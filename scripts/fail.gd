extends Control
## FEEL-15：氧气耗尽独立失败画面。不是普通结算，不写最佳纪录。

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var _title: Label
var _sub: Label
var _button_row: HBoxContainer


func _ready() -> void:
	queue_redraw()
	_build()
	var args := OS.get_cmdline_user_args()
	if "--capture-fail" in args:
		_capture_and_quit(_arg_after(args, "--capture-fail", "feel15-fail.png"))


func _draw() -> void:
	var view := get_viewport_rect().size
	# 深水 + 气泡：失败是“水下”的，不是普通结算的沙滩。
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.035, 0.13, 0.20))
	draw_rect(Rect2(0, view.y * 0.22, view.x, view.y * 0.78),
		Color(0.02, 0.16, 0.24))
	for i in 18:
		var x := fmod(float(i) * 137.0 + 40.0, view.x)
		var y := fmod(float(i) * 83.0 + 120.0, view.y)
		draw_circle(Vector2(x, y), 3.0 + float(i % 4),
			Color(0.5, 0.9, 1.0, 0.22))
	# 下沉的 TUBO 轮廓 + 绝望的耳朵。
	var c := Vector2(view.x * 0.16, view.y * 0.78)
	draw_circle(c, 38, Color(0.92, 0.92, 0.88, 0.72))
	draw_line(c + Vector2(-14, -30), c + Vector2(-25, -86),
		Color(0.92, 0.92, 0.88, 0.72), 9)
	draw_line(c + Vector2(14, -30), c + Vector2(27, -82),
		Color(0.92, 0.92, 0.88, 0.72), 9)
	draw_circle(c + Vector2(-10, -4), 4, Color(0.1, 0.15, 0.2, 0.8))
	draw_circle(c + Vector2(10, -4), 4, Color(0.1, 0.15, 0.2, 0.8))
	draw_line(c + Vector2(-8, 12), c + Vector2(8, 8),
		Color(0.1, 0.15, 0.2, 0.8), 3)
	# 上方伸下来的 BITT 鳍/壳边：够不着。
	draw_circle(Vector2(view.x * 0.84, view.y * 0.30), 52,
		Color(0.30, 0.52, 0.30, 0.55))
	draw_circle(Vector2(view.x * 0.84 + 52, view.y * 0.27), 18,
		Color(0.42, 0.62, 0.35, 0.55))


func _build() -> void:
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	_title = Label.new()
	_title.text = Locale.t("fail.title")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 54)
	_title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.62))
	_title.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.10))
	_title.add_theme_constant_override("outline_size", 10)
	box.add_child(_title)
	_sub = Label.new()
	_sub.text = Locale.t("fail.sub")
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_font_size_override("font_size", 22)
	_sub.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	box.add_child(_sub)
	var reason := Label.new()
	reason.text = Locale.t("fail.reason_oxygen") if GameManager.failure_reason == "OXYGEN_OUT" \
		else GameManager.failure_reason
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason.add_theme_font_size_override("font_size", 18)
	reason.add_theme_color_override("font_color", Color(1.0, 0.68, 0.48))
	box.add_child(reason)
	var tip := Label.new()
	tip.text = Locale.t("fail.tip_oxygen") if GameManager.failure_reason == "OXYGEN_OUT" \
		else Locale.t("fail.tip_oxygen")
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 18)
	tip.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0))
	box.add_child(tip)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	box.add_child(spacer)
	_button_row = HBoxContainer.new()
	_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_row.add_theme_constant_override("separation", 20)
	box.add_child(_button_row)
	var again := _button(Locale.t("fail.again"),
		func() -> void: GameManager.start_race())
	var menu := _button(Locale.t("fail.menu"),
		func() -> void: GameManager.go_to_menu())
	_button_row.add_child(again)
	_button_row.add_child(menu)
	var hint := Label.new()
	hint.text = Locale.t("fail.hint")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.6, 0.78, 0.9))
	box.add_child(hint)
	get_tree().process_frame.connect(func() -> void: again.grab_focus(), CONNECT_ONE_SHOT)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	UiTheme.style_button(b)
	b.pressed.connect(cb)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	# R / M 由 GameManager 的全局输入处理；这里只补 ENTER。
	if event.physical_keycode == KEY_ENTER:
		GameManager.start_race()


func _capture_and_quit(file_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(
		dir.path_join(file_name))
	print("CAPTURE ", dir.path_join(file_name))
	get_tree().quit(0)


func _arg_after(args: PackedStringArray, flag: String, fallback: String) -> String:
	var i := args.find(flag)
	if i >= 0 and i + 1 < args.size() and not args[i + 1].begins_with("--"):
		return args[i + 1]
	return fallback
