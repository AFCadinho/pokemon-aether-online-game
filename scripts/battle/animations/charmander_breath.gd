extends RefCounted
## Add the native mouth-breath sequence only to these compatible reviewed rigs.
const DATA = preload("res://resources/battle/model_animations/charmander_breath.json")
const LIBRARY_PATH := "res://resources/battle/model_animations/charmander_breath.res"
const ACTION := "special_attack_2"
static func matches(identity: String, digest: String) -> bool:
	return preload("res://scripts/battle/animations/lossless_model_revisions.gd").matches(identity, digest, DATA.data.models)

static func profile_for(identity: String, digest: String, original: Dictionary) -> Dictionary:
	if not matches(identity, digest): return original
	var result := original.duplicate(true)
	result.action_timing[ACTION] = DATA.data.timing.duplicate(true)
	# These older models use the stable fallback HUD envelope for every clip.
	# Do not introduce a one-clip envelope that would move the HUD mid-attack.
	result.motion.clips[ACTION] = DATA.data.motion.duplicate(true)
	return result

static func apply(player: AnimationPlayer, identity: String, digest: String) -> bool:
	if player == null or not matches(identity, digest) or not player.has_animation_library(""):
		return false
	var addon: AnimationLibrary = load(LIBRARY_PATH)
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	if library.has_animation(ACTION): return true
	if library.add_animation(ACTION, addon.get_animation(ACTION).duplicate(true)) != OK: return false
	player.stop()
	player.remove_animation_library("")
	player.add_animation_library("", library)
	# Entry/exit are authored in the clip; preserve their source poses.
	player.set_blend_time("idle", ACTION, 0.0)
	player.set_blend_time(ACTION, "idle", 0.0)
	return true
