extends SceneTree

const Appearance := preload("res://scripts/services/character_appearance_service.gd")
const FutureAppearance := preload("res://scripts/world/story/future_self_appearance.gd")

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var save := root.get_node("PlayerSave")
	var original: Dictionary = save.to_appearance_state()
	for gender: String in ["male", "female"]:
		save.apply_appearance_state({
			"gender": gender,
			"body": Appearance.resolve_body_model_id("", gender),
			"skin_tone": "#b87860", "eye_color": "#3090d0",
			"hair": Appearance.get_default_part_id("hair", gender),
		})
		var npc: Node = load("res://scenes/npcs/rock_tunnel_future_self_npc.tscn").instantiate()
		root.add_child(npc)
		await process_frame
		var frames: SpriteFrames = npc.npc_sprite_frames
		_check(frames != null, "%s Future Self has composed frames" % gender)
		for direction: String in ["up", "down", "left", "right"]:
			_check(frames.has_animation("idle_" + direction), "%s idle %s exists" % [gender, direction])
			_check(frames.get_frame_count("walk_" + direction) == 4, "%s walk %s has four frames" % [gender, direction])
		var metadata: Dictionary = npc.build_battle_trainer_metadata({})
		_check(not metadata.has("_battle_sprite_id"), "%s battle avoids a catalog trainer fallback" % gender)
		_check(metadata.get("_battle_sprite_frames") == frames, "%s battle shares overworld frames" % gender)
		_check(metadata.get("_battle_mugshot") == npc.mugshot, "%s battle shares dialogue portrait" % gender)
		var mt_moon: Node = load("res://scripts/world/story/mt_moon_ambush_controller.gd").new()
		var reference: Texture2D = mt_moon._future_self_mugshot()
		_check(npc.mugshot != null and npc.mugshot.get_image().get_data() == reference.get_image().get_data(), "%s portrait matches Mt. Moon" % gender)
		var bare_body := Appearance.get_skin_tinted_body_frames(
			save.appearance_body_id, gender, Appearance.BODY_MOVEMENT_DEFAULT, save.appearance_skin_tone
		)
		_check(frames.get_frame_texture("idle_down", 0).get_image().get_data() != Appearance._get_texture_image(bare_body.get_frame_texture("idle_down", 0)).get_data(), "%s outfit is rendered over the body" % gender)
		mt_moon.free()
		npc.queue_free()
		await process_frame
	save.apply_appearance_state(original)
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failed = true
		push_error("FAIL " + label)
