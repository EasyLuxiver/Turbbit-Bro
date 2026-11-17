extends Node
## TBB-CORE-FEEL-09 P0-B — 9 个动态障碍（tide_rock）身份与运动来源对照。
##
## 判的是“换身份不换物理”：
##   1) 9 个实例全部存在；
##   2) 每个实例的 x / w / 判定矩形 / motion 参数与本轮冻结基线完全一致；
##   3) 每个实例都有身份、运动来源、可见运动解释与碰撞说明；
##   4) 没有任何一个为了“更好看”缩小碰撞框。
##
## 基线取自 FEEL-08 的 9 块清单（x/w 与 motion 都是当时值，本轮只改画法）。
##
## 输出：docs/reports/longrun/core-feel-09-p0b-dynamic-rocks.json

const LevelDataScript = preload("res://scripts/systems/level_data.gd")
const OUT_PATH := "res://docs/reports/longrun/core-feel-09-p0b-dynamic-rocks.json"

## FEEL-08 基线：id / x / w / identity / motion。
const BASELINE := [
	{"id": "rock3", "x": 8400.0, "w": 120.0, "identity": "buoy",
		"motion": {"name": "tide_rock", "axis": "y", "amp": 52.0, "period": 3.6}},
	{"id": "rock4", "x": 17770.0, "w": 120.0, "identity": "dock_crate",
		"motion": {"name": "tide_rock", "axis": "y", "amp": 52.0, "period": 3.6}},
	{"id": "rock5", "x": 23200.0, "w": 130.0, "identity": "dock_crate",
		"motion": {"name": "tide_rock", "axis": "y", "amp": 52.0, "period": 3.6}},
	{"id": "rock7", "x": 31800.0, "w": 120.0, "identity": "dock_crate",
		"motion": {"name": "tide_rock", "axis": "y", "amp": 52.0, "period": 3.6}},
	{"id": "rock8", "x": 41450.0, "w": 130.0, "identity": "drift_crate",
		"motion": {"name": "tide_rock", "axis": "y", "amp": 52.0, "period": 3.6}},
	{"id": "rock9", "x": 48610.0, "w": 140.0, "identity": "drift_crate",
		"motion": {"name": "tide_rock", "axis": "y", "amp": 52.0, "period": 3.6}},
	{"id": "rock10", "x": 56180.0, "w": 120.0, "identity": "drift_crate",
		"motion": {"name": "tide_rock", "axis": "y", "amp": 52.0, "period": 3.6}},
	{"id": "rock11", "x": 61940.0, "w": 150.0, "identity": "drift_crate",
		"motion": {"name": "tide_rock", "axis": "y", "amp": 52.0, "period": 3.6}},
	{"id": "rock12", "x": 66720.0, "w": 120.0, "identity": "drift_crate",
		"motion": {"name": "tide_rock", "axis": "y", "amp": 52.0, "period": 3.6}},
]

const SOURCE := {
	"buoy": "锚绳拴在海底，浮标随涌浪起落；画面上绳子和浪峰一起动",
	"dock_crate": "吊索挂在屋顶/吊臂上，货箱随吊点升降；画面上吊索与滑轮可见",
	"drift_crate": "从码头冲出的货箱，随水渠/大浪浮沉；画面上浪峰与水花可见",
}
const VISUAL := {
	"buoy": "红白桶身 + 顶灯 + 锚绳；浪峰时底部画浪鼓，浪谷时水线没过桶身",
	"dock_crate": "木箱 + 两根吊索汇聚到滑轮；箱体升降时吊索长度同步变化",
	"drift_crate": "半沉木箱 + 浪鼓 + 两侧水花；浪谷时箱体几乎贴水线",
}
const COLLISION := {
	"buoy": "同一矩形（含反下潜段）随浪整体上下；没有缩框",
	"dock_crate": "同一矩形（含反下潜段）随吊点上下；没有缩框",
	"drift_crate": "同一矩形（含反下潜段）随浪上下；没有缩框",
}

var checks: Array = []


func _ready() -> void:
	var by_id := {}
	for g in LevelDataScript.groups():
		by_id[String(g["group"])] = g
	var rows := []
	for b in BASELINE:
		var g: Dictionary = by_id.get(String(b["id"]), {})
		if g.is_empty():
			rows.append({"id": b["id"], "missing": true})
			continue
		var rects := []
		for r in g["rects"]:
			var rect: Rect2 = r
			rects.append([rect.position.x, rect.position.y, rect.size.x, rect.size.y])
		var motion: Dictionary = g.get("motion", {})
		var identity := String(g["identity"])
		var row := {
			"obstacle_id": String(b["id"]),
			"zone": int(LevelDataScript.zone_at(float(b["x"]))["id"]),
			"old_identity": "sea_rock (FEEL-08 前)",
			"new_identity": identity,
			"motion_source": String(SOURCE.get(identity, "")),
			"visual_behavior": String(VISUAL.get(identity, "")),
			"collision": String(COLLISION.get(identity, "")),
			"x_now": float(g["rects"][0].position.x),
			"x_baseline": float(b["x"]),
			"w_now": float(g["rects"][0].size.x),
			"w_baseline": float(b["w"]),
			"motion_now": motion,
			"motion_baseline": b["motion"],
			"rects_now": rects,
			"physics_identical": _same_physics(g, b),
		}
		rows.append(row)
	var missing := []
	var drifted := []
	var no_source := []
	for r in rows:
		if bool(r.get("missing", false)):
			missing.append(r["id"])
			continue
		if not bool(r["physics_identical"]):
			drifted.append(r["id"])
		if String(r["motion_source"]) == "":
			no_source.append(r["id"])
	_check("nine_present", missing.is_empty(),
		"9 个动态障碍全部存在%s" % ("" if missing.is_empty() else "，缺：" + str(missing)))
	_check("physics_identical", drifted.is_empty(),
		"x/w/判定矩形/motion 与基线一致%s" % ("" if drifted.is_empty()
			else "，变了：" + str(drifted)))
	_check("motion_source", no_source.is_empty(),
		"9/9 有运动来源%s" % ("" if no_source.is_empty() else "，缺：" + str(no_source)))
	var data := {
		"task": "TBB-CORE-FEEL-09 P0-B",
		"generated_at": Time.get_datetime_string_from_system(),
		"count": rows.size(),
		"rows": rows,
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
	print("P0B DYNAMIC ROCKS: %d/%d checks pass" % [checks.size() - failed, checks.size()])
	print("P0B RESULT: ", "PASS" if failed == 0 else "FAIL")
	get_tree().quit(0 if failed == 0 else 1)


func _same_physics(g: Dictionary, b: Dictionary) -> bool:
	if not is_equal_approx(float(g["rects"][0].position.x), float(b["x"])):
		return false
	if not is_equal_approx(float(g["rects"][0].size.x), float(b["w"])):
		return false
	var m: Dictionary = g.get("motion", {})
	var bm: Dictionary = b["motion"]
	if String(m.get("name", "")) != String(bm["name"]):
		return false
	if not is_equal_approx(float(m.get("amp", 0.0)), float(bm["amp"])):
		return false
	if not is_equal_approx(float(m.get("period", 0.0)), float(bm["period"])):
		return false
	if String(m.get("axis", "y")) != String(bm["axis"]):
		return false
	# 判定矩形必须是模板的两段：主带 220/42 + 反下潜段 368/50。
	var r0: Rect2 = g["rects"][0]
	var r1: Rect2 = g["rects"][1]
	if not is_equal_approx(r0.position.y, 220.0) or not is_equal_approx(r0.size.y, 42.0):
		return false
	if not is_equal_approx(r1.position.y, 368.0) or not is_equal_approx(r1.size.y, 50.0):
		return false
	if not is_equal_approx(r1.position.x, float(b["x"])) \
			or not is_equal_approx(r1.size.x, float(b["w"])):
		return false
	return true


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})


func _write_json(path: String, data: Dictionary) -> void:
	var abs := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + path)
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()
