class_name VoxelMeshGenerator
## 体素网格生成器
## 会将数据分为6个方向 并多线程计算网格

var pos_min: Vector3i
var pos_max: Vector3i
var slice_voxels: Array[Dictionary]
var scale: float = 1
var import_materials_textures: bool
var unwrap_lightmap_uv2: bool
var materials: Array
var tasks: Array
var mesh: Mesh
var voxel: VoxelData

func generate(voxel: VoxelData, options: Dictionary, path: String = "") -> ArrayMesh:
	self.voxel = voxel
	scale = options[VoxelMeshImporter.scale]
	if scale <= 0:
		scale = 0.01
	import_materials_textures = options[VoxelMeshImporter.import_materials_textures]
	unwrap_lightmap_uv2 = options[VoxelMeshImporter.unwrap_lightmap_uv2]
	materials = options[VoxelMeshImporter.materials]
	var time = Time.get_ticks_usec()
	match options[VoxelMeshImporter.mesh_mode]:
		VoxelMeshImporter.MeshMode.Default:
			voxel.generate_models_mesh()
			mesh = voxel.get_mesh()
			change_mesh_scale(scale)
		VoxelMeshImporter.MeshMode.MergeSide:
			start_generate_mesh(voxel.get_voxels(), voxel)
			wait_finished()
		VoxelMeshImporter.MeshMode.Merge:
			start_generate_mesh(voxel.get_voxels(), voxel)
			wait_finished()

	if not mesh:
		return null

	if unwrap_lightmap_uv2:
		mesh.lightmap_unwrap(Transform3D.IDENTITY, scale)
	
	if import_materials_textures:
		var mat := generate_material(path if import_materials_textures else "")
		mesh.surface_set_material(0, mat)
		if mesh.get_surface_count() > 1:
			var trans_mat := generate_material_trans(mat, path if import_materials_textures else "")
			mesh.surface_set_material(1, trans_mat)
	else:
		for i in materials.size():
			mesh.surface_set_material(i, materials[i])

	prints("generate mesh: ", (Time.get_ticks_usec() - time) / 1000.0, "ms", mesh.get_faces().size() / 6, "face")

	return mesh

func change_mesh_scale(scale: float):
	if mesh:
		var mesh_tool = MeshDataTool.new()
		var new_mesh = ArrayMesh.new()
		for si in mesh.get_surface_count():
			mesh_tool.create_from_surface(mesh, si)
			for i in mesh_tool.get_vertex_count():
				mesh_tool.set_vertex(i, mesh_tool.get_vertex(i) * scale)
			mesh_tool.commit_to_surface(new_mesh, si)
		mesh = new_mesh


func generate_material(save_path: String = "") -> StandardMaterial3D:
	var path := save_path.get_basename() + '_mat.tres'
	var material: Material = ResourceLoader.load(path) if FileAccess.file_exists(path) else StandardMaterial3D.new()
	if material is StandardMaterial3D:
		material.emission_enabled = true
		material.emission_energy_multiplier = 16
		material.metallic = 1
		material.albedo_texture = generate_albedo_textrue(save_path)
		material.metallic_texture = generate_metal_textrue(save_path)
		material.roughness_texture = generate_rough_textrue(save_path)
		material.emission_texture = generate_emission_textrue(save_path)
		if save_path:
			material.resource_path = path
			ResourceSaver.save(material)
	else:
		generate_albedo_textrue(save_path)
		generate_metal_textrue(save_path)
		generate_rough_textrue(save_path)
		generate_emission_textrue(save_path)
	return material

func generate_material_trans(base: Material, save_path: String = "") -> StandardMaterial3D:
	var path := save_path.get_basename() + '_mat_trans.tres'
	var material: Material = ResourceLoader.load(path) if FileAccess.file_exists(path) else base.duplicate() if base else StandardMaterial3D.new()
	if material is StandardMaterial3D:
		material.refraction_enabled = true
		material.emission_enabled = false
		material.transparency = BaseMaterial3D.Transparency.TRANSPARENCY_ALPHA
		if save_path:
			material.resource_path = path
			ResourceSaver.save(material)
	else:
		pass
	return material

func _generate_texture(get_pixel: Callable, save_path: String, type: String) -> ImageTexture:
	var image := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	for x in 256:
		var color := get_pixel.call(voxel.materials[x])
		image.set_pixel(x, 0, color)
	var path := save_path.get_basename() + '_' + type + '.tres'
	var texture: ImageTexture = ResourceLoader.load(path) if FileAccess.file_exists(path) else ImageTexture.create_from_image(image)
	texture.set_image(image)
	if save_path:
		texture.resource_path = path
		ResourceSaver.save(texture)
	return texture

func generate_albedo_textrue(save_path: String = "") -> ImageTexture:
	return _generate_texture(func(m): return m.color, save_path, "albedo")

func generate_metal_textrue(save_path: String = "") -> ImageTexture:
	return _generate_texture(func(m): return Color.from_hsv(0, 0, m.metal), save_path, "metal")

func generate_rough_textrue(save_path: String = "") -> ImageTexture:
	return _generate_texture(func(m): return Color.from_hsv(0, 0, m.rough), save_path, "rough")

func generate_emission_textrue(save_path: String = "") -> ImageTexture:
	return _generate_texture(func(m): return m.color * m.emission, save_path, "emission")


func start_generate_mesh(voxels: Dictionary[Vector3i, int], voxel: VoxelData) -> void:
	self.voxel = voxel
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
		mesh = ArrayMesh.new()
		var surface = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for task in tasks:
			WorkerThreadPool.wait_for_task_completion(task.id)
		for i in 2:
			for task in tasks:
				if "meshes" in task:
					var child_mesh: ArrayMesh = task.meshes[i]
					if child_mesh.get_surface_count() > 0:
						surface.append_from(child_mesh, 0, Transform3D.IDENTITY)
			surface.commit(mesh)
			surface.clear()
		tasks.clear()
	return mesh

func _generate_dir_face(task) -> void:
	var surfaces: Array[SurfaceTool] = [SurfaceTool.new(), SurfaceTool.new()]
	for surface in surfaces:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var axis := FaceTool.SliceAxis[task.dir]
	var slices := slice_voxels[axis.x]
	for slice_index in range(pos_min[axis.x], pos_max[axis.x] + 1):
		if slices.has(slice_index):
			var slice_voxels_visible = _get_dir_visible_slice_voxels(slices, axis, task.dir, slice_index)
			if slice_voxels_visible.size() > 0:
				var slice = slices[slice_index]
				var pos: Vector3i
				pos[axis.x] = slice_index
				for y in range(pos_min[axis.y], pos_max[axis.y] + 1):
					pos[axis.y] = y
					for z in range(pos_min[axis.z], pos_max[axis.z] + 1):
						pos[axis.z] = z
						if slice_voxels_visible.has(pos):
							_generate_voxel_dir_face(slice_voxels_visible, axis, pos, task.dir, surfaces)
	task.meshes = [surfaces[0].commit(), surfaces[1].commit()]


func _get_dir_visible_slice_voxels(slices: Dictionary, axis: Vector3i, dir: int, slice_index: int) -> Dictionary:
	var voxels := {}
	var offset := Vector3i(FaceTool.Normals[dir])
	var slice: Dictionary = slices[slice_index]
	var dir_slice_index := slice_index + offset[axis.x]
	
	if not slices.has(dir_slice_index):
		return slice.duplicate()
	
	var dir_slice = slices[dir_slice_index]
	for pos: Vector3i in slice:
		var dir_pos: Vector3i = pos + offset
		if !dir_slice.has(dir_pos) or voxel.materials[dir_slice[dir_pos]].is_transparent != voxel.materials[slice[pos]].is_transparent:
			voxels[pos] = slice[pos]
	return voxels

func _generate_voxel_dir_face(voxels: Dictionary, axis: Vector3i, pos: Vector3i, dir: int, surfaces: Array[SurfaceTool]) -> void:
	var y_size: int = _get_y_size(voxels, pos, axis.y)
	var z_size: int = _get_z_size(voxels, pos, axis, y_size)
	var size: Vector3 = Vector3.ONE
	size[axis.y] = y_size
	size[axis.z] = z_size
	var id: int = voxels[pos]
	var uv := Vector2((id + 0.5) / 256.0, 0.5)
	
	var surface := surfaces[0] if not voxel.materials[id].is_transparent else surfaces[1]

	surface.set_normal(FaceTool.Normals[dir])
	for point: Vector3 in FaceTool.Faces[dir]:
		surface.set_uv(uv)
		surface.add_vertex((point * size + Vector3(pos)) * scale)
	
	var cur_pos := pos
	for y in y_size:
		cur_pos[axis.z] = pos[axis.z]
		for z in z_size:
			voxels.erase(cur_pos)
			cur_pos[axis.z] += 1
		cur_pos[axis.y] += 1

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
