extends RefCounted
## In-process prepared resource LRU, never a scene/node pool or disk cache.
## Source bytes are an admission limit, not a claim about decoded RAM/VRAM.
const MAX_ENTRIES := 2
const MAX_SOURCE_BYTES := 67108864
static var items := {}
static var order: Array[String] = []
static var source_bytes := 0

static func key(path: String, hash: String, timing: Dictionary) -> String:
	return path + ":" + hash + ":" + JSON.stringify(timing, "", true).sha256_text()

static func fetch(cache_key: String) -> PackedScene:
	if not items.has(cache_key):
		return null
	order.erase(cache_key)
	order.append(cache_key)
	return items[cache_key].scene

static func retain(cache_key: String, scene: PackedScene, bytes: int) -> void:
	if scene == null or bytes <= 0 or bytes > MAX_SOURCE_BYTES:
		return
	_remove(cache_key)
	while not order.is_empty() and (order.size() >= MAX_ENTRIES or source_bytes + bytes > MAX_SOURCE_BYTES):
		_remove(order[0])
	items[cache_key] = {"scene": scene, "bytes": bytes}
	order.append(cache_key)
	source_bytes += bytes

static func _remove(cache_key: String) -> void:
	if items.has(cache_key):
		source_bytes -= int(items[cache_key].bytes)
		items.erase(cache_key)
	order.erase(cache_key)

static func clear() -> void:
	items.clear()
	order.clear()
	source_bytes = 0
