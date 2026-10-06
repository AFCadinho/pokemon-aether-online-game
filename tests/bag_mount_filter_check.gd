extends SceneTree

const Filter := preload("res://scripts/ui/bag_mount_filter.gd")
const Mounts := preload("res://scripts/services/mount_service.gd")
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var localization := root.get_node("LocalizationManager")
	var settings := root.get_node("SettingsManager")
	var original_tab: String = settings.bag_mount_tab
	var original_locale: String = localization.current_locale
	localization.set_locale("en")
	settings.set_bag_mount_tab("all")
	for mode: String in ["land", "surf"]:
		for mount_id: String in Mounts.get_mount_ids_for_mode(mode):
			var item_id := Mounts.get_mount_unlock_item_id(mount_id)
			if item_id.is_empty():
				continue
			for suffix: String in ["", "-bound"]:
				var item := {"id": item_id + suffix, "category": "mounts", "tradable": suffix.is_empty()}
				_check(Filter.matches(item, mode) and not Filter.matches(item, "boxes"), "Catalog mount is classified correctly: " + item_id + suffix)
	var land := {"id": "cyclizar-mount", "name": "Cyclizar Mount", "category": "mounts", "quantity": 1, "tradable": false}
	var surf := {"id": "primal-kyogre-mount", "name": "Primal Kyogre Mount", "category": "mounts", "quantity": 1, "tradable": true}
	var box := {"id": "glaceon-mount-box", "name": "Glaceon Mount Box", "category": "mounts", "quantity": 2, "tradable": true, "useAction": "open_mount_box"}
	var bound_box := {"id": "primal-kyogre-mount-box-bound", "name": "Primal Kyogre Mount Box", "category": "mounts", "quantity": 1, "tradable": false, "useAction": "open_mount_box"}
	_check(Filter.matches(box, "boxes") and not Filter.matches(box, "land") and Filter.movement_mode(box) == "land", "Land boxes stay in Boxes and retain a Land label")
	_check(Filter.matches(bound_box, "boxes", 2) and not Filter.matches(bound_box, "surf") and Filter.movement_mode(bound_box) == "surf", "Bound Surf boxes stay in Boxes and retain a Surf label")
	_check(not Filter.matches(bound_box, "boxes", 1) and not Filter.matches(box, "boxes", 2), "Tradeability filtering does not mix binding variants")
	_check(Filter.matches_search(box, " GLACEON ") and Filter.normalize_tab("invalid") == "all", "Search and stored-tab validation are robust")
	var scene := load("res://scenes/interface/ui_overlay.tscn") as PackedScene
	var overlay := scene.instantiate()
	overlay.set("root_control", overlay.get_node("Control"))
	overlay.call("_setup_bag_popup")
	var filter_popup: PopupMenu = overlay.bag_mount_tradeability_select.get_popup()
	var popup_panel := filter_popup.get_theme_stylebox("panel") as StyleBoxFlat
	var popup_hover := filter_popup.get_theme_stylebox("hover") as StyleBoxFlat
	_check(filter_popup.transparent_bg and filter_popup.borderless, "Mount filter popup supports rounded transparent edges")
	_check(popup_panel != null and popup_panel.bg_color == Color("#050e18fc") and popup_panel.corner_radius_top_left == 8, "Mount filter popup uses the dark rounded Bag menu style")
	_check(popup_hover != null and popup_hover.bg_color == Color("#17283bf8") and popup_hover.border_width_left == 1, "Mount filter rows have a clear highlighted hover state")
	_check(filter_popup.get_theme_font_size("font_size") == overlay.bag_mount_tradeability_select.get_theme_font_size("font_size") and filter_popup.get_theme_constant("v_separation") == 6, "Mount filter popup matches the button typography with spaced rows")
	_check(filter_popup.get_theme_icon("radio_checked") == overlay.RANKED_DROPDOWN_RADIO_CHECKED and filter_popup.get_theme_icon("radio_unchecked") == overlay.RANKED_DROPDOWN_RADIO_UNCHECKED, "Mount filter popup replaces default Godot radio icons")
	overlay.bag_inventory_loaded = true
	overlay.bag_inventory_items.assign([bound_box, surf, box, land])
	overlay.call("_on_bag_category_selected", "mounts")
	_check(overlay.bag_mount_filter_bar.visible and overlay.bag_item_slots.size() == 4, "Mount category shows its controls and all inventory variants")
	_check(overlay.bag_item_grid.get_child(0).hotbar_item["id"] == "cyclizar-mount", "Mounts are sorted alphabetically")
	overlay.bag_mount_tab_buttons["boxes"].pressed.emit()
	_check(overlay.bag_item_slots.size() == 2 and settings.bag_mount_tab == "boxes", "Box tab selects only boxes and persists the choice")
	var saved_settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(settings.SETTINGS_PATH))
	_check(saved_settings.get("bag_mount_tab") == "boxes", "The chosen mount tab is stored for the next session")
	_check(overlay.bag_item_grid.get_child(0).find_child("MountBoxMode", true, false).text == "Land", "Box cards render their movement label")
	overlay.bag_mount_tradeability_select.item_selected.emit(2)
	_check(overlay.bag_item_slots.size() == 1 and overlay.bag_selected_item["id"] == bound_box["id"], "Filtering clears a hidden selection and inspects the correct bound box")
	overlay.bag_search_input.text = "glaceon"
	overlay.call("_on_bag_search_changed", "glaceon")
	_check(overlay.bag_item_slots.is_empty() and overlay.bag_selected_item.is_empty(), "Combined search and binding filters show a safe empty result")
	overlay.bag_search_input.text = ""
	overlay.call("_on_bag_category_selected", "medicine")
	_check(not overlay.bag_mount_filter_bar.visible, "Mount controls are hidden for other Bag categories")
	overlay.call("_on_bag_category_selected", "mounts")
	_check(overlay.bag_mount_tab == "boxes", "Switching Bag categories retains the mount tab")
	localization.set_locale("nl")
	overlay.call("_refresh_bag_localized_ui")
	_check(overlay.bag_mount_tab_buttons["all"].text.begins_with("Alles") and overlay.bag_mount_tradeability_select.get_item_text(1) == "Verhandelbaar", "Mount filters update with the Bag language")
	overlay.free()
	settings.set_bag_mount_tab(original_tab)
	localization.set_locale(original_locale)
	quit.call_deferred(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failures += 1
		push_error("FAIL " + message)
