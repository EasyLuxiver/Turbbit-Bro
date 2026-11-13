extends Node
## 阶段 4 核心体验自检（2026-11-11 重设计指令）。
## 本文件替换旧的“失权自动恶化”测试，验的是新规则：
##   1) 兔子受控 10 s / 30 s，乌龟待命不沉、不失衡；
##   2) 乌龟受控 10 s / 30 s，兔子待命不滑、不失衡；
##   3) 快速 SHIFT 不加风险、也不清风险；
##   4) 兔子 ↑ 过岩石、↓ 过低梁；乌龟 SPACE 过宽浪；
##   5) 错误动作有可见后果（硬直/失衡/浪击）；
##   6) 同一碰撞重复两次，结果和时间一致；
##   7) 氧气只在水下消耗、水面恢复；Showtime 只给 +1.5，不瞬间回满，
##      也不抢控制权；
##   8) 55 组 = 岩石 19 / 低梁 17 / 宽浪 19，相邻组反应距离 ≥ 700 px。
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT res://scenes/stage4_core_experience.tscn

const Tuning = preload("res://scripts/systems/tuning.gd")
const LevelDataScript = preload("res://scripts/systems/level_data.gd")
const REPORT_PATH := "res://docs/reports/stage4-core-experience.json"

var is_runner := false
var failures: Array[String] = []
var race
var sim := 0.0
var report := {}


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4CoreRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	Engine.time_scale = 2.0
	Locale.language = "en"
	var best_text := _read(GameManager.BEST_PATH)

	await _test_standby_turtle()
	await _test_standby_rabbit()
	await _test_rapid_shift()
	await _test_jump()
	await _test_crouch()
	await _test_dive_gate()
	await _test_wrong_action()
	await _test_repeatable_hit()
	await _test_oxygen()
	await _test_showtime()
	_test_rhythm()

	_write_report()
	_restore(GameManager.BEST_PATH, best_text)
	Engine.time_scale = 1.0

	if failures.is_empty():
		print("STAGE4 CORE EXPERIENCE: PASS")
		get_tree().quit(0)
	else:
		print("STAGE4 CORE EXPERIENCE: FAIL")
		for item in failures:
			print("  - " + item)
		get_tree().quit(1)


# ---- 1. 控制兔子 10 s / 30 s：乌龟待命不沉、不失衡。 ----

func _test_standby_turtle() -> void:
	await _fresh(false)
	Engine.time_scale = 3.0
	# BRO BRAIN：待命/未恢复时乌龟围绕巡航水深上下晃（drift_bob_px，幅度 ≤18 px），
	# 所以判“30 s 一直留在巡航带内”，不判某一瞬间的深度——旧版按 ±1.5 px 取两个
	# 时间点，晃的相位一变就随机失败（2026-11-13 实测 341.2 / 338.0 被误判为下沉）。
	var band := 20.0
	var y10 := 0.0
	var y_min := 1.0e9
	var y_max := -1.0e9
	var daze_max := 0.0
	var t0 := sim
	while sim - t0 < 30.5:
		var y: float = race.turtle.position.y
		y_min = minf(y_min, y)
		y_max = maxf(y_max, y)
		if sim - t0 >= 10.0 and y10 == 0.0:
			y10 = y
		daze_max = maxf(daze_max, race.turtle.daze_time)
		await _step()
	_check(absf(y10 - Tuning.NEUTRAL_DEPTH) <= band,
		"turtle standby 10 s inside cruise band (y=%.1f)" % y10)
	_check(y_min >= Tuning.NEUTRAL_DEPTH - band and y_max <= Tuning.NEUTRAL_DEPTH + band,
		"turtle standby 30 s stays in cruise band (y=%.1f..%.1f)" % [y_min, y_max])
	_check(daze_max < 0.01, "turtle standby never accumulates imbalance (%.2f)" % daze_max)
	_check(GameManager.accident_state == "NONE", "turtle standby 30 s has no accident")
	_check(GameManager.current_control == "rabbit", "control stays on rabbit")
	Engine.time_scale = 2.0
	report["standby_turtle"] = {"y_10s": y10, "y_30s": race.turtle.position.y,
		"max_daze": daze_max}
	print("  standby turtle -> y10 %.1f y30 %.1f daze %.2f" % [
		y10, race.turtle.position.y, daze_max])


# ---- 2. 控制乌龟 10 s / 30 s：兔子待命不滑、不失衡。 ----

func _test_standby_rabbit() -> void:
	await _fresh(false)
	await _shift()
	Engine.time_scale = 3.0
	var slide_max := 0.0
	var daze_max := 0.0
	var slide10 := 0.0
	var t0 := sim
	while sim - t0 < 30.5:
		if sim - t0 >= 10.0 and slide10 == 0.0:
			slide10 = race.rabbit.slide
		slide_max = maxf(slide_max, race.rabbit.slide)
		daze_max = maxf(daze_max, race.rabbit.daze_time)
		await _step()
	_check(absf(slide10) < 0.001, "rabbit standby 10 s does not slide (%.3f)" % slide10)
	_check(absf(race.rabbit.slide) < 0.001,
		"rabbit standby 30 s does not slide (%.3f)" % race.rabbit.slide)
	_check(daze_max < 0.01, "rabbit standby never accumulates imbalance (%.2f)" % daze_max)
	_check(race.mount.state == "RIDING", "rabbit stays attached while on standby")
	_check(GameManager.accident_state == "NONE", "rabbit standby 30 s has no accident")
	Engine.time_scale = 2.0
	report["standby_rabbit"] = {"slide_10s": slide10, "slide_30s": race.rabbit.slide,
		"max_daze": daze_max}
	print("  standby rabbit -> slide10 %.3f slide30 %.3f daze %.2f" % [
		slide10, race.rabbit.slide, daze_max])


# ---- 3. 快速 SHIFT：不清风险、也不额外加风险。 ----

func _test_rapid_shift() -> void:
	await _fresh(false)
	race.rabbit.add_imbalance(4.0)
	var before: float = race.rabbit.daze_time
	var turtle_before: float = race.turtle.daze_time
	var count0: int = GameManager.shift_count
	for i in 6:
		await _shift()
		await _wait_sim(0.1)
	_check(GameManager.shift_count == count0 + 6,
		"six rapid SHIFTs all register (%d)" % (GameManager.shift_count - count0))
	_check(absf(race.rabbit.daze_time - before) < 0.08,
		"rapid SHIFT keeps existing rabbit risk (%.2f -> %.2f)" % [
			before, race.rabbit.daze_time])
	_check(race.turtle.daze_time < turtle_before + 0.01,
		"rapid SHIFT adds no turtle risk (%.2f)" % race.turtle.daze_time)
	_check(GameManager.accident_state == "NONE", "rapid SHIFT causes no accident")
	# 受控方站稳 0.5 s 后仍然会恢复；切换本身不是豁免。
	var d0: float = race.rabbit.daze_time
	await _wait_sim(2.0)
	_check(race.rabbit.daze_time < d0 - 0.5,
		"controlled side still recovers after settling (%.2f -> %.2f)" % [
			d0, race.rabbit.daze_time])
	report["rapid_shift"] = {"before": before, "after": race.rabbit.daze_time,
		"after_settle": race.rabbit.daze_time}
	print("  rapid shift -> %.2f -> %.2f" % [before, race.rabbit.daze_time])


# ---- 4a. 兔子 ↑ 跳过岩石。 ----

func _test_jump() -> void:
	await _fresh(true)
	Engine.time_scale = 1.0
	var g := _group("rock1")
	var start := _group_start(g)
	_place(start - 120.0)
	await _step()
	await _tap(KEY_UP)
	var ok := await _wait_until(func(): return race.passed_groups.has("rock1"), 4.0)
	_check(ok, "rabbit jump clears rock1")
	_check(not race.hit_groups.has("rock1"), "rock1 not marked as hit")
	_check(GameManager.accident_state == "NONE", "jump landing causes no accident")
	_check(race.combo >= 1, "clean jump counts as a clean pass (combo=%d)" % race.combo)
	Engine.time_scale = 2.0
	report["jump"] = {"passed": ok, "combo": race.combo}
	print("  jump -> passed=%s combo=%d" % [str(ok), race.combo])


# ---- 4b. 兔子 ↓ 趴低过梁。 ----

func _test_crouch() -> void:
	await _fresh(true)
	Engine.time_scale = 1.0
	var g := _group("beam1")
	var start := _group_start(g)
	var end := _group_end(g)
	_place(start - 160.0)
	_send_key(KEY_DOWN, true)
	await _step()
	var ok := await _wait_until(
		func(): return race.turtle.position.x > end + 90.0, 4.0)
	_send_key(KEY_DOWN, false)
	await _step()
	_check(ok, "rabbit crouch crosses beam1")
	_check(race.passed_groups.has("beam1"), "beam1 is counted as passed")
	_check(not race.hit_groups.has("beam1"), "beam1 not marked as hit")
	_check(GameManager.accident_state == "NONE", "crouch causes no accident")
	Engine.time_scale = 2.0
	report["crouch"] = {"passed": ok, "combo": race.combo}
	print("  crouch -> passed=%s combo=%d" % [str(ok), race.combo])


# ---- 4c. 乌龟 ↓ 下潜过礁拱。 ----

func _test_dive_gate() -> void:
	await _fresh(true)
	Engine.time_scale = 1.0
	await _shift()
	var g := _group("gate1")
	var start := _group_start(g)
	var end := _group_end(g)
	_place(start - 200.0)
	_send_key(KEY_DOWN, true)
	var deep := await _wait_until(
		func(): return race.turtle.position.y > Tuning.NEUTRAL_DEPTH + Tuning.DIVE_DEPTH * 0.6, 3.0)
	_check(deep, "turtle ↓ actually dives under the gate")
	var ok := await _wait_until(
		func(): return race.turtle.position.x > end + 120.0, 4.0)
	_send_key(KEY_DOWN, false)
	var up := await _wait_until(
		func(): return race.turtle.position.y <= Tuning.NEUTRAL_DEPTH + 2.0, 2.5)
	_check(ok, "diving turtle clears gate1")
	_check(not race.hit_groups.has("gate1"), "gate1 not marked as hit")
	_check(GameManager.accident_state == "NONE", "dive causes no accident")
	_check(up, "released dive returns to the surface (y=%.0f)" % race.turtle.position.y)
	Engine.time_scale = 2.0
	report["dive"] = {"passed": ok, "surfaced": up}
	print("  dive -> passed=%s surfaced=%s" % [str(ok), str(up)])


# ---- 5. 错误动作有可见后果。 ----

func _test_wrong_action() -> void:
	await _fresh(true)
	Engine.time_scale = 1.0
	var t0_wait: float = 0.0
	_place(1300.0 - 60.0)
	var hit := await _wait_until(
		func(): return GameManager.accident_state != "NONE", 2.0)
	_check(hit, "running into a rock without jumping has a consequence")
	_check(GameManager.accident_state == "RABBIT_STUN",
		"wrong jump reads as RABBIT_STUN (%s)" % GameManager.accident_state)
	_check(race.rabbit.daze_time >= 3.0,
		"wrong action leaves visible imbalance (%.1f)" % race.rabbit.daze_time)
	_check(race.rabbit_stun > 0.0, "wrong action causes a short stun")
	Engine.time_scale = 2.0
	report["wrong_action"] = {"state": GameManager.accident_state,
		"daze": race.rabbit.daze_time, "wait": t0_wait}
	print("  wrong action -> %s daze %.1f" % [
		GameManager.accident_state, race.rabbit.daze_time])


# ---- 6. 同一碰撞重复两次，时间与结果一致。 ----

func _test_repeatable_hit() -> void:
	var rows := []
	for run in 2:
		await _fresh(true)
		Engine.time_scale = 1.0
		_place(1300.0 - 60.0)
		var t0 := sim
		var hit := await _wait_until(
			func(): return GameManager.accident_state != "NONE", 2.0)
		_check(hit, "collision run %d registers" % (run + 1))
		rows.append({
			"seconds": sim - t0,
			"state": GameManager.accident_state,
			"daze": race.rabbit.daze_time,
			"stun": race.rabbit_stun,
		})
	_check(rows[0]["state"] == rows[1]["state"],
		"same collision gives the same state (%s)" % str(rows[0]["state"]))
	_check(absf(rows[0]["seconds"] - rows[1]["seconds"]) < 0.05,
		"same collision gives the same timing (%.2f vs %.2f)" % [
			rows[0]["seconds"], rows[1]["seconds"]])
	_check(absf(rows[0]["daze"] - rows[1]["daze"]) < 0.01,
		"same collision gives the same imbalance (%.2f vs %.2f)" % [
			rows[0]["daze"], rows[1]["daze"]])
	_check(absf(rows[0]["stun"] - rows[1]["stun"]) < 0.01,
		"same collision gives the same stun duration")
	Engine.time_scale = 2.0
	report["repeatable_hit"] = rows
	print("  repeatable hit -> %s" % str(rows))


# ---- 7a. 氧气：只有真的在水下才掉，回到水面恢复。 ----

func _test_oxygen() -> void:
	await _fresh(false)
	Engine.time_scale = 1.0
	await _shift()
	_place(2000.0)
	GameManager.oxygen = 6.0
	_send_key(KEY_DOWN, true)
	var sunk := await _wait_until(
		func(): return race.turtle.position.y > Tuning.NEUTRAL_DEPTH 			+ Tuning.OXYGEN_DEPTH_MARGIN + 6.0, 2.0)
	_check(sunk, "holding ↓ puts the shell actually underwater (y=%.0f)" % race.turtle.position.y)
	var ox0: float = GameManager.oxygen
	await _wait_sim(1.2)
	var ox1: float = GameManager.oxygen
	_check(ox1 < ox0 - 0.3,
		"oxygen drains while actually underwater (%.1f -> %.1f)" % [ox0, ox1])
	_send_key(KEY_DOWN, false)
	var up := await _wait_until(
		func(): return race.turtle.position.y <= Tuning.NEUTRAL_DEPTH + 2.0, 3.0)
	_check(up, "releasing ↓ returns the shell to the surface (y=%.0f)" % race.turtle.position.y)
	await _wait_sim(1.2)
	_check(GameManager.oxygen > ox1 + 0.3,
		"oxygen recovers at the surface (%.1f -> %.1f)" % [ox1, GameManager.oxygen])
	_check(GameManager.accident_state != "OXYGEN_OUT", "no oxygen accident in 4.5 s")
	Engine.time_scale = 2.0
	report["oxygen"] = {"before": ox0, "underwater": ox1, "recovered": GameManager.oxygen}
	print("  oxygen -> %.1f -> %.1f -> %.1f" % [
		ox0, ox1, GameManager.oxygen])


# ---- 7b. Showtime：奖励不清控制权，也不瞬间回满氧气。 ----

func _test_showtime() -> void:
	await _fresh(false)
	Engine.time_scale = 2.0
	var control0: String = GameManager.current_control
	await _pass_group("beam6")
	await _pass_group("rock8")
	await _pass_group("bird9")
	_check(race.showtime_active, "three clean passes trigger Showtime")
	_check(GameManager.current_control == control0,
		"Showtime keeps the player's control (%s)" % GameManager.current_control)
	# 表演期间强制压在水下，才能看出“结束只给 +1.5”，而不是被水面恢复掩盖。
	GameManager.oxygen = 4.0
	var t0 := sim
	while race.showtime_active and sim - t0 < 2.5:
		race.turtle.position.y = Tuning.NEUTRAL_DEPTH + Tuning.DUNK_DEPTH
		await _step()
	_check(GameManager.showtime_count == 1, "Showtime counts once")
	_check(not race.showtime_active, "Showtime ends by itself")
	_check(GameManager.current_control == control0,
		"Showtime end keeps the player's control")
	_check(GameManager.oxygen > 3.0 and GameManager.oxygen < 4.6,
		"Showtime gives only a small oxygen refill (%.1f)" % GameManager.oxygen)
	report["showtime"] = {"oxygen_after": GameManager.oxygen,
		"control": GameManager.current_control}
	print("  showtime -> oxygen %.1f control %s" % [
		GameManager.oxygen, GameManager.current_control])


# ---- 8. 赛道节奏：三类障碍、数量、反应距离。 ----

func _test_rhythm() -> void:
	var groups := LevelDataScript.groups()
	var counts := {}
	var zone_kinds := {1: {}, 2: {}, 3: {}}
	var min_gap := 1.0e9
	var max_gap := 0.0
	var min_reaction := 1.0e9
	var max_reaction := 0.0
	var prev_end := -1.0
	for g in groups:
		counts[g["kind"]] = counts.get(g["kind"], 0) + 1
		zone_kinds[g["zone"]][g["kind"]] = true
		var start := LevelDataScript.group_start(g)
		if prev_end >= 0.0:
			var gap := start - prev_end
			var speed: float = LevelDataScript.zone_by_id(g["zone"])["base_speed"]
			min_gap = minf(min_gap, gap)
			max_gap = maxf(max_gap, gap)
			min_reaction = minf(min_reaction, gap / speed)
			max_reaction = maxf(max_reaction, gap / speed)
		prev_end = LevelDataScript.group_end(g)
	_check(groups.size() == 55, "track has 55 groups (%d)" % groups.size())
	_check(counts.get("SURFACE_ROCK", 0) == 12,
		"12 surface rocks (%d)" % counts.get("SURFACE_ROCK", 0))
	_check(counts.get("LOW_BEAM", 0) == 9,
		"9 dock beams (%d)" % counts.get("LOW_BEAM", 0))
	_check(counts.get("LOW_BIRD", 0) == 9 and counts.get("SHARK", 0) == 6
		and counts.get("HIGH_WALL", 0) == 3
		and counts.get("DIVE_GATE", 0) == 8 and counts.get("FLOATING_LOG", 0) == 8,
		"bird/shark/wall/gate/log counts 9/6/3/8/8 (%s)" % str(counts))
	_check(counts.size() == 7, "seven space classes incl. high wall (%d)" % counts.size())
	for zid in [1, 2, 3]:
		_check(zone_kinds[zid].size() == 7,
			"zone %d uses all seven obstacle classes" % zid)
	_check(min_reaction >= 3.5,
		"each obstacle gives >= 3.5 s reaction at its zone speed (min %.2f s)"
			% min_reaction)
	_check(max_reaction < 6.0,
		"no judgement-free stretch longer than 6 s (max %.2f s)" % max_reaction)
	report["rhythm"] = {
		"groups": groups.size(), "counts": counts,
		"min_gap_px": min_gap, "max_gap_px": max_gap,
		"min_reaction_s": min_reaction, "max_reaction_s": max_reaction,
	}
	print("  rhythm -> %d groups %s gap %.0f..%.0f px, reaction %.2f..%.2f s" % [
		groups.size(), str(counts), min_gap, max_gap, min_reaction, max_reaction])


# ---- 工具 ----

func _group(id: String) -> Dictionary:
	for g in race.hazard_groups:
		if g["group"] == id:
			return g
	return {}


func _group_start(g: Dictionary) -> float:
	return race._group_start(g)


func _group_end(g: Dictionary) -> float:
	return race._group_end(g)


func _place(x: float) -> void:
	race.turtle.position = Vector2(x, Tuning.NEUTRAL_DEPTH)
	race.turtle.speed = 220.0
	race.turtle._vy = 0.0
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.mark_riding()


## 直接把赛道推进过一组：用于 Showtime 这种与操作无关的奖励验证。
func _pass_group(id: String) -> void:
	var g := _group(id)
	if g.is_empty():
		return
	var start := _group_start(g)
	var end := _group_end(g)
	race.turtle.position = Vector2(start - 60.0, Tuning.NEUTRAL_DEPTH)
	await _step()
	# 刚过判定线就结算（+85 > +80），别等再多跑几帧——
	# SHOWTIME_CLEAR=900，Z3 的组间尾距 1000 px，多跑 4 px 就挤进下一组的前视距离。
	race.turtle.position = Vector2(end + 85.0, Tuning.NEUTRAL_DEPTH)
	await _step()


func _fresh(hazards: bool) -> void:
	GameManager.start_race()
	await _frames(4)
	race = get_tree().current_scene
	race.test_disable_hazards = not hazards
	sim = 0.0
	await get_tree().physics_frame


func _step() -> void:
	await get_tree().physics_frame
	sim += (1.0 / 60.0) * Engine.time_scale


func _wait_sim(seconds: float) -> void:
	var start := sim
	while sim - start < seconds:
		await _step()


func _wait_until(cond: Callable, limit: float) -> bool:
	var start := sim
	while sim - start < limit:
		if cond.call():
			return true
		await _step()
	return cond.call()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shift() -> void:
	await _tap(KEY_SHIFT)


func _tap(keycode: Key) -> void:
	_send_key(keycode, true)
	await get_tree().physics_frame
	_send_key(keycode, false)
	await get_tree().physics_frame


func _send_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok  " + message)
	else:
		failures.append(message)
		print("  FAIL " + message)


func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func _restore(path: String, text: String) -> void:
	if text == "":
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


func _write_report() -> void:
	var path := ProjectSettings.globalize_path(REPORT_PATH)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("  WARN cannot write ", path)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("  report -> ", path)
