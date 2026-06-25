# map_manager
extends Control

@export var stage_node_scene: PackedScene
@export var all_stages: Array[StageData]

@onready var stages_container = $ScrollContainer/StagesContainer
@onready var stage_key_pass_ui = $stage_key_pass

var spawned_nodes = {}

func _ready():
	print("🎬 ===== [MAP MANAGER READY] เริ่มต้นระบบแผนที่ Ruina =====")
	
	# ดีบัคความพร้อมของ Containers
	if stages_container:
		print("📦 พบโหนด StagesContainer เรียบร้อย ขนาดโหนด: ", stages_container.size)
	else:
		print("❌ ไม่พบโหนด StagesContainer! กรุณาเช็คการลากหรือตั้งชื่อโหนดลูกในหน้าหลัก")
		
	# ล้างปุ่มเก่าที่อาจหลงค้างอยู่
	var old_children_count = stages_container.get_children().size()
	for child in stages_container.get_children():
		child.queue_free()
	if old_children_count > 0:
		print("🧹 เคลียร์โหนดขยะเก่าออกจากแผนที่สำเร็จ: ", old_children_count, " โหนด")
		
	await get_tree().process_frame
	generate_ruina_map()

func generate_ruina_map():
	if all_stages.size() == 0:
		print("⚠️ [MAP ERROR] อาร์เรย์ all_stages ว่างเปล่า!")
		return
	if stage_node_scene == null:
		print("⚠️ [MAP ERROR] ไม่มีไฟล์ซีนต้นแบบปุ่ม!")
		return

	print("🏗️ [STEP 1] กำลังเริ่มสปอว์นปุ่มด่านทั้งหมดจํานวน: ", all_stages.size(), " ด่าน")
	for stage_data in all_stages:
		if stage_data == null: continue
		
		var node = stage_node_scene.instantiate()
		stages_container.add_child(node)
		node.setup(stage_data)
		node.name = stage_data.stage_id
		
		# 🌟 [เพิ่มจุดที่ 1]: เชื่อมต่อสัญญาณเมื่อปุ่มด่านขาวๆ โดนกด ให้มาเรียกฟังก์ชันเปิด UI ด้านล่าง
		if node.has_signal("stage_clicked"):
			node.stage_clicked.connect(_on_stage_node_clicked)
		
		spawned_nodes[stage_data.stage_id] = node
		print("   ✅ สปอว์นปุ่มด่านสำเร็จ [", stage_data.stage_id, "] วางไว้ที่พิกัด: ", node.position)

	# 🌟 จุดสำคัญ: รอให้โหนดลูกทั้งหมดถูกวาดและคำนวณ Layout (Size/Position) ในเฟรมจริงให้เสร็จก่อน
	await get_tree().process_frame
	await get_tree().process_frame # รอซ้ำ 2 เฟรมเพื่อความชัวร์ในระบบ UI ของ Godot 4

	print("🔗 [STEP 2] กำลังเริ่มคำนวณและวาดเส้นเชื่อมโยงระหว่างด่าน...")
	var line_count = 0
	for stage_data in all_stages:
		if stage_data == null or not spawned_nodes.has(stage_data.stage_id): continue
		var current_node = spawned_nodes[stage_data.stage_id]
		
		for next_stage in stage_data.next_stages:
			if next_stage == null: continue
			if not spawned_nodes.has(next_stage.stage_id): continue
				
			var next_node = spawned_nodes[next_stage.stage_id]
			
			var line = Line2D.new()
			stages_container.add_child(line)
			stages_container.move_child(line, 0) # ซ่อนเส้นไว้เลเยอร์หลังปุ่ม
			
			line.width = 5.0
			line.default_color = Color(0.5, 0.5, 0.5, 0.7)
			line.joint_mode = Line2D.LINE_JOINT_ROUND
			
			# ตอนนี้ค่า .size จะไม่เป็น 0 หรือหดตัวแล้วเพราะผ่านการรีเฟรชเฟรม UI มาแล้ว
			var current_center = current_node.size / 2
			var next_center = next_node.size / 2
			
			var start_pos = current_node.position + current_center
			var end_pos = next_node.position + next_center
			
			line.add_point(start_pos)
			line.add_point(end_pos)
			line_count += 1

# 🌟 [เพิ่มจุดที่ 2]: ฟังก์ชันรับสัญญาณมารองรับข้อมูลด่าน และสั่งเด้งหน้าต่าง UI ขวามือ
func _on_stage_node_clicked(stage_data: StageData):
	print("🖱️ [MAP] ผู้เล่นกดเลือกด่าน: ", stage_data.stage_id)
	if stage_key_pass_ui:
		# ส่งข้อมูลด่านไปให้หน้าต่าง UI ประมวลผลและเด้งขึ้นมา
		stage_key_pass_ui.display_stage_info(stage_data)
	else:
		print("❌ ไม่พบโหนด stage_key_pass_ui ในหน้าจอ! กรุณาเช็คการลากวางโหนด")
