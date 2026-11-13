extends Node
## 阶段 4 换挡灰盒：同一段固定关卡，比较三种水平速度策略。
##   A  固定速度（区域基准 240），不换挡（当前正式版的行为）
##   B  三档可选（SLOW 190 / CRUISE 240 / FAST 320），按策略换挡
##   BF 全程 FAST（用来检查“FAST 唯一最优”是否成立）
##
## 驾驶逻辑三条腿完全相同，只有水平速度不同；手动推进 race.gd 的
## _physics_process，固定 1/60 步长，保证结果可复现。
## 这一段不接入正式关卡，也不写 best.json。
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT \
##       res://scenes/stage4_gear_ab.tscn
## 输出：docs/reports/stage4-gear-ab.json

const OUT_PATH := "res://docs/reports/stage4-gear-ab.json"
const STEP := 1.0 / 60.0
## 取 Zone 2 的一段真实关卡：空气横杆 / 水下礁 / 长墙 / 矮岩 / 低梁，
## 五种组各一，够覆盖“开阔段提速 + 临障碍减速”。
const START_X := 21200.0
const END_X := 28500.0
const GEAR_SPEEDS := [190.0, 240.0, 320.0]
const GEAR_NAMES := ["SLOW", "CRUISE", "FAST"]

var is_runner := false
var race
var mode := "A"
var gear := 1
var frames := 0
var accidents := 0
var slips := 0
var sinks := 0
var shifts := 0
var down_presses := 0
var up_presses := 0
var gear_changes := 0
var gear_waste := 0
var gear_osc := 0
var state_sum := 0
var gear_frames := [0, 0, 0]
var _last_gear_t := -10.0
var _last_dir := 0
var _last_accident := "NONE"
var _hard_stop := false
var data := {}
var results := {}


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4GearABRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	Locale.language = "en"
	for m in ["A", "B", "BS", "BF"]:
		await _reset(m)
		results[m] = await _drive()
		print("  done %s %s" % [m, JSON.stringify(results[m])])
	data["arms"] = results
	data["section"] = {"start": START_X, "end": END_X}
	data["gear_speeds"] = {"slow": GEAR_SPEEDS[0], "cruise": GEAR_SPEEDS[1],
		"fast": GEAR_SPEEDS[2]}
	# 灰盒直接写档位（等价于玩家按 ←/→ 一次）；没有接正式输入，因为正式版没有换挡键。
	data["input_actions"] = ["gear applied by harness; a real build would map left/right"]
	_write_json()
	var verdict := _verdict()
	print("STAGE4 GEAR AB: %s" % verdict)
	print("  data: " + JSON.stringify(data))
	get_tree().quit(0)


## 每个模式都从同一场景、同一位置、同一状态开始。
func _reset(m: String) -> void:
	mode = m
	gear = 1
	frames = 0
	accidents = 0
	slips = 0
	sinks = 0
	shifts = 0
	down_presses = 0
	up_presses = 0
	gear_changes = 0
	gear_waste = 0
	gear_osc = 0
	state_sum = 0
	gear_frames = [0, 0, 0]
	_last_gear_t = -10.0
	_last_dir = 0
	_last_accident = "NONE"
	_hard_stop = false
	var old_scene := get_tree().current_scene
	GameManager.start_race()
	await _wait_new_scene(old_scene)
	await get_tree().process_frame
	race = get_tree().current_scene
	race.test_disable_hazards = false
	race.test_no_finish = true
	race.set_physics_process(false)
	race.turtle.position = Vector2(START_X, 300.0)
	race.turtle.speed = GEAR_SPEEDS[1]
	race.turtle.base_speed = GEAR_SPEEDS[1]
	race.turtle.daze_time = 0.0
	race.turtle._sink_speed = 0.0
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race._update_zone()
	_apply_speed()
	GameManager.set_control("turtle")
	for action in ["up", "down", "left", "right", "boost", "shift"]:
		Input.action_release(action)


func _drive() -> Dictionary:
	await _hold(4)
	var groups := _groups()
	for i in groups.size():
		if _hard_stop or race.turtle.position.x > END_X:
			break
		var next: Dictionary = groups[i + 1] if i + 1 < groups.size() else {}
		await _handle(groups[i], next)
	if not _hard_stop:
		await _travel_to(END_X, false)
	return {
		"mode": mode,
		"cleared": not _hard_stop and race.turtle.position.x >= END_X - 40.0,
		"seconds": snappedf(frames * STEP, 0.01),
		"frames": frames,
		"accidents": accidents,
		"slips": slips,
		"sinks": sinks,
		"shifts": shifts,
		"down_presses": down_presses,
		"up_presses": up_presses,
		"gear_changes": gear_changes,
		"gear_waste": gear_waste,
		"gear_oscillations": gear_osc,
		"avg_states": snappedf(float(state_sum) / maxf(frames, 1.0), 0.01),
		"gear_seconds": [snappedf(gear_frames[0] * STEP, 0.01),
			snappedf(gear_frames[1] * STEP, 0.01),
			snappedf(gear_frames[2] * STEP, 0.01)],
	}


func _groups() -> Array:
	var out: Array = []
	for g in LevelData.groups():
		var s: float = LevelData.group_start(g)
		if s >= START_X - 300.0 and s <= END_X:
			out.append(g)
	return out


func _handle(g: Dictionary, next := {}) -> void:
	var kind: String = g["kind"]
	var start: float = LevelData.group_start(g)
	var end: float = LevelData.group_end(g)
	if race.turtle.position.x > end + 80.0:
		return
	if kind == "SURFACE_WALL" or kind == "SURFACE_ROCK" or kind == "LOW_BEAM":
		await _dive_through(start, end, kind, next)
	else:
		var target: float = end + 90.0
		var next_kind: String = next.get("kind", "")
		if next_kind in ["SURFACE_WALL", "SURFACE_ROCK", "LOW_BEAM"]:
			target = minf(target, LevelData.group_start(next) - 170.0)
		await _travel_to(target, false)


func _dive_through(start: float, end: float, kind: String, next := {}) -> void:
	var long_dive: bool = end - start >= 300.0
	if long_dive:
		await _prep_wall(start)
	else:
		await _travel_to(start - 400.0, false)
		await _calm_rabbit(1.2, start - 120.0)
		await _travel_to(start - 170.0, false, false)
	await _prepare_turtle()
	Input.action_press("down")
	down_presses += 1
	await _dive_to(355.0 if kind == "SURFACE_ROCK" else 345.0)
	await _until_x(end + 55.0, 30.0)
	var next_kind: String = next.get("kind", "")
	if next_kind in ["SURFACE_WALL", "SURFACE_ROCK", "LOW_BEAM"] \
			and LevelData.group_start(next) - end <= 320.0:
		return
	await _surface()
	await _prepare_rabbit()


func _prep_wall(start: float) -> void:
	await _travel_to(start - 1900.0, false)
	var deadline: float = _t() + 25.0
	var turn := "rabbit"
	while race.turtle.position.x < start - 355.0 and _t() < deadline and not _hard_stop:
		await _control_to(turn)
		var hold_start: float = _t()
		while _t() - hold_start < 1.0 and race.turtle.position.x < start - 355.0 \
				and not _hard_stop:
			if turn == "rabbit" and race.turtle.daze_time > 3.0:
				break
			await _tick()
		turn = "turtle" if turn == "rabbit" else "rabbit"
	await _control_to("rabbit")
	var tail: float = _t()
	while race.rabbit.daze_time > 0.1 and _t() - tail < 3.0 \
			and race.turtle.position.x < start - 95.0 and not _hard_stop:
		await _tick()
	await _travel_to(start - 95.0, false, false)


func _calm_rabbit(limit: float, limit_x := 1.0e9, turtle_cap := 3.2) -> void:
	if race.showtime_active:
		return
	var start: float = _t()
	await _control_to("rabbit")
	while _t() - start < limit and not race.showtime_active \
			and race.rabbit.daze_time > 0.15 \
			and race.turtle.daze_time < turtle_cap \
			and race.turtle.position.x < limit_x and not _hard_stop:
		await _tick()


func _travel_to(target: float, prep := true, balance := true) -> void:
	var hold_until := 0.0
	while not _hard_stop and race.turtle.position.x < target:
		if balance and not race.showtime_active and race.mount.state == "RIDING" \
				and GameManager.accident_state == "NONE" \
				and _t() >= hold_until:
			var diff: float = race.rabbit.daze_time - race.turtle.daze_time
			if race.rabbit.daze_time > 2.2 and GameManager.current_control != "rabbit":
				await _control_to("rabbit")
				hold_until = _t() + 0.9
			elif race.turtle.daze_time > 2.2 and GameManager.current_control != "turtle":
				await _control_to("turtle")
				hold_until = _t() + 0.9
				if race.turtle.position.y > 305.0:
					await _surface()
			elif diff > 0.4 and GameManager.current_control != "rabbit":
				await _control_to("rabbit")
				hold_until = _t() + 1.0
			elif diff < -0.4 and GameManager.current_control != "turtle":
				await _control_to("turtle")
				hold_until = _t() + 1.0
				if race.turtle.position.y > 305.0:
					await _surface()
		await _tick()
	if prep:
		await _prepare_rabbit()


func _prepare_rabbit() -> void:
	if race.showtime_active:
		return
	await _control_to("rabbit")


func _prepare_turtle() -> void:
	if GameManager.accident_state != "NONE":
		await _wait_accident_clear(6.0)
	await _control_to("turtle")


func _control_to(target: String) -> void:
	if _hard_stop or GameManager.current_control == target:
		return
	var start: float = _t()
	while _t() - start < 6.0 and not _hard_stop:
		if race.showtime_active:
			# Showtime 期间 GameManager 拒绝切人；等它结束，不计入失败时间。
			start = _t()
			await _tick()
			continue
		if GameManager.current_control == target:
			return
		GameManager.toggle_control()
		shifts += 1
		await _tick()


func _dive_to(depth: float) -> void:
	var start: float = _t()
	while _t() - start < 4.0 and race.turtle.position.y < depth and not _hard_stop:
		await _tick()
	Input.action_release("down")
	if race.turtle.position.y < depth - 5.0 and not _hard_stop:
		_hard_stop = true


func _until_x(target: float, limit := 40.0) -> void:
	var start: float = _t()
	while not _hard_stop:
		if race.turtle.position.x >= target:
			return
		if _t() - start > limit:
			_hard_stop = true
			return
		await _tick()


func _surface() -> void:
	if race.turtle.position.y <= 305.0:
		return
	# 乌龟身上按上是上浮，兔子身上按上是起跳。Showtime 期间切不过去，
	# 此时绝对不能按上，否则会把兔子扔进水里。
	if GameManager.current_control != "turtle":
		await _control_to("turtle")
	if GameManager.current_control != "turtle" or _hard_stop:
		return
	Input.action_press("up")
	up_presses += 1
	var start: float = _t()
	while _t() - start < 5.0 and race.turtle.position.y > 305.0 and not _hard_stop:
		await _tick()
	Input.action_release("up")
	# 手动推进时 is_action_just_pressed 会跨多个模拟帧保持为真：Up 刚松开就切到
	# 兔子会被判成一次起跳（兔子被扔进水里）。等一个真实物理帧让边沿过期。
	await get_tree().physics_frame
	await get_tree().process_frame


func _wait_accident_clear(limit: float) -> void:
	var start: float = _t()
	while GameManager.accident_state != "NONE" and _t() - start < limit \
			and not _hard_stop:
		await _tick()


func _hold(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _t() -> float:
	return frames * STEP


## 推进一帧真实物理。race.gd 每帧都会把 turtle.base_speed 写回
## current_zone["base_speed"]，所以换挡不能直接写 turtle，只能改
## current_zone 的副本——这就是“区域基准速度”本身，改它等于改档位。
func _tick() -> void:
	if _hard_stop:
		return
	if mode == "BF":
		gear = 2
	elif mode == "B" or mode == "BS":
		_auto_gear()
	_apply_speed()
	race._physics_process(STEP)
	frames += 1
	_measure()
	if GameManager.accident_state != "NONE" and _last_accident == "NONE":
		accidents += 1
		if GameManager.accident_state in ["RABBIT_SLIP", "RABBIT_WATER", "OXYGEN_OUT"]:
			slips += 1
		else:
			sinks += 1
		print("  %s ACCIDENT %s t=%.1f x=%.0f y=%.0f gear=%s rabbit=%.1f turtle=%.1f"
			% [mode, GameManager.accident_state, _t(), race.turtle.position.x,
				race.turtle.position.y, GEAR_NAMES[gear],
				race.rabbit.daze_time, race.turtle.daze_time])
		# 事故后不再继续驾驶，避免残局影响统计。
		_hard_stop = true
	_last_accident = GameManager.accident_state


func _apply_speed() -> void:
	var want: float = GEAR_SPEEDS[gear]
	if race.current_zone.get("base_speed", 0.0) != want \
			or not race.current_zone.get("_gear_copy", false):
		race.current_zone = race.current_zone.duplicate()
		race.current_zone["base_speed"] = want
		race.current_zone["_gear_copy"] = true
	race.turtle.base_speed = want


## B 策略：开阔且两人都安全时 FAST，其余 CRUISE。
## BS 策略：再往前一步，临近障碍前 600 px 退 SLOW，试“用减速换精度”。
func _auto_gear() -> void:
	var busy: bool = race.turtle.position.y > 305.0 or race.showtime_active \
		or GameManager.accident_state != "NONE"
	var dist: float = _next_obstacle_x() - race.turtle.position.x
	var safe: bool = race.rabbit.daze_time < 1.2 and race.turtle.daze_time < 1.2
	var want := 1
	if not busy and safe and dist > 900.0:
		want = 2
	elif mode == "BS" and not busy and safe and dist < 600.0 and dist > 150.0:
		want = 0
	_set_gear(want)


func _set_gear(g: int) -> void:
	if g == gear:
		return
	var dir := signi(g - gear)
	var now: float = _t()
	if dir == -_last_dir and now - _last_gear_t < 1.5:
		gear_osc += 1
	if _next_obstacle_x() - race.turtle.position.x < 300.0:
		gear_waste += 1
	_last_dir = dir
	_last_gear_t = now
	gear = g
	gear_changes += 1


func _next_obstacle_x() -> float:
	for g in _groups():
		var s: float = LevelData.group_start(g)
		if s > race.turtle.position.x - 40.0:
			return s
	return END_X


func _measure() -> void:
	gear_frames[gear] += 1
	var states := 0
	if race.turtle.position.y > 305.0:
		states += 1
	if race.showtime_active:
		states += 1
	if GameManager.accident_state != "NONE":
		states += 1
	if race.rabbit.daze_time > 0.8:
		states += 1
	if race.turtle.daze_time > 0.8:
		states += 1
	if GameManager.oxygen < Tuning.OXYGEN_LOW:
		states += 1
	state_sum += states


func _verdict() -> String:
	var a: Dictionary = results["A"]
	var b: Dictionary = results["B"]
	var s: Dictionary = results["BS"]
	var f: Dictionary = results["BF"]
	for k in ["A", "B", "BS", "BF"]:
		var r: Dictionary = results[k]
		print("  %s %.1fs clear=%s accidents=%d shifts=%d gears=%d waste=%d osc=%d states=%.2f gear_s=%s"
			% [k, r["seconds"], str(r["cleared"]), r["accidents"], r["shifts"],
				r["gear_changes"], r["gear_waste"], r["gear_oscillations"],
				r["avg_states"], str(r["gear_seconds"])])
	var a_ok: bool = a["cleared"] and a["accidents"] == 0
	var b_ok: bool = b["cleared"] and b["accidents"] == 0
	var s_ok: bool = s["cleared"] and s["accidents"] == 0
	var f_ok: bool = f["cleared"] and f["accidents"] == 0
	var b_delta: float = (a["seconds"] - b["seconds"]) / maxf(a["seconds"], 0.01)
	if not a_ok:
		return "NO CONCLUSION (A 没有干净通过，灰盒先修好)"
	if not b_ok:
		return "REMOVE（B 用同样驾驶逻辑都跑不干净，换挡只是增加操作）"
	if f_ok and f["seconds"] <= b["seconds"] * 1.01:
		return "REMOVE（全程 FAST 不差于策略换挡：FAST 唯一最优，三档退化成单档）"
	if b_delta < 0.03 or b["gear_changes"] < 6:
		return "REMOVE（换挡收益 %.1f%%，不足以抵消操作成本）" % (b_delta * 100.0)
	if not s_ok or s["accidents"] > b["accidents"]:
		return "SIMPLIFY（加 SLOW 没有换来安全，三档里只有提速那档有用）"
	if b["gear_oscillations"] > b["gear_changes"] / 3:
		return "SIMPLIFY（换挡来回抖动，需要更少档位/更宽死区）"
	if b_delta < 0.08:
		return "SIMPLIFY（有可测收益 %.1f%%，但只值得留一档可选提速）" % (b_delta * 100.0)
	return "KEEP（换挡收益 %.1f%%，且没有多余操作或新增事故）" % (b_delta * 100.0)


func _write_json() -> void:
	var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()


func _wait_new_scene(old_scene: Node) -> void:
	for i in 240:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene != old_scene \
				and scene.scene_file_path.ends_with("race.tscn"):
			return
