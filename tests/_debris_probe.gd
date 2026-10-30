extends "res://tests/perf_probe.gd"
# temporary (60 FPS work): where a frame goes with 250 loose plates in the berth


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Txt.zh = true
	if "look=0" in OS.get_cmdline_user_args():
		Look.on = false
	Game.contract = {}
	Game.start_ship = "tug"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": {"skill_grapple_multi": 3} if "ropes" in OS.get_cmdline_user_args() else {}}
	root.add_child(g)
	await _frames(60)
	var cc: Vector2 = Dock.BAY * Geom.M + Vector2(26.0, 2.0) * Geom.M
	var mats := ["steel", "titanium", "aluminium", "composite", "ceramic"]
	var n := int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 and OS.get_cmdline_user_args()[0].is_valid_int() else 250
	for i in n:
		var at := cc + Vector2((i % 25) * 0.85 * Geom.M - 10.6 * Geom.M, (i / 25) * 1.0 * Geom.M - 5.0 * Geom.M)
		var h := Vector2(14, 10)
		g.world.add_piece("plate", PackedVector2Array([at - h, at + Vector2(h.x, -h.y), at + h, at + Vector2(-h.x, h.y)]), {"mat": mats[i % 5], "mass": 0.2})
	g.world.dirty_links = true
	await _frames(200)
	if "ropes" in OS.get_cmdline_user_args():
		g.tools.tool = 3
		g.tools.toggle_multi(false)
		g.drone.global_position = cc + Vector2(0, 7.0 * Geom.M)
		g.bot.aim = cc + Vector2(0, -1.0 * Geom.M)
		g.bot.lmb = true
		await _frames(3)
		for i in 30:
			var p := cc + Vector2(i * 0.8 * Geom.M - 12.0 * Geom.M, 9.0 * Geom.M)
			g.world.rope_fx.snap(PackedVector2Array([p, p + Vector2(0, 3.0 * Geom.M), p + Vector2(0, 6.0 * Geom.M)]), p + Vector2(0, 3.0 * Geom.M), 0.8)
		g.bot.move = Vector2(0.5, 0)
	World.prof = {}
	var rope_us := 0
	var phys_ms := 0.0
	var proc_ms := 0.0
	var pairs := 0.0
	World.acc_sum = {}
	World.acc_n = {}
	for phase in ["all"]:
		match phase:
			"no_hud":
				g.hud.visible = false
			"no_minimap":
				for ch in g.hud.get_children():
					if ch.get_script() != null and str(ch.get_script().resource_path).ends_with("minimap.gd"):
						ch.visible = false
			"no_world_draw":
				g.world.visible = false
			"no_look":
				Look.on = false
			"physics_off":
				g.world.visible = true
				for b in g.world.bodies: b.freeze = true
		await _frames(30)
		var ts: Array = []
		var l0 := Time.get_ticks_usec()
		var rc := 0.0
		var rg := 0.0
		var vp := root.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp, true)
		for i in 300:
			await process_frame
			rope_us += g.world.rope_fx.cost_us
			phys_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			proc_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			pairs = maxf(pairs, Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS))
			var n2 := Time.get_ticks_usec()
			ts.append((n2 - l0) / 1000.0)
			l0 = n2
			rc += RenderingServer.viewport_get_measured_render_time_cpu(vp)
			rg += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		var a := 0.0
		for x in ts: a += x
		ts.sort()
		print("PHASE %-14s frame mean %.2f median %.2f p95 %.2f ms | render cpu %.2f gpu %.2f" % [phase, a / ts.size(), ts[ts.size() / 2], ts[int(ts.size() * 0.95)], rc / 300.0, rg / 300.0])
		var _sl := 0
		for _b in g.world.bodies: _sl += 1 if _b.sleeping else 0
		print("  process %.2f ms/frame, bodies %d sleeping %d" % [proc_ms / 300.0, g.world.bodies.size(), _sl])
		print("  physics %.2f ms/frame, pairs max %d, steps/frame %.2f" % [phys_ms / 300.0, pairs, float(Engine.physics_ticks_per_second) * (Time.get_ticks_usec() * 0.0 + 1.0) / 60.0])
		print("  rope %.3f ms/frame (live %d) held=%s" % [rope_us / 300.0 / 1000.0, g.world.rope_fx.live(), str(g.tools.held_body != null)])
		var pk: Array = World.prof.keys()
		pk.sort_custom(func(x, y): return World.prof[x] > World.prof[y])
		for k in pk.slice(0, 8):
			print("  P %-22s %.3f ms/frame" % [k, World.prof[k] / 300.0 / 1000.0])
		var ks: Array = World.acc_sum.keys()
		ks.sort_custom(func(x, y): return World.acc_sum[x] > World.acc_sum[y])
		for k in ks.slice(0, 26):
			print("  %-26s %.3f ms/frame" % [k, World.acc_sum[k] / 300.0 / 1000.0])
		var pd: Array = g.dock.prof_draw
		print("  furnace draws %d: smelter %.2f ms, scrapline %.2f ms, flush %.2f ms each" % [pd[3], pd[0] / 1000.0 / maxf(1, pd[3]), pd[1] / 1000.0 / maxf(1, pd[3]), pd[2] / 1000.0 / maxf(1, pd[3])])
	quit()
