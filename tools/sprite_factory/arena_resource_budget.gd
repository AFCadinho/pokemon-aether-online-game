extends SceneTree
## Inspect all retained art dependencies, including textures embedded in scenes.
const Catalog = preload("res://scripts/battle/arenas/arena_catalog.gd")
var seen := {}
var textures: Array[Dictionary] = []
func _init() -> void:
	_run.call_deferred()
func _visit(value: Variant, owner: String) -> void:
	if value is Resource:
		var id: int = value.get_instance_id()
		if seen.has(id):
			return
		seen[id] = true
		if value is Texture2D:
			var image: Image = value.get_image()
			var row := {"class":value.get_class(),"path":value.resource_path,"owner":owner,
				"width":value.get_width(),"height":value.get_height()}
			if image != null:
				row.format = image.get_format()
				row.compressed = image.is_compressed()
				row.image_bytes = image.get_data_size()
				row.mipmaps = image.get_mipmap_count()
			textures.append(row)
			return
		for property: Dictionary in value.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_STORAGE:
				_visit(value.get(property.name),owner)
	elif value is Array:
		for item in value:
			_visit(item,owner)
	elif value is Dictionary:
		for item in value.values():
			_visit(item,owner)
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=2:
		push_error("Requires candidate manifest and report path")
		quit(1)
		return
	var error := Catalog.prepare_forest(args[0])
	if not error.is_empty():
		push_error(error)
		quit(1)
		return
	var deadline := Time.get_ticks_msec()+60000
	while not Catalog.forest_ready() and Catalog.forest_error.is_empty() and Time.get_ticks_msec()<deadline:
		await process_frame
	if not Catalog.forest_ready():
		push_error("Resource loading failed: " + Catalog.forest_error)
		quit(1)
		return
	for path: String in Catalog.Art.resources:
		_visit(Catalog.Art.resources[path],path)
	textures.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return int(a.get("image_bytes",0))>int(b.get("image_bytes",0)))
	var file := FileAccess.open(args[1],FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"roots":Catalog.Art.resources.size(),"textures":textures,
		"limit":"Decoded/encoded Image bytes, not measured GPU residency. Includes retained, possibly unused, scene subresources."},"\t"))
	file.close()
	print("ARENA_RESOURCE_BUDGET_OK roots=",Catalog.Art.resources.size()," textures=",textures.size())
	quit()
