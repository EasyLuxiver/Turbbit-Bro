# 游戏内文本清单（FEEL-11）

> 目的：把玩家可见文本按“出现在哪里 / 起什么作用”摊开，方便直接改字。
> 稳定 ID 不要改；只改 `zh` / `en` 文本。CSV 版：`feel11-text-inventory.csv`。

## 改字前必须知道的 7 件事

1. **ID 是代码契约**：`Locale.t("...")`、`state.*`、`accident.*`、`grade.*`、`zone.*` 都是按 ID 取字，改 ID 会静默回退成 ID 本身。只改 `zh` / `en`。
2. **HUD 键帽靠文字里的 ↑/↓/SHIFT 识别**（`hud.gd:748`）：提示里保留这些符号，或同步改识别逻辑，否则键帽图标会消失。
3. **成对提示**：`prompt.*_from_turtle` / `*_on_turtle` 是“当前控的是谁”的另一套说法；改默认提示时两条一起改。
4. **占位符**：`{0}`、`{1}`、`{2}` 是运行时参数；结算页还有靠空格对齐的列，改字后要回看 1280/1600 两种宽度。
5. **术语基线（FEEL-11 已定）**：失误槽 = `BRO 槽`；干净通过 = `默契`；换人动作 = `换人`；故事用 TUBO/BITT，即时提示用兔子/乌龟。新增文本沿用这套。
6. **`hazard.*` / `action.*` 多数是调试/旧 HUD 的键**，改它们不一定改到玩家看到的字；真正玩家可见的是 `prompt.*` / `lesson.*` / `hint.*` / `feedback.*`。
7. **测试专用文本**（制作人菜单、P0-C 提示）不在 Locale 里，别把它们的口吻带进正式关卡。

## FEEL-11 已处理的文本问题

1. `center.bro_full` 已改成“两人同时出事 —— 一起翻船！”，不再把原因归到 BRO 槽满。
2. `hint.dive_late` 已改成“按住 ↓ 下潜；过木后松手上浮”，和真实辅助下潜一致。
3. 食物规则：`opening.food` / `pause.food` 保留完整规则；`hud.snack_preview` / `hint.snack` 缩成必要信息。
4. 术语：失误槽统一叫“BRO 槽”，干净通过叫“默契”，换人动作统一叫“换人”；故事用 TUBO/BITT，即时提示用兔子/乌龟。
5. 主菜单已移除“阶段 4 / 完整赛道 / 3 个区域”；改为大表哥训练邀请 + “开始挑战”。
6. `prompt.*` 已缩短成“角色 + 一个动作 + 按键”；失败后的“为什么”留在 `hint.*` / `lesson.*`。
7. P0-C 测试段的 `CURRENT` / `下潜` / `起跳` / 绞盘文字仍只在测试段，不进入正式 55 组。

## 总览

| 组 | 条数 | 作用 |
|---|---:|---|
| 主菜单 / 设置 / 退出 | 25 | 决定第一印象与基本操作入口 |
| 开场 | 4 | 在没有障碍的低压力画面里讲第一课 |
| 开场连环画 | 12 | 用画面讲清共享意识的来历 |
| 教学 | 12 | 四步实际问题操作 + 大表哥短句 |
| HUD | 58 | 持续可读的状态与时机 |
| 角色名 | 2 | 统一“兔子/乌龟”的称呼 |
| 角色状态 | 37 | 让玩家读出当前姿态/危险 |
| 障碍名 | 16 | 障碍的正式名字；多数不在主 HUD 常驻 |
| 动作名 | 12 | 障碍对应动作的短名 |
| 首次教学 | 13 | “谁 + 为什么 + 按什么”的第一课 |
| 情境提示 | 19 | 解释刚刚发生了什么、下一步怎么做 |
| 动作提示 | 23 | 当前该按什么；按当前控制角色分两套 |
| 即时反馈 | 36 | 告诉玩家动作成功/失败/状态变化 |
| 大字横幅 | 8 | 把重大后果说得比小字更重 |
| 中央大字 | 7 | 阶段性节点与强情绪 |
| 世界内文字 | 9 | 世界内的定位与规则提示 |
| 暂停页 | 10 | 玩家唯一能停下来读规则的地方 |
| 区域名/教学 | 6 | 三个区域的命名与一句话目标 |
| 评级 | 5 | 结算的情绪落点 |
| 结算页 | 23 | 本局数据、纪录、下一次建议 |
| 事故名 | 6 | 事故的正式短名 |
| 其他 | 0 | 未分类 |

## 主菜单 / 设置 / 退出

**出现位置**：主菜单按钮、标题、退出确认、设置页  
**作用**：决定第一印象与基本操作入口

| ID | 中文 | English | 备注 |
|---|---|---|---|
| `menu.title` | TURBBIT BRO! | TURBBIT BRO! |  |
| `menu.subtitle` | 兄弟俩，准备好接受训练了吗？ | BROS. READY FOR TRAINING? |  |
| `menu.stage` | 大表哥的水上训练挑战 | COUSIN'S WATER TRAINING CHALLENGE |  |
| `menu.best` | 最佳 {0} 秒   连击 {1} | BEST {0} s   STREAK {1} |  |
| `menu.no_record` | 还没有纪录 | NO RECORD YET |  |
| `menu.start` | 回车  -  开始比赛 | ENTER  -  START RACE |  |
| `menu.settings` | S  -  设置 | S  -  SETTINGS |  |
| `menu.quit` | Q / ESC  -  退出游戏 | Q / ESC  -  QUIT |  |
| `menu.language` | 语言：简体中文 | LANGUAGE: ENGLISH |  |
| `menu.start_game` | 开始挑战 | START CHALLENGE |  |
| `menu.producer` | 制作人测试 | PRODUCER TESTS |  |
| `menu.settings_button` | 设置 | SETTINGS |  |
| `menu.quit_button` | 退出游戏 | QUIT |  |
| `menu.keys` | ↑↓ 选择   Enter 确认   L 语言 | ↑↓ SELECT   ENTER CONFIRM   L LANGUAGE |  |
| `quit.title` | 要退出游戏吗？ | QUIT GAME? |  |
| `quit.body` | 还没冲线，退出后本局进度不会保留。 | The run is not finished. Progress will be lost. |  |
| `quit.yes` | 退出 | QUIT |  |
| `quit.no` | 取消 | CANCEL |  |
| `menu.hint` | SHIFT 换人    ↑ 兔子跳 / 乌龟跃起    ↓ 兔子趴低 / 乌龟下潜 | SHIFT transfer   ↑ RABBIT JUMP / TURTLE LEAP   ↓ RABBIT CROUCH / TURTLE DIVE |  |
| `settings.title` | 设置 | SETTINGS |  |
| `settings.language` | 语言    L - 切换（当前：简体中文） | LANGUAGE    L - SWITCH (CURRENT: ENGLISH) |  |
| `settings.back` | ESC / S  -  返回 | ESC / S  -  BACK |  |
| `settings.back_button` | 返回 | BACK |  |
| `settings.keys` | ↑↓ 选择   Enter 确认   L 切换语言 | ↑↓ SELECT   ENTER CONFIRM   L SWITCH LANGUAGE |  |
| `settings.note` | 语言只改变文字，不影响玩法、物理参数和比赛纪录。 | Language only changes text. It does not affect gameplay, physics, or records. |  |

## 开场

**出现位置**：比赛开始前的开场卡  
**作用**：在没有障碍的低压力画面里讲第一课

| ID | 中文 | English | 备注 |
|---|---|---|---|
| `opening.ready` | 准备好，兄弟？ | READY, BRO? |  |
| `opening.hint` | ↑ 跳跃    ↓ 趴低 | ↑ JUMP    ↓ CROUCH |  |
| `opening.food` | 能量海藻：操控乌龟吃 → 加速；操控兔子吃 → 下一跳更高；不吃也不扣分 | SNACK: DRIVE THE TURTLE TO EAT = TURBO; DRIVE THE RABBIT = HIGHER JUMP; SKIPPING IS FREE |  |
| `opening.skip` | 任意键跳过 | PRESS ANY KEY TO SKIP |  |

## 开场连环画

**出现位置**：7 格开场连环画  
**作用**：用画面讲清共享意识的来历

| ID | 中文 | English | 备注 |
|---|---|---|---|
| `comic.skip` | 任意键跳过 | PRESS ANY KEY TO SKIP |  |
| `comic.1.narr` | 上一次比赛，兄弟俩本来有机会赢。 | LAST RACE, THE BROS COULD HAVE WON. |  |
| `comic.1.rabbit` | 我就闭眼休息一下…… | JUST GONNA REST MY EYES... |  |
| `comic.2.turtle` | 你倒是醒醒啊！ | WAKE UP, MAN! |  |
| `comic.3.narr` | 大表哥决定亲自训练他们。 | COUSIN DECIDED TO TRAIN THEM HIMSELF. |  |
| `comic.3.cousin` | 你们缺的不是速度，是默契！ | YOU DON'T LACK SPEED. YOU LACK SYNC! |  |
| `comic.4.cousin` | 特制能量蛋糕！嘿嘿！ | SPECIAL ENERGY CAKE! HEH HEH! |  |
| `comic.5.bros` | 哇啊啊啊——！ | WHOA AAAA—! |  |
| `comic.6.narr` | 从那天起，他们偶尔会……交换控制权？ | SINCE THEN, THEY SOMETIMES... SWAP CONTROL? |  |
| `comic.6.rabbit` | 等等，刚刚是我在动吗？ | WAIT. WAS THAT ME MOVING? |  |
| `comic.7.cousin` | 很好！现在，给我跑出兄弟默契！ | GOOD! NOW SHOW ME THAT BRO SYNC! |  |
| `comic.7.narr` | 一场混乱又刺激的训练，正式开始。 | A CHAOTIC, WILD TRAINING STARTS NOW. |  |

## 教学

**出现位置**：60–90 s 教学覆盖层  
**作用**：四步实际问题操作 + 大表哥短句

| ID | 中文 | English | 备注 |
|---|---|---|---|
| `tutorial.title` | 大表哥的训练 | COUSIN'S TRAINING |  |
| `tutorial.step1` | 兔子！别光顾着跑，看看前面！ | RABBIT! STOP DAYDREAMING. WATCH AHEAD! |  |
| `tutorial.step1_hint` | TUBO：↑ 跳，↓ 趴低 | TUBO: ↑ JUMP, ↓ CROUCH | FEEL-10 新名；与“兔子/乌龟”混用，需统一 |
| `tutorial.step2` | 乌龟！稳住，水里才是你的主场！ | TURTLE! STEADY. THE WATER IS YOUR HOME! |  |
| `tutorial.step2_hint` | SHIFT 换 BITT：↑ 跃起，↓ 下潜 | SHIFT TO BITT: ↑ LEAP, ↓ DIVE | FEEL-10 新名；与“兔子/乌龟”混用，需统一 |
| `tutorial.step3` | 漂亮！别让另一个闲着！ | NICE! DON'T LEAVE THE OTHER ONE IDLE! |  |
| `tutorial.step3_hint` | ↑ 跳 → SHIFT → ↓ 潜 | ↑ JUMP → SHIFT → ↓ DIVE |  |
| `tutorial.step4` | 这次你们自己来！ | THIS ONE IS ALL YOURS! |  |
| `tutorial.step4_hint` | 用你刚学会的交接，自己过 | USE THE RELAY YOU JUST LEARNED |  |
| `tutorial.done` | 很好！现在，给我跑出兄弟默契！ | GOOD! NOW SHOW ME THAT BRO SYNC! |  |
| `tutorial.skip` | K 跳过教学 | K SKIP TUTORIAL |  |
| `tutorial.fail` | 别急，看看下一步该谁动。 | EASY. CHECK WHO MOVES NEXT. |  |

## HUD

**出现位置**：左上角色面板、右上时间/区域/进度、底部氧气/食物/协作条  
**作用**：持续可读的状态与时机

| ID | 中文 | English | 备注 |
|---|---|---|---|
| `hud.control` | 控制    {0} | CONTROL   {0} |  |
| `hud.rabbit` | 兔子    {0}   抓地 {1}% | RABBIT    {0}   GRIP {1}% |  |
| `hud.turtle` | 乌龟    {0} | TURTLE    {0} |  |
| `hud.accident` | 事故    {0} | ACCIDENT  {0} |  |
| `hud.time` | 时间    {0} 秒 | TIME    {0} s |  |
| `hud.speed` | 速度    {0} | SPEED   {0} |  |
| `hud.cruise` | 巡航 | CRUISE |  |
| `hud.boost` | 加速 | BOOST |  |
| `hud.turbo` | 乌龟 TURBO！加速中 | TURTLE TURBO! |  |
| `hud.rabbit_boost` | 兔子！下一跳更高 | RABBIT! HIGHER JUMP |  |
| `hud.snack_ahead` | 海藻在前 · 当前：{0}会吃 | SNACK AHEAD · {0} EATS NOW |  |
| `hud.snack_cant` | 海藻在前 · 现在够不到（回巡航 / 落地再吃） | SNACK AHEAD · OUT OF REACH (CRUISE OR LAND TO EAT) |  |
| `hud.snack_preview` | 海藻：兔子吃 ↑ / 乌龟吃 » | SNACK: RABBIT ↑ / TURTLE » |  |
| `hud.zone` | 区域 {0}/3  {1} | ZONE {0}/3  {1} |  |
| `hud.progress` | 进度 {0}%   {1}/{2} 组 | PROGRESS {0}%   {1}/{2} GROUPS |  |
| `hud.air` | 氧气    {0} 秒   {1} | AIR      {0} s   {1} |  |
| `hud.surface` | 水面 - 恢复中 | SURFACE - RECOVERING |  |
| `hud.emergency` | 紧急上浮 | EMERGENCY ASCENT |  |
| `hud.airborne` | 空中 - 不耗氧 | AIRBORNE - NO DRAIN |  |
| `hud.rescuing` | 救援中 {0}s - 潜到兔子下面 | RESCUE {0}s - DIVE UNDER THE RABBIT |  |
| `hud.rescuing_air` | 救援中 {0}s - 跃起接住 | RESCUE {0}s - LEAP TO CATCH |  |
| `hud.rescue_return` | 兔子回壳中 {0}s | RABBIT RETURNING {0}s |  |
| `hud.underwater` | 水下 - 耗氧中 | UNDERWATER - DRAINING |  |
| `hud.undertow` | 暗流 - 壳沉太深，换给乌龟抬起来 | UNDERTOW - TOO DEEP, GIVE IT TO THE TURTLE |  |
| `hud.brotherhood` | 兄弟情    {0} | BROTHERHOOD  {0} | BRO METER / 默契 / 兄弟情 术语混用，建议统一 |
| `hud.clean` | 干净通过  {0}/{1} | CLEAN PASSES  {0}/{1} |  |
| `hud.clean_best` | 干净通过  {0}/{1}   最佳 {2} | CLEAN PASSES  {0}/{1}   BEST {2} |  |
| `hud.showtime` | SHOWTIME  {0} 秒 | SHOWTIME  {0} s |  |
| `hud.showtime_ready` | SHOWTIME 就绪 | SHOWTIME READY |  |
| `hud.showtime_banner` | 操控乌龟 · SHIFT 中止 | DRIVE TURTLE · SHIFT TO ABORT |  |
| `hud.warn` | {0}  {1} px  -  {2} | {0}  {1} px  -  {2} |  |
| `hud.control_now` | SHIFT   当前控制：{0} | SHIFT   CONTROL: {0} |  |
| `hud.acting` | 操控 · {0} | DRIVING · {0} |  |
| `hud.standby_stable` | 待命 · 稳定 | STANDBY · STABLE |  |
| `hud.standby_risk` | 待命 · 不稳 | STANDBY · WOBBLY |  |
| `hud.drift_distracted` | 开始神游 | DRIFTING |  |
| `hud.drift_restless` | 坐不住了 | FIDGETY |  |
| `hud.drift_mischief` | 要惹麻烦 | TROUBLE |  |
| `hud.drift_effect_rabbit` | 空中修正 {0}% · 身偏 {1}px | AIR {0}% · {1}px OFF |  |
| `hud.drift_effect_turtle` | 巡航 {0}% · 壳晃 {1}px | CRUISE {0}% · BOB {1}px |  |
| `hud.drift_recover_rabbit` | 回神中 · 空中修正 {0}% | RECOVER · AIR {0}% |  |
| `hud.drift_recover_turtle` | 回神中 · 巡航 {0}% | RECOVER · CRUISE {0}% |  |
| `hud.drift_recovering` | 回神中 | RECOVER |  |
| `hud.rabbit_risk` | 兔子晃动 {0}% | RABBIT WOBBLE {0}% |  |
| `hud.turtle_risk` | 乌龟晃动 {0}% | TURTLE WOBBLE {0}% |  |
| `hud.coop_prepare` | {0}  准备 | {0}  GET READY |  |
| `hud.coop_now` | {0}  现在！ | {0}  NOW! |  |
| `hud.coop_missed` | {0}  已错过 | {0}  MISSED |  |
| `hud.coop_tag` | 可 {0} | {0} READY |  |
| `hud.coop_assist` | 配合 | ASSIST |  |
| `hud.coop_release` | 松开 ↓ 上浮接人！ | RELEASE ↓ - SURFACE & CATCH! |  |
| `hud.oxygen` | 氧气 {0}s | AIR {0}s |  |
| `hud.oxygen_recovering` | 水面恢复中 | SURFACE - RECOVERING |  |
| `hud.oxygen_low` | 氧气偏低 | AIR LOW |  |
| `hud.oxygen_critical` | 氧气告急 | AIR CRITICAL |  |
| `hud.bond` | 默契 {0}/{1} | BRO PASS {0}/{1} | BRO METER / 默契 / 兄弟情 术语混用，建议统一 |
| `hud.showtime_t` | SHOWTIME {0}s  剩 | SHOWTIME {0}s LEFT |  |
| `hud.bro_meter` | BRO 槽 {0}/{1} | BRO METER {0}/{1} | BRO METER / 默契 / 兄弟情 术语混用，建议统一 |

## 角色名

**出现位置**：HUD 与提示里的角色称呼  
**作用**：统一“兔子/乌龟”的称呼

| ID | 中文 | English | 备注 |
|---|---|---|---|
| `who.rabbit` | 兔子 | RABBIT |  |
| `who.turtle` | 乌龟 | TURTLE |  |

## 角色状态

**出现位置**：HUD 角色行、世界内角色旁边的小字  
**作用**：让玩家读出当前姿态/危险

| ID | 中文 | English | 备注 |
|---|---|---|---|
| `state.RIDING` | 骑乘 | RIDING |  |
| `state.RECOVERING` | 恢复中 | RECOVERING |  |
| `state.RELAXED` | 神游 | RELAXED |  |
| `state.NO_POWER` | 无动力 | NO POWER |  |
| `state.TOO_DEEP` | 过深 | TOO DEEP |  |
| `state.SLIDING` | 正在滑落 | SLIPPING |  |
| `state.EDGE` | 快掉了 | ABOUT TO FALL |  |
| `state.STUNNED` | 眩晕 | STUNNED |  |
| `state.SHOWTIME` | 表演 | SHOWTIME |  |
| `state.AIRBORNE` | 空中 | AIRBORNE |  |
| `state.WAITING_CATCH` | 落水 · 等接应 | IN WATER · WAIT |  |
| `state.CRUISING` | 巡航 | CRUISING |  |
| `state.BOOSTING` | 加速 | BOOSTING |  |
| `state.SURFACING` | 上浮 | SURFACING |  |
| `state.DIVING` | 下潜 | DIVING |  |
| `state.CROUCHING` | 趴低 | CROUCHING |  |
| `state.GRIPPING` | 抓紧 | GRIPPING |  |
| `state.LEAPING` | 跃起 | LEAPING |  |
| `state.POPPING` | 拍水跃浪 | WATER POP |  |
| `state.DUNKED` | 被浪压进水里 | DUNKED |  |
| `state.BELLY_UP` | 翻肚皮 | BELLY UP |  |
| `state.UNSTEADY` | 轻微晃动 | UNSTEADY |  |
| `state.WOBBLING` | 明显摇晃 | WOBBLING |  |
| `state.FLIP_RISK` | 要翻了 | FLIP RISK |  |
| `state.DAZED` | 恍惚 | DAZED |  |
| `state.SINKING` | 下沉 | SINKING |  |
| `state.DEEP` | 过深 | DEEP |  |
| `state.DANGER` | 危险 | DANGER |  |
| `state.UNCONSCIOUS` | 昏迷 | UNCONSCIOUS |  |
| `state.EMERGENCY` | 紧急 | EMERGENCY |  |
| `state.JUMPING` | 跳跃 | JUMPING |  |
| `state.FALLING` | 下落 | FALLING |  |
| `state.RESCUING` | 救援 | RESCUING |  |
| `state.SAFE` | 安全 | SAFE |  |
| `state.LOW` | 偏低 | LOW |  |
| `state.CRITICAL` | 告急 | CRITICAL |  |
| `state.EMPTY` | 耗尽 | EMPTY |  |

## 障碍名

**出现位置**：调试层/旧 HUD/关卡数据映射  
**作用**：障碍的正式名字；多数不在主 HUD 常驻

| ID | 中文 | English | 备注 |
|---|---|---|---|
| `hazard.low_rock` | 低岩 | LOW ROCK | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `hazard.low_beam` | 低梁 | LOW BEAM | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `hazard.wide_wave` | 宽浪 | WIDE WAVE | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `hazard.low_bird` | 低飞海鸟 | LOW BIRD | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `hazard.dock_beam` | 码头横梁 | DOCK BEAM | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `hazard.shark` | 鲨鱼 | SHARK | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `hazard.dive_gate` | 水下拱岩 | REEF ARCH | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `hazard.floating_log` | 浮木 | FLOATING LOG | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `hazard.high_wall` | 高墙 | HIGH WALL | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `hazard.reef` | 暗礁 | REEF | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `hazard.reef_chain` | 礁链 | REEF CHAIN | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `hazard.long_wall` | 长墙 | LONG WALL | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `hazard.sink_gate` | 下沉门 | SINK GATE | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `hazard.final_gate` | 终点门 | FINAL GATE | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `hazard.low_bar` | 低杆 | LOW BAR | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `hazard.rock_beam` | 岩石 + 横梁 | ROCK + BEAM | 多为调试/旧键，改它不一定改到玩家看到的字 |

## 动作名

**出现位置**：调试层/旧 HUD/关卡数据映射  
**作用**：障碍对应动作的短名

| ID | 中文 | English | 备注 |
|---|---|---|---|
| `action.jump_or_dive` | 跳过去 | JUMP OVER | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `action.crouch_or_dive` | 趴下 | CROUCH DOWN | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `action.water_pop` | 拍水跃浪 | SPACE WATER POP | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `action.leap` | 乌龟 ↑ 跃起 | TURTLE ↑ LEAP | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `action.dive` | 乌龟 ↓ 下潜 | TURTLE ↓ DIVE | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `action.jump_and_dive` | 兔子跳 + 乌龟潜 | RABBIT JUMP + TURTLE DIVE | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `action.stay_high` | 保持水面 | STAY HIGH | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `action.dive_through` | 换人让壳沉 | HAND OVER TO SINK | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `action.take_rabbit` | 换给兔子 | TAKE THE RABBIT | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `action.dont_jump` | 别跳 | DON'T JUMP | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `action.jump_then_crouch` | 先跳再趴 | JUMP THEN CROUCH | 多为调试/旧键，改它不一定改到玩家看到的字 |
| `action.crouch_after_landing` | 落地后趴下 | CROUCH AFTER LANDING | 多为调试/旧键，改它不一定改到玩家看到的字 |

## 首次教学

**出现位置**：底部提示栏，第一次遇到某类障碍时  
**作用**：“谁 + 为什么 + 按什么”的第一课

| ID | 中文 | English | 备注 |
|---|---|---|---|
| `lesson.rock` | 跳过岩石 - 按 SHIFT 换兔子，再按 ↑ 起跳 | JUMP THE ROCK - SHIFT TO THE RABBIT, THEN ↑ | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `lesson.beam` | 趴低过梁 - 按 SHIFT 换兔子，再按 ↓ 趴低 | CROUCH UNDER THE BEAM - SHIFT TO THE RABBIT, THEN ↓ | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `lesson.wave` | 宽浪 - 按 SHIFT 换成乌龟，按 SPACE 拍水跃浪 | WIDE WAVE - SHIFT TO THE TURTLE, PRESS SPACE TO POP | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `lesson.reef` | 暗礁在深处 - 贴着水面走 | REEFS SIT DEEP - STAY ON THE SURFACE |  |
| `lesson.wall` | 长墙 - 按 SHIFT 换给兔子，壳会自己沉下去 | LONG WALL - SHIFT TO THE RABBIT AND THE SHELL SINKS | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `lesson.sink_gate` | 下沉门 - 兔子掌权时龟壳会自己沉下去 | SINK GATE - THE SHELL SINKS WHILE THE RABBIT IS IN CHARGE |  |
| `lesson.airbar` | 低杆 - 让兔子留在龟壳上 | LOW BAR - KEEP THE RABBIT ON THE SHELL |  |
| `lesson.combo` | 连续三次干净通过会触发 SHOWTIME | THREE CLEAN PASSES TRIGGER SHOWTIME |  |
| `lesson.bird` | 低飞海鸟 - 按 SHIFT 换兔子按 ↓ 趴低，乌龟照常巡航 | LOW BIRD - SHIFT TO THE RABBIT AND PRESS ↓, THE SHELL KEEPS CRUISING | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `lesson.dock_beam` | 码头横梁 - 按 SHIFT 换兔子趴低过，龟壳不受影响 | DOCK BEAM - SHIFT TO THE RABBIT AND CROUCH, THE SHELL IS UNAFFECTED | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `lesson.gate` | 水下拱岩 - 按 SHIFT 换乌龟，按住 ↓ 潜过去 | REEF ARCH - SHIFT TO THE TURTLE AND HOLD ↓ | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `lesson.shark` | 鲨鱼从下面冲上来 - 按 SHIFT 换乌龟，再按 ↑ 跃起 | SHARK FROM BELOW - SHIFT TO THE TURTLE AND PRESS ↑ | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `lesson.log` | 浮木 - 兔子先跳，按 SHIFT 换乌龟下潜；越过木尾松开 ↓ 上浮接人 | FLOATING LOG - JUMP, SHIFT, DIVE. PAST THE LOG, RELEASE ↓ TO CATCH. | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |

## 情境提示

**出现位置**：底部提示栏、角色旁、碰撞后  
**作用**：解释刚刚发生了什么、下一步怎么做

| ID | 中文 | English | 备注 |
|---|---|---|---|
| `hint.take_rabbit` | 按 SHIFT 换兔子 - 这个只有兔子能躲 | PRESS SHIFT FOR THE RABBIT - ONLY IT CAN DODGE THIS | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `hint.air_low` | 氧气偏低 - 换回乌龟就上浮 | AIR LOW - TAKE THE TURTLE BACK |  |
| `hint.air_critical` | 氧气告急 - 马上换乌龟 | AIR CRITICAL - TURTLE NOW |  |
| `hint.clean_pass` | 干净通过  {0}/{1} | CLEAN PASS  {0}/{1} |  |
| `hint.pickup` | 接住了！ | PICKUP! |  |
| `hint.boost` | 加速带 - 操控乌龟时自动提速 | BOOST LANE - AUTOMATIC WHILE DRIVING THE TURTLE |  |
| `hint.snack` | 海藻：SHIFT 决定谁吃；不吃不扣分 | SNACK: SHIFT PICKS WHO EATS; SKIPPING IS FREE | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `hint.wave_hit` | 壳翻了 - 稳住，等它自己翻回来 | SHELL FLIPPED - STEADY, IT ROLLS BACK |  |
| `hint.shark_hit` | 鲨鱼只咬壳 - 按 ↑ 跃起躲开 | THE SHARK BITES THE SHELL - PRESS ↑ TO LEAP | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `hint.gate_hit` | 拱岩：按住 ↓ 潜到它下面再松 | REEF ARCH: HOLD ↓ UNTIL YOU'RE UNDER IT | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `hint.wall_hit` | 高墙：乌龟先 ↑ 跃起，兔子再蹬一下 | HIGH WALL: ↑ LEAP, THEN KICK WITH THE RABBIT | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `hint.dive_late` | 浮木：兔子起跳后 SHIFT 给乌龟，按住 ↓ 下潜；过木后松手上浮 | LOG: JUMP, THEN SHIFT TO TURTLE - HOLD ↓ TO DIVE; RELEASE TO SURFACE | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `hint.log_jump` | 浮木：先按 ↑ 让兔子起跳，再 SHIFT 给乌龟 | LOG: PRESS ↑ TO JUMP FIRST, THEN SHIFT TO THE TURTLE | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `hint.dive_deep` | 壳停得太深 - 浮木组合请先 ↑ 起跳再 SHIFT，下潜和上浮会自动完成 | SHELL TOO DEEP - FOR LOGS: ↑ JUMP THEN SHIFT; DIVE AND SURFACE ARE AUTOMATIC | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `hint.motion` | 这组会动 - 看准空隙再上 | THIS ONE MOVES - GO THROUGH THE GAP |  |
| `hint.motion_buoy` | 系泊浮标：锚绳拴在海底，随涌浪起落 - 等它落到低点再跳 | MOORING BUOY - ROPED TO THE SEABED, RIDES THE SWELL. JUMP AT THE LOW POINT |  |
| `hint.motion_hoist` | 吊装货箱：挂在码头吊钩上，跟着吊臂上下晃 - 看准它升起的那拍 | HOIST CRATE - HANGS FROM THE DOCK CRANE AND SWINGS WITH IT. TIME THE LIFT |  |
| `hint.motion_cargo` | 漂流货箱：从码头冲出来的货，随大浪浮沉 - 看准浪谷再跳 | DRIFTING CARGO - WASHED OUT FROM THE DOCK, RIDES THE SWELL. JUMP IN THE TROUGH |  |
| `hint.motion_eel` | 水渠鳗鱼：平时盘在水渠底，靠近时带电窜上来 - 提前跃起 | CANAL EEL - COILED ON THE CANAL BED, SPARKS AND LUNGES. LEAP EARLY |  |

## 动作提示

**出现位置**：底部中央提示栏，接近障碍时  
**作用**：当前该按什么；按当前控制角色分两套

| ID | 中文 | English | 备注 |
|---|---|---|---|
| `prompt.jump` | ↑ 跳跃 | ↑ JUMP | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `prompt.crouch` | ↓ 趴低 | ↓ CROUCH | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `prompt.pop` | SHIFT + SPACE 拍水跃浪 | SHIFT + SPACE WATER POP | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `prompt.rescue_shift` | SHIFT 乌龟 → 按住 ↓ 潜下去接住兔子 | SHIFT TURTLE → HOLD ↓ TO CATCH | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `prompt.rescue_dive` | 按住 ↓ 潜下去接住兔子 | HOLD ↓ TO CATCH THE RABBIT | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `prompt.rescue_leap_shift` | SHIFT 乌龟 → 按 ↑ 跃起接住兔子 | SHIFT TURTLE → ↑ TO CATCH | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `prompt.rescue_leap` | 按 ↑ 跃起接住兔子 | PRESS ↑ TO CATCH THE RABBIT | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `prompt.leap` | 鲨鱼 - SHIFT + ↑ 乌龟跃起 | SHARK - SHIFT + ↑ LEAP | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `prompt.dive` | 礁拱 - SHIFT + ↓ 按住下潜 | ARCH - SHIFT + ↓ HOLD | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `prompt.combo` | 浮木 - ↑ 跳 → SHIFT → ↓ 潜 | LOG - ↑ JUMP → SHIFT → ↓ DIVE | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `prompt.ollie` | 高墙 - SHIFT + ↑ 跃起 → SHIFT → ↑ 蹬踏 | WALL - SHIFT + ↑ LEAP → SHIFT → ↑ KICK | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `prompt.jump_from_turtle` | SHIFT 回兔子 → ↑ 跳跃 | SHIFT TO RABBIT → ↑ JUMP | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748；与默认 prompt 成对；改一条要改两条 |
| `prompt.crouch_from_turtle` | SHIFT 回兔子 → ↓ 趴低 | SHIFT TO RABBIT → ↓ CROUCH | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748；与默认 prompt 成对；改一条要改两条 |
| `prompt.leap_on_turtle` | 鲨鱼冲上来了 - ↑ 乌龟跃起 | SHARK IS UP - ↑ TURTLE LEAP | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748；与默认 prompt 成对；改一条要改两条 |
| `prompt.dive_on_turtle` | 礁拱下面就是通道 - 按住 ↓ 下潜 | THE GAP IS UNDER THE ARCH - HOLD ↓ DIVE | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748；与默认 prompt 成对；改一条要改两条 |
| `prompt.combo_from_turtle` | SHIFT 兔子 → ↑ 跳 → SHIFT → ↓ 潜 | SHIFT RABBIT → ↑ JUMP → SHIFT → ↓ DIVE | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748；与默认 prompt 成对；改一条要改两条 |
| `prompt.ollie_on_turtle` | 高墙 - ↑ 跃起 → SHIFT 兔子 → ↑ 蹬踏 | HIGH WALL - ↑ LEAP → SHIFT RABBIT → ↑ KICK | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748；与默认 prompt 成对；改一条要改两条 |
| `prompt.net` | 屋顶吊网压下来 - ↓ 趴低，从网底下过 | CARGO NET - ↓ CROUCH | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `prompt.net_from_turtle` | 吊网只压兔子层 - 按住 ↓ 下潜，从网底下过 | CARGO NET - HOLD ↓ DIVE | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748；与默认 prompt 成对；改一条要改两条 |
| `prompt.eel` | 水渠鳗鱼会从底下窜上来 - SHIFT + ↑ 乌龟跃起 | CANAL EEL - SHIFT + ↑ TURTLE LEAP | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `prompt.eel_on_turtle` | 鳗鱼从底下窜上来 - ↑ 乌龟跃起 | CANAL EEL - ↑ TURTLE LEAP | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748；与默认 prompt 成对；改一条要改两条 |
| `prompt.sluice` | 船闸只有乌龟潜得过去 - SHIFT + ↓ 按住下潜 | SLUICE GATE - SHIFT + ↓ HOLD | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748 |
| `prompt.sluice_on_turtle` | 闸板下面就是通道 - 按住 ↓ 下潜 | SLUICE GATE - HOLD ↓ DIVE | HUD 键帽依赖 ↑/↓/SHIFT，改字要保留符号或同步 hud.gd:748；与默认 prompt 成对；改一条要改两条 |

## 即时反馈

**出现位置**：底部反馈行、角色/世界特效文字  
**作用**：告诉玩家动作成功/失败/状态变化

| ID | 中文 | English | 备注 |
|---|---|---|---|
| `feedback.clean` | 干净通过！ | CLEAN! |  |
| `feedback.bro_pass` | 兄弟！漂亮！ | BRO PASS! |  |
| `feedback.bro_dive` | BRO DIVE！ | BRO DIVE! |  |
| `feedback.bro_ollie` | BRO OLLIE！ | BRO OLLIE! |  |
| `feedback.bro_combo` | BRO COMBO！ | BRO COMBO! |  |
| `feedback.pop` | 拍水跃浪！ | WATER POP! |  |
| `feedback.leap` | 跃起！ | LEAP! |  |
| `feedback.turbo` | TURBO！ 吞下去了！ | TURBO! GULP! |  |
| `feedback.snack_rabbit` | 兔子吃了！ 下一跳更高！ | RABBIT ATE! HIGHER JUMP! |  |
| `feedback.turbo_switch` | TURBO！亲手喂到！乌龟很满足！ | TURBO! HAND-FED! TURTLE LOVES IT! |  |
| `feedback.wave_hit` | 壳被浪掀翻了！ | WAVE HIT - SHELL FLIPPED! |  |
| `feedback.shark_hit` | 鲨鱼从下面来的 - 壳翻了！ | SHARK FROM BELOW - SHELL FLIPPED! |  |
| `feedback.gate_hit` | 没潜到位 - 壳撞上拱岩！ | NOT DEEP ENOUGH - HIT THE REEF ARCH! |  |
| `feedback.wall_hit` | 没跃过墙 - 壳撞上去了！ | MISSED THE OLLIE - SHELL HIT THE WALL! |  |
| `feedback.dive_late` | 下潜太晚 - 壳撞上浮木！ | DIVE TOO LATE - SHELL HIT THE LOG! |  |
| `feedback.log_jump` | 跳跃高度不对 - 撞上浮木！ | BAD JUMP ARC - HIT THE LOG! |  |
| `feedback.rescue_ok` | 接住了！兄弟！ | CAUGHT! BRO! |  |
| `feedback.rescue_reunion` | 兄弟回来了！右边这口气补上了 | BRO'S BACK! BOTH OF YOU CALM DOWN |  |
| `feedback.rescue_miss` | 没接住……兔子被冲回壳上 | MISSED... RABBIT WASHED BACK |  |
| `feedback.shift_take` | 换人 - {0}开始收心 | SWITCH - {0} RECOVERING |  |
| `feedback.shift_lock` | 换人间隔 0.2 秒 | SWAP LOCK 0.2s |  |
| `feedback.relay_clever` | 电流接力 +50 | RELAY +50 |  |
| `feedback.relay_perfect` | 完美接力 +100 | PERFECT RELAY +100 |  |
| `feedback.burst_rabbit_warn` | BITT 走神了——注意它下一步 | BITT IS DRIFTING - WATCH IT | FEEL-10 新名；与“兔子/乌龟”混用，需统一 |
| `feedback.burst_turtle_warn` | TUBO 走神了——注意壳的深度 | TUBO IS DRIFTING - WATCH THE SHELL | FEEL-10 新名；与“兔子/乌龟”混用，需统一 |
| `feedback.burst_rabbit` | BITT 不听指挥，自己趴下了！ | BITT IGNORED YOU AND CROUCHED! | FEEL-10 新名；与“兔子/乌龟”混用，需统一 |
| `feedback.burst_turtle` | TUBO 不听指挥，自己往下沉！ | TUBO IGNORED YOU AND DOVE! | FEEL-10 新名；与“兔子/乌龟”混用，需统一 |
| `feedback.burst_back` | 回过神了——重新接手 | BACK ONLINE - TAKE OVER |  |
| `feedback.showtime_reward` | SHOWTIME 完成  +100 分  ·  氧气 +{0} | SHOWTIME DONE  +100 PTS  ·  OXYGEN +{0} |  |
| `feedback.showtime_reward_full` | SHOWTIME 完成  +100 分  ·  氧气已满 | SHOWTIME DONE  +100 PTS  ·  OXYGEN FULL |  |
| `feedback.drift_back` | {0}回过神了 | {0} IS BACK |  |
| `feedback.drift_warn_restless` | {0}坐不住了：{1} | {0} IS FIDGETY: {1} |  |
| `feedback.drift_warn_mischief` | {0}要惹麻烦了：{1} | {0} IS ACTING UP: {1} |  |
| `feedback.drift_lag_rabbit` | BITT 走神了 - 蹦跳慢了半拍 | BITT IS DAYDREAMING - SLOW TO JUMP | FEEL-10 新名；与“兔子/乌龟”混用，需统一 |
| `feedback.drift_lag_turtle` | TUBO 走神了 - 壳没马上听懂 | TUBO IS DAYDREAMING - SHELL SLOW TO REACT | FEEL-10 新名；与“兔子/乌龟”混用，需统一 |
| `feedback.drift_autocrouch` | BITT 自己趴下了！ | BITT DUCKED ON HIS OWN! | FEEL-10 新名；与“兔子/乌龟”混用，需统一 |

## 大字横幅

**出现位置**：屏幕中央的大字事故/救援横幅  
**作用**：把重大后果说得比小字更重

| ID | 中文 | English | 备注 |
|---|---|---|---|
| `banner.slip` | 摔了！兔子没抓住 | WIPEOUT! RABBIT LOST GRIP |  |
| `banner.water` | 扑通！兔子落水 | SPLASH! RABBIT IN THE WATER |  |
| `banner.stun` | 咚！兔子被撞晕 | BONK! RABBIT IS STUNNED |  |
| `banner.hit` | 哎哟！兔子撞到了 | OUCH! RABBIT HIT SOMETHING |  |
| `banner.reef` | 引擎故障！乌龟撞上暗礁 | ENGINE FAILURE! TURTLE HIT THE REEF |  |
| `banner.oxygen` | 没气了！紧急上浮 | NO AIR! EMERGENCY ASCENT |  |
| `banner.pickup` | 好接！ | NICE SAVE! |  |
| `banner.rescue` | 获救 | RESCUED |  |

## 中央大字

**出现位置**：屏幕中央的区域/Showtime/冲线/满格文字  
**作用**：阶段性节点与强情绪

| ID | 中文 | English | 备注 |
|---|---|---|---|
| `center.zone` | 区域 {0}  {1} | ZONE {0}  {1} |  |
| `center.showtime` | SHOWTIME！ | SHOWTIME! |  |
| `center.brotherhood` | 兄弟情！ | BROTHERHOOD! |  |
| `center.shows_over` | 表演结束！ | SHOW'S OVER! |  |
| `center.finish` | 冲线！  {0}  {1} | FINISH!  {0}  {1} |  |
| `center.bro_full` | 两人同时出事 —— 一起翻船！ | BOTH IN TROUBLE - CAPSIZED! | BRO METER / 默契 / 兄弟情 术语混用，建议统一 |
| `center.bro_recover` | 重新出发！ | BACK IN ACTION! |  |

## 世界内文字

**出现位置**：世界坐标里的区域标题、终点、加速带、食物、暂停提示  
**作用**：世界内的定位与规则提示

| ID | 中文 | English | 备注 |
|---|---|---|---|
| `world.zone_header` | {0}  {1} | {0}  {1} |  |
| `world.danger_depth` | 危险深度 | DANGER DEPTH |  |
| `world.finish` | 终点 | FINISH |  |
| `world.paused` | 已暂停 | PAUSED |  |
| `world.pause_hint` | ESC 继续   SHIFT 换人   R 重开   M 主菜单 | ESC RESUME   SHIFT TRANSFER   R RESTART   M MENU |  |
| `world.boost` | 加速带 | BOOST |  |
| `world.snack` | 海藻 | SNACK |  |
| `world.eat_now` | 吃 | EAT |  |
| `world.grip` | {0}   抓地 {1}% | {0}  GRIP {1}% |  |

## 暂停页

**出现位置**：ESC 暂停菜单  
**作用**：玩家唯一能停下来读规则的地方

| ID | 中文 | English | 备注 |
|---|---|---|---|
| `pause.title` | 已暂停 | PAUSED |  |
| `pause.breath` | Take a breath, bro. | Take a breath, bro. |  |
| `pause.resume` | 继续游戏 | RESUME |  |
| `pause.restart` | 重新开始 | RESTART |  |
| `pause.menu` | 返回主菜单 | MAIN MENU |  |
| `pause.keys` | ESC 继续   R 重开   M 主菜单 | ESC RESUME   R RESTART   M MENU |  |
| `pause.food` | 能量海藻：SHIFT 决定谁吃 — 乌龟吃 = 加速，兔子吃 = 下一跳更高；不吃不扣分 | SNACK: SHIFT PICKS WHO EATS - TURTLE = TURBO, RABBIT = HIGHER JUMP; SKIPPING COSTS NOTHING |  |
| `pause.help` | 帮助 / 操作说明 | HELP / CONTROLS |  |
| `pause.help_title` | 操作说明 | CONTROLS |  |
| `pause.help_body` | SHIFT 换人：障碍只认一种身体，换错就撞（换人间隔 0.2 秒）\n↑ 兔子跳 / 乌龟跃起    ↓ 兔子趴低 / 乌龟下潜\n礁拱：乌龟潜过去；鲨鱼：乌龟跃起；\n低梁/海鸟/吊网：趴低或下潜；岩/箱/浮台：跳过去\n浮木：先 ↑ 跳，再 SHIFT 给乌龟 ↓ 潜\n高墙：SHIFT + ↑ 跃起，再 SHIFT 兔子 ↑ 蹬踏\n食物：操控谁谁吃，不吃不扣分 | SHIFT SWAP: EACH OBSTACLE FITS ONE BODY (0.2s BETWEEN SWAPS)\n↑ RABBIT JUMP / TURTLE LEAP    ↓ RABBIT CROUCH / TURTLE DIVE\nARCH: TURTLE DIVE; SHARK/EEL: TURTLE LEAP\nBEAM/NET/GULL: CROUCH OR DIVE; ROCK/CRATE/PONTOON: JUMP\nLOG: ↑ JUMP FIRST, SHIFT, THEN ↓ DIVE\nHIGH WALL: SHIFT + ↑ LEAP, SHIFT RABBIT, ↑ KICK\nSNACK: WHOEVER YOU DRIVE EATS; SKIPPING IS FREE |  |

## 区域名/教学

**出现位置**：区域标题、区域中央提示、HUD 区域行  
**作用**：三个区域的命名与一句话目标

| ID | 中文 | English | 备注 |
|---|---|---|---|
| `zone.1.name` | 阳光海岸 | SUNNY COAST |  |
| `zone.2.name` | 码头乱流 | DOCK CHAOS |  |
| `zone.3.name` | 肌肉狂潮 | MUSCLE MAYHEM |  |
| `zone.1.lesson` | 区域 1 阳光海岸 - 学会跳、趴低、乌龟跃起和下潜 | ZONE 1  SUNNY COAST - LEARN JUMP, CROUCH, TURTLE LEAP AND DIVE |  |
| `zone.2.lesson` | 区域 2 码头乱流 - 吊网、鳗鱼、船闸，换对人才过得去 | ZONE 2  DOCK CHAOS - NETS, EELS, SLUICES: PICK THE RIGHT BRO |  |
| `zone.3.lesson` | 区域 3 肌肉狂潮 - 龟兔各走一条路，别靠连点 | ZONE 3  MUSCLE MAYHEM - TWO ROUTES, NO MASHING |  |

## 评级

**出现位置**：结算页等级标题  
**作用**：结算的情绪落点

| ID | 中文 | English | 备注 |
|---|---|---|---|
| `grade.S` | 绝对好兄弟！ | ABSOLUTE BROS! |  |
| `grade.A` | 肌肉兄弟！ | MUSCLE BROTHERS! |  |
| `grade.B` | 还算铁的哥们！ | PRETTY GOOD BUDDIES! |  |
| `grade.C` | 塑料兄弟情！ | PLASTIC FRIENDSHIP! |  |
| `grade.D` | 两个脑细胞，零配合！ | TWO BRAIN CELLS, ZERO COORDINATION! |  |

## 结算页

**出现位置**：冲线后的结算页  
**作用**：本局数据、纪录、下一次建议

| ID | 中文 | English | 备注 |
|---|---|---|---|
| `result.title` | 比赛完成 | RACE COMPLETE | 保留 {0} 等占位符与对齐空格 |
| `result.time` | 比赛时间              {0} 秒 | RACE TIME              {0} s | 保留 {0} 等占位符与对齐空格 |
| `result.casualties` | 兔子伤亡              {0} | RABBIT CASUALTIES      {0} | 保留 {0} 等占位符与对齐空格 |
| `result.engine` | 乌龟故障              {0} | TURTLE ENGINE FAILURE  {0} | 保留 {0} 等占位符与对齐空格 |
| `result.coop` | 完美合作              {0} | PERFECT COOPERATION    {0} | 保留 {0} 等占位符与对齐空格 |
| `result.showtime` | 表演次数              {0} | SHOWTIME               {0} | 保留 {0} 等占位符与对齐空格 |
| `result.streak` | 完美连击              {0} | PERFECT STREAK         {0} | 保留 {0} 等占位符与对齐空格 |
| `result.accidents` | 事故总数              {0} | TOTAL ACCIDENTS        {0} | 保留 {0} 等占位符与对齐空格 |
| `result.clean` | 干净通过              {0} | CLEAN PASSES           {0} | 保留 {0} 等占位符与对齐空格 |
| `result.combos` | 连招                  {0} | BRO COMBOS             {0} | 保留 {0} 等占位符与对齐空格 |
| `result.rescues` | 救援成功              {0} | RESCUE SAVES           {0} | 保留 {0} 等占位符与对齐空格 |
| `result.snacks` | 亲手喂到              {0} | HAND-FED SNACKS        {0} | 保留 {0} 等占位符与对齐空格 |
| `result.try_combo` | 下次试试：兔子跳起来后按 SHIFT 让乌龟下潜（BRO DIVE） | NEXT TRY: JUMP, THEN SHIFT THE TURTLE DOWN (BRO DIVE) | 保留 {0} 等占位符与对齐空格 |
| `result.try_snack` | 下次试试：按 SHIFT 换到乌龟，亲手把海藻喂给它 | NEXT TRY: SHIFT TO THE TURTLE AND FEED IT THE SEAWEED | 保留 {0} 等占位符与对齐空格 |
| `result.try_rescue` | 下次试试：兔子落水时按 SHIFT 换乌龟，按住 ↓ 追下去接它 | NEXT TRY: WHEN THE RABBIT FALLS IN, SHIFT AND HOLD ↓ TO CATCH | 保留 {0} 等占位符与对齐空格 |
| `result.mistakes` | 失误                  {0} | MISTAKES               {0} | 保留 {0} 等占位符与对齐空格 |
| `result.joint` | 翻船次数              {0} | CAPSIZES               {0} | 保留 {0} 等占位符与对齐空格 |
| `result.best` | 最佳时间 {0}   最低事故 {1}   最长连击 {2} | BEST TIME  {0}   BEST ACCIDENTS  {1}   BEST STREAK  {2} | 保留 {0} 等占位符与对齐空格 |
| `result.new_time` | 新最佳时间！ | NEW BEST TIME! | 保留 {0} 等占位符与对齐空格 |
| `result.new_streak` | 新最长连击！ | NEW BEST STREAK! | 保留 {0} 等占位符与对齐空格 |
| `result.again` | 再玩一次 | PLAY AGAIN | 保留 {0} 等占位符与对齐空格 |
| `result.menu` | 返回主菜单 | MAIN MENU | 保留 {0} 等占位符与对齐空格 |
| `result.retry` | R  -  重开        M  -  主菜单        Enter  -  选中的按钮 | R  -  RETRY    M  -  MAIN MENU    ENTER  -  SELECTED BUTTON | 保留 {0} 等占位符与对齐空格 |

## 事故名

**出现位置**：HUD 事故行/横幅  
**作用**：事故的正式短名

| ID | 中文 | English | 备注 |
|---|---|---|---|
| `accident.RABBIT_SLIP` | 兔子滑落 | RABBIT SLIP |  |
| `accident.RABBIT_WATER` | 兔子落水 | RABBIT IN WATER |  |
| `accident.RABBIT_AIR` | 兔子被抛到空中 | RABBIT IN THE AIR |  |
| `accident.OXYGEN_OUT` | 氧气耗尽 | OXYGEN OUT |  |
| `accident.TURTLE_REEF` | 乌龟撞礁 / 下沉 | TURTLE REEF / SINK |  |
| `accident.RABBIT_STUN` | 兔子硬直 | RABBIT STUN |  |
