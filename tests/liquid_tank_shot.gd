extends SceneTree
# A big tank cut open (user 2026-10-27: "一整团液体喷出来……是一整个"): RO-128's ballast tank
# (2.4 m³ of water) cut right across with a kerf. Screenshots at 0.5, 1.5, 3 and 6 s; how many
# globules and how big the biggest; frame times while it pours. Own test saves only.
#   tools/run_test.sh tests/liquid_tank_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_tankshot_career.json"
	SaveGame.path = "user://zp_test_tankshot_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "ro128"
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 40: await process_frame
	for n in g.world.rooms:
		g.world.reveal(n, g.world.rooms[n].bbox.get_center())
	var p = g.world.tag("BT-1")
	var bb: Rect2 = Geom.bbox(g.world.world_poly(p))
	var c := bb.get_center()
	print("BT-1 ", bb.position / Geom.M, " ", bb.size / Geom.M, " water ", g.sys.fvol.ballast.amount)
	g.cam_override = c
	g.zoom_override = clampf(700.0 / maxf(bb.size.x, bb.size.y), 0.15, 1.0)
	for i in 70: await process_frame
	# a kerf right across it, a little past each side
	var a := c - Vector2(bb.size.x * 0.6, 0.0)
	var b := c + Vector2(bb.size.x * 0.6, 0.0)
	g.cut_kerf(p, PackedVector2Array([a, b]))
	var lq = g.liquids
	var t := 0.0
	var frames: Array = []
	var shots := [[0.5, "a"], [1.5, "b"], [3.0, "c"], [6.0, "d"]]
	while not shots.is_empty():
		var t0 := Time.get_ticks_usec()
		await process_frame
		frames.append((Time.get_ticks_usec() - t0) / 1000.0)
		t += 1.0 / 60.0
		if t >= float(shots[0][0]):
			var big := 0.0
			for bl in lq.blobs:
				big = maxf(big, float(bl.vol))
			print("t %.1f s: %d globules, biggest %.3f m³, adrift %.3f m³, left in the tank %.3f m³" % [t, lq.count(), big, lq.total_volume(), g.sys.fvol.ballast.amount])
			if DisplayServer.get_name() != "headless":
				Cap.save(root, "res://tests/out/liquid_tank_%s_zh.png" % shots[0][1])
			shots.pop_front()
	frames.sort()
	print("TANK FRAMES avg %.1f p95 %.1f max %.1f ms" % [frames.reduce(func(s, x): return s + x, 0.0) / frames.size(), frames[int(frames.size() * 0.95)], frames[frames.size() - 1]])
	quit()
