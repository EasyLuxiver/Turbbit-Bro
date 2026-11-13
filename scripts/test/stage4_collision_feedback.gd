extends Node
## 阶段 4 P1-5 验收（TBB-SHIFT-FEEL-03）：碰撞 / 落地 / 主动动作的反馈。
##
## 真实关卡、真实物理、引擎按键代理。五段：
##   rabbit_stun —— 兔子撞岩：40–60 ms 表现停顿 + 2–3 px 震动，判定不变
##   turtle_wave —— 乌龟撞礁拱：更重的 90 ms 停顿 + 5–8 px 震动，判定不变
##   landing     —— 兔子落回壳：落地水花记在真实落点
##   dive_fx     —— BRO DIVE 通过浮木：青色成功反馈（与 OLLIE 区分）
##   ollie_fx    —— BRO OLLIE 通过高墙：金色成功反馈
##
## 表现停顿只冻结“画出来的位置”；本探针同时记录物理速度/事故状态/碰撞组，
## 证明判定结果与改动前逐条一致（速度 ×0.6、RABBIT_STUN、bro_meter +1 等）。
##
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT \
##       res://scenes/stage4_collision_feedback.tscn
## 输出：docs/reports/longrun/phase-v-collision-feedback.json

const Tuning = preload("res://scripts/systems/tuning.gd")
const LevelData = preload("res://scripts/systems/level_data.gd")
const OUT_PATH := "res://docs/reports/longrun/phase-v-collision-feedback.json"

var is_runner := false
var race
var sim := 0.0
var rows: Array = []
var failures: Array[String] = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4CollisionFeedbackRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 3.0
	await get_tree().process_frame
	await _run()


func _run() -> void:
	GameManager.start_race()
	for i in 3:
		await get_tree().process_frame
	race = get_tree().current_scene
	_check(race != null and race.scene_file_path.ends_with("race.tscn"),
		"formal race scene loaded")
	if race == null:
		_finish()
		return
	race.test_no_finish = true
	race.test_disable_hazards = false

	for case_name in ["rabbit_stun", "turtle_wave", "landing", "dive_fx", "ollie_fx"]:
		race.load_level(LevelData.groups(), LevelData.boost_lanes())
		await get_tree().physics_frame
		sim = 0.0
		var row: Dictionary = {}
		match case_name:
			"rabbit_stun":
				row = await _case_rabbit_stun()
			"turtle_wave":
				row = await _case_turtle_wave()
			"landing":
				row = await _case_landing()
			"dive_fx":
				row = await _case_dive_fx()
			"ollie_fx":
				row = await _case_ollie_fx()
		rows.append(row)

	Engine.time_scale = 1.0
	_write_json()
	_finish()


# ---------------- 案例 ----------------

func _case_rabbit_stun() -> Dictionary:
	_reset(2150.0, "turtle")
	var v: float = race.turtle.base_speed
	var steps := 0
	while steps < 60 * 8 and not race.hit_groups.has("rock1") \
			and GameManager.accident_state == "NONE":
		await _step()
		steps += 1
	var hs: Dictionary = race.hitstop_log.back() if not race.hitstop_log.is_empty() else {}
	var sh: Dictionary = race.shake_log.back() if not race.shake_log.is_empty() else {}
	var acc: String = GameManager.accident_state
	var speed_at: float = race.turtle.speed
	var ratio: float = speed_at / v
	var stun: float = race.rabbit_stun
	var peak := 0.0
	for i in 6:
		await _step()
	peak = race._shake_peak
	var checks := {
		"hit_rock1": race.hit_groups.has("rock1"),
		"accident_rabbit_stun": acc == "RABBIT_STUN",
		"rabbit_stunned": race.rabbit.state == "STUNNED",
		"stun_time_unchanged": absf(stun - Tuning.STUN_TIME) < 0.11,
		"turtle_speed_x06": absf(ratio - 0.6) < 0.03,
		"hitstop_40_60ms": not hs.is_empty() and String(hs["who"]) == "rabbit" \
			and float(hs["s"]) >= 0.04 and float(hs["s"]) <= 0.06,
		"shake_amp_2_3px": not sh.is_empty() and not bool(sh["major"]) \
			and float(sh["amp"]) >= 2.0 and float(sh["amp"]) <= 3.0,
		"shake_peak_2_3px": peak >= 2.0 and peak <= 3.0,
	}
	return _row("rabbit_stun", 2150.0, checks, {
		"accident": acc, "turtle_speed": snappedf(speed_at, 0.1),
		"base_speed": v, "hitstop": hs, "shake": sh,
		"shake_peak_px": snappedf(peak, 0.01), "stun": snappedf(stun, 0.01),
	})


func _case_turtle_wave() -> Dictionary:
	_reset(3350.0, "turtle")
	var v: float = race.turtle.base_speed
	var steps := 0
	while steps < 60 * 8 and not race.hit_groups.has("gate1") \
			and GameManager.accident_state == "NONE":
		await _step()
		steps += 1
	var hs: Dictionary = race.hitstop_log.back() if not race.hitstop_log.is_empty() else {}
	var sh: Dictionary = race.shake_log.back() if not race.shake_log.is_empty() else {}
	var acc: String = GameManager.accident_state
	var speed_at: float = race.turtle.speed
	var ratio: float = speed_at / v
	var dunk: float = race.turtle.dunk_timer
	var peak := 0.0
	for i in 6:
		await _step()
	peak = race._shake_peak
	var checks := {
		"hit_gate1": race.hit_groups.has("gate1"),
		"accident_none": acc == "NONE",
		"turtle_dunked": dunk > 0.0,
		"turtle_speed_x06": absf(ratio - 0.6) < 0.03,
		"bro_meter_1": GameManager.bro_meter == 1,
		"hitstop_80_100ms": not hs.is_empty() and String(hs["who"]) == "turtle" \
			and float(hs["s"]) >= 0.07 and float(hs["s"]) <= 0.10,
		"shake_amp_5_8px": not sh.is_empty() and bool(sh["major"]) \
			and float(sh["amp"]) >= 5.0 and float(sh["amp"]) <= 8.0,
		"shake_peak_5_8px": peak >= 5.0 and peak <= 8.0,
	}
	return _row("turtle_wave", 3350.0, checks, {
		"accident": acc, "turtle_speed": snappedf(speed_at, 0.1),
		"base_speed": v, "hitstop": hs, "shake": sh,
		"shake_peak_px": snappedf(peak, 0.01), "dunk": snappedf(dunk, 0.01),
		"bro_meter": GameManager.bro_meter,
	})


func _case_landing() -> Dictionary:
	_reset(4300.0, "rabbit")
	var pickup0: int = GameManager.pickup_count
	await _until_x(4420.0)
	_press("up")
	await _step()
	if race.mount.state != "AIRBORNE":
		await _step()
	_release("up")
	var airborne: bool = race.mount.state == "AIRBORNE"
	var landed := false
	var guard := 0
	while guard < 300 and GameManager.accident_state == "NONE":
		await _step()
		guard += 1
		if race.mount.state == "RIDING" and not race.mount.state == "AIRBORNE":
			landed = true
			break
	var splash_t: float = race.land_splash_t
	var splash_d: float = race.land_splash_pos.distance_to(race.rabbit.position)
	var checks := {
		"jumped": airborne,
		"landed": landed,
		"pickup_counted": GameManager.pickup_count == pickup0 + 1,
		"splash_started": splash_t >= 0.0 and splash_t <= 0.2,
		"splash_at_real_landing": splash_d <= 24.0,
		"clean": GameManager.accident_state == "NONE",
	}
	# 0.4 s 后水花自己消失，不会挂在画面上。
	guard = 0
	while guard < 30 and race.land_splash_t >= 0.0:
		await _step()
		guard += 1
	checks["splash_expires"] = race.land_splash_t < 0.0
	return _row("landing", 4300.0, checks, {
		"splash_t": snappedf(splash_t, 0.01),
		"splash_dx_from_rabbit": snappedf(splash_d, 0.1),
		"pickup_count": GameManager.pickup_count,
	})


func _case_dive_fx() -> Dictionary:
	_reset(5900.0, "turtle")
	await _settle(6150.0)
	await _control_to("rabbit")
	var press_x: float = 6400.0 - (float(race.turtle.base_speed) * 0.7 - 2.0)
	await _until_x(press_x)
	_press("up")
	await _step()
	if race.mount.state != "AIRBORNE":
		await _step()
	_release("up")
	_press("down")
	await _control_to("turtle")
	var guard := 0
	# 浮木尾端 6432：壳要带着下潜保持到 6462（尾端后 30 px）再上浮，否则
	# 壳左侧还在木下就开始抬，会蹭到木的下沿（实测 6472 处 y=431 撞上）。
	while guard < 600 and race.turtle.position.x < 6462.0 \
			and GameManager.accident_state == "NONE":
		await _step()
		guard += 1
	_release("down")
	guard = 0
	while guard < 400 and not race.passed_groups.has("log1") \
			and GameManager.accident_state == "NONE":
		await _step()
		guard += 1
	var fx: Dictionary = race.action_fx_log.back() if not race.action_fx_log.is_empty() else {}
	var checks := {
		"passed_log1": race.passed_groups.has("log1"),
		"no_contact": race.hit_groups.is_empty(),
		"clean": GameManager.accident_state == "NONE",
		"dive_fx": not fx.is_empty() and String(fx["kind"]) == "dive",
	}
	return _row("dive_fx", 5900.0, checks, {
		"fx": fx, "fx_log": race.action_fx_log,
		"combo": race.combo, "hit_groups": race.hit_groups.keys(),
	})


func _case_ollie_fx() -> Dictionary:
	# P6 换位后 wall1 在 10860（原 13300），重置点随之前移。
	_reset(10100.0, "turtle")
	var start := 10860.0
	var lead: float = float(race.turtle.base_speed) * 0.8
	await _settle(start - lead)
	# 壳跃起
	_press("up")
	await _step()
	await _step()
	_release("up")
	var leaped: bool = race.turtle.leap_active
	# 换到兔子，在墙前 90 px 蹬踏（第二跳）
	await _control_to("rabbit")
	var guard := 0
	while guard < 240 and race.turtle.position.x < start - 90.0 \
			and GameManager.accident_state == "NONE":
		await _step()
		guard += 1
	_press("up")
	await _step()
	await _step()
	_release("up")
	await _control_to("turtle")
	guard = 0
	while guard < 400 and not race.passed_groups.has("wall1") \
			and GameManager.accident_state == "NONE":
		await _step()
		guard += 1
	var fx: Dictionary = race.action_fx_log.back() if not race.action_fx_log.is_empty() else {}
	var checks := {
		"leaped": leaped,
		"passed_wall1": race.passed_groups.has("wall1"),
		"no_contact": race.hit_groups.is_empty(),
		"clean": GameManager.accident_state == "NONE",
		"ollie_fx": not fx.is_empty() and String(fx["kind"]) == "ollie",
		"distinct_from_dive": fx.is_empty() or String(fx.get("kind", "")) == "ollie",
	}
	return _row("ollie_fx", 12600.0, checks, {
		"fx": fx, "fx_log": race.action_fx_log,
		"combo": race.combo, "hit_groups": race.hit_groups.keys(),
	})


# ---------------- 驱动 ----------------

func _reset(x: float, control: String) -> void:
	_release_all()
	sim = 0.0
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.oxygen = Tuning.OXYGEN_MAX
	GameManager.showtime_active = false
	GameManager.current_control = control
	GameManager.has_shifted = true
	GameManager.pickup_window = false
	GameManager.bro_meter = 0
	race.showtime_active = false
	race.showtime_t = 0.0
	race.finishing = false
	race.hazard_cooldown = 0.0
	race.turtle_repair = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.rabbit_stun = 0.0
	race.emergency_timer = 0.0
	race.combo = 0
	# G20：hit_roles 必须和 hit_groups 一起清。只清 hit_groups 时，B2 起的“角色×组”记账还留着，同组第二例起整组免疫——后面那些重复用例其实在测一段不会撞的赛道。
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.group_actions.clear()
	race.hitstop_log.clear()
	race.shake_log.clear()
	race.action_fx_log.clear()
	race._hitstop_t = 0.0
	race._hitstop_who = ""
	race._shake_t = 0.0
	race._shake_peak = 0.0
	race.land_splash_t = -1.0
	race.action_fx_t = -1.0
	race.accident_flash = 0.0
	var zone: Dictionary = LevelData.zone_at(x)
	race.current_zone = zone
	var speed: float = float(zone["base_speed"])
	race.turtle.reset(Vector2(x, Tuning.NEUTRAL_DEPTH))
	race.turtle.speed = speed
	race.turtle.base_speed = speed
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()


func _settle(target_x: float) -> void:
	var guard := 0
	while race.turtle.position.x < target_x and guard < 900 \
			and GameManager.accident_state == "NONE":
		await _step()
		guard += 1
	guard = 0
	while race.turtle.position.y > 400.0 and guard < 300 \
			and GameManager.accident_state == "NONE":
		await _step()
		guard += 1


func _until_x(target: float) -> void:
	var guard := 0
	while race.turtle.position.x < target and guard < 600 \
			and GameManager.accident_state == "NONE":
		await _step()
		guard += 1


func _control_to(who: String) -> void:
	if GameManager.current_control == who:
		return
	var guard := 0
	while GameManager.current_control != who and guard < 30:
		if race.showtime_active:
			await _step()
			guard += 1
			continue
		GameManager.toggle_control()
		await _step()
		guard += 1


func _press(action: String) -> void:
	if not Input.is_action_pressed(action):
		Input.action_press(action)


func _release(action: String) -> void:
	if Input.is_action_pressed(action):
		Input.action_release(action)


func _release_all() -> void:
	for a in ["up", "down", "shift"]:
		Input.action_release(a)


func _step() -> void:
	await get_tree().physics_frame
	sim += (1.0 / 60.0) * Engine.time_scale


# ---------------- 结果 ----------------

func _row(name: String, start_x: float, checks: Dictionary, data: Dictionary) -> Dictionary:
	var ok := true
	for k in checks:
		if not bool(checks[k]):
			ok = false
			_check(false, "%s: %s" % [name, k])
	var row := {
		"case": name, "start_x": start_x, "sim_s": snappedf(sim, 0.01),
		"checks": checks, "pass": ok,
	}
	for k in data:
		row[k] = data[k]
	print("COLLISION %-12s pass=%s %s" % [name, str(ok), str(checks)])
	return row


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)


func _write_json() -> void:
	var data := {
		"generated_at": Time.get_datetime_string_from_system(),
		"note": "P1-5 collision/action feedback: real physics + engine input proxy; not a human playtest.",
		"hitstop_rabbit_s": race.HITSTOP_RABBIT,
		"hitstop_turtle_s": race.HITSTOP_TURTLE,
		"shake_normal_px": race.SHAKE_NORMAL_PX,
		"shake_major_px": race.SHAKE_MAJOR_PX,
		"rows": rows,
	}
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
		f.close()


func _finish() -> void:
	if failures.is_empty():
		print("STAGE4 COLLISION FEEDBACK: PASS")
	else:
		print("STAGE4 COLLISION FEEDBACK: FAIL")
		for item in failures:
			print("  - " + item)
	get_tree().quit(0 if failures.is_empty() else 1)
