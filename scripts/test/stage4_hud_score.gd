extends Node
## 追加任务 §七-9 — HUD 与评分表现审核（窗口化 1280×720，真实赛道 + 引擎内输入）
##
## 证据类型：自动化测试 + 引擎按键代理 + 窗口化截图。**不是真人试玩。**
##
## 检查：
##   1. HUD 不再显示固定数字总分；total_score / score_log 仍在后台累计。
##   2. HUD 显示当前角色、BRO METER、氧气、食物加速状态与 TURBO。
##   3. 连招走真实 _update_combo 路径后，HUD 出现 BRO COMBO。
##   4. 真实撞梁落水 + SHIFT + 下潜接住后，HUD 出现“接住了”，救援计数 +1。
##   5. 结算页七项（时间/干净/连招/救援/失误/联合事故/评级）可读，且无固定总分。
##   6. 1280×720 下中英文所有可见文字实际字号 ≥14 px，面板面积 ≤8%。
##   7. 输出 1280×720 中英文 HUD 与结算截图，供人工打开查看。
##
## 运行（必须窗口化，headless 不会真正改窗口尺寸）：
##   D:/Godot_v4.7-stable_win64_console.exe --path D:/GAMESTUDIO/TURBBIT \
##       res://scenes/stage4_hud_score.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/phase-t-hud-score.json"
const MIN_PX := 14.0
const AREA_LIMIT := 0.08
const STEP_HZ := 60.0

var is_runner := false
var race: Node = null
var failures: Array[String] = []
var checks: Array = []
var data: Dictionary = {}
var _scale := 1.0
var sim := 0.0
var _fb_events: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4HudScoreRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.feedback.connect(func(t: String, k: String) -> void:
		_fb_events.append("%s|%s" % [t, k]))
	await get_tree().process_frame
	await _run()


func _run() -> void:
	var win := get_window()
	win.size = Vector2i(1280, 720)
	await _frames(8)
	var win_size := win.size
	var vp := get_viewport().get_visible_rect().size
	_scale = minf(float(win_size.x) / 1600.0, float(win_size.y) / 900.0)
	data["window_size"] = [win_size.x, win_size.y]
	data["viewport_design"] = [vp.x, vp.y]
	data["content_scale"] = snappedf(_scale, 0.001)
	print("HUD-SCORE window=%dx%d design=%.0fx%.0f scale=%.3f" % [
		win_size.x, win_size.y, vp.x, vp.y, _scale])
	_check(win_size == Vector2i(1280, 720), "real window is 1280x720 (got %s)" % str(win_size))
	_check(absf(_scale - 0.8) < 0.01, "content scale is 0.8 (got %.3f)" % _scale)

	Locale.language = "zh"
	GameManager.start_race()
	await _wait_scene("race.tscn")
	await _frames(4)
	race = get_tree().current_scene
	_check(race != null and race.hud != null, "race scene has HUD")
	if race == null or race.hud == null:
		_finish()
		return
	race.test_disable_hazards = true
	race.test_no_finish = true

	# ---- 1) 固定总分退出 HUD，但后台计算保留 ----
	GameManager.total_score = 12345
	await _frames(3)
	var score_before := GameManager.total_score
	GameManager.add_score(100, "probe_retained")
	GameManager.add_score(50, "probe_retained_2")
	_check(GameManager.total_score == score_before + 150,
		"total_score still accumulates (%d -> %d)" % [score_before, GameManager.total_score])
	_check(not GameManager.score_log.is_empty()
		and String(GameManager.score_log[-1]["reason"]) == "probe_retained_2",
		"score_log still records entries for analysis")
	data["score_log_last"] = GameManager.score_log[-1]

	# ---- 2) 食物加速状态 + TURBO（真实 snack 状态字段） ----
	race.snack_boost_until_x = race.turtle.position.x + 600.0
	race.turtle.speed = 253.0
	await _frames(3)
	_check(race.snack_boost_active(), "snack boost is active for the snapshot")
	_check(race.hud.snack_label.visible
		and race.hud.snack_label.text.contains("TURBO")
		and (race.hud.snack_label.text.contains("!") or race.hud.snack_label.text.contains("！")),
		"boost state shows TURBO in HUD ('%s')" % race.hud.snack_label.text)
	data["turbo_text_zh"] = race.hud.snack_label.text

	_hud_checks("zh", "兔子", "氧气")
	data["hud_shot_zh"] = await _shot("phase-t-hud-zh-1280x720.png")

	Locale.set_language("en")
	await _frames(4)
	_check(race.hud.snack_label.text.contains("TURBO"),
		"en boost state shows TURBO ('%s')" % race.hud.snack_label.text)
	_hud_checks("en", "RABBIT", "AIR")
	data["hud_shot_en"] = await _shot("phase-t-hud-en-1280x720.png")
	data["turbo_text_en"] = race.hud.snack_label.text
	Locale.language = "zh"
	race.snack_boost_until_x = -1.0
	await _frames(2)

	# ---- 3) 连招反馈走真实 _update_combo ----
	await _combo_feedback()
	# ---- 4) 真实落水 + 主动接住，看 HUD 反馈与计数 ----
	await _rescue_feedback()
	# ---- 5) 结算页 ----
	await _result_checks()

	_finish()


## HUD 可见文字：无总分、四要素、字号、面板面积。
func _hud_checks(tag: String, who_word: String, air_word: String) -> void:
	var hud = race.hud
	var text := _joined(hud)
	_check(not text.contains("12345") and not text.contains("分数")
		and not text.contains("SCORE"),
		"%s HUD hides fixed total score" % tag)
	_check(hud.control_label.text.contains(who_word),
		"%s HUD shows current character ('%s')" % [tag, hud.control_label.text])
	_check(hud.bro_meter_label.text.contains("BRO METER"),
		"%s HUD shows BRO METER ('%s')" % [tag, hud.bro_meter_label.text])
	_check(hud.oxygen_label.text.contains(air_word),
		"%s HUD shows oxygen ('%s')" % [tag, hud.oxygen_label.text])
	var mf := _min_actual_font(hud)
	_check(float(mf["actual"]) >= MIN_PX,
		"%s HUD min actual font %.1f px >= %.0f (design %.0f, '%s')" % [
			tag, mf["actual"], MIN_PX, mf["design"], mf["text"]])
	var ratio := _panel_area_ratio(hud)
	_check(ratio <= AREA_LIMIT,
		"%s panel area %.2f%% <= %.0f%%" % [tag, ratio * 100.0, AREA_LIMIT * 100.0])
	data["font_" + tag] = mf
	data["panel_area_" + tag] = snappedf(ratio, 0.0001)


## 真实 _update_combo：combo 2 -> 越过 bird1 -> combo 3 应发 BRO COMBO。
func _combo_feedback() -> void:
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	await get_tree().physics_frame
	race.test_disable_hazards = true
	race.test_no_finish = true
	var group := {}
	for g in race.hazard_groups:
		if String(g["group"]) == "bird1":
			group = g
			break
	_check(not group.is_empty(), "bird1 exists for combo probe")
	if group.is_empty():
		return
	var start := LevelData.group_start(group)
	var end := LevelData.group_end(group)
	race.combo = 2
	GameManager.combo = 2
	GameManager.accident_state = "NONE"
	race.turtle.position = Vector2(start - 100.0, Tuning.NEUTRAL_DEPTH)
	race.turtle.speed = 0.0
	await _frames(3)
	race.turtle.position.x = end + 90.0
	race.turtle.speed = 0.0
	var seen := ""
	for i in 16:
		await get_tree().process_frame
		race.turtle.speed = 0.0
		if race.hud.feedback_label.visible:
			seen = race.hud.feedback_label.text
			break
	_check(seen.contains("BRO COMBO"),
		"combo milestone feedback in HUD (got '%s', combo=%d)" % [seen, race.combo])
	data["combo_feedback"] = seen
	data["combo_after"] = race.combo
	GameManager.combo = 0
	race.combo = 0


## 真实撞梁落水（错误动作）→ SHIFT 切乌龟 + 按住 ↓ → 接住。
func _rescue_feedback() -> void:
	Engine.time_scale = 4.0
	Engine.physics_ticks_per_second = int(STEP_HZ * Engine.time_scale)
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	await get_tree().physics_frame
	race.test_disable_hazards = false
	race.test_no_finish = true
	var enc := {}
	for e in LevelData.snack_encounters():
		if String(e["obstacle_group"]) == "beam1":
			enc = e
			break
	var group := {}
	for g in race.hazard_groups:
		if String(g["group"]) == "beam1":
			group = g
			break
	_check(not enc.is_empty() and not group.is_empty(), "beam1 encounter exists for rescue probe")
	if enc.is_empty() or group.is_empty():
		Engine.time_scale = 1.0
		Engine.physics_ticks_per_second = int(STEP_HZ)
		return
	var food_x := float(enc["x"])
	var obs_start := LevelData.group_start(group)
	var obs_end := LevelData.group_end(group)
	_reset(food_x - 320.0, "turtle")
	sim = 0.0
	var switched := false
	var jumped := false
	var crash := ""
	var counter_before := GameManager.rescue_success_count
	var seen := ""
	var caught := false
	var steps := 0
	while steps < int(STEP_HZ * 8.0):
		var x: float = race.turtle.position.x
		if not switched and race.snack_last_eaten != "":
			switched = true
			_control("rabbit")
		if switched and not jumped and x >= obs_start - 45.0:
			_press("up")
			jumped = true
		if GameManager.accident_state == "RABBIT_WATER":
			crash = "RABBIT_WATER"
			break
		await _step()
		steps += 1
		if x >= obs_end + 700.0:
			break
	_release_all()
	if crash == "RABBIT_WATER":
		_shift()
		_press("down")
		for i in int(STEP_HZ * 6.0):
			if GameManager.rescue_success_count > counter_before:
				caught = true
				break
			await _step()
		# HUD 在 _process 里把 feedback_text 写进 Label；等两帧再读实际可见文字。
		await _frames(2)
		seen = race.hud.feedback_label.text
	_release_all()
	_check(crash == "RABBIT_WATER", "real collision produces RABBIT_WATER")
	_check(caught and GameManager.rescue_success_count == counter_before + 1,
		"active rescue catch increments rescue_success_count (%d -> %d)" % [
			counter_before, GameManager.rescue_success_count])
	# G15：这里原来断言“最后一条可见反馈含『接住』”。但救援是两拍：
	# 抓到的瞬间发 feedback.rescue_ok（接住了！兄弟！），抬回壳上完成 carry 时
	# 再发 feedback.rescue_reunion（兄弟回来了！…）。HUD 反馈行后写覆盖前写，而
	# rescue_success_count 要到 carry 完成才 +1——所以读到的永远是第二拍，
	# 这条断言从加入重聚文案那天起就必挂（该测试需要窗口，不在 headless 批量里，
	# 一直没人发现）。改成同时断言“第一拍发出过 + HUD 最后显示重聚”，
	# 不再依赖某一拍的停留时间，也不改产品文案。
	var catch_msg := Locale.t("feedback.rescue_ok")
	var catch_seen := false
	for e in _fb_events:
		if String(e).begins_with(catch_msg):
			catch_seen = true
	_check(catch_seen and seen == Locale.t("feedback.rescue_reunion"),
		"rescue feedback two beats (catch emitted=%s, HUD last='%s')" % [
			str(catch_seen), seen])
	data["rescue_crash"] = crash
	data["rescue_feedback"] = seen
	data["rescue_feedback_events"] = _fb_events.slice(-4)
	data["rescue_success_count"] = GameManager.rescue_success_count
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = int(STEP_HZ)


## 结算页：七项可读、无固定总分、字号与截图。
func _result_checks() -> void:
	GameManager.grade = "S"
	GameManager.total_score = 12460
	GameManager.finish_time = 296.63
	GameManager.clean_pass_count = 55
	GameManager.combo_dive_count = 8
	GameManager.combo_ollie_count = 3
	GameManager.rescue_success_count = 4
	GameManager.accident_count = 2
	GameManager.joint_accident_count = 1
	GameManager.best_time = 296.63
	GameManager.best_accidents = 0
	GameManager.best_streak_record = 54
	GameManager.new_best_time = false
	GameManager.new_best_score = false
	GameManager.new_best_streak = false
	Locale.language = "zh"
	get_tree().change_scene_to_file("res://scenes/result.tscn")
	await _frames(8)
	var res := get_tree().current_scene
	_check(res != null and res.scene_file_path.ends_with("result.tscn"),
		"result scene loads")
	if res == null:
		return
	var zh := _joined(res)
	_check(_line_with(zh, "比赛时间").contains("296.63"), "zh result shows time")
	_check(_line_with(zh, "干净通过").contains("55"), "zh result shows clean passes")
	_check(_line_with(zh, "连招").contains("11"), "zh result shows combos")
	_check(_line_with(zh, "救援成功").contains("4"), "zh result shows rescue saves")
	_check(_line_with(zh, "失误").contains("2"), "zh result shows mistakes")
	_check(_line_with(zh, "翻船次数").contains("1"), "zh result shows capsizes")
	_check(zh.contains("S"), "zh result shows final grade")
	_check(not zh.contains("总分") and not zh.contains("12460"),
		"zh result hides fixed total score")
	var mf_zh := _min_actual_font(res)
	_check(float(mf_zh["actual"]) >= MIN_PX,
		"zh result min actual font %.1f px >= %.0f (design %.0f, '%s')" % [
			mf_zh["actual"], MIN_PX, mf_zh["design"], mf_zh["text"]])
	data["font_result_zh"] = mf_zh
	data["result_zh_lines"] = zh.split("\n")
	data["result_shot_zh"] = await _shot("phase-t-result-zh-1280x720.png")

	Locale.set_language("en")
	await _frames(4)
	var en := _joined(res)
	_check(_line_with(en, "RACE TIME").contains("296.63"), "en result shows time")
	_check(_line_with(en, "CLEAN PASSES").contains("55"), "en result shows clean passes")
	_check(_line_with(en, "BRO COMBOS").contains("11"), "en result shows combos")
	_check(_line_with(en, "RESCUE SAVES").contains("4"), "en result shows rescue saves")
	_check(_line_with(en, "MISTAKES").contains("2"), "en result shows mistakes")
	_check(_line_with(en, "CAPSIZES").contains("1"),
		"en result shows capsizes")
	_check(not en.contains("TOTAL SCORE") and not en.contains("12460"),
		"en result hides fixed total score")
	var mf_en := _min_actual_font(res)
	_check(float(mf_en["actual"]) >= MIN_PX,
		"en result min actual font %.1f px >= %.0f (design %.0f, '%s')" % [
			mf_en["actual"], MIN_PX, mf_en["design"], mf_en["text"]])
	data["font_result_en"] = mf_en
	data["result_shot_en"] = await _shot("phase-t-result-en-1280x720.png")
	Locale.set_language("zh")


# ---------------- 工具 ----------------

func _check(ok: bool, what: String) -> void:
	var row := {"ok": ok, "what": what}
	checks.append(row)
	print("HUD-SCORE %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures.append(what)


func _visible_labels(root: Node) -> Array:
	var out := []
	if (root is Label or root is Button) and root.is_visible_in_tree():
		out.append(root)
	for child in root.get_children():
		out.append_array(_visible_labels(child))
	return out


func _joined(root: Node) -> String:
	var parts := PackedStringArray()
	for c in _visible_labels(root):
		parts.append(String(c.text))
	return "\n".join(parts)


func _line_with(text: String, key: String) -> String:
	for line in text.split("\n"):
		if line.contains(key):
			return line
	return ""


func _min_actual_font(root: Node) -> Dictionary:
	var min_design := 9999.0
	var min_text := ""
	for c in _visible_labels(root):
		var fs := float(c.get_theme_font_size("font_size"))
		if fs < min_design:
			min_design = fs
			min_text = String(c.text).substr(0, 28)
	return {
		"design": min_design,
		"actual": snappedf(min_design * _scale, 0.1),
		"text": min_text,
	}


func _panel_area_ratio(hud) -> float:
	var vp := get_viewport().get_visible_rect().size
	var area := 0.0
	for c in ["tl", "tr", "bl", "br"]:
		var panel: Control = hud._panels[c]
		var r := panel.get_global_rect()
		area += r.size.x * r.size.y
	return area / (vp.x * vp.y)


func _shot(file_name: String) -> String:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(file_name)
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("HUD-SCORE SHOT %s (%dx%d)" % [path, img.get_width(), img.get_height()])
	return "res://screenshots/" + file_name


func _wait_scene(suffix: String) -> void:
	for i in 240:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path.ends_with(suffix):
			return
	_check(false, "scene %s loaded" % suffix)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _reset(x: float, control: String) -> void:
	_release_all()
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.oxygen = Tuning.OXYGEN_MAX
	GameManager.bro_meter = 0
	GameManager.showtime_active = false
	GameManager.current_control = control
	GameManager.has_shifted = true
	GameManager.pickup_window = false
	race.showtime_active = false
	race.showtime_t = 0.0
	race.finishing = false
	race.hazard_cooldown = 0.0
	race.turtle_repair = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.rabbit_stun = 0.0
	race.emergency_timer = 0.0
	race.combo = 0
	race.rescue_last_result = ""
	# G20：hit_roles 必须和 hit_groups 一起清。只清 hit_groups 时，B2 起的“角色×组”记账还留着，同组第二例起整组免疫——后面那些重复用例其实在测一段不会撞的赛道。
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.current_zone = LevelData.zone_at(x)
	var speed: float = float(race.current_zone["base_speed"])
	race.turtle.reset(Vector2(x, Tuning.NEUTRAL_DEPTH))
	race.turtle.speed = speed
	race.turtle.base_speed = speed
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()


func _control(who: String) -> void:
	if GameManager.current_control != who:
		GameManager.set_control(who)


## SHIFT 走真实 InputEventKey；引擎没派发时退回直接调用并记录。
func _shift() -> String:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SHIFT
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	if GameManager.current_control == "turtle":
		return "action"
	GameManager.toggle_control()
	return "direct"


func _press(action: String) -> void:
	if not Input.is_action_pressed(action):
		Input.action_press(action)


func _release_all() -> void:
	Input.action_release("up")
	Input.action_release("down")
	Input.action_release("shift")


func _step() -> void:
	await get_tree().physics_frame
	sim += 1.0 / STEP_HZ


func _finish() -> void:
	data["checks"] = checks
	data["failures"] = failures
	data["generated_at"] = Time.get_datetime_string_from_system()
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
		f.close()
	if failures.is_empty():
		print("STAGE4 HUD SCORE: PASS checks=%d" % checks.size())
		get_tree().quit(0)
	else:
		print("STAGE4 HUD SCORE: FAIL checks=%d failures=%d" % [checks.size(), failures.size()])
		for item in failures:
			print("  - " + item)
		get_tree().quit(1)
