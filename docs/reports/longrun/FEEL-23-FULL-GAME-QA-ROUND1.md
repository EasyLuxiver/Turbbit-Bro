# FEEL-23 FULL GAME QA · 第一轮全面质检与修复

- 日期：2026-11-15
- 基线：`FEEL-22-CORE-STABILITY-AND-RULE-UNIFICATION`
- 模式：CONTROLLED_WRITE
- **未导出/打包/复制 EXE，未执行 Godot Export。**
- **best.json 未修改，MD5：`067DEB9A71A19C2F6F9F6DC41FEABF09`。**
- 不宣布游戏完成或内容冻结。

## 1. 本轮结论

完成了一轮以“真实状态/真实运行”为主的 QA 和修复：

- 两套失控逻辑收敛为惩罚条一套；旧神游、旧自动下潜、旧 OVERDRIVE 自动链停用。
- SHIFT 不再继承旧角色的下潜尾、↑ 缓存、辅助下潜状态。
- 救援统一为“接触即接住，SPACE 只追近”，删除超时自动回壳。
- 动态浮标/吊装货箱/漂流货箱删除了无法用画面解释的水下碰撞段，并有实机截图。
- 特殊海鸟攻击恢复；预兆 0.55→0.80 s；ACTION 期间不再同时画本体和独立纸片鸟。
- 负面/正面 HUD 改名为“捣乱压力 / 兄弟配合”，并给 1/2 格增加抱怨/警告反馈。
- 教学假终点、`STEP 1/4`、系统播报腔文本清理；教学窗口化流程通过。

但**没有完成一次完整人手 55 组试玩**，因此不能把版本描述成“Producer 最终验收版”。

## 2. 问题清单与处理

| 编号 | 优先级 | 系统 | 问题 | 根因 | 处理 | 复测 |
|---|---|---|---|---|---|---|
| F23-01 | P0 | 失控 | 旧神游与惩罚条两套逻辑同时影响角色 | `BroBrain.tick`/drift 效果仍在运行链 | 停用 tick、漂移位置/速度/空气修正、自动 OVERDRIVE | 耦合 19/19；代码检查 |
| F23-02 | P0 | SHIFT | 切走后乌龟继续潜、兔子吃旧 ↑ 缓存 | `standby_dive_t`、buffer 跨 SHIFT、dive assist | 强制清零/清缓存/关闭辅助下潜 | controller + `_physics_process` 路径检查 |
| F23-03 | P0 | 救援 | 接触自动接与超时自动回壳竞争 | `_rescue_auto` 仍可启动 | 删除超时自动回壳；接触接住；SPACE 追近 | 氧气 8/8；catch matrix PASS |
| F23-04 | P0 | 动态障碍 | 吊箱/浮标/漂流箱下方有独立深色判定块 | 9 组动态 SURFACE_ROCK 共用 ANTI_DIVE 段 | 删除三类身份的反下潜段，只保留可见主物体 | 3 张实机图；55 audit no_solution=[] |
| F23-05 | P1 | 海鸟 | 特殊攻击被关闭，恢复后又有纸片体 | 特殊攻击与本体动画不同源 | 恢复特殊攻击；预兆 0.8 s；ACTION 隐藏本体避免双鸟 | `stage19_bird_behavior` 17/17 |
| F23-06 | P1 | HUD | 两个 0/3 含义不清 | 负向/正向共用数字和抽象名 | 改为“捣乱压力/兄弟配合”；1/2 格抱怨/警告 | HUD 41/41；bilingual PASS |
| F23-07 | P1 | 教学 | 假终点、STEP 文本、结束直接 reload | tutorial 用 world_end 画终点但 test_no_finish | world_end 外移；播 `tutorial.done`；移除 STEP；确定性过渡 | `stage13_tutorial_flow` 窗口化 PASS |
| F23-08 | P2 | 文本 | “惩罚条清零/好戏开场/表演结束”系统播报腔 | 机制名直接进玩家文本 | 改为兄弟口吻；保留内部 SHOWTIME 标识 | Locale 检查 |
| F23-09 | P2 | 两圈 | rock2 自动驾驶擦碰 | 自动驾驶未适配取消自动下潜 | 不作为真人难度结论；记录 | `stage3_playtest` 55/55、2 事故 |
| F23-10 | P2 | 海鸟视觉 | 特殊攻击体仍是纸片 | 无新美术，只有原生绘制 | 与本体同屏问题已消除；仍属灰盒占位 | 截图 |
| F23-11 | P3 | 性能 | 未做长时间 CPU/内存剖析 | 本轮工具时间限制 | 未声明通过 | 未验证 |

## 3. 最终规则

### 捣乱压力

- 每角色独立 3 格。
- 有效失误 +1，当前受控角色显示；另一个角色只在 >0 时显示。
- 1 格：显示抱怨反馈，不修改输入；干净通过会释放 1 格压力。
- 2 格：显示“快忍不住了”警告，不自动动作；干净通过会释放 1 格压力。
- 3 格 + 该角色未受控：进入 MISCHIEF；有预兆、动作、结束/冷却；SHIFT 到该角色可立即制止；救援优先。
- 不自动跳、不自动潜、不暗中改输入。干净通过/有效操作会释放压力，玩家始终有脱困途径。

### 兄弟配合

- 连续干净通过 +1；事故/碰撞清零。
- 满 3 触发 SHOWTIME；给奖励/氧气；不打断当前控制权。
- 和捣乱压力各自独立，没有共享数值。

### 救援

- 接触即接住。
- SPACE 只负责追近，不隔空救。
- 没有超时自动回壳。
- 氧气归零真实失败。

## 4. 真实运行检查

| 检查 | 结果 |
|---|---|
| 菜单 → 漫画 → 教学（窗口 + OS 键盘注入） | 走到教学，提示随角色切换 |
| `stage13_tutorial_flow`（窗口化） | PASS，含跳过/结束 |
| `stage4_flow` | PASS |
| `stage4_bilingual` | PASS |
| `stage4_hud_layout` / `stage4_hud_score` | PASS / 41/41 |
| `stage4_opening_pause` | PASS |
| `stage5_c_hud` | PASS |
| `stage13_catch_matrix` | PASS |
| `stage15_oxygen_fail` | 8/8 |
| `stage15_mischief` | 13/13 |
| `stage19_bird_behavior` | 17/17 |
| `stage21_shark_pack` | 9/9 |
| `stage22_coupling` | 19/19 |
| 55 组 solution audit | 四片全部 `no_solution=[]` |
| 两圈自动驾驶 | 55/55；run1/run2 各 2 次事故，rock2 擦碰 |

## 5. 证据

- HUD：`docs/reports/longrun/feel22/hud-unified-zh.png`
- 教学窗口：`docs/reports/longrun/feel22/tutorial-window.png`
- 动态障碍：`docs/reports/longrun/feel22/dynamic-buoy-dip.png`、`dynamic-dock-crate.png`、`dynamic-drift-crate.png`
- 海鸟：`docs/reports/longrun/feel19/bird-poop-telegraph.png`、`bird-poop-projectile.png`
- 测试日志：`/tmp/feel23-*`（本轮环境临时日志；长期结论见上述测试 JSON）

## 6. 未解决 / 风险

- **没有一次完整人手 55 组试玩**；不能把自动驾驶事故当真人难度。
- 特殊海鸟攻击体仍是原生纸片；已避免同屏双鸟，但还不是最终美术/动画。
- 鲨鱼群只有 shark6，跟随剪影仍是占位。
- rock2 自动驾驶擦碰；需要真人确认起跳窗口。
- 未做长时间 CPU/GPU/内存剖析。
- `showtime_active` 仍有 race / GameManager 两处镜像。
- 旧测试 `stage8_hz`、`stage12_overdrive` 测的是已停用旧行为，不再作为通过依据。

## 7. 自判

**还不具备交给 Producer 做最终验收的条件。**  
它具备的是：核心旧逻辑已收敛、主要状态冲突已清理、文本/HUD/教学/动态障碍可读性明显改善、自动化与窗口化教学流程通过。还缺一次完整人手试玩和特殊敌人体验确认。

## 7.1 修改文件（本轮）

核心：`scripts/race.gd`、`scripts/autoload/game_manager.gd`、`scripts/autoload/locale.gd`、`scripts/actors/turtle_controller.gd`、`scripts/actors/rabbit_controller.gd`、`scripts/systems/level_data.gd`、`scripts/ui/hud.gd`、`scripts/result.gd`、`scripts/ui/opening.gd`、`scripts/test/tutorial.gd`。

测试/证据：`scripts/test/stage22_coupling.gd`、`scenes/stage22_coupling.tscn`、`scenes/stage22_capture_dynamic.tscn`、`scripts/test/stage22_capture_dynamic.gd`，以及 `stage4_bilingual`、`stage4_flow`、`stage4_hud_score`、`stage17_mischief_readability`、`stage19_bird_behavior`、`stage4_collision_feedback` 的期望更新。

## 8. 停止

- 未导出、未打包、未复制 EXE。
- 未修改 best.json。
- 等待制作人试玩；不宣布完成或内容冻结。
