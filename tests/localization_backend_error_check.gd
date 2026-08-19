extends SceneTree

const HTTP_SERVICE_PATHS: Array[String] = [
	"res://scripts/services/aether_atelier_service.gd",
	"res://scripts/services/auth_service.gd",
	"res://scripts/services/badge_progression_service.gd",
	"res://scripts/services/donator_store_service.gd",
	"res://scripts/services/guild_service.gd",
	"res://scripts/services/inventory_service.gd",
	"res://scripts/services/mail_service.gd",
	"res://scripts/services/market_service.gd",
	"res://scripts/services/moderator_teleport_service.gd",
	"res://scripts/services/party_heal_service.gd",
	"res://scripts/services/field_move_service.gd",
	"res://scripts/services/player_action_service.gd",
	"res://scripts/services/player_game_state_service.gd",
	"res://scripts/services/player_gameplay_reset_service.gd",
	"res://scripts/services/player_party_state_service.gd",
	"res://scripts/services/player_hotbar_service.gd",
	"res://scripts/services/player_stats_service.gd",
	"res://scripts/services/player_wallet_service.gd",
	"res://scripts/services/pokedex_service.gd",
	"res://scripts/services/pokemon_storage_service.gd",
	"res://scripts/services/social_service.gd",
	"res://scripts/services/trade_service.gd",
	"res://scripts/battle/battle_api/battle_api_client.gd",
	"res://scripts/battle/battle_api/pokemon_data_api_client.gd",
]

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var localization := root.get_node_or_null("LocalizationManager")
	var errors := root.get_node_or_null("BackendErrorLocalization")
	_check(localization != null, "LocalizationManager is available")
	_check(errors != null, "BackendErrorLocalization is available")
	if localization == null or errors == null:
		quit(1)
		return

	var original_locale := str(localization.get("current_locale"))
	var coded_response := {
		"status": 409,
		"body": {
			"detail": {
				"code": "guild_name_unavailable",
				"message": "That internal English detail must not reach the player.",
			},
		},
	}
	_check(errors.call("error_code", coded_response) == "guild_name_unavailable", "nested stable code is extracted")
	var update_response := {
		"status": 426,
		"body": {
			"detail": {
				"code": "client_update_required",
				"releaseVersion": "0.3.38",
				"requiredBuild": "private-build-id",
				"downloadUrl": "https://updates.example/game.zip",
			},
		},
	}
	var update_message := str(errors.call("message", update_response))
	_check(update_message.contains("0.3.38"), "update message shows the friendly release version")
	_check(not update_message.contains("private-build-id"), "update message hides the build identity")
	_check(not update_message.contains("https://"), "update message hides technical URLs")
	var login_source := FileAccess.get_file_as_string("res://scripts/ui/login_screen.gd")
	_check(
		login_source.contains('BackendErrorLocalizationService.message(result, "ui.login.error.sign_in")'),
		"login errors use the shared safe backend message"
	)

	localization.call("set_locale", "nl")
	_check(
		errors.call("message", coded_response) == "Die Guildnaam is al in gebruik.",
		"known backend code displays in Dutch"
	)
	_check(
		errors.call("message", {
			"detail": {"code": "GUILD_LOBBY_TRANSIT_ATTUNEMENT_REQUIRED"}
		}) == "Stem eerst af op een Aethernet Crystal voordat je naar de Aether Clash Lobby reist.",
		"Guild Lobby attunement requirement displays in Dutch"
	)
	_check(
		errors.call("message", {"detail": {"code": "current_password_incorrect"}})
		== "Het huidige wachtwoord is onjuist.",
		"privacy password errors explain how identity verification failed"
	)
	_check(
		errors.call("message", {
			"detail": {
				"code": "pokemon_level_cap_party_ineligible",
				"levelCap": 18.0,
			}
		}) == "Je team bevat een Pokémon boven de huidige levellimiet van 18.",
		"party level cap errors display whole-number caps"
	)
	_check(
		errors.call("message", {
			"detail": {
				"code": "trade_pokemon_level_cap_exceeded",
				"pokemonLevel": 20.0,
				"tradeLevelCap": 5.0,
			}
		}) == "Deze Pokémon is level 20 en komt boven de trade-levellimiet van de ontvanger (5).",
		"trade level cap errors include the relevant levels"
	)
	var unknown_response := {
		"detail": {
			"code": "future_sensitive_failure",
			"message": "database shard secret detail",
		},
	}
	var unknown_message := str(errors.call("message", unknown_response))
	_check(unknown_message == "Er ging iets mis. Probeer het opnieuw.", "unknown code uses safe Dutch fallback")
	_check(not unknown_message.contains("database"), "unknown error does not expose raw detail")
	_check(
		errors.call("diagnostic_message", unknown_response) == "database shard secret detail",
		"raw server detail remains available for diagnostics"
	)
	var referenced_response := {
		"detail": {
			"code": "service_error",
			"message": "private upstream failure",
			"supportId": "PA-ABCDEFGH2345",
		},
	}
	_check(
		errors.call("support_id", referenced_response) == "PA-ABCDEFGH2345",
		"safe support reference is extracted"
	)
	_check(
		errors.call("support_id", {"supportId": "PA-ABC]\nINJECTED"}) == "",
		"malformed support reference is rejected"
	)
	var dialog_service := root.get_node_or_null("GameErrorDialogService")
	_check(dialog_service != null, "GameErrorDialogService is available")
	if dialog_service != null:
		var referenced_lines: Array = dialog_service.call("response_lines", referenced_response)
		_check(referenced_lines.size() == 2, "reportable error includes message and reference")
		_check(
			str(referenced_lines[1]) == "Referentie: PA-ABCDEFGH2345",
			"support reference is localized"
		)
		_check(
			not "\n".join(referenced_lines).contains("private upstream"),
			"dialogue never exposes diagnostic server text"
		)
	var decorated: Dictionary = errors.call("decorate", coded_response)
	_check(decorated.get("errorCode") == "guild_name_unavailable", "decorated result preserves stable code")
	_check(decorated.has("diagnosticError"), "decorated result preserves diagnostic message separately")
	_check(decorated.get("error") == "Die Guildnaam is al in gebruik.", "decorated result exposes safe player message")

	localization.call("set_locale", "pt_BR")
	_check(
		errors.call("message", coded_response) == "Esse nome de Guilda já está em uso.",
		"known backend code displays in Brazilian Portuguese"
	)
	_check(
		errors.call("transport_message", HTTPRequest.RESULT_TIMEOUT) == "A solicitação expirou. Tente novamente.",
		"transport failures are localized"
	)
	var trade_service: Node = (load("res://scripts/services/trade_service.gd") as Script).new()
	_check(
		trade_service.call("_extract_error", coded_response.get("body"), 409) == "Esse nome de Guilda já está em uso.",
		"HTTP services route response bodies through the shared resolver"
	)
	trade_service.free()

	for locale: String in ["en", "nl", "pt_BR"]:
		var catalog: Dictionary = localization.call("get_catalog", locale)
		for key_value: Variant in errors.call("mapped_translation_keys"):
			_check(catalog.has(str(key_value)), "%s contains mapped backend key %s" % [locale, key_value])
	for path: String in HTTP_SERVICE_PATHS:
		_check(
			FileAccess.get_file_as_string(path).contains("BackendErrorLocalizationService"),
			"%s uses the shared backend error resolver" % path
		)

	localization.call("set_locale", original_locale)
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
