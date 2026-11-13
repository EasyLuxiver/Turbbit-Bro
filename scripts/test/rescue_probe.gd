extends Node
## PHASE F 主动救援自动探针（只读玩法结果，不修改救援逻辑）
##
## 用一个包装场景实例化 race.tscn，再反复调用 race.start_rescue_proto()：
##   - 不输入 -> 必须失败并有限恢复；
##   - 只 SHIFT 不潜 -> 必须失败；
##   - 在不同时间开始按住 ↓ -> 测出接住窗口；
##   - 先切乌龟再潜 -> 验证“玩家主动切人”这条路径。
##
## 用法：
##   D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
##       res://scenes/rescue_probe.tscn > docs/reports/logs/rescue-probe.log 2>&1
##
## 输出：docs/reports/longrun/phase-f-rescue.json

const RaceScene = preload("res://scenes/race.tscn")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/phase-f-rescue.json"

## [标签, 开始下潜的延迟 s, 是否先切回兔子再 SHIFT]
const TRIALS := [
	["none", -1.0, false],
	["shift_only", -1.0, true],
	["dive_0.0", 0.0, false],
	["dive_0.2", 0.2, false],
	["dive_0.4", 0.4, false],
	["dive_0.6", 0.6, false],
	["dive_0.8", 0.8, false],
	["dive_1.0", 1.0, false],
	["dive_1.2", 1.2, false],
	["dive_1.4", 1.4, false],
	["dive_1.6", 1.6, false],
	["dive_1.8", 1.8, false],
	["dive_2.0", 2.0, false],
	["dive_2.2", 2.2, false],
	["dive_2.6", 2.6, false],
	["shift_then_dive", 0.6, true],
]

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
	race.setup_rescue_proto()
	await get_tree().physics_frame

	print("RESCUE: container=%d trials=%d" % [Tuning.RESCUE_ACTIVE_TIME, TRIALS.size()])
	for t in TRIALS:
		var label: String = String(t[0])
		var delay: float = float(t[1])
		var switch_first: bool = bool(t[2])
		var row: Dictionary = await _trial(label, delay, switch_first)
		rows.append(row)
		print("%-15s result=%-6s catch=%.2f recover=%.2f oxy=%.2f acc=%d" % [
			label, String(row["result"]), float(row["catch_s"]),
			float(row["recover_s"]), float(row["oxygen"]), int(row["accident_count"])])
		_write()

	_write()
	print("RESCUE: DONE")
	get_tree().quit(0)


func _trial(label: String, delay: float, switch_first: bool) -> Dictionary:
	_release_all()
	race.start_rescue_proto()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var t0 := sim
	if switch_first:
		# 模拟玩家在兔子身上：事故不强制换人，SHIFT 应被允许。
		GameManager.current_control = "rabbit"
		GameManager.has_shifted = true
		await _step()
		GameManager.toggle_control()
		if label == "shift_only":
			# 只切人，不下潜。
			pass
	if delay >= 0.0:
		while sim - t0 < delay - 0.001:
			await _step()
		_press("down")

	var result := ""
	var catch_s := -1.0
	var recovered_s := -1.0
	while sim - t0 < 5.0:
		if result == "" and String(race.rescue_last_result) != "":
			result = String(race.rescue_last_result)
			catch_s = sim - t0
		if result != "" and GameManager.accident_state == "NONE" \
				and race.mount.state == "RIDING":
			recovered_s = sim - t0
			break
		await _step()
	_release_all()

	if result == "":
		result = "timeout"
	if recovered_s < 0.0 and GameManager.accident_state == "NONE" \
			and race.mount.state == "RIDING":
		recovered_s = sim - t0
	return {
		"label": label,
		"delay": delay,
		"switch_first": switch_first,
		"result": result,
		"catch_s": snappedf(catch_s, 0.01),
		"recover_s": snappedf(recovered_s, 0.01),
		"oxygen": snappedf(GameManager.oxygen, 0.01),
		"accident_count": GameManager.accident_count,
		"bro_meter": GameManager.bro_meter,
		"rabbit_x_ahead": snappedf(race.rabbit.position.x - race.turtle.position.x, 0.1),
		"control": GameManager.current_control,
	}


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
		"note": "主动救援自动探针：真实按键、自动驾驶代理，不是真人。",
		"trials": rows,
	}
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
		f.close()
