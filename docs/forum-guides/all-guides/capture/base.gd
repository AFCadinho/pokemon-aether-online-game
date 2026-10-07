extends SceneTree

var view: SubViewport
var overlay: Node
var out: String
var records: Array = []
var map: Node

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	pass

func setup() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() >= 1)
	out = args[0]
	assert(not root.get_node("AuthService").is_authenticated(), "Captures must not use a player session")
	root.get_node("LocalizationManager").set_locale("en")
	root.get_node("SettingsManager").battle_presentation_mode = "2d"
	view = SubViewport.new()
	view.size = Vector2i(1920,1080)
	view.gui_embed_subwindows = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(view)
	map = load("res://generated/tiled_visuals/pallet_town_compact/pallet_town_compact.visual.tscn").instantiate()
	view.add_child(map)
	var camera := Camera2D.new()
	camera.position = Vector2(850,650)
	camera.zoom = Vector2.ONE * 2
	view.add_child(camera)
	camera.make_current()
	overlay = load("res://scenes/interface/ui_overlay.tscn").instantiate()
	overlay.custom_viewport = view
	view.add_child(overlay)
	await settle()
	overlay.set_process(false)
	clear()

func clear() -> void:
	for child in (overlay.get("root_control") as Control).get_children():
		if child is CanvasItem:
			child.hide()
	for child in view.get_children():
		if child is Control:
			child.hide()

func center(node: Control) -> void:
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.position = (Vector2(view.size) - node.size) * 0.5

func settle() -> void:
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw

func shot(topic: int, key: String, node: Control, caption: String, heading: String) -> void:
	node.show()
	await settle()
	var bounds := node.get_global_rect().grow(12)
	var region := Rect2i(Vector2i(bounds.position), Vector2i(bounds.size)).intersection(Rect2i(Vector2i.ZERO, view.size))
	assert(region.size.x > 100 and region.size.y > 100)
	var folder := out.path_join(str(topic))
	DirAccess.make_dir_recursive_absolute(folder)
	var picture := view.get_texture().get_image()
	assert(picture.get_region(region).save_png(folder.path_join(key + ".png")) == OK)
	var full := ProjectSettings.globalize_path("res://.tmp/all-guides/full").path_join(str(topic))
	DirAccess.make_dir_recursive_absolute(full)
	assert(picture.save_png(full.path_join(key + "-full.png")) == OK)
	records.append({"topic": topic, "filename": key + ".png", "caption": caption, "heading": heading, "size": [region.size.x, region.size.y], "control": str(node.name), "exampleData": true})
	print("CAPTURE ",topic," ",key)

func finish(group: String) -> void:
	var file := FileAccess.open(out.path_join("captures-" + group + ".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(records,"\t") + "\n")
	print("CAPTURE_GROUP_OK ",group," ",records.size())
	quit(0)

func sample_pokemon() -> Pokemon:
	var pokemon := Pokemon.new("bulbasaur",15,"","overgrow","Modest",{},
		{"hp":31,"atk":24,"def":28,"spa":31,"spd":30,"spe":25},
		{"hp":43,"atk":20,"def":23,"spa":31,"spd":29,"spe":22},
		[{"id":"tackle","name":"Tackle","type":"normal","category":"physical","basePower":40,"pp":35},
		{"id":"growl","name":"Growl","type":"normal","category":"status","basePower":0,"pp":40},
		{"id":"vinewhip","name":"Vine Whip","type":"grass","category":"physical","basePower":45,"pp":25}],
		"example-pokemon",101,false,false,["grass","poison"],["overgrow","chlorophyll"],"Pallet Town",
		{"originalTrainerName":"Example Trainer","locationName":"Pallet Town","metLevel":5},true,
		{"hp":4,"spa":40,"spe":20})
	pokemon.current_level_exp = 3200
	pokemon.next_level_exp = 4000
	pokemon.experience = 3650
	pokemon.happiness = 120
	pokemon.max_hp = 43
	pokemon.current_hp = 43
	return pokemon

func read_fixture(name: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string("res://docs/forum-guides/all-guides/capture/" + name))

func shot_window(topic: int, key: String, window: Window, caption: String, heading: String) -> void:
	window.show()
	await settle()
	var bounds := Rect2(Vector2(window.position),Vector2(window.size)).grow(12)
	var region := Rect2i(Vector2i(bounds.position),Vector2i(bounds.size)).intersection(Rect2i(Vector2i.ZERO,view.size))
	var folder := out.path_join(str(topic))
	DirAccess.make_dir_recursive_absolute(folder)
	var picture := view.get_texture().get_image()
	assert(picture.get_region(region).save_png(folder.path_join(key + ".png")) == OK)
	records.append({"topic":topic,"filename":key + ".png","caption":caption,"heading":heading,"size":[region.size.x,region.size.y],"control":str(window.name),"exampleData":true})
	print("CAPTURE ",topic," ",key)
