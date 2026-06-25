extends MarginContainer

@onready var player_card_node = $MainLayout/PlayerSide/PlayerCard
@onready var player_desc = $MainLayout/PlayerSide/PlayerDesc
@onready var enemy_card_node = $MainLayout/EnemySide/EnemyCard
@onready var enemy_desc = $MainLayout/EnemySide/EnemyDesc
@onready var status_label = $MainLayout/CenterInfo/StatusLabel

@onready var main_layout = $MainLayout
@onready var center_info = $MainLayout/CenterInfo

func _ready():
	# ขนาดรวมของ preview (ปรับความสูงเพิ่มเล็กน้อยเพื่อให้มีที่วางคำอธิบาย)
	self.custom_minimum_size = Vector2(420, 160)

	main_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	main_layout.add_theme_constant_override("separation", 8)

	center_info.custom_minimum_size = Vector2(180, 0)
	center_info.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF

	# ตั้งค่าการแสดงผลข้อความคำอธิบาย (Player & Enemy)
	for desc_label in [player_desc, enemy_desc]:
		if desc_label:
			desc_label.custom_minimum_size = Vector2(100, 0)
			desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART # ให้ขึ้นบรรทัดใหม่เอง
			desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			desc_label.add_theme_font_size_override("font_size", 11) # ลดขนาดฟอนต์คำอธิบายลงหน่อย

	# การ์ดทั้งสองฝั่ง
	for node in [player_card_node, enemy_card_node]:
		node.custom_minimum_size = Vector2(80, 110)
		node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func update_data(p_card_data: CardData, e_unit: Node2D = null, p_unit: Node2D = null, is_clashing: bool = false):
	if is_instance_valid(player_card_node): player_card_node.texture = null
	if is_instance_valid(enemy_card_node): enemy_card_node.texture = null
	status_label.text = ""

	if p_card_data:
		if is_instance_valid(player_card_node):
			player_card_node.texture = p_card_data.card_image
			player_card_node.show()
		if is_instance_valid(player_desc):
			var p_name = p_card_data.card_name if p_card_data.card_name != "" else "Card"
			var coins = p_card_data.get_coin_count() if p_card_data.has_method("get_coin_count") else 1
			var base = p_card_data.base_power if "base_power" in p_card_data else 0
			var pwr = p_card_data.coin_power if "coin_power" in p_card_data else 0
			var ctype = p_card_data.card_type if "card_type" in p_card_data else ""
			player_desc.text = p_name + "\nCoin " + str(coins) + "\nBasePower " + str(base) + "\nCoinPower " + str(pwr) + "\nType " + str(ctype)

	var e_card_data = null
	# เพิ่มเงื่อนไข: จะดึงการ์ดศัตรูมาโชว์และคำนวณ ก็ต่อเมื่อมันเกิดการ Clash กันจริงๆ เท่านั้น
	if is_clashing and is_instance_valid(e_unit) and e_unit.has_method("get_current_card"):
		e_card_data = e_unit.get_current_card()

	if e_card_data:
		if is_instance_valid(enemy_card_node):
			enemy_card_node.show()
			enemy_card_node.texture = e_card_data.card_image
		if is_instance_valid(enemy_desc):
			var e_name = e_card_data.card_name if e_card_data.card_name != "" else "Enemy Card"
			var coins = e_card_data.get_coin_count() if e_card_data.has_method("get_coin_count") else 1
			var base = e_card_data.base_power if "base_power" in e_card_data else 0
			var pwr = e_card_data.coin_power if "coin_power" in e_card_data else 0
			var ctype = e_card_data.card_type if "card_type" in e_card_data else ""
			enemy_desc.text = e_name + "\nCoin " + str(coins) + "\nBasePower " + str(base) + "\nCoinPower " + str(pwr) + "\nType " + str(ctype)
	else:
		if is_instance_valid(enemy_card_node): enemy_card_node.hide()
		if is_instance_valid(enemy_desc): enemy_desc.text = ""

	# ดึง SP จาก unit
	var p_sp = p_unit.get("current_sp") if is_instance_valid(p_unit) else 0
	var e_sp = e_unit.get("current_sp") if is_instance_valid(e_unit) else 0
	if p_sp == null: p_sp = 0
	if e_sp == null: e_sp = 0

	# ส่งค่า is_clashing เข้าไปทำงานต่อ
	_update_clash_status(p_card_data, e_card_data, p_sp, e_sp, is_clashing)

	show()
	await get_tree().process_frame
	var vp = get_viewport_rect().size
	self.global_position = Vector2((vp.x - self.size.x) / 2.0, 50)


func _update_clash_status(p_card, e_card, p_sp: int = 0, e_sp: int = 0, is_clashing: bool = false):
	if not p_card: return
	
	# ถ้าไม่มีการ์ดศัตรู หรือระบบคำนวณแล้วว่าไม่เกิดการ Clash (ตีฟรี)
	if not e_card or not is_clashing:
		status_label.text = "UNCONTESTED"
		status_label.add_theme_color_override("font_color", Color(0, 0.8, 1))
		return

	var p_avg = (_get_max_power(p_card) + _get_min_power(p_card)) / 2.0
	var e_avg = (_get_max_power(e_card) + _get_min_power(e_card)) / 2.0

	# SP ทุก 15 = +1 effective power
	var p_sp_bonus = p_sp / 15.0
	var e_sp_bonus = e_sp / 15.0

	var diff = (p_avg + p_sp_bonus) - (e_avg + e_sp_bonus)

	if diff >= 6.0:
		status_label.text = "DOMINATING"
		status_label.add_theme_color_override("font_color", Color.GREEN)
	elif diff >= 2.0:
		status_label.text = "FAVORABLE"
		status_label.add_theme_color_override("font_color", Color.GREEN_YELLOW)
	elif diff >= -2.0:
		status_label.text = "NEUTRAL"
		status_label.add_theme_color_override("font_color", Color.YELLOW)
	elif diff >= -6.0:
		status_label.text = "STRUGGLING"
		status_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		status_label.text = "HOPELESS"
		status_label.add_theme_color_override("font_color", Color.RED)


func _get_max_power(card_data) -> float:
	if not card_data: return 0.0
	var coins = card_data.get_coin_count() if card_data.has_method("get_coin_count") else 1
	var base = card_data.base_power if "base_power" in card_data else 0
	var pwr = card_data.coin_power if "coin_power" in card_data else 0
	return float(base + (coins * pwr))

func _get_min_power(card_data) -> float:
	if not card_data: return 0.0
	return float(card_data.base_power if "base_power" in card_data else 0)
