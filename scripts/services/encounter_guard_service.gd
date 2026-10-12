extends Node

signal released
signal charge_changed

const ENDPOINT := "/game/encounter-guard"
const LOGIN_SCENE := "res://scenes/interface/login_screen.tscn"

# Kept in the autoload so switching battle/world overlays does not lose the offer.
var renewal_pending := false
var renewal_revision := 0
var guard: Dictionary = {}
var session_token := ""
var polling := false
var submitting := false
var elapsed := 2.0
var deadline_msec := 0
var retry_msec := 0
var challenge_id := ""
var layer: CanvasLayer
var backdrop: ColorRect
var prompt: Label
var reference: TextureRect
var countdown: Label
var feedback: Label
var grid: GridContainer
var previously_paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = CanvasLayer.new()
	layer.layer = 2000
	add_child(layer)
	backdrop = ColorRect.new()
	backdrop.color = Color(0.025, 0.035, 0.065, 0.94)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(backdrop)
	backdrop.hide()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(390, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var title := Label.new()
	title.text = "Encounter Guard"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	prompt = Label.new()
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(prompt)
	reference = TextureRect.new()
	reference.custom_minimum_size = Vector2(96, 96)
	reference.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reference.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reference.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(reference)
	grid = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(feedback)
	countdown = Label.new()
	countdown.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(countdown)


func _process(delta: float) -> void:
	if session_token != AuthService.session_token:
		session_token = AuthService.session_token
		guard = {}
		_reset_renewal()
		_hide_lock()
		charge_changed.emit()
		elapsed = 2.0
	if not AuthService.is_authenticated():
		return
	if backdrop.visible and bool(guard.get("locked", false)):
		var seconds := maxi(0, ceili(float(deadline_msec - Time.get_ticks_msec()) / 1000.0))
		countdown.text = LocalizationManager.text("ui.encounter_guard.timer", {"seconds": seconds})
		for button: Button in grid.get_children():
			button.disabled = seconds == 0 or submitting or Time.get_ticks_msec() < retry_msec
		# The server decides whether a last-second submission arrived in time.
		# Continue polling at zero; do not discard a pending accepted answer.
	elapsed += delta
	if elapsed >= 2.0 and not polling and not submitting:
		elapsed = 0.0
		_refresh()


func _input(event: InputEvent) -> void:
	# Pausing the game also blocks gameplay's polling of held input. GUI clicks
	# still reach this always-processing overlay; gameplay keybindings do not.
	if backdrop.visible and not (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag):
		get_viewport().set_input_as_handled()


func ensure_unlocked(value: Variant) -> bool:
	if not value is Dictionary:
		return true
	var expected_token := AuthService.session_token
	if value is Dictionary:
		apply_state(value)
	while bool(guard.get("locked", false)) and AuthService.is_authenticated() and AuthService.session_token == expected_token:
		await released
	return AuthService.is_authenticated() and AuthService.session_token == expected_token


func apply_state(value: Dictionary) -> void:
	if session_token != AuthService.session_token:
		session_token = AuthService.session_token
		guard = {}
		_reset_renewal()
		_hide_lock()
	if float(value.get("serverTime", 0)) < float(guard.get("serverTime", 0)):
		return
	if bool(guard.get("locked", false)) and not bool(value.get("locked", false)) and str(value.get("battleId", "")).is_empty():
		# Timeout cleanup removes the active binding. An accepted unlock keeps
		# its battle ID, so a missed realtime logout cannot resume this battle.
		_logout()
		return
	var was_active := bool(guard.get("active", false)) and int(guard.get("remaining", 0)) > 0
	var is_active := bool(value.get("active", false)) and int(value.get("remaining", 0)) > 0
	if is_active and not was_active:
		_reset_renewal()
	elif not is_active and not bool(value.get("expired", false)) and (
		was_active or (bool(value.get("locked", false)) and not bool(guard.get("locked", false)))
	):
		renewal_revision += 1
		renewal_pending = true
	guard = value.duplicate(true)
	charge_changed.emit()
	if bool(guard.get("expired", false)):
		_logout()
	elif bool(guard.get("locked", false)):
		_show_lock()
	elif bool(guard.get("waitingForPartner", false)):
		_show_partner_wait()
	else:
		_hide_lock()


func dismiss_renewal(revision: int) -> void:
	if revision == renewal_revision:
		renewal_pending = false


func _reset_renewal() -> void:
	renewal_revision += 1
	renewal_pending = false


func _show_lock() -> void:
	if not backdrop.visible:
		previously_paused = get_tree().paused
		get_tree().paused = true
		backdrop.show()
	grid.show()
	reference.show()
	var remaining_seconds := maxf(0, float(guard.get("expiresAt", 0)) - float(guard.get("serverTime", Time.get_unix_time_from_system())))
	deadline_msec = Time.get_ticks_msec() + int(remaining_seconds * 1000)
	retry_msec = Time.get_ticks_msec() + int(maxf(0, float(guard.get("retryAt", 0)) - float(guard.get("serverTime", 0))) * 1000)
	var challenge: Dictionary = guard.get("challenge", {})
	var next_id := str(challenge.get("id", ""))
	if next_id == challenge_id:
		return
	challenge_id = next_id
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	prompt.text = LocalizationManager.text("ui.encounter_guard.prompt")
	feedback.text = ""
	reference.texture = null
	var example := Image.new()
	if example.load_png_from_buffer(Marshalls.base64_to_raw(str(challenge.get("referenceImage", "")))) == OK:
		reference.texture = ImageTexture.create_from_image(example)
	for option: Dictionary in challenge.get("options", []):
		var image := Image.new()
		if image.load_png_from_buffer(Marshalls.base64_to_raw(str(option.get("image", "")))) != OK:
			continue
		var button := Button.new()
		button.icon = ImageTexture.create_from_image(image)
		button.custom_minimum_size = Vector2(112, 112)
		button.add_theme_constant_override("icon_max_width", 88)
		button.expand_icon = true
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = Time.get_ticks_msec() < retry_msec
		button.set_meta("option_id", str(option.get("id", "")))
		button.pressed.connect(_choose.bind(str(option.get("id", "")), button))
		grid.add_child(button)


func _show_partner_wait() -> void:
	if not backdrop.visible:
		previously_paused = get_tree().paused
		get_tree().paused = true
		backdrop.show()
	challenge_id = ""
	grid.hide()
	reference.hide()
	prompt.text = LocalizationManager.text("ui.encounter_guard.partner")
	feedback.text = ""
	countdown.text = ""


func _choose(option_id: String, button: Button) -> void:
	if submitting or Time.get_ticks_msec() < retry_msec or Time.get_ticks_msec() >= deadline_msec:
		return
	button.disabled = true
	submitting = true
	var result := await _request(HTTPClient.METHOD_POST, "/unlock", {
		"battleId": guard.get("battleId", ""), "challengeId": challenge_id, "choices": [option_id]})
	submitting = false
	if bool(result.get("success", false)):
		var was_locked := bool(guard.get("locked", false))
		apply_state(result.get("encounterGuard", {}))
		if was_locked and bool(guard.get("locked", false)):
			feedback.text = LocalizationManager.text("ui.encounter_guard.wrong")
	else:
		# Do not permit client-side dismissal after an ambiguous result. Reload
		# the authoritative challenge, including whether the answer succeeded.
		feedback.text = LocalizationManager.text("ui.encounter_guard.retry")
		challenge_id = ""
		await _refresh()


func _hide_lock() -> void:
	if backdrop != null and backdrop.visible:
		backdrop.hide()
		get_tree().paused = previously_paused
	challenge_id = ""
	released.emit()


func _logout() -> void:
	guard = {}
	_reset_renewal()
	AuthService.set_pending_login_notice(LocalizationManager.text("ui.encounter_guard.expired"))
	AuthService.clear_session()
	charge_changed.emit()
	_hide_lock()
	get_tree().paused = false
	get_tree().change_scene_to_file(LOGIN_SCENE)


func _refresh() -> void:
	polling = true
	var result := await _request(HTTPClient.METHOD_GET)
	polling = false
	if bool(result.get("success", false)):
		apply_state(result.get("encounterGuard", {}))


func _request(method: HTTPClient.Method, suffix := "", body: Dictionary = {}) -> Dictionary:
	var sent_token := AuthService.session_token
	var base_url: String = await GatewayApiConfig.get_base_url()
	var request := HTTPRequest.new()
	request.timeout = 8.0
	add_child(request)
	var error := request.request(base_url + ENDPOINT + suffix, GatewayApiConfig.get_json_headers(), method, JSON.stringify(body) if method != HTTPClient.METHOD_GET else "")
	if error != OK:
		request.queue_free()
		return {"success": false}
	var response: Array = await request.request_completed
	request.queue_free()
	if sent_token != AuthService.session_token or int(response[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"success": false}
	var status := int(response[1])
	if status == 401 and backdrop.visible:
		_logout()
	if status < 200 or status >= 300:
		return {"success": false}
	var parsed: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	return parsed as Dictionary if parsed is Dictionary else {"success": false}
