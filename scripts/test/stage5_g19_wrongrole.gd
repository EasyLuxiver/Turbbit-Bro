extends Node
## REBUILD-05 G19：撞 A 类障碍时，第一次告诉你“这个要换兔子”。
##
## 问题（玩家视角）：低梁 / 海鸟 / 岩檐只在兔子那一层判定。玩家在操控乌龟时
## 撞上，画面上就是“我什么都没按就撞了”——乌龟的 ↓ 是下潜，不是趴低，
## 玩家没有可用的躲法，也不知道该换人。G3 已经为“壳停太深”做过一次具体提示，
## 这里补 A 类的对应一句，当局只给一次。
##
## 三个 case 同一条赛道、同一个物理：
##   rabbit_hit_first  兔子操控撞梁   → 不该出现这句（玩家当时就在兔子身上）
##   turtle_hit        乌龟操控撞梁   → 出现一次，文本与 locale 一致
##   turtle_hit_again  再撞另一组     → 不重复出现（当局一次）
##
## 运行：godot --headless --path TURBBIT res://scenes/stage5_g19_wrongrole.tscn
## 输出：docs/reports/longrun/rebuild05-g19-wrongrole.json

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/rebuild05-g19-wrongrole.json"
const STEP := 1.0 / 60.0
const HINT_KEY := "hint.take_rabbit"

var is_runner := false
var race: Node = null
var hints: Array = []
var failures: Array = []
var checks_run := 0
var out := {}


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage5G19Runner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	# G19_LANG=en 只影响探针自己的语言（取证截图用），不写 settings.json。
	var lang := OS.get_environment("G19_LANG")
	Locale.language = lang if lang != "" else "zh"
	GameManager.start_race()
	for i in 4:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null:
		push_error("G19: no race scene")
		_finish(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_disable_hazards = false
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()
	GameManager.hint.connect(_on_hint)

	out["generated_at"] = Time.get_datetime_string_from_system()
	var prev := Locale.language
	Locale.language = "zh"
	out["hint_text_zh"] = Locale.t(HINT_KEY)
	Locale.language = "en"
	out["hint_text_en"] = Locale.t(HINT_KEY)
	Locale.language = prev
	out["language"] = prev

	# 三个 case 用同一组障碍（第一次出现的 LOW_BEAM/LOW_BIRD）：
	# 乌龟跃起能把整组抬进低梁/海鸟，兔子自己起跳也能撞上——同一条件只有操控权不同。
	# 用两个不同组会把“这组在乌龟方案下撞不到”混进来（rock1 跃起就过去了）。
	var groups := _a_class_groups(1)
	if groups.is_empty():
		push_error("G19: no A-class group")
		_finish(1)
		return
	var gname := String(groups[0])
	out["cases"] = {}
	out["cases"]["rabbit_hit_first"] = _case(gname, "rabbit")
	out["cases"]["turtle_hit"] = _case(gname, "turtle")
	# 取证截图：只在窗口化运行时用（headless 读不到渲染结果）。
	# G19_SHOT=文件名，存到 screenshots/；拍的是 turtle_hit 这一帧的正式 HUD。
	var shot := OS.get_environment("G19_SHOT")
	if shot != "" and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://screenshots/" + shot))
		out["shot"] = shot
	out["cases"]["turtle_hit_again"] = _case(gname, "turtle")
	_evaluate()
	_write()
	var ok := failures.is_empty()
	print("G19 WRONGROLE: %s checks=%d failures=%d" % [
		"PASS" if ok else "FAIL", _check_count(), failures.size()])
	for f in failures:
		print("  - ", f)
	_finish(0 if ok else 1)


## 一个 case：把乌龟放到障碍前，按 ↑（乌龟跃起 / 兔子起跳），等真事故。
## 操控乌龟时 ↑ 是乌龟跃起，整组抬高，壳上的兔子撞进 A 类障碍；
## 操控兔子时 ↑ 是兔子自己起跳。两条都是真实输入，不脚本触发事故。
func _case(group_name: String, control: String) -> Dictionary:
	var g := _group(group_name)
	if g.is_empty():
		return {"error": "no group " + group_name}
	var start: float = race._group_start(g)
	var lead := 120.0 if control == "turtle" else 45.0
	_reset(start - lead, LevelData.zone_at(start), control)
	hints.clear()

	Input.action_press("up")
	race._note_up_input()
	race._physics_process(STEP)
	Input.action_release("up")

	var accident := ""
	var got := false
	var hud_text := ""
	var hud_visible := false
	var guard := 0
	while guard < 240:
		race._physics_process(STEP)
		guard += 1
		if got:
			break
		if GameManager.accident_count > 0:
			accident = GameManager.accident_state
			got = true
	# 事故后先把 HUD 刷一次，读底部提示行真实显示的东西。
	if race.hud != null:
		race.hud._refresh()
		race.hud._layout()
		hud_text = String(race.hud.hint_label.text)
		hud_visible = race.hud.hint_label.visible
	return {
		"group": group_name,
		"control": control,
		"accident_state": accident,
		"accidents": GameManager.accident_count,
		"hints": hints.duplicate(),
		"got_hint": _has_hint(),
		"hud_text": hud_text,
		"hud_visible": hud_visible,
	}


func _evaluate() -> void:
	var a: Dictionary = out["cases"]["rabbit_hit_first"]
	var b: Dictionary = out["cases"]["turtle_hit"]
	var c: Dictionary = out["cases"]["turtle_hit_again"]
	# 提示是在游戏运行的语言下发出的：英文取证跑就比英文，中文跑就比中文。
	var zh := String(out["hint_text_zh"])
	var want := String(out["hint_text_en"]) if String(out["language"]) == "en" else zh
	# 1. 两种操控都真的撞上了：case 本身要成立，否则“没提示”没有意义。
	_expect("rabbit_hit_first crashed (%s)" % String(a["accident_state"]),
		int(a["accidents"]) == 1)
	_expect("turtle_hit crashed (%s)" % String(b["accident_state"]),
		int(b["accidents"]) == 1)
	_expect("turtle_hit_again crashed (%s)" % String(c["accident_state"]),
		int(c["accidents"]) == 1)
	# 2. 操控兔子时不出现这句。
	_expect("rabbit control: no take_rabbit hint (%s)" % str(a["hints"]),
		not bool(a["got_hint"]))
	# 3. 操控乌龟时出现，且文本就是 locale 那一句，HUD 上也看得见。
	_expect("turtle control: hint shown (%s)" % str(b["hints"]),
		bool(b["got_hint"]))
	_expect("turtle control: hint text is %s" % want,
		_has_exact(b["hints"], want))
	_expect("turtle control: HUD hint label shows it (%s)" % String(b["hud_text"]),
		String(b["hud_text"]) == want and bool(b["hud_visible"]))
	# 4. 当局只一次。
	_expect("second crash: no repeat (%s)" % str(c["hints"]),
		not bool(c["got_hint"]))
	# 5. 改过的教学文案在底部提示行放得下（18 px，单行，不换行）。
	var wide := _widest_lesson()
	out["widest_lesson"] = wide
	_expect("lesson texts fit the hint row (%s)" % JSON.stringify(wide), _lesson_fits())


## 逐条量更新过的教学文案：中英各一次，用 HUD 提示行同一个字体/字号。
func _widest_lesson() -> Dictionary:
	var keys := ["lesson.rock", "lesson.beam", "lesson.bird", "lesson.dock_beam",
		"lesson.gate", "lesson.shark", "lesson.wall", "lesson.log"]
	var font: Font = race.hud.hint_label.get_theme_font("font")
	var fsize: int = race.hud.hint_label.get_theme_font_size("font_size")
	var vp := get_viewport().get_visible_rect().size
	var worst := {"key": "", "lang": "", "px": 0.0, "limit": vp.x - 32.0}
	var prev := Locale.language
	for lang in ["zh", "en"]:
		Locale.language = lang
		for k in keys:
			var w := font.get_string_size(Locale.t(k), HORIZONTAL_ALIGNMENT_LEFT,
				-1, fsize).x
			if w > float(worst["px"]):
				worst = {"key": k, "lang": lang, "px": snappedf(w, 0.1),
					"limit": vp.x - 32.0}
	Locale.language = prev
	return worst


func _lesson_fits() -> bool:
	var w: Dictionary = out.get("widest_lesson", {})
	return float(w.get("px", 0.0)) <= float(w.get("limit", 0.0))


func _check_count() -> int:
	return checks_run


func _has_hint() -> bool:
	for h in hints:
		if String(h) == Locale.t(HINT_KEY):
			return true
	return false


func _has_exact(list: Array, text: String) -> bool:
	for h in list:
		if String(h) == text:
			return true
	return false


func _on_hint(text: String) -> void:
	hints.append(text)


func _a_class_groups(want: int) -> Array:
	var names: Array = []
	for g in race.hazard_groups:
		if String(g["kind"]) in ["LOW_BEAM", "LOW_BIRD", "SURFACE_ROCK"]:
			names.append(String(g["group"]))
			if names.size() >= want:
				break
	return names


func _group(name: String) -> Dictionary:
	for g in race.hazard_groups:
		if String(g["group"]) == name:
			return g
	return {}


func _reset(x: float, zone: Dictionary, control: String) -> void:
	Input.action_release("up")
	Input.action_release("down")
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.oxygen = Tuning.OXYGEN_MAX
	GameManager.oxygen_phase = "SAFE"
	GameManager.accident_count = 0
	GameManager.showtime_active = false
	GameManager.clear_bro_meter()
	GameManager.current_control = control
	GameManager.has_shifted = true
	GameManager.pickup_window = false
	race.showtime_active = false
	race.showtime_t = 0.0
	race.finishing = false
	race.hazard_cooldown = 0.0
	race._accident_t = 0.0
	race.accident_flash = 0.0
	race.turtle_repair = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.rabbit_stun = 0.0
	race.emergency_timer = 0.0
	race.combo = 0
	race.reset_brains()
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.group_actions.clear()
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


func _expect(what: String, ok: bool) -> void:
	checks_run += 1
	if not ok:
		failures.append(what)


func _write() -> void:
	out["failures"] = failures
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out, "  "))
		f.close()


func _finish(code: int) -> void:
	get_tree().quit(code)
