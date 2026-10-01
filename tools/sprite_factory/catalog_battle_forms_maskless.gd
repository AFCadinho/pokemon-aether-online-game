extends "res://tools/sprite_factory/catalog_dlc_runtime_review.gd"
## Diagnostic instances only. Packed scenes retain their real masks.
func _sample(model: Node, player: AnimationPlayer, action: String, fraction: float) -> AABB:
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if str(mesh.name) in ["pm1120_12_00_body_b_mesh", "pm1120_13_00_body_b_mesh", "pm1120_14_00_body_b_mesh"]:
			mesh.visible = false
	return await super._sample(model, player, action, fraction)
