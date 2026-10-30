extends "res://tests/guide_check.gd"
# user 2026-10-26 ("刚刚派了拖船去拖，然后应该给我弹出来那个星图"): a tug sent from the terminal closes
# it and opens the star map on the tug, following it; the first time its parts are framed one by
# one (the tug, the countdown, the close button), then not again; a tug sent from the star map
# itself follows too; the view lets go once the hand moves it. Own test saves only.
#   godot --path . --resolution 1600x900 --position -2600,40 -s tests/tow_watch_check.gd --fixed-fps 60


func _initialize() -> void:
	Scan.ON = false
	Career.path = "user://zp_test_tow_watch_career.json"
	SaveGame.path = "user://zp_test_tow_watch_save.json"
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
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "starmap_tour": true, "port_walk": true}
	Career.data.history = [{"id": "TUG-001"}]
	Career.data.port = {"salvage": 1, "trade": 1, "tug": 2}
	Career.data.offers = Market.make(4242, Career.data)
	Career.data.money = 50000.0
	Career.save()
	await _spawn()
	await _frames(20)
	g.open_console("terminal")
	await _frames(6)
	var term = g.console_ui
	var i := -1
	for k in term.offers().size():
		if term.offers()[k].get("find", false):
			i = k
			break
	check(i >= 0, "a found hulk on the terminal's list")
	var oid := str(term.offers()[i].id)
	term.take(i)
	await _frames(12)
	var sm = g.console_ui
	check(sm != null and sm.has_method("watch_tow") and sm.follow == oid and sm._follow_on, "sent from the terminal: the star map opens on the tug")
	check(sm != null and sm.tour_on() and sm._tour_kind == "tow", "the first time, its parts are framed")
	await _frames(40)
	Cap.save(root, "res://tests/out/tow_watch_1_zh.png")
	var au: Vector2 = sm._tow_au(oid)
	check(au.is_finite() and sm.pan.distance_to(au) < 0.05, "the view follows the tug (%.3f AU off)" % sm.pan.distance_to(au))
	var seen_steps := 0
	while sm.tour_on() and seen_steps < 6:
		sm._tour_next()
		seen_steps += 1
		await _frames(2)
		if seen_steps == 1:
			Cap.save(root, "res://tests/out/tow_watch_2_zh.png")
	check(seen_steps == 3 and Career.data.seen.get("tow_tour", false), "three parts, then marked seen (%d)" % seen_steps)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	ev.position = Vector2(300, 300)
	sm._map_input(ev)
	check(not sm._follow_on, "the hand on the view lets it go")
	sm.close()
	await _frames(6)
	# from the star map itself: follows, no tour the second time
	g.open_star_map("find")
	await _frames(6)
	sm = g.console_ui
	var j := -1
	for k in Career.data.offers.size():
		if Career.data.offers[k].get("find", false):
			j = k
			break
	if j >= 0:
		sm._send(j)
		await _frames(6)
		check(sm._follow_on and not sm.tour_on(), "sent from the star map: it follows, no tour again")
	print("TOW WATCH %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
