extends Control

# ==========================================
# 🟢 โซน Player (ฝั่งซ้าย)
# ==========================================
@onready var p_side_panel = $HBoxContainer/PlayerSide
@onready var p_skill_name: Label = $HBoxContainer/PlayerSide/SkillInfoPanel/SkillNameLabel
@onready var p_skill_desc: Label = $HBoxContainer/PlayerSide/SkillInfoPanel/SkillDescLabel
@onready var p_base_number: Label = $HBoxContainer/PlayerSide/BasePowerFrame/BaseNumber
@onready var p_coin_hand: AnimatedSprite2D = $HBoxContainer/PlayerSide/CoinHandDisplay
@onready var p_coin_count: Label = $HBoxContainer/PlayerSide/CoinHandDisplay/CoinCountLabel
@onready var p_marker: Marker2D = $HBoxContainer/PlayerSide/CoinHandDisplay/FloatingTextMarker

var p_current_power: int = 0
var p_remaining_coins: int = 0
var p_coin_value: int = 0

# ==========================================
# 🔴 โซน Enemy (ฝั่งขวา)
# ==========================================
@onready var e_side_panel = $HBoxContainer/EnemySide
@onready var e_skill_name: Label = $HBoxContainer/EnemySide/SkillInfoPanel/SkillNameLabel
@onready var e_skill_desc: Label = $HBoxContainer/EnemySide/SkillInfoPanel/SkillDescLabel
@onready var e_base_number: Label = $HBoxContainer/EnemySide/BasePowerFrame/BaseNumber
@onready var e_coin_hand: AnimatedSprite2D = $HBoxContainer/EnemySide/CoinHandDisplay
@onready var e_coin_count: Label = $HBoxContainer/EnemySide/CoinHandDisplay/CoinCountLabel
@onready var e_marker: Marker2D = $HBoxContainer/EnemySide/CoinHandDisplay/FloatingTextMarker

var e_current_power: int = 0
var e_remaining_coins: int = 0
var e_coin_value: int = 0

# ==========================================
# 🎯 โซน Tracking
# ==========================================
var target_attacker = null
var target_enemy = null
var battle_camera_ref = null
var is_tracking = false

# ==========================================
# ⚙️ โหลด Scene
# ==========================================
var floating_number_scene = preload("res://scenes/ui/floating_number.tscn")

func _ready():
	if is_instance_valid(p_coin_hand):
		p_coin_hand.animation_finished.connect(_on_p_coin_hand_finished)
	if is_instance_valid(e_coin_hand):
		e_coin_hand.animation_finished.connect(_on_e_coin_hand_finished)

func _process(_delta):
	pass

# ==========================================
# 🔹 1. ฟังก์ชันเปิดหน้าจอ UI
# ==========================================
func start_clash_ui(player_card, enemy_card, attacker_node = null, enemy_node = null, camera_node = null):
	show()

	target_attacker = attacker_node
	target_enemy = enemy_node
	battle_camera_ref = camera_node
	is_tracking = false

	var hbox = $HBoxContainer
	hbox.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hbox.position.y = 80

	var p_frame = $HBoxContainer/PlayerSide/BasePowerFrame
	var e_frame = $HBoxContainer/EnemySide/BasePowerFrame
	var p_hand_pos = p_coin_hand.position
	var e_hand_pos = e_coin_hand.position

	if is_instance_valid(p_frame):
		p_frame.position = Vector2(p_hand_pos.x + 67, p_hand_pos.y + 10)
	if is_instance_valid(e_frame):
		e_frame.position = Vector2(e_hand_pos.x - 75, e_hand_pos.y + 10)

	# --- ฝั่ง Player ---
	if player_card != null:
		if is_instance_valid(p_side_panel):
			p_side_panel.show()
		if is_instance_valid(p_frame):
			p_frame.show()   # ✅ reset กลับมาโชว์
		p_skill_name.text = player_card.card_name
		p_skill_desc.text = player_card.description
		p_current_power = player_card.base_power
		p_base_number.text = str(p_current_power)
		p_remaining_coins = player_card.get_coin_count()
		p_coin_count.text = str(p_remaining_coins)
		p_coin_value = player_card.coin_power
		if is_instance_valid(p_coin_hand):
			p_coin_hand.show()
			p_coin_hand.stop()
			p_coin_hand.animation = "TossCoin"
			p_coin_hand.frame = 0
	else:
		# 🟢 Enemy ตีฟรี → ซ่อนทุกอย่างฝั่ง Player
		p_remaining_coins = 0
		p_current_power = 0
		if is_instance_valid(p_coin_hand):
			p_coin_hand.hide()
		if is_instance_valid(p_side_panel):
			p_side_panel.hide()
		if is_instance_valid(p_frame):
			p_frame.hide()

	# --- ฝั่ง Enemy ---
	if enemy_card != null:
		if is_instance_valid(e_side_panel):
			e_side_panel.show()
		if is_instance_valid(e_frame):
			e_frame.show()   # ✅ reset กลับมาโชว์
		e_skill_name.text = enemy_card.card_name
		e_skill_desc.text = enemy_card.description
		e_current_power = enemy_card.base_power
		e_base_number.text = str(e_current_power)
		e_remaining_coins = enemy_card.get_coin_count()
		e_coin_count.text = str(e_remaining_coins)
		e_coin_value = enemy_card.coin_power
		if is_instance_valid(e_coin_hand):
			e_coin_hand.show()
			e_coin_hand.stop()
			e_coin_hand.animation = "TossCoin"
			e_coin_hand.frame = 0
	else:
		# 🟢 Player ตีฟรี → ซ่อนทุกอย่างฝั่ง Enemy
		e_remaining_coins = 0
		e_current_power = 0
		if is_instance_valid(e_coin_hand):
			e_coin_hand.hide()
		if is_instance_valid(e_side_panel):
			e_side_panel.hide()
		if is_instance_valid(e_frame):
			e_frame.hide()

	play_toss_animations()

# ==========================================
# 🔹 1.5 ฟังก์ชันซ่อน UI
# ==========================================
func hide_clash_ui():
	is_tracking = false
	hide()

# ==========================================
# 🔹 2. ฟังก์ชันรับผลการทอยรายรอบ (ช่วงดวลแคลช)
# ==========================================
func process_clash_round(p_is_heads: bool, e_is_heads: bool, clash_result: int):
	update_player_roll(p_is_heads)
	update_enemy_roll(e_is_heads)

	if clash_result == 1:
		if e_remaining_coins > 0:
			e_remaining_coins -= 1
			e_coin_count.text = str(e_remaining_coins)
	elif clash_result == -1:
		if p_remaining_coins > 0:
			p_remaining_coins -= 1
			p_coin_count.text = str(p_remaining_coins)

# ==========================================
# 🟢 ฟังก์ชันแสดงผลทอยเหรียญทีละฮิต (ช่วงทำดาเมจ / ตีฟรี)
# ==========================================
func process_damage_hit_roll(is_player_hitting: bool, is_heads: bool):
	if is_player_hitting:
		update_player_roll(is_heads)
		if p_remaining_coins > 0:
			p_remaining_coins -= 1
			p_coin_count.text = str(p_remaining_coins)
	else:
		update_enemy_roll(is_heads)
		if e_remaining_coins > 0:
			e_remaining_coins -= 1
			e_coin_count.text = str(e_remaining_coins)

func update_player_roll(is_heads: bool):
	if p_remaining_coins > 0:
		if is_instance_valid(p_coin_hand):
			p_coin_hand.stop()
			p_coin_hand.frame = 0
			p_coin_hand.play("TossCoin")
		if is_heads:
			p_current_power += p_coin_value
			p_base_number.text = str(p_current_power)
			spawn_floating_text("+" + str(p_coin_value), Color.GREEN, p_marker)
		else:
			spawn_floating_text("+0", Color.DARK_GRAY, p_marker)

func update_enemy_roll(is_heads: bool):
	if e_remaining_coins > 0:
		if is_instance_valid(e_coin_hand):
			e_coin_hand.stop()
			e_coin_hand.frame = 0
			e_coin_hand.play("TossCoin")
		if is_heads:
			e_current_power += e_coin_value
			e_base_number.text = str(e_current_power)
			spawn_floating_text("+" + str(e_coin_value), Color.RED, e_marker)
		else:
			spawn_floating_text("+0", Color.DARK_GRAY, e_marker)

# ==========================================
# 🔹 3. ระบบแสดงตัวเลขและแอนิเมชัน
# ==========================================
func spawn_floating_text(display_text: String, text_color: Color, marker: Marker2D):
	if floating_number_scene == null or marker == null: return

	var number_instance = floating_number_scene.instantiate()
	marker.add_child(number_instance)
	number_instance.position = Vector2.ZERO

	if marker.global_scale != Vector2.ZERO:
		number_instance.scale = Vector2.ONE / marker.global_scale

	if "text" in number_instance:
		number_instance.text = display_text
	number_instance.modulate = text_color

func play_toss_animations():
	if is_instance_valid(p_coin_hand) and p_remaining_coins > 0 and p_coin_hand.visible:
		p_coin_hand.play("TossCoin")
	if is_instance_valid(e_coin_hand) and e_remaining_coins > 0 and e_coin_hand.visible:
		e_coin_hand.play("TossCoin")

func _on_p_coin_hand_finished():
	pass

func _on_e_coin_hand_finished():
	pass
