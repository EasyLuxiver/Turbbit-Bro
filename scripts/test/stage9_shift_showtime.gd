extends Node
## TBB-CORE-FEEL-09 P0-C / P0-D — SHIFT 0.20 s 锁定 与 Showtime 奖励。
##
## P0-C 判据：
##   1) 首次切换在同一调用内生效（不多一帧延迟）；
##   2) 成功后 0.20 s 内二次切换被忽略，且不排队；
##   3) 30/60/120 Hz 下锁定时长一致（误差 ≤ 一个物理步长）；
##   4) 事故中的旧规则不变：普通事故不能换人，主动救援两种状态可以换。
##
## P0-D 判据：
##   1) 正常完成 +100 分、+1.5 氧气、次数 +1，只发一次；
##   2) 再次调用不发第二次；
##   3) SHIFT 中断（completed=false）不发奖；
##   4) HUD 反馈信号里有奖励文本；
##   5) 结算页文本包含 Showtime 次数。
##
## 输出：docs/reports/longrun/core-feel-09-p0cd-shift-showtime.json

const Tuning = preload("res://scripts/systems/tuning.gd")
const OUT_PATH := "res://docs/reports/longrun/core-feel-09-p0cd-shift-showtime.json"
const HZ_SET := [30, 60, 120]

var is_runner := false
var checks: Array = []
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
	Locale.set_language("zh")
	var shift_rows := []
	for hz in HZ_SET:
		shift_rows.append(_shift_case(int(hz)))
	_shift_accident_rules()
	await _showtime_case()
	var failed := 0
	for c in checks:
		if not bool(c["ok"]):
			failed += 1
			print("FAIL  %s  %s" % [c["name"], c["detail"]])
		else:
			print("ok    %s  %s" % [c["name"], c["detail"]])
	var data := {
		"task": "TBB-CORE-FEEL-09 P0-C/P0-D",
		"generated_at": Time.get_datetime_string_from_system(),
		"shift_lock": shift_rows,
		"checks": checks,
		"failed": failed,
	}
	_write_json(OUT_PATH, data)
	print("P0CD: %d/%d checks pass" % [checks.size() - failed, checks.size()])
	print("P0CD RESULT: ", "PASS" if failed == 0 else "FAIL")
	get_tree().quit(0 if failed == 0 else 1)


func _shift_case(hz: int) -> Dictionary:
	var step := 1.0 / float(hz)
	GameManager.process_mode = Node.PROCESS_MODE_DISABLED
	GameManager.state = GameManager.GameState.RUNNING
	GameManager._reset_run()
	var from0 := GameManager.current_control
	GameManager.toggle_control()
	var first_ok := GameManager.current_control != from0
	var after_first := GameManager.current_control
	# 立刻再按：必须被锁定挡住，且之后不补发。
	GameManager.toggle_control()
	var immediate_blocked := GameManager.current_control == after_first
	var t := 0.0
	var unlock_t := -1.0
	var toggles := 0
	while t < 0.6:
		GameManager.tick_shift_lock(step)
		t += step
		var before := GameManager.current_control
		GameManager.toggle_control()
		toggles += 1
		if GameManager.current_control != before:
			unlock_t = t
			break
	var err := absf(unlock_t - 0.20)
	# 锁定到期后不按：控制权必须停在上一次换到的人身上。
	var after_unlock := GameManager.current_control
	GameManager.tick_shift_lock(0.3)
	var stays := GameManager.current_control == after_unlock
	var ok := first_ok and immediate_blocked and unlock_t > 0.0 \
		and err <= step + 0.0001 and stays
	_check("shift_%dHz" % hz, ok,
		"%d Hz: 首次=%s 立即二次被挡=%s 解锁=%.3fs 误差=%.3fs 不排队=%s" % [
			hz, str(first_ok), str(immediate_blocked), unlock_t, err, str(stays)])
	return {
		"hz": hz, "step_s": step, "first_immediate": first_ok,
		"immediate_second_blocked": immediate_blocked,
		"unlock_s": snappedf(unlock_t, 0.001),
		"error_vs_0p2_s": snappedf(err, 0.001),
		"no_queue": stays,
	}
	# 注：no_queue 用“到期后不按也不换人”来判，比“补发”更严格。


func _shift_accident_rules() -> void:
	GameManager.process_mode = Node.PROCESS_MODE_DISABLED
	GameManager.state = GameManager.GameState.RUNNING
	GameManager._reset_run()
	GameManager.shift_lock_t = 0.0
	GameManager.accident_state = "RABBIT_HIT"
	var before := GameManager.current_control
	GameManager.toggle_control()
	var blocked_in_accident := GameManager.current_control == before
	GameManager.accident_state = "RABBIT_WATER"
	var before2 := GameManager.current_control
	GameManager.toggle_control()
	var rescue_allowed := GameManager.current_control != before2
	GameManager.accident_state = "NONE"
	_check("shift_accident_rules", blocked_in_accident and rescue_allowed,
		"普通事故挡住=%s；主动救援允许=%s" % [
			str(blocked_in_accident), str(rescue_allowed)])


func _showtime_case() -> void:
	GameManager.start_race()
	for i in 10:
		await get_tree().process_frame
	var race: Node = get_tree().current_scene
	if race == null or not ("showtime_active" in race):
		_check("showtime_scene", false, "no race scene")
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	GameManager.feedback.connect(_on_feedback)
	GameManager.oxygen = 4.0
	GameManager.total_score = 0
	GameManager.showtime_count = 0
	race.start_showtime()
	var started := bool(race.showtime_active)
	race._tick_showtime(Tuning.SHOWTIME_TIME + 0.01)
	var score1 := GameManager.total_score
	var oxy1 := GameManager.oxygen
	var count1 := GameManager.showtime_count
	var ended := not bool(race.showtime_active)
	# 再调一次：不能重复发奖。
	race._end_showtime(true)
	var no_double := GameManager.total_score == score1 \
		and is_equal_approx(GameManager.oxygen, oxy1) \
		and GameManager.showtime_count == count1
	# 中断：不发奖。
	race.start_showtime()
	race._end_showtime(false)
	var interrupt_free := GameManager.total_score == score1 \
		and GameManager.showtime_count == count1
	var reward_feedback := false
	for f in feedback_log:
		if String(f).contains("SHOWTIME") or String(f).contains("表演"):
			reward_feedback = true
	# 结算页：次数必须出现在文本里。
	var shown := await _result_shows_count()
	_check("showtime_once", started and ended and score1 == 100 \
		and is_equal_approx(oxy1, 5.5) and count1 == 1,
		"开始=%s 结束=%s 分=%d 氧=%.1f 次数=%d" % [
			str(started), str(ended), score1, oxy1, count1])
	_check("showtime_no_double", no_double, "第二次完成调用不重复发奖=%s" % str(no_double))
	_check("showtime_interrupt_no_reward", interrupt_free,
		"SHIFT 中断不发奖=%s" % str(interrupt_free))
	_check("showtime_feedback", reward_feedback, "HUD 反馈含奖励文本=%s" % str(reward_feedback))
	_check("showtime_result_row", shown, "结算页显示次数=%s" % str(shown))


func _result_shows_count() -> bool:
	var res: Node = load("res://scenes/result.tscn").instantiate()
	add_child(res)
	await get_tree().process_frame
	var label: Label = res.get("_stats_label")
	if label == null:
		return false
	var text := label.text
	res.queue_free()
	return text.contains("表演次数") or text.contains("SHOWTIME")


func _on_feedback(text: String, _kind: String) -> void:
	feedback_log.append(text)


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})


func _write_json(path: String, data: Dictionary) -> void:
	var abs := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + path)
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()
