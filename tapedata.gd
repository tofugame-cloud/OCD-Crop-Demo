extends Resource
class_name TapeData

@export_group("Basic Info")
@export var tape_name: String = "Tape Name"
@export var description: String = ""
@export var icon: Texture2D

@export_group("Rarity & Type")
@export_enum("KEY", "LOOT") var tape_type: String = "LOOT"
## เพิ่มระดับความหายาก (ใช้สำหรับสีของชื่อ หรืออัตราการดรอป)
@export_enum("Common", "Uncommon", "Rare", "Epic", "Legendary") var rarity: String = "Common"

@export_group("Specific Data")
## ใช้สำหรับ KEY
@export var target_room_id: String = ""

## ใช้สำหรับ LOOT (การ์ดที่สุ่มได้จากเทปนี้)
@export var loot_table: Array[CardData] = []
