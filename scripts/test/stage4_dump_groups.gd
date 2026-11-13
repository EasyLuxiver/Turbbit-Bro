extends Node
## 只读导出：把 GROUPS 的（组名 / 区 / 种类 / 起点 x / 终点 x）写成 JSON，
## 给 Phase J 的离线节奏分析用。不改游戏状态。
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT res://scenes/stage4_dump_groups.tscn

func _ready() -> void:
	var level := preload("res://scripts/systems/level_data.gd")
	var out := []
	for g in level.GROUPS:
		out.append({
			"group": g["group"],
			"zone": g["zone"],
			"kind": g["kind"],
			"start": float(g["x"]),
			"end": float(g["x"]) + float(g["w"]),
		})
	var zones := []
	for z in level.ZONES:
		zones.append({"id": z["id"], "start": z["start"], "end": z["end"],
			"base_speed": z["base_speed"]})
	var path := ProjectSettings.globalize_path("res://docs/reports/logs/phase-j/groups.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"zones": zones, "groups": out}, "  "))
	f.close()
	print("DUMP GROUPS: %d -> %s" % [out.size(), path])
	get_tree().quit(0)
