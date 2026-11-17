extends Node
## FEEL-11 F：新流程接入测试。
## 首次开始 → 7 格连环画；看完/跳过后 → 教学；教学完成/跳过 → 正式比赛。
## 直接重开（result/retry）不再重复故事/教学。

var is_runner := false
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
	GameManager.story_seen = false
	GameManager.tutorial_done = false
	GameManager.start_game_flow()
	for i in 4:
		await get_tree().process_frame
	_check("fresh_start_opens_comic", _scene("opening_comic.tscn"),
		str(get_tree().current_scene.scene_file_path) if get_tree().current_scene else "")
	var comic: Node = get_tree().current_scene
	comic._finish()
	for i in 4:
		await get_tree().process_frame
	_check("comic_finish_opens_tutorial", _scene("tutorial.tscn"),
		str(get_tree().current_scene.scene_file_path) if get_tree().current_scene else "")
	var tut: Node = get_tree().current_scene
	tut._finish()
	for i in 4:
		await get_tree().process_frame
	_check("tutorial_finish_opens_race", _scene("race.tscn"),
		str(get_tree().current_scene.scene_file_path) if get_tree().current_scene else "")
	GameManager.start_race()
	for i in 4:
		await get_tree().process_frame
	_check("retry_skips_story", _scene("race.tscn") and GameManager.story_seen
		and GameManager.tutorial_done,
		"%s story=%s tutorial=%s" % [str(get_tree().current_scene.scene_file_path),
			str(GameManager.story_seen), str(GameManager.tutorial_done)])
	_write()
	_finish()


func _write() -> void:
	var f := FileAccess.open("res://docs/reports/longrun/core-feel-11-flow.json",
		FileAccess.WRITE)
	f.store_string(JSON.stringify({"task": "TBB-CORE-FEEL-11 F",
		"generated_at": Time.get_datetime_string_from_system(),
		"checks": checks}, "  "))
	f.close()


func _scene(name: String) -> bool:
	var s := get_tree().current_scene
	return s != null and s.scene_file_path.ends_with(name)


func _check(n: String, ok: bool, d: String) -> void:
	checks.append({"name": n, "ok": ok, "detail": d})
	print(("ok    " if ok else "FAIL  ") + n + "  " + d)


func _finish() -> void:
	var failed := 0
	for c in checks:
		if not bool(c["ok"]):
			failed += 1
	print("FEEL-11 FLOW: %d/%d pass" % [checks.size() - failed, checks.size()])
	print("FEEL-11 FLOW RESULT: ", "PASS" if failed == 0 else "FAIL")
	get_tree().quit(0 if failed == 0 else 1)
