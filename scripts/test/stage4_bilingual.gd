extends Node
## 阶段 4 双语自检：默认中文、切换语言立即生效、持久化、HUD/结算/大字实时刷新，
## 以及“语言不影响玩法数值 / 不污染纪录”。
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT res://scenes/stage4_bilingual.tscn

const SETTINGS_PATH := "user://settings.json"

var is_runner := false
var failures: Array[String] = []
var race
var _settings_backup := {}
var _orig_language := "zh"
var _best_text := ""


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4Runner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	_settings_backup = _backup_file(SETTINGS_PATH)
	_orig_language = Locale.language
	_best_text = _read_file(GameManager.BEST_PATH)

	_check_default_chinese()
	_check_tables()
	await _check_menu_flow()
	await _check_hud_live_switch()
	await _check_banner_live_switch()
	await _check_pause_texts()
	await _check_result_live_switch()

	_check(_read_file(GameManager.BEST_PATH) == _best_text,
		"best.json unchanged by bilingual test")
	_restore_file(SETTINGS_PATH, _settings_backup)
	Locale.language = _orig_language

	if failures.is_empty():
		print("STAGE4 BILINGUAL: PASS")
		get_tree().quit(0)
	else:
		print("STAGE4 BILINGUAL: FAIL")
		for item in failures:
			print("  - " + item)
		get_tree().quit(1)


# ---- 1. 首次启动默认简体中文。 ----

func _check_default_chinese() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	Locale.language = "en"  # 故意先设错，验证 _load() 会回到默认。
	Locale._load()
	_check(Locale.language == "zh", "first launch defaults to zh without settings file")
	_check(Locale.t("menu.start").contains("回车"), "zh menu string loaded")
	_check(Locale.zone_name(1) == "阳光海岸", "zh zone name")


# ---- 2. 文本表完整性。 ----

func _check_tables() -> void:
	var missing_zh: Array[String] = []
	var missing_en: Array[String] = []
	for id in Locale.STRINGS.keys():
		var entry: Dictionary = Locale.STRINGS[id]
		if str(entry.get("zh", "")).strip_edges() == "":
			missing_zh.append(id)
		if str(entry.get("en", "")).strip_edges() == "":
			missing_en.append(id)
	_check(missing_zh.is_empty(), "every text id has zh (%d ids)" % Locale.STRINGS.size())
	_check(missing_en.is_empty(), "every text id has en")
	if not missing_zh.is_empty():
		print("  missing zh: %s" % str(missing_zh))
	if not missing_en.is_empty():
		print("  missing en: %s" % str(missing_en))

	_check(Locale.hazard("LOW ROCK") == "低岩", "hazard label mapped")
	_check(Locale.hazard("JUMP OVER") == "跳过去", "action label mapped")
	_check(Locale.hazard("UNKNOWN HINT") == "UNKNOWN HINT",
		"unmapped hazard text passes through")
	for grade in ["S", "A", "B", "C", "D"]:
		_check(Locale.grade_title(grade) != "", "grade title " + grade)
	for state in ["RIDING", "SLIDING", "STUNNED", "DAZED", "DANGER", "EMERGENCY"]:
		_check(Locale.state_name(state) != state or state == "SAFE",
			"state name mapped: " + state)
	_check(Locale.zone_lesson(1).contains("阳光海岸"), "zone lesson localized")


# ---- 3. 菜单：默认中文，L 立即切英文，S 进设置，ESC 返回，写入持久化。 ----

func _check_menu_flow() -> void:
	Locale.language = "zh"
	GameManager.state = GameManager.GameState.MENU
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	await _frames(5)
	var menu := get_tree().current_scene
	_check(menu != null and menu.scene_file_path.ends_with("menu.tscn"), "menu scene loads")

	var zh_text := _joined(menu)
	_check(zh_text.contains("TURBBIT BRO!"), "menu title")
	_check(zh_text.contains("开始游戏"), "zh start button")
	_check(zh_text.contains("设置"), "zh settings button")
	_check(zh_text.contains("退出游戏"), "zh quit button")
	_check(zh_text.contains("↑↓ 选择"), "zh menu key hint")
	print("  menu zh -> %s" % zh_text.replace("\n", " | "))

	# L 切换：不重启，当前界面立即变英文。
	await _press(KEY_L)
	await _frames(2)
	var en_text := _joined(menu)
	_check(Locale.language == "en", "L switches language in place")
	_check(en_text.contains("START GAME"), "menu refreshes to English instantly")
	_check(en_text.contains("QUIT"), "quit button in English")
	_check(not en_text.contains("开始游戏"), "no zh/en stacked in one menu")
	var saved := _read_file(SETTINGS_PATH)
	_check(saved.contains("\"en\""), "language choice persisted to settings.json")
	Locale.set_fullscreen(true)
	var fs_saved := _read_file(SETTINGS_PATH)
	_check(fs_saved.contains("\"fullscreen\":true"),
		"fullscreen choice persisted to settings.json")
	Locale.set_fullscreen(false)
	print("  menu en -> %s" % en_text.replace("\n", " | "))

	# S 进设置，设置页有语言按钮；ESC 返回主菜单而不是退出游戏。
	await _press(KEY_S)
	await _frames(2)
	var set_text := _joined(menu)
	_check(set_text.contains("SETTINGS"), "S opens settings")
	_check(set_text.contains("LANGUAGE: ENGLISH"), "settings shows language option")
	await _press(KEY_L)
	await _frames(2)
	var set_zh := _joined(menu)
	_check(set_zh.contains("设置") and set_zh.contains("简体中文"),
		"settings refreshes to Chinese instantly")
	await _press(KEY_ESCAPE)
	await _frames(2)
	var back := _joined(menu)
	_check(GameManager.state == GameManager.GameState.MENU, "ESC in settings does not quit")
	_check(back.contains("开始游戏"), "ESC returns to main menu")

	# 进入设置时回车不应该开始比赛；焦点在语言按钮上，回车只切语言。
	await _press(KEY_S)
	await _frames(2)
	await _press(KEY_ENTER)
	await _frames(3)
	_check(get_tree().current_scene.scene_file_path.ends_with("menu.tscn"),
		"ENTER in settings does not start the race")
	_check(Locale.language == "en",
		"ENTER in settings activates the focused language button")
	await _press(KEY_ESCAPE)
	await _frames(2)

	# 语言已持久化为英文，新建一个 Locale 实例模拟“下次启动”从文件读回。
	var fresh = load("res://scripts/autoload/locale.gd").new()
	add_child(fresh)
	await _frames(1)
	_check(fresh.language == "en", "fresh locale instance loads persisted English")
	fresh.queue_free()


# ---- 4. 比赛 HUD：中文显示；比赛中切语言立即刷新且数值不变。 ----

func _check_hud_live_switch() -> void:
	Locale.language = "zh"
	GameManager.start_race()
	await _frames(6)
	race = get_tree().current_scene
	race.test_no_mischief = true
	_check(race != null and race.scene_file_path.ends_with("race.tscn"), "race scene loads")
	race.test_disable_hazards = true
	await _frames(2)

	_check(race.hud.control_label.text.contains("操控"), "zh HUD control")
	_check(race.hud.control_label.text.contains("兔子"), "zh HUD TUBO")
	_check(race.hud.time_label.text.contains(":"), "zh HUD time")
	_check(race.hud.zone_label.text.contains("区域 1/3"), "zh HUD zone")
	_check(race.oxygen_bubble_count() > 0, "zh HUD oxygen bubbles")
	# FEEL-24 起右下角 0/3 面板（BRO METER、默契/Showtime）已整体移除；
	# 这里不再断言 bond_label / bro_meter_label，否则会拿到 nil 并中断整段 HUD 断言。
	# 底部行空闲时不放常驻说明书，只显示当下的短提示。
	_check(race.hud.hint_label.text == "", "zh HUD idle hint line is empty")
	print("  hud zh -> %s" % race.hud.control_label.text.replace("\n", " | "))

	var speed_before: float = race.turtle.speed
	var x_before: float = race.turtle.position.x
	var control_before: String = GameManager.current_control
	var oxygen_before: float = GameManager.oxygen
	var groups_before: int = race.total_groups()
	var accidents_before: int = GameManager.accident_count

	Locale.set_language("en")
	await _frames(2)
	_check(race.hud.control_label.text.contains("DRIVING"), "en HUD control updates live")
	_check(race.hud.time_label.text.contains(":"), "en HUD time updates live")
	_check(race.hud.zone_label.text.contains("ZONE 1/3"), "en HUD zone updates live")
	_check(race.oxygen_bubble_count() > 0, "en HUD oxygen bubbles")
	_check(race.hud.hint_label.text == "", "en HUD idle hint line stays empty")
	_check(is_equal_approx(race.turtle.speed, speed_before), "language does not change speed")
	_check(race.turtle.position.x >= x_before, "language does not rewind position")
	_check(GameManager.current_control == control_before, "language does not change control")
	_check(GameManager.oxygen <= oxygen_before + 1.0,
		"language does not change oxygen rules")
	_check(race.total_groups() == groups_before, "language does not change level data")
	_check(GameManager.accident_count == accidents_before, "language does not add accidents")


# ---- 5. 事故大字 / 接人 / 获救。 ----

func _check_banner_live_switch() -> void:
	var banner = race.get_node_or_null("Banner")
	_check(banner != null, "banner layer exists")
	if banner == null:
		return
	Locale.language = "zh"
	GameManager.accident.emit("RABBIT_SLIP")
	await _frames(1)
	_check(banner.label.text == "摔了！兔子 没抓住", "zh accident banner")
	Locale.set_language("en")
	GameManager.accident.emit("RABBIT_SLIP")
	await _frames(1)
	_check(banner.label.text == "WIPEOUT! TUBO LOST GRIP", "en accident banner")
	Locale.language = "zh"
	GameManager.pickup_success.emit()
	await _frames(1)
	_check(banner.label.text == "好接！", "zh pickup banner")
	Locale.language = "en"
	GameManager.rescue_done.emit()
	await _frames(1)
	_check(banner.label.text == "RESCUED", "en rescue banner")


# ---- 6. 暂停 / 场景内固定文字。 ----

func _check_pause_texts() -> void:
	Locale.language = "zh"
	_check(Locale.t("world.paused") == "已暂停", "zh pause title")
	_check(Locale.t("world.pause_hint").contains("ESC 继续"), "zh pause hint")
	Locale.language = "en"
	_check(Locale.t("world.paused") == "PAUSED", "en pause title")
	_check(Locale.t("world.pause_hint").contains("ESC RESUME"), "en pause hint")
	Locale.language = "zh"
	_check(Locale.t("world.danger_depth") == "危险深度", "zh danger depth")
	_check(Locale.t("world.finish") == "终点", "zh finish marker")
	_check(Locale.t("world.boost").contains("加速带"), "zh boost lane")
	Locale.language = "en"
	_check(Locale.t("world.danger_depth") == "DANGER DEPTH", "en danger depth")
	_check(Locale.t("world.finish") == "FINISH", "en finish marker")

	GameManager.toggle_pause()
	_check(GameManager.state == GameManager.GameState.PAUSED, "pause state set")
	GameManager.toggle_pause()
	_check(GameManager.state == GameManager.GameState.RUNNING, "resume state set")


# ---- 7. 结算：中文/英文实时切换，数字不变。 ----

func _check_result_live_switch() -> void:
	GameManager.state = GameManager.GameState.RESULT
	GameManager.grade = "B"
	GameManager.total_score = 12460
	GameManager.finish_time = 296.63
	GameManager.rabbit_casualties = 0
	GameManager.turtle_failures = 0
	GameManager.perfect_cooperation = 54
	GameManager.showtime_count = 18
	GameManager.best_streak = 54
	GameManager.accident_count = 5
	GameManager.combo_dive_count = 8
	GameManager.combo_ollie_count = 3
	GameManager.clean_pass_count = 55
	GameManager.joint_accident_count = 0
	GameManager.rescue_success_count = 4
	Locale.language = "zh"
	get_tree().change_scene_to_file("res://scenes/result.tscn")
	await _frames(5)
	var result := get_tree().current_scene
	_check(result != null and result.scene_file_path.ends_with("result.tscn"),
		"result scene loads")
	var zh_text := _joined(result)
	_check(zh_text.contains("训练结束"), "zh result title")
	_check(not zh_text.contains("总分"), "zh result hides total score")
	_check(zh_text.contains("比赛时间") and zh_text.contains("296.63"), "zh result time")
	_check(zh_text.contains("比赛时间") and zh_text.contains("失误")
		and zh_text.contains("干净通过"),
		"zh result stats (time/mistakes/clean)")
	_check(zh_text.contains("R 再来一次"), "zh result prompt")
	print("  result zh -> %s" % zh_text.replace("\n", " | "))

	Locale.set_language("en")
	await _frames(2)
	var en_text := _joined(result)
	_check(en_text.contains("TRAINING'S OVER"), "en result updates live")
	_check(not en_text.contains("TOTAL SCORE"), "en result hides total score")
	_check(en_text.contains("RACE TIME") and en_text.contains("MISTAKES")
		and en_text.contains("CLEAN PASSES"),
		"en result stats (time/mistakes/clean)")
	_check(en_text.contains("NEXT GOAL") and en_text.contains("0 MISTAKES"),
		"en result shows S clean goal")
	_check(en_text.contains("R  RETRY"), "en result prompt")
	_check(not en_text.contains("比赛"), "result has no leftover Chinese")
	Locale.set_language("zh")
	await _frames(2)
	_check(_joined(result).contains("训练结束"), "result switches back live")


# ---- 工具 ----

func _press(keycode: Key) -> void:
	_send_key(keycode, true)
	await get_tree().process_frame
	_send_key(keycode, false)
	await get_tree().process_frame


func _send_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _joined(root: Node) -> String:
	return "\n".join(PackedStringArray(_label_texts(root)))


func _label_texts(root: Node) -> Array[String]:
	var out: Array[String] = []
	if root is Label and (root as Label).text != "":
		out.append((root as Label).text)
	# 菜单/暂停/结算是原生 Button，不再是纯 Label。
	if root is Button and (root as Button).text != "":
		out.append((root as Button).text)
	for child in root.get_children():
		out.append_array(_label_texts(child))
	return out


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok  " + message)
	else:
		failures.append(message)
		print("  FAIL " + message)


func _read_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func _backup_file(path: String) -> Dictionary:
	return {"exists": FileAccess.file_exists(path), "text": _read_file(path)}


func _restore_file(path: String, info: Dictionary) -> void:
	if info.get("exists", false):
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(info["text"])
			file.close()
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
