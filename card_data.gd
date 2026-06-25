extends Resource
class_name CardData

@export_group("Basic Info")
@export var card_name: String = "Card"
@export var cost: int = 1
@export var card_image: Texture2D
@export var animation_name: String = "clash2"
@export_multiline var description: String = ""

@export_group("Combat Stats")
@export var base_power: int = 5
@export var coin_power: int = 2
@export var manual_coin_count: int = 0 

# 🟢 เพิ่มการเลือกประเภทอาวุธ
@export_enum("None", "Slash", "Pierce", "Blunt") var dmg_type: String = "None"
# 🟢 เพิ่มการเลือกประเภทพลัง
@export_enum("Physical", "Mental") var dmg_source: String = "Physical"

@export_enum("Attack", "Heal", "SP Gain", "Draw") var card_type: String = "Attack"

@export_group("Effects")
@export var heal_amount: int = 15
@export var sp_gain: int = 20
@export var draw_amount: int = 1 

@export_group("Reaction System")
## ติ๊กถูกถ้าการ์ดใบนี้คือการ์ด Parry/Counter
@export var is_reaction_card: bool = false 

## กำหนดความยากในการกด (ถ้า 0 คือปกติ)
## ยิ่งค่าสูงอาจจะยิ่งทำให้ Window การกดสั้นลงหรือยากขึ้น (ถ้าอยากให้เป็น Hard Mode)
@export var reaction_difficulty: float = 0.0 

# ==========================================
# --- [ Logic ] ---
# ==========================================

## หาจำนวนเหรียญทั้งหมด
func get_coin_count() -> int:
	if manual_coin_count > 0:
		return manual_coin_count
	return cost + 1

## คำนวณพลังโจมตีสูงสุดที่เป็นไปได้ (Base + (Power * Coins))
func get_max_power() -> int:
	return base_power + (coin_power * get_coin_count())

## คำนวณพลังต่ำสุดที่เป็นไปได้
func get_min_power() -> int:
	return base_power

# ==========================================
# --- [ New: Support Logic ] ---
# ==========================================
## ฟังก์ชันสำหรับจัดการผลของไอเทม/การ์ด Support (ย้ายมาจาก MainBattle)
func apply_support_effect(user: Node2D, target: Node2D):
	var c_type = str(card_type).to_lower()
	
	match c_type:
		"heal":
			# เช็คว่ามีฟังก์ชันรักษาไหม ถ้าไม่มีให้ใช้ take_damage ติดลบแทน
			if target.has_method("heal_hp"):
				target.heal_hp(heal_amount)
			elif target.has_method("take_damage"):
				target.take_damage(-heal_amount)
			print("💖 [CardSystem] Healed ", target.name, " for ", heal_amount)
			
		"sp gain":
			if user.has_method("gain_sp"):
				user.gain_sp(sp_gain)
			elif "current_sp" in user:
				user.current_sp += sp_gain
			print("⚡ [CardSystem] SP Gained: ", sp_gain)
			
		"draw":
			if user.has_method("draw_one_card"):
				# จั่วตามจำนวนที่กำหนดใน draw_amount
				for i in range(draw_amount):
					user.draw_one_card(0)
			elif user.has_method("draw_new_hand"):
				user.draw_new_hand()
			print("🃏 [CardSystem] Draw Effect Activated")

	# สั่งรีเฟรช UI ของตัวละครหลังจากค่าเปลี่ยน
	if user.has_method("update_status_ui"): 
		user.update_status_ui()
	if target != user and target.has_method("update_status_ui"): 
		target.update_status_ui()
