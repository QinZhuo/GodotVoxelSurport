@tool
class_name LinkVoxArrayMeshImporter
extends LinkResImporter

func _get_importer_name():
	return str(super._get_importer_name(), '.vol.array_mesh')

func _get_resource_type():
	return 'ArrayMesh'

func _get_import_options(path, preset):
	return [
		{
			name = 'link_path',
			default_value = '',
			property_hint = PROPERTY_HINT_GLOBAL_FILE,
			hint_string = "*.vox"
		},
		{
			name = 'scale',
			default_value = 0.1,
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
	var mesh: ArrayMesh = VoxelMeshGenerator.new().generate(voxel, options['scale'])
	if not mesh:
		return _load_res(save_path, source_file)
	return _save_res(mesh, save_path, source_file)
