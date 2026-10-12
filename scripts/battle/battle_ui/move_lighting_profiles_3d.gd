extends RefCounted
## Individually authored lighting beats sampled from the existing native VFX clock.
const Recipes = preload("res://scripts/battle/battle_ui/move_recipe_3d.gd")
const PROFILES := {
	"hyperbeam": {"tint":Color("ffc477"), "flash":Color("fff4d6"), "brightness":0.96, "energy":1.45, "range":3.6, "mix":0.24},
	"solarbeam": {"tint":Color("c9ed76"), "flash":Color("ffffce"), "brightness":1.025, "energy":1.15, "range":3.8, "mix":0.28},
	"flashcannon": {"tint":Color("acdaef"), "flash":Color("eefaff"), "brightness":0.98, "energy":1.1, "range":3.0, "mix":0.18},
	"pyroball": {"tint":Color("ff8e45"), "flash":Color("ffd19b"), "brightness":0.98, "energy":1.65, "range":3.4, "mix":0.20},
	"flamethrower": {"tint":Color("ff9a52"), "flash":Color("ffcf7b"), "brightness":1.0, "energy":1.0, "range":3.3, "mix":0.19},
	"thunderbolt": {"tint":Color("ffe377"), "flash":Color("e0f4ff"), "brightness":0.96, "energy":1.35, "range":3.4, "mix":0.21},
	"electroshot": {"tint":Color("7fbaff"), "flash":Color("fff2a2"), "brightness":0.94, "energy":1.45, "range":3.7, "mix":0.26},
	"icebeam": {"tint":Color("8bddf2"), "flash":Color("dcfaff"), "brightness":1.0, "energy":0.95, "range":3.0, "mix":0.23},
	"blizzard": {"tint":Color("b1d9ef"), "flash":Color("e4f6ff"), "brightness":1.02, "energy":0.6, "range":7.0, "mix":0.40},
	"hurricane": {"tint":Color("81969f"), "flash":Color("bbcdd4"), "brightness":0.86, "energy":0.25, "range":7.0, "mix":0.36},
}
const RECIPE_BEAMS := ["hyperbeam", "solarbeam", "electroshot"]
const FIELDS := ["blizzard", "hurricane"]

static func emission_end(effect: Node) -> float:
	if effect.key in RECIPE_BEAMS:
		return effect.emission_end if effect.emission_end >= 0 else lerpf(effect.impact, effect.duration, 0.65)
	if effect.key in ["icebeam", "flamethrower"]: return effect.emission_end
	if effect.key == "flashcannon":
		return effect.emission_end if effect.emission_end >= 0 else effect.impact + effect.duration * 0.22 * 0.65
	if effect.key == "thunderbolt": return effect.impact + effect.duration * 0.28 * 0.75
	return effect.impact

static func sample(effect: Node, seconds: float) -> Dictionary:
	if Recipes.EXTENSIONS.data.moves.has(effect.key): return _sample_extension(effect, seconds)
	var profile: Dictionary = PROFILES[effect.key]
	var points: Dictionary = effect.anchors.call()
	var origin: Vector3 = points.source
	var aim: Vector3 = points.target
	if effect.key in RECIPE_BEAMS or effect.key == "pyroball":
		if effect.launched:
			origin = effect.origin
			aim = effect.aim
	elif effect.key in FIELDS and effect.captured:
		aim = effect.aim
	var charge := smoothstep(effect.effect_start, maxf(effect.launch, effect.effect_start + 0.01), seconds)
	var flight := clampf((seconds - effect.launch) / maxf(effect.impact - effect.launch, 0.01), 0.0, 1.0)
	var after: float = (seconds - effect.impact) / maxf(effect.duration - effect.impact, 0.01)
	var phase: float = seconds / effect.duration
	var weight := charge * (1.0 - smoothstep(0.0, 1.0, after))
	var pulse := smoothstep(0.0, 0.05, after) * (1.0 - smoothstep(0.05, 0.4, after)) if effect.hit else 0.0
	var tint: Color = profile.tint
	var color: Color = tint
	var energy: float = profile.energy
	var reach := clampf(float(profile.range) * effect.emission_scale, 2.0, 5.0)
	var lights: Array[Dictionary] = []
	match effect.key:
		"hyperbeam":
			color = tint.lerp(Color("fff0c0"), flight * 0.7)
			charge *= charge # Hot compact charge, followed by a warm white shaft.
		"solarbeam":
			color = Color("e7d773").lerp(tint, smoothstep(0.0, 0.5, flight))
		"flashcannon":
			color = tint.lerp(Color.WHITE, flight * 0.45)
		"flamethrower":
			energy *= 0.9 + 0.07 * sin(phase * 19.0) + 0.03 * sin(phase * 37.0)
		"thunderbolt":
			var wave := pow(sin(flight * PI * 3.0 + maxf(after, 0.0) * PI * 2.0), 2.0)
			energy *= 0.78 + wave * 0.22
			color = tint.lerp(profile.flash, wave * 0.2)
		"electroshot":
			var wave := pow(sin(flight * PI * 2.0 + maxf(after, 0.0) * PI * 3.0), 2.0)
			energy *= 0.83 + wave * 0.17
			color = tint.lerp(profile.flash, smoothstep(0.0, 0.35, flight) * 0.6)
		"icebeam":
			color = tint.lerp(profile.flash, flight * 0.35)
		"pyroball":
			var fraction := smoothstep(0.0, 1.0, flight)
			var point := origin.lerp(aim, fraction)
			point.y += sin(fraction * PI) * effect.projectile_arc_height
			if seconds < effect.impact:
				_add(lights, point, color, energy * (charge * 0.5 if seconds < effect.launch else 1.0), reach, "projectile")
		"blizzard", "hurricane":
			# Broad, restrained illumination sits inside the captured field volume.
			weight = smoothstep(0.0, 0.1, phase) * (1.0 - smoothstep(0.72, 1.0, phase))
			if effect.key == "hurricane": pulse = 0.0 # Wind dims; it does not flash like lightning.
			var field: Dictionary = points.get("field", {})
			var center: Vector3 = effect.field_center if effect.captured else field.get("center", (origin + aim) * 0.5)
			var radius: float = effect.field_radius if effect.captured else field.get("radius", 5.8)
			_add(lights, center + Vector3.UP * 2.0, tint, energy * weight, clampf(radius * 1.3, 5.0, 10.0), "field")
	if effect.key not in FIELDS and effect.key != "pyroball":
		var sources: Array = points.get("sources", [origin])
		if sources.is_empty(): sources = [origin]
		var end := emission_end(effect)
		var fade := 1.0 - smoothstep(effect.impact, maxf(end, effect.impact + 0.01), seconds)
		if seconds >= end: fade = 0.0
		var split := 1.0 / sqrt(float(sources.size()))
		for emitter: Vector3 in sources.slice(0, 2):
			if seconds < effect.launch:
				_add(lights, emitter, color, energy * charge * 0.5 * split, reach * 0.7, "charge")
			elif fade > 0.0001:
				var tip := emitter.lerp(aim, flight)
				var growth := smoothstep(0.0, 0.12, flight)
				for fraction in [0.0, 0.5, 1.0]:
					_add(lights, emitter.lerp(tip, fraction), color, energy * fade * growth * split * 0.45, reach, "beam")
	if pulse > 0.0001:
		_add(lights, aim, profile.flash, float(profile.energy) * pulse, reach + 0.5, "impact")
	return {"weight":weight, "pulse":pulse, "lights":lights, "color":tint.lerp(profile.flash, pulse * 0.45), "profile":profile}

static func _add(lights: Array[Dictionary], point: Vector3, color: Color, energy: float, reach: float, role: String) -> void:
	if energy <= 0.0001: return
	lights.append({"point":point, "color":color, "energy":energy, "range":reach, "role":role})

static func supports(key: String) -> bool:
	return PROFILES.has(key) or float(Recipes.get_recipe(key).get("lighting", {}).get("energy", 0.0)) > 0.0

static func _sample_extension(effect: Node, seconds: float) -> Dictionary:
	var recipe: Dictionary = Recipes.get_recipe(effect.key)
	var tint := Color(str(recipe.color))
	var config: Dictionary = recipe.lighting
	var profile := {"tint":tint,"flash":tint.lerp(Color.WHITE,.55),"brightness":float(config.brightness),"mix":float(config.mix),"energy":float(config.energy)}
	var charge := smoothstep(effect.effect_start,maxf(effect.launch,effect.effect_start+.01),seconds)
	var flight := clampf((seconds-effect.launch)/maxf(effect.impact-effect.launch,.01),0,1)
	var after: float = (seconds-effect.impact)/maxf(effect.duration-effect.impact,.01)
	var weight := charge*(1.-smoothstep(0,1.,after))
	var pulse := sin(clampf(after/.4,0,1)*PI) if effect.hit and bool(recipe.damaging) else 0.0
	var points: Dictionary = effect.anchors.call()
	var origin: Vector3 = effect.origin if effect.launched else points.source
	var aim: Vector3 = effect.aim if effect.launched else points.target
	var lights: Array[Dictionary] = []
	var energy := float(config.energy)
	if recipe.family=="beams":
		var fade := 1.-smoothstep(effect.impact,effect.emission_end,seconds)
		if seconds < effect.emission_end:
			for emitter: Vector3 in points.get("sources",[origin]).slice(0,2):
				_add(lights,emitter.lerp(aim,flight*.5),tint,energy*charge*fade,3.,"beam")
	elif recipe.family=="projectiles":
		if seconds < effect.impact:
			var point := origin.lerp(aim,flight)+Vector3.UP*sin(flight*PI)*float(recipe.arc)
			_add(lights,point,tint,energy*charge,3.,"projectile")
	elif recipe.family=="field":
		_add(lights,effect.field_center+Vector3.UP*1.6,tint,energy*weight,6.,"field")
	else:
		var point: Vector3 = points.get("actor_center",origin) if recipe.contact or recipe.target=="actor" else origin.lerp(aim,flight)
		_add(lights,point,tint,energy*weight*.65,2.5,"cast")
	if pulse>.001:_add(lights,aim,profile.flash,energy*pulse,3.,"impact")
	return {"weight":weight,"pulse":pulse,"lights":lights,"color":tint.lerp(profile.flash,pulse*.25),"profile":profile}
