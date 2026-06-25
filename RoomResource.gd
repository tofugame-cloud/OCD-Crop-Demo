extends Resource
class_name RoomResource

@export var room_id: String = ""
@export var type: String = "Monster"
@export var hint_text: String = ""
@export var enemy_pool: Array[EnemyData] = []  # เพิ่มบรรทัดนี้
@export var min_enemies: int = 1               # เพิ่มบรรทัดนี้
@export var max_enemies: int = 2               # เพิ่มบรรทัดนี้
