extends Node
## PHASE-FIX：海鸟组被镜头甩到身后后，不再发射/保留投射物。

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
	race.load_level([LevelData.build_group({"group": "bird3", "zone": 1,
		"kind": "LOW_BIRD", "x": 1000.0, "w": 120.0})], [])
	var g: Dictionary = race._group_by_name("bird3")
	var st: Dictionary = race._bird_states["bird3"]
	st["phase"] = "ACTION"
	st["mode"] = "poop"
	st["queue"] = ["poop"]
	# 镜头在鸟前方 3000：鸟已经出画，不能发射。
	race.camera.position.x = 3000.0
	race._bird_attacks.clear()
	race._spawn_bird_attack(g, st)
	_check("offscreen_spawn_blocked", race._bird_attacks.is_empty(),
		"attacks=%d" % race._bird_attacks.size())
	race._tick_bird_behaviors(1.0 / 60.0)
	_check("offscreen_state_done", String(st["phase"]) == "DONE",
		"phase=%s" % String(st["phase"]))
	# 制作人质检：远程便便已撤掉；屏内也不再发射。
	race.camera.position.x = 600.0
	st["phase"] = "ACTION"
	st["mode"] = "poop"
	st["queue"] = ["poop"]
	race._bird_attacks.clear()
	race._spawn_bird_attack(g, st)
	_check("onscreen_ranged_disabled", race._bird_attacks.is_empty(),
		"attacks=%d" % race._bird_attacks.size())
	print("STAGE48 BIRD OFFSCREEN: " + ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		print("  ok   " + name + "  " + detail)
	else:
		failures.append(name)
		print("  FAIL " + name + "  " + detail)
