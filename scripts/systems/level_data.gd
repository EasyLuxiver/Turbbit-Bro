class_name LevelData
extends RefCounted
## 阶段 3 赛道数据：三个区域、障碍组、加速段、教学提示。
## 所有坐标以世界像素为单位；SURFACE_Y=300，危险深度=740。
## 阶段 2 的前 8 组位置在 Phase V 之前保持不变；Phase V（P1-4）重排了 Zone 1
## 的开场站位（见 GROUPS 上方注释），所有自检/回归一律按组名取位置，不写死 x。

const SURFACE_Y := 300.0
## 正式赛程从这里出发（race.gd 的 reset 也读它）。Zone 1 的“空档”要从这里量，
## 不是从 0 量——0～400 是起跑线前的布景，玩家不经过。
const RACE_START_X := 400.0
## FEEL-37：Z3 末段四次后缀前移（-500 / -600 / -600 / -500），把 4 个 4 s 组合
## 压成 2 s 级紧接力；再为 Z2 提前换人把 gate4 起后缀前移 350；终点同步前移 2550，尾段留白与调整前一致（5.5 s）。
const WORLD_END := 58850.0
const COMBO_GAP := 1200.0
const PAR_TIME := 300.0

const ZONES := [
	{
		"id": 1, "name": "SUNNY COAST", "start": 0.0, "end": 10000.0,
		"base_speed": 220.0, "grade_color": Color(0.45, 0.95, 1.0),
		"sky": Color(0.55, 0.80, 0.92), "water": Color(0.06, 0.42, 0.55),
		"deep": Color(0.03, 0.28, 0.40), "seabed": Color(0.75, 0.68, 0.45),
		"lesson": "ZONE 1  SUNNY COAST - LEARN THE WATER",
	},
	{
		"id": 2, "name": "DOCK CHAOS", "start": 10000.0, "end": 34000.0,
		"base_speed": 240.0, "grade_color": Color(1.0, 0.55, 0.65),
		"sky": Color(0.46, 0.73, 0.88), "water": Color(0.10, 0.43, 0.52),
		"deep": Color(0.05, 0.23, 0.36), "seabed": Color(0.62, 0.48, 0.42),
		"lesson": "ZONE 2  DOCK CHAOS - NETS, EELS, SLUICES: PICK THE RIGHT BRO",
	},
	{
		"id": 3, "name": "MUSCLE MAYHEM", "start": 34000.0, "end": WORLD_END,
		"base_speed": 260.0, "grade_color": Color(1.0, 0.80, 0.35),
		"sky": Color(0.93, 0.58, 0.38), "water": Color(0.16, 0.36, 0.50),
		"deep": Color(0.08, 0.18, 0.32), "seabed": Color(0.52, 0.40, 0.32),
		"lesson": "ZONE 3  MUSCLE MAYHEM - NO MORE WARM-UPS",
	},
]

# ---- 2026-11-11 障碍空间重映射 ----
# 不再按旧名词分“岩石 / 低梁 / 浪墙”，按“占哪一层空间、谁来处理”分五类：
#   LOW_BEAM             A 兔子层·趴低：只压站立兔（252～300），龟壳巡航高度（306～362）不动
#   LOW_BIRD             A 兔子层·趴低（2026-11-12 重做）：海鸟不再是“一块低空横带”，
#                        而是俯冲攻击——主判定带（世界 234～274）压站立兔，上方再加一段
#                        俯冲空域（世界 130～234）覆盖翅膀扫过的空间。所以：趴低（284～308）
#                        干净；乌龟下潜（兔子 402～450）干净但要耗氧；跳（峰值兔身 63～111）
#                        和乌龟跃起（兔身 92～140）都会撞进俯冲路径——“跳过去”不再和趴低等价。
#                        画法见 race.gd::_draw_bird：预警→下潜→攻击→拉起是连续轨迹。
#   SURFACE_ROCK         A 兔子层·跳跃：只压兔子；岩檐 296 让开龟壳顶 306 十像素
#   SHARK                C 水下攻击：整条身体从海底冲到水面（Phase N 后 288～480）。下潜最深时壳顶 456
#                        仍在 480 以上，所以躲不开；必须乌龟跃起 160 px 把整组带高。
#   DIVE_GATE            D 水下通道：压巡航龟壳；乌龟下潜 150 px 后兔头顶 402 让开下沿 384
#   FLOATING_LOG         B 组合：上沿 192 压跃起后的壳底 202（只跃起也过不去）、下沿 410
#                        压巡航龟壳与深潜兔；兔子跳上沿、乌龟潜下沿，两条路都要走
#                        上沿从 180 抬到 192、宽度 50→32：跳跃变矮后“兔子在空中
#                        且高于上沿”的窗口只有 0.21~0.99 s，而下潜从起步到壳顶低于
#                        410 需要 ~0.22 s（DIVE_ACCEL 有加速段）。180+50 宽时两者
#                        只剩 9 px 起跳窗口，抬 12 px、收窄 18 px 后回到 ~35 px。
# 每组只记 x 与宽度；y 与高度来自类型模板，判定框和画法出自同一份数据。
# ---- 2026-11-12 M 门槛①：下潜不再是“只潜就能过”的万能解 ----
# 兔子层障碍原本只占据水面上方（岩檐 296、梁底 274），乌龟一下潜整组就沉到障碍
# 下方，于是“按住 ↓”能绕过 30 组兔子层障碍。这里给岩和梁各加一段水下阻挡
# （关卡 y 368～418 → 世界 402～452）：
#   下潜后兔子身体 402～450（壳心下潜到 484，兔身 -58 再往上 24），正好被压住；
#   巡航壳 306～362 从它上方过，下潜壳 456～512 从它下方过——壳永远不穿模，
#   视觉上仍是“壳从两层障碍之间的缝里过”，只是兔子不能靠下潜把头压进水下。
# 判定路径没变：A 类仍只判兔子、趴低仍按状态直接放行；跳跃/跃起仍从上方过。
# LOW_BIRD 不加：海鸟只在水面上，下潜躲鸟在物理上说得通，保留这条合法路线。
const ANTI_DIVE_Y := 368.0
const ANTI_DIVE_H := 50.0

const KIND_SPEC := {
	"LOW_BIRD": {"y": 200.0, "h": 40.0, "w": 120.0,
		"hint": "DIVING GULL", "action": "CROUCH DOWN",
		"lesson": "DIVING GULL - CROUCH, DON'T JUMP INTO IT"},
	"LOW_BEAM": {"y": 140.0, "h": 100.0, "w": 170.0,
		"hint": "DOCK BEAM", "action": "CROUCH DOWN",
		"lesson": "DOCK BEAM - CROUCH, THE SHELL KEEPS CRUISING"},
	"SURFACE_ROCK": {"y": 220.0, "h": 42.0, "w": 120.0,
		"hint": "LOW ROCK", "action": "JUMP OVER",
		"lesson": "JUMP THE ROCK - THE TURTLE PASSES UNDER"},
	# Phase N（2026-11-12）：tolerance 细扫证实 shark 的真实起跳窗只有 0.404 s
	# （不是报告里的 0.154 s——那是 40 px 网格一档）。制作人要求 ≥0.5 s，
	# 于是把鲨鱼上沿下移 14 px（世界 274→288，仍在海面以上 12 px）：
	# 跃起需要抬高的“净空”从 85 px 降到 71 px，窗口按实测升到 ~0.51 s，
	# 加速 15% 后 ~0.59 s。只动鲨鱼这一类，不碰跃起参数、不碰其它障碍。
	"SHARK": {"y": 254.0, "h": 192.0, "w": 70.0,
		"hint": "SHARK", "action": "TURTLE LEAP",
		"lesson": "SHARK - TAKE THE TURTLE AND PRESS UP"},
	"DIVE_GATE": {"y": 170.0, "h": 180.0, "w": 180.0,
		"hint": "REEF ARCH", "action": "TURTLE DIVE",
		"lesson": "REEF ARCH - TAKE THE TURTLE AND HOLD DOWN"},
	"FLOATING_LOG": {"y": 158.0, "h": 200.0, "w": 32.0,
		"hint": "FLOATING LOG", "action": "JUMP + DIVE",
		"lesson": "FLOATING LOG - JUMP, SWITCH, DIVE"},
	# 高墙是两段矩形：墙楣（压骑乘兔）+ 墙身（压巡航壳和深潜路线），
	# 中间 82～236 的窗口只放得下跃起到顶的壳。y/h 这里给整墙的外部尺寸
	# （y 与墙楣上沿同值），真正的两段几何由 build_group 写死。
	"HIGH_WALL": {"y": 86.0, "h": 400.0, "w": 30.0,
		"hint": "HIGH WALL", "action": "LEAP + KICK",
		"lesson": "HIGH WALL - LEAP, SWITCH, KICK"},
}

# 55 组。节奏按“一次只教一个东西 → 开始连换 → 收紧”排：
#   Z1 教学：趴低 → 跳跃 → 跃起 → 下潜 → 组合，每类先单独出现再重复；
#   Z2 连换：兔子 / 乌龟交替，组合每 3～4 组一次；
#   Z3 收紧：组合 4 次，单角色间距 1000 px（260 px/s = 3.85 s）。
# FEEL-41：Z2 的连续关系不再只靠“距离”，而是靠前后答案：
#   shark3→beam3（跃鲨→趴梁）、rock4→gate3（跳岩→潜拱）、
#   gate3→bird3（出拱→换兔子）、rock6→gate4（2.93 s 提前换人）、
#   shark5→bird5（鲨退→换兔子）。Z1 的 rock3 是潮汐时机双解。
# 组合漂浮物前方留 ≥1000 px：Z1 1160/220=5.27 s、Z2 1230/240=5.13 s、Z3 1350/260=5.19 s。
# Phase V（P1-4）把 Z1 的组合提前到 log1=6400（首次协同 ≈27.3 s），
# 后面的单角色间距全部保持 ≥3.5 s 基线（最小 818 px = 3.72 s）。
# 单角色最小尾端间距 900 px（Z1 4.09 s / Z2 4.25 s / Z3 3.85 s），都高于 3.5 s 基线。
const GROUPS := [
	# ---- Zone 1：教学。----
	# P1-4（TBB-SHIFT-FEEL-03）：首 35 s 的节奏由“站位”决定，不加大字教学。
	# 赛程从 x=400 出发、Z1 基速 220 px/s，所以按“离起点距离 / 220”算：
	#   0–5 s   空镜：bird1 放在 1560（接触 ≈5.3 s），此前不要求任何输入
	#   5–10 s  首次互动：bird1 趴低（默认就在兔子身上，只需 ↓）
	#   15–20 s 首次有意义的 SHIFT：gate1 在 3800（接触 ≈15.5 s），必须换到乌龟下潜
	#   25–35 s 首次协同：log1 在 6400（接触 ≈27.3 s），跳 + SHIFT + ↓ 的 BRO DIVE
	# 只换位置，不增删关卡。三格轮换：gate1→3800、rock3→8400、beam1→14550。
	# beam1 落到第二段加速带（13700–14400）前方，保住“吃到食物后同一段低梁”的
	# 救援/加速探针（stage4_rescue_boost、stage4_hud_score 按组名找它）。
	{"group": "bird1", "zone": 1, "kind": "LOW_BIRD", "x": 1560.0, "w": 120.0},
	# REBUILD-05 E3 试过 rock1 2500 → 2610：Z1 最长空档确实是 rock1→gate1，
	# 但 rock1 挪进第一段加速带（2550 起）会抢走首份食物的锚点
	# （食物从 3250 掉到带左端 2550，紧贴岩石前 60 px），已回退到 2500。
	# 空档改为在 gate1 上解决（见下一行注释）。
	# 2026-11-13（REBUILD-05 E3）：3900 → 3800。Z1 最长空档在 rock1→gate1 /
	# gate1→rock2 上，把礁拱往中间夹 100 px，两段从 6.36 / 5.45 s 收到 5.91 / 5.91 s；
	# 食物仍锚在加速带右端 3250（clamp 生效，未移位），gate1→rock2 也不再拉长。
	{"group": "gate1", "zone": 1, "kind": "DIVE_GATE", "x": 2400.0, "w": 180.0},
	{"group": "rock2", "zone": 1, "kind": "SURFACE_ROCK", "x": 3240.0, "w": 110.0,
		"combo": "gate1_rock2", "relay": true},
	# FEEL-34：Z1 第一根浮木加高，乌龟单潜不再能从底部绕过；
	# 必须兔子跳上沿 + 乌龟潜下沿（约 24 s，第一次真接力）。
	{"group": "log1", "zone": 1, "kind": "FLOATING_LOG", "x": 4080.0, "w": 32.0, "h": 215.0},
	{"group": "shark1", "zone": 1, "kind": "SHARK", "x": 4920.0, "w": 70.0,
		"motion": {"name": "ambush_shark"}},
	# REBUILD-05 E2 原型 1（周期运动）：潮汐岩。
	# 岩体随浪上下 52 px / 3.6 s。基本解法不变——跳过去在任何相位都成立；
	# 读懂节奏的奖励是“浪谷时直接骑过去”（岩顶沉到世界 202，兔身 252 起让开，
	# 浪谷窗口 0.76 s > 过岩的 0.55 s，整段都低才成立）。
	# 高相位岩顶 306：反下潜段被抬到世界 454，深潜也能从下面过——
	# 浪峰钻、浪谷骑、任何时候跳，三种答案由运动决定，但都不是必死。
	{"group": "rock3", "zone": 1, "kind": "SURFACE_ROCK", "x": 5760.0, "w": 120.0, "identity": "buoy",
		"dual": true,
		"motion": {"name": "tide_rock", "axis": "y", "amp": 52.0, "period": 3.6}},
	# P6（2026-11-13）：原 9600 的低梁 → 10860 的高墙、原 10860 的低鸟 → 13300。
	# 35–50 s 原来是 rock3→beam2→bird2 三连兔子（只跳、趴、趴），命名无聊段。
	# 现在中段插进 wall1（跃起+蹬踏，BOTH）：47.5 s 必须两角色配合一次，
	# 三连兔子拆成“两连 + 一次配合”，窗口里角色切换两次。间距全部 4.9~5.1 s。
	{"group": "wall1", "zone": 1, "kind": "HIGH_WALL", "x": 6600.0, "w": 30.0},
	{"group": "gate2", "zone": 1, "kind": "DIVE_GATE", "x": 7440.0, "w": 180.0},
	# CORE-FEEL-07 P1-E：bird2 从 13300 收到 12850。原 gate2→bird2→beam1 是
	# “5.05 / 5.18 s”两拍同速；现在变成 3.05 s 的突然一拍，再留 7.23 s 长呼吸，
	# 让“节奏变化”这一段有可测量的加速与回落（beam1 是食物锚点，位置不动）。
	# FEEL-09 优化：7.23 s 的空档超过“最长 6 s”门槛，bird2 回到 13280；
	# 两拍变成 5.82 / 5.77 s，仍保留方向切换，但不再有 7 s 无事可做。
	{"group": "bird2", "zone": 1, "kind": "LOW_BIRD", "x": 8280.0, "w": 110.0,
		"dual": true},
	{"group": "beam1", "zone": 1, "kind": "LOW_BEAM", "x": 9120.0, "w": 170.0},

	# ---- Zone 2：连换。 ----
	# REBUILD-06 P3：原来的“巡游鲨”改成水下伏击，移动从横向巡游换成
	# “在水下等 → 靠近时预警 → 冲上水面 → 退回深水”。
	# P6（2026-11-13）：shark3 与 beam3 换位（17000↔15800）。换位前
	# bird2(兔)→beam1(兔)→beam3(兔) 是三连兔子：Z1 末尾两连 + 进 Z2 再一组，
	# 刚做完 wall1 的配合又回到同一个答案；换位后 bird2+beam1 两连、shark3
	# 在 69.7 s 先要一次乌龟对水下伏击的应对、beam3+rock4 也只剩两连。
	{"group": "shark3", "zone": 2, "kind": "SHARK", "x": 10600.0, "w": 70.0,
		"motion": {"name": "ambush_shark"}},
	# FEEL-09 优化：beam3 从 17000 提前到 16880，beam3→rock4 由 2.50 s 拉到
	# 3.71 s，满足“单角色障碍至少 3.5 s”的门槛；rock4 是动态障碍，不动它的 x。
	{"group": "beam3", "zone": 2, "kind": "LOW_BEAM", "x": 11164.0, "w": 170.0,
		"combo": "shark3_beam3"},
	# REBUILD-05 G：进 Z2 第一组岩也改成潮汐岩（同 52 px / 3.6 s）。
	# 这样“进 Z2 就看得见东西在动”，不是先走五组静态再碰到第一块会动的岩。
	{"group": "rock4", "zone": 2, "kind": "SURFACE_ROCK", "x": 12250.4, "w": 120.0, "identity": "dock_crate",
		"motion": {"name": "tide_rock", "axis": "y", "amp": 52.0, "period": 3.6, "phase": 0.18}},
	{"group": "gate3", "zone": 2, "kind": "DIVE_GATE", "x": 13311.7, "w": 180.0,
		"combo": "rock4_gate3", "relay": true},
	{"group": "bird3", "zone": 2, "kind": "LOW_BIRD", "x": 14539.2, "w": 120.0,
		"combo": "gate3_bird3"},
	# REBUILD-05 G：Z2 也补一组涨落浮木——到 Z2 结束前，三个原型（潮汐/巡游/浪涌）
	# 都出现过。浮木不是食物锚点（Z2 锚点是 gate3 / rock6 / shark5）。
	# 规格与 log6 完全相同（−18 ± 22 px / 5.0 s），浪高上限仍是 +4，不偷袭标准 BRO DIVE。
	{"group": "log2", "zone": 2, "kind": "FLOATING_LOG", "x": 15837.2, "w": 32.0,
		"motion": {"name": "swell_log", "axis": "y", "amp": 22.0, "period": 5.0,
			"bias": -18.0, "phase": 0.22}},
	# REBUILD-05 F：Z2 也补一组潮汐岩（同 52 px / 3.6 s 规格）。Z1 只留 rock3
	# 当样板——教学区不再加运动；Z2 从这里开始“同样的岩，有时在动”。
	# 这组不是食物锚点（锚点是 rock6），动的是 y 轴，不影响食物位置。
	{"group": "rock5", "zone": 2, "kind": "SURFACE_ROCK", "x": 17211.6, "w": 130.0, "identity": "dock_crate",
		"motion": {"name": "tide_rock", "axis": "y", "amp": 52.0, "period": 3.6, "phase": 0.47}},
	{"group": "beam4", "zone": 2, "kind": "LOW_BEAM", "x": 18433.2, "w": 180.0,
		"no_anti_dive": true, "dual": true, "combo": "beam4_dual"},
	{"group": "wall2", "zone": 2, "kind": "HIGH_WALL", "x": 19588.7, "w": 30.0},
	{"group": "rock6", "zone": 2, "kind": "SURFACE_ROCK", "x": 20579.0, "w": 140.0,
		"no_anti_dive": true, "dual": true},
	{"group": "gate4", "zone": 2, "kind": "DIVE_GATE", "x": 21423.1, "w": 180.0,
		"combo": "rock6_gate4", "relay": true},
	{"group": "bird4", "zone": 2, "kind": "LOW_BIRD", "x": 22782.7, "w": 110.0,
		"combo": "gate4_bird4", "relay": true, "dual": true},
	{"group": "log3", "zone": 2, "kind": "FLOATING_LOG", "x": 24241.2, "w": 32.0},
	{"group": "rock7", "zone": 2, "kind": "SURFACE_ROCK", "x": 25367.6, "w": 120.0, "identity": "dock_crate",
		"motion": {"name": "tide_rock", "axis": "y", "amp": 52.0, "period": 3.6, "phase": 0.63}},
	{"group": "beam5", "zone": 2, "kind": "LOW_BEAM", "x": 26464.7, "w": 170.0,
		"no_anti_dive": true, "dual": true, "combo": "beam5_dual"},
	# REBUILD-06 P3 原型：水下伏击鲨的样板组（Z2 第一只）。
	# 潜伏时整条鱼在 528～720，正常巡航/下潜都碰不到；进入 0.95 s 航程
	# 亮 0.55 s 预警，然后冲到水面压 1.4 s。跃起仍是保底解，退避后壳自动放行。
	{"group": "shark5", "zone": 2, "kind": "SHARK", "x": 27595.7, "w": 70.0,
		"motion": {"name": "ambush_shark"}},
	{"group": "bird5", "zone": 2, "kind": "LOW_BIRD", "x": 28719.4, "w": 120.0,
		"combo": "shark5_bird5", "dual": true},
	{"group": "log4", "zone": 2, "kind": "FLOATING_LOG", "x": 30019.4, "w": 32.0},
	# CORE-FEEL-07 P1-E：gate5 从 38000 收到 37480。log4（BRO DIVE）落下后
	# 已经在下潜姿态，2.91 s 后紧接着要过礁拱——这一段是“连招”，不是两个单点。
	{"group": "gate5", "zone": 2, "kind": "DIVE_GATE", "x": 31394.3, "w": 180.0,
		"relay": true},

	# ---- Zone 3：收紧。 ----
	# 间距按“上一组尾端 +1000 px”（260 px/s = 3.85 s）排，组合前留 1350 px（5.19 s）。
	# Phase Q 起 shark8 之后的一段改为 950~1340 px（3.65~5.15 s），见下方注释。
	# FEEL-20 P1：G31–G35 连续情境。把 beam6 放在 Z3 入口第一拍，
	# 让 gate5（B）→ beam6（T）→ shark6（B）形成 B/T/B 的角色交替；
	# shark6 仍是水下伏击，只是从第一组后移一组。
	# PHASE-4：beam6 在 37953，实际仍在 Z2 区间（Z3 从 39000 开始）。
	# 保留它作为 Z3 前的最后一拍，但 zone 标为 2，避免“区域外障碍”与提前提速。
	{"group": "beam6", "zone": 2, "kind": "LOW_BEAM", "x": 32953.1, "w": 180.0},
	{"group": "shark6", "zone": 3, "kind": "SHARK", "x": 34218.9, "w": 70.0,
		"motion": {"name": "ambush_shark"}},
	# P6（2026-11-13）：Z3 第三组岩加入潮汐（同 52 px / 3.6 s）。Z3 的高操作占比
	# 原来被 Z2 压过（0.50 < 0.58），且这几个静态岩连着梁/拱做成整段“站着按键”。
	# 它不在食物锚点链上（锚点是 shark8/beam8/shark9/gate8），动的是 y 轴，不影响食物。
	{"group": "rock8", "zone": 3, "kind": "SURFACE_ROCK", "x": 35372.8, "w": 130.0,
		"identity": "drift_crate", "dual": true,
		"motion": {"name": "tide_rock", "axis": "y", "amp": 52.0, "period": 3.6, "phase": 0.31}},
	{"group": "gate6", "zone": 3, "kind": "DIVE_GATE", "x": 36553.3, "w": 180.0,
		"relay": true},
	# REBUILD-05 G22：Z3 的这组浮木也随浪涌走（与 log6/log2 同规格 −18 ± 22 px / 5.0 s，
	# 相位错开 0.35 个周期）。它不在食物锚点链上（Z3 锚点是 shark8/beam8/shark9/gate8）。
	# 这样 Z3 两处“浮木/鸟”不再是同一张静态图：第一处浮木会沉浮，第二处不动。
	{"group": "log5", "zone": 3, "kind": "FLOATING_LOG", "x": 37297.8, "w": 32.0,
		"combo": "gate6_log5", "relay": true,
		"motion": {"name": "swell_log", "axis": "y", "amp": 22.0, "period": 5.0,
			"bias": -18.0, "phase": 0.35}},
	{"group": "bird6", "zone": 3, "kind": "LOW_BIRD", "x": 37946.4, "w": 120.0,
		"combo": "log5_bird6", "relay": true, "dual": true},
	{"group": "wall3", "zone": 3, "kind": "HIGH_WALL", "x": 39222.3, "w": 30.0},
	{"group": "beam7", "zone": 3, "kind": "LOW_BEAM", "x": 39706.4, "w": 170.0,
		"combo": "wall3_beam7"},
	# REBUILD-05 F：Z3 第二组潮汐岩（同规格）。这组比样板宽 20 px，
	# 跳跃在 8 个相位都验过；它不是食物锚点（锚点是 shark9）。
	{"group": "rock9", "zone": 3, "kind": "SURFACE_ROCK", "x": 40894.0, "w": 140.0, "identity": "drift_crate",
		"motion": {"name": "tide_rock", "axis": "y", "amp": 52.0, "period": 3.6, "phase": 0.52}},
	# CORE-FEEL-07 P1-E：D 持续环境段的入口。礁拱从 190 拉成 760 宽——不是新障碍，
	# 是同一个 DIVE_GATE 拉长：玩家必须持续按住 ↓ 约 3.8 s（含进洞下潜与出洞上浮）
	# 从长隧道里穿过去，氧气按原速率消耗。出洞后 3.0 s 接涨落浮木（log6），
	# 环境一直在动，没有“过一组就歇”的节拍。
	# FEEL-09 优化：D1 长隧道 760 → 600。它仍是全游戏最长的下潜段，但尾端到
	# log6 的反应从 3.00 s 提到 3.62 s，满足单角色障碍 3.5 s 门槛。
	{"group": "gate7", "zone": 3, "kind": "DIVE_GATE", "x": 42054.4, "w": 420.0},
	# FEEL-13 P0-B：Z3 末段顺序与间距重排。
	# 旧顺序在 shark8 之后是 bird7→beam8→rock10 三连兔子；现在把 log7 插进
	# beam8 与 rock10 之间，再把 shark9 提前到 rock10 之后，最后四组改成
	# log8→rock11→gate8→bird9。全程没有三连同主角/同节奏。
	# 间距按“上一组末端 + 3.75~4.55 s 反应时间”重算；gate7 仍是 600 宽长隧道，
	# 隧道尾到 log6 保留 4.15 s。
	# REBUILD-05 E2 原型 3（环境变化）：涨落浮木 −18 ± 22 px / 5.0 s，phase 0.14。
	{"group": "log6", "zone": 3, "kind": "FLOATING_LOG", "x": 43708.0, "w": 32.0,
		"motion": {"name": "swell_log", "axis": "y", "amp": 22.0, "period": 5.0,
			"bias": -18.0, "phase": 0.14}},
	# shark8 仍是食物锚点；它现在直接接 bird7，不再让 beam8 紧贴加速尾巴。
	{"group": "shark8", "zone": 3, "kind": "SHARK", "x": 44853.1, "w": 70.0,
		"motion": {"name": "ambush_shark"}},
	{"group": "bird7", "zone": 3, "kind": "LOW_BIRD", "x": 46077.7, "w": 110.0},
	{"group": "beam8", "zone": 3, "kind": "LOW_BEAM", "x": 47241.6, "w": 180.0},
	{"group": "log7", "zone": 3, "kind": "FLOATING_LOG", "x": 48439.0, "w": 32.0},
	# REBUILD-05 E3：Z3 第二组动态潮汐岩，phase 0.71。
	{"group": "rock10", "zone": 3, "kind": "SURFACE_ROCK", "x": 49000.0, "w": 120.0,
		"identity": "drift_crate", "combo": "log7_rock10", "relay": true, "dual": true,
		"motion": {"name": "tide_rock", "axis": "y", "amp": 52.0, "period": 3.6, "phase": 0.71}},
	{"group": "shark9", "zone": 3, "kind": "SHARK", "x": 50065.0, "w": 70.0,
		"motion": {"name": "ambush_shark"}},
	{"group": "bird8", "zone": 3, "kind": "LOW_BIRD", "x": 50648.1, "w": 130.0,
		"combo": "shark9_bird8", "relay": true},
	{"group": "beam9", "zone": 3, "kind": "LOW_BEAM", "x": 51932.7, "w": 170.0},
	{"group": "log8", "zone": 3, "kind": "FLOATING_LOG", "x": 53156.6, "w": 32.0},
	# REBUILD-05 G：Z3 末段宽岩（w=150）加潮汐，phase 0.27；不是食物锚点。
	{"group": "rock11", "zone": 3, "kind": "SURFACE_ROCK", "x": 54206.0, "w": 150.0, "identity": "drift_crate",
		"motion": {"name": "tide_rock", "axis": "y", "amp": 52.0, "period": 3.6, "phase": 0.27}},
	{"group": "gate8", "zone": 3, "kind": "DIVE_GATE", "x": 55376.4, "w": 180.0},
	{"group": "bird9", "zone": 3, "kind": "LOW_BIRD", "x": 56150.0, "w": 120.0,
		"combo": "gate8_bird9", "relay": true},
	# 终点前最后一跳仍是动态潮汐岩，phase 0.58；在浪里收尾。
	{"group": "rock12", "zone": 3, "kind": "SURFACE_ROCK", "x": 56700.0, "w": 120.0,
		"identity": "drift_crate",
		"motion": {"name": "tide_rock", "axis": "y", "amp": 52.0, "period": 3.6, "phase": 0.58}},
]

# ---- CORE-FEEL-07 P1-E：节奏分段 ----
# 整条赛道切成连续的 10 段，每段只回答一个问题：这一段让玩家做什么节拍？
#   A 单点：孤立单点，前后都有长恢复（基础节拍）
#   B 连招：连续两组间隔 <= COMBO_GAP_S，必须连着处理（不是一组一歇）
#   C 节奏变化：段内间隔从长突然变短、再拉长（5.05 -> 3.05 -> 7.23 s）
#   D 持续环境：同一个状态要维持 >= 2.5 s（760 px 长礁拱的持续下潜），后面紧跟会动的环境
# 分段是“数据”不是“注释”：探针和报告都直接读它，改站位不用同步改文案。
const COMBO_GAP_S := 3.2
const RHYTHM_SEGMENTS := [
	{"id": "A1", "type": "A", "name": "OPENING BREATH", "name_zh": "开场呼吸",
		"groups": ["bird1", "rock1", "gate1", "rock2"]},
	{"id": "A2", "type": "A", "name": "FIRST SINGLES", "name_zh": "先认单点",
		"groups": ["log1", "shark1", "rock3"]},
	{"id": "C1", "type": "C", "name": "TEMPO SPIKE", "name_zh": "节奏突变",
		"groups": ["beam2", "wall1", "gate2", "bird2", "beam1"]},
	{"id": "A3", "type": "A", "name": "ZONE TWO DOOR", "name_zh": "二区门口",
		"groups": ["shark3"]},
	{"id": "B1", "type": "B", "name": "CROUCH THEN JUMP", "name_zh": "趴低接跳",
		"groups": ["beam3", "rock4"]},
	{"id": "A4", "type": "A", "name": "CORAL SINGLES", "name_zh": "珊瑚单点",
		"groups": ["gate3", "bird3", "log2", "rock5", "beam4", "wall2", "rock6",
			"gate4", "bird4", "log3", "rock7", "beam5", "shark5", "bird5"]},
	{"id": "B2", "type": "B", "name": "DIVE CHAIN", "name_zh": "下潜连招",
		"groups": ["log4", "gate5"]},
	{"id": "A5", "type": "A", "name": "MUSCLE SINGLES", "name_zh": "三区单点",
		"groups": ["shark6", "beam6", "rock8", "gate6", "log5", "bird6", "wall3",
			"beam7", "rock9"]},
	{"id": "D1", "type": "D", "name": "LONG TUNNEL", "name_zh": "长隧道",
		"groups": ["gate7", "log6"]},
	{"id": "A6", "type": "A", "name": "FINAL SINGLES", "name_zh": "终段单点",
		"groups": ["bird7", "shark8", "beam8", "rock10", "log7", "bird8", "shark9",
			"beam9", "rock11", "gate8", "log8", "bird9", "rock12"]},
]

# ---- 2026-11-11 补充指令：独立原型段 ----
# 五类障碍各一组，间距 1200 px（220 px/s = 5.45 s），保证“首次出现 ≥5 s”。
# 起点 x=400，第一组放在 1500，正好给满 PROMPT_RANGE=1100 的预警。
# 几何全部按“兔子层 / 乌龟层”两条路线设计，不按障碍名字派动作（数值为关卡空间，装载时 +34）：
#   LOW_BIRD   200～240 + 俯冲空域 96～200：主带压站立兔，空域覆盖跳跃/跃起的弧线；
#              趴低兔（250～274）与龟壳（272～328）不碰
#   SURFACE_ROCK 220～262：只压兔子，龟壳顶 272 让开 10 px（实测兔子跳过去即可）
#   LOW_BEAM   140～240：站立兔顶头，趴低兔 250 起让开
#   DIVE_GATE  170～350：巡航龟壳顶 272 撞上沿；下潜 150 后兔头顶 368 让开 18 px
#   SHARK      240～335：巡航龟壳底 328 撞上；跃起 58 px 后龟壳底 270 让开
#   FLOATING_LOG 192～410：上沿压站立兔与跃起壳底，下沿压巡航龟壳；兔子跳上沿、乌龟潜下沿
const PROTO_GROUPS := [
	{"group": "proto_bird", "zone": 1, "kind": "LOW_BIRD",
		"rects": [Rect2(1500, 200, 120, 40), Rect2(1500, 96, 120, 104)],
		"hint": "DIVING GULL", "action": "CROUCH DOWN",
		"lesson": "DIVING GULL - CROUCH, DON'T JUMP INTO IT"},
	{"group": "proto_rock", "zone": 1, "kind": "SURFACE_ROCK",
		"rects": [Rect2(2700, 220, 110, 42)],
		"hint": "LOW ROCK", "action": "JUMP OVER",
		"lesson": "JUMP THE ROCK - THE TURTLE PASSES UNDER"},
	{"group": "proto_beam", "zone": 1, "kind": "LOW_BEAM",
		"rects": [Rect2(3900, 140, 180, 100)],
		"hint": "DOCK BEAM", "action": "CROUCH DOWN",
		"lesson": "DOCK BEAM - CROUCH, THE SHELL KEEPS CRUISING"},
	{"group": "proto_gate", "zone": 1, "kind": "DIVE_GATE",
		"rects": [Rect2(5100, 170, 180, 180)],
		"hint": "REEF ARCH", "action": "TURTLE DIVE",
		"lesson": "REEF ARCH - TAKE THE TURTLE AND HOLD ↓"},
	{"group": "proto_shark", "zone": 1, "kind": "SHARK",
		"rects": [Rect2(6300, 240, 70, 206)],
		"hint": "SHARK", "action": "TURTLE LEAP",
		"lesson": "SHARK - TAKE THE TURTLE AND PRESS ↑"},
	{"group": "proto_log", "zone": 1, "kind": "FLOATING_LOG",
		"rects": [Rect2(7600, 158, 32, 218)],
		"hint": "FLOATING LOG", "action": "JUMP + DIVE",
		"lesson": "FLOATING LOG - JUMP, SWITCH, DIVE"},
	# BRO OLLIE：墙楣 world 120～136、窗口 world 136～240、墙身 world 240～520。
	# 跃起到顶（160）时龟心 174、壳 149～199（进窗口）、兔身 95～137（撞墙楣）；
	# 兔子蹬踏 +119 px 后身体 20～68，从墙楣顶上过去。数值为关卡空间（装载 +34）。
	# 墙宽 30：壳 90 宽，跃起高于墙身的窗口 168 px，扣除 120 px 落脚占位后
	# 仍有 ±24 px 起跳容错（BRO DIVE 的窗口也是 ~24 px）。墙楣下沿 136 是
	# “低跃从楣下钻过”的封口线：兔头顶 136 时壳底已低于墙身顶 240。
	{"group": "proto_wall", "zone": 1, "kind": "HIGH_WALL",
		"rects": [Rect2(9000, 86, 30, 16), Rect2(9000, 206, 30, 280)],
		"hint": "HIGH WALL", "action": "LEAP + KICK",
		"lesson": "HIGH WALL - LEAP, SWITCH, KICK"},
]
const PROTO_END := 10100.0

# 原型段里“组合障碍”的预期动作，测试和 F3 共用一份，避免两处各写一遍。
const ROLE_BY_KIND := {
	"LOW_BIRD": "RABBIT",
	"LOW_BEAM": "RABBIT",
	"SURFACE_ROCK": "RABBIT",
	"DIVE_GATE": "TURTLE",
	"SHARK": "TURTLE",
	"FLOATING_LOG": "BOTH",
	"HIGH_WALL": "BOTH",
}

# ---- Phase O（2026-11-12）：加速带改为 TURTLE SNACK RUSH ----
# 原 BOOST_LANES 不再提供“进带自动提速”；它现在的唯一用途是标出食物可以出现的
# 那几段水面（旧测试也用它来关闭加速，语义改为“这里没有食物”）。
# 每段带对应前方第一组固定障碍；食物放在该障碍前 SNACK_LEAD px（夹回带内）。
# 加速段因此最长 450 px，从障碍首次进入视野（1100 px）到碰撞仍 ≥4 s：
#   Z1 220→253：650/220 + 450/253 = 4.73 s
#   Z2 240→276：650/240 + 450/276 = 4.34 s
#   Z3 260→299：650/260 + 450/299 = 4.00 s
# 只在“操控乌龟”且乌龟处于巡航深度时吃；不额外加按键，不吃不惩罚。
const SNACK_LEAD := 450.0
const SNACK_BOOST_SCALE := 1.15
const SNACK_CONTACT_PX := 70.0
const SNACK_BOOST_TAIL := 180.0

const BOOST_LANES := [
	Rect2(2550, 250, 700, 70),
	Rect2(7000, 250, 700, 70),
	Rect2(13400, 250, 700, 70),
	Rect2(20800, 250, 700, 70),
	Rect2(28400, 250, 700, 70),
	Rect2(48000, 250, 500, 70),
	Rect2(49200, 250, 700, 70),
	Rect2(53900, 250, 500, 70),
	Rect2(57100, 250, 500, 70),
]

## 任务书 §二 给的每区候选池（保留原文，作为设计意图的存档）。
const ZONE_OBSTACLE_POOL := {
	1: ["LOW_BIRD", "LOW_BEAM", "SURFACE_ROCK"],
	2: ["DIVE_GATE", "SHARK", "FLOATING_LOG"],
	3: ["HIGH_WALL", "FLOATING_LOG", "SURFACE_ROCK"],
}

## ---- Phase P（2026-11-12）：食物后第 1 组障碍按固定种子抽取 ----
## 实际抽取池 = ZONE_OBSTACLE_POOL 去掉双角色连招（高墙/浮木），原因：
##   1) PHASE-N §6 实测：加速 1.15× 后高墙第一段窗口 0.23 s、浮木 0.33 s，
##      低于本轮“至少约 0.5 s”的目标；普通障碍同条件实测 ≥0.53 s。
##   2) 复杂障碍的预警受 1100 px 视野限制，Z3 最多 4.23 s，凑不到 §二 的“≥5 s”。
## 复杂连招仍在固定关卡里出现 16 次（巡航速度、前面留 5.19 s 准备段），
## 所以“复杂组合”这一课不会消失，只是不作为食物加速的随机结果。
## Z3 剔除墙/木后只剩岩，补进梁/鲨两种已教学单角色障碍，保证抽取有变化；
## 两者在加速下的实测窗口分别是“整个接近段”和 0.585 s。
const SNACK_DRAW_POOL := {
	1: ["LOW_BIRD", "LOW_BEAM", "SURFACE_ROCK"],
	2: ["DIVE_GATE", "SHARK"],
	3: ["SURFACE_ROCK", "LOW_BEAM", "SHARK"],
}

## 第一个食物遭遇固定用关卡自己的种类（§五：第一次用固定、简单、宽容的障碍）。
## 之后 8 次才按种子抽。
const SNACK_FIXED_FIRST := true


## 由“x + 宽度”生成完整组：判定框、F3 标签、教学文案共用同一份模板。
## CORE-FEEL-08 P1-C：每种障碍的默认身份（动物型 / 物品环境型）。
## 清单里每条障碍都要能回答“它是什么”，没有身份的种类不允许存在。
## 判定、计时、分数完全不读这个字段；只有绘制和提示读。
const IDENTITY_BY_KIND := {
	"LOW_BIRD": "diving_gull",     # 俯冲海鸥：海鸟俯冲抢食
	"LOW_BEAM": "dock_beam",       # 码头横梁：栈桥结构
	"SHARK": "reef_shark",         # 礁鲨：巡游 / 伏击
	"DIVE_GATE": "reef_arch",      # 礁拱：天然岩拱，必须下潜
	"FLOATING_LOG": "drift_log",   # 漂流浮木：随浪涌起伏
	"HIGH_WALL": "high_wall",      # 高墙：码头堤墙，必须协作翻越
	"SURFACE_ROCK": "sea_rock",    # 静止礁石
}

## TBB-CORE-FEEL-09 P0-A：第二区域是室内木质码头（Producer 已定），
## 障碍身份必须跟着场景走。只覆盖 Z2；Z1/Z3 继续用上面的默认表。
##   海鸥 → 屋顶吊网（绞盘放下/收回，网底压兔子层）
##   礁鲨 → 水渠鳗鱼（盘在水渠底，靠近时窜上来）
##   礁拱 → 木质船闸（闸板悬在水面，底部留出下潜通道）
##   静止礁石 → 系泊浮台（码头浮台，跳过去；下面挂锚链）
## 判定 kind 完全不变，这里只改“它是什么”。
const IDENTITY_BY_KIND_ZONE := {
	2: {
		"LOW_BIRD": "cargo_net",
		"SHARK": "canal_eel",
		"DIVE_GATE": "sluice_gate",
		"SURFACE_ROCK": "mooring_pontoon",
	},
}

## FEEL-13 P0-B：真正落地的几何节奏重排（55 组数量/种类不变）。
## 只把后一组拉近前一组，形成 8 个近距离双段；不改障碍类型/区域。


static func build_group(spec: Dictionary) -> Dictionary:
	var kind: String = spec["kind"]
	var gx := float(spec.get("x", 0.0))
	var shape: Dictionary = KIND_SPEC[kind]
	var w: float = spec.get("w", shape["w"])
	var h: float = spec.get("h", shape["h"])
	# CORE-FEEL-08 P1-C：身份字段。种类（kind）决定“怎么过”，身份（identity）
	# 决定“它是什么、为什么在这里、为什么动”。判定/计时完全不读这个字段，
	# 只有绘制（race._draw_hazard）和运动提示（_update_motion_lesson）读它。
	#   buoy        Z1 海上系泊浮标——锚绳拴住，随涌浪起落
	#   dock_crate  Z2 木质码头吊装货箱——挂在吊钩上，随吊臂晃动
	#   drift_crate Z3 外海漂流货箱——从码头冲出去的货，随大浪浮沉
	#   sea_rock    静止礁石（默认，不动）
	var identity := String(spec.get("identity", ""))
	if identity == "":
		# FEEL-09 P0-A：先查“本区域覆盖”，再落回种类默认身份。
		# 这样 Z2 的海鸥/鲨鱼/礁拱可换成码头设施，而 Z1/Z3 不受影响。
		var zone_table: Dictionary = IDENTITY_BY_KIND_ZONE.get(int(spec["zone"]), {})
		identity = String(zone_table.get(kind, IDENTITY_BY_KIND.get(kind, kind)))
	var rects := [Rect2(gx, shape["y"], w, h)]
	# 高墙是两段矩形（墙楣 + 墙身），单矩形模板在这里不适用：
	# 窗口给关卡空间 82～236（装载 +34 → 世界 116～270）。
	# Phase H 的实测：真正卡死起手窗口的是墙身的上沿，不是墙楣——壳是 96×56，
	# 判定时再内缩 3 px，只要壳的下沿还没升到墙身以上就判龟撞，所以墙身越高、
	# 能过的 lead 越窄（改前墙身上沿世界 240，探针窗口 0.136 s）。
	# 把墙身从 206 下移到 236（世界 270），窗口底端多出 30 px，起手窗口随之放宽。
	# 墙楣保持 86 不动：抬高墙楣只会让骑乘兔要跳得更高，实测把窗口收窄了（见 PHASE-H 报告）。
	# 墙身下沿 486 不动，深潜仍被挡死。
	if kind == "HIGH_WALL":
		rects = [Rect2(gx, 86.0, w, 16.0),
			Rect2(gx, 236.0, w, 250.0)]
	# 俯冲海鸟：主判定带之外再加一段“俯冲空域”（装载 +34 后世界 130～234）。
	# 这一段不是把主判定带放大——它对应画出来的下潜轨迹和翅膀扫过的空间：
	# 站立/跳跃/跃起都会撞进去，趴低从它下方过，乌龟下潜从水下过（见文件头）。
	if kind == "LOW_BIRD":
		rects.append(Rect2(gx, 96.0, w, 104.0))
	# 岩/梁的水下反下潜段：只罩住“下潜后的兔子”，壳从它上下两侧过（见文件头注释）。
	# FEEL-22：浮标/吊装货箱/漂流货箱的水下碰撞段无法在画面上解释成同一个物体，
	# 先删除这三类身份的反下潜段；碰撞只保留可见主物体。
	if kind == "LOW_BEAM" or (kind == "SURFACE_ROCK"
			and identity not in ["buoy", "dock_crate", "drift_crate"]):
		if not bool(spec.get("no_anti_dive", false)):
			rects.append(Rect2(gx, ANTI_DIVE_Y, w, ANTI_DIVE_H))
	return {
		"group": spec["group"], "zone": spec["zone"], "kind": kind,
		"identity": identity,
		"rects": rects,
		# REBUILD-05 E2：动态障碍。空字典 = 静止（默认）。
		# 运动只改“这一刻的判定框位置”，不改类型模板；race.gd 的
		# hazard_offset() 同时喂画和判定，所以两者不可能走散。
		"motion": spec.get("motion", {}),
		"hint": shape["hint"], "action": shape["action"],
		"lesson": shape["lesson"],
		"combo": String(spec.get("combo", "")),
		"dual": bool(spec.get("dual", false)),
		"relay": bool(spec.get("relay", false)),
	}


static func groups() -> Array:
	var out := []
	for spec in GROUPS:
		out.append(build_group(spec))
	return out


## CORE-FEEL-07 P1-E：把 RHYTHM_SEGMENTS 展开成带真实站位/速度的分段。
## 段边界取该段第一组的起点与最后一组的末端；段与段之间不重叠也不留缝。
static func rhythm_segments() -> Array:
	var by_name := {}
	for spec in GROUPS:
		by_name[String(spec["group"])] = spec
	var out := []
	for seg in RHYTHM_SEGMENTS:
		var names: Array = seg["groups"]
		var list := []
		for n in names:
			if by_name.has(String(n)):
				list.append(build_group(by_name[String(n)]))
		if list.is_empty():
			continue
		var start := 1.0e9
		var end := 0.0
		for g in list:
			start = minf(start, group_start(g))
			end = maxf(end, group_end(g))
		var zone := zone_at(start)
		out.append({
			"id": String(seg["id"]), "type": String(seg["type"]),
			"name": String(seg["name"]), "name_zh": String(seg["name_zh"]),
			"zone": int(zone["id"]), "speed": float(zone["base_speed"]),
			"start": start, "end": end, "groups": list,
			"group_names": names.duplicate(),
		})
	return out


static func proto_groups() -> Array:
	return PROTO_GROUPS.duplicate(true)


static func role_for_kind(kind: String) -> String:
	return ROLE_BY_KIND.get(kind, "RABBIT")


static func boost_lanes() -> Array:
	return BOOST_LANES.duplicate()


## Phase O：由加速带生成食物遭遇表。
## 每段带 → 前方第一组固定障碍（障碍已确定，Phase P 再按种子换种类）；
## 食物 x = 障碍 x − 450，夹回带内。返回的字典带 eaten 标记，由 race 缓存。
static func snack_encounters(lanes: Array = BOOST_LANES) -> Array:
	var out := []
	for lane_v in lanes:
		var lane: Rect2 = lane_v
		var obstacle_index := -1
		for i in GROUPS.size():
			if float(GROUPS[i]["x"]) > lane.position.x:
				obstacle_index = i
				break
		if obstacle_index < 0:
			continue
		var obstacle_x := float(GROUPS[obstacle_index]["x"])
		var x := clampf(obstacle_x - SNACK_LEAD, lane.position.x, lane.end.x)
		out.append({
			"x": x,
			"lane": lane,
			"obstacle_index": obstacle_index,
			"obstacle_group": String(GROUPS[obstacle_index]["group"]),
			"zone": int(GROUPS[obstacle_index]["zone"]),
			"eaten": false,
		})
	return out


## 截至 x（不含 x 处的组）已经出现过的种类；“未教学不得随机出现”靠它过滤。
static func taught_kinds_before(x: float) -> Array:
	var out := []
	for spec in GROUPS:
		if float(spec["x"]) >= x:
			break
		var kind := String(spec["kind"])
		if not (kind in out):
			out.append(kind)
	return out


static func is_complex_kind(kind: String) -> bool:
	return kind == "FLOATING_LOG" or kind == "HIGH_WALL"


## 按种子给 9 个食物遭遇定种类。第一个固定，其余从该区抽取池里抽；
## 规则：只抽已教学的、同一区不连续重复同一种（“不许连着两次同一种高压障碍”）。
## 返回 [{index, group, zone, kind, slot_w, fixed}]，纯函数——同种子必然同结果。
static func plan_snack_draws(seed_value: int, encounters: Array) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := []
	var last_by_zone := {}
	# P6：按“最终顺序”记每组种类，用来避免抽出来的种类和前后组合成三连同角色。
	# 抽到的组后面可能还会被再抽到（不会，锚点各不同），但前后组里可能有已抽过的。
	var final_kinds := {}
	for g in GROUPS:
		final_kinds[String(g["group"])] = String(g["kind"])
	for i in encounters.size():
		var enc: Dictionary = encounters[i]
		var group_index := int(enc["obstacle_index"])
		var spec: Dictionary = GROUPS[group_index]
		var zone := int(spec["zone"])
		var original := String(spec["kind"])
		if i == 0 and SNACK_FIXED_FIRST:
			out.append({
				"index": i, "group_index": group_index,
				"group": String(spec["group"]), "zone": zone,
				"kind": original, "slot_w": float(spec["w"]), "fixed": true,
			})
			last_by_zone[zone] = original
			continue
		# FEEL-40：结构性组（连招/接力/双解）不能被随机抽取换角色。
		# 例如 shark9 被抽成 LOW_BEAM 时，bird8 的“鲨鱼退→换兔子”就消失了。
		# 这些组的关卡语义优先于食物点的种类变化；下一组是结构性组时，
		# 这一组也不能换，否则连招的前一拍会被抽走。
		var is_struct := bool(spec.get("relay", false)) \
			or bool(spec.get("dual", false)) \
			or String(spec.get("combo", "")) != ""
		if not is_struct and group_index + 1 < GROUPS.size():
			var nxt: Dictionary = GROUPS[group_index + 1]
			is_struct = bool(nxt.get("relay", false)) \
				or bool(nxt.get("dual", false)) \
				or String(nxt.get("combo", "")) != ""
		if is_struct:
			out.append({
				"index": i, "group_index": group_index,
				"group": String(spec["group"]), "zone": zone,
				"kind": original, "slot_w": float(spec["w"]),
				"fixed": false, "structural": true,
			})
			last_by_zone[zone] = original
			continue
		var pool: Array = SNACK_DRAW_POOL.get(zone, [])
		var last := String(last_by_zone.get(zone, ""))
		var taught := taught_kinds_before(float(spec["x"]))
		var candidates := []
		for k in pool:
			if String(k) != last and (String(k) in taught) and not is_complex_kind(String(k)):
				candidates.append(String(k))
		if candidates.is_empty():
			for k in pool:
				if String(k) != last and not is_complex_kind(String(k)):
					candidates.append(String(k))
		if candidates.is_empty():
			for k in pool:
				if not is_complex_kind(String(k)):
					candidates.append(String(k))
		if candidates.is_empty():
			candidates = [original]
		# P6：角色节奏优先——若上一组的最终角色是兔子/乌龟，优先抽另一角色的种类。
		# 只在“优先集非空”时收窄，不改变原有合法集；这样默认种子下
		# Z3 的 shark8/shark9 不会被抽成岩、把尾段变成五连兔子。
		var prev_kind := ""
		if group_index > 0:
			prev_kind = String(final_kinds.get(
				String(GROUPS[group_index - 1]["group"]), ""))
		if prev_kind != "":
			var prev_role := role_for_kind(prev_kind)
			if prev_role != "BOTH":
				var preferred := []
				for k in candidates:
					if role_for_kind(String(k)) != prev_role:
						preferred.append(String(k))
				if not preferred.is_empty():
					candidates = preferred
		var kind := String(candidates[rng.randi_range(0, candidates.size() - 1)])
		final_kinds[String(spec["group"])] = kind
		out.append({
			"index": i, "group_index": group_index,
			"group": String(spec["group"]), "zone": zone,
			"kind": kind, "slot_w": float(spec["w"]), "fixed": false,
		})
		last_by_zone[zone] = kind
	return out


## 把抽到的种类写进已构建的关卡组：组的起点 x 不变，宽度优先用该种类的自然宽度
## （视觉/判定一致）；若自然宽度会让“下一组”的间距低于 3.5 s 基线，就退回原槽位宽度。
static func apply_snack_draws(groups: Array, draws: Array) -> void:
	for d in draws:
		if bool(d.get("fixed", false)):
			continue
		var i := int(d.get("group_index", -1))
		if i < 0 or i >= groups.size():
			continue
		var spec: Dictionary = GROUPS[i]
		if String(spec["kind"]) == String(d["kind"]):
			continue
		var base := {
			"group": spec["group"], "zone": spec["zone"],
			"kind": String(d["kind"]), "x": float(spec["x"]),
			# FEEL-37：食物抽取换的是“种类”，不是这一组的关卡语义。
			# 漏掉 combo/relay/dual 时，bird9 被抽成岩后就不再算接力组，
			# 真实流程里 gate8→bird9 的连续换人会从审计里消失。
			"combo": String(spec.get("combo", "")),
			"relay": bool(spec.get("relay", false)),
			"dual": bool(spec.get("dual", false)),
			"no_anti_dive": bool(spec.get("no_anti_dive", false))
				or (bool(spec.get("relay", false)) and String(d["kind"]) == "SURFACE_ROCK")
				or (bool(spec.get("dual", false))
					and String(d["kind"]) in ["LOW_BEAM", "SURFACE_ROCK"]),
		}
		# FEEL-47：换 kind 后不能继承旧 motion / identity。
		# rock11（SURFACE_ROCK + tide_rock）曾被抽成 LOW_BEAM 后仍上下移动，
		# 画面就成了“会浮沉的木塔”。只有同 kind 才由上面的 continue 保留原运动。
		if String(d["kind"]) == "SHARK":
			base["motion"] = {"name": "ambush_shark"}
		var natural := build_group(base)
		var next_start := 1.0e9
		if i + 1 < groups.size():
			next_start = group_start(groups[i + 1])
		var zone_speed := float(zone_by_id(int(spec["zone"]))["base_speed"])
		var gap_s := (next_start - group_end(natural)) / zone_speed
		if gap_s < 3.5:
			base["w"] = float(spec["w"])
			natural = build_group(base)
		groups[i] = natural


static func zone_at(x: float) -> Dictionary:
	for zone in ZONES:
		if x < zone["end"]:
			return zone
	return ZONES[ZONES.size() - 1]


static func zone_by_id(id: int) -> Dictionary:
	for zone in ZONES:
		if zone["id"] == id:
			return zone
	return ZONES[0]


static func groups_in_zone(id: int) -> Array:
	var result := []
	for spec in GROUPS:
		if spec["zone"] == id:
			result.append(build_group(spec))
	return result


static func lane_at(x: float) -> bool:
	for lane in BOOST_LANES:
		if x >= lane.position.x and x <= lane.end.x:
			return true
	return false


static func group_start(group: Dictionary) -> float:
	var start_x := 1.0e9
	for r in group["rects"]:
		var rect: Rect2 = r
		start_x = minf(start_x, rect.position.x)
	return start_x


static func group_end(group: Dictionary) -> float:
	var end_x := 0.0
	for r in group["rects"]:
		var rect: Rect2 = r
		end_x = maxf(end_x, rect.end.x)
	return end_x


## 供自检与报告使用的分区统计：组数、种类、连段簇、密度（组/分钟）。
static func stats() -> Dictionary:
	var result := {}
	for zone in ZONES:
		var zid: int = zone["id"]
		var list := groups_in_zone(zid)
		var kinds := {}
		var clusters := 0
		var largest := 1
		var run := 1
		var prev_x := -1.0e9
		var max_gap := 0.0
		var min_gap := 1.0e9
		for group in list:
			kinds[group["kind"]] = kinds.get(group["kind"], 0) + 1
			var gx := group_start(group)
			if prev_x > -1.0e8:
				var gap := gx - prev_x
				max_gap = maxf(max_gap, gap)
				min_gap = minf(min_gap, gap)
				if gap <= COMBO_GAP:
					run += 1
				else:
					if run >= 2:
						clusters += 1
						largest = maxi(largest, run)
					run = 1
			prev_x = gx
		if run >= 2:
			clusters += 1
			largest = maxi(largest, run)
		var seconds: float = (zone["end"] - zone["start"]) / zone["base_speed"]
		result[zid] = {
			"groups": list.size(),
			"kinds": kinds,
			"clusters": clusters,
			"largest_cluster": largest,
			"max_gap": max_gap,
			"min_gap": min_gap if min_gap < 1.0e8 else 0.0,
			"minutes": seconds / 60.0,
			"groups_per_min": list.size() / maxf(seconds / 60.0, 0.01),
		}
	return result
