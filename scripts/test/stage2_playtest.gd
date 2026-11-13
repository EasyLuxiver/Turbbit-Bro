extends Node
## 阶段 2 脚本化连续运行：90 秒模拟时间，跑主赛道三圈。
## 覆盖：三次干净通过触发 Showtime、加速通道、兔子硬直、乌龟触礁，
## 以及每次事故后的恢复；结束时重开验证各项重置。
## LEGACY（2026-11-11）：本脚本按旧“手动下潜”编排（_prepare_turtle/_dive_to/
## _surface），非对称冲浪板下这些按键不再改变深度，日志里的 DIVE 段会打 WARN。
## 它不属于回归闸门；正确模型见 stage3_playtest（正式关卡全流程）。
## 【已退役 2026-11-11】阶段 4 五类空间重构后，本脚本的按键编排与主赛道
## 位置都已过期；直接以 exit 2 退出，不再覆盖 docs/reports/stage2-run.log。
## 当前回归以 stage1/2/3_selftest + stage3_playtest + stage4_* 为准。
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT res://scenes/stage2_playtest.tscn

const Tuning = preload("res://scripts/systems/tuning.gd")
const DURATION := 90.0
const LOG_PATH := "res://docs/reports/stage2-run.log"
const LAP_END := 6100.0
const START_X := 400.0

var is_runner := false
var lines: Array[String] = []
var failures: Array[String] = []
var race
var seen_accidents := {}
var saw_boost := false
var max_accident_elapsed := 0.0
var stuck_elapsed := 0.0
var lap := 1
var laps_completed := 0
# 看门狗必须用成员变量：GDScript lambda 里的局部变量按值捕获，赋值不会保留。
var _wd_last_accident := "NONE"
var _wd_accident_elapsed := 0.0
var _wd_last_t := 0.0
var _wd_last_x := 0.0


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage2PlaytestRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	print("STAGE2 PLAYTEST: RETIRED — pre-Stage-4 key choreography; see header.")
	get_tree().quit(2)
	return
	Engine.time_scale = 3.0
	_log("STAGE 2 SCRIPTED RUN  duration=%.0fs  time_scale=3.0" % DURATION)

	GameManager.start_race()
	await _frames(3)
	race = get_tree().current_scene
	race.test_no_finish = true
	_check(race.scene_file_path.ends_with("race.tscn"), "race scene loaded")
	_check(GameManager.state == GameManager.GameState.RUNNING, "state RUNNING")

	_start_watchdog()

	# ---- 第 1 圈：干净通过前三个障碍 -> Showtime；加速；故意撞墙 -> 触礁。 ----
	await _jump_at(1270)
	await _crouch_at(2070.0, 2295.0)
	await _travel_to(2560)
	await _control_to("turtle")
	Input.action_press("boost")
	await _until_x(3240)
	Input.action_release("boost")
	await _control_to("rabbit")
	if GameManager.combo >= 2:
		_log("t=%5.2f  COMBO %d before reef" % [GameManager.race_time, GameManager.combo])

	await _travel_to(3430)
	await _prepare_turtle()
	Input.action_press("down")
	await _dive_to(340.0)
	await _until_x(4010)
	await _surface()
	await _control_to("rabbit")

	# 这里不潜水：验证乌龟撞墙事故与恢复。
	await _travel_to(4200)
	await _until_accident("TURTLE_REEF", 6.0)
	await _until_accident_none(6.0)
	await _recover_wall()
	# 组合段按任务书提示“DIVE BOTH”：潜水同时越过岩石与横梁。
	await _travel_to(5060)
	await _prepare_turtle()
	Input.action_press("down")
	await _dive_to(360.0)
	await _until_x(5810)
	await _surface()
	await _control_to("rabbit")
	await _travel_to(LAP_END)
	await _wrap_lap()

	# ---- 第 2 圈：故意不蹲 -> 兔子硬直；再撞一次墙并恢复。 ----
	await _jump_at(1270)
	# 故意不蹲：站着推进横梁，等 RABBIT_STUN。
	await _travel_to(2020)
	await _prepare_rabbit()
	await _until_accident("RABBIT_STUN", 3.0)
	await _until_accident_none(3.0)
	await _control_to("rabbit")

	await _travel_to(3430)
	await _prepare_turtle()
	Input.action_press("down")
	await _dive_to(340.0)
	await _until_x(4010)
	await _surface()
	await _control_to("rabbit")

	await _travel_to(4200)
	await _until_accident("TURTLE_REEF", 6.0)
	await _until_accident_none(6.0)
	await _recover_wall()
	# 组合段按任务书提示“DIVE BOTH”：潜水同时越过岩石与横梁。
	await _travel_to(5060)
	await _prepare_turtle()
	Input.action_press("down")
	await _dive_to(360.0)
	await _until_x(5810)
	await _surface()
	await _control_to("rabbit")
	await _travel_to(LAP_END)
	await _wrap_lap()

	# ---- 第 3 圈：全部正确动作，跑到 90 秒。 ----
	await _jump_at(1270)
	await _crouch_at(2070.0, 2295.0)

	await _travel_to(3430)
	await _prepare_turtle()
	Input.action_press("down")
	await _dive_to(340.0)
	await _until_x(4010)
	await _surface()
	await _control_to("rabbit")

	await _travel_to(4200)
	await _until_accident("TURTLE_REEF", 6.0)
	await _until_accident_none(6.0)
	await _recover_wall()
	# 组合段按任务书提示“DIVE BOTH”：潜水同时越过岩石与横梁。
	await _travel_to(5060)
	await _prepare_turtle()
	Input.action_press("down")
	await _dive_to(360.0)
	await _until_x(5810)
	await _surface()
	await _control_to("rabbit")

	# 剩余时间继续前进，保证是“连续运行”而不是提前结算。
	while GameManager.race_time < DURATION:
		await get_tree().physics_frame

	_release_all()

	# ---- 判定。 ----
	var showtime_total: int = GameManager.showtime_count
	var shifts_total: int = GameManager.shift_count
	var accidents_total: int = GameManager.accident_count
	var classes := PackedStringArray(seen_accidents.keys())
	_check(showtime_total >= 1, "at least one Showtime (%d)" % showtime_total)
	_check(seen_accidents.has("RABBIT_STUN") and seen_accidents.has("TURTLE_REEF"),
		"two accident classes observed (%s)" % ", ".join(classes))
	_check(saw_boost, "boost observed")
	_check(max_accident_elapsed < 5.0,
		"no accident lasts >=5s (max %.2fs)" % max_accident_elapsed)
	_check(stuck_elapsed <= 6.0, "no >6s unrecoverable stall (%.2fs)" % stuck_elapsed)
	_check(GameManager.race_time >= DURATION - 1.0,
		"ran full duration (%.2fs)" % GameManager.race_time)
	_check(GameManager.current_control in ["rabbit", "turtle"], "control remains valid")

	var combo_before: int = GameManager.combo
	var sim_time: float = GameManager.race_time
	GameManager.start_race()
	await _frames(3)
	_check(GameManager.current_control == "rabbit", "restart resets control")
	_check(is_equal_approx(GameManager.oxygen, Tuning.OXYGEN_MAX), "restart resets oxygen")
	# 场景加载会吃掉几帧；判断的是“重置”，不是精确的零。
	_check(GameManager.race_time < 0.5, "restart resets race time")
	_check(GameManager.combo == 0 and GameManager.showtime_count == 0,
		"restart resets combo / showtime (was combo=%d)" % combo_before)
	_check(GameManager.shift_count == 0 and GameManager.accident_count == 0,
		"restart resets counters (was shifts=%d accidents=%d)" % [
			shifts_total, accidents_total])

	_log("")
	_log("RESULT  simulated=%.2fs  laps=%d  shifts=%d  showtime=%d  accidents=%d" % [
		sim_time, laps_completed, shifts_total, showtime_total, accidents_total])
	_log("RESULT  classes=%s  max_accident=%.2fs  stuck=%.2fs  failures=%d" % [
		", ".join(classes), max_accident_elapsed, stuck_elapsed, failures.size()])
	for item in failures:
		_log("FAIL  " + item)

	_write_log()
	Engine.time_scale = 1.0
	if failures.is_empty():
		print("STAGE2 PLAYTEST: PASS")
		get_tree().quit(0)
	else:
		print("STAGE2 PLAYTEST: FAIL")
		for item in failures:
			print("  - " + item)
		get_tree().quit(1)


func _start_watchdog() -> void:
	# 后台看门狗：记录事故持续时间、前进停滞和加速，不打断主脚本。
	_wd_last_x = race.turtle.position.x
	_wd_last_t = 0.0
	_wd_last_accident = "NONE"
	_wd_accident_elapsed = 0.0
	var watchdog := Timer.new()
	watchdog.wait_time = 0.1
	watchdog.autostart = true
	add_child(watchdog)
	watchdog.timeout.connect(_watchdog_tick)


func _watchdog_tick() -> void:
	var t: float = GameManager.race_time
	if GameManager.turtle_speed > 340.0:
		saw_boost = true
	if GameManager.accident_state != _wd_last_accident:
		if GameManager.accident_state != "NONE":
			seen_accidents[GameManager.accident_state] = true
			_log("t=%5.2f  ACCIDENT %s  control=%s x=%.0f" % [
				t, GameManager.accident_state, GameManager.current_control,
				race.turtle.position.x])
		else:
			_log("t=%5.2f  RECOVERED  control=%s x=%.0f" % [
				t, GameManager.current_control, race.turtle.position.x])
		_wd_last_accident = GameManager.accident_state
	if GameManager.accident_state != "NONE":
		_wd_accident_elapsed += 0.1
		max_accident_elapsed = maxf(max_accident_elapsed, _wd_accident_elapsed)
	else:
		_wd_accident_elapsed = 0.0
	if t - _wd_last_t >= 1.0:
		var moved: float = race.turtle.position.x - _wd_last_x
		if moved < 30.0 and GameManager.accident_state == "NONE":
			stuck_elapsed += t - _wd_last_t
		else:
			stuck_elapsed = 0.0
		_wd_last_x = race.turtle.position.x
		_wd_last_t = t
		_log("t=%5.2f  lap=%d x=%.0f y=%.0f state=%s control=%s mount=%s " % [
			t, lap, race.turtle.position.x, race.turtle.position.y,
			GameManager.accident_state,
			GameManager.current_control, race.mount.state]
			+ "rabbit=%s turtle=%s oxy=%.1f combo=%d show=%d" % [
			race.rabbit.state, race.turtle.state, GameManager.oxygen,
			GameManager.combo, GameManager.showtime_count])


func _until_x(target: float, limit := 25.0) -> void:
	var start: float = GameManager.race_time
	while GameManager.race_time < DURATION:
		if race.turtle.position.x >= target:
			return
		if GameManager.race_time - start > limit:
			_log("WARN  wait x=%.0f timed out at x=%.0f" % [target, race.turtle.position.x])
			return
		await get_tree().physics_frame


func _travel_to(target: float) -> void:
	# 开阔水域按玩家节奏交替换人：任何一方无人控制都不超过约 2 秒，
	# 避免兔子滑落或乌龟沉底把长跑变成连环事故。
	var last_switch: float = GameManager.race_time
	while GameManager.race_time < DURATION and race.turtle.position.x < target:
		if not GameManager.showtime_active and race.mount.state == "RIDING" \
				and GameManager.race_time - last_switch > 1.2:
			if GameManager.current_control == "rabbit":
				await _control_to("turtle")
				if race.turtle.position.y > 305.0:
					await _surface()
			else:
				await _control_to("rabbit")
			last_switch = GameManager.race_time
		await get_tree().physics_frame
	# 每段位移都在“兔子掌控、乌龟在水面”结束：
	# 后续跳跃/下潜的计时从干净状态起算，不继承上一段留下的神游余量。
	await _prepare_rabbit()


func _prepare_rabbit() -> void:
	# 两端神游时钟都归零：短暂交给乌龟（重置乌龟计时）后立刻收回兔子。
	if GameManager.showtime_active:
		return
	await _prepare_turtle()
	await _control_to("rabbit")


func _prepare_turtle() -> void:
	# 先切回兔子让它的神游时钟归零，再交回乌龟并上浮，
	# 保证下潜动作一开始就是完整的状态窗口。
	await _control_to("rabbit")
	await _control_to("turtle")
	if race.turtle.position.y > 305.0:
		await _surface()


func _until_accident(reason: String, limit := 6.0) -> void:
	var start: float = GameManager.race_time
	while GameManager.race_time - start < limit:
		if GameManager.accident_state == reason:
			return
		await get_tree().physics_frame
	_log("WARN  accident %s not seen (state=%s)" % [reason, GameManager.accident_state])


func _until_accident_none(limit := 6.0) -> void:
	var start: float = GameManager.race_time
	while GameManager.race_time - start < limit:
		if GameManager.accident_state == "NONE":
			return
		await get_tree().physics_frame
	_log("WARN  accident did not clear (%s)" % GameManager.accident_state)


func _jump_at(trigger: float) -> void:
	# 先退到触发点前 160 px 完成上浮/换人准备，再按 x 精确起跳。
	# 准备动作（上浮 + 两次换人）会让乌龟继续前进约 40～70 px，
	# 直接“到位后换人”会把兔子送进岩石，起跳变成撞头。
	await _travel_to(trigger - 160.0)
	await _prepare_turtle()
	# 神游会掉速；先把速度喂回巡航档，再交给兔子，起跳才有足够水平速度越过岩檐。
	var t0: float = GameManager.race_time
	while GameManager.race_time - t0 < 3.0 and race.turtle.speed < 205.0:
		await get_tree().physics_frame
	await _control_to("rabbit")
	while GameManager.race_time < DURATION and race.turtle.position.x < trigger:
		await get_tree().physics_frame
	await _jump()


func _crouch_at(start_x: float, end_x: float) -> void:
	# 蹲伏段同样把上浮/换人放在远处完成：滑行中上浮会让兔子站着撞上横梁。
	await _travel_to(start_x - 90.0)
	await _prepare_turtle()
	var t0: float = GameManager.race_time
	while GameManager.race_time - t0 < 3.0 and race.turtle.speed < 205.0:
		await get_tree().physics_frame
	await _control_to("rabbit")
	while GameManager.race_time < DURATION and race.turtle.position.x < start_x:
		await get_tree().physics_frame
	Input.action_press("down")
	await _until_x(end_x)
	Input.action_release("down")
	await _prepare_rabbit()


func _jump() -> void:
	if GameManager.current_control != "rabbit":
		await _control_to("rabbit")
	if race.mount.state != "RIDING" or not race.turtle.is_at_surface():
		_log("WARN  jump skipped mount=%s y=%.0f" % [
			race.mount.state, race.turtle.position.y])
		return
	Input.action_press("up")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("up")


func _control_to(target: String) -> void:
	var start: float = GameManager.race_time
	while GameManager.race_time - start < 5.0:
		if GameManager.showtime_active:
			await get_tree().physics_frame
			continue
		if GameManager.current_control == target:
			return
		GameManager.toggle_control()
		await get_tree().physics_frame
	_log("WARN  control_to %s timed out (control=%s)" % [
		target, GameManager.current_control])


func _dive_to(depth: float) -> void:
	var start: float = GameManager.race_time
	while GameManager.race_time - start < 3.0 and race.turtle.position.y < depth:
		await get_tree().physics_frame
	Input.action_release("down")
	if race.turtle.position.y < depth - 5.0:
		_log("WARN  dive only reached y=%.0f (target %.0f)" % [
			race.turtle.position.y, depth])


func _surface() -> void:
	# 已经在水面就不要按上：残留的 press/release 会让兔子在白跑时误起跳。
	if race.turtle.position.y <= 305.0:
		return
	Input.action_press("up")
	var start: float = GameManager.race_time
	while GameManager.race_time - start < 4.0 and race.turtle.position.y > 305.0:
		await get_tree().physics_frame
	Input.action_release("up")


func _recover_wall() -> void:
	# 触礁修复后仍在墙里；冷却约 2 s 用完前必须下潜穿墙。
	_log("t=%5.2f  WALL begin control=%s x=%.0f y=%.0f grace=%.1f" % [
		GameManager.race_time, GameManager.current_control,
		race.turtle.position.x, race.turtle.position.y, race.turtle_grace])
	await _prepare_turtle()
	_log("t=%5.2f  WALL prepared control=%s x=%.0f y=%.0f grace=%.1f" % [
		GameManager.race_time, GameManager.current_control,
		race.turtle.position.x, race.turtle.position.y, race.turtle_grace])
	Input.action_press("down")
	await _dive_to(345.0)
	_log("t=%5.2f  WALL dived control=%s x=%.0f y=%.0f" % [
		GameManager.race_time, GameManager.current_control,
		race.turtle.position.x, race.turtle.position.y])
	await _until_x(4860)
	await _surface()
	await _control_to("rabbit")


func _wrap_lap() -> void:
	_log("t=%5.2f  LAP %d done x=%.0f -> back to start" % [
		GameManager.race_time, lap, race.turtle.position.x])
	race.turtle.position = Vector2(START_X, 300.0)
	laps_completed += 1
	lap += 1
	await get_tree().physics_frame
	await get_tree().physics_frame


func _release_all() -> void:
	for action in ["up", "down", "left", "right", "boost", "shift"]:
		Input.action_release(action)


func _write_log() -> void:
	var path := ProjectSettings.globalize_path(LOG_PATH)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("  WARN cannot write ", path)
		return
	for line in lines:
		file.store_line(line)
	file.close()
	print("  log -> ", path)


func _log(text: String) -> void:
	lines.append(text)
	print("  " + text)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok  " + message)
	else:
		failures.append(message)
		print("  FAIL " + message)
