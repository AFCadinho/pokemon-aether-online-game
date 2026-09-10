extends RefCounted

## A killed tween never emits finished. Keep the original tween identity and
## bound its lifetime so cancellation cannot strand a battle coroutine.
static func for_tween(host: Node, tween: Tween, timeout_seconds := 8.0) -> bool:
	if not is_instance_valid(host) or not host.is_inside_tree() or tween == null:
		return false
	var tree := host.get_tree()
	var completion := {"done": false}
	var listener := func(): completion["done"] = true
	tween.finished.connect(listener, CONNECT_ONE_SHOT)
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while not completion["done"] and tween.is_valid() and is_instance_valid(host) and host.is_inside_tree():
		if Time.get_ticks_msec() >= deadline:
			tween.kill()
			break
		await tree.process_frame
	if tween.finished.is_connected(listener):
		tween.finished.disconnect(listener)
	return completion["done"]
