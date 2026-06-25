extends Control

signal card_selected(data: CardData, node: Control)

@export var card_data: CardData:
	set(value):
		card_data = value
		if is_node_ready():
			update_ui()

@onready var skill_icon = get_node_or_null("TextureButton/SkilIcon")
@onready var power_label = get_node_or_null("TextureButton/Power_Label")
@onready var button: TextureButton = get_node_or_null("TextureButton")

func _ready():
	# บังคับขนาดการ์ด
	custom_minimum_size = Vector2(150, 210)
	
	if button:
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_SCALE
		
		# ✅ เปลี่ยนจาก pressed เป็น button_down เพื่อให้ลากเส้นได้ทันทีที่จิ้ม
		if button.button_down.is_connected(_on_texture_button_pressed):
			button.button_down.disconnect(_on_texture_button_pressed)
		button.button_down.connect(_on_texture_button_pressed)
		
		# ✅ ป้องกันปุ่มกิน Input จนลากไปหามอนสเตอร์ไม่ได้
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		
	if skill_icon:
		skill_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE # กันรูปบังปุ่ม
		skill_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		skill_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		skill_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if power_label:
		power_label.mouse_filter = Control.MOUSE_FILTER_IGNORE # กันตัวหนังสือบังปุ่ม

	update_ui()

func update_ui():
	if not card_data: return
	if skill_icon and card_data.card_image:
		skill_icon.texture = card_data.card_image
	if power_label:
		power_label.text = str(card_data.base_power)

# ✅ ฟังก์ชันนี้จะทำงานทันทีที่ "นิ้วแตะ" (Button Down)
func _on_texture_button_pressed():
	if card_data:
		print("🃏 [CardUI] จิ้มการ์ดแล้ว (Down): ", card_data.card_name)
		card_selected.emit(card_data, self)
