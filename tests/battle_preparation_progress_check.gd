extends SceneTree
class SlowStage extends "res://scripts/battle/battle_ui/experimental_battle_3d.gd":
	var started := Time.get_ticks_msec()
	func _process(_delta: float) -> void:
		pass
	func _preparation_progress() -> Array:
		# Four observable loading steps, then a genuine stall.
		return [mini(4,int((Time.get_ticks_msec()-started)/50))]
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var settings = root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_catalog_path = "user://progress-fixture.json"
	var stage := SlowStage.new()
	root.add_child(stage)
	var started := Time.get_ticks_msec()
	await stage.await_prepared(true,100)
	var elapsed := Time.get_ticks_msec()-started
	assert(elapsed >= 270,"Active loading was cut off by the original total timeout")
	assert(elapsed < 1500 and stage.preparation_failed,"A genuine stall must remain bounded")
	assert(not stage.active and not stage.warming_render)
	stage.queue_free()
	await process_frame
	print("PREPARATION_PROGRESS_OK elapsed_ms=",elapsed)
	quit()
