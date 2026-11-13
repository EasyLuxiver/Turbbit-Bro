extends Node
## TBB-EXPERIENCE-REBUILD-05 G3：擦水事故的具体原因提示验收探针。
##
## 事故本身不变（RABBIT_WATER，−100，记 1 格），只把“为什么”说出来：
## 壳一直停在水下、兔子落壳擦水时，走 hint 通道给一句
## 「壳停得太深 - 越过木尾就该松开 ↓ 上浮接人」。
## 对照：壳不在主动下潜时（例如被别的动作打下水）不出现这句。
##
## 输出：docs/reports/longrun/rebuild05-g3-hint.json
## 运行：godot --headless --path TURBBIT res://scenes/stage5_g3_hint.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/rebuild05-g3-hint.json"
const GROUP := "log1"
const LEAD := 160.0
const DELAY := 0.1
const HINT_KEY := "壳停得太深"
const CONTROL_GAP_X := 9000.0

var is_runner := false
var race: Node = null
var out := {}
var failures: Array = []
var hints: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage5G3HintRunner"
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
		push_error("G3 HINT: no race")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()
	GameManager.hint.connect(_on_hint)

	out["generated_at"] = Time.get_datetime_string_from_system()
	out["cases"] = {
		"diving_graze": _case_diving(),
		"deep_but_not_diving": _case_not_diving(),
		"knocked_into_water": _case_knocked(),
	}
	_evaluate()
	_write()
	print("G3 HINT: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


## A：真实标准时机的 BRO DIVE，一直按住 ↓ 不放（B3 的擦水场景）。
func _case_diving() -> Dictionary:
	var g := _group(GROUP)
	if g.is_empty():
		return {"error": "no group"}
	race.test_disable_hazards = false
	var start: float = race._group_start(g)
	var end: float = race._group_end(g)
	var step := 1.0 / 60.0
	_reset(start - LEAD, LevelData.zone_at(start))
	hints.clear()

	Input.action_press("up")
	race._note_up_input()
	race._physics_process(step)
	Input.action_release("up")
	var waited := step
	while waited < DELAY:
		race._physics_process(step)
		waited += step
	# CORE-FEEL-07 P0-A：起跳后 SHIFT 会触发辅助下潜，自动上浮并接住兔子，
	# 本用例想要的“壳停在水下、兔子擦水”按新规则已不再由这条操作产生。
	# 这里验的是手动下潜那条路（换人晚于辅助窗口）的提示文案，所以先撤掉辅助；
	# 辅助本身由 stage7_bro_dive_assist 验收。
	race._clear_dive_assist()
	GameManager.toggle_control()
	Input.action_press("down")
	var diving_at_graze := false
	var graze_x := -1.0
	var guard := 0
	while guard < 360 and race.turtle.position.x <= end + 300.0:
		race._physics_process(step)
		guard += 1
		if GameManager.accident_count > 0:
			diving_at_graze = race.turtle.diving
			graze_x = race.turtle.position.x
			break
	Input.action_release("down")
	# 接上正式 HUD：hint 信号必须真的出现在底部提示行上，英文也要放得下。
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
		# 一次性提示是一段已经本地化好的字符串（切换语言不会回译），
		# 所以英文宽度直接用同一套字体量模板文案。
		var font: Font = race.hud.hint_label.get_theme_font("font")
		var fsize: int = race.hud.hint_label.get_theme_font_size("font_size")
		var prev_lang: String = Locale.language
		Locale.language = "en"
		hud_text_en = String(Locale.t("hint.dive_deep"))
		Locale.language = prev_lang
		var vp := get_viewport().get_visible_rect().size
		hud_fits_en = font.get_string_size(hud_text_en, HORIZONTAL_ALIGNMENT_LEFT,
			-1, fsize).x <= vp.x - 32.0
	return {
		"accidents": GameManager.accident_count,
		"accident_state": GameManager.accident_state,
		"diving_at_graze": diving_at_graze,
		"graze_x_past_end": snappedf(graze_x - end, 0.1) if graze_x >= 0.0 else -1.0,
		"hints": hints.duplicate(),
		"got_specific_hint": _has_hint(),
		"hud_text": hud_text,
		"hud_visible": hud_visible,
		"hud_fits": hud_fits,
		"hud_text_en": hud_text_en,
		"hud_fits_en": hud_fits_en,
	}


## B：同一条 RABBIT_WATER 判定，但壳没有在主动下潜。
## 做法：兔子被撞离壳、落在壳侧 220 px（超过 PICKUP_DX=120）掉进水里；
## 壳在巡航水深、diving=false。事故照记，但不该出现“壳停得太深”这句。
func _case_not_diving() -> Dictionary:
	# 这一组只测提示条件，先把障碍判定关掉，避免同位置的礁/梁先记一笔。
	race.test_disable_hazards = true
	_reset(CONTROL_GAP_X, LevelData.zone_at(CONTROL_GAP_X))
	hints.clear()
	race.turtle.position.y = Tuning.NEUTRAL_DEPTH
	race.turtle._vy = 0.0
	race.turtle.diving = false
	race.mount.mark_airborne()
	race.rabbit.position = Vector2(race.turtle.position.x + 220.0,
		race.SURFACE_Y - 10.0)
	race.rabbit.velocity = Vector2(0.0, 420.0)
	var diving_frames := 0
	var at_surface := false
	var rising := false
	var mount_state := ""
	var trace: Array = []
	for i in 60:
		race._physics_process(1.0 / 60.0)
		if race.turtle.diving:
			diving_frames += 1
		if i % 5 == 0:
			trace.append({
				"i": i,
				"mount": race.mount.state,
				"rabbit_y": snappedf(race.rabbit.position.y, 0.1),
				"vy": snappedf(race.rabbit.velocity.y, 0.1),
				"pickup_window": GameManager.pickup_window,
				"accidents": GameManager.accident_count,
			})
		if GameManager.accident_count > 0:
			mount_state = race.mount.state
			at_surface = race.turtle.is_at_surface()
			rising = race.turtle.is_rising()
			break
	race.test_disable_hazards = false
	return {
		"accidents": GameManager.accident_count,
		"accident_state": GameManager.accident_state,
		"diving_frames": diving_frames,
		"mount_state_at_trigger": mount_state,
		"turtle_at_surface": at_surface,
		"turtle_rising": rising,
		"trace": trace,
		"hints": hints.duplicate(),
		"got_specific_hint": _has_hint(),
	}


## C：被别的动作直接打下水（海鸟/障碍的 _rabbit_contact 快路径）。
## 这条路径根本不经过落壳判定，所以即使 diving=true 也不该出这句提示。
func _case_knocked() -> Dictionary:
	race.test_disable_hazards = true
	_reset(CONTROL_GAP_X, LevelData.zone_at(CONTROL_GAP_X))
	hints.clear()
	race.mount.mark_airborne()
	race.rabbit.velocity = Vector2(0.0, 120.0)
	# 同步调用，不给 tick 机会把 diving 清掉：证明提示与 diving 无关，
	# 只属于“落壳擦水”那一条判定。
	race.turtle.diving = true
	var diving_before: bool = race.turtle.diving
	race._rabbit_contact("")
	race.test_disable_hazards = false
	return {
		"accidents": GameManager.accident_count,
		"accident_state": GameManager.accident_state,
		"diving_true_at_call": diving_before,
		"hints": hints.duplicate(),
		"got_specific_hint": _has_hint(),
	}


func _hint_fits_viewport() -> bool:
	var vp := get_viewport().get_visible_rect().size
	return race.hud.hint_label.get_combined_minimum_size().x <= vp.x - 32.0


func _on_hint(text: String) -> void:
	hints.append(text)


func _has_hint() -> bool:
	for h in hints:
		if String(h).contains(HINT_KEY):
			return true
	return false


func _group(name: String) -> Dictionary:
	for g in race.hazard_groups:
		if String(g["group"]) == name:
			return g
	return {}


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
	var a: Dictionary = out["cases"]["diving_graze"]
	var b: Dictionary = out["cases"]["deep_but_not_diving"]
	_expect("diving graze: accident still booked once (%d)" % int(a["accidents"]),
		int(a["accidents"]) == 1)
	_expect("diving graze: accident state is RABBIT_WATER (%s)" % a["accident_state"],
		String(a["accident_state"]) == "RABBIT_WATER")
	_expect("diving graze: shell was actively diving (%s)" % str(a["diving_at_graze"]),
		bool(a["diving_at_graze"]))
	_expect("diving graze: specific hint shown (%s)" % str(a["hints"]),
		bool(a["got_specific_hint"]))
	_expect("diving graze: hint lands in the real HUD (%s, visible=%s)"
		% [a["hud_text"], str(a["hud_visible"])],
		bool(a["hud_visible"]) and String(a["hud_text"]).contains(HINT_KEY))
	_expect("diving graze: chinese hint fits the viewport (%s)" % str(a["hud_fits"]),
		bool(a["hud_fits"]))
	_expect("diving graze: english hint present and fits (%s, %s)"
		% [a["hud_text_en"], str(a["hud_fits_en"])],
		String(a["hud_text_en"]).contains("SHELL TOO DEEP") and bool(a["hud_fits_en"]))
	_expect("not diving: same accident still happens (%d)" % int(b["accidents"]),
		int(b["accidents"]) == 1)
	_expect("not diving: accident state is RABBIT_WATER (%s)" % b["accident_state"],
		String(b["accident_state"]) == "RABBIT_WATER")
	_expect("not diving: shell never dived during the run (%d frames)" % int(b["diving_frames"]),
		int(b["diving_frames"]) == 0)
	_expect("not diving: no dive-deep hint (%s)" % str(b["hints"]),
		not bool(b["got_specific_hint"]))
	var c: Dictionary = out["cases"]["knocked_into_water"]
	_expect("knocked into water: accident booked once (%d)" % int(c["accidents"]),
		int(c["accidents"]) == 1)
	_expect("knocked into water: no dive-deep hint even with diving=true (%s)"
		% str(c["hints"]), not bool(c["got_specific_hint"]))


func _expect(label: String, ok: bool) -> void:
	if not ok:
		failures.append(label)


func _write() -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f == null:
		push_error("G3 HINT: cannot write " + OUT_PATH)
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()
