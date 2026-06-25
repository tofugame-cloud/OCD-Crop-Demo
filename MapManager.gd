# map_manager.gd
extends Control

@export var door_scene: PackedScene
@onready var door_container = $HBoxContainer

var _is_transitioning = false

func _ready():
	spawn_doors()

func spawn_doors():
	# ✅ รอให้ลบเสร็จก่อนด้วย await
	for child in door_container.get_children():
		child.queue_free()
	await get_tree().process_frame  # รอ 1 frame ให้ลบเสร็จ
	
	_is_transitioning = false

	# 🚨 [หักดิบเพื่อเทส] บังคับสร้างเฉพาะประตู Elite เท่านั้น เอาพวก Monster, Event, Rest, Shop ออกไปให้หมด
	var final_list: Array[String] = ["Elite", "Elite", "Elite"] # บังคับให้โผล่มา 3 บานเป็น Elite ล้วนๆ

	print("--- 🚪 [TEST MODE] บังคับสุ่มได้เฉพาะห้อง Elite: ", final_list)

	for i in range(final_list.size()):
		var type_name = final_list[i]
		var door = door_scene.instantiate()
		door_container.add_child(door)        # ✅ add_child ก่อน
		door.name = "Door_" + str(i) + "_" + type_name
		door._room_type = type_name           # ✅ set หลัง — node ready แล้ว setter จะ update visuals
		door.door_selected.connect(_on_door_selected)

func _on_door_selected(type: String):
	print("🚪 door_selected! type = ", type)
	if _is_transitioning:
		return
	_is_transitioning = true
	GameManager.is_battle_won = false
	GameManager.current_room_type = type
	
	# 🚨 แก้ไขตรงนี้เพื่อให้โหลดไฟล์ resource ของ Monster แทน
	match type:
		"Elite":
			# เปลี่ยนจาก elite_room_1 เป็น monster_room_1
			GameManager.current_room = load("res://data/RoomResource/monster_room_1.tres")
			get_tree().change_scene_to_file("res://scenes/main/main_battle.tscn")
		_:
			# เปลี่ยนตรงนี้ด้วยถ้าคุณต้องการเผื่อกรณีอื่นๆ
			GameManager.current_room = load("res://data/RoomResource/monster_room_1.tres")
			get_tree().change_scene_to_file("res://scenes/main/main_battle.tscn")
