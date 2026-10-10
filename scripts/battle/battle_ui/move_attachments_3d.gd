extends RefCounted
## Anatomical emitters, independent of a move's physical/special damage category.
## Offsets use each named bone's local units; rigs may have different scales.
const CALIBRATED = preload("res://data/battle_move_attachments_3d.json")
const Catalog = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Recipes = preload("res://scripts/battle/battle_ui/move_recipe_3d.gd")
const MOVE_PARTS := {
	"dracometeor": "body",
	"shadowball": "mouth", "sludgebomb": "mouth", "focusblast": "body", "moonblast": "body",
	"iceshard": "body", "poisonsting": "mouth", "swift": "body", "flashcannon": "mouth",
	"magicalleaf": "body", "waterpulse": "mouth",
	"tackle": "body", "scratch": "hand", "bite": "mouth",
	"ember": "mouth", "watergun": "mouth", "thundershock": "body",
	"flamethrower": "mouth", "bubble": "mouth", "bubblebeam": "mouth",
	"icebeam": "mouth", "razorleaf": "body", "quickattack": "body",
	"bugbite": "mouth", "peck": "mouth", "lick": "mouth",
	"doublekick": "foot", "highjumpkick": "foot", "lowkick": "foot", "pyroball": "foot",
}
const PROFILES := {
	"pikachu": {"electric_body": [["spine_02", Vector3.ZERO]]},
	"charmander": {
		"mouth": [["head", Vector3(0.05, 0, 0.195)]],
		"hand": [["right_hand", Vector3(0.033, 0, 0)]],
	},
	# Calibrated at the open lip in Charmeleon's native special-attack pose.
	"charmeleon": {"mouth": [["head", Vector3(-0.015, 0, 0.235)]]},
	"squirtle": {"mouth": [["head", Vector3(0, 0, 0.145)]]},
	"blastoise": {
		"mouth": [["head", Vector3(0.08, 0, 0.275)]],
		"cannons": [["left_feeler_b_02", Vector3(0.261, 0, 0)], ["right_feeler_b_02", Vector3(0.261, 0, 0)]],
	},
}
const MOVE_OVERRIDES := {"blastoise": {"scald": "cannons", "hydrovortex": "cannons", "watergun": "cannons", "bubblebeam": "cannons", "icebeam": "cannons", "flashcannon": "cannons"}, "pikachu": {"thundershock": "electric_body", "thunderbolt": "electric_body"}}
const CACHE_META := &"move_attachment_bindings"

static func action_for(identity: String, move_key: String, available_actions: Dictionary) -> String:
	var species := Catalog.canonical_identity(identity).trim_suffix("@shiny")
	var action := str(CALIBRATED.data.profiles.get(species, {}).get("move_actions", {}).get(move_key, ""))
	return action if action in ["physical_attack", "physical_attack_2", "special_attack", "special_attack_2"] and available_actions.has(action) else ""

static func part_for(identity: String, move_key: String) -> String:
	# Shiny uses the same rig; alternate/Mega forms require their own profile.
	var species := Catalog.canonical_identity(identity).trim_suffix("@shiny")
	var overrides: Dictionary = MOVE_OVERRIDES.get(species, {}).duplicate()
	overrides.merge(CALIBRATED.data.profiles.get(species, {}).get("moves", {}), true)
	return overrides.get(move_key, MOVE_PARTS.get(move_key, Recipes.get_recipe(move_key).get("attachment", "body")))

## Reviewed timing/orientation belongs to one exact form, move and native clip.
static func choreography_for(identity: String, move_key: String, action: String) -> Dictionary:
	var species := Catalog.canonical_identity(identity).trim_suffix("@shiny")
	var spec: Dictionary = CALIBRATED.data.profiles.get(species, {}).get("move_choreography", {}).get(move_key, {})
	if spec.get("action", "") != action: return {}
	var launch := float(spec.get("launch_fraction", -1))
	var impact := float(spec.get("impact_fraction", -1))
	var yaw := float(spec.get("contact_yaw_degrees", 0))
	if not is_finite(launch) or not is_finite(impact) or not is_finite(yaw): return {}
	if launch < 0 or launch >= impact or impact >= 1 or absf(yaw) > 180: return {}
	return {"launch_fraction": launch, "impact_fraction": impact, "contact_yaw_degrees": yaw}

## One outer element is one emitter. Its weighted bones describe a single
## moving point (e.g. between two lips); paired cannons remain two emitters.
static func definitions_for(identity: String, part: String, action := "") -> Array:
	var species := Catalog.canonical_identity(identity).trim_suffix("@shiny")
	var profile: Dictionary = CALIBRATED.data.profiles.get(species, {})
	var parts: Dictionary = profile.get("parts", {}).duplicate()
	parts.merge(profile.get("actions", {}).get(action, {}), true)
	if parts.has(part): return parts[part]
	var groups := []
	for definition: Array in PROFILES.get(species, {}).get(part, []):
		var offset: Vector3 = definition[1]
		groups.append([{"bone": definition[0], "offset": [offset.x, offset.y, offset.z], "weight": 1.0}])
	return groups

static func configured_parts(identity: String) -> Array:
	var species := Catalog.canonical_identity(identity).trim_suffix("@shiny")
	var parts: Dictionary = PROFILES.get(species, {}).duplicate()
	parts.merge(CALIBRATED.data.profiles.get(species, {}).get("parts", {}), true)
	for action_parts: Dictionary in CALIBRATED.data.profiles.get(species, {}).get("actions", {}).values():
		parts.merge(action_parts, true)
	var keys := parts.keys()
	keys.sort()
	return keys

static func sample(actor: Node3D, identity: String, move_key: String, world: Node3D, action := "") -> Dictionary:
	return sample_part(actor, identity, part_for(identity, move_key), world, action)

static func sample_part(actor: Node3D, identity: String, part: String, world: Node3D, action := "") -> Dictionary:
	if not is_instance_valid(actor) or not is_instance_valid(world): return {}
	var species := Catalog.canonical_identity(identity).trim_suffix("@shiny")
	var definitions := definitions_for(species, part, action)
	if definitions.is_empty(): return {}
	var cache: Dictionary = actor.get_meta(CACHE_META, {})
	var cache_key := species + ":" + part + ":" + action
	if not cache.has(cache_key):
		cache[cache_key] = _bind(actor, definitions)
		actor.set_meta(CACHE_META, cache)
	var points: Array[Vector3] = []
	var names: Array[String] = []
	for group: Array in cache[cache_key]:
		if group[0].has("visible_mesh"):
			var mesh: Node3D = group[0].visible_mesh.get_ref()
			if not is_instance_valid(mesh) or not mesh.is_inside_tree(): return {}
			if not mesh.is_visible_in_tree(): continue
		var point := Vector3.ZERO
		var total_weight := 0.0
		for binding: Dictionary in group:
			var skeleton: Skeleton3D = binding.skeleton.get_ref()
			if not is_instance_valid(skeleton) or not skeleton.is_inside_tree(): return {}
			var local: Vector3 = skeleton.get_bone_global_pose(binding.bone) * binding.offset
			point += world.to_local(skeleton.to_global(local)) * binding.weight
			total_weight += binding.weight
			names.append(binding.name)
		if total_weight <= 0.0: return {}
		points.append(point / total_weight)
	if points.is_empty(): return {}
	return {"sources": points, "part": part, "bones": names}

static func _bind(actor: Node3D, definitions: Array) -> Array:
	var groups := []
	for group: Array in definitions:
		if group.is_empty(): return []
		var visible_mesh: Node3D
		if group[0].has("visible_mesh"):
			visible_mesh = actor.get_node_or_null(NodePath(str(group[0].visible_mesh))) as MeshInstance3D
			if visible_mesh == null: return []
		var bindings := []
		for definition: Dictionary in group:
			var raw: Array = definition.get("offset", [])
			var weight := float(definition.get("weight", 1.0))
			if raw.size() != 3 or not is_finite(weight) or weight <= 0.0: return []
			var offset := Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
			if not offset.is_finite(): return []
			var found := false
			for skeleton: Skeleton3D in actor.find_children("*", "Skeleton3D", true, false):
				var bone := skeleton.find_bone(str(definition.get("bone", "")))
				if bone < 0: continue
				bindings.append({"skeleton": weakref(skeleton), "bone": bone,
					"name": definition.bone, "offset": offset, "weight": weight})
				found = true
				break
			# Missing one lip or one cannon invalidates the entire attachment.
			if not found: return []
		if visible_mesh != null: bindings[0]["visible_mesh"] = weakref(visible_mesh)
		groups.append(bindings)
	return groups
