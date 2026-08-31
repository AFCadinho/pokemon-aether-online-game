extends SceneTree

const TRAINER_AVATAR_PREVIEW_SCRIPT := preload("res://scripts/ui/trainer_avatar_preview.gd")

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var host := Control.new()
	root.add_child(host)
	var preview := TRAINER_AVATAR_PREVIEW_SCRIPT.new() as TrainerAvatarPreview
	preview.size = Vector2(46, 46)
	preview.set_trainer_state({
		"gender": "female",
		"appearance": {
			"body": "Gen4_Base_F_v1",
			"hair": "Aether_Blossom_Hair",
			"top": "Aether_Blossom_Dress",
			"hair_color": "#6b4632",
			"skin_tone": "#f8d0b8",
		},
	}, "AL")
	host.add_child(preview)
	await process_frame
	await process_frame

	_check(preview.portrait != null and preview.portrait.visible, "equipped appearance uses the sprite portrait")
	_check(preview.fallback_label != null and not preview.fallback_label.visible, "initials stay hidden when appearance is available")
	_check(
		preview.portrait != null
		and preview.portrait.avatar != null
		and str(preview.portrait.appearance_state.get("gender", "")) == "female",
		"trainer gender reaches the shared portrait renderer"
	)

	preview.set_trainer_state({}, "AL")
	await process_frame
	_check(not preview.portrait.visible, "missing appearance does not render an invented portrait")
	_check(preview.fallback_label.visible and preview.fallback_label.text == "AL", "missing appearance keeps a readable initials fallback")

	host.queue_free()
	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
