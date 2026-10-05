extends "res://scripts/battle/battle_ui/source_move_effect_3d.gd"
## Bubble uses loose globes; Bubble Beam uses a dense, sustained jet.
## Both reuse inspected SV Bubble Beam artwork, with authored Godot motion.
const BUBBLE_SPRITES := {
	"bubble_pop": [preload("res://assets/battles/moves_3d/sv_bubbles/cpt_2_bubble0003.png"), Vector3(0.55,0.86,1), 8.0, true],
	"bubble_splash": [preload("res://assets/battles/moves_3d/sv_bubbles/cpt_2_water0009.png"), Vector3(0.4,0.78,1), 8.0, false],
}
var bubble_material: ShaderMaterial

func _sprite_values(id: String) -> Array:
	return BUBBLE_SPRITES[id] if BUBBLE_SPRITES.has(id) else super._sprite_values(id)

func _bubble(point: Vector3, size: float, fade: float) -> void:
	if bubble_material == null:
		var shader := Shader.new()
		shader.code = """
shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_never;
uniform sampler2D bubble_mask : filter_linear, repeat_enable;
uniform float opacity = 1.0;
void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.5);
	vec4 source = texture(bubble_mask, UV);
	float shine = source.r * source.a;
	ALBEDO = mix(vec3(0.12, 0.55, 0.83), vec3(0.84, 0.97, 1.0), max(rim, shine));
	ALPHA = (0.13 + rim * 0.65 + shine * 0.25) * opacity;
}
"""
		bubble_material = ShaderMaterial.new()
		bubble_material.shader = shader
		bubble_material.set_shader_parameter("bubble_mask", preload("res://assets/battles/moves_3d/sv_bubbles/cpt_0_bubble0202.png"))
	bubble_material.set_shader_parameter("opacity",fade)
	_piece(sphere,bubble_material,point,Vector3.ONE*size)

func _draw_source_move(from: Vector3, to: Vector3, right: Vector3, up: Vector3) -> bool:
	if key not in ["bubble","bubblebeam"]: return super._draw_source_move(from,to,right,up)
	var beam := key == "bubblebeam"
	var facing := Basis(right,up,right.cross(up))
	var travel := (elapsed-launch)/maxf(impact-launch,0.01)
	var after := (elapsed-impact)/maxf(duration*0.3,0.01)
	var fade := 1.0-clampf(after,0,1)
	if travel >= 0 and after < 1:
		for origin: Vector3 in emission_sources:
			var direction := (to-origin).normalized()
			var side := direction.cross(Vector3.UP if absf(direction.y)<0.95 else Vector3.RIGHT).normalized()
			var vertical := side.cross(direction).normalized()
			for i in (24 if beam else 9):
				var p := travel-float(i)*(0.045 if beam else 0.065)
				if p < 0: continue
				if beam:
					if after > 0.65: continue
					p = fmod(p,1.0)
				elif p > 1: continue
				var spread := sin(p*PI)*(0.12 if beam else 0.42)
				var point := origin.lerp(to,p) + side*sin(i*2.4+elapsed*3.0)*spread
				point += vertical*cos(i*1.7+elapsed*2.0)*spread
				if not beam: point.y += sin(p*PI)*0.24
				var size := (0.07 if beam else 0.12) + fmod(i*0.037,0.065)
				_bubble(point,size,fade)
	if hit and after >= 0 and after < 1:
		if beam: _source_sprite(to,0.95,"bubble_splash",after,fade*0.7,facing)
		for i in (6 if beam else 3):
			var angle := i*TAU/(6.0 if beam else 3.0)
			var offset := Vector3(cos(angle),sin(angle),sin(angle*2))*after*0.6
			_source_sprite(to+offset,0.7,"bubble_pop",0.25+after*0.75,fade,facing,angle)
	return true
