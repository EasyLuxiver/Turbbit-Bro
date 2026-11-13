extends Node
## 统一文本管理：简体中文 / English。
## 首次启动默认中文，玩家选择写入 user://settings.json 并立即生效。
## 所有玩家可见文本一律走这里的稳定 ID，不在场景里散落硬编码字符串。

signal language_changed(language: String)

const SETTINGS_PATH := "user://settings.json"
const LANGUAGES := ["zh", "en"]
const DEFAULT_LANGUAGE := "zh"

var language: String = DEFAULT_LANGUAGE


func _ready() -> void:
	_load()


func set_language(code: String) -> void:
	if code not in LANGUAGES:
		return
	language = code
	_save()
	language_changed.emit(language)


func toggle_language() -> void:
	set_language("en" if language == "zh" else "zh")


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


func _save() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"language": language}))
	file.close()


func settings_path_absolute() -> String:
	return ProjectSettings.globalize_path(SETTINGS_PATH)


# ---- 文本表 ----

const HAZARD_IDS := {
	"LOW ROCK": "hazard.low_rock",
	"LOW BEAM": "hazard.low_beam",
	"WIDE WAVE": "hazard.wide_wave",
	"LOW BIRD": "hazard.low_bird",
	"DOCK BEAM": "hazard.dock_beam",
	"SHARK": "hazard.shark",
	"REEF ARCH": "hazard.dive_gate",
	"FLOATING LOG": "hazard.floating_log",
	"SPACE WATER POP": "action.water_pop",
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
		"zh": "一个脑子。两身肌肉。零个脑细胞。",
		"en": "ONE MIND. TWO MUSCLES. ZERO BRAINCELLS."},
	"menu.stage": {
		"zh": "阶段 4 / 完整赛道 - 3 个区域",
		"en": "STAGE 4 / FULL TRACK - 3 ZONES"},
	"menu.best": {
		"zh": "最佳 {0} 秒   连击 {1}",
		"en": "BEST {0} s   STREAK {1}"},
	"menu.no_record": {"zh": "还没有纪录", "en": "NO RECORD YET"},
	# ---- 开场占位（Phase V P2-7）----
	"opening.ready": {"zh": "准备好，兄弟？", "en": "READY, BRO?"},
	"opening.hint": {
		"zh": "SHIFT 换人  ·  ↑ 行动  ·  ↓ 趴低 / 下潜",
		"en": "SHIFT SWAP  ·  ↑ ACT  ·  ↓ CROUCH / DIVE"},
	# CORE-FEEL-07 P1-C：第一次讲食物放在开场画面（没有任何障碍，不是高压链中间）。
	# 已经跳过开场的人，在食物接近时还会看到 HUD 的持续预告。
	"opening.food": {
		"zh": "能量海藻：操控乌龟吃 → 加速；操控兔子吃 → 下一跳更高；不吃也不扣分",
		"en": "SNACK: DRIVE THE TURTLE TO EAT = TURBO; DRIVE THE RABBIT = HIGHER JUMP; SKIPPING IS FREE"},
	"opening.skip": {"zh": "任意键跳过", "en": "PRESS ANY KEY TO SKIP"},
	"menu.start": {"zh": "回车  -  开始比赛", "en": "ENTER  -  START RACE"},
	"menu.settings": {"zh": "S  -  设置", "en": "S  -  SETTINGS"},
	"menu.quit": {"zh": "Q / ESC  -  退出游戏", "en": "Q / ESC  -  QUIT"},
	"menu.language": {"zh": "语言：简体中文", "en": "LANGUAGE: ENGLISH"},
	# 2026-11-11 补充指令：主菜单必须是可点的按钮，不再只靠快捷键。
	"menu.start_game": {"zh": "开始游戏", "en": "START GAME"},
	"menu.settings_button": {"zh": "设置", "en": "SETTINGS"},
	"menu.quit_button": {"zh": "退出游戏", "en": "QUIT"},
	"menu.keys": {
		"zh": "↑↓ 选择   Enter 确认   L 语言",
		"en": "↑↓ SELECT   ENTER CONFIRM   L LANGUAGE"},
	"quit.title": {"zh": "要退出游戏吗？", "en": "QUIT GAME?"},
	"quit.body": {
		"zh": "还没冲线，退出后本局进度不会保留。",
		"en": "The run is not finished. Progress will be lost."},
	"quit.yes": {"zh": "退出", "en": "QUIT"},
	"quit.no": {"zh": "取消", "en": "CANCEL"},
	# 只留开局必须知道的按键。F3 是调试层，不占玩家文本。
	"menu.hint": {
		"zh": "SHIFT 换人    ↑ 兔子跳 / 乌龟跃起    ↓ 兔子趴低 / 乌龟下潜",
		"en": "SHIFT transfer   ↑ RABBIT JUMP / TURTLE LEAP   ↓ RABBIT CROUCH / TURTLE DIVE"},

	# ---- 设置 ----
	"settings.title": {"zh": "设置", "en": "SETTINGS"},
	"settings.language": {
		"zh": "语言    L - 切换（当前：简体中文）",
		"en": "LANGUAGE    L - SWITCH (CURRENT: ENGLISH)"},
	"settings.back": {"zh": "ESC / S  -  返回", "en": "ESC / S  -  BACK"},
	"settings.back_button": {"zh": "返回", "en": "BACK"},
	"settings.keys": {
		"zh": "↑↓ 选择   Enter 确认   L 切换语言",
		"en": "↑↓ SELECT   ENTER CONFIRM   L SWITCH LANGUAGE"},
	"settings.note": {
		"zh": "语言只改变文字，不影响玩法、物理参数和比赛纪录。",
		"en": "Language only changes text. It does not affect gameplay, physics, or records."},

	# ---- HUD ----
	"hud.control": {"zh": "控制    {0}", "en": "CONTROL   {0}"},
	"who.rabbit": {"zh": "兔子", "en": "RABBIT"},
	"who.turtle": {"zh": "乌龟", "en": "TURTLE"},
	"hud.rabbit": {"zh": "兔子    {0}   抓地 {1}%", "en": "RABBIT    {0}   GRIP {1}%"},
	"hud.turtle": {"zh": "乌龟    {0}", "en": "TURTLE    {0}"},
	"hud.accident": {"zh": "事故    {0}", "en": "ACCIDENT  {0}"},
	"hud.time": {"zh": "时间    {0} 秒", "en": "TIME    {0} s"},
	"hud.speed": {"zh": "速度    {0}", "en": "SPEED   {0}"},
	"hud.cruise": {"zh": "巡航", "en": "CRUISE"},
	"hud.boost": {"zh": "加速", "en": "BOOST"},
	"hud.turbo": {"zh": "乌龟 TURBO！加速中", "en": "TURTLE TURBO!"},
	"hud.rabbit_boost": {
		"zh": "兔子！下一跳更高",
		"en": "RABBIT! HIGHER JUMP"},
	# CORE-FEEL-07 P1-C：接近食物时 HUD 同时预告两种效果，并明确“现在谁吃”。
	# {0} 是当前操控者的角色名（兔子 / 乌龟）。
	"hud.snack_ahead": {
		"zh": "海藻在前 · 当前：{0}会吃",
		"en": "SNACK AHEAD · {0} EATS NOW"},
	"hud.snack_cant": {
		"zh": "海藻在前 · 现在够不到（回巡航 / 落地再吃）",
		"en": "SNACK AHEAD · OUT OF REACH (CRUISE OR LAND TO EAT)"},
	"hud.snack_preview": {
		"zh": "兔子吃 ↑ 下一跳更高     乌龟吃 » 加速",
		"en": "RABBIT ↑ HIGHER JUMP     TURTLE » TURBO"},
	"hud.zone": {"zh": "区域 {0}/3  {1}", "en": "ZONE {0}/3  {1}"},
	"hud.progress": {
		"zh": "进度 {0}%   {1}/{2} 组",
		"en": "PROGRESS {0}%   {1}/{2} GROUPS"},
	"hud.air": {"zh": "氧气    {0} 秒   {1}", "en": "AIR      {0} s   {1}"},
	"hud.surface": {"zh": "水面 - 恢复中", "en": "SURFACE - RECOVERING"},
	"hud.emergency": {"zh": "紧急上浮", "en": "EMERGENCY ASCENT"},
	"hud.airborne": {"zh": "空中 - 不耗氧", "en": "AIRBORNE - NO DRAIN"},
	"hud.rescuing": {"zh": "救援中 {0}s - 潜到兔子下面", "en": "RESCUE {0}s - DIVE UNDER THE RABBIT"},
	"hud.rescuing_air": {"zh": "救援中 {0}s - 跃起接住", "en": "RESCUE {0}s - LEAP TO CATCH"},
	"hud.rescue_return": {"zh": "兔子回壳中 {0}s", "en": "RABBIT RETURNING {0}s"},
	"hud.underwater": {"zh": "水下 - 耗氧中", "en": "UNDERWATER - DRAINING"},
	"hud.undertow": {"zh": "暗流 - 壳沉太深，交给乌龟抬起来", "en": "UNDERTOW - TOO DEEP, GIVE IT TO THE TURTLE"},
	"hud.brotherhood": {"zh": "兄弟情    {0}", "en": "BROTHERHOOD  {0}"},
	"hud.clean": {"zh": "干净通过  {0}/{1}", "en": "CLEAN PASSES  {0}/{1}"},
	"hud.clean_best": {
		"zh": "干净通过  {0}/{1}   最佳 {2}",
		"en": "CLEAN PASSES  {0}/{1}   BEST {2}"},
	# 中断方式由 Showtime 横幅说明，这里只留剩余时间。
	"hud.showtime": {"zh": "SHOWTIME  {0} 秒", "en": "SHOWTIME  {0} s"},
	"hud.showtime_ready": {"zh": "SHOWTIME 就绪", "en": "SHOWTIME READY"},
	"hud.showtime_banner": {
		"zh": "操控乌龟 · SHIFT 中止",
		"en": "DRIVE TURTLE · SHIFT TO ABORT"},
	"hud.warn": {"zh": "{0}  {1} px  -  {2}", "en": "{0}  {1} px  -  {2}"},
	# 阶段 4 紧凑 HUD：控制权 + 各自状态 + 只在硬直/滑移时出现的晃动条。
	# Phase G：daze 已封顶且不再判事故，所以这里量的是“现在晃得多厉害”，
	# 不是“离掉下去还有多远”——旧文案“倾覆风险”会承诺一个不存在的结果。
	"hud.control_now": {"zh": "SHIFT   当前控制：{0}", "en": "SHIFT   CONTROL: {0}"},
	"hud.acting": {"zh": "操控 · {0}", "en": "DRIVING · {0}"},
	"hud.standby_stable": {"zh": "待命 · 稳定", "en": "STANDBY · STABLE"},
	"hud.standby_risk": {"zh": "待命 · 不稳", "en": "STANDBY · WOBBLY"},
	# 神游一旦开始就不再加“待命”前缀：行本身就在角色名下，前缀只是占宽度；
	# 省下来的位置留给后面的“具体后果”。
	"hud.drift_distracted": {"zh": "开始神游", "en": "DRIFTING"},
	"hud.drift_restless": {"zh": "坐不住了", "en": "FIDGETY"},
	"hud.drift_mischief": {"zh": "要惹麻烦", "en": "TROUBLE"},
	# CORE-FEEL-07 P1-D：只写“它现在在想别的”不够——用户试玩时看不出神游满值
	# 到底会怎样。状态行后面直接跟这一刻真正生效的代价（读控制器当前值）。
	"hud.drift_effect_rabbit": {
		"zh": "空中修正 {0}% · 身偏 {1}px",
		"en": "AIR {0}% · {1}px OFF"},
	"hud.drift_effect_turtle": {
		"zh": "巡航 {0}% · 壳晃 {1}px",
		"en": "CRUISE {0}% · BOB {1}px"},
	# 受控恢复中只报主代价（百分比），并把“回神中”放在数字前：恢复的核心读数
	# 是“数字在变好”，同时英文面板也塞得下（满值 + 两行状态时面积仍 <= 8%）。
	"hud.drift_recover_rabbit": {
		"zh": "回神中 · 空中修正 {0}%",
		"en": "RECOVER · AIR {0}%"},
	"hud.drift_recover_turtle": {
		"zh": "回神中 · 巡航 {0}%",
		"en": "RECOVER · CRUISE {0}%"},
	"hud.drift_recovering": {"zh": "回神中", "en": "RECOVER"},
	"hud.rabbit_risk": {"zh": "兔子晃动 {0}%", "en": "RABBIT WOBBLE {0}%"},
	"hud.turtle_risk": {"zh": "乌龟晃动 {0}%", "en": "TURTLE WOBBLE {0}%"},
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
	"hud.oxygen": {"zh": "氧气 {0}s", "en": "AIR {0}s"},
	"hud.oxygen_recovering": {"zh": "水面恢复中", "en": "SURFACE - RECOVERING"},
	"hud.oxygen_low": {"zh": "氧气偏低", "en": "AIR LOW"},
	"hud.oxygen_critical": {"zh": "氧气告急", "en": "AIR CRITICAL"},
	# 兄弟情和干净通过合并成一个三格计数。
	"hud.bond": {"zh": "默契 {0}/{1}", "en": "BRO PASS {0}/{1}"},
	"hud.showtime_t": {"zh": "SHOWTIME {0}s  剩", "en": "SHOWTIME {0}s LEFT"},
	# 阶段 4：BRO METER 是“失误槽”，和上面的默契（连招）不是一回事。
	# §七-9：hud.score 已移除——固定数字总分不再出现在玩家界面。
	"hud.bro_meter": {"zh": "BRO METER {0}/{1}", "en": "BRO METER {0}/{1}"},

	# ---- 角色与氧气状态 ----
	"state.RIDING": {"zh": "骑乘", "en": "RIDING"},
	"state.RECOVERING": {"zh": "恢复中", "en": "RECOVERING"},
	"state.RELAXED": {"zh": "神游", "en": "RELAXED"},
	"state.NO_POWER": {"zh": "无动力", "en": "NO POWER"},
	"state.TOO_DEEP": {"zh": "过深", "en": "TOO DEEP"},
	"state.SLIDING": {"zh": "正在滑落", "en": "SLIPPING"},
	"state.EDGE": {"zh": "快掉了", "en": "ABOUT TO FALL"},
	"state.STUNNED": {"zh": "眩晕", "en": "STUNNED"},
	"state.SHOWTIME": {"zh": "表演", "en": "SHOWTIME"},
	"state.AIRBORNE": {"zh": "空中", "en": "AIRBORNE"},
	"state.WAITING_CATCH": {"zh": "落水 · 等接应", "en": "IN WATER · WAIT"},
	"state.CRUISING": {"zh": "巡航", "en": "CRUISING"},
	"state.BOOSTING": {"zh": "加速", "en": "BOOSTING"},
	"state.SURFACING": {"zh": "上浮", "en": "SURFACING"},
	"state.DIVING": {"zh": "下潜", "en": "DIVING"},
	"state.CROUCHING": {"zh": "趴低", "en": "CROUCHING"},
	"state.GRIPPING": {"zh": "抓紧", "en": "GRIPPING"},
	"state.LEAPING": {"zh": "跃起", "en": "LEAPING"},
	"state.POPPING": {"zh": "拍水跃浪", "en": "WATER POP"},
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
	"accident.RABBIT_SLIP": {"zh": "兔子滑落", "en": "RABBIT SLIP"},
	"accident.RABBIT_WATER": {"zh": "兔子落水", "en": "RABBIT IN WATER"},
	"accident.RABBIT_AIR": {"zh": "兔子被抛到空中", "en": "RABBIT IN THE AIR"},
	"accident.OXYGEN_OUT": {"zh": "氧气耗尽", "en": "OXYGEN OUT"},
	"accident.TURTLE_REEF": {"zh": "乌龟撞礁 / 下沉", "en": "TURTLE REEF / SINK"},
	"accident.RABBIT_STUN": {"zh": "兔子硬直", "en": "RABBIT STUN"},

	# ---- 等级 ----
	"grade.S": {"zh": "绝对好兄弟！", "en": "ABSOLUTE BROS!"},
	"grade.A": {"zh": "肌肉兄弟！", "en": "MUSCLE BROTHERS!"},
	"grade.B": {"zh": "还算铁的哥们！", "en": "PRETTY GOOD BUDDIES!"},
	"grade.C": {"zh": "塑料兄弟情！", "en": "PLASTIC FRIENDSHIP!"},
	"grade.D": {"zh": "两个脑细胞，零配合！", "en": "TWO BRAIN CELLS, ZERO COORDINATION!"},

	# ---- 区域 ----
	"zone.1.name": {"zh": "阳光海岸", "en": "SUNNY COAST"},
	"zone.2.name": {"zh": "珊瑚乱流", "en": "CORAL CHAOS"},
	"zone.3.name": {"zh": "肌肉狂潮", "en": "MUSCLE MAYHEM"},
	"zone.1.lesson": {
		"zh": "区域 1 阳光海岸 - 学会跳、趴低、乌龟跃起和下潜",
		"en": "ZONE 1  SUNNY COAST - LEARN JUMP, CROUCH, TURTLE LEAP AND DIVE"},
	"zone.2.lesson": {
		"zh": "区域 2 珊瑚乱流 - 障碍换方向来，判断该换谁",
		"en": "ZONE 2  CORAL CHAOS - READ THE DIRECTION, PICK THE BRO"},
	"zone.3.lesson": {
		"zh": "区域 3 肌肉狂潮 - 龟兔各走一条路，别靠连点",
		"en": "ZONE 3  MUSCLE MAYHEM - TWO ROUTES, NO MASHING"},

	# ---- 障碍提示 ----
	"hazard.low_rock": {"zh": "低岩", "en": "LOW ROCK"},
	"hazard.low_beam": {"zh": "低梁", "en": "LOW BEAM"},
	"hazard.wide_wave": {"zh": "宽浪", "en": "WIDE WAVE"},
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
	"action.water_pop": {"zh": "拍水跃浪", "en": "SPACE WATER POP"},
	"action.leap": {"zh": "乌龟 ↑ 跃起", "en": "TURTLE ↑ LEAP"},
	"action.dive": {"zh": "乌龟 ↓ 下潜", "en": "TURTLE ↓ DIVE"},
	"action.jump_and_dive": {"zh": "兔子跳 + 乌龟潜", "en": "RABBIT JUMP + TURTLE DIVE"},
	"action.stay_high": {"zh": "保持水面", "en": "STAY HIGH"},
	"action.dive_through": {"zh": "换手让壳沉", "en": "HAND OVER TO SINK"},
	"action.take_rabbit": {"zh": "换给兔子", "en": "TAKE THE RABBIT"},
	"action.dont_jump": {"zh": "别跳", "en": "DON'T JUMP"},
	"action.jump_then_crouch": {"zh": "先跳再趴", "en": "JUMP THEN CROUCH"},
	"action.crouch_after_landing": {"zh": "落地后趴下", "en": "CROUCH AFTER LANDING"},
	# REBUILD-05 G19：教学文本以前只说“兔子按 ↓”，没说怎么变成兔子。
	# 新手在乌龟身上按 ↓ 会下潜（另一个动作），然后莫名其妙撞梁。
	# 需要换人的类型，第一次教学就把 SHIFT 点名出来。
	"lesson.rock": {
		"zh": "跳过岩石 - 按 SHIFT 换兔子，再按 ↑ 起跳",
		"en": "JUMP THE ROCK - SHIFT TO THE RABBIT, THEN ↑"},
	"lesson.beam": {
		"zh": "趴低过梁 - 按 SHIFT 换兔子，再按 ↓ 趴低",
		"en": "CROUCH UNDER THE BEAM - SHIFT TO THE RABBIT, THEN ↓"},
	"lesson.wave": {
		"zh": "宽浪 - 按 SHIFT 换成乌龟，按 SPACE 拍水跃浪",
		"en": "WIDE WAVE - SHIFT TO THE TURTLE, PRESS SPACE TO POP"},
	"lesson.reef": {
		"zh": "暗礁在深处 - 贴着水面走",
		"en": "REEFS SIT DEEP - STAY ON THE SURFACE"},
	"lesson.wall": {
		"zh": "长墙 - 按 SHIFT 把控制交给兔子，壳会自己沉下去",
		"en": "LONG WALL - SHIFT TO THE RABBIT AND THE SHELL SINKS"},
	"lesson.sink_gate": {
		"zh": "下沉门 - 兔子掌权时龟壳会自己沉下去",
		"en": "SINK GATE - THE SHELL SINKS WHILE THE RABBIT IS IN CHARGE"},
	"lesson.airbar": {
		"zh": "低杆 - 让兔子留在龟壳上",
		"en": "LOW BAR - KEEP THE RABBIT ON THE SHELL"},
	"lesson.combo": {
		"zh": "连续三次干净通过会触发 SHOWTIME",
		"en": "THREE CLEAN PASSES TRIGGER SHOWTIME"},
	"lesson.bird": {
		"zh": "低飞海鸟 - 按 SHIFT 换兔子按 ↓ 趴低，乌龟照常巡航",
		"en": "LOW BIRD - SHIFT TO THE RABBIT AND PRESS ↓, THE SHELL KEEPS CRUISING"},
	"lesson.dock_beam": {
		"zh": "码头横梁 - 按 SHIFT 换兔子趴低过，龟壳不受影响",
		"en": "DOCK BEAM - SHIFT TO THE RABBIT AND CROUCH, THE SHELL IS UNAFFECTED"},
	"lesson.gate": {
		"zh": "水下拱岩 - 按 SHIFT 换乌龟，按住 ↓ 潜过去",
		"en": "REEF ARCH - SHIFT TO THE TURTLE AND HOLD ↓"},
	"lesson.shark": {
		"zh": "鲨鱼从下面冲上来 - 按 SHIFT 换乌龟，再按 ↑ 跃起",
		"en": "SHARK FROM BELOW - SHIFT TO THE TURTLE AND PRESS ↑"},
	# REBUILD-05 G2：第三步以前没有说法——越过木尾要松手，否则壳停在水下、
	# 兔子落壳擦水。教学只加这一句，和 HUD 的“松开 ↓”提示用同一套说法。
	"lesson.log": {
		"zh": "浮木 - 兔子先跳，按 SHIFT 换乌龟下潜；越过木尾松开 ↓ 上浮接人",
		"en": "FLOATING LOG - JUMP, SHIFT, DIVE. PAST THE LOG, RELEASE ↓ TO CATCH."},

	# REBUILD-05 G19：A 类障碍（低梁/海鸟/岩檐）只在兔子的那一层判定。
	# 玩家当时要是在操控乌龟，兔子只是“搭车”，根本没法躲——但画面上看起来
	# 就是“我什么都没按就撞了”。第一次发生时给一句换人，一局只说一次。
	"hint.take_rabbit": {
		"zh": "按 SHIFT 换兔子 - 这个只有兔子能躲",
		"en": "PRESS SHIFT FOR THE RABBIT - ONLY IT CAN DODGE THIS"},

	# ---- 场景文字与提示 ----
	"world.zone_header": {"zh": "{0}  {1}", "en": "{0}  {1}"},
	"world.danger_depth": {"zh": "危险深度", "en": "DANGER DEPTH"},
	"world.finish": {"zh": "终点", "en": "FINISH"},
	"world.paused": {"zh": "已暂停", "en": "PAUSED"},
	"pause.title": {"zh": "已暂停", "en": "PAUSED"},
	"pause.breath": {"zh": "Take a breath, bro.", "en": "Take a breath, bro."},
	"pause.resume": {"zh": "继续游戏", "en": "RESUME"},
	"pause.restart": {"zh": "重新开始", "en": "RESTART"},
	"pause.menu": {"zh": "返回主菜单", "en": "MAIN MENU"},
	"pause.keys": {
		"zh": "ESC 继续   R 重开   M 主菜单",
		"en": "ESC RESUME   R RESTART   M MENU"},
	# CORE-FEEL-07 P1-C：暂停是玩家唯一能停下来读规则的地方，食物规则写在暂停页。
	"pause.food": {
		"zh": "能量海藻：SHIFT 决定谁吃 — 乌龟吃 = 加速，兔子吃 = 下一跳更高；不吃不扣分",
		"en": "SNACK: SHIFT PICKS WHO EATS - TURTLE = TURBO, RABBIT = HIGHER JUMP; SKIPPING COSTS NOTHING"},
	"world.pause_hint": {
		"zh": "ESC 继续   SHIFT 换人   R 重开   M 主菜单",
		"en": "ESC RESUME   SHIFT TRANSFER   R RESTART   M MENU"},
	"world.boost": {"zh": "加速带", "en": "BOOST"},
	"world.snack": {"zh": "海藻", "en": "SNACK"},
	"world.eat_now": {"zh": "吃", "en": "EAT"},
	"world.grip": {"zh": "{0}   抓地 {1}%", "en": "{0}  GRIP {1}%"},
	"center.zone": {"zh": "区域 {0}  {1}", "en": "ZONE {0}  {1}"},
	"center.showtime": {"zh": "SHOWTIME！", "en": "SHOWTIME!"},
	"center.brotherhood": {"zh": "兄弟情！", "en": "BROTHERHOOD!"},
	"center.shows_over": {"zh": "表演结束！", "en": "SHOW'S OVER!"},
	"center.finish": {"zh": "冲线！  {0}  {1}", "en": "FINISH!  {0}  {1}"},
	# CORE-FEEL-07D：满格是“命运绑定 → 两个人一起遭殃”，不是“两个人都有错”。
	# 旧文案“联合惩罚”会让只失误一次的玩家觉得被冤枉，改说后果、不指认谁犯错。
	"center.bro_full": {
		"zh": "BRO METER 满 —— 一起翻船！",
		"en": "BRO METER FULL - BOTH CAPSIZED!"},
	"center.bro_recover": {
		"zh": "重新出发！",
		"en": "BACK IN ACTION!"},
	"hint.air_low": {"zh": "氧气偏低 - 换回乌龟就上浮", "en": "AIR LOW - TAKE THE TURTLE BACK"},
	"hint.air_critical": {"zh": "氧气告急 - 马上换乌龟", "en": "AIR CRITICAL - TURTLE NOW"},
	"hint.clean_pass": {"zh": "干净通过  {0}/{1}", "en": "CLEAN PASS  {0}/{1}"},
	"hint.pickup": {"zh": "接住了！", "en": "PICKUP!"},
	"hint.boost": {
		"zh": "加速带 - 操控乌龟时自动提速",
		"en": "BOOST LANE - AUTOMATIC WHILE DRIVING THE TURTLE"},
	"hint.snack": {
		"zh": "能量海藻 - 操控谁谁就吃：乌龟吃到加速，兔子吃到下一跳更高；不吃没惩罚",
		"en": "SNACK - WHOEVER YOU DRIVE EATS IT: TURTLE = TURBO, RABBIT = HIGHER JUMP; SKIPPING COSTS NOTHING"},
	"hint.wave_hit": {
		"zh": "壳翻了 - 稳住，等它自己翻回来",
		"en": "SHELL FLIPPED - STEADY, IT ROLLS BACK"},
	# CORE-FEEL-07C：乌龟的失败提示要说“这个障碍该做什么”，不再一律喊换人。
	"hint.shark_hit": {
		"zh": "鲨鱼只咬壳 - 按 ↑ 跃起躲开",
		"en": "THE SHARK BITES THE SHELL - PRESS ↑ TO LEAP"},
	"hint.gate_hit": {
		"zh": "拱岩：按住 ↓ 潜到它下面再松",
		"en": "REEF ARCH: HOLD ↓ UNTIL YOU'RE UNDER IT"},
	"hint.wall_hit": {
		"zh": "高墙：乌龟先 ↑ 跃起，兔子再蹬一下",
		"en": "HIGH WALL: ↑ LEAP, THEN KICK WITH THE RABBIT"},

	# ---- 阶段 4：干净通过 / BRO PASS / 首次教学 ----
	"feedback.clean": {"zh": "干净通过！", "en": "CLEAN!"},
	"feedback.bro_pass": {"zh": "兄弟！漂亮！", "en": "BRO PASS!"},
	"feedback.bro_dive": {"zh": "BRO DIVE！", "en": "BRO DIVE!"},
	"feedback.bro_ollie": {"zh": "BRO OLLIE！", "en": "BRO OLLIE!"},
	"feedback.bro_combo": {"zh": "BRO COMBO！", "en": "BRO COMBO!"},
	"feedback.pop": {"zh": "拍水跃浪！", "en": "WATER POP!"},
	"feedback.leap": {"zh": "跃起！", "en": "LEAP!"},
	"feedback.turbo": {"zh": "TURBO！ 吞下去了！", "en": "TURBO! GULP!"},
	# REBUILD-06 P4：兔子吃到海藻的专属反馈（跳跃强化）。
	"feedback.snack_rabbit": {
		"zh": "兔子吃了！ 下一跳更高！",
		"en": "RABBIT ATE! HIGHER JUMP!"},
	# PLAYFUL-04 §4：切到乌龟亲手喂到的正向反馈（不切也照样吃，只是没这一下）。
	"feedback.turbo_switch": {
		"zh": "TURBO！亲手喂到！乌龟很满足！",
		"en": "TURBO! HAND-FED! TURTLE LOVES IT!"},
	"feedback.wave_hit": {"zh": "壳被浪掀翻了！", "en": "WAVE HIT - SHELL FLIPPED!"},
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
		"zh": "浮木：兔子起跳后 SHIFT 给乌龟，它会自动下潜、过木自动上浮",
		"en": "LOG: JUMP, THEN SHIFT - THE SHELL DIVES AND SURFACES BY ITSELF"},
	"hint.log_jump": {
		"zh": "浮木：先按 ↑ 让兔子起跳，再 SHIFT 给乌龟",
		"en": "LOG: PRESS ↑ TO JUMP FIRST, THEN SHIFT TO THE TURTLE"},
	# REBUILD-05 G3：按住 ↓ 不放导致的擦水（B3 实测）。和 G2 的“松开 ↓”提示同一套说法。
	"hint.dive_deep": {
		"zh": "壳停得太深 - 浮木组合请先 ↑ 起跳再 SHIFT，下潜和上浮会自动完成",
		"en": "SHELL TOO DEEP - FOR LOGS: ↑ JUMP THEN SHIFT; DIVE AND SURFACE ARE AUTOMATIC"},
	# REBUILD-05 G6：会动的障碍首次出现时的一区一次提示。
	"hint.motion": {
		"zh": "这组会动 - 看准空隙再上",
		"en": "THIS ONE MOVES - GO THROUGH THE GAP"},
	"feedback.rescue_ok": {"zh": "接住了！兄弟！", "en": "CAUGHT! BRO!"},
	"feedback.rescue_reunion": {
		"zh": "兄弟回来了！右边这口气补上了",
		"en": "BRO'S BACK! BOTH OF YOU CALM DOWN"},
	"feedback.rescue_miss": {
		"zh": "没接住……兔子被冲回壳上",
		"en": "MISSED... RABBIT WASHED BACK"},
	# REFINE-06 P1：换手的“开始收心”和“真的回过神”分开报，
	# 玩家能看出 SHIFT 立刻有用、但恢复需要持续受控。
	"feedback.shift_take": {
		"zh": "换手 - {0}开始收心",
		"en": "SWITCH - {0} RECOVERING"},
	"feedback.drift_back": {
		"zh": "{0}回过神了",
		"en": "{0} IS BACK"},
	# CORE-FEEL-07 P1-D：越过 6 s / 9 s 阈值时报警一次，并写出此刻的具体代价。
	# 只报“升级”，不报降级（恢复由 drift_back 负责），快速换手不会连刷。
	"feedback.drift_warn_restless": {
		"zh": "{0}坐不住了：{1}",
		"en": "{0} IS FIDGETY: {1}"},
	"feedback.drift_warn_mischief": {
		"zh": "{0}要惹麻烦了：{1}",
		"en": "{0} IS ACTING UP: {1}"},
	"prompt.jump": {"zh": "↑ 跳跃", "en": "↑ JUMP"},
	"prompt.crouch": {"zh": "↓ 趴低", "en": "↓ CROUCH"},
	"prompt.pop": {
		"zh": "SHIFT + SPACE 拍水跃浪",
		"en": "SHIFT + SPACE WATER POP"},
	"prompt.rescue_shift": {
		"zh": "SHIFT 乌龟 → 按住 ↓ 潜下去接住兔子",
		"en": "SHIFT TURTLE → HOLD ↓ TO CATCH"},
	"prompt.rescue_dive": {
		"zh": "按住 ↓ 潜下去接住兔子",
		"en": "HOLD ↓ TO CATCH THE RABBIT"},
	"prompt.rescue_leap_shift": {
		"zh": "SHIFT 乌龟 → 按 ↑ 跃起接住兔子",
		"en": "SHIFT TURTLE → ↑ TO CATCH"},
	"prompt.rescue_leap": {
		"zh": "按 ↑ 跃起接住兔子",
		"en": "PRESS ↑ TO CATCH THE RABBIT"},
	"prompt.leap": {"zh": "SHIFT + ↑ 乌龟跃起", "en": "SHIFT + ↑ TURTLE LEAP"},
	"prompt.dive": {"zh": "SHIFT + ↓ 按住下潜", "en": "SHIFT + HOLD ↓ TURTLE DIVE"},
	"prompt.combo": {
		"zh": "↑ 兔子跳 → SHIFT 乌龟 → ↓ 潜",
		"en": "↑ RABBIT JUMP → SHIFT → ↓ TURTLE DIVE"},
	"prompt.ollie": {
		"zh": "SHIFT + ↑ 乌龟跃起 → SHIFT 兔子 → ↑ 蹬踏",
		"en": "SHIFT + ↑ LEAP → SHIFT RABBIT → ↑ KICK"},
	# REBUILD-05 F：首次教学提示要看“你现在控的是谁”。玩家先按过 SHIFT 再遇到
	# 第一组时，旧文案会让他按错人（比如已控乌龟，还叫他“SHIFT + ↓”）。
	# 兔子专属的障碍：提示先换回兔子；乌龟专属的：去掉多余的 SHIFT。
	"prompt.jump_from_turtle": {
		"zh": "SHIFT 回兔子 → ↑ 跳跃",
		"en": "SHIFT TO RABBIT → ↑ JUMP"},
	"prompt.crouch_from_turtle": {
		"zh": "SHIFT 回兔子 → ↓ 趴低",
		"en": "SHIFT TO RABBIT → ↓ CROUCH"},
	"prompt.leap_on_turtle": {
		"zh": "按 ↑ 乌龟跃起",
		"en": "PRESS ↑ TURTLE LEAP"},
	"prompt.dive_on_turtle": {
		"zh": "按住 ↓ 下潜",
		"en": "HOLD ↓ DIVE"},
	"prompt.combo_from_turtle": {
		"zh": "SHIFT 兔子 → ↑ 跳 → SHIFT 乌龟 → ↓ 潜",
		"en": "SHIFT RABBIT → ↑ JUMP → SHIFT → ↓ DIVE"},
	"prompt.ollie_on_turtle": {
		"zh": "↑ 跃起 → SHIFT 兔子 → ↑ 蹬踏",
		"en": "↑ LEAP → SHIFT RABBIT → ↑ KICK"},

	# ---- 大字反馈 ----
	"banner.slip": {"zh": "摔了！兔子没抓住", "en": "WIPEOUT! RABBIT LOST GRIP"},
	"banner.water": {"zh": "扑通！兔子落水", "en": "SPLASH! RABBIT IN THE WATER"},
	"banner.stun": {"zh": "咚！兔子被撞晕", "en": "BONK! RABBIT IS STUNNED"},
	"banner.hit": {"zh": "哎哟！兔子撞到了", "en": "OUCH! RABBIT HIT SOMETHING"},
	"banner.reef": {"zh": "引擎故障！乌龟撞上暗礁", "en": "ENGINE FAILURE! TURTLE HIT THE REEF"},
	"banner.oxygen": {"zh": "没气了！紧急上浮", "en": "NO AIR! EMERGENCY ASCENT"},
	"banner.pickup": {"zh": "好接！", "en": "NICE SAVE!"},
	"banner.rescue": {"zh": "获救", "en": "RESCUED"},

	# ---- 结算 ----
	"result.title": {"zh": "比赛完成", "en": "RACE COMPLETE"},
	"result.time": {"zh": "比赛时间              {0} 秒", "en": "RACE TIME              {0} s"},
	"result.casualties": {"zh": "兔子伤亡              {0}", "en": "RABBIT CASUALTIES      {0}"},
	"result.engine": {"zh": "乌龟故障              {0}", "en": "TURTLE ENGINE FAILURE  {0}"},
	"result.coop": {"zh": "完美合作              {0}", "en": "PERFECT COOPERATION    {0}"},
	"result.showtime": {"zh": "表演次数              {0}", "en": "SHOWTIME               {0}"},
	"result.streak": {"zh": "完美连击              {0}", "en": "PERFECT STREAK         {0}"},
	"result.accidents": {"zh": "事故总数              {0}", "en": "TOTAL ACCIDENTS        {0}"},
	"result.clean": {"zh": "干净通过              {0}", "en": "CLEAN PASSES           {0}"},
	"result.combos": {"zh": "连招                  {0}", "en": "BRO COMBOS             {0}"},
	"result.rescues": {"zh": "救援成功              {0}", "en": "RESCUE SAVES           {0}"},
	# G16：结算页记住“亲手喂到”这件事——它是换人去照顾乌龟的动机，值一次记录。
	"result.snacks": {"zh": "亲手喂到              {0}", "en": "HAND-FED SNACKS        {0}"},
	# G17：结算页的“下次试试”。只给一条，按 next_try_key() 的优先级挑。
	"result.try_combo": {
		"zh": "下次试试：兔子跳起来后按 SHIFT 让乌龟下潜（BRO DIVE）",
		"en": "NEXT TRY: JUMP, THEN SHIFT THE TURTLE DOWN (BRO DIVE)"},
	"result.try_snack": {
		"zh": "下次试试：按 SHIFT 换到乌龟，亲手把海藻喂给它",
		"en": "NEXT TRY: SHIFT TO THE TURTLE AND FEED IT THE SEAWEED"},
	"result.try_rescue": {
		"zh": "下次试试：兔子落水时按 SHIFT 换乌龟，按住 ↓ 追下去接它",
		"en": "NEXT TRY: WHEN THE RABBIT FALLS IN, SHIFT AND HOLD ↓ TO CATCH"},
	"result.mistakes": {"zh": "失误                  {0}", "en": "MISTAKES               {0}"},
	"result.joint": {"zh": "翻船次数              {0}", "en": "CAPSIZES               {0}"},
	"result.best": {
		"zh": "最佳时间 {0}   最低事故 {1}   最长连击 {2}",
		"en": "BEST TIME  {0}   BEST ACCIDENTS  {1}   BEST STREAK  {2}"},
	"result.new_time": {"zh": "新最佳时间！", "en": "NEW BEST TIME!"},
	"result.new_streak": {"zh": "新最长连击！", "en": "NEW BEST STREAK!"},
	"result.again": {"zh": "再玩一次", "en": "PLAY AGAIN"},
	"result.menu": {"zh": "返回主菜单", "en": "MAIN MENU"},
	"result.retry": {
		"zh": "R  -  重开        M  -  主菜单        Enter  -  选中的按钮",
		"en": "R  -  RETRY    M  -  MAIN MENU    ENTER  -  SELECTED BUTTON"},
}
