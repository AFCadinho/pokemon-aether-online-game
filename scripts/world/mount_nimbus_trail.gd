extends Node2D

# Same nozzle positions and seven short puffs as the approved Nimbus design.
# Native 192px mount-cell coordinates; the entire node inherits the cloud hover.
const NOZZLES := {"down": Vector2(96, 78), "left": Vector2(121, 95), "right": Vector2(71, 95), "up": Vector2(96, 115)}
const AXES := {"down": Vector2.UP, "left": Vector2.RIGHT, "right": Vector2.LEFT, "up": Vector2.DOWN}
var enabled := false
var active := false
var direction := "down"
var clock := 0.0
var axis := Vector2.UP
var trail_color := Color(1.0, 0.67, 0.12)
var highlight_color := Color(1.0, 0.94, 0.54)


func configure(definition: Dictionary, _mount: AnimatedSprite2D) -> void:
	enabled = str(definition.get("movementEffect", "")) == "nimbus_trail"
	trail_color = Color.from_string(str(definition.get("trailColor", "")), Color(1.0, 0.67, 0.12))
	highlight_color = Color.from_string(str(definition.get("trailHighlightColor", "")), Color(1.0, 0.94, 0.54))
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not enabled:
		clear()


func sync_frame(mount: AnimatedSprite2D) -> void:
	if not enabled or mount == null or not mount.visible:
		clear()
		return
	direction = str(mount.animation).trim_prefix("walk_").trim_prefix("idle_")
	if not AXES.has(direction):
		clear()
		return
	active = str(mount.animation).begins_with("walk_")
	axis = AXES[direction]
	position = NOZZLES[direction] - Vector2(96, 96)
	visible = active
	set_process(active)
	queue_redraw()


func clear() -> void:
	active = false
	visible = false
	clock = 0.0
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	clock = fposmod(clock + maxf(delta, 0.0), 10.0)
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	for index in range(7):
		var age := fposmod(clock * 1.7 + index / 7.0, 1.0)
		var point := (axis * (4.0 + age * 20.0) + axis.orthogonal() * roundf(sin(index + clock * 4.0))).round()
		var radius := roundf(3.0 * (1.0 - age)) + 1.0
		draw_circle(point, radius, Color(trail_color, (1.0 - age) * 0.8), true, -1.0, false)
		draw_rect(Rect2(point - Vector2.ONE, Vector2(2, 2)), Color(highlight_color, 1.0 - age))
