extends SceneTree
const Cap = preload("res://tests/cap.gd")
func _initialize() -> void:
	Career.path = "user://zp_test_nr95shot_career.json"
	SaveGame.path = "user://zp_test_nr95shot_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()
func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "nr95"
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 20: await process_frame
	var core = g.world.tag("CORE")
	var at: Vector2 = g.world.frame(core) * Geom.centroid(core.poly)
	print("core at ", at / Geom.M, " room '", core.room, "' art ", core.art, " drawn above it: ")
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.gone or p == core: continue
		if Geometry2D.is_point_in_polygon(Geom.centroid(core.poly), p.poly):
			print("   ", p.tag if p.tag != "" else p.key, " ", p.kind, " order ", g.world.order.find(id), " vs core ", g.world.order.find(core.id))
	g.cam_override = at
	g.zoom_override = 1.2
	for i in 80: await process_frame
	Cap.save(root, "res://tests/out/nr95_core_zh.png")
	g.zoom_override = 0.45
	for i in 80: await process_frame
	Cap.save(root, "res://tests/out/nr95_core_wide_zh.png")
	quit()
