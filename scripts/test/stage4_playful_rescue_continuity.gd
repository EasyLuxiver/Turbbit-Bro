extends Node
## TBB-SHIFT-PLAYFUL-04 §3：水中接应的连续性审查。
##
## 在正式 race.gd 上真实跑物理：兔子从壳后方掉进水里，记录
##   落水时的世界坐标/速度、乌龟位置/速度/深度、
##   接应开始时刻、水平/垂直距离的逐帧演化、
##   接住触发点、接住后的坐标；
## 并对每个 case 检查：
##   - 兔子保留真实落点（没有向前瞬移）；
##   - 接住判定用的是水平+垂直距离和相对速度（命中帧 = 几何窗口第一次成立的那帧）；
##   - 接近→托起→回壳全程逐帧位移不超过物理上限（没有瞬移）；
##   - 玩家主动下潜明显提高成功率；
##   - 失败是短暂、可恢复、不会再记一次事故的。
##
## 输出：docs/reports/longrun/playful04-rescue-continuity.json

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/playful04-rescue-continuity.json"
## 单帧位移的物理上限：正常下落 950 px/s、救援追赶 560、抬升 520。
## 任何一帧超过 1000 px/s 的位移都只可能是吸附/瞬移。
const MAX_IMPLIED_SPEED := 1000.0

var is_runner := false
var race: Node = null
var data := {}
var failures: Array = []


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
	Locale.language = "zh"
	GameManager.start_race()
	for i in 4:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null:
		push_error("RESCUE PROBE: no race scene")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_disable_hazards = true
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()

	data["setup"] = {
		# 兔子被撞离壳、已经在壳下方（不在接人盒内，不会被普通接人吸走），
		# 横向只偏 46 px——这就是“从后方落水”的真实起点。
		"rabbit_start_offset": [-46.0, 105.0],
		"rabbit_start_velocity": [0.0, 60.0],
		"turtle_x": 5000.0, "turtle_depth": Tuning.NEUTRAL_DEPTH,
		"turtle_speed": 220.0,
		"catch_box": {"dx": Tuning.RESCUE_CATCH_DX,
			"dy_min": Tuning.RESCUE_CATCH_DY_MIN,
			"dy_max": Tuning.RESCUE_CATCH_DY_MAX,
			"closing_min": Tuning.RESCUE_CLOSING_MIN},
		"slow_speed": Tuning.RESCUE_SLOW_SPEED,
		"carry_speed": Tuning.CARRY_SPEED,
	}
	data["trials"] = {}

	var trials := [
		{"name": "dive_immediate", "delay": 0.0, "hz": 60.0},
		{"name": "dive_0_3s", "delay": 0.3, "hz": 60.0},
		{"name": "dive_0_6s", "delay": 0.6, "hz": 60.0},
		{"name": "dive_1_0s", "delay": 1.0, "hz": 60.0},
		{"name": "no_dive", "delay": -1.0, "hz": 60.0},
		{"name": "dive_immediate_30hz", "delay": 0.0, "hz": 30.0},
		{"name": "dive_immediate_120hz", "delay": 0.0, "hz": 120.0},
		{"name": "no_dive_30hz", "delay": -1.0, "hz": 30.0},
	]
	for tr in trials:
		data["trials"][String(tr["name"])] = _trial(
			float(tr["delay"]), 1.0 / float(tr["hz"]))

	_evaluate()
	_write()
	print("RESCUE CONTINUITY: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


## ---- 单个 trial ----

func _trial(dive_delay: float, step: float) -> Dictionary:
	_reset()
	Input.action_release("down")
	var every: int = int(round(step * 60.0))
	if every < 1:
		every = 1
	var t := 0.0
	var prev: Vector2 = race.rabbit.position
	var trace: Array = []
	var ev := {}
	var seen_trigger := false
	var max_speed_implied := 0.0
	var catch_t := -1.0
	var miss_t := -1.0
	var recovered_t := -1.0
	var box_ok_t := -1.0
	var box_ok_dx := 0.0
	var box_ok_dy := 0.0
	var ticks := 0
	var i := 0
	while t < 7.0 and ticks < 6000:
		var pressing: bool = dive_delay >= 0.0 and t >= dive_delay
		if pressing:
			Input.action_press("down")
		else:
			Input.action_release("down")
		race._physics_process(step)
		t += step
		ticks += 1
		i += 1

		var rp: Vector2 = race.rabbit.position
		var mp: Vector2 = race.turtle.get_mount_point()
		var move: float = rp.distance_to(prev)
		prev = rp
		if seen_trigger:
			max_speed_implied = maxf(max_speed_implied, move / step)

		var st := String(race.mount.state)
		var dx: float = rp.x - mp.x
		var dy: float = rp.y - mp.y
		var closing: float = race.turtle.speed - race.rabbit.velocity.x
		var in_box: bool = absf(dx) <= Tuning.RESCUE_CATCH_DX \
			and dy >= Tuning.RESCUE_CATCH_DY_MIN \
			and dy <= Tuning.RESCUE_CATCH_DY_MAX \
			and closing >= Tuning.RESCUE_CLOSING_MIN

		if not seen_trigger and GameManager.accident_state == "RABBIT_WATER":
			seen_trigger = true
			ev["trigger_t"] = snappedf(t, 0.001)
			ev["trigger_rabbit"] = [snappedf(rp.x, 0.1), snappedf(rp.y, 0.1)]
			ev["trigger_vel"] = [snappedf(race.rabbit.velocity.x, 0.1),
				snappedf(race.rabbit.velocity.y, 0.1)]
			ev["trigger_turtle"] = [snappedf(race.turtle.position.x, 0.1),
				snappedf(race.turtle.position.y, 0.1)]
			ev["trigger_turtle_speed"] = snappedf(race.turtle.speed, 0.1)
			ev["trigger_dx"] = snappedf(dx, 0.1)
		if st == "RESCUE_ACTIVE" and not ev.has("splash_t"):
			ev["splash_t"] = snappedf(t, 0.001)
			ev["splash_pos"] = [snappedf(race.rescue_splash_pos.x, 0.1),
				snappedf(race.rescue_splash_pos.y, 0.1)]
			ev["splash_dx"] = snappedf(race.rescue_splash_pos.x - mp.x, 0.1)
			ev["splash_vel_y"] = snappedf(race.rabbit.velocity.y, 0.1)
		# 几何窗口第一次成立的帧。接住那一帧状态已经变成 CARRYING，
		# 所以这里只看“已经落水之后”，不看当前状态名。
		if seen_trigger and box_ok_t < 0.0 and in_box:
			box_ok_t = t
			box_ok_dx = dx
			box_ok_dy = dy
			ev["box_first_t"] = snappedf(t, 0.001)
			ev["box_first_dx"] = snappedf(dx, 0.1)
			ev["box_first_dy"] = snappedf(dy, 0.1)
		if catch_t < 0.0 and String(race.rescue_last_result) == "caught":
			catch_t = t
			ev["catch_t"] = snappedf(t, 0.001)
			ev["catch_pos"] = [snappedf(rp.x, 0.1), snappedf(rp.y, 0.1)]
			ev["catch_dx"] = snappedf(dx, 0.1)
			ev["catch_dy"] = snappedf(dy, 0.1)
			ev["catch_distance"] = snappedf(rp.distance_to(mp), 0.1)
			ev["catch_state"] = st
			ev["catch_in_box"] = in_box
			ev["catch_box_first_t"] = box_ok_t
		if miss_t < 0.0 and String(race.rescue_last_result) == "missed":
			miss_t = t
			ev["miss_t"] = snappedf(t, 0.001)
			ev["miss_reason"] = String(race.rescue_last_reason)
			ev["miss_pos"] = [snappedf(rp.x, 0.1), snappedf(rp.y, 0.1)]
			ev["miss_dx"] = snappedf(dx, 0.1)
			ev["miss_dy"] = snappedf(dy, 0.1)
			ev["miss_distance"] = snappedf(rp.distance_to(mp), 0.1)
			ev["miss_state"] = st
		if st == "CARRYING" and String(race.carry_kind) == "rescue_return" \
				and not ev.has("return_carry_t"):
			ev["return_carry_t"] = snappedf(t, 0.001)
		if recovered_t < 0.0 and (catch_t >= 0.0 or miss_t >= 0.0) \
				and GameManager.accident_state == "NONE" and st == "RIDING":
			recovered_t = t
			ev["recovered_t"] = snappedf(t, 0.001)

		if i % every == 0:
			trace.append({
				"t": snappedf(t, 0.01), "state": st,
				"r": [snappedf(rp.x, 0.1), snappedf(rp.y, 0.1)],
				"tv": [snappedf(race.turtle.position.x, 0.1),
					snappedf(race.turtle.position.y, 0.1)],
				"spd": snappedf(race.turtle.speed, 0.1),
				"rv": [snappedf(race.rabbit.velocity.x, 0.1),
					snappedf(race.rabbit.velocity.y, 0.1)],
				"dx": snappedf(dx, 0.1), "dy": snappedf(dy, 0.1),
				"box": in_box,
			})
		if recovered_t >= 0.0:
			break

	Input.action_release("down")
	var caught: bool = catch_t >= 0.0
	ev["caught"] = caught
	ev["final_state"] = String(race.mount.state)
	ev["final_accident"] = GameManager.accident_state
	ev["max_implied_speed"] = snappedf(max_speed_implied, 1.0)
	ev["carry_max_step"] = snappedf(race.carry_max_step, 0.1)
	ev["carry_max_speed"] = snappedf(race.carry_max_step / step, 1.0)
	ev["accident_count"] = GameManager.accident_count
	ev["success_count"] = GameManager.rescue_success_count
	ev["total_t"] = snappedf(t, 0.001)
	ev["total_from_splash"] = snappedf(t - float(ev.get("splash_t", t)), 0.001)
	if miss_t >= 0.0:
		ev["recover_from_miss"] = snappedf(
			float(ev.get("recovered_t", t)) - float(ev.get("miss_t", 0.0)), 0.001)
	else:
		ev["recover_from_miss"] = 0.0
	ev["dive_delay"] = dive_delay
	ev["step"] = step
	ev["trace"] = trace
	return ev


func _reset() -> void:
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.clear_bro_meter()
	GameManager.accident_count = 0
	GameManager.total_score = 0
	GameManager.score_log.clear()
	GameManager.rabbit_casualties = 0
	GameManager.turtle_failures = 0
	GameManager.rescue_success_count = 0
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
	# G20：hit_roles 必须和 hit_groups 一起清。只清 hit_groups 时，B2 起的“角色×组”记账还留着，同组第二例起整组免疫——后面那些重复用例其实在测一段不会撞的赛道。
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.group_actions.clear()
	race.reset_brains()
	race.turtle.reset(Vector2(5000.0, Tuning.NEUTRAL_DEPTH))
	race.turtle.base_speed = 220.0
	race.turtle.speed = 220.0
	race.turtle.speed_cap = 1.0e9
	race.turtle.daze_time = 0.0
	race.turtle.drift = 0.0
	race.rabbit.reset()
	race.mount.reset()
	race.mount.mark_airborne()
	race.rabbit.position = race.turtle.get_mount_point() + Vector2(-46.0, 105.0)
	race.rabbit.velocity = Vector2(0.0, 60.0)
	race.rabbit.state = "FALLING"
	race.rescue_last_result = ""
	race.rescue_last_reason = ""
	race.rescue_prev_pos = race.rabbit.position
	race.carry_max_step = 0.0
	race.carry_kind = ""
	race.snack_boost_until_x = -1.0
	race.snack_boost_speed = 0.0


## ---- 判定 ----

func _evaluate() -> void:
	var trials: Dictionary = data["trials"]
	for name in trials.keys():
		var tr: Dictionary = trials[name]
		# 1) 没有瞬移：从落水开始，每一帧位移都在物理上限内。
		_expect("%s: no teleport (max implied %.0f px/s vs bound %.0f)" % [
			name, float(tr["max_implied_speed"]), MAX_IMPLIED_SPEED],
			float(tr["max_implied_speed"]) <= MAX_IMPLIED_SPEED + 1.0)
		# 抬升本身是 smoothstep：峰值是平均速度的 1.5 倍，再加上乌龟同帧的移动。
		_expect("%s: carry lift is a visible glide, not a jump (%.0f px/s)" % [
			name, float(tr["carry_max_speed"])],
			float(tr["carry_max_speed"]) <= Tuning.CARRY_SPEED * 1.5 + 500.0)
		# 2) 落水保留真实落点：触发点就是兔子掉落的位置，没有向前弹。
		_expect("%s: trigger keeps the real position (dx=%.1f, behind)" % [
			name, float(tr.get("trigger_dx", 0.0))],
			float(tr.get("trigger_dx", 0.0)) <= 0.0)
		# 3) 恢复后状态干净。
		_expect("%s: ends riding with no active accident (%s/%s)" % [
			name, tr["final_state"], tr["final_accident"]],
			String(tr["final_state"]) == "RIDING"
			and String(tr["final_accident"]) == "NONE")
		_expect("%s: exactly one accident recorded (%d)" % [name, int(tr["accident_count"])],
			int(tr["accident_count"]) == 1)
		if bool(tr["caught"]):
			_expect("%s: catch happens inside the distance box" % name,
				bool(tr["catch_in_box"]))
			_expect("%s: catch uses the box rule, not a snap (first box tick %.3f, catch %.3f)"
				% [name, float(tr["catch_box_first_t"]), float(tr["catch_t"])],
				absf(float(tr["catch_box_first_t"]) - float(tr["catch_t"])) <= 0.05)
			_expect("%s: the catch is a visible lift, not an attach (state=%s, distance=%.1f)"
				% [name, tr["catch_state"], float(tr["catch_distance"])],
				String(tr["catch_state"]) == "CARRYING"
				and float(tr["catch_distance"]) > Tuning.CARRY_SNAP_DIST)
		else:
			_expect("%s: a missed rescue is short (%.2f s from miss to riding)"
				% [name, float(tr["recover_from_miss"])],
				float(tr["recover_from_miss"]) <= 2.5)

	# 4) 玩家主动下潜明显提高成功率。
	_expect("dive immediately -> caught", bool(trials["dive_immediate"]["caught"]))
	# 不按 ↓：壳一直在水面，接不到；乌龟会从兔子身边开过去（passed_by）。
	_expect("no dive -> missed with a concrete reason (%s)"
		% String(trials["no_dive"].get("miss_reason", "")),
		not bool(trials["no_dive"]["caught"])
		and String(trials["no_dive"].get("miss_reason", "")) != "")
	var dive_ok := 0
	var dive_n := 0
	for n in ["dive_immediate", "dive_0_3s", "dive_0_6s"]:
		dive_n += 1
		if bool(trials[n]["caught"]):
			dive_ok += 1
	_expect("early dives succeed (%.0f/%.0f)" % [dive_ok, dive_n], dive_ok == dive_n)
	# 5) 帧率无关：30/120 Hz 下同样是接住，且都没有瞬移。
	for n in ["dive_immediate_30hz", "dive_immediate_120hz"]:
		_expect("%s: caught at this physics rate" % n, bool(trials[n]["caught"]))
	_expect("no_dive_30hz: missed at this physics rate",
		not bool(trials["no_dive_30hz"]["caught"]))

	# 汇总表
	var table := []
	for name in trials.keys():
		var tr: Dictionary = trials[name]
		table.append({
			"name": name, "dive_delay": tr["dive_delay"], "step": tr["step"],
			"caught": tr["caught"], "miss_reason": tr.get("miss_reason", ""),
			"catch_dx": tr.get("catch_dx", null), "catch_dy": tr.get("catch_dy", null),
			"max_implied_speed": tr["max_implied_speed"],
			"recover_from_miss": tr["recover_from_miss"],
		})
	data["summary"] = table


func _expect(what: String, ok: bool) -> void:
	if not ok:
		failures.append(what)


func _write() -> void:
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		failures.append("cannot write " + OUT_PATH)
		return
	f.store_string(JSON.stringify({
		"generated_at": Time.get_datetime_string_from_system(),
		"note": "水中接应连续性：正式 race.gd 真实物理逐帧记录；自动探针，不是真人试玩。",
		"data": data,
		"failures": failures,
	}, "  "))
	f.close()
