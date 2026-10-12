extends "catalog_dlc_runtime_review.gd"
func _run() -> void:
	auto_accept_quit = false
	process_frame.connect(func(): RenderingServer.force_draw(false))
	await super._run()
