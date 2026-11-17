extends Node
## FEEL-31：测试场逻辑验收 + SHARK6 三只实体鲨鱼/看台；介入已移除。
## 鼠标路径在窗口模式下用 Input.parse_input_event 走一遍；headless 只测逻辑。

const KINDS := ["SURFACE_ROCK", "LOW_BIRD", "LOW_BEAM", "DIVE_GATE",
	"FLOATING_LOG", "SHARK", "HIGH_WALL", "SHARK6"]
const FPS := 60.0

var is_runner := false
var arena: Node
var checks: Array = []
var best_before := ""


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
	best_before = _read_best()
	arena = load("res://scenes/test_arena.tscn").instantiate()
	get_tree().root.add_child(arena)
	for i in 8:
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await _shot("arena-panel")
	var race: Node = arena.race
	_check("arena_starts_empty", race.hazard_groups.is_empty(),
		"groups=%d" % race.hazard_groups.size())
	_check("arena_no_finish", race.test_no_finish and GameManager.test_no_best,
		"no_finish=%s no_best=%s" % [str(race.test_no_finish), str(GameManager.test_no_best)])
	var x0: float = race.turtle.position.x
	for i in 60:
		await get_tree().physics_frame
	_check("arena_moves_forward", race.turtle.position.x > x0 + 100.0,
		"dx=%.0f" % (race.turtle.position.x - x0))

	# 1) 八种对象逐个生成，并做一次碰撞接线验证。
	for i in KINDS.size():
		var kind: String = KINDS[i]
		arena._option.selected = i
		arena._on_spawn()
		await get_tree().physics_frame
		var g: Dictionary = race.hazard_groups[-1]
		var spawned := String(g["kind"]) == ("SHARK" if kind == "SHARK6" else kind)
		var hit := _hit_once(race, g, kind)
		_check("spawn_%s" % kind, spawned and hit,
			"kind=%s spawned=%s hit=%s" % [String(g["kind"]), str(spawned), str(hit)])
		arena._on_clear()
		await get_tree().process_frame
	_check("clear_removes_all", race.hazard_groups.is_empty(),
		"groups=%d" % race.hazard_groups.size())

	# 连续生成多个，不要求先清除。
	arena._option.selected = 0
	arena._on_spawn()
	arena._on_spawn()
	await get_tree().physics_frame
	_check("multiple_spawns", race.hazard_groups.size() == 2,
		"groups=%d" % race.hazard_groups.size())
	arena._on_clear()

	# 2) 看台：只表现，不产生攻击/事故。
	arena._on_stands()
	var t0: int = GameManager.accident_count
	for i in 30:
		await get_tree().physics_frame
	_check("stands_no_harm", race._shark_stands_t > 0.0
		and GameManager.accident_count == t0 and race._shark_attacks.is_empty(),
		"stands=%.1f accidents=%d" % [race._shark_stands_t,
			GameManager.accident_count - t0])
	if DisplayServer.get_name() != "headless":
		await _shot("arena-stands")

	# 3) 随机摧毁障碍的鲨群干预已移除：不能再出现“障碍消失但无事发生”。
	_check("intervention_removed", not race.has_method("trigger_shark_intervention"),
		"method=%s" % str(race.has_method("trigger_shark_intervention")))

	# 4) SHARK6：三只鲨鱼依次出手，日志齐全。
	arena._on_clear()
	arena._option.selected = 7
	arena._on_spawn()
	await get_tree().physics_frame
	var pack: Dictionary = race.hazard_groups[-1]
	race.turtle.reset(Vector2(race._group_start(pack) - 150.0, race.surface_ref()))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	GameManager.accident_state = "NONE"
	race.rabbit.state = "RIDING"
	race._shark_pack["shark6"]["phase"] = "CIRCLE"
	race._shark_pack["shark6"]["t"] = 0.0
	race._shark_pack_entry_seen = true
	race._tick_shark_pack(1.0 / FPS)
	var seen := {}
	var shot_thin := false
	var shot_fat := false
	for i in 600:
		race._tick_shark_pack(1.0 / FPS)
		race._check_shark_attacks(1.0 / FPS)
		for row in race._shark_pack_log:
			seen[String(row.get("who", ""))] = true
		if DisplayServer.get_name() != "headless":
			for a in race._shark_attacks:
				var mode := String(a.get("mode", ""))
				if mode == "thin" and not shot_thin:
					shot_thin = true
					await _shot("arena-shark6-thin")
				elif mode == "fat" and not shot_fat:
					shot_fat = true
					await _shot("arena-shark6-fat")
		var shots_ok: bool = true
		if DisplayServer.get_name() != "headless":
			shots_ok = shot_thin and shot_fat
		if seen.has("leader") and seen.has("thin") and seen.has("fat") and shots_ok:
			break
	_check("shark6_all_three_attack", seen.has("leader") and seen.has("thin") and seen.has("fat"),
		str(seen.keys()))
	if DisplayServer.get_name() != "headless":
		await _shot("arena-shark6")

	# 5) 鼠标：窗口模式下点击“生成”按钮；headless 无法路由鼠标。
	if DisplayServer.get_name() != "headless":
		arena._on_clear()
		arena._option.selected = 0
		var btn: Button = null
		for b in _all_buttons(arena):
			if b.text == Locale.t("arena.spawn"):
				btn = b
		if btn != null:
			var r: Rect2 = btn.get_global_rect()
			var p: Vector2 = r.get_center()
			_click(p)
			for i in 4:
				await get_tree().process_frame
		_check("mouse_spawn_button", not race.hazard_groups.is_empty(),
			"groups=%d" % race.hazard_groups.size())

	_check("best_json_untouched", _read_best() == best_before, "best byte-identical")

	# 6) 正式菜单不再暴露测试场；测试场只允许测试工具直接加载。
	arena.queue_free()
	for i in 3:
		await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	for i in 10:
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await _shot("menu-test-arena")
	var menu_btn: Button = null
	for b in _all_buttons(get_tree().current_scene):
		if b.text == Locale.t("menu.test_arena"):
			menu_btn = b
	_check("menu_test_arena_hidden", menu_btn == null,
		"found=%s" % str(menu_btn != null))
	get_tree().change_scene_to_file("res://scenes/test_arena.tscn")
	for i in 12:
		await get_tree().process_frame
	var path := ""
	if get_tree().current_scene != null:
		path = get_tree().current_scene.scene_file_path
	_check("arena_scene_direct", path.ends_with("test_arena.tscn"), path)
	var entered: Node = get_tree().current_scene
	var entered_race: Node = null
	if entered != null:
		entered_race = entered.get("race") as Node
	var no_opening := false
	if entered_race != null:
		no_opening = entered_race.get("opening") == null \
			and not entered_race.has_node("OpeningLayer")
	_check("arena_no_opening_overlay", no_opening,
		"opening=%s" % str(not no_opening))

	# 7) 重启与返回菜单。
	var fresh: Node = get_tree().current_scene
	if fresh != null and fresh.has_method("_on_restart"):
		fresh._on_restart()
		for i in 12:
			await get_tree().process_frame
		fresh = get_tree().current_scene
		var restart_path := fresh.scene_file_path if fresh != null else ""
		var restart_empty := false
		var fresh_race: Node = null
		if fresh != null:
			fresh_race = fresh.get("race") as Node
		if fresh_race != null:
			restart_empty = fresh_race.hazard_groups.is_empty()
		_check("arena_restart", restart_path.ends_with("test_arena.tscn") and restart_empty,
			"%s empty=%s" % [restart_path, str(restart_empty)])
		fresh._on_menu()
		for i in 12:
			await get_tree().process_frame
		var menu_path := ""
		if get_tree().current_scene != null:
			menu_path = get_tree().current_scene.scene_file_path
		_check("arena_returns_menu", menu_path.ends_with("menu.tscn")
			and GameManager.state == GameManager.GameState.MENU, menu_path)

	_write()
	var ok: bool = checks.all(func(c): return bool(c["ok"]))
	print("TEST ARENA: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _hit_once(race: Node, g: Dictionary, kind: String) -> bool:
	GameManager.accident_state = "NONE"
	GameManager.last_mistake_role = ""
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.hazard_cooldown = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	var idx: int = g["rects"].size() - 1 if kind == "HIGH_WALL" else 0
	var rect: Rect2 = race.hazard_rect_live(g, idx)
	if kind == "SHARK6":
		var leader: Dictionary = race._pack_actor("leader")
		if not leader.is_empty():
			leader["phase"] = "HOLD"
			leader["tx"] = rect.get_center().x
			leader["rect"] = Rect2(rect.get_center().x - 45.0, 288.0, 90.0, 192.0)
			race._shark_attacks.clear()
			race._shark_attacks.append(leader)
			rect = leader["rect"]
	elif String(g["kind"]) == "SHARK":
		race._ambush[String(g["group"])] = {"phase": "LUNGE", "t": 0.0}
		rect = race.hazard_rect_live(g, 0)
	if kind in ["SURFACE_ROCK", "LOW_BIRD", "LOW_BEAM", "FLOATING_LOG"]:
		race.rabbit.state = "RIDING"
		race.rabbit.position = rect.get_center()
		race.turtle.position = Vector2(rect.position.x - 300.0, race.surface_ref())
	else:
		race.turtle.position = rect.get_center()
		race.rabbit.position = race.turtle.get_mount_point()
	if kind == "LOW_BIRD":
		# 海鸟只在 DIVE 窗口判伤；把乌龟放到攻击航程内，兔子仍放在判定带里。
		race.turtle.position.x = rect.position.x - 80.0
	race._check_hazards()
	if kind == "SHARK6":
		race._check_shark_attacks(0.0)
	return not race.hit_groups.is_empty() or GameManager.last_mistake_role != ""


func _click(pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	ev.position = pos
	ev.global_position = pos
	get_viewport().push_input(ev)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.button_mask = 0
	up.position = pos
	up.global_position = pos
	get_viewport().push_input(up)


func _all_buttons(node: Node) -> Array:
	var out := []
	if node is Button:
		out.append(node)
	for c in node.get_children():
		out.append_array(_all_buttons(c))
	return out


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://docs/reports/longrun/feel31")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("CAPTURE ", name)


func _read_best() -> String:
	var path := "user://best.json"
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_buffer(f.get_length()).hex_encode()
	f.close()
	return s


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var f := FileAccess.open("res://docs/reports/longrun/feel31-test-arena.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"checks": checks}, "  "))
		f.close()
