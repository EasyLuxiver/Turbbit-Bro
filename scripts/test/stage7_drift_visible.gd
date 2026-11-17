extends Node
## CORE-FEEL-07 P1-D — 神游可见性验证（headless，真实 brain / 真实 HUD / 真实控制器）
##
## 用户试玩原话：“神游满值没惩罚”“仪表说会惹麻烦但看不出会发生什么”。
## 本探针只核对“看得懂、看得出、能恢复”，不改数值、不加第二套生命值：
##   1) HUD 按角色显示程度（条）与具体后果（空中修正/身偏 · 巡航/壳晃）；
##   2) 越过 6 s / 9 s 阈值各报警一次，提示里点名角色并写出当前代价；
##   3) 满值（12 s）动作可辨认：兔子耳朵下垂、乌龟划水、标记升为 "!!"；
##   4) 恢复可见：受控后条在缩、条旁“回神中”的代价数字在变好，回到 CALM 报一次；
##   5) 不强制换手、不锁输入、不进入不可恢复状态；不写 BRO、不产生事故；
##   6) 满值状态下 HUD 面积与字号仍达标（中英文各测一次）。
##
## 用法：
##   D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
##       res://scenes/stage7_drift_visible.tscn > docs/reports/logs/core-feel-07-p1d.log 2>&1
##
## 输出：docs/reports/longrun/core-feel-07-drift-visible.json
## 窗口化运行时会另存 screenshots/core-feel-07-drift-*.png 供人工核对。

const LevelDataScript = preload("res://scripts/systems/level_data.gd")
const TuningScript = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/core-feel-07-drift-visible.json"
const STEP := 1.0 / 60.0
const MIN_ACTUAL_PX := 14.0
const AREA_LIMIT := 0.08

var is_runner := false
var race: Node = null
var checks: Array = []
var data := {}
var feedback_log: Array = []
var warn_log: Array = []
var sim := 0.0


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
	Locale.set_language("zh")
	GameManager.start_race()
	for i in 4:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null or race.hud == null:
		push_error("P1D: no race scene")
		_finish(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = true
	GameManager.feedback.connect(_on_feedback)
	race.load_level(LevelDataScript.groups(), LevelDataScript.boost_lanes())
	await get_tree().physics_frame
	# 只看神游本身：清掉障碍与食物，避免碰撞/连击/Showtime 冻结神游时钟。
	race.hazard_groups = []
	race.entered_groups.clear()
	race.boost_lanes = []
	race._snack_cache_sig = -1
	race._snack_cache = []

	data["hud_rabbit"] = _hud_consequence_case("rabbit")
	data["hud_turtle"] = _hud_consequence_case("turtle")
	data["rabbit_thresholds"] = _threshold_case("rabbit")
	data["turtle_thresholds"] = _threshold_case("turtle")
	data["full_pose"] = _full_pose_case()
	data["recovery"] = _recovery_case()
	data["no_trap"] = _no_trap_case()
	data["hud_stress"] = _hud_stress_case()
	data["source_markup"] = _source_markup()

	if DisplayServer.get_name() != "headless":
		await _shots()

	_write()
	_finish(0 if _all_pass() else 1)


# ---------------- 1) HUD：程度 + 具体后果 ----------------

func _hud_consequence_case(who: String) -> Dictionary:
	var other := "turtle" if who == "rabbit" else "rabbit"
	race.reset_brains()
	GameManager.set_control(other)
	_set_drift(who, TuningScript.DRIFT_CAP)
	race.hud._refresh()
	var bar: ProgressBar = race.hud.rabbit_drift_bar if who == "rabbit" \
		else race.hud.turtle_drift_bar
	var row: Control = race.hud.rabbit_drift_row if who == "rabbit" \
		else race.hud.turtle_drift_row
	var status: Label = race.hud.rabbit_status if who == "rabbit" \
		else race.hud.turtle_status
	var effect: Label = race.hud.rabbit_drift_effect if who == "rabbit" \
		else race.hud.turtle_drift_effect
	var body = race.rabbit if who == "rabbit" else race.turtle
	var want_air := int(round(body.drift_air_scale() * 100.0)) if who == "rabbit" else 0
	var want_off := int(round(body.drift_offset_amp_px())) if who == "rabbit" else 0
	var want_cruise := int(round(body.drift_speed_scale(false) * 100.0)) \
		if who == "turtle" else 0
	var want_bob := int(round(body.drift_bob_amp_px(false))) if who == "turtle" else 0
	var out := {
		"status": String(status.text),
		"effect": String(effect.text),
		"bar_value": snappedf(bar.value, 0.01),
		"row_visible": row.visible,
		"drift": snappedf(float(_brain(who).drift), 0.01),
	}
	_expect("1 %s 满值时 HUD 显示神游条（100%%）" % who,
		bool(out["row_visible"]) and absf(float(out["bar_value"]) - 100.0) < 0.01,
		str(out["bar_value"]))
	_expect("1 %s 状态行点名“过载”，条旁写明具体后果" % who,
		String(out["status"]).contains("过载")
			and not String(out["effect"]).contains("px")
			and String(out["effect"]).contains("%"),
		"%s | %s" % [out["status"], out["effect"]])
	if who == "rabbit":
		_expect("1 兔子后果 = 空中修正 55% + 落点偏（读控制器真实值）",
			String(out["effect"]).contains("空中修正 %d%%" % want_air)
				and String(out["effect"]).contains("落点偏")
				and not String(out["effect"]).contains("px")
				and want_air == 55,
			"air=%d off=%d text=%s" % [want_air, want_off, out["effect"]])
	else:
		_expect("1 乌龟后果 = 速度 90% + 壳在晃（读控制器真实值）",
			String(out["effect"]).contains("速度 %d%%" % want_cruise)
				and String(out["effect"]).contains("壳在晃")
				and not String(out["effect"]).contains("px")
				and want_cruise == 90 and want_bob == 18,
			"cruise=%d bob=%d text=%s" % [want_cruise, want_bob, out["effect"]])
	return out


# ---------------- 2) 阈值报警 ----------------

func _threshold_case(who: String) -> Dictionary:
	race.reset_brains()
	GameManager.set_control("turtle" if who == "rabbit" else "rabbit")
	feedback_log.clear()
	warn_log.clear()
	sim = 0.0
	for i in 12 * 60:
		_step()
	var warnings: Array = warn_log.duplicate()
	var restless := {}
	var mischief := {}
	for w in warnings:
		if String(w["text"]).contains("发麻"):
			restless = w
		elif String(w["text"]).contains("过载"):
			mischief = w
	var drift: float = float(_brain(who).drift)
	var out := {
		"warnings": warnings,
		"restless_t": float(restless.get("t", -1.0)),
		"mischief_t": float(mischief.get("t", -1.0)),
		"drift": snappedf(drift, 0.01),
	}
	_expect("2 %s 6 s 阈值报警一次（%.2f s）" % [who, float(out["restless_t"])],
		not restless.is_empty() and absf(float(out["restless_t"]) - 6.0) <= 0.2,
		str(warnings))
	_expect("2 %s 9 s 阈值报警一次（%.2f s）" % [who, float(out["mischief_t"])],
		not mischief.is_empty() and absf(float(out["mischief_t"]) - 9.0) <= 0.2,
		str(warnings))
	_expect("2 报警点名角色并写出代价（不是只说“要惹麻烦”）",
		not mischief.is_empty()
			and String(mischief["text"]).contains(Locale.t("who." + who))
			and not String(mischief["text"]).contains("px"),
		String(mischief.get("text", "")))
	_expect("2 报告只有两条（升级才报，不刷屏）", warnings.size() == 2,
		str(warnings.size()))
	_expect("2 %s 12 s 到达满值" % who, drift >= TuningScript.DRIFT_CAP - 0.001,
		"%.2f" % drift)
	return out


# ---------------- 3) 满值动作 ----------------

func _full_pose_case() -> Dictionary:
	race.reset_brains()
	GameManager.set_control("rabbit")
	_set_drift("rabbit", TuningScript.DRIFT_CAP)
	_set_drift("turtle", TuningScript.DRIFT_CAP)
	race.hud._refresh()
	var out := {
		"rabbit_mark": race.drift_mark_text("rabbit"),
		"turtle_mark": race.drift_mark_text("turtle"),
		"rabbit_ears_droop": snappedf(race.rabbit_ears_droop(), 0.01),
		"turtle_paddle": snappedf(race.turtle_paddle_strength(), 0.01),
		"rabbit_bar": snappedf(race.hud.rabbit_drift_bar.value, 0.01),
		"turtle_bar": snappedf(race.hud.turtle_drift_bar.value, 0.01),
		"rabbit_status": String(race.hud.rabbit_status.text),
		"turtle_status": String(race.hud.turtle_status.text),
		"rabbit_effect": String(race.hud.rabbit_drift_effect.text),
		"turtle_effect": String(race.hud.turtle_drift_effect.text),
	}
	_expect("3 兔子满值：标记 !! + 耳朵下垂（>=1.1 rad）",
		String(out["rabbit_mark"]) == "!!" and float(out["rabbit_ears_droop"]) >= 1.1,
		"mark=%s droop=%s" % [out["rabbit_mark"], out["rabbit_ears_droop"]])
	_expect("3 乌龟满值：标记 !! + 划水强度满（1.0）",
		String(out["turtle_mark"]) == "!!" and absf(float(out["turtle_paddle"]) - 1.0) < 0.01,
		"mark=%s paddle=%s" % [out["turtle_mark"], out["turtle_paddle"]])
	_expect("3 两条神游条都满（100%）",
		absf(float(out["rabbit_bar"]) - 100.0) < 0.01
			and absf(float(out["turtle_bar"]) - 100.0) < 0.01,
		"%s / %s" % [out["rabbit_bar"], out["turtle_bar"]])
	_expect("3 受控方状态也写出恢复中的代价（不隐瞒受控后的余波）",
		String(out["rabbit_effect"]).contains("回神中")
			and String(out["rabbit_effect"]).contains("空中修正"),
		"%s | %s" % [out["rabbit_status"], out["rabbit_effect"]])
	# 满值不等于新状态："MISCHIEF" 仍是最高一档，不改大脑分段/阈值。
	_expect("3 满值仍属 MISCHIEF 档（没有新增第五段）",
		race.rabbit_brain.state_name() == "MISCHIEF"
			and race.turtle_brain.state_name() == "MISCHIEF",
		"%s / %s" % [race.rabbit_brain.state_name(), race.turtle_brain.state_name()])
	return out


# ---------------- 4) 恢复可见 ----------------

func _recovery_case() -> Dictionary:
	race.reset_brains()
	GameManager.set_control("turtle")
	_set_drift("rabbit", TuningScript.DRIFT_CAP)
	_set_drift("turtle", 0.0)
	GameManager.set_control("rabbit")
	race.hud._refresh()
	var bar_before: float = race.hud.rabbit_drift_bar.value
	var text_before := String(race.hud.rabbit_status.text)
	var effect_before := String(race.hud.rabbit_drift_effect.text)
	# 0.5 s 站稳之后才开始回落：先走 0.5 s，再走 1.0 s。
	for i in 30:
		_step()
	for i in 60:
		_step()
	race.hud._refresh()
	var bar_mid: float = race.hud.rabbit_drift_bar.value
	var text_mid := String(race.hud.rabbit_status.text)
	var effect_mid := String(race.hud.rabbit_drift_effect.text)
	var drift_mid: float = float(race.rabbit_brain.drift)
	feedback_log.clear()
	var frames := 0
	while race.rabbit_brain.drift > 0.0001 and frames < 900:
		_step()
		frames += 1
	race.hud._refresh()
	var out := {
		"bar_before": snappedf(bar_before, 0.01),
		"bar_mid": snappedf(bar_mid, 0.01),
		"text_before": text_before,
		"text_mid": text_mid,
		"effect_before": effect_before,
		"effect_mid": effect_mid,
		"drift_mid": snappedf(drift_mid, 0.01),
		"bar_after": snappedf(race.hud.rabbit_drift_bar.value, 0.01),
		"row_after": race.hud.rabbit_drift_row.visible,
		"status_after": String(race.hud.rabbit_status.text),
		"recover_seconds": snappedf(frames * STEP, 0.01),
		"back_feedback": _find_feedback("回过神"),
		"control": GameManager.current_control,
	}
	_expect("4 受控后条开始缩（100 -> %.0f%%)" % float(out["bar_mid"]),
		float(out["bar_mid"]) < float(out["bar_before"]) - 5.0,
		str(out))
	_expect("4 受控后条旁写“回神中”且代价数字变好",
		String(out["effect_mid"]).contains("回神中")
			and String(out["effect_mid"]).contains("空中修正")
			and String(out["effect_mid"]) != String(out["effect_before"]),
		"%s | %s -> %s" % [out["text_mid"], out["effect_before"],
			out["effect_mid"]])
	_expect("4 回满后条消失、播一次“回过神了”",
		not bool(out["row_after"])
			and String(out["back_feedback"]).contains("回过神"),
		"%s / row=%s / back=%s" % [out["status_after"], out["row_after"],
			out["back_feedback"]])
	_expect("4 恢复时长在 2–7 s（渐变，不是瞬清）",
		float(out["recover_seconds"]) >= 2.0 and float(out["recover_seconds"]) <= 7.0,
		str(out["recover_seconds"]))
	_expect("4 恢复过程没有强制换手", String(out["control"]) == "rabbit",
		String(out["control"]))
	return out


# ---------------- 5) 不锁输入 / 不可恢复 / 无事故 ----------------

func _no_trap_case() -> Dictionary:
	race.reset_brains()
	GameManager.set_control("turtle")
	var bro0: int = GameManager.bro_meter
	var acc0: int = GameManager.accident_count
	var state0: String = GameManager.accident_state
	# 12 s 兔子没人管 + 12 s 乌龟没人管：24 s 完全不干预，不产生惩罚性结算。
	for i in 12 * 60:
		_step()
	GameManager.set_control("rabbit")
	for i in 12 * 60:
		_step()
	var control_after := GameManager.current_control
	var still_idle := GameManager.accident_state
	# 输入没被锁：SHIFT 照常换人；换回后按住 ↑ 仍然是合法输入（不报错、不拦）。
	GameManager.toggle_control()
	var toggled := GameManager.current_control
	# FEEL-09 P0-C：0.20 s 换手锁定；用同一套手动步进把锁定走完再换回。
	for i in 16:
		_step()
	GameManager.toggle_control()
	var toggled_back := GameManager.current_control
	var out := {
		"bro_delta": GameManager.bro_meter - bro0,
		"accident_delta": GameManager.accident_count - acc0,
		"state_after_idle": String(still_idle),
		"control_stayed": String(control_after),
		"toggled_to": String(toggled),
		"toggled_back": String(toggled_back),
		"rabbit_drift": snappedf(float(race.rabbit_brain.drift), 0.01),
		"turtle_drift": snappedf(float(race.turtle_brain.drift), 0.01),
	}
	_expect("5 24 s 神游不写 BRO、不产生事故（不是第二套生命值）",
		int(out["bro_delta"]) == 0 and int(out["accident_delta"]) == 0
			and String(out["state_after_idle"]) == String(state0),
		str(out))
	_expect("5 神游不会强制换手/锁输入：SHIFT 仍可换人并换回",
		String(out["control_stayed"]) == "rabbit"
			and String(out["toggled_to"]) == "turtle"
			and String(out["toggled_back"]) == "rabbit",
		"%s -> %s -> %s" % [out["control_stayed"], out["toggled_to"],
			out["toggled_back"]])
	_expect("5 24 s 后两人仍可恢复（不是不可恢复状态）",
		float(out["rabbit_drift"]) <= TuningScript.DRIFT_CAP + 0.001
			and float(out["turtle_drift"]) <= TuningScript.DRIFT_CAP + 0.001,
		str(out))
	return out


# ---------------- 6) HUD 面积/字号（满值中英文） ----------------

func _hud_stress_case() -> Dictionary:
	race.reset_brains()
	GameManager.set_control("rabbit")
	_set_drift("rabbit", TuningScript.DRIFT_CAP)
	_set_drift("turtle", TuningScript.DRIFT_CAP)
	race.hud._refresh()
	var out := {}
	for lang in ["zh", "en"]:
		Locale.set_language(lang)
		race.hud._refresh()
		race.hud._layout()
		var mf := _min_actual_font(race.hud)
		var ratio := _panel_area_ratio(race.hud)
		var rects := {}
		for c in ["tl", "tr", "bl", "br"]:
			var rect: Rect2 = race.hud._panels[c].get_global_rect()
			rects[c] = [snappedf(rect.size.x, 0.1), snappedf(rect.size.y, 0.1)]
		out[lang] = {
			"min_design_font": mf["design"],
			"min_actual_font": mf["actual"],
			"min_text": mf["text"],
			"panel_area": snappedf(ratio, 0.0001),
			"panel_rects": rects,
			"rabbit_status": String(race.hud.rabbit_status.text),
			"turtle_status": String(race.hud.turtle_status.text),
			"rabbit_effect": String(race.hud.rabbit_drift_effect.text),
			"turtle_effect": String(race.hud.turtle_drift_effect.text),
		}
	Locale.set_language("zh")
	race.hud._refresh()
	for lang in ["zh", "en"]:
		_expect("6 %s 满值 HUD 字号仍 >= 14 px（实际）" % lang,
			float(out[lang]["min_actual_font"]) >= MIN_ACTUAL_PX,
			"%s (%s)" % [out[lang]["min_actual_font"], out[lang]["min_text"]])
		_expect("6 %s 满值 HUD 面积仍 <= 8%%" % lang,
			float(out[lang]["panel_area"]) <= AREA_LIMIT,
			"%.2f%%" % (float(out[lang]["panel_area"]) * 100.0))
	return out


# ---------------- 7) 画法结构 ----------------

func _source_markup() -> Dictionary:
	var src := _read_source("res://scripts/race.gd")
	var out := {
		"ears_droop": src.contains("func rabbit_ears_droop("),
		"turtle_paddle": src.contains("func turtle_paddle_strength("),
		"full_mark": src.contains("\"!!\""),
		"mark_used_by_draw": src.contains("drift_mark_text(\"turtle\")")
			and src.contains("drift_mark_text(\"rabbit\")"),
		"threshold_feedback": src.contains("feedback.drift_warn_"),
	}
	_expect("7 满值动作/标记/阈值报警都接进真实画法与反馈",
		bool(out["ears_droop"]) and bool(out["turtle_paddle"])
			and bool(out["full_mark"]) and bool(out["mark_used_by_draw"])
			and bool(out["threshold_feedback"]),
		str(out))
	return out


# ---------------- 场景工具 ----------------

func _brain(who: String):
	return race.rabbit_brain if who == "rabbit" else race.turtle_brain


func _set_drift(who: String, value: float) -> void:
	var brain = _brain(who)
	brain.drift = clampf(value, 0.0, TuningScript.DRIFT_CAP)
	var body = race.rabbit if who == "rabbit" else race.turtle
	body.drift = brain.drift
	body.drift_state = brain.state_name()


func _step() -> void:
	race._physics_process(STEP)
	sim += STEP


func _min_actual_font(root: Node) -> Dictionary:
	var scale := 1.0
	var vp := get_viewport().get_visible_rect().size
	scale = minf(vp.x / 1600.0, vp.y / 900.0)
	var min_design := 9999.0
	var min_text := ""
	for c in _visible_labels(root):
		var fs := float(c.get_theme_font_size("font_size"))
		if fs < min_design:
			min_design = fs
			min_text = String(c.text).substr(0, 32)
	return {"design": min_design, "actual": snappedf(min_design * scale, 0.1),
		"text": min_text}


func _visible_labels(root: Node) -> Array:
	var out: Array = []
	if root is Label and (root as Label).is_visible_in_tree() \
			and not String((root as Label).text).is_empty():
		out.append(root)
	for c in root.get_children():
		out.append_array(_visible_labels(c))
	return out


func _panel_area_ratio(hud) -> float:
	var vp := get_viewport().get_visible_rect().size
	var area := 0.0
	for c in ["tl", "tr", "bl", "br"]:
		var panel: Control = hud._panels[c]
		if not panel.visible:
			continue
		var r := panel.get_global_rect()
		area += r.size.x * r.size.y
	return area / (vp.x * vp.y)


func _find_feedback(fragment: String) -> String:
	for f in feedback_log:
		if String(f.get("text", "")).contains(fragment):
			return String(f["text"])
	return ""


func _on_feedback(text: String, kind: String = "") -> void:
	feedback_log.append({"text": text, "kind": kind, "t": sim})
	if feedback_log.size() > 80:
		feedback_log.pop_front()
	if text.contains("发麻") or text.contains("过载"):
		warn_log.append({"text": text, "kind": kind, "t": snappedf(sim, 0.01)})
	if warn_log.size() > 40:
		warn_log.pop_front()


func _read_source(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	return s


func _shots() -> void:
	_set_drift("rabbit", TuningScript.DRIFT_CAP)
	_set_drift("turtle", TuningScript.DRIFT_CAP)
	GameManager.set_control("rabbit")
	race.hud._refresh()
	await _shot("core-feel-07-drift-full-zh.png")
	Locale.set_language("en")
	race.hud._refresh()
	await _shot("core-feel-07-drift-full-en.png")
	Locale.set_language("zh")
	race.hud._refresh()


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(file_name)
	var img := get_viewport().get_texture().get_image()
	if img != null and img.save_png(path) == OK:
		print("SHOT %s (%dx%d)" % [path, img.get_width(), img.get_height()])


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
	print("CORE-FEEL-07 P1-D: %s" % ("PASS" if code == 0 else "FAIL"))
	get_tree().quit(code)
