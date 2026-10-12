extends CanvasLayer

class_name OverworldCaveVisibilityController

const FLASH_REVEAL_SECONDS := 0.55
const FLASH_DARKEN_SECONDS := 0.2

@export var player_path: NodePath
@export var flash_light_path: NodePath
@export var day_night_controller_path: NodePath

var current_group_id := ""
var sight_radius := 96.0
var feather := 12.0
var reveal_progress := 0.0:
	set(value):
		reveal_progress = clampf(value, 0.0, 1.0)
		_sync_mask()

var _reveal_tween: Tween

@onready var player: Node2D = get_node(player_path) as Node2D
@onready var flash_light: OverworldFieldMoveFlashLight = get_node(flash_light_path) as OverworldFieldMoveFlashLight
@onready var day_night_controller: OverworldDayNightController = get_node(day_night_controller_path) as OverworldDayNightController
@onready var darkness_mask: ColorRect = $DarknessMask
@onready var mask_material: ShaderMaterial = darkness_mask.material as ShaderMaterial


func _ready() -> void:
	flash_light.active_changed.connect(_on_flash_active_changed)
	_sync_mask()


func _process(_delta: float) -> void:
	_update_mask_geometry()


# Returns true once per cave visit, allowing the world to show an entry hint.
func apply_map(map_node: Node) -> bool:
	var settings: Dictionary = {}
	if map_node != null and map_node.has_method("get_cave_visibility_settings"):
		settings = map_node.call("get_cave_visibility_settings")
	var group_id := str(settings.get("groupId", "")).strip_edges()
	var entered_cave := not group_id.is_empty() and group_id != current_group_id
	current_group_id = group_id
	sight_radius = maxf(float(settings.get("radius", 96.0)), 1.0)
	feather = clampf(float(settings.get("feather", 12.0)), 1.0, sight_radius)
	flash_light.apply_cave_visibility_group(group_id)
	_stop_reveal_tween()
	day_night_controller.set_cave_flash_lit(not current_group_id.is_empty() and flash_light.active)
	reveal_progress = 1.0 if flash_light.active else 0.0
	return entered_cave


func _on_flash_active_changed(active: bool) -> void:
	day_night_controller.set_cave_flash_lit(not current_group_id.is_empty() and active)
	_stop_reveal_tween()
	if current_group_id.is_empty():
		_sync_mask()
		return
	_reveal_tween = create_tween()
	_reveal_tween.tween_property(
		self, "reveal_progress", 1.0 if active else 0.0,
		FLASH_REVEAL_SECONDS if active else FLASH_DARKEN_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _stop_reveal_tween() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_tween = null


func _sync_mask() -> void:
	if darkness_mask == null:
		return
	darkness_mask.visible = not current_group_id.is_empty() and reveal_progress < 1.0
	set_process(darkness_mask.visible)
	mask_material.set_shader_parameter("reveal_progress", reveal_progress)
	if darkness_mask.visible:
		_update_mask_geometry()


func _update_mask_geometry() -> void:
	# The player can briefly leave the tree while the world swaps maps.
	if not is_instance_valid(player) or not player.is_inside_tree():
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var canvas_transform := player.get_canvas_transform()
	var screen_to_world := canvas_transform.affine_inverse()
	var player_screen := canvas_transform * player.global_position
	var full_radius := sight_radius
	for corner: Vector2 in [Vector2.ZERO, Vector2(viewport_size.x, 0.0), viewport_size, Vector2(0.0, viewport_size.y)]:
		full_radius = maxf(full_radius, screen_to_world.basis_xform(corner - player_screen).length() + feather)
	mask_material.set_shader_parameter("viewport_size", viewport_size)
	mask_material.set_shader_parameter("player_screen_position", player_screen)
	mask_material.set_shader_parameter("world_per_screen_x", screen_to_world.x)
	mask_material.set_shader_parameter("world_per_screen_y", screen_to_world.y)
	mask_material.set_shader_parameter("sight_radius", sight_radius)
	mask_material.set_shader_parameter("full_radius", full_radius)
	mask_material.set_shader_parameter("feather", feather)
