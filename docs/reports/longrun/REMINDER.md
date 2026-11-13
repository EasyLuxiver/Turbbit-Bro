# 07:00 提醒 — Windows 任务计划程序

## 已注册任务

| 项 | 值 |
|---|---|
| 任务名称 | `TURBBIT-Longrun-Reminder` |
| 触发时间 | `2026-11-12 07:00:00 +08:00`（一次性） |
| 状态 | Ready，NextRunTime `2026/11/12 7:00:00` |
| 运行身份 | 当前用户，`LogonType=Interactive`（只在用户登录会话中显示弹窗） |
| 唤醒 | `WakeToRun` 已开（机器睡眠也会唤醒执行） |
| 执行程序 | `powershell.exe` |
| 执行参数 | `-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "D:\GAMESTUDIO\TURBBIT\tools\longrun_reminder.ps1"` |
| 脚本 | `TURBBIT/tools/longrun_reminder.ps1` |
| 日志 | `TURBBIT/docs/reports/longrun/reminder.log` |
| 状态源 | `TURBBIT/docs/reports/longrun/LONGRUN_STATE.md` |
| 恢复提示 | `TURBBIT/docs/reports/longrun/RESUME_PROMPT.md` |

## 脚本行为

1. 读 `LONGRUN_STATE.md` 的 `STATUS:` / `LAST_UPDATED:` / `NEXT:`，计算心跳年龄。
2. 读 `.lock`：PID 仍存活 → 标 `RUNNING`，明确提示**不要**启动第二个实例；
   PID 已死 → 标 `STALE`。
3. 写一行日志到 `reminder.log`。
4. 用 `WScript.Shell.Popup` 显示摘要（默认 60 秒自动消失），并打开
   `RESUME_PROMPT.md`。
5. 不启动 Godot、不启动 AI 会话、不修改任何项目文件；因此不存在“自动恢复”的假象。
6. `STATUS: COMPLETE` 时只提示“已完成，不要重启”，不提示继续。

## 测试记录

- 命令：
  `powershell -NoProfile -ExecutionPolicy Bypass -File tools\longrun_reminder.ps1 -Test -NoOpen -PopupSeconds 5`
- 结果：退出码 0；日志：
  ```
  2026-11-12 02:06:56 TEST=True status=READY lock=none head=No live worker; task is stopped or not started.
  2026-11-12 02:07:00 popup dismissed
  ```
- 任务注册后查询：`State=Ready`、`NextRunTime=2026/11/12 7:00:00`、
  `StartBoundary=2026-11-12T07:00:00+08:00`、`Enabled=True`。
- **未观测到 07:00 的真实触发**（写这份记录时还没到）。脚本本身已直接运行验证；
  计划任务已注册且 Ready。若 07:00 没有弹窗，先查
  `Get-ScheduledTaskInfo -TaskName TURBBIT-Longrun-Reminder` 的
  `LastTaskResult` 和 `reminder.log`。

## 已知限制（不假装满足）

- 脚本不会自动拉起新的 Claude 会话。项目没有现成的“正式恢复入口”；
  07:00 的提醒只负责把状态和 `RESUME_PROMPT.md` 摆到人面前。
- `LogonType=Interactive` 意味着用户必须处于登录会话；注销状态下不会显示弹窗，
  但任务日志仍会写。
- 如果 07:00 时机器关机且未进入睡眠/休眠，任务不会执行（`StartWhenAvailable`
  只覆盖错过后的补跑，不覆盖关机）。

## 修改 / 删除

```
Get-ScheduledTask -TaskName TURBBIT-Longrun-Reminder | Format-List *
Unregister-ScheduledTask -TaskName TURBBIT-Longrun-Reminder -Confirm:$false
```
