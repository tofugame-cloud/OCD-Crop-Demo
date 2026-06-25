# door_button.gd
extends TextureButton

signal door_selected(type: String)

var _room_type: String = "":
	set(value):
		_room_type = value
		if is_node_ready():
			_update_visuals(_room_type)

func _ready():
	pressed.connect(_on_pressed)
	_update_visuals(_room_type) # เผื่อกรณีมีค่าแล้ว

func _update_visuals(type: String):
	print("UPDATE VISUAL:", type)
	if type == "":
		return
	var lbl = get_node_or_null("RoomTypeLabel")
	if not lbl:
		return
	lbl.add_theme_color_override("font_color", Color.BLACK)
	match type:
		"Monster": lbl.text = "ENEMY"
		"Elite":   lbl.text = "ELITE"
		"Rest":    lbl.text = "REST"
		"Event":   lbl.text = "EVENT"
		"Shop":    lbl.text = "SHOP"
		"Boss":    lbl.text = "BOSS"
		_:         lbl.text = type.to_upper()

func _on_pressed():
	print("🖱️ name=", name, " _room_type=", _room_type)
	door_selected.emit(_room_type)
