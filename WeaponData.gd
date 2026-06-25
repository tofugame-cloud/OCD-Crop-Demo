extends Resource
class_name WeaponData

@export var weapon_name: String = "ชื่ออาวุธ"
@export var weapon_icon: Texture2D # เอาไว้โชว์ในช่อง Inventory หรือหน้าเลือกตัว
@export var bonus_cards: Array[CardData] = [] # ลากการ์ดที่อาวุธนี้จะให้มาใส่ตรงนี้
@export var attack_bonus: int = 0 # แถมพลังโจมตีให้ตัวละครด้วยก็ได้
