extends "res://tests/guide_check.gd"
# The tow's route ends on the port where the port is when the tug docks (user 2026-11-10, 截图：回港航线
# 绕了大半圈，箭头停在右侧空白处，零压港在下方：“要把星图的目标定成零压港，而不是莫名其妙的一个目标”).
# The tug flies a shortened span (the first tow at most FIRST_S), the arc was worked out for the true
# flight: it ended on the port's place on a later day. At several times along the tow: the drawn end
# within a few pixels of the port at the arrival time, the tug on the drawn line, docking on the port.
# The freighters on the shipping page: their arcs end on their target at their own arrival.
# Own test saves only.  tools/run_test.sh tests/starmap_tow_route_check.gd [--shot NAME]


func _initialize() -> void:
	Career.path = "user://zp_test_tow_route_career.json"
	SaveGame.path = "user://zp_test_tow_route_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _shot_name() -> String:
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	for i in args.size():
		if args[i] == "--shot" and i + 1 < args.size():
			return args[i + 1]
	return "after"


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.offers = []
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "starmap_tour": true, "tow_tour": true}
	Career.data.money = 20000.0
	Career.save()
	Scan.ON = true
	await _spawn()
	await _frames(20)
	g.open_star_map("find")
	await _frames(20)
	var sm = g.console_ui
	# the farthest sector reached: the longest arc
	var ord: Array = Scan.order()
	var far: int = ord[mini(Scan.reach(), ord.size()) - 1]
	sm.sel_sector = far
	Scan.sweep(far)
	Scan.advance(Scan.SWEEP_S + 0.5)
	for sg in Scan.signals(far):
		Scan.analyze(str(sg.id))
		Scan.advance(Scan.ANALYZE_S + 0.5)
	sm._sig_key = ""
	sm._fill()
	await _frames(10)
	var send: Button = null
	for b in sm.find_box.find_children("*", "Button", true, false):
		if not b.disabled and not b.is_queued_for_deletion() and "派拖船去拖" in b.text:
			send = b
			break
	check(send != null, "a tug button to press")
	if send == null:
		quit(1)
		return
	send.pressed.emit()
	await _frames(10)
	var a: Dictionary = {}
	for x in ShipMarket.data().assets:
		if str(x.state) == "towing":
			a = x
	check(not a.is_empty(), "a tow under way")
	# the whole route in view, drawn on
	sm._follow_on = false
	sm.view_zt = 1.0
	sm.pan_t = Vector2.ZERO
	await _frames(100)
	Cap.save(root, "res://tests/out/starmap_tow_route_%s.png" % _shot_name())
	if not sm.has_method("_tow_path"):
		print("STARMAP TOW ROUTE (before shot only)")
		quit(0)
		return
	var arr_day := float(a.run.depart) + ShipMarket.tow_span(a)
	var worst := 0.0
	var worst_tug := 0.0
	for f in [0.0, 0.25, 0.5, 0.8, 0.97]:
		var day: float = float(a.run.depart) + ShipMarket.tow_span(a) * float(f)
		Shipping.data().day = day
		await _frames(3)
		var path: Dictionary = sm._tow_path(a)
		var end_px: Vector2 = sm._to(sm._path_at(path, 1.0))
		var port_px: Vector2 = sm._to(Orbits.pos(Orbits.PORT, arr_day))
		worst = maxf(worst, end_px.distance_to(port_px))
		# the tug is on the drawn line at its share of the way
		var tug_px: Vector2 = sm._to(sm._tow_au(str(a.id)))
		# (the clock ran on over the frames waited: the share of the way now)
		var share := clampf((Shipping.day() - float(a.run.depart)) / ShipMarket.tow_span(a), 0.0, 1.0)
		var on_px: Vector2 = sm._to(sm._path_at(path, share))
		worst_tug = maxf(worst_tug, tug_px.distance_to(on_px))
	check(worst < 3.0, "the route ends on the port at the arrival time, at every time along the tow (worst %.2f px)" % worst)
	check(worst_tug < 3.0, "the tug rides the drawn route (worst %.2f px)" % worst_tug)
	# the start: the hulk's station on the departure day
	var path0: Dictionary = sm._tow_path(a)
	var st_px: Vector2 = sm._to(Orbits.pos(Orbits.station(int(a.listing.station)), float(a.run.depart)))
	check(sm._to(sm._path_at(path0, 0.0)).distance_to(st_px) < 3.0, "it starts at the hulk's station on the departure day")
	# docking: the tug is on the port's ring
	Shipping.data().day = arr_day - 0.0001
	await _frames(3)
	var dock: float = sm._to(sm._tow_au(str(a.id))).distance_to(sm._to(Orbits.pos(Orbits.PORT, Shipping.day())))
	check(dock < 3.0, "the moment it docks, the tug is on the port (%.2f px)" % dock)
	# the shipping page: each freighter's arc ends on its target at its own arrival
	var sworst := 0.0
	var n := 0
	# no trade in this career: two freighters the way Shipping makes them (one in, one out), checked
	# without a frame passing and taken off again
	var fake: Array = []
	if Shipping.live().is_empty():
		var st2: int = ord[0]
		fake.append({"id": "FV-T1", "state": "inbound", "station": st2, "run": Orbits.transfer(Orbits.station(st2), Orbits.PORT, Shipping.day())})
		fake.append({"id": "FV-T2", "state": "leaving", "station": far, "run": Orbits.transfer(Orbits.PORT, Orbits.station(far), Shipping.day())})
		Shipping.data().ships.append_array(fake)
	for s in Shipping.live():
		if not (str(s.state) in ["inbound", "leaving"]):
			continue
		var run: Dictionary = s.run
		var end: Vector2 = sm._to(Orbits.on_transfer(run, 1.0))
		var target: Array = Orbits.PORT if str(s.state) == "inbound" else Orbits.station(int(s.get("station", -1)))
		if str(s.state) == "leaving" and int(s.get("station", -1)) < 0:
			continue
		sworst = maxf(sworst, end.distance_to(sm._to(Orbits.pos(target, float(run.depart) + float(run.tof)))))
		n += 1
	for x in fake:
		Shipping.data().ships.erase(x)
	check(n >= 2 and sworst < 3.0, "the shipping page's arcs end on their targets (%d ships, worst %.2f px)" % [n, sworst])
	print("STARMAP TOW ROUTE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
