extends Node
## TBB-CORE-FEEL-07 P0-B：一次事故只罚一次的事件化判罚实测。
##
## 用户试玩反馈：「联合判罚的判定也还是有问题」——旧实现里
##   _check_hazards 让兔子和乌龟各记各的，_turtle_contact 又无条件直连
##   GameManager.note_mistake，于是一次没跳过去的浮木会扣两次分（第三次甚至
##   直接凑满 BRO METER）；玩家只看见一次失败，账上却是两笔。
##
## 本轮规则（P0-B）：
##   同一障碍 + 同一时间窗（Tuning.ACCIDENT_JOINT_WINDOW）+ 同一次失败动作
##   = 一个“事故事件”。
##   - 单侧命中：只罚命中的那个角色；
##   - 两侧都命中：记联合事故，但仍然只罚一次；
##   - 不同障碍是不同事件，各自独立记账（救援中的真实碰撞不被吞）；
##   - 救援成功不产生联合事故，也不追加惩罚。
##   事件记录含 id / group / kind / roles / settled / penalty_role / rescue，
##   不用一个全局 hit 标志代替两个角色的碰撞事实。
##
## 失败矩阵 8 例，逐例核对：事件记录、事故数、分数条目、BRO METER（HUD 文本）、
## 角色表现反馈、以及碰撞体是否被偷偷缩小。
##
## 输出：docs/reports/longrun/core-feel-07-joint-penalty.json
## 运行：godot --headless --path TURBBIT res://scenes/stage7_joint_penalty.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/core-feel-07-joint-penalty.json"
const STEP := 1.0 / 60.0
const TURTLE_HALF_W := 45.0

## 每例一个专属障碍，互不干扰（全部落在 Z1，220 px/s）。
const LEVEL := [
	{"group": "pb_rock", "zone": 1, "kind": "SURFACE_ROCK", "x": 1500.0},
	{"group": "pb_gate", "zone": 1, "kind": "DIVE_GATE", "x": 3000.0},
	{"group": "pb_log", "zone": 1, "kind": "FLOATING_LOG", "x": 6000.0},
	{"group": "pb_beam", "zone": 1, "kind": "LOW_BEAM", "x": 7500.0},
	{"group": "pb_log2", "zone": 1, "kind": "FLOATING_LOG", "x": 10500.0},
	{"group": "pb_beam2", "zone": 1, "kind": "LOW_BEAM", "x": 13000.0},
	{"group": "pb_shark2", "zone": 1, "kind": "SHARK", "x": 13090.0},
	{"group": "pb_gate2", "zone": 1, "kind": "DIVE_GATE", "x": 14300.0},
]

var is_runner := false
var race: Node = null
var out := {}
var failures: Array = []
var sig_feedback: Array = []
var sig_hint: Array = []
var sig_accident: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage7JointPenaltyRunner"
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
		push_error("CORE-FEEL-07 P0-B: no race scene")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	var groups := []
	for spec in LEVEL:
		groups.append(LevelData.build_group(spec))
	race.load_level(groups, [])
	race.boost_lanes.clear()
	GameManager.feedback.connect(_on_feedback)
	GameManager.hint.connect(_on_hint)
	GameManager.accident.connect(_on_accident)

	out["generated_at"] = Time.get_datetime_string_from_system()
	out["rule"] = {
		"joint_window_s": Tuning.ACCIDENT_JOINT_WINDOW,
		"note": "same obstacle + same window = one event; both roles = joint, still one penalty",
	}
	out["geometry"] = _geometry()
	out["cases"] = {}
	out["cases"]["c1_rabbit_only"] = _case_rabbit_only()
	out["cases"]["c2_turtle_only"] = _case_turtle_only()
	out["cases"]["c3_both_same_frame"] = _case_both_same_frame()
	out["cases"]["c4_sequential_same_log"] = _case_sequential()
	out["cases"]["c5_rabbit_water_rescue"] = _case_rescue_success()
	out["cases"]["c6_rescue_independent_hit"] = _case_rescue_independent()
	out["cases"]["c7_turtle_pushed_no_second"] = _case_turtle_pushed()
	out["cases"]["c8_turtle_passes_clean"] = _case_turtle_passes()
	_evaluate()
	_write()
	print("CORE-FEEL-07 P0-B: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _on_feedback(text: String, _style: String) -> void:
	sig_feedback.append(text)


func _on_hint(text: String) -> void:
	sig_hint.append(text)


func _on_accident(reason: String) -> void:
	sig_accident.append(reason)


# ---------------------------------------------------------------- 用例

## 1. 兔子单独撞岩檐：只罚兔子；乌龟既不扣分也不被挡。
func _case_rabbit_only() -> Dictionary:
	var g := _group("pb_rock")
	_reset_at(_left(g) - 160.0)
	var t := 0.0
	while t < 4.0:
		race._physics_process(STEP)
		t += STEP
		if race.hit_groups.has("pb_rock"):
			break
	# 撞后 0.5 s 再看：A 类的岩檐不该把壳挡住，乌龟应该已经从岩檐下面开过去。
	_frames(30)
	var row := _snap()
	row["case"] = "rabbit_only"
	row["kind"] = "SURFACE_ROCK"
	row["rabbit_state"] = String(race.rabbit.state)
	row["turtle_speed"] = snappedf(float(race.turtle.speed), 0.1)
	# A 类只占兔子那一层：乌龟不该被这道障碍挡住，应该已经开过去。
	row["turtle_past_rock"] = float(race.turtle.position.x) > _left(g) + 1.0
	return row


## 2. 乌龟单独撞水下通道：只罚乌龟；兔子不背锅。
func _case_turtle_only() -> Dictionary:
	var g := _group("pb_gate")
	_reset_at(_left(g) - 160.0)
	var t := 0.0
	while t < 4.0:
		race._physics_process(STEP)
		t += STEP
		if race.hit_groups.has("pb_gate"):
			break
	var row := _snap()
	row["case"] = "turtle_only"
	row["kind"] = "DIVE_GATE"
	row["turtle_dunk"] = snappedf(float(race.turtle.dunk_timer), 0.01)
	row["turtle_flip"] = snappedf(float(race.turtle.flip_t), 0.01)
	row["turtle_speed"] = snappedf(float(race.turtle.speed), 0.1)
	return row


## 3. 同一帧两个角色都压在同一个障碍里：联合事故，只罚一次。
## 用真实几何摆放（两个判定框都真的和障碍相交），不是伪造 hit 标志。
func _case_both_same_frame() -> Dictionary:
	_reset_at(5400.0)
	var g := _group("pb_log")
	var r: Rect2 = g["rects"][0]
	var cx := r.position.x + r.size.x * 0.5
	race.turtle.position = Vector2(cx, r.end.y - 30.0)
	race.rabbit.state = "RIDING"
	race.rabbit.position = Vector2(cx, r.position.y + 28.0)
	race.mount.mark_riding()
	race._check_hazards()
	var row := _snap()
	row["case"] = "both_same_frame"
	row["kind"] = "FLOATING_LOG"
	row["turtle_dunk"] = snappedf(float(race.turtle.dunk_timer), 0.01)
	row["turtle_speed"] = snappedf(float(race.turtle.speed), 0.1)
	row["rabbit_state"] = String(race.rabbit.state)
	return row


## 4. 同一根浮木先后两次：乌龟先撞，1.3 s 后壳上的兔子擦到同一根木头。
## 这是用户看到的“一次失败扣两次分”的原样复现。
func _case_sequential() -> Dictionary:
	var g := _group("pb_log")
	_reset_at(_left(g) - 200.0)
	var t := 0.0
	var gap := -1.0
	var first_t := -1.0
	while t < 6.0:
		race._physics_process(STEP)
		t += STEP
		if first_t < 0.0 and race.hit_groups.has("pb_log"):
			first_t = t
		if first_t >= 0.0 and race.hit_roles.get("pb_log", {}).size() >= 2:
			gap = t - first_t
			break
	var row := _snap()
	row["case"] = "sequential_same_log"
	row["kind"] = "FLOATING_LOG"
	row["gap_s"] = snappedf(gap, 0.01)
	row["rabbit_state"] = String(race.rabbit.state)
	row["rabbit_feedback"] = _last_feedback()
	row["turtle_dunk"] = snappedf(float(race.turtle.dunk_timer), 0.01)
	return row


## 5. 兔落水 → 乌龟下潜救起：全程只罚一次，救援成功不产生联合事故。
func _case_rescue_success() -> Dictionary:
	var g := _group("pb_beam")
	_reset_at(_left(g) - 40.0)
	# 真的起跳：兔子在空中撞进低梁 → RABBIT_WATER（与鸟/浪同一条事故路径）。
	race.rabbit.launch(race.turtle.get_mount_point(), race.turtle.speed)
	race.mount.mark_airborne()
	var t := 0.0
	while t < 1.5 and GameManager.accident_state != "RABBIT_WATER":
		race._physics_process(STEP)
		t += STEP
	var hit := _snap()
	GameManager.set_control("turtle")
	var dived := false
	var t2 := 0.0
	while t2 < 9.0:
		if t2 >= 0.4 and not dived:
			Input.action_press("down")
			dived = true
		race._physics_process(STEP)
		t2 += STEP
		if String(race.rescue_last_result) == "caught" \
				and GameManager.accident_state == "NONE" \
				and String(race.mount.state) == "RIDING":
			break
	Input.action_release("down")
	var row := _snap()
	row["case"] = "rabbit_water_rescue"
	row["kind"] = "LOW_BEAM"
	row["hit_snapshot"] = _trim(hit)
	row["rescue_result"] = String(race.rescue_last_result)
	row["rescue_reason"] = String(race.rescue_last_reason)
	row["mount_state"] = String(race.mount.state)
	row["rescue_seconds"] = snappedf(t2, 0.01)
	return row


## 6. 救援进行中乌龟撞上另一道障碍：新事件照常记账，不被救援吞掉、也不并成联合。
func _case_rescue_independent() -> Dictionary:
	var g := _group("pb_beam2")
	_reset_at(_left(g) - 40.0)
	race.rabbit.launch(race.turtle.get_mount_point(), race.turtle.speed)
	race.mount.mark_airborne()
	var t := 0.0
	while t < 1.5 and GameManager.accident_state != "RABBIT_WATER":
		race._physics_process(STEP)
		t += STEP
	var after_fall := _snap()
	GameManager.set_control("turtle")
	Input.action_press("down")
	var hit := {}
	var t2 := 0.0
	while t2 < 4.0:
		race._physics_process(STEP)
		t2 += STEP
		if Dictionary(race.hit_roles.get("pb_shark2", {})).has("turtle"):
			hit = _snap()
			break
	Input.action_release("down")
	var row := _snap()
	row["case"] = "rescue_independent_hit"
	row["kind"] = "SHARK"
	row["after_fall"] = _trim(after_fall)
	row["hit_snapshot"] = _trim(hit)
	row["accident_state_at_hit"] = String(hit.get("accident_state", ""))
	row["rescue_state_at_hit"] = String(hit.get("mount_state", ""))
	row["seconds_to_hit"] = snappedf(t2, 0.01)
	return row


## 7. 乌龟被实心障碍顶住：同一障碍不会因为多帧重叠而再记一笔。
func _case_turtle_pushed() -> Dictionary:
	var g := _group("pb_log2")
	var left := _left(g)
	_reset_at(left - 160.0)
	var t := 0.0
	while t < 3.0:
		race._physics_process(STEP)
		t += STEP
		if Dictionary(race.hit_roles.get("pb_log2", {})).has("turtle"):
			break
	var at_hit := _snap()
	_frames(60)
	var row := _snap()
	row["case"] = "turtle_pushed_no_second"
	row["kind"] = "FLOATING_LOG"
	row["at_hit"] = _trim(at_hit)
	row["turtle_x"] = snappedf(float(race.turtle.position.x), 0.1)
	row["log_left"] = snappedf(left, 0.1)
	row["pinned_left_of_log"] = float(race.turtle.position.x) <= left - TURTLE_HALF_W + 1.0
	return row


## 8. 乌龟正确下潜、从通道下方穿过：没有碰撞就不该有事件。
func _case_turtle_passes() -> Dictionary:
	var g := _group("pb_gate2")
	var right := _right(g)
	_reset_at(_left(g) - 700.0)
	GameManager.set_control("turtle")
	Input.action_press("down")
	var t := 0.0
	while t < 8.0 and float(race.turtle.position.x) < right + 120.0:
		race._physics_process(STEP)
		t += STEP
	Input.action_release("down")
	var row := _snap()
	row["case"] = "turtle_passes_clean"
	row["kind"] = "DIVE_GATE"
	row["end_x"] = snappedf(float(race.turtle.position.x), 0.1)
	row["gate_right"] = snappedf(right, 0.1)
	row["hit_groups"] = race.hit_groups.keys()
	return row


# ---------------------------------------------------------------- 快照

func _snap() -> Dictionary:
	var mistakes: Array = []
	var mistake_total := 0
	for e in GameManager.score_log:
		if String(e.get("reason", "")).begins_with("mistake:"):
			mistakes.append(String(e.get("reason", "")))
			mistake_total += int(e.get("points", 0))
	var hud := ""
	if race.hud != null and race.hud.has_method("_refresh"):
		race.hud._refresh()
		if race.hud.bro_meter_label != null:
			hud = race.hud.bro_meter_label.text
	var banner := ""
	var b := race.get_node_or_null("Banner")
	if b != null and b.label != null:
		banner = b.label.text
	return {
		"accident_count": GameManager.accident_count,
		"joint_count": GameManager.joint_accident_count,
		"bro_meter": GameManager.bro_meter,
		"score": GameManager.total_score,
		"mistakes": mistakes.size(),
		"mistake_reasons": mistakes,
		"mistake_points": mistake_total,
		"hud_meter": hud,
		"banner": banner,
		"accident_state": GameManager.accident_state,
		"mount_state": String(race.mount.state),
		"feedback": sig_feedback.duplicate(),
		"hints": sig_hint.duplicate(),
		"accident_signals": sig_accident.duplicate(),
		"events": _event_rows(),
		"hit_roles_log1": "",
	}


func _trim(s: Dictionary) -> Dictionary:
	return {
		"accident_count": int(s["accident_count"]),
		"joint_count": int(s["joint_count"]),
		"bro_meter": int(s["bro_meter"]),
		"mistakes": int(s["mistakes"]),
		"mistake_reasons": s["mistake_reasons"],
		"accident_state": String(s["accident_state"]),
		"mount_state": String(s["mount_state"]),
		"events": s["events"],
		"hud_meter": String(s["hud_meter"]),
	}


func _event_rows() -> Array:
	var rows := []
	for ev in race.accident_event_log:
		var roles: Array = ev["roles"].keys()
		roles.sort()
		rows.append({
			"id": int(ev["id"]),
			"group": String(ev["group"]),
			"kind": String(ev["kind"]),
			"roles": roles,
			"settled": bool(ev["settled"]),
			"penalty_role": String(ev["penalty_role"]),
			"rescue": String(ev["rescue"]),
			"t": snappedf(float(ev["t"]), 0.01),
		})
	return rows


func _geometry() -> Dictionary:
	var g := _group("pb_log")
	var rect: Rect2 = g["rects"][0]
	return {
		"log_rect": [snappedf(rect.position.x, 0.1), snappedf(rect.position.y, 0.1),
			snappedf(rect.size.x, 0.1), snappedf(rect.size.y, 0.1)],
		"turtle_body": [snappedf(race.turtle.get_body_rect().size.x, 0.1),
			snappedf(race.turtle.get_body_rect().size.y, 0.1)],
		"rabbit_body": [snappedf(race.rabbit.get_body_rect().size.x, 0.1),
			snappedf(race.rabbit.get_body_rect().size.y, 0.1)],
		"joint_window_s": Tuning.ACCIDENT_JOINT_WINDOW,
		"hazard_cooldown_s": Tuning.HAZARD_COOLDOWN,
	}


# ---------------------------------------------------------------- 驱动

func _group(key: String) -> Dictionary:
	for g in race.hazard_groups:
		if String(g["group"]) == key:
			return g
	return {}


func _left(g: Dictionary) -> float:
	return float(g["rects"][0].position.x)


func _right(g: Dictionary) -> float:
	return float(g["rects"][0].end.x)


func _frames(n: int) -> void:
	for i in n:
		race._physics_process(STEP)


func _last_feedback() -> String:
	return "" if sig_feedback.is_empty() else String(sig_feedback[sig_feedback.size() - 1])


func _reset_at(x: float) -> void:
	Input.action_release("up")
	Input.action_release("down")
	sig_feedback.clear()
	sig_hint.clear()
	sig_accident.clear()
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
	race.current_zone = LevelData.zone_by_id(1)
	race.world_end = 1.0e9
	race.turtle.reset(Vector2(x, Tuning.NEUTRAL_DEPTH))
	race.turtle.base_speed = 220.0
	race.turtle.speed = 220.0
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	race.rabbit.state = "RIDING"
	race._buf_action = ""
	race._buf_age = 0.0


# ---------------------------------------------------------------- 判定

func _evaluate() -> void:
	var geo: Dictionary = out["geometry"]
	_expect("log rect unchanged (32 x 218), got %.1f x %.1f" % [
		float(geo["log_rect"][2]), float(geo["log_rect"][3])],
		is_equal_approx(float(geo["log_rect"][2]), 32.0)
		and is_equal_approx(float(geo["log_rect"][3]), 218.0))
	_expect("turtle body not shrunk (%.0f x %.0f)" % [
		float(geo["turtle_body"][0]), float(geo["turtle_body"][1])],
		float(geo["turtle_body"][0]) >= 90.0 and float(geo["turtle_body"][1]) >= 50.0)
	_expect("rabbit body not shrunk (%.0f x %.0f)" % [
		float(geo["rabbit_body"][0]), float(geo["rabbit_body"][1])],
		float(geo["rabbit_body"][0]) > 0.0 and float(geo["rabbit_body"][1]) > 0.0)

	var c: Dictionary = out["cases"]

	# 1 兔子单罚
	var c1: Dictionary = c["c1_rabbit_only"]
	_expect("1 one event, rabbit only", _roles_of(c1) == ["rabbit"]
		and String(_ev(c1, 0).get("penalty_role", "")) == "rabbit")
	_expect("1 exactly one penalty (accidents=%d, mistakes=%d)" % [
		int(c1["accident_count"]), int(c1["mistakes"])],
		int(c1["accident_count"]) == 1 and int(c1["mistakes"]) == 1)
	_expect("1 one BRO METER slot (hud=%s)" % String(c1["hud_meter"]),
		int(c1["bro_meter"]) == 1 and String(c1["hud_meter"]).contains("1/"))
	var m1: Array = c1["mistake_reasons"]
	_expect("1 score entry is RABBIT_STUN (%s)" % str(m1),
		m1.size() == 1 and String(m1[0]).ends_with("RABBIT_STUN"))
	_expect("1 rabbit is stunned, turtle is not blocked by the A-class rock", String(c1["rabbit_state"]) == "STUNNED"
		and bool(c1["turtle_past_rock"]))

	# 2 乌龟单罚
	var c2: Dictionary = c["c2_turtle_only"]
	_expect("2 one event, turtle only", _roles_of(c2) == ["turtle"]
		and String(_ev(c2, 0).get("penalty_role", "")) == "turtle")
	_expect("2 exactly one penalty (accidents=%d, mistakes=%d)" % [
		int(c2["accident_count"]), int(c2["mistakes"])],
		int(c2["accident_count"]) == 1 and int(c2["mistakes"]) == 1)
	_expect("2 turtle feedback is not swallowed (dunk=%.2f, flip=%.2f)" % [
		float(c2["turtle_dunk"]), float(c2["turtle_flip"])],
		float(c2["turtle_dunk"]) > 0.0 and float(c2["turtle_flip"]) > 0.0)
	_expect("2 turtle slowed down (%.1f <= 132)" % float(c2["turtle_speed"]),
		float(c2["turtle_speed"]) <= 132.1)

	# 3 同帧双撞
	var c3: Dictionary = c["c3_both_same_frame"]
	_expect("3 one event, both roles, joint", _roles_of(c3) == ["rabbit", "turtle"]
		and String(_ev(c3, 0).get("penalty_role", "")) == "joint")
	_expect("3 joint accident is charged once (accidents=%d, mistakes=%d)" % [
		int(c3["accident_count"]), int(c3["mistakes"])],
		int(c3["accident_count"]) == 1 and int(c3["mistakes"]) == 1)
	_expect("3 joint still fills exactly one slot (bro=%d, hud=%s)" % [
		int(c3["bro_meter"]), String(c3["hud_meter"])],
		int(c3["bro_meter"]) == 1 and String(c3["hud_meter"]).contains("1/"))
	_expect("3 second role still gets physical feedback (dunk=%.2f)" % float(c3["turtle_dunk"]),
		float(c3["turtle_dunk"]) > 0.0)

	# 4 先后双撞（用户反馈的原始复现）
	var c4: Dictionary = c["c4_sequential_same_log"]
	_expect("4 both roles recorded on the same log (%s)" % str(_roles_of(c4)),
		_roles_of(c4) == ["rabbit", "turtle"])
	_expect("4 same obstacle within the joint window (gap=%.2f s <= %.1f s)" % [
		float(c4["gap_s"]), Tuning.ACCIDENT_JOINT_WINDOW],
		float(c4["gap_s"]) > 0.0 and float(c4["gap_s"]) <= Tuning.ACCIDENT_JOINT_WINDOW)
	_expect("4 still only one penalty (accidents=%d, mistakes=%d, %s)" % [
		int(c4["accident_count"]), int(c4["mistakes"]), str(c4["mistake_reasons"])],
		int(c4["accident_count"]) == 1 and int(c4["mistakes"]) == 1)
	_expect("4 penalty is recorded as joint (got %s)" % String(_ev(c4, 0).get("penalty_role", "")),
		String(_ev(c4, 0).get("penalty_role", "")) == "joint")
	_expect("4 rabbit still gets its physical consequence (%s, feedback=%s)" % [
		String(c4["rabbit_state"]), String(c4["rabbit_feedback"])],
		String(c4["rabbit_state"]) != "RIDING")

	# 5 兔落水救援成功
	var c5: Dictionary = c["c5_rabbit_water_rescue"]
	var h5: Dictionary = c5["hit_snapshot"]
	_expect("5 fall is rabbit-only (%s)" % str(h5["events"]),
		(h5["events"] as Array).size() == 1 and _roles_from_rows(h5["events"]) == ["rabbit"])
	_expect("5 rescue completes (%s/%s)" % [String(c5["rescue_result"]), String(c5["mount_state"])],
		String(c5["rescue_result"]) == "caught" and String(c5["mount_state"]) == "RIDING")
	_expect("5 successful rescue adds no penalty (accidents=%d, mistakes=%d)" % [
		int(c5["accident_count"]), int(c5["mistakes"])],
		int(c5["accident_count"]) == 1 and int(c5["mistakes"]) == 1)
	_expect("5 rescue success is never a joint accident (joint=%d, roles=%s)" % [
		int(c5["joint_count"]), str(_roles_of(c5))],
		int(c5["joint_count"]) == 0 and _roles_of(c5) == ["rabbit"])
	_expect("5 accident state clears after the rescue (%s)" % String(c5["accident_state"]),
		String(c5["accident_state"]) == "NONE")

	# 6 救援中独立碰撞
	var c6: Dictionary = c["c6_rescue_independent_hit"]
	var h6: Dictionary = c6["hit_snapshot"]
	_expect("6 independent hit happens while the rabbit is in the water (%s)" % [
		String(c6["accident_state_at_hit"])],
		String(c6["accident_state_at_hit"]) == "RABBIT_WATER")
	_expect("6 independent collision is not swallowed (accidents=%d, mistakes=%d)" % [
		int(c6["accident_count"]), int(c6["mistakes"])],
		int(c6["accident_count"]) == 2 and int(c6["mistakes"]) == 2)
	_expect("6 the new event is turtle-only, not joint (events=%s)" % str(c6["events"]),
		(c6["events"] as Array).size() == 2
		and String(_ev(c6, 1).get("penalty_role", "")) == "turtle"
		and _roles_of(c6) == ["rabbit", "turtle"])
	_expect("6 first event stays rabbit-only (%s)" % str(_ev(c6, 0)),
		String(_ev(c6, 0).get("penalty_role", "")) == "rabbit")

	# 7 被顶住不再追加
	var c7: Dictionary = c["c7_turtle_pushed_no_second"]
	_expect("7 turtle is physically blocked at the log (x=%.1f <= %.1f)" % [
		float(c7["turtle_x"]), float(c7["log_left"]) - TURTLE_HALF_W],
		bool(c7["pinned_left_of_log"]))
	_expect("7 overlap does not stack penalties (accidents=%d, mistakes=%d)" % [
		int(c7["accident_count"]), int(c7["mistakes"])],
		int(c7["accident_count"]) == 1 and int(c7["mistakes"]) == 1)
	_expect("7 event stays turtle-only (%s)" % str(_roles_of(c7)), _roles_of(c7) == ["turtle"])

	# 8 正确下潜
	var c8: Dictionary = c["c8_turtle_passes_clean"]
	_expect("8 clean dive records nothing (accidents=%d, events=%d)" % [
		int(c8["accident_count"]), (c8["events"] as Array).size()],
		int(c8["accident_count"]) == 0 and (c8["events"] as Array).size() == 0)
	_expect("8 turtle actually passed the gate (x=%.1f > %.1f)" % [
		float(c8["end_x"]), float(c8["gate_right"])],
		float(c8["end_x"]) > float(c8["gate_right"]) + 100.0)


func _roles_of(row: Dictionary) -> Array:
	return _roles_from_rows(row.get("events", []))


func _roles_from_rows(events: Array) -> Array:
	var roles := []
	for e in events:
		for r in e.get("roles", []):
			if not roles.has(String(r)):
				roles.append(String(r))
	roles.sort()
	return roles


func _ev(row: Dictionary, i: int) -> Dictionary:
	var events: Array = row.get("events", [])
	if i < 0 or i >= events.size():
		return {}
	return events[i]


func _expect(msg: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + msg)
	if not ok:
		failures.append(msg)


func _write() -> void:
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		failures.append("cannot write " + OUT_PATH)
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()
