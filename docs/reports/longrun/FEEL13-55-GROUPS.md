# FEEL-13 55 组实际重排设计表

所有 x / 间距 / 顺序 / 相位均从 `scripts/systems/level_data.gd` 现场计算；旧值来自 `_attic/2026-11-14/feel13-layout-before/level_data-before.gd`。

自动指标：{"groups": 55, "max_same_rhythm_run": 2, "max_same_primary_run": 2, "double_role": 33, "dynamic": 18, "guard": 30, "rescue": 11, "buffer": 15, "windows_5_3types": 51, "windows_5_total": 51, "normal_no_space": 44, "min_react_s": 3.58, "audit_no_solution": 0, "audit_design_correct": 55, "audit_generated_at": "2026-11-14T21:12:55"}

| 组 | 区域 | 障碍 | x | 结构 | 节奏 | 核心决策 | 主要角色 | 普通路线（不按 SPACE） | 进阶路线 | SHIFT | SPACE | 实际修改 | 验证 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| G01 | Z1 | LOW_BIRD | 1560 | 单点 | 缓冲 | 看海鸟俯冲相位：趴低或下潜 | TUBO | 趴低；也可跳/下潜 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | 不变 | audit PASS（实际 LOW_BIRD，设计答案 crouch；可过 crouch/dive） |
| G02 | Z1 | SURFACE_ROCK | 2500 | 单点 | 紧凑 | 看岩面：跳；动态时读浪相位 | TUBO | 跳过去 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | 不变 | audit PASS（实际 SURFACE_ROCK，设计答案 jump；可过 jump/leap/dive_jump） |
| G03 | Z1 | DIVE_GATE | 3800 | 单点 | 缓冲 | 看闸底：下潜 | BITT | 按住 ↓ 下潜 | SHIFT 到 BITT 后 SPACE 主动接应（TUBO 落水时） | 可选 | — | 不变 | audit PASS（实际 DIVE_GATE，设计答案 dive；可过 dive） |
| G04 | Z1 | SURFACE_ROCK | 5100 | 单点 | 缓冲 | 看岩面：跳；动态时读浪相位 | TUBO | 跳过去 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | 不变 | audit PASS（实际 SURFACE_ROCK，设计答案 jump；可过 jump/leap） |
| G05 | Z1 | FLOATING_LOG | 6400 | 组合 | 组合 | 跳与潜的先后：先跳再换手 | 双角色 | TUBO 跳 → SHIFT → BITT 潜 | 用 SHIFT 接力把两段接起来；不按 SPACE 也能普通过 | 必需 | 救援 | 不变 | audit PASS（实际 FLOATING_LOG，设计答案 dive_jump；可过 dive_jump） |
| G06 | Z1 | SHARK | 7250 | 动态单点 | 动态 | 看水下伏击预警：跃起；读运动相位 | BITT | 跃起 | SHIFT 到 BITT 后 SPACE 主动接应（TUBO 落水时） | 可选 | — | 不变 | audit PASS（实际 SHARK，设计答案 leap；可过 jump/leap/dive_jump/leap_jump） |
| G07 | Z1 | SURFACE_ROCK | 8262 | 动态单点 | 动态 | 看岩面：跳；动态时读浪相位；读运动相位 | TUBO | 跳过去 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 8400→8262 | audit PASS（实际 SURFACE_ROCK，设计答案 jump；可过 jump/leap/dive_jump） |
| G08 | Z1 | LOW_BEAM | 9369 | 单点 | 技能机会 | 看梁高：趴低；可护盾抢精准 | TUBO | 趴低 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 9600→9369 | audit PASS（实际 LOW_BEAM，设计答案 crouch；可过 crouch） |
| G09 | Z1 | HIGH_WALL | 10716 | 组合 | 组合 | 跃起高度与第二段蹬踏时机 | 双角色 | BITT 跃 → SHIFT → TUBO 蹬 | 用 SHIFT 接力把两段接起来；不按 SPACE 也能普通过 | 必需 | 救援 | x 10860→10716 | audit PASS（实际 HIGH_WALL，设计答案 leap_jump；可过 leap_jump） |
| G10 | Z1 | DIVE_GATE | 12182 | 单点 | 缓冲 | 看闸底：下潜 | BITT | 按住 ↓ 下潜 | SHIFT 到 BITT 后 SPACE 主动接应（TUBO 落水时） | 可选 | — | x 12000→12182 | audit PASS（实际 DIVE_GATE，设计答案 dive；可过 dive） |
| G11 | Z1 | LOW_BIRD | 13394 | 单点 | 技能机会 | 看海鸟俯冲相位：趴低或下潜 | TUBO | 趴低；也可跳/下潜 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 13280→13394 | audit PASS（实际 LOW_BIRD，设计答案 crouch；可过 crouch/dive） |
| G12 | Z1 | LOW_BEAM | 14770 | 单点 | 缓冲 | 看梁高：趴低；可护盾抢精准 | TUBO | 趴低 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 14550→14770 | audit PASS（实际 LOW_BIRD，设计答案 crouch；可过 crouch/dive；本局食物抽签 LOW_BEAM→LOW_BIRD） |
| G13 | Z2 | SHARK | 15800 | 动态单点 | 动态 | 看水下伏击预警：跃起；读运动相位 | BITT | 跃起 | SHIFT 到 BITT 后 SPACE 主动接应（TUBO 落水时） | 可选 | — | 不变 | audit PASS（实际 SHARK，设计答案 leap；可过 jump/leap/dive_jump/leap_jump/none） |
| G14 | Z2 | LOW_BEAM | 16760 | 单点 | 紧凑 | 看梁高：趴低；可护盾抢精准 | TUBO | 趴低 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 16750→16760 | audit PASS（实际 LOW_BEAM，设计答案 crouch；可过 crouch） |
| G15 | Z2 | SURFACE_ROCK | 17843 | 动态单点 | 动态 | 看岩面：跳；动态时读浪相位；读运动相位 | TUBO | 跳过去 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 17770→17843；phase 0.00→0.18 | audit PASS（实际 SURFACE_ROCK，设计答案 jump；可过 jump/crouch/leap/dive_jump） |
| G16 | Z2 | DIVE_GATE | 18924 | 单点 | 单独 | 看闸底：下潜 | BITT | 按住 ↓ 下潜 | SHIFT 到 BITT 后 SPACE 主动接应（TUBO 落水时） | 可选 | — | x 19200→18924 | audit PASS（实际 SHARK，设计答案 leap；可过 jump/leap/dive_jump/leap_jump/none；本局食物抽签 DIVE_GATE→SHARK） |
| G17 | Z2 | LOW_BIRD | 20228 | 单点 | 技能机会 | 看海鸟俯冲相位：趴低或下潜 | TUBO | 趴低；也可跳/下潜 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 20600→20228 | audit PASS（实际 LOW_BIRD，设计答案 crouch；可过 crouch/dive/leap_jump） |
| G18 | Z2 | FLOATING_LOG | 21613 | 组合 | 组合 | 跳与潜的先后：先跳再换手；读运动相位 | 双角色 | TUBO 跳 → SHIFT → BITT 潜 | 用 SHIFT 接力把两段接起来；不按 SPACE 也能普通过 | 必需 | 救援 | x 21950→21613；phase 0.00→0.22 | audit PASS（实际 FLOATING_LOG，设计答案 dive_jump；可过 dive/dive_jump） |
| G19 | Z2 | SURFACE_ROCK | 23097 | 动态单点 | 动态 | 看岩面：跳；动态时读浪相位；读运动相位 | TUBO | 跳过去 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 23200→23097；phase 0.00→0.47 | audit PASS（实际 SURFACE_ROCK，设计答案 jump；可过 jump/leap/dive_jump） |
| G20 | Z2 | LOW_BEAM | 24117 | 单点 | 紧凑 | 看梁高：趴低；可护盾抢精准 | TUBO | 趴低 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 24400→24117 | audit PASS（实际 LOW_BEAM，设计答案 crouch；可过 crouch） |
| G21 | Z2 | HIGH_WALL | 25210 | 组合 | 组合 | 跃起高度与第二段蹬踏时机 | 双角色 | BITT 跃 → SHIFT → TUBO 蹬 | 用 SHIFT 接力把两段接起来；不按 SPACE 也能普通过 | 必需 | 救援 | x 25600→25210 | audit PASS（实际 HIGH_WALL，设计答案 leap_jump；可过 leap_jump） |
| G22 | Z2 | SURFACE_ROCK | 26200 | 单点 | 技能机会 | 看岩面：跳；动态时读浪相位 | TUBO | 跳过去 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 26800→26200 | audit PASS（实际 DIVE_GATE，设计答案 dive；可过 dive；本局食物抽签 SURFACE_ROCK→DIVE_GATE） |
| G23 | Z2 | DIVE_GATE | 27465 | 单点 | 单独 | 看闸底：下潜 | BITT | 按住 ↓ 下潜 | SHIFT 到 BITT 后 SPACE 主动接应（TUBO 落水时） | 可选 | — | x 28000→27465 | audit PASS（实际 DIVE_GATE，设计答案 dive；可过 dive） |
| G24 | Z2 | LOW_BIRD | 28909 | 单点 | 缓冲 | 看海鸟俯冲相位：趴低或下潜 | TUBO | 趴低；也可跳/下潜 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 29200→28909 | audit PASS（实际 LOW_BIRD，设计答案 crouch；可过 crouch/dive/leap_jump） |
| G25 | Z2 | FLOATING_LOG | 30481 | 组合 | 组合 | 跳与潜的先后：先跳再换手 | 双角色 | TUBO 跳 → SHIFT → BITT 潜 | 用 SHIFT 接力把两段接起来；不按 SPACE 也能普通过 | 必需 | 救援 | x 30550→30481 | audit PASS（实际 FLOATING_LOG，设计答案 dive_jump；可过 dive_jump） |
| G26 | Z2 | SURFACE_ROCK | 31403 | 动态单点 | 动态 | 看岩面：跳；动态时读浪相位；读运动相位 | TUBO | 跳过去 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 31800→31403；phase 0.00→0.63 | audit PASS（实际 SURFACE_ROCK，设计答案 jump；可过 jump/leap/dive_jump） |
| G27 | Z2 | LOW_BEAM | 32437 | 单点 | 紧凑 | 看梁高：趴低；可护盾抢精准 | TUBO | 趴低 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 33000→32437 | audit PASS（实际 LOW_BEAM，设计答案 crouch；可过 crouch） |
| G28 | Z2 | SHARK | 33567 | 动态单点 | 动态 | 看水下伏击预警：跃起；读运动相位 | BITT | 跃起 | SHIFT 到 BITT 后 SPACE 主动接应（TUBO 落水时） | 可选 | — | x 34200→33567 | audit PASS（实际 SHARK，设计答案 leap；可过 jump/leap/dive_jump/leap_jump/none） |
| G29 | Z2 | LOW_BIRD | 34761 | 单点 | 技能机会 | 看海鸟俯冲相位：趴低或下潜 | TUBO | 趴低；也可跳/下潜 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 35400→34761 | audit PASS（实际 LOW_BIRD，设计答案 crouch；可过 crouch/dive/leap_jump） |
| G30 | Z2 | FLOATING_LOG | 36146 | 组合 | 组合 | 跳与潜的先后：先跳再换手 | 双角色 | TUBO 跳 → SHIFT → BITT 潜 | 用 SHIFT 接力把两段接起来；不按 SPACE 也能普通过 | 必需 | 救援 | x 36750→36146 | audit PASS（实际 FLOATING_LOG，设计答案 dive_jump；可过 dive_jump） |
| G31 | Z2 | DIVE_GATE | 37630 | 单点 | 缓冲 | 看闸底：下潜 | BITT | 按住 ↓ 下潜 | SHIFT 到 BITT 后 SPACE 主动接应（TUBO 落水时） | 可选 | — | 不变 | audit PASS（实际 DIVE_GATE，设计答案 dive；可过 dive） |
| G32 | Z3 | SHARK | 39200 | 动态单点 | 动态 | 看水下伏击预警：跃起；读运动相位 | BITT | 跃起 | SHIFT 到 BITT 后 SPACE 主动接应（TUBO 落水时） | 可选 | — | 不变 | audit PASS（实际 SHARK，设计答案 leap；可过 jump/leap/dive_jump） |
| G33 | Z3 | LOW_BEAM | 40245 | 单点 | 紧凑 | 看梁高：趴低；可护盾抢精准 | TUBO | 趴低 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 40270→40245 | audit PASS（实际 LOW_BEAM，设计答案 crouch；可过 crouch） |
| G34 | Z3 | SURFACE_ROCK | 41425 | 动态单点 | 动态 | 看岩面：跳；动态时读浪相位；读运动相位 | TUBO | 跳过去 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 41450→41425；phase 0.00→0.31 | audit PASS（实际 SURFACE_ROCK，设计答案 jump；可过 jump/crouch/leap/dive_jump） |
| G35 | Z3 | DIVE_GATE | 42581 | 单点 | 紧凑 | 看闸底：下潜 | BITT | 按住 ↓ 下潜 | SHIFT 到 BITT 后 SPACE 主动接应（TUBO 落水时） | 可选 | — | x 42580→42581 | audit PASS（实际 DIVE_GATE，设计答案 dive；可过 dive） |
| G36 | Z3 | FLOATING_LOG | 43839 | 组合 | 组合 | 跳与潜的先后：先跳再换手；读运动相位 | 双角色 | TUBO 跳 → SHIFT → BITT 潜 | 用 SHIFT 接力把两段接起来；不按 SPACE 也能普通过 | 必需 | 救援 | x 44110→43839 | audit PASS（实际 FLOATING_LOG，设计答案 dive_jump；可过 dive/dive_jump） |
| G37 | Z3 | LOW_BIRD | 45025 | 单点 | 技能机会 | 看海鸟俯冲相位：趴低或下潜 | TUBO | 趴低；也可跳/下潜 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 45250→45025 | audit PASS（实际 LOW_BIRD，设计答案 crouch；可过 crouch/dive/leap_jump） |
| G38 | Z3 | HIGH_WALL | 46325 | 组合 | 组合 | 跃起高度与第二段蹬踏时机 | 双角色 | BITT 跃 → SHIFT → TUBO 蹬 | 用 SHIFT 接力把两段接起来；不按 SPACE 也能普通过 | 必需 | 救援 | x 46370→46325 | audit PASS（实际 HIGH_WALL，设计答案 leap_jump；可过 leap_jump） |
| G39 | Z3 | LOW_BEAM | 47330 | 单点 | 紧凑 | 看梁高：趴低；可护盾抢精准 | TUBO | 趴低 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 47440→47330 | audit PASS（实际 LOW_BEAM，设计答案 crouch；可过 crouch） |
| G40 | Z3 | SURFACE_ROCK | 48500 | 动态单点 | 动态 | 看岩面：跳；动态时读浪相位；读运动相位 | TUBO | 跳过去 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 48610→48500；phase 0.00→0.52 | audit PASS（实际 SURFACE_ROCK，设计答案 jump；可过 jump/leap/dive_jump） |
| G41 | Z3 | DIVE_GATE | 49666 | 单点 | 紧凑 | 看闸底：下潜 | BITT | 按住 ↓ 下潜 | SHIFT 到 BITT 后 SPACE 主动接应（TUBO 落水时） | 可选 | — | x 49750→49666 | audit PASS（实际 DIVE_GATE，设计答案 dive；可过 dive） |
| G42 | Z3 | FLOATING_LOG | 51344 | 组合 | 组合 | 跳与潜的先后：先跳再换手；读运动相位 | 双角色 | TUBO 跳 → SHIFT → BITT 潜 | 用 SHIFT 接力把两段接起来；不按 SPACE 也能普通过 | 必需 | 救援 | x 51650→51344；phase 0.00→0.14 | audit PASS（实际 FLOATING_LOG，设计答案 dive_jump；可过 dive/dive_jump） |
| G43 | Z3 | SHARK | 52530 | 动态单点 | 动态 | 看水下伏击预警：跃起；读运动相位 | BITT | 跃起 | SHIFT 到 BITT 后 SPACE 主动接应（TUBO 落水时） | 可选 | — | x 53910→52530；序 G44→G43 | audit PASS（实际 SHARK，设计答案 leap；可过 jump/leap/dive_jump） |
| G44 | Z3 | LOW_BIRD | 53780 | 单点 | 技能机会 | 看海鸟俯冲相位：趴低或下潜 | TUBO | 趴低；也可跳/下潜 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 52800→53780；序 G43→G44 | audit PASS（实际 LOW_BEAM，设计答案 crouch；可过 crouch；本局食物抽签 LOW_BIRD→LOW_BEAM） |
| G45 | Z3 | LOW_BEAM | 54865 | 单点 | 紧凑 | 看梁高：趴低；可护盾抢精准 | TUBO | 趴低 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 55040→54865 | audit PASS（实际 SHARK，设计答案 leap；可过 jump/leap/dive_jump；本局食物抽签 LOW_BEAM→SHARK） |
| G46 | Z3 | FLOATING_LOG | 56045 | 组合 | 组合 | 跳与潜的先后：先跳再换手 | 双角色 | TUBO 跳 → SHIFT → BITT 潜 | 用 SHIFT 接力把两段接起来；不按 SPACE 也能普通过 | 必需 | 救援 | x 57640→56045；序 G47→G46 | audit PASS（实际 FLOATING_LOG，设计答案 dive_jump；可过 dive_jump） |
| G47 | Z3 | SURFACE_ROCK | 57103 | 动态单点 | 动态 | 看岩面：跳；动态时读浪相位；读运动相位 | TUBO | 跳过去 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 56180→57103；序 G46→G47；phase 0.00→0.71 | audit PASS（实际 SURFACE_ROCK，设计答案 jump；可过 jump/crouch/leap/dive_jump） |
| G48 | Z3 | SHARK | 58301 | 动态单点 | 动态 | 看水下伏击预警：跃起；读运动相位 | BITT | 跃起 | SHIFT 到 BITT 后 SPACE 主动接应（TUBO 落水时） | 可选 | — | x 59720→58301；序 G49→G48 | audit PASS（实际 SHARK，设计答案 leap；可过 jump/leap/dive_jump） |
| G49 | Z3 | LOW_BIRD | 59525 | 单点 | 技能机会 | 看海鸟俯冲相位：趴低或下潜 | TUBO | 趴低；也可跳/下潜 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 58640→59525；序 G48→G49 | audit PASS（实际 SURFACE_ROCK，设计答案 jump；可过 jump/leap/dive_jump/leap_jump；本局食物抽签 LOW_BIRD→SURFACE_ROCK） |
| G50 | Z3 | LOW_BEAM | 60835 | 单点 | 技能机会 | 看梁高：趴低；可护盾抢精准 | TUBO | 趴低 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 60820→60835 | audit PASS（实际 LOW_BEAM，设计答案 crouch；可过 crouch） |
| G51 | Z3 | FLOATING_LOG | 61980 | 组合 | 组合 | 跳与潜的先后：先跳再换手 | 双角色 | TUBO 跳 → SHIFT → BITT 潜 | 用 SHIFT 接力把两段接起来；不按 SPACE 也能普通过 | 必需 | 救援 | x 64560→61980；序 G53→G51 | audit PASS（实际 FLOATING_LOG，设计答案 dive_jump；可过 dive_jump） |
| G52 | Z3 | SURFACE_ROCK | 63012 | 动态单点 | 动态 | 看岩面：跳；动态时读浪相位；读运动相位 | TUBO | 跳过去 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 61940→63012；序 G51→G52；phase 0.00→0.27 | audit PASS（实际 LOW_BEAM，设计答案 crouch；可过 crouch；本局食物抽签 SURFACE_ROCK→LOW_BEAM） |
| G53 | Z3 | DIVE_GATE | 64188 | 单点 | 紧凑 | 看闸底：下潜 | BITT | 按住 ↓ 下潜 | SHIFT 到 BITT 后 SPACE 主动接应（TUBO 落水时） | 可选 | — | x 63040→64188；序 G52→G53 | audit PASS（实际 DIVE_GATE，设计答案 dive；可过 dive） |
| G54 | Z3 | LOW_BIRD | 65446 | 单点 | 技能机会 | 看海鸟俯冲相位：趴低或下潜 | TUBO | 趴低；也可跳/下潜 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | x 65600→65446 | audit PASS（实际 LOW_BIRD，设计答案 crouch；可过 crouch/dive/leap_jump） |
| G55 | Z3 | SURFACE_ROCK | 66720 | 动态单点 | 动态 | 看岩面：跳；动态时读浪相位；读运动相位 | TUBO | 跳过去 | SPACE 护盾精准反击，再决定是否 SHIFT | 可选 | 护盾 | phase 0.00→0.58 | audit PASS（实际 SURFACE_ROCK，设计答案 jump；可过 jump/crouch/leap/dive_jump） |

## 硬指标

| 指标 | 要求 | 实测 |
|---|---|---|
| 连续同节奏 | ≤2 | 2 |
| 连续同主角色 | ≤2 | 2 |
| 双角色组 | ≥12 | 33 |
| 动态组 | ≥10 | 18 |
| 护盾机会 | ≥8 | 30 |
| 救援机会 | ≥4 | 11 |
| 缓冲/学习 | ≥8 | 15 |
| 任意 5 组 ≥3 种节奏 | 全部 | 51/51 |
| 普通路线不按 SPACE | ≥一半 | 44/55 |
| 最小反应时间（上一组末端到下一组起点） | ≥3.5 s | 3.58 s |
| solution audit 无解组 | 0 | 0 |
| solution audit 设计答案正确 | 55 | 55 |
