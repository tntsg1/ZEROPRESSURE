extends SceneTree
# Stills of CF-90's readable chain (97 号): the contract card with the wall; the board and the
# bending bars with the end bay half emptied; the review. Writes tests/out/cf90_chain_*.png. Own saves only.
# (2026-11-12: the props are gone; this no longer places any.)
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
	for t in ["C11", "C12"]:
		_free(t)
		await _frames(5)
	g.cam_override = Vector2(36.0, 0.0) * Geom.M
	g.zoom_override = 0.36
	g.drone.global_position = Vector2(36.0, -14.0) * Geom.M
	await _frames(120)
	Cap.save(root, "res://tests/out/cf90_chain_2_board.png")
	await _frames(120)
	g.finish_contract(true)
	await _frames(300)
	Cap.save(root, "res://tests/out/cf90_chain_4_review.png")
	quit()
