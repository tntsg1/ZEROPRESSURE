extends "res://tests/guide_check.gd"
# A hulk home in the tug yard, started from the terminal: the tug pushes it round into the berth.
# Skipped part-way (any key) it must be all the way in — user 2026-10-26: only x was reset, the hulk
# floated up to ~100 m off and the drone launched into its hull ("还是不能动"). Own saves only.
#   godot --headless --path . --fixed-fps 60 -s tests/yard_skip_check.gd


func _initialize() -> void:
	Career.path = "user://zp_test_yard_skip_career.json"
	SaveGame.path = "user://zp_test_yard_skip_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()


func _start() -> void:
	Scan.ON = false
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.cert_kind = "full"
	Career.data.history = [{"id": "TUG-001"}]
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "first_tow": true, "starmap_tour": true}
	Career.data.money = 200000.0
	Career.data.offers = Market.make(4242, Career.data)
	Career.save()
	var o: Dictionary = Career.data.offers[0]
	ShipMarket.tow_find(0)
	var a := ShipMarket.asset(str(o.id))
	Shipping.data().day = float(a.run.depart) + ShipMarket.tow_span(a) + 0.01
	ShipMarket.tick()
	a.seen_in = true
	Career.save()
	var idx := -1
	for k in Career.data.offers.size():
		if str(Career.data.offers[k].get("id", "")) == str(o.id):
			idx = k
	Career.accept(idx)
	Game.contract = Career.sign_active()
	Game.start_ship = str(Game.contract.get("ship", ""))
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": false, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)


func _run() -> void:
	Txt.zh = true
	for at in [100, 200, 400]:
		await _start()
		await _frames(at)
		var was: Vector2 = g.world.position
		check(g.state == "intro", "frame %d: the tug is pushing the hulk round (world at %s)" % [at, str(was.round())])
		g._end_intro()
		await _frames(30)
		check(g.world.position == Vector2.ZERO and g.state == "play", "skipped at frame %d: the hulk is all the way in the berth" % at)
		var p0: Vector2 = g.drone.global_position
		g.bot.move = Vector2(1, 0)
		await _frames(90)
		g.bot.move = Vector2.ZERO
		check(g.drone.alive and g.drone.global_position.distance_to(p0) > 2.0 * Geom.M and g.cam_override == null, "and the drone flies free, the camera with it (moved %.1f m)" % (g.drone.global_position.distance_to(p0) / Geom.M))
		g.queue_free()
		await _frames(4)
	print("YARD SKIP %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
