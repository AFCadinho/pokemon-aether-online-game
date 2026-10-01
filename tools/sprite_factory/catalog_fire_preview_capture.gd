extends "res://tools/sprite_factory/catalog_motion_review.gd"
## Freeze skeleton for fire-only sweep; deterministic source-mask loop timing.
func _pose(model: Node3D, player: AnimationPlayer, action: String, fraction: float) -> AABB:
	var fire_only := OS.get_environment("POKEAETHER_FIRE_ONLY_SWEEP") == "1"
	var box := await super._pose(model,player,action,0.5 if fire_only else fraction)
	for node in model.find_children("*","MeshInstance3D",true,false):
		for surface in node.mesh.get_surface_count():
			var material: Material = node.get_active_material(surface)
			if material is ShaderMaterial:
				material.set_shader_parameter("review_time",fraction*2.0)
	return box
