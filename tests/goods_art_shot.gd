extends SceneTree
# 50 号: the four goods pictures, large and small, on the new ground — to see they are clear.
#   tools/run_test.sh tests/goods_art_shot.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var frame := 0


func _initialize() -> void:
	Txt.test_zh = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(page)
	page.add_child(UiSkin.Ground.new())
	var row := HBoxContainer.new()
	row.position = Vector2(60, 120)
	row.add_theme_constant_override("separation", 30)
	page.add_child(row)
	var row2 := HBoxContainer.new()
	row2.position = Vector2(60, 560)
	row2.add_theme_constant_override("separation", 30)
	page.add_child(row2)
	for g in [["mixed_metal", 0], ["ferrous_scrap", 1], ["nonferrous_mix", 0], ["steel_billet", 1]]:
		var big := PanelContainer.new()
		big.add_theme_stylebox_override("panel", UiSkin.glass())
		var pic := UiSkin.Goods.new(str(g[0]), int(g[1]))
		pic.custom_minimum_size = Vector2(400, 250)
		big.add_child(pic)
		row.add_child(big)
		var small := UiSkin.Goods.new(str(g[0]), int(g[1]))
		small.custom_minimum_size = Vector2(160, 100)
		row2.add_child(small)


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 30:
		Cap.save(root, "res://tests/out/goods_art_zh.png")
		print("GOODS ART SHOT")
		return true
	return false
