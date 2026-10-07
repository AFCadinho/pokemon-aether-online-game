extends "res://docs/forum-guides/all-guides/capture/base.gd"

func _run() -> void:
	await setup()
	var guild := load("res://scenes/interface/guild_popup.tscn").instantiate() as Control
	(overlay.get("root_control") as Control).add_child(guild)
	guild.call("show_debug_member_preview")
	guild.show()
	await settle()
	center(guild)
	guild.set("active_guild_section","bank")
	guild.call("_render_guild_home")
	await shot(96,"01-bank-categories",guild,"Example Guild Bank: choose Funds, Pokémon, Items or Resources. Access depends on your guild rank and assigned rights.","## Opening the Guild Bank")
	guild.set("active_guild_bank_category","rights")
	guild.call("_render_guild_home")
	await shot(96,"02-bank-rank-rights",guild,"Example leader view: review bank permissions for each rank before allowing withdrawals or loans.","## Ranks and permissions")
	guild.set("active_guild_section","aether_clash")
	guild.call("_render_guild_home")
	await shot(70,"01-duel-lobby",guild,"Example Aether Clash lobby: check the opposing guild and remaining entry time before joining a duel.","## Joining a duel")
	guild.call("_confirm_aether_clash_challenge",{"id":3,"name":"Midnight League"})
	var challenge := guild.find_child("GuildAetherClashChallengeDialog",true,false) as Control
	await shot(70,"02-challenge-settings",challenge.get("panel"),"Example challenge: choose the format, optional stake and spectator access before sending it.","## Challenging another guild")
	challenge.queue_free()
	await process_frame
	clear()
	var bots := load("res://scripts/ui/aether_clash_bot_challenge_menu.gd").new() as CanvasLayer
	bots.custom_viewport = view
	view.add_child(bots)
	bots.call("build",{"available":true,"canChallenge":true,"maxBotCount":20,"aiPolicies":["ai4","intermediate","ai5","mix_v1"],"rewardClaimedToday":false,"rewardResetAvailable":false})
	await shot(97,"01-training-setup",bots.get("dialog").get("panel"),"Example guild practice setup: choose the bot count, battle format, AI policy and spectator access.","## Starting training")
	(bots.get("difficulty") as OptionButton).select(2)
	bots.call("_update_reward_choice")
	(bots.get("reward_attempt") as CheckBox).button_pressed = true
	await shot(97,"02-reward-attempt",bots.get("dialog").get("panel"),"Example: reward attempts use AI5 and up to 20 bots. Tick the reward option only when you intend to use that day's attempt.","## Daily reward attempts")
	finish("guilds")
