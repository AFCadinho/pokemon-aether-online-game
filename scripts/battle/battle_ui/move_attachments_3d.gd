extends RefCounted
## Anatomical emitters, independent of a move's physical/special damage category.
## Offsets are in the named bone's local coordinates (metres in these reviewed rigs).
const MOVE_PARTS := {
	"tackle": "body", "scratch": "hand", "bite": "mouth",
	"ember": "mouth", "watergun": "mouth", "thundershock": "body",
	"flamethrower": "mouth", "bubble": "mouth", "bubblebeam": "mouth",
}
const PROFILES := {
	"pikachu": {"electric_body": [["spine_02", Vector3.ZERO]]},
	"charmander": {
		"mouth": [["head", Vector3(0.05, 0, 0.195)]],
		"hand": [["right_hand", Vector3(0.033, 0, 0)]],
	},
	"squirtle": {"mouth": [["head", Vector3(0, 0, 0.145)]]},
	"blastoise": {
		"mouth": [["head", Vector3(0.08, 0, 0.275)]],
		"cannons": [["left_feeler_b_02", Vector3(0.261, 0, 0)], ["right_feeler_b_02", Vector3(0.261, 0, 0)]],
	},
}
const MOVE_OVERRIDES := {"blastoise": {"watergun": "cannons", "bubblebeam": "cannons"}, "pikachu": {"thundershock": "electric_body", "thunderbolt": "electric_body"}}
const CACHE_META := &"move_attachment_bindings"

static func part_for(identity: String, move_key: String) -> String:
	# Shiny uses the same rig; alternate/Mega forms require their own profile.
	var species := identity.trim_suffix("@shiny")
	return MOVE_OVERRIDES.get(species, {}).get(move_key, MOVE_PARTS.get(move_key, "body"))

static func sample(actor: Node3D, identity: String, move_key: String, world: Node3D) -> Dictionary:
	var species := identity.trim_suffix("@shiny")
	var part := part_for(identity, move_key)
	var definitions: Array = PROFILES.get(species, {}).get(part, [])
	if definitions.is_empty(): return {}
	var cache: Dictionary = actor.get_meta(CACHE_META, {})
	var cache_key := species + ":" + part
	if not cache.has(cache_key):
		var bindings := []
		for definition: Array in definitions:
			var found := false
			for skeleton: Skeleton3D in actor.find_children("*", "Skeleton3D", true, false):
				var bone := skeleton.find_bone(definition[0])
				if bone < 0: continue
				bindings.append({"skeleton": weakref(skeleton), "bone": bone, "name": definition[0], "offset": definition[1]})
				found = true
				break
			# A partial pair is unsafe: fall back as a whole if this rig differs.
			if not found:
				bindings.clear()
				break
		cache[cache_key] = bindings
		actor.set_meta(CACHE_META, cache)
	var points: Array[Vector3] = []
	var names: Array[String] = []
	for binding: Dictionary in cache[cache_key]:
		var skeleton: Skeleton3D = binding.skeleton.get_ref()
		if not is_instance_valid(skeleton) or not skeleton.is_inside_tree(): return {}
		var point: Vector3 = skeleton.get_bone_global_pose(binding.bone) * binding.offset
		points.append(world.to_local(skeleton.to_global(point)))
		names.append(binding.name)
	if points.is_empty(): return {}
	return {"sources": points, "part": part, "bones": names}
