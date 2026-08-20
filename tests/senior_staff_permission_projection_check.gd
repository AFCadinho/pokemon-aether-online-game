extends SceneTree

const STAFF_PERMISSION_POLICY := preload("res://scripts/ui/staff_permission_policy.gd")

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var senior_staff_roles: Array[String] = ["senior_staff"]
	_check(
		STAFF_PERMISSION_POLICY.fixed_role_grants_permission(senior_staff_roles, "generating"),
		"Senior Staff retain item-generation access with a stale permission projection"
	)
	_check(
		STAFF_PERMISSION_POLICY.fixed_role_grants_permission(
			senior_staff_roles,
			"future:non-owner-tool"
		),
		"Senior Staff inherit future non-owner controls from their fixed role"
	)
	for permission: String in STAFF_PERMISSION_POLICY.OWNER_ONLY_PERMISSION_IDS:
		_check(
			not STAFF_PERMISSION_POLICY.fixed_role_grants_permission(
				senior_staff_roles,
				permission
			),
			"Senior Staff do not inherit owner-only permission %s" % permission
		)

	var moderator_roles: Array[String] = ["moderator"]
	_check(
		not STAFF_PERMISSION_POLICY.fixed_role_grants_permission(moderator_roles, "generating"),
		"other staff roles do not inherit item-generation access"
	)

	var owner_roles: Array[String] = ["owner"]
	for permission: String in STAFF_PERMISSION_POLICY.OWNER_ONLY_PERMISSION_IDS:
		_check(
			STAFF_PERMISSION_POLICY.fixed_role_grants_permission(owner_roles, permission),
			"Owner retains fixed permission %s" % permission
		)

	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return
	failures += 1
	push_error("FAIL %s" % message)
