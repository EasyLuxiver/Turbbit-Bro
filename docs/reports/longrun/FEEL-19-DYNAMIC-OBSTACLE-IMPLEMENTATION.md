# FEEL-19 动态障碍与生态体验改造

- 日期：2026-11-15
- 阶段：`STAGE=4`
- 模式：CONTROLLED_WRITE
- **未导出任何测试包/候选包/EXE，未执行 Godot Export，未制作发布目录。**
- 结论：本批完成 **P0-A/P0-B、P1-A 海鸟行为、P2 MISCHIEF 电弧防御**，并接入正式比赛；**P1-B 鲨鱼群、P2-A 温泉、P2-B 水草、G10–G17/G31–G35/G39–G41 情境化尚未接入**，原因见第 5–7 节。自动化结果不等于真人体验。

## 1. P0-A：MISCHIEF 状态可读性

### 修改

- `GameManager.note_mistake()`：主控角色满格后不再把主条重置为 0/3，保持 **3/3 红色**；真正清空只在 MISCHIEF 完成/中断时。
- HUD 保留原有三格主条，不新增资源条；未受控兄弟继续显示文字副行。
- 满格时主条 `BRO METER TUBO 3/3` 可直接看到，SHIFT 后立即切换到 BITT 的条。

### 验证

- `stage19_p0_readability` 6/6：
  - 满格主条 `BRO METER TUBO 3/3`；
  - 副行 `BITT 0/3`；
  - 落水 prompt 含 SPACE；
  - SPACE 键帽出现；
  - 教学 step2 hint、暂停帮助都含 SPACE。
- `stage4_bro_meter` PASS（第三格保持 3/3 + 标记角色；MISCHIEF 完成后清零）。
- 截图：`docs/reports/longrun/feel19/p0-full-meter-space.png`。

## 2. P0-B：主动救援提示

### 修改

- `prompt.rescue_shift`：`SHIFT BITT → SPACE 主动救援（或按住 ↓ 接）`。
- `prompt.rescue_dive`：`SPACE 主动救援（或按住 ↓ 接TUBO）`。
- `feedback.rescue_auto_fail`：改为“SHIFT BITT 后按 SPACE”。
- 教程 step2 的 hint 明确 `SPACE 主动救援（TUBO落水）`；暂停帮助已有 SPACE。
- HUD 新增 **SPACE 键帽**，只在 prompt 含 SPACE 时显示/点亮；不常驻。
- 中英文同步。

### 验证

- `stage19_p0_readability` 6/6；`stage4_hud_layout` PASS；`stage4_hud_score` 41 checks PASS。
- 截图 `p0-full-meter-space.png` 同时显示满格、SPACE 键帽、SPACE 文案。

## 3. P1-A：海鸟多行为

### 实现（已接入正式 55 组）

`race.gd` 新增有限状态机：

```
WAIT → TELEGRAPH 0.55 s → ACTION 0.65 s → RECOVER 0.55 s → DONE
```

- 只给少数鸟额外行为，其他鸟保持原单次俯冲：
  - `bird3`：poop（排泄投射）
  - `bird4`：chase（追逐）
  - `bird6`：return（回马枪）
  - `bird8`：poop（默认种子可能被食物抽签换成 SURFACE_ROCK，换掉时自然没有鸟行为）
- 目标不固定：进入 TELEGRAPH 时，按“鸟与 TUBO/BITT 的实际横向距离”选更近的角色；poop 的落点是目标当前坐标。
- 攻击：
  - poop：预兆/落点，0.85 s 抛物线投射物，24×24 判定；
  - return：鸟体从左侧回扫，120×44 判定，target=TUBO；
  - chase：鸟体从目标左侧追扫，target 按实际位置；BITT 目标时攻击高度覆盖壳顶。
- 两个角色都能被命中：
  - TUBO → `_rabbit_contact("LOW_BIRD")`，错误处理给失衡/硬直；
  - BITT → `_turtle_contact(..., "LOW_BIRD")`，减速/翻壳，文案 `feedback.bird_poop`。
- 结束：攻击 life 结束、RECOVER 后 DONE；不会无限追击。
- 仍是固定 55 组、固定区域；没有新角色/按键/资源条/随机地图。

### P2 电弧防御互动（已接入）

- 只在 MISCHIEF 的 `ACTION` + `_mischief_fx_kind=="shock"` 时生效；
- 只抵消 **poop** 投射物；鲨鱼冲撞、水草、温泉等不抵消；
- 失控 BITT 的电弧可替 TUBO 弹开投射物，反馈 `mischief.arc_block`；
- 不产生长期无敌、不改救援优先级、不改 OVERDRIVE/SHOWTIME 状态；不通过反复 SHIFT 延长（只在现有 shock ACTION 窗口内）。

### 验证

- `stage19_bird_behavior` **14/14**：
  - 三种额外行为的 TELEGRAPH/ACTION/RECOVER；
  - poop 命中 TUBO、命中 BITT；回马枪/追逐鸟体命中；
  - 电弧抵消且无事故；
  - 30/60/120 Hz 攻击窗口在 0.56–0.60 s；
- 截图：`feel19/bird-poop-telegraph.png`、`bird-poop-projectile.png`。
- 正式两圈：55/55 通过；新增鸟行为使自动驾驶每圈多 1 次事故（新增攻击没有被自动驾驶适配），不是无解；需真人确认是否公平。

## 4. 未接入 / 部分完成

### P1-B 鲨鱼群（未实现，方案）

现有鲨鱼是**每组一个完整身体矩形**；要做“领头 + 跟随/交错”，必须增加额外的碰撞体和独立攻击状态，不能只画几条影子冒充群体。

建议最小方案：

- 仅对 `shark5`/`shark8` 两个现有组启用 pack；
- 状态：`CIRCLE → LEAD_TELEGRAPH → LEAD_LUNGE → COMPANION_1 → COMPANION_2 → RETREAT`；
- 伙伴有各自 1 次攻击，错开 ≥0.45 s；同一时间最多 1 个攻击体；
- 伙伴只在 LUNGE/TELEGRAPH 的对应矩形参与判定，其余时间不覆盖水域；
- 现有鲨鱼身体矩形仍作为领头；不新增组、不新增类型；
- 需要新的 `_shark_attacks` 碰撞/绘制路径，并跑全量 audit + 两圈，风险高于本批鸟行为，因此本轮**没有强行接入**。

### P2-A 温泉喷口（未实现，方案）

- 不新增障碍组，优先挂在 Z3 深水 `DIVE_GATE`/长隧道附近的现有位置；
- 状态：`IDLE → BUBBLE_TELEGRAPH 0.8 s → ERUPT 0.5 s → COOL 0.7 s`；
- 喷发矩形只在 BITT 水下深度层；TUBO 在壳上不直接受击；
- 预兆：气泡柱/热浪/落点圈，至少 0.8 s；喷发伤害前不出现同帧突袭；
- 玩家应对：提前上浮/换 TUBO/等冷却；不新增按键；
- 需要新增“环境危险矩形”与小范围绘制，先做单组验证，再决定是否加入正式赛道。

### P2-B 抓取型水草（未实现，方案/风险）

- 现有 `mount.state`、`RESCUE_ACTIVE`、`RESCUING` 已经把“兔子离壳”语义占满；水草抓 BITT 需要一个独立“被抓/拖拽/挣脱”状态；
- 不新增按键的前提下，只能复用 SPACE/SHIFT，可能与主动救援冲突；
- 若强行接入，容易造成软锁/无限拖拽或与救援状态叠加；本轮按任务“如果架构不适合，先提交方案”处理，**不接入**；
- 下一批若要实现，需先定义 `GRABBED` 状态优先级低于救援、高于普通 MISCHIEF，并写状态迁移测试。

### 赛道情境化（未实现）

- 本轮没有重排 G10–G17/G31–G35/G39–G41；原因：鸟行为刚接入，先确认 55/55 和 audit；情境化需要改 x/顺序，风险和回归成本高，应作为下一批独立任务。

### 随机性

- 当前是**每个指定鸟固定行为**（bird3 poop、bird4 chase、bird6 return、bird8 poop），不是运行时加权随机；
- 目标角色按实际位置选择，不是固定 TUBO；
- 没有随机地图/随机组；同种子可复现；
- 尚未实现“同一组不同遭遇的权重/冷却/重复约束”；下一批若做，必须先写合法性检查，避免无解组合。

## 5. 回归与验证

- `stage19_p0_readability` 6/6。
- `stage19_bird_behavior` 12/12。
- `stage4_bro_meter` PASS。
- `stage4_hud_layout` PASS；`stage4_hud_score` 41 checks PASS。
- `stage15_mischief` PASS；`stage15_showtime_shift` PASS。
- 两圈正式跑圈：**55/55、0 失败**；鸟行为使每圈 1 次事故（自动驾驶未适配新攻击）；需要真人判断是否公平。
- 全量 55 组 solution audit：**no_solution=[]，design_correct=55**（`_f19_audit2.log`，final target-selection code）；七类设计答案全部通过。
- 30/60/120：鸟行为测试覆盖；原有 `stage8_hz_regression` 仍按原回归执行。

## 6. 美术/音频

- 本轮没有新增正式素材；海鸟/投射物/电弧都是原生占位绘制，**不能标最终美术**。
- 需要美术：海鸟多行为姿态（盘旋、俯冲、回马枪、追逐、排泄投射）、投射物、MISCHIEF 电弧、温泉、水草。
- 需要音频：海鸟预兆/俯冲/命中、投射物飞行/落地、电弧、鲨鱼群、温泉、水草抓取；状态触发点见 FEEL-17 音频清单。
- 等素材到位后按 `FEEL-17-ART-TASKS.md` / `FEEL-17-AUDIO-TASKS.md` 接入；本轮不替代团队制作最终资源。

## 7. 修改文件

- `scripts/race.gd`：海鸟状态机、投射物/鸟体攻击、电弧抵消、P0 相关提示/状态。
- `scripts/autoload/game_manager.gd`：满格主条保持 3/3。
- `scripts/autoload/locale.gd`：SPACE 救援文案、鸟/电弧文案。
- `scripts/ui/hud.gd`：SPACE 键帽。
- `scripts/test/stage19_p0_readability.gd` + scene。
- `scripts/test/stage19_bird_behavior.gd` + scene。
- `scripts/test/stage19_capture.gd` + scene。
- `docs/reports/longrun/feel19/*`：截图/记录。

## 8. 停止

- 未导出任何测试包/候选包/EXE；没有执行 Export。
- `best.json` 未读写；保持原样（MD5 见交付时复核）。
- 本批已完成 P0 + P1-A + 电弧；P1-B/P2-A/P2-B/情境化未接入，等待下一批或制作人决策。
- **不宣布内容冻结，不宣布游戏完成。**
