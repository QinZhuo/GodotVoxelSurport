class_name VoxelData

var models: Array[VoxelModel]

var materials: Array[VoxelMaterial]

var nodes: Dictionary[int, VoxelNode]

var layers: Dictionary[int, VoxelLayer]

func get_voxels(frame_index: int = 0) -> Dictionary[Vector3i, int]:
	if nodes.size() > 0:
		return nodes[frame_index].get_voxels(self, frame_index)
	elif models.size() > 0:
		var node := VoxelNode.new()
		node.models.append(models[frame_index])
		return node.get_voxels(self, frame_index)
	return {}

func get_mesh(frame_index: int = 0) -> ArrayMesh:
	if nodes.size() > 0:
		return nodes[frame_index].get_mesh(self, frame_index)
	elif models.size() > 0:
		var node := VoxelNode.new()
		node.models.append(models[frame_index])
		return node.get_mesh(self, frame_index)
	return null

func generate_models_mesh():
	for model in models:
		model.start_generate_mesh(self)
	for model in models:
		model.wait_finished()

func _to_string() -> String:
	return str("nodes:", nodes, "models:", models)

class VoxelModel:
	var size: Vector3:
		set(value):
			size = value
			offset = - (size / 2).floor()

	var offset: Vector3

	var voxels: Dictionary[Vector3i, int]

	var mesh: ArrayMesh

	var _generator: VoxelMeshGenerator

	func start_generate_mesh(voxel: VoxelData):
		if mesh:
			return
		_generator = VoxelMeshGenerator.new()
		_generator.start_generate_mesh(voxels, voxel)

	func wait_finished() -> ArrayMesh:
		if not mesh and _generator:
			mesh = _generator.wait_finished()
			_generator = null
		return mesh

	func _to_string() -> String:
		return str(voxels.size())

class VoxelMaterial:
	var id: int

	var color: Color

	var is_transparent: bool = false

	var alpha: float = 1:
		set(value):
			if is_transparent:
				color.a = value

	var metal: float = 0

	var rough: float = 1

	var emission: float = 0


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

	const MaxSurface = 2
	func get_mesh(voxel: VoxelData, frame_index: int = 0) -> ArrayMesh:
		var result_mesh = ArrayMesh.new()
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var models := get_models(voxel, frame_index)
		for face in MaxSurface:
			for i in models.size():
				var mesh: ArrayMesh = models[i][0].mesh
				if mesh.get_surface_count() <= face:
					break
				var transform: Transform3D = models[i][1]
				var offset := transform * (Vector3.ONE * 1000) - (Vector3.ONE * 1000)
				surface.append_from(mesh, face, transform)
			surface.commit(result_mesh)
			surface.clear()
		return result_mesh

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

	func _to_string() -> String:
		return str(id, ' ', child_nodes)

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
