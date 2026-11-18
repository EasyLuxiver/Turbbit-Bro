extends Node
## FEEL-10 P0-A：联合判罚语义矩阵（8 例）。
##
## 单角色事故只让该角色捣乱；真正联合只在两人同时危险且进入时刻相差
## ≤0.6 s 时触发；救援不喂 BRO、不触发全员冻结；同一事件不重复计罚。
##
## 输出：docs/reports/longrun/core-feel-10-p0a-joint.json

const OUT_PATH := "res://docs/reports/longrun/core-feel-10-p0a-joint.json"
const LevelData = preload("res://scripts/systems/level_data.gd")

var is_runner := false
var race: Node = null
var checks: Array = []
var rows: Array = []


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
	race.test_no_mischief = true
	if race == null:
		_check("race", false, "no race scene")
		_finish()
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = true
	race.hazard_groups = []
	_case_single("rabbit")
	_case_single("turtle")
	_case_true_joint()
	_case_rescue_success()
	_case_rescue_fail()
	_case_two_slots_then_single()
	_case_outside_window()
	_case_same_event()
	_check("other_role_operable", _case_other_role_operable(),
		"单角色捣乱时另一角色仍受控、不接受捣乱计时")
	_write()
	_finish()


func _reset() -> void:
	GameManager._reset_run()
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.current_control = "rabbit"
	GameManager.accident_state = "NONE"
	GameManager.accident_count = 0
	GameManager.role_mischief_pending = false
	GameManager.role_mischief_role = ""
	GameManager.accident_state = "NONE"
	race.hazard_cooldown = 0.0
	race.joint_show_t = 0.0
	race.accident_event_time = 0.0
	race._joint_episode_done = false
	race._rabbit_danger_since = -1.0
	race._turtle_danger_since = -1.0
	race._burst_who = ""
	race._burst_phase = ""
	race._burst_t = 0.0
	race._burst_cd = 0.0
	race._rabbit_refuse_t = 0.0
	race._turtle_refuse_t = 0.0
	race._od_phase = ""
	race._od_role = ""
	race._od_cd = 0.0
	race._od_emphasis_t = 0.0
	race._od_flash = 0.0
	Engine.time_scale = 1.0
	race.turtle.accident = false
	race.turtle_repair = 0.0
	race.turtle.reset(Vector2(800.0, race.surface_ref()))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()


func _case_single(who: String) -> void:
	_reset()
	for i in 3:
		GameManager.note_mistake("RABBIT_STUN" if who == "rabbit" else "TURTLE_WAVE",
			who)
	# FEEL-24：单角色连续失误只留下抱怨窗口，不武装 BRO 槽、不触发联合。
	_check("%s_single" % who,
		GameManager.complaint_role == who
			and GameManager.joint_accident_count == 0
			and race.joint_show_t == 0.0,
		"complaint=%s joint=%d" % [GameManager.complaint_role,
			GameManager.joint_accident_count])
	rows.append({"case": who + "_single", "bro": GameManager.bro_meter,
		"complaint": GameManager.complaint_role})


func _case_true_joint() -> void:
	_reset()
	race.rabbit.state = "FALLING_WATER"
	race.mount.state = "RESCUE_FALLING"
	race.turtle.accident = true
	race._update_true_joint(0.0)
	_check("true_joint", GameManager.joint_accident_count == 1
		and race.joint_show_t > 0.0
		and GameManager.accident_state == "BRO_BREAK",
		"joint=%d show=%.2f state=%s" % [GameManager.joint_accident_count,
			race.joint_show_t, GameManager.accident_state])


func _case_rescue_success() -> void:
	_reset()
	var triggered: bool = race._trigger_accident("RABBIT_WATER")
	var before: int = GameManager.accident_count
	var bro0: int = GameManager.bro_meter
	_check("rescue_success_initial", triggered and before == 1,
		"triggered=%s accidents=%d" % [str(triggered), before])
	# 模拟接住：救援流程本身不再记账。
	race.rabbit.state = "RIDING"
	race.mount.state = "RIDING"
	GameManager.accident_state = "NONE"
	race._finish_rescue_return()
	_check("rescue_success", GameManager.accident_count == before
		and GameManager.bro_meter == bro0,
		"accidents %d->%d bro %d->%d" % [before, GameManager.accident_count,
			bro0, GameManager.bro_meter])


func _case_rescue_fail() -> void:
	_reset()
	race._trigger_accident("RABBIT_WATER")
	var before: int = GameManager.accident_count
	var bro0: int = GameManager.bro_meter
	race._rescue_miss("timeout")
	_check("rescue_fail", GameManager.accident_count == before
		and GameManager.bro_meter == bro0,
		"accidents %d->%d bro %d->%d" % [before, GameManager.accident_count,
			bro0, GameManager.bro_meter])


func _case_two_slots_then_single() -> void:
	_reset()
	GameManager.note_mistake("RABBIT_STUN", "rabbit")
	GameManager.note_mistake("TURTLE_WAVE", "turtle")
	GameManager.note_mistake("RABBIT_STUN", "rabbit")
	# FEEL-24 起不再有“两格→第三格武装”的 BRO 槽；连续失误只生成
	# 最后一次抱怨窗口（complaint_role），不会自动升级成联合事故。
	_check("two_slots_then_single",
		GameManager.complaint_role == "rabbit"
			and GameManager.joint_accident_count == 0
			and race.joint_show_t == 0.0,
		"complaint=%s joint=%d" % [GameManager.complaint_role,
			GameManager.joint_accident_count])


func _case_outside_window() -> void:
	_reset()
	race.turtle.accident = true
	race.accident_event_time = 0.0
	race._update_true_joint(0.0)
	race.accident_event_time = 1.0
	race.rabbit.state = "FALLING_WATER"
	race.mount.state = "RESCUE_FALLING"
	race._update_true_joint(0.0)
	_check("outside_window", GameManager.joint_accident_count == 0
		and race.joint_show_t == 0.0,
		"joint=%d show=%.2f" % [GameManager.joint_accident_count,
			race.joint_show_t])


func _case_same_event() -> void:
	_reset()
	race._trigger_accident("RABBIT_WATER")
	var n1: int = GameManager.accident_count
	race._trigger_accident("RABBIT_WATER", false)
	_check("same_event", GameManager.accident_count == n1,
		"accidents %d -> %d" % [n1, GameManager.accident_count])


func _case_other_role_operable() -> bool:
	_reset()
	for i in 3:
		GameManager.note_mistake("RABBIT_STUN", "rabbit")
	GameManager.current_control = "turtle"
	race._od_cd = 0.0
	race._start_burst("rabbit", "bro")
	var started: bool = String(race._od_phase) == "PRE" 		and String(race._od_role) == "rabbit"
	# 过载预兆不夺走当前乌龟的控制权；另一角色仍然可操作。
	race._tick_overdrive(0.31)
	var activated: bool = String(race._od_phase) == "ACTIVE"
	var control_ok: bool = GameManager.current_control == "turtle"
	var turtle_ok: bool = float(race._turtle_refuse_t) <= 0.0
	race._tick_overdrive(0.6)
	var recovered: bool = String(race._od_phase) == "" 		and float(race._od_cd) > 0.0
	rows.append({"case": "overdrive", "started": started, "activated": activated,
		"turtle_ok": turtle_ok, "control_ok": control_ok, "recovered": recovered})
	return started and activated and turtle_ok and control_ok and recovered

func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var data := {"task": "TBB-CORE-FEEL-10 P0-A",
		"generated_at": Time.get_datetime_string_from_system(),
		"rows": rows, "checks": checks}
	var abs := ProjectSettings.globalize_path(OUT_PATH)
	DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))
	f.close()


func _finish() -> void:
	var failed := 0
	for c in checks:
		if not bool(c["ok"]):
			failed += 1
	print("P0A JOINT: %d/%d pass" % [checks.size() - failed, checks.size()])
	print("P0A RESULT: ", "PASS" if failed == 0 else "FAIL")
	get_tree().quit(0 if failed == 0 else 1)
