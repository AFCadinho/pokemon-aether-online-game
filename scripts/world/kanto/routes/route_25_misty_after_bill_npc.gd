extends DialogueNPC

class_name Route25MistyAfterBillNPC


func _ready() -> void:
	dialogue_lines = [
		_text("ui.world.route_25.misty_after_bill.asked_about_dadinho"),
		_text("ui.world.route_25.misty_after_bill.bill_ticket"),
		_text("ui.world.route_25.misty_after_bill.vermilion_guidance"),
	]
	super._ready()


func _text(key: String) -> String:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager == null:
		return key
	return str(localization_manager.call("text", key))
