extends SceneTree
# ARK-01 改造方案 2：侧挂转轮（ships/ark01.json 已是转轮；旧环版在 tests/fixtures/ark01_rings_old.json）。Stills, frame times on the same cameras (old rings vs wheels), and a
# Movie Maker run for a ~10 s clip.
#   tools/run_test.sh tests/ark_wheel_shot.gd --fixed-fps 60 -- shots      (stills: tests/out/wheel_*.png)
#   tools/run_test.sh tests/ark_wheel_shot.gd -- perf                      (frame times, vsync off)
#   tools/run_test.sh tests/ark_wheel_shot.gd --fixed-fps 60 --write-movie G:/temp/zp_wheel/w.avi -- movie
# Test saves only (user://zp_test_wheel_*), the window off-screen.
const Cap = preload("res://tests/cap.gd")
const Wheels = preload("res://tools/authoring/ark01_wheels.gd")
var g
var mode := "shots"


func _initialize() -> void:
	Career.path = "user://zp_test_wheel_career.json"
	SaveGame.path = "user://zp_test_wheel_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(preload("res://tests/test_window.gd").new())
	for a in OS.get_cmdline_user_args():
		mode = a
	_run.call_deferred()


func _f(n: int) -> void:
	for i in n:
		await process_frame


func _start(wheels: bool) -> void:
	Ship.clear_cache()
	# the ship file has the wheels; the old rings for the same-camera comparison are a test fixture
	if not wheels:
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/ark01_rings_old.json"))
		Ship.CONTENTS.add(d)
		if not d.has("value"):
			d.value = {}
		d.value.metal = Ship.scrap_value("ark01", d)
		Variant.revalue(d)
		Lines.apply_ship("ark01", d)
		Ship.override("ark01", d)
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "ark01"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _f(30)
	for n in g.world.rooms:
		g.world.reveal(n, g.world.rooms[n].bbox.get_center())
	await _f(40)


func _view(x: float, y: float, z: float, n: int = 60) -> void:
	g.zoom_override = z
	g.cam_override = Vector2(x, y) * Geom.M
	g.drone.global_position = Vector2(x, 0.0) * Geom.M
	for i in n:
		g.cam_pos = g.cam_override
		g.cam_vel = Vector2.ZERO
		g.zoom_now = z
		await process_frame


func _stop() -> void:
	g.queue_free()
	await _f(4)


const VIEWS := [
	["whole", 304.0, 0.0, 0.0],           # zoom 0: the whole ship (worked out below)
	["pair", 142.0, 6.0, 0.1],          # both wheels
	["wheelA", 97.0, -55.0, 0.22],        # wheel A and its board
	["rimA", 85.0, -88.0, 0.8],          # wheel A's top module close
]


func _zoom(v: Array) -> float:
	return float(v[3]) if float(v[3]) > 0.0 else 1800.0 / ((Dock.FLOOR_X1 + 20.0) * Geom.M)


func _run() -> void:
	if mode == "compare":
		await _compare()
	elif mode == "perf":
		await _perf()
	elif mode == "movie":
		await _movie()
	else:
		await _shots()
	quit()


func _shots() -> void:
	await _start(true)
	for v in VIEWS:
		await _view(v[1], v[2], _zoom(v))
		Cap.save(root, "res://tests/out/wheel_%s.png" % v[0])
		if v[0] in ["pair", "wheelA"]:
			await _f(60)
			Cap.save(root, "res://tests/out/wheel_%s_t1.png" % v[0])
	# loads off and the brakes on (A 3, B 4): the boards read the stop
	var rg = g.rings
	for r in ["A", "B"]:
		_op("K-R" + r)
		_op("SR-" + r)
		_op("BCOOL-" + r)
	for i in 3:
		_op("BRK-A%d" % (i + 1))
	for i in 4:
		_op("BRK-B%d" % (i + 1))
	await _view(142.0, 6.0, 0.1, 600)
	Cap.save(root, "res://tests/out/wheel_pair_braking.png")
	print("WHEEL rpm A %.2f B %.2f  cap A %.0f%% B %.0f%%  members A %d B %d" % [rg.rpm.A, rg.rpm.B, rg.cap_charge("A") * 100.0, rg.cap_charge("B") * 100.0, rg.members.A.size(), rg.members.B.size()])
	var inf := Wheels.info()
	for r in inf:
		print("WHEEL %s hub (%.1f, %.1f) m  rim %.1f m  swept %.1f m  ø %.0f m" % [r, inf[r].cx, inf[r].cy, inf[r].rout, inf[r].sweep, inf[r].rout * 2.0])
	await _stop()


func _op(id: String) -> void:
	var c = g.world.ctrls.get(id)
	if c != null:
		g.do_wrench({"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)})


# frame times on the same cameras, the old rings and then the wheels, in one run
func _perf() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var res := {}
	for wheels in [false, true]:
		await _start(wheels)
		for v in [VIEWS[0], VIEWS[1], VIEWS[2]]:
			await _view(v[1], v[2], _zoom(v), 90)
			var ts: Array = []
			var t0 := Time.get_ticks_usec()
			for i in 240:
				g.cam_pos = g.cam_override
				await process_frame
				var t1 := Time.get_ticks_usec()
				ts.append((t1 - t0) / 1000.0)
				t0 = t1
			ts.sort()
			var mean := 0.0
			for t in ts:
				mean += t
			mean /= ts.size()
			res["%s %s" % ["WHEELS" if wheels else "OLD   ", v[0]]] = [mean, ts[int(ts.size() * 0.5)], ts[int(ts.size() * 0.95)], ts[int(ts.size() * 0.99)]]
		await _stop()
	for k in res:
		var a: Array = res[k]
		print("PERF %-14s mean %5.2f  p50 %5.2f  p95 %5.2f  p99 %5.2f ms  (%.0f fps)" % [k, a[0], a[1], a[2], a[3], 1000.0 / a[0]])


# Movie Maker: ~4 s on both wheels, ~4 s on wheel A and its board, ~3 s on the top module
func _movie() -> void:
	await _start(true)
	await _view(142.0, 6.0, 0.1, 240)
	await _view(97.0, -55.0, 0.22, 240)
	await _view(85.0, -88.0, 0.8, 180)
	await _stop()


# the old ring's top module and the wheel's (held at 0°, stopped), the same size on screen
func _compare() -> void:
	var inf := Wheels.info()
	# each wheel's top module, the old ring's top module beside it, the same size on screen
	var shots := [["A", 85.0, 0.45], ["B", 193.0, 0.38]]
	for wheels in [false, true]:
		await _start(wheels)
		if wheels:
			for r in ["A", "B"]:
				g.rings.rpm[r] = 0.0
			await _f(2)
			g.rings.fx.hold("A", 0.0)
			g.rings.fx.hold("B", 0.0)
		for sh in shots:
			var r: String = sh[0]
			var old_y: float = -105.0 if r == "A" else -111.0
			var cy: float = old_y if not wheels else float(inf[r].cy) - float(inf[r].rout) + 9.5
			await _view(float(sh[1]), cy, float(sh[2]), 70)
			Cap.save(root, "res://tests/out/wcmp_%s_%s.png" % ["new" if wheels else "old", r])
		await _stop()
