extends Node
## CORE-FEEL-07 追问（只读诊断）：一次失败的 BRO DIVE 到底记了几笔？
##
## 制作人反馈：兔子起跳撞浮木 → 乌龟下潜去接兔子 → 还是出现「联合惩罚」。
## 这里在真实关卡 log1 上复现这条动作链，逐帧记录：
##   - 事故事件（t / roles / settled / penalty_role）
##   - 每次 note_mistake（原因 + 时间）
##   - BRO METER / 联合惩罚演出
## 分三种接人时机（落水后 0.1 / 0.8 / 1.6 s 才开始下潜），看第二笔从哪来。
##
## 输出：docs/reports/longrun/core-feel-07-brodive-fail.json
## 运行：godot --headless --path TURBBIT res://scenes/stage7_brodive_fail.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/core-feel-07-brodive-fail.json"
const STEP := 1.0 / 60.0
const GROUP := "log1"

var is_runner := false
var race: Node = null
var out := {}
var sig_feedback: Array = []
var sig_hint: Array = []
var sig_accident: Array = []
var mistakes: Array = []
var events_seen := 0
var timeline: Array = []
var t_now := 0.0


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage7BrodiveFailRunner"
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
		push_error("BRODIVE-FAIL: no race scene")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()
	GameManager.feedback.connect(_on_feedback)
	GameManager.hint.connect(_on_hint)
	GameManager.accident.connect(_on_accident)

	out["generated_at"] = Time.get_datetime_string_from_system()
	out["group"] = GROUP
	out["joint_window_s"] = Tuning.ACCIDENT_JOINT_WINDOW
	out["hazard_cooldown_s"] = Tuning.HAZARD_COOLDOWN
	out["rescue_slow_speed"] = Tuning.RESCUE_SLOW_SPEED
	out["cases"] = {}
	out["cases"]["a_jump_late_dive_fast"] = _case(120.0, 0.1)
	out["cases"]["b_jump_early_dive_fast"] = _case(250.0, 0.1)
	out["cases"]["c_jump_late_dive_late"] = _case(120.0, 1.6)
	out["cases"]["d_jump_early_dive_late"] = _case(250.0, 1.6)
	out["sweep"] = _sweep()
	_write()
	print("BRODIVE-FAIL: DONE")
	get_tree().quit(0)


func _on_feedback(text: String, _style: String) -> void:
	sig_feedback.append(text)


func _on_hint(text: String) -> void:
	sig_hint.append(text)


func _on_accident(reason: String) -> void:
	sig_accident.append(reason)


## lead = 起跳点距浮木左缘的像素；dive_delay = 落水后多久开始按 ↓。
func _case(lead: float, dive_delay: float) -> Dictionary:
	var g := _group()
	var left := float(g["rects"][0].position.x)
	var zone: Dictionary = LevelData.zone_at(left)
	var v := float(zone["base_speed"])
	_reset_at(left - lead, zone, v)

	# 1) 兔子起跳，等它撞上浮木 / 或落地。
	_control("rabbit")
	_press("up")
	var t := 0.0
	var hit_at := -1.0
	while t < 2.0 and GameManager.accident_state != "RABBIT_WATER":
		race._physics_process(STEP)
		t += STEP
		_mark(t)
	if GameManager.accident_state == "RABBIT_WATER":
		hit_at = t
	_release("up")
	var at_fall := _snap()
	at_fall["hit_at"] = snappedf(hit_at, 0.01)

	# 2) SHIFT 给乌龟，等 dive_delay 后按下 ↓ 接人。
	_control("turtle")
	var t2 := 0.0
	var dived := false
	var water_at := hit_at
	while t2 < 9.0:
		if not dived and t2 >= dive_delay:
			_press("down")
			dived = true
		race._physics_process(STEP)
		t2 += STEP
		_mark(t2)
		if water_at < 0.0 and GameManager.accident_state == "RABBIT_WATER":
			water_at = t + t2
		if String(race.mount.state) == "RIDING" \
				and GameManager.accident_state == "NONE" \
				and String(race.rescue_last_result) == "caught":
			break
	_release("down")
	var row := _snap()
	row["lead"] = lead
	row["dive_delay"] = dive_delay
	row["hit_at"] = snappedf(hit_at, 0.01)
	row["water_at"] = snappedf(water_at, 0.01)
	if not row["events"].is_empty():
		var e0: Dictionary = row["events"][0]
		row["settled_gap"] = snappedf(water_at - float(e0["settled_t"]), 0.01) \
			if water_at >= 0.0 else -1.0
	row["rescue_result"] = String(race.rescue_last_result)
	row["rescue_reason"] = String(race.rescue_last_reason)
	row["mount_state"] = String(race.mount.state)
	row["at_fall"] = at_fall
	row["timeline"] = _timeline()
	return row


# ---------------------------------------------------------------- 扫参数

## 起跳点 × 落水后开始下潜的延迟：只留一句摘要，用来看“一笔/两笔”的分布。
func _sweep() -> Array:
	var rows := []
	for lead in [20.0, 40.0, 60.0, 80.0, 100.0, 120.0, 140.0, 160.0, 200.0, 240.0]:
		for delay in [0.1, 0.6, 1.2]:
			var c := _case(lead, delay)
			rows.append({
				"lead": lead, "dive_delay": delay,
				"mistakes": c["mistakes"].size(),
				"reasons": c["mistakes"],
				"meter": c["bro_meter"], "joint": c["joint_count"],
				"rescue": c["rescue_result"],
				"water_at": c.get("water_at", -1.0),
				"settled_gap": c.get("settled_gap", -1.0),
				"event_roles": _roles_summary(c["events"]),
				"event_penalty": _penalty_summary(c["events"]),
			})
	return rows


func _roles_summary(events: Array) -> Array:
	var out_rows := []
	for e in events:
		out_rows.append({"group": String(e["group"]), "roles": e["roles"],
			"settled": bool(e["settled"]), "t": float(e["t"])})
	return out_rows


func _penalty_summary(events: Array) -> Array:
	var out_rows := []
	for e in events:
		out_rows.append(String(e["penalty_role"]))
	return out_rows


# ---------------------------------------------------------------- 驱动

func _group() -> Dictionary:
	for g in race.hazard_groups:
		if String(g["group"]) == GROUP:
			return g
	return {}


func _reset_at(x: float, zone: Dictionary, v: float) -> void:
	Input.action_release("up")
	Input.action_release("down")
	Input.action_release("shift")
	sig_feedback.clear()
	sig_hint.clear()
	sig_accident.clear()
	mistakes.clear()
	timeline.clear()
	events_seen = 0
	t_now = 0.0
	_joint_seen = false
	_joint_shown = false
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.oxygen = Tuning.OXYGEN_MAX
	GameManager.oxygen_phase = "SAFE"
	GameManager.accident_count = 0
	GameManager.joint_accident_count = 0
	GameManager.pickup_count = 0
	GameManager.total_score = 0
	GameManager.score_log.clear()
	GameManager.showtime_active = false
	GameManager.clear_bro_meter()
	GameManager.current_control = "rabbit"
	GameManager.has_shifted = false
	GameManager.combo = 0
	race.current_zone = zone
	race.showtime_active = false
	race.showtime_t = 0.0
	race.joint_show_t = 0.0
	race.finishing = false
	race.hazard_cooldown = 0.0
	race.accident_flash = 0.0
	race._accident_t = 0.0
	race.turtle_repair = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.rabbit_stun = 0.0
	race.emergency_timer = 0.0
	race.combo = 0
	race.combo_max = 0
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.group_actions.clear()
	race.input_buffer_log.clear()
	race.accident_events.clear()
	race.accident_event_log.clear()
	race.accident_event_seq = 0
	race.accident_event_time = 0.0
	race.rescue_last_result = ""
	race.rescue_last_reason = ""
	race._clear_dive_assist()
	race.reset_brains()
	race.world_end = 1.0e9
	race.turtle.reset(Vector2(x, Tuning.NEUTRAL_DEPTH))
	race.turtle.base_speed = v
	race.turtle.speed = v
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	race.rabbit.state = "RIDING"
	race._buf_action = ""
	race._buf_age = 0.0


## 每帧记录：新事件、新失误、乌龟 x/y、状态。只在关键变化时写一行，避免 9 秒 × 4 例的噪音。
func _mark(_t: float) -> void:
	var log: Array = race.accident_event_log
	while events_seen < log.size():
		var ev: Dictionary = log[events_seen]
		events_seen += 1
		var roles: Array = ev["roles"].keys()
		roles.sort()
		timeline.append({
			"kind": "event",
			"id": int(ev["id"]),
			"group": String(ev["group"]),
			"roles": roles,
			"settled": bool(ev["settled"]),
			"penalty_role": String(ev["penalty_role"]),
			"t": snappedf(float(ev["t"]), 0.01),
		})
	var n := 0
	for e in GameManager.score_log:
		if String(e.get("reason", "")).begins_with("mistake:"):
			n += 1
	if n > mistakes.size():
		for i in range(mistakes.size(), n):
			mistakes.append(String(GameManager.score_log[_mistake_index(i)].get("reason", "")))
		timeline.append({
			"kind": "mistake", "reason": mistakes[mistakes.size() - 1],
			"turtle_x": snappedf(float(race.turtle.position.x), 0.1),
			"turtle_y": snappedf(float(race.turtle.position.y), 0.1),
			"bro_meter": GameManager.bro_meter,
			"ahead_of_log": float(race.turtle.position.x) < _group()["rects"][0].position.x,
		})
	if GameManager.bro_joint_pending and not bool(_joint_seen):
		_joint_seen = true
		timeline.append({
			"kind": "joint_armed", "turtle_x": snappedf(float(race.turtle.position.x), 0.1),
			"bro_meter": GameManager.bro_meter,
		})
	if race.joint_show_t > 0.0 and not bool(_joint_shown):
		_joint_shown = true
		timeline.append({"kind": "joint_show_started"})


var _joint_seen := false
var _joint_shown := false


func _mistake_index(i: int) -> int:
	var k := -1
	for j in GameManager.score_log.size():
		if String(GameManager.score_log[j].get("reason", "")).begins_with("mistake:"):
			k += 1
			if k == i:
				return j
	return -1


func _timeline() -> Array:
	var out_rows := timeline.duplicate(true)
	timeline.clear()
	return out_rows


func _snap() -> Dictionary:
	var bad: Array = []
	for e in GameManager.score_log:
		if String(e.get("reason", "")).begins_with("mistake:"):
			bad.append(String(e.get("reason", "")))
	var events := []
	for ev in race.accident_event_log:
		var roles: Array = ev["roles"].keys()
		roles.sort()
		events.append({
			"id": int(ev["id"]), "group": String(ev["group"]), "kind": String(ev["kind"]),
			"roles": roles, "settled": bool(ev["settled"]),
			"penalty_role": String(ev["penalty_role"]),
			"rescue": String(ev["rescue"]), "t": snappedf(float(ev["t"]), 0.01),
			"settled_t": snappedf(float(ev["settled_t"]), 0.01),
		})
	return {
		"accident_count": GameManager.accident_count,
		"joint_count": GameManager.joint_accident_count,
		"bro_meter": GameManager.bro_meter,
		"joint_pending": GameManager.bro_joint_pending,
		"mistakes": bad,
		"accident_state": GameManager.accident_state,
		"events": events,
		"feedback": sig_feedback.duplicate(),
		"hints": sig_hint.duplicate(),
		"accident_signals": sig_accident.duplicate(),
	}


func _control(who: String) -> void:
	if GameManager.current_control != who:
		GameManager.set_control(who)


func _press(action: String) -> void:
	if not Input.is_action_pressed(action):
		Input.action_press(action)


func _release(action: String) -> void:
	if Input.is_action_pressed(action):
		Input.action_release(action)


func _write() -> void:
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out, "  "))
		f.close()
