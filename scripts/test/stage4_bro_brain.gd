extends Node
## TBB-SHIFT-CORE-02 第 3–4 步：BRO BRAIN 四种神游状态 + 两种角色的行为差异。
## 固定步长推进真实 race.gd 的 _physics_process（不是另写一套模拟），
## 只关闭障碍和冲线，因为这里验证的是“没人管的伙伴会怎样”，不是通关。
##
## 证据类型：headless 自动化 + 窗口化截图（同一脚本）；不是真人试玩。
## 运行：
##   Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT \
##       res://scenes/stage4_bro_brain.tscn
## 输出：docs/reports/stage4-bro-brain.json，窗口化时另存 screenshots/brain-*.png

const Tuning = preload("res://scripts/systems/tuning.gd")
const OUT_PATH := "res://docs/reports/stage4-bro-brain.json"
const STEP := 1.0 / 60.0

var is_runner := false
var failures: Array[String] = []
var race
var data := {}
var sim := 0.0


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4BroBrainRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	Locale.language = "en"
	GameManager.start_race()
	await _wait_scene("race.tscn")
	await _frames(4)
	race = get_tree().current_scene
	_check(race != null, "race scene loaded")
	if race == null:
		_finish()
		return
	race.test_disable_hazards = true
	race.test_no_finish = true
	race.set_physics_process(false)
	# 本测试只观察“没人管会怎样”：清掉障碍组，避免一路碰撞/连击/Showtime
	# 把神游时钟冻住（Showtime 期间 BRO BRAIN 有意暂停）。
	race.hazard_groups = []
	race.entered_groups.clear()
	# 食物表在本测试里关掉：第 5 步单独验证“控制兔子时乌龟也能吃到”。
	race.boost_lanes = []
	race._snack_cache_sig = -1

	data["rabbit_stages"] = await _stages("rabbit")
	data["turtle_stages"] = await _stages("turtle")
	data["switch_recovery"] = _switch_recovery()
	data["rapid_shift"] = _rapid_shift()
	data["rabbit_air_control"] = _rabbit_air_control()
	data["turtle_settle"] = _turtle_settle()
	data["no_second_health_system"] = _no_second_health()
	_write_json()
	_finish()


## 让目标角色连续 12 s 无人控制，按 3/6/9/12 s 采样状态与行为量。
func _stages(who: String) -> Dictionary:
	race.reset_brains()
	GameManager.set_control("turtle" if who == "rabbit" else "rabbit")
	var brain = race.rabbit_brain if who == "rabbit" else race.turtle_brain
	var body = race.rabbit if who == "rabbit" else race.turtle
	var out := {"role": who, "transitions": {}, "samples": {}}
	var last := ""
	var marks := {180: "3.0s", 360: "6.0s", 540: "9.0s", 720: "12.0s"}
	var y_min := 9999.0
	var y_max := -9999.0
	var offset_max := 0.0
	var speed_min := 9999.0
	var air_scale_min := 9.0
	var daze_max := 0.0
	var accident := "NONE"
	sim = 0.0
	for i in 720:
		_tick(1)
		sim += STEP
		var st: String = brain.state_name()
		if st != last:
			out["transitions"][st] = snappedf(sim, 0.01)
			last = st
		var mount_point: Vector2 = race.turtle.get_mount_point()
		if who == "rabbit":
			offset_max = maxf(offset_max, absf(body.position.x - mount_point.x))
			air_scale_min = minf(air_scale_min, body.drift_air_scale())
			daze_max = maxf(daze_max, body.daze_time)
		else:
			y_min = minf(y_min, body.position.y)
			y_max = maxf(y_max, body.position.y)
			speed_min = minf(speed_min, body.speed)
		accident = GameManager.accident_state
		if marks.has(i + 1):
			out["samples"][marks[i + 1]] = _sample(who)
			if DisplayServer.get_name() != "headless" and (i + 1) in [360, 540, 720]:
				await _shot("brain-%s-%s.png" % [
					who, String(marks[i + 1]).replace(".", "_")])
	if who == "rabbit":
		out["offset_max_px"] = snappedf(offset_max, 0.1)
		out["air_scale_min"] = snappedf(air_scale_min, 0.01)
		out["daze_max"] = snappedf(daze_max, 0.01)
		# 12 s 无人管：不能自己掉水，也不能开始滑落。
		_check(race.mount.state == "RIDING" and accident == "NONE"
			and daze_max <= 0.001 and race.rabbit.slide <= 0.001,
			"rabbit idles 12 s without falling (mount=%s accident=%s daze=%.3f)"
			% [race.mount.state, accident, daze_max])
		_check(offset_max >= Tuning.DRIFT_MAX_OFFSET - 1.0,
			"rabbit drift visibly moves it toward the shell edge (%.1f px)"
			% offset_max)
		_check(air_scale_min <= 0.60,
			"rabbit MISCHIEF degrades air control (min %.2f)" % air_scale_min)
	else:
		out["y_min"] = snappedf(y_min, 0.1)
		out["y_max"] = snappedf(y_max, 0.1)
		out["speed_min"] = snappedf(speed_min, 0.1)
		# 上下晃，但不是持续下沉：两端都围绕巡航水深，误差不超过 20 px。
		_check(y_min >= Tuning.NEUTRAL_DEPTH - 20.0
			and y_max <= Tuning.NEUTRAL_DEPTH + 20.0,
			"turtle idles 12 s around cruise depth, never sinks (%.1f..%.1f)"
			% [y_min, y_max])
		_check(y_max - y_min >= 6.0,
			"turtle drift is visible as bobbing (range %.1f px)" % (y_max - y_min))
		_check(speed_min <= 205.0,
			"turtle drift trims cruise speed (min %.1f)" % speed_min)
		_check(accident == "NONE", "turtle idle causes no accident")
	var expected := {"DISTRACTED": 3.0, "RESTLESS": 6.0, "MISCHIEF": 9.0}
	for key in expected:
		var got := float(out["transitions"].get(key, -1.0))
		_check(absf(got - expected[key]) <= 0.05,
			"%s reaches %s at %.2f s (want %.1f)" % [who, key, got, expected[key]])
	_check(float(out["transitions"].get("CALM", -1.0)) <= 0.02,
		"%s starts CALM" % who)
	print("BRAIN STAGES %s: %s" % [who, JSON.stringify(out["transitions"])])
	return out


func _sample(who: String) -> Dictionary:
	if who == "rabbit":
		var mp: Vector2 = race.turtle.get_mount_point()
		return {
			"drift": snappedf(race.rabbit_brain.drift, 0.01),
			"state": race.rabbit_brain.state_name(),
			"offset_x": snappedf(race.rabbit.position.x - mp.x, 0.1),
			"offset_y": snappedf(race.rabbit.position.y - mp.y, 0.1),
			"air_scale": snappedf(race.rabbit.drift_air_scale(), 0.01),
		}
	return {
		"drift": snappedf(race.turtle_brain.drift, 0.01),
		"state": race.turtle_brain.state_name(),
		"y": snappedf(race.turtle.position.y, 0.1),
		"speed": snappedf(race.turtle.speed, 0.1),
	}


## SHIFT 立刻拿控制权，但不立刻清空神游；换走时未恢复的量保留。
func _switch_recovery() -> Dictionary:
	race.reset_brains()
	GameManager.set_control("turtle")
	_tick(600)
	var before: float = race.rabbit_brain.drift
	GameManager.set_control("rabbit")
	_tick(1)
	var after_shift: float = race.rabbit_brain.drift
	_check(after_shift >= before - 0.05,
		"SHIFT does not instantly clear drift (%.2f -> %.2f)" % [before, after_shift])
	_tick(23)
	var at_04: float = race.rabbit_brain.drift
	_check(absf(at_04 - after_shift) <= 0.02,
		"0.4 s of control does not recover yet (%.2f)" % at_04)
	_tick(36)
	var at_10: float = race.rabbit_brain.drift
	_check(at_10 <= after_shift - 0.5,
		"stable control recovers after the 0.5 s hold (%.2f -> %.2f)"
		% [after_shift, at_10])
	GameManager.set_control("turtle")
	_tick(30)
	var kept: float = race.rabbit_brain.drift
	_check(kept >= at_10 - 0.05,
		"switching away keeps unrecovered drift (%.2f -> %.2f)" % [at_10, kept])
	GameManager.set_control("rabbit")
	var frames := 0
	while race.rabbit_brain.drift > 0.0001 and frames < 900:
		_tick(1)
		frames += 1
	var seconds := frames * STEP
	_check(race.rabbit_brain.drift <= 0.0001 and seconds >= 2.0 and seconds <= 7.0,
		"remaining recovery is gradual, not instant (%.2f s)" % seconds)
	return {
		"before_shift": snappedf(before, 0.01),
		"after_shift": snappedf(after_shift, 0.01),
		"after_0_4s": snappedf(at_04, 0.01),
		"after_1_0s": snappedf(at_10, 0.01),
		"kept_after_switch_away": snappedf(kept, 0.01),
		"remaining_recovery_seconds": snappedf(seconds, 0.01),
	}


## 快速 SHIFT 不能把两人的神游一起磨掉：每次控制不到 0.5 s，恢复不启动。
func _rapid_shift() -> Dictionary:
	race.reset_brains()
	GameManager.set_control("turtle")
	_tick(600)
	var before: float = race.rabbit_brain.drift
	for i in 10:
		GameManager.toggle_control()
		_tick(6)
	var after: float = race.rabbit_brain.drift
	_check(after >= before - 0.05,
		"rapid SHIFT farms no recovery (%.2f -> %.2f)" % [before, after])
	_check(after <= before + 0.8,
		"rapid SHIFT also adds no surprise drift (%.2f -> %.2f)" % [before, after])
	return {"before": snappedf(before, 0.01), "after": snappedf(after, 0.01),
		"switches": 10}


## 真实差异：神游中的兔子在空中更难修正落点（不是只改一个显示数字）。
func _rabbit_air_control() -> Dictionary:
	var calm_dx := _air_drift_px(0.0)
	var mischief_dx := _air_drift_px(Tuning.DRIFT_CAP)
	_check(mischief_dx <= calm_dx - 5.0,
		"rabbit air correction is slower when drifting (%.1f vs %.1f px)"
		% [mischief_dx, calm_dx])
	return {"calm_dx": snappedf(calm_dx, 0.1),
		"mischief_dx": snappedf(mischief_dx, 0.1)}


func _air_drift_px(drift: float) -> float:
	race.mount.mark_riding()
	race.rabbit.reset()
	race.rabbit.drift = drift
	race.rabbit.drift_state = "CALM" if drift <= 0.0 else "MISCHIEF"
	var mp: Vector2 = race.turtle.get_mount_point()
	race.rabbit.attach(mp)
	race.rabbit.launch(mp, 220.0)
	var x0: float = race.rabbit.position.x
	Input.action_press("right")
	for i in 30:
		race.rabbit.tick_air(STEP, true)
	Input.action_release("right")
	var dx: float = race.rabbit.position.x - x0
	race.rabbit.attach(mp)
	race.mount.mark_riding()
	race.reset_brains()
	return dx


## 乌龟：高神游时被接管，壳还在晃；稳定操控几秒后回到巡航水深与满速。
func _turtle_settle() -> Dictionary:
	race.reset_brains()
	GameManager.set_control("rabbit")
	_tick(600)
	var idle_y0: float = race.turtle.position.y
	var idle_min := idle_y0
	var idle_max := idle_y0
	for i in 60:
		_tick(1)
		idle_min = minf(idle_min, race.turtle.position.y)
		idle_max = maxf(idle_max, race.turtle.position.y)
	GameManager.set_control("turtle")
	var ctl_min: float = race.turtle.position.y
	var ctl_max: float = ctl_min
	for i in 60:
		_tick(1)
		ctl_min = minf(ctl_min, race.turtle.position.y)
		ctl_max = maxf(ctl_max, race.turtle.position.y)
	var drift_at_takeover: float = race.turtle_brain.drift
	_tick(420)
	var settled_drift: float = race.turtle_brain.drift
	var settled_y: float = race.turtle.position.y
	var settled_speed: float = race.turtle.speed
	_check(idle_max - idle_min >= 6.0,
		"idle turtle bobbing range %.1f px" % (idle_max - idle_min))
	_check(drift_at_takeover >= 9.0,
		"turtle still drifting when taken over (%.2f s)" % drift_at_takeover)
	_check(ctl_max - ctl_min >= 4.0,
		"taken-over shell still wobbles before recovering (%.1f px)"
		% (ctl_max - ctl_min))
	_check(settled_drift <= 0.001 and absf(settled_y - Tuning.NEUTRAL_DEPTH) < 1.5
		and absf(settled_speed - race.turtle.base_speed) < 2.0,
		"stable control settles drift/depth/speed (%.2f / %.1f / %.1f)"
		% [settled_drift, settled_y, settled_speed])
	return {
		"idle_range_px": snappedf(idle_max - idle_min, 0.1),
		"takeover_range_px": snappedf(ctl_max - ctl_min, 0.1),
		"drift_at_takeover": snappedf(drift_at_takeover, 0.01),
		"settled_drift": snappedf(settled_drift, 0.01),
		"settled_y": snappedf(settled_y, 0.1),
		"settled_speed": snappedf(settled_speed, 0.1),
	}


## 神游不是第二套生命系统：不写 BRO METER，不产生事故。
func _no_second_health() -> Dictionary:
	var meter_before: int = GameManager.bro_meter
	var accidents_before: int = GameManager.accident_count
	race.reset_brains()
	GameManager.set_control("turtle")
	_tick(720)
	GameManager.set_control("rabbit")
	_tick(720)
	_check(GameManager.bro_meter == meter_before \
		and GameManager.accident_count == accidents_before \
		and GameManager.accident_state == "NONE",
		"24 s of drift writes no BRO METER slot and no accident")
	return {
		"bro_meter": GameManager.bro_meter,
		"accident_count": GameManager.accident_count,
		"accident_state": GameManager.accident_state,
	}


func _tick(n: int) -> void:
	for i in n:
		race._physics_process(STEP)


func _shot(file_name: String) -> void:
	await get_tree().process_frame
	race._save_shot(file_name)


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


func _write_json() -> void:
	var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if file == null:
		failures.append("write %s" % OUT_PATH)
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()


func _finish() -> void:
	Locale.language = "zh"
	if failures.is_empty():
		print("STAGE4 BRO BRAIN: PASS")
	else:
		print("STAGE4 BRO BRAIN: FAIL")
		for item in failures:
			print("  - " + item)
	print("BRO BRAIN data: " + JSON.stringify(data))
	get_tree().quit(0 if failures.is_empty() else 1)
