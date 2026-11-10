extends SceneTree
# 128 号 第 7 段: the furnace and the queue of the seg7 test career (test save only)
func _initialize() -> void:
	Career.path = "user://zp_test_seg7_career.json"
	SaveGame.path = "user://zp_test_seg7_save.json"
	Career.load_or_new()
	print("heat ", Career.data.get("industrial_heat", {}))
	print("queue ", ProcessQueue.open_entries())
	print("port ", Career.data.get("port", {}), " chapter ", Mainline.chapter())
	print("grid cap MW ", Grid.capacity())
	print("raw ", StoreBook.raw_stock())
	quit(0)
