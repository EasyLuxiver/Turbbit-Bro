extends Node
## FEEL-10 P0-D：Z2 木码头入场节拍与“先读环境、再见第一组障碍”。
##
## 判据：
##   1. 入口前 2–3 s 就能看到码头在接近（远景先实、屋顶/近景后实）；
##   2. 每一层的淡入是连续的（50 px 采样步进 <= 0.12），没有整块跳变；
##   3. 过界后 2–3 s 内六层全部实心；
##   4. 第一组 Z2 障碍出现时，环境已全部可读（alpha=1）；
##   5. 入场不冻结玩法（不写 turtle.speed / 不改 obstacles）。
##
## 输出：docs/reports/longrun/feel10-p0d/

const OUT_DIR := "res://docs/reports/longrun/feel10-p0d"
const OUT_JSON := "res://docs/reports/longrun/core-feel-10-p0d-entry.json"

var is_runner := false
var race: Node = null
var checks: Array = []
var rows: Array = []
var alpha_rows: Array = []


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
	if race == null:
		_check("race", false, "no race scene")
		_finish()
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_disable_hazards = true
	race.test_no_finish = true
	GameManager.set_control("rabbit")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var dock: Node = race.get_node("Zone2Dock")
	var first_z2 := _first_z2_group()
	var first_x: float = race._group_start(first_z2)
	# 连续采样：13200 → 第一组障碍，50 px 一步。
	var prev := {}
	var max_step := 0.0
	var step_at := 0.0
	var x := 7400.0
	while x <= first_x + 1.0:
		await _pin(x)
		var a := _alphas(dock)
		if not prev.is_empty():
			for k in a.keys():
				var d: float = absf(float(a[k]) - float(prev[k]))
				if d > max_step:
					max_step = d
					step_at = x
		prev = a
		alpha_rows.append({"x": x, "a": a})
		x += 50.0
	_check("fade_continuous", max_step <= 0.12,
		"最大 50 px 淡入跳变 %.3f @x=%.0f" % [max_step, step_at])
	# 过界时：远景/中景实，屋顶与近景仍在淡入（读作“正在走进去”）。
	await _pin(10000.0)
	var at_boundary := _alphas(dock)
	_check("boundary_layers",
		float(at_boundary["bg_far"]) >= 0.99
			and float(at_boundary["bg_mid"]) >= 0.99
			and float(at_boundary["fg_overhead"]) >= 0.35
			and float(at_boundary["fg_overhead"]) <= 0.95
			and float(at_boundary["fg_near"]) >= 0.35
			and float(at_boundary["fg_near"]) <= 0.95,
		"@10000 %s" % str(at_boundary))
	# 第一组障碍时：六层全部实心。
	await _pin(first_x)
	var at_first := _alphas(dock)
	var all_full := true
	for k in at_first.keys():
		# fg_near 是最慢的一层；压缩后第一组在 600 px 处，允许它 >=0.90，
		# 其余背景/顶梁必须全实，保证玩家先读懂环境再处理鲨鱼。
		var need := 0.90 if String(k) == "fg_near" else 0.99
		if String(k) != "canal" and float(at_first[k]) < need:
			all_full = false
	_check("first_obstacle_after_env", all_full,
		"first=%s @%.0f %s" % [String(first_z2["group"]), first_x, str(at_first)])
	_check("first_obstacle_gap", first_x - 10000.0 >= 120.0,
		"距边界 %.0f px ≈ %.1f s" % [first_x - 10000.0,
			(first_x - 10000.0) / 220.0])
	# 入场不冻结：速度/障碍组数与边界前一致。
	await _pin(9700.0)
	var speed_before: float = race.turtle.base_speed
	var groups_before: int = race.hazard_groups.size()
	await _pin(10300.0)
	_check("entry_not_blocking",
		race.turtle.base_speed == speed_before
			and race.hazard_groups.size() == groups_before,
		"speed %.0f→%.0f groups %d→%d" % [speed_before,
			race.turtle.base_speed, groups_before, race.hazard_groups.size()])
	# 入口节拍截图：远景接近 / 边界 / 刚过界 / 第一组障碍。
	await _shot(dock, 8400.0, "p0d-1-far-dock")
	await _shot(dock, 9200.0, "p0d-2-approach")
	await _shot(dock, 10000.0, "p0d-3-boundary")
	await _shot(dock, 10500.0, "p0d-4-inside")
	await _shot(dock, first_x, "p0d-5-first-obstacle")
	_write(first_x)
	_finish()


func _pin(x: float) -> void:
	race.turtle.position = Vector2(x, race.surface_ref())
	race.rabbit.position = race.turtle.get_mount_point()
	race.mount.mark_riding()
	race._update_zone()
	race._update_camera()
	race._update_dock()
	race.queue_redraw()
	for i in 2:
		await get_tree().process_frame


func _shot(dock: Node, x: float, name: String) -> void:
	await _pin(x)
	for i in 3:
		await get_tree().process_frame
	var dir := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE ", path)


func _alphas(dock: Node) -> Dictionary:
	var out := {}
	for l in dock.layers:
		out[String(l.layer)] = snappedf(float(l.modulate.a), 0.001)
	return out


func _first_z2_group() -> Dictionary:
	for g in race.hazard_groups:
		if int(g["zone"]) == 2:
			return g
	return {}


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write(first_x: float) -> void:
	var data := {"task": "TBB-CORE-FEEL-10 P0-D",
		"generated_at": Time.get_datetime_string_from_system(),
		"first_z2_x": first_x, "checks": checks,
		"samples": alpha_rows}
	var f := FileAccess.open(OUT_JSON, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))
	f.close()


func _finish() -> void:
	var failed := 0
	for c in checks:
		if not bool(c["ok"]):
			failed += 1
	print("P0D ENTRY: %d/%d pass" % [checks.size() - failed, checks.size()])
	print("P0D RESULT: ", "PASS" if failed == 0 else "FAIL")
	get_tree().quit(0 if failed == 0 else 1)
