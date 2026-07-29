@tool
extends DialogueNPC

class_name AetherAtelierNPC

@export var opening_dialogue_lines: Array[String] = [
	"Welcome to the Aether Atelier!",
	"Bring me every loose piece of an outfit and I can carefully pack it back into a tradeable box.",
]


func interact_with_player(_player: Node2D) -> void:
	var metadata_response: Dictionary = await _load_npc_metadata()
	if not bool(metadata_response.get("success", false)):
		await show_dialogue([
			"My outfit records are unavailable right now.",
			"Please try again in a moment.",
		])
		return
	var lines := dialogue_lines if not dialogue_lines.is_empty() else opening_dialogue_lines
	await show_dialogue(lines)
	var ui_overlay := (
		get_tree().current_scene.get_node_or_null("UIOverlay")
		if get_tree().current_scene != null
		else null
	)
	if ui_overlay != null and ui_overlay.has_method("open_aether_atelier"):
		ui_overlay.call("open_aether_atelier")
		return
	await show_dialogue(["The Atelier counter is unavailable right now."])
