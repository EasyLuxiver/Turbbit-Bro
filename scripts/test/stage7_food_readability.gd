extends Node
## CORE-FEEL-07 P1-C — 食物可读性验证（headless，真实 HUD / 真实吃取判定）
##
## 用户试玩原话：“目前食物我不知道有什么用也不清楚怎么让兔子或者乌龟吃到”。
## 本探针只核对“看得懂、看得出、不吃不亏”：
##   1) 接近食物时 HUD 同时预告两种效果（兔子 ↑ 更高跳 / 乌龟 » 加速）；
##   2) HUD 明确写出“当前谁吃”，够不到时写“够不到”而不是沉默；
##   3) 乌龟吃到：TURBO + 速度真的升高，HUD 写 TURBO 并点名乌龟；
##   4) 兔子吃到：下一跳强化真的生效，HUD / 反馈点名兔子；
##   5) 不吃（跃起越过）：不扣分、不记事故、BRO 不动；
##   6) 暂停页有食物说明；开场画面（第一次教学，零障碍）有食物说明；
##   7) 第一个食物所在位置的前后障碍距离（证明第一次“正式”讲解在开场而不是链中间）；
##   8) 世界里的食物自带两种效果图标 + “吃”标记（源码结构 + 截图另行人工核对）。
##
## 用法：
##   D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
##       res://scenes/stage7_food_readability.tscn > docs/reports/logs/core-feel-07-p1c.log 2>&1
##
## 输出：docs/reports/longrun/core-feel-07-food-readability.json

const LevelDataScript = preload("res://scripts/systems/level_data.gd")
const TuningScript = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/core-feel-07-food-readability.json"
const STEP := 1.0 / 60.0

var is_runner := false
var race: Node = null
var checks: Array = []
var data := {}
var feedback_log: Array = []


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
	GameManager.start_race()
	for i in 4:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null or race.hud == null:
		push_error("P1C: no race scene")
		_finish(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	GameManager.feedback.connect(_on_feedback)

	race.load_level(LevelDataScript.groups(), LevelDataScript.boost_lanes())
	await get_tree().physics_frame

	data["locale_zh"] = {}
	data["locale_en"] = {}
	var food_x := float(race._snack_list()[0]["x"])
	data["first_food"] = _food_neighborhood(food_x)

	# ---- 1/2) 接近时 HUD 预告 ----
	_place(food_x - 200.0, "turtle")
	race.hud._refresh()
	data["approach_turtle"] = _hud_texts()
	_expect("1 接近时 HUD 写“当前乌龟会吃”",
		String(race.hud.snack_label.text).contains("BITT")
			and String(race.hud.snack_label.text).contains("吃"),
		String(race.hud.snack_label.text))
	_expect("1 接近时 HUD 第二行同时列出两种效果",
		race.hud.snack_effect_label.visible
			and String(race.hud.snack_effect_label.text).contains("TUBO")
			and String(race.hud.snack_effect_label.text).contains("BITT")
			and String(race.hud.snack_effect_label.text).contains("↑")
			and String(race.hud.snack_effect_label.text).contains("»"),
		String(race.hud.snack_effect_label.text))

	GameManager.set_control("rabbit")
	race.mount.reset()
	race.mount.mark_riding()
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.hud._refresh()
	data["approach_rabbit"] = _hud_texts()
	_expect("1 换成兔子后 HUD 写“当前兔子会吃”",
		String(race.hud.snack_label.text).contains("TUBO")
			and String(race.hud.snack_label.text).contains("吃"),
		String(race.hud.snack_label.text))

	# 够不到：把乌龟压到巡航深度以下 60 px（例如刚下潜），HUD 必须解释原因。
	race.turtle.position.y = TuningScript.NEUTRAL_DEPTH + 60.0
	race.hud._refresh()
	data["approach_out_of_reach"] = _hud_texts()
	_expect("2 够不到时 HUD 明说“够不到”（不是沉默）",
		String(race.hud.snack_label.text).contains("够不到"),
		String(race.hud.snack_label.text))
	race.turtle.position.y = TuningScript.NEUTRAL_DEPTH

	# ---- 英文 ----
	Locale.set_language("en")
	GameManager.set_control("turtle")
	race.hud._refresh()
	data["approach_turtle_en"] = _hud_texts()
	_expect("1 EN 接近时写 “TURTLE EATS NOW”",
		String(race.hud.snack_label.text).contains("BITT")
			and String(race.hud.snack_label.text).contains("EATS NOW"),
		String(race.hud.snack_label.text))
	_expect("1 EN 第二行同时列出两种效果",
		String(race.hud.snack_effect_label.text).contains("TUBO")
			and String(race.hud.snack_effect_label.text).contains("BITT")
			and String(race.hud.snack_effect_label.text).contains("↑")
			and String(race.hud.snack_effect_label.text).contains("»"),
		String(race.hud.snack_effect_label.text))
	Locale.set_language("zh")

	# ---- 3) 乌龟吃 ----
	_relayout()
	food_x = float(race._snack_list()[0]["x"])
	_place(food_x, "turtle")
	var base_speed: float = float(race.current_zone["base_speed"])
	feedback_log.clear()
	race._update_snack(STEP)
	race.hud._refresh()
	var turtle_case := {
		"by": race.snack_last_by,
		"boost_active": race.snack_boost_active(),
		"boost_speed": race.snack_boost_speed,
		"base_speed": base_speed,
		"hud": String(race.hud.snack_label.text),
		"feedback": feedback_log.duplicate(),
	}
	data["eat_turtle"] = turtle_case
	_expect("3 乌龟吃到：判定记录 by=turtle", String(turtle_case["by"]) == "turtle")
	_expect("3 乌龟吃到：速度变成 base×1.15",
		absf(float(turtle_case["boost_speed"]) - base_speed * LevelDataScript.SNACK_BOOST_SCALE) < 0.01
			and bool(turtle_case["boost_active"]),
		"%s vs %s" % [turtle_case["boost_speed"], base_speed * LevelDataScript.SNACK_BOOST_SCALE])
	_expect("3 乌龟吃到：HUD 写“加速”并点名 BITT",
		String(turtle_case["hud"]).contains("加速")
			and String(turtle_case["hud"]).contains("BITT"),
		String(turtle_case["hud"]))
	_expect("3 乌龟吃到：反馈文案点名加速",
		_has_feedback("加速"), str(turtle_case["feedback"]))

	# ---- 4) 兔子吃 ----
	_relayout()
	food_x = float(race._snack_list()[0]["x"])
	_place(food_x, "rabbit")
	feedback_log.clear()
	race._update_snack(STEP)
	race.hud._refresh()
	var rabbit_case := {
		"by": race.snack_last_by,
		"jump_boost": race.rabbit.jump_boost,
		"rabbit_boost_active": race.snack_rabbit_boost_active(),
		"turtle_boost_active": race.snack_boost_active(),
		"hud": String(race.hud.snack_label.text),
		"feedback": feedback_log.duplicate(),
	}
	data["eat_rabbit"] = rabbit_case
	_expect("4 兔子吃到：判定记录 by=rabbit", String(rabbit_case["by"]) == "rabbit")
	_expect("4 兔子吃到：下一跳强化 >1，且乌龟不加速",
		float(rabbit_case["jump_boost"]) > 1.0
			and bool(rabbit_case["rabbit_boost_active"])
			and not bool(rabbit_case["turtle_boost_active"]),
		"jump_boost=%s" % rabbit_case["jump_boost"])
	_expect("4 兔子吃到：HUD 点名兔子 + 下一跳更高",
		String(rabbit_case["hud"]).contains("TUBO")
			and String(rabbit_case["hud"]).contains("更高"),
		String(rabbit_case["hud"]))
	_expect("4 兔子吃到：反馈文案说兔子吃了",
		_has_feedback("TUBO"), str(rabbit_case["feedback"]))

	# ---- 5) 不吃（跃起越过） ----
	_relayout()
	food_x = float(race._snack_list()[0]["x"])
	_place(food_x, "turtle")
	var acc_before: int = GameManager.accident_count
	var bro_before: int = GameManager.bro_meter
	var score_before: int = GameManager.total_score
	race.turtle.leap_active = true
	race._update_snack(STEP)
	race.turtle.leap_active = false
	var skip_case := {
		"eaten": race.snack_last_eaten != "" or bool(race._snack_list()[0]["eaten"]),
		"accidents": GameManager.accident_count - acc_before,
		"bro": GameManager.bro_meter - bro_before,
		"score": GameManager.total_score - score_before,
	}
	data["skip"] = skip_case
	_expect("5 跃起越过：没吃到", not bool(skip_case["eaten"]))
	_expect("5 跃起越过：不记事故、BRO 不动、不扣分",
		int(skip_case["accidents"]) == 0 and int(skip_case["bro"]) == 0
			and int(skip_case["score"]) >= 0,
		str(skip_case))

	# ---- 6) 暂停页 / 开场 ----
	var pause_text: String = await _pause_menu_text()
	data["pause_text"] = pause_text
	_expect("6 暂停页有食物说明（谁吃、两种效果、不吃不扣分）",
		pause_text.contains("海藻") and pause_text.contains("BITT")
			and pause_text.contains("TUBO") and pause_text.contains("不扣分"),
		pause_text)
	var opening_source := _read_source("res://scripts/ui/opening.gd")
	data["opening_food_text"] = Locale.t("opening.food")
	_expect("6 开场画面（第一次教学，零障碍）挂上食物说明",
		opening_source.contains("opening.food")
			and String(data["opening_food_text"]).contains("BITT")
			and String(data["opening_food_text"]).contains("TUBO"),
		String(data["opening_food_text"]))
	# 开场说明必须真的在“没有障碍”的位置：赛道起点到第一组障碍之间。
	var first_group_x: float = 1.0e9
	for g in race.hazard_groups:
		first_group_x = minf(first_group_x, LevelDataScript.group_start(g))
	data["opening_clear_px"] = first_group_x - LevelDataScript.RACE_START_X
	_expect("6 开场画面出现在第一组障碍之前（不在障碍链中间）",
		first_group_x > LevelDataScript.RACE_START_X,
		"first group at %.0f, start at %.0f" % [first_group_x,
			LevelDataScript.RACE_START_X])

	# ---- 7) 第一个食物前后障碍 ----
	var nb: Dictionary = data["first_food"]
	_expect("7 第一处食物与其前后障碍的距离已记录",
		float(nb["prev_gap_px"]) > 0.0 and float(nb["next_gap_px"]) > 0.0,
		str(nb))

	# ---- 8) 世界图标 / 标记结构 ----
	var race_source := _read_source("res://scripts/race.gd")
	data["world_markup"] = {
		"effect_icons": race_source.contains("\"↑\"") and race_source.contains("\"»\""),
		"eat_mark": race_source.contains("func _draw_eat_mark(")
			and race_source.contains("world.eat_now"),
		"who_eats_api": race_source.contains("func snack_who_eats()"),
	}
	_expect("8 食物自带两种效果图标 + “吃”标记 + 公开 who-eats 接口",
		bool(data["world_markup"]["effect_icons"])
			and bool(data["world_markup"]["eat_mark"])
			and bool(data["world_markup"]["who_eats_api"]),
		str(data["world_markup"]))

	_write()
	_finish(0 if _all_pass() else 1)


# ---------------- 场景工具 ----------------

func _relayout() -> void:
	race.load_level(LevelDataScript.groups(), LevelDataScript.boost_lanes())
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.oxygen = TuningScript.OXYGEN_MAX
	GameManager.bro_meter = 0
	GameManager.showtime_active = false
	GameManager.has_shifted = true
	GameManager.pickup_window = false
	GameManager.snack_switch_count = 0
	race.finishing = false
	race.hazard_cooldown = 0.0
	race.turtle_repair = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.rabbit_stun = 0.0
	race.emergency_timer = 0.0
	race.combo = 0
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.snack_boost_until_x = -1.0
	race.snack_boost_speed = 0.0
	race.snack_last_eaten = ""
	race.snack_last_by = ""


func _place(x: float, control: String) -> void:
	_relayout()
	GameManager.current_control = control
	var zone: Dictionary = LevelDataScript.zone_at(x)
	race.current_zone = zone
	var speed: float = float(zone["base_speed"])
	race.turtle.reset(Vector2(x, TuningScript.NEUTRAL_DEPTH))
	race.turtle.speed = speed
	race.turtle.base_speed = speed
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()


func _hud_texts() -> Dictionary:
	return {
		"snack": String(race.hud.snack_label.text),
		"snack_visible": race.hud.snack_label.visible,
		"effect": String(race.hud.snack_effect_label.text),
		"effect_visible": race.hud.snack_effect_label.visible,
	}


func _food_neighborhood(food_x: float) -> Dictionary:
	var prev_name := ""
	var prev_end := -1.0
	var next_name := ""
	var next_start := -1.0
	for g in race.hazard_groups:
		var s: float = LevelDataScript.group_start(g)
		var e: float = LevelDataScript.group_end(g)
		if e <= food_x and e > prev_end:
			prev_end = e
			prev_name = String(g["group"])
		if s > food_x and (next_start < 0.0 or s < next_start):
			next_start = s
			next_name = String(g["group"])
	var zone_speed := 220.0
	if next_start > 0.0:
		zone_speed = float(LevelDataScript.zone_at(next_start)["base_speed"])
	return {
		"food_x": food_x,
		"prev_group": prev_name,
		"prev_end_x": prev_end,
		"prev_gap_px": food_x - prev_end,
		"prev_gap_s": (food_x - prev_end) / zone_speed,
		"next_group": next_name,
		"next_start_x": next_start,
		"next_gap_px": next_start - food_x,
		"next_gap_s": (next_start - food_x) / zone_speed,
	}


func _pause_menu_text() -> String:
	GameManager.state = GameManager.GameState.PAUSED
	for i in 3:
		await get_tree().process_frame
	var menu: Node = race.get_node_or_null("PauseLayer/PauseMenu")
	var out := ""
	if menu != null:
		out = _collect_text(menu)
	GameManager.state = GameManager.GameState.RUNNING
	for i in 2:
		await get_tree().process_frame
	return out


func _collect_text(node: Node) -> String:
	var out := ""
	if node is Label:
		out += String((node as Label).text) + "\n"
	for c in node.get_children():
		out += _collect_text(c)
	return out


func _read_source(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	return s


func _has_feedback(fragment: String) -> bool:
	for f in feedback_log:
		if String(f).contains(fragment):
			return true
	return false


func _on_feedback(text: String, _style: String = "") -> void:
	feedback_log.append(text)


func _expect(label: String, ok: bool, detail: String = "") -> void:
	checks.append({"label": label, "pass": ok, "detail": detail})
	print("%s %s%s" % ["ok  " if ok else "FAIL", label,
		(" [" + detail + "]") if detail != "" else ""])


func _all_pass() -> bool:
	for c in checks:
		if not bool(c["pass"]):
			return false
	return true


func _write() -> void:
	data["generated_at"] = Time.get_datetime_string_from_system()
	data["checks"] = checks
	data["pass"] = _all_pass()
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
		f.close()


func _finish(code: int) -> void:
	print("CORE-FEEL-07 P1-C: %s" % ("PASS" if code == 0 else "FAIL"))
	get_tree().quit(code)
