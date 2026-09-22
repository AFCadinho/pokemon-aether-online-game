extends RefCounted
## Shared camera/spawn geometry; independent of arena assets and game autoloads.
const CAMERA_FOV := 48.0
const ROUTE_22_POND_ORIGIN := Vector3(11, 0, -4.5)

static func battle_origin(id: String) -> Vector3:
	if id == "route_1_water":
		return Vector3(-13.5, 2.54, -29.0)
	return ROUTE_22_POND_ORIGIN if id == "route_22_water" else Vector3.ZERO

static func spawn(index: int) -> Vector3:
	return Vector3(-2.8, 0, 1.5) if index == 0 else Vector3(2.8, 0, -1.5)

static func camera_home(id: String) -> Vector3:
	return (Vector3(2.5, 5.0, 16.0) if id == "stadium" else Vector3(4, 5.5, 12)) + battle_origin(id)

static func camera_target(id: String) -> Vector3:
	return (Vector3(0, 2.8, 0) if id == "stadium" else Vector3(0, 1.3, 0)) + battle_origin(id)
