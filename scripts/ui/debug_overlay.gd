extends CanvasLayer
## 阶段 2 调试面板（F1）：只读 GameManager 的真实状态，不自己保存副本。

var label: Label


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(360, 0)
	add_child(panel)

	label = Label.new()
	label.add_theme_font_size_override("font_size", 17)
	panel.add_child(label)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if label == null:
		return
	label.text = "\n".join([
		"STAGE 2 DEBUG  (F1)",
		"state:     %s" % GameManager.state_name(),
		"control:   %s" % GameManager.current_control.to_upper(),
		"rabbit:    %s  (%s)" % [GameManager.rabbit_state, GameManager.rabbit_phase],
		"turtle:    %s  (%s)" % [GameManager.turtle_state, GameManager.turtle_phase],
		"mount:     %s" % GameManager.mount_state,
		"slide:     %d%%" % int(round(GameManager.slide_progress * 100.0)),
		"pickup:    %s" % ("READY" if GameManager.pickup_window else "-"),
		"oxygen:    %.2f  (%s)" % [GameManager.oxygen, GameManager.oxygen_phase],
		"speed:     %.0f px/s" % GameManager.turtle_speed,
		"time:      %.2f s" % GameManager.race_time,
		"combo:     %d / best %d" % [GameManager.combo, GameManager.combo_max],
		"showtime:  %s  x%d" % [
			"ACTIVE" if GameManager.showtime_active else "READY" if GameManager.combo >= 3 else "-",
			GameManager.showtime_count],
		"shifts:    %d" % GameManager.shift_count,
		"pickups:   %d" % GameManager.pickup_count,
		"accidents: %d  (%s)" % [GameManager.accident_count, GameManager.accident_state],
	])
