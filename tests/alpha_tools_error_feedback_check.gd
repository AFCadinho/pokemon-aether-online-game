extends SceneTree

const Feedback := preload("res://scripts/services/alpha_tools_error_feedback.gd")

var failed := false


func _init() -> void:
	_check_backend_detail_is_shown()
	_check_safe_fallback_is_used()
	_check_alpha_team_command_uses_feedback_formatter()
	quit(1 if failed else 0)


func _check_backend_detail_is_shown() -> void:
	var message := Feedback.team_creation_failure(
		0,
		1,
		{"species": "Diancie Mega"},
		{
			"error": "Something went wrong. Please try again.",
			"body": {"detail": "Alpha Pokemon cannot be shiny"},
		}
	)
	_check_equal(
		message,
		"Created 0 Alpha Pokemon, then Pokemon 1 (Diancie Mega) failed: Alpha Pokemon cannot be shiny",
		"Alpha Tools exposes the actionable backend validation reason"
	)


func _check_safe_fallback_is_used() -> void:
	var message := Feedback.team_creation_failure(
		2,
		3,
		{"speciesId": "ogerpon"},
		{"error": "Request timed out"}
	)
	_check_equal(
		message,
		"Created 2 Alpha Pokemon, then Pokemon 3 (ogerpon) failed: Request timed out",
		"transport errors retain the existing player-facing fallback"
	)


func _check_alpha_team_command_uses_feedback_formatter() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	_check_equal(
		source.contains("ALPHA_TOOLS_ERROR_FEEDBACK.team_creation_failure("),
		true,
		"the Alpha team command uses the actionable failure formatter"
	)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
