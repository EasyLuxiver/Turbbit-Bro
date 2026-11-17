extends Node
## FEEL-17 P1：主控惩罚条 + 未受控兄弟简化状态；预警/满格/换人即时切换。

var is_runner := false
var race: Node
var checks: Array = []


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
	GameManager.test_no_best = true
	GameManager.start_race()
	for i in 5:
		await get_tree().process_frame
	race = get_tree().current_scene
	race.set_physics_process(false)
	race.opening_active = false
	race.test_disable_hazards = true
	race.load_level([], [])
	# 玩家控 TUBO，BITT 的条到 2：出现琥珀预警。
	GameManager.current_control = "rabbit"
	GameManager.clear_bro_meter()
	GameManager.note_mistake("TURTLE_WAVE", "turtle")
	GameManager.note_mistake("TURTLE_WAVE", "turtle")
	race.hud._process(0.016)
	_check("other_near_full", race.hud.bro_other_label.text.contains("BITT 捣乱压力 2/3"),
		race.hud.bro_other_label.text)
	_check("other_near_full_color",
		race.hud.bro_other_label.get_theme_color("font_color") != Color(1, 1, 1),
		str(race.hud.bro_other_label.get_theme_color("font_color")))
	# 满格：红色 + !
	GameManager.note_mistake("TURTLE_WAVE", "turtle")
	race.hud._process(0.016)
	_check("other_full_warning", race.hud.bro_other_label.text.contains("BITT 捣乱压力 3/3")
		and race.hud.bro_other_label.text.contains("!"),
		race.hud.bro_other_label.text)
	# SHIFT 后：主控条切 BITT，另一个 TUBO 显示为 0/3（状态立即正确）。
	GameManager.shift_lock_t = 0.0
	GameManager.toggle_control()
	race.hud._process(0.016)
	_check("shift_meter_switch", race.hud.bro_meter_label.text.contains("BITT")
		and race.hud.bro_other_label.text.contains("TUBO"),
		"%s | %s" % [race.hud.bro_meter_label.text,
			race.hud.bro_other_label.text])
	# 面板仍在视口内、面积不超。
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var area := 0.0
	for c in ["tl", "tr", "bl", "br"]:
		var panel: Control = race.hud._panels[c]
		area += panel.get_global_rect().size.x * panel.get_global_rect().size.y
	_check("panel_area_ok", area / (vp.x * vp.y) <= 0.08,
		"area=%.3f%%" % (area / (vp.x * vp.y) * 100.0))
	_check("no_new_meter_nodes", race.hud.get_node_or_null("OxygenBar") == null,
		"no new resource bar")
	_write()
	get_tree().quit(0 if checks.all(func(c): return bool(c["ok"])) else 1)


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var f := FileAccess.open("res://docs/reports/longrun/core-feel-17-readability.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks}, "  "))
	f.close()
