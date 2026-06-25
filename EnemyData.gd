extends Resource
class_name EnemyData

@export_group("Basic Info")
@export var enemy_name: String = "Abnormality"
@export var max_hp: int = 100

@export_group("Visuals")
## ลากไฟล์ SpriteFrames ของมอนสเตอร์มาใส่ที่นี่ (มีท่า idle, atk_slash, hurt ฯลฯ)
@export var enemy_topdown: SpriteFrames 
@export var enemy_anim: SpriteFrames 
@export var visual_scale: Vector2 = Vector2(1.0, 1.0)
@export var visual_offset: Vector2 = Vector2(0, 0)

@export_group("Combat")
## 🔹 ช่วงค่าความเร็วของมอนสเตอร์ (เช่น 1 ถึง 6)
@export var min_speed: int = 1
@export var max_speed: int = 6
@export var max_targets: int = 1
## รายการการ์ดหรือท่าโจมตีที่มอนสเตอร์ตัวนี้ "หยิบมาใช้ได้"
@export var enemy_action_pool: Array[CardData]
## พลังโจมตีพื้นฐาน (เผื่อเอาไปบวกกับดาเมจของการ์ด)
@export var base_attack: int = 5 

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

# --- [ Functions ] ---

## ฟังก์ชันสำหรับสุ่มหยิบการ์ดขึ้นมา 1 ใบเพื่อโจมตีในเทิร์นนั้น
func get_random_action() -> CardData:
	if enemy_action_pool.size() > 0:
		return enemy_action_pool.pick_random()
	return null
