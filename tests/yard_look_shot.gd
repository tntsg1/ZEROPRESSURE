extends SceneTree
# 工业剖面 · 船坞与港区样片: the same camera, the old picture and the cutaway one (Pal.solid) side by
# side, for the berth (empty and with GR-7 in it) and the processing district. Own test saves only.
#   tools/run_test.sh tests/yard_look_shot.gd --fixed-fps 60 -- [ship=gr7] [only=berth|process]
const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_yardlook_career.json"
	SaveGame.path = "user://zp_test_yardlook_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _redraw_all(n: Node) -> void:
	if n is CanvasItem:
		(n as CanvasItem).queue_redraw()
	for c in n.get_children():
		_redraw_all(c)


func _hold(g, at: Vector2, z: float, n: int) -> void:
	for i in n:
		g.cam_override = at
		g.zoom_override = z
		g.zoom_now = z
		g.cam_pos = at
		await process_frame


func _run() -> void:
	var sid := "gr7"
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ship="):
			sid = a.substr(5)
		elif a.begins_with("only="):
			only = a.substr(5)
	Txt.zh = true
	Backdrop.t_fixed = 3.0
	Career.data = Career.fresh()
	Career.data.port = {"power": 2, "salvage": 1, "process": 2, "tug": 1, "trade": 1, "cargo": 1, "ring": 0}
	Career.save()
	Game.contract = {}
	Game.start_ship = sid
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": {"crane": true}}
	root.add_child(g)
	await _frames(10)
	g.job = {"id": "yard-look", "ship": sid}
	await _frames(50)
	g.tutorial = null
	var M := Geom.M
	g.drone.global_position = Vector2(-20, -20) * M
	var views: Array = []
	if only != "process":
		views.append(["berth_near", 0.9, Vector2(4.0, 4.0) * M])
		views.append(["berth_tower", 0.9, Vector2(-4.0, -2.0) * M])
		views.append(["berth_whole", 0.3, Dock.centre() * M])
	if only != "berth":
		var pb: Rect2 = PortStructure.box("process") if ClassDB.class_exists("PortStructure") or true else Rect2()
		views.append(["process_whole", minf(1920.0 * 0.9 / pb.size.x, 1080.0 * 0.85 / pb.size.y) * 0.3, pb.get_center()])
		views.append(["process_near", 0.3, pb.get_center()])
	for v in views:
		for look in ["old", "new"]:
			Pal.solid = look == "new"
			_redraw_all(g)
			g.world.redraw_all(true)
			await _hold(g, v[2], v[1], 30)
			Cap.save(root, "res://tests/out/yard_%s_%s_%s.png" % [sid, v[0], look])
		print("shot %s" % v[0])
	Pal.solid = true
	g.queue_free()
	await _frames(6)
	quit(0)
