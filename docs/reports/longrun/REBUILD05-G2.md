# G2 — BRO DIVE 的第二步有提示了：“松开 ↓”

日期：2026-11-13（04:17 起）
改动：`scripts/race.gd`（`dive_release_ready()`，只读状态）、
`scripts/ui/hud.gd`（正式 HUD 的乌龟行）、
`scripts/autoload/locale.gd`（`hud.coop_release` 中英各一条）
探针：`scripts/test/stage5_g2_release.gd` + `scenes/stage5_g2_release.tscn`（新）
数据：`rebuild05-g2-release.json`

## 为什么做这一条

B3 的实测结论是：BRO DIVE 的窗口不缺（178/180 通过），缺的是**第二步的可读性**——
起跳和 SHIFT 玩家看得见，但“什么时候松开 ↓”没有任何信号。
最自然的操作（一直按住）也能落回壳上，却会擦水记一次 −100，
画面上只有水花差别。玩家做对了大半、却为最后一个没有提示的动作挨罚。

C 段的协作条只覆盖“什么时候该做连招”（兔子行准备/现在），
连招一旦开始、组被记账，整行就收掉了——正好缺了后面的“松手”这一拍。

## 做了什么

只加一个读数与一行字，不改判定、不改碰撞、不加惩罚：

```gdscript
# race.gd：三个条件全部只读“已经发生”的状态
func dive_release_ready() -> bool:
    # 1) 兔子还在空中（没落壳）
    # 2) 壳仍在主动下潜（松开后自然消失）
    # 3) 壳已越过浮木右缘 40 px（B3 的标准松手点），窗口 400 px
```

HUD 把它写在**既有左上角状态区的乌龟行**（金色 `松开 ↓ 上浮接人！` /
`RELEASE ↓ - SURFACE & CATCH!`），不重开时机条、不新增面板。
礁拱下潜、接应下潜、普通下潜都不满足“兔子空中 + 浮木在后”，因此不出现。

## 探针读数（`rebuild05-g2-release.json`）

同一组 log1，两条完全相同的标准时机路线，只在提示出现后做不同选择：

| | 提示出现 | 出现位置 | 松手后 | 事故 |
|---|---|---|---|---|
| 跟着提示松手 | 是 | 越过右缘 **42.7 px**（标准点 40） | 提示立即消失 | **0** |
| 一直按住 | 是 | 同上 | — | **1**（擦水，落点仍在壳上） |

不该出现的三种场景：

| 场景 | `dive_release_ready()` | 乌龟行文字 |
|---|---|---|
| 礁拱（DIVE_GATE）下潜 | false | 空（不显示） |
| 接应下潜（RABBIT_WATER + 追接） | false | 空（不显示） |
| 松手后的下一帧 | false | 空 |

版面：提示可见时四块面板总面积 **6.0%**（门槛 8%），英文行在面板内放得下
（`cue_fits_en=true`）。`G2 RELEASE: PASS`。

## 这条提示改变了什么

它把“我做了判断然后成功了”从一次**沉默的操作**变成一次**可见的时机选择**：
玩家在金色文字出现的那一小段时间里按下的松手，现在能被自己看到、也能被结果确认
（0 事故 vs 按住 = 1 事故）。它不降低难度，也不替代技巧——手快的玩家可以不用它，
手慢的玩家第一次能靠它学会。

## 配套的一句教学

`lesson.log` 原来只说“兔子先跳，换乌龟下潜，两条路一起过”，第三步没有说法。
现在改成“浮木 - 兔子先跳，换乌龟下潜；越过木尾松开 ↓ 上浮接人”
（en: `FLOATING LOG - JUMP, SHIFT, DIVE. PAST THE LOG, RELEASE ↓ TO CATCH.`），
和 HUD 提示用同一套说法。`stage5_f_lessons` 与 `stage4_bilingual` 复跑 PASS。

## 回归

带提示与教学新文案的两圈全流程（`stage3_playtest`，正式 `race.tscn`，13 组动态）：

```
RESULT run1 time=272.9 score=9770 grade=S passed=55 accidents=0
RESULT run2 time=272.8 score=9770 grade=S passed=55 accidents=0  (Retry)
STAGE3 PLAYTEST: PASS
```

`best.json` md5 跑后仍 `c322f9a20321c5b618f98db7e4120969`。
另复跑 `stage5_c_hud`、`stage4_hud_priority`、`stage4_bilingual`、`stage5_f_lessons` 全 PASS。
QC：`tbb-exp05-g2` 5/5 pass。

## 已知限制

- 只有 BRO DIVE 有这条提示；BRO OLLIE 的蹬踏与普通跳跃没有对应提示（本轮不做）。
- 提示窗口固定在“越过右缘 40 px 起 400 px”，没有按基速缩放；Z1/Z2/Z3 的
  基速差 220/240/260，最坏情况下窗口时间差约 18%，仍大于一次松手的反应时间。
- 仍是灰盒文字，不带声音与动画（边界 A1/A3）。
- 没有真人验证——见交付报告 §12。
