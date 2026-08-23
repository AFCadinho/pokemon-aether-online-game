extends SceneTree

const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"

var failed := false


func _init() -> void:
	var source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)
	var visibility := _function_block(source, "func _refresh_dev_tools_visibility()")
	var open_dev_actions := _function_block(source, "func _can_open_dev_actions()")
	var open_dev_menu := _function_block(source, "func _on_dev_actions_button_pressed()")
	var open_resources := _function_block(source, "func _on_dev_add_button_pressed()")
	var open_items := _function_block(source, "func _on_dev_add_item_button_pressed()")
	var search_items := _function_block(source, "func _refresh_dev_item_results()")
	var select_item := _function_block(source, "func _on_dev_item_result_selected(item: Dictionary)")
	var create_item := _function_block(source, "func _on_dev_item_confirm_pressed()")
	var create_dev_pokemon := _function_block(source, "func _on_dev_add_pokemon_button_pressed()")
	var spawn_encounter := _function_block(source, "func _on_dev_spawn_pokemon_button_pressed()")
	var add_currency := _function_block(source, "func _on_dev_add_money_button_pressed()")
	var create_alpha_pokemon := _function_block(source, "func _on_alpha_create_pokemon_button_pressed()")

	_check(
		source.contains('const DEV_ITEM_GENERATING_PERMISSION := "items:generating"'),
		"item generation has a narrow client permission"
	)
	_check(
		source.contains('const DEV_POKEMON_GENERATING_PERMISSION := "pokemon:generating"'),
		"unrestricted developer Pokemon generation has a narrow client permission"
	)
	_check(
		open_dev_actions.contains("return _can_use_dev_tools() or _can_generate_dev_items()"),
		"item-only users can open the Developer Tools launcher"
	)
	_check(
		visibility.contains("dev_add_pokemon_button.visible = can_generate_dev_pokemon")
		and visibility.contains("dev_spawn_pokemon_button.visible = can_use_dev_tools")
		and visibility.contains("dev_world_preview_panel.visible = can_use_dev_tools")
		and visibility.contains("dev_cleanup_test_pokemon_button.visible = can_use_dev_tools"),
		"only unrestricted Pokemon generation needs the additional Pokemon permission"
	)
	_check(
		visibility.contains("dev_add_item_button.visible = can_generate_dev_items")
		and visibility.contains("dev_add_button.visible = can_open_dev_actions")
		and visibility.contains("dev_add_money_button.visible = can_use_dev_tools"),
		"tester resources include both items and currencies"
	)
	_check(
		open_dev_menu.contains("if not _can_open_dev_actions():")
		and open_resources.contains("if not _can_open_dev_actions():"),
		"item-only access is checked again when menus are opened"
	)
	_check(
		open_items.contains("if not _can_generate_dev_items():")
		and search_items.contains("if not _can_generate_dev_items():")
		and select_item.contains("if not _can_generate_dev_items():")
		and create_item.contains("if not _can_generate_dev_items():"),
		"every interactive item-generator step rechecks item access"
	)
	_check(
		create_dev_pokemon.contains("if not _can_generate_dev_pokemon():")
		and spawn_encounter.contains("if not _can_use_dev_tools():")
		and add_currency.contains("if not _can_use_dev_tools():")
		and create_alpha_pokemon.contains("if not _can_use_content_creator_generation():"),
		"Pokemon creation, general tester tools, and Alpha generation keep separate guards"
	)

	quit(1 if failed else 0)


func _function_block(source: String, function_header: String) -> String:
	var start := source.find(function_header)
	if start < 0:
		return ""
	var end := source.find("\nfunc ", start + function_header.length())
	return source.substr(start) if end < 0 else source.substr(start, end - start)


func _check(value: bool, label: String) -> void:
	if value:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
