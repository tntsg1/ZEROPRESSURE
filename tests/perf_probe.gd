extends SceneTree
# 60 FPS work: where the frame goes. A scene settles, then 180 frames are measured: the real
# interval between frames (what is presented, vsync off), script process and physics time, the
# viewport's render time on the CPU and on the GPU, draw calls. Then each of the game's top-level
# nodes is stopped in turn (processing and drawing) and the drop in process time is listed: the
# hot spots. Measurement only. Own test saves only.
#   tools/run_test.sh tests/perf_probe.gd -- ship=tug
var g: Node


func _initialize() -> void:
	Career.path = "user://zp_test_perfprobe_career.json"
	SaveGame.path = "user://zp_test_perfprobe_save.json"
	SaveGame.allow_test = true
	# visible=1: the window stays where the user can see it (a real on-screen run); otherwise it is
	# moved off-screen like every other test so it never takes focus
	if DisplayServer.get_name() != "headless" and _arg("visible", "0") != "1":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func measure(n: int) -> Dictionary:
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var dts: Array = []
	var pr := 0.0
	var ph := 0.0
	var rc := 0.0
	var rg := 0.0
	var dc := 0.0
	var last := Time.get_ticks_usec()
	for i in n:
		await process_frame
		var now := Time.get_ticks_usec()
		dts.append((now - last) / 1000.0)
		last = now
		pr += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		ph += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		rc += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		rg += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var s := dts.duplicate()
	s.sort()
	var avg := 0.0
	for x in s:
		avg += x
	avg /= s.size()
	var low := 0.0
	var nlow := maxi(1, int(s.size() * 0.01))
	for k in nlow:
		low += s[s.size() - 1 - k]
	low /= nlow
	return {"avg": avg, "p95": s[int(s.size() * 0.95)], "p99": s[mini(s.size() - 1, int(s.size() * 0.99))], "max": s[s.size() - 1], "low1": low,
		"process": pr / n, "physics": ph / n, "render_cpu": rc / n, "render_gpu": rg / n, "draws": dc / n}


static func line(name: String, m: Dictionary) -> String:
	return "%-28s frame avg %6.2f  p95 %6.2f  p99 %6.2f  max %6.2f  1%%low %6.2f | process %6.2f physics %5.2f render cpu %5.2f gpu %5.2f | draws %5.0f" % [name, m.avg, m.p95, m.p99, m.max, m.low1, m.process, m.physics, m.render_cpu, m.render_gpu, m.draws]


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var ship := _arg("ship", "tug")
	Game.contract = {}
	Game.start_ship = ship
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(60)
	var nl := int(_arg("drops", "0"))
	if nl > 0:
		for k in 30:
			g.liquids.spill(Vector2((20.0 + (k % 6) * 4.0) * Geom.M, (-10.0 + (k / 6) * 3.0) * Geom.M), Vector2.from_angle(k), 0.02, "water", nl / 30, PI, 1.0, false)
		print("  drops spilt: ", g.liquids.blobs.size() + g.liquids._new.size())
	if int(_arg("leak", "0")) > 0:
		var sp := Node.new()
		sp.set_script(preload("res://tests/_leak_tmp.gd"))
		sp.set("g", g)
		root.add_child(sp)
		await _frames(300)
		print("  leaking: %d globules" % g.liquids.blobs.size())
	var nd := int(_arg("debris", "0"))
	if nd > 0:
		var cc := Vector2(43.0 * Geom.M, -7.0 * Geom.M)
		for i in nd:
			var at := cc + Vector2((i % 25) * 0.85 * Geom.M - 10.6 * Geom.M, (i / 25) * 1.0 * Geom.M - 5.0 * Geom.M)
			var h := Vector2(14, 10)
			g.world.add_piece("plate", PackedVector2Array([at - h, at + Vector2(h.x, -h.y), at + h, at + Vector2(-h.x, h.y)]), {"mat": "steel", "mass": 0.2})
		g.world.dirty_links = true
	var zm := float(_arg("zoom", "-1"))
	if zm > 0.0:
		g.zoom_override = zm
		g.cam_override = Vector2(float(_arg("camx", "300")) * Geom.M, 0)
	await _frames(120)
	World.prof.clear()
	var base := await measure(180)
	var keys: Array = World.prof.keys()
	keys.sort_custom(func(x, y): return World.prof[x] > World.prof[y])
	print("  World.prof over 180 frames (µs, max per call or running total): ", keys.slice(0, 18).map(func(k): return "%s=%d" % [k, World.prof[k]]))
	print(line("%s settled" % ship, base))
	print("  dock: bodies loop %.2f ms, process %.2f ms" % [g.dock.prof_bodies_us / 1000.0, g.dock.prof_process_us / 1000.0])
	var sl := 0
	var vmax := 0.0
	for bb in g.world.bodies:
		if is_instance_valid(bb):
			if bb.sleeping:
				sl += 1
			vmax = maxf(vmax, bb.linear_velocity.length())
	print("  bodies %d, sleeping %d, fastest %.1f px/s" % [g.world.bodies.size(), sl, vmax])
	var pulled := 0
	var near_zone := 0
	var in_buf := 0
	var scrap_n := 0
	var fast_at := Vector2.ZERO
	for bb in g.world.bodies:
		if not is_instance_valid(bb):
			continue
		var com: Vector2 = bb.global_transform * bb.center_of_mass
		if g.dock.field_pull(com) != Vector2.ZERO:
			pulled += 1
		if g.dock.in_buffer(bb):
			in_buf += 1
		if g.dock.is_scrap(bb):
			scrap_n += 1
		for id in Dock.ZONES:
			if Dock.zpos(id).distance_to(com) < 8.0 * Geom.M:
				near_zone += 1
				break
		if bb.linear_velocity.length() > vmax * 0.9:
			fast_at = com / Geom.M
	print("  tractor-pulled %d, near a mouth %d, in buffer %d, scrap %d, fastest at %s m" % [pulled, near_zone, in_buf, scrap_n, str(fast_at)])
	g.dock.set_physics_process(false)
	await _frames(60)
	var nd2 := await measure(120)
	print(line("  dock physics off", nd2))
	g.dock.set_physics_process(true)
	g.dock.set_process(false)
	await _frames(30)
	print(line("  dock process off", await measure(120)))
	g.dock.set_process(true)
	g.dock.visible = false
	await _frames(30)
	print(line("  dock hidden", await measure(120)))
	g.dock.visible = true
	await _frames(30)
	# who takes the process time
	var rows: Array = []
	var nodes: Array = g.get_children()
	nodes.append_array(g.world.get_children())
	for part in g.world._pass_roots:
		var pr: Node = g.world._pass_roots[part]
		pr.set_meta("probe_name", "piece pass " + str(part))
		nodes.append(pr)
	for n in nodes:
		var was_p: bool = n.is_processing()
		var was_pp: bool = n.is_physics_processing()
		n.set_process(false)
		n.set_physics_process(false)
		var vis_was := true
		if n is CanvasItem:
			vis_was = n.visible
			n.visible = false
		await _frames(20)
		var m := await measure(60)
		n.set_process(was_p)
		n.set_physics_process(was_pp)
		if n is CanvasItem:
			n.visible = vis_was
		var sc: String = n.get_script().resource_path.get_file() if n.get_script() != null else n.get_class()
		for lname in ["back_layer", "light_layer", "line_layer", "piece_layer", "cover_layer", "heat_layer", "bodies_node", "rope_fx"]:
			if g.world.get(lname) == n:
				sc = "world." + lname
		if n.has_meta("probe_name"):
			sc = str(n.get_meta("probe_name"))
		if g.get("sail") != null and g.sail.get("overlay") == n:
			sc = "sail.overlay"
		rows.append([str(n.name) + " " + sc, base.process - m.process, base.physics - m.physics, base.avg - m.avg])
		await _frames(10)
	rows.sort_custom(func(a, b): return a[3] > b[3])
	print("  stopping each top-level node (process / physics / frame saved, ms):")
	for r in rows.slice(0, 14):
		print("    %-40s %6.2f %6.2f %6.2f" % r)
	quit()
