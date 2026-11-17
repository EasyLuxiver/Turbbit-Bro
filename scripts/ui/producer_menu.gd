extends Control
## FEEL-10 P1-B：制作人测试入口（A–H）。
##
## 全部是正式游戏里的可点入口，不依赖自动驾驶脚本；每个入口都有标题、
## 一句“要观察什么”、R 重置、ESC 返回本页。测试期间 GameManager.test_no_best
## 阻止写入正式 best.json。

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const ENTRIES := [
	["A", "单角色 / 联合事故", "撞兔子专属障碍只扣兔子；按 J 演示两人同时危险 → 联合",
		"case"],
	["B", "救援免疫", "兔子落水进入救援；按 K 演示救援中的碰撞不记账",
		"case"],
	["C", "TUBO 神游", "已把乌龟推到 RESTLESS；看绞盘/自漂与 0.5–1 s 不服从",
		"case"],
	["D", "BITT 神游", "已把兔子推到 RESTLESS；看前摇与不服从，另一角色仍可操作",
		"case"],
	["E", "水流改道", "浮木被水推高/压低；高时下潜、低时起跳",
		"res://scenes/p0c_current_test.tscn"],
	["F", "状态吊网", "网低时趴低；切乌龟后绞盘把网拉高，兔层让开",
		"res://scenes/p0c_net_test.tscn"],
	["G", "Z1 → Z2 入场", "从 14200 起跑；看远景码头 → 屋顶/近景 → 第一组障碍",
		"case"],
	["H", "TUBO 拆件动画", "头/颈/壳/四鳍/尾/眼睑各自动；Idle→Cruise→Jump→Landing",
		"res://scenes/tubo_parts_anim_test.tscn"],
	["I", "SHIFT 实验室", "60–90 s：巡航/兔子跳/乌龟潜/交接/组合/救援",
		"res://scenes/shift_lab.tscn"],
]

var _focusables: Array[Button] = []


func _ready() -> void:
	Locale.set_language("zh")
	_build()
	_focusables[0].grab_focus.call_deferred()
	if "--capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()


func _capture() -> void:
	await get_tree().create_timer(0.5).timeout
	var dir := ProjectSettings.globalize_path(
		"res://docs/reports/longrun/feel10-p1b")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(
		dir.path_join("producer-menu.png"))
	get_tree().quit(0)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.09, 0.14)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(UiTheme.make_label("制作人测试  PRODUCER TESTS", 42,
		UiTheme.GOLD))
	box.add_child(UiTheme.make_label(
		"选一个入口，按提示观察；R 重置，F10 返回（本页 ESC 也可返回）。测试不写正式纪录。",
		16, Color(0.72, 0.86, 0.95)))
	box.add_child(_spacer(6))
	for e in ENTRIES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)
		var b := Button.new()
		b.custom_minimum_size = Vector2(300, 38)
		b.text = "%s    %s" % [String(e[0]), String(e[1])]
		UiTheme.style_button(b, false)
		b.pressed.connect(_on_entry.bind(String(e[0]), String(e[3])))
		row.add_child(b)
		var desc := UiTheme.make_label(String(e[2]), 14,
			Color(0.62, 0.78, 0.86))
		desc.custom_minimum_size = Vector2(620, 0)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc)
		_focusables.append(b)
	box.add_child(_spacer(8))
	var back := Button.new()
	back.text = "返回主菜单  [ESC]"
	UiTheme.style_button(back, false)
	back.pressed.connect(_on_back)
	box.add_child(back)
	_focusables.append(back)


func _on_entry(code: String, target: String) -> void:
	GameManager.test_no_best = true
	if target == "case":
		GameManager.producer_mode = code
		get_tree().change_scene_to_file("res://scenes/producer_case.tscn")
	else:
		get_tree().change_scene_to_file(target)


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		_on_back()


func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s
