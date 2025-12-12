class_name VoxFile

static func Open(path: String) -> VoxFile:
	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		return null

	var id = file.get_buffer(4).get_string_from_ascii()
	if id != "VOX ":
		file.close()
		file = null
		return null
	
	var version = file.get_32()
	var vox := VoxFile.new(file)
	
	file.close()
	file = null
	return vox

func _init(file: FileAccess):
	_file = file
	voxel_data = VoxelData.new()
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
			voxel_data.colors.resize(256)
			for i in 255:
				voxel_data.colors[i + 1] = _get_color()
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
					frame.rotation = _get_rotation(int(frame_attributes['_r']))
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
			var material := VoxelData.VoxelMaterial.new();
			voxel_data.materials[material_id] = material
			var attributes := _get_dictionary()
			material.type = attributes.get("_type", "diffuse");
			material.weight = float(attributes.get("_weight", 0));
			material.specular = float(attributes.get("spec", 0));
			material.roughness = float(attributes.get("rough", 0));
			material.flux = float(attributes.get("flux", 0));
			material.refraction = float(attributes.get("ior", 0));
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
		var key = _get_string(_get_int());
		dictionary[key] = _get_string(_get_int());
	return dictionary;

func _get_node() -> VoxelData.VoxelNode:
	var node := VoxelData.VoxelNode.new()
	node.id = _get_int()
	node.attributes = _get_dictionary()
	voxel_data.nodes[node.id] = node
	return node


func _get_rotation(encoded_rot: int) -> Basis:
	var rotation: Basis
	var x_axis = ((encoded_rot >> 0) & 0x03)
	var y_axis = ((encoded_rot >> 2) & 0x03)
	
	var axes = [0, 1, 2]
	axes.erase(x_axis)
	axes.erase(y_axis)
	var z_axis = axes[0]

	var x_sign = 1 if ((encoded_rot >> 4) & 0x01) == 0 else -1
	var y_sign = 1 if ((encoded_rot >> 5) & 0x01) == 0 else -1
	var z_sign = 1 if ((encoded_rot >> 6) & 0x01) == 0 else -1
	
	var axis_map = [0, 2, 1]

	rotation.x = Vector3()
	rotation.x[axis_map[x_axis]] = x_sign
	
	rotation.y = Vector3()
	rotation.y[axis_map[z_axis]] = z_sign
	
	rotation.z = Vector3()
	rotation.z[axis_map[y_axis]] = - y_sign

	return rotation