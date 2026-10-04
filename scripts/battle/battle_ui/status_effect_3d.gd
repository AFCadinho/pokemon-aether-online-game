extends "res://scripts/battle/battle_ui/common_battle_effect_3d.gd"
## Persistent, silent status presentation. Every overlay belongs to one actor.

const TINT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;
uniform vec4 tint : source_color;
uniform float strength = 0.0;
uniform sampler2D mask_texture : hint_default_white;
void fragment() {
	ALBEDO = tint.rgb;
	ALPHA = strength * texture(mask_texture, UV).a;
}
"""
var actor: Node3D
var cycle := 0.0
var overlays: Dictionary = {}
var tint_materials: Array[ShaderMaterial] = []

func attach_model(target: Node3D) -> void:
	actor = target
	var shader := Shader.new()
	shader.code = TINT_SHADER
	var meshes := target.find_children("*", "MeshInstance3D", true, false)
	if target is MeshInstance3D:
		meshes.append(target)
	for mesh: MeshInstance3D in meshes:
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("tint", Color(str(PROFILES[key][1])))
		var surface := mesh.get_active_material(0) if mesh.mesh != null and mesh.mesh.get_surface_count() > 0 else null
		if surface is StandardMaterial3D and surface.albedo_texture != null:
			material.set_shader_parameter("mask_texture", surface.albedo_texture)
		material.next_pass = mesh.material_overlay
		overlays[mesh] = [mesh.material_overlay, material]
		mesh.material_overlay = material
		tint_materials.append(material)

func _process(delta: float) -> void:
	if done:
		return
	if not is_instance_valid(actor) or (valid.is_valid() and not bool(valid.call())):
		cancel()
		return
	var speed := maxf(float(speed_provider.call()), 0.0) if speed_provider.is_valid() else 1.0
	cycle += maxf(delta,0.0) * speed
	# A quiet tint persists between short particle pulses; no repeated audio.
	elapsed = minf(fmod(cycle, 2.4), duration)
	_update_visuals()
	var strength := 0.13 + 0.16 * (0.5 + 0.5 * sin(cycle * TAU * 0.65))
	if key == "status_badly_poisoned": strength *= 1.35
	if key == "status_sleeping": strength *= 0.45
	for material: ShaderMaterial in tint_materials:
		material.set_shader_parameter("strength", strength)

func _restore_materials() -> void:
	for mesh: MeshInstance3D in overlays:
		if not is_instance_valid(mesh): continue
		if mesh.material_overlay == overlays[mesh][1]:
			mesh.material_overlay = overlays[mesh][0]
		else:
			var material := mesh.material_overlay
			while material != null:
				if material.next_pass == overlays[mesh][1]:
					material.next_pass = overlays[mesh][0]
					break
				material = material.next_pass
	overlays.clear()
	tint_materials.clear()

func cancel() -> void:
	_restore_materials()
	super.cancel()

func _exit_tree() -> void:
	_restore_materials()
	super._exit_tree()
