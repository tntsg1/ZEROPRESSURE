extends SceneTree
# AX-40 逆火 · the annihilation cinematic (scripts/annihilation.gd), stage 1 sample: triggered in a
# career berth on a small hull (the AX-40 itself comes in stage 2). Key frames, frame times.
# Own test saves only.
#   tools/run_test.sh tests/anni_shot.gd --fixed-fps 60
#   tools/run_test.sh tests/anni_shot.gd --fixed-fps 30 --write-movie recordings/anni_sample.avi -- movie
const Cap = preload("res://tests/cap.gd")
const Anni = preload("res://scripts/annihilation.gd")

var frames: Array = []
var by := {}
var gpu: Array = []
var movie := false


func _initialize() -> void:
	Career.path = "user://zp_test_annishot_career.json"
	SaveGame.path = "user://zp_test_annishot_save.json"
	SaveGame.allow_test = true
	movie = "movie" in OS.get_cmdline_user_args()
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _until(nk, tt: float) -> void:
	while nk.t < tt and not nk.finished:
		var t0 := Time.get_ticks_usec()
		await process_frame
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		frames.append(ms)
		var vp := root.get_viewport_rid()
		gpu.append([nk.t, RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp)])
		var ph := "unbind" if nk.t < 0.6 else ("collapse" if nk.t < 1.2 else ("bang" if nk.t < 1.5 else ("spectrum" if nk.t < 4.0 else ("afterglow" if nk.t < 7.6 else "card"))))
		if not by.has(ph):
			by[ph] = []
		by[ph].append(ms)


func _shot(nk, tt: float, name: String) -> void:
	await _until(nk, tt)
	if not movie:
		Cap.save(root, "res://tests/out/anni_%s.png" % name)
		frames.append(999.0)


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.port = {"power": 2, "salvage": 1, "process": 2, "tug": 1, "trade": 1, "cargo": 1, "ring": 0}
	Career.save()
	Game.contract = {}
	Game.start_ship = "jd38"
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	var t0 := Time.get_ticks_msec()
	Anni.prebake()
	for i in 10: await process_frame
	g.job = {"id": "anni-shot", "ship": "jd38"}
	for i in 50: await process_frame
	var tb := Time.get_ticks_msec()
	Anni.track_mesh()
	await Anni.warm(g)
	print("ANNI bake ready after %d ms (wait on main %d ms)" % [Time.get_ticks_msec() - t0, Time.get_ticks_msec() - tb])
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var bb := Rect2()
	var first := true
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.gone:
			continue
		var r := Geom.bbox(g.world.world_poly(p))
		bb = r if first else bb.merge(r)
		first = false
	var at := bb.get_center()
	g.cam_override = at
	g.zoom_override = 1080.0 / (22.0 * Geom.M)
	for i in 30: await process_frame
	if not movie:
		Cap.save(root, "res://tests/out/anni_00_before.png")
	var ts := Time.get_ticks_usec()
	g.start_annihilation(at)
	print("ANNI setup %.1f ms" % ((Time.get_ticks_usec() - ts) / 1000.0))
	var nk = g.nuke
	await _shot(nk, 0.3, "01_unbind")
	await _shot(nk, 0.85, "02_collapse")
	await _shot(nk, 1.15, "03_collapse_late")
	await _shot(nk, 1.21, "04_negative")
	await _shot(nk, 1.32, "05_star_shell")
	await _shot(nk, 1.9, "06_spectrum_early")
	await _shot(nk, 2.7, "07_spectrum")
	await _shot(nk, 3.5, "08_spectrum_late")
	await _shot(nk, 4.6, "09_afterglow")
	await _shot(nk, 6.2, "10_afterglow_out")
	await _shot(nk, 7.3, "11_embers")
	await _shot(nk, 7.6 + 2.4, "12_card")
	var ft: Array = frames.filter(func(x): return x < 300.0)
	ft.sort()
	var avg := 0.0
	for x in ft:
		avg += x
	avg /= maxf(1.0, ft.size())
	print("ANNI FRAMES n %d avg %.2f ms p95 %.2f p99 %.2f max %.2f" % [ft.size(), avg, ft[int(ft.size() * 0.95)], ft[int(ft.size() * 0.99)], ft[ft.size() - 1]])
	for ph in by:
		var a: Array = by[ph].filter(func(x): return x < 300.0)
		a.sort()
		print("  %s n %d p50 %.2f p95 %.2f max %.2f" % [ph, a.size(), a[a.size() / 2], a[int(a.size() * 0.95)], a[a.size() - 1]])
	for col in [1, 2]:
		var xs: Array = gpu.map(func(d): return d[col])
		xs.sort()
		print("  %s p50 %.2f p95 %.2f max %.2f ms" % [["", "render cpu", "gpu"][col], xs[xs.size() / 2], xs[int(xs.size() * 0.95)], xs[xs.size() - 1]])
	nk.skip()
	for i in 5: await process_frame
	print("ANNI state after skip: ", g.state, " nuked ", g.nuked)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.path))
	quit()
