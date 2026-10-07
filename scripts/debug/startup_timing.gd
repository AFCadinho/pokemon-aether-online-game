extends RefCounted

# Opt-in in release clients as well. Log timings only, never account data.
static func record(stage: String, started_usec: int) -> void:
	if "--startup-timings" in OS.get_cmdline_user_args() or OS.get_environment("POKEAETHER_STARTUP_TIMINGS") == "1":
		print("STARTUP_TIMING phase=%s ms=%.3f" % [stage, (Time.get_ticks_usec() - started_usec) / 1000.0])
