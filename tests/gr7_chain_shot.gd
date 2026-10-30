extends SceneTree
# Stills of GR-7's readable chain (95 号): the contract card with both groups and both ways, the
# board after a knock on the auxiliary engine and the beam through a crate, the review. Writes
# tests/out/gr7_chain_*.png. Own saves only.
#   tools/run_test.sh tests/gr7_chain_shot.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var g


func _initialize() -> void:
	SaveGame.path = "user://zp_test_gr7chainshot_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "gr7"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(150)
	Cap.save(root, "res://tests/out/gr7_chain_1_card.png")
	g.close_contract()
	g.state = "play"
	g.tutorial = null
	await _frames(40)
	var eng = g.world.tag("ENG-F")
	g._dent(eng, maxf(0.0, eng.cond - 0.3), "dv_impact")
	var crate = g.world.tag("C-02")
	var at: Vector2 = g.world.frame(crate) * Geom.centroid(crate.poly)
	g.on_cut_into(crate, at)
	g.cam_override = at
	g.zoom_override = 0.5
	await _frames(200)
	Cap.save(root, "res://tests/out/gr7_chain_2_board.png")
	g.finish_contract(true)
	await _frames(300)
	Cap.save(root, "res://tests/out/gr7_chain_3_review.png")
	quit()
