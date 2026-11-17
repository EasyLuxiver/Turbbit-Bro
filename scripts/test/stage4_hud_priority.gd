extends Node
## 阶段 4 HUD 优先级自检：障碍预警、教学提示、通过反馈各占一行，互不覆盖。
## 在真实 race.tscn 里摆位后读 HUD 的实际 Label 文本，不另做假 HUD。
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT res://scenes/stage4_hud_priority.tscn

var is_runner := false
var failures: Array[String] = []
const Tuning = preload("res://scripts/systems/tuning.gd")

var race
var _freeze_x := 0.0


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4HudPriorityRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	Locale.language = "zh"
	GameManager.start_race()
	await _wait_scene("race.tscn")
	await _frames(4)
	race = get_tree().current_scene
	_check(race != null and race.hud != null, "race scene has HUD")
	if race == null or race.hud == null:
		_finish()
		return

	# 关掉碰撞，只观察显示优先级：站在第一根低杆前 300 px，会触发“↓ 趴低”预警。
	race.test_disable_hazards = true
	var beam := {}
	for g in race.hazard_groups:
		if g["group"] == "beam1":
			beam = g
			break
	_check(not beam.is_empty(), "beam1 exists on the track")
	race.turtle.position = Vector2(race._group_start(beam) - 300.0, Tuning.NEUTRAL_DEPTH)
	race.turtle.speed = 0.0
	# 巡航是自动的，race 每帧都会把 base_speed 写回区速；等待期间把位置钉住，
	# 否则 3 s 内会漂到下一块岩石的预警范围，把“趴低”换成“跳跃”。
	_freeze_x = race.turtle.position.x
	await _frames(3)

	_check(race.hud.prompt_label.visible
		and race.hud.prompt_label.text.contains("趴"),
		"obstacle prompt is visible before the beam (%s)" % race.hud.prompt_label.text)
	_check(race.hud.hint_label.text == "", "hint line is empty by default")

	# 教学提示进自己的一行，不抢障碍预警。
	GameManager.hint.emit("测试提示")
	await _frames(2)
	_check(race.hud.prompt_label.visible and race.hud.prompt_label.text.contains("趴"),
		"hint does not replace the obstacle prompt (%s)" % race.hud.prompt_label.text)
	_check(race.hud.hint_label.visible and race.hud.hint_label.text == "测试提示",
		"hint shows in its own line (%s)" % race.hud.hint_label.text)

	# 通过反馈再来一行：三行同时在场。
	GameManager.feedback.emit("干净通过", "clean")
	await _frames(2)
	_check(race.hud.feedback_label.visible, "clean-pass feedback appears")
	_check(race.hud.prompt_label.visible and race.hud.hint_label.visible,
		"prompt / hint / feedback can be on screen at the same time")

	# 各自按自己的时长清空：反馈 0.75 s < 提示 2.2 s < 预警 3.0 s。
	await _hold(1.0)
	_check(not race.hud.feedback_label.visible, "feedback clears after 0.75 s")
	_check(race.hud.prompt_label.visible and race.hud.hint_label.visible,
		"prompt and hint outlive the feedback")
	await _hold(1.4)
	_check(not race.hud.hint_label.visible, "hint clears after 2.2 s")
	_check(race.hud.prompt_label.visible, "prompt is still up after the hint clears")
	await _hold(0.8)
	_check(not race.hud.prompt_label.visible,
		"prompt clears after 3 s (timer %.2f, text '%s')" % [
			race.hud.prompt_timer, race.hud.prompt_text])

	await _measure_lifetimes()

	# 这里不冲线，不写 best.json。
	_finish()


## 逐帧观察三条文字各自从出现到消失的实际时长，打印最大值。
func _measure_lifetimes() -> void:
	var t0 := Time.get_ticks_msec()
	GameManager.feedback.emit("测量反馈", "clean")
	GameManager.hint.emit("测量提示")
	GameManager.prompt.emit("测量预警")
	var started := {}
	var seen := {}
	var res := {}
	var keys := ["feedback", "hint", "prompt"]
	while Time.get_ticks_msec() - t0 < 6000:
		race.turtle.speed = 0.0
		race.turtle.position.x = _freeze_x
		await get_tree().process_frame
		var now := Time.get_ticks_msec()
		var vis := {
			"feedback": race.hud.feedback_label.visible,
			"hint": race.hud.hint_label.visible,
			"prompt": race.hud.prompt_label.visible,
		}
		for k in keys:
			if res.has(k):
				continue
			if vis[k]:
				seen[k] = true
				if not started.has(k):
					started[k] = now
			elif started.has(k):
				res[k] = (now - int(started[k])) / 1000.0
		if res.size() == 3:
			break
	var worst := 0.0
	for k in keys:
		var v: float = res.get(k, -1.0)
		worst = maxf(worst, v)
		print("HUD TIMING %s=%.2f s (appeared=%s)" % [k, v, seen.get(k, false)])
	print("HUD TIMING max=%.2f s" % worst)
	_check(res.size() == 3, "all three lines appeared and cleared within 6 s")
	# FEEL-09 P1-A：SHIFT / 连招提示要在 1100 px 外触发后一直留到障碍前，
	# 设计值从 3 s 提到 5 s；反馈 0.75 s、hint 2.2 s 不变。
	_check(worst > 0.0 and worst <= 5.05, "longest visible line %.2f s <= 5.0 s" % worst)


func _wait_scene(suffix: String) -> void:
	for i in 240:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path.ends_with(suffix):
			return
	_check(false, "scene %s loaded" % suffix)


## 等待但不让自动巡航把车开出预警窗口。
func _hold(seconds: float) -> void:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(seconds * 1000.0):
		race.turtle.speed = 0.0
		race.turtle.position.x = _freeze_x
		await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)


func _finish() -> void:
	Locale.language = "zh"
	if failures.is_empty():
		print("STAGE4 HUD PRIORITY: PASS")
		get_tree().quit(0)
	else:
		print("STAGE4 HUD PRIORITY: FAIL")
		for item in failures:
			print("  - " + item)
		get_tree().quit(1)
