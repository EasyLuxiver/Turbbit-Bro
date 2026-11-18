extends Node
## FEEL-22：核心状态耦合矩阵。只验证已经存在的状态机，不新增玩法。
## 覆盖 SHIFT / SHOWTIME / OVERDRIVE，救援×氧气×动态攻击，
## 以及失败/重开前的状态清理契约。旧 MISCHIEF 用例已随机制移除。

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")
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
	race.test_disable_hazards = false
	race.load_level([], [])

	_case_shift_input_cleanup()
	_case_real_physics_shift()
	_case_shift_showtime()
	_case_shift_overdrive()
	_case_rescue_oxygen_attacks()
	_case_failure_cleanup()
	_case_log_destroy()
	_case_motion_guards()
	_case_player_text()

	_write()
	get_tree().quit(0 if checks.all(func(c): return bool(c["ok"])) else 1)


func _base(control: String = "rabbit") -> void:
	GameManager._reset_run()
	GameManager.current_control = control
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.shift_lock_t = 0.0
	GameManager.accident_state = "NONE"
	race.showtime_active = false
	GameManager.showtime_active = false
	race.showtime_t = 0.0
	race._od_phase = ""
	race._od_role = ""
	race._od_t = 0.0
	race._od_cd = 0.0
	race._od_afterimages.clear()
	race._bird_attacks.clear()
	race._shark_attacks.clear()
	race._shark_pack.clear()
	race.joint_show_t = 0.0
	race.finishing = false
	race.turtle.reset(Vector2(500.0, race.surface_ref()))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	race.turtle.speed = 220.0
	race.rescue_prev_pos = race.rabbit.position


func _case_shift_input_cleanup() -> void:
	_base("turtle")
	race.turtle.standby_dive_t = 0.55
	race._buf_action = "up"
	race._buf_age = 0.0
	race._buf_shift_count = GameManager.shift_count
	race._down_delay = 1.0
	race.dive_assist = "ARMED"
	GameManager.shift_lock_t = 0.0
	GameManager.toggle_control()
	_check("shift_clears_old_dive_and_jump", race.turtle.standby_dive_t == 0.0
		and race._buf_action == "" and race._down_delay == 0.0
		and race.dive_assist == "OFF",
		"standby=%.2f buf=%s down=%.2f assist=%s" % [
			race.turtle.standby_dive_t, race._buf_action,
			race._down_delay, race.dive_assist])
	_check("shift_new_role_idle", GameManager.current_control == "rabbit"
		and race.rabbit.state == "RIDING",
		"control=%s rabbit=%s" % [GameManager.current_control,
			race.rabbit.state])
	# 控制器层：按 ↓ 时受控会潜，切走后下一帧不得继续潜。
	_base("turtle")
	race.turtle.tick(1.0 / FPS, true, false, 1.0, true, 220.0)
	var dove: bool = race.turtle.diving
	GameManager.shift_lock_t = 0.0
	GameManager.toggle_control()
	race.turtle.tick(1.0 / FPS, false, false, 0.0, true, 220.0)
	_check("turtle_does_not_inherit_dive", dove and not race.turtle.diving
		and race.turtle.standby_dive_t == 0.0,
		"dove=%s diving=%s standby=%.2f" % [str(dove),
			str(race.turtle.diving), race.turtle.standby_dive_t])


func _case_real_physics_shift() -> void:
	_base("turtle")
	race.opening_active = false
	Input.action_press("down")
	for i in 4:
		race._physics_process(1.0 / FPS)
	var dove: bool = race.turtle.diving
	Input.action_release("down")
	GameManager.shift_lock_t = 0.0
	GameManager.toggle_control()
	race._physics_process(1.0 / FPS)
	_check("real_physics_no_dive_inherit", dove and not race.turtle.diving,
		"dove=%s diving=%s" % [str(dove), str(race.turtle.diving)])
	Input.action_release("down")


func _case_shift_showtime() -> void:
	_base("rabbit")
	GameManager.combo = 0
	race.start_showtime()
	_check("showtime_starts", race.showtime_active
		and GameManager.showtime_active,
		"race=%s gm=%s" % [race.showtime_active, GameManager.showtime_active])
	GameManager.shift_lock_t = 0.0
	GameManager.toggle_control()
	race._tick_showtime(0.10)
	_check("shift_keeps_showtime", GameManager.current_control == "turtle"
		and race.showtime_active and race.rabbit.state == "SHOWTIME",
		"control=%s active=%s rabbit=%s" % [GameManager.current_control,
			race.showtime_active, race.rabbit.state])
	# 表演期间不再启动过载。
	race.rabbit_brain.drift = Tuning.DRIFT_CAP
	GameManager.current_control = "rabbit"
	race._tick_overdrive(1.0 / FPS)
	_check("overdrive_blocked_by_showtime", race._od_phase == "",
		"od=%s" % race._od_phase)
	race._end_showtime(false)


func _case_shift_overdrive() -> void:
	_base("rabbit")
	race.rabbit_brain.drift = Tuning.DRIFT_CAP
	race._tick_overdrive(1.0 / FPS)
	_check("overdrive_auto_trigger_disabled", race._od_phase == ""
		and race._od_role == "",
		"phase=%s role=%s" % [race._od_phase, race._od_role])
	GameManager.shift_lock_t = 0.0
	GameManager.toggle_control()
	for i in 10:
		race._tick_overdrive(1.0 / FPS)
	_check("overdrive_stays_off_after_shift", race._od_phase == "",
		"phase=%s control=%s" % [race._od_phase, GameManager.current_control])


func _case_rescue_oxygen_attacks() -> void:
	_base("rabbit")
	GameManager.accident_state = "RABBIT_WATER"
	race.rabbit.state = "FALLING_WATER"
	race.rabbit.position = race.turtle.get_mount_point() + Vector2(300, 100)
	race.rabbit.velocity = Vector2.ZERO
	race.rescue_prev_pos = race.rabbit.position
	race.mount.mark_rescue_active(0.0)
	race.rescue_last_result = ""
	GameManager.oxygen = 0.50
	race.rescue_auto_blocked_t = 0.0
	race._tick_recovery(0.02)
	_check("auto_rescue_blocked_low_air", race.rescue_last_result != "auto"
		and race.mount.state == "RESCUE_ACTIVE",
		"result=%s mount=%s oxygen=%.2f" % [race.rescue_last_result,
			race.mount.state, GameManager.oxygen])
	# FEEL-22：超时自动回壳已取消；氧够也不能自动接。
	GameManager.oxygen = 2.0
	race._tick_recovery(0.02)
	_check("auto_rescue_disabled", race.rescue_last_result != "auto"
		and race.mount.state == "RESCUE_ACTIVE",
		"result=%s mount=%s oxygen=%.2f" % [race.rescue_last_result,
			race.mount.state, GameManager.oxygen])
	# 救援中的鸟/鲨攻击必须清空，且不记账。
	_base("rabbit")
	GameManager.accident_state = "RABBIT_WATER"
	race.rabbit.state = "FALLING_WATER"
	race.test_disable_hazards = false
	race._bird_attacks = [{"type": "body", "target": "rabbit", "x": 500.0,
		"vx": 0.0, "life": 1.0, "t": 0.0, "group": "bird1"}]
	race._shark_attacks = [{"target": "rabbit", "rect": Rect2(480, 300, 70, 86),
		"t": 0.0, "life": 1.0, "group": "shark6"}]
	var before: int = GameManager.accident_count
	race._check_bird_attacks(0.01)
	race._check_shark_attacks(0.01)
	_check("rescue_clears_attacks", race._bird_attacks.is_empty()
		and race._shark_attacks.is_empty()
		and GameManager.accident_count == before,
		"bird=%d shark=%d accidents=%d->%d" % [race._bird_attacks.size(),
			race._shark_attacks.size(), before, GameManager.accident_count])


func _case_failure_cleanup() -> void:
	_base("rabbit")
	GameManager.showtime_active = true
	GameManager.shift_lock_t = 0.2
	GameManager.finished = true
	GameManager._reset_run()
	_check("retry_reset_global", GameManager.accident_state == "NONE"
		and not GameManager.showtime_active
		and GameManager.shift_lock_t == 0.0
		and not GameManager.finished
		and GameManager.oxygen == Tuning.OXYGEN_MAX,
		"accident=%s show=%s lock=%.2f finished=%s" % [
			GameManager.accident_state, GameManager.showtime_active,
			GameManager.shift_lock_t, GameManager.finished])


func _case_player_text() -> void:
	var old_lang: String = Locale.language
	Locale.language = "zh"
	var fail_sub := Locale.t("fail.sub")
	var result_title := Locale.t("result.title")
	var antidote := Locale.t("result.antidote")
	var progress := Locale.t("hud.progress", [12, 55])
	var drift := Locale.t("hud.drift_effect_turtle", [90])
	_check("fail_text_in_character", fail_sub.contains("氧气")
		and not fail_sub.contains("结算") and not fail_sub.contains("普通"),
		fail_sub)
	_check("result_has_antidote", antidote.contains("解药")
		and result_title == "训练结束",
		"%s | %s" % [result_title, antidote])
	GameManager.waterlogged = 0
	GameManager.waterlogged_t = 0.0
	GameManager.note_fall()
	var cap1 := GameManager.oxygen_capacity()
	GameManager.tick_waterlogged(30.0)
	_check("waterlogged_caps_and_recovers", cap1 < Tuning.OXYGEN_MAX
		and GameManager.waterlogged == 0 and GameManager.oxygen_capacity() == Tuning.OXYGEN_MAX,
		"cap=%.1f level=%d" % [cap1, GameManager.waterlogged])
	_check("hud_has_no_debug_units", progress == "赛程 12/55"
		and not drift.contains("px") and drift.contains("壳在晃"),
		"%s | %s" % [progress, drift])
	Locale.language = old_lang


func _case_log_destroy() -> void:
	_base("rabbit")
	var g := LevelData.build_group({"group": "logx", "zone": 1,
		"kind": "FLOATING_LOG", "x": 900.0, "w": 32.0})
	race.load_level([g], [])
	race.test_disable_hazards = false
	race.turtle.reset(Vector2(860.0, race.surface_ref()))
	race.rabbit.reset()
	var log_rect: Rect2 = race.hazard_rect_live(g, 0)
	race.rabbit.position = log_rect.get_center()
	race.turtle.position = log_rect.get_center()
	race.rabbit.state = "JUMPING"
	race.group_actions["logx"] = {"jumped": true}
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	GameManager.accident_state = "NONE"
	race._check_hazards()
	_check("failed_log_destroys_once", race.destroyed_groups.has("logx")
		and race.passed_groups.has("logx"),
		"destroyed=%s passed=%s" % [str(race.destroyed_groups.has("logx")),
			str(race.passed_groups.has("logx"))])


func _case_motion_guards() -> void:
	_base("turtle")
	race.turtle.position.y = Tuning.NEUTRAL_DEPTH + 150.0
	var deep_can: bool = race.turtle.can_leap()
	race.turtle.position.y = Tuning.NEUTRAL_DEPTH
	var surface_can: bool = race.turtle.can_leap()
	_check("no_underwater_leap", not deep_can and surface_can,
		"deep=%s surface=%s" % [str(deep_can), str(surface_can)])
	var g := LevelData.build_group({"group": "gatex", "zone": 3,
		"kind": "DIVE_GATE", "x": 1000.0, "w": 760.0})
	race.load_level([g], [])
	race.turtle.reset(Vector2(1300.0, race.surface_ref()))
	var before: float = race.turtle.position.x
	race._resolve_turtle_solid()
	_check("long_gate_no_left_snap", absf(race.turtle.position.x - before) < 1.0,
		"before=%.0f after=%.0f" % [before, race.turtle.position.x])


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var f := FileAccess.open(
		"res://docs/reports/longrun/core-feel-22-coupling.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks}, "  "))
	f.close()
