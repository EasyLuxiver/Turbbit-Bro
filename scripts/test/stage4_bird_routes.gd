extends Node
## TBB-SHIFT-CORE-02 §4：海鸟四路线证据（只读，不改玩法）。
##
## 细窗审计（stage4_window_audit）只记录“通过”的 lead，回答不了任务书要求的
## 每路线五项：成功率 / 反应窗口 / 是否碰撞 / 是否干净通过 / 是否影响后续。
## 这里对三只海鸟各跑四条路线，逐 trial 记录失败通道、氧气消耗、通关瞬间的
## 壳深度/速度/是否还在壳上，以及游戏自己判定的精准动作。
##
## 用法：
##   D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
##       res://scenes/stage4_bird_routes.tscn > docs/reports/logs/phase-shift/bird-routes.log 2>&1
##
## 输出：docs/reports/longrun/shift02-bird-routes.json

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/shift02-bird-routes.json"
const CASES := [0, 16, 36]
const SCHEMES := ["crouch", "jump", "dive", "leap"]

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
		push_error("BIRD: no current scene")
		_finish(1)
		return
	race.test_disable_hazards = false
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()
	await get_tree().physics_frame

	var groups: Array = race.hazard_groups
	print("BIRD routes=%d cases=%d" % [CASES.size(), SCHEMES.size()])
	sim = 0.0
	for gi in CASES:
		var g: Dictionary = groups[gi]
		var start: float = race._group_start(g)
		var end: float = race._group_end(g)
		var zone: Dictionary = LevelData.zone_at(start)
		var v: float = float(zone["base_speed"])
		var entry := {
			"index": gi, "group": String(g["group"]), "kind": String(g["kind"]),
			"zone": int(zone["id"]), "base_speed": v,
			"rects": [], "routes": {},
		}
		for rr in g["rects"]:
			var rect: Rect2 = rr
			entry["rects"].append([rect.position.x, rect.position.y,
				rect.size.x, rect.size.y])
		print("CASE g=%02d %s z%d v=%.0f" % [gi, String(g["group"]), int(zone["id"]), v])
		for scheme in SCHEMES:
			var lo := 10.0
			var hi := 620.0 if scheme == "dive" else 420.0
			var step := 10.0
			var trials: Array = []
			var lead := lo
			while lead <= hi + 0.01:
				trials.append(await _run_case(g, scheme, lead, start, end, zone))
				lead += step
			var s := _summarize(trials, v, scheme)
			entry["routes"][scheme] = s
			print("  %-6s pass=%3d/%3d lead %.0f..%.0f (%.2f s) fail=%s ox=%.2f..%.2f dy=%.0f..%.0f precise=%d" % [
				scheme, int(s["pass_count"]), int(s["trials"]),
				float(s["lead_min"]), float(s["lead_max"]), float(s["window_s"]),
				str(s["fail_channels"]), float(s["oxygen_min"]), float(s["oxygen_max"]),
				float(s["dy_min"]), float(s["dy_max"]), int(s["precise_count"])])
		rows.append(entry)
		_write()
	_write()
	print("BIRD: DONE")
	_finish(0)


func _run_case(g: Dictionary, scheme: String, lead: float, start: float,
		end: float, zone: Dictionary) -> Dictionary:
	var gname := String(g["group"])
	_reset(start - lead, zone)
	var t0 := sim
	var acted := false
	var rabbit_hit := false
	var turtle_hit := false
	var water := false
	var steps := 0
	while sim - t0 < 5.0 and steps < 700:
		var x: float = race.turtle.position.x
		if x > end + 200.0:
			break
		if not acted and x >= start - lead:
			acted = true
			match scheme:
				"crouch":
					_control("rabbit"); _press("down")
				"jump":
					_control("rabbit"); _press("up")
				"dive":
					_control("turtle"); _press("down")
				"leap":
					_control("turtle"); _press("up")
		await _step()
		steps += 1
		var r: Rect2 = race.rabbit.get_body_rect()
		var t: Rect2 = race.turtle.get_body_rect()
		for rr in g["rects"]:
			var rect: Rect2 = rr
			if rect.grow(-3.0).intersects(r):
				rabbit_hit = true
			if rect.grow(-3.0).intersects(t):
				turtle_hit = true
		if GameManager.accident_state == "RABBIT_WATER":
			water = true
	# 与细窗审计同口径：越过尾端 150 px、没撞、没落水、还在壳上才算过。
	var ended_x: float = race.turtle.position.x
	var riding: bool = race.mount.state == "RIDING"
	var hit: bool = bool(race.hit_groups.has(gname))
	var passed := ended_x > end + 150.0 and not hit and not water and riding
	var fail := "pass"
	if not passed:
		if hit and rabbit_hit:
			fail = "rabbit_hit"
		elif hit and turtle_hit:
			fail = "turtle_hit"
		elif water:
			fail = "rabbit_water"
		elif not riding:
			fail = "pickup_fail"
		else:
			fail = "incomplete"
	_release_all()
	var precise := false
	if passed:
		var act: Dictionary = race.group_actions.get(gname, {})
		precise = race._precise_action(String(g["kind"]), act)
	return {
		"lead": snappedf(lead, 0.1),
		"passed": passed,
		"fail": fail,
		"oxygen_used": snappedf(Tuning.OXYGEN_MAX - GameManager.oxygen, 0.01),
		"dy": snappedf(race.turtle.position.y - Tuning.NEUTRAL_DEPTH, 0.1),
		"speed_ratio": snappedf(race.turtle.speed / maxf(race.turtle.base_speed, 1.0), 0.01),
		"riding": riding,
		"precise": precise,
	}


func _summarize(trials: Array, v: float, scheme: String) -> Dictionary:
	var pass_trials: Array = []
	var fails := {}
	for t in trials:
		if bool(t["passed"]):
			pass_trials.append(t)
		else:
			var f := String(t["fail"])
			fails[f] = int(fails.get(f, 0)) + 1
	var lead_min := 0.0
	var lead_max := 0.0
	var ox_min := 0.0
	var ox_max := 0.0
	var dy_min := 0.0
	var dy_max := 0.0
	var precise := 0
	if not pass_trials.is_empty():
		lead_min = float(pass_trials[0]["lead"])
		lead_max = float(pass_trials[pass_trials.size() - 1]["lead"])
		ox_min = 999.0
		ox_max = -999.0
		dy_min = 999.0
		dy_max = -999.0
		for t in pass_trials:
			ox_min = minf(ox_min, float(t["oxygen_used"]))
			ox_max = maxf(ox_max, float(t["oxygen_used"]))
			dy_min = minf(dy_min, float(t["dy"]))
			dy_max = maxf(dy_max, float(t["dy"]))
			if bool(t["precise"]):
				precise += 1
	var window_s := 0.0
	if pass_trials.size() > 1:
		window_s = (lead_max - lead_min) / v
	return {
		"scheme": scheme,
		"trials": trials.size(),
		"pass_count": pass_trials.size(),
		"success_rate": snappedf(float(pass_trials.size()) / float(maxi(trials.size(), 1)), 0.001),
		"lead_min": lead_min,
		"lead_max": lead_max,
		"window_s": snappedf(window_s, 0.001),
		"fail_channels": fails,
		"oxygen_min": 0.0 if pass_trials.is_empty() else snappedf(ox_min, 0.01),
		"oxygen_max": 0.0 if pass_trials.is_empty() else snappedf(ox_max, 0.01),
		"dy_min": 0.0 if pass_trials.is_empty() else snappedf(dy_min, 0.1),
		"dy_max": 0.0 if pass_trials.is_empty() else snappedf(dy_max, 0.1),
		"precise_count": precise,
		"trials_data": trials,
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
	race.group_actions.clear()
	# 每个 trial 从 CALM 起跑，避免前面的神游量残留改变本次输入的速度/位置。
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
		"note": "海鸟四路线：真实按键、加速带关闭、基速；自动驾驶代理，不是真人。",
		"cases": rows,
	}
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
		f.close()


func _finish(code: int) -> void:
	get_tree().quit(code)
