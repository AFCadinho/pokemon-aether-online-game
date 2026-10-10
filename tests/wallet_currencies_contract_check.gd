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
		overlay.contains('"ui.trainer_card.wallet.aetherite"')
		and overlay.contains('"ui.trainer_card.wallet.battle_points"')
		and overlay.contains('cards.columns = 2'),
		"Trainer Card uses a two-column Wallet grid"
	)
	_check(
		overlay.contains('preload("res://assets/ui/aetherite.svg")')
		and overlay.contains('preload("res://assets/ui/battle_points.svg")'),
		"new wallet currencies use dedicated icons"
	)
	_check(
		overlay.contains('"ui.staff.dev.add_aetherite"')
		and overlay.contains('"ui.staff.dev.add_battle_points"')
		and overlay.contains("PlayerWalletService.dev_add_aetherite(amount)")
		and overlay.contains("PlayerWalletService.dev_add_battle_points(amount)")
		and overlay.contains("currency_buttons.columns = 2"),
		"Developer Tools uses a two-column currency grant grid"
	)
	_check(
		wallet_service.contains('DEV_ADD_CASINO_TOKENS_ENDPOINT := "/game/dev/wallet/casino-tokens"')
		and overlay.contains("PlayerWalletService.dev_add_casino_tokens(amount)")
		and loading_screen.contains('wallet.get("casino_tokens", PlayerSave.casino_tokens)'),
		"Casino Tokens use the dedicated grant endpoint and restore on profile loading"
	)
	call_deferred("_run_runtime_checks")


func _run_runtime_checks() -> void:
	var save := root.get_node("PlayerSave")
	var wallet := root.get_node("PlayerWalletService")
	wallet.call("apply_wallet_result", {"success": true, "wallet": {"casino_tokens": 12345}})
	_check(int(save.get("casino_tokens")) == 12345, "wallet response applies authoritative Casino Tokens")
	wallet.call("apply_wallet_result", {"success": true, "wallet": {"money": 5}})
	_check(int(save.get("casino_tokens")) == 12345, "partial older wallet responses preserve Casino Tokens")
	wallet.call("apply_wallet_result", {"success": false, "wallet": {"casino_tokens": 99}})
	_check(int(save.get("casino_tokens")) == 12345, "failed wallet responses cannot change Casino Tokens")
	var overlay := (load("res://scenes/interface/ui_overlay.tscn") as PackedScene).instantiate()
	var tab := overlay.call("_create_trainer_card_wallet_tab") as Control
	var grid := tab.find_child("WalletCurrencyGrid", true, false) as GridContainer
	_check(grid != null and grid.get_child_count() == 5, "Wallet renders all five gameplay currencies")
	var balance := overlay.get("trainer_card_casino_tokens_label") as Label
	_check(balance != null and balance.text == "12,345", "Casino Token card renders the saved balance")
	_check(overlay.call("_normalize_backend_bag_category", "evolution-items", "gold-coin") == "general", "Gold Coin stays an evolution item in the Bag")
	var resolver := load("res://scripts/services/item_icon_resolver.gd")
	var icon := resolver.load_icon("gold-coin") as Texture2D
	_check(icon != null and icon.resource_path.ends_with("GIMMIGHOULCOIN.png"), "Gold Coin resolves its coin icon instead of a placeholder")
	var item_localization := root.get_node("ItemLocalization")
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		_check(bool(item_localization.call("has_translation", "gold-coin", locale)), "Gold Coin has item localization for " + locale)
	save.call("reset_gameplay_progress")
	_check(int(save.get("casino_tokens")) == 0, "gameplay reset clears Casino Tokens")
	save.set("casino_tokens", 99)
	save.call("reset_account_state")
	_check(int(save.get("casino_tokens")) == 0, "logout/account reset clears Casino Tokens")
	tab.free()
	overlay.free()

	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
