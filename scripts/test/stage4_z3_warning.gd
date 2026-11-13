extends Node
## 阶段 4 P1-6 验收（TBB-SHIFT-FEEL-03）：Z3 复杂障碍的远距预警。
##
## 真实 race.tscn + 真实物理：
##   log5  —— 从 42700 出发，1300 px（Z3 260 px/s = 5.0 s）内首次亮预警；
##   wall3 —— 同样窗口，且高墙用自己的图标/颜色；
##   z2    —— Zone 2 里同样近距离的浮木不亮（预警只在 Z3）；
##   位置  —— 图标钉在画面右缘（≤1080 px）、画在天空层（不压操作带）；
##   状态  —— 只暴露“前方最近一组”，通过后立即换下一组或熄灭。
##
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT \
##       res://scenes/stage4_z3_warning.tscn
## 输出：docs/reports/longrun/phase-v-z3-warning.json

const LevelData = preload("res://scripts/systems/level_data.gd")
const OUT_PATH := "res://docs/reports/longrun/phase-v-z3-warning.json"
const Z3_SPEED := 260.0
const LOG5_X := 44110.0
const WALL3_X := 46370.0

var is_runner := false
var race
var sim := 0.0
var rows: Array = []
var failures: Array[String] = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4Z3WarningRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 4.0
	await get_tree().process_frame
	await _run()


func _run() -> void:
	GameManager.start_race()
	for i in 3:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null:
		_check(false, "formal race scene loaded")
		_finish()
		return
	race.test_no_finish = true
	race.test_disable_hazards = false

	for case_name in ["log5", "wall3", "zone2_only"]:
		race.load_level(LevelData.groups(), LevelData.boost_lanes())
		await get_tree().physics_frame
		sim = 0.0
		match case_name:
			"log5":
				rows.append(await _case_log5())
			"wall3":
				rows.append(await _case_wall3())
			"zone2_only":
				rows.append(await _case_zone2_only())

	Engine.time_scale = 1.0
	_write_json()
	_finish()


func _case_log5() -> Dictionary:
	_reset(42700.0)
	var d_start: float = LOG5_X - race.turtle.position.x
	var inactive_at_start: bool = not race.z3_warn_active()
	var first_x := 0.0
	var first_d := 0.0
	var guard := 0
	while guard < 120 and not race.z3_warn_active():
		await _step()
		guard += 1
	if race.z3_warn_active():
		first_x = race.turtle.position.x
		first_d = float(race.z3_warn_dist)
	var group: String = race.z3_warn_group
	var kind: String = race.z3_warn_kind
	var icon_x: float = minf(LOG5_X - 50.0, first_x + 1080.0)
	var edge_off: float = icon_x - first_x
	var lead_s: float = first_d / Z3_SPEED
	var checks := {
		"inactive_before_range": inactive_at_start and d_start > 1300.0,
		"fires": race.z3_warn_active(),
		"nearest_complex_is_log5": group == "log5",
		"kind_is_log": kind == "FLOATING_LOG",
		"lead_about_5s": lead_s >= 4.5 and lead_s <= 5.1,
		"only_edge_or_before": first_d <= 1310.0 and first_d >= 1240.0,
		"icon_at_screen_edge": edge_off >= 950.0 and edge_off <= 1080.0,
		"icon_in_sky_layer": race.Z3_ICON_Y < 240.0,
	}
	var data := {
		"first_x": snappedf(first_x, 1.0), "first_dist": snappedf(first_d, 1.0),
		"lead_s": snappedf(lead_s, 0.01), "group": group, "kind": kind,
		"icon_edge_offset": snappedf(edge_off, 1.0), "icon_y": race.Z3_ICON_Y,
	}
	# 通过后必须换组/熄灭：把 log5 标成已通过，下一组 complex 是 3700 px 外的 wall3，
	# 超出 1300 px 窗口 → 应该立即熄灭（不会提前暴露 wall3）。
	race.passed_groups["log5"] = true
	await _step()
	await _step()
	checks["clears_after_pass"] = not race.z3_warn_active()
	data["after_pass_group"] = race.z3_warn_group
	return _row("log5", 42700.0, checks, data)


func _case_wall3() -> Dictionary:
	_reset(45000.0)
	var d_start: float = WALL3_X - race.turtle.position.x
	var inactive_at_start: bool = not race.z3_warn_active()
	var first_d := 0.0
	var guard := 0
	while guard < 120 and not race.z3_warn_active():
		await _step()
		guard += 1
	if race.z3_warn_active():
		first_d = float(race.z3_warn_dist)
	var lead_s: float = first_d / Z3_SPEED
	var checks := {
		"inactive_before_range": inactive_at_start and d_start > 1300.0,
		"fires": race.z3_warn_active(),
		"nearest_complex_is_wall3": race.z3_warn_group == "wall3",
		"kind_is_wall": race.z3_warn_kind == "HIGH_WALL",
		"lead_about_5s": lead_s >= 4.5 and lead_s <= 5.1,
	}
	return _row("wall3", 45000.0, checks, {
		"first_dist": snappedf(first_d, 1.0), "lead_s": snappedf(lead_s, 0.01),
		"group": race.z3_warn_group, "kind": race.z3_warn_kind,
	})


func _case_zone2_only() -> Dictionary:
	# log3 在 30550：离 30000 只有 550 px，若预警不限 Z3 会立刻亮。
	_reset(30000.0)
	var d: float = 30550.0 - race.turtle.position.x
	await _step()
	await _step()
	var checks := {
		"in_zone2": int(race.current_zone["id"]) == 2,
		"near_complex_present": d < 1300.0,
		"no_warning_in_zone2": not race.z3_warn_active(),
	}
	return _row("zone2_only", 30000.0, checks, {
		"dist_to_log3": snappedf(d, 1.0), "warn_group": race.z3_warn_group,
	})


# ---------------- 工具 ----------------

func _reset(x: float) -> void:
	_release_all()
	sim = 0.0
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.oxygen = 8.0
	GameManager.showtime_active = false
	GameManager.current_control = "turtle"
	GameManager.has_shifted = true
	GameManager.bro_meter = 0
	race.showtime_active = false
	race.finishing = false
	race.hazard_cooldown = 0.0
	race.turtle_repair = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.rabbit_stun = 0.0
	race.combo = 0
	# G20：hit_roles 必须和 hit_groups 一起清。只清 hit_groups 时，B2 起的“角色×组”记账还留着，同组第二例起整组免疫——后面那些重复用例其实在测一段不会撞的赛道。
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.group_actions.clear()
	race.z3_warn_group = ""
	race.z3_warn_kind = ""
	race.z3_warn_dist = -1.0
	var zone: Dictionary = LevelData.zone_at(x)
	race.current_zone = zone
	var speed: float = float(zone["base_speed"])
	race.turtle.reset(Vector2(x, 334.0))
	race.turtle.speed = speed
	race.turtle.base_speed = speed
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()


func _release_all() -> void:
	for a in ["up", "down", "shift"]:
		Input.action_release(a)


func _step() -> void:
	await get_tree().physics_frame
	sim += (1.0 / 60.0) * Engine.time_scale


func _row(name: String, start_x: float, checks: Dictionary, data: Dictionary) -> Dictionary:
	var ok := true
	for k in checks:
		if not bool(checks[k]):
			ok = false
			_check(false, "%s: %s" % [name, k])
	var row := {"case": name, "start_x": start_x, "checks": checks, "pass": ok}
	for k in data:
		row[k] = data[k]
	print("Z3 WARN %-12s pass=%s %s" % [name, str(ok), str(checks)])
	return row


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)


func _write_json() -> void:
	var data := {
		"generated_at": Time.get_datetime_string_from_system(),
		"note": "P1-6 Z3 early warning: real race physics; icon geometry measured from state, not screenshots.",
		"warn_range_px": 1300.0, "edge_px": 1080.0,
		"rows": rows,
	}
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
		f.close()


func _finish() -> void:
	if failures.is_empty():
		print("STAGE4 Z3 WARNING: PASS")
	else:
		print("STAGE4 Z3 WARNING: FAIL")
		for item in failures:
			print("  - " + item)
	get_tree().quit(0 if failures.is_empty() else 1)
