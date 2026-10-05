extends "res://tests/run_project_checks.gd"

func _init() -> void:
	if OS.get_name() != "Linux":
		print("SKIP Linux project-check watchdog")
		quit(0)
		return
	log_dir = OS.get_environment("POKEAETHER_TEST_LOG_DIR")
	if log_dir.is_empty():
		log_dir = DEFAULT_LOG_DIR
	DirAccess.make_dir_recursive_absolute(log_dir)
	var executable := OS.get_executable_path()
	var project_path := ProjectSettings.globalize_path("res://")
	_run_check(executable, project_path, "res://tests/fixtures/project_check_hang.gd", 1, false)
	var timed_out := failed and failed_count == 1 and passed_count == 0
	failed = false
	failed_count = 0
	_run_check(executable, project_path, "res://tests/fixtures/project_check_script_error.gd", 10, false)
	var rejected_script_error := failed and failed_count == 1 and passed_count == 0
	failed = false
	failed_count = 0
	_run_check(executable, project_path, "res://tests/fixtures/project_check_success.gd", 10)
	var resumed := not failed and failed_count == 0 and passed_count == 1
	if timed_out and rejected_script_error and resumed:
		print("PASS hung checks are bounded, script errors fail, and subsequent checks run")
		quit(0)
	else:
		push_error("Watchdog regression: timeout=%s script_error=%s resume=%s" % [timed_out, rejected_script_error, resumed])
		quit(1)
