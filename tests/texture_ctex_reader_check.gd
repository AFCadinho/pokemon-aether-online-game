extends SceneTree
const Reader = preload("res://tools/sprite_factory/texture_ctex_reader.gd")
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size()==2 and DisplayServer.get_name()=="headless")
	assert(ProjectSettings.load_resource_pack(args[0],false))
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	assert(rows.size()==42)
	for row: Dictionary in rows:
		var path := "res://"+str(row.path)
		var custom := Reader.read(path)
		var native: Image = load(path).get_image()
		assert(custom != null and native != null)
		assert(custom.get_format()==native.get_format())
		assert(custom.get_size()==native.get_size())
		assert(custom.get_mipmap_count()==native.get_mipmap_count())
		assert(custom.get_data()==native.get_data(),"CTEX reader must match Godot's independent headless loader byte-for-byte")
	print("TEXTURE_CTEX_READER_OK exact format, dimensions, all mip bytes for 42 CTEX files")
	quit()
