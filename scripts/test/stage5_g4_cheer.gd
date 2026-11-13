extends Node
## TBB-EXPERIENCE-REBUILD-05 G4：连招成功时角色本体弹一下的验收探针。
##
## 只加画法偏移（celebrate_t -> celebration_offset()），rabbit.position 不动。
## 验：
##   1) 真实 BRO DIVE 成功（log1）与 BRO OLLIE 成功（wall1）都会触发；
##   2) 普通跳跃、礁拱干净下潜不触发；
##   3) 0.34 s 内自然归零，重新成功会重新计时；事故数不变。
##
## 输出：docs/reports/longrun/rebuild05-g4-cheer.json
## 运行：godot --headless --path TURBBIT res://scenes/stage5_g4_cheer.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/rebuild05-g4-cheer.json"
const STEP := 1.0 / 60.0
const LOG := "log1"
const WALL := "wall1"
const KICK_OFFSET := 60.0
const LEAD := 160.0
const DELAY := 0.1

var is_runner := false
var race: Node = null
var out := {}
var failures: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage5G4CheerRunner"
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
		push_error("G4 CHEER: no race")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()

	out["generated_at"] = Time.get_datetime_string_from_system()
	out["dive"] = _case_dive()
	out["ollie"] = _case_ollie()
	out["controls"] = _controls()
	_evaluate()
	_write()
	print("G4 CHEER: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


## 真实 BRO DIVE：标准时机起跳、0.1 s 换人、提示出现就松手（G2 的跟提示路线）。
func _case_dive() -> Dictionary:
	var g := _group(LOG)
	if g.is_empty():
		return {"error": "no log"}
	var start: float = race._group_start(g)
	var end: float = race._group_end(g)
	_reset(start - LEAD)
	Input.action_press("up")
	race._note_up_input()
	race._physics_process(STEP)
	Input.action_release("up")
	var waited := STEP
	while waited < DELAY:
		race._physics_process(STEP)
		waited += STEP
	GameManager.toggle_control()
	Input.action_press("down")
	var guard := 0
	var released := false
	while guard < 420 and race.turtle.position.x <= end + 300.0:
		if race.dive_release_ready() and not released:
			Input.action_release("down")
			released = true
		race._physics_process(STEP)
		guard += 1
		if GameManager.accident_count > 0:
			break
		if race.celebrate_t >= 0.0:
			# 连招成功的当帧就停，接着量这一下表演。
			break
	Input.action_release("down")
	return _celebrate_reading("dive", g)


## 真实 BRO OLLIE：墙前 0.8 s 起跳，墙前 60 px 兔子蹬踏（E3 的有效窗口内）。
func _case_ollie() -> Dictionary:
	var g := _group(WALL)
	if g.is_empty():
		return {"error": "no wall"}
	var start: float = race._group_start(g)
	var spd := float(LevelData.zone_at(start)["base_speed"])
	var lead := spd * 0.8
	_reset(start - lead - 40.0)
	GameManager.current_control = "turtle"
	var guard := 0
	while guard < 600 and race.turtle.position.x < start - lead:
		race._physics_process(STEP)
		guard += 1
	Input.action_press("up")
	race._note_up_input()
	race._physics_process(STEP)
	Input.action_release("up")
	race._physics_process(STEP)
	guard = 0
	while guard < 600 and race.turtle.position.x < start - KICK_OFFSET \
			and GameManager.accident_state == "NONE":
		race._physics_process(STEP)
		guard += 1
	GameManager.current_control = "rabbit"
	Input.action_press("up")
	race._note_up_input()
	race._physics_process(STEP)
	Input.action_release("up")
	race._physics_process(STEP)
	guard = 0
	while guard < 600 and GameManager.accident_state == "NONE":
		race._physics_process(STEP)
		guard += 1
		if race.celebrate_t >= 0.0:
			break
	return _celebrate_reading("ollie", g)


## 成功后 40 帧的读数：触发种类、峰值位移、是否只改画法、是否自然归零。
func _celebrate_reading(expected_kind: String, g: Dictionary) -> Dictionary:
	var kind := String(race.celebrate_kind)
	var at_success := float(race.celebrate_t)
	var pos_before: Vector2 = race.rabbit.position
	race.celebration_offset()
	race.celebration_offset()
	var pos_after: Vector2 = race.rabbit.position
	var peak := 0.0
	var frames_nonzero := 0
	var frame_zero := -1
	for i in 40:
		var off: Vector2 = race.celebration_offset()
		if absf(off.y) > peak:
			peak = absf(off.y)
		if absf(off.y) > 1.0:
			frames_nonzero += 1
		race._physics_process(STEP)
		if frame_zero < 0 and race.celebrate_t < 0.0:
			frame_zero = i + 1
	return {
		"group": String(g.get("group", "")),
		"expected_kind": expected_kind,
		"celebrate_kind": kind,
		"celebrate_t_at_success": snappedf(at_success, 0.001),
		"peak_hop_px": snappedf(peak, 0.1),
		"frames_nonzero": frames_nonzero,
		"cleared_after_frames": frame_zero,
		"position_unchanged_by_offset": pos_before == pos_after,
		"accidents": GameManager.accident_count,
		"mount": String(race.mount.state),
		"riding": String(race.mount.state) == "RIDING",
	}


## 不该触发的对照：普通跳跃、礁拱下潜（干净通过但不是连招）。
func _controls() -> Dictionary:
	# a) 普通跳跃：空格地，没有任何组在附近。
	_reset(200.0)
	Input.action_press("up")
	race._note_up_input()
	var jump_peak := 0.0
	for i in 40:
		race._physics_process(STEP)
		jump_peak = maxf(jump_peak, absf(race.celebration_offset().y))
		if i == 2:
			Input.action_release("up")
	var jump := {
		"celebrate_t": snappedf(race.celebrate_t, 0.001),
		"peak_hop_px": snappedf(jump_peak, 0.1),
	}
	# b) 礁拱下潜：控乌龟按住 ↓ 通过，干净通过但没有连招。
	var gate := _first_kind("DIVE_GATE")
	var gate_start: float = race._group_start(gate)
	_reset(gate_start - 140.0, LevelData.zone_at(gate_start))
	GameManager.toggle_control()
	Input.action_press("down")
	var gate_peak := 0.0
	for i in 160:
		race._physics_process(STEP)
		gate_peak = maxf(gate_peak, absf(race.celebration_offset().y))
	Input.action_release("down")
	var gate_row := {
		"celebrate_t": snappedf(race.celebrate_t, 0.001),
		"peak_hop_px": snappedf(gate_peak, 0.1),
		"accident_state": GameManager.accident_state,
	}
	# c) 重新成功会重新计时：同一帧调两次，间隔 6 帧。
	race.celebrate_t = -1.0
	race._trigger_action_fx("dive", race.rabbit.position)
	var t0: float = race.celebrate_t
	for i in 6:
		race._physics_process(STEP)
	var t1: float = race.celebrate_t
	race._trigger_action_fx("dive", race.rabbit.position)
	var t2: float = race.celebrate_t
	var retrigger := {
		"first": snappedf(t0, 0.001),
		"before_second": snappedf(t1, 0.001),
		"after_second": snappedf(t2, 0.001),
		"reset": t2 <= 0.0001 and t1 > 0.0,
	}
	return {"plain_jump": jump, "gate_dive": gate_row, "retrigger": retrigger}


func _evaluate() -> void:
	var dive: Dictionary = out["dive"]
	var ollie: Dictionary = out["ollie"]
	_expect("BRO DIVE success: celebration triggers (%s)"
		% dive.get("celebrate_kind", ""),
		String(dive.get("celebrate_kind", "")) == "dive")
	_expect("BRO DIVE success: hop is visible (%.1f px over %d frames)"
		% [float(dive.get("peak_hop_px", 0.0)), int(dive.get("frames_nonzero", 0))],
		float(dive.get("peak_hop_px", 0.0)) >= 8.0
			and int(dive.get("frames_nonzero", 0)) >= 10)
	_expect("BRO DIVE success: draw offset does not move the rabbit",
		bool(dive.get("position_unchanged_by_offset", false)))
	_expect("BRO DIVE success: hop ends by 0.4 s (%s frames)"
		% str(dive.get("cleared_after_frames", -1)),
		int(dive.get("cleared_after_frames", -1)) > 0
			and int(dive.get("cleared_after_frames", -1)) <= 25)
	_expect("BRO OLLIE success: celebration triggers (%s)"
		% ollie.get("celebrate_kind", ""),
		String(ollie.get("celebrate_kind", "")) == "ollie")
	_expect("BRO OLLIE success: hop is visible (%.1f px)"
		% float(ollie.get("peak_hop_px", 0.0)),
		float(ollie.get("peak_hop_px", 0.0)) >= 8.0)
	var c: Dictionary = out["controls"]
	_expect("plain jump: no celebration (peak %.1f px)"
		% float(c["plain_jump"]["peak_hop_px"]),
		float(c["plain_jump"]["peak_hop_px"]) <= 0.01)
	_expect("clean gate dive: no celebration (peak %.1f px)"
		% float(c["gate_dive"]["peak_hop_px"]),
		float(c["gate_dive"]["peak_hop_px"]) <= 0.01)
	_expect("second success restarts the timer (%s -> %s)"
		% [str(c["retrigger"]["before_second"]), str(c["retrigger"]["after_second"])],
		bool(c["retrigger"]["reset"]))
	_expect("no new accidents in either success case (%d / %d)"
		% [int(dive.get("accidents", -1)), int(ollie.get("accidents", -1))],
		int(dive.get("accidents", -1)) == 0 and int(ollie.get("accidents", -1)) == 0)


func _expect(label: String, ok: bool) -> void:
	if not ok:
		failures.append(label)


func _group(name: String) -> Dictionary:
	for g in race.hazard_groups:
		if String(g["group"]) == name:
			return g
	return {}


func _first_kind(kind: String) -> Dictionary:
	for g in race.hazard_groups:
		if String(g["kind"]) == kind:
			return g
	return {}


func _reset(x: float, zone: Dictionary = {}) -> void:
	if zone.is_empty():
		zone = LevelData.zone_at(x)
	Input.action_release("up")
	Input.action_release("down")
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.oxygen = Tuning.OXYGEN_MAX
	GameManager.oxygen_phase = "SAFE"
	GameManager.accident_count = 0
	GameManager.pickup_count = 0
	GameManager.showtime_active = false
	GameManager.clear_bro_meter()
	GameManager.current_control = "rabbit"
	GameManager.has_shifted = false
	GameManager.combo = 0
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
	race.celebrate_t = -1.0
	race.celebrate_kind = ""
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.group_actions.clear()
	race.input_buffer_log.clear()
	race.reset_brains()
	race.current_zone = zone
	race.world_end = 1.0e9
	race.turtle.reset(Vector2(x, Tuning.NEUTRAL_DEPTH))
	race.turtle.base_speed = float(zone["base_speed"])
	race.turtle.speed = float(zone["base_speed"])
	race.turtle.speed_cap = 1.0e9
	race.turtle.daze_time = 0.0
	race.turtle.drift = 0.0
	race.turtle.dunk_timer = 0.0
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	race.rabbit.state = "RIDING"
	race._buf_action = ""
	race._buf_age = 0.0


func _write() -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f == null:
		push_error("G4 CHEER: cannot write " + OUT_PATH)
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()
