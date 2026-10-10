extends SceneTree

const CHINESE_FONT: Font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
const SYMBOL_FONT: Font = preload("res://assets/fonts/DejaVuSans.ttf")

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := root.get_node("LocalizationManager")
	var original_locale: String = manager.current_locale
	var label := Label.new()
	label.text = "大秦帝国 / 大秦帝國 Recruiting! 简體中文 ₽ ✦ →"
	root.add_child(label)
	var default_font: Font = manager.default_fallback_font
	# Returning to English also exercises fallback coverage after a locale switch.
	for locale: String in ["en", "nl", "pt_BR", "zh_CN", "en"]:
		manager.set_locale(locale)
		await process_frame
		var font := label.get_theme_font("font")
		_check(font != null, "%s label resolves a font" % locale)
		if font == null:
			continue
		for character: String in ["大", "秦", "帝", "国", "國", "简", "體", "中", "文"]:
			_check_glyph(font, character, CHINESE_FONT, locale)
		for character: String in ["₽", "✦", "→"]:
			_check_glyph(font, character, SYMBOL_FONT, locale)
		if locale != "zh_CN":
			_check(font == default_font, "%s preserves the original Latin UI font" % locale)
			_check_glyph(font, "A", default_font, locale)
	manager.set_locale(original_locale)
	label.free()
	if not failed:
		print("PASS multilingual_font_check: bundled Chinese and symbol glyphs in every UI locale")
	quit(1 if failed else 0)


func _check_glyph(font: Font, character: String, expected_font: Font, locale: String) -> void:
	var line := TextLine.new()
	line.add_string(character, font, 24)
	var glyphs := TextServerManager.get_primary_interface().shaped_text_get_glyphs(line.get_rid())
	_check(not glyphs.is_empty(), "%s shapes %s" % [locale, character])
	for glyph: Dictionary in glyphs:
		_check(int(glyph.get("index", 0)) != 0, "%s renders %s without a missing-glyph box" % [locale, character])
		_check(expected_font.get_rids().has(glyph.get("font_rid")), "%s uses the bundled font for %s" % [locale, character])


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("FAIL %s" % message)
