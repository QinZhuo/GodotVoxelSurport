@tool
class_name VoxelArrayMeshImporter
extends EditorImportPlugin

func _get_importer_name():
	return 'voxel_surport.voxel.array_mesh'

func _get_visible_name():
	return 'ArrayMesh'

func _get_recognized_extensions():
	return ['voxel']

func _get_save_extension():
	return 'mesh'

func _get_resource_type():
	return 'Mesh'

func _get_preset_count():
	return 0

func _get_preset_name(_preset):
	return 'Default'

func _get_import_options(path, preset):
	return [
		{
			name = 'scale',
			default_value = 0.1,
		},
		{
			name = 'from_path',
			default_value = '',
			property_hint = PROPERTY_HINT_GLOBAL_FILE,
		},
	]

func _get_option_visibility(path, option, options):
	return true

func _import(source_file, save_path, options: Dictionary, _platforms, gen_files):
	var from_path: String = options["from_path"]
	var voxel: VoxelData
	if from_path:
		var vox := VoxAccess.Open(from_path)
		if vox:
			voxel = vox.voxel_data
		voxel.get_voxels()
	if not voxel:
		return FAILED
	var mesh: ArrayMesh = VoxelMeshGenerator.new().generate(voxel, options['scale'])
	if not mesh:
		return FAILED
	return ResourceSaver.save(mesh, "%s.%s" % [save_path, _get_save_extension()])

#const TEMP_PATH := "res://.godot/imported/{}_temp.tres"

# static func save(voxel: VoxelData, path: String):
# 	ResourceSaver.save(voxel, TEMP_PATH)
# 	_copy(TEMP_PATH, path)


# static func load(path: String) -> VoxelData:
# 	var time = Time.get_ticks_usec()
# 	_copy(path, TEMP_PATH)
# 	var voxel: VoxelData = ResourceLoader.load(TEMP_PATH)
# 	prints("load voxel data time:", (Time.get_ticks_usec() - time) / 1000.0, "ms", voxel.voxels.size(), "voxels")
# 	return voxel

# static func _copy(file_path: String, target_path: String):
# 	var file := FileAccess.open(target_path, FileAccess.WRITE)
# 	if file:
# 		file.store_buffer(FileAccess.get_file_as_bytes(file_path))
# 		file.close()
