extends "res://tests/guide_check.gd"
# 131 号: the stores terminal in the berth and its cable to the cargo district; the "fly there" guides'
# way on the floor, the arrow on the screen's edge with the metres left, the way in the card's title,
# all folded away at the target. Own test saves only.
#   tools/run_test.sh tests/guide_way_shot.gd --fixed-fps 60

const OUT := "res://tests/out/guide_way_%s.png"
const GuideWay = preload("res://scripts/guide_way.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_guide_way_career.json"
	SaveGame.path = "user://zp_test_guide_way_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _shot(name: String) -> void:
	await _frames(4)
	Cap.save(root, OUT % name)
	print("SHOT ", ProjectSettings.globalize_path(OUT % name))


func _put(p: Vector2, settle := 40) -> void:
	g.drone.global_position = p
	g.drone.linear_velocity = Vector2.ZERO
	# the view straight onto it (a teleport would leave the camera's spring swinging)
	g.cam_pos = p
	g.cam_vel = Vector2.ZERO
	await _frames(settle)


func _run() -> void:
	Txt.zh = true
	Game.coach_in_tests = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	# the stores guide waits for its own part (one guide at a time, as in the game)
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_tour": true, "store_guide_done": true}
	Career.data.money = 20000.0
	Career.data.history = [{"id": "TUG-001"}]
	Career.save()
	await _spawn()
	await _frames(20)
	var M := Geom.M
	# ---- the stores terminal and its cable
	var tc: Vector2 = Consoles.rack_centre()
	await _put(tc + Vector2(3.0, 0.5) * M)
	await _shot("1_terminal")
	await _put(tc + Vector2(0.6, 0.8) * M)
	check(g.consoles.near() == "rack", "the drone at the terminal: E opens the stores")
	await _shot("2_terminal_near")
	g.zoom_target = 0.32
	await _put(tc + Vector2(18.0, -6.0) * M, 90)
	await _shot("3_cable_berth")
	g.zoom_target = 0.14
	await _put(PortStructure.centre() + Vector2(10.0, 40.0) * M, 120)
	await _shot("4_cable_port")
	g.zoom_target = 0.22
	await _put(PortStructure.centre() + Vector2(0.0, 34.0) * M, 120)
	await _shot("4b_cable_ring")
	g.zoom_target = Game.CAM_ZOOM
	await _put(tc + Vector2(12.0, 0.0) * M, 60)
	# ---- the way: the port walk's first step (131 号: the berth's own shuttle stop, not the corridor)
	g.start_port_walk(true)
	await _frames(10)
	var wk = g.port_walk
	check(wk != null and wk.kind() == "station" and wk.zone() == "salvage", "the walk starts at the berth's shuttle stop (%s)" % (wk.kind() if wk != null else "-"))
	# the step's own 2 s look at the target (port_walk._begin, plan_focus) over, back on the drone
	await _put(tc + Vector2(12.0, 0.0) * M, 150)
	print("TITLE station: ", wk.title.text, "  way ", wk.way.length_m, " m")
	check(wk.title.text.begins_with("往") and wk.title.text.find("拆船区接驳站") >= 0, "the title says the way: %s" % wk.title.text)
	check(wk.way.show > 0.9, "the floor arrows are up (%.0f m)" % wk.way.length_m)
	await _shot("5_station_step")
	# at the stop: folded away
	await _put(Tram.station_at("salvage"), 40)
	print("step now ", wk.kind(), " ", wk.zone(), " title ", wk.title.text, " show ", wk.way.show)
	check(wk.kind() == "ride" and wk.zone() == "ring" and wk.way.show < 0.05, "at the stop: the ride to the ring next, the way folded away")
	await _shot("6_at_stop")
	# a district far off: the way round the ring's deck (the cargo district's console)
	var w2 := GuideWay.new()
	var path: PackedVector2Array = GuideWay.route(g, Vector2(wk._gate_x(), wk._rail_y() + 4.0 * M), PortStructure.console_spot("trade"))
	print("ROUTE berth→trade: ", path.size(), " points, ", int(GuideWay._len(path) / M), " m")
	check(path.size() >= 6, "berth to trade: out the gate, up, round the deck, down the corridor, in the door")
	# the stores guide: from the port back to the terminal
	wk.stop()
	await _frames(4)
	StoreBook.ON = true
	Career.data.seen.erase("store_guide_done")
	g._store_guide()
	await _frames(4)
	if g.store_guide != null:
		# from the ring: down the berth's corridor, through the gate, to the terminal
		await _put(PortStructure.centre() + Vector2(0.0, PortArt.HUB_R + 4.0) * PortStructure.M(), 90)
		print("STORE TITLE: ", g.store_guide.title.text, "  way ", g.store_guide.way.length_m, " m ", g.store_guide.way.path.size(), " points")
		check(g.store_guide.way.show > 0.9 and g.store_guide.way.path.size() >= 4, "from the ring: the way down the corridor and in at the gate, the edge arrow up")
		await _shot("7_store_from_ring")
		await _put(tc + Vector2(30.0, -4.0) * M, 60)
		await _shot("9_store_guide")
		await _put(tc + Vector2(1.0, 0.6) * M, 60)
		check(g.store_guide.way.show < 0.05, "at the terminal the way has folded away (%.2f)" % g.store_guide.way.show)
		await _shot("10_store_arrived")
	else:
		check(false, "the stores guide did not start")
	print("DONE %d/%d" % [checks - fails, checks])
	quit(1 if fails > 0 else 0)
