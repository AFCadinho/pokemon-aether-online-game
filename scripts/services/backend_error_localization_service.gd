extends Node

class_name BackendErrorLocalizationService

const DEFAULT_FALLBACK_KEY := "backend.error.generic"
const CATALOG_PATHS: Dictionary = {
	"en": "res://localization/en.json",
	"nl": "res://localization/nl.json",
	"pt_BR": "res://localization/pt_BR.json",
	"zh_CN": "res://localization/zh_CN.json",
}

const CODE_TO_KEY: Dictionary = {
	"unauthorized": "backend.error.auth_required",
	"not_authenticated": "backend.error.auth_required",
	"authentication_required": "backend.error.auth_required",
	"email_not_verified": "ui.login.error.email_not_verified",
	"missing_bearer_token": "backend.error.auth_required",
	"invalid_bearer_token": "backend.error.auth_required",
	"current_password_incorrect": "backend.error.current_password_incorrect",
	"privacy_request_rate_limited": "backend.error.rate_limited",
	"privacy_export_too_large": "ui.settings.privacy.error.too_large",
	"client_update_required": "backend.error.client_update_required",
	"action_forbidden": "backend.error.action_blocked",
	"resource_not_found": "backend.error.unavailable",
	"request_failed": "backend.error.generic",
	"service_error": "backend.error.generic",
	"not_enough_money": "backend.error.not_enough_money",
	"not_enough_bank_money": "backend.error.not_enough_bank_money",
	"bank_balance_overflow": "backend.error.bank_balance_overflow",
	"money_balance_overflow": "backend.error.money_balance_overflow",
	"bank_interaction_required": "backend.error.bank_interaction_required",
	"not_enough_aetherite": "backend.error.not_enough_aetherite",
	"not_enough_battle_points": "backend.error.not_enough_battle_points",
	"market_not_active": "backend.error.market_not_active",
	"market_interaction_required": "backend.error.market_interaction_required",
	"market_interaction_misconfigured": "backend.error.market_unavailable",
	"global_heal_cooldown_active": "backend.error.global_heal_cooldown",
	"global_heal_broadcast_failed": "backend.error.global_heal_broadcast",
	"global_heal_not_found": "backend.error.global_heal_unavailable",
	"global_heal_expired": "backend.error.global_heal_expired",
	"global_heal_player_busy": "backend.error.global_heal_busy",
	"market_badges_required": "backend.error.market_badges_required",
	"market_item_already_owned": "backend.error.item_already_owned",
	"market_purchase_request_conflict": "backend.error.request_conflict",
	"not_enough_gems": "backend.error.not_enough_gems",
	"transit_attunement_location_invalid": "backend.error.transit_wrong_location",
	"transit_attunement_distance_invalid": "backend.error.transit_too_far",
	"item_not_found": "backend.error.item_not_found",
	"item_not_owned": "backend.error.item_not_owned",
	"move_mentor_resource_required": "backend.error.move_mentor_resource_required",
	"item_not_usable": "backend.error.item_not_usable",
	"item_no_effect": "backend.error.item_no_effect",
	"item_unsupported": "backend.error.item_unsupported",
	"item_not_tradable": "ui.trade.error.item_not_tradable",
	"item_reserved_for_trade": "ui.trade.error.item_reserved",
	"already_in_guild": "ui.guild.error.already_member",
	"guild_badges_required": "ui.guild.error.badges_required",
	"guild_name_unavailable": "backend.error.guild_name_unavailable",
	"guild_full": "backend.error.guild_full",
	"guild_direct_join_unavailable": "backend.error.guild_join_unavailable",
	"guild_applications_closed": "backend.error.guild_applications_closed",
	"guild_application_conflict": "backend.error.request_conflict",
	"guild_application_not_found": "backend.error.guild_application_unavailable",
	"guild_application_resolved": "backend.error.guild_application_unavailable",
	"guild_application_invalid": "backend.error.guild_application_unavailable",
	"guild_application_forbidden": "backend.error.guild_application_forbidden",
	"guild_application_cooldown": "backend.error.guild_application_cooldown",
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
	"guild_lobby_transit_attunement_required": "ui.guild.lobby.error.attunement_required",
	"guild_not_found": "backend.error.guild_not_found",
	"guild_leader_required": "backend.error.guild_leader_required",
	"guild_leader_cannot_leave": "backend.error.guild_leader_cannot_leave",
	"guild_leave_borrowed_pokemon": "backend.error.guild_leave_borrowed_pokemon",
	"guild_leave_owned_pokemon": "backend.error.guild_leave_owned_pokemon",
	"guild_kick_forbidden": "backend.error.guild_kick_forbidden",
	"guild_kick_self": "backend.error.guild_kick_self",
	"guild_kick_hierarchy": "backend.error.guild_kick_hierarchy",
	"guild_kick_borrowed_assets": "backend.error.guild_kick_borrowed_assets",
	"guild_emblem_template_not_found": "backend.error.guild_emblem_unavailable",
	"guild_emblem_template_already_unlocked": "backend.error.guild_emblem_unlocked",
	"guild_bank_permission_required": "backend.error.guild_bank_permission",
	"guild_permissions_forbidden": "ui.guild.permissions.error",
	"guild_leader_permissions_locked": "ui.guild.permissions.error",
	"guild_permission_grant_forbidden": "ui.guild.permissions.error",
	"guild_bank_money_unavailable": "backend.error.guild_bank_money",
	"guild_bank_wallet_limit": "backend.error.guild_bank_wallet_limit",
	"guild_bank_item_storage_full": "backend.error.guild_bank_item_full",
	"guild_bank_item_unavailable": "backend.error.guild_bank_item_unavailable",
	"guild_bank_item_not_lendable": "backend.error.guild_bank_item_not_lendable",
	"guild_bank_pokemon_storage_full": "backend.error.guild_bank_pokemon_full",
	"guild_bank_pokemon_unavailable": "backend.error.guild_bank_pokemon_unavailable",
	"guild_bank_pokemon_not_shareable": "backend.error.guild_bank_pokemon_not_shareable",
	"guild_bank_pokemon_holding_item": "backend.error.guild_bank_pokemon_holding_item",
	"guild_bank_party_pokemon_required": "backend.error.guild_bank_party_required",
	"guild_bank_pokemon_location_changed": "backend.error.guild_bank_pokemon_moved",
	"pokemon_stored_in_guild_bank": "backend.error.guild_bank_pokemon_stored",
	"guild_bank_pokemon_borrowed": "backend.error.guild_bank_pokemon_borrowed",
	"lending_unavailable": "ui.lending.error.disabled",
	"guild_request_id_conflict": "backend.error.request_conflict",
	"guild_creation_conflict": "backend.error.request_conflict",
	"guild_creation_incomplete": "ui.guild.error.create",
	"aether_clash_membership_required": "backend.error.guild_membership_not_found",
	"aether_clash_permission_required": "backend.error.aether_clash_permission",
	"aether_clash_action_forbidden": "backend.error.aether_clash_permission",
	"aether_clash_guild_not_found": "backend.error.aether_clash_unavailable",
	"aether_clash_guild_unavailable": "backend.error.aether_clash_unavailable",
	"aether_clash_target_guild_required": "backend.error.aether_clash_target_guild",
	"aether_clash_target_rank_required": "backend.error.aether_clash_target_rank",
	"aether_clash_challenge_not_found": "backend.error.aether_clash_unavailable",
	"aether_clash_self_challenge": "backend.error.aether_clash_self",
	"aether_clash_challenge_pending": "backend.error.aether_clash_pending",
	"aether_clash_guild_busy": "backend.error.aether_clash_busy",
	"aether_clash_challenge_unavailable": "backend.error.aether_clash_challenge_unavailable",
	"aether_clash_challenge_expired": "backend.error.aether_clash_challenge_unavailable",
	"aether_clash_tier_unsupported": "backend.error.aether_clash_tier_unsupported",
	"aether_clash_stake_funds_required": "backend.error.aether_clash_stake_funds_required",
	"aether_clash_intake_paused": "backend.error.aether_clash_intake_paused",
	"aether_clash_stake_limit": "backend.error.aether_clash_stake_limit",
	"aether_clash_pending_limit": "backend.error.aether_clash_pending_limit",
	"aether_clash_challenge_rate_limited": "backend.error.aether_clash_challenge_rate_limited",
	"aether_clash_participant_limit": "backend.error.aether_clash_participant_limit",
	"aether_clash_spectator_limit": "backend.error.aether_clash_spectator_limit",
	"aether_clash_team_invalid": "backend.error.aether_clash_team_invalid",
	"aether_clash_team_lock_invalid": "backend.error.aether_clash_team_lock_invalid",
	"aether_clash_team_lock_changed": "backend.error.aether_clash_team_lock_invalid",
	"aether_clash_entry_closed": "backend.error.aether_clash_entry_closed",
	"aether_clash_spectating_forbidden": "backend.error.aether_clash_spectating_forbidden",
	"aether_clash_portal_required": "backend.error.aether_clash_portal_required",
	"aether_clash_teleport_pending": "backend.error.aether_clash_teleport_pending",
	"aether_clash_activity_blocked": "backend.error.aether_clash_activity_blocked",
	"aether_clash_exchange_blocked": "backend.error.aether_clash_exchange_blocked",
	"loan_aether_clash_unavailable": "backend.error.aether_clash_exchange_blocked",
	"aether_clash_presence_required": "backend.error.aether_clash_presence_required",
	"aether_clash_player_in_battle": "backend.error.aether_clash_player_in_battle",
	"aether_clash_contact_sync_pending": "backend.error.aether_clash_contact_sync_pending",
	"aether_clash_contact_sync_unavailable": "backend.error.aether_clash_contact_sync_pending",
	"aether_clash_contact_out_of_range": "backend.error.aether_clash_contact_out_of_range",
	"pokemon_reserved_for_trade": "ui.trade.error.pokemon_reserved",
	"pokemon_holding_item": "ui.trade.error.pokemon_holding_item",
	"pokemon_not_tradable": "ui.trade.error.pokemon_not_tradable",
	"pokemon_not_owned_or_held": "ui.trade.error.pokemon_not_owned",
	"starter_pokemon_protected": "ui.storage.release.starter_protected",
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
	"trade_pokemon_level_cap_exceeded": "backend.error.trade_pokemon_level_cap_exceeded",
	"exchange_asset_type_invalid": "backend.error.exchange_asset_type_invalid",
	"exchange_request_conflict": "backend.error.exchange_request_conflict",
	"exchange_listing_limit": "backend.error.exchange_listing_limit",
	"exchange_wishlist_limit": "backend.error.exchange_wishlist_limit",
	"exchange_price_too_high": "backend.error.exchange_price_too_high",
	"exchange_listing_not_found": "backend.error.exchange_listing_not_found",
	"exchange_listing_unavailable": "backend.error.exchange_listing_unavailable",
	"exchange_wishlist_not_found": "backend.error.exchange_wishlist_not_found",
	"exchange_wishlist_unavailable": "backend.error.exchange_wishlist_unavailable",
	"exchange_own_wishlist": "backend.error.exchange_own_wishlist",
	"exchange_wishlist_requester_unavailable": "backend.error.exchange_wishlist_requester_unavailable",
	"exchange_wishlist_refund_wallet_full": "backend.error.exchange_wishlist_refund_wallet_full",
	"exchange_own_listing": "backend.error.exchange_own_listing",
	"exchange_seller_unavailable": "backend.error.exchange_seller_unavailable",
	"exchange_seller_wallet_full": "backend.error.exchange_seller_wallet_full",
	"exchange_pokemon_not_found": "backend.error.exchange_pokemon_not_found",
	"exchange_pokemon_must_be_in_party": "backend.error.exchange_pokemon_must_be_in_party",
	"exchange_party_slot_occupied": "backend.error.exchange_party_slot_occupied",
	"exchange_asset_changed": "backend.error.exchange_asset_changed",
	"exchange_pokemon_storage_full": "backend.error.exchange_pokemon_storage_full",
	"pokemon_listed_on_exchange": "backend.error.pokemon_listed_on_exchange",
	"trade_review_mismatch": "ui.trade.error.review_changed",
	"trade_review_not_locked": "ui.trade.error.review_not_locked",
	"trade_settlement_invalidated": "ui.trade.error.settlement_invalidated",
	"trade_settlement_retryable": "ui.trade.error.settlement_retry",
	"trade_confirmation_stale": "ui.trade.error.stale",
	"trade_rate_limited": "backend.error.rate_limited",
	"trade_rollout_unavailable": "ui.trade.error.service_unavailable",
	"loan_same_map_required": "ui.lending.error.same_map",
	"loan_presence_unavailable": "ui.lending.error.presence_unavailable",
	"loan_lender_party_required": "ui.lending.error.party_required",
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
	"wild_encounter_not_found": "backend.error.wild_encounter_not_found",
	"fishing_authentication_required": "backend.error.auth_required",
	"fishing_rod_validation_unavailable": "backend.error.fishing_unavailable",
	"fishing_level_required": "backend.error.fishing_level_required",
	"fishing_badges_required": "backend.error.fishing_badges_required",
	"no_usable_pokemon": "backend.error.no_usable_pokemon",
	"pokemon_level_cap_reached": "backend.error.pokemon_level_cap_reached",
	"pokemon_level_cap_party_ineligible": "backend.error.pokemon_level_cap_party_ineligible",
	"pokemon_level_cap_authentication_required": "backend.error.auth_required",
	"pokemon_level_cap_validation_unavailable": "backend.error.unavailable",
	"pokemon_party_changed_refresh_required": "backend.error.party_changed_refresh",
	"active_wild_battle_exists": "backend.error.active_wild_battle",
	"active_trainer_battle_exists": "backend.error.active_trainer_battle",
	"pokemon_held_item_locked": "backend.error.pokemon_held_item_locked",
	"room_timer_authority_disabled": "ui.pvp.room.timer_unavailable",
	"room_timer_authority_unavailable": "ui.pvp.room.timer_unavailable",
	"room_timer_client_contract_required": "ui.pvp.room.timer_unavailable",
	"room_timer_participant_not_eligible": "ui.pvp.room.timer_unavailable",
	"unsupported_timer_tier": "ui.pvp.room.timer_unavailable",
	"unsupported_room_timer_tier": "ui.pvp.room.timer_unavailable",
	"pokemon_nickname_insufficient_funds": "ui.pokemon_summary.nickname.insufficient_funds",
	"pokemon_nickname_locked_for_pvp": "ui.pokemon_summary.nickname.blocked",
	"pokemon_nickname_not_allowed": "ui.pokemon_summary.nickname.not_allowed",
	"npc_reward_not_found": "backend.error.reward_unavailable",
	"field_move_charm_not_owned": "backend.error.item_not_owned",
	"field_move_hm_required": "backend.error.field_move_hm_required",
	"field_move_badge_required": "backend.error.field_move_badge_required",
	"field_move_not_known": "backend.error.field_move_unavailable",
	"field_move_pokemon_not_in_party": "backend.error.field_move_unavailable",
	"invalid_field_move_binding": "backend.error.field_move_unavailable",
	"invalid_field_move_source": "backend.error.field_move_unavailable",
	"rock_smash_locked": "backend.error.rock_smash_locked",
	"rock_smash_rock_unavailable": "backend.error.rock_smash_unavailable",
	"rock_smash_already_smashed": "backend.error.rock_smash_already_smashed",
	"rock_smash_level_required": "backend.error.rock_smash_level_required",
	"rock_smash_context_mismatch": "backend.error.rock_smash_unavailable",
	"rock_smash_too_far": "backend.error.rock_smash_too_far",
	"rock_smash_request_required": "backend.error.request_invalid",
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
	"circuit_breaker_open": "backend.error.unavailable",
	"test_form_not_allowed": "backend.error.mega_test_form_not_allowed",
	"mega_direct_form_not_allowed": "backend.error.mega_direct_form_not_allowed",
	"mega_catalog_disabled": "backend.error.mega_catalog_disabled",
	"mega_format_disabled": "backend.error.mega_format_disabled",
	"mega_format_not_allowed": "backend.error.mega_format_not_allowed",
	"mega_calculator_pending": "backend.error.mega_calculator_pending",
	"mega_ai_pending": "backend.error.mega_ai_pending",
	"mega_readiness_pending": "backend.error.mega_readiness_pending",
	"mega_catalog_unavailable": "backend.error.mega_compatibility_unavailable",
	"mega_catalog_revision_mismatch": "backend.error.mega_compatibility_unavailable",
	"mega_capability_data_missing": "backend.error.mega_compatibility_unavailable",
	"mega_capability_conflict": "backend.error.mega_compatibility_unavailable",
	"mega_engine_manifest_stale": "backend.error.mega_compatibility_unavailable",
	"mega_calculator_manifest_stale": "backend.error.mega_compatibility_unavailable",
	"mega_context_unknown": "backend.error.mega_compatibility_unavailable",
}


static func error_code(response: Dictionary) -> String:
	for source: Dictionary in _response_dictionaries(response):
		for field: String in ["errorCode", "error_code", "code"]:
			var value: Variant = source.get(field, "")
			if value is String and not str(value).strip_edges().is_empty():
				return _normalize_code(str(value))
	return ""


static func support_id(response: Dictionary) -> String:
	for source: Dictionary in _response_dictionaries(response):
		for field: String in ["supportId", "support_id", "referenceId", "reference_id"]:
			var value := str(source.get(field, "")).strip_edges().to_upper()
			if _valid_support_id(value):
				return value
	return ""


static func message(
	response: Dictionary,
	fallback_key: String = DEFAULT_FALLBACK_KEY,
	values: Dictionary = {}
) -> String:
	var code := error_code(response)
	var key := str(CODE_TO_KEY.get(code, "")).strip_edges()
	if code == "aether_clash_team_invalid":
		var rule_code := _aether_clash_team_rule_code(response)
		var rule_key := "backend.error.aether_clash_team_invalid.%s" % rule_code
		if not rule_code.is_empty() and _has_key(rule_key):
			key = rule_key
		elif CODE_TO_KEY.has(rule_code):
			key = str(CODE_TO_KEY.get(rule_code, "")).strip_edges()
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
	var reference := support_id(response)
	if not code.is_empty():
		decorated["errorCode"] = code
	if not reference.is_empty():
		decorated["supportId"] = reference
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


static func _aether_clash_team_rule_code(response: Dictionary) -> String:
	for source: Dictionary in _response_dictionaries(response):
		for field: String in ["ruleCode", "rule_code"]:
			var value := str(source.get(field, "")).strip_edges()
			if not value.is_empty():
				return _normalize_code(value)
	return ""


static func _valid_support_id(value: String) -> bool:
	if value.length() != 15 or not value.begins_with("PA-"):
		return false
	for character: String in value.substr(3):
		if not character in "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567":
			return false
	return true


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
	for integer_level_key: String in [
		"level",
		"requiredLevel",
		"requiredFishingLevel",
		"levelCap",
		"pokemonLevel",
		"tradeLevelCap",
	]:
		if values.has(integer_level_key):
			values[integer_level_key] = _whole_number(values.get(integer_level_key, 0))
	return values


static func _whole_number(value: Variant) -> int:
	if value is int or value is float:
		return roundi(float(value))
	var text := str(value).strip_edges()
	return roundi(text.to_float()) if text.is_valid_float() else 0


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
