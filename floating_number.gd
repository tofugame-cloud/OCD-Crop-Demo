extends Label

func _ready():
	# ✅ ปรับขนาดตัวหนังสือ — เปลี่ยนเลขได้ตามต้องการ
	add_theme_font_size_override("font_size", 48)
	
	$AnimationPlayer.play("float_up")
	$AnimationPlayer.animation_finished.connect(_on_animation_finished)

func _on_animation_finished(_anim_name):
	queue_free()
