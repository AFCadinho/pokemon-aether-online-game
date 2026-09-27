extends SceneTree

const Wind := preload("res://addons/tiled_tmx_importer/importer/tmx_tall_grass_wind.gd")
const FP := preload("res://tests/support/visual_atlas_fingerprint.gd")
const Compactor := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_compactor.gd")
const Validator := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd")
var failures: Array[String]=[]
var checked_cells := 0
var checked_frames := 0

func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/tall_grass_standard_report.json"))
	for id in report.maps:
		var path := "res://generated/tiled_visuals/%s/%s.visual.tscn" % [id,id]
		var root := (load(path) as PackedScene).instantiate()
		var actual := FP.new().capture(root)
		_check(actual.fingerprint==report.maps[id].before.fingerprint,"Original image/layout/TileData: "+id)
		_check(preload("res://tools/standardize_tall_grass.gd").existing_timelines(root)==report.maps[id].existing_animation_fingerprint,"Existing native timelines: "+id)
		_check_grass(root,int(report.maps[id].grass_cells))
		failures.append_array(Validator.new().validate(root,path.trim_suffix(".tscn")+".tileset.tres"))
		root.free()
	# A freshly painted static grass tile must receive native grouped animation
	# automatically, without a custom TSX or manually selecting phase variants.
	var dir := "user://default_grass_import_check"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var image := Image.load_from_file(Wind.IMAGES[Wind.PIXELS_SHA256])
	image.save_png(dir+"/grass.png")
	var tmx := '<map orientation="orthogonal" width="4" height="4" tilewidth="32" tileheight="32"><tileset firstgid="1" name="grass" tilewidth="32" tileheight="32" tilecount="56" columns="8"><image source="grass.png" width="256" height="224"/></tileset><layer id="1" name="Grass" width="4" height="4"><data encoding="csv">2147483649,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1</data></layer></map>'
	FileAccess.open(dir+"/input.tmx",FileAccess.WRITE).store_string(tmx)
	var result := preload("res://addons/tiled_tmx_importer/importer/tmx_visual_importer.gd").new().import_tmx(ProjectSettings.globalize_path(dir+"/input.tmx"),dir+"/output.visual.tscn")
	_check(result.get("success",false),"Default importer recognizes static grass")
	if result.get("success",false):
		var root := (ResourceLoader.load(dir+"/output.visual.tscn","PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene).instantiate()
		_check_grass(root,16)
		_check(((root.get_child(0) as TileMapLayer).get_cell_alternative_tile(Vector2i.ZERO) & 4096)!=0,"Flipped cells retain their transform")
		root.free()
	for failure in failures:push_error(failure)
	print("TALL_GRASS_WIND_CHECK ",JSON.stringify({"maps":report.maps.size(),"cells":checked_cells,"frames":checked_frames,"success":failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func _check_grass(root: Node,expected: int) -> void:
	var layers: Array[TileMapLayer]=[]
	Compactor.new()._collect(root,layers)
	var seen := {};var count := 0;var timings := {}
	for layer in layers:
		for cell in layer.get_used_cells():
			var sid := layer.get_cell_source_id(cell)
			var source := layer.tile_set.get_source(sid) as TileSetAtlasSource
			var coords := layer.get_cell_atlas_coords(cell)
			var family: String=source.get_meta("pao_tall_grass_family","")
			if not Wind.IMAGES.has(family):continue
			count+=1;checked_cells+=1
			var phase := Wind.phase_at(cell)
			_check(is_equal_approx(source.get_tile_animation_frame_duration(coords,0),Wind.PAUSES[phase]/1000.0),"Correct group phase at "+str(cell))
			if seen.has(sid):continue
			seen[sid]=true
			var image := source.texture.get_image();image.convert(Image.FORMAT_RGBA8)
			var reference := Image.load_from_file(Wind.IMAGES[family]);reference.convert(Image.FORMAT_RGBA8)
			_check(source.get_tile_animation_frames_count(coords)==50,"50 timeline frames")
			var duration := 0.0
			for f in 50:
				var n := 4 if f==0 or f==49 else 4+f
				var correct := reference.get_region(Rect2i(n%8*32,n/8*32,32,32))
				_check(image.get_region(source.get_tile_texture_region(coords,f)).get_data()==correct.get_data(),"Approved frame artwork")
				duration+=source.get_tile_animation_frame_duration(coords,f)
				checked_frames+=1
			_check(is_equal_approx(duration,7.56),"Approved period")
	_check(count==expected,"Expected grass cells: "+str(expected)+", actual "+str(count))
func _check(condition: bool,message: String) -> void:
	if not condition:failures.append(message)
