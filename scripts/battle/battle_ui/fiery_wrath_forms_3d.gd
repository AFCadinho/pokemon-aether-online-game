extends RefCounted
## A curved wall of dark fire, with a continuous silhouette and native clock.
var flame: ArrayMesh
var material: ShaderMaterial

func _init() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [-1.0, 1.0]:
		for row in 8:
			for column in 48:
				for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
					var u: float = (column + corner.x) / 48.0
					var v: float = (row + corner.y) / 8.0
					var x := (u - 0.5) * 2.0
					var crown := (1.2 + 1.3 * sin(u * PI)) * (0.75 + 0.25 * sin(u * 17.0 * PI + sin(u * 9.0)))
					tool.set_uv(Vector2(u,v))
					tool.add_vertex(Vector3(x * 2.5, v * crown, x * x * 0.55 + v * v * 0.5 + face * 0.12 * sin(v * PI)))
	tool.generate_normals()
	flame = tool.commit()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform float seconds = 0.0;
uniform float opacity = 1.0;
void vertex() {
 VERTEX.x += sin(seconds*7.0 + UV.x*24.0) * UV.y*UV.y*0.18;
 VERTEX.y += sin(seconds*9.0 + UV.x*31.0) * UV.y*UV.y*0.16;
 VERTEX.z += sin(seconds*6.0 + UV.x*18.0) * UV.y*UV.y*0.2;
}
void fragment() {
 float flow = 0.5 + 0.5 * sin(UV.x * 56.0 + sin(UV.y * 9.0 - seconds * 7.0) * 2.5 - UV.y * 14.0 + seconds * 5.0);
 float vein = pow(flow, 3.0);
 vec3 color = mix(vec3(0.035,0.002,0.025), vec3(0.8,0.008,0.11), vein);
 color = mix(color, vec3(1.0,0.13,0.035), pow(flow,12.0) * UV.y);
 ALBEDO = color;
 EMISSION = color * (0.5 + vein);
 ALPHA = opacity * (1.0 - smoothstep(0.87,1.0,UV.y)) * smoothstep(0.0,0.04,UV.y);
}
"""
	material = ShaderMaterial.new()
	material.shader = shader

func draw(effect: Node) -> void:
	material.set_shader_parameter("seconds", effect.elapsed / effect.duration * float(effect.recipe.duration_seconds))
	material.set_shader_parameter("opacity", effect.envelope)
	var forward: Vector3 = effect.ground - effect.actor_ground
	forward.y = 0
	if forward.is_zero_approx(): forward = Vector3.FORWARD
	forward = forward.normalized()
	var basis := Basis(forward.cross(Vector3.UP),Vector3.UP,-forward)
	if effect.flight < 0:
		var charge := smoothstep(0.0,effect.launch,effect.elapsed)
		for i in 3:
			var angle := i * TAU / 3.0
			var point: Vector3 = effect.actor_ground + Vector3(cos(angle),0,sin(angle)) * 0.6
			effect._piece(flame,material,point,Vector3(0.3,0.55,0.35)*charge,Basis(Vector3.UP,angle))
		return
	var progress := clampf(effect.flight,0,1)
	var fade := 1.0 - smoothstep(0.0,0.75,effect.after)
	var point: Vector3 = effect.actor_ground.lerp(effect.ground,progress)
	effect._piece(flame,material,point,Vector3(0.55+progress*0.65,0.7+progress*0.5,1.0)*fade,basis)
	# One lower following crest makes the advancing wave thick rather than flat.
	effect._piece(flame,material,point-forward*0.65,Vector3(0.5+progress*0.5,0.5,0.7)*fade,basis)
	if effect.impact_drawn:
		for i in 2:
			var radius: float = (0.6+effect.after*(3.5+i))*fade
			effect._piece(effect.ring,effect.edge,effect.ground+Vector3.UP*(0.08+i*0.15),Vector3(radius,0.35,radius))
