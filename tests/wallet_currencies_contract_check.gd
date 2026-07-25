extends SceneTree

var failed := false


func _init() -> void:
	var player_data := FileAccess.get_file_as_string("res://scripts/data/player_data.gd")
	var wallet_service := FileAccess.get_file_as_string("res://scripts/services/player_wallet_service.gd")
	var loading_screen := FileAccess.get_file_as_string("res://scripts/ui/loading_screen.gd")
	var overlay := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")

	_check(
		player_data.contains("var aetherite := 0")
		and player_data.contains("var battle_points := 0"),
		"local player state declares Aetherite and Battle Points"
	)
	_check(
		player_data.contains("aetherite = 0")
		and player_data.contains("battle_points = 0"),
		"gameplay reset clears future gameplay currencies"
	)
	_check(
		wallet_service.contains('wallet.get("aetherite", PlayerSave.aetherite)')
		and wallet_service.contains('wallet.get("battle_points", PlayerSave.battle_points)'),
		"wallet refresh applies authoritative Aetherite and Battle Point balances"
	)
	_check(
		wallet_service.contains('DEV_ADD_AETHERITE_ENDPOINT := "/game/dev/wallet/aetherite"')
		and wallet_service.contains('DEV_ADD_BATTLE_POINTS_ENDPOINT := "/game/dev/wallet/battle-points"')
		and wallet_service.contains("func dev_add_aetherite(amount: int)")
		and wallet_service.contains("func dev_add_battle_points(amount: int)"),
		"developer wallet service can grant both new currencies"
	)
	_check(
		loading_screen.contains('wallet.get("aetherite", PlayerSave.aetherite)')
		and loading_screen.contains('wallet.get("battle_points", PlayerSave.battle_points)'),
		"profile loading restores Aetherite and Battle Point balances"
	)
	_check(
		overlay.contains('"Aetherite"')
		and overlay.contains('"Battle Points"')
		and overlay.contains('cards.columns = 2'),
		"Trainer Card renders all four balances in a 2x2 Wallet grid"
	)
	_check(
		overlay.contains('preload("res://assets/ui/aetherite.svg")')
		and overlay.contains('preload("res://assets/ui/battle_points.svg")'),
		"new wallet currencies use dedicated icons"
	)
	_check(
		overlay.contains('dev_aetherite_confirm_button.text = "Add Aetherite"')
		and overlay.contains('dev_battle_points_confirm_button.text = "Add Battle Points"')
		and overlay.contains("PlayerWalletService.dev_add_aetherite(amount)")
		and overlay.contains("PlayerWalletService.dev_add_battle_points(amount)")
		and overlay.contains("currency_buttons.columns = 2"),
		"Developer Tools exposes a 2x2 grant grid for every wallet currency"
	)

	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
