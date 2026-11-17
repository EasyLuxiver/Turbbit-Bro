extends Node
## FEEL-15：红白浮标 / 木质动态障碍的“画到 BITT 身上就必须有反馈”。
## 只测判定一致性：同一 hazard_rect_live 既画也判。

const LevelData = preload("res://scripts/systems/level_data.gd")
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
	for i in 5:
		await get_tree().process_frame
	race = get_tree().current_scene
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = false
	var buoy := LevelData.build_group({"group": "test_buoy", "zone": 1,
		"kind": "SURFACE_ROCK", "x": 1000.0, "w": 120.0, "identity": "buoy",
		"motion": {"name": "tide_rock", "axis": "y", "amp": 52.0, "period": 3.6}})
	var crate := LevelData.build_group({"group": "test_crate", "zone": 1,
		"kind": "SURFACE_ROCK", "x": 1000.0, "w": 120.0, "identity": "dock_crate",
		"motion": {"name": "tide_rock", "axis": "y", "amp": 52.0, "period": 3.6}})
	# 1) 浮标浪峰：视觉矩形压到龟壳，必须产生乌龟碰撞。
	_case(buoy, 0.9, true, "buoy_high_hits_turtle")
	# 2) 浮标浪谷：矩形在龟壳上方，BITT 正常过。
	_case(buoy, 2.7, false, "buoy_low_lets_turtle_pass")
	# 3) 木质吊箱同样：浪峰必须反馈，不能只画不判。
	_case(crate, 0.9, true, "crate_high_hits_turtle")
	# 4) 静态岩不误伤乌龟（原设计：壳从下面过）。
	var rock := LevelData.build_group({"group": "test_rock", "zone": 1,
		"kind": "SURFACE_ROCK", "x": 1000.0, "w": 120.0, "identity": "sea_rock"})
	_case(rock, 0.9, false, "static_rock_does_not_hit_turtle")
	_write()
	get_tree().quit(0 if checks.all(func(c): return bool(c["ok"])) else 1)


func _case(group: Dictionary, clock: float, expect_turtle: bool, name: String) -> void:
	GameManager.accident_state = "NONE"
	GameManager.clear_bro_meter()
	GameManager.current_control = "turtle"
	race.load_level([group], [])
	race.hazard_clock = clock
	race.hit_roles.clear()
	race.hit_groups.clear()
	race._dynamic_bump_cd.clear()
	race.turtle.reset(Vector2(1000.0, race.surface_ref()))
	race.turtle.speed = 240.0
	race.turtle.accident = false
	race.turtle.flip_lock = 0.0
	race.rabbit.reset()
	race.rabbit.state = "JUMPING"
	race.rabbit.velocity = Vector2(0.0, -120.0)
	race.rabbit.position = race.turtle.get_mount_point() + Vector2(0, -300)
	race.mount.mark_riding()
	race.hazard_cooldown = 0.0
	var live: Rect2 = race.hazard_rect_live(group, 0)
	var t_rect: Rect2 = race.turtle.get_body_rect()
	var visual_overlap := t_rect.intersects(live)
	race._check_hazards()
	var bumped: bool = race._dynamic_bump_cd.has(String(group["group"]))
	_check(name, bumped == expect_turtle and visual_overlap == expect_turtle,
		"bumped=%s visual_overlap=%s rect=%s body=%s" % [
			str(bumped), str(visual_overlap), str(live), str(t_rect)])
	# 错误处理必须有可见后果：减速/摇晃至少一个；但不升级成事故/扣格。
	if expect_turtle:
		_check(name + "_feedback", race.turtle.speed < 240.0,
			"speed=%.1f hit_roles=%s" % [race.turtle.speed,
				str(race.hit_roles.get(String(group["group"]), {}))])
		_check(name + "_visible_reaction", race.turtle.dunk_timer > 0.0,
			"dunk_timer=%.2f" % race.turtle.dunk_timer)


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var f := FileAccess.open("res://docs/reports/longrun/core-feel-15-dynamic-buoy.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks}, "  "))
	f.close()
