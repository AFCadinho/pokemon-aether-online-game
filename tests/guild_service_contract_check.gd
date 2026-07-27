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
	_check_contains(service_source, "func create_guild", "guild service exposes creation")
	_check_contains(service_source, "func load_home", "guild service loads the member dashboard")
	_check_contains(service_source, "func update_settings", "guild service updates leader settings")
	_check_contains(service_source, "func update_emblem", "guild service updates the emblem")
	_check_contains(service_source, "func apply_emblem_template", "guild service reapplies Guild-owned emblem templates")
	_check_contains(service_source, '"emblemTemplates": _array', "guild service preserves Guild-owned emblem templates")
	_check_contains(service_source, "signal guild_changed", "guild service publishes emblem changes to the nameplate")
	_check_contains(service_source, "current_guild", "guild service caches the current guild for the local nameplate")
	_check_contains(service_source, "func invite_member", "guild service sends invitations")
	_check_contains(service_source, "func accept_invitation", "guild service accepts invitations")
	_check_contains(service_source, "func decline_invitation", "guild service declines invitations")
	_check_contains(service_source, "func cancel_invitation", "guild service cancels invitations")
	_check_contains(project_source, 'GuildService="*res://scripts/services/guild_service.gd"', "guild service is available as an autoload")

	quit(1 if failed else 0)


func _check_contains(source: String, expected: String, label: String) -> void:
	if source.contains(expected):
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
