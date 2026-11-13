# LONGRUN_STATE — TBB-LONGRUN-PLAYABILITY-01 / -02 / -05 / REFINE-06

STATUS: REFINE-06 P0–P2 / P4 / P5 / P6 完成（P3 QC 字面 FAIL 待制作人裁）；最终报告已写，等制作人质检；STAGE=4
LAST_UPDATED: 2026-11-13 20:25（REFINE-06 最终报告）
检查点（20:10，REFINE-06 P6）：`tbb-refine06-p6-rhythm` 9/9 pass；报告 `REFINE-06-P6.md`。
      - 只做两处换位、不增删障碍：Z1 把 wall1 从 13300 移到 10860、bird2 从 10860 移到
        13300（35–50 s 三连兔子 rock3→beam2→bird2 中间插进 BOTH 高墙）；Z2 把 shark3 与
        beam3 换位（15800↔17000），拆掉 Z2 入口三连兔子。组数仍 55，x 集合不变。
      - 复审数字：同类别连 0、同角色 >3 为 0（仅 beam9→rock11→gate8 三连，合规）、
        刚切又切回 0、空档最大 5.46 s、静态无操作段 0（检测器自检通过）、动态 3 种
        （tide_rock 9 / ambush_shark 7 / swell_log 3）、高操作占比 0.333→0.579→0.625、
        食物 2/3/4、BOTH 2/4/5。
      - 两圈 fullrun 274.6/274.6 s、9650、S、55/55、0 事故、最大停摆 0.0 s、SCRIPT ERROR 0、
        `STAGE3 PLAYTEST: PASS`；两圈各有 `wall ollie at x=10860`；`best.json` md5 未变。
      - headless 12 场景 exit 0；`stage6_balance_matrix` 31/31；三张窗口截图逐张打开看过
        （`screenshots/refine06-p6-z1-*.png`）。
      - 已知：`stage5_g4_cheer` BRO DIVE 欢呼 32 帧 > 25 阈值（既有问题，未改阈值）；
        七段中“恢复和收尾”仅 ~16 s，Z2 长 97 s。
      - 有趣性自评：**有保留**——七段可逐段指认、被点名无聊段已修复，但末段偏薄且未做真人试玩。
NEXT: 等制作人裁决 P3 三条验收（§6）+ 安排真人试玩；`STAGE=4` 不动，不宣布完成
检查点（19:05，REFINE-06 P5）：`tbb-refine06-p5-character-feedback` 8/8 pass；报告 `REFINE-06-P5.md`。
      - 乌龟被浪掀翻：`flip_t = 0.9 s` 纯表现计时，0.18 s 翻过去 → 肚皮朝天、四肢相位不同地
        乱蹬、头被压在壳下 → 最后 0.25 s 翻回来；`flip_lock` 0.9+0.6 s，贴着鲨鱼连拍不会
        整段卡在肚皮朝天。位置/碰撞/判定/事故记账全不动（只记浪击那一次）。
      - 兔子侧没有改玩法：落水水花（误差 0.8 px）、下落连续性（最大隐含 944.4 px/s）、
        靠近→接住→抬回（水里 58 帧 / 抬升 16 帧 / 第 75 帧回 RIDING）本次用探针复核 + 截图。
      - 不穿墙：贴浮木掀翻前进 72 帧、71 帧相交、壳最右沿 6403 < 浮木 6400 + 3，被顶回 6355。
      - 正式赛道真实输入：撞鲨鱼掀翻 0.9 s；撞低梁 0.98 s 落水 → SHIFT+↓ 0.53 s 救回。
      - 回归：两圈 fullrun 274.6/274.5 s、9650、S、55/55、0 事故、最大停摆 0.0 s、
        SCRIPT ERROR 0；headless 8 场景 exit 0，hud_score 44/44、menu_input PASS、
        snack_zones 18 行 0 fail、snack_rush 3 例 0 fail、playful_shift_reward PASS、
        snack_contest PASS、char_feedback PASS；`best.json` md5 未变；STAGE=4。
      - 有趣性自评：**有保留**——两个失败都一眼可读且有性格，掀翻不挡操作、不拖时间，
        但掀翻机制上仍是浪击的后果补充；未做真人试玩。
检查点（17:40，REFINE-06 P4）：`tbb-refine06-p4-snack-contest` 7/7 pass；报告 `REFINE-06-P4.md`。
      - 食物改“控制谁就谁吃”：控乌龟 = 原有 TURBO×1.15 + 冷静 + +30 分；控兔子 =
        下一跳初速 ×1.15（实测峰值 183.8→244.0 px，×1.33），乌龟不加速不冷静不得分；
        没吃到零惩罚。320 px 内两角色都伸手（主动/伙伴两色），没被控的一方头顶 “!”。
      - 探针 `stage4_snack_contest`（9 例）：SHIFT 同帧换吃的一方、320/321 px 边界、
        空中错过零代价、正式赛道 9 份食物；输出 `refine06-p4-snack-contest.json`。
      - 五张取证截图 `screenshots/refine06-p4-snack-*.png` 逐张打开看过。
      - 回归：两圈 fullrun 274.6/274.5 s、9650、S、55/55、0 事故、9 份食物乌龟 5 / 兔子 4
        交替吃、SCRIPT ERROR 0；headless 8 场景 exit 0，hud_score 44/44、menu_input PASS、
        snack_zones 18 行 0 fail、snack_rush 3 例 0 fail、playful_shift_reward PASS；
        `best.json` md5 未变；STAGE=4。
      - 有趣性自评：**有保留**——反应窗 1.45/1.33/1.23 s，两种结果可见不同，但仍是
        二选一小判断，没有新操作；未做真人试玩。
NEXT: REFINE-06 P6（55 组节奏复审 + 10 问自评 + 总报告）
检查点（15:06，REFINE-06 P3）：`tbb-refine06-p3-shark-ambush` 8 条中 5 条 pass、
      3 条按字面 fail（标准 1、2、3，QC 任务判 FAIL，未按“完成”计）；报告 `REFINE-06-P3.md`。
      - 鲨鱼改为靠近触发的水下伏击：潜伏 528～720 → 0.95 s 预警 → 0.55 s 鳍/“!”
        → 冲上 288～480 压 1.4 s → 退 0.55 s；退避即放行，P0 的“无限顶住”从机制上消失。
      - 新增探针 `stage6_shark_ambush`（6 组×576 帧逐帧、10 次不跃、10 次定点起跳、
        0.05 s 扫窗、4 档深度）；输出 `refine06-p3-shark-ambush.json`（两次跑除时间戳
        逐字段一致）；三张窗口截图已打开核对，live y=528/528/288。
      - 实测：安全窗 0.30–0.65（Z1）/0.25–0.65（Z2）/0.15–0.65（Z3）；0.3、0.6 各 10/10，
        **0.9 s 0/10**（接触在 0.95 s）。窗口宽 ≤0.50 s，而“0.3 与 0.9 都过”需要 ≥0.60 s
        ——字面无解（跃起高位 1.13 s − 重叠 0.62 s = 0.51 s），不是参数没调。
      - **真 bug**：默认种子把 gate3 抽成 SHARK 时 `build_group` 丢了 `motion`，
        生成一条静止水面鲨（P0 换入口回来）；已在 `apply_snack_draws` 补 motion，
        并把 `_init_ambush()` 挪到抽取之后。默认赛道实际 5 条鲨（shark8/9 被抽成岩），
        与标准 1 的“6 组”前提冲突，未擅自改种子/抽取。
      - 回归：两圈 fullrun 272.8/272.7 s、9770、S、55/55、0 事故、5 次跃起 tur=0.00、
        SCRIPT ERROR 0；headless 8 场景 exit 0；`stage4_penalty` 单独重跑 PASS；
        窗口化 hud_score 重跑 44/44、menu PASS（批量里这两个因超时残留/焦点失败，
        单独重跑通过）；`best.json` md5 未变；STAGE=4。
      - 有趣性自评：**有保留**——预警可读、窗口够宽，但只多了起跳时机，没有新决策；
        本阶段最无聊 30 s：第一圈 t≈35–50 s rock3→beam2→bird2 三连“按 ↑”。
      详见 `REFINE-06-P3.md`。
NEXT: REFINE-06 P4（小份食物争夺系统）
检查点（14:30，REFINE-06 P2）：`tbb-refine06-p2-brodive` 6/6 pass；无产品代码改动。
      - 新探针 `scenes/stage6_bro_dive_robust.tscn`：log1/log3/log8 各 10 次标准
        输入，30/30 干净通过、0 事故、每组 10 次签名逐位一致；30/120 Hz 不翻转
        （余量差 ≤7.3 px）；输出 `refine06-p2-brodive.json`。
      - 真实最差余量：兔子 20.3/45.1/59.7 px，乌龟 22.0/14.8/8.9 px。
        **勘误**：`REBUILD05-B3.md` 的 74.0/44.6 px 是 maxf 最好值，不是最差值。
      - 安全窗口：起跳 40–56 px（0.2–0.28 s）、SHIFT 延迟 0.16 s+、松手 80–88 px；
        HUD 提示点（+40 px）距失败边还有 24–32 px。
      - 偏差对照：跳太晚 → 兔撞；SHIFT 太晚 → 龟撞；**跳太早不失败**（安全落回壳，
        非连招），已按 G18 先例写勘误。
      - 回归：两圈 fullrun 272.9/272.8 s、9770、S、55/55、0 事故、stderr 0 行；
        hud_score 44/44、menu_input PASS；`best.json` md5 未变；STAGE=4。
      详见 `REFINE-06-P2.md`。
NEXT: REFINE-06 P3（鲨鱼改为水下伏击 + 预警，解决 P0 静止鲨鱼顶住壳）
检查点（14:20，REFINE-06 P1）：P1 两项都已完成，QC `tbb-refine06-p1-hud` 7/7 pass。
      - HUD 重做（`scripts/ui/role_glyph.gd` 新增原生 `_draw` 角色图形；`hud.gd`
        两行角色行 + 当前控制 ▶/金环 + 四档文案/颜色/条；`race.gd` 只改
        `_draw_drift_mark` 画法加想法泡底）。无新素材/字体/音效，无倒计时。
      - 动态平衡矩阵 `scenes/stage6_balance_matrix.tscn`：AB/C/DE 三次实跑，
        覆盖五类段落，31 条判定 failed=0，输出
        `docs/reports/longrun/refine06-p1-balance.json`（含逐帧 shift_traces、
        进组双方快照、碰撞原因、`unwinnable_found=false`）。
      - 0.5 s 恢复缓冲与 2.0/s 回落由 6 条逐帧 trace 证明；换手反馈延迟 0.00 s。
      - 回归：hud_score 44/44、menu_input PASS、两圈 fullrun 272.9/272.8 s、
        9770、S、55/55、0 事故、stderr 0 行（`refine06-p1-fullrun.*.log`）；
        `best.json` md5 `c322f9a20321c5b618f98db7e4120969` 未变；STAGE=4。
      - 有趣性自评：**有保留**——SHIFT 时机可感、可测有收益，但矩阵里标准打法
        就能 0 撞通过，drift 未成为失败原因；需 P6 的 55 组站距复盘判断是否真被逼。
      详见 `REFINE-06-P1.md`。
NEXT: REFINE-06 P2（BRO DIVE 障碍鲁棒性：≥3 个代表障碍 × 10 次重复）
检查点（13:40，REFINE-06 P0）：`race.gd` 新增 `_resolve_turtle_solid()`——壳对实心
      障碍（浮木/鲨鱼/高墙/潜门/海鸟层除外）真实顶住，只推出不往前送；已越过
      右沿时沿 y 轴推回最近水平边（修掉浮木下方上浮 10.75 px / 5 帧穿角）。
      7 必验 + 1 补充用例全过（`refine06-p0-collision.json`，穿透 0）；正式
      race.tscn 两圈 `fullrun` 272.9/272.8 s、9770、S、55/55、0 事故
      （`refine06-p0-fullrun.log`）；`best.json` md5 未变；窗口化 HUD 44/44、菜单 PASS。
      行为变化：只跳不潜时壳被顶住、兔子落水走救援（`stage2_selftest` 断言已按
      物理真相改写）。风险：静止鲨鱼会把壳无限顶住，P3 才给通过窗口。
      详见 `REFINE-06-P0.md`。制作人补充指令见 `MISSION-REFINE-06-SUPPLEMENT.md`
      （动态平衡是核心 SHIFT 机制，保压力、不取消失控）。
检查点（12:32，G22）：制作人要求“把可优化的部分优化完，然后我进行质检”。
      已完成三项（`REBUILD05-G22.md`）：
      - 补教封顶：每类首次教学 + 一次补教，之后不再复读；探针新增 F 用例，
        反向对照恰好 F6/F7 变红。
      - log5（Z3 第一处浮木）加同规格浪涌，动态 13/55→14/55；E2 扩到 14 组，
        log5 振幅 21.9/22、5 相位 `hits 0`。
      - `load_level()` 归零 `hazard_clock`：多行探针每例同相位起跑（正式赛局 0 变化）。
      回归（最终工作树）：`fullrun-g22.log` 272.9/272.8 s、9770、S、55/55、0 事故，
      关键行与 `fullrun-final.log` diff 为空；26 场景批量全绿（含 e2/g21）；
      窗口化 HUD 44/44、菜单 PASS（并发时那一次 best.json 比对失败已作废，单独重跑 PASS）；
      `best.json` md5 `c322f9a20321c5b618f98db7e4120969` 前后一致；`STAGE=4`。
      仍未做：真人试玩、55 组解法矩阵重跑、Z3 两对重复的顺序、音效/美术。
终止确认（09:48，制作人）：停止一切新改动。最后一次核验——
      `best.json` md5 `C322F9A20321C5B618F98DB7E4120969`，
      内容 `best_accidents 0 / best_score 3150 / best_streak 54 / best_time 283.961389`
      （与 08:52 收尾取样逐字节一致）；`docs/STAGE.md` 仍为 `STAGE=4`；
      报告 `TBB-EXPERIENCE-REBUILD-05.md` 12 节齐全（一句话结论 + §1–§12），
      §11 八条未完成项在位；无 Godot 进程残留。此后不再改动任何文件。
检查点（08:52，制作人）：最后 1 小时，停止新功能，做全量回归 / best.json 校验 /
      写报告 / 更新本文件；未完成项如实列出。执行记录（08:56 完成）：
      - 产品代码自 G21 后未再改动；探针只加了 `--capture-relesson` 取证分支。
      - 收尾回归 `fullrun-final.log`：run1 272.9 s / 9770 / S / 55/55 / 0 事故，
        run2 272.8 s 同，`STAGE3 PLAYTEST: PASS`；FINISH/SCORE/PLAYTEST 关键行与
        `fullrun-g21.log` diff 为空。
      - 25 场景批量（`/tmp/final-<scene>.log`，含 `stage4_lesson_prompt`、g17/g19/g21）
        全部 exit 0、0 条失败行；窗口化 `stage4_hud_score` 44/44、
        `stage4_menu_input` PASS。
      - `best.json` 跑前跑后 md5 `c322f9a20321c5b618f98db7e4120969`（两次取样一致）；
        `STAGE=4` 未动。
      - 未完成项：见报告 §11「本轮明确没有做 / 没有验证的」八条（真人试玩仍缺，
        主动换人动机弱、Z3 重复、无音频、G21 补教无上限等）。
检查点（07:41，制作人）：E 早已接入正式赛道并实跑，F 复核也已完成，不是待办——
      E1 海鸟重做 `REBUILD05-E1.md`（画与判定同源，`stage4_bird_routes` 三组）；
      E2 三原型 `REBUILD05-E2.md` + `rebuild05-e2-motion.json`（周期/扫掠/环境各一组，
      13 组×8 相位全干净），`level_data.gd` 里现有 13 处 `motion` 规格就是它们；
      E3 节奏 `REBUILD05-E3.md`（动态 3/55→5/55、两处空跑缩短）；G 段再加到 13/55。
      正式场景证据：两圈 `fullrun-g21.log` 272.9/272.8 s、S、55/55、0 事故；
      窗口化 HUD/菜单测试各轮补跑。F 复核 04:05 完成（`REBUILD05-F.md`）。
      G20（20 个探针补清 `hit_roles`）与 G21（撞过的类型下一组再教）已收尾，
      见 `REBUILD05-G20.md` / `REBUILD05-G21.md`；此后按 08:52 指令转入收尾，未再开新功能。
检查点（06:07，制作人）：C/D/E 早在 02:58–03:42 收尾，不是待办——
      C 引导条已挂在正式 HUD（`scripts/ui/hud.gd`，`race.tscn` 每局都挂），
      正式 race 场景窗口化截图 `screenshots/rebuild05-coop_coop_{prepare,now,missed}.png`，
      探针 `rebuild05-c-hud.json`（dive/ollie/control+rescue/双语四例）；
      D 三种正向切换证据在 `REBUILD05-D.md` + `rebuild05-d-shift.json`
      （食物切/不切 boost_speed 同为 253.0 只差 30 分、救援 `rescue_switch` 与重聚两拍、
      BRO DIVE/OLLIE 既有奖励）；E 动态障碍 `REBUILD05-E1/E2/E3.md`，
      动态组 3/55→5/55→7/55，G 段再加到 13/55（`REBUILD05-G.md`）。
      当前不在 C/D/E；G17 已收尾，G18（探针）已收尾，G19 已收尾。
NEXT: G15（窗口化 `stage4_hud_score` 过期断言）、G16（结算页「亲手喂到」）都已收尾：
      QC `g15` 5/5、`g16` 6/6；两圈 `fullrun-g15.log` / `fullrun-g16.log` 272.9/272.8、
      9770、S、55/55、0 事故，关键行与 g12 `diff` 为空；21 场景 `reg-g16-*` 全 exit 0；
      真实窗口化通关结算页读到「亲手喂到 9」，与同局 `snack=9` 对上；
      `best.json` md5 始终 `c322f9a20321c5b618f98db7e4120969`。
      G17 已收尾：结算页加一条「下次试试」（`GameManager.next_try_key()`，
      连招 / 喂食 / 救援三选一，都做到就不显示），QC `g17` 6/6、
      `stage5_g17_trynext` PASS 7、两圈 `fullrun-g17.log` 与 g16 diff 为空。
      G18 已收尾（只改探针）：`stage4_rescue_boost` 两个洞——
      (1) `_reset()` 漏清 `hit_roles`，同组从第二例起整组免疫，25 例修复前只有 2 例真撞；
      (2) `_evaluate()` 的 8 条汇总判定从不进退出码（`base_matches_phase_f` 红着也退 0）。
      修复后 25/25 行 `crash=RABBIT_WATER`、`checks red=0`、两圈与 g17 diff 为空，
      QC `g18` 7/7（第 3 条标准里“2.4 missed”是我抄了探针旧断言，实测 caught，
      勘误写在 `REBUILD05-G18.md`）。另记未修：20 个探针同样只清 `hit_groups`
      不清 `hit_roles`，需单独清扫轮。
      G19 已收尾：A 类障碍（低梁/海鸟/岩檐）只在兔子那一层判，玩家操控乌龟撞上时
      第一次给一句「按 SHIFT 换兔子 - 这个只有兔子能躲」（当局一次），8 条教学文案
      中英都点名 SHIFT；探针 `stage5_g19_wrongrole` 9/9（兔子操控不提示、乌龟提示
      且文本与 locale 一致、再撞不重复），两圈 `fullrun-g19.log` 与 g18 diff 为空，
      23 场景批量全绿，QC `g19` 6/6；`best.json` md5 未变。
      G20 已收尾（只改探针，产品 0 行）：G18 记下的 20 个探针补齐 `hit_roles` 复位
      （25 处）；重跑暴露三件事——`bird_routes` 的 jump/leap 旧「通过」是免疫假象
      （实为 0/42，海鸟只有趴低能过，E1 已加勘误）；`snack_zones` 起点贴着巡逻鲨
      扫掠边、且 `hazard_clock` 行间漂移（补起点余量与 clock 归零后 18/18 连跑两次一致）；
      `joint_verdict` 8 条断言是 B2 之前的「双撞合并一格」，按 `stage5_b_probe` s3
      改成「各记一笔」后 PASS。两圈 `fullrun-g20.log` 与 g19 关键行 diff 为空；
      23 场景批量与窗口化测试见 `REBUILD05-G20.md`。
      G21 已收尾：撞过的障碍类型，下一组再教一次（`lesson_seen.erase(kind)` +
      `_update_lessons()` 跳过已撞组）；探针 `stage5_g21_relesson` 五组 PASS、
      两处改动各做反向对照（只有 A 组四条 / E 组三条变红）；两圈 `fullrun-g21.log`
      与 g20 关键行 diff 为空、24 场景批量全绿、窗口化 HUD 44/44 + 菜单 PASS、
      `best.json` md5 未变，QC `g21` 6/6。
      08:52 收到收尾指令后不再开新功能：最终工作树重跑 `fullrun-final.log`
      （与 g21 关键行 diff 为空）、25 场景批量全绿、窗口化 HUD 44/44 + 菜单 PASS、
      `best.json` md5 未变；交付报告 `TBB-EXPERIENCE-REBUILD-05.md` 定稿（§11 如实列出
      八条未完成/未验证项），21 份 QC 记录复核全部 ALL PASS。
      下一步是制作人真人验收（这是本轮唯一无法由我做的一环），保持 STAGE=4。
G 段已记录的判断：近身余量实测（`rebuild05-g-margins.json`）证明“险过 + 绝对阈值”
    会误伤——鲨鱼标准跃起只剩 6 px、骑过岩只有 ≈10 px，都是几何固定余量，
    不是玩家本事，所以该机制不接入（只留证据）。
B3 结论：不是窗口窄（三组 7/7 干净通过、全量 178/180），真问题是一直按住 ↓ 会擦水扣分却看不出来
→ 见 `REBUILD05-B3.md`。
B1/B2 改动：`race.gd` 每角色分开记账（`hit_roles`）、接应期间乌龟照常判障碍、
`_trigger_accident` 返回是否记账、接应成功把 3 s 冷却压回 1.2 s。
探针：`scripts/test/stage5_b_probe.gd` + `scenes/stage5_b_probe.tscn`，
输出 `docs/reports/longrun/rebuild05-b-probe.json`（7 例全 PASS）。

## TBB-EXPERIENCE-REBUILD-05 进度（2026-11-13 02:25 起）

- [x] B1 接应成功仍判罚（2026-11-13 02:25，`rebuild05-b-probe.json` b1 / b1b）
- [x] B2 双角色碰撞判定（2026-11-13 02:25，s1–s5 五场景）
- [x] B3 BRO DIVE 三个代表障碍（2026-11-13 02:34，`REBUILD05-B3.md`、
      `rebuild05-b3-repeat.json`；log1/log3/log8 各 7/7 干净通过、0 事故、
      5×60 Hz 一致、30/120 Hz 不翻转；全量 178/180；按住不放会擦水记 1 次事故）
- [x] C 双角色引导条（2026-11-13 02:58，`REBUILD05-C.md`、`rebuild05-c-hud.json`、
      `screenshots/rebuild05-coop_coop_{prepare,now,missed}.png`；
      两圈中文 272.8/272.7 s、9770、S、55/55、0 事故、`STAGE3 PLAYTEST: PASS`；
      `best.json` md5 未变）
- [x] D SHIFT 正向体验（2026-11-13 02:58，`REBUILD05-D.md`、`rebuild05-d-shift.json`；
      三种正向切换各有可测收益；不切换零惩罚）
- [x] E1 海鸟重做（2026-11-13 03:12，`REBUILD05-E1.md`；画与判定同源，
      三组海鸟 `hit_but_not_drawn=0`）
- [x] E2 三动态障原型（2026-11-13 03:22，`REBUILD05-E2.md`、`rebuild05-e2-motion.json`；
      周期运动/扫掠追逐/环境变化各一组样板，8 相位全干净）
- [x] E3 三区节奏（2026-11-13 03:42，`REBUILD05-E3.md`；动态 3/55→5/55，
      两处空跑 6.36/6.00 s→5.91/5.73 s；两圈 272.8/272.7 s、S、55/55、0 事故）
- [x] F GDD 复核与小步优化（2026-11-13 04:05，`REBUILD05-F.md`、
      `rebuild05-f-lessons.json`（25 条断言 PASS）；教学文案按控制者分人；
      动态障 5/55→7/55；两圈 272.8/272.7 s、S、55/55、0 事故；
      `best.json` md5 `c322f9a20321c5b618f98db7e4120969` 未变；QC 7/7 pass）
- [x] G 持续优化（2026-11-13 04:16，`REBUILD05-G.md`、`rebuild05-g-margins.json`）：
      动态障碍 7/55→13/55（rock4/rock7/shark6/rock11/log2/rock12，Z1 1/Z2 6/Z3 6）；
      E2 十三组×8 相位（浮木 5 相位）0 命中、规格全对表；近身余量实测后否掉
      “险过”机制（几何固定余量，非玩家本事）；两圈 `fullrun-g2.log`
      272.9/272.8 s、9770、S、55/55、0 事故；`best.json` md5 未变；
      QC 第 6 条已按 13/55 重判
- [x] 批量回归（2026-11-13 04:15）：selftest/bilingual/core/hud_priority/level_audit/
      metrics/snack_draw/snack_zones/snack_rush/e3_ollie/f_lessons 全绿（11/11，退出码 0）
- [x] 交付报告 `TBB-EXPERIENCE-REBUILD-05.md`（2026-11-13 04:19，H1–H12 已写；
      批量回归表已补）
- [x] G2 BRO DIVE “松开 ↓”提示（2026-11-13 04:21，`REBUILD05-G2.md`、
      `rebuild05-g2-release.json`）：`race.dive_release_ready()` + 正式 HUD 乌龟行
      + 双语一行 + `lesson.log` 补第三步；探针跟提示松手 0 事故 / 按住 1 事故；
      礁拱与接应各 120 帧 0 次；面板 6.0%；两圈 272.9/272.8 s、55/55、0 事故
      （`fullrun-g2b.log`）；`best.json` md5 未变；QC `tbb-exp05-g2` 5/5 pass
- [x] G3 擦水事故原因提示（2026-11-13 04:38 完成，`REBUILD05-G3.md`、
      `rebuild05-g3-hint.json`）：`race.gd` 落壳判定里 `turtle.diving` 时发
      `hint.dive_deep`；探针三组 PASS（擦水越过木尾 90.3 px 出提示并进正式 HUD、
      非下潜落水 0 次、被撞快路径 diving=true 也 0 次），事故数各 1；
      两圈 `fullrun-g3.log` 272.9/272.8 s、55/55、0 事故、PASS；
      `best.json` md5 未变；QC `tbb-exp05-g3` 5/5 pass
- [x] G4 连招成功时角色本体弹一下（2026-11-13 04:52 完成，`REBUILD05-G4.md`、
      `rebuild05-g4-cheer.json`）：`race.gd` 只在 `_trigger_action_fx` 起
      `celebrate_t`、只在 `_draw_rabbit` 加 `celebration_offset()`，位置不动；
      探针 PASS（dive/ollie 各 12.0 px、19 帧、第 21 帧归零；普通跳跃/礁拱 0；
      重触发会重置）；两圈 `fullrun-g4.log` 272.9/272.8 s、55/55、0 事故；
      `best.json` md5 未变；QC `tbb-exp05-g4` 5/5 pass
- [x] G5 接人/救回成功时角色本体弹一下（2026-11-13 04:49 完成，`REBUILD05-G5.md`、
      `rebuild05-g5-carry.json`）：`_apply_carry_result` 的 pickup / rescue 分支各调
      `_celebrate(kind)`；真实抬升 25 帧后触发，两类各 12.0 px、19 帧、第 21 帧归零，
      计数各 +1；普通跳跃/礁拱/rescue_return 全 0；两圈 `fullrun-g5.log` 272.9/272.8 s；
      `best.json` md5 未变；QC `tbb-exp05-g5` 5/5 pass。
      补记：第一版漏了日常落壳也会走 `_apply_carry_result("pickup")`，普通跳跃落壳会多弹一下；
      改为 `real_catch` 参数，落壳处传 false，对照延到 150 帧覆盖整段滞空，`fullrun-g5b.log` 复核通过
      （详见 `REBUILD05-G5.md`「补记」）
- [x] G6 会动的障碍每区首次提示（2026-11-13 04:53 完成，`REBUILD05-G6.md`、
      `rebuild05-g6-motion.json`）：`_update_motion_lesson()` 在 560 px 提醒一次/区，
      事故期间让位；Z1 rock3 556.3 px / Z2 rock4 560.0 px 各 1 次、同区不重复、
      静态组 0；两圈 `fullrun-g6.log` 272.9/272.8 s；`best.json` md5 未变；
      QC `tbb-exp05-g6` 5/5 pass
- [x] G7 「好接！」只给真正的接住（2026-11-13 05:01 完成，`REBUILD05-G7.md`、
      `rebuild05-g7-banner.json`）：普通跳跃落壳也发 `pickup_success`，每跳一次都喊
      「好接！」；`_apply_carry_result(kind, real_catch)` 只在真接住时发信号+弹跳，
      落壳保留水花与 `pickup_count`；探针 8 条断言 PASS（落壳横幅空/0 次、离壳 200 px
      真接住「好接！」1 次、救回「获救」1 次）；两圈 `fullrun-g7.log` 272.9/272.8 s、
      55/55、0 事故；`best.json` md5 未变；QC `tbb-exp05-g7` 5/5 pass
- [x] G8 接人提示环可见（2026-11-13 05:10 完成，`REBUILD05-G8.md`、
      `rebuild05-g8-corridor.json`）：PLAYFUL-04 的落壳分支把 `pickup_window` 同帧清掉，
      绿环 16 ms 一闪；改成“显示=落壳走廊（-150 px 起）/ 收人=can_pickup（-60 当帧吸附）”，
      文字仍在吸附区出现；探针 8 条断言 PASS（普通跳跃窗口 14 帧、上升段 0、
      壳下潜时 0 帧且仍记 RABBIT_WATER、深接抬升 11 帧）；`stage1_selftest` 恢复 exit 0；
      两圈 `fullrun-g8.log` 272.9/272.8 s、55/55、0 事故；md5 未变；QC `tbb-exp05-g8` 6/6 pass
- [x] 批量回归 G8 后（2026-11-13 05:11）：18 场景（含 stage1_selftest、g5_carry、
      g7_banner、g8_corridor）全部 exit 0
- [x] G9 落壳时壳有重量反应（2026-11-13 05:27 完成，`REBUILD05-G9.md`、
      `rebuild05-g9-shell-dip.json`）：日常落壳 / 真接住 / 救回 7 / 11 / 14 px 下沉，
      0.26 s 下沉-回弹-归零，只加在 `_draw_turtle` 画法上；探针 20 条断言 PASS
      （落壳帧 7.0 px、第 16 帧归零、干净下潜 160 帧 0、位置/判定框逐字不变）；
      截图 `rebuild05-g9-shell-dip{,_rest}.png` 实测壳下移 6 px；
      两圈 `fullrun-g9.log` 272.9/272.8 s、55/55、0 事故；md5 未变；QC `tbb-exp05-g9` 8/8
- [x] G10 首次教学先来后到（2026-11-13 05:35 完成，`REBUILD05-G10.md`、
      `rebuild05-g10-lesson-order.json`）：旧循环让 1100 px 内更远的鲨鱼教学盖掉
      「BRO DIVE 现在！」前的组合教学，底栏方向相反；现在一帧只发最近的一组、
      最近的障碍组尾 +80 px 前不发更远的新类型；5 px 步进扫描 5300→6500 鲨鱼 0 次、
      越过 log1 后 6515 只发一次、旧循环重放仍会发（可区分）、全赛道七类各一次；
      两圈 `fullrun-g10.log` 272.9/272.8 s、55/55、0 事故；md5 未变；
      修前/修后截图 `rebuild05-coop_{audit,g10}_*.png`
- [x] G11 Showtime 截图取证修复（2026-11-13 05:41 完成，`REBUILD05-G11.md`、
      `rebuild05-g11-showtime.json`）：`--capture-showtime` 把乌龟传送到 rock2 正中，
      传送即撞、表演被事故门槛拒掉，截出来是「咚！兔子被撞晕」。改为先关判定、
      传送点 5100→5300；探针 4 条断言 PASS（事故中仍拒绝、修后拍到 SHOWTIME、
      兔子离壳 51.4 px、无新事故）；两张修后截图都打开看过；
      两圈 `fullrun-g11.log` 272.9/272.8 s、55/55、0 事故；md5 未变；QC `tbb-exp05-g11` 5/5
- [x] G12 暂停界面补操作对照（2026-11-13 05:50 完成，`REBUILD05-G12.md`）：
      `locale.gd` 的 `menu.hint` 早已写好但全项目无人引用，暂停面板只有 ESC/R/M。
      现在按钮与快捷键行之间挂上「SHIFT 换人 / ↑ 兔子跳·乌龟跃起 / ↓ 兔子趴低·乌龟下潜」；
      1280×720 中英文各一张截图（`rebuild05-pause-g12{,-en}.png`）都打开看过、不裁切；
      `stage4_opening_pause --force-opening` 窗口化 7/7 PASS（原有标题/呼吸语/三按钮/继续恢复都在）；
      只改 `scripts/ui/pause_menu.gd`，没加字符串没加素材；两圈 `fullrun-g12.log`
      与 g11 逐字一致；21 场景 `reg-g12-*.log` 全 exit 0；md5 未变；QC `tbb-exp05-g12` 6/6
- [x] G13 事故截图必须真的拍到事故（2026-11-13 05:54 完成，`REBUILD05-G13.md`）：
      把剩下的反馈面挨个拍了一遍，只有 `--capture-accident` 拍的是空画面——bird1 在 P1-4
      挪到 1560 后，旧的“传送到 1290 等 0.4 s”只够走 88 px。改成传送到鸟前 160 px、
      等 `accident_state` 真的变化（3 s 兜底）；判定/记账一行没动。两张独立运行都拍到
      「咚！兔子被撞晕」+ BRO METER 1/3；两圈 `fullrun-g13.log` 与 g12 逐字一致；
      QC `tbb-exp05-g13` 5/5
- [x] G14 截图工具不再覆盖历史证据（2026-11-13 06:00 完成，`REBUILD05-G14.md`）：
      `_capture_boost()` 写死 `stage2_boost.png`，一次取证就把 2026-11-10 Phase 2 的证据
      覆盖了。改为认 `-- --capture-boost <文件名>`；原图从 `.godot/imported/*.ctex`
      （lossless）按 `source_md5` 逐字节恢复（96ae3af9…），打开确认是旧 HUD。
      21 场景 `reg-g14-*` 全 exit 0、0 SCRIPT ERROR；批量退出后 md5 未变；QC `tbb-exp05-g14` 5/5。
      遗留：`--capture-boost` 的取景本身已过时（加速带只做食物锚点），要拍 TURBO 用
      `--capture-snack`，已写进 G14 的限制一节
- [x] G15 窗口化 HUD 回归的过期断言（2026-11-13 06:08 完成，`REBUILD05-G15.md`）：
      `stage4_hud_score` 不在 21 场景批量里，一直红着没人发现——救援是两拍
      （`rescue_ok` 抓到时 / `rescue_reunion` 抬回壳上时），HUD 后写覆盖前写，
      旧断言等 `rescue_success_count` 变了才读，读到的永远是第二拍，还写死中文。
      改成同时断言「第一拍发过 + HUD 最后显示重聚」，总数仍 44：
      `PASS checks=44`、exit 0（修前 `FAIL checks=44 failures=1`）；产品代码 md5 未变；
      两圈 `fullrun-g15.log` 272.9/272.8 s、55/55、0 事故、关键行与 g12 `diff` 为空；
      `best.json` md5 未变；QC `tbb-exp05-g15` 5/5 pass。
      以后每轮收尾要单独补跑 `stage4_hud_score` / `stage4_menu_input` 两个窗口化测试
- [x] G16 结算页记住「亲手喂到」（2026-11-13 06:18 完成，`REBUILD05-G16.md`、
      `rebuild05-g16-snacks.json`）：亲手喂到是“照顾搭档”的动作，但结算页不留痕。
      加 `GameManager.snack_switch_count`（只在操控乌龟吃到时 +1）+ 结算「救援成功」
      下面一行「亲手喂到」/`HAND-FED SNACKS`；计分与文案分人逻辑未动。
      `stage4_snack_rush` 三例 fed_count 1/0/1 全 PASS、fed_score 各对；
      真实窗口化通关结算页读到 `亲手喂到 9`，与同局 `snack=9` 一致；
      两圈 `fullrun-g16.log` 与 g15 关键行 diff 为空；21 场景全 exit 0；
      `best.json` md5 未变；QC `tbb-exp05-g16` 6/6 pass
- [x] G17 结算页「下次试试」（2026-11-13 06:19 完成，`REBUILD05-G17.md`、
      `rebuild05-g17-trynext.json`）：结算页只有数字，新手不知道漏了什么。
      `GameManager.next_try_key()` 纯函数三选一（连招→喂食→救援，都做够就不显示），
      结算页「最佳时间」下加一条浅绿建议；探针 7 条 PASS（含“刷新不改任何计数或得分”、
      只一个 `TryNext` label）、中英文 1280×720 截图不压按钮；两圈 `fullrun-g17.log`
      与 g16 关键行 diff 为空；QC `tbb-exp05-g17` 6/6
- [x] G18 救援窗口探针修复（2026-11-13 06:40 完成，`REBUILD05-G18.md`）：
      `stage4_rescue_boost` 的 23/25 例 `no_hit` 不是产品问题，是探针 `_reset()`
      漏清 `hit_roles`（B2 起按“角色×组”记账，同组第二例起免疫）；
      另修 `_evaluate()` 的汇总判定从不进退出码（红着也退 0，同 G15 那类静默绿）。
      修复后 25/25 `crash=RABBIT_WATER`、8/8 checks、两圈 `fullrun-g18.log` 与 g17
      diff 为空、`best.json` md5 未变；QC `g18` 7/7（第 3 条标准写错，见勘误）
- [x] G19 撞「只有兔子能躲」的障碍时第一次说换人（2026-11-13 06:40 完成，
      `REBUILD05-G19.md`、`rebuild05-g19-wrongrole.json`）：乌龟控制下撞
      LOW_BEAM/LOW_BIRD/SURFACE_ROCK，当局第一次发 `hint.take_rabbit`
      （`_wrong_role_hinted` 复位在 `_arm_rescue_proto`），8 条教学文案中英点名 SHIFT；
      探针 9/9、中英 1280×720 正式 HUD 截图各一张、两圈 `fullrun-g19.log` 与 g18
      关键行 diff 为空、23 场景批量全绿；QC `g19` 6/6
- [x] G20 20 个探针补清 `hit_roles`（2026-11-13 08:00 完成，`REBUILD05-G20.md`）：
      20 文件 25 处复位；`bird_routes` jump/leap 由假通过变 0/42（E1 勘误）、
      `snack_zones` 起点余量 + `hazard_clock` 归零后 18/18、`joint_verdict` 按 B2
      改预期后 PASS；两圈 `fullrun-g20.log` 与 g19 diff 为空；QC `g20` 6/6
- [x] G21 撞过的障碍类型，下一组再教一次（2026-11-13 08:11 完成，`REBUILD05-G21.md`）：
      `_check_hazards()` 真实记账时 `lesson_seen.erase(kind)`；`_update_lessons()`
      跳过 `hit_groups` 里已撞过的组（乌龟碰撞无事故状态，否则原地复读）。
      探针 `stage5_g21_relesson` 五组（撞→补教、干净通过不补、冷却不补、
      别的类型只教一次、乌龟撞完不在原地复读）PASS；两处改动各做反向对照，
      分别只有 A 组四条 / E 组三条变红；两圈 `fullrun-g21.log`、24 场景批量、
      窗口化 HUD/菜单、`best.json` md5 见 `REBUILD05-G21.md`

### 待查（不是本轮引入）

- ~~20 个探针清了 `race.hit_groups` 却没清 `race.hit_roles`~~（G20 已处理）。
  剩下的同源风险：别的多行探针若依赖动态障碍相位，仍可能翻面；G20 只在
  `snack_zones` 里归零了 `hazard_clock`。
  建议单独一轮：抽公共复位函数（`hit_groups`/`hit_roles`/`hazard_clock` 一起清）
  + 逐个重跑判读。

---

（以下为 PLAYFUL-04 结束时的状态，保留不覆盖。）

`TBB-SHIFT-FEEL-03`（Phase V：SHIFT 手感与玩法打磨）七项全部完成，
报告 `PHASE-V-FEEL.md`，QC 17 条全 PASS。中文完整赛道两圈 PASS
（272.8 / 272.7 s、9500 分、S、55/55、0 事故、failures=0），
`best.json` md5 `c322f9a20321c5b618f98db7e4120969` 前后一致（测试现在自己快照/还原）。
美术与音效按制作人指令冻结；Opening/Pause 为原生 Control 占位。
下一步等制作人复核本轮交付并试玩新手感（hitstop / 镜头震动 / Z3 预警 / 开场暂停）。
**不进入 STAGE 5，不宣布最终完成。**
`-01` 的全部状态与证据保留在下方，不覆盖；`-02` 的进度见文末「追加任务 -02」一节。

## TBB-SHIFT-FEEL-03（已完成待复核）

- 七项：SHIFT 电击表现、输入宽容、伙伴自主与后果、Z1 开场节奏、
  碰撞/动作反馈、Z3 远距预警、开场与暂停占位。
- 证据：`docs/reports/longrun/phase-v-{collision-feedback,z3-warning,opening-pause}.json`、
  `docs/reports/stage4-shift-feel.json`、`docs/reports/stage4-partner-neglect.json`、
  `docs/reports/longrun/phase-v-z1-rhythm.json`；
  截图 `screenshots/phase-v-{shift,collision,rescue,z3-warning,opening,opening-pause}.png`。
- 回归：中文完整主流程 + 完整赛道 PASS；30/60/120 Hz PASS；
  `stage4_hud_score` 44 项 PASS；`stage4_level_audit` 55 个正式组 + 7 个调试组。
- 全量回归顺带修正测试驾驶：log1 按兔子真实 x 判起跳点（不动物理）。
- 未验证：本轮新手感没有新的真人试玩；制作人此前 3–4 次试玩在 2026-11-11。


## 任务

- 编号：TBB-LONGRUN-PLAYABILITY-01
- 目标：把 Turbbit Bro! 做成完整、欢乐、易上手、有操作深度、值得重复游玩的灰盒；
  最终交制作人人工验收。
- 硬约束：`STAGE=4`，禁止推进 STAGE 5；自动测试不得写成真人试玩，
  真人反馈单独记录在 `PRODUCER-PLAYTEST-NOTES.md`；
  不跑 `../LESSONS/CHECKS/preflight.py`；素材继续冻结。
- 完整指令：`docs/reports/longrun/MISSION.md`（原文）。

## 版本与工作区

- 引擎：Godot 4.7 stable（`D:/Godot_v4.7-stable_win64_console.exe`）。
- `docs/STAGE.md`：`STAGE=4`。
- Git 根：`D:/GAMESTUDIO`，HEAD `4448151`；**`TURBBIT/` 整体未被跟踪**
  （`git status --short -- TURBBIT` 只有 `?? TURBBIT/`，`git ls-files TURBBIT` 为 0）。
  因此没有可回退的提交基线。
- 开工基线快照：`docs/reports/longrun/baseline-2026-11-12-0205.zip`
  （scripts / scenes / project.godot / STAGE / STAGE-4 文档 / 解法矩阵，约 260 KB）。
  任何回退先取这个 zip，不要依赖 git。
- 玩家纪录：`best.json` 现为
  `{"best_accidents":0,"best_score":3150,"best_streak":54,"best_time":283.961389454381,"score_model":2}`
  （md5 `c322f9a20321c5b618f98db7e4120969`）。
  自动跑写过的测试纪录已还原；Phase V 起 `stage3_playtest` 自己快照/还原，
  不再需要在外部手工恢复。

## 已完成阶段

- A 启动前检查：已读 STAGE / STAGE-4.md / STAGE-4-SPACE.md / 最新 QC / 最新回归；
  已查进程；已建任务目录、状态文件、恢复提示、基线快照、提醒脚本。
  Windows 任务 `TURBBIT-Longrun-Reminder` 已注册到 `2026-11-12 07:00 +08:00`
  （Interactive + WakeToRun），脚本已用 `-Test` 直接跑通（退出码 0）；
  详见 `REMINDER.md`。07:00 的真实触发已观测到（`reminder.log`：`07:00:02 TEST=False
  status=RUNNING lock=RUNNING pid=7972`，07:01:03 弹窗被确认）；但当时的锁是**陈旧锁**
  ——实际工作在 04:13 就因脚本解析错误挂了，锁没删。教训：锁文件不能单独当“活着”的证据。
- B 设计方向：已记录，尚未做任何玩法改动。
- C 逐组体验审计：完成，只读。报告 `PHASE-C-AUDIT.md`；细窗数据
  `phase-c-windows.json`；55 行表 `_phase_c_table.md`；截图 `screenshots/phase-c_*.png`。
  核心结论：单乌龟覆盖 44/55；下潜覆盖 38/55；必须 SHIFT 仅 11/55；兔子无唯一解；
  连招第一段窗口 0.14–0.25 s；最长空档 5.91 s；鲨鱼判定上沿有 34 px 隐形带。
- F 主动救援：完成工程验证并接入主流程。报告 `PHASE-F-RESCUE.md`；
  水救数据 `phase-f-rescue.json`、空中对比 `phase-f-rescue-air.json`；
  窗口化截图 `screenshots/rescue_demo_catch.png`、`rescue_demo_miss*.png`。
  选定“下潜接住水面兔子”；`RABBIT_WATER` 不再 1.6 s 自动放回，改为 3.2 s 主动窗口，
  失败 0.8 s 有限回壳；真人 NOT TESTED。本机 OS 键位注入被系统拒绝（SendInput=0），
  窗口化证据是引擎内输入代理，不是真人键位。
- E 连招第二段窗口：完成，只读。报告 `PHASE-E-COMBOS.md`；
  数据 `phase-e-combo-windows.json`；日志 `docs/reports/logs/combo-windows.log`。
  核心结论：BRO DIVE 最佳第二段窗 0.15/0.20/0.25 s（Z1/Z2/Z3），
  自然做法“跳完立刻 SHIFT+↓”成立，犹豫 >0.15 s 会龟撞；
  BRO OLLIE 第二段最早只能从 0.40 s 开始，最佳窗 0.25/0.35/0.30 s，早按必失败。
  两种连招结构都成立；Z1 log1 的 0.15 s 是唯一低于 0.25 s 的完整窗口。
- G 惩罚统一：完成工程验证。报告 `PHASE-G-PENALTY.md`。
  `daze_time` 降为短硬直/姿态，封顶 `DAZE_CAP=3.6`（旧落水线 9.5 的 38%），
  不再由阈值自动触发 `RABBIT_SLIP` / `TURTLE_REEF`；所有有效失误经
  `note_mistake()` 当场记 1 格 + −100，第三格播 1.4 s `BRO_BREAK`，之后复位、
  清格、1.5 s 宽限、本局继续。连续碰撞靠 `hit_groups` 去重。
  新增自检 `stage4_penalty`（37 条）；窗口化截图 `screenshots/phase-g_*.png`。
  真人 NOT TESTED。
- H 三区节奏与障碍空间：完成（证据见 `PHASE-H-ZONE-SPACE.md`）。四处改动：
  ① 审计脚本 `_reset()` 补清 BRO METER（假无解 g=27 的根因，属探针 bug）；
  ② Z1 连招顺序对调：先浮木 BRO DIVE、后高墙 BRO OLLIE，log1 右移 120 px 保住 ≥5 s；
  ③ 高墙墙身 y 206→236（世界 240→270）：起手窗口 wall1 0.136→0.318 s、
  wall2 0.208→0.375 s、wall3 0.192→0.308 s；抬墙楣的假设被实测否掉并回退；
  ④ 鲨鱼画法上沿 `top+34`→`top+4`，与判定框同一条线。
  最终几何矩阵 55/55 有解、0 设计答案缺失、0 条 `passing_schemes` 差异（按区分/种类比较）；
  最终几何 `stage4_metrics` PASS、自动批 10/10 PASS、两圈 55/55×2 0 事故。
  真人 NOT TESTED。
- I HUD / 菜单 / 中英双语：完成自动部分（报告 `PHASE-I-HUD-INTERACTION.md`）。
  真正找到并修掉的是对比度：压在 60% 面板上的灰字 3.81:1、红字 3.59:1、
  失衡 50–80% 档 3.06:1，全部低于 4.5:1。改法只动文字色（`MUTED` 提亮、
  新增 `RED_TEXT`、`_risk_color()` 四档换浅色），`PANEL_BG` 仍是 60%——
  要压到 4.5:1 得把面板调到约 90% 不透明，那是任务书明令避免的。
  改后最差 4.76:1。布局没动（4.17% / 5.28% 本就在 8% 内）。
  新增 `stage4_hud_contrast`、`stage4_hud_layout`；`stage4_hud_priority` 加了实测存活时长；
  `stage4_menu_input` 加了 ENTER 与三张截图。真人 NOT TESTED。
- J 难度 / 舒适度 / 可重复游玩：完成自动部分（报告 `PHASE-J-DIFFICULTY.md`）。
  **零玩法改动**，只加测量工具。结论：55 组最紧容差 0.154 s（shark6/8/9，Z3）、
  最紧反应预算 3.54 s（wall3）、组间最紧空档 3.85 s；7 类障碍在 Z1 全部各教一次，
  提示距障碍 ≥3.72 s（含零输入乱撞、38 次事故的对抗工况）；
  没有单一方案覆盖全程（最高下潜 38/55）。窗口化实跑两圈 55/55、0 事故、0 SCRIPT ERROR。
  新增探针 `stage4_lesson_prompt`；`stage4_solution_audit` 加 `--tolerance`；
  `stage4_combo_windows` 加 `--indices/--out`；离线汇总 `logs/phase-j/summarize.py`。
  真人 NOT TESTED。

## 当前进行中的工作

无。M 门槛 ① 已完成：
- 制作人 2026-11-12 在「加成本 / 收窄几何 / 保持现状」里选了**收窄关卡几何**。
- 做法（零机制改动）：`level_data.gd` 给 `SURFACE_ROCK` / `LOW_BEAM` 各加一段
  水下阻挡（世界 y 402～452）。这段正好罩住“下潜后的兔子身体 402～450”，
  巡航壳 306～362 从上方过、下潜壳 456～512 从下方过，壳不穿模；
  A 类仍只判兔子、趴低仍按状态放行，判定规则一行没改。
- 结果：`dive` 覆盖率 38/55 → **17/55**（只剩 8 个礁门 + 9 只鸟），
  岩 12 + 梁 9 共 21 组下潜全失败；`leap` 27 成为最高单方案；
  55/55 仍有解、设计答案全过；容差扫描逐组不变；窗口化两圈 55/55、0 事故。
- 证据：`PHASE-M-DIVE.md`、`logs/phase-m/`（含 `before/` 备份）、
  `screenshots/phase-m_{rock,beam}_block.png`。

## 下一项可执行任务

M（最终交付门槛）两条硬要求，**都已完成自动层**：
② **PASS（2026-11-12 13:12）**：headless `stage4_penalty` 37/37 ok、
`STAGE4 PENALTY: PASS`、stderr 0 字节；代码上事故只有一条链
`_trigger_accident → note_accident → note_mistake → BRO METER`，`daze_time`
仍封顶 `DAZE_CAP` 只做硬直；`best.json` 跑前备份、跑后逐字节一致。
证据 `docs/reports/logs/phase-m/penalty.log` + `best.before.json`。
① **PASS（2026-11-12 16:45）**：按制作人选择的「收窄关卡几何」完成，
下潜覆盖率 38/55→17/55，21 组岩/梁不再能被下潜绕过。QC `tbb-stage4-dive-dominance`
9/9 pass；证据 `PHASE-M-DIVE.md`、`logs/phase-m/coverage.json`。
**没有改任何机制/数值**，只给两类障碍加了水下段。

自动项到此为止。下一步只剩制作人结构化验收（所有 `NOT_VERIFIED` 的共同缺口）。
制作人已试玩并留过意见（见 `PRODUCER-PLAYTEST-NOTES.md`），但没有逐条验收记录；
不得把自动结论当作已验收。

已收口但 `NOT_VERIFIED` 的 QC：`tbb-stage4-difficulty-comfort`（1–6 pass、7 pending）、
`tbb-stage4-hud-interaction`（1–6 pass、7 pending）、
`tbb-stage4-zone-space`（1–6 pass、7 pending）、
`tbb-stage4-penalty`（1–6 pass、7 pending）、
`tbb-longrun-rescue`（1–5 pass、6 pending）、`tbb-stage4-combo-core`（1–10 pass、11 pending）。

## 已知问题与证据

| 问题 | 现状 | 证据 |
|---|---|---|
| 真人试玩 | **已试玩**（自述 3–4 次；2026-11-11 书面意见见 `PRODUCER-PLAYTEST-NOTES.md`）；QC 第 11 条仍 pending（没有结构化验收） | `../LESSONS/CHECKS/qc.py status --task tbb-stage4-combo-core` |
| 只潜覆盖 | **已收窄（Phase M）**：38/55 → 17/55（只剩鸟 9 + 门 8）；岩/梁 21 组下潜全失败，必须跳/趴 | `PHASE-M-DIVE.md`、`logs/phase-m/coverage.json` |
| 最高覆盖单方案 | `leap` 27/55（有时机成本，最紧窗口 0.154 s）；不是按住不放的零成本解 | `logs/phase-m/coverage.json` |
| 真正强制换人 | 11/55（浮木 8/墙 3）；鲨 6 只需乌龟，不用 SHIFT | `PHASE-C-AUDIT.md` §2.1 |
| 兔子无唯一解 | 兔子能过的 30 组都有乌龟替代 | `PHASE-C-AUDIT.md` §2.1 |
| 两套失衡 | **已消除**（Phase G）：daze 封顶 3.6 只做硬直，BRO METER 三格唯一 | `PHASE-G-PENALTY.md` §2 |
| ~~HUD 失衡条封顶 38%~~ | **已修（Phase G）**：分母改为 `DAZE_CAP`，条能走满；文案改“晃动/不稳” | `race.gd` `rabbit_imbalance_pct()`、`PHASE-G-PENALTY.md` §7 |
| 死代码 | `is_falling()` / `can_sink_danger()` 无生产调用者；旧下沉模型留在 `SURFBOARD_PHYSICS=false` 分支 | `grep` 结果、`PHASE-G-PENALTY.md` §7 |
| 总分区分度 | S=8000/9500；分数是按组记账 | `game_manager.gd`、`stage4-metrics` |
| 空档旧数作废 | 组间空档 54 个：最小 3.85 s、中位 4.44 s、最长 5.55 s；开场跑道 4.09 s（x=400→bird1）。无 8.3–8.7 s 空档 | `logs/phase-j/phase-j-summary.json`、`PHASE-C-AUDIT.md` §2.5 |
| 反应 / 容差 / 恢复 | 自动探针全达标：反应 ≥3.54 s、容差 ≥0.154 s、恢复 ≥3.85 s；**不是真人数据** | `logs/phase-j/phase-j-summary.json`、`PHASE-J-DIFFICULTY.md` §3–5 |
| Z3 实际起手时间 | 3.85 s 间距 − 130–235 px 起手 = 2.94–3.35 s | `PHASE-C-AUDIT.md` §2.5 |
| 连招窗口 | 浮木 0.182/0.208/0.231 s；高墙 0.318/0.375/0.308 s（Phase H 后） | `phase-e-combo-windows.phaseh-after.json`、`PHASE-H-ZONE-SPACE.md` §5 |
| 鲨鱼判定上沿 | **已修（Phase H）**：鱼头顶 = 判定框上沿 + 4 px（原 34 px） | `race.gd` SHARK 画法、`screenshots/phase-h_shark.png` |
| 救援未成立 | 已改为主动下潜救援；3.2 s 窗口、失败 0.8 s 回壳 | `PHASE-F-RESCUE.md`、`phase-f-rescue.json` |
| 救援偏宽容 | 2.0 s 内开始下潜都能接住，横向可身后 120 px 接住 | `PHASE-F-RESCUE.md` §6 |
| 窗口化真实键位 | 本机 SendInput 返回 0，OS 注入不可用；窗口化证据是引擎内代理 | `logs/input-injection-sendinput.log` |
| 菜单测试 | headless 鼠标必 FAIL，窗口化 PASS | `stage4-menu-input-rev2-windowed.log` |
| 720p 字号 | **已修（Phase T/U）**：HUD/结算 18 设计；菜单/设置/退出/暂停 14/15/16→18；1280×720 一律 14.4 px 实际（原 10.4–12.8 px），`stage4_menu_input` 5 处断言覆盖 | `PHASE-T-HUD-SCORE.md` §3.5、`PHASE-U-FULL-RUN.md` §2/§6.2、`logs/phase-t/regress/stage4_menu_input.log` |
| HUD 对比度 | **已修（Phase I）**：最差 3.06→4.76:1；面板透明度未动 | `logs/phase-i/contrast.log`、`PHASE-I-HUD-INTERACTION.md` §3 |
| 菜单最高分 | **已修（Phase U）**：纪录行只显示最佳时间 + 最长连击；`best_score` 仍保存 | `menu.gd`、`PHASE-U-FULL-RUN.md` §2 |
| Z1 开场空跑 | **未修，下一轮第一件事**：0–30 s 无输入 / 5.91 s 起步段；Phase S、T、U 连续指向同一处 | `PHASE-S-DIFFICULTY-CURVE.md`、`PHASE-T-HUD-SCORE.md` §3.10、`PHASE-U-FULL-RUN.md` §7 |
| 自动驾驶种类 | **已修（Phase U）**：探针改读 `race.hazard_groups`；修复前 gate3/rock6/gate8 误触 | `stage3_playtest.gd` `_live_groups()`、`PHASE-U-FULL-RUN.md` §2 |

## 进程与任务锁

- 当前无 Godot 进程（Phase M 收尾时已清掉两个 12:53 启动的残留测试进程）。
- 锁文件：`docs/reports/longrun/.lock`，格式 `PID STARTED_AT`。
  2026-11-12 16:45 已删除陈旧锁（`7972 2026-11-12 02:10`，PID 已死）。
- 开始一轮工作前写入；正常结束/阶段结束删除；崩溃则保留，下一轮按“PID 是否仍存活”
  判活。提醒脚本不会启动第二个实例，也不会自动拉起 AI 会话。

## 最近一次完整回归

- Phase U（2026-11-12 19:11，`docs/reports/logs/phase-t/`）：
  窗口化 `stage3_playtest` 中英文各两圈（run1 Enter、run2 Retry），
  每圈 `passed=55/55`、`accidents=0`、`max_accident=0.00s`、`max_stuck=0.0s`、
  `grade=S`、三区全到；stdout 47 条 ok / 0 FAIL，**stderr 0 行**，0 条 SCRIPT ERROR。
  食物加速每圈 9 次真实触发（`SNACK eaten`，速度 253/276/299 = 基础 ×1.15），
  `LEVEL SEED 20261112` 可复现；自动驾驶改读 `race.hazard_groups` 后
  gate3/rock6/gate8 三个改种组零接触。
  headless 回归 15 项 exit=0、stderr 0 字节；窗口化 `stage4_menu_input`、
  `stage4_hud_contrast` PASS。`best.json` 跑前备份、跑后还原，
  md5 `1CAC4067611D1B059374F4E1379C4C24` 与备份一致。
  **以上都是自动驾驶/代理/窗口化自动输入，不是真人。**

- Phase M（2026-11-12 16:45，`docs/reports/logs/phase-m/`）：
  窗口化 `stage3_playtest` 两圈 `passed=55/55`、`accidents=0`、`grade=S`、
  `failures=0`、`STAGE3 PLAYTEST: PASS`，0 条 SCRIPT ERROR；
  headless 回归 16 个场景全部 exit=0、0 FAIL、stderr 0 字节；
  `best.json` 已从 `best.before-playtest.json` 还原并逐字节核对。
  全量解法矩阵重跑：dive 38→17、no_solution=[]、design_correct 55/55；
  容差扫描三片重跑，55/55 组通过区间与改动前逐组一致。
  **以上都是自动驾驶/代理，不是真人。**

- Phase J（2026-11-12 13:00，`docs/reports/logs/phase-j/`）：
  窗口化 `stage3_playtest` 两圈 `passed=55/55`、`accidents=0`、`score=9500`、
  `failures=0`、`STAGE3 PLAYTEST: PASS`，stdout/stderr 0 条 SCRIPT ERROR；
  回归 `reg-flow` / `reg-hud_priority` / `reg-bilingual` / `reg-bro_meter` 全 PASS
  （stderr 均 0 字节）。跑完已把 `best.json` 还原为
  `{"score_model":2,"best_time":296.63,"best_accidents":0,"best_score":-1,"best_streak":54}`，
  与备份 `logs/phase-j/best.before.json` 逐字节一致。**该日志是自动驾驶，不是真人。**

- Phase I（2026-11-12 04:0x，`docs/reports/logs/phase-i/`）：
  `reg-hud_layout` PASS（4.167% / 5.281%）、`reg-hud_priority` PASS
  （`HUD TIMING feedback=0.75 hint=2.19 prompt=3.00 max=3.00`）、
  `reg-bilingual` PASS、`reg-bro_meter` PASS、`reg-flow` PASS、
  `reg-menu-input` PASS（36 条 ok、12 次鼠标点击、DOWN/UP/SPACE/ENTER，窗口化）；
  `contrast.log` `STAGE4 HUD CONTRAST: PASS`（64 行，最差 4.76:1）。
  跑完核对 `best.json` 未变。

- `docs/reports/logs/phase-h/playtest-final.log`（2026-11-12 04:10，Phase H 最终几何）：
  两圈 `passed=55/55`、`accidents=0`、`score=9500`、`failures=0`、`max_stuck=0`、
  0 条 SCRIPT ERROR。该日志由 `stage3_playtest.tscn` 生成；跑完已把测试写的
  `best.json` 还原为
  `{"score_model":2,"best_time":296.63,"best_accidents":0,"best_score":-1,"best_streak":54}`
  （备份 `best.json.phaseh-final.bak`）。
- `docs/reports/logs/phase-h/final-*.log`：自动批 10 项 10/10 PASS，0 条 SCRIPT ERROR；
  `metrics-after-body.log`：`STAGE4 METRICS: PASS`。
- QC `tbb-stage4-penalty`：1–6 pass，7 pending → `NOT_VERIFIED`（缺真人）。
- QC `tbb-longrun-rescue`：1–5 pass，6 pending → `NOT_VERIFIED`。
- QC `tbb-stage4-combo-core`：1–10 pass，11 pending → `NOT_VERIFIED`。
- 自动批全部 PASS（…-phaseg.log）：stage4-penalty / bro meter / bilingual /
  stage2 / stage3 / flow / core experience / hud priority / shift graybox / proto；
  10 条日志均 0 条 SCRIPT ERROR。

## 时间预算与可行性（2026-11-12 02:07 评估）

- 制作人指定 07:00 提醒；此前口述执行窗口到 11:00。实际可执行窗口约 4 小时。
- 全量 M 节交付（救援循环 + 惩罚统一 + 三区重排 + HUD + 难度）不可能在 4 小时内
  以可验收质量完成；本任务按断点续跑推进，允许“部分完成 + 状态落盘”。
- 第一优先：C 审计 → F 救援原型（最大乐趣缺口）→ D/E 手感与连招窗口 →
  G 惩罚统一 → H/I 关卡与 HUD。每个子任务单独回归、单独更新本文件。
- 无法自动恢复 Claude 会话：提醒只能弹窗 + 打开 `RESUME_PROMPT.md`，
  不得声称已恢复。OS 级自动拉起会话属于未实现能力。

## 恢复点

- 基线（-01 开工）：`baseline-2026-11-12-0205.zip`
- **基线（-02 开工）：`baseline-2026-11-12-P02.zip`**（2026-11-12 16:54，
  scripts / scenes / project.godot / STAGE / STAGE-4 / 解法矩阵 / MISSION-02 / 本状态文件）
- 恢复提示：`RESUME_PROMPT.md`
- 提醒：`REMINDER.md` + `tools/longrun_reminder.ps1`

---

## 追加任务 TBB-LONGRUN-PLAYABILITY-02（2026-11-12 起）

- 原文：`MISSION-02.md`（制作人追加，不覆盖 `MISSION.md`）。
- 当前阶段仍是 `STAGE=4`；不进入 STAGE 5；制作人已试玩，结构化验收未完成
  （见 `PRODUCER-PLAYTEST-NOTES.md`）。
- 新玩法三件：TURTLE SNACK RUSH（可选进食 → 15% 短加速 → 加速后的随机障碍）、
  区域随机障碍池 + 固定种子、主动救援原型（Phase F 已有，需按新验收重验）。
- 另要求：解释并处理 0.154 s 窗口；HUD 增加加速状态/`TURBO!`；弱化固定总分；
  1280×720 的中英文字号问题；三区难度曲线按“组合判断而非手速”复审。

### 进度（-02）

| # | 步骤 | 状态 | 产物 / 证据 |
|---|---|---|---|
| 1 | 检查状态并建立新恢复点 | **DONE** 2026-11-12 16:54 | 本文件、`MISSION-02.md`、`baseline-2026-11-12-P02.zip` |
| 2 | 解释 0.154 s 窗口 | **DONE**（验收 6/7 已过，窗口化全程回归并入 #10） | `PHASE-N-0154.md`；`matrix-after.log` 55/55 有解、设计答案 55/55 |
| 3 | 食物加速单一原型 | **DONE** | `PHASE-O-SNACK.md`；`stage4_snack_rush` 3/3 PASS；`screenshots/stage4_snack_{before,gulp,turbo}.png` |
| 4 | 随机障碍候选池 + 种子复现 | **DONE**（QC 1–6 pass，7 = 未做结构化真人验收） | `PHASE-P-DRAW.md`；`stage4_snack_draw` 23/23；默认种子 `20261112`，日志 `LEVEL SEED`；`solution-audit.log no_solution=[]` |
| 5 | 三区食物遭遇实测 | **DONE**（QC 6/6 pass） | `PHASE-P-ZONES.md`；`stage4_snack_zones` 默认种子 18/18、种子 424242 18/18；`zones.log` / `zones-seed424242.log`；`phase-p-zones*.json` |
| 6 | 修正不公平碰撞/预警 | **DONE** 2026-11-12 18:13（QC 7/7 pass） | `PHASE-Q-FAIRNESS.md`；只右移 Z3 的 9 组（+100…+420 px）；`warning-audit-after-q.log` MIN 4.017 s FAILS 0（改前 `--legacy` 3.833 s FAILS 1）；`solution-audit-after-q.log` 55/55；`metrics-after-q.log` 3.65/5.13 PASS；两种子 `zones-*-after-q.log` 18/18；`draw-after-q.log` 23/23。Z3 “复杂 ≥5 s” 与 1100 px 视野上限（4.231 s）冲突，已列为制作人决策项 |
| 7 | 主动救援原型 | **DONE** 2026-11-12 18:20（QC 7/7 pass） | `PHASE-R-RESCUE.md`；`stage4_rescue_boost` 25/25（`logs/phase-r/rescue-boost.log`）；加速中真实撞梁 → `RABBIT_WATER`；Z1 加速窗口 0.0–2.0 s、Z3（299 px/s）0.0–1.6 s；失败 3.22 s + 0.78 s 逐帧回壳（单帧 9.33 px）；事故只 +1 |
| 8 | 三区难度曲线 | **DONE** 2026-11-12 18:30（QC 8/8 pass） | `PHASE-S-DIFFICULTY-CURVE.md`；只读重算 `phase-s-curve.py` + `phase-s-difficulty-curve.json`；补测 5 px 细扫 rock8/rock4/shark3/shark1（`logs/phase-s/`）；密度 10.6/11.4/13.1 组每分；单动作窗口 Z3 不变窄（岩 0.432/0.458/0.462、鲨 0.386/0.458/0.500）；连招第一段 0.182/0.208/0.231（浮木）；Z1 8 s 空档已消除（最长 5.91 s 起点段）。Z3 连招占比与 Z2 持平（20.8% vs 21.1%），§五“组合判断”列为制作人决策项，未改关卡 |
| 9 | HUD / 评分表现 | **DONE** 2026-11-12 18:42（QC 11/11 pass） | `PHASE-T-HUD-SCORE.md`；`stage4_hud_score` 窗口化 44/44（`logs/phase-t/hud-score.log`）；HUD 与结算移除固定数字总分（`total_score`/`score_log` 保留）；结算七项含救援成功；`rescue_success_count` 接入 `_rescue_catch`；连招里程碑不再被“干净通过”覆盖；1280×720 最小实际字号 12→**14.4 px**；面板 4.52%/6.10%（≤8%）。回归 5 项全 PASS；`best.json` md5 前后一致 |
| 10 | 完整赛道回归 | **DONE** 2026-11-12 19:11 | `PHASE-U-FULL-RUN.md`；窗口化中英各两圈 55/55、0 事故、S、三区、`failures=0`；stdout 47 ok、stderr 0 行；`best.json` md5 前后 `1CAC…C24`。回归中修掉自动驾驶读原始种类（gate3/rock6/gate8 误触）、菜单残留最高分展示、菜单/暂停 11.2–12.8 px 字号，玩法未改 |
| 11 | 更新恢复点与验收入口 | **DONE** 2026-11-12 19:11 | 本文件 `NEXT`/本表、`RESUME_PROMPT.md` 改到 `-02`、新增 `PRODUCER-ACCEPTANCE.md`；`STAGE=4` 未动 |

---

## 追加任务 TBB-SHIFT-CORE-02（2026-11-12，已完成待复核）

- 原文：`MISSION-SHIFT-02.md`；报告：`PHASE-SHIFT-CORE.md`；
  QC 任务：`tbb-shift-core-02`（14 条，13 = 证据分类/STAGE，14 = 有趣性）。
- 阶段仍是 `STAGE=4`；不进入 STAGE 5；制作人已试玩（意见见
  `PRODUCER-PLAYTEST-NOTES.md`），本轮新机制未获新的真人验证。

| # | 步骤 | 状态 | 产物 / 证据 |
|---|---|---|---|
| 1–3 | 神游四态 + 两种角色行为 | **DONE** | `stage4-bro-brain.json`；四段 3.02/6.02/9.00 s；兔子 25.7 px、乌龟 0.90× |
| 4 | 海鸟四路线 | **DONE** | crouch 42/42、dive 59–60/62、jump/leap 0/42；`shift02-bird-routes.json`；前后对比 `phase-c-windows.shift02-*.json` |
| 5 | BRO DIVE 窗口 | **DONE** | `DIVE_GAIN=5.0`；Z1 0.15→0.30、Z2 0.20→0.35、Z3 0.25→0.35 s；`shift02-combo-*.json`、`shift02-bro-dive-matrix.json` |
| 6 | 落水坐标 | **DONE** | `shift02-water-rescue.json`；trigger_dx 0.7/5.3（旧 520）、fall 1.25 s、teleports 0 |
| 7 | 接人判定 | **DONE** | 140/[-95,40] + 6 段扫掠；0–1.2 s 接住、1.6 s 起 `turtle_too_shallow` |
| 8 | 完整赛道回归 | **DONE** | 窗口化中英各两圈 55/55、0 事故、stderr 0；`fullrun-{zh,en}.*.log`；beam7 由神游偏移引起，改测试司机收手判据 |
| 9 | 开场/暂停设计稿 | **DONE** | `SHIFT02-INTRO-PAUSE.md`；`shift_shocked` 事件接口已落地并灰盒断言 |
| 10 | 状态与恢复点 | **DONE** | 本节 + `RESUME_PROMPT.md`；`best.json` md5 `c322f9a20321c5b618f98db7e4120969` 未变 |

- 回归批：stage0–4 共 16 场景，修完两处旧测试契约（stage2 加速带 → 食物、
  rescue_boost 基速对照）后全部 exit=0、0 FAIL、0 SCRIPT ERROR。
