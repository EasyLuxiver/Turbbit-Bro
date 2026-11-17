extends Control
## 阶段 3 结算：显示完成时间、干净通过、连招、救援、失误、联合事故、S-D 等级
## 与个人纪录。§七-9 起固定数字总分不再出现在玩家界面，但仍在后台计算。
## 文字走 Locale；切换语言时立即刷新，不重开结算。

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var _title_label: Label
var _grade_label: Label
var _antidote_label: Label
var _stats_label: Label
var _best_label: Label
var _try_label: Label
var _prompt_label: Label
var _cousin_line: Label
var _bros_line: Label
var _again_button: Button
var _menu_button: Button


func _ready() -> void:
	queue_redraw()
	_build_ui()
	Locale.language_changed.connect(_on_language_changed)
	var args := OS.get_cmdline_user_args()
	if "--capture-result" in args:
		# 截图用样本数据；不调用 finalize_run，所以不会写 best.json。
		_fill_sample()
		for a in args:
			if a.begins_with("--grade="):
				GameManager.grade = a.substr(8)
				_refresh()
		# G17：-- --trynext 把样本改成“有连招、没亲手喂到”的那一局，
		# 拍「下次试试」这一行；只改内存里的样本值。
		if "--trynext" in args:
			GameManager.snack_switch_count = 0
			_refresh()
		_capture_and_quit(_arg_after(args, "--capture-result", "stage4_result.png"))


func _draw() -> void:
	var view := get_viewport_rect().size
	# FEEL-15：终点是明亮完整的海岸终点，不再是黑暗空场。
	for i in 12:
		var k := float(i) / 11.0
		draw_rect(Rect2(0, view.y * k / 3.0, view.x, view.y / 3.0 + 2.0),
			Color(0.42 + 0.18 * k, 0.72 + 0.12 * k, 0.88 + 0.06 * k))
	draw_rect(Rect2(0, view.y * 0.46, view.x, view.y * 0.20),
		Color(0.06, 0.42, 0.52))
	draw_rect(Rect2(0, view.y * 0.66, view.x, view.y * 0.34),
		Color(0.78, 0.66, 0.40))
	draw_circle(Vector2(view.x * 0.82, view.y * 0.14), 92.0,
		Color(1.0, 0.86, 0.35, 0.92))
	draw_circle(Vector2(view.x * 0.82, view.y * 0.14), 116.0,
		Color(1.0, 0.90, 0.50, 0.20))
	# 终点舞台：木板 + 彩旗，读作“到达终点”，不是结算表格背景。
	draw_rect(Rect2(view.x * 0.06, view.y * 0.66, view.x * 0.88, 18),
		Color(0.52, 0.35, 0.18))
	for i in 9:
		var x := view.x * (0.08 + 0.10 * i)
		draw_line(Vector2(x, view.y * 0.66), Vector2(x, view.y * 0.60),
			Color(0.34, 0.22, 0.12), 4)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, view.y * 0.60), Vector2(x + 34, view.y * 0.615),
			Vector2(x, view.y * 0.635)]),
			Color(1.0, 0.45 + 0.2 * (i % 2), 0.3, 0.85))
	# 中央半透明底：明亮的终点也要保证两种语言的成绩可读。
	# FEEL-22：底框盖到快捷键行，避免白字压在沙地/木板上读不清。
	draw_rect(Rect2(view.x * 0.11, view.y * 0.05, view.x * 0.78, view.y * 0.68),
		Color(0.02, 0.08, 0.12, 0.62))
	draw_rect(Rect2(view.x * 0.11, view.y * 0.05, view.x * 0.78, view.y * 0.68),
		Color(1.0, 0.86, 0.35, 0.55), false, 2.0)
	_draw_cousin(Vector2(view.x * 0.84, view.y * 0.82), 1.05)
	# 大表哥手里的解药：绿色小瓶 + 软木塞 + 高光。
	_draw_potion(Vector2(view.x * 0.84 + 70, view.y * 0.82 - 30), 1.0)
	_draw_tubo(Vector2(view.x * 0.10, view.y * 0.84), 0.95)
	_draw_bitt(Vector2(view.x * 0.22, view.y * 0.88), 0.95)


func _draw_potion(p: Vector2, s: float) -> void:
	draw_circle(p, 20 * s, Color(0.45, 1.0, 0.55, 0.16))
	draw_rect(Rect2(p + Vector2(-10, -8) * s, Vector2(20, 30) * s),
		Color(0.30, 0.85, 0.38))
	draw_rect(Rect2(p + Vector2(-10, -8) * s, Vector2(20, 30) * s),
		Color(0.12, 0.45, 0.18), false, 2.0)
	draw_rect(Rect2(p + Vector2(-4, -16) * s, Vector2(8, 10) * s),
		Color(0.48, 0.32, 0.18))
	draw_rect(Rect2(p + Vector2(-5, -20) * s, Vector2(10, 5) * s),
		Color(0.75, 0.58, 0.32))
	draw_circle(p + Vector2(-3, 4) * s, 3.5 * s,
		Color(0.85, 1.0, 0.8, 0.9))


func _build_ui() -> void:
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	_title_label = Label.new()
	_title_label.text = Locale.t("result.title")
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 58)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	# 背景的太阳圆会压在标题后面，加描边保证两种语言都读得清。
	_title_label.add_theme_color_override("font_outline_color", Color(0.03, 0.10, 0.16, 0.95))
	_title_label.add_theme_constant_override("outline_size", 8)
	box.add_child(_title_label)

	_grade_label = Label.new()
	_grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grade_label.add_theme_font_size_override("font_size", 40)
	_grade_label.add_theme_color_override("font_color", _grade_color(GameManager.grade))
	box.add_child(_grade_label)

	_cousin_line = Label.new()
	_cousin_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cousin_line.add_theme_font_size_override("font_size", 22)
	_cousin_line.add_theme_color_override("font_color", Color(1.0, 0.86, 0.36))
	box.add_child(_cousin_line)
	# 终点画面里有大表哥和解药；文字必须把这件事说破，不能只在背景画个绿瓶。
	_antidote_label = Label.new()
	_antidote_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_antidote_label.add_theme_font_size_override("font_size", 18)
	_antidote_label.add_theme_color_override("font_color", Color(0.72, 1.0, 0.76))
	box.add_child(_antidote_label)
	_bros_line = Label.new()
	_bros_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bros_line.add_theme_font_size_override("font_size", 18)
	_bros_line.add_theme_color_override("font_color", Color(0.82, 0.95, 1.0))
	box.add_child(_bros_line)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	box.add_child(spacer)

	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override("font_size", 22)
	_stats_label.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0))
	box.add_child(_stats_label)

	_best_label = Label.new()
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_best_label.add_theme_font_size_override("font_size", 18)
	_best_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	_best_label.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.12, 0.9))
	_best_label.add_theme_constant_override("outline_size", 4)
	box.add_child(_best_label)

	# G17：一条「下次试试」。只显示 Local 里选中的那一句；没有建议时整行隐藏，
	# 所以结算页在“都玩到了”的那一局不会多出一块空位。
	_try_label = Label.new()
	_try_label.name = "TryNext"
	_try_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_try_label.add_theme_font_size_override("font_size", 18)
	_try_label.add_theme_color_override("font_color", Color(0.75, 0.92, 0.8))
	_try_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_try_label)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 18)
	box.add_child(spacer2)

	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 24)
	_prompt_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_prompt_label.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.12, 0.95))
	_prompt_label.add_theme_constant_override("outline_size", 5)
	box.add_child(_prompt_label)

	# 真正可点的结算按钮：再玩一次 / 返回主菜单。R / M 仍是快捷键。
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	_again_button = _button(row, Locale.t("result.again"),
		func() -> void: GameManager.start_race())
	_menu_button = _button(row, Locale.t("result.menu"),
		func() -> void: GameManager.go_to_menu())

	_refresh()
	get_tree().process_frame.connect(_focus_again, CONNECT_ONE_SHOT)


func _refresh() -> void:
	_title_label.text = Locale.t("result.title")
	_grade_label.add_theme_color_override("font_color", _grade_color(GameManager.grade))
	_grade_label.text = "%s   %s" % [
		GameManager.grade, Locale.grade_title(GameManager.grade)]
	var g := String(GameManager.grade)
	if g not in ["S", "A", "B", "C", "D"]:
		g = "D"
	if _cousin_line != null:
		_cousin_line.text = Locale.t("result.cousin_" + g)
	if _antidote_label != null:
		_antidote_label.text = Locale.t("result.antidote")
	if _bros_line != null:
		var line_g := g if g in ["S", "B", "D"] else "B"
		_bros_line.text = "%s   %s" % [Locale.t("result.tubo_" + line_g),
			Locale.t("result.bitt_" + line_g)]
	# FEEL-12：只留时间/事故/默契/组合四行；其余统计退出结算页。
	_stats_label.text = "      ".join([
		Locale.t("result.time", ["%6.2f" % GameManager.finish_time]),
		Locale.t("result.mistakes", ["%d" % GameManager.accident_count]),
		Locale.t("result.clean", ["%d" % GameManager.clean_pass_count]),
	])
	var best_time := "--"
	if GameManager.best_time > 0.0:
		best_time = "%.2f s" % GameManager.best_time
	var best_accidents := "--" if GameManager.best_accidents < 0 \
		else str(GameManager.best_accidents)
	var lines := [
		Locale.t("result.best", [best_time, best_accidents,
			GameManager.best_streak_record]),
	]
	if GameManager.new_best_time:
		lines.append(Locale.t("result.new_time"))
	if GameManager.new_best_streak:
		lines.append(Locale.t("result.new_streak"))
	_best_label.text = "   ".join(PackedStringArray(lines))
	if is_instance_valid(_try_label):
		var try_key := GameManager.next_try_key()
		_try_label.visible = try_key != ""
		_try_label.text = Locale.t(try_key) if try_key != "" else ""
	_prompt_label.text = Locale.t("result.retry")
	if is_instance_valid(_again_button):
		_again_button.text = Locale.t("result.again")
	if is_instance_valid(_menu_button):
		_menu_button.text = Locale.t("result.menu")


func _on_language_changed(_code: String) -> void:
	_refresh()


func _button(box: Container, text: String, cb: Callable) -> Button:
	var button := Button.new()
	button.text = text
	UiTheme.style_button(button)
	button.pressed.connect(cb)
	box.add_child(button)
	return button


func _focus_again() -> void:
	if is_instance_valid(_again_button) and _again_button.is_inside_tree():
		_again_button.grab_focus()


func _fill_sample() -> void:
	GameManager.grade = "S"
	GameManager.total_score = 12460
	GameManager.finish_time = 296.63
	GameManager.rabbit_casualties = 0
	GameManager.turtle_failures = 0
	GameManager.perfect_cooperation = 54
	GameManager.showtime_count = 18
	GameManager.best_streak = 54
	GameManager.accident_count = 0
	GameManager.clean_pass_count = 55
	GameManager.combo_dive_count = 8
	GameManager.combo_ollie_count = 3
	GameManager.rescue_success_count = 4
	GameManager.snack_switch_count = 3
	GameManager.joint_accident_count = 0
	_refresh()


func _arg_after(args: PackedStringArray, flag: String, fallback: String) -> String:
	var i := args.find(flag)
	if i >= 0 and i + 1 < args.size() and not args[i + 1].begins_with("--"):
		return args[i + 1]
	return fallback


func _capture_and_quit(file_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(file_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE ", path)
	get_tree().quit(0)


func _grade_color(grade: String) -> Color:
	match grade:
		"S":
			return Color(1.0, 0.9, 0.3)
		"A":
			return Color(0.5, 1.0, 0.6)
		"B":
			return Color(0.45, 0.85, 1.0)
		"C":
			return Color(1.0, 0.65, 0.35)
		_:
			return Color(1.0, 0.4, 0.35)


func _draw_cousin(p: Vector2, s: float) -> void:
	var skin := Color(0.95, 0.72, 0.52)
	var shirt := Color(1.0, 0.38, 0.3)
	var line := Color(0.12, 0.08, 0.06)
	draw_circle(p + Vector2(0, 40) * s, 54 * s, shirt)
	draw_rect(Rect2(p + Vector2(-40, 46) * s, Vector2(80, 72) * s), shirt)
	draw_circle(p + Vector2(0, -24) * s, 34 * s, skin)
	draw_arc(p + Vector2(0, -30) * s, 23 * s, PI, TAU, 14, line, 4 * s)
	draw_line(p + Vector2(-24, -24) * s, p + Vector2(-8, -24) * s, line, 4 * s)
	draw_line(p + Vector2(8, -24) * s, p + Vector2(24, -24) * s, line, 4 * s)
	draw_line(p + Vector2(-44, 22) * s, p + Vector2(-72, -8) * s, skin, 20 * s)
	draw_line(p + Vector2(44, 22) * s, p + Vector2(72, -8) * s, skin, 20 * s)
	draw_circle(p + Vector2(-73, -9) * s, 11 * s, skin)
	draw_circle(p + Vector2(73, -9) * s, 11 * s, skin)
	draw_line(p + Vector2(0, -2) * s, p + Vector2(0, 12) * s, line, 3 * s)
	draw_circle(p + Vector2(0, 14) * s, 5 * s, Color(0.85, 0.85, 0.8))


func _draw_tubo(p: Vector2, s: float) -> void:
	var body := Color(0.95, 0.95, 0.93)
	draw_circle(p, 24 * s, body)
	draw_rect(Rect2(p + Vector2(-13, -62) * s, Vector2(9, 38) * s), body)
	draw_rect(Rect2(p + Vector2(4, -62) * s, Vector2(9, 38) * s), body)
	draw_circle(p + Vector2(10, -4) * s, 3 * s, Color(0.1, 0.1, 0.1))


func _draw_bitt(p: Vector2, s: float) -> void:
	draw_circle(p, 34 * s, Color(0.25, 0.6, 0.3))
	draw_circle(p + Vector2(36, -10) * s, 16 * s, Color(0.4, 0.7, 0.3))
	draw_circle(p + Vector2(42, -13) * s, 3 * s, Color(0.05, 0.08, 0.06))
	draw_arc(p, 20 * s, 0, TAU, 20, Color(0.55, 0.9, 0.4), 3 * s)
