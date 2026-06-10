extends CharacterBody2D

const TILE_SIZE := 32
const MOVE_SPEED := 160.0
const SORT_Z_MIN := -256
const SORT_Z_MAX := 256

@onready var body_sprite: AnimatedSprite2D = $Look/BodySprite
@onready var hair_sprite: AnimatedSprite2D = $Look/HairSprite
@onready var feet_marker: Marker2D = $FeetMarker

# TileMapLayer nodes die speciale map-informatie bevatten.
# Collision bevat de onzichtbare/blokkerende tegels.
# TallGrass kan later gebruikt worden voor encounters/effects.
var collision_tilemap: TileMapLayer
var grass_tilemap: TileMapLayer

# Movement state.
# is_moving voorkomt dat je nieuwe input verwerkt terwijl de speler nog naar
# de volgende tile aan het lopen is.
var is_moving := false

# target_position is een wereldpositie in pixels.
# De speler beweegt hier soepel naartoe met move_toward().
var target_position := Vector2.ZERO

# Onthoudt de laatste kijkrichting, zodat de idle frame goed blijft staan.
var last_direction := Vector2.DOWN

func get_feet_position() -> Vector2:
	return feet_marker.global_position

func face_world_position(world_position: Vector2) -> void:
	var delta := world_position - get_feet_position()
	if delta == Vector2.ZERO:
		return
	
	if abs(delta.x) > abs(delta.y):
		last_direction = Vector2.RIGHT if delta.x > 0 else Vector2.LEFT
	else:
		last_direction = Vector2.DOWN if delta.y > 0 else Vector2.UP
	
	set_idle_frame()

func _ready() -> void:
	# Haal de TileMapLayer nodes uit de huidige map op.
	# Dit werkt alleen als GameState.current_map al naar de actieve map wijst.
	if GameState.current_map != null:
		grass_tilemap = GameState.current_map.get_node("TallGrass")
		collision_tilemap = GameState.current_map.get_node("Collision")
	
	# Zet speler terug op laatst bekende positie in de juiste richting.
	if GameState.has_player_position:
		global_position = GameState.player_position
		last_direction = GameState.player_direction
	
	# De eerste target is waar de speler nu al staat.
	# Daardoor begint hij niet meteen ergens heen te bewegen.
	target_position = global_position
	_update_sort_z()

func _physics_process(delta: float) -> void:	
	_update_sort_z()

	if is_moving:
		# Beweeg in pixels richting de target_position.
		# Dit is visueel vloeiend, ook al kies je targets per tile.
		global_position = global_position.move_toward(target_position, MOVE_SPEED * delta)
		_update_sort_z()

		# Als de bestemming is bereikt.
		if global_position == target_position:
			is_moving = false
			set_idle_frame()

			if check_for_map_exit():
				return
			
			if is_standing_on_tall_grass():
				check_for_grass_encounter()
		return

	if GameState.input_locked:
		set_idle_frame()
		return

	if _is_ui_typing():
		set_idle_frame()
		return
		
	# Bepaal welke richting de speler op wilt lopen.
	var direction := Vector2.ZERO
	if Input.is_action_pressed("move_right"):
		direction = Vector2.RIGHT
	elif Input.is_action_pressed("move_left"):
		direction = Vector2.LEFT
	elif Input.is_action_pressed("move_down"):
		direction = Vector2.DOWN
	elif  Input.is_action_pressed("move_up"):
		direction = Vector2.UP

	if direction != Vector2.ZERO:
		last_direction = direction
		play_walk_animation(direction)

		# Bepaal de volgende wereldpositie.
		# Voorbeeld: Vector2.RIGHT * 32 = Vector2(32, 0), dus 1 tile naar rechts.
		var new_target_position := global_position + (direction * TILE_SIZE)

		# Check eerst of de target tile vrij is.
		# Alleen als can_move_to true teruggeeft, starten we de beweging.
		if can_move_to(new_target_position):
			target_position = new_target_position
			is_moving = true
		else:
			set_idle_frame()

func play_walk_animation(direction: Vector2) -> void:
	var animation_name := ""

	if direction == Vector2.RIGHT:
		animation_name = "walk_right"
	elif direction == Vector2.LEFT:
		animation_name = "walk_left"
	elif direction == Vector2.DOWN:
		animation_name = "walk_down"
	elif direction == Vector2.UP:
		animation_name = "walk_up"

	body_sprite.play(animation_name)
	hair_sprite.play(animation_name)

func can_move_to(check_position: Vector2) -> bool:
	refresh_map_layers()

	if collision_tilemap == null:
		push_warning("Player.can_move_to: Collision TileMapLayer is missing; allowing movement as fallback.")
		return true
	
	var current_map: Node = _resolve_current_map()
	if current_map != null and current_map.has_method("is_position_blocked_by_character"):
		if current_map.is_position_blocked_by_character(check_position):
			return false
	
	# check_position is een global/world pixelpositie.
	# TileMapLayer.local_to_map() verwacht juist een lokale positie binnen die TileMapLayer.
	# Daarom zetten we eerst world -> local om.
	var local_position := collision_tilemap.to_local(check_position)

	# Zet de lokale pixelpositie om naar een tile/grid coördinaat.
	# Voorbeeld bij 32x32 tiles: lokale pixelpositie (64, 96) wordt ongeveer tile (2, 3).
	var tile_position := collision_tilemap.local_to_map(local_position)

	# Vraag tiledata op voor die tile.
	# In deze setup betekent: geen tile_data = geen collision tile = vrij lopen.
	# Wel tile_data = er ligt een collision tile = blokkeren.
	var source_id: int = collision_tilemap.get_cell_source_id(tile_position)
	if source_id != -1:
		return false

	var tile_data := collision_tilemap.get_cell_tile_data(tile_position)

	return tile_data == null
	
func set_idle_frame():
	body_sprite.stop()
	hair_sprite.stop()
	
	_set_idle_animation(body_sprite, last_direction)
	_set_idle_animation(hair_sprite, last_direction)
		
func refresh_map_layers() -> void:
	var current_map: Node = _resolve_current_map()
	if current_map == null:
		collision_tilemap = null
		grass_tilemap = null	
		push_warning("Player.refresh_map_layers: could not resolve current map.")
		return

	GameState.current_map = current_map
	collision_tilemap = current_map.get_node_or_null("Collision")
	grass_tilemap = current_map.get_node_or_null("TallGrass")

	if collision_tilemap == null:
		push_warning("Player.refresh_map_layers: Collision layer missing on %s." % current_map.name)
	
func is_standing_on_tall_grass() -> bool:
	if grass_tilemap == null:
		refresh_map_layers()

	if grass_tilemap == null:
		return false
		
	var local_position := grass_tilemap.to_local(global_position)
	var tile_position := grass_tilemap.local_to_map(local_position)
	var tile_data := grass_tilemap.get_cell_tile_data(tile_position)
	
	return tile_data != null
		
func check_for_grass_encounter() -> void:
	var current_map := GameState.current_map
	
	if current_map == null:
		return
		
	if not current_map.has_method("get_wild_encounter_area_id"):
		return
		
	var area_id: String = str(current_map.call("get_wild_encounter_area_id"))
	if area_id == "":
		return

	if current_map.has_method("should_trigger_wild_encounter"):
		if not bool(current_map.call("should_trigger_wild_encounter", "grass")):
			return
	
	var world := GameState.get_world()
	if world != null and world.has_method("start_triggered_wild_battle_for_area"):
		world.start_triggered_wild_battle_for_area(area_id, "grass")

func _is_ui_typing() -> bool:
	var focused_control := get_viewport().gui_get_focus_owner()
	return focused_control is LineEdit or focused_control is TextEdit

func check_for_map_exit() -> bool:
	var current_map: Node = _resolve_current_map()
	if current_map == null:
		return false

	var exits := current_map.get_node_or_null("Exits")
	if exits == null:
		return false

	for exit_node: Node in exits.get_children():
		if not (exit_node is Area2D):
			continue

		var exit_area := exit_node as Area2D
		if _is_inside_exit_area(exit_area):
			if exit_area.has_method("_on_body_entered"):
				exit_area.call("_on_body_entered", self)
				return true

	return false

func _is_inside_exit_area(exit_area: Area2D) -> bool:
	for child: Node in exit_area.get_children():
		if not (child is CollisionShape2D):
			continue

		var shape_node := child as CollisionShape2D
		if shape_node.disabled:
			continue

		var shape: Shape2D = shape_node.shape
		if shape is RectangleShape2D:
			var rectangle_shape := shape as RectangleShape2D
			var local_position := shape_node.to_local(global_position)
			var shape_rect := Rect2(-rectangle_shape.size * 0.5, rectangle_shape.size)
			if shape_rect.has_point(local_position):
				return true

	return false

func _resolve_current_map() -> Node:
	var parent_node := get_parent()
	while parent_node != null:
		if parent_node.get_node_or_null("Collision") != null or parent_node.get_node_or_null("TallGrass") != null:
			return parent_node

		parent_node = parent_node.get_parent()

	if GameState.current_map != null and is_instance_valid(GameState.current_map):
		return GameState.current_map

	return null

func _update_sort_z() -> void:
	z_index = clampi(floori(get_feet_position().y / TILE_SIZE), SORT_Z_MIN, SORT_Z_MAX)

func _set_idle_animation(sprite: AnimatedSprite2D, direction: Vector2) -> void:
	var animation_name := _get_idle_animation_name(direction)
	if animation_name != "" and sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)
		sprite.stop()
		return
	
	animation_name = _get_walk_animation_name(direction)
	if animation_name != "" and sprite.sprite_frames.has_animation(animation_name):
		sprite.animation = animation_name
		sprite.frame = 0
		sprite.stop()

func _get_idle_animation_name(direction: Vector2) -> String:
	if direction == Vector2.DOWN:
		return "idle_down"
	if direction == Vector2.UP:
		return "idle_up"
	if direction == Vector2.LEFT:
		return "idle_left"
	if direction == Vector2.RIGHT:
		return "idle_right"
	
	return ""

func _get_walk_animation_name(direction: Vector2) -> String:
	if direction == Vector2.DOWN:
		return "walk_down"
	if direction == Vector2.UP:
		return "walk_up"
	if direction == Vector2.LEFT:
		return "walk_left"
	if direction == Vector2.RIGHT:
		return "walk_right"
	
	return ""
