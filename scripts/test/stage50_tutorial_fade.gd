extends Node
## PHASE-FIX：教学结束 -> 0.35 s 黑场 -> 正赛淡入标记。

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
	tut._finish()
	_check("finish_starts_handoff", tut._handoff_t > 0.0,
		"handoff=%.2f" % tut._handoff_t)
	tut._process(1.41)
	_check("black_hold_starts", tut._black_t > 0.0
		and tut._fade_rect != null and tut._fade_rect.visible,
		"black=%.2f visible=%s" % [tut._black_t,
			str(tut._fade_rect.visible if tut._fade_rect != null else false)])
	GameManager.race_fade_in = false
	tut._process(0.36)
	_check("race_fade_flag", GameManager.race_fade_in,
		"race_fade_in=%s" % str(GameManager.race_fade_in))
	print("STAGE50 TUTORIAL FADE: " + ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		print("  ok   " + name + "  " + detail)
	else:
		failures.append(name)
		print("  FAIL " + name + "  " + detail)
