extends RefCounted
## Android needs an explicit experimental build; browser remains sprite-only.
static func supported() -> bool:
	return allows(OS.has_feature("web"), OS.has_feature("mobile"), OS.has_feature("android"),
		OS.has_feature("android_3d_pilot"), OS.is_debug_build(), OS.has_feature("android_3d_experimental"))

static func allows(web: bool, mobile: bool, android: bool, pilot: bool, debug: bool, experimental := false) -> bool:
	return not web and (not mobile or (android and ((pilot and debug) or experimental)))

static func render_dimensions(target: Vector2i, experimental_android: bool) -> Vector2i:
	if not experimental_android:
		return target
	var factor := minf(1.0, minf(960.0 / maxf(2, target.x), 540.0 / maxf(2, target.y)))
	return Vector2i(maxi(2, roundi(target.x * factor)), maxi(2, roundi(target.y * factor)))
