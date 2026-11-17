extends SceneTree


func _init() -> void:
	var groups: Array = LevelData.GROUPS
	print("TOTAL=", groups.size())
	var by_kind := {}
	var by_zone := {}
	var dynamic := 0
	for g in groups:
		by_kind[g["kind"]] = int(by_kind.get(g["kind"], 0)) + 1
		by_zone[g["zone"]] = int(by_zone.get(g["zone"], 0)) + 1
		if g.has("motion"):
			dynamic += 1
	print("KINDS=", by_kind)
	print("ZONES=", by_zone)
	print("DYNAMIC=", dynamic)
	quit()
