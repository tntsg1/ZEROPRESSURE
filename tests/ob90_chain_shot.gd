extends SceneTree
# Stills of OB-90's readable chain (94 号): the contract card with the mirror and the two ways, the
# board and the tags by the mirror (a cut close by with the cover up first, then the locks on and
# the outer upper backplane cut free), the review. Writes tests/out/ob90_chain_*.png. Own saves only.
#   tools/run_test.sh tests/ob90_chain_shot.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var g


func _initialize() -> void:
	SaveGame.path = "user://zp_test_ob90chainshot_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _switch(id: String, on: bool) -> void:
	g.sys.set_switch(id, on)
	g.world.ctrls[id].state = on


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "ob90"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(150)
	Cap.save(root, "res://tests/out/ob90_chain_1_card.png")
	g.contract_open = false
	g.state = "play"
	g.tutorial = null
	await _frames(40)
	var op = g.optics
	var mc: Vector2 = g.world.frame(g.world.tag("PM-U5")) * Geom.centroid(g.world.tag("PM-U5").poly)
	var near = null
	var best := INF
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.gone or str(p.name_key) in ["p_ob_segment", "p_ob_actuator", "p_ob_backplane"]:
			continue
		var d: float = (g.world.frame(p) * Geom.centroid(p.poly)).distance_to(mc)
		if d < best:
			best = d
			near = p
	op.on_cut(near)
	for r in ["1", "2", "3"]:
		_switch(str(op.cfg.locks[r]), true)
	g.cam_override = mc + Vector2(8.0, 0.0) * Geom.M
	g.zoom_override = 0.5
	g.drone.global_position = mc + Vector2(12.0, -6.0) * Geom.M
	await _frames(240)
	Cap.save(root, "res://tests/out/ob90_chain_2_board.png")
	g.finish_contract(true)
	await _frames(300)
	Cap.save(root, "res://tests/out/ob90_chain_3_review.png")
	quit()
