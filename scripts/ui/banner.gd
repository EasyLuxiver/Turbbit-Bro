extends CanvasLayer
## 大字反馈（事故 / 接人 / Showtime）。小提示由 HUD 的预警条负责。

var label: Label
var timer := 0.0


func _ready() -> void:
	label = Label.new()
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_top = 40.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.text = ""

	GameManager.accident.connect(_on_accident)
	GameManager.pickup_success.connect(_on_pickup)
	GameManager.rescue_done.connect(_on_rescue)
	GameManager.center_message.connect(_on_center)


func _process(delta: float) -> void:
	if timer > 0.0:
		timer -= delta
		if timer <= 0.0:
			label.text = ""


func show_text(text: String, color: Color, seconds: float = 2.0) -> void:
	label.text = text
	label.add_theme_color_override("font_color", color)
	timer = seconds


func _on_center(text: String, color: Color) -> void:
	show_text(text, color, 1.8)


func _on_accident(reason: String) -> void:
	show_text(_accident_text(reason), Color(1.0, 0.45, 0.3))


func _on_pickup() -> void:
	show_text(Locale.t("banner.pickup"), Color(0.4, 1.0, 0.5))


func _on_rescue() -> void:
	show_text(Locale.t("banner.rescue"), Color(0.6, 0.9, 1.0))


func _accident_text(reason: String) -> String:
	var id: String = ACCIDENT_IDS.get(reason, "")
	return Locale.t(id) if id != "" else reason


const ACCIDENT_IDS := {
	"RABBIT_SLIP": "banner.slip",
	"RABBIT_WATER": "banner.water",
	"RABBIT_AIR": "banner.water",
	"RABBIT_STUN": "banner.stun",
	"RABBIT_HIT": "banner.hit",
	"TURTLE_REEF": "banner.reef",
	"OXYGEN_OUT": "banner.oxygen",
}
