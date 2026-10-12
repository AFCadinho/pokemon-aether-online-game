extends "catalog_galar_birds_battle_review.gd"
## Reuse native-clock grounding and hover checks for the Therian cohort.
func _run() -> void:
	auto_accept_quit = false
	await super._run()
