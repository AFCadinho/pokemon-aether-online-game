extends RefCounted
## Explicit container revisions of unchanged reviewed rigs. This allows only
## the client animation correction, never catalog admission or future rigs.
const DATA = preload("res://resources/battle/model_animations/lossless_model_revisions.json")

static func matches(identity: String, digest: String, originals: Dictionary) -> bool:
	var original: String = originals.get(identity, "")
	if original.is_empty() or digest.is_empty():
		return false
	if digest == original:
		return true
	var revision: Dictionary = DATA.data.models.get(identity, {})
	return revision.get("source_sha256", "") == original and revision.get("sha256", "") == digest
