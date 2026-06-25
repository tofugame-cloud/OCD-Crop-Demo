extends CanvasLayer

@onready var btn_office    = $LeftMenuContainer/VBoxContainer/BtnOffice
@onready var btn_mission   = $LeftMenuContainer/VBoxContainer/BtnMission
@onready var btn_burn_tape = $LeftMenuContainer/VBoxContainer/BtnBurnTape
@onready var btn_briefcase = $LeftMenuContainer/VBoxContainer/BtnBriefcase

var briefcase_scene = preload("res://scenes/ui/briefcase.tscn")
var briefcase_instance = null

func _ready():
	_build_ui()
	_connect_buttons()
	briefcase_instance = briefcase_scene.instantiate()
	add_child.call_deferred(briefcase_instance)

func _build_ui():
	var left = $LeftMenuContainer
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.custom_minimum_size = Vector2(220, 0)

	var buttons = {
		btn_office:    "🏢  OFFICE",
		btn_mission:   "📋  MISSION",
		btn_burn_tape: "🔥  BURN TAPE",
		btn_briefcase: "💼  BRIEFCASE",
	}
	for btn in buttons:
		btn.text = buttons[btn]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(200, 48)
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", Color(0.90, 0.75, 0.35, 1.0))

func _connect_buttons():
	btn_briefcase.pressed.connect(_on_briefcase)

func _on_briefcase():
	if briefcase_instance:
		briefcase_instance.open()
	else:
		await get_tree().process_frame
		if briefcase_instance:
			briefcase_instance.open()

# ── เรียกจากภายนอกเพื่อซ่อน/แสดง HUD ──
func hide_hud():
	$LeftMenuContainer.hide()

func show_hud():
	$LeftMenuContainer.show()
