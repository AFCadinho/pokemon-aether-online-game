extends "res://scripts/launcher.gd"
## Network-free launcher UI fixture; downloads still exercise the real queue.
func check_for_updates() -> void: pass
func fetch_news() -> void: pass
func _refresh_server_health() -> void: pass
func _load_launcher_settings() -> void: pass
func _load_local_versions() -> void: pass
func _has_installed_game() -> bool: return true
