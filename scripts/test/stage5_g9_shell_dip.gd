extends Node
## TBB-EXPERIENCE-REBUILD-05 G9：兔子落回壳上时壳下沉再回弹的验收探针。
##
## 制作人 2026-11-11 第 4 条：兔子跳回来、乌龟接住，“乌龟只是切换过来了，
## 并没有做什么动作”。G5/G7/G8 补的是兔子弹跳、横幅和提示环——壳本身没动过。
## 本项让壳在承重那一下下沉（画法偏移），验：
##   1) 普通跳跃落壳：1–2 帧内见峰值 ≥5 px，0.35 s 内归零；
##   2) 真接住（离壳 200 px 抬升回来）≥8 px、救回 ≥10 px，两类都触发；
##   3) 只改画法：位置与判定框不动；
##   4) 不落壳时恒为 0（干净下潜过礁拱、纯巡航）；
##   5) 有回弹（中途出现负值），不是单向沉下去。
##
## 输出：docs/reports/longrun/rebuild05-g9-shell-dip.json
## 运行：godot --headless --path TURBBIT res://scenes/stage5_g9_shell_dip.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/rebuild05-g9-shell-dip.json"
const STEP := 1.0 / 60.0
const CARRY_AWAY := Vector2(-200.0, 60.0)

var is_runner := false
var race: Node = null
var out := {}
var failures: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage5G9ShellDipRunner"
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
		push_error("G9 SHELL DIP: no race")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()

	out["generated_at"] = Time.get_datetime_string_from_system()
	out["plain_jump"] = _plain_jump()
	out["pickup"] = _carry_case("pickup")
	out["rescue"] = _carry_case("rescue")
	out["controls"] = _controls()
	out["draw_only"] = _draw_only()
	_evaluate()
	_write()
	print("G9 SHELL DIP: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


## 1) 普通跳跃：从壳上跳起再落回，落壳那一帧开始下沉。
func _plain_jump() -> Dictionary:
	_reset(200.0)
	var pickup_before: int = GameManager.pickup_count
	Input.action_press("up")
	race._note_up_input()
	var jumped := false
	var landed := false
	var land_frame := -1
	var peak := 0.0
	var dip_frame_one := 0.0
	var first_neg_frame := -1
	var cleared_frame := -1
	for i in 150:
		race._physics_process(STEP)
		if i == 2:
			Input.action_release("up")
		var off: float = race.shell_dip_offset()
		if String(race.mount.state) == "AIRBORNE":
			jumped = true
		elif jumped and String(race.mount.state) == "RIDING" and not landed:
			landed = true
			land_frame = i
		if landed:
			if i - land_frame == 0:
				dip_frame_one = off
			peak = maxf(peak, off)
			if first_neg_frame < 0 and off < -0.5:
				first_neg_frame = i - land_frame
			if cleared_frame < 0 and i - land_frame > 3 and absf(off) <= 0.01:
				cleared_frame = i - land_frame
	var quiet := 0.0
	for i in 30:
		race._physics_process(STEP)
		quiet = maxf(quiet, absf(race.shell_dip_offset()))
	return {
		"jumped": jumped,
		"landed": landed,
		"land_frame": land_frame,
		"dip_at_land_frame": snappedf(dip_frame_one, 0.1),
		"peak_dip_px": snappedf(peak, 0.1),
		"rebound_frame": first_neg_frame,
		"cleared_after_frames": cleared_frame,
		"quiet_after_cleared": snappedf(quiet, 0.001),
		"pickup_count_delta": GameManager.pickup_count - pickup_before,
		"accidents": GameManager.accident_count,
	}


## 2) 真接住 / 救回：离壳 200 px 的抬升（走 _tick_carry，不瞬移）。
func _carry_case(kind: String) -> Dictionary:
	_reset(200.0)
	var mp: Vector2 = race.turtle.get_mount_point()
	race.rabbit.position = mp + CARRY_AWAY
	var pickup_before: int = GameManager.pickup_count
	var rescue_before: int = GameManager.rescue_success_count
	if kind == "rescue":
		GameManager.accident_state = "RABBIT_WATER"
	race._begin_carry(kind, mp)
	var carry_frames := 0
	while carry_frames < 300 and String(race.mount.state) != "RIDING":
		race._physics_process(STEP)
		carry_frames += 1
	var peak := 0.0
	var rebound := false
	var frames_nonzero := 0
	var cleared_frame := -1
	for i in 40:
		var off: float = race.shell_dip_offset()
		peak = maxf(peak, off)
		if off < -0.5:
			rebound = true
		if absf(off) > 0.01:
			frames_nonzero += 1
		if cleared_frame < 0 and i > 3 and absf(off) <= 0.01:
			cleared_frame = i
		race._physics_process(STEP)
	return {
		"kind": kind,
		"carry_frames": carry_frames,
		"peak_dip_px": snappedf(peak, 0.1),
		"rebound": rebound,
		"frames_nonzero": frames_nonzero,
		"cleared_after_frames": cleared_frame,
		"pickup_count_delta": GameManager.pickup_count - pickup_before,
		"rescue_count_delta": GameManager.rescue_success_count - rescue_before,
		"accident_state": GameManager.accident_state,
		"accidents": GameManager.accident_count,
		"mount": String(race.mount.state),
	}


## 3) 不落壳时的对照：干净下潜过礁拱、以及在壳上静跑。
func _controls() -> Dictionary:
	var gate := _first_kind("DIVE_GATE")
	var gate_start: float = race._group_start(gate)
	_reset(gate_start - 140.0, LevelData.zone_at(gate_start))
	GameManager.toggle_control()
	Input.action_press("down")
	var gate_peak := 0.0
	var gate_moved := false
	for i in 160:
		race._physics_process(STEP)
		gate_peak = maxf(gate_peak, absf(race.shell_dip_offset()))
	Input.action_release("down")
	gate_moved = race.turtle.position.x > gate_start
	# 纯巡航：没有任何落壳，也不该出现下沉。
	_reset(200.0)
	var ride_peak := 0.0
	var ride_frames := 0
	for i in 60:
		race._physics_process(STEP)
		if absf(race.shell_dip_offset()) > 0.01:
			ride_frames += 1
		ride_peak = maxf(ride_peak, absf(race.shell_dip_offset()))
	return {
		"gate_dive": {
			"peak_dip_px": snappedf(gate_peak, 0.1),
			"passed_start": gate_moved,
			"accident_state": GameManager.accident_state,
		},
		"plain_ride": {
			"peak_dip_px": snappedf(ride_peak, 0.1),
			"frames_nonzero": ride_frames,
		},
	}


## 4) 只改画法：把所在区基速临时改成 0（_physics_process 每帧会重读 current_zone），
##    触发下沉前后位置与判定框必须逐字相同。
func _draw_only() -> Dictionary:
	var still: Dictionary = LevelData.zone_at(200.0).duplicate()
	still["base_speed"] = 0.0
	_reset(200.0, still)
	race._physics_process(STEP)
	var t_pos: Vector2 = race.turtle.position
	var r_pos: Vector2 = race.rabbit.position
	var t_rect: Rect2 = race.turtle.get_body_rect()
	var r_rect: Rect2 = race.rabbit.get_body_rect()
	race._shell_dip(Tuning.SHELL_DIP_CATCH)
	var peak := 0.0
	for i in 12:
		race._physics_process(STEP)
		peak = maxf(peak, race.shell_dip_offset())
	var pos_same: bool = race.turtle.position == t_pos and race.rabbit.position == r_pos
	var rect_same: bool = race.turtle.get_body_rect() == t_rect \
		and race.rabbit.get_body_rect() == r_rect
	return {
		"peak_dip_px": snappedf(peak, 0.1),
		"turtle_position_unchanged": race.turtle.position == t_pos,
		"rabbit_position_unchanged": race.rabbit.position == r_pos,
		"turtle_rect_unchanged": race.turtle.get_body_rect() == t_rect,
		"rabbit_rect_unchanged": race.rabbit.get_body_rect() == r_rect,
		"positions_unchanged": pos_same,
		"rects_unchanged": rect_same,
	}


func _evaluate() -> void:
	var p: Dictionary = out["plain_jump"]
	_expect("plain jump: landed on the shell", bool(p.get("landed", false)))
	_expect("plain jump: dip visible at landing (%.1f px in frame %d)"
		% [float(p.get("peak_dip_px", 0.0)), int(p.get("land_frame", -1))],
		float(p.get("peak_dip_px", 0.0)) >= 5.0)
	_expect("plain jump: dip starts on the landing frame (%.1f px)"
		% float(p.get("dip_at_land_frame", 0.0)),
		float(p.get("dip_at_land_frame", 0.0)) >= 5.0)
	_expect("plain jump: returns to 0 within 0.35 s (%s frames)"
		% str(p.get("cleared_after_frames", -1)),
		int(p.get("cleared_after_frames", -1)) > 0
			and int(p.get("cleared_after_frames", -1)) <= 21)
	_expect("plain jump: stays at 0 after settling (%.3f px)"
		% float(p.get("quiet_after_cleared", 0.0)),
		float(p.get("quiet_after_cleared", 0.0)) <= 0.01)
	_expect("plain jump: rebound exists (first negative frame %d)"
		% int(p.get("rebound_frame", -1)),
		int(p.get("rebound_frame", -1)) >= 0)
	_expect("plain jump: pickup_count advances by 1 (%s)"
		% str(p.get("pickup_count_delta", 0)),
		int(p.get("pickup_count_delta", 0)) == 1)
	var c: Dictionary = out["pickup"]
	_expect("real pickup: dip heavier than a routine landing (%.1f px)"
		% float(c.get("peak_dip_px", 0.0)),
		float(c.get("peak_dip_px", 0.0)) >= 8.0)
	_expect("real pickup: triggers after the carry, not at begin (%s frames)"
		% str(c.get("carry_frames", 0)),
		int(c.get("carry_frames", 0)) >= 2 and int(c.get("frames_nonzero", 0)) >= 8)
	_expect("real pickup: pickup_count +1 (%s)"
		% str(c.get("pickup_count_delta", 0)),
		int(c.get("pickup_count_delta", 0)) == 1)
	var r: Dictionary = out["rescue"]
	_expect("rescue: heaviest dip (%.1f px)" % float(r.get("peak_dip_px", 0.0)),
		float(r.get("peak_dip_px", 0.0)) >= 10.0)
	_expect("rescue: rescue_count +1 (%s) and accident cleared (%s)"
		% [str(r.get("rescue_count_delta", 0)), str(r.get("accident_state", ""))],
		int(r.get("rescue_count_delta", 0)) == 1
			and String(r.get("accident_state", "")) == "NONE")
	var ctl: Dictionary = out["controls"]
	_expect("clean gate dive: no dip (%.1f px, passed=%s)"
		% [float(ctl["gate_dive"]["peak_dip_px"]), str(ctl["gate_dive"]["passed_start"])],
		bool(ctl["gate_dive"]["passed_start"])
			and float(ctl["gate_dive"]["peak_dip_px"]) <= 0.01)
	_expect("plain ride: no dip (%d frames)"
		% int(ctl["plain_ride"]["frames_nonzero"]),
		int(ctl["plain_ride"]["frames_nonzero"]) == 0)
	var d: Dictionary = out["draw_only"]
	_expect("draw only: positions do not move", bool(d.get("positions_unchanged", false)))
	_expect("draw only: hit rects do not move", bool(d.get("rects_unchanged", false)))
	_expect("no accidents in any landing case (%d / %d / %d)"
		% [int(p.get("accidents", -1)), int(c.get("accidents", -1)),
			int(r.get("accidents", -1))],
		int(p.get("accidents", -1)) == 0 and int(c.get("accidents", -1)) == 0
			and int(r.get("accidents", -1)) == 0)


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
	race.shell_dip_t = -1.0
	race.shell_dip_amp = 0.0
	race.shell_dip_peak = 0.0
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
		push_error("G9 SHELL DIP: cannot write " + OUT_PATH)
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()
