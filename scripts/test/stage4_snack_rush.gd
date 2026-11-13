extends Node
## PHASE O — TURTLE SNACK RUSH 原型的自动化验证（真实物理 + 引擎按键代理）
##
## 只测“吃 / 不吃 / 吃了不操作”三种驱动的结果，不猜手感。
## 三个 case 都从 x=2720 出发，跑过 Z1 第一处食物（x=3250）和它后面的
## 固定障碍 gate1（3800–3980，P1-4 起第一组就是礁拱）：
##   eat  —— 操控乌龟经过食物（碰到就吃），再按住 ↓ 下潜钻过礁拱；
##   skip —— 操控乌龟在食物前跃起从上方越过（不进食，不应有任何惩罚），
##           落地后按住 ↓ 下潜钻过礁拱。2026-11-12 起“换操控兔子”不再是合法跳过：
##           食物判定只看乌龟位置，谁在操控都会吃；不吃只能用 ↑/↓ 主动离开食物层。
##   hit  —— 操控乌龟吃下后不操作：加速期间碰撞必须仍然生效（撞礁拱）。
##
## 用法：
##   D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
##       res://scenes/stage4_snack_rush.tscn > docs/reports/logs/phase-o/snack-rush.log 2>&1
##
## 输出：docs/reports/longrun/phase-o-snack.json

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/phase-o-snack.json"
## 从 rock1 尾端之后出发：rock1 在 2500–2610，站进岩里会立刻判兔子撞岩，
## 把“不进食无惩罚”的基线污染成一次失误（2610 → 2720 留 110 px 余量）。
## 食物仍在 3250（gate1 3800 − SNACK_LEAD 被加速带右端夹住），后面是 gate1。
const START_X := 2720.0
const END_X := 4600.0
const VISIBLE_X := 2700.0   # gate1(3800) − PROMPT_RANGE(1100)
const OBSTACLE_X := 3800.0

var is_runner := false
var race: Node = null
var sim := 0.0
var rows: Array = []
var step_hz := 60.0


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 8.0
	Engine.physics_ticks_per_second = int(step_hz * Engine.time_scale)
	await get_tree().process_frame
	await _run()


func _run() -> void:
	GameManager.start_race()
	for i in 3:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null:
		push_error("SNACK: no current scene")
		_finish(1)
		return
	race.test_disable_hazards = false
	race.test_no_finish = true

	for case_name in ["eat", "skip", "hit"]:
		rows.append(await _run_case(case_name))

	_write()
	var fails := 0
	for r in rows:
		if not bool(r["pass"]):
			fails += 1
	print("SNACK: DONE cases=%d fails=%d" % [rows.size(), fails])
	_finish(0 if fails == 0 else 1)


func _run_case(case_name: String) -> Dictionary:
	# 每个 case 重新装一份关卡：食物 eaten 标记、加速、缓存全部复位。
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	await get_tree().physics_frame
	_reset(START_X, "turtle")
	sim = 0.0
	var v: float = float(race.current_zone["base_speed"])

	var t_visible := -1.0
	# G16：亲手喂到计数按 case 取增量（计数只在 start_race 归零，三例共用一局）。
	var fed_before: int = GameManager.snack_switch_count
	var switch_scores_before := _count_switch_scores()
	var t_collide := -1.0
	var eaten := false
	var eaten_at := -1.0
	var speed_at_contact := 0.0
	var boost_target := 0.0
	var speed_at_3400 := 0.0
	var max_speed := 0.0
	var boost_at_obstacle := false
	var steps := 0
	var dived := false
	var leap_pressed := false
	var last_bro: int = GameManager.bro_meter

	while sim < 12.0 and steps < 60 * 12:
		var x: float = race.turtle.position.x
		if case_name == "eat" and not dived and x >= 3300.0:
			# 吃完之后（3250）立刻按住 ↓：礁拱的答案是乌龟下潜。
			_press("down")
			dived = true
		if case_name == "skip":
			# 食物在 3250：2990 起跳，整段接触窗口（3180–3320）都在空中。
			if not leap_pressed and x >= 2990.0:
				_press("up")
				leap_pressed = true
			if leap_pressed and not dived and x >= 3360.0 and not race.turtle.leap_active:
				_release("up")
				_press("down")
				dived = true
		if t_visible < 0.0 and x >= VISIBLE_X:
			t_visible = sim
		if not eaten and race.snack_last_eaten != "":
			eaten = true
			eaten_at = sim
			speed_at_contact = race.turtle.speed
			boost_target = race.snack_boost_speed
		if absf(x - 3400.0) < 6.0:
			speed_at_3400 = race.turtle.speed
		max_speed = maxf(max_speed, race.turtle.speed)
		if GameManager.bro_meter != last_bro:
			print("  BRO %d->%d at x=%.0f t=%.2f acc=%s" % [last_bro,
				GameManager.bro_meter, x, sim, GameManager.accident_state])
			last_bro = GameManager.bro_meter
		if t_collide < 0.0 and x >= OBSTACLE_X:
			t_collide = sim
			boost_at_obstacle = race.snack_boost_active()
		await _step()
		steps += 1
		if case_name == "hit" and race.hit_groups.has("gate1"):
			break
		if race.turtle.position.x >= END_X:
			break

	var ended_x: float = race.turtle.position.x
	var hit: bool = bool(race.hit_groups.has("gate1"))
	var accident: String = GameManager.accident_state
	var riding: bool = bool(race.mount.state == "RIDING")
	var boost_left: bool = race.snack_boost_active()
	var fed_delta: int = GameManager.snack_switch_count - fed_before
	var switch_scores: int = _count_switch_scores() - switch_scores_before
	var result := {
		"case": case_name,
		"start_x": START_X,
		"end_x": snappedf(ended_x, 0.1),
		"base_speed": v,
		"eaten": eaten,
		"eaten_at_s": snappedf(eaten_at, 0.001),
		"snack_last_eaten": race.snack_last_eaten,
		"speed_at_contact": snappedf(speed_at_contact, 0.1),
		"boost_target": snappedf(boost_target, 0.1),
		"speed_at_3400": snappedf(speed_at_3400, 0.1),
		"max_speed": snappedf(max_speed, 0.1),
		"boost_at_obstacle": boost_at_obstacle,
		"boost_left_at_end": boost_left,
		"warning_s": snappedf(t_collide - t_visible, 0.001) if t_visible >= 0.0 and t_collide >= 0.0 else -1.0,
		"hit": hit,
		"accident": accident,
		"riding": riding,
		"oxygen": snappedf(GameManager.oxygen, 0.01),
		"bro_meter": GameManager.bro_meter,
		"fed_count": fed_delta,
	}
	var checks := {}
	if case_name == "eat":
		checks["ate"] = eaten
		checks["boost_at_obstacle"] = boost_at_obstacle
		checks["speed_raised"] = max_speed > v * 1.08
		checks["single_boost"] = eaten and absf(boost_target - v * LevelData.SNACK_BOOST_SCALE) < 0.1
		# 吃下后一直控乌龟：加速结束应精确回到区速。
		checks["back_to_cruise"] = not boost_left \
			and race.turtle.speed <= v + 3.0 and race.turtle.speed >= v * 0.98
		checks["warning_ge_4s"] = float(result["warning_s"]) >= 4.0
		checks["passed_clean"] = not hit and accident == "NONE" and riding
		# G16：这一例全程操控乌龟吃到食物 → 亲手喂到 +1，且计分只有这一笔。
		checks["fed_count"] = fed_delta == 1
		checks["fed_score"] = switch_scores == 1
	elif case_name == "skip":
		checks["not_eaten"] = not eaten
		checks["cruise_speed"] = absf(float(result["speed_at_3400"]) - v) <= 3.0
		checks["fed_count"] = fed_delta == 0
		checks["fed_score"] = switch_scores == 0
		# 礁拱的解法本身就是乌龟下潜，氧气会真实消耗（约 4.5 s），这不是“不吃食物”的惩罚。
		# 只要求：没进食也照样活着通过，且没有事故 / BRO METER / 氧气见底。
		checks["no_penalty"] = accident == "NONE" and GameManager.bro_meter == 0 \
			and GameManager.oxygen > 0.0
		checks["passed_clean"] = not hit and riding
	else:
		checks["ate"] = eaten
		checks["collision_alive"] = hit or accident != "NONE"
		checks["fed_count"] = fed_delta == 1
		checks["fed_score"] = switch_scores == 1
	var all_ok := true
	for k in checks:
		if not bool(checks[k]):
			all_ok = false
	result["checks"] = checks
	result["pass"] = all_ok
	_release_all()
	print("SNACK case=%-4s pass=%s eaten=%s v=%.0f max=%.1f warn=%.2f hit=%s acc=%s riding=%s checks=%s" % [
		case_name, str(all_ok), str(eaten), v, max_speed,
		float(result["warning_s"]), str(hit), accident, str(riding), str(checks)])
	return result


func _count_switch_scores() -> int:
	var n := 0
	for e in GameManager.score_log:
		if typeof(e) == TYPE_DICTIONARY and String(e.get("reason", "")) == "snack_switch":
			n += 1
	return n


func _reset(x: float, control: String) -> void:
	_release_all()
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


func _control(who: String) -> void:
	if GameManager.current_control != who:
		GameManager.set_control(who)


func _press(action: String) -> void:
	if not Input.is_action_pressed(action):
		Input.action_press(action)


func _release(action: String) -> void:
	if Input.is_action_pressed(action):
		Input.action_release(action)


func _release_all() -> void:
	Input.action_release("up")
	Input.action_release("down")
	Input.action_release("shift")


func _step() -> void:
	await get_tree().physics_frame
	sim += 1.0 / step_hz


func _write() -> void:
	var data := {
		"generated_at": Time.get_datetime_string_from_system(),
		"note": "TURTLE SNACK 原型：引擎按键代理 + 真实物理；不是真人试玩。",
		"step_hz": step_hz,
		"food_x": float(LevelData.snack_encounters()[0]["x"]),
		"rows": rows,
	}
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
		f.close()


func _finish(code: int) -> void:
	get_tree().quit(code)
