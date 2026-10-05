extends "res://scripts/battle/battle_ui/source_move_effect_3d.gd"
## Flamethrower: SV flame masks and noise on a sustained, mouth-anchored stream.
const FIRE_SPRITES := {
	"flame_stream": [preload("res://assets/battles/moves_3d/sv_flamethrower/cpt_2_fire0007s.png"), Vector3.ONE, 8.0, false],
	"flame_muzzle": [preload("res://assets/battles/moves_3d/sv_flamethrower/cpt_2_fire0005.png"), Vector3.ONE, 8.0, false],
	"flame_hit": [preload("res://assets/battles/moves_3d/sv_flamethrower/cpt_2_fire0005.png"), Vector3.ONE, 8.0, false],
	"flame_sparks": [preload("res://assets/battles/moves_3d/sv_flamethrower/cpt_2_fire0008.png"), Vector3(1,0.45,0.04), 4.0, false],
}
var fire_shader: Shader
var stream_material: ShaderMaterial
var flame_cone := CylinderMesh.new()
var emission_end := 0.0

func start(move: String, timing: Dictionary, options: Dictionary, native_clock: Callable, positions: Callable, guard: Callable) -> void:
	emission_end = float(timing.get("emission_end_frame",float(timing.impact_frame)+float(timing.frames)*0.224))/60.0
	super.start(move,timing,options,native_clock,positions,guard)

func _sprite_values(id: String) -> Array:
	return FIRE_SPRITES[id] if FIRE_SPRITES.has(id) else super._sprite_values(id)

func _fire_puff(point: Vector3, size: float, id: String, phase: float, alpha: float, facing: Basis, rotation_value := 0.0) -> void:
	if fire_shader == null:
		fire_shader = Shader.new()
		fire_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform sampler2D source_mask : filter_linear, repeat_disable;
uniform sampler2D flow_mask : filter_linear, repeat_enable;
uniform float frames = 8.0;
uniform float frame_index = 0.0;
uniform float opacity = 1.0;
uniform float seconds = 0.0;
void fragment() {
	vec2 uv = vec2((UV.x + floor(frame_index)) / frames, UV.y);
	float mask = texture(source_mask, uv).r;
	float flow = texture(flow_mask, UV * 1.7 + vec2(0.0, seconds * 2.0)).r;
	ALBEDO = mix(vec3(1.0, 0.12, 0.015), vec3(1.0, 0.87, 0.32), smoothstep(0.2, 0.8, flow));
	ALPHA = mask * smoothstep(0.1, 0.65, flow) * opacity;
}
"""
	if not sprite_templates.has(id):
		var template := ShaderMaterial.new()
		template.shader = fire_shader
		template.set_shader_parameter("source_mask", FIRE_SPRITES[id][0])
		template.set_shader_parameter("frames", FIRE_SPRITES[id][2])
		template.set_shader_parameter("flow_mask", preload("res://assets/battles/moves_3d/sv_flamethrower/cpt_3_flow0703s.png"))
		sprite_templates[id] = template
	var previous := cursor
	_source_sprite(point, size, id, phase, alpha, facing, rotation_value)
	if cursor > previous: sprite_materials[previous].set_shader_parameter("seconds", elapsed)

func _draw_source_move(from: Vector3, to: Vector3, right: Vector3, up: Vector3) -> bool:
	if key != "flamethrower": return super._draw_source_move(from,to,right,up)
	var facing := Basis(right,up,right.cross(up))
	var travel := (elapsed-launch) / maxf(impact-launch,0.01)
	var after := (elapsed-impact) / maxf(duration*0.28,0.01)
	if travel >= 0 and elapsed < emission_end:
		# Stop the stream before the native head returns from the breath pose.
		var fade := 1.0-clampf((elapsed-impact)/maxf(emission_end-impact,0.01),0,1)
		for origin: Vector3 in emission_sources:
			var direction := (to-origin).normalized()
			var side := direction.cross(Vector3.UP if absf(direction.y)<0.95 else Vector3.RIGHT).normalized()
			var vertical := side.cross(direction).normalized()
			_fire_core(origin,origin.lerp(to,clampf(travel,0,1)),fade)
			_fire_puff(origin,0.6,"flame_muzzle",fmod(elapsed*2.5,0.75),fade,facing)
			for i in 18:
				var p := (float(i)+fmod(elapsed*8.0,1.0))/18.0
				if p > minf(travel,1.0): continue
				var point := origin.lerp(to,p)
				point += (side*sin(i*2.4+elapsed*9.0)+vertical*cos(i*1.7+elapsed*7.0))*p*0.14
				_fire_puff(point,0.34+p*0.65,"flame_stream",fmod(elapsed*1.8+i*0.13,1.0),fade*0.68,facing, sin(i*2.3)*0.6)
	if hit and after >= 0 and after < 1:
		_fire_puff(to,1.2+after*0.5,"flame_hit",after,1.0-after,facing)
		for i in 5:
			var angle := i*TAU/5.0
			var offset := Vector3(cos(angle),sin(angle),sin(angle*2))*after*0.65
			_source_sprite(to+offset,0.75,"flame_sparks",after,1.0-after,facing,angle)
	return true

func _fire_core(from: Vector3, to: Vector3, fade: float) -> void:
	var delta := to-from
	if delta.length_squared()<0.0001: return
	if stream_material == null:
		flame_cone.height = 1.0
		flame_cone.top_radius = 1.0
		flame_cone.bottom_radius = 0.25
		flame_cone.radial_segments = 12
		var shader := Shader.new()
		shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform sampler2D flow_mask : filter_linear, repeat_enable;
uniform float seconds = 0.0;
uniform float opacity = 1.0;
void fragment() {
	float flow = texture(flow_mask, vec2(UV.x * 2.0 + seconds * 0.3, UV.y * 5.0 + seconds * 5.0)).r;
	ALBEDO = mix(vec3(1.0, 0.13, 0.005), vec3(1.0, 0.75, 0.12), flow);
	ALPHA = (0.25 + flow * 0.5) * opacity;
}
"""
		stream_material = ShaderMaterial.new()
		stream_material.shader = shader
		stream_material.set_shader_parameter("flow_mask",preload("res://assets/battles/moves_3d/sv_flamethrower/cpt_3_flow0703s.png"))
	stream_material.set_shader_parameter("seconds",elapsed)
	stream_material.set_shader_parameter("opacity",fade)
	var y := delta.normalized()
	var x := y.cross(Vector3.UP if absf(y.y)<0.95 else Vector3.RIGHT).normalized()
	_piece(flame_cone,stream_material,(from+to)*0.5,Vector3(0.22,delta.length(),0.22),Basis(x,y,x.cross(y)))
