extends "res://tests/battle_dialogue_preview.gd"
## Run with --moves --sv-source=/absolute/path/to/extracted/pilot.
const Pilot = preload("res://tests/ember_sv_effect_pilot.gd")
var source_dir := ""
var source_manifest: Dictionary
var pilot_enabled := true
var attached_count := 0

func _start() -> void:
	if "--smoke-sv-ember" in OS.get_cmdline_user_args():
		create_timer(60.0).timeout.connect(func(): printerr("SV_EMBER_PILOT_TIMEOUT"); quit(1))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sv-source="): source_dir = arg.trim_prefix("--sv-source=")
	var file := source_dir.path_join("manifest.json")
	if "--moves" not in OS.get_cmdline_user_args() or not FileAccess.file_exists(file):
		printerr("Extract Ember first; supply --moves --sv-source=/absolute/output/path")
		quit(1)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(file))
	if not parsed is Dictionary or parsed.get("conversion", "") != "partial-textures-and-colors" or parsed.get("move", "") != "ember":
		printerr("Invalid Ember pilot manifest")
		quit(1)
		return
	source_manifest = parsed
	for part: String in source_manifest.parts:
		for texture: String in source_manifest.parts[part].textures:
			if not FileAccess.file_exists(source_dir.path_join(part).path_join(texture + ".png")):
				printerr("Missing extracted texture: ", texture)
				quit(1)
				return
	await super._start()
	root.title = "PokeAether — Ember SV-bronmateriaal (proef)"
	move_picker.select(3)
	var toggle := CheckButton.new()
	toggle.text = "SV-bronmateriaal (uit = bestaande Ember)"
	toggle.button_pressed = true
	toggle.toggled.connect(func(enabled): pilot_enabled = enabled)
	toolbar.add_child(toggle)
	status.text = "Proef: oorspronkelijke SV-textures en kleuren; aangepaste beweging."
	if "--smoke-sv-ember" in OS.get_cmdline_user_args():
		await _check_pilot()

func _load_preview() -> void:
	await super._load_preview()
	if not is_instance_valid(battle): return
	var renderer = battle.animation_router.model_presenter
	if renderer.active and not renderer.world.child_entered_tree.is_connected(_effect_added):
		renderer.world.child_entered_tree.connect(_effect_added)

func _effect_added(node: Node) -> void:
	if node.get_script() == preload("res://scripts/battle/battle_ui/move_effect_3d.gd"):
		_attach.call_deferred(node)

func _attach(effect: Node) -> void:
	if not pilot_enabled or not is_instance_valid(effect) or effect.key != "ember" or effect.done: return
	var visual := Pilot.new()
	effect.get_parent().add_child(visual)
	visual.configure(effect, source_dir, source_manifest)
	attached_count += 1

func _check_pilot() -> void:
	var renderer = battle.animation_router.model_presenter
	assert(renderer.active and battle.battle_state.battle_id.is_empty())
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	for reverse in [false, true]:
		move_reverse.button_pressed = reverse
		for outcome in [0, 1, 2]:
			move_outcome.select(outcome)
			var attached_before := attached_count
			_preview_move()
			var captured := {}
			var deadline := Time.get_ticks_msec() + 10000
			while move_busy:
				assert(Time.get_ticks_msec() < deadline, "Ember pilot timed out")
				for effect: Node in renderer.common_effects:
					if effect.get("key") != "ember": continue
					var phase := "impact" if effect.elapsed >= effect.impact else "flight"
					if effect.elapsed < lerpf(effect.launch, effect.impact, 0.6) or captured.has(phase): continue
					captured[phase] = true
					if not output.is_empty() and DisplayServer.get_name() != "headless":
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png(output.path_join("sv-ember-%s-%s-%s.png" % [reverse, outcome, phase]))
				await process_frame
			assert(attached_count == attached_before + 1, "Source visual must attach")
			await process_frame
			await process_frame
			assert(renderer.common_effects.is_empty())
			for child: Node in renderer.world.get_children(): assert(child.get_script() != Pilot, "Pilot must clean up")
	move_outcome.select(0)
	_preview_move()
	while renderer.common_effects.is_empty(): await process_frame
	var effect: Node = renderer.common_effects[0]
	while effect.elapsed < lerpf(effect.launch, effect.impact, 0.6): await process_frame
	battle.animation_router.playback_speed = 0
	await process_frame
	var frozen: float = effect.elapsed
	await create_timer(0.15).timeout
	assert(is_equal_approx(frozen, effect.elapsed))
	renderer.user_camera_yaw = 0.8
	renderer.user_camera_pitch = 0.15
	await process_frame
	await process_frame
	var visible_sprites := 0
	for child: Node in renderer.world.get_children():
		if child.get_script() != Pilot: continue
		for sprite: MeshInstance3D in child.sprites:
			if not sprite.visible: continue
			visible_sprites += 1
			assert(absf(sprite.global_basis.z.normalized().dot(renderer.camera.global_basis.z.normalized())) > 0.999)
	assert(visible_sprites > 0 and is_equal_approx(frozen, effect.elapsed), "Frozen effect must face the orbiting camera")
	if not output.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("sv-ember-orbit-paused.png"))
	battle.animation_router.cancel_render()
	battle.animation_router.playback_speed = 1
	while move_busy: await process_frame
	await process_frame
	await process_frame
	assert(renderer.common_effects.is_empty() and battle.animation_router.active_audio_nodes.is_empty())
	for child: Node in renderer.world.get_children(): assert(child.get_script() != Pilot)
	print("SV_EMBER_PILOT_OK directions=2 outcomes=3 pause=true orbit=true cancel=true cleanup=true")
	quit()
