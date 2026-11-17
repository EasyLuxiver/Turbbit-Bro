extends Node
## CORE-FEEL-08 P2-8 — 30/60/120 Hz 回归（headless，真实 race.gd）
##
## 同一段玩法在三种物理步长下各跑一遍，判的是“行为按秒一致，不是按帧一致”：
##   1) 神游延迟：恶作剧档下 BITT 起跳 / TUBO 下潜的实测延迟（秒）；
##   2) 巡航速度：3 s 无输入前进距离（px）；
##   3) 动态障碍：岩石一个周期内的位移振幅（px，由 hazard_clock 驱动）；
##   4) 轻事故恢复：真撞岩后的 RABBIT_STUN 恢复时长（秒）；
##   5) 神游恢复：从满值回到 0 的时间（秒）；
##   6) 第二区域视差：同一组镜头位置下六层屏幕位移（与帧率无关）。
##
## 用法：
##   D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
##       res://scenes/stage8_hz_regression.tscn
##
## 输出：docs/reports/longrun/core-feel-08-p2-hz.json

const LevelDataScript = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/core-feel-08-p2-hz.json"
const HZ_SET := [30, 60, 120]
## 神游恶作剧档：兔子/乌龟的延迟上限（Tuning.DRIFT_REACT_*_MAX）。
const JUMP_TOLERANCE := 0.05
const DIVE_TOLERANCE := 0.05

var is_runner := false
var race: Node = null
var checks: Array = []
var data := {}
var feedback_log: Array = []
## 每个 Hz 用例的步长；所有测量都用它把帧数换算成秒。
var step := 1.0 / 60.0


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
		push_error("P2-8: no race scene")
		_finish(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	GameManager.feedback.connect(_on_feedback)

	var rows := []
	for hz in HZ_SET:
		step = 1.0 / float(hz)
		Engine.physics_ticks_per_second = int(hz)
		var row := {
			"hz": int(hz),
			"step_s": snappedf(step, 0.0001),
			"jump_delay_s": _jump_delay_case(),
			"dive_delay_s": _dive_delay_case(),
			"travel_3s_px": _travel_case(),
			"rock_span_px": _rock_case(),
			"stun_recover_s": _stun_case(),
			"drift_recover_s": _drift_recover_case(),
			"dock_deltas": _dock_case(),
		}
		rows.append(row)
		print("-- %d Hz: %s" % [hz, str(row)])
	data["rows"] = rows
	_judge(rows)
	_write()
	_finish(0 if _all_pass() else 1)


# ---------------- 用例 ----------------

## 神游恶作剧档下按 ↑ 到真正执行起跳，折算成秒。
func _jump_delay_case() -> float:
	_reset_case()
	GameManager.set_control("rabbit")
	_set_drift("rabbit", Tuning.DRIFT_CAP)
	race.mount.mark_riding()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.rabbit.state = "RIDING"
	Input.action_release("up")
	_tick(2)
	var log_before: int = race.input_buffer_log.size()
	# 清掉真实按键去重时间戳，否则同一毫秒内连续注入会被当成重复事件。
	race._buf_event_msec = -9999
	Input.action_press("up")
	var frames := 0
	while frames < 120:
		_tick(1)
		frames += 1
		if race.input_buffer_log.size() > log_before:
			break
	Input.action_release("up")
	if race.input_buffer_log.size() <= log_before:
		return -1.0
	return frames * step


## 神游恶作剧档下按 ↓ 到真正开始下潜，折算成秒。
func _dive_delay_case() -> float:
	_reset_case()
	GameManager.set_control("turtle")
	_set_drift("turtle", Tuning.DRIFT_CAP)
	race.turtle.position.y = Tuning.NEUTRAL_DEPTH
	Input.action_release("down")
	_tick(4)
	Input.action_press("down")
	var frames := 0
	while frames < 120:
		_tick(1)
		frames += 1
		if race.turtle.diving:
			break
	Input.action_release("down")
	if not race.turtle.diving:
		return -1.0
	return frames * step


## 3 s 无输入前进距离：应该看到同样的 px，不随 Hz 变化。
func _travel_case() -> float:
	_reset_case()
	race.hazard_groups = []
	race.entered_groups.clear()
	race.boost_lanes = []
	race._snack_cache_sig = -1
	race._snack_cache = []
	race.hit_groups.clear()
	var x0: float = race.turtle.position.x
	var seconds := 3.0
	var frames := int(round(seconds / step))
	_tick(frames)
	return snappedf(race.turtle.position.x - x0, 0.1)


## 同一块移动岩石在一个周期内的位移振幅（hazard_clock 驱动）。
func _rock_case() -> float:
	_reset_case()
	# 保留 hazard_groups 采样，但关掉碰撞：只量运动，不量撞。
	race.test_disable_hazards = true
	var g := _group("rock3")
	if g.is_empty():
		return -1.0
	var amp := float(Dictionary(g.get("motion", {})).get("amp", 0.0))
	var period := float(Dictionary(g.get("motion", {})).get("period", 1.0))
	var lo := 1e9
	var hi := -1e9
	var frames := int(round(maxf(period * 1.25, 1.0) / step))
	for i in frames:
		_tick(1)
		var off: float = race.hazard_offset(g).y
		lo = minf(lo, off)
		hi = maxf(hi, off)
	if not data.has("rock_ref"):
		data["rock_ref"] = {}
	data["rock_ref"]["amp"] = amp
	data["rock_ref"]["period"] = period
	return snappedf(hi - lo, 0.1) if hi > lo else -1.0


## 真撞岩 → RABBIT_STUN，量恢复时长（秒）。
func _stun_case() -> float:
	_reset_case()
	race.test_disable_hazards = false
	var rock := _group("rock1")
	if rock.is_empty():
		return -1.0
	var start := LevelDataScript.group_start(rock)
	race.turtle.position = Vector2(start - 90.0, Tuning.NEUTRAL_DEPTH)
	race.rabbit.attach(race.turtle.get_mount_point())
	GameManager.set_control("rabbit")
	var wait_frames := 0
	while wait_frames < int(round(4.0 / step)) and GameManager.accident_state == "NONE":
		_tick(1)
		wait_frames += 1
	if GameManager.accident_state != "RABBIT_STUN":
		return -1.0
	var rec_frames := 0
	while rec_frames < int(round(3.0 / step)) and GameManager.accident_state != "NONE":
		_tick(1)
		rec_frames += 1
	var out := rec_frames * step
	if not data.has("stun_ref"):
		data["stun_ref"] = {}
	data["stun_ref"]["stun_time"] = Tuning.STUN_TIME
	return snappedf(out, 0.01)


## 从恶作剧满值恢复到延迟归零的时间（秒）。
func _drift_recover_case() -> float:
	_reset_case()
	GameManager.set_control("rabbit")
	_set_drift("rabbit", Tuning.DRIFT_CAP)
	var max_frames := int(round(10.0 / step))
	var frames := 0
	while frames < max_frames:
		_tick(1)
		frames += 1
		if race.drift_react_delay_ms("rabbit") == 0:
			return snappedf(frames * step, 0.01)
	return -1.0


## 第二区域视差只跟镜头位置有关：同一组镜头位置下各层屏幕位移应与 Hz 无关。
func _dock_case() -> Dictionary:
	var dock := race.get_node_or_null("Zone2Dock")
	if dock == null:
		return {}
	var out := {}
	for name in ["BG_Far", "BG_Mid", "BG_Props", "Gameplay_Canal", "FG_Near", "FG_Overhead"]:
		var layer: Node2D = dock.get_node_or_null(name)
		if layer == null:
			continue
		# 与 stage8_dock_layers 同一算法：同一世界点 22000 在镜头走 1200 px
		# 前后的屏幕位移，应等于 −1200×parallax。
		dock.update_cam(22000.0)
		var before: float = layer.vx(22000.0)
		dock.update_cam(23200.0)
		var after: float = layer.vx(22000.0)
		out[name] = snappedf((after - 23200.0) - (before - 22000.0), 0.01)
	return out


# ---------------- 判定 ----------------

func _judge(rows: Array) -> void:
	var jump := []
	var dive := []
	var travel := []
	var rock := []
	var stun := []
	var recover := []
	for r in rows:
		jump.append(float(r["jump_delay_s"]))
		dive.append(float(r["dive_delay_s"]))
		travel.append(float(r["travel_3s_px"]))
		rock.append(float(r["rock_span_px"]))
		stun.append(float(r["stun_recover_s"]))
		recover.append(float(r["drift_recover_s"]))
	_expect("1 神游延迟按秒一致（30/60/120 Hz 极差 <= %.2f s）" % JUMP_TOLERANCE,
		_spread(jump) <= JUMP_TOLERANCE and _all_in(jump, 0.18, 0.28),
		"%s s，极差 %.3f" % [str(jump.map(func(v): return snappedf(v, 0.001))), _spread(jump)])
	_expect("1 神游延迟按秒一致（TUBO 30/60/120 Hz 极差 <= %.2f s）" % DIVE_TOLERANCE,
		_spread(dive) <= DIVE_TOLERANCE and _all_in(dive, 0.22, 0.32),
		"%s s，极差 %.3f" % [str(dive.map(func(v): return snappedf(v, 0.001))), _spread(dive)])
	_expect("2 3 s 巡航距离一致（极差 <= 1%）",
		_spread(travel) <= 0.01 * 660.0 and _all_in(travel, 640.0, 680.0),
		"%s px，极差 %.1f" % [str(travel), _spread(travel)])
	var rock_ref: Dictionary = data.get("rock_ref", {})
	var want_span := 2.0 * float(rock_ref.get("amp", 52.0))
	_expect("3 动态障碍振幅按周期一致（极差 <= 2 px，达到 2×amp）",
		_spread(rock) <= 2.0 and _all_in(rock, want_span - 2.0, want_span + 2.0),
		"%s px（2×amp=%.1f）" % [str(rock), want_span])
	var stun_ref: Dictionary = data.get("stun_ref", {})
	var want_stun := float(stun_ref.get("stun_time", 0.8))
	_expect("4 轻事故恢复按秒一致（极差 <= 0.1 s，且在 STUN_TIME+0.3 内）",
		_spread(stun) <= 0.1 and _all_in(stun, want_stun - 0.1, want_stun + 0.3),
		"STUN_TIME=%.2f，%s s" % [want_stun, str(stun)])
	_expect("5 神游恢复按秒一致（极差 <= 0.3 s，4.0–6.5 s）",
		_spread(recover) <= 0.3 and _all_in(recover, 4.0, 6.5),
		"%s s" % str(recover))
	# 视差：三个 Hz 的六层位移必须完全相同。
	var dock_ok := true
	var base: Dictionary = rows[0].get("dock_deltas", {})
	for i in range(1, rows.size()):
		var cur: Dictionary = rows[i].get("dock_deltas", {})
		if cur.size() != base.size() or base.is_empty():
			dock_ok = false
			continue
		for k in base:
			if absf(float(cur[k]) - float(base[k])) > 0.01:
				dock_ok = false
	_expect("6 第二区域视差与帧率无关（六层位移三次测量完全相同）",
		dock_ok, str(base))


func _spread(values: Array) -> float:
	var lo := 1e9
	var hi := -1e9
	for v in values:
		lo = minf(lo, float(v))
		hi = maxf(hi, float(v))
	return hi - lo


func _all_in(values: Array, lo: float, hi: float) -> bool:
	for v in values:
		if float(v) < lo or float(v) > hi:
			return false
	return true


# ---------------- 场景工具 ----------------

func _reset_case() -> void:
	Input.action_release("up")
	Input.action_release("down")
	Input.action_release("shift")
	race.test_disable_hazards = true
	race.test_no_finish = true
	race.load_level(LevelDataScript.groups(), LevelDataScript.boost_lanes())
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.accident_events.clear()
	race.accident_event_log.clear()
	race.accident_event_seq = 0
	race.accident_event_time = 0.0
	race.hazard_cooldown = 0.0
	race.rabbit_stun = 0.0
	race.emergency_timer = 0.0
	race.turtle_repair = 0.0
	race.joint_show_t = 0.0
	race.showtime_active = false
	GameManager.showtime_active = false
	GameManager.accident_state = "NONE"
	GameManager.bro_meter = 0
	GameManager.bro_joint_pending = false
	GameManager.bro_meter_changed.emit(0)
	GameManager.oxygen = Tuning.OXYGEN_MAX
	GameManager.set_control("rabbit")
	race.turtle.reset(Vector2(LevelDataScript.RACE_START_X, Tuning.NEUTRAL_DEPTH))
	race.turtle.speed_cap = 1.0e9
	race.turtle.speed = 220.0
	race.turtle.base_speed = 220.0
	race.rabbit.reset()
	race.mount.reset()
	race.mount.mark_riding()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.reset_brains()
	race._clear_dive_assist()
	_tick(3)


func _group(id: String) -> Dictionary:
	for g in race.hazard_groups:
		if String(g["group"]) == id:
			return g
	return {}


func _set_drift(who: String, value: float) -> void:
	var brain = race.rabbit_brain if who == "rabbit" else race.turtle_brain
	brain.drift = clampf(value, 0.0, Tuning.DRIFT_CAP)
	var body = race.rabbit if who == "rabbit" else race.turtle
	body.drift = brain.drift
	body.drift_state = brain.state_name()


func _tick(n: int) -> void:
	for i in n:
		race._physics_process(step)


func _on_feedback(text: String, kind: String = "") -> void:
	feedback_log.append({"text": text, "kind": kind})
	if feedback_log.size() > 160:
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
	data["task"] = "TBB-CORE-FEEL-08 P2-8"
	data["generated_at"] = Time.get_datetime_string_from_system()
	data["hz_set"] = HZ_SET
	data["checks"] = checks
	data["pass"] = _all_pass()
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
		f.close()


func _finish(code: int) -> void:
	print("CORE-FEEL-08 P2-8: %s" % ("PASS" if code == 0 else "FAIL"))
	get_tree().quit(code)
