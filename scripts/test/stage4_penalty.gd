extends Node
## 阶段 4 / Phase G 惩罚统一自检：
##   1. daze_time 只是短硬直/姿态，永远不单独触发 RABBIT_SLIP / TURTLE_REEF；
##   2. 每次有效碰撞（兔子撞障碍 / 乌龟撞浪）恰好记 1 格 BRO METER、扣 100；
##   3. 第三格播联合事故，结束后清格、复位、给宽限、本局继续；
##   4. 落水救援计 1 格，成功不退还，失败不追加；
##   5. 兔子/乌龟的事故表现可区分，各自不累积到临界。
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT res://scenes/stage4_penalty.tscn

const Tuning = preload("res://scripts/systems/tuning.gd")

var is_runner := false
var failures: Array[String] = []
var race


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4PenaltyRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	Engine.time_scale = 2.0
	await _fresh()
	race.test_disable_hazards = true

	# ---- 1. daze 不再是第二套事故系统 ----
	race.rabbit.daze_time = Tuning.SLIP_FALL_TIME + 2.0
	race.rabbit.slide = race.rabbit.slide_for_time(race.rabbit.daze_time)
	await _wait_physics(0.8)
	_check(GameManager.accident_state == "NONE",
		"rabbit daze above the old fall line triggers nothing (%s)" % \
			GameManager.accident_state)
	_check(race.mount.state == "RIDING", "rabbit stays mounted with high daze")
	race.rabbit.daze_time = 0.0
	race.rabbit.slide = 0.0

	race.turtle.daze_time = Tuning.SINK_DANGER_TIME + 2.0
	await _wait_physics(0.8)
	_check(GameManager.accident_state == "NONE",
		"turtle daze above the old danger line triggers nothing (%s)" % \
			GameManager.accident_state)
	_check(not race.turtle.accident, "turtle does not flip from daze alone")
	_check(race.turtle.state != "UNCONSCIOUS",
		"turtle stays conscious with high daze (%s)" % race.turtle.state)
	race.turtle.daze_time = 0.0

	# add_imbalance 的封顶：连续加也不会越过临界。
	for i in 5:
		race.rabbit.add_imbalance(Tuning.RABBIT_HIT_IMBALANCE)
		race.turtle.add_imbalance(Tuning.TURTLE_HIT_IMBALANCE)
	_check(race.rabbit.daze_time <= Tuning.DAZE_CAP + 0.01
		and race.turtle.daze_time <= Tuning.DAZE_CAP + 0.01,
		"add_imbalance is capped at DAZE_CAP (rabbit %.2f turtle %.2f)" % [
			race.rabbit.daze_time, race.turtle.daze_time])
	_check(not race.rabbit.is_falling(), "rabbit never reaches the fall line")

	# ---- 2. 每次有效碰撞记一格 ----
	await _fresh()
	race.test_disable_hazards = true
	GameManager.total_score = 1000
	var meter0: int = GameManager.bro_meter
	var accidents0: int = GameManager.accident_count

	race._turtle_contact("test_wave")
	await _physics_frames(1)
	_check(GameManager.bro_meter == meter0 + 1,
		"one shell hit fills exactly one slot (%d)" % GameManager.bro_meter)
	_check(GameManager.accident_count == accidents0 + 1,
		"one shell hit counts as one mistake (%d)" % GameManager.accident_count)
	_check(GameManager.total_score == 900,
		"one shell hit costs exactly 100 (%d)" % GameManager.total_score)
	_check(GameManager.accident_state == "NONE",
		"a shell hit is a mistake, not a forced accident state (%s)" % \
			GameManager.accident_state)
	_check(race.turtle.dunk_timer > 0.0, "shell hit dunks the group")
	_check(race.turtle.daze_time > 0.0 and race.rabbit.daze_time < 0.01,
		"shell hit only marks the turtle (turtle %.2f rabbit %.2f)" % [
			race.turtle.daze_time, race.rabbit.daze_time])

	# 兔子撞障碍：当场短硬直，同样是 1 格。
	race._rabbit_contact()
	await _physics_frames(1)
	_check(GameManager.accident_state == "RABBIT_STUN",
		"rabbit contact reads as RABBIT_STUN (%s)" % GameManager.accident_state)
	_check(GameManager.bro_meter == meter0 + 2,
		"rabbit contact fills the second slot (%d)" % GameManager.bro_meter)
	_check(race.rabbit.daze_time > 0.0 and race.turtle.daze_time < 3.7,
		"rabbit contact marks the rabbit without a second rabbit countdown")
	_check(race.rabbit.state == "STUNNED",
		"rabbit has its own stun expression (%s)" % race.rabbit.state)
	# 等硬直清掉，再补第三格。
	await _wait_for(func() -> bool:
		return GameManager.accident_state == "NONE", 240)

	race._turtle_contact("test_wave_2")
	await _physics_frames(1)
	_check(GameManager.bro_meter == 3 and GameManager.bro_joint_pending,
		"third mistake fills the meter and arms the joint show (%d)" % \
			GameManager.bro_meter)
	_check(GameManager.total_score == 500,
		"three mistakes cost 3x100 + 200 joint (score %d)" % GameManager.total_score)
	var shown := await _wait_for(func() -> bool:
		return GameManager.accident_state == "BRO_BREAK", 120)
	_check(shown, "joint show starts after the third mistake (%s)" % \
		GameManager.accident_state)

	# ---- 3. 联合事故后恢复 ----
	var ended := await _wait_for(func() -> bool:
		return GameManager.accident_state == "NONE" and race.joint_show_t <= 0.0, 300)
	_check(ended, "joint show ends and state returns to NONE")
	_check(GameManager.bro_meter == 0,
		"meter clears after the joint show (%d)" % GameManager.bro_meter)
	_check(race.turtle_grace > 0.0 and race.rabbit_grace > 0.0,
		"short protection granted (turtle %.2f rabbit %.2f)" % [
			race.turtle_grace, race.rabbit_grace])
	_check(absf(race.turtle.position.y - Tuning.NEUTRAL_DEPTH) < 2.0,
		"turtle is restored to cruise depth (%.1f)" % race.turtle.position.y)
	_check(GameManager.state == GameManager.GameState.RUNNING,
		"run continues after the joint accident")

	# ---- 4. 落水救援：计 1 格，成功不退，失败不加 ----
	await _fresh()
	race.test_disable_hazards = true
	GameManager.total_score = 1000
	race._trigger_accident("RABBIT_WATER")
	await _physics_frames(1)
	_check(GameManager.bro_meter == 1,
		"falling in the water costs one slot (%d)" % GameManager.bro_meter)
	_check(GameManager.accident_state == "RABBIT_WATER",
		"water rescue is active (%s)" % GameManager.accident_state)
	var score_after_accident: int = GameManager.total_score
	race._rescue_catch(race.turtle.get_mount_point())
	await _physics_frames(1)
	_check(GameManager.accident_state == "NONE",
		"catching the rabbit ends the accident (%s)" % GameManager.accident_state)
	_check(GameManager.bro_meter == 1,
		"rescue success does not refund the slot (%d)" % GameManager.bro_meter)
	# REBUILD-05 D2 起，救回重聚本身给 +50（只加不减，见 race.gd 的 rescue 分支）；
	# 这里要验的仍然是“不会把扣掉的那 100 还回来”，所以按 1000-100+50 判。
	_check(GameManager.total_score == score_after_accident + Tuning.RESCUE_SWITCH_BONUS,
		"rescue success only adds the reunion bonus (%d)" % \
			GameManager.total_score)
	_check(race.mount.state == "RIDING", "rabbit is back on the shell")

	await _fresh()
	race.test_disable_hazards = true
	race._trigger_accident("RABBIT_WATER")
	await _physics_frames(1)
	race._rescue_miss()
	await _physics_frames(1)
	_check(GameManager.bro_meter == 1,
		"rescue miss adds no extra slot (%d)" % GameManager.bro_meter)
	await _wait_for(func() -> bool:
		return GameManager.accident_state == "NONE" and race.mount.state == "RIDING", 240)
	_check(GameManager.bro_meter == 1,
		"rescue miss still leaves exactly one mistake (%d)" % GameManager.bro_meter)

	# ---- 4b. 同一次连续碰撞只记一次（走真实判定框，不是直接调用）----
	await _fresh()
	race.test_disable_hazards = false
	var shark_rect := Rect2()
	for g in race.hazard_groups:
		if g["kind"] == "SHARK":
			# REBUILD-06 P3：鲨鱼会潜伏/上冲，判定框不再等于基础框。
			# 取“此刻”的框，才能把壳放进真正会被判的位置。
			shark_rect = race.hazard_rect_live(g, 0)
			break
	race.turtle.position = shark_rect.get_center()
	var meter_b: int = GameManager.bro_meter
	race._check_hazards()
	race._check_hazards()
	await _physics_frames(1)
	_check(GameManager.bro_meter == meter_b + 1,
		"one continuous collision counts once through hit_groups (%d -> %d)" % [
			meter_b, GameManager.bro_meter])
	_check(race.hit_groups.size() > 0, "the collided group is marked as hit")

	# ---- 5. 正常动作不涨格 ----
	await _fresh()
	race.test_disable_hazards = true
	var meter_n: int = GameManager.bro_meter
	var score_n: int = GameManager.total_score
	GameManager.set_control("turtle")
	await _physics_frames(2)
	Input.action_press("up")
	await _physics_frames(3)
	Input.action_release("up")
	await _physics_frames(2)
	Input.action_press("down")
	await _physics_frames(6)
	Input.action_release("down")
	GameManager.set_control("rabbit")
	await _physics_frames(2)
	Input.action_press("up")
	await _physics_frames(3)
	Input.action_release("up")
	await _physics_frames(2)
	GameManager.toggle_control()
	await _physics_frames(2)
	_check(GameManager.bro_meter == meter_n,
		"jump/leap/dive/SHIFT add no slots (%d -> %d)" % [
			meter_n, GameManager.bro_meter])
	_check(GameManager.total_score == score_n,
		"jump/leap/dive/SHIFT cost no score (%d -> %d)" % [
			score_n, GameManager.total_score])

	Engine.time_scale = 1.0
	if failures.is_empty():
		print("STAGE4 PENALTY: PASS")
		get_tree().quit(0)
	else:
		print("STAGE4 PENALTY: FAIL")
		for item in failures:
			print("  - " + item)
		get_tree().quit(1)


func _fresh() -> void:
	GameManager.start_race()
	await _frames(4)
	race = get_tree().current_scene


func _wait_for(cond: Callable, max_frames: int) -> bool:
	var guard := 0
	while guard < max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
		guard += 1
	return cond.call()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_physics(seconds: float) -> void:
	var guard := 0
	while guard < int(seconds * 60.0) and guard < 600:
		await get_tree().physics_frame
		guard += 1


func _check(ok: bool, label: String) -> void:
	if ok:
		print("ok  " + label)
	else:
		failures.append(label)
		print("FAIL  " + label)
