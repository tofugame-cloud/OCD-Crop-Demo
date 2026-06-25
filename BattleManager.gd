extends Node

var current_enemy_data: EnemyData

# ฟังก์ชันคำนวณตัวคูณ (ใส่ไว้ตรงนี้เลย)
func get_total_multiplier(card_data: CardData, target) -> float:
	var mult = 1.0
	
	# ดึงค่าต้านทานจาก target (ไม่ว่าจะเป็น EmployeeData หรือ EnemyData)
	# เราใช้ .get() เพื่อป้องกัน Error ถ้าเผลอไม่ได้ใส่ตัวแปรนั้นใน .tres
	
	# 1. ประเภทอาวุธ
	mult *= target.get("res_slash", 1.0) if card_data.dmg_type == "Slash" else 1.0
	mult *= target.get("res_pierce", 1.0) if card_data.dmg_type == "Pierce" else 1.0
	mult *= target.get("res_blunt", 1.0) if card_data.dmg_type == "Blunt" else 1.0
	
	# 2. ประเภทพลัง (กายภาพ/จิตใจ)
	mult *= target.get("res_physical", 1.0) if card_data.dmg_source == "Physical" else 1.0
	mult *= target.get("res_mental", 1.0) if card_data.dmg_source == "Mental" else 1.0
	
	return mult

# ฟังก์ชันสำหรับเรียกใช้ง่ายๆ ตอนตี
func calculate_damage(card_data: CardData, target) -> int:
	var mult = get_total_multiplier(card_data, target)
	var final_dmg = int(card_data.base_power * mult)
	return final_dmg
