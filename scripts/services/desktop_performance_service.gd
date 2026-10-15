extends "res://scripts/services/android_performance_service.gd"
## Shared bounded transport and frame accounting, without Android JNI sampling.

func _supported_platform() -> bool:
	return OS.has_feature("pc") and not OS.has_feature("android") and not OS.has_feature("web")

func _sharing_enabled() -> bool:
	return SettingsManager.share_desktop_performance

func _quality_preset() -> String:
	return SettingsManager.desktop_battle_quality_preset

func _target_fps() -> int:
	return SettingsManager.desktop_fps_limit

func _platform_metadata() -> Dictionary:
	# Never use a computer/host name or hardware serial as a device model.
	return {"platform": "desktop", "deviceModel": "desktop", "osName": OS.get_name(),
		"cpu": OS.get_processor_name().left(120) if not OS.get_processor_name().is_empty() else "unknown",
		"vsyncMode": DisplayServer.window_get_vsync_mode()}

func _native_sample() -> Dictionary:
	# Engine GPU allocation estimates are already sampled by the shared service.
	# No portable release process-RAM or temperature probe is available here.
	return {}
