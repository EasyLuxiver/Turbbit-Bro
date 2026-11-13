extends Node
## TBB-SHIFT-CORE-02 第 5 步：食物碰撞与恢复。
## 规则在 Playful-04 改过、CORE-FEEL-07 P1-C 沿用：**操控谁就谁吃**。
## 本探针原写于 SHIFT-CORE-02，当时规定“操控兔子时乌龟照样吃”；那条已被
## “SHIFT 决定谁吃”的取舍取代，所以这里改判：兔子控制下兔子吃、乌龟继续走神；
## 乌龟控制下乌龟吃、走神归零并进 TURBO。固定步长推进真实 race.gd 的
## _physics_process，不另写一套模拟。只关障碍和冲线；食物用注入的确定性遭遇。
##
## 证据类型：headless 自动化 + 窗口化截图（同一脚本）；不是真人试玩。
## 运行：
##   Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT \
##       res://scenes/stage4_snack_contact.tscn
## 输出：docs/reports/stage4-snack-contact.json，窗口化时截图 screenshots/snack-*.png

const Tuning = preload("res://scripts/systems/tuning.gd")
const LevelData = preload("res://scripts/systems/level_data.gd")
const OUT_PATH := "res://docs/reports/stage4-snack-contact.json"
const STEP := 1.0 / 60.0

var is_runner := false
var failures: Array[String] = []
var race
var data := {}


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4SnackContactRunner"
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
	race.test_disable_hazards = true
	race.test_no_finish = true
	race.set_physics_process(false)
	race.hazard_groups = []
	race.entered_groups.clear()
	# 关掉关卡自带的食物表：本测试只注入自己的一条，避免半路被真食物清掉神游。
	race.boost_lanes = []
	race._snack_cache_sig = -1
	race._snack_cache = []

	data["eat_while_controlling_rabbit"] = await _eat_while_rabbit()
	data["eat_while_controlling_turtle"] = _eat_while_turtle()
	data["boost_window"] = await _boost_window()
	data["no_stacking"] = await _no_stacking()
	data["dive_avoids"] = await _dive_avoids()
	_write_json()
	_finish()


## 操控兔子时兔子吃：乌龟继续走神（不会因为兔子吃到而恢复），这是“给谁吃”的取舍。
func _eat_while_rabbit() -> Dictionary:
	_park(Vector2(2000.0, Tuning.NEUTRAL_DEPTH))
	race.reset_brains()
	GameManager.set_control("rabbit")
	# 先让乌龟无人管 6 s，形成真实的走神量，再让食物出现在嘴边。
	_tick(360)
	var drift_before: float = race.turtle_brain.drift
	var state_before: String = race.turtle_brain.state_name()
	var enc := _place_food(30.0)
	var pass0: int = GameManager.clean_pass_count
	var meter0: int = GameManager.bro_meter
	var accidents0: int = GameManager.accident_count
	_tick(1)
	var eaten: bool = bool(enc["eaten"])
	_check(eaten, "rabbit bites while the player controls the rabbit")
	_check(race.snack_last_by == "rabbit",
		"the bite is credited to the rabbit (got %s)" % race.snack_last_by)
	_check(GameManager.current_control == "rabbit",
		"control stays on the rabbit through the bite")
	_check(drift_before >= 3.0,
		"turtle was genuinely drifting before the bite (%.2f s, %s)"
		% [drift_before, state_before])
	_check(race.turtle_brain.drift >= drift_before - 0.0001,
		"a rabbit bite does not calm the drifting turtle (%.2f -> %.2f)"
		% [drift_before, race.turtle_brain.drift])
	_check(absf(race.rabbit.jump_boost - Tuning.RABBIT_SNACK_JUMP_SCALE) < 0.001,
		"rabbit bite grants the jump boost (%.2f)" % race.rabbit.jump_boost)
	_check(GameManager.clean_pass_count == pass0,
		"a bite is not counted as a normal obstacle pass")
	_check(GameManager.bro_meter == meter0 and GameManager.accident_count == accidents0,
		"a bite writes no BRO METER slot and no accident")
	if DisplayServer.get_name() != "headless":
		await _shot("snack-eat-rabbit-driving.png")
	return {
		"drift_before": snappedf(drift_before, 0.01),
		"state_before": state_before,
		"drift_after": snappedf(race.turtle_brain.drift, 0.01),
		"eaten": eaten,
		"by": race.snack_last_by,
		"jump_boost": snappedf(race.rabbit.jump_boost, 0.01),
		"control": GameManager.current_control,
		"clean_pass_before": pass0,
		"clean_pass_after": GameManager.clean_pass_count,
	}


## 操控乌龟时乌龟吃：走神清零、TURBO 生效——食物是“照顾乌龟”的方式。
func _eat_while_turtle() -> Dictionary:
	_park(Vector2(2000.0, Tuning.NEUTRAL_DEPTH))
	race.reset_brains()
	GameManager.set_control("rabbit")
	_tick(360)
	var drift_before: float = race.turtle_brain.drift
	GameManager.set_control("turtle")
	var enc := _place_food(30.0)
	var meter0: int = GameManager.bro_meter
	_tick(1)
	_check(bool(enc["eaten"]), "turtle bites while the player controls the turtle")
	_check(race.snack_last_by == "turtle",
		"the bite is credited to the turtle (got %s)" % race.snack_last_by)
	_check(drift_before >= 3.0,
		"turtle was genuinely drifting before the bite (%.2f)" % drift_before)
	_check(race.turtle_brain.drift <= 0.0001,
		"a turtle bite calms the turtle (%.2f -> %.2f)"
		% [drift_before, race.turtle_brain.drift])
	_check(GameManager.bro_meter == meter0, "a turtle bite writes no BRO METER slot")
	return {
		"drift_before": snappedf(drift_before, 0.01),
		"drift_after": snappedf(race.turtle_brain.drift, 0.01),
		"eaten": bool(enc["eaten"]),
		"by": race.snack_last_by,
		"control": GameManager.current_control,
	}


## 1.15× 短加速：吃到后真的更快，窗口结束后平滑回到区速；不是永久加速。
func _boost_window() -> Dictionary:
	_check(race.snack_boost_active(), "boost is active right after the bite")
	var want: float = float(race.current_zone["base_speed"]) * LevelData.SNACK_BOOST_SCALE
	var target_at_bite: float = race.snack_boost_speed
	_check(absf(target_at_bite - want) <= 0.1,
		"boost target is 1.15x zone base (%.1f want %.1f)" % [target_at_bite, want])
	var speed_max := 0.0
	var frames := 0
	while race.snack_boost_active() and frames < 600:
		_tick(1)
		frames += 1
		speed_max = maxf(speed_max, race.turtle.speed)
	_check(speed_max >= want - 2.0 and speed_max <= want + 1.0,
		"turtle actually reaches the boost speed (%.1f)" % speed_max)
	_check(not race.snack_boost_active(),
		"boost window closes by itself (%.2f s)" % (frames * STEP))
	var after_frames := 0
	while absf(race.turtle.speed - race.turtle.base_speed) > 2.0 and after_frames < 300:
		_tick(1)
		after_frames += 1
	_check(race.snack_boost_speed == 0.0 and after_frames <= 90,
		"boost ends smoothly back to cruise speed (%.2f s, speed %.1f)"
		% [after_frames * STEP, race.turtle.speed])
	return {
		"want_speed": snappedf(want, 0.1),
		"speed_max": snappedf(speed_max, 0.1),
		"boost_seconds": snappedf(frames * STEP, 0.01),
		"settle_seconds": snappedf(after_frames * STEP, 0.01),
		"settled_speed": snappedf(race.turtle.speed, 0.1),
	}


## 连续吃两个不会叠成 1.15²：第二次只是刷新同一段加速。
func _no_stacking() -> Dictionary:
	race.reset_brains()
	GameManager.set_control("turtle")
	var enc := _place_food(20.0)
	_tick(1)
	_check(bool(enc["eaten"]), "first bite lands")
	var first_speed: float = race.snack_boost_speed
	var enc2 := _place_food(20.0)
	_tick(1)
	_check(bool(enc2["eaten"]), "second bite lands inside the boost")
	var second_speed: float = race.snack_boost_speed
	var limit: float = float(race.current_zone["base_speed"]) * LevelData.SNACK_BOOST_SCALE
	var speed_max := 0.0
	for i in 60:
		_tick(1)
		speed_max = maxf(speed_max, race.turtle.speed)
	_check(absf(second_speed - first_speed) <= 0.1 and second_speed <= limit + 0.1,
		"two bites do not multiply the boost (%.1f -> %.1f, limit %.1f)"
		% [first_speed, second_speed, limit])
	_check(speed_max <= limit + 1.0,
		"no infinite stacking in actual speed (%.1f)" % speed_max)
	return {
		"first_boost_speed": snappedf(first_speed, 0.1),
		"second_boost_speed": snappedf(second_speed, 0.1),
		"speed_max": snappedf(speed_max, 0.1),
		"limit": snappedf(limit, 0.1),
	}


## 操控乌龟时 ↓ 下潜可以主动选择“不吃”：判定用的是真实高度，不是角色开关。
func _dive_avoids() -> Dictionary:
	_park(Vector2(4200.0, Tuning.NEUTRAL_DEPTH))
	race.reset_brains()
	GameManager.set_control("turtle")
	var enc := _place_food(300.0)
	var fx: float = float(enc["x"])
	Input.action_press("down")
	var deepest := 0.0
	var frames := 0
	while race.turtle.position.x < fx + 80.0 and frames < 300:
		_tick(1)
		deepest = maxf(deepest, race.turtle.position.y)
		frames += 1
	Input.action_release("down")
	_check(not bool(enc["eaten"]),
		"holding down dives under the food and does not bite")
	_check(deepest >= Tuning.NEUTRAL_DEPTH + 80.0,
		"the dive actually left the food layer (deepest %.1f)" % deepest)
	if DisplayServer.get_name() != "headless":
		await _shot("snack-dive-pass.png")
	# 松手后浮回巡航深度，食物还在（前面没吃，下一个还在）。
	_tick(240)
	_check(absf(race.turtle.position.y - Tuning.NEUTRAL_DEPTH) < 20.0,
		"released dive returns to cruise depth (%.1f)" % race.turtle.position.y)
	return {
		"eaten": bool(enc["eaten"]),
		"deepest_y": snappedf(deepest, 0.1),
		"returned_y": snappedf(race.turtle.position.y, 0.1),
	}


## 把乌龟放到指定位置，同步兔子与相机，避免上一条用例的位移污染下一条。
func _park(at: Vector2) -> void:
	race.turtle.position = at
	race.turtle.speed = race.turtle.base_speed
	race.turtle._vy = 0.0
	race.mount.mark_riding()
	race.rabbit.position = race.turtle.get_mount_point()
	race._update_camera()
	race.queue_redraw()


## 注入一条确定性食物遭遇：食物在乌龟前方 dx 处，并给一个用于计算加速窗口的组。
func _place_food(dx: float) -> Dictionary:
	var fx: float = race.turtle.position.x + dx
	var enc := {
		"x": fx, "lane": Rect2(Vector2(fx - 100.0, 0.0), Vector2(200.0, 0.0)),
		"obstacle_index": 0, "obstacle_group": "TEST_BITE", "zone": 1, "eaten": false,
	}
	race.boost_lanes = []
	race._snack_cache = [enc]
	race._snack_cache_sig = 0
	# 组只为 _eat_snack 计算“加速到障碍之后”的窗口；吃完立即移除以免触发连击。
	race.hazard_groups = [{
		"group": "TEST_BITE", "kind": "LOW_BIRD", "zone": 1,
		"rects": [Rect2(fx + 260.0, 200.0, 40.0, 100.0)],
	}]
	race.entered_groups.clear()
	return enc


func _tick(n: int) -> void:
	for i in n:
		race._physics_process(STEP)
		if race.hazard_groups.size() > 0 and race.snack_gulp_t > 0.0:
			# 吃到了：障碍组只用于算窗口，留着会被当成正常通过。
			race.hazard_groups = []


func _shot(file_name: String) -> void:
	await get_tree().process_frame
	race._save_shot(file_name)


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
		print("STAGE4 SNACK CONTACT: PASS")
	else:
		print("STAGE4 SNACK CONTACT: FAIL")
		for item in failures:
			print("  - " + item)
	print("SNACK CONTACT data: " + JSON.stringify(data))
	get_tree().quit(0 if failures.is_empty() else 1)
