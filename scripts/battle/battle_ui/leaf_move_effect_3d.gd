extends "res://scripts/battle/battle_ui/source_move_effect_3d.gd"
## Curved, tumbling 3D leaves with the SV leaf silhouette and impact atlas.
const LEAF_SPRITES := {
	"leaf_debris": [preload("res://assets/battles/moves_3d/sv_razorleaf/cpt_2_obj0006.png"), Vector3(0.5, 1.0, 0.22), 4.0, true],
	"leaf_hit": [preload("res://assets/battles/moves_3d/sv_razorleaf/cpt_2_shock0008.png"), Vector3(0.68, 1.0, 0.32), 4.0, false],
}
var leaf_mesh: ArrayMesh
var leaf_material: ShaderMaterial

func _sprite_values(id: String) -> Array:
	return LEAF_SPRITES[id] if LEAF_SPRITES.has(id) else super._sprite_values(id)

func _draw_source_move(from: Vector3, to: Vector3, right: Vector3, up: Vector3) -> bool:
	if leaf_mesh == null: _build_leaf()
	var facing := Basis(right, up, right.cross(up))
	var travel := (elapsed - launch) / maxf(impact - launch, 0.01)
	var after := (elapsed - impact) / maxf(duration * 0.22, 0.01)
	var forward := (to - from).normalized()
	var side := forward.cross(Vector3.UP).normalized()
	var vertical := side.cross(forward).normalized()
	# Fan paths live in world space: orbiting the camera never relocates a leaf.
	for i in 6:
		var t := (travel - float(i) * 0.035) / (1.0 - float(i) * 0.035)
		if t < 0 or t >= 1: continue
		var angle := float(i) * TAU / 6.0
		var fan := (side * cos(angle) * 0.65 + vertical * (0.25 + sin(angle) * 0.45)) * sin(t * PI)
		var point := from.lerp(to, t) + fan
		var orientation := Basis(side, vertical, side.cross(vertical)) * Basis(Vector3.FORWARD, angle + t * 9.0)
		orientation *= Basis(Vector3.RIGHT, 0.5 + sin(t * TAU + angle) * 0.65)
		var size := 0.48 + float(i % 3) * 0.045
		_piece(leaf_mesh, leaf_material, point, Vector3.ONE * size, orientation)
	if hit and after >= 0 and after < 1:
		_source_sprite(to, 1.3 + after * 0.5, "leaf_hit", after, (1.0 - after) * 0.85, facing)
		for i in 3:
			var angle := float(i) * TAU / 3.0
			var offset := (side * cos(angle) + vertical * sin(angle)) * after * 0.65
			_source_sprite(to + offset, 0.7, "leaf_debris", after, 1.0 - after, facing, angle)
	return true

func _build_leaf() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 8:
		for col in 4:
			for corner in [Vector2(0,0), Vector2(1,0), Vector2(1,1), Vector2(0,0), Vector2(1,1), Vector2(0,1)]:
				var uv := Vector2((col + corner.x) / 4.0, (row + corner.y) / 8.0)
				surface.set_uv(uv)
				surface.add_vertex(Vector3((uv.x - 0.5) * 0.6, 0.5 - uv.y,
					sin(uv.y * PI) * 0.12 + absf(uv.x - 0.5) * 0.14))
	surface.generate_normals()
	leaf_mesh = surface.commit()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D leaf_texture : source_color, filter_linear, repeat_disable;
void fragment() {
	vec4 leaf = texture(leaf_texture, UV);
	ALBEDO = mix(vec3(0.08, 0.28, 0.015), vec3(0.47, 0.95, 0.12), leaf.r);
	EMISSION = ALBEDO * 0.28;
	ROUGHNESS = 0.7;
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
}
"""
	leaf_material = ShaderMaterial.new()
	leaf_material.shader = shader
	leaf_material.set_shader_parameter("leaf_texture", preload("res://assets/battles/moves_3d/sv_razorleaf/cpt_0_obj0001.png"))
