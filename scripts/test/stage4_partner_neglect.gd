extends Node
## 阶段 4 伙伴后果验收（TBB-SHIFT-FEEL-03 §4 / P0-3）。
##
## 验证“管与不管真的有区别”，并且区别可理解、可预防：
##   neglect  兔子在 MISCHIEF（drift=10），玩家一直控乌龟 → 低梁前站直探头，
##            擦到梁 → RABBIT_STUN + 连击清零 + BRO METER +1；不落水。
##   care     同样的 drift，玩家提前切回兔子并趴低 → 干净通过，姿势消失。
##   drift    只让神游跑 12 s（无障碍）→ 不增加 BRO METER、不产生事故。
##
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT res://scenes/stage4_partner_neglect.tscn
## 输出：docs/reports/stage4-partner-neglect.json
##
## 不是人工试玩：只证明两条真实玩法的结果差异。

const Tuning = preload("res://scripts/systems/tuning.gd")
const OUT_PATH := "res://docs/reports/stage4-partner-neglect.json"
const STEP := 1.0 / 60.0
const BEAM_X := 14550.0
const BEAM_W := 170.0
const START_X := 13600.0

var is_runner := false
var failures: Array[String] = []
var race
var data := {}


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4PartnerNeglectRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	Locale.language = "en"
	GameManager.start_race()
	await _wait_scene("race.tscn")
	await _frames(4)
	race = get_tree().current_scene
	_check(race != null, "race scene loaded")
	if race == null:
		_finish()
		return
	race.test_no_finish = true
	race.set_physics_process(false)

	data["drift_only"] = _drift_only()
	data["neglect"] = _run_encounter(false)
	data["care"] = _run_encounter(true)

	_check(data["drift_only"]["bro_meter_delta"] == 0,
		"12 s drift alone adds no BRO METER (%d)" % data["drift_only"]["bro_meter_delta"])
	_check(data["drift_only"]["accident"] == "NONE",
		"12 s drift alone triggers no accident (%s)" % data["drift_only"]["accident"])

	var neg: Dictionary = data["neglect"]
	var care: Dictionary = data["care"]
	_check(neg["hit"], "neglected MISCHIEF rabbit grazes the low beam")
	_check(neg["accident_at_contact"] == "RABBIT_STUN",
		"graze is a stun, not a water fall (%s)" % neg["accident_at_contact"])
	_check(neg["pose_frames"] > 0, "wrong posture was held before contact (%d frames)"
		% neg["pose_frames"])
	_check(neg["bro_meter_delta"] >= 1, "real mistake costs BRO METER (+%d)"
		% neg["bro_meter_delta"])
	_check(neg["combo_after"] == 0, "real contact resets the combo")
	_check(not care["hit"], "cared-for rabbit passes the same beam clean")
	_check(care["was_crouching"], "takeover let the player crouch in time")
	_check(care["pose_after_takeover"] == 0,
		"posture disappears immediately after taking control")
	_check(care["bro_meter_delta"] == 0, "clean pass costs no BRO METER")
	_check(not neg["water_fall"] and not care["water_fall"], "neither run ends in a water fall")
	_write_json()
	_finish()


## 只跑神游：无输入、无障碍。drift 到 12 s 封顶也不产生惩罚。
func _drift_only() -> Dictionary:
	_setup(false)
	race.test_disable_hazards = true
	race.rabbit_brain.drift = Tuning.DRIFT_CAP
	var meter0: int = GameManager.bro_meter
	var acc0: int = GameManager.accident_count
	for i in 720:
		_tick(1)
	var out := {
		"bro_meter_delta": GameManager.bro_meter - meter0,
		"accident_delta": GameManager.accident_count - acc0,
		"accident": GameManager.accident_state,
		"drift": snappedf(race.rabbit_brain.drift, 0.01),
		"state": race.rabbit_brain.state_name(),
		"mount": race.mount.state,
	}
	race.test_disable_hazards = false
	return out


## 同一条低梁的两次真实通过：不管（一直控乌龟）vs 管（提前切兔子趴低）。
func _run_encounter(take_over: bool) -> Dictionary:
	_setup(true)
	race.rabbit_brain.drift = 10.0
	var meter0: int = GameManager.bro_meter
	var accident_at_contact := ""
	var pose_frames := 0
	var pose_after_takeover := 0
	var crouch_seen := false
	var took_over := false
	var contact_x := -1.0
	var hit := false
	var water_fall := false
	var n := 0
	while n < 900:
		var x: float = race.turtle.position.x
		if take_over and not took_over and BEAM_X - x <= 420.0:
			GameManager.toggle_control()
			took_over = true
		if take_over and x >= BEAM_X - 150.0 and x <= BEAM_X + BEAM_W + 80.0:
			if not Input.is_action_pressed("down"):
				Input.action_press("down")
		elif Input.is_action_pressed("down"):
			Input.action_release("down")
		if took_over and race.rabbit.mischief_pose:
			pose_after_takeover += 1
		if not took_over and race.rabbit.mischief_pose:
			pose_frames += 1
		if race.rabbit.state == "CROUCHING":
			crouch_seen = true
		_tick(1)
		n += 1
		if not hit and race.hit_groups.has("beam1"):
			hit = true
			contact_x = x
			accident_at_contact = GameManager.accident_state
		if GameManager.accident_state == "RABBIT_WATER":
			water_fall = true
		if race.turtle.position.x > BEAM_X + BEAM_W + 220.0:
			break
	Input.action_release("down")
	# 让事故恢复走完，别把中途状态当成结束状态。
	var guard := 0
	while GameManager.accident_state != "NONE" and guard < 300:
		_tick(1)
		guard += 1
	return {
		"take_over": take_over,
		"hit": hit,
		"contact_x": snappedf(contact_x, 0.1),
		"accident_at_contact": accident_at_contact,
		"accident_end": GameManager.accident_state,
		"water_fall": water_fall,
		"pose_frames": pose_frames,
		"pose_after_takeover": pose_after_takeover,
		"was_crouching": crouch_seen,
		"bro_meter_delta": GameManager.bro_meter - meter0,
		"combo_after": race.combo,
		"ticks": n,
	}


func _setup(with_hazard: bool) -> void:
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.showtime_active = false
	GameManager.bro_meter = 0
	GameManager.bro_joint_pending = false
	GameManager.shift_count = 0
	race.showtime_active = false
	race.test_disable_hazards = not with_hazard
	# G20：hit_roles 必须和 hit_groups 一起清。只清 hit_groups 时，B2 起的“角色×组”记账还留着，同组第二例起整组免疫——后面那些重复用例其实在测一段不会撞的赛道。
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.combo = 0
	race.hazard_cooldown = 0.0
	race.boost_lanes.clear()
	race.turtle.reset(Vector2(START_X, Tuning.NEUTRAL_DEPTH))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.reset_brains()
	GameManager.set_control("turtle")
	race.rabbit_grace = 0.0
	race.rabbit_stun = 0.0
	Input.action_release("up")
	Input.action_release("down")
	_tick(2)


func _tick(n: int) -> void:
	for i in n:
		race._physics_process(STEP)


func _wait_scene(suffix: String) -> void:
	for i in 240:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path.ends_with(suffix):
			return
	_check(false, "scene %s loaded" % suffix)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)


func _write_json() -> void:
	var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if file == null:
		failures.append("write %s" % OUT_PATH)
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()


func _finish() -> void:
	Locale.language = "zh"
	if failures.is_empty():
		print("STAGE4 PARTNER NEGLECT: PASS")
	else:
		print("STAGE4 PARTNER NEGLECT: FAIL")
		for item in failures:
			print("  - " + item)
	print("  data: " + JSON.stringify(data))
	get_tree().quit(0 if failures.is_empty() else 1)
