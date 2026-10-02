extends "res://tests/catalog_batch_01_candidate_stress_check.gd"
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
func _run() -> void:
	var directory := OS.get_environment("POKEAETHER_FORM_BUNDLE_WORK")
	assert(directory.is_absolute_path())
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("runtime-fixture.json")))
	Registry.DATA.data.models.merge(fixture.models, true)
	Registry.DATA.data.profiles.merge(fixture.profiles, true)
	await super._run()
	var output := OS.get_environment("POKEAETHER_BATCH01_STRESS_OUTPUT")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output))
	report["steady_frame_p95_ms"] = {}
	for arena in steady_samples:
		var samples: Array = steady_samples[arena]
		samples.sort()
		report.steady_frame_p95_ms[arena] = {"samples": samples.size(), "p95_ms": samples[int(samples.size() * .95)]}
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()

var steady_samples: Dictionary = {}
var observe_steady := false

func _sample_frame() -> void:
	super._sample_frame()
	if observe_steady and sample and not frame_samples.is_empty():
		var arena: String = root.get_node("SettingsManager").battle_3d_arena
		if not steady_samples.has(arena):
			steady_samples[arena] = []
		steady_samples[arena].append(frame_samples[-1])

func _ready_pair(species: String, left_shiny: bool, right_shiny: bool) -> void:
	await super._ready_pair(species, left_shiny, right_shiny)
	# Four pairs use the same prepared observation interval as the Kyurem gate.
	# Observe two seconds of the real arena after preparation, with the same gate.
	context = "steady " + species
	observe_steady = true
	await _frames(120)
	observe_steady = false
