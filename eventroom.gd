extends TextureRect 

func _on_button_pressed():
	# นายต้องใส่ " " ครอบ path แบบนี้เป๊ะๆ นะ
	var map_path = "res://scenes/ui/Map_system/map.tscn"
	get_tree().change_scene_to_file(map_path)
	print(">>> กลับไปหน้าแผนที่เรียบร้อย")
