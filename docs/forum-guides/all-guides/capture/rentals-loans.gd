extends "res://docs/forum-guides/all-guides/capture/base.gd"

func _run() -> void:
	await setup()
	var rental := load("res://scripts/ui/rental_workspace.gd").new() as Window
	rental.set("kind","pokemon")
	view.add_child(rental)
	rental.set("catalog",{"offers":[],"rentals":[],"maxPokemon":6})
	(rental.get("balance") as Label).text = "Aetherite: 1,000"
	(rental.get("pokemon_paste") as TextEdit).text = "Scizor @ Leftovers\nAbility: Technician\nEVs: 252 Atk / 4 SpD / 252 Spe\nAdamant Nature\n- Bullet Punch\n- U-turn\n- Roost\n- Swords Dance"
	rental.call("_update_pokemon_preview")
	rental.call("_refresh_builder_actions")
	rental.popup_centered(Vector2i(940,670))
	await shot_window(86,"01-rental-set-builder",rental,"Example individual rental: paste a Pokémon set, inspect its preview, then request the authoritative quote before renting.","## Renting individual Pokémon")
	rental.hide()
	clear()
	var lending := load("res://scripts/ui/lending_workspace.gd").new() as Window
	view.add_child(lending)
	lending.set("target_username","Example Trainer")
	lending.set("capabilities",{"enabled":true,"durationsSeconds":[3600,10800,21600,43200,86400,172800,259200]})
	var candidates: Array[Dictionary] = [{"pokemonId":101,"name":"Bulbasaur","speciesId":"bulbasaur","level":15,"lendable":true,"heldItemId":"","pokemon":{"species":"bulbasaur","level":15}}]
	lending.set("party_candidates",candidates)
	lending.call("_set_workspace_mode",true)
	(lending.get("target_display_label") as Label).text = "To: Example Trainer"
	lending.call("_populate_durations")
	lending.set("selected_pokemon",{101:true})
	lending.call("_render_assets")
	lending.call("_render_loans")
	(lending.get("status_label") as Label).text = ""
	lending.set_process(false)
	lending.popup_centered(Vector2i(900,640))
	await shot_window(92,"01-compose-player-loan",lending,"Example loan offer: choose a Party Pokémon, duration and optional fee. The recipient must accept before the loan begins.","## Making a loan offer")
	lending.hide()
	clear()
	var replay := load("res://scripts/ui/battle_replay_library.gd").new() as Control
	(overlay.get("root_control") as Control).add_child(replay)
	replay.show()
	var list := replay.get("list") as Control
	list.add_child(replay.call("_card",{"battleId":"example-replay","status":"available","title":"My first sparring victory","favorite":true,"opponentDisplayName":"Scholar","kind":"ai_sparring","result":"win","turns":12,"createdAt":"2026-10-07T12:00:00Z","expiresAt":"2026-11-06T12:00:00Z","difficulty":"ai4"}))
	(replay.get("status") as Label).text = "1 replay"
	(replay.get("usage") as Label).text = root.get_node("LocalizationManager").text("ui.replays.usage",{"favorites":1})
	await shot(94,"01-replay-library",replay.get("shell"),"Example replay library: use Play to watch a recording, the star to keep it as a favorite, or the sharing control to manage a replay code.","## Finding and watching a replay")
	finish("rentals-loans")
