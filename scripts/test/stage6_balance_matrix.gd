extends Node
## REFINE-06 P1：动态平衡矩阵（可重复测试场景）
##
## 制作人补充要求：动态平衡是 SHIFT 的核心机制，必须能用同一条测试场景反复
## 复现“连续兔子专属 / 连续乌龟专属 / 交替 / 伙伴失控中组合 / 高压力后恢复”
## 五类压力，并逐组记录状态变化、控制权、SHIFT 与恢复时间、进障碍时双方状态、
## 失误原因，以及是否存在无解组合。
##
## 三段独立运行（同一条正式 race.tscn，真实按键，不做单帧精确校准）：
##   AB  7900→12400  兔子专属 rock3/beam2 两连（乌龟神游）→ 立刻切龟过 wall1（跃起+蹬踏）
##                   再切回龟下潜 gate2
##   C   3480→7480   交替：gate1(龟潜) → rock2(兔跳) → log1(兔跳+龟潜) → shark1(龟跃)
##   DE  7900→12400  控兔子让乌龟一路神游到 MISCHIEF → 兔过 rock3/beam2 →
##                   墙前一刻切到神游的乌龟跃起、切兔蹬踏 → 放回乌龟下潜过 gate2 →
##                   开阔水域先恢复乌龟再恢复兔子
##
## P6（2026-11-13）：Z1 顺序改成 rock3→beam2→wall1→gate2→bird2（原 beam2→bird2→gate2→wall1），
## 本场景的名次全部按组名取 x，但三段的行进区间与按键顺序按新顺序重排；
## 判定的五类压力不变（连续兔子 / 连续乌龟 / 交替 / 伙伴失控中组合 / 压后恢复）。
##
## 输入提前量取自 stage4_solution_audit 的“人类按得出来”区间（不是逐帧扫描）：
## 趴低 160、下潜 320、跃起 160、高墙跃起 176、浮木起跳 170。
##
## 输出：docs/reports/longrun/refine06-p1-balance.json
## 用法：
##   godot --headless --path TURBBIT res://scenes/stage6_balance_matrix.tscn
##   godot --path TURBBIT res://scenes/stage6_balance_matrix.tscn -- --capture-p1
##     （窗口化截图：兔子受控趴低、乌龟 MISCHIEF，HUD 与标记同屏）

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/refine06-p1-balance.json"
const STEP := 1.0 / 60.0
## 进障碍前的取样距离：标记/教学在更早的 170 / 1100 px 就已可见，
## 这里取 60 px 当作“马上就要撞上”的那一刻。
const ENTRY_LEAD := 60.0

## 输入提前量（px）。取审计里能过的中段，不做逐帧校准。
const LEAD_CROUCH := 160.0
const LEAD_DIVE := 320.0
const LEAD_LEAP := 160.0
const LEAD_WALL := 176.0
const LEAD_ROCK_JUMP := 60.0
# 浮木组合的起跳窗口：兔子整个身体要高于上沿 192，直到尾沿 6432 才落回。
# 170 是窗口早端，乌龟 bob 一低 16 px 就擦到尾沿 1 px（第一次跑实测）。
const LEAD_LOG_JUMP := 140.0
## 高墙蹬踏：跃起后壳到墙前 70 px 时切兔子补跳（与 solution_audit 一致）。
const WALL_STOMP_AT := 70.0

var is_runner := false
var race: Node = null
var out := {}
var failures: Array = []

var sim := 0.0
var run_name := ""
var run_data := {}
var _last_state := {"rabbit": "CALM", "turtle": "CALM"}
var _last_accident := "NONE"
var _log_seen := 0
var _hit_seen := {}
# SHIFT 后 1.25 s 内逐帧记录接过来的角色 drift，用来证明“受控 0.5 s 后才开始回落”。
var _trace := {}
var _pressed := {"up": false, "down": false}


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage6BalanceMatrixRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	Locale.language = "zh"
	GameManager.start_race()
	for i in 4:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null:
		push_error("P1 MATRIX: no race scene")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()
	await get_tree().physics_frame

	GameManager.feedback.connect(_on_feedback)

	out = {
		"generated_at": Time.get_datetime_string_from_system(),
		"note": "动态平衡矩阵：真实 race.tscn、真实按键、固定提前量；自动驾驶代理，不是真人试玩。",
		"step_hz": 60,
		"runs": {},
	}

	_run_ab()
	_run_c()
	_run_de()

	if "--capture-p1" in OS.get_cmdline_user_args():
		await _capture_p1()
		await _capture_stages()

	_evaluate()
	_write()
	print("REFINE06 P1 MATRIX: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _on_feedback(text: String, kind: String) -> void:
	if run_data.is_empty():
		return
	run_data["feedback"].append({
		"t": snappedf(sim, 0.01),
		"text": text,
		"kind": kind,
	})


# ---------------------------------------------------------------- 重置与驱动

## 每个 run 是独立世界：位置、输入、账本全清；神游量只在同一 run 内延续。
func _reset(x: float, control: String, name: String) -> void:
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.clear_bro_meter()
	GameManager.accident_count = 0
	GameManager.total_score = 0
	GameManager.score_log.clear()
	GameManager.rabbit_casualties = 0
	GameManager.turtle_failures = 0
	GameManager.rescue_success_count = 0
	GameManager.pickup_count = 0
	GameManager.showtime_active = false
	GameManager.current_control = control
	GameManager.has_shifted = true
	GameManager.shift_count = 0
	race.showtime_active = false
	race.showtime_t = 0.0
	race.combo = 0
	race.combo_max = 0
	race.joint_show_t = 0.0
	race.finishing = false
	race.hazard_cooldown = 0.0
	race.accident_flash = 0.0
	race.rabbit_stun = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.emergency_timer = 0.0
	race.turtle_repair = 0.0
	race._coyote_t = 0.0
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.group_actions.clear()
	race.test_disable_hazards = false
	race.reset_brains()
	race.turtle.reset(Vector2(x, Tuning.NEUTRAL_DEPTH))
	race.turtle.speed = 220.0
	race.turtle.base_speed = 220.0
	race.turtle.speed_cap = 1.0e9
	race.turtle.daze_time = 0.0
	race.turtle.dunk_timer = 0.0
	race.turtle.leap_active = false
	race.turtle.leap_timer = 0.0
	race.turtle.leap_cooldown = 0.0
	race.rabbit.reset()
	race.mount.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.mark_riding()
	race.rabbit.state = "RIDING"
	race.rescue_last_result = ""
	race.rescue_last_reason = ""
	race.snack_boost_until_x = -1.0
	race.snack_boost_speed = 0.0
	_release_all()
	sim = 0.0
	_last_state = {"rabbit": "CALM", "turtle": "CALM"}
	_last_accident = "NONE"
	_log_seen = 0
	_hit_seen = {}
	_trace = {}
	run_name = name
	run_data = {
		"segments": {},
		"entries": {},
		"events": [],
		"shifts": [],
		"shift_traces": [],
		"feedback": [],
		"mistakes": [],
		"hits": [],
		"accidents": [],
		"score_log": [],
	}
	out["runs"][name] = run_data
	# 先跑两帧空帧，让输入缓存看到“全部松开”，再开始按键。
	_step()
	_step()


func _step() -> void:
	race._physics_process(STEP)
	sim += STEP
	_observe()


## 每帧观察：神游状态变化、事故、错过、新失误；全部带时间戳。
func _observe() -> void:
	for who in ["rabbit", "turtle"]:
		var st := _state(who)
		if st != String(_last_state[who]):
			run_data["events"].append({
				"t": snappedf(sim, 0.01),
				"who": who,
				"from": _last_state[who],
				"to": st,
				"drift": snappedf(_drift(who), 0.01),
				"control": GameManager.current_control,
			})
			_last_state[who] = st
	if GameManager.accident_state != _last_accident:
		run_data["accidents"].append({
			"t": snappedf(sim, 0.01),
			"from": _last_accident,
			"to": GameManager.accident_state,
			"x": snappedf(race.turtle.position.x, 0.1),
		})
		_last_accident = GameManager.accident_state
	for key in race.hit_groups.keys():
		if not _hit_seen.has(key):
			_hit_seen[key] = true
			run_data["hits"].append({
				"t": snappedf(sim, 0.01),
				"group": key,
				"roles": Dictionary(race.hit_roles.get(key, {})).keys(),
				"rabbit": _snap_role("rabbit"),
				"turtle": _snap_role("turtle"),
			})
	if not _trace.is_empty():
		var dt: float = sim - float(_trace["t0"])
		if dt <= 1.26:
			(_trace["samples"] as Array).append([
				snappedf(dt, 0.01), snappedf(_drift(String(_trace["who"])), 0.01)])
			# Showtime 期间 BRO BRAIN 冻结：这段轨迹不能用来证明“0.5 s 后回落”，
			# 记下第一次冻结的时刻，判定时跳过整条。
			if race.showtime_active and not _trace.has("showtime_from"):
				_trace["showtime_from"] = snappedf(dt, 0.01)
		else:
			_trace = {}
	var log: Array = GameManager.score_log
	while _log_seen < log.size():
		var e: Dictionary = log[_log_seen]
		var reason := String(e.get("reason", ""))
		var rec := {
			"t": snappedf(sim, 0.01),
			"reason": reason,
			"points": int(e.get("points", 0)),
			"x": snappedf(race.turtle.position.x, 0.1),
		}
		run_data["score_log"].append(rec)
		if reason.begins_with("mistake:"):
			rec["control"] = GameManager.current_control
			rec["rabbit"] = _snap_role("rabbit")
			rec["turtle"] = _snap_role("turtle")
			run_data["mistakes"].append(rec)
		_log_seen += 1


func _state(who: String) -> String:
	if who == "rabbit":
		return String(race.rabbit_brain.state_name())
	return String(race.turtle_brain.state_name())


func _drift(who: String) -> float:
	if who == "rabbit":
		return float(race.rabbit_brain.drift)
	return float(race.turtle_brain.drift)


func _snap_role(who: String) -> Dictionary:
	if who == "rabbit":
		return {
			"brain": _state("rabbit"),
			"drift": snappedf(_drift("rabbit"), 0.01),
			"state": String(race.rabbit.state),
			"x": snappedf(race.rabbit.position.x, 0.1),
			"y": snappedf(race.rabbit.position.y, 0.1),
		}
	return {
		"brain": _state("turtle"),
		"drift": snappedf(_drift("turtle"), 0.01),
		"state": String(race.turtle.state),
		"x": snappedf(race.turtle.position.x, 0.1),
		"y": snappedf(race.turtle.position.y, 0.1),
		"speed": snappedf(race.turtle.speed, 0.1),
		"speed_scale": snappedf(
			race.turtle.drift_speed_scale(GameManager.current_control == "turtle"), 0.01),
	}


func _snap_pair() -> Dictionary:
	return {
		"t": snappedf(sim, 0.01),
		"control": GameManager.current_control,
		"rabbit": _snap_role("rabbit"),
		"turtle": _snap_role("turtle"),
	}


# ---------------------------------------------------------------- 输入

func _press(action: String) -> void:
	if bool(_pressed.get(action, false)):
		return
	# 另一个垂直键必须先松，并且过一帧——输入缓存只认按下沿。
	for other in ["up", "down"]:
		if other != action and bool(_pressed.get(other, false)):
			Input.action_release(other)
			_pressed[other] = false
			_step()
	Input.action_press(action)
	_pressed[action] = true


func _release(action: String) -> void:
	if not bool(_pressed.get(action, false)):
		return
	Input.action_release(action)
	_pressed[action] = false


func _release_all() -> void:
	Input.action_release("up")
	Input.action_release("down")
	Input.action_release("shift")
	_pressed = {"up": false, "down": false}


func _shift_to(who: String) -> void:
	if GameManager.current_control == who:
		return
	# 上一条轨迹若在 1.26 s 内就被下一次换手截断，回落无从测量：
	# 记 truncated，判定“0.9–1.2 s 已开始回落”时跳过它（0.45 s 缓冲仍照测）。
	if not _trace.is_empty():
		var prev_samples: Array = _trace.get("samples", [])
		var last_dt := 0.0
		if not prev_samples.is_empty():
			last_dt = float(prev_samples[prev_samples.size() - 1][0])
		if last_dt < 1.26:
			_trace["truncated"] = true
	var from_who := GameManager.current_control
	GameManager.toggle_control()
	run_data["shifts"].append({
		"t": snappedf(sim, 0.01),
		"from": from_who,
		"to": who,
		"x": snappedf(race.turtle.position.x, 0.1),
		"before": _snap_pair(),
	})
	_trace = {
		"who": who,
		"t0": sim,
		"drift0": snappedf(_drift(who), 0.01),
		"samples": [],
	}
	run_data["shift_traces"].append(_trace)


func _teleport(x: float) -> void:
	var dx: float = x - float(race.turtle.position.x)
	race.turtle.position.x = x
	if String(race.mount.state) == "RIDING":
		race.rabbit.position.x += dx
	race.rescue_prev_pos.x += dx


# ---------------------------------------------------------------- 录制辅助

func _group(key: String) -> Dictionary:
	for g in race.hazard_groups:
		if String(g["group"]) == key:
			return g
	return {}


func _start(key: String) -> float:
	var g := _group(key)
	return race._group_start(g) if not g.is_empty() else -1.0


func _record_entry(key: String, required: String, force: bool = false) -> void:
	if run_data["entries"].has(key):
		return
	var start := _start(key)
	if start < 0.0:
		return
	# 组合障碍的“进组”是起跳那一刻（动作窗口约 140 px），比统一的 −60 px 早；
	# force 让调用点自己决定采样时刻，不再被 ENTRY_LEAD 挡住。
	if not force and race.turtle.position.x < start - ENTRY_LEAD:
		return
	var snap := _snap_pair()
	snap["group"] = key
	snap["kind"] = String(_group(key).get("kind", ""))
	snap["start"] = start
	snap["required"] = required
	snap["entry_lead_px"] = snappedf(start - race.turtle.position.x, 0.1)
	snap["partner_state"] = _state("turtle" if GameManager.current_control == "rabbit" else "rabbit")
	snap["partner_drift"] = snappedf(
		_drift("turtle" if GameManager.current_control == "rabbit" else "rabbit"), 0.01)
	run_data["entries"][key] = snap


func _segment(name: String, extra: Dictionary = {}) -> Dictionary:
	var d := {
		"name": name,
		"t": snappedf(sim, 0.01),
		"x": snappedf(race.turtle.position.x, 0.1),
		"control": GameManager.current_control,
		"rabbit": _snap_role("rabbit"),
		"turtle": _snap_role("turtle"),
		"bro_meter": GameManager.bro_meter,
		"accident_count": GameManager.accident_count,
	}
	for k in extra:
		d[k] = extra[k]
	run_data["segments"][name] = d
	return d


## 每个 run 结束时的账本：有没有撞、有没有失误、有没有事故。
func _run_tail() -> Dictionary:
	return {
		"mistakes": run_data["mistakes"].size(),
		"hits": run_data["hits"].size(),
		"accidents": run_data["accidents"].size(),
		"hits_detail": run_data["hits"].duplicate(true),
		"accident_detail": run_data["accidents"].duplicate(true),
		"passed_groups": race.passed_groups.keys(),
	}


# ---------------------------------------------------------------- 段 A + B

## A：连续兔子专属（rock3 → beam2），全程控兔子 → 乌龟一路神游。
## B：紧接 A，立刻切乌龟；乌龟带着 A 留下的神游量恢复 → wall1 跃起、切兔蹬踏 →
##   再切回乌龟下潜过 gate2。B 结束时兔子已被放养整段，正好检验“伙伴失控中的组合动作”。
func _run_ab() -> void:
	_reset(7900.0, "rabbit", "ab")
	var rock := _start("rock3")
	var beam := _start("beam2")
	var wall := _start("wall1")
	var gate := _start("gate2")
	var did := {}

	# ---- A ----
	while sim < 16.0 and race.turtle.position.x < beam + 240.0:
		var x: float = race.turtle.position.x
		if not did.has("rock_j") and x >= rock - LEAD_ROCK_JUMP:
			_press("up")
			did["rock_j"] = true
		if did.has("rock_j") and not did.has("rock_r") and x >= rock + 190.0:
			_release("up")
			did["rock_r"] = true
		if not did.has("beam_c") and x >= beam - LEAD_CROUCH:
			_press("down")
			did["beam_c"] = true
		if did.has("beam_c") and not did.has("beam_r") and x >= beam + 220.0:
			_release("down")
			did["beam_r"] = true
		_record_entry("rock3", "jump")
		_record_entry("beam2", "crouch")
		_step()
	_release_all()
	var a_end := _segment("A_rabbit_only", {"groups": ["rock3", "beam2"]})

	# ---- B ----
	_shift_to("turtle")
	run_data["segments"]["B_start_drift"] = {
		"t": snappedf(sim, 0.01),
		"turtle": _snap_role("turtle"),
		"rabbit": _snap_role("rabbit"),
	}
	did = {}
	while sim < 34.0 and race.turtle.position.x < 12400.0:
		var x: float = race.turtle.position.x
		if not did.has("wall_leap") and x >= wall - LEAD_WALL:
			_press("up")
			did["wall_leap"] = true
		if did.has("wall_leap") and not did.has("wall_stomp") \
				and race.turtle.leap_active and x >= wall - WALL_STOMP_AT:
			_release("up")
			_shift_to("rabbit")
			_step()
			_press("up")
			did["wall_stomp"] = true
		if did.has("wall_stomp") and not did.has("wall_stomp_r") and x >= wall + 50.0:
			_release("up")
			did["wall_stomp_r"] = true
		# 蹬踏完成后墙已过：切回乌龟，准备下潜 gate2。
		if did.has("wall_stomp_r") and not did.has("back_to_turtle") and x >= wall + 90.0:
			_shift_to("turtle")
			did["back_to_turtle"] = true
		if not did.has("gate_d") and x >= gate - LEAD_DIVE:
			_press("down")
			did["gate_d"] = true
		if did.has("gate_d") and not did.has("gate_r") and x >= gate + 260.0:
			_release("down")
			did["gate_r"] = true
		_record_entry("gate2", "dive")
		_record_entry("wall1", "leap+stomp")
		_step()
	_release_all()
	var b_end := _segment("B_turtle_only", {"groups": ["wall1", "gate2"]})

	# 段摘要里只保留判定需要的数，避免 JSON 膨胀。
	a_end["end_drift"] = {"rabbit": a_end["rabbit"]["drift"], "turtle": a_end["turtle"]["drift"]}
	b_end["end_drift"] = {"rabbit": b_end["rabbit"]["drift"], "turtle": b_end["turtle"]["drift"]}
	run_data["tail"] = _run_tail()


# ---------------------------------------------------------------- 段 C

## 交替：乌龟专属 → 兔子专属 → 组合（兔跳+龟潜）→ 乌龟专属。
## 每次换手都让上一半停在半路，检验“注意力分配”而不是一次性清空。
func _run_c() -> void:
	_reset(3480.0, "turtle", "c")
	var gate1 := _start("gate1")
	var rock2 := _start("rock2")
	var log1 := _start("log1")
	var shark1 := _start("shark1")
	var did := {}
	var jumps := 0
	while sim < 26.0 and race.turtle.position.x < 7480.0:
		var x: float = race.turtle.position.x
		if not did.has("gate_d") and x >= gate1 - LEAD_DIVE:
			_press("down")
			did["gate_d"] = true
		if did.has("gate_d") and not did.has("gate_r") and x >= gate1 + 250.0:
			_release("down")
			did["gate_r"] = true
		if not did.has("to_rabbit") and x >= 4600.0:
			_shift_to("rabbit")
			did["to_rabbit"] = true
		# 岩檐只能跳：判定只放行“上升中的 JUMPING”。趴低对 SURFACE_ROCK 无效
		# （第一次跑就是把它当 LOW_BEAM 处理，兔子直接撞成 STUNNED）。
		if not did.has("rock_c") and x >= rock2 - LEAD_ROCK_JUMP:
			_press("up")
			did["rock_c"] = true
		if did.has("rock_c") and not did.has("rock_r") and x >= rock2 + 190.0:
			_release("up")
			did["rock_r"] = true
		if not did.has("log_jump") and x >= log1 - LEAD_LOG_JUMP:
			_press("up")
			did["log_jump"] = true
		if did.has("log_jump") and not did.has("log_shift") \
				and String(race.mount.state) == "AIRBORNE":
			_release("up")
			_shift_to("turtle")
			_press("down")
			did["log_shift"] = true
		if did.has("log_shift") and not did.has("log_r") and x >= log1 + 120.0:
			_release("down")
			did["log_r"] = true
		if not did.has("shark_leap") and x >= shark1 - LEAD_LEAP:
			_release("down")
			_press("up")
			did["shark_leap"] = true
		if did.has("shark_leap") and not did.has("shark_r") \
				and race.turtle.leap_active and jumps < 1:
			_release("up")
			jumps += 1
		_record_entry("gate1", "dive")
		_record_entry("rock2", "jump")
		_record_entry("log1", "jump+shift+dive")
		_record_entry("shark1", "leap")
		_step()
		# 起跳后的第一帧：兔子已 JUMPING、还没切乌龟。这一帧才是组合的“进组状态”。
		if did.has("log_jump") and not did.has("log_entry"):
			_record_entry("log1", "jump+shift+dive", true)
			did["log_entry"] = true
	_release_all()
	_segment("C_alternating", {"groups": ["gate1", "rock2", "log1", "shark1"]})
	run_data["tail"] = _run_tail()


# ---------------------------------------------------------------- 段 D + E

## D：开局就控兔子，让乌龟一路神游到 MISCHIEF（先过 rock3/beam2），
##    墙前一刻才切到神游的乌龟跃起、切兔蹬踏；墙后把控制权放回乌龟，
##    让它带着尚未收回的神游下潜过 gate2——组合动作不是提前清空状态再做。
func _run_de() -> void:
	_reset(7900.0, "rabbit", "de")
	var rock := _start("rock3")
	var beam := _start("beam2")
	var wall := _start("wall1")
	var gate := _start("gate2")
	var did := {}
	while sim < 34.0 and race.turtle.position.x < 12400.0:
		var x: float = race.turtle.position.x
		if not did.has("rock_j") and x >= rock - LEAD_ROCK_JUMP:
			_press("up")
			did["rock_j"] = true
		if did.has("rock_j") and not did.has("rock_r") and x >= rock + 190.0:
			_release("up")
			did["rock_r"] = true
		if not did.has("beam_c") and x >= beam - LEAD_CROUCH:
			_press("down")
			did["beam_c"] = true
		if did.has("beam_c") and not did.has("beam_r") and x >= beam + 220.0:
			_release("down")
			did["beam_r"] = true
		# 墙前一刻接手：乌龟已经神游了一整段，跃起窗口只剩 176 px。
		if not did.has("wall_leap") and x >= wall - LEAD_WALL:
			_shift_to("turtle")
			run_data["segments"]["D_shift"] = _snap_pair()
			_press("up")
			did["wall_leap"] = true
		if did.has("wall_leap") and not did.has("wall_stomp") \
				and race.turtle.leap_active and x >= wall - WALL_STOMP_AT:
			_release("up")
			_shift_to("rabbit")
			_step()
			_press("up")
			did["wall_stomp"] = true
		if did.has("wall_stomp") and not did.has("wall_stomp_r") and x >= wall + 50.0:
			_release("up")
			did["wall_stomp_r"] = true
		# 蹬踏完成后不再切回乌龟：让它在神游里继续待着，
		# 直到下潜前一刻才接手——这才是“伙伴最糟的时候被迫接手”。
		if not did.has("gate_d") and x >= gate - LEAD_DIVE:
			_shift_to("turtle")
			_press("down")
			did["gate_d"] = true
		if did.has("gate_d") and not did.has("gate_r") and x >= gate + 260.0:
			_release("down")
			did["gate_r"] = true
		_record_entry("beam2", "crouch")
		_record_entry("wall1", "leap+stomp")
		_record_entry("gate2", "dive")
		_step()
	_release_all()
	_segment("D_dazed_combo", {"groups": ["beam2", "wall1", "gate2"]})
	run_data["tail"] = _run_tail()

	# E 的设定：压力段后到开阔水域，先控乌龟回到 CALM，再切回兔子恢复；
	# 两个角色不能同时恢复——这正是动态平衡要求玩家分配注意力的地方。
	# ---- E：恢复段 ----
	# D 结尾可能刚好触发 Showtime（3 连击）。演出期间 BRO BRAIN 冻结，
	# 先把演出走完再开始计恢复时间，否则测到的是“冻结 1.8 s”。
	var guard := 0
	while race.showtime_active and guard < 240:
		_step()
		guard += 1
	var e0 := sim
	_teleport(67000.0)
	# 乌龟此刻仍受控（D 切过来的），先把它收回 CALM。
	while sim - e0 < 9.0 and _state("turtle") != "CALM":
		_step()
	var t_turtle := sim - e0
	var turtle_recovered := _state("turtle") == "CALM"
	# 再切回兔子：它在 D+E 整段无人照看，必须再花时间收回。
	_shift_to("rabbit")
	var e1 := sim
	while sim - e1 < 7.0 and _state("rabbit") != "CALM":
		_step()
	var t_rabbit := sim - e1
	_segment("E_recovery", {
		"turtle_recover_s": snappedf(t_turtle, 0.01),
		"turtle_recovered": turtle_recovered,
		"rabbit_recover_s": snappedf(t_rabbit, 0.01),
		"rabbit_recovered": _state("rabbit") == "CALM",
		"turtle_before": _state("turtle"),
	})
	run_data["tail"] = _run_tail()


# ---------------------------------------------------------------- 截图（窗口化）

## 兔子受控趴低、乌龟 MISCHIEF：一张图同时看到 HUD 的两个角色身份、
## 当前控制箭头/金环、分级神游条，以及世界里的角色图形+阶段符号。
## P6 换位后 beam2 离起点只有 7.7 s 的航程，自然神游到不了 MISCHIEF（≥9）；
## 这里在截图前直接把 turtle_brain.drift 设到 MISCHIEF 档（同 _capture_stages），
## “自然累积”的证据是 AB/DE 的逐帧轨迹，不是这张图。
func _capture_p1() -> void:
	_reset(7900.0, "rabbit", "capture")
	if race.hud != null:
		race.hud.hint_timer = 0.0
		race.hud.prompt_timer = 0.0
		race.hud.feedback_timer = 0.0
	var beam := _start("beam2")
	var did := {}
	while sim < 16.0 and race.turtle.position.x < beam + 150.0:
		var x: float = race.turtle.position.x
		if not did.has("beam_c") and x >= beam - LEAD_CROUCH:
			_press("down")
			did["beam_c"] = true
		_step()
	race.turtle_brain.drift = 9.6
	race.turtle_brain.hold = 0.0
	_step()
	_step()
	for i in 6:
		await get_tree().process_frame
	for i in 4:
		await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("refine06-p1-hud.png")
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE ", path,
		" rabbit=", _state("rabbit"), "/", race.rabbit.state,
		" turtle=", _state("turtle"), " drift=", snappedf(_drift("turtle"), 0.01),
		" control=", GameManager.current_control)
	print("MARKDBG ctrl_drift=", snappedf(race.turtle.drift, 0.01),
		" state=", race.turtle.drift_state,
		" accident=", race.turtle.accident,
		" daze=", snappedf(race.turtle.daze_time, 0.01),
		" dunk=", snappedf(race.turtle.dunk_timer, 0.01),
		" pos=", race.turtle.position, " cam=", race.camera.position)
	_release_all()


## 四档 HUD/世界标记同屏对照。这里直接设置 turtle_brain.drift 只是为了截到
## 各档位的画面；状态本身是否自然累积/回落由 AB/CDE 三段逐帧记录证明。
func _capture_stages() -> void:
	_reset(8900.0, "rabbit", "stage_capture")
	# 上一轮模拟留下的“干净通过/教学”横幅会挂在屏幕中央；截图前清掉，
	# 免得把旧提示当成这一档位的 HUD 状态。
	if race.hud != null:
		race.hud.hint_timer = 0.0
		race.hud.prompt_timer = 0.0
		race.hud.feedback_timer = 0.0
	_press("down")
	var dir := ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	var stages := [[1.5, "calm"], [4.5, "distracted"], [7.5, "restless"], [10.5, "mischief"]]
	for st in stages:
		race.turtle_brain.drift = float(st[0])
		race.turtle_brain.hold = 0.0
		_step()
		_step()
		for i in 4:
			await get_tree().process_frame
		for i in 3:
			await RenderingServer.frame_post_draw
		var path := dir.path_join("refine06-p1-hud-%s.png" % String(st[1]))
		get_viewport().get_texture().get_image().save_png(path)
		print("CAPTURE_STAGE ", path, " drift=", snappedf(race.turtle.drift, 0.01),
			" state=", race.turtle.drift_state,
			" hud=", race.turtle_brain.state_name())
	_release_all()


# ---------------------------------------------------------------- 判定

func _evaluate() -> void:
	out["checks"] = []
	var runs: Dictionary = out["runs"]
	var ab: Dictionary = runs.get("ab", {})
	var c: Dictionary = runs.get("c", {})
	var de: Dictionary = runs.get("de", {})

	# ---- A：连续兔子专属 ----
	var a: Dictionary = ab.get("segments", {}).get("A_rabbit_only", {})
	var a_pass := _passed(ab, ["rock3", "beam2"])
	_expect("A 连续兔子专属：rock3/beam2 都通过（%s）" % str(ab.get("tail", {}).get("passed_groups", [])),
		a_pass)
	_expect("A 两连没有撞（hits=%d）" % int(ab.get("tail", {}).get("hits", -1)),
		int(ab.get("tail", {}).get("hits", -1)) == 0 and ab.get("mistakes", []).is_empty())
	var a_esc: Array = []
	for e in ab.get("events", []):
		if String(e["who"]) == "turtle" and String(e["to"]) != "CALM" \
				and float(e["t"]) <= float(a.get("t", 0.0)) + 0.01:
			a_esc.append(String(e["to"]))
	_expect("A 不切乌龟时它的神游确实在升级（%s，末段 drift=%.2f）" % [
		str(a_esc), float(a.get("end_drift", {}).get("turtle", 0.0))],
		a_esc.size() >= 1 and float(a.get("end_drift", {}).get("turtle", 0.0)) >= 6.0)
	_expect("A 受控兔子保持 CALM（drift=%.2f）" % float(a.get("end_drift", {}).get("rabbit", 99.0)),
		float(a.get("end_drift", {}).get("rabbit", 99.0)) <= 0.01)

	# ---- B：连续乌龟专属，切在 A 的坏状态上 ----
	var bstart: Dictionary = ab.get("segments", {}).get("B_start_drift", {})
	var b: Dictionary = ab.get("segments", {}).get("B_turtle_only", {})
	var b_pass := _passed(ab, ["wall1", "gate2"])
	_expect("B 连续乌龟专属：wall1/gate2 都通过（%s）" % str(ab.get("tail", {}).get("passed_groups", [])),
		b_pass)
	_expect("B 整段没有撞（hits=%d, mistakes=%d）" % [
		int(ab.get("tail", {}).get("hits", -1)), int(ab.get("tail", {}).get("mistakes", -1))],
		int(ab.get("tail", {}).get("hits", -1)) == 0
		and int(ab.get("tail", {}).get("mistakes", -1)) == 0)
	_expect("B 切手时乌龟带着 A 留下的神游（%s drift=%.2f）" % [
		String(bstart.get("turtle", {}).get("brain", "?")),
		float(bstart.get("turtle", {}).get("drift", 0.0))],
		float(bstart.get("turtle", {}).get("drift", 0.0)) >= 6.0)
	var gate_entry: Dictionary = ab.get("entries", {}).get("gate2", {})
	var wall_entry: Dictionary = ab.get("entries", {}).get("wall1", {})
	_expect("B 切手后到 gate2 已在恢复（乌龟 drift %.2f→%.2f）" % [
		float(bstart.get("turtle", {}).get("drift", 0.0)),
		float(gate_entry.get("turtle", {}).get("drift", 99.0))],
		float(gate_entry.get("turtle", {}).get("drift", 99.0))
			< float(bstart.get("turtle", {}).get("drift", 0.0)))
	_expect("B 及时切换的回报：到墙前乌龟已回到 CALM（drift=%.2f）" % [
		float(wall_entry.get("turtle", {}).get("drift", 99.0))],
		String(wall_entry.get("turtle", {}).get("brain", "")) == "CALM")
	_expect("B 伙伴失控中仍完成组合：墙前兔子是 %s（drift=%.2f）且墙过了" % [
		String(wall_entry.get("rabbit", {}).get("brain", "")),
		float(wall_entry.get("rabbit", {}).get("drift", 0.0))],
		float(wall_entry.get("rabbit", {}).get("drift", 0.0)) >= 3.0 and b_pass)
	_expect("B 全程无事故（accidents=%d）" % int(ab.get("tail", {}).get("accidents", -1)),
		int(ab.get("tail", {}).get("accidents", -1)) == 0)

	# ---- C：交替 ----
	var c_pass := _passed(c, ["gate1", "rock2", "log1", "shark1"])
	_expect("C 交替：gate1/rock2/log1/shark1 都通过（%s）" % str(c.get("tail", {}).get("passed_groups", [])),
		c_pass)
	_expect("C 整段没有撞（hits=%d, mistakes=%d）" % [
		int(c.get("tail", {}).get("hits", -1)), int(c.get("tail", {}).get("mistakes", -1))],
		int(c.get("tail", {}).get("hits", -1)) == 0
		and int(c.get("tail", {}).get("mistakes", -1)) == 0)
	# 交替段需要两次换手：开局控龟下潜 → 换兔起跳/趴低 → 浮木前换回龟下潜。
	# 鲨鱼是乌龟专属，不需要再换；硬凑第三次等于故意做错一次。
	var c_shifts: Array = c.get("shifts", [])
	var has_tr := false
	var has_rt := false
	for s in c_shifts:
		if String(s["from"]) == "turtle" and String(s["to"]) == "rabbit":
			has_tr = true
		if String(s["from"]) == "rabbit" and String(s["to"]) == "turtle":
			has_rt = true
	_expect("C 交替：龟→兔、兔→龟两次换手都发生（%d 次）" % c_shifts.size(),
		c_shifts.size() >= 2 and has_tr and has_rt)
	var log_entry: Dictionary = c.get("entries", {}).get("log1", {})
	_expect("C 浮木组合：进组时控兔子起跳（control=%s, rabbit=%s）" % [
		String(log_entry.get("control", "?")),
		String(log_entry.get("rabbit", {}).get("state", "?"))],
		String(log_entry.get("control", "")) == "rabbit"
		and String(log_entry.get("rabbit", {}).get("state", "")) in ["JUMPING", "FALLING"])
	var log_shift := false
	for s in c.get("shifts", []):
		if String(s["to"]) == "turtle" and float(s["x"]) > 6000.0 and float(s["x"]) < 6500.0:
			log_shift = true
	_expect("C 浮木组合：起跳后在浮木前切到乌龟（记录到 shift）", log_shift)
	_expect("C 全程无事故（accidents=%d）" % int(c.get("tail", {}).get("accidents", -1)),
		int(c.get("tail", {}).get("accidents", -1)) == 0)

	# ---- D：伙伴失控中的组合 ----
	var d_shift: Dictionary = de.get("segments", {}).get("D_shift", {})
	var d: Dictionary = de.get("segments", {}).get("D_dazed_combo", {})
	var d_pass := _passed(de, ["beam2", "wall1", "gate2"])
	_expect("D 伙伴失控中组合：beam2/wall1/gate2 都通过（%s）" % str(de.get("tail", {}).get("passed_groups", [])),
		d_pass)
	_expect("D 整段没有撞（hits=%d, mistakes=%d）" % [
		int(de.get("tail", {}).get("hits", -1)), int(de.get("tail", {}).get("mistakes", -1))],
		int(de.get("tail", {}).get("hits", -1)) == 0
		and int(de.get("tail", {}).get("mistakes", -1)) == 0)
	_expect("D 接手时乌龟正处于 MISCHIEF（%s drift=%.2f）" % [
		String(d_shift.get("turtle", {}).get("brain", "?")),
		float(d_shift.get("turtle", {}).get("drift", 0.0))],
		String(d_shift.get("turtle", {}).get("brain", "")) == "MISCHIEF")
	var d_gate: Dictionary = de.get("entries", {}).get("gate2", {})
	_expect("D 在龟神游时下潜仍过 gate2（进组：控制=%s 乌龟=%s drift=%.2f）" % [
		String(d_gate.get("control", "?")),
		String(d_gate.get("turtle", {}).get("brain", "?")),
		float(d_gate.get("turtle", {}).get("drift", 0.0))],
		String(d_gate.get("control", "")) == "turtle"
		and float(d_gate.get("turtle", {}).get("drift", 0.0)) >= 3.0)
	_expect("D 全程无事故（accidents=%d）" % int(de.get("tail", {}).get("accidents", -1)),
		int(de.get("tail", {}).get("accidents", -1)) == 0)

	# ---- E：恢复 ----
	var e: Dictionary = de.get("segments", {}).get("E_recovery", {})
	_expect("E 压后恢复：乌龟在 9 s 内回到 CALM（%.2f s）" % float(e.get("turtle_recover_s", 99.0)),
		bool(e.get("turtle_recovered", false)) and float(e.get("turtle_recover_s", 99.0)) <= 9.0)
	_expect("E 再切兔子也能恢复（%.2f s，%s）" % [
		float(e.get("rabbit_recover_s", 99.0)), str(e.get("rabbit_recovered", false))],
		bool(e.get("rabbit_recovered", false)) and float(e.get("rabbit_recover_s", 99.0)) <= 7.0)
	_expect("E 恢复过程中确实发生了状态回落（记录到事件）",
		_has_recovery_events(de))

	# ---- 接手缓冲：换手后 0.5 s 内不回落，之后 2.0/s 回落 ----
	# 这是“快速 SHIFT 白嫖不到恢复”的逐帧证据：只认连续受控时间，不认一次换手。
	var trace_checked := 0
	var hold_bad: Array = []
	var fall_bad: Array = []
	for run in [ab, c, de]:
		for tr in run.get("shift_traces", []):
			var d0 := float(tr.get("drift0", 0.0))
			if d0 < 3.0:
				continue
			if bool(tr.get("truncated", false)):
				continue
			# 轨迹窗口里出现 Showtime：brain 被冻结，回落测不到，跳过（同 E 段先等演出走完）。
			if float(tr.get("showtime_from", 99.0)) <= 1.26:
				continue
			trace_checked += 1
			var at_hold := d0
			var after := d0
			for s in tr.get("samples", []):
				var dt := float(s[0])
				if dt <= 0.45:
					at_hold = float(s[1])
				elif dt >= 0.9 and dt <= 1.2:
					after = minf(after, float(s[1]))
			if at_hold < d0 - 0.06:
				hold_bad.append("%s %.2f→%.2f" % [tr["who"], d0, at_hold])
			if after > d0 - 0.5:
				fall_bad.append("%s %.2f→%.2f" % [tr["who"], d0, after])
	_expect("SHIFT 接手后前 0.45 s 不回落（逐帧轨迹 %d 条，异常 %s）" % [
		trace_checked, str(hold_bad)],
		trace_checked >= 4 and hold_bad.is_empty())
	_expect("连续受控 0.5 s 后才开始回落（0.9–1.2 s 内至少降 0.5，异常 %s）" % str(fall_bad),
		trace_checked >= 4 and fall_bad.is_empty())

	# ---- 反馈：接手有即时反馈、恢复到 CALM 再报一次 ----
	var shift_take := _feedback_for(ab, "开始收心")
	var shift_take_d := _feedback_for(de, "开始收心")
	var back := _feedback_for(de, "回过神")
	_expect("SHIFT 接手正在神游的角色：立刻有反馈（AB %d 条 / DE %d 条）" % [
		shift_take.size(), shift_take_d.size()],
		shift_take_d.size() >= 1)
	_expect("恢复完成时再报一次（DE %d 条，%s）" % [
		back.size(), str(back.slice(0, 3))], back.size() >= 1)
	if not shift_take_d.is_empty():
		var dt: float = float(shift_take_d[0]["t"]) - float(_first_shift_t(de))
		_expect("接手反馈在 0.75 s 内出现（实测 %.2f s）" % dt,
			dt >= 0.0 and dt <= 0.75)

	# ---- 无解组合判定 ----
	out["verdict"] = {
		"unwinnable_found": not (a_pass and b_pass and c_pass and d_pass),
		"all_required_groups_passed": a_pass and b_pass and c_pass and d_pass,
		"no_hits": int(ab.get("tail", {}).get("hits", 1)) == 0
			and int(c.get("tail", {}).get("hits", 1)) == 0
			and int(de.get("tail", {}).get("hits", 1)) == 0,
		"no_accidents": int(ab.get("tail", {}).get("accidents", 1)) == 0
			and int(c.get("tail", {}).get("accidents", 1)) == 0
			and int(de.get("tail", {}).get("accidents", 1)) == 0,
	}
	_expect("矩阵结论：没有发现无解组合（所有必做动作在伙伴神游/恢复中都完成）",
		not bool(out["verdict"]["unwinnable_found"]))


func _passed(run: Dictionary, keys: Array) -> bool:
	var passed: Array = run.get("tail", {}).get("passed_groups", [])
	for k in keys:
		if not passed.has(k):
			return false
	return true


func _has_recovery_events(run: Dictionary) -> bool:
	# 状态从高档回落到低档，且当时控制着那个角色。
	var order := {"CALM": 0, "DISTRACTED": 1, "RESTLESS": 2, "MISCHIEF": 3}
	for e in run.get("events", []):
		var f := int(order.get(String(e["from"]), 9))
		var t := int(order.get(String(e["to"]), 9))
		if t < f and String(e["control"]) == String(e["who"]):
			return true
	return false


func _feedback_for(run: Dictionary, needle: String) -> Array:
	var out_a: Array = []
	for f in run.get("feedback", []):
		if String(f["text"]).contains(needle):
			out_a.append(f)
	return out_a


func _first_shift_t(run: Dictionary) -> float:
	var arr: Array = run.get("shifts", [])
	return float(arr[0]["t"]) if not arr.is_empty() else -1.0


func _expect(label: String, ok: bool) -> void:
	out["checks"].append({"label": label, "ok": ok})
	if not ok:
		failures.append(label)


func _write() -> void:
	out["summary"] = {
		"checks": out["checks"].size(),
		"failed": failures.size(),
		"failures": failures,
	}
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out, "  "))
		f.close()
		print("WROTE " + OUT_PATH)
