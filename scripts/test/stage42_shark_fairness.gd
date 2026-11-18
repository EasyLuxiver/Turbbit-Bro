extends Node
## FEEL-42：SHARK6 三拍的真实输入公平性测试。
## 不使用“直接改 _shark_pack 阶段/直接 set_control”来断言成功；
## 每一次操作都通过真实 InputEvent/Input.action 进入 race.tscn 的同一处理路径。
## 记录：即时、0.20 s、0.35 s 反应；正确角色/错误角色/动作过晚。
## FEEL-49：不再是三只水鲨 + 独立攻击体，而是同一只实体鱼从水下 HOLD 帧判定。

const DELTAS := [0.0, 0.20, 0.35]
const FPS_DELTA := 1.0 / 60.0
var is_runner := false
var arena: Node
var race: Node
var checks: Array = []
var feedback_seen: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 2.0
	await get_tree().process_frame
	await _run()


func _run() -> void:
	arena = load("res://scenes/test_arena.tscn").instantiate()
	get_tree().root.add_child(arena)
	for i in 6:
		await get_tree().process_frame
	race = arena.race
	race.test_no_mischief = true
	GameManager.feedback.connect(func(text: String, _kind: String) -> void: feedback_seen.append(text))
	# 正确操作三档延迟。
	for d in DELTAS:
		var row: Dictionary = await _trial("correct", d)
		_check("correct_delay_%.2f" % d,
			bool(row["passed"]) and int(row["hits"].size()) == 0,
			JSON.stringify(row))
	var cue_ok := false
	for t in feedback_seen:
		if String(t).contains("老大要冲了") or String(t).contains("准备跃起"):
			cue_ok = true
	_check("leader_ready_cue", cue_ok, JSON.stringify(feedback_seen.slice(-12)))
	# 早按测试：0 / 0.20 s 起跳太早，记录为失败窗口，不伪装成正确操作。
	var early0: Dictionary = await _trial("early_leader_0", 0.0)
	_check("early_leader_0_hits", bool(early0["passed"])
		and early0["hits"].has("leader"), JSON.stringify(early0))
	var late_leader: Dictionary = await _trial("late_leader", 0.0)
	_check("late_leader_hits", bool(late_leader["passed"])
		and late_leader["hits"].has("leader"), JSON.stringify(late_leader))
	# 错误角色/动作过晚：至少证明每拍都有可命中的独立窗口。
	var wrong_leader: Dictionary = await _trial("wrong_leader", 0.0)
	_check("wrong_leader_hits", bool(wrong_leader["passed"])
		and wrong_leader["hits"].has("leader"), JSON.stringify(wrong_leader))
	var wrong_fat: Dictionary = await _trial("wrong_fat", 0.0)
	_check("wrong_fat_hits", bool(wrong_fat["passed"]) and wrong_fat["hits"].has("fat"),
		JSON.stringify(wrong_fat))
	var wrong_thin: Dictionary = await _trial("wrong_thin", 0.0)
	_check("wrong_thin_hits", bool(wrong_thin["passed"]) and wrong_thin["hits"].has("thin"),
		JSON.stringify(wrong_thin))
	var late_fat: Dictionary = await _trial("late_fat", 1.10)
	_check("late_fat_hits", bool(late_fat["passed"]) and late_fat["hits"].has("fat"),
		JSON.stringify(late_fat))
	var late_thin: Dictionary = await _trial("late_thin", 1.20)
	_check("late_thin_hits", bool(late_thin["passed"]) and late_thin["hits"].has("thin"),
		JSON.stringify(late_thin))
	_write()
	var ok: bool = checks.all(func(c): return bool(c["ok"]))
	print("SHARK FAIRNESS: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _trial(mode: String, delay: float) -> Dictionary:
	_release_all()
	race.clear_test_groups()
	race.load_level([], [])
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.current_control = "rabbit"
	GameManager.has_shifted = false
	GameManager.oxygen = 8.0
	GameManager.total_score = 0
	race.turtle.reset(Vector2(400.0, race.surface_ref()))
	race.turtle.base_speed = 220.0
	race.turtle.speed = 220.0
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	race.hazard_clock = 0.0
	race.hazard_cooldown = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.hit_roles.clear()
	race.hit_groups.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.group_actions.clear()
	race.accident_event_log.clear()
	race.accident_events.clear()
	race.accident_event_time = 0.0
	race.accident_event_seq = 0
	race._dynamic_bump_cd.clear()
	race._shark_pack.clear()
	race._shark_pack_log.clear()
	race._shark_attacks.clear()
	race.test_disable_hazards = false
	feedback_seen.clear()
	var g: Dictionary = race.spawn_test_group("SHARK6", 700.0)
	var target_x: float = race._group_start(g)
	# 真实输入准备：切到乌龟，而不是直接写 current_control。
	await _shift_to("turtle")
	var sim := 0.0
	var leader_t := -1.0
	var fat_t := -1.0
	var thin_t := -1.0
	var leader_done := false
	var leader_leaped := false
	var fat_done := false
	var thin_done := false
	var fat_down := false
	var thin_down := false
	var leader_delay := 0.35 if mode.begins_with("correct") else 0.0
	if mode == "late_leader":
		leader_delay = 1.10
	var fat_delay := delay
	var thin_delay := delay
	if mode == "late_fat":
		fat_delay = 1.10
		thin_delay = 0.0
	elif mode == "late_thin":
		fat_delay = 0.0
		thin_delay = 1.20
	var frames := 0
	var leader_geom := false
	var leader_overlap := false
	while frames < 1500:
		var pack: Dictionary = race._shark_pack.get("shark6", {})
		var phase := String(pack.get("phase", ""))
		var amb: Dictionary = race._ambush.get("shark6", {})
		var amb_phase := String(amb.get("phase", ""))
		if phase == "LEAD_LUNGE":
			var la: Dictionary = race._pack_actor("leader")
			if not la.is_empty() and (la["rect"] as Rect2).intersects(
					race.turtle.get_body_rect()):
				leader_overlap = true
		if amb_phase == "LUNGE" and not leader_geom:
			leader_geom = true
			var la: Dictionary = race._pack_actor("leader")
			if not la.is_empty():
				print("LEADER_GEOM body=", race.turtle.get_body_rect(),
					" live=", la["rect"], " ctl=", GameManager.current_control)
		if amb_phase == "TELEGRAPH" and leader_t < 0.0:
			leader_t = sim
		if phase == "GAP1" and fat_t < 0.0:
			fat_t = sim
		if phase == "GAP2" and thin_t < 0.0:
			thin_t = sim

		# leader：乌龟跃起。错误 leader 模式故意不按。
		if leader_t >= 0.0 and not leader_done and sim >= leader_t + leader_delay:
			leader_done = true
			if mode != "wrong_leader":
				leader_leaped = await _tap_up()
		# fat：切兔子 + 趴低；正确延迟组和软测试组都保持到 thin。
		if fat_t >= 0.0 and not fat_done and sim >= fat_t + fat_delay \
				and mode in ["correct", "wrong_thin", "late_thin", "early_leader_0"]:
			fat_done = true
			await _shift_to("rabbit")
			Input.action_press("down")
			fat_down = true
		elif mode in ["wrong_fat", "late_fat"] and fat_t >= 0.0 \
				and sim >= fat_t + delay and not fat_done:
			fat_done = true
			# 过晚：等 fat attack 已经生成后再趴；wrong_fat 完全不趴。
			if mode == "late_fat":
				Input.action_press("down")
				fat_down = true
		# thin：切乌龟 + 下潜。
		if thin_t >= 0.0 and not thin_done and sim >= thin_t + thin_delay \
				and mode in ["correct", "wrong_fat", "late_fat", "early_leader_0"]:
			thin_done = true
			await _shift_to("turtle")
			Input.action_press("down")
			thin_down = true
		elif mode in ["wrong_thin", "late_thin"] and thin_t >= 0.0 \
				and sim >= thin_t + delay and not thin_done:
			thin_done = true
		if fat_down and (phase == "RETREAT" or phase == "DONE"):
			Input.action_release("down")
			fat_down = false
		if thin_down and (phase == "RETREAT" or phase == "DONE"):
			Input.action_release("down")
			thin_down = false
		if phase == "DONE" and sim > 3.0:
			break
		await get_tree().physics_frame
		sim += FPS_DELTA * Engine.time_scale
		frames += 1
	_release_all()
	var hits: Array = []
	for e in race._shark_pack_log:
		if String(e.get("event", "")) == "hit":
			hits.append(String(e.get("who", "")))
	var event_roles: Array = []
	for e in race.accident_event_log:
		if String(e.get("group", "")) != "shark6":
			continue
		var et := float(e.get("t", -1.0))
		if fat_t >= 0.0 and et < fat_t:
			event_roles.append("leader")
		elif thin_t >= 0.0 and et < thin_t:
			event_roles.append("fat")
		elif et >= 0.0:
			event_roles.append("thin")
	var passed := true
	if mode.begins_with("correct"):
		passed = hits.is_empty() and event_roles.is_empty() \
			and String(race._shark_pack.get("shark6", {}).get("phase", "")) == "DONE"
	return {
		"mode": mode, "delay": delay, "passed": passed,
		"hits": hits, "event_roles": event_roles,
		"phase": String(race._shark_pack.get("shark6", {}).get("phase", "")),
		"accident": GameManager.accident_state, "control": GameManager.current_control,
		"hit_groups": race.hit_groups.keys(), "last_role": GameManager.last_mistake_role,
		"leader_overlap": leader_overlap,
		"leader_leaped": leader_leaped,
		"events": race.accident_event_log.duplicate(true),
		"target_x": target_x, "sim": snappedf(sim, 0.01),
		"pack_log": race._shark_pack_log.duplicate(true),
	}


func _shift_to(who: String) -> void:
	if GameManager.current_control == who:
		return
	_tap_shift()
	for i in 4:
		await get_tree().physics_frame


func _tap_shift() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SHIFT
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventKey.new()
	up.physical_keycode = KEY_SHIFT
	up.pressed = false
	Input.parse_input_event(up)


func _tap_up() -> bool:
	Input.action_press("up")
	var leaped := false
	for i in 20:
		if race.turtle.leap_active:
			leaped = true
			break
		await get_tree().physics_frame
	Input.action_release("up")
	return leaped


func _release_all() -> void:
	for a in ["up", "down", "left", "right", "shift"]:
		Input.action_release(a)


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var f := FileAccess.open("res://docs/reports/longrun/feel42-shark-fairness.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"checks": checks}, "  "))
		f.close()
