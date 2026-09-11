extends RefCounted

const WINDOW_USEC := 5000000
var frames: Array[Dictionary] = []
var pings: Array[int] = []
var last_ping_stamp := -1
var ping_band := -1


func reset_frames() -> void:
	frames.clear()


func reset_ping() -> void:
	pings.clear()
	last_ping_stamp = -1
	ping_band = -1


func record_frame(duration_usec: int, now_usec: int) -> void:
	if duration_usec > 0:
		frames.append({"at": now_usec, "duration": duration_usec})
	_expire_frames(now_usec)


func _expire_frames(now_usec: int) -> void:
	while not frames.is_empty() and now_usec - int(frames[0].at) >= WINDOW_USEC:
		frames.pop_front()


func frame_summary(now_usec: int) -> Dictionary:
	_expire_frames(now_usec)
	if frames.is_empty():
		return {}
	var total := 0
	var worst := 0
	for frame: Dictionary in frames:
		var duration := int(frame.duration)
		total += duration
		worst = maxi(worst, duration)
	return {"milliseconds": float(total) / frames.size() / 1000.0, "low_fps": 1000000.0 / worst}


func record_ping(milliseconds: int, stamp: int) -> void:
	if milliseconds < 0:
		reset_ping()
		return
	if stamp == last_ping_stamp:
		return
	last_ping_stamp = stamp
	pings.append(milliseconds)
	if pings.size() > 5:
		pings.pop_front()
	if pings.size() < 3:
		return
	var average := average_ping()
	# 100/200 ms bands with 10 ms hysteresis after the initial classification.
	if ping_band < 0:
		ping_band = 0 if average < 100 else (1 if average < 200 else 2)
	elif ping_band == 0 and average >= 110:
		ping_band = 2 if average >= 210 else 1
	elif ping_band == 1:
		if average < 90:
			ping_band = 0
		elif average >= 210:
			ping_band = 2
	elif ping_band == 2 and average < 190:
		ping_band = 0 if average < 90 else 1


func average_ping() -> float:
	if pings.is_empty():
		return -1.0
	var total := 0.0
	for ping: int in pings:
		total += ping
	return total / pings.size()
