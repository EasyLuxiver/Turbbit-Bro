extends Node
## REBUILD-05 G10：首次教学按“先来后到”，不给更远的障碍抢底栏。
##
## 问题（玩家视角）：首次 BRO DIVE 逼近 log1（x=6400）时，鲨鱼 shark1（x=7250）
## 在 1100 px 教学范围内也更早被判定“没教过”，底栏于是显示
## 「SHIFT + ↑ 乌龟跃起」——和左上的「BRO DIVE 现在！」方向相反。
## 做法：只有“最近的那一组”过完（组尾 + LESSON_CLEAR_BEHIND）才允许教下一种类型，
## 并且一帧只发最近的一组（不再让后发的更远类型盖掉先发的）。
##
## 用法：在正式 race 场景里直接调 `_update_lessons()`，把乌龟按 5 px 步进扫过
## 指定区间，记录每次 prompt 信号的原文与当时的 x。不改判定、不注入按键。
##
## 运行：godot --headless --path TURBBIT res://scenes/stage5_g10_lesson_order.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/rebuild05-g10-lesson-order.json"
const STEP := 5.0

var is_runner := false
var race: Node = null
var failures: Array = []
var emissions: Array = []
var captured := ""
var capture_x := 0.0


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage5G10LessonOrderRunner"
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
		push_error("G10: no race")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	GameManager.prompt.connect(_on_prompt)

	var log1 := _group("log1")
	var shark1 := _group("shark1")
	if log1.is_empty() or shark1.is_empty():
		push_error("G10: log1/shark1 missing")
		get_tree().quit(1)
		return
	var log_end: float = LevelData.group_end(log1)
	var log_start: float = LevelData.group_start(log1)
	var shark_start: float = LevelData.group_start(shark1)

	# ---- 1. 首次 BRO DIVE 的接近与下潜段：不许出现鲨鱼教学 ----
	race.lesson_seen.clear()
	emissions.clear()
	captured = ""
	_sweep(5300.0, 6500.0)
	var combo_hits := _hits(Locale.t("prompt.combo"))
	var leap_hits := _hits(Locale.t("prompt.leap"))
	var forbidden: Array = []
	for e in emissions:
		if e["x"] >= 6150.0 and e["x"] <= 6500.0 and e["text"] == Locale.t("prompt.leap"):
			forbidden.append(e)
	_expect("combo lesson fires exactly once in 5300-6500", combo_hits.size() == 1)
	# rock2（x=5100，组尾 5240 + 80）在 5320 前仍算“没过完”，组合教学因此从 1100 px
	# 提前量退到 1080 px（4.9 s）——仍在 5 s 量级，够读完一句。
	_expect("combo lesson keeps >= 1000 px lead",
		combo_hits.size() == 1 and log_start - float(combo_hits[0]["x"]) >= 1000.0)
	_expect("no shark lesson during 6150-6500 (BRO DIVE window)", forbidden.is_empty())
	_expect("no shark lesson before log1 is cleared",
		leap_hits.is_empty())
	# 对照：把旧循环（1100 px 内每个未见类型都发、后发盖前发）在 x=6150 重放一遍，
	# 它应当仍然会发鲨鱼教学——证明本探针能区分修复前后，不是一个恒真断言。
	var legacy_seen := {
		"SURFACE_ROCK": true, "LOW_BEAM": true, "LOW_BIRD": true,
		"DIVE_GATE": true, "FLOATING_LOG": true,
	}
	_expect("legacy rule emits shark at 6150 (bug reproduced)",
		_legacy_emit_at(6150.0, legacy_seen) == Locale.t("prompt.leap"))

	# ---- 2. 越过 log1 后补发一次，只一次 ----
	captured = ""
	_sweep(6500.0, shark_start + 60.0)
	var leap_after := _hits(Locale.t("prompt.leap"))
	_expect("shark lesson fires exactly once after log1", leap_after.size() == 1)
	var leap_x := -1.0
	if leap_after.size() == 1:
		leap_x = float(leap_after[0]["x"])
	_expect("shark lesson waits until log1 end + clearance",
		leap_x >= log_end + Tuning.LESSON_CLEAR_BEHIND - STEP)
	_expect("shark lesson still has >= 700 px lead",
		leap_x >= 0.0 and shark_start - leap_x >= 700.0)
	_expect("shark wording unchanged", leap_after.size() == 1
		and String(leap_after[0]["text"]) == Locale.t("prompt.leap"))

	# ---- 3. 干净接近（没有更近的障碍）仍然照常教学 ----
	race.lesson_seen.clear()
	for k in ["SURFACE_ROCK", "LOW_BEAM", "LOW_BIRD", "FLOATING_LOG", "DIVE_GATE", "HIGH_WALL"]:
		race.lesson_seen[k] = true
	captured = ""
	race.turtle.position.x = shark_start - 200.0
	race._update_lessons()
	_expect("control: clean approach still teaches SHARK", captured == Locale.t("prompt.leap"))

	# ---- 4. 全赛道扫一遍：七类都必须至少教过一次（门禁不能把教学吞掉）----
	race.lesson_seen.clear()
	emissions.clear()
	captured = ""
	_sweep(0.0, LevelData.WORLD_END)
	var all_kinds := {
		"SURFACE_ROCK": "prompt.jump",
		"LOW_BEAM": "prompt.crouch",
		"LOW_BIRD": "prompt.crouch",
		"SHARK": "prompt.leap",
		"DIVE_GATE": "prompt.dive",
		"FLOATING_LOG": "prompt.combo",
		"HIGH_WALL": "prompt.ollie",
	}
	var taught := {}
	for e in emissions:
		taught[String(e["text"])] = true
	for kind in all_kinds:
		_expect("full track teaches %s" % kind,
			taught.has(Locale.t(all_kinds[kind])))
	# 同一类只教一次：七类 → 至多 7 条；FEEL-09 起 Z2 的吊网/鳗鱼/船闸
	# 有独立文案，各多一条；整条赛道目前 13 条，上限放到 14。
	_expect("lesson count stays small (<= 14)", emissions.size() <= 14)

	_write(log_start, log_end, shark_start, leap_x, forbidden)
	print("G10 LESSON ORDER: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


## 把乌龟按 STEP 步进扫过 [from_x, to_x]，每次调一次 _update_lessons()。
func _sweep(from_x: float, to_x: float) -> void:
	var x := from_x
	while x <= to_x:
		race.turtle.position.x = x
		race._update_lessons()
		x += STEP


## 修复前的 `_update_lessons` 循环：范围内每个未见类型都发，最后一次覆盖前面。
## 只用于对照，不改 race 状态（seen 是调用方给的副本）。
func _legacy_emit_at(x: float, seen: Dictionary) -> String:
	var last := ""
	for g in race.hazard_groups:
		var kind: String = g["kind"]
		if seen.has(kind):
			continue
		var d: float = LevelData.group_start(g) - x
		if d < 0.0 or d > Tuning.PROMPT_RANGE:
			continue
		seen[kind] = true
		last = race._lesson_prompt(kind)
	return last


func _on_prompt(text: String) -> void:
	captured = text
	emissions.append({"x": race.turtle.position.x, "text": text})


func _hits(text: String) -> Array:
	var out := []
	for e in emissions:
		if String(e["text"]) == text:
			out.append(e)
	return out


func _group(name: String) -> Dictionary:
	for g in race.hazard_groups:
		if String(g["group"]) == name:
			return g
	return {}


func _expect(label: String, ok: bool) -> void:
	if not ok:
		failures.append(label)


func _write(log_start: float, log_end: float, shark_start: float,
		leap_x: float, forbidden: Array) -> void:
	var payload := {
		"note": "正式 race 场景内直接调 _update_lessons()，不是真人试玩。",
		"log1_start": log_start,
		"log1_end": log_end,
		"shark1_start": shark_start,
		"shark_lesson_x": leap_x,
		"forbidden_shark_in_bro_dive_window": forbidden,
		"emissions": emissions,
		"failures": failures,
	}
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		push_error("G10: cannot write %s" % OUT_PATH)
		return
	f.store_string(JSON.stringify(payload, "  "))
	f.close()
	print("G10: wrote %s" % OUT_PATH)
