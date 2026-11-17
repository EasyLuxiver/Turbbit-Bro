extends Node
## FEEL-34：MISCHIEF 安全距离 700 px 边界 + 32% 概率保持。
const LevelData = preload("res://scripts/systems/level_data.gd")
var is_runner := false
var race: Node
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
	seed(20261116)
	GameManager.test_no_best = true
	GameManager.start_race()
	for i in 4:
		await get_tree().process_frame
	race = get_tree().current_scene
	race.set_physics_process(false)
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	var first: Dictionary = race.hazard_groups[0]
	var start: float = race._group_start(first)
	for d in [699.0, 700.0, 701.0]:
		race.turtle.reset(Vector2(start - d, race.surface_ref()))
		var ok: bool = race._mischief_clear_of_hazards()
		_check("clear_%d" % int(d), (d > 700.0) == ok,
			"distance=%d clear=%s" % [int(d), str(ok)])
	# 699 px 内绝不启动；701 px 外保持约 32%。
	var starts_inside := 0
	for i in 500:
		_prepare(race, start - 699.0)
		race._maybe_start_mischief()
		if race._mischief_role != "":
			starts_inside += 1
			race._end_mischief("completed")
	_check("no_start_inside_700", starts_inside == 0, "starts=%d/500" % starts_inside)
	var starts_outside := 0
	var n := 2000
	for i in n:
		_prepare(race, start - 701.0)
		race._maybe_start_mischief()
		if race._mischief_role != "":
			starts_outside += 1
			race._end_mischief("completed")
	var rate := float(starts_outside) / float(n)
	_check("rate_outside_700", rate >= 0.29 and rate <= 0.35,
		"%d/%d = %.1f%%" % [starts_outside, n, rate * 100.0])
	_write()
	var ok: bool = checks.all(func(c): return bool(c["ok"]))
	print("MISCHIEF 700: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _prepare(r: Node, x: float) -> void:
	r.turtle.reset(Vector2(x, r.surface_ref()))
	r.turtle.speed = 0.0
	r.turtle.base_speed = 0.0
	GameManager.current_control = "rabbit"
	GameManager.accident_state = "NONE"
	GameManager.showtime_active = false
	r.showtime_active = false
	r._mischief_role = ""
	r._mischief_phase = ""
	r._mischief_cd = 0.0
	r._ignore_t["turtle"] = 12.0
	GameManager.complaint_role = "turtle"
	GameManager.complaint_t = 2.6
	GameManager.mischief_lock_role = ""


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var f := FileAccess.open("res://docs/reports/longrun/feel34-mischief-700.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"checks": checks}, "  "))
		f.close()
