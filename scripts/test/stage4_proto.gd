extends Node
## 阶段 4 障碍空间原型段自检（2026-11-11 补充指令）。
## 验的是“碰撞空间 + 操作分工”，不是障碍名字：
##   A 兔子层（趴低 / 跳跃）：只压兔子，龟壳巡航高度不动
##   B 组合漂浮物：兔子跳上沿、乌龟潜下沿，两条路同时走
##   C 水下攻击：乌龟跃起带动整组，兔子不需要额外动作
##   D 水下通道：乌龟下潜，整个壳（连同壳上的兔子）从下方过
## 还会做三件“反证”：不按、按错、只做一半，都必须被判定框抓住。
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT res://scenes/stage4_proto.tscn

const Tuning = preload("res://scripts/systems/tuning.gd")
const LevelDataScript = preload("res://scripts/systems/level_data.gd")
const REPORT_PATH := "res://docs/reports/stage4-proto.json"

var is_runner := false
var failures: Array[String] = []
var race
var sim := 0.0
var report := {}
var feedback_seen: Array[String] = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4ProtoRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.feedback.connect(_on_feedback_seen)
	await get_tree().process_frame
	await _run()


func _run() -> void:
	Locale.language = "en"
	var best_text := _read(GameManager.BEST_PATH)

	await _test_structure()
	await _test_crouch_bird()
	await _test_wrong_crouch()
	await _test_jump_rock()
	await _test_wrong_jump()
	await _test_shark_need_leap()
	await _test_shark_leap()
	await _test_shark_dive_only()
	await _test_gate_need_dive()
	await _test_gate_dive()
	await _test_log_full_sequence()
	await _test_log_jump_only()
	await _test_log_dive_only()
	await _test_log_leap_only()
	await _test_wall_leap_only()
	await _test_wall_ollie()
	await _test_geometry()
	await _test_warning_times()

	_write_report()
	_restore(GameManager.BEST_PATH, best_text)

	if failures.is_empty():
		print("STAGE4 PROTO: PASS")
		get_tree().quit(0)
	else:
		print("STAGE4 PROTO: FAIL")
		for item in failures:
			print("  - " + item)
		get_tree().quit(1)


# ---- 0. 原型段结构：六类障碍各一组（含高墙），另加码头低梁对照。 ----

func _test_structure() -> void:
	await _fresh()
	var kinds := {}
	for g in race.hazard_groups:
		kinds[g["kind"]] = kinds.get(g["kind"], 0) + 1
	_check(race.hazard_groups.size() == 7,
		"proto has 7 groups (%d)" % race.hazard_groups.size())
	for kind in ["LOW_BIRD", "SURFACE_ROCK", "LOW_BEAM", "DIVE_GATE", "SHARK",
			"FLOATING_LOG", "HIGH_WALL"]:
		_check(kinds.get(kind, 0) == 1, "proto has one %s" % kind)
	_check(is_equal_approx(race.world_end, LevelDataScript.PROTO_END),
		"proto finishes at its own world end (%.0f)" % race.world_end)
	report["structure"] = {"count": race.hazard_groups.size(), "kinds": kinds}
	print("  structure -> ", kinds)


# ---- A1. 低飞海鸟：兔子趴低过，乌龟巡航深度不动。 ----

func _test_crouch_bird() -> void:
	await _fresh()
	var g := _group("proto_bird")
	var end := _group_end(g)
	_place(_group_start(g) - 150.0)
	_check(GameManager.current_control == "rabbit", "bird test starts on the rabbit")
	var y0: float = race.turtle.position.y
	_send_key(KEY_DOWN, true)
	await _step()
	var ok := await _wait_until(_past_x(end + 90.0), 4.0)
	_send_key(KEY_DOWN, false)
	await _step()
	_check(ok, "crouched rabbit crosses the low bird")
	_check(not race.hit_groups.has("proto_bird"), "bird not marked as hit")
	_check(race.passed_groups.has("proto_bird"), "bird counted as passed")
	_check(GameManager.accident_state == "NONE", "crouch under the bird causes no accident")
	_check(absf(race.turtle.position.y - y0) < 1.5,
		"turtle cruise depth unaffected (%.1f -> %.1f)"
			% [y0, race.turtle.position.y])
	report["crouch_bird"] = {"passed": ok, "turtle_y": race.turtle.position.y}
	print("  crouch bird -> passed=%s turtle_y %.1f" % [ok, race.turtle.position.y])


func _test_wrong_crouch() -> void:
	await _fresh()
	var g := _group("proto_bird")
	_place(_group_start(g) - 70.0)
	var hit := await _wait_until(_accident(), 2.0)
	_check(hit, "standing into the low bird has a consequence")
	_check(race.hit_groups.has("proto_bird"), "bird marked as hit when standing")
	_check(race.rabbit.daze_time > 1.0,
		"wrong crouch leaves visible imbalance (%.1f)" % race.rabbit.daze_time)
	report["wrong_crouch"] = {"accident": GameManager.accident_state,
		"daze": race.rabbit.daze_time}
	print("  wrong crouch -> %s daze %.1f"
		% [GameManager.accident_state, race.rabbit.daze_time])


# ---- A2. 低岩：兔子跳跃；龟壳在下面 10 px 让开。 ----

func _test_jump_rock() -> void:
	await _fresh()
	var g := _group("proto_rock")
	_place(_group_start(g) - 100.0)
	var y0: float = race.turtle.position.y
	await _tap(KEY_UP)
	_check(race.mount.state == "AIRBORNE", "up lifts the rabbit off the shell")
	var ok := await _wait_until(_passed("proto_rock"), 4.0)
	var landed := await _wait_until(_riding(), 2.0)
	_check(ok, "rabbit jump clears the low rock")
	_check(not race.hit_groups.has("proto_rock"), "rock not marked as hit")
	_check(GameManager.accident_state == "NONE", "rock landing causes no accident")
	_check(landed, "rabbit is back on the shell")
	_check(absf(race.turtle.position.y - y0) < 1.5,
		"turtle never changes depth for a rabbit-layer obstacle (%.1f)"
			% race.turtle.position.y)
	report["jump_rock"] = {"passed": ok, "landed": landed,
		"turtle_y": race.turtle.position.y}
	print("  jump rock -> passed=%s landed=%s turtle_y %.1f"
		% [ok, landed, race.turtle.position.y])


func _test_wrong_jump() -> void:
	await _fresh()
	var g := _group("proto_rock")
	_place(_group_start(g) - 70.0)
	var hit := await _wait_until(_accident(), 2.0)
	_check(hit, "running into the rock without jumping has a consequence")
	_check(GameManager.accident_state == "RABBIT_STUN",
		"wrong jump reads as RABBIT_STUN (%s)" % GameManager.accident_state)
	_check(race.hit_groups.has("proto_rock"), "rock marked as hit without jump")
	report["wrong_jump"] = {"accident": GameManager.accident_state,
		"daze": race.rabbit.daze_time}
	print("  wrong jump -> %s daze %.1f"
		% [GameManager.accident_state, race.rabbit.daze_time])


# ---- C. 鲨鱼：不跃起会撞；跃起把整组带高，兔子不用额外动作。 ----

func _test_shark_need_leap() -> void:
	await _fresh()
	await _shift()
	var g := _group("proto_shark")
	_place(_group_start(g) - 70.0)
	var hit := await _wait_until(_hit("proto_shark"), 2.0)
	_check(hit, "cruising into the shark is a hit")
	_check(race.turtle.daze_time > 2.0,
		"shark hit leaves visible imbalance (%.1f)" % race.turtle.daze_time)
	_check(GameManager.accident_state == "NONE",
		"a single shark hit is imbalance, not an instant accident (%s)"
			% GameManager.accident_state)
	report["shark_no_leap"] = {"hit": hit, "daze": race.turtle.daze_time}
	print("  shark no-leap -> hit=%s daze %.1f" % [hit, race.turtle.daze_time])


## 下潜不是万能解：鲨鱼整条占满水柱，最深的下潜也还在它的身体里。
func _test_shark_dive_only() -> void:
	await _fresh()
	await _shift()
	var g := _group("proto_shark")
	_place(_group_start(g) - 200.0)
	_send_key(KEY_DOWN, true)
	var hit := await _wait_until(_hit("proto_shark"), 2.5)
	_send_key(KEY_DOWN, false)
	await _step()
	_check(hit, "diving does not get under the shark")
	_check(race.turtle.daze_time > 2.0,
		"shark hit while diving leaves visible imbalance (%.1f)"
			% race.turtle.daze_time)
	report["shark_dive_only"] = {"hit": hit, "daze": race.turtle.daze_time}
	print("  shark dive-only -> hit=%s daze %.1f" % [hit, race.turtle.daze_time])


func _test_shark_leap() -> void:
	await _fresh()
	await _shift()
	_check(GameManager.current_control == "turtle", "SHIFT hands control to the turtle")
	var g := _group("proto_shark")
	_place(_group_start(g) - 140.0)
	await _tap(KEY_UP)
	_check(race.turtle.leap_active, "up starts the turtle leap")
	var apex := 1.0e9
	var rabbit_jumped := false
	var start_sim := sim
	var ok := false
	while sim - start_sim < 3.0:
		apex = minf(apex, race.turtle.position.y)
		if race.rabbit.state in ["JUMPING", "FALLING"]:
			rabbit_jumped = true
		if race.passed_groups.has("proto_shark"):
			ok = true
			break
		await _step()
	_check(ok, "leap clears the shark")
	_check(not race.hit_groups.has("proto_shark"), "shark not marked as hit when leaping")
	_check(not rabbit_jumped, "rabbit is carried by the leap and never has to jump")
	_check(race.mount.state == "RIDING", "rabbit stays on the shell through the leap")
	_check(apex < Tuning.NEUTRAL_DEPTH - 150.0,
		"leap lifts the whole group well above cruise (apex %.0f)" % apex)
	_check(GameManager.accident_state == "NONE", "leap causes no accident")
	var leap_done := await _wait_until(_leap_over(), 2.0)
	_check(leap_done and absf(race.turtle.position.y - Tuning.NEUTRAL_DEPTH) < 2.0,
		"leap lands back at cruise depth (%.1f)" % race.turtle.position.y)
	report["shark_leap"] = {"passed": ok, "apex_y": apex,
		"rabbit_jumped": rabbit_jumped}
	print("  shark leap -> passed=%s apex %.0f rabbit_jumped=%s"
		% [ok, apex, rabbit_jumped])


# ---- D. 水下拱岩：不潜会撞；按住 ↓ 过，尾端自动回巡航。 ----

func _test_gate_need_dive() -> void:
	await _fresh()
	await _shift()
	var g := _group("proto_gate")
	_place(_group_start(g) - 70.0)
	var hit := await _wait_until(_hit("proto_gate"), 2.0)
	_check(hit, "cruising into the reef arch is a hit")
	_check(race.turtle.daze_time > 2.0,
		"reef arch hit leaves visible imbalance (%.1f)" % race.turtle.daze_time)
	report["gate_no_dive"] = {"hit": hit, "daze": race.turtle.daze_time}
	print("  gate no-dive -> hit=%s daze %.1f" % [hit, race.turtle.daze_time])


func _test_gate_dive() -> void:
	await _fresh()
	await _shift()
	var g := _group("proto_gate")
	var start := _group_start(g)
	var end := _group_end(g)
	_place(start - 160.0)
	var deepest := 0.0
	_send_key(KEY_DOWN, true)
	await _step()
	var start_sim := sim
	var ok := false
	while sim - start_sim < 3.5:
		deepest = maxf(deepest, race.turtle.position.y)
		if race.turtle.position.x > end + 90.0:
			ok = true
			break
		await _step()
	# 尾端之后松开 ↓：正常浮力上浮（不再有自动上浮）。
	_send_key(KEY_DOWN, false)
	var surfaced := await _wait_until(_shallow(Tuning.NEUTRAL_DEPTH + 2.0), 2.0)
	await _step()
	_check(ok, "holding down clears the reef arch")
	_check(not race.hit_groups.has("proto_gate"), "gate not marked as hit when diving")
	_check(deepest > Tuning.NEUTRAL_DEPTH + Tuning.DIVE_DEPTH - 12.0,
		"dive reaches the designed depth (%.1f)" % deepest)
	_check(race.mount.state == "RIDING", "rabbit rides the shell under the arch")
	_check(surfaced, "turtle surfaces after the player releases down (y=%.1f)"
		% race.turtle.position.y)
	_check(GameManager.accident_state == "NONE", "dive causes no accident")
	report["gate_dive"] = {"passed": ok, "deepest": deepest,
		"surfaced_after_release": surfaced}
	print("  gate dive -> passed=%s deepest %.0f surfaced=%s"
		% [ok, deepest, surfaced])


# ---- B. 组合漂浮物：完整序列。 ----

func _test_log_full_sequence() -> void:
	await _fresh()
	var g := _group("proto_log")
	var start := _group_start(g)
	var end := _group_end(g)
	# 起跳点必须是“浮木上方窗口”的中点，不能是拍脑袋的距离：
	# 蛙身底 < 浮木顶(192) 的时间窗是 0.21~0.99 s（跳跃参数决定），
	# 这段窗要覆盖“兔子前沿进入 -> 后沿离开”浮木的整段行程 (lead-16..lead+66)/v。
	# 下潜侧：壳顶要从 306 沉到 410 以下约 0.22 s（600/6000 的加速段）；
	# 换人比按键晚 ~0.18 s。合并后窗口上沿 0.99v-48、下沿 (0.22+0.18)v+45，
	# 中点取 0.7v - 2。
	var lead: float = race.turtle.base_speed * 0.7 - 2.0
	_place(start - lead)
	var y0: float = race.turtle.position.y
	# 1) 兔子先跳
	await _tap(KEY_UP)
	_check(race.mount.state == "AIRBORNE", "jump lifts the rabbit off the shell")
	# 第一张连拍放在起跳这一帧：兔子离壳、乌龟还没开始潜，和“过木那一帧”不同。
	_shot("stage4-combo-dive-1-jump.png")
	var jump_y0: float = race.rabbit.position.y
	# 下潜键在换人前就按住：换人那一帧乌龟就开始潜，壳的前沿才来得及在
	# 浮木左边缘之前降到 438 以下（壳半宽 48 px 比中心早进浮木）。
	_send_key(KEY_DOWN, true)
	await _wait_sim(0.02)
	# 2) 换乌龟：跳跃不能被换人取消
	await _shift()
	_check(GameManager.current_control == "turtle", "SHIFT hands control to the turtle")
	_check(race.mount.state == "AIRBORNE",
		"rabbit is still airborne after SHIFT to the turtle")
	_check(race.rabbit.position.y < jump_y0 - 25.0,
		"rabbit keeps rising after the switch (dy=%.0f)"
			% (race.rabbit.position.y - jump_y0))
	# 3) down 已按住，下潜从换人那一帧开始
	await _step()
	var both_active := false
	var rabbit_over_log := false
	var turtle_under_log := false
	var log_top: float = g["rects"][0].position.y
	var log_bottom: float = g["rects"][0].end.y
	var start_sim := sim
	var ok := false
	while sim - start_sim < 4.0:
		var over: bool = race.turtle.position.x > start - 20.0 \
			and race.turtle.position.x < end + 20.0
		if over and race.mount.state == "AIRBORNE" \
				and race.rabbit.get_body_rect().end.y < log_top:
			rabbit_over_log = true
		if over and race.turtle.get_body_rect().position.y > log_bottom:
			if not turtle_under_log:
				_shot("stage4-combo-dive-2-under.png")
			turtle_under_log = true
		if race.mount.state == "AIRBORNE" \
				and race.turtle.position.y > Tuning.NEUTRAL_DEPTH + 90.0:
			both_active = true
		if race.turtle.position.x > end + 30.0:
			ok = true
			break
		await _step()
	# 4) 尾端后松 ↓，壳按浮力上浮、兔子落回。接人是玩家的操作。
	# 松键之后才等“组已通过”：通过发生在 end+80，若还按着 ↓ 会多沉一截，
	# 兔子接人就会摔（实测 dy=34.5 并出事故）。这里按键已松，只等判定。
	_send_key(KEY_DOWN, false)
	var dive_pass := await _wait_until(
		func() -> bool: return race.passed_groups.has("proto_log"), 0.6)
	if dive_pass:
		_shot("stage4-combo-dive-3-clear.png")
	var landed := await _wait_until(_riding(), 1.5)
	var settle_min := 1.0e9
	var start_sim2 := sim
	var settled := false
	while sim - start_sim2 < 1.5:
		settle_min = minf(settle_min, race.turtle.position.y)
		if settle_min <= Tuning.NEUTRAL_DEPTH + 2.0:
			settled = true
			break
		await _step()
	var back := await _wait_until(
		func() -> bool: return absf(race.turtle.position.y - y0) < 1.5, 1.5)
	_check(ok, "the full sequence crosses the floating log")
	_check(not race.hit_groups.has("proto_log"), "floating log not marked as hit")
	_check(both_active, "rabbit jump and turtle dive coexist in the same obstacle")
	_check(rabbit_over_log, "rabbit body is above the log top while over it")
	_check(turtle_under_log, "turtle body is below the log bottom while over it")
	_check(landed, "rabbit lands back on the shell after the log")
	_check(settled and settle_min <= Tuning.NEUTRAL_DEPTH + 2.0,
		"turtle is back at cruise depth after the log (min %.1f)"
			% settle_min)
	_check(GameManager.accident_state == "NONE", "combined log causes no accident")
	_check(race.passed_groups.has("proto_log"), "floating log counted as passed")
	var mount_dy: float = race.rabbit.position.y - race.turtle.get_mount_point().y
	_check(absf(mount_dy) < 2.0,
		"rabbit sits exactly on the shell after landing (dy=%.1f)" % mount_dy)
	_shot("stage4-combo-dive-4-land.png")
	_check(back and absf(race.turtle.position.y - y0) < 2.0,
		"turtle settles at its departure depth (%.1f -> %.1f)"
			% [y0, race.turtle.position.y])
	# HUD 必须在对局里真的报出 BRO DIVE，而不只是结算里多 250 分。
	_check(feedback_seen.has(Locale.t("feedback.bro_dive")),
		"HUD announces BRO DIVE on the log pass (%s)" % _fb_tail())
	report["log_full"] = {
		"passed": ok, "both_active": both_active,
		"rabbit_over_log": rabbit_over_log, "turtle_under_log": turtle_under_log,
		"landed": landed, "mount_dy": mount_dy,
		"turtle_y": race.turtle.position.y,
	}
	print("  log full -> passed=%s both=%s above=%s below=%s landed=%s dy %.1f"
		% [ok, both_active, rabbit_over_log, turtle_under_log, landed, mount_dy])


## 只跳不潜：乌龟撞浮木下沿。兔子在空中，不能替乌龟解决问题。
func _test_log_jump_only() -> void:
	await _fresh()
	var g := _group("proto_log")
	_place(_group_start(g) - 200.0)
	await _tap(KEY_UP)
	var hit := await _wait_until(_hit("proto_log"), 2.5)
	_check(hit, "jumping alone does not move the shell under the log")
	_check(race.turtle.daze_time > 2.0,
		"shell hit leaves visible imbalance (%.1f)" % race.turtle.daze_time)
	report["log_jump_only"] = {"hit": hit, "daze": race.turtle.daze_time}
	print("  log jump-only -> hit=%s daze %.1f" % [hit, race.turtle.daze_time])


## 只潜不跳：兔子撞浮木上沿。乌龟在水下，不能替兔子解决问题。
func _test_log_dive_only() -> void:
	await _fresh()
	await _shift()
	var g := _group("proto_log")
	_place(_group_start(g) - 160.0)
	_send_key(KEY_DOWN, true)
	await _step()
	var hit := await _wait_until(_hit("proto_log"), 2.5)
	_send_key(KEY_DOWN, false)
	await _step()
	_check(hit, "diving alone leaves the rabbit in the log's upper route")
	_check(race.rabbit.daze_time > 1.0,
		"rabbit hit leaves visible imbalance (%.1f)" % race.rabbit.daze_time)
	report["log_dive_only"] = {"hit": hit, "daze": race.rabbit.daze_time}
	print("  log dive-only -> hit=%s daze %.1f" % [hit, race.rabbit.daze_time])


## 只跃起也不是浮木的解：跃起到顶时壳底 202 仍在浮木上沿 180 之下。
## 上沿从 224 抬到 180 就是为了封掉“整组飞过去”的万能跃起。
func _test_log_leap_only() -> void:
	await _fresh()
	await _shift()
	var g := _group("proto_log")
	_place(_group_start(g) - 176.0)
	await _tap(KEY_UP)
	_check(race.turtle.leap_active, "up starts the turtle leap at the log")
	var hit := await _wait_until(_hit("proto_log"), 2.5)
	_check(hit, "leaping alone still hits the floating log")
	_check(race.turtle.daze_time > 2.0,
		"log hit during the leap leaves visible imbalance (%.1f)"
			% race.turtle.daze_time)
	report["log_leap_only"] = {"hit": hit, "daze": race.turtle.daze_time}
	print("  log leap-only -> hit=%s daze %.1f" % [hit, race.turtle.daze_time])


# ---- E. 高墙：乌龟跃起只把壳送进窗口，壳上的兔子撞墙楣。 ----
# 峰值降到 160 后，跃起到顶时兔身 92～140，墙楣 80～120 —— 兔子必须额外蹬踏。

func _test_wall_leap_only() -> void:
	await _fresh()
	await _shift()
	var g := _group("proto_wall")
	var start := _group_start(g)
	# 跃起 1.6 s，0.8 s 到顶；220 px/s 下从 start-176 起跳，到顶正好在墙。
	_place(start - 176.0)
	await _tap(KEY_UP)
	_check(race.turtle.leap_active, "up starts the turtle leap at the high wall")
	var hit := await _wait_until(_hit("proto_wall"), 2.5)
	_check(hit, "leap alone leaves the riding rabbit in the wall pier")
	_check(race.rabbit.daze_time > 1.0,
		"wall pier hit leaves visible rabbit imbalance (%.1f)" % race.rabbit.daze_time)
	_check(race.turtle.daze_time < 0.5,
		"the turtle itself clears the window, only the rabbit is caught (%.1f)"
			% race.turtle.daze_time)
	report["wall_leap_only"] = {"hit": hit, "rabbit_daze": race.rabbit.daze_time,
		"turtle_daze": race.turtle.daze_time}
	print("  wall leap-only -> hit=%s rab_daze %.1f tur_daze %.1f"
		% [hit, race.rabbit.daze_time, race.turtle.daze_time])


func _test_wall_ollie() -> void:
	await _fresh()
	await _shift()
	var g := _group("proto_wall")
	var start := _group_start(g)
	var end := _group_end(g)
	var pier: Rect2 = g["rects"][0]
	_place(start - 176.0)
	await _tap(KEY_UP)
	_check(race.turtle.leap_active, "leap starts the wall sequence")
	# 蹬踏点：兔身 26 宽、蹬踏弧线约 0.48 s 到顶。在墙前 ~70 px 起跳，
	# 弧线顶部落在墙的中后段；起跳再早会在墙尾还没升够，再晚会在墙头撞楣。
	var ready := await _wait_until(
		func() -> bool: return race.turtle.position.x >= start - 70.0, 2.0)
	_check(ready, "shell reaches the wall after the leap")
	await _shift()
	_check(GameManager.current_control == "rabbit",
		"SHIFT hands control to the rabbit during the leap")
	await _tap(KEY_UP)
	_check(race.mount.state == "AIRBORNE",
		"rabbit kicks off the shell during the leap (state %s)" % race.mount.state)
	# 第一张连拍放在蹬踏这一帧：兔子刚离壳，壳还在窗口下方。
	_shot("stage4-combo-ollie-1-kick.png")
	var over_pier := false
	var turtle_in_window := false
	var start_sim := sim
	var ok := false
	while sim - start_sim < 3.0:
		var x: float = race.turtle.position.x
		if x >= start - 5.0 and x <= end + 5.0:
			if race.mount.state == "AIRBORNE" \
					and race.rabbit.get_body_rect().end.y < pier.position.y:
				over_pier = true
			var shell: Rect2 = race.turtle.get_body_rect()
			if shell.position.y > pier.end.y and shell.end.y < g["rects"][1].position.y:
				if not turtle_in_window:
					_shot("stage4-combo-ollie-2-window.png")
				turtle_in_window = true
		if x > end + 150.0:
			ok = true
			break
		await _step()
	# HUD 必须在对局里真的报出 BRO OLLIE。
	_check(feedback_seen.has(Locale.t("feedback.bro_ollie")),
		"HUD announces BRO OLLIE on the wall pass (%s)" % _fb_tail())
	var landed := await _wait_until(_riding(), 3.0)
	var settle := await _wait_until(_leap_over(), 2.0)
	_check(ok, "leap + rabbit kick crosses the high wall")
	_check(not race.hit_groups.has("proto_wall"), "high wall not marked as hit")
	_check(over_pier, "rabbit body is above the pier top while crossing the wall")
	_check(turtle_in_window, "shell passes through the wall window")
	_shot("stage4-combo-ollie-3-land.png")
	_check(landed, "rabbit lands back on the shell after the wall")
	_check(race.mount.state == "RIDING" and GameManager.accident_state == "NONE",
		"wall ollie ends clean (%s / %s)"
			% [race.mount.state, GameManager.accident_state])
	_check(race.passed_groups.has("proto_wall"), "high wall counted as passed")
	report["wall_ollie"] = {"passed": ok, "over_pier": over_pier,
		"turtle_in_window": turtle_in_window, "landed": landed,
		"settle": settle, "accident": GameManager.accident_state}
	print("  wall ollie -> passed=%s over_pier=%s window=%s landed=%s"
		% [ok, over_pier, turtle_in_window, landed])


# ---- 几何一致性：判定框必须真的贴合“两条路线”。 ----

func _test_geometry() -> void:
	await _fresh()
	var speed: float = LevelDataScript.zone_by_id(1)["base_speed"]
	var cruise := Tuning.NEUTRAL_DEPTH
	var rabbit_top := cruise - 58.0 - 24.0
	var rabbit_bottom := cruise - 58.0 + 24.0
	var crouch_top := cruise - 58.0 + 20.0 - 12.0
	var turtle_top := cruise - 28.0
	var turtle_bottom := cruise + 28.0
	var dive_y := cruise + Tuning.DIVE_DEPTH
	var dive_rabbit_top := dive_y - 58.0 - 24.0
	var leap_apex := Tuning.NEUTRAL_DEPTH - Tuning.LEAP_HEIGHT

	var bird: Rect2 = _group("proto_bird")["rects"][0]
	_check(bird.end.y > rabbit_top and bird.end.y < crouch_top,
		"bird band hits standing rabbit but not crouched (%.0f..%.0f vs %.0f/%.0f)"
			% [bird.position.y, bird.end.y, rabbit_top, crouch_top])
	_check(bird.end.y < turtle_top,
		"bird band never touches the shell (%.0f < %.0f)" % [bird.end.y, turtle_top])

	var rock: Rect2 = _group("proto_rock")["rects"][0]
	_check(_overlaps(rock, rabbit_top, rabbit_bottom),
		"rock band hits the rabbit's body (%.0f..%.0f vs %.0f..%.0f)"
			% [rock.position.y, rock.end.y, rabbit_top, rabbit_bottom])
	_check(rock.end.y < turtle_top,
		"rock leaves the cruising shell clear (%.0f < %.0f)" % [rock.end.y, turtle_top])

	var beam: Rect2 = _group("proto_beam")["rects"][0]
	_check(beam.end.y > rabbit_top and beam.end.y < crouch_top,
		"dock beam hits standing rabbit, crouch clears (%.0f < %.0f)"
			% [beam.end.y, crouch_top])

	var gate: Rect2 = _group("proto_gate")["rects"][0]
	_check(_overlaps(gate, turtle_top, turtle_bottom),
		"reef arch blocks the cruising shell (%.0f..%.0f vs %.0f..%.0f)"
			% [gate.position.y, gate.end.y, turtle_top, turtle_bottom])
	_check(gate.end.y < dive_rabbit_top,
		"reef arch clears the diving rabbit (%.0f < %.0f)"
			% [gate.end.y, dive_rabbit_top])

	var shark: Rect2 = _group("proto_shark")["rects"][0]
	_check(_overlaps(shark, turtle_top, turtle_bottom),
		"shark overlaps the cruising shell (%.0f..%.0f)"
			% [shark.position.y, shark.end.y])
	var need_rise: float = turtle_bottom - shark.position.y
	_check(need_rise < Tuning.LEAP_HEIGHT - 40.0,
		"leap height leaves margin over the shark (need %.0f of %.0f)"
			% [need_rise, Tuning.LEAP_HEIGHT])
	var above_ratio := 2.0 * asin(clampf(need_rise / Tuning.LEAP_HEIGHT, 0.0, 1.0)) / PI
	var above_time: float = (1.0 - above_ratio) * Tuning.LEAP_TIME
	var span_time: float = (shark.size.x + 96.0) / speed
	_check(above_time > span_time + 0.2,
		"shark window has reaction slack (above %.2f s vs span %.2f s)"
			% [above_time, span_time])
	# 下潜的极限壳顶 dive_y-28 仍然在鲨鱼身体里：下潜躲不开。
	_check(shark.end.y > dive_y - 28.0,
		"shark body blocks even the deepest dive shell (%.0f > %.0f)"
			% [shark.end.y, dive_y - 28.0])

	var log: Rect2 = _group("proto_log")["rects"][0]
	_check(log.position.y < rabbit_bottom and log.end.y > rabbit_top,
		"log blocks the standing rabbit route (%.0f..%.0f)"
			% [log.position.y, log.end.y])
	_check(log.position.y < turtle_bottom and log.end.y > turtle_top,
		"log blocks the cruising shell route (%.0f..%.0f)"
			% [log.position.y, log.end.y])
	_check(log.end.y > dive_rabbit_top,
		"log bottom blocks the diving rabbit so dive alone fails (%.0f > %.0f)"
			% [log.end.y, dive_rabbit_top])
	# 跳跃弧线：兔身底 < log 顶 的时间窗必须覆盖“兔子在浮木上方”的整段。
	var t_above := _air_above_time(rabbit_bottom - log.position.y)
	var log_span_time: float = (log.size.x + 32.0) / speed
	_check(t_above > log_span_time + 0.3,
		"jump window covers the log with slack (above %.2f s vs span %.2f s)"
			% [t_above, log_span_time])
	# 跃起的极限壳底 leap_apex+28 仍在浮木上沿之下：只跃起躲不开。
	_check(log.position.y < leap_apex + 28.0,
		"log top sits under the leap shell bottom, so leaping alone hits (%.0f < %.0f)"
			% [log.position.y, leap_apex + 28.0])

	# 高墙：跃起到顶时墙楣只压兔子、窗口只放壳；蹬踏后兔身要从墙楣顶上过。
	var pier: Rect2 = _group("proto_wall")["rects"][0]
	var wall: Rect2 = _group("proto_wall")["rects"][1]
	var leap_rabbit_top := leap_apex - 58.0 - 24.0
	var leap_rabbit_bottom := leap_apex - 58.0 + 24.0
	var leap_shell_top := leap_apex - 28.0
	var leap_shell_bottom := leap_apex + 28.0
	_check(_overlaps(pier, leap_rabbit_top, leap_rabbit_bottom),
		"wall pier catches the riding rabbit at the leap apex (%.0f..%.0f vs %.0f..%.0f)"
			% [pier.position.y, pier.end.y, leap_rabbit_top, leap_rabbit_bottom])
	_check(pier.end.y < leap_shell_top and wall.position.y > leap_shell_bottom,
		"wall window fits the shell at the leap apex (%.0f < %.0f .. %.0f < %.0f)"
			% [pier.position.y + pier.size.y, leap_shell_top,
				leap_shell_bottom, wall.position.y])
	_check(wall.end.y > dive_rabbit_top,
		"wall body blocks the diving rabbit so dive alone fails (%.0f > %.0f)"
			% [wall.end.y, dive_rabbit_top])
	var kick_h := Tuning.OLLIE_KICK_VELOCITY * Tuning.OLLIE_KICK_VELOCITY \
		/ (2.0 * 1050.0)
	var kicked_bottom := leap_apex - 58.0 + 24.0 - kick_h
	_check(kicked_bottom < pier.position.y - 20.0,
		"rabbit kick clears the pier top with margin (%.0f < %.0f)"
			% [kicked_bottom, pier.position.y])
	report["geometry"] = {
		"rabbit": [rabbit_top, rabbit_bottom], "crouch_top": crouch_top,
		"turtle": [turtle_top, turtle_bottom],
		"dive_rabbit_top": dive_rabbit_top, "leap_apex": leap_apex,
		"shark_above_s": above_time, "shark_span_s": span_time,
		"log_above_s": t_above, "log_span_s": log_span_time,
	}
	print("  geometry -> shark above %.2f/%.2f s, log above %.2f/%.2f s"
		% [above_time, span_time, t_above, log_span_time])


func _overlaps(rect: Rect2, top: float, bottom: float) -> bool:
	return rect.position.y < bottom and rect.end.y > top


## 跳跃弧线里“兔身底高于某个高度”的时长：-v t + 0.5 g t^2 = -h。
## 数值必须跟 rabbit_controller 的实际跳跃一致（g=1050、v=630）。
func _air_above_time(h: float) -> float:
	var g := 1050.0
	var v := 630.0
	var disc := v * v - 2.0 * g * h
	if disc <= 0.0:
		return 0.0
	var root := sqrt(disc)
	var t1 := (v - root) / g
	var t2 := (v + root) / g
	return maxf(t2 - t1, 0.0)


# ---- 预警时间：单角色 ≥3.5 s，组合 ≥5 s。 ----

func _test_warning_times() -> void:
	await _fresh()
	var speed: float = LevelDataScript.zone_by_id(1)["base_speed"]
	var rows := []
	var min_single := 1.0e9
	var combo_s := 0.0
	var prev_end := 400.0
	for g in race.hazard_groups:
		var start := _group_start(g)
		# 首次看见 = 进入提示距离；也不能比与上一组尾端的间距更早。
		var sight_px := minf(maxf(start - prev_end, 0.0), Tuning.PROMPT_RANGE)
		var seconds := sight_px / speed
		if g["kind"] == "FLOATING_LOG":
			combo_s = seconds
		else:
			min_single = minf(min_single, seconds)
		rows.append({"group": g["group"], "kind": g["kind"],
			"sight_px": sight_px, "seconds": seconds})
		prev_end = _group_end(g)
	_check(min_single >= 3.5,
		"single-role obstacles give >= 3.5 s from first sight (min %.2f s)"
			% min_single)
	_check(combo_s >= 5.0,
		"combined log gives >= 5 s from first sight (%.2f s)" % combo_s)
	report["warning_times"] = {"rows": rows, "min_single_s": min_single,
		"combo_s": combo_s}
	print("  warning times -> single min %.2f s, combo %.2f s"
		% [min_single, combo_s])


# ---- 工具 ----

func _past_x(x: float) -> Callable:
	return func() -> bool: return race.turtle.position.x > x


func _accident() -> Callable:
	return func() -> bool: return GameManager.accident_state != "NONE"


func _passed(key: String) -> Callable:
	return func() -> bool: return race.passed_groups.has(key)


func _hit(key: String) -> Callable:
	return func() -> bool: return race.hit_groups.has(key)


func _riding() -> Callable:
	return func() -> bool: return race.mount.state == "RIDING"


func _shallow(y: float) -> Callable:
	return func() -> bool: return race.turtle.position.y <= y


func _leap_over() -> Callable:
	return func() -> bool: return not race.turtle.leap_active


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
	race.turtle.leap_active = false
	race.turtle.leap_timer = 0.0
	race.turtle.diving = false
	race.turtle.dunk_timer = 0.0
	race.turtle.daze_time = 0.0
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.mark_riding()


func _fresh() -> void:
	GameManager.start_race()
	await _frames(4)
	race = get_tree().current_scene
	race.setup_proto()
	# setup_proto 只重置赛道数据；上一条测试撞过的组必须在这里清掉，
	# 否则“只跃起会撞”的留痕会被下一条“跃起+蹬踏”误判成自己撞的。
	# G20：hit_roles 必须和 hit_groups 一起清。只清 hit_groups 时，B2 起的“角色×组”记账还留着，同组第二例起整组免疫——后面那些重复用例其实在测一段不会撞的赛道。
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.test_disable_hazards = false
	race.test_no_finish = true
	sim = 0.0
	feedback_seen.clear()
	await get_tree().physics_frame


## HUD 反馈由信号驱动：0.75 s 的显示窗口在截图/等待里会过期，
## 记录整段测试收到过的提示，比事后读 label 可靠。
func _on_feedback_seen(text: String, _kind: String) -> void:
	feedback_seen.append(text)


func _fb_tail() -> String:
	if feedback_seen.is_empty():
		return "none"
	return feedback_seen.back()


## 连续截图：只在带 --shots 时存图（--headless 没有渲染，不写真图）。
func _shot(file_name: String) -> void:
	if not ("--shots" in OS.get_cmdline_user_args()):
		return
	race._save_shot(file_name)


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
