extends Node
## PHASE E 连招第二段窗口扫描（只读，不改玩法）
##
## Phase C 细窗只扫了“第一次输入”的 lead；连招的第二段（SHIFT + 下潜 / SHIFT + 蹬踏）
## 在探针里是固定脚本，因此 0.14–0.25 s 只是起手窗口，不是完整窗口。
##
## 这里做二维扫描：
##   BRO DIVE: 兔子跳 lead × 起跳后到 SHIFT/下潜的延迟
##   BRO OLLIE: 乌龟跃 lead × 跃起后到 SHIFT/蹬踏的延迟
## 每个格子记录 pass 与失败通道，输出二维窗口图。
##
## 用法：
##   D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
##       res://scenes/stage4_combo_windows.tscn > docs/reports/logs/combo-windows.log 2>&1
##
## 输出：docs/reports/longrun/phase-e-combo-windows.json

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/phase-e-combo-windows.json"

## [group 名或索引, scheme, lead_min, lead_max, lead_step, delay_min, delay_max, delay_step]
## CORE-FEEL-07：关卡重新排过槽位后固定索引会悄悄指错组（08 曾经是浮木，
## 现在 08 是高墙），扫描结果会变成“0/273”这种看不懂的数。改成按组名解析。
const CASES := [
	["log1", "dive_jump", 100.0, 300.0, 10.0, 0.00, 0.60, 0.05],   # LOG  z1
	["log3", "dive_jump", 100.0, 300.0, 10.0, 0.00, 0.60, 0.05],   # LOG  z2
	["log8", "dive_jump", 100.0, 300.0, 10.0, 0.00, 0.60, 0.05],   # LOG  z3
	["wall1", "leap_jump", 120.0, 260.0, 10.0, 0.00, 0.90, 0.05],  # WALL z1
	["wall2", "leap_jump", 120.0, 280.0, 10.0, 0.00, 0.90, 0.05],  # WALL z2
	["wall3", "leap_jump", 140.0, 280.0, 10.0, 0.00, 0.90, 0.05],  # WALL z3
]

var is_runner := false
var race: Node = null
var sim := 0.0
var rows: Array = []
var out_path := OUT_PATH
## Phase N：物理步长与速度倍率（模拟食物加速后的遭遇）。
var step_hz := 60.0
var speed_scale := 1.0


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 16.0
	# Phase N：可调物理步长（默认 60 Hz，和正式游戏一致；time_scale 只加速墙钟）。
	step_hz = float(_arg(OS.get_cmdline_user_args(), "--step-hz", "60"))
	Engine.physics_ticks_per_second = int(step_hz * Engine.time_scale)
	await get_tree().process_frame
	await _run()


func _run() -> void:
	GameManager.start_race()
	for i in 3:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null:
		push_error("COMBO: no current scene")
		_finish(1)
		return
	race.test_disable_hazards = false
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()
	await get_tree().physics_frame

	# 命令行覆盖（Phase J）：--indices 8,17,... --scheme dive_jump
	# --lead min,max,step --delay min,max,step --out res://...
	# 不传就按 CASES 跑，行为与 Phase E/H 一致。
	var cases: Array = CASES
	var uargs := OS.get_cmdline_user_args()
	var idx_arg := _arg(uargs, "--indices")
	if idx_arg != "":
		var scheme := _arg(uargs, "--scheme")
		if scheme == "":
			scheme = "dive_jump"
		var lp := _triple(_arg(uargs, "--lead"), "120,300,10")
		var dp := _triple(_arg(uargs, "--delay"), "0.00,0.35,0.05")
		cases = []
		for s in idx_arg.split(","):
			cases.append([int(s.strip_edges()), scheme, lp[0], lp[1], lp[2],
				dp[0], dp[1], dp[2]])
	var out_arg := _arg(uargs, "--out")
	if out_arg != "":
		out_path = out_arg

	var groups: Array = race.hazard_groups
	print("COMBO groups=%d cases=%d out=%s" % [groups.size(), cases.size(), out_path])
	sim = 0.0
	for case_v in cases:
		var case: Array = case_v
		var gi: int = -1
		if case[0] is String:
			for i in groups.size():
				if String(groups[i]["group"]) == String(case[0]):
					gi = i
					break
			if gi < 0:
				push_error("COMBO: group %s not found" % String(case[0]))
				continue
		else:
			gi = int(case[0])
		var scheme: String = String(case[1])
		var g: Dictionary = groups[gi]
		var start: float = race._group_start(g)
		var end: float = race._group_end(g)
		var zone: Dictionary = LevelData.zone_at(start)
		speed_scale = float(_arg(uargs, "--speed-scale", "1.0"))
		if speed_scale != 1.0:
			zone = zone.duplicate()
			zone["base_speed"] = float(zone["base_speed"]) * speed_scale
		var v: float = float(zone["base_speed"])
		var lead_min: float = float(case[2])
		var lead_max: float = float(case[3])
		var lead_step: float = float(case[4])
		var delay_min: float = float(case[5])
		var delay_max: float = float(case[6])
		var delay_step: float = float(case[7])

		var entry := {
			"index": gi, "group": String(g["group"]), "kind": String(g["kind"]),
			"zone": int(zone["id"]), "width": snappedf(end - start, 0.1),
			"base_speed": v,
			"speed_scale": speed_scale,
			"step_hz": step_hz,
			"scheme": scheme,
			"lead_range": [lead_min, lead_max, lead_step],
			"delay_range": [delay_min, delay_max, delay_step],
			"cells": [],
			"leads": [],
			"summary": {},
		}
		print("CASE g=%02d %-12s z%d w=%.0f v=%.0f %s" % [
			gi, String(g["kind"]), int(zone["id"]), end - start, v, scheme])

		var lead := lead_min
		while lead <= lead_max + 0.01:
			var cells_for_lead: Array = []
			var delay := delay_min
			while delay <= delay_max + 0.001:
				var r: Dictionary = await _run_case(g, scheme, lead, delay, start, end, zone)
				var cell := {
					"lead": snappedf(lead, 0.1),
					"delay": snappedf(delay, 0.01),
					"passed": bool(r["passed"]),
					"why": String(r["why"]),
					"oxygen_used": r["oxygen_used"],
				}
				entry["cells"].append(cell)
				cells_for_lead.append(cell)
				delay += delay_step
			var pass_cells: Array = []
			var fail_why := {}
			for c in cells_for_lead:
				if bool(c["passed"]):
					pass_cells.append(c)
				else:
					var w := String(c["why"])
					fail_why[w] = int(fail_why.get(w, 0)) + 1
			var summary := _ranges(pass_cells, v)
			var lead_row := {
				"lead": snappedf(lead, 0.1),
				"pass_count": pass_cells.size(),
				"delay_min": summary["min"],
				"delay_max": summary["max"],
				"delay_window_s": summary["window_s"],
				"delay_runs": summary["runs"],
				"fail": fail_why,
			}
			entry["leads"].append(lead_row)
			if pass_cells.size() > 0:
				print("  lead=%3.0f pass=%2d delay %.2f..%.2f (%.2f s, runs=%d)" % [
					lead, pass_cells.size(), summary["min"], summary["max"],
					summary["window_s"], int(summary["runs"])])
			lead += lead_step

		entry["summary"] = _summarize(entry["leads"], v)
		rows.append(entry)
		_write()
		print("  SUMMARY pass=%d/%d lead_with_pass=%d best_delay=%.2f s at lead %.0f" % [
			int(entry["summary"]["pass_cells"]), int(entry["summary"]["cells"]),
			int(entry["summary"]["leads_with_pass"]),
			float(entry["summary"]["best_delay_window_s"]),
			float(entry["summary"]["best_lead"])])

	_write()
	print("COMBO: DONE")
	_finish(0)


func _run_case(g: Dictionary, scheme: String, lead: float, delay: float,
		start: float, end: float, zone: Dictionary) -> Dictionary:
	var gname := String(g["group"])
	_reset(start - lead, zone)
	# 输入缓存（SHIFT-FEEL-03）用“按下沿”判定：同一引擎帧内先松后按，沿会被
	# 吃掉，跳就永远不触发（整张表会变成 input_missed）。先让一帧物理看到
	# 全部松开，再开始按。这是探针的输入注入，不是玩法。
	await _step()
	var t0 := sim
	var first_t := -1.0
	var second_t := -1.0
	var first_done := false
	var second_done := false
	var second_invalid := false
	var rabbit_hit := false
	var turtle_hit := false
	var water := false
	var hit_at_x := -1.0
	var accident_seen := false
	var down_released := false
	var steps := 0

	while sim - t0 < 6.0 and steps < 900:
		var x: float = race.turtle.position.x
		if x > end + 220.0:
			break
		if scheme == "dive_jump":
			if not first_done and x >= start - lead:
				_control("rabbit"); _press("up")
				first_done = true
				first_t = sim
			elif first_done and not second_done and sim - first_t >= delay - 0.001:
				# 第二段：松开跳，立刻换乌龟按住下潜。
				# 只有在空中才成立；不在空中就记为无效时序（不是 pass）。
				if race.mount.state == "AIRBORNE":
					_release("up")
					_control("turtle"); _press("down")
					second_done = true
					second_t = sim
				elif sim - first_t > delay + 0.20:
					second_invalid = true
					second_done = true
		elif scheme == "leap_jump":
			if not first_done and x >= start - lead:
				_control("turtle"); _press("up")
				first_done = true
				first_t = sim
			elif first_done and not second_done and sim - first_t >= delay - 0.001:
				if race.turtle.leap_active:
					_release("up")
					_control("rabbit")
					# 蹬踏是“按下沿”：先松、过一帧、再按，否则这一下永远不触发。
					await _step()
					_press("up")
					second_done = true
					second_t = sim
				elif sim - first_t > delay + 0.20:
					second_invalid = true
					second_done = true
		await _step()
		steps += 1
		x = race.turtle.position.x
		if race.hit_groups.has(gname):
			if hit_at_x < 0.0:
				hit_at_x = x
				var r: Rect2 = race.rabbit.get_body_rect()
				var t: Rect2 = race.turtle.get_body_rect()
				for rr in g["rects"]:
					var rect: Rect2 = rr
					if rect.grow(-3.0).intersects(r):
						rabbit_hit = true
					if rect.grow(-3.0).intersects(t):
						turtle_hit = true
		if GameManager.accident_state != "NONE" and not accident_seen:
			accident_seen = true
			if GameManager.accident_state == "RABBIT_WATER":
				water = true
		if scheme == "dive_jump" and second_done and not down_released \
				and x >= end + 30.0:
			_release("down")
			down_released = true
		if x > end + 220.0:
			break

	_release_all()
	var ended_x: float = race.turtle.position.x
	var hit: bool = bool(race.hit_groups.has(gname))
	var riding: bool = bool(race.mount.state == "RIDING")
	var passed := first_done and second_done and not second_invalid \
		and ended_x > end + 150.0 and not hit and not water and riding
	var why := "pass"
	if passed:
		why = "pass"
	elif second_invalid or not second_done:
		why = "input_missed"
	elif water:
		why = "rabbit_water"
	elif turtle_hit:
		why = "turtle_hit"
	elif rabbit_hit:
		why = "rabbit_hit"
	elif not riding:
		why = "pickup_fail"
	elif ended_x <= end + 150.0:
		why = "incomplete"
	elif hit:
		why = "hit"
	return {
		"passed": passed, "why": why,
		"rabbit_hit": rabbit_hit, "turtle_hit": turtle_hit,
		"oxygen_used": snappedf(Tuning.OXYGEN_MAX - GameManager.oxygen, 0.01),
		"hit_at_x": snappedf(hit_at_x, 0.1),
	}


## 把一串 pass 单元格压成“延迟区间”；只统计连续段（step 已知）。
func _ranges(pass_cells: Array, v: float) -> Dictionary:
	if pass_cells.is_empty():
		return {"min": 0.0, "max": 0.0, "window_s": 0.0, "runs": 0, "width": 0.0}
	var ds: Array = []
	for c in pass_cells:
		ds.append(float(c["delay"]))
	ds.sort()
	var runs := 1
	var run_width := 0.0
	var best_run := 0.0
	var step := 0.05
	for i in range(1, ds.size()):
		var d := float(ds[i]) - float(ds[i - 1])
		if d > step * 1.5:
			runs += 1
			run_width = 0.0
		else:
			run_width += d
			best_run = maxf(best_run, run_width)
	var first := float(ds[0])
	var last := float(ds[ds.size() - 1])
	return {
		"min": snappedf(first, 0.01),
		"max": snappedf(last, 0.01),
		"window_s": snappedf(last - first, 0.001),
		"runs": runs,
		"width": snappedf(best_run + (step if ds.size() > 0 else 0.0), 0.001),
	}


func _summarize(leads: Array, v: float) -> Dictionary:
	var cells := 0
	var pass_cells := 0
	var leads_with_pass := 0
	var best_delay := 0.0
	var best_lead := 0.0
	var best_min := 0.0
	var best_max := 0.0
	var lead_first := 0.0
	var lead_last := 0.0
	for row in leads:
		cells += int(row["pass_count"]) + _fail_count(row)
		if int(row["pass_count"]) > 0:
			pass_cells += int(row["pass_count"])
			leads_with_pass += 1
			if lead_first == 0.0:
				lead_first = float(row["lead"])
			lead_last = float(row["lead"])
			var w := float(row["delay_window_s"])
			if w > best_delay:
				best_delay = w
				best_lead = float(row["lead"])
				best_min = float(row["delay_min"])
				best_max = float(row["delay_max"])
	return {
		"cells": cells,
		"pass_cells": pass_cells,
		"leads_with_pass": leads_with_pass,
		"lead_first": lead_first,
		"lead_last": lead_last,
		"lead_window_s": snappedf((lead_last - lead_first) / v, 0.001),
		"best_delay_window_s": snappedf(best_delay, 0.001),
		"best_lead": best_lead,
		"best_delay_min": best_min,
		"best_delay_max": best_max,
	}


func _fail_count(row: Dictionary) -> int:
	var n := 0
	var f: Dictionary = row["fail"]
	for k in f:
		n += int(f[k])
	return n


func _reset(x: float, zone: Dictionary) -> void:
	_release_all()
	GameManager.accident_state = "NONE"
	GameManager.oxygen = Tuning.OXYGEN_MAX
	GameManager.showtime_active = false
	GameManager.current_control = "turtle"
	GameManager.has_shifted = true
	GameManager.pickup_window = false
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
	# 每个 trial 从 CALM 起跑：神游量会跨 trial 残留，不清零会让后面的格子
	# 带着前面攒下的降速/偏移/起跳点偏移，“窗口”测的就不是这一次输入了。
	race.reset_brains()
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


func _write() -> void:
	var data := {
		"generated_at": Time.get_datetime_string_from_system(),
		"note": "连招第二段二维扫描：真实按键、加速带关闭、基速、自动驾驶代理，不是真人。",
		"cases": rows,
	}
	var f := FileAccess.open(ProjectSettings.globalize_path(out_path), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
		f.close()


func _arg(uargs: PackedStringArray, name: String, fallback := "") -> String:
	for i in uargs.size():
		if uargs[i] == name and i + 1 < uargs.size():
			return uargs[i + 1]
	return fallback


func _triple(s: String, fallback: String) -> Array:
	if s == "":
		s = fallback
	var p := s.split(",")
	if p.size() != 3:
		p = fallback.split(",")
	return [float(p[0]), float(p[1]), float(p[2])]


func _finish(code: int) -> void:
	get_tree().quit(code)
