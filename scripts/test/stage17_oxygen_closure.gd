extends Node
## FEEL-17 P0：氧气失败闭环。主动救援最快；自动回壳有距离条件；
## 氧气耗尽优先于尚未完成的自动回壳；30/60/120 一致。

const FPS := 60.0
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
	GameManager.test_no_best = true
	GameManager.start_race()
	for i in 5:
		await get_tree().process_frame
	race = get_tree().current_scene
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = true
	race.load_level([], [])
	# 1) 主动救援最快：真实接住 → RIDING。
	_water(180.0)
	GameManager.current_control = "turtle"
	race._try_role_skill()
	var active_caught := false
	for i in 180:
		if String(race.mount.state) == "CARRYING":
			race._tick_carry(1.0 / FPS)
		else:
			race._tick_recovery(1.0 / FPS)
			race._tick_bro_catch(1.0 / FPS)
			race.turtle.tick(1.0 / FPS, true, false, 0.0, true, 240.0)
		if String(race.rescue_last_result) == "caught" and String(race.mount.state) == "RIDING":
			active_caught = true
			break
	_check("active_rescue_fastest", active_caught,
		"result=%s mount=%s" % [String(race.rescue_last_result), String(race.mount.state)])
	# 2) 近距自动回壳成功。
	_water(120.0)
	var auto_ok := false
	for i in 360:
		race._update_oxygen(1.0 / FPS)
		race._tick_recovery(1.0 / FPS)
		if String(race.mount.state) == "CARRYING":
			race._tick_carry(1.0 / FPS)
		if String(race.mount.state) == "RIDING" and String(race.rescue_last_result) == "auto":
			auto_ok = true
			break
	_check("auto_rescue_near_succeeds", auto_ok,
		"result=%s mount=%s" % [String(race.rescue_last_result), String(race.mount.state)])
	# 3) 远距自动回壳不成立：仍在水里，氧气继续下降，玩家可 SPACE。
	_water(1200.0)
	for i in 240:
		race._update_oxygen(1.0 / FPS)
		race._tick_recovery(1.0 / FPS)
	_check("auto_rescue_far_blocked", String(race.mount.state) == "RESCUE_ACTIVE"
		and float(race.rescue_auto_blocked_t) > 0.0,
		"mount=%s blocked=%.1f oxygen=%.1f" % [String(race.mount.state),
			float(race.rescue_auto_blocked_t), GameManager.oxygen])
	_check("far_still_drains_oxygen", GameManager.oxygen < 7.0,
		"oxygen=%.2f" % GameManager.oxygen)
	# 4) 远距持续到氧气耗尽：真实失败场景，不是测试造数据。
	var failed := false
	for i in 600:
		race._update_oxygen(1.0 / FPS)
		race._tick_recovery(1.0 / FPS)
		if GameManager.state == GameManager.GameState.FAILED:
			failed = true
			break
	_check("oxygen_really_fails", failed and GameManager.failure_reason == "OXYGEN_OUT",
		"state=%s reason=%s oxygen=%.2f" % [GameManager.state_name(),
			GameManager.failure_reason, GameManager.oxygen])
	# 6) 30/60/120 Hz：近距自动回壳都能完成，耗时在合理范围。
	for hz in [30.0, 60.0, 120.0]:
		_water(120.0)
		var t := 0.0
		var ok := false
		var step: float = 1.0 / float(hz)
		for i in int(6.0 * hz):
			race._update_oxygen(step)
			race._tick_recovery(step)
			if String(race.mount.state) == "CARRYING":
				race._tick_carry(step)
			t += step
			if String(race.mount.state) == "RIDING":
				ok = true
				break
		_check("auto_hz_%d" % int(hz), ok and t >= 3.8 and t < 7.0,
			"t=%.2f mount=%s" % [t, String(race.mount.state)])
	# 5) 高优先级中断自动回壳：不卡在半个抬升，状态回到可 SPACE 的 RESCUE_ACTIVE。
	_water(120.0)
	var interrupted := false
	for i in 360:
		race._update_oxygen(1.0 / FPS)
		race._tick_recovery(1.0 / FPS)
		if String(race.mount.state) == "CARRYING":
			break
	if String(race.mount.state) == "CARRYING":
		race._turtle_contact("auto_interrupt", "SHARK", false)
		interrupted = true
	_check("auto_interrupt_state", interrupted
		and bool(race.rescue_auto_disabled)
		and String(race.mount.state) == "RESCUE_ACTIVE",
		"mount=%s disabled=%s" % [String(race.mount.state),
			str(race.rescue_auto_disabled)])

	# 5) 同帧：自动抬回最后一帧氧气为 0，必须失败而不是 RIDING。
	_water(120.0)
	race.mount.mark_carrying(0.1)
	race.carry_kind = "rescue_return"
	race.carry_from = race.rabbit.position
	race.carry_t = 0.1
	race.carry_dur = 0.1
	GameManager.oxygen = 0.0
	race._tick_carry(0.2)
	_check("same_frame_oxygen_wins", GameManager.state == GameManager.GameState.FAILED,
		"state=%s mount=%s" % [GameManager.state_name(), String(race.mount.state)])
	_write()
	get_tree().quit(0 if checks.all(func(c): return bool(c["ok"])) else 1)


func _water(distance: float) -> void:
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "RABBIT_WATER"
	GameManager.oxygen = 8.0
	GameManager.failure_reason = ""
	race.turtle.reset(Vector2(900.0, race.surface_ref()))
	race.turtle.speed = 220.0
	race.rabbit.reset()
	race.rabbit.position = Vector2(900.0 + distance, race.surface_ref() + 128.0)
	race.rabbit.state = "FALLING_WATER"
	race.mount.reset()
	race.mount.mark_rescue_active(3.2)
	race.rescue_prev_pos = race.rabbit.position
	race.rescue_last_result = ""
	race.rescue_last_reason = ""
	race.rescue_auto_blocked_t = 0.0
	race.carry_kind = ""
	race.carry_t = 0.0
	race.carry_dur = 0.0
	race._catch_active = false


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var f := FileAccess.open("res://docs/reports/longrun/core-feel-17-oxygen.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks}, "  "))
	f.close()
