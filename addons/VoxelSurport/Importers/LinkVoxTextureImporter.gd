@tool
class_name LinkVoxMaterialImporter
extends LinkResImporter

func _get_importer_name():
	return str(super._get_importer_name(), '.vol.material')

func _get_resource_type():
	return 'Material'

func _get_import_options(path, preset):
	return [
		{
			name = 'link_path',
			default_value = '',
			property_hint = PROPERTY_HINT_GLOBAL_FILE,
			hint_string = "*.vox"
		},
	]

func _import(source_file, save_path, options: Dictionary, _platforms, gen_files):
	var from_path: String = options["link_path"]
	var voxel: VoxelData
	if from_path:
		var vox := VoxAccess.Open(from_path)
		if vox:
			voxel = vox.voxel_data
			voxel.get_voxels()
	if not voxel:
		return _load_res(save_path, source_file)
	var material := voxel.get_material()
	return _save_res(material, save_path, source_file)
