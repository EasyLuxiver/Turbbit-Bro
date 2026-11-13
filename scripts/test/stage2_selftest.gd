extends Node
## 阶段 2 自检：氧气、事故分级、六类障碍（主赛道抽查）、连击与 Showtime。
##
## 阶段 4 起“待命时间”不再让任何角色变糟：兔子滑落 / 乌龟下沉都是
## 事件驱动的失衡（碰撞、错误着陆）。
## Phase G 后 daze_time 只做短硬直/姿态动画，封顶 DAZE_CAP；
## 第 2、3 节改为验证“daze 永远不定罪、每次碰撞记 1 格 BRO METER”。
## 六类障碍的完整正反证在 stage4_proto（原型段）里；这里只在主赛道
## 抽查 LOW_BIRD / SHARK / FLOATING_LOG，确认主流程接入没有退化。
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT res://scenes/stage2_selftest.tscn

const Tuning = preload("res://scripts/systems/tuning.gd")
const LevelDataScript = preload("res://scripts/systems/level_data.gd")

var is_runner := false
var failures: Array[String] = []
var race


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage2Runner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	# 旧断言按英文写；直接改内存语言，不写 settings.json。
	Locale.language = "en"
	for action in ["shift", "boost", "up", "down", "left", "right", "pause", "restart", "confirm"]:
		_check(InputMap.has_action(action), "action exists: " + action)

	# 1. 启动与常驻 HUD。
	await _reset(true)
	_check(GameManager.state == GameManager.GameState.RUNNING, "state RUNNING")
	_check(GameManager.current_control == "rabbit", "initial control rabbit")
	_check(is_equal_approx(GameManager.oxygen, Tuning.OXYGEN_MAX), "oxygen starts at max")
	_check(race.get_node_or_null("HUDLayer/HUD") != null, "HUD lives in main race scene")
	_check(race.hud.control_label.text.contains("CONTROL"), "HUD control field")
	_check(race.hud.oxygen_label.text.contains("AIR"), "HUD oxygen field")
	_check(race.hud.bond_label.text.contains("BRO PASS"), "HUD brotherhood field")
	_check(race.hud.time_label.text.contains(":"), "HUD time field")
	_check(race._debug_overlay != null, "F1 debug overlay exists")
	print("  hud    -> %s" % race.hud.control_label.text.replace("\n", " | "))

	# 2. 兔子失衡只做姿态：待命不累积；撞击把姿态推差，
	#    但封顶在 DAZE_CAP，绝不会自己变成 RABBIT_SLIP。
	#    持续惩罚只记在 BRO METER，由第 3 节验证。
	await _shift()
	await _wait(1.2)
	_check(race.rabbit.daze_time < 0.01,
		"standby rabbit accumulates no imbalance (%.2f)" % race.rabbit.daze_time)
	race.rabbit.add_imbalance(Tuning.RABBIT_HIT_IMBALANCE)
	await _physics_frames(1)
	_check(race.rabbit.state == "SLIDING", "1 hit -> SLIDING (%s)" % race.rabbit.state)
	_check(race.rabbit.slide > 0.005, "slide becomes visible (%.2f)" % race.rabbit.slide)
	race.rabbit.add_imbalance(Tuning.RABBIT_HIT_IMBALANCE)
	race.rabbit.add_imbalance(Tuning.RABBIT_HIT_IMBALANCE)
	await _physics_frames(1)
	_check(race.rabbit.daze_time <= Tuning.DAZE_CAP + 0.01,
		"3 hits are capped at DAZE_CAP (%.2f / %.2f)" % [
			race.rabbit.daze_time, Tuning.DAZE_CAP])
	_check(not race.rabbit.is_falling(),
		"3 hits never reach the fall line (%.2f)" % race.rabbit.daze_time)
	await _wait(0.6)
	_check(GameManager.accident_state == "NONE",
		"daze alone triggers no RABBIT_SLIP (%s)" % GameManager.accident_state)
	_check(race.mount.state == "RIDING", "rabbit stays on the shell")
	print("  daze   -> %.2f cap=%.2f accident=%s" % [
		race.rabbit.daze_time, Tuning.DAZE_CAP, GameManager.accident_state])

	# 3. 乌龟浪击：每一下当场记 1 格 BRO METER（唯一的持续事故系统），
	#    daze 只做短硬直/下沉动画；第三格才是联合事故，不再“攒到临界补翻肚皮”。
	await _reset(true)
	GameManager.total_score = 1000
	var meter0: int = GameManager.bro_meter
	race._turtle_contact("test")
	await _physics_frames(1)
	_check(GameManager.accident_state == "NONE",
		"one shell hit is a mistake, not an accident (%s)" % GameManager.accident_state)
	_check(GameManager.bro_meter == meter0 + 1,
		"one shell hit fills exactly one slot (%d)" % GameManager.bro_meter)
	_check(GameManager.total_score == 900,
		"one shell hit costs exactly 100 (%d)" % GameManager.total_score)
	_check(race.turtle.daze_time > 2.0,
		"shell hit leaves visible imbalance (%.1f)" % race.turtle.daze_time)
	_check(race.turtle.dunk_timer > 0.0, "shell hit dunks the group briefly")
	race._turtle_contact("test")
	race._turtle_contact("test")
	await _physics_frames(1)
	_check(race.turtle.daze_time <= Tuning.DAZE_CAP + 0.01,
		"three shell hits stay below the old danger line (%.2f)" % race.turtle.daze_time)
	_check(GameManager.bro_meter == 3 and GameManager.bro_joint_pending,
		"third shell hit fills the meter and arms the joint show (%d/%s)" % [
			GameManager.bro_meter, str(GameManager.bro_joint_pending)])
	_check(GameManager.accident_state == "BRO_BREAK",
		"third shell hit starts the joint accident (%s)" % GameManager.accident_state)
	# 联合演出 1.4 s；多等 0.6 s 确认结束、清格、复位。
	await _wait(2.0)
	_check(GameManager.accident_state == "NONE",
		"joint show ends and the run continues (%s)" % GameManager.accident_state)
	_check(GameManager.bro_meter == 0,
		"joint show clears the meter (%d)" % GameManager.bro_meter)
	_check(absf(race.turtle.position.y - Tuning.NEUTRAL_DEPTH) < 2.0,
		"joint show restores cruise depth (%.1f)" % race.turtle.position.y)
	print("  hit    -> accident=%s meter=%d y=%.1f" % [
		GameManager.accident_state, GameManager.bro_meter, race.turtle.position.y])

	# 4. 氧气：水面恢复 / 水下消耗 / 空中不消耗 / 切换不回氧 / 耗尽紧急上浮。
	#    阶段 4 起下潜是主动动作：切到乌龟按住 ↓。
	await _reset(true)
	GameManager.oxygen = 5.0
	await _wait(0.5)
	_check(GameManager.oxygen > 5.0, "oxygen recovers at surface (%.2f)" % GameManager.oxygen)

	await _reset(true)
	await _dive_until(Tuning.NEUTRAL_DEPTH + Tuning.OXYGEN_DEPTH_MARGIN + 6.0)
	GameManager.oxygen = 4.0
	await _wait(0.6)
	_check(race.turtle.position.y > Tuning.NEUTRAL_DEPTH + Tuning.OXYGEN_DEPTH_MARGIN,
		"turtle underwater for oxygen test (%.1f)" % race.turtle.position.y)
	_check(GameManager.oxygen < 3.7, "oxygen drains underwater (%.2f)" % GameManager.oxygen)
	_send_key(KEY_DOWN, false)

	await _reset(true)
	_send_key(KEY_UP, true)
	await _physics_frames(2)
	_send_key(KEY_UP, false)
	_check(race.mount.state == "AIRBORNE", "jump leaves the shell for the air test")
	GameManager.oxygen = 4.0
	await _wait(0.3)
	_check(absf(GameManager.oxygen - 4.0) < 0.05,
		"airborne does not drain oxygen (%.2f)" % GameManager.oxygen)

	await _reset(true)
	await _dive_until(Tuning.NEUTRAL_DEPTH + Tuning.OXYGEN_DEPTH_MARGIN + 6.0)
	GameManager.oxygen = 4.0
	await _shift()
	await _physics_frames(2)
	_check(GameManager.oxygen <= 4.05, "switching control does not refill oxygen")
	_send_key(KEY_DOWN, false)
	print("  oxygen -> %.2f (%s)" % [GameManager.oxygen, GameManager.oxygen_phase])

	await _reset(true)
	await _dive_until(Tuning.NEUTRAL_DEPTH + Tuning.OXYGEN_DEPTH_MARGIN + 6.0)
	GameManager.oxygen = 0.05
	var out_frames := 0
	while GameManager.accident_state == "NONE" and out_frames < 30:
		await get_tree().physics_frame
		out_frames += 1
	_send_key(KEY_DOWN, false)
	_check(GameManager.accident_state == "OXYGEN_OUT", "oxygen empty -> emergency")
	await _wait(0.8)
	_check(GameManager.accident_state == "NONE", "emergency recovers")
	_check(race.turtle.position.y <= Tuning.NEUTRAL_DEPTH + 2.0, "emergency surfaces turtle")
	_check(GameManager.oxygen >= 4.9, "emergency refills to safe level (%.1f)" % GameManager.oxygen)
	print("  air out-> y=%.1f oxygen=%.1f" % [race.turtle.position.y, GameManager.oxygen])

	# 5. 事故分级：普通碰撞是硬直，不强制换人、不落水。
	await _reset(false)
	race.turtle.position = Vector2(_group_x("rock1") - 40.0, Tuning.NEUTRAL_DEPTH)
	# 兔子身体比龟心靠前 13 px、岩石在 2500：实测受击约在 0.12 s，硬直 0.8 s
	# 到 0.92 s 结束；原来等 1.0 s 正好落在窗口外，采样点前移到 0.5 s。
	await _wait(0.5)
	_check(GameManager.accident_state == "RABBIT_STUN", "rock contact -> RABBIT_STUN")
	_check(race.rabbit_stun > 0.0, "stun timer active")
	_check(GameManager.current_control == "rabbit",
		"stun does not force a control swap (%s)" % GameManager.current_control)
	_check(race.mount.state == "RIDING", "stun keeps rabbit on shell")
	await _wait(0.9)
	_check(GameManager.accident_state == "NONE", "stun clears without rescue")
	print("  stun   -> %.1f s, mount=%s" % [Tuning.STUN_TIME, race.mount.state])

	# 6. 主赛道抽查三类（完整六类正反证见 stage4_proto）。
	#    LOW_BIRD：站着撞，趴下过。
	var bird_x := _group_x("bird1")
	await _reset(false)
	race.turtle.position = Vector2(bird_x - 40.0, Tuning.NEUTRAL_DEPTH)
	await _wait(0.5)
	_check(GameManager.accident_state == "RABBIT_STUN", "standing under low bird -> stun")

	await _reset(false)
	race.turtle.position = Vector2(bird_x - 70.0, Tuning.NEUTRAL_DEPTH)
	_send_key(KEY_DOWN, true)
	await _wait(0.5)
	_check(GameManager.accident_state == "NONE", "crouch clears low bird")
	_send_key(KEY_DOWN, false)
	print("  bird   -> %s" % GameManager.accident_state)

	#    SHARK：REBUILD-06 P3 起是水下伏击——先潜伏，靠近 260 px 才预警/上冲。
	#    撞鲨要等它冲上来（预警 0.55 s + 0.12 s 起跳），不再是“贴上去立刻撞”。
	var shark_x := _group_x("shark1")
	await _reset(false)
	race.turtle.position = Vector2(shark_x - 40.0, Tuning.NEUTRAL_DEPTH)
	var shark_wait := 0.0
	while not race.hit_groups.has("shark1") and shark_wait < 2.5:
		await _wait(0.05)
		shark_wait += 0.05
	_check(race.hit_groups.has("shark1") and race.turtle.daze_time > 2.0,
		"cruising shell hits the shark after its lunge (hit=%s daze %.1f)" % [
			str(race.hit_groups.has("shark1")), race.turtle.daze_time])
	_check(GameManager.accident_state == "NONE", "one shark hit is imbalance")

	await _reset(false)
	race.turtle.position = Vector2(shark_x - 140.0, Tuning.NEUTRAL_DEPTH)
	await _shift()
	# 等到预警出现再起跳：这才是玩家在正式赛道上读到的时机。
	var warn_wait := 0.0
	while warn_wait < 1.0:
		var st: Dictionary = race.hazard_motion_state(_group("shark1"))
		if String(st.get("phase", "")) == "TELEGRAPH":
			break
		await _wait(0.05)
		warn_wait += 0.05
	await _tap(KEY_UP)
	await _wait(1.4)
	_check(not race.hit_groups.has("shark1"), "turtle leap clears the shark")
	_check(race.rabbit.state == "RIDING" or race.rabbit.is_airborne() == false,
		"rabbit is carried by the leap, not asked to jump")
	await _wait(0.8)
	_check(GameManager.accident_state == "NONE", "leap causes no accident")
	print("  shark  -> %s (telegraph wait %.2f s)" % [
		GameManager.accident_state, warn_wait])

	#    FLOATING_LOG：只跳不潜，乌龟撞下沿（组合必须两条路都走）。
	# REBUILD-05 B2 起两个角色各记各的：这条用例要的是“兔子跳过去、壳撞下沿”。
	# REBUILD-06 P0 起壳对浮木是实心的：不按 ↓ 不再“撞一下继续穿过去”，
	# 壳被顶在浮木入口；兔子按起跳速度（壳速 +15）已经飞出去，落点在水里。
	# 所以这里的真实结果从“壳穿过去、事故 NONE”变成“壳被顶住 + 兔子落水”，
	# 落水走的是救援流程（可救回），不是额外补一笔联合判罚——断言按物理真相改，
	# 并明确要求不能同时出现联合事故演出。
	await _reset(false)
	race.turtle.position = Vector2(_group_x("log1") - 160.0, Tuning.NEUTRAL_DEPTH)
	await _tap(KEY_UP)
	await _wait(1.4)
	_check(race.hit_groups.has("log1"),
		"jumping alone leaves the shell in the log's lower route")
	_check(GameManager.accident_state == "RABBIT_WATER",
		"shell is blocked and the jumping rabbit ends up in the water")
	_check(not GameManager.bro_joint_pending,
		"one log mistake stays a rescue flow, not a joint-accident show")
	print("  log    -> hit=%s accident=%s joint_pending=%s" % [
		race.hit_groups.has("log1"), GameManager.accident_state,
		GameManager.bro_joint_pending])

	# 7. Phase O 起加速带不再直接提速，而是在带内放一份食物；游到食物位置
	# 自动吃下 → 当前区速 ×1.15，过障碍后收尾回落。旧断言（带内 >340）
	# 测的是被食物系统替换掉的机制，已按现设计改写。
	await _reset(true)
	await _shift()
	var snack_x := 2600.0
	for enc in LevelDataScript.snack_encounters(LevelDataScript.boost_lanes()):
		if float(enc["x"]) > 2400.0:
			snack_x = float(enc["x"])
			break
	race.turtle.position = Vector2(snack_x, Tuning.NEUTRAL_DEPTH)
	await _wait(1.0)
	_check(race.snack_last_eaten != "" and race.snack_boost_active()
			and race.turtle.speed > 240.0,
		"snack in boost lane accelerates automatically (%.0f, %s)" % [
			race.turtle.speed, race.snack_last_eaten])
	# 越过加速收尾点，但不能停在另一份食物的判定圈里（那样会再吃一次）。
	var end_x: float = race.snack_boost_until_x + 200.0
	for enc in race._snack_list():
		var ex := float(enc["x"])
		if absf(ex - end_x) < 90.0:
			end_x = ex + 90.0
	race.turtle.position = Vector2(end_x, Tuning.NEUTRAL_DEPTH)
	await _wait(1.0)
	_check(race.turtle.speed < 300.0,
		"leaving the lane sheds the boost (%.0f)" % race.turtle.speed)
	print("  boost  -> speed=%.0f" % race.turtle.speed)

	# 8. 接人容错。
	await _reset(true)
	race.mount.mark_airborne()
	var m: Vector2 = race.turtle.get_mount_point()
	_check(race.mount.can_pickup(m + Vector2(110, 20), 10.0, m, true),
		"pickup tolerance 110 px")
	_check(not race.mount.can_pickup(m + Vector2(130, 20), 10.0, m, true),
		"pickup rejects 130 px")
	_check(not race.mount.can_pickup(m + Vector2(30, 20), -10.0, m, true),
		"pickup rejects rising rabbit")
	race.mount.mark_riding()

	# 9. 连击与 Showtime：只算干净通过，3 次触发；不抢控制权；可中断。
	await _reset(true)
	await _pass_group("beam1")
	_check(race.combo == 1, "clean pass 1 -> combo 1")
	await _pass_group("beam2")
	_check(race.combo == 2, "clean pass 2 -> combo 2")
	await _pass_group("beam3")
	_check(race.showtime_active, "3 clean passes -> Showtime")
	_check(GameManager.current_control == "rabbit",
		"Showtime does not steal control (%s)" % GameManager.current_control)
	await _physics_frames(2)
	_check(race.rabbit.state == "SHOWTIME", "rabbit performs automatically")
	print("  show   -> active=%s combo=%d" % [race.showtime_active, race.combo])

	await _shift()
	await _physics_frames(2)
	_check(not race.showtime_active, "SHIFT aborts Showtime")
	_check(GameManager.current_control == "rabbit",
		"abort keeps control where it was (%s)" % GameManager.current_control)
	# 中断把失衡直接推到 RELAXED 线（跳过提示期）；兔子若正受控，
	# 阶段 4 的恢复规则会在 0.5 s 后把它收回——中断只是取消奖励，不是惩罚。
	_check(race.rabbit.daze_time >= Tuning.RELAX_TIME - 0.01,
		"abort skips the warning window (daze %.2f)" % race.rabbit.daze_time)

	await _reset(true)
	await _pass_group("beam1")
	await _pass_group("beam2")
	await _pass_group("beam3")
	_check(race.showtime_active, "Showtime starts for completion test")
	await _wait(Tuning.SHOWTIME_TIME + 0.3)
	_check(not race.showtime_active, "Showtime completes")
	_check(GameManager.showtime_count == 1, "showtime_count increments")
	_check(race.combo == 0, "Showtime consumes the combo")
	print("  show   -> count=%d oxygen=%.1f" % [GameManager.showtime_count, GameManager.oxygen])

	# 表演中碰撞：演出结束、当场判硬直、连击清零。
	await _reset(false)
	race.start_showtime()
	_check(race.showtime_active, "manual Showtime starts for collision test")
	race.turtle.position = Vector2(_group_x("rock1") - 40.0, Tuning.NEUTRAL_DEPTH)
	# 40 px + 壳半宽 48 按 Z1 基础速度要 0.5 s 以上才够到岩石；原来的 0.5 s 是
	# 卡在边界上的，headless 帧率一抖就随机红。给到 1.0 s 只放宽等待，不放宽断言。
	await _wait(1.0)
	_check(not race.showtime_active, "collision during Showtime ends performance")
	_check(GameManager.accident_state == "RABBIT_STUN",
		"Showtime collision -> stun (%s)" % GameManager.accident_state)
	_check(race.combo == 0, "accident clears combo")
	print("  show   -> collision=%s" % GameManager.accident_state)

	# 10. 重开重置。
	GameManager.start_race()
	await _frames(3)
	race = get_tree().current_scene
	_check(GameManager.current_control == "rabbit", "restart resets control")
	_check(is_equal_approx(GameManager.oxygen, Tuning.OXYGEN_MAX), "restart resets oxygen")
	_check(GameManager.combo == 0 and GameManager.showtime_count == 0,
		"restart resets combo / showtime count")
	_check(GameManager.shift_count == 0 and GameManager.accident_count == 0,
		"restart resets counters")
	_check(GameManager.race_time < 0.3, "restart resets race time")

	if failures.is_empty():
		print("STAGE2 SELFTEST: PASS")
		get_tree().quit(0)
	else:
		print("STAGE2 SELFTEST: FAIL")
		for item in failures:
			print("  - " + item)
		get_tree().quit(1)


func _reset(disable_hazards: bool) -> void:
	GameManager.start_race()
	await _frames(3)
	race = get_tree().current_scene
	race.test_disable_hazards = disable_hazards


## 主动下潜直到目标深度：切到乌龟，按住 ↓。调用方负责松手。
func _dive_until(target_y: float) -> void:
	if GameManager.current_control != "turtle":
		await _shift()
	_send_key(KEY_DOWN, true)
	var frames := 0
	while race.turtle.position.y < target_y and frames < 240 \
			and GameManager.accident_state == "NONE":
		await get_tree().physics_frame
		frames += 1


## 干净通过一组：先站进入口带，再越到出口后方（连击要求“真的靠近过”）。
func _pass_group(id: String) -> void:
	var start := _group_x(id)
	var end := start
	for g in LevelDataScript.groups():
		if g["group"] == id:
			end = LevelDataScript.group_end(g)
	race.turtle.position = Vector2(start - 60.0, Tuning.NEUTRAL_DEPTH)
	await _physics_frames(2)
	race.turtle.position = Vector2(end + 85.0, Tuning.NEUTRAL_DEPTH)
	await _physics_frames(2)


func _group(id: String) -> Dictionary:
	for g in LevelDataScript.groups():
		if g["group"] == id:
			return g
	return {}


func _group_x(id: String) -> float:
	for g in LevelDataScript.groups():
		if g["group"] == id:
			return LevelDataScript.group_start(g)
	return 0.0


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


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
	await get_tree().process_frame


func _tap(key: Key) -> void:
	_send_key(key, true)
	await get_tree().physics_frame
	_send_key(key, false)


func _send_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
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
