extends Node
## 阶段 3 完整赛道脚本化通关：从 0 跑到 66000，连续两次通关，
## 第二次走结算界面的 Retry。驾驶策略按本局实际障碍种类（race.hazard_groups，
## 含 Phase P 按种子抽定的食物后障碍）的五类动作驱动：
##   趴低（低飞鸟/低梁）-> 兔子 ↓
##   跳跃（低岩）      -> 兔子 ↑
##   跃起（鲨鱼）      -> 乌龟 ↑，整组被带高
##   下潜（水下拱门）  -> 乌龟 ↓，尾端自动上浮
##   组合（漂浮木）    -> 兔子 ↑ 后空中换乌龟 ↓，尾端自动上浮接人
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT res://scenes/stage3_playtest.tscn
## 截图：... res://scenes/stage3_playtest.tscn -- --capture（需要真实窗口）

const LevelDataScript = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")
const DURATION := 900.0
const LOG_PATH := "res://docs/reports/stage3-run.log"
const START_X := 400.0

var is_runner := false
var capture := false
var zh_run := false
var lines: Array[String] = []
var failures: Array[String] = []
var race
var seen_accidents := {}
var zones_seen := {}
var _captured_zones := {}
var _captured_relays := {}
var saw_boost := false
## 物理帧时钟：固定 1/60，逐帧累加。GameManager.race_time 走的是渲染帧
## delta，headless 下每次运行都不一样，用它做驾驶判断会让 A 组结果不可复现。
var sim_time := 0.0
## 驾驶阶段标记，只写进日志，方便对时间线定位。
var phase := ""
var max_accident_elapsed := 0.0
var stuck_elapsed := 0.0
var max_stuck := 0.0
# 看门狗状态放成员变量：lambda/局部变量不会跨帧保留。
var _wd_last_accident := "NONE"
var _wd_accident_elapsed := 0.0
var _wd_last_t := 0.0
var _wd_last_x := 0.0
var _wd_last_zone := 0
## 回归会真的跑完两圈，结算会按“更好就写”覆盖 best.json。
## 测完原样放回：正式纪录由制作人的试玩决定，不能被自动化刷新。
var _best_before := ""
var _best_existed := false


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage3PlaytestRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	capture = "--capture" in OS.get_cmdline_user_args()
	zh_run = "--zh" in OS.get_cmdline_user_args()
	_snapshot_best()
	await get_tree().process_frame
	await _run()


func _snapshot_best() -> void:
	_best_existed = FileAccess.file_exists(GameManager.BEST_PATH)
	if _best_existed:
		_best_before = FileAccess.get_file_as_string(GameManager.BEST_PATH)


func _restore_best() -> void:
	if _best_existed:
		var f := FileAccess.open(GameManager.BEST_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(_best_before)
			f.close()
	elif FileAccess.file_exists(GameManager.BEST_PATH):
		DirAccess.remove_absolute(GameManager.best_path_absolute())


func _run() -> void:
	Engine.time_scale = 3.0
	# 旧断言按英文写；直接改内存语言，不写 settings.json。
	# --zh 用于阶段 4 的中文完整流程证据，日志单独写，不覆盖阶段 3 记录。
	Locale.language = "zh" if zh_run else "en"
	_log("STAGE 3 FULL RUN  time_scale=3.0  capture=%s" % str(capture))
	GameManager.start_race()
	await _frames(3)
	race = get_tree().current_scene
	if race != null:
		race.test_no_overdrive = true
		# 全关自动驾驶只验证“55 组可跑完/计分闭合”。MISCHIEF 会主动改变
		# 速度/深度，让固定驾驶器出现一次非路线碰撞，改由 stage15 覆盖。
		race.test_no_mischief = true
	_check(race.scene_file_path.ends_with("race.tscn"), "race scene loaded")
	_check(GameManager.state == GameManager.GameState.RUNNING, "state RUNNING")
	_start_watchdog()

	var r1: Dictionary = await _run_once(1, false)

	if capture:
		await _save_shot("stage3_result.png")
		await _press(KEY_ENTER)
		await _frames(10)
		await _save_shot("stage3_menu.png")
		_log("CAPTURE  zone/result/menu screenshots written")
		_finish_ok()
		return

	# 第一次结算后按 R 重开，第二次通关必须走这条真实路径。
	await _press(KEY_R)
	await _frames(8)
	_check(_scene_is("race.tscn"), "R on result starts the retry race")
	_check(GameManager.state == GameManager.GameState.RUNNING, "retry state RUNNING")
	race = get_tree().current_scene
	# 第二圈是新的 race 实例：回归基线必须和第一圈同条件。
	# 过载/教学单独由 stage12_* 覆盖，这里关掉，否则会把“新实例默认开”误算成手感差异。
	if race != null:
		race.test_no_overdrive = true
		race.test_no_lessons = true
		race.test_no_mischief = true
	# 8 个渲染帧在 time_scale=3 下本身就可能推进 0.6–0.8 s；这里判“刚重开”，
	# 不是判某一帧的精确值。旧阈值 0.5 会在加载慢时误报。
	_check(not GameManager.finished and GameManager.race_time < 1.0,
		"retry clears finish state (race_time=%.2f)" % GameManager.race_time)
	_reset_watchdog_baseline()
	var r2: Dictionary = await _run_once(2, true)

	_check(r1["finish_time"] >= 240.0,
		"run 1 simulated >= 240 s (%.1f)" % r1["finish_time"])
	_check(r2["finish_time"] >= 240.0,
		"run 2 simulated >= 240 s (%.1f)" % r2["finish_time"])
	for result in [r1, r2]:
		var tag := "run %d" % result["index"]
		_check(result["zones"].has(1) and result["zones"].has(2)
			and result["zones"].has(3), tag + " visited all 3 zones")
		_check(result["passed"] >= 40,
			"%s passed >= 40 groups (%d/%d)" % [tag, result["passed"], result["total"]])
		_check(result["grade"] in ["S", "A", "B", "C", "D"],
			tag + " grade in S-D (%s)" % result["grade"])
	_check(r2["retry"], "run 2 started from result Retry")
	_check(max_accident_elapsed < 5.0,
		"no accident lasts >=5s (max %.2fs)" % max_accident_elapsed)
	_check(max_stuck <= 15.0, "no unrecoverable stall (max %.1fs)" % max_stuck)

	_check(FileAccess.file_exists(GameManager.BEST_PATH), "best.json exists")
	var parsed = JSON.parse_string(
		FileAccess.get_file_as_string(GameManager.BEST_PATH))
	_check(typeof(parsed) == TYPE_DICTIONARY, "best.json is valid JSON")
	if typeof(parsed) == TYPE_DICTIONARY:
		var ok: bool = parsed.has("best_time") and parsed.has("best_accidents") \
			and parsed.has("best_score") and parsed.has("best_streak")
		_check(ok, "best.json stores 4 record fields")
		_log("BEST  time=%s accidents=%s score=%s streak=%s  -> %s" % [
			str(parsed.get("best_time")), str(parsed.get("best_accidents")),
			str(parsed.get("best_score")), str(parsed.get("best_streak")),
			GameManager.best_path_absolute()])

	_log("")
	_log("RESULT  run1 time=%.1f score=%d grade=%s passed=%d accidents=%d" % [
		r1["finish_time"], r1["score"], r1["grade"], r1["passed"], r1["accidents"]])
	_log("RESULT  run2 time=%.1f score=%d grade=%s passed=%d accidents=%d  (Retry)" % [
		r2["finish_time"], r2["score"], r2["grade"], r2["passed"], r2["accidents"]])
	_log("RESULT  zones=%s  max_accident=%.2fs  max_stuck=%.1fs  failures=%d" % [
		str(zones_seen.keys()), max_accident_elapsed, max_stuck, failures.size()])
	for item in failures:
		_log("FAIL  " + item)
	_finish_ok()


func _finish_ok() -> void:
	_write_log()
	_restore_best()
	Engine.time_scale = 1.0
	if failures.is_empty():
		print("STAGE3 PLAYTEST: PASS")
		get_tree().quit(0)
	else:
		print("STAGE3 PLAYTEST: FAIL")
		for item in failures:
			print("  - " + item)
		get_tree().quit(1)


func _run_once(index: int, retry: bool) -> Dictionary:
	_log("---- RUN %d  (%s) ----" % [index, "RETRY" if retry else "ENTER"])
	sim_time = 0.0
	_zones_mark()

	await _autopilot()

	var start := Time.get_ticks_msec()
	while not GameManager.finished and Time.get_ticks_msec() - start < 20000:
		await get_tree().physics_frame
	_check(GameManager.finished, "run %d finish captured" % index)

	var stats := {
		"index": index,
		"retry": retry,
		"finish_time": GameManager.finish_time,
		"score": GameManager.total_score,
		"grade": GameManager.grade,
		"passed": race.passed_count(),
		"total": race.total_groups(),
		"zones": GameManager.zones_visited.duplicate(),
		"accidents": GameManager.accident_count,
		"casualties": GameManager.rabbit_casualties,
		"engine_failures": GameManager.turtle_failures,
		"showtime": GameManager.showtime_count,
		"streak": GameManager.best_streak,
	}
	_log("FINISH  run=%d time=%.1f score=%d grade=%s passed=%d/%d "
		% [index, stats["finish_time"], stats["score"], stats["grade"],
			stats["passed"], stats["total"]]
		+ "casualties=%d engine=%d show=%d streak=%d" % [
			stats["casualties"], stats["engine_failures"],
			stats["showtime"], stats["streak"]])
	# PHASE-1：正式跑里必须真的看得到捣乱动作，而不是只有系统存在。
	if race != null and race.get("mischief_log") != null:
		_log("MISCHIEF_LOG " + JSON.stringify(race.mischief_log))
	# FEEL-42：确认正式跑中鲨群三拍都发生，而不是只出老大/胖鲨。
	if race != null and race.get("_shark_pack_log") != null:
		_log("SHARK_PACK_LOG " + JSON.stringify(race._shark_pack_log))
		var pack_who := []
		for e in race._shark_pack_log:
			if String(e.get("event", "")) == "attack":
				pack_who.append(String(e.get("who", "")))
		_check(pack_who.has("leader") and pack_who.has("fat") and pack_who.has("thin"),
			"run %d shark pack three attacks %s" % [index, JSON.stringify(pack_who)])
	_check_score_table(index)

	start = Time.get_ticks_msec()
	while not _scene_is("result.tscn") and Time.get_ticks_msec() - start < 15000:
		await get_tree().physics_frame
	await _frames(2)
	_check(_scene_is("result.tscn"), "run %d reached result screen" % index)
	_check(GameManager.state == GameManager.GameState.RESULT,
		"run %d state RESULT" % index)
	if not capture:
		var texts: Array[String] = _label_texts(get_tree().current_scene)
		var joined := "\n".join(PackedStringArray(texts))
		if zh_run:
			_check(not joined.contains("总分") and joined.contains("干净通过")
				and joined.contains("失误") and joined.contains("比赛时间"),
				"run %d result shows time/mistakes/clean, no score (zh)" % index)
			_check(joined.contains("比赛时间")
				and joined.contains(Locale.grade_title(GameManager.grade)),
				"run %d result shows time and grade (zh)" % index)
			_check(joined.contains("最佳时间") and joined.contains("最低事故"),
				"run %d result shows best records (zh)" % index)
		else:
			_check(not joined.contains("TOTAL SCORE")
				and joined.contains("CLEAN PASSES") and joined.contains("MISTAKES")
				and joined.contains("RACE TIME"),
				"run %d result shows time/mistakes/clean, no score" % index)
			_check(joined.contains("RACE TIME")
				and joined.contains(Locale.grade_title(GameManager.grade)),
				"run %d result shows time and grade" % index)
			_check(joined.contains("BEST TIME") and joined.contains("BEST ACCIDENTS"),
				"run %d result shows best records" % index)

	return stats


# ---- 自动驾驶：按 LevelData 的 kind 逐组处理。 ----

## Phase P：本局实际障碍种类是装载时按种子抽定并写进 race.hazard_groups 的，
## 与 LevelData 的原始种类可能不同。自动驾驶必须读“抽到的那一份”，
## 否则 gate3/rock6/gate8 这类被换过种类的组仍按旧动作过，必然撞上。
func _live_groups() -> Array:
	if race != null and is_instance_valid(race) and not race.hazard_groups.is_empty():
		return race.hazard_groups
	return LevelDataScript.groups()


func _autopilot() -> void:
	var groups: Array = _live_groups()
	for i in groups.size():
		if GameManager.finished:
			return
		await _handle_group(groups[i])
		if capture:
			await _capture_zone_once()
	await _travel_to(LevelDataScript.WORLD_END - 40.0)


func _handle_group(g: Dictionary) -> void:
	var kind: String = g["kind"]
	var start := LevelDataScript.group_start(g)
	var end := LevelDataScript.group_end(g)
	if capture and String(g["group"]) in ["rock2", "beam3", "bird3", "gate4", "bird5", "log5", "beam7", "bird8", "bird9"] \
			and not _captured_relays.has(String(g["group"])):
		_captured_relays[String(g["group"])] = true
		await _save_shot("stage37_%s.png" % String(g["group"]))
	if race.turtle.position.x > end + 80.0:
		return
	match kind:
		"LOW_BIRD", "LOW_BEAM":
			await _crouch_under(start, end)
		"SURFACE_ROCK":
			await _jump_over(start, end)
		"SHARK":
			await _leap_shark(g, start, end)
		"DIVE_GATE":
			await _dive_gate(start, end)
		"FLOATING_LOG":
			await _log_combo(start, end)
		"HIGH_WALL":
			await _wall_ollie(start, end)
		_:
			_log("WARN  unknown kind %s (%s)" % [kind, g["group"]])
			await _settle_turtle(start - 120.0, 0.6, 300.0, 500.0)
			await _travel_to(end + 90.0, false)


## 兔子层低岩：跳过去。滞空 1.15 s，90 px 低岩在 220 龟速下约 0.4 s。
## 起跳高度是相对龟壳的：龟壳沉 120 px，岩顶就抬到兔子的起跳弧线里，
## 所以先在岩前把龟壳带回巡航水深（兔子不起作用时龟壳会一直往下走）。
## REBUILD-05 E2：动态障碍在 delay 秒后的横向位移（驾驶器只读，不改玩法）。
## 玩家在屏幕上看到的是它“现在”在哪，决定成败的是它“到达时”在哪；
## 速度恒定，所以能改的只有什么时候跳——读位置再往前推一个飞行时间。
func _motion_offset_x(g: Dictionary, delay: float = 0.0) -> float:
	if race == null or not race.has_method("hazard_offset"):
		return 0.0
	var motion: Dictionary = g.get("motion", {})
	if motion.is_empty() or String(motion.get("axis", "y")) != "x":
		return 0.0
	var amp := float(motion.get("amp", 0.0))
	var period := maxf(float(motion.get("period", 1.0)), 0.2)
	var t: float = float(race.hazard_clock) + delay
	return amp * sin(TAU * (t / period + float(motion.get("phase", 0.0))))


## CORE-FEEL-08 P0-A：兔子可能正在“走神”，起跳会晚半拍才执行。
## 会玩的玩家看见“BITT 走神了”会提前按——驾驶器也这么补偿，把按下点
## 往前挪 delay × 龟速 像素，让兔子离地的位置回到原来的设计点。
## 这不是绕过延迟：延迟仍然真实发生，只是驾驶器的按键更早。
func _press_lead_px(who: String = "rabbit") -> float:
	var react := float(race.drift_react_delay_ms(who)) / 1000.0
	return react * float(race.turtle.base_speed)


## 按住 ↑ 直到真的离地。走神的兔子最多晚 0.35 s，这里等到位再松手；
## 返回是否离地（不丢键：延迟结束后一定执行）。
func _press_up_until_airborne(max_steps: int = 30) -> bool:
	Input.action_press("up")
	var n := 0
	while n < max_steps and race.mount.state != "AIRBORNE" \
			and GameManager.accident_state == "NONE":
		await _step()
		n += 1
	Input.action_release("up")
	return race.mount.state == "AIRBORNE"


func _jump_over(start: float, end: float) -> void:
	phase = "jump"
	# 起跳点由“接人那一刻龟壳必须已经让开岩石”决定，不是兔子让开。
	# 滞空无人控龟，壳在 0.8 s 内从满速掉到 140，1.126 s 接人时只走了
	# 约 (1.126×速度 − 70) px；壳（半宽 48）要越过岩尾，所以
	# lead ≤ 这段距离 − 岩宽 − 48。跳早了回落时壳还在岩里，兔子一站上壳
	# 就和岩石相交，判成 RABBIT_STUN——旧路线里“落地即被撞”的根因。
	# 2026-11-13（PLAYFUL-04 全回归）：原来这里写死岩宽 90，但表里实际是
	# 110/150。rock11（w=150）按 90 算会晚跳 60 px，兔子落点只剩 9 px
	# 余量，下落弧线的后角在 1–4 px 内擦到岩石后上角（本次全回归真命中，
	# daze 3.2 s）。改为读本组实际宽度：这是驾驶器参数，不是玩法参数。
	# 速度要取赛段基础速：settle 会把龟速抬回满档，用“此刻速度”会算偏小。
	var spd: float = race.turtle.base_speed
	var shell_travel: float = 1.2 * spd - 70.0
	var rock_w: float = maxf(end - start, 1.0)
	var lead := clampf(shell_travel - (rock_w + 48.0), 55.0, 120.0)
	# 壳必须在巡航水深、龟速接近满档才起跳：起跳速度就是当时的龟速。
	# 壳沉 100 px 时弧线整体低 100 px，会撞在岩檐上。
	await _settle_turtle(start - lead - 100.0, 0.6, 300.0, 440.0)
	# 起跳前就把控制权交给兔子：兔子本来就得“自己跑”这一小段对位，而且
	# 切换之后它的滑落计时才会停。拖到起跳那一帧才换，计时已经在等待里
	# 顶到 3.3，换过去还要再站 0.5 s——落崖就是这么发生的。
	await _control_to("rabbit")
	var t1: float = sim_time
	var press_x: float = start - lead - _press_lead_px()
	while sim_time - t1 < 2.0 and race.turtle.position.x < press_x \
			and GameManager.accident_state == "NONE":
		await _step()
	_log("JUMP  x=%.0f rock=%.0f-%.0f y=%.0f spd=%.0f ctl=%s show=%s" % [
		race.turtle.position.x, start, end, race.turtle.position.y,
		race.turtle.speed, GameManager.current_control,
		str(race.showtime_active)])
	# “just pressed”只在按键被处理的那一帧成立：先按住，等真正离地再松手。
	# 同一帧按完就松开等于没按，兔子会原地骑进岩石（旧日志里 JUMP 后面没有
	# 任何 t= 轨迹行，就是起跳根本没发生）。
	if not await _press_up_until_airborne():
		_log("WARN  jump did not launch x=%.0f y=%.0f ctl=%s" % [
			race.turtle.position.x, race.turtle.position.y,
			GameManager.current_control])
	var guard := 0
	var next_log: float = sim_time
	while race.mount.state == "AIRBORNE" and guard < 140 			and GameManager.accident_state == "NONE":
		await _step()
		guard += 1
		if sim_time >= next_log:
			_log("JUMP  t=%.2f x=%.0f rab_y=%.0f rab_vy=%.0f tur=%.0f st=%s" % [
				sim_time, race.turtle.position.x, race.rabbit.position.y,
				race.rabbit.velocity.y, race.turtle.position.y, race.rabbit.state])
			next_log = sim_time + 0.15
	# 落地就收回乌龟：兔子握着控制权时壳一直在沉，迟收回几十像素就是几十像素深度。
	await _control_to("turtle")
	await _travel_to(end + 90.0, false)


## 兔子层低梁：趴下过。趴下 rect 比站姿低 32 px，梁底完全让开。
func _crouch_under(start: float, end: float) -> void:
	phase = "crouch"
	# 换人 + 趴下只要两三帧（0.05 s ≈ 10 px），停在梁前 55 px。
	# 梁前的每一像素都是“兔子握权、壳在下沉”：130 px 的余量让整段趴下
	# 变成 2.6 s、出口 y=600～690、乌龟计时 2.8～3.5（离 3.6 只剩 0.1 s），
	# 氧气也在那一段被抽干。55 px 够按两帧，出口能压在 500 上下。
	# CORE-FEEL-08 P0-A：走神的兔子听 ↓ 会晚半拍（最多 0.26 s ≈ 57 px）。
	# 会玩的玩家看见“BITT 走神了”会提前趴下——驾驶器也提前 lead px 停，
	# 并且等它真的趴下（CROUCHING）再往梁里走，否则站着进了判定带。
	await _settle_turtle(start - 55.0 - _press_lead_px(), 0.6, 220.0, 380.0)
	await _control_to("rabbit")
	Input.action_press("down")
	var crouch_wait := 0
	while crouch_wait < 30 and race.rabbit.state != "CROUCHING" \
			and GameManager.accident_state == "NONE":
		await _step()
		crouch_wait += 1
	var guard := 0
	# 兔子矩形半宽 16，过 end+24 就再也碰不到梁；再多守 26 px 只是让乌龟
	# 多沉一截——壳从巡航水深沉 160 px/s 时，50 px 的余量等于 50 px 的深度。
	# 判据必须用兔子的真实位置：SHIFT-02 起未受控的神游偏移（最多 22+7 px）
	# 和滑移会把兔子整体往后拖，按乌龟 x 收手会让它带偏移站起来、刮到梁尾。
	while race.rabbit.position.x < end + 24.0 and guard < 300 			and GameManager.accident_state == "NONE":
		await _step()
		guard += 1
	Input.action_release("down")
	_log("CROUCH exit x=%.0f y=%.0f tur=%.2f rab=%.2f" % [
		race.turtle.position.x, race.turtle.position.y,
		race.turtle.daze_time, race.rabbit.daze_time])
	# 过梁立刻交回乌龟：低梁是兔子的活，梁一过兔子就没理由继续握着控制权。
	await _control_to("turtle")


## C. 鲨鱼：乌龟受控按 ↑ 跃起，整组被带高，兔子不用做任何动作。
func _leap_shark(g: Dictionary, start: float, end: float) -> void:
	phase = "leap"
	# 跃起的弧线相对龟壳算：壳必须在巡航水深，跳起来才够高。
	# 起跳点让“壳与鲨鱼的 x 重叠窗口”整个落在弧线高处：
	# 壳半宽 45（96-2*3 的碰撞体），鲨鱼 y 274~480，壳底 <=274 要求
	# p 在 0.18~0.82；把重叠中点对到顶点（p=0.5）最稳。
	# 顶点在起跳后 0.8 s，入口在重叠中点前 0.8v-80 px；
	# 按键还要跨 2~3 个物理帧才被消费（约 0.13 s），一并前移。
	var v: float = maxf(race.turtle.base_speed, 1.0)
	await _settle_turtle(start - (0.93 * v - 35.0) - _press_lead_px("turtle"),
		0.6, 300.0, 380.0)
	# REBUILD-05 E2：鲨鱼会前后巡游。按“弧顶压到危险区中心”那一刻它的位置挪起跳点
	# （提前量 + 半宽 = 0.93 s），不是按此刻位置、也不是背固定秒数。
	var patrol := _motion_offset_x(g, 0.93)
	if absf(patrol) > 0.5:
		race.turtle.position.x += patrol
		race.rabbit.attach(race.turtle.get_mount_point())
		_log("LEAP  patrol offset %+.0f px -> jump x=%.0f" % [
			patrol, race.turtle.position.x])
	await _control_to("turtle")
	# “just pressed”只在按键被处理的那一帧成立：按住等真正起跳再松手。
	# CORE-FEEL-08 P0-A：乌龟走神时 ↑ 也会晚半拍，这里等到 leap 真的开始。
	Input.action_press("up")
	var leap_wait := 0
	while leap_wait < 30 and not race.turtle.leap_active \
			and GameManager.accident_state == "NONE":
		await _step()
		leap_wait += 1
	Input.action_release("up")
	if not race.turtle.leap_active:
		_log("WARN  leap did not start x=%.0f y=%.0f" % [
			race.turtle.position.x, race.turtle.position.y])
	var guard := 0
	while guard < 240 and GameManager.accident_state == "NONE":
		if not race.turtle.leap_active and race.turtle.position.x >= end + 80.0:
			break
		await _step()
		guard += 1
	_log("LEAP  exit x=%.0f y=%.0f tur=%.2f" % [
		race.turtle.position.x, race.turtle.position.y, race.turtle.daze_time])
	await _travel_to(end + 120.0, false)


## E. 高墙（BRO OLLIE）：乌龟跃起把壳送进窗口，空中 SHIFT 给兔子再按 ↑ 蹬踏，
## 兔子从墙楣顶上过去，落回壳上。只跃起时兔子必撞墙楣（见 stage4_proto 的对照）。
func _wall_ollie(start: float, end: float) -> void:
	phase = "ollie"
	# 跃起最高点在起跳后 0.8 s：起跳点按“最高点正对墙面”摆，
	# 壳进窗口时兔子正好在墙楣高度（它比壳高 60 px，正好被楣挡住）。
	var lead: float = race.turtle.base_speed * 0.8
	await _settle_turtle(start - lead - _press_lead_px("turtle"), 0.6, 300.0, 380.0)
	await _control_to("turtle")
	# CORE-FEEL-08 P0-A：乌龟走神时 ↑ 晚半拍，按住等到 leap 真的开始。
	Input.action_press("up")
	var leap_wait := 0
	while leap_wait < 30 and not race.turtle.leap_active \
			and GameManager.accident_state == "NONE":
		await _step()
		leap_wait += 1
	Input.action_release("up")
	if not race.turtle.leap_active:
		_log("WARN  wall leap did not start x=%.0f y=%.0f" % [
			race.turtle.position.x, race.turtle.position.y])
	# 蹬踏点：墙前 70 px。兔子蹬踏后要 0.19 s 才能把体底抬到墙楣上沿
	# (86) 以上，260 px/s 下 70 px = 0.27 s，220/240/260 三种基速都在窗口内
	# （实测通过高度约 50 px，门槛 62 px）。
	# 2026-11-13（REBUILD-05 E3）：原来写 90 px，正好压在落壳窗口的外沿。
	# 探针 stage5_e3_ollie 逐档量过（220 px/s，墙 13300）：
	#   蹬踏点 40…85 px 落壳成功，90 px 起全部 RABBIT_WATER——
	#   跃起 1.6 s 结束在墙后 176 px，兔子飞行 ≈1.2 s，
	#   蹬踏点晚于 88 px 就“壳还没回到水面、兔子先落水”。改到 70 px，
	#   两侧各留 ≈15 px 余量。
	# 先换人再等：_control_to 自己会走 1~2 个物理帧（time_scale 3、
	# 260 px/s 时一帧 13 px），换人放在等待前，蹬踏点才不会被换人延迟顶到墙根。
	var guard := 0
	while guard < 240 and race.turtle.position.x < start - 150.0 \
			and GameManager.accident_state == "NONE":
		await _step()
		guard += 1
	await _control_to("rabbit")
	guard = 0
	var kick_x: float = start - 70.0 - _press_lead_px()
	while guard < 240 and race.turtle.position.x < kick_x \
			and GameManager.accident_state == "NONE":
		await _step()
		guard += 1
	Input.action_press("up")
	await _step()
	await _step()
	Input.action_release("up")
	if race.mount.state != "AIRBORNE":
		_log("WARN  ollie kick did not launch x=%.0f leap=%s" % [
			race.turtle.position.x, str(race.turtle.leap_active)])
	# 壳走完整个跃起弧线，兔子落回壳上；等落稳再交给下一段。
	guard = 0
	while guard < 300 and GameManager.accident_state == "NONE":
		if race.mount.state == "RIDING" and not race.turtle.leap_active \
				and race.turtle.position.x >= end + 80.0:
			break
		await _step()
		guard += 1
	_log("OLLIE exit x=%.0f y=%.0f ctl=%s tur=%.2f rab=%.2f" % [
		race.turtle.position.x, race.turtle.position.y,
		GameManager.current_control, race.turtle.daze_time, race.rabbit.daze_time])
	# 连招的落脚是硬条件：兔子没回到壳上、或这一撞出了事故，本段就不算通过。
	# 以前只看“组数够不够”，墙 3（260 px/s）掉 Water 也记成 55/55，属于掩盖。
	_check(GameManager.accident_state == "NONE" and race.mount.state == "RIDING",
		"wall ollie at x=%.0f lands back on shell (accident=%s mount=%s)" % [
			start, GameManager.accident_state, race.mount.state])
	await _travel_to(end + 140.0, false)


## D. 水下拱门：乌龟受控按住 ↓ 潜过去；尾端之后不松手也会自动上浮。
func _dive_gate(start: float, end: float) -> void:
	phase = "dive"
	# 进门必须龟壳在巡航水深：上一段兔子握权时壳已经沉了，潜深会叠加。
	# CORE-FEEL-08 P0-A：乌龟走神时 ↓ 晚半拍，提前 lead px 开始沉。
	await _settle_turtle(start - 160.0 - _press_lead_px("turtle"),
		0.6, 300.0, 380.0)
	await _control_to("turtle")
	Input.action_press("down")
	var guard := 0
	while guard < 600 and GameManager.accident_state == "NONE":
		if race.turtle.position.x >= end + 90.0:
			break
		await _step()
		guard += 1
	# 尾端之后继续按着 ↓：自动上浮是动作的一部分，不能等玩家松手才回巡航。
	var surf_start: float = sim_time
	while sim_time - surf_start < 2.0 and GameManager.accident_state == "NONE":
		if race.turtle.position.y <= Tuning.NEUTRAL_DEPTH + 2.0:
			break
		await _step()
	Input.action_release("down")
	_log("DIVE  exit x=%.0f y=%.0f tur=%.2f" % [
		race.turtle.position.x, race.turtle.position.y, race.turtle.daze_time])
	await _travel_to(end + 140.0, false)


## B. 组合漂浮木：兔子先跳，空中换乌龟，按住 ↓ 潜过去，尾端自动上浮接人。
func _log_combo(start: float, end: float) -> void:
	phase = "combo"
	await _settle_turtle(start - 250.0, 0.6, 300.0, 380.0)
	# 起跳点由壳的“前沿”决定：壳半宽 48，前沿比中心早 48 px 进浮木，
	# 那时壳顶必须已经低于浮木下沿(410) -> 下潜要提前 ~0.32 s 完成。
	# 起跳太早则兔子落得太早、壳还没浮到 454 的接人带里。
	# 兔身底 < 浮木顶(192) 的时间窗 0.21~0.99 s 必须盖住兔子过木的整段行程
	# (lead-16..lead+56)/v；下潜侧壳顶要沉到 410 以下约 0.22 s，换人还要 ~0.18 s。
	# 两侧合并后窗口取中点：lead = 0.7v - 2。
	await _control_to("rabbit")
	var press_x: float = start - (float(race.turtle.base_speed) * 0.7 - 2.0) \
		- _press_lead_px()
	var guard := 0
	while guard < 240 and GameManager.accident_state == "NONE":
		# 用兔子自己的 x 判起跳点：未受控时它会比壳落后十几到二十几像素，
		# 按乌龟 x 起跳等于把整条弧线往后挪，兔子会擦到浮木尾端上角
		# （实测 log1 x=6441 y=175 FALLING_WATER）。人也是看着兔子按跳的。
		if race.rabbit.position.x >= press_x:
			break
		await _step()
		guard += 1
	if not await _press_up_until_airborne():
		_log("WARN  combo jump did not launch x=%.0f rab=%s mount=%s tur_y=%.0f ctl=%s pending=%s" % [race.turtle.position.x, race.rabbit.state, race.mount.state, race.turtle.position.y, GameManager.current_control, str(race.rabbit.snack_jump_pending)])
	# 离地后只等一帧就换乌龟：跳跃在按键被处理的那一帧已经离地，换人不取消它。
	# 等 0.12 s 会让下潜晚 ~30 px；浮木下沿离巡航壳顶只有 12 px，
	# 下潜起步晚半拍就撞下沿（实测 8 次全撞），所以这里把余量全吃满。
	# 下潜键在换人前按住：换人那一帧就开始潜，壳的前沿才有时间降到浮木下沿之下。
	Input.action_press("down")
	await _control_to("turtle")
	guard = 0
	while guard < 600 and GameManager.accident_state == "NONE":
		if race.turtle.position.x >= end + 30.0:
			break
		await _step()
		guard += 1
	# 尾端过后松开 ↓：壳按浮力上浮，兔子落回壳上。
	Input.action_release("down")
	var settle_start: float = sim_time
	var landed := false
	while sim_time - settle_start < 2.5 and GameManager.accident_state == "NONE":
		if race.mount.state == "RIDING":
			if race.turtle.position.y <= Tuning.NEUTRAL_DEPTH + 2.0:
				landed = true
				break
		await _step()
	_log("COMBO exit x=%.0f y=%.0f landed=%s tur=%.2f rab=%.2f" % [
		race.turtle.position.x, race.turtle.position.y, str(landed),
		race.turtle.daze_time, race.rabbit.daze_time])
	await _travel_to(end + 160.0, false)

func _calm_rabbit(limit: float, limit_x := 1.0e9, turtle_cap := 6.0) -> void:
	# 控制兔子直到滑落计时降下来；乌龟同时开始神游，所以设时间上限、
	# 乌龟风险上限和前进上限。乌龟被控制时风险会冻结，所以允许它带点风险。
	# Showtime 期间抢不回兔子（控制权锁在乌龟），等表演结束反而会把跑道吃光。
	phase = "calm"
	if race.showtime_active:
		return
	var start: float = sim_time
	await _control_to("rabbit")
	while sim_time - start < limit and not race.showtime_active \
			and race.rabbit.daze_time > 0.15 \
			and race.turtle.daze_time < turtle_cap \
			and race.turtle.position.x < limit_x:
		await _step()


func _travel_to(target: float, prep := true, balance := true) -> void:
	# 开阔水域按“谁的风险高就控谁”平衡两人：不追求固定节拍，
	# 只把 daze 差压在 0.4 s 内，避免一个人先到 3.6 s。
	# 换人后至少守 0.9 s：恢复要站稳 0.5 s 才开始，来回点 SHIFT 等于谁都不恢复。
	phase = "travel"
	# 开阔水域的节拍：默认乌龟握着（壳停在巡航水深），兔子计时见长才交给兔子
	# 一段恢复时间，收完就交回乌龟。两人都不许过 1.2 s——新模型里兔子握着
	# 控制权时龟壳一直在沉，一人一把梭会把壳压到障碍深度以下。
	var hold_until := 0.0
	while sim_time < DURATION and race.turtle.position.x < target:
		# 紧急换人不吃 hold_until：冷却只为防止来回连点，不能把计时放到事故线。
		# 事故线 9.5 s（旧模型 3.6），阈值按比例放宽，别把自动驾驶练成高频切换。
		var urgent: bool = race.rabbit.daze_time > 8.0 \
			or race.turtle.daze_time > 8.0
		# REBUILD-06 P4：食物前的主动选择。两个人都会伸手，这里按遭遇序号轮换
		# （第 1/3/5… 个给乌龟、第 2/4/6… 个给兔子），只为让回归同时覆盖
		# 两种吃法；这是自动驾驶的输入策略，不是游戏规则。切完守 1.4 s，
		# 覆盖“320 px ÷ 区速（最快 1.33 s）后接触”的那一次判定。
		var snack_want: String = _snack_control_want()
		if snack_want != "" and GameManager.current_control != snack_want \
				and not race.showtime_active and race.mount.state == "RIDING" \
				and GameManager.accident_state == "NONE":
			await _control_to(snack_want)
			hold_until = sim_time + 1.4
		if balance and not race.showtime_active and race.mount.state == "RIDING" \
				and GameManager.accident_state == "NONE" \
				and (sim_time >= hold_until or urgent):
			var ctl: String = GameManager.current_control
			# 深度也是节拍的一部分：兔子握权时壳在沉（氧气线 = 334 + 80），
			# 所以壳还深的时候不换人，沉过 410 就先把兔子交给乌龟抬回来。
			# 计时逼近滑落（3.6）时优先级高于深度：摔兔子比壳沉几十像素更贵。
			# 兔子段收短（回到 1.1 而不是 0.6）：兔子握权时壳在沉，1.1 s 只沉
			# 90 px，浮力半秒就能抬回来；收到 0.6 要多握半秒，白送 50 px 深度。
			# 带宽按深度实测调宽：收回到 1.1 时兔子段要 1.4 s、壳白沉 120 px，
			# 平均深度因此抬到 450～490，下沉门带着 460 进墙就必沉到 700（事故）。
			# 1.6 收手：兔子段 0.9 s、沉 70 px，乌龟段 1.2 s 抬得回来。
			if ctl == "turtle" and (race.turtle.position.y < 400.0
					and race.rabbit.daze_time > 5.0
					or race.rabbit.daze_time > 8.0):
				await _control_to("rabbit")
				hold_until = sim_time + 1.0
			elif ctl == "rabbit" and (race.rabbit.daze_time < 3.0 \
					or race.turtle.daze_time > 4.5 \
					or race.turtle.position.y > 410.0):
				await _control_to("turtle")
				hold_until = sim_time + 1.0
		await _step()
	# 出口收拾：平衡循环可能在“兔子计时 2.6”那一头停下，把 2.6 原样交给下一段。
	# 下一段开头是乌龟收尾（兔子没人管），高计时再加 1.5 s 就危险了。
	# 交出去之前先压回 1.4（新窗口下 1.2 s 回烧能收 1.7 s）。
	if balance and not race.showtime_active and race.mount.state == "RIDING" \
			and GameManager.accident_state == "NONE" \
			and GameManager.current_control == "turtle" \
			and race.rabbit.daze_time > 2.5:
		await _control_to("rabbit")
		var te: float = sim_time
		while sim_time - te < 1.2 and race.rabbit.daze_time > 1.4 \
				and race.turtle.daze_time < 3.0 \
				and race.turtle.position.x < target + 90.0 \
				and GameManager.accident_state == "NONE":
			await _step()
	if prep:
		await _prepare_rabbit()


## 兔子动作和下沉门都要求龟壳在巡航水深：兔子握着控制权时龟壳一直在沉，
## 沉 100 px 之后跳跃弧线够不到岩顶，下沉门也来不及再沉到墙底之下。
## 动作前先把控制权交回乌龟，让浮力把壳抬回 334、下沉计时落下去。
func _settle_turtle(target_x: float, rabbit_target := 0.6, rise_px := 300.0,
		depth_target := 400.0) -> void:
	# 动作前把局面收干净：乌龟回计时、壳尽量抬回 334，兔子计时也要低。
	# 顺序很重要——兔子收计时的时候壳在沉，所以那一段必须离目标还有余量。
	if GameManager.accident_state != "NONE":
		await _wait_accident_clear(4.0)
	# 1) 平衡走位到目标前 rise_px：这一段是乌龟回计时的地方。
	await _travel_to(target_x - rise_px, false, true)
	# 2) 兔子计时按“最后一段没人管它会涨多少”预估，而不是看当前值。
	#    旧写法只看当前 daze：兔子 0.05 时不做接管，最后一段 3 s 全按乌龟控，
	#    到动作点正好 3.3（掉崖边上）。组合岩前那一次就是这么摔的。
	var spd: float = maxf(race.turtle.speed, 80.0)
	var proj: float = maxf(target_x - race.turtle.position.x, 0.0) / spd
	# 事故线 9.5 s：投影到动作点超过 5.0 才提前收；收 1.4～2.0 s 能回 2.2～3.7 s。
	if race.rabbit.daze_time + proj > 5.0 and race.turtle.daze_time < 4.0 \
			and race.turtle.position.x < target_x - 150.0:
		await _control_to("rabbit")
		var tc: float = sim_time
		while sim_time - tc < 2.0 and race.rabbit.daze_time > 1.0 \
				and race.turtle.daze_time < 5.0 \
				and race.turtle.position.x < target_x - 150.0 \
				and GameManager.accident_state == "NONE":
			await _step()
	# 3) 收尾只走到 target，不再“追深度”：追深度会冲过目标几十到几百像素，
	#    把下一段的路线吃掉——空气杆那次冲了 370 px，组合岩的接管点只剩 7 px。
	_log("SETTLE[%s] t=%.2f x=%.0f y=%.0f tur=%.2f rab=%.2f target=%.0f room=%.0f" % [
		phase, sim_time, race.turtle.position.x, race.turtle.position.y,
		race.turtle.daze_time, race.rabbit.daze_time,
		target_x, target_x - race.turtle.position.x])
	await _control_to("turtle")
	var t0: float = sim_time
	while sim_time - t0 < 3.0 and race.turtle.position.x < target_x \
			and GameManager.accident_state == "NONE":
		# 收尾这段没人管兔子。计时逼近 9.5 时必须插一段兔子回烧，
		# 否则收尾本身就会摔一次（旧日志 20.4k 处的滑落）。
		if race.rabbit.daze_time > 6.0:
			await _control_to("rabbit")
			var tb: float = sim_time
			while race.rabbit.daze_time > 4.8 and sim_time - tb < 1.2 \
					and GameManager.accident_state == "NONE":
				await _step()
			await _control_to("turtle")
		await _step()
	if race.turtle.position.y > depth_target:
		_log("WARN  settle deep x=%.0f y=%.0f daze_t=%.2f" % [
			race.turtle.position.x, race.turtle.position.y, race.turtle.daze_time])


func _prepare_rabbit() -> void:
	# 新模型里低岩/低梁只能靠兔子动作过；Showtime 锁控 1.8 s，
	# 撞上障碍就是白送一次事故。用 SHIFT 中止表演再换人（GDD 6.6 允许）。
	if GameManager.accident_state != "NONE":
		await _wait_accident_clear(6.0)
	await _control_to("rabbit")


func _prepare_turtle() -> void:
	# Showtime 会把控制权直接锁给乌龟；兔子在表演姿势里贴着壳顶，
	# 等表演结束再下潜只会把跑道吃光，正好撞进头顶障碍。
	# 表演期间照常接管乌龟（控制权本来就在乌龟），该潜就潜。
	if GameManager.accident_state != "NONE":
		await _wait_accident_clear(6.0)
	await _control_to("turtle")


func _wait_accident_clear(limit: float) -> void:
	var start: float = sim_time
	while GameManager.accident_state != "NONE" and sim_time - start < limit:
		await _step()


func _until_x(target: float, limit := 40.0) -> void:
	var start: float = sim_time
	while sim_time < DURATION:
		if race.turtle.position.x >= target:
			return
		if sim_time - start > limit:
			_log("WARN  wait x=%.0f timed out at x=%.0f" % [
				target, race.turtle.position.x])
			return
		await _ensure_turtle()
		await _step()


## P4：前方 320 px 内有没吃的食物时，这一口该给谁（按遭遇序号轮换）。
## 只给自动驾驶用；返回 "" 表示当前没有要抢的食物。
func _snack_control_want() -> String:
	if race.snack_interest_x < 0.0:
		return ""
	var list: Array = race._snack_list()
	for i in list.size():
		var enc: Dictionary = list[i]
		if absf(float(enc["x"]) - race.snack_interest_x) < 1.0:
			return "rabbit" if i % 2 == 1 else "turtle"
	return ""


func _control_to(target: String) -> void:
	# 已经握着目标就别再等：Showtime 期间控制权本来就在乌龟，
	# 傻等表演结束会让乌龟带着兔子在壳上撞进头顶障碍。
	if GameManager.current_control == target:
		return
	var start: float = sim_time
	while sim_time - start < 6.0:
		if race.showtime_active:
			# 表演期间不能换人；中止表演会让兔子直接进入滑落读秒（代价更大），
			# 所以等它自己演完。正常路线靠 race 的 900 px 空档保证不在表演期间过障碍。
			await _step()
			continue
		if GameManager.current_control == target:
			return
		GameManager.toggle_control()
		if "--trace" in OS.get_cmdline_user_args():
			_log("SWITCH->%s t=%.2f x=%.0f rab=%.2f tur=%.2f phase=%s" % [
				target, sim_time, race.turtle.position.x,
				race.rabbit.daze_time, race.turtle.daze_time, phase])
		await _step()
	_log("WARN  control_to %s timed out (control=%s)" % [
		target, GameManager.current_control])


func _surface() -> void:
	# 新模型没有上浮键：收回控制权，浮力自己把壳抬回巡航水深。
	var ref: float = race.surface_ref()
	if race.turtle.position.y <= ref + 6.0:
		return
	phase = "surface"
	await _ensure_turtle()
	var start: float = sim_time
	while sim_time - start < 5.0 and race.turtle.position.y > ref + 6.0:
		await _step()


func _ensure_turtle() -> void:
	# Showtime 会把控制权交给乌龟；表演结束时又还给原来的一方。
	# 下潜/通过/上浮都必须确认还在操作乌龟，否则只能看着它下沉。
	if race.showtime_active:
		return
	if GameManager.current_control != "turtle":
		await _control_to("turtle")


# ---- 看门狗与日志。 ----

func _start_watchdog() -> void:
	_reset_watchdog_baseline()
	var watchdog := Timer.new()
	watchdog.wait_time = 0.1
	watchdog.autostart = true
	add_child(watchdog)
	watchdog.timeout.connect(_watchdog_tick)


func _reset_watchdog_baseline() -> void:
	_wd_last_x = race.turtle.position.x
	_wd_last_t = GameManager.race_time
	_wd_last_accident = "NONE"
	_wd_accident_elapsed = 0.0
	_wd_last_zone = GameManager.zone


func _watchdog_tick() -> void:
	# 结算/换场景期间 race 已被释放，定时器还会再响一次。
	if race == null or not is_instance_valid(race):
		return
	var t: float = GameManager.race_time
	if GameManager.turtle_speed > 340.0:
		saw_boost = true
	if GameManager.accident_state != _wd_last_accident:
		if GameManager.accident_state != "NONE":
			seen_accidents[GameManager.accident_state] = true
			_log("t=%6.1f  ACCIDENT %s  control=%s x=%.0f zone=%d phase=%s" % [
				t, GameManager.accident_state, GameManager.current_control,
				race.turtle.position.x, GameManager.zone, phase])
			_log("        turtle=(%.0f,%.0f) rabbit=(%.0f,%.0f) rab=%s slide=%.2f "
				% [race.turtle.position.x, race.turtle.position.y,
					race.rabbit.position.x, race.rabbit.position.y,
					race.rabbit.state, race.rabbit.slide]
				+ "showtime=%s mount=%s" % [
					str(race.showtime_active), race.mount.state])
			_log("        hits=%s down=%s up=%s daze_r=%.2f daze_t=%.2f" % [
				_intersecting_groups(),
				str(Input.is_action_pressed("down")), str(Input.is_action_pressed("up")),
				race.rabbit.daze_time, race.turtle.daze_time])
		else:
			_log("t=%6.1f  RECOVERED  control=%s x=%.0f" % [
				t, GameManager.current_control, race.turtle.position.x])
		_wd_last_accident = GameManager.accident_state
	if GameManager.accident_state != "NONE":
		_wd_accident_elapsed += 0.1
		max_accident_elapsed = maxf(max_accident_elapsed, _wd_accident_elapsed)
	else:
		_wd_accident_elapsed = 0.0
	if GameManager.zone != _wd_last_zone:
		_wd_last_zone = GameManager.zone
		zones_seen[GameManager.zone] = true
		_log("t=%6.1f  ZONE %d %s  x=%.0f" % [
			t, GameManager.zone, GameManager.zone_name_text, race.turtle.position.x])
	if t - _wd_last_t >= 5.0:
		var moved: float = race.turtle.position.x - _wd_last_x
		if moved < 40.0 and GameManager.accident_state == "NONE":
			stuck_elapsed += t - _wd_last_t
			max_stuck = maxf(max_stuck, stuck_elapsed)
		else:
			stuck_elapsed = 0.0
		_wd_last_x = race.turtle.position.x
		_wd_last_t = t
		_log("t=%6.1f  x=%6.0f y=%.0f zone=%d control=%s mount=%s phase=%s "
			% [t, race.turtle.position.x, race.turtle.position.y, GameManager.zone,
				GameManager.current_control, race.mount.state, phase]
			+ "rab=%s tur=%s oxy=%.1f combo=%d show=%d passed=%d" % [
				race.rabbit.state, race.turtle.state, GameManager.oxygen,
				GameManager.combo, GameManager.showtime_count, race.passed_count()])


func _zones_mark() -> void:
	zones_seen[1] = true
	_wd_last_zone = 1


func _intersecting_groups() -> String:
	# 事故瞬间列出所有与乌龟/兔子身体相交的障碍组；只用于定位，不参与判定。
	var hits: Array[String] = []
	var t_rect: Rect2 = race.turtle.get_body_rect()
	var r_rect: Rect2 = race.rabbit.get_body_rect()
	for g in _live_groups():
		for r in g["rects"]:
			if t_rect.intersects(r):
				hits.append("%s:turtle" % g["group"])
			if r_rect.intersects(r):
				hits.append("%s:rabbit" % g["group"])
	return "none" if hits.is_empty() else ",".join(hits)


# ---- 截图（仅 --capture：真实窗口）。 ----

func _capture_zone_once() -> void:
	if race == null or not is_instance_valid(race):
		return
	var zid: int = race.zone_id()
	if _captured_zones.has(zid):
		return
	_captured_zones[zid] = true
	await _save_shot("stage3_zone%d.png" % zid)


func _save_shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	var image := get_viewport().get_texture().get_image()
	var path := dir.path_join(file_name)
	image.save_png(path)
	print("CAPTURE ", path)


# ---- 工具。 ----

func _scene_is(name: String) -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path.ends_with(name)


func _label_texts(root: Node) -> Array[String]:
	var out: Array[String] = []
	if root is Label and (root as Label).text != "":
		out.append((root as Label).text)
	for child in root.get_children():
		out.append_array(_label_texts(child))
	return out


func _press(keycode: Key) -> void:
	_send_key(keycode, true)
	await get_tree().process_frame
	_send_key(keycode, false)
	await get_tree().process_frame


func _send_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _release_all() -> void:
	for action in ["up", "down", "left", "right", "boost", "shift"]:
		Input.action_release(action)


func _write_log() -> void:
	var path := ProjectSettings.globalize_path(
		"res://docs/reports/stage4-fullrun-zh.log" if zh_run else LOG_PATH)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("  WARN cannot write ", path)
		return
	for line in lines:
		file.store_line(line)
	file.close()
	print("  log -> ", path)


func _log(text: String) -> void:
	lines.append(text)
	print("  " + text)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## 推进一个物理帧并推进固定时钟。time_scale 会缩放每个物理帧的 delta，
## 所以这里乘上同一个系数；驾驶逻辑只用 sim_time 计时，保证每次运行一致。
func _step() -> void:
	await get_tree().physics_frame
	sim_time += (1.0 / 60.0) * Engine.time_scale


## 分数表可审计：本次每个组的得分都在 score_log 里，逐笔对表、按顺序重放，
## 重放结果必须等于运行时总分。这样“干净通过 +100、精准 +150、连招 +250/+300、
## 失误 -100、三格 -200、同一动作不重复计”不是看代码猜的，是这局跑出来的。
func _check_score_table(index: int) -> void:
	var counts := {"clean": 0, "precise": 0, "bro_dive": 0, "bro_ollie": 0,
		"mistake": 0, "joint": 0, "snack": 0, "showtime": 0,
		"relay_clever": 0, "relay_perfect": 0, "rescue_switch": 0}
	var bad: Array[String] = []
	var replay := 0
	for entry in GameManager.score_log:
		var reason: String = entry["reason"]
		var points: int = entry["points"]
		var want := 0
		if reason == "clean":
			counts["clean"] += 1
			want = 100
		elif reason == "bro_dive":
			counts["bro_dive"] += 1
			want = 250
		elif reason == "bro_ollie":
			counts["bro_ollie"] += 1
			want = 300
		elif reason == "joint":
			counts["joint"] += 1
			want = -200
		elif reason == "showtime":
			# FEEL-09 P0-D：Showtime 正常完成的一次性奖励。
			counts["showtime"] += 1
			want = 100
		elif reason.begins_with("precise:"):
			counts["precise"] += 1
			want = 150
		elif reason == "snack_switch":
			# PLAYFUL-04 §4：亲手喂到的一小笔奖励，只在分数表里多一行。
			counts["snack"] += 1
			want = Tuning.SNACK_SWITCH_BONUS
		elif reason == "relay_clever":
			counts["relay_clever"] += 1
			want = 50
		elif reason == "relay_perfect":
			counts["relay_perfect"] += 1
			want = 100
		elif reason == "rescue_switch":
			counts["rescue_switch"] += 1
			want = Tuning.RESCUE_SWITCH_BONUS
		elif reason.begins_with("mistake:"):
			counts["mistake"] += 1
			want = -100
		else:
			bad.append("unknown reason " + reason)
			continue
		if points != want:
			bad.append("%s paid %d want %d" % [reason, points, want])
		replay = maxi(replay + points, 0)
	_check(bad.is_empty(), "run %d score log follows the table (%s)"
		% [index, ", ".join(PackedStringArray(bad)) if not bad.is_empty()
			else "%d entries ok" % GameManager.score_log.size()])
	_check(replay == GameManager.total_score,
		"run %d replayed score log equals total (%d vs %d)" % [
			index, replay, GameManager.total_score])
	var pass_entries: int = counts["clean"] + counts["precise"] \
		+ counts["bro_dive"] + counts["bro_ollie"]
	_check(pass_entries == race.passed_count(),
		"run %d every passed group is scored (passed=%d scored=%d)" % [
			index, race.passed_count(), pass_entries])
	_check(race.hit_groups.is_empty(),
		"run %d has no hazard contacts (%s)" % [
			index, race.hit_groups.keys()])
	_check(counts["bro_dive"] == GameManager.combo_dive_count
		and counts["bro_ollie"] == GameManager.combo_ollie_count,
		"run %d combo counters match the log (dive %d/%d ollie %d/%d)" % [
			index, counts["bro_dive"], GameManager.combo_dive_count,
			counts["bro_ollie"], GameManager.combo_ollie_count])
	_log("SCORE   clean=%d precise=%d dive=%d ollie=%d snack=%d showtime=%d mistake=%d joint=%d -> %d"
		% [counts["clean"], counts["precise"], counts["bro_dive"],
			counts["bro_ollie"], counts["snack"], counts["showtime"],
			counts["mistake"], counts["joint"], replay])


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok  " + message)
	else:
		failures.append(message)
		print("  FAIL " + message)
