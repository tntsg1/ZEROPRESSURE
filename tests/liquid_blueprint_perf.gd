extends SceneTree
# Real-rendering benchmark; fixed simulation step only, vsync and frame cap off.
const Cap = preload("res://tests/cap.gd")

class TimedLiquid extends "res://scripts/liquids.gd":
	var sums := {}
	func _move(dt: float) -> void:
		var us := Time.get_ticks_usec()
		super._move(dt)
		sums.move = sums.get("move", 0) + Time.get_ticks_usec() - us
	func _merge(step: float = 1.0 / 60.0) -> void:
		var us := Time.get_ticks_usec()
		super._merge(step)
		sums.merge = sums.get("merge", 0) + Time.get_ticks_usec() - us
	func _draw() -> void:
		var us := Time.get_ticks_usec()
		super._draw()
		sums.draw = sums.get("draw", 0) + Time.get_ticks_usec() - us
	func _hit(b: Dictionary, hit: Dictionary, lk: Dictionary) -> void:
		var us := Time.get_ticks_usec()
		super._hit(b, hit, lk)
		sums.hit = sums.get("hit", 0) + Time.get_ticks_usec() - us

class TimedBlueprint extends Blueprint:
	var stages := {}
	func _dpoly(poly: PackedVector2Array, c: Color, w: float) -> void:
		var us := Time.get_ticks_usec()
		super._dpoly(poly,c,w)
		stages.poly = stages.get("poly",0) + Time.get_ticks_usec() - us
	func _dpath(poly: PackedVector2Array, c: Color, w: float) -> void:
		var us := Time.get_ticks_usec()
		super._dpath(poly,c,w)
		stages.path = stages.get("path",0) + Time.get_ticks_usec() - us
	func _label(at: Vector2, txt: String, px: int, col: Color, off: Vector2 = Vector2(4,-4)) -> void:
		var us := Time.get_ticks_usec()
		super._label(at,txt,px,col,off)
		stages.label = stages.get("label",0) + Time.get_ticks_usec() - us
	func _point_label(at: Vector2, txt: String, col: Color) -> void:
		var us := Time.get_ticks_usec()
		super._point_label(at,txt,col)
		stages.point = stages.get("point",0) + Time.get_ticks_usec() - us
	var draw_us := 0
	var draws := 0
	func _draw() -> void:
		var us := Time.get_ticks_usec()
		super._draw()
		draw_us += Time.get_ticks_usec() - us
		draws += 1

var g: Game

func _initialize() -> void:
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n: await process_frame

func measure(tag: String, n: int = 80) -> void:
	var values: Array = []
	var last := Time.get_ticks_usec()
	var lq = g.liquids
	lq.sums.clear()
	g.blueprint.stages.clear()
	g.blueprint.draw_us = 0
	g.blueprint.draws = 0
	for i in n:
		await process_frame
		var now := Time.get_ticks_usec()
		values.append((now - last) / 1000.0)
		last = now
	values.sort()
	var sum := 0.0
	for v in values: sum += v
	var parts := {}
	for key in lq.sums: parts[key] = snappedf(float(lq.sums[key]) / n / 1000.0, 0.001)
	print("BP STAGES ",g.blueprint.stages)
	print("BENCH %s mean=%.3f p95=%.3f max=%.3f liquid_ms/frame=%s bp_draw_ms=%.3f bp_draws=%d blobs=%d" % [tag, sum/n, values[int(n*0.95)], values[-1], parts, g.blueprint.draw_us / 1000.0, g.blueprint.draws, lq.count()])

func scene(sid: String) -> void:
	Game.start_ship = sid
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	g.liquids.free()
	g.liquids = TimedLiquid.new()
	g.liquids.setup(g)
	g.add_child(g.liquids)
	g.blueprint.free()
	g.blueprint = TimedBlueprint.new()
	g.blueprint.game = g
	g.add_child(g.blueprint)
	await frames(40)
	g.state = "play"
	for key in g.world.rooms: g.world.reveal(key, g.world.rooms[key].bbox.get_center())

func _run() -> void:
	SaveGame.path = "user://zp_test_liqbp_save.json"
	Career.path = "user://zp_test_liqbp_career.json"
	Txt.cfg_path = "user://zp_test_liqbp_settings.cfg"
	Txt.zh = true
	SaveGame.allow_test = true
	seed(70123)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.add_child(preload("res://tests/test_window.gd").new())
	await scene("mf126")
	g.cam_override = Vector2(106, 2) * Geom.M
	g.zoom_override = 1.0
	await frames(35)
	await measure("liquid-dry")
	# A genuine tank cut, where the player's screenshot shows the spilled coolant.
	var tank = g.world.tag("CT")
	g.on_cut_into(tank, Geom.bbox(g.world.world_poly(tank)).get_center())
	await frames(140)
	await measure("liquid-tank-cut")
	# Full particle budget inside the ship, including wet walls (old test used empty space).
	for i in 32:
		g.liquids.spill(Vector2(103 + (i % 8) * 0.8, 1 + (i / 8) * 0.8) * Geom.M, Vector2.DOWN, 0.03, "glycol", 10, 1.0, 1.0, true)
	await frames(30)
	await measure("liquid-320-inside")
	Cap.save(root, "res://proofs/liquid_perf.png")
	g.queue_free()
	await frames(3)
	if "liquid-only" in OS.get_cmdline_user_args():
		quit()
		return
	await scene("ark01")
	g.cam_override = Vector2(304, 0) * Geom.M
	g.zoom_override = 0.045
	await frames(40)
	await measure("ark-blueprint-off")
	g.blueprint.toggle()
	await measure("ark-blueprint-opening", 45)
	await measure("ark-blueprint-on")
	# Continuous zoom forces layout updates, as it does when navigating the drawing.
	for i in 3:
		g.zoom_override = 0.045 + i * 0.003
		await measure("ark-blueprint-zoom-%d" % i, 35)
	g.zoom_override = 0.8
	await frames(80)
	await measure("ark-blueprint-close")
	g.cam_override = Vector2(440, 0) * Geom.M
	await measure("ark-blueprint-pan")
	Cap.save(root, "res://proofs/ark_blueprint_perf.png")
	g.queue_free()
	await frames(3)
	quit()
