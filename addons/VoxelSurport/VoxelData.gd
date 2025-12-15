class_name VoxelData

var models: Array[VoxelModel]

var materials: Array[VoxelMaterial]

var nodes: Dictionary[int, VoxelNode]

var layers: Dictionary[int, VoxelLayer]

func get_voxels() -> Dictionary[Vector3i, int]:
	if nodes.size() > 0:
		return nodes[0].get_voxels(self)
	return {}

func get_mesh() -> ArrayMesh:
	if nodes.size() > 0:
		return nodes[0].get_mesh(self)
	return null

func get_material(save_path: String = "") -> StandardMaterial3D:
	var time = Time.get_ticks_usec()
	var path := save_path.get_basename() + '.tres'
	var material: Material = ResourceLoader.load(path) if FileAccess.file_exists(path) else StandardMaterial3D.new()
	if material is StandardMaterial3D:
		material.emission_enabled = true
		material.emission_energy_multiplier = 16
		material.metallic = 1
		material.albedo_texture = get_albedo_textrue(save_path)
		material.metallic_texture = get_metal_textrue(save_path)
		material.roughness_texture = get_rough_textrue(save_path)
		material.emission_texture = get_emission_textrue(save_path)
	if save_path:
		material.resource_path = path
		ResourceSaver.save(material)
	return material

func _get_texture(get_pixel: Callable, save_path: String = , type: String) -> ImageTexture:
	var image := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	for x in 256:
		var color := get_pixel.call(materials[x])
		image.set_pixel(x, 0, color)
	var path := save_path.get_basename() + '_' + type + '.tres'
	var texture: ImageTexture = ResourceLoader.load(path) if FileAccess.file_exists(path) else ImageTexture.create_from_image(image)
	texture.set_image(image)
	if save_path:
		texture.resource_path = path
		ResourceSaver.save(texture)
	return texture

func get_albedo_textrue(save_path: String = "") -> ImageTexture:
	return _get_texture(func(m): return m.color, save_path, "albedo")

func get_metal_textrue(save_path: String = "") -> ImageTexture:
	return _get_texture(func(m): return Color.from_hsv(0, 0, m.metal), save_path, "metal")

func get_rough_textrue(save_path: String = "") -> ImageTexture:
	return _get_texture(func(m): return Color.from_hsv(0, 0, m.rough), save_path, "rough")

func get_emission_textrue(save_path: String = "") -> ImageTexture:
	return _get_texture(func(m): return m.color * m.emission, save_path, "emission")


class VoxelModel:
	var size: Vector3:
		set(value):
			size = value
			offset = - (size / 2).floor()

	var offset: Vector3

	var voxels: Dictionary[Vector3i, int]

	var mesh: ArrayMesh

	var _generator: VoxelMeshGenerator

	func start_generate_mesh():
		if mesh:
			return
		_generator = VoxelMeshGenerator.new()
		_generator.start_generate_mesh(voxels)

	func wait_finished() -> ArrayMesh:
		if not mesh and _generator:
			mesh = _generator.wait_finished()
			_generator = null
		return mesh


class VoxelMaterial:
	var id: int

	var color: Color

	var type: String

	var trans: float = 0

	var metal: float = 0

	var specular: float = 0.5

	var rough: float = 1

	var emission: float = 0

	var flux: float = 1

	var refraction: float = 0.5

	func _to_string():
		return str(id, ":", color)

class VoxelNode:
	var id: int
	
	var attributes: Dictionary[String, String]
	
	var layerId := -1
	
	var child_nodes: Array[int]
	
	var frames: Dictionary[int, VoxelFrame]

	var models: Array

	func get_frame(index: int) -> VoxelFrame:
		if not frames.has(index):
			frames[index] = VoxelFrame.new()
		return frames[index]

	func get_models(voxel: VoxelData, frame_index: int = 0) -> Array:
		if layerId in voxel.layers and not voxel.layers[layerId].isVisible:
			return models
		models.clear()
		if child_nodes.size() > 0:
			var tasks := []
			for i in child_nodes:
				tasks.append(WorkerThreadPool.add_task(voxel.nodes[i].get_models.bind(voxel, frame_index)))
			for task in tasks:
				WorkerThreadPool.wait_for_task_completion(task)
			for i in child_nodes:
				models.append_array(voxel.nodes[i].models)
		if frames.size() > frame_index:
			frames[frame_index].merge_models(voxel, models)
		return models

	func get_mesh(voxel: VoxelData, frame_index: int = 0) -> ArrayMesh:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var models := get_models(voxel, frame_index)
		for i in models.size():
			var transform: Transform3D = models[i][1]
			var offset := transform * (Vector3.ONE * 1000) - (Vector3.ONE * 1000)

			surface.append_from(models[i][0].mesh, 0, transform)
		return surface.commit()

	func get_voxels(voxel: VoxelData, frame_index: int = 0) -> Dictionary[Vector3i, int]:
		var voxels: Dictionary[Vector3i, int]
		var models := get_models(voxel, frame_index)
		var half_step = Vector3(0.5, 0.5, 0.5);
		for i in models.size():
			var model: VoxelModel = models[i][0]
			var transform: Transform3D = models[i][1]
			for pos in model.voxels:
				var new_pos := transform * Vector3(pos)
				voxels[Vector3i(new_pos)] = model.voxels[pos]
		return voxels
		
class VoxelFrame:
	var model_id: int = -1
	
	var position: Vector3
	
	var rotation: Basis

	var transform: Transform3D:
		get(): return Transform3D(rotation, position)

	func merge_models(voxel: VoxelData, models: Array):
		if model_id >= 0:
			var model := voxel.models[model_id]
			models.append([model, Transform3D.IDENTITY.translated(model.offset)])
		if rotation != Basis.IDENTITY or position != Vector3.ZERO:
			for i in models.size():
				var model_transform: Transform3D = models[i][1]
				models[i][1] = transform * model_transform

class VoxelLayer:
	var id: int;
	
	var isVisible: bool;
