extends SceneTree
# Stills of M-14's readable chain (96 号): the contract card with the ore and the crushing line and
# both ways; the board and the tags by the hopper (a gate open, then a wall off below the heap);
# the review. Writes tests/out/m14_chain_*.png. Own saves only.
#   tools/run_test.sh tests/m14_chain_shot.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var g


func _initialize() -> void:
	SaveGame.path = "user://zp_test_m14chainshot_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "m14"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(150)
	Cap.save(root, "res://tests/out/m14_chain_1_card.png")
	g.close_contract()
	g.state = "play"
	g.tutorial = null
	await _frames(40)
	var o = g.ore
	g.world.tag("GATE-2").door_open = true
	var wall = o.shell["HW-L"][0]
	for j in g.world.joints_of(wall).duplicate():
		g.world.kill_joint(j)
	g.world.relink()
	g.cam_override = Vector2(31.8, 1.0) * Geom.M
	g.zoom_override = 0.42
	g.drone.global_position = Vector2(31.8, -12.0) * Geom.M
	await _frames(150)
	Cap.save(root, "res://tests/out/m14_chain_2_board.png")
	g.finish_contract(true)
	await _frames(300)
	Cap.save(root, "res://tests/out/m14_chain_3_review.png")
	quit()
