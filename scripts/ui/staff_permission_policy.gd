extends RefCounted

const OWNER_ONLY_PERMISSION_IDS: Array[String] = [
	"owner:tools",
	"battles:live:view",
	"server:access:manage",
	"diagnostics:view",
]


static func fixed_role_grants_permission(
	role_ids: Array[String],
	normalized_permission: String
) -> bool:
	return (
		role_ids.has("owner")
		or (
			role_ids.has("senior_staff")
			and normalized_permission not in OWNER_ONLY_PERMISSION_IDS
		)
	)
