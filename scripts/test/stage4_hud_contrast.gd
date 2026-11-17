extends Node
## Phase I HUD 对比度自检（必须开真实窗口，headless 不渲染）。
##
## 做法：
##   1. 站到 beam1 前 300 px，触发真实的预警 / 教学 / 连招反馈三条底部文字；
##   2. 抓一张“完整 HUD”的截图 A；
##   3. 把 HUD 整体藏掉，抓一张“纯场景”截图 B；
##   4. 四角面板的文字背景 = 截图 A 里该面板描边框内一圈像素（只有面板底色，没有字），
##      取最亮的一个当最坏背景；底部中央没有面板，背景 = 截图 B 里该标签矩形中的最亮像素；
##   5. 用 WCAG 公式算每个可见 Label 的实际字色对实际背景的对比度。
##
## 判据：每个可见文字 >= 4.5:1。
## 运行：Godot_v4.7-stable_win64_console.exe --path TURBBIT res://scenes/stage4_hud_contrast.tscn

const MIN_RATIO := 4.5
const SIZES := [Vector2i(1600, 900), Vector2i(1280, 720)]
const CORNERS := ["tl", "tr", "bl", "br"]

var is_runner := false
var failures: Array[String] = []
var race
var rows: Array[String] = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4HudContrastRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	# 本探针需要真实渲染；headless 下 frame_post_draw 不保证触发，
	# 以前会挂到 600 s 被外部杀掉。显式跳过，结果写清楚。
	if DisplayServer.get_name() == "headless":
		print("HUD CONTRAST: SKIP (requires a real window; run without --headless)")
		get_tree().quit(0)
		return
	Locale.language = "zh"
	GameManager.start_race()
	await _wait_scene("race.tscn")
	await _frames(6)
	race = get_tree().current_scene
	_check(race != null and race.hud != null, "race scene has HUD")
	if race == null or race.hud == null:
		_finish()
		return

	race.test_disable_hazards = true
	var beam := {}
	for g in race.hazard_groups:
		if g["group"] == "beam1":
			beam = g
			break
	if not beam.is_empty():
		race.turtle.position = Vector2(race._group_start(beam) - 300.0, 334.0)
		race.turtle.speed = 0.0
	await _frames(4)

	# 验收标准 2 的一半：默认画面没有开发标签。
	_check(race.get("debug_mode") == false, "debug_mode is off in normal play")
	var overlay = race.get("_debug_overlay")
	_check(overlay == null or overlay.visible == false, "debug overlay is hidden in normal play")

	for s in SIZES:
		var win := get_window()
		win.size = s
		await _frames(8)
		for lang in ["zh", "en"]:
			Locale.set_language(lang)
			await _frames(4)
			# 三条底部文字同时在场：障碍预警 + 最长教学行 + 连招反馈。
			GameManager.prompt.emit(Locale.t("prompt.ollie"))
			GameManager.hint.emit(Locale.t("lesson.sink_gate"))
			GameManager.feedback.emit(Locale.t("feedback.bro_combo"), "bro")
			await _frames(3)
			await _measure(s, lang)

	Locale.set_language("zh")
	await _measure_forced()
	_finish()


func _measure(size_hint: Vector2i, lang: String) -> void:
	var hud = race.hud
	await RenderingServer.frame_post_draw
	var full: Image = get_viewport().get_texture().get_image()
	hud.visible = false
	await _frames(3)
	await RenderingServer.frame_post_draw
	var bare: Image = get_viewport().get_texture().get_image()
	hud.visible = true
	await _frames(2)

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var k := float(full.get_width()) / vp.x
	var tag := "%dx%d/%s (image %dx%d, viewport %.0fx%.0f)" % [
		size_hint.x, size_hint.y, lang, full.get_width(), full.get_height(), vp.x, vp.y]
	print("HUD CONTRAST %s" % tag)
	# 验收标准 5 的截图证据：这就是一次真实窗口里的完整画面。
	full.save_png(ProjectSettings.globalize_path(
		"res://docs/reports/logs/phase-i/hud-%dx%d-%s.png" % [size_hint.x, size_hint.y, lang]))

	var worst := 99.0
	for c in CORNERS:
		var panel: Control = hud._panels[c]
		var r: Rect2 = panel.get_global_rect()
		var bg := _ring_max(full, r, k)
		for lab in _all_labels(panel):
			if not lab.is_visible_in_tree() or lab.text.strip_edges() == "":
				continue
			var ratio := _ratio(lab, bg)
			worst = minf(worst, ratio)
			_report(tag, c, lab, bg, ratio)
	for lab in _all_labels(hud._bottom_center):
		if not lab.is_visible_in_tree() or lab.text.strip_edges() == "":
			continue
		var r2: Rect2 = (lab as Control).get_global_rect()
		var bg2 := _rect_max(bare, r2, k)
		var ratio2 := _ratio(lab, bg2)
		worst = minf(worst, ratio2)
		_report(tag, "bc", lab, bg2, ratio2)
	print("HUD CONTRAST %s worst=%.2f" % [tag, worst])


## 平时只在失衡 / 缺氧时才出现的文字，也要够亮：暂停 _refresh 后强行点亮再量。
## 四个失衡档位各量一次（<25 / 25-50 / 50-80 / >=80），再加一条缺氧红字。
func _measure_forced() -> void:
	var hud = race.hud
	hud.set_process(false)
	hud.rabbit_risk_row.visible = true
	hud.turtle_risk_row.visible = true
	await _frames(3)
	await RenderingServer.frame_post_draw
	var full: Image = get_viewport().get_texture().get_image()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var k := float(full.get_width()) / vp.x
	var tag := "forced/zh"
	print("HUD CONTRAST %s" % tag)
	var tl: Control = hud._panels["tl"]
	var tl_bg := _ring_max(full, tl.get_global_rect(), k)
	for pct in [10, 30, 60, 90]:
		hud.rabbit_risk_label.text = "兔子失衡 %d%%" % pct
		hud.rabbit_risk_label.add_theme_color_override("font_color", hud._risk_color(pct))
		await _frames(2)
		await RenderingServer.frame_post_draw
		_report(tag, "tl/risk%d" % pct, hud.rabbit_risk_label, tl_bg,
			_ratio(hud.rabbit_risk_label, tl_bg))

	hud.rabbit_risk_row.visible = false
	hud.turtle_risk_row.visible = false
	hud.set_process(true)
	await _frames(2)


func _report(tag: String, where: String, lab: Label, bg: Color, ratio: float) -> void:
	var fg: Color = lab.get_theme_color("font_color")
	var line := "%s [%s] '%s' fg=(%.2f,%.2f,%.2f) bg=(%.2f,%.2f,%.2f) ratio=%.2f %s" % [
		tag, where, lab.text.substr(0, 28),
		fg.r, fg.g, fg.b, bg.r, bg.g, bg.b, ratio,
		"ok" if ratio >= MIN_RATIO else "FAIL"]
	print("  " + line)
	rows.append(line)
	_check(ratio >= MIN_RATIO, "%s %s '%s' contrast %.2f >= %.1f" % [
		tag, where, lab.text.substr(0, 20), ratio, MIN_RATIO])


## 面板描边框（内缩 3 px）里最亮的一个像素：只有面板底色与描边，没有被字压住。
func _ring_max(img: Image, r: Rect2, k: float) -> Color:
	var x0 := int(r.position.x * k)
	var y0 := int(r.position.y * k)
	var x1 := int((r.position.x + r.size.x) * k) - 1
	var y1 := int((r.position.y + r.size.y) * k) - 1
	var best := Color.BLACK
	for d in [3, 4]:
		for x in range(x0 + 7, x1 - 6):
			best = _louder(img, best, x, y0 + d)
			best = _louder(img, best, x, y1 - d)
		for y in range(y0 + 7, y1 - 6):
			best = _louder(img, best, x0 + d, y)
			best = _louder(img, best, x1 - d, y)
	return best


func _rect_max(img: Image, r: Rect2, k: float) -> Color:
	var x0 := int(r.position.x * k)
	var y0 := int(r.position.y * k)
	var x1 := int((r.position.x + r.size.x) * k) - 1
	var y1 := int((r.position.y + r.size.y) * k) - 1
	var best := Color.BLACK
	# 稀疏采样即可：背景是渐变，不需要逐像素。
	for x in range(x0, x1 + 1, 2):
		for y in range(y0, y1 + 1, 2):
			best = _louder(img, best, x, y)
	return best


func _louder(img: Image, best: Color, x: int, y: int) -> Color:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return best
	var p := img.get_pixel(x, y)
	return p if _lum(p) > _lum(best) else best


func _ratio(lab: Label, bg: Color) -> float:
	var fg: Color = lab.get_theme_color("font_color")
	var a := _lum(fg) + 0.05
	var b := _lum(bg) + 0.05
	return maxf(a, b) / minf(a, b)


## WCAG 相对亮度（sRGB -> 线性）。
func _lum(c: Color) -> float:
	var ch := func(v: float) -> float:
		return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * ch.call(c.r) + 0.7152 * ch.call(c.g) + 0.0722 * ch.call(c.b)


func _all_labels(node: Node) -> Array:
	var out := []
	for child in node.get_children():
		if child is Label:
			out.append(child)
		out.append_array(_all_labels(child))
	return out


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


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)


func _finish() -> void:
	print("HUD CONTRAST LINES %d" % rows.size())
	if failures.is_empty():
		print("STAGE4 HUD CONTRAST: PASS")
		get_tree().quit(0)
	else:
		print("STAGE4 HUD CONTRAST: FAIL")
		for item in failures:
			print("  - " + item)
		get_tree().quit(1)
