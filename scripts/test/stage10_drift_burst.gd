extends Node
## FEEL-10 P0-B：神游四阶段与满值“不服从”实测（30/60/120 Hz）。
##
## 判据：
##   CALM/DISTRACTED 不产生满值不服从；
##   RESTLESS 有可见自漂但没有强制夺权；
##   MISCHIEF 在前摇后产生 0.5–1.0 s 的单角色不服从，结束后恢复；
##   另一角色始终不被锁；
##   30/60/120 Hz 的前摇/持续时间一致（按秒，不按帧）。

const OUT_PATH := "res://docs/reports/longrun/core-feel-10-p0b-drift.json"
const Tuning = preload("res://scripts/systems/tuning.gd")
const HZ := [30, 60, 120]

var is_runner := false
var race: Node = null
var checks: Array = []
var rows: Array = []
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
	GameManager.start_race()
	for i in 4:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null:
		_check("race", false, "no race scene")
		_finish()
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = true
	race.hazard_groups = []
	GameManager.feedback.connect(func(text: String, _k: String) -> void:
		feedback_log.append(text))
	_case_stage_values()
	# FEEL-12：旧的“拒绝输入/自动趴低”已被 BRO OVERDRIVE 取代；
	# 这里只保留四段延迟；过载/慢镜头由 stage12_overdrive 覆盖。
	_write()
	_finish()


func _reset() -> void:
	GameManager._reset_run()
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.current_control = "rabbit"
	GameManager.accident_state = "NONE"
	race.hazard_cooldown = 0.0
	race.joint_show_t = 0.0
	race._burst_who = ""
	race._burst_phase = ""
	race._burst_t = 0.0
	race._burst_cd = 0.0
	race._rabbit_refuse_t = 0.0
	race._turtle_refuse_t = 0.0
	race.rabbit_brain.drift = 0.0
	race.turtle_brain.drift = 0.0
	race.turtle.reset(Vector2(800.0, race.surface_ref()))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()


func _case_stage_values() -> void:
	_reset()
	race.rabbit.drift = 0.0
	var calm_rabbit: float = race._drift_react_delay("rabbit")
	race.rabbit.drift = Tuning.DRIFT_CALM_END + 0.5
	var distracted: float = race._drift_react_delay("rabbit")
	race.rabbit.drift = Tuning.DRIFT_RESTLESS_END - 0.2
	var restless: float = race._drift_react_delay("rabbit")
	race.rabbit.drift = Tuning.DRIFT_CAP
	var mischief: float = race._drift_react_delay("rabbit")
	_check("stage_delays",
		calm_rabbit < 0.001 and distracted > calm_rabbit
			and restless > distracted and mischief > restless
			and mischief <= Tuning.DRIFT_REACT_RABBIT_MAX + 0.001,
		"delay CALM=%.2f DIST=%.2f RESTLESS=%.2f MISCHIEF=%.2f" % [
			calm_rabbit, distracted, restless, mischief])
	_reset()
	race.turtle_brain.drift = Tuning.DRIFT_RESTLESS_END + 0.5
	var rest_drift: float = race._tubo_autodrift()
	race.turtle_brain.drift = Tuning.DRIFT_CAP
	var max_drift: float = race._tubo_autodrift()
	_check("tubo_stage_drift", absf(rest_drift) <= Tuning.TUBO_AUTODRIFT_PX * 0.51
		and absf(max_drift) <= Tuning.TUBO_AUTODRIFT_PX * 1.01,
		"RESTLESS≈%.1f MISCHIEF≈%.1f" % [rest_drift, max_drift])


func _burst_row(hz: int, who: String) -> Dictionary:
	var step := 1.0 / float(hz)
	_reset()
	GameManager.current_control = "turtle"
	if who == "rabbit":
		race.rabbit_brain.drift = Tuning.DRIFT_CAP
	else:
		race.turtle_brain.drift = Tuning.DRIFT_CAP
	feedback_log.clear()
	var t := 0.0
	var start_t := -1.0
	var burst_t := -1.0
	var end_t := -1.0
	var other_locked := false
	for i in 600:
		race._tick_role_burst(step)
		t += step
		if start_t < 0.0 and String(race._burst_who) == who:
			start_t = t
		if burst_t < 0.0 and String(race._burst_phase) == "BURST":
			burst_t = t
		if who == "rabbit" and float(race._turtle_refuse_t) > 0.0:
			other_locked = true
		if who == "turtle" and float(race._rabbit_refuse_t) > 0.0:
			other_locked = true
		if burst_t >= 0.0 and end_t < 0.0 and String(race._burst_who) == "":
			end_t = t
			break
	var telegraph := burst_t - start_t if start_t >= 0.0 and burst_t >= 0.0 else -1.0
	var duration := end_t - burst_t if burst_t >= 0.0 and end_t >= 0.0 else -1.0
	var ok := start_t >= 0.0 and telegraph >= 0.25 and telegraph <= 0.5 \
		and duration >= 0.55 and duration <= 0.85 and not other_locked \
		and float(race._burst_cd) > 0.0
	_check("burst_%s_%dHz" % [who, hz], ok,
		"start=%.2f telegraph=%.2f duration=%.2f other_locked=%s cd=%.2f" % [
			start_t, telegraph, duration, str(other_locked), float(race._burst_cd)])
	return {"who": who, "hz": hz, "start_s": snappedf(start_t, 0.001),
		"telegraph_s": snappedf(telegraph, 0.001),
		"duration_s": snappedf(duration, 0.001),
		"other_locked": other_locked, "feedback": feedback_log.duplicate()}


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _finish() -> void:
	var failed := 0
	for c in checks:
		if not bool(c["ok"]):
			failed += 1
	print("P0B DRIFT: %d/%d pass" % [checks.size() - failed, checks.size()])
	print("P0B RESULT: ", "PASS" if failed == 0 else "FAIL")
	get_tree().quit(0 if failed == 0 else 1)


func _write() -> void:
	var data := {"task": "TBB-CORE-FEEL-10 P0-B",
		"generated_at": Time.get_datetime_string_from_system(),
		"rows": rows, "checks": checks}
	var abs := ProjectSettings.globalize_path(OUT_PATH)
	DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))
	f.close()
