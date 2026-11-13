extends Node
## TBB-EXPERIENCE-REBUILD-05 G8：接人提示环（落壳走廊）的验收探针。
##
## 背景：PLAYFUL-04 把落壳改成“进 -60 px 当帧吸附”，同时把 pickup_window 清掉，
## 于是绿环/「接住了！」只在被消费的那一帧为 true——16 ms 一闪，玩家看不见，
## stage1 的 “pickup window shown during landing” 也因此 FAIL。
## G8 把“显示”和“收人”分开：显示是 -150 px 起的落壳走廊，收人仍是 -60 当帧吸附。
##
## 验：
##   1) 普通跳跃下落段 pickup_window 连续为 true 至少 6 帧，且起点在 -60 以上（提前量）；
##   2) 上升段不亮（vy < 0），落壳照旧 +1；
##   3) 乌龟下潜且未上浮时兔子落水：全程不亮，仍记 RABBIT_WATER；
##   4) 深接（壳在水下上浮）仍走 _begin_carry 连续抬升，不瞬移。
##
## 输出：docs/reports/longrun/rebuild05-g8-corridor.json
## 运行：godot --headless --path TURBBIT res://scenes/stage5_g8_corridor.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/rebuild05-g8-corridor.json"
const STEP := 1.0 / 60.0

var is_runner := false
var race: Node = null
var out := {}
var failures: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage5G8CorridorRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	Locale.language = "zh"
	GameManager.start_race()
	for i in 4:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null:
		push_error("G8 CORRIDOR: no race")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()

	out["generated_at"] = Time.get_datetime_string_from_system()
	out["plain_jump"] = _plain_jump()
	out["diving_water"] = _diving_water()
	out["deep_catch"] = _deep_catch()
	_evaluate()
	_write()
	print("G8 CORRIDOR: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


## a) 普通跳跃：起跳 -> 上升 -> 下落 -> 落壳。数窗口连续帧与起点高度。
func _plain_jump() -> Dictionary:
	_reset(200.0)
	var pickup_before: int = GameManager.pickup_count
	Input.action_press("up")
	race._note_up_input()
	var run := 0
	var max_run := 0
	var first_dy := 0.0
	var window_on_rising := 0
	var jumped := false
	var landed := false
	var landing_dy := 0.0
	var landing_window := false
	for i in 180:
		race._physics_process(STEP)
		if i == 2:
			Input.action_release("up")
		var mp: Vector2 = race.turtle.get_mount_point()
		var dy: float = race.rabbit.position.y - mp.y
		var rising: bool = float(race.rabbit.velocity.y) < 0.0
		var w: bool = GameManager.pickup_window
		if String(race.mount.state) == "AIRBORNE":
			jumped = true
			if w:
				if run == 0:
					first_dy = dy
				run += 1
				max_run = maxi(max_run, run)
				if rising:
					window_on_rising += 1
			else:
				run = 0
		elif jumped and String(race.mount.state) == "RIDING":
			landed = true
			landing_dy = dy
			landing_window = w
			break
	return {
		"jumped": jumped,
		"landed": landed,
		"max_consecutive_window_frames": max_run,
		"first_true_dy": snappedf(first_dy, 0.1),
		"window_frames_while_rising": window_on_rising,
		"landing_dy": snappedf(landing_dy, 0.1),
		"landing_window": landing_window,
		"pickup_count_delta": GameManager.pickup_count - pickup_before,
	}


## b) 壳在水下且没在上浮：兔子从上方落水，不能显示“能接住”。
func _diving_water() -> Dictionary:
	_reset(200.0)
	GameManager.toggle_control()
	# 一直按住 ↓：壳停在最大下潜深度、没有上浮，整段都不该亮环。
	Input.action_press("down")
	for i in 45:
		race._physics_process(STEP)
	var mp: Vector2 = race.turtle.get_mount_point()
	var at_surface: bool = race.turtle.is_at_surface()
	var rising: bool = race.turtle.is_rising()
	race.rabbit.position = mp + Vector2(0.0, -140.0)
	race.rabbit.velocity = Vector2(0.0, 120.0)
	race.mount.mark_airborne()
	var window_frames := 0
	var accident := ""
	var accident_frames := 0
	for i in 150:
		race._physics_process(STEP)
		if GameManager.pickup_window:
			window_frames += 1
		if GameManager.accident_state == "RABBIT_WATER":
			accident = "RABBIT_WATER"
			accident_frames = i
			break
	Input.action_release("down")
	return {
		"turtle_at_surface": at_surface,
		"turtle_rising": rising,
		"window_true_frames": window_frames,
		"accident": accident,
		"accident_frame": accident_frames,
	}


## c) 深接：壳在水下正在上浮，兔子在壳上方 100 px 落下来，应走连续抬升。
func _deep_catch() -> Dictionary:
	_reset(200.0)
	GameManager.toggle_control()
	Input.action_press("down")
	for i in 45:
		race._physics_process(STEP)
	Input.action_release("down")
	var rising_frames := 0
	while rising_frames < 20 and not race.turtle.is_rising():
		race._physics_process(STEP)
		rising_frames += 1
	var mp: Vector2 = race.turtle.get_mount_point()
	var at_surface: bool = race.turtle.is_at_surface()
	var rising: bool = race.turtle.is_rising()
	var drop_dy := -100.0
	race.rabbit.position = mp + Vector2(0.0, drop_dy)
	race.rabbit.velocity = Vector2(0.0, 160.0)
	race.mount.mark_airborne()
	var distance_before: float = race.rabbit.position.distance_to(race.turtle.get_mount_point())
	var carry_started_frame := -1
	var carry_frames := 0
	var pickup_before: int = GameManager.pickup_count
	for i in 120:
		race._physics_process(STEP)
		if carry_started_frame < 0 and String(race.mount.state) == "CARRYING":
			carry_started_frame = i
		if carry_started_frame >= 0 and String(race.mount.state) == "CARRYING":
			carry_frames += 1
		if carry_started_frame >= 0 and String(race.mount.state) == "RIDING":
			break
	var distance_after: float = race.rabbit.position.distance_to(race.turtle.get_mount_point())
	return {
		"turtle_at_surface": at_surface,
		"turtle_rising": rising,
		"rising_wait_frames": rising_frames,
		"drop_dy": drop_dy,
		"distance_before": snappedf(distance_before, 0.1),
		"distance_after": snappedf(distance_after, 0.1),
		"carry_started_frame": carry_started_frame,
		"carry_frames": carry_frames,
		"mount": String(race.mount.state),
		"pickup_count_delta": GameManager.pickup_count - pickup_before,
	}


func _evaluate() -> void:
	var pj: Dictionary = out["plain_jump"]
	_expect("plain jump: the landing corridor stays on for a stretch (%d frames, from dy %.1f)"
		% [int(pj["max_consecutive_window_frames"]), float(pj["first_true_dy"])],
		int(pj["max_consecutive_window_frames"]) >= 6)
	_expect("plain jump: the ring starts before the snap zone (%s dy), not at the catch frame"
		% str(pj["first_true_dy"]),
		float(pj["first_true_dy"]) <= -60.0
			and float(pj["first_true_dy"]) >= Tuning.PICKUP_HINT_DY_MIN)
	_expect("plain jump: nothing lights up while the rabbit is rising (%s frames)"
		% str(pj["window_frames_while_rising"]),
		int(pj["window_frames_while_rising"]) == 0)
	_expect("plain jump: still lands and counts (%s)"
		% str(pj["pickup_count_delta"]),
		bool(pj["jumped"]) and bool(pj["landed"])
			and int(pj["pickup_count_delta"]) == 1)
	var dw: Dictionary = out["diving_water"]
	_expect("diving shell: no catch hint while underwater and not rising (%s frames)"
		% str(dw["window_true_frames"]),
		not bool(dw["turtle_at_surface"]) and not bool(dw["turtle_rising"])
			and int(dw["window_true_frames"]) == 0)
	_expect("diving shell: the rabbit still counts as falling in water (%s)"
		% str(dw["accident"]),
		String(dw["accident"]) == "RABBIT_WATER")
	var dc: Dictionary = out["deep_catch"]
	_expect("deep catch: the shell is underwater and rising (%s / %s)"
		% [str(dc["turtle_at_surface"]), str(dc["turtle_rising"])],
		not bool(dc["turtle_at_surface"]) and bool(dc["turtle_rising"]))
	_expect("deep catch: still lifted over several frames, not snapped in one (%s frames)"
		% str(dc["carry_frames"]),
		int(dc["carry_started_frame"]) >= 0 and int(dc["carry_frames"]) >= 2)
	_expect("deep catch: the rabbit ends up on the shell and counts (%s)"
		% str(dc["pickup_count_delta"]),
		String(dc["mount"]) == "RIDING" and int(dc["pickup_count_delta"]) == 1)


func _expect(label: String, ok: bool) -> void:
	if not ok:
		failures.append(label)


func _reset(x: float) -> void:
	var zone: Dictionary = LevelData.zone_at(x)
	Input.action_release("up")
	Input.action_release("down")
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.oxygen = Tuning.OXYGEN_MAX
	GameManager.oxygen_phase = "SAFE"
	GameManager.accident_count = 0
	GameManager.showtime_active = false
	GameManager.clear_bro_meter()
	GameManager.current_control = "rabbit"
	GameManager.has_shifted = false
	GameManager.combo = 0
	GameManager.pickup_window = false
	race.showtime_active = false
	race.showtime_t = 0.0
	race.joint_show_t = 0.0
	race.finishing = false
	race.hazard_cooldown = 0.0
	race.accident_flash = 0.0
	race._accident_t = 0.0
	race.turtle_repair = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.rabbit_stun = 0.0
	race.emergency_timer = 0.0
	race.combo = 0
	race.combo_max = 0
	race.celebrate_t = -1.0
	race.celebrate_kind = ""
	race.carry_kind = ""
	race.carry_dur = 0.0
	race.carry_t = 0.0
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.group_actions.clear()
	race.input_buffer_log.clear()
	race.reset_brains()
	race.current_zone = zone
	race.world_end = 1.0e9
	race.turtle.reset(Vector2(x, Tuning.NEUTRAL_DEPTH))
	race.turtle.base_speed = float(zone["base_speed"])
	race.turtle.speed = float(zone["base_speed"])
	race.turtle.speed_cap = 1.0e9
	race.turtle.daze_time = 0.0
	race.turtle.drift = 0.0
	race.turtle.dunk_timer = 0.0
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	race.rabbit.state = "RIDING"
	race._buf_action = ""
	race._buf_age = 0.0


func _write() -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f == null:
		push_error("G8 CORRIDOR: cannot write " + OUT_PATH)
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()
