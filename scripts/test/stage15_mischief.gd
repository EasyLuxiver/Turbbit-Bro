extends Node
## FEEL-15：双向 BRO MISCHIEF、SHIFT 中断、救援优先级、惩罚条重置。

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

	# 1) BITT 满、玩家控 TUBO：BITT 捣乱，TUBO 仍可控。
	_reset("rabbit")
	_fill("turtle")
	race._tick_mischief(1.0 / FPS)
	_check("1_bitt_mischief", race._mischief_role == "turtle"
		and GameManager.current_control == "rabbit",
		"role=%s control=%s phase=%s" % [race._mischief_role,
			GameManager.current_control, race._mischief_phase])
	_tick_for(0.50)
	_check("1b_shock_effect", race._mischief_phase == "ACTION"
		and race._mischief_fx_kind == "shock",
		"phase=%s fx=%s" % [race._mischief_phase, race._mischief_fx_kind])
	_tick_for(1.2)
	_check("1c_resets", race._mischief_role == ""
		and GameManager.role_meter("turtle") == 0,
		"role=%s meter=%d" % [race._mischief_role, GameManager.role_meter("turtle")])

	# 2) TUBO 满、玩家控 BITT：TUBO 拽 BITT，减速。
	_reset("turtle")
	_fill("rabbit")
	race._tick_mischief(1.0 / FPS)
	_tick_for(0.50)
	_check("2_tubo_mischief", race._mischief_role == "rabbit"
		and race._mischief_fx_kind == "tug",
		"role=%s fx=%s" % [race._mischief_role, race._mischief_fx_kind])

	# 3) 失控中 SHIFT：旧角色立即停止，新未受控满格角色接管。
	_reset("rabbit")
	_fill("turtle")
	race._tick_mischief(1.0 / FPS)
	GameManager.shift_lock_t = 0.0
	GameManager.toggle_control()
	race._tick_mischief(1.0 / FPS)
	_check("3_shift_stops_old", race._mischief_role != "turtle"
		and GameManager.role_meter("turtle") == 0,
		"role=%s turtle_meter=%d" % [race._mischief_role,
			GameManager.role_meter("turtle")])
	# 新成为未受控的 TUBO 已经满格：由它接管。
	_fill("rabbit")
	race._mischief_last_control = GameManager.current_control
	race._tick_mischief(1.0 / FPS)
	_check("3b_new_role_takes_over", race._mischief_role == "rabbit",
		"role=%s" % race._mischief_role)

	# 3c) 动作进行期间 SHIFT 也必须当帧停止，不继续施加下一次电击/牵引。
	_reset("rabbit")
	_fill("turtle")
	race._tick_mischief(1.0 / FPS)
	_tick_for(0.50) # 进入 ACTION 并已施加一次
	GameManager.shift_lock_t = 0.0
	GameManager.toggle_control()
	race._tick_mischief(1.0 / FPS)
	_check("3c_action_shift_stops", race._mischief_role == ""
		and GameManager.role_meter("turtle") == 0,
		"role=%s meter=%d" % [race._mischief_role, GameManager.role_meter("turtle")])

	# 4) 前摇期间 SHIFT 也必须停止，不留下电击/牵引。
	_reset("rabbit")
	_fill("turtle")
	race._tick_mischief(1.0 / FPS)
	GameManager.shift_lock_t = 0.0
	GameManager.toggle_control()
	race._tick_mischief(1.0 / FPS)
	_tick_for(1.2)
	_check("4_no_residual_fx", race._mischief_role == ""
		and race._mischief_fx_kind == "",
		"role=%s fx=%s" % [race._mischief_role, race._mischief_fx_kind])

	# 5) 救援优先级：TUBO 落水时，BITT 的捣乱立即结束；切 BITT 后可以救援。
	_reset("rabbit")
	_fill("turtle")
	race._tick_mischief(1.0 / FPS)
	GameManager.accident_state = "RABBIT_WATER"
	race.rabbit.state = "FALLING_WATER"
	race.rabbit.position = Vector2(1180.0, race.surface_ref() + 128.0)
	race.mount.mark_rescue_active(3.2)
	race._tick_mischief(1.0 / FPS)
	_check("5_rescue_priority", race._mischief_role == ""
		and GameManager.role_meter("turtle") == 0,
		"role=%s meter=%d" % [race._mischief_role, GameManager.role_meter("turtle")])
	GameManager.shift_lock_t = 0.0
	GameManager.toggle_control()
	race._try_role_skill()
	_check("5b_bitt_can_catch", GameManager.current_control == "turtle"
		and bool(race._catch_active),
		"control=%s catch=%s" % [GameManager.current_control,
			str(race._catch_active)])

	# 6) 不出现双角色同时失控。
	_reset("rabbit")
	_fill("turtle")
	_fill("rabbit")
	race._tick_mischief(1.0 / FPS)
	_tick_for(0.2)
	var only_one: bool = race._mischief_role in ["", "rabbit", "turtle"]
	_check("6_single_role", only_one, "role=%s" % race._mischief_role)

	# 7) 30/120 Hz：事件仍能完整结束并重置，不依赖 60 Hz。
	for hz in [30.0, 120.0]:
		_reset("rabbit")
		_fill("turtle")
		race._tick_mischief(1.0 / hz)
		var steps := 0
		while race._mischief_role != "" and steps < int(4.0 * hz):
			race._tick_mischief(1.0 / hz)
			steps += 1
		_check("7_mischief_hz_%d" % int(hz), race._mischief_role == ""
			and GameManager.role_meter("turtle") == 0,
			"steps=%d role=%s meter=%d" % [steps, race._mischief_role,
				GameManager.role_meter("turtle")])
	_write()
	get_tree().quit(0 if checks.all(func(c): return bool(c["ok"])) else 1)


func _reset(control: String) -> void:
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.current_control = control
	GameManager.shift_lock_t = 0.0
	GameManager.accident_state = "NONE"
	GameManager.clear_bro_meter()
	GameManager.test_no_best = true
	race._mischief_role = ""
	race._mischief_phase = ""
	race._mischief_t = 0.0
	race._mischief_cd = 0.0
	race._mischief_last_control = control
	race._mischief_fx_kind = ""
	race._mischief_fx_t = 0.0
	race._mischief_action_done = false
	race.mount.reset()
	race.mount.mark_riding()
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.turtle.reset(Vector2(900.0, race.surface_ref()))
	race.turtle.speed = 220.0


func _fill(who: String) -> void:
	for i in 3:
		GameManager.note_mistake("TURTLE_WAVE" if who == "turtle" else "RABBIT_STUN", who)


func _tick_for(seconds: float) -> void:
	var n := int(seconds * FPS)
	for i in n:
		race._tick_mischief(1.0 / FPS)


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var f := FileAccess.open("res://docs/reports/longrun/core-feel-15-mischief.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks}, "  "))
	f.close()
