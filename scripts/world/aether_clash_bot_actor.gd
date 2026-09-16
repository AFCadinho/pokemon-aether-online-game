extends Node2D

# Deliberately not a remote player or interactable NPC: no social menu,
# presence registration, movement, dialogue or account/profile lookup.
const FRAMES := preload("res://assets/npcs/classes/ace_trainer_m_frames.tres")
var user_id := 0
var actor_key := ""
var sprite: AnimatedSprite2D
var nameplate: Label


func _init() -> void:
	z_as_relative = false
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = FRAMES
	sprite.position = Vector2(0, -24)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	nameplate = Label.new()
	nameplate.position = Vector2(-32, -66)
	nameplate.size = Vector2(64, 24)
	nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nameplate.add_theme_font_size_override("font_size", 12)
	nameplate.add_theme_color_override("font_color", Color("ffb9aa"))
	nameplate.add_theme_color_override("font_outline_color", Color.BLACK)
	nameplate.add_theme_constant_override("outline_size", 3)
	add_child(nameplate)


func apply_state(player: Dictionary, compact_label: bool = false) -> void:
	var bot: Dictionary = player["bot"]
	user_id = int(player["userId"])
	actor_key = str(bot["actorKey"])
	global_position = Vector2(float(bot["x"]), float(bot["y"]))
	z_index = clampi(floori(global_position.y), -4096, 4096)
	# Large rosters can still have anchors only 64px apart. Show the full name
	# for smaller, well-spaced rosters and retain compact labels at high capacity.
	var ordinal := actor_key.get_slice(":", 2).to_int()
	var full_name := str(bot.get("displayName", "")).strip_edges()
	nameplate.size.x = 64 if compact_label else 144
	nameplate.position.x = -nameplate.size.x / 2.0
	nameplate.text = ("[BOT] %d" % ordinal if ordinal > 0 else "[BOT]") if compact_label or full_name.is_empty() else full_name
	var engaged: bool = player.get("engagementId") != null and not str(player.get("engagementId", "")).is_empty()
	sprite.modulate = Color(1, 1, 1, 0.45) if engaged else Color.WHITE
