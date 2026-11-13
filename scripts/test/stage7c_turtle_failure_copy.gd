extends Node
## CORE-FEEL-07C：乌龟失败时，屏幕到底在说什么？
##
## 制作人反馈：乌龟被撞后画面已经翻肚皮了，但 HUD/反馈/提示全在说“被浪冲下去”。
## 本探针在真实关卡里分别让乌龟真实撞上浮木 / 鲨鱼 / 拱岩 / 高墙，逐帧记录：
##   - 撞上的瞬间：屏幕反馈、底部提示
##   - 撞后 0.35 s：掀翻中，头顶状态字、HUD 状态
##   - 撞后 1.1 s：掀翻已结束、壳还在水里，再读一次
##   - 记账：BRO METER / 事故数（必须仍是一次失败一格）
##
## 输出：docs/reports/longrun/core-feel-07c-turtle-copy.json
## 运行：godot --headless --path TURBBIT res://scenes/stage7c_turtle_failure_copy.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/core-feel-07c-turtle-copy.json"
const SHOT_PATH := "res://screenshots/core-feel-07c-shark-flip.png"
const STEP := 1.0 / 60.0

var is_runner := false
var race: Node = null
var out := {}
var failures: Array = []
var last_feedback := ""
var last_hint := ""


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage7cTurtleCopyRunner"
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
		push_error("CORE-FEEL-07C: no race scene")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()
	GameManager.feedback.connect(_on_feedback)
	GameManager.hint.connect(_on_hint)

	out["generated_at"] = Time.get_datetime_string_from_system()
	out["joint_window_s"] = Tuning.ACCIDENT_JOINT_WINDOW
	out["flip_time_s"] = Tuning.FLIP_TIME
	out["dunk_time_s"] = Tuning.DUNK_TIME
	out["cases"] = {}
	out["cases"]["log"] = await _case_log()
	out["cases"]["shark"] = await _case_ride_into("shark1", "SHARK", true)
	out["cases"]["gate"] = await _case_ride_into("gate1", "DIVE_GATE", false)
	out["cases"]["wall"] = await _case_ride_into("wall1", "HIGH_WALL", false)
	_evaluate()
	_write()
	print("CORE-FEEL-07C: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _on_feedback(text: String, _style: String) -> void:
	last_feedback = text


func _on_hint(text: String) -> void:
	last_hint = text


## 浮木：走标准失败的 BRO DIVE（兔子起跳、壳撞木），壳只身撞木的那一笔。
func _case_log() -> Dictionary:
	var g := _group("log1")
	var left := float(g["rects"][0].position.x)
	var zone: Dictionary = LevelData.zone_at(left)
	_reset_at(left - 120.0, zone, float(zone["base_speed"]))
	_control("rabbit")
	_press("up")
	var t := 0.0
	while t < 2.0 and not race.hit_roles.has("log1"):
		race._physics_process(STEP)
		t += STEP
	_release("up")
	var row := _row("log1", "FLOATING_LOG", t, false)
	await _after_hit(row)
	return row


## 其余障碍：把乌龟摆在障碍前 260 px，什么都不按，让壳真实撞上去。
func _case_ride_into(group: String, kind: String, shoot: bool) -> Dictionary:
	var g := _group(group)
	var left := float(g["rects"][0].position.x)
	var zone: Dictionary = LevelData.zone_at(left)
	_reset_at(left - 260.0, zone, float(zone["base_speed"]))
	_control("turtle")
	var t := 0.0
	while t < 5.0 and not race.hit_roles.has(group):
		race._physics_process(STEP)
		t += STEP
	var row := _row(group, kind, t, shoot)
	await _after_hit(row)
	return row


func _row(group: String, kind: String, t: float, shoot: bool = false) -> Dictionary:
	var row := {
		"group": group,
		"kind": kind,
		"hit": race.hit_roles.has(group),
		"hit_at": snappedf(t, 0.01),
		"feedback": last_feedback,
		"hint": last_hint,
		"bro_meter": GameManager.bro_meter,
		"accident_count": GameManager.accident_count,
		"shoot": shoot,
	}
	return row


## 撞后 0.35 s（掀翻中）与 1.1 s（掀翻结束、壳还在水里）各读一次状态字。
func _after_hit(row: Dictionary) -> void:
	_step(0.35)
	row["flip_phase_text"] = race._turtle_phase_text()
	row["flip_hud_action"] = race.hud._turtle_action()
	row["flip_t"] = snappedf(race.turtle.flip_t, 0.01)
	row["flip_dunk_timer"] = snappedf(race.turtle.dunk_timer, 0.01)
	if bool(row.get("shoot", false)):
		await _shot(row)
	_step(0.75)
	row["dunk_phase_text"] = race._turtle_phase_text()
	row["dunk_hud_action"] = race.hud._turtle_action()
	row["dunk_flip_t"] = snappedf(race.turtle.flip_t, 0.01)
	row["dunk_timer"] = snappedf(race.turtle.dunk_timer, 0.01)
	row["bro_meter_after"] = GameManager.bro_meter
	row["accident_count_after"] = GameManager.accident_count
	var reasons: Array = []
	for e in GameManager.score_log:
		if String(e.get("reason", "")).begins_with("mistake:"):
			reasons.append(String(e.get("reason", "")))
	row["mistakes"] = reasons


func _evaluate() -> void:
	var expected := {
		"log": ["feedback.dive_late", "hint.dive_late"],
		"shark": ["feedback.shark_hit", "hint.shark_hit"],
		"gate": ["feedback.gate_hit", "hint.gate_hit"],
		"wall": ["feedback.wall_hit", "hint.wall_hit"],
	}
	for key in ["log", "shark", "gate", "wall"]:
		var c: Dictionary = out["cases"][key]
		_expect("%s hit registered (hit=%s at %.2fs)" % [
			key, str(c["hit"]), float(c["hit_at"])], bool(c["hit"]))
		_expect("%s feedback names the hazard (%s)" % [key, String(c["feedback"])],
			String(c["feedback"]) == Locale.t(expected[key][0]))
		_expect("%s hint tells the right next move (%s)" % [key, String(c["hint"])],
			String(c["hint"]) == Locale.t(expected[key][1]))
		_expect("%s not one generic wave line (%s)" % [key, String(c["feedback"])],
			not String(c["feedback"]).contains("浪") or key == "log")
		_expect("%s flip reads as belly-up (%s / %s, flip_t=%.2f)" % [
			key, String(c["flip_phase_text"]), String(c["flip_hud_action"]),
			float(c["flip_t"])],
			float(c["flip_t"]) > 0.0
			and String(c["flip_phase_text"]) == Locale.state_name("BELLY_UP")
			and String(c["flip_hud_action"]) == Locale.state_name("BELLY_UP"))
		# 浮木的失败会同时触发兔子落水救援：HUD 那行该报“救援”，头顶的壳仍然
		# 是“被浪压进水里”。其余三种障碍没有救援介入，两处都必须是没入水里。
		var dunk_hud_ok: bool = String(c["dunk_hud_action"]) == Locale.state_name("DUNKED") \
			or (key == "log" and String(c["dunk_hud_action"]) == Locale.state_name("RESCUING"))
		_expect("%s after the flip the shell is still dunked (%s / %s, flip=%.2f dunk=%.2f)" % [
			key, String(c["dunk_phase_text"]), String(c["dunk_hud_action"]),
			float(c["dunk_flip_t"]), float(c["dunk_timer"])],
			float(c["dunk_flip_t"]) <= 0.0 and float(c["dunk_timer"]) > 0.0
			and String(c["dunk_phase_text"]) == Locale.state_name("DUNKED")
			and dunk_hud_ok)
		_expect("%s still charges exactly one slot (meter=%d accidents=%d, %s)" % [
			key, int(c["bro_meter_after"]), int(c["accident_count_after"]),
			str(c["mistakes"])],
			int(c["bro_meter_after"]) == 1 and int(c["accident_count_after"]) == 1)
		var bad := "换回乌龟"
		_expect("%s no contradictory advice (%s / %s)" % [
			key, String(c["feedback"]), String(c["hint"])],
			not (String(c["feedback"]) + String(c["hint"])).contains(bad))


# ---------------------------------------------------------------- 驱动

func _group(name: String) -> Dictionary:
	for g in race.hazard_groups:
		if String(g["group"]) == name:
			return g
	return {}


func _reset_at(x: float, zone: Dictionary, v: float) -> void:
	Input.action_release("up")
	Input.action_release("down")
	Input.action_release("shift")
	last_feedback = ""
	last_hint = ""
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.oxygen = Tuning.OXYGEN_MAX
	GameManager.oxygen_phase = "SAFE"
	GameManager.accident_count = 0
	GameManager.joint_accident_count = 0
	GameManager.total_score = 0
	GameManager.score_log.clear()
	GameManager.clear_bro_meter()
	GameManager.current_control = "rabbit"
	GameManager.has_shifted = false
	GameManager.combo = 0
	race.current_zone = zone
	race.showtime_active = false
	race.showtime_t = 0.0
	race.joint_show_t = 0.0
	race.finishing = false
	race.hazard_cooldown = 0.0
	race.accident_flash = 0.0
	race._accident_t = 0.0
	race.turtle_repair = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.rabbit_stun = 0.0
	race.emergency_timer = 0.0
	race.combo = 0
	race.combo_max = 0
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.group_actions.clear()
	race.input_buffer_log.clear()
	race.accident_events.clear()
	race.accident_event_log.clear()
	race.accident_event_seq = 0
	race.accident_event_time = 0.0
	race.rescue_last_result = ""
	race.rescue_last_reason = ""
	race._clear_dive_assist()
	race.reset_brains()
	race.world_end = 1.0e9
	race.turtle.reset(Vector2(x, Tuning.NEUTRAL_DEPTH))
	race.turtle.base_speed = v
	race.turtle.speed = v
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	race.rabbit.state = "RIDING"
	race._buf_action = ""
	race._buf_age = 0.0
	var banner := race.get_node_or_null("Banner")
	if banner != null:
		banner.label.text = ""
		banner.timer = 0.0


func _control(who: String) -> void:
	if GameManager.current_control != who:
		GameManager.set_control(who)


func _press(action: String) -> void:
	if not Input.is_action_pressed(action):
		Input.action_press(action)


func _release(action: String) -> void:
	if Input.is_action_pressed(action):
		Input.action_release(action)


func _step(seconds: float) -> void:
	var guard := 0
	while guard < int(seconds / STEP):
		race._physics_process(STEP)
		guard += 1


func _shot(row: Dictionary) -> void:
	if DisplayServer.get_name() == "headless":
		return
	race.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(ProjectSettings.globalize_path(SHOT_PATH))
	row["screenshot"] = SHOT_PATH
	row["screenshot_err"] = err


func _expect(msg: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + msg)
	if not ok:
		failures.append(msg)


func _write() -> void:
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out, "  "))
		f.close()
