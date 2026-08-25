extends SceneTree

func _init() -> void:
	var scene_source := FileAccess.get_file_as_string(
		"res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn"
	)
	var map_script_source := FileAccess.get_file_as_string(
		"res://scripts/world/kanto/towns/viridian_city.gd"
	)
	var gate_source := FileAccess.get_file_as_string(
		"res://scripts/world/npcs/ev_training_gate_npc.gd"
	)
	var service_source := FileAccess.get_file_as_string(
		"res://scripts/services/ev_training_service.gd"
	)
	var expert_source := FileAccess.get_file_as_string(
		"res://scripts/world/kanto/towns/ev_training_expert_mateo.gd"
	)
	var world_source := FileAccess.get_file_as_string(
		"res://scripts/world/world.gd"
	)
	var battle_source := FileAccess.get_file_as_string(
		"res://scripts/battle/battle.gd"
	)
	var ui_overlay_source := FileAccess.get_file_as_string(
		"res://scripts/ui/ui_overlay.gd"
	)
	_assert(scene_source.contains("EVExpertMateo"), "EV expert Mateo is missing")
	_assert(scene_source.contains("ev_expert_f_frames.tres"), "Mateo's overworld sprite does not match the Expert portrait")
	_assert(scene_source.contains("EVAssistantRina"), "north EV assistant is missing")
	_assert(scene_source.contains("EVAssistantEli"), "south EV assistant is missing")
	_assert(scene_source.contains("kanto_viridian_city_ev_training"), "EV encounter region is missing")
	_assert(scene_source.contains("EVTrainingNorthInside"), "north teleport markers are missing")
	_assert(scene_source.contains("EVTrainingSouthInside"), "south teleport markers are missing")
	_assert(map_script_source.contains("_setup_ev_training_grass"), "EV grass mask setup is missing")
	for stat: String in ["hp", "atk", "def", "spa", "spd", "spe"]:
		_assert(gate_source.contains('"id": "%s"' % stat), "missing EV stat choice: %s" % stat)
	var localized_gate_keys: Array[String] = [
		"ui.ev_training.assistant.session_active",
		"ui.ev_training.assistant.pre_lesson",
		"ui.ev_training.assistant.authorization_required",
		"ui.ev_training.assistant.tutorial_ready",
		"ui.ev_training.assistant.introduction",
		"ui.ev_training.assistant.session_started",
		"ui.ev_training.assistant.lesson_paused",
		"ui.ev_training.assistant.session_complete",
		"ui.ev_training.assistant.title",
		"ui.ev_training.assistant.stat_prompt",
		"ui.ev_training.assistant.session_fee",
		"ui.ev_training.mateo.lesson_intro.evs",
		"ui.ev_training.mateo.focus_targets",
		"ui.ev_training.mateo.battle_progress",
		"ui.ev_training.mateo.allocation_instructions",
		"ui.ev_training.mateo.choose_pokemon",
	]
	for locale: String in ["en", "nl", "pt_BR"]:
		var locale_data: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://localization/%s.json" % locale)
		)
		_assert(locale_data is Dictionary, "EV assistant localization parses for %s" % locale)
		if not locale_data is Dictionary:
			continue
		for key: String in localized_gate_keys:
			_assert(
				str((locale_data as Dictionary).get(key, "")).strip_edges() != "",
				"missing %s in %s" % [key, locale]
			)
	_assert(
		gate_source.contains('const TRAINER_SCHOOL_QUEST_ID := "learn_at_trainer_school"')
		and gate_source.contains('LocalizationManager.text("ui.ev_training.assistant.pre_lesson")'),
		"EV assistants must keep their training dialogue hidden before the Trainer School lesson"
	)
	_assert(
		not gate_source.contains("This is Viridian City's focused EV training field.")
		and not gate_source.contains("Training session complete."),
		"EV assistant runtime dialogue must not be hardcoded in English"
	)
	_assert(
		expert_source.contains('LocalizationManager.text("ui.ev_training.mateo.lesson_intro.evs")')
		and not expert_source.contains("EV means Effort Value. A Pokemon that participates"),
		"Mateo's runtime lesson must use the localization catalog"
	)
	_assert(
		gate_source.contains('backdrop.name = "EvTrainingChoiceBackdrop"')
		and gate_source.contains('fee_badge.name = "EvTrainingFeeBadge"')
		and gate_source.contains('grid_panel.name = "EvTrainingStatGridPanel"'),
		"EV stat choice uses layered themed surfaces"
	)
	_assert(
		gate_source.contains("func _apply_stat_button_style")
		and gate_source.contains("func _apply_cancel_button_style")
		and gate_source.contains('"hover"'),
		"EV stat choice replaces default Godot buttons with interactive styles"
	)
	_assert(service_source.contains("/game/ev-training/session"), "EV session endpoint is missing")
	_assert(service_source.contains("/game/ev-training/tutorial/focus"), "EV tutorial focus endpoint is missing")
	_assert(expert_source.contains("allocate_training_evs"), "Mateo's EV allocation lesson is missing")
	_assert(
		world_source.contains('const EV_TRAINING_MAP_ID := "kanto_viridian_city"')
		and world_source.contains("func _end_ev_training_session_for_map_exit")
		and world_source.count("await _end_ev_training_session_for_map_exit(") == 2,
		"EV sessions must end for regular and authorized map exits"
	)
	_assert(
		battle_source.contains('api_response.get("captureAllowed", true)')
		and battle_source.contains("battle_type == BattleType.WILD and wild_capture_allowed"),
		"EV training battles must be able to hide and reject the Bag"
	)
	_assert(
		ui_overlay_source.count("pokemon_summary_ev_allocate_popup.z_index = UI_MODAL_Z_INDEX + 1") >= 2
		and ui_overlay_source.contains("_activate_ui_panel(pokemon_summary_ev_allocate_popup)\n\t# Summary cards use the modal layer"),
		"EV allocation must remain visible above the Pokemon summary card"
	)
	_assert(
		ui_overlay_source.contains("const POKEMON_EV_STORAGE_TOTAL_LIMIT := POKEMON_EV_STAT_LIMIT * 6")
		and ui_overlay_source.contains("var allocated_value: int = clampi(int(pokemon.evs.get(stat_id, 0)), 0, POKEMON_EV_STAT_LIMIT)")
		and ui_overlay_source.contains("var max_gain: int = max(POKEMON_EV_STAT_LIMIT - allocated_value - current_value, 0)")
		and not ui_overlay_source.contains("POKEMON_EV_TOTAL_LIMIT - allocated_total - stored_total"),
		"stored EV capacity must respect the combined per-stat cap and remain independent from the 510 allocated EV limit"
	)
	_assert(
		ui_overlay_source.contains('LocalizationManager.text("ui.pokemon_summary.evs.stored", {')
		and not ui_overlay_source.contains('LocalizationManager.text("ui.pokemon_summary.evs.available_capacity"'),
		"stored EV totals belong in the section title without a duplicate capacity row"
	)
	print("EV training checks passed.")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
