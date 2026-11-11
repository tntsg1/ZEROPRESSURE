extends "res://tests/recoil_check.gd"
# A flywheel's square vacuum housing stays put on the ship; only the wheel inside turns
# (user 2026-11-10: "它整个都在转，不只有里面的东西在转，它整个方形也在转").
#   1 MD-160 FW-1 at 20,000 rpm: two frames a moment apart, the band along the housing's
#     outline is the same picture (the housing did not turn), the disc inside is not (the
#     wheel did)
#   2 a wheel torn loose still turning: the housing is flung and tumbles slowly (the bearings'
#     drag), nowhere near the wheel's own speed
# tools/run_test.sh tests/flywheel_casing_check.gd   (writes tests/out/flywheel_casing_*.png)


func _initialize() -> void:
	SaveGame.path = "user://zp_test_flycase_save.json"
	SaveGame.allow_test = true
	Career.path = "user://zp_test_flycase_career.json"
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _cam(g, at: Vector2, zoom: float) -> void:
	g.cam_override = at
	g.cam_pos = at
	g.cam_vel = Vector2.ZERO
	g.zoom_now = zoom
	g.zoom_override = zoom
	for i in 4:
		await process_frame


func _grab() -> Image:
	await process_frame
	return root.get_texture().get_image()


# mean difference of two shots over the pixels where test(px) holds
func _diff(a: Image, b: Image, test: Callable) -> float:
	var sum := 0.0
	var n := 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			if not test.call(Vector2(x, y)):
				continue
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			sum += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
			n += 1
	return sum / maxf(1.0, n)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out"))
	print("flywheel: 1 the housing stays put while the wheel turns (the energy course's square housing)")
	var g = await _game("sp_energy")
	var p = g.world.tag("FW-1")
	check(p != null and g.flywheel.spinning("FW-1"), "FW-1 at %.0f rpm" % float(g.flywheel.rpm.get("FW-1", 0.0)))
	var c := _centre(g, p)
	g.world.reveal(g.world.room_at(c), c)
	g.drone.global_position = c + Vector2(0, -12.0 * M)
	# the course's opening card read and put away
	for n in g.find_children("*", "", true, false):
		if n.get_script() == load("res://scripts/tutorial_hud.gd"):
			n.intro = 2
			n.intro_k = 0.0
	var zoom := 4.0
	await _cam(g, c, zoom)
	await _frames(120)
	var a := await _grab()
	a.save_png(ProjectSettings.globalize_path("res://tests/out/flywheel_casing_a.png"))
	await _frames(17)
	var b := await _grab()
	b.save_png(ProjectSettings.globalize_path("res://tests/out/flywheel_casing_b.png"))
	# the housing on screen: its outline's band, and the disc the wheel turns in
	var vp: Vector2 = Vector2(a.get_width(), a.get_height())
	var xf: Transform2D = g.get_viewport().get_canvas_transform()
	var poly: PackedVector2Array = xf * g.world.world_poly(p)
	var bb := Geom.bbox(poly)
	var half: float = minf(bb.size.x, bb.size.y) * 0.5
	var mid := bb.get_center()
	print("  housing on screen %s, %.0f px across (viewport %s)" % [bb, half * 2.0, vp])
	# the housing's corners (well outside the wheel's disc), against a strip of plain
	# background beside it (the camera feed's grain moves every frame anyway)
	var band := func(q: Vector2) -> bool:
		return q.distance_to(mid) > half * 1.12 and (Geometry2D.is_point_in_polygon(q, poly) or Geom.dist_to_boundary(q, poly) < 8.0)
	var disc := func(q: Vector2) -> bool:
		return q.distance_to(mid) < half * 0.85
	var bg := func(q: Vector2) -> bool:
		return q.x > bb.end.x + 30.0 and q.x < bb.end.x + 120.0 and q.y > bb.position.y and q.y < bb.end.y
	var d_band := _diff(a, b, band)
	var d_disc := _diff(a, b, disc)
	var d_bg := _diff(a, b, bg)
	print("  change between the shots: housing corners %.4f, wheel disc %.4f, background %.4f" % [d_band, d_disc, d_bg])
	check(d_disc > d_bg * 3.0 + 0.002, "the wheel inside turned (%.4f)" % d_disc)
	check(d_band < d_bg * 2.0 + 0.003, "the housing's corners did not move (%.4f, background %.4f)" % [d_band, d_bg])
	await _done(g)

	print("flywheel: 2 torn loose still turning: the housing tumbles slowly")
	g = await _game("md160")
	p = g.world.tag("FW-1")
	for j in g.world.joints_of(p).duplicate():
		g.world.kill_joint(j)
	for l in g.world.lines_of(p).duplicate():
		g.world.kill_line(l)
	await _frames(6)
	check(g.flywheel.loose.has("FW-1") and p.body != null, "FW-1 let go at 20,000 rpm: torn loose")
	var av: float = absf(p.body.angular_velocity) if p.body != null else 0.0
	check(av > 0.5 and av <= 3.0, "its housing tumbles at %.1f rad/s (the wheel inside turns at %.0f rad/s)" % [av, 20000.0 * TAU / 60.0])
	await _cam(g, _centre(g, p), 2.0)
	var img := await _grab()
	img.save_png(ProjectSettings.globalize_path("res://tests/out/flywheel_casing_loose.png"))
	await _done(g)
	print("flywheel casing: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
	quit(1 if fails > 0 else 0)
