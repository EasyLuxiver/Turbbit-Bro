extends Node
## TBB-EXPERIENCE-REFINE-06 P5：角色反馈与喜剧表现探针。
##
## 直接跑正式 race.gd 的落水/救援与浪击掀翻：
##   1) rabbit_water —— 兔子落水：水花记在真实穿水点；从离壳到回壳逐帧位移连续；
##      靠近 → 接住 → 抬回壳上三阶段各有多少帧（必须看得见）；
##   2) flip —— 乌龟被浪掀翻：flip_t 置位、0.9 s 内走完、不是事故状态；
##      掀翻期间/之后事故计数与 BRO METER 都只记浪击那一次；
##      恢复后状态回到行进、速度回巡航附近、控制权不变、兔子还在壳上；
##   3) flip_no_clip —— 贴着浮木掀翻并前进：逐帧检查壳矩形，不允许不接触地越过；
##   4) source —— 源码接线检查。
##
## 输出：docs/reports/longrun/refine06-p5-character-feedback.json
## 运行：godot --headless --path TURBBIT res://scenes/stage4_char_feedback.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/refine06-p5-character-feedback.json"
const STEP := 1.0 / 60.0
## 单帧位移的物理上限：正常下落 950 px/s、救援追赶 560、抬升 520。
## 超过 1000 px/s 的位移只可能是吸附/瞬移。
const MAX_IMPLIED_SPEED := 1000.0

var is_runner := false
var race: Node = null
var out := {}
var failures: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4CharFeedbackRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	Locale.language = "zh"
	GameManager.start_race()
	for i in 4:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null:
		push_error("P5 FEEDBACK: no race scene")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_disable_hazards = true
	race.test_no_finish = true
	Input.action_release("down")
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()

	out["constants"] = {
		"flip_time": Tuning.FLIP_TIME,
		"dunk_time": Tuning.DUNK_TIME,
		"rescue_entry_y": Tuning.RESCUE_ENTRY_Y,
		"max_implied_speed": MAX_IMPLIED_SPEED,
	}
	out["rabbit_splash"] = _case_rabbit_splash()
	out["rabbit_water"] = _case_rabbit_water()
	out["flip"] = _case_flip()
	out["flip_no_clip"] = _case_flip_no_clip()
	out["formal_track"] = _case_formal_track()
	out["source"] = _source_check()

	_evaluate()
	_write()
	print("P5 CHAR FEEDBACK: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _clean() -> void:
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.clear_bro_meter()
	GameManager.accident_count = 0
	GameManager.total_score = 0
	GameManager.score_log.clear()
	GameManager.rescue_success_count = 0
	race.showtime_active = false
	race.joint_show_t = 0.0
	race.finishing = false
	race.hazard_cooldown = 0.0
	race.rabbit_stun = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.emergency_timer = 0.0
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.rescue_last_result = ""
	race.rescue_last_reason = ""
	race.rescue_splash_t = -1.0
	race.rescue_splash_pos = Vector2.ZERO
	race.reset_brains()
	race.turtle.reset(Vector2(5000.0, Tuning.NEUTRAL_DEPTH))
	race.turtle.base_speed = 220.0
	race.turtle.speed = 0.0
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()


## 1a) 兔子从水线上方掉落：水花必须记在真实穿水点。
func _case_rabbit_splash() -> Dictionary:
	_clean()
	GameManager.current_control = "turtle"
	Input.action_release("down")
	# 从壳上被撞飞：水线以上 100 px，真实往下掉再穿水。
	race.rabbit.position = race.turtle.position + Vector2(-46.0, -100.0)
	race.rabbit.velocity = Vector2(0.0, 300.0)
	race.rabbit.state = "FALLING_WATER"
	race._trigger_accident("RABBIT_WATER")
	var frame := 0
	while frame < 120 and String(race.mount.state) == "RESCUE_FALLING":
		race._physics_process(STEP)
		frame += 1
	var splash_err: float = race.rabbit.position.distance_to(race.rescue_splash_pos)
	return {
		"fall_frames": frame,
		"rabbit_at_splash": [snappedf(race.rabbit.position.x, 0.1),
			snappedf(race.rabbit.position.y, 0.1)],
		"splash_pos": [snappedf(race.rescue_splash_pos.x, 0.1),
			snappedf(race.rescue_splash_pos.y, 0.1)],
		"splash_err_px": snappedf(splash_err, 0.1),
		"splash_y_minus_entry": snappedf(
			race.rescue_splash_pos.y - Tuning.RESCUE_ENTRY_Y, 0.1),
		"mount_state": String(race.mount.state),
	}


## 1b) 兔子已经掉到壳后方：下潜接住 → 抬回壳上，三阶段可见且位置连续。
func _case_rabbit_water() -> Dictionary:
	_clean()
	GameManager.current_control = "turtle"
	Input.action_release("down")
	# 壳后方 -46、落点下方 105（相对壳上落点）：不在普通接人盒里，必须真的下潜去接。
	var mp0: Vector2 = race.turtle.get_mount_point()
	race.turtle.speed = 220.0
	race.rabbit.position = mp0 + Vector2(-46.0, 105.0)
	race.rabbit.velocity = Vector2(0.0, 60.0)
	race.rabbit.state = "FALLING_WATER"
	var prev: Vector2 = race.rabbit.position
	var max_implied := 0.0
	var water_frames := 0
	var carry_frames := 0
	var fall_frames := 0
	var splash_err := -1.0
	var catch_frame := -1
	var recovered_frame := -1
	var frame := 0
	var t := 0.0
	var trace: Array = []
	race._trigger_accident("RABBIT_WATER")
	Input.action_release("down")
	while t < 6.0 and frame < 600:
		# 0.6 s 后才开始下潜：兔子已经沉深一点，接住后抬回壳上的距离看得见。
		if t >= 0.6:
			Input.action_press("down")
		race._physics_process(STEP)
		t += STEP
		frame += 1
		var rp: Vector2 = race.rabbit.position
		max_implied = maxf(max_implied, rp.distance_to(prev) / STEP)
		prev = rp
		var st := String(race.mount.state)
		if frame % 10 == 0:
			trace.append([snappedf(t, 0.01), st,
				[snappedf(race.rabbit.position.x, 0.0), snappedf(race.rabbit.position.y, 0.0)],
				[snappedf(race.turtle.position.x, 0.0), snappedf(race.turtle.position.y, 0.0)],
				snappedf(race.turtle.speed, 0.0)])
		if st == "RESCUE_FALLING":
			fall_frames += 1
		if st == "RESCUE_ACTIVE":
			water_frames += 1
			if splash_err < 0.0:
				splash_err = rp.distance_to(race.rescue_splash_pos)
		if st == "CARRYING":
			carry_frames += 1
			if catch_frame < 0:
				catch_frame = frame
		if recovered_frame < 0 and String(race.rescue_last_result) == "caught" \
				and st == "RIDING" and GameManager.accident_state == "NONE":
			recovered_frame = frame
			break
	Input.action_release("down")
	return {
		"trace": trace,
		"splash_err_px": snappedf(splash_err, 0.1),
		"fall_frames": fall_frames,
		"water_frames": water_frames,
		"carry_frames": carry_frames,
		"catch_frame": catch_frame,
		"recovered_frame": recovered_frame,
		"last_result": String(race.rescue_last_result),
		"last_reason": String(race.rescue_last_reason),
		"max_implied_speed": snappedf(max_implied, 0.1),
		"rabbit_state": String(race.rabbit.state),
		"mount_state": String(race.mount.state),
		"accident_state": String(GameManager.accident_state),
		"accident_count": GameManager.accident_count,
		"rescue_success": GameManager.rescue_success_count,
	}


## 2) 乌龟被浪掀翻：表现计时、无第二套惩罚、恢复后正常。
func _case_flip() -> Dictionary:
	_clean()
	GameManager.current_control = "turtle"
	var result := {}
	var acc_before := GameManager.accident_count
	var bro_before := GameManager.bro_meter
	race._turtle_contact("probe_reef", "SHARK")
	result["flip_t_at_hit"] = snappedf(race.turtle.flip_t, 0.001)
	var x_at_hit: float = race.turtle.position.x
	var x_at_flip_end := 0.0
	result["turtle_accident"] = race.turtle.accident
	result["accident_delta"] = GameManager.accident_count - acc_before
	result["bro_delta"] = GameManager.bro_meter - bro_before
	var acc_after_hit := GameManager.accident_count
	var bro_after_hit := GameManager.bro_meter
	var flip_frames := 0
	var t := 0.0
	var frame := 0
	var flip_end_t := -1.0
	var cruise_t := -1.0
	var speed_at_cruise := 0.0
	var state_at_cruise := ""
	# 掀翻 0.9 s 走完；入水 1.8 s 还要上浮回巡航。给 4 s 看清“接回正常逻辑”。
	while t < 4.0 and frame < 400:
		race._physics_process(STEP)
		t += STEP
		frame += 1
		if race.turtle.flip_t > 0.0:
			flip_frames += 1
		elif flip_end_t < 0.0 and frame > 1:
			flip_end_t = t
			x_at_flip_end = race.turtle.position.x
		if flip_end_t >= 0.0 and cruise_t < 0.0 \
				and String(race.turtle.state) == "CRUISING" and race.turtle.flip_t <= 0.0:
			cruise_t = t
			speed_at_cruise = race.turtle.speed
			state_at_cruise = String(race.turtle.state)
			break
	result["flip_frames"] = flip_frames
	result["flip_end_t"] = snappedf(flip_end_t, 0.01)
	result["flip_move_px"] = snappedf(x_at_flip_end - x_at_hit, 0.1)
	result["cruise_t"] = snappedf(cruise_t, 0.01)
	result["speed_at_cruise"] = snappedf(speed_at_cruise, 0.1)
	result["state_at_cruise"] = state_at_cruise
	result["accident_delta_total"] = GameManager.accident_count - acc_after_hit
	result["bro_delta_total"] = GameManager.bro_meter - bro_after_hit
	result["accident_count"] = GameManager.accident_count
	result["bro_meter"] = GameManager.bro_meter
	result["turtle_state_end"] = String(race.turtle.state)
	result["turtle_speed_end"] = snappedf(race.turtle.speed, 0.1)
	result["turtle_base_speed"] = race.turtle.base_speed
	result["turtle_accident_end"] = race.turtle.accident
	result["control_end"] = GameManager.current_control
	result["mount_end"] = String(race.mount.state)
	result["accident_state_end"] = String(GameManager.accident_state)
	return result


## 3) 翻肚皮期间不穿墙：贴着浮木一路前进，壳不能被“推过去”。
func _case_flip_no_clip() -> Dictionary:
	_clean()
	race.test_disable_hazards = false
	var log_group := {}
	for g in race.hazard_groups:
		if String(g["kind"]) == "FLOATING_LOG":
			log_group = g
			break
	if log_group.is_empty():
		race.test_disable_hazards = true
		failures.append("flip_no_clip: no FLOATING_LOG in level")
		return {}
	var rect: Rect2 = race.hazard_rect_live(log_group, 0)
	# 壳的最右沿放在浮木左沿前 6 px：下一帧就会顶上去。
	var center_y: float = (rect.position.y + rect.end.y) * 0.5
	race.turtle.reset(Vector2(rect.position.x - 6.0 - 48.0, center_y))
	race.turtle.base_speed = 220.0
	race.turtle.speed = 220.0
	GameManager.current_control = "turtle"
	race.turtle.start_flip()
	var frames := 0
	var flip_frames := 0
	var max_right := -1.0e9
	var crossed := false
	var overlap_frames := 0
	var contact_frames := 0
	var t := 0.0
	while t < 1.2 and frames < 200:
		race._physics_process(STEP)
		t += STEP
		frames += 1
		if race.turtle.flip_t > 0.0:
			flip_frames += 1
		var tr: Rect2 = race.turtle.get_body_rect()
		max_right = maxf(max_right, tr.end.x)
		if tr.intersects(rect):
			overlap_frames += 1
		# 判“穿过去”：壳中心越过浮木右沿，且从未与浮木相交过。
		if race.turtle.position.x > rect.end.x and overlap_frames == 0:
			crossed = true
		if GameManager.accident_count > 0:
			contact_frames += 1
	race.test_disable_hazards = true
	return {
		"log_rect": [snappedf(rect.position.x, 0.1), snappedf(rect.position.y, 0.1),
			snappedf(rect.end.x, 0.1), snappedf(rect.end.y, 0.1)],
		"frames": frames,
		"flip_frames": flip_frames,
		"max_shell_right_x": snappedf(max_right, 0.1),
		"log_left_x": snappedf(rect.position.x, 0.1),
		"intersect_frames": overlap_frames,
		"crossed_without_contact": crossed,
		"turtle_x": snappedf(race.turtle.position.x, 0.1),
		"turtle_y": snappedf(race.turtle.position.y, 0.1),
	}


## 4) 正式赛道真实输入：按 ↑ 撞低梁 → 兔子落水 → SHIFT 换乌龟 ↓ 接住；
##    不开躲避直接撞鲨鱼 → 乌龟被掀翻。两段都在 load_level 后的正式布局上跑。
func _case_formal_track() -> Dictionary:
	var result := {}
	# --- A：鲨鱼 → 乌龟掀翻 ---
	_clean()
	race.test_disable_hazards = false
	var shark := _first_group("SHARK")
	if shark.is_empty():
		race.test_disable_hazards = true
		failures.append("formal_track: no SHARK group")
		return result
	var srect: Rect2 = race.hazard_rect_live(shark, 0)
	race.turtle.reset(Vector2(srect.position.x - 220.0, Tuning.NEUTRAL_DEPTH))
	race.turtle.speed = 220.0
	GameManager.current_control = "turtle"
	var t := 0.0
	var frame := 0
	var flip_seen := false
	var flip_start_t := -1.0
	var x_at_flip := 0.0
	var x_after := 0.0
	while t < 4.0 and frame < 300:
		race._physics_process(STEP)
		t += STEP
		frame += 1
		if not flip_seen and race.turtle.flip_t > 0.0:
			flip_seen = true
			flip_start_t = t
			x_at_flip = race.turtle.position.x
		if flip_seen and race.turtle.flip_t <= 0.0:
			x_after = race.turtle.position.x
			break
	result["flip_triggered"] = flip_seen
	result["flip_move_px"] = snappedf(x_after - x_at_flip, 0.1)
	result["flip_time_s"] = snappedf(t - flip_start_t, 0.01)
	result["flip_state"] = String(race.turtle.state)
	result["flip_accident_state"] = String(GameManager.accident_state)
	result["flip_accident_count"] = GameManager.accident_count
	# --- B：低梁 → 兔子落水 → 救援 ---
	race.test_disable_hazards = true
	_clean()
	var beam := _first_group("LOW_BEAM")
	if beam.is_empty():
		beam = _first_group("LOW_BIRD")
	if beam.is_empty():
		failures.append("formal_track: no LOW_BEAM/LOW_BIRD group")
		return result
	var brect: Rect2 = race.hazard_rect_live(beam, 0)
	race.turtle.reset(Vector2(brect.position.x - 90.0, Tuning.NEUTRAL_DEPTH))
	race.turtle.speed = 220.0
	GameManager.set_control("rabbit")
	race.test_disable_hazards = false
	Input.action_release("up")
	Input.action_release("down")
	t = 0.0
	frame = 0
	var jumped := false
	var water_seen := false
	var water_t := -1.0
	while t < 3.0 and frame < 200:
		if not jumped and t >= 0.05:
			Input.action_press("up")
			jumped = true
		elif jumped and t >= 0.1:
			Input.action_release("up")
		race._physics_process(STEP)
		t += STEP
		frame += 1
		if GameManager.accident_state == "RABBIT_WATER":
			water_seen = true
			water_t = t
			break
	Input.action_release("up")
	result["rabbit_water_triggered"] = water_seen
	result["rabbit_water_t"] = snappedf(water_t, 0.01)
	var caught := false
	var rescue_t := -1.0
	if water_seen:
		GameManager.set_control("turtle")
		Input.action_press("down")
		var rt := 0.0
		while rt < 4.0 and frame < 500:
			race._physics_process(STEP)
			rt += STEP
			t += STEP
			frame += 1
			if String(race.rescue_last_result) == "caught" \
					and String(race.mount.state) == "RIDING":
				caught = true
				rescue_t = rt
				break
		Input.action_release("down")
	result["rescue_caught"] = caught
	result["rescue_after_water_s"] = snappedf(rescue_t, 0.01)
	result["rescue_success_count"] = GameManager.rescue_success_count
	result["final_accident_state"] = String(GameManager.accident_state)
	result["final_mount"] = String(race.mount.state)
	race.test_disable_hazards = true
	Input.action_release("up")
	Input.action_release("down")
	return result


func _first_group(kind: String) -> Dictionary:
	for g in race.hazard_groups:
		if String(g["kind"]) == kind:
			return g
	return {}


## 5) 源码接线。
func _source_check() -> Dictionary:
	var race_src := FileAccess.get_file_as_string("res://scripts/race.gd")
	var turtle_src := FileAccess.get_file_as_string("res://scripts/actors/turtle_controller.gd")
	return {
		"contact_calls_start_flip": race_src.contains("turtle.start_flip()"),
		"draw_uses_flip_t": race_src.contains("turtle.flip_t > 0.0"),
		"flip_decrements": turtle_src.contains("flip_t = maxf(flip_t - delta, 0.0)"),
		"splash_sets_pos": race_src.contains("rescue_splash_pos = rabbit.position"),
	}


func _evaluate() -> void:
	var sp: Dictionary = out["rabbit_splash"]
	_expect("rabbit: splash at the real water-entry point (err=%.2f px)"
		% float(sp.get("splash_err_px", 999.0)),
		float(sp.get("splash_err_px", 999.0)) >= 0.0
		and float(sp.get("splash_err_px", 999.0)) <= 2.0)
	_expect("rabbit: splash lands on the waterline (y-entry=%.1f)"
		% float(sp.get("splash_y_minus_entry", 999.0)),
		absf(float(sp.get("splash_y_minus_entry", 999.0))) <= 12.0)
	var rw: Dictionary = out["rabbit_water"]
	_expect("rabbit: no teleport (max implied %.1f px/s <= %.0f)"
		% [float(rw.get("max_implied_speed", 1.0e9)), MAX_IMPLIED_SPEED],
		float(rw.get("max_implied_speed", 1.0e9)) <= MAX_IMPLIED_SPEED)
	_expect("rabbit: rescued (result=%s)" % String(rw.get("last_result", "")),
		String(rw.get("last_result", "")) == "caught"
		and int(rw.get("recovered_frame", -1)) > 0)
	_expect("rabbit: in-water phase visible (water_frames=%d)"
		% int(rw.get("water_frames", 0)), int(rw.get("water_frames", 0)) >= 10)
	_expect("rabbit: carry-back phase visible (carry_frames=%d)"
		% int(rw.get("carry_frames", 0)), int(rw.get("carry_frames", 0)) >= 10)

	var fl: Dictionary = out["flip"]
	_expect("flip: wave hit sets flip_t (%.2f)"
		% float(fl.get("flip_t_at_hit", 0.0)),
		is_equal_approx(float(fl.get("flip_t_at_hit", 0.0)), Tuning.FLIP_TIME))
	_expect("flip: not an accident state", not bool(fl.get("turtle_accident", true)))
	_expect("flip: fits the time cap (%.2f s <= 1.0)" % float(fl.get("flip_end_t", 9.0)),
		float(fl.get("flip_end_t", 9.0)) > 0.0 and float(fl.get("flip_end_t", 9.0)) <= 1.0)
	_expect("flip: no extra penalty (accident +%d, bro +%d after)"
		% [int(fl.get("accident_delta_total", 9)), int(fl.get("bro_delta_total", 9))],
		int(fl.get("accident_delta_total", 9)) == 0
		and int(fl.get("bro_delta_total", 9)) == 0)
	_expect("flip: back to normal cruising (state=%s speed=%.0f at t=%.2f)"
		% [String(fl.get("turtle_state_end", "")),
			float(fl.get("turtle_speed_end", 0.0)), float(fl.get("cruise_t", -1.0))],
		String(fl.get("turtle_state_end", "")) == "CRUISING"
		and float(fl.get("cruise_t", -1.0)) > 0.0
		and absf(float(fl.get("turtle_speed_end", 0.0))
			- float(fl.get("turtle_base_speed", 220.0))) <= 10.0)
	_expect("flip: control and mount unchanged",
		String(fl.get("control_end", "")) == "turtle"
		and String(fl.get("mount_end", "")) == "RIDING"
		and String(fl.get("accident_state_end", "")) == "NONE")

	var nc: Dictionary = out["flip_no_clip"]
	_expect("flip_no_clip: flip was active while advancing (flip_frames=%d)"
		% int(nc.get("flip_frames", 0)), int(nc.get("flip_frames", 0)) >= 10)
	_expect("flip_no_clip: never crossed without contact (max right %.1f < log right)"
		% float(nc.get("max_shell_right_x", 0.0)),
		not bool(nc.get("crossed_without_contact", true)))

	var ft: Dictionary = out["formal_track"]
	_expect("formal: shark contact flips the turtle on the real track",
		bool(ft.get("flip_triggered", false)))
	_expect("formal: flip does not freeze play (moved %.0f px while flipped)"
		% float(fl.get("flip_move_px", 0.0)),
		float(fl.get("flip_move_px", 0.0)) >= 80.0)
	_expect("formal: flip ends within 1.0 s (%.2f s)"
		% float(ft.get("flip_time_s", 9.0)),
		float(ft.get("flip_time_s", 9.0)) > 0.0
		and float(ft.get("flip_time_s", 9.0)) <= 1.0)
	_expect("formal: beam hit drops the rabbit into water on the real track",
		bool(ft.get("rabbit_water_triggered", false)))
	_expect("formal: SHIFT + dive rescues the rabbit on the real track",
		bool(ft.get("rescue_caught", false))
		and String(ft.get("final_accident_state", "")) == "NONE"
		and String(ft.get("final_mount", "")) == "RIDING")
	_expect("formal: rescue has a reasonable action window (%.2f s)"
		% float(ft.get("rescue_after_water_s", 9.0)),
		float(ft.get("rescue_after_water_s", 9.0)) > 0.0
		and float(ft.get("rescue_after_water_s", 9.0)) < 3.0)

	var src: Dictionary = out["source"]
	_expect("source: race calls turtle.start_flip()",
		bool(src.get("contact_calls_start_flip", false)))
	_expect("source: turtle flip drawn from flip_t", bool(src.get("draw_uses_flip_t", false)))
	_expect("source: flip_t decrements in tick", bool(src.get("flip_decrements", false)))
	_expect("source: splash at real rabbit position", bool(src.get("splash_sets_pos", false)))


func _expect(what: String, ok: bool) -> void:
	if not ok:
		failures.append(what)


func _write() -> void:
	var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if file == null:
		failures.append("cannot write " + OUT_PATH)
		return
	file.store_string(JSON.stringify({
		"generated_at": Time.get_datetime_string_from_system(),
		"note": "P5 角色反馈：直接跑正式 race.gd 的落水/救援与浪击掀翻；引擎输入代理，不是真人试玩。",
		"data": out,
		"failures": failures,
	}, "  "))
	file.close()
