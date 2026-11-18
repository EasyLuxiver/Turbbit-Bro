extends Control
## 阶段 4 重设计 HUD：紧凑、内容自适应，不再有四块大面积空面板。
## 左上：SHIFT 当前控制 + 两个角色各自的“操控 / 待命·稳定”，
##       只有真的失衡时才出现一条“兔子失衡 18% / 乌龟倾覆风险 40%”。
## 右上：时间（mm:ss.t）、区域、进度。没有速度行，也没有固定总分（§七-9）。
## 左下：氧气 + 状态 + 分格条。右下不再有 0/3 面板（FEEL-24）。
## 底部中央：首次遇到某类障碍时教一次；干净通过/BRO PASS 短反馈。
## 数据全部来自 race 与 GameManager，不自己存副本。

const Tuning = preload("res://scripts/systems/tuning.gd")
const LevelData = preload("res://scripts/systems/level_data.gd")
const RoleGlyphScript = preload("res://scripts/ui/role_glyph.gd")
const BroPortraitScript = preload("res://scripts/ui/bro_portrait.gd")

## REBUILD-05 C2：协作窗口。数值来自实测，不是拍的：
##   BRO DIVE 有效起跳距 = 80–300 px（`REBUILD05-B3.md`，178/180 通过）
##   BRO OLLIE 有效起跳距 = 150–260 px（`playful04-combo-windows.json`）
## 预警提前到 520 px：约 1.7–2.4 s，够看清再决定，不提前剧透更远的障碍。
const COOP_WARN_PX := 520.0
const DIVE_OPEN_PX := 300.0
const DIVE_CLOSE_PX := 80.0
const OLLIE_OPEN_PX := 260.0
const OLLIE_CLOSE_PX := 150.0

const PANEL_BG := Color(0.02, 0.07, 0.1, 0.6)
const PANEL_BORDER := Color(0.4, 0.8, 0.95, 0.28)
const TEXT := Color(0.92, 0.97, 1.0)
const MUTED := Color(0.78, 0.88, 0.95)
const GOLD := Color(1.0, 0.86, 0.35)
const GREEN := Color(0.45, 0.95, 0.6)
const AMBER := Color(1.0, 0.8, 0.3)
const RED := Color(1.0, 0.36, 0.3)
## 压在 60% 面板上的红字不能直接用 RED：亮天空透过面板后 RED 只有 ~3.6:1。
## 槽条/分格继续用饱和 RED，文字用这个浅一档的。实测见 PHASE-I-HUD-INTERACTION.md。
const RED_TEXT := Color(1.0, 0.80, 0.72)
const CYAN := Color(0.45, 0.95, 1.0)

var race: Node = null

var _panels := {}
var _bottom_center: VBoxContainer

var control_label: Label
var rabbit_role: Label
var rabbit_status: Label
var rabbit_sleep_bar: ProgressBar
var turtle_sleep_bar: ProgressBar
var rabbit_coop: Label
var turtle_role: Label
var turtle_status: Label
var turtle_coop: Label
## REFINE-06 P1：角色图形 + 当前控制箭头 + 神游进度条。
## 名称之外再给形状（耳朵/壳）和位置标记，不看字也能分出谁是谁、谁在受控。
var rabbit_glyph: Control
var rabbit_portrait: Control
var turtle_portrait: Control
var turtle_glyph: Control
var rabbit_arrow: Label
var turtle_arrow: Label
var rabbit_drift_row: HBoxContainer
var rabbit_drift_bar: ProgressBar
var rabbit_drift_effect: Label
var turtle_drift_row: HBoxContainer
var turtle_drift_bar: ProgressBar
var turtle_drift_effect: Label
var rabbit_risk_row: HBoxContainer
var rabbit_risk_label: Label
var rabbit_risk_bar: ProgressBar
var turtle_risk_row: HBoxContainer
var turtle_risk_label: Label
var turtle_risk_bar: ProgressBar
## C2：协作时机条。只在 520 px 预警范围内出现，错过就消失，不常驻。
var coop_bar: ProgressBar

var time_label: Label
var zone_label: Label
var progress_label: Label

## Phase O：食物加速状态。只在“加速中 / 前方有海藻”时出现，不做常驻空行。
var snack_label: Label
## CORE-FEEL-07 P1-C：食物接近时第二行，同时预告“兔子吃 / 乌龟吃”两种效果。
var snack_effect_label: Label

## FEEL-24：右下角 0/3 面板（BRO METER、默契/Showtime）已整体移除；
## FEEL-47 起三格 BRO METER 改由头顶短叹号 + 抱怨窗口表达。
## 旧标签不再声明，避免测试误以为 HUD 还有这一行。
var feedback_label: Label
## PHASE-FIX：兄弟对话（小头像 + 短句）。
var bro_row: HBoxContainer
var bro_portrait: Control
var bro_say_label: Label
var bro_say_t := 0.0
var hint_label: Label
var prompt_label: Label
## FEEL-09 P1-A：按键图标行。重要指令必须能“看见要按哪个键”，
## 不只读一行字。三个键帽是高亮提示，不是可点击按钮。
var key_row: HBoxContainer
var keycap_panels := {}
var keycap_labels := {}
## 只在亮/暗状态变化时重建 StyleBox；否则每帧 duplicate 会拖慢高 tick 测试。
var keycap_lit := {}

var hint_text := ""
var hint_timer := 0.0
var feedback_text := ""
var feedback_kind := "clean"
var feedback_timer := 0.0
var prompt_text := ""
var prompt_timer := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tl := _make_panel("tl")
	control_label = _label(tl, 18, GOLD)
	var rabbit_row := HBoxContainer.new()
	rabbit_row.add_theme_constant_override("separation", 8)
	tl.add_child(rabbit_row)
	rabbit_arrow = _label(rabbit_row, 18, GOLD)
	rabbit_arrow.text = ">"
	rabbit_arrow.visible = false
	rabbit_glyph = RoleGlyphScript.new()
	rabbit_glyph.role = "rabbit"
	rabbit_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rabbit_row.add_child(rabbit_glyph)
	rabbit_portrait = BroPortraitScript.new()
	rabbit_portrait.role = "rabbit"
	rabbit_row.add_child(rabbit_portrait)
	rabbit_role = _label(rabbit_row, 18, TEXT)
	rabbit_status = _label(rabbit_row, 18, GREEN)
	rabbit_sleep_bar = _sleep_bar(rabbit_row)
	var rdr := _drift_row(tl, CYAN)
	rabbit_drift_row = rdr[0]
	rabbit_drift_bar = rdr[1]
	rabbit_drift_effect = rdr[2]
	# 协作机会单独一行、小一号字：塞进角色行会把英文面板撑到 404 px。
	rabbit_coop = _label(tl, 16, GOLD)
	rabbit_coop.visible = false
	var turtle_row := HBoxContainer.new()
	turtle_row.add_theme_constant_override("separation", 8)
	tl.add_child(turtle_row)
	turtle_arrow = _label(turtle_row, 18, GOLD)
	turtle_arrow.text = ">"
	turtle_arrow.visible = false
	turtle_glyph = RoleGlyphScript.new()
	turtle_glyph.role = "turtle"
	turtle_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	turtle_row.add_child(turtle_glyph)
	turtle_portrait = BroPortraitScript.new()
	turtle_portrait.role = "turtle"
	turtle_row.add_child(turtle_portrait)
	turtle_role = _label(turtle_row, 18, TEXT)
	turtle_status = _label(turtle_row, 18, GREEN)
	turtle_sleep_bar = _sleep_bar(turtle_row)
	var tdr := _drift_row(tl, CYAN)
	turtle_drift_row = tdr[0]
	turtle_drift_bar = tdr[1]
	turtle_drift_effect = tdr[2]
	turtle_coop = _label(tl, 16, GOLD)
	turtle_coop.visible = false
	var rr := _risk_row(tl, CYAN)
	rabbit_risk_row = rr[0]
	rabbit_risk_label = rr[1]
	rabbit_risk_bar = rr[2]
	var trt := _risk_row(tl, AMBER)
	turtle_risk_row = trt[0]
	turtle_risk_label = trt[1]
	turtle_risk_bar = trt[2]
	# 协作时机条放在同一块状态区的最下面：不挡赛道，也不新增一块面板。
	coop_bar = ProgressBar.new()
	coop_bar.min_value = 0
	coop_bar.max_value = 100
	coop_bar.value = 0
	coop_bar.show_percentage = false
	coop_bar.custom_minimum_size = Vector2(120, 6)
	coop_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coop_bar.add_theme_stylebox_override("background",
		_bar_style(Color(0.12, 0.16, 0.2, 0.9)))
	coop_bar.add_theme_stylebox_override("fill", _bar_style(GOLD))
	coop_bar.visible = false
	tl.add_child(coop_bar)

	var tr := _make_panel("tr")
	time_label = _label(tr, 25, TEXT)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	zone_label = _label(tr, 18, MUTED)
	zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_label = _label(tr, 18, MUTED)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var bl := _make_panel("bl")
	# FEEL-12 E：氧气改画在 TUBO 头顶三颗气泡；左下只保留食物加速状态。
	snack_label = _label(bl, 18, CYAN)
	snack_effect_label = _label(bl, 15, MUTED)
	snack_effect_label.visible = false
	snack_label.visible = false

	# FEEL-24：右下角不再创建任何 0/3 面板。
	# 底部中央不挂面板：文字直接压在画面上，避免挡角色和障碍。
	_bottom_center = VBoxContainer.new()
	_bottom_center.alignment = BoxContainer.ALIGNMENT_END
	_bottom_center.add_theme_constant_override("separation", 4)
	add_child(_bottom_center)
	feedback_label = _label(_bottom_center, 26, GOLD)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bro_row = HBoxContainer.new()
	bro_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bro_row.add_theme_constant_override("separation", 8)
	_bottom_center.add_child(bro_row)
	bro_portrait = BroPortraitScript.new()
	bro_row.add_child(bro_portrait)
	bro_say_label = _label(bro_row, 20, TEXT)
	bro_row.visible = false
	# 按键图标行：SHIFT / ↑ / ↓。只在有指令提示时出现，按文案高亮。
	key_row = HBoxContainer.new()
	key_row.alignment = BoxContainer.ALIGNMENT_CENTER
	key_row.add_theme_constant_override("separation", 8)
	_bottom_center.add_child(key_row)
	keycaps_entry("shift", "SHIFT")
	keycaps_entry("up", "↑")
	keycaps_entry("down", "↓")
	# FEEL-19：SPACE 只在主动救援提示里出现，不常驻。
	keycaps_entry("pop", "SPACE")
	keycap_panels["pop"].visible = false
	key_row.visible = false
	hint_label = _label(_bottom_center, 18, MUTED)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label = _label(_bottom_center, 22, CYAN)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.visible = false
	hint_label.visible = false
	prompt_label.visible = false

	GameManager.hint.connect(_on_hint)
	GameManager.feedback.connect(_on_feedback)
	GameManager.prompt.connect(_on_prompt)
	GameManager.bro_say.connect(_on_bro_say)
	Locale.language_changed.connect(_on_language_changed)


func _process(delta: float) -> void:
	if hint_timer > 0.0:
		hint_timer = maxf(hint_timer - delta, 0.0)
	if feedback_timer > 0.0:
		feedback_timer = maxf(feedback_timer - delta, 0.0)
	if prompt_timer > 0.0:
		prompt_timer = maxf(prompt_timer - delta, 0.0)
	if bro_say_t > 0.0:
		bro_say_t = maxf(bro_say_t - delta, 0.0)
		if bro_say_t <= 0.0 and bro_row != null:
			bro_row.visible = false
	if race == null or not is_instance_valid(race):
		return
	if race.turtle == null or race.rabbit == null:
		return
	_refresh()
	_layout()


func _refresh() -> void:
	# ---- 左上：控制权 + 双方状态 ----
	var cur: String = GameManager.current_control
	control_label.text = Locale.t("hud.control_now", [Locale.t("who." + cur)])
	# PHASE-FIX：角色行改用小头像，不再显示名字文本。
	rabbit_role.text = ""
	turtle_role.text = ""
	var rabbit_risk: int = race.rabbit_imbalance_pct()
	var turtle_risk: int = race.turtle_imbalance_pct()
	var rabbit_drift := _drift_state("rabbit")
	var turtle_drift := _drift_state("turtle")
	# 第二标识：谁受控，谁前面有金色箭头、图形外面有金圈。文字之外还有位置和形状。
	rabbit_arrow.visible = cur == "rabbit"
	turtle_arrow.visible = cur == "turtle"
	rabbit_glyph.level = _drift_level(rabbit_drift)
	rabbit_glyph.controlled = cur == "rabbit"
	turtle_glyph.level = _drift_level(turtle_drift)
	turtle_glyph.controlled = cur == "turtle"
	_update_sleep_bar(rabbit_sleep_bar, "rabbit")
	_update_sleep_bar(turtle_sleep_bar, "turtle")
	if cur == "rabbit":
		rabbit_status.text = _acting_text(_rabbit_action())
		rabbit_status.add_theme_color_override("font_color", GOLD)
		turtle_status.text = _standby_text(turtle_risk, turtle_drift)
		turtle_status.add_theme_color_override("font_color",
			_standby_color(turtle_risk, turtle_drift))
	else:
		turtle_status.text = _acting_text(_turtle_action())
		turtle_status.add_theme_color_override("font_color", GOLD)
		rabbit_status.text = _standby_text(rabbit_risk, rabbit_drift)
		rabbit_status.add_theme_color_override("font_color",
			_standby_color(rabbit_risk, rabbit_drift))
	_update_drift_bar(rabbit_drift_row, rabbit_drift_bar, race.rabbit_brain,
		rabbit_drift, cur == "rabbit")
	rabbit_drift_effect.text = _drift_effect("rabbit", cur == "rabbit")
	rabbit_drift_effect.add_theme_color_override("font_color",
		_drift_color(rabbit_drift))
	_update_drift_bar(turtle_drift_row, turtle_drift_bar, race.turtle_brain,
		turtle_drift, cur == "turtle")
	turtle_drift_effect.text = _drift_effect("turtle", cur == "turtle")
	turtle_drift_effect.add_theme_color_override("font_color",
		_drift_color(turtle_drift))
	# 兔子在水里时，不管现在控的是谁，兔子那一行都必须是“落水 · 等接应”。
	# 显示“待命 · 稳定”会让玩家以为它还好好待在壳上。
	if GameManager.accident_state == "RABBIT_WATER":
		rabbit_status.text = Locale.state_name("WAITING_CATCH")
		rabbit_status.add_theme_color_override("font_color", RED_TEXT)

	# 失衡只在真的有风险时出现，百分比和条同时出现，不做两条永久空条。
	rabbit_risk_row.visible = rabbit_risk > 0
	rabbit_risk_label.text = Locale.t("hud.rabbit_risk", [rabbit_risk])
	rabbit_risk_label.add_theme_color_override("font_color", _risk_color(rabbit_risk))
	rabbit_risk_bar.value = rabbit_risk
	_set_bar_color(rabbit_risk_bar, _risk_color(rabbit_risk))
	turtle_risk_row.visible = turtle_risk > 0
	turtle_risk_label.text = Locale.t("hud.turtle_risk", [turtle_risk])
	turtle_risk_label.add_theme_color_override("font_color", _risk_color(turtle_risk))
	turtle_risk_bar.value = turtle_risk
	_set_bar_color(turtle_risk_bar, _risk_color(turtle_risk))
	_refresh_coop()

	# ---- 右上：时间 / 区域 / 进度 ----
	var t: float = GameManager.race_time
	time_label.text = "%02d:%04.1f" % [int(t / 60.0), fmod(t, 60.0)]
	zone_label.text = Locale.t("hud.zone",
		[race.zone_id(), Locale.zone_name(race.zone_id())])
	progress_label.text = Locale.t("hud.progress", [
		race.passed_count(), race.total_groups()])

	# ---- 左下：食物（氧气改为 TUBO 头顶气泡，不再显示数值） ----
	if race.snack_rabbit_boost_active():
		snack_label.visible = true
		snack_label.text = Locale.t("hud.rabbit_boost")
		snack_label.add_theme_color_override("font_color", GREEN)
		snack_effect_label.visible = false
	elif race.snack_boost_active():
		snack_label.visible = true
		snack_label.text = Locale.t("hud.turbo")
		snack_label.add_theme_color_override("font_color", GREEN)
		snack_effect_label.visible = false
	elif race.snack_ahead_distance() >= 0.0:
		var eater: String = race.snack_who_eats()
		snack_label.visible = true
		if eater == "":
			snack_label.text = Locale.t("hud.snack_cant")
		else:
			snack_label.text = Locale.t("hud.snack_ahead",
				[Locale.t("who." + eater)])
		snack_label.add_theme_color_override("font_color", CYAN)
		snack_effect_label.visible = true
		snack_effect_label.text = Locale.t("hud.snack_preview")
	else:
		snack_label.visible = false
		snack_effect_label.visible = false
	_panels["bl"].visible = snack_label.visible or snack_effect_label.visible

	# FEEL-24：右下角不再常驻任何 0/3 计数。
	# ---- 底部中央：反馈 / 一次性教学 / 提示 ----
	feedback_label.visible = feedback_timer > 0.0
	feedback_label.text = feedback_text
	feedback_label.add_theme_color_override("font_color", _feedback_color(feedback_kind))
	hint_label.visible = hint_timer > 0.0
	hint_label.text = hint_text
	prompt_label.visible = prompt_timer > 0.0
	prompt_label.text = prompt_text
	var a := 1.0
	if prompt_timer > 0.0 and prompt_timer < 0.6:
		a = prompt_timer / 0.6
	prompt_label.modulate.a = a
	# 按键图标：只高亮这条提示真正用到的键。
	key_row.visible = prompt_label.visible and prompt_text != ""
	if key_row.visible:
		key_row.modulate.a = a
		var on_shift := prompt_text.contains("SHIFT")
		var on_up := prompt_text.contains("↑")
		var on_down := prompt_text.contains("↓")
		_set_keycap("shift", on_shift)
		_set_keycap("up", on_up)
		_set_keycap("down", on_down)
		# FEEL-22：只显示这条提示真正要按的键。三个键帽常驻会把底栏撑成键盘，
		# 反而盖住角色和当前动作。
		keycap_panels["shift"].visible = on_shift
		keycap_panels["up"].visible = on_up
		keycap_panels["down"].visible = on_down
		var space_on: bool = prompt_text.contains("SPACE")
		_set_keycap("pop", space_on)
		keycap_panels["pop"].visible = space_on
	# FEEL-09 P0-C：换手冷却时把 SHIFT 键帽压暗，避免“按了没反应”。
	var shift_cap: PanelContainer = keycap_panels.get("shift")
	if shift_cap != null:
		shift_cap.modulate.a = 0.62 if GameManager.shift_lock_t > 0.0 else 1.0


func _rabbit_action() -> String:
	if race.showtime_active:
		return Locale.state_name("SHOWTIME")
	if GameManager.accident_state == "RABBIT_WATER":
		return Locale.state_name("WAITING_CATCH")
	if race.mount.state == "AIRBORNE":
		return Locale.state_name("AIRBORNE")
	if race.rabbit_stun > 0.0:
		return Locale.state_name("STUNNED")
	if race.turtle.leap_active:
		return Locale.state_name("LEAPING")
	if race.rabbit.daze_time > 0.01:
		return Locale.state_name("RECOVERING")
	return Locale.state_name(race.rabbit.state)


func _turtle_action() -> String:
	if race.turtle.accident:
		return Locale.state_name("UNCONSCIOUS")
	if race.mount.state == "RESCUE_ACTIVE" or race.mount.state == "RESCUE_AIR":
		return Locale.state_name("RESCUING")
	if race.turtle.leap_active:
		return Locale.state_name("LEAPING")
	if race.turtle.diving:
		return Locale.state_name("DIVING")
	# CORE-FEEL-07C：掀翻期间先报“翻肚皮”，和壳的画面一致；翻完还在水里才报没入。
	if race.turtle.flip_t > 0.0:
		return Locale.state_name("BELLY_UP")
	if race.turtle.dunk_timer > 0.0:
		return Locale.state_name("DUNKED")
	if race.turtle.daze_time > 0.01:
		return Locale.state_name("RECOVERING")
	if race.turtle.speed > race.turtle.base_speed + 10.0:
		return Locale.state_name("BOOSTING")
	return Locale.state_name("CRUISING")


## 待命方不再永远显示“稳定”：神游进入 DISTRACTED 之后直接报状态，
## 玩家不用盯着壳边才知道伙伴开始走神。CALM 仍显示原来的稳定文案。
func _drift_state(who: String) -> String:
	var brain = race.rabbit_brain if who == "rabbit" else race.turtle_brain
	if brain == null:
		return "CALM"
	return String(brain.state_name())


## 待命文案：物理失衡优先（百分比单独一行），其次是神游阶段。
## “具体后果”紧挨在神游条右边（_drift_effect），不再挤进状态行。
func _standby_text(risk: int, drift_state: String) -> String:
	if risk > 0:
		return Locale.t("hud.standby_risk")
	if drift_state != "CALM":
		return Locale.t("hud.drift_" + drift_state.to_lower())
	return Locale.t("hud.standby_stable")


## 操控中的状态只写动作名。“回神中”和具体代价放在神游条右边，
## 恢复过程靠条在缩、数字在变好看得见，面板也不会被中英双语挤到超宽。
func _acting_text(action: String) -> String:
	return Locale.t("hud.acting", [action])


## 神游的“具体后果”：数字直接读角色控制器此刻真正生效的值（空中修正倍率、
## 身体偏移、巡航倍率、壳晃幅度），不是另算一套说明文字。
func _drift_effect(who: String, controlled: bool) -> String:
	if who == "rabbit":
		var air := int(round(race.rabbit.drift_air_scale() * 100.0))
		if controlled:
			return Locale.t("hud.drift_recover_rabbit", [air])
		var off: float = race.rabbit.drift_offset_amp_px()
		return Locale.t("hud.drift_effect_rabbit" if off >= 4.0
			else "hud.drift_effect_rabbit_light", [air])
	var cruise := int(round(race.turtle.drift_speed_scale(controlled) * 100.0))
	if controlled:
		return Locale.t("hud.drift_recover_turtle", [cruise])
	var bob: float = race.turtle.drift_bob_amp_px(controlled)
	return Locale.t("hud.drift_effect_turtle" if bob >= 4.0
		else "hud.drift_effect_turtle_light", [cruise])


## 阶段越深颜色越重：CALM 绿、DISTRACTED 琥珀、RESTLESS 橙、MISCHIEF 红。
## MISCHIEF 的红字带轻微脉动，和“稳定”不可能看混。
func _standby_color(risk: int, drift_state: String) -> Color:
	var c := _drift_color(drift_state)
	if drift_state == "MISCHIEF":
		c.a = 0.72 + 0.28 * absf(sin(Time.get_ticks_msec() * 0.008))
	if risk > 0 and drift_state == "CALM":
		return AMBER
	return c


func _drift_level(state: String) -> int:
	match state:
		"DISTRACTED":
			return 1
		"RESTLESS":
			return 2
		"MISCHIEF":
			return 3
	return 0


func _drift_color(state: String) -> Color:
	match state:
		"DISTRACTED":
			return AMBER
		"RESTLESS":
			return Color(1.0, 0.62, 0.25)
		"MISCHIEF":
			return RED_TEXT
	return GREEN


## 神游条只在真的有积累/恢复时出现；比例是“离失控还有多远”，不是倒计时秒数。
func _update_drift_bar(row: HBoxContainer, bar: ProgressBar, brain,
		state: String, controlled: bool) -> void:
	var drift := 0.0 if brain == null else float(brain.drift)
	row.visible = drift > 0.05
	if not row.visible:
		return
	bar.value = clampf(drift / Tuning.DRIFT_CAP * 100.0, 0.0, 100.0)
	var color := _drift_color(state)
	if state == "MISCHIEF" and not controlled:
		color.a = 0.70 + 0.30 * absf(sin(Time.get_ticks_msec() * 0.008))
	_set_bar_color(bar, color)


## C2：只报“前方最近的一组浮木/高墙”，且只在 520 px 内。
## 兔子起跳之后（AIRBORNE）窗口问题已经回答完了，保持“现在”直到通过，
## 不能因为距离继续缩小就翻成“已错过”——那会让玩家在连招中间收到相互矛盾的提示。
func _coop_target() -> Dictionary:
	if race == null or race.hazard_groups == null:
		return {}
	if bool(race.get("test_no_coop_hint")):
		return {}
	if GameManager.accident_state != "NONE":
		return {}
	var ms := String(race.mount.state)
	if ms in ["RESCUE_FALLING", "RESCUE_ACTIVE", "RESCUE_AIR", "RESCUING", "CARRYING"]:
		return {}
	var best: Dictionary = {}
	var best_d := 1.0e9
	for g in race.hazard_groups:
		var kind := String(g["kind"])
		if kind != "FLOATING_LOG" and kind != "HIGH_WALL":
			continue
		var key := String(g["group"])
		if bool(race.passed_groups.get(key, false)) \
				or bool(race.hit_groups.get(key, false)):
			continue
		var d: float = LevelData.group_start(g) - race.turtle.position.x
		# 障碍已经在身后（还没被记账）时不再提示；-30 留给“已错过”的最后一眼。
		if d < -30.0 or d > COOP_WARN_PX:
			continue
		if d < best_d:
			best_d = d
			best = g
	if best.is_empty():
		return {}
	var kind2 := String(best["kind"])
	var dive := kind2 == "FLOATING_LOG"
	var open_px: float = DIVE_OPEN_PX if dive else OLLIE_OPEN_PX
	var close_px: float = DIVE_CLOSE_PX if dive else OLLIE_CLOSE_PX
	var phase := "prepare"
	# AIRBORNE 已经是“起跳完成”的状态，窗口问题答完了；但只有兔子确实在为这组
	# 障碍起跳时才锁“现在”，否则远处随便跳一下也会把这组浮木点亮。
	if (ms == "AIRBORNE" and best_d <= open_px + 40.0) \
			or (best_d <= open_px and best_d >= close_px):
		phase = "now"
	elif best_d < close_px:
		phase = "missed"
	var span := COOP_WARN_PX - close_px
	var pct := clampf((COOP_WARN_PX - best_d) / span * 100.0, 0.0, 100.0)
	return {
		"group": String(best["group"]),
		"kind": kind2,
		"combo": Locale.t("combo.bro_dive" if dive else "combo.bro_ollie"),
		"actor": "rabbit" if dive else "turtle",
		"dist": best_d,
		"phase": phase,
		"pct": pct,
	}


func _refresh_coop() -> void:
	# REBUILD-05 G2：浮木下潜的第二拍。越过右缘后协作条已经收尾（组已过），
	# 所以这条提示单独占乌龟行，不重开时机条；松手（不再主动下潜）就消失。
	if race != null and race.has_method("dive_release_ready") \
			and race.dive_release_ready():
		coop_bar.visible = false
		rabbit_coop.visible = false
		turtle_coop.visible = true
		turtle_coop.text = "   " + Locale.t("hud.coop_release")
		turtle_coop.add_theme_color_override("font_color", GOLD)
		return
	var t := _coop_target()
	if t.is_empty():
		coop_bar.visible = false
		rabbit_coop.visible = false
		turtle_coop.visible = false
		return
	var combo: String = String(t["combo"])
	var phase: String = String(t["phase"])
	var now := phase == "now"
	# “准备”用灰蓝，有效窗口用金色，错过用浅红——三档一眼能分。
	var color := MUTED
	if now:
		color = GOLD
	elif phase == "missed":
		color = RED_TEXT
	coop_bar.visible = true
	coop_bar.value = float(t["pct"])
	_set_bar_color(coop_bar, color)
	# 机会写在角色自己那一行下面：位置说明是谁，文字只说明时机。
	# 另一方在有效窗口里标一句“配合”，不抢金色。
	var actor: String = String(t["actor"])
	var phase_text := "   " + Locale.t("hud.coop_" + phase, [combo])
	rabbit_coop.visible = actor == "rabbit" or now
	turtle_coop.visible = actor == "turtle" or now
	rabbit_coop.text = phase_text if actor == "rabbit" \
		else "   " + Locale.t("hud.coop_assist")
	turtle_coop.text = phase_text if actor == "turtle" \
		else "   " + Locale.t("hud.coop_assist")
	rabbit_coop.add_theme_color_override("font_color",
		color if actor == "rabbit" else MUTED)
	turtle_coop.add_theme_color_override("font_color",
		color if actor == "turtle" else MUTED)


func _risk_color(pct: int) -> Color:
	if pct >= 80:
		return RED_TEXT
	if pct >= 50:
		return Color(1.0, 0.80, 0.55)
	if pct >= 25:
		return AMBER
	return Color(0.66, 0.86, 1.0)


func _feedback_color(kind: String) -> Color:
	match kind:
		"bro", "pop":
			return GOLD
		"hit":
			return RED_TEXT
		_:
			return CYAN


func _layout() -> void:
	var vp := get_viewport_rect().size
	for corner in _panels:
		var panel: PanelContainer = _panels[corner]
		if not panel.visible:
			continue
		var ms := panel.get_combined_minimum_size()
		panel.size = ms
		match corner:
			"tl":
				panel.position = Vector2(14, 14)
			"tr":
				panel.position = Vector2(vp.x - 14.0 - ms.x, 14)
			"bl":
				panel.position = Vector2(14, vp.y - 14.0 - ms.y)
			"br":
				panel.position = Vector2(vp.x - 14.0 - ms.x, vp.y - 14.0 - ms.y)
	var bc_size := _bottom_center.get_combined_minimum_size()
	_bottom_center.size = bc_size
	_bottom_center.position = Vector2((vp.x - bc_size.x) * 0.5,
		vp.y - 16.0 - bc_size.y)


func _on_bro_say(who: String, text: String) -> void:
	if bro_row == null:
		return
	bro_portrait.role = who
	bro_say_label.text = text
	bro_row.visible = true
	bro_say_t = 2.2


func _on_hint(text: String) -> void:
	hint_text = text
	hint_timer = 2.2


func _on_feedback(text: String, kind: String) -> void:
	feedback_text = text
	feedback_kind = kind
	# Showtime 奖励一行信息量大，0.75 s 读不完；给它 1.8 s。
	feedback_timer = 1.8 if text.contains("SHOWTIME") or text.contains("表演") \
		or text.contains("配合上了") or text.contains("CLICKED") else 0.75


func _on_prompt(text: String) -> void:
	prompt_text = _at_most_two_lines(text)
	# FEEL-09 P1-A：SHIFT / 连招提示在 1100 px 外就触发，3 s 会在障碍前
	# 2 s 就消失。给需要跨到障碍前的提示 5 s，单动作提示仍 3 s。
	var hold := 3.0
	if text.contains("SHIFT") or text.contains("浮木") or text.contains("高墙") \
			or text.contains("吊网") or text.contains("鳗鱼") \
			or text.contains("船闸") or text.contains("CARGO NET") \
			or text.contains("EEL") or text.contains("SLUICE"):
		hold = 5.0
	prompt_timer = hold


## FEEL-09 P1-A：一次提示最多两行。过长的单行在中间断开，
## 不在 26 个字里塞完整段说明。
func _at_most_two_lines(text: String) -> String:
	if text.contains("\n") or text.length() <= 40:
		return text
	var mid := text.length() / 2
	# 只在语义分隔处断行，绝不把 “SHIFT” 这类按键词劈开。
	for sep in [" → ", "，", "；", " - ", " "]:
		var cut := text.find(sep, maxi(mid - 10, 0))
		if cut >= 0 and cut <= mid + 14:
			var after: int = cut + String(sep).length()
			return text.substr(0, after).strip_edges() + "\n" \
				+ text.substr(after).strip_edges()
	return text


func keycaps_entry(id: String, text: String) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.1, 0.13, 0.9)
	style.border_color = Color(0.3, 0.42, 0.5, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", 15)
	lab.add_theme_color_override("font_color", Color(0.62, 0.78, 0.88))
	panel.add_child(lab)
	key_row.add_child(panel)
	keycap_panels[id] = panel
	keycap_labels[id] = lab


func _set_keycap(id: String, lit: bool) -> void:
	if bool(keycap_lit.get(id, false)) == lit:
		return
	keycap_lit[id] = lit
	var panel: PanelContainer = keycap_panels.get(id)
	var lab: Label = keycap_labels.get(id)
	if panel == null or lab == null:
		return
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate()
	style.bg_color = Color(0.35, 0.27, 0.08, 0.95) if lit else Color(0.06, 0.1, 0.13, 0.9)
	style.border_color = GOLD if lit else Color(0.3, 0.42, 0.5, 0.9)
	panel.add_theme_stylebox_override("panel", style)
	lab.add_theme_color_override("font_color", GOLD if lit else Color(0.62, 0.78, 0.88))


func _on_language_changed(_code: String) -> void:
	# 旧语言的文字不能残留到新语言里。
	hint_timer = 0.0
	feedback_timer = 0.0
	prompt_timer = 0.0
	hint_text = ""
	feedback_text = ""
	prompt_text = ""


func _make_panel(corner: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	_panels[corner] = panel
	return box


## 神游进度：100×4 的细条 + 18 px 的后果文字（满值状态下面板仍 <= 8% 面积）。
## 不做“还剩几秒”的数字，避免变成倒计时压力；条 + 数字放在同一行，
## 玩家一眼就能把“程度”和“具体代价”对上。
func _drift_row(parent: VBoxContainer, fill: Color) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(100, 4)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", _bar_style(Color(0.12, 0.16, 0.2, 0.9)))
	bar.add_theme_stylebox_override("fill", _bar_style(fill))
	row.add_child(bar)
	var effect := _label(row, 18, fill)
	row.visible = false
	return [row, bar, effect]


## 返回 [行, 标签, 条]；GDScript 不能通过参数把新建节点传回调用方。
func _risk_row(parent: VBoxContainer, fill: Color) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := _label(row, 18, fill)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(96, 8)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", _bar_style(Color(0.12, 0.16, 0.2, 0.9)))
	bar.add_theme_stylebox_override("fill", _bar_style(fill))
	row.add_child(bar)
	row.visible = false
	return [row, label, bar]


func _bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	return style


func _set_bar_color(bar: ProgressBar, color: Color) -> void:
	bar.add_theme_stylebox_override("fill", _bar_style(color))


func _update_sleep_bar(bar: ProgressBar, who: String) -> void:
	if bar == null or race == null or not race.has_method("sleep_value"):
		return
	var v: float = race.sleep_value(who)
	bar.value = v
	bar.visible = v > 0.5
	var col: Color = CYAN
	var stage: int = race.sleep_stage(who)
	if stage >= 2:
		col = RED
	elif stage == 1:
		col = AMBER
	# 只在阶段变化时重建 StyleBox，避免每帧分配拖慢高 tick 探针。
	if int(bar.get_meta("sleep_stage", -1)) != stage:
		bar.set_meta("sleep_stage", stage)
		bar.add_theme_stylebox_override("fill", _bar_style(col))
	# 走神期间条轻微脉动：不改数值，只提醒“压力还在”。
	if stage >= 1:
		var pulse := 0.72 + 0.28 * absf(sin(Time.get_ticks_msec() * 0.005))
		bar.modulate = Color(1, 1, 1, pulse)
	else:
		bar.modulate = Color.WHITE


func _sleep_bar(parent: Container) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(42, 4)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background",
		_bar_style(Color(0.12, 0.16, 0.2, 0.9)))
	bar.add_theme_stylebox_override("fill", _bar_style(CYAN))
	bar.visible = false
	parent.add_child(bar)
	return bar


func _label(parent: Container, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label
