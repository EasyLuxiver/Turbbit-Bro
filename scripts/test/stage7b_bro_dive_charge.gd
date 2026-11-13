extends Node
## CORE-FEEL-07 P0-B 补丁验收：一次失败的 BRO DIVE 只罚一次。
##
## 制作人反馈：兔子起跳撞浮木 → 乌龟下潜去接兔子 → 还是出现「联合惩罚」。
## 复现结论（修复前）：乌龟壳撞浮木记 1 格；壳被浮木顶住，兔子这一跳没有壳可落，
## 1.1 s 后落水又记 1 格——一次失败扣两格，BRO METER 提前满格，播「联合惩罚」。
##
## 本探针在真实关卡 log1 上用真实按键跑这条动作链，逐条判定：
##   1. 标准失败 BRO DIVE：失误 1 次、BRO METER 1 格、无联合惩罚；落水与救援照常发生
##   2. 落水并入同一事件：事件 followups 里能看到 RABBIT_WATER
##   3. 独立失败不被吞：兔子单独落水仍记 1；另一道障碍照常记账；同木双撞仍只 1 笔
##   4. 从 2 格开始：一次失败 BRO DIVE 后到 3 格并触发联合惩罚（第三格是正常的）
##
## 输出：docs/reports/longrun/core-feel-07b-bro-dive-charge.json
## 运行：godot --headless --path TURBBIT res://scenes/stage7b_bro_dive_charge.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/core-feel-07b-bro-dive-charge.json"
const STEP := 1.0 / 60.0
const GROUP := "log1"

var is_runner := false
var race: Node = null
var out := {}
var failures: Array = []
var sig_feedback: Array = []
var sig_hint: Array = []
var sig_accident: Array = []
var mistakes: Array = []
var events_seen := 0
var timeline: Array = []
var _joint_seen := false
var _joint_shown := false


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage7bBroDiveChargeRunner"
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
		push_error("CORE-FEEL-07B: no race scene")
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
	out["cases"]["c1_failed_brodive"] = _case(120.0, 0.1, 0)
	out["cases"]["c2_failed_brodive_at_2slots"] = _case(120.0, 0.1, 2)
	out["cases"]["c3_rabbit_water_alone"] = _case_rabbit_water_alone()
	out["cases"]["c4_independent_obstacle"] = _case(120.0, 1.6, 0)
	out["cases"]["c5_same_log_after"] = _case(250.0, 0.1, 0)
	out["cases"]["c6_second_fall_after_window"] = _case_second_fall_after_window()
	out["sweep"] = _sweep()
	_evaluate()
	_write()
	print("CORE-FEEL-07B: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _on_feedback(text: String, _style: String) -> void:
	sig_feedback.append(text)


func _on_hint(text: String) -> void:
	sig_hint.append(text)


func _on_accident(reason: String) -> void:
	sig_accident.append(reason)


## lead = 起跳点距浮木左缘的像素；dive_delay = 落水后多久开始按 ↓；
## preload_meter = 起跑前已经有的 BRO METER 格数。
func _case(lead: float, dive_delay: float, preload_meter: int) -> Dictionary:
	var g := _group()
	var left := float(g["rects"][0].position.x)
	var zone: Dictionary = LevelData.zone_at(left)
	var v := float(zone["base_speed"])
	_reset_at(left - lead, zone, v, preload_meter)

	# 1) 兔子起跳，等它撞上浮木 / 或落地。
	_control("rabbit")
	_press("up")
	var t := 0.0
	var hit_at := -1.0
	while t < 2.0 and GameManager.accident_state != "RABBIT_WATER" \
			and race.joint_show_t <= 0.0:
		race._physics_process(STEP)
		t += STEP
		_mark()
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
		_mark()
		if water_at < 0.0 and GameManager.accident_state == "RABBIT_WATER":
			water_at = t + t2
		# 联合惩罚一开演就停：第 6 例要看的是“第三格在这一刻触发”，不是演出后再跑 9 秒。
		if race.joint_show_t > 0.0:
			break
		if String(race.mount.state) == "RIDING" \
				and GameManager.accident_state == "NONE" \
				and String(race.rescue_last_result) == "caught":
			break
	_release("down")
	var row := _snap()
	row["lead"] = lead
	row["dive_delay"] = dive_delay
	row["preload_meter"] = preload_meter
	row["hit_at"] = snappedf(hit_at, 0.01)
	row["water_at"] = snappedf(water_at, 0.01)
	row["at_fall"] = at_fall
	row["rescue_result"] = String(race.rescue_last_result)
	row["rescue_reason"] = String(race.rescue_last_reason)
	row["mount_state"] = String(race.mount.state)
	row["timeline"] = _timeline()
	return row


## 没有浮木、也没有别的障碍：兔子跳出去，半路把壳潜下去——壳不在下面，兔子落水。
## 这是独立的一次失败，必须照常记 1 格（不能被“并入上游事件”的逻辑吞掉）。
func _case_rabbit_water_alone() -> Dictionary:
	var zone: Dictionary = LevelData.zone_by_id(1)
	_reset_at(900.0, zone, float(zone["base_speed"]), 0)
	_control("rabbit")
	_press("up")
	var t := 0.0
	var shifted := false
	while t < 3.0 and GameManager.accident_state != "RABBIT_WATER":
		if not shifted and t >= 0.8:
			_release("up")
			_control("turtle")
			_press("down")
			shifted = true
		race._physics_process(STEP)
		t += STEP
		_mark()
	_release("up")
	_release("down")
	var row := _snap()
	row["case"] = "rabbit_water_alone"
	row["water_at"] = snappedf(t, 0.01)
	row["timeline"] = _timeline()
	return row


## 浮木事件过去超过 1.5 s 之后，兔子再落一次水：这是新的一笔，必须照记。
## 先复现标准失败（落水被并进浮木事件），等救援把兔子捞回来；窗口早过了，
## 兔子再跳一次、半路把壳潜下去——仍是真实物理与真实按键，看第二格记不记。
func _case_second_fall_after_window() -> Dictionary:
	var first := _case(120.0, 0.1, 0)
	var settled_t := float(_ev(first, 0).get("settled_t", -1.0))
	_control("rabbit")
	_press("up")
	var t := 0.0
	var shifted := false
	var gap_at_fall := -1.0
	while t < 4.0 and GameManager.accident_state != "RABBIT_WATER":
		if not shifted and t >= 0.8:
			_release("up")
			_control("turtle")
			_press("down")
			shifted = true
		race._physics_process(STEP)
		t += STEP
		_mark()
		if GameManager.accident_state == "RABBIT_WATER":
			gap_at_fall = race.accident_event_time - settled_t
	_release("up")
	_release("down")
	var row := _snap()
	row["case"] = "second_fall_after_window"
	row["first_mistakes"] = first["mistakes"]
	row["settled_t"] = snappedf(settled_t, 0.01)
	row["second_fall_t"] = snappedf(t, 0.01)
	row["second_fall_gap_s"] = snappedf(gap_at_fall, 0.01)
	row["timeline"] = _timeline()
	return row


# ---------------------------------------------------------------- 扫参数

## 起跳点 × 落水后开始下潜的延迟：看“一笔/两笔”的分布是否还随起跳点跳变。
func _sweep() -> Array:
	var rows := []
	for lead in [40.0, 60.0, 80.0, 100.0, 120.0, 140.0, 160.0, 200.0, 240.0]:
		for delay in [0.1, 0.6, 1.2]:
			var c := _case(lead, delay, 0)
			rows.append({
				"lead": lead, "dive_delay": delay,
				"mistakes": c["mistakes"].size(),
				"reasons": c["mistakes"],
				"meter": c["bro_meter"], "joint": c["joint_count"],
				"rescue": c["rescue_result"],
				"water_at": c.get("water_at", -1.0),
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


func _reset_at(x: float, zone: Dictionary, v: float, preload_meter: int) -> void:
	Input.action_release("up")
	Input.action_release("down")
	Input.action_release("shift")
	sig_feedback.clear()
	sig_hint.clear()
	sig_accident.clear()
	mistakes.clear()
	timeline.clear()
	events_seen = 0
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
	for i in preload_meter:
		GameManager.note_mistake("PRELOAD")
	GameManager.score_log.clear()
	GameManager.accident_count = 0
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


## 每帧记录：新事件、新失误、联合惩罚。只在关键变化时写一行。
func _mark() -> void:
	var log: Array = race.accident_event_log
	while events_seen < log.size():
		var ev: Dictionary = log[events_seen]
		events_seen += 1
		var roles: Array = ev["roles"].keys()
		roles.sort()
		timeline.append({
			"kind": "event", "id": int(ev["id"]), "group": String(ev["group"]),
			"roles": roles, "settled": bool(ev["settled"]),
			"penalty_role": String(ev["penalty_role"]),
			"rabbit_air": bool(ev.get("rabbit_air", false)),
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
			"ahead_of_log": float(race.turtle.position.x) < float(_group()["rects"][0].position.x),
		})
	if GameManager.bro_joint_pending and not _joint_seen:
		_joint_seen = true
		timeline.append({"kind": "joint_armed", "bro_meter": GameManager.bro_meter})
	if race.joint_show_t > 0.0 and not _joint_shown:
		_joint_shown = true
		timeline.append({"kind": "joint_show_started"})


func _mistake_index(i: int) -> int:
	var k := -1
	for j in GameManager.score_log.size():
		if String(GameManager.score_log[j].get("reason", "")).begins_with("mistake:"):
			k += 1
			if k == i:
				return j
	return -1


func _timeline() -> Array:
	var rows := timeline.duplicate(true)
	timeline.clear()
	return rows


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
			"rescue": String(ev["rescue"]),
			"rabbit_air": bool(ev.get("rabbit_air", false)),
			"followups": ev.get("followups", []),
			"t": snappedf(float(ev["t"]), 0.01),
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


# ---------------------------------------------------------------- 判定

func _evaluate() -> void:
	var c: Dictionary = out["cases"]

	# 1) 标准失败 BRO DIVE：一笔
	var c1: Dictionary = c["c1_failed_brodive"]
	_expect("1 failed BRO DIVE charges once (accidents=%d, mistakes=%d, %s)" % [
		int(c1["accident_count"]), (c1["mistakes"] as Array).size(),
		str(c1["mistakes"])],
		int(c1["accident_count"]) == 1 and (c1["mistakes"] as Array).size() == 1)
	_expect("1 failed BRO DIVE fills one BRO METER slot (meter=%d, hud=%s)" % [
		int(c1["bro_meter"]), str(c1["mistakes"])],
		int(c1["bro_meter"]) == 1)
	_expect("1 no premature joint penalty (joint=%d, pending=%s)" % [
		int(c1["joint_count"]), str(c1["joint_pending"])],
		int(c1["joint_count"]) == 0 and not bool(c1["joint_pending"]))
	_expect("1 the fall still happens physically (%s)" % str(c1["accident_signals"]),
		(c1["accident_signals"] as Array).has("RABBIT_WATER"))
	_expect("1 the rescue still plays (result=%s, mount=%s)" % [
		String(c1["rescue_result"]), String(c1["mount_state"])],
		String(c1["rescue_result"]) == "caught"
		and String(c1["mount_state"]) == "RIDING")
	# 2) 落水并入同一事件，记录可查
	var e1: Dictionary = _ev(c1, 0)
	var follows: Array = e1.get("followups", [])
	_expect("2 the fall is recorded on the same event (followups=%s)" % str(follows),
		follows.size() == 1 and String(follows[0].get("reason", "")) == "RABBIT_WATER")
	_expect("2 the event stays obstacle-factual (roles=%s, penalty=%s)" % [
		str(e1.get("roles", [])), String(e1.get("penalty_role", ""))],
		str(e1.get("roles", [])) == str(["turtle"])
		and String(e1.get("penalty_role", "")) == "turtle")

	# 3) 独立失败不被吞
	var c3: Dictionary = c["c3_rabbit_water_alone"]
	_expect("3 rabbit falling into open water still charges once (mistakes=%d, meter=%d)" % [
		(c3["mistakes"] as Array).size(), int(c3["bro_meter"])],
		(c3["mistakes"] as Array).size() == 1 and int(c3["bro_meter"]) == 1
		and (c3["mistakes"] as Array)[0].ends_with("RABBIT_WATER"))
	var c4: Dictionary = c["c4_independent_obstacle"]
	_expect("4 another obstacle is still charged (mistakes=%d, events=%d)" % [
		(c4["mistakes"] as Array).size(), (c4["events"] as Array).size()],
		(c4["mistakes"] as Array).size() == 2 and (c4["events"] as Array).size() == 2
		and String((c4["events"] as Array)[1].get("group", "")) != GROUP)
	var c5: Dictionary = c["c5_same_log_after"]
	_expect("5 same log, rabbit + turtle, still one charge (mistakes=%d, roles=%s)" % [
		(c5["mistakes"] as Array).size(), str(_ev(c5, 0).get("roles", []))],
		(c5["mistakes"] as Array).size() == 1
		and str(_ev(c5, 0).get("roles", [])) == str(["rabbit", "turtle"]))
	# 同一块浮木、但已过 1.5 s 窗口的落水：不能吞，必须重新记一格。
	var c6: Dictionary = c["c6_second_fall_after_window"]
	var c6_bad: Array = c6["mistakes"]
	_expect("3 a second fall outside the window is charged again (mistakes=%d, gap=%.2fs, %s)" % [
		c6_bad.size(), float(c6.get("second_fall_gap_s", -1.0)), str(c6_bad)],
		c6_bad.size() == 2 and c6_bad.has("mistake:RABBIT_WATER")
		and float(c6.get("second_fall_gap_s", -1.0)) > Tuning.ACCIDENT_JOINT_WINDOW)

	# 6) 从 2 格开始：这次失败把它推到 3 格，联合惩罚是正常的第三格
	var c2: Dictionary = c["c2_failed_brodive_at_2slots"]
	_expect("6 from 2 slots one failed BRO DIVE reaches 3 (meter=%d, pending=%s)" % [
		int(c2["bro_meter"]), str(c2["joint_pending"])],
		int(c2["bro_meter"]) == 3 and bool(c2["joint_pending"]))

	# 7) 扫参：所有能接住的标准失败 BRO DIVE 都是 1 笔
	var bad_rows := []
	for r in out["sweep"]:
		if String(r["rescue"]) == "caught" and int(r["mistakes"]) != 1:
			bad_rows.append(r)
	_expect("7 every caught failed BRO DIVE charges once (bad rows=%d)" % bad_rows.size(),
		bad_rows.is_empty())


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
	if f != null:
		f.store_string(JSON.stringify(out, "  "))
		f.close()
