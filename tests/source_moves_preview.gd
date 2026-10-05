extends "res://tests/battle_dialogue_preview.gd"
## Normal live Ember plus opt-in Water Gun candidate, without local dump dependencies.
const SourceEffect = preload("res://scripts/battle/battle_ui/source_move_effect_3d.gd")
const LegacyEffect = preload("res://scripts/battle/battle_ui/move_effect_3d.gd")
var candidate_enabled := true
var overrides: Array[Node] = []
var compared_count := 0

func _start() -> void:
	if "--moves" not in OS.get_cmdline_user_args():
		printerr("Supply --moves")
		quit(1)
		return
	if "--smoke-source-moves" in OS.get_cmdline_user_args():
		create_timer(90.0).timeout.connect(func(): printerr("SOURCE_MOVES_TIMEOUT"); quit(1))
	await super._start()
	root.title = "PokeAether — Ember goedgekeurd / Water Gun review"
	move_picker.select(3 if "--ember" in OS.get_cmdline_user_args() else 4)
	var toggle := CheckButton.new()
	toggle.text = "Bronmateriaal (uit = oude vormgeving)"
	toggle.button_pressed = true
	toggle.toggled.connect(func(enabled): candidate_enabled = enabled)
	toolbar.add_child(toggle)
	status.text = "Ember: goedgekeurd en actief. Water Gun: nieuwe proef. Afspelen om te vergelijken."
	if "--smoke-source-moves" in OS.get_cmdline_user_args(): await _check_source_moves()

func _load_preview() -> void:
	await super._load_preview()
	if not is_instance_valid(battle): return
	var renderer = battle.animation_router.model_presenter
	if renderer.active and not renderer.world.child_entered_tree.is_connected(_effect_added):
		renderer.world.child_entered_tree.connect(_effect_added)

func _effect_added(node: Node) -> void:
	if node.get_script() in [LegacyEffect, SourceEffect] and not node.has_meta("preview_override"):
		_override.call_deferred(node)

func _override(effect: Node) -> void:
	if not is_instance_valid(effect) or effect.done: return
	var replacement: Node3D
	if effect.key == "watergun" and candidate_enabled:
		replacement = SourceEffect.new()
	elif effect.key == "ember" and not candidate_enabled:
		replacement = LegacyEffect.new()
	else: return
	replacement.set_meta("preview_override", true)
	effect.get_parent().add_child(replacement)
	replacement.view_camera = effect.view_camera
	effect.visible = false
	overrides.append(replacement)
	replacement.tree_exiting.connect(func(): overrides.erase(replacement), CONNECT_ONE_SHOT)
	effect.tree_exiting.connect(replacement.cancel, CONNECT_ONE_SHOT)
	replacement.start(effect.key, {"frames":effect.duration * 60.0, "impact_frame":effect.impact * 60.0},
		{"show_impact":effect.hit, "result":"miss" if effect.miss else ""}, effect.clock, effect.anchors, effect.valid)
	compared_count += 1

func _check_source_moves() -> void:
	var renderer = battle.animation_router.model_presenter
	assert(renderer.active and battle.battle_state.battle_id.is_empty())
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	for move_index in [3, 4]:
		move_picker.select(move_index)
		for reverse in [false, true]:
			move_reverse.button_pressed = reverse
			for outcome in [0, 1, 2]:
				move_outcome.select(outcome)
				_preview_move()
				var captured := {}
				while move_busy:
					for effect: Node in renderer.common_effects:
						if effect.get("key") not in ["ember", "watergun"]: continue
						var phase := "impact" if effect.elapsed >= effect.impact else "flight"
						if effect.elapsed < lerpf(effect.launch, effect.impact, 0.6) or captured.has(phase): continue
						captured[phase] = true
						if not output.is_empty() and DisplayServer.get_name() != "headless":
							await RenderingServer.frame_post_draw
							root.get_texture().get_image().save_png(output.path_join("source-%s-%s-%s-%s.png" % [effect.key, reverse, outcome, phase]))
					await process_frame
				await process_frame
				await process_frame
				assert(renderer.common_effects.is_empty() and overrides.is_empty())
		move_outcome.select(0)
		_preview_move()
		while renderer.common_effects.is_empty(): await process_frame
		var effect: Node = renderer.common_effects[0]
		while effect.elapsed < lerpf(effect.launch, effect.impact, 0.6): await process_frame
		battle.animation_router.playback_speed = 0
		await process_frame
		var frozen: float = effect.elapsed
		await create_timer(0.1).timeout
		assert(is_equal_approx(frozen, effect.elapsed))
		var visible_effect: Node = effect if move_index == 3 else overrides[0]
		assert(is_equal_approx(frozen, visible_effect.elapsed))
		renderer.user_camera_yaw += 0.65
		renderer.user_camera_pitch = 0.1
		await process_frame
		await process_frame
		var visible_quads := 0
		for piece: MeshInstance3D in visible_effect.pieces:
			if not piece.visible or not piece.mesh is QuadMesh: continue
			visible_quads += 1
			assert(absf(piece.global_basis.z.normalized().dot(renderer.camera.global_basis.z.normalized())) > 0.999, "Orbit facing move=%d actual=%s camera=%s elapsed=%f frozen=%f" % [move_index, piece.global_basis.z, renderer.camera.global_basis.z, visible_effect.elapsed, frozen])
		assert(visible_quads > 0 and is_equal_approx(frozen, visible_effect.elapsed))
		if not output.is_empty() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("source-orbit-%s.png" % move_index))
		battle.animation_router.cancel_render()
		battle.animation_router.playback_speed = 1
		while move_busy: await process_frame
		await process_frame
		await process_frame
		assert(renderer.common_effects.is_empty() and overrides.is_empty() and battle.animation_router.active_audio_nodes.is_empty())
		candidate_enabled = false
		await _preview_move()
		await process_frame
		await process_frame
		assert(renderer.common_effects.is_empty() and overrides.is_empty())
		candidate_enabled = true
	assert(compared_count >= 8)
	print("SOURCE_MOVES_PREVIEW_OK moves=2 directions=2 outcomes=3 pause=true orbit=true comparison=true cancel=true cleanup=true")
	quit()
