extends Node
## PHASE R / 追加任务 §七-7 — 加速状态下的主动救援重验
## （headless，真实关卡物理 + 引擎按键代理；不是真人试玩）
##
## 在正式赛道上复现新机制下的落水：
##   操控乌龟吃下食物 → TURBO 生效 → 切兔子 → 跳着撞进低梁（错误动作）→ 兔子落水。
## 之后按不同延迟切回乌龟、按住 ↓，记录接住/失败、恢复耗时、事故计数、
## 失败恢复期间兔子是否逐帧被冲回（不是瞬移）。
## 同一份探针再跑一组“不吃食物”的基速对照，确认 PHASE-F 的旧窗口没被改坏。
##
## 用法：
##   D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
##       res://scenes/stage4_rescue_boost.tscn \
##       > docs/reports/logs/phase-r/rescue-boost.log 2>&1
##
## 输出：docs/reports/longrun/phase-r-rescue-boost.json
## 证据类型：自动化测试 / 引擎按键代理，不是真人试玩。

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/phase-r-rescue-boost.json"
const STEP_HZ := 60.0
## 撞梁：跳跃要正好在梁的 x 段里处于“离地且在梁的高度带”。45 px 起跳 = 0.18 s。
const JUMP_LEAD := 45.0
## 失败恢复期间兔子由 move_toward(560 px/s) 冲回：60 Hz 下单帧 ≤ 9.4 px。
const MAX_TELEPORT_STEP := 12.0
const START_LEAD := 320.0

## [标签, 障碍组, 是否吃食物(TURBO), 事故后多少秒开始 SHIFT+↓ (-1 = 不下潜), 是否只切人不潜]
## beam1 = Z1（220 / TURBO 253）；beam8 = Z3（260 / TURBO 299，最坏的一段尾巴）。
const TRIALS := [
	["boost_none", "beam1", true, -1.0, false],
	["boost_shift_only", "beam1", true, -1.0, true],
	["boost_dive_0.0", "beam1", true, 0.0, false],
	["boost_dive_0.4", "beam1", true, 0.4, false],
	["boost_dive_0.8", "beam1", true, 0.8, false],
	["boost_dive_1.2", "beam1", true, 1.2, false],
	["boost_dive_1.6", "beam1", true, 1.6, false],
	["boost_dive_1.8", "beam1", true, 1.8, false],
	["boost_dive_2.0", "beam1", true, 2.0, false],
	["boost_dive_2.2", "beam1", true, 2.2, false],
	["boost_dive_2.4", "beam1", true, 2.4, false],
	["base_none", "beam1", false, -1.0, false],
	["base_dive_0.0", "beam1", false, 0.0, false],
	["base_dive_1.6", "beam1", false, 1.6, false],
	["base_dive_2.0", "beam1", false, 2.0, false],
	["base_dive_2.2", "beam1", false, 2.2, false],
	["base_dive_2.4", "beam1", false, 2.4, false],
	["z3_none", "beam8", true, -1.0, false],
	["z3_dive_0.0", "beam8", true, 0.0, false],
	["z3_dive_0.8", "beam8", true, 0.8, false],
	["z3_dive_1.2", "beam8", true, 1.2, false],
	["z3_dive_1.6", "beam8", true, 1.6, false],
	["z3_dive_1.8", "beam8", true, 1.8, false],
	["z3_dive_2.0", "beam8", true, 2.0, false],
	["z3_dive_2.2", "beam8", true, 2.2, false],
]

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
		push_error("RESCUE-BOOST: no current scene")
		get_tree().quit(1)
		return
	race.test_disable_hazards = false
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	await get_tree().physics_frame

	for t in TRIALS:
		var row: Dictionary = await _trial(String(t[0]), String(t[1]), bool(t[2]),
			float(t[3]), bool(t[4]))
		rows.append(row)
		_write()
		print("RESCUE-BOOST %-17s %-6s boost=%s crash=%s speed=%.0f result=%-7s catch=%.2f recover=%.2f step=%.1f acc+%d/%d %s" % [
			String(row["label"]), String(row["group"]), str(row["boost_at_crash"]),
			String(row["crash"]), float(row["speed_at_crash"]), String(row["result"]),
			float(row["catch_s"]), float(row["recover_s"]), float(row["max_return_step"]),
			int(row.get("accident_delta_at_recovery", -1)),
			int(row["accident_delta"]), "PASS" if bool(row["pass"]) else str(row["checks"])])

	_evaluate()
	_write()
	var fails := 0
	for r in rows:
		if not bool(r["pass"]):
			fails += 1
	# 汇总判定必须进退出码：以前只数 row.pass，checks 里红着也照样 DONE 退 0，
	# “探针能跑绿”与“窗口真的没坏”被混成了一件事。
	var red: Array = []
	for k in checks:
		if not bool(checks[k]):
			red.append(String(k))
	print("RESCUE-BOOST: DONE rows=%d fails=%d checks=%d red=%d" % [rows.size(), fails,
		checks.size(), red.size()])
	if red.size() > 0:
		print("  red checks: ", ", ".join(red))
	get_tree().quit(0 if fails == 0 and red.is_empty() else 1)


func _trial(label: String, group_name: String, boost_case: bool, delay: float,
		shift_only: bool) -> Dictionary:
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	if not boost_case:
		# SHIFT-02 §1-8 起，食物只看乌龟真实位置：操控兔子时乌龟路过照样吃。
		# 旧写法“食物前切兔子躲开”已不成立，base_* 会实测成 TURBO 253，
		# 与“不吃食物”的窗口参照物不符。基速对照直接清空 lanes 关闭食物。
		race.boost_lanes.clear()
	await get_tree().physics_frame
	var enc := {}
	for e in LevelData.snack_encounters():
		if String(e["obstacle_group"]) == group_name:
			enc = e
			break
	var food_x: float = float(enc["x"])
	var group: Dictionary = {}
	for g in race.hazard_groups:
		if String(g["group"]) == group_name:
			group = g
			break
	var obs_start: float = LevelData.group_start(group)
	var obs_end: float = LevelData.group_end(group)

	_reset(food_x - START_LEAD, "turtle")
	sim = 0.0
	var acc_before := GameManager.accident_count
	var switched := false
	var jumped := false
	var eaten := false
	var crash := ""
	var t_crash := -1.0
	var x_crash := -1.0
	var speed_crash := -1.0
	var boost_crash := false
	var ahead_crash := -1.0
	var steps := 0

	# ---- 1) 真实撞击：吃/不吃食物，切兔子，跳进低梁 ----
	while sim < 16.0 and steps < int(STEP_HZ * 16.0):
		var x: float = race.turtle.position.x
		if not eaten and race.snack_last_eaten != "":
			eaten = true
		if not switched:
			if boost_case and eaten:
				switched = true
				_control("rabbit")
			elif not boost_case and x >= food_x - 200.0:
				# 基速对照必须“不吃”：食物前方就切回兔子，否则乌龟路过会自动吃下。
				switched = true
				_control("rabbit")
		if switched and not jumped and x >= obs_start - JUMP_LEAD:
			_press("up")
			jumped = true
		if GameManager.accident_state == "RABBIT_WATER":
			crash = "RABBIT_WATER"
			t_crash = sim
			x_crash = x
			speed_crash = race.turtle.speed
			boost_crash = race.snack_boost_active()
			ahead_crash = race.rabbit.position.x - race.turtle.position.x
			break
		await _step()
		steps += 1
		if race.turtle.position.x >= obs_end + 700.0:
			crash = "no_hit"
			break
	_release_all()

	var row := {
		"label": label,
		"group": group_name,
		"boost_case": boost_case,
		"delay": delay,
		"eaten": eaten,
		"crash": crash,
		"x_crash": snappedf(x_crash, 0.1),
		"speed_at_crash": snappedf(speed_crash, 0.1),
		"boost_at_crash": boost_crash,
		"rabbit_ahead_at_crash": snappedf(ahead_crash, 0.1),
		"zone_base": float(race.current_zone["base_speed"]),
	}
	if crash != "RABBIT_WATER":
		row["result"] = "no_crash"
		row["catch_s"] = -1.0
		row["recover_s"] = -1.0
		row["max_return_step"] = -1.0
		row["accident_delta"] = GameManager.accident_count - acc_before
		row["accident_delta_at_recovery"] = row["accident_delta"]
		row["checks"] = {"crash": false}
		row["pass"] = false
		return row

	# ---- 2) 救援：按延迟 SHIFT + 按住 ↓ ----
	var t0 := sim
	var shift_done := false
	var dive_done := false
	var switch_via := ""
	var result := ""
	var catch_s := -1.0
	var recover_s := -1.0
	var acc_at_recovery := -1
	var x_at_recovery := -1.0
	var max_step := 0.0
	var prev_rabbit: Vector2 = race.rabbit.position
	var pool := 0
	while sim - t0 < 6.0 and pool < int(STEP_HZ * 6.0):
		var elapsed := sim - t0
		if not shift_done and (shift_only or delay >= 0.0) and elapsed >= 0.0:
			switch_via = _shift()
			shift_done = true
		if delay >= 0.0 and not dive_done and elapsed >= delay:
			_press("down")
			dive_done = true
		if result == "" and String(race.rescue_last_result) != "":
			result = String(race.rescue_last_result)
			catch_s = elapsed
		if result != "" and GameManager.accident_state == "NONE" \
				and race.mount.state == "RIDING":
			recover_s = elapsed
			acc_at_recovery = GameManager.accident_count - acc_before
			x_at_recovery = race.turtle.position.x
			break
		await _step()
		pool += 1
		if race.mount.state == "RESCUING":
			max_step = maxf(max_step, race.rabbit.position.distance_to(prev_rabbit))
		prev_rabbit = race.rabbit.position
	if result == "":
		result = "timeout"
	_release_all()

	# ---- 3) 恢复后再跑 1.0 s，确认没有第二次事故 ----
	var tail := 0
	while tail < int(STEP_HZ * 1.0):
		await _step()
		tail += 1

	row["result"] = result
	row["catch_s"] = snappedf(catch_s, 0.01)
	row["recover_s"] = snappedf(recover_s, 0.01)
	row["max_return_step"] = snappedf(max_step, 0.01)
	row["accident_delta_at_recovery"] = acc_at_recovery
	row["x_at_recovery"] = snappedf(x_at_recovery, 0.1)
	row["accident_delta"] = GameManager.accident_count - acc_before
	row["x_after_tail"] = snappedf(race.turtle.position.x, 0.1)
	row["bro_meter"] = GameManager.bro_meter
	row["oxygen_after"] = snappedf(GameManager.oxygen, 0.01)
	row["riding_after"] = race.mount.state == "RIDING"
	row["accident_after"] = GameManager.accident_state
	row["control_after"] = GameManager.current_control
	row["switch_via"] = switch_via
	row["speed_after"] = snappedf(race.turtle.speed, 0.1)
	row["boost_after"] = race.snack_boost_active()

	var c := {}
	c["crash_water"] = crash == "RABBIT_WATER"
	c["boost_case_matches"] = boost_crash == boost_case
	# 救援本身只记一次事故。恢复之后的尾巴里如果再撞下一组障碍，那是“没输入继续
	# 往前开”的真实后果，单独记在 accident_delta（含尾巴），不进这条判定。
	c["accident_once_through_recovery"] = int(row["accident_delta_at_recovery"]) == 1
	c["riding_after"] = bool(row["riding_after"])
	c["oxygen_after"] = float(row["oxygen_after"]) >= Tuning.OXYGEN_RECOVERED - 0.01
	if result == "missed":
		c["recover_bound"] = recover_s >= 0.0 and recover_s - catch_s <= 1.4
		c["no_teleport"] = max_step <= MAX_TELEPORT_STEP
	if delay < 0.0 or shift_only:
		c["not_caught"] = result == "missed"
	elif label.begins_with("boost_dive_"):
		# 加速状态：0.0–1.6 s 必须能接住（窗口 ≥1.6 s），2.0 s 起只记录不判。
		c["window"] = result == "caught" if delay <= 1.6 else true
	elif label.begins_with("base_dive_"):
		# §6 重写接人判定后，基速窗口比 PHASE-F 更宽（扩大有效区 + 6 段扫掠容错）：
		# 实测 0.0–2.4 s 都能接住，2.4 s 在 2.85 s 接上，属“容错变好”不是回归。
		# 失败边界不在这里断言——由 base_none（完全不切/不下潜）与
		# stage4_water_rescue 的 1.6/2.0 s（从水花起算）负责。
		if delay <= 2.4:
			c["window"] = result == "caught"
	row["checks"] = c
	var all_ok := true
	for k in c:
		if not bool(c[k]):
			all_ok = false
	row["pass"] = all_ok
	return row


## 用真实按键事件走 GameManager._unhandled_input；若引擎没派发就退回直接调用，
## 并记下走的是哪条路（报告里要写清楚）。
func _shift() -> String:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SHIFT
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	if GameManager.current_control == "turtle":
		return "action"
	GameManager.toggle_control()
	return "direct"


func _evaluate() -> void:
	var by := {}
	for r in rows:
		by[String(r["label"])] = r
	# 1. 加速撞击确实发生在 TURBO 中
	checks["boost_crash_under_turbo"] = bool(by["boost_dive_0.0"]["boost_at_crash"]) \
		and float(by["boost_dive_0.0"]["speed_at_crash"]) \
			> float(by["boost_dive_0.0"]["zone_base"]) * 1.05
	# 2. 不输入 / 只切人都不接住
	checks["player_action_required"] = String(by["boost_none"]["result"]) == "missed" \
		and String(by["boost_shift_only"]["result"]) == "missed"
	# 3. 加速窗口 ≥1.6 s
	var w := true
	for d in ["0.0", "0.4", "0.8", "1.2", "1.6"]:
		w = w and String(by["boost_dive_" + d]["result"]) == "caught"
	checks["boost_window_ge_1.6s"] = w
	# 4. 基速对照没被改坏：PHASE-F 的 0.0/1.6/2.0 三档必须仍是 caught，
	#    且“完全不动作”必须接不住。2.4 s 只记录不断言——§6 重写接人判定后
	#    基速窗口变宽（2.4 s 在 2.85 s 接上），那是容错变好，不是回归；
	#    真正的失败边界由 base_none 与 stage4_water_rescue 负责。
	checks["base_matches_phase_f"] = String(by["base_dive_0.0"]["result"]) == "caught" \
		and String(by["base_dive_1.6"]["result"]) == "caught" \
		and String(by["base_dive_2.0"]["result"]) == "caught" \
		and String(by["base_none"]["result"]) == "missed"
	# 5. 失败是有限、逐帧的恢复，不是瞬移
	checks["miss_is_finite_and_not_teleport"] = bool(by["boost_none"]["checks"].get("no_teleport", false)) \
		and float(by["boost_none"]["max_return_step"]) > 0.0 \
		and float(by["boost_none"]["max_return_step"]) <= MAX_TELEPORT_STEP \
		and int(by["boost_none"]["accident_delta_at_recovery"]) == 1
	# 6. 所有试次都只记一次事故
	var once := true
	for r in rows:
		once = once and int(r["accident_delta_at_recovery"]) == 1
	checks["one_accident_every_trial"] = once
	# 7. Z3 最坏尾巴：TURBO 299 px/s 下仍有 ≥1.2 s 的起始窗口（不是帧级窗口）
	var z3 := true
	for d in ["0.0", "0.8", "1.2"]:
		z3 = z3 and String(by["z3_dive_" + d]["result"]) == "caught"
	checks["z3_window_ge_1.2s"] = z3
	checks["z3_none_misses"] = String(by["z3_none"]["result"]) == "missed"


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
	race.rescue_last_result = ""
	race.hit_groups.clear()
	# B2 起碰撞按“角色×障碍组”各记一次（hit_roles）。正式流程由 start_race 复位，
	# 探针直接调 load_level，不会经过那里；少了这一行，同组从第二例起整组免疫，
	# 25 例里只有每组第一例真的撞上了——看起来像“下潜不再落水”，其实是探针自己的洞。
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


func _write() -> void:
	var data := {
		"generated_at": Time.get_datetime_string_from_system(),
		"note": "加速状态下的主动救援重验：正式赛道、真实物理、引擎按键代理，不是真人试玩。",
		"level_seed": race.level_seed if race != null else 0,
		"step_hz": STEP_HZ,
		"group": "beam1 (Z1) + beam8 (Z3)",
		"rows": rows,
		"checks": checks,
	}
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
		f.close()
