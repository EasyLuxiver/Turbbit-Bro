extends Node
## FEEL-19 P1-A：海鸟额外行为（排泄/回马枪/追逐）的预兆、攻击、判定、恢复、电弧抵消。

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
	race.test_no_mischief = true
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = false
	# 制作人质检：远程便便已撤掉，只保留俯冲；不再断言排泄攻击。
	# FEEL-49：鸟已经飞过/拉起后，固定判定带不能再伤人。
	_bird_pass_no_hit()
	# 种子可复现 + 相邻遭遇不重复同一行为序列。
	_plan_repro()
	_write()
	get_tree().quit(0 if checks.all(func(c): return bool(c["ok"])) else 1)


func _group(name: String) -> Dictionary:
	return LevelData.build_group({"group": name, "zone": 1, "kind": "LOW_BIRD",
		"x": 1000.0, "w": 120.0})


func _setup(name: String, target: String) -> void:
	race.load_level([_group(name)], [])
	race.turtle.reset(Vector2(900.0, race.surface_ref()))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	if target == "turtle":
		race.rabbit.position.x = 600.0
	else:
		race.turtle.position.x = 600.0
	var forced := {"bird3": "poop", "bird4": "poop", "bird6": "poop"}
	if forced.has(name):
		race._bird_states[name]["queue"] = [forced[name]]
		race._bird_states[name]["idx"] = 0
		race._bird_states[name]["mode"] = forced[name]
	race._bird_states[name]["target"] = target
	race._bird_states[name]["phase"] = "WAIT"
	race._bird_states[name]["t"] = 0.0
	race._bird_attacks.clear()
	GameManager.accident_state = "NONE"
	race.hazard_cooldown = 0.0
	race.turtle.flip_lock = 0.0
	race.turtle.speed = 220.0


func _behavior_case(name: String, mode: String, target: String, seconds: float) -> void:
	_setup(name, target)
	var phases := []
	for i in int(seconds * FPS):
		race._tick_bird_behaviors(1.0 / FPS)
		var p := String(race._bird_states[name]["phase"])
		if phases.is_empty() or phases[-1] != p:
			phases.append(p)
	_check(name + "_phases", phases.has("TELEGRAPH") and phases.has("ACTION")
		and phases.has("RECOVER") and String(race._bird_states[name]["mode"]) == mode,
		str(phases))
	_check(name + "_attack_spawned", race._bird_attacks.size() > 0,
		"attacks=%d" % race._bird_attacks.size())


func _poop_hit(target: String) -> void:
	_setup("bird3", target)
	# force a quick action and place the target at the drop point.
	for i in 90:
		race._tick_bird_behaviors(1.0 / FPS)
		if String(race._bird_states["bird3"]["phase"]) == "ACTION":
			break
	race._check_bird_attacks(1.0 / FPS)
	if race._bird_attacks.is_empty():
		_check("poop_hit_" + target, false, "no attack")
		return
	var a: Dictionary = race._bird_attacks[0]
	# PHASE-FIX：排泄只在落水时判，直接把时间推到落水前 5 ms。
	a["t"] = float(a["life"]) - 0.005
	var land: Vector2 = a["p1"]
	if target == "rabbit":
		race.rabbit.position = land
	else:
		race.turtle.position = land
	race._check_bird_attacks(0.01)
	var hit: bool = GameManager.accident_state in ["RABBIT_STUN", "RABBIT_WATER", "TURTLE_REEF"] \
		or race.turtle.flip_lock > 0.0 or race.turtle.speed < 220.0
	_check("poop_hit_" + target, hit,
		"accident=%s flip=%.2f speed=%.1f" % [GameManager.accident_state,
			race.turtle.flip_lock, race.turtle.speed])
	if target == "rabbit":
		_check("poop_splash", race._bird_splashes.size() > 0,
			"splashes=%d" % race._bird_splashes.size())


func _bird_pass_no_hit() -> void:
	var g: Dictionary = _group("birdpass")
	race.load_level([g], [])
	race.turtle.reset(Vector2(1200.0, race.surface_ref()))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	var band: Rect2 = g["rects"][0]
	# 鸟已经飞到左边：兔子仍站在原判定带里，但这一帧不应再判伤。
	race.turtle.position = Vector2(band.position.x + 300.0, race.surface_ref())
	race.rabbit.position = band.get_center()
	race.rabbit.state = "RIDING"
	GameManager.accident_state = "NONE"
	race.hazard_cooldown = 0.0
	race.rabbit_grace = 0.0
	race.turtle_grace = 0.0
	race.hit_roles.clear()
	race.hit_groups.clear()
	race._check_hazards()
	var passed_hit: bool = GameManager.accident_state != "NONE" or not race.hit_groups.is_empty()
	# 鸟还在俯冲航程内：同一位置必须能判到。
	race.turtle.position = Vector2(band.position.x - 80.0, race.surface_ref())
	race.rabbit.position = band.get_center()
	race.rabbit.state = "RIDING"
	GameManager.accident_state = "NONE"
	race.hazard_cooldown = 0.0
	race.rabbit_grace = 0.0
	race.turtle_grace = 0.0
	race.hit_roles.clear()
	race.hit_groups.clear()
	race._check_hazards()
	var dive_hit: bool = GameManager.accident_state != "NONE" or not race.hit_groups.is_empty()
	_check("bird_pass_no_hit", not passed_hit and dive_hit,
		"passed=%s dive=%s" % [str(passed_hit), str(dive_hit)])


func _body_hit(name: String, target: String) -> void:
	_setup(name, target)
	for i in 100:
		race._tick_bird_behaviors(1.0 / FPS)
		if race._bird_attacks.size() > 0:
			break
	if race._bird_attacks.is_empty():
		_check("body_hit_" + name, false, "no body attack")
		return
	var a: Dictionary = race._bird_attacks[0]
	a["t"] = float(a["life"]) - 0.02
	var ar: Rect2 = race._bird_attack_rect(a)
	if target == "rabbit":
		race.rabbit.position = ar.get_center()
	else:
		race.turtle.position = ar.get_center()
	GameManager.accident_state = "NONE"
	race.turtle.flip_lock = 0.0
	race.turtle.speed = 220.0
	race._check_bird_attacks(0.01)
	var hit: bool = race.turtle.flip_lock > 0.0 or race.turtle.speed < 220.0 		or GameManager.accident_state in ["RABBIT_STUN", "RABBIT_WATER"]
	_check("body_hit_" + name, hit,
		"accident=%s flip=%.2f speed=%.1f" % [GameManager.accident_state,
			race.turtle.flip_lock, race.turtle.speed])


func _hz_case(hz: float) -> void:
	_setup("bird4", "rabbit")
	var t := 0.0
	var seen := false
	var step: float = 1.0 / hz
	for i in int(2.0 * hz):
		race._tick_bird_behaviors(step)
		t += step
		if race._bird_attacks.size() > 0:
			seen = true
			break
	_check("bird_hz_%d" % int(hz), seen and t >= 1.0 and t < 1.6,
		"t=%.2f" % t)


func _plan_repro() -> void:
	race.level_seed = 20261112
	race.load_level(LevelData.groups(), [])
	var a := {}
	for k in race._bird_states.keys():
		a[k] = race._bird_states[k]["queue"].duplicate()
	race.level_seed = 20261112
	race.load_level(LevelData.groups(), [])
	var b := {}
	var last := ""
	var repeat := false
	for k in race._bird_states.keys():
		b[k] = race._bird_states[k]["queue"].duplicate()
		var sig := "/".join(PackedStringArray(race._bird_states[k]["queue"]))
		# 纯 dive 是间隔；真正相邻的特殊序列不能重复。
		if sig == "dive":
			last = ""
		else:
			if sig == last:
				repeat = true
			last = sig
	_check("bird_seed_reproducible", a == b, "states=%d" % a.size())
	_check("bird_no_adjacent_repeat", not repeat, "last=%s" % last)
	# 远程便便撤掉后，所有鸟都只排俯冲；种子不再改变特殊序列。
	race.level_seed = 20261113
	race.load_level(LevelData.groups(), [])
	var all_dive := true
	for k in race._bird_states.keys():
		var q: Array = race._bird_states[k]["queue"]
		if q.size() != 1 or String(q[0]) != "dive":
			all_dive = false
	_check("bird_seed_all_dive", all_dive,
		"states=%d" % race._bird_states.size())


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var f := FileAccess.open("res://docs/reports/longrun/core-feel-19-bird.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks}, "  "))
	f.close()
