extends Node
## TBB-EXPERIENCE-REFINE-06 P6：55 组节奏复审（只读，不改游戏状态）。
##
## 用正式关卡数据（含默认种子的食物后障碍抽取）把整条赛道展开成一张表：
## 每组 → 区 / 种类 / 所需角色 / 起点 / 与上一组的间距（px 与秒）/ 是否动态；
## 再从这张表复算任务书 §八 的几条硬指标：
##   · 连续同类障碍、连续同一角色压力段（BOTH 打断）；
##   · 刚切换又必须切回（X→Y→X 且两段都短）；
##   · 超过 6.0 s 的空档、连续 3 组静态单角色的无操作段；
##   · 动态障碍行为种类与连续重复；
##   · 每个区的高操作占比（BOTH 或动态）、食物与互动分布。
##
## 输出：docs/reports/longrun/refine06-p6-rhythm.json
## 运行：godot --headless --path TURBBIT res://scenes/stage4_p6_rhythm.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")

const OUT_PATH := "res://docs/reports/longrun/refine06-p6-rhythm.json"
const RACE_START_X := 400.0
## 组间空档上限：3.5 s 是“单角色最小间距”基线，6.0 s 是会让人等得发困。
const MAX_GAP_S := 6.0
## “刚切换又必须切回”：两段都短才算，合计不超过 6 s。
const SWITCH_BACK_WINDOW_S := 6.0

var is_runner := false
var race: Node = null
var rows: Array = []
var out := {}
var failures: Array = []
var advisory: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4P6RhythmRunner"
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
		push_error("P6 RHYTHM: no race scene")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())

	var groups: Array = race.hazard_groups
	var prev_end := RACE_START_X
	for i in groups.size():
		var g: Dictionary = groups[i]
		var start := LevelData.group_start(g)
		var end := LevelData.group_end(g)
		var kind := String(g["kind"])
		var zone := int(g["zone"])
		var speed := _zone_speed(zone)
		var motion: Dictionary = g.get("motion", {})
		var motion_name := String(motion.get("name", ""))
		var gap_px := start - prev_end
		var gap_s := gap_px / speed
		rows.append({
			"i": i,
			"group": String(g["group"]),
			"zone": zone,
			"kind": kind,
			"role": LevelData.role_for_kind(kind),
			"start": start,
			"end": end,
			"speed": speed,
			"t": _time_at(start),
			"gap_px": gap_px,
			"gap_s": gap_s,
			"motion": motion_name,
			"dynamic": motion_name != "",
		})
		prev_end = end

	var snacks := _snack_rows(race._snack_list())
	var zones := _zone_stats(snacks)
	var run_stats := {
		"same_kind_runs": _same_kind_runs(),
		"same_role_runs": _same_role_runs(),
		"switch_backs": _switch_backs(),
		"long_gaps": _long_gaps(),
		"static_streaks": _static_streaks(),
		"motion_streaks": _motion_streaks(),
	}

	out = {
		"rows": rows,
		"snacks": snacks,
		"zones": zones,
		"run_stats": run_stats,
		"advisory": advisory,
		"constants": {
			"max_gap_s": MAX_GAP_S,
			"switch_back_window_s": SWITCH_BACK_WINDOW_S,
			"race_start_x": RACE_START_X,
		},
	}
	_evaluate()
	_print_table()
	_write()
	print("P6 RHYTHM: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _zone_speed(zid: int) -> float:
	for z in LevelData.ZONES:
		if int(z["id"]) == zid:
			return float(z["base_speed"])
	return 220.0


## 从起跑到 x 的估算时间：逐区按该区基础速度积分（不含食物加速，仅用于排节奏）。
func _time_at(x: float) -> float:
	var t := 0.0
	for z in LevelData.ZONES:
		var a := maxf(RACE_START_X, float(z["start"]))
		var b := float(z["end"])
		if x <= a:
			break
		t += (minf(x, b) - a) / float(z["base_speed"])
		if x <= b:
			break
	return t


func _snack_rows(list: Array) -> Array:
	var out := []
	for enc in list:
		var x := float(enc["x"])
		var zid := int(enc["zone"])
		var gname := String(enc["obstacle_group"])
		var role := "?"
		for r in rows:
			if String(r["group"]) == gname:
				role = String(r["role"])
				break
		out.append({
			"x": x, "zone": zid, "t": _time_at(x),
			"group": gname, "role": role,
		})
	return out


func _zone_stats(snacks: Array) -> Array:
	var out := []
	for z in LevelData.ZONES:
		var zid := int(z["id"])
		var list := []
		for r in rows:
			if int(r["zone"]) == zid:
				list.append(r)
		var dynamic := 0
		var both := 0
		var static_single := 0
		var kinds := {}
		var max_gap := 0.0
		var sum_gap := 0.0
		for r in list:
			if bool(r["dynamic"]):
				dynamic += 1
			if String(r["role"]) == "BOTH":
				both += 1
			if not bool(r["dynamic"]) and String(r["role"]) != "BOTH":
				static_single += 1
			kinds[String(r["kind"])] = int(kinds.get(String(r["kind"]), 0)) + 1
			max_gap = maxf(max_gap, float(r["gap_s"]))
			sum_gap += float(r["gap_s"])
		var snack_n := 0
		for s in snacks:
			if int(s["zone"]) == zid:
				snack_n += 1
		var n := list.size()
		out.append({
			"zone": zid,
			"name": String(z["name"]),
			"groups": n,
			"kinds": kinds,
			"dynamic": dynamic,
			"both": both,
			"static_single": static_single,
			"high_op": dynamic + both,
			"high_op_ratio": float(dynamic + both) / float(maxi(n, 1)),
			"max_gap_s": max_gap,
			"mean_gap_s": sum_gap / float(maxi(n, 1)),
			"snacks": snack_n,
			"first_t": float(list[0]["t"]) if n > 0 else 0.0,
			"last_t": float(list[n - 1]["t"]) if n > 0 else 0.0,
		})
	return out


func _same_kind_runs() -> Array:
	var out := []
	var run := 1
	for i in range(1, rows.size()):
		if String(rows[i]["kind"]) == String(rows[i - 1]["kind"]):
			run += 1
		else:
			if run >= 3:
				out.append(_kind_run(i, run))
			run = 1
	if run >= 3:
		out.append(_kind_run(rows.size(), run))
	return out


func _kind_run(end_i: int, run: int) -> Dictionary:
	var start_i := end_i - run
	return {
		"kind": String(rows[end_i - 1]["kind"]),
		"length": run,
		"from": String(rows[start_i]["group"]),
		"to": String(rows[end_i - 1]["group"]),
		"t": float(rows[start_i]["t"]),
	}


func _same_role_runs() -> Array:
	var out := []
	var run := 1
	for i in range(1, rows.size()):
		var same := String(rows[i]["role"]) == String(rows[i - 1]["role"])
		var single := String(rows[i]["role"]) != "BOTH"
		if same and single:
			run += 1
		else:
			if run >= 3:
				out.append(_role_run(i, run))
			run = 1
	if run >= 3:
		out.append(_role_run(rows.size(), run))
	return out


func _role_run(end_i: int, run: int) -> Dictionary:
	var start_i := end_i - run
	return {
		"role": String(rows[end_i - 1]["role"]),
		"length": run,
		"from": String(rows[start_i]["group"]),
		"to": String(rows[end_i - 1]["group"]),
		"t": float(rows[start_i]["t"]),
	}


func _switch_backs() -> Array:
	var out := []
	for i in range(1, rows.size() - 1):
		var a := String(rows[i - 1]["role"])
		var b := String(rows[i]["role"])
		var c := String(rows[i + 1]["role"])
		if a == "BOTH" or b == "BOTH" or c == "BOTH":
			continue
		if a != c or a == b:
			continue
		var span := float(rows[i]["gap_s"]) + float(rows[i + 1]["gap_s"])
		if span <= SWITCH_BACK_WINDOW_S:
			out.append({
				"pattern": "%s-%s-%s" % [a, b, c],
				"groups": [String(rows[i - 1]["group"]), String(rows[i]["group"]),
					String(rows[i + 1]["group"])],
				"span_s": span,
				"t": float(rows[i - 1]["t"]),
			})
	return out


func _long_gaps() -> Array:
	var out := []
	for r in rows:
		if float(r["gap_s"]) > MAX_GAP_S:
			out.append({
				"group": String(r["group"]),
				"gap_s": float(r["gap_s"]),
				"gap_px": float(r["gap_px"]),
				"t": float(r["t"]),
			})
	return out


## “无操作段”判定：连续 ≥3 组静态单角色，且这几组要求的是同一个角色。
## 静态但角色交替（例如 bird1 趴低 → rock1 跳 → gate1 下潜）每次都要换手，
## 不是无操作段；真正让人发困的是“站着按同一个键、看同一种东西”。
func _static_streaks() -> Array:
	var out := []
	var run := 0
	for i in rows.size():
		var r: Dictionary = rows[i]
		if not bool(r["dynamic"]) and String(r["role"]) != "BOTH":
			run += 1
		else:
			if run >= 3:
				_check_static_run(out, i, run)
			run = 0
	if run >= 3:
		_check_static_run(out, rows.size(), run)
	return out


func _check_static_run(out: Array, end_i: int, run: int) -> void:
	var start_i := end_i - run
	var role := String(rows[start_i]["role"])
	for j in range(start_i + 1, end_i):
		if String(rows[j]["role"]) != role:
			return
	out.append({
		"role": role,
		"length": run,
		"from": String(rows[start_i]["group"]),
		"to": String(rows[end_i - 1]["group"]),
		"t": float(rows[start_i]["t"]),
	})


func _motion_streaks() -> Array:
	var out := []
	var run := 1
	for i in range(1, rows.size()):
		var a := String(rows[i]["motion"])
		var b := String(rows[i - 1]["motion"])
		if a != "" and a == b:
			run += 1
		else:
			run = 1
		if run >= 3:
			out.append({
				"motion": String(rows[i]["motion"]),
				"length": run,
				"from": String(rows[i - run + 1]["group"]),
				"to": String(rows[i]["group"]),
			})
	return out


func _evaluate() -> void:
	# 自检：静态无操作段检测器本身要能抓到“三连兔子（静态）”。
	# 否则 static_streaks 为空时无法区分“真没有”与“检测器坏了”。
	if not _self_check_static():
		failures.append("static streak detector self-check failed")
	if rows.size() != 55:
		failures.append("row count %d != 55" % rows.size())
	var rs: Dictionary = out["run_stats"]
	var same_kind: Array = rs["same_kind_runs"]
	var same_role: Array = rs["same_role_runs"]
	var long_gaps: Array = rs["long_gaps"]
	var statics: Array = rs["static_streaks"]
	var motions: Array = rs["motion_streaks"]
	if not same_kind.is_empty() or not same_role.is_empty():
		# 任务书 §八 的原文是“连续同类障碍不超过 3 组、连续同一角色压力段不超过 3 组”，
		# 所以恰好 3 连是合规的，只把 >3 判 FAIL；3 连单独记进 advisory 供人读。
		for r in same_kind:
			if int(r["length"]) > 3:
				failures.append("same-kind run > 3: %s" % str(r))
			else:
				advisory.append("same-kind 3 连（允许）：%s→%s t=%.1f" % [
					String(r["from"]), String(r["to"]), float(r["t"])])
		for r in same_role:
			if int(r["length"]) > 3:
				failures.append("same-role run > 3: %s" % str(r))
			else:
				advisory.append("same-role 3 连（允许）：%s→%s t=%.1f" % [
					String(r["from"]), String(r["to"]), float(r["t"])])
	if not long_gaps.is_empty():
		failures.append("gap > %.1fs: %s" % [MAX_GAP_S, str(long_gaps)])
	if not statics.is_empty():
		failures.append("static single-role streak >= 3: %s" % str(statics))
	if not motions.is_empty():
		failures.append("same motion run >= 3: %s" % str(motions))

	var zs: Array = out["zones"]
	var z1 := float(zs[0]["high_op_ratio"])
	var z2 := float(zs[1]["high_op_ratio"])
	var z3 := float(zs[2]["high_op_ratio"])
	if not (z1 <= z2 and z2 <= z3):
		failures.append("high-op ratio not rising: Z1 %.2f Z2 %.2f Z3 %.2f" % [z1, z2, z3])
	for z in zs:
		if int(z["dynamic"]) < 1:
			failures.append("zone %d has no dynamic group" % int(z["zone"]))
		if int(z["both"]) < 1:
			failures.append("zone %d has no BOTH group" % int(z["zone"]))

	var snack_zones := {}
	for s in out["snacks"]:
		snack_zones[int(s["zone"])] = int(snack_zones.get(int(s["zone"]), 0)) + 1
	if snack_zones.size() != 3:
		failures.append("snacks not in all 3 zones: %s" % str(snack_zones))


func _self_check_static() -> bool:
	var saved := rows
	rows = [
		{"group": "s1", "role": "RABBIT", "dynamic": false, "t": 1.0},
		{"group": "s2", "role": "RABBIT", "dynamic": false, "t": 2.0},
		{"group": "s3", "role": "RABBIT", "dynamic": false, "t": 3.0},
		{"group": "s4", "role": "TURTLE", "dynamic": true, "t": 4.0},
	]
	var r := _static_streaks()
	rows = saved
	return r.size() == 1 and int(r[0].get("length", 0)) == 3


func _print_table() -> void:
	print("P6 RHYTHM TABLE (t = 从起跑线按各区基础速度估算，不含食物加速)")
	print("%3s %-8s %2s %-13s %-6s %8s %7s %7s %9s %-14s" % [
		"#", "group", "Z", "kind", "role", "t", "gap_px", "gap_s", "start", "motion"])
	for r in rows:
		print("%3d %-8s %2d %-13s %-6s %8.1f %7.0f %7.2f %9.0f %-14s" % [
			int(r["i"]) + 1, String(r["group"]), int(r["zone"]), String(r["kind"]),
			String(r["role"]), float(r["t"]), float(r["gap_px"]), float(r["gap_s"]),
			float(r["start"]), String(r["motion"])])
	print("P6 ZONES")
	for z in out["zones"]:
		print("  Z%d %-12s groups=%d kinds=%s dynamic=%d both=%d high_op=%.2f max_gap=%.2fs mean_gap=%.2fs snacks=%d" % [
			int(z["zone"]), String(z["name"]), int(z["groups"]), str(z["kinds"]),
			int(z["dynamic"]), int(z["both"]), float(z["high_op_ratio"]),
			float(z["max_gap_s"]), float(z["mean_gap_s"]), int(z["snacks"])])
	print("P6 RUN STATS " + JSON.stringify(out["run_stats"]))
	for a in advisory:
		print("P6 ADVISORY " + String(a))
	print("P6 SNACKS " + JSON.stringify(out["snacks"]))


func _write() -> void:
	var path := ProjectSettings.globalize_path(OUT_PATH)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("P6 RHYTHM JSON -> " + path)
