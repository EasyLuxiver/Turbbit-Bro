extends Node
## PHASE-SLEEP：走神度轻压力。独立增长、切换停止、持续恢复、不干扰、
## 满值漏电：短硬直 + 软强制切换，切回可恢复。

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
	race.test_disable_hazards = true
	race.load_level([], [])
	race.test_no_mischief = false
	GameManager.accident_state = "NONE"
	GameManager.oxygen = Tuning.OXYGEN_MAX
	race.showtime_active = false
	race._sleep = {"rabbit": 0.0, "turtle": 0.0}
	race._sleep_event_role = ""
	race._sleep_phase = ""
	race._sleep_cd = 0.0
	GameManager.current_control = "rabbit"

	var speed0: float = race.turtle.speed
	var oxy0: float = GameManager.oxygen
	var acc0: int = GameManager.accident_count
	race._tick_sleep(1.0)
	_check("uncontrolled_grows", race.sleep_value("turtle") > 5.0
		and race.sleep_value("rabbit") == 0.0,
		"rabbit=%.1f turtle=%.1f" % [race.sleep_value("rabbit"),
			race.sleep_value("turtle")])
	_check("no_interference_before_full",
		is_equal_approx(race.turtle.speed, speed0)
			and is_equal_approx(GameManager.oxygen, oxy0)
			and GameManager.accident_count == acc0,
		"speed=%.1f oxy=%.1f accidents=%d" % [race.turtle.speed,
			GameManager.oxygen, GameManager.accident_count])

	# 切换后：原来控制的身体开始涨；被控制的身体只缓慢恢复，不清零。
	race._sleep = {"rabbit": 20.0, "turtle": 10.0}
	GameManager.current_control = "turtle"
	race._tick_sleep(1.0)
	_check("switch_stops_and_recovers", race.sleep_value("rabbit") > 20.0
		and race.sleep_value("turtle") > 0.0,
		"rabbit=%.1f turtle=%.1f" % [race.sleep_value("rabbit"),
			race.sleep_value("turtle")])

	# 预兆里切到漏电身体：取消，不强制切换。
	race._sleep = {"rabbit": 0.0, "turtle": 100.0}
	race._sleep_event_role = ""
	race._sleep_phase = ""
	race._sleep_cd = 0.0
	GameManager.current_control = "rabbit"
	race._tick_sleep(0.01)
	_check("event_starts", race._sleep_event_role == "turtle"
		and race._sleep_phase == "TELEGRAPH",
		"role=%s phase=%s" % [race._sleep_event_role, race._sleep_phase])
	GameManager.set_control("turtle")
	race._tick_sleep(0.01)
	_check("switch_cancels", race._sleep_event_role == ""
		and GameManager.current_control == "turtle",
		"role=%s control=%s" % [race._sleep_event_role,
			GameManager.current_control])

	# 不取消：0.2–0.3 s 硬直 + 软强制切换；不记事故/不扣氧。
	race._sleep = {"rabbit": 0.0, "turtle": 100.0}
	race._sleep_event_role = ""
	race._sleep_phase = ""
	race._sleep_cd = 0.0
	GameManager.current_control = "rabbit"
	GameManager.accident_state = "NONE"
	race.rabbit_stun = 0.0
	acc0 = GameManager.accident_count
	oxy0 = GameManager.oxygen
	race._tick_sleep(0.01)
	race._tick_sleep(0.66)
	_check("zap_forces_switch", GameManager.current_control == "turtle",
		"control=%s" % GameManager.current_control)
	_check("zap_short_stun", race.rabbit_stun > 0.0
		and race.rabbit_stun <= 0.30,
		"stun=%.2f" % race.rabbit_stun)
	_check("zap_no_accident_or_oxygen", GameManager.accident_count == acc0
		and is_equal_approx(GameManager.oxygen, oxy0),
		"accidents=%d oxy=%.1f" % [GameManager.accident_count, GameManager.oxygen])
	race._tick_sleep(0.31)
	race._tick_sleep(0.26)
	_check("event_ends", race._sleep_event_role == "",
		"role=%s phase=%s" % [race._sleep_event_role, race._sleep_phase])
	GameManager.set_control("rabbit")
	_check("can_switch_back", GameManager.current_control == "rabbit",
		"control=%s" % GameManager.current_control)

	print("STAGE53 SLEEP: " + ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		print("  ok   " + name + "  " + detail)
	else:
		failures.append(name)
		print("  FAIL " + name + "  " + detail)
