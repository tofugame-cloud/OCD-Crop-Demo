extends Resource
class_name EmployeeData

@export_group("Basic Info")
@export var employee_name: String = "Employee Name"
@export var employee_id: int = 1
@export var portrait: Texture2D # ใช้โชว์ใน UI

@export_group("Visuals")
## ใส่ SpriteFrames ที่มีทั้งท่าสู้ (idle, slash) และท่าเดิน (walk_up, walk_down, etc.)
@export var employee_topdown: SpriteFrames 
@export var employee_anim: SpriteFrames 
@export var visual_scale: Vector2 = Vector2(0.1, 0.1)
@export var visual_offset: Vector2 = Vector2(0, 0)

@export_group("Status")
@export var max_hp: int = 100
# เอา current_hp ออกจากไฟล์ .tres เพื่อไม่ให้เลือดลดถาวรข้ามเซฟ
@export var base_attack: int = 10
@export var speed: int = 5 

@export_group("Deck System")
@export var starting_deck: Array[CardData] = []

@export_group("Equipped Items")
@export var current_weapon: WeaponData
@export var equipped_items: Array[EquipmentData] = []

@export_group("Weakness/Resistance")
## 0.5 = ต้านทาน (ได้รับดาเมจครึ่งเดียว)
## 1.0 = ปกติ
## 2.0 = แพ้ทาง (ได้รับดาเมจ 2 เท่า)
## 0.0 = ป้องกันสมบูรณ์ (Immune)

@export var res_slash: float = 1.0   # ฟัน
@export var res_pierce: float = 1.0  # แทง
@export var res_blunt: float = 1.0   # ทุบ

@export var res_physical: float = 1.0 # กายภาพ
@export var res_mental: float = 1.0   # จิตใจ

@export_group("Abnormality Pages")
## รายการ Page ที่ตัวละครตัวนี้ถืออยู่ (ที่ได้รับเลือกมาจาก Pool)
@export var active_pages: Array[AbnormalityPage] = []

@export_group("Combat Traits")
@export var can_parry: bool = false # พนักงานคนนี้มีทักษะ Parry ไหม?
@export var parry_window_multiplier: float = 1.0 # 1.0 คือปกติ ถ้าคนเก่งอาจจะเป็น 1.5 (กดง่ายขึ้น)


# --- [ Functions ] ---

## ฟังก์ชันรวมการ์ดทั้งหมด
func get_full_deck() -> Array[CardData]:
	var full_deck = starting_deck.duplicate()
	
	if current_weapon and current_weapon.get("bonus_cards"):
		for card in current_weapon.bonus_cards:
			if card: full_deck.append(card)
	
	for item in equipped_items:
		if item and item.get("bonus_cards"):
			for card in item.bonus_cards:
				if card: full_deck.append(card)
					
	return full_deck
