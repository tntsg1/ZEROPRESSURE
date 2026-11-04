extends SceneTree
# 118 号: what the depth layer is doing at the berth (a probe). Own test saves only.
func _initialize() -> void:
	Career.path = "user://zp_test_depth_career.json"
	SaveGame.path = "user://zp_test_depth_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()

func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.port = {"power": 2, "salvage": 1, "process": 2, "tug": 1, "trade": 1, "cargo": 1, "ring": 0}
	Career.save()
	Game.contract = {}
	Game.start_ship = "jd38"
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 60: await process_frame
	var d = g.dock.depth_fx
	print("k=%.2f applied=%.2f wash.vis=%s group.vis=%s sil=%s z=%d dock.vis=%s lights=%s soft=%s" % [d.k, d._applied, d.wash.is_visible_in_tree(), d.group.is_visible_in_tree(), d.sil.global_transform, d.z_index, g.dock.visible, g.has_upgrade("lights"), Look._soft != null])
	print("children of dock: ", g.dock.get_children().map(func(n): return n.name))
	print("world pos ", g.world.global_position, " order ", g.world.order.size(), " wall ", d._wall_rect())
	quit(0)
