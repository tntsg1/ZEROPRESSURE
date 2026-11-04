extends "res://tests/guide_check.gd"
# 68 号 §5: finding hulks on the star map. No hulks appear by themselves; a sector in reach is
# swept (~15 s) into 2–5 bare signals; analysing one (~10 s) tells a hulk from rock; a hulk goes
# on the found list with its tow quoted and the tug is sent for it from the map; a swept sector
# has nothing new for a while; the reach grows with the tug station and the trade district; the
# main line points at the star map; G opens it. Own saves only.
#   tools/run_test.sh tests/scan_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_scan_career.json"
	SaveGame.path = "user://zp_test_scan_save.json"
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
	Career.data.money = 300000.0
	Career.data.port = {"salvage": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.offers = Market.make(4242, Career.data)
	Career.save()
	check(Career.data.offers.is_empty(), "no hulks turn up by themselves")
	check(Keys.codes("starmap") == [KEY_G], "G opens the star map")
	# ---- reach
	check(Scan.reach() == 3, "three sectors in reach at the start (%d)" % Scan.reach())
	var far: int = Scan.order()[Orbits.STATIONS.size() - 1]
	var near: int = Scan.order()[0]
	check(not Scan.sweep(far).ok, "a sector out of reach cannot be swept")
	Career.data.port.tug = 1
	var r1 := Scan.reach()
	Career.data.port.trade = 1
	var r2 := Scan.reach()
	Career.data.port = {"salvage": 1}
	check(r1 == 5 and r2 == 8, "the tug station and the trade district reach further (%d, %d)" % [r1, r2])
	# ---- the main line: sweep the belt
	var st := Mainline._next_ship("再拆一艘船。")
	check(str(st.go) == "scan" and "星图" in str(st.text), "the next step points at the star map: %s" % str(st.text))
	# ---- the sweep takes its time
	check(Scan.sweep(near).ok and Scan.busy(), "a sweep starts")
	check(not Scan.sweep(Scan.order()[1]).ok, "one job at a time")
	check(Scan.advance(Scan.SWEEP_S - 1.0).is_empty() and Scan.busy(), "not done before its time")
	var done := Scan.advance(2.0)
	var sigs := Scan.signals(near)
	check(str(done.get("kind", "")) == "sweep" and sigs.size() >= 2 and sigs.size() <= 5, "swept: %d signals" % sigs.size())
	var unknown := sigs.all(func(s): return not s.known and "未知" in Scan.verdict(s))
	check(unknown, "the signals are bare until analysed")
	var ship_sig := ""
	var other_sig := ""
	for s in sigs:
		if str(s.kind) == "ship" and ship_sig == "":
			ship_sig = str(s.id)
		elif str(s.kind) != "ship" and other_sig == "":
			other_sig = str(s.id)
	check(ship_sig != "", "the first sweep finds at least one hulk")
	check(Scan.sweep_block(near) != "", "a swept sector has nothing new for a while: %s" % Scan.sweep_block(near))
	# ---- analysis: a hulk
	check(Scan.analyze(ship_sig).ok, "analysis starts")
	Scan.advance(Scan.ANALYZE_S + 0.1)
	var found := Scan.found()
	check(found.size() == 1, "the hulk is on the found list")
	var o: Dictionary = Career.data.offers[found[0]] if found.size() == 1 else {}
	check(o.get("find", false) and float(o.get("fee", 0.0)) > 0.0 and float(o.get("tow_days", 0.0)) > 0.0 and int(o.get("station", -1)) == near, "with its tow quoted (%s) from its station" % Pal.money(float(o.get("fee", 0.0))))
	check("已漂流" in Scan.verdict(Scan.sig_of(ship_sig)), "the signal reads as a hulk: %s" % Scan.verdict(Scan.sig_of(ship_sig)))
	# ---- analysis: rock or debris
	if other_sig != "":
		Scan.analyze(other_sig)
		Scan.finish()
		check(Scan.found().size() == 1 and not "已漂流" in Scan.verdict(Scan.sig_of(other_sig)), "rock is only rock: %s" % Scan.verdict(Scan.sig_of(other_sig)))
	# ---- saved and read back
	Career.save()
	var keep := JSON.stringify(JSON.parse_string(JSON.stringify(Career.data.scan)))
	Career.data = {}
	Career.load_or_new()
	check(JSON.stringify(JSON.parse_string(JSON.stringify(Career.data.get("scan", {})))) == keep, "the sweep is in the save")
	# ---- the star map, find mode
	await _spawn()
	await _frames(20)
	g.open_star_map("find")
	await _frames(10)
	var sm = g.console_ui
	check(sm != null and sm.mode == "find" and sm.find_box.visible, "the star map opens on finding hulks")
	sm.sel_sector = near
	sm.sel_sig = ship_sig
	sm._sig_key = ""
	sm._fill()
	await _frames(30)
	Cap.save(root, "res://tests/out/scan_found_zh.png")
	# the tug sent from the map
	var idx: int = Scan.found()[0]
	var id := str(Career.data.offers[idx].id)
	sm._send(idx)
	await _frames(4)
	check(str(ShipMarket.asset(id).get("state", "")) == "towing" and Scan.found().is_empty(), "the tug is sent from the map")
	# a sweep under way, for the picture
	var second: int = Scan.order()[1]
	sm.sel_sector = second
	sm.sel_sig = ""
	Scan.sweep(second)
	Scan.advance(Scan.SWEEP_S * 0.4)
	sm._sig_key = ""
	sm._fill()
	await _frames(20)
	Cap.save(root, "res://tests/out/scan_sweep_zh.png")
	sm.close()
	await _frames(4)
	g.queue_free()
	await _frames(4)
	print("SCAN %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
