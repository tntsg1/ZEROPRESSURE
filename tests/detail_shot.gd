extends SceneTree
# 设备精细画法第二批: each new drawing on its ship, close up, the old picture and the cutaway one
# side by side (same run, same camera). Rooms opened so the machines show. Own test saves only.
#   tools/run_test.sh tests/detail_shot.gd --fixed-fps 60 -- ship=ps12 SUITE-1 [TAG ...]
const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_detail_career.json"
	SaveGame.path = "user://zp_test_detail_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var sid := "ps12"
	var tags: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ship="):
			sid = a.substr(5)
		else:
			tags.append(a)
	Txt.zh = true
	Backdrop.t_fixed = 3.0
	Career.data = Career.fresh()
	Career.data.port = {"power": 2, "salvage": 1, "process": 2, "tug": 1, "trade": 1, "cargo": 1, "ring": 0}
	Career.save()
	Game.contract = {}
	Game.start_ship = sid
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(10)
	g.job = {"id": "detail-shot", "ship": sid}
	await _frames(50)
	g.tutorial = null
	var w = g.world
	for n in w.rooms:
		w.rooms[n].revealed = true
		w.rooms[n].reveal_t = 1.0
	for t in tags:
		var p = w.tag(str(t))
		if p == null:
			print("no %s" % t)
			continue
		var bb := Geom.bbox(p.poly)
		var z := clampf(minf(1920.0 * 0.35 / bb.size.x, 1080.0 * 0.45 / bb.size.y), 0.6, 2.6)
		for look in ["old", "new"]:
			Pal.solid = look == "new"
			w.redraw_all(true)
			w.dirty_back = true
			w.cover_layer.queue_redraw()
			w.back_layer.queue_redraw()
			w.light_layer.queue_redraw()
			for i in 24:
				g.cam_override = bb.get_center()
				g.zoom_override = z
				g.zoom_now = z
				g.cam_pos = bb.get_center()
				g.drone.global_position = bb.get_center() + Vector2(-26, -14) * Geom.M
				g.drone.linear_velocity = Vector2.ZERO
				await process_frame
			Cap.save(root, "res://tests/out/detail_%s_%s_%s.png" % [sid, str(t), look])
		print("shot %s" % t)
	Pal.solid = true
	g.queue_free()
	await _frames(6)
	quit(0)
