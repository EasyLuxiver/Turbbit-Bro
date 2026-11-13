extends Node
## CORE-FEEL-07D：满格到底在说什么？
##
## 设计决定（制作人 2026-11-13）：共享三格规则不动，但“联合惩罚”字面像在说
## “两个人都有错”。满格只描述后果，改成“一起翻船”；结算页同一套说法。
## 本探针核对：
##   1. 满格中央提示 = 新文案，中英文都不含“联合 / JOINT”
##   2. 规则未变：前两格只记失误，第三格额外 -200、演出后清零
##   3. 结算页对应一行 = “翻船次数 / CAPSIZES”
##
## 输出：docs/reports/longrun/core-feel-07d-capsize-copy.json
## 运行：godot --headless --path TURBBIT res://scenes/stage7d_joint_copy.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")

const OUT_PATH := "res://docs/reports/longrun/core-feel-07d-capsize-copy.json"
const STEP := 1.0 / 60.0

var is_runner := false
var race: Node = null
var out := {}
var failures: Array = []
var center_msgs: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage7dJointCopyRunner"
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
		push_error("CORE-FEEL-07D: no race scene")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()
	GameManager.center_message.connect(_on_center)

	GameManager.clear_bro_meter()
	GameManager.accident_count = 0
	GameManager.joint_accident_count = 0
	# 分数下限是 0（add_score 会 clamp），先垫分才能量出每次扣多少。
	GameManager.total_score = 10000
	GameManager.score_log.clear()

	# 前两格：只记失误。
	var score0: int = GameManager.total_score
	GameManager.note_mistake("TURTLE_WAVE")
	var meter1: int = GameManager.bro_meter
	var score1: int = GameManager.total_score
	GameManager.note_mistake("TURTLE_WAVE")
	var meter2: int = GameManager.bro_meter
	var score2: int = GameManager.total_score
	out["meter_after_first"] = meter1
	out["meter_after_second"] = meter2
	out["score_cost_first"] = score0 - score1
	out["score_cost_second"] = score1 - score2
	out["score_before_third"] = score2

	# 第三格：真实事故入口，满格后由 race 播演出。
	race._trigger_accident("RABBIT_STUN")
	out["meter_after_third"] = GameManager.bro_meter
	out["joint_pending"] = GameManager.bro_joint_pending
	out["score_cost_third"] = score2 - GameManager.total_score

	# 等演出开始（事故恢复后由 race._physics_process 播）。
	var guard := 0
	while guard < 600 and GameManager.accident_state != "BRO_BREAK":
		race._physics_process(STEP)
		guard += 1
	out["show_started"] = GameManager.accident_state == "BRO_BREAK"
	out["show_start_frames"] = guard
	out["center_msgs"] = center_msgs.duplicate()
	out["center_zh"] = center_msgs[-1] if center_msgs.size() > 0 else ""

	# 演出结束：清零。
	guard = 0
	while guard < 600 and (race.joint_show_t > 0.0 \
			or GameManager.accident_state != "NONE"):
		race._physics_process(STEP)
		guard += 1
	out["show_ended"] = race.joint_show_t <= 0.0 \
		and GameManager.accident_state == "NONE"
	out["meter_after_show"] = GameManager.bro_meter
	out["joint_pending_after_show"] = GameManager.bro_joint_pending

	# 中央提示的中英文文案（同一份 Locale 表；race 发消息时走的就是它）。
	out["center_zh_locale"] = Locale.t("center.bro_full")
	Locale.set_language("en")
	out["center_en_locale"] = Locale.t("center.bro_full")
	Locale.set_language("zh")

	# 结算页：中英文各读一次。
	GameManager.clean_pass_count = 5
	GameManager.combo_dive_count = 2
	GameManager.combo_ollie_count = 1
	GameManager.rescue_success_count = 1
	GameManager.snack_switch_count = 0
	GameManager.accident_count = 3
	GameManager.joint_accident_count = 1
	get_tree().change_scene_to_file("res://scenes/result.tscn")
	for i in 8:
		await get_tree().process_frame
	var res := get_tree().current_scene
	if res == null:
		push_error("CORE-FEEL-07D: no result scene")
		get_tree().quit(1)
		return
	out["result_zh"] = _stats_text(res)
	Locale.set_language("en")
	for i in 4:
		await get_tree().process_frame
	out["result_en"] = _stats_text(res)

	_evaluate()
	_write()
	print("CORE-FEEL-07D: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _stats_text(res: Node) -> String:
	var label = res.get("_stats_label")
	return "" if label == null else String(label.text)


func _on_center(text: String, _color: Color) -> void:
	center_msgs.append(text)


func _evaluate() -> void:
	_expect("first slot costs 100 (%d)" % int(out["score_cost_first"]),
		int(out["score_cost_first"]) == 100)
	_expect("second slot costs 100 (%d)" % int(out["score_cost_second"]),
		int(out["score_cost_second"]) == 100)
	_expect("two slots after two mistakes (meter=%d)" % int(out["meter_after_second"]),
		int(out["meter_after_first"]) == 1 and int(out["meter_after_second"]) == 2)
	_expect("third mistake fills the meter (meter=%d pending=%s)" % [
		int(out["meter_after_third"]), str(out["joint_pending"])],
		int(out["meter_after_third"]) == 3 and bool(out["joint_pending"]))
	_expect("third mistake costs 300 total (%d)" % int(out["score_cost_third"]),
		int(out["score_cost_third"]) == 300)
	_expect("joint show starts (frames=%d)" % int(out["show_start_frames"]),
		bool(out["show_started"]))
	_expect("center message is the new copy (%s)" % String(out["center_zh"]),
		String(out["center_zh"]) == "BRO METER 满 —— 一起翻船！")
	_expect("center message never says 联合/惩罚 (%s)" % String(out["center_zh"]),
		not String(out["center_zh"]).contains("联合")
		and not String(out["center_zh"]).contains("惩罚"))
	_expect("show ends and clears the meter (meter=%d pending=%s)" % [
		int(out["meter_after_show"]), str(out["joint_pending_after_show"])],
		bool(out["show_ended"]) and int(out["meter_after_show"]) == 0
		and not bool(out["joint_pending_after_show"]))
	_expect("en center message names no culprit (%s)" % String(out["center_en_locale"]),
		String(out["center_en_locale"]).contains("CAPSIZED")
		and not String(out["center_en_locale"]).contains("JOINT"))
	var zh := String(out["result_zh"])
	_expect("zh result names the stat 翻船次数", zh.contains("翻船次数"))
	_expect("zh result has no leftover 联合", not zh.contains("联合"))
	var count_line := false
	for line in zh.split("\n"):
		if line.contains("翻船次数") and line.contains("1"):
			count_line = true
	_expect("zh result shows the count (1)", zh.contains("翻船次数") and count_line)
	var en := String(out["result_en"])
	_expect("en result names the stat CAPSIZES", en.contains("CAPSIZES"))
	_expect("en result has no leftover JOINT", not en.contains("JOINT"))


func _expect(msg: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + msg)
	if not ok:
		failures.append(msg)


func _write() -> void:
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out, "  "))
		f.close()
