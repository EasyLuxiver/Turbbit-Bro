extends Node
## TBB-EXPERIENCE-REBUILD-05 E2：三种动态障碍原型的验收探针。
##
## 三个原型（各一组样板，已接进正式赛道）：
##   rock3  tide_rock     周期上下 52 px / 3.6 s  —— 考通过时机
##   log6   swell_log     局部浪涌 −18 ± 22 px / 5.0 s —— 环境变化，上下两条路余量互换
##
## REBUILD-06 P3：鲨鱼不再是正弦巡游，改成“水下伏击 → 预警 → 上冲 → 退避”的
## 逐组状态机（见 race.gd `_update_ambush_sharks`）。鲨鱼的周期/相位扫描已移交
## `stage6_shark_ambush`（它按状态机而不是正弦规格验），本探针只留正弦型障碍。
##
## 判四件事：
##  1. 运动是真的：振幅/偏置/周期/轴与规格一致，且画和判定读同一个 hazard_offset()。
##  2. 不偷袭：基础解在整周期每个相位都成立（跳 / 连招）。
##  3. 时机有意义：潮汐岩的浪谷可以直接骑过去（更好的解），中潮骑过去会撞。
##  4. 涨落浮木的标准 BRO DIVE 在每个相位都成立。
##
## 输出：docs/reports/longrun/rebuild05-e2-motion.json
## 运行：godot --headless --path TURBBIT res://scenes/stage5_e2_motion.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/rebuild05-e2-motion.json"
const STEP := 1.0 / 60.0
## E3 扩到五组：rock10（Z3 潮汐岩）用与样板相同的规格，
## 所以同一套相位扫描就能验“不偷袭”。
const GROUPS := ["rock3", "log6", "rock10", "rock5", "rock9",
	"rock4", "rock7", "rock11", "log2", "rock12", "log5"]
## REBUILD-05 F：Z2 rock5 / Z3 rock9 也用同规格，扩到七组。
## REBUILD-05 G：再补 rock4 / rock7（Z2）、rock11（Z3）、log2（Z2 浪涌）、
## rock12（终点前潮汐）。
## REBUILD-06 P3：shark3/5/6 不再走正弦巡游（改成伏击状态机），已从本探针移出。
## 每个原型的规格（测试和实现分开写一份：改实现不改测试才算验收）。
const SPEC := {
	"rock3": {"axis": "y", "amp": 52.0, "period": 3.6, "bias": 0.0},
	"log6": {"axis": "y", "amp": 22.0, "period": 5.0, "bias": -18.0},
	"rock10": {"axis": "y", "amp": 52.0, "period": 3.6, "bias": 0.0},
	"rock5": {"axis": "y", "amp": 52.0, "period": 3.6, "bias": 0.0},
	"rock9": {"axis": "y", "amp": 52.0, "period": 3.6, "bias": 0.0},
	"rock4": {"axis": "y", "amp": 52.0, "period": 3.6, "bias": 0.0},
	"rock7": {"axis": "y", "amp": 52.0, "period": 3.6, "bias": 0.0},
	"rock11": {"axis": "y", "amp": 52.0, "period": 3.6, "bias": 0.0},
	"log2": {"axis": "y", "amp": 22.0, "period": 5.0, "bias": -18.0},
	"rock12": {"axis": "y", "amp": 52.0, "period": 3.6, "bias": 0.0},
	"log5": {"axis": "y", "amp": 22.0, "period": 5.0, "bias": -18.0},
}
const PHASES := [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875]

var is_runner := false
var race: Node = null
var out := {}
var failures: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage5E2Runner"
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
		push_error("E2 MOTION: no race")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()

	out["generated_at"] = Time.get_datetime_string_from_system()
	out["motion"] = {}
	for name in GROUPS:
		out["motion"][name] = _scan_motion(_group(name))
	out["rock_jump"] = _sweep("rock3", PHASES, _run_rock_jump)
	out["log_combo"] = _sweep("log6", [0.0, 0.2, 0.4, 0.6, 0.8], _run_log_combo)
	# 骑过浪谷 / 回落 / 浪峰：时钟要按“到达岩体中心的那一刻”来摆，不是按出发时刻
	# ——从 start-260 骑到岩心要 320/220 ≈ 1.45 s。
	# 三种时钟各扫一遍，读数只认实测的岩顶/岩底，不假设某个相位等于某个高度。
	out["rock_ride"] = {
		"dip": _run_rock_ride(_group("rock3"), 0.75),
		"mid": _run_rock_ride(_group("rock3"), 0.5),
		"peak": _run_rock_ride(_group("rock3"), 0.25),
	}
	# E3/F 扩展组：同规格，扫同样的相位，只验“基础解一直在”。
	out["rock_jump_ext"] = {}
	for name in ["rock10", "rock5", "rock9", "rock4", "rock7", "rock11", "rock12"]:
		out["rock_jump_ext"][name] = _sweep(name, PHASES, _run_rock_jump)
	# G：Z2 的 log2 用和 log6 同一组相位扫描（5 个相位）。
	# G22：Z3 的 log5 也加了同规格浪涌（相位错开 0.35），同样扫 5 个相位。
	out["log_combo_ext"] = {}
	for name in ["log2", "log5"]:
		out["log_combo_ext"][name] = _sweep(name, [0.0, 0.2, 0.4, 0.6, 0.8], _run_log_combo)
	_evaluate()
	_write()
	print("E2 MOTION: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


# ---------------------------------------------------------------- 运动本身

## 扫一整周期：振幅、周期、轴、以及“判定框 = 基础框 + offset”。
func _scan_motion(g: Dictionary) -> Dictionary:
	if g.is_empty():
		failures.append("missing group")
		return {}
	var spec: Dictionary = SPEC[String(g["group"])]
	var period := float(spec["period"])
	var amp := float(spec["amp"])
	var base: Rect2 = g["rects"][0]
	var samples: Array = []
	var max_off := -INF
	var min_off := INF
	var rect_ok := true
	for i in 25:
		var t := period * float(i) / 24.0
		race.hazard_clock = t
		var off: Vector2 = race.hazard_offset(g)
		var live: Rect2 = race.hazard_rect_live(g, 0)
		if live.position != base.position + off or live.size != base.size:
			rect_ok = false
		var v := off.x if String(spec["axis"]) == "x" else off.y
		max_off = maxf(max_off, v)
		min_off = minf(min_off, v)
		if i < 8:
			samples.append(snappedf(v, 0.1))
	# 周期：t 与 t+period 必须完全同相。
	race.hazard_clock = 0.37
	var a: Vector2 = race.hazard_offset(g)
	race.hazard_clock = 0.37 + period
	var b: Vector2 = race.hazard_offset(g)
	var cross_axis_ok := true
	race.hazard_clock = 0.0
	var zero: Vector2 = race.hazard_offset(g)
	if String(spec["axis"]) == "x" and absf(zero.y) > 0.001:
		cross_axis_ok = false
	if String(spec["axis"]) == "y" and absf(zero.x) > 0.001:
		cross_axis_ok = false
	return {
		"axis": String(spec["axis"]),
		"amp_expected": amp,
		# 实测振幅/偏置用整周期的极值反推，而不是信实现里写的数。
		"amp_measured": snappedf((max_off - min_off) * 0.5, 0.1),
		"bias_expected": float(spec.get("bias", 0.0)),
		"bias_measured": snappedf((max_off + min_off) * 0.5, 0.1),
		"range_measured": [snappedf(min_off, 0.1), snappedf(max_off, 0.1)],
		"period_expected": period,
		"period_repeat_delta": snappedf(a.distance_to(b), 0.001),
		"samples_first_8": samples,
		"rect_follows_offset": rect_ok,
		"no_cross_axis": cross_axis_ok,
	}


# ---------------------------------------------------------------- 基础解：整周期

func _sweep(name: String, phases: Array, runner: Callable) -> Array:
	var g := _group(name)
	var rows: Array = []
	if g.is_empty():
		failures.append("missing group " + name)
		return rows
	for p in phases:
		rows.append(runner.call(g, float(p)))
	return rows


## 低岩：按驾驶器的起跳提前量跳过去。任何相位都不该撞。
func _run_rock_jump(g: Dictionary, phase: float) -> Dictionary:
	var start: float = race._group_start(g)
	var w: float = race._group_end(g) - start
	var spd := 220.0
	var lead := clampf(1.2 * spd - 70.0 - (w + 48.0), 15.0, 120.0)
	_reset(start - lead, phase * 3.6)
	var top_at_jump: float = race.hazard_rect_live(g, 0).position.y
	GameManager.set_control("rabbit")
	Input.action_press("up")
	race._note_up_input()
	race._physics_process(STEP)
	Input.action_release("up")
	var hit := _advance_until(start - 200.0, race._group_end(g) + 220.0)
	return {
		"phase": phase,
		"rock_top_at_jump": snappedf(top_at_jump, 0.1),
		"hit": hit,
		"accidents": GameManager.accident_count,
		"end_x": snappedf(race.turtle.position.x, 0.1),
	}


## 浮木：标准 BRO DIVE（跳 160 px 前 → 0.1 s 后 SHIFT 下潜 → 越过右缘 40 px 松手）。
func _run_log_combo(g: Dictionary, phase: float) -> Dictionary:
	var start: float = race._group_start(g)
	var end: float = race._group_end(g)
	_reset(start - 160.0, phase * 5.0)
	Input.action_press("up")
	race._note_up_input()
	race._physics_process(STEP)
	Input.action_release("up")
	var waited := STEP
	while waited < 0.1:
		race._physics_process(STEP)
		waited += STEP
	GameManager.toggle_control()
	Input.action_press("down")
	var hit := false
	var dived := true
	var guard := 0
	var detail := {}
	while guard < 420 and race.turtle.position.x <= end + 220.0:
		if dived and race.turtle.position.x >= end + 40.0:
			Input.action_release("down")
			dived = false
		race._physics_process(STEP)
		guard += 1
		if race.hit_groups.has(String(g["group"])):
			hit = true
			var live: Rect2 = race.hazard_rect_live(g, 0)
			var rr: Rect2 = race.rabbit.get_body_rect()
			var tr: Rect2 = race.turtle.get_body_rect()
			detail = {
				"x": snappedf(race.turtle.position.x, 0.1),
				"log": [live.position.y, live.end.y],
				"rabbit": [snappedf(rr.position.y, 0.1), snappedf(rr.end.y, 0.1)],
				"turtle": [snappedf(tr.position.y, 0.1), snappedf(tr.end.y, 0.1)],
				"roles": race.hit_roles.get(String(g["group"]), {}),
				"state": GameManager.accident_state,
			}
			break
	Input.action_release("down")
	var riding: bool = String(race.mount.state) == "RIDING"
	return {
		"phase": phase,
		"log_top_at_start": snappedf(race.hazard_rect_live(g, 0).position.y, 0.1),
		"hit": hit,
		"hit_detail": detail,
		"riding_after": riding,
		"accidents": GameManager.accident_count,
		"end_x": snappedf(race.turtle.position.x, 0.1),
	}


# ---------------------------------------------------------------- 时机有没有意义

## 潮汐岩的浪谷：不跳、直接骑过去应该干净；浪峰：骑过去会撞。
## 这一对读数证明运动改变的是“玩家的决定”，不是背景动画。
func _run_rock_ride(g: Dictionary, phase: float) -> Dictionary:
	var start: float = race._group_start(g)
	var end: float = race._group_end(g)
	var w: float = end - start
	var speed := 220.0
	# 从 start-260 骑到岩心（start + w/2）要这么多秒；把它从目标相位里减掉，
	# 保证“到达岩体的那一刻”正好是谷（phase 0.75）或峰（phase 0.25）。
	var travel := (260.0 + w * 0.5) / speed
	var clock := fposmod(phase * 3.6 - travel, 3.6)
	_reset(start - 260.0, clock)
	GameManager.set_control("rabbit")
	var top_at_cross := 999.0
	var bottom_at_cross := -999.0
	var hit := false
	var guard := 0
	while guard < 400 and race.turtle.position.x <= end + 200.0:
		race._physics_process(STEP)
		guard += 1
		# 兔子身体与岩体 x 重叠的整段时间里，记录岩顶的最低/最高。
		var rr: Rect2 = race.rabbit.get_body_rect()
		var live: Rect2 = race.hazard_rect_live(g, 0)
		if rr.end.x >= live.position.x and rr.position.x <= live.end.x:
			top_at_cross = minf(top_at_cross, live.position.y)
			bottom_at_cross = maxf(bottom_at_cross, live.end.y)
		if GameManager.accident_count > 0:
			hit = true
			break
	Input.action_release("up")
	Input.action_release("down")
	return {
		"phase": phase,
		"clock_at_start": snappedf(clock, 0.01),
		"rock_top_min_during_cross": snappedf(top_at_cross, 0.1),
		"rock_bottom_max_during_cross": snappedf(bottom_at_cross, 0.1),
		"hit": hit,
		"accidents": GameManager.accident_count,
	}


# ---------------------------------------------------------------- 判定

func _evaluate() -> void:
	for name in GROUPS:
		var m: Dictionary = out["motion"].get(name, {})
		if m.is_empty():
			continue
		var spec: Dictionary = SPEC[name]
		_expect("%s: amplitude matches spec (%.1f vs %.1f)"
			% [name, float(m["amp_measured"]), float(spec["amp"])],
			absf(float(m["amp_measured"]) - float(spec["amp"])) <= 1.0)
		_expect("%s: bias matches spec (%.1f vs %.1f, range %s)"
			% [name, float(m["bias_measured"]), float(m["bias_expected"]), str(m["range_measured"])],
			absf(float(m["bias_measured"]) - float(m["bias_expected"])) <= 1.0)
		_expect("%s: offset repeats every period (delta %.3f)"
			% [name, float(m["period_repeat_delta"])],
			float(m["period_repeat_delta"]) <= 0.01)
		_expect("%s: the live collision rect is exactly base + offset" % name,
			bool(m["rect_follows_offset"]))
		_expect("%s: motion stays on its own axis" % name, bool(m["no_cross_axis"]))

	for name in ["rock3", "rock10", "rock5", "rock9", "rock4", "rock7", "rock11", "rock12"]:
		var rj: Array = out["rock_jump"] if name == "rock3" \
			else Array(out["rock_jump_ext"].get(name, []))
		var rj_bad := 0
		var rj_tops := []
		for r in rj:
			if bool(r["hit"]):
				rj_bad += 1
			rj_tops.append(float(r["rock_top_at_jump"]))
		_expect("%s: jumping clears at every phase (%d hits, tops %s)"
			% [name, rj_bad, str(rj_tops)], rj_bad == 0)
		# 相位确实改变了岩顶位置：否则连扫相位只是重复同一次。
		_expect("%s: phase really moves the rock (%s)"
			% [name, str(rj_tops)], _span(rj_tops) >= 80.0)

	var lc: Array = out["log_combo"]
	var lc_bad := 0
	var lc_tops := []
	for r in lc:
		if bool(r["hit"]) or not bool(r["riding_after"]):
			lc_bad += 1
		lc_tops.append(float(r["log_top_at_start"]))
	_expect("log6: the standard BRO DIVE works at every phase (%d bad, tops %s)"
		% [lc_bad, str(lc_tops)], lc_bad == 0)
	_expect("log6: the swell really moves the log (%s)" % str(lc_tops),
		_span(lc_tops) >= 25.0)

	# G/G22：涨落浮木（Z2 log2、Z3 log5）用同一组检查。
	var ext_logs: Dictionary = out["log_combo_ext"]
	for name in ext_logs.keys():
		var l2: Array = ext_logs[name]
		var l2_bad := 0
		var l2_tops := []
		for r in l2:
			if bool(r["hit"]) or not bool(r["riding_after"]):
				l2_bad += 1
			l2_tops.append(float(r["log_top_at_start"]))
		_expect("%s: the standard BRO DIVE works at every phase (%d bad, tops %s)"
			% [name, l2_bad, str(l2_tops)], l2_bad == 0)
		_expect("%s: the swell really moves the log (%s)" % [name, str(l2_tops)],
			_span(l2_tops) >= 25.0)

	var dip: Dictionary = out["rock_ride"]["dip"]
	var mid: Dictionary = out["rock_ride"]["mid"]
	_expect("rock3: riding the trough is a clean pass (hit=%s, rock bottom %s)"
		% [str(dip["hit"]), str(dip["rock_bottom_max_during_cross"])],
		not bool(dip["hit"]))
	# 落在兔子高度上的那一档（实测岩顶 281.6，兔子 255..297）必然重叠——
	# 证明“等浪谷再骑”不是装饰性的建议。
	_expect("rock3: riding mid-tide is a real hit — timing matters (hit=%s, rock top %s)"
		% [str(mid["hit"]), str(mid["rock_top_min_during_cross"])], bool(mid["hit"]))


# ---------------------------------------------------------------- 工具

## 从当前 x 推进到 end_x；返回是否真的撞了这一组。
func _advance_until(from_x: float, end_x: float) -> bool:
	var hit := false
	var guard := 0
	while guard < 600 and race.turtle.position.x <= end_x:
		race._physics_process(STEP)
		guard += 1
		if GameManager.accident_count > 0:
			hit = true
			break
	Input.action_release("up")
	Input.action_release("down")
	return hit


func _reset(x: float, clock: float) -> void:
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.clear_bro_meter()
	GameManager.accident_count = 0
	GameManager.total_score = 0
	GameManager.score_log.clear()
	GameManager.rabbit_casualties = 0
	GameManager.turtle_failures = 0
	GameManager.rescue_success_count = 0
	GameManager.pickup_count = 0
	GameManager.showtime_active = false
	GameManager.current_control = "rabbit"
	GameManager.oxygen = Tuning.OXYGEN_MAX
	race.showtime_active = false
	race.joint_show_t = 0.0
	race.finishing = false
	race.hazard_cooldown = 0.0
	race.accident_flash = 0.0
	race.rabbit_stun = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.emergency_timer = 0.0
	race.turtle_repair = 0.0
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.group_actions.clear()
	race.reset_brains()
	race.hazard_clock = clock
	race.turtle.reset(Vector2(x, Tuning.NEUTRAL_DEPTH))
	race.turtle.base_speed = float(LevelData.zone_at(x)["base_speed"])
	race.turtle.speed = race.turtle.base_speed
	race.turtle.speed_cap = 1.0e9
	race.turtle.daze_time = 0.0
	race.turtle.drift = 0.0
	race.turtle.dunk_timer = 0.0
	race.rabbit.reset()
	race.mount.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.mark_riding()
	race.rabbit.state = "RIDING"
	race.rescue_last_result = ""
	race.rescue_last_reason = ""
	race.carry_max_step = 0.0
	race.carry_kind = ""
	race.snack_boost_until_x = -1.0
	race.snack_boost_speed = 0.0
	race.snack_last_eaten = ""
	race.snack_gulp_t = 0.0
	race.snack_gulp_by_player = false
	Input.action_release("down")
	Input.action_release("up")


func _group(name: String) -> Dictionary:
	for g in race.hazard_groups:
		if String(g["group"]) == name:
			return g
	return {}


## 数值数组的跨度（GDScript 的 maxf/minf 只吃两个标量）。
func _span(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var lo := float(arr[0])
	var hi := lo
	for v in arr:
		lo = minf(lo, float(v))
		hi = maxf(hi, float(v))
	return hi - lo


func _expect(label: String, ok: bool) -> void:
	if not ok:
		failures.append(label)


func _write() -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f == null:
		push_error("E2 MOTION: cannot write " + OUT_PATH)
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()
