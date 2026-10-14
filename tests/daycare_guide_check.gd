extends SceneTree

const ExternalLinks := preload("res://scripts/core/external_links.gd")
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	_check(ExternalLinks.DAYCARE_GUIDE_URL.begins_with("https://forums.pokeaether.com/t/") and not "PLACEHOLDER" in ExternalLinks.DAYCARE_GUIDE_URL, "Guide uses the published public topic")
	var localization := root.get_node("LocalizationManager")
	for resolution: Vector2i in [Vector2i(1280, 960), Vector2i(520, 700)]:
		var view := SubViewport.new()
		view.size = resolution
		root.add_child(view)
		for scene: String in ["daycare_popup", "aethering_popup", "nature_specialist_popup"]:
			for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
				localization.set_locale(locale)
				var panel = load("res://scenes/interface/" + scene + ".tscn").instantiate()
				view.add_child(panel)
				panel.show()
				for _frame in range(8):
					await process_frame
				var button: Button = panel.guide_button
				_check(button.is_visible_in_tree() and not button.disabled, scene + " always exposes the guide, including loading state")
				_check(button.text == localization.text("ui.daycare.forum_guide") and not button.tooltip_text.begins_with("ui."), scene + " guide label/tooltip translated: " + locale)
				_check(button.pressed.is_connected(ExternalLinks.open_daycare_guide), scene + " opens the shared guide handler")
				_check(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(button.get_global_rect()), scene + " guide fits " + str(resolution) + ": " + locale)
				if scene == "aethering_popup":
					_check(panel.title.size.y >= 20, "Aethering title stays visible")
				if scene == "nature_specialist_popup":
					_check(panel.title_label.size.y >= 20, "Nature title stays visible")
				panel.free()
		view.free()
	localization.set_locale("en")
	print("DAYCARE_GUIDE_CHECK_OK" if failures == 0 else "DAYCARE_GUIDE_CHECK_FAILED: " + str(failures))
	quit(0 if failures == 0 else 1)
