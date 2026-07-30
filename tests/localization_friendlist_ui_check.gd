extends SceneTree

const POPUP_SCENE_PATH := "res://scenes/interface/friendlist_popup.tscn"

var failed := false
var localization_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	localization_manager = root.get_node_or_null("LocalizationManager")
	_check(localization_manager != null, "Friend List localization check can access LocalizationManager")
	if localization_manager == null:
		quit(1)
		return

	var original_locale := str(localization_manager.get("current_locale"))
	localization_manager.call("set_locale", "nl")
	var packed := load(POPUP_SCENE_PATH) as PackedScene
	var popup := packed.instantiate()
	root.add_child(popup)
	await process_frame
	popup.overview = {
		"friends": [{
			"user": {
				"username": "misty",
				"displayName": "Misty",
				"online": true,
				"statusMessage": "",
			},
		}],
		"incomingFriendRequests": [],
		"outgoingFriendRequests": [],
		"blockedUsers": [],
		"profile": {"statusMessage": ""},
	}
	popup.call("_render_overview")

	_check(_tree_contains_text(popup, "Vrienden"), "Friend List title renders in Dutch")
	_check(_tree_contains_text(popup, "+  Vriend toevoegen"), "Friend List primary action renders in Dutch")
	_check(_tree_contains_text(popup, "1 vrienden · 1 online"), "Friend summary renders in Dutch")
	_check(_tree_contains_text(popup, "Geen statusbericht"), "Friend status fallback renders in Dutch")
	var search := popup.get("friend_search_input") as LineEdit
	_check(
		search != null and search.placeholder_text == "Zoek op naam of gebruikersnaam",
		"Friend search renders in Dutch"
	)

	localization_manager.call("set_locale", "pt_BR")
	await process_frame
	_check(_tree_contains_text(popup, "Amigos"), "Friend List title updates to Portuguese")
	_check(_tree_contains_text(popup, "+  Adicionar amigo"), "Friend action updates to Portuguese")
	_check(_tree_contains_text(popup, "1 amigos · 1 online"), "Friend summary updates to Portuguese")
	_check(_tree_contains_text(popup, "Sem mensagem de status"), "Status fallback updates to Portuguese")
	_check(
		search != null and search.placeholder_text == "Buscar por nome ou usuário",
		"Friend search updates to Portuguese"
	)

	popup.queue_free()
	await process_frame
	localization_manager.call("set_locale", original_locale)
	quit(1 if failed else 0)


func _tree_contains_text(node: Node, expected: String) -> bool:
	if node is Label and (node as Label).text == expected:
		return true
	if node is Button and (node as Button).text == expected:
		return true
	for child: Node in node.get_children():
		if _tree_contains_text(child, expected):
			return true
	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
