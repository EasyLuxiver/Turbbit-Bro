extends Node
## CORE-FEEL-07 P1-E 验收：节奏差异化。
##
## 赛道被 LevelData.RHYTHM_SEGMENTS 切成连续 10 段，每段一种节奏：
##   A 单点 / B 连招 / C 节奏变化 / D 持续环境。
## 本探针做两件事：
##   1) 从真实关卡数据算每段的空跑时长、单点数、连招数、持续状态时长、
##      高压长度、恢复长度、重复连招数（口径写在 JSON 的 definitions 里）；
##   2) 在正式关卡里逐段真实跑两遍：安全路线（提前量小、逐组处理、按完就松）
##      与配合路线（提前换人、下潜连招不断键）。两条路线都必须无碰撞跑过该段。
##
## 这是“路段可完成”的工程证明，不是真人试玩；按键是引擎内输入代理。
##
## 运行：
##   Godot_v4.7-stable_win64_console.exe --headless --path . \
##       res://scenes/stage7_rhythm_segments.tscn
## 输出：docs/reports/longrun/core-feel-07-rhythm.json

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/core-feel-07-rhythm.json"
const STEP_HZ := 60.0
const VISION_PX := 1100.0
const HOLD_MARGIN_PX := 260.0
const SINGLE_GAP_S := 3.5
const TIME_LIMIT_S := 120.0

var is_runner := false
var race: Node = null
var sim := 0.0
var step_hz := STEP_HZ
var full_mode := false
var tap_frames := 0
var failures: Array[String] = []
var data := {}
var rock_debug := {}


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage7RhythmRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	# P2 帧率一致性：--hz=30 / --hz=120 用同一套驱动在别的物理步长下重跑。
	# 每帧仍然推进 1/step_hz 的游戏秒，所以两条路线的“提前量、按住时长”
	# 换算出来是同一段时间，不随帧率变。
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):
			step_hz = maxf(float(arg.substr(5)), 1.0)
		elif arg == "--full":
			full_mode = true
	Engine.time_scale = 10.0
	Engine.physics_ticks_per_second = int(step_hz * Engine.time_scale)
	await get_tree().process_frame
	await _run()


func _run() -> void:
	GameManager.start_race()
	for i in 4:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null:
		push_error("RHYTHM: no race scene")
		_finish(1)
		return
	race.opening_active = false
	race.test_disable_hazards = false
	race.test_no_finish = true
	# 食物不在本探针的证明范围（P1-C 已单独验过）；清掉加速带，避免吃到后
	# 速度变化把“路段能否完成”变成另一种结论。
	race.load_level(LevelData.groups(), [])
	race.boost_lanes.clear()
	await get_tree().physics_frame

	if full_mode:
		await _run_full()
		return

	data["definitions"] = {
		"empty_run_s": "上一组末端 -> 本段第一组起点的空档 / 该区基速",
		"recovery_s": "本段最后一组末端 -> 下一段第一组起点的空档 / 该区基速",
		"single_points": "前后空档都 >= %.1f s 的孤立组数" % SINGLE_GAP_S,
		"combos": "相邻两组间隔 <= %.1f s 的连招对数" % LevelData.COMBO_GAP_S,
		"sustained_s": "同一状态（趴低/下潜/跃起）连续要维持的最长时间，"
			+ "按 组宽 + %.0f px 进出余量 计算" % HOLD_MARGIN_PX,
		"pressure_s": "第一组进入 HUD 预警（-430 px）到最后一组动作结束（+120 px）的时长",
		"repeated_combos": "段内重复出现的同种类连招对（同一对出现第 2 次起计数）",
		"routes": "safe=提前 260 px 起手、逐组处理；coop=提前 400 px 换人起手、下潜连招不断键。",
	}
	data["segments"] = []
	data["routes"] = {}

	var all_groups: Array = LevelData.groups()
	var index_by_name := {}
	for i in all_groups.size():
		index_by_name[String(all_groups[i]["group"])] = i
	var segs: Array = LevelData.rhythm_segments()
	var types := {}
	for seg in segs:
		var m := _metrics_for(seg, all_groups, index_by_name)
		var rows := {}
		for route in ["safe", "coop"]:
			rows[route] = await _run_route(seg, route)
		var entry := {
			"id": seg["id"], "type": seg["type"], "name": seg["name"],
			"name_zh": seg["name_zh"], "zone": seg["zone"],
			"group_names": seg["group_names"], "metrics": m, "routes": rows,
		}
		data["segments"].append(entry)
		types[String(seg["type"])] = int(types.get(String(seg["type"]), 0)) + 1
		_print_segment(entry)

	data["type_counts"] = types
	_check_types(types)
	_check_route_completion()
	_write()
	print("CORE-FEEL-07 P1-E: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	_finish(0 if failures.is_empty() else 1)


## P2：正式关卡全程真跑。不按段传送，从起点一次跑到终点，
## 55 组按顺序处理，段与段之间的衔接也进入判定。
## 运行：... -- --full
func _run_full() -> void:
	var all_groups: Array = LevelData.groups()
	var seg := {
		"id": "FULL", "type": "FULL", "name": "full run", "name_zh": "全程",
		"zone": 1, "start": LevelData.RACE_START_X,
		"end": LevelData.WORLD_END - 240.0, "groups": all_groups,
	}
	data["definitions"] = {
		"mode": "full",
		"world_start": LevelData.RACE_START_X,
		"world_end": LevelData.WORLD_END,
		"routes": "safe=提前 260 px 起手；coop=提前 400 px 起手、下潜连招不断键。",
	}
	data["full"] = {}
	print("FULL RUN groups=%d start=%.0f end=%.0f" % [
		all_groups.size(), float(LevelData.RACE_START_X), float(LevelData.WORLD_END)])
	for route in ["safe", "coop"]:
		var r: Dictionary = await _run_route(seg, route, 480.0, 34000)
		data["full"][route] = r
		var reached: bool = float(r["ended_x"]) >= LevelData.WORLD_END - 300.0
		var detail := "ended=%.1f hits=%s acc=%d mount=%s sim=%.1fs" % [
			float(r["ended_x"]), str(r["hits"]), int(r["accidents"]),
			String(r["mount_state"]), float(r["sim_s"])]
		print("FULL %s %s" % [route, detail])
		_expect("P2 全程 %s 从起点跑到终点且无碰撞/无事故" % route,
			bool(r["passed"]) and reached, detail)
	# 失败边界：同一条正式关卡、同一套判定，完全不操作必须失败。
	# 不靠缩小碰撞体或特判，靠把“正向能过”与“不操作过不去”放在同一个跑法里对照。
	var rn: Dictionary = await _run_route(seg, "none", 480.0, 34000)
	data["full"]["none"] = rn
	var none_detail := "ended=%.1f hits=%s acc=%d mount=%s" % [
		float(rn["ended_x"]), str(rn["hits"]), int(rn["accidents"]),
		String(rn["mount_state"])]
	print("FULL none %s" % none_detail)
	_expect("P2 全程不操作必须失败（有命中或事故）",
		not bool(rn["passed"]) and (int(rn["accidents"]) > 0
			or not (rn["hits"] as Array).is_empty()), none_detail)
	_write()
	print("CORE-FEEL-07 P2 FULL RUN: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	_finish(0 if failures.is_empty() else 1)


# ---------------- 1) 分段指标 ----------------
func _metrics_for(seg: Dictionary, all_groups: Array,
		index_by_name: Dictionary) -> Dictionary:
	var gs: Array = seg["groups"]
	var v: float = float(seg["speed"])
	var gaps_s: Array = []
	for i in range(1, gs.size()):
		gaps_s.append((LevelData.group_start(gs[i])
			- LevelData.group_end(gs[i - 1])) / v)
	var first_index: int = int(index_by_name[String(gs[0]["group"])])
	var last_index: int = int(index_by_name[String(gs[gs.size() - 1]["group"])])
	var prev_end := LevelData.RACE_START_X
	if first_index > 0:
		prev_end = LevelData.group_end(all_groups[first_index - 1])
	var next_start := LevelData.WORLD_END
	if last_index < all_groups.size() - 1:
		next_start = LevelData.group_start(all_groups[last_index + 1])
	var empty_before := (LevelData.group_start(gs[0]) - prev_end) / v
	var recovery := (next_start - LevelData.group_end(gs[gs.size() - 1])) / v

	var singles := 0
	for i in gs.size():
		var before: float = empty_before if i == 0 else float(gaps_s[i - 1])
		var after: float = recovery if i == gs.size() - 1 else float(gaps_s[i])
		if before >= SINGLE_GAP_S and after >= SINGLE_GAP_S:
			singles += 1
	var combos := 0
	var pair_count := {}
	for i in gaps_s.size():
		if float(gaps_s[i]) <= LevelData.COMBO_GAP_S:
			combos += 1
			var key := "%s>%s" % [String(gs[i]["kind"]), String(gs[i + 1]["kind"])]
			pair_count[key] = int(pair_count.get(key, 0)) + 1
	var repeated := 0
	for k in pair_count:
		if int(pair_count[k]) > 1:
			repeated += int(pair_count[k]) - 1

	var sustained := 0.0
	var run_state := ""
	var run_start := 0.0
	var run_end := 0.0
	for g in gs:
		var state := _hold_state(String(g["kind"]))
		var gs_x := LevelData.group_start(g)
		var ge_x := LevelData.group_end(g)
		if state == "":
			if run_state != "":
				sustained = maxf(sustained,
					(run_end - run_start + HOLD_MARGIN_PX) / v)
				run_state = ""
			continue
		if state == run_state:
			run_end = ge_x
		else:
			if run_state != "":
				sustained = maxf(sustained,
					(run_end - run_start + HOLD_MARGIN_PX) / v)
			run_state = state
			run_start = gs_x
			run_end = ge_x
	if run_state != "":
		sustained = maxf(sustained, (run_end - run_start + HOLD_MARGIN_PX) / v)

	var pressure := (LevelData.group_end(gs[gs.size() - 1]) + 120.0
		- (LevelData.group_start(gs[0]) - 430.0)) / v
	var active := (LevelData.group_end(gs[gs.size() - 1])
		- LevelData.group_start(gs[0])) / v
	var gap_min := 99.0
	var gap_max := 0.0
	for gap in gaps_s:
		gap_min = minf(gap_min, float(gap))
		gap_max = maxf(gap_max, float(gap))
	return {
		"groups": gs.size(),
		"empty_run_s": snappedf(empty_before, 0.01),
		"recovery_s": snappedf(recovery, 0.01),
		"gap_min_s": snappedf(gap_min, 0.01) if not gaps_s.is_empty() else 0.0,
		"gap_max_s": snappedf(gap_max, 0.01),
		"gap_ratio": snappedf(gap_max / maxf(gap_min, 0.01), 0.01),
		"single_points": singles,
		"combos": combos,
		"repeated_combos": repeated,
		"sustained_s": snappedf(sustained, 0.01),
		"pressure_s": snappedf(pressure, 0.01),
		"active_len_s": snappedf(active, 0.01),
	}


func _hold_state(kind: String) -> String:
	match kind:
		"LOW_BEAM", "LOW_BIRD":
			return "crouch"
		"DIVE_GATE":
			return "dive"
		"SHARK":
			return "leap"
	return ""


# ---------------- 2) 真实路线 ----------------

func _run_route(seg: Dictionary, route: String,
		time_limit: float = TIME_LIMIT_S, step_limit: int = 24000) -> Dictionary:
	var zone: Dictionary = LevelData.zone_by_id(int(seg["zone"]))
	_reset(maxf(float(seg["start"]) - 280.0, 0.0), zone)
	var coop := route == "coop"
	var none := route == "none"
	var lead := 400.0 if coop else 260.0
	var exit := 150.0 if coop else 40.0
	var gs: Array = seg["groups"]
	var gi := 0
	var gf := {"jump": false, "shift": false, "kick": false}
	var acc0: int = GameManager.accident_count
	var t0 := sim
	var steps := 0
	var seen_hits := {}
	var first_hit := {}
	var trace: Array = []
	var landing: Array = []
	var cur_kind := ""
	var last_mount := String(race.mount.state)
	var last_rstate := String(race.rabbit.state)
	while sim - t0 < time_limit and steps < step_limit:
		var x: float = race.turtle.position.x
		if x > float(seg["end"]) + 220.0:
			break
		if gi < gs.size() and x > LevelData.group_end(gs[gi]) + 80.0:
			gi += 1
			gf = {"jump": false, "shift": false, "kick": false}
			# 配合路线：下潜连招不断键——浮木之后紧跟礁拱时，↓ 一直按着。
			var chain_dive := coop and gi < gs.size() \
				and String(gs[gi]["kind"]) == "DIVE_GATE"
			if not chain_dive:
				_release("down")
			_release("up")
		if gi >= gs.size() or none:
			_release_all()
		else:
			cur_kind = String(gs[gi]["kind"])
			_drive_group(gs[gi], x, lead, exit, coop, gf)
		_tick_tap()
		await get_tree().physics_frame
		sim += 1.0 / step_hz
		steps += 1
		var mst := String(race.mount.state)
		var rst := String(race.rabbit.state)
		if mst != last_mount or rst != last_rstate:
			trace.append({
				"x": snappedf(race.turtle.position.x, 0.1),
				"mount": mst, "rabbit": rst,
				"turtle_y": snappedf(race.turtle.position.y, 0.1),
				"rabbit_y": snappedf(race.rabbit.position.y, 0.1),
				"vy": snappedf(race.rabbit.velocity.y, 0.1),
				"rvx": snappedf(race.rabbit.velocity.x, 0.1),
				"vt": snappedf(sim - t0, 0.01),
				"speed": snappedf(race.turtle.speed, 0.1),
				"jump": bool(gf.get("jump", false)),
				"rock": rock_debug.duplicate(),
			})
			last_mount = mst
			last_rstate = rst
		if cur_kind == "FLOATING_LOG" and mst == "AIRBORNE" \
				and race.rabbit.velocity.y >= 0.0:
			var mp: Vector2 = race.turtle.get_mount_point()
			var ldy: float = race.rabbit.position.y - mp.y
			var ldx: float = absf(race.rabbit.position.x - mp.x)
			if ldx <= 170.0 and ldy >= -280.0:
				landing.append({
					"x": snappedf(race.turtle.position.x, 0.1),
					"dy": snappedf(ldy, 0.1), "dx": snappedf(ldx, 0.1),
					"ry": snappedf(race.rabbit.position.y, 0.1),
					"mpy": snappedf(mp.y, 0.1),
					"ty": snappedf(race.turtle.position.y, 0.1),
					"vy": snappedf(race.rabbit.velocity.y, 0.1),
					"ctl": GameManager.current_control,
					"surf": race.turtle.is_at_surface(),
					"ris": race.turtle.is_rising(),
					"dive": race.turtle.diving,
					"caught": not race.turtle.leap_active \
						and race.mount.can_pickup(race.rabbit.position,
							race.rabbit.velocity.y, mp,
							race.turtle.is_at_surface(), race.turtle.is_rising()),
				})
		for g in gs:
			var gn := String(g["group"])
			if race.hit_groups.has(gn) and not seen_hits.has(gn):
				seen_hits[gn] = true
				if first_hit.is_empty():
					first_hit = _hit_snapshot(g)
					trace.append({"hit": gn, "x": snappedf(x, 0.1)})
	var hit_names: Array = []
	for g in gs:
		if race.hit_groups.has(String(g["group"])):
			hit_names.append(String(g["group"]))
	var ended_x: float = race.turtle.position.x
	var acc_n: int = GameManager.accident_count - acc0
	# 完成 = 跑过段尾、没有撞到本段任何障碍，且中途没有掉进水里等事故。
	var passed: bool = ended_x > float(seg["end"]) + 200.0 \
		and hit_names.is_empty() and acc_n == 0
	var entry := {
		"passed": passed,
		"ended_x": snappedf(ended_x, 0.1),
		"hits": hit_names,
		"first_hit": first_hit,
		"accidents": acc_n,
		"mount_state": String(race.mount.state),
		"sim_s": snappedf(sim - t0, 0.01),
		"steps": steps,
		"trace": trace,
		"landing": landing,
	}
	_release_all()
	return entry


func _hit_snapshot(g: Dictionary) -> Dictionary:
	var rabbit_rect: Rect2 = race.rabbit.get_body_rect()
	var turtle_rect: Rect2 = race.turtle.get_body_rect()
	var by: Array = []
	for r in g["rects"]:
		var rect: Rect2 = r
		if rect.intersects(rabbit_rect):
			by.append("rabbit")
		if rect.intersects(turtle_rect):
			by.append("turtle")
	return {
		"group": String(g["group"]), "kind": String(g["kind"]),
		"x": snappedf(race.turtle.position.x, 0.1),
		"control": GameManager.current_control,
		"mount": String(race.mount.state),
		"rabbit_state": String(race.rabbit.state),
		"turtle_y": snappedf(race.turtle.position.y, 0.1),
		"rabbit_rect": [snappedf(rabbit_rect.position.x, 0.1),
			snappedf(rabbit_rect.position.y, 0.1),
			snappedf(rabbit_rect.size.x, 0.1), snappedf(rabbit_rect.size.y, 0.1)],
		"turtle_rect": [snappedf(turtle_rect.position.x, 0.1),
			snappedf(turtle_rect.position.y, 0.1),
			snappedf(turtle_rect.size.x, 0.1), snappedf(turtle_rect.size.y, 0.1)],
		"down": Input.is_action_pressed("down"),
		"up": Input.is_action_pressed("up"),
		"by": by,
		"off_now": snappedf(race.hazard_offset(g).y, 0.1),
		"pred": rock_debug.duplicate(),
	}


func _drive_group(g: Dictionary, x: float, lead: float, exit: float,
		coop: bool, gf: Dictionary) -> void:
	var kind := String(g["kind"])
	var start := LevelData.group_start(g)
	var end := LevelData.group_end(g)
	var v: float = float(race.current_zone.get("base_speed", 220.0))
	match kind:
		"LOW_BEAM", "LOW_BIRD":
			_want("rabbit")
			if x >= start - lead:
				_hold("down")
			if x > end + exit:
				_release("down")
		"SURFACE_ROCK":
			# 潮汐岩会上下移动 52 px，固定的起跳距离在浪峰相位会把兔子送到岩沿上。
			# 改成每帧预测“现在起跳，整段过岩是否都在岩顶之上”：
			# 兔子矩形 32 宽、壳上兔身 252～300，岩矩形 [254+off, 296+off]。
			# 只要有一点机身低于岩顶就不跳；能跳就跳，不能就继续骑。
			_want("rabbit")
			if not bool(gf["jump"]) and x < end + 30.0:
				var plan := _rock_plan(g, x)
				if plan == "jump":
					_tap("up")
					if String(race.mount.state) == "AIRBORNE":
						gf["jump"] = true
			if x > end + exit:
				_release("up")
		"DIVE_GATE":
			_want("turtle")
			if x >= start - lead:
				_hold("down")
			if x > end + exit:
				_release("down")
		"SHARK":
			_want("turtle")
			if x >= start - 0.6 * v and x < end + 30.0 and not bool(gf["jump"]):
				_tap("up")
				if race.turtle.leap_active:
					gf["jump"] = true
			if x > end + exit:
				_release("up")
		"FLOATING_LOG":
			if not bool(gf["jump"]):
				_want("rabbit")
				if x >= start - (0.7 * v - 2.0):
					_tap("up")
					if String(race.mount.state) == "AIRBORNE":
						gf["jump"] = true
			elif not bool(gf["shift"]):
				_want("turtle")
				_hold("down")
				gf["shift"] = true
			elif x > end + 40.0:
				# 浮木后的下潜只保持到木尾 +40 px：兔子还要落回壳上，
				# 壳必须浮回水面才能接（coop 的 exit=150 会让壳停在 483，
				# 落壳窗口整个错过——B2 coop 实测掉水）。后面的潜水门会自己再按。
				_release("down")
		"HIGH_WALL":
			if not bool(gf["jump"]):
				_want("turtle")
				if x >= start - 0.8 * v:
					_tap("up")
					if race.turtle.leap_active:
						gf["jump"] = true
			elif not bool(gf["kick"]):
				if x >= start - 0.3 * v:
					_want("rabbit")
					_tap("up")
					gf["kick"] = true
				else:
					_want("turtle")


## 潮汐岩的过法：先算“现在起跳，兔子在整段过岩期间是否都在岩顶之上”。
## 岩的上下位移用 hazard_motion_state 给出的 sin/cos 沿时间外推，
## 所以不再依赖固定 lead；宽岩、窄岩、静止/潮汐岩都走同一套判断。
## 坐标用运行时世界坐标：岩顶 254、岩底 296（level_data 的 220/262 + WORLD_Y_SHIFT 34），
## 壳上兔身 252～300，兔矩形宽 32（中心 ±16）。
func _rock_plan(g: Dictionary, x: float) -> String:
	var start := LevelData.group_start(g)
	var end := LevelData.group_end(g)
	# 空中水平速度不是“起跳瞬间的 turtle.speed + 15”：tick_air 在受控时
	# 立刻把 +15 收回到 air_base（=起跳时的 turtle.speed），而神游还在继续减速。
	# 实测按 turtle.speed 算，并在飞行 1.2 s 里再留 8 px/s 的减速余量。
	var va: float = maxf(float(race.turtle.speed) - 8.0, 1.0)
	var st: Dictionary = race.hazard_motion_state(g)
	if st.is_empty():
		st = {"period": 1.0, "amp": 0.0, "bias": 0.0, "sin": 0.0, "cos": 1.0}
	var t_near: float = (start - 16.0 - x) / va
	var t_far: float = (end + 16.0 - x) / va
	if t_far <= 0.0:
		return "ride"
	var v0: float = 630.0 * float(race.rabbit.jump_boost)
	# 离散积分每帧先生效位移再加回重力，比连续解低几像素；留 12 px 余量。
	const CLEAR_MARGIN := 12.0
	# 兔子下落到离壳 60 px 就进接人窗口、会被抬升路径拉回壳上。
	# 如果这个窗口在岩沿之前打开，抬升路径就会横穿岩沿（实测差 4 px）。
	# 所以最后一帧还要求兔子仍高过接人窗口 18 px，保证抬升发生在岩沿之后。
	const CATCH_CLEAR := 78.0
	var ride_ok := true
	var jump_ok := true
	var off_far := 0.0
	var h_far := 0.0
	for i in 9:
		var t: float = lerpf(maxf(t_near, 0.0), t_far, float(i) / 8.0)
		var off: float = _motion_offset(st, t)
		var top := 254.0 + off
		var bottom := 296.0 + off
		# 骑乘：岩不能穿过兔身 252～300。
		if bottom > 252.0 and top < 300.0:
			ride_ok = false
		# 起跳：这一时刻兔子下沿要在岩顶之上。
		var h: float = v0 * t - 525.0 * t * t
		if i == 8:
			off_far = off
			h_far = h
		var cap: float = top - CLEAR_MARGIN
		if i == 8:
			cap = minf(cap, 300.0 - CATCH_CLEAR)
		if 300.0 - h > cap:
			jump_ok = false
	rock_debug = {"x": snappedf(x, 0.1), "speed": snappedf(va + 8.0, 0.1),
		"t_far": snappedf(t_far, 0.01), "off_far": snappedf(off_far, 0.1),
		"h_far": snappedf(h_far, 0.1), "ride": ride_ok, "jump": jump_ok}
	if ride_ok:
		return "ride"
	return "jump" if jump_ok else "wait"


func _motion_offset(st: Dictionary, dt: float) -> float:
	var period: float = maxf(float(st.get("period", 1.0)), 0.2)
	var w := TAU * dt / period
	var s := float(st.get("sin", 0.0)) * cos(w) + float(st.get("cos", 1.0)) * sin(w)
	return float(st.get("bias", 0.0)) + float(st.get("amp", 0.0)) * s


func _want(who: String) -> void:	if GameManager.current_control != who:
		GameManager.set_control(who)


func _hold(action: String) -> void:
	if not Input.is_action_pressed(action):
		Input.action_press(action)


func _release(action: String) -> void:
	if Input.is_action_pressed(action):
		Input.action_release(action)


func _tap(action: String) -> void:
	if not Input.is_action_pressed(action):
		Input.action_press(action)
		tap_frames = 2


func _tick_tap() -> void:
	if tap_frames > 0:
		tap_frames -= 1
		if tap_frames == 0:
			_release("up")


func _release_all() -> void:
	Input.action_release("up")
	Input.action_release("down")
	Input.action_release("shift")
	tap_frames = 0


func _reset(x: float, zone: Dictionary) -> void:
	_release_all()
	GameManager.accident_state = "NONE"
	GameManager.oxygen = Tuning.OXYGEN_MAX
	GameManager.showtime_active = false
	GameManager.current_control = "turtle"
	GameManager.has_shifted = true
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
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.group_actions.clear()
	race.reset_brains()
	var speed: float = float(zone["base_speed"])
	race.current_zone = zone
	race.turtle.reset(Vector2(x, Tuning.NEUTRAL_DEPTH))
	race.turtle.speed = speed
	race.turtle.base_speed = speed
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	# 上一段结束时按过的 ↑ 可能还在 120 ms 缓冲里；不清理的话，
	# 新一段第一帧就会替玩家跳一次（实测 B2 coop 开局白白落水一次）。
	race._buf_action = ""
	race._up_was_pressed = false
	sim = 0.0


# ---------------- 3) 判定 ----------------

func _check_types(types: Dictionary) -> void:
	for t in ["A", "B", "C", "D"]:
		_expect("P1-E 至少有 1 段 %s 型节奏" % t,
			int(types.get(t, 0)) >= 1, "counts=%s" % str(types))
	var a_ok := false
	var b_ok := false
	var c_ok := false
	var d_ok := false
	# 指标在 data["segments"]（LevelData.rhythm_segments() 的原始段没有 metrics）。
	for seg in data["segments"]:
		var m: Dictionary = seg["metrics"]
		match String(seg["type"]):
			"A":
				if int(m["single_points"]) >= 1 and float(m["empty_run_s"]) >= SINGLE_GAP_S:
					a_ok = true
			"B":
				if int(m["combos"]) >= 1:
					b_ok = true
			"C":
				if int(m["combos"]) >= 1 and float(m["gap_ratio"]) >= 1.5:
					c_ok = true
			"D":
				if float(m["sustained_s"]) >= 2.5:
					d_ok = true
	_expect("A 段有孤立单点 + >= %.1f s 空跑" % SINGLE_GAP_S, a_ok, "")
	_expect("B 段有间隔 <= %.1f s 的连招" % LevelData.COMBO_GAP_S, b_ok, "")
	_expect("C 段间隔比 >= 1.5（有快有慢）", c_ok, "")
	_expect("D 段同一状态要维持 >= 2.5 s", d_ok, "")


func _check_route_completion() -> void:
	for seg in data["segments"]:
		var sid := String(seg["id"])
		var routes: Dictionary = seg["routes"]
		for route in ["safe", "coop"]:
			var r: Dictionary = routes[route]
			_expect("%s %s 路线真实跑过该段且无碰撞" % [sid, route],
				bool(r["passed"]),
				"ended=%.1f hits=%s acc=%d mount=%s" % [
					float(r["ended_x"]), str(r["hits"]), int(r["accidents"]),
					String(r["mount_state"])])


func _expect(label: String, ok: bool, detail: String) -> void:
	if ok:
		print("ok   %s %s" % [label, ("[" + detail + "]") if detail != "" else ""])
	else:
		failures.append(label + ((" [" + detail + "]") if detail != "" else ""))
		print("FAIL %s [%s]" % [label, detail])


func _print_segment(e: Dictionary) -> void:
	var m: Dictionary = e["metrics"]
	var routes: Dictionary = e["routes"]
	print("%s %s %-18s groups=%2d 空跑%5.2fs 恢复%5.2fs 单点%2d 连招%d 持续%4.2fs 高压%5.1fs 重复%d | safe=%s coop=%s" % [
		String(e["id"]), String(e["type"]), String(e["name_zh"]),
		int(m["groups"]), float(m["empty_run_s"]), float(m["recovery_s"]),
		int(m["single_points"]), int(m["combos"]), float(m["sustained_s"]),
		float(m["pressure_s"]), int(m["repeated_combos"]),
		"PASS" if bool(routes["safe"]["passed"]) else "FAIL",
		"PASS" if bool(routes["coop"]["passed"]) else "FAIL"])


func _out_path() -> String:
	if full_mode:
		return "res://docs/reports/longrun/core-feel-07-fullrun.json"
	if is_equal_approx(step_hz, STEP_HZ):
		return OUT_PATH
	return "res://docs/reports/longrun/core-feel-07-rhythm-hz%d.json" % int(step_hz)


func _write() -> void:
	data["generated_at"] = Time.get_datetime_string_from_system()
	data["step_hz"] = step_hz
	data["note"] = "节奏分段指标来自真实关卡数据；两条路线是引擎内输入代理的真跑，不是真人试玩。"
	var f := FileAccess.open(ProjectSettings.globalize_path(_out_path()), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
		f.close()


func _finish(code: int) -> void:
	get_tree().quit(code)
