extends Node
## TBB-SHIFT-PLAYFUL-04 §4：SHIFT 的小幅正向反馈审查。
## REBUILD-06 P4 更新：食物改成“控制谁就谁吃”——
##   乌龟吃到 = 原有 TURBO + 冷静；兔子吃到 = 兔子跳跃强化，乌龟不加速。
##
## 只看四件事，不做新状态、不加惩罚：
##   1) 食物可读性（远处能看到、会不会自己亮）；
##   2) 操控乌龟吃到 → TURBO + 冷静 + 亲手喂到奖励；
##   3) 操控兔子吃到 → 兔子跳跃强化，乌龟不加速；
##   4) 不操控兔子时，兔子自己不会持续制造危险。
##
## 输出：docs/reports/longrun/playful04-shift-reward.json

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/playful04-shift-reward.json"
const STEP := 1.0 / 60.0

var is_runner := false
var race: Node = null
var data := {}
var failures: Array = []
var feedback_log: Array = []


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
	Locale.language = "zh"
	GameManager.start_race()
	for i in 4:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null:
		push_error("SHIFT REWARD: no race scene")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_disable_hazards = true
	race.test_no_finish = true
	# 食物就挂在 boost_lanes 上（snack_encounters 由它们生成），这里不能清空。
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	GameManager.feedback.connect(func(text: String, _style: String) -> void:
		feedback_log.append(text))

	data["english"] = _english()
	data["readability"] = _case_readability()
	data["feed_as_turtle"] = _case_feed("turtle")
	data["feed_as_rabbit"] = _case_feed("rabbit")
	data["skip_food"] = _case_skip()
	data["autonomous_rabbit"] = _case_autonomous()

	_evaluate()
	_write()
	print("SHIFT REWARD: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _english() -> Dictionary:
	Locale.language = "en"
	var out := {
		"turbo": Locale.t("feedback.turbo"),
		"turbo_switch": Locale.t("feedback.turbo_switch"),
		"hint_snack": Locale.t("hint.snack"),
		"world_snack": Locale.t("world.snack"),
	}
	Locale.language = "zh"
	return out


func _clean() -> void:
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.clear_bro_meter()
	GameManager.accident_count = 0
	GameManager.total_score = 0
	GameManager.score_log.clear()
	GameManager.rabbit_casualties = 0
	GameManager.turtle_failures = 0
	GameManager.current_control = "rabbit"
	race.showtime_active = false
	race.joint_show_t = 0.0
	race.finishing = false
	race.hazard_cooldown = 0.0
	race.rabbit_stun = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.emergency_timer = 0.0
	# G20：hit_roles 必须和 hit_groups 一起清。只清 hit_groups 时，B2 起的“角色×组”记账还留着，同组第二例起整组免疫——后面那些重复用例其实在测一段不会撞的赛道。
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
	race.snack_last_by = ""
	race.snack_last_eaten = ""
	race.rabbit_boost_until_x = -1.0
	race.snack_interest_x = -1.0
	race.rabbit.jump_boost = 1.0
	feedback_log.clear()
	for enc in race._snack_list():
		enc["eaten"] = false


func _first_snack() -> Dictionary:
	var list: Array = race._snack_list()
	return list[0] if not list.is_empty() else {}


## 1) 可读性：食物在远处就被 world 层点亮，乌龟会朝它偏。
func _case_readability() -> Dictionary:
	_clean()
	var enc := _first_snack()
	var out := {"encounter_x": float(enc.get("x", 0.0))}
	if enc.is_empty():
		failures.append("readability: no snack encounter")
		return out
	# snack_ahead_distance 是“多远能看到有吃的”的判定源。
	race.turtle.position = Vector2(float(enc["x"]) - 900.0, Tuning.NEUTRAL_DEPTH)
	race.turtle.food_ahead = race.snack_ahead_distance()
	out["ahead_900"] = race.turtle.food_ahead
	race.turtle.position = Vector2(float(enc["x"]) - 40.0, Tuning.NEUTRAL_DEPTH)
	race.turtle.food_ahead = race.snack_ahead_distance()
	out["ahead_40"] = race.turtle.food_ahead
	# 龟在走神时闻到吃的会朝食物偏（+x / +y，朝前下方），这是“它想过去”的可读信号。
	# 只影响画法，不改变碰撞。
	# 画法读的是乌龟自己的 drift/drift_state（每帧由 brain 同步过来）。
	race.turtle.drift = Tuning.DRIFT_CAP
	race.turtle.drift_state = "MISCHIEF"
	race.turtle.food_ahead = race.snack_ahead_distance()
	var lean: Vector2 = race.turtle.drift_look_px(false)
	out["lean_toward_food"] = [snappedf(lean.x, 0.1), snappedf(lean.y, 0.1)]
	out["drift_state"] = race.turtle.drift_state
	out["eaten_false"] = not bool(enc.get("eaten", false))
	_expect("readability: food reads as ahead from 900 px (%.0f)"
		% float(out["ahead_900"]), float(out["ahead_900"]) >= 0.0)
	_expect("readability: an unattended turtle looks toward the food (%s)"
		% str(out["lean_toward_food"]),
		lean.x > 0.0 and lean.y > 0.0)
	return out


## 2/3) 控制谁就谁吃：乌龟吃到是 TURBO，兔子吃到是跳跃强化。
func _case_feed(control: String) -> Dictionary:
	_clean()
	GameManager.current_control = control
	var enc := _first_snack()
	var out := {"control": control}
	if enc.is_empty():
		failures.append("feed_%s: no snack" % control)
		return out
	race.turtle.position = Vector2(float(enc["x"]), Tuning.NEUTRAL_DEPTH)
	race.rabbit.attach(race.turtle.get_mount_point())
	race.turtle_brain.drift = 0.8
	out["drift_before"] = race.turtle_brain.drift
	out["interest_before"] = race._nearest_snack_ahead(Tuning.SNACK_INTEREST_PX)
	race._update_snack(STEP)
	out["eaten"] = bool(enc.get("eaten", false))
	out["eaten_by"] = race.snack_last_by
	out["drift_after"] = race.turtle_brain.drift
	out["boost_until_x"] = race.snack_boost_until_x
	out["boost_speed"] = race.snack_boost_speed
	out["turtle_boost_active"] = race.snack_boost_active()
	out["rabbit_boost_until_x"] = race.rabbit_boost_until_x
	out["rabbit_jump_boost"] = race.rabbit.jump_boost
	out["rabbit_boost_active"] = race.snack_rabbit_boost_active()
	out["gulp_by_player"] = race.snack_gulp_by_player
	out["feedback"] = feedback_log[feedback_log.size() - 1] if not feedback_log.is_empty() else ""
	out["score"] = GameManager.total_score
	var bonuses: Array = []
	for e in GameManager.score_log:
		if String(e.get("reason", "")) == "snack_switch":
			bonuses.append(int(e.get("points", 0)))
	out["switch_bonus_entries"] = bonuses
	out["accident_count"] = GameManager.accident_count
	out["bro_meter"] = GameManager.bro_meter
	return out


## 3) 没吃到：只是错过机会，没有扣分、没有记事故、没有额外失衡。
func _case_skip() -> Dictionary:
	_clean()
	GameManager.current_control = "rabbit"
	var enc := _first_snack()
	var out := {}
	if enc.is_empty():
		failures.append("skip: no snack")
		return out
	# 在水下路过（比巡航深 60 px），食物判定够不到。
	race.turtle.position = Vector2(float(enc["x"]), Tuning.NEUTRAL_DEPTH + 60.0)
	race.turtle_brain.drift = 0.3
	out["drift_before"] = race.turtle_brain.drift
	for i in 30:
		race._update_snack(STEP)
	out["eaten"] = bool(enc.get("eaten", false))
	out["drift_after"] = race.turtle_brain.drift
	out["score"] = GameManager.total_score
	out["score_log_size"] = GameManager.score_log.size()
	out["accident_count"] = GameManager.accident_count
	out["bro_meter"] = GameManager.bro_meter
	out["boost_active"] = race.snack_boost_active()
	return out


## 4) 玩家在乌龟身上时，兔子自己不会动：没有自发的跳跃/离壳/掉水。
func _case_autonomous() -> Dictionary:
	_clean()
	GameManager.current_control = "turtle"
	Input.action_release("down")
	Input.action_release("up")
	var max_offset := 0.0
	var states := {}
	var mischief_frames := 0
	var ticks := 360
	race.turtle.position = Vector2(5000.0, Tuning.NEUTRAL_DEPTH)
	for i in ticks:
		race._physics_process(STEP)
		var off: float = race.rabbit.position.distance_to(
			race.turtle.get_mount_point())
		max_offset = maxf(max_offset, off)
		var st := String(race.mount.state)
		states[st] = int(states.get(st, 0)) + 1
		if bool(race.rabbit.mischief_pose):
			mischief_frames += 1
	var out := {
		"seconds": float(ticks) * STEP,
		"max_offset_from_mount": snappedf(max_offset, 0.01),
		"mount_states": states,
		"mischief_frames": mischief_frames,
		"accident_count": GameManager.accident_count,
		"rabbit_state": race.rabbit.state,
	}
	return out


func _evaluate() -> void:
	var a: Dictionary = data["feed_as_turtle"]
	var b: Dictionary = data["feed_as_rabbit"]
	var s: Dictionary = data["skip_food"]
	var r: Dictionary = data["autonomous_rabbit"]

	# 亲手喂到：
	_expect("feed_as_turtle: eaten", bool(a.get("eaten", false)))
	_expect("feed_as_turtle: feedback is the special one",
		String(a.get("feedback", "")) == Locale.t("feedback.turbo_switch"))
	_expect("feed_as_turtle: gulp marked as player-fed", bool(a.get("gulp_by_player", false)))
	_expect("feed_as_turtle: +%d bonus recorded (%s)"
		% [Tuning.SNACK_SWITCH_BONUS, str(a.get("switch_bonus_entries", []))],
		int(a.get("score", 0)) == Tuning.SNACK_SWITCH_BONUS
		and (a.get("switch_bonus_entries", []) as Array).size() == 1)
	_expect("feed_as_turtle: calms the turtle (drift 0)",
		is_equal_approx(float(a.get("drift_after", -1.0)), 0.0))
	_expect("feed_as_turtle: turtle boost on, rabbit boost off",
		bool(a.get("turtle_boost_active", false))
		and not bool(a.get("rabbit_boost_active", true))
		and is_equal_approx(float(a.get("rabbit_jump_boost", 0.0)), 1.0))

	# P4：控制兔子 → 兔子吃。兔子得到跳跃强化，乌龟完全不加速、不冷静、不加分。
	_expect("feed_as_rabbit: eaten by the rabbit",
		bool(b.get("eaten", false)) and String(b.get("eaten_by", "")) == "rabbit")
	_expect("feed_as_rabbit: rabbit jump boost %.2f active until x=%.0f"
		% [float(b.get("rabbit_jump_boost", 0.0)), float(b.get("rabbit_boost_until_x", 0.0))],
		is_equal_approx(float(b.get("rabbit_jump_boost", 0.0)),
			Tuning.RABBIT_SNACK_JUMP_SCALE)
		and bool(b.get("rabbit_boost_active", false)))
	_expect("feed_as_rabbit: turtle gets no turbo",
		not bool(b.get("turtle_boost_active", true))
		and is_equal_approx(float(b.get("boost_speed", 0.0)), 0.0))
	_expect("feed_as_rabbit: turtle is not calmed (drift stays %.2f)"
		% float(b.get("drift_after", -1.0)),
		float(b.get("drift_after", 0.0)) >= float(b.get("drift_before", 0.0)) - 0.001)
	_expect("feed_as_rabbit: no snack bonus",
		int(b.get("score", 0)) == 0
		and (b.get("switch_bonus_entries", []) as Array).is_empty())
	_expect("feed_as_rabbit: feedback names the rabbit",
		String(b.get("feedback", "")) == Locale.t("feedback.snack_rabbit"))

	# 没吃到：什么都不扣。
	_expect("skip_food: not eaten", not bool(s.get("eaten", false)))
	_expect("skip_food: no score change (%d) and no score entries (%d)"
		% [int(s.get("score", 0)), int(s.get("score_log_size", 0))],
		int(s.get("score", 0)) == 0 and int(s.get("score_log_size", 0)) == 0)
	_expect("skip_food: no accident, no bro slot",
		int(s.get("accident_count", -1)) == 0 and int(s.get("bro_meter", -1)) == 0)
	_expect("skip_food: no extra drift penalty (%.2f -> %.2f)"
		% [float(s.get("drift_before", 0.0)), float(s.get("drift_after", 0.0))],
		float(s.get("drift_after", 1.0)) <= float(s.get("drift_before", 0.0)) + 0.001)
	_expect("skip_food: no boost",
		not bool(s.get("boost_active", true)))

	# 兔子自主：一直贴着壳，没有自己跳/掉。
	# 骑乘跟随有一点点平滑滞后（不是漂移），但远小于半个身体。
	_expect("autonomous_rabbit: stays on the shell (max offset %.2f px)"
		% float(r.get("max_offset_from_mount", 999.0)),
		float(r.get("max_offset_from_mount", 999.0)) <= 16.0)
	_expect("autonomous_rabbit: never airborne on its own (%s)"
		% str(r.get("mount_states", {})),
		not (r.get("mount_states", {}) as Dictionary).has("AIRBORNE"))
	_expect("autonomous_rabbit: no accident from its own behavior",
		int(r.get("accident_count", -1)) == 0)


func _expect(what: String, ok: bool) -> void:
	if not ok:
		failures.append(what)


func _write() -> void:
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		failures.append("cannot write " + OUT_PATH)
		return
	f.store_string(JSON.stringify({
		"generated_at": Time.get_datetime_string_from_system(),
		"note": "SHIFT 正向反馈审查：直接调用正式 race.gd 的食物/物理逻辑；自动探针，不是真人试玩。",
		"data": data,
		"failures": failures,
	}, "  "))
	f.close()
