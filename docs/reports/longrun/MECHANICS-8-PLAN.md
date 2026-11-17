# TURBBIT 机制拉到 8 分 · 规划书

> **状态：待制作人审阅。审阅通过、明确说“开始”之前，不改代码。**

**目标：** 在不新增敌人、障碍种类、按键、角色技能和环境系统的前提下，把“纯机制趣味”从 6.5 拉到 8.0。

**判断标准（8 分）：** 会推荐给别人；会为了 S 主动再跑一局；每次失败都能归因到“按晚了 / 换晚了 / 氧气没管”，而不是“莫名其妙”。

**技术栈：** Godot 4.7 / GDScript / 现有 `race.gd`、`hud.gd`、`level_data.gd`、`tuning.gd`；不引入新依赖。

---

## 1. 现状与差距

| 维度 | 现在 | 8 分需要 |
|---|---|---|
| 失误代价 | 0.8 s 硬直 + 扣 100 分，跑照常继续 | 失误要动氧气，让“撞一下”影响后面的路线 |
| S 目标 | 只在结算页看到 | 跑图里能看到离 S 还差几次 |
| 选择密度 | 10 组双解 / 53 组 | 16–18 组双解，且每组两条路线都真实可过 |
| 换人技术 | SHIFT 基本免费，主要是“换对角色” | 换对时机有可见奖励，换晚/换错没有 |
| 表现 | 灰盒 + 文字提示 | 不在本轮；留给美术音效 |

当前自动跑基线：238.6–238.7 s、53/53、4 accidents/圈、max_stuck=0、grade B。
`best.json` 基线：`067DEB9A71A19C2F6F9F6DC41FEABF09`。

## 2. 四个改动（全部复用现有系统）

### A. 事故扣氧 + 2 秒不回氧

- 严重事故：氧气 −0.8，2.0 s 内不恢复；
- 乌龟擦碰（`TURTLE_WAVE` / `TURTLE_DIVE_LATE`）：氧气 −0.3，1.0 s 内不恢复；
- 任何一次撞击不会把氧气直接打到 0：最低保留 0.6，避免“一撞即死”；
- 氧气耗尽仍然只由持续下潜造成，失败页原因不变。

### B. 跑图内 S 进度

- 右上角加一行小字，不恢复旧的 0/3 面板；
- 0 失误：`S · 干净 12` / `S · CLEAN 12`；
- 首次失误：`S 已失去 · 失误 1` / `S LOST · 1 MISTAKE`，变红；之后持续显示失误数；
- 中英文实时切换。

### C. 双解 10 → 16–18 组

优先加这 8 组，目标 18：

`bird3`、`bird7`、`bird8`、`beam3`、`beam8`、`rock5`、`rock7`、`rock11`

如果某组两条路线测不过，按顺序换候补：`bird9`、`beam7`、`rock9`、`rock12`。
最终至少 16 组；每组必须通过 `stage35_combo_audit` 的 rabbit / turtle 两条路线。

### D. 换人时机奖励

- 威胁前 **0.30–0.70 秒**内换到“能解这组”的角色：`GOOD SWAP`，+50 分；
- 只对简单组生效：`LOW_BIRD`、`LOW_BEAM`、`SURFACE_ROCK`、`DIVE_GATE`；
- 组合组（`FLOATING_LOG` / `HIGH_WALL` / `SHARK`）不重复奖励，它们已有自己的连招/鲨群收益；
- 同一组只奖励一次，防止来回刷；
- 第一版**只加奖励，不加换晚惩罚**。如果全关出现刷换，再单独评估 0.15 s 交接硬直。

## 3. 文件地图

| 文件 | 责任 |
|---|---|
| `scripts/systems/tuning.gd` | 新增事故扣氧、恢复锁、换人窗口常量 |
| `scripts/race.gd` | 扣氧落点、恢复锁、S 数据、换人时机判定 |
| `scripts/ui/hud.gd` | 右上角 S 进度行 |
| `scripts/autoload/locale.gd` | 4 条新文案（zh/en） |
| `scripts/systems/level_data.gd` | 8 组加 `"dual": true` |
| `scripts/test/stage43_air_stakes.gd/.tscn` | 新建：事故扣氧 + 恢复锁 |
| `scripts/test/stage44_swap_timing.gd/.tscn` | 新建：换人时机奖励 |
| `scripts/test/stage35_combo_audit.gd` | 双解名单/数量 10 → 16–18 |
| `scripts/test/stage4_bilingual.gd` | S 进度中英文断言 |
| `scripts/test/stage3_selftest.gd` | 全关/HUD 回归 |
| `docs/PRODUCER_QA_GUIDE.md` | 双解数量、S 进度、扣氧说明 |

## 4. 任务

### Task 0：先写验收标准（动手前）

- [ ] 在 `LESSONS/CHECKS` 下开任务，晚于产物写会判 FAIL：

```bash
cd /d/GAMESTUDIO
python LESSONS/CHECKS/qc.py start --task tbb-mechanics-8 \
  --title "机制拉到 8 分" \
  --artifact TURBBIT/docs/reports/longrun/MECHANICS-8.md \
  --criteria \
  "严重事故后 2 秒内氧气下降 >=0.8 且 2 秒内不恢复（stage43）" \
  "跑图 HUD 显示 S 进度，首次失误后切为 S LOST，中英文均正确（stage4_bilingual）" \
  "双解组 >=16，每组 rabbit/turtle 两条路线都通过（stage35）" \
  "威胁前 0.30-0.70 秒换到正确角色记录 GOOD SWAP 并 +50 分（stage44）" \
  "全关 53/53、无卡死、自动跑事故 <=6/圈、氧气失败 <=1/圈（stage3_playtest）" \
  "一局内至少 3 次 combo/双解高峰，且 S 目标在跑图中可见；机制趣味性自评 8/10"
```

- [ ] 备份 `best.json` 到 `/tmp/best.mechanics8.json`，每轮测试后恢复并核对 MD5。

### Task 1：事故扣氧

**文件：**
- 修改 `scripts/systems/tuning.gd`（氧气常量区）
- 修改 `scripts/race.gd`（`_update_oxygen`、`_trigger_accident`、`_turtle_contact`、`_reset_run`）
- 修改 `scripts/autoload/locale.gd`（`hint.air_hit`）
- 新建 `scripts/test/stage43_air_stakes.gd` + `scenes/stage43_air_stakes.tscn`

**代码：**

```gdscript
# tuning.gd，紧挨 OXYGEN_* 常量
const ACCIDENT_OXYGEN_COST := 0.8
const ACCIDENT_OXYGEN_COST_MINOR := 0.3
const ACCIDENT_OXYGEN_MIN := 0.6
const ACCIDENT_RECOVER_LOCK := 2.0
const ACCIDENT_RECOVER_LOCK_MINOR := 1.0
```

```gdscript
# race.gd，变量区
var _oxygen_recover_lock_t := 0.0

# _reset_run / load_level 里同时清零：
# _oxygen_recover_lock_t = 0.0

func _apply_accident_air_cost(cost: float, lock: float) -> void:
	_oxygen_recover_lock_t = maxf(_oxygen_recover_lock_t, lock)
	var target := maxf(GameManager.oxygen - cost, Tuning.ACCIDENT_OXYGEN_MIN)
	if target < GameManager.oxygen:
		GameManager.oxygen = target
		GameManager.oxygen_phase = oxygen_phase()
		GameManager.hint.emit(Locale.t("hint.air_hit"))
```

```gdscript
# _update_oxygen：锁定期只停恢复，不停水下消耗
if _oxygen_recover_lock_t > 0.0:
	_oxygen_recover_lock_t = maxf(_oxygen_recover_lock_t - delta, 0.0)
...
else:
	if _oxygen_recover_lock_t <= 0.0:
		GameManager.oxygen = minf(GameManager.oxygen
			+ delta * Tuning.OXYGEN_RECOVER, GameManager.oxygen_capacity())
```

```gdscript
# _trigger_accident，charge 且 rescue_ctx == "NONE" 时：
GameManager.note_accident(reason)
_apply_accident_air_cost(Tuning.ACCIDENT_OXYGEN_COST, Tuning.ACCIDENT_RECOVER_LOCK)
```

```gdscript
# _turtle_contact，charge 时：
_apply_accident_air_cost(Tuning.ACCIDENT_OXYGEN_COST_MINOR,
	Tuning.ACCIDENT_RECOVER_LOCK_MINOR)
```

- [ ] 测试脚本 `stage43_air_stakes.gd`：

```gdscript
extends Node
var is_runner := false
var race
var failures: Array[String] = []

func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()

func _run() -> void:
	GameManager.test_no_best = true
	GameManager.start_race()
	for i in 5:
		await get_tree().process_frame
	race = get_tree().current_scene
	race.set_physics_process(false)
	race.opening_active = false
	race.test_disable_hazards = true
	race.load_level([], [])
	GameManager.oxygen = Tuning.OXYGEN_MAX
	race.accident_state = "NONE"
	race.hazard_cooldown = 0.0
	var before := GameManager.oxygen
	race._trigger_accident("RABBIT_STUN")
	_check(GameManager.oxygen <= before - 0.79, "severe costs 0.8")
	_check(race._oxygen_recover_lock_t >= 1.9, "2s recovery lock")
	var locked := GameManager.oxygen
	race._update_oxygen(1.0)
	_check(is_equal_approx(GameManager.oxygen, locked), "no recovery during lock")
	race._update_oxygen(1.2)
	_check(GameManager.oxygen > locked, "recovery after lock")
	GameManager.oxygen = 0.7
	race._apply_accident_air_cost(Tuning.ACCIDENT_OXYGEN_COST,
		Tuning.ACCIDENT_RECOVER_LOCK)
	_check(GameManager.oxygen >= 0.6 - 0.001, "a hit never empties air")
	print("STAGE43 AIR STAKES: " + ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)

func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
		print("  FAIL " + msg)
	else:
		print("  ok   " + msg)
```

- [ ] 跑：`Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT res://scenes/stage43_air_stakes.tscn`，期望 `STAGE43 AIR STAKES: PASS`。
- [ ] 提交：`feat(turbbit): 事故扣氧与恢复锁`

### Task 2：跑图内 S 进度

**文件：**
- 修改 `scripts/ui/hud.gd`（`tr` 面板、`_refresh`）
- 修改 `scripts/autoload/locale.gd`
- 修改 `scripts/test/stage4_bilingual.gd`

**代码：**

```gdscript
# hud.gd，变量区
var s_label: Label

# _ready 的 tr 面板
s_label = _label(tr, 18, GOLD)
s_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

# _refresh 末尾
if GameManager.accident_count == 0:
	s_label.text = Locale.t("hud.s_clean", [race.passed_count()])
	s_label.add_theme_color_override("font_color", GOLD)
else:
	s_label.text = Locale.t("hud.s_lost", [GameManager.accident_count])
	s_label.add_theme_color_override("font_color", RED_TEXT)
```

```gdscript
# locale.gd STRINGS
"hud.s_clean": {"zh": "S · 干净 {0}", "en": "S · CLEAN {0}"},
"hud.s_lost": {"zh": "S 已失去 · 失误 {0}", "en": "S LOST · {0} MISTAKE"},
"hint.air_hit": {"zh": "撞掉一口气！先别下潜", "en": "AIR KNOCKED OUT! DON'T DIVE YET"},
"feedback.good_swap": {"zh": "换得漂亮！", "en": "GOOD SWAP!"},
```

- [ ] 在 `stage4_bilingual` 的 HUD 段末尾加：0 失误时含 `S`；`note_mistake` 后含“已失去”；切英文后含 `S LOST`。
- [ ] 跑 `stage4_bilingual`，期望 PASS、无 SCRIPT ERROR。

### Task 3：双解 10 → 16–18

**文件：**
- 修改 `scripts/systems/level_data.gd`（8 个 spec 加 `"dual": true`）
- 修改 `scripts/test/stage35_combo_audit.gd`（`dual_names`、`dual_total_10`、`dual_count`）
- 修改 `docs/PRODUCER_QA_GUIDE.md`

**步骤：**

- [ ] 给 `bird3`、`bird7`、`bird8`、`beam3`、`beam8`、`rock5`、`rock7`、`rock11` 加 `"dual": true`。
- [ ] `stage35` 的 `dual_names` 追加实际保留的名字；`dual_total_10` 改为 `dual_total_16_18`，断言 `dual_total >= 16 and dual_total <= 18`；`dual_count` 断言 `>= 16`。
- [ ] 跑 `stage35_combo_audit`；每一组双解的 2 条路线必须全过。
- [ ] 任何一组失败：去掉它的 `dual`，换候补 `bird9`/`beam7`/`rock9`/`rock12`，直到 16–18 组且全过。
- [ ] 更新 `PRODUCER_QA_GUIDE.md` 的双解清单和数量。

### Task 4：换人时机奖励

**文件：**
- 修改 `scripts/race.gd`（`next_hazard_info`、`_on_shift_take`、新增 `_evaluate_swap_timing` / `_role_solves`）
- 新建 `scripts/test/stage44_swap_timing.gd` + `scenes/stage44_swap_timing.tscn`
- `locale.gd` 已加 `feedback.good_swap`

**代码：**

```gdscript
# race.gd 常量
const SWAP_GOOD_MIN := 0.30
const SWAP_GOOD_MAX := 0.70
const SWAP_GOOD_SCORE := 50

var _last_swap_reward_group := ""

# _reset_run / load_level 里同时清零：
# _last_swap_reward_group = ""

# next_hazard_info 的返回字典追加
"zone": int(group["zone"]),
"dual": bool(group.get("dual", false)),

# _on_shift_take 的普通换手分支
_start_relay(from, to)
_evaluate_swap_timing(to)

func _role_solves(kind: String, who: String, dual: bool) -> bool:
	match kind:
		"LOW_BIRD", "LOW_BEAM", "SURFACE_ROCK":
			return who == "rabbit" or (dual and who == "turtle")
		"DIVE_GATE":
			return who == "turtle"
		_:
			return false

func _evaluate_swap_timing(to: String) -> void:
	var next := next_hazard_info()
	if next.is_empty():
		return
	var kind := String(next["kind"])
	if kind in ["FLOATING_LOG", "HIGH_WALL", "SHARK"]:
		return
	var gname := String(next["group"])
	if gname == _last_swap_reward_group:
		return
	var zone := int(next.get("zone", 1))
	var speed := 240.0
	for z in LevelDataScript.ZONES:
		if int(z["id"]) == zone:
			speed = float(z["base_speed"])
			break
	var t := float(next["distance"]) / maxf(speed, 1.0)
	if t < SWAP_GOOD_MIN or t > SWAP_GOOD_MAX:
		return
	if not _role_solves(kind, to, bool(next.get("dual", false))):
		return
	_last_swap_reward_group = gname
	GameManager.add_score(SWAP_GOOD_SCORE, "swap:" + kind)
	GameManager.feedback.emit(Locale.t("feedback.good_swap"), "clean")
```

- [ ] 测试脚本 `stage44_swap_timing.gd`：

```gdscript
extends Node
var is_runner := false
var race
var failures: Array[String] = []

func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()

func _run() -> void:
	GameManager.test_no_best = true
	GameManager.start_race()
	for i in 5:
		await get_tree().process_frame
	race = get_tree().current_scene
	race.set_physics_process(false)
	race.opening_active = false
	race.test_disable_hazards = true
	race.load_level(LevelDataScript.groups(), [])
	_case("rock2", "turtle", 0.55, true)   # 非双解：换到兔子，正确
	_case("rock2", "turtle", 0.15, false)  # 太晚
	_case("rock2", "turtle", 1.20, false)  # 太早
	_case("rock2", "rabbit", 0.55, false)  # 换错角色
	_case("rock3", "rabbit", 0.55, true)   # 双解：换到乌龟，也正确
	print("STAGE44 SWAP TIMING: " + ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)

func _case(gname: String, from_who: String, t: float, expect: bool) -> void:
	var g: Dictionary = {}
	for item in race.hazard_groups:
		if String(item["group"]) == gname:
			g = item
			break
	if g.is_empty():
		_check(false, "group missing " + gname)
		return
	var zone := int(g["zone"])
	var speed := 220.0
	for z in LevelDataScript.ZONES:
		if int(z["id"]) == zone:
			speed = float(z["base_speed"])
			break
	race.turtle.position.x = race._group_start(g) - t * speed
	GameManager.current_control = from_who
	GameManager.accident_state = "NONE"
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.shift_lock_t = 0.0
	GameManager.total_score = 0
	race._last_swap_reward_group = ""
	GameManager.toggle_control()
	var got := GameManager.total_score == 50
	_check(got == expect, "%s %s t=%.2f expect=%s got=%d"
		% [gname, from_who, t, str(expect), GameManager.total_score])

func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
		print("  FAIL " + msg)
	else:
		print("  ok   " + msg)
```

- [ ] 跑 `stage44_swap_timing`，期望 PASS。
- [ ] 全关日志里至少出现一次 `swap:` 计分；不出现同一组连续刷分。

### Task 5：全关回归、调参、报告

- [ ] 跑 `stage3_playtest`：53/53、无卡死、事故 ≤6/圈、氧气失败 ≤1/圈。
- [ ] 跑 `stage3_selftest`、`stage35_combo_audit`、`stage4_bilingual`、`stage15_mischief`、`stage15_fail_flow`、`stage10_joint_semantics`、`stage32_shark_timing`、`stage21_shark_pack`、`stage42_shark_fairness`、`stage19_bird_behavior`、`stage13_catch_matrix`、`stage31_arena`。
- [ ] 如果事故 >6/圈：先把严重事故扣氧从 0.8 降到 0.6，再跑；不要动恢复锁。
- [ ] 如果氧气失败 >1/圈：把最低保留从 0.6 降到 0.5，或把严重事故扣氧降到 0.6。
- [ ] 更新 `PRODUCER_QA_GUIDE.md` 和 `docs/reports/longrun/MECHANICS-8.md`，写清实测数。
- [ ] 按 qc.py 逐条 mark，附证据；FAIL/NOT_VERIFIED 不得写“已完成”。
- [ ] 提交，确认工作树干净、`best.json` MD5 不变。

## 5. 验收标准（机制 8 分的六条）

1. 双解 ≥16 组，每组 rabbit/turtle 两条路线都 PASS。
2. 严重事故后 2 秒内氧气下降 ≥0.8，且 2 秒内不回氧；一次撞击不会直接清空氧气。
3. 跑图 HUD 始终显示 S 进度；第一次失误切为 S LOST；中英文正确。
4. 威胁前 0.30–0.70 秒换到正确角色记录 GOOD SWAP +50；换晚/换错不奖励。
5. 全关 53/53、无卡死、自动跑事故 ≤6/圈、氧气失败 ≤1/圈。
6. 一局内至少 3 次 combo/双解高峰；S 目标在跑图中可见。**这条是设计自评，不是真人试玩结论；真人趣味性仍标 NOT_VERIFIED。**

六条全过：机制自评 **8.0**；有一条不过：按实际写 7.x，不硬报 8。

## 6. 风险与回滚

| 风险 | 处理 |
|---|---|
| 扣氧让 Z3 过难 | 先降扣氧到 0.6；保留最低 0.6；氧气失败 >1/圈就回滚 |
| 双解是假选择 | `stage35` 两条路线不过就不标；宁可 16 组，不凑 18 |
| 换人奖励鼓励乱换 | 同组只奖励一次；只对简单组；先不加惩罚 |
| HUD 变回仪表盘 | 只加一行 S，不恢复 0/3 面板 |
| 没有真人试玩 | 每步留自动证据；最终 8 分标“工程自评”，不冒充真人结论 |

每个 Task 一个提交；任何一步让 `stage3_playtest` 失败，先回滚该 Task，不带着红灯往下做。

## 7. 不做

- 不加新敌人、新障碍种类、新按键、新角色技能、新环境系统；
- 不做幽灵回放、练习模式、色盲专项；
- 不做美术、音频、导出、打包、部署；
- 不改 `best.json`。

## 8. 需要制作人确认的三个参数

1. 事故扣氧：**0.8 / 最低 0.6 / 锁 2 秒**（保守可改 0.6）。
2. 双解目标：**18 组**（保底 16）。
3. 换人奖励：**窗口 0.30–0.70 秒，+50 分，只奖励不惩罚**（是否要加换晚惩罚，等第一轮数据）。
