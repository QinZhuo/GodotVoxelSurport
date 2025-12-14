class_name VoxAccess

static func Open(path: String) -> VoxAccess:
	var time = Time.get_ticks_usec()
	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		return null

	var id = file.get_buffer(4).get_string_from_ascii()
	if id != "VOX ":
		file.close()
		return null
	
	var version = file.get_32()
	var vox := VoxAccess.new(file)
	prints("open .vox time:", (Time.get_ticks_usec() - time) / 1000.0, "ms")
	file.close()
	return vox

func _init(file: FileAccess):
	_file = file
	voxel_data = VoxelData.new()
	voxel_data.materials.resize(256)
	for i in voxel_data.materials.size():
		voxel_data.materials[i] = VoxelData.VoxelMaterial.new()
	while file.get_position() < file.get_length():
		read_chunk()

var voxel_data: VoxelData
var _file: FileAccess
var _chunk_size = 0

func read_chunk():
	var id = _get_string(4)
	var size := _get_int()
	var chunks := _get_int()
	_chunk_size = size
	match id:
		"SIZE":
			var model := VoxelData.VoxelModel.new()
			voxel_data.models.append(model)
			model.size = _get_vector3i()
		"XYZI":
			var model := voxel_data.models.back()
			for i in _get_int():
				var pos := _get_vector3byte()
				model.voxels[pos] = _get_byte()
		"RGBA":
			var model := voxel_data.models.back()
			for i in 255:
				voxel_data.materials[i + 1].color = _get_color()
		"nTRN":
			var node := _get_node()
			node.child_nodes.append(_get_int())
			_get_int() # reserved id (must be -1)
			node.layerId = _get_int()
			for i in _get_int():
				var frame_attributes := _get_dictionary()
				var frame_index := int(frame_attributes.get('_f', '0'))
				var frame := node.get_frame(frame_index)
				if frame_attributes.has('_t'):
					var position := frame_attributes['_t'].split_floats(' ')
					frame.position = Vector3(position[0], position[2], -position[1])
				if frame_attributes.has('_r'):
					frame.rotation = decode_rotation(int(frame_attributes['_r']))
		"nGRP":
			var node := _get_node()
			for i in _get_int():
				node.child_nodes.append(_get_int())
		"nSHP":
			var node := _get_node()
			for i in _get_int():
				var model_id := _get_int()
				var model_attributes := _get_dictionary()
				var frame_index := int(model_attributes.get('_f', '0'))
				node.get_frame(frame_index).model_id = model_id
		"MATL":
			var material_id := _get_int()
			var material := voxel_data.materials[material_id] if material_id < 256 else VoxelData.VoxelMaterial.new()
			var attributes := _get_dictionary()
			material.type = attributes.get("_type", "diffuse")

			material.color.a = 1 - float(attributes.get("_trans", 0))

			material.metal = float(attributes.get("_metal", 0)) if material.type == "_metal" else 0
			material.specular = float(attributes.get("_sp", 1)) / 2

			material.rough = float(attributes.get("_rough", 0)) if material.type == "_metal" else 1
			
			material.emission = float(attributes.get("_emit", 0)) if material.type == "_emit" else 0
			material.flux = float(attributes.get("_flux", 1))
			
			material.refraction = float(attributes.get("_ri", 1.5)) / 3

		"LAYR":
			var layer := VoxelData.VoxelLayer.new()
			layer.id = _get_int()
			layer.isVisible = _get_dictionary().get('_hidden', '0') != '1'
			voxel_data.layers[layer.id] = layer
	_get_remaining()


func _get_byte() -> int:
	_chunk_size -= 1
	return _file.get_8()
	
func _get_int() -> int:
	_chunk_size -= 4
	return _file.get_32()

func _get_buffer(length) -> PackedByteArray:
	_chunk_size -= length
	return _file.get_buffer(length)

func _get_remaining():
	_get_buffer(_chunk_size)
	_chunk_size = 0

func _get_string(length):
	return _get_buffer(length).get_string_from_ascii()


func _get_vector3byte() -> Vector3i:
	var x := _get_byte()
	var y := _get_byte()
	var z := _get_byte()
	return Vector3i(x, z, -y)

func _get_vector3i() -> Vector3i:
	var x := _get_int()
	var y := _get_int()
	var z := _get_int()
	return Vector3i(x, z, -y)

func _get_color() -> Color:
	return Color(_get_byte() / 255.0, _get_byte() / 255.0, _get_byte() / 255.0, _get_byte() / 255.0)

func _get_dictionary() -> Dictionary[String, String]:
	var dictionary: Dictionary[String, String]
	for _p in range(_get_int()):
		var key = _get_string(_get_int())
		dictionary[key] = _get_string(_get_int())
	return dictionary

func _get_node() -> VoxelData.VoxelNode:
	var node := VoxelData.VoxelNode.new()
	node.id = _get_int()
	node.attributes = _get_dictionary()
	voxel_data.nodes[node.id] = node
	return node

static var rot_cache: Dictionary[int, Basis] = {}
func decode_rotation(byte_value: int) -> Basis:
	if rot_cache.has(byte_value):
		return rot_cache[byte_value]
		
	var row0_index = byte_value & 3
	var row1_index = (byte_value >> 2) & 3
	var row2_index = 3 - row0_index - row1_index
	
	var sign0 = 1 if ((byte_value >> 4) & 1) == 0 else -1
	var sign1 = 1 if ((byte_value >> 5) & 1) == 0 else -1
	var sign2 = 1 if ((byte_value >> 6) & 1) == 0 else -1
	
	var cols = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	cols[row0_index].x = sign0
	cols[row1_index].y = sign1
	cols[row2_index].z = sign2
	
	var col0 = cols[0]
	var col1 = cols[1]
	var col2 = cols[2]
	
	var godot_col0 = Vector3(col0.x, col0.z, -col0.y)
	var godot_col1 = Vector3(col2.x, col2.z, -col2.y)
	var godot_col2 = Vector3(-col1.x, -col1.z, col1.y)
	var rotation := Basis(godot_col0, godot_col1, godot_col2)
	rot_cache[byte_value] = rotation
	return rotation