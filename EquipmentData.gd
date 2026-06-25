extends Resource
class_name EquipmentData

@export_group("Basic Info")
@export var equip_name: String = ""
@export var icon: Texture2D

@export_group("Stats Bonus")
## ใช้ Dictionary เก็บค่า Status ที่บวกเพิ่ม
@export var bonus_stats: Dictionary = {"hp": 0, "atk": 0}

@export_group("Resistance Bonus")
## ยิ่งค่าน้อยยิ่งกันได้ดี (เช่น 0.8 คือกัน 20%, 1.2 คือแพ้ทาง 20%)
@export var res_slash: float = 1.0
@export var res_pierce: float = 1.0
@export var res_blunt: float = 1.0
@export var res_physical: float = 1.0
@export var res_mental: float = 1.0

@export_group("Special Cards")
@export var boss_cards: Array[CardData] 

# --- [ Functions ] ---

func get_stat_bonus(stat_name: String) -> int:
	return bonus_stats.get(stat_name, 0)
