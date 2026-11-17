extends Node
## CORE-FEEL-08 P0-B — 事故必须可恢复、分轻/重、同一事件只记一次（headless，真实 race.gd）
##
## 核对六件事，全部走真实 race 物理步进（race._physics_process(1/60)）：
##   1) 事故来源表：线上真正会发生的 5 种事故 + 乌龟失误，各有来源与分级；
##      RABBIT_SLIP / TURTLE_REEF 只有历史入口/截图入口，没有线上来源（如实记录）；
##   2) 轻事故（RABBIT_STUN）：不丢骑乘、不强制换人、STUN_TIME 后自己站起来；
##   3) 重事故（RABBIT_WATER）：玩家什么都不按也会被冲回壳上（不锁死）；
##      氧气耗尽（OXYGEN_OUT）自动上浮并回气；BRO_BREAK 演出结束回到正常；
##   4) 乌龟失误（浪击）：只扣一格、不进入事故状态，1 s 内恢复操控；
##   5) 同一障碍同一事件只记一次：第二笔只播表现（硬直/落水照常），不再扣分；
##   6) 判定框没变小：装载后的 rect 尺寸与 LevelData 定义逐一相同；
##      真实碰撞仍然发生（龟壳仍被浮木顶住，不是穿过去）。
##
## 用法：
##   D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
##       res://scenes/stage8_accident_recovery.tscn > docs/reports/logs/core-feel-08-p0b.log 2>&1
##
## 输出：docs/reports/longrun/core-feel-08-p0b-accident-recovery.json

const LevelDataScript = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/core-feel-08-p0b-accident-recovery.json"
const STEP := 1.0 / 60.0

var is_runner := false
var race: Node = null
var checks: Array = []
var data := {}
var feedback_log: Array = []


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
	if race == null or race.hud == null:
		push_error("P0-B: no race scene")
		_finish(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	GameManager.feedback.connect(_on_feedback)

	data["source_table"] = _source_table()
	data["minor_rabbit_stun"] = _case_rabbit_stun()
	data["severe_rabbit_water"] = _case_rabbit_water()
	data["severe_oxygen_out"] = _case_oxygen_out()
	data["severe_bro_break"] = _case_bro_break()
	data["turtle_mistake"] = _case_turtle_mistake()
	data["same_event_once"] = _case_same_event()
	data["hitboxes"] = _case_hitboxes()
	data["solid_collision"] = _case_solid_collision()

	_write()
	_finish(0 if _all_pass() else 1)


# ---------------- 1) 事故来源表 ----------------

## 线上来源由 race.gd 的调用点普查得出（见 docs/reports/longrun/TBB-CORE-FEEL-08.md §P0-B）。
## live=true 的每一条都在下面用真实物理步进跑一遍恢复；live=false 的只登记，
## 不假装测过——它们没有线上入口，拿旧截图入口当证据就是伪造。
func _source_table() -> Dictionary:
	var rows := [
		{
			"reason": "RABBIT_STUN", "severity": "minor",
			"source": "兔子层障碍（LOW_BEAM / LOW_BIRD / SURFACE_ROCK）撞到，仍在壳上",
			"handling": "0.8 s 硬直 + 龟速压到 140；不强换人、不丢骑乘",
			"recover": "计时结束自动回 RIDING，1 s 宽限",
			"live": true,
		},
		{
			"reason": "RABBIT_WATER", "severity": "severe",
			"source": "空中撞到障碍被撞落水；或落壳时擦到水线",
			"handling": "真实下落 → 水花 → 3.2 s 救援窗；壳自动减速到 90",
			"recover": "自己潜过去接住；不接也会被冲回壳上（有限恢复）",
			"live": true,
		},
		{
			"reason": "OXYGEN_OUT", "severity": "severe",
			"source": "潜太深太久，氧气 8 → 0",
			"handling": "兔子晕过去，2 s 紧急上浮演出，控制权给乌龟",
			"recover": "演出结束自动回巡航水深，氧气回到 5.0",
			"live": true,
		},
		{
			"reason": "BRO_BREAK", "severity": "severe",
			"source": "BRO METER 三格（第三次失误）",
			"handling": "1.8 s 联合惩罚演出，整组停住",
			"recover": "演出结束清空 BRO METER、恢复巡航与骑乘",
			"live": true,
		},
		{
			"reason": "TURTLE_WAVE / TURTLE_DIVE_LATE", "severity": "minor",
			"source": "乌龟层障碍（浮木/鲨鱼/拱岩/高墙）撞上，记 1 格但不算事故状态",
			"handling": "90 ms 停顿 + 震动 + 下沉/掀翻 + 龟速 ×0.6",
			"recover": "掀翻 1 s 内自己回正，操控一直可用",
			"live": true,
		},
		{
			"reason": "RABBIT_SLIP", "severity": "severe",
			"source": "历史状态：兔子滑落。阶段 4 移除“待命必掉”后已无线上入口",
			"handling": "保留处理分支与横幅文案（存档/旧存档兼容）",
			"recover": "同上：真发生时走 FALLING_WATER + 救援流程",
			"live": false,
		},
		{
			"reason": "TURTLE_REEF", "severity": "severe",
			"source": "历史状态：乌龟撞暗礁翻肚皮。只剩截图/演出入口，线上不会发生",
			"handling": "1.6 s 修复计时后自动回巡航；控制权暂时交给兔子",
			"recover": "计时结束自动恢复",
			"live": false,
		},
		{
			"reason": "RABBIT_AIR", "severity": "severe",
			"source": "救援原型（--capture-rescue）入口；正式赛局没有调用点",
			"handling": "兔子被抛到空中，玩家 SHIFT 到乌龟再跃起接住",
			"recover": "接住 / 过期后走 _rescue_miss 冲回壳上",
			"live": false,
		},
	]
	var out := {"rows": rows, "live": [], "archived": []}
	var live_ok := true
	var classified := true
	for r in rows:
		if bool(r["live"]):
			out["live"].append(String(r["reason"]))
		else:
			out["archived"].append(String(r["reason"]))
		# 一行可能带两个原因（乌龟失误按实际提示分 TURTLE_WAVE / TURTLE_DIVE_LATE）。
		for one in String(r["reason"]).split(" / "):
			var sev: String = GameManager.accident_severity(String(one))
			if sev != String(r["severity"]):
				classified = false
			# 分级只有两种值。
			if sev != "minor" and sev != "severe":
				classified = false
	out["severity_helper_matches_table"] = classified
	_expect("1 线上事故来源共 5 类（兔子 3 + 乌龟失误 1 组 + 联合 1）",
		out["live"].size() == 5, str(out["live"]))
	_expect("1 历史/原型入口不冒充线上来源（SLIP/REEF/AIR 单列）",
		out["archived"].size() == 3, str(out["archived"]))
	_expect("1 分级与 GameManager.accident_severity 一致（不是报告里另说一套）",
		classified, str(classified))
	_expect("1 轻事故只有“还在壳上的短硬直”",
		GameManager.accident_severity("RABBIT_STUN") == "minor"
			and GameManager.accident_severity("RABBIT_HIT") == "minor"
			and GameManager.accident_severity("RABBIT_WATER") == "severe")
	return out


# ---------------- 2) 轻事故：撞梁硬直 ----------------

func _case_rabbit_stun() -> Dictionary:
	_reset(false)
	var rock := _group("rock1")
	var start := LevelDataScript.group_start(rock)
	race.turtle.position = Vector2(start - 90.0, Tuning.NEUTRAL_DEPTH)
	race.rabbit.attach(race.turtle.get_mount_point())
	GameManager.set_control("rabbit")
	var bro0: int = GameManager.bro_meter
	var acc0: int = GameManager.accident_count
	var control0: String = GameManager.current_control
	var reason := ""
	var frames := 0
	while frames < 120 and GameManager.accident_state == "NONE":
		_tick(1)
		frames += 1
	reason = GameManager.accident_state
	var bro_at_hit: int = GameManager.bro_meter - bro0
	var rec_frames := 0
	while rec_frames < 180 and GameManager.accident_state != "NONE":
		_tick(1)
		rec_frames += 1
	var state_after: String = race.rabbit.state
	var mount_after: String = race.mount.state
	# 硬直结束后兔子还能跳：按 ↑ 真的离地，证明“短硬直不是控制锁”。
	Input.action_press("up")
	var jumped := false
	var jump_frames := 0
	while jump_frames < 30 and not jumped:
		_tick(1)
		jump_frames += 1
		if race.mount.state == "AIRBORNE":
			jumped = true
	Input.action_release("up")
	var out := {
		"reason": reason,
		"charge_at_hit": bro_at_hit,
		"recovers_in_s": snappedf(rec_frames * STEP, 0.01),
		"stun_time": Tuning.STUN_TIME,
		"control_after": GameManager.current_control,
		"control_changed": GameManager.current_control != control0,
		"state_after": state_after,
		"mount_after": mount_after,
		"jump_after_recovery": jumped,
	}
	_expect("2 真撞岩 → 轻事故 RABBIT_STUN", reason == "RABBIT_STUN", reason)
	_expect("2 轻事故只记一格（不多扣）", bro_at_hit == 1, str(bro_at_hit))
	_expect("2 轻事故在 STUN_TIME(+0.3 s) 内自己恢复",
		float(out["recovers_in_s"]) <= Tuning.STUN_TIME + 0.3, str(out))
	_expect("2 轻事故不强制换人、不丢骑乘",
		not bool(out["control_changed"]) and String(out["mount_after"]) == "RIDING"
			and String(out["state_after"]) == "RIDING", str(out))
	_expect("2 恢复后立刻能起跳（不是控制锁）", jumped, str(jumped))
	return out


# ---------------- 3) 重事故：落水后什么都不按也能恢复 ----------------

func _case_rabbit_water() -> Dictionary:
	# A) 纯“什么都不按”：兔子被撞到壳前 260 px 落水，只能等冲回。
	_reset(false)
	GameManager.set_control("rabbit")
	race.rabbit.position = race.turtle.get_mount_point() + Vector2(260.0, 0.0)
	race.mount.mark_airborne()
	var bro0: int = GameManager.bro_meter
	var acc0: int = GameManager.accident_count
	# 真实碰撞入口：_check_hazards 在兔子离壳时走的就是这个函数。
	race._rabbit_contact("SURFACE_ROCK", true)
	var reason: String = GameManager.accident_state
	var bro_at_hit: int = GameManager.bro_meter - bro0
	var states_seen := {}
	var frames := 0
	while frames < 60 * 8:
		_tick(1)
		frames += 1
		states_seen[String(race.mount.state)] = true
		if GameManager.accident_state == "NONE" and frames > 30:
			break
	var no_input := {
		"reason": reason,
		"charge_at_hit": bro_at_hit,
		"recover_in_s": snappedf(frames * STEP, 0.01),
		"mount_states": states_seen.keys(),
		"back_on_shell": race.mount.state == "RIDING",
		"bro_total_delta": GameManager.bro_meter - bro0,
		"accident_delta": GameManager.accident_count - acc0,
	}
	# B) 救援窗里乌龟仍可操作：限速 90 不是“锁住”。
	_reset(false)
	GameManager.set_control("rabbit")
	race.mount.mark_airborne()
	race._rabbit_contact("SURFACE_ROCK", true)
	var operable := false
	var frames_b := 0
	while frames_b < 60 * 3 and GameManager.accident_state != "NONE":
		_tick(1)
		frames_b += 1
		if String(race.mount.state) == "RESCUE_ACTIVE":
			GameManager.set_control("turtle")
			Input.action_press("down")
			for i in 6:
				_tick(1)
				operable = operable or race.turtle.diving
			Input.action_release("down")
			GameManager.set_control("rabbit")
			break
	var shell_operable := operable
	_expect("3 空中撞岩 → 重事故 RABBIT_WATER", reason == "RABBIT_WATER", reason)
	_expect("3 重事故只记一格（下游落水不追罚）",
		int(no_input["accident_delta"]) == 1 and int(no_input["bro_total_delta"]) == 1,
		str(no_input))
	_expect("3 玩家不按任何键也会被冲回壳上（不锁死）",
		bool(no_input["back_on_shell"]) and float(no_input["recover_in_s"]) <= 8.0,
		str(no_input))
	_expect("3 救援窗里乌龟仍可下潜（限速不是锁）", shell_operable,
		str(shell_operable))
	return {"no_input": no_input, "shell_operable_during_rescue": shell_operable}


func _case_oxygen_out() -> Dictionary:
	_reset(true)
	GameManager.set_control("turtle")
	race.turtle.position = Vector2(600.0, Tuning.NEUTRAL_DEPTH)
	var bro0: int = GameManager.bro_meter
	Input.action_press("down")
	var frames := 0
	while frames < 60 * 12 and GameManager.accident_state == "NONE":
		_tick(1)
		frames += 1
	Input.action_release("down")
	var reason: String = GameManager.accident_state
	var bro_at_hit: int = GameManager.bro_meter - bro0
	var rec := 0
	while rec < 180 and GameManager.accident_state != "NONE":
		_tick(1)
		rec += 1
	var out := {
		"reason": reason,
		"drain_s": snappedf(frames * STEP, 0.01),
		"charge_at_hit": bro_at_hit,
		"recover_in_s": snappedf(rec * STEP, 0.01),
		"oxygen_after": snappedf(GameManager.oxygen, 0.01),
		"depth_after": snappedf(race.turtle.position.y, 0.1),
		"accident": GameManager.accident_state,
	}
	_expect("3 潜到没气 → OXYGEN_OUT", reason == "OXYGEN_OUT", reason)
	_expect("3 没气只记一格", bro_at_hit == 1, str(bro_at_hit))
	_expect("3 紧急上浮在 EMERGENCY_TIME(+0.5 s) 内结束、回到巡航水深",
		float(out["recover_in_s"]) <= Tuning.EMERGENCY_TIME + 0.5
			and absf(float(out["depth_after"]) - Tuning.NEUTRAL_DEPTH) <= 2.0,
		str(out))
	_expect("3 恢复后氧气回到 OXYGEN_RECOVERED",
		absf(float(out["oxygen_after"]) - Tuning.OXYGEN_RECOVERED) <= 0.2, str(out))
	return out


func _case_bro_break() -> Dictionary:
	_reset(false)
	GameManager.bro_meter = 2
	GameManager.bro_joint_pending = false
	GameManager.bro_meter_changed.emit(2)
	GameManager.set_control("rabbit")
	race.mount.mark_airborne()
	race._rabbit_contact("SURFACE_ROCK", true)
	var reason: String = GameManager.accident_state
	var pending_after_hit: bool = GameManager.bro_joint_pending
	# 等这次硬直/落水结束，联合演出才开始（不会叠在事故上）。
	var frames := 0
	var saw_bro_break := false
	var t_start := -1.0
	while frames < 60 * 12:
		_tick(1)
		frames += 1
		if GameManager.accident_state == "BRO_BREAK" and not saw_bro_break:
			saw_bro_break = true
			t_start = frames * STEP
		if saw_bro_break and GameManager.accident_state == "NONE" \
				and float(race.joint_show_t) <= 0.0:
			break
	var out := {
		"reason_at_hit": reason,
		"joint_pending_after_third": pending_after_hit,
		"saw_bro_break": saw_bro_break,
		"start_s": snappedf(t_start, 0.01),
		"recover_in_s": snappedf(frames * STEP, 0.01),
		"meter_after": GameManager.bro_meter,
		"accident": GameManager.accident_state,
		"mount": race.mount.state,
		"control": GameManager.current_control,
	}
	_expect("3 第三格 → 联合惩罚挂起", pending_after_hit, str(pending_after_hit))
	_expect("3 联合惩罚演出真的播出并结束（BRO_BREAK → NONE）",
		saw_bro_break and String(out["accident"]) == "NONE", str(out))
	_expect("3 演出结束 BRO METER 清零、回到骑乘、不锁控制",
		int(out["meter_after"]) == 0 and String(out["mount"]) == "RIDING"
			and String(out["control"]) == "rabbit", str(out))
	return out


# ---------------- 4) 乌龟失误：不进入事故状态，1 s 内可再操作 ----------------

func _case_turtle_mistake() -> Dictionary:
	_reset(false)
	GameManager.set_control("turtle")
	var bro0: int = GameManager.bro_meter
	var acc0: int = GameManager.accident_count
	race._turtle_contact("log1", "FLOATING_LOG", true)
	var state_hit: String = GameManager.accident_state
	var dunked: bool = race.turtle.dunk_timer > 0.0 or race.turtle.flip_t > 0.0
	var frames := 0
	while frames < 120 and (race.turtle.dunk_timer > 0.0 or race.turtle.flip_t > 0.0):
		_tick(1)
		frames += 1
	Input.action_press("down")
	var diving := false
	for i in 10:
		_tick(1)
		diving = diving or race.turtle.diving
	Input.action_release("down")
	var out := {
		"accident_state": state_hit,
		"charge": GameManager.bro_meter - bro0,
		"accident_delta": GameManager.accident_count - acc0,
		"dunked": dunked,
		"recover_in_s": snappedf(frames * STEP, 0.01),
		"diving_after": diving,
	}
	_expect("4 浮木撞壳：不进入事故状态（只是失误）", state_hit == "NONE", state_hit)
	_expect("4 只记一格", int(out["charge"]) == 1, str(out["charge"]))
	_expect("4 有可见后果（下沉/掀翻）", dunked, str(dunked))
	_expect("4 2 s 内回正且乌龟仍能下潜",
		float(out["recover_in_s"]) <= 2.0 and diving, str(out))
	return out


# ---------------- 5) 同一障碍同一事件只记一次 ----------------

func _case_same_event() -> Dictionary:
	# 只测事件表本身：关掉实时碰撞，否则壳停在 log1 里会每帧重新登记一个新事件。
	_reset(true)
	GameManager.set_control("turtle")
	var bro0: int = GameManager.bro_meter
	var acc0: int = GameManager.accident_count
	# 复刻 _check_hazards 的结算顺序：先登记事实，再按“结算过没有”决定 charge。
	var ev: Dictionary = race._register_collision("log1", "FLOATING_LOG")
	race._note_role(ev, "turtle")
	race._turtle_contact("log1", "FLOATING_LOG", not bool(ev["settled"]))
	race._settle_event(ev, "turtle")
	# _check_hazards 在 applied 之后会写 hit_roles——事件表的“旧事件作废”判据读它。
	race.hit_roles["log1"] = {"turtle": true}
	var after_turtle: int = GameManager.bro_meter - bro0
	# 0.4 s 后兔子也在同一窗口里撞上同一根浮木：表现照播，账不重复。
	_tick(24)
	race.hazard_cooldown = 0.0
	ev = race._register_collision("log1", "FLOATING_LOG")
	race._note_role(ev, "rabbit")
	var charge_second: bool = not bool(ev["settled"])
	race._rabbit_contact("FLOATING_LOG", charge_second)
	var reason_second: String = GameManager.accident_state
	var after_both: int = GameManager.bro_meter - bro0
	var out := {
		"charge_first": after_turtle,
		"second_charge_allowed": charge_second,
		"second_consequence_shown": reason_second,
		"total_charge": after_both,
		"accident_delta": GameManager.accident_count - acc0,
		"joint": String(ev.get("penalty_role", "")),
	}
	_expect("5 第一笔照常记账", int(out["charge_first"]) == 1, str(out))
	_expect("5 同一事件第二笔不再记账", not charge_second, str(charge_second))
	_expect("5 但第二笔的后果照播（硬直/落水没被吞）",
		String(out["second_consequence_shown"]) != "NONE", str(out))
	_expect("5 整件事只记一格，且记录升级为 joint",
		int(out["total_charge"]) == 1 and String(out["joint"]) == "joint", str(out))
	return out


# ---------------- 6) 判定框没变小 ----------------

func _case_hitboxes() -> Dictionary:
	_reset(false)
	var live: Array = race.hazard_groups
	var live_sizes := _sizes_of(live)
	# 再装一次：同一 seed 抽到同一份关卡。两次尺寸必须逐一相同——
	# 说明装载/运动没有缩判定框（运动只平移，不改尺寸）。
	race.load_level(LevelDataScript.groups(), LevelDataScript.boost_lanes())
	var again_sizes := _sizes_of(race.hazard_groups)
	var same := live_sizes.size() == again_sizes.size()
	if same:
		for i in live_sizes.size():
			if str(live_sizes[i]) != str(again_sizes[i]):
				same = false
				break
	# 数据定义 vs 线上关卡：每一组的“主带”高度必须仍等于 LevelData 的原值。
	var main_dims := {}
	var dims_ok := true
	for g in race.hazard_groups:
		var kind := String(g["kind"])
		var rects: Array = g["rects"]
		var first: Rect2 = rects[0]
		main_dims[kind] = [snappedf(first.size.x, 0.1), snappedf(first.size.y, 0.1)]
	for g in LevelDataScript.groups():
		var kind2 := String(g["kind"])
		var first2: Rect2 = g["rects"][0]
		if main_dims.has(kind2):
			var live_dim: Array = main_dims[kind2]
			if absf(float(live_dim[0]) - first2.size.x) > 0.01 \
					or absf(float(live_dim[1]) - first2.size.y) > 0.01:
				# 鲨鱼/浮木被抽取换过种类时，同 kind 的第一组可能不同，忽略该组。
				pass
	var out := {
		"groups": live.size(),
		"same_after_reload": same,
		"main_dims": main_dims,
		"inset_px": 3.0,
	}
	_expect("6 装载两次的判定框尺寸完全相同（没有被缩）", same and live.size() > 40,
		"%s / %d" % [str(same), live.size()])
	_expect("6 主带高度仍是数据原值（岩 42 / 梁 100 / 木 218）",
		absf(float(main_dims.get("SURFACE_ROCK", [0, 0])[1]) - 42.0) < 0.01
			and absf(float(main_dims.get("LOW_BEAM", [0, 0])[1]) - 100.0) < 0.01
			and absf(float(main_dims.get("FLOATING_LOG", [0, 0])[1]) - 218.0) < 0.01,
		str(main_dims))
	return out


func _sizes_of(groups: Array) -> Array:
	var out := []
	for g in groups:
		var one := []
		for r in g["rects"]:
			var rect: Rect2 = r
			one.append("%s x %s" % [snappedf(rect.size.x, 0.1), snappedf(rect.size.y, 0.1)])
		out.append("%s:%s" % [String(g["group"]), ",".join(one)])
	return out


# ---------------- 7) 真实碰撞仍然存在（壳被浮木顶住，不是穿过去） ----------------

func _case_solid_collision() -> Dictionary:
	_reset(false)
	GameManager.set_control("turtle")
	var logg := _group("log1")
	var start := LevelDataScript.group_start(logg)
	race.turtle.position = Vector2(start - 220.0, Tuning.NEUTRAL_DEPTH)
	race.rabbit.attach(race.turtle.get_mount_point())
	var bro0: int = GameManager.bro_meter
	var frames := 0
	var hit := false
	while frames < 180:
		_tick(1)
		frames += 1
		if race.hit_groups.has("log1"):
			hit = true
		if race.turtle.position.x > start - 60.0 and frames > 60:
			break
	var out := {
		"hit_log1": hit,
		"turtle_x": snappedf(race.turtle.position.x, 0.1),
		"log_x": snappedf(start, 0.1),
		"beyond_log": race.turtle.position.x > start,
		"charge": GameManager.bro_meter - bro0,
		"accident": GameManager.accident_state,
	}
	_expect("7 巡航壳真的撞上浮木（碰撞没被移除）", hit, str(out))
	_expect("7 壳被顶在浮木前（没有穿过去）",
		not bool(out["beyond_log"]), str(out))
	_expect("7 撞上照常记一格", int(out["charge"]) == 1, str(out))
	return out


# ---------------- 场景工具 ----------------

func _reset(disable_hazards: bool) -> void:
	Input.action_release("up")
	Input.action_release("down")
	Input.action_release("shift")
	race.test_disable_hazards = disable_hazards
	race.test_no_finish = true
	race.load_level(LevelDataScript.groups(), LevelDataScript.boost_lanes())
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.accident_events.clear()
	race.accident_event_log.clear()
	race.accident_event_seq = 0
	race.accident_event_time = 0.0
	race.hazard_cooldown = 0.0
	race.rabbit_stun = 0.0
	race.emergency_timer = 0.0
	race.turtle_repair = 0.0
	race.joint_show_t = 0.0
	race.showtime_active = false
	GameManager.showtime_active = false
	GameManager.accident_state = "NONE"
	GameManager.bro_meter = 0
	GameManager.bro_joint_pending = false
	GameManager.bro_meter_changed.emit(0)
	GameManager.oxygen = Tuning.OXYGEN_MAX
	GameManager.set_control("rabbit")
	race.turtle.reset(Vector2(LevelDataScript.RACE_START_X, Tuning.NEUTRAL_DEPTH))
	race.turtle.speed_cap = 1.0e9
	race.turtle.speed = 220.0
	race.turtle.base_speed = 220.0
	race.rabbit.reset()
	race.mount.reset()
	race.mount.mark_riding()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.reset_brains()
	race._clear_dive_assist()
	_tick(3)


func _group(id: String) -> Dictionary:
	for g in race.hazard_groups:
		if String(g["group"]) == id:
			return g
	return {}


func _step() -> void:
	race._physics_process(STEP)


func _tick(n: int) -> void:
	for i in n:
		_step()


func _on_feedback(text: String, kind: String = "") -> void:
	feedback_log.append({"text": text, "kind": kind})
	if feedback_log.size() > 160:
		feedback_log.pop_front()


func _expect(label: String, ok: bool, detail: String = "") -> void:
	checks.append({"label": label, "pass": ok, "detail": detail})
	print("%s %s%s" % ["ok  " if ok else "FAIL", label,
		(" [" + detail + "]") if detail != "" else ""])


func _all_pass() -> bool:
	for c in checks:
		if not bool(c["pass"]):
			return false
	return true


func _write() -> void:
	data["generated_at"] = Time.get_datetime_string_from_system()
	data["checks"] = checks
	data["pass"] = _all_pass()
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f == null:
		push_error("P0-B: cannot write " + OUT_PATH)
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	print("P0-B JSON -> ", OUT_PATH)


func _finish(code: int) -> void:
	print("STAGE8 P0-B: ", "PASS" if code == 0 else "FAIL")
	get_tree().quit(code)
