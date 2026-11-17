extends Node
## FEEL-33：MISCHIEF 概率分支修复后的回归。
## 目标：12 s 无人管 -> 抱怨；约 32% 动手；其余退回第二阶段（ignore=8）。
## 保留：2.6 s 抱怨窗口、冷却、安全距离、SHIFT 中断规则。

var is_runner := false
var race: Node
var checks: Array = []
var rates: Dictionary = {}


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
	GameManager.start_race()
	for i in 3:
		await get_tree().process_frame
	race = get_tree().current_scene
	race.test_disable_hazards = true
	race.turtle.reset(Vector2(400.0, 400.0))
	race.turtle.speed = 0.0
	race.turtle.base_speed = 0.0
	GameManager.current_control = "turtle"
	GameManager.accident_state = "NONE"
	GameManager.showtime_active = false
	race.showtime_active = false
	var n := 2000
	for who in ["rabbit", "turtle"]:
		var starts := 0
		var cancels := 0
		var state_ok := true
		for i in n:
			race._mischief_role = ""
			race._mischief_phase = ""
			race._mischief_cd = 0.0
			race._ignore_t[who] = 12.0
			GameManager.complaint_role = who
			GameManager.complaint_t = 2.6
			GameManager.accident_state = "NONE"
			GameManager.showtime_active = false
			race.showtime_active = false
			GameManager.mischief_lock_role = ""
			if who == "rabbit":
				GameManager.current_control = "turtle"
			else:
				GameManager.current_control = "rabbit"
			race._maybe_start_mischief()
			if race._mischief_role != "":
				starts += 1
				if GameManager.complaint_role != "" or race._mischief_phase != "TELEGRAPH" \
						or GameManager.mischief_lock_role != who:
					state_ok = false
				race._end_mischief("completed")
			else:
				cancels += 1
				if absf(float(race._ignore_t[who]) - 8.0) > 0.001:
					state_ok = false
		var rate := float(starts) / float(n)
		rates[who] = rate
		_check("rate_%s" % who, rate >= 0.29 and rate <= 0.35,
			"%d/%d = %.1f%%" % [starts, n, rate * 100.0])
		_check("state_%s" % who, state_ok and starts + cancels == n,
			"starts=%d cancels=%d state_ok=%s" % [starts, cancels, str(state_ok)])
	# 抱怨窗口仍是 2.6 s。
	GameManager.complaint_role = "rabbit"
	GameManager.complaint_t = 2.6
	GameManager.tick_complaint(1.0)
	var half := absf(GameManager.complaint_t - 1.6) < 0.01
	GameManager.tick_complaint(1.7)
	var cleared := GameManager.complaint_role == ""
	_check("complaint_window_2_6", half and cleared,
		"after1=%.1f cleared=%s" % [GameManager.complaint_t, str(cleared)])
	_write()
	var ok: bool = checks.all(func(c): return bool(c["ok"]))
	print("MISCHIEF RATE: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var f := FileAccess.open("res://docs/reports/longrun/feel33-mischief-rate.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"rates": rates, "checks": checks}, "  "))
		f.close()
