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
	var save_bar := popup.find_child("AppearanceSaveBar", true, false) as Control if popup != null else null
	var preview_panel := popup.find_child("AppearancePreviewPanel", true, false) as Control if popup != null else null
	var preview_viewport := _find_subviewport(preview_panel)
	var category_rail := popup.find_child("AppearanceCategoryRail", true, false) as VBoxContainer if popup != null else null
	var content_stack := popup.find_child("AppearanceContentStack", true, false) as VBoxContainer if popup != null else null
	var swatch_row := popup.find_child("NaturalColorSwatches", true, false) as HBoxContainer if popup != null else null
	var badge_option := overlay.get("trainer_card_badge_option") as OptionButton
	var redeem_button := popup.find_child("RedeemCodeButton", true, false) as Button if popup != null else null

	_check(
		tabs != null
		and tabs.get_tab_title(0) == "Overzicht"
		and tabs.get_tab_title(1) == "Badges"
		and tabs.get_tab_title(3) == "Portemonnee",
		"Trainer Card navigation renders in the intended Dutch order"
	)
	_check(subtitle != null and subtitle.text.begins_with("TRAINERPASPOORT"), "Trainer Card passport renders in Dutch")
	_check(redeem_button != null and redeem_button.text == "Code inwisselen", "Trainer Card redeem action renders in Dutch")
	_check(_find_label(popup, "VALUTAPORTEMONNEE") != null, "Trainer Card wallet renders in Dutch")
	_check(_find_label(popup, "VOORTGANGSLIMIETEN") != null, "Trainer Card progression limits render in Dutch")
	_check(_find_label(popup, "Levellimiet") != null, "Trainer Card level cap renders in Dutch")
	_check(_find_label(popup, "Trade-limiet") != null, "Trainer Card trade cap renders in Dutch")
	_check(_find_label(popup, "Natuurlijke kleuren") != null, "Appearance colors render in Dutch")
	_check(
		preview_viewport != null
		and preview_viewport.size == Vector2i(194, 248)
		and preview_viewport.get_meta("preview_scale", Vector2.ZERO) == Vector2(3.0, 3.0),
		"Appearance uses a large full-body preview"
	)
	_check(
		category_rail != null
		and category_rail.get_child_count() == 9
		and _all_category_buttons_toggle(category_rail),
		"Appearance category rail stays compact and clearly selectable"
	)
	_check(
		tabs != null
		and tabs.get_tab_bar().focus_mode == Control.FOCUS_ALL
		and category_rail != null
		and _all_category_buttons_focusable(category_rail),
		"Trainer Card tabs and Appearance categories support keyboard focus"
	)
	_check(
		content_stack != null and _find_line_edit(content_stack) == null,
		"Appearance omits search when the body catalog is short"
	)
	_check(
		swatch_row != null and _swatches_have_labels(swatch_row),
		"Appearance natural-color swatches have explicit labels"
	)
	_check(save_bar != null and not save_bar.visible, "Appearance save feedback stays hidden when clean")
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
	overlay.set("appearance_inventory_slot_counts", {"top": 1})
	var top_category_button := category_rail.get_child(6) as Button if category_rail != null else null
	if top_category_button != null and content_stack != null:
		overlay.call(
			"_on_trainer_card_appearance_category_selected",
			top_category_button,
			content_stack,
			"top"
		)
	var part_buttons: Dictionary = overlay.get("trainer_card_part_buttons") as Dictionary
	var starter_shirt_button := part_buttons.get("top:Shirt") as Button
	var unequip_button := overlay.get("trainer_card_appearance_unequip_button") as Button
	var return_button := overlay.get("trainer_card_appearance_return_button") as Button
	var wardrobe_toolbar := popup.find_child("AppearanceWardrobeToolbar", true, false) as VBoxContainer if popup != null else null
	var wardrobe_capacity := popup.find_child("AppearanceWardrobeCapacity", true, false) as Label if popup != null else null
	var wardrobe_actions := popup.find_child("AppearanceWardrobeActions", true, false) as HBoxContainer if popup != null else null
	_check(not part_buttons.has("top:"), "Appearance no longer presents None as a wardrobe item")
	_check(
		starter_shirt_button != null
		and starter_shirt_button.icon != null
		and starter_shirt_button.custom_minimum_size.y >= 58.0,
		"Appearance wardrobe cards show recognizable sprite thumbnails"
	)
	_check(unequip_button != null and unequip_button.text == "Uittrekken", "Unequip is a compact Dutch category action")
	_check(return_button != null and return_button.text == "Naar Bag", "Return to Bag is clearly labeled in Dutch")
	_check(
		wardrobe_toolbar != null
		and wardrobe_capacity != null
		and wardrobe_capacity.get_parent() == wardrobe_toolbar
		and wardrobe_actions != null
		and wardrobe_actions.get_parent() == wardrobe_toolbar,
		"Appearance keeps wardrobe capacity on its own readable row"
	)
	_check(
		wardrobe_capacity != null
		and wardrobe_capacity.text.contains("1/8")
		and wardrobe_capacity.tooltip_text == wardrobe_capacity.text,
		"Appearance keeps the complete wardrobe capacity available"
	)
	var player_save := root.get_node_or_null("PlayerSave")
	var original_hair_id := str(player_save.get("appearance_hair_id")) if player_save != null else ""
	var hair_category_button := category_rail.get_child(2) as Button if category_rail != null else null
	if hair_category_button != null and content_stack != null:
		overlay.call(
			"_on_trainer_card_appearance_category_selected",
			hair_category_button,
			content_stack,
			"hair"
		)
	unequip_button = overlay.get("trainer_card_appearance_unequip_button") as Button
	_check(
		unequip_button != null
		and unequip_button.text == "Kaal / Geen haar"
		and unequip_button.visible
		and unequip_button.toggle_mode,
		"Hair uses an explicit Dutch no-hair choice"
	)
	if player_save != null:
		player_save.set("appearance_hair_id", "")
	overlay.call("_refresh_trainer_card_appearance_actions")
	_check(
		unequip_button != null and unequip_button.button_pressed,
		"The no-hair choice shows its selected state"
	)
	if player_save != null:
		player_save.set("appearance_hair_id", original_hair_id)
	var body_category_button := category_rail.get_child(1) as Button if category_rail != null else null
	if body_category_button != null and content_stack != null:
		overlay.call(
			"_on_trainer_card_appearance_category_selected",
			body_category_button,
			content_stack,
			"body"
		)

	overlay.set("trainer_card_has_unsaved_appearance_changes", true)
	overlay.call("_update_trainer_card_appearance_save_state")
	_check(save_bar != null and save_bar.visible, "Appearance save feedback appears for unsaved changes")
	_check(save_button != null and save_button.text == "Opslaan", "Appearance save action renders in Dutch")
	_check(status_label != null and status_label.text.begins_with("Niet-opgeslagen"), "Appearance status renders in Dutch")

	localization_manager.call("set_locale", "pt_BR")
	overlay.call("_refresh_trainer_card_localized_ui")
	_check(
		tabs != null
		and tabs.get_tab_title(0) == "Visão geral"
		and tabs.get_tab_title(1) == "Insígnias"
		and tabs.get_tab_title(3) == "Carteira",
		"Trainer Card navigation updates to Portuguese"
	)
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
	if hair_category_button != null and content_stack != null:
		overlay.call(
			"_on_trainer_card_appearance_category_selected",
			hair_category_button,
			content_stack,
			"hair"
		)
	unequip_button = overlay.get("trainer_card_appearance_unequip_button") as Button
	_check(
		unequip_button != null and unequip_button.text == "Careca / Sem cabelo",
		"No-hair choice updates to Portuguese"
	)
	if top_category_button != null and content_stack != null:
		overlay.call(
			"_on_trainer_card_appearance_category_selected",
			top_category_button,
			content_stack,
			"top"
		)
	unequip_button = overlay.get("trainer_card_appearance_unequip_button") as Button
	return_button = overlay.get("trainer_card_appearance_return_button") as Button
	_check(unequip_button != null and unequip_button.text == "Retirar", "Unequip action updates to Portuguese")
	_check(return_button != null and return_button.text == "À Bolsa", "Return-to-Bag action updates to Portuguese")

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


func _find_subviewport(node: Node) -> SubViewport:
	if node == null:
		return null
	if node is SubViewport:
		return node as SubViewport
	for child: Node in node.get_children():
		var result := _find_subviewport(child)
		if result != null:
			return result
	return null


func _find_line_edit(node: Node) -> LineEdit:
	if node == null:
		return null
	if node is LineEdit:
		return node as LineEdit
	for child: Node in node.get_children():
		var result := _find_line_edit(child)
		if result != null:
			return result
	return null


func _all_category_buttons_toggle(category_rail: VBoxContainer) -> bool:
	for child: Node in category_rail.get_children():
		if child is Button and not (child as Button).toggle_mode:
			return false
	return true


func _all_category_buttons_focusable(category_rail: VBoxContainer) -> bool:
	for child: Node in category_rail.get_children():
		if child is Button and (child as Button).focus_mode != Control.FOCUS_ALL:
			return false
	return true


func _swatches_have_labels(swatch_row: HBoxContainer) -> bool:
	if swatch_row.get_child_count() != 3:
		return false
	for child: Node in swatch_row.get_children():
		if not child is VBoxContainer or child.get_child_count() < 2:
			return false
		if not child.get_child(0) is Label or not child.get_child(1) is Button:
			return false
	return true


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
