extends Node
## PHASE P — 随机障碍抽取的自动化验证（headless，真实物理 + 引擎按键代理）
##
## 验四件事：
##   1) 同种子复现：两次 plan_snack_draws 完全一致；
##   2) 抽取合法：第一个固定、其余来自本区池、已教学、同区不连续重复、
##      不含双角色连招（高墙/浮木）；
##   3) 接入不破坏关卡：55 组、组名与槽位 x/w 不变、单角色间距 ≥3.5 s、
##      组合间距 ≥5 s；
##   4) 真实物理：在抽到的那个遭遇里，吃下食物后按该种类的设计答案能过去，
##      加速开关（boost_at_obstacle）与预警 ≥4 s 都有记录。
##
## 用法：
##   D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
##       res://scenes/stage4_snack_draw.tscn > docs/reports/logs/phase-p/draw.log 2>&1
##
## 输出：docs/reports/longrun/phase-p-draw.json
## 证据类型：自动化测试 / 引擎按键代理，不是真人试玩。

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/phase-p-draw.json"
const SEEDS := [424242, 7, 20261112, 99]
## 真实物理的两个案例：一个抽到乌龟解法（鲨鱼），一个抽到兔子解法（低鸟）。
const PHYSICS_CASES := [
	{"seed": 424242, "encounter": 2},
	{"seed": 99, "encounter": 1},
]
const START_LEAD := 320.0
const STEP_HZ := 60.0

var is_runner := false
var race: Node = null
var sim := 0.0
var checks := {}
var seed_rows: Array = []
var physics_rows: Array = []


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
	_check_plan_structure()
	await _check_physics()

	_write()
	var fails := 0
	for k in checks:
		if not bool(checks[k]):
			fails += 1
			print("DRAW FAIL: %s" % k)
	print("SNACK DRAW: DONE checks=%d fails=%d" % [checks.size(), fails])
	_finish(0 if fails == 0 else 1)


# ---------------- 结构 ----------------

func _check_plan_structure() -> void:
	var encs: Array = LevelData.snack_encounters()
	_check("encounters_9", encs.size() == 9, "encounters=%d" % encs.size())

	var fixed_ok := true
	var pool_ok := true
	var taught_ok := true
	var repeat_ok := true
	var complex_ok := true
	var any_changed := false
	var base_plan: Array = LevelData.plan_snack_draws(int(SEEDS[0]), encs)
	var base_kinds := []
	for d in base_plan:
		base_kinds.append(String(d["kind"]))

	for seed_value in SEEDS:
		var a: Array = LevelData.plan_snack_draws(int(seed_value), encs)
		var b: Array = LevelData.plan_snack_draws(int(seed_value), encs)
		_check("same_seed_repro_%d" % int(seed_value), JSON.stringify(a) == JSON.stringify(b),
			"seed=%d" % int(seed_value))
		var kinds := []
		var last_by_zone := {}
		for i in a.size():
			var d: Dictionary = a[i]
			var zone := int(d["zone"])
			var kind := String(d["kind"])
			kinds.append(kind)
			if i == 0:
				if not bool(d["fixed"]) or kind != String(LevelData.GROUPS[
						int(encs[0]["obstacle_index"])]["kind"]):
					fixed_ok = false
			else:
				if not (kind in LevelData.SNACK_DRAW_POOL.get(zone, [])):
					pool_ok = false
				var slot_x := float(LevelData.GROUPS[int(encs[i]["obstacle_index"])]["x"])
				if not (kind in LevelData.taught_kinds_before(slot_x)):
					taught_ok = false
				if String(last_by_zone.get(zone, "")) == kind:
					repeat_ok = false
			if LevelData.is_complex_kind(kind):
				complex_ok = false
			last_by_zone[zone] = kind
		if JSON.stringify(kinds) != JSON.stringify(base_kinds):
			any_changed = true
		seed_rows.append({"seed": int(seed_value), "kinds": kinds})
		print("DRAW seed=%d %s" % [int(seed_value), ",".join(PackedStringArray(kinds))])

	_check("first_fixed", fixed_ok, "第一个遭遇固定为关卡原种类")
	_check("pool_member", pool_ok, "抽到的种类都在本区抽取池")
	_check("taught_first", taught_ok, "抽到的种类在该 x 之前已教学")
	_check("no_consecutive_repeat", repeat_ok, "同区不连续抽到同一种")
	_check("no_complex_in_snack", complex_ok, "加速遭遇不抽高墙/浮木")
	_check("seeds_vary", any_changed, "不同种子出现不同序列")

	# 应用到关卡后：组数、组名、槽位 x/w 不变；间距指标不变。
	for seed_value in SEEDS:
		var groups: Array = LevelData.groups()
		var before_starts := []
		var before_names := []
		for g in groups:
			before_names.append(String(g["group"]))
			before_starts.append(LevelData.group_start(g))
		var draws: Array = LevelData.plan_snack_draws(int(seed_value), encs)
		LevelData.apply_snack_draws(groups, draws)
		var names_ok := groups.size() == LevelData.GROUPS.size()
		var start_ok := true
		for i in groups.size():
			if String(groups[i]["group"]) != before_names[i]:
				names_ok = false
			# 起点不变：抽到的种类只换“这一格是什么”，不挪位置。
			if absf(LevelData.group_start(groups[i]) - float(before_starts[i])) > 0.01:
				start_ok = false
		var gaps := _gaps(groups)
		var ok := names_ok and start_ok and float(gaps["min_single"]) >= 3.5 \
			and float(gaps["min_combo"]) >= 5.0
		_check("level_ok_%d" % int(seed_value), ok,
			"groups=%d names=%s starts=%s single=%.2fs combo=%.2fs" % [
				groups.size(), str(names_ok), str(start_ok),
				float(gaps["min_single"]), float(gaps["min_combo"])])
		if not ok:
			print("  LEVEL KINDS seed=%d %s" % [int(seed_value), str(_kinds(groups))])


func _kinds(groups: Array) -> Array:
	var out := []
	for g in groups:
		out.append(String(g["kind"]))
	return out


## 与 stage4_metrics 同口径：单角色间距 ≥3.5 s、浮木组合 ≥5 s
## （现有门槛只对 FLOATING_LOG 算组合；高墙的准备段沿用既有口径，本阶段不改）。
func _gaps(groups: Array) -> Dictionary:
	var speed_by_zone := {1: 220.0, 2: 240.0, 3: 260.0}
	var min_single := 1.0e9
	var min_combo := 1.0e9
	var prev_end := 0.0
	for g in groups:
		var gap_s: float = (LevelData.group_start(g) - prev_end) \
			/ float(speed_by_zone.get(int(g["zone"]), 260.0))
		if String(g["kind"]) == "FLOATING_LOG":
			min_combo = minf(min_combo, gap_s)
		else:
			min_single = minf(min_single, gap_s)
		prev_end = LevelData.group_end(g)
	return {"min_single": min_single, "min_combo": min_combo}


# ---------------- 真实物理：抽到的那个遭遇 ----------------

func _check_physics() -> void:
	GameManager.start_race()
	for i in 3:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null:
		_check("physics_scene", false, "no current scene")
		return
	race.test_disable_hazards = false
	race.test_no_finish = true
	var encs: Array = LevelData.snack_encounters()
	for case in PHYSICS_CASES:
		await _run_physics_case(int(case["seed"]), int(case["encounter"]), encs)


func _run_physics_case(seed_value: int, enc_index: int, encs: Array) -> void:
	race.level_seed = seed_value
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	await get_tree().physics_frame

	var enc: Dictionary = encs[enc_index]
	var draw: Dictionary = race.snack_draws[enc_index]
	var kind := String(draw["kind"])
	var food_x := float(enc["x"])
	var group: Dictionary = {}
	for g in race.hazard_groups:
		if String(g["group"]) == String(enc["obstacle_group"]):
			group = g
			break
	var obs_x: float = LevelData.group_start(group)
	var obs_end: float = LevelData.group_end(group)
	var answer := _answer_for(kind)
	# 预警要从“障碍首次进入 1100 px 视野”开始量，所以起点必须在那之前；
	# 同时不能落在上一组障碍里（相邻组很近时退到它尾端 +60 px，测出来是偏短的下界）。
	var visible_x := obs_x - Tuning.PROMPT_RANGE
	var prev_end := 0.0
	for i in race.hazard_groups.size():
		if String(race.hazard_groups[i]["group"]) == String(enc["obstacle_group"]):
			if i > 0:
				prev_end = LevelData.group_end(race.hazard_groups[i - 1])
			break
	var start_x := minf(food_x - START_LEAD, visible_x - 40.0)
	start_x = maxf(start_x, prev_end + 60.0)
	var tag := "s%d_e%d" % [seed_value, enc_index]

	# 从食物前 320 px 出发，先操控乌龟吃下，接触后再按该种类的设计答案。
	_reset(start_x, "turtle")
	sim = 0.0
	var pressed := false
	var switched := false
	var eaten := false
	var t_visible := -1.0
	var t_collide := -1.0
	var max_speed := 0.0
	var boost_at_obstacle := false
	var steps := 0

	while sim < 20.0 and steps < int(STEP_HZ * 20.0):
		var x: float = race.turtle.position.x
		if not switched and x >= food_x + 10.0:
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
			boost_at_obstacle = race.snack_boost_active()
		max_speed = maxf(max_speed, race.turtle.speed)
		await _step()
		steps += 1
		if race.turtle.position.x >= obs_end + 260.0:
			break

	var hit: bool = bool(race.hit_groups.has(String(enc["obstacle_group"])))
	var accident: String = GameManager.accident_state
	var riding: bool = race.mount.state == "RIDING"
	var result := {
		"seed": seed_value,
		"encounter": enc_index,
		"group": String(enc["obstacle_group"]),
		"kind": kind,
		"answer": answer,
		"eaten": eaten,
		"max_speed": snappedf(max_speed, 0.1),
		"boost_at_obstacle": boost_at_obstacle,
		"warning_s": snappedf(t_collide - t_visible, 0.001)
			if t_visible >= 0.0 and t_collide >= 0.0 else -1.0,
		"hit": hit,
		"accident": accident,
		"riding": riding,
	}
	physics_rows.append(result)
	print("DRAW PHYSICS seed=%d group=%s kind=%s eaten=%s v=%.1f warn=%.2f hit=%s acc=%s riding=%s" % [
		seed_value, String(enc["obstacle_group"]), kind, str(eaten),
		max_speed, float(result["warning_s"]), str(hit), accident, str(riding)])

	_check("physics_%s_ate" % tag, eaten, "操控乌龟经过食物（%s）" % kind)
	_check("physics_%s_boost" % tag, boost_at_obstacle, "到障碍时仍在加速")
	_check("physics_%s_warning_ge_4s" % tag, float(result["warning_s"]) >= 4.0,
		"预警 %.2f s" % float(result["warning_s"]))
	_check("physics_%s_passed" % tag, not hit and accident == "NONE" and riding,
		"hit=%s acc=%s riding=%s" % [str(hit), accident, str(riding)])
	_release_all()


## 每种障碍的“设计答案”：谁操控、提前多少 px、按什么。
## lead 取自 PHASE-N §5（加速 ×1.15）实测窗口的中间值。
func _answer_for(kind: String) -> Dictionary:
	match kind:
		"LOW_BIRD":
			return {"control": "rabbit", "lead": 320.0, "press": ["down"]}
		"LOW_BEAM":
			return {"control": "rabbit", "lead": 320.0, "press": ["down"]}
		"SURFACE_ROCK":
			return {"control": "rabbit", "lead": 110.0, "press": ["up"]}
		"DIVE_GATE":
			return {"control": "turtle", "lead": 260.0, "press": ["down"]}
		"SHARK":
			return {"control": "turtle", "lead": 190.0, "press": ["up"]}
		_:
			return {"control": "turtle", "lead": 190.0, "press": ["up"]}


# ---------------- 工具 ----------------

func _reset(x: float, control: String) -> void:
	_release_all()
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.oxygen = Tuning.OXYGEN_MAX
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


func _release_all() -> void:
	Input.action_release("up")
	Input.action_release("down")
	Input.action_release("shift")


func _step() -> void:
	await get_tree().physics_frame
	sim += 1.0 / STEP_HZ


func _check(key: String, ok: bool, detail: String = "") -> void:
	checks[key] = ok
	print("  %-26s %s  %s" % [key, "PASS" if ok else "FAIL", detail])


func _write() -> void:
	var data := {
		"generated_at": Time.get_datetime_string_from_system(),
		"note": "Phase P 随机障碍抽取：结构 + 真实物理；引擎按键代理，不是真人试玩。",
		"step_hz": STEP_HZ,
		"pool": LevelData.SNACK_DRAW_POOL,
		"seeds": seed_rows,
		"physics": physics_rows,
		"checks": checks,
	}
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
		f.close()


func _finish(code: int) -> void:
	get_tree().quit(code)
