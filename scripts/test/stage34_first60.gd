extends Node
## FEEL-34：前 60 秒接力审计。
## 记录第一个 FLOATING_LOG 的时间，并验证单角色绕不过、BRO DIVE 才能过。
const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")
const FPS := 60.0
var is_runner := false
var race: Node
var checks: Array = []


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
	GameManager.test_no_best = true
	GameManager.start_race()
	for i in 4:
		await get_tree().process_frame
	race = get_tree().current_scene
	race.test_no_mischief = true
	race.opening_active = false
	race.test_no_finish = true
	race.test_no_bird_behaviors = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	var log1: Dictionary = {}
	var wall1: Dictionary = {}
	for g in race.hazard_groups:
		if String(g.get("group", "")) == "log1":
			log1 = g
		if String(g.get("group", "")) == "wall1":
			wall1 = g
	if log1.is_empty() or wall1.is_empty():
		_check("level_groups", false, "log1/wall1 missing")
		get_tree().quit(1)
		return
	var z1: Dictionary = LevelData.zone_at(race._group_start(log1))
	var speed: float = float(z1["base_speed"])
	var t_log: float = (race._group_start(log1) - LevelData.RACE_START_X) / speed
	var t_wall: float = (race._group_start(wall1) - LevelData.RACE_START_X) / speed
	print("FIRST60 log1=%.1fs wall1=%.1fs speed=%.0f" % [t_log, t_wall, speed])
	_check("log1_within_60", t_log <= 60.0, "log1=%.1fs" % t_log)
	var rabbit_only := await _case(log1, "rabbit_only", false)
	var turtle_only := await _case(log1, "turtle_only", false)
	var dive := await _case(log1, "bro_dive", true)
	# FEEL-47：浮木缩到 215 后，乌龟单潜也能通过；保留兔子单跳过不去，
	# BRO DIVE 仍是更稳的解法，但不再要求“单乌龟必须失败”。
	_check("single_rabbit_cannot_pass", not bool(rabbit_only["passed"]),
		"rabbit=%s turtle=%s" % [str(rabbit_only["passed"]), str(turtle_only["passed"])])
	_check("bro_dive_passes", bool(dive["passed"]), JSON.stringify(dive))
	_write()
	var ok: bool = checks.all(func(c): return bool(c["ok"]))
	print("FIRST60: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _case(g: Dictionary, mode: String, relay: bool) -> Dictionary:
	var start: float = race._group_start(g)
	var end: float = race._group_end(g)
	var zone: Dictionary = LevelData.zone_at(start)
	_reset(start - 160.0, zone)
	var jumped := false
	var shifted := false
	var down := false
	var t0 := 0.0
	var sim := 0.0
	var accident := false
	while sim < 5.0:
		var x: float = race.turtle.position.x
		if x > end + 220.0:
			break
		if mode == "rabbit_only":
			_control("rabbit")
			if not jumped and x >= start - 160.0:
				_press("up")
				jumped = true
		elif mode == "turtle_only":
			_control("turtle")
			if not down and x >= start - 160.0:
				_press("down")
				down = true
		else:
			if not jumped and x >= start - 160.0:
				_control("rabbit")
				_press("up")
				jumped = true
			elif jumped and not shifted and x >= start - 100.0:
				_release("up")
				_control("turtle")
				_press("down")
				shifted = true
		await get_tree().physics_frame
		sim += 1.0 / FPS
		if GameManager.accident_state != "NONE":
			accident = true
		if down and x >= end:
			_release("down")
		if shifted and x >= end:
			_release("down")
	_release_all()
	var riding: bool = race.mount.state == "RIDING"
	var hit: bool = race.hit_groups.has(String(g["group"]))
	return {"mode": mode, "passed": riding and not accident and not hit,
		"riding": riding, "accident": accident, "hit": hit,
		"accident_state": GameManager.accident_state,
		"hit_roles": race.hit_roles.get(String(g["group"]), {}),
		"turtle_y": race.turtle.position.y, "rabbit_y": race.rabbit.position.y}


func _reset(x: float, zone: Dictionary) -> void:
	_release_all()
	GameManager.accident_state = "NONE"
	GameManager.oxygen = Tuning.OXYGEN_MAX
	GameManager.current_control = "rabbit"
	GameManager.has_shifted = true
	race.showtime_active = false
	race.hazard_cooldown = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.hit_groups.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.group_actions.clear()
	race.current_zone = zone
	race.turtle.reset(Vector2(x, race.surface_ref()))
	race.turtle.speed = float(zone["base_speed"])
	race.turtle.base_speed = float(zone["base_speed"])
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()


func _control(who: String) -> void:
	if GameManager.current_control != who:
		GameManager.set_control(who)


func _press(a: String) -> void:
	if not Input.is_action_pressed(a):
		Input.action_press(a)


func _release(a: String) -> void:
	if Input.is_action_pressed(a):
		Input.action_release(a)


func _release_all() -> void:
	for a in ["up", "down", "left", "right", "shift"]:
		Input.action_release(a)


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var f := FileAccess.open("res://docs/reports/longrun/feel34-first60.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"checks": checks}, "  "))
		f.close()
