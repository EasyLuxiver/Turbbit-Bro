extends Node
## CORE-FEEL-08 P1-C 探针：障碍物身份清单与区域归属完整性。
##
## 只读关卡数据，不跑比赛、不改任何状态。输出一份机器可读的清单
## （obstacle_id / identity / category / region / motion_source / interaction /
## player_counterplay），报告里的表就是这份 JSON 的转写。
##
## 为什么要有这个探针：P1-C 的要求不是“把石头画好看”，而是**每一条障碍物
## 都能回答它是什么、为什么在这里、为什么这样动**。这四条里能自动判的
## （身份非空、身份与区域匹配、会动的有运动来源、静止的不动、提示文案存在）
## 全部落在这里；不能自动判的（画得像不像）用截图 + 人眼。

const LevelDataScript = preload("res://scripts/systems/level_data.gd")
const OUT_PATH := "res://docs/reports/longrun/core-feel-09-p1c-obstacle-inventory.json"

## 和 race.gd 的 _category_of 同表。探针不加载 race 场景，所以这里复写一份；
## 两边走散时由 stage8_baseline 的类别断言兜底。
const CATEGORY := {
	"LOW_BIRD": "A/RABBIT-CROUCH",
	"LOW_BEAM": "A/RABBIT-CROUCH",
	"SURFACE_ROCK": "A/RABBIT-JUMP",
	"FLOATING_LOG": "B/COMBINED",
	"SHARK": "C/TURTLE-LEAP",
	"DIVE_GATE": "D/TURTLE-DIVE",
	"HIGH_WALL": "B/COMBINED",
}

## 玩家对策：一句话写清“玩家做什么”。和 interaction（提示条上的动作）分开记，
## 因为高墙/浮木的 interaction 是连招，counterplay 才是完整答案。
const COUNTERPLAY := {
	"LOW_BIRD": "蹲低（兔子）或下潜（乌龟）从俯冲空域下方过",
	"LOW_BEAM": "蹲低从梁下过；梁柱扎在海底，链上看得出高低",
	"SHARK": "跃起（乌龟）从鲨鱼上方过",
	"DIVE_GATE": "按住下潜（乌龟）穿过礁拱",
	"FLOATING_LOG": "跳跃→换手→下潜的连招",
	"HIGH_WALL": "跃起→换手→踢墙的连招",
	"SURFACE_ROCK": "跳跃越过去；乌龟巡航从岩下过",
}

## 身份专属对策：同样是 SURFACE_ROCK，浮标/吊箱/漂流货箱的“什么时候跳”不一样。
const COUNTERPLAY_BY_IDENTITY := {
	"buoy": "跳跃越过去；系泊浮标随涌浪起落，等它落到低点再跳",
	"dock_crate": "跳跃越过去；吊装货箱随吊臂升降，看准它升起的那拍",
	"drift_crate": "跳跃越过去；漂流货箱随大浪浮沉，看准浪谷再跳",
	"cargo_net": "趴低（兔子）或下潜（乌龟）从吊网下方过；网由屋顶绞盘放下",
	"canal_eel": "跃起（乌龟）从鳗鱼上方过；鳗鱼盘在水渠底，靠近时窜上来",
	"sluice_gate": "按住下潜（乌龟）从闸板下过；闸板吊在码头结构上",
	"mooring_pontoon": "跳跃越过去；系泊浮台，跳过去就行",
}

## 会动的障碍必须有“为什么动”。identity → 运动来源说明。
const MOTION_SOURCE_TEXT := {
	"buoy": "锚绳拴在海底，随涌浪上下",
	"dock_crate": "挂在码头吊钩上，随吊臂升降",
	"drift_crate": "被大浪推着浮沉，随浪谷起伏",
	"drift_log": "随浪涌整体起伏（swell_log）",
	"reef_shark": "巡游/伏击（ambush_shark），按距离状态机上下",
	"canal_eel": "盘在水渠底，按距离状态机预警并窜上水面（ambush_shark）",
}

## FEEL-09 P0-A：Z2 身份覆盖表。和 LevelData.IDENTITY_BY_KIND_ZONE 保持一致。
const IDENTITY_BY_KIND_ZONE := {
	2: {
		"LOW_BIRD": "cargo_net",
		"SHARK": "canal_eel",
		"DIVE_GATE": "sluice_gate",
		"SURFACE_ROCK": "mooring_pontoon",
	},
}

## Producer 点名的 8 个错位障碍：id → 期望身份。
const Z2_MISMATCH := {
	"bird3": "cargo_net", "bird4": "cargo_net", "bird5": "cargo_net",
	"shark3": "canal_eel", "shark5": "canal_eel",
	"gate3": "sluice_gate", "gate4": "sluice_gate", "gate5": "sluice_gate",
}

## 室内码头里不允许再出现的“海底/珊瑚礁”身份。
const CORAL_IDENTITIES := ["diving_gull", "reef_shark", "reef_arch", "sea_rock"]

## identity → 底栏运动提示的文案 key（浮木等没有专属 key 的走 hint.motion）。
const HINT_KEY := {
	"buoy": "hint.motion_buoy",
	"dock_crate": "hint.motion_hoist",
	"drift_crate": "hint.motion_cargo",
	"canal_eel": "hint.motion_eel",
}

const TIDE_IDENTITY_BY_ZONE := {
	1: "buoy",
	2: "dock_crate",
	3: "drift_crate",
}

var checks: Array = []


func _ready() -> void:
	var rows := _build_rows()
	_check_identity_complete(rows)
	_check_identity_by_kind(rows)
	_check_z2_identities(rows)
	_check_z2_no_coral(rows)
	_check_tide_identity_by_zone(rows)
	_check_motion_has_source(rows)
	_check_static_rocks_still(rows)
	_check_hint_text(rows)
	_check_category_known(rows)

	var failed := 0
	for c in checks:
		if not c["ok"]:
			failed += 1
			print("FAIL  %s  %s" % [c["name"], c["detail"]])
		else:
			print("ok    %s  %s" % [c["name"], c["detail"]])
	var data := {
		"task": "TBB-CORE-FEEL-08 P1-C",
		"generated_at": Time.get_datetime_string_from_system(),
		"group_count": rows.size(),
		"identity_count": _identities(rows).size(),
		"identities": _identities(rows),
		"rows": rows,
		"checks": checks,
		"failed": failed,
	}
	_write_json(OUT_PATH, data)
	print("P1C INVENTORY: %d groups, %d identities, %d/%d checks pass" % [
		rows.size(), _identities(rows).size(), checks.size() - failed, checks.size()])
	print("P1C RESULT: ", "PASS" if failed == 0 else "FAIL")
	get_tree().quit(0 if failed == 0 else 1)


func _build_rows() -> Array:
	var rows := []
	for g in LevelDataScript.groups():
		var zone := LevelDataScript.zone_at(LevelDataScript.group_start(g))
		var motion: Dictionary = g.get("motion", {})
		var kind := String(g["kind"])
		var identity := String(g["identity"])
		var motion_name := String(motion.get("name", ""))
		var motion_source := "静止"
		if motion_name != "":
			motion_source = String(MOTION_SOURCE_TEXT.get(identity,
				"运动名：" + motion_name))
		rows.append({
			"obstacle_id": String(g["group"]),
			"kind": kind,
			"identity": identity,
			"category": String(CATEGORY.get(kind, "?")),
			"region": "Z%d %s" % [int(zone["id"]), String(zone["name"])],
			"zone": int(zone["id"]),
			"x": LevelDataScript.group_start(g),
			"motion_source": motion_source,
			"motion": motion_name,
			"interaction": String(g["action"]),
			"player_counterplay": String(COUNTERPLAY_BY_IDENTITY.get(identity,
				COUNTERPLAY.get(kind, ""))),
			"hint": String(g["hint"]),
		})
	return rows


func _identities(rows: Array) -> Array:
	var out := []
	for r in rows:
		if not out.has(r["identity"]):
			out.append(r["identity"])
	out.sort()
	return out


func _add(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})


func _check_identity_complete(rows: Array) -> void:
	var missing := []
	for r in rows:
		if String(r["identity"]) == "":
			missing.append(r["obstacle_id"])
	_add("identity_complete", missing.is_empty(),
		"%d/%d 条障碍有身份%s" % [rows.size() - missing.size(), rows.size(),
			"" if missing.is_empty() else "，缺：" + str(missing)])


func _check_identity_by_kind(rows: Array) -> void:
	var bad := []
	var checked := 0
	for r in rows:
		var kind := String(r["kind"])
		if kind == "SURFACE_ROCK":
			continue
		checked += 1
		var zone_table: Dictionary = IDENTITY_BY_KIND_ZONE.get(int(r["zone"]), {})
		var want := String(zone_table.get(kind,
			LevelDataScript.IDENTITY_BY_KIND.get(kind, kind)))
		if String(r["identity"]) != want:
			bad.append("%s:%s!=%s" % [r["obstacle_id"], r["identity"], want])
	_add("identity_by_kind", bad.is_empty(),
		"%d 条非岩障碍身份与“本区域默认表”一致%s" % [checked, "" if bad.is_empty()
			else "，不一致：" + str(bad)])


## FEEL-09 P0-A：Producer 点名的 8 个 Z2 错位障碍 8/8 对齐。
func _check_z2_identities(rows: Array) -> void:
	var by_id := {}
	for r in rows:
		by_id[String(r["obstacle_id"])] = r
	var bad := []
	for id in Z2_MISMATCH.keys():
		if not by_id.has(id):
			bad.append("%s:缺" % id)
			continue
		var want := String(Z2_MISMATCH[id])
		var got := String(by_id[id]["identity"])
		if got != want:
			bad.append("%s:%s!=%s" % [id, got, want])
	_add("z2_mismatch_8of8", bad.is_empty(),
		"Z2 点名障碍 %d/%d 已换身份%s" % [Z2_MISMATCH.size() - bad.size(),
			Z2_MISMATCH.size(), "" if bad.is_empty() else "，不符：" + str(bad)])


## FEEL-09 P0-A：Z2 不允许残留海底/珊瑚礁身份。
func _check_z2_no_coral(rows: Array) -> void:
	var bad := []
	for r in rows:
		if int(r["zone"]) != 2:
			continue
		if CORAL_IDENTITIES.has(String(r["identity"])):
			bad.append("%s:%s" % [r["obstacle_id"], r["identity"]])
	_add("z2_no_coral", bad.is_empty(),
		"Z2 无海底/珊瑚礁身份%s" % ("" if bad.is_empty() else "，残留：" + str(bad)))


func _check_tide_identity_by_zone(rows: Array) -> void:
	var bad := []
	var seen := 0
	for r in rows:
		if String(r["motion"]) != "tide_rock":
			continue
		seen += 1
		var want := String(TIDE_IDENTITY_BY_ZONE.get(int(r["zone"]), "?"))
		if String(r["identity"]) != want:
			bad.append("%s(z%d):%s!=%s" % [r["obstacle_id"], int(r["zone"]),
				r["identity"], want])
	_add("tide_identity_by_zone", bad.is_empty() and seen > 0,
		"%d 块潮汐岩按区域换成浮标/吊装货箱/漂流货箱%s" % [seen,
			"" if bad.is_empty() else "，不符：" + str(bad)])


func _check_motion_has_source(rows: Array) -> void:
	var bad := []
	var moving := 0
	for r in rows:
		if String(r["motion"]) == "":
			continue
		moving += 1
		if String(r["motion_source"]) == "静止" or String(r["motion_source"]) == "":
			bad.append(r["obstacle_id"])
	_add("motion_has_source", bad.is_empty(),
		"%d 条动态障碍都有运动来源%s" % [moving,
			"" if bad.is_empty() else "，缺：" + str(bad)])


func _check_static_rocks_still(rows: Array) -> void:
	var bad := []
	for r in rows:
		if String(r["identity"]) == "sea_rock" and String(r["motion"]) != "":
			bad.append(r["obstacle_id"])
	_add("static_rocks_still", bad.is_empty(),
		"静止礁石没有运动%s" % ("" if bad.is_empty() else "，动了：" + str(bad)))


func _check_hint_text(rows: Array) -> void:
	var keys := []
	for r in rows:
		if String(r["motion"]) == "":
			continue
		var id := String(r["identity"])
		var key := String(HINT_KEY.get(id, "hint.motion"))
		if not keys.has(key):
			keys.append(key)
	var bad := []
	var old_lang: String = Locale.language
	for lang in ["zh", "en"]:
		Locale.set_language(lang)
		for key in keys:
			var text := Locale.t(key)
			if text == key or text.strip_edges() == "":
				bad.append("%s@%s" % [key, lang])
	Locale.set_language(old_lang)
	_add("motion_hint_text", bad.is_empty(),
		"运动提示 %s 中英都有文案%s" % [str(keys),
			"" if bad.is_empty() else "，缺：" + str(bad)])


func _check_category_known(rows: Array) -> void:
	var bad := []
	for r in rows:
		if String(r["category"]) == "?":
			bad.append(r["obstacle_id"])
	_add("category_known", bad.is_empty(),
		"每条障碍都有 A/B/C/D 类别%s" % ("" if bad.is_empty() else "，缺：" + str(bad)))


func _write_json(path: String, data: Dictionary) -> void:
	var abs := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + path)
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()
