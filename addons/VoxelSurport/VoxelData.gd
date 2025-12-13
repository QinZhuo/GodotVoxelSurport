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
			var time = Time.get_ticks_usec()
			nodes[0].merge_Voxels(voxels, self)
			prints("get voxels time:", (Time.get_ticks_usec() - time) / 1000.0, "ms", voxels.size(), "voxels")
	return voxels

func get_material(save_path: String = "", gen_files: Array[String] = []) -> StandardMaterial3D:
	var time = Time.get_ticks_usec()
	var material := StandardMaterial3D.new()
	material.emission_enabled = true
	material.emission_energy_multiplier = 16
	if save_path:
		material.albedo_texture = get_albedo_textrue(save_path + "_albedo.png")
		gen_files.append(save_path + "_albedo.png")
		material.metallic_texture = get_metal_textrue(save_path + "_metal.png")
		gen_files.append(save_path + "_metal.png")
		material.roughness_texture = get_rough_textrue(save_path + "_rough.png")
		gen_files.append(save_path + "_rough.png")
		material.emission_texture = get_emission_textrue(save_path + "_emission.png")
		gen_files.append(save_path + "_emission.png")
	else:
		material.albedo_texture = get_albedo_textrue()
		material.metallic_texture = get_metal_textrue()
		material.roughness_texture = get_rough_textrue()
		material.emission_texture = get_emission_textrue()
	prints("create material time:", (Time.get_ticks_usec() - time) / 1000.0, "ms")
	return material

func get_albedo_textrue(save_path: String = "") -> ImageTexture:
	var image := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	for x in 256:
		var color := colors[x]
		if materials.has(x):
			color.a = 1 - materials[x].trans
		image.set_pixel(x, 0, color)
	if save_path:
		image.save_png(save_path)
	return ImageTexture.create_from_image(image)

func get_metal_textrue(save_path: String = "") -> ImageTexture:
	var image := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	for x in 256:
		image.set_pixel(x, 0, Color.from_hsv(0, 0, materials[x].metal if materials.has(x) else 0))
	if save_path:
		image.save_png(save_path)
	return ImageTexture.create_from_image(image)

func get_rough_textrue(save_path: String = "") -> ImageTexture:
	var image := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	for x in 256:
		image.set_pixel(x, 0, Color.from_hsv(0, 0, materials[x].roughness if materials.has(x) else 0))
	if save_path:
		image.save_png(save_path)
	return ImageTexture.create_from_image(image)

func get_emission_textrue(save_path: String = "") -> ImageTexture:
	var image := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	for x in 256:
		var color := colors[x] * materials[x].emission if materials.has(x) else Color.BLACK
		color.a = 1
		image.set_pixel(x, 0, color)
	if save_path:
		image.save_png(save_path)
	return ImageTexture.create_from_image(image)


class VoxelModel:
	var size: Vector3
	
	var voxels: Dictionary[Vector3i, int]
	
	func merge_Voxels(target_voxels: Dictionary[Vector3i, int]):
		var offset: Vector3i = (size / 2).floor()
		for pos in voxels:
			target_voxels[pos - offset] = voxels[pos]


class VoxelMaterial:
	var type: String

	var trans: float = 0

	var metal: float = 0

	var specular: float = 0.5

	var roughness: float = 1

	var emission: float = 0

	var flux: float = 1

	var refraction: float = 0.5

class VoxelNode:
	var id: int
	
	var attributes: Dictionary[String, String]
	
	var layerId := -1
	
	var child_nodes: Array[int]
	
	var frames: Array[VoxelFrame]
	
	var voxels: Dictionary[Vector3i, int]

	func get_frame(index: int) -> VoxelFrame:
		if index >= frames.size():
			frames.resize(index + 1)
		if not frames[index]:
			frames[index] = VoxelFrame.new()
		return frames[index]
	
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
