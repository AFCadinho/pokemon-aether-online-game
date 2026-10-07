extends "res://scripts/services/settings_manager.gd"
## Exercise unsupported-platform settings with the same persistence methods.
var is_web := false
var is_mobile := false
var experimental_android := false
func _ready() -> void: pass
func supports_3d_presentation() -> bool:
	return supports_battle_visual_choice(is_web, is_mobile, experimental_android)
func is_android_3d_experimental() -> bool:
	return experimental_android and not is_web
