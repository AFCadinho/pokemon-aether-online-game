extends Node3D
## First native move VFX. Samples the model clock; never changes HP or outcomes.
signal finished
const KEYS := ["tackle", "scratch", "bite", "ember", "watergun", "thundershock", "thunderbolt", "flamethrower", "bubble", "bubblebeam", "icebeam", "razorleaf", "quickattack", "shadowball", "sludgebomb", "focusblast", "moonblast", "iceshard", "poisonsting", "swift", "flashcannon", "magicalleaf", "waterpulse"]
const COLORS := [Color("ffd798"), Color("ffeac2"), Color("fff1d0"), Color("ff6b16"), Color("29baff"), Color("ffdc25"), Color("ffe448"), Color("ff671b"), Color("69dcff"), Color("3fc7ff"), Color("83e3ff"), Color("81ed42"), Color("e5f8ff"), Color("9b38e8"), Color("bc58d4"), Color("84f4ff"), Color("ffb3ed"), Color("d7f6ff"), Color("d4a0ff"), Color("fff1a1"), Color("e4fbff"), Color("bdff75"), Color("8eedff")]
const AUDIO_EDITS = preload("res://assets/battles/moves_3d/audio_edited/manifest.json")
const IMPACT_SOUNDS := {
	"shadowball": "PRSFX- Shadow Ball2.wav", "sludgebomb": "PRSFX- Sludge Bomb2.wav",
	"moonblast": "PRSFX- Moonblast2.wav", "swift": "PRSFX- Swift2.wav",
	"magicalleaf": "PRSFX- Magical Leaf2.wav", "waterpulse": "PRSFX- Water Pulse2.wav",
}
# World-space size, independent of camera angle. Scale geometry around each
# sampled anchor, never the effect root (which would move mouths and targets).
const PRESENTATION_SCALES := {
	"tackle": 1.3, "scratch": 1.3, "bite": 1.2, "quickattack": 1.35,
	"ember": 1.6, "watergun": 1.8, "thundershock": 1.7, "thunderbolt": 1.8,
	"flamethrower": 1.7, "bubble": 1.6, "bubblebeam": 1.7, "icebeam": 1.8,
	"razorleaf": 1.6, "shadowball": 2.0, "sludgebomb": 1.8, "focusblast": 2.2,
	"moonblast": 2.5, "iceshard": 1.7, "poisonsting": 1.6, "swift": 1.8,
	"flashcannon": 2.5, "magicalleaf": 1.7, "waterpulse": 1.8,
}
var presentation_scale := 1.0
var key := ""
var elapsed := 0.0
var duration := 1.0
var impact := 0.45
var launch := 0.1
var done := false
var cancelled := false
var hit := false
var miss := false
var clock: Callable
var anchors: Callable
var valid: Callable
var view_camera: Camera3D
var pieces: Array[MeshInstance3D] = []
var core: StandardMaterial3D
var edge: StandardMaterial3D
var glow: StandardMaterial3D
var sphere := SphereMesh.new()
var tube := CylinderMesh.new()
var tooth := CylinderMesh.new()
var cursor := 0
var emission_sources: Array = []

func _init() -> void:
	# Sample attachment poses after the stage has applied its actor transforms.
	process_priority = 11

static func move_key(move: String) -> String:
	return move.strip_edges().to_lower().replace(" ", "").replace("-", "").replace("_", "")

static func supports(move: String) -> bool:
	return move_key(move) in KEYS

static func audio_source_key(move: String) -> String:
	# No separate Bubble Beam sample is packaged yet; reuse Bubble only in 3D.
	var normalized := move_key(move)
	return "bubble" if normalized == "bubblebeam" else normalized

static func audio_plan(source: Dictionary, timing: Dictionary) -> Dictionary:
	if source.is_empty() or timing.is_empty(): return {}
	var plan := source.duplicate(true)
	var duration_seconds := float(timing.frames) / 60.0
	var impact_seconds := float(timing.impact_frame) / 60.0
	var release := launch_time(timing)
	var cues: Array = []
	var paths := {}
	var seen := {}
	for cue: Dictionary in source.get("cues", []):
		var name := str(cue.event.get("name", ""))
		if seen.has(name): continue
		seen[name] = true
		# Fail closed for a changed catalog: never accidentally restore a full
		# multi-second 2D sample to a native move that has not been reviewed.
		var edit: Dictionary = AUDIO_EDITS.data.entries.get(name, {})
		if edit.is_empty(): continue
		var role := str(edit.role)
		var at_seconds := release
		var end_seconds := impact_seconds + duration_seconds * 0.06
		if role == "charge":
			at_seconds = 0.0
			end_seconds = release
		elif role == "impact":
			at_seconds = impact_seconds
			end_seconds = impact_seconds + duration_seconds * 0.25
		elif role == "stream":
			end_seconds = impact_seconds + duration_seconds * 0.18
		end_seconds = minf(end_seconds, duration_seconds)
		if end_seconds <= at_seconds: continue
		var event: Dictionary = cue.event.duplicate(true)
		event["role"] = role
		event["requires_hit"] = role == "impact"
		event["end_seconds"] = end_seconds
		event["fade_seconds"] = minf(duration_seconds * 0.06, (end_seconds-at_seconds) * 0.25)
		cues.append({"at_seconds": at_seconds, "event": event})
		paths[name] = edit.path
	cues.sort_custom(func(a, b): return a.at_seconds < b.at_seconds)
	plan.cues = cues
	plan.sound_paths = paths
	plan.duration_seconds = duration_seconds
	plan.speed_scale = 1.0
	plan["bounded_to_action"] = true
	return plan

static func launch_time(timing: Dictionary) -> float:
	var impact_seconds := float(timing.impact_frame) / 60.0
	return clampf(float(timing.get("launch_frame", float(timing.impact_frame) - float(timing.frames) * 0.28)) / 60.0, 0.0, impact_seconds)

func start(move: String, timing: Dictionary, options: Dictionary, native_clock: Callable, positions: Callable, guard: Callable) -> void:
	key = move_key(move)
	presentation_scale = float(PRESENTATION_SCALES.get(key, 1.0))
	duration = float(timing.frames) / 60.0
	impact = float(timing.impact_frame) / 60.0
	launch = launch_time(timing)
	clock = native_clock
	anchors = positions
	valid = guard
	miss = str(options.get("result", "")).strip_edges().to_lower() == "miss"
	hit = bool(options.get("show_impact", options.get("stop_at_impact", false))) and not miss
	set_meta("battle_field_visual", true) # Exclude temporary geometry from irradiance copies.
	var color: Color = COLORS[KEYS.find(key)]
	core = _material(color.lerp(Color.WHITE, 0.8), 0.95)
	edge = _material(color, 0.85)
	glow = _material(color, 0.18)
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	tube.top_radius = 1.0
	tube.bottom_radius = 1.0
	tube.height = 1.0
	tube.radial_segments = 10
	tooth.top_radius = 0.0
	tooth.bottom_radius = 1.0
	tooth.height = 1.0
	tooth.radial_segments = 4
	_process(0)

func _material(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color, alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.5
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func seconds() -> float:
	return elapsed

func cancel() -> void:
	if done: return
	cancelled = true
	_finish()

func _finish() -> void:
	if done: return
	done = true
	visible = false
	set_process(false)
	clock = Callable()
	anchors = Callable()
	valid = Callable()
	finished.emit()
	queue_free()

func _geometry_scale() -> float:
	return presentation_scale

func _piece(mesh: Mesh, material: Material, point: Vector3, scale_value: Vector3, basis_value := Basis.IDENTITY, preserve_length := false) -> void:
	if cursor >= pieces.size():
		var node := MeshInstance3D.new()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		pieces.append(node)
	var node := pieces[cursor]
	cursor += 1
	node.mesh = mesh
	node.material_override = material
	var dimensions := scale_value * _geometry_scale()
	# Beam/cone length is the measured source-to-tip distance, not an artistic
	# dimension. Only widen it, so it cannot overshoot the target or emitter.
	if preserve_length: dimensions.y = scale_value.y
	node.transform = Transform3D(basis_value * Basis.from_scale(dimensions), point)
	node.visible = true

func _ball(point: Vector3, radius: float, material: Material) -> void:
	if radius > 0.002: _piece(sphere, material, point, Vector3.ONE * radius)

func _line(a: Vector3, b: Vector3, width: float, material: Material) -> void:
	var delta := b - a
	if delta.length() < 0.001 or width <= 0.001: return
	var y := delta.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	_piece(tube, material, (a+b)*0.5, Vector3(width, delta.length()+width*0.65, width), Basis(x,y,x.cross(y)), true)

func _process(_delta: float) -> void:
	if done: return
	if not valid.is_valid() or not valid.call():
		cancel()
		return
	elapsed = maxf(elapsed, float(clock.call()))
	if elapsed + 0.00001 >= duration:
		elapsed = duration
		_finish()
		return
	var points: Dictionary = anchors.call()
	emission_sources = points.get("sources", [points.source])
	if emission_sources.is_empty(): emission_sources = [points.source]
	var from: Vector3 = emission_sources[0]
	var to: Vector3 = points.target
	var size := clampf(float(points.radius), 0.35, 1.4)
	var right := Vector3.RIGHT
	var up := Vector3.UP
	if is_instance_valid(view_camera):
		right = global_basis.inverse() * view_camera.global_basis.x
		up = global_basis.inverse() * view_camera.global_basis.y
	var travel := clampf((elapsed-launch) / maxf(impact-launch,0.01),0,1)
	var after := (elapsed-impact) / maxf(duration * 0.19,0.01)
	var fade := 1.0 - clampf(after,0,1)
	cursor = 0
	if _draw_source_move(from, to, right, up):
		for i in range(cursor, pieces.size()): pieces[i].visible = false
		return
	if elapsed >= launch and after < 1.0:
		match key:
			"tackle":
				for i in 5:
					var offset: Vector3 = right * sin(i*2.4) * size * 0.5 + up * cos(i*2.4) * size * 0.4
					var end: Vector3 = from.lerp(to, travel) + offset
					_line(end - (to-from).normalized()*0.9*fade, end, 0.028*fade, core)
			"scratch":
				if hit or miss:
					var sweep := clampf((elapsed-impact) / (duration*0.12) + 0.6,0,1)
					for claw in 3:
						for segment in 7:
							var t := float(segment)/7.0
							if t > sweep: continue
							var next := t+1.0/7.0
							var a: Vector3 = to + right*((claw-1)*0.35 + (t-0.5)*0.65+sin(t*PI)*0.18)*size + up*(0.8-t*1.6)*size
							var b: Vector3 = to + right*((claw-1)*0.35 + (next-0.5)*0.65+sin(next*PI)*0.18)*size + up*(0.8-next*1.6)*size
							var width := sin((t+0.08)*PI)*0.07*size*fade
							_line(a,b,width,edge)
							_line(a+right*0.01,b+right*0.01,width*0.4,core)
			"bite":
				if hit or miss:
					var opening := absf(clampf((elapsed-impact)/(duration*0.16),-1,1))
					for jaw in [-1,1]:
						for i in 5:
							var x := (i-2)*0.32
							var point: Vector3 = to + right*x*size + up*jaw*(0.14+opening*0.8 + x*x*0.25)*size
							var forward: Vector3 = right.cross(up)
							_piece(tooth,core,point,Vector3(0.14,0.42,0.16)*size*fade,Basis(right,up*-jaw,forward*-jaw))
							if i < 4:
								var next_x := x+0.32
								var base: Vector3 = point + up*jaw*0.21*size
								var next: Vector3 = to + right*next_x*size + up*jaw*(0.35+opening*0.8+next_x*next_x*0.25)*size
								_line(base,next,0.035*size*fade,edge)
			"ember":
				for ember in 3:
					var phase := clampf(travel - ember*0.055,0,1)
					var point: Vector3 = from.lerp(to, phase) + up*sin(phase*PI)*0.5 + right*(ember-1)*sin(phase*PI)*0.2
					_ball(point,0.15*fade,core)
					_ball(point,0.24*fade,glow)
					for tail in 4:
						var behind := maxf(0, phase-tail*0.026)
						_ball(from.lerp(to,behind)+up*sin(behind*PI)*0.5+right*(ember-1)*sin(behind*PI)*0.2,(0.15-tail*0.028)*fade,edge)
			"watergun":
				for origin: Vector3 in emission_sources:
					for i in 18:
						var t := float(i)/18.0
						if t > travel: continue
						var next := minf(t+1.0/18.0,travel)
						var a := origin.lerp(to,t)+up*sin(t*PI)*0.18
						var b := origin.lerp(to,next)+up*sin(next*PI)*0.18
						var width := (0.07 + t*0.07)*(0.85+0.15*sin(t*35-elapsed*25))*fade
						_line(a,b,width,edge)
						_line(a+up*0.025,b+up*0.025,width*0.35,core)
			"thundershock":
				var end := from.lerp(to,travel)
				for branch in 2:
					var last := from
					for i in range(1,11):
						var t := float(i)/10.0
						var jitter := sin(t*PI)*0.28
						var point := from.lerp(end,t) + right*sin(i*13.1+floor(elapsed*18)*2.4+branch)*jitter + up*cos(i*5.8+branch)*jitter
						_line(last,point,0.04*fade,edge)
						_line(last,point,0.013*fade,core)
						last = point
		if hit and after >= 0.0 and after < 1.0:
			# Impact is visual only. Damage/audio still belong to their ordered events.
			_ball(to, size*(0.12+after*0.3)*fade,glow)
			for i in 9:
				var direction := right*cos(i*TAU/9)+up*sin(i*TAU/9)
				var distance := size*(0.16+after*0.9)
				if key in ["ember", "watergun"]:
					_ball(to+direction*distance-up*after*after*0.4,0.055*fade,edge)
				else:
					_line(to+direction*distance,to+direction*(distance+size*0.25*fade),0.025*fade,core)
	for i in range(cursor,pieces.size()): pieces[i].visible = false

func _draw_source_move(_from: Vector3, _to: Vector3, _right: Vector3, _up: Vector3) -> bool:
	return false
