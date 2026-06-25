extends Area2D
class_name EmployeeUnit

signal action_finished
signal died(unit)
signal unit_selected(unit_node)

@export var data: EmployeeData

@onready var sprite = $AnimatedSprite2D
@onready var hp_bar = find_child("HPBar")
@onready var label_name = find_child("Label")
@onready var sp_label = $Marker2D/SPLabel 
@onready var speed_label = $Marker2D/SpeedLabel

var line: Line2D = null 
var current_hp: int
var speed: int = 0
var current_sp: int = 0
var is_dead: bool = false
var is_staggered: bool = false 
var current_target: Node2D = null 

# --- ระบบ UI Settings ---
var ui_scale = Vector2(1, 1)

# --- ระบบ Deck ---
var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []
var hand: Array[CardData] = []
var hand_size: int = 4 
var has_been_staggered: bool = false

func _ready():
	input_pickable = true
	line = find_child("TargetLine*") as Line2D
	if line:
		line.hide()
		line.top_level = true    
		line.z_index = 100
		line.width = 30.0        
		line.default_color = Color(0, 0.8, 1, 0.8) 
		line.clear_points()
		line.add_point(Vector2.ZERO)
		line.add_point(Vector2.ZERO)
	
	if sprite and not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)

func update_status_ui():
	var is_battling_now = false
	var main = get_tree().current_scene
	if main and main.has_method("get") and main.get("is_battling") == true:
		is_battling_now = true

	if speed_label:
		speed_label.text = str(speed)
		speed_label.top_level = true
		speed_label.scale = ui_scale
		speed_label.z_index = 150
		speed_label.add_theme_color_override("font_color", Color(0, 0, 0))
		speed_label.global_position = $Marker2D.global_position + Vector2(-15, -20) 
		speed_label.visible = !is_dead and !is_battling_now # Speed หายตอนสู้
	
	if sp_label:
		sp_label.text = "SP: " + str(current_sp)
		sp_label.visible = !is_dead # SP ต้องโชว์ตลอดแม้จะสู้กันอยู่

# 🔹 เพิ่มฟังก์ชันนี้เพื่อให้ระบบ Clash สั่งเพิ่ม SP ได้
func gain_sp(amount: int):
	if is_dead: return
	current_sp = clampi(current_sp + amount, -45, 45)
	update_status_ui()

func roll_speed():
	speed = randi_range(1, 4) 
	update_status_ui()

func update_target_line(start_pos: Vector2, end_pos: Vector2):
	if line:
		if not line.visible: line.show()
		line.global_position = Vector2.ZERO 
		line.set_point_position(0, start_pos)
		line.set_point_position(1, end_pos)

func clear_target_line():
	if line: line.hide()
	current_target = null

func reset_target():
	current_target = null
	clear_target_line()

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.is_pressed():
		unit_selected.emit(self)

func setup_unit():
	if not data: return
	if data.employee_anim: sprite.sprite_frames = data.employee_anim
	self.scale = data.visual_scale
	current_sp = 0
	is_dead = false
	is_staggered = false
	var has_been_staggered: bool = false
	if hp_bar:
		hp_bar.max_value = data.max_hp
		hp_bar.value = current_hp
		hp_bar.show()
	if label_name: label_name.text = data.employee_name
	roll_speed()
	update_status_ui()
	play_anim("idle")
	setup_deck()

func setup_deck():
	if not data or data.starting_deck.is_empty(): return
	draw_pile = data.starting_deck.duplicate()
	draw_pile.shuffle()
	draw_new_hand()

func draw_new_hand():
	discard_pile.append_array(hand)
	hand.clear()
	for i in range(hand_size):
		if draw_pile.is_empty():
			if discard_pile.is_empty(): break 
			draw_pile = discard_pile.duplicate()
			draw_pile.shuffle()
			discard_pile.clear()
		hand.append(draw_pile.pop_back())

func draw_one_card(slot_index: int):
	if draw_pile.is_empty():
		if discard_pile.is_empty(): return
		draw_pile = discard_pile.duplicate()
		draw_pile.shuffle()
		discard_pile.clear()
	if not draw_pile.is_empty():
		var new_card = draw_pile.pop_back()
		if slot_index >= 0 and slot_index < hand.size():
			discard_pile.append(hand[slot_index])
			hand[slot_index] = new_card

func play_anim(anim_name: String):
	if is_dead:
		sprite.play("die")
		return
	var clean_anim = anim_name.to_lower().strip_edges()
	if is_staggered and clean_anim == "idle":
		sprite.play("lose")
		return
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(clean_anim):
		sprite.play(clean_anim)
	else:
		if clean_anim != "idle" and sprite.sprite_frames.has_animation("clash2"): 
			sprite.play("clash2")

func take_damage(amount: int):
	if is_dead: return
	current_hp = clampi(current_hp - amount, 0, data.max_hp)
	if hp_bar:
		var t = create_tween()
		t.tween_property(hp_bar, "value", current_hp, 0.2).set_trans(Tween.TRANS_QUAD)
	if current_hp <= 0: 
		die()
	# ไม่เรียก play_anim("lose") ที่นี่ — ให้ main_battle จัดการ animation

func _on_animation_finished():
	if is_dead: return
	if is_staggered:
		sprite.play("lose")
		return
	if sprite.animation != "idle":
		play_anim("idle")
		action_finished.emit()

func die():
	if is_dead: return
	is_dead = true
	clear_target_line()
	if hp_bar: hp_bar.hide()
	update_status_ui()
	play_anim("die")
	died.emit(self)
