extends SceneTree
# probe: the ship's attached keyed structure, for tests/plan_p_key_check.gd
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Career.path = "user://zp_test_plan_p_probe_career.json"
	SaveGame.path = "user://zp_test_plan_p_probe_save.json"
	SaveGame.allow_test = false
	Career.data = Career.fresh()
	Career.data.active = {}
	var ship: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "pod"
	Game.start_ship = ship
	Game.contract = {"id":"PLAN-P-PROBE","ship":ship,"fee":0,"time":900,"kit":{}}
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	for k in 8: await process_frame
	print("career=",g.career()," ctrls=",g.world.ctrls.keys())
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.gone or p.body != null or p.key == "" or p.door or p.cls == "equip": continue
		var r := Rect2(p.poly[0],Vector2.ZERO)
		for q in p.poly: r = r.expand(q)
		print("%s cls=%s rooms=%s bbox=%s" % [p.key,p.cls,str(g.plan._rooms_by_piece(p)),str(Rect2(r.position/Geom.M,r.size/Geom.M))])
	quit(0)
