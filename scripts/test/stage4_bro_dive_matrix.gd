extends Node
## TBB-SHIFT-CORE-02 §7：BRO DIVE 与接人多因子验收（只读，不改玩法）。
##
## 单靠一个“完美时间序列”不算验收。这里同时扫：
##   起跳距离 lead × SHIFT 时机 delay × 下潜持续时间 release × 物理帧率 hz
## 并逐 trial 记录：兔子落点、接人吸附距离、跳跃与下潜并行的帧数、失败通道。
##
## 用法：
##   D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
##       res://scenes/stage4_bro_dive_matrix.tscn > docs/reports/logs/phase-shift/bro-dive-matrix.log 2>&1
##
## 输出：docs/reports/longrun/shift02-bro-dive-matrix.json

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/shift02-bro-dive-matrix.json"
const LOGS := [8, 24, 52]
const LEADS := [140.0, 160.0, 180.0, 200.0, 220.0]
const DELAYS := [0.0, 0.1, 0.2, 0.3, 0.4]
const RELEASES := [-40.0, 0.0, 40.0, 80.0]
const CORE_HZ := 60.0
const HZ_SET := [30.0, 60.0, 120.0]

var is_runner := false
var race: Node = null
var sim := 0.0
var step_hz := 60.0
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
	_set_hz(CORE_HZ)
	await get_tree().process_frame
	await _run()


func _set_hz(hz: float) -> void:
	step_hz = hz
	Engine.physics_ticks_per_second = int(hz * Engine.time_scale)


func _run() -> void:
	GameManager.start_race()
	for i in 3:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null:
		push_error("DIVE: no current scene")
		_finish(1)
		return
	race.test_disable_hazards = false
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()
	await get_tree().physics_frame

	var groups: Array = race.hazard_groups
	print("DIVE matrix logs=%d leads=%d delays=%d releases=%d hz=%s" % [
		LOGS.size(), LEADS.size(), DELAYS.size(), RELEASES.size(), str(HZ_SET)])
	sim = 0.0
	for gi in LOGS:
		var g: Dictionary = groups[gi]
		var start: float = race._group_start(g)
		var end: float = race._group_end(g)
		var zone: Dictionary = LevelData.zone_at(start)
		var v: float = float(zone["base_speed"])
		var entry := {
			"index": gi, "group": String(g["group"]), "kind": String(g["kind"]),
			"zone": int(zone["id"]), "base_speed": v,
			"core": [], "frame_rates": [],
		}
		print("CASE g=%02d %s z%d v=%.0f" % [gi, String(g["group"]), int(zone["id"]), v])
		_set_hz(CORE_HZ)
		for lead in LEADS:
			for delay in DELAYS:
				for release in RELEASES:
					var r: Dictionary = await _run_case(g, lead, delay, release,
						start, end, zone)
					r["lead"] = lead
					r["delay"] = delay
					r["release"] = release
					entry["core"].append(r)
		# 帧率：以核心矩阵里通过数最多的组合为基准，各帧率再跑一遍。
		var best := _best_combo(entry["core"])
		if best.is_empty():
			print("  no core pass; frame-rate sweep skipped")
		else:
			for hz in HZ_SET:
				_set_hz(hz)
				for release in RELEASES:
					var r2: Dictionary = await _run_case(g, float(best["lead"]),
						float(best["delay"]), release, start, end, zone)
					r2["hz"] = hz
					r2["lead"] = best["lead"]
					r2["delay"] = best["delay"]
					r2["release"] = release
					entry["frame_rates"].append(r2)
			_set_hz(CORE_HZ)
			print("  best lead=%.0f delay=%.1f" % [
				float(best["lead"]), float(best["delay"])])
		_print_entry(entry)
		rows.append(entry)
		_write()
	_write()
	print("DIVE: DONE")
	_finish(0)


func _run_case(g: Dictionary, lead: float, delay: float, release: float,
		start: float, end: float, zone: Dictionary) -> Dictionary:
	var gname := String(g["group"])
	_reset(start - lead, zone)
	var t0 := sim
	var jumped := false
	var jumped_t := -1.0
	var shifted := false
	var down_held := false
	var was_air := false
	var landed := false
	var land_x := -1.0
	var snap_px := -1.0
	var parallel_frames := 0
	var prev_rabbit: Vector2 = race.rabbit.position
	var water := false
	var rabbit_hit := false
	var turtle_hit := false
	var pickup_t := -1.0
	var steps := 0
	while sim - t0 < 6.0 and steps < 900:
		var x: float = race.turtle.position.x
		if x > end + 220.0:
			break
		if not jumped and x >= start - lead:
			_control("rabbit"); _press("up")
			jumped = true
			jumped_t = sim
		elif jumped and not shifted and sim - jumped_t >= delay - 0.001:
			if race.mount.state == "AIRBORNE":
				_release("up"); _control("turtle"); _press("down")
				shifted = true
				down_held = true
			elif sim - jumped_t > delay + 0.20:
				shifted = true
		var air_before: bool = race.mount.state == "AIRBORNE"
		prev_rabbit = race.rabbit.position
		await _step()
		steps += 1
		x = race.turtle.position.x
		if race.mount.state == "AIRBORNE":
			was_air = true
			if race.turtle.position.y > Tuning.NEUTRAL_DEPTH + 30.0:
				parallel_frames += 1
		elif was_air and not landed:
			landed = true
			land_x = race.rabbit.position.x
			if air_before:
				snap_px = prev_rabbit.distance_to(race.turtle.get_mount_point())
			pickup_t = sim - jumped_t
		if down_held and x >= end + release:
			_release("down")
			down_held = false
		var rrect: Rect2 = race.rabbit.get_body_rect()
		var trect: Rect2 = race.turtle.get_body_rect()
		for rr in g["rects"]:
			var rect: Rect2 = rr
			if rect.grow(-3.0).intersects(rrect):
				rabbit_hit = true
			if rect.grow(-3.0).intersects(trect):
				turtle_hit = true
		if GameManager.accident_state == "RABBIT_WATER":
			water = true
	# 落地判据：越过尾端 150 px、没撞、没落水、还在壳上、确实被接过一次。
	var ended_x: float = race.turtle.position.x
	var riding: bool = race.mount.state == "RIDING"
	var hit: bool = bool(race.hit_groups.has(gname))
	var passed := ended_x > end + 150.0 and not hit and not water and riding \
		and pickup_t >= 0.0
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
		elif pickup_t < 0.0:
			fail = "never_landed"
		else:
			fail = "incomplete"
	_release_all()
	return {
		"passed": passed,
		"fail": fail,
		"land_dx_end": snappedf(land_x - end, 0.1) if land_x >= 0.0 else -999.0,
		"snap_px": snappedf(snap_px, 0.1),
		"pickup_s": snappedf(pickup_t, 0.01),
		"parallel_frames": parallel_frames,
		"oxygen_used": snappedf(Tuning.OXYGEN_MAX - GameManager.oxygen, 0.01),
	}


func _best_combo(core: Array) -> Dictionary:
	var counts := {}
	var keys := {}
	for r in core:
		var k := "%d|%d" % [int(round(float(r["lead"]) / 10.0)),
			int(round(float(r["delay"]) * 10.0))]
		keys[k] = r
		if bool(r["passed"]):
			counts[k] = int(counts.get(k, 0)) + 1
	var best_k := ""
	var best_n := 0
	for k in counts:
		if int(counts[k]) > best_n:
			best_n = int(counts[k])
			best_k = k
	if best_k == "":
		return {}
	var r: Dictionary = keys[best_k]
	return {"lead": r["lead"], "delay": r["delay"], "pass_count": best_n}


func _print_entry(e: Dictionary) -> void:
	var pass_core := 0
	var fails := {}
	var snaps: Array = []
	var lands: Array = []
	var parallel_min := 999
	for r in e["core"]:
		if bool(r["passed"]):
			pass_core += 1
			snaps.append(float(r["snap_px"]))
			lands.append(float(r["land_dx_end"]))
			parallel_min = mini(parallel_min, int(r["parallel_frames"]))
		else:
			var f := String(r["fail"])
			fails[f] = int(fails.get(f, 0)) + 1
	print("  CORE pass=%d/%d fail=%s" % [pass_core, e["core"].size(), str(fails)])
	if not snaps.is_empty():
		snaps.sort()
		lands.sort()
		print("    snap_px %.0f..%.0f  land_dx_end %.0f..%.0f  parallel_frames>=%d" % [
			float(snaps[0]), float(snaps[snaps.size() - 1]),
			float(lands[0]), float(lands[lands.size() - 1]), parallel_min])
	for r in e["frame_rates"]:
		print("    hz=%3.0f release=%+4.0f pass=%s fail=%s snap=%.0f" % [
			float(r["hz"]), float(r["release"]), str(bool(r["passed"])),
			String(r["fail"]), float(r["snap_px"])])


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
		"note": "BRO DIVE 多因子：真实按键、加速带关闭、基速；引擎内输入代理，不是真人。",
		"cases": rows,
	}
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
		f.close()


func _finish(code: int) -> void:
	get_tree().quit(code)
