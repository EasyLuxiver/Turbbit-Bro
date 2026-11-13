extends Node
## TBB-EXPERIENCE-REFINE-06 P4：食物争夺探针。
##
## 直接调用正式 race.gd 的食物逻辑（不复制规则），只测不调：
##   1) SHIFT 决定归属：同一份食物，控乌龟 → 乌龟吃；控兔子 → 兔子吃；
##   2) 乌龟吃 = 原有 TURBO 加速 + 冷静 + 亲手喂到奖励；
##   3) 兔子吃 = 兔子跳跃强化（初速 ×1.15），乌龟不加速、不冷静、不加分；
##   4) 兔子在空中时食物从壳下经过 → 没吃到，但什么都不扣；
##   5) 跳跃强化的实际峰值：普通跳 vs 强化跳，用同一套 tick_air 逐帧量；
##   6) 争抢提示窗口：食物进入 320 px 才有提示，320/区速 = 反应时间；
##   7) 正式赛道的食物布局（默认种子抽取之后）与源码接线检查。
##
## 输出：docs/reports/longrun/refine06-p4-snack-contest.json
## 运行：godot --headless --path TURBBIT res://scenes/stage4_snack_contest.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/refine06-p4-snack-contest.json"
const STEP := 1.0 / 60.0

var is_runner := false
var race: Node = null
var out := {}
var failures: Array = []
var feedback_log: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4SnackContestRunner"
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
		push_error("P4 SNACK: no race scene")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_disable_hazards = true
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	GameManager.feedback.connect(func(text: String, _style: String) -> void:
		feedback_log.append(text))

	out["constants"] = {
		"interest_px": Tuning.SNACK_INTEREST_PX,
		"rabbit_jump_scale": Tuning.RABBIT_SNACK_JUMP_SCALE,
		"rabbit_tail_px": Tuning.RABBIT_SNACK_TAIL,
		"contact_px": LevelData.SNACK_CONTACT_PX,
	}
	out["shift_decides"] = _case_shift_decides()
	out["turtle_eat"] = _case_feed("turtle")
	out["rabbit_eat"] = _case_feed("rabbit")
	out["rabbit_airborne_skip"] = _case_airborne_skip()
	out["jump_peak"] = _case_jump_peak()
	out["eat_then_jump"] = _case_eat_then_jump()
	out["interest_window"] = _case_interest_window()
	out["formal_track"] = _formal_track()
	out["source"] = _source_check()

	_evaluate()
	_write()
	print("P4 SNACK CONTEST: " + ("PASS" if failures.is_empty() else "FAIL"))
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
	GameManager.snack_switch_count = 0
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
	race.reset_brains()
	race.turtle.reset(Vector2(5000.0, Tuning.NEUTRAL_DEPTH))
	race.turtle.base_speed = 220.0
	race.turtle.speed = 220.0
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	race.snack_boost_until_x = -1.0
	race.snack_boost_speed = 0.0
	race.snack_gulp_t = 0.0
	race.snack_gulp_by_player = false
	race.snack_last_eaten = ""
	race.snack_last_by = ""
	race.rabbit_boost_until_x = -1.0
	race.rabbit.jump_boost = 1.0
	race.snack_interest_x = -1.0
	feedback_log.clear()
	for enc in race._snack_list():
		enc["eaten"] = false


func _first_snack() -> Dictionary:
	var list: Array = race._snack_list()
	return list[0] if not list.is_empty() else {}


func _group_end_for(obstacle_group: String) -> float:
	for g in race.hazard_groups:
		if String(g["group"]) == obstacle_group:
			return race._group_end(g)
	return -1.0


## 1) 同一份食物、同一个位置，只换操控 → 吃到的角色跟着换。
func _case_shift_decides() -> Dictionary:
	var rows := {}
	for control in ["turtle", "rabbit"]:
		_clean()
		GameManager.current_control = control
		var enc := _first_snack()
		if enc.is_empty():
			failures.append("shift_decides: no snack")
			return rows
		race.turtle.position = Vector2(float(enc["x"]), Tuning.NEUTRAL_DEPTH)
		race.rabbit.attach(race.turtle.get_mount_point())
		race._update_snack(STEP)
		rows[control] = {
			"eaten": bool(enc.get("eaten", false)),
			"eaten_by": race.snack_last_by,
			"feedback": feedback_log[feedback_log.size() - 1] if not feedback_log.is_empty() else "",
		}
	return rows


## 2/3) 谁吃谁拿到什么。
func _case_feed(control: String) -> Dictionary:
	_clean()
	GameManager.current_control = control
	var enc := _first_snack()
	var result := {"control": control}
	if enc.is_empty():
		failures.append("feed_%s: no snack" % control)
		return result
	var x := float(enc["x"])
	var obstacle := String(enc.get("obstacle_group", ""))
	race.turtle.position = Vector2(x, Tuning.NEUTRAL_DEPTH)
	race.rabbit.attach(race.turtle.get_mount_point())
	race.turtle_brain.drift = 0.8
	result["drift_before"] = race.turtle_brain.drift
	var score_before := GameManager.total_score
	var fed_before := GameManager.snack_switch_count
	race._update_snack(STEP)
	result["eaten"] = bool(enc.get("eaten", false))
	result["eaten_by"] = race.snack_last_by
	result["drift_after"] = race.turtle_brain.drift
	result["turtle_boost_active"] = race.snack_boost_active()
	result["boost_speed"] = race.snack_boost_speed
	result["boost_until_x"] = race.snack_boost_until_x
	result["zone_speed"] = float(race.current_zone["base_speed"])
	result["rabbit_boost_active"] = race.snack_rabbit_boost_active()
	result["rabbit_jump_boost"] = race.rabbit.jump_boost
	result["rabbit_boost_until_x"] = race.rabbit_boost_until_x
	result["rabbit_boost_expected_x"] = _group_end_for(obstacle) + Tuning.RABBIT_SNACK_TAIL
	result["score_delta"] = GameManager.total_score - score_before
	result["fed_delta"] = GameManager.snack_switch_count - fed_before
	result["gulp_t"] = race.snack_gulp_t
	result["feedback"] = feedback_log[feedback_log.size() - 1] if not feedback_log.is_empty() else ""
	result["accident_count"] = GameManager.accident_count
	result["bro_meter"] = GameManager.bro_meter
	return result


## 4) 兔子在空中：食物从壳下经过，吃不到，但没有惩罚。
func _case_airborne_skip() -> Dictionary:
	_clean()
	GameManager.current_control = "rabbit"
	var enc := _first_snack()
	var result := {}
	if enc.is_empty():
		failures.append("airborne_skip: no snack")
		return result
	race.turtle.position = Vector2(float(enc["x"]), Tuning.NEUTRAL_DEPTH)
	race.rabbit.launch(race.turtle.get_mount_point(), 0.0)
	result["airborne_at_start"] = race.rabbit.is_airborne()
	for i in 20:
		race._update_snack(STEP)
	result["eaten"] = bool(enc.get("eaten", false))
	result["turtle_boost_active"] = race.snack_boost_active()
	result["rabbit_boost_active"] = race.snack_rabbit_boost_active()
	result["score"] = GameManager.total_score
	result["score_log_size"] = GameManager.score_log.size()
	result["accident_count"] = GameManager.accident_count
	result["bro_meter"] = GameManager.bro_meter
	result["feedback_count"] = feedback_log.size()
	return result


## 5) 实际跳跃峰值：同一段 tick_air，普通跳 vs 强化跳。
func _case_jump_peak() -> Dictionary:
	_clean()
	var mount: Vector2 = race.turtle.get_mount_point()
	var normal := _peak(mount, 1.0)
	var boosted := _peak(mount, Tuning.RABBIT_SNACK_JUMP_SCALE)
	race.rabbit.jump_boost = 1.0
	return {
		"normal_px": snappedf(normal, 0.1),
		"boosted_px": snappedf(boosted, 0.1),
		"ratio": snappedf(boosted / maxf(normal, 0.001), 0.01),
	}


func _peak(mount: Vector2, boost: float) -> float:
	race.rabbit.reset()
	race.rabbit.jump_boost = boost
	race.rabbit.attach(mount)
	var y0: float = race.rabbit.position.y
	race.rabbit.launch(mount, 0.0)
	var best := 0.0
	for i in 300:
		race.rabbit.tick_air(STEP, false)
		best = maxf(best, y0 - race.rabbit.position.y)
		if race.rabbit.velocity.y >= 0.0:
			break
	return best


## 吃到之后再跳一次：不手动改 jump_boost，直接量“吃完这一刻”的峰值。
func _case_eat_then_jump() -> Dictionary:
	_clean()
	GameManager.current_control = "rabbit"
	var enc := _first_snack()
	var result := {}
	if enc.is_empty():
		failures.append("eat_then_jump: no snack")
		return result
	race.turtle.position = Vector2(float(enc["x"]), Tuning.NEUTRAL_DEPTH)
	race.rabbit.attach(race.turtle.get_mount_point())
	race._update_snack(STEP)
	result["eaten_by"] = race.snack_last_by
	result["jump_boost_after_eat"] = race.rabbit.jump_boost
	var mount: Vector2 = race.turtle.get_mount_point()
	var boosted := _peak_keep_boost(mount)
	race.rabbit.jump_boost = 1.0
	var normal := _peak_keep_boost(mount)
	result["boosted_px"] = snappedf(boosted, 0.1)
	result["normal_px"] = snappedf(normal, 0.1)
	result["ratio"] = snappedf(boosted / maxf(normal, 0.001), 0.01)
	return result


func _peak_keep_boost(mount: Vector2) -> float:
	race.rabbit.reset()
	race.rabbit.attach(mount)
	var y0: float = race.rabbit.position.y
	race.rabbit.launch(mount, 0.0)
	var best := 0.0
	for i in 300:
		race.rabbit.tick_air(STEP, false)
		best = maxf(best, y0 - race.rabbit.position.y)
		if race.rabbit.velocity.y >= 0.0:
			break
	return best


## 6) 争抢提示窗口：320 px 内才亮；两角色都够得着（都在壳上、巡航深度）。
func _case_interest_window() -> Dictionary:
	_clean()
	GameManager.current_control = "turtle"
	var enc := _first_snack()
	var result := {}
	if enc.is_empty():
		failures.append("interest: no snack")
		return result
	var x := float(enc["x"])
	var v := float(race.current_zone["base_speed"])
	race.turtle.position = Vector2(x - Tuning.SNACK_INTEREST_PX, Tuning.NEUTRAL_DEPTH)
	race.rabbit.attach(race.turtle.get_mount_point())
	race._update_snack(STEP)
	result["interest_at_320"] = race.snack_interest_x
	result["expect_x"] = x
	race.turtle.position = Vector2(x - Tuning.SNACK_INTEREST_PX - 1.0,
		Tuning.NEUTRAL_DEPTH)
	race._update_snack(STEP)
	result["interest_at_321"] = race.snack_interest_x
	# 两个角色都具备“想吃”的身体条件：兔子在壳上、没有晕、乌龟在巡航深度。
	result["rabbit_wants"] = race.mount.state == "RIDING" \
		and not race.rabbit.is_airborne() and race.rabbit.state != "STUNNED"
	result["turtle_wants"] = absf(race.turtle.position.y - Tuning.NEUTRAL_DEPTH) <= 40.0
	result["zone_speed"] = v
	result["reaction_s"] = snappedf(Tuning.SNACK_INTEREST_PX / maxf(v, 1.0), 0.01)
	return result


## 7) 正式赛道：默认种子抽取后的食物布局。
func _formal_track() -> Dictionary:
	var xs: Array = []
	for enc in race._snack_list():
		xs.append(snappedf(float(enc["x"]), 0.1))
	return {"count": xs.size(), "xs": xs}


## 8) 源码接线：判定与画法都真的接进 _update_snack/_draw_snacks。
func _source_check() -> Dictionary:
	var src := FileAccess.get_file_as_string("res://scripts/race.gd")
	return {
		"eater_fn": src.contains("func _snack_eater() -> String:"),
		"eater_used": src.contains("var eater := _snack_eater()"),
		"contest_draw": src.contains("_draw_snack_contest(snack_interest_x)"),
		"want_mark": src.contains("func _draw_want_mark("),
		"rabbit_gulp_mouth": src.contains("if rabbit_ate"),
		"rabbit_fx": src.contains("func _draw_rabbit_boost_fx("),
	}


func _evaluate() -> void:
	var sd: Dictionary = out["shift_decides"]
	_expect("shift: turtle control -> turtle eats (%s)" % str(sd.get("turtle", {})),
		String((sd.get("turtle", {}) as Dictionary).get("eaten_by", "")) == "turtle")
	_expect("shift: rabbit control -> rabbit eats (%s)" % str(sd.get("rabbit", {})),
		String((sd.get("rabbit", {}) as Dictionary).get("eaten_by", "")) == "rabbit")

	var t: Dictionary = out["turtle_eat"]
	_expect("turtle_eat: eaten by turtle",
		bool(t.get("eaten", false)) and String(t.get("eaten_by", "")) == "turtle")
	_expect("turtle_eat: TURBO at zone speed x1.15 (%.1f)"
		% float(t.get("boost_speed", 0.0)),
		bool(t.get("turtle_boost_active", false))
		and is_equal_approx(float(t.get("boost_speed", 0.0)),
			float(t.get("zone_speed", 0.0)) * LevelData.SNACK_BOOST_SCALE))
	_expect("turtle_eat: rabbit stays at normal jump (%.2f)"
		% float(t.get("rabbit_jump_boost", 0.0)),
		is_equal_approx(float(t.get("rabbit_jump_boost", 0.0)), 1.0)
		and not bool(t.get("rabbit_boost_active", true)))
	_expect("turtle_eat: calms the turtle and credits hand-feed (%d)"
		% int(t.get("fed_delta", 0)),
		is_equal_approx(float(t.get("drift_after", 1.0)), 0.0)
		and int(t.get("fed_delta", 0)) == 1
		and int(t.get("score_delta", 0)) == Tuning.SNACK_SWITCH_BONUS)
	_expect("turtle_eat: feedback names the turtle",
		String(t.get("feedback", "")) == Locale.t("feedback.turbo_switch"))
	_expect("turtle_eat: gulp fx running (%.2f)" % float(t.get("gulp_t", 0.0)),
		float(t.get("gulp_t", 0.0)) > 0.0)

	var r: Dictionary = out["rabbit_eat"]
	_expect("rabbit_eat: eaten by rabbit",
		bool(r.get("eaten", false)) and String(r.get("eaten_by", "")) == "rabbit")
	_expect("rabbit_eat: jump boost %.2f until x=%.0f (expected %.0f)"
		% [float(r.get("rabbit_jump_boost", 0.0)),
			float(r.get("rabbit_boost_until_x", 0.0)),
			float(r.get("rabbit_boost_expected_x", 0.0))],
		is_equal_approx(float(r.get("rabbit_jump_boost", 0.0)),
			Tuning.RABBIT_SNACK_JUMP_SCALE)
		and bool(r.get("rabbit_boost_active", false))
		and is_equal_approx(float(r.get("rabbit_boost_until_x", 0.0)),
			float(r.get("rabbit_boost_expected_x", 0.0))))
	_expect("rabbit_eat: turtle does NOT get turbo (speed %.1f)"
		% float(r.get("boost_speed", 0.0)),
		not bool(r.get("turtle_boost_active", true))
		and is_equal_approx(float(r.get("boost_speed", 0.0)), 0.0))
	_expect("rabbit_eat: turtle not calmed (drift %.2f -> %.2f)"
		% [float(r.get("drift_before", 0.0)), float(r.get("drift_after", 0.0))],
		float(r.get("drift_after", 0.0)) >= float(r.get("drift_before", 0.0)) - 0.001)
	_expect("rabbit_eat: no score and no hand-feed credit",
		int(r.get("score_delta", -1)) == 0 and int(r.get("fed_delta", -1)) == 0)
	_expect("rabbit_eat: feedback names the rabbit",
		String(r.get("feedback", "")) == Locale.t("feedback.snack_rabbit"))
	_expect("rabbit_eat: gulp fx running (%.2f)" % float(r.get("gulp_t", 0.0)),
		float(r.get("gulp_t", 0.0)) > 0.0)

	var a: Dictionary = out["rabbit_airborne_skip"]
	_expect("airborne_skip: rabbit was airborne", bool(a.get("airborne_at_start", false)))
	_expect("airborne_skip: food not eaten", not bool(a.get("eaten", false)))
	_expect("airborne_skip: no boost either side",
		not bool(a.get("turtle_boost_active", true))
		and not bool(a.get("rabbit_boost_active", true)))
	_expect("airborne_skip: no score / accident / bro slot / feedback",
		int(a.get("score", -1)) == 0 and int(a.get("score_log_size", -1)) == 0
		and int(a.get("accident_count", -1)) == 0
		and int(a.get("bro_meter", -1)) == 0
		and int(a.get("feedback_count", -1)) == 0)

	var j: Dictionary = out["jump_peak"]
	_expect("jump_peak: boosted %.1f px vs normal %.1f px (ratio %.2f, need >=1.25)"
		% [float(j.get("boosted_px", 0.0)), float(j.get("normal_px", 0.0)),
			float(j.get("ratio", 0.0))],
		float(j.get("ratio", 0.0)) >= 1.25)

	var ej: Dictionary = out["eat_then_jump"]
	_expect("eat_then_jump: rabbit ate first (%s)" % str(ej.get("eaten_by", "")),
		String(ej.get("eaten_by", "")) == "rabbit")
	_expect("eat_then_jump: the next jump reaches %.1f px vs %.1f px before (ratio %.2f)"
		% [float(ej.get("boosted_px", 0.0)), float(ej.get("normal_px", 0.0)),
			float(ej.get("ratio", 0.0))],
		float(ej.get("ratio", 0.0)) >= 1.25)

	var i: Dictionary = out["interest_window"]
	_expect("interest: set at exactly 320 px (%.1f)" % float(i.get("interest_at_320", -1.0)),
		is_equal_approx(float(i.get("interest_at_320", -1.0)),
			float(i.get("expect_x", -2.0))))
	_expect("interest: cleared at 321 px (%.1f)" % float(i.get("interest_at_321", 0.0)),
		float(i.get("interest_at_321", 0.0)) < 0.0)
	_expect("interest: both characters can want it",
		bool(i.get("rabbit_wants", false)) and bool(i.get("turtle_wants", false)))
	_expect("interest: %.2f s reaction time at %.0f px/s"
		% [float(i.get("reaction_s", 0.0)), float(i.get("zone_speed", 0.0))],
		float(i.get("reaction_s", 0.0)) >= 1.0)

	var f: Dictionary = out["formal_track"]
	_expect("formal_track: %d snacks loaded" % int(f.get("count", 0)),
		int(f.get("count", 0)) == 9)

	var s: Dictionary = out["source"]
	for k in s.keys():
		_expect("source: %s" % k, bool(s[k]))


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
		"note": "P4 食物争夺：直接调用正式 race.gd 的食物逻辑；引擎输入代理，不是真人试玩。",
		"data": out,
		"failures": failures,
	}, "  "))
	file.close()
