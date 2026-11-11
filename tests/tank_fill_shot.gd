extends SceneTree
# Tanks seen holding their liquid (scripts/tank_fill_fx.gd): key frames of a ship's tanks full,
# being drawn off (the bubble growing, the liquid streaming to the outlet), nearly empty.
# Only the test drains the volume (as a hose would); nothing in the mechanism is changed.
# tools/run_test.sh tests/tank_fill_shot.gd --fixed-fps 60 -- <ship> [vol]
const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_tankfill_career.json"
	SaveGame.path = "user://zp_test_tankfill_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _fx(g):
	for c in g.boiloff.get_children():
		if c.get_script() == preload("res://scripts/tank_fill_fx.gd"):
			return c
	return null


func _look(g, at: Vector2, zoom: float, wait: int, name: String, vol: String = "", drain: float = 0.0) -> void:
	g.zoom_override = zoom
	g.cam_override = at
	for i in wait:
		if vol != "" and drain > 0.0:
			g.sys.fvol[vol].amount = maxf(0.0, float(g.sys.fvol[vol].amount) - drain)
		await process_frame
	Cap.save(root, "res://tests/out/%s.png" % name)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var ship: String = args[0] if args.size() > 0 else "hg170"
	Game.contract = {}
	Game.start_ship = ship
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 20:
		await process_frame
	for n in g.world.rooms:
		g.world.reveal(n, g.world.rooms[n].bbox.get_center())
	var w := 0
	while str(g.state) == "survey" and w < 60 * 25:
		await process_frame
		w += 1
	g.drone.global_position = Vector2(-40.0, -60.0) * Geom.M
	for i in 5:
		await process_frame
	var fx = _fx(g)
	if fx == null or fx._tanks.is_empty():
		print("TANK FILL SHOT: no tanks on ", ship)
		quit(1)
		return
	var vol: String = args[1] if args.size() > 1 else str(fx._tanks[0].vol)
	# the view: every tank of that volume, and those near it
	var box := Rect2()
	var first := true
	for e in fx._tanks:
		if str(e.vol) != vol:
			continue
		var bb: Rect2 = fx._xf(e) * (e.bb as Rect2)
		box = bb if first else box.merge(bb)
		first = false
	var vs: Vector2 = root.get_visible_rect().size
	var zoom := clampf(minf(vs.x / (box.size.x * 1.6), vs.y / (box.size.y * 2.2)), 0.05, 3.0)
	if ship == "hg170" and args.size() <= 1:
		box = Rect2(Vector2(66.0, -7.0) * Geom.M, Vector2(62.0, 14.0) * Geom.M)
		zoom = clampf(vs.x / (box.size.x * 1.15), 0.05, 3.0)
	var at := box.get_center()
	var full: float = float(g.sys.fvol[vol].amount)
	print("TANK FILL SHOT %s vol %s holds %.2f of %.2f, %d tanks drawn on the ship" % [ship, vol, full, float(fx._tanks[0].full), fx._tanks.size()])
	var tag := "%s_%s" % [ship, vol]
	# what the layer costs a frame: every tank's shape worked out (as both its layers use it)
	var t0 := Time.get_ticks_usec()
	for it in 30:
		for e in fx._tanks:
			e.erase("_f")
			fx._shape_now(e, fx._xf(e))
	# the liquid drawn is what the system holds: its share of each tank's area, k from 2% to 98%
	var worst := 0.0
	var tb := Time.get_ticks_usec()
	var nb := 0
	for e in fx._tanks:
		if (e.lv as Array).is_empty():
			fx._levels(e)
			nb += 1
	print("TANK FILL LEVELS built %d in %.1f ms (spread two a frame in the game)" % [nb, float(Time.get_ticks_usec() - tb) / 1000.0])
	for e in fx._tanks:
		var keep: float = float(g.sys.fvol[e.vol].amount)
		for k in [0.02, 0.1, 0.3, 0.5, 0.7, 0.9, 0.98]:
			g.sys.fvol[e.vol].amount = float(e.full) * k
			var sh: Array = fx._shape_now(e, Transform2D.IDENTITY)
			var W: PackedVector2Array = sh[0]
			var B: PackedVector2Array = sh[1]
			var aw := 0.0
			var ab := 0.0
			for i in W.size():
				aw += W[i].cross(W[(i + 1) % W.size()])
				ab += B[i].cross(B[(i + 1) % B.size()])
			worst = maxf(worst, absf((aw - ab) / aw - k))
		g.sys.fvol[e.vol].amount = keep
	print("TANK FILL AREA worst |drawn share - held share| = %.3f over %d tanks" % [worst, fx._tanks.size()])
	print("TANK FILL COST %.3f ms a frame for %d tanks (shapes, all on screen)" % [float(Time.get_ticks_usec() - t0) / 30000.0, fx._tanks.size()])
	await _look(g, at, zoom, 60, "tank_%s_a_held" % tag)
	if ship == "hg170":
		# all four drawn off at once, the pressure up (boiling harder)
		for t in g.boiloff.kpa:
			g.boiloff.kpa[t] = 560.0
		for i in 100:
			for e in fx._tanks:
				g.sys.fvol[e.vol].amount = maxf(0.0, float(g.sys.fvol[e.vol].amount) - 0.025)
			await process_frame
		Cap.save(root, "res://tests/out/tank_%s_b_drawing.png" % tag)
		for e in fx._tanks:
			g.sys.fvol[e.vol].amount = 0.35
		for i in 60:
			for e in fx._tanks:
				g.sys.fvol[e.vol].amount = maxf(0.0, float(g.sys.fvol[e.vol].amount) - 0.002)
			await process_frame
		Cap.save(root, "res://tests/out/tank_%s_c_nearly_empty.png" % tag)
		quit()
		return
	await _look(g, at, zoom, 100, "tank_%s_b_drawing" % tag, vol, full * 0.005)
	g.sys.fvol[vol].amount = float(fx._tanks[0].full) * 0.08
	for e in fx._tanks:
		if str(e.vol) == vol:
			g.sys.fvol[vol].amount = float(e.full) * 0.08
	await _look(g, at, zoom, 60, "tank_%s_c_nearly_empty" % tag, vol, float(g.sys.fvol[vol].amount) * 0.004)
	quit()
