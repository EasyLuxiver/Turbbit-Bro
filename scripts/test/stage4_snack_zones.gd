extends Node
## PHASE P / §七-5 — 三区 9 段食物遭遇逐段实测（headless，真实物理 + 引擎按键代理）
##
## 每段跑两条路径：
##   eat  —— 操控乌龟经过食物自动吃下，再按该格抽到的种类的设计答案过障碍；
##   skip —— 操控乌龟在食物前跃起从上方越过（不进食），落地后仍按设计答案过障碍。
##           2026-11-12 起“换操控兔子”不再是合法跳过：食物判定只看乌龟位置，
##           谁在操控都会吃；不吃只能用 ↑/↓ 主动离开食物层。
## 记录：吃没吃、到障碍时的速度、预警、最高速、事故、氧气、BRO、是否仍骑乘、
## 出遭遇后是否回到巡航。
##
## 结果在本进程开始时按 `--seed`（默认 20261112）抽定，日志会打印 LEVEL SEED。
##
## 用法：
##   D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
##       res://scenes/stage4_snack_zones.tscn -- --seed 20261112 \
##       > docs/reports/logs/phase-p/zones.log 2>&1
##
## 输出：docs/reports/longrun/phase-p-zones.json
## 证据类型：自动化测试 / 引擎按键代理，不是真人试玩。

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/phase-p-zones.json"
const START_LEAD := 320.0
const STEP_HZ := 60.0

var is_runner := false
var race: Node = null
var sim := 0.0
var rows: Array = []
var checks := {}


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 8.0
	Engine.physics_ticks_per_second = int(STEP_HZ * Engine.time_scale)
	await get_tree().process_frame
	await _run()


func _run() -> void:
	GameManager.start_race()
	for i in 3:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null:
		push_error("ZONES: no current scene")
		_finish(1)
		return
	race.test_disable_hazards = false
	race.test_no_finish = true
	# 先装一次，让默认种子 / --seed 生效，抽样结果从 race.snack_draws 读。
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	await get_tree().physics_frame

	var encs: Array = LevelData.snack_encounters()
	for i in encs.size():
		for case_name in ["eat", "skip"]:
			rows.append(await _run_case(i, case_name, encs[i], race.snack_draws[i]))

	_write()
	var fails := 0
	for r in rows:
		if not bool(r["pass"]):
			fails += 1
	print("SNACK ZONES: DONE rows=%d fails=%d" % [rows.size(), fails])
	_finish(0 if fails == 0 else 1)


func _run_case(enc_index: int, case_name: String, enc: Dictionary,
		draw: Dictionary) -> Dictionary:
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	await get_tree().physics_frame
	var kind := String(draw["kind"])
	var answer := _answer_for(kind)
	var food_x := float(enc["x"])
	var group: Dictionary = {}
	for g in race.hazard_groups:
		if String(g["group"]) == String(enc["obstacle_group"]):
			group = g
			break
	var obs_x: float = LevelData.group_start(group)
	var obs_end: float = LevelData.group_end(group)
	var visible_x := obs_x - Tuning.PROMPT_RANGE
	var prev_end := 0.0
	var prev_amp := 0.0
	for i in race.hazard_groups.size():
		if String(race.hazard_groups[i]["group"]) == String(enc["obstacle_group"]):
			if i > 0:
				prev_end = LevelData.group_end(race.hazard_groups[i - 1])
				# G20：前一组如果是动态障碍，它的活动矩形会扫出静态端点 ±amp。
				# 起点只留 60 px 时（gate3 那行），乌龟一出生就蹭到前面巡逻鲨的扫掠范围，
				# 记一笔 TURTLE_WAVE——以前同组的 hit_roles 还留着才没暴露。
				var pm: Dictionary = race.hazard_groups[i - 1].get("motion", {})
				prev_amp = float(pm.get("amp", 0.0))
			break
	var start_x := maxf(minf(food_x - START_LEAD, visible_x - 40.0),
		prev_end + 60.0 + prev_amp + 40.0)

	# 两条路径都从乌龟起步：食物判定只看乌龟位置。skip 用跃起从上方越过去。
	_reset(start_x, "turtle")
	sim = 0.0
	var v: float = float(race.current_zone["base_speed"])
	var pressed := false
	var switched := false
	var leap_pressed := false
	var eaten := false
	var t_visible := -1.0
	var t_collide := -1.0
	var oxygen_at_food := -1.0
	var max_speed := 0.0
	var speed_at_obstacle := 0.0
	var boost_at_obstacle := false
	var steps := 0

	while sim < 22.0 and steps < int(STEP_HZ * 22.0):
		var x: float = race.turtle.position.x
		if case_name == "skip" and not leap_pressed and x >= food_x - 260.0:
			# 起跳后 0.13 s 就离开食物层；1.6 s 的滞空覆盖整段接触窗口（±70 px）。
			_press("up")
			leap_pressed = true
		if not switched:
			if case_name == "eat" and x >= food_x + 10.0:
				_control(String(answer["control"]))
				switched = true
			elif case_name == "skip" and leap_pressed and not race.turtle.leap_active \
					and x >= food_x + 170.0:
				_release("up")
				oxygen_at_food = GameManager.oxygen
				_control(String(answer["control"]))
				switched = true
		if switched and not pressed:
			var trigger: float = obs_x - float(answer["lead"])
			if x >= trigger:
				for a in answer["press"]:
					_press(String(a))
				pressed = true
		if t_visible < 0.0 and x >= visible_x:
			t_visible = sim
		if not eaten and race.snack_last_eaten != "":
			eaten = true
		if t_collide < 0.0 and x >= obs_x:
			t_collide = sim
			speed_at_obstacle = race.turtle.speed
			boost_at_obstacle = race.snack_boost_active()
		max_speed = maxf(max_speed, race.turtle.speed)
		await _step()
		steps += 1
		if race.turtle.position.x >= obs_end + 260.0:
			break

	# 收尾：等这次加速真正结束（最多 2 s），再等速度自己落回当前区巡航
	# （最多 1.5 s；跨区时 base 会从 220 跳到 240，所以按“当前 base”判，不写死）。
	var end_boost: bool = bool(race.snack_boost_active())
	var tail := 0
	while end_boost and tail < int(STEP_HZ * 2.0):
		await _step()
		tail += 1
		end_boost = race.snack_boost_active()
	var settle := 0
	while settle < int(STEP_HZ * 1.5) \
			and absf(race.turtle.speed - float(race.turtle.base_speed)) > 3.0:
		await _step()
		settle += 1
	var hit: bool = bool(race.hit_groups.has(String(enc["obstacle_group"])))
	var accident: String = GameManager.accident_state
	var riding: bool = race.mount.state == "RIDING"
	# 视野预警的“设计值”：从障碍首次进入 1100 px 视野算起。
	# 探针起点可能晚于首次可见（上一组障碍还占着那个位置），所以实测值是下界；
	# 设计值按巡航段 + 加速段的实际速度算，验收用它。
	var v_boost := v * LevelData.SNACK_BOOST_SCALE
	var warning_design := (food_x - visible_x) / v \
		+ (obs_x - food_x) / v_boost
	if case_name == "skip":
		warning_design = (obs_x - visible_x) / v
	var end_base: float = float(race.turtle.base_speed)
	var result := {
		"encounter": enc_index + 1,
		"case": case_name,
		"zone": int(enc["zone"]),
		"group": String(enc["obstacle_group"]),
		"kind": kind,
		"answer": String(answer["control"]),
		"start_x": snappedf(start_x, 0.1),
		"eaten": eaten,
		"base_speed": v,
		"speed_at_obstacle": snappedf(speed_at_obstacle, 0.1),
		"max_speed": snappedf(max_speed, 0.1),
		"boost_at_obstacle": boost_at_obstacle,
		"warning_s": snappedf(t_collide - t_visible, 0.001)
			if t_visible >= 0.0 and t_collide >= 0.0 else -1.0,
		"warning_design_s": snappedf(warning_design, 0.001),
		"hit": hit,
		"accident": accident,
		"oxygen": snappedf(GameManager.oxygen, 0.01),
		"oxygen_at_food": snappedf(oxygen_at_food, 0.01),
		"bro_meter": GameManager.bro_meter,
		"riding": riding,
		"speed_after_s": snappedf(race.turtle.speed, 0.1),
		"boost_after": race.snack_boost_active(),
	}
	var c := {}
	if case_name == "eat":
		c["ate"] = eaten
		c["boost_at_obstacle"] = boost_at_obstacle
		c["speed_raised"] = max_speed > v * 1.08
		c["warning_ge_4s"] = warning_design >= 4.0
		c["passed_clean"] = not hit and accident == "NONE" and riding
		c["back_to_cruise"] = absf(float(result["speed_after_s"]) - end_base) <= 3.0 \
			and not bool(result["boost_after"])
	else:
		c["not_eaten"] = not eaten
		c["cruise_at_obstacle"] = absf(speed_at_obstacle - v) <= 3.0
		# “不吃没有惩罚”只看跳过食物那一刻：氧气未掉、BRO 未涨、无事故。
		# 之后的主动下潜（DIVE_GATE 的答案是下潜）本身耗氧，那是玩法不是惩罚。
		c["no_penalty"] = accident == "NONE" and GameManager.bro_meter == 0 \
			and oxygen_at_food >= 0.0 and absf(oxygen_at_food - Tuning.OXYGEN_MAX) < 0.01
		c["warning_ge_4s"] = warning_design >= 4.0
		c["passed_clean"] = not hit and riding
	var all_ok := true
	for k in c:
		if not bool(c[k]):
			all_ok = false
	result["checks"] = c
	result["pass"] = all_ok
	rows_check(enc_index, case_name, all_ok)
	_release_all()
	print("ZONE SNACK #%d %-4s z%d %-11s %-6s w=%.2f v=%.0f/%.0f hit=%s acc=%s ride=%s %s" % [
		enc_index + 1, case_name, int(enc["zone"]), String(enc["obstacle_group"]),
		kind, float(result["warning_s"]), speed_at_obstacle, max_speed,
		str(hit), accident, str(riding), "PASS" if all_ok else str(c)])
	return result


func rows_check(enc_index: int, case_name: String, ok: bool) -> void:
	checks["e%d_%s" % [enc_index + 1, case_name]] = ok


## 设计答案：谁操控、提前多少 px、按什么（lead 取 PHASE-N 实测窗口的中段）。
func _answer_for(kind: String) -> Dictionary:
	match kind:
		"LOW_BIRD":
			return {"control": "rabbit", "lead": 320.0, "press": ["down"]}
		"LOW_BEAM":
			return {"control": "rabbit", "lead": 320.0, "press": ["down"]}
		"SURFACE_ROCK":
			return {"control": "rabbit", "lead": 70.0, "press": ["up"]}
		"DIVE_GATE":
			return {"control": "turtle", "lead": 260.0, "press": ["down"]}
		"SHARK":
			return {"control": "turtle", "lead": 190.0, "press": ["up"]}
		"FLOATING_LOG":
			return {"control": "rabbit", "lead": 190.0, "press": ["up"]}
		_:
			return {"control": "turtle", "lead": 190.0, "press": ["up"]}


# ---------------- 工具 ----------------

func _reset(x: float, control: String) -> void:
	_release_all()
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.oxygen = Tuning.OXYGEN_MAX
	GameManager.bro_meter = 0
	GameManager.showtime_active = false
	GameManager.current_control = control
	GameManager.has_shifted = true
	GameManager.pickup_window = false
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
	# G20：动态障碍的相位只看 hazard_clock（物理时间）。行与行之间它一直在走，
	# 前一行多跑几十毫秒就会把后一行的巡逻鲨相位整个挪开——同一行会时过时不过。
	# 正式比赛每局重建场景、clock 从 0 开始，探针也按这个口径每行归零。
	race.hazard_clock = 0.0
	# G20：hit_roles 必须和 hit_groups 一起清。只清 hit_groups 时，B2 起的“角色×组”记账还留着，同组第二例起整组免疫——后面那些重复用例其实在测一段不会撞的赛道。
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.current_zone = LevelData.zone_at(x)
	var speed: float = float(race.current_zone["base_speed"])
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
	sim += 1.0 / STEP_HZ


func _write() -> void:
	var data := {
		"generated_at": Time.get_datetime_string_from_system(),
		"note": "9 段食物遭遇 × 吃/不吃；引擎按键代理 + 真实物理，不是真人试玩。",
		"level_seed": race.level_seed,
		"step_hz": STEP_HZ,
		"draws": race.snack_draws,
		"rows": rows,
		"checks": checks,
	}
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
		f.close()


func _finish(code: int) -> void:
	get_tree().quit(code)
