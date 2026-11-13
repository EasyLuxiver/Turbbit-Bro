extends Node
## TBB-EXPERIENCE-REBUILD-05 G5：接人 / 救回成功时角色本体弹一下的验收探针。
##
## 与 G4 共用 celebrate_t -> celebration_offset()，只多两个触发点：
##   _apply_carry_result("pickup") / ("rescue")。
## 验：
##   1) 真实抬升（_begin_carry，非瞬移）结束后两类成功各自触发，种类对得上；
##   2) 普通跳跃、礁拱干净下潜、没接住的恢复（rescue_return）都不触发；
##   3) 0.34 s 内归零；只改画法，rabbit.position 不动；事故数不变。
##
## 输出：docs/reports/longrun/rebuild05-g5-carry.json
## 运行：godot --headless --path TURBBIT res://scenes/stage5_g5_carry.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/rebuild05-g5-carry.json"
const STEP := 1.0 / 60.0
const CARRY_AWAY := Vector2(-200.0, 60.0)

var is_runner := false
var race: Node = null
var out := {}
var failures: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage5G5CarryRunner"
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
		push_error("G5 CARRY: no race")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()

	out["generated_at"] = Time.get_datetime_string_from_system()
	out["pickup"] = _carry_case("pickup")
	out["rescue"] = _carry_case("rescue")
	out["controls"] = _controls()
	_evaluate()
	_write()
	print("G5 CARRY: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


## 真实抬升：兔子放在离壳 200 px 的位置，走 _begin_carry（会经过 _tick_carry 才落地）。
func _carry_case(kind: String) -> Dictionary:
	_reset(200.0)
	var mp: Vector2 = race.turtle.get_mount_point()
	race.rabbit.position = mp + CARRY_AWAY
	var pickup_before: int = GameManager.pickup_count
	var rescue_before: int = GameManager.rescue_success_count
	if kind == "rescue":
		GameManager.accident_state = "RABBIT_WATER"
	race._begin_carry(kind, mp)
	# 抬升走的是逐帧插值，不能瞬移：先数帧，确认 celebrate 不是在 _begin_carry 当帧就有。
	var carry_frames := 0
	while carry_frames < 300 and race.celebrate_t < 0.0:
		race._physics_process(STEP)
		carry_frames += 1
	var reading := _celebrate_reading(kind, carry_frames)
	reading["carry_frames_before_trigger"] = carry_frames
	reading["pickup_count_delta"] = GameManager.pickup_count - pickup_before
	reading["rescue_count_delta"] = GameManager.rescue_success_count - rescue_before
	reading["accident_state"] = GameManager.accident_state
	if kind == "pickup":
		reading["banner_expected"] = true
	return reading


## 成功后 40 帧的读数：触发种类、峰值位移、是否只改画法、是否自然归零。
func _celebrate_reading(expected_kind: String, _carry_frames: int) -> Dictionary:
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


## 不该触发的对照：普通跳跃、礁拱干净下潜、没接住的恢复。
func _controls() -> Dictionary:
	# a) 普通跳跃：空地，没有任何组在附近。必须跑满整段滞空，落到壳上为止——
	#    日常落壳也走 _apply_carry_result("pickup")，但那次不该放庆祝弹跳。
	_reset(200.0)
	Input.action_press("up")
	race._note_up_input()
	var jump_peak := 0.0
	var landed := false
	var jumped := false
	for i in 150:
		race._physics_process(STEP)
		jump_peak = maxf(jump_peak, absf(race.celebration_offset().y))
		if i == 2:
			Input.action_release("up")
		if String(race.mount.state) == "AIRBORNE":
			jumped = true
		elif jumped and String(race.mount.state) == "RIDING":
			landed = true
	var jump := {
		"celebrate_t": snappedf(race.celebrate_t, 0.001),
		"peak_hop_px": snappedf(jump_peak, 0.1),
		"jumped": jumped,
		"landed": landed,
		"pickup_count": GameManager.pickup_count,
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
	# c) 没接住的恢复（rescue_return）：例外，不该庆祝。
	_reset(200.0)
	GameManager.accident_state = "RABBIT_WATER"
	var mp: Vector2 = race.turtle.get_mount_point()
	race.rabbit.position = mp + CARRY_AWAY
	race._begin_carry("rescue_return", mp)
	var return_peak := 0.0
	for i in 120:
		race._physics_process(STEP)
		return_peak = maxf(return_peak, absf(race.celebration_offset().y))
	var return_row := {
		"celebrate_t": snappedf(race.celebrate_t, 0.001),
		"peak_hop_px": snappedf(return_peak, 0.1),
		"accident_state": GameManager.accident_state,
	}
	return {"plain_jump": jump, "gate_dive": gate_row, "rescue_return": return_row}


func _evaluate() -> void:
	var pickup: Dictionary = out["pickup"]
	var rescue: Dictionary = out["rescue"]
	_expect("pickup success: celebration triggers (%s)"
		% pickup.get("celebrate_kind", ""),
		String(pickup.get("celebrate_kind", "")) == "pickup")
	_expect("pickup success: hop is visible (%.1f px over %d frames)"
		% [float(pickup.get("peak_hop_px", 0.0)), int(pickup.get("frames_nonzero", 0))],
		float(pickup.get("peak_hop_px", 0.0)) >= 8.0
			and int(pickup.get("frames_nonzero", 0)) >= 10)
	_expect("pickup success: draw offset does not move the rabbit",
		bool(pickup.get("position_unchanged_by_offset", false)))
	_expect("pickup success: hop ends by 0.4 s (%s frames)"
		% str(pickup.get("cleared_after_frames", -1)),
		int(pickup.get("cleared_after_frames", -1)) > 0
			and int(pickup.get("cleared_after_frames", -1)) <= 25)
	_expect("pickup success: only fires after the carry, not at begin (%s)"
		% str(pickup.get("carry_frames_before_trigger", 0)),
		int(pickup.get("carry_frames_before_trigger", 0)) >= 2)
	_expect("pickup success: pickup_count advances by 1 (%s)"
		% str(pickup.get("pickup_count_delta", 0)),
		int(pickup.get("pickup_count_delta", 0)) == 1)
	_expect("rescue success: celebration triggers (%s)"
		% rescue.get("celebrate_kind", ""),
		String(rescue.get("celebrate_kind", "")) == "rescue")
	_expect("rescue success: hop is visible (%.1f px)"
		% float(rescue.get("peak_hop_px", 0.0)),
		float(rescue.get("peak_hop_px", 0.0)) >= 8.0)
	_expect("rescue success: rescue_count advances by 1 (%s)"
		% str(rescue.get("rescue_count_delta", 0)),
		int(rescue.get("rescue_count_delta", 0)) == 1)
	_expect("rescue success: accident state cleared (%s)"
		% rescue.get("accident_state", ""),
		String(rescue.get("accident_state", "")) == "NONE")
	var c: Dictionary = out["controls"]
	_expect("plain jump: lands back on the shell, and the landing does not celebrate (peak %.1f px)"
		% float(c["plain_jump"]["peak_hop_px"]),
		bool(c["plain_jump"].get("jumped", false))
			and bool(c["plain_jump"].get("landed", false))
			and float(c["plain_jump"]["peak_hop_px"]) <= 0.01)
	_expect("clean gate dive: no celebration (peak %.1f px)"
		% float(c["gate_dive"]["peak_hop_px"]),
		float(c["gate_dive"]["peak_hop_px"]) <= 0.01)
	_expect("missed rescue return: no celebration (peak %.1f px)"
		% float(c["rescue_return"]["peak_hop_px"]),
		float(c["rescue_return"]["peak_hop_px"]) <= 0.01)
	_expect("no new accidents in either success case (%d / %d)"
		% [int(pickup.get("accidents", -1)), int(rescue.get("accidents", -1))],
		int(pickup.get("accidents", -1)) == 0 and int(rescue.get("accidents", -1)) == 0)


func _expect(label: String, ok: bool) -> void:
	if not ok:
		failures.append(label)


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
	race.carry_kind = ""
	race.carry_dur = 0.0
	race.carry_t = 0.0
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
		push_error("G5 CARRY: cannot write " + OUT_PATH)
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()
