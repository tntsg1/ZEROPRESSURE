extends SceneTree
# Stills of CF-90's readable chain (97 号): the contract card with the wall and both ways; the
# board, the bending bars and a prop under bay 2 with bay 3 half emptied; a prop under bay 5
# bowing over its rating; the review. Writes tests/out/cf90_chain_*.png. Own saves only.
#   tools/run_test.sh tests/cf90_chain_shot.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var g


func _initialize() -> void:
	SaveGame.path = "user://zp_test_cf90chainshot_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _free(t: String) -> void:
	var p = g.world.tag(t)
	for j in g.world.joints_of(p).duplicate():
		g.world.kill_joint(j)
	g.world.relink()
	p.body.global_position += Vector2(0, -30.0) * Geom.M


func _place(tag: String) -> void:
	var gr = g.gear
	gr.sel = gr.carried_types().find("prop")
	var p = g.world.tag(tag)
	var at: Vector2 = g.world.frame(p) * Geom.centroid(p.poly)
	var tg: Dictionary = gr.target(at, {}, {"kind": "piece", "piece": p, "pos": at})
	if not tg.is_empty():
		gr.act(tg)


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "cf90"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(150)
	Cap.save(root, "res://tests/out/cf90_chain_1_card.png")
	g.close_contract()
	g.state = "play"
	g.tutorial = null
	await _frames(40)
	_place("C21")
	await _frames(10)
	for t in ["C31", "C32"]:
		_free(t)
		await _frames(5)
	g.cam_override = Vector2(36.0, 0.0) * Geom.M
	g.zoom_override = 0.36
	g.drone.global_position = Vector2(36.0, -14.0) * Geom.M
	await _frames(120)
	Cap.save(root, "res://tests/out/cf90_chain_2_board.png")
	_place("C51")
	g.cam_override = Vector2(62.0, 0.0) * Geom.M
	await _frames(40)
	Cap.save(root, "res://tests/out/cf90_chain_3_over.png")
	await _frames(120)
	g.finish_contract(true)
	await _frames(300)
	Cap.save(root, "res://tests/out/cf90_chain_4_review.png")
	quit()
