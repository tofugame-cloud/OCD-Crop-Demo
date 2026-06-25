extends Resource
class_name AbnormalityPage

@export_group("Basic Info")
@export var page_name: String = "Page Name"
@export var page_icon: Texture2D
@export_multiline var description: String = ""

@export_group("Rarity")
@export_enum("EGO", "Common", "Rare", "Unique") var rarity: String = "Common"

@export_group("Effect Settings")
## ใช้ Dictionary เพื่อเก็บผลลัพธ์ เช่น {"atk_up": 1, "hp_regen": 5}
## เพื่อให้สามารถดัดแปลงได้ง่ายโดยไม่ต้องแก้โค้ดหลัก
@export var effect_data: Dictionary = {}

## (Optional) เงื่อนไขในการเปิดใช้งาน เช่น "start_of_turn", "on_clash_win"
@export_enum("Passive", "StartOfTurn", "OnClashWin", "OnHit") var trigger_type: String = "Passive"

# --- [ Logic ] ---

## ฟังก์ชันสำหรับตรวจสอบผลของ Page
func apply_effect(target: Node2D):
	# ตรงนี้เราจะเขียน Logic ว่าถ้าเจอกุญแจคำสั่งนี้ ให้ทำอะไร
	# เช่นถ้าใน effect_data มี "atk_up" ก็ไปเพิ่มพลังโจมตีให้ target
	print("Applying effect of: ", page_name)
