class_name HotbarShortcut
extends RefCounted


static func slot_index_from_event(event: InputEventKey) -> int:
	if (
		not event.pressed
		or event.echo
		or not event.ctrl_pressed
		or event.shift_pressed
		or event.alt_pressed
		or event.meta_pressed
	):
		return -1

	var keycode := event.physical_keycode
	if keycode == 0:
		keycode = event.keycode

	match keycode:
		KEY_1: return 0
		KEY_2: return 1
		KEY_3: return 2
		KEY_4: return 3
		KEY_5: return 4
		KEY_6: return 5
		KEY_7: return 6
		KEY_8: return 7
		_: return -1
