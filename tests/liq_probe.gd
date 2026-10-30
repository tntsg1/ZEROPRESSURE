extends SceneTree
# Debugging: what happens to liquid hydrogen spat from HG-170's relief valve.
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_liqprobe_save.json"
	SaveGame.allow_test = true
	_run()


func _process(_dt: float) -> bool:
	return finished


func _run() -> void:
	Game.contract = {}
	Game.start_ship = "hg170"
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 5:
		await process_frame
	var rv = g.world.tag("RV-2")
	var at: Vector2 = g.world.frame(rv) * Geom.centroid(rv.poly)
	g.liquids.spill(at, Vector2.UP, 0.02, "lh2", 4, 0.8, 2.0, false)
	print("PROBE after spill ", g.liquids.count(), " at ", at / Geom.M)
	for f in 8:
		for i in 10:
			await process_frame
		print("PROBE f%d n %d vol %.4f %s" % [f * 10, g.liquids.count(), g.liquids.total_volume(), g.liquids.blobs.map(func(b): return [b.pos / Geom.M, b.stuck, snappedf(b.vol, 0.0001)])])
	finished = true
