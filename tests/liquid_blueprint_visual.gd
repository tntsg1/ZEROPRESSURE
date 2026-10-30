extends SceneTree
const Reference = preload("res://tests/liquid_blueprint_reference.gd")
var fails := 0
var views: Array = []

func _initialize() -> void:
	_run.call_deferred()

func frames(n: int = 3) -> void:
	for i in n: await process_frame

func viewport() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(1024, 640)
	vp.world_2d = World2D.new()
	vp.use_hdr_2d = true
	vp.msaa_2d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	return vp

func compare(tag: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	var a: Image = views[0].get_texture().get_image()
	var b: Image = views[1].get_texture().get_image()
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var da := a.get_data()
	var db := b.get_data()
	var total := 0
	var major := 0
	var changed := 0
	for i in da.size():
		var diff := absi(int(da[i]) - int(db[i]))
		total += diff
		if diff > 1: changed += 1
		if diff > 12: major += 1
	var mean := float(total) / da.size()
	print("VISUAL %s mean=%.5f changed=%d major=%d" % [tag, mean, changed, major])
	# Same silhouette/details, permitting float rounding at MSAA edges.
	if mean > 0.25 or major > 2500: fails += 1
	a.save_png("res://proofs/" + tag + "_before.png")
	b.save_png("res://proofs/" + tag + "_after.png")

func _run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	views = [viewport(), viewport()]
	var nodes: Array = []
	for script in [Reference.Liquid, preload("res://scripts/liquids.gd")]:
		var node = script.new()
		node.set_physics_process(false)
		node._t = 2.3
		views[nodes.size()].add_child(node)
		nodes.append(node)
	for mode in ["common", "ice_mix", "mixed"]:
		var blobs: Array = []
		var looks: Array = ["water", "glycol"] if mode != "mixed" else nodes[0].LOOKS.keys()
		for look in looks:
			for r in ([2.0, 2.6, 3.1, 3.9, 4.1, 9.9, 10.1, 30.0] if mode == "common" else [2.0, 8.0, 20.0]):
				for stuck in [false, true]:
					var i := blobs.size()
					blobs.append({"pos": Vector2(52 + (i % 8) * 125, 70 + (i / 8) * 70), "vel": Vector2.ZERO,
						"vol": pow(r / Geom.M, 3) * PI / 0.75, "look": look, "t": 1.7,
						"ph": i * 0.61, "stuck": 0 if stuck else -1, "nrm": Vector2.from_angle(i * 0.61),
						"ice": mode != "common" and look == "water", "quiet": true})
		for node in nodes:
			node.blobs = blobs.duplicate(true)
			node.queue_redraw()
		await compare("liquid_" + mode)
	# Keep merge order, volume and momentum exactly consistent with the old algorithm.
	seed(7142)
	var drops: Array = []
	for i in 320:
		drops.append({"pos": Vector2(randf_range(-90, 90), randf_range(-60, 60)), "vel": Vector2(randf_range(-30,30),randf_range(-30,30)),
			"vol": randf_range(0.0001, 0.04), "look": "water" if i % 3 else "glycol", "t": randf_range(0,2), "ph": 0.0,
			"stuck": i % 7 if i % 4 == 0 else -1, "loc": Vector2.ZERO, "nrm": Vector2.UP, "ice": i % 23 == 0, "quiet": i % 9 == 0})
	for node in nodes: node.blobs = drops.duplicate(true)
	for i in 4:
		for node in nodes: node._merge()
		var same: bool = nodes[0].blobs == nodes[1].blobs
		print("MERGE EQUIVALENCE ", i, " ", same)
		if not same: fails += 1
	for node in nodes: node.queue_free()
	await frames()
	var g := Game.new()
	g.ship = Ship.load_data("ark01")
	var source := Blueprint.new()
	# Snapshot uses the live dock's designed clamps and empty engineering notes.
	g.dock = Dock.new()
	g.world = World.new()
	Ship.build(g.world, g.ship)
	source.game = g
	source.snapshot()
	nodes.clear()
	for script in [Reference.Drawing, Blueprint]:
		var node = script.new()
		node.set_process(false)
		node.game = g
		node.k = 1.0
		node.on = true
		node.snapped = true
		for key in ["rooms", "equip", "runs", "points", "x0", "x1", "y_top"]: node.set(key, source.get(key))
		if nodes.is_empty(): node.material = null
		views[nodes.size()].add_child(node)
		nodes.append(node)
	for zoom in [0.03, 0.3, 1.0]:
		g.zoom_now = zoom
		for i in 2:
			views[i].canvas_transform = Transform2D(Vector2.RIGHT * zoom, Vector2.DOWN * zoom, Vector2(512,320) - Vector2(304,0) * Geom.M * zoom)
			nodes[i].queue_redraw()
		await compare("blueprint_" + str(zoom))
		if nodes[0]._placed != nodes[1]._placed:
			print("LABEL PLACEMENT MISMATCH")
			fails += 1
	# Move to another section without changing zoom: culled detail must reappear.
	for i in 2:
		views[i].canvas_transform = Transform2D(Vector2.RIGHT, Vector2.DOWN, Vector2(512,320) - Vector2(440,0) * Geom.M)
		nodes[i]._process(0.0)
	await compare("blueprint_pan")
	for vp in views: vp.queue_free()
	source.free()
	g.dock.free()
	g.world.free()
	g.free()
	await frames()
	print("LIQUID BLUEPRINT VISUAL ", "PASS" if fails == 0 else "FAIL", " failures=", fails)
	quit(0 if fails == 0 else 1)
