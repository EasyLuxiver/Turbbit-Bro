extends Node
## 阶段 4 SHIFT 手感验收（TBB-SHIFT-FEEL-03 §2/§3）。
##
## §2 SHIFT 电击表现：正式 Race 场景里确有订阅、一次换人恰好一发表现 + 一段音效，
##    受激只落在新角色身上，不改位置、不加冷却、不阻塞输入。
## §3 输入宽容：兔子跳跃缓冲 120 ms、离壳后 100 ms 宽限跳、同帧 SHIFT+动作交付给
##    新角色一次、连续快速 SHIFT 不追发、30/60/120 Hz 结论一致。
##
## 固定步长手动推进真实 race.gd 的 _physics_process，不依赖真机帧率。
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT res://scenes/stage4_shift_feel.tscn
## 输出：docs/reports/stage4-shift-feel.json
##
## 这不是人工试玩：只证明状态机与事件行为，手感和有趣性仍需制作人判定。

const Tuning = preload("res://scripts/systems/tuning.gd")
const OUT_PATH := "res://docs/reports/stage4-shift-feel.json"
const NEAR_LEAD := 0.10
const FAR_LEAD := 0.13

var is_runner := false
var failures: Array[String] = []
var race
var step := 1.0 / 60.0
var data := {}


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4ShiftFeelRunner"
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

	# 只测手感层，不测障碍；也不冲线、不写 best.json。
	race.test_disable_hazards = true
	race.test_no_finish = true
	race.set_physics_process(false)

	data["fx"] = _test_fx()
	data["jump_buffer"] = _test_jump_buffer()
	data["coyote"] = _test_coyote()
	data["shift_action"] = _test_shift_action()
	data["rapid_shift"] = _test_rapid_shift()
	data["rates"] = _test_rates()
	_write_json()
	_finish()


## ---- §2 SHIFT 电击表现 ----

func _test_fx() -> Dictionary:
	_setup_stable()
	var fx = race.shift_fx
	_check(fx != null, "formal Race owns a ShiftFX controller")
	if fx == null:
		return {}

	var connected := false
	for conn in GameManager.shift_shocked.get_connections():
		var cb: Callable = conn["callable"]
		if cb.get_object() == fx and cb.get_method() == "on_shift_shocked":
			connected = true
	_check(connected, "formal Race subscribes GameManager.shift_shocked -> ShiftFX")

	var fx0: int = fx.fx_count
	var sfx0: int = fx.sfx_count
	var frames0: int = fx.sfx_frames
	var tp: Vector2 = race.turtle.position
	var rp: Vector2 = race.rabbit.position
	_swap()
	var same_call: bool = fx.fx_count == fx0 + 1 and fx.sfx_count == sfx0
	_check(same_call, "one player SHIFT -> exactly one FX and no SFX event (%d/%d)"
		% [fx.fx_count - fx0, fx.sfx_count - sfx0])
	# PLAYFUL-04 硬边界：SHIFT 电流音效关闭。视觉保留，音频帧增量必须为 0。
	_check(fx.sfx_frames - frames0 == 0,
		"SHIFT SFX is muted: 0 audio frames pushed (%d)" % (fx.sfx_frames - frames0))
	var audio_children := 0
	for child in fx.get_children():
		if child is AudioStreamPlayer:
			audio_children += 1
	_check(audio_children == 0, "muted SHIFT does not even create an AudioStreamPlayer (%d)" % audio_children)
	_check(fx.get("burst_stream") == null, "no replacement audio stream wired in while muted")
	_check(fx.last_from == "rabbit" and fx.last_to == "turtle",
		"FX knows who was shocked (%s -> %s)" % [fx.last_from, fx.last_to])
	_check(fx._t >= 0.0 and fx._flash > 0.0, "arc + screen flash armed")
	_check(race._shift_jolt_t > 0.0 and race._shift_jolt_who == "turtle",
		"startle jolt is applied to the NEW character only (%s)" % race._shift_jolt_who)
	_check(race._camera_pulse_t > 0.0, "camera pulse scheduled (%0.3f s)" % race._camera_pulse_t)
	_check(race.turtle.position == tp and race.rabbit.position == rp,
		"FX does not move bodies in the event frame")
	_check(GameManager.current_control == "turtle", "control handed to the new character")

	if race.hud != null and race.hud.has_method("_refresh"):
		race.hud._refresh()
	var hud_text := ""
	if race.hud != null and race.hud.control_label != null:
		hud_text = race.hud.control_label.text
	_check(hud_text.contains("TURTLE"), "HUD control text syncs to the new character (%s)" % hud_text)

	# FEEL-09 P0-C：第一次换手已在上面发生；立刻再按应被 0.20 s 锁定挡住。
	GameManager.toggle_control()
	var blocked_ok: bool = fx.fx_count == fx0 + 1 \
		and GameManager.current_control == "turtle"
	_check(blocked_ok, "0.20 s lock: immediate second shift is ignored (no second FX)")
	# 锁定到期后再按，第二发表现才成立。
	_swap()
	var second_ok: bool = fx.fx_count == fx0 + 2 \
		and GameManager.current_control == "rabbit"
	_check(second_ok, "after 0.20 s the second shift fires its own FX (SFX still muted)")

	# 程序换人（set_control）不冒充玩家电击。
	var direct0: int = fx.fx_count
	GameManager.set_control("turtle")
	GameManager.set_control("rabbit")
	_check(fx.fx_count == direct0, "programmatic set_control does not fake the electric shock")

	return {
		"subscribed": connected,
		"fx_delta": 2,
		"sfx_delta": fx.sfx_count - sfx0,
		"sfx_muted": fx.sfx_count == sfx0 and fx.sfx_frames == frames0,
		"audio_players": audio_children,
		"frames_per_burst": fx.sfx_frames - frames0,
		"hud_text": hud_text,
		"jolt_who": race._shift_jolt_who,
		"camera_pulse": snappedf(race._camera_pulse_t, 0.001),
	}


## ---- §3 输入宽容 ----

func _test_jump_buffer() -> Dictionary:
	_setup_stable()
	var land := _jump_land_ticks()
	_check(land > 10, "baseline rabbit jump lands after %d ticks" % land)
	if land <= 10:
		return {"land_ticks": land}

	var near_lead: int = maxi(int(floor(NEAR_LEAD / step)), 1)
	var far_lead: int = maxi(int(ceil(FAR_LEAD / step)), near_lead + 1)
	var near := _jump_with_lead(land, near_lead)
	var far := _jump_with_lead(land, far_lead)
	# 前后对照：旧规则没有缓冲（只认落地当帧）。同一次 100 ms 提前按下，
	# 把窗口临时换成 0 复现旧行为——按了等于没按；换回 0.12 才生效。
	race.input_buffer_override = 0.0
	var before := _jump_with_lead(land, near_lead)
	race.input_buffer_override = -1.0
	_check(not before["jumped"], "before: no buffer -> %.0f ms-early press lost"
		% (near_lead * step * 1000.0))
	_check(near["jumped"], "press %.0f ms before landing still jumps (lead %d ticks, age %0.3f)"
		% [near_lead * step * 1000.0, near_lead, near["age"]])
	_check(not far["jumped"], "press %.0f ms before landing expires, no queued jump (lead %d ticks, age %0.3f)"
		% [far_lead * step * 1000.0, far_lead, far["age"]])
	_check(not _has_buffered_jump(far["log"]), "expired buffer is cleared, not delivered later")
	return {
		"land_ticks": land,
		"before": before,
		"near": near,
		"far": far,
	}


func _test_coyote() -> Dictionary:
	var early := _coyote_case(false)
	var late := _coyote_case(true)
	_check(early["jumped"], "within 100 ms of leaving the surface still jumps (coyote %0.3f)"
		% early["coyote_before"])
	_check(not late["jumped"], "after the 100 ms coyote expires, no jump (coyote %0.3f)"
		% late["coyote_before"])
	_check(late["still_riding"], "late press does not queue a jump for later")
	return {"early": early, "late": late}


func _test_shift_action() -> Dictionary:
	# 兔子 → 乌龟：同帧 SHIFT + ↑，交给人后只该乌龟跃起。
	_setup_stable()
	race._note_up_input()
	_swap()
	_tick(1)
	var leap: bool = race.turtle.leap_active
	var rabbit_air: bool = race.mount.state != "RIDING" or race.rabbit.is_airborne()
	_check(leap, "same-frame SHIFT+up delivered to the turtle (leap)")
	_check(not rabbit_air, "the old character does not also jump (%s/%s)"
		% [race.mount.state, race.rabbit.state])

	# 乌龟 → 兔子：同帧 SHIFT + ↑，只该兔子跳。
	_setup_stable()
	GameManager.set_control("turtle")
	race._note_up_input()
	_swap()
	_tick(1)
	var rabbit_jump: bool = race.rabbit.is_airborne()
	var turtle_leap: bool = race.turtle.leap_active
	_check(rabbit_jump, "same-frame SHIFT+up delivered to the rabbit (jump)")
	_check(not turtle_leap, "turtle does not also leap")

	# 略晚按：换人完成后同一帧内再按，也归新角色。
	_setup_stable()
	_swap()
	race._note_up_input()
	_tick(1)
	_check(race.turtle.leap_active, "slightly late press after the handoff still goes to the turtle")

	# 无效动作：在空中按 ↑ 不会多出一次跳；也不会存到下一次落地之后。
	_setup_stable()
	race._note_up_input()
	_tick(1)
	_check(race.mount.state == "AIRBORNE", "first jump airborne")
	race._note_up_input()
	_tick(1)
	var mid_air_log_size: int = race.input_buffer_log.size()
	_check(mid_air_log_size == 1, "mid-air up is not consumed as a second jump")
	_tick(int(ceil(FAR_LEAD / step)) + 2)
	var guard := 0
	while race.mount.state == "AIRBORNE" and guard < 240:
		_tick(1)
		guard += 1
	_check(race.mount.state == "RIDING",
		"mid-air up expired before landing and did not auto-jump on landing")

	return {
		"rabbit_to_turtle": {"leap": leap, "old_jumped": rabbit_air},
		"turtle_to_rabbit": {"jump": rabbit_jump, "old_leaped": turtle_leap},
		"mid_air_log": mid_air_log_size,
	}


func _test_rapid_shift() -> Dictionary:
	_setup_stable()
	race._note_up_input()
	_swap()
	_swap()
	_swap()
	var shifts: int = GameManager.shift_count
	_tick(1)
	var fired: bool = race.turtle.leap_active or race.rabbit.is_airborne()
	_check(not fired, "3 rapid SHIFTs invalidate the buffered action (no delayed burst)")
	_tick(30)
	var late_fired: bool = race.turtle.leap_active or race.rabbit.is_airborne()
	_check(not late_fired, "no delayed action burst 0.5 s after rapid SHIFT")
	_check(race.input_buffer_log.is_empty(), "rapid SHIFT leaves no consumed-action log")
	_check(shifts == 3, "SHIFT itself has no cooldown (%d toggles accepted)" % shifts)
	return {
		"shifts": shifts,
		"fired": fired,
		"late_fired": late_fired,
		"log": race.input_buffer_log.duplicate(true),
	}


func _test_rates() -> Dictionary:
	var out := {}
	for rate in [30, 60, 120]:
		step = 1.0 / float(rate)
		var row := {}
		row["jump_buffer"] = _test_jump_buffer()
		row["coyote"] = _test_coyote()
		row["same_frame"] = _test_shift_action_at_rate()
		out[str(rate)] = row
	step = 1.0 / 60.0
	# 三种帧率都要同时满足“略早能跳 / 过早失效”。
	for rate in out:
		var jb: Dictionary = out[rate]["jump_buffer"]
		_check(jb.get("near", {}).get("jumped", false),
			"%s Hz: jump buffer delivers" % rate)
		_check(not jb.get("far", {}).get("jumped", true),
			"%s Hz: expired buffer does not fire" % rate)
		var cy: Dictionary = out[rate]["coyote"]
		_check(cy["early"]["jumped"], "%s Hz: coyote jump works" % rate)
		_check(not cy["late"]["jumped"], "%s Hz: coyote expiry blocks jump" % rate)
		_check(out[rate]["same_frame"]["leap"], "%s Hz: same-frame SHIFT+up -> turtle leap" % rate)
		_check(not out[rate]["same_frame"]["old_jumped"],
			"%s Hz: same-frame SHIFT+up does not move the old character" % rate)
	return out


func _test_shift_action_at_rate() -> Dictionary:
	_setup_stable()
	race._note_up_input()
	_swap()
	_tick(1)
	return {
		"leap": race.turtle.leap_active,
		"old_jumped": race.mount.state != "RIDING" or race.rabbit.is_airborne(),
	}


## ---- 基座与工具 ----

## 稳定可跳基线：乌龟巡航在水面、兔子在壳上、无神游、无缓存。
func _setup_stable() -> void:
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.showtime_active = false
	race.showtime_active = false
	GameManager.shift_count = 0
	race.turtle.reset(Vector2(5200.0, Tuning.NEUTRAL_DEPTH))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.reset_brains()
	GameManager.set_control("rabbit")
	race._buf_action = ""
	race._buf_age = 0.0
	race._buf_shift_count = 0
	race._buf_event_msec = -9999
	race._up_was_pressed = false
	race._coyote_t = race.JUMP_COYOTE_TIME
	race._shift_jolt_t = 0.0
	race._camera_pulse_t = 0.0
	race.rabbit_grace = 0.0
	race.rabbit_stun = 0.0
	race.input_buffer_log.clear()
	_tick(2)


func _jump_land_ticks() -> int:
	_setup_stable()
	race._note_up_input()
	_tick(1)
	if race.mount.state != "AIRBORNE":
		return -1
	var n := 1
	while n < 600:
		_tick(1)
		n += 1
		if race.mount.state == "RIDING":
			return n
	return -1


## 一次完整起跳，在落地前 lead 个物理帧按下 ↑；返回落地后是否又跳起来。
func _jump_with_lead(land: int, lead: int) -> Dictionary:
	_setup_stable()
	race._note_up_input()
	_tick(1)
	var n := 1
	while n < land - lead:
		_tick(1)
		n += 1
	race._note_up_input()
	while n <= land + 2:
		_tick(1)
		n += 1
	var log: Array = race.input_buffer_log.duplicate(true)
	var age := 0.0
	for entry in log:
		if String(entry.get("by", "")) == "buffered_jump":
			age = float(entry.get("age", 0.0))
	return {
		"jumped": race.mount.state == "AIRBORNE",
		"age": snappedf(age if age > 0.0 else lead * step, 0.001),
		"log": log,
	}


func _coyote_case(expire: bool) -> Dictionary:
	_setup_stable()
	race.turtle.position.y = 520.0
	_tick(1)
	if expire:
		var guard := 0
		while race._coyote_t > 0.0 and guard < 120:
			race.turtle.position.y = 520.0
			_tick(1)
			guard += 1
	var coyote_before: float = race._coyote_t
	race._note_up_input()
	_tick(1)
	var jumped: bool = race.rabbit.is_airborne()
	var still_riding: bool = race.mount.state == "RIDING"
	if not jumped:
		_tick(10)
		still_riding = still_riding and race.mount.state == "RIDING"
	return {
		"jumped": jumped,
		"still_riding": still_riding,
		"coyote_before": snappedf(coyote_before, 0.001),
		"turtle_y": snappedf(race.turtle.position.y, 0.1),
	}


func _has_buffered_jump(log: Array) -> bool:
	for entry in log:
		if String(entry.get("by", "")) == "buffered_jump":
			return true
	return false


func _tick(n: int) -> void:
	for i in n:
		race._physics_process(step)


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


## 本探针测 FX / 缓冲，不测 0.20 s 锁定；换手前把锁定走完，
## 让“快速连续换手”的场景仍按原来的时序执行。
func _swap() -> void:
	if GameManager.shift_lock_t > 0.0:
		GameManager.tick_shift_lock(0.25)
	GameManager.toggle_control()


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
		print("STAGE4 SHIFT FEEL: PASS")
	else:
		print("STAGE4 SHIFT FEEL: FAIL")
		for item in failures:
			print("  - " + item)
	print("  data: " + JSON.stringify(data))
	get_tree().quit(0 if failures.is_empty() else 1)
