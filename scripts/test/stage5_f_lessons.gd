extends Node
## REBUILD-05 F：首次教学提示是否随“当前控制角色”变化。
##
## 问题（玩家视角）：玩家先按 SHIFT 换了人，再遇到第一次出现的障碍时，
## 旧文案一律写“SHIFT + ↓”，等于叫他当场把控制权交出去、错过这一组。
## 做法：在正式 race 场景里，把乌龟依次摆到每一类障碍前 500 px，
## 分别以“控兔子 / 控乌龟”各调一次 `_update_lessons()`，读 GameManager.prompt 的原文。
##
## 断言：
##   1. 控兔子时文案与旧版逐字一致（常见路径不回归）；
##   2. 控乌龟时文案与控兔子不同（真的分人）；
##   3. 兔子专属障碍（岩/梁/鸟/浮木）在控乌龟时以 “SHIFT” 开头（先换回来）；
##   4. 乌龟专属障碍（鲨/门/墙）在控乌龟时不再出现 “SHIFT + ”（不用再换人）；
##   5. 中英文都能取到，且两种控制下都不同。
##
## 运行：godot --headless --path TURBBIT res://scenes/stage5_f_lessons.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/rebuild05-f-lessons.json"
const LEAD := 500.0

const BASE_KEY := {
	"SURFACE_ROCK": "prompt.jump",
	"LOW_BEAM": "prompt.crouch",
	"LOW_BIRD": "prompt.crouch",
	"SHARK": "prompt.leap",
	"DIVE_GATE": "prompt.dive",
	"FLOATING_LOG": "prompt.combo",
	"HIGH_WALL": "prompt.ollie",
}
## 这些障碍只有兔子能解：控乌龟时必须提示先换回来。
const RABBIT_ONLY := ["SURFACE_ROCK", "LOW_BEAM", "LOW_BIRD", "FLOATING_LOG"]
## 这些障碍是乌龟的动作：控乌龟时不该再出现 “SHIFT + 动作”。
const TURTLE_ONLY := ["SHARK", "DIVE_GATE", "HIGH_WALL"]

var is_runner := false
var race: Node = null
var failures: Array = []
var captured := ""
var rows: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage5FLessonsRunner"
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
		push_error("F LESSONS: no race")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	GameManager.prompt.connect(_on_prompt)

	for kind in BASE_KEY:
		var g := _first_group(kind)
		if g.is_empty():
			_expect("group for %s exists" % kind, false)
			continue
		var start: float = race._group_start(g)
		var rabbit_text := _emit_for(kind, start, "rabbit")
		var turtle_text := _emit_for(kind, start, "turtle")
		var base_text: String = Locale.t(BASE_KEY[kind])
		rows.append({
			"kind": kind,
			"rabbit": rabbit_text,
			"turtle": turtle_text,
			"base": base_text,
		})
		_expect("%s / rabbit keeps the original wording" % kind,
			rabbit_text == base_text)
		_expect("%s / turtle wording differs from rabbit" % kind,
			turtle_text != "" and turtle_text != rabbit_text)
		if RABBIT_ONLY.has(kind):
			_expect("%s / turtle wording tells the player to SHIFT back" % kind,
				turtle_text.begins_with("SHIFT"))
		if TURTLE_ONLY.has(kind):
			_expect("%s / turtle wording has no redundant SHIFT + action" % kind,
				not turtle_text.contains("SHIFT + "))

	_check_english()
	_write()
	print("F LESSONS: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


## 把乌龟摆到这一组前 LEAD px，只让这一类“未见过”，然后让 race 发一次教学。
func _emit_for(kind: String, start: float, control: String) -> String:
	for k in BASE_KEY:
		race.lesson_seen[k] = true
	race.lesson_seen.erase(kind)
	GameManager.accident_state = "NONE"
	GameManager.current_control = control
	race.turtle.position = Vector2(start - LEAD, Tuning.NEUTRAL_DEPTH)
	captured = ""
	race._update_lessons()
	return captured


func _check_english() -> void:
	Locale.language = "en"
	var start: float = race._group_start(_first_group("SURFACE_ROCK"))
	var en_rabbit := _emit_for("SURFACE_ROCK", start, "rabbit")
	var en_turtle := _emit_for("SURFACE_ROCK", start, "turtle")
	rows.append({"kind": "SURFACE_ROCK", "lang": "en",
		"rabbit": en_rabbit, "turtle": en_turtle})
	_expect("en / rabbit wording is non-empty", en_rabbit != "")
	_expect("en / turtle wording is non-empty", en_turtle != "")
	_expect("en / turtle wording differs from rabbit", en_turtle != en_rabbit)
	_expect("en / turtle wording tells the player to SHIFT back",
		en_turtle.begins_with("SHIFT"))
	Locale.language = "zh"


func _on_prompt(text: String) -> void:
	captured = text


func _first_group(kind: String) -> Dictionary:
	for g in race.hazard_groups:
		if String(g["kind"]) == kind:
			return g
	return {}


func _expect(what: String, ok: bool) -> void:
	print(("  ok  " if ok else "  FAIL  ") + what)
	if not ok:
		failures.append(what)


func _write() -> void:
	var data := {
		"generated_at": Time.get_datetime_string_from_system(),
		"note": "正式 race 场景内直接调 _update_lessons()，不是真人试玩。",
		"rows": rows,
		"failures": failures,
	}
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))
		f.close()
	print("WROTE " + OUT_PATH)
