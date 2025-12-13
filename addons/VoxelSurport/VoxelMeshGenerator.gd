class_name VoxelMeshGenerator

var pos_min: Vector3i
var pos_max: Vector3i
var slice_voxels: Array[Dictionary]
var scale: float
var thread_datas: Array[ThreadData] = []

func generate(voxel_data: VoxelData, scale: float) -> Mesh:
	var time = Time.get_ticks_usec()
	var voxels := voxel_data.get_voxels()
	self.scale = scale
	pos_min = Vector3i.MAX
	pos_max = Vector3i.MIN
	
	if voxels.size() == 0:
		return null

	slice_voxels = [ {}, {}, {}]
	for pos in voxels:
		pos_min.x = min(pos_min.x, pos.x)
		pos_min.y = min(pos_min.y, pos.y)
		pos_min.z = min(pos_min.z, pos.z)
		pos_max.x = max(pos_max.x, pos.x)
		pos_max.y = max(pos_max.y, pos.y)
		pos_max.z = max(pos_max.z, pos.z)
		for axis in 3:
			var slice_index := pos[axis]
			var slices := slice_voxels[axis]
			if not slices.has(slice_index):
				slices[slice_index] = {}
			slices[slice_index][pos] = voxels[pos]
	
	
	for dir in FaceTool.Faces.size():
		var surface = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var data = ThreadData.new(dir, surface)
		thread_datas.append(data)

	var task_id := WorkerThreadPool.add_group_task(_generate_dir_face, FaceTool.Faces.size())
	WorkerThreadPool.wait_for_group_task_completion(task_id)
	
	var main_surface = SurfaceTool.new()
	main_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for data in thread_datas:
		var mesh = data.surface.commit()
		main_surface.append_from(mesh, 0, Transform3D.IDENTITY)

	var material := StandardMaterial3D.new()
	main_surface.set_material(material)
	material.albedo_texture = voxel_data.get_albedo_textrue()
	material.metallic_texture = voxel_data.get_metal_textrue()
	material.roughness_texture = voxel_data.get_rough_textrue()
	material.emission_enabled = true
	material.emission_energy_multiplier = 16
	material.emission_texture = voxel_data.get_emission_textrue()
	var mesh := main_surface.commit()
	prints("generate mesh: ", (Time.get_ticks_usec() - time) / 1000.0, "ms", mesh.get_faces().size() / 6, "face")
	return mesh


func _generate_dir_face(dir: int) -> void:
	var axis := FaceTool.SliceAxis[dir]
	var slices := slice_voxels[axis.x]
	var surface := thread_datas[dir].surface
	for slice_index in range(pos_min[axis.x], pos_max[axis.x] + 1):
		if slices.has(slice_index):
			var slice_voxels_visible = _get_dir_visible_slice_voxels(slices, axis, dir, slice_index)
			if slice_voxels_visible.size() > 0:
				var slice = slices[slice_index]
				for pos in slice:
					if slice_voxels_visible.has(pos):
						_generate_voxel_dir_face(slice_voxels_visible, axis, pos, dir, surface)


func _get_dir_visible_slice_voxels(slices: Dictionary, axis: Vector3i, dir: int, slice_index: int) -> Dictionary:
	var voxels := {}
	var offset := Vector3i(FaceTool.Normals[dir])
	var slice: Dictionary = slices[slice_index]
	var dir_slice_index := slice_index + offset[axis.x]
	
	if not slices.has(dir_slice_index):
		return slice.duplicate()
	
	var dir_slice = slices[dir_slice_index]
	for pos in slice:
		if !dir_slice.has(pos + offset):
			voxels[pos] = slice[pos]
	return voxels


func _generate_voxel_dir_face(voxels: Dictionary, axis: Vector3i, pos: Vector3i, dir: int, surface: SurfaceTool) -> void:
	var y_size: int = _get_y_size(voxels, pos, axis.y)
	var z_size: int = _get_z_size(voxels, pos, axis, y_size)
	var size: Vector3 = Vector3.ONE
	size[axis.y] = y_size
	size[axis.z] = z_size
	var uv := Vector2((voxels[pos] + 0.5) / 256.0, 0.5)
	
	surface.set_normal(FaceTool.Normals[dir])
	for point: Vector3 in FaceTool.Faces[dir]:
		surface.set_uv(uv)
		surface.add_vertex((point * size + Vector3(pos)) * scale)

	var cur_pos := pos
	for z in range(z_size):
		cur_pos[axis.y] = pos[axis.y]
		for y in range(y_size):
			voxels.erase(cur_pos)
			cur_pos[axis.y] += 1
		cur_pos[axis.z] += 1

func _get_y_size(voxels: Dictionary, pos: Vector3i, axis_y: int, max_size: int = -1) -> int:
	var value: int = voxels[pos]
	var cur_pos: Vector3i = pos
	cur_pos[axis_y] += 1
	var size := 1
	
	while voxels.has(cur_pos) and voxels[cur_pos] == value:
		cur_pos[axis_y] += 1
		size += 1
		if max_size > 0 and size >= max_size:
			break
	return size

func _get_z_size(voxels: Dictionary, pos: Vector3i, axis: Vector3i, y_size: int) -> int:
	var value: int = voxels[pos]
	var cur_pos: Vector3i = pos
	cur_pos[axis.z] += 1
	var size := 1
	
	while voxels.has(cur_pos) and voxels[cur_pos] == value and _get_y_size(voxels, cur_pos, axis.y, y_size) >= y_size:
		cur_pos[axis.z] += 1
		size += 1
	return size


class ThreadData:
	var dir: int
	var surface: SurfaceTool
	
	func _init(p_dir: int, p_tool: SurfaceTool):
		dir = p_dir
		surface = p_tool