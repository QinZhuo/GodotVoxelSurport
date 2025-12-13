class_name VoxelData

var models: Array[VoxelModel]
var colors: Array[Color]
var materials: Dictionary[int, VoxelMaterial]
var nodes: Dictionary[int, VoxelNode]
var layers: Dictionary[int, VoxelLayer]
var voxels: Dictionary[Vector3i, int]

func get_voxels() -> Dictionary[Vector3i, int]:
	if voxels.size() == 0:
		if nodes.size() > 0:
			nodes[0].merge_Voxels(voxels, self)
	return voxels


class VoxelModel:
	var size: Vector3
	var voxels: Dictionary[Vector3i, int]
	func merge_Voxels(target_voxels: Dictionary[Vector3i, int]):
		var offset: Vector3i = (size / 2).floor()
		for pos in voxels:
			target_voxels[pos - offset] = voxels[pos]


class VoxelMaterial:
	var type: String
	var weight: float
	var specular: float
	var roughness: float
	var flux: float
	var refraction: float


class VoxelNode:
	var id: int
	var attributes: Dictionary[String, String]
	var layerId := -1
	var child_nodes: Array[int]
	var frames: Array[VoxelFrame]

	func get_frame(index: int) -> VoxelFrame:
		if index >= frames.size():
			frames.resize(index + 1)
		if not frames[index]:
			frames[index] = VoxelFrame.new()
		return frames[index]

	var voxels: Dictionary[Vector3i, int]
	
	func merge_Voxels(target_voxels: Dictionary[Vector3i, int], voxel: VoxelData, frame_index: int = 0):
		get_Voxels(voxel, frame_index)
		for pos in voxels:
			target_voxels[pos] = voxels[pos]

	func get_Voxels(voxel: VoxelData, frame_index: int = 0) -> Dictionary[Vector3i, int]:
		if voxels.size() > 0:
			return voxels
		if layerId in voxel.layers and not voxel.layers[layerId].isVisible:
			return voxels
		if child_nodes.size() > 1:
			var tasks := []
			for i in child_nodes:
				tasks.append(WorkerThreadPool.add_task(voxel.nodes[i].get_Voxels.bind(voxel, frame_index)))
			for task in tasks:
				WorkerThreadPool.wait_for_task_completion(task)
		for i in child_nodes:
			voxel.nodes[i].merge_Voxels(voxels, voxel, frame_index)
		if frames.size() > frame_index:
			var frame := frames[frame_index]
			if frame.model_id >= 0:
				voxel.models[frame.model_id].merge_Voxels(voxels)
			if frame.rotation != Basis.IDENTITY or frame.position != Vector3.ZERO:
				var new_data: Dictionary[Vector3i, int]
				for pos in voxels:
					var half_step = Vector3(0.5, 0.5, 0.5);
					var new_pos := ((frame.rotation * Vector3(pos) + half_step - half_step).floor() + frame.position);
					new_data[Vector3i(new_pos)] = voxels[pos]
				voxels = new_data
		return voxels
		
		
class VoxelFrame:
	var model_id: int = -1
	var position: Vector3
	var rotation: Basis


class VoxelLayer:
	var id: int;
	var isVisible: bool;
