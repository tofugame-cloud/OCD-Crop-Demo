extends Node2D

@onready var clash_display = $CanvasLayer/ClashDisplay

@export_group("Prefabs")
@export var employee_scene: PackedScene
@export var enemy_scene: PackedScene
@export var card_ui_scene: PackedScene 
@export var clash_preview_scene: PackedScene

@export_group("Battle Data")
@export var player_party: Array[EmployeeData]
@export var enemy_party: Array[EnemyData]
@export var max_cost_per_unit: int = 3 

# --- Variables ---
var current_selected_unit: EmployeeUnit = null
var current_selected_card: CardData = null
var current_card_node: Control = null  
var is_targeting: bool = false
var battle_queue: Array = [] 
var unit_costs = {} 
var turn_count: int = 1
var played_card_indices = {}

var line_container: Node2D
var is_battling: bool = false 
var original_camera_pos: Vector2 = Vector2.ZERO # เก็บพิกัดเดิมของกล้อง

# ==========================================
# --- ระบบ ClashPreview ---
# ==========================================
var clash_preview_instance: Control = null
var preview_owner_unit: EmployeeUnit = null  

# ==========================================
# --- ระบบแสดงคำอธิบายการ์ด ---
# ==========================================
var drag_start_pos: Vector2 = Vector2.ZERO
var showing_info_card_index: int = -1
var card_desc_panel: PanelContainer = null
var card_desc_label: RichTextLabel = null

@onready var card_hand = $CanvasLayer/CardHand
@onready var turn_label = $CanvasLayer/TurnLabel
@onready var start_button = $CanvasLayer/StartButton
@onready var battle_camera = $BattleCamera

func is_support_card(card_data: CardData) -> bool:
	var c_type = str(card_data.card_type).to_lower()
	return c_type in ["heal", "sp gain", "draw"]

func _ready():
	line_container = Node2D.new()
	add_child(line_container)
	
	if is_instance_valid(battle_camera):
		original_camera_pos = battle_camera.global_position # จำตำแหน่งกล้องเริ่มต้น
	
	setup_card_info_panel()
	
	if clash_preview_scene:
		clash_preview_instance = clash_preview_scene.instantiate()
		$CanvasLayer.add_child(clash_preview_instance)
		clash_preview_instance.hide()
	if GameManager.current_room != null:
		var room = GameManager.current_room
		var pool = room.enemy_pool
		if pool.size() > 0:
			var count = randi_range(room.min_enemies, room.max_enemies)
			count = min(count, pool.size())
			pool.shuffle()
			enemy_party = pool.slice(0, count)
	
	print("--- ⚔️ [SYSTEM] Battle Phase Initialized ---")
	if clash_display:
		clash_display.hide()
		print("ลงทะเบียน ClashDisplay สำเร็จ!")
	update_turn_ui()
	
	spawn_all_units()
	roll_all_speeds() 
	monster_think_phase()

func setup_card_info_panel():
	card_desc_panel = PanelContainer.new()
	card_desc_label = RichTextLabel.new()
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	
	margin.add_child(card_desc_label)
	card_desc_panel.add_child(margin)
	$CanvasLayer.add_child(card_desc_panel)
	
	card_desc_panel.custom_minimum_size = Vector2(300, 150)
	card_desc_panel.global_position = Vector2(20, 100) 
	card_desc_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_desc_label.bbcode_enabled = true
	card_desc_panel.hide()

func hide_card_info():
	if is_instance_valid(card_desc_panel):
		card_desc_panel.hide()
	showing_info_card_index = -1

func toggle_card_info(c_data: CardData, idx: int):
	if showing_info_card_index == idx:
		hide_card_info() 
	else:
		showing_info_card_index = idx
		card_desc_panel.show()
		
		var t_name = c_data.card_name if c_data.card_name != "" else "Unknown"
		var t_type = c_data.card_type if c_data.card_type != "" else "Normal"
		var t_cost = str(c_data.cost)
		var t_desc = c_data.description if c_data.description != "" else "ไม่มีคำอธิบาย"
		
		var text = "[b][color=yellow]" + t_name + "[/color][/b] (Cost: " + t_cost + ")\n"
		text += "Type: " + t_type + "\n"
		
		if not is_support_card(c_data):
			var coins = c_data.get_coin_count() if c_data.has_method("get_coin_count") else 1
			var base = str(c_data.base_power) if "base_power" in c_data else "0"
			var power = str(c_data.coin_power) if "coin_power" in c_data else "0"
			text += "Power: " + base + " + (" + power + " x " + str(coins) + " Coins)\n"
			
		text += "\n" + t_desc
		card_desc_label.text = text

func update_turn_ui():
	if turn_label: turn_label.text = "TURN: " + str(turn_count)

# ==========================================
# --- 1. ระบบจัดการหน่วยรบ ---
# ==========================================
func spawn_all_units():
	var battle_field = find_child("BattleField")
	if not battle_field: battle_field = self
	
	if player_party.is_empty() and GameManager.employee_roster.size() > 0:
		player_party = GameManager.employee_roster
	
	var columns = 2
	var spacing_x = 180
	var spacing_y = 150

	for i in range(player_party.size()):
		var data = player_party[i]
		if not data: continue
		var emp_name = data.employee_name if data.employee_name != "" else data.resource_path.get_file()
		var saved_hp = GameManager.get_employee_hp(emp_name, data.max_hp)
		if saved_hp <= 0: continue
		var unit = employee_scene.instantiate()
		battle_field.add_child(unit)
		unit.add_to_group("players")
		unit.data = data
		if unit.has_method("setup_unit"): unit.setup_unit()
		unit.current_hp = saved_hp
		if unit.hp_bar:
			unit.hp_bar.max_value = data.max_hp
			unit.hp_bar.value = saved_hp
		if unit.has_method("update_status_ui"): unit.update_status_ui()
		unit.unit_selected.connect(_on_unit_selected)
		unit_costs[unit] = max_cost_per_unit
		played_card_indices[unit] = []
		var row = int(i / columns)
		var col = i % columns
		unit.global_position = Vector2(350 - (col * spacing_x), 350 + (row * spacing_y))
		if unit.get("line"):
			unit.line.width = 4.0
			unit.line.default_color = Color(0, 0.8, 1, 0.6)

	for i in range(enemy_party.size()):
		var e_data = enemy_party[i]
		if not e_data: continue
		var enemy = enemy_scene.instantiate()
		if not enemy.died.is_connected(_on_enemy_died):
			enemy.died.connect(_on_enemy_died)
		battle_field.add_child(enemy)
		enemy.add_to_group("enemies")
		enemy.data = e_data
		if enemy.has_method("setup_unit"): enemy.setup_unit()
		if enemy.has_method("setup_enemy"): enemy.setup_enemy()
		var row = i / columns
		var col = i % columns
		enemy.global_position = Vector2(850 + (col * spacing_x), 350 + (row * spacing_y))

# ==========================================
# --- 2. ระบบเส้น Line2D ---
# ==========================================
func refresh_all_lines():
	for child in line_container.get_children():
		child.queue_free()

	if is_battling: 
		return

	for act in battle_queue:
		if not is_instance_valid(act.attacker) or not is_instance_valid(act.target): 
			continue
		
		var attacker = act.attacker
		var target = act.target
		var slot_idx = act.get("slot_idx", 0) 
		
		var is_enemy_aiming_at_me = false
		if target.get("is_enemy") == true and target.get("current_targets"):
			if slot_idx >= 0 and slot_idx < target.current_targets.size():
				if target.current_targets[slot_idx] == attacker:
					is_enemy_aiming_at_me = true

		var p_spd = attacker.get("speed")
		var e_spd = target.get("speed")
		
		var is_speed_redirect_clash = false
		if p_spd != null and e_spd != null and p_spd > e_spd:
			is_speed_redirect_clash = true

		var is_clashing = is_enemy_aiming_at_me or is_speed_redirect_clash

		var end_pos = target.global_position
		if target.has_method("get_slot_world_position") and slot_idx >= 0:
			end_pos = target.get_slot_world_position(slot_idx)

		draw_action_line(attacker.global_position, end_pos, is_clashing, true)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_method("update_all_target_lines"):
			enemy.update_all_target_lines()
					
func draw_action_line(start_p, final_target, is_clashing, is_player):
	var line = Line2D.new()
	line.width = 4.0
	
	if is_clashing: 
		line.default_color = Color(1, 1, 0, 0.9)
	else: 
		line.default_color = Color(0, 0.8, 1, 0.6) if is_player else Color(1, 0.2, 0.2, 0.6)
		
	var dist = start_p.distance_to(final_target)
	var curve_h = -280.0 if dist < 450 else -480.0
	var mid_p = (start_p + final_target) / 2 + Vector2(0, curve_h) 
	
	for i in range(21):
		var t = i / 20.0
		var q0 = start_p.lerp(mid_p, t)
		var q1 = mid_p.lerp(final_target, t)
		var pos = q0.lerp(q1, t)
		line.add_point(line.to_local(pos))
		
	line_container.add_child(line)

func clear_unit_line(unit):
	if is_instance_valid(unit) and unit.get("line"):
		unit.line.clear_points()
		unit.line.hide()

# ==========================================
# --- 3. ระบบเลือกการ์ด ---
# ==========================================
func _on_unit_selected(unit: EmployeeUnit):
	if is_targeting or unit.get("is_dead") or unit.get("is_staggered") or is_battling: return
	
	hide_card_info() 
	
	if unit == current_selected_unit and is_instance_valid(clash_preview_instance):
		if clash_preview_instance.visible:
			clash_preview_instance.hide()
		else:
			_refresh_clash_preview(unit)
		return
	
	if is_instance_valid(clash_preview_instance):
		clash_preview_instance.hide()
	preview_owner_unit = null
	
	current_selected_unit = unit
	for child in card_hand.get_children(): child.queue_free()
	if unit.get("hand"):
		for i in range(unit.hand.size()):
			var c_data = unit.hand[i]
			var new_card = card_ui_scene.instantiate()
			new_card.card_data = c_data
			new_card.set_meta("card_index", i) 
			card_hand.add_child(new_card)
			new_card.card_selected.connect(_on_card_selected_from_hand)
	update_card_visuals()
	_refresh_clash_preview(unit)

func _on_card_selected_from_hand(data: CardData, card_node: Control):
	if not is_instance_valid(current_selected_unit) or is_battling: return
	drag_start_pos = get_global_mouse_position()
	current_selected_card = data
	current_card_node = card_node
	is_targeting = true
	var line = current_selected_unit.get("line")
	if is_instance_valid(line): line.hide()

func _refresh_clash_preview(unit: EmployeeUnit):
	if not is_instance_valid(clash_preview_instance): 
		return
	
	var latest_card: CardData = null
	var latest_target = null
	var act_slot_idx: int = 0

	for act in battle_queue:
		if act.attacker == unit:
			latest_card = act.card
			latest_target = act.target
			act_slot_idx = act.get("slot_idx", 0)
	
	if latest_card == null or not is_instance_valid(latest_target):
		clash_preview_instance.hide()
		preview_owner_unit = null
		return
	
	var enemy_card_slot_idx: int = act_slot_idx
	var is_clash = false

	if latest_target.get("is_enemy") == true and latest_target.get("current_targets"):
		if enemy_card_slot_idx >= 0 and enemy_card_slot_idx < latest_target.current_targets.size():
			if latest_target.current_targets[enemy_card_slot_idx] == unit:
				is_clash = true

	var p_spd = unit.get("speed")
	var e_spd = latest_target.get("speed")
	var e_is_stag = latest_target.get("is_staggered") if latest_target.has_method("get") else false
	
	if not is_clash and p_spd != null and e_spd != null and p_spd > e_spd and not e_is_stag:
		is_clash = true

	if clash_preview_instance.has_method("update_data"):
		clash_preview_instance.update_data(latest_card, latest_target, unit, is_clash)

	var p_card_node = clash_preview_instance.get_node_or_null("MainLayout/PlayerSide/PlayerCard")
	var e_card_node = clash_preview_instance.get_node_or_null("MainLayout/EnemySide/EnemyCard")
	var center_info = clash_preview_instance.get_node_or_null("MainLayout/CenterInfo")
	var status_lbl = clash_preview_instance.get_node_or_null("MainLayout/CenterInfo/StatusLabel")

	if is_instance_valid(p_card_node):
		p_card_node.custom_minimum_size = Vector2(80, 120)
		p_card_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p_card_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if is_instance_valid(e_card_node):
		e_card_node.custom_minimum_size = Vector2(80, 120)
		e_card_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		e_card_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if is_instance_valid(center_info):
		center_info.custom_minimum_size = Vector2(150, 0)
		center_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_instance_valid(status_lbl):
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status_lbl.add_theme_font_size_override("font_size", 22)

	clash_preview_instance.custom_minimum_size = Vector2(400, 150)
	
	if is_clash and latest_target.get("is_enemy") == true and latest_target.has_method("get_slot_world_position"):
		var slot_world = latest_target.get_slot_world_position(enemy_card_slot_idx)
		var slot_screen = get_viewport().get_canvas_transform() * slot_world
		clash_preview_instance.global_position = slot_screen + Vector2(-200, 20)
	else:
		var screen_x = get_viewport_rect().size.x
		clash_preview_instance.global_position = Vector2((screen_x - 400) / 2.0, 50)

	preview_owner_unit = unit
	clash_preview_instance.show()

func _hide_clash_preview():
	if is_instance_valid(clash_preview_instance):
		clash_preview_instance.hide()
	preview_owner_unit = null

# ==========================================
# --- 4. _process: วาดเส้นระหว่างลาก ---
# ==========================================
func _process(_delta):
	if not is_targeting or not is_instance_valid(current_selected_unit) or not is_instance_valid(current_card_node):
		if is_instance_valid(current_selected_unit): clear_unit_line(current_selected_unit)
		return

	var mouse_p = get_global_mouse_position()
	if drag_start_pos.distance_to(mouse_p) < 15.0:
		return

	if is_support_card(current_selected_card):
		current_card_node.global_position = mouse_p - (current_card_node.size / 2) + Vector2(0, -100)
		current_card_node.modulate.a = 0.7
		var line = current_selected_unit.get("line")
		if is_instance_valid(line):
			line.show()
			line.clear_points()
			var start_p = current_card_node.global_position + (current_card_node.size / 2)
			var dist = start_p.distance_to(mouse_p)
			var curve_h = -280.0 if dist < 450 else -480.0
			var mid_p = (start_p + mouse_p) / 2 + Vector2(0, curve_h)
			for i in range(21):
				var t = i / 20.0
				var q0 = start_p.lerp(mid_p, t)
				var q1 = mid_p.lerp(mouse_p, t)
				var pos = q0.lerp(q1, t)
				line.add_point(line.to_local(pos))
			line.default_color = Color(0.4, 1, 0.4, 0.8)
	else:
		var line = current_selected_unit.get("line")
		if is_instance_valid(line):
			line.show()
			line.clear_points()
			var card_center = current_card_node.global_position + (current_card_node.size / 2)
			var start_p = get_canvas_transform().affine_inverse() * card_center
			var dist = start_p.distance_to(mouse_p)
			var curve_h = -280.0 if dist < 450 else -480.0
			var mid_p = (start_p + mouse_p) / 2 + Vector2(0, curve_h)
			for i in range(21):
				var t = i / 20.0
				var q0 = start_p.lerp(mid_p, t)
				var q1 = mid_p.lerp(mouse_p, t)
				var pos = q0.lerp(q1, t)
				line.add_point(line.to_local(pos))
			line.default_color = Color(0, 0.8, 1, 0.6)
			
func _input(event):
	if is_targeting and event is InputEventMouseButton and not event.is_pressed():
		finalize_targeting()

# ==========================================
# --- 5. finalize_targeting: ปล่อยการ์ด ---
# ==========================================
func finalize_targeting():
	if not is_targeting or not is_instance_valid(current_selected_unit):
		is_targeting = false
		return
		
	is_targeting = false
	clear_unit_line(current_selected_unit)

	var drop_pos = get_global_mouse_position()
	var is_click = drag_start_pos.distance_to(drop_pos) < 15.0
	var idx = current_card_node.get_meta("card_index") if is_instance_valid(current_card_node) else -1

	if is_click:
		if idx >= 0:
			toggle_card_info(current_selected_card, idx)
		return_card_to_hand()
		return

	hide_card_info()
	
	var hit_result = get_unit_under_mouse()
	var target = hit_result["unit"]
	var hit_slot_idx = hit_result["slot_idx"]
	
	var c_data = current_selected_card
	var current_u_cost = unit_costs.get(current_selected_unit, max_cost_per_unit)

	# ── การ์ด Support ──
	if is_support_card(c_data):
		var hand_center = card_hand.global_position + (card_hand.size / 2)
		var drag_dist = hand_center.distance_to(drop_pos)
		var is_thrown = drag_dist > 130
		if is_thrown and c_data.cost <= current_u_cost:
			unit_costs[current_selected_unit] -= c_data.cost
			execute_support_card(current_selected_unit, c_data, idx)
			return
		else:
			return_card_to_hand()
			return

	# ── การ์ดโจมตี ──
	var is_already_played = idx in played_card_indices.get(current_selected_unit, [])
	if is_already_played:
		remove_action_by_index(current_selected_unit, idx)
		current_u_cost = unit_costs[current_selected_unit]

	if not is_instance_valid(target) or target.get("is_dead"):
		if drop_pos.x > 700.0:
			var active_enemies = get_tree().get_nodes_in_group("enemies").filter(func(e): return not e.get("is_dead"))
			if not active_enemies.is_empty():
				var best_target = null
				var min_dist = 200.0
				for e in active_enemies:
					var dist = drop_pos.distance_to(e.global_position)
					if dist < min_dist:
						min_dist = dist
						best_target = e
				if min_dist < 200.0:
					target = best_target

	if is_instance_valid(target) and not target.get("is_dead"):
		if c_data.cost <= current_u_cost:
			if target.get("is_enemy") == true:
				if hit_slot_idx < 0:
					hit_slot_idx = _find_closest_slot_for_enemy(target, drop_pos)
				if hit_slot_idx < 0:
					hit_slot_idx = 0
				
				var player_speed = current_selected_unit.speed if "speed" in current_selected_unit else 0
				var enemy_speed = target.speed if "speed" in target else 0
				
				var is_enemy_aiming_at_me = false
				if target.get("current_targets") and hit_slot_idx < target.current_targets.size():
					if target.current_targets[hit_slot_idx] == current_selected_unit:
						is_enemy_aiming_at_me = true
				
				if player_speed > enemy_speed or is_enemy_aiming_at_me:
					if target.has_method("register_challenger"):
						target.register_challenger(current_selected_unit, hit_slot_idx)
				else:
					print("Speed ต่ำกว่าศัตรู และศัตรูไม่ได้เล็งเรา! จะกลายเป็นสถานะตีฟรี (Uncontested)")
			
			unit_costs[current_selected_unit] -= c_data.cost
			current_selected_unit.current_target = target
			played_card_indices[current_selected_unit].append(idx)
			
			battle_queue.append({
				"attacker": current_selected_unit,
				"target": target,
				"card": c_data,
				"card_index": idx,
				"slot_idx": hit_slot_idx
			})
			_refresh_clash_preview(current_selected_unit)
			current_card_node = null
		else:
			return_card_to_hand()
	else:
		return_card_to_hand()

	update_clash_redirections() 
	
	if is_instance_valid(target) and target.get("is_enemy") == true:
		var player_speed = current_selected_unit.speed if "speed" in current_selected_unit else 0
		var enemy_speed = target.speed if "speed" in target else 0
		
		var is_enemy_aiming_at_me = false
		if target.get("current_targets") and hit_slot_idx < target.current_targets.size():
			if target.current_targets[hit_slot_idx] == current_selected_unit:
				is_enemy_aiming_at_me = true
		
		if player_speed > enemy_speed or is_enemy_aiming_at_me:
			if target.has_method("set_slot_line_visible"):
				target.set_slot_line_visible(hit_slot_idx, false)
		else:
			if target.has_method("set_slot_line_visible"):
				target.set_slot_line_visible(hit_slot_idx, true)
				
	refresh_all_lines()
	update_card_visuals()

# ==========================================
# --- 7. ระบบต่อสู้ (Battle Phase + Camera Zoom) ---
# ==========================================
func resolve_battle_queue():
	is_battling = true
	card_hand.visible = false
	_hide_clash_preview()
	hide_card_info()
	toggle_speed_labels(false)

	if line_container:
		for child in line_container.get_children():
			child.queue_free()

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_method("clear_target_line"):
			enemy.clear_target_line()
		if "_slot_labels" in enemy:
				for lbl in enemy._slot_labels:
					if is_instance_valid(lbl): lbl.hide()

	update_clash_redirections()

	battle_queue.sort_custom(func(a, b):
		var speed_a = a.attacker.speed if "speed" in a.attacker else 0
		var speed_b = b.attacker.speed if "speed" in b.attacker else 0
		
		if speed_a != speed_b:
			return speed_a > speed_b
		else:
			return randf() > 0.5
	)

	var clashes = []
	var player_attacks = []
	var clashed_slots = {} 

	for action in battle_queue:
		var attacker = action.attacker
		var target = action.target
		if not is_instance_valid(target): continue
		
		var s_idx = action.get("slot_idx", 0)
		var is_slot_clash = false
		if target.get("is_enemy") == true and target.get("current_targets"):
			if s_idx >= 0 and s_idx < target.current_targets.size():
				if target.current_targets[s_idx] == attacker:
					is_slot_clash = true
					
		if is_slot_clash:
			var slot_key = str(target.get_instance_id()) + "_" + str(s_idx)
			if not clashed_slots.has(slot_key):
				clashes.append(action)
				clashed_slots[slot_key] = action
			else:
				var existing_action = clashed_slots[slot_key]
				var current_spd = attacker.get("speed") if attacker.get("speed") != null else 0
				var existing_spd = existing_action.attacker.get("speed") if existing_action.attacker.get("speed") != null else 0
				
				if current_spd > existing_spd:
					player_attacks.append(existing_action) 
					clashes.erase(existing_action)
					clashes.append(action)
					clashed_slots[slot_key] = action
				else:
					player_attacks.append(action)
		else:
			player_attacks.append(action)

	# ── เฟสเข้าปะทะ (Clashes) ──
	for clash in clashes:
		if not is_instance_valid(clash.attacker) or clash.attacker.get("is_dead") or clash.attacker.get("is_staggered"): continue
		if not is_instance_valid(clash.target) or clash.target.get("is_dead"): continue
		
		if clash.target.get("is_staggered"):
			await execute_one_sided_attack(clash.attacker, clash.target, clash.card)
		else:
			await execute_clash(clash.attacker, clash.target, clash.card)

	# ── ดึงข้อมูลการโจมตี One-Sided ของศัตรู ──
	var enemy_free_attacks = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.get("is_dead") or enemy.get("is_staggered"): continue
		var targets = enemy.get("current_targets")
		
		if targets and targets.size() > 0:
			for i in range(targets.size()):
				var t = get_real_unit(targets[i]) if is_instance_valid(targets[i]) else null
				if is_instance_valid(t) and not t.get("is_dead"):
					var slot_key = str(enemy.get_instance_id()) + "_" + str(i)
					if clashed_slots.has(slot_key): 
						continue
					var e_card = enemy.get_card_for_target(i) if enemy.has_method("get_current_card") else enemy.get_current_card()
					
					enemy_free_attacks.append({
						"enemy": enemy,
						"target": t,
						"card": e_card,
						"speed": enemy.speed if "speed" in enemy else 0
					})

	# ── นำข้อมูลโจมตีมารวมและเรียงตาม Speed ──
	var all_one_sided_attacks = []
	for attack in player_attacks:
		all_one_sided_attacks.append({
			"is_player": true,
			"attacker": attack.attacker,
			"target": attack.target,
			"card": attack.card,
			"speed": attack.attacker.speed if "speed" in attack.attacker else 0
		})

	for f_attack in enemy_free_attacks:
		all_one_sided_attacks.append({
			"is_player": false,
			"attacker": f_attack.enemy,
			"target": f_attack.target,
			"card": f_attack.card,
			"speed": f_attack.speed
		})

	all_one_sided_attacks.sort_custom(func(a, b):
		if a.speed != b.speed:
			return a.speed > b.speed
		return randf() > 0.5
	)

	# ── เฟสโจมตีฝ่ายเดียว (One-Sided Attacks) ──
	for action in all_one_sided_attacks:
		if not is_instance_valid(action.attacker) or action.attacker.get("is_dead") or action.attacker.get("is_staggered"): continue
		if not is_instance_valid(action.target) or action.target.get("is_dead"): continue
		
		await execute_one_sided_attack(action.attacker, action.target, action.card)

	# ── ดึงกล้องกลับสู่มุมมองปกติเมื่อจบทุก Action ──
	await reset_camera()

	# ── จบ Phase จัดการระบบ ──
	turn_count += 1
	update_turn_ui()
	battle_queue.clear()
	is_battling = false

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_method("reset_challengers"):
			enemy.reset_challengers()

	var all_units_post = get_tree().get_nodes_in_group("players") + get_tree().get_nodes_in_group("enemies")
	for unit in all_units_post:
		if is_instance_valid(unit) and not unit.get("is_dead"):
			var is_unit_stag = unit.get("is_staggered")
			if is_unit_stag == null: is_unit_stag = false
			if is_unit_stag:
				var recovery = unit.get_meta("stagger_recovery_turn", -1)
				if recovery != -1 and turn_count > recovery:
					unit.set("is_staggered", false)
					unit.remove_meta("stagger_recovery_turn")
					unit.play_anim("idle")

	reset_all_units()
	roll_all_speeds()
	toggle_speed_labels(true) 
	card_hand.visible = true
	monster_think_phase()

func return_card_to_hand():
	if is_instance_valid(current_card_node):
		current_card_node.modulate.a = 1.0
		current_card_node = null
	_on_unit_selected(current_selected_unit)
	
func remove_action_by_index(unit, card_idx):
	for i in range(battle_queue.size() - 1, -1, -1):
		var act = battle_queue[i]
		if act.attacker == unit and act.card_index == card_idx:
			unit_costs[unit] += act.card.cost
			played_card_indices[unit].erase(card_idx)
			
			if act.target.get("is_enemy") == true:
				if act.target.has_method("unregister_challenger"):
					act.target.unregister_challenger(unit)
				if act.target.has_method("set_slot_line_visible"):
					var s_idx = act.get("slot_idx", 0)
					act.target.set_slot_line_visible(s_idx, true)
			
			battle_queue.remove_at(i)
			var remaining_target = null
			for b in battle_queue:
				if b.attacker == unit: remaining_target = b.target
			unit.current_target = remaining_target
			break
	update_clash_redirections()
	refresh_all_lines()

func execute_support_card(unit, c_data, idx):
	if c_data.has_method("apply_support_effect"):
		c_data.apply_support_effect(unit, unit)
	if unit.get("hand") and unit.hand.size() > idx:
		unit.hand.remove_at(idx)
	if is_instance_valid(current_card_node):
		current_card_node.queue_free()
	
	current_card_node = null
	is_targeting = false 
	
	_on_unit_selected(unit)
	refresh_all_lines()
	update_card_visuals()
	
func get_unit_under_mouse() -> Dictionary:
	var space_state = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	var mouse_pos = get_global_mouse_position()
	params.position = mouse_pos
	params.collide_with_areas = true
	
	var results = space_state.intersect_point(params)
	if results.size() == 0: 
		return {"unit": null, "slot_idx": -1}
	
	var best_unit = null
	var best_slot_idx = -1
	var min_dist = 99999.0 

	for result in results:
		var collider = result.collider
		var hit = collider
		
		while hit != null:
			if hit.get("is_enemy") == true:
				var slot_collisions = hit.get("_slot_collisions")
				if slot_collisions:
					for i in range(slot_collisions.size()):
						if slot_collisions[i] == collider:
							var dist = mouse_pos.distance_to(slot_collisions[i].global_position)
							if dist < min_dist:
								min_dist = dist
								best_unit = hit
								best_slot_idx = i
				break
			elif hit.get("is_dead") != null:
				if not hit.get("is_dead") and best_unit == null:
					best_unit = hit
					best_slot_idx = 0
				break
			hit = hit.get_parent()

	if best_unit != null:
		return {"unit": best_unit, "slot_idx": best_slot_idx if best_slot_idx >= 0 else 0}
	
	return {"unit": null, "slot_idx": -1}

# ==========================================
# --- 6. ปุ่ม Cancel และ Start ---
# ==========================================
func _on_cancel_button_pressed():
	if battle_queue.is_empty() or current_selected_unit == null: return
	for i in range(battle_queue.size() - 1, -1, -1):
		if battle_queue[i].attacker == current_selected_unit:
			remove_action_by_index(current_selected_unit, battle_queue[i].card_index)
			break
	update_clash_redirections() 
	update_card_visuals()
	_hide_clash_preview()
	
func get_real_unit(node) -> Node:
	var hit = node
	while hit != null:
		if hit.get("is_dead") != null:
			return hit
		hit = hit.get_parent()
	return null
	
func _on_start_button_pressed():
	var alive_players = get_tree().get_nodes_in_group("players").filter(
		func(p): return not p.get("is_dead")
	)
	var active_players = alive_players.filter(
		func(p): return not p.get("is_staggered")
	)
	if not battle_queue.is_empty() or active_players.is_empty():
		resolve_battle_queue()
	
func get_combat_stats(card_data):
	var stats = {"coins": 1, "base": 4, "coin_power": 3}
	if card_data is CardData:
		stats.coins = card_data.get_coin_count()
		stats.base = card_data.base_power
		stats.coin_power = card_data.coin_power
	return stats

func roll_skill(stats, current_coins, unit = null):
	var total_power = stats.base
	var sp_bonus = 0.0
	
	# เก็บประวัติว่าเหรียญลูกล่าสุดออกหัวไหม (ตั้งค่าเริ่มต้นเป็นก้อยไว้ก่อน)
	var last_is_heads = false 
	
	if unit != null:
		var sp = unit.get("current_sp")
		if sp != null:
			sp_bonus = clamp(sp / 15.0 * 0.1, -0.3, 0.3)
			
	for i in range(current_coins):
		var coin_result = randf() > (0.5 - sp_bonus)
		if coin_result:
			total_power += stats.coin_power
			last_is_heads = true  # ดักจับได้ว่าลูกนี้ออกหัว!
		else:
			last_is_heads = false # ดักจับได้ว่าลูกนี้ออกก้อย!
			
	# 📦 แทนที่จะคืนค่าตัวเลขโดดๆ เราจะส่งกลับเป็น Dictionary (ห่อข้อมูล)
	return {
		"total_power": total_power,
		"is_heads": last_is_heads
	}

# ==========================================
# --- คุมการเล่น Animation (Clash & Hit) และกล้อง ---
# ==========================================
func execute_clash(attacker, target, card):
	if not is_instance_valid(attacker) or attacker.get("is_dead") or attacker.get("is_staggered"): return
	if not is_instance_valid(target) or target.get("is_dead"): return
	
	if target.get("is_staggered"):
		await execute_one_sided_attack(attacker, target, card)
		return
	
	var a_start = attacker.global_position
	var t_start = target.global_position
	var midpoint = (a_start + t_start) / 2.0
	
	# 📷 ปรับความเร็วกล้องพุ่งเข้าหา (0.3 วินาที - กำลังพอดีตา)
	await focus_on_position(midpoint, 3.0, 0.3)
	
	var t = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	# ⚔️ ปรับความเร็วตอนพุ่งชนกันเป็น 0.12 วินาที (ให้พอดูมีแรงกระแทก)
	t.tween_property(attacker, "global_position", midpoint + Vector2(-60, 0), 0.12)
	t.tween_property(target, "global_position", midpoint + Vector2(60, 0), 0.12)
	await t.finished
	
	var a_stats = get_combat_stats(card)
	var e_card = target.get_current_card() if target.has_method("get_current_card") else null
	var t_stats = get_combat_stats(e_card)
	var a_coins = a_stats.coins
	var t_coins = t_stats.coins
	
	if clash_display:
		clash_display.show()
		clash_display.start_clash_ui(card, e_card, attacker, target, battle_camera)
	
	while a_coins > 0 and t_coins > 0:
		attacker.play_anim("clash1.5")
		target.play_anim("clash1.5")
		
		# ⏳ เวลาง้างก่อนเหรียญทอยออก (0.12 วินาที)
		await get_tree().create_timer(0.12).timeout 
		
		var a_result = roll_skill(a_stats, a_coins, attacker)
		var t_result = roll_skill(t_stats, t_coins, target)
		
		var a_roll = a_result["total_power"]
		var t_roll = t_result["total_power"]
		var a_is_heads = a_result["is_heads"]
		var t_is_heads = t_result["is_heads"]
		
		if is_instance_valid(battle_camera):
			var shake_t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			shake_t.tween_property(battle_camera, "global_position", midpoint + Vector2(8, 0), 0.04)
			shake_t.tween_property(battle_camera, "global_position", midpoint + Vector2(-8, 0), 0.04)
			shake_t.tween_property(battle_camera, "global_position", midpoint, 0.04)
		
		var clash_result = 0 
		if a_roll > t_roll:
			t_coins -= 1
			clash_result = 1
			attacker.play_anim("clash2")
			target.play_anim("lose")
		elif t_roll > a_roll:
			a_coins -= 1
			clash_result = -1
			target.play_anim("clash2")
			attacker.play_anim("lose")
		else:
			clash_result = 0
			attacker.play_anim("clash2")
			target.play_anim("clash2")
			
		if clash_display:
			clash_display.process_clash_round(a_is_heads, t_is_heads, clash_result)
				
		# ⏳ [ปรับแก้] หน่วงเวลาหลังรู้ผลดวลแต่ละเหรียญเป็น 0.35 วินาที (เพื่อให้มองทันว่าใครเสียเหรียญ)
		await get_tree().create_timer(0.35).timeout

	if a_coins > 0:
		apply_clash_sp(attacker, true)
		apply_clash_sp(target, false)
		await execute_multi_hit(attacker, target, card, a_stats, a_coins, true) 
	elif t_coins > 0:
		apply_clash_sp(target, true)
		apply_clash_sp(attacker, false)
		await execute_multi_hit(target, attacker, e_card, t_stats, t_coins, false) 
		
	# ⏳ เวลาหยุดนิ่งเมื่อจบคอมโบก่อนกระโดดกลับ (0.25 วินาที)
	await get_tree().create_timer(0.25).timeout
	await return_to_idle(attacker, a_start)
	if is_instance_valid(target): await return_to_idle(target, t_start)
	
	# 📷 ดึงกล้องกลับ (0.4 วินาที)
	await reset_camera(0.4)



func execute_one_sided_attack(attacker, target, card):
	if not is_instance_valid(attacker) or attacker.get("is_dead") or attacker.get("is_staggered"): return
	if not is_instance_valid(target) or target.get("is_dead"): return
	
	var start_pos = attacker.global_position
	var dir = (target.global_position - attacker.global_position).normalized()
	var stop_pos = target.global_position - (dir * 80)
	
	await focus_on_position(attacker.global_position, 3.0, 0.4)
	
	# ตรวจสอบหาฝั่งผู้โจมตีหลัก
	var is_attacker_player = true
	if attacker.has_method("is_in_group") and attacker.is_in_group("enemy"):
		is_attacker_player = false
	elif "is_enemy" in attacker and attacker.is_enemy:
		is_attacker_player = false
	
	# 🔹 เปิด UI การตีฟรี (เคลียร์ค่าก่อนสั่งเปิด UI)
	if clash_display:
		if is_attacker_player:
			# ถ้าเราเป็นผู้เล่นตี -> ศัตรูไม่ต้องทอย (e_remaining_coins = 0)
			clash_display.e_remaining_coins = 0 
			clash_display.start_clash_ui(card, null, attacker, target, battle_camera)
		else:
			# ถ้าศัตรูตี -> ผู้เล่นไม่ต้องทอย (p_remaining_coins = 0)
			clash_display.p_remaining_coins = 0 
			clash_display.start_clash_ui(null, card, attacker, target, battle_camera)
	
	var t = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t.tween_property(attacker, "global_position", stop_pos, 0.15)
	await t.finished
	
	focus_on_position(attacker.global_position, 3.2, 0.2)
	
	var stats = get_combat_stats(card)
	# ส่งตัวแปรระบุฝั่งตามเข้าไปใน execute_multi_hit
	await execute_multi_hit(attacker, target, card, stats, stats.coins, is_attacker_player)
	
	# ปิด UI หลังโจมตีเสร็จ
	if clash_display:
		clash_display.hide_clash_ui()
	
	await get_tree().create_timer(0.4).timeout
	await return_to_idle(attacker, start_pos)
	
	await reset_camera(0.5)



func execute_multi_hit(attacker, target, card, stats, remaining_coins, is_player_hitting: bool = true):
	var anim = "clash2"
	if card != null and card.get("animation_name") != "":
		anim = card.animation_name

	var current_damage_power = stats.base

	for i in range(remaining_coins):
		if not is_instance_valid(target) or target.get("is_dead"):
			break

		attacker.play_anim("clash1.5")
		await get_tree().create_timer(0.15).timeout

		var is_heads = randf() > 0.5
		if is_heads:
			current_damage_power += stats.coin_power

		# 🔹 [ระบบดีดเหรียญดาเมจ]: บังคับสั่งงานตามฝั่งที่รับสิทธิ์มาจากฟังก์ชันระดับบนโดยตรง
		if clash_display and clash_display.visible:
			clash_display.process_damage_hit_roll(is_player_hitting, is_heads)

		if is_instance_valid(battle_camera):
			var shake_t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			shake_t.tween_property(battle_camera, "global_position", battle_camera.global_position + Vector2(20, 0), 0.05)
			shake_t.tween_property(battle_camera, "global_position", battle_camera.global_position - Vector2(20, 0), 0.05)
			shake_t.tween_property(battle_camera, "global_position", battle_camera.global_position, 0.05)

		attacker.play_anim(anim)

		if target.has_method("take_damage"):
			target.take_damage(current_damage_power)

			var m_hp = target.data.max_hp if "data" in target and target.data else 100
			var cur_hp = target.current_hp if "current_hp" in target else 0

			if cur_hp <= 0:
				target.set("is_dead", true)
				target.play_anim("die")
				if clash_display:
					clash_display.hide_clash_ui()
				check_battle_end()
				return

			var already_staggered = target.get("is_staggered")
			if already_staggered == null:
				already_staggered = false

			if cur_hp <= (m_hp * 0.5) and not already_staggered and not target.get("has_been_staggered"):
				target.is_staggered = true
				target.has_been_staggered = true  
				target.set_meta("stagger_recovery_turn", turn_count + 1)
				target.play_anim("lose")
				if target.has_method("reset_target"):
					target.reset_target()
				break
			elif not already_staggered:
				target.play_anim("lose")

		await get_tree().create_timer(0.4).timeout

	if clash_display:
		clash_display.hide_clash_ui()






func return_to_idle(unit, pos):
	if is_instance_valid(unit):
		if unit.get("is_dead"):
			unit.play_anim("die")
			return 
		var back_t = create_tween().set_trans(Tween.TRANS_SINE)
		back_t.tween_property(unit, "global_position", pos, 0.25)
		await back_t.finished
		
		var is_stag = unit.get("is_staggered")
		if is_stag == null: is_stag = false
		if is_stag: 
			unit.play_anim("lose")
		else: 
			unit.play_anim("idle")

# ==========================================
# --- 8. UI & Utilities ---
# ==========================================
func update_card_visuals():
	if not is_instance_valid(current_selected_unit): return
	var unit_current_cost = unit_costs.get(current_selected_unit, 0)
	var used_indices = played_card_indices.get(current_selected_unit, [])
	for card_node in card_hand.get_children():
		var idx = card_node.get_meta("card_index")
		if idx in used_indices:
			card_node.modulate = Color(0, 1, 0, 0.6) 
			card_node.mouse_filter = Control.MOUSE_FILTER_STOP 
		elif card_node.card_data.cost > unit_current_cost:
			card_node.modulate = Color(0.3, 0.3, 0.3) 
			card_node.mouse_filter = Control.MOUSE_FILTER_STOP 
		else:
			card_node.modulate = Color(1, 1, 1) 
			card_node.mouse_filter = Control.MOUSE_FILTER_STOP
			
func monster_think_phase():
	var alive_players = get_tree().get_nodes_in_group("players").filter(func(p): return not p.get("is_dead"))
	if alive_players.is_empty(): return

	for enemy in get_tree().get_nodes_in_group("enemies"):
		var is_stag = enemy.get("is_staggered")
		if is_stag == null: is_stag = false
		if not is_instance_valid(enemy) or enemy.get("is_dead") or is_stag:
			if is_instance_valid(enemy):
				enemy.current_target = null
				if "current_targets" in enemy: enemy.current_targets.clear()
				if enemy.has_method("clear_target_line"): enemy.clear_target_line()
			continue

		var max_t = 1
		if "max_targets" in enemy:
			max_t = enemy.max_targets
		elif enemy.get("data") and "max_targets" in enemy.data:
			max_t = enemy.data.max_targets

		var chosen = []
		
		for i in range(max_t):
			var random_player = alive_players.pick_random() 
			if random_player:
				chosen.append(random_player)

		if "current_targets" in enemy:
			enemy.current_targets = chosen
		else:
			enemy.set("current_targets", chosen)
			
		enemy.current_target = chosen[0] if chosen.size() > 0 else null
		
		enemy.set_meta("original_targets", chosen.duplicate()) 
		enemy.set_meta("original_target", enemy.current_target)
		
		if enemy.has_method("update_all_target_lines"):
			enemy.update_all_target_lines()

	refresh_all_lines()


func reset_all_units():
	for unit in played_card_indices.keys(): played_card_indices[unit] = []
	for unit in unit_costs.keys(): 
		if is_instance_valid(unit):
			unit_costs[unit] = max_cost_per_unit
			var is_stag = unit.get("is_staggered")
			if is_stag == null: is_stag = false
			
			if not unit.get("is_dead"):
				if is_stag:
					unit.play_anim("lose")
				else:
					unit.play_anim("idle")
					if unit.has_method("reset_target"): unit.reset_target()
					if unit.has_method("draw_new_hand"): unit.draw_new_hand()
				
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			var is_stag = enemy.get("is_staggered")
			if is_stag == null: is_stag = false
			if not enemy.get("is_dead"):
				if is_stag:
					enemy.play_anim("lose")
				else:
					enemy.play_anim("idle")
					if enemy.has_method("reset_target"): enemy.reset_target()
	current_selected_unit = null
	for child in card_hand.get_children(): child.queue_free()

func _on_enemy_died(slain_enemy):
	if is_instance_valid(slain_enemy):
		if slain_enemy.has_method("clear_target_line"): slain_enemy.clear_target_line()
		if slain_enemy.has_method("reset_target"): slain_enemy.reset_target()
		
	for i in range(battle_queue.size() - 1, -1, -1):
		if battle_queue[i].target == slain_enemy:
			var act = battle_queue[i]
			played_card_indices[act.attacker].erase(act.card_index)
			unit_costs[act.attacker] += act.card.cost
			battle_queue.remove_at(i)
	update_clash_redirections() 
	update_card_visuals()
	refresh_all_lines()
	if is_instance_valid(clash_preview_instance) and clash_preview_instance.visible:
		_refresh_clash_preview(preview_owner_unit)

# ==========================================
# --- 9. ระบบ Speed, SP และ แย่งเล็ง (Redirection) ---
# ==========================================
func roll_all_speeds():
	var all_units = get_tree().get_nodes_in_group("players") + get_tree().get_nodes_in_group("enemies")
	for unit in all_units:
		if is_instance_valid(unit) and not unit.get("is_dead"):
			if unit.has_method("roll_speed"):
				unit.roll_speed()
			else:
				var spd = randi_range(1, 4)
				unit.set("speed", spd)
				if unit.has_method("update_status_ui"):
					unit.update_status_ui()
				
func apply_clash_sp(unit, is_winner: bool):
	if not is_instance_valid(unit): return
	var current_sp = unit.get("current_sp")
	if current_sp == null: current_sp = 0
	var change = 10 if is_winner else -5  
	var new_sp = clamp(current_sp + change, -45, 45)
	unit.set("current_sp", new_sp)
	if unit.has_method("update_status_ui"):
		unit.update_status_ui()
	else:
		var lbl = unit.get_node_or_null("Marker2D/SPLabel")
		if lbl: lbl.text = "SP: " + str(new_sp)

func update_clash_redirections():
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var is_stag = enemy.get("is_staggered")
		if is_stag == null: is_stag = enemy.get_meta("is_staggered", false)
		
		if is_instance_valid(enemy) and not enemy.get("is_dead"):
			if is_stag:
				enemy.current_target = null
				if "current_targets" in enemy: enemy.current_targets.clear()
				continue
				
			if enemy.has_meta("original_targets"):
				var origs = enemy.get_meta("original_targets")
				enemy.current_targets = origs.duplicate()
				enemy.current_target = enemy.current_targets[0] if enemy.current_targets.size() > 0 else null
			elif enemy.has_meta("original_target"):
				var orig = enemy.get_meta("original_target")
				if is_instance_valid(orig) and not orig.get("is_dead"):
					enemy.current_target = orig
				else:
					enemy.current_target = null
		elif is_instance_valid(enemy):
			enemy.current_target = null

	for act in battle_queue:
		var p_unit = act.attacker
		var e_unit = act.target
		var s_idx = act.get("slot_idx", 0)
		var e_is_stag = e_unit.get("is_staggered") if is_instance_valid(e_unit) else false
		if e_is_stag == null: e_is_stag = e_unit.get_meta("is_staggered", false)
		
		if is_instance_valid(p_unit) and is_instance_valid(e_unit) and not e_is_stag and not e_unit.get("is_dead"):
			var p_spd = p_unit.get("speed")
			var e_spd = e_unit.get("speed")
			
			if p_spd != null and e_spd != null:
				if p_spd > e_spd:
					if e_unit.get("is_enemy") == true and e_unit.get("current_targets") != null:
						var targets = e_unit.current_targets
						if s_idx < targets.size():
							targets[s_idx] = p_unit
					else:
						e_unit.current_target = p_unit

func toggle_speed_labels(is_visible: bool):
	var all_units = get_tree().get_nodes_in_group("players") + get_tree().get_nodes_in_group("enemies")
	for unit in all_units:
		if is_instance_valid(unit):
			var label_paths = [
				"SpeedLabel", "speed_label", 
				"Marker2D/SpeedLabel", "Marker2D/speed_label"
			]
			for path in label_paths:
				var lbl = unit.get_node_or_null(path)
				if lbl: 
					lbl.visible = is_visible

# ==========================================
# --- 10. ระบบ Auto Battle ---
# ==========================================
func _on_auto_button_pressed() -> void:
	if is_battling: return

	battle_queue.clear()
	for unit in unit_costs.keys():
		unit_costs[unit] = max_cost_per_unit
		played_card_indices[unit] = []

	var players = get_tree().get_nodes_in_group("players").filter(func(p): return not p.get("is_dead"))
	var enemies = get_tree().get_nodes_in_group("enemies").filter(func(e): return not e.get("is_dead"))

	if enemies.is_empty() or players.is_empty(): return

	for p_unit in players:
		if not p_unit.get("hand"): continue

		for i in range(p_unit.hand.size()):
			var card = p_unit.hand[i]
			if is_support_card(card): continue
			if card.cost <= unit_costs[p_unit]:
				var best_target = _find_best_auto_target(p_unit, enemies)
				if best_target:
					var chosen_slot = 0
					if best_target.has_method("get_slot_world_position"):
						chosen_slot = _find_closest_slot_for_enemy(best_target, best_target.global_position)
						if chosen_slot < 0: chosen_slot = 0

					unit_costs[p_unit] -= card.cost
					played_card_indices[p_unit].append(i)
					battle_queue.append({
						"attacker": p_unit, 
						"target": best_target,
						"card": card, 
						"card_index": i,
						"slot_idx": chosen_slot
					})
					p_unit.current_target = best_target
					break 

	update_clash_redirections()
	refresh_all_lines()
	update_card_visuals()
	print("--- 🤖 [AI] Auto-Selection Complete ---")

func _find_best_auto_target(attacker, enemies) -> Node2D:
	var best_enemy = null
	var max_weight = -999.0

	for enemy in enemies:
		if enemy.get("is_dead"): continue
		var weight = 0.0
		
		var is_stag = enemy.get("is_staggered")
		if is_stag == null: is_stag = enemy.get_meta("is_staggered", false)
		if is_stag:
			weight += 50.0
			
		var p_spd = attacker.get("speed")
		var e_spd = enemy.get("speed")
		if p_spd != null and e_spd != null:
			if p_spd > e_spd:
				weight += 20.0
			elif p_spd < e_spd:
				weight -= 10.0
		var cur_hp = enemy.current_hp if "current_hp" in enemy else 0
		var m_hp = enemy.data.max_hp if "data" in enemy else 100
		if m_hp > 0:
			var hp_percent = (float(cur_hp) / float(m_hp)) * 100.0
			weight += (100.0 - hp_percent) * 0.5
		if enemy.get("current_target") == attacker:
			weight += 15.0
		if weight > max_weight:
			max_weight = weight
			best_enemy = enemy
	return best_enemy
	
func check_battle_end():
	var alive_enemies = get_tree().get_nodes_in_group("enemies").filter(func(e): return not e.get("is_dead"))
	if alive_enemies.size() == 0:
		_on_enemy_defeated()
		return

	var alive_players = get_tree().get_nodes_in_group("players").filter(func(p): return not p.get("is_dead"))
	if alive_players.size() == 0:
		_on_player_defeated()

func _on_player_defeated():
	print("--- 💀 แพ้แล้ว! กำลังบันทึกสถานะพนักงาน ---")
	for unit in get_tree().get_nodes_in_group("players"):
		if is_instance_valid(unit) and unit.data:
			var emp_name = unit.data.employee_name if unit.data.employee_name != "" else unit.data.resource_path.get_file()
			GameManager.save_employee_hp(emp_name, 0)
	await get_tree().create_timer(1.5).timeout
	
	# 🔴 เปลี่ยนชื่อซีนตรงนี้ให้เป็นซีนแผนที่ใหม่ของคุณ
	var map_path = "res://scenes/ui/Map_systemV2/stage_select_map.tscn"
	if ResourceLoader.exists(map_path):
		get_tree().change_scene_to_file(map_path)
	else:
		print("❌ ไม่พบไฟล์แผนที่ใหม่! กรุณาเช็คพาธ: ", map_path)

func _on_enemy_defeated():
	if GameManager.get("is_battle_won") == true: return
	GameManager.is_battle_won = true
	print("--- 🎉 ชนะแล้ว! กำลังบันทึกสถานะพนักงาน ---")
	
	for unit in get_tree().get_nodes_in_group("players"):
		if is_instance_valid(unit) and unit.data:
			var hp_to_save = unit.current_hp if not unit.get("is_dead") else 0
			var emp_name = unit.data.employee_name if unit.data.employee_name != "" else unit.data.resource_path.get_file()
			GameManager.save_employee_hp(emp_name, hp_to_save)
	
	GameManager.clear_room() 
	await get_tree().create_timer(1.5).timeout
	
	# 🟢 เปลี่ยนชื่อซีนตรงนี้ให้เป็นซีนแผนที่ใหม่ของคุณเช่นกัน
	var map_path = "res://scenes/ui/Map_systemV2/stage_select_map.tscn"
	if ResourceLoader.exists(map_path):
		get_tree().change_scene_to_file(map_path)
	else:
		print("❌ ไม่พบไฟล์แผนที่ใหม่! กรุณาเช็คพาธ: ", map_path)

		
func _find_closest_slot_for_enemy(enemy_node: Node2D, drop_position: Vector2) -> int:
	if not enemy_node.has_method("get_slot_world_position"): 
		return 0
		
	var closest_idx = 0
	var min_dist = 99999.0
	var max_slots = 1
	
	if enemy_node.get("current_targets") != null:
		max_slots = enemy_node.current_targets.size()
	elif enemy_node.get("card_slot_offsets") != null:
		max_slots = enemy_node.card_slot_offsets.size()
	
	for i in range(max_slots): 
		var slot_pos = enemy_node.get_slot_world_position(i)
		if slot_pos.length() < 500.0:
			slot_pos = enemy_node.global_position + slot_pos
			
		var dist = drop_position.distance_to(slot_pos)
		if dist < min_dist: 
			min_dist = dist
			closest_idx = i
			
	return closest_idx

func is_slot_clashed(enemy_node, slot_idx: int) -> bool:
	for act in battle_queue:
		if act.target == enemy_node and act.get("slot_idx") == slot_idx:
			return true 
	return false

# ==========================================
# --- 12. ระบบควบคุมกล้อง (Camera Zoom System) ---
# ==========================================

func focus_on_position(target_pos: Vector2, zoom_level: float = 3.0, duration: float = 0.4):
	print("Camera trying to move to: ", target_pos) # เพิ่มบรรทัดนี้
	if not is_instance_valid(battle_camera): 
		print("Camera is null!")
		return
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(battle_camera, "global_position", target_pos, duration)
	tween.tween_property(battle_camera, "zoom", Vector2(zoom_level, zoom_level), duration)
	await tween.finished

func reset_camera(duration: float = 0.5):
	if not is_instance_valid(battle_camera): 
		return
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# ดึงกล้องกลับไปตำแหน่งแรกเริ่มของมัน
	tween.tween_property(battle_camera, "global_position", original_camera_pos, duration)
	tween.tween_property(battle_camera, "zoom", Vector2(1, 1), duration)
	await tween.finished
