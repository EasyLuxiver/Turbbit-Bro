extends Node
## 制作人质检：教学结束不再重载场景，也不归位；从当前位置接着跑。

const LevelData = preload("res://scripts/systems/level_data.gd")

var is_runner := false
var tut: Node
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
	tut = load("res://scenes/tutorial.tscn").instantiate()
	get_tree().root.add_child(tut)
	for i in 8:
		await get_tree().process_frame
	var race_before: Node = tut.race
	var x_before: float = tut.race.turtle.position.x
	tut._finish()
	_check("finish_starts_handoff", tut._handoff_t > 0.0,
		"handoff=%.2f" % tut._handoff_t)
	tut._process(1.41)
	_check("same_race_instance", tut.race == race_before and is_instance_valid(race_before),
		"same=%s" % str(tut.race == race_before))
	_check("position_kept", absf(tut.race.turtle.position.x - x_before) < 0.5,
		"x %.1f -> %.1f" % [x_before, tut.race.turtle.position.x])
	_check("full_race_restored", not tut.race.test_no_finish \
		and tut.race.world_end == LevelData.WORLD_END \
		and not GameManager.test_no_best,
		"no_finish=%s world_end=%.0f no_best=%s" % [
			str(tut.race.test_no_finish), tut.race.world_end,
			str(GameManager.test_no_best)])
	print("STAGE50 TUTORIAL FADE: " + ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		print("  ok   " + name + "  " + detail)
	else:
		failures.append(name)
		print("  FAIL " + name + "  " + detail)
