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
		{
			name = import_albedo_textrue,
			default_value = false
		},
		{
			name = import_metal_textrue,
			default_value = false
		},
		{
			name = import_rough_textrue,
			default_value = false
		},
		{
			name = import_emission_textrue,
			default_value = false
		},
	]

const import_albedo_textrue := "import_albedo_textrue"
const import_metal_textrue := "import_metal_textrue"
const import_rough_textrue := "import_rough_textrue"
const import_emission_textrue := "import_emission_textrue"
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
	
	prints("generate mesh: ", (Time.get_ticks_usec() - time) / 1000.0, "ms", mesh.get_faces().size() / 6, "face")
	var material := (mesh.surface_get_material(0) as StandardMaterial3D)
	var tex_path := "{0}_albedo.png".format([source_file.trim_suffix(".vox")]) if options[import_albedo_textrue] else ""
	material.albedo_texture = vox.voxel_data.get_albedo_textrue(tex_path)
	tex_path = "{0}_metal.png".format([source_file.trim_suffix(".vox")]) if options[import_metal_textrue] else ""
	material.metallic_texture = vox.voxel_data.get_metal_textrue(tex_path)
	tex_path = "{0}_rough.png".format([source_file.trim_suffix(".vox")]) if options[import_rough_textrue] else ""
	material.roughness_texture = vox.voxel_data.get_rough_textrue(tex_path)
	material.emission_enabled = true
	tex_path = "{0}_emission.png".format([source_file.trim_suffix(".vox")]) if options[import_emission_textrue] else ""
	material.emission_texture = vox.voxel_data.get_emission_textrue(tex_path)
	material.emission_energy_multiplier = 16
	return ResourceSaver.save(mesh, "%s.%s" % [save_path, _get_save_extension()])
