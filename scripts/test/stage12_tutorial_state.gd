extends Node
## FEEL-12 G：教学步骤状态迁移测试（不替代真人）。
## 验证：设置新步骤 → 旧提示清除、下一提示同帧出现；提前完成动作 → 不要求重复。

var is_runner := false
var checks: Array = []


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
	var tut: Node = load("res://scenes/tutorial.tscn").instantiate()
	get_tree().root.add_child(tut)
	for i in 5:
		await get_tree().process_frame
	tut._set_step(0)
	_check("step1_prompt", tut._line.text == Locale.t("tutorial.step1")
		and tut._hint.text == Locale.t("tutorial.step1_hint"),
		"line/hint step1")
	tut._set_step(1)
	_check("step2_replaces_step1",
		tut._line.text == Locale.t("tutorial.step2")
			and not tut._line.text.contains(Locale.t("tutorial.step1")),
		"line step2, no step1")
	# 提前完成 step2 的动作：设 x 到门槛并满足 leap/dive，下一次 _process 应进入 step3。
	tut._leaped = true
	tut._dived = true
	tut.race.turtle.position.x = 4800.0
	tut._process(0.016)
	_check("early_action_advances", tut.step == 2,
		"step=%d (expect 2)" % tut.step)
	# 旧提示不得被重新写回。
	tut._process(0.016)
	_check("no_stale_prompt",
		tut._line.text == Locale.t("tutorial.step3")
			and not tut._line.text.contains(Locale.t("tutorial.step1")),
		"line step3 stable")
	_write()
	get_tree().quit(0 if checks.all(func(c): return bool(c["ok"])) else 1)


func _check(n: String, ok: bool, d: String) -> void:
	checks.append({"name": n, "ok": ok, "detail": d})
	print(("ok    " if ok else "FAIL  ") + n + "  " + d)


func _write() -> void:
	var f := FileAccess.open("res://docs/reports/longrun/core-feel-12-tutorial.json",
		FileAccess.WRITE)
	f.store_string(JSON.stringify({"task": "TBB-CORE-FEEL-12 G", "checks": checks}, "  "))
	f.close()
