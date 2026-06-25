extends Resource
class_name AbnormalityPagePool

@export var all_available_pages: Array[AbnormalityPage]

func get_random_selection(count: int = 3) -> Array[AbnormalityPage]:
	var selection = []
	var pool = all_available_pages.duplicate()
	pool.shuffle()
	
	for i in range(min(count, pool.size())):
		selection.append(pool[i])
	return selection
