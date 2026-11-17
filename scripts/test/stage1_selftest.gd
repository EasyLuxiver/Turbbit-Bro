extends Node
## 阶段 1 自检：把核心玩法逐条跑一遍。
## 阶段 2 起判定窗口改为三段（提示/开始/惩罚），本回归测试已对齐新数值。
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT res://scenes/stage1_selftest.tscn

const Tuning = preload("res://scripts/systems/tuning.gd")
const LevelDataScript = preload("res://scripts/systems/level_data.gd")

var is_runner := false
var failures: Array[String] = []
var _best_existed := false
var _best_text := ""


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage1Runner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	# 终点测试用瞬移，finalize_run 会把它当个人纪录写盘；测试不能污染玩家纪录。
	_backup_best()
	for action in ["shift", "boost", "up", "down", "left", "right", "pause", "restart", "confirm"]:
		_check(InputMap.has_action(action), "action exists: " + action)

	GameManager.start_race()
	await _frames(3)
	var race := get_tree().current_scene
	_check(race.scene_file_path.ends_with("race.tscn"), "start -> race scene")
	_check(GameManager.state == GameManager.GameState.RUNNING, "state RUNNING")
	_check(GameManager.current_control == "rabbit", "initial control is rabbit")
	_check(not GameManager.has_shifted, "no shift yet")
	_check(is_equal_approx(GameManager.oxygen, Tuning.OXYGEN_MAX), "oxygen starts full")
	_check(race.mount.state == "RIDING", "rabbit mounted at start")
	print("  boot   -> control=%s mount=%s turtle=%.1f" % [
		GameManager.current_control, race.mount.state, race.turtle.speed])

	race.test_disable_hazards = true

	# 1. 乌龟在第一次 SHIFT 前自动巡航，兔子不被神游拖累。
	var x0: float = race.turtle.position.x
	await get_tree().create_timer(0.4).timeout
	_check(race.turtle.position.x > x0 + 60.0, "turtle auto-cruises before first SHIFT")
	_check(race.turtle.state == "CRUISING", "turtle CRUISING before first SHIFT")
	_check(race.rabbit.slide <= 0.01, "rabbit does not slide before first SHIFT")
	_check(race.rabbit.state == "RIDING", "rabbit RIDING before first SHIFT")

	# 2. SHIFT 给乌龟：兔子待命。阶段 4 移除了“失去控制就自然滑落”，
	#    失衡只由碰撞累加，待命既不滑也不积失衡。
	var speed_before_shift: float = race.turtle.speed
	await _shift()
	await _frames(1)
	_check(GameManager.current_control == "turtle", "SHIFT -> turtle control")
	_check(GameManager.shift_count == 1, "shift_count increments")
	_check(absf(race.turtle.speed - speed_before_shift) < 10.0,
		"SHIFT does not reset turtle speed (%.1f -> %.1f)" % [
			speed_before_shift, race.turtle.speed])
	await get_tree().create_timer(2.4).timeout
	_check(race.rabbit.slide <= 0.01, "standby rabbit holds on (slide %.2f)" % race.rabbit.slide)
	_check(race.rabbit.daze_time < 0.01,
		"standby rabbit accumulates no imbalance (%.2f)" % race.rabbit.daze_time)
	_check(race.rabbit.state == "RIDING", "standby rabbit stays RIDING (%s)" % race.rabbit.state)
	_check(race.turtle.speed > 200.0, "turtle keeps cruising when controlled")

	# 3. SHIFT 回兔子：龟壳失去控制也不再下沉；切换不瞬移、不瞬清零。
	var slide_before: float = race.rabbit.slide
	await _shift()
	await get_tree().create_timer(0.4).timeout
	_check(GameManager.current_control == "rabbit", "SHIFT -> rabbit control")
	_check(absf(race.rabbit.slide - slide_before) < 0.01,
		"SHIFT does not instantly reset slide (%.2f -> %.2f)" % [
			slide_before, race.rabbit.slide])
	_check(race.turtle.state == "CRUISING",
		"uncontrolled turtle keeps CRUISING (%s)" % race.turtle.state)
	_check(race.turtle.speed > 200.0,
		"uncontrolled shell keeps its speed (%.1f)" % race.turtle.speed)
	_check(absf(race.turtle.position.y - Tuning.NEUTRAL_DEPTH) < 1.0,
		"uncontrolled shell holds cruise depth (%.2f)" % race.turtle.position.y)
	await get_tree().create_timer(1.4).timeout
	_check(absf(race.rabbit.slide - slide_before) < 0.01,
		"controlled rabbit does not gain or lose slide on standby (%.2f -> %.2f)" % [
			slide_before, race.rabbit.slide])
	_check(race.turtle.state == "CRUISING"
		and absf(race.turtle.position.y - Tuning.NEUTRAL_DEPTH) < 1.0,
		"shell still at cruise depth 1.8 s later (%.2f)" % race.turtle.position.y)

	# 4. 长时间待命不再触发滑落事故（旧的“神游 9.5 s 必掉”模型已移除）。
	var accidents_before: int = GameManager.accident_count
	await _shift()
	await get_tree().create_timer(9.8).timeout
	_check(GameManager.accident_state == "NONE",
		"10 s of standby causes no accident (%s)" % GameManager.accident_state)
	_check(GameManager.accident_count == accidents_before,
		"standby does not change accident_count")
	_check(race.mount.state == "RIDING", "rabbit still mounted after 10 s standby")
	print("  standby-> state=%s mount=%s slide=%.2f" % [
		GameManager.accident_state, race.mount.state, race.rabbit.slide])

	# 5. 跳跃 -> 空中 SHIFT 给龟 -> 下潜 -> 上浮 -> 接住兔子。
	var pickups_before: int = GameManager.pickup_count
	await _shift()
	await _physics_frames(2)
	_check(GameManager.current_control == "rabbit", "back on rabbit before jump")
	_send_key(KEY_UP, true)
	# CORE-FEEL-08 P0-A：前面刚待命 9.8 s，兔子已在“要惹麻烦”档——起跳会晚半拍
	# （<= 0.35 s）。这里等它真的起跳，并把实测延迟记下来：延迟是设计，丢键才是 bug。
	var jump_wait := 0.0
	while race.mount.state != "AIRBORNE" and jump_wait < 0.45:
		await get_tree().create_timer(1.0 / 60.0).timeout
		jump_wait += 1.0 / 60.0
	_send_key(KEY_UP, false)
	print("  jump   -> delayed %.3f s after 10 s standby" % jump_wait)
	_check(race.mount.state == "AIRBORNE", "jump -> mount AIRBORNE")
	_check(race.rabbit.is_airborne(), "jump -> rabbit airborne")
	_check(jump_wait <= 0.35,
		"drift delays the jump but does not drop it (%.3f s)" % jump_wait)

	await get_tree().create_timer(0.2).timeout
	await _shift()
	_check(GameManager.current_control == "turtle", "mid-air SHIFT -> turtle")
	_check(race.rabbit.is_airborne(), "rabbit still airborne after mid-air SHIFT")

	# 冲浪板模型没有手动下潜：切到乌龟后壳自动浮回巡航水深，
	# 接人判定看的是“壳在巡航深度附近”，不再靠按键控深。
	await get_tree().create_timer(0.35).timeout
	_check(absf(race.turtle.position.y - Tuning.NEUTRAL_DEPTH) < 12.0,
		"turtle floats back to cruise depth (%.1f)" % race.turtle.position.y)
	_check(race.turtle.is_at_surface(), "turtle is at pickup depth")

	var reacquired := false
	for i in 90:
		await get_tree().physics_frame
		if GameManager.pickup_count > pickups_before and race.mount.state == "RIDING":
			reacquired = true
			break
		if GameManager.accident_state != "NONE":
			break
	_check(reacquired, "mid-air shift + auto float -> pickup (%d)" % GameManager.pickup_count)
	print("  pickup -> count=%d mount=%s accident=%s" % [
		GameManager.pickup_count, race.mount.state, GameManager.accident_state])

	# 6. 跳跃后正常落回龟壳也能接住。
	await _reset_race(true)
	race = get_tree().current_scene
	pickups_before = GameManager.pickup_count
	_send_key(KEY_UP, true)
	await _physics_frames(2)
	_send_key(KEY_UP, false)
	# 空中移动：按左，水平速度应被主动改变。
	_send_key(KEY_LEFT, true)
	await get_tree().create_timer(0.15).timeout
	_send_key(KEY_LEFT, false)
	_check(race.rabbit.velocity.x < 200.0,
		"rabbit air movement changes horizontal velocity (%.1f)" % race.rabbit.velocity.x)
	var saw_window := false
	var picked := false
	for i in 120:
		await get_tree().physics_frame
		if GameManager.pickup_window:
			saw_window = true
		if GameManager.pickup_count > pickups_before and race.mount.state == "RIDING":
			picked = true
			break
		if GameManager.accident_state != "NONE":
			break
	_check(picked, "plain jump lands back on turtle (%d)" % GameManager.pickup_count)
	_check(saw_window, "pickup window shown during landing")
	print("  land   -> picked=%s window=%s accident=%s" % [
		picked, saw_window, GameManager.accident_state])

	# 6b. 主动下潜：按住 ↓ 到 DIVE_DEPTH，松手回到巡航；不会掉到危险深度。
	#     （阶段 4 起“失去控制就自动下沉”已移除，深度只由 ↓ 决定。）
	await _reset_race(true)
	race = get_tree().current_scene
	await _shift()
	_send_key(KEY_DOWN, true)
	await get_tree().create_timer(1.0).timeout
	_check(race.turtle.position.y > Tuning.NEUTRAL_DEPTH + Tuning.DIVE_DEPTH * 0.85,
		"DOWN reaches dive depth (%.0f)" % race.turtle.position.y)
	_check(GameManager.accident_state == "NONE", "a normal dive is not an accident")
	_send_key(KEY_DOWN, false)
	await get_tree().create_timer(1.6).timeout
	_check(race.turtle.position.y <= Tuning.NEUTRAL_DEPTH + 2.0,
		"released dive returns to cruise depth (%.1f)" % race.turtle.position.y)
	print("  dive   -> y=%.1f accident=%s" % [
		race.turtle.position.y, GameManager.accident_state])

	# 7. 障碍：碰撞触发、正确操作可避开（按当前 55 组数据取位置）。
	var rock_x := _group_x("rock1")
	await _reset_race(false)
	race = get_tree().current_scene
	race.turtle.position = Vector2(rock_x - 40.0, Tuning.NEUTRAL_DEPTH)
	await get_tree().create_timer(0.5).timeout
	_check(GameManager.accident_state == "RABBIT_STUN",
		"surface rock -> RABBIT_STUN (%s)" % GameManager.accident_state)

	await _reset_race(false)
	race = get_tree().current_scene
	race.turtle.position = Vector2(rock_x - 90.0, Tuning.NEUTRAL_DEPTH)
	await _physics_frames(2)
	_send_key(KEY_UP, true)
	await get_tree().create_timer(0.18).timeout
	_send_key(KEY_UP, false)
	await get_tree().create_timer(0.6).timeout
	_check(GameManager.accident_state == "NONE", "jump clears surface rock")

	# 低矮横梁：站着撞；趴下过。
	var beam_x := _group_x("beam1")
	await _reset_race(false)
	race = get_tree().current_scene
	race.turtle.position = Vector2(beam_x - 40.0, Tuning.NEUTRAL_DEPTH)
	await get_tree().create_timer(0.5).timeout
	_check(GameManager.accident_state == "RABBIT_STUN", "standing under beam -> RABBIT_STUN")

	await _reset_race(false)
	race = get_tree().current_scene
	race.turtle.position = Vector2(beam_x - 70.0, Tuning.NEUTRAL_DEPTH)
	_send_key(KEY_DOWN, true)
	await get_tree().create_timer(0.5).timeout
	_check(GameManager.accident_state == "NONE", "crouch clears low beam")
	_send_key(KEY_DOWN, false)
	print("  beam   -> %s" % GameManager.accident_state)

	# 水下通道：巡航龟壳撞上沿；乌龟 ↓ 潜过去。
	var gate_x := _group_x("gate1")
	await _reset_race(false)
	race = get_tree().current_scene
	race.turtle.position = Vector2(gate_x - 40.0, Tuning.NEUTRAL_DEPTH)
	await get_tree().create_timer(0.5).timeout
	# DIVE_GATE 只加失衡、不直接判事故：一次撞拱是可见失衡（+4.4），不是瞬间事故。
	_check(race.hit_groups.has("gate1"), "cruising shell is caught by the reef arch")
	_check(race.turtle.daze_time > 2.0,
		"reef arch hit leaves visible imbalance (%.1f)" % race.turtle.daze_time)
	_check(GameManager.accident_state == "NONE",
		"one arch hit is imbalance, not an instant accident")

	await _reset_race(false)
	race = get_tree().current_scene
	race.turtle.position = Vector2(gate_x - 220.0, Tuning.NEUTRAL_DEPTH)
	await _shift()
	_send_key(KEY_DOWN, true)
	await get_tree().create_timer(1.2).timeout
	_send_key(KEY_DOWN, false)
	_check(GameManager.accident_state == "NONE", "diving turtle clears the reef arch")
	print("  gate   -> %s" % GameManager.accident_state)

	# 8. 重开重置。
	GameManager.start_race()
	await _frames(3)
	_check(GameManager.shift_count == 0, "restart resets shift_count")
	_check(GameManager.accident_count == 0, "restart resets accident_count")
	_check(GameManager.pickup_count == 0, "restart resets pickup_count")
	_check(GameManager.current_control == "rabbit", "restart resets control")
	_check(is_equal_approx(GameManager.oxygen, Tuning.OXYGEN_MAX), "restart resets oxygen")
	_check(GameManager.race_time < 0.3, "restart resets race time")

	# 9. 终点 -> 结算 -> 菜单。阶段 3 起终点有 1.6 秒的 FINISH 演出。
	race = get_tree().current_scene
	race.turtle.position.x = LevelDataScript.WORLD_END + 1.0
	var wait_start := Time.get_ticks_msec()
	while not get_tree().current_scene.scene_file_path.ends_with("result.tscn") \
			and Time.get_ticks_msec() - wait_start < 5000:
		await get_tree().physics_frame
	_check(get_tree().current_scene.scene_file_path.ends_with("result.tscn"),
		"finish -> result scene")
	GameManager.go_to_menu()
	await _frames(3)
	_check(get_tree().current_scene.scene_file_path.ends_with("menu.tscn"),
		"result -> menu scene")

	# 10. 菜单 Enter 真的能进比赛（玩家实际入口）。
	_send_key(KEY_ENTER, true)
	await _frames(2)
	_send_key(KEY_ENTER, false)
	await _frames(3)
	_check(get_tree().current_scene.scene_file_path.ends_with("race.tscn"),
		"menu ENTER -> race scene")

	_restore_best()
	if failures.is_empty():
		print("STAGE1 SELFTEST: PASS")
		get_tree().quit(0)
	else:
		print("STAGE1 SELFTEST: FAIL")
		for item in failures:
			print("  - " + item)
		get_tree().quit(1)


func _backup_best() -> void:
	_best_existed = FileAccess.file_exists(GameManager.BEST_PATH)
	if _best_existed:
		_best_text = FileAccess.get_file_as_string(GameManager.BEST_PATH)


func _restore_best() -> void:
	if _best_existed:
		var file := FileAccess.open(GameManager.BEST_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(_best_text)
			file.close()
	elif FileAccess.file_exists(GameManager.BEST_PATH):
		DirAccess.remove_absolute(GameManager.best_path_absolute())


func _reset_race(disable_hazards: bool) -> void:
	GameManager.start_race()
	await _frames(3)
	var race := get_tree().current_scene
	race.test_disable_hazards = disable_hazards


func _group_x(id: String) -> float:
	for g in LevelDataScript.groups():
		if g["group"] == id:
			return LevelDataScript.group_start(g)
	return 0.0


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _shift() -> void:
	_send_key(KEY_SHIFT, true)
	await get_tree().process_frame
	_send_key(KEY_SHIFT, false)


func _send_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	# 同时写 keycode：GUI 按钮的 ui_accept 走 keycode，纯物理码在菜单里不触发。
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok  " + message)
	else:
		failures.append(message)
		print("  FAIL " + message)
