extends SceneTree
## Direct texture allocations/readback, not a phone frame-rate benchmark.
const Reader = preload("res://tools/sprite_factory/texture_ctex_reader.gd")
const ORIGIN := "http://127.0.0.1:8799/"
const PREFIX := "user://android-texture-residency"
var report := {"schema":1,"suite":"android-texture-residency","cases":[]}
var failures: Array[String] = []
var rd: RenderingDevice
class ErrorSink extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			errors.append(code + " " + rationale)
var sink := ErrorSink.new()
func _init() -> void:
	_run.call_deferred()
func _check(ok: bool, reason: String) -> bool:
	if not ok:
		failures.append(reason)
		print("TEXTURE_RESIDENCY_FAIL ",reason)
	return ok
func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if _check(file != null,"Writable diagnostic report"):
		file.store_string(text)
		file.close()
func _hash(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()
func _fetch(name: String) -> PackedByteArray:
	var request := HTTPRequest.new()
	request.timeout = 45
	request.body_size_limit = 80*1024*1024
	root.add_child(request)
	if not _check(request.request(ORIGIN+name)==OK,"Start loopback fixture request"):
		request.queue_free()
		return PackedByteArray()
	var result: Array = await request.request_completed
	request.queue_free()
	return result[3] if _check(result[0]==HTTPRequest.RESULT_SUCCESS and result[1]==200,"Fixture HTTP "+name) else PackedByteArray()
func _fixture() -> Dictionary:
	var pins = JSON.parse_string((await _fetch("fixture.json")).get_string_from_utf8())
	var variant := FileAccess.get_file_as_string("user://android-arena-variant").strip_edges()
	if not _check(pins is Dictionary and variant in ["desktop-art","android-etc2-art"] and pins.has(variant),"Owned variant and pins"):
		return {}
	var pin: Dictionary = pins[variant]
	var path := "user://android-arena-forest.pck"
	var bytes := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	if bytes.size()!=int(pin.bytes) or _hash(bytes)!=pin.sha256:
		bytes = await _fetch(variant+"/forest.pck")
		if not _check(bytes.size()==int(pin.bytes) and _hash(bytes)==pin.sha256,"Exact candidate pack hash"):
			return {}
		var file := FileAccess.open(path,FileAccess.WRITE)
		if not _check(file != null,"Write fixture pack"):
			return {}
		file.store_buffer(bytes)
		file.close()
	if not _check(ProjectSettings.load_resource_pack(path,false),"Mount candidate"):
		return {}
	report.variant = variant
	report.pack_sha256 = pin.sha256
	return pin
func _format(image_format: int) -> int:
	match image_format:
		Image.FORMAT_DXT1: return RenderingDevice.DATA_FORMAT_BC1_RGB_UNORM_BLOCK
		Image.FORMAT_DXT3: return RenderingDevice.DATA_FORMAT_BC2_UNORM_BLOCK
		Image.FORMAT_DXT5: return RenderingDevice.DATA_FORMAT_BC3_UNORM_BLOCK
		Image.FORMAT_RGTC_R: return RenderingDevice.DATA_FORMAT_BC4_UNORM_BLOCK
		Image.FORMAT_RGTC_RG: return RenderingDevice.DATA_FORMAT_BC5_UNORM_BLOCK
		Image.FORMAT_ETC2_R11: return RenderingDevice.DATA_FORMAT_EAC_R11_UNORM_BLOCK
		Image.FORMAT_ETC2_RG11: return RenderingDevice.DATA_FORMAT_EAC_R11G11_UNORM_BLOCK
		Image.FORMAT_ETC2_RGB8: return RenderingDevice.DATA_FORMAT_ETC2_R8G8B8_UNORM_BLOCK
		Image.FORMAT_ETC2_RGBA8: return RenderingDevice.DATA_FORMAT_ETC2_R8G8B8A8_UNORM_BLOCK
		Image.FORMAT_RGBA8: return RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	return -1
func _memory() -> int:
	return rd.get_memory_usage(RenderingDevice.MEMORY_TEXTURES)
func _allocate(image: Image, format: int) -> Dictionary:
	var usage := RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT|RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT|RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	if not _check(rd.texture_is_format_supported_for_usage(format,usage),"Format supports upload/readback"):
		return {}
	var before := _memory()
	var spec := RDTextureFormat.new()
	spec.width = image.get_width()
	spec.height = image.get_height()
	spec.mipmaps = image.get_mipmap_count()+1
	spec.format = format
	spec.usage_bits = usage
	var bytes := image.get_data()
	var texture := rd.texture_create(spec,RDTextureView.new(),[bytes])
	if not _check(texture.is_valid(),"Allocate texture"):
		return {}
	rd.submit()
	rd.sync()
	var allocated := _memory()-before
	var actual := rd.texture_get_format(texture)
	var readback := rd.texture_get_data(texture,0)
	var exact := readback==bytes
	_check(exact,"Exact uploaded bytes read back, including all mips")
	var row := {"rd_format":actual.format,"mips":actual.mipmaps,"input_bytes":bytes.size(),
		"allocation_bytes":allocated,"roundtrip_exact":exact,"sha256":_hash(bytes),"readback_sha256":_hash(readback)}
	rd.free_rid(texture)
	rd.submit()
	rd.sync()
	row.released_delta_bytes = _memory()-before
	_check(int(row.released_delta_bytes)==0,"Local texture accounting returns to baseline")
	return row
func _image(path: String) -> Image:
	return Reader.read(path)
func _run() -> void:
	OS.add_logger(sink)
	var args := OS.get_cmdline_user_args()
	var pin := {}
	if OS.has_feature("android"):
		if not _check(OS.is_debug_build() and OS.has_feature("android_texture_residency"),"Tagged separate debug app only"):
			_finish()
			return
		pin = await _fixture()
	else:
		if not _check(args.size()==3,"Host probe needs pack, texture list and output"):
			_finish()
			return
		report.output = args[2]
		_check(ProjectSettings.load_resource_pack(args[0],false),"Mount host pack")
		pin = {"textures":JSON.parse_string(FileAccess.get_file_as_string(args[1]))}
	if pin.is_empty() or not _check(pin.get("textures") is Array and pin.textures.size()==42,"All 42 imported texture payloads required"):
		_finish()
		return
	report.renderer = RenderingServer.get_current_rendering_method()
	report.adapter = RenderingServer.get_video_adapter_name()
	report.frame_pacing = ProjectSettings.get_setting("display/window/frame_pacing/android/enable_frame_pacing",true)
	report.shader_cache = ProjectSettings.get_setting("rendering/shader_compiler/shader_cache/enabled",true)
	rd = RenderingServer.create_local_rendering_device()
	if not _check(rd != null,"Native Vulkan local rendering device"):
		_finish()
		return
	for item: Dictionary in pin.textures:
		var path := "res://"+str(item.path)
		if item.has("sha256") and not _check(_hash(FileAccess.get_file_as_bytes(path))==item.sha256,"Exact CTEX payload: "+path):
			break
		var image := _image(path)
		if not _check(image != null and image.get_width()==1024 and image.get_height()==1024 and image.get_mipmap_count()==10,"Original resolution/mips: "+path):
			break
		var format := _format(image.get_format())
		if not _check(format>=0,"Explicit format mapping: "+str(image.get_format())):
			break
		var row := {"path":item.path,"image_format":image.get_format(),"compressed":image.is_compressed()}
		var usage := RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT|RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT|RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
		row.supported = rd.texture_is_format_supported_for_usage(format,usage)
		if row.supported:
			row.encoded = _allocate(image,format)
		else:
			row.encoded = {"input_bytes":image.get_data_size(),"unsupported":true}
		var decoded: Image = image.duplicate()
		if decoded.is_compressed() and not _check(decoded.decompress()==OK,"CPU decoder succeeds"):
			break
		decoded.convert(Image.FORMAT_RGBA8)
		row.rgba_control = _allocate(decoded,RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM)
		report.cases.append(row)
		_write(PREFIX+"-phase",str(report.cases.size()))
		_write(str(report.get("output",PREFIX+"-details.json")),JSON.stringify(report,"\t"))
		print("TEXTURE_RESIDENCY_CASE ",report.cases.size()," format=",image.get_format()," supported=",row.supported)
		await process_frame
		if not failures.is_empty() or not sink.errors.is_empty():
			break
	_check(report.cases.size()==42,"Complete 42-texture inventory")
	_finish()
func _finish() -> void:
	if rd != null:
		rd.free()
		rd = null
	report.failures = failures
	report.engine_errors = sink.errors
	report.success = failures.is_empty() and sink.errors.is_empty()
	_write(str(report.get("output",PREFIX+"-details.json")),JSON.stringify(report,"\t"))
	print("TEXTURE_RESIDENCY_RESULT success=",report.success," cases=",report.cases.size())
	quit(0 if report.success else 1)
