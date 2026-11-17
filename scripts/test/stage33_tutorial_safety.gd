extends Node
## FEEL-33：教学期间不得触发抱怨/捣乱（MCP 实跑发现乌龟在教程里翻肚皮）。
var is_runner := false
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
	var tut: Node = load("res://scenes/tutorial.tscn").instantiate()
	get_tree().root.add_child(tut)
	for i in 10:
		await get_tree().process_frame
	var race: Node = tut.race
	_check("tutorial_flag", bool(race.test_no_mischief), "test_no_mischief=%s" % str(race.test_no_mischief))
	race._tick_ignore(20.0)
	_check("no_ignore_accumulation", GameManager.complaint_role == "",
		"complaint=%s" % GameManager.complaint_role)
	GameManager.complaint_role = "turtle"
	GameManager.complaint_t = 2.6
	race._maybe_start_mischief()
	_check("no_mischief_in_tutorial", race._mischief_role == ""
		and GameManager.mischief_lock_role == "",
		"role=%s lock=%s" % [race._mischief_role, GameManager.mischief_lock_role])
	_write()
	get_tree().quit(0 if checks.all(func(c): return bool(c["ok"])) else 1)


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var f := FileAccess.open("res://docs/reports/longrun/feel33-tutorial-safety.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"checks": checks}, "  "))
		f.close()
