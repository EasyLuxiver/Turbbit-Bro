# FEEL-45 · 浮木下段缩短 / 开局跟随鱼修复

- 基线：FEEL-44
- 未导出、未打包、未覆盖 Web/EXE；`best.json` MD5 未变。

## 1. 浮木下段缩短

`log1`（以及教学的 `tut_log1`）高度从 **240 → 215 px**：

- 水下段减少 25 px；
- 乌龟下潜通道更短；
- `stage34_first60` 复测：
  - `rabbit_only=false`
  - `turtle_only=false`
  - `bro_dive=true`

降低到 215 是有意的折中：如果再缩到 210/200，单乌龟（带骑乘兔）也可能直接通过，
BRO DIVE 就不再是必须的。当前保留 BRO DIVE 的教学语义，同时缩短水下段。

## 2. 开局三只跟随鱼

根因：FEEL-44 把鲨群剪影改成“跟随玩家坐标”后，没有判断 shark6 是否在附近；
开局时 `_shark_pack` 已初始化，导致三只剪影从第一帧就画在角色身后。

修复：只有

- 鲨群已经进入非 `CIRCLE` 的三拍，或
- 玩家与 shark6 的距离 ≤1600 px

才画跟随剪影。

真实开局截图：`screenshots/f45-start.png`——只有开场海鸟，没有三只鱼。

## 3. 兔子落水独立性

`rescue_suction_offset` 只保留横向吸附；兔子落水后不再跟随乌龟上浮/下潜。
`stage35` 的 `rescue_suction_horizontal_only` 通过；`stage4_water_rescue`
water 捕获仍 exit 0。

## 4. 回归

- `stage3_playtest`：260.9/260.9 s，55/55，4 accidents/lap。
- `stage34_first60`：PASS。
- `stage34_tutorial_relay`：PASS。
- `stage42_shark_fairness`：PASS（此前基线，无鲨群改动）。
- `stage35_combo_audit`：PASS。
- `best.json` MD5 未变。

## 5. 仍需要注意

- 浮木高度 215 是折中值；如果制作人认为仍太长，可以继续缩，但
  需要明确接受“单乌龟+骑乘兔可能也能过”。
- 自动跑仍 4 accidents/lap，原因是测试代理不会按三拍提示躲避。
- 没有音效/正式美术。

**STOP，等制作人确认这版浮木长度。**
