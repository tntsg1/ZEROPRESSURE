extends SceneTree
# Stills of SA-200's readable chain (93 号): the contract card with the core asset and the two
# ways, the board and the corner tags while a corner winds (one panel cut taut first), the review
# at the settlement. Writes tests/out/sa200_chain_*.png. Own saves only.
#   tools/run_test.sh tests/sa200_chain_shot.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var g


func _initialize() -> void:
	SaveGame.path = "user://zp_test_sa200chainshot_save.json"
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
	Game.start_ship = "sa200"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(150)
	Cap.save(root, "res://tests/out/sa200_chain_1_card.png")
	g.contract_open = false
	g.state = "play"
	g.tutorial = null
	await _frames(30)
	var sl = g.sail
	for t in sl.cfg.panels:
		if str(sl.cfg.panels[t].quad) == "SE" and not sl.torn.has(t):
			sl.on_cut(g.world.tag(str(t)))
			break
	_switch("W-SE", false)
	_switch("GND", true)
	_switch("W-NW", false)
	_switch("F-NW", true)
	var w: Vector2 = sl._winch_at("NW")
	g.cam_override = w + Vector2(10.0, -6.0) * Geom.M
	g.zoom_override = 0.42
	g.drone.global_position = w + Vector2(6.0, -10.0) * Geom.M
	await _frames(400)
	Cap.save(root, "res://tests/out/sa200_chain_2_board.png")
	for k in 60 * 60:
		await process_frame
		if sl.furled("NW"):
			break
	await _frames(30)
	g.finish_contract(true)
	await _frames(300)
	Cap.save(root, "res://tests/out/sa200_chain_3_review.png")
	quit()
