extends RefCounted
## Client-shipped skeletal correction for these exact reviewed model revisions.
## Meshes/materials and downloaded bundle bytes remain intact. Future model
## revisions must be measured separately and never inherit this correction.
const DATA = preload("res://resources/battle/model_animations/gliscor_flight.json")
const LIBRARY_PATH := "res://resources/battle/model_animations/gliscor_flight.res"

static func matches(identity: String, digest: String) -> bool:
	return DATA.data.models.has(identity) and DATA.data.models[identity] == digest

static func profile_for(identity: String, digest: String, original: Dictionary) -> Dictionary:
	if not matches(identity, digest):
		return original
	var result: Dictionary = original.duplicate(true)
	for field in DATA.data.profile:
		result[field] = DATA.data.profile[field].duplicate(true)
	return result

static func apply(player: AnimationPlayer, identity: String, digest: String) -> bool:
	if player == null or not matches(identity, digest):
		return false
	var library: AnimationLibrary = load(LIBRARY_PATH)
	# Each actor owns animation clocks/loop settings; never mutate the source
	# scene's shared library or another normal/shiny preview.
	player.stop()
	if player.has_animation_library(""):
		player.remove_animation_library("")
	player.add_animation_library("", library.duplicate(true))
	# Attack/faint clips already contain their entry/exit motion. Blending those
	# again can bend the tail below the authored clearance envelope.
	player.playback_default_blend_time = 0.0
	player.set_blend_time("idle", "sleep", 0.2)
	player.set_blend_time("sleep", "idle", 0.2)
	return true
