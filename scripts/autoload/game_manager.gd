extends Node
## 全局状态：游戏流程、控制权、计时、调试数据。
## 控制权与角色状态由 race 场景每帧写回，这里只保存可观察值。

const Tuning = preload("res://scripts/systems/tuning.gd")
const LevelDataScript = preload("res://scripts/systems/level_data.gd")

enum GameState { MENU, RUNNING, PAUSED, RESULT, FAILED }

signal accident(reason: String)
signal pickup_success
signal rescue_done
signal hint(text: String)
signal center_message(text: String, color: Color)
## 干净通过 / BRO PASS 的短反馈，和“首次介绍”分开，避免重复教学。
signal feedback(text: String, kind: String)
signal prompt(text: String)
## BRO METER 三格共享事故槽：每涨一格、满格各发一次。
signal bro_meter_changed(slots: int)
signal bro_meter_full
## SHIFT 电击的表现接口（TBB-SHIFT-CORE-02 §8）：只在玩家真正换人那一帧发出。
## 订阅者只做视觉/音效，不得改控制、不得阻塞输入、不得加冷却/惩罚。
signal shift_shocked(from_who: String, to_who: String)

const MENU_SCENE := "res://scenes/menu.tscn"
const RACE_SCENE := "res://scenes/race.tscn"
const RESULT_SCENE := "res://scenes/result.tscn"
const FAIL_SCENE := "res://scenes/fail.tscn"
const STORY_SCENE := "res://scenes/opening_comic.tscn"
const TUTORIAL_SCENE := "res://scenes/tutorial.tscn"
const BEST_PATH := "user://best.json"
## 分数表改版：旧档的 best_score 用的是另一套计分，和新表不可比。
## 只丢弃最高分，最佳时间/事故/连胜继续保留。
const SCORE_MODEL := 2

var state: GameState = GameState.MENU
## P1-B：制作人测试入口。菜单写模式，producer_case 读取；测试期间不写纪录。
var producer_mode := ""
var test_no_best := false
## FEEL-11：首次启动先看 7 格连环画，再进 60–90 s 教学；之后直接比赛。
var story_seen := false
var tutorial_done := false
var current_control: String = "rabbit"
var has_shifted: bool = false
var shift_count: int = 0
## FEEL-09 P0-C：成功换手后的短锁定。第一次换仍然立刻生效；
## 0.20 s 内的第二次 SHIFT 直接忽略（不排队、不延迟补发）。
## 目的不是提高操作门槛，而是让“什么时候换”变成一次要提前做的决定。
const SHIFT_LOCK_TIME := 0.20
var shift_lock_t: float = 0.0
var race_time: float = 0.0
var rabbit_state: String = "RIDING"
var turtle_state: String = "CRUISING"
var mount_state: String = "RIDING"
var oxygen: float = Tuning.OXYGEN_MAX
var oxygen_phase: String = "SAFE"
var turtle_speed: float = 220.0
var accident_state: String = "NONE"
var accident_count: int = 0
var pickup_count: int = 0
var slide_progress: float = 0.0
var pickup_window: bool = false
var rabbit_phase: String = "RIDING"
var turtle_phase: String = "CRUISING"
var combo: int = 0
var combo_max: int = 0
var showtime_count: int = 0
var showtime_active: bool = false

# ---- 阶段 3：区域、评分、结算与个人纪录。 ----
var zone: int = 1
var zone_name_text: String = "SUNNY COAST"
var zones_visited: Dictionary = {1: true}
var rabbit_casualties: int = 0
var turtle_failures: int = 0
var perfect_cooperation: int = 0
var perfect_streak: int = 0
var best_streak: int = 0
var total_score: int = 0
var grade: String = ""
var grade_name: String = ""
var finish_time: float = 0.0
var finished: bool = false
var new_best_time := false
var new_best_score := false
var new_best_streak := false

var best_time: float = -1.0
var best_accidents: int = -1
var best_score: int = -1
var best_streak_record: int = 0

# ---- 阶段 4：BRO METER（三格共享事故槽）与指令里的分数表。 ----
const BRO_METER_SLOTS := 3
var bro_meter: int = 0
var bro_meter_max: int = 0
## FEEL-10 P0-A：累计失误满格时，只让“本次失误的角色”短暂捣乱，
## 不再把三格累计误判成两人同时出事。
var role_mischief_pending := false
var role_mischief_role := ""
## FEEL-24：一次失误就产生可读的抱怨事件；没有 3 格计数。
var complaint_role := ""
var complaint_t := 0.0
## FEEL-15：两个角色各自的惩罚条（内部 0..3）；HUD 当前显示主控角色的那一条。
## bro_meter 继续作为兼容/显示值，不再代表“两人共享”。
var bro_meter_role := {"rabbit": 0, "turtle": 0}
## MISCHIEF 进行中时锁住该角色的惩罚条：失误照常扣分/计事故，但不再充能。
var mischief_lock_role := ""
var failure_reason := ""
## FEEL-25：频繁落水造成的“气短”层数；不显示数字，靠气泡/动作表达。
var waterlogged := 0
var waterlogged_t := 0.0
## 兼容旧探针：真正的联合事故由 race 的双人危险检测触发，不再由 BRO 满格触发。
var bro_joint_pending := false
var joint_accident_count: int = 0
var combo_dive_count: int = 0
var combo_ollie_count: int = 0
var clean_pass_count: int = 0
## §七-9：主动救援成功次数（只在 _rescue_catch 里加，计时器修复不算）。
var rescue_success_count: int = 0
## G16：亲手喂到（操控乌龟时吃到食物）次数。兔子在骑时自动吃的不算。
var snack_switch_count: int = 0
## 逐笔分数（reason/points），给测量与结算核对用；只保留最近若干笔。
var score_log: Array = []


func _ready() -> void:
	_bind_inputs()
	_load_best()


func _process(delta: float) -> void:
	if state == GameState.RUNNING:
		race_time += delta


## FEEL-09 P0-C：锁定按比赛模拟时间走。由 race._physics_process 调用，
## 这样 30/60/120 Hz 与测试里的手动步进都一致；暂停/开场不推进。
func tick_shift_lock(delta: float) -> void:
	shift_lock_t = maxf(shift_lock_t - delta, 0.0)


func _bind_inputs() -> void:
	var keys := {
		"shift": [KEY_SHIFT],
		"boost": [KEY_RIGHT],
		"pop": [KEY_SPACE],
		"up": [KEY_UP],
		"down": [KEY_DOWN],
		"left": [KEY_LEFT],
		"right": [KEY_RIGHT],
		"pause": [KEY_ESCAPE],
		"restart": [KEY_R],
		"confirm": [KEY_ENTER],
		"menu": [KEY_M],
	}
	for action in keys.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shift"):
		toggle_control()
	elif event.is_action_pressed("pause"):
		toggle_pause()
	elif event.is_action_pressed("restart"):
		# 结算界面也承诺 R 重开；阶段 3 的第二次通关就走这条路。
		if state == GameState.RUNNING or state == GameState.PAUSED \
				or state == GameState.RESULT:
			start_race()
	elif event.is_action_pressed("menu"):
		if state == GameState.PAUSED or state == GameState.RESULT 				or state == GameState.FAILED:
			go_to_menu()


func start_game_flow() -> void:
	if not story_seen:
		state = GameState.MENU
		get_tree().change_scene_to_file(STORY_SCENE)
		return
	if not tutorial_done:
		start_tutorial()
		return
	start_race()


func start_tutorial() -> void:
	_reset_run()
	test_no_best = true
	state = GameState.RUNNING
	get_tree().change_scene_to_file(TUTORIAL_SCENE)


func start_race() -> void:
	_reset_run()
	# 从正式流程进来时故事/教学已经看过；直接重开也跳过它们，避免重复错乱。
	story_seen = true
	tutorial_done = true
	test_no_best = false
	state = GameState.RUNNING
	get_tree().change_scene_to_file(RACE_SCENE)


func go_to_menu() -> void:
	state = GameState.MENU
	get_tree().change_scene_to_file(MENU_SCENE)


func finish_race() -> void:
	state = GameState.RESULT
	get_tree().change_scene_to_file(RESULT_SCENE)


## FEEL-15：氧气耗尽不是普通结算，也不能写最佳纪录；独立失败画面只允许重开/回菜单。
func finish_failure(reason: String = "OXYGEN_OUT") -> void:
	if state == GameState.FAILED:
		return
	failure_reason = reason
	test_no_best = true
	finished = false
	state = GameState.FAILED
	get_tree().change_scene_to_file(FAIL_SCENE)


func toggle_control() -> void:
	if state != GameState.RUNNING:
		return
	# FEEL-22：冲线演出已经结算，别再让 SHIFT 改控制权；结算页的重开不受影响。
	if finished:
		return
	# 主动救援是唯一允许在事故中换人的状态：玩家必须切到乌龟把兔子接上来。
	if accident_state != "NONE" and accident_state != "RABBIT_WATER" \
			and accident_state != "RABBIT_AIR":
		return
	# FEEL-09 P0-C：成功换手后 0.20 s 锁定。锁定期内不排队、不延迟补发；
	# 给一条轻量反馈，避免玩家以为按键丢了。
	if shift_lock_t > 0.0:
		feedback.emit(Locale.t("feedback.shift_lock"), "shift")
		return
	var from_who := current_control
	current_control = "rabbit" if current_control == "turtle" else "turtle"
	# FEEL-25：切到抱怨角色只阻止 MISCHIEF，不再瞬间抹掉抱怨状态；
	# 抱怨窗口自然过期，或由 فعال MISCHIEF 结束清除。
	has_shifted = true
	shift_count += 1
	shift_lock_t = SHIFT_LOCK_TIME
	# HUD 跟着主控角色切换显示它自己的惩罚条。
	bro_meter = int(bro_meter_role.get(current_control, 0))
	bro_meter_changed.emit(bro_meter)
	shift_shocked.emit(from_who, current_control)


func set_control(who: String) -> void:
	if who == current_control:
		return
	current_control = who
	has_shifted = true


func toggle_pause() -> void:
	if state == GameState.RUNNING:
		state = GameState.PAUSED
	elif state == GameState.PAUSED:
		state = GameState.RUNNING
	# 主菜单的 ESC 由菜单自己处理（弹退出确认），这里不直接退出游戏。


func _reset_run() -> void:
	current_control = "rabbit"
	has_shifted = false
	shift_count = 0
	shift_lock_t = 0.0
	race_time = 0.0
	rabbit_state = "RIDING"
	turtle_state = "CRUISING"
	mount_state = "RIDING"
	oxygen = Tuning.OXYGEN_MAX
	oxygen_phase = "SAFE"
	turtle_speed = 220.0
	accident_state = "NONE"
	accident_count = 0
	pickup_count = 0
	slide_progress = 0.0
	pickup_window = false
	rabbit_phase = "RIDING"
	turtle_phase = "CRUISING"
	combo = 0
	combo_max = 0
	showtime_count = 0
	showtime_active = false
	zone = 1
	zone_name_text = "SUNNY COAST"
	zones_visited = {1: true}
	rabbit_casualties = 0
	turtle_failures = 0
	perfect_cooperation = 0
	perfect_streak = 0
	best_streak = 0
	total_score = 0
	grade = ""
	grade_name = ""
	finish_time = 0.0
	finished = false
	new_best_time = false
	new_best_score = false
	new_best_streak = false
	bro_meter = 0
	bro_meter_max = 0
	bro_joint_pending = false
	role_mischief_pending = false
	role_mischief_role = ""
	complaint_role = ""
	complaint_t = 0.0
	waterlogged = 0
	waterlogged_t = 0.0
	bro_meter_role = {"rabbit": 0, "turtle": 0}
	complaint_role = ""
	complaint_t = 0.0
	mischief_lock_role = ""
	failure_reason = ""
	last_mistake_role = ""
	joint_accident_count = 0
	combo_dive_count = 0
	combo_ollie_count = 0
	clean_pass_count = 0
	rescue_success_count = 0
	snack_switch_count = 0
	score_log.clear()


func state_name() -> String:
	return GameState.keys()[state]


## G17：结算页「下次试试」只读本局计数，按优先级挑一条最可能让人想再来一次的建议。
## 连招是核心动作，所以先教；喂食每区都有机会；救援只在真摔过又没救回时才提。
## 纯函数：不读写本局任何状态，三条都不缺就返回空串（结算页整行不显示）。
func next_try_key() -> String:
	if combo_dive_count + combo_ollie_count == 0:
		return "result.try_combo"
	if snack_switch_count == 0:
		return "result.try_snack"
	if accident_count > 0 and rescue_success_count == 0:
		return "result.try_rescue"
	return ""


# ---- 阶段 3：事件记账。 ----

func note_zone(id: int, name: String) -> void:
	zone = id
	zone_name_text = name
	zones_visited[id] = true


## 统一的失误记账（Phase G）：所有“有效失误”只走这一条路——
## 兔子撞障碍、乌龟撞浪、落水/翻壳等事故都记 1 格 BRO METER、扣 100 分。
## BRO METER 是唯一的持续惩罚；daze_time 只做短硬直，不许再记第二笔。
func note_mistake(reason: String, role: String = "") -> void:
	var who := role
	if who == "":
		who = _role_for_reason(reason)
	last_mistake_role = who
	accident_count += 1
	perfect_streak = 0
	add_score(-100, "mistake:" + reason)
	if who not in ["rabbit", "turtle"]:
		return
	# FEEL-24：不再累计 3 格；一次失误生成一次可读的抱怨事件。
	# PHASE-1：抱怨窗口从 2.6 s 拉到 7 s。玩家离开该角色后，捣乱才有机会
	# 真正发生；2.6 s 在 220–260 px/s 下往往还没离开安全区就过期，导致
	# 玩家几乎看不到“电对方/拽绳”。
	if mischief_lock_role == who:
		return
	complaint_role = who
	complaint_t = 7.0
	feedback.emit(Locale.t("feedback.complaint_" + who), "hit")


var last_mistake_role := ""


func _role_for_reason(reason: String) -> String:
	if reason.begins_with("RABBIT") or reason == "OXYGEN_OUT":
		return "rabbit"
	if reason.begins_with("TURTLE"):
		return "turtle"
	return ""


## race 取走一次“单角色捣乱”，取走后不重复触发。
func take_role_mischief() -> String:
	if not role_mischief_pending:
		return ""
	role_mischief_pending = false
	var who := role_mischief_role
	role_mischief_role = ""
	return who


func oxygen_capacity() -> float:
	return maxf(Tuning.OXYGEN_MAX - 0.5 * float(waterlogged), 4.5)


func oxygen_drain_scale() -> float:
	return 1.0 + 0.12 * float(waterlogged)


func note_fall() -> void:
	waterlogged = mini(waterlogged + 1, 3)
	waterlogged_t = 0.0
	if waterlogged == 1:
		feedback.emit(Locale.t("feedback.waterlogged"), "hit")


func tick_waterlogged(delta: float) -> void:
	# 连续约 30 秒不落水，恢复一层；不靠隐藏数字制造无限负循环。
	waterlogged_t += delta
	if waterlogged > 0 and waterlogged_t >= 30.0:
		waterlogged -= 1
		waterlogged_t = 0.0


func note_accident(reason: String, role: String = "") -> void:
	if reason in ["RABBIT_SLIP", "RABBIT_WATER", "RABBIT_AIR", "OXYGEN_OUT"]:
		rabbit_casualties += 1
	elif reason == "TURTLE_REEF":
		turtle_failures += 1
	note_mistake(reason, role)


## CORE-FEEL-08 P0-B：事故分级。
## 轻 = 还在壳上、只是短硬直（0.8 s 自己站起来，不丢骑乘、不强制换人）；
## 重 = 离开壳 / 整组停摆，需要救援或等演出结束。
## 分级只影响“玩家读到的重量”（横幅颜色/停留时间），不改任何判定与计时。
const ACCIDENT_SEVERITY := {
	"RABBIT_HIT": "minor",
	"RABBIT_STUN": "minor",
	# 乌龟层失误（浪击/下潜太晚）不算 accident_state，但同样只记一格、可立刻继续操作。
	"TURTLE_WAVE": "minor",
	"TURTLE_DIVE_LATE": "minor",
	"RABBIT_SLIP": "severe",
	"RABBIT_WATER": "severe",
	"RABBIT_AIR": "severe",
	"TURTLE_REEF": "severe",
	"OXYGEN_OUT": "severe",
	"BRO_BREAK": "severe",
}


func accident_severity(reason: String) -> String:
	return String(ACCIDENT_SEVERITY.get(reason, "severe"))


## 联合惩罚演出结束时才清空：演出期间三格保持满，玩家看得到“这是第三格”。
func clear_bro_meter() -> void:
	bro_meter = 0
	bro_joint_pending = false
	role_mischief_pending = false
	role_mischief_role = ""
	complaint_role = ""
	complaint_t = 0.0
	waterlogged = 0
	waterlogged_t = 0.0
	bro_meter_role = {"rabbit": 0, "turtle": 0}
	complaint_role = ""
	complaint_t = 0.0
	mischief_lock_role = ""
	bro_meter_changed.emit(bro_meter)


## FEEL-15：MISCHIEF 结束时明确清零该角色的惩罚条（不是缓慢自然恢复）。
func reset_role_meter(who: String) -> void:
	if not bro_meter_role.has(who):
		return
	bro_meter_role[who] = 0
	if who == current_control:
		bro_meter = 0
		bro_meter_changed.emit(bro_meter)


func role_meter(who: String) -> int:
	return int(bro_meter_role.get(who, 0))


## FEEL-24：抱怨窗口。玩家切到该角色会制止；窗口过期自然消散。
func tick_complaint(delta: float) -> void:
	if complaint_t <= 0.0:
		return
	complaint_t = maxf(complaint_t - delta, 0.0)
	if complaint_t <= 0.0:
		complaint_role = ""


## FEEL-23：干净通过/有效操作给一次压力释放；这是玩家可理解的脱困途径。
## 正在捣乱的角色不能靠这一步洗掉事件，必须由 SHIFT/结束流程处理。
func relieve_pressure(who: String, amount: int = 1) -> void:
	if who not in ["rabbit", "turtle"] or mischief_lock_role == who:
		return
	var cur := int(bro_meter_role.get(who, 0))
	if cur <= 0:
		return
	cur = maxi(cur - amount, 0)
	bro_meter_role[who] = cur
	if who == current_control:
		bro_meter = cur
		bro_meter_changed.emit(bro_meter)
	if cur < BRO_METER_SLOTS and role_mischief_role == who:
		role_mischief_pending = false
		role_mischief_role = ""


# ---- 阶段 4：指令里的分数表（同一次动作只记一笔）。 ----

func add_score(points: int, reason: String) -> void:
	total_score = maxi(total_score + points, 0)
	score_log.append({"reason": reason, "points": points})
	if score_log.size() > 240:
		score_log.pop_front()


func note_clean_pass() -> void:
	clean_pass_count += 1
	add_score(100, "clean")
	perfect_cooperation += 1
	perfect_streak += 1
	best_streak = maxi(best_streak, perfect_streak)


## 精准动作（跳/趴/潜/跃）或两种连招。连招整段完成才调用，不给“半套”分。
func note_precise_pass(kind: String) -> void:
	clean_pass_count += 1
	perfect_cooperation += 1
	perfect_streak += 1
	best_streak = maxi(best_streak, perfect_streak)
	match kind:
		"FLOATING_LOG":
			combo_dive_count += 1
			add_score(250, "bro_dive")
		"HIGH_WALL":
			combo_ollie_count += 1
			add_score(300, "bro_ollie")
		_:
			add_score(150, "precise:" + kind)


func note_showtime() -> void:
	# Showtime 结束不清完美连胜；只有事故才清。
	pass


func finalize_run() -> void:
	if finished:
		return
	finished = true
	finish_time = race_time
	# STAGE 4 起分数按动作逐笔累计（见 add_score / note_precise_pass），
	# 冲线时不再按时间/连击重算，等待或拖延不会加一分。
	grade = grade_for_score(total_score, accident_count)
	grade_name = grade_title(grade)
	# P1-B：制作人测试入口不写正式纪录。场景本身也会 test_no_finish，
	# 这里再兜一层，防止手动改 world_end 或误触结算时污染 best.json。
	if not test_no_best:
		_update_best()
		_save_best()


## 兼容旧调用：分数已经是逐笔累计值。
func compute_score() -> int:
	return total_score


## 满编 55 组全精准 = 44×150 + 3×300 + 8×250 = 9500。
## PHASE-1：S 不再只看分数。0 事故 + 8000 才是 S；1–2 次最高 A；
## 3–5 次最高 B。accidents < 0 时保留旧调用（测试/探针只测分数曲线）。
func grade_for_score(score: int, accidents: int = -1) -> String:
	if accidents >= 0:
		if accidents == 0 and score >= 8000:
			return "S"
		if accidents <= 2 and score >= 6500:
			return "A"
		if accidents <= 5 and score >= 5000:
			return "B"
		if accidents <= 8 and score >= 3000:
			return "C"
		return "D"
	if score >= 8000:
		return "S"
	if score >= 6500:
		return "A"
	if score >= 5000:
		return "B"
	if score >= 3000:
		return "C"
	return "D"


func grade_title(g: String) -> String:
	# 显示文案统一走 Locale；这里只决定等级。
	return Locale.grade_title(g)


func _update_best() -> void:
	new_best_time = best_time < 0.0 or finish_time < best_time
	new_best_score = total_score > best_score
	new_best_streak = best_streak > best_streak_record
	if new_best_time:
		best_time = finish_time
	# GDD 12.4 的计分按全部事故计罚；最好纪录必须用同一口径，
	# 否则硬直（RABBIT_STUN）不进 best_accidents，结算里的“最佳事故数”会偏乐观。
	var accidents := accident_count
	if best_accidents < 0 or accidents < best_accidents:
		best_accidents = accidents
	if new_best_score:
		best_score = total_score
	if new_best_streak:
		best_streak_record = best_streak


func _load_best() -> void:
	if not FileAccess.file_exists(BEST_PATH):
		return
	var file := FileAccess.open(BEST_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	best_time = float(parsed.get("best_time", -1.0))
	best_accidents = int(parsed.get("best_accidents", -1))
	best_score = int(parsed.get("best_score", -1))
	best_streak_record = int(parsed.get("best_streak", 0))
	# 没写 model 的档就是旧计分；最高分作废，别的纪录保留。
	if int(parsed.get("score_model", 1)) != SCORE_MODEL:
		best_score = -1


func _save_best() -> void:
	var file := FileAccess.open(BEST_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"score_model": SCORE_MODEL,
		"best_time": best_time,
		"best_accidents": best_accidents,
		"best_score": best_score,
		"best_streak": best_streak_record,
	}))
	file.close()


func best_path_absolute() -> String:
	return ProjectSettings.globalize_path(BEST_PATH)
