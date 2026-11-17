extends Control
## FEEL-11 P1：7 格开场连环画，20–30 s。
##
## 只用原生 Control / 绘制：不引入新美术素材。旁白 + 角色气泡，画面优先。
## 任意键/鼠标下一格，ESC 跳过全部；自动 3.5 s 一格。
## 完成或跳过都只走一次：story_seen=true → 教学。

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const PANEL_TIME := 3.5
const PANELS := 7
const NARR := ["comic.1.narr", "", "comic.3.narr", "", "", "comic.6.narr", "comic.7.narr"]

var _panel := 0
var _t := 0.0
var _done := false
var _narr: Label
var _bubble: PanelContainer
var _bubble_label: Label
var _skip: Label
var _index: Label
var _root: Control
var _flash := 0.0
var _capture_mode := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Locale.language_changed.connect(_on_locale_changed)
	resized.connect(_layout)
	_layout()
	_set_panel(0)
	if "--capture" in OS.get_cmdline_user_args():
		_capture_mode = true
		_capture.call_deferred()


func _process(delta: float) -> void:
	if _done or _capture_mode:
		return
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	if _panel in [3, 4, 5]:
		queue_redraw()
	if _t >= PANEL_TIME:
		_advance()


func _input(event: InputEvent) -> void:
	if _done or _capture_mode:
		return
	var pressed := false
	var skip_all := false
	if event is InputEventKey and event.pressed and not event.echo:
		pressed = true
		skip_all = event.physical_keycode == KEY_ESCAPE
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if skip_all:
		_finish()
	else:
		_advance()


func _advance() -> void:
	if _panel >= PANELS - 1:
		_finish()
		return
	_panel += 1
	_t = 0.0
	_set_panel(_panel)


func _finish() -> void:
	if _done:
		return
	_done = true
	GameManager.story_seen = true
	GameManager.start_tutorial()


func _build() -> void:
	_root = Control.new()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_narr = UiTheme.make_label("", 24, Color(0.95, 0.97, 1.0))
	_narr.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_narr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_narr)
	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", _bubble_style())
	_root.add_child(_bubble)
	_bubble_label = UiTheme.make_label("", 22, Color(1.0, 0.94, 0.78))
	_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.add_child(_bubble_label)
	_skip = UiTheme.make_label("", 16, Color(0.75, 0.88, 0.96))
	_skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_root.add_child(_skip)
	_index = UiTheme.make_label("", 16, Color(0.7, 0.85, 0.95))
	_index.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_index)


func _bubble_style() -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(0.04, 0.1, 0.15, 0.92)
	b.border_color = Color(1.0, 0.82, 0.3, 0.7)
	b.set_border_width_all(2)
	b.set_corner_radius_all(16)
	b.content_margin_left = 18
	b.content_margin_right = 18
	b.content_margin_top = 10
	b.content_margin_bottom = 10
	return b


func _layout() -> void:
	var vp := size if size.x > 1.0 else get_viewport_rect().size
	var left := vp.x * 0.08
	_narr.position = Vector2(left, vp.y * 0.06)
	_narr.size = Vector2(vp.x * 0.84, 90)
	_bubble.position = Vector2(vp.x * 0.30, vp.y * 0.70)
	_bubble.size = Vector2(vp.x * 0.56, 110)
	_skip.position = Vector2(left, vp.y - 52)
	_skip.size = Vector2(vp.x * 0.5, 30)
	_index.position = Vector2(vp.x - 180, vp.y - 52)
	_index.size = Vector2(140, 30)
	queue_redraw()


func _set_panel(i: int) -> void:
	_panel = i
	_t = 0.0
	var nkey: String = NARR[i]
	_narr.visible = nkey != ""
	if nkey != "":
		_narr.text = Locale.t(nkey)
	var bubble_key := ""
	match i:
		0: bubble_key = "comic.1.rabbit"
		1: bubble_key = "comic.2.turtle"
		2: bubble_key = "comic.3.cousin"
		3: bubble_key = "comic.4.cousin"
		4: bubble_key = "comic.5.bros"
		5: bubble_key = "comic.6.rabbit"
		6: bubble_key = "comic.7.cousin"
	if bubble_key == "":
		_bubble.visible = false
	else:
		_bubble.visible = true
		_bubble_label.text = Locale.t(bubble_key)
	_skip.text = Locale.t("comic.skip_next")
	_index.text = "%d / %d" % [i + 1, PANELS]
	queue_redraw()


func _on_locale_changed(_c: String) -> void:
	_set_panel(_panel)


func _draw() -> void:
	var vp := size if size.x > 1.0 else get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.045, 0.07))
	var panel := Rect2(vp.x * 0.06, vp.y * 0.08, vp.x * 0.88, vp.y * 0.58)
	draw_rect(panel, Color(0.07, 0.13, 0.18))
	draw_rect(panel, Color(0.35, 0.72, 0.86, 0.55), false, 3.0)
	var cx := panel.position.x + panel.size.x * 0.5
	var cy := panel.position.y + panel.size.y * 0.5
	match _panel:
		0:
			_draw_track(panel)
			_draw_rabbit(panel.position + Vector2(panel.size.x * 0.25, panel.size.y * 0.62), 1.0, true)
			_draw_turtle(panel.position + Vector2(panel.size.x * 0.70, panel.size.y * 0.66), 1.0)
			draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 20, panel.position.y + 34),
				"ZZZ", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.75, 0.9, 1.0))
		1:
			_draw_track(panel)
			_draw_finish(panel)
			_draw_turtle(panel.position + Vector2(panel.size.x * 0.55, panel.size.y * 0.68), 0.9)
			_draw_rabbit(panel.position + Vector2(panel.size.x * 0.35, panel.size.y * 0.72), 0.9, true)
			draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + panel.size.x * 0.72,
				panel.position.y + 50), "2nd", HORIZONTAL_ALIGNMENT_LEFT, -1, 30,
				Color(1.0, 0.6, 0.45))
		2:
			_draw_sky(panel)
			_draw_cousin(panel.position + Vector2(panel.size.x * 0.5, panel.size.y * 0.62), 1.3)
		3:
			_draw_sky(panel)
			_draw_cousin(panel.position + Vector2(panel.size.x * 0.28, panel.size.y * 0.64), 1.0)
			_draw_cake(panel.position + Vector2(panel.size.x * 0.68, panel.size.y * 0.66), 1.2)
		4:
			_draw_sky(panel)
			_draw_rabbit(panel.position + Vector2(panel.size.x * 0.34, panel.size.y * 0.66), 1.0, false)
			_draw_turtle(panel.position + Vector2(panel.size.x * 0.66, panel.size.y * 0.68), 1.0)
			_draw_arcs(panel.position + Vector2(panel.size.x * 0.34, panel.size.y * 0.45),
				panel.position + Vector2(panel.size.x * 0.66, panel.size.y * 0.52), 5)
		5:
			_draw_sky(panel)
			_draw_rabbit(panel.position + Vector2(panel.size.x * 0.36, panel.size.y * 0.66), 1.0, false)
			_draw_turtle(panel.position + Vector2(panel.size.x * 0.64, panel.size.y * 0.68), 1.0)
			_draw_arcs(panel.position + Vector2(panel.size.x * 0.36, panel.size.y * 0.40),
				panel.position + Vector2(panel.size.x * 0.64, panel.size.y * 0.46), 7)
			for i in 2:
				draw_string(ThemeDB.fallback_font, Vector2(cx - 80 + i * 160, cy - 130),
					"?", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(1.0, 0.9, 0.45))
		6:
			_draw_track(panel)
			_draw_rabbit(panel.position + Vector2(panel.size.x * 0.30, panel.size.y * 0.66), 0.95, false)
			_draw_turtle(panel.position + Vector2(panel.size.x * 0.42, panel.size.y * 0.70), 0.95)
			_draw_cousin(panel.position + Vector2(panel.size.x * 0.76, panel.size.y * 0.64), 1.1)
			draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + panel.size.x * 0.70,
				panel.position.y + 70), "♪", HORIZONTAL_ALIGNMENT_LEFT, -1, 40,
				Color(1.0, 0.85, 0.35))
	# 页码点
	var n := PANELS
	for i in n:
		var p := Vector2(cx - (n - 1) * 9.0 + i * 18.0, panel.end.y + 26.0)
		draw_circle(p, 4.0, Color(1.0, 0.85, 0.35) if i <= _panel else Color(0.35, 0.55, 0.65))


func _draw_sky(panel: Rect2) -> void:
	draw_rect(panel, Color(0.32, 0.56, 0.68))
	draw_rect(Rect2(panel.position.x, panel.position.y + panel.size.y * 0.62,
		panel.size.x, panel.size.y * 0.38), Color(0.06, 0.28, 0.36))
	draw_line(Vector2(panel.position.x, panel.position.y + panel.size.y * 0.62),
		Vector2(panel.end.x, panel.position.y + panel.size.y * 0.62),
		Color(0.75, 0.95, 1.0, 0.7), 3.0)


func _draw_track(panel: Rect2) -> void:
	_draw_sky(panel)
	draw_rect(Rect2(panel.position.x, panel.position.y + panel.size.y * 0.80,
		panel.size.x, panel.size.y * 0.20), Color(0.62, 0.52, 0.34))
	for i in 8:
		var x := panel.position.x + panel.size.x * float(i) / 8.0
		draw_line(Vector2(x, panel.position.y + panel.size.y * 0.80),
			Vector2(x + 30, panel.position.y + panel.size.y * 0.80),
			Color(0.9, 0.8, 0.55, 0.5), 3.0)


func _draw_finish(panel: Rect2) -> void:
	var x := panel.position.x + panel.size.x * 0.86
	draw_line(Vector2(x, panel.position.y + 40), Vector2(x, panel.position.y + panel.size.y * 0.80),
		Color(1, 1, 1), 6.0)
	for i in 8:
		var y := panel.position.y + 40 + i * 16
		draw_rect(Rect2(x - 20, y, 20, 8), Color(0.9, 0.9, 0.9) if i % 2 == 0
			else Color(0.1, 0.1, 0.1))


func _draw_rabbit(p: Vector2, s: float, asleep: bool) -> void:
	var body := Color(0.93, 0.94, 0.9)
	var line := Color(0.1, 0.12, 0.14)
	draw_circle(p, 26 * s, body)
	draw_circle(p + Vector2(0, -34 * s), 22 * s, body)
	draw_line(p + Vector2(-13, -50) * s, p + Vector2(-18, -92) * s, body, 10 * s)
	draw_line(p + Vector2(8, -50) * s, p + Vector2(12, -90) * s, body, 10 * s)
	draw_circle(p + Vector2(-18, -92) * s, 5 * s, body)
	draw_circle(p + Vector2(12, -90) * s, 5 * s, body)
	draw_circle(p + Vector2(9, -38) * s, 3.5 * s, line)
	if asleep:
		draw_line(p + Vector2(2, -38) * s, p + Vector2(16, -38) * s, line, 2 * s)
	else:
		draw_circle(p + Vector2(12, -40) * s, 5 * s, Color(1, 1, 1))
		draw_circle(p + Vector2(13, -40) * s, 2.5 * s, line)


func _draw_turtle(p: Vector2, s: float) -> void:
	var shell := Color(0.2, 0.45, 0.2)
	var skin := Color(0.55, 0.78, 0.32)
	draw_circle(p, 34 * s, shell)
	draw_circle(p + Vector2(-30, 12) * s, 12 * s, skin)
	draw_circle(p + Vector2(30, 12) * s, 12 * s, skin)
	draw_circle(p + Vector2(36, -22) * s, 17 * s, skin)
	draw_circle(p + Vector2(43, -25) * s, 3 * s, Color(0.08, 0.1, 0.1))
	draw_arc(p, 22 * s, 0, TAU, 24, Color(0.65, 0.85, 0.4), 3 * s)
	for i in 4:
		var a := i * PI * 0.5 + 0.3
		draw_line(p, p + Vector2(cos(a), sin(a)) * 24 * s,
			Color(0.1, 0.25, 0.12), 3 * s)


func _draw_cousin(p: Vector2, s: float) -> void:
	var skin := Color(0.95, 0.72, 0.52)
	var shirt := Color(1.0, 0.38, 0.3)
	var line := Color(0.12, 0.08, 0.06)
	draw_circle(p + Vector2(0, 40) * s, 58 * s, shirt)
	draw_rect(Rect2(p + Vector2(-42, 48) * s, Vector2(84, 70) * s), shirt)
	draw_circle(p + Vector2(0, -30) * s, 38 * s, skin)
	draw_arc(p + Vector2(0, -36) * s, 26 * s, PI, TAU, 16, line, 4 * s)
	draw_line(p + Vector2(-28, -30) * s, p + Vector2(-8, -30) * s, line, 5 * s)
	draw_line(p + Vector2(8, -30) * s, p + Vector2(28, -30) * s, line, 5 * s)
	# 肌肉手臂
	draw_line(p + Vector2(-48, 20) * s, p + Vector2(-78, -18) * s, skin, 24 * s)
	draw_line(p + Vector2(48, 20) * s, p + Vector2(78, -18) * s, skin, 24 * s)
	draw_circle(p + Vector2(-80, -20) * s, 14 * s, skin)
	draw_circle(p + Vector2(80, -20) * s, 14 * s, skin)
	# 口哨
	draw_line(p + Vector2(0, -6) * s, p + Vector2(0, 14) * s, line, 3 * s)
	draw_circle(p + Vector2(0, 16) * s, 6 * s, Color(0.85, 0.85, 0.8))


func _draw_cake(p: Vector2, s: float) -> void:
	draw_rect(Rect2(p + Vector2(-55, -10) * s, Vector2(110, 60) * s),
		Color(0.95, 0.78, 0.45))
	draw_rect(Rect2(p + Vector2(-55, -10) * s, Vector2(110, 18) * s),
		Color(0.98, 0.92, 0.72))
	draw_rect(Rect2(p + Vector2(-55, -10) * s, Vector2(110, 60) * s),
		Color(0.35, 0.2, 0.1), false, 3 * s)
	for i in 3:
		var x := p.x - 30 + i * 30
		draw_line(Vector2(x, p.y - 14), Vector2(x, p.y - 42), Color(0.4, 0.3, 0.2), 3)
		draw_circle(Vector2(x, p.y - 46), 5, Color(1.0, 0.9, 0.35))


func _draw_arcs(a: Vector2, b: Vector2, n: int) -> void:
	var k := 0.65 + 0.35 * absf(sin(Time.get_ticks_msec() * 0.012))
	for i in n:
		var pts := PackedVector2Array()
		for j in 9:
			var f := float(j) / 8.0
			var base := a.lerp(b, f)
			var jitter := sin(f * 37.0 + i * 4.0 + Time.get_ticks_msec() * 0.02) * 12.0
			pts.append(base + Vector2(0, jitter))
		draw_polyline(pts, Color(0.55, 0.95, 1.0, 0.55 * k), 3.0)


func _capture() -> void:
	var dir := ProjectSettings.globalize_path("res://docs/reports/longrun/feel11")
	DirAccess.make_dir_recursive_absolute(dir)
	for i in PANELS:
		_set_panel(i)
		for f in 2:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			dir.path_join("opening-%d.png" % (i + 1)))
	print("CAPTURE opening comic 7 panels")
	get_tree().quit(0)
