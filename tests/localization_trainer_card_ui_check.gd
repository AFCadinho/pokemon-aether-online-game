extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"

var failed := false
var localization_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	localization_manager = root.get_node_or_null("LocalizationManager")
	_check(localization_manager != null, "Trainer Card localization check can access LocalizationManager")
	if localization_manager == null:
		quit(1)
		return

	var original_locale := str(localization_manager.get("current_locale"))
	_check_trainer_card_runtime_translation()
	localization_manager.call("set_locale", original_locale)
	await process_frame
	quit(1 if failed else 0)


func _check_trainer_card_runtime_translation() -> void:
	var packed := load(OVERLAY_SCENE_PATH) as PackedScene
	_check(packed != null, "localized Trainer Card overlay loads")
	if packed == null:
		return

	var overlay := packed.instantiate()
	overlay.set("root_control", overlay.get_node_or_null("Control"))
	localization_manager.call("set_locale", "nl")
	overlay.call("_setup_trainer_card_popup")

	var popup := overlay.get("trainer_card_popup") as PanelContainer
	var tabs := overlay.get("trainer_card_tabs") as TabContainer
	var subtitle := overlay.get("trainer_card_subtitle_label") as Label
	var save_button := overlay.get("trainer_card_appearance_save_button") as Button
	var status_label := overlay.get("trainer_card_appearance_status_label") as Label
	var badge_option := overlay.get("trainer_card_badge_option") as OptionButton
	var redeem_button := popup.find_child("RedeemCodeButton", true, false) as Button if popup != null else null

	_check(tabs != null and tabs.get_tab_title(1) == "Portemonnee", "Trainer Card tab renders in Dutch")
	_check(subtitle != null and subtitle.text.begins_with("TRAINERPASPOORT"), "Trainer Card passport renders in Dutch")
	_check(redeem_button != null and redeem_button.text == "Code inwisselen", "Trainer Card redeem action renders in Dutch")
	_check(_find_label(popup, "VALUTAPORTEMONNEE") != null, "Trainer Card wallet renders in Dutch")
	_check(_find_label(popup, "VOORTGANGSLIMIETEN") != null, "Trainer Card progression limits render in Dutch")
	_check(_find_label(popup, "Levellimiet") != null, "Trainer Card level cap renders in Dutch")
	_check(_find_label(popup, "Trade-limiet") != null, "Trainer Card trade cap renders in Dutch")
	_check(_find_label(popup, "Natuurlijke kleuren") != null, "Appearance colors render in Dutch")
	_check(badge_option != null and badge_option.get_item_text(0) == "Geen", "Trainer Card badge fallback renders in Dutch")
	var badge_popup := badge_option.get_popup() if badge_option != null else null
	_check(
		badge_option != null
		and badge_option.has_theme_icon_override("arrow")
		and badge_option.has_theme_stylebox_override("disabled"),
		"Trainer Card badge selector styles its arrow and disabled state"
	)
	_check(
		badge_popup != null
		and badge_popup.transparent_bg
		and badge_popup.borderless
		and badge_popup.has_theme_stylebox_override("panel")
		and badge_popup.has_theme_stylebox_override("hover"),
		"Trainer Card badge dropdown uses a dedicated popup surface"
	)
	_check(
		badge_popup != null
		and badge_popup.has_theme_icon_override("radio_checked")
		and badge_popup.has_theme_icon_override("radio_unchecked"),
		"Trainer Card badge dropdown replaces the default Godot selection icons"
	)
	_check(overlay.call("_format_appearance_option_name", "body", "Gen4_Base_v1") == "Standaard", "Appearance option renders in Dutch")
	_check(overlay.call("_format_appearance_option_name", "hair", "IronFanton_Hair") == "IronFanton-haar", "IronFanton hair renders in Dutch")
	_check(overlay.call("_format_appearance_swatch_name", "Dark Brown") == "Donkerbruin", "Appearance swatch renders in Dutch")

	overlay.set("trainer_card_has_unsaved_appearance_changes", true)
	overlay.call("_update_trainer_card_appearance_save_state")
	_check(save_button != null and save_button.text == "Opslaan", "Appearance save action renders in Dutch")
	_check(status_label != null and status_label.text.begins_with("Niet-opgeslagen"), "Appearance status renders in Dutch")

	localization_manager.call("set_locale", "pt_BR")
	overlay.call("_refresh_trainer_card_localized_ui")
	_check(tabs != null and tabs.get_tab_title(1) == "Carteira", "Trainer Card tab updates to Portuguese")
	_check(subtitle != null and subtitle.text.begins_with("PASSAPORTE DE TREINADOR"), "Trainer Card passport updates to Portuguese")
	_check(redeem_button != null and redeem_button.text == "Resgatar código", "Trainer Card redeem action updates to Portuguese")
	_check(_find_label(popup, "CARTEIRA DE MOEDAS") != null, "Trainer Card wallet updates to Portuguese")
	_check(_find_label(popup, "LIMITES DE PROGRESSÃO") != null, "Trainer Card progression limits update to Portuguese")
	_check(_find_label(popup, "Limite de nível") != null, "Trainer Card level cap updates to Portuguese")
	_check(_find_label(popup, "Limite de troca") != null, "Trainer Card trade cap updates to Portuguese")
	_check(_find_label(popup, "Cores naturais") != null, "Appearance colors update to Portuguese")
	_check(badge_option != null and badge_option.get_item_text(0) == "Nenhum", "Trainer Card badge fallback updates to Portuguese")
	_check(save_button != null and save_button.text == "Salvar", "Appearance save action updates to Portuguese")
	_check(status_label != null and status_label.text.begins_with("Alterações"), "Appearance status updates to Portuguese")
	_check(overlay.call("_format_appearance_swatch_name", "Dark Brown") == "Marrom-escuro", "Appearance swatch updates to Portuguese")
	_check(overlay.call("_format_appearance_option_name", "top", "IronFanton_Shirt") == "Camisa IronFanton", "IronFanton shirt updates to Portuguese")

	if popup != null:
		var minimum_size := popup.get_combined_minimum_size()
		_check(minimum_size.x <= 720.0 and minimum_size.y <= 500.0, "Trainer Card translations fit the designed popup bounds")

	for loader_property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader := overlay.get(loader_property) as Node
		if loader != null:
			loader.free()
	overlay.free()


func _find_label(node: Node, text: String) -> Label:
	if node == null:
		return null
	if node is Label and (node as Label).text == text:
		return node as Label
	for child: Node in node.get_children():
		var result := _find_label(child, text)
		if result != null:
			return result
	return null


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
