extends Node
## FEEL-36：跳过教学后，第一次 BRO DIVE 必须有一次性动作提示。
const LevelData = preload("res://scripts/systems/level_data.gd")
var is_runner := false
var race: Node
var hints: Array = []
var checks: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	GameManager.test_no_best = true
	GameManager.start_race()
	for i in 4:
		await get_tree().process_frame
	race = get_tree().current_scene
	race.opening_active = false
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	GameManager.hint.connect(func(text: String): hints.append(text))
	var log1: Dictionary = {}
	for g in race.hazard_groups:
		if String(g["group"]) == "log1":
			log1 = g
	race.turtle.reset(Vector2(race._group_start(log1) - 600.0, race.surface_ref()))
	race.turtle.speed = 0.0
	race.turtle.base_speed = 0.0
	GameManager.current_control = "rabbit"
	race._update_lessons()
	race._update_lessons()
	var dive_hints := hints.filter(func(h): return String(h).contains("BRO DIVE"))
	_check("first_dive_hint_once", dive_hints.size() == 1, JSON.stringify(hints))
	_write()
	get_tree().quit(0 if checks.all(func(c): return bool(c["ok"])) else 1)


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var f := FileAccess.open("res://docs/reports/longrun/feel36-first-hint.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"checks": checks}, "  "))
		f.close()
