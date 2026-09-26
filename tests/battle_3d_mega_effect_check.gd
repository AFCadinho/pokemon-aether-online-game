extends SceneTree

const Effect = preload("res://scripts/battle/battle_ui/mega_evolution_effect_3d.gd")

class MockPresenter extends Node:
	var active := true
	var calls := 0
	func play_mega_evolution(_ident: String, reveal: Callable) -> bool:
		calls += 1
		reveal.call()
		return true

var reveals := 0
var finishes := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var effect := Effect.new()
	root.add_child(effect)
	effect.start(1.0)
	effect.set_process(false)
	effect.reveal_requested.connect(func(): reveals += 1)
	effect.finished.connect(func(): finishes += 1)
	effect._process(1.34)
	assert(reveals == 0 and finishes == 0)
	effect._process(0.02)
	assert(reveals == 1 and effect.revealed)
	effect._process(4.0)
	assert(reveals == 1 and finishes == 1)
	await process_frame

	var cancelled := Effect.new()
	root.add_child(cancelled)
	cancelled.start(1.0)
	cancelled.set_process(false)
	cancelled.reveal_requested.connect(func(): reveals += 1)
	cancelled.finished.connect(func(): finishes += 1)
	cancelled.cancel()
	cancelled._process(10.0)
	assert(reveals == 1 and finishes == 2)
	await process_frame

	var presenter := MockPresenter.new()
	root.add_child(presenter)
	var router = load("res://scripts/battle/battle_animation_router.gd").new()
	router.model_presenter = presenter
	var settings := root.get_node("SettingsManager")
	var old_animations: bool = settings.battle_animations
	settings.battle_animations = true
	await router.play_effect_animation("mega_evolution", "p1a: Dragonite", func(): reveals += 1)
	assert(presenter.calls == 1 and reveals == 2)
	settings.battle_animations = old_animations
	presenter.queue_free()
	print("BATTLE_3D_MEGA_EFFECT_OK")
	quit()
