extends Node
## 阶段 3 自检：三区域赛道数据、分区难度、评分与纪录、以及
## 菜单 → 比赛 → 终点 → 结算 → R 重开 / 回车回菜单的完整闭环。
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT res://scenes/stage3_selftest.tscn

const LevelDataScript = preload("res://scripts/systems/level_data.gd")

var is_runner := false
var failures: Array[String] = []
var race
var _best_backup := {}


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage3Runner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	_best_backup = _backup_best()
	# 旧断言按英文写；直接改内存语言，不写 settings.json。
	Locale.language = "en"

	_check_level_data()
	_check_scoring()
	_check_persistence()
	await _check_full_flow()

	_restore_best(_best_backup)

	if failures.is_empty():
		print("STAGE3 SELFTEST: PASS")
		get_tree().quit(0)
	else:
		print("STAGE3 SELFTEST: FAIL")
		for item in failures:
			print("  - " + item)
		get_tree().quit(1)


# ---- 1. 赛道数据。 ----

func _check_level_data() -> void:
	var zones: Array = LevelDataScript.ZONES
	_check(zones.size() == 3, "3 zones declared (%d)" % zones.size())
	_check(zones[0]["id"] == 1 and zones[1]["id"] == 2 and zones[2]["id"] == 3,
		"zone ids are 1, 2, 3")
	_check(zones[0]["name"] == "SUNNY COAST"
		and zones[1]["name"] == "DOCK CHAOS"
		and zones[2]["name"] == "MUSCLE MAYHEM", "zone names")
	_check(is_zero_approx(zones[0]["start"]), "zone 1 starts at 0")
	_check(is_equal_approx(zones[0]["end"], 15000.0)
		and is_equal_approx(zones[1]["start"], 15000.0), "zone 1/2 boundary 15000")
	_check(is_equal_approx(zones[1]["end"], 39000.0)
		and is_equal_approx(zones[2]["start"], 39000.0), "zone 2/3 boundary 39000")
	_check(is_equal_approx(zones[2]["end"], LevelDataScript.WORLD_END),
		"zone 3 ends at world end %.0f" % LevelDataScript.WORLD_END)
	_check(is_equal_approx(zones[0]["base_speed"], 220.0)
		and is_equal_approx(zones[1]["base_speed"], 240.0)
		and is_equal_approx(zones[2]["base_speed"], 260.0),
		"base speed 220 / 240 / 260")

	_check(LevelDataScript.zone_at(0.0)["id"] == 1, "zone_at(0) = 1")
	_check(LevelDataScript.zone_at(14999.0)["id"] == 1, "zone_at(14999) = 1")
	_check(LevelDataScript.zone_at(15000.0)["id"] == 2, "zone_at(15000) = 2")
	_check(LevelDataScript.zone_at(38999.0)["id"] == 2, "zone_at(38999) = 2")
	_check(LevelDataScript.zone_at(39000.0)["id"] == 3, "zone_at(39000) = 3")
	_check(LevelDataScript.zone_at(65999.0)["id"] == 3, "zone_at(65999) = 3")

	var groups: Array = LevelDataScript.groups()
	_check(groups.size() == 55, "55 hazard groups (%d)" % groups.size())
	var counts := {1: 0, 2: 0, 3: 0}
	var kinds_by_zone := {1: {}, 2: {}, 3: {}}
	var all_kinds := {}
	var zone_ok := true
	var rects_ok := true
	var sorted_ok := true
	var prev_start := -1.0
	for g in groups:
		var zid: int = g["zone"]
		var kind: String = g["kind"]
		counts[zid] = counts.get(zid, 0) + 1
		kinds_by_zone[zid][kind] = true
		all_kinds[kind] = true
		var start := LevelDataScript.group_start(g)
		var end := LevelDataScript.group_end(g)
		var zone: Dictionary = LevelDataScript.zone_by_id(zid)
		if start < zone["start"] or end > zone["end"]:
			zone_ok = false
		if start <= prev_start:
			sorted_ok = false
		prev_start = start
		if g["rects"].is_empty() or not g.has("hint") or not g.has("action"):
			rects_ok = false
	_check(counts[1] == 12 and counts[2] == 20 and counts[3] == 23,
		"groups per zone 12 / 20 / 23 (%s)" % str(counts))
	_check(zone_ok, "every group lies inside its declared zone")
	_check(sorted_ok, "groups are sorted by start x")
	_check(rects_ok, "every group has rects / hint / action")
	# STAGE 4 加入 HIGH_WALL（BRO OLLIE），空间类别从 6 类变 7 类。
	_check(all_kinds.size() == 7, "all 7 space classes present (%s)" % str(all_kinds.keys()))
	_check(kinds_by_zone[1].size() == 7 and kinds_by_zone[2].size() == 7
		and kinds_by_zone[3].size() == 7,
		"each zone contains all 7 classes (%d/%d/%d)" % [
			kinds_by_zone[1].size(), kinds_by_zone[2].size(), kinds_by_zone[3].size()])

	var lanes: Array = LevelDataScript.boost_lanes()
	_check(lanes.size() == 9, "9 boost lanes (%d)" % lanes.size())
	var lanes_in_zone := {1: 0, 2: 0, 3: 0}
	var lanes_ok := true
	for lane in lanes:
		var rect: Rect2 = lane
		if rect.position.x < 0.0 or rect.end.x > LevelDataScript.WORLD_END:
			lanes_ok = false
		lanes_in_zone[LevelDataScript.zone_at(rect.position.x)["id"]] += 1
	_check(lanes_ok, "boost lanes inside track")
	_check(lanes_in_zone[1] >= 2 and lanes_in_zone[2] >= 2 and lanes_in_zone[3] >= 2,
		"boost lanes in all zones (%s)" % str(lanes_in_zone))
	_check(LevelDataScript.lane_at(2600.0) and not LevelDataScript.lane_at(1200.0),
		"lane_at matches boost lane")

	# 难度递增：密度上升、最长空档缩短、连段更长。
	var st: Dictionary = LevelDataScript.stats()
	var z1: Dictionary = st[1]
	var z2: Dictionary = st[2]
	var z3: Dictionary = st[3]
	_check(z1["groups_per_min"] < z2["groups_per_min"]
		and z2["groups_per_min"] < z3["groups_per_min"],
		"density rises %.1f < %.1f < %.1f groups/min" % [
			z1["groups_per_min"], z2["groups_per_min"], z3["groups_per_min"]])
	# 空档按“时间”判，不按像素：快区的组合前导天然更长（260 px/s 下 5 s = 1300 px）。
	# FEEL-09：用“上一组尾端 → 下一组起点”的自由时间；start-to-start 会把
	# 600 px 的长隧道也算成空档，误报 7.31 s。
	var gap_px := [_max_tail_gap(1), _max_tail_gap(2), _max_tail_gap(3)]
	var gap_s := [gap_px[0] / 220.0, gap_px[1] / 240.0, gap_px[2] / 260.0]
	_check(gap_s[0] <= 6.0 and gap_s[1] <= 6.0 and gap_s[2] <= 6.0,
		"longest empty stretch stays under 6 s in every zone (%.2f / %.2f / %.2f s)" % gap_s)
	var logs := {1: 0, 2: 0, 3: 0}
	for group in LevelDataScript.groups():
		if group["kind"] == "FLOATING_LOG":
			logs[group["zone"]] += 1
	_check(logs[1] >= 1 and logs[2] >= 3 and logs[3] >= 4,
		"combined obstacles rise per zone (%d / %d / %d)" % [logs[1], logs[2], logs[3]])
	print("  stats  -> Z1 %.1f/min tail-gap %.0f | Z2 %.1f/min tail-gap %.0f | Z3 %.1f/min tail-gap %.0f" % [
		z1["groups_per_min"], gap_px[0],
		z2["groups_per_min"], gap_px[1],
		z3["groups_per_min"], gap_px[2]])


func _max_tail_gap(zone_id: int) -> float:
	var list: Array = LevelDataScript.groups_in_zone(zone_id)
	list.sort_custom(func(a, b) -> bool:
		return LevelDataScript.group_start(a) < LevelDataScript.group_start(b))
	var prev := 0.0
	var first := true
	var mx := 0.0
	for g in list:
		var s: float = LevelDataScript.group_start(g)
		if first:
			# 区域开场到第一组不算“障碍之间”的空档。
			first = false
		else:
			mx = maxf(mx, s - prev)
		prev = LevelDataScript.group_end(g)
	return mx


# ---- 2. 评分与事故分类。 ----

func _check_scoring() -> void:
	GameManager._reset_run()
	# STAGE 4 指令的分数表：分数按动作逐笔累计，时间/等待不加分。
	GameManager.add_score(150, "precise:SURFACE_ROCK")
	GameManager.add_score(250, "bro_dive")
	GameManager.add_score(300, "bro_ollie")
	GameManager.add_score(-100, "mistake:RABBIT_SLIP")
	_check(GameManager.total_score == 600,
		"score table 150+250+300-100 = %d" % GameManager.total_score)
	GameManager.add_score(-100, "mistake:RABBIT_SLIP")
	_check(GameManager.total_score == 500,
		"mistakes are -100 each (%d)" % GameManager.total_score)
	GameManager._reset_run()
	GameManager.note_clean_pass()
	_check(GameManager.total_score == 100 and GameManager.clean_pass_count == 1,
		"clean pass pays +100 (%d/clean %d)" % [
			GameManager.total_score, GameManager.clean_pass_count])

	_check(GameManager.grade_for_score(8000) == "S", "grade S at 8000")
	_check(GameManager.grade_for_score(7999) == "A", "grade A at 7999")
	_check(GameManager.grade_for_score(6500) == "A", "grade A at 6500")
	_check(GameManager.grade_for_score(6499) == "B", "grade B at 6499")
	_check(GameManager.grade_for_score(5000) == "B", "grade B at 5000")
	_check(GameManager.grade_for_score(2999) == "D", "grade D below 3000")

	# PHASE-1：旧三格 BRO METER 已退役；失误现在记事故并生成 7 s 抱怨窗口。
	GameManager._reset_run()
	GameManager.note_mistake("RABBIT_STUN", "rabbit")
	_check(GameManager.accident_count == 1
		and GameManager.complaint_role == "rabbit"
		and GameManager.complaint_t > 6.0,
		"mistake -> accident + 7s complaint (%d/%s/%.1f)" % [
			GameManager.accident_count, GameManager.complaint_role,
			GameManager.complaint_t])
	GameManager.note_mistake("TURTLE_WAVE", "turtle")
	_check(GameManager.accident_count == 2
		and GameManager.complaint_role == "turtle",
		"second mistake -> new complaint role")

	GameManager._reset_run()
	GameManager.note_clean_pass()
	GameManager.note_clean_pass()
	GameManager.note_clean_pass()
	_check(GameManager.perfect_cooperation == 3 and GameManager.perfect_streak == 3
		and GameManager.best_streak == 3, "3 clean passes -> coop 3 / streak 3")
	GameManager.note_showtime()
	_check(GameManager.perfect_streak == 3, "Showtime does not reset perfect streak")
	GameManager.note_accident("RABBIT_SLIP")
	_check(GameManager.rabbit_casualties == 1 and GameManager.perfect_streak == 0,
		"rabbit slip -> Rabbit Casualties 1 / streak reset")
	GameManager.note_clean_pass()
	GameManager.note_accident("TURTLE_REEF")
	_check(GameManager.turtle_failures == 1 and GameManager.perfect_streak == 0,
		"turtle reef -> Turtle Engine Failure 1 / streak reset")
	GameManager.note_clean_pass()
	GameManager.note_accident("RABBIT_STUN")
	_check(GameManager.rabbit_casualties == 1 and GameManager.turtle_failures == 1
		and GameManager.perfect_streak == 0,
		"stun resets streak but stays outside the two GDD categories")
	print("  score  -> formula / grades / accident classes ok")


# ---- 3. best.json 读写（先备份玩家纪录）。 ----

func _check_persistence() -> void:
	GameManager.best_time = 123.45
	GameManager.best_accidents = 3
	GameManager.best_score = 8888
	GameManager.best_streak_record = 9
	GameManager._save_best()
	_check(FileAccess.file_exists(GameManager.BEST_PATH), "best.json written")
	var parsed = JSON.parse_string(
		FileAccess.get_file_as_string(GameManager.BEST_PATH))
	_check(typeof(parsed) == TYPE_DICTIONARY, "best.json is valid JSON")
	var raw := ""
	if typeof(parsed) == TYPE_DICTIONARY:
		_check(is_equal_approx(float(parsed.get("best_time", -1.0)), 123.45)
			and int(parsed.get("best_accidents", -1)) == 3
			and int(parsed.get("best_score", -1)) == 8888
			and int(parsed.get("best_streak", -1)) == 9,
			"best.json stores time / accidents / score / streak")
		for key in ["best_time", "best_accidents", "best_score", "best_streak"]:
			raw += "%s=%s " % [key, str(parsed.get(key))]
	GameManager.best_time = -1.0
	GameManager.best_accidents = -1
	GameManager.best_score = -1
	GameManager.best_streak_record = 0
	GameManager._load_best()
	_check(is_equal_approx(GameManager.best_time, 123.45)
		and GameManager.best_accidents == 3
		and GameManager.best_score == 8888
		and GameManager.best_streak_record == 9, "best.json reads back")
	# 旧计分档（没有 score_model）的最高分不能被当成新表纪录，否则永远刷不破；
	# 时间/事故/连胜是同一口径，必须保留。
	var legacy := FileAccess.open(GameManager.BEST_PATH, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({
		"best_time": 100.0, "best_accidents": 2,
		"best_score": 12460, "best_streak": 7,
	}))
	legacy.close()
	GameManager.best_time = -1.0
	GameManager.best_accidents = -1
	GameManager.best_score = -1
	GameManager.best_streak_record = 0
	GameManager._load_best()
	_check(GameManager.best_score == -1
		and is_equal_approx(GameManager.best_time, 100.0)
		and GameManager.best_accidents == 2
		and GameManager.best_streak_record == 7,
		"legacy score is dropped, other records survive")
	print("  best   -> %s(%s)" % [raw, GameManager.best_path_absolute()])


# ---- 4. 菜单 → 比赛 → 结算 → 重开 / 回菜单。 ----

func _check_full_flow() -> void:
	get_tree().change_scene_to_file(GameManager.MENU_SCENE)
	await _frames(5)
	_check(_scene_is("menu.tscn"), "menu scene loads")

	# 主菜单开始会先走开场漫画；本测试只验菜单之后的比赛/结算链路。
	GameManager.start_race()
	await _frames(10)
	_check(_scene_is("race.tscn"), "start_race opens race")
	_check(GameManager.state == GameManager.GameState.RUNNING, "state RUNNING")
	race = get_tree().current_scene
	race.test_disable_hazards = true

	race.turtle.position = Vector2(16000.0, 300.0)
	await _physics_frames(3)
	await _frames(2)
	_check(GameManager.zone == 2 and GameManager.zone_name_text == "DOCK CHAOS",
		"zone 2 entered at 16000")
	_check(is_equal_approx(race.turtle.base_speed, 240.0),
		"zone 2 base speed 240 (%.0f)" % race.turtle.base_speed)
	_check(race.hud.zone_label.text.contains("ZONE 2/3"),
		"HUD shows ZONE 2/3")

	race.turtle.position = Vector2(40000.0, 300.0)
	await _physics_frames(3)
	await _frames(2)
	_check(GameManager.zone == 3 and GameManager.zone_name_text == "MUSCLE MAYHEM",
		"zone 3 entered at 40000")
	_check(is_equal_approx(race.turtle.base_speed, 260.0),
		"zone 3 base speed 260 (%.0f)" % race.turtle.base_speed)
	_check(race.hud.zone_label.text.contains("ZONE 3/3"),
		"HUD shows ZONE 3/3")
	_check(GameManager.zones_visited.has(1) and GameManager.zones_visited.has(2)
		and GameManager.zones_visited.has(3), "all three zones recorded")

	await _finish_now(305.0)
	_check(GameManager.finished, "finish captured")
	_check(GameManager.finish_time >= 305.0,
		"finish time recorded (%.1f)" % GameManager.finish_time)
	await _await_result()
	_check(_scene_is("result.tscn"), "result scene loads after finish")
	_check(GameManager.state == GameManager.GameState.RESULT, "state RESULT")
	var texts := _label_texts(get_tree().current_scene)
	var joined := "\n".join(PackedStringArray(texts))
	# §七-9：结算七项（时间/干净通过/连招/救援成功/失误/联合事故/评级），
	# 固定数字总分退出玩家界面。
	for metric in ["RACE TIME", "CLEAN PASSES", "MISTAKES", "BRO DIVE"]:
		_check(joined.contains(metric), "result shows " + metric)
	_check(not joined.contains("TOTAL SCORE"), "result hides total score")
	_check(GameManager.grade in ["S", "A", "B", "C", "D"],
		"result grade in S-D (%s)" % GameManager.grade)
	_check(joined.contains("RETRY") and joined.contains("MAIN MENU"),
		"result offers Retry / Main Menu")
	print("  result -> grade=%s score=%d time=%.1f" % [
		GameManager.grade, GameManager.total_score, GameManager.finish_time])

	await _press(KEY_R)
	await _frames(6)
	_check(_scene_is("race.tscn") and GameManager.state == GameManager.GameState.RUNNING,
		"R on result restarts the race")
	_check(not GameManager.finished and GameManager.race_time < 0.5,
		"restart clears finish state")
	race = get_tree().current_scene
	race.test_disable_hazards = true

	await _press(KEY_ESCAPE)
	await _frames(3)
	_check(GameManager.state == GameManager.GameState.PAUSED, "ESC pauses")
	await _press(KEY_M)
	await _frames(6)
	_check(_scene_is("menu.tscn") and GameManager.state == GameManager.GameState.MENU,
		"M from pause returns to menu")

	GameManager.start_race()
	await _frames(10)
	_check(_scene_is("race.tscn"), "start_race opens a second race")
	race = get_tree().current_scene
	race.test_disable_hazards = true
	await _finish_now(320.0)
	await _await_result()
	_check(_scene_is("result.tscn"), "second finish reaches result")
	# 结算页的 Enter 现在是“确认当前焦点按钮”（默认是再玩一次），
	# 回主菜单走 M 或点按钮；这里验快捷键路径。
	await _press(KEY_M)
	await _frames(6)
	_check(_scene_is("menu.tscn"), "M on result returns to menu")

	# 第二次跑完时 best.json 已有纪录，菜单应能显示。
	var menu_texts := _label_texts(get_tree().current_scene)
	var menu_joined := "\n".join(PackedStringArray(menu_texts))
	_check(menu_joined.contains("TURBBIT BRO"), "menu loads after finishes")
	print("  menu   -> %s" % menu_joined.replace("\n", " | "))


func _finish_now(time_value: float) -> void:
	GameManager.race_time = time_value
	race.turtle.position = Vector2(LevelDataScript.WORLD_END - 30.0, 300.0)
	var start := Time.get_ticks_msec()
	while not GameManager.finished and Time.get_ticks_msec() - start < 4000:
		await get_tree().physics_frame


func _await_result() -> void:
	var start := Time.get_ticks_msec()
	while not _scene_is("result.tscn") and Time.get_ticks_msec() - start < 6000:
		await get_tree().physics_frame
	await _frames(2)


func _scene_is(name: String) -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path.ends_with(name)


func _label_texts(root: Node) -> Array[String]:
	var out: Array[String] = []
	if root is Label and (root as Label).text != "":
		out.append((root as Label).text)
	for child in root.get_children():
		out.append_array(_label_texts(child))
	return out


# ---- best.json 备份 / 还原，避免自检里 305 秒的假成绩污染玩家纪录。 ----

func _backup_best() -> Dictionary:
	var info := {"exists": FileAccess.file_exists(GameManager.BEST_PATH), "text": ""}
	if info["exists"]:
		info["text"] = FileAccess.get_file_as_string(GameManager.BEST_PATH)
	return info


func _restore_best(info: Dictionary) -> void:
	if info.get("exists", false):
		var file := FileAccess.open(GameManager.BEST_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(info["text"])
			file.close()
	elif FileAccess.file_exists(GameManager.BEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameManager.BEST_PATH))
	GameManager.best_time = -1.0
	GameManager.best_accidents = -1
	GameManager.best_score = -1
	GameManager.best_streak_record = 0
	GameManager._load_best()


# ---- 工具。 ----

func _press(keycode: Key) -> void:
	_send_key(keycode, true)
	await get_tree().process_frame
	_send_key(keycode, false)
	await get_tree().process_frame


func _send_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	# 真实按键同时带 keycode 和 physical_keycode；只填 physical 时
	# InputMap 的 ui_accept（按 keycode 匹配）不会命中，菜单按钮就收不到 Enter。
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok  " + message)
	else:
		failures.append(message)
		print("  FAIL " + message)
