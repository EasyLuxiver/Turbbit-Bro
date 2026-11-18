extends Node
## 制作人质检：混合物理的落礁石/滚落 + 乌龟跳撞低梁。

const LevelData = preload("res://scripts/systems/level_data.gd")

var is_runner := false
var race: Node
var failures: Array[String] = []


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
	race.test_disable_hazards = true
	race.load_level([], [])
	race.test_no_mischief = true

	# 1) 礁石顶面：从上方落下 -> 站上/滚动 -> 边缘掉下。
	var rock: Dictionary = LevelData.build_group({"group": "perch_rock",
		"zone": 1, "kind": "SURFACE_ROCK", "x": 1200.0, "w": 220.0})
	race.hazard_groups = [rock]
	var rr: Rect2 = rock["rects"][0]
	race.turtle.reset(Vector2(900.0, race.surface_ref()))
	race.rabbit.reset()
	race.rabbit.position = Vector2(rr.position.x + 60.0, rr.position.y - 22.0)
	race.rabbit.velocity = Vector2(0.0, 400.0)
	race.rabbit.state = "FALLING"
	race.mount.mark_airborne()
	var landed: bool = race._try_rock_landing("perch_rock", rr,
		race.rabbit.get_body_rect())
	_check("rock_landing_starts", landed and race._rock_perch_active,
		"landed=%s active=%s" % [str(landed), str(race._rock_perch_active)])
	_check("rock_landing_on_top", absf(race.rabbit.position.y
		- (rr.position.y - race.rabbit.get_body_rect().size.y * 0.5)) < 1.0,
		"rabbit_y=%.1f top=%.1f" % [race.rabbit.position.y, rr.position.y])
	race._tick_rock_perch(0.20)
	_check("rock_rolls_forward", race.rabbit.position.x > rr.position.x + 60.0,
		"x=%.1f" % race.rabbit.position.x)
	race._tick_rock_perch(0.30)
	_check("rock_hops_off", not race._rock_perch_active
		and race.rabbit.velocity.y < 0.0,
		"active=%s vy=%.1f" % [str(race._rock_perch_active),
			race.rabbit.velocity.y])
	# 从侧面/内部进石头时，兔子要被推出去，不能卡住。
	race.hazard_groups = [rock]
	race.rabbit.position = rr.get_center()
	race.rabbit.state = "FALLING"
	race._rock_perch_active = false
	race.test_disable_hazards = false
	race._resolve_rabbit_solid()
	_check("rabbit_pushed_out", not race.rabbit.get_body_rect().intersects(rr),
		"rabbit=%s rect=%s" % [str(race.rabbit.get_body_rect()), str(rr)])

	# 2) 乌龟跳撞低梁：A 类也要有碰撞/弹回反馈。
	var beam: Dictionary = LevelData.build_group({"group": "tower_beam",
		"zone": 1, "kind": "LOW_BEAM", "x": 1600.0, "w": 220.0})
	race.hazard_groups = [beam]
	var br: Rect2 = beam["rects"][0]
	race._bonk_streak = 0
	race._bounce_cd = 0.0
	race._bonk_anim_active = false
	race.turtle.reset(Vector2(br.position.x + br.size.x * 0.5,
		br.position.y + br.size.y * 0.5))
	race.turtle.leap_active = true
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.mark_riding()
	race.test_disable_hazards = false
	race._check_hazards()
	_check("turtle_lowbeam_reacts", race._bonk_streak >= 1
		or race._bonk_anim_active,
		"streak=%d bonk=%s" % [race._bonk_streak,
			str(race._bonk_anim_active)])

	# 3) 两人都记过 roles 后，高墙仍必须继续判定/弹回，不能变霸体。
	var wall: Dictionary = LevelData.build_group({"group": "test_wall",
		"zone": 1, "kind": "HIGH_WALL", "x": 2200.0, "w": 180.0})
	race.hazard_groups = [wall]
	var wr: Rect2 = wall["rects"][0]
	race._bonk_streak = 0
	race._bounce_cd = 0.0
	race._bonk_anim_active = false
	race.hit_roles["test_wall"] = {"rabbit": true, "turtle": true}
	race.turtle.reset(Vector2(wr.position.x + wr.size.x * 0.5,
		wr.position.y + wr.size.y * 0.5))
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.mark_riding()
	race.test_disable_hazards = false
	race._check_hazards()
	_check("both_roles_still_block", race._bonk_streak >= 1
		or race._bonk_anim_active,
		"streak=%d bonk=%s" % [race._bonk_streak,
			str(race._bonk_anim_active)])

	# 4) 联合判罚只冻结，不许把兔子瞬移回龟壳。
	race.rabbit.position = Vector2(1100.0, 180.0)
	race.turtle.position = Vector2(900.0, race.surface_ref())
	race._start_joint_show()
	race._hold_joint_pose()
	race._end_joint_show()
	_check("joint_no_teleport", absf(race.rabbit.position.x - 1100.0) < 1.0
		and absf(race.rabbit.position.y - 180.0) < 12.0,
		"rabbit=%s" % str(race.rabbit.position))

	# 普通二连跳：乌龟在下面就自动接，不需要再切乌龟/按 SPACE。
	race.hazard_groups = []
	race.test_disable_hazards = true
	GameManager.accident_state = "NONE"
	GameManager.current_control = "rabbit"
	race._sleep_fall_requires_space = false
	race._sleep_lock_catch = false
	race.turtle.reset(Vector2(900.0, race.surface_ref()))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	race.turtle.speed = 0.0
	race.turtle.base_speed = 0.0
	race.rabbit.launch(race.turtle.get_mount_point(), 0.0, 0.0)
	race.mount.mark_airborne()
	var caught := false
	for i in 240:
		race._tick_rabbit(1.0 / 60.0, false, false)
		if race.rabbit.state == "RIDING" and race.mount.state == "RIDING":
			caught = true
			break
	_check("normal_jump_auto_catch", caught,
		"rabbit=%s mount=%s" % [race.rabbit.state, race.mount.state])

	print("STAGE57 PHYSICS: " + ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		print("  ok   " + name + "  " + detail)
	else:
		failures.append(name)
		print("  FAIL " + name + "  " + detail)
