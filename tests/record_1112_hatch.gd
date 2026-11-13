extends "res://tests/hatch_free_check.gd"
# 2026-11-12 update video: an open hatch cut free and taken away — the hatch opened, the laser on its
# hinges, it comes loose where it stood, the grapple takes it. BELT's first door; test saves only.
#   tools/run_test.sh tests/record_1112_hatch.gd --write-movie G:/temp/zp_upd1112/hatch.avi --fixed-fps 60 -- belt
var tick: Node


func _initialize() -> void:
	super()
	tick = preload("res://tests/rec_tick_1112.gd").new()
	root.add_child(tick)


func _park(at: Vector2) -> void:
	g.drone.global_position = at
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()


func _run() -> void:
	Txt.zh = true
	var a := OS.get_cmdline_user_args()
	await _game(a[0] if a.size() > 0 else "belt")
	var doors: Array = W.order.map(func(i): return W.pieces[i]).filter(func(p): return p.door and not p.gone and p.body == null and p.open_dir.length() > 4.0)
	if doors.is_empty():
		print("HATCH no door")
		quit(1)
		return
	var d = doors[0]
	for rn in W.rooms:
		W.reveal(rn, Geom.centroid(W.world_poly(d)))
	var c := _inside(d)
	g.cam_override = c
	g.zoom_override = 1.3
	var spot := c + Vector2(0, -3.0) * Geom.M
	_park(spot)
	await _frames(40)
	tick.keep(true, "hatch")
	await _frames(40)
	d.door_open = true
	for i in 70:
		_park(spot)
		await process_frame
	# the beam on each hinge, then cut where it is drawn
	g.tools.set_tool(2, true)
	for j in W.joints_of(d):
		var at := _jdrawn(j)
		g.bot.aim = at
		g.bot.lmb = true
		for i in 40:
			_park(spot)
			await process_frame
	g.bot.lmb = false
	_cut_hinges(d)
	for i in 50:
		_park(spot)
		await process_frame
	print("HATCH loose %s" % str(d.body != null))
	# the grapple takes it and the drone tows it off
	if d.body != null:
		g.tools.set_tool(3, true)
		g.bot.aim = _inside(d)
		g.bot.lmb = true
		for i in 30:
			_park(spot)
			await process_frame
		for i in 150:
			spot += Vector2(0.02, -0.03) * Geom.M
			_park(spot)
			g.cam_override = g.cam_override.lerp(spot, 0.03)
			await process_frame
		g.bot.lmb = false
	await _frames(40)
	tick.keep(false, "end")
	quit()
