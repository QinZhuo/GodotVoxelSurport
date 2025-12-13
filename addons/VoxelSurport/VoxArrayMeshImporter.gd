@tool
class_name VoxArrayMeshImporter
extends EditorImportPlugin

func _get_importer_name():
	return 'voxel_surport.vol.array_mesh'

func _get_visible_name():
	return 'ArrayMesh'

func _get_recognized_extensions():
	return ['vox']

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
			default_value = 0.1
		},
	]

func _get_option_visibility(path, option, options):
	return true

func _import(source_file, save_path, options, _platforms, gen_files):
	var mesh: ArrayMesh = VoxelMeshGenerator.new().generate(VoxAccess.Open(source_file).voxel_data, options['scale'])
	if not mesh:
		return FAILED

	return ResourceSaver.save(mesh, "%s.%s" % [save_path, _get_save_extension()])
