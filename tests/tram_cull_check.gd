extends "res://tests/guide_check.gd"
# 97 号 (user 2026-10-28 screenshot: out by the power district, on a curve, the rails vanished): the
# rails were drawn with a transform on draw_mesh, and a mesh so drawn is culled by its own bounds
# untransformed — round the world's origin, far from the power and tug districts. Now the layers
# stand at the port's centre. Out at each district's line, and on the ride from the power district
# to the tug station, the frame with the rails layer and without it must differ: the rails are seen.
#   tools/run_test.sh tests/tram_cull_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_tram_cull_career.json"
	SaveGame.path = "user://zp_test_tram_cull_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _put(at: Vector2, zoom: float) -> void:
	g.cam_override = at
	g.zoom_override = zoom
	g.cam_pos = at
	g.cam_vel = Vector2.ZERO
	g.zoom_now = zoom


# how many pixels the rails layer changes, the camera at `at`
func _seen(at: Vector2, zoom: float) -> int:
	var tr = g.tram
	_put(at, zoom)
	await _frames(3)
	var a := root.get_texture().get_image()
	tr.rails.visible = false
	await _frames(3)
	var b := root.get_texture().get_image()
	tr.rails.visible = true
	await _frames(2)
	var n := 0
	for y in range(0, a.get_height(), 4):
		for x in range(0, a.get_width(), 4):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.06:
				n += 1
	return n


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("TRAM CULL needs a window (tools/run_test.sh)")
		quit()
		return
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "cargo": 1, "power": 1, "tug": 1}
	Career.data.tram_found = ["ring", "power", "tug", "process", "trade", "cargo"]
	Career.data.seen = {"port_walk_started": true}
	Career.save()
	await _spawn()
	var tr = g.tram
	for i in 120:
		if tr._job == null and not tr._track.is_empty():
			break
		await _frames(1)
	check(not tr._track.is_empty(), "the track is built")
	# each district's line halfway along, far from the world's origin
	for z in ["power", "tug", "process", "trade", "cargo", "salvage"]:
		var lg: Array = Tram._leg(z)
		var mid: Vector2 = (lg[0] as Vector2).lerp(lg[-1], 0.5)
		var px: int = await _seen(mid, 0.8)
		check(px > 300, "%s's line, %.0f m from the origin: the rails are seen (%d px of them)" % [z, mid.length() / Geom.M, px])
	# the ride in the user's screenshot: power → tug, the camera on the train through the curves
	g.drone.global_position = Tram.station_at("power")
	await _frames(2)
	tr.call_to("power", "tug")
	var worst := 1 << 30
	var looked := 0
	var f := 0
	while tr.phase != "" and f < 60 * 60:
		await _frames(1)
		f += 1
		if tr.phase == "ride" and f % 45 == 0:
			var px: int = await _seen(tr.position_px, 0.55)
			worst = mini(worst, px)
			looked += 1
	check(looked >= 4 and worst > 300, "riding power → tug, %d looks at the train: the rails always seen (fewest %d px)" % [looked, worst])
	g.queue_free()
	await _frames(4)
	print("TRAM CULL %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
