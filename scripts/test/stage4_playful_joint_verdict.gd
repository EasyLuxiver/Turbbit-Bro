extends Node
## TBB-SHIFT-PLAYFUL-04 §2：双角色事故的联合判定审查。
##
## 在正式 race.gd 上直接摆位 + 调用真实的 _check_hazards / _physics_process，
## 覆盖任务书要求的所有组合：
##   只有兔子 / 只有乌龟 / 同障碍双角色 / 不同障碍 / 同一窗口内重复碰撞 /
##   已眩晕时再撞 / 窗口结束后的新碰撞；
## 每条都对照：事故状态、BRO METER、accident_count、分数、角色伤亡计数、
##   实际碰撞组、屏幕反馈文案、HUD 的 BRO METER 文字。
##
## 输出：docs/reports/longrun/playful04-joint-verdict.json
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT \
##       res://scenes/stage4_playful_joint_verdict.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/playful04-joint-verdict.json"
const STEP := 1.0 / 60.0

var is_runner := false
var race: Node = null
var data := {}
var feedback_log: Array = []
var hint_log: Array = []
var failures: Array = []


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
		push_error("JOINT VERDICT: no race scene")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_disable_hazards = false
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()
	GameManager.feedback.connect(_on_feedback)
	GameManager.hint.connect(_on_hint)

	var logs: Array = []
	for g in race.hazard_groups:
		if String(g["kind"]) == "FLOATING_LOG":
			logs.append(g)
	if logs.size() < 3:
		push_error("JOINT VERDICT: need 3 logs, got %d" % logs.size())
		get_tree().quit(1)
		return
	data["merge_window"] = {
		"hazard_cooldown": Tuning.HAZARD_COOLDOWN,
		"turtle_cooldown": Tuning.TURTLE_COOLDOWN,
		"rabbit_stun": Tuning.STUN_TIME,
		"rescue_active": Tuning.RESCUE_ACTIVE_TIME,
		"rule": "同一组障碍 hit_groups 只记一次；事故状态未结束前 _physics_process 不判新碰撞（合并）；状态结束 + 冷却结束后新碰撞才再记。",
	}
	data["english"] = _english_texts()
	data["cases"] = {}

	var l0: Dictionary = logs[0]
	var l1: Dictionary = logs[1]
	var l2: Dictionary = logs[2]

	data["cases"]["rabbit_only"] = _case_rabbit_only(l0)
	data["cases"]["turtle_only"] = _case_turtle_only(l0)
	data["cases"]["both_same_obstacle"] = _case_both(l0)
	data["cases"]["repeat_same_group"] = _case_repeat(l0)
	data["cases"]["different_obstacle_in_window"] = _case_different(l0, l1, l2)
	data["cases"]["while_dazed"] = _case_while_dazed(l0, l1)
	data["cases"]["after_window"] = _case_after_window(l0, l1)
	data["cases"]["hud_and_records"] = _case_hud(l0)
	data["cases"]["joint_escalation"] = _case_joint(logs)

	Locale.language = "zh"
	_write()
	print("JOINT VERDICT: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _english_texts() -> Dictionary:
	Locale.language = "en"
	var out := {
		"dive_late": Locale.t("feedback.dive_late"),
		"log_jump": Locale.t("feedback.log_jump"),
		"hint_dive_late": Locale.t("hint.dive_late"),
		"hint_log_jump": Locale.t("hint.log_jump"),
		"wave_hit": Locale.t("feedback.wave_hit"),
	}
	Locale.language = "zh"
	return out


## ---- 基线 ----

func _clean() -> void:
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.clear_bro_meter()
	GameManager.accident_count = 0
	GameManager.total_score = 0
	GameManager.score_log.clear()
	GameManager.rabbit_casualties = 0
	GameManager.turtle_failures = 0
	GameManager.pickup_count = 0
	GameManager.showtime_active = false
	GameManager.current_control = "rabbit"
	race.showtime_active = false
	race.joint_show_t = 0.0
	race.finishing = false
	race.hazard_cooldown = 0.0
	race.accident_flash = 0.0
	race.rabbit_stun = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.emergency_timer = 0.0
	# G20：hit_roles 必须和 hit_groups 一起清。只清 hit_groups 时，B2 起的“角色×组”记账还留着，同组第二例起整组免疫——后面那些重复用例其实在测一段不会撞的赛道。
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.group_actions.clear()
	race.reset_brains()
	race.turtle.reset(Vector2(0.0, Tuning.NEUTRAL_DEPTH))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	feedback_log.clear()
	hint_log.clear()


func _place(group: Dictionary, turtle_mode: String, rabbit_mode: String) -> void:
	var rect: Rect2 = group["rects"][0]
	var cx: float = rect.get_center().x
	var ty := Tuning.NEUTRAL_DEPTH
	var ry := rect.position.y + 40.0
	if turtle_mode == "deep":
		ty = rect.end.y + 70.0
	elif turtle_mode == "under":
		ty = rect.end.y - 20.0
	if rabbit_mode == "above":
		ry = rect.position.y - 50.0
		race.mount.mark_airborne()
		race.rabbit.state = "JUMPING"
	elif rabbit_mode == "inside":
		race.mount.mark_airborne()
		race.rabbit.state = "FALLING"
	race.turtle.position = Vector2(cx, ty)
	race.rabbit.position = Vector2(cx, ry)


func _snap(group: Dictionary) -> Dictionary:
	var last_score: Dictionary = {}
	if not GameManager.score_log.is_empty():
		last_score = GameManager.score_log[GameManager.score_log.size() - 1]
	# total_score 在 0 处夹底（add_score 的 maxi），所以“扣了多少”要看记账本身。
	var mistakes: Array = []
	for e in GameManager.score_log:
		if String(e.get("reason", "")).begins_with("mistake:"):
			mistakes.append((e as Dictionary).duplicate())
	var hud_bro := ""
	var hud_status := ""
	if race.hud != null and race.hud.has_method("_refresh"):
		race.hud._refresh()
		if race.hud.bro_meter_label != null:
			hud_bro = race.hud.bro_meter_label.text
		if race.hud.oxygen_label != null:
			hud_status = race.hud.oxygen_label.text
	return {
		"group": String(group["group"]),
		"accident_state": GameManager.accident_state,
		"bro_meter": GameManager.bro_meter,
		"accident_count": GameManager.accident_count,
		"score": GameManager.total_score,
		"mistake_entries": mistakes,
		"last_score": last_score,
		"hit_groups": race.hit_groups.keys(),
		"feedback": feedback_log[feedback_log.size() - 1] if not feedback_log.is_empty() else "",
		"hint": hint_log[hint_log.size() - 1] if not hint_log.is_empty() else "",
		"rabbit_casualties": GameManager.rabbit_casualties,
		"turtle_failures": GameManager.turtle_failures,
		"pickup_count": GameManager.pickup_count,
		"hud_bro": hud_bro,
		"hud_status": hud_status,
	}


func _on_feedback(text: String, _style: String) -> void:
	feedback_log.append(text)


func _on_hint(text: String) -> void:
	hint_log.append(text)


## ---- §2 场景 ----

## 只有兔子撞浮木：乌龟已经潜到木头下面（不碰），兔子在空中落进木头。
func _case_rabbit_only(group: Dictionary) -> Dictionary:
	_clean()
	_place(group, "deep", "inside")
	race._check_hazards()
	var s := _snap(group)
	s["expect"] = {
		"role": "rabbit",
		"accident": "RABBIT_WATER",
		"bro": 1, "score_delta": -100,
		"text": "撞浮木 = 跳跃弧线提示，不是浪",
	}
	_expect(s, s["accident_state"] == "RABBIT_WATER", "rabbit water accident")
	_expect(s, int(s["bro_meter"]) == 1, "rabbit alone fills exactly one slot")
	_expect(s, _mistake_total(s) == -100 and _mistake_count(s) == 1,
		"rabbit alone records exactly one -100 entry (%s)" % str(s["mistake_entries"]))
	_expect(s, int(s["rabbit_casualties"]) == 1, "rabbit casualty counter increments")
	_expect(s, str(s["feedback"]) == Locale.t("feedback.log_jump"),
		"rabbit-on-log feedback says jump arc (%s)" % s["feedback"])
	_expect(s, run_state_mount() == "RESCUE_FALLING",
		"rabbit water starts the real fall, not a snap")
	return s


## 只有乌龟撞浮木：潜水太晚，兔子已经跳在半空（不碰）。
func _case_turtle_only(group: Dictionary) -> Dictionary:
	_clean()
	_place(group, "inside", "above")
	race._check_hazards()
	var s := _snap(group)
	s["expect"] = {
		"role": "turtle",
		"accident": "none (wave mistake)",
		"bro": 1, "score_delta": -100,
		"text": "下潜太晚，且原因是浮木",
	}
	_expect(s, s["accident_state"] == "NONE", "turtle-on-log is a mistake, not an accident")
	_expect(s, int(s["bro_meter"]) == 1, "turtle alone fills exactly one slot")
	_expect(s, _mistake_total(s) == -100 and _mistake_count(s) == 1,
		"turtle alone records exactly one -100 entry (%s)" % str(s["mistake_entries"]))
	_expect(s, int(s["turtle_failures"]) == 0,
		"turtle_failures is reserved for TURTLE_REEF accidents (0 here)")
	_expect(s, str(s["feedback"]) == Locale.t("feedback.dive_late"),
		"turtle-on-log feedback says dive too late (%s)" % s["feedback"])
	_expect(s, str(s["hint"]) == Locale.t("hint.dive_late"),
		"turtle-on-log hint explains the BRO DIVE order")
	_expect(s, str(s["last_score"].get("reason", "")).ends_with("TURTLE_DIVE_LATE"),
		"score log records the real reason (%s)" % str(s["last_score"]))
	return s


## 同一障碍、同一帧双方都在框里：兔子先判，事故记为联合，但只罚一次。
## 本探针写于 B2 之前；B2 曾改成“两个角色各记一笔”。CORE-FEEL-07 P0-B 又改了：
## 同一障碍 + 同一时间窗 = 一个事故事件，联合事故也只结算一次（用户试玩时
## 一次失败被扣两次分，就是这里）。角色集仍然保留两个人。
func _case_both(group: Dictionary) -> Dictionary:
	_clean()
	_place(group, "inside", "inside")
	race._check_hazards()
	var s := _snap(group)
	s["expect"] = {
		"role": "rabbit first",
		"accident": "RABBIT_WATER",
		"bro": 1, "score_delta": -100,
		"hit_groups": 1,
	}
	_expect(s, s["accident_state"] == "RABBIT_WATER", "both roles -> rabbit branch wins")
	_expect(s, int(s["bro_meter"]) == 1, "dual-role contact books one slot (P0-B, joint)")
	_expect(s, _mistake_total(s) == -100 and _mistake_count(s) == 1,
		"dual-role contact records one entry (%s)" % str(s["mistake_entries"]))
	_expect(s, int(s["hit_groups"].size()) == 1, "the group is marked once")
	# 同一帧再判一次：不会因为还卡在框里再加一笔。
	race._check_hazards()
	var s2 := _snap(group)
	_expect(s2, int(s2["bro_meter"]) == 1, "second check in the same frame is absorbed")
	return {"first": s, "second": s2}


## 同一障碍、连续多帧都在框里：只记一次。
func _case_repeat(group: Dictionary) -> Dictionary:
	_clean()
	_place(group, "inside", "above")
	var before := 0
	for i in 8:
		race._check_hazards()
	if not GameManager.score_log.is_empty():
		before = GameManager.score_log.size()
	var s := _snap(group)
	s["expect"] = {"bro": 1, "score_log_entries": 1}
	_expect(s, int(s["bro_meter"]) == 1, "8 consecutive frames inside one log = one slot")
	_expect(s, before == 1, "8 consecutive frames = one score entry (%d)" % before)
	_expect(s, int(s["accident_count"]) == 1, "one mistake count")
	return s


## 一次事故窗口内撞另一个障碍：合并（不再加一笔）；窗口结束后再撞：重新记。
## G20：乌龟放到 log 下方（deep）。B2 起乌龟也参与记账，“乌龟同帧在框里”会把
## 兔子窗口这件事遮掉——这个用例只想看兔子，所以另一角色必须离开危险区。
func _case_different(a: Dictionary, b: Dictionary, c: Dictionary) -> Dictionary:
	_clean()
	_place(a, "deep", "inside")
	race._check_hazards()
	var first := _snap(a)
	# 事故窗口内（RABBIT_STUN 0.8 s + 冷却）：换下一根浮木。
	GameManager.accident_state = "RABBIT_STUN"
	race.rabbit_stun = Tuning.STUN_TIME
	race.hazard_cooldown = Tuning.HAZARD_COOLDOWN
	_place(b, "deep", "inside")
	race._physics_process(STEP)
	var in_window := _snap(b)
	# 窗口结束：事故清空、冷却归零，再撞第三根。
	GameManager.accident_state = "NONE"
	race.rabbit_stun = 0.0
	race.rabbit_grace = 0.0
	race.hazard_cooldown = 0.0
	race.rabbit.state = "RIDING"
	_place(c, "deep", "inside")
	race._check_hazards()
	var after := _snap(c)
	var out := {
		"first": first, "in_window": in_window, "after": after,
		"expect": {
			"merged_in_window": true, "recorded_after_window": true,
		},
	}
	_expect(out, int(in_window["bro_meter"]) == int(first["bro_meter"]),
		"a different obstacle inside the accident window is merged (no extra slot)")
	_expect(out, int(after["bro_meter"]) == int(first["bro_meter"]) + 1,
		"after the window closes, a new obstacle records again (+1)")
	_expect(out, int(after["accident_count"]) == 2, "accident_count follows the same rule")
	return out


## 已眩晕/失衡时再撞：不追加。G20：乌龟放到 log 下方，只测兔子这一侧。
func _case_while_dazed(group: Dictionary, other: Dictionary) -> Dictionary:
	_clean()
	GameManager.accident_state = "RABBIT_STUN"
	race.rabbit_stun = Tuning.STUN_TIME
	_place(group, "deep", "inside")
	race._physics_process(STEP)
	var s := _snap(group)
	s["expect"] = {"bro": 0, "record": false}
	_expect(s, int(s["bro_meter"]) == 0, "hitting while already dazed does not add a slot")
	_expect(s, race.hit_groups.is_empty(),
		"hitting while dazed does not even mark the group")
	return s


## 事故窗口彻底结束后（模拟恢复完成），同一障碍重新可判。
func _case_after_window(group: Dictionary, other: Dictionary) -> Dictionary:
	_clean()
	_place(group, "inside", "above")
	race._check_hazards()
	var first := _snap(group)
	GameManager.accident_state = "NONE"
	race.hazard_cooldown = 0.0
	race.rabbit_stun = 0.0
	race.hit_groups.clear()
	race.hit_roles.clear()
	_place(group, "inside", "above")
	race._check_hazards()
	var again := _snap(group)
	var out := {"first": first, "again": again,
		"expect": {"second_hit_recorded": true}}
	_expect(out, int(again["bro_meter"]) == 2,
		"after recovery, hitting a log again records a second slot")
	return out


## UI / 记录一致性：BRO METER 文字、状态文字、feedback 与记录同源。
func _case_hud(group: Dictionary) -> Dictionary:
	_clean()
	_place(group, "inside", "above")
	race._check_hazards()
	var s := _snap(group)
	var bro_text_ok: bool = String(s["hud_bro"]).contains("1/%d"
		% GameManager.BRO_METER_SLOTS)
	var zh_ok: bool = str(s["feedback"]) == Locale.t("feedback.dive_late")
	Locale.language = "en"
	var en_text := Locale.t("feedback.dive_late")
	Locale.language = "zh"
	var en_ok := en_text != String(s["feedback"]) and en_text.contains("DIVE")
	s["expect"] = {"hud_bro_contains": "1/3", "zh_text": true, "en_text": true}
	_expect(s, bro_text_ok, "HUD BRO METER text matches the slot count (%s)" % s["hud_bro"])
	_expect(s, zh_ok, "UI feedback is the same localized string as the record")
	_expect(s, en_ok, "bilingual: en text exists and differs (%s)" % en_text)
	return s


## 三格满：联合事故只升级一次，不叠第二笔；满了也不会溢出第 4 格。
func _case_joint(logs: Array) -> Dictionary:
	_clean()
	var steps: Array = []
	for i in 3:
		var g: Dictionary = logs[i]
		GameManager.accident_state = "NONE"
		race.hazard_cooldown = 0.0
		race.hit_groups.clear()
		race.hit_roles.clear()
		_place(g, "inside", "above")
		race._check_hazards()
		steps.append(_snap(g))
	# 满格之后再撞一次：不加格、不再升级。
	GameManager.accident_state = "NONE"
	race.hazard_cooldown = 0.0
	race.hit_groups.clear()
	race.hit_roles.clear()
	_place(logs[3], "inside", "above")
	race._check_hazards()
	var overflow := _snap(logs[3])
	var joint_entries := 0
	var joint_points := 0
	for e in GameManager.score_log:
		if String(e.get("reason", "")) == "joint":
			joint_entries += 1
			joint_points += int(e.get("points", 0))
	var out := {
		"steps": steps, "overflow": overflow,
		"joint_accident_count": GameManager.joint_accident_count,
		"joint_entries": joint_entries, "joint_points": joint_points,
		"expect": {
			"bro_max": GameManager.BRO_METER_SLOTS, "joint_once": true,
			"joint_points": -200, "overflow_absorbed": true,
		},
	}
	_expect(out, int(steps[2]["bro_meter"]) == GameManager.BRO_METER_SLOTS,
		"three different logs fill all three slots")
	_expect(out, joint_entries == 1 and joint_points == -200,
		"the joint accident escalates exactly once with -200 (%d/%d)"
			% [joint_entries, joint_points])
	_expect(out, int(overflow["bro_meter"]) == GameManager.BRO_METER_SLOTS,
		"a further hit beyond a full meter does not overflow a 4th slot (%d)"
			% int(overflow["bro_meter"]))
	_expect(out, joint_entries == 1,
		"a further hit does not trigger a second joint escalation")
	return out


## ---- 工具 ----

func run_state_mount() -> String:
	return race.mount.state


func _mistake_total(s: Dictionary) -> int:
	var n := 0
	for e in s.get("mistake_entries", []):
		n += int((e as Dictionary).get("points", 0))
	return n


func _mistake_count(s: Dictionary) -> int:
	return (s.get("mistake_entries", []) as Array).size()


func _expect(scope: Dictionary, ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)
		scope["failed"] = true


func _write() -> void:
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		failures.append("cannot write " + OUT_PATH)
		return
	f.store_string(JSON.stringify({
		"generated_at": Time.get_datetime_string_from_system(),
		"note": "联合判定审查：直接调用正式 race.gd 的 _check_hazards / _physics_process；不是真人试玩。",
		"data": data,
		"failures": failures,
	}, "  "))
	f.close()
