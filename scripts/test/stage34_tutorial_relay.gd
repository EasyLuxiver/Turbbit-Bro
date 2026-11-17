extends Node
## FEEL-34：完整教学路径必须亲自完成一次真实 BRO DIVE（不能只按 SHIFT/文字）。
const Tuning = preload("res://scripts/systems/tuning.gd")
var is_runner := false
var tut: Node
var race: Node
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
	tut = load("res://scenes/tutorial.tscn").instantiate()
	get_tree().root.add_child(tut)
	for i in 8:
		await get_tree().process_frame
	race = tut.race
	var log1: Dictionary = {}
	for g in race.hazard_groups:
		if String(g["kind"]) == "FLOATING_LOG":
			log1 = g
			break
	if log1.is_empty():
		_check("tutorial_log", false, "missing")
		get_tree().quit(1)
		return
	var start: float = race._group_start(log1)
	var end: float = race._group_end(log1)
	# 负例：只控制乌龟下潜，不能让教学 step 3 通过。
	tut._set_step(2)
	_reset(start - 160.0)
	race.rabbit.attach(race.turtle.get_mount_point())
	_control("turtle")
	_press("down")
	await _step_until(end + 140.0)
	_release_all()
	var negative_relay := _has_relay()
	# 正例：兔子跳 + SHIFT + 乌龟潜；扫几个 lead，找可复现的成功点。
	tut._set_step(2)
	var positive_relay := false
	for lead in [120.0, 140.0, 160.0, 180.0, 200.0]:
		race.relay_log.clear()
		_reset(start - lead)
		_control("rabbit")
		_press("up")
		await _wait(0.10)
		_release("up")
		GameManager.toggle_control()
		_press("down")
		await _step_until(end + 140.0)
		_release_all()
		if _has_relay():
			positive_relay = true
			print("RELAY_OK lead=", lead)
			break
	await _step_until(5700.0)
	_check("tutorial_requires_real_relay", not negative_relay and positive_relay,
		"negative=%s positive=%s step=%d" % [str(negative_relay), str(positive_relay), tut.step])
	_check("tutorial_advances_after_relay", tut.step >= 3, "step=%d" % tut.step)
	_write()
	var ok: bool = checks.all(func(c): return bool(c["ok"]))
	print("TUTORIAL RELAY: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _has_relay() -> bool:
	for r in race.relay_log:
		if String(r.get("result", "")) in ["clever", "perfect"]:
			return true
	return false


func _reset(x: float) -> void:
	_release_all()
	GameManager.accident_state = "NONE"
	race.turtle.reset(Vector2(x, race.surface_ref()))
	race.turtle.base_speed = 220.0
	race.turtle.speed = 220.0
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.hit_groups.clear()
	race.group_actions.clear()


func _control(who: String) -> void:
	if GameManager.current_control != who:
		GameManager.set_control(who)


func _press(a: String) -> void:
	if not Input.is_action_pressed(a):
		Input.action_press(a)


func _release(a: String) -> void:
	if Input.is_action_pressed(a):
		Input.action_release(a)


func _release_all() -> void:
	for a in ["up", "down", "left", "right", "shift"]:
		Input.action_release(a)


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += 1.0 / 60.0


func _step_until(x_target: float) -> void:
	var n := 0
	while race.turtle.position.x < x_target and n < 600:
		await get_tree().physics_frame
		n += 1


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var f := FileAccess.open("res://docs/reports/longrun/feel34-tutorial-relay.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"checks": checks}, "  "))
		f.close()
