extends Node
## FEEL-13 P1-B：教学逐步骤人工检查的自动化取证。
## 运行（窗口化）：Godot --path . --resolution 1920x1080 res://scenes/stage13_tutorial_flow.tscn
## 只验证状态迁移与截图，不替代真人试玩；不写 best.json。

var is_runner := false
var checks: Array = []
var tut: Node
var dir := ""


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	dir = ProjectSettings.globalize_path("res://docs/reports/longrun/feel13")
	DirAccess.make_dir_recursive_absolute(dir)
	tut = load("res://scenes/tutorial.tscn").instantiate()
	get_tree().root.add_child(tut)
	for i in 6:
		await get_tree().process_frame
	await _shot("tutorial-step1")
	_check("step1 text", tut._line.text == Locale.t("tutorial.step1")
		and tut._hint.text == Locale.t("tutorial.step1_hint"),
		"step1 line/hint")
	_check("cousin title", tut._title.text == Locale.t("tutorial.title"), "cousin title")
	# 即时替换：设 step2，同一调用内旧提示必须消失。
	tut._set_step(1)
	_check("step2 immediate", tut._line.text == Locale.t("tutorial.step2")
		and not tut._line.text.contains(Locale.t("tutorial.step1")), "step2 replaces step1")
	await _shot("tutorial-step2")
	# 提前完成动作：x 已到门槛、leap/dive 已发生，下一帧直接进 step3。
	tut._leaped = true
	tut._dived = true
	tut.race.turtle.position.x = 4800.0
	tut._process(0.016)
	_check("early action advances", tut.step == 2, "step=%d" % tut.step)
	_check("no stale prompt", tut._line.text == Locale.t("tutorial.step3"),
		"line step3")
	await _shot("tutorial-step3")
	# 失败提示：可见、有文案、2.2 s 后消失。
	tut._show_fail()
	_check("fail visible", tut._fail.visible
		and tut._fail.text == Locale.t("tutorial.fail"), "fail text")
	await _shot("tutorial-fail")
	tut._process(2.3)
	_check("fail fades", not tut._fail.visible, "fail hidden after 2.3 s")
	# 重开：回到 step1，提示重新出现。
	tut._set_step(0)
	_check("restart step1", tut.step == 0 and tut._line.text == Locale.t("tutorial.step1"),
		"restart step1")
	# 跳过：K 键进入正式比赛；只验证 _finished 与 GameManager 状态。
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_K
	ev.pressed = true
	tut._input(ev)
	_check("skip finishes", tut._finished and GameManager.tutorial_done,
		"finished=%s tutorial_done=%s" % [str(tut._finished), str(GameManager.tutorial_done)])
	_write()
	get_tree().quit(0 if checks.all(func(c): return bool(c["ok"])) else 1)


func _shot(name: String) -> void:
	for i in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + "-1920.png"))
	print("CAPTURE ", name)


func _check(n: String, ok: bool, d: String) -> void:
	checks.append({"name": n, "ok": ok, "detail": d})
	print(("ok    " if ok else "FAIL  ") + n + "  " + d)


func _write() -> void:
	var f := FileAccess.open("res://docs/reports/longrun/core-feel-13-tutorial.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"task": "FEEL-13 P1-B", "checks": checks}, "  "))
	f.close()
