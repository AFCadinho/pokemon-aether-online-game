extends SceneTree

var failed := false


func _init() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	var service := FileAccess.get_file_as_string("res://scripts/services/thieving_service.gd")
	var npc := FileAccess.get_file_as_string("res://scripts/world/npcs/base_npc.gd")
	var heal := FileAccess.get_file_as_string("res://scripts/world/npcs/heal_npc.gd")
	var market := FileAccess.get_file_as_string("res://scripts/world/npcs/market_attendant_npc.gd")
	var party_heal := FileAccess.get_file_as_string("res://scripts/services/party_heal_service.gd")
	var status_hud := FileAccess.get_file_as_string("res://scripts/ui/thieving_status_hud.gd")
	var mentor := FileAccess.get_file_as_string("res://scripts/world/kanto/towns/thieving_mentor_rook.gd")
	var rook_help_locales: Array[String] = ["en", "nl", "pt_BR"]
	var viridian := FileAccess.get_file_as_string(
		"res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn"
	)
	var pallet := FileAccess.get_file_as_string(
		"res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn"
	)
	var players_house := FileAccess.get_file_as_string(
		"res://scenes/overworld/kanto/towns/pallet_town/players_house.tscn"
	)

	_check("ThievingService=" in project and "pickpocket={" in project, "Thieving service and T input are registered")
	_check("/game/thieving/pickpocket" in service, "Pickpocket uses the server endpoint")
	_check("ui.thieving.locked" in npc and "is_unlocked" in service, "Pickpocket remains locked until Rook's lesson")
	_check("learn_to_pickpocket" in mentor and "pickpocket_hotkey" in mentor, "Rook teaches the configurable pickpocket input")
	_check("return_to_rook" in mentor and "claim_npc_item_reward" in mentor, "Rook completes the lesson and grants rewards only after the return step")
	for locale: String in rook_help_locales:
		var locale_data: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://localization/%s.json" % locale)
		)
		_check(locale_data is Dictionary, "Rook help localization parses for %s" % locale)
		if not locale_data is Dictionary:
			continue
		var help_text := " ".join([
			str(locale_data.get("mentor.rocket_rook.help.basics.2", "")),
			str(locale_data.get("mentor.rocket_rook.help.risk.2", "")),
			str(locale_data.get("mentor.rocket_rook.help.progression.1", "")),
			str(locale_data.get("mentor.rocket_rook.help.progression.2", "")),
		])
		_check("Loot" not in help_text, "Rook no longer describes a separate Loot currency in %s" % locale)
		_check(
			"Pokédollars" in help_text and "25%" in help_text and "1%" in help_text,
			"Rook explains direct cash and exact XP and level bonuses in %s" % locale
		)
		_check(
			"₽5" in help_text and "₽25" in help_text,
			"Rook explains the bail range in %s" % locale
		)
	_check("BODY_MOVEMENT_PICKPOCKET" in npc and "create_timer(0.55)" in npc, "NPC interaction plays the one-shot pose")
	_check("ui.thieving.experience" in npc and "experienceAwarded" in npc, "Pickpocket attempts report awarded Thieving XP")
	_check("rewardMoney" in service and "lostMoney" in service, "Thieving rewards and fines use the shared wallet")
	_check("rewardItem" in service and "load_inventory" in service, "Item loot refreshes the player inventory")
	_check("system.thieving_arrest" in FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd"), "Arrests can appear as global system messages")
	_check("_try_start_pickpocket" in npc and "pickpocketProfile" in npc, "Pickpocket targets load their class from NPC metadata on demand")
	_check("_is_player_behind_npc" in npc and "behind_direction" in npc, "Pickpocket attempts require the player to stand behind the target")
	_check("ThievingPromptButton" in npc and "assets/ui/thieving.svg" in npc, "Eligible targets show a clickable Thieving action")
	_check("[T]" not in npc, "NPC nameplates no longer use a hard-coded Thieving key prompt")
	_check("pickpocket_enabled = true" not in viridian, "Viridian targets are data-driven instead of scene overrides")
	_check(
		"kanto_viridian_city_gardener_mabel" in viridian
		and "kanto_viridian_city_ace_trainer_victor" in viridian
		and 'npc_sprite_frames = ExtResource("25_elder_f")' in viridian
		and 'npc_sprite_frames = ExtResource("32_ace_trainer_m")' in viridian,
		"Viridian has outdoor elderly and Ace Trainer targets with class sprites"
	)
	_check("pickpocket_enabled = true" not in pallet, "Pallet Town has no pickpocket targets")
	_check("pickpocket_enabled = true" not in players_house, "Player house has no pickpocket targets")
	_check("public_service = false" in players_house, "Mom remains a private heal service")
	_check("use_public_service(\"pokemon_center\")" in heal, "Public heals check Most Wanted")
	_check("use_public_service(\"market\")" in market, "Markets check Most Wanted")
	_check("\"publicService\": public_service" in party_heal, "Heal authority receives the public-service flag")
	_check("BODY_MOVEMENT_FISH" not in npc, "Pickpocket does not alter fishing behavior")
	_check(
		"panel.visible = jailed" in status_hud
		and "jailed or currency > 0 or wanted > 0" not in status_hud,
		"Contraband and Wanted stay in the Skills interface instead of the overworld HUD"
	)
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
