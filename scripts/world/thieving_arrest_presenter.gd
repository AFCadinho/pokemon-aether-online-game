extends RefCounted

class_name ThievingArrestPresenter

const TILE_SIZE := 32.0
const LAW_ENFORCEMENT_NPC_TYPE := "law_enforcement"
const OFFICER_NAME := "Officer Jenny"
const OFFICER_SCENE: PackedScene = preload("res://scenes/npcs/dialogue_npc.tscn")
const OFFICER_FRAMES: SpriteFrames = preload("res://assets/npcs/classes/officer_jenny_frames.tres")
const OFFICER_PORTRAIT: Texture2D = preload(
	"res://assets/sprites/trainer_cards/showdown/policeman-gen7.png"
)


static func show_confrontation(source_npc: Node2D, player: Node2D, npc_type: String) -> void:
	if source_npc == null or player == null:
		return
	if npc_type.strip_edges().to_lower() == LAW_ENFORCEMENT_NPC_TYPE:
		source_npc.call("face_world_position", player.global_position)
		player.call("face_world_position", source_npc.global_position)
		await _show_officer_dialogue(
			player,
			LocalizationManager.text("ui.thieving.arrest.officer_confrontation")
		)
		return

	var officer := _spawn_temporary_officer(
		player,
		get_position_behind_player(player.global_position, _player_direction(player))
	)
	if officer == null:
		return
	await player.get_tree().process_frame
	officer.call("face_world_position", player.global_position)
	player.call("face_world_position", officer.global_position)
	await _show_officer_dialogue(
		player,
		LocalizationManager.text("ui.thieving.arrest.civilian_confrontation")
	)
	if is_instance_valid(officer):
		officer.queue_free()


static func show_jail_arrival(player: Node2D, arrest: Dictionary) -> void:
	if player == null:
		return
	var officer := _spawn_temporary_officer(player, player.global_position + Vector2(TILE_SIZE, 0.0))
	if officer == null:
		return
	await player.get_tree().process_frame
	officer.call("face_world_position", player.global_position)
	player.call("face_world_position", officer.global_position)
	await _show_officer_dialogue(
		player,
		LocalizationManager.text("ui.thieving.arrest.jail_arrival", {
			"amount": maxi(int(arrest.get("lostMoney", 0)), 0),
			"minutes": maxi(ceili(float(arrest.get("sentenceSeconds", 0)) / 60.0), 1),
		})
	)
	if is_instance_valid(officer):
		officer.queue_free()


static func _show_officer_dialogue(player: Node2D, line: String) -> void:
	var scene_tree := player.get_tree()
	var current_scene := scene_tree.current_scene
	if current_scene == null:
		push_warning("ThievingArrestPresenter: current scene is unavailable for arrest dialogue.")
		return
	var dialogue_box := current_scene.get_node_or_null("DialogueBox/Box")
	if dialogue_box == null or not dialogue_box.has_method("start_dialogue"):
		push_warning("ThievingArrestPresenter: DialogueBox/Box not found.")
		return
	dialogue_box.call("start_dialogue", [line], OFFICER_NAME, OFFICER_PORTRAIT, true)
	await dialogue_box.dialogue_finished


static func get_position_behind_player(player_position: Vector2, player_direction: Vector2) -> Vector2:
	var direction := player_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	return player_position - direction * TILE_SIZE


static func _player_direction(player: Node2D) -> Vector2:
	var direction_value: Variant = player.get("last_direction")
	return direction_value as Vector2 if direction_value is Vector2 else Vector2.DOWN


static func _spawn_temporary_officer(player: Node2D, world_position: Vector2) -> Node2D:
	var current_map := GameState.current_map as Node
	if current_map == null or not is_instance_valid(current_map):
		return null
	var npc_parent := current_map.get_node_or_null("Entities/NPCs")
	if npc_parent == null:
		npc_parent = current_map
	var officer := OFFICER_SCENE.instantiate() as Node2D
	officer.name = "TemporaryArrestOfficer"
	officer.set("display_name", OFFICER_NAME)
	officer.set("npc_definition_id", "trainer_class_policeman")
	officer.set("npc_sprite_frames", OFFICER_FRAMES)
	officer.set("mugshot", OFFICER_PORTRAIT)
	officer.set("npc_metadata_loaded", true)
	var interaction_area := officer.get_node_or_null("InteractionArea") as Area2D
	if interaction_area != null:
		interaction_area.monitoring = false
		interaction_area.monitorable = false
	npc_parent.add_child(officer)
	officer.global_position = world_position
	return officer
