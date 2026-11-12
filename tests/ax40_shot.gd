extends SceneTree
# AX-40 逆火 screenshots (scripts/antimatter.gd, scripts/annihilation.gd): the ship in a career berth
# with its chain marked, the wrench at the main switch (the chain flares), the portable supply on
# the trap (dual supply), the trap at the antimatter cradle; then, on a second run, the main switch
# thrown with nothing on the trap: the annihilation on the real ship, its frame times.
# Own test saves only.
#   tools/run_test.sh tests/ax40_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")

var frames: Array = []


func _initialize() -> void:
	Career.path = "user://zp_test_ax40shot_career.json"
	SaveGame.path = "user://zp_test_ax40shot_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _game():
	Career.data = Career.fresh()
	Career.data.port = {"power": 2, "salvage": 1, "process": 2, "tug": 1, "trade": 1, "cargo": 1, "ring": 0}
	Career.save()
	Game.contract = {}
	Game.start_ship = "ax40"
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 10: await process_frame
	g.job = {"id": "ax40-shot", "ship": "ax40"}
	for i in 60: await process_frame
	return g


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _park(g, at: Vector2) -> void:
	g.drone.global_position = at
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()


func _run() -> void:
	Txt.zh = true
	var g = null
	var a = null
	if "anni_only" in OS.get_cmdline_user_args():
		await _anni()
		return
	g = await _game()
	a = g.anti
	var tr = a.trap
	var tc: Vector2 = g.world.frame(tr) * Geom.centroid(tr.poly)
	# the whole ship, its chain marked
	g.cam_override = tc + Vector2(0, 0)
	g.zoom_override = 1080.0 / (24.0 * Geom.M)
	_park(g, tc + Vector2(-9.0, -1.0) * Geom.M)
	for i in 40: await process_frame
	Cap.save(root, "res://tests/out/ax40_s1_ship.png")
	# open it up so the inside shows (the rooms vented, the doors open) — as the safe path does
	for id in ["G-B", "G-T", "G-E"]:
		g.do_hose(_ctrl(g, id))
	for i in 60 * 40:
		await process_frame
		if g.sys.P("B") < 5.0 and g.sys.P("T") < 5.0 and g.sys.P("E") < 5.0:
			break
	for id in ["HT-B", "D-0", "HT-E"]:
		g.do_wrench(_ctrl(g, id))
		for i in 30: await process_frame
	for i in 60: await process_frame
	# the wrench at the main switch: the chain flares
	var km: Vector2 = g.world.ctrl_world(g.world.ctrls["K-M"])
	g.tools.tool = 2
	g.bot.aim = km + Vector2(18, -6)
	g.cam_override = (km + tc) * 0.5
	g.zoom_override = 1080.0 / (20.0 * Geom.M)
	_park(g, km + Vector2(-2.5, -2.0) * Geom.M)
	for i in 20: await process_frame
	Cap.save(root, "res://tests/out/ax40_s2_warn.png")
	# the portable supply on the trap: taking up the load, then dual supply
	g.bot.aim = tc + Vector2(0, -8.0) * Geom.M
	g.tools.tool = 1
	g.do_measure(_ctrl(g, "CONF"))
	g.gear.act({"kind": "place", "type": "confine", "piece": tr, "pos": tc + Vector2(0, -2.2) * Geom.M})
	g.cam_override = tc
	g.zoom_override = 1080.0 / (11.0 * Geom.M)
	_park(g, tc + Vector2(-4.0, -3.0) * Geom.M)
	for i in 45: await process_frame
	Cap.save(root, "res://tests/out/ax40_s3_taking_over.png")
	for i in 120: await process_frame
	g.do_measure(_ctrl(g, "CONF"))
	for i in 10: await process_frame
	Cap.save(root, "res://tests/out/ax40_s4_dual.png")
	# the bus off, the trap unbolted, at the cradle
	g.do_wrench(_ctrl(g, "K-M"))
	for i in 30: await process_frame
	for j in g.world.joints_of(tr).duplicate():
		if j.type in ["bolt", "lock"]:
			g.do_wrench({"kind": "joint", "joint": j, "pos": g.world.joint_world(j)})
			await process_frame
	for l in g.world.lines_of(tr).duplicate():
		var end := 0 if l.a == tr.id else 1
		g.do_wrench({"kind": "connector", "line": l, "end": end, "pos": g.world.line_end_world(l, end)})
	for i in 20: await process_frame
	var mouth: Vector2 = Dock.zpos("anti")
	var b = tr.body
	g.cam_override = mouth + Vector2(0, 4.0) * Geom.M
	g.zoom_override = 1080.0 / (24.0 * Geom.M)
	for i in 50:
		b.global_position = mouth + Vector2(0, 3.2) * Geom.M - b.global_transform.basis_xform(b.center_of_mass)
		b.linear_velocity = Vector2.ZERO
		b.angular_velocity = 0.0
		await process_frame
	Cap.save(root, "res://tests/out/ax40_s5_cradle.png")
	g.queue_free()
	for i in 240: await process_frame

	await _anni()


# the second run: the main switch thrown with nothing on the trap; frame times by phase, GPU
func _anni() -> void:
	var by := {}
	var gpu: Array = []
	var g = await _game()
	var a
	var tr
	var tc: Vector2
	a = g.anti
	tr = a.trap
	tc = g.world.frame(tr) * Geom.centroid(tr.poly)
	g.cam_override = tc
	g.zoom_override = 1080.0 / (22.0 * Geom.M)
	for i in 30: await process_frame
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var base: Array = []
	for i in 180:
		var t0 := Time.get_ticks_usec()
		await process_frame
		base.append((Time.get_ticks_usec() - t0) / 1000.0)
	base.sort()
	print("AX40 BASE before the switch: p50 %.2f p95 %.2f max %.2f" % [base[base.size() / 2], base[int(base.size() * 0.95)], base[base.size() - 1]])
	g.do_wrench(_ctrl(g, "K-M"))
	while g.nuke == null:
		await process_frame
	var nk = g.nuke
	var shots := [[0.3, "a_unbind"], [0.95, "b_collapse"], [1.21, "c_negative"], [1.35, "d_star"], [2.2, "e_spectrum"], [3.3, "f_spectrum_late"], [4.8, "g_afterglow"], [7.0, "h_embers"], [10.0, "i_card"]]
	for sh in shots:
		while nk.t < float(sh[0]) and not nk.finished:
			var t0 := Time.get_ticks_usec()
			await process_frame
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			frames.append(ms)
			var ph := "unbind" if nk.t < 0.6 else ("collapse" if nk.t < 1.2 else ("bang" if nk.t < 1.5 else ("spectrum" if nk.t < 4.0 else ("afterglow" if nk.t < 7.6 else "card"))))
			if not by.has(ph):
				by[ph] = []
			by[ph].append(ms)
			var vp := root.get_viewport_rid()
			gpu.append([RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp)])
		Cap.save(root, "res://tests/out/ax40_s6_%s.png" % sh[1])
	var ft: Array = frames.filter(func(x): return x < 300.0)
	ft.sort()
	var avg := 0.0
	for x in ft:
		avg += x
	avg /= maxf(1.0, ft.size())
	print("AX40 ANNI FRAMES n %d avg %.2f p95 %.2f p99 %.2f max %.2f" % [ft.size(), avg, ft[int(ft.size() * 0.95)], ft[int(ft.size() * 0.99)], ft[ft.size() - 1]])
	for ph in by:
		var q: Array = by[ph]
		q.sort()
		print("  %s n %d p50 %.2f p95 %.2f max %.2f" % [ph, q.size(), q[q.size() / 2], q[int(q.size() * 0.95)], q[q.size() - 1]])
	for col in [0, 1]:
		var xs: Array = gpu.map(func(d): return d[col])
		xs.sort()
		print("  %s p50 %.2f p95 %.2f max %.2f ms" % [["render cpu", "gpu"][col], xs[xs.size() / 2], xs[int(xs.size() * 0.95)], xs[xs.size() - 1]])
	g.queue_free()
	for i in 240: await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.path))
	quit()
