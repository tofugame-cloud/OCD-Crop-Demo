extends CanvasLayer

@onready var dim_bg          = $ColorRect
@onready var right_container = $RightContainer
@onready var main_frame      = $RightContainer/TextureRect
@onready var vbox            = $RightContainer/TextureRect/VBoxContainer
@onready var title_label     = $RightContainer/TextureRect/VBoxContainer/TitleLabel
@onready var story_label     = $RightContainer/TextureRect/VBoxContainer/StoryLabel
@onready var slots_container = $RightContainer/TextureRect/VBoxContainer/KeySlotsContainer
@onready var start_button    = $RightContainer/TextureRect/VBoxContainer/StartButton
@onready var close_button    = $RightContainer/TextureRect/VBoxContainer/CloseButton

var required_slots     = 3
var current_stage_data: StageData
var slot_data: Array   = []  # เก็บ TapeData หรือ null ในแต่ละช่อง

const C_BG       = Color(0.07, 0.05, 0.03, 1.0)
const C_GOLD     = Color(0.90, 0.75, 0.35, 1.0)
const C_GOLD_DIM = Color(0.50, 0.38, 0.12, 1.0)
const C_TEXT     = Color(0.76, 0.70, 0.56, 1.0)
const C_SLOT_BG  = Color(0.11, 0.09, 0.06, 1.0)
const C_SLOT_BD  = Color(0.40, 0.30, 0.10, 1.0)
const C_SEC      = Color(0.65, 0.55, 0.25, 1.0)

const PW = 300.0
const PH = 660.0
const PY = 30.0

func _ready():
	hide()
	layer = 5
	_build_ui()

func _build_ui():
	dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_bg.color        = Color(0, 0, 0, 0.70)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	right_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	right_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	main_frame.anchor_left   = 1.0
	main_frame.anchor_top    = 0.0
	main_frame.anchor_right  = 1.0
	main_frame.anchor_bottom = 0.0
	main_frame.offset_left   = -PW - 18.0
	main_frame.offset_top    = PY
	main_frame.offset_right  = -18.0
	main_frame.offset_bottom = PY + PH
	main_frame.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
	main_frame.stretch_mode  = TextureRect.STRETCH_SCALE
	main_frame.clip_contents = true
	main_frame.mouse_filter  = Control.MOUSE_FILTER_STOP

	if not main_frame.draw.is_connected(_on_frame_draw):
		main_frame.draw.connect(_on_frame_draw)

	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   =  14
	vbox.offset_top    =  14
	vbox.offset_right  = -14
	vbox.offset_bottom = -14
	vbox.alignment     = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_theme_constant_override("separation", 8)

	title_label.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", C_GOLD)
	title_label.custom_minimum_size = Vector2(0, 28)

	_add_node_once("sep_title", func():
		var r = ColorRect.new()
		r.color                 = C_GOLD_DIM
		r.custom_minimum_size   = Vector2(0, 1)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.mouse_filter          = Control.MOUSE_FILTER_IGNORE
		return r
	, title_label.get_index() + 1)

	story_label.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
	story_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_label.custom_minimum_size   = Vector2(0, 110)
	story_label.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	story_label.vertical_alignment    = VERTICAL_ALIGNMENT_TOP
	story_label.add_theme_font_size_override("font_size", 10)
	story_label.add_theme_color_override("font_color", C_TEXT)
	story_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_add_section_header("hdr_books", "BOOKS OF THE DAY", slots_container.get_index())

	slots_container.alignment             = BoxContainer.ALIGNMENT_CENTER
	slots_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_container.custom_minimum_size   = Vector2(0, 125)
	slots_container.add_theme_constant_override("separation", 8)
	slots_container.mouse_filter = Control.MOUSE_FILTER_PASS

	var btn_idx = start_button.get_index()
	_add_section_header("hdr_addr", "ADDRESSEE", btn_idx)
	_add_addressee_box("addr_box", btn_idx + 1)

	_style_start_button()
	_style_close_button()

func _on_frame_draw():
	var sz   = main_frame.size
	var full = Rect2(Vector2.ZERO, sz)
	main_frame.draw_rect(full, C_BG)
	main_frame.draw_rect(full, C_GOLD, false, 2.0)
	main_frame.draw_rect(full.grow(-5), C_GOLD_DIM, false, 1.0)
	main_frame.draw_line(Vector2(8, 56.0), Vector2(sz.x - 8, 56.0), C_GOLD_DIM, 1.0)

func _add_node_once(node_name: String, builder: Callable, at_idx: int):
	if vbox.has_node(node_name): return
	var node = builder.call()
	node.name = node_name
	vbox.add_child(node)
	vbox.move_child(node, at_idx)

func _add_section_header(node_name: String, text: String, at_idx: int):
	_add_node_once(node_name, func():
		var hb = HBoxContainer.new()
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.custom_minimum_size   = Vector2(0, 18)
		hb.add_theme_constant_override("separation", 4)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var ll = ColorRect.new()
		ll.color                 = C_GOLD_DIM
		ll.custom_minimum_size   = Vector2(8, 1)
		ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ll.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
		ll.mouse_filter          = Control.MOUSE_FILTER_IGNORE

		var lb = Label.new()
		lb.text = " %s " % text
		lb.add_theme_font_size_override("font_size", 9)
		lb.add_theme_color_override("font_color", C_SEC)
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var lr = ColorRect.new()
		lr.color                 = C_GOLD_DIM
		lr.custom_minimum_size   = Vector2(8, 1)
		lr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lr.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
		lr.mouse_filter          = Control.MOUSE_FILTER_IGNORE

		hb.add_child(ll); hb.add_child(lb); hb.add_child(lr)
		return hb
	, at_idx)

func _add_addressee_box(node_name: String, at_idx: int):
	_add_node_once(node_name, func():
		var p = Panel.new()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.custom_minimum_size   = Vector2(0, 80)
		p.mouse_filter          = Control.MOUSE_FILTER_STOP

		var sb = StyleBoxFlat.new()
		sb.bg_color     = C_SLOT_BG
		sb.border_color = C_SLOT_BD
		sb.set_border_width_all(1)
		p.add_theme_stylebox_override("panel", sb)

		var vb2 = VBoxContainer.new()
		vb2.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb2.alignment    = BoxContainer.ALIGNMENT_CENTER
		vb2.mouse_filter = Control.MOUSE_FILTER_PASS
		vb2.add_theme_constant_override("separation", 2)

		var q = Label.new()
		q.text = "?"
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.add_theme_font_size_override("font_size", 30)
		q.add_theme_color_override("font_color", C_GOLD_DIM)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var unk = Label.new()
		unk.text = "???"
		unk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unk.add_theme_font_size_override("font_size", 10)
		unk.add_theme_color_override("font_color", C_GOLD_DIM)
		unk.mouse_filter = Control.MOUSE_FILTER_IGNORE

		vb2.add_child(q); vb2.add_child(unk)
		p.add_child(vb2)
		return p
	, at_idx)

# ════════════════════════════════════════════
#  SLOT SYSTEM
# ════════════════════════════════════════════
func setup_key_slots():
	for c in slots_container.get_children():
		c.queue_free()

	slot_data.clear()

	# จำนวน slot = จำนวน key ที่ด่านต้องการ
	required_slots = max(current_stage_data.required_keys.size(), 1)

	for i in range(required_slots):
		slot_data.append(null)

	var slot_w = int((PW - 28 - (required_slots - 1) * 8) / required_slots)

	for i in range(required_slots):
		var slot = Panel.new()
		slot.name                = "Slot_%d" % i
		slot.custom_minimum_size = Vector2(slot_w, 115)
		slot.mouse_filter        = Control.MOUSE_FILTER_STOP

		var sb = StyleBoxFlat.new()
		sb.bg_color     = C_SLOT_BG
		sb.border_color = C_SLOT_BD
		sb.set_border_width_all(1)
		slot.add_theme_stylebox_override("panel", sb)

		var vb = VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.alignment    = BoxContainer.ALIGNMENT_CENTER
		vb.mouse_filter = Control.MOUSE_FILTER_PASS
		vb.add_theme_constant_override("separation", 4)

		# แสดง required key id บนสล็อต
		var req_lbl = Label.new()
		req_lbl.text = current_stage_data.required_keys[i] if i < current_stage_data.required_keys.size() else "?"
		req_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		req_lbl.add_theme_font_size_override("font_size", 7)
		req_lbl.add_theme_color_override("font_color", C_GOLD_DIM)
		req_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var icon = Label.new()
		icon.text = "🔒"
		icon.name = "SlotIcon"
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.add_theme_font_size_override("font_size", 24)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var reg = Label.new()
		reg.text = "Empty"
		reg.name = "SlotLabel"
		reg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reg.add_theme_font_size_override("font_size", 8)
		reg.add_theme_color_override("font_color", C_GOLD_DIM)
		reg.mouse_filter = Control.MOUSE_FILTER_IGNORE

		vb.add_child(req_lbl)
		vb.add_child(icon)
		vb.add_child(reg)
		slot.add_child(vb)
		slot.gui_input.connect(_on_slot_pressed.bind(i))
		slots_container.add_child(slot)

func _on_slot_pressed(event: InputEvent, slot_index: int):
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	# หา Briefcase จาก MainHud
	var briefcase = MainHud.get_node_or_null("Briefcase")
	if briefcase == null:
		print("❌ ไม่เจอ Briefcase")
		return

	var tape = briefcase.get_selected_tape()
	if tape == null:
		# ยังไม่ได้เลือก → เปิด Briefcase ให้เลือก
		briefcase.open()
		return

	# เช็คว่า tape ตรงกับ required_key ของช่องนี้ไหม
	var required_id = ""
	if slot_index < current_stage_data.required_keys.size():
		required_id = current_stage_data.required_keys[slot_index]

	if tape.target_room_id != required_id:
		print("❌ Key ไม่ตรง! ต้องการ: [", required_id, "] แต่ได้: [", tape.target_room_id, "]")
		return

	# เช็คว่า tape นี้ถูกใช้ช่องอื่นแล้วไหม
	for i in range(slot_data.size()):
		if slot_data[i] == tape and i != slot_index:
			print("⚠️ Key นี้ใช้ในช่องอื่นแล้ว")
			return

	# ใส่ลงช่อง
	slot_data[slot_index] = tape
	_update_slot_visual(slot_index, tape)
	briefcase.clear_and_close()
	check_key_requirements(current_stage_data)

func _update_slot_visual(slot_index: int, tape: TapeData):
	var slot = slots_container.get_child(slot_index)
	if slot == null: return

	var filled_style = StyleBoxFlat.new()
	filled_style.bg_color     = Color(0.15, 0.12, 0.05, 1.0)
	filled_style.border_color = C_GOLD
	filled_style.set_border_width_all(2)
	slot.add_theme_stylebox_override("panel", filled_style)

	var vb       = slot.get_child(0)
	var icon_lbl = vb.get_node("SlotIcon")
	var reg_lbl  = vb.get_node("SlotLabel")
	icon_lbl.text = "🔑"
	reg_lbl.text  = tape.tape_name
	reg_lbl.add_theme_color_override("font_color", C_GOLD)

# ════════════════════════════════════════════
#  STYLE
# ════════════════════════════════════════════
func _style_start_button():
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.custom_minimum_size   = Vector2(0, 42)
	start_button.add_theme_font_size_override("font_size", 12)
	start_button.add_theme_color_override("font_color",          C_BG)
	start_button.add_theme_color_override("font_hover_color",    C_BG)
	start_button.add_theme_color_override("font_pressed_color",  C_BG)
	start_button.add_theme_color_override("font_disabled_color", C_GOLD_DIM)

	for theme_name in ["normal", "hover", "pressed", "disabled"]:
		var s = StyleBoxFlat.new()
		match theme_name:
			"normal":   s.bg_color = C_GOLD;                    s.border_color = C_GOLD_DIM; s.set_border_width_all(1)
			"hover":    s.bg_color = Color(0.75,0.60,0.25,1.0); s.border_color = C_GOLD;     s.set_border_width_all(2)
			"pressed":  s.bg_color = Color(0.38,0.28,0.08,1.0); s.set_border_width_all(0)
			"disabled": s.bg_color = Color(0.16,0.13,0.08,1.0); s.border_color = C_SLOT_BD;  s.set_border_width_all(1)
		start_button.add_theme_stylebox_override(theme_name, s)

func _style_close_button():
	close_button.text                  = "✕  CLOSE"
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.custom_minimum_size   = Vector2(0, 36)
	close_button.add_theme_font_size_override("font_size", 11)
	close_button.add_theme_color_override("font_color",       C_GOLD_DIM)
	close_button.add_theme_color_override("font_hover_color", C_GOLD)

	var sn = StyleBoxFlat.new()
	sn.bg_color     = Color(0.10, 0.07, 0.04, 1.0)
	sn.border_color = C_GOLD_DIM
	sn.set_border_width_all(1)
	close_button.add_theme_stylebox_override("normal", sn)

	var sh = StyleBoxFlat.new()
	sh.bg_color     = Color(0.18, 0.13, 0.07, 1.0)
	sh.border_color = C_GOLD
	sh.set_border_width_all(1)
	close_button.add_theme_stylebox_override("hover", sh)

	if not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
		
	if not start_button.pressed.is_connected(_on_start_button_pressed):
		start_button.pressed.connect(_on_start_button_pressed)

# ════════════════════════════════════════════
#  LOGIC
# ════════════════════════════════════════════
func display_stage_info(data: StageData):
	current_stage_data = data
	show()
	main_frame.queue_redraw()

	title_label.text = (data.stage_name if data.stage_name != "" else data.stage_id).to_upper()
	story_label.text = data.story_text if data.get("story_text") != null and data.story_text != "" else (
		"DEAR GUEST: I FORMALLY INVITE YOU TO THE LIBRARY.\n"
		+ "THE LIBRARY'S BOOKS CAN PROVIDE YOU ALL THE WISDOM,\n"
		+ "WEALTH, HONOR, AND POWER YOU SEEK.\n"
		+ "HOWEVER, AN ORDEAL WILL AWAIT YOU IN THE LIBRARY.\n"
		+ "IF YOU CANNOT OVERCOME THIS ORDEAL,\n"
		+ "YOU WILL BE CONVERTED INTO A BOOK YOURSELF.\n"
		+ "– ANGELA"
	)
	setup_key_slots()
	check_key_requirements(data)

func check_key_requirements(data: StageData):
	# ถ้าไม่มี required_keys เลย = เข้าได้เลย
	if data.required_keys.is_empty():
		start_button.disabled = false
		start_button.text     = "SEND INVITATION"
		return

	# เช็คว่าทุก slot มีเทปครบ
	var all_filled = true
	for tape in slot_data:
		if tape == null:
			all_filled = false
			break

	start_button.disabled = not all_filled
	start_button.text     = "SEND INVITATION" if all_filled else "KEY CARD INSUFFICIENT"

func _on_close_pressed():
	hide()

func _on_start_button_pressed():
	if current_stage_data and current_stage_data.room_resource:
		MainHud.hide_hud()
		GameManager.is_battle_won = false
		GameManager.current_room  = current_stage_data.room_resource
		get_tree().change_scene_to_file("res://scenes/main/main_battle.tscn")
