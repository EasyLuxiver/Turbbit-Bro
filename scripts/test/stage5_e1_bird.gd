extends Node
## TBB-EXPERIENCE-REBUILD-05 E1：海鸟“画出来的位置”和“判定的位置”是不是同一个。
##
## 判定用的是 LevelData 的两段矩形（主带 + 俯冲空域）；本探针把正式 race 场景里
## `bird_pose()` 给出的绘制范围逐像素采样，和同一时刻兔子身体、判定矩形的
## 相交结果比对：
##   - 判定说撞了，画面上却没有任何鸟的身体盖住兔子 → 隐形墙（旧版的问题）
##   - 画面上鸟压着兔子，判定却不撞 → 画了不打
## 另判：四段节奏顺序、蹲下时鸟不进入趴低层、俯冲把空域真扫过一遍。
##
## 输出：docs/reports/longrun/rebuild05-e1-bird.json
## 运行：godot --headless --path TURBBIT res://scenes/stage5_e1_bird.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/rebuild05-e1-bird.json"
const GROUPS := ["bird1", "bird3", "bird4"]
## 玩家站立 / 趴低时的兔子身体（世界 y，见 level_data.gd 文件头）。
const STAND_TOP := 252.0
const STAND_BOTTOM := 300.0
const CROUCH_TOP := 284.0
const CROUCH_BOTTOM := 308.0

var is_runner := false
var race: Node = null
var out := {}
var failures: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage5E1Runner"
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
		push_error("E1 BIRD: no race")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()

	out["generated_at"] = Time.get_datetime_string_from_system()
	out["groups"] = {}
	for name in GROUPS:
		var g := _group(name)
		if g.is_empty():
			failures.append("missing group " + name)
			continue
		out["groups"][name] = _scan(g)
	out["sweep"] = _sweep_airspace(_group("bird1"))
	_evaluate()
	_write()
	print("E1 BIRD: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


## 沿整段接近逐像素采样：同一时刻的绘制范围 vs 判定结果。
func _scan(group: Dictionary) -> Dictionary:
	var band: Rect2 = group["rects"][0]
	var start: float = band.position.x
	var mismatch_invisible := 0
	var mismatch_drawn := 0
	var rows: Array = []
	var phases := []
	var crouch_enter := 0
	var stand_contact := 0
	# 判定用的矩形就是 LevelData 给的那两段。
	var rects: Array = group["rects"]
	for step in range(1100, -700, -5):
		var d := float(step)
		# 把乌龟摆到“鸟还差 d 到达”的位置，兔子站在壳上。
		race.turtle.position = Vector2(start - d, Tuning.NEUTRAL_DEPTH)
		race.rabbit.attach(race.turtle.get_mount_point())
		race.rabbit.state = "RIDING"
		var pose: Dictionary = race.bird_pose(group, 0.0)
		var ph := String(pose["phase"])
		if phases.is_empty() or phases[-1] != ph:
			phases.append(ph)
		var cx: float = band.position.x + band.size.x * 0.5
		var span: float = pose["span_x"]
		var drawn := Rect2(cx - span, float(pose["wing_top"]), span * 2.0,
			float(pose["wing_bottom"]) - float(pose["wing_top"]))
		var body := Rect2(cx - span, float(pose["body_top"]), span * 2.0,
			float(pose["body_bottom"]) - float(pose["body_top"]))
		var shape := drawn.merge(body)
		# 画面上的鸟在攻击段是否足够大：翼展必须覆盖主带（±2 px）。
		if ph == "STRIKE":
			if float(pose["wing_bottom"]) > CROUCH_TOP:
				crouch_enter += 1
			if float(pose["wing_top"]) > STAND_TOP + 40.0:
				failures.append("strike wings do not reach the standing rabbit")
		# 判定：用正式规则里那两段矩形 + 兔子真实判定框。
		var r_rect: Rect2 = race._inset(race.rabbit.get_body_rect(), 3.0)
		var hits := false
		for r in rects:
			var rect: Rect2 = r
			if r_rect.intersects(rect):
				hits = true
		var seen := shape.intersects(r_rect)
		if hits and not seen:
			mismatch_invisible += 1
			if rows.size() < 8:
				rows.append({"d": d, "phase": ph, "why": "hit but no bird drawn",
					"rabbit": [r_rect.position.y, r_rect.end.y],
					"drawn": [shape.position.y, shape.end.y]})
		elif seen and not hits:
			mismatch_drawn += 1
			if rows.size() < 8:
				rows.append({"d": d, "phase": ph, "why": "bird drawn but no hit",
					"rabbit": [r_rect.position.y, r_rect.end.y],
					"drawn": [shape.position.y, shape.end.y]})
		if hits:
			stand_contact += 1
	return {
		"band": [band.position.y, band.end.y],
		"phases": phases,
		"contact_samples": stand_contact,
		"hit_but_not_drawn": mismatch_invisible,
		"drawn_but_no_hit": mismatch_drawn,
		"examples": rows,
		"strike_enters_crouch_lane": crouch_enter,
	}


## 俯冲段有没有真的把“俯冲空域”（130～234）整段扫过：任何一段 > 2 px 的空洞
## 都意味着那里是一堵看不见的墙。
func _sweep_airspace(group: Dictionary) -> Dictionary:
	if group.is_empty():
		return {"error": "no bird1"}
	var band: Rect2 = group["rects"][0]
	var start: float = band.position.x
	var air_top := 130.0
	var air_bottom := 234.0
	var covered := {}
	for step in range(240, -20, -2):
		race.turtle.position = Vector2(start - float(step), Tuning.NEUTRAL_DEPTH)
		var pose: Dictionary = race.bird_pose(group, 0.0)
		var top := float(pose["body_top"])
		var bottom := float(pose["body_bottom"])
		var y := air_top
		while y <= air_bottom:
			if y >= top and y <= bottom:
				covered[int(y)] = true
			y += 1.0
	var gaps := 0
	var worst := 0
	var run := 0
	var y := air_top
	while y <= air_bottom:
		if covered.has(int(y)):
			worst = maxi(worst, run)
			run = 0
		else:
			run += 1
		y += 1.0
	worst = maxi(worst, run)
	gaps = 0 if worst <= 2 else worst
	return {"air": [air_top, air_bottom], "max_gap_px": worst, "gaps": gaps}


func _evaluate() -> void:
	for name in GROUPS:
		var d: Dictionary = out["groups"].get(name, {})
		if d.is_empty():
			continue
		_expect("%s: rhythm order is cruise→telegraph→dive→strike→recover (%s)"
			% [name, str(d["phases"])],
			_wanted_order(d["phases"]))
		_expect("%s: no invisible wall (hit_but_not_drawn=%d)"
			% [name, int(d["hit_but_not_drawn"])], int(d["hit_but_not_drawn"]) == 0)
		_expect("%s: no drawn-but-harmless bird (drawn_but_no_hit=%d)"
			% [name, int(d["drawn_but_no_hit"])], int(d["drawn_but_no_hit"]) == 0)
		_expect("%s: crouching lane is never visually entered (%d)"
			% [name, int(d["strike_enters_crouch_lane"])],
			int(d["strike_enters_crouch_lane"]) == 0)
		_expect("%s: standing rabbit really is in contact (%d samples)"
			% [name, int(d["contact_samples"])], int(d["contact_samples"]) > 0)
	var sw: Dictionary = out["sweep"]
	if not sw.has("error"):
		_expect("dive sweep covers the whole airspace (max gap %d px)" % int(sw["max_gap_px"]),
			int(sw["max_gap_px"]) <= 2)


func _wanted_order(phases: Array) -> bool:
	var want := ["CRUISE", "TELEGRAPH", "DIVE", "STRIKE", "RECOVER"]
	var i := 0
	for p in phases:
		if i < want.size() and String(p) == want[i]:
			i += 1
	return i == want.size()


func _group(name: String) -> Dictionary:
	for g in race.hazard_groups:
		if String(g["group"]) == name:
			return g
	return {}


func _expect(label: String, ok: bool) -> void:
	if not ok:
		failures.append(label)


func _write() -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f == null:
		push_error("E1 BIRD: cannot write " + OUT_PATH)
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()
