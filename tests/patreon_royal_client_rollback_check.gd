extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(OVERLAY_SCENE_PATH) as PackedScene
	_check(packed != null, "Trainer Card overlay loads")
	if packed == null:
		quit(1)
		return
	var overlay = packed.instantiate()
	var preview := {
		"top": "AetherRoyal_Shirt",
		"bottom": "AetherRoyal_Trousers",
		"legs": "AetherRoyal_Trousers",
		"cape": "AetherRoyal_Cape",
		"shoes": "Shoes",
	}
	var restored: Dictionary = overlay.call("_appearance_with_rejected_royal_parts_restored", preview, {
		"top": "Shirt", "bottom": "Trousers", "cape": null,
	})
	_check(restored.get("top") == "Shirt" and restored.get("bottom") == "Trousers"
		and restored.get("legs") == "Trousers", "rejected Royal clothing returns to saved parts")
	_check(restored.get("cape") == "__none__", "rejected Royal cape is removed locally")
	_check(restored.get("shoes") == "Shoes", "unrelated outfit choices stay in the preview")
	_check(preview.get("top") == "AetherRoyal_Shirt", "rollback leaves the original request intact")
	var auth := root.get_node("AuthService")
	var save := root.get_node("PlayerSave")
	var previous_user: Dictionary = auth.current_user.duplicate(true)
	var previous_appearance: Dictionary = save.to_appearance_state()
	auth.current_user = {"roles": []}
	save.apply_appearance_state({"top": "Shirt"})
	overlay.call("_on_trainer_card_part_selected", "top", "AetherRoyal_Shirt")
	_check(save.appearance_top_id == "Shirt", "Royal selection without the role does not change the local avatar")
	_check(overlay.get("trainer_card_appearance_message_key") == "backend.error.patreon_role_required",
		"Royal selection explains the role requirement in the Trainer Card")
	var saved_with_empty_cape: Dictionary = save.to_appearance_state()
	saved_with_empty_cape["cape"] = null
	_check(overlay.call("_save_response_matches_current_appearance", {"appearance": saved_with_empty_cape}),
		"server null and local unequipped parts compare as the same appearance")
	save.apply_appearance_state(previous_appearance)
	auth.current_user = previous_user
	overlay.free()
	print("Patreon Royal client rollback checks: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error("FAIL " + label)
