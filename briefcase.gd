extends CanvasLayer

@onready var dim_bg        = $ColorRect
@onready var main_panel    = $MainPanel
@onready var vbox          = $MainPanel/VBoxContainer
@onready var title_label   = $MainPanel/VBoxContainer/TitleLabel
@onready var separator     = $MainPanel/VBoxContainer/Separator
@onready var close_button  = $MainPanel/VBoxContainer/CloseButton
@onready var tab_container = $MainPanel/VBoxContainer/TabContainer
@onready var key_grid      = $MainPanel/VBoxContainer/TabContainer/KeyTapeTab/KeyTapeGrid
@onready var loot_grid     = $MainPanel/VBoxContainer/TabContainer/LootTapeTab/LootTapeGrid

const C_BG        = Color(0.07, 0.05, 0.03, 1.0)
const C_GOLD      = Color(0.90, 0.75, 0.35, 1.0)
const C_GOLD_DIM  = Color(0.50, 0.38, 0.12, 1.0)
const C_TEXT      = Color(0.76, 0.70, 0.56, 1.0)
const C_SLOT_BG   = Color(0.11, 0.09, 0.06, 1.0)
const C_SLOT_BD   = Color(0.40, 0.30, 0.10, 1.0)

const RARITY_COLORS = {
	"Common":    Color(0.76, 0.70, 0.56, 1.0),
	"Uncommon":  Color(0.30, 0.80, 0.40, 1.0),
	"Rare":      Color(0.20, 0.50, 0.90, 1.0),
	"Epic":      Color(0.70, 0.20, 0.90, 1.0),
	"Legendary": Color(0.95, 0.60, 0.10, 1.0),
}

# ── Selection State ──
var selected_tape: TapeData = null
var selected_card: Panel    = null

func _ready():
	hide()
	layer = 10
	_build_ui()
	GameManager.inventory_changed.connect(_on_inventory_changed)

func _build_ui():
	dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_bg.color        = Color(0, 0, 0, 0.70)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	main_panel.set_anchors_preset(Control.PRESET_CENTER)
	main_panel.offset_left   = -320.0
	main_panel.offset_top    = -300.0
	main_panel.offset_right  =  320.0
	main_panel.offset_bottom =  300.0
	main_panel.mouse_filter  = Control.MOUSE_FILTER_STOP

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color     = C_BG
	panel_style.border_color = C_GOLD
	panel_style.set_border_width_all(2)
	main_panel.add_theme_stylebox_override("panel", panel_style)

	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   =  12
	vbox.offset_top    =  12
	vbox.offset_right  = -12
	vbox.offset_bottom = -12
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS

	title_label.text = "BRIEFCASE"
	title_label.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.custom_minimum_size   = Vector2(0, 32)
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", C_GOLD)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE

	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.mouse_filter        = Control.MOUSE_FILTER_PASS

	for grid in [key_grid, loot_grid]:
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		grid.mouse_filter = Control.MOUSE_FILTER_PASS

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

func open():
	show()
	refresh()

func refresh():
	_clear_selection()
	_populate_grid(key_grid,  GameManager.get_key_tapes())
	_populate_grid(loot_grid, GameManager.get_loot_tapes())

func _populate_grid(grid: GridContainer, tapes: Array[TapeData]):
	for child in grid.get_children():
		child.queue_free()

	if tapes.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "— ไม่มีเทป —"
		empty_lbl.add_theme_color_override("font_color", C_GOLD_DIM)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
		grid.add_child(empty_lbl)
		return

	for tape in tapes:
		grid.add_child(_make_tape_card(tape))

func _make_tape_card(tape: TapeData) -> Panel:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(160, 200)
	card.mouse_filter        = Control.MOUSE_FILTER_STOP

	var card_style = StyleBoxFlat.new()
	card_style.bg_color     = C_SLOT_BG
	card_style.border_color = C_SLOT_BD
	card_style.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", card_style)

	var vb = VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left  = 8;  vb.offset_top    = 8
	vb.offset_right = -8; vb.offset_bottom = -8
	vb.alignment    = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_PASS

	if tape.icon:
		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(80, 80)
		icon_rect.expand_mode         = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture             = tape.icon
		icon_rect.mouse_filter        = Control.MOUSE_FILTER_PASS
		vb.add_child(icon_rect)
	else:
		var ph = Label.new()
		ph.text = "📼"
		ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ph.add_theme_font_size_override("font_size", 36)
		ph.mouse_filter = Control.MOUSE_FILTER_PASS
		vb.add_child(ph)

	var name_lbl = Label.new()
	name_lbl.text                 = tape.tape_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", RARITY_COLORS.get(tape.rarity, C_TEXT))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS

	var rarity_lbl = Label.new()
	rarity_lbl.text                 = tape.rarity
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_font_size_override("font_size", 9)
	rarity_lbl.add_theme_color_override("font_color", C_GOLD_DIM)
	rarity_lbl.mouse_filter = Control.MOUSE_FILTER_PASS

	var desc_lbl = Label.new()
	desc_lbl.text                 = tape.description
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 9)
	desc_lbl.add_theme_color_override("font_color", C_TEXT)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_PASS

	vb.add_child(name_lbl)
	vb.add_child(rarity_lbl)
	vb.add_child(desc_lbl)
	card.add_child(vb)

	card.gui_input.connect(_on_card_pressed.bind(tape, card))
	return card

# ── Selection System ──────────────────────────────────
func _on_card_pressed(event: InputEvent, tape: TapeData, card: Panel):
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	# กดซ้ำ = deselect
	if selected_tape == tape:
		_clear_selection()
		return
	_select_card(tape, card)

func _select_card(tape: TapeData, card: Panel):
	_clear_selection()
	selected_tape = tape
	selected_card = card

	var sel_style = StyleBoxFlat.new()
	sel_style.bg_color     = Color(0.22, 0.17, 0.05, 1.0)
	sel_style.border_color = C_GOLD
	sel_style.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", sel_style)
	print("✅ [BRIEFCASE] เลือก: ", tape.tape_name)

func _clear_selection():
	if selected_card != null and is_instance_valid(selected_card):
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color     = C_SLOT_BG
		normal_style.border_color = C_SLOT_BD
		normal_style.set_border_width_all(1)
		selected_card.add_theme_stylebox_override("panel", normal_style)
	selected_tape = null
	selected_card = null

func get_selected_tape() -> TapeData:
	return selected_tape

func clear_and_close():
	_clear_selection()
	hide()

# ─────────────────────────────────────────────────────
func _on_close_pressed():
	clear_and_close()

func _on_inventory_changed():
	if visible:
		refresh()
