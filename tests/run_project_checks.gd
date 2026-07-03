extends SceneTree

const CHECK_SCRIPTS: Array[String] = [
	"res://tests/battle_display_data_presenter_check.gd",
	"res://tests/battle_event_text_formatter_check.gd",
	"res://tests/battle_state_primal_forms_check.gd",
	"res://tests/pokemon_ball_metadata_check.gd",
	"res://tests/pokemon_cry_resolver_check.gd",
	"res://tests/pokemon_experience_payload_check.gd",
	"res://tests/pokemon_factory_hp_snapshot_check.gd",
	"res://tests/pvp_ranked_banlists_check.gd",
	"res://tests/pvp_ranked_team_validation_check.gd",
	"res://tests/map_encounter_provider_check.gd",
	"res://tests/pallet_town_encounter_check.gd",
	"res://tests/tmx_visual_importer_check.gd",
	"res://tests/social_service_contract_check.gd",
]

const LOG_DIR := "/tmp/pokeaether_project_checks"

var failed := false


func _init() -> void:
	var log_error := DirAccess.make_dir_recursive_absolute(LOG_DIR)
	if log_error != OK:
		push_error("Failed to create check log directory: %s" % LOG_DIR)
		quit(1)
		return

	var executable := OS.get_executable_path()
	var project_path := ProjectSettings.globalize_path("res://")

	print("Running %d project checks..." % CHECK_SCRIPTS.size())
	for script_path in CHECK_SCRIPTS:
		_run_check(executable, project_path, script_path)

	quit(1 if failed else 0)


func _run_check(executable: String, project_path: String, script_path: String) -> void:
	var output: Array = []
	var log_file := "%s/%s.log" % [LOG_DIR, _script_log_name(script_path)]
	var exit_code := OS.execute(
		executable,
		PackedStringArray([
			"--no-header",
			"--headless",
			"--log-file",
			log_file,
			"--path",
			project_path,
			"--script",
			script_path,
		]),
		output,
		true
	)

	if exit_code == 0:
		print("PASS %s" % script_path)
		return

	failed = true
	push_error(
		"FAIL %s exit_code=%d log=%s\n%s" % [script_path, exit_code, log_file, _format_output(output)]
	)


func _format_output(output: Array) -> String:
	var parts: Array[String] = []
	for item in output:
		parts.append(str(item))
	return "\n".join(parts)


func _script_log_name(script_path: String) -> String:
	return script_path.replace("res://", "").replace("/", "_").replace(".", "_")
