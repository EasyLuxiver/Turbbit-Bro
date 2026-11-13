extends Node
## STAGE 4 解法空间审计（只审计，不改玩法）
##
## 对 55 组障碍逐组跑真实输入探针，每组 7 种方案：
##   jump       只控制兔子跳跃
##   crouch     只控制兔子趴低
##   dive       只控制乌龟下潜（最早时机，按最深算）
##   leap       只控制乌龟跃起（3 个时机）
##   dive_jump  兔子起跳 → SHIFT → 乌龟下潜（BRO DIVE 的当前实现）
##   leap_jump  乌龟跃起 → SHIFT → 兔子二段跳（BRO OLLIE 的当前实现）
##   none       不操作、正常巡航
##
## 每个 case 传送到 start - lead，真实按键，记录：
##   是否通过 / 兔子碰撞 / 乌龟碰撞 / 落水 / 接人失败 / 操作系统 / 氧气消耗 / 最终状态。
##
## 用法：
##   D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
##       res://scenes/stage4_solution_audit.tscn > docs/reports/logs/solution-audit.log 2>&1

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_BASE := "res://docs/reports/stage4-solution-matrix"
## Phase J 容差扫描：只跑每组“设计答案”那一个方案，把 lead 从 400 扫到 40，
## 用通过区间换算出人类按得出来的时间窗。--tolerance 开启。
const TOL_BASE := "res://docs/reports/stage4-tolerance-scan"
const TOL_LEADS := [400.0, 340.0, 280.0, 240.0, 200.0, 160.0, 120.0, 80.0, 40.0]
var tol_mode := false
## 分片：--from N --to M（闭区间）。空 = 全量。
var shard_from := -1
var shard_to := -1
var out_path := OUT_BASE + ".json"
## Phase N：0.154 s 复核用的细扫参数（只在 --tolerance 下生效）。
##   --lead-min / --lead-max / --lead-step 自定义 lead 扫描带（px，从大到小）
##   --group <name> 只扫一组
##   --speed-scale <s> 把该区基速乘 s（模拟食物加速后的实际速度）
var lead_min := -1.0
var lead_max := -1.0
var lead_step := 0.0
var only_group := ""
var speed_scale := 1.0
## 物理步长（Hz）。默认 60，和正式游戏一致；探针用 time_scale=8 加速墙钟。
## --step-hz 30/120 用来验证窗口对帧率不敏感。
var step_hz := 60.0

## 加速带会改变速度、污染“基速下可解性”，审计时全关。
const DISABLE_BOOST := true
## 每个方案的探针时机（离组起点的距离，px）。dive/crouch/none 只需一个时机。
var LEADS := {
	"jump": [320.0, 240.0, 160.0, 100.0, 60.0, 40.0],
	"crouch": [160.0],
	"dive": [320.0],
	"leap": [320.0, 240.0, 160.0],
	"dive_jump": [160.0, 150.0, 140.0, 120.0],
	"leap_jump": [320.0, 240.0, 160.0],
	"none": [0.0],
}

var is_runner := false
var race: Node = null
var sim := 0.0
var rows: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	var uargs := OS.get_cmdline_user_args()
	tol_mode = uargs.has("--tolerance")
	for i in uargs.size():
		if uargs[i] == "--from" and i + 1 < uargs.size():
			shard_from = int(uargs[i + 1])
		elif uargs[i] == "--to" and i + 1 < uargs.size():
			shard_to = int(uargs[i + 1])
		elif uargs[i] == "--lead-min" and i + 1 < uargs.size():
			lead_min = float(uargs[i + 1])
		elif uargs[i] == "--lead-max" and i + 1 < uargs.size():
			lead_max = float(uargs[i + 1])
		elif uargs[i] == "--lead-step" and i + 1 < uargs.size():
			lead_step = float(uargs[i + 1])
		elif uargs[i] == "--group" and i + 1 < uargs.size():
			only_group = String(uargs[i + 1])
		elif uargs[i] == "--speed-scale" and i + 1 < uargs.size():
			speed_scale = float(uargs[i + 1])
		elif uargs[i] == "--step-hz" and i + 1 < uargs.size():
			step_hz = float(uargs[i + 1])
	if only_group != "":
		var tag := only_group
		if speed_scale != 1.0:
			tag += "-x%s" % str(speed_scale)
		if step_hz != 60.0:
			tag += "-hz%d" % int(step_hz)
		out_path = TOL_BASE + "-fine-%s.json" % tag
	elif shard_from >= 0:
		out_path = (TOL_BASE if tol_mode else OUT_BASE) + "-%02d-%02d.json" % [shard_from, shard_to]
	elif tol_mode:
		out_path = TOL_BASE + ".json"
	Engine.time_scale = 8.0
	# 每物理步固定 1/step_hz 游戏秒（time_scale 只加速墙钟，不改步长）。
	Engine.physics_ticks_per_second = int(step_hz * Engine.time_scale)
	await get_tree().process_frame
	await _run()


func _run() -> void:
	GameManager.start_race()
	for i in 3:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null:
		push_error("AUDIT: no current scene")
		_print_and_quit(1)
		return
	race.test_disable_hazards = false
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	if DISABLE_BOOST:
		race.boost_lanes.clear()
	await get_tree().physics_frame

	var groups: Array = race.hazard_groups
	print("AUDIT groups=%d schemes=%d shard=%d..%d" % [
		groups.size(), LEADS.size(), shard_from, shard_to])
	sim = 0.0
	var lo: int = 0 if shard_from < 0 else shard_from
	var hi: int = groups.size() - 1 if shard_to < 0 else mini(shard_to, groups.size() - 1)
	for i in range(lo, hi + 1):
		var g: Dictionary = groups[i]
		if only_group != "" and String(g["group"]) != only_group:
			continue
		var row: Dictionary
		if tol_mode:
			row = await _audit_tolerance(i, g)
		else:
			row = await _audit_group(i, g)
		rows.append(row)
		print(_row_line(row))

	_write_json()
	_print_and_quit(0)


func _audit_tolerance(index: int, g: Dictionary) -> Dictionary:
	var start: float = race._group_start(g)
	var end: float = race._group_end(g)
	var kind: String = String(g["kind"])
	var zone: Dictionary = LevelData.zone_at(start)
	if speed_scale != 1.0:
		zone = zone.duplicate()
		zone["base_speed"] = float(zone["base_speed"]) * speed_scale
	var scheme: String = _design_answer(kind)
	var b := float(zone["base_speed"])
	var leads: Array = TOL_LEADS.duplicate()
	# 细扫：自定义扫描带，用来区分“真窗口”和“粗网格的一档”。
	if lead_step > 0.0:
		leads = []
		var v := lead_max
		while v >= lead_min - 0.001:
			leads.append(snappedf(v, 0.1))
			v -= lead_step
	# 连招的第一段起手点跟区速绑定（主流程 0.7v / 0.8v），扫描带围绕它。
	elif scheme == "dive_jump":
		leads = [b * 0.95, b * 0.85, b * 0.75, b * 0.7, b * 0.65, b * 0.55, b * 0.45]
	elif scheme == "leap_jump":
		leads = [b * 1.1, b * 1.0, b * 0.9, b * 0.8, b * 0.75, b * 0.65, b * 0.55]
	var trials: Array = []
	for lead_v in leads:
		trials.append(await _run_case(g, scheme, float(lead_v), start, end, zone))
	var passing: Array = []
	for t in trials:
		if bool(t["passed"]):
			passing.append(float(t["lead"]))
	return {
		"index": index,
		"zone": int(zone["id"]),
		"kind": kind,
		"group": String(g["group"]),
		"design_answer": scheme,
		"leads": leads,
		"passing_leads": passing,
		"trials": trials,
	}


func _audit_group(index: int, g: Dictionary) -> Dictionary:
	var start: float = race._group_start(g)
	var end: float = race._group_end(g)
	var kind: String = String(g["kind"])
	var zone: Dictionary = LevelData.zone_at(start)
	var schemes := {}
	for scheme in LEADS.keys():
		var trials: Array = []
		var leads: Array = LEADS[scheme]
		# BRO DIVE 的起跳点跟基速绑定：主流程用 0.7v-2，这里给它 ±18 的搜索带。
		# 固定距离在 zone 2/3（240/260）会整体偏早，把“能过”误判成“不能过”。
		# 高墙的跃起点必须让壳的最高点正对墙面（主流程 lead = 0.8v）。
		# 固定 320/240/160 在 zone 1（220）会整体偏早，把能过的 OLLIE 误判成无解。
		if scheme == "leap_jump" and kind == "HIGH_WALL":
			var wb := float(zone["base_speed"])
			leads = [wb * 0.8 + 20.0, wb * 0.8, wb * 0.8 - 20.0]
		if scheme == "dive_jump":
			var b := float(zone["base_speed"])
			leads = [b * 0.7 + 16.0, b * 0.7 - 2.0,
				b * 0.7 - 20.0, b * 0.7 - 38.0]
		for lead_v in leads:
			var lead: float = float(lead_v)
			trials.append(await _run_case(g, scheme, lead, start, end, zone))
		var best := _best_trial(trials)
		schemes[scheme] = {
			"pass": bool(best["passed"]),
			"best_lead": best["lead"],
			"rabbit_hit": best["rabbit_hit"],
			"turtle_hit": best["turtle_hit"],
			"water": best["water"],
			"pickup_fail": best["pickup_fail"],
			"seconds": best["seconds"],
			"oxygen_used": best["oxygen_used"],
			"final": best["final"],
			"trials": trials,
		}
	var passing: Array = []
	for s in schemes.keys():
		if bool(schemes[s]["pass"]):
			passing.append(s)
	# 设计声称的答案（来自 STAGE-4-SPACE.md 的空间模型）。
	var design := _design_answer(kind)
	return {
		"index": index,
		"zone": int(zone["id"]),
		"kind": kind,
		"start": start,
		"end": end,
		"design_answer": design,
		"passing_schemes": passing,
		"schemes": schemes,
	}


func _design_answer(kind: String) -> String:
	match kind:
		"LOW_BIRD", "LOW_BEAM":
			return "crouch"
		"SURFACE_ROCK":
			return "jump"
		"FLOATING_LOG":
			return "dive_jump"
		"SHARK":
			return "leap"
		"DIVE_GATE":
			return "dive"
		"HIGH_WALL":
			return "leap_jump"
	return "?"


func _run_case(g: Dictionary, scheme: String, lead: float, start: float,
		end: float, zone: Dictionary) -> Dictionary:
	var gname := String(g["group"])
	_reset(start - lead, zone, scheme)
	# 输入缓存（SHIFT-FEEL-03）只认“按下沿”：同一引擎帧内先松后按，沿会被吃掉，
	# 所有靠 ↑ 的解法都会假失败（solution 全空）。先让一帧物理看到全部松开。
	# 这是探针的输入注入，不是玩法。
	await _step()
	var t0 := sim
	var jumped := false
	var shifted := false
	var leaped := false
	var rabbit_hit := false
	var turtle_hit := false
	var water := false
	var hit_at_x := -1.0
	var hit_channel := ""
	var first_accident := "NONE"
	var accident_seen := false
	var pickup_delta := 0
	var max_depth := 0.0
	var min_depth := 9999.0
	var steps := 0
	var press_done := {}
	var press_speed := -1.0
	var max_speed := 0.0
	var down_released := false
	var accident_at := -1.0
	# 步数上限按物理步长换算：60 Hz 时 700 步 ≈ 11.7 s，高步长不能提前截断。
	while sim - t0 < 5.0 and steps < int(700.0 * step_hz / 60.0):
		if accident_at >= 0.0 and sim - accident_at > 0.7:
			break
		var x: float = race.turtle.position.x
		if x <= end + 200.0:
			# ---- 方案输入 ----
			match scheme:
				"jump":
					if not jumped and x >= start - lead:
						press_speed = race.turtle.speed
						_control("rabbit")
						_press("up")
						jumped = true
				"crouch":
					if not jumped and x >= start - lead:
						_control("rabbit")
						_press("down")
						jumped = true
				"dive":
					if not jumped and x >= start - lead:
						_control("turtle")
						_press("down")
						jumped = true
				"leap":
					if not jumped and x >= start - lead:
						_control("turtle")
						_press("up")
						jumped = true
						press_speed = race.turtle.speed
				"dive_jump":
					if not jumped and x >= start - lead:
						_control("rabbit")
						_press("up")
						jumped = true
						press_done["jump_t"] = sim
					elif jumped and not shifted and race.mount.state == "AIRBORNE":
						_release("up")
						shifted = true
						_control("turtle")
						_press("down")
				"leap_jump":
					if not jumped and x >= start - lead:
						_control("turtle")
						_press("up")
						jumped = true
						leaped = true
						press_done["leap_t"] = sim
					elif leaped and not shifted and race.turtle.leap_active \
							and ((x >= start - 70.0) if String(g["kind"]) == "HIGH_WALL" else race.turtle.leap_timer >= 0.35):
						_release("up")
						shifted = true
						_control("rabbit")
						# 蹬踏也是“按下沿”：先松、过一帧、再按，否则这一下永远不触发。
						await _step()
						steps += 1
						_press("up")
						press_done["second_jump"] = (race.mount.state == "AIRBORNE")
		else:
			break

		await _step()
		steps += 1
		x = race.turtle.position.x
		max_speed = maxf(max_speed, race.turtle.speed)
		max_depth = maxf(max_depth, race.turtle.position.y)
		min_depth = minf(min_depth, race.turtle.position.y)
		if race.hit_groups.has(gname):
			if hit_at_x < 0.0:
				hit_at_x = x
				var r: Rect2 = race.rabbit.get_body_rect()
				var t: Rect2 = race.turtle.get_body_rect()
				var hit_r := false
				var hit_t := false
				for rr in g["rects"]:
					var rect: Rect2 = rr
					if rect.grow(-3.0).intersects(r):
						hit_r = true
					if rect.grow(-3.0).intersects(t):
						hit_t = true
				rabbit_hit = hit_r
				turtle_hit = hit_t
				hit_channel = "both" if (hit_r and hit_t) else ("rabbit" if hit_r else "turtle")
				first_accident = GameManager.accident_state
		if GameManager.accident_state != "NONE" and not accident_seen:
			accident_seen = true
			accident_at = sim
			if GameManager.accident_state == "RABBIT_WATER":
				water = true
			if first_accident == "NONE":
				first_accident = GameManager.accident_state
		if scheme == "dive_jump" and shifted and not down_released \
				and x >= end + 30.0:
			_release("down")
			down_released = true
		if x <= end + 200.0 and jumped:
			pass

	# 结束
	_release_all()
	var ended_x: float = race.turtle.position.x
	var hit: bool = bool(race.hit_groups.has(gname))
	var riding: bool = bool(race.mount.state == "RIDING")
	var airborne: bool = bool(race.mount.state == "AIRBORNE")
	var pickup_fail: bool = bool(airborne) or race.mount.state == "RESCUING"
	var passed := ended_x > end + 150.0 and not hit and not water and riding
	if scheme in ["jump", "dive_jump", "leap_jump"]:
		pickup_fail = not riding
		if not riding:
			passed = false
	var seconds := sim - t0
	return {
		"lead": lead,
		"passed": passed,
		"rabbit_hit": rabbit_hit,
		"turtle_hit": turtle_hit,
		"water": water,
		"pickup_fail": pickup_fail,
		"seconds": snappedf(seconds, 0.01),
		"oxygen_used": snappedf(Tuning.OXYGEN_MAX - GameManager.oxygen, 0.01),
		"hit_at_x": hit_at_x,
		"hit_channel": hit_channel,
		"press_speed": snappedf(press_speed, 0.1),
		"max_speed": snappedf(max_speed, 0.1),
		"first_accident": first_accident,
		"max_depth": snappedf(max_depth, 0.1),
		"min_depth": snappedf(min_depth, 0.1),
		"ended_x": snappedf(ended_x, 0.1),
		"final": {
			"mount": race.mount.state,
			"rabbit": race.rabbit.state,
			"turtle": race.turtle.state,
			"accident": GameManager.accident_state,
			"control": GameManager.current_control,
			"leap_active": race.turtle.leap_active,
			"second_jump": bool(press_done.get("second_jump", false)),
			"oxygen": snappedf(GameManager.oxygen, 0.01),
		},
	}


func _best_trial(trials: Array) -> Dictionary:
	# 优先：通过 → 无碰撞 → 兔子碰撞少 → 时间短。
	var best: Dictionary = trials[0]
	for t in trials:
		var bt: Dictionary = best
		var tt: Dictionary = t
		if bool(tt["passed"]) and not bool(bt["passed"]):
			best = t
		elif bool(tt["passed"]) == bool(bt["passed"]):
			if int(tt["rabbit_hit"]) < int(bt["rabbit_hit"]):
				best = t
			elif int(tt["rabbit_hit"]) == int(bt["rabbit_hit"]) \
					and float(tt["seconds"]) < float(bt["seconds"]):
				best = t
	return best


func _reset(x: float, zone: Dictionary, scheme: String) -> void:
	_release_all()
	GameManager.accident_state = "NONE"
	GameManager.oxygen = Tuning.OXYGEN_MAX
	GameManager.showtime_active = false
	# 每个 case 是独立世界：BRO METER 和联合惩罚的排队必须一起清。
	# 不清的话前一个 case 攒的格子会带进来，第三格在下一个 case 开场就触发
	# 1.4 s 联合演出（速度被钉成 0、位置被锁），探针结果随机变成“无解”。
	GameManager.clear_bro_meter()
	GameManager.accident_count = 0
	race.joint_show_t = 0.0
	race.accident_flash = 0.0
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
	# G20：hit_roles 必须和 hit_groups 一起清。只清 hit_groups 时，B2 起的“角色×组”记账还留着，同组第二例起整组免疫——后面那些重复用例其实在测一段不会撞的赛道。
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	# race 每帧会把 turtle.base_speed 拉回 current_zone，所以倍速必须写进 zone 本身。
	race.current_zone = zone
	var speed: float = float(zone["base_speed"])
	race.turtle.reset(Vector2(x, Tuning.NEUTRAL_DEPTH))
	race.turtle.speed = speed
	race.turtle.base_speed = speed
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()


func _control(who: String) -> void:
	if GameManager.current_control != who:
		GameManager.set_control(who)


func _press(action: String) -> void:
	if not Input.is_action_pressed(action):
		Input.action_press(action)


func _release(action: String) -> void:
	if Input.is_action_pressed(action):
		Input.action_release(action)


func _release_all() -> void:
	Input.action_release("up")
	Input.action_release("down")
	Input.action_release("shift")


func _step() -> void:
	await get_tree().physics_frame
	sim += 1.0 / step_hz


func _row_line(row: Dictionary) -> String:
	if tol_mode:
		return "TOL   g=%02d %-9s %-13s pass_leads=%s" % [
			int(row["index"]), String(row["group"]), String(row["kind"]),
			str(row["passing_leads"])]
	var s: String = "AUDIT g=%02d %-13s design=%-9s pass=%s" % [
		int(row["index"]), String(row["kind"]), String(row["design_answer"]),
		str(row["passing_schemes"])]
	return s


func _write_json() -> void:
	if tol_mode:
		var payload := {
			"generated_at": Time.get_datetime_string_from_system(),
			"note": "Phase J 容差扫描：只跑设计答案方案，lead 从大到小扫；自动驾驶代理，不是真人。",
			"groups": rows.size(),
			"rows": rows,
		}
		var tf := FileAccess.open(ProjectSettings.globalize_path(out_path), FileAccess.WRITE)
		if tf == null:
			push_error("TOL: cannot write " + out_path)
			return
		tf.store_string(JSON.stringify(payload, "  "))
		tf.close()
		print("TOL wrote " + out_path)
		return
	var by_kind := {}
	var log_dive_only: Array = []
	var no_solution: Array = []
	for row in rows:
		var kind: String = String(row["kind"])
		if not by_kind.has(kind):
			by_kind[kind] = {"groups": 0, "design_correct": 0, "pass_counts": {}}
		var k: Dictionary = by_kind[kind]
		k["groups"] = int(k["groups"]) + 1
		var passing: Array = row["passing_schemes"]
		if passing.has(String(row["design_answer"])):
			k["design_correct"] = int(k["design_correct"]) + 1
		for s in passing:
			k["pass_counts"][s] = int(k["pass_counts"].get(s, 0)) + 1
		if passing.is_empty():
			no_solution.append(int(row["index"]))
		if kind == "FLOATING_LOG":
			var sc: Dictionary = row["schemes"]
			log_dive_only.append({
				"index": row["index"],
				"dive_only_pass": bool(sc["dive"]["pass"]),
				"jump_only_pass": bool(sc["jump"]["pass"]),
				"combo_pass": bool(sc["dive_jump"]["pass"]),
				"leap_only_pass": bool(sc["leap"]["pass"]),
				"passing": passing,
			})
	var data := {
		"generated_at": Time.get_datetime_string_from_system(),
		"note": "真实输入探针，加速带关闭，基速；自动驾驶代理，不是真人。",
		"groups": rows.size(),
		"no_solution_groups": no_solution,
		"logs_falsification": log_dive_only,
		"by_kind": by_kind,
		"matrix": rows,
	}
	var f := FileAccess.open(ProjectSettings.globalize_path(out_path), FileAccess.WRITE)
	if f == null:
		push_error("AUDIT: cannot write " + out_path)
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	print("AUDIT wrote " + out_path)
	print("AUDIT no_solution=%s" % str(no_solution))
	for kind in by_kind.keys():
		var k: Dictionary = by_kind[kind]
		print("AUDIT kind=%-13s groups=%d design_correct=%d pass_counts=%s" % [
			String(kind), int(k["groups"]), int(k["design_correct"]),
			str(k["pass_counts"])])
	for l in log_dive_only:
		print("AUDIT log g=%02d dive_only=%s jump_only=%s combo=%s leap_only=%s passing=%s" % [
			int(l["index"]), str(l["dive_only_pass"]), str(l["jump_only_pass"]),
			str(l["combo_pass"]), str(l["leap_only_pass"]), str(l["passing"])])


func _print_and_quit(code: int) -> void:
	if code == 0:
		print("SOLUTION AUDIT: DONE")
	else:
		print("SOLUTION AUDIT: FAIL")
	get_tree().quit(code)
