extends Node
## PHASE-FIX：鲨群三拍期间，shark6 前后 1500 px 的普通障碍被隐藏。

const LevelData = preload("res://scripts/systems/level_data.gd")

var is_runner := false
var race: Node
var failures: Array[String] = []


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
	for i in 5:
		await get_tree().process_frame
	race = get_tree().current_scene
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = true
	var g := LevelData.build_group({"group": "shark6", "zone": 3,
		"kind": "SHARK", "x": 1000.0, "w": 70.0})
	g["test_spawned"] = true
	race.load_level([g], [])
	race._shark_pack["shark6"]["phase"] = "LEAD_LUNGE"
	var near := LevelData.build_group({"group": "near_test", "zone": 3,
		"kind": "LOW_BEAM", "x": 1500.0, "w": 170.0})
	_check("arena_hides_normal", race._shark_arena_hides(near),
		"phase=LEAD_LUNGE")
	race._shark_pack["shark6"]["phase"] = "DONE"
	_check("arena_releases_normal", not race._shark_arena_hides(near),
		"phase=DONE")
	print("STAGE49 ARENA EXCLUSIVE: " + ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		print("  ok   " + name + "  " + detail)
	else:
		failures.append(name)
		print("  FAIL " + name + "  " + detail)
