extends RefCounted

# Application ping/pong round-trip time, including server processing.
const STALE_AFTER_MSEC := 15000
const PENDING_TIMEOUT_MSEC := 12000
var sent_at := -1
var received_at := -1
var round_trip_msec := -1


func reset() -> void:
	sent_at = -1
	received_at = -1
	round_trip_msec = -1


func sent(now: int) -> void:
	# Keep the original timestamp: the protocol does not carry ping IDs.
	if sent_at < 0:
		sent_at = now


func received(now: int) -> void:
	if sent_at < 0:
		return
	round_trip_msec = now - sent_at
	received_at = now
	if round_trip_msec >= PENDING_TIMEOUT_MSEC:
		round_trip_msec = -1
	sent_at = -1


func sample(now: int) -> int:
	if received_at < 0 or now - received_at >= STALE_AFTER_MSEC:
		return -1
	if sent_at >= 0 and now - sent_at >= PENDING_TIMEOUT_MSEC:
		return -1
	return round_trip_msec
