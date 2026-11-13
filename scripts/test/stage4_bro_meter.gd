extends Node
## 阶段 4 BRO METER 三格共享事故槽：真实比赛场景里验证
##   触发（连续碰撞只记一次 / 第三格满）→ BRO_BREAK 演出 →
##   恢复位置、清空槽位、短暂保护、本局继续 → 重复触发。
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT res://scenes/stage4_bro_meter.tscn

var is_runner := false
var failures: Array[String] = []
var race
var _center_msgs: Array[String] = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4BroMeterRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	Engine.time_scale = 4.0
	GameManager.start_race()
	await _frames(6)
	race = get_tree().current_scene
	_check(race != null and race.scene_file_path.ends_with("race.tscn"),
		"race scene loads")
	race.test_disable_hazards = true
	GameManager.center_message.connect(_on_center_message)
	# 测试用起始分：add_score 在 0 分会夹到 0，扣分就看不出来。
	GameManager.total_score = 2000
	await _frames(2)

	# ---- 0. 正常动作不涨格：跳、潜、SHIFT 都不是失误。 ----
	# 障碍已关，这里只证明“输入本身”不进 note_accident。
	var meter0: int = GameManager.bro_meter
	var accidents0: int = GameManager.accident_count
	var score0: int = GameManager.total_score
	Input.action_press("up")
	await _frames(4)
	Input.action_release("up")
	GameManager.toggle_control()
	Input.action_press("down")
	await _frames(8)
	Input.action_release("down")
	GameManager.toggle_control()
	await _frames(4)
	_check(GameManager.bro_meter == meter0 and GameManager.accident_count == accidents0,
		"normal jump/dive/SHIFT do not fill the meter (meter=%d accidents=%d)" % [
			GameManager.bro_meter, GameManager.accident_count])
	_check(GameManager.total_score == score0,
		"normal actions do not cost score (%d -> %d)" % [
			score0, GameManager.total_score])

	# ---- 1. 连续碰撞只记一次：同一帧再撞不给第二格。 ----
	var accidents_before: int = GameManager.accident_count
	var score_before: int = GameManager.total_score
	race._trigger_accident("RABBIT_STUN")
	race._trigger_accident("RABBIT_STUN")
	_check(GameManager.accident_count == accidents_before + 1,
		"one continuous collision counts once (accidents %d -> %d)" % [
			accidents_before, GameManager.accident_count])
	_check(GameManager.total_score == score_before - 100,
		"one mistake costs exactly 100 (%d -> %d)" % [
			score_before, GameManager.total_score])
	_check(GameManager.bro_meter == 1 and not GameManager.bro_joint_pending,
		"first slot filled, joint not pending (meter=%d)" % GameManager.bro_meter)
	await _frames(2)
	_check(race.hud.bro_meter_label.text.contains("1/3"),
		"hud bro meter shows 1/3 (%s)" % race.hud.bro_meter_label.text)

	# ---- 2. 第二格。 ----
	await _wait_recovered()
	score_before = GameManager.total_score
	race._trigger_accident("RABBIT_STUN")
	_check(GameManager.bro_meter == 2,
		"second slot filled (meter=%d)" % GameManager.bro_meter)
	_check(GameManager.total_score == score_before - 100,
		"second mistake costs exactly 100")

	# ---- 3. 第三格：满槽 + 联合惩罚 ----
	await _wait_recovered()
	score_before = GameManager.total_score
	var joints_before: int = GameManager.joint_accident_count
	race._trigger_accident("RABBIT_STUN")
	_check(GameManager.bro_meter == 3 and GameManager.bro_joint_pending,
		"third slot fills meter and arms the joint show (meter=%d pending=%s)" % [
			GameManager.bro_meter, GameManager.bro_joint_pending])
	_check(GameManager.joint_accident_count == joints_before + 1,
		"joint accident counted once (%d -> %d)" % [
			joints_before, GameManager.joint_accident_count])
	_check(GameManager.total_score == score_before - 300,
		"third mistake costs 100 + 200 joint (%d -> %d)" % [
			score_before, GameManager.total_score])
	await _frames(2)
	_check(race.hud.bro_meter_label.text.contains("3/3"),
		"hud bro meter shows 3/3 (%s)" % race.hud.bro_meter_label.text)

	# 演出在短硬直结束后开始。
	var shown := await _wait_for(func() -> bool:
		return GameManager.accident_state == "BRO_BREAK", 600)
	_check(shown, "joint show starts after the stun clears (state=%s)" % [
		GameManager.accident_state])
	_check(race.joint_show_t > 0.0, "joint show timer is running")
	_check(is_zero_approx(race.turtle.speed), "joint show holds the turtle still")
	_check(_center_msgs.any(func(m: String) -> bool: return m.contains("BRO METER")),
		"joint show is announced on screen (%s)" % \
			", ".join(PackedStringArray(_center_msgs)))
	var x_during: float = race.turtle.position.x

	# ---- 4. 恢复：位置、槽位、保护、本局继续 ----
	var ended := await _wait_for(func() -> bool:
		return race.joint_show_t <= 0.0 and GameManager.accident_state == "NONE", 600)
	_check(ended, "joint show ends and state returns to NONE")
	_check(GameManager.bro_meter == 0 and not GameManager.bro_joint_pending,
		"meter clears after the show (meter=%d)" % GameManager.bro_meter)
	_check(race.turtle.position.y == race.surface_ref(),
		"turtle is restored to cruise depth (y=%.0f want %.0f)" % [
			race.turtle.position.y, race.surface_ref()])
	_check(race.turtle.position.x >= x_during - 1.0,
		"turtle is not rewound by the punishment (x %.0f -> %.0f)" % [
			x_during, race.turtle.position.x])
	_check(race.mount.state == "RIDING" and race.rabbit.state == "RIDING",
		"rabbit is riding again (mount=%s rabbit=%s)" % [
			race.mount.state, race.rabbit.state])
	_check(race.rabbit_grace >= 1.4 and race.turtle_grace >= 1.4,
		"short protection granted (rabbit %.2f turtle %.2f)" % [
			race.rabbit_grace, race.turtle_grace])
	_check(GameManager.state == GameManager.GameState.RUNNING,
		"run continues after the joint punishment")
	await _frames(2)
	_check(race.hud.bro_meter_label.text.contains("0/3"),
		"hud bro meter shows 0/3 after recovery (%s)" % race.hud.bro_meter_label.text)

	# ---- 5. 重复触发：再满三格还能触发第二次。 ----
	var joints_before2: int = GameManager.joint_accident_count
	for _i in 3:
		await _wait_recovered()
		race._trigger_accident("RABBIT_STUN")
	_check(GameManager.joint_accident_count == joints_before2 + 1,
		"second joint accident triggers again (%d -> %d)" % [
			joints_before2, GameManager.joint_accident_count])
	var shown2 := await _wait_for(func() -> bool:
		return GameManager.accident_state == "BRO_BREAK", 600)
	_check(shown2, "second joint show starts")
	var ended2 := await _wait_for(func() -> bool:
		return race.joint_show_t <= 0.0 and GameManager.accident_state == "NONE", 600)
	_check(ended2 and GameManager.bro_meter == 0,
		"second joint show ends and clears the meter")

	Engine.time_scale = 1.0
	if failures.is_empty():
		print("STAGE4 BRO METER: PASS")
		get_tree().quit(0)
	else:
		print("STAGE4 BRO METER: FAIL")
		for item in failures:
			print("  - " + item)
		get_tree().quit(1)


func _wait_recovered() -> void:
	# 事故状态与冷却都归零、演出也结束，才能制造下一次“有效失误”。
	await _wait_for(func() -> bool:
		return race.hazard_cooldown <= 0.0 \
			and GameManager.accident_state == "NONE" \
			and race.joint_show_t <= 0.0, 1200)


func _wait_for(cond: Callable, max_frames: int) -> bool:
	var guard := 0
	while guard < max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
		guard += 1
	return cond.call()


func _on_center_message(text: String, _color: Color) -> void:
	_center_msgs.append(text)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(ok: bool, label: String) -> void:
	if ok:
		print("ok  " + label)
	else:
		failures.append(label)
		print("FAIL  " + label)
