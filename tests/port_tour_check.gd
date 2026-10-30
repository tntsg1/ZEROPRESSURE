extends "res://tests/guide_check.gd"
# 83 号: the port tour. Due once the first ship is stripped; forced the first time (each card held
# at least 2 s, Esc does nothing); the camera goes to each district; eight cards, each with what it
# is and what it does; done, the camera is given back and it is not due again; replayed from the
# menu, Esc ends it. Own test saves only.
#   tools/run_test.sh tests/port_tour_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_port_tour_career.json"
	SaveGame.path = "user://zp_test_port_tour_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true}
	Career.save()
	var PT = preload("res://scripts/port_tour.gd")
	check(not PT.due(), "not before the first ship")
	Career.data.history = [{"id": "TUG-001"}]
	check(PT.due(), "due once the first ship is stripped")
	await _spawn()
	await _frames(20)
	g.start_port_tour(true)
	await _frames(10)
	var tour = g.port_tour
	check(tour != null and g.state == "porttour" and g.cam_override != null, "it starts: the camera over the port")
	Cap.save(root, "res://tests/out/port_tour_1_zh.png")
	tour.next()
	check(tour.i == 0, "the first time a card holds at least 2 s")
	tour.key(KEY_ESCAPE)
	check(g.port_tour != null and g.state == "porttour", "and Esc does not end it")
	var zones := []
	for k in tour.ORDER.size():
		var r: Array = tour.rows(tour.ORDER[k])
		check(str(r[0]) != "" and str(r[1]) != "" and str(r[2]) != "", "card %d (%s): %s" % [k + 1, tour.ORDER[k], str(r[0])])
	for k in tour.ORDER.size() - 1:
		await _frames(int(tour.MIN_S * 60.0) + 6)
		var before: Vector2 = g.cam_override
		tour.next()
		await _frames(30)
		zones.append(tour.ORDER[tour.i])
		if tour.ORDER[tour.i] in ["salvage", "power", "tug"]:
			Cap.save(root, "res://tests/out/port_tour_%s_zh.png" % tour.ORDER[tour.i])
		check(g.cam_override != before, "on to %s: the camera moves there" % tour.ORDER[tour.i])
	await _frames(int(tour.MIN_S * 60.0) + 6)
	tour.next()
	await _frames(4)
	check(g.port_tour == null and g.state == "play" and g.cam_override == null and g.zoom_override < 0.0, "done: the camera is given back")
	check(Career.data.seen.get("port_tour", false) and not PT.due(), "and it is not due again")
	# replayed from the menu: Esc ends it
	g.start_port_tour(false)
	await _frames(4)
	g.port_tour.key(KEY_ESCAPE)
	await _frames(4)
	check(g.port_tour == null and g.state == "play", "replayed from the menu, Esc ends it")
	print("PORT TOUR %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
