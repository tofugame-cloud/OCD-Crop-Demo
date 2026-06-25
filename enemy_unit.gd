# enemy_unit.gd
extends Area2D
class_name EnemyUnit

signal action_finished
signal died(unit)

@export var data: EnemyData

# ── [Dynamic Configuration] ──
var max_targets: int = 1
var card_slot_offsets: Array[Vector2] = []

@onready var sprite = $AnimatedSprite2D
@onready var hp_bar = find_child("HPBar")
@onready var label_name = find_child("Label")
@onready var sp_label = $Marker2D/SPLabel
@onready var speed_label = $Marker2D/SpeedLabel

# ── runtime vars ──
var _slot_collisions: Array = []
var _target_lines: Array = []
var _slot_labels: Array = []
var _speed_labels: Array = [] # 🛠️ [เพิ่มเติม]: เก็บ Label ตัวเลข Speed ของแต่ละลูกเต๋า
var _base_collision: CollisionShape2D = null

var current_hp: int
var speed: int = 0
var current_sp: int = 0
var is_dead: bool = false
var is_staggered: bool = false
var current_target: Node2D = null
var current_targets: Array = []
var has_been_staggered: bool = false
var is_enemy: bool = true
var current_card = null
var current_cards: Array = []
var ui_scale = Vector2(1, 1)

# ✅ track ว่าแต่ละ slot มีใครเล็งบ้าง (key=slot_idx, value=Array of players)
var slot_challengers: Dictionary = {}

# 🛠️ ไว้จำว่าสล็อตไหนโดนผู้เล่นแย่งชิงความสนใจ (Clash) ไปแล้ว จะได้ไม่วาดเส้นแดง
var _hidden_clash_slots: Dictionary = {}

# ==========================================
# --- Deck System ---
# ==========================================
func setup_deck():
	if not data: return
	pick_random_card()

func pick_random_card():
	if not data:
		current_card = null
		current_cards.clear()
		return
	current_cards.clear()
	
	# [แก้ไขแล้ว] บังคับลูปขั้นต่ำ 1 รอบ ป้องกันการสุ่มการ์ดออกมาเป็นค่าว่าง
	var loops = max(1, max_targets)
	for i in range(loops):
		current_cards.append(data.get_random_action())
	current_card = current_cards[0] if current_cards.size() > 0 else null

func get_current_card():
	return current_card

func get_card_for_target(idx: int):
	if idx < current_cards.size() and current_cards[idx] != null:
		return current_cards[idx]
	return current_card

# ==========================================
# --- Slot & Dynamic Rebuild System ---
# ==========================================
func get_slot_world_position(idx: int) -> Vector2:
	if idx < card_slot_offsets.size():
		return global_position + card_slot_offsets[idx]
	return global_position + Vector2(0, -100)

func _build_slot_offsets():
	card_slot_offsets.clear()
	for i in range(max_targets):
		var x = (i - (max_targets - 1) / 2.0) * 50.0
		card_slot_offsets.append(Vector2(x, -120))

func _rebuild_slots():
	for l in _target_lines:
		if is_instance_valid(l): l.queue_free()
	for lbl in _slot_labels:
		if is_instance_valid(lbl): lbl.queue_free()
	for s_lbl in _speed_labels:
		if is_instance_valid(s_lbl): s_lbl.queue_free()
		
	_target_lines.clear()
	_slot_labels.clear()
	_speed_labels.clear()

	for col in _slot_collisions:
		if is_instance_valid(col) and col != _base_collision:
			col.queue_free()
	_slot_collisions.clear()

	for i in range(max_targets):
		var l = Line2D.new()
		l.top_level = true
		l.z_index = 99
		l.width = 5.0 
		l.default_color = Color(1.0, 0.15, 0.15, 0.8)
		l.antialiased = true
		l.hide()
		add_child(l)
		_target_lines.append(l)

		var lbl = TextureRect.new()
		lbl.top_level = true
		lbl.z_index = 150
		lbl.texture = load("res://assets/Sprite/dice11_20260604102546.png")
		lbl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lbl.size = Vector2(60, 75)
		lbl.hide()
		add_child(lbl)
		_slot_labels.append(lbl)

		# ── [แก้ไข]: ปรับเป็นสีดำล้วนและไม่มีเงาเพื่อความสะอาดตา ──
		var s_lbl = Label.new()
		s_lbl.top_level = true
		s_lbl.z_index = 151
		s_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		# ขนาดฟอนต์ 22 สีดำล้วน
		s_lbl.add_theme_font_size_override("font_size", 22)
		s_lbl.add_theme_color_override("font_color", Color.BLACK)
		
		# ลบ label_settings ที่มีเงาออกเพื่อให้เป็นตัวหนังสือดำล้วนจริงๆ
		s_lbl.label_settings = null
		
		s_lbl.hide()
		add_child(s_lbl)
		_speed_labels.append(s_lbl)

		if i == 0 and is_instance_valid(_base_collision):
			_slot_collisions.append(_base_collision)
		else:
			var col = CollisionShape2D.new()
			if is_instance_valid(_base_collision) and _base_collision.shape:
				col.shape = _base_collision.shape
			else:
				var cap = CapsuleShape2D.new()
				cap.radius = 60
				cap.height = 120
				col.shape = cap
			add_child(col)
			_slot_collisions.append(col)
# ==========================================
# --- Challenger System ---
# ==========================================
func register_challenger(player, slot_idx: int) -> int:
	for s in slot_challengers.keys():
		slot_challengers[s].erase(player)
	if not slot_challengers.has(slot_idx):
		slot_challengers[slot_idx] = []
	slot_challengers[slot_idx].append(player)
	return slot_idx

func unregister_challenger(player):
	for s in slot_challengers.keys():
		slot_challengers[s].erase(player)

func is_clash_challenger(player, slot_idx: int) -> bool:
	if not slot_challengers.has(slot_idx): return false
	var arr = slot_challengers[slot_idx]
	if arr.is_empty(): return false
	return arr.back() == player

func reset_challengers():
	slot_challengers.clear()
	_hidden_clash_slots.clear()

func set_slot_line_visible(slot_idx: int, is_visible: bool):
	_hidden_clash_slots[slot_idx] = !is_visible
	if slot_idx < _target_lines.size() and is_instance_valid(_target_lines[slot_idx]):
		if not is_visible:
			_target_lines[slot_idx].hide()
		else:
			update_all_target_lines()

# ==========================================
# --- Ready & Process ---
# ==========================================
func _ready():
	if sprite and not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)

	_base_collision = null
	for child in get_children():
		if child is CollisionShape2D:
			_base_collision = child
			break

	if data:
		setup_enemy()

func _process(_delta):
	if is_dead: return

	for i in range(_slot_collisions.size()):
		var col = _slot_collisions[i]
		if not is_instance_valid(col): continue
		if i >= card_slot_offsets.size():
			col.disabled = true
			continue
		col.disabled = false
		var s = self.scale
		if s.x != 0 and s.y != 0:
			col.position = card_slot_offsets[i] / s
		else:
			col.position = card_slot_offsets[i]

	# เช็คว่าตอนนี้อยู่ในกระบวนการ Battle (Clash) หรือเปล่า
	var is_battling_now = false
	var main = get_tree().current_scene
	if main and main.has_method("get") and main.get("is_battling") == true:
		is_battling_now = true

	for i in range(_slot_labels.size()):
		var lbl = _slot_labels[i]
		var s_lbl = _speed_labels[i] if i < _speed_labels.size() else null
		
		if not is_instance_valid(lbl) or not lbl.visible: 
			if is_instance_valid(s_lbl): s_lbl.hide()
			continue
			
		if i >= card_slot_offsets.size(): continue
		var slot_pos = get_slot_world_position(i)
		
		# ── ปรับสูตรคำนวณตำแหน่งใหม่เพื่อให้ลูกเต๋าครอบพิกัด Slot ตรงกลางพอดี ──
		lbl.global_position = slot_pos - (lbl.size / 2.0)
		
		# ── อัปเดตตำแหน่งข้อความสปีดให้วิ่งไปอยู่ตรงกลางของลูกเต๋าลูกนั้นๆ พอดีเป๊ะ ──
		if is_instance_valid(s_lbl):
			if is_battling_now:
				s_lbl.hide()
			else:
				s_lbl.show()
				s_lbl.text = str(speed)
				# คำนวณขยับตำแหน่งให้อยู่ตรงกลางแผ่นภาพสี่เหลี่ยมลูกเต๋าพอดี
				s_lbl.global_position = lbl.global_position + (lbl.size / 2.0) - (s_lbl.size / 2.0)

# ==========================================
# --- Target Lines Draw ---
# ==========================================
func update_all_target_lines():
	for i in range(_target_lines.size()):
		var l = _target_lines[i]
		var lbl = _slot_labels[i] if i < _slot_labels.size() else null

		# บังคับให้ลูกเต๋าแสดงผลเสมอ (ตราบใดที่ศัตรูยังไม่ตาย) ไม่ว่าจะโดนลากเส้นชนหรือหลุดออก
		if is_instance_valid(lbl):
			lbl.visible = !is_dead

		var is_slot_clashed = false
		var main = get_tree().current_scene
		
		if main and main.has_method("is_slot_clashed"):
			is_slot_clashed = main.is_slot_clashed(self, i)

		# ซ่อนเฉพาะเส้นแดงเมื่อเกิดการ Clash หรือซ่อนสล็อต (ลูกเต๋าจะไม่ถูกซ่อนแล้ว)
		if _hidden_clash_slots.get(i, false) or is_slot_clashed:
			l.hide()
			continue

		if i < current_targets.size() and is_instance_valid(current_targets[i]):
			l.show()
			l.clear_points()
			l.global_position = Vector2.ZERO

			var start_p = get_slot_world_position(i)
			var end_p = current_targets[i].global_position

			var dist = start_p.distance_to(end_p)
			var curve_h = -180.0 if dist < 450 else -320.0
			var mid_p = (start_p + end_p) / 2 + Vector2(0, curve_h)

			for j in range(21):
				var t = j / 20.0
				var q0 = start_p.lerp(mid_p, t)
				var q1 = mid_p.lerp(end_p, t)
				l.add_point(q0.lerp(q1, t))
		else:
			l.hide()

func update_target_line(_start_pos: Vector2, _end_pos: Vector2):
	update_all_target_lines()

func clear_target_line():
	for l in _target_lines:
		if is_instance_valid(l): l.hide()

func reset_target():
	current_target = null
	current_targets.clear()
	clear_target_line()
	reset_challengers() 
	pick_random_card()

# ==========================================
# --- Initialization Setup ---
# ==========================================
func setup_enemy():
	if not data: return

	max_targets = data.max_targets if data.get("max_targets") != null else 1
	_build_slot_offsets()
	_rebuild_slots()
	setup_deck()

	if data.enemy_anim: sprite.sprite_frames = data.enemy_anim
	self.scale = data.visual_scale
	if data.visual_offset != Vector2.ZERO:
		sprite.position = data.visual_offset

	current_hp = data.max_hp
	current_sp = 0
	is_dead = false
	is_staggered = false
	has_been_staggered = false

	if hp_bar:
		hp_bar.max_value = data.max_hp
		hp_bar.value = current_hp
		hp_bar.show()

	if label_name:
		label_name.text = "[ENEMY] " + data.enemy_name

	roll_speed()
	update_status_ui()
	play_anim("idle")
	
	# บังคับให้ลูกเต๋าโผล่ขึ้นมาโชว์ตัวทันทีเมื่อศัตรูถูก Setup ในฉากเสร็จ
	for lbl in _slot_labels:
		if is_instance_valid(lbl): lbl.show()

# ==========================================
# --- Status UI ---
# ==========================================
func update_status_ui():
	# สปีดเลเบลชุดพื้นหลังเดิม บังคับให้ซ่อนถาวรเนื่องจากย้ายระบบตัวเลขไปลงในลูกเต๋าแบบไดนามิกแล้ว
	if speed_label:
		speed_label.visible = false

	if sp_label:
		sp_label.text = "SP: " + str(current_sp)
		sp_label.visible = !is_dead

	# 🛠️ [แก้ไขสำหรับ MainBattle]: บังคับอัปเดตข้อความสปีดสีดำบนลูกเต๋าทันทีที่มีการเรียกใช้ฟังก์ชันนี้
	for i in range(_speed_labels.size()):
		var s_lbl = _speed_labels[i]
		if is_instance_valid(s_lbl):
			s_lbl.text = str(speed)

func gain_sp(amount: int):
	if is_dead: return
	current_sp = clamp(current_sp + amount, -45, 45)
	update_status_ui()

func roll_speed():
	# สุ่มความเร็วตามข้อมูลของศัตรูตัวนั้นๆ จริงๆ จาก EnemyData
	if data:
		speed = randi_range(data.min_speed, data.max_speed)
	else:
		speed = randi_range(1, 6)
	update_status_ui()

# ==========================================
# --- Combat & Animations ---
# ==========================================
func take_damage(amount: int):
	if is_dead: return
	current_hp = max(0, current_hp - amount)
	if hp_bar:
		var t = create_tween()
		t.tween_property(hp_bar, "value", current_hp, 0.25).set_trans(Tween.TRANS_SINE)
	if current_hp <= 0:
		die()

func _on_animation_finished():
	if is_dead: return
	if is_staggered:
		sprite.play("lose")
		return
	if sprite.animation != "idle":
		play_anim("idle")
		action_finished.emit()

func play_anim(anim_name: String):
	if is_dead:
		sprite.play("die")
		return
	if is_staggered:
		sprite.play("lose")
		return
	var target_name = anim_name.to_lower()
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(target_name):
		sprite.play(target_name)
	else:
		sprite.play("idle")

func die():
	if is_dead: return
	is_dead = true
	self.set_deferred("monitorable", false)
	self.set_deferred("monitoring", false)
	clear_target_line()
	
	# สั่งซ่อนภาพลูกเต๋าและเลขสปีดทั้งหมดทันทีเมื่อศัตรูตาย (Die)
	for lbl in _slot_labels:
		if is_instance_valid(lbl): lbl.hide()
	for s_lbl in _speed_labels:
		if is_instance_valid(s_lbl): s_lbl.hide()
		
	reset_challengers() 
	reset_target()
	if hp_bar: hp_bar.hide()
	update_status_ui()
	play_anim("die")
	died.emit(self)
