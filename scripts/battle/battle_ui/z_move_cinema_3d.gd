extends RefCounted
## Z-only composition: captured attack anchors, native clock, no gameplay state.
const DATA = preload("res://data/battle_z_cinema_3d.json")
const Recipes = preload("res://scripts/battle/battle_ui/move_recipe_3d.gd")
const SkystrikePath = preload("res://scripts/battle/battle_ui/skystrike_path_3d.gd")
const SkystrikeExplosion = preload("res://scripts/battle/battle_ui/skystrike_explosion_3d.gd")
const Climax = preload("res://scripts/battle/battle_ui/z_climax_3d.gd")

static func supports(key: String) -> bool:
	return DATA.data.moves.has(key)

static func shot(effect: Node, camera: Camera3D, context: Dictionary, seconds: float) -> Dictionary:
	var profile: Dictionary = DATA.data.moves[effect.key]
	var recipe := Recipes.get_recipe(effect.key)
	var a: Dictionary = context.actor_body
	var b: Dictionary = context.target_body
	var source: Vector3 = context.source
	var target: Vector3 = context.target
	var ground: Vector3 = context.target_ground
	var forward: Vector3 = ground - context.actor_ground
	forward.y = 0.0
	# Self-targeting Extreme Evoboost still needs a front three-quarter shot.
	if forward.length_squared() < 0.01: forward = -camera.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var side := forward.cross(Vector3.UP).normalized()
	var points: Array[Vector3] = []
	var scale_value: float = effect.presentation_scale
	var direction := forward + side * 0.8 + Vector3.UP * 0.16
	if seconds < effect.launch or profile.shot == "self":
		_body(points, a)
		_box(points, context.actor_center, Vector3.ONE * (2.0 if profile.shot == "self" else 0.7) * scale_value)
		_box(points, source + Vector3.UP * (1.2 if effect.key == "lightthatburnsthesky" else 0.0), Vector3.ONE * scale_value)
	elif seconds < effect.impact:
		_body(points, a)
		_body(points, b)
		_box(points, source, Vector3.ONE * 0.8 * scale_value)
		var height: float = profile.height
		var radius := 1.8 * scale_value
		if profile.shot == "field":
			var field: Dictionary = context.field
			_box(points, field.center + Vector3.UP * height * 0.5, Vector3(field.radius + 0.5, height * 0.5, field.radius + 0.5))
		else:
			_box(points, ground + Vector3.UP * height * 0.5, Vector3(radius, height * 0.5 + scale_value, radius))
			if profile.shot == "air":
				_box(points, context.actor_center.lerp(target, 0.5) + Vector3.UP * 2.0, Vector3.ONE * maxf(float(a.height), radius))
			elif profile.shot in ["orb", "dragon", "wave"]:
				_box(points, source.lerp(target, 0.5) + Vector3.UP * 1.5, Vector3.ONE * radius)
		direction = -forward * 0.25 + side + Vector3.UP * float(profile.elevation)
		if effect.key == "supersonicskystrike":
			_box(points,context.actor_center + Vector3.UP*SkystrikePath.HEIGHT,Vector3.ONE*maxf(float(a.height)*0.65,1.8))
			var flight := clampf((seconds-effect.launch)/maxf(effect.impact-effect.launch,0.01),0,1)
			# Low three-quarter ascent, then a view down the diving trajectory.
			direction = -forward*0.4+side+Vector3.UP*(0.16 if flight<0.55 else 0.85)
	else:
		_body(points, b)
		var radius := 2.0 * scale_value
		_box(points, target, Vector3.ONE * radius)
		_box(points, ground + Vector3.UP * float(profile.height) * 0.5, Vector3(radius, float(profile.height) * 0.5, radius))
		if bool(recipe.contact): _body(points, a)
		direction = -forward * 0.7 + side + Vector3.UP * maxf(0.2, float(profile.elevation) * 0.6)
		if effect.key == "supersonicskystrike" and effect.hit:
			# Reserve the entire pressure front; the explosion must not grow out
			# of frame or force the camera to chase individual cloud lobes.
			_box(points,ground+Vector3.UP*2.5*scale_value,Vector3(SkystrikeExplosion.FRAME_RADIUS,3.0,SkystrikeExplosion.FRAME_RADIUS)*scale_value)
			direction = -forward*0.5+side+Vector3.UP*0.25
	if Climax.supports(effect.key) and seconds >= effect.impact and (effect.hit or profile.shot == "self"):
		var finale: Dictionary = Climax.DATA.data.moves[effect.key]
		var local_scale: float = effect._geometry_scale()
		var center: Vector3 = context.actor_ground if profile.shot == "self" else ground
		_box(points,center+Vector3.UP*float(finale.height)*0.45*local_scale,Climax.frame_half(effect.key)*local_scale)
		# Stay on the same side of the battle axis and frame the complete blast.
		direction = -forward*0.5+side+Vector3.UP*float(finale.elevation)
	return {"points":points, "direction":direction.normalized()}

static func _body(points: Array[Vector3], bounds: Dictionary) -> void:
	var half := Vector3(float(bounds.radius), float(bounds.height) * 0.5, float(bounds.radius))
	_box(points, bounds.position + Vector3.UP * half.y, half)

static func _box(points: Array[Vector3], center: Vector3, half: Vector3) -> void:
	for corner in 8: points.append(AABB(center - half, half * 2.0).get_endpoint(corner))

static func lighting(effect: Node, seconds: float) -> Dictionary:
	var authored: Dictionary = DATA.data.moves[effect.key]
	var recipe := Recipes.get_recipe(effect.key)
	var tint := Color(str(authored.tint))
	var flash := Color(str(authored.flash))
	var profile := {"tint":tint, "flash":flash, "brightness":float(authored.brightness), "mix":float(authored.mix)}
	var charge := smoothstep(0.0, maxf(effect.launch, 0.01), seconds)
	var flight := clampf((seconds - effect.launch) / maxf(effect.impact - effect.launch, 0.01), 0.0, 1.0)
	var after := clampf((seconds - effect.impact) / maxf(effect.duration - effect.impact, 0.01), 0.0, 1.0)
	var weight := charge * (1.0 - smoothstep(0.0, 1.0, after))
	var pulse := sin(clampf(after / 0.45, 0.0, 1.0) * PI) if effect.hit and bool(recipe.damaging) else 0.0
	if effect.key == "supersonicskystrike" and effect.hit and seconds >= effect.impact:
		pulse = SkystrikeExplosion.pulse(after)
		profile.tint = tint.lerp(flash,pulse*0.25)
		profile.brightness = lerpf(float(authored.brightness),1.08,pulse)
	elif Climax.supports(effect.key) and seconds >= effect.impact:
		var finale: Dictionary = Climax.DATA.data.moves[effect.key]
		var self_aura: bool = authored.shot == "self"
		var burst := Climax.pulse(effect.key,after) if effect.hit or self_aura else 0.0
		pulse = burst if not self_aura else 0.0
		flash = Color(finale.hot)
		profile.flash = flash
		profile.tint = tint.lerp(Color(finale.tint),burst*0.4)
		profile.brightness = lerpf(float(authored.brightness),1.08 if not self_aura else 1.02,burst)
	var anchors: Dictionary = effect.anchors.call()
	# Both Z renderers capture their path before any lunge/dodge takes place.
	var source: Vector3 = effect.fixed_source if effect.get("fixed_source") is Vector3 else effect.origin
	var aim: Vector3 = effect.aim
	var energy := float(authored.energy)
	var point := source.lerp(aim, flight)
	if bool(recipe.contact) or authored.shot == "self": point = anchors.actor_center
	elif authored.shot in ["orb", "dragon"]: point += Vector3.UP * sin(flight * PI) * 1.5
	elif authored.shot in ["column", "vortex", "lightning"]: point = aim + Vector3.UP * float(authored.height) * 0.3
	var color := Color(str(recipe.color)).lerp(flash, flight * 0.3)
	var lights: Array[Dictionary] = []
	if seconds < effect.impact:
		lights.append({"point":source if seconds < effect.launch else point, "color":color, "energy":energy * charge, "range":4.5, "role":"z_cast"})
	if authored.shot == "field":
		lights.append({"point":anchors.field.center + Vector3.UP * 2.0, "color":color, "energy":energy * weight * 0.6, "range":7.0, "role":"z_field"})
	if authored.shot == "self" and seconds >= effect.impact:
		lights.append({"point":anchors.actor_center,"color":flash,"energy":energy*Climax.pulse(effect.key,after),"range":6.0,"role":"z_aura"})
	if pulse > 0.001:
		var blast: bool = effect.key == "supersonicskystrike" or Climax.supports(effect.key)
		lights.append({"point":aim, "color":flash, "energy":energy * pulse * (2.6 if blast else 1.0), "range":8.5 if blast else 5.0, "role":"z_impact"})
	return {"profile":profile, "weight":weight, "pulse":pulse, "color":color, "lights":lights, "cinematic":true}
