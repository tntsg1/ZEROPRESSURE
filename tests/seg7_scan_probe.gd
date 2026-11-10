extends SceneTree
# 128 号 第 7 段: the seg7 test career (restored snapshot): sweep sector 0 as the first sweep and print it
func _initialize() -> void:
	Career.path = "user://zp_test_seg7_career.json"
	SaveGame.path = "user://zp_test_seg7_save.json"
	Career.load_or_new()
	print("first_tow seen ", Career.data.get("seen", {}).get("first_tow", false), " sectors ", Scan.data().sectors.keys(), " n ", Scan.data().n)
	var sigs: Array = Scan._sweep(0)
	for s in sigs:
		print("  ", s.id, " ", s.kind, " ", s.get("offer", {}).get("ship", ""), " ", s.get("what", ""))
	quit(0)
