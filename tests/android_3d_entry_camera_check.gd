extends "res://tests/early_3d_arena_check.gd"
## Offline Android early reveal and fixed overview, with held response/models.
func _run() -> void:
	ProjectSettings.set_setting("_custom_features", "android,android_3d_experimental")
	# The fixture uses its prepared stadium, not a network forest download.
	root.get_node("Android3DEnvironmentService").verified = true
	root.get_node("PlayerSave").party.assign([Pokemon.new("Dragonite", 100)])
	await super._run()

func _make_host() -> Control:
	var host: Control = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	host.set_script(load("res://tests/fixtures/android_entry_host.gd"))
	return host
