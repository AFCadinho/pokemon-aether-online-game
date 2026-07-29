extends SceneTree

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var workspace_script := load("res://scripts/ui/trade_workspace.gd") as Script
	var workspace := workspace_script.new() as Window
	root.add_child(workspace)
	await process_frame
	var localization_manager := root.get_node_or_null("LocalizationManager")
	_check(localization_manager != null, "localization manager is available")
	if localization_manager != null:
		localization_manager.set_locale("nl")
		await process_frame
		_check(workspace.title == "Ruilen met speler", "trade window title refreshes in Dutch")
		_check(_find_button(workspace, "Aanbod gereed") != null, "Ready action refreshes in Dutch")
		var search := _find_line_edit_with_placeholder(
			workspace,
			"Zoek ruilbare items op naam of categorie"
		)
		_check(search != null, "item search refreshes in Dutch")
		localization_manager.set_locale("pt_BR")
		await process_frame
		_check(workspace.title == "Troca entre jogadores", "trade title refreshes in Brazilian Portuguese")
		localization_manager.set_locale("en")
		await process_frame
	workspace.queue_free()
	quit(1 if failed else 0)


func _find_button(node: Node, expected: String) -> Button:
	if node is Button and (node as Button).text == expected:
		return node as Button
	for child: Node in node.get_children():
		var match := _find_button(child, expected)
		if match != null:
			return match
	return null


func _find_line_edit_with_placeholder(node: Node, expected: String) -> LineEdit:
	if node is LineEdit and (node as LineEdit).placeholder_text == expected:
		return node as LineEdit
	for child: Node in node.get_children():
		var match := _find_line_edit_with_placeholder(child, expected)
		if match != null:
			return match
	return null


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
