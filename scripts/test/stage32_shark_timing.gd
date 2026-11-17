extends Node
## FEEL-32：鲨鱼群 10 轮 + 正式 Z3 的时间轴验收。
## 记录 warn / attack / end 时间戳，验证：
##   - 顺序 leader → fat → thin（Turtle → Rabbit → Turtle）
##   - 每次 attack - warn >= 0.9 s
##   - 下一段 warn - 上一段 end >= 0.7 s
##   - 任意时刻最多一个攻击体

const LevelData = preload("res://scripts/systems/level_data.gd")
const FPS := 60.0
const DELTA := 1.0 / FPS
const EPS := 0.02

var is_runner := false
var arena: Node
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
	arena = load("res://scenes/test_arena.tscn").instantiate()
	get_tree().root.add_child(arena)
	for i in 8:
		await get_tree().process_frame
	var race: Node = arena.race
	race.set_physics_process(false)
	var ok_rounds := 0
	for r in 10:
		arena._option.selected = 7
		arena._on_spawn()
		await get_tree().physics_frame
		var g: Dictionary = race.hazard_groups[-1]
		var res := _drive(race, g)
		if bool(res["ok"]):
			ok_rounds += 1
		else:
			print("ROUND_FAIL ", r, " ", JSON.stringify(res))
		arena._on_clear()
	_check("arena_10_rounds", ok_rounds == 10, "%d/10" % ok_rounds)

	# 正式 Z3 组，同一时间轴。
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	var z3: Dictionary = {}
	for g in race.hazard_groups:
		if String(g.get("group", "")) == "shark6":
			z3 = g
	if not z3.is_empty():
		var res := _drive(race, z3)
		_check("z3_timeline", bool(res["ok"]), JSON.stringify(res))
	else:
		_check("z3_timeline", false, "shark6 missing")
	_write()
	var ok: bool = checks.all(func(c): return bool(c["ok"]))
	print("SHARK TIMING: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _drive(race: Node, g: Dictionary) -> Dictionary:
	race._shark_attacks.clear()
	race._bird_attacks.clear()
	race._shark_pack_log.clear()
	var start: float = race._group_start(g)
	race.turtle.reset(Vector2(start - 60.0, 560.0))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	GameManager.accident_state = "NONE"
	race._shark_pack["shark6"] = {"phase": "CIRCLE", "t": 0.0, "announced": false}
	race._shark_pack_entry_seen = true
	race._pack_reset_actors()
	var max_attacks := 0
	for i in 1200:
		race.hazard_clock += DELTA
		race._tick_shark_pack(DELTA)
		race._check_shark_attacks(DELTA)
		max_attacks = maxi(max_attacks, race._shark_attacks.size())
		var attacks: Array = race._shark_pack_log.filter(func(e): return String(e.get("event", "")) == "attack")
		var ends: Array = race._shark_pack_log.filter(func(e): return String(e.get("event", "")) == "end")
		if attacks.size() >= 3 and ends.size() >= 3:
			break
	return _validate(race._shark_pack_log, max_attacks)


func _validate(log: Array, max_attacks: int) -> Dictionary:
	var attacks: Array = log.filter(func(e): return String(e.get("event", "")) == "attack")
	var warns: Array = log.filter(func(e): return String(e.get("event", "")) == "warn")
	var ends: Array = log.filter(func(e): return String(e.get("event", "")) == "end")
	var order: Array = []
	for a in attacks:
		order.append(String(a.get("who", "")))
	var order_ok := order == ["leader", "fat", "thin"]
	var warn_ok := true
	var warn_detail := []
	for a in attacks:
		var who := String(a.get("who", ""))
		var at := float(a.get("t", -1))
		var prev: Dictionary = {}
		for w in warns:
			if String(w.get("who", "")) == who and float(w.get("t", 0)) <= at:
				prev = w
		var d := at - float(prev.get("t", -99))
		warn_detail.append("%s=%.2f" % [who, d])
		if d < 0.9 - EPS:
			warn_ok = false
	var safety_ok := true
	var safety_detail := []
	# leader end -> fat warn; fat end -> thin warn
	var seq: Array = ["leader", "fat"]
	for who in seq:
		var end: Dictionary = {}
		for e in ends:
			if String(e.get("who", "")) == who:
				end = e
		var next_who := "fat" if who == "leader" else "thin"
		var nw: Dictionary = {}
		for w in warns:
			if String(w.get("who", "")) == next_who and float(w.get("t", 0)) >= float(end.get("t", 0)):
				nw = w
		var d := float(nw.get("t", -99)) - float(end.get("t", 0))
		safety_detail.append("%s->%s=%.2f" % [who, next_who, d])
		if d < 0.7 - EPS:
			safety_ok = false
	var ok := order_ok and warn_ok and safety_ok and max_attacks <= 1
	return {"ok": ok, "order": order, "warn": warn_detail,
		"safety": safety_detail, "max_attacks": max_attacks}


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var f := FileAccess.open("res://docs/reports/longrun/feel32-shark-timing.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"checks": checks}, "  "))
		f.close()
