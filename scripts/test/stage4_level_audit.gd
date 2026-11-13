extends Node
## 阶段 4 内容审计：把三区域的组数、种类、间隔、操作选项、组合重复度
## 和“真正需要输入的时间”算成可复现的 JSON。
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT res://scenes/stage4_level_audit.tscn
##
## 口径：
## - gap_px 是上一组障碍末端 -> 下一组起点（真实空档），不是起点到起点。
## - 操作选项按“碰撞空间 + 谁受控”推导，不按障碍名字推导：
##   A 兔子层，趴低：LOW_BIRD / LOW_BEAM -> 只能 crouch（乌龟巡航高度不受影响）；
##   A 兔子层，跳跃：SURFACE_ROCK -> 只能 jump；
##   B 组合：FLOATING_LOG -> jump + dive 两条路同时走，缺一条就撞；
##   C 水下攻击：SHARK -> 只能 leap（乌龟跃起带动整组）；
##   D 水下通道：DIVE_GATE -> 只能 dive。
## - must_* 统计的是“只能靠这个动作”的组数，用来对照旧模型
##   （旧：34 组只需下潜、21 组只需保持水面、跳跃/趴下/跃起 0 组）。

const Tuning = preload("res://scripts/systems/tuning.gd")
const LevelDataScript = preload("res://scripts/systems/level_data.gd")
const OUT_PATH := "res://docs/reports/stage4-content-matrix.json"
const HUD_WARN := 430.0

var is_runner := false


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4LevelAuditRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_run()


func _run() -> void:
	var out := {
		"definitions": {
			"gap": "previous group end -> next group start",
			"threat_window_px": HUD_WARN,
			"options_from_collision": true,
		},
		"zones": {},
		"totals": {},
	}
	var totals := {
		"groups": 0, "must_crouch": 0, "must_jump": 0, "must_leap": 0,
		"must_dive": 0, "must_both": 0, "no_solution_groups": 0,
		"boost_lanes": 0,
	}
	for zone in LevelDataScript.ZONES:
		var zid: int = zone["id"]
		var list: Array = LevelDataScript.groups_in_zone(zid)
		var base_speed: float = zone["base_speed"]
		var entries: Array = []
		var prev_end := 0.0
		var cluster := 0
		var prev_start := -1.0e9
		var threat: Array = []
		var kinds := {}
		var options := {"crouch": 0, "jump": 0, "leap": 0, "dive": 0}
		var no_input_zone := 0
		var sequence: Array[String] = []
		for i in list.size():
			var g: Dictionary = list[i]
			var start: float = LevelDataScript.group_start(g)
			var end: float = LevelDataScript.group_end(g)
			var gap_px := 0.0
			var gap_s := 0.0
			if i > 0:
				gap_px = start - prev_end
				gap_s = gap_px / base_speed
			if i > 0 and start - prev_start > LevelDataScript.COMBO_GAP:
				cluster += 1
			var opt: Array[String] = _options_for(g["kind"])
			for o in opt:
				options[o] = int(options.get(o, 0)) + 1
			kinds[g["kind"]] = int(kinds.get(g["kind"], 0)) + 1
			sequence.append(g["kind"])
			threat.append([start - HUD_WARN, end])
			if opt.is_empty():
				no_input_zone += 1
			entries.append({
				"i": i + 1,
				"group": g["group"],
				"kind": g["kind"],
				"start": start,
				"end": end,
				"width": end - start,
				"options": opt,
				"gap_px": gap_px,
				"gap_s": snappedf(gap_s, 0.01),
				"cluster": cluster,
			})
			prev_end = maxf(prev_end, end)
			prev_start = start
			totals["groups"] = int(totals["groups"]) + 1
			match opt:
				["crouch"]:
					totals["must_crouch"] = int(totals["must_crouch"]) + 1
				["jump"]:
					totals["must_jump"] = int(totals["must_jump"]) + 1
				["leap"]:
					totals["must_leap"] = int(totals["must_leap"]) + 1
				["dive"]:
					totals["must_dive"] = int(totals["must_dive"]) + 1
				["jump", "dive"]:
					totals["must_both"] = int(totals["must_both"]) + 1
				["leap", "jump"]:
					totals["must_ollie"] = int(totals.get("must_ollie", 0)) + 1
				_:
					totals["no_solution_groups"] = int(totals["no_solution_groups"]) + 1
		var threat_s := _union_seconds(threat, base_speed)
		var zone_seconds: float = (zone["end"] - zone["start"]) / base_speed
		var lanes: Array = []
		for lane in LevelDataScript.boost_lanes():
			var rect: Rect2 = lane
			if rect.position.x >= zone["start"] and rect.position.x < zone["end"]:
				lanes.append({
					"start": rect.position.x, "end": rect.end.x,
					"length": rect.size.x, "seconds": snappedf(rect.size.x / base_speed, 0.01),
				})
		out["zones"][zid] = {
			"name": zone["name"],
			"start": zone["start"],
			"end": zone["end"],
			"length_px": zone["end"] - zone["start"],
			"base_speed": base_speed,
			"nominal_seconds": snappedf(zone_seconds, 0.01),
			"groups": list.size(),
			"kinds": kinds,
			"options": options,
			"must_crouch_groups": int(options["crouch"]),
			"must_jump_groups": int(options["jump"]),
			"must_leap_groups": int(options["leap"]),
			"must_dive_groups": int(options["dive"]),
			"no_input_groups": no_input_zone,
			"threat_seconds": snappedf(threat_s, 0.01),
			"threat_fraction": snappedf(threat_s / zone_seconds, 0.001),
			"no_input_fraction": snappedf(float(no_input_zone) / maxf(list.size(), 1), 0.001),
			"clusters": cluster + 1,
			"unique_bigrams": _unique_ngrams(sequence, 2),
			"unique_trigrams": _unique_ngrams(sequence, 3),
			"top_bigrams": _top_ngrams(sequence, 2, 5),
			"top_trigrams": _top_ngrams(sequence, 3, 5),
			"boost_lanes": lanes,
			"entries": entries,
		}
		totals["boost_lanes"] = int(totals["boost_lanes"]) + lanes.size()
	# 每组的无解计数在 entries 里已经算过，这里回收成总数。
	var no_input := 0
	for zid in out["zones"].keys():
		var z: Dictionary = out["zones"][zid]
		no_input += int(z["no_input_groups"])
	out["totals"] = totals
	out["totals"]["no_solution_groups"] = no_input
	out["totals"]["kinds"] = _kind_totals()
	_write(out)
	_print_summary(out)
	get_tree().quit(0)


func _options_for(kind: String) -> Array[String]:
	match kind:
		"LOW_BIRD", "LOW_BEAM":
			return ["crouch"]
		"SURFACE_ROCK":
			return ["jump"]
		"FLOATING_LOG":
			return ["jump", "dive"]
		"SHARK":
			return ["leap"]
		"DIVE_GATE":
			return ["dive"]
		"HIGH_WALL":
			return ["leap", "jump"]
	return []


func _kind_totals() -> Dictionary:
	var result := {}
	for g in LevelDataScript.groups():
		result[g["kind"]] = int(result.get(g["kind"], 0)) + 1
	return result


func _union_seconds(intervals: Array, speed: float) -> float:
	var sorted := intervals.duplicate()
	sorted.sort_custom(func(a, b): return a[0] < b[0])
	var total := 0.0
	var cur_start := -1.0e20
	var cur_end := -1.0e20
	for iv in sorted:
		var s: float = iv[0]
		var e: float = iv[1]
		if s > cur_end:
			if cur_end > cur_start:
				total += (cur_end - cur_start) / speed
			cur_start = s
			cur_end = e
		else:
			cur_end = maxf(cur_end, e)
	if cur_end > cur_start:
		total += (cur_end - cur_start) / speed
	return total


func _unique_ngrams(seq: Array[String], n: int) -> int:
	var seen := {}
	for i in range(0, seq.size() - n + 1):
		seen["/".join(seq.slice(i, i + n))] = true
	return seen.size()


func _top_ngrams(seq: Array[String], n: int, limit: int) -> Array:
	var counts := {}
	for i in range(0, seq.size() - n + 1):
		var key := "/".join(seq.slice(i, i + n))
		counts[key] = int(counts.get(key, 0)) + 1
	var pairs := []
	for k in counts.keys():
		pairs.append([k, counts[k]])
	pairs.sort_custom(func(a, b):
		if a[1] == b[1]:
			return a[0] < b[0]
		return a[1] > b[1])
	var out := []
	for i in mini(limit, pairs.size()):
		out.append({"pattern": pairs[i][0], "count": pairs[i][1]})
	return out


func _write(data: Dictionary) -> void:
	var path := ProjectSettings.globalize_path(OUT_PATH)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if file == null:
		print("FAIL cannot write ", path)
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	print("WROTE ", path)


func _print_summary(out: Dictionary) -> void:
	for zid in out["zones"].keys():
		var z: Dictionary = out["zones"][zid]
		var gaps: Array = []
		for e in z["entries"]:
			if e["gap_px"] > 0.0:
				gaps.append(e["gap_s"])
		gaps.sort()
		var max_gap: float = gaps[-1] if gaps.size() > 0 else 0.0
		print("ZONE %d %s  groups=%d  %.1fs  threat=%.1f%%  max_gap=%.2fs" % [
			zid, z["name"], z["groups"], z["nominal_seconds"],
			z["threat_fraction"] * 100.0, max_gap])
		print("        kinds=%s  options=%s  unique bi/tri=%d/%d" % [
			str(z["kinds"]), str(z["options"]),
			z["unique_bigrams"], z["unique_trigrams"]])
	print("TOTALS  %s" % str(out["totals"]))
