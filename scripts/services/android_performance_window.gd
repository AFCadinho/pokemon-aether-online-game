extends RefCounted
## Constant-size foreground frame histogram. Values are engine frame intervals,
## not Android presentation timestamps or direct GPU timings.
const BOUNDS_MS := [8, 12, 17, 25, 34, 50, 100, 250, 1000, 600000]
var histogram: Array[int] = []
var count := 0
var total_usec := 0
var maximum_usec := 0
var over_budget := 0
var over_50 := 0
var over_100 := 0

func _init() -> void:
	histogram.resize(BOUNDS_MS.size())
	histogram.fill(0)

func record(usec: int, target_fps: int) -> void:
	if usec <= 0:
		return
	# Bound pathological clock intervals without losing long foreground stalls.
	usec = mini(usec, 600000000)
	count += 1
	total_usec += usec
	maximum_usec = maxi(maximum_usec, usec)
	# Zero means uncapped on desktop: there is no selected frame budget.
	if target_fps > 0:
		over_budget += int(usec > 1500000.0 / target_fps)
	over_50 += int(usec > 50000)
	over_100 += int(usec > 100000)
	for index in BOUNDS_MS.size():
		if usec <= BOUNDS_MS[index] * 1000:
			histogram[index] += 1
			break

func summary() -> Dictionary:
	if count == 0:
		return {}
	return {"frameCount": count, "durationMs": total_usec / 1000.0,
		"maxFrameMs": maximum_usec / 1000.0, "histogram": histogram.duplicate(),
		"overBudgetFrames": over_budget, "over50MsFrames": over_50, "over100MsFrames": over_100}
