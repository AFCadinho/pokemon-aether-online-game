extends RefCounted
## Diagnostic CPU reader for pinned Godot 4.6 CTEX v1 payloads. No GPU fallback.
## Container layout: Godot scene/resources/compressed_texture.{cpp,h}, 4.6-stable.
## This is intentionally not a general runtime texture loader.
static func read(path: String) -> Image:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length()<52:
		return null
	if file.get_buffer(4).get_string_from_ascii()!="GST2" or file.get_32()!=1:
		return null
	file.seek(36)
	var encoding := file.get_32()
	var width := file.get_16()
	var height := file.get_16()
	var mipmaps := file.get_32()
	var format := file.get_32()
	# This probe accepts only the audited 1024-square, full-mipmap candidates.
	if width!=1024 or height!=1024 or mipmaps!=10:
		return null
	var data := PackedByteArray()
	if encoding==0: # Raw Image data, including GPU-compressed blocks.
		data = file.get_buffer(file.get_length()-file.get_position())
	elif encoding in [1,2]: # PNG/WebP independently encode each mip level.
		for level in mipmaps+1:
			var size := file.get_32()
			if size<=0 or size>file.get_length()-file.get_position():
				return null
			var bytes := file.get_buffer(size)
			var image := Image.new()
			var error := image.load_png_from_buffer(bytes) if encoding==1 else image.load_webp_from_buffer(bytes)
			if error!=OK or image.is_compressed() or image.get_width()!=maxi(1,width>>level) or image.get_height()!=maxi(1,height>>level):
				return null
			image.convert(format)
			data.append_array(image.get_data())
	else:
		return null
	if file.get_position()!=file.get_length():
		return null
	file.close()
	return Image.create_from_data(width,height,true,format,data)
