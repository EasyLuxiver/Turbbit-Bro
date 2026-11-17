extends Node
## FEEL-29 任务B：BRO DIVE 接应过程的位置连续性探针。
## 只记录，不改玩法：接住抬升期间兔子每帧的 x/y 位移，找出回拉与突变。

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

var is_runner := false
var race: Node = null
var sim := 0.0
var hz := 60.0
var rows: Array = []

const GROUP_NAME := "log3"
const LEADS := [140.0, 160.0, 180.0]
const DELAYS := [0.0, 0.15, 0.30]
const RIGHT_HELD := [false, true]


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 8.0
	Engine.physics_ticks_per_second = int(hz * Engine.time_scale)
	await get_tree().process_frame
	await _run()


func _run() -> void:
	GameManager.start_race()
	for i in 3:
		await get_tree().process_frame
	race = get_tree().current_scene
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()
	await get_tree().physics_frame
	var group: Dictionary = {}
	for g in race.hazard_groups:
		if String(g["group"]) == GROUP_NAME:
			group = g
			break
	if group.is_empty():
		push_error("no " + GROUP_NAME)
		get_tree().quit(1)
		return
	var start: float = race._group_start(group)
	var end: float = race._group_end(group)
	var zone: Dictionary = LevelData.zone_at(start)
	print("DIVE HANDOFF group=%s start=%.0f end=%.0f" % [GROUP_NAME, start, end])
	for lead in LEADS:
		for delay in DELAYS:
			for right in RIGHT_HELD:
				var r := await _case(group, lead, delay, right, start, end, zone)
				rows.append(r)
				print(JSON.stringify(r))
	_write()
	var bad := rows.filter(func(r): return bool(r["back_px"] > 2.0) or bool(r["water"]))
	print("DIVE HANDOFF: rows=%d bad=%d" % [rows.size(), bad.size()])
	get_tree().quit(0 if bad.is_empty() else 1)


func _case(g: Dictionary, lead: float, delay: float, right: bool,
		start: float, end: float, zone: Dictionary) -> Dictionary:
	_reset(start - lead, zone)
	var t0 := sim
	var jumped := false
	var jumped_t := -1.0
	var shifted := false
	var down_held := false
	var prev_x: float = race.rabbit.position.x
	var prev_y: float = race.rabbit.position.y
	var last_state := ""
	var carry_frames := 0
	var back_px := 0.0
	var back_max := 0.0
	var step_max := 0.0
	var catch_dx := 0.0
	var catch_dy := 0.0
	var water := false
	var accident := false
	var rabbit_hit := false
	var turtle_hit := false
	var score0: int = GameManager.total_score
	var steps := 0
	if right:
		Input.action_press("right")
	while sim - t0 < 6.0 and steps < 900:
		var x: float = race.turtle.position.x
		if x > end + 240.0:
			break
		if not jumped and x >= start - lead:
			_control("rabbit")
			_press("up")
			jumped = true
			jumped_t = sim
		elif jumped and not shifted and sim - jumped_t >= delay - 0.001:
			if race.mount.state == "AIRBORNE":
				_release("up")
				_control("turtle")
				_press("down")
				shifted = true
				down_held = true
			elif sim - jumped_t > delay + 0.20:
				shifted = true
		await _step()
		steps += 1
		var state: String = race.mount.state
		if state == "CARRYING":
			carry_frames += 1
			if DisplayServer.get_name() != "headless" and lead == 160.0 \
					and delay == 0.15 and right:
				if carry_frames == 1:
					await _shot("dive-catch-1920")
				elif carry_frames == 8:
					await _shot("dive-carry-mid-1920")
			if last_state != "CARRYING":
				var mp: Vector2 = race.turtle.get_mount_point()
				catch_dx = race.rabbit.position.x - mp.x
				catch_dy = race.rabbit.position.y - mp.y
			var dx: float = race.rabbit.position.x - prev_x
			var dy: float = race.rabbit.position.y - prev_y
			if dx < -0.05:
				back_px += -dx
				back_max = maxf(back_max, -dx)
			step_max = maxf(step_max, Vector2(dx, dy).length())
		prev_x = race.rabbit.position.x
		prev_y = race.rabbit.position.y
		last_state = state
		if GameManager.accident_state != "NONE":
			accident = true
			if GameManager.accident_state == "RABBIT_WATER":
				water = true
		var rrect: Rect2 = race.rabbit.get_body_rect()
		var trect: Rect2 = race.turtle.get_body_rect()
		for rr in g["rects"]:
			var rect: Rect2 = rr
			if rect.grow(-3.0).intersects(rrect):
				rabbit_hit = true
			if rect.grow(-3.0).intersects(trect):
				turtle_hit = true
		if down_held and race.turtle.position.x >= end:
			_release("down")
			down_held = false
	_release_all()
	if DisplayServer.get_name() != "headless" and lead == 160.0 \
			and delay == 0.15 and right:
		await _shot("dive-after-1920")
	var passed: bool = race.turtle.position.x > end + 150.0 \
		and race.mount.state == "RIDING" \
		and not bool(race.hit_groups.has(String(g["group"])))
	return {
		"lead": lead, "delay": delay, "right": right,
		"passed": passed, "water": water, "accident": accident,
		"rabbit_hit": rabbit_hit, "turtle_hit": turtle_hit,
		"carry_frames": carry_frames,
		"catch_dx": snappedf(catch_dx, 0.1),
		"catch_dy": snappedf(catch_dy, 0.1),
		"back_px": snappedf(back_px, 0.1),
		"back_max": snappedf(back_max, 0.1),
		"step_max": snappedf(step_max, 0.1),
		"score_delta": GameManager.total_score - score0,
	}


func _reset(x: float, zone: Dictionary) -> void:
	_release_all()
	GameManager.accident_state = "NONE"
	GameManager.oxygen = Tuning.OXYGEN_MAX
	GameManager.current_control = "turtle"
	GameManager.has_shifted = true
	race.showtime_active = false
	race.hazard_cooldown = 0.0
	race.turtle_repair = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.rabbit_stun = 0.0
	race.emergency_timer = 0.0
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.group_actions.clear()
	race.reset_brains()
	race.current_zone = zone
	race.turtle.reset(Vector2(x, Tuning.NEUTRAL_DEPTH))
	race.turtle.speed = float(zone["base_speed"])
	race.turtle.base_speed = float(zone["base_speed"])
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()


func _control(who: String) -> void:
	if GameManager.current_control != who:
		GameManager.set_control(who)


func _press(action: String) -> void:
	if not Input.is_action_pressed(action):
		Input.action_press(action)


func _release(action: String) -> void:
	if Input.is_action_pressed(action):
		Input.action_release(action)


func _release_all() -> void:
	for a in ["up", "down", "right", "left", "shift"]:
		Input.action_release(a)


func _step() -> void:
	await get_tree().physics_frame
	sim += 1.0 / hz


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://docs/reports/longrun/feel29")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("CAPTURE ", name)


func _write() -> void:
	var path := ProjectSettings.globalize_path("res://docs/reports/longrun/feel29-dive-handoff.json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"cases": rows}, "  "))
		f.close()
