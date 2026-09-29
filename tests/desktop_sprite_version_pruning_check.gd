extends SceneTree

const DiskCache := preload("res://scripts/services/desktop_sprite_disk_cache.gd")


func _init() -> void:
	var root_path := "user://sprite-pruning-check-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root_path))
	var legacy := root_path.path_join("0".repeat(64) + ".cache")
	var legacy_file := FileAccess.open(legacy, FileAccess.WRITE)
	legacy_file.store_8(1)
	legacy_file.close()
	var cache := DiskCache.new(root_path)
	var first_meta := "https://example.com/pokemon-front-oldversion123/pikachu/animation.json"
	var first_sheet := "https://example.com/pokemon-front-oldversion123/pikachu/sheet.png"
	var next_meta := "https://example.com/pokemon-front-newversion123/pikachu/animation.json"
	var next_sheet := "https://example.com/pokemon-front-newversion123/pikachu/sheet.png"
	var final_meta := "https://example.com/pokemon-front-finalversion1/pikachu/animation.json"
	var final_sheet := "https://example.com/pokemon-front-finalversion1/pikachu/sheet.png"
	assert(cache.write(first_meta, PackedByteArray([1])))
	assert(not FileAccess.file_exists(legacy), "Legacy anonymous cache should be cleared once")
	assert(cache.write(first_sheet, PackedByteArray([2])))
	assert(cache.commit("animated/front/pikachu", first_meta, first_sheet))
	assert(cache.write(next_meta, PackedByteArray([3])))
	assert(not cache.commit("animated/front/pikachu", next_meta, next_sheet))
	assert(FileAccess.file_exists(cache.file_for_url(first_meta)), "Keep old pair until replacement is complete")
	assert(cache.write(next_sheet, PackedByteArray([4])))
	assert(cache.commit("animated/front/pikachu", next_meta, next_sheet))
	assert(not FileAccess.file_exists(cache.file_for_url(first_meta)))
	assert(not FileAccess.file_exists(cache.file_for_url(first_sheet)))
	assert(cache.read(next_sheet) == PackedByteArray([4]))
	assert(cache.commit("animated/front/pikachu-alias", next_meta, next_sheet))
	assert(cache.write(final_meta, PackedByteArray([5])))
	assert(cache.write(final_sheet, PackedByteArray([6])))
	assert(cache.commit("animated/front/pikachu", final_meta, final_sheet))
	assert(FileAccess.file_exists(cache.file_for_url(next_sheet)), "Keep files used by another identity")
	assert(cache.commit("animated/front/pikachu-alias", final_meta, final_sheet))
	assert(not FileAccess.file_exists(cache.file_for_url(next_meta)))
	assert(not FileAccess.file_exists(cache.file_for_url(next_sheet)))
	var index_path := root_path.path_join("index.json")
	var backup_file := FileAccess.open(root_path.path_join("index.previous.json"), FileAccess.WRITE)
	backup_file.store_buffer(FileAccess.get_file_as_bytes(index_path))
	backup_file.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(index_path))
	var orphan_url := "https://example.com/orphan/sheet.png"
	assert(cache.write(orphan_url, PackedByteArray([7])))
	var reopened := DiskCache.new(root_path)
	assert(reopened.read(final_sheet) == PackedByteArray([6]))
	assert(FileAccess.file_exists(index_path), "Recover an interrupted index replacement")
	assert(not FileAccess.file_exists(reopened.file_for_url(orphan_url)), "Restart should prune unfinished downloads")
	assert(reopened.clear())
	assert(reopened.bytes_used() == 0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(root_path))
	print("DESKTOP_SPRITE_VERSION_PRUNING_OK")
	quit()
