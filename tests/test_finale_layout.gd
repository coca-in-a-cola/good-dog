extends Node
## Production finale in real viewport sizes, including shaped glyph ink extents.
var failures: Array[String] = []
var assertions := 0
var views: Array[SubViewport] = []
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures.append(message)
		print("FINALE_CHECK_FAIL ", message)
func before_each() -> void:
	failures.clear()
	assertions = 0
	GameState.clock.manual = true
func after_each() -> void:
	for view in views:
		view.queue_free()
	views.clear()
	GameState.clock.manual = false
	await get_tree().process_frame
func test_production_credits_shaped_glyphs_safe_and_centered() -> void:
	for dimensions in [Vector2i(1920,1080), Vector2i(720,1280), Vector2i(2560,1080)]:
		var view := SubViewport.new()
		view.size = dimensions
		views.append(view)
		add_child(view)
		var finale = load("res://scenes/finale.tscn").instantiate()
		view.add_child(finale)
		finale.stage = 1
		finale.elapsed = 2.2
		var key := InputEventKey.new()
		key.keycode = KEY_K
		key.pressed = true
		finale._unhandled_input(key)
		await get_tree().process_frame
		var label: Label = finale.label
		check(finale.stage == 2 and label.text == finale.CREDITS_TEXT, "production credits and original notices retained")
		check(finale.background.size == Vector2(dimensions), "opaque background covers viewport")
		check((label.position + label.size / 2 - Vector2(dimensions)/2).length() < 1, "group centered in viewport")
		check(label.position.x >= 24 and label.position.y >= 24, "safe margins")
		var fg := label.get_theme_color("font_color").srgb_to_linear()
		var bg: Color = finale.background.color.srgb_to_linear()
		var lum_fg := fg.r*0.2126+fg.g*0.7152+fg.b*0.0722
		var lum_bg := bg.r*0.2126+bg.g*0.7152+bg.b*0.0722
		check((lum_bg+0.05)/(lum_fg+0.05) >= 7, "text/background contrast at least 7:1")
		var paragraph := TextParagraph.new()
		paragraph.width = label.size.x
		paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		paragraph.add_string(label.text, label.get_theme_font("font"), label.get_theme_font_size("font_size"))
		var ts := TextServerManager.get_primary_interface()
		check(paragraph.get_size().y <= label.size.y, "shaped text height fits safe rectangle")
		for line in paragraph.get_line_count():
			var rid := paragraph.get_line_rid(line)
			var width := paragraph.get_line_size(line).x
			var pen := (label.size.x-width)/2
			for glyph in ts.shaped_text_get_glyphs(rid):
				if glyph.font_rid.is_valid() and glyph.index != 0:
					var offset: Vector2 = ts.font_get_glyph_offset(glyph.font_rid, Vector2i(glyph.font_size,0), glyph.index)
					var ink: Vector2 = ts.font_get_glyph_size(glyph.font_rid, Vector2i(glyph.font_size,0), glyph.index)
					var left: float = pen + glyph.offset.x + offset.x
					check(left >= -1 and left + ink.x <= label.size.x + 1, "actual shaped glyph ink fits horizontally")
				pen += glyph.advance * glyph.repeat
		print("FINALE_LAYOUT_OK ",dimensions," font=",label.get_theme_font_size("font_size")," shaped_lines=",paragraph.get_line_count())
