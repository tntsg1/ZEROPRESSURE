extends SceneTree
# 24 号: the port's drawing, before and after the performance work.
#   tools/run_test.sh tests/perf_port_check.gd --fixed-fps 60
# Each view is pictured twice under the same settled camera: drawn the old way (Backdrop.legacy:
# the whole port from scratch, as before) and the new way; the two are compared pixel by pixel.
# Then frame times, and the still layer left alone while nothing changes.
# Only the port layer is shown in the pictures (the berth, HUD and the rest hidden) and its
# animation clock is held still, so two runs draw exactly the same moment.
const Cap = preload("res://tests/cap.gd")
const T_FIXED := 12.3
const SHOTS := [
	["lit_berth", true, "", 0.38, "berth"],
	["lit_pano", true, "", -1.0, "pano"],
	["lit_hub", true, "", 1.1, "hub"],
	["lit_inside_process", true, "process", 0.55, "process"],
	["lit_inside_cargo", true, "cargo", 0.55, "cargo"],
	["dark_pano", false, "", -1.0, "pano"],
	["dark_berth", false, "", 0.38, "berth"],
	["dark_power", false, "", 0.7, "power"],
]
var g: Node
var base := false
var fails := 0
var checks := 0


func _initialize() -> void:
	base = OS.get_cmdline_user_args().has("base")
	Career.path = "user://zp_test_perfport_career.json"
	SaveGame.path = "user://zp_test_perfport_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _career(lit: bool) -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.market = true
	Career.data.port = {"power": 1, "salvage": 1, "process": 2, "tug": 1, "trade": 2, "cargo": 1, "ring": 1} if lit else {}
	Career.save()


func _spawn() -> void:
	Game.start_ship = "berth"
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(10)
	g.drone.freeze = true
	g.drone.linear_velocity = Vector2.ZERO


func _focus(where: String) -> Vector2:
	match where:
		"berth": return Dock.centre() * Geom.M + Vector2(0, -10.0 * Geom.M)
		"pano": return Backdrop.pano_centre_px()
		"hub": return Backdrop.port_centre_px()
	return Backdrop.port_centre_px() + PortArt.district_at(where) * PortArt.PM * Geom.M


# only the port layer on screen
func _isolate(on: bool) -> void:
	for n in g.get_children():
		if n is CanvasItem and not n is Backdrop:
			n.visible = not on
		elif n is CanvasLayer:
			n.visible = not on
	for v in [g.tram, g.boat]:
		if v != null:
			v.visible = not on
	g.hud.visible = not on
	if g.port_structure != null:
		g.port_structure.set_process(not on)


func _place(shot: Array) -> void:
	PortArt.inside = str(shot[2])
	var at := _focus(str(shot[4]))
	var z: float = float(shot[3]) if float(shot[3]) > 0.0 else Backdrop.port_zoom(root.get_visible_rect().size)
	g.drone.global_position = at
	g.cam_override = at
	g.cam_pos = at
	g.zoom_override = z
	g.zoom_target = z
	g.zoom_now = z


func _wall(n: int = 120) -> float:
	await _frames(15)
	var t0 := Time.get_ticks_usec()
	await _frames(n)
	return (Time.get_ticks_usec() - t0) / 1000.0 / n


func _diff(a: Image, b: Image) -> Array:
	if a.get_size() != b.get_size():
		return [1.0, 255]
	var w := a.get_width()
	var h := a.get_height()
	var bad := 0
	var worst := 0
	for y in range(0, h):
		for x in range(0, w):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var d := int(round(maxf(maxf(absf(ca.r - cb.r), absf(ca.g - cb.g)), absf(ca.b - cb.b)) * 255.0))
			if d > 8:
				bad += 1
			worst = maxi(worst, d)
	return [float(bad) / float(w * h), worst]


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Backdrop.t_fixed = T_FIXED
	var last_lit := -1
	for shot in SHOTS:
		var lit: bool = shot[1]
		if int(lit) != last_lit:
			if g != null:
				g.queue_free()
				await _frames(4)
			_career(lit)
			await _spawn()
			last_lit = int(lit)
		_isolate(true)
		_place(shot)
		# the camera settles, then the old drawing and the new one under the very same view
		Backdrop.legacy = true
		await _frames(150)
		var path_a := "res://tests/out/portpx_base_%s.png" % shot[0]
		Cap.save(root, path_a)
		Backdrop.legacy = false
		await _frames(20)
		var path_b := "res://tests/out/portpx_new_%s.png" % shot[0]
		Cap.save(root, path_b)
		var a := Image.load_from_file(ProjectSettings.globalize_path(path_a))
		var b := Image.load_from_file(ProjectSettings.globalize_path(path_b))
		if a == null or b == null:
			check(false, "%s: both pictures exist" % shot[0])
		else:
			var d := _diff(a, b)
			check(float(d[0]) <= 0.005, "%s: %.3f %% of pixels differ by more than 8/255 (worst %d/255)" % [shot[0], float(d[0]) * 100.0, int(d[1])])
	# frame times with everything shown and the clock running
	Backdrop.t_fixed = -1.0
	_career(true)
	g.queue_free()
	await _frames(4)
	await _spawn()
	g.drone.freeze = false
	g.cam_override = null
	g.zoom_override = -1.0
	var times := {}
	for v in [["berth, drone view", 0.62, "berth"], ["berth, zoomed out", 0.25, "berth"], ["port panorama", -1.0, "pano"], ["inside process", 0.55, "process"]]:
		var at := _focus(str(v[2]))
		var z: float = float(v[1]) if float(v[1]) > 0.0 else Backdrop.port_zoom(root.get_visible_rect().size)
		g.drone.global_position = at
		g.cam_override = at
		g.cam_pos = at
		g.zoom_override = z
		g.zoom_target = z
		g.zoom_now = z
		var ms := await _wall()
		times[v[0]] = ms
		print("PERF %-20s %6.2f ms" % [v[0], ms])
		if not base:
			check(ms <= 16.0, "%s: %.2f ms a frame (≤ 16)" % [v[0], ms])
	if not base and g.backdrop_parts() != null:
		var before: int = g.backdrop_parts().builds
		await _frames(120)
		check(g.backdrop_parts().builds == before, "the static port is not rebuilt while nothing changes (%d builds in 120 frames)" % (g.backdrop_parts().builds - before))
	g.queue_free()
	await _frames(4)
	print("PERF PORT %s (%d checks, %d failed)" % ["BASE" if base else ("PASS" if fails == 0 else "FAIL"), checks, fails])
	quit()
