@tool
extends EditorPlugin

var importers: Array[EditorImportPlugin]

func _enter_tree():
	importers.append(VoxArrayMeshImporter.new())
	importers.append(LinkVoxImporter.new())
	importers.append(LinkVoxMaterialImporter.new())
	importers.append(LinkVoxArrayMeshImporter.new())
	for importer in importers:
		add_import_plugin(importer)

func _exit_tree():
	for importer in importers:
		remove_import_plugin(importer)
