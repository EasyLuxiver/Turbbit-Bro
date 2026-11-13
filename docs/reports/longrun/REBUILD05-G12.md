# G12 — 暂停界面补上操作对照：忘了键就按 ESC 看一眼

日期：2026-11-13（05:47 起）
改动：`scripts/ui/pause_menu.gd`（多一行 `menu.hint`）
截图：`screenshots/rebuild05-pause-g12.png`（中）、`rebuild05-pause-g12-en.png`（英），均 1280×720

## 为什么做这一条

玩家唯一能“停下来想一下我该按哪个键”的地方就是暂停。旧暂停面板只有
标题、Take a breath、三个按钮和 `ESC 继续 R 重开 M 主菜单`——**没有一个字说
SHIFT / ↑ / ↓ 各自做什么**。开局那 6 s 有过一次按键说明，但跑起来以后忘了就没处查；
中英文都是这样。

`Locale` 里其实早就有一条现成的 `menu.hint`（双语、逐角色分工：
「SHIFT 换人 / ↑ 兔子跳·乌龟跃起 / ↓ 兔子趴低·乌龟下潜」），
但全项目没有任何界面引用它——写了、没挂。

## 做了什么

`pause_menu.gd` 在按钮和快捷键行之间加一个 18 px 的 Label，文本直接取
`Locale.t("menu.hint")`：

```
SHIFT 换人    ↑ 兔子跳 / 乌龟跃起    ↓ 兔子趴低 / 乌龟下潜
```

- **没有新增字符串**：`locale.gd` 一个条目都没加（mtime 停在 04:49）；
- **没有新增素材**：只有文本 Label，颜色用现有的浅蓝色档；
- **没有改暂停行为**：按钮、快捷键、暂停/恢复逻辑都没动。

## 证据

| 验收点 | 证据 |
|---|---|
| 中文 1280×720 完整可见、不裁切 | 本人打开 `rebuild05-pause-g12.png`：面板内一行读完，左右留着内边距 |
| 英文 1280×720 完整可见 | 本人打开 `rebuild05-pause-g12-en.png`：`SHIFT transfer ↑ RABBIT JUMP / TURTLE LEAP ↓ RABBIT CROUCH / TURTLE DIVE` 一行到底，面板在屏内 |
| 原有内容不少、继续能恢复 | `stage4_opening_pause`（窗口化 + `--force-opening`）：7/7 用例 PASS，pause 行 8 条断言全 true，含 `breath_text`、`three_buttons`、`resume_works` |
| 只动了这一处 | `find scripts scenes -newermt "05:40"` 只列出 `scripts/ui/pause_menu.gd`（TURBBIT 未纳入 git，无法用 diff 证明，见下） |
| 回归 | 见“回归”一节 |

英文截图是临时把 `user://settings.json` 改成 `{"language":"en"}` 拍的，拍完已还原
（md5 `835b0ae4f1840c8e63c26bb2018c1fee`，内容 `{"language":"zh"}` 逐字节一致）。

## 回归

- `stage4_opening_pause`（窗口化，`--force-opening`）：`STAGE4 OPENING/PAUSE: PASS`。
  不加该参数时 boot/freeze 两个用例本来就不过（开场只在正式入口挂），与本改动无关。
- 两圈 `stage3_playtest`（`fullrun-g12.log`）：与 `fullrun-g11.log` 逐字一致。
- 21 场景 headless 批量回归：全部 exit 0（日志 `$TEMP/reg-g12-<scene>.log`）。
- `best.json` 跑后 md5 未变。

## 已知限制

- 这是一行文字，**不改变暂停时的信息结构**（仍是三个按钮 + 两行按键说明）；
  面板在 1600×900 下会随内容变宽，未做最大宽度约束。
- 未做真人验证：玩家是否会因此少按错键，需要制作人试玩确认。
- `TURBBIT/` 整体未纳入 git（`git ls-files TURBBIT` 为 0），所以“只改一个文件”
  用文件时间戳证明，而不是 `git diff`。
