@tool
class_name VoxArrayMeshImporter
extends EditorImportPlugin

func _get_importer_name():
	return 'voxel_surport.vol.array_mesh'

func _get_visible_name():
	return _get_resource_type()

func _get_recognized_extensions():
	return ['vox']

func _get_save_extension():
	return "res"

func _get_resource_type():
	return 'ArrayMesh'

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
		{
			name = 'material',
            default_value = "",
            property_hint = PROPERTY_HINT_FILE,
            hint_string = "*.lres,*.res,*.tres"
		}
	]

func _get_option_visibility(path, option, options):
	return true

func _import(source_file, save_path, options, _platforms, gen_files):
	var mesh: ArrayMesh = VoxelMeshGenerator.new().generate(VoxAccess.Open(source_file).voxel_data, options['scale'])
	if not mesh:
		return FAILED
	if options["material"]:
		var material := ResourceLoader.load(options["material"])
		mesh.surface_set_material(0, material)
	return ResourceSaver.save(mesh, "%s.%s" % [save_path, _get_save_extension()])
