extends Node
## 阶段 4 P1-4 验收（TBB-SHIFT-FEEL-03）：Zone 1 前 35 s 的节奏。
##
## 用正式关卡、真实物理和引擎按键代理，从起跑点跑到 log1 之后，记录：
##   0–5 s     无强制输入（第一次按键必须晚于 4.0 s）
##   5–10 s    首次互动（bird1 趴低）
##   15–20 s   首次有意义的 SHIFT（gate1 必须换乌龟下潜）
##   25–35 s   首次协同（log1 跳 + SHIFT + ↓）
## 只换站位，不新增大字教学；本探针只证明“节奏在三段窗口里”，不判有趣性。
##
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT \
##       res://scenes/stage4_z1_rhythm.tscn
## 输出：docs/reports/longrun/phase-v-z1-rhythm.json

const Tuning = preload("res://scripts/systems/tuning.gd")
const LevelData = preload("res://scripts/systems/level_data.gd")
const OUT_PATH := "res://docs/reports/longrun/phase-v-z1-rhythm.json"
const STOP_X := 7100.0
const MAX_SIM := 45.0

var is_runner := false
var race
var sim := 0.0
var timeline: Array = []
var first := {
	"crouch": -1.0, "jump": -1.0, "shift": -1.0, "combo": -1.0,
	"crouch_x": 0.0, "jump_x": 0.0, "shift_x": 0.0, "combo_x": 0.0,
}
var failures: Array[String] = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4Z1RhythmRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	Engine.time_scale = 3.0
	GameManager.start_race()
	for i in 3:
		await get_tree().process_frame
	race = get_tree().current_scene
	_check(race != null and race.scene_file_path.ends_with("race.tscn"),
		"formal race scene loaded")
	if race == null:
		_finish()
		return
	race.test_no_finish = true
	# start_race 到第一次 await 之间已经跑了半个身位（≈0.5 s）。探针的时钟必须
	# 对齐真正的起跑点，否则所有事件都会被算早半个身位。前 3 s 没有神游掉速，
	# 用 220 px/s 反推这段预跑时间足够（误差 <0.05 s）。
	sim = maxf(0.0, (race.turtle.position.x - LevelData.RACE_START_X) / 220.0)

	var groups: Array = race.hazard_groups
	var kinds: Array = []
	for i in groups.size():
		var g: Dictionary = groups[i]
		if LevelData.group_start(g) > STOP_X:
			break
		kinds.append(String(g["kind"]))
		await _handle(g)
		if GameManager.accident_state != "NONE":
			break
		if race.turtle.position.x > STOP_X:
			break
		if sim > MAX_SIM:
			break

	var total_groups := groups.size()
	_check(kinds.size() >= 5, "reached the first five groups (%d)" % kinds.size())
	_check(kinds.slice(0, 5) == ["LOW_BIRD", "SURFACE_ROCK", "DIVE_GATE",
		"SURFACE_ROCK", "FLOATING_LOG"],
		"Z1 opening order is bird/rock/gate/rock/log (%s)" % str(kinds))
	_check(GameManager.accident_count == 0,
		"clean opening, no accidents (%d)" % GameManager.accident_count)
	_check(race.hit_groups.is_empty(), "no hazard contact (%s)" % str(race.hit_groups.keys()))

	_check(first["crouch"] > 4.0,
		"no forced input in the first 4 s (first press at %.2f s)" % first["crouch"])
	_check(first["crouch"] >= 4.5 and first["crouch"] <= 10.0,
		"first interaction in 5-10 s window (crouch at %.2f s)" % first["crouch"])
	_check(first["shift"] >= 14.0 and first["shift"] <= 20.0,
		"first required SHIFT in 15-20 s window (at %.2f s)" % first["shift"])
	_check(first["combo"] >= 25.0 and first["combo"] <= 35.0,
		"first collaboration in 25-35 s window (at %.2f s)" % first["combo"])
	_check(first["crouch"] < first["jump"] and first["jump"] < first["shift"]
		and first["shift"] < first["combo"],
		"nodes arrive in order crouch < jump < shift < combo")
	_check(race.turtle.position.x >= 6650.0,
		"simulation reached past the first combo (x=%.0f)" % race.turtle.position.x)

	_write_json()
	Engine.time_scale = 1.0
	_finish()


# ---------------- 驱动（按本局实际种类，动作来自 stage3 的实测路线） ----------------

func _handle(g: Dictionary) -> void:
	var kind := String(g["kind"])
	var start := LevelData.group_start(g)
	var end := LevelData.group_end(g)
	var t0 := sim
	var x0: float = race.turtle.position.x
	match kind:
		"LOW_BIRD", "LOW_BEAM":
			# 趴低是兔子的活：不要求先浮壳，直接握兔子到梁前 55 px。
			await _control_to("rabbit")
			await _until_x(start - 55.0)
			if first["crouch"] < 0.0:
				first["crouch"] = sim
				first["crouch_x"] = race.turtle.position.x
			_press("down")
			var guard := 0
			while race.rabbit.position.x < end + 24.0 and guard < 360 \
					and GameManager.accident_state == "NONE":
				await _step()
				guard += 1
			_release("down")
			await _control_to("turtle")
		"SURFACE_ROCK":
			var spd: float = race.turtle.base_speed
			var lead := clampf(1.2 * spd - 70.0 - 138.0, 15.0, 120.0)
			await _settle(start - lead - 100.0)
			await _control_to("rabbit")
			await _until_x(start - lead)
			if first["jump"] < 0.0:
				first["jump"] = sim
				first["jump_x"] = race.turtle.position.x
			_press("up")
			# 兔子可能正在神游：按键会晚 0.04–0.22 s 才执行，等真的离地再松手。
			var launch := 0
			while launch < 30 and race.mount.state != "AIRBORNE" \
					and GameManager.accident_state == "NONE":
				await _step()
				launch += 1
			_release("up")
			var guard := 0
			while race.mount.state == "AIRBORNE" and guard < 200 \
					and GameManager.accident_state == "NONE":
				await _step()
				guard += 1
			await _control_to("turtle")
		"DIVE_GATE":
			await _settle(start - 160.0)
			if first["shift"] < 0.0:
				first["shift"] = sim
				first["shift_x"] = race.turtle.position.x
			await _control_to("turtle")
			_press("down")
			var guard := 0
			while race.turtle.position.x < end + 90.0 and guard < 600 \
					and GameManager.accident_state == "NONE":
				await _step()
				guard += 1
			_release("down")
		"SHARK", "FLOATING_LOG", "HIGH_WALL":
			if first["shift"] < 0.0:
				first["shift"] = sim
				first["shift_x"] = race.turtle.position.x
			await _log_combo(start, end)
		_:
			await _settle(start - 120.0)
	timeline.append({
		"group": String(g["group"]), "kind": kind,
		"t_handler": snappedf(t0, 0.01),
		"x_handler": snappedf(x0, 1.0),
		"handler_s": snappedf(sim - t0, 0.01),
		"accident": GameManager.accident_state,
	})


func _log_combo(start: float, end: float) -> void:
	# 本探针测节奏，不测 Showtime；连击刚好在浮木前触发时表演会锁兔子。
	if race.showtime_active:
		race._end_showtime(false)
	await _settle(start - 250.0)
	await _control_to("rabbit")
	var press_x: float = start - (float(race.turtle.base_speed) * 0.7 - 2.0)
	await _until_x(press_x)
	if first["combo"] < 0.0:
		first["combo"] = sim
		first["combo_x"] = race.turtle.position.x
	_press("up")
	var launch := 0
	while launch < 30 and race.mount.state != "AIRBORNE" \
			and GameManager.accident_state == "NONE":
		await _step()
		launch += 1
	_release("up")
	_press("down")
	# 本探针只测 Z1 节奏，不测 SHIFT 冷却；由 _control_to 清掉锁定，
	# 保持原始“跳→换手→下潜”的时序。
	await _control_to("turtle")
	var guard := 0
	while race.turtle.position.x < end + 30.0 and guard < 600 \
			and GameManager.accident_state == "NONE":
		await _step()
		guard += 1
	_release("down")
	var settle_t := sim
	while sim - settle_t < 2.5 and GameManager.accident_state == "NONE":
		if race.mount.state == "RIDING" and race.turtle.position.y <= Tuning.NEUTRAL_DEPTH + 2.0:
			break
		await _step()
	await _control_to("turtle")


# ---------------- 工具 ----------------

func _settle(target_x: float) -> void:
	await _control_to("turtle")
	var guard := 0
	while race.turtle.position.x < target_x and guard < 900 \
			and GameManager.accident_state == "NONE" and sim < MAX_SIM:
		await _step()
		guard += 1
	# 巡航水深：起跳/下潜都要求壳在 334 附近（上浮由浮力完成）。
	guard = 0
	while race.turtle.position.y > 400.0 and guard < 300 \
			and GameManager.accident_state == "NONE":
		await _step()
		guard += 1


func _until_x(target: float) -> void:
	var guard := 0
	while race.turtle.position.x < target and guard < 600 \
			and GameManager.accident_state == "NONE":
		await _step()
		guard += 1


func _control_to(who: String) -> void:
	if GameManager.current_control == who:
		return
	var guard := 0
	while GameManager.current_control != who and guard < 30:
		if race.showtime_active:
			await _step()
			guard += 1
			continue
		GameManager.shift_lock_t = 0.0
		GameManager.toggle_control()
		await _step()
		guard += 1


func _press(action: String) -> void:
	if not Input.is_action_pressed(action):
		Input.action_press(action)


func _release(action: String) -> void:
	if Input.is_action_pressed(action):
		Input.action_release(action)


func _step() -> void:
	await get_tree().physics_frame
	sim += (1.0 / 60.0) * Engine.time_scale


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)


func _write_json() -> void:
	var data := {
		"generated_at": Time.get_datetime_string_from_system(),
		"note": "Zone 1 opening rhythm: real physics + engine input proxy; not a human playtest.",
		"race_start_x": LevelData.RACE_START_X,
		"z1_base_speed": 220.0,
		"first": first,
		"timeline": timeline,
		"accidents": GameManager.accident_count,
		"hits": race.hit_groups.keys(),
		"reached_x": snappedf(race.turtle.position.x, 1.0),
		"sim_s": snappedf(sim, 0.01),
	}
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
		f.close()


func _finish() -> void:
	if failures.is_empty():
		print("STAGE4 Z1 RHYTHM: PASS")
	else:
		print("STAGE4 Z1 RHYTHM: FAIL")
		for item in failures:
			print("  - " + item)
	print("  first: " + JSON.stringify(first))
	print("  timeline: " + JSON.stringify(timeline))
	get_tree().quit(0 if failures.is_empty() else 1)
