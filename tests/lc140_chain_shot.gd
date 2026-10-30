extends SceneTree
# Stills of LC-140's readable chain (98 号): the contract card; the board and the cradle's tags
# (two locks off, a loose piece in the way out outlined red); the ship rolling out halfway on its
# winch cable; the review. Writes tests/out/lc140_chain_*.png. Own saves only.
#   tools/run_test.sh tests/lc140_chain_shot.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var g


func _initialize() -> void:
	SaveGame.path = "user://zp_test_lc140chainshot_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ctrl(id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "lc140"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(150)
	Cap.save(root, "res://tests/out/lc140_chain_1_card.png")
	g.close_contract()
	g.state = "play"
	g.tutorial = null
	await _frames(40)
	var ns = g.nested
	g.do_wrench(_ctrl("CL-1"))
	g.do_wrench(_ctrl("CL-2"))
	var junk = null
	for id in g.world.order:
		var q = g.world.pieces[id]
		if not q.gone and q.cls == "metal" and q.mass > 0.3 and q.mass < 2.0 and not ns.cfg.pieces.has(q.tag) and Geom.centroid(q.poly).x > 80.0 * Geom.M:
			junk = q
			break
	for j in g.world.joints_of(junk).duplicate():
		g.world.kill_joint(j)
	g.world.relink()
	await _frames(2)
	junk.body.global_position = Vector2(14.0, 0.0) * Geom.M
	junk.body.linear_velocity = Vector2.ZERO
	g.cam_override = Vector2(30.0, 2.0) * Geom.M
	g.zoom_override = 0.42
	g.drone.global_position = Vector2(30.0, -12.0) * Geom.M
	await _frames(90)
	Cap.save(root, "res://tests/out/lc140_chain_2_board.png")
	# made safe at once (the sequence itself is lc140_chain_check's), the way cleared, the winch
	junk.body.global_position = Vector2(200.0, -80.0) * Geom.M
	g.do_wrench(_ctrl("SK"))
	g.sys.set_fluid(str(ns.cfg.fuel), 0.0)
	for r in [str(ns.cfg.room), str(ns.cfg.hold)]:
		if g.sys.vols.has(r):
			g.sys.vols[r].n = 0.0
	g.do_wrench(_ctrl("CL-3"))
	g.do_wrench(_ctrl("CL-4"))
	g.world.tag(str(ns.cfg.door)).door_open = true
	await _frames(40)
	print("blockers ", ns.blockers())
	g.do_wrench(_ctrl("WINCH"))
	g.cam_override = Vector2(15.0, 2.0) * Geom.M
	await _frames(int(60.0 * float(ns.cfg.get("time", 12.0)) * 0.55))
	Cap.save(root, "res://tests/out/lc140_chain_3_out.png")
	await _frames(500)
	g.finish_contract(true)
	await _frames(300)
	Cap.save(root, "res://tests/out/lc140_chain_4_review.png")
	quit()
