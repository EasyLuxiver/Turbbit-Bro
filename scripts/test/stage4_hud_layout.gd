extends Node
## Phase I HUD 布局自检：在真实 race.tscn 里读 HUD 的实际矩形与标签尺寸。
##
## 检查（每个窗口尺寸 × 每种语言）：
##   1. 四角面板合计面积占视口比例 <= 8%；
##   2. 四角面板都在视口内，彼此不重叠，也不压到底部中央文字块；
##   3. 每个可见 Label 的宽度装得下它的最小宽度（不截断）。
##
## 运行：
##   Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT res://scenes/stage4_hud_layout.tscn
##   加 --resolution 1280x720 可测小窗口（headless 下改窗口尺寸不生效）。

var is_runner := false
var failures: Array[String] = []
var race

const AREA_LIMIT := 0.08
const SIZES := [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720)]
const LANGS := ["zh", "en"]
const CORNERS := ["tl", "tr", "bl", "br"]


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4HudLayoutRunner"
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
	await _wait_scene("race.tscn")
	await _frames(4)
	race = get_tree().current_scene
	_check(race != null and race.hud != null, "race scene has HUD")
	if race == null or race.hud == null:
		_finish()
		return

	# 站到低杆前 300 px，触发真实的障碍预警；关碰撞，免得被测期间出事。
	race.test_disable_hazards = true
	var beam := {}
	for g in race.hazard_groups:
		if g["group"] == "beam1":
			beam = g
			break
	_check(not beam.is_empty(), "beam1 exists on the track")
	if not beam.is_empty():
		race.turtle.position = Vector2(race._group_start(beam) - 300.0, 334.0)
		race.turtle.speed = 0.0
	await _frames(3)

	for s in SIZES:
		var win := get_window()
		if win != null and not DisplayServer.get_name() == "headless":
			win.size = s
		await _frames(4)
		for lang in LANGS:
			Locale.set_language(lang)
			await _frames(4)
			# 三行底部文字同时在场：真实障碍预警 + 最长教学行 + 连招反馈。
			GameManager.prompt.emit(Locale.t("prompt.ollie"))
			GameManager.hint.emit(Locale.t("lesson.sink_gate"))
			GameManager.feedback.emit(Locale.t("feedback.bro_combo"), "bro")
			await _frames(2)
			_measure(s, lang)

	# 测完恢复默认，避免影响后续场景。
	Locale.language = "zh"
	_finish()


func _measure(size_hint: Vector2i, lang: String) -> void:
	var hud = race.hud
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var rects := {}
	for c in CORNERS:
		rects[c] = (hud._panels[c] as Control).get_global_rect()
	var bc: Rect2 = (hud._bottom_center as Control).get_global_rect()
	var area := 0.0
	for c in CORNERS:
		area += rects[c].size.x * rects[c].size.y
	var ratio := area / (vp.x * vp.y)
	var tag := "%dx%d/%s (viewport %.0fx%.0f)" % [size_hint.x, size_hint.y, lang, vp.x, vp.y]
	print("HUD LAYOUT %s area=%.3f%% panels=%s bottom_center=%s" % [
		tag, ratio * 100.0, str(rects), str(bc)])
	_check(ratio <= AREA_LIMIT,
		"%s panel area %.2f%% <= %.0f%%" % [tag, ratio * 100.0, AREA_LIMIT * 100.0])

	var screen := Rect2(Vector2.ZERO, vp)
	for c in CORNERS:
		_check(screen.encloses(rects[c]), "%s panel %s inside viewport" % [tag, c])
	# FEEL-13：隐藏的空面板（例如没吃食物时的左下状态）不参与重叠判定；
	# 它的 rect 留在原点，和左上角面板相交，但那不是玩家看得见的东西。
	var visible_panels: Array[String] = []
	for c in CORNERS:
		var p: Control = hud._panels[c]
		if p != null and p.is_visible_in_tree() and p.size.x > 8.0 and p.size.y > 8.0:
			visible_panels.append(c)
	for i in visible_panels.size():
		for j in range(i + 1, visible_panels.size()):
			_check(not rects[visible_panels[i]].intersects(rects[visible_panels[j]]),
				"%s panels %s/%s do not overlap" % [tag, visible_panels[i], visible_panels[j]])
		if rects[visible_panels[i]].intersects(bc):
			_check(false, "%s panel %s overlaps bottom-center text" % [tag, visible_panels[i]])

	var labels := 0
	for c in CORNERS:
		for lab in _all_labels(hud._panels[c]):
			if not lab.is_visible_in_tree():
				continue
			labels += 1
			var need: float = lab.get_combined_minimum_size().x
			_check(lab.size.x + 0.5 >= need,
				"%s label '%s' width %.1f >= min %.1f" % [tag, lab.text, lab.size.x, need])
	for lab in _all_labels(hud._bottom_center):
		if not lab.is_visible_in_tree():
			continue
		labels += 1
		var need: float = lab.get_combined_minimum_size().x
		_check(lab.size.x + 0.5 >= need,
			"%s bottom label '%s' width %.1f >= min %.1f" % [tag, lab.text, lab.size.x, need])
	print("HUD LAYOUT %s labels_checked=%d" % [tag, labels])


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
	if failures.is_empty():
		print("STAGE4 HUD LAYOUT: PASS")
		get_tree().quit(0)
	else:
		print("STAGE4 HUD LAYOUT: FAIL")
		for item in failures:
			print("  - " + item)
		get_tree().quit(1)
