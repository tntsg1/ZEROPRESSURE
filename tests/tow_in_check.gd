extends "res://tests/guide_check.gd"
# 63 号: the tug bringing a hulk home is seen. Home while the operator is free in the empty berth:
# the berth goes into its bringing-in, the camera on the tug, the hulk moving in from open space
# to the waiting berth beside the dock, where it then stays drawn; seen once (not again after a
# reload); a key skips it; home while the terminal is open, it waits for the terminal to close;
# a tug sent out is seen leaving. Own saves only.
#   tools/run_test.sh tests/tow_in_check.gd --fixed-fps 60


func _initialize() -> void:
	# 68 号: this test reads the hulks the market drew by itself (before the star-map sweep)
	Scan.ON = false
	Career.path = "user://zp_test_tow_in_career.json"
	SaveGame.path = "user://zp_test_tow_in_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


# the first find on the page sent for and flown home (arrived cards go to the front of the page)
func _home(_i: int) -> String:
	var i := -1
	for k in Career.data.offers.size():
		if Career.data.offers[k].get("find", false):
			i = k
			break
	if i < 0:
		return ""
	var id := str(Career.data.offers[i].id)
	ShipMarket.tow_find(i)
	var a := ShipMarket.asset(id)
	Shipping.data().day = maxf(float(Shipping.data().day), float(a.run.depart) + float(a.run.tof) + 0.01)
	ShipMarket.tick()
	Career.save()
	return id


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 500000.0
	# 72 号: four berths in the tug yard (stage 2) for the three hulks this test brings home
	Career.data.port = {"salvage": 1, "trade": 1, "tug": 2}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.offers = Market.make(515, Career.data)
	Career.save()
	await _spawn()
	await _frames(20)
	var tt = g.tow_traffic
	check(tt != null, "the empty berth has its tug traffic")
	# ---- a tug sent out is seen leaving
	ShipMarket.tow_find(0)
	await _frames(40)
	check(not tt.departures.is_empty(), "a tug sent out is seen leaving")
	# ---- home: brought in on camera
	var asset_id := str(ShipMarket.data().assets[0].id)
	var a0 := ShipMarket.asset(asset_id)
	Shipping.data().day = float(a0.run.depart) + float(a0.run.tof) + 0.01
	ShipMarket.tick()
	Career.save()
	var t := 0
	while g.state != "towin" and t < 120:
		await _frames(1)
		t += 1
	await _frames(3)
	check(g.state == "towin" and str(tt.arrival.get("id", "")) == asset_id and g.cam_override != null, "home while free in the berth: the bringing-in starts, the camera on the tug")
	var p0: Vector2 = tt.path_at(0.05)
	var p1: Vector2 = tt.path_at(0.95)
	var berth: Vector2 = tt.moor(int(tt.arrival.slot), tt.arrival.stern, str(tt.arrival.get("ship", "")))  # 96 号: berth 1 may be the station's mouth
	check(p0.distance_to(berth) > 100.0 * Geom.M and p1.distance_to(berth) < 10.0 * Geom.M, "it comes in from open space to its berth in the tug yard")
	await _frames(int(tt.IN_T * 60.0 * 0.45))
	Cap.save(root, "res://tests/out/tow_in_mid_zh.png")
	# user 2026-10-27: the inside is not seen on the way in — only the hull's outside
	var n_pieces: int = Ship.load_data(str(ShipMarket.asset(asset_id).listing.offer.ship)).get("pieces", []).size()
	check(tt.arrival.polys.size() <= 6 and tt.arrival.polys.size() < n_pieces, "brought in as its outside only: %d outline(s), not its %d pieces" % [tt.arrival.polys.size(), n_pieces])
	t = 0
	while g.state == "towin" and t < int(tt.IN_T * 60.0) + 120:
		await _frames(1)
		t += 1
	check(g.state == "play" and ShipMarket.asset(asset_id).get("seen_in", false) and g.cam_override == null, "it ends at its yard berth, seen for good, the camera back")
	await _frames(40)
	check(tt._parked.any(func(p): return str(p.id) == asset_id), "the hulk stays drawn at its yard berth until it is started")
	g.cam_override = TugYard.slot_px(0) + Vector2(-20.0, 0.0) * Geom.M
	g.zoom_override = 0.4
	await _frames(40)
	Cap.save(root, "res://tests/out/tow_in_parked_zh.png")
	g.cam_override = null
	g.zoom_override = -1.0
	# ---- a key skips it
	var id2 := _home(0)
	t = 0
	while g.state != "towin" and t < 120:
		await _frames(1)
		t += 1
	await _frames(30)
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_ESCAPE
	g._unhandled_input(ev)
	await _frames(4)
	check(g.state == "play" and ShipMarket.asset(id2).get("seen_in", false), "Esc skips the bringing-in; the hulk is at its yard berth")
	# ---- home while the terminal is open: it waits
	if Career.data.offers.any(func(o): return o.get("find", false)):
		g.open_console("terminal")
		await _frames(6)
		var id3 := _home(0)
		await _frames(60)
		check(g.state != "towin" and not ShipMarket.asset(id3).get("seen_in", false), "home while the terminal is open: it waits")
		g.console_ui.close()
		t = 0
		while g.state != "towin" and t < 120:
			await _frames(1)
			t += 1
		check(g.state == "towin" and str(tt.arrival.get("id", "")) == id3, "the terminal closed: it is brought in")
		# user 2026-10-26: cut short by something else taking the game back to play — the camera stayed
		# on the tug's path for good. Now the bringing-in ends and the camera is given back
		g.state = "play"
		await _frames(45)
		check(tt.arrival.is_empty() and g.cam_override == null and g.zoom_override < 0.0, "cut short: the bringing-in ends and the camera comes back")
		await _frames(4)
	else:
		check(false, "(no third find to test the terminal case)")
		check(false, "(no third find)")
	# the hulk being stripped is never brought in again inside its own job
	var due_id := ""
	for a in ShipMarket.data().assets:
		if str(a.state) == "arrived":
			a.seen_in = false
			due_id = str(a.id)
			break
	if due_id != "":
		Career.data.active = {"id": due_id}
		check(preload("res://scripts/tow_traffic.gd").due().get("id", "") != due_id, "the hulk being stripped is not brought in again")
		Career.data.active = {}
	g.queue_free()
	await _frames(4)
	print("TOW IN %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
