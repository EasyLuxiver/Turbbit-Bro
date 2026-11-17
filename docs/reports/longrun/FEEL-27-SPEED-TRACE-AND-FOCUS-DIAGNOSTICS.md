# FEEL-27 SPEED TRACE & WINDOW FOCUS DIAGNOSTICS

- 基线：FEEL-26-ROOT-CAUSE-AND-WINDOW-QA
- 模式：CONTROLLED_WRITE
- 未导出/打包/复制 EXE；best.json 未修改。

## 1. 速度写入点

`turtle.speed` 直接/间接写入：

- `race.gd:827` 初始化 220
- `race.gd:1770` 兔子硬直上限 140
- `race.gd:1788/1803` 紧急恢复 180
- `race.gd:2099/2173` 乌龟接触 `*= 0.6`
- `race.gd:2123` 动态浮标/货箱接触 `*= 0.82`
- `race.gd:2688` OVERDRIVE 提速
- `race.gd:2786/2799/2807` 联合事故/恢复
- `race.gd:6190-6249` 截图/测试夹具
- `turtle_controller.gd` 受控/待命/救援/受击的 move_toward 目标

## 2. 三次复现时间线

诊断日志（同一初值，第一圈）：

```
SPEED_TRACE old=220.0 new=241.0 x=3206 ...   # 食物加速
SPEED_TRACE old=253.0 new=238.0 x=4179 ...   # 加速结束回落
SPEED_TRACE old=220.0 new=132.0 x=5092 ctl=rabbit mount=RIDING acc=RABBIT_STUN daze=0.0 raid=3.2
SPEED_TRACE old=132.0 new=153.0 x=5100 ...   # 事故后恢复
```

second run identical at x=5092.

## 3. 根因

第一次 220→132 发生在 **x=5092，同一帧 `RABBIT_STUN`**。  
因此 132 不是起跳失败的原因，而是**兔子撞上 rock2 后的硬直减速**。  
真正根因是自动驾驶在 x=5092 才按跳：rock2 从 5100 开始，兔子身体已经与岩石相交，起跳请求被硬直/碰撞抢先，速度为事故后 `220*0.6=132`。

不是：
- rock2 可见碰撞体分离；
- MISCHIEF 扣速；
- 待命乌龟掉速；
- 0.6 倍率直接导致起跳失败。

## 4. 修复

只修自动驾驶的 rock2 起跳 lead：

`stage3_playtest.gd::_jump_over()` 的 lead 下限从 15 px 改为 55 px。  
这是测试驾驶参数，不是游戏规则；未改 rock2 碰撞、尺寸、容错或正常玩家输入。

修复后：

```
FINISH run=1 passed=55/55 accidents=1
FINISH run=2 passed=55/55 accidents=1 (Retry)
STAGE3 PLAYTEST: PASS
```

rock2 不再出现起跳失败/擦碰。

## 5. 窗口焦点

实际窗口启动、菜单 ENTER、漫画 ESC、教学进入成功；`STEP 1/4` 已消失，提示随角色切换。  
但 Windows 键盘注入仍不能稳定把教学完整跑到结算，曾出现输入落到非游戏窗口。  
本轮没有建立稳定焦点恢复机制；完整窗口流程仍未完成。

## 6. 回归

- `stage3_playtest` PASS：两圈 55/55，每圈 1 次事故（非 rock2）。
- 55 组 audit：四片 `no_solution=[]`。
- `stage4_flow` / `stage4_bilingual` / HUD / tutorial / catch / oxygen / mischief / bird / shark / coupling 既有回归保持通过。
- best.json MD5 未变。

## 7. 未解决

1. 窗口焦点/输入链路仍不稳定，完整窗口流程未完成。
2. 两圈仍有 1 次/圈事故（海鸟/其他），不是 rock2。
3. 海鸟纸片体、鲨鱼剪影仍为灰盒。
4. 自动 SHOWTIME 保持关闭。

## 8. 自判

rock2 速度异常已确认并修复，修复前后证据完整；**完整窗口试玩仍未完成**，因此不具备 Producer 最终验收条件。
