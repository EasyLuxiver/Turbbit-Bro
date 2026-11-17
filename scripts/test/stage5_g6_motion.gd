extends Node
## TBB-EXPERIENCE-REBUILD-05 G6：会动的障碍首次进入范围时提醒一句的验收探针。
##
## 验：
##   1) 每区第一组带 motion 的障碍进入 560 px 时，底栏出现一次 hint.motion；
##   2) 同区后面再遇到会动的组不再重复；
##   3) 静态组不触发；事故期间不触发（事故结束后才补）；
##   4) 提示进的是正式 HUD 的底部提示行，中英文都放得下。
##
## 输出：docs/reports/longrun/rebuild05-g6-motion.json
## 运行：godot --headless --path TURBBIT res://scenes/stage5_g6_motion.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/rebuild05-g6-motion.json"
const STEP := 1.0 / 60.0
const HINT_KEY := "hint.motion"
const APPROACH := 780.0

var is_runner := false
var race: Node = null
var hints: Array = []
var out := {}
var failures: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage5G6MotionRunner"
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
		push_error("G6 MOTION: no race")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()
	GameManager.hint.connect(_on_hint)

	out["generated_at"] = Time.get_datetime_string_from_system()
	out["zone1"] = _zone_case(1, false)
	out["zone2"] = _zone_case(2, false)
	out["zone2_second"] = _second_motion_no_repeat(2)
	out["static"] = _static_control()
	out["during_accident"] = _accident_control()
	out["hud"] = _hud_reading()
	_evaluate()
	_write()
	print("G6 MOTION: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


## 从组前 780 px 起步，走到组右侧 200 px，记录这一程里出现的所有提示。
func _zone_case(zone_id: int, with_accident: bool) -> Dictionary:
	var g := _first_motion(zone_id, 0)
	if g.is_empty():
		return {"error": "no motion group in zone %d" % zone_id}
	var gs: float = LevelData.group_start(g)
	_reset(gs - APPROACH, LevelData.zone_at(gs))
	if with_accident:
		GameManager.accident_state = "RABBIT_WATER"
	var guard := 0
	while guard < 400 and race.turtle.position.x < gs + 200.0:
		race._physics_process(STEP)
		guard += 1
	if with_accident:
		GameManager.accident_state = "NONE"
	var mine := _motion_hints()
	return {
		"group": String(g["group"]),
		"motion": String(g.get("motion", {}).get("name", "")),
		"count": mine.size(),
		"first": mine[0] if mine.size() > 0 else {},
		"frames": guard,
	}


## 同区继续走到第二组会动的障碍：不应再出现（一程连续跑，不重开）。
func _second_motion_no_repeat(zone_id: int) -> Dictionary:
	var first := _first_motion(zone_id, 0)
	var second := _first_motion(zone_id, 1)
	if first.is_empty() or second.is_empty():
		return {"error": "zone %d needs two motion groups" % zone_id}
	var gs: float = LevelData.group_start(first)
	var stop: float = LevelData.group_start(second) + 200.0
	_reset(gs - APPROACH, LevelData.zone_at(gs))
	var guard := 0
	while guard < 900 and race.turtle.position.x < stop:
		race._physics_process(STEP)
		guard += 1
	return {
		"first": String(first["group"]),
		"second": String(second["group"]),
		"count": _motion_hints().size(),
		"only_from_first": _motion_hints().size() == 1 \
			and String(_motion_hints()[0].get("group", "")) == String(first["group"]),
		"frames": guard,
	}


## 静态障碍（同区、无 motion）：不该出现「会动」提示。
func _static_control() -> Dictionary:
	var g := {}
	for cand in race.hazard_groups:
		if int(cand.get("zone", 0)) != 1:
			continue
		if not Dictionary(cand.get("motion", {})).is_empty():
			continue
		g = cand
		break
	if g.is_empty():
		return {"error": "no static group"}
	var gs: float = LevelData.group_start(g)
	_reset(gs - APPROACH, LevelData.zone_at(gs))
	var guard := 0
	while guard < 400 and race.turtle.position.x < gs + 200.0:
		race._physics_process(STEP)
		guard += 1
	return {"group": String(g["group"]), "count": _motion_hints().size()}


## 事故期间：同一组会动的障碍经过时要压住；事故结束后才补一句。
func _accident_control() -> Dictionary:
	var g := _first_motion(3, 0)
	if g.is_empty():
		return {"error": "no motion group in zone 3"}
	var gs: float = LevelData.group_start(g)
	_reset(gs - APPROACH, LevelData.zone_at(gs))
	GameManager.accident_state = "RABBIT_WATER"
	var guard := 0
	while guard < 400 and race.turtle.position.x < gs - 20.0:
		race._physics_process(STEP)
		guard += 1
	var during := _motion_hints().size()
	GameManager.accident_state = "NONE"
	guard = 0
	while guard < 200 and race.turtle.position.x < gs + 200.0:
		race._physics_process(STEP)
		guard += 1
	return {
		"group": String(g["group"]),
		"during_accident": during,
		"after_accident": _motion_hints().size(),
	}


## 正式 HUD：最近一次提示必须出现在底部提示行，中英文都放得下。
func _hud_reading() -> Dictionary:
	var hud_text := ""
	var hud_visible := false
	var hud_fits := false
	var hud_text_en := ""
	var hud_fits_en := false
	if race.hud != null:
		race.hud._refresh()
		race.hud._layout()
		hud_text = String(race.hud.hint_label.text)
		hud_visible = race.hud.hint_label.visible
		hud_fits = _hint_fits_viewport()
		var font: Font = race.hud.hint_label.get_theme_font("font")
		var fsize: int = race.hud.hint_label.get_theme_font_size("font_size")
		var prev_lang: String = Locale.language
		Locale.language = "en"
		hud_text_en = String(Locale.t(HINT_KEY))
		Locale.language = prev_lang
		var vp := get_viewport().get_visible_rect().size
		hud_fits_en = font.get_string_size(hud_text_en, HORIZONTAL_ALIGNMENT_LEFT,
			-1, fsize).x <= vp.x - 32.0
	return {
		"text": hud_text,
		"visible": hud_visible,
		"fits": hud_fits,
		"text_en": hud_text_en,
		"fits_en": hud_fits_en,
	}


func _evaluate() -> void:
	var z1: Dictionary = out["zone1"]
	var z2: Dictionary = out["zone2"]
	_expect("zone 1: motion hint fires once (%s)" % str(z1.get("count", -1)),
		int(z1.get("count", 0)) == 1)
	_expect("zone 1: hint names the moving group (%s)"
		% str(z1.get("first", {}).get("group", "")),
		String(z1.get("first", {}).get("group", "")) == String(z1.get("group", "")))
	_expect("zone 1: hint fires inside the 560 px window (d=%s)"
		% str(z1.get("first", {}).get("distance", -1.0)),
		float(z1.get("first", {}).get("distance", 9999.0)) <= 560.0
			and float(z1.get("first", {}).get("distance", -1.0)) >= 0.0)
	_expect("zone 2: own first motion hint fires (%s)" % str(z2.get("count", -1)),
		int(z2.get("count", 0)) == 1)
	var repeat: Dictionary = out["zone2_second"]
	_expect("same zone: second moving group does not repeat (%s -> %s, count=%s)"
		% [str(repeat.get("first", "")), str(repeat.get("second", "")),
			str(repeat.get("count", -1))],
		not repeat.has("error") and bool(repeat.get("only_from_first", false)))
	_expect("static group: no motion hint (%s)"
		% str(out["static"].get("count", -1)),
		int(out["static"].get("count", 0)) == 0)
	var acc: Dictionary = out["during_accident"]
	_expect("during accident: hint held back (%s)" % str(acc.get("during_accident", -1)),
		int(acc.get("during_accident", -1)) == 0)
	_expect("after accident: hint catches up (%s)" % str(acc.get("after_accident", -1)),
		int(acc.get("after_accident", 0)) == 1)
	var hud: Dictionary = out["hud"]
	_expect("hint lands in the real HUD (%s, visible=%s)"
		% [hud.get("text", ""), str(hud.get("visible", false))],
		bool(hud.get("visible", false)) and String(hud.get("text", "")) != "")
	_expect("chinese hint fits the viewport (%s)" % str(hud.get("fits", false)),
		bool(hud.get("fits", false)))
	_expect("english hint present and fits (%s, %s)"
		% [hud.get("text_en", ""), str(hud.get("fits_en", false))],
		String(hud.get("text_en", "")) != "" and bool(hud.get("fits_en", false)))


func _expect(label: String, ok: bool) -> void:
	if not ok:
		failures.append(label)


func _first_motion(zone_id: int, skip: int) -> Dictionary:
	var found: Array = []
	for g in race.hazard_groups:
		if int(g.get("zone", 0)) != zone_id:
			continue
		if Dictionary(g.get("motion", {})).is_empty():
			continue
		found.append(g)
	found.sort_custom(func(a, b): return LevelData.group_start(a) < LevelData.group_start(b))
	if skip >= found.size():
		return {}
	return found[skip]


func _motion_hints() -> Array:
	var result: Array = []
	# FEEL-09：会动的障碍按身份各有一句（浮标/吊箱/漂流货/鳗鱼/通用）。
	var keys := ["hint.motion", "hint.motion_buoy", "hint.motion_hoist",
		"hint.motion_cargo", "hint.motion_eel"]
	var allowed := []
	for k in keys:
		allowed.append(Locale.t(k))
	for h in hints:
		if String(h["text"]) in allowed:
			result.append(h)
	return result


func _on_hint(text: String) -> void:
	var x: float = race.turtle.position.x
	var near := _nearest_motion_group(x)
	hints.append({
		"text": text,
		"x": snappedf(x, 0.1),
		"group": String(near.get("group", "")),
		"distance": snappedf(float(near.get("distance", -1.0)), 0.1),
	})


## 这一句是哪一组会动的障碍引起的：取前方最近的一组（判定只看“进入 560 px”）。
func _nearest_motion_group(x: float) -> Dictionary:
	var best := ""
	var best_d := 1.0e9
	for g in race.hazard_groups:
		if Dictionary(g.get("motion", {})).is_empty():
			continue
		var d: float = LevelData.group_start(g) - x
		if d >= -40.0 and d < best_d:
			best_d = d
			best = String(g["group"])
	return {"group": best, "distance": best_d if best != "" else -1.0}


func _hint_fits_viewport() -> bool:
	var vp := get_viewport().get_visible_rect().size
	return race.hud.hint_label.get_combined_minimum_size().x <= vp.x - 32.0


func _reset(x: float, zone: Dictionary = {}) -> void:
	if zone.is_empty():
		zone = LevelData.zone_at(x)
	hints.clear()
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
	race.motion_lesson_zone = -1
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
		push_error("G6 MOTION: cannot write " + OUT_PATH)
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()
