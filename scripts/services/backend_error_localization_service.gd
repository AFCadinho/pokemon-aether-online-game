extends Node

class_name BackendErrorLocalizationService

const DEFAULT_FALLBACK_KEY := "backend.error.generic"
const CATALOG_PATHS: Dictionary = {
	"en": "res://localization/en.json",
	"nl": "res://localization/nl.json",
	"pt_BR": "res://localization/pt_BR.json",
}

const CODE_TO_KEY: Dictionary = {
	"unauthorized": "backend.error.auth_required",
	"not_authenticated": "backend.error.auth_required",
	"authentication_required": "backend.error.auth_required",
	"email_not_verified": "ui.login.error.email_not_verified",
	"missing_bearer_token": "backend.error.auth_required",
	"invalid_bearer_token": "backend.error.auth_required",
	"client_update_required": "backend.error.client_update_required",
	"action_forbidden": "backend.error.action_blocked",
	"resource_not_found": "backend.error.unavailable",
	"request_failed": "backend.error.generic",
	"service_error": "backend.error.generic",
	"not_enough_money": "backend.error.not_enough_money",
	"not_enough_gems": "backend.error.not_enough_gems",
	"item_not_found": "backend.error.item_not_found",
	"item_not_owned": "backend.error.item_not_owned",
	"item_not_usable": "backend.error.item_not_usable",
	"item_no_effect": "backend.error.item_no_effect",
	"item_unsupported": "backend.error.item_unsupported",
	"item_not_tradable": "ui.trade.error.item_not_tradable",
	"item_reserved_for_trade": "ui.trade.error.item_reserved",
	"already_in_guild": "ui.guild.error.already_member",
	"guild_badges_required": "ui.guild.error.badges_required",
	"guild_name_unavailable": "backend.error.guild_name_unavailable",
	"guild_full": "backend.error.guild_full",
	"guild_invite_forbidden": "backend.error.guild_invite_forbidden",
	"guild_invite_target_not_found": "backend.error.trainer_not_found",
	"guild_invite_self": "ui.guild.error.already_member",
	"guild_invite_target_joined": "backend.error.guild_target_joined",
	"guild_invite_pending": "backend.error.guild_invite_pending",
	"guild_invitation_not_found": "backend.error.guild_invitation_unavailable",
	"guild_invitation_invalid": "backend.error.guild_invitation_unavailable",
	"guild_invitation_resolved": "backend.error.guild_invitation_unavailable",
	"guild_invitation_expired": "backend.error.guild_invitation_expired",
	"guild_membership_not_found": "backend.error.guild_membership_not_found",
	"guild_not_found": "backend.error.guild_not_found",
	"guild_leader_required": "backend.error.guild_leader_required",
	"guild_emblem_template_not_found": "backend.error.guild_emblem_unavailable",
	"guild_emblem_template_already_unlocked": "backend.error.guild_emblem_unlocked",
	"guild_request_id_conflict": "backend.error.request_conflict",
	"guild_creation_conflict": "backend.error.request_conflict",
	"guild_creation_incomplete": "ui.guild.error.create",
	"pokemon_reserved_for_trade": "ui.trade.error.pokemon_reserved",
	"pokemon_holding_item": "ui.trade.error.pokemon_holding_item",
	"pokemon_not_tradable": "ui.trade.error.pokemon_not_tradable",
	"pokemon_not_owned_or_held": "ui.trade.error.pokemon_not_owned",
	"pokemon_location_stale": "ui.trade.error.pokemon_moved",
	"trade_offer_requires_party_pokemon": "ui.trade.error.party_last",
	"trade_item_quantity_unavailable": "ui.trade.error.item_quantity",
	"trade_item_quantity_changed": "ui.trade.error.item_quantity",
	"trade_item_snapshot_changed": "ui.trade.error.item_changed",
	"trade_money_unavailable": "ui.trade.error.money_changed",
	"trade_money_balance_changed": "ui.trade.error.money_changed",
	"money_reserved_for_trade": "ui.trade.error.money_reserved",
	"trade_offer_party_only": "ui.trade.error.party_only",
	"trade_party_capacity_exceeded": "ui.trade.error.opponent_party_full",
	"trade_party_capacity_invalid": "ui.trade.error.party_space",
	"trade_party_space_required": "ui.trade.error.party_space",
	"trade_offer_required": "ui.trade.error.offer_required",
	"trade_review_mismatch": "ui.trade.error.review_changed",
	"trade_review_not_locked": "ui.trade.error.review_not_locked",
	"trade_settlement_invalidated": "ui.trade.error.settlement_invalidated",
	"trade_settlement_retryable": "ui.trade.error.settlement_retry",
	"trade_confirmation_stale": "ui.trade.error.stale",
	"trade_rate_limited": "backend.error.rate_limited",
	"trade_rollout_unavailable": "ui.trade.error.service_unavailable",
	"trade_payload_too_large": "backend.error.payload_too_large",
	"aether_atelier_missing_components": "ui.atelier.error.components",
	"aether_atelier_outfit_not_found": "backend.error.item_unavailable",
	"aether_atelier_chroma_not_found": "backend.error.item_unavailable",
	"aether_atelier_chroma_not_in_wardrobe": "backend.error.item_not_owned",
	"aether_atelier_wear_item_not_owned": "backend.error.item_not_owned",
	"aether_atelier_chroma_unchanged": "backend.error.no_change",
	"aether_atelier_invalid_outfit_dye": "ui.atelier.error.dye",
	"aether_atelier_no_equipped_chroma": "ui.atelier.error.dye",
	"donator_store_gender_mismatch": "ui.store.error.incompatible",
	"donator_store_item_already_owned": "backend.error.item_already_owned",
	"donator_store_item_not_sold": "backend.error.item_unavailable",
	"invalid_donator_store_item": "backend.error.item_unavailable",
	"invalid_donator_store_price": "backend.error.request_invalid",
	"invalid_donator_store_chroma_colors": "backend.error.request_invalid",
	"appearance_gender_mismatch": "ui.store.error.incompatible",
	"appearance_item_not_found": "backend.error.item_unavailable",
	"appearance_not_owned": "backend.error.item_not_owned",
	"appearance_not_available": "backend.error.item_unavailable",
	"appearance_slot_full": "backend.error.appearance_slot_full",
	"appearance_item_overlap_active": "backend.error.appearance_overlap",
	"appearance_item_not_active": "backend.error.item_unavailable",
	"invalid_appearance_item": "backend.error.item_unavailable",
	"invalid_appearance_color": "backend.error.request_invalid",
	"mail_cooldown_active": "backend.error.rate_limited",
	"mail_attachment_voided": "backend.error.mail_attachment_unavailable",
	"fishing_rod_required": "backend.error.fishing_rod_required",
	"fishing_rod_not_owned": "backend.error.fishing_rod_not_owned",
	"invalid_fishing_rod": "backend.error.fishing_rod_invalid",
	"invalid_fishing_encounter_type": "backend.error.fishing_unavailable",
	"encounter_type_not_found": "backend.error.fishing_nothing_biting",
	"fishing_authentication_required": "backend.error.auth_required",
	"fishing_rod_validation_unavailable": "backend.error.fishing_unavailable",
	"fishing_level_required": "backend.error.fishing_level_required",
	"fishing_badges_required": "backend.error.fishing_badges_required",
	"no_usable_pokemon": "backend.error.no_usable_pokemon",
	"npc_reward_not_found": "backend.error.reward_unavailable",
	"field_move_charm_not_owned": "backend.error.item_not_owned",
	"field_move_not_known": "backend.error.field_move_unavailable",
	"field_move_pokemon_not_in_party": "backend.error.field_move_unavailable",
	"invalid_field_move_binding": "backend.error.field_move_unavailable",
	"invalid_field_move_source": "backend.error.field_move_unavailable",
	"gameplay_reset_blocked": "backend.error.action_blocked",
	"gift_code_invalid": "ui.gift_code.error.invalid",
	"gift_code_inactive": "ui.gift_code.error.inactive",
	"gift_code_expired": "ui.gift_code.error.expired",
	"gift_code_exhausted": "ui.gift_code.error.exhausted",
	"gift_code_already_redeemed": "ui.gift_code.error.already_redeemed",
	"gift_code_pokemon_storage_full": "ui.gift_code.error.storage_full",
	"gift_code_wallet_limit": "ui.gift_code.error.wallet_limit",
	"gift_code_inventory_limit": "ui.gift_code.error.inventory_limit",
	"gift_code_reward_unavailable": "ui.gift_code.error.unavailable",
	"gift_code_rate_limited": "backend.error.rate_limited",
	"request_timeout": "backend.error.timeout",
	"service_unavailable": "backend.error.unavailable",
}


static func error_code(response: Dictionary) -> String:
	for source: Dictionary in _response_dictionaries(response):
		for field: String in ["errorCode", "error_code", "code"]:
			var value: Variant = source.get(field, "")
			if value is String and not str(value).strip_edges().is_empty():
				return _normalize_code(str(value))
	return ""


static func message(
	response: Dictionary,
	fallback_key: String = DEFAULT_FALLBACK_KEY,
	values: Dictionary = {}
) -> String:
	var code := error_code(response)
	var key := str(CODE_TO_KEY.get(code, "")).strip_edges()
	var format_values := _format_values(response)
	format_values.merge(values, true)
	if not key.is_empty() and _has_key(key):
		return _text(key, format_values)
	var safe_fallback := fallback_key if _has_key(fallback_key) else DEFAULT_FALLBACK_KEY
	return _text(safe_fallback, format_values)


static func decorate(
	response: Dictionary,
	fallback_key: String = DEFAULT_FALLBACK_KEY,
	values: Dictionary = {}
) -> Dictionary:
	var decorated := response.duplicate(true)
	var code := error_code(response)
	var diagnostic := diagnostic_message(response)
	if not code.is_empty():
		decorated["errorCode"] = code
	if not diagnostic.is_empty():
		decorated["diagnosticError"] = diagnostic
	decorated["error"] = message(response, fallback_key, values)
	return decorated


static func diagnostic_message(response: Dictionary) -> String:
	for source: Dictionary in _response_dictionaries(response):
		for field: String in ["message", "error", "detail"]:
			var value: Variant = source.get(field, "")
			if value is String and not str(value).strip_edges().is_empty():
				return str(value).strip_edges()
	return ""


static func transport_message(request_result: int) -> String:
	match request_result:
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CONNECTION_ERROR:
			return _text("backend.error.connection")
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return _text("backend.error.secure_connection")
		HTTPRequest.RESULT_TIMEOUT:
			return _text("backend.error.timeout")
		_:
			return _text(DEFAULT_FALLBACK_KEY)


static func mapped_translation_keys() -> Array:
	var keys := CODE_TO_KEY.values()
	keys.sort()
	return keys


static func _response_dictionaries(response: Dictionary) -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	var body := _dictionary(response.get("body", {}))
	var body_detail := _dictionary(body.get("detail", {}))
	var detail := _dictionary(response.get("detail", {}))
	for source: Dictionary in [body_detail, detail, body, response]:
		if not source.is_empty():
			sources.append(source)
	return sources


static func _format_values(response: Dictionary) -> Dictionary:
	var values: Dictionary = {}
	for source: Dictionary in _response_dictionaries(response):
		values.merge(source, false)
	if not values.has("count"):
		values["count"] = int(values.get(
			"requiredBadges",
			values.get("required_badges", values.get("requiredCount", 0))
		))
	if not values.has("amount"):
		values["amount"] = int(values.get(
			"missingAmount",
			values.get("requiredAmount", values.get("amountRequired", 0))
		))
	if not values.has("level"):
		values["level"] = int(values.get(
			"requiredFishingLevel",
			values.get("required_level", 1)
		))
	return values


static func _normalize_code(value: String) -> String:
	return value.strip_edges().to_lower().replace("-", "_").replace(" ", "_")


static func _text(key: String, values: Dictionary = {}) -> String:
	var manager := _localization_manager()
	if manager != null and bool(manager.call("has_key", key, "en")):
		return str(manager.call("text", key, values))
	var locale := str(manager.get("current_locale")) if manager != null else "en"
	var localized := _catalog_value(locale, key)
	if localized.is_empty():
		localized = _catalog_value("en", key)
	return (localized if not localized.is_empty() else key).format(values)


static func _has_key(key: String) -> bool:
	var manager := _localization_manager()
	if manager != null and bool(manager.call("has_key", key, "en")):
		return true
	return not _catalog_value("en", key).is_empty()


static func _localization_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("LocalizationManager") if tree != null else null


static func _catalog_value(locale: String, key: String) -> String:
	var path := str(CATALOG_PATHS.get(locale, CATALOG_PATHS["en"]))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return str((parsed as Dictionary).get(key, ""))
	return ""


static func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}
