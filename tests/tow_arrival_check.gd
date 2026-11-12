extends "res://tests/guide_check.gd"
# 137 号 (user 2026-11-11: "我买那个最小的货运吊舱，星图上面显示它已经到了，但实际上它完全没有动画，也完全
# 到不了"): every ship the hulk market can sell, bought and towed home: its tow runs out, the asset
# comes home (arrived), the tug brings it in on camera in the empty berth, it lies in its tug-yard
# berth, and its card waits on the contracts page ready to start. POD first, with a shot of it in
# its berth. Own test saves only.
#   tools/run_test.sh tests/tow_arrival_check.gd --fixed-fps 60 [-- pod,gr7]

var probe := false
var tug_stage := 2
var early := false     # the career as a new player has it (the guides not seen)
var unseen := false
var from_feed := true
var held_n := 0    # 到港 while a page is open, its card started before the tug brought it in


func _initialize() -> void:
	Career.path = "user://zp_test_tow_arrival_career.json"
	SaveGame.path = "user://zp_test_tow_arrival_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _fresh() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 50000000.0
	Career.data.port = {"salvage": 2, "trade": 1, "tug": tug_stage, "power": 1, "cargo": 1, "process": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true, "starmap_tour": true}
	if early:
		Career.data.seen = {"belt_prelude": true, "intro": true}
		Career.data.drill = {}
	Career.data.offers = []
	var ups: Dictionary = Career.data.get("upgrades", {})
	for k in ["berth88", "berth120", "berth200", "berth620"]:
		ups[k] = true
	Career.data.upgrades = ups
	Career.save()


# a listing of this very ship, bought: the asset under tow. From the endless feed when one of this
# ship is up there (as the player buys: id "SM-F…"), else a listing made for it
func _buy(ship: String) -> Dictionary:
	if from_feed:
		for m in ShipMarket.feed(Shipping.day()):
			if str(m.ship) == ship and ShipMarket.take(str(m.id)):
				var r0 := ShipMarket.buy(str(m.id))
				if r0.ok:
					return ShipMarket.asset(str(m.id))
	return _buy_made(ship)


func _buy_made(ship: String) -> Dictionary:
	# one draw of this ship (the full contract check on ARK-01 takes seconds a try)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var o := Market.offer(rng, Career.data, 2, {}, "full", ship)
	o.erase("_ship")
	if o.is_empty():
		return {}
	var d := ShipMarket.data()
	var id := "SM-T%s" % ship.to_upper()
	o.id = id
	o.bought = true
	o.drift_years = 0
	o.fee = 0.0
	var now := Shipping.day()
	d.listings.append({"id": id, "offer": o, "station": 0, "price": 1000.0, "statements": [{"cat": "structure", "how": "clean", "traps": []}, {"cat": "systems", "how": "clean", "traps": []}],
		"title": {"kind": ""}, "rating": {"score": 9, "agency": "bsi", "day": now, "paid": false}, "inspected": {}, "listed": now, "expires": now + 9999.0, "floor": 900.0})
	var r := ShipMarket.buy(id)
	if not r.ok:
		print("  buy %s refused: %s" % [ship, str(r.get("reason", ""))])
		return {}
	return ShipMarket.asset(id)


func _trip(ship: String) -> Array:
	var a := _buy(ship)
	if a.is_empty():
		return [false, "not bought"]
	var id := str(a.id)
	# the tow runs out now
	a.run.depart = Shipping.day() - ShipMarket.tow_span(a) - 1.0
	if unseen:
		g.open_star_map("find")
		await _frames(150)
		var a1 := ShipMarket.asset(id)
		print("    over the star map: state %s, seen_in %s" % [str(a1.get("state")), str(a1.get("seen_in", false))])
		g.console_ui.close()
		var r2: Array = await _start_job(id, ship)
		return r2
	var log := []
	var saw_towin := false
	var t := 0
	while t < 1200:
		t += 1
		await process_frame
		if g.state == "towin":
			saw_towin = true
		var a2 := ShipMarket.asset(id)
		if t % 60 == 0 and probe:
			print("    t=%d state=%s game=%s seen_in=%s arrival=%s parked=%s in_berth=%s console=%s walk=%s store_guide=%s port_view=%s part=%s" % [t, str(a2.get("state")), g.state, str(a2.get("seen_in", false)), str(g.tow_traffic.arrival.get("id", "")) if g.tow_traffic != null else "-", str(g.tow_traffic._parked.map(func(p): return p.id)) if g.tow_traffic != null else "-", str(g.in_berth()), str(g.console_ui), str(g.walk_on()), str(g.store_guide_on()), str(g.port_view), preload("res://scripts/port_walk.gd").due_part(g)])
		if a2.get("seen_in", false) and g.state == "play" and g.tow_traffic.arrival.is_empty() and t > 30:
			break
	var a3 := ShipMarket.asset(id)
	var held := str(a3.get("state", "")) == "held"
	var parked: bool = g.tow_traffic != null and g.tow_traffic._parked.any(func(p): return str(p.id) == id)
	var home: bool = str(a3.get("state", "")) in ["arrived", "held"] and a3.get("seen_in", false) and saw_towin and parked
	if held:
		held_n += 1
		# a held hulk: the notice says why and the market pays it; then it is free
		var paid := ShipMarket.pay_title(id)
		if not paid.ok:
			return [false, "held, not paid: %s" % str(paid.get("reason", ""))]
	ShipMarket.cards()
	var card: bool = Career.data.get("offers", []).any(func(o): return str(o.get("id", "")) == id)
	var head := "%s · brought in on camera %s · in its berth %s · card %s · %d frames" % ["held, paid" if held else "arrived", str(saw_towin), str(parked), str(card), t]
	if not (home and card):
		return [false, head]
	if ship == "pod" and not unseen:
		g.cam_override = TugYard.slot_px(int(a3.get("yard", 0)), "pod")
		g.cam_pos = g.cam_override
		g.zoom_override = 0.5
		await _frames(60)
		Cap.save(root, "res://tests/out/tow_arrival_pod_berth_tug%d%s.png" % [tug_stage, "_held" if held else ""])
		g.cam_override = null
		g.zoom_override = -1.0
	var job: Array = await _start_job(id, ship)
	return [job[0], head + " · " + str(job[1])]


# the card taken and started the way the loadout page starts it; the job's own opening runs
func _start_job(id: String, ship: String) -> Array:
	var idx := -1
	var offs: Array = Career.data.get("offers", [])
	for i in offs.size():
		if str(offs[i].get("id", "")) == id:
			idx = i
	if idx < 0:
		return [false, "no card"]
	var o: Dictionary = Career.accept(idx)
	if o.is_empty():
		return [false, "card not taken"]
	g.queue_free()
	await _frames(4)
	Game.contract = Career.active()
	Game.start_ship = str(Career.active().get("ship", ship))
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	var states := []
	var t := 0
	while t < 1500:
		t += 1
		await process_frame
		if states.is_empty() or states[-1] != g.state:
			states.append(g.state)
			if probe:
				print("    job t=%d state=%s in_berth=%s ship=%s" % [t, g.state, str(g.in_berth()), str(g.ship.get("id", ""))])
		if g.state == "play" and not g.in_berth() and t > 120:
			break
	if ship == "pod":
		Cap.save(root, "res://tests/out/tow_arrival_%s_job.png" % ship)
	var ok: bool = g.state == "play" and not g.in_berth() and str(g.ship.get("id", "")) == ship
	return [ok, "job: states %s, %d frames" % [str(states), t]]


func _run() -> void:
	var ids: Array = []
	for a in OS.get_cmdline_user_args():
		if a == "unseen":
			unseen = true
			continue
		if a == "early":
			early = true
			continue
		if a.begins_with("tug="):
			tug_stage = int(a.substr(4))
			continue
		ids.append_array(Array(a.split(",")).filter(func(x): return x != ""))
	probe = not ids.is_empty()
	if ids.is_empty():
		for e in Market.POOL:
			if Ship.available(str(e[0])):
				ids.append(str(e[0]))
		ids.erase("pod")
		ids.push_front("pod")
	var fails_list: Array = []
	for ship in ids:
		_fresh()
		await _spawn()
		await _frames(30)
		var r: Array = await _trip(str(ship))
		check(r[0], "%s: bought, towed home, brought in, in its berth, ready (%s)" % [ship, r[1]])
		if not r[0]:
			fails_list.append(ship)
		g.queue_free()
		await _frames(6)
	print("FAILED TYPES: %s · %d came home held (paid, then started)" % [str(fails_list), held_n])
	print("TOW ARRIVAL %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
