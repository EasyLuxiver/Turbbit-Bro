extends Node
## FEEL-32：shark6 固定顺序 Turtle → Rabbit → Turtle：
##   老大（乌龟跃起）→ 胖小弟（兔子趴低）→ 瘦小弟（乌龟下潜）。
## FEEL-49：三只鲨鱼是持续实体；攻击体必须是同一只鱼（is_same），
## 不再是水里三只 + 另一个临时攻击体。同时验证预警、安全间隔和压顶几何。
const LevelData = preload("res://scripts/systems/level_data.gd")
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
	for i in 5:
		await get_tree().process_frame
	race = get_tree().current_scene
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = false
	var g := LevelData.build_group({"group": "shark6", "zone": 3, "kind": "SHARK",
		"x": 1000.0, "w": 70.0, "motion": {"name": "ambush_shark"}})
	g["test_spawned"] = true
	race.load_level([g], [])
	race.turtle.reset(Vector2(850.0, race.surface_ref()))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	GameManager.accident_state = "NONE"
	race.hazard_cooldown = 0.0
	race._shark_pack["shark6"]["phase"] = "CIRCLE"
	race._shark_pack["shark6"]["t"] = 0.0
	race._shark_pack_entry_seen = true

	# 第一段：老大 → 乌龟。三只实体先跟随，0.85 s 后老大进入预警。
	for i in 90:
		race._tick_shark_pack(1.0 / FPS)
		if String(race._shark_pack["shark6"]["phase"]) == "LEAD_LUNGE":
			break
	_check("first_is_leader", String(race._shark_pack["shark6"]["phase"]) == "LEAD_LUNGE"
		and String(race._pack_actor("leader").get("phase", "")) == "WARN",
		"pack=%s leader=%s" % [String(race._shark_pack["shark6"]["phase"]),
			String(race._pack_actor("leader").get("phase", ""))])
	# 等老大完成上冲、压顶、下潜，再进入胖鲨。
	var fat: Dictionary = {}
	var phases: Array = []
	for i in 420:
		race._tick_shark_pack(1.0 / FPS)
		var p := String(race._shark_pack["shark6"]["phase"])
		if phases.is_empty() or phases[-1] != p:
			phases.append(p)
		if String(race._pack_actor("fat").get("phase", "")) in ["RISE", "HOLD", "RETREAT"]:
			fat = race._pack_actor("fat")
			break
	_check("second_is_fat", not fat.is_empty()
		and String(fat.get("target", "")) == "rabbit"
		and String(fat.get("mode", "")) == "fat"
		and phases.has("SAFE1") and phases.has("GAP1"),
		"target=%s mode=%s phases=%s" % [String(fat.get("target", "")),
			String(fat.get("mode", "")), str(phases)])
	_check("pack_has_three_entities", race._pack_actors.size() == 3,
		"actors=%d" % race._pack_actors.size())
	# 攻击体必须就是水里的那一只，不能是另一个临时 actor。
	_check("fat_is_same_entity", not fat.is_empty()
		and fat == race._pack_actor("fat"),
		"same=%s" % str(not fat.is_empty() and fat == race._pack_actor("fat")))
	# 胖鲨：趴低安全，站立命中。攻击帧只在 HOLD；测试直接把实体拨到压顶帧。
	fat["phase"] = "HOLD"
	fat["rect"] = fat["strike_rect"]
	race.rabbit.state = "CROUCHING"
	race.rabbit.position = (fat["rect"] as Rect2).get_center()
	GameManager.accident_state = "NONE"
	race._check_shark_attacks(0.01)
	var crouch_hit: bool = GameManager.accident_state != "NONE"
	race.rabbit.state = "RIDING"
	race.rabbit.position = (fat["rect"] as Rect2).get_center()
	GameManager.accident_state = "NONE"
	race._check_shark_attacks(0.01)
	var stand_hit: bool = GameManager.accident_state != "NONE"
	_check("fat_crouch_safe_stand_hit", not crouch_hit and stand_hit,
		"crouch=%s stand=%s" % [str(crouch_hit), str(stand_hit)])

	# 第三段：瘦小弟 → 乌龟；压顶几何，只有下潜安全。
	race._shark_attacks.clear()
	GameManager.accident_state = "NONE"
	race.turtle.reset(Vector2(850.0, race.surface_ref()))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	race._shark_pack["shark6"]["phase"] = "SAFE2"
	race._shark_pack["shark6"]["t"] = 0.0
	var thin: Dictionary = {}
	for i in 300:
		race._tick_shark_pack(1.0 / FPS)
		if String(race._pack_actor("thin").get("phase", "")) in ["RISE", "HOLD", "RETREAT"]:
			thin = race._pack_actor("thin")
			break
	_check("third_is_thin", not thin.is_empty()
		and String(thin.get("target", "")) == "turtle"
		and String(thin.get("mode", "")) == "thin",
		"target=%s mode=%s" % [String(thin.get("target", "")), String(thin.get("mode", ""))])
	_check("thin_is_same_entity", not thin.is_empty()
		and thin == race._pack_actor("thin"),
		"same=%s" % str(not thin.is_empty() and thin == race._pack_actor("thin")))
	thin["phase"] = "HOLD"
	thin["rect"] = thin["strike_rect"]
	var thin_rect: Rect2 = thin["rect"]
	race.turtle.position = Vector2(thin_rect.get_center().x, thin_rect.end.y + 120.0)
	GameManager.accident_state = "NONE"
	GameManager.last_mistake_role = ""
	race._check_shark_attacks(0.01)
	var dive_safe: bool = GameManager.last_mistake_role != "turtle"
	race.turtle.position = thin_rect.get_center()
	GameManager.accident_state = "NONE"
	GameManager.last_mistake_role = ""
	race._check_shark_attacks(0.01)
	var cruise_hit: bool = GameManager.last_mistake_role == "turtle"
	race._shark_attacks.clear()
	race._shark_attacks.append(thin.duplicate())
	race.turtle.position = Vector2(thin_rect.get_center().x, thin_rect.position.y + 40.0)
	GameManager.accident_state = "NONE"
	GameManager.last_mistake_role = ""
	race._check_shark_attacks(0.01)
	var leap_hit: bool = GameManager.last_mistake_role == "turtle"
	_check("thin_dive_only", dive_safe and cruise_hit and leap_hit,
		"dive=%s cruise=%s leap=%s" % [str(dive_safe), str(cruise_hit), str(leap_hit)])

	# 救援清理。
	race._shark_attacks.clear()
	race._shark_pack["shark6"]["phase"] = "GAP2"
	GameManager.accident_state = "RABBIT_WATER"
	race.rabbit.state = "FALLING_WATER"
	race.mount.mark_rescue_active(3.2)
	race._tick_shark_pack(1.0 / FPS)
	_check("rescue_clears_pack", race._shark_pack["shark6"]["phase"] == "CIRCLE"
		and race._shark_attacks.is_empty(),
		"phase=%s attacks=%d" % [String(race._shark_pack["shark6"]["phase"]),
			race._shark_attacks.size()])

	# 看台。
	GameManager.accident_state = "NONE"
	race.rabbit.state = "RIDING"
	race.mount.mark_riding()
	race._shark_attacks.clear()
	race._shark_pack["shark6"]["phase"] = "RETREAT"
	race._shark_pack["shark6"]["t"] = 1.0
	race._tick_shark_pack(1.0 / FPS)
	_check("pack_no_stands", race._shark_stands_t <= 0.0,
		"stands=%.1f" % race._shark_stands_t)

	# 正式 Z3 组存在并能推进到第一段跟随攻击。
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	var z3: Dictionary = {}
	for zg in race.hazard_groups:
		if String(zg.get("group", "")) == "shark6":
			z3 = zg
	_check("z3_shark6_present", not z3.is_empty(), "found=%s" % str(not z3.is_empty()))
	if not z3.is_empty():
		var z3_start: float = race._group_start(z3)
		race.turtle.reset(Vector2(z3_start - 120.0, race.surface_ref()))
		race.rabbit.reset()
		race.rabbit.attach(race.turtle.get_mount_point())
		race.mount.reset()
		race.mount.mark_riding()
		GameManager.accident_state = "NONE"
		race._shark_pack["shark6"]["phase"] = "CIRCLE"
		race._shark_pack["shark6"]["t"] = 0.0
		race._shark_pack_entry_seen = true
		race._pack_reset_actors()
		var attack_seen := false
		for i in 420:
			race._tick_shark_pack(1.0 / FPS)
			if not race._shark_attacks.is_empty():
				attack_seen = true
				break
		_check("z3_pack_attacks", attack_seen,
			"phase=%s attacks=%d" % [String(race._shark_pack["shark6"]["phase"]),
				race._shark_attacks.size()])

	# FEEL-49：随机摧毁障碍的“鲨群介入”已移除。
	_check("shark_intervention_removed", not race.has_method("trigger_shark_intervention"),
		"method=%s" % str(race.has_method("trigger_shark_intervention")))
	_write()
	get_tree().quit(0 if checks.all(func(c): return bool(c["ok"])) else 1)


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var f := FileAccess.open("res://docs/reports/longrun/core-feel-21-shark-pack.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks}, "  "))
	f.close()
