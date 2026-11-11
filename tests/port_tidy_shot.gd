extends SceneTree
# 港区外观整洁版（极简体块, PortArt.hull_style 1）: each district's outside, the old picture and the
# new one (Pal.solid) side by side, close and the whole port far. Own test saves only.
#   tools/run_test.sh tests/port_tidy_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")
const ZONES := ["power", "process", "trade", "cargo", "tug", "salvage"]


func _initialize() -> void:
	Career.path = "user://zp_test_porttidy_career.json"
	SaveGame.path = "user://zp_test_porttidy_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _redraw_all(n: Node) -> void:
	if n is CanvasItem:
		(n as CanvasItem).queue_redraw()
	for c in n.get_children():
		_redraw_all(c)


func _run() -> void:
	Txt.zh = true
	Backdrop.t_fixed = 3.0
	Career.data = Career.fresh()
	Career.data.port = {"power": 2, "salvage": 1, "process": 2, "tug": 1, "trade": 1, "cargo": 1, "ring": 0}
	Career.save()
	Game.contract = {}
	Game.start_ship = "gr7"
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 10: await process_frame
	g.job = {"id": "port-tidy", "ship": "gr7"}
	for i in 50: await process_frame
	g.tutorial = null
	g.drone.global_position = Vector2(-20, -20) * Geom.M
	var views: Array = []
	for z in ZONES:
		views.append([z, 0.2, PortStructure.box(z).get_center()])
	views.append(["port", 0.035, PortStructure.centre()])
	for v in views:
		for look in ["old", "new"]:
			Pal.solid = look == "new"
			_redraw_all(g)
			for i in 40:
				g.cam_override = v[2]; g.zoom_override = v[1]; g.zoom_now = v[1]; g.cam_pos = v[2]
				await process_frame
			Cap.save(root, "res://tests/out/porttidy_%s_%s.png" % [v[0], look])
		print("shot %s" % v[0])
	Pal.solid = true
	g.queue_free()
	for i in 6: await process_frame
	quit(0)
