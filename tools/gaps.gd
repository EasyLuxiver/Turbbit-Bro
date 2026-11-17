extends SceneTree


func _init() -> void:
	var groups := LevelData.groups()
	for i in range(1, groups.size()):
		var prev: Dictionary = groups[i - 1]
		var g: Dictionary = groups[i]
		var zone := LevelData.zone_at(LevelData.group_start(g))
		var speed := float(zone["base_speed"])
		var gap := (LevelData.group_start(g) - LevelData.group_end(prev)) / speed
		if gap > 5.5:
			print("%s(%s) -> %s(%s) gap=%.2fs x=%.0f->%.0f" % [
				prev["group"], prev["kind"], g["group"], g["kind"], gap,
				LevelData.group_start(prev), LevelData.group_start(g)])
	quit()
