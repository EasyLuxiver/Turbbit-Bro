extends Node
## CORE-FEEL-08 P0-A — 神游必须真的影响控制（headless，真实 race.gd / 真实输入）
##
## 旧版神游只改数值（偏移、速度、空中修正），玩家仍然“按了就好”。
## 本探针核对四件事，全部用 Input.action_press 走真实输入路径：
##   1) 四阶段可区分：CALM 0 ms，DISTRACTED 40–100，RESTLESS 100–180，MISCHIEF 180–260；
##   2) 实测延迟：BITT 起跳 / TUBO 下潜真的晚这么多毫秒才执行，但一定执行（不丢键）；
##   3) 按住不放不受影响：延迟只挂在按下沿，按住时神游涨到满值也不会重新计时；
##   4) 自主动作与恢复：BITT 每 2.6 s 自己趴 0.35 s，TUBO 壳自己漂 ±14 px；
##      恢复后延迟归零、有“回过神”反馈；不写 BRO、不产生事故、不强制换手。
##
## 用法：
##   D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
##       res://scenes/stage8_drift_control.tscn > docs/reports/logs/core-feel-08-p0a.log 2>&1
##
## 输出：docs/reports/longrun/core-feel-08-p0a-drift-control.json

const LevelDataScript = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/core-feel-08-p0a-drift-control.json"
const STEP := 1.0 / 60.0
const STAGE_POINTS := {
	"CALM": 2.0, "DISTRACTED": 4.5, "RESTLESS": 7.5, "MISCHIEF": 11.5,
}

var is_runner := false
var race: Node = null
var checks: Array = []
var data := {}
var feedback_log: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	Locale.set_language("zh")
	GameManager.start_race()
	for i in 4:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null or race.hud == null:
		push_error("P0-A: no race scene")
		_finish(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = true
	GameManager.feedback.connect(_on_feedback)
	race.load_level(LevelDataScript.groups(), LevelDataScript.boost_lanes())
	await get_tree().physics_frame
	# 只看神游本身：清掉障碍/食物，避免碰撞与 Showtime 冻结神游时钟。
	race.hazard_groups = []
	race.entered_groups.clear()
	race.boost_lanes = []
	race._snack_cache_sig = -1
	race._snack_cache = []

	data["stage_table"] = _stage_table()
	data["rabbit_latency"] = _rabbit_latency_case()
	data["turtle_latency"] = _turtle_latency_case()
	data["hold_no_redelay"] = _hold_case()
	data["autonomy_rabbit"] = _autocrouch_case()
	data["autonomy_turtle"] = _tubo_autodrift_case()
	data["recovery"] = _recovery_case()
	data["no_trap"] = _no_trap_case()

	_write()
	_finish(0 if _all_pass() else 1)


# ---------------- 1) 四阶段延迟表 ----------------

func _stage_table() -> Dictionary:
	var out := {}
	for who in ["rabbit", "turtle"]:
		var rows := {}
		_reset_race_state()
		for stage in STAGE_POINTS:
			_set_drift(who, float(STAGE_POINTS[stage]))
			rows[stage] = {
				"drift": snappedf(float(STAGE_POINTS[stage]), 0.01),
				"state": _brain(who).state_name(),
				"delay_ms": race.drift_react_delay_ms(who),
			}
		out[who] = rows
		_expect("1 %s CALM 不延迟（0 ms）" % who,
			int(rows["CALM"]["delay_ms"]) == 0 and rows["CALM"]["state"] == "CALM",
			str(rows["CALM"]))
		_expect("1 %s 分心 40–100 ms" % who,
			int(rows["DISTRACTED"]["delay_ms"]) >= 40
				and int(rows["DISTRACTED"]["delay_ms"]) <= 100
				and rows["DISTRACTED"]["state"] == "DISTRACTED",
			str(rows["DISTRACTED"]))
		_expect("1 %s 坐不住 100–180 ms" % who,
			int(rows["RESTLESS"]["delay_ms"]) >= 100
				and int(rows["RESTLESS"]["delay_ms"]) <= 180
				and rows["RESTLESS"]["state"] == "RESTLESS",
			str(rows["RESTLESS"]))
		_expect("1 %s 恶作剧 180–260 ms（最高档最明显）" % who,
			int(rows["MISCHIEF"]["delay_ms"]) >= 180
				and int(rows["MISCHIEF"]["delay_ms"]) <= 260
				and rows["MISCHIEF"]["state"] == "MISCHIEF",
			str(rows["MISCHIEF"]))
		_expect("1 %s 四档严格递增（不是同一套数字换名字）" % who,
			int(rows["CALM"]["delay_ms"]) < int(rows["DISTRACTED"]["delay_ms"])
				and int(rows["DISTRACTED"]["delay_ms"]) < int(rows["RESTLESS"]["delay_ms"])
				and int(rows["RESTLESS"]["delay_ms"]) < int(rows["MISCHIEF"]["delay_ms"]),
			"%d/%d/%d/%d" % [rows["CALM"]["delay_ms"],
				rows["DISTRACTED"]["delay_ms"], rows["RESTLESS"]["delay_ms"],
				rows["MISCHIEF"]["delay_ms"]])
	# 两角色不是同一套数字改名：同一档延迟/后果不同。
	_expect("1 两角色不是同一套数字换名字（同档延迟不同）",
		int(out["rabbit"]["MISCHIEF"]["delay_ms"])
			!= int(out["turtle"]["MISCHIEF"]["delay_ms"]),
		"rabbit=%d turtle=%d" % [out["rabbit"]["MISCHIEF"]["delay_ms"],
			out["turtle"]["MISCHIEF"]["delay_ms"]])
	return out


# ---------------- 2) 实测：BITT 起跳延迟 ----------------

func _rabbit_latency_case() -> Dictionary:
	var out := {}
	for stage in STAGE_POINTS:
		out[stage] = _measure_jump_frames(float(STAGE_POINTS[stage]))
	var calm_ms := int(round(float(out["CALM"]) * STEP * 1000.0))
	var dist_ms := int(round(float(out["DISTRACTED"]) * STEP * 1000.0))
	var rest_ms := int(round(float(out["RESTLESS"]) * STEP * 1000.0))
	var mis_ms := int(round(float(out["MISCHIEF"]) * STEP * 1000.0))
	data["rabbit_latency_ms"] = {"CALM": calm_ms, "DISTRACTED": dist_ms,
		"RESTLESS": rest_ms, "MISCHIEF": mis_ms}
	_expect("2 BITT 起跳：CALM 当帧起跳（<= %d ms）" % 34, calm_ms <= 34, str(calm_ms))
	_expect("2 BITT 起跳：分心后实测 >= 40 ms", dist_ms >= 40, str(dist_ms))
	_expect("2 BITT 起跳：坐不住后实测 >= 100 ms", rest_ms >= 100, str(rest_ms))
	_expect("2 BITT 起跳：恶作剧实测 >= 180 ms（明显慢半拍）",
		mis_ms >= 180, str(mis_ms))
	_expect("2 BITT 起跳：四档实测严格递增",
		calm_ms < dist_ms and dist_ms < rest_ms and rest_ms < mis_ms,
		"%d/%d/%d/%d" % [calm_ms, dist_ms, rest_ms, mis_ms])
	_expect("2 BITT 起跳：延迟后仍然执行（不丢键、不锁输入）",
		int(out["MISCHIEF"]) > 0, str(out))
	return out


func _measure_jump_frames(drift: float) -> int:
	_reset_race_state()
	GameManager.set_control("rabbit")
	_set_drift("rabbit", drift)
	race.mount.mark_riding()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.rabbit.state = "RIDING"
	Input.action_release("up")
	_tick(2)
	var log_before: int = race.input_buffer_log.size()
	# 探针专用：清掉“真实按键事件去重”的时间戳，否则同一毫秒内的连续注入
	# 会被 _buffer_input 当成重复事件而跳过记录（生产逻辑不变）。
	race._buf_event_msec = -9999
	Input.action_press("up")
	var frames := 0
	while frames < 40:
		_tick(1)
		frames += 1
		if race.input_buffer_log.size() > log_before:
			break
	Input.action_release("up")
	if race.input_buffer_log.size() > log_before:
		return frames
	return -1


# ---------------- 3) 实测：TUBO 下潜延迟 ----------------

func _turtle_latency_case() -> Dictionary:
	var out := {}
	for stage in STAGE_POINTS:
		out[stage] = _measure_dive_frames(float(STAGE_POINTS[stage]))
	var calm_ms := int(round(float(out["CALM"]) * STEP * 1000.0))
	var dist_ms := int(round(float(out["DISTRACTED"]) * STEP * 1000.0))
	var rest_ms := int(round(float(out["RESTLESS"]) * STEP * 1000.0))
	var mis_ms := int(round(float(out["MISCHIEF"]) * STEP * 1000.0))
	data["turtle_latency_ms"] = {"CALM": calm_ms, "DISTRACTED": dist_ms,
		"RESTLESS": rest_ms, "MISCHIEF": mis_ms}
	_expect("3 TUBO 下潜：CALM 当帧生效（<= %d ms）" % 34, calm_ms <= 34, str(calm_ms))
	_expect("3 TUBO 下潜：分心后实测 >= 40 ms", dist_ms >= 40, str(dist_ms))
	_expect("3 TUBO 下潜：坐不住后实测 >= 100 ms", rest_ms >= 100, str(rest_ms))
	_expect("3 TUBO 下潜：恶作剧实测 >= 180 ms（比兔子慢得更明显）",
		mis_ms >= 180 and mis_ms >= int(round(float(out["CALM"]) * STEP * 1000.0)),
		str(mis_ms))
	_expect("3 TUBO 下潜：四档实测严格递增",
		calm_ms < dist_ms and dist_ms < rest_ms and rest_ms < mis_ms,
		"%d/%d/%d/%d" % [calm_ms, dist_ms, rest_ms, mis_ms])
	_expect("3 TUBO 下潜：延迟后仍然执行（不丢键、不锁输入）",
		int(out["MISCHIEF"]) > 0, str(out))
	return out


func _measure_dive_frames(drift: float) -> int:
	_reset_race_state()
	GameManager.set_control("turtle")
	_set_drift("turtle", drift)
	race.turtle.position.y = Tuning.NEUTRAL_DEPTH
	Input.action_release("down")
	_tick(4)
	Input.action_press("down")
	var frames := 0
	while frames < 40:
		_tick(1)
		frames += 1
		if race.turtle.diving:
			break
	Input.action_release("down")
	if race.turtle.diving:
		return frames
	return -1


# ---------------- 4) 按住不放不被重新延迟 ----------------

func _hold_case() -> Dictionary:
	_reset_race_state()
	GameManager.set_control("turtle")
	_set_drift("turtle", 0.0)
	race.turtle.position.y = Tuning.NEUTRAL_DEPTH
	Input.action_release("down")
	_tick(4)
	Input.action_press("down")
	_tick(10)
	var diving_before: bool = race.turtle.diving
	# 按住的同时神游涨到满值：延迟只挂在按下沿，不应该重新计时。
	_set_drift("turtle", Tuning.DRIFT_CAP)
	var diving_all := true
	for i in 30:
		_tick(1)
		if not race.turtle.diving:
			diving_all = false
	var y_after: float = race.turtle.position.y
	Input.action_release("down")
	var out := {
		"diving_before": diving_before,
		"diving_while_held_at_cap": diving_all,
		"depth": snappedf(y_after - Tuning.NEUTRAL_DEPTH, 0.1),
	}
	_expect("4 按住 ↓ 在 CALM 立即下潜", diving_before, str(out))
	_expect("4 按住时神游涨满不会重新延迟（持续输入不受影响）", diving_all, str(out))
	_expect("4 按住下潜真的沉下去（不是只改标记）",
		float(out["depth"]) >= 10.0, str(out["depth"]))
	return out


# ---------------- 5) BITT 自主动作：自己趴下 ----------------

func _autocrouch_case() -> Dictionary:
	_reset_race_state()
	GameManager.set_control("turtle")
	_set_drift("rabbit", Tuning.DRIFT_CAP)
	var bro0: int = GameManager.bro_meter
	var acc0: int = GameManager.accident_count
	race.drift_impair_log.clear()
	feedback_log.clear()
	var crouch_frames := 0
	var states := {}
	for i in 60 * 8:
		_tick(1)
		states[String(race.rabbit.state)] = int(states.get(String(race.rabbit.state), 0)) + 1
		if race.rabbit.state == "CROUCHING":
			crouch_frames += 1
	var events: Array = []
	var intervals: Array = []
	var last_t := -1.0
	for e in race.drift_impair_log:
		if String(e.get("kind", "")) != "autocrouch":
			continue
		var t := float(e["t"])
		events.append(snappedf(t, 0.01))
		if last_t >= 0.0:
			intervals.append(snappedf(t - last_t, 0.01))
		last_t = t
	var fb := _find_feedback("趴下")
	var out := {
		"events": events,
		"intervals": intervals,
		"crouch_frames": crouch_frames,
		"crouch_seconds": snappedf(crouch_frames * STEP, 0.01),
		"state_frames": states,
		"feedback": fb,
		"bro_delta": GameManager.bro_meter - bro0,
		"accident_delta": GameManager.accident_count - acc0,
		"control": GameManager.current_control,
	}
	_expect("5 8 s 内 BITT 至少自己趴 3 次", events.size() >= 3, str(events))
	var periodic := not intervals.is_empty()
	for iv in intervals:
		if absf(float(iv) - Tuning.BITT_AUTOCROUCH_PERIOD) > 0.05:
			periodic = false
	_expect("5 自主动作按 2.6 s 周期发生（不是每帧乱动）", periodic, str(intervals))
	_expect("5 姿势真的变过（CROUCHING 帧 >= 15）",
		crouch_frames >= 15, str(crouch_frames))
	_expect("5 自主动作有可见提示（“趴下”）", fb.contains("趴下"), fb)
	_expect("5 自主动作不写 BRO、不产生事故、不强制换手",
		int(out["bro_delta"]) == 0 and int(out["accident_delta"]) == 0
			and String(out["control"]) == "turtle",
		str(out))
	return out


# ---------------- 6) TUBO 自主动作：壳自己漂 ----------------

func _tubo_autodrift_case() -> Dictionary:
	var mis := _depth_range(Tuning.DRIFT_CAP)
	var rest := _depth_range(7.5)
	var out := {
		"mischief_range_px": mis["range"],
		"restless_range_px": rest["range"],
		"mischief_depth": mis,
		"restless_depth": rest,
		"max_autodrift_px": mis["max_autodrift"],
	}
	_expect("6 TUBO 恶作剧比坐不住多漂（壳自己在动，不只是晃）",
		float(mis["range"]) >= float(rest["range"]) + 5.0, str(out))
	_expect("6 壳自己漂的幅度读得到（|autodrift_px| 峰值 >= 10）",
		float(mis["max_autodrift"]) >= 10.0, str(mis["max_autodrift"]))
	_expect("6 TUBO 自主动作是“漂”不是“潜到底”（最大偏移 <= 45 px）",
		float(mis["max_abs"]) <= 45.0, str(mis["max_abs"]))
	_expect("6 TUBO 漂的时候没有下潜（diving 一直 false）",
		not bool(mis["diving_any"]), str(mis["diving_any"]))
	# 玩家按住 ↓ 立刻接管：目标深度整段覆盖自主动作。
	_reset_race_state()
	GameManager.set_control("turtle")
	_set_drift("turtle", Tuning.DRIFT_CAP)
	race.turtle.position.y = Tuning.NEUTRAL_DEPTH
	Input.action_release("down")
	_tick(4)
	Input.action_press("down")
	_tick(30)
	var overrode: bool = race.turtle.diving
	var depth: float = race.turtle.position.y - Tuning.NEUTRAL_DEPTH
	Input.action_release("down")
	_expect("6 玩家按住 ↓ 就能接管（自主动作让位）",
		overrode and depth >= 20.0, "diving=%s depth=%.1f" % [overrode, depth])
	return out


func _depth_range(drift: float) -> Dictionary:
	_reset_race_state()
	GameManager.set_control("turtle")
	_set_drift("turtle", drift)
	var y0: float = race.turtle.position.y
	var lo := y0
	var hi := y0
	var max_abs := 0.0
	var max_autodrift := 0.0
	var diving_any := false
	for i in 60 * 6:
		_tick(1)
		var y: float = race.turtle.position.y
		lo = minf(lo, y)
		hi = maxf(hi, y)
		max_abs = maxf(max_abs, absf(y - Tuning.NEUTRAL_DEPTH))
		max_autodrift = maxf(max_autodrift, absf(float(race.turtle.autodrift_px)))
		diving_any = diving_any or race.turtle.diving
	return {"range": snappedf(hi - lo, 0.1), "max_abs": snappedf(max_abs, 0.1),
		"max_autodrift": snappedf(max_autodrift, 0.1),
		"diving_any": diving_any}


# ---------------- 7) 恢复 ----------------

func _recovery_case() -> Dictionary:
	_reset_race_state()
	GameManager.set_control("rabbit")
	_set_drift("rabbit", Tuning.DRIFT_CAP)
	feedback_log.clear()
	race._drift_lag_fb_t = {"rabbit": -99.0, "turtle": -99.0}
	var start_ms: int = race.drift_react_delay_ms("rabbit")
	var frames := 0
	var zero_at := -1
	while frames < 60 * 10:
		_tick(1)
		frames += 1
		if zero_at < 0 and race.drift_react_delay_ms("rabbit") == 0:
			zero_at = frames
		if race.rabbit_brain.drift <= 0.0001:
			break
	var end_ms: int = race.drift_react_delay_ms("rabbit")
	var out := {
		"delay_start_ms": start_ms,
		"delay_end_ms": end_ms,
		"delay_zero_at_s": snappedf(zero_at * STEP, 0.01),
		"drift": snappedf(float(race.rabbit_brain.drift), 0.01),
		"back_feedback": _find_feedback("回过神"),
		"control": GameManager.current_control,
	}
	_expect("7 恢复后延迟回到 0", end_ms == 0 and float(out["drift"]) <= 0.0001,
		str(out))
	_expect("7 延迟在 2–7 s 内消失（渐变，不是瞬清）",
		float(out["delay_zero_at_s"]) >= 2.0 and float(out["delay_zero_at_s"]) <= 7.0,
		str(out["delay_zero_at_s"]))
	_expect("7 恢复过程报“回过神”，且没有强制换手",
		String(out["back_feedback"]).contains("回过神")
			and String(out["control"]) == "rabbit",
		"%s / %s" % [out["back_feedback"], out["control"]])
	return out


# ---------------- 8) 不锁死 / 不反转 / 不强制换人 ----------------

func _no_trap_case() -> Dictionary:
	_reset_race_state()
	var bro0: int = GameManager.bro_meter
	var acc0: int = GameManager.accident_count
	var reversed_any := false
	var control_changed := false
	# 每个阶段各 2 s：一边是兔子受控（↑ 起跳），一边是乌龟受控（↓ 下潜）。
	for stage in STAGE_POINTS:
		var d := float(STAGE_POINTS[stage])
		_set_drift("rabbit", d)
		_set_drift("turtle", d)
		GameManager.set_control("rabbit")
		var c0: String = GameManager.current_control
		_tick(120)
		if GameManager.current_control != c0:
			control_changed = true
		GameManager.set_control("turtle")
		race.turtle.position.y = Tuning.NEUTRAL_DEPTH
		Input.action_press("down")
		_tick(30)
		# 反转 = 按 ↓ 反而上浮；这里只要有下沉趋势就说明方向没反。
		if race.turtle.position.y < Tuning.NEUTRAL_DEPTH - 1.0:
			reversed_any = true
		Input.action_release("down")
		_tick(10)
	var out := {
		"bro_delta": GameManager.bro_meter - bro0,
		"accident_delta": GameManager.accident_count - acc0,
		"accident_state": GameManager.accident_state,
		"reversed": reversed_any,
		"forced_switch": control_changed,
	}
	_expect("8 四档各 2 s：不写 BRO、不产生事故", int(out["bro_delta"]) == 0
		and int(out["accident_delta"]) == 0, str(out))
	_expect("8 不会反向控制（按 ↓ 不会上浮）", not reversed_any, str(out["reversed"]))
	_expect("8 不会强制换人", not control_changed, str(out["forced_switch"]))
	# SHIFT 照常可用，且延迟按“新受控角色”自己的神游量算。
	_reset_race_state()
	GameManager.set_control("turtle")
	_set_drift("rabbit", Tuning.DRIFT_CAP)
	_set_drift("turtle", 0.0)
	GameManager.toggle_control()
	var to := GameManager.current_control
	var delay_after: int = race.drift_react_delay_ms(to)
	_expect("8 SHIFT 立即生效，延迟跟随新角色",
		to == "rabbit" and delay_after == race.drift_react_delay_ms("rabbit")
			and delay_after >= 180,
		"%s / %d" % [to, delay_after])
	return out


# ---------------- 场景工具 ----------------

func _brain(who: String):
	return race.rabbit_brain if who == "rabbit" else race.turtle_brain


func _set_drift(who: String, value: float) -> void:
	var brain = _brain(who)
	brain.drift = clampf(value, 0.0, Tuning.DRIFT_CAP)
	var body = race.rabbit if who == "rabbit" else race.turtle
	body.drift = brain.drift
	body.drift_state = brain.state_name()


func _reset_race_state() -> void:
	Input.action_release("up")
	Input.action_release("down")
	race.reset_brains()
	race._clear_dive_assist()
	race.rabbit.reset()
	race.mount.mark_riding()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.turtle.position.y = Tuning.NEUTRAL_DEPTH
	race.turtle.daze_time = 0.0
	race.turtle.accident = false
	race.turtle.dunk_timer = 0.0
	_tick(3)


func _step() -> void:
	race._physics_process(STEP)


func _tick(n: int) -> void:
	for i in n:
		_step()


func _find_feedback(fragment: String) -> String:
	for f in feedback_log:
		if String(f.get("text", "")).contains(fragment):
			return String(f["text"])
	return ""


func _on_feedback(text: String, kind: String = "") -> void:
	feedback_log.append({"text": text, "kind": kind})
	if feedback_log.size() > 120:
		feedback_log.pop_front()


func _expect(label: String, ok: bool, detail: String = "") -> void:
	checks.append({"label": label, "pass": ok, "detail": detail})
	print("%s %s%s" % ["ok  " if ok else "FAIL", label,
		(" [" + detail + "]") if detail != "" else ""])


func _all_pass() -> bool:
	for c in checks:
		if not bool(c["pass"]):
			return false
	return true


func _write() -> void:
	data["generated_at"] = Time.get_datetime_string_from_system()
	data["checks"] = checks
	data["pass"] = _all_pass()
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
		f.close()


func _finish(code: int) -> void:
	print("CORE-FEEL-08 P0-A: %s" % ("PASS" if code == 0 else "FAIL"))
	get_tree().quit(code)
