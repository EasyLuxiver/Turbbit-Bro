extends Node
## 统一文本管理：简体中文 / English。
## 首次启动默认中文，玩家选择写入 user://settings.json 并立即生效。
## 所有玩家可见文本一律走这里的稳定 ID，不在场景里散落硬编码字符串。

signal language_changed(language: String)

const SETTINGS_PATH := "user://settings.json"
const LANGUAGES := ["zh", "en"]
const DEFAULT_LANGUAGE := "zh"

var language: String = DEFAULT_LANGUAGE
var fullscreen := false
var _web_theme: Theme = null


func _ready() -> void:
	_load()
	_apply_display()
	# Web 导出没有系统字体回退，默认字体不含中日韩字形。
	# 用打包的 Noto Sans SC 子集当默认字体；CanvasLayer 会截断主题继承，
	# 所以额外给挂在 CanvasLayer 下的根 Control 直接装主题。
	if OS.has_feature("web"):
		var font := load("res://assets/fonts/NotoSansSC-Turbbit.otf") as Font
		if font != null:
			ThemeDB.fallback_font = font
			_web_theme = Theme.new()
			_web_theme.default_font = font
			get_tree().root.theme = _web_theme
			get_tree().node_added.connect(_web_node_added)


func _web_node_added(node: Node) -> void:
	if _web_theme == null or not (node is Control):
		return
	if node.get_parent() is CanvasLayer:
		(node as Control).theme = _web_theme


func set_language(code: String) -> void:
	if code not in LANGUAGES:
		return
	language = code
	_save()
	language_changed.emit(language)


func toggle_language() -> void:
	set_language("en" if language == "zh" else "zh")


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_save()
	_apply_display()


func toggle_fullscreen() -> void:
	set_fullscreen(not fullscreen)


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_WINDOWED
	if fullscreen:
		mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(mode)


func t(id: String, args: Array = []) -> String:
	var entry = STRINGS.get(id)
	if entry == null:
		return id
	var text: String = entry.get(language, entry.get("en", id))
	if not args.is_empty():
		text = text.format(args)
	return text


func state_name(state: String) -> String:
	var id := "state." + state
	return t(id) if STRINGS.has(id) else state


func accident_name(reason: String) -> String:
	var id := "accident." + reason
	return t(id) if STRINGS.has(id) else reason


func grade_title(grade: String) -> String:
	var id := "grade." + grade
	return t(id) if STRINGS.has(id) else t("grade.D")


func zone_name(id: int) -> String:
	return t("zone.%d.name" % id)


func zone_lesson(id: int) -> String:
	return t("zone.%d.lesson" % id)


## 关卡数据里保存的是英文文本；这里用显式 ID 映射到当前语言。
## 映射放在一处，UI 层不出现散落的英文常量。
func hazard(text: String) -> String:
	var id: String = HAZARD_IDS.get(text, "")
	return t(id) if id != "" else text


# ---- 持久化 ----

func _load() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		language = DEFAULT_LANGUAGE
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	# 用 JSON.new().parse() 而不是 JSON.parse_string()：设置文件被写坏时
	# parse_string 会往控制台打一条引擎 ERROR，玩家侧看起来像崩溃；
	# 这里静默退回默认语言即可。
	var json := JSON.new()
	var text := file.get_as_text()
	file.close()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return
	var parsed: Dictionary = json.data
	var code: String = str(parsed.get("language", DEFAULT_LANGUAGE))
	if code in LANGUAGES:
		language = code
	fullscreen = bool(parsed.get("fullscreen", false))


func _save() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"language": language, "fullscreen": fullscreen}))
	file.close()


func settings_path_absolute() -> String:
	return ProjectSettings.globalize_path(SETTINGS_PATH)


# ---- 文本表 ----

const HAZARD_IDS := {
	"LOW ROCK": "hazard.low_rock",
	"LOW BEAM": "hazard.low_beam",
	"LOW BIRD": "hazard.low_bird",
	"DOCK BEAM": "hazard.dock_beam",
	"SHARK": "hazard.shark",
	"REEF ARCH": "hazard.dive_gate",
	"FLOATING LOG": "hazard.floating_log",
	"TURTLE LEAP": "action.leap",
	"TURTLE DIVE": "action.dive",
	"JUMP + DIVE": "action.jump_and_dive",
	"REEF": "hazard.reef",
	"REEF CHAIN": "hazard.reef_chain",
	"LONG WALL": "hazard.long_wall",
	"SINK GATE": "hazard.sink_gate",
	"FINAL GATE": "hazard.final_gate",
	"LOW BAR": "hazard.low_bar",
	"ROCK + BEAM": "hazard.rock_beam",
	"JUMP OVER": "action.jump_or_dive",
	"CROUCH DOWN": "action.crouch_or_dive",
	"STAY HIGH": "action.stay_high",
	"HAND OVER TO SINK": "action.dive_through",
	"TAKE THE RABBIT": "action.take_rabbit",
	"DON'T JUMP": "action.dont_jump",
	"JUMP THEN CROUCH": "action.jump_then_crouch",
	"CROUCH AFTER LANDING": "action.crouch_after_landing",
	"JUMP THE ROCK - THE RABBIT JUMPS": "lesson.rock",
	"CROUCH UNDER THE BEAM - THE RABBIT DUCKS": "lesson.beam",
	"REEFS SIT DEEP - STAY ON THE SURFACE": "lesson.reef",
	"LONG WALL - HAND OVER AND THE SHELL SINKS": "lesson.wall",
	"SINK GATE - THE SHELL SINKS WHILE THE RABBIT IS IN CHARGE": "lesson.sink_gate",
	"LOW BAR - KEEP THE RABBIT ON THE SHELL": "lesson.airbar",
	"THREE CLEAN PASSES TRIGGER SHOWTIME": "lesson.combo",
}

const STRINGS := {
	# ---- 主菜单 ----
	"menu.title": {"zh": "TURBBIT BRO!", "en": "TURBBIT BRO!"},
	"menu.subtitle": {
		"zh": "兄弟俩，准备好接受训练了吗？",
		"en": "BROS. READY FOR TRAINING?"},
	"menu.best": {
		"zh": "最佳 {0} 秒   连击 {1}",
		"en": "BEST {0} s   STREAK {1}"},
	"menu.no_record": {"zh": "还没有纪录", "en": "NO RECORD YET"},
	# ---- 开场占位（Phase V P2-7）----
	"opening.subtitle": {
		"zh": "大表哥的水上训练挑战",
		"en": "COUSIN'S WATER TRAINING CHALLENGE"},
	"opening.ready": {"zh": "准备好，兄弟？", "en": "READY, BRO?"},
	"opening.hint": {
		"zh": "↑ 跳跃    ↓ 趴低",
		"en": "↑ JUMP    ↓ CROUCH"},
	# CORE-FEEL-07 P1-C：第一次讲食物放在开场画面（没有任何障碍，不是高压链中间）。
	# 已经跳过开场的人，在食物接近时还会看到 HUD 的持续预告。
	"opening.food": {
		"zh": "海藻别浪费：乌龟 吃＝加速，兔子 吃＝下一跳更高。不吃也行。",
		"en": "SEAWEED IS FREE POWER: BITT EATS = SPEED, TUBO EATS = HIGHER JUMP. SKIP IT IF YOU LIKE."},
	"opening.skip": {"zh": "任意键跳过", "en": "PRESS ANY KEY TO SKIP"},
	"menu.start": {"zh": "回车  -  开始比赛", "en": "ENTER  -  START RACE"},
	"menu.settings": {"zh": "S  -  设置", "en": "S  -  SETTINGS"},
	"menu.quit": {"zh": "Q / ESC  -  退出游戏", "en": "Q / ESC  -  QUIT"},
	"menu.language": {"zh": "语言：简体中文", "en": "LANGUAGE: ENGLISH"},
	# 2026-11-11 补充指令：主菜单必须是可点的按钮，不再只靠快捷键。
	"menu.start_game": {"zh": "开始游戏", "en": "START GAME"},
	"menu.producer": {"zh": "制作人测试", "en": "PRODUCER TESTS"},
	"menu.settings_button": {"zh": "设置", "en": "SETTINGS"},
	"menu.test_arena": {"zh": "动态障碍测试场", "en": "TEST ARENA"},
	"arena.title": {"zh": "动态障碍测试场", "en": "TEST ARENA"},
	"arena.type": {"zh": "障碍类型", "en": "OBSTACLE"},
	"arena.spawn": {"zh": "生成", "en": "SPAWN"},
	"arena.clear": {"zh": "清除", "en": "CLEAR"},
	"arena.restart": {"zh": "重新开始", "en": "RESTART"},
	"arena.stands": {"zh": "看台行为", "en": "STANDS"},
	"arena.intervene": {"zh": "赛道介入", "en": "INTERVENE"},
	"arena.menu": {"zh": "返回主菜单", "en": "MAIN MENU"},
	"arena.hint": {"zh": "鼠标点击面板；障碍生成在龟兔前方 700 px。", "en": "MOUSE ONLY. SPAWNS 700 PX AHEAD."},
	"menu.quit_button": {"zh": "退出游戏", "en": "QUIT"},
	"menu.keys": {
		"zh": "↑↓ 选择   Enter 确认",
		"en": "↑↓ SELECT   ENTER CONFIRM"},
	# FEEL-11：开场连环画 / 教学。
	"comic.skip": {"zh": "任意键跳过", "en": "PRESS ANY KEY TO SKIP"},
	"comic.skip_next": {
		"zh": "任意键下一格   ·   ESC 跳过",
		"en": "ANY KEY NEXT   ·   ESC SKIP"},
	"comic.1.narr": {"zh": "上一次比赛，兄弟俩本来有机会赢。", "en": "LAST RACE, THE BROS COULD HAVE WON."},
	"comic.1.rabbit": {"zh": "我就闭眼休息一下……", "en": "JUST GONNA REST MY EYES..."},
	"comic.2.turtle": {"zh": "你倒是醒醒啊！", "en": "WAKE UP, MAN!"},
	"comic.3.narr": {"zh": "大表哥决定亲自训练他们。", "en": "COUSIN DECIDED TO TRAIN THEM HIMSELF."},
	"comic.3.cousin": {"zh": "你们缺的不是速度，是默契！", "en": "YOU DON'T LACK SPEED. YOU LACK SYNC!"},
	"comic.4.cousin": {"zh": "特制能量蛋糕！嘿嘿！", "en": "SPECIAL ENERGY CAKE! HEH HEH!"},
	"comic.5.bros": {"zh": "哇啊啊啊——！", "en": "WHOA AAAA—!"},
	"comic.6.narr": {"zh": "从那天起，他们偶尔会……换着来？", "en": "SINCE THEN, THEY SOMETIMES... SWAP?"},
	"comic.6.rabbit": {"zh": "等等，刚刚是我在动吗？", "en": "WAIT. WAS THAT ME MOVING?"},
	"comic.7.cousin": {"zh": "很好！现在，给我跑出兄弟默契！", "en": "GOOD! NOW SHOW ME THAT BRO SYNC!"},
	"comic.7.narr": {"zh": "一场混乱又刺激的训练，正式开始。", "en": "A CHAOTIC, WILD TRAINING STARTS NOW."},
	"tutorial.title": {"zh": "大表哥的训练", "en": "COUSIN'S TRAINING"},
	"tutorial.step1": {"zh": "兔子！看前面！", "en": "TUBO! STOP DAYDREAMING. WATCH AHEAD!"},
	"tutorial.step1_hint": {"zh": "兔子：↑ 跳 / ↓ 趴低", "en": "TUBO: ↑ JUMP / ↓ CROUCH"},
	"tutorial.step1_hint_on_turtle": {"zh": "SHIFT 回 兔子：↑ 跳 / ↓ 趴低", "en": "SHIFT TO TUBO: ↑ JUMP / ↓ CROUCH"},
	"tutorial.step2": {"zh": "乌龟！水里看你的！", "en": "BITT! STEADY. THE WATER IS YOUR HOME!"},
	"tutorial.step2_hint": {"zh": "换乌龟：↑ 跃 / ↓ 潜", "en": "BITT: ↑ LEAP / ↓ DIVE"},
	"tutorial.step2_hint_on_rabbit": {"zh": "先 SHIFT 乌龟：↑ 跃 / ↓ 潜", "en": "SHIFT TO BITT: ↑ LEAP / ↓ DIVE"},
	"tutorial.step3": {"zh": "漂亮！别让另一个闲着！", "en": "NICE! DON'T LEAVE THE OTHER ONE IDLE!"},
	"tutorial.step3_hint": {"zh": "↑ 跳 → SHIFT → ↓ 潜", "en": "↑ JUMP → SHIFT → ↓ DIVE"},
	"tutorial.step3_hint_on_turtle": {"zh": "SHIFT 回兔子：跳→换→潜", "en": "SHIFT TO TUBO: JUMP → SWAP → DIVE"},
	"tutorial.step4": {"zh": "这次你们自己来！", "en": "THIS ONE IS ALL YOURS!"},
	"tutorial.step4_hint": {"zh": "用你刚学会的交接，自己过", "en": "USE THE RELAY YOU JUST LEARNED"},
	"tutorial.done": {"zh": "接下来，看你们的了。", "en": "NEXT UP: SHOW ME WHAT YOU'VE GOT."},
	"tutorial.skip": {"zh": "K 跳过教学", "en": "K SKIP TUTORIAL"},
	"tutorial.fail": {"zh": "别急，看看下一步该谁动。", "en": "EASY. CHECK WHO MOVES NEXT."},
	"quit.title": {"zh": "要退出游戏吗？", "en": "QUIT GAME?"},
	"quit.body": {
		"zh": "还没冲线，退出后本局进度不会保留。",
		"en": "The run is not finished. Progress will be lost."},
	"quit.yes": {"zh": "退出", "en": "QUIT"},
	"quit.no": {"zh": "取消", "en": "CANCEL"},
	# 只留开局必须知道的按键。F3 是调试层，不占玩家文本。
	"menu.hint": {
		"zh": "SHIFT 换人    ↑ 兔子跳 / 乌龟跃起    ↓ 兔子趴低 / 乌龟下潜",
		"en": "SHIFT transfer   ↑ TUBO JUMP / BITT LEAP   ↓ TUBO CROUCH / BITT DIVE"},

	# ---- 设置 ----
	"settings.title": {"zh": "设置", "en": "SETTINGS"},
	"settings.language": {
		"zh": "语言    L - 切换（当前：简体中文）",
		"en": "LANGUAGE    L - SWITCH (CURRENT: ENGLISH)"},
	"settings.back": {"zh": "ESC / S  -  返回", "en": "ESC / S  -  BACK"},
	"settings.back_button": {"zh": "返回", "en": "BACK"},
	"settings.fullscreen_on": {"zh": "全屏：开", "en": "FULLSCREEN: ON"},
	"settings.fullscreen_off": {"zh": "全屏：关", "en": "FULLSCREEN: OFF"},
	"settings.keys": {
		"zh": "↑↓ 选择   Enter 确认   L 切换语言",
		"en": "↑↓ SELECT   ENTER CONFIRM   L SWITCH LANGUAGE"},
	"settings.note": {
		"zh": "语言只换文字，不改玩法，也不影响比赛纪录。",
		"en": "Language only changes text. It does not affect gameplay or records."},
	"settings.web_note": {
		"zh": "网页版：英文界面（未打包中文字体）。",
		"en": "WEB BUILD: ENGLISH UI ONLY (NO CJK FONT BUNDLED)."},
	"settings.keys_web": {
		"zh": "↑↓ 选择   Enter 确认",
		"en": "↑↓ SELECT   ENTER CONFIRM"},

	# ---- HUD ----
	"hud.control": {"zh": "控制    {0}", "en": "CONTROL   {0}"},
	"who.rabbit": {"zh": "兔子", "en": "TUBO"},
	"who.turtle": {"zh": "乌龟", "en": "BITT"},
	"hud.speed": {"zh": "速度    {0}", "en": "SPEED   {0}"},
	"hud.cruise": {"zh": "巡航", "en": "CRUISE"},
	"hud.boost": {"zh": "加速", "en": "BOOST"},
	"hud.turbo": {"zh": "乌龟 加速中！", "en": "BITT TURBO!"},
	"hud.rabbit_boost": {
		"zh": "兔子！下一跳更高",
		"en": "TUBO! HIGHER JUMP"},
	# CORE-FEEL-07 P1-C：接近食物时 HUD 同时预告两种效果，并明确“现在谁吃”。
	# {0} 是当前操控者的角色名（兔子 / 乌龟）。
	"hud.snack_ahead": {
		"zh": "海藻在前 · 现在 {0} 吃",
		"en": "SNACK AHEAD · {0} EATS NOW"},
	"hud.snack_cant": {
		"zh": "海藻在前 · 现在够不到（回水面 / 落地再吃）",
		"en": "SNACK AHEAD · OUT OF REACH (SURFACE OR LAND)"},
	"hud.snack_preview": {
		"zh": "海藻：兔子 ↑ 跳更高 / 乌龟 » 加速",
		"en": "SNACK: TUBO ↑ HIGHER / BITT » SPEED"},
	"hud.zone": {"zh": "区域 {0}/3  {1}", "en": "ZONE {0}/3  {1}"},
	"hud.progress": {
		"zh": "赛程 {0}/{1}",
		"en": "RACE {0}/{1}"},
	"hud.surface": {"zh": "浮上来了，正在回气", "en": "SURFACE - RECOVERING"},
	"hud.emergency": {"zh": "紧急上浮", "en": "EMERGENCY ASCENT"},
	"hud.airborne": {"zh": "空中——氧气不掉", "en": "AIRBORNE - NO DRAIN"},
	"hud.rescuing": {"zh": "救援中 {0}s - 潜到兔子下面", "en": "RESCUE {0}s - DIVE UNDER THE TUBO"},
	"hud.rescuing_air": {"zh": "救援中 {0}s - 跃起接住", "en": "RESCUE {0}s - LEAP TO CATCH"},
	"hud.rescue_return": {"zh": "兔子回壳中 {0}s", "en": "TUBO RETURNING {0}s"},
	"hud.underwater": {"zh": "水下——氧气在掉", "en": "UNDERWATER - DRAINING"},
	"hud.undertow": {"zh": "暗流 - 壳沉太深，换给乌龟抬起来", "en": "UNDERTOW - TOO DEEP, GIVE IT TO THE BITT"},
	# 中断方式由表演横幅说明，这里只留剩余时间。
	"hud.showtime": {"zh": "配合 {0}s", "en": "SHOWTIME {0}s"},
	"hud.showtime_ready": {"zh": "兄弟俩对上眼了", "en": "BROS LOCKED IN"},
	"hud.showtime_banner": {
		"zh": "乌龟 在演，SHIFT 换人",
		"en": "BITT IS UP - SHIFT TO SWAP"},
	# 阶段 4 紧凑 HUD：控制权 + 各自状态 + 只在硬直/滑移时出现的晃动条。
	# Phase G：daze 已封顶且不再判事故，所以这里量的是“现在晃得多厉害”，
	# 不是“离掉下去还有多远”——旧文案“倾覆风险”会承诺一个不存在的结果。
	"hud.control_now": {"zh": "操控 {0} · SHIFT 换人", "en": "DRIVING {0} · SHIFT TO SWAP"},
	"hud.acting": {"zh": "{0}", "en": "{0}"},
	"hud.standby_stable": {"zh": "待命", "en": "STANDBY"},
	"hud.standby_risk": {"zh": "待命 · 在晃", "en": "STANDBY · WOBBLY"},
	# 神游一旦开始就不再加“待命”前缀：行本身就在角色名下，前缀只是占宽度；
	# 省下来的位置留给后面的“具体后果”。
	"hud.drift_distracted": {"zh": "电流不稳", "en": "CURRENT UNSTABLE"},
	"hud.drift_restless": {"zh": "电流发麻", "en": "CURRENT BUZZ"},
	"hud.drift_mischief": {"zh": "电流过载！", "en": "OVERLOAD!"},
	# CORE-FEEL-07 P1-D：只写“它现在在想别的”不够——用户试玩时看不出神游满值
	# 到底会怎样。状态行后面直接跟这一刻真正生效的代价（读控制器当前值）。
	"hud.drift_effect_rabbit": {
		"zh": "空中修正 {0}% · 落点偏",
		"en": "AIR {0}% · LANDING OFF"},
	"hud.drift_effect_rabbit_light": {
		"zh": "空中修正 {0}% · 开始走神",
		"en": "AIR {0}% · DRIFTING"},
	"hud.drift_effect_turtle": {
		"zh": "速度 {0}% · 壳在晃",
		"en": "SPEED {0}% · SHELL WOBBLY"},
	"hud.drift_effect_turtle_light": {
		"zh": "速度 {0}% · 开始走神",
		"en": "SPEED {0}% · DRIFTING"},
	# 受控恢复中只报主代价（百分比），并把“回神中”放在数字前：恢复的核心读数
	# 是“数字在变好”，同时英文面板也塞得下（满值 + 两行状态时面积仍 <= 8%）。
	"hud.drift_recover_rabbit": {
		"zh": "回神中 · 空中修正 {0}%",
		"en": "RECOVER · AIR {0}%"},
	"hud.drift_recover_turtle": {
		"zh": "回神中 · 速度 {0}%",
		"en": "RECOVER · SPEED {0}%"},
	"hud.drift_recovering": {"zh": "回神中", "en": "RECOVER"},
	"hud.rabbit_risk": {"zh": "兔子 在晃 {0}%", "en": "TUBO WOBBLE {0}%"},
	"hud.turtle_risk": {"zh": "乌龟 在晃 {0}%", "en": "BITT WOBBLE {0}%"},
	# REBUILD-05 C2：协作时机提示。只在障碍进入 520 px 预警圈时出现，
	# 有效窗口用“现在”，窗口过去用“已错过”明确结束。
	"hud.coop_prepare": {"zh": "{0}  准备", "en": "{0}  GET READY"},
	"hud.coop_now": {"zh": "{0}  现在！", "en": "{0}  NOW!"},
	"hud.coop_missed": {"zh": "{0}  已错过", "en": "{0}  MISSED"},
	"hud.coop_tag": {"zh": "可 {0}", "en": "{0} READY"},
	"hud.coop_assist": {"zh": "配合", "en": "ASSIST"},
	# REBUILD-05 G2：BRO DIVE 的第二步——“该松手了”。B3 实测：一直按住 ↓
	# 会把壳停在水下 150 px，兔子落壳时擦水白记一次事故，而画面上只有水花差别。
	# 这条提示只在“兔子还在空中 + 壳还在浮木右侧下潜”时出现，松手就消失。
	"hud.coop_release": {"zh": "松开 ↓ 上浮接人！", "en": "RELEASE ↓ - SURFACE & CATCH!"},
	"feedback.waterlogged": {"zh": "兔子 呛水了，气短——别再频繁掉水", "en": "TUBO IS WATERLOGGED - DON'T KEEP FALLING IN"},
	"hud.oxygen": {"zh": "氧气 {0}s", "en": "AIR {0}s"},
	"hud.oxygen_recovering": {"zh": "浮上来了，正在回气", "en": "SURFACE - RECOVERING"},
	"hud.oxygen_low": {"zh": "氧气偏低", "en": "AIR LOW"},
	"hud.oxygen_critical": {"zh": "氧气告急", "en": "AIR CRITICAL"},
	# 兄弟情和干净通过合并成一个三格计数。
	"hud.bond": {"zh": "兄弟配合 {0}/{1}", "en": "BRO COMBO {0}/{1}"},
	"hud.showtime_t": {"zh": "配合 {0}s", "en": "SHOWTIME {0}s"},
	# 阶段 4：过载槽是“失误槽”，和上面的连击不是一回事。
	# §七-9：hud.score 已移除——固定数字总分不再出现在玩家界面。
	"hud.bro_meter": {"zh": "捣乱压力 {0}/{1}", "en": "OVERLOAD {0}/{1}"},
	"hud.bro_other": {"zh": "{0} 捣乱压力 {1}/{2}", "en": "{0} OVERLOAD {1}/{2}"},
	"hud.bro_meter_role": {"zh": "{0} 捣乱压力 {1}/{2}", "en": "{0} OVERLOAD {1}/{2}"},

	# ---- 角色与氧气状态 ----
	"state.RIDING": {"zh": "骑乘", "en": "RIDING"},
	"state.RECOVERING": {"zh": "恢复中", "en": "RECOVERING"},
	"state.RELAXED": {"zh": "电流发麻", "en": "CURRENT BUZZ"},
	"state.NO_POWER": {"zh": "无动力", "en": "NO POWER"},
	"state.TOO_DEEP": {"zh": "过深", "en": "TOO DEEP"},
	"state.SLIDING": {"zh": "正在滑落", "en": "SLIPPING"},
	"state.EDGE": {"zh": "快掉了", "en": "ABOUT TO FALL"},
	"state.STUNNED": {"zh": "眩晕", "en": "STUNNED"},
	"state.SHOWTIME": {"zh": "表演中", "en": "SHOWTIME"},
	"state.AIRBORNE": {"zh": "空中", "en": "AIRBORNE"},
	"state.WAITING_CATCH": {"zh": "落水 · 等接应", "en": "IN WATER · WAIT"},
	"state.CRUISING": {"zh": "巡航", "en": "CRUISING"},
	"state.BOOSTING": {"zh": "加速", "en": "BOOSTING"},
	"state.SURFACING": {"zh": "上浮", "en": "SURFACING"},
	"state.DIVING": {"zh": "下潜", "en": "DIVING"},
	"state.CROUCHING": {"zh": "趴低", "en": "CROUCHING"},
	"state.GRIPPING": {"zh": "抓紧", "en": "GRIPPING"},
	"state.LEAPING": {"zh": "跃起", "en": "LEAPING"},
	"state.DUNKED": {"zh": "被浪压进水里", "en": "DUNKED"},
	# CORE-FEEL-07C：撞上障碍时壳是真的翻过去了，状态字必须和第 0.9 s 的画面一致，
	# 不能整段都说“被浪压进水里”。
	"state.BELLY_UP": {"zh": "翻肚皮", "en": "BELLY UP"},
	"state.UNSTEADY": {"zh": "轻微晃动", "en": "UNSTEADY"},
	"state.WOBBLING": {"zh": "明显摇晃", "en": "WOBBLING"},
	"state.FLIP_RISK": {"zh": "要翻了", "en": "FLIP RISK"},
	"state.DAZED": {"zh": "恍惚", "en": "DAZED"},
	"state.SINKING": {"zh": "下沉", "en": "SINKING"},
	"state.DEEP": {"zh": "过深", "en": "DEEP"},
	"state.DANGER": {"zh": "危险", "en": "DANGER"},
	"state.UNCONSCIOUS": {"zh": "昏迷", "en": "UNCONSCIOUS"},
	"state.EMERGENCY": {"zh": "紧急", "en": "EMERGENCY"},
	"state.JUMPING": {"zh": "跳跃", "en": "JUMPING"},
	"state.FALLING": {"zh": "下落", "en": "FALLING"},
	"state.RESCUING": {"zh": "救援", "en": "RESCUING"},
	"state.SAFE": {"zh": "安全", "en": "SAFE"},
	"state.LOW": {"zh": "偏低", "en": "LOW"},
	"state.CRITICAL": {"zh": "告急", "en": "CRITICAL"},
	"state.EMPTY": {"zh": "耗尽", "en": "EMPTY"},

	# ---- 事故 ----
	"accident.RABBIT_SLIP": {"zh": "兔子滑落", "en": "TUBO SLIP"},
	"accident.RABBIT_WATER": {"zh": "兔子落水", "en": "TUBO IN WATER"},
	"accident.RABBIT_AIR": {"zh": "兔子被抛到空中", "en": "TUBO IN THE AIR"},
	"accident.OXYGEN_OUT": {"zh": "氧气耗尽", "en": "OXYGEN OUT"},
	"accident.TURTLE_REEF": {"zh": "乌龟撞礁 / 下沉", "en": "BITT REEF / SINK"},
	"accident.RABBIT_STUN": {"zh": "兔子硬直", "en": "TUBO STUN"},

	# ---- 等级 ----
	"grade.S": {"zh": "绝对好兄弟！", "en": "ABSOLUTE BROS!"},
	"grade.A": {"zh": "肌肉兄弟！", "en": "MUSCLE BROTHERS!"},
	"grade.B": {"zh": "还算铁的哥们！", "en": "PRETTY GOOD BUDDIES!"},
	"grade.C": {"zh": "塑料兄弟情！", "en": "PLASTIC FRIENDSHIP!"},
	"grade.D": {"zh": "两个脑细胞，零配合！", "en": "TWO BRAIN CELLS, ZERO COORDINATION!"},

	# ---- 区域 ----
	"zone.1.name": {"zh": "阳光海岸", "en": "SUNNY COAST"},
	"zone.2.name": {"zh": "码头乱流", "en": "DOCK CHAOS"},
	"zone.3.name": {"zh": "肌肉狂潮", "en": "MUSCLE MAYHEM"},
	"zone.1.lesson": {
		"zh": "区域 1 阳光海岸 - 学会跳、趴低、乌龟跃起和下潜",
		"en": "ZONE 1  SUNNY COAST - LEARN JUMP, CROUCH, BITT LEAP AND DIVE"},
	"zone.2.lesson": {
		"zh": "区域 2 码头乱流 - 吊网、鳗鱼、船闸，换对人才过得去",
		"en": "ZONE 2  DOCK CHAOS - NETS, EELS, SLUICES: PICK THE RIGHT BRO"},
	"zone.3.lesson": {
		"zh": "区域 3 肌肉狂潮 - 龟兔各走一条路，别靠连点",
		"en": "ZONE 3  MUSCLE MAYHEM - TWO ROUTES, NO MASHING"},

	# ---- 障碍提示 ----
	"hazard.low_rock": {"zh": "低岩", "en": "LOW ROCK"},
	"hazard.low_beam": {"zh": "低梁", "en": "LOW BEAM"},
	"hazard.low_bird": {"zh": "低飞海鸟", "en": "LOW BIRD"},
	"hazard.dock_beam": {"zh": "码头横梁", "en": "DOCK BEAM"},
	"hazard.shark": {"zh": "鲨鱼", "en": "SHARK"},
	"hazard.dive_gate": {"zh": "水下拱岩", "en": "REEF ARCH"},
	"hazard.floating_log": {"zh": "浮木", "en": "FLOATING LOG"},
	"hazard.high_wall": {"zh": "高墙", "en": "HIGH WALL"},
	"hazard.reef": {"zh": "暗礁", "en": "REEF"},
	"hazard.reef_chain": {"zh": "礁链", "en": "REEF CHAIN"},
	"hazard.long_wall": {"zh": "长墙", "en": "LONG WALL"},
	"hazard.sink_gate": {"zh": "下沉门", "en": "SINK GATE"},
	"hazard.final_gate": {"zh": "终点门", "en": "FINAL GATE"},
	"hazard.low_bar": {"zh": "低杆", "en": "LOW BAR"},
	"hazard.rock_beam": {"zh": "岩石 + 横梁", "en": "ROCK + BEAM"},
	"action.jump_or_dive": {"zh": "跳过去", "en": "JUMP OVER"},
	"action.crouch_or_dive": {"zh": "趴下", "en": "CROUCH DOWN"},
	"action.leap": {"zh": "乌龟 ↑ 跃起", "en": "BITT ↑ LEAP"},
	"action.dive": {"zh": "乌龟 ↓ 下潜", "en": "BITT ↓ DIVE"},
	"action.jump_and_dive": {"zh": "兔子跳 + 乌龟潜", "en": "TUBO JUMP + BITT DIVE"},
	"action.stay_high": {"zh": "保持水面", "en": "STAY HIGH"},
	"action.dive_through": {"zh": "换人让壳沉", "en": "HAND OVER TO SINK"},
	"action.take_rabbit": {"zh": "换给兔子", "en": "TAKE THE TUBO"},
	"action.dont_jump": {"zh": "别跳", "en": "DON'T JUMP"},
	"action.jump_then_crouch": {"zh": "先跳再趴", "en": "JUMP THEN CROUCH"},
	"action.crouch_after_landing": {"zh": "落地后趴下", "en": "CROUCH AFTER LANDING"},
	# REBUILD-05 G19：教学文本以前只说“兔子按 ↓”，没说怎么变成兔子。
	# 新手在乌龟身上按 ↓ 会下潜（另一个动作），然后莫名其妙撞梁。
	# 需要换人的类型，第一次教学就把 SHIFT 点名出来。
	"lesson.rock": {
		"zh": "跳过岩石——按 SHIFT 换到 兔子，再按 ↑ 起跳",
		"en": "JUMP THE ROCK - SHIFT TO THE TUBO, THEN ↑"},
	"lesson.beam": {
		"zh": "趴低过梁——按 SHIFT 换到 兔子，再按 ↓ 趴低",
		"en": "CROUCH UNDER THE BEAM - SHIFT TO THE TUBO, THEN ↓"},
	"lesson.reef": {
		"zh": "暗礁在深处 - 贴着水面走",
		"en": "REEFS SIT DEEP - STAY ON THE SURFACE"},
	"lesson.wall": {
		"zh": "长墙——按 SHIFT 换到 兔子，壳会自己沉下去",
		"en": "LONG WALL - SHIFT TO THE TUBO AND THE SHELL SINKS"},
	"lesson.sink_gate": {
		"zh": "下沉门——兔子 掌舵时，龟壳会自己沉下去",
		"en": "SINK GATE - THE SHELL SINKS WHILE THE TUBO IS IN CHARGE"},
	"lesson.airbar": {
		"zh": "低杆——让 兔子 留在龟壳上",
		"en": "LOW BAR - KEEP THE TUBO ON THE SHELL"},
	"lesson.combo": {
		"zh": "干净通过，别撞。",
		"en": "CLEAN PASSES. DON'T CRASH."},
	"lesson.bird": {
		"zh": "低飞海鸟——按 SHIFT 换到 兔子 趴低，乌龟 照常巡航",
		"en": "LOW BIRD - SHIFT TO THE TUBO AND PRESS ↓, THE SHELL KEEPS CRUISING"},
	"lesson.dock_beam": {
		"zh": "码头横梁——按 SHIFT 换到 兔子 趴低过，龟壳不受影响",
		"en": "DOCK BEAM - SHIFT TO THE TUBO AND CROUCH, THE SHELL IS UNAFFECTED"},
	"lesson.gate": {
		"zh": "水下拱岩——按 SHIFT 换到 乌龟，按住 ↓ 潜过去",
		"en": "REEF ARCH - SHIFT TO THE BITT AND HOLD ↓"},
	"lesson.shark": {
		"zh": "鲨鱼从下面冲上来——按 SHIFT 换到 乌龟，再按 ↑ 跃起",
		"en": "SHARK FROM BELOW - SHIFT TO THE BITT AND PRESS ↑"},
	# REBUILD-05 G2：第三步以前没有说法——越过木尾要松手，否则壳停在水下、
	# 兔子落壳擦水。教学只加这一句，和 HUD 的“松开 ↓”提示用同一套说法。
	"lesson.log": {
		"zh": "浮木——兔子 先跳，按 SHIFT 换 乌龟 下潜；越过木尾松开 ↓ 上浮接人",
		"en": "FLOATING LOG - JUMP, SHIFT, DIVE. PAST THE LOG, RELEASE ↓ TO CATCH."},

	# REBUILD-05 G19：A 类障碍（低梁/海鸟/岩檐）只在兔子的那一层判定。
	# 玩家当时要是在操控乌龟，兔子只是“搭车”，根本没法躲——但画面上看起来
	# 就是“我什么都没按就撞了”。第一次发生时给一句换人，一局只说一次。
	"hint.take_rabbit": {
		"zh": "按 SHIFT 换到 兔子——这一下只有他能躲",
		"en": "PRESS SHIFT FOR THE TUBO - ONLY IT CAN DODGE THIS"},

	# ---- 场景文字与提示 ----
	"world.zone_header": {"zh": "{0}  {1}", "en": "{0}  {1}"},
	"world.danger_depth": {"zh": "危险深度", "en": "DANGER DEPTH"},
	"world.finish": {"zh": "终点", "en": "FINISH"},
	"world.finish_cousin": {
		"zh": "大表哥：跑起来！别让我白等！",
		"en": "COUSIN: BRING IT HOME! I'VE BEEN WAITING!"},
	"world.finish_cheer": {
		"zh": "大表哥：这才叫兄弟默契！",
		"en": "COUSIN: THAT'S BRO SYNC!"},
	"world.safe_above": {"zh": "跳上面", "en": "JUMP ABOVE"},
	"world.safe_below": {"zh": "潜下面", "en": "DIVE BELOW"},
	"world.current": {"zh": "急流", "en": "CURRENT"},
	"world.dive_here": {"zh": "潜下去", "en": "DIVE"},
	"world.ollie": {"zh": "跃墙", "en": "OLLIE"},
	"world.jump_here": {"zh": "跳过去", "en": "JUMP"},
	"world.blocked": {"zh": "过不去", "en": "BLOCKED"},
	"world.winch_up": {"zh": "网升起 ↑", "en": "NET UP ↑"},
	"world.net_low": {"zh": "网压低了", "en": "NET LOW"},
	"world.showtime_pop": {"zh": "漂亮！", "en": "NICE!"},
	"combo.bro_dive": {"zh": "兄弟下潜", "en": "BRO DIVE"},
	"combo.bro_ollie": {"zh": "兄弟蹬墙", "en": "BRO OLLIE"},
	"world.paused": {"zh": "已暂停", "en": "PAUSED"},
	"pause.title": {"zh": "已暂停", "en": "PAUSED"},
	"pause.breath": {"zh": "喘口气，兄弟。", "en": "Take a breath, bro."},
	"pause.resume": {"zh": "继续游戏", "en": "RESUME"},
	"pause.restart": {"zh": "重新开始", "en": "RESTART"},
	"pause.menu": {"zh": "返回主菜单", "en": "MAIN MENU"},
	"pause.keys": {
		"zh": "ESC 继续   R 重开   M 主菜单",
		"en": "ESC RESUME   R RESTART   M MENU"},
	# CORE-FEEL-07 P1-C：暂停是玩家唯一能停下来读规则的地方，食物规则写在暂停页。
	"pause.food": {
		"zh": "能量海藻：SHIFT 决定谁吃 — 乌龟吃 = 加速，兔子吃 = 下一跳更高；不吃不扣分",
		"en": "SNACK: SHIFT PICKS WHO EATS - BITT = TURBO, TUBO = HIGHER JUMP; SKIPPING COSTS NOTHING"},
	# FEEL-09 P1-A：暂停页可重新打开的帮助。按“谁 + 为什么 + 按什么”写，
	# 每条一行，最多两行；不新增美术素材。
	"pause.help": {"zh": "帮助 / 操作说明", "en": "HELP / CONTROLS"},
	"pause.help_title": {"zh": "操作说明", "en": "CONTROLS"},
	"pause.help_body": {
		"zh": "SHIFT 换人：兔子 ↑ 跳 / ↓ 趴低；乌龟 ↑ 跃起 / ↓ 下潜\n兔子 头顶的气泡是氧气；失误后他会嘟囔，没人管就可能自己找事\n海藻：SHIFT 决定谁吃——乌龟 加速，兔子 下一跳更高；不吃不扣分\n换人接力 · 海藻加速 · 下潜靠近救兄弟\n救援：乌龟 下潜靠近 兔子 就会接住；够不到按 SPACE 追一把",
		"en": "SHIFT SWAP: TUBO ↑ JUMP / ↓ CROUCH; BITT ↑ LEAP / ↓ DIVE\nTHE BUBBLES OVER TUBO ARE AIR; A FULL OVERLOAD METER MAKES THE CURRENT BODY ACT OUT\nSEAWEED: SHIFT PICKS WHO EATS - BITT SPEEDS UP, TUBO JUMPS HIGHER; SKIPPING COSTS NOTHING\nSHIFT RELAYS · CLEAN PASSES BUILD BRO COMBO · TEAM MOVES CLICK INTO SHOWTIME\nRESCUE: DIVE THE BITT CLOSE TO A TUBO IN THE WATER; SPACE TO LUNGE"},
	"world.pause_hint": {
		"zh": "ESC 继续   SHIFT 换人   R 重开   M 主菜单",
		"en": "ESC RESUME   SHIFT TRANSFER   R RESTART   M MENU"},
	"world.boost": {"zh": "加速带", "en": "BOOST"},
	"world.snack": {"zh": "海藻", "en": "SNACK"},
	"world.eat_now": {"zh": "吃", "en": "EAT"},
	"world.grip": {"zh": "{0}   抓地 {1}%", "en": "{0}  GRIP {1}%"},
	"center.zone": {"zh": "区域 {0}  {1}", "en": "ZONE {0}  {1}"},
	"center.showtime": {"zh": "兄弟合拍！", "en": "SHOWTIME!"},
	"center.brotherhood": {"zh": "兄弟情！", "en": "BROTHERHOOD!"},
	"center.shows_over": {"zh": "漂亮，收工！", "en": "NICE - THAT'S A WRAP!"},
	"center.finish": {"zh": "冲线！  {0}  {1}", "en": "FINISH!  {0}  {1}"},
	# CORE-FEEL-07D：满格是“命运绑定 → 两个人一起遭殃”，不是“两个人都有错”。
	# 旧文案“联合惩罚”会让只失误一次的玩家觉得被冤枉，改说后果、不指认谁犯错。
	"center.bro_full": {
		"zh": "两人同时出事 —— 一起翻船！",
		"en": "BOTH IN TROUBLE - CAPSIZED!"},
	"center.bro_recover": {
		"zh": "重新出发！",
		"en": "BACK IN ACTION!"},
	"hint.air_low": {"zh": "氧气偏低 - 换回乌龟就上浮", "en": "AIR LOW - TAKE THE BITT BACK"},
	"hint.air_critical": {"zh": "氧气告急 - 马上换乌龟", "en": "AIR CRITICAL - BITT NOW"},
	"hint.clean_pass": {"zh": "干净通过  {0}/{1}", "en": "CLEAN PASS  {0}/{1}"},
	"hint.pickup": {"zh": "接住了！", "en": "PICKUP!"},
	"hint.first_bro_dive": {
		"zh": "BRO DIVE：先跳，再 SHIFT 到乌龟按住 ↓",
		"en": "BRO DIVE: JUMP, SHIFT TO BITT, HOLD DOWN"},
	"hint.boost": {
		"zh": "加速带 - 操控乌龟时自动提速",
		"en": "BOOST LANE - AUTOMATIC WHILE DRIVING THE BITT"},
	"hint.snack": {
		"zh": "海藻：SHIFT 决定谁吃；不吃不扣分",
		"en": "SNACK: SHIFT PICKS WHO EATS; SKIPPING IS FREE"},
	"hint.wave_hit": {
		"zh": "壳翻了 - 稳住，等它自己翻回来",
		"en": "SHELL FLIPPED - STEADY, IT ROLLS BACK"},
	"hint.buoy_hit": {
		"zh": "乌龟 撞上浮标/木箱 - 等它落下或跃起",
		"en": "BITT HIT THE BUOY/CRATE - WAIT OR LEAP"},
	# CORE-FEEL-07C：乌龟的失败提示要说“这个障碍该做什么”，不再一律喊换人。
	"hint.shark_hit": {
		"zh": "鲨鱼只咬壳 - 按 ↑ 跃起躲开",
		"en": "THE SHARK BITES THE SHELL - PRESS ↑ TO LEAP"},
	"hint.gate_hit": {
		"zh": "拱岩：按住 ↓ 潜到它下面再松",
		"en": "REEF ARCH: HOLD ↓ UNTIL YOU'RE UNDER IT"},
	"hint.wall_hit": {
		"zh": "高墙：乌龟先 ↑ 跃起，兔子再蹬一下",
		"en": "HIGH WALL: ↑ LEAP, THEN KICK WITH THE TUBO"},

	# ---- 阶段 4：干净通过 / BRO PASS / 首次教学 ----
	"feedback.clean": {"zh": "漂亮！", "en": "NICE!"},
	"feedback.bro_pass": {"zh": "兄弟配合！", "en": "BRO PASS!"},
	"feedback.bro_dive": {"zh": "兄弟下潜！", "en": "BRO DIVE!"},
	"feedback.bro_ollie": {"zh": "兄弟蹬墙！", "en": "BRO OLLIE!"},
	"feedback.bro_combo": {"zh": "兄弟配合！", "en": "BRO COMBO!"},
	"feedback.leap": {"zh": "跃起！", "en": "LEAP!"},
	"feedback.leap_underwater": {"zh": "先浮上水面再跃起", "en": "SURFACE FIRST, THEN LEAP"},
	"feedback.turbo": {"zh": "乌龟 加速！吞下去了！", "en": "BITT TURBO! GULP!"},
	# REBUILD-06 P4：兔子吃到海藻的专属反馈（跳跃强化）。
	"feedback.snack_rabbit": {
		"zh": "兔子 吃了！下一跳更高！",
		"en": "TUBO ATE! HIGHER JUMP!"},
	# PLAYFUL-04 §4：切到乌龟亲手喂到的正向反馈（不切也照样吃，只是没这一下）。
	"feedback.turbo_switch": {
		"zh": "乌龟 加速！这口喂得漂亮！",
		"en": "BITT TURBO! HAND-FED!"},
	"feedback.wave_hit": {"zh": "壳被浪掀翻了！", "en": "WAVE HIT - SHELL FLIPPED!"},
	"bro.crouch": {"zh": "趴下！", "en": "GET DOWN!"},
	"bro.down": {"zh": "往下！", "en": "GO DOWN!"},
	"bro.leap": {"zh": "跃起来！", "en": "LEAP!"},
	"bro.bonk": {"zh": "别硬顶！先换人！", "en": "STOP HEADBUTTING IT - SWITCH!"},
	"sleep.telegraph_rabbit": {
		"zh": "兔子开始走神……", "en": "TUBO IS DRIFTING OFF..."},
	"sleep.telegraph_turtle": {
		"zh": "乌龟开始走神……", "en": "BITT IS DRIFTING OFF..."},
	"sleep.zap_rabbit": {
		"zh": "兔子漏电！乌龟被电了一下", "en": "TUBO LEAKS! BITT GETS ZAPPED"},
	"sleep.zap_turtle": {
		"zh": "乌龟漏电！兔子被电了一下", "en": "BITT LEAKS! TUBO GETS ZAPPED"},
	"feedback.turtle_bonk": {
		"zh": "咚！乌龟被弹回来了（{0}/{1}）",
		"en": "BONK! BITT BOUNCED BACK ({0}/{1})"},
	"cousin.bonk_hint": {
		"zh": "大表哥：别硬顶！先换人，再看清楚再按。",
		"en": "COUSIN: STOP HEADBUTTING IT - SWITCH, THEN READ IT."},
	"feedback.shark_pack": {"zh": "鲨鱼群围上来了！", "en": "THE SHARK PACK IS CIRCLING!"},
	"feedback.shark_fat": {"zh": "胖鲨盯上兔子了！", "en": "THE FAT SHARK WANTS TUBO!"},
	"feedback.shark_boss": {
		"zh": "老大来了——SHIFT 乌龟，等它冲上来再跃起",
		"en": "THE BOSS - SHIFT BITT, LEAP AS IT RISES"},
	"feedback.shark_boss_ready": {
		"zh": "老大要冲了——SHIFT 乌龟，准备跃起",
		"en": "BOSS INCOMING - SHIFT BITT, GET READY TO LEAP"},
	"feedback.shark_boss_now": {
		"zh": "现在——跃起！",
		"en": "NOW - LEAP!"},
	"feedback.shark_thin": {"zh": "瘦鲨压过来了！", "en": "THE THIN SHARK IS OVERHEAD!"},
	"feedback.shark_intervention": {"zh": "鲨群撞碎障碍！前面换成胖鲨低扑——趴低！", "en": "THE PACK SMASHES THROUGH - FAT SHARK AHEAD, CROUCH!"},
	"feedback.bird_attack": {"zh": "海鸟变招了——看预兆！", "en": "THE GULL CHANGED ATTACK - WATCH THE TELL!"},
	"feedback.bird_poop": {"zh": "乌龟 被海鸟排泄物砸到！", "en": "BITT GOT HIT BY GULL DROPPINGS!"},
	"hint.bird_poop": {"zh": "看落点预兆 - 潜开或换 兔子", "en": "WATCH THE DROP MARKER - DIVE OR SWITCH TO TUBO"},
	"feedback.buoy_hit": {"zh": "乌龟 撞上浮标/木箱！", "en": "BITT HIT THE BUOY/CRATE!"},
	# CORE-FEEL-07C：乌龟撞的不一定是浪。鲨鱼、拱岩、高墙各有自己的失败说法，
	# 否则玩家看到的字和刚撞上的东西对不上。
	"feedback.shark_hit": {
		"zh": "鲨鱼从下面来的 - 壳翻了！",
		"en": "SHARK FROM BELOW - SHELL FLIPPED!"},
	"feedback.gate_hit": {
		"zh": "没潜到位 - 壳撞上拱岩！",
		"en": "NOT DEEP ENOUGH - HIT THE REEF ARCH!"},
	"feedback.wall_hit": {
		"zh": "没跃过墙 - 壳撞上去了！",
		"en": "MISSED THE OLLIE - SHELL HIT THE WALL!"},
	# PLAYFUL-04：浮木撞壳的两种失败要分得开，否则玩家不知道错在哪一步。
	"feedback.dive_late": {
		"zh": "下潜太晚 - 壳撞上浮木！",
		"en": "DIVE TOO LATE - SHELL HIT THE LOG!"},
	"feedback.log_jump": {
		"zh": "跳跃高度不对 - 撞上浮木！",
		"en": "BAD JUMP ARC - HIT THE LOG!"},
	"hint.dive_late": {
		"zh": "浮木：兔子起跳后 SHIFT 给乌龟，按住 ↓ 下潜；过木后松手上浮",
		"en": "LOG: JUMP, THEN SHIFT TO BITT - HOLD ↓ TO DIVE; RELEASE TO SURFACE"},
	"hint.log_jump": {
		"zh": "浮木：先按 ↑ 让兔子起跳，再 SHIFT 给乌龟",
		"en": "LOG: PRESS ↑ TO JUMP FIRST, THEN SHIFT TO THE BITT"},
	# REBUILD-05 G3：按住 ↓ 不放导致的擦水（B3 实测）。和 G2 的“松开 ↓”提示同一套说法。
	"hint.dive_deep": {
		"zh": "壳停得太深 - 浮木组合请先 ↑ 起跳再 SHIFT，下潜和上浮会自动完成",
		"en": "SHELL TOO DEEP - FOR LOGS: ↑ JUMP THEN SHIFT; DIVE AND SURFACE ARE AUTOMATIC"},
	# REBUILD-05 G6：会动的障碍首次出现时的一区一次提示。
	# CORE-FEEL-08 P1-C：浮木随浪走仍用这条；岩/箱按身份各说各的来历。
	"hint.motion": {
		"zh": "这组会动 - 看准空隙再上",
		"en": "THIS ONE MOVES - GO THROUGH THE GAP"},
	"hint.motion_buoy": {
		"zh": "系泊浮标：锚绳拴在海底，随涌浪起落 - 等它落到低点再跳",
		"en": "MOORING BUOY - ROPED TO THE SEABED, RIDES THE SWELL. JUMP AT THE LOW POINT"},
	"hint.motion_hoist": {
		"zh": "吊装货箱：挂在码头吊钩上，跟着吊臂上下晃 - 看准它升起的那拍",
		"en": "HOIST CRATE - HANGS FROM THE DOCK CRANE AND SWINGS WITH IT. TIME THE LIFT"},
	"hint.motion_cargo": {
		"zh": "漂流货箱：从码头冲出来的货，随大浪浮沉 - 看准浪谷再跳",
		"en": "DRIFTING CARGO - WASHED OUT FROM THE DOCK, RIDES THE SWELL. JUMP IN THE TROUGH"},
	# FEEL-09 P0-A：Z2 的鲨鱼换成水渠鳗鱼，运动提示也要说清水渠里的来历。
	"hint.motion_eel": {
		"zh": "水渠鳗鱼：平时盘在水渠底，靠近时带电窜上来 - 提前跃起",
		"en": "CANAL EEL - COILED ON THE CANAL BED, SPARKS AND LUNGES. LEAP EARLY"},
	"mischief.telegraph_turtle": {"zh": "乌龟 眼神不对……", "en": "BITT IS PLANNING SOMETHING..."},
	"mischief.telegraph_rabbit": {"zh": "兔子 开始拽绳子了……", "en": "TUBO IS GRABBING THE ROPE..."},
	"mischief.start_turtle": {"zh": "乌龟 等烦了，开始搞事！", "en": "BITT GOT BORED - HERE WE GO!"},
	"mischief.start_rabbit": {"zh": "兔子 等烦了，开始搞事！", "en": "TUBO GOT BORED - HERE WE GO!"},
	"mischief.arc_block": {"zh": "乌龟 的电弧弹开了投射物！", "en": "BITT'S ARC DEFLECTED THE PROJECTILE!"},
	"mischief.hit_rabbit": {"zh": "乌龟 电了 兔子 一下！", "en": "BITT ZAPPED TUBO!"},
	"mischief.zap_landing": {"zh": "兔子 起跳时被 乌龟 电了一下，掉下去了！", "en": "BITT ZAPPED TUBO MID-AIR!"},
	"mischief.end": {"zh": "行了行了，我不闹了。", "en": "OKAY, OKAY - I'M DONE."},
	"mischief.tag_tug": {"zh": "拽绳", "en": "TUG"},
	"mischief.tag_zap": {"zh": "电击", "en": "ZAP"},
	"feedback.complaint_rabbit": {"zh": "兔子 嘟囔：又是我……", "en": "TUBO MUTTERS: ME AGAIN..."},
	"feedback.complaint_turtle": {"zh": "乌龟 嘟囔：你倒是看着点啊。", "en": "BITT MUTTERS: WATCH IT."},
	"feedback.log_smash": {"zh": "浮木撞碎了——继续走！", "en": "LOG SMASHED - KEEP GOING!"},
	"feedback.meter_mild": {"zh": "{0} 开始烦躁……", "en": "{0} IS GETTING FIDGETY..."},
	"feedback.meter_warn": {"zh": "{0} 快忍不住了！", "en": "{0} IS ABOUT TO BLOW!"},
	"mischief.hit_turtle": {"zh": "兔子 拽住绳子，乌龟 被勒得减速！", "en": "TUBO TUGGED THE ROPE - BITT SLOWED!"},
	"feedback.rescue_ok": {"zh": "接住了！兄弟！", "en": "CAUGHT! BRO!"},
	"feedback.rescue_reunion": {
		"zh": "兄弟回来了！氧气也回了一口",
		"en": "BRO'S BACK! AIR TOPPED UP"},
	"feedback.rescue_miss": {
		"zh": "没接住……兔子被冲回壳上",
		"en": "MISSED... TUBO WASHED BACK"},
	"feedback.rescue_auto_interrupt": {
		"zh": "兔子 又被冲走了——他还在水里",
		"en": "TUBO GOT WASHED AWAY - HE'S STILL IN THE WATER"},
	"feedback.rescue_auto_fail": {
		"zh": "乌龟 还够不到——下潜靠近，或按 SPACE 追一把",
		"en": "BITT CAN'T REACH - DIVE CLOSER OR PRESS SPACE"},
	"feedback.rescue_auto": {
		"zh": "水流把 兔子 推回壳上了……下次按 SPACE 更快",
		"en": "THE CURRENT WASHED TUBO BACK... PRESS SPACE NEXT TIME"},
	# REFINE-06 P1：换手的“开始收心”和“真的回过神”分开报，
	# 玩家能看出 SHIFT 立刻有用、但恢复需要持续受控。
	"feedback.shift_take": {
		"zh": "换人——{0} 开始回神",
		"en": "SWITCH - {0} RECOVERING"},
	# FEEL-09 P0-C：0.20 s 锁定期间的轻量反馈（不排队、不补发）。
	"feedback.shift_lock": {
		"zh": "刚换过人，稍等一下",
		"en": "JUST SWAPPED - WAIT A BEAT"},
	# FEEL-11 B3：电流接力。普通换人不给字；只有两边都动了才提示。
	"feedback.relay_clever": {
		"zh": "接力漂亮 +50",
		"en": "NICE RELAY +50"},
	"feedback.relay_perfect": {
		"zh": "完美接力 +100",
		"en": "PERFECT RELAY +100"},
	# FEEL-09 P0-D：Showtime 完成奖励（分 + 实际氧气增量），只在正常完成时出现。
	"feedback.showtime_reward": {
		"zh": "漂亮！这下配合上了！ 氧气 +{0}",
		"en": "NICE! THAT CLICKED. OXYGEN +{0}"},
	"feedback.showtime_reward_full": {
		"zh": "漂亮！这下配合上了！ 氧气已满",
		"en": "NICE! THAT CLICKED. OXYGEN FULL"},
	"feedback.drift_back": {
		"zh": "{0}回过神了",
		"en": "{0} IS BACK"},
	# CORE-FEEL-07 P1-D：越过 6 s / 9 s 阈值时报警一次，并写出此刻的具体代价。
	# 只报“升级”，不报降级（恢复由 drift_back 负责），快速换手不会连刷。
	"feedback.drift_warn_restless": {
		"zh": "{0} 电流发麻：{1}",
		"en": "{0} BUZZING: {1}"},
	"feedback.drift_warn_mischief": {
		"zh": "{0} 电流过载：{1}",
		"en": "{0} OVERLOAD: {1}"},
	# CORE-FEEL-08 P0-A：走神时“按了没马上动”要报一次，否则玩家会以为按键坏了。
	# 每个角色 2.5 s 最多一条；只说“慢半拍”，不报具体毫秒。
	"feedback.drift_lag_rabbit": {
		"zh": "兔子 电流慢了半拍 - 跳跃延迟",
		"en": "TUBO'S CURRENT LAGS - JUMP DELAYED"},
	"feedback.drift_lag_turtle": {
		"zh": "乌龟 电流慢了半拍 - 壳反应延迟",
		"en": "BITT'S CURRENT LAGS - SHELL DELAYED"},
	# 恶作剧阶段的自主动作：BITT 自己趴下一下（安全方向），不是惩罚，是“没在听指挥”。
	"feedback.drift_autocrouch": {
		"zh": "兔子 自己趴下了！",
		"en": "TUBO DUCKED ON ITS OWN!"},
	"prompt.jump": {"zh": "↑ 跳跃", "en": "↑ JUMP"},
	"prompt.crouch": {"zh": "↓ 趴低", "en": "↓ CROUCH"},
	"prompt.dual_beam": {
		"zh": "低梁：兔子趴低，或 SHIFT 乌龟下潜（耗氧）",
		"en": "LOW BEAM: TUBO CROUCH, OR SHIFT BITT + DIVE (OXYGEN)"},
	"prompt.dual_beam_on_turtle": {
		"zh": "低梁：乌龟下潜（耗氧），或 SHIFT 兔子趴低",
		"en": "LOW BEAM: BITT DIVE (OXYGEN), OR SHIFT TUBO + CROUCH"},
	"prompt.dual_bird": {
		"zh": "海鸟低飞：兔子趴低，或 SHIFT 乌龟下潜（耗氧）",
		"en": "LOW GULL: TUBO CROUCH, OR SHIFT BITT + DIVE (OXYGEN)"},
	"prompt.dual_bird_on_turtle": {
		"zh": "海鸟低飞：乌龟下潜（耗氧），或 SHIFT 兔子趴低",
		"en": "LOW GULL: BITT DIVE (OXYGEN), OR SHIFT TUBO + CROUCH"},
	"prompt.dual_rock": {
		"zh": "礁石：兔子跳过，或 SHIFT 乌龟下潜（耗氧，省一次换人）",
		"en": "ROCK: TUBO JUMP, OR SHIFT BITT + DIVE (OXYGEN, SAVES A SWAP)"},
	"prompt.dual_rock_on_turtle": {
		"zh": "礁石：乌龟下潜（耗氧），或 SHIFT 兔子跳过",
		"en": "ROCK: BITT DIVE (OXYGEN), OR SHIFT TUBO + JUMP"},
	"prompt.dual_tide_rock": {
		"zh": "潮汐岩：兔子看浪谷跳过（时机风险），或 SHIFT 乌龟下潜（耗氧）",
		"en": "TIDE ROCK: TUBO JUMPS THE TROUGH (TIMING), OR SHIFT BITT + DIVE (OXYGEN)"},
	"prompt.dual_tide_rock_on_turtle": {
		"zh": "潮汐岩：乌龟下潜（耗氧），或 SHIFT 兔子看浪谷跳",
		"en": "TIDE ROCK: BITT DIVE (OXYGEN), OR SHIFT TUBO + JUMP THE TROUGH"},
	"prompt.relay_shark3_beam3": {
		"zh": "连招：鲨鱼跃起 → 落下立刻 SHIFT 兔子趴低",
		"en": "CHAIN: LEAP THE SHARK → SHIFT TUBO + CROUCH"},
	"prompt.relay_rock4_gate3": {
		"zh": "连招：跳过岩 → SHIFT 乌龟潜拱",
		"en": "CHAIN: JUMP THE ROCK → SHIFT BITT + DIVE THE ARCH"},
	"prompt.relay_gate3_bird3": {
		"zh": "连招：出拱 → SHIFT 兔子趴低，或乌龟继续潜",
		"en": "CHAIN: OUT OF THE ARCH → SHIFT TUBO + CROUCH, OR KEEP BITT DIVING"},
	"prompt.relay_shark5_bird5": {
		"zh": "连招：鲨鱼退 → SHIFT 兔子趴低，或乌龟继续潜",
		"en": "CHAIN: SHARK RETREATS → SHIFT TUBO + CROUCH, OR KEEP BITT DIVING"},
	"prompt.relay_gate1_rock2": {
		"zh": "连招：拱下潜 → SHIFT 兔子跳过岩石",
		"en": "CHAIN: DIVE THE ARCH → SHIFT TUBO + JUMP THE ROCK"},
	"prompt.relay_rock6_gate4": {
		"zh": "提前换人：礁石后 3 秒是拱门——跳完立刻 SHIFT 乌龟，或直接潜过礁石",
		"en": "EARLY SWAP: THE ARCH IS 3 S AFTER THE ROCK - SHIFT BITT AFTER THE JUMP, OR DIVE THE ROCK"},
	"prompt.relay_gate6_log5": {
		"zh": "连招：拱下潜 → 立刻 SHIFT 兔子跳 → SHIFT 乌龟潜（浮木）",
		"en": "CHAIN: DIVE THE ARCH → SHIFT TUBO + JUMP → SHIFT BITT + DIVE"},
	"prompt.relay_log5_bird6": {
		"zh": "连招：浮木落地 → SHIFT 兔子趴低，或继续乌龟下潜",
		"en": "CHAIN: CLEAR THE LOG → SHIFT TUBO + CROUCH, OR KEEP BITT DIVING"},
	"prompt.relay_log7_rock10": {
		"zh": "连招：浮木落地 → SHIFT 兔子跳过岩石",
		"en": "CHAIN: CLEAR THE LOG → SHIFT TUBO + JUMP THE ROCK"},
	"prompt.relay_shark9_bird8": {
		"zh": "连招：鲨鱼退 → SHIFT 兔子趴低，或继续乌龟下潜",
		"en": "CHAIN: SHARK RETREATS → SHIFT TUBO + CROUCH, OR KEEP BITT DIVING"},
	"prompt.relay_gate8_bird9": {
		"zh": "连招：出拱 → 立刻 SHIFT 兔子，处理下一组",
		"en": "CHAIN: OUT OF THE ARCH → SHIFT TUBO FOR THE NEXT ONE"},
	"hint.relay_fail_gate1_rock2": {
		"zh": "连招断在换人：出拱后换兔子跳过，不要继续潜水",
		"en": "CHAIN BROKE: AFTER THE ARCH, SHIFT TUBO + JUMP - DON'T KEEP DIVING"},
	"hint.relay_fail_shark3_beam3": {
		"zh": "连招断在换人：鲨鱼落下后立刻 SHIFT 兔子趴低",
		"en": "CHAIN BROKE: AFTER THE SHARK, SHIFT TUBO + CROUCH"},
	"hint.relay_fail_rock4_gate3": {
		"zh": "连招断在换人：跳过岩后立刻 SHIFT 乌龟潜拱",
		"en": "CHAIN BROKE: AFTER THE ROCK, SHIFT BITT + DIVE"},
	"hint.relay_fail_gate3_bird3": {
		"zh": "连招断在换人：出拱后换兔子趴低，或继续乌龟潜",
		"en": "CHAIN BROKE: AFTER THE ARCH, SHIFT TUBO + CROUCH, OR KEEP DIVING"},
	"hint.relay_fail_shark5_bird5": {
		"zh": "连招断在换人：鲨鱼退后换兔子趴低，或继续乌龟潜",
		"en": "CHAIN BROKE: AFTER THE SHARK, SHIFT TUBO + CROUCH, OR KEEP DIVING"},
	"hint.relay_fail_rock6_gate4": {
		"zh": "连招断在换人：礁石后马上要下潜；提前 SHIFT 乌龟，或一开始就潜过礁石",
		"en": "CHAIN BROKE: THE ARCH IS NEXT - SHIFT BITT EARLY, OR DIVE THE ROCK FROM THE START"},
	"hint.relay_fail_gate6_log5": {
		"zh": "连招断在换人：下拱后先 SHIFT 兔子跳，再 SHIFT 乌龟潜",
		"en": "CHAIN BROKE: AFTER THE ARCH, SHIFT TUBO + JUMP, THEN SHIFT BITT + DIVE"},
	"hint.relay_fail_log5_bird6": {
		"zh": "连招断在换人：浮木落地后立刻 SHIFT 兔子趴低，或让乌龟继续潜",
		"en": "CHAIN BROKE: AFTER THE LOG, SHIFT TUBO + CROUCH, OR KEEP BITT DIVING"},
	"hint.relay_fail_log7_rock10": {
		"zh": "连招断在换人：浮木落地后立刻 SHIFT 兔子跳过",
		"en": "CHAIN BROKE: AFTER THE LOG, SHIFT TUBO + JUMP"},
	"hint.relay_fail_shark9_bird8": {
		"zh": "连招断在换人：鲨鱼退后立刻 SHIFT 兔子趴低，或继续下潜",
		"en": "CHAIN BROKE: AFTER THE SHARK, SHIFT TUBO + CROUCH, OR KEEP DIVING"},
	"hint.relay_fail_gate8_bird9": {
		"zh": "连招断在换人：出拱后立刻 SHIFT 兔子处理下一组",
		"en": "CHAIN BROKE: AFTER THE ARCH, SHIFT TUBO FOR THE NEXT GROUP"},
	"prompt.rescue_shift": {
		"zh": "SHIFT 到 乌龟，下潜靠近；够不到按 SPACE 追",
		"en": "SHIFT TO BITT, DIVE CLOSER; SPACE TO LUNGE"},
	"prompt.rescue_dive": {
		"zh": "下潜靠近 兔子；够不到按 SPACE 追",
		"en": "DIVE CLOSER; SPACE TO LUNGE"},
	"prompt.rescue_leap_shift": {
		"zh": "SHIFT 乌龟 → 按 ↑ 跃起接住兔子",
		"en": "SHIFT BITT → ↑ TO CATCH"},
	"prompt.rescue_leap": {
		"zh": "按 ↑ 跃起接住兔子",
		"en": "PRESS ↑ TO CATCH THE TUBO"},
	"prompt.leap": {
		"zh": "鲨鱼来了——SHIFT 到 乌龟，按 ↑ 跃起",
		"en": "SHARK - SHIFT TO BITT, PRESS ↑ TO LEAP"},
	"prompt.dive": {
		"zh": "拱岩下面有路——SHIFT 到 乌龟，按住 ↓ 潜",
		"en": "ARCH - SHIFT TO BITT, HOLD ↓ TO DIVE"},
	"prompt.combo": {
		"zh": "浮木——↑ 跳 → SHIFT → ↓ 潜",
		"en": "LOG - ↑ JUMP → SHIFT → ↓ DIVE"},
	"prompt.ollie": {
		"zh": "高墙——SHIFT 到 乌龟，↑ 跃起 → SHIFT → ↑ 蹬",
		"en": "WALL - SHIFT TO BITT, ↑ LEAP → SHIFT → ↑ KICK"},
	# REBUILD-05 F：首次教学提示要看“你现在控的是谁”。玩家先按过 SHIFT 再遇到
	# 第一组时，旧文案会让他按错人（比如已控乌龟，还叫他“SHIFT + ↓”）。
	# 兔子专属的障碍：提示先换回兔子；乌龟专属的：去掉多余的 SHIFT。
	"prompt.jump_from_turtle": {
		"zh": "SHIFT 回 兔子 → ↑ 跳",
		"en": "SHIFT TO TUBO → ↑ JUMP"},
	"prompt.crouch_from_turtle": {
		"zh": "SHIFT 回 兔子 → ↓ 趴低",
		"en": "SHIFT TO TUBO → ↓ CROUCH"},
	"prompt.leap_on_turtle": {
		"zh": "鲨鱼冲上来了——↑ 跃起",
		"en": "SHARK IS UP - ↑ LEAP"},
	"prompt.dive_on_turtle": {
		"zh": "拱岩下面就是通道——按住 ↓ 潜",
		"en": "THE GAP IS UNDER THE ARCH - HOLD ↓"},
	"prompt.combo_from_turtle": {
		"zh": "SHIFT 到 兔子 → ↑ 跳 → SHIFT → ↓ 潜",
		"en": "SHIFT TO TUBO → ↑ JUMP → SHIFT → ↓ DIVE"},
	"prompt.ollie_on_turtle": {
		"zh": "高墙——↑ 跃起 → SHIFT 到 兔子 → ↑ 蹬",
		"en": "WALL - ↑ LEAP → SHIFT TO TUBO → ↑ KICK"},
	# FEEL-09 P0-A：Z2 室内码头的三个新身份。每条都先说“为什么”，再说按键。
	"prompt.net": {
		"zh": "屋顶吊网压下来——↓ 趴低，从网底下过",
		"en": "CARGO NET - ↓ CROUCH"},
	"prompt.net_from_turtle": {
		"zh": "吊网只压 兔子 这一层——按住 ↓ 潜过去",
		"en": "CARGO NET - HOLD ↓ DIVE"},
	"prompt.eel": {
		"zh": "水渠鳗鱼会从底下窜上来——SHIFT 到 乌龟，按 ↑ 跃起",
		"en": "CANAL EEL - SHIFT TO BITT, ↑ LEAP"},
	"prompt.eel_on_turtle": {
		"zh": "鳗鱼从底下窜上来了——↑ 跃起",
		"en": "CANAL EEL - ↑ LEAP"},
	"prompt.sluice": {
		"zh": "船闸只有 乌龟 潜得过去——SHIFT 到 乌龟，按住 ↓",
		"en": "SLUICE GATE - SHIFT TO BITT, HOLD ↓"},
	"prompt.sluice_on_turtle": {
		"zh": "闸板下面就是通道——按住 ↓ 潜",
		"en": "SLUICE GATE - HOLD ↓"},

	# ---- 大字反馈 ----
	"banner.slip": {"zh": "摔了！兔子 没抓住", "en": "WIPEOUT! TUBO LOST GRIP"},
	"banner.water": {"zh": "扑通！兔子 落水", "en": "SPLASH! TUBO IN THE WATER"},
	"banner.stun": {"zh": "咚！兔子 被撞晕", "en": "BONK! TUBO IS STUNNED"},
	"banner.hit": {"zh": "哎哟！兔子 撞到了", "en": "OUCH! TUBO HIT SOMETHING"},
	"banner.reef": {"zh": "乌龟 撞上暗礁！", "en": "BITT HIT THE REEF!"},
	"banner.oxygen": {"zh": "没气了！紧急上浮", "en": "NO AIR! EMERGENCY ASCENT"},
	"banner.pickup": {"zh": "好接！", "en": "NICE SAVE!"},
	"banner.rescue": {"zh": "获救", "en": "RESCUED"},

	# ---- 结算 ----
	"fail.title": {"zh": "我把兄弟弄丢了", "en": "I LOST MY BROTHER"},
	"fail.sub": {
		"zh": "氧气见底了。\n乌龟 没能把他捞回来。",
		"en": "TUBO RAN OUT OF AIR.\nBITT COULDN'T GET HIM BACK."},
	"fail.reason_oxygen": {"zh": "原因：氧气耗尽", "en": "CAUSE: OUT OF AIR"},
	"fail.reason_bonk": {
		"zh": "原因：连续撞了 6 次，乌龟晕过去了",
		"en": "CAUSE: SIX BONKS IN A ROW - BITT IS OUT COLD"},
	"fail.line_bonk": {
		"zh": "我让我的兄弟晕过去了。",
		"en": "I LET MY BRO PASS OUT."},
	"fail.tip_bonk": {
		"zh": "先换人，再看清楚障碍再按。",
		"en": "SWITCH FIRST, THEN READ THE OBSTACLE."},
	"fail.tip_oxygen": {
		"zh": "下次：先 SHIFT 乌龟上浮，或让 兔子 吃海藻补氧。",
		"en": "NEXT: SHIFT TO BITT TO SURFACE, OR LET TUBO EAT KELP."},
	"fail.again": {"zh": "再来一次", "en": "TRY AGAIN"},
	"fail.menu": {"zh": "回主菜单", "en": "MAIN MENU"},
	"fail.hint": {"zh": "R / ENTER 再来一次 · M 回主菜单", "en": "R / ENTER RETRY · M MENU"},
	"result.title": {"zh": "训练结束", "en": "TRAINING'S OVER"},
	"result.antidote": {
		"zh": "大表哥把解药丢过来：喝了。下次别让我下水捞你们。",
		"en": "COUSIN TOSSES OVER THE ANTIDOTE: DRINK UP. NEXT TIME, DON'T MAKE ME FISH YOU OUT."},
	"result.time": {"zh": "比赛时间              {0} 秒", "en": "RACE TIME              {0} s"},
	"result.coop": {"zh": "默契                  {0}", "en": "SYNC                   {0}"},
	"result.clean": {"zh": "干净通过              {0}", "en": "CLEAN PASSES           {0}"},
	"result.breakdown": {
		"zh": "干净 {0} · BRO DIVE {1} · BRO OLLIE {2} · 食物 {3}",
		"en": "CLEAN {0} · BRO DIVE {1} · BRO OLLIE {2} · SNACKS {3}"},
	"result.combos": {"zh": "兄弟配合            {0}", "en": "BRO COMBO              {0}"},
	# G17：结算页的“下次试试”。只给一条，按 next_try_key() 的优先级挑。
	"result.try_combo": {
		"zh": "下次试试：兔子 跳起来后按 SHIFT 让 乌龟 下潜（兄弟下潜）",
		"en": "NEXT TRY: JUMP, THEN SHIFT THE BITT DOWN (BRO DIVE)"},
	"result.try_snack": {
		"zh": "下次试试：按 SHIFT 换到 乌龟，亲手把海藻喂给它",
		"en": "NEXT TRY: SHIFT TO THE BITT AND FEED IT THE SEAWEED"},
	"result.try_rescue": {
		"zh": "下次试试：兔子 落水时 SHIFT 到 乌龟，下潜靠近；够不到再按 SPACE 追",
		"en": "NEXT TRY: WHEN THE TUBO FALLS IN, SHIFT TO BITT AND DIVE CLOSER; SPACE TO LUNGE"},
	"result.mistakes": {"zh": "失误                  {0}", "en": "MISTAKES               {0}"},
	"result.next_goal_clean": {
		"zh": "下一目标：S 需要 0 次失误（本局 {0} 次）",
		"en": "NEXT GOAL: S REQUIRES 0 MISTAKES (THIS RUN: {0})"},
	"result.next_goal_score": {
		"zh": "下一目标：S 需要 8000 分以上",
		"en": "NEXT GOAL: S NEEDS 8000+"},
	"result.best": {
		"zh": "最佳时间 {0}   最低事故 {1}   最长连击 {2}",
		"en": "BEST TIME  {0}   BEST ACCIDENTS  {1}   BEST STREAK  {2}"},
	"result.new_time": {"zh": "新最佳时间！", "en": "NEW BEST TIME!"},
	"result.new_streak": {"zh": "新最长连击！", "en": "NEW BEST STREAK!"},
	"result.again": {"zh": "再玩一次", "en": "PLAY AGAIN"},
	"result.menu": {"zh": "返回主菜单", "en": "MAIN MENU"},
	"result.retry": {
		"zh": "R 再来一次    M 回主菜单    Enter 确认",
		"en": "R  RETRY    M  MAIN MENU    ENTER  CONFIRM"},
	"feedback.od_ready_rabbit": {
		"zh": "兔子 耳朵竖起 —— SHIFT 换走，让它弹！",
		"en": "TUBO'S EARS ARE UP - SHIFT AWAY AND LET IT SPRING!"},
	"feedback.od_ready_turtle": {
		"zh": "乌龟 的龟壳开始旋转 —— SHIFT 换走，让它旋！",
		"en": "BITT'S SHELL IS SPINNING - SHIFT AWAY AND LET IT SPIN!"},
	"feedback.od_spring": {
		"zh": "兔子 弹簧过载！",
		"en": "TUBO SPRING OVERLOAD!"},
	"feedback.od_shell": {
		"zh": "乌龟 旋壳过载！",
		"en": "BITT SHELL OVERLOAD!"},
	"feedback.od_end": {
		"zh": "电流稳定了",
		"en": "CURRENT STABLE"},
	"result.cousin_S": {
		"zh": "大表哥：这才叫兄弟默契！",
		"en": "COUSIN: NOW THAT'S BRO SYNC!"},
	"result.cousin_A": {
		"zh": "大表哥：有进步，再快一点！",
		"en": "COUSIN: BETTER. FASTER NEXT TIME!"},
	"result.cousin_B": {
		"zh": "大表哥：还行，别只靠蛮力。",
		"en": "COUSIN: NOT BAD. LESS MUSCLE, MORE SYNC."},
	"result.cousin_C": {
		"zh": "大表哥：你们俩是在互相拖后腿吗？",
		"en": "COUSIN: ARE YOU DRAGGING EACH OTHER?"},
	"result.cousin_D": {
		"zh": "大表哥：至少没沉底，再来！",
		"en": "COUSIN: AT LEAST YOU DIDN'T SINK. AGAIN!"},
	"result.tubo_S": {
		"zh": "兔子：我本来就很快。",
		"en": "TUBO: I WAS ALREADY FAST."},
	"result.bitt_S": {
		"zh": "乌龟：是我把你带过去的。",
		"en": "BITT: I CARRIED YOU."},
	"result.tubo_B": {
		"zh": "兔子：下一圈我跳得更高。",
		"en": "TUBO: I'LL JUMP HIGHER NEXT RUN."},
	"result.bitt_B": {
		"zh": "乌龟：先把壳稳住吧。",
		"en": "BITT: KEEP THE SHELL STEADY FIRST."},
	"result.tubo_D": {
		"zh": "兔子：刚才那下不算。",
		"en": "TUBO: THAT ONE DIDN'T COUNT."},
	"result.bitt_D": {
		"zh": "乌龟：算你头上。",
		"en": "BITT: IT COUNTS."},
	"feedback.guard_block": {
		"zh": "挡下了！",
		"en": "BLOCKED!"},
	"feedback.guard_precise": {
		"zh": "精准反击！+50",
		"en": "PERFECT GUARD! +50"},
	"feedback.catch_start": {
		"zh": "乌龟 冲过去接 兔子！",
		"en": "BITT GOES FOR TUBO!"},
	"feedback.catch_fail": {
		"zh": "没接住……",
		"en": "MISSED THE CATCH..."},
	"prompt.catch": {
		"zh": "SPACE 去救",
		"en": "SPACE TO RESCUE"},
}
