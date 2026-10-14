@tool
extends DialogueNPC
class_name DaycareTrainerNPC

func interact_with_player(_player: Node2D) -> void:
	var response: Dictionary = await _load_npc_metadata()
	if not bool(response.get("success", false)):
		await show_dialogue([LocalizationManager.text("npc.error.try_again")])
		return
	await show_dialogue()
	var scene := get_tree().current_scene
	var overlay := scene.get_node_or_null("UIOverlay") if scene != null else null
	if overlay != null and overlay.has_method("open_daycare"):
		overlay.call("open_daycare")
	else:
		await show_dialogue([LocalizationManager.text("ui.daycare.unavailable")])
