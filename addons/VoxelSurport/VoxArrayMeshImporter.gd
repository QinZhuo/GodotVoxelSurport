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
			name = 'Scale',
			default_value = 0.1
		},
		{
			name = 'albedo textrue',
			default_value = false
		},
		{
			name = 'rough textrue',
			default_value = false
		},
		{
			name = 'roughs textrue',
			default_value = false
		},
	]

func _get_option_visibility(path, option, options):
	return true

func _import(source_file, save_path, options, _platforms, _gen_files):
	var time = Time.get_ticks_usec()
	var vox := VoxFile.Open(source_file)
	if not vox:
		return FAILED
	prints("load .vox time:", (Time.get_ticks_usec() - time) / 1000.0, "ms")
	var voxels := vox.voxel_data.get_voxels()
	prints("get voxels time:", (Time.get_ticks_usec() - time) / 1000.0, "ms", voxels.size(), "voxels")
	var mesh: ArrayMesh = VoxelMeshGenerator.new().generate(vox.voxel_data, 0.1)
	if not mesh:
		return FAILED
	var material := (mesh.surface_get_material(0) as StandardMaterial3D)
	material.albedo_texture = vox.voxel_data.get_albedo_textrue()
	prints("generate mesh: ", (Time.get_ticks_usec() - time) / 1000.0, "ms", mesh.get_faces().size() / 6, "face")
	return ResourceSaver.save(mesh, "%s.%s" % [save_path, _get_save_extension()])
