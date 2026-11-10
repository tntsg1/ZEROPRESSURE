extends SceneTree
# 128 号 第 7 段: the seg7 test career's main line (test save only)
func _initialize() -> void:
	Career.path = "user://zp_test_seg7_career.json"
	SaveGame.path = "user://zp_test_seg7_save.json"
	Career.load_or_new()
	print("port ", Career.data.get("port", {}), " money ", Career.data.money)
	print("chapter ", Mainline.chapter(), " next_open ", Mainline.next_open(), " power_open ", Mainline.power_open())
	for id in Mainline.CHAPTERS:
		print("  ", id, " done ", Mainline.done(id), " hit ", Mainline.hit(id))
	print("step ", Mainline.step())
	quit(0)
