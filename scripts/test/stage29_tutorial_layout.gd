extends Node
## FEEL-29 任务A：SHIFT 切换控制不得改变教学台词的布局。
## 只测量控件几何（宽/行数/位置），不改文本内容和教学流程。

var is_runner := false
var tut: Node
var panel: Control
var checks: Array = []
var baseline := {}


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
	tut = load("res://scenes/tutorial.tscn").instantiate()
	get_tree().root.add_child(tut)
	for i in 8:
		await get_tree().process_frame
	# 冻结位移，只观察布局；不影响提示刷新。
	tut.race.turtle.base_speed = 0.0
	tut.race.turtle.speed = 0.0
	tut._set_step(0)
	await _settle()
	panel = tut._line.get_parent().get_parent().get_parent()
	baseline = _measure()
	print("BASE ", JSON.stringify(baseline))
	if DisplayServer.get_name() != "headless":
		_shot("tutorial-rabbit-1920")
	_check("step1 baseline text", tut._line.text == Locale.t("tutorial.step1"),
		tut._line.text)
	for i in 10:
		GameManager.set_control("turtle" if i % 2 == 0 else "rabbit")
		await _settle()
		var m := _measure()
		print("SWITCH %d %s" % [i, JSON.stringify(m)])
		if i == 0 and DisplayServer.get_name() != "headless":
			_shot("tutorial-turtle-1920")
		_check("line width stable #%d" % i,
			absf(float(m["line_w"]) - float(baseline["line_w"])) <= 0.5,
			"%s vs %s" % [m["line_w"], baseline["line_w"]])
		_check("line count stable #%d" % i, int(m["line_count"]) == int(baseline["line_count"]),
			"%s vs %s" % [m["line_count"], baseline["line_count"]])
		_check("panel width stable #%d" % i,
			absf(float(m["panel_w"]) - float(baseline["panel_w"])) <= 0.5,
			"%s vs %s" % [m["panel_w"], baseline["panel_w"]])
		_check("panel height stable #%d" % i,
			absf(float(m["panel_h"]) - float(baseline["panel_h"])) <= 0.5,
			"%s vs %s" % [m["panel_h"], baseline["panel_h"]])
		_check("panel x stable #%d" % i,
			absf(float(m["panel_x"]) - float(baseline["panel_x"])) <= 0.5,
			"%s vs %s" % [m["panel_x"], baseline["panel_x"]])
		_check("line text unchanged #%d" % i,
			tut._line.text == Locale.t("tutorial.step1"), tut._line.text)
	_write()
	var ok: bool = checks.all(func(c): return bool(c["ok"]))
	print("TUTORIAL LAYOUT: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _settle() -> void:
	for i in 3:
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	var dir := ProjectSettings.globalize_path("res://docs/reports/longrun/feel29")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("CAPTURE ", name)


func _measure() -> Dictionary:
	return {
		"line_w": snappedf(tut._line.size.x, 0.1),
		"line_h": snappedf(tut._line.size.y, 0.1),
		"line_count": tut._line.get_line_count(),
		"hint_w": snappedf(tut._hint.size.x, 0.1),
		"hint_text": tut._hint.text,
		"panel_w": snappedf(panel.size.x, 0.1),
		"panel_h": snappedf(panel.size.y, 0.1),
		"panel_x": snappedf(panel.position.x, 0.1),
	}


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var path := ProjectSettings.globalize_path("res://docs/reports/longrun/feel29-tutorial-layout.json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"checks": checks}, "  "))
		f.close()
