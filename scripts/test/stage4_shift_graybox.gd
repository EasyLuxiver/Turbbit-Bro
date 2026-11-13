extends Node
## 阶段 4 SHIFT 灰盒：验证“切换不能直接清空滑落/下沉风险”（GDD 6.3）。
## 固定步长手动推进真实 race.gd 的 _physics_process，不依赖真机帧率。
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT res://scenes/stage4_shift_graybox.tscn
## 输出：docs/reports/stage4-shift-graybox.json
##
## 这不是人工试玩：只证明状态机在切换瞬间保留了哪些数，以及受控恢复需要多久。

const Tuning = preload("res://scripts/systems/tuning.gd")
const OUT_PATH := "res://docs/reports/stage4-shift-graybox.json"
const STEP := 1.0 / 60.0

var is_runner := false
var failures: Array[String] = []
var race
var data := {}


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4ShiftGrayboxRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	Locale.language = "en"
	GameManager.start_race()
	await _wait_scene("race.tscn")
	await _frames(4)
	race = get_tree().current_scene
	_check(race != null, "race scene loaded")
	if race == null:
		_finish()
		return

	# 只测状态机，不测障碍；也不冲线、不写 best.json。
	race.test_disable_hazards = true
	race.test_no_finish = true
	race.set_physics_process(false)
	race.turtle.position = Vector2(5200.0, 300.0)
	race.turtle.speed = 0.0
	race.turtle.daze_time = 0.0
	race.turtle._sink_speed = 0.0
	race.rabbit.daze_time = 0.0
	race.rabbit.slide = 0.0
	GameManager.set_control("turtle")
	_tick(1)

	data["rabbit_handoff"] = _rabbit_handoff()
	data["turtle_handoff"] = _turtle_handoff()
	data["rapid_switch"] = _rapid_switch()
	data["rabbit_recovery"] = _recovery("rabbit")
	data["turtle_recovery"] = _recovery("turtle")
	data["shift_event"] = _shift_event()
	data["recover_rate"] = Tuning.CONTROL_RECOVER_RATE
	data["recover_delay"] = Tuning.CONTROL_RECOVER_DELAY
	_write_json()
	_finish()


func _rabbit_handoff() -> Dictionary:
	# 控制乌龟，让兔子神游到危险期，再切回兔子：计时和滑移必须还在。
	GameManager.set_control("turtle")
	race.turtle.position.y = 300.0
	race.turtle._sink_speed = 0.0
	race.rabbit.daze_time = 2.90
	race.rabbit.slide = race.rabbit.slide_for_time(2.90)
	_tick(1)
	var before := _rabbit_values()
	GameManager.toggle_control()
	_tick(1)
	var after := _rabbit_values()
	var offset_shift: float = absf(after["offset_x"] - before["offset_x"])
	# 滑移量按当前五段模型取 2.9 s 的应有值（0.35 的段落里约 0.16），
	# 这里守的是“切换前后一点没丢”，不写死某个阶段的绝对值。
	var kept: bool = after["daze"] > 2.5 and after["slide"] > 0.05 \
		and absf(after["slide"] - race.rabbit.slide_for_time(2.90)) < 0.02 \
		and offset_shift < 1.0
	_check(kept, "rabbit handoff keeps daze/slide/offset (%.3f/%.3f off %.1f)"
		% [after["daze"], after["slide"], offset_shift])
	_check(before["daze"] > 2.5, "rabbit was actually at risk before handoff")
	race.hud._refresh()
	_check(race.hud._rabbit_action() == Locale.state_name("RECOVERING"),
		"rabbit HUD shows lingering recovery (%s)" % race.hud._rabbit_action())
	return {"before": before, "after": after, "offset_shift_px": snappedf(offset_shift, 0.01)}


func _turtle_handoff() -> Dictionary:
	# 控制兔子，让乌龟沉到危险期，再切回乌龟：深度、计时、下沉速度必须还在。
	GameManager.set_control("rabbit")
	race.rabbit.daze_time = 0.0
	race.turtle.position.y = 520.0
	race.turtle.daze_time = 2.90
	race.turtle._sink_speed = 60.0
	_tick(1)
	var before := _turtle_values()
	GameManager.toggle_control()
	_tick(1)
	var after := _turtle_values()
	var y_shift: float = absf(after["y"] - before["y"])
	# 冲浪板模型没有“下沉速度”：失控的深度由浮力回浮接管，一帧最多
	# DIVE_RISE_SPEED/60 = 7 px。守的是“SHIFT 没有把壳瞬移回巡航水深（334）”，
	# 而不是“这一帧不许动”——1.8 px 正是浮力从 -10 加速到 -110 的位移。
	var kept: bool = after["daze"] > 2.5 and y_shift <= 7.5 \
		and after["y"] > 500.0 and after["vy"] < 0.0
	_check(kept, "turtle handoff keeps depth/daze (y %.1f daze %.3f vy %.1f)"
		% [after["y"], after["daze"], after["vy"]])
	race.hud._refresh()
	_check(race.hud._turtle_action() == Locale.state_name("RECOVERING"),
		"turtle HUD shows lingering recovery (%s)" % race.hud._turtle_action())
	return {"before": before, "after": after, "y_shift_px": snappedf(y_shift, 0.01)}


func _rapid_switch() -> Dictionary:
	# 两个角色都在 2.9 s 风险期，快速来回切 10 次（每次 0.1 s）。
	# 正确行为：风险只在两人之间转移，不会被每次切换清空。
	GameManager.set_control("turtle")
	race.turtle.position.y = 520.0
	race.turtle.daze_time = 2.90
	race.turtle._sink_speed = 60.0
	race.rabbit.daze_time = 2.90
	race.rabbit.slide = race.rabbit.slide_for_time(2.90)
	_tick(1)
	for i in 10:
		GameManager.toggle_control()
		_tick(6)
	var rabbit := _rabbit_values()
	var turtle := _turtle_values()
	var kept: bool = rabbit["daze"] > 2.0 and turtle["daze"] > 2.0 \
		and GameManager.accident_state == "NONE"
	_check(kept, "rapid SHIFT cannot clear both risks (rabbit %.3f turtle %.3f)"
		% [rabbit["daze"], turtle["daze"]])
	return {
		"switches": 10,
		"rabbit_after": rabbit,
		"turtle_after": turtle,
		"accident": GameManager.accident_state,
	}


func _recovery(who: String) -> Dictionary:
	# 从 EDGE（3.3 s）恢复到 0 需要实际控制时间，而不是一次 SHIFT。
	GameManager.set_control("turtle" if who == "rabbit" else "rabbit")
	GameManager.set_control(who)
	if who == "rabbit":
		race.turtle_grace = 0.0
		race.rabbit_grace = 0.0
		race.turtle.position.y = 300.0
		race.turtle.daze_time = 0.0
		race.turtle._sink_speed = 0.0
		race.rabbit.daze_time = 3.30
		race.rabbit.slide = race.rabbit.slide_for_time(3.30)
	else:
		race.rabbit_grace = 0.0
		race.turtle_grace = 0.0
		race.rabbit.daze_time = 0.0
		race.rabbit.slide = 0.0
		race.turtle.position.y = 520.0
		race.turtle.daze_time = 3.30
		race.turtle._sink_speed = 60.0
		# 冲浪板模型没有“按住上浮”：控制权一给乌龟，浮力就开始把它抬回巡航水深。
	var frames := 0
	while frames < 360:
		_tick(1)
		frames += 1
		if who == "rabbit" and race.rabbit.daze_time <= 0.0001:
			break
		if who == "turtle" and race.turtle.daze_time <= 0.0001:
			break
	var seconds := frames * STEP
	# 计时清零只是“恢复”，壳还在上浮路上；再走一小段确认浮力真的把它送回巡航水深。
	var settle_frames := 0
	if who == "turtle":
		while absf(race.turtle.position.y - Tuning.NEUTRAL_DEPTH) >= 2.0 \
				and settle_frames < 120 and GameManager.accident_state == "NONE":
			_tick(1)
			settle_frames += 1
	var partner_daze: float = race.turtle.daze_time if who == "rabbit" \
		else race.rabbit.daze_time
	var ok: bool = seconds >= 1.6 and seconds <= 2.1 \
		and GameManager.accident_state == "NONE" and partner_daze < 3.6
	if who == "turtle":
		ok = ok and absf(race.turtle.position.y - Tuning.NEUTRAL_DEPTH) < 2.0
	_check(ok, "%s controlled recovery takes %.2f s, partner at %.2f s risk"
		% [who, seconds, partner_daze])
	return {
		"seconds": snappedf(seconds, 0.01),
		"frames": frames,
		"settle_frames": settle_frames,
		"accident": GameManager.accident_state,
		"partner_daze": snappedf(partner_daze, 0.001),
		"turtle_y": snappedf(race.turtle.position.y, 0.1),
	}


func _rabbit_values() -> Dictionary:
	return {
		"daze": snappedf(race.rabbit.daze_time, 0.001),
		"slide": snappedf(race.rabbit.slide, 0.001),
		"offset_x": snappedf(race.rabbit.position.x - race.turtle.get_mount_point().x, 0.01),
	}


func _turtle_values() -> Dictionary:
	return {
		"daze": snappedf(race.turtle.daze_time, 0.001),
		"y": snappedf(race.turtle.position.y, 0.01),
		"sink_speed": snappedf(race.turtle._sink_speed, 0.01),
		"vy": snappedf(race.turtle._vy, 0.01),
	}


func _tick(n: int) -> void:
	for i in n:
		race._physics_process(STEP)


func _wait_scene(suffix: String) -> void:
	for i in 240:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path.ends_with(suffix):
			return
	_check(false, "scene %s loaded" % suffix)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## §8 SHIFT 电击只做事件接口：一次换人恰好一发，同一帧生效，不阻塞；
## 程序换人（set_control）不冒充玩家电击。
func _shift_event() -> Dictionary:
	var events: Array = []
	var cb := func(from_who: String, to_who: String) -> void:
		events.append([from_who, to_who])
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.showtime_active = false
	GameManager.shift_shocked.connect(cb)
	GameManager.set_control("turtle")
	_tick(1)
	var before := GameManager.current_control
	GameManager.toggle_control()
	var switched_same_frame: bool = GameManager.current_control != before
	var after_toggle := events.size()
	GameManager.set_control("turtle")
	var after_direct := events.size()
	GameManager.shift_shocked.disconnect(cb)
	_check(after_toggle == 1 and switched_same_frame,
		"SHIFT fires shift_shocked once, same frame (%d)" % after_toggle)
	_check(after_direct == after_toggle,
		"set_control does not fake a player SHIFT (%d->%d)" % [after_toggle, after_direct])
	var ev: Array = events[0] if events.size() > 0 else []
	_check(ev.size() == 2 and String(ev[0]) == "turtle" and String(ev[1]) == "rabbit",
		"shift_shocked from/to correct (%s)" % str(ev))
	return {
		"events": events.size(),
		"same_frame": switched_same_frame,
		"direct_events": after_direct - after_toggle,
		"first": ev,
	}


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)


func _write_json() -> void:
	var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if file == null:
		failures.append("write %s" % OUT_PATH)
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()


func _finish() -> void:
	Locale.language = "zh"
	if failures.is_empty():
		print("STAGE4 SHIFT GRAYBOX: PASS")
	else:
		print("STAGE4 SHIFT GRAYBOX: FAIL")
		for item in failures:
			print("  - " + item)
	print("  data: " + JSON.stringify(data))
	get_tree().quit(0 if failures.is_empty() else 1)
