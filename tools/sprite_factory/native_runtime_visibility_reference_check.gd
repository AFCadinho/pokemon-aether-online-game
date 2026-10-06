extends "res://tools/sprite_factory/native_paired_reference_check.gd"
## Compare the actual client visibility contract on independent source/candidate actors.
## Renderer, meshes, textures, skeletons and zero-tolerance comparisons are unchanged.
const Visibility = preload("res://scripts/battle/animations/reviewed_source_visibility.gd")
func prepare_actor(actor: Node3D,entry: Dictionary,candidate: bool) -> void:
	preload("res://scripts/battle/battle_ui/material_surface_order.gd").apply(actor)
	var digest: String=entry.candidate_sha256 if candidate else entry.source_sha256
	if Visibility.matches(entry.identity,digest):
		assert(Visibility.apply(actor,entry.identity,digest))
	report["material_surface_order_contract_sha256"]=FileAccess.get_sha256("res://scripts/battle/battle_ui/material_surface_order.gd")
	report["material_response_contract_sha256"]=FileAccess.get_sha256("res://scripts/battle/battle_ui/material_response.gd")
	report["runtime_visibility_contract_sha256"]=FileAccess.get_sha256("res://resources/battle/model_visibility/roaring_moon.json")
