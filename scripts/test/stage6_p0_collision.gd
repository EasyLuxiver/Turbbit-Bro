extends Node
## TBB-EXPERIENCE-REFINE-06 P0：双角色物理碰撞 / 联合判罚
##
## 七个必验用例 + 一个高墙补充用例，全部在正式 race.tscn 里用引擎内真实输入
## （Input.action_press / GameManager.toggle_control）逐帧驱动，不直接改事故状态。
##
## 每个用例都额外跑一条“穿透监视”：乌龟判定框（与 _check_hazards 同样的 3 px
## 内缩）一旦和实心障碍相交，就把重叠深度和“壳心是否已经在障碍里面”记下来。
## 撞上之后壳必须被顶在障碍入口那一侧——不能靠事后补记或缩小判定框蒙混。
##
## 输出：docs/reports/longrun/refine06-p0-collision.json
## 用法：godot --headless --path TURBBIT res://scenes/stage6_p0_collision.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/refine06-p0-collision.json"
const STEP := 1.0 / 60.0
## 乌龟判定框半宽（96 宽，内缩 3 → 90 / 2）。
const TURTLE_HALF_W := 45.0

const RABBIT_LAYER := ["LOW_BEAM", "LOW_BIRD", "SURFACE_ROCK"]

var is_runner := false
var race: Node = null
var out := {}
var failures: Array = []
## 每个用例的穿透监视（用例内部每帧累加）。
var pen := {}
## `--pen-trace`：逐帧打印任何正重叠，用来解释 max_pen 的来源。
var trace_pen := false


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage6P0ProbeRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	trace_pen = "--pen-trace" in OS.get_cmdline_user_args()
	await get_tree().process_frame
	await _run()


func _run() -> void:
	Locale.language = "zh"
	GameManager.start_race()
	for i in 4:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null:
		push_error("P0 PROBE: no race scene")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()
	await get_tree().physics_frame

	out["generated_at"] = Time.get_datetime_string_from_system()
	out["hazard_geometry_matches_level_data"] = _geometry_ok()
	out["cases"] = {}

	out["cases"]["c1_rabbit_only"] = _case_rabbit_only()
	out["cases"]["c2_turtle_only"] = _case_turtle_only()
	out["cases"]["c3_both_same_frame"] = _case_both_same_frame()
	out["cases"]["c4_sequential_same_group"] = _case_sequential()
	out["cases"]["c5_contact_while_dunked"] = _case_contact_while_dunked()
	var rescue: Dictionary = _case_rescue_then_independent()
	out["cases"]["c6_rescue_success"] = rescue["rescue"]
	out["cases"]["c7_independent_after_rescue"] = rescue["after"]
	out["cases"]["c8_high_wall"] = _case_high_wall()

	if "--capture-p0" in OS.get_cmdline_user_args():
		await _capture_block()

	_evaluate()
	_write()
	print("REFINE06 P0 PROBE: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


# ---------------------------------------------------------------- 基础驱动

func _reset(x: float) -> void:
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.clear_bro_meter()
	GameManager.accident_count = 0
	GameManager.total_score = 0
	GameManager.score_log.clear()
	GameManager.rabbit_casualties = 0
	GameManager.turtle_failures = 0
	GameManager.rescue_success_count = 0
	GameManager.pickup_count = 0
	GameManager.showtime_active = false
	GameManager.current_control = "turtle"
	race.showtime_active = false
	race.joint_show_t = 0.0
	race.finishing = false
	race.hazard_cooldown = 0.0
	race.accident_flash = 0.0
	race.rabbit_stun = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.emergency_timer = 0.0
	race.turtle_repair = 0.0
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.group_actions.clear()
	race.reset_brains()
	race.test_disable_hazards = false
	race.turtle.reset(Vector2(x, Tuning.NEUTRAL_DEPTH))
	race.turtle.base_speed = 220.0
	race.turtle.speed = 220.0
	race.turtle.speed_cap = 1.0e9
	race.turtle.daze_time = 0.0
	race.turtle.drift = 0.0
	race.turtle.dunk_timer = 0.0
	race.turtle.leap_active = false
	race.turtle.leap_timer = 0.0
	race.turtle.leap_cooldown = 0.0
	race.rabbit.reset()
	race.mount.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.mark_riding()
	race.rabbit.state = "RIDING"
	race.rescue_last_result = ""
	race.rescue_last_reason = ""
	race.carry_max_step = 0.0
	race.carry_kind = ""
	race.snack_boost_until_x = -1.0
	race.snack_boost_speed = 0.0
	Input.action_release("down")
	Input.action_release("up")
	Input.action_release("shift")
	pen = {"max_pen_px": 0.0, "center_inside_frames": 0, "groups": {}}


func _frames(n: int, tag: String) -> void:
	for i in n:
		race._physics_process(STEP)
		_scan_pen(tag)


func _step_to(target_x: float, max_frames: int, tag: String) -> bool:
	for i in max_frames:
		race._physics_process(STEP)
		_scan_pen(tag)
		if race.turtle.position.x >= target_x:
			return true
	return false


func _teleport(x: float) -> void:
	var dx: float = x - float(race.turtle.position.x)
	race.turtle.position.x = x
	if String(race.mount.state) == "RIDING":
		race.rabbit.position.x += dx
	race.rescue_prev_pos.x += dx


## 每帧穿透监视：只看“乌龟会被挡”的障碍类型（A 类不占乌龟那一层）。
## 记录最大重叠深度和“壳心已经在实框里”的帧数——后者才是玩家看到的穿模。
func _scan_pen(tag: String) -> void:
	var tr: Rect2 = race._inset(race.turtle.get_body_rect(), 3.0)
	for g in race.hazard_groups:
		var group: Dictionary = g
		var kind := String(group["kind"])
		if kind in RABBIT_LAYER:
			continue
		for i in group["rects"].size():
			var rect: Rect2 = race.hazard_rect_live(group, i)
			if not tr.intersects(rect):
				continue
			var depth: float = minf(tr.end.x, rect.end.x) - maxf(tr.position.x, rect.position.x)
			pen["max_pen_px"] = maxf(float(pen["max_pen_px"]), snappedf(depth, 0.01))
			if trace_pen and depth > 0.01:
				print("PEN ", tag, " ", group["group"], "#", i, " d=", snappedf(depth, 0.01),
					" x=", snappedf(race.turtle.position.x, 0.1),
					" y=", snappedf(race.turtle.position.y, 0.1),
					" tr=", tr, " rect=", rect)
			if rect.has_point(race.turtle.position):
				pen["center_inside_frames"] = int(pen["center_inside_frames"]) + 1
				var key := tag + ":" + String(group["group"])
				pen["groups"][key] = int(pen["groups"].get(key, 0)) + 1


func _snap(extra: Dictionary = {}) -> Dictionary:
	var d := {
		"accident": GameManager.accident_state,
		"mount": String(race.mount.state),
		"rabbit_state": String(race.rabbit.state),
		"control": GameManager.current_control,
		"accident_count": GameManager.accident_count,
		"score_log": GameManager.score_log.duplicate(true),
		"turtle_x": snappedf(race.turtle.position.x, 0.1),
		"turtle_y": snappedf(race.turtle.position.y, 0.1),
		"turtle_dunk": snappedf(race.turtle.dunk_timer, 0.01),
		"turtle_leap": race.turtle.leap_active,
		"cooldown": snappedf(race.hazard_cooldown, 0.01),
		"hit_roles": race.hit_roles.duplicate(true),
		"pen": {
			"max_pen_px": pen["max_pen_px"],
			"center_inside_frames": pen["center_inside_frames"],
			"groups": pen["groups"].duplicate(true),
		},
	}
	for k in extra:
		d[k] = extra[k]
	return d


func _reasons(snap: Dictionary) -> Array:
	var r: Array = []
	for e in snap.get("score_log", []):
		r.append(String(e["reason"]))
	return r


func _count_mistakes(reasons: Array) -> int:
	var n := 0
	for r in reasons:
		if String(r).begins_with("mistake:"):
			n += 1
	return n


func _rects_of(key: String) -> Array:
	for g in race.hazard_groups:
		if String(g["group"]) == key:
			return g["rects"]
	return []


func _live_rect(key: String) -> Rect2:
	for g in race.hazard_groups:
		if String(g["group"]) == key:
			return race.hazard_rect_live(g, 0)
	return Rect2()


func _drop_rabbit(behind: Vector2, vel: Vector2) -> void:
	race.mount.mark_airborne()
	race.rabbit.position = race.turtle.get_mount_point() + behind
	race.rabbit.velocity = vel
	race.rabbit.state = "FALLING"
	race.rescue_prev_pos = race.rabbit.position


# ---------------------------------------------------------------- 用例

## 1. 兔子单独撞低梁：只有兔子记账，乌龟不背锅；A 类也不该挡住乌龟。
func _case_rabbit_only() -> Dictionary:
	_reset(9600.0 - 260.0)
	var t := 0.0
	var ev := {}
	while t < 2.2:
		race._physics_process(STEP)
		_scan_pen("c1")
		t += STEP
		if race.hit_roles.has("beam2"):
			ev["hit"] = _snap()
			break
	_frames(24, "c1") # 撞后 0.4 s，确认没有追加
	ev["end"] = _snap()
	ev["reasons"] = _reasons(ev["end"])
	ev["roles"] = Dictionary(race.hit_roles.get("beam2", {})).keys()
	var beam_end: float = 0.0
	var beam_left: float = 1.0e9
	for r in _rects_of("beam2"):
		beam_end = maxf(beam_end, float(Rect2(r).end.x))
		beam_left = minf(beam_left, float(Rect2(r).position.x))
	ev["beam_end"] = beam_end
	ev["beam_left"] = beam_left
	# A 类不占乌龟那一层：壳应当照常开进梁的 x 范围（不被挡在入口）。
	ev["turtle_entered_beam"] = race.turtle.position.x > beam_left + 1.0
	return ev


## 2. 乌龟单独撞鲨鱼：只记乌龟；上冲时壳被顶在入口，退避后自动放行。
## REBUILD-06 P3 起鲨鱼是水下伏击：撞击发生在它冲上水面那一瞬，顶住只持续
## 到它退回深水（≤2 s），之后壳会自动恢复前进——P0 的“无限顶住”不再存在。
func _case_turtle_only() -> Dictionary:
	_reset(7250.0 - 280.0)
	var t := 0.0
	var ev := {}
	var hit_t := -1.0
	while t < 3.0:
		race._physics_process(STEP)
		_scan_pen("c2")
		t += STEP
		if Dictionary(race.hit_roles.get("shark1", {})).has("turtle"):
			ev["hit"] = _snap()
			ev["hit_t"] = snappedf(t, 0.001)
			hit_t = t
			break
	# 撞上的那一帧：壳必须还在鲨鱼入口左侧，没有穿过去。
	var sr_hit := _live_rect("shark1")
	ev["shark_left"] = snappedf(sr_hit.position.x, 0.1)
	ev["pinned_left_of_shark"] = race.turtle.position.x \
		<= sr_hit.position.x - TURTLE_HALF_W + 1.0
	# 继续开，不按任何键：等它退回深水，看壳是否自己恢复前进。
	var free_t := -1.0
	var guard := 0
	while guard < 360 and hit_t >= 0.0:
		race._physics_process(STEP)
		_scan_pen("c2")
		t += STEP
		guard += 1
		var sr := _live_rect("shark1")
		if sr.position.y >= 512.0 \
				and race.turtle.position.x > sr.position.x + 20.0:
			free_t = t
			break
	ev["released_after_s"] = snappedf(free_t - hit_t, 0.001) if free_t >= 0.0 else -1.0
	_frames(20, "c2")
	ev["end"] = _snap()
	ev["reasons"] = _reasons(ev["end"])
	ev["roles"] = Dictionary(race.hit_roles.get("shark1", {})).keys()
	var sr := _live_rect("shark1")
	ev["shark_left_end"] = snappedf(sr.position.x, 0.1)
	ev["released_past_shark"] = free_t >= 0.0 \
		and race.turtle.position.x > sr.position.x + 20.0
	return ev


## 3. 同一次遭遇里两边都撞浮木：两个角色都要有记录，但只罚一次（联合事故）。
## CORE-FEEL-07 P0-B 起规则改了：同一障碍 + 同一时间窗 = 一个事故事件，只结算一次。
## 这里断言的是“两个角色都被记进事件、账上只有一笔”，不再要求两笔。
func _case_both_same_frame() -> Dictionary:
	_reset(6400.0 - 260.0)
	var t := 0.0
	var ev := {}
	var role_t := {}
	var face_x := -1.0
	while t < 3.0:
		race._physics_process(STEP)
		_scan_pen("c3")
		t += STEP
		var roles: Dictionary = race.hit_roles.get("log1", {})
		for role in roles.keys():
			if not role_t.has(role):
				role_t[role] = snappedf(t, 0.001)
				# 记录“第一次记账那一帧”的壳位置：它必须还在入口左侧。
				if face_x < 0.0 and String(role) == "turtle":
					face_x = float(race.turtle.position.x)
		if roles.size() >= 2:
			ev["hit"] = _snap()
			ev["hit_t"] = snappedf(t, 0.001)
			break
	_frames(60, "c3")
	ev["end"] = _snap()
	ev["first_hit_t"] = role_t
	ev["reasons"] = _reasons(ev["end"])
	ev["mistakes"] = _count_mistakes(ev["reasons"])
	ev["roles"] = Dictionary(race.hit_roles.get("log1", {})).keys()
	var lr := _live_rect("log1")
	ev["log_left"] = snappedf(lr.position.x, 0.1)
	ev["turtle_x_at_first_book"] = snappedf(face_x, 0.1)
	ev["turtle_blocked_at_entry"] = face_x > 0.0 and face_x <= lr.position.x - TURTLE_HALF_W + 1.0
	if role_t.has("rabbit") and role_t.has("turtle"):
		ev["contact_gap_s"] = snappedf(absf(float(role_t["rabbit"]) - float(role_t["turtle"])), 0.001)
	return ev


## 4. 同一组先后撞：乌龟先顶在浮木入口，壳被撞沉后兔子从下方擦到同一根浮木。
## CORE-FEEL-07 P0-B：这仍然是“一次失败动作”，两个角色记进同一个事件，只罚一次。
func _case_sequential() -> Dictionary:
	_reset(6400.0 - 260.0)
	var t := 0.0
	var ev := {}
	var role_t := {}
	while t < 3.4:
		race._physics_process(STEP)
		_scan_pen("c4")
		t += STEP
		var roles: Dictionary = race.hit_roles.get("log1", {})
		for role in roles.keys():
			if not role_t.has(role):
				role_t[role] = snappedf(t, 0.001)
		if roles.size() >= 2:
			ev["both_at"] = snappedf(t, 0.001)
			break
	_frames(90, "c4") # 再 1.5 s：不允许同一组继续累计
	ev["end"] = _snap()
	ev["first_hit_t"] = role_t
	ev["reasons"] = _reasons(ev["end"])
	ev["mistakes"] = _count_mistakes(ev["reasons"])
	ev["roles"] = Dictionary(race.hit_roles.get("log1", {})).keys()
	return ev


## 5. 乌龟在浪涌/下沉（被击退）状态中撞上高墙：仍然要记账，且照样被顶住。
func _case_contact_while_dunked() -> Dictionary:
	# 先在 shark1 撞一次，进入 dunk；再摆到 wall1 前。
	_reset(7250.0 - 280.0)
	var t := 0.0
	var ev := {}
	while t < 3.0:
		race._physics_process(STEP)
		_scan_pen("c5a")
		t += STEP
		if Dictionary(race.hit_roles.get("shark1", {})).has("turtle"):
			break
	ev["dunk_before"] = snappedf(race.turtle.dunk_timer, 0.01)
	_teleport(10860.0 - 130.0)
	ev["dunk_at_teleport"] = snappedf(race.turtle.dunk_timer, 0.01)
	t = 0.0
	while t < 1.6:
		race._physics_process(STEP)
		_scan_pen("c5b")
		t += STEP
		if Dictionary(race.hit_roles.get("wall1", {})).has("turtle"):
			ev["hit"] = _snap({"hit_t": snappedf(t, 0.001)})
			break
	_frames(30, "c5b")
	ev["end"] = _snap()
	ev["reasons"] = _reasons(ev["end"])
	ev["roles"] = Dictionary(race.hit_roles.get("wall1", {})).keys()
	ev["dunk_at_hit"] = float(ev.get("hit", {}).get("turtle_dunk", 0.0))
	var wr := _live_rect("wall1")
	ev["turtle_left_of_wall"] = race.turtle.position.x <= wr.position.x - TURTLE_HALF_W + 1.0
	return ev


## 6 + 7. 兔子落水 → 乌龟下潜救起（成功不追加判罚）；救援后再撞新障碍照常记账。
func _case_rescue_then_independent() -> Dictionary:
	var x0 := 7920.0 # log1 / shark1 之后的开阔水域
	_reset(x0)
	_drop_rabbit(Vector2(-46.0, 105.0), Vector2(0.0, 60.0))
	Input.action_release("down")
	var ev := {"x0": x0}
	var t := 0.0
	var seen_trigger := false
	var seen_catch := false
	var seen_done := false
	var done_t := -1.0
	while t < 9.0:
		if seen_trigger:
			Input.action_press("down")
		race._physics_process(STEP)
		_scan_pen("c6")
		t += STEP
		if not seen_trigger and GameManager.accident_state == "RABBIT_WATER":
			seen_trigger = true
			ev["trigger"] = _snap()
			ev["trigger_mistakes"] = _count_mistakes(_reasons(ev["trigger"]))
		if seen_trigger and not seen_catch and String(race.rescue_last_result) == "caught":
			seen_catch = true
			ev["catch"] = _snap()
		if seen_catch and not seen_done and GameManager.accident_state == "NONE" \
				and String(race.mount.state) == "RIDING":
			seen_done = true
			done_t = t
			ev["done"] = _snap()
			Input.action_release("down")
		if seen_done and t - done_t > 1.0:
			break
	Input.action_release("down")
	ev["after"] = _snap()
	ev["mistakes_after"] = _count_mistakes(_reasons(ev["after"]))
	ev["accident_count_after"] = GameManager.accident_count
	ev["reasons_after"] = _reasons(ev["after"])

	# 救援成功后重新出发，撞一个全新的障碍（log3，静态）。
	_teleport(30550.0 - 260.0)
	var t2 := 0.0
	var ev2 := {}
	while t2 < 3.0:
		race._physics_process(STEP)
		_scan_pen("c7")
		t2 += STEP
		if Dictionary(race.hit_roles.get("log3", {})).has("turtle"):
			ev2["hit"] = _snap({"hit_t": snappedf(t2, 0.001)})
			break
	_frames(20, "c7")
	ev2["end"] = _snap()
	ev2["reasons"] = _reasons(ev2["end"])
	ev2["roles"] = Dictionary(race.hit_roles.get("log3", {})).keys()
	ev2["accident_count"] = GameManager.accident_count
	ev2["mistakes_total"] = _count_mistakes(ev2["reasons"])
	return {"rescue": ev, "after": ev2}


## 8. 高墙：不跃起时壳被顶在墙前；按 ↑ 跃起后必须能过——证明顶住不是死锁。
func _case_high_wall() -> Dictionary:
	# P6 换位后 wall1 在 10860（原 13300）。
	_reset(10860.0 - 260.0)
	var t := 0.0
	var ev := {}
	while t < 3.0:
		race._physics_process(STEP)
		_scan_pen("c8a")
		t += STEP
		if Dictionary(race.hit_roles.get("wall1", {})).has("turtle"):
			ev["hit"] = _snap({"hit_t": snappedf(t, 0.001)})
			break
	_frames(60, "c8a")
	ev["blocked"] = _snap()
	var wr := _live_rect("wall1")
	ev["turtle_left_of_wall"] = race.turtle.position.x <= wr.position.x - TURTLE_HALF_W + 1.0
	ev["wall_end"] = snappedf(wr.end.x, 0.1)
	# 标准输入：从墙前按 ↑ 跃起（乌龟受控）。
	Input.action_press("up")
	var t2 := 0.0
	while t2 < 3.0:
		race._physics_process(STEP)
		_scan_pen("c8b")
		t2 += STEP
		if race.turtle.position.x > wr.end.x + TURTLE_HALF_W:
			ev["passed"] = _snap({"pass_t": snappedf(t2, 0.001)})
			break
	Input.action_release("up")
	if not ev.has("passed"):
		ev["passed"] = false
	ev["end"] = _snap()
	return ev


# ---------------------------------------------------------------- 肉眼证据

## 只在带 `--capture-p0` 的窗口化运行里执行：把壳开到浮木入口顶住，截一张图。
## 用途是给“壳停在浮木入口、没有插进浮木里”留一张人眼能看的证据；
## headless 跑不会走这里，输出图也是黑的。
func _capture_block() -> void:
	_reset(6400.0 - 260.0)
	var t := 0.0
	while t < 3.0:
		race._physics_process(STEP)
		_scan_pen("cap")
		t += STEP
		if Dictionary(race.hit_roles.get("log1", {})).has("turtle"):
			break
	for i in 20: # 顶住后再跑 0.33 s，让相机与顶住状态稳定
		race._physics_process(STEP)
	for i in 4:
		await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("refine06-p0-log-block.png")
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE ", path, " turtle_x=", snappedf(race.turtle.position.x, 0.1),
		" log_left=", snappedf(_live_rect("log1").position.x, 0.1))


# ---------------------------------------------------------------- 判定

func _geometry_ok() -> bool:
	# 判定框必须来自关卡数据本来的几何（装载 +34 y、食物抽签只换锚点的种类）。
	# 这里查本次用例用到的 5 组：x / w / 矩形数 / 每段的 y、h 都必须与
	# build_group 的原样几何一致——没有为了通过而缩小或放大判定框。
	var bad: Array = []
	var dy: float = Tuning.WORLD_Y_SHIFT
	for key in ["beam2", "shark1", "log1", "wall1", "log3"]:
		var group: Dictionary = {}
		for g in race.hazard_groups:
			if String(g["group"]) == key:
				group = g
				break
		var spec := {}
		for s in LevelData.GROUPS:
			if String(s["group"]) == key:
				spec = s
				break
		if group.is_empty() or spec.is_empty():
			bad.append("%s: 找不到" % key)
			continue
		var base: Dictionary = LevelData.build_group(spec)
		var live: Array = group["rects"]
		var orig: Array = base["rects"]
		if live.size() != orig.size():
			bad.append("%s: 矩形数 %d != %d" % [key, live.size(), orig.size()])
			continue
		for i in live.size():
			var lr: Rect2 = live[i]
			var orr: Rect2 = orig[i]
			if absf(lr.position.x - orr.position.x) > 0.01 \
					or absf(lr.size.x - orr.size.x) > 0.01:
				bad.append("%s[%d]: x/w %.1f/%.1f != %.1f/%.1f" % [
					key, i, lr.position.x, lr.size.x, orr.position.x, orr.size.x])
			if absf(lr.position.y - (orr.position.y + dy)) > 0.01 \
					or absf(lr.size.y - orr.size.y) > 0.01:
				bad.append("%s[%d]: y/h %.1f/%.1f != %.1f/%.1f" % [
					key, i, lr.position.y, lr.size.y, orr.position.y + dy, orr.size.y])
	out["geometry_mismatches"] = bad
	return bad.is_empty()


func _evaluate() -> void:
	var c: Dictionary = out["cases"]

	_expect("几何：判定框与 level_data 的 x / w 一致", bool(out["hazard_geometry_matches_level_data"]))
	_expect("关闭判定的测试开关未被用来通过（test_disable_hazards=false）",
		not race.test_disable_hazards)

	# 1 兔子单独
	var c1: Dictionary = c["c1_rabbit_only"]
	_expect("1 兔子撞低梁记了兔子（%s）" % str(c1.get("reasons", [])),
		c1.has("hit") and _has_any(c1.get("reasons", []), "RABBIT"))
	_expect("1 低梁不记乌龟（%s）" % str(c1.get("roles", [])),
		not (c1.get("roles", []) as Array).has("turtle"))
	_expect("1 A 类不挡乌龟：壳开进了梁的 x 范围（x=%.1f, 梁起=%.1f）" % [
		float(c1.get("end", {}).get("turtle_x", 0.0)), float(c1.get("beam_left", 0.0))],
		bool(c1.get("turtle_entered_beam")))
	_expect("1 穿透 0（max=%.2f px, center=%d）" % [
		float(c1.get("end", {}).get("pen", {}).get("max_pen_px", 0.0)),
		int(c1.get("end", {}).get("pen", {}).get("center_inside_frames", 0))],
		int(c1.get("end", {}).get("pen", {}).get("center_inside_frames", 1)) == 0)

	# 2 乌龟单独
	var c2: Dictionary = c["c2_turtle_only"]
	_expect("2 鲨鱼记了乌龟（%s）" % str(c2.get("reasons", [])),
		c2.has("hit") and _has_any(c2.get("reasons", []), "TURTLE"))
	_expect("2 鲨鱼不记兔子（%s）" % str(c2.get("roles", [])),
		not (c2.get("roles", []) as Array).has("rabbit"))
	_expect("2 撞击那一帧壳被顶在鲨鱼左沿（%s, 左沿=%.1f）" % [
		str(c2.get("pinned_left_of_shark")), float(c2.get("shark_left", 0.0))],
		bool(c2.get("pinned_left_of_shark")))
	_expect("2 退避后壳自动放行（%.2f s ≤ 2.0 s，且已越过入口）" % [
		float(c2.get("released_after_s", 99.0))],
		float(c2.get("released_after_s", 99.0)) >= 0.0 \
			and float(c2.get("released_after_s", 99.0)) <= 2.0 \
			and bool(c2.get("released_past_shark")))
	_expect("2 穿透 0（max=%.2f px, center=%d）" % [
		float(c2.get("end", {}).get("pen", {}).get("max_pen_px", 0.0)),
		int(c2.get("end", {}).get("pen", {}).get("center_inside_frames", 0))],
		int(c2.get("end", {}).get("pen", {}).get("center_inside_frames", 1)) == 0)
	_expect("2 同一组只记一笔（mistakes=%d）" % _count_mistakes(c2.get("reasons", [])),
		_count_mistakes(c2.get("reasons", [])) == 1)

	# 3 同一次遭遇双撞
	var c3: Dictionary = c["c3_both_same_frame"]
	_expect("3 同一次遭遇里两个角色都有记录（%s，间隔 %.2f s）" % [
		str(c3.get("roles", [])), float(c3.get("contact_gap_s", 99.0))],
		(c3.get("roles", []) as Array).has("rabbit")
		and (c3.get("roles", []) as Array).has("turtle")
		and float(c3.get("contact_gap_s", 99.0)) <= 1.6)
	_expect("3 同一障碍只记一笔（mistakes=%d）" % int(c3.get("mistakes", -1)),
		int(c3.get("mistakes", -1)) == 1)
	_expect("3 接触帧壳被顶在浮木入口（x=%.1f, 入口=%.1f）" % [
		float(c3.get("turtle_x_at_first_book", 0.0)), float(c3.get("log_left", 0.0))],
		bool(c3.get("turtle_blocked_at_entry")))
	_expect("3 穿透 0（max=%.2f px, center=%d）" % [
		float(c3.get("end", {}).get("pen", {}).get("max_pen_px", 0.0)),
		int(c3.get("end", {}).get("pen", {}).get("center_inside_frames", 0))],
		int(c3.get("end", {}).get("pen", {}).get("center_inside_frames", 1)) == 0)

	# 4 同组先后撞
	var c4: Dictionary = c["c4_sequential_same_group"]
	_expect("4 先后撞同组：只记一笔、两个角色都在（mistakes=%d, roles=%s）" % [
		int(c4.get("mistakes", -1)), str(c4.get("roles", []))],
		int(c4.get("mistakes", -1)) == 1
		and (c4.get("roles", []) as Array).has("rabbit")
		and (c4.get("roles", []) as Array).has("turtle"))
	var rt: Dictionary = c4.get("first_hit_t", {})
	_expect("4 两次接触是分开的两帧（turtle=%s, rabbit=%s）" % [
		str(rt.get("turtle", "-")), str(rt.get("rabbit", "-"))],
		rt.has("rabbit") and rt.has("turtle")
		and absf(float(rt["rabbit"]) - float(rt["turtle"])) > 0.0)
	_expect("4 穿透 0（max=%.2f px, center=%d）" % [
		float(c4.get("end", {}).get("pen", {}).get("max_pen_px", 0.0)),
		int(c4.get("end", {}).get("pen", {}).get("center_inside_frames", 0))],
		int(c4.get("end", {}).get("pen", {}).get("center_inside_frames", 1)) == 0)
	_expect("4 穿透 0（max=%.2f px, center=%d）" % [
		float(c4.get("end", {}).get("pen", {}).get("max_pen_px", 0.0)),
		int(c4.get("end", {}).get("pen", {}).get("center_inside_frames", 0))],
		int(c4.get("end", {}).get("pen", {}).get("center_inside_frames", 1)) == 0)

	# 5 浪涌/下沉中撞
	var c5: Dictionary = c["c5_contact_while_dunked"]
	_expect("5 下沉中被击退仍记了乌龟（%s）" % str(c5.get("reasons", [])),
		c5.has("hit") and _has_any(c5.get("reasons", []), "TURTLE"))
	_expect("5 撞击那一刻仍在 dunk 里（dunk=%.2f s）" % float(c5.get("dunk_at_hit", 0.0)),
		float(c5.get("dunk_at_hit", 0.0)) > 0.0)
	_expect("5 仍被顶在墙前", bool(c5.get("turtle_left_of_wall")))
	_expect("5 穿透 0（max=%.2f px, center=%d）" % [
		float(c5.get("end", {}).get("pen", {}).get("max_pen_px", 0.0)),
		int(c5.get("end", {}).get("pen", {}).get("center_inside_frames", 0))],
		int(c5.get("end", {}).get("pen", {}).get("center_inside_frames", 1)) == 0)

	# 6 救援成功
	var c6: Dictionary = c["c6_rescue_success"]
	_expect("6 救援流程完整（trigger/catch/done）",
		c6.has("trigger") and c6.has("catch") and c6.has("done"))
	_expect("6 救援成功后事故数不再增加（%d）" % int(c6.get("accident_count_after", -1)),
		int(c6.get("accident_count_after", -1)) == 1)
	_expect("6 救援成功后没有新的 mistake（%d，%s）" % [
		int(c6.get("mistakes_after", -1)), str(c6.get("reasons_after", []))],
		int(c6.get("mistakes_after", -1)) == 1)
	_expect("6 救援成功不产生联合事故（state=%s）" % str(c6.get("after", {}).get("accident")),
		String(c6.get("after", {}).get("accident")) == "NONE")
	_expect("6 救援成功回到骑乘（%s）" % str(c6.get("after", {}).get("mount")),
		String(c6.get("after", {}).get("mount")) == "RIDING")
	_expect("6 score_log 里有接人奖励但没有 mistake 追加（%s）" % str(c6.get("reasons_after", [])),
		_has_any(c6.get("reasons_after", []), "rescue_switch")
		and _count_mistakes(c6.get("reasons_after", [])) == 1)

	# 7 救援后独立碰撞
	var c7: Dictionary = c["c7_independent_after_rescue"]
	_expect("7 救援后新障碍照常记乌龟（%s）" % str(c7.get("roles", [])),
		(c7.get("roles", []) as Array).has("turtle")
		and _has_any(c7.get("reasons", []), "TURTLE"))
	_expect("7 新事故没有被并进救援事故（accident_count=%d，总 mistake=%d）" % [
		int(c7.get("accident_count", -1)), int(c7.get("mistakes_total", -1))],
		int(c7.get("accident_count", -1)) >= 2 and int(c7.get("mistakes_total", -1)) >= 2)
	_expect("7 穿透 0（max=%.2f px, center=%d）" % [
		float(c7.get("end", {}).get("pen", {}).get("max_pen_px", 0.0)),
		int(c7.get("end", {}).get("pen", {}).get("center_inside_frames", 0))],
		int(c7.get("end", {}).get("pen", {}).get("center_inside_frames", 1)) == 0)

	# 8 高墙
	var c8: Dictionary = c["c8_high_wall"]
	_expect("8 不跃起时壳被顶在墙前", bool(c8.get("turtle_left_of_wall")))
	_expect("8 顶住 1 s 内没有穿过去", float(c8.get("blocked", {}).get("turtle_x", 1.0e9))
		<= float(c8.get("wall_end", 0.0)))
	_expect("8 从墙前按 ↑ 跃起能过（证明不是死锁）", c8.has("passed"))
	_expect("8 穿透 0（max=%.2f px, center=%d）" % [
		float(c8.get("end", {}).get("pen", {}).get("max_pen_px", 0.0)),
		int(c8.get("end", {}).get("pen", {}).get("center_inside_frames", 0))],
		int(c8.get("end", {}).get("pen", {}).get("center_inside_frames", 1)) == 0)


func _has_any(arr: Array, needle: String) -> bool:
	for r in arr:
		if String(r).contains(needle):
			return true
	return false


func _expect(label: String, ok: bool) -> void:
	if not ok:
		failures.append(label)


func _write() -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out, "  "))
		f.close()
