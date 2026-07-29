extends SceneTree

const TOOLTIP_FILES := [
	"res://scenes/interface/ui_overlay.tscn",
	"res://scenes/interface/hotkey_sidebar.tscn",
	"res://scenes/interface/party_slot.tscn",
	"res://scenes/battle/pokemon_info_hud.tscn",
	"res://scenes/battle/party_slot.tscn",
	"res://scripts/ui/ui_overlay.gd",
	"res://scripts/ui/donator_store_popup.gd",
	"res://scripts/ui/trade_workspace.gd",
	"res://scripts/ui/party_slot.gd",
	"res://scripts/ui/bag_item_effect_preview.gd",
	"res://scripts/battle/battle.gd",
	"res://scripts/battle/battle_ui/party_slot.gd",
]

const TECHNICAL_TOOLTIP_PHRASES := [
	"authoritative Store catalog",
	"server team validation",
	"Locked revision",
	"Verification %s",
	"ownership id",
	"release drop zone",
	"Searches every loaded box",
	"Read-only preview",
	"Remove item stack",
	"Not implemented yet",
	"Hotkey 1",
	'tooltip_text = "Active Pokemon"',
	'tooltip_text = "Shiny Pokemon"',
]

var failed := false


func _init() -> void:
	var combined_source := ""
	for file_path: String in TOOLTIP_FILES:
		combined_source += FileAccess.get_file_as_string(file_path)

	for phrase: String in TECHNICAL_TOOLTIP_PHRASES:
		_check(not combined_source.contains(phrase), "tooltips avoid technical phrase: %s" % phrase)

	_check(combined_source.contains('"Create Pokémon for the Alpha"'), "Alpha Tools explains its player-facing purpose")
	_check(combined_source.contains('tooltip_text = "Search all storage boxes"'), "storage search uses everyday language")
	_check(combined_source.contains('tooltip_text = "Checking whether your team can enter ranked battles..."'), "ranked team checks use player-facing language")
	_check(combined_source.contains('"ui.store.safety"'), "Store safety avoids backend terminology")
	_check(combined_source.contains('"ui.trade.review.tooltip"'), "localized trade safety describes what players need to do")

	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
