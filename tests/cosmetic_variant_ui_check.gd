extends SceneTree

const PARTS := {"top": "TeamRocket_Shirt", "bottom": "TeamRocket_Trousers", "shoes": "TeamRocket_Shoes", "headgear": "TeamRocket_Cap"}
const ITEMS := {"top": "team-rocket-shirt", "bottom": "team-rocket-trousers", "shoes": "team-rocket-shoes", "headgear": "team-rocket-cap"}
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var save := root.get_node("PlayerSave")
	var auth := root.get_node("AuthService")
	var localization := root.get_node("LocalizationManager")
	var previous_appearance: Dictionary = save.to_appearance_state()
	var previous_gender: String = save.gender
	var previous_name: String = save.player_name
	var previous_user: Dictionary = auth.current_user.duplicate(true)
	var previous_locale: String = localization.current_locale
	localization.set_locale("nl")
	var overlay = load("res://scenes/interface/ui_overlay.tscn").instantiate()
	root.add_child(overlay)
	var unlocks: Array = []
	for category: String in PARTS:
		unlocks.append({"slot": category, "appearanceId": PARTS[category], "sourceItemId": ITEMS[category]})
	for gender: String in ["female", "male"]:
		var appearance := PARTS.duplicate()
		appearance["body"] = "Gen4_Base_F_v1" if gender == "female" else "Gen4_Base_v1"
		overlay.call("_apply_trainer_service_result", {
			"user": {"gender": gender, "displayName": "Variant Test", "appearance": appearance},
			"appearanceUnlocks": unlocks, "appearanceSlotCounts": {"top": 1, "bottom": 1, "shoes": 1, "headgear": 1},
			"inventory": [],
		}, true)
		_check(save.gender == gender, "gender change reaches the local save")
		for category: String in PARTS:
			var actual: String = str(save.get("appearance_%s_id" % category))
			_check(actual == PARTS[category], "%s keeps the server's equipped %s" % [gender, category])
			_check(bool(overlay.call("_is_appearance_part_owned", category, actual)), "retained %s remains selectable" % category)
			_check(str(overlay.call("_appearance_source_item_for_part", category, actual)) == ITEMS[category], "returning %s targets its universal item" % category)
			_check(str(overlay.call("_format_appearance_option_name", category, actual)) == root.get_node("ItemLocalization").display_name(ITEMS[category]), "wardrobe and Bag use the same localized item name")
	var confirm: String = localization.text("ui.bag.gender.confirm_message", {"gender": "female"})
	_check(confirm.contains("blijven") and not confirm.contains("Alle cosmetica"), "confirmation explains retained adaptive cosmetics")
	overlay.queue_free()
	auth.apply_current_user(previous_user)
	save.gender = previous_gender
	save.player_name = previous_name
	save.apply_appearance_state(previous_appearance)
	localization.set_locale(previous_locale)
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failed = true
		push_error("FAIL %s" % label)
