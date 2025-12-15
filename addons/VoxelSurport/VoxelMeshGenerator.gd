class_name VoxelMeshGenerator

var pos_min: Vector3i
var pos_max: Vector3i
var slice_voxels: Array[Dictionary]
var scale: float = 1
var import_materials_textures: bool
var unwrap_lightmap_uv2: bool
var materials: Array
var tasks: Array
var mesh: Mesh

func generate(voxel_data: VoxelData, options: Dictionary, path: String = "") -> ArrayMesh:
	scale = options[VoxelMeshImporter.scale]
	import_materials_textures = options[VoxelMeshImporter.import_materials_textures]
	unwrap_lightmap_uv2 = options[VoxelMeshImporter.unwrap_lightmap_uv2]
	materials = options[VoxelMeshImporter.materials]
	var time = Time.get_ticks_usec()

	match options[VoxelMeshImporter.mesh_mode]:
		VoxelMeshImporter.MeshMode.Default:
			for model in voxel_data.models:
				model.start_generate_mesh()
			for model in voxel_data.models:
				model.wait_finished()
			mesh = voxel_data.get_mesh()
			var mesh_tool = MeshDataTool.new()
			var new_mesh = ArrayMesh.new()
			for si in mesh.get_surface_count():
				mesh_tool.create_from_surface(mesh, si)
				for i in mesh_tool.get_vertex_count():
					mesh_tool.set_vertex(i, mesh_tool.get_vertex(i) * scale)
				mesh_tool.commit_to_surface(new_mesh, si)
			mesh = new_mesh
		VoxelMeshImporter.MeshMode.MergeSide:
			start_generate_mesh(voxel_data.get_voxels())
			wait_finished()
		VoxelMeshImporter.MeshMode.Merge:
			start_generate_mesh(voxel_data.get_voxels())
			wait_finished()

	if unwrap_lightmap_uv2:
		mesh.lightmap_unwrap(Transform3D.IDENTITY, scale)
	
	if import_materials_textures:
		var mat := voxel_data.get_material(path if import_materials_textures else "")
		mesh.surface_set_material(0, mat)
	else:
		for i in materials.size():
			mesh.surface_set_material(i, materials[i])

	prints("generate mesh: ", (Time.get_ticks_usec() - time) / 1000.0, "ms", mesh.get_faces().size() / 6, "face")

	return mesh

func start_generate_mesh(voxels: Dictionary[Vector3i, int]) -> void:
	pos_min = Vector3i.MAX
	pos_max = Vector3i.MIN
	
	if voxels.size() == 0:
		return

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
	
	tasks.clear()
	for dir in FaceTool.Faces.size():
		var task = {dir = dir}
		tasks.append(task)
		task.id = WorkerThreadPool.add_task(_generate_dir_face.bind(task))
		
func wait_finished() -> ArrayMesh:
	if not mesh and tasks.size() > 0:
		var surface = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for task in tasks:
			WorkerThreadPool.wait_for_task_completion(task.id)
			if "mesh" in task and task.mesh:
				surface.append_from(task.mesh, 0, Transform3D.IDENTITY)
		mesh = surface.commit()
		tasks.clear()
	return mesh

func _generate_dir_face(task) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var axis := FaceTool.SliceAxis[task.dir]
	var slices := slice_voxels[axis.x]
	for slice_index in range(pos_min[axis.x], pos_max[axis.x] + 1):
		if slices.has(slice_index):
			var slice_voxels_visible = _get_dir_visible_slice_voxels(slices, axis, task.dir, slice_index)
			if slice_voxels_visible.size() > 0:
				var slice = slices[slice_index]
				for pos in slice:
					if slice_voxels_visible.has(pos):
						_generate_voxel_dir_face(slice_voxels_visible, axis, pos, task.dir, surface)
	task.mesh = surface.commit()

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
