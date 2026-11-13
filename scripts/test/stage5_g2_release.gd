extends Node
## TBB-EXPERIENCE-REBUILD-05 G2：BRO DIVE 的“该松手了”提示验收探针。
##
## B3 已证明：一直按住 ↓ 也能落回壳上，但会擦水白记一次事故，画面只有水花差别。
## 本探针验三件事：
##   1) 提示在“兔子空中 + 壳仍在浮木右侧下潜”时出现，且长在正式 HUD 的乌龟行；
##   2) 按提示松手 → 0 事故；一直按住 → 仍记 1 次（提示不消灭代价）；
##   3) 礁拱下潜 / 接应下潜 / 松手后不出现该提示。
##
## 输出：docs/reports/longrun/rebuild05-g2-release.json
## 运行：godot --headless --path TURBBIT res://scenes/stage5_g2_release.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/rebuild05-g2-release.json"
const GROUP := "log1"
const LEAD := 160.0
const DELAY := 0.1

var is_runner := false
var race: Node = null
var out := {}
var failures: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage5G2ReleaseRunner"
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
		push_error("G2 RELEASE: no race/HUD")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = false
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()

	var g := _group(GROUP)
	if g.is_empty():
		push_error("G2 RELEASE: group %s not found" % GROUP)
		get_tree().quit(1)
		return

	out["generated_at"] = Time.get_datetime_string_from_system()
	out["group"] = GROUP
	out["trials"] = {
		"follow_cue": _trial(g, true),
		"hold_through": _trial(g, false),
	}
	out["absence"] = _absence()
	_evaluate()
	_write()
	print("G2 RELEASE: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


## 一次完整 BRO DIVE。release_on_cue=true 时：提示出现的当帧松手；
## false 时一直按住到结束（对照：仍会擦水记一次事故）。
func _trial(g: Dictionary, release_on_cue: bool) -> Dictionary:
	var rate := 60.0
	var step := 1.0 / rate
	var start: float = race._group_start(g)
	var end: float = race._group_end(g)
	var key := String(g["group"])
	_reset(start - LEAD, LevelData.zone_at(start))

	Input.action_press("up")
	race._note_up_input()
	race._physics_process(step)
	Input.action_release("up")

	var waited := step
	while waited < DELAY:
		race._physics_process(step)
		waited += step
	# CORE-FEEL-07 P0-A：起跳后 SHIFT 到乌龟会触发辅助下潜，上浮改自动，
	# “松开 ↓”提示按设计不再出现（dive_release_ready() 在辅助期间直接返回 false）。
	# 本探针验的是手动下潜那条路（例如换人晚于辅助窗口），所以先撤掉辅助；
	# 辅助本身由 stage7_bro_dive_assist 验收。
	race._clear_dive_assist()
	GameManager.toggle_control()
	Input.action_press("down")

	var cue_seen := false
	var cue_x := -1.0
	var cue_text := ""
	var cue_rabbit := ""
	var cue_turtle := ""
	var cue_panels_pct := 0.0
	var cue_row_en := ""
	var cue_fits_en := false
	var released := false
	var release_true_frames := -1
	var hold_after_cue := 0
	var guard := 0
	while guard < int(rate * 6.0) and race.turtle.position.x <= end + 300.0:
		var live: bool = race.dive_release_ready()
		if live and not cue_seen:
			cue_seen = true
			cue_x = race.turtle.position.x
			race.hud._refresh()
			race.hud._layout()
			cue_text = String(race.hud.turtle_coop.text).strip_edges() \
				if race.hud.turtle_coop.visible else ""
			cue_rabbit = String(race.hud.rabbit_coop.text).strip_edges() \
				if race.hud.rabbit_coop.visible else ""
			cue_turtle = cue_text
			cue_panels_pct = _panel_area_pct()
			# 中英文都要量：同一个提示帧切一次语言，读英文行与面板宽高。
			Locale.language = "en"
			race.hud._refresh()
			race.hud._layout()
			race.hud._layout()
			cue_row_en = String(race.hud.turtle_coop.text).strip_edges() \
				if race.hud.turtle_coop.visible else ""
			var panel: Control = race.hud._panels["tl"]
			cue_fits_en = panel.size.x + 0.5 >= panel.get_combined_minimum_size().x \
				and panel.size.y + 0.5 >= panel.get_combined_minimum_size().y
			cue_panels_pct = maxf(cue_panels_pct, _panel_area_pct())
			Locale.language = "zh"
			race.hud._refresh()
			race.hud._layout()
		if cue_seen and not released and release_on_cue:
			Input.action_release("down")
			released = true
			# 松手后整段必须一直不亮（不再主动下潜）：检查之后的 30 帧。
			var after := 0
			race.hud._refresh()
			for k in 30:
				race._physics_process(step)
				guard += 1
				if race.dive_release_ready():
					after += 1
			release_true_frames = after
			continue
		if cue_seen and not released:
			hold_after_cue += 1
		race._physics_process(step)
		guard += 1
		if race.hit_groups.has(key):
			break
	Input.action_release("down")

	return {
		"release_on_cue": release_on_cue,
		"cue_seen": cue_seen,
		"cue_x_past_end": snappedf(cue_x - end, 0.1) if cue_seen else -1.0,
		"cue_row": cue_turtle,
		"cue_row_en": cue_row_en,
		"cue_fits_en": cue_fits_en,
		"cue_rabbit_row": cue_rabbit,
		"cue_panels_pct": snappedf(cue_panels_pct, 2),
		"hold_steps_after_cue": hold_after_cue,
		"cue_true_frames_after_release": release_true_frames,
		"holding": race.mount.state != "RIDING",
		"state": race.mount.state,
		"riding": race.mount.state == "RIDING",
		"accidents": GameManager.accident_count,
		"accident_state": GameManager.accident_state,
		"hit": race.hit_groups.has(key),
		"end_x": snappedf(race.turtle.position.x, 0.1),
	}


## 三种“不该出现”的场景：礁拱下潜、接应下潜、以及根本没在空中。
func _absence() -> Dictionary:
	var rows := {}
	# a) 礁拱（DIVE_GATE）下潜：控乌龟按住 ↓，兔子在壳上。
	var gate := _first_kind("DIVE_GATE")
	_reset(LevelData.group_start(gate) - 120.0, LevelData.zone_at(LevelData.group_start(gate)))
	GameManager.toggle_control()
	Input.action_press("down")
	var gate_true := 0
	for i in 120:
		race._physics_process(1.0 / 60.0)
		if race.dive_release_ready():
			gate_true += 1
	Input.action_release("down")
	race.hud._refresh()
	rows["dive_gate"] = {
		"predicate": race.dive_release_ready(),
		"frames_true": gate_true,
		"frames": 120,
		"turtle_row": String(race.hud.turtle_coop.text).strip_edges() \
			if race.hud.turtle_coop.visible else "",
	}
	# b) 接应下潜：RABBIT_WATER + 追接。
	var log := _group(GROUP)
	_reset(LevelData.group_start(log) - 60.0, LevelData.zone_at(LevelData.group_start(log)))
	GameManager.accident_state = "RABBIT_WATER"
	race.mount.mark_rescue_active(Tuning.RESCUE_ACTIVE_TIME)
	GameManager.current_control = "turtle"
	Input.action_press("down")
	var rescue_true := 0
	for i in 120:
		race._physics_process(1.0 / 60.0)
		if race.dive_release_ready():
			rescue_true += 1
	Input.action_release("down")
	race.hud._refresh()
	rows["rescue"] = {
		"predicate": race.dive_release_ready(),
		"frames_true": rescue_true,
		"frames": 120,
		"turtle_row": String(race.hud.turtle_coop.text).strip_edges() \
			if race.hud.turtle_coop.visible else "",
	}
	return rows


func _first_kind(kind: String) -> Dictionary:
	for g in race.hazard_groups:
		if String(g["kind"]) == kind:
			return g
	return {}


func _group(name: String) -> Dictionary:
	for g in race.hazard_groups:
		if String(g["group"]) == name:
			return g
	return {}


func _panel_area_pct() -> float:
	var area := 0.0
	for c in race.hud._panels:
		var p: Control = race.hud._panels[c]
		if p.visible:
			area += p.size.x * p.size.y
	var vp := get_viewport().get_visible_rect().size
	return area / (vp.x * vp.y) * 100.0


func _reset(x: float, zone: Dictionary) -> void:
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
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	race._buf_action = ""
	race._buf_age = 0.0


func _evaluate() -> void:
	var follow: Dictionary = out["trials"]["follow_cue"]
	var hold: Dictionary = out["trials"]["hold_through"]
	_expect("follow: cue appears", bool(follow["cue_seen"]))
	_expect("follow: cue lands on the turtle row (%s)" % follow["cue_row"],
		String(follow["cue_row"]).contains("松开"))
	_expect("follow: english cue is present (%s)" % follow["cue_row_en"],
		String(follow["cue_row_en"]).contains("RELEASE"))
	_expect("follow: english cue fits the panel", bool(follow["cue_fits_en"]))
	_expect("follow: panels stay under 8%% with the cue visible (%.2f%%)"
		% float(follow["cue_panels_pct"]), float(follow["cue_panels_pct"]) <= 8.0)
	_expect("follow: releasing on the cue costs no accident (%d)" % int(follow["accidents"]),
		int(follow["accidents"]) == 0)
	_expect("follow: rabbit is back on the shell (%s)" % follow["state"],
		bool(follow["riding"]))
	_expect("hold: cue also appears when the player keeps holding", bool(hold["cue_seen"]))
	_expect("hold: ignoring the cue still costs exactly 1 accident (%d)"
		% int(hold["accidents"]), int(hold["accidents"]) == 1)
	_expect("hold: reward for holding is not a crash (%s)" % hold["state"],
		bool(hold["riding"]))
	var abs_rows: Dictionary = out["absence"]
	_expect("follow: cue stays off for 30 frames after release (%d)"
		% int(follow["cue_true_frames_after_release"]),
		int(follow["cue_true_frames_after_release"]) == 0)
	_expect("dive gate: no release cue in 120 frames (%d)" % int(abs_rows["dive_gate"]["frames_true"]),
		int(abs_rows["dive_gate"]["frames_true"]) == 0)
	_expect("rescue dive: no release cue in 120 frames (%d)"
		% int(abs_rows["rescue"]["frames_true"]),
		int(abs_rows["rescue"]["frames_true"]) == 0)


func _expect(label: String, ok: bool) -> void:
	if not ok:
		failures.append(label)


func _write() -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f == null:
		push_error("G2 RELEASE: cannot write " + OUT_PATH)
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()
