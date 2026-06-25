extends Resource
class_name StageData

@export var stage_id: String = ""
@export var stage_name: String = ""
@export var position: Vector2
@export var required_keys: Array[String] = []  # เปลี่ยนจาก required_key: String
@export var room_resource: RoomResource
@export var next_stages: Array[StageData] = []
