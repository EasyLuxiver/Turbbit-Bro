class_name Tuning
extends RefCounted
## 全项目数值集中在这里，改难度只改这个文件。
## 出处：GDD 05.6 物理宽限、05.5 氧气、08 事故、09 Showtime。
##
## 2026-11-11 核心体验指令：失衡按事件累积，不随待命时间增长。
## 2026-11-12 Phase G：五段曲线保留为姿态/动画刻度，但 daze_time 封顶在
## DAZE_CAP（3.6），不再有任何“攒到 9.5 就出事故”的第二套倒计时。
## 持续惩罚只有 BRO METER 三格：每次有效失误 +1 格，第三格播联合事故。
## 切换自由、失衡真实：夺回控制不清零，0.5 s 站稳后按 2.5/s 慢慢收。
const RELAX_TIME := 1.5
const SLIP_EDGE_TIME := 4.5
const SLIP_CRITICAL_TIME := 7.5
const SLIP_FALL_TIME := 9.5
const SINK_EDGE_TIME := 4.5
const SINK_CRITICAL_TIME := 7.5
const SINK_DANGER_TIME := 9.5

## 2026-11-12 Phase G 惩罚统一：BRO METER 三格是唯一的持续事故系统。
## daze_time 降级为短硬直/姿态动画，封顶在“明显趔趄、但绝不定罪”的区间，
## 永远到不了 SLIP_FALL_TIME / SINK_DANGER_TIME，也不会自己触发落水或翻肚皮。
## 事件仍然留下可见后果（撞一下滑、浪一下沉），但持续风险只记在 BRO METER。
const DAZE_CAP := 3.6

# 加速时失控时钟走得更快：同样的窗口会缩到约 3/4。
const SLIP_BOOST_CLOCK := 1.35
const SLIDE_PIXELS := 70.0
const BOOST_SPEED := 330.0

## 重新夺回控制权后的恢复速度：滑落/下沉计时按时间衰减，不瞬间清零。
## GDD 6.3「不允许通过切换直接重置滑落进度」。
## 连续控制满 0.5 s 才开始恢复：防止快速连点 SHIFT 把两人的风险一起磨掉；
## 恢复到稳的速率 2.5/s，从 EDGE 约需 1.8 s（含 0.5 s 站稳）。
const CONTROL_RECOVER_DELAY := 0.5
const CONTROL_RECOVER_RATE := 2.5

## ---- BRO BRAIN（2026-11-12 TBB-SHIFT-CORE-02）----
## 未被控制的角色会神游：3 s 分心、6 s 坐不住、9 s 恶作剧。
## 时间只是调试基线，不是事故倒计时；drift 封顶 12 s，永远到不了落水/翻肚皮。
## 恢复规则与失衡一致：连续受控 0.5 s 后才按 2.0/s 收回，快速 SHIFT 白嫖不到。
const DRIFT_CALM_END := 3.0
const DRIFT_DISTRACTED_END := 6.0
const DRIFT_RESTLESS_END := 9.0
const DRIFT_CAP := 12.0
const DRIFT_RECOVER_RATE := 2.0
## 兔子在 MISCHIEF 时最多偏离壳心 22 px；仍站在 92 px 宽的壳上，不会自己掉。
const DRIFT_MAX_OFFSET := 22.0
## P0-3：MISCHIEF 的兔子在低梁/海鸟前会站起来探头——看得见、切回即取消。
## 站立兔身 252–300 原本离低梁下缘 240 还有 12 px 余量；抬起 18 px 后
## 判定矩形（内缩 3 px）与梁重叠 3 px：会刮到，但只是失衡/硬直，不会落水。
const MISCHIEF_POSE_LIFT := 18.0

## ---- CORE-FEEL-08 P0-A：神游必须真的影响控制 ----
## 旧版只有位置偏移 / 速度 / 空中修正，玩家仍能“按了就好”。现在分心之后，
## 新按下的动作会晚半拍才执行（不是丢键、不是锁死）：
##   分心 3–6 s：+0.04～0.10 s（几乎只在数字上）
##   坐不住 6–9 s：+0.10～0.18 s（按跳跃能感觉到延迟）
##   恶作剧 9 s+：+0.18～0.26 s（明显慢半拍，但仍会执行）
## 延迟只作用于“按下沿”，按住不放不受影响；切换角色立即按各自的神游量算。
const DRIFT_REACT_MIN := 0.04
const DRIFT_REACT_RABBIT_MAX := 0.22
const DRIFT_REACT_TURTLE_MAX := 0.26
## 两角色各自的小动作：BITT 会自己趴一下（安全方向），TUBO 的壳会自己漂一点深度。
## 只在恶作剧且玩家没有垂直输入时发生；幅度小、会自己回来，不写 BRO METER。
const BITT_AUTOCROUCH_PERIOD := 2.6
const BITT_AUTOCROUCH_LEN := 0.35
## 壳自己漂的深度偏移上限（px）。比神游晃动 18 px 小，玩家按住 ↓ 立刻整个让位。
const TUBO_AUTODRIFT_PX := 14.0

# 氧气：GDD 建议 5 秒；P1 放宽到 6.5，但实测乌龟路线几乎无代价。
# PHASE-2：容量 6.0、耗 1.2/s、回 2.0/s，连续两次下潜/长隧道会真的肉疼；
# 仍保留三档提示（满/低/告急），不新增状态。
const OXYGEN_MAX := 6.5
const OXYGEN_LOW := 5.0
const OXYGEN_CRITICAL := 2.5
const OXYGEN_DRAIN := 1.1
const OXYGEN_RECOVER := 2.0
const OXYGEN_RECOVERED := 5.0

# PLAYFUL-04 §4：亲手喂到海藻的一小笔奖励。只是加分，不加惩罚、不加新状态。
const SNACK_SWITCH_BONUS := 30
# REBUILD-06 P4：食物争夺。
## 谁在操控谁吃：乌龟吃 = 原有 TURBO + 冷静；兔子吃 = 跳跃强化。
## 争抢提示从 320 px 开始（≈1.3 s 反应），两个角色都伸手，玩家用 SHIFT 决定归属。
const SNACK_INTEREST_PX := 320.0
## 兔子跳跃强化：初速 ×1.15（峰值高度 ≈ ×1.32），窗口与乌龟加速同长——
## 到该遭遇的障碍末尾 + 180 px，确保强化覆盖它本来要跳的那一组。
const RABBIT_SNACK_JUMP_SCALE := 1.30
const RABBIT_SNACK_TAIL := 180.0
# REBUILD-05 D2：主动把落水的兄弟接回壳上是一笔正向奖励（不是“补回扣分”）。
# 不切过去追接也不会多扣分——救援失败仍然只是原来的落水账。
const RESCUE_SWITCH_BONUS := 50

# 接人：横向 120 px，落点上下 -60～90，近距离直接吸附。
const PICKUP_DX := 120.0
const PICKUP_DY_MIN := -60.0
## 接住“正在上浮”的壳时放宽：BRO DIVE 里兔子要落在还没完全浮起的壳上。
## 巡航中的壳仍用 -60，否则兔子会在半空被提前吸上壳（越过低岩时会被拽进岩里）。
const PICKUP_DY_MIN_RISING := -120.0
## PLAYFUL-04：壳还在水下、但已经在往上游（刚松开 ↓）时，允许从更深的地方接。
## 接住之后走 carry 连续抬回壳上，不做瞬移；玩家仍然要自己起跳、自己下潜、自己松 ↓。
const PICKUP_DY_RISING_DEEP := -150.0
const PICKUP_DY_MAX := 90.0
const PICKUP_SNAP_DX := 70.0
## REBUILD-05 G8：提示环的“落壳走廊”。
## 收人判定仍用 PICKUP_DY_MIN(-60)：兔子一进这个范围就吸附。于是 pickup_window
## 只在那一帧为 true，而且同帧被消费——绿色提示环 16 ms 一闪，玩家根本看不见，
## stage1 的“接住时要显示窗口”也因此失效。显示比判定早一档：兔子已在下落、
## 壳在水面或正在上浮、横向对准时就从 -150 亮环，约 0.3 s 的可见提前量。
const PICKUP_HINT_DY_MIN := -150.0

# ---- 接住后的连续抬升（PLAYFUL-04 §1/§3：不许瞬移）----
## 接人/救援成功后，兔子从真实接住点连续移动到壳上落点；距离越远时间越长。
## 距离 ≤ CARRY_SNAP_DIST 时保持旧手感（直接吸附），普通跳不受影响。
const CARRY_SPEED := 520.0
const CARRY_MIN_TIME := 0.12
const CARRY_MAX_TIME := 0.42
const CARRY_SNAP_DIST := 24.0

# ---- REBUILD-05 G9：落壳时壳的重量反应 ----
## 制作人 2026-11-11 第 4 条：兔子跳回来乌龟“只是切换过来了，并没有做什么动作”。
## 兔子落回壳上/被接住/被救回时，壳往下沉一下再回弹：只改 `_draw_turtle` 的画法，
## turtle.position、判定框、接应距离都不读它。
## 日常落壳 7 px（每次跳都有，所以轻）；真接住 11 px；救回 14 px（最重的一拍）。
## 0.26 s 走完“下沉 → 回弹 → 归零”，和 G4/G5 的 0.34 s 兔子弹跳错开一点，不打架。
const SHELL_DIP_TIME := 0.26
const SHELL_DIP_ROUTINE := 7.0
const SHELL_DIP_CATCH := 11.0
const SHELL_DIP_RESCUE := 14.0

# ---- 非对称冲浪板（2026-11-11 制作人定稿方向）----
# 兔子站在龟壳上；乌龟不再接受玩家的上/下控深，受控时用自动浮力回到
# NEUTRAL_DEPTH，失控时才下沉，重新受控再自动上浮。保留惯性，不瞬移。
# 灰盒会临时置 false 做“改前”对照；正式流程为 true（2026-11-11 接入）。
static var SURFBOARD_PHYSICS := true

const NEUTRAL_DEPTH := 334.0
## 障碍/加速带数据仍按旧水面 300 摆放；开启后整体下移同样的量，
## 保持“角色与障碍”的相对几何和旧验证完全一致。
const WORLD_Y_SHIFT := NEUTRAL_DEPTH - 300.0

## 自动浮力：离巡航水深越远垂直速度越大，但有上下限和加速度，
## 所以是“漂回去”而不是瞬移。150 px/s 只用于紧急上浮量级。
const BUOY_RISE_SPEED := 150.0
const BUOY_SINK_SPEED := 90.0
const BUOY_ACCEL := 240.0
const BUOY_GAIN := 3.0

## 失控下沉：一失去意识就开始沉，但整体放慢到“看得见、来得及”。
## 35 → 40 → 55 → 80 px/s 四段：下沉门（墙底 334）要求壳沉 31 px 才让开，
## 第一段 25 px/s 时在 220 px/s 的巡航速度下要提前 1.2 s 换人才过得去，
## 实测全跑两场各有 2 个门在“墙前 300 px 换人”时差 8 px 撞墙；
## 提到 35 后同样提前量能沉到 365，门内仍只有 40/55 px/s，不会变成快沉。
## 惰性神游仍要 8.3 s 才碰危险深度 740，不会变成 3 秒倒计时。
const SINK_RELAX := 35.0
const SINK_SLOW := 40.0
const SINK_FAST := 55.0
const SINK_CRITICAL := 80.0
const SINK_RAMP := 90.0
## 兔子握权时乌龟失控：速度按段掉到 140 → 110 → 90 → 70，门里仍有 ~100 px/s。
const DAZE_SPEED_1 := 140.0
const DAZE_SPEED_2 := 110.0
const DAZE_SPEED_3 := 90.0
const DAZE_SPEED_4 := 70.0
## 水下暗流：兔子握着控制权、壳已经沉到巡航水深以下 76 px（y>410）时，
## 兔子层障碍的“水下部分”仍会把兔子撞下来（防止靠一直下沉绕过跳/趴）。
## 410 是兔子站着从岩石/横梁底下“擦过去”的临界深度；再深就是免费绕行。
## 画面上用一层半透明暗流柱标出来，不是隐形判定。
## 解除办法：把控制权交回乌龟，浮力会把壳抬回巡航水深。
const UNDERTOW_MARGIN := 76.0

## 接人：巡航水深 + 120 px 内都算够得着（新模型没有手动上浮，容错要宽）。
## 实测：兔子滞空 1.244 s，期间壳无人控制会沉 70～105 px；原来 70 px 的
## 余量正好卡在“跳一次就接不回来”，落地即落水的假难度就是这么来的。
const PICKUP_SURFACE_MARGIN := 120.0
## 氧气：以巡航水深为基准，再往下 80 px 才消耗。
## 新模型里兔子握着控制权时壳会自己沉，正常节拍下会沉到 400～430；
## 更低梁要趴 2 s，出口能到 550 上下。55 px 的余量让“过梁”本身就在抽氧，
## 自动驾驶实测在 49 s / 70 s 两次因过梁后的深位把氧气耗尽。
## 80 px（消耗线 414）之后才真的是“压得太深”。
const OXYGEN_DEPTH_MARGIN := 80.0

# ---- 2026-11-11 核心玩法重设计：待命不再恶化，失衡只来自错误 ----
# 兔子/乌龟的失衡值改用“秒”计：不再随待命时间增长，只在碰撞、错误着陆、
# 特殊动作失败时按事件加值；受控稳定操控（0.5 s 站稳后）按 2.5/s 收回。
## 一次碰撞加多少失衡。乌龟一次撞击 4.4；兔子 3.2，三次到落水。
const RABBIT_HIT_IMBALANCE := 3.2
const TURTLE_HIT_IMBALANCE := 4.4
## 乌龟主动垂直动作（2026-11-11 补充指令）：
## ↑ 带动整组向上跃起躲水下攻击；↓ 主动下潜过水下通道。
## 两者都不是事故、不加失衡；松开/通过后自动回巡航水深。
## 跃起：一次性上抛，1.6 s，落回巡航水深。
## 时长按“乌龟整个身体（96 宽）都要高过鲨鱼”反推：220 px/s 下
## 需要约 1.2 s 高于鲨鱼顶，1.0 s 的跃起只剩 0.2 s 容错，等于帧级输入。
## 峰值 2026-11-12 由 250 降到 160：BRO OLLIE 的高墙楣要能压住“骑在壳上”
## 的兔子（壳上 58、半身 24）。250 峰值时兔子已到 y=2，任何墙楣都压不到它，
## 兔子也就没有需要玩家补那一下的空间。160 时跃起到顶：龟心 174、壳 146～202、
## 兔身 92～140 —— 墙楣 80～120 只压兔子、窗口 120～230 只放壳。
## 鲨鱼复核：壳底 362 要让开上冲鲨顶 288 需抬 74，1.6 s 跃起的高位窗口约 1.13 s。
const LEAP_TIME := 1.6
const LEAP_HEIGHT := 160.0
const LEAP_COOLDOWN := 0.40
## REBUILD-06 P3：鲨鱼改成水下伏击。
## 注意坐标系：level_data 里写 254，装载时 WORLD_Y_SHIFT（+34）后才是运行时的
## 288～480（70 宽）。深潜时整条鱼往下挂 240 → 528～720：乌龟最深到下潜 150
## （壳底 512，内缩后 509），静止的鲨鱼与最深可达位置仍留 16 px 余量；
## 兔子落水也在 600 以上——这就是 P0“静止鲨鱼把壳无限顶住”的出口。
## 玩家靠近后先亮 0.55 s 预警（水面鳍/泡泡/“!”），0.12 s 冲到水面
## （288～480，巡航壳底 359 与下潜都躲不开，只能跃起），压 1.4 s 后退 0.55 s。
##
## 唤醒距离按“时间”给，不按固定像素：wake = 0.95 s × 本区基础速度 + 45。
## 45 是壳半宽，所以无论 Z1 220 还是 Z3 260，壳碰到鲨鱼都正好是预警后
## 0.95 s——三个区的起跳窗口因此重合成同一段，玩家学一次就通用。
## 起跳滞空的高位窗口是 0.235～1.365 s（内缩壳底 359 要让开上冲鲨顶 288
## 需抬高 71 px，sin > 0.444）；扣掉整段壳与鱼重叠的时间
## （(70+90)/v = 0.62～0.73 s），安全起跳窗口落在预警后约 0.20/0.25/0.31
## （Z3/Z2/Z1）到 0.72 s——跨区共用 0.31～0.72 s，宽约 0.40 s。
## 上冲 0.55～1.95 s 一定盖住“到达 0.95 s + 穿过 0.73 s”，所以不跃必撞。
const SHARK_WAKE_LEAD := 0.95
## 壳半宽：唤醒距离里要把“壳前沿已经进到多近”算进去。
const SHARK_SHELL_HALF := 45.0
const SHARK_TELEGRAPH_TIME := 0.55
const SHARK_RISE_TIME := 0.12
const SHARK_LUNGE_TIME := 1.40
const SHARK_RETREAT_TIME := 0.55
## 退回深水后至少 1.2 s 才会再次被靠近触发：停在原地不会“连拍”。
const SHARK_REARM_TIME := 1.20
## 运行时基础框 288～480 往下移 240 → 528～720（视口 900，仍在画面内）。
const SHARK_DOWN_OFFSET := 240.0
## BRO OLLIE 的兔子蹬踏：独立于普通跳（-630 -> 184 px）的一次较短的弹跳。
## 蹬踏点兔心在 163 左右，+119 px 后身体 20～68，刚好高过墙楣顶 80；
## 落回仍走 can_pickup（下坠 + 纵向窗口），不额外造“自动接人”。
const OLLIE_KICK_VELOCITY := -500.0
## 下潜：按住 ↓ 下到巡航水深以下 150 px；通过障碍后自动上浮。
## 深度要同时满足两条几何：龟壳顶让开水下障碍底（>28 px），
## 且壳上的兔子头顶也要让开（兔心在壳上 58、半身高 24 → 需要 >110 px）。
## 上浮 420 / 加速 1400 是“破水而出”的推力：障碍尾端到兔子落回之间
## 只有约 0.5 s，慢了就会“壳还在深处、兔子已经落地”。
const DIVE_DEPTH := 150.0
## 下沉 600 / 加速 6000：BRO DIVE 要在壳前沿进浮木前把壳顶从 306 沉到 410 以下，
## 旧的 480/2400 有 0.2 s 加速段、全程 0.32 s，加上换人延迟后起跳窗口只剩 ~6 px。
## 600/6000 把这一段压到 0.22 s（0.1 s 到满速），窗口回到 ~35 px。深度不变，
## 所以鲨鱼（身体到 480）仍能压住最深的下潜，下潜依然不是万能解。
const DIVE_SINK_SPEED := 600.0
const DIVE_RISE_SPEED := 420.0
const DIVE_ACCEL := 6000.0
## TBB-SHIFT-CORE-02 §5：浮木下通道要求壳顶从 306 沉到 410 以下（目标 484）。
## 600/6000 只解决“起步”：BUOY_GAIN=3.0 在接近 484 时按指数收速，最后 46 px
## 实测要 0.42 s（不是注释里的 0.22 s），于是第二段 SHIFT+↓ 只剩 0.15 s。
## 下潜单独用 5.0 的增益：同深度 0.42→0.28 s，第二段窗口回到 ~0.27 s；
## 深度与上浮都不变——鲨鱼（身体到 480）仍能压住最深的下潜。
const DIVE_GAIN := 5.0
## CORE-FEEL-07 P0-A：辅助下潜（浮木组合）的“压舱下潜”。
## 玩家起跳后 SHIFT 的那一刻才开始下潜；这段下沉时间就是 SHIFT 窗口的余量。
## 600/5.0 要到壳顶 410 以下需要 0.22 s，实测 SHIFT 只能晚到 0.25 s；
## 900/10/14000 把这段压到约 0.15 s，窗口回到人手级，同时深度上限不变
## （仍到 DIVE_DEPTH，鲨鱼该压住的还是压住）。只在辅助下潜时生效。
const DIVE_ASSIST_SINK_SPEED := 900.0
const DIVE_ASSIST_GAIN := 10.0
const DIVE_ASSIST_ACCEL := 14000.0
## CORE-FEEL-07 P0-A：浮木前的兔子起跳是“大跳”。
## 原来起跳提前量只有约 20–60 px（约 0.1–0.27 s）就能过木：跳早了兔子会落在木顶上。
## 高度 ×1.15（滞空 1.2→1.38 s，峰值 189→250 px）把提前量放宽到 120–260 px
## （0.54–1.18 s），起跳不再必须“卡着点早跳”；滞空变长也让乌龟有更多时间上浮接人。
## 幅度选 1.15 而不是 1.25：1.25 也能过，但兔子会飞得过高（实测净空 165 px），
## 1.15 的净空 107–115 px 仍然明显是“大跳”，又不会像被弹上去。
## 只对“前方最近障碍是浮木”的起跳生效，其他障碍仍是原来的跳。
const LOG_JUMP_HEIGHT_SCALE := 1.15
## 被水下攻击/墙拍中后整组短暂没入水下，氧气因此真正有意义。
const DUNK_TIME := 1.8
const DUNK_DEPTH := 115.0
## REFINE-06 P5：浪击把乌龟掀个肚皮朝天。纯表现计时（不动判定/碰撞/惩罚），
## 1.0 s 内在“翻过去 → 四肢乱蹬 → 自己翻回来”走完，不影响 1.8 s 的入水。
## 上限定 0.9 s：任务书要求“轻微喜剧化，但不要让动画拖得过长”。
const FLIP_TIME := 0.9
## 首次介绍提示的触发距离：组合障碍要求提前约 5 s 识别（220 px/s × 5 s = 1100）。
const PROMPT_RANGE := 1100.0
## REBUILD-05 G10：只有“眼前最近的那一组”过完（组尾再往后 80 px）才允许教下一种新类型。
## 否则 1100 px 内更远的障碍会把自己的动作教学盖上来——首次 BRO DIVE 逼近 log1 时，
## 底栏曾显示 1050 px 外鲨鱼的「SHIFT + ↑ 乌龟跃起」，和左上的「BRO DIVE 现在！」方向相反。
const LESSON_CLEAR_BEHIND := 80.0
## Showtime 不再瞬间回满氧气，只小幅回复。
const SHOWTIME_OXYGEN := 0.5

const STUN_TIME := 0.8

# ---- 2026-11-12 主动救援（Phase F）----
## 兔子落水后不再自动放回：乌龟继续巡航，兔子漂在壳前方，玩家切乌龟并下潜接住。
## 这段窗口是“玩家看到事故 → 决定下潜 → 壳沉到兔子下面”的时间，不是自动计时。
const RESCUE_ACTIVE_TIME := 3.2
## 旧值：把兔子直接摆到乌龟前方 520 px / 深度 460（TBB-SHIFT-CORE-02 §6 判定为
## “为了方便接人而直接设置位置”，已停用）。保留常量只为读旧数据/旧日志。
const RESCUE_RABBIT_AHEAD := 520.0
const RESCUE_RABBIT_DEPTH := 460.0

## ---- 真实落水（2026-11-12 TBB-SHIFT-CORE-02 §6）----
## 兔子落水不再瞬移：保持离壳瞬间的世界坐标、方向和速度继续下落，
## 穿过这条水线时才出水花、才开始救援计时（340 = 旧水面 300 + 40）。
const RESCUE_ENTRY_Y := 340.0
## 空中的重力与兔子跳跃一致，不另造一套；终端速度也沿用兔子自己的 950。
const RESCUE_FALL_GRAVITY := 1050.0
const RESCUE_FALL_MAX_VY := 950.0
## 进水后的横向阻力：落点就在世界坐标里停住，乌龟必须真的追上来。
## 起跳水平速度约 235 px/s，900 px/s² 下 0.26 s 停下、只多漂约 30 px。
const RESCUE_WATER_DRAG := 900.0
## 入水仍带着下落速度：兔子不会在水面停住，先扎进去再被水拖住。
## 保留 60% 入射速度、2200 px/s² 减速：满跳落水（约 730 px/s）多扎 43 px，
## 于是巡航壳顶（276）够不着水面上的兔子，接人必须真的下潜。
const RESCUE_ENTRY_KEEP_VY := 0.6
const RESCUE_WATER_VY_DRAG := 2200.0
## 兔子在水里下沉：12 px/s 在 3.2 s 内只沉 38 px，巡航高度就能一直兜住，
## 下潜变成可选项。45 px/s 时约 1.4 s 后兔子到 400 以下，巡航壳顶（276）
## 已经够不着，玩家必须真的下潜——水花仍发生在真实落点。
const RESCUE_RABBIT_SINK := 45.0
## 兔子落水后乌龟明显慢下来找人：这是事故代价（和 stun 的 140 px/s 同性质），
## 不是接人辅助——它不让兔子瞬移，也不替玩家下潜，只把“壳从兔子身上开过去”
## 的窗口从 0.9 s 拉到约 2 s，让提示看得见、来得及反应。
const RESCUE_SLOW_SPEED := 90.0

## 主动接人（水里/空中）的判定：位置 + 相对速度。
## 横向 140 比普通接人（120）略放大：壳会把兔子“兜”住，不要求像素级对齐。
## 纵向刻意不对称：兔子最多在壳上落点下方 40 px（再深就是壳没潜下去），
## 最多在上方 95 px（壳从兔子下方兜上来）。
## 巡航高度兔子在壳下 64 px，仍在框外——不靠框子把下潜变成可选。
const RESCUE_CATCH_DX := 140.0
const RESCUE_CATCH_DY_MIN := -95.0
const RESCUE_CATCH_DY_MAX := 40.0
## 轻微吸附只在这个更外一圈、且真实靠近时生效（160 px/s，方向朝壳）。
const RESCUE_SUCTION_DX := 165.0
const RESCUE_SUCTION_DY_MIN := -105.0
const RESCUE_SUCTION_DY_MAX := 50.0
const RESCUE_SUCTION_SPEED := 160.0
## 相对速度门：乌龟相对兔子没有在接近（兔子正被甩到身后）时不接。
const RESCUE_CLOSING_MIN := -60.0
## 接住后的宽限与失败后的“冲回壳上”时间（有限恢复，不是第二次事故）。
const RESCUE_GRACE_TIME := 1.2
const RESCUE_RETURN_TIME := 0.8
## PLAYFUL-04 §3：追赶结束后如果还差一段距离，用抬升把最后一段走完。
## 比接人的 0.42 s 略长，让“被冲回壳上”看得出方向，而不是一帧吸过去。
const RESCUE_RETURN_CARRY_MAX := 0.6
## 方案 2 原型：兔子被抛到空中，乌龟必须跃起接住。只用于对比测试；
## 兔子从 40 px 开始以 500 px/s² 下落，水面线按满潜壳顶附近 460 判定失败。
const RESCUE_AIR_TIME := 2.4
const RESCUE_AIR_AHEAD := 240.0
const RESCUE_AIR_START_Y := 40.0
const RESCUE_AIR_GRAVITY := 500.0
const RESCUE_AIR_WATER_Y := 460.0

## 事故演出：短、夸张、马上回到玩法。修复/救援 1.6 s，配 0.15 s 闪白。
const RESCUE_TIME := 1.6
const REPAIR_TIME := 1.6
const ACCIDENT_FLASH := 0.15
const EMERGENCY_TIME := 2.0
## CORE-FEEL-07 P0-B：同一障碍的“同一次事故”时间窗。两次碰撞落在这个窗口里
## （乌龟先撞浮木、壳被撞沉后壳上的兔子 1.33 s 后又擦到同一根木头）算同一件事，
## 只结算一次惩罚。1.5 s 的来历：正式关卡实测同组双撞间隔 1.334 s
## （refine06-p0-collision.json c3/c4），而不同障碍的最小间距 900 px ≈ 3.46 s，
## 事件又按 group 分开存，所以不会把两道障碍并成一次。
const ACCIDENT_JOINT_WINDOW := 1.5
## 事故后的同源保护：核心体验指令要求 3 s 内不出现同源连续事故。
## 2.5 只比 1.6 s 的救援多 0.9 s，兔子刚站回壳上就还在梁下，会立刻二连摔。
const HAZARD_COOLDOWN := 3.0
## 触礁修复后乌龟仍停在障碍里；冷却要覆盖 2 s 修复 + 约 2 s 反应/下潜。
const TURTLE_COOLDOWN := 4.0
const GRACE_TIME := 2.0
const SHOWTIME_TIME := 0.7
const SHOWTIME_COMBO := 3
## PHASE-FIX：Showtime 改为概率小奖励，不再用 0/3 计数器。
const SHOWTIME_CHANCE := 0.15
const SHOWTIME_CD := 18.0
