extends SceneTree

const TEMPLATE_PATH := "res://scenes/overworld/kanto/reusable_interiors/pokemon_center_template.tscn"
const BANK_POPUP_PATH := "res://scenes/interface/bank_popup.tscn"
const CENTER_PATHS := [
	"res://scenes/overworld/kanto/towns/viridian_city/pokemon_center.tscn",
	"res://scenes/overworld/kanto/towns/pewter_city/pokemon_center.tscn",
	"res://scenes/overworld/kanto/routes/route_3_pokemon_center.tscn",
	"res://scenes/overworld/kanto/towns/cerulean_city/pokemon_center.tscn",
]

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var template_source := FileAccess.get_file_as_string(TEMPLATE_PATH)
	_check(not template_source.is_empty(), "Pokémon Center template is readable")
	_check(template_source.contains('[node name="Banker" parent="Entities/NPCs"'), "Pokémon Center template includes the Banker")
	_check(template_source.contains("position = Vector2(560, 400)"), "Banker occupies the right upper counter")
	var banker_scene_source := FileAccess.get_file_as_string("res://scenes/npcs/banker_npc.tscn")
	_check(banker_scene_source.contains('display_name = "Banker"'), "Banker uses the clear English name")
	_check(banker_scene_source.contains("manual_interaction_reach_tiles = 3"), "Banker can be reached across the upper counter")
	var banker_script_source := FileAccess.get_file_as_string("res://scripts/world/npcs/banker_npc.gd")
	_check(banker_script_source.contains('bank_marker.name = "BankMarker"'), "Banker displays a money icon above the nameplate")
	_check(FileAccess.get_file_as_string("res://scenes/npcs/move_mentor_npc.tscn").contains('text = "TM"'), "Move Maniac scene includes a TM marker")
	_check(FileAccess.get_file_as_string("res://scenes/npcs/move_deleter_npc.tscn").contains('text = "−"'), "Move Deleter scene includes a deletion marker")
	_check(FileAccess.get_file_as_string("res://scenes/npcs/aether_atelier_npc.tscn").contains('text = "◇"'), "Aether Atelier scene includes an atelier marker")

	for center_path: String in CENTER_PATHS:
		var center_source := FileAccess.get_file_as_string(center_path)
		_check(center_source.contains("pokemon_center_template.tscn"), "%s inherits the shared template" % center_path)

	var popup_scene_source := FileAccess.get_file_as_string(BANK_POPUP_PATH)
	var popup_script_source := FileAccess.get_file_as_string("res://scripts/ui/bank_popup.gd")
	_check(popup_scene_source.contains("custom_minimum_size = Vector2(470, 420)"), "Bank uses an expanded compact interface")
	_check(popup_script_source.contains('amount_input.name = "BankAmountInput"'), "Bank provides an amount input")
	_check(popup_script_source.contains("amount_input = LineEdit.new()"), "Bank amount input uses the custom interface styling")
	_check(popup_script_source.contains("var amount := _requested_amount()"), "Bank actions use the typed amount immediately")
	_check(popup_script_source.contains("header.gui_input.connect(_on_header_gui_input)"), "Bank window can be dragged by its header")
	_check(popup_script_source.contains('deposit_button.name = "DepositButton"'), "Bank provides a deposit action")
	_check(popup_script_source.contains('withdraw_button.name = "WithdrawButton"'), "Bank provides a withdraw action")
	_check(popup_script_source.contains('deposit_all_button.name = "DepositAllButton"'), "Bank provides a deposit all action")
	_check(popup_script_source.contains('withdraw_all_button.name = "WithdrawAllButton"'), "Bank provides a withdraw all action")
	_check(popup_script_source.contains("for quick_amount: int in [100, 1_000, 10_000]"), "Bank provides standard quick amounts")

	var wallet_source := FileAccess.get_file_as_string("res://scripts/services/player_wallet_service.gd")
	_check(wallet_source.contains('const PLAYER_BANK_TRANSFER_ENDPOINT := "/game/bank/transfer"'), "Wallet service uses the bank endpoint")
	_check(wallet_source.contains("PlayerSave.bank_money"), "Wallet results retain the protected balance")
	_check(template_source.contains('instance=ExtResource("13_banker")'), "Banker is owned by the shared center template")

	if failures == 0:
		print("PASS: Banker storage checks")
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failures += 1
	push_error("FAIL: %s" % message)
