extends Node
## 乌龟 BONK_OUT 失败页：必须是乌龟的副标题/头像，不是氧气兔子页。

var is_runner := false
var failures: Array[String] = []
var dir := ""


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
	dir = ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	GameManager.failure_role = "turtle"
	GameManager.finish_failure("BONK_OUT")
	for i in 5:
		await get_tree().process_frame
	var fail = get_tree().current_scene
	var sub: String = fail._sub.text if fail != null and fail.get("_sub") != null else ""
	_check("turtle_fail_sub", sub.contains("乌龟") or sub.contains("BITT"),
		sub)
	_check("turtle_fail_not_oxygen", not sub.contains("氧气")
		and not sub.contains("OUT OF AIR"), sub)
	if DisplayServer.get_name() != "headless":
		for i in 2:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			dir.path_join("window_turtle_fail.png"))
		print("CAPTURE window_turtle_fail")
	print("STAGE59 TURTLE FAIL: " + ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		print("  ok   " + name + "  " + detail)
	else:
		failures.append(name)
		print("  FAIL " + name + "  " + detail)
