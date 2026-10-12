extends SceneTree

const Authoring := preload("res://tools/guild_room_template_authoring.gd")

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Authoring.FOLDER))
	for template: Dictionary in Authoring.templates():
		var scene := Authoring.build(template)
		var packed := PackedScene.new()
		var error := packed.pack(scene)
		if error == OK:
			error = ResourceSaver.save(packed, Authoring.FOLDER + str(template.id) + ".tscn")
		scene.free()
		if error != OK:
			push_error("Could not create room template scene: " + str(template.id))
			quit(1)
			return
	print("Created complete Guild room template authoring scenes.")
	quit(0)
