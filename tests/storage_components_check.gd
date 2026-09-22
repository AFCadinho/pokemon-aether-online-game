extends SceneTree
const C = preload("res://tools/sprite_factory/storage_components.gd")

func _initialize() -> void:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	var a := ImageTexture.create_from_image(image)
	var b := ImageTexture.create_from_image(image.duplicate())
	assert(C.fingerprint(a) == C.fingerprint(b))
	image.set_pixel(0, 0, Color(1, 0, 0, 0.5))
	assert(C.fingerprint(a) != C.fingerprint(ImageTexture.create_from_image(image)), "Alpha is part of exact identity")
	image.fill(Color.RED)
	image.generate_mipmaps()
	assert(C.fingerprint(a) != C.fingerprint(ImageTexture.create_from_image(image)), "Mipmaps are part of identity")
	var animation := Animation.new()
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath("Mesh:visible"))
	animation.track_insert_key(track, 0.0, true)
	var copy: Animation = animation.duplicate()
	copy.resource_name = "Different label"
	assert(C.fingerprint(animation) == C.fingerprint(copy), "Resource label is not motion data")
	copy.length += 0.25
	assert(C.fingerprint(animation) != C.fingerprint(copy))
	copy = animation.duplicate()
	copy.track_set_key_value(track, 0, false)
	assert(C.fingerprint(animation) != C.fingerprint(copy), "Visibility keys must not merge")
	var skin := Skin.new()
	skin.add_bind(0, Transform3D.IDENTITY)
	var other_skin: Skin = skin.duplicate()
	other_skin.set_bind_bone(0, 1)
	assert(C.fingerprint(skin) != C.fingerprint(other_skin), "Bindings must not merge")
	var material := StandardMaterial3D.new()
	material.albedo_texture = a
	material.set_meta("pokeaether_material_response", {"endpoint_0": a, "endpoint_1": b, "specular": 0.5})
	var owned_a := {}
	var owned_b := {}
	var first := C.owned_material(material, owned_a)
	var second := C.owned_material(material, owned_b)
	assert(first != second and first.albedo_texture == second.albedo_texture)
	first.albedo_color = Color.BLUE
	assert(second.albedo_color == Color.WHITE and material.albedo_color == Color.WHITE)
	assert(first.get_meta("pokeaether_material_response").endpoint_0 == a)
	print("STORAGE_COMPONENTS_UNIT_OK exact pixels/mips, timing, visibility, bindings, instance materials")
	quit()
