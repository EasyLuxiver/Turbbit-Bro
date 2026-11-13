extends Node
## PHASE C 细窗审计（只读，不改玩法）
##
## 目的：粗审计（stage4_solution_audit.gd）每个方案只试 1～6 个 lead，
## 只能回答“能不能过”，回答不了“给人留了多宽的操作窗口”。
## 这里对“每类障碍 × 每个区域”各取一个代表组，把 lead 扫细，测出：
##   - 最早/最晚可行 lead（px）
##   - 换算成秒的输入窗口（px / zone base_speed）
##   - 失败侧的碰撞通道（兔子/乌龟/落水/接人失败）
##
## 用法：
##   D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
##       res://scenes/stage4_window_audit.tscn > docs/reports/logs/window-audit.log 2>&1
##
## 输出：docs/reports/longrun/phase-c-windows.json

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/core-feel-07-window-audit.json"

## 代表组：同一 kind、同一 zone 里按 x 排中间的一组。
## 值 = [kind, zone, [scheme, ...], 粗扫 step px, 细扫 step px]
##
## CORE-FEEL-07 P2：这里原来写死组下标。Phase H 对调过槽位之后，
## 下标指向的已经不是原类型的组（08 是 HIGH_WALL、10 是 LOW_BIRD），
## 审计照跑不误、结果全是“0 px 窗口”。改成按 kind+zone 在装载后的
## 真实关卡里解析，站位再动也不会量错东西。
const CASES := [
	["LOW_BIRD", 1, ["crouch", "jump", "dive", "leap"], 20.0, 10.0],
	["LOW_BIRD", 2, ["crouch", "jump", "dive", "leap"], 20.0, 10.0],
	["LOW_BIRD", 3, ["crouch", "jump", "dive", "leap"], 20.0, 10.0],
	["SURFACE_ROCK", 1, ["jump", "dive", "leap"], 20.0, 10.0],
	["SURFACE_ROCK", 2, ["jump", "dive", "leap"], 20.0, 10.0],
	["SURFACE_ROCK", 3, ["jump", "dive", "leap"], 20.0, 10.0],
	["LOW_BEAM", 1, ["crouch", "dive"], 20.0, 10.0],
	["LOW_BEAM", 2, ["crouch", "dive"], 20.0, 10.0],
	["LOW_BEAM", 3, ["crouch", "dive"], 20.0, 10.0],
	["SHARK", 1, ["leap", "dive"], 20.0, 10.0],
	["SHARK", 2, ["leap", "dive"], 20.0, 10.0],
	["SHARK", 3, ["leap", "dive"], 20.0, 10.0],
	["DIVE_GATE", 1, ["dive"], 20.0, 10.0],
	["DIVE_GATE", 2, ["dive"], 20.0, 10.0],
	["DIVE_GATE", 3, ["dive"], 20.0, 10.0],
	["FLOATING_LOG", 1, ["dive_jump"], 10.0, 5.0],
	["FLOATING_LOG", 2, ["dive_jump"], 10.0, 5.0],
	["FLOATING_LOG", 3, ["dive_jump"], 10.0, 5.0],
	["HIGH_WALL", 1, ["leap_jump"], 10.0, 5.0],
	["HIGH_WALL", 2, ["leap_jump"], 10.0, 5.0],
	["HIGH_WALL", 3, ["leap_jump"], 10.0, 5.0],
]

var is_runner := false
var race: Node = null
var sim := 0.0
var rows: Array = []
## 调试用：--kind=HIGH_WALL 只扫这一类，其余跳过。
var only_kind := ""


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="):
			only_kind = arg.substr(7)
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 16.0
	Engine.physics_ticks_per_second = 960
	await get_tree().process_frame
	await _run()


func _run() -> void:
	GameManager.start_race()
	for i in 3:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null:
		push_error("WINDOW: no current scene")
		_finish(1)
		return
	race.test_disable_hazards = false
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()
	await get_tree().physics_frame

	var groups: Array = race.hazard_groups
	print("WINDOW groups=%d cases=%d" % [groups.size(), CASES.size()])
	sim = 0.0
	for case_v in CASES:
		var case: Array = case_v
		if only_kind != "" and String(case[0]) != only_kind:
			continue
		var gi := _resolve(case[0], int(case[1]))
		if gi < 0:
			push_error("WINDOW: no group for %s z%d" % [String(case[0]), int(case[1])])
			continue
		var g: Dictionary = groups[gi]
		var start: float = race._group_start(g)
		var end: float = race._group_end(g)
		var zone: Dictionary = LevelData.zone_at(start)
		var v: float = float(zone["base_speed"])
		var entry := {
			"index": gi, "group": String(g["group"]), "kind": String(g["kind"]),
			"zone": int(zone["id"]), "width": snappedf(end - start, 0.1),
			"base_speed": v, "sight_s": snappedf(Tuning.PROMPT_RANGE / v, 0.01),
			"schemes": {},
		}
		print("CASE g=%02d %-13s z%d w=%.0f v=%.0f" % [
			gi, String(g["kind"]), int(zone["id"]), end - start, v])
		for scheme_v in case[2]:
			var scheme: String = String(scheme_v)
			var step: float = float(case[4] if scheme in ["dive_jump", "leap_jump"] else case[3])
			var lo := 10.0
			var hi := 420.0
			if scheme == "dive":
				hi = 620.0
			if scheme in ["dive_jump", "leap_jump"]:
				lo = 80.0
				hi = 320.0
			var trials: Array = []
			var lead := lo
			while lead <= hi + 0.01:
				var r: Dictionary = await _run_case(g, scheme, lead, start, end, zone)
				if bool(r["passed"]):
					trials.append({
						"lead": lead,
						"seconds_before": snappedf(lead / v, 0.001),
						"seconds": r["seconds"],
						"oxygen_used": r["oxygen_used"],
					})
				lead += step
			var window_s := 0.0
			var early := 0.0
			var late := 0.0
			if not trials.is_empty():
				var first: Dictionary = trials[0]
				var last: Dictionary = trials[trials.size() - 1]
				early = float(first["lead"])
				late = float(last["lead"])
				window_s = (late - early) / v
			entry["schemes"][scheme] = {
				"pass_count": trials.size(),
				"lead_min": early,
				"lead_max": late,
				"window_px": late - early,
				"window_s": snappedf(window_s, 0.001),
				"trials": trials,
			}
			print("  %-9s pass=%3d lead %.0f..%.0f (%.0f px = %.2f s)" % [
				scheme, trials.size(), early, late, late - early, window_s])
		rows.append(entry)
		_write()
	_write()
	print("WINDOW: DONE")
	_finish(0)


## 按 kind + zone 在装载后的真实关卡里找代表组：同类型按 x 排序取中间一组。
func _resolve(kind: String, zone_id: int) -> int:
	var groups: Array = race.hazard_groups
	var cand: Array = []
	for i in groups.size():
		var g: Dictionary = groups[i]
		if String(g["kind"]) != kind:
			continue
		if int(LevelData.zone_at(race._group_start(g))["id"]) != zone_id:
			continue
		cand.append(i)
	if cand.is_empty():
		return -1
	return int(cand[cand.size() / 2])


func _run_case(g: Dictionary, scheme: String, lead: float, start: float,
		end: float, zone: Dictionary) -> Dictionary:
	var gname := String(g["group"])
	_reset(start - lead, zone)
	# 输入缓存用“按下沿”判定：_reset 里的 _release_all() 与第一下按键
	# 落在同一引擎帧时，沿会被吃掉（跳/跃起永远不触发）。先让一帧物理
	# 看到全部松开，再开始按。与 stage4_combo_windows 的处理一致。
	await _step()
	var t0 := sim
	var jumped := false
	var shifted := false
	var leaped := false
	var rabbit_hit := false
	var turtle_hit := false
	var water := false
	var hit_at_x := -1.0
	var accident_seen := false
	var down_released := false
	var steps := 0
	while sim - t0 < 5.0 and steps < 700:
		var x: float = race.turtle.position.x
		if x > end + 200.0:
			break
		match scheme:
			"jump":
				if not jumped and x >= start - lead:
					_control("rabbit"); _press("up"); jumped = true
			"crouch":
				if not jumped and x >= start - lead:
					_control("rabbit"); _press("down"); jumped = true
			"dive":
				if not jumped and x >= start - lead:
					_control("turtle"); _press("down"); jumped = true
			"leap":
				if not jumped and x >= start - lead:
					_control("turtle"); _press("up"); jumped = true
			"dive_jump":
				if not jumped and x >= start - lead:
					_control("rabbit"); _press("up"); jumped = true
				elif jumped and not shifted and race.mount.state == "AIRBORNE":
					_release("up"); shifted = true
					_control("turtle"); _press("down")
			"leap_jump":
				if not jumped and x >= start - lead:
					_control("turtle"); _press("up"); jumped = true; leaped = true
				elif leaped and not shifted and race.turtle.leap_active \
						and ((x >= start - 70.0) if String(g["kind"]) == "HIGH_WALL"
						else race.turtle.leap_timer >= 0.35):
					_release("up"); shifted = true
					_control("rabbit")
					# 蹬踏也是“按下沿”：同一帧内松了马上按会被吃掉。
					await _step()
					_press("up")
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
		# 与粗审计一致：组合的下潜要松开，壳才有机会上浮接人。
		if scheme == "dive_jump" and shifted and not down_released \
				and x >= end + 30.0:
			_release("down")
			down_released = true
		if x > end + 200.0:
			break
	_release_all()
	var ended_x: float = race.turtle.position.x
	var hit: bool = bool(race.hit_groups.has(gname))
	var riding: bool = bool(race.mount.state == "RIDING")
	var passed := ended_x > end + 150.0 and not hit and not water and riding
	if scheme in ["jump", "dive_jump", "leap_jump"] and not riding:
		passed = false
	return {
		"lead": lead, "passed": passed, "rabbit_hit": rabbit_hit,
		"turtle_hit": turtle_hit, "water": water,
		"seconds": snappedf(sim - t0, 0.01),
		"oxygen_used": snappedf(Tuning.OXYGEN_MAX - GameManager.oxygen, 0.01),
		"hit_at_x": snappedf(hit_at_x, 0.1),
	}


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
	# G20：hit_roles 必须和 hit_groups 一起清。只清 hit_groups 时，B2 起的“角色×组”记账还留着，同组第二例起整组免疫——后面那些重复用例其实在测一段不会撞的赛道。
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	# 每个 trial 从 CALM 起跑：神游量会跨 trial 残留，不清零会让后面的格子
	# 带着前面攒下的降速/偏移，“窗口”测的就不是这一次输入了。
	race.reset_brains()
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
	sim += 1.0 / 60.0


func _write() -> void:
	var data := {
		"generated_at": Time.get_datetime_string_from_system(),
		"note": "细窗审计：真实按键、加速带关闭、基速；自动驾驶代理，不是真人。",
		"cases": rows,
	}
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
		f.close()


func _finish(code: int) -> void:
	get_tree().quit(code)
