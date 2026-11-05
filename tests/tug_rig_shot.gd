extends "res://tests/guide_check.gd"
# 2026-11-05 (user, the third time: "这尾部怎么不是拖船，还是这个推进器啊？"): the company's own tug
# brings a hulk home on its line and arm, two of them a long one, and pushes a hull into the dock
# with its fenders on the stern (scripts/tug_rig.gd). Shots of each, wide as the cut is framed and
# close; the tug's burns read from its real acceleration; it ends home on its deck. Own saves only.
#   tools/run_test.sh tests/tug_rig_shot.gd --fixed-fps 60

const OUT := "res://tests/out/tug_rig/"
var frame_ms: Array = []


func _initialize() -> void:
	Scan.ON = false
	Career.path = "user://zp_test_tug_rig_career.json"
	SaveGame.path = "user://zp_test_tug_rig_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


# a still of the bringing-in held where it is, the camera put on `at` at `zoom`
func _close(at: Vector2, zoom: float, name: String) -> void:
	g.tow_traffic.shot = {"cam": at, "zoom": zoom}
	await _frames(80)
	Cap.save(root, OUT + name)
	g.tow_traffic.shot = {}


# a still of the port, the camera on `at` at `zoom`
func _look(at: Vector2, zoom: float, name: String) -> void:
	g.cam_override = at
	g.zoom_override = zoom
	await _frames(90)
	Cap.save(root, OUT + name)
	g.cam_override = null
	g.zoom_override = -1.0


func _bring(ship: String) -> String:
	var i := -1
	for k in Career.data.offers.size():
		if Career.data.offers[k].get("find", false):
			i = k
			break
	if i < 0:
		# no find left on the page: a fresh page, one of its offers made a find
		Career.data.offers = Market.make(900 + ShipMarket.data().assets.size(), Career.data)
		i = 0
		Career.data.offers[0].find = true
	var id := str(Career.data.offers[i].id)
	if ship != "":
		Career.data.offers[i].ship = ship
	var r := ShipMarket.tow_find(i)
	if not bool(r.get("ok", true)):
		print("  tow_find refused: %s" % str(r.get("reason", "")))
	var a := ShipMarket.asset(id)
	if a.is_empty():
		return ""
	if ship != "":
		a.listing.offer.ship = ship
		a.ship = ship
	Shipping.data().day = maxf(float(Shipping.data().day), float(a.run.depart) + float(a.run.tof) + 0.01)
	ShipMarket.tick()
	Career.save()
	return id


func _towin(id: String, stills: Dictionary) -> void:
	var tt = g.tow_traffic
	var t := 0
	while g.state != "towin" and t < 240:
		await _frames(1)
		t += 1
	check(g.state == "towin" and str(tt.arrival.get("id", "")) == id, "%s: brought in on camera" % id)
	if g.state != "towin":
		return
	var tugs: Array = tt.arrival.tugs.map(func(x): return str(x.name))
	print("  %s (%s, slot %d, mouth %s): towed by %s" % [id, str(tt.arrival.ship), int(tt.arrival.slot), str(tt.arrival.mouth), ", ".join(tugs)])
	for tg in tt.arrival.tugs:
		if int(tg.i) >= 0:
			check(tt.W.held.has(int(tg.i)) and float(tt.W.dock[int(tg.i)]) <= 0.001, "%s is out on the tow, not on its deck berth" % tg.name)
	var keys: Array = stills.keys()
	keys.sort()
	var burn_main := false
	var burn_retro := false
	var last := Time.get_ticks_usec()
	while g.state == "towin":
		await process_frame
		var now := Time.get_ticks_usec()
		frame_ms.append((now - last) / 1000.0)
		last = now
		if tt.arrival.is_empty():
			break
		var at := float(tt.arrival.t)
		if not tt.arrival.get("cast", false):
			var acc: Vector2 = tt._tug_acc(0, at)
			if acc.x > 3.0:
				burn_main = true
			if acc.x < -3.0:
				burn_retro = true
		if not keys.is_empty() and at >= float(keys[0]):
			var k = keys.pop_front()
			Cap.save(root, OUT + str(stills[k]) + "_wide.png")
			if not tt.arrival.get("cast", false):
				var mid := Vector2.ZERO
				for j in tt.arrival.tugs.size():
					mid += tt._tug_px(j, float(tt.arrival.t)) / tt.arrival.tugs.size()
				await _close(mid + Vector2(-9.0, -2.5) * Geom.M, 0.8 if tt.arrival.tugs.size() == 1 else 0.5, str(stills[k]) + "_close.png")
	check(burn_main and burn_retro, "on the way in the tug's main drive speeds it up and its retros brake it")
	check(g.state == "play" and ShipMarket.asset(id).get("seen_in", false), "%s lies at its berth, seen" % id)


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 900000.0
	Career.data.port = {"salvage": 1, "trade": 1, "tug": 2}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "first_tow": true, "starmap_tour": true}
	Career.data.offers = Market.make(515, Career.data)
	Career.save()
	await _spawn()
	await _frames(30)
	# ---- one tug: on the line, then braking on the arm
	var id1 := _bring("")
	await _towin(id1, {1.8: "1_tow_line", 5.0: "2_tow_arm_brake"})
	# home: it flies to the gate and in to its berth
	var t := 0
	while not g.tow_traffic.flights.is_empty() and t < 900:
		await _frames(1)
		t += 1
	await _frames(240)
	check(g.tow_traffic.W.held.is_empty() and float(g.tow_traffic.W.dock[0]) > 0.5, "the tug flew home to the gate and in to its berth (dock %.2f)" % float(g.tow_traffic.W.dock[0]))
	var box := PortStructure.box("tug")
	await _look(box.position + Vector2(22.0, 8.0) * Geom.M, 0.55, "3_home_on_deck.png")
	# ---- two tugs: a long hulk (both home and charged)
	Career.data.tug_charge = {"TG-1": 1.0, "TG-2": 1.0}
	await _frames(400)
	# a berth that takes a 70 m hulk (what the market checks before it sends a tug)
	var up: Dictionary = Career.data.get("upgrades", {})
	up["berth88"] = true
	Career.data.upgrades = up
	var id2 := _bring("fx70")
	await _towin(id2, {2.0: "4_two_tugs_line", 4.9: "5_two_tugs_arm"})
	# ---- skipped part-way: the tug is cast off at once and still goes home
	var id3 := _bring("")
	t = 0
	while g.state != "towin" and t < 240:
		await _frames(1)
		t += 1
	await _frames(90)
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_ESCAPE
	g._unhandled_input(ev)
	await _frames(4)
	check(g.state == "play" and ShipMarket.asset(id3).get("seen_in", false), "Esc skips the bringing-in; the hulk at its berth")
	check(g.tow_traffic.W.held.is_empty() or not g.tow_traffic.flights.is_empty(), "skipped: every tug out is flying home, none left hanging")
	frame_ms.sort()
	if not frame_ms.is_empty():
		print("  tow-in frames: median %.2f ms, P95 %.2f ms, max %.2f ms (%d frames)" % [frame_ms[frame_ms.size() / 2], frame_ms[int(frame_ms.size() * 0.95)], frame_ms[frame_ms.size() - 1], frame_ms.size()])
	g.queue_free()
	await _frames(4)
	# ---- the opening: the tug pushes the hull round the station and into the dock
	Career.data.offers = Market.make(4242, Career.data)
	var o: Dictionary = Career.data.offers[0]
	ShipMarket.tow_find(0)
	var a := ShipMarket.asset(str(o.id))
	Shipping.data().day = float(a.run.depart) + ShipMarket.tow_span(a) + 0.01
	ShipMarket.tick()
	a.seen_in = true
	Career.data.tug_charge = {"TG-1": 1.0, "TG-2": 1.0}
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
	var pushes := {int(60.0 * g.PUSH_T * 0.12): "6_push_round", int(60.0 * (g.PUSH_T + 2.3)): "7_push_into_dock", int(60.0 * g.PUSH_T * 0.55): "6b_push_round_mid"}
	var f := 0
	var saw := false
	frame_ms = []
	var last := Time.get_ticks_usec()
	while f < int(60.0 * (g.PUSH_T + 7.0)) and g.state == "intro":
		await process_frame
		var now := Time.get_ticks_usec()
		frame_ms.append((now - last) / 1000.0)
		last = now
		f += 1
		if pushes.has(f):
			Cap.save(root, OUT + str(pushes[f]) + "_wide.png")
			var tp: Vector2 = g.dock.tug_pos()
			print("  %s: tug at %s m, tugs %s" % [str(pushes[f]), str((tp / Geom.M).round()), str(g.dock._rig_tugs.map(func(x): return x.name))])
			if tp != Vector2.INF:
				saw = true
	check(saw, "the opening: the tug is on the stern pushing")
	frame_ms.sort()
	if not frame_ms.is_empty():
		print("  opening frames: median %.2f ms, P95 %.2f ms, max %.2f ms (%d frames)" % [frame_ms[frame_ms.size() / 2], frame_ms[int(frame_ms.size() * 0.95)], frame_ms[frame_ms.size() - 1], frame_ms.size()])
	print("TUG RIG %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
