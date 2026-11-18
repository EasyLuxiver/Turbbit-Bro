extends Node
## FEEL-11 P1：60–90 秒教学，接在 7 格连环画之后、正式 55 组之前。
##
## 4 步：TUBO 跳/趴 → SHIFT 到 BITT 跃/潜 → 第一次电流接力 → 自己过组合。
## 大表哥只在教学/开场/区域转换/结尾出现；这里不写 best.json。
## 完成或按 K 跳过后进入正式比赛（GameManager.start_race）。

const LevelData = preload("res://scripts/systems/level_data.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const SPEED := 220.0
const END_X := 7000.0
const STEP_X := [2200.0, 4000.0, 5600.0, 7000.0]

var race: Node
var step := 0
var _t := 0.0
var _finished := false
var _handoff_t := -1.0
var _black_t := 0.0
var _fade_rect: ColorRect
var _jumped := false
var _crouched := false
var _leaped := false
var _dived := false
var _relay_seen := false
var _accidents0 := 0
var _fail_t := 0.0
var _title: Label
var _line: Label
var _hint: Label
var _fail: Label
var _step_label: Label
var _overlay: CanvasLayer


func _ready() -> void:
	GameManager.test_no_best = true
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.current_control = "rabbit"
	race = load("res://scenes/race.tscn").instantiate()
	add_child(race)
	await get_tree().process_frame
	await get_tree().process_frame
	race.opening_active = false
	race.test_no_finish = true
	race.test_no_coop_hint = true
	race.test_no_lessons = true
	race.test_no_mischief = true
	race.test_no_showtime = true
	race.test_no_bounce = true
	race.world_end = END_X
	race.turtle.reset(Vector2(400.0, race.surface_ref()))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	var groups := [
		{"group": "tut_rock", "zone": 1, "kind": "SURFACE_ROCK", "x": 1300.0, "w": 120.0},
		{"group": "tut_beam", "zone": 1, "kind": "LOW_BEAM", "x": 2100.0, "w": 170.0},
		{"group": "tut_gate", "zone": 1, "kind": "DIVE_GATE", "x": 3000.0, "w": 180.0},
		{"group": "tut_shark", "zone": 1, "kind": "SHARK", "x": 3800.0, "w": 70.0},
		{"group": "tut_log1", "zone": 1, "kind": "FLOATING_LOG", "x": 5000.0, "w": 32.0,
			"h": 215.0},
		{"group": "tut_log2", "zone": 1, "kind": "FLOATING_LOG", "x": 6400.0, "w": 32.0},
	]
	var built := []
	for spec in groups:
		built.append(LevelData.build_group(spec))
	race.load_level(built, [])
	race.world_end = END_X
	race.turtle.base_speed = SPEED
	race.turtle.speed = SPEED
	race.rabbit.attach(race.turtle.get_mount_point())
	_accidents0 = GameManager.accident_count
	_build_overlay()
	_set_step(0)
	if "--capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()


func _process(delta: float) -> void:
	if _handoff_t > 0.0:
		_handoff_t -= delta
		if _handoff_t <= 0.0:
			_continue_to_race()
		return
	if _finished or race == null:
		return
	_t += delta
	if _fail_t > 0.0:
		_fail_t -= delta
		if _fail_t <= 0.0 and _fail != null:
			_fail.visible = false
	# 实际动作采样：不要求玩家按对每一步才推进；错过也会在 x 阈值处继续。
	if race.rabbit.state in ["JUMPING", "FALLING"]:
		_jumped = true
	if race.rabbit.state == "CROUCHING":
		_crouched = true
	if race.turtle.leap_active:
		_leaped = true
	if race.turtle.diving:
		_dived = true
	for row in race.relay_log:
		if String(row.get("result", "")) in ["clever", "perfect"]:
			_relay_seen = true
	_refresh_hint()
	if GameManager.accident_count > _accidents0:
		_accidents0 = GameManager.accident_count
		_show_fail()
	var x: float = race.turtle.position.x
	if step < 3:
		var gate := false
		match step:
			0: gate = _jumped and _crouched
			1: gate = _leaped and _dived
			2: gate = _relay_seen
		if x >= STEP_X[step] and gate:
			_set_step(step + 1)
		elif x >= STEP_X[step] + 900.0:
			# 没做到也放行，但明确告诉玩家漏了哪一步；不把教学变成卡关。
			_show_fail()
			_set_step(step + 1)
	elif x >= END_X - 80.0:
		_finish()


func _set_step(s: int) -> void:
	step = s
	if _line == null:
		return
	GameManager.prompt.emit("")
	GameManager.hint.emit("")
	_step_label.text = ""
	_title.text = Locale.t("tutorial.title")
	match s:
		0:
			_line.text = Locale.t("tutorial.step1")
			_hint.text = Locale.t("tutorial.step1_hint")
		1:
			_line.text = Locale.t("tutorial.step2")
			_hint.text = Locale.t("tutorial.step2_hint")
		2:
			_line.text = Locale.t("tutorial.step3")
			_hint.text = Locale.t("tutorial.step3_hint")
		_:
			_line.text = Locale.t("tutorial.step4")
			_hint.text = Locale.t("tutorial.step4_hint")


## 大表哥的提示必须跟着“现在控的是谁”走；否则玩家已经在 BITT 上，
## 底栏还在教 TUBO 的键。
func _refresh_hint() -> void:
	if _hint == null:
		return
	var on_turtle := GameManager.current_control == "turtle"
	match step:
		0:
			_hint.text = Locale.t("tutorial.step1_hint_on_turtle" if on_turtle
				else "tutorial.step1_hint")
		1:
			_hint.text = Locale.t("tutorial.step2_hint_on_rabbit" if not on_turtle
				else "tutorial.step2_hint")
		2:
			_hint.text = Locale.t("tutorial.step3_hint_on_turtle" if on_turtle
				else "tutorial.step3_hint")


func _show_fail() -> void:
	if _fail == null:
		return
	_fail.text = Locale.t("tutorial.fail")
	_fail.visible = true
	_fail_t = 2.2


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 35
	add_child(_overlay)
	var panel := PanelContainer.new()
	# FEEL-13 P1-B：1920 下左上 HUD 实际到 x≈332（逻辑 1600 基准），
	# 原来 280 会把「SHIFT 当前控制」压掉；右移到 HUD 之后。
	panel.position = Vector2(360, 18)
	panel.custom_minimum_size = Vector2(880, 0)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var portrait := CousinPortrait.new()
	portrait.custom_minimum_size = Vector2(90, 110)
	row.add_child(portrait)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	# FEEL-29：文本列宽度固定，不随提示文字长短变化。
	# 否则 SHIFT 换人后提示变长，同一列里的主台词会重新换行。
	box.custom_minimum_size = Vector2(702, 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	_title = UiTheme.make_label("", 18, UiTheme.GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(_title)
	_line = UiTheme.make_label("", 20, Color(0.95, 0.97, 1.0))
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_line)
	_hint = UiTheme.make_label("", 16, Color(0.62, 0.95, 0.9))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# FEEL-29：提示换人后会变长；允许换行，避免把整列撑宽、带偏主台词。
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_hint)
	_fail = UiTheme.make_label("", 15, Color(1.0, 0.55, 0.4))
	_fail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_fail.visible = false
	box.add_child(_fail)
	_step_label = UiTheme.make_label("", 14, Color(0.62, 0.78, 0.86))
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_step_label)
	var skip := UiTheme.make_label(Locale.t("tutorial.skip"), 15,
		Color(0.75, 0.88, 0.96))
	skip.position = Vector2(380, 172)
	skip.size = Vector2(300, 24)
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_overlay.add_child(skip)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.visible = false
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(_fade_rect)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_K or event.keycode == KEY_K:
		_finish()
		get_viewport().set_input_as_handled()


func _continue_to_race() -> void:
	# 制作人质检：教学结束不再重载 race，也不把兔子和乌龟归位；
	# 只收掉教学 UI、恢复正赛参数，从当前位置接着跑。
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null
	GameManager.tutorial_done = true
	GameManager.test_no_best = false
	GameManager.state = GameManager.GameState.RUNNING
	Engine.time_scale = 1.0
	GameManager.race_fade_in = false
	race.test_no_finish = false
	race.test_no_coop_hint = false
	race.test_no_lessons = false
	race.test_no_mischief = false
	race.test_no_showtime = false
	race.test_no_bounce = false
	race.opening_active = false
	race.world_end = LevelData.WORLD_END
	race.load_level(LevelData.groups(), [])
	race.turtle.speed = float(race.current_zone.get("base_speed", SPEED))
	race.turtle.base_speed = float(race.current_zone.get("base_speed", SPEED))
	print("TUTORIAL CONTINUE x=%.0f" % race.turtle.position.x)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	GameManager.tutorial_done = true
	print("TUTORIAL DONE x=%.0f t=%.1f step=%d" % [
		race.turtle.position.x, _t, step])
	# FEEL-22：不画假终点，也不跨线瞬移回起点。
	# 先让大表哥说完，再进入正式训练。
	GameManager.prompt.emit("")
	GameManager.hint.emit("")
	_line.text = Locale.t("tutorial.done")
	_hint.text = ""
	_step_label.text = ""
	# 用 _process 计时，headless/手动步进也能稳定走完过渡。
	_handoff_t = 1.4


## 大表哥的简笔头像：只画形状，不引入素材。
class CousinPortrait:
	extends Control

	func _draw() -> void:
		var c := size * 0.5
		var skin := Color(0.95, 0.72, 0.52)
		var shirt := Color(1.0, 0.38, 0.3)
		var line := Color(0.12, 0.08, 0.06)
		draw_circle(c + Vector2(0, 32), 34, shirt)
		draw_rect(Rect2(c + Vector2(-26, 34), Vector2(52, 28)), shirt)
		draw_circle(c + Vector2(0, -10), 23, skin)
		draw_arc(c + Vector2(0, -14), 18, PI, TAU, 12, line, 3)
		draw_line(c + Vector2(-16, -10), c + Vector2(-6, -10), line, 4)
		draw_line(c + Vector2(6, -10), c + Vector2(16, -10), line, 4)
		draw_line(c + Vector2(-24, 18), c + Vector2(-40, -2), skin, 14)
		draw_line(c + Vector2(24, 18), c + Vector2(40, -2), skin, 14)
		draw_circle(c + Vector2(-41, -3), 7, skin)
		draw_circle(c + Vector2(41, -3), 7, skin)


func _capture() -> void:
	await get_tree().create_timer(1.0).timeout
	var dir := ProjectSettings.globalize_path("res://docs/reports/longrun/feel11")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(
		dir.path_join("tutorial-step1.png"))
	_set_step(2)
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png(
		dir.path_join("tutorial-step3.png"))
	print("CAPTURE tutorial")
	get_tree().quit(0)
