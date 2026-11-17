extends Node
## TBB-EXPERIENCE-REBUILD-05 C：双角色引导条与协作时机提示的验收探针。
##
## 不新建 UI：直接驱动正式 `race.tscn` 里的 HUD（`scripts/ui/hud.gd`）。
## 判定：预警范围边界、准备/现在/错过三态、错过明确结束、角色行、
## 双向控制、落水待接应、中英文不溢出。
##
## 输出：docs/reports/longrun/rebuild05-c-hud.json
## 运行：godot --headless --path TURBBIT res://scenes/stage5_c_hud.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/rebuild05-c-hud.json"

var is_runner := false
var race: Node = null
var out := {}
var failures: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage5CHudRunner"
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
		push_error("C HUD: no race/HUD")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()

	out["generated_at"] = Time.get_datetime_string_from_system()
	out["cases"] = []
	_case_log_window()
	_case_wall_window()
	_case_control_and_rescue()
	_case_language()
	_write()
	print("C HUD: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


# ---------------------------------------------------------------- 浮木 / BRO DIVE

func _case_log_window() -> void:
	var g := _group("log1")
	_reset_at(LevelData.group_start(g) - 600.0, LevelData.zone_at(LevelData.group_start(g)))
	var rows := []
	# 600 px：范围外，整行不该出现
	rows.append(_at("600 outside", LevelData.group_start(g) - 600.0))
	# 500 px：准备
	rows.append(_at("500 prepare", LevelData.group_start(g) - 500.0))
	# 300 / 200 / 80：有效
	rows.append(_at("300 open", LevelData.group_start(g) - 300.0))
	rows.append(_at("200 now", LevelData.group_start(g) - 200.0))
	rows.append(_at("80 close", LevelData.group_start(g) - 80.0))
	# 60 px：已错过（还来得及看到，但已经不能按标准时机起跳）
	rows.append(_at("60 missed", LevelData.group_start(g) - 60.0))
	out["cases"].append({"case": "dive_window", "group": "log1", "rows": rows})

	_expect("dive: 600 px is out of range", not bool(rows[0]["visible"]))
	_expect("dive: 500 px is prepare (%s)" % rows[1]["phase"], rows[1]["phase"] == "prepare")
	_expect("dive: 300 px is valid (%s)" % rows[2]["phase"], rows[2]["phase"] == "now")
	_expect("dive: 200 px is valid (%s)" % rows[3]["phase"], rows[3]["phase"] == "now")
	_expect("dive: 80 px is still valid (%s)" % rows[4]["phase"], rows[4]["phase"] == "now")
	_expect("dive: 60 px is missed (%s)" % rows[5]["phase"], rows[5]["phase"] == "missed")
	_expect("dive: label names BRO DIVE (%s)" % rows[3]["label"],
		String(rows[3]["label"]).contains(Locale.t("combo.bro_dive")))
	_expect("dive: rabbit row offers the chance (%s)" % rows[3]["rabbit"],
		String(rows[3]["rabbit"]).length() > 0)
	_expect("dive: turtle row says assist only (%s)" % rows[3]["turtle"],
		String(rows[3]["turtle"]).length() > 0)
	# 条形单调：越近越满
	var pcts: Array = []
	for r in rows:
		pcts.append(float(r["pct"]))
	var mono := true
	for i in range(1, pcts.size()):
		if float(pcts[i]) < float(pcts[i - 1]):
			mono = false
	_expect("dive: bar fills monotonically %s" % str(pcts), mono)
	# 通过后立刻结束
	race.passed_groups[String(g["group"])] = true
	race.hud._refresh()
	_expect("dive: passed group hides the row", not race.hud.coop_bar.visible)
	race.passed_groups.erase(String(g["group"]))


# ---------------------------------------------------------------- 高墙 / BRO OLLIE

func _case_wall_window() -> void:
	var g := _group("wall1")
	_reset_at(LevelData.group_start(g) - 200.0, LevelData.zone_at(LevelData.group_start(g)))
	var r := _at("200 now", LevelData.group_start(g) - 200.0)
	out["cases"].append({"case": "ollie_window", "group": "wall1", "rows": [r]})
	_expect("ollie: 200 px is valid (%s)" % r["phase"], r["phase"] == "now")
	_expect("ollie: label names BRO OLLIE (%s)" % r["label"],
		String(r["label"]).contains(Locale.t("combo.bro_ollie")))
	_expect("ollie: turtle row is the actor (%s)" % r["turtle"],
		String(r["turtle"]).contains(Locale.t("combo.bro_ollie")))
	_expect("ollie: rabbit row says assist (%s)" % r["rabbit"],
		not String(r["rabbit"]).contains(Locale.t("combo.bro_ollie")))


# ---------------------------------------------------------------- 控制权 / 接应

func _case_control_and_rescue() -> void:
	var g := _group("log1")
	_reset_at(LevelData.group_start(g) - 200.0, LevelData.zone_at(LevelData.group_start(g)))
	var rows := {}

	GameManager.current_control = "rabbit"
	race.hud._refresh()
	rows["rabbit_control"] = {
		"rabbit": race.hud.rabbit_status.text,
		"turtle": race.hud.turtle_status.text,
	}
	GameManager.current_control = "turtle"
	race.hud._refresh()
	rows["turtle_control"] = {
		"rabbit": race.hud.rabbit_status.text,
		"turtle": race.hud.turtle_status.text,
	}

	GameManager.accident_state = "RABBIT_WATER"
	race.mount.mark_rescue_active(Tuning.RESCUE_ACTIVE_TIME)
	race.hud._refresh()
	rows["rabbit_water"] = {
		"rabbit": race.hud.rabbit_status.text,
		"turtle": race.hud.turtle_status.text,
		"coop": bool(race.hud.coop_bar.visible),
	}

	out["cases"].append({"case": "control_and_rescue", "rows": rows})
	_expect("control: rabbit row says DRIVING in zh (%s)" % rows["rabbit_control"]["rabbit"],
		String(rows["rabbit_control"]["rabbit"]).contains("骑乘"))
	_expect("control: turtle row says standby (%s)" % rows["rabbit_control"]["turtle"],
		String(rows["rabbit_control"]["turtle"]).contains("待命"))
	_expect("control: turtle row says DRIVING after shift (%s)"
		% rows["turtle_control"]["turtle"],
		String(rows["turtle_control"]["turtle"]).contains("巡航"))
	_expect("rescue: rabbit row says wait for catch (%s)" % rows["rabbit_water"]["rabbit"],
		String(rows["rabbit_water"]["rabbit"]).contains("等接应"))
	_expect("rescue: turtle row says rescuing (%s)" % rows["rabbit_water"]["turtle"],
		String(rows["rabbit_water"]["turtle"]).contains("救援"))
	_expect("rescue: coop row is suppressed during an accident",
		not bool(rows["rabbit_water"]["coop"]))

	GameManager.accident_state = "NONE"
	race.mount.mark_riding()
	GameManager.current_control = "rabbit"


# ---------------------------------------------------------------- 中英文

func _case_language() -> void:
	var g := _group("log1")
	_reset_at(LevelData.group_start(g) - 200.0, LevelData.zone_at(LevelData.group_start(g)))
	var rows := {}
	for lang in ["zh", "en"]:
		Locale.language = lang
		race.hud._refresh()
		# 新出现的行要多量一次：第一次取 minimum_size 时子节点还没重排完。
		race.hud._layout()
		race.hud._layout()
		var panel: Control = race.hud._panels["tl"]
		rows[lang] = {
			"label": _actor_line(),
			"rabbit": race.hud.rabbit_coop.text,
			"turtle": race.hud.turtle_coop.text,
			"panel": [panel.size.x, panel.size.y],
			"min": [panel.get_combined_minimum_size().x,
				panel.get_combined_minimum_size().y],
		}
	Locale.language = "zh"
	out["cases"].append({"case": "language", "rows": rows})
	for lang in ["zh", "en"]:
		var r: Dictionary = rows[lang]
		_expect("%s: coop label is non-empty (%s)" % [lang, r["label"]],
			String(r["label"]).length() > 0)
		var fits: bool = float(r["panel"][0]) + 0.5 >= float(r["min"][0]) \
			and float(r["panel"][1]) + 0.5 >= float(r["min"][1])
		_expect("%s: top-left panel fits its text (%s >= %s)" % [lang, r["panel"], r["min"]],
			fits)
		# 提示出现时最容易超预算——用正式 HUD 的四块面板实测总面积。
		var area := 0.0
		for c in race.hud._panels:
			var p: Control = race.hud._panels[c]
			if p.visible:
				area += p.size.x * p.size.y
		var vp := get_viewport().get_visible_rect().size
		var pct := area / (vp.x * vp.y)
		_expect("%s: panels stay under 8%% with the hint visible (%.2f%%)" % [
			lang, pct * 100.0], pct <= 0.08)


# ---------------------------------------------------------------- 工具

func _group(name: String) -> Dictionary:
	for g in race.hazard_groups:
		if String(g["group"]) == name:
			return g
	return {}


## 把乌龟挪到指定 x，刷新一次 HUD，读出这一帧的所有提示状态。
func _at(tag: String, x: float) -> Dictionary:
	race.turtle.position.x = x
	race.hud._refresh()
	race.hud._layout()
	var shown: bool = race.hud.coop_bar.visible
	return {
		"tag": tag,
		"visible": shown,
		"label": _actor_line(),
		"pct": float(race.hud.coop_bar.value) if shown else 0.0,
		"phase": String(race.hud._coop_target().get("phase", "")) if shown else "",
		"rabbit": race.hud.rabbit_coop.text if race.hud.rabbit_coop.visible else "",
		"turtle": race.hud.turtle_coop.text if race.hud.turtle_coop.visible else "",
	}


func _actor_line() -> String:
	# 行动方那行带连招名，配合方只有“配合”；优先取带 BRO 的那行。
	var r: String = String(race.hud.rabbit_coop.text).strip_edges() \
		if race.hud.rabbit_coop.visible else ""
	var t: String = String(race.hud.turtle_coop.text).strip_edges() \
		if race.hud.turtle_coop.visible else ""
	if r.contains("BRO") or r.contains("兄弟"):
		return r
	if t.contains("BRO") or t.contains("兄弟"):
		return t
	return r if r != "" else t


func _reset_at(x: float, zone: Dictionary) -> void:
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.current_control = "rabbit"
	GameManager.oxygen = Tuning.OXYGEN_MAX
	race.mount.mark_riding()
	race.showtime_active = false
	# G20：hit_roles 必须和 hit_groups 一起清。只清 hit_groups 时，B2 起的“角色×组”记账还留着，同组第二例起整组免疫——后面那些重复用例其实在测一段不会撞的赛道。
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.turtle.reset(Vector2(x, Tuning.NEUTRAL_DEPTH))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.current_zone = zone
	race.hud._refresh()
	race.hud._layout()


func _expect(label: String, ok: bool) -> void:
	if not ok:
		failures.append(label)


func _write() -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f == null:
		push_error("C HUD: cannot write " + OUT_PATH)
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()
