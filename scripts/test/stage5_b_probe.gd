extends Node
## TBB-EXPERIENCE-REBUILD-05 B1/B2/B3：只读诊断 + 回归探针。
##
## B1：兔子落水 → 乌龟下潜接住 → 回壳。逐阶段记录
##     accident_state / score_log / BRO METER / casualties，检查接应成功后
##     是否还有追加判罚、事故状态是否残留。
## B2：五种回归场景 —— 单兔 / 单龟 / 同帧双撞 / 先后撞同障碍 / 浪涌干扰。
## B3：接应过程中乌龟真实穿过浮木，碰撞是否被吞（“接应无敌”）。
##
## 输出：docs/reports/longrun/rebuild05-b-probe.json
## 用法：godot --headless --path TURBBIT res://scenes/stage5_b_probe.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/rebuild05-b-probe.json"
const STEP := 1.0 / 60.0

var is_runner := false
var race: Node = null
var out := {}
var failures: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage5BProbeRunner"
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
		push_error("B PROBE: no race scene")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()
	await get_tree().physics_frame

	out["generated_at"] = Time.get_datetime_string_from_system()
	out["cases"] = {}

	# B1：无碍物的纯接应流程（隔离事故记账）。
	race.test_disable_hazards = true
	out["cases"]["b1_rescue_after_face_fall"] = _case_rescue()
	# B1b：接应期间乌龟真实撞上浮木——事故状态不能再把障碍判定整段关掉。
	race.test_disable_hazards = false
	out["cases"]["b1b_hazard_during_rescue"] = _case_hazard_during_rescue()

	# B2 五场景。
	race.test_disable_hazards = false
	out["cases"]["s1_rabbit_only"] = _case_ride_into("beam2", 9600.0 - 190.0, 3.2)
	out["cases"]["s2_turtle_only"] = _case_ride_into("shark1", 7250.0 - 190.0, 3.2)
	out["cases"]["s3_both_same_log"] = _case_ride_into("log1", 6400.0 - 190.0, 3.2)
	out["cases"]["s4_two_records_one_group"] = _case_jump_then_cruise()
	out["cases"]["s5_wave_during_rescue"] = _case_wave_during_rescue()

	_evaluate()
	_write()
	print("B PROBE: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _reset(x: float, y: float) -> void:
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
	GameManager.current_control = "turtle"
	race.showtime_active = false
	race.joint_show_t = 0.0
	race.finishing = false
	race.hazard_cooldown = 0.0
	race.accident_flash = 0.0
	race.rabbit_stun = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.emergency_timer = 0.0
	race.turtle_repair = 0.0
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.group_actions.clear()
	race.reset_brains()
	race.turtle.reset(Vector2(x, y))
	race.turtle.base_speed = 220.0
	race.turtle.speed = 220.0
	race.turtle.speed_cap = 1.0e9
	race.turtle.daze_time = 0.0
	race.turtle.drift = 0.0
	race.turtle.dunk_timer = 0.0
	race.rabbit.reset()
	race.mount.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.mark_riding()
	race.rabbit.state = "RIDING"
	race.rescue_last_result = ""
	race.rescue_last_reason = ""
	race.carry_max_step = 0.0
	race.carry_kind = ""
	race.snack_boost_until_x = -1.0
	race.snack_boost_speed = 0.0
	Input.action_release("down")
	Input.action_release("up")


func _drop_rabbit(behind: Vector2, vel: Vector2) -> void:
	race.mount.mark_airborne()
	race.rabbit.position = race.turtle.get_mount_point() + behind
	race.rabbit.velocity = vel
	race.rabbit.state = "FALLING"
	race.rescue_prev_pos = race.rabbit.position


## 记录一次快照，便于逐阶段对照。
func _snap(t: float, extra: Dictionary = {}) -> Dictionary:
	var d := {
		"t": snappedf(t, 0.001),
		"accident": GameManager.accident_state,
		"mount": String(race.mount.state),
		"rabbit_state": String(race.rabbit.state),
		"control": GameManager.current_control,
		"bro": GameManager.bro_meter,
		"accident_count": GameManager.accident_count,
		"casualties": GameManager.rabbit_casualties,
		"turtle_failures": GameManager.turtle_failures,
		"rescue_ok": GameManager.rescue_success_count,
		"score": GameManager.total_score,
		"score_log": GameManager.score_log.duplicate(true),
		"cooldown": snappedf(race.hazard_cooldown, 0.01),
		"oxygen": snappedf(GameManager.oxygen, 0.01),
		"turtle_speed": snappedf(race.turtle.speed, 0.1),
		"turtle_dunk": snappedf(race.turtle.dunk_timer, 0.01),
		"hit_roles": race.hit_roles.duplicate(true),
	}
	for k in extra:
		d[k] = extra[k]
	return d


func _reasons(snap: Dictionary) -> Array:
	var r: Array = []
	for e in snap.get("score_log", []):
		r.append(String(e["reason"]))
	return r


func _rect_of(key: String) -> Rect2:
	for g in race.hazard_groups:
		if String(g["group"]) == key:
			return g["rects"][0]
	return Rect2()


## B1：兔子从壳上掉下去，玩家按住 ↓ 下潜接人（开阔水域，隔离事故记账）。
func _case_rescue() -> Dictionary:
	var x0 := 7920.0 # log1(6400)、shark1(7250) 之后的开阔水域
	_reset(x0, Tuning.NEUTRAL_DEPTH)
	_drop_rabbit(Vector2(-46.0, 105.0), Vector2(0.0, 60.0))
	Input.action_release("down")

	var ev := {"x0": x0}
	var t := 0.0
	var seen_trigger := false
	var seen_catch := false
	var seen_done := false
	var suppressed_ticks := 0
	var intersected := {}
	var done_t := -1.0
	while t < 9.0:
		if seen_trigger:
			Input.action_press("down") # 触发后玩家立刻按住 ↓ 追兔子
		race._physics_process(STEP)
		t += STEP
		if not seen_trigger and GameManager.accident_state == "RABBIT_WATER":
			seen_trigger = true
			ev["trigger"] = _snap(t, {"rabbit_x": snappedf(race.rabbit.position.x, 0.1)})
			ev["trigger_t"] = snappedf(t, 0.001)
		if seen_trigger and not seen_catch and String(race.rescue_last_result) == "caught":
			seen_catch = true
			ev["catch"] = _snap(t)
			ev["catch_t"] = snappedf(t, 0.001)
		if seen_catch and not seen_done and GameManager.accident_state == "NONE" \
				and String(race.mount.state) == "RIDING":
			seen_done = true
			done_t = t
			ev["done"] = _snap(t)
			ev["done_t"] = snappedf(t, 0.001)
			Input.action_release("down")
		if seen_done and t - done_t > 2.5:
			break
		# 接应/事故期间：乌龟身体和障碍重叠但还没被记账的帧数。
		if seen_trigger:
			var tr: Rect2 = race._inset(race.turtle.get_body_rect(), 3.0)
			for g in race.hazard_groups:
				var group: Dictionary = g
				var key := String(group["group"])
				for r in group["rects"]:
					var rect: Rect2 = r
					if tr.intersects(rect):
						intersected[key] = true
						if not Dictionary(race.hit_roles.get(key, {})).has("turtle"):
							suppressed_ticks += 1
	Input.action_release("down")
	ev["after"] = _snap(t)
	ev["turtle_overlap_unrecorded_ticks"] = suppressed_ticks
	ev["turtle_intersected_groups"] = intersected.keys()
	return ev


## 兔子在 log1 前 250 px 落水、玩家不管；乌龟继续以巡航深度撞同一根木头。
## 这是“接应＝无敌”的正面反例：事故状态是 RABBIT_WATER，乌龟的碰撞也必须记。
func _case_hazard_during_rescue() -> Dictionary:
	_reset(6400.0 - 250.0, Tuning.NEUTRAL_DEPTH)
	_drop_rabbit(Vector2(-46.0, 105.0), Vector2(0.0, 60.0))
	Input.action_release("down")
	Input.action_release("up")
	var t := 0.0
	var ev := {}
	while t < 3.0:
		race._physics_process(STEP)
		t += STEP
		if GameManager.accident_state == "RABBIT_WATER" and not ev.has("trigger"):
			ev["trigger"] = _snap(t)
		if Dictionary(race.hit_roles.get("log1", {})).has("turtle") and not ev.has("hit"):
			ev["hit"] = _snap(t) # 记下命中那一刻的事故状态
			break
	ev["end"] = _snap(t)
	ev["reasons"] = _reasons(ev["end"])
	ev["roles"] = Dictionary(race.hit_roles.get("log1", {})).keys()
	return ev


## 无输入直冲某组障碍：看两个角色分别被记了什么。
func _case_ride_into(key: String, x0: float, seconds: float) -> Dictionary:
	_reset(x0, Tuning.NEUTRAL_DEPTH)
	# REBUILD-06 P3：鲨鱼有逐组伏击状态。每例从“已经在深水里等”重来，
	# 否则上一例残留的相位会让同样的输入时撞时不撞。
	race.reset_ambush_states("DOWN")
	Input.action_release("down")
	Input.action_release("up")
	var t := 0.0
	var ev := {"target": key, "x0": x0}
	var role_t := {}
	while t < seconds:
		race._physics_process(STEP)
		t += STEP
		var roles: Dictionary = race.hit_roles.get(key, {})
		for role in roles.keys():
			if not role_t.has(role):
				role_t[role] = snappedf(t, 0.001)
	ev["first_hit_t"] = role_t
	ev["end"] = _snap(t)
	ev["reasons"] = _reasons(ev["end"])
	ev["roles"] = Dictionary(race.hit_roles.get(key, {})).keys()
	return ev


## 同一组浮木被两个角色先后撞上：乌龟先被顶在入口，壳被撞沉后从下方滑过，
## 壳上的兔子从浮木下沿擦到同一根木头。
##
## 2026-11-13 REFINE-06 P0 之后龟壳是实心的：以前“兔子在空中先撞木头、乌龟
## 随后穿过”的旧输入，现在会在壳被顶住时让兔子从上方清过木头（兔子比壳窄
## 29 px，壳停住后它追不上木头），所以这里改成真实的“先后各一笔”路径：
## 乌龟先撞、兔子后擦到，两笔都要保留。
func _case_jump_then_cruise() -> Dictionary:
	_reset(6400.0 - 260.0, Tuning.NEUTRAL_DEPTH)
	Input.action_release("down")
	Input.action_release("up")
	var t := 0.0
	var ev := {}
	while t < 5.0:
		race._physics_process(STEP)
		t += STEP
		if Dictionary(race.hit_roles.get("log1", {})).has("turtle") and not ev.has("first_hit"):
			ev["first_hit"] = _snap(t)
			ev["first_hit_t"] = snappedf(t, 0.001)
			ev["first_hit_reasons"] = _reasons(ev["first_hit"])
		if Dictionary(race.hit_roles.get("log1", {})).has("rabbit"):
			ev["second_hit"] = _snap(t)
			ev["second_hit_t"] = snappedf(t, 0.001)
			break
	ev["end"] = _snap(t)
	ev["reasons"] = _reasons(ev["end"])
	ev["roles"] = Dictionary(race.hit_roles.get("log1", {})).keys()
	return ev


## 兔子在 shark1 前落水；乌龟不理会继续巡航，撞鲨鱼（浪涌）必须照常记账。
func _case_wave_during_rescue() -> Dictionary:
	_reset(7250.0 - 200.0, Tuning.NEUTRAL_DEPTH)
	race.reset_ambush_states("DOWN")
	_drop_rabbit(Vector2(-46.0, 105.0), Vector2(0.0, 60.0))
	Input.action_release("down")
	Input.action_release("up")
	var t := 0.0
	var ev := {}
	var trigger_t := -1.0
	while t < 4.0:
		race._physics_process(STEP)
		t += STEP
		if trigger_t < 0.0 and GameManager.accident_state == "RABBIT_WATER":
			trigger_t = t
			ev["trigger"] = _snap(t)
		if trigger_t >= 0.0 and race.hit_roles.get("shark1", {}).has("turtle"):
			ev["wave_hit"] = _snap(t)
			break
	ev["end"] = _snap(t)
	ev["reasons"] = _reasons(ev["end"])
	ev["roles"] = Dictionary(race.hit_roles.get("shark1", {})).keys()
	return ev


func _evaluate() -> void:
	var c: Dictionary = out["cases"]

	# ---- B1：接应成功必须干净收尾 ----
	var b1: Dictionary = c["b1_rescue_after_face_fall"]
	var ok_b1: bool = b1.has("trigger") and b1.has("done")
	_expect("b1: rescue flow completed", ok_b1)
	if ok_b1:
		# rescue_switch 是 SHIFT 接人的 +50 奖励，不是失误；只数 mistake: 条目。
		var n_done := _count_mistakes(_reasons(b1["done"]))
		var n_after := _count_mistakes(_reasons(b1["after"]))
		_expect("b1: exactly one fall mistake recorded (%s)" % str(_reasons(b1["done"])),
			n_done == 1)
		_expect("b1: no extra penalty after successful rescue (%d -> %d)" % [n_done, n_after],
			n_done == n_after)
		_expect("b1: accident state cleared (%s)" % String(b1["after"]["accident"]),
			String(b1["after"]["accident"]) == "NONE")
		_expect("b1: riding again (%s)" % String(b1["after"]["mount"]),
			String(b1["after"]["mount"]) == "RIDING")
		_expect("b1: cooldown relaxed to rescue grace (%s s)" % str(b1["done"]["cooldown"]),
			float(b1["done"]["cooldown"]) <= Tuning.RESCUE_GRACE_TIME + 0.001)

	# ---- B1b：接应期间的真实碰撞不能被吞 ----
	var b1b: Dictionary = c["b1b_hazard_during_rescue"]
	var hit_snap: Dictionary = b1b.get("hit", {})
	_expect("b1b: turtle collides with log1 while rescuing (%s)" % str(b1b.get("roles")),
		(b1b.get("roles", []) as Array).has("turtle"))
	_expect("b1b: that collision happened during RABBIT_WATER (state=%s)" % [
		String(hit_snap.get("accident", "none"))],
		String(hit_snap.get("accident", "")) == "RABBIT_WATER")
	_expect("b1b: and it produced a real record (%s)" % str(b1b.get("reasons")),
		_has_any(b1b.get("reasons", []), "TURTLE_DIVE_LATE"))

	# ---- B2 s1：单兔。只有兔子记账 ----
	var s1: Dictionary = c["s1_rabbit_only"]
	_expect("s1: rabbit recorded on LOW_BEAM (%s)" % str(s1["reasons"]),
		_has_any(s1["reasons"], "RABBIT"))
	_expect("s1: turtle NOT recorded on LOW_BEAM (%s)" % str(s1["roles"]),
		not (s1["roles"] as Array).has("turtle"))

	# ---- B2 s2：单龟。只有乌龟记账 ----
	var s2: Dictionary = c["s2_turtle_only"]
	_expect("s2: turtle recorded on SHARK (%s)" % str(s2["reasons"]),
		_has_any(s2["reasons"], "TURTLE"))
	_expect("s2: rabbit NOT recorded on SHARK (%s)" % str(s2["roles"]),
		not (s2["roles"] as Array).has("rabbit"))

	# ---- B2 s3：同一组障碍两个角色都撞。CORE-FEEL-07 P0-B 起只罚一次 ----
	var s3: Dictionary = c["s3_both_same_log"]
	_expect("s3: both roles recorded on FLOATING_LOG (%s)" % str(s3["roles"]),
		(s3["roles"] as Array).has("rabbit") and (s3["roles"] as Array).has("turtle"))
	_expect("s3: the same obstacle is charged exactly once (%s)" % str(s3["reasons"]),
		_count_mistakes(s3["reasons"]) == 1)

	# ---- B2 s4：同一组先后撞。同一个事故事件，仍然只罚一次 ----
	var s4: Dictionary = c["s4_two_records_one_group"]
	_expect("s4: both roles recorded on log1 (%s)" % str(s4["roles"]),
		(s4["roles"] as Array).has("rabbit") and (s4["roles"] as Array).has("turtle"))
	_expect("s4: exactly one record for the group (%s)" % str(s4["reasons"]),
		_count_mistakes(s4["reasons"]) == 1)

	# ---- B2 s5：浪涌不能替代碰撞记录 ----
	var s5: Dictionary = c["s5_wave_during_rescue"]
	_expect("s5: turtle wave recorded while rabbit is in rescue (%s)" % str(s5["reasons"]),
		_has_any(s5["reasons"], "TURTLE"))
	_expect("s5: wave hit keeps its own obstacle label",
		(s5["reasons"] as Array).any(func(r): return String(r) == "mistake:TURTLE_WAVE"))


func _has_any(arr: Array, needle: String) -> bool:
	for r in arr:
		if String(r).contains(needle):
			return true
	return false


func _count_mistakes(arr: Array) -> int:
	var n := 0
	for r in arr:
		if String(r).begins_with("mistake:"):
			n += 1
	return n


func _expect(label: String, ok: bool) -> void:
	if not ok:
		failures.append(label)


func _write() -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f == null:
		push_error("B PROBE: cannot write " + OUT_PATH)
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()
