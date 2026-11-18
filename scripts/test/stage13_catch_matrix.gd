extends Node
## FEEL-13 P0-A：BITT 主动救援链路矩阵。
## 覆盖：前方/后方/远距/浅水/深水/水面/水下/障碍路径/窗口将尽/安全无救援。
## 真实物理逐帧推进；每个 case 记录是否真的接住、是否回到 RIDING、最大单帧位移。

const FPS := 60.0
const LevelData = preload("res://scripts/systems/level_data.gd")

var is_runner := false
var race: Node
var rows: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	GameManager.start_race()
	for i in 4:
		await get_tree().process_frame
	race = get_tree().current_scene
	race.test_no_mischief = true
	race.set_physics_process(false)
	race.opening_active = false
	race.test_disable_hazards = true
	race.test_no_lessons = true
	race.test_no_finish = true
	GameManager.test_no_best = true
	race.world_end = 1.0e9
	_case("ahead_far", 800.0, 120.0, 5.0, true, +1)
	_case("behind_near", -240.0, 120.0, 5.0, true, -1)
	_case("shallow", 280.0, 40.0, 5.0, true, +1)
	_case("deep", 280.0, 220.0, 5.0, true, +1)
	_case("deep_down", 280.0, 220.0, 5.0, true, +1, "", 60.0, true)
	_case("from_surface", 280.0, 0.0, 5.0, true, +1)
	_case("underwater", 280.0, 260.0, 5.0, true, +1)
	_case("window_ending", 120.0, 40.0, 0.90, true, +1)
	_case("obstacle_path", 320.0, 120.0, 5.0, true, +1, "LOW_BEAM")
	_case("ahead_30hz", 280.0, 120.0, 5.0, true, +1, "", 30.0)
	_case("ahead_120hz", 280.0, 120.0, 5.0, true, +1, "", 120.0)
	_case("tubo_safe", 280.0, 120.0, 0.0, false, +1)
	var ok := true
	for r in rows:
		ok = ok and bool(r["ok"])
	var f := FileAccess.open("res://docs/reports/longrun/core-feel-13-catch-matrix.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"cases": rows, "ok": ok}, "  "))
	f.close()
	print("CATCH MATRIX: " + ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


func _case(name: String, dx: float, depth: float, window: float,
		expect_catch: bool, direction: int, obstacle: String = "", hz: float = 60.0,
		hold_down: bool = false) -> void:
	var step := 1.0 / hz
	GameManager._reset_run()
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.current_control = "turtle"
	GameManager.shift_lock_t = 0.0
	GameManager.accident_state = "RABBIT_WATER" if expect_catch else "NONE"
	race.test_disable_hazards = obstacle == ""
	var groups := []
	if obstacle != "":
		groups.append(LevelData.build_group({"group": "catch_beam", "zone": 1,
			"kind": obstacle, "x": 1060.0, "w": 170.0}))
	race.load_level(groups, [])
	race.turtle.reset(Vector2(900.0, race.surface_ref()))
	race.turtle.speed = 220.0
	race.turtle.base_speed = 220.0
	race.rabbit.reset()
	if expect_catch:
		race.rabbit.position = Vector2(900.0 + dx, race.surface_ref() + depth)
		race.rabbit.state = "FALLING_WATER"
		race.mount.mark_rescue_active(window)
	else:
		race.rabbit.attach(race.turtle.get_mount_point())
		race.mount.mark_riding()
	race._catch_active = false
	race._catch_t = 0.0
	race.rescue_last_result = ""
	# 上一例可能留下紧急浮出/硬直计时；它到期会把 rabbit.state 强行写成 RIDING，
	# 主动救援会在低帧率下被中途取消（30 Hz 实测）。
	race.emergency_timer = 0.0
	race.rabbit_stun = 0.0
	race.rabbit_grace = 0.0
	race.turtle_grace = 0.0
	# 上一例的上一帧位置如果留在壳边，can_rescue_catch 的线段扫掠会把本帧误判为接住。
	race.rescue_prev_pos = race.rabbit.position
	Input.action_release("pop")
	race._physics_process(step)
	Input.action_press("pop")
	if hold_down:
		Input.action_press("down")
	race._physics_process(step)
	Input.action_release("pop")
	var started := bool(race._catch_active)
	var caught := false
	var riding := false
	var max_step := 0.0
	var prev: Vector2 = race.rabbit.position
	var caught_at := -1
	for i in int(300.0 * hz / 60.0):
		race._physics_process(step)
		var now: Vector2 = race.rabbit.position
		max_step = maxf(max_step, prev.distance_to(now))
		prev = now
		if String(race.rescue_last_result) == "caught" and caught_at < 0:
			caught_at = i
		if caught_at >= 0 and String(race.mount.state) == "RIDING" and i - caught_at >= 3:
			riding = true
			break
		if String(race.rescue_last_result) == "missed" and not expect_catch:
			break
	caught = String(race.rescue_last_result) == "caught"
	if hold_down:
		Input.action_release("down")
	var ok := true
	if expect_catch:
		ok = started and caught and riding and max_step <= 80.0
	else:
		ok = not started and not caught
	rows.append({"case": name, "dx": dx, "depth": depth, "window": window,
		"started": started, "caught": caught, "riding": riding,
		"caught_at": caught_at, "max_step_px": snappedf(max_step, 2.0),
		"final_mount": String(race.mount.state), "ok": ok})
	print("CATCH %-14s started=%s caught=%s riding=%s at=%d maxstep=%.1f final=%s reason=%s timer=%.2f catch_t=%.2f -> %s" % [
		name, str(started), str(caught), str(riding), caught_at, max_step,
		String(race.mount.state), String(race.rescue_last_reason),
		float(race.mount.rescue_timer), float(race._catch_t), "PASS" if ok else "FAIL"])
