extends SceneTree

const OAKS_PARCEL_ICON := preload("res://assets/items/icons/OAKSPARCEL.png")


func _init() -> void:
	var failures := 0
	if OAKS_PARCEL_ICON == null:
		failures += 1
		push_error("FAIL Oak's Parcel icon loads")
	if OAKS_PARCEL_ICON != null and OAKS_PARCEL_ICON.get_size() != Vector2(48, 48):
		failures += 1
		push_error("FAIL Oak's Parcel icon is 48x48")
	var icon_image := Image.load_from_file("res://assets/items/icons/OAKSPARCEL.png")
	if icon_image == null or icon_image.get_pixel(0, 0).a >= 1.0:
		failures += 1
		push_error("FAIL Oak's Parcel icon has transparency")
	if failures == 0:
		print("PASS Oak's Parcel has a dedicated transparent 48x48 item icon")
	quit(1 if failures > 0 else 0)
