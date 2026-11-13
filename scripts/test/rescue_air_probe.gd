extends Node
## PHASE F 方案 2 对比探针：兔子从空中落下，乌龟必须在正确时机跃起接住。
##
## 只用于原型对比，不改正常赛道。所有结果写入 phase-f-rescue-air.json。
##
## 用法：
##   D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
##       res://scenes/rescue_air_probe.tscn > docs/reports/logs/rescue-air-probe.log 2>&1

const RaceScene = preload("res://scenes/race.tscn")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/phase-f-rescue-air.json"

## [标签, 跃起延迟 s, 是否先下潜（错误动作对照）]
const TRIALS := [
	["none", -1.0, false],
	["dive_only", -1.0, true],
	["leap_0.0", 0.0, false],
	["leap_0.2", 0.2, false],
	["leap_0.4", 0.4, false],
	["leap_0.6", 0.6, false],
	["leap_0.8", 0.8, false],
	["leap_1.0", 1.0, false],
	["leap_1.2", 1.2, false],
	["leap_1.4", 1.4, false],
	["leap_1.6", 1.6, false],
	["leap_1.8", 1.8, false],
	["leap_2.0", 2.0, false],
	["leap_2.2", 2.2, false],
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

	print("RESCUE-AIR: container=%.2f trials=%d" % [
		Tuning.RESCUE_AIR_TIME, TRIALS.size()])
	for t in TRIALS:
		var label: String = String(t[0])
		var delay: float = float(t[1])
		var dive_first: bool = bool(t[2])
		var row: Dictionary = await _trial(label, delay, dive_first)
		rows.append(row)
		print("%-12s result=%-6s catch=%.2f recover=%.2f min_dy=%.0f" % [
			label, String(row["result"]), float(row["catch_s"]),
			float(row["recover_s"]), float(row["min_dy"])])
		_write()

	_write()
	print("RESCUE-AIR: DONE")
	get_tree().quit(0)


func _trial(label: String, delay: float, dive_first: bool) -> Dictionary:
	_release_all()
	race.start_rescue_proto(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var t0 := sim
	if dive_first:
		_press("down")

	var result := ""
	var catch_s := -1.0
	var recovered_s := -1.0
	var min_dy := 9999.0
	var leap_at := -1.0
	while sim - t0 < 5.0:
		if delay >= 0.0 and leap_at < 0.0 and sim - t0 >= delay - 0.001:
			_press("up")
			leap_at = sim - t0
		var dy: float = race.rabbit.position.y - race.turtle.get_mount_point().y
		min_dy = minf(min_dy, absf(dy))
		if result == "" and String(race.rescue_last_result) != "":
			result = String(race.rescue_last_result)
			catch_s = sim - t0
		if result != "" and GameManager.accident_state == "NONE" \
				and race.mount.state == "RIDING":
			recovered_s = sim - t0
			break
		await _step()
		if leap_at >= 0.0 and sim - t0 > leap_at + 0.05:
			Input.action_release("up")
	_release_all()

	if result == "":
		result = "timeout"
	if recovered_s < 0.0 and GameManager.accident_state == "NONE" \
			and race.mount.state == "RIDING":
		recovered_s = sim - t0
	return {
		"label": label,
		"delay": delay,
		"dive_first": dive_first,
		"result": result,
		"catch_s": snappedf(catch_s, 0.01),
		"recover_s": snappedf(recovered_s, 0.01),
		"min_dy": snappedf(min_dy, 0.1),
		"bro_meter": GameManager.bro_meter,
		"accident_count": GameManager.accident_count,
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
		"note": "方案 2 空中救援对比探针：真实按键、自动驾驶代理，不是真人。",
		"trials": rows,
	}
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
		f.close()
