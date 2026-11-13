extends Node
## 阶段 1 脚本化连续运行：60 秒模拟时间，记录主动切换、接人、事故与恢复。
## LEGACY（2026-11-11）：非对称冲浪板取消了手动下潜，本脚本里周期按 DOWN/UP
## 的段落已不产生深度变化。它不属于回归闸门；完整赛道证据用 stage3_playtest。
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT res://scenes/stage1_playtest.tscn

const DURATION := 60.0
const LOG_PATH := "res://docs/reports/stage1-run.log"

var is_runner := false
var lines: Array[String] = []
var failures: Array[String] = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage1PlaytestRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	Engine.time_scale = 2.0
	_log("STAGE 1 SCRIPTED RUN  duration=%.0fs  time_scale=2.0" % DURATION)

	GameManager.start_race()
	await _frames(3)
	var race := get_tree().current_scene
	race.test_no_finish = true
	_check(race.scene_file_path.ends_with("race.tscn"), "race scene loaded")
	_check(GameManager.state == GameManager.GameState.RUNNING, "state RUNNING")

	var next_shift := 3.0
	var next_jump := 1.0
	var last_pickup := 0
	var saw_pickup := false
	var planned_shifts := 0
	var last_accident := "NONE"
	var accident_elapsed := 0.0
	var max_accident_elapsed := 0.0
	var stuck_elapsed := 0.0
	var last_x: float = race.turtle.position.x
	var last_check := 0.0
	var up_release := 0

	while GameManager.race_time < DURATION:
		await get_tree().physics_frame
		var t: float = GameManager.race_time

		if GameManager.accident_state != last_accident:
			if GameManager.accident_state != "NONE":
				_log("t=%5.2f  ACCIDENT %s  control=%s" % [
					t, GameManager.accident_state, GameManager.current_control])
			else:
				_log("t=%5.2f  RECOVERED  control=%s" % [t, GameManager.current_control])
			last_accident = GameManager.accident_state

		if GameManager.accident_state != "NONE":
			accident_elapsed += get_physics_process_delta_time()
			max_accident_elapsed = maxf(max_accident_elapsed, accident_elapsed)
		else:
			accident_elapsed = 0.0

		if t >= next_shift:
			GameManager.toggle_control()
			planned_shifts += 1
			_log("t=%5.2f  PLANNED SHIFT -> %s" % [t, GameManager.current_control])
			next_shift += 3.0

		# 兔子：每 2 秒在龟壳上起跳一次，制造接人机会。
		if GameManager.current_control == "rabbit" and race.mount.state == "RIDING" \
				and race.turtle.is_at_surface() and t >= next_jump:
			Input.action_press("up")
			up_release = 2
			next_jump = t + 2.0
		if up_release > 0:
			up_release -= 1
			if up_release == 0:
				Input.action_release("up")

		# 乌龟：加速并按 0.8 秒周期下潜 / 上浮。
		if GameManager.current_control == "turtle":
			Input.action_press("boost")
			if fmod(t, 1.6) < 0.8:
				Input.action_press("down")
			else:
				Input.action_release("down")
		else:
			Input.action_release("boost")
			Input.action_release("down")

		if GameManager.pickup_count > last_pickup:
			saw_pickup = true
			last_pickup = GameManager.pickup_count
			_log("t=%5.2f  PICKUP #%d  mount=%s" % [
				t, GameManager.pickup_count, race.mount.state])

		if t - last_check >= 1.0:
			var moved: float = race.turtle.position.x - last_x
			if moved < 30.0 and GameManager.accident_state == "NONE":
				stuck_elapsed += t - last_check
			else:
				stuck_elapsed = 0.0
			last_x = race.turtle.position.x
			last_check = t
			_log("t=%5.2f  state=%s control=%s rabbit=%s turtle=%s " % [
				t, GameManager.accident_state, GameManager.current_control,
				race.rabbit.state, race.turtle.state]
				+ "mount=%s slide=%d pickup=%d x=%.0f" % [
				race.mount.state, int(round(race.rabbit.slide * 100.0)),
				GameManager.pickup_count, race.turtle.position.x])

		if stuck_elapsed > 6.0:
			failures.append("turtle stuck for >6s (no forward progress)")
			break

	Input.action_release("up")
	Input.action_release("down")
	Input.action_release("boost")

	_check(planned_shifts >= 1, "at least one planned SHIFT (%d)" % planned_shifts)
	_check(saw_pickup, "at least one successful pickup (%d)" % GameManager.pickup_count)
	_check(max_accident_elapsed < 5.0,
		"no accident lasts >=5s (max %.2fs)" % max_accident_elapsed)
	_check(stuck_elapsed <= 6.0, "no >6s unrecoverable stall")
	_check(GameManager.current_control in ["rabbit", "turtle"], "control remains valid")
	_check(GameManager.race_time >= DURATION - 1.0,
		"ran full duration (%.2fs)" % GameManager.race_time)

	_log("")
	_log("RESULT  simulated=%.2fs  shifts=%d  pickups=%d  accidents=%d" % [
		GameManager.race_time, planned_shifts, GameManager.pickup_count,
		GameManager.accident_count])
	_log("RESULT  max_accident=%.2fs  stuck=%.2fs  failures=%d" % [
		max_accident_elapsed, stuck_elapsed, failures.size()])
	for item in failures:
		_log("FAIL  " + item)

	_write_log()
	Engine.time_scale = 1.0
	if failures.is_empty():
		print("STAGE1 PLAYTEST: PASS")
		get_tree().quit(0)
	else:
		print("STAGE1 PLAYTEST: FAIL")
		for item in failures:
			print("  - " + item)
		get_tree().quit(1)


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
