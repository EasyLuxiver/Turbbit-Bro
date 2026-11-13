extends Node
## 阶段 4 / 审计 B：受限视野驾驶器（工程代理，不是人工试玩）。
##
## 它只使用“当前能看见”的信息：
## - 障碍组只有在 turtle.x 到 turtle.x + lookahead 之间才进入感知；
## - 感知到之后还要经过 reaction 秒才允许做决定；
## - 所有按键经过 input_delay 秒才生效；
## - 有决策错误概率，会选错“下潜/保持水面”；
## - 没有任何预设路线、理想时间点或未来组坐标。
##
## 三档参数集中在 PROFILES。随机种子固定，可复现。
## 运行：
##   Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT \
##       res://scenes/stage4_driver.tscn
## 结果：docs/reports/stage4-driver.json 与 docs/reports/stage4-driver.log
##
## 注意：这是工程代理测试，不假冒人类试玩结论。它证明“在这种受限模型下
## 会发生什么”，不证明“真实玩家觉得难/不难”。
##
## 【已退役 2026-11-11 — 障碍空间五类重构】
## 本驾驶器的决策表仍是旧的“两路线”模型（SURFACE_ROCK/LOW_BEAM → 下潜、
## 其余 → 保持水面），与当前五类空间（趴低 / 跳跃 / 跃起 / 下潜 / 组合）
## 不兼容。用它跑出的数字不再能代表当前游戏，因此脚本直接以 exit 2 退出，
## 不再写 stage4-driver.json。历史结果保留在 docs/reports/stage4-driver.json
## 与 STAGE-4-GAMEPLAY-AUDIT.md，只作旧模型的存档；当前验收以
## stage4_proto、stage4_level_audit、stage4_metrics 与真人试玩为准。

const LevelDataScript = preload("res://scripts/systems/level_data.gd")
const OUT_JSON := "res://docs/reports/stage4-driver.json"
const OUT_LOG := "res://docs/reports/stage4-driver.log"
const WORLD_END := LevelDataScript.WORLD_END
const DURATION_LIMIT := 420.0

## 参数全部集中在这里，改难度只改这张表。
## lookahead: 能看见多远的障碍（px）。上限 430 = HUD 预警距离；
##            任何档位都不能看穿到玩家拿不到的信息之外。
##            新手 380（错过预警条开头），普通/熟练 430。
## reaction: 看见后多久才允许决定（s）
## input_delay: 决定后按键多久生效（s）
## error_rate: 每个障碍第一次进入感知时，选错解法的概率
## dive_depth: 下潜目标深度（y）
## dive_margin: 提前量（px）
## switch_interval: 开阔水域交替换人的周期（s）
## pump_at: 失控计时超过这个值就切回受控方救一下（s）
## boost_clear: 前方多少 px 内没有障碍才敢加速
## boost_chance: 进入加速带时选择加速的概率
const PROFILES := [
	{
		"name": "beginner", "lookahead": 380.0, "reaction": 0.45,
		"input_delay": 0.25, "error_rate": 0.18, "dive_depth": 360.0,
		"dive_margin": 30.0, "switch_interval": 2.0, "pump_at": 3.0,
		"boost_clear": 0.0, "boost_chance": 0.0, "prep_rabbit": false,
	},
	{
		"name": "normal", "lookahead": 430.0, "reaction": 0.30,
		"input_delay": 0.15, "error_rate": 0.07, "dive_depth": 350.0,
		"dive_margin": 70.0, "switch_interval": 1.5, "pump_at": 2.9,
		"boost_clear": 500.0, "boost_chance": 0.35, "prep_rabbit": true,
	},
	{
		"name": "skilled", "lookahead": 430.0, "reaction": 0.18,
		"input_delay": 0.08, "error_rate": 0.02, "dive_depth": 340.0,
		"dive_margin": 120.0, "switch_interval": 1.2, "pump_at": 2.6,
		"boost_clear": 800.0, "boost_chance": 0.85, "prep_rabbit": true,
	},
]

const RUNS_PER_PROFILE := 4

var is_runner := false
var profile: Dictionary = {}
var run_index := 0
var rng := RandomNumberGenerator.new()
var race
var lines: Array[String] = []
var failures: Array[String] = []

# 感知与计划。
var known_groups := {}          # group name -> {kind,start,end,noticed_t,wrong}
var pending_notice: Array = []  # due times
var plan := {}
var last_sense_t := -1.0
var sense_period := 0.05

# 输入队列。
var applied := {"down": false, "up": false, "boost": false}
var desired := {"down": false, "up": false, "boost": false}
var pending_key := {}           # action -> due time
var pending_shift_due := -1.0
var pending_shift_target := ""
var shift_lock_until := -1.0
var shift_count := 0
var pump_count := 0
## 救援保持：切回兔子救人后必须真的握住一段时间，
## 否则下潜计划会在 0.25 s 冷却结束后立刻抢回乌龟，救人等于没救。
var rescue_hold_until := -1.0
var last_switch_t := 0.0
var boost_lane_end := -1.0
var boost_want := false
var last_rabbit_state := "RIDING"
var last_showtime := false

# 统计。
var stats := {}
var accident_events: Array = []
var zone_enter_t := {}
var zone_leave_t := {}
var zone_accidents := {}
var last_accident := "NONE"
var last_zone := 0
var last_x := 0.0
var last_oxygen := 8.0
var min_oxygen := 8.0
var oxygen_out := 0
var boost_seconds := 0.0
var jump_count := 0
var crouch_count := 0
var pickup_start := 0
var late_events: Array = []
# 第一次感知到的组。事故后重新观察同组不算“反应不足”。
var seen_once := {}
var notice_events := 0
var all_runs: Array = []
## 每轮重置的物理帧时钟，替代渲染帧累加的 race_time 做判断。
var sim_time := 0.0

var _best_backup := {}
var _log_file


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4DriverRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	print("STAGE4 DRIVER: RETIRED — two-route policy superseded by the five-class model; see header.")
	get_tree().quit(2)
	return
	_best_backup = _backup_file(GameManager.BEST_PATH)
	Engine.time_scale = 3.0
	Locale.language = "en"
	_log("STAGE4 DRIVER  engineering proxy (not human playtest)  time_scale=3.0")
	_log("profiles=%d runs_each=%d" % [PROFILES.size(), RUNS_PER_PROFILE])
	var only := _arg_after(OS.get_cmdline_user_args(), "--only", "")
	var runs := int(_arg_after(OS.get_cmdline_user_args(), "--runs",
		str(RUNS_PER_PROFILE)))
	all_runs.clear()
	for p in PROFILES:
		if only != "" and p["name"] != only:
			continue
		for i in mini(runs, RUNS_PER_PROFILE):
			await _run_trial(p, i)
	_restore_file(GameManager.BEST_PATH, _best_backup)
	_check(_read_file(GameManager.BEST_PATH) == str(_best_backup.get("text", "")),
		"best.json restored byte for byte")
	_write_outputs()
	Engine.time_scale = 1.0
	if failures.is_empty():
		print("STAGE4 DRIVER: PASS")
		get_tree().quit(0)
	else:
		print("STAGE4 DRIVER: FAIL")
		for item in failures:
			print("  - " + item)
		get_tree().quit(1)


func _run_trial(p: Dictionary, index: int) -> void:
	profile = p
	run_index = index
	rng.seed = hash(str(p["name"])) + index * 1000003
	_reset_state()
	_log("")
	_log("---- %s run %d  seed=%d ----" % [p["name"], index + 1, rng.seed])
	GameManager.start_race()
	await _frames(4)
	race = get_tree().current_scene
	if race == null or not race.scene_file_path.ends_with("race.tscn"):
		_check(false, "%s run %d race scene" % [p["name"], index + 1])
		return
	Engine.time_scale = 3.0
	var deadline := Time.get_ticks_msec() + 400000
	while is_instance_valid(race) and not GameManager.finished \
			and sim_time < DURATION_LIMIT \
			and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	_finish_trial(index)


func _reset_state() -> void:
	sim_time = 0.0
	known_groups.clear()
	pending_notice.clear()
	plan = {}
	last_sense_t = -1.0
	applied = {"down": false, "up": false, "boost": false}
	desired = {"down": false, "up": false, "boost": false}
	pending_key.clear()
	pending_shift_due = -1.0
	pending_shift_target = ""
	shift_lock_until = -1.0
	shift_count = 0
	pump_count = 0
	rescue_hold_until = -1.0
	last_switch_t = 0.0
	boost_lane_end = -1.0
	boost_want = false
	last_rabbit_state = "RIDING"
	last_showtime = false
	accident_events.clear()
	zone_enter_t.clear()
	zone_leave_t.clear()
	zone_accidents.clear()
	last_accident = "NONE"
	last_zone = 1
	zone_enter_t[1] = 0.0
	last_x = 400.0
	last_oxygen = 8.0
	min_oxygen = 8.0
	oxygen_out = 0
	boost_seconds = 0.0
	jump_count = 0
	crouch_count = 0
	pickup_start = GameManager.pickup_count
	late_events.clear()
	seen_once.clear()
	notice_events = 0
	stats = {
		"profile": profile.get("name", "?"),
		"run": run_index + 1,
		"seed": rng.seed,
	}


func _physics_process(delta: float) -> void:
	if race == null or not is_instance_valid(race):
		return
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	# 物理帧时钟：每个物理帧的 delta 已按 time_scale 缩放，逐帧累加就是
	# 确定的游戏时间。原先用 GameManager.race_time（渲染帧累加），同一份
	# 代码两次运行的判断时刻会差几帧，12 轮结果能从熟练 0 事故变成 5–7 起，
	# 这样的数据不能用来比较难度档位。
	sim_time += delta
	var now: float = sim_time
	_apply_due_inputs(now)
	_track(now)
	# 感知不因事故/表演暂停：玩家在恢复和 Showtime 里仍然看得见前方。
	_sense(now)
	_activate_notices(now)
	if GameManager.finished:
		return
	# 主动救援：切到乌龟、按住下潜，直到接住或失败（只用于工程回归，不是难度证明）。
	if GameManager.accident_state == "RABBIT_WATER" \
			and race.mount.state == "RESCUE_ACTIVE":
		_control_to("turtle", now)
		desired = {"down": true, "up": false, "boost": false}
		_sync_actions(now)
		plan = {}
		return
	if GameManager.accident_state != "NONE":
		desired = {"down": false, "up": false, "boost": false}
		_sync_actions(now)
		plan = {}
		return
	if race.showtime_active:
		# Showtime 强制乌龟控制；兔子是演出状态，不做普通计划。
		# 玩家仍能操作乌龟：岩石/横梁/长墙/低杆都要下潜（演出把兔子举高，
		# 低杆反而更危险），只有水下礁石要保持水面。
		desired = {"down": false, "up": false, "boost": false}
		var hazard := _nearest_known()
		if not hazard.is_empty() and _x_ahead(hazard) < 430.0:
			if hazard["kind"] == "UNDERWATER_REEF":
				desired["up"] = race.turtle.position.y > 302.0
			else:
				desired["down"] = race.turtle.position.y < float(profile["dive_depth"])
		_sync_actions(now)
		return
	_choose_plan(now)
	_execute_plan(now)
	_safety_pump(now)
	_sync_actions(now)


func _sense(now: float) -> void:
	# 只把 [x, x+lookahead] 里的组放进感知；不读取更远的未来。
	if now - last_sense_t < sense_period:
		return
	last_sense_t = now
	var x: float = race.turtle.position.x
	var look: float = profile["lookahead"]
	# 反应延迟期间同一组会一直留在前方；不要在每帧重复抽“错误决策”，
	# 否则 error_rate 会被叠加成 1-(1-p)^n。
	var queued := {}
	for n in pending_notice:
		queued[n["group"]] = true
	for g in LevelDataScript.groups():
		var key: String = g["group"]
		if known_groups.has(key) or queued.has(key):
			continue
		var start: float = _group_start(g)
		var end: float = _group_end(g)
		if end < x - 40.0:
			continue
		if start - x > look:
			continue
		var wrong := rng.randf() < float(profile["error_rate"])
		pending_notice.append({
			"due": now + float(profile["reaction"]),
			"group": key, "kind": g["kind"], "start": start, "end": end,
			"wrong": wrong, "seen_x": x,
		})
		notice_events += 1


func _activate_notices(now: float) -> void:
	var keep: Array = []
	for n in pending_notice:
		if float(n["due"]) <= now:
			var key: String = n["group"]
			var first_time := not seen_once.has(key)
			seen_once[key] = true
			known_groups[key] = {
				"kind": n["kind"], "start": n["start"], "end": n["end"],
				"wrong": n["wrong"], "noticed_t": now,
			}
			var speed: float = _speed()
			var ttc: float = maxf(0.0, (float(n["start"]) - race.turtle.position.x) / speed)
			var need: float = float(profile["input_delay"]) \
				+ maxf(0.0, float(profile["dive_depth"]) - race.turtle.position.y) / 180.0
			if first_time and ttc < need + 0.15:
				late_events.append({
					"group": key, "kind": n["kind"], "ttc": snappedf(ttc, 0.01),
					"need": snappedf(need, 0.01), "x": snappedf(race.turtle.position.x, 0.1),
					"zone": GameManager.zone,
				})
		else:
			keep.append(n)
	pending_notice = keep


func _choose_plan(now: float) -> void:
	if not plan.is_empty():
		var p_end: float = float(plan["end"])
		if race.turtle.position.x <= p_end + 70.0:
			return
		plan = {}
	var h := _nearest_known()
	if h.is_empty():
		return
	var mode := _correct_mode(h["kind"])
	if h["wrong"]:
		mode = "surface" if mode == "dive" else "dive"
	plan = {
		"group": h["group"], "kind": h["kind"], "start": h["start"],
		"end": h["end"], "mode": mode, "wrong": h["wrong"],
		"noticed_x": race.turtle.position.x,
	}
	_log("t=%6.1f x=%6.0f NOTICE %-11s %-15s -> %s%s" % [
		now, race.turtle.position.x, h["group"], h["kind"], mode.to_upper(),
		"  (WRONG)" if h["wrong"] else ""])
	_log("       plan ctrl=%s y=%.0f oxy=%.1f rabbit_daze=%.1f turtle_daze=%.1f" % [
		GameManager.current_control, race.turtle.position.y, GameManager.oxygen,
		race.rabbit.daze_time, race.turtle.daze_time])


func _nearest_known() -> Dictionary:
	var best := {}
	var best_start := 1.0e12
	var x: float = race.turtle.position.x
	for key in known_groups.keys():
		var g: Dictionary = known_groups[key]
		if float(g["end"]) < x - 20.0:
			continue
		if float(g["start"]) < best_start:
			best_start = float(g["start"])
			best = {"group": key, "kind": g["kind"], "start": g["start"],
				"end": g["end"], "wrong": g["wrong"]}
	return best


func _x_ahead(h: Dictionary) -> float:
	return float(h["start"]) - race.turtle.position.x


func _speed() -> float:
	return maxf(race.turtle.speed, 80.0)


func _correct_mode(kind: String) -> String:
	if kind in ["SURFACE_ROCK", "LOW_BEAM", "SURFACE_WALL"]:
		return "dive"
	return "surface"


func _execute_plan(now: float) -> void:
	desired["boost"] = false
	# 救兔子期间不抢回乌龟：任何计划（下潜/水面/空闲）都要让这次救援成立。
	if now < rescue_hold_until and GameManager.current_control == "rabbit":
		desired["down"] = false
		desired["up"] = false
		return
	if plan.is_empty():
		_idle_control(now)
		return
	var x: float = race.turtle.position.x
	var y: float = race.turtle.position.y
	var start: float = plan["start"]
	var end: float = plan["end"]
	var speed: float = _speed()
	var mode: String = plan["mode"]

	if mode == "dive":
		var trigger: float = speed * (float(profile["input_delay"]) + 0.35) \
			+ float(profile["dive_margin"])
		if x >= start - trigger:
			if not bool(plan.get("dbg", false)):
				plan["dbg"] = true
				_log("       diveSTART t=%.2f x=%.0f ctrl=%s y=%.0f down_applied=%s show=%s" % [
					now, x, GameManager.current_control, y, str(applied["down"]),
					str(race.showtime_active)])
			# 决定后 SHIFT 和下潜是同一批按键：都只等一次输入延迟。
			# 乌龟还没接管时按住“下”只在兔子身上判成趴下，不会跳。
			if now < rescue_hold_until:
				# 刚切回兔子救人：握住它把滑落收回来，别让计划立刻抢回乌龟。
				desired["down"] = false
				desired["up"] = false
				return
			_control_to("turtle", now)
			if x < end + 50.0:
				# 乌龟接管前先按住“下”（兔子只会趴下），接管后到深度就松开。
				desired["down"] = GameManager.current_control != "turtle" \
					or y < float(profile["dive_depth"])
				desired["up"] = false
			else:
				desired["down"] = false
				desired["up"] = GameManager.current_control == "turtle" and y > 302.0
		else:
			# 普通/熟练档会在下潜前回头摸一下兔子：把滑落进度清零再潜水，
			# 否则一条 500px 长墙 + 紧跟的组合障碍会让兔子在乌龟受控期间滑下去。
			if bool(profile.get("prep_rabbit", false)) \
					and x >= start - trigger - 420.0 \
					and race.rabbit.daze_time > 0.1 \
					and GameManager.current_control != "rabbit" \
					and not (GameManager.oxygen < 5.5 and y > 340.0):
				_control_to("rabbit", now)
				desired["down"] = false
				desired["up"] = false
				return
			_idle_control(now)
	else:
		# 保持水面：看到障碍后把乌龟放在水面；不跳、不潜。
		if x >= start - 350.0:
			_control_to("turtle", now)
			desired["down"] = false
			desired["up"] = GameManager.current_control == "turtle" and y > 302.0
		else:
			_idle_control(now)

	if x > end + 90.0:
		plan = {}
		desired["down"] = false
		desired["up"] = GameManager.current_control == "turtle" and y > 302.0


func _idle_control(now: float) -> void:
	# 开阔水域：没有障碍计划时按固定周期交替换人，避免任何一方长时间失控。
	desired["down"] = false
	# 只有乌龟受控时才按上浮；兔子受控时按上会被判成起跳。
	desired["up"] = GameManager.current_control == "turtle" \
		and race.turtle.position.y > 302.0
	# 氧气见底时优先回水面，而不是继续让乌龟下沉。
	if GameManager.oxygen < 5.5 and race.turtle.position.y > 340.0:
		_control_to("turtle", now)
		desired["up"] = true
		desired["boost"] = false
		return
	_update_boost_choice(now)
	if now - last_switch_t < float(profile["switch_interval"]):
		return
	if race.showtime_active or GameManager.accident_state != "NONE":
		return
	var target := "rabbit" if GameManager.current_control == "turtle" else "turtle"
	_control_to(target, now)
	last_switch_t = now


func _update_boost_choice(_now: float) -> void:
	var x: float = race.turtle.position.x
	var lane_end := -1.0
	for lane in LevelDataScript.boost_lanes():
		var r: Rect2 = lane
		if x >= r.position.x and x <= r.end.x:
			lane_end = r.end.x
			break
	if lane_end != boost_lane_end:
		boost_lane_end = lane_end
		boost_want = lane_end > 0.0 and rng.randf() < float(profile["boost_chance"])
	desired["boost"] = false
	if not boost_want or lane_end < 0.0:
		return
	if GameManager.current_control != "turtle" or GameManager.oxygen < 5.5:
		return
	if race.rabbit.daze_time > 2.2:
		return
	var h := _nearest_known()
	if not h.is_empty() and _x_ahead(h) < float(profile["boost_clear"]):
		return
	desired["boost"] = true


func _safety_pump(now: float) -> void:
	# 玩家能从 HUD 看到另一方在滑落/下沉。这里模拟“切回去救一下再切回来”。
	if race.showtime_active or GameManager.accident_state != "NONE":
		return
	if race.mount.state != "RIDING":
		return
	# 正在钻障碍时先通过：此时切回兔子会中断下潜，撞墙更糟。
	# 但已经潜到目标深度时切人不会再撞顶墙，可以顺手救兔子。
	if not plan.is_empty() and plan["mode"] == "dive" \
			and race.turtle.position.x < float(plan["end"]) + 20.0 \
			and race.turtle.position.y < float(profile["dive_depth"]) - 10.0:
		return
	var daze: float = 0.0
	var who := ""
	if GameManager.current_control == "turtle":
		daze = race.rabbit.daze_time
		who = "rabbit"
	else:
		daze = race.turtle.daze_time
		who = "turtle"
	if daze >= float(profile["pump_at"]):
		if GameManager.current_control != who:
			if pending_shift_due >= 0.0:
				return
			_control_to(who, now)
			if pending_shift_due < 0.0:
				return
			if who == "rabbit":
				desired["up"] = false
				# 恢复要 0.5 s 站稳 + 2.5/s 回落；至少握 0.9 s 才算救到。
				rescue_hold_until = now + 0.9
			pump_count += 1
			_log("t=%6.1f x=%6.0f PUMP -> %s  daze=%.1f" % [
				now, race.turtle.position.x, who, daze])


func _control_to(who: String, now: float) -> void:
	if GameManager.current_control == who:
		return
	if pending_shift_due >= 0.0:
		return
	# 同一次判断不要在事件生效前后重复下单（会来回切两次）。
	if now < shift_lock_until:
		return
	pending_shift_due = now + float(profile["input_delay"])
	pending_shift_target = who


func _sync_actions(now: float) -> void:
	for action in ["down", "up", "boost"]:
		if bool(desired[action]) == bool(applied[action]):
			continue
		if pending_key.has(action):
			continue
		pending_key[action] = now + float(profile["input_delay"])


func _apply_due_inputs(now: float) -> void:
	if pending_shift_due >= 0.0 and now >= pending_shift_due:
		var target := pending_shift_target
		pending_shift_due = -1.0
		pending_shift_target = ""
		var shift_ok: bool = GameManager.state == GameManager.GameState.RUNNING \
			and GameManager.accident_state == "NONE" and not race.showtime_active \
			and GameManager.current_control != target
		if shift_ok:
			_send_shift()
			shift_count += 1
			shift_lock_until = now + 0.25
			if target == "rabbit":
				# “上”在乌龟身上是上浮，在兔子身上是起跳。
				# 切人时若还压着上，会在接管那一帧误跳，污染接人统计。
				desired["up"] = false
				pending_key.erase("up")
				if bool(applied["up"]):
					Input.action_release("up")
					applied["up"] = false
		else:
			_log("t=%6.1f x=%6.0f SHIFT DROPPED -> %s  state=%s accident=%s show=%s ctrl=%s"
				% [now, race.turtle.position.x, target, GameManager.state,
					GameManager.accident_state, str(race.showtime_active),
					GameManager.current_control])
	var still := {}
	for action in pending_key.keys():
		if now >= float(pending_key[action]):
			if bool(desired[action]):
				Input.action_press(action)
			else:
				Input.action_release(action)
			applied[action] = bool(desired[action])
		else:
			still[action] = pending_key[action]
	pending_key = still


func _send_shift() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.physical_keycode = KEY_SHIFT
	event.pressed = true
	Input.parse_input_event(event)
	var up := InputEventKey.new()
	up.keycode = KEY_SHIFT
	up.physical_keycode = KEY_SHIFT
	up.pressed = false
	Input.parse_input_event(up)


func _track(now: float) -> void:
	var x: float = race.turtle.position.x
	var z: int = GameManager.zone
	if z != last_zone:
		if last_zone > 0:
			zone_leave_t[last_zone] = now
		zone_enter_t[z] = now
		last_zone = z
	if GameManager.accident_state != last_accident:
		if GameManager.accident_state != "NONE":
			var ev := {
				"t": snappedf(now, 0.01), "x": snappedf(x, 0.1),
				"zone": z, "reason": GameManager.accident_state,
				"control": GameManager.current_control,
				"turtle_y": snappedf(race.turtle.position.y, 0.1),
				"oxygen": snappedf(GameManager.oxygen, 0.01),
				"showtime": last_showtime,
				"nearest_group": _nearest_group_at(x),
			}
			accident_events.append(ev)
			zone_accidents[z] = int(zone_accidents.get(z, 0)) + 1
			if GameManager.accident_state == "OXYGEN_OUT":
				oxygen_out += 1
			# 撞过一次后重新观察这一组：模拟玩家记住“刚才那样不行”，
			# 重新做一次判断，而不是永远重复同一个错误。
			var ng := _nearest_group_at(x)
			if ng != "":
				known_groups.erase(ng)
			_log("t=%6.1f x=%6.0f ACCIDENT %-12s zone=%d control=%s y=%.0f oxy=%.1f" % [
				now, x, GameManager.accident_state, z,
				GameManager.current_control, race.turtle.position.y,
				GameManager.oxygen])
		last_accident = GameManager.accident_state
	min_oxygen = minf(min_oxygen, GameManager.oxygen)
	last_oxygen = GameManager.oxygen
	if GameManager.current_control == "turtle" and Input.is_action_pressed("boost") \
			and GameManager.turtle_speed > 300.0:
		boost_seconds += 0.05
	if race.rabbit.state == "JUMPING" or race.rabbit.state == "FALLING":
		jump_count += 1
	if race.rabbit.state == "CROUCHING":
		crouch_count += 1
	last_x = x
	last_showtime = race.showtime_active


func _nearest_group_at(x: float) -> String:
	var best := ""
	var best_d := 1.0e12
	for g in LevelDataScript.groups():
		var s: float = _group_start(g)
		var e: float = _group_end(g)
		if x >= s - 160.0 and x <= e + 60.0:
			var d := absf(x - s) if x < s else 0.0
			if d < best_d:
				best_d = d
				best = g["group"]
	return best


func _finish_trial(index: int) -> void:
	desired = {"down": false, "up": false, "boost": false}
	_sync_actions(sim_time)
	Input.action_release("down")
	Input.action_release("up")
	Input.action_release("boost")
	var finished: bool = GameManager.finished
	var ft: float = sim_time
	zone_leave_t[last_zone] = ft
	var zones := {}
	for z in [1, 2, 3]:
		var start_t: float = zone_enter_t.get(z, -1.0)
		var end_t: float = zone_leave_t.get(z, -1.0)
		if start_t >= 0.0 and end_t >= start_t:
			zones[str(z)] = snappedf(end_t - start_t, 0.01)
	stats["finished"] = finished
	stats["timed_out"] = not finished and sim_time >= DURATION_LIMIT
	stats["finish_time"] = snappedf(ft, 0.01)
	stats["score"] = GameManager.total_score
	stats["grade"] = GameManager.grade
	stats["passed"] = race.passed_count() if is_instance_valid(race) else 0
	stats["accidents"] = GameManager.accident_count
	stats["accident_events"] = accident_events.duplicate(true)
	stats["accidents_by_zone"] = zone_accidents.duplicate(true)
	stats["zones_seconds"] = zones
	stats["shifts"] = shift_count
	stats["pumps"] = pump_count
	stats["showtime"] = GameManager.showtime_count
	stats["streak"] = GameManager.best_streak
	stats["min_oxygen"] = snappedf(min_oxygen, 0.01)
	stats["oxygen_out"] = oxygen_out
	stats["boost_seconds"] = snappedf(boost_seconds, 0.01)
	stats["pickups"] = GameManager.pickup_count - pickup_start
	stats["late_events"] = late_events.duplicate(true)
	stats["notices"] = notice_events
	stats["casualties"] = GameManager.rabbit_casualties
	stats["engine_failures"] = GameManager.turtle_failures
	_log("FINISH %-9s run %d  t=%.1f  accidents=%d  shifts=%d  show=%d  oxy_min=%.1f  passed=%d  grade=%s" % [
		profile["name"], index + 1, ft, GameManager.accident_count, shift_count,
		GameManager.showtime_count, min_oxygen, stats["passed"], GameManager.grade])
	all_runs.append(stats.duplicate(true))
	_check(finished or stats["timed_out"],
		"%s run %d ended (finished=%s timed_out=%s)" % [
			profile["name"], index + 1, str(finished), str(stats["timed_out"])])
	if not is_instance_valid(race):
		return


func _write_outputs() -> void:
	var payload := {
		"note": "engineering proxy, not human playtest",
		"profiles": PROFILES,
		"runs_per_profile": RUNS_PER_PROFILE,
		"summary": _summarize(),
		"runs": all_runs,
	}
	var path := ProjectSettings.globalize_path(OUT_JSON)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(OUT_JSON, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "  "))
		file.close()
	var log_path := ProjectSettings.globalize_path(OUT_LOG)
	var lf := FileAccess.open(OUT_LOG, FileAccess.WRITE)
	if lf != null:
		for line in lines:
			lf.store_line(line)
		lf.close()
	print("WROTE ", path)
	print("WROTE ", log_path)


func _summarize() -> Dictionary:
	var out := {}
	for p in PROFILES:
		var name := String(p["name"])
		var sample: Array = []
		for r in all_runs:
			if String(r.get("profile", "")) == name:
				sample.append(r)
		if sample.is_empty():
			continue
		var acc_sum := 0
		var acc_min := 9999
		var acc_max := -1
		var finish_n := 0
		var timeout_n := 0
		var shift_sum := 0
		var show_sum := 0
		var oxy_min := 99.0
		var oxygen_out_n := 0
		var pickup_n := 0
		var late_n := 0
		var boost_sum := 0.0
		var by_zone := {}
		var zone_secs := {}
		var finish_times: Array = []
		for r in sample:
			var a := int(r.get("accidents", 0))
			acc_sum += a
			acc_min = mini(acc_min, a)
			acc_max = maxi(acc_max, a)
			if bool(r.get("finished", false)):
				finish_n += 1
				finish_times.append(float(r.get("finish_time", 0.0)))
			if bool(r.get("timed_out", false)):
				timeout_n += 1
			shift_sum += int(r.get("shifts", 0))
			show_sum += int(r.get("showtime", 0))
			oxy_min = minf(oxy_min, float(r.get("min_oxygen", 99.0)))
			oxygen_out_n += int(r.get("oxygen_out", 0))
			pickup_n += int(r.get("pickups", 0))
			late_n += int(r.get("late_events", []).size())
			boost_sum += float(r.get("boost_seconds", 0.0))
			for z in r.get("accidents_by_zone", {}).keys():
				by_zone[z] = int(by_zone.get(z, 0)) + int(r["accidents_by_zone"][z])
			for z in r.get("zones_seconds", {}).keys():
				zone_secs[z] = float(zone_secs.get(z, 0.0)) + float(r["zones_seconds"][z])
		var n := float(sample.size())
		var avg_ft := 0.0
		for t in finish_times:
			avg_ft += float(t)
		avg_ft = avg_ft / maxf(1.0, float(finish_times.size()))
		for z in zone_secs.keys():
			zone_secs[z] = snappedf(float(zone_secs[z]) / n, 0.01)
		out[name] = {
			"runs": sample.size(),
			"clear_rate": snappedf(float(finish_n) / n, 0.01),
			"timeouts": timeout_n,
			"avg_finish_time": snappedf(avg_ft, 0.01),
			"accidents_avg": snappedf(float(acc_sum) / n, 0.01),
			"accidents_min": acc_min,
			"accidents_max": acc_max,
			"accidents_by_zone": by_zone,
			"avg_zone_seconds": zone_secs,
			"shifts_avg": snappedf(float(shift_sum) / n, 0.1),
			"showtime_avg": snappedf(float(show_sum) / n, 0.1),
			"min_oxygen_any": snappedf(oxy_min, 0.01),
			"oxygen_out_total": oxygen_out_n,
			"pickups_total": pickup_n,
			"late_events_total": late_n,
			"boost_seconds_total": snappedf(boost_sum, 0.01),
		}
	return out


func _group_start(g: Dictionary) -> float:
	var s := 1.0e12
	for r in g["rects"]:
		s = minf(s, (r as Rect2).position.x)
	return s


func _group_end(g: Dictionary) -> float:
	var e := 0.0
	for r in g["rects"]:
		e = maxf(e, (r as Rect2).end.x)
	return e


func _arg_after(args: PackedStringArray, flag: String, fallback: String) -> String:
	var i := args.find(flag)
	if i >= 0 and i + 1 < args.size() and not args[i + 1].begins_with("--"):
		return args[i + 1]
	return fallback


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	_log("FAIL " + message)


func _log(text: String) -> void:
	lines.append(text)
	print("  " + text)


func _read_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func _backup_file(path: String) -> Dictionary:
	return {"exists": FileAccess.file_exists(path), "text": _read_file(path)}


func _restore_file(path: String, info: Dictionary) -> void:
	if info.get("exists", false):
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(info["text"])
			file.close()
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
