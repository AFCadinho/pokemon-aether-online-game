extends "res://tests/early_3d_arena_check.gd"
## Offline Android reveal policy, with held downloads and the real host/pool.
func _make_host() -> Control:
	var host: Control = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	host.set_script(load("res://tests/fixtures/android_entry_host.gd"))
	return host
