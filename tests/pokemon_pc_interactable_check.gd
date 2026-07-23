extends SceneTree

const PokemonPcInteractableScript := preload("res://scripts/world/interactables/pokemon_pc_interactable.gd")
const PokemonPcInteractableScene := preload("res://scenes/world/interactables/pokemon_pc_interactable.tscn")
const PcPokemonSlotButtonScript := preload("res://scripts/ui/pc_pokemon_slot_button.gd")
const UI_OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"
const OAKS_LAB_SCENE_PATH := "res://scenes/overworld/kanto/towns/pallet_town/oaks_lab.tscn"

var failed := false


func _init() -> void:
	_check_interactable_script_compiles()
	_check_interactable_scene_defaults()
	_check_pc_slot_button_script_compiles()
	_check_ui_overlay_wrapper_exists()
	_check_oaks_lab_has_pc_interactable()

	quit(1 if failed else 0)


func _check_interactable_script_compiles() -> void:
	var interactable := PokemonPcInteractableScript.new()
	_check_equal(interactable is WorldInteractable, true, "PokemonPcInteractable extends WorldInteractable")
	_check_equal(interactable.has_method("_can_start_manual_interaction"), true, "PokemonPcInteractable owns interaction area behavior")
	_check_equal(interactable.has_method("interact_with_player"), true, "PokemonPcInteractable exposes interact_with_player")
	interactable.free()

	var source := _read_text_file("res://scripts/world/interactables/pokemon_pc_interactable.gd")
	_check_equal(source.contains("func _is_player_on_interaction_tile(player: Node2D) -> bool:"), true, "PokemonPcInteractable requires exact standing tile")
	_check_equal(source.contains("interaction_area.global_position"), true, "PokemonPcInteractable uses InteractionArea position for standing tile")
	_check_equal(source.contains("_to_tile(player_feet_position) == _to_tile(target_position)"), true, "PokemonPcInteractable compares exact feet tile")
	_check_equal(source.contains("@export var required_facing_direction"), true, "PokemonPcInteractable exposes required facing direction")
	_check_equal(source.contains("func _required_facing_vector() -> Vector2:"), true, "PokemonPcInteractable maps editor facing direction")
	_check_equal(source.contains("func _start_manual_interaction(body: Node2D) -> void:"), true, "PokemonPcInteractable controls manual interaction")
	_check_equal(source.contains("body.set(\"last_direction\", _required_facing_vector())"), true, "PokemonPcInteractable keeps player facing the configured direction")


func _check_interactable_scene_defaults() -> void:
	var interactable := PokemonPcInteractableScene.instantiate()
	_check_equal(interactable is PokemonPcInteractable, true, "Reusable PokemonPC scene uses PokemonPcInteractable")
	_check_equal(interactable.get("interactable_kind"), "pokemon_pc", "Reusable PokemonPC kind")
	_check_equal(interactable.get("display_name"), "PC", "Reusable PokemonPC display name")
	_check_equal(interactable.get("blocks_movement"), false, "Reusable PokemonPC does not add collision")
	_check_equal(interactable.get("interaction_shape_size"), Vector2(32, 32), "Reusable PokemonPC interaction size")

	var interaction_area := interactable.get_node_or_null("InteractionArea") as Area2D
	_check_equal(interaction_area != null, true, "Reusable PokemonPC has InteractionArea")
	if interaction_area != null:
		_check_equal(interaction_area.position, Vector2(0, 32), "Reusable PokemonPC standing tile")
		var collision_shape := interaction_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		_check_equal(collision_shape != null, true, "Reusable PokemonPC has interaction collision")
		if collision_shape != null:
			var rectangle := collision_shape.shape as RectangleShape2D
			_check_equal(rectangle != null, true, "Reusable PokemonPC uses rectangle interaction shape")
			if rectangle != null:
				_check_equal(rectangle.size, Vector2(32, 32), "Reusable PokemonPC rectangle size")
	interactable.free()


func _check_pc_slot_button_script_compiles() -> void:
	var button := PcPokemonSlotButtonScript.new()
	_check_equal(button is Button, true, "PcPokemonSlotButton extends Button")
	_check_equal(button.has_signal("slot_dropped"), true, "PcPokemonSlotButton emits drops")
	_check_equal(button.has_method("_get_drag_data"), true, "PcPokemonSlotButton exposes drag data")
	_check_equal(button.has_method("_create_drag_icon_preview"), true, "PcPokemonSlotButton drags Pokemon icon preview")
	_check_equal(button.has_method("_can_drop_data"), true, "PcPokemonSlotButton validates drop data")
	_check_equal(button.has_method("_drop_data"), true, "PcPokemonSlotButton handles drop data")
	button.drop_target = {"type": "box", "boxIndex": 0, "slotIndex": 5}
	var box_drag_data := {
		"kind": "pokemon_pc_slot",
		"source": {"type": "box", "boxIndex": 0, "slotIndex": 2, "pokemonId": 42},
	}
	_check_equal(button._can_drop_data(Vector2.ZERO, box_drag_data), true, "PcPokemonSlotButton accepts box to different box slot")
	var same_box_drag_data := {
		"kind": "pokemon_pc_slot",
		"source": {"type": "box", "boxIndex": 0, "slotIndex": 5, "pokemonId": 42},
	}
	_check_equal(button._can_drop_data(Vector2.ZERO, same_box_drag_data), false, "PcPokemonSlotButton rejects box drop onto same slot")
	button.free()


func _check_ui_overlay_wrapper_exists() -> void:
	var source := _read_text_file(UI_OVERLAY_SCRIPT_PATH)
	_check_equal(source.contains("func open_pokemon_pc() -> void:"), true, "UIOverlay exposes open_pokemon_pc")
	_check_equal(source.contains("await _show_pc_popup()"), true, "open_pokemon_pc opens existing PC popup")
	_check_equal(source.contains("func _create_pc_pokemon_slot_button"), true, "UIOverlay renders visual PC Pokemon slots")
	_check_equal(source.contains("func _create_pc_box_pokemon_slot_button"), true, "UIOverlay renders vertical PC box Pokemon slots")
	_check_equal(source.contains("shiny_badge.text = \"S\""), true, "UIOverlay marks shiny boxed Pokemon")
	_check_equal(source.contains("func _open_pc_box_pokemon_summary"), true, "UIOverlay opens boxed Pokemon summary from slot click")
	_check_equal(source.contains("party_drag_visual = party_drag_source_slot.duplicate() as Control"), true, "UIOverlay drags whole normal party slot preview")
	_check_equal(source.contains("func _handle_pc_drag_input"), true, "UIOverlay uses custom PC drag input")
	_check_equal(source.contains("button.use_native_drag = false"), true, "UIOverlay disables native PC slot drag feedback")
	_check_equal(source.contains("PokemonAssets.load_party_icon"), true, "UIOverlay uses Pokemon icons in PC slots")
	_check_equal(source.contains("func _pc_payload_species"), true, "UIOverlay normalizes boxed Pokemon display data")
	_check_equal(source.contains("PC_POKEMON_SLOT_BUTTON_SCRIPT"), true, "UIOverlay uses draggable PC slot button")
	_check_equal(source.contains("button.drag_source"), true, "UIOverlay assigns PC drag sources")
	_check_equal(source.contains("button.drop_target"), true, "UIOverlay assigns PC drop targets")
	_check_equal(source.contains("func _on_pc_slot_dropped"), true, "UIOverlay routes PC slot drops")
	_check_equal(source.contains("pc_party_slot_by_owned_id"), true, "UIOverlay tracks PC party storage slots")
	_check_equal(source.contains("func _pc_party_pokemon_at_storage_slot"), true, "UIOverlay can inspect party storage slots")
	_check_equal(source.contains("func _pc_storage_slot_for_party_pokemon"), true, "UIOverlay translates compact party rows to storage slots")
	_check_equal(source.contains("func _pc_first_open_party_storage_slot"), true, "UIOverlay targets first open party storage slot")
	_check_equal(source.contains("pc_box_tab_bar"), true, "UIOverlay uses PC box tab bar")
	_check_equal(source.contains("func _refresh_pc_box_tabs"), true, "UIOverlay refreshes PC box tabs")
	_check_equal(source.contains("func _apply_pc_box_tab_style"), true, "UIOverlay styles active PC box tab")
	_check_equal(source.contains("pc_search_input"), true, "UIOverlay has PC search input")
	_check_equal(source.contains("pc_all_boxes"), true, "UIOverlay caches all boxes for global PC search")
	_check_equal(source.contains("pc_box_scroll"), true, "UIOverlay scrolls global PC search results")
	_check_equal(source.contains("func _pc_pokemon_matches_search"), true, "UIOverlay filters PC box Pokemon search")
	_check_equal(source.contains("pc_release_drop_panel"), true, "UIOverlay has PC release drop zone")
	_check_equal(source.contains("func _confirm_pc_release_from_source"), true, "UIOverlay confirms releases from dropped Pokemon")
	_check_equal(source.contains("func _release_selected_pc_pokemon"), true, "UIOverlay releases selected PC Pokemon")
	_check_equal(source.contains("func _add_pc_held_item_marker"), true, "UIOverlay marks PC Pokemon with held items")
	_check_equal(source.contains("HeldItemMarker"), true, "UIOverlay creates held item marker control")
	_check_equal(source.contains("pc_box_selector"), false, "UIOverlay no longer uses PC box dropdown")
	_check_equal(source.contains("socials_pc_button"), false, "Socials menu no longer owns PC button")
	_check_equal(source.contains("_on_socials_pc_button_pressed"), false, "Socials PC handler removed")


func _check_oaks_lab_has_pc_interactable() -> void:
	var scene_source := _read_text_file(OAKS_LAB_SCENE_PATH)
	_check_equal(scene_source.contains("res://scenes/world/interactables/pokemon_pc_interactable.tscn"), true, "Oak's Lab references reusable PokemonPC scene")
	_check_equal(scene_source.contains("[node name=\"Interactables\" type=\"Node2D\" parent=\"Entities\""), true, "Oak's Lab has Interactables container")
	_check_equal(scene_source.contains("[node name=\"PokemonPC\" parent=\"Entities/Interactables\""), true, "Oak's Lab instances PokemonPC under Interactables")
	_check_equal(scene_source.contains("position = Vector2(304, 464)"), true, "PokemonPC node is aligned with the blue PC")
	_check_equal(scene_source.contains("interactable_id = \"oak_lab_pc\""), true, "Oak's Lab assigns its PokemonPC id")
	_check_equal(scene_source.contains("[node name=\"PokémonLaboratory\" parent=\".\""), true, "Oak's Lab keeps the generated laboratory visual")


func _read_text_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("Could not read %s" % path)
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])


func _fail(label: String) -> void:
	failed = true
	push_error(label)
