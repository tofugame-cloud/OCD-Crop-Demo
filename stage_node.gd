# stage_node.gd
extends TextureButton

signal stage_clicked(stage_data: StageData)

@onready var label = get_node_or_null("RoomTypeLabel")

var associated_data: StageData

func setup(data: StageData):
	associated_data = data
	position = data.position
	
	if label:
		label.text = data.stage_name if data.stage_name != "" else data.stage_id
		label.z_index = 5
	
	disabled = false
	
	# ── เปลี่ยนมาเช็ค required_keys (Array) แทน required_key (String) ──
	var is_unlocked = true
	if not data.required_keys.is_empty():
		for key_id in data.required_keys:
			if not GameManager.has_key_tape(key_id):
				is_unlocked = false
				break
	
	if is_unlocked:
		modulate = Color.WHITE               # พร้อมเข้า
	else:
		modulate = Color(0.4, 0.4, 0.6, 0.8) # ล็อกอยู่

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not pressed.is_connected(_on_stage_pressed):
		pressed.connect(_on_stage_pressed)

func _on_stage_pressed():
	if associated_data:
		stage_clicked.emit(associated_data)
		print("📡 [STAGE NODE] ส่งสัญญาณเลือกด่าน: ", associated_data.stage_id)
