# FEEL-09 工作日志（内部，不是交付报告）

## 2026-11-14 01:56 起

- best.json 冻结 0700；后续探针误写 0.034 s 假纪录，已用冻结备份还原并再次冻结。
- stage4_hud_contrast 改窗口运行 PASS；headless 加 SKIP 保护，不再 600 s 挂死。
- 菜单 windowed PASS（headless 15/16 条失败全是鼠标 hover/click）。
- 阶段 1 基线探针全 PASS：hz / balance / 两圈 / flow / shift / identity / rocks / lesson。

## 02:00–03:30 美术

- Anima 重出 TUBO 参考（seed20/21），v2 拆 10 件试了 2 段鳍，GIF/状态图已存
  `art_test/tubo_v2/tubo_v2_preview.gif`、`tubo_v2_states.png`。
- 后续改用 anima-base 平涂参考想重切，手工多边形没对齐，`parts_v2` 已不可复现
  GIF；`art_test/tubo_v2/README.md` 已写明。正式技术验证以 `art_test/tubo/` v1 为准。
- Z2 场景润色 d0.30 对照图已存 `art_test/polish/compare_polish.png`。

## 03:00–03:40 玩法优化

- 关卡节奏（只动非动态障碍）：
  - bird2 12850 → 13280（Z1 最长空档 7.23 → 5.8 s）
  - gate3 19400 → 19200（Z2 最长空档 6.29 → 5.96 s）
  - beam3 17000 → 16750（单角色最小 2.50 → 3.54 s）
  - gate5 37480 → 37630（log4→gate5 2.91 → 3.53 s）
  - gate7 宽 760 → 600（长隧道→log6 3.00 → 3.62 s）
- 结果：`stage4_core_experience` PASS；`stage4_metrics` 只剩 combined 3.62 < 5。
  `stage3_selftest` 只剩 baseline 的 JOINT/CAPSIZES 文案（已改成 CAPSIZES 后 PASS）。
- HUD：SHIFT/浮木/高墙提示保持 5 s；新指令出现时清掉底栏 hint，最多两行。
- Showtime 奖励文案改成实际氧气增量（满氧显示“氧气已满”）。
- 鳗鱼加高光；吊网加重型 crate + 梁下“！”预警。
- z1_rhythm 探针修了神游延迟导致的起跳晚点（等离地再松手），PASS。
- G21 探针改用 kind|identity 课键，PASS。

## 证据

- gate: `docs/reports/longrun/gate-feel09c.txt`
- 新探针 JSON：`core-feel-09-p0a/p0b/p0cd/p1a-*.json`
- 截图：`screenshots/core-feel-09-*`

## 04:35 代码冻结
- 最终套件 final-suite.txt：除 stage4_metrics 1 条（3.62<5）与 stage2 基线 9 条外全 PASS。
- 两圈 3m05 墙钟、55/55、0 事故。
- best.json 还原 0700 并冻结；交付前解除只读。
- 设置语言 zh。
