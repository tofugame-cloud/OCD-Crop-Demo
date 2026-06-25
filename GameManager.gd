extends Node

signal sanity_changed(new_value)
signal game_over_triggered
signal inventory_changed

var current_employee: EmployeeData
var current_enemy: EnemyData
var current_room: RoomResource = null
var is_battle_won: bool = false
var employee_hp_map: Dictionary = {}
var current_room_type: String = ""

var manager_sanity: int = 0:
	set(value):
		var old_value = manager_sanity
		manager_sanity = clamp(value, -45, 100)
		if old_value != manager_sanity:
			sanity_changed.emit(manager_sanity)
		if manager_sanity <= -45:
			_trigger_game_over()

var current_floor: int = 1
var employee_roster: Array[EmployeeData] = []
var gathered_equipment: Array[EquipmentData] = []
var rooms_cleared: int = 0
var rooms_per_boss: int = 5
var boss_count: int = 0

# --- 📦 INVENTORY — ใช้ TapeData ตัวเดียว แยกด้วย tape_type ---
var inventory_tapes: Array[TapeData] = []

# GameManager.gd — แก้แค่ _ready() เท่านั้น

# ลบ @export var starter_key_tape: TapeData ออก

func _ready() -> void:
	print("--- 🧠 [SYSTEM] GameManager Ready ---")
	_give_starter_tapes()

func _give_starter_tapes():
	var supervisor_key = load("res://data/TapeData/key/supervisor_key.tres")
	if supervisor_key:
		add_tape(supervisor_key)
	else:
		push_error("❌ ไม่พบ supervisor_key.tres — เช็ค path ให้ตรง!")

# ════════════════════════════════════════════
#  📼 TAPE INVENTORY
# ════════════════════════════════════════════

func add_tape(data: TapeData):
	if data == null: return
	# KEY tape — ป้องกัน room เดิมซ้ำ
	if data.tape_type == "KEY":
		for t in inventory_tapes:
			if t.tape_type == "KEY" and t.target_room_id == data.target_room_id:
				print("⚠️ มี Key Tape ห้องนี้อยู่แล้ว: ", data.target_room_id)
				return
	inventory_tapes.append(data)
	inventory_changed.emit()
	print("📼 [TAPE ADDED] ", data.tape_name, " (", data.tape_type, ")")

func remove_tape(data: TapeData):
	var idx = inventory_tapes.find(data)
	if idx != -1:
		inventory_tapes.remove_at(idx)
		inventory_changed.emit()

# KEY — เช็คสิทธิ์เข้าด่าน
func has_key_tape(room_id: String) -> bool:
	for t in inventory_tapes:
		if t.tape_type == "KEY" and t.target_room_id == room_id:
			return true
	return false

# LOOT — ใช้เทปแล้วหักออก 1 ใบ
func use_loot_tape(tape_name: String) -> bool:
	for i in range(inventory_tapes.size()):
		var t = inventory_tapes[i]
		if t.tape_type == "LOOT" and t.tape_name == tape_name:
			inventory_tapes.remove_at(i)
			inventory_changed.emit()
			print("✂️ [LOOT TAPE USED] ใช้: ", tape_name)
			return true
	print("❌ [LOOT TAPE] ไม่พบเทป: ", tape_name)
	return false

# ดึงเฉพาะ KEY tapes (Briefcase ใช้)
func get_key_tapes() -> Array[TapeData]:
	var result: Array[TapeData] = []
	for t in inventory_tapes:
		if t.tape_type == "KEY":
			result.append(t)
	return result

# ดึงเฉพาะ LOOT tapes (Briefcase ใช้)
func get_loot_tapes() -> Array[TapeData]:
	var result: Array[TapeData] = []
	for t in inventory_tapes:
		if t.tape_type == "LOOT":
			result.append(t)
	return result

# ════════════════════════════════════════════
#  HP / ROOM / FLOOR
# ════════════════════════════════════════════

func save_employee_hp(unit_name: String, hp: int):
	if unit_name == "": return
	employee_hp_map[unit_name] = hp

func get_employee_hp(unit_name: String, default_max_hp: int) -> int:
	if employee_hp_map.has(unit_name):
		return employee_hp_map[unit_name]
	return default_max_hp

func clear_room():
	rooms_cleared += 1
	is_battle_won = false

func is_boss_room() -> bool:
	return rooms_cleared > 0 and rooms_cleared % rooms_per_boss == 0

func next_floor():
	current_floor += 1
	is_battle_won = false

func reset_dungeon():
	rooms_cleared = 0
	boss_count    = 0
	current_floor = 1
	is_battle_won = false
	employee_hp_map.clear()
	inventory_tapes.clear()
	inventory_changed.emit()
	print("🔄 รีเซ็ตข้อมูลทั้งหมดแล้ว")

func _trigger_game_over():
	game_over_triggered.emit()
