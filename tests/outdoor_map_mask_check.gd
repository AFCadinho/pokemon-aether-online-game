extends SceneTree

const OutdoorMask := preload("res://scripts/world/outdoor_map_mask.gd")
const MapMetadata := preload("res://scripts/world/map_metadata.gd")
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for fixture: Array in [
		["towns/test/test.tscn", "exterior", true],
		["routes/test.tscn", "route", true],
		["towns/test/house.tscn", "interior", false],
		["routes/gate.tscn", "transition", false],
		["caves/test.tscn", "exterior", false],
		["guild_base/test.tscn", "exterior", false],
	]:
		var map := Node2D.new()
		map.set_script(MapMetadata)
		map.scene_file_path = "res://scenes/overworld/kanto/" + str(fixture[0])
		map.set("world_access_area_type", fixture[1])
		map.position = Vector2(96, -64)
		root.add_child(map)
		var bounds := Rect2(128, 0, 320, 256)
		OutdoorMask.apply(map, bounds)
		var mask := map.get_node_or_null("OutdoorMapMask")
		_check((mask != null) == bool(fixture[2]), str(fixture[0]) + " scope")
		if mask != null:
			_check(mask.get_active_floor_region() == Rect2(32, 64, 320, 256), "Map offset is respected")
			_check(not mask.follow_player_floor and not mask.constrain_camera_to_active_floor, "Outdoor mask leaves camera and floors alone")
			_check(mask.z_index == 4096 and not mask.z_as_relative, "Border covers world actors")
			for side: String in ["Top", "Bottom", "Left", "Right"]:
				var polygon: Polygon2D = mask.get_node(side)
				_check(polygon.color == Color.BLACK, side + " is black")
				for point: Vector2 in polygon.polygon:
					_check(not Rect2(32.01, 64.01, 319.98, 255.98).has_point(point), "Mask preserves map interior")
			# Simulate viewport corners at the supported zooms and aspect ratios.
			for viewport_size: Vector2 in [Vector2(1280, 720), Vector2(2560, 1080), Vector2(720, 1280)]:
				for zoom: float in [0.5, 1.0, 1.5, 2.0]:
					for direction: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2.ZERO]:
						var point := Vector2(192, 192) + direction * viewport_size / (2.0 * zoom)
						var covered := false
						for side: String in ["Top", "Bottom", "Left", "Right"]:
							var polygon: Polygon2D = mask.get_node(side)
							covered = covered or Geometry2D.is_point_in_polygon(point, polygon.polygon)
						_check(covered == not Rect2(32, 64, 320, 256).has_point(point), "Zoom/aspect corners outside map are masked")
			OutdoorMask.apply(map, bounds)
			_check(map.get_node("OutdoorMapMask") == mask, "Repeated camera setup reuses mask")
		map.free()
	print("OUTDOOR_MAP_MASK ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
