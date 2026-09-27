extends SceneTree

const Wind := preload("res://addons/tiled_tmx_importer/importer/tmx_tall_grass_wind.gd")
const Compactor := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_compactor.gd")
const FP := preload("res://tests/support/visual_atlas_fingerprint.gd")
const Validator := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd")
const REPORT := "res://tools/tall_grass_standard_report.json"
var failed := false

func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var apply := "--apply" in OS.get_cmdline_user_args()
	var records := {}
	for id in DirAccess.get_directories_at("res://generated/tiled_visuals"):
		if id.ends_with("_test"):continue
		var path := _path(id)
		var root := _load(path)
		var before := FP.new().capture(root)
		var old_animation := existing_timelines(root)
		var plan := Wind.new().apply(root)
		if plan.cells == 0:
			root.free();continue
		var stage := "user://tall_grass_standard/"+id+"/"+id+".visual.tscn"
		var result := _save(root,stage,plan.animations)
		root.free()
		if not result.get("success",false):_fail(str(result));return
		var after := _verify(stage,before,old_animation)
		if failed:return
		records[id]={"before":before,"after":after,"grass_cells":plan.cells,"phase_counts":plan.phase_counts,"existing_animation_fingerprint":old_animation}
		print("GRASS_STAGE ",id," ",plan.cells)
	if apply and not records.is_empty():
		var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/tiled/migrated_visual_fingerprints.json"))
		var prior: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/map_animation_rollout_report.json"))
		for id in records:
			var path := _path(id)
			var root := _load(path)
			var plan := Wind.new().apply(root)
			var result := _save(root,path,plan.animations)
			root.free()
			if not result.get("success",false):_fail(str(result));return
			var actual := _verify(path,records[id].before,records[id].existing_animation_fingerprint)
			if failed:return
			if baseline.has(id):
				assert(baseline[id].fingerprint==actual.fingerprint)
				baseline[id].baseRGBABytes=actual.baseRGBABytes
				baseline[id].usedTiles=actual.usedTiles
			if prior.maps.has(id):
				prior.maps[id].current_static_reference=actual
				prior.maps[id].after=actual
		_write("res://tests/fixtures/tiled/migrated_visual_fingerprints.json",baseline)
		_write("res://tools/map_animation_rollout_report.json",prior)
		_write(REPORT,{"version":1,"maps":records})
	print("TALL_GRASS_STANDARD ",JSON.stringify({"maps":records.size(),"applied":apply,"success":true}))
	quit()

static func existing_timelines(root: Node) -> String:
	# Every existing non-grass animation must retain pixels, durations, speed,
	# and its cell placement after atlas repacking.
	var layers: Array[TileMapLayer]=[]
	Compactor.new()._collect(root,layers)
	var images := {};var signatures := {};var records: Array=[]
	for layer in layers:
		var cells := layer.get_used_cells()
		cells.sort_custom(func(a,b): return a.y<b.y or (a.y==b.y and a.x<b.x))
		for cell in cells:
			var sid := layer.get_cell_source_id(cell)
			var source := layer.tile_set.get_source(sid) as TileSetAtlasSource
			var coords := layer.get_cell_atlas_coords(cell)
			var count := source.get_tile_animation_frames_count(coords)
			if count<2:continue
			var key := str(sid)+str(coords)
			if not signatures.has(key):
				if not images.has(sid):
					var image := source.texture.get_image();image.convert(Image.FORMAT_RGBA8);images[sid]=image
				var first := FP.new()._hash(images[sid].get_region(source.get_tile_texture_region(coords)).get_data())
				if Wind.IMAGES.has(first):
					signatures[key]=[];continue
				var frames: Array=[]
				for f in count:
					frames.append([FP.new()._hash(images[sid].get_region(source.get_tile_texture_region(coords,f)).get_data()),roundi(source.get_tile_animation_frame_duration(coords,f)*1000000/source.get_tile_animation_speed(coords))])
				signatures[key]=frames
			if not signatures[key].is_empty():records.append([str(layer.name),str(cell),layer.get_cell_alternative_tile(cell),signatures[key]])
	return FP.new()._hash(JSON.stringify(records).to_utf8_buffer())

func _verify(path: String,before: Dictionary,animations: String) -> Dictionary:
	var root := _load(path)
	var after := FP.new().capture(root)
	var errors := Validator.new().validate(root,path.trim_suffix(".tscn")+".tileset.tres")
	var unchanged := existing_timelines(root)==animations
	root.free()
	if after.fingerprint!=before.fingerprint or after.cells!=before.cells or after.layers!=before.layers or not unchanged or not errors.is_empty():
		_fail("Map/artwork/TileData or existing animation changed: "+path+str(errors)+" timelines="+str(unchanged));return {}
	return after
func _save(root: Node,path: String,animations: Dictionary) -> Dictionary:
	var result := Compactor.new().compact(root,path.trim_suffix(".tscn")+".tileset.tres",animations)
	if not result.get("success",false):return result
	var packed := PackedScene.new();var err := packed.pack(root)
	if err==OK:err=ResourceSaver.save(packed,path)
	return {"success":err==OK,"error":error_string(err)}
func _load(path: String) -> Node:
	return (ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene).instantiate()
func _path(id: String) -> String:
	return "res://generated/tiled_visuals/%s/%s.visual.tscn" % [id,id]
func _write(path: String,data: Dictionary) -> void:
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(data,"\t",true)+"\n")
func _fail(message: String) -> void:
	failed=true;push_error(message);quit(1)
