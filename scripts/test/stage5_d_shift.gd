extends Node
## TBB-EXPERIENCE-REBUILD-05 D：SHIFT 正向体验的验收探针。
##
## 判三件事：
##  1. 三种正向切换（障碍连招 / 亲手喂 / 主动接回）各有一条不同的正向反馈
##     与一笔可测收益；不切换只是少拿，不额外扣分。
##  2. 未被控制的角色神游 12 s 不产生事故，BRO METER 仍 0 格，四态顺序不退化。
##  3. 不为“没换人”另立罚项：一次真实的连招失败只记事故本身那一条。
##
## 输出：docs/reports/longrun/rebuild05-d-shift.json
## 运行：godot --headless --path TURBBIT res://scenes/stage5_d_shift.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/rebuild05-d-shift.json"
const STEP := 1.0 / 60.0

var is_runner := false
var race: Node = null
var out := {}
var failures: Array = []
var fb: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage5DShiftRunner"
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
	if race == null or race.hud == null:
		push_error("D SHIFT: no race")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	GameManager.feedback.connect(_on_feedback)

	out["generated_at"] = Time.get_datetime_string_from_system()
	out["cases"] = {}

	out["cases"]["rescue_reward"] = _case_rescue_reward()
	out["cases"]["food_without_switch"] = _case_food(false)
	out["cases"]["food_with_switch"] = _case_food(true)
	out["cases"]["drift_turtle"] = _case_drift("rabbit")
	out["cases"]["drift_rabbit"] = _case_drift("turtle")
	out["cases"]["failed_combo_penalty"] = _case_failed_combo()

	_evaluate()
	_write()
	print("D SHIFT: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _on_feedback(text: String, kind: String) -> void:
	fb.append({"text": text, "kind": kind})


# ---------------------------------------------------------------- 接回壳上

func _case_rescue_reward() -> Dictionary:
	var x0 := 7920.0 # log1/shark1 之后的开阔水域
	_reset(x0, Tuning.NEUTRAL_DEPTH)
	fb.clear()
	var score0 := GameManager.total_score
	_drop_rabbit(Vector2(-46.0, 105.0), Vector2(0.0, 60.0))

	var t := 0.0
	var pressed := false
	var shifted := false
	var caught_t := -1.0
	var done_t := -1.0
	while t < 9.0:
		if GameManager.accident_state == "RABBIT_WATER":
			# 玩家在这一刻做的两件事：SHIFT 给乌龟，再按住 ↓ 潜下去追。
			if not shifted:
				shifted = true
				GameManager.toggle_control()
			if GameManager.current_control == "turtle":
				pressed = true
				Input.action_press("down")
		race._physics_process(STEP)
		t += STEP
		if caught_t < 0.0 and String(race.rescue_last_result) == "caught":
			caught_t = t
		if caught_t >= 0.0 and done_t < 0.0 \
				and GameManager.accident_state == "NONE" \
				and String(race.mount.state) == "RIDING":
			done_t = t
			break
	Input.action_release("down")

	var reasons: Array = []
	for e in GameManager.score_log:
		reasons.append(String(e["reason"]))
	var texts: Array = []
	for e in fb:
		texts.append(String(e["text"]))
	var d := {
		"dive_pressed": pressed,
		"caught_t": snappedf(caught_t, 0.01),
		"done_t": snappedf(done_t, 0.01),
		"rescue_count": GameManager.rescue_success_count,
		"score_delta": GameManager.total_score - score0,
		"score_reasons": reasons,
		"feedback": texts,
		"rabbit_drift_after": snappedf(race.rabbit_brain.drift, 0.01),
		"turtle_drift_after": snappedf(race.turtle_brain.drift, 0.01),
		"accidents": GameManager.accident_count,
	}
	return d


# ---------------------------------------------------------------- 食物 / 亲手喂

func _case_food(switch_to_turtle: bool) -> Dictionary:
	var enc := {}
	for e in race._snack_list():
		if float(e["x"]) > 2000.0:
			enc = e
			break
	if enc.is_empty():
		return {"error": "no snack encounter"}
	var food_x: float = float(enc["x"])
	_reset(food_x - 420.0, Tuning.NEUTRAL_DEPTH)
	# 两次对照用同一颗食物：缓存里的 eaten 标记必须重置，否则第二次跑会当它已被吃。
	for e in race._snack_list():
		e["eaten"] = false
	fb.clear()
	var score0 := GameManager.total_score
	if switch_to_turtle:
		GameManager.set_control("turtle")
	var t := 0.0
	var eaten := false
	while t < 6.0:
		race._physics_process(STEP)
		t += STEP
		if race.snack_last_eaten != "":
			eaten = true
			break
	var texts: Array = []
	for e in fb:
		texts.append(String(e["text"]))
	var d := {
		"food_x": snappedf(food_x, 0.1),
		"control": GameManager.current_control,
		"eaten": eaten,
		"score_delta": GameManager.total_score - score0,
		"boost_active": race.snack_boost_active(),
		"boost_speed": snappedf(race.snack_boost_speed, 0.1),
		"rabbit_jump_boost": snappedf(race.rabbit.jump_boost, 0.01),
		"rabbit_boost_until_x": snappedf(race.rabbit_boost_until_x, 0.1),
		"feedback": texts,
		"negative_entries": _negative_reasons(),
		"accidents": GameManager.accident_count,
	}
	Input.action_release("down")
	Input.action_release("up")
	return d


# ---------------------------------------------------------------- 神游 12 s

func _case_drift(controlled: String) -> Dictionary:
	_reset(3200.0, Tuning.NEUTRAL_DEPTH)
	GameManager.set_control(controlled)
	GameManager.clear_bro_meter()
	GameManager.accident_count = 0
	var t := 0.0
	var states := {}
	var max_off := 0.0
	var pin_x: float = race.turtle.position.x
	while t < 12.0:
		# 把乌龟钉在原地：这一段只想看“神游本身会不会记账”，不看开车撞障碍。
		race.turtle.position.x = pin_x
		race._physics_process(STEP)
		t += STEP
		var who = race.turtle_brain if controlled == "rabbit" else race.rabbit_brain
		var st := String(who.state_name())
		if not states.has(st):
			states[st] = snappedf(t, 0.01)
		max_off = maxf(max_off, float(who.drift))
	var d := {
		"controlled": controlled,
		"drifted": "turtle" if controlled == "rabbit" else "rabbit",
		"states_seen": states,
		"drift_max": snappedf(max_off, 0.01),
		"drift_end": snappedf(float(
			race.turtle_brain.drift if controlled == "rabbit" else race.rabbit_brain.drift), 0.01),
		"accidents": GameManager.accident_count,
		"bro_meter": GameManager.bro_meter,
		"accident_state": GameManager.accident_state,
		"score_negatives": _negative_reasons(),
	}
	return d


# ---------------------------------------------------------------- 没换人的代价

## 在 log1 前按标准起跳但不切乌龟（不接第二段）：只应该记这一次真实碰撞，
## 不允许再出现“没换人”的附加罚项。
func _case_failed_combo() -> Dictionary:
	var g := _group("log1")
	var start: float = LevelData.group_start(g)
	_reset(start - 500.0, Tuning.NEUTRAL_DEPTH)
	var score0 := GameManager.total_score
	var t := 0.0
	var jumped := false
	while t < 6.0:
		var x: float = race.turtle.position.x
		if not jumped and x >= start - 160.0:
			Input.action_press("up")
			jumped = true
		elif jumped:
			Input.action_release("up")
		race._physics_process(STEP)
		t += STEP
		if GameManager.accident_count > 0 and t > 1.0:
			break
	Input.action_release("up")
	Input.action_release("down")
	return {
		"jumped": jumped,
		"accidents": GameManager.accident_count,
		"accident_state": GameManager.accident_state,
		"score_delta": GameManager.total_score - score0,
		"score_negatives": _negative_reasons(),
		"bro_meter": GameManager.bro_meter,
	}


func _negative_reasons() -> Array:
	var r: Array = []
	for e in GameManager.score_log:
		if int(e["points"]) < 0:
			r.append(String(e["reason"]))
	return r


# ---------------------------------------------------------------- 判定

func _evaluate() -> void:
	var rr: Dictionary = out["cases"]["rescue_reward"]
	_expect("rescue: caught and back on the shell (%s/%s)" % [rr["caught_t"], rr["done_t"]],
		float(rr["caught_t"]) >= 0.0 and float(rr["done_t"]) > float(rr["caught_t"]))
	_expect("rescue: one success counted (%d)" % int(rr["rescue_count"]),
		int(rr["rescue_count"]) == 1)
	_expect("rescue: reunion reward is logged (%s)" % str(rr["score_reasons"]),
		Array(rr["score_reasons"]).has("rescue_switch"))
	_expect("rescue: reunion feedback is its own line (%s)" % str(rr["feedback"]),
		_has_text(rr["feedback"], "兄弟回来了"))
	_expect("rescue: both bros calm down after the reunion (%s / %s)"
		% [rr["rabbit_drift_after"], rr["turtle_drift_after"]],
		float(rr["rabbit_drift_after"]) == 0.0 and float(rr["turtle_drift_after"]) == 0.0)
	_expect("rescue: the fall is still the only accident (%d)" % int(rr["accidents"]),
		int(rr["accidents"]) == 1)

	var no_sw: Dictionary = out["cases"]["food_without_switch"]
	var sw: Dictionary = out["cases"]["food_with_switch"]
	if no_sw.has("error") or sw.has("error"):
		failures.append("food: no encounter planned")
	else:
		_expect("food: eating without switching still works (%s)" % no_sw["eaten"],
			bool(no_sw["eaten"]))
		# REFINE-06 P4 定案：兔子吃 = 下一跳 ×1.15（不给乌龟加速），乌龟吃 = TURBO。
		# 原来这里断言“两次 boost_speed 相同”，与 P4 的取舍相反，已按现机制改写：
		# 不切换也拿得到真实收益（跳跃强化），只是拿不到亲手喂的 30 分与乌龟 TURBO。
		_expect("food: no-switch still gets a real benefit (兔跳 ×%.2f，到 x=%.0f)"
			% [float(no_sw["rabbit_jump_boost"]), float(no_sw["rabbit_boost_until_x"])],
			float(no_sw["rabbit_jump_boost"]) > 1.0
			and float(no_sw["rabbit_boost_until_x"]) > float(no_sw["food_x"]))
		_expect("food: no-switch costs no points (%+d)" % int(no_sw["score_delta"]),
			int(no_sw["score_delta"]) >= 0 and Array(no_sw["negative_entries"]).is_empty())
		_expect("food: feeding by hand pays the bonus (%+d)" % int(sw["score_delta"]),
			int(sw["score_delta"]) == Tuning.SNACK_SWITCH_BONUS)
		_expect("food: feed feedback differs from auto-eat (%s / %s)"
			% [str(no_sw["feedback"]), str(sw["feedback"])],
			str(no_sw["feedback"]) != str(sw["feedback"]))
		_expect("food: 两种吃法给不同的强化（兔 ×%.2f / 龟 %.0f px/s）"
			% [float(no_sw["rabbit_jump_boost"]), float(sw["boost_speed"])],
			float(no_sw["boost_speed"]) == 0.0 and float(sw["boost_speed"]) > 0.0
			and float(sw["rabbit_jump_boost"]) == 1.0)

	var dt: Dictionary = out["cases"]["drift_turtle"]
	var dr: Dictionary = out["cases"]["drift_rabbit"]
	for pair in [["turtle", dt], ["rabbit", dr]]:
		var who: String = pair[0]
		var d: Dictionary = pair[1]
		_expect("%s drift: 12 s without input causes no accident (%d)"
			% [who, int(d["accidents"])], int(d["accidents"]) == 0)
		_expect("%s drift: BRO METER stays empty (%d)" % [who, int(d["bro_meter"])],
			int(d["bro_meter"]) == 0)
		_expect("%s drift: no negative score while drifting (%s)"
			% [who, str(d["score_negatives"])], Array(d["score_negatives"]).is_empty())
		_expect("%s drift: four states still reached (%s)" % [who, str(d["states_seen"])],
			_reaches_four(d["states_seen"]))

	var fc: Dictionary = out["cases"]["failed_combo_penalty"]
	_expect("failed combo: exactly one real accident is recorded (%d)"
		% int(fc["accidents"]), int(fc["accidents"]) == 1)
	_expect("failed combo: no extra 'didn't switch' penalty (%s)"
		% str(fc["score_negatives"]),
		Array(fc["score_negatives"]).size() == 1)
	_expect("failed combo: the penalty is the accident itself (%s)"
		% str(fc["score_negatives"]),
		Array(fc["score_negatives"]).size() == 1 \
			and String(fc["score_negatives"][0]).begins_with("mistake:"))


func _has_text(arr: Array, needle: String) -> bool:
	for t in arr:
		if String(t).contains(needle):
			return true
	return false


func _reaches_four(states: Dictionary) -> bool:
	return states.has("CALM") and states.has("DISTRACTED") \
		and states.has("RESTLESS") and states.has("MISCHIEF")


# ---------------------------------------------------------------- 工具

func _reset(x: float, y: float) -> void:
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
	GameManager.current_control = "rabbit"
	GameManager.oxygen = Tuning.OXYGEN_MAX
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
	race.turtle.reset(Vector2(x, y))
	race.turtle.base_speed = 220.0
	race.turtle.speed = 220.0
	race.turtle.speed_cap = 1.0e9
	race.turtle.daze_time = 0.0
	race.turtle.drift = 0.0
	race.turtle.dunk_timer = 0.0
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
	# REFINE-06 P4 起兔子吃食物走“下一跳更强”，不复位会串到下一个用例。
	race.rabbit.jump_boost = 1.0
	race.rabbit_boost_until_x = -1.0
	race.snack_last_eaten = ""
	race.snack_gulp_t = 0.0
	race.snack_gulp_by_player = false
	Input.action_release("down")
	Input.action_release("up")


func _drop_rabbit(behind: Vector2, vel: Vector2) -> void:
	race.mount.mark_airborne()
	race.rabbit.position = race.turtle.get_mount_point() + behind
	race.rabbit.velocity = vel
	race.rabbit.state = "FALLING"
	race.rescue_prev_pos = race.rabbit.position


func _group(name: String) -> Dictionary:
	for g in race.hazard_groups:
		if String(g["group"]) == name:
			return g
	return {}


func _expect(label: String, ok: bool) -> void:
	if not ok:
		failures.append(label)


func _write() -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f == null:
		push_error("D SHIFT: cannot write " + OUT_PATH)
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()
