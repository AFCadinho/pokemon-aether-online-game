extends SceneTree
const Platform = preload("res://scripts/battle/battle_ui/model_platform.gd")
func _init() -> void:
	assert(Platform.allows(false, false, false, false, false))
	assert(not Platform.allows(false, true, true, false, true), "Regular Android remains 2D")
	assert(not Platform.allows(false, true, true, true, false), "Release Android cannot enable the debug pilot")
	assert(not Platform.allows(true, true, true, true, true), "Web remains sprite-only")
	assert(not Platform.allows(false, true, false, true, true), "Other mobile platforms remain disabled")
	assert(Platform.allows(false, true, true, true, true))
	print("ANDROID_3D_PLATFORM_OK production_unchanged=true debug_pilot_only=true")
	quit()
