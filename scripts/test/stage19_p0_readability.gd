extends Node
## FEEL-19 P0：救援 SPACE 文案/键帽。
## FEEL-24 起右下角 0/3 面板已移除，原“满格可见”两条断言随之删除；
## MISCHIEF 可读性由 stage15_mischief 覆盖。

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
	GameManager.current_control = "rabbit"
	GameManager.prompt.emit(Locale.t("prompt.rescue_dive"))
	race.hud._process(0.016)
	_check("rescue_prompt_space", race.hud.prompt_label.text.contains("SPACE"),
		race.hud.prompt_label.text)
	_check("space_keycap_visible", race.hud.keycap_panels["pop"].visible,
		str(race.hud.keycap_panels["pop"].visible))
	# 教学只教换人/动词；救援 SPACE 由实时 prompt 与暂停帮助承载。
	_check("pause_help_mentions_space", Locale.t("pause.help_body").contains("SPACE"),
		Locale.t("pause.help_body"))
	_write()
	get_tree().quit(0 if checks.all(func(c): return bool(c["ok"])) else 1)


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var f := FileAccess.open("res://docs/reports/longrun/core-feel-19-p0.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks}, "  "))
	f.close()
