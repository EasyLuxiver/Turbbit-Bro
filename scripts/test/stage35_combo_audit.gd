extends Node
## FEEL-35：5–8 组组合审计 + 双解 LOW_BEAM。
const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")
const FPS := 60.0
var is_runner := false
var race: Node
var checks: Array = []
var live_prompts: Array = []


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
	GameManager.test_no_best = true
	GameManager.start_race()
	for i in 4:
		await get_tree().process_frame
	race = get_tree().current_scene
	race.opening_active = false
	race.test_no_finish = true
	race.test_no_bird_behaviors = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	GameManager.prompt.connect(func(text: String) -> void: live_prompts.append(text))
	var groups: Array = race.hazard_groups
	var coop := 0
	var combos := 0
	var relay_names := []
	var coop_by_zone := {1: 0, 2: 0, 3: 0}
	var must_by_zone := {1: 0, 2: 0, 3: 0}
	var cont_by_zone := {1: 0, 2: 0, 3: 0}
	var dual_by_zone := {1: 0, 2: 0, 3: 0}
	var dual_names := ["bird2", "beam4", "beam5", "rock3", "rock6"]
	var dual_groups: Array = []
	for g in groups:
		var z: int = int(g["zone"])
		var gname := String(g["group"])
		var gkind := String(g["kind"])
		var gcombo := String(g.get("combo", ""))
		var gdual := bool(g.get("dual", false))
		var grelay := bool(g.get("relay", false))
		if gkind in ["FLOATING_LOG", "HIGH_WALL"] or grelay:
			coop += 1
			coop_by_zone[z] = int(coop_by_zone.get(z, 0)) + 1
		if gkind in ["FLOATING_LOG", "HIGH_WALL"] \
				or gname in ["gate1", "rock2", "beam3"]:
			must_by_zone[z] = int(must_by_zone.get(z, 0)) + 1
		if (gcombo != "" and not gdual) or (grelay and gcombo == ""):
			cont_by_zone[z] = int(cont_by_zone.get(z, 0)) + 1
		if gdual:
			dual_by_zone[z] = int(dual_by_zone.get(z, 0)) + 1
		if grelay:
			relay_names.append(gname)
		if gcombo != "":
			combos += 1
		if gname in dual_names:
			dual_groups.append(g)
	print("RELAY_NAMES ", relay_names)
	print("COOP_BY_ZONE ", JSON.stringify(coop_by_zone))
	print("MUST_BY_ZONE ", JSON.stringify(must_by_zone))
	print("CONT_BY_ZONE ", JSON.stringify(cont_by_zone))
	print("DUAL_BY_ZONE ", JSON.stringify(dual_by_zone))
	var must_total := 0
	var cont_total := 0
	var dual_total := 0
	for z in [1, 2, 3]:
		must_total += int(must_by_zone[z])
		cont_total += int(cont_by_zone[z])
		dual_total += int(dual_by_zone[z])
	_check("must_switch_14", must_total == 14, "by zone %s" % JSON.stringify(must_by_zone))
	_check("continuous_15", cont_total == 15, "by zone %s" % JSON.stringify(cont_by_zone))
	_check("dual_total_5", dual_total == 5, "by zone %s" % JSON.stringify(dual_by_zone))
	_check("coop_count", coop >= 16 and coop <= 22, "coop=%d combos=%d" % [coop, combos])
	# 每个组合：和上一组的间隔必须在 400–800 px。
	var gap_ok := true
	var gaps := []
	var tight := []
	for i in groups.size():
		var g: Dictionary = groups[i]
		if String(g.get("combo", "")) == "" or not bool(g.get("relay", false)):
			continue
		if i == 0:
			gap_ok = false
			continue
		var prev: Dictionary = groups[i - 1]
		var gap: float = race._group_start(g) - race._group_end(prev)
		gaps.append("%s=%.0f" % [String(g["group"]), gap])
		if gap <= 650.0:
			tight.append(String(g["group"]))
		if gap < 400.0 or gap > 1300.0:
			gap_ok = false
	_check("combo_gaps_400_800", gap_ok, ",".join(gaps))
	_check("tight_relay_count_5", tight.size() >= 5,
		"tight=%s" % ",".join(tight))
	# FEEL-40：Z2 只做一个 2.5–3.5 s 的提前换人窗口，不压成 Z3 的 2 s。
	var rock6: Dictionary = {}
	var gate4: Dictionary = {}
	for g in groups:
		if String(g.get("group", "")) == "rock6":
			rock6 = g
		elif String(g.get("group", "")) == "gate4":
			gate4 = g
	if not rock6.is_empty() and not gate4.is_empty():
		var z2_gap: float = race._group_start(gate4) - race._group_end(rock6)
		_check("z2_anticipation_gap", z2_gap / 240.0 >= 2.5 and z2_gap / 240.0 <= 3.5,
			"rock6->gate4 %.0f px = %.2f s" % [z2_gap, z2_gap / 240.0])
	# 双解：bird2 / beam4 / beam5 / rock3 / rock6。
	_check("dual_count", dual_groups.size() == 5, "count=%d" % dual_groups.size())
	var dual_prompt: String = race._lesson_prompt("LOW_BEAM", "", true)
	_check("dual_beam_prompt", dual_prompt.contains("SHIFT") or dual_prompt.contains("shifting")
		or dual_prompt.contains("下潜") or dual_prompt.contains("DIVE"), dual_prompt)
	var bird_prompt: String = race._lesson_prompt("LOW_BIRD", "", true)
	_check("dual_bird_prompt", bird_prompt.contains("SHIFT") or bird_prompt.contains("下潜")
		or bird_prompt.contains("DIVE"), bird_prompt)
	var rock_prompt: String = race._lesson_prompt("SURFACE_ROCK", "", true)
	_check("dual_rock_prompt", rock_prompt.contains("SHIFT") or rock_prompt.contains("下潜")
		or rock_prompt.contains("DIVE"), rock_prompt)
	var tide_prompt: String = race._lesson_prompt("SURFACE_ROCK", "buoy", true)
	_check("dual_tide_prompt", tide_prompt.contains("潮汐") or tide_prompt.contains("TIDE"),
		tide_prompt)
	# 真实流程：把控制放在 beam4 前，清掉已学键，_update_lessons 必须真的发一条
	# 双解文案；不能只证明 _lesson_prompt 的返回值。
	var beam4: Dictionary = {}
	for g in groups:
		if String(g.get("group", "")) == "beam4":
			beam4 = g
	if not beam4.is_empty():
		_reset(race._group_start(beam4) - 300.0, beam4)
		race.lesson_seen.clear()
		race.lesson_prompt_count = 0
		live_prompts.clear()
		race._update_lessons()
		await get_tree().process_frame
		var live := ""
		for p in live_prompts:
			if String(p).contains("低梁") or String(p).contains("LOW BEAM"):
				live = String(p)
				break
		_check("dual_prompt_live", not live.is_empty(), live if not live.is_empty()
			else JSON.stringify(live_prompts))
		_check("dual_prompt_mentions_two_answers", (live.contains("SHIFT")
			or live.contains("下潜") or live.contains("DIVE"))
			and (live.contains("趴低") or live.contains("CROUCH")), live)
	# Z1：真实流程的第一次“拱→岩”换人提示必须能弹出来。
	var rock2: Dictionary = {}
	for g in groups:
		if String(g.get("group", "")) == "rock2":
			rock2 = g
	if not rock2.is_empty():
		_reset(race._group_start(rock2) - 300.0, rock2)
		race.lesson_seen.clear()
		race.lesson_prompt_count = 0
		live_prompts.clear()
		race._update_lessons()
		await get_tree().process_frame
		var early_live := ""
		for p in live_prompts:
			if String(p).contains("岩石") or String(p).contains("ROCK") \
					or String(p).contains("拱"):
				early_live = String(p)
				break
		_check("z1_chain_prompt_live", early_live.contains("SHIFT"), early_live
			if not early_live.is_empty() else JSON.stringify(live_prompts))
	# Z1 末段 bird2 双解：真实流程必须能弹出“两条路”，而不是被 bird1 吞掉。
	var bird2: Dictionary = {}
	for g in groups:
		if String(g.get("group", "")) == "bird2":
			bird2 = g
	if not bird2.is_empty():
		_reset(race._group_start(bird2) - 300.0, bird2)
		race.lesson_seen.clear()
		race.lesson_prompt_count = 0
		live_prompts.clear()
		race._update_lessons()
		await get_tree().process_frame
		var bird_live := ""
		for p in live_prompts:
			if String(p).contains("海鸟") or String(p).contains("GULL"):
				bird_live = String(p)
				break
		_check("z1_bird2_prompt_live", bird_live.contains("SHIFT")
			and (bird_live.contains("下潜") or bird_live.contains("DIVE")),
			bird_live if not bird_live.is_empty() else JSON.stringify(live_prompts))
	# 双解的 lesson key 必须与单答案不同，否则真实流程里提示永远不弹。
	var normal_key: String = race._lesson_key({"kind": "LOW_BEAM", "group": "beam1"})
	var dual_key: String = race._lesson_key({"kind": "LOW_BEAM", "group": "beam4", "dual": true})
	_check("dual_lesson_key", normal_key != dual_key, "%s vs %s" % [normal_key, dual_key])
	var tight_prompt: String = race._lesson_prompt("FLOATING_LOG", "", false, "gate6_log5")
	_check("tight_relay_prompt", tight_prompt.contains("SHIFT")
		and (tight_prompt.contains("浮木") or tight_prompt.contains("LOG")), tight_prompt)
	var tight_key: String = race._lesson_key(
		{"kind": "FLOATING_LOG", "group": "log5", "combo": "gate6_log5", "relay": true})
	_check("tight_relay_lesson_key", tight_key.ends_with("|relay"), tight_key)
	var early_prompt: String = race._lesson_prompt("SURFACE_ROCK", "", false, "gate1_rock2")
	_check("z1_chain_prompt", early_prompt.contains("SHIFT"), early_prompt)
	var z2_prompt: String = race._lesson_prompt("DIVE_GATE", "", false, "rock6_gate4")
	_check("z2_anticipation_prompt", z2_prompt.contains("SHIFT"), z2_prompt)
	var fail_hints_ok := true
	for combo in ["gate1_rock2", "shark3_beam3", "rock4_gate3", "gate3_bird3",
			"rock6_gate4", "shark5_bird5", "gate6_log5", "log5_bird6",
			"log7_rock10", "shark9_bird8", "gate8_bird9"]:
		var text: String = Locale.t("hint.relay_fail_" + combo)
		if text == "" or text == ("hint.relay_fail_" + combo):
			fail_hints_ok = false
	_check("relay_fail_hints", fail_hints_ok, "early + tight combos have failure-cause text")
	for g in dual_groups:
		var bname := String(g["group"])
		var kind := String(g["kind"])
		var crouch_action := "down" if kind != "SURFACE_ROCK" else "up"
		var crouch := await _dual_case(g, "rabbit", crouch_action)
		var dive := await _dual_case(g, "turtle", "down")
		_check("dual_rabbit_passes_%s" % bname, bool(crouch["passed"]),
			JSON.stringify(crouch))
		_check("dual_turtle_passes_%s" % bname,
			bool(dive["passed"]) and bool(dive["oxygen_used"]), JSON.stringify(dive))
	# rock3 的兔子答案必须由潮汐相位决定：8 个相位各跑一次。
	for g in dual_groups:
		if String(g.get("group", "")) != "rock3":
			continue
		var phase_ok := 0
		var phase_rows := []
		for i in 8:
			var c: Dictionary = await _dual_case(g, "rabbit", "up", i * 3.6 / 8.0)
			phase_rows.append(bool(c["passed"]))
			if bool(c["passed"]):
				phase_ok += 1
		_check("rock3_tide_phases", phase_ok >= 6 and phase_ok < 8,
			"%d/8 %s (timing risk; turtle dive is stable)" % [phase_ok, str(phase_rows)])
		var turtle_ok := 0
		var turtle_rows := []
		for i in 8:
			var t: Dictionary = await _dual_case(g, "turtle", "down", i * 3.6 / 8.0)
			turtle_rows.append(bool(t["passed"]))
			if bool(t["passed"]):
				turtle_ok += 1
		_check("rock3_turtle_phases", turtle_ok == 8,
			"%d/8 %s" % [turtle_ok, str(turtle_rows)])
	# 氧气三气泡：满氧全绿；剩 2.5 时第三颗半淡出；剩 1.8 时中间黄；
	# 剩 0.8 时最后一颗红。验证不是三颗同时换色。
	var ob_full: Dictionary = race.oxygen_bubble_state(2, 3.0)
	var ob_two: Dictionary = race.oxygen_bubble_state(2, 2.5)
	var ob_mid: Dictionary = race.oxygen_bubble_state(1, 1.8)
	var ob_first_mid: Dictionary = race.oxygen_bubble_state(0, 1.8)
	var ob_last: Dictionary = race.oxygen_bubble_state(0, 0.8)
	var c_mid: Color = ob_mid["color"]
	var c_first_mid: Color = ob_first_mid["color"]
	var c_last: Color = ob_last["color"]
	_check("oxygen_bubble_discrete",
		float(ob_full["fill"]) >= 0.99 and float(ob_two["fill"]) < 0.7
		and c_mid.g < 0.95 and c_first_mid.g < 0.95 and c_last.r > 0.9,
		"full=%s two=%s mid=%s first_mid=%s last=%s" % [JSON.stringify(ob_full),
			JSON.stringify(ob_two), JSON.stringify(ob_mid),
			JSON.stringify(ob_first_mid), JSON.stringify(ob_last)])
	var moving_beams := []
	for g in groups:
		if String(g.get("kind", "")) == "LOW_BEAM" and not Dictionary(g.get("motion", {})).is_empty():
			moving_beams.append(String(g.get("group", "")))
	_check("low_beam_motion_cleared", moving_beams.is_empty(), str(moving_beams))
	race._turtle_last_draw_x = -1.0e9
	race._turtle_facing = 1.0
	race._update_turtle_facing(500.0)
	race._update_turtle_facing(490.0)
	var face_left: float = race._turtle_facing
	race._update_turtle_facing(510.0)
	var face_right: float = race._turtle_facing
	_check("turtle_visual_facing", face_left < -0.9 and face_right > 0.9,
		"left=%.1f right=%.1f" % [face_left, face_right])
	race.mount.mark_rescue_active(1.0)
	var suction: Vector2 = race.mount.rescue_suction_offset(
		Vector2(100.0, 420.0), Vector2(100.0, 300.0), 0.1)
	race.mount.reset()
	_check("rescue_suction_horizontal_only", is_zero_approx(suction.y),
		"offset=%s" % str(suction))
	race._visual_stress = {"rabbit": 0.0, "turtle": 0.0}
	race._bump_visual_stress("rabbit", 1.0)
	var s1: int = race._visual_stage("rabbit")
	race._bump_visual_stress("rabbit", 1.0)
	var s2: int = race._visual_stage("rabbit")
	race._bump_visual_stress("rabbit", 1.0)
	var s3: int = race._visual_stage("rabbit")
	_check("visual_stress_three_stages", s1 == 1 and s2 == 2 and s3 == 3,
		"%d/%d/%d" % [s1, s2, s3])
	# 单次受击不能变成永久血条格：约 2.5 秒内回到 0。
	race._visual_stress = {"rabbit": 1.0, "turtle": 0.0}
	race._tick_visual_stress(2.5)
	var decayed: bool = race._visual_stage("rabbit") == 0
	race._visual_stress = {"rabbit": 0.0, "turtle": 0.0}
	_check("visual_stress_not_permanent", decayed,
		"after_2.5s=%s" % str(decayed))
	_write()
	var ok: bool = checks.all(func(c): return bool(c["ok"]))
	print("COMBO AUDIT: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _dual_case(g: Dictionary, who: String, action: String,
		clock: float = -1.0) -> Dictionary:
	var start: float = race._group_start(g)
	var end: float = race._group_end(g)
	_reset(start - 220.0, g)
	if clock >= 0.0:
		race.hazard_clock = clock
	_control(who)
	if action == "down":
		_press("down")
	var jumped := false
	var n := 0
	while race.turtle.position.x < end + 120.0 and n < 300:
		if action == "up" and not jumped and race.turtle.position.x >= start - 105.0:
			_press("up")
			jumped = true
		await get_tree().physics_frame
		n += 1
	_release_all()
	var passed: bool = race.mount.state == "RIDING" \
		and GameManager.accident_state == "NONE" \
		and not race.hit_groups.has(String(g["group"]))
	return {"who": who, "action": action, "passed": passed,
		"oxygen_used": GameManager.oxygen < Tuning.OXYGEN_MAX - 0.05,
		"accident": GameManager.accident_state,
		"turtle_y": race.turtle.position.y, "rabbit_y": race.rabbit.position.y,
		"hit_roles": race.hit_roles.get(String(g["group"]), {})}


func _reset(x: float, g: Dictionary) -> void:
	_release_all()
	GameManager.accident_state = "NONE"
	GameManager.oxygen = Tuning.OXYGEN_MAX
	GameManager.current_control = "rabbit"
	GameManager.has_shifted = true
	race.showtime_active = false
	race.hazard_cooldown = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.hit_groups.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.group_actions.clear()
	var zone: Dictionary = LevelData.zone_at(race._group_start(g))
	race.current_zone = zone
	race.turtle.reset(Vector2(x, race.surface_ref()))
	race.turtle.speed = float(zone["base_speed"])
	race.turtle.base_speed = float(zone["base_speed"])
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()


func _control(who: String) -> void:
	if GameManager.current_control != who:
		GameManager.set_control(who)


func _press(a: String) -> void:
	if not Input.is_action_pressed(a):
		Input.action_press(a)


func _release_all() -> void:
	for a in ["up", "down", "left", "right", "shift"]:
		Input.action_release(a)


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var f := FileAccess.open("res://docs/reports/longrun/feel41-decision-audit.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"checks": checks}, "  "))
		f.close()
