extends RefCounted
## Android 3D stays confined to the separate, explicitly tagged debug pilot.
static func supported() -> bool:
	return allows(OS.has_feature("web"), OS.has_feature("mobile"), OS.has_feature("android"),
		OS.has_feature("android_3d_pilot"), OS.is_debug_build())

static func allows(web: bool, mobile: bool, android: bool, pilot: bool, debug: bool) -> bool:
	return not web and (not mobile or (android and pilot and debug))
