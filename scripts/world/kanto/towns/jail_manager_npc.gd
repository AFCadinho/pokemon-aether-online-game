@tool
extends DialogueNPC

class_name JailManagerNPC

const JailBailDialogScript := preload("res://scripts/ui/jail_bail_dialog.gd")


func interact_with_player(_player: Node2D) -> void:
	var result: Dictionary = await ThievingService.load_bailable_detainees()
	if not bool(result.get("success", false)):
		await GameErrorDialogService.show_response(result, "backend.error.jail_load")
		return
	await show_dialogue([
		"I manage the Viridian City jail. Trainers caught thieving may be released when their bail is paid.",
		"You may pay for yourself or help another trainer. Staff detentions cannot be paid off here.",
	], display_name)
	var dialog := JailBailDialogScript.new() as JailBailDialog
	get_tree().current_scene.add_child(dialog)
	dialog.open_with_detainees(result.get("detainees", []) as Array)
	await dialog.closed
