extends "res://tests/guild_mount_lending_check.gd"


func _run() -> void:
	await _check_loan_kind("player")
	print("Direct mount lending checks: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)
