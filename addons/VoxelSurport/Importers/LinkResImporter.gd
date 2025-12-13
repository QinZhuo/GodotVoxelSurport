@tool
class_name LinkResImporter
extends EditorImportPlugin

func _get_importer_name():
	return 'voxel_surport.link_res'

func _get_visible_name():
	return _get_resource_type()

func _get_recognized_extensions():
	return ['lres']

func _get_save_extension():
	return 'res'

func _get_resource_type():
	return 'Resource'

func _get_preset_count():
	return 0

func _get_preset_name(_preset):
	return 'Default'

func _get_import_options(path, preset):
	return [
		{
			name = 'link_path',
			default_value = '',
			property_hint = PROPERTY_HINT_GLOBAL_FILE,
			hint_string = "*.*"
		},
	]

func _get_option_visibility(path, option, options):
	return true

func _import(source_file, save_path, options, _platforms, _gen_files):
	var link_path: String = options["link_path"]
	var res: Resource
	if link_path:
		res = ResourceLoader.load(link_path)
	if not res:
		return _load_res(save_path, source_file)
	return _save_res(res, save_path, source_file)
 
func _load_res(save_path: String, source_path: String) -> Error:
	var path := str(save_path, '.', _get_save_extension())
	_copy(source_path, path)
	prints("load link path file failed.  source file:", source_path)
	return Error.OK if ResourceLoader.load(path) != null else Error.FAILED

func _save_res(res: Resource, save_path: String, source_path: String):
	var path := str(save_path, '.', _get_save_extension())
	var result := ResourceSaver.save(res, path)
	if result == Error.OK:
		_copy(path, source_path)
	return result

func _copy(file_path: String, target_path: String):
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file:
		file.store_buffer(FileAccess.get_file_as_bytes(file_path))
		file.close()