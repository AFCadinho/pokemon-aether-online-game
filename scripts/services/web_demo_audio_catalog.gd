extends RefCounted

## Legacy compatibility shim. Browser music uses the external HTMLAudio bridge.
## Do not add music preloads here: all_resources exports otherwise bundle them.

const STREAMS := {}


static func get_stream(path: String) -> AudioStream:
	return STREAMS.get(path, null) as AudioStream
