extends Node
## PHASE-SLEEP：走神度 + 漏电弹飞。
## 满值：电圈/弹飞/抓壳判定；抓壳成功不落水，失败必入水并进入救援。

var is_runner := false
var race: Node
var failures: Array[String] = []
var dir := ""


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
	dir = ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
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

	var speed0: float = race.turtle.speed
	var acc0: int = GameManager.accident_count
	race._reset_sleep_for_test("rabbit", 0.0, 0.0)
	race._tick_sleep(1.0)
	_check("uncontrolled_grows", race.sleep_value("turtle") >= 4.5
		and race.sleep_value("rabbit") == 0.0,
		"rabbit=%.1f turtle=%.1f" % [race.sleep_value("rabbit"),
			race.sleep_value("turtle")])
	_check("no_interference_before_full",
		is_equal_approx(race.turtle.speed, speed0)
			and GameManager.accident_count == acc0,
		"speed=%.1f accidents=%d" % [race.turtle.speed,
			GameManager.accident_count])

	# 切换后：原来控制的身体开始涨；被控制的身体恢复，不清零。
	race._reset_sleep_for_test("turtle", 20.0, 10.0)
	race._tick_sleep(1.0)
	_check("switch_stops_and_recovers", race.sleep_value("rabbit") > 20.0
		and race.sleep_value("turtle") < 10.0,
		"rabbit=%.1f turtle=%.1f" % [race.sleep_value("rabbit"),
			race.sleep_value("turtle")])

	# 预兆里切到漏电身体：取消，不放电。
	race._reset_sleep_for_test("rabbit", 0.0, 100.0)
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

	# A：控制兔子，乌龟漏电。抓壳成功 -> 切乌龟、不落水。
	race._reset_sleep_for_test("rabbit", 0.0, 100.0, 1.0)
	race._tick_sleep(0.01)
	race._tick_sleep(0.66)
	await _shot("sleep_grab")
	_check("zap_switches_to_zapper", GameManager.current_control == "turtle",
		"control=%s" % GameManager.current_control)
	_check("grab_success_no_water", not race._sleep_lock_catch
		or race._sleep_grab_success,
		"grab=%s lock=%s" % [str(race._sleep_grab_success),
			str(race._sleep_lock_catch)])
	race._tick_sleep(0.20)
	_check("grab_attaches", race.rabbit.state == "RIDING"
		and race.mount.state == "RIDING"
		and GameManager.accident_count == acc0,
		"rabbit=%s mount=%s accidents=%d" % [race.rabbit.state,
			race.mount.state, GameManager.accident_count])
	race._tick_sleep(0.35)

	# A：抓壳失败 -> 必入水，控制仍是乌龟（可直接救）。
	race._reset_sleep_for_test("rabbit", 0.0, 100.0, 0.0)
	race._tick_sleep(0.01)
	race._tick_sleep(0.66)
	_check("fail_locks_catch", race._sleep_lock_catch
		and GameManager.current_control == "turtle",
		"lock=%s control=%s" % [str(race._sleep_lock_catch),
			GameManager.current_control])
	race.rabbit.position.y = race.surface_ref() + 12.0
	race._tick_sleep(0.01)
	_check("fail_enters_water", GameManager.accident_state == "RABBIT_WATER"
		and GameManager.accident_count == acc0 + 1,
		"state=%s accidents=%d" % [GameManager.accident_state,
			GameManager.accident_count])
	_check("fail_catch_unlocks", not race._sleep_lock_catch,
		"lock=%s" % str(race._sleep_lock_catch))
	_check("fail_requires_space", race._sleep_fall_requires_space,
		"requires_space=%s" % str(race._sleep_fall_requires_space))

	# B：控制乌龟，兔子漏电。抓壳成功 -> 切兔子、不落水。
	race._reset_sleep_for_test("turtle", 100.0, 0.0, 1.0)
	race._tick_sleep(0.01)
	race._tick_sleep(0.66)
	_check("b_switches_to_rabbit", GameManager.current_control == "rabbit",
		"control=%s" % GameManager.current_control)
	race._tick_sleep(0.20)
	_check("b_grab_attaches", race.rabbit.state == "RIDING"
		and race.mount.state == "RIDING",
		"rabbit=%s mount=%s" % [race.rabbit.state, race.mount.state])
	race._tick_sleep(0.35)

	# B：抓壳失败 -> 入水瞬间把控制交给乌龟。
	race._reset_sleep_for_test("turtle", 100.0, 0.0, 0.0)
	race._tick_sleep(0.01)
	race._tick_sleep(0.66)
	_check("b_initially_rabbit", GameManager.current_control == "rabbit",
		"control=%s" % GameManager.current_control)
	race.rabbit.position.y = race.surface_ref() + 12.0
	race._tick_sleep(0.01)
	_check("b_hands_off_to_turtle", GameManager.current_control == "turtle",
		"control=%s" % GameManager.current_control)
	_check("b_water_once", GameManager.accident_state == "RABBIT_WATER"
		and GameManager.accident_count == acc0 + 2,
		"state=%s accidents=%d" % [GameManager.accident_state,
			GameManager.accident_count])

	# 抓壳率：趴低更高，空中更低。
	race.rabbit.state = "CROUCHING"
	var p_crouch: float = race._sleep_grab_chance_for()
	race.rabbit.state = "JUMPING"
	var p_air: float = race._sleep_grab_chance_for()
	_check("grab_chance_modifiers", p_crouch > p_air,
		"crouch=%.2f air=%.2f" % [p_crouch, p_air])

	print("STAGE53 SLEEP: " + ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for i in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("CAPTURE ", name)


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		print("  ok   " + name + "  " + detail)
	else:
		failures.append(name)
		print("  FAIL " + name + "  " + detail)
