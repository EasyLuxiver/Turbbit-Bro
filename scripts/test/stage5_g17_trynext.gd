extends Node
## REBUILD-05 G17：结算页「下次试试」——只读本局计数，给一条下次可做的动作。
##
## 问题（玩家视角）：结算页只有数字。一个从没打出过连招的新人，看完 7 行数字
## 也不知道自己漏了什么、下一局该试什么；CLAUDE.md 的有趣性检查第 4 条
## “比上一局多一个想再试一次的理由”，结算页此前一条都没给。
##
## 做法：`GameManager.next_try_key()` 是纯函数，按优先级返回一条 locale key：
##   没打出过连招 → BRO DIVE；有连招但没亲手喂到 → 喂海藻；
##   都做到过、但有事故且没救回 → SHIFT 追接；都不缺 → 空串（整行不显示）。
## 结算页只把它显示出来，不改任何计分或状态。
##
## 运行：godot --headless --path TURBBIT res://scenes/stage5_g17_trynext.tscn
## 输出：docs/reports/longrun/rebuild05-g17-trynext.json

const OUT_PATH := "res://docs/reports/longrun/rebuild05-g17-trynext.json"
const RESULT_SCENE := "res://scenes/result.tscn"

var is_runner := false
var failures: Array = []
var rows: Array = []


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
	var res: Node = load(RESULT_SCENE).instantiate()
	add_child(res)
	await get_tree().process_frame
	await get_tree().process_frame
	if res == null or not is_instance_valid(res):
		push_error("G17: result scene not instantiated")
		_finish(1)
		return

	# 1) 纯函数：五种输入 → 期望的 key（含“三条都不满足 → 空串”）。
	var cases := [
		{"name": "no_combo", "combos": 0, "ollie": 0, "snacks": 0,
			"acc": 0, "rescues": 0, "want": "result.try_combo", "visible": true},
		{"name": "combo_no_snack", "combos": 4, "ollie": 1, "snacks": 0,
			"acc": 0, "rescues": 0, "want": "result.try_snack", "visible": true},
		{"name": "missed_rescue", "combos": 5, "ollie": 1, "snacks": 3,
			"acc": 2, "rescues": 0, "want": "result.try_rescue", "visible": true},
		{"name": "clean_run", "combos": 5, "ollie": 1, "snacks": 3,
			"acc": 0, "rescues": 0, "want": "", "visible": false},
		{"name": "did_rescue", "combos": 5, "ollie": 1, "snacks": 3,
			"acc": 1, "rescues": 1, "want": "", "visible": false},
	]
	# 3) 只读：每次判定与 _refresh 都不得改动本局计数或得分。
	# 快照放在“本 case 输入设置完”之后：设置输入是测试自己的事，不是被测对象。
	var before := {}
	for c in cases:
		GameManager.combo_dive_count = int(c["combos"])
		GameManager.combo_ollie_count = int(c["ollie"])
		GameManager.snack_switch_count = int(c["snacks"])
		GameManager.accident_count = int(c["acc"])
		GameManager.rescue_success_count = int(c["rescues"])
		var snap := _snapshot()
		if before.is_empty():
			before = snap
		var key := GameManager.next_try_key()
		res._refresh()
		await get_tree().process_frame
		var visible: bool = res._try_label != null and res._try_label.visible
		var text := "" if res._try_label == null else String(res._try_label.text)
		var want_text := "" if String(c["want"]) == "" else Locale.t(String(c["want"]))
		var ok := key == String(c["want"]) and visible == bool(c["visible"]) \
			and text == want_text
		if not ok:
			failures.append("%s: key='%s' want='%s' visible=%s text='%s'" % [
				String(c["name"]), key, String(c["want"]), str(visible), text])
		rows.append({
			"case": String(c["name"]),
			"key": key,
			"visible": visible,
			"text": text,
			"pass": ok,
		})
		var after_case := _snapshot()
		for k in snap:
			if snap[k] != after_case[k]:
				failures.append("%s: state mutated %s %s -> %s" % [
					String(c["name"]), k, str(snap[k]), str(after_case[k])])

	# 2) 只有一行「下次试试」：不能两条叠着出现。
	var found := 0
	for n in res.find_children("*", "", true, false):
		if String(n.name) == "TryNext":
			found += 1
	if found != 1:
		failures.append("expect exactly one TryNext label, got %d" % found)

	var after := _snapshot()

	_write(before, after, found)
	var ok_all := failures.is_empty()
	print("G17 TRYNEXT: %s checks=%d failures=%d" % [
		"PASS" if ok_all else "FAIL", rows.size() + 2, failures.size()])
	for f in failures:
		print("  - ", f)
	if res.is_inside_tree():
		res.queue_free()
	_finish(0 if ok_all else 1)


func _snapshot() -> Dictionary:
	return {
		"total_score": GameManager.total_score,
		"finish_time": GameManager.finish_time,
		"accident_count": GameManager.accident_count,
		"snack_switch_count": GameManager.snack_switch_count,
		"rescue_success_count": GameManager.rescue_success_count,
		"combo_dive_count": GameManager.combo_dive_count,
		"combo_ollie_count": GameManager.combo_ollie_count,
		"score_log_size": GameManager.score_log.size(),
		"grade": GameManager.grade,
	}


func _write(before: Dictionary, after: Dictionary, found: int) -> void:
	var data := {
		"generated_at": Time.get_datetime_string_from_system(false, true),
		"rows": rows,
		"trynext_label_count": found,
		"state_first_case": before,
		"state_last_case": after,
		"failures": failures,
	}
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
		f.close()


func _finish(code: int) -> void:
	get_tree().quit(code)
