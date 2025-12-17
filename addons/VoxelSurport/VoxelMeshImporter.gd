@tool
class_name VoxelMeshImporter
extends EditorImportPlugin

func _get_importer_name():
	return 'voxel_mesh'

func _get_visible_name():
	return "Voxel Mesh"

func _get_recognized_extensions():
	return ['vox']

func _get_save_extension():
	return "mesh"

func _get_resource_type():
	return 'Mesh'

func _get_import_options(path, preset):
	return [
		{
			name = mesh_mode,
			default_value = MeshMode.Merge,
			property_hint = PropertyHint.PROPERTY_HINT_ENUM,
			hint_string = "Merge,Default"
		},
		{
			name = scale,
			default_value = 0.1,
		},
		{
			name = frame_index,
			default_value = 0,
		},
		{
			name = unwrap_lightmap_uv2,
			default_value = false,
		},
		{
			name = import_materials_textures,
			default_value = false,
		},
		{
			name = material_path,
			default_value = "",
			property_hint = PropertyHint.PROPERTY_HINT_FILE,
			hint_string = "*tres,*res"
		},
		{
			name = material_trans_path,
			default_value = "",
			property_hint = PropertyHint.PROPERTY_HINT_FILE,
			hint_string = "*tres,*res"
		},
	]

const frame_index := "mesh/frame_index"
const mesh_mode := "mesh/mode"
const scale := "mesh/scale"
const unwrap_lightmap_uv2 := "mesh/unwrap_lightmap_uv2"
const material_path := "material_path/material_path"
const material_trans_path := "material_path/material_trans_path"
const import_materials_textures := "material_path/import_materials_textures"

enum MeshMode {
	Merge,
	Default,
}

func _import(source_file, save_path, options, _platforms, gen_files):
	var mesh: ArrayMesh
	mesh = VoxelMeshGenerator.new().generate(VoxAccess.Open(source_file).voxel, options, source_file)
	if not mesh:
		return FAILED
	return ResourceSaver.save(mesh, "%s.%s" % [save_path, _get_save_extension()])
