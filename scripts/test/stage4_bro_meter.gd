extends Node
## FEEL-11 回归：BRO 槽的新语义。
## 旧版“三格满 = 联合”已被 FEEL-10 取代：
##   三格满 → 只让本次失误角色短暂捣乱；真联合 = 两人 0.6 s 内同时真实危险。
## 这个测试替代 FEEL-07 时代的“三格触发联合”用例。

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
	GameManager.test_no_best = true
	GameManager.start_race()
	await _frames(6)
	race = get_tree().current_scene
	_check(race != null and race.scene_file_path.ends_with("race.tscn"),
		"race scene loads")
	race.test_disable_hazards = true
	race.test_no_finish = true
	race.load_level([], [])
	race._od_phase = ""
	race._od_role = ""
	race._od_cd = 0.0
	GameManager.center_message.connect(_on_center_message)
	GameManager.total_score = 2000
	await _frames(2)

	# 1. 正常动作不涨槽。
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
		"normal jump/dive/SHIFT do not fill the meter")
	_check(GameManager.total_score == score0, "normal actions cost no score")
	# 快速两次 toggle 的第二次会被 0.2 s 锁拒绝；后面的三格测试必须在兔子身上。
	GameManager.current_control = "rabbit"
	GameManager.shift_lock_t = 0.0

	# 2. 单角色失误：三格满只武装该角色，不触发联合。
	await _wait_recovered()
	race._trigger_accident("RABBIT_STUN")
	_check(GameManager.bro_meter == 1 and not GameManager.role_mischief_pending,
		"first slot filled")
	await _wait_recovered()
	race._trigger_accident("RABBIT_STUN")
	_check(GameManager.bro_meter == 2, "second slot filled")
	await _wait_recovered()
	var joints0: int = GameManager.joint_accident_count
	race._trigger_accident("RABBIT_STUN")
	var armed: bool = GameManager.role_mischief_pending or String(race._burst_who) == "rabbit"
	_check(GameManager.bro_meter == 3 and armed,
		"third slot keeps full meter and arms the offending role (meter=%d armed=%s)" % [
			GameManager.bro_meter, str(armed)])
	_check(GameManager.role_mischief_role in ["", "rabbit"],
		"only the offending role is marked (%s)" % GameManager.role_mischief_role)
	_check(GameManager.joint_accident_count == joints0,
		"three slots do NOT trigger a joint (%d -> %d)" % [
			joints0, GameManager.joint_accident_count])
	_check(GameManager.accident_state != "BRO_BREAK",
		"no full-team freeze on meter full (%s)" % GameManager.accident_state)
	await _frames(2)
	_check(race.hud.bro_meter_label.text.contains("3/3"),
		"hud shows full meter after the third slot (%s)" % \
			race.hud.bro_meter_label.text)
	# FEEL-15：第三格不再驱动 OVERDRIVE；角色满格后，只有它变成“未受控”才捣乱。
	await _wait_recovered()
	GameManager.current_control = "rabbit"
	GameManager.shift_lock_t = 0.0
	GameManager.toggle_control() # -> turtle; rabbit becomes uncontrolled
	race._mischief_last_control = "turtle"
	race._tick_mischief(1.0 / 60.0)
	_check(race._mischief_role == "rabbit",
		"uncontrolled full role starts MISCHIEF (%s)" % race._mischief_role)
	var ended_mischief := await _wait_for(func() -> bool:
		return race._mischief_role == "" and GameManager.role_meter("rabbit") == 0, 300)
	_check(ended_mischief, "mischief ends and resets the role meter")

	# 3. 真联合：两人同时真实危险。
	await _wait_recovered()
	var joints1: int = GameManager.joint_accident_count
	race.rabbit.state = "FALLING_WATER"
	race.mount.state = "RESCUE_FALLING"
	race.turtle.accident = true
	race.accident_event_time = 0.0
	race._rabbit_danger_since = 0.0
	race._turtle_danger_since = 0.0
	race._joint_episode_done = false
	GameManager.accident_state = "NONE"
	race._update_true_joint(0.0)
	_check(GameManager.joint_accident_count == joints1 + 1,
		"true joint counted once (%d -> %d)" % [
			joints1, GameManager.joint_accident_count])
	_check(GameManager.accident_state == "BRO_BREAK" and race.joint_show_t > 0.0,
		"joint show starts (%s show=%.2f)" % [GameManager.accident_state,
			float(race.joint_show_t)])
	_check(_center_msgs.any(func(m: String) -> bool:
		return m.contains("两人同时出事") or m.contains("BOTH IN TROUBLE")),
		"joint show explains both-in-trouble, not meter-full (%s)" % \
			", ".join(PackedStringArray(_center_msgs)))
	var ended := await _wait_for(func() -> bool:
		return race.joint_show_t <= 0.0 and GameManager.accident_state == "NONE", 600)
	_check(ended, "joint show ends and state clears")
	_check(race.mount.state == "RIDING" and race.rabbit.state == "RIDING",
		"rabbit rides again (%s/%s)" % [race.mount.state, race.rabbit.state])

	Engine.time_scale = 1.0
	GameManager.test_no_best = false
	if failures.is_empty():
		print("STAGE4 BRO METER: PASS")
		get_tree().quit(0)
	else:
		print("STAGE4 BRO METER: FAIL")
		for item in failures:
			print("  - " + item)
		get_tree().quit(1)


func _wait_recovered() -> void:
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


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok  " + message)
	else:
		failures.append(message)
		print("  FAIL " + message)
