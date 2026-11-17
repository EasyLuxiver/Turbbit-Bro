extends Node
## FEEL-10 P0-C：量两个新动词的“安全通道”是否真的成立，而不是只画了动画。
##
## 直接实例化两个独立试玩场景，读它们装载的那一组障碍：
##   水流浮木：整个 6 s 周期里，至少有一条路清空；且存在“只能跳”和“只能潜”两段。
##   状态吊网：兔子受控且不趴低 → 撞；趴低 → 过；换乌龟把网拉高 → 不趴也过。
## 网高用真实 _physics_process 推进，量 0.5 s 到位。
##
## 输出：docs/reports/longrun/core-feel-10-p0c-verbs.json

const OUT_PATH := "res://docs/reports/longrun/core-feel-10-p0c-verbs.json"
const JUMP_PEAK_Y := 87.0
const DIVE_CENTER_Y := 484.0

var is_runner := false
var checks: Array = []
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
	Locale.set_language("zh")
	await _case_current()
	await _case_net()
	_write()
	_finish()


func _spawn(path: String) -> Node:
	var seg: Node = load(path).instantiate()
	add_child(seg)
	for i in 4:
		await get_tree().process_frame
	var race: Node = seg.race
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = false
	return seg


func _case_current() -> void:
	var seg: Node = await _spawn("res://scenes/p0c_current_test.tscn")
	var race: Node = seg.race
	var g: Dictionary = race.hazard_groups[0]
	var base: Rect2 = g["rects"][0]
	var period := float(g["motion"].get("period", 6.0))
	var rabbit = race.rabbit
	var turtle = race.turtle
	rabbit.state = "RIDING"
	turtle.state = "CRUISING"
	var both := 0
	var jump_only := 0
	var dive_only := 0
	var neither := 0
	var best_high := {}
	var best_low := {}
	for i in 48:
		var t := period * float(i) / 48.0
		race.hazard_clock = t
		var off: Vector2 = race.hazard_offset(g)
		var live := Rect2(base.position + off, base.size)
		var cx := live.position.x + live.size.x * 0.5
		rabbit.position = Vector2(cx, JUMP_PEAK_Y)
		var jump_rect: Rect2 = race._inset(rabbit.get_body_rect(), 3.0)
		turtle.position = Vector2(cx, DIVE_CENTER_Y)
		var dive_rect: Rect2 = race._inset(turtle.get_body_rect(), 3.0)
		var jump_clear := not jump_rect.intersects(live)
		var dive_clear := not dive_rect.intersects(live)
		if jump_clear and dive_clear:
			both += 1
		elif jump_clear:
			jump_only += 1
			if best_low.is_empty():
				best_low = {"t": snappedf(t, 0.001), "offset": snappedf(off.y, 0.1)}
		elif dive_clear:
			dive_only += 1
			if best_high.is_empty():
				best_high = {"t": snappedf(t, 0.001), "offset": snappedf(off.y, 0.1)}
		else:
			neither += 1
	_check("current_always_safe", neither == 0,
		"48 相位里无解=%d（both=%d jump_only=%d dive_only=%d）" % [
			neither, both, jump_only, dive_only])
	_check("current_alternates",
		jump_only >= 4 and dive_only >= 4,
		"jump_only=%d dive_only=%d" % [jump_only, dive_only])
	_check("current_extremes_reachable",
		not best_high.is_empty() and not best_low.is_empty(),
		"dive-only@%s jump-only@%s" % [str(best_high), str(best_low)])
	rows.append({"verb": "current", "period_s": period,
		"amp": g["motion"].get("amp"), "both": both, "jump_only": jump_only,
		"dive_only": dive_only, "neither": neither,
		"dive_only_sample": best_high, "jump_only_sample": best_low})
	seg.queue_free()
	await get_tree().process_frame


func _case_net() -> void:
	var seg: Node = await _spawn("res://scenes/p0c_net_test.tscn")
	var race: Node = seg.race
	var g: Dictionary = race.hazard_groups[0]
	var base: Rect2 = g["rects"][0]
	var rabbit = race.rabbit
	var turtle = race.turtle
	# 先让乌龟受控，按真实物理步进 0.30 s / 0.50 s，量网高到位时间。
	GameManager.current_control = "turtle"
	race.turtle.position = Vector2(400.0, race.surface_ref())
	race._state_net_shift = 0.0
	race.test_disable_hazards = true
	var t := 0.0
	var t90 := -1.0
	for i in 60:
		race._physics_process(1.0 / 120.0)
		t += 1.0 / 120.0
		if t90 < 0.0 and float(race._state_net_shift) <= -90.0:
			t90 = t
	var shift_up: float = race._state_net_shift
	_check("net_raise_0p5s", t90 >= 0.35 and t90 <= 0.60
		and shift_up <= -94.0,
		"到位 %.2f s，最终 %.1f px" % [t90, shift_up])
	# 兔层：用真实 get_body_rect 判三种做法。
	turtle.position = Vector2(base.position.x + base.size.x * 0.5,
		race.surface_ref())
	rabbit.input_down = false
	rabbit.tick_riding(0.016, turtle.get_mount_point(), true, false, true)
	var ride_rect: Rect2 = race._inset(rabbit.get_body_rect(), 3.0)
	rabbit.input_down = true
	rabbit.tick_riding(0.016, turtle.get_mount_point(), true, false, true)
	var crouch_rect: Rect2 = race._inset(rabbit.get_body_rect(), 3.0)
	var low_live := Rect2(base.position, base.size)
	var high_live := Rect2(base.position + Vector2(0.0, shift_up), base.size)
	var ride_low := ride_rect.intersects(low_live)
	var crouch_low := crouch_rect.intersects(low_live)
	var ride_high := ride_rect.intersects(high_live)
	_check("net_rabbit_choices", ride_low and not crouch_low,
		"网低：站着 hit=%s，趴低 hit=%s" % [str(ride_low), str(crouch_low)])
	_check("net_switch_opens_lane", not ride_high,
		"网高：站着 hit=%s（应 false）" % str(ride_high))
	# 换回兔子，网应回落到低位（同样按真实物理）。
	GameManager.current_control = "rabbit"
	race.turtle.position = Vector2(400.0, race.surface_ref())
	for i in 120:
		race._physics_process(1.0 / 120.0)
	var shift_down: float = race._state_net_shift
	_check("net_lower_returns", absf(shift_down) <= 0.1,
		"回落 1.0 s 后 %.2f px" % shift_down)
	rows.append({"verb": "net", "raise_s": snappedf(t90, 0.001),
		"raised_px": snappedf(shift_up, 0.1), "returned_px": snappedf(shift_down, 0.1),
		"ride_low_hit": ride_low, "crouch_low_hit": crouch_low,
		"ride_high_hit": ride_high})
	seg.queue_free()
	await get_tree().process_frame


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var data := {"task": "TBB-CORE-FEEL-10 P0-C",
		"generated_at": Time.get_datetime_string_from_system(),
		"rows": rows, "checks": checks}
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))
	f.close()


func _finish() -> void:
	var failed := 0
	for c in checks:
		if not bool(c["ok"]):
			failed += 1
	print("P0C VERBS: %d/%d pass" % [checks.size() - failed, checks.size()])
	print("P0C RESULT: ", "PASS" if failed == 0 else "FAIL")
	get_tree().quit(0 if failed == 0 else 1)
