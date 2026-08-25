extends SceneTree

const SERVICE_PATH := "res://scripts/services/guild_service.gd"
const PROJECT_PATH := "res://project.godot"

var failed := false


func _init() -> void:
	var service_source := FileAccess.get_file_as_string(SERVICE_PATH)
	var project_source := FileAccess.get_file_as_string(PROJECT_PATH)

	_check_contains(service_source, 'GUILDS_ENDPOINT := "/game/guilds"', "guild service uses the gateway guild endpoint")
	_check_contains(service_source, '"requestId": pending_creation_request_id', "guild creation has an idempotency key")
	_check_contains(service_source, "func load_directory", "guild service loads authoritative directory state")
	_check_contains(service_source, "func load_invitations", "guild service loads incoming invitations independently")
	_check_contains(service_source, 'GUILD_INVITATIONS_ENDPOINT := "/game/guild-invitations"', "guild invitation polling avoids loading the directory")
	_check_contains(service_source, "func create_guild", "guild service exposes creation")
	_check_contains(service_source, "func join_guild", "guild service joins open Guilds")
	_check_contains(service_source, "func apply_to_guild", "guild service submits membership applications")
	_check_contains(service_source, "func cancel_application", "guild service cancels the player's application")
	_check_contains(service_source, "func load_home", "guild service loads the member dashboard")
	_check_contains(service_source, "func leave_guild", "guild service exposes Guild departure")
	_check_contains(service_source, 'GUILD_HOME_ENDPOINT + "/leave"', "guild departure uses the member endpoint")
	_check_contains(service_source, "func teleport_to_lobby", "guild service exposes the free Lobby teleport")
	_check_contains(service_source, "func load_bank", "guild service loads the authoritative Guild Bank")
	_check_contains(service_source, "func load_history", "guild service loads membership and rank history")
	_check_contains(service_source, "func load_bank_log", "guild service loads categorized bank logs")
	_check_contains(service_source, "func deposit_bank_money", "guild service deposits Guild funds")
	_check_contains(service_source, "func withdraw_bank_money", "guild service withdraws Guild funds")
	_check_contains(service_source, "func deposit_bank_item", "guild service deposits Guild items")
	_check_contains(service_source, "func withdraw_bank_item", "guild service withdraws Guild items")
	_check_contains(service_source, "func borrow_bank_item", "guild service borrows Guild items without transferring ownership")
	_check_contains(service_source, "func borrow_bank_pokemon", "guild service borrows Guild Pokémon without transferring ownership")
	_check_contains(service_source, "func return_bank_loan_asset", "guild service returns individual borrowed assets")
	_check_contains(service_source, "func force_return_bank_loan_asset", "guild service exposes authorized force returns")
	_check_contains(service_source, "func deposit_bank_pokemon", "guild service deposits or returns Guild Pokémon")
	_check_contains(service_source, "func withdraw_bank_pokemon", "guild service withdraws Guild-owned Pokémon")
	_check_contains(service_source, 'GUILD_LOBBY_TELEPORT_ENDPOINT := "/game/guilds/me/lobby/teleport"', "guild service uses the dedicated Lobby endpoint")
	_check_contains(service_source, "func update_settings", "guild service updates leader settings")
	_check_contains(service_source, '"loanDurationSeconds": loan_duration_seconds', "guild settings preserve the selected loan duration")
	_check_contains(service_source, "func update_member_role", "guild service updates compact Guild ranks")
	_check_contains(service_source, "func update_member_bank_permissions", "guild service updates personal Guild Bank rights")
	_check_contains(service_source, '"/members/%d/bank-permissions"', "Guild Bank rights use the dedicated member endpoint")
	_check_contains(service_source, "func update_emblem", "guild service updates the emblem")
	_check_contains(service_source, "func apply_emblem_template", "guild service reapplies Guild-owned emblem templates")
	_check_contains(service_source, '"emblemTemplates": _array', "guild service preserves Guild-owned emblem templates")
	_check_contains(service_source, "signal guild_changed", "guild service publishes emblem changes to the nameplate")
	_check_contains(service_source, "current_guild", "guild service caches the current guild for the local nameplate")
	_check_contains(service_source, "func invite_member", "guild service sends invitations")
	_check_contains(service_source, "func accept_invitation", "guild service accepts invitations")
	_check_contains(service_source, "func decline_invitation", "guild service declines invitations")
	_check_contains(service_source, "func cancel_invitation", "guild service cancels invitations")
	_check_contains(service_source, "func accept_application", "guild service accepts membership applications")
	_check_contains(service_source, "func decline_application", "guild service declines membership applications")
	_check_contains(service_source, '"pendingApplications": _array', "guild service preserves pending applications")
	_check_contains(service_source, '"rankPermissions": _dictionary', "guild service preserves authoritative rank permissions")
	_check_contains(project_source, 'GuildService="*res://scripts/services/guild_service.gd"', "guild service is available as an autoload")

	quit(1 if failed else 0)


func _check_contains(source: String, expected: String, label: String) -> void:
	if source.contains(expected):
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
