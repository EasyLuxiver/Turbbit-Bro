extends Node
## 阶段 4 数值基线：可复现地测量并记录玩法数值，改动前后用同一脚本对比。
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT res://scenes/stage4_metrics.tscn
## 输出：docs/reports/stage4-metrics.json

const Tuning = preload("res://scripts/systems/tuning.gd")
const LevelDataScript = preload("res://scripts/systems/level_data.gd")
const RaceScript = preload("res://scripts/race.gd")
const RabbitScript = preload("res://scripts/actors/rabbit_controller.gd")
const TurtleScript = preload("res://scripts/actors/turtle_controller.gd")
const MountScript = preload("res://scripts/systems/mount_controller.gd")
const OUT_PATH := "res://docs/reports/stage4-metrics.json"

var is_runner := false
var failures: Array[String] = []
var data := {}


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4MetricsRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	data["measured_at"] = Time.get_datetime_string_from_system()
	data["jump"] = _measure_jump()
	data["turtle"] = _measure_turtle()
	data["pickup"] = _measure_pickup()
	data["oxygen"] = _measure_oxygen()
	data["reaction"] = _measure_reaction()
	data["recovery"] = _measure_recovery()
	data["gaps"] = _measure_gaps()
	data["showtime"] = _measure_showtime()
	_write_json()

	if failures.is_empty():
		print("STAGE4 METRICS: PASS")
		get_tree().quit(0)
	else:
		print("STAGE4 METRICS: FAIL")
		for item in failures:
			print("  - " + item)
		get_tree().quit(1)


func _measure_jump() -> Dictionary:
	var rabbit = RabbitScript.new()
	rabbit.launch(Vector2.ZERO, 220.0)
	var frames := 0
	var apex := 0.0
	while frame_ok(frames):
		rabbit.tick_air(1.0 / 60.0, false)
		frames += 1
		apex = maxf(apex, -rabbit.position.y)
		if frames > 5 and rabbit.position.y >= 0.0 and rabbit.velocity.y > 0.0:
			break
	var airtime := float(frames) / 60.0
	rabbit.free()
	# 阶段 4 把跳跃调成“能跨过组合漂浮物的整个上沿”：v=700 g=700 -> 2.0 s / 350 px。
	var expect_air: float = 2.0 * (-RabbitScript.JUMP_VELOCITY) / RabbitScript.GRAVITY
	var expect_apex: float = pow(-RabbitScript.JUMP_VELOCITY, 2.0) 		/ (2.0 * RabbitScript.GRAVITY)
	var result := {
		"jump_velocity": -RabbitScript.JUMP_VELOCITY,
		"gravity": RabbitScript.GRAVITY,
		"airtime_s": snappedf(airtime, 0.01),
		"apex_px": snappedf(apex, 0.1),
		"air_forward_at_220": snappedf(airtime * 220.0, 1.0),
		"air_forward_at_330": snappedf(airtime * 330.0, 1.0),
	}
	_check(absf(airtime - expect_air) < 0.06,
		"jump airtime matches v/g = %.2f s (%.2f)" % [expect_air, airtime])
	_check(absf(apex - expect_apex) < 6.0,
		"jump apex matches v^2/2g = %.0f px (%.1f)" % [expect_apex, apex])
	print("  jump   -> airtime %.2fs apex %.1fpx" % [airtime, apex])
	return result


func frame_ok(frames: int) -> bool:
	return frames < 600


func _measure_turtle() -> Dictionary:
	var turtle = TurtleScript.new()
	turtle.reset(Vector2.ZERO)
	var base_target: float = 220.0
	for i in 60:
		turtle.tick(1.0 / 60.0, true, false, 0.0, false, Tuning.BOOST_SPEED)
	var base_speed: float = turtle.speed

	var boost_time := 0.0
	while turtle.speed < Tuning.BOOST_SPEED - 0.01 and boost_time < 2.0:
		turtle.tick(1.0 / 60.0, true, true, 0.0, false, Tuning.BOOST_SPEED)
		boost_time += 1.0 / 60.0
	var boost_speed: float = turtle.speed

	# 冲浪板模型的三条基线：待命不沉、按住 ↓ 1 s 潜到多深、松手后回到巡航要多久。
	turtle.reset(Vector2(0.0, Tuning.NEUTRAL_DEPTH))
	for i in 60:
		turtle.tick(1.0 / 60.0, false, false, 0.0, false, Tuning.BOOST_SPEED)
	var standby_drift: float = absf(turtle.position.y - Tuning.NEUTRAL_DEPTH)

	turtle.reset(Vector2(0.0, Tuning.NEUTRAL_DEPTH))
	for i in 60:
		turtle.tick(1.0 / 60.0, true, false, 1.0, false, Tuning.BOOST_SPEED)
	var dive_1s: float = turtle.position.y - Tuning.NEUTRAL_DEPTH

	turtle.reset(Vector2(0.0, 520.0))
	var rise_frames := 0
	while absf(turtle.position.y - Tuning.NEUTRAL_DEPTH) >= 2.0 and rise_frames < 240:
		turtle.tick(1.0 / 60.0, true, false, 0.0, false, Tuning.BOOST_SPEED)
		rise_frames += 1
	var surface_y: float = turtle.position.y
	var rise_s := float(rise_frames) / 60.0
	turtle.free()

	var result := {
		"base_speed_z1": base_target,
		"base_speed_z2": 240.0,
		"base_speed_z3": 260.0,
		"boost_speed": Tuning.BOOST_SPEED,
		"snack_boost_scale": LevelDataScript.SNACK_BOOST_SCALE,
		"accel_up": 420.0,
		"accel_down": 300.0,
		"boost_reach_time_s": snappedf(boost_time, 0.01),
		"neutral_depth": Tuning.NEUTRAL_DEPTH,
		"sink_relax_slow_fast": [Tuning.SINK_RELAX, Tuning.SINK_SLOW, Tuning.SINK_FAST],
		"standby_drift_px": snappedf(standby_drift, 0.1),
		"dive_1s_px": snappedf(dive_1s, 1.0),
		"buoyancy_return_s": snappedf(rise_s, 0.01),
		"buoyancy_return_y": snappedf(surface_y, 0.1),
	}
	_check(is_equal_approx(base_speed, base_target), "turtle cruises at zone base speed")
	_check(is_equal_approx(boost_speed, Tuning.BOOST_SPEED), "turtle reaches boost speed")
	# 阶段 4：待命不再自动下沉（旧模型的失控沉降已移除），深度只由 ↓ 决定。
	_check(standby_drift < 1.0, "standby shell holds cruise depth (%.1f px)" % standby_drift)
	_check(dive_1s > Tuning.DIVE_DEPTH * 0.85 and dive_1s <= Tuning.DIVE_DEPTH + 0.5,
		"1 s of ↓ reaches %.0f of %.0f px" % [dive_1s, Tuning.DIVE_DEPTH])
	_check(absf(surface_y - Tuning.NEUTRAL_DEPTH) < 2.0 and rise_s < 2.0,
		"buoyancy returns to cruise depth in %.2f s (%.1f)" % [rise_s, surface_y])
	_check(LevelDataScript.SNACK_BOOST_SCALE >= 1.10 and LevelDataScript.SNACK_BOOST_SCALE <= 1.25,
		"snack boost is a 10-25% one-encounter bump")
	print("  turtle -> base %.0f boost %.0f(%.2fs) standby %.1fpx dive1s %.0fpx rise %.2fs" % [
		base_speed, boost_speed, boost_time, standby_drift, dive_1s, rise_s])
	return result


func _measure_pickup() -> Dictionary:
	var mount = MountScript.new()
	mount.mark_airborne()
	var dx_ok: bool = mount.can_pickup(Vector2(Tuning.PICKUP_DX, 0), 10.0, Vector2.ZERO, true)
	var dx_bad: bool = mount.can_pickup(Vector2(Tuning.PICKUP_DX + 1.0, 0), 10.0, Vector2.ZERO, true)
	var dy_low: bool = mount.can_pickup(Vector2(0, Tuning.PICKUP_DY_MIN), 10.0, Vector2.ZERO, true)
	var dy_low_bad: bool = mount.can_pickup(
		Vector2(0, Tuning.PICKUP_DY_MIN - 1.0), 10.0, Vector2.ZERO, true)
	var dy_high: bool = mount.can_pickup(Vector2(0, Tuning.PICKUP_DY_MAX), 10.0, Vector2.ZERO, true)
	var dy_high_bad: bool = mount.can_pickup(
		Vector2(0, Tuning.PICKUP_DY_MAX + 1.0), 10.0, Vector2.ZERO, true)
	var rising: bool = mount.can_pickup(Vector2.ZERO, -1.0, Vector2.ZERO, true)
	var deep_turtle: bool = mount.can_pickup(Vector2.ZERO, 10.0, Vector2.ZERO, false)
	mount.free()
	var result := {
		"dx": Tuning.PICKUP_DX, "dy_min": Tuning.PICKUP_DY_MIN,
		"dy_max": Tuning.PICKUP_DY_MAX, "snap_dx": Tuning.PICKUP_SNAP_DX,
		"window_time_at_220_s": snappedf((Tuning.PICKUP_DX * 2.0) / 220.0, 0.01),
	}
	_check(dx_ok and not dx_bad, "pickup dx boundary 120")
	_check(dy_low and not dy_low_bad, "pickup dy min boundary -60")
	_check(dy_high and not dy_high_bad, "pickup dy max boundary 90")
	_check(not rising, "pickup rejects rising rabbit")
	_check(not deep_turtle, "pickup rejects turtle below surface")
	print("  pickup -> dx 120, dy -60..90, snap 70")
	return result


func _measure_oxygen() -> Dictionary:
	var drain_time := Tuning.OXYGEN_MAX / Tuning.OXYGEN_DRAIN
	var recover_time := Tuning.OXYGEN_MAX / Tuning.OXYGEN_RECOVER
	var result := {
		"max_s": Tuning.OXYGEN_MAX,
		"low_s": Tuning.OXYGEN_LOW,
		"critical_s": Tuning.OXYGEN_CRITICAL,
		"drain_per_s": Tuning.OXYGEN_DRAIN,
		"recover_per_s": Tuning.OXYGEN_RECOVER,
		"recovered_after_accident_s": Tuning.OXYGEN_RECOVERED,
		"full_drain_s": snappedf(drain_time, 0.01),
		"full_recover_s": snappedf(recover_time, 0.01),
		"max_dive_time_with_recovery": snappedf(
			Tuning.OXYGEN_MAX / Tuning.OXYGEN_DRAIN
			+ Tuning.OXYGEN_RECOVERED / Tuning.OXYGEN_DRAIN, 0.1),
	}
	_check(Tuning.OXYGEN_LOW < Tuning.OXYGEN_MAX, "oxygen LOW below max")
	_check(Tuning.OXYGEN_CRITICAL < Tuning.OXYGEN_LOW, "oxygen CRITICAL below LOW")
	print("  oxygen -> %.1fs dive, %.1fs refill, empty->full %.2fs" % [
		drain_time, Tuning.OXYGEN_RECOVERED, recover_time])
	return result


func _measure_reaction() -> Dictionary:
	var rows := []
	for zone in LevelDataScript.ZONES:
		var base: float = zone["base_speed"]
		rows.append({
			"zone": zone["id"],
			"base_speed": base,
			"base_reaction_s_430": snappedf(430.0 / base, 0.01),
			"boost_reaction_s_430": snappedf(430.0 / Tuning.BOOST_SPEED, 0.01),
			"snack_reaction_s_430": snappedf(430.0 / (base * LevelDataScript.SNACK_BOOST_SCALE), 0.01),
			"base_reaction_s_270": snappedf(270.0 / base, 0.01),
			"boost_reaction_s_270": snappedf(270.0 / Tuning.BOOST_SPEED, 0.01),
		})
	var result := {
		"hud_warn_px": 430.0,
		"world_board_px": 270.0,
		"rows": rows,
	}
	for row in rows:
		_check(row["base_reaction_s_430"] >= 1.6,
			"zone %d gives >=1.6 s at base speed" % row["zone"])
	print("  react  -> Z1 %.2fs .. Z3 %.2fs at HUD warn range (base)" % [
		rows[0]["base_reaction_s_430"], rows[2]["base_reaction_s_430"]])
	return result


func _measure_recovery() -> Dictionary:
	var result := {
		"stun_s": Tuning.STUN_TIME,
		"rescue_s": Tuning.RESCUE_TIME,
		"repair_s": Tuning.REPAIR_TIME,
		"emergency_s": Tuning.EMERGENCY_TIME,
		"hazard_cooldown_s": Tuning.HAZARD_COOLDOWN,
		"turtle_cooldown_s": Tuning.TURTLE_COOLDOWN,
		"grace_s": Tuning.GRACE_TIME,
	}
	_check(Tuning.TURTLE_COOLDOWN >= Tuning.REPAIR_TIME + Tuning.GRACE_TIME,
		"turtle cooldown covers repair + grace")
	print("  recover-> stun %.1fs rescue %.1fs repair %.1fs emergency %.1fs" % [
		Tuning.STUN_TIME, Tuning.RESCUE_TIME, Tuning.REPAIR_TIME, Tuning.EMERGENCY_TIME])
	return result


# ---- 空档：按“上一个障碍末端 -> 下一个障碍起点”算真实空闲距离。 ----

func _measure_gaps() -> Dictionary:
	var current: Array = LevelDataScript.groups()
	var result := {"zones": {}}
	for zone in LevelDataScript.ZONES:
		result["zones"][str(zone["id"])] = _zone_gaps(current, zone)

	var z1: Dictionary = result["zones"]["1"]
	var z2: Dictionary = result["zones"]["2"]
	var z3: Dictionary = result["zones"]["3"]
	_check(z1["groups_per_min"] < z2["groups_per_min"]
		and z2["groups_per_min"] < z3["groups_per_min"],
		"density rises %.1f < %.1f < %.1f groups/min" % [
			z1["groups_per_min"], z2["groups_per_min"], z3["groups_per_min"]])
	for pair in [["1", z1], ["2", z2], ["3", z3]]:
		_check(pair[1]["longest_empty_s"] <= 6.0,
			"zone %s longest empty stretch <= 6 s (%.2f at %s)" % [
				pair[0], pair[1]["longest_empty_s"], pair[1]["longest_empty_at"]])

	# 基线：单角色 ≥3.5 s、组合 ≥5 s（与 stage4_proto 的实测口径一致）。
	var speed_by_zone := {1: 220.0, 2: 240.0, 3: 260.0}
	var min_single := 1.0e9
	var min_combo := 1.0e9
	var prev_end := 0.0
	for g in current:
		var gap_s: float = (LevelDataScript.group_start(g) - prev_end) 			/ speed_by_zone[int(g["zone"])]
		if g["kind"] == "FLOATING_LOG":
			min_combo = minf(min_combo, gap_s)
		else:
			min_single = minf(min_single, gap_s)
		prev_end = LevelDataScript.group_end(g)
	result["min_single_gap_s"] = snappedf(min_single, 0.01)
	result["min_combo_gap_s"] = snappedf(min_combo, 0.01)
	_check(min_single >= 3.5,
		"every single-role obstacle has >= 3.5 s from the previous tail (min %.2f)" % min_single)
	_check(min_combo >= 5.0,
		"every combined obstacle has >= 5 s from the previous tail (min %.2f)" % min_combo)
	print("  gaps   -> Z1 %.1f  Z2 %.1f  Z3 %.1f groups/min; min %.2fs single / %.2fs combo" % [
		z1["groups_per_min"], z2["groups_per_min"], z3["groups_per_min"],
		min_single, min_combo])
	return result


func _zone_gaps(groups: Array, zone: Dictionary) -> Dictionary:
	var base: float = zone["base_speed"]
	var list := []
	for g in groups:
		if int(g["zone"]) == int(zone["id"]):
			list.append(g)
	var gaps := []
	# Zone 1 从正式出发位置量空档：0～RACE_START_X 是起跑线前的布景，玩家不经过。
	var prev_end: float = maxf(float(zone["start"]), float(LevelDataScript.RACE_START_X))
	var prev_name := "ZONE_START"
	var longest := 0.0
	var longest_at := ""
	for g in list:
		var start := LevelDataScript.group_start(g)
		var end := LevelDataScript.group_end(g)
		var px := start - prev_end
		var seconds := px / base
		gaps.append({"from": prev_name, "to": g["group"], "px": snappedf(px, 1.0),
			"seconds": snappedf(seconds, 0.01)})
		if seconds > longest:
			longest = seconds
			longest_at = "%s -> %s" % [prev_name, g["group"]]
		prev_end = end
		prev_name = g["group"]
	var tail_px: float = zone["end"] - prev_end
	var tail_s := tail_px / base
	gaps.append({"from": prev_name, "to": "ZONE_END", "px": snappedf(tail_px, 1.0),
		"seconds": snappedf(tail_s, 0.01)})
	if tail_s > longest:
		longest = tail_s
		longest_at = "%s -> ZONE_END" % prev_name
	var minutes: float = (zone["end"] - zone["start"]) / base / 60.0
	return {
		"groups": list.size(),
		"duration_s": snappedf(minutes * 60.0, 0.1),
		"groups_per_min": snappedf(float(list.size()) / minutes, 0.01),
		"longest_empty_s": snappedf(longest, 0.01),
		"longest_empty_at": longest_at,
		"gaps": gaps,
	}


func _groups_in(groups: Array, from_x: float, to_x: float) -> Array:
	var out := []
	for g in groups:
		var start := LevelDataScript.group_start(g)
		if start >= from_x and start <= to_x:
			out.append(g["group"])
	return out


func _measure_showtime() -> Dictionary:
	var total: int = LevelDataScript.groups().size()
	var result := {
		"combo_required": Tuning.SHOWTIME_COMBO,
		"showtime_duration_s": Tuning.SHOWTIME_TIME,
		"max_triggers_clean_run": total / Tuning.SHOWTIME_COMBO,
		"measured_stage3_triggers": 18,
		"measured_stage3_time_s": 296.63,
		"measured_per_min": snappedf(18.0 / (296.63 / 60.0), 2),
	}
	_check(total / Tuning.SHOWTIME_COMBO == 18, "55 groups -> up to 18 Showtimes")
	print("  show   -> %.1fs, every %d clean passes, max 18 per run" % [
		Tuning.SHOWTIME_TIME, Tuning.SHOWTIME_COMBO])
	return result


func _write_json() -> void:
	var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if file == null:
		_check(false, "metrics json writable")
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	print("  file   -> %s" % ProjectSettings.globalize_path(OUT_PATH))


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok  " + message)
	else:
		failures.append(message)
		print("  FAIL " + message)
