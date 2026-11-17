extends Node
## TBB-CORE-FEEL-09 P0-A — 运行时 Z2 身份核对（headless，真实 race.gd）。
##
## 为什么不用静态 GROUPS 表：9 个“食物锚点”组会按种子重抽 kind
## （LevelData.plan_snack_draws），所以 gate3 不一定是 DIVE_GATE。
## 本探针加载真实比赛场景，读的是这一局实际生成的 hazard_groups。
##
## 判的是：
##   1) 55 组完整；
##   2) Producer 点名的 8 个 Z2 组存在，且运行时身份属于室内码头集合；
##   3) Z2 没有任何海底/珊瑚礁身份（海鸥/鲨鱼/礁拱/礁石）；
##   4) Z2 的 19 组身份白名单（吊网/鳗鱼/船闸/浮台/木梁/吊箱/浮木/高墙）。
##
## 输出：docs/reports/longrun/core-feel-09-p0a-runtime-identities.json

const OUT_PATH := "res://docs/reports/longrun/core-feel-09-p0a-runtime-identities.json"
const LevelDataScript = preload("res://scripts/systems/level_data.gd")

## Producer 点名的 8 个错位组（按位置，不按 kind——kind 会被种子重抽）。
const NAMED := ["bird3", "bird4", "bird5", "shark3", "shark5",
	"gate3", "gate4", "gate5"]
const DOCK_IDENTITIES := ["cargo_net", "canal_eel", "sluice_gate",
	"mooring_pontoon", "dock_beam", "dock_crate", "drift_log", "high_wall",
	"dock_wall"]
const CORAL_IDENTITIES := ["diving_gull", "reef_shark", "reef_arch", "sea_rock"]

var is_runner := false
var checks: Array = []


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
	Locale.set_language("zh")
	GameManager.start_race()
	for i in 10:
		await get_tree().process_frame
	var race: Node = get_tree().current_scene
	if race == null or not ("hazard_groups" in race):
		push_error("P0-A runtime: no race scene")
		_finish(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	var rows := []
	var z2 := []
	for g in race.hazard_groups:
		var start := float(race._group_start(g))
		var zone := int(LevelDataScriptZone(start))
		var row := {
			"obstacle_id": String(g["group"]), "zone": zone,
			"kind": String(g["kind"]), "identity": String(g.get("identity", "")),
			"x": start,
		}
		rows.append(row)
		if zone == 2:
			z2.append(row)
	_check("group_count", rows.size() == 55, "%d/55 组" % rows.size())
	var by_id := {}
	for r in rows:
		by_id[String(r["obstacle_id"])] = r
	var missing := []
	var bad_named := []
	for id in NAMED:
		if not by_id.has(id):
			missing.append(id)
			continue
		var identity := String(by_id[id]["identity"])
		if not DOCK_IDENTITIES.has(identity):
			bad_named.append("%s:%s" % [id, identity])
	_check("named_8_present", missing.is_empty(),
		"点名的 8 组都存在%s" % ("" if missing.is_empty() else "，缺：" + str(missing)))
	_check("named_8_dock_identity", bad_named.is_empty(),
		"点名的 8 组运行时身份都在码头集合内%s" % ("" if bad_named.is_empty()
			else "，不符：" + str(bad_named)))
	var coral := []
	for r in z2:
		if CORAL_IDENTITIES.has(String(r["identity"])):
			coral.append("%s:%s" % [r["obstacle_id"], r["identity"]])
	_check("z2_no_coral", coral.is_empty(),
		"Z2 无海底/珊瑚礁身份%s" % ("" if coral.is_empty() else "，残留：" + str(coral)))
	var unknown := []
	for r in z2:
		if not DOCK_IDENTITIES.has(String(r["identity"])):
			unknown.append("%s:%s" % [r["obstacle_id"], r["identity"]])
	_check("z2_identity_whitelist", unknown.is_empty(),
		"Z2 的 %d 组身份都在码头白名单内%s" % [z2.size(),
			"" if unknown.is_empty() else "，越界：" + str(unknown)])
	_check("z2_count", z2.size() == 19, "Z2 运行时有 %d 组" % z2.size())

	var data := {
		"task": "TBB-CORE-FEEL-09 P0-A",
		"generated_at": Time.get_datetime_string_from_system(),
		"level_seed": int(race.level_seed),
		"group_count": rows.size(),
		"z2_count": z2.size(),
		"named": NAMED,
		"rows": rows,
		"z2_rows": z2,
		"checks": checks,
	}
	_write_json(OUT_PATH, data)
	var failed := 0
	for c in checks:
		if not bool(c["ok"]):
			failed += 1
			print("FAIL  %s  %s" % [c["name"], c["detail"]])
		else:
			print("ok    %s  %s" % [c["name"], c["detail"]])
	print("P0A RUNTIME IDENTITIES: %d/%d checks pass (seed %d)" % [
		checks.size() - failed, checks.size(), int(race.level_seed)])
	print("P0A RESULT: ", "PASS" if failed == 0 else "FAIL")
	_finish(0 if failed == 0 else 1)


func LevelDataScriptZone(x: float) -> int:
	return int(LevelDataScript.zone_at(x)["id"])


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})


func _finish(code: int) -> void:
	get_tree().quit(code)


func _write_json(path: String, data: Dictionary) -> void:
	var abs := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + path)
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()
