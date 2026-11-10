extends SceneTree
# 128 号 第 7 段: read the seg7 test career and print what a step asks about (own test save only)
#   godot --headless --path . -s tests/seg7_probe.gd
func _initialize() -> void:
	Career.path = "user://zp_test_seg7_career.json"
	SaveGame.path = "user://zp_test_seg7_save.json"
	Career.load_or_new()
	print("money ", Career.data.money, " chapter ", Mainline.chapter(), " upgrades ", Career.data.get("upgrades", {}).keys())
	print("parts ", Career.data.get("parts", []).map(func(p): return "%s/%s/%s" % [p.get("tag", ""), p.get("nk", ""), p.get("cls", "")]))
	print("goods ", Career.data.get("goods", []).map(func(p): return "%s/%s/%s" % [p.get("tag", ""), p.get("nk", ""), p.get("cat", "")]))
	print("lights needs ", Repair.find("lights"))
	print("parts_for lights ", Repair.parts_for("lights"))
	print("guide info ", Guide.repair_info("lights"))
	quit(0)
