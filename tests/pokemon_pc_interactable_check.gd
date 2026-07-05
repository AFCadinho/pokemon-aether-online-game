extends SceneTree

const PokemonPcInteractableScript := preload("res://scripts/world/interactables/pokemon_pc_interactable.gd")
const PcPokemonSlotButtonScript := preload("res://scripts/ui/pc_pokemon_slot_button.gd")
const UI_OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"
const OAKS_LAB_SCENE_PATH := "res://scenes/overworld/kanto/towns/pallet_town/oaks_lab.tscn"

var failed := false


func _init() -> void:
	_check_interactable_script_compiles()
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


func _check_pc_slot_button_script_compiles() -> void:
	var button := PcPokemonSlotButtonScript.new()
	_check_equal(button is Button, true, "PcPokemonSlotButton extends Button")
	_check_equal(button.has_signal("slot_dropped"), true, "PcPokemonSlotButton emits drops")
	_check_equal(button.has_method("_get_drag_data"), true, "PcPokemonSlotButton exposes drag data")
	_check_equal(button.has_method("_can_drop_data"), true, "PcPokemonSlotButton validates drop data")
	_check_equal(button.has_method("_drop_data"), true, "PcPokemonSlotButton handles drop data")
	button.free()


func _check_ui_overlay_wrapper_exists() -> void:
	var source := _read_text_file(UI_OVERLAY_SCRIPT_PATH)
	_check_equal(source.contains("func open_pokemon_pc() -> void:"), true, "UIOverlay exposes open_pokemon_pc")
	_check_equal(source.contains("await _show_pc_popup()"), true, "open_pokemon_pc opens existing PC popup")
	_check_equal(source.contains("func _create_pc_pokemon_slot_button"), true, "UIOverlay renders visual PC Pokemon slots")
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
	_check_equal(source.contains("socials_pc_button"), false, "Socials menu no longer owns PC button")
	_check_equal(source.contains("_on_socials_pc_button_pressed"), false, "Socials PC handler removed")


func _check_oaks_lab_has_pc_interactable() -> void:
	var scene_source := _read_text_file(OAKS_LAB_SCENE_PATH)
	_check_equal(scene_source.contains("res://scripts/world/interactables/pokemon_pc_interactable.gd"), true, "Oak's Lab references PokemonPcInteractable")
	_check_equal(scene_source.contains("[node name=\"PokemonPC\" type=\"Node2D\" parent=\"Entities\""), true, "Oak's Lab has PokemonPC node")
	_check_equal(scene_source.contains("position = Vector2(112, 0)"), true, "PokemonPC node is aligned with the blue PC")
	_check_equal(scene_source.contains("interactable_kind = \"pokemon_pc\""), true, "PokemonPC interactable kind")
	_check_equal(scene_source.contains("blocks_movement = false"), true, "PokemonPC interactable does not add collision")
	_check_equal(scene_source.contains("[node name=\"InteractionArea\" type=\"Area2D\" parent=\"Entities/PokemonPC\""), true, "PokemonPC uses explicit interaction area")
	_check_equal(scene_source.contains("position = Vector2(0, 32)"), true, "PokemonPC interaction area is on the standing tile")
	_check_equal(scene_source.contains("[node name=\"DeskPc\" type=\"TileMapLayer\" parent=\"Objects\""), true, "DeskPc remains visual TileMapLayer")


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
