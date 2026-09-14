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
	nameplate.position = Vector2(-110, -66)
	nameplate.size = Vector2(220, 24)
	nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nameplate.add_theme_font_size_override("font_size", 12)
	nameplate.add_theme_color_override("font_color", Color("ffb9aa"))
	nameplate.add_theme_color_override("font_outline_color", Color.BLACK)
	nameplate.add_theme_constant_override("outline_size", 3)
	add_child(nameplate)


func apply_state(player: Dictionary) -> void:
	var bot: Dictionary = player["bot"]
	user_id = int(player["userId"])
	actor_key = str(bot["actorKey"])
	global_position = Vector2(float(bot["x"]), float(bot["y"]))
	z_index = clampi(floori(global_position.y), -4096, 4096)
	nameplate.text = str(bot.get("displayName", "[BOT]"))
	var engaged: bool = player.get("engagementId") != null and not str(player.get("engagementId", "")).is_empty()
	sprite.modulate = Color(1, 1, 1, 0.45) if engaged else Color.WHITE
