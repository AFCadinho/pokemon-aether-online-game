extends SceneTree
const Audit = preload("res://tools/sprite_factory/model_texture_audit.gd")

func texture(color: Color, dimensions: Vector2i = Vector2i(8, 8), mipmaps: bool = true) -> ImageTexture:
	var image := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	if mipmaps:
		image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _init() -> void:
	assert(DisplayServer.get_name() == "headless")
	var identical_a := texture(Color(0.1, 0.2, 0.3, 0.4))
	var identical_b := texture(Color(0.1, 0.2, 0.3, 0.4))
	var shiny := texture(Color(0.9, 0.2, 0.3, 0.4))
	var alpha := texture(Color(0.1, 0.2, 0.3, 0.9))
	var size_changed := texture(Color(0.1, 0.2, 0.3, 0.4), Vector2i(4, 16))
	var no_mips := texture(Color(0.1, 0.2, 0.3, 0.4), Vector2i(8, 8), false)
	var named := texture(Color(0.1, 0.2, 0.3, 0.4))
	named.resource_name = "eye"
	var local := texture(Color(0.1, 0.2, 0.3, 0.4))
	local.resource_local_to_scene = true
	var metadata := texture(Color(0.1, 0.2, 0.3, 0.4))
	metadata.set_meta("purpose", "sleep")
	var resources := [identical_a, identical_a, identical_b, shiny, alpha, size_changed, no_mips, named, local, metadata]
	var audit := Audit.new()
	audit.inspect(resources)
	assert(audit.textures.size() == 9, "Already shared objects must not count twice")
	assert(int(audit.summary().strict_shareable_duplicate_bytes) == identical_b.get_image().get_data_size())
	var before := Audit.signature(resources)
	var optimized: Array = audit.share(resources)
	assert(Audit.signature(optimized) == before)
	assert(optimized[0] == optimized[1] and optimized[0] == optimized[2])
	for index in range(3, resources.size()):
		assert(optimized[index] == resources[index] and optimized[index] != optimized[0])
	assert(audit.replacements == 1)
	# Nested material-response endpoints and animation resources are retained.
	var model := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.name = "Body"
	mesh.mesh = BoxMesh.new()
	model.add_child(mesh)
	mesh.owner = model
	var material := StandardMaterial3D.new()
	material.albedo_texture = identical_a
	material.set_meta("pokeaether_material_response", {"schema": 1, "endpoint_0": identical_b, "endpoint_1": shiny, "specular": 0.2})
	mesh.material_override = material
	var animation := Animation.new()
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath("Body:visible"))
	animation.track_insert_key(track, 0.0, true)
	animation.track_insert_key(track, 0.5, false)
	var library := AnimationLibrary.new()
	library.add_animation("sleep", animation)
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	model.add_child(player)
	player.owner = model
	player.add_animation_library("", library)
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	model.free()
	var semantic := Audit.signature(scene)
	var scene_audit := Audit.new()
	scene_audit.share(scene)
	assert(scene_audit.replacements == 1 and Audit.signature(scene) == semantic)
	var file_path := "user://model-texture-sharing-fixture.scn"
	assert(ResourceSaver.save(scene, file_path, ResourceSaver.FLAG_COMPRESS) == OK)
	var restored := ResourceLoader.load(file_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	assert(restored != null and Audit.signature(restored) == semantic)
	# Mutating mip bytes, even below the visible base level, must change identity.
	var image := identical_a.get_image()
	var bytes := image.get_data()
	bytes[-1] = (bytes[-1] + 1) % 256
	var changed_mip := Image.create_from_data(image.get_width(), image.get_height(), true, image.get_format(), bytes)
	assert(Audit.image_signature(changed_mip) != Audit.image_signature(image))
	# The offline pool must not be integrated as a permanent runtime cache.
	var holder := Audit.new()
	var temporary := texture(Color.RED)
	var reference: WeakRef = weakref(temporary)
	holder.share(temporary)
	temporary = null
	assert(reference.get_ref() != null)
	holder = null
	assert(reference.get_ref() == null, "Diagnostic owner retained a texture after release")
	for repeat in 50:
		assert(Audit.signature(NodePath("root/eye:texture")) == Audit.signature(NodePath("root/eye:texture")))
	print("MODEL_TEXTURE_SHARING_CHECK_OK pixel/alpha/mip/dimension/metadata/name/local ownership")
	quit()
