extends SceneTree
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 1)
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	for row: Dictionary in records:
		var packer := PCKPacker.new()
		assert(packer.pck_start(row.output) == OK)
		for file: Dictionary in row.files:
			assert(packer.add_file(file.virtual_path, file.source_path) == OK)
		assert(packer.flush() == OK)
		print("MODEL_PAIR_PACK_OK ", row.output)
	quit()
