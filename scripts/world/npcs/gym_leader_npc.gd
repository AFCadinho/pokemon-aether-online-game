@tool
extends TrainerNPC

class_name GymLeaderNPC

const GymLeaderDefinitionResource := preload("res://scripts/world/npcs/gym_leader_definition.gd")
const DEFAULT_GYM_BATTLE_ENVIRONMENT_ID := "pvp_stadium"

var badge_region := "kanto"
var badge_id := ""
var badge_display_name := "Gym Badge"
var badge_icon_texture: Texture2D
var required_badge_ids: Array[String] = []

var badge_marker: Sprite2D


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	_setup_badge_marker()
	if not PlayerSave.gym_badges_changed.is_connected(_refresh_badge_marker):
		PlayerSave.gym_badges_changed.connect(_refresh_badge_marker)


func _apply_npc_profile() -> void:
	super._apply_npc_profile()
	var gym_profile := npc_profile as GymLeaderDefinitionResource
	if gym_profile == null:
		return
	if battle_environment_id.strip_edges() in ["", "inherit"]:
		battle_environment_id = DEFAULT_GYM_BATTLE_ENVIRONMENT_ID

	badge_region = gym_profile.badge_region
	badge_id = gym_profile.badge_id
	badge_display_name = gym_profile.badge_display_name
	badge_icon_texture = gym_profile.badge_icon_texture
	required_badge_ids = gym_profile.required_badge_ids.duplicate()


func supports_trainer_rematches() -> bool:
	return false


func has_existing_trainer_completion() -> bool:
	return _has_own_badge()


func show_intro_dialogue() -> void:
	var missing_badges := _missing_required_badges()
	if missing_badges.is_empty():
		await super.show_intro_dialogue()
		return

	var dialogue_box := get_tree().current_scene.get_node_or_null("DialogueBox/Box")
	if dialogue_box == null:
		push_warning("GymLeaderNPC: DialogueBox/Box not found.")
		return
	var requirement_names: Array[String] = []
	for missing_badge: String in missing_badges:
		requirement_names.append("%s Badge" % missing_badge.capitalize())
	dialogue_box.start_dialogue(
		[
			LocalizationManager.text("npc.gym_leader.trial_locked"),
			LocalizationManager.text(
				"npc.gym_leader.badges_required",
				{"badges": ", ".join(requirement_names)}
			),
		],
		display_name,
		mugshot
	)
	await dialogue_box.dialogue_finished


func _resolve_intro_dialogue_lines(trainer_metadata: Dictionary) -> Array[String]:
	if _has_own_badge():
		var rematch_dialogue_id := str(trainer_metadata.get("rematchDialogueId", "")).strip_edges()
		if not rematch_dialogue_id.is_empty():
			var localized_lines := await _get_dialogue_metadata_lines(rematch_dialogue_id)
			if not localized_lines.is_empty():
				return localized_lines
		var rematch_lines := _string_array(trainer_metadata.get("dialogue_rematch", []))
		if not rematch_lines.is_empty():
			return rematch_lines
	return await super._resolve_intro_dialogue_lines(trainer_metadata)


func _missing_required_badges() -> Array[String]:
	var missing: Array[String] = []
	for required_badge_id: String in required_badge_ids:
		var normalized_id := required_badge_id.strip_edges().to_lower()
		if normalized_id == "":
			continue
		if not PlayerSave.has_gym_badge(badge_region, normalized_id):
			missing.append(normalized_id)
	return missing


func _has_own_badge() -> bool:
	return (
		badge_id.strip_edges() != ""
		and PlayerSave.has_gym_badge(badge_region, badge_id)
	)


func _setup_badge_marker() -> void:
	badge_marker = Sprite2D.new()
	badge_marker.name = "BadgeMarker"
	badge_marker.texture = badge_icon_texture
	badge_marker.position = Vector2(0, -102)
	badge_marker.scale = Vector2(0.075, 0.075)
	badge_marker.z_index = 513
	add_child(badge_marker)
	_refresh_badge_marker()


func _refresh_badge_marker() -> void:
	if badge_marker == null:
		return
	badge_marker.visible = badge_icon_texture != null
	badge_marker.modulate = Color.WHITE if _has_own_badge() else Color("#8490a6b8")
	if _has_own_badge():
		mark_trainer_completed()


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			var text := str(item).strip_edges()
			if text != "":
				result.append(text)
	return result
