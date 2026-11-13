extends Node
## TBB-SHIFT-CORE-02 §6：兔子落水坐标与接人判定的证据探针（只读，不改玩法）。
##
## 回答三件事：
##   1) 落水是不是从真实离壳位置开始——逐帧记录兔子的世界坐标，检查有没有瞬移；
##   2) 水花是不是在实际落点、乌龟没有把兔子提前拽到前面；
##   3) 接人窗口/失败原因：从水花算起的下潜延迟阶梯 + 结果与原因。
##
## 用法：
##   D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
##       res://scenes/stage4_water_rescue.tscn > docs/reports/logs/phase-shift/water-rescue.log 2>&1
##
## 输出：docs/reports/longrun/shift02-water-rescue.json

const RaceScene = preload("res://scenes/race.tscn")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/shift02-water-rescue.json"
## 下潜延迟从“水花出现”开始算；-1 = 不下潜（安全恢复路径）。
const DELAYS := [-1.0, 0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 1.2, 1.6, 2.0]
const STEP_MAX := 8.0

var is_runner := false
var race: Node = null
var sim := 0.0
var rows: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 16.0
	Engine.physics_ticks_per_second = 960
	await get_tree().process_frame
	await _run()


func _run() -> void:
	race = RaceScene.instantiate()
	add_child(race)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	GameManager._reset_run()
	GameManager.state = GameManager.GameState.RUNNING
	# 单段直线、无其他障碍干扰；落水机制本身照常。
	race.test_disable_hazards = true
	race.test_no_finish = true
	race.setup_rescue_proto()
	await get_tree().physics_frame

	print("WATER: delays=%d step_max=%.1f" % [DELAYS.size(), STEP_MAX])
	for delay in DELAYS:
		var row := await _trial("proto", delay)
		rows.append(row)
		print("%-8s delay=%.1f trigger_dx=%.1f entry_dx=%.1f fall=%.2f maxstep=%.1f " % [
			String(row["mode"]), delay, float(row["trigger_dx"]),
			float(row["entry_dx"]), float(row["fall_s"]), float(row["max_step"])]
			+ "result=%-6s reason=%-18s catch_after=%.2f min_dy=%.1f" % [
				String(row["result"]), String(row["reason"]),
				float(row["catch_after_splash"]), float(row["min_dy"])])
		_write()
	# 自然路径：真的跳一次、没人接，由 _tick_rabbit 自己触发落水。
	for delay in [-1.0, 0.0, 0.4, 0.8]:
		var row2 := await _trial("natural", delay)
		rows.append(row2)
		print("%-8s delay=%.1f trigger_dx=%.1f entry_dx=%.1f fall=%.2f maxstep=%.1f " % [
			String(row2["mode"]), delay, float(row2["trigger_dx"]),
			float(row2["entry_dx"]), float(row2["fall_s"]), float(row2["max_step"])]
			+ "result=%-6s reason=%-18s catch_after=%.2f min_dy=%.1f" % [
				String(row2["result"]), String(row2["reason"]),
				float(row2["catch_after_splash"]), float(row2["min_dy"])])
		_write()
	print("WATER: DONE")
	get_tree().quit(0)


func _trial(mode: String, delay: float) -> Dictionary:
	_release_all()
	if mode == "proto":
		race.start_rescue_proto()
	else:
		_arm_natural()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var t0 := sim
	var trigger_dx := -999.0
	var entry := Vector2.ZERO
	var entry_dx := -999.0
	var splash_t := -1.0
	var fall_s := -1.0
	var max_step := 0.0
	var teleports := 0
	var teleport_at := -1.0
	var teleport_px := 0.0
	var prev: Vector2 = race.rabbit.position
	var shifted := false
	var dived := false
	var result := ""
	var reason := ""
	var catch_after := -1.0
	var min_dy := 999.0
	var recovered_s := -1.0
	var steps := 0
	# 自然路径的“被撞掉”：跳起来之后由 hazard 走 _rabbit_contact，
	# 和鸟/浪把空中的兔子打下去是同一条代码路径。
	var hit_done := mode != "natural"
	while sim - t0 < 9.0 and steps < 600:
		var rb: Vector2 = race.rabbit.position
		# 连续性：一帧位移不得大于“当前速度 × dt + 6 px 余量”。
		# 只在对“落水/下落/水中”这段计时；接住那一帧的吸附、回收演出不算瞬移。
		var vlen: float = race.rabbit.velocity.length()
		var allow := vlen / 60.0 + 6.0
		var tracking: bool = race.mount.state in ["AIRBORNE", "RESCUE_FALLING",
			"RESCUE_ACTIVE"]
		if tracking:
			var step_len := prev.distance_to(rb)
			max_step = maxf(max_step, step_len)
			if step_len > allow:
				teleports += 1
				teleport_at = sim - t0
				teleport_px = maxf(teleport_px, step_len)
		prev = rb

		if not hit_done and sim - t0 >= 0.30:
			hit_done = true
			race._rabbit_contact()

		if GameManager.accident_state == "RABBIT_WATER" and trigger_dx < -900.0:
			trigger_dx = rb.x - race.turtle.position.x
		if splash_t < 0.0 and race.mount.state == "RESCUE_ACTIVE":
			splash_t = sim - t0
			entry = rb
			entry_dx = rb.x - race.turtle.position.x
			fall_s = sim - t0
		if splash_t >= 0.0:
			var mp: Vector2 = race.turtle.get_mount_point()
			if race.mount.state == "RESCUE_ACTIVE":
				min_dy = minf(min_dy, rb.y - mp.y)
			if not shifted and delay >= 0.0:
				_control("turtle")
				shifted = true
			if delay >= 0.0 and not dived and sim - t0 - splash_t >= delay:
				_press("down")
				dived = true

		if result == "" and String(race.rescue_last_result) != "":
			result = String(race.rescue_last_result)
			reason = String(race.rescue_last_reason)
			catch_after = sim - t0 - splash_t if splash_t >= 0.0 else -1.0
		if result != "" and GameManager.accident_state == "NONE" \
				and race.mount.state == "RIDING":
			recovered_s = sim - t0
			break
		await _step()
		steps += 1
	_release_all()
	if result == "":
		result = "timeout"
	return {
		"mode": mode,
		"delay": delay,
		"trigger_dx": snappedf(trigger_dx, 0.1),
		"entry_dx": snappedf(entry_dx, 0.1),
		"entry_y": snappedf(entry.y, 0.1),
		"fall_s": snappedf(fall_s, 0.01),
		# 水花与“穿水前最后一帧的兔子位置”只差一帧的下落距离（<20 px），
		# 说明水花就画在实际落点，不是别处。
		"splash_matches_entry": entry.distance_to(race.rescue_splash_pos) <= 20.0
			if entry_dx > -900.0 else false,
		"splash_dx": snappedf(race.rescue_splash_pos.x - race.turtle.position.x, 0.1),
		"max_step": snappedf(max_step, 0.1),
		"teleports": teleports,
		"teleport_at": snappedf(teleport_at, 0.01),
		"teleport_px": snappedf(teleport_px, 0.1),
		"splash_step_px": snappedf(entry.distance_to(race.rescue_splash_pos), 0.1),
		"result": result,
		"reason": reason,
		"catch_after_splash": snappedf(catch_after, 0.01),
		"min_dy": 0.0 if min_dy > 900.0 else snappedf(min_dy, 0.1),
		"recover_s": snappedf(recovered_s, 0.01),
		"oxygen_used": snappedf(Tuning.OXYGEN_MAX - GameManager.oxygen, 0.01),
	}


## 自然路径的起手：真的按一次跳、随后切到乌龟但不下潜。
func _arm_natural() -> void:
	# 自然路径不要 proto 的自动重开：结果由 _tick_rabbit 自己判。
	race.rescue_proto_mode = false
	race._arm_rescue_proto(false)
	# _arm_rescue_proto 会立刻触发事故；自然路径要从“还在跳”开始，
	# 所以先把它复原成一次普通起跳，让 _tick_rabbit 自己判落水。
	GameManager.accident_state = "NONE"
	race.rescue_last_result = ""
	race.rescue_last_reason = ""
	race.rescue_splash_t = -1.0
	race.hazard_cooldown = 0.0
	race.mount.reset()
	race.rabbit.reset()
	race.rabbit.launch(race.turtle.get_mount_point(), race.turtle.speed)
	race.mount.mark_airborne()


func _control(who: String) -> void:
	if GameManager.current_control != who:
		GameManager.set_control(who)


func _press(action: String) -> void:
	if not Input.is_action_pressed(action):
		Input.action_press(action)


func _release_all() -> void:
	Input.action_release("up")
	Input.action_release("down")
	Input.action_release("shift")


func _step() -> void:
	await get_tree().physics_frame
	sim += 1.0 / 60.0


func _write() -> void:
	var data := {
		"generated_at": Time.get_datetime_string_from_system(),
		"note": "落水坐标/接人窗口：引擎内输入代理，不是真人；hazard 关闭只为隔离机制。",
		"cases": rows,
	}
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
		f.close()
