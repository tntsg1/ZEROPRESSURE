extends "res://tests/guide_check.gd"
# 货船穿模 (user 2026-11-10: "交易之后货船过来，结果货船一过来就直接消失不见了，完全看不到货船在哪里，只知道货
# 凭空冒出来了"). After a deal on the exchange the freighter that comes for it (an order's pick-up) or with
# it (something bought) is followed frame by frame, from the moment it starts in until it is out past
# ClientShips.FAR again:
#   - it is on the list every frame, its node in the tree and visible, drawn whole (no fading);
#   - its hull box never crosses a district's shell, the trade pier, any district's outside works
#     (PortArt.exterior_rects) or ARK-01;
#   - it starts in from far out and leaves the same way (not popping in or out in plain view);
#   - no crate is on the dock before it lies alongside; a bought thing is in the stores only after it
#     berthed (and after its crates went through the intake); an order's crates are aboard only after it
#     berthed;
#   - the boom is in before it leaves; and all this with the camera on the far side of the port too.
# With "shots": the four moments (in, alongside, unloading, out) into tests/out/trade_ship_*.png.
#   tools/run_test.sh tests/trade_ship_check.gd --fixed-fps 60 [-- shots]

const OUT := "res://tests/out/trade_ship_%s.png"
const PS = preload("res://scripts/port_structure.gd")
const CS = preload("res://scripts/client_ships.gd")
const TW = preload("res://scripts/trade_works.gd")
const FW = preload("res://scripts/freight_works.gd")
const RepairBill = preload("res://scripts/repair_bill.gd")
var want_shots := false


func _initialize() -> void:
	Career.path = "user://zp_test_tradeship_career.json"
	SaveGame.path = "user://zp_test_tradeship_save.json"
	SaveGame.allow_test = true
	want_shots = "shots" in OS.get_cmdline_user_args()
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _snap(name: String) -> void:
	if not want_shots:
		return
	await _frames(2)
	Cap.save(root, OUT % name)


func _part(uid: String, nk: String, v: float, tag: String, mass: float) -> Dictionary:
	return {"uid": uid, "nk": nk, "cls": "power", "cond": 1.0, "value": v, "ship": "tug", "tag": tag, "mass": mass, "job": "TUG-001"}


func _career() -> void:
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.prologue_done = true
	Career.data.onboard = "done"
	Career.data.history = [{"id": "TUG-001"}, {"id": "S09-001"}]
	Career.data.seen = {"port_walk": true, "first_ship": true, "intro": true, "belt_prelude": true, "first_tow": true, "store_guide_done": true, "store_counter": true}
	Career.data.port = {"salvage": 1, "trade": 1}
	Career.data.upgrades = {"lights": 1, "furnace_main": 1, "net_fix": 1}
	Career.data.parts = [_part("s1", "p_battery", 2000.0, "BAT-T", 0.4), _part("s2", "p_nav", 4000.0, "NAV-T", 0.25)]
	Career.data.structure_t = 4.0
	Career.data.money = 60000.0
	Career.data.migrations = [{"id": "128_hall"}]
	Career.save()


# a freighter's box (world px): its bow clamp (0.35 m past the hull) to its engine bell (1.4 m aft),
# turned whichever way it faces (mid-turn: the wider of the two), mast top to fenders
func _hull(e: Dictionary) -> Rect2:
	var m := PS.M()
	var at := PS.box("trade").position + (e.at as Vector2) * m
	var half := float(e.len) * 0.5
	var fl := float(e.flip)
	var bow := -(half + 0.4) * fl
	var aft := (half + 1.45) * fl
	if absf(fl) < 0.999:
		bow = -(half + 1.45)
		aft = half + 1.45
	return Rect2(at + Vector2(minf(bow, aft), -4.4) * m, Vector2(absf(aft - bow), 7.5) * m)


# what it must never cross (world px): every district's shell, its outside works, ARK-01
func _obstacles() -> Array:
	var m := PS.M()
	var c := PS.centre()
	var out: Array = []
	for zone in ["power", "tug", "process", "trade", "cargo"]:
		out.append([zone, PS.box(zone)])
		for r: Rect2 in PortArt.exterior_rects(zone):
			out.append([zone + " works", Rect2(c + r.position * m, r.size * m)])
	var ak := PortArt.ARK_K
	out.append(["ARK-01", Rect2(c + (PortArt.ARK_AT + Vector2(-58.0 * ak - 15.0, -36.0)) * m, Vector2((58.0 + 64.0) * ak + 15.0, 72.0) * m)])
	return out


# follow one ship (by its order / delivery id) from its start until it is gone
func _follow(id: String, kind: String, label: String, look_away: bool) -> Dictionary:
	var r := {"seen": false, "gone": false, "vanished": false, "hidden": 0, "faded": 0, "clip": "", "start_d": 0.0, "end_d": 0.0,
		"berth_t": -1.0, "crate_early": false, "phases": {}, "boom_out_leaving": false}
	var obs := _obstacles()
	var b := PS.box("trade")
	var m := PS.M()
	var shot := {}
	var berth: Vector2 = CS.berth()
	for i in 60 * 140:
		await process_frame
		var e := {}
		for x in CS.ships():
			if str(x.oid) == id:
				e = x
		if e.is_empty():
			if r.seen:
				# off the list: only once it is out past FAR
				var rec: Dictionary = HallMarket.order(id) if kind == "pick" else HallMarket.delivery(id)
				if rec.is_empty() or (rec.has("out_at") and HallMarket.clock() - float(rec.out_at) >= HallMarket.leave_secs() - 0.05):
					r.gone = true
				else:
					r.vanished = true
				break
			continue
		if not r.seen:
			r.seen = true
			r.start_d = (e.at as Vector2).distance_to(berth)
		r.end_d = (e.at as Vector2).distance_to(berth)
		var ph := str(e.phase)
		r.phases[ph] = true
		if not (g.client_ships.is_inside_tree() and g.client_ships.visible):
			r.hidden = int(r.hidden) + 1
		if float(e.alpha) < 1.0:
			r.faded = int(r.faded) + 1
		var hb := _hull(e)
		for ob in obs:
			if str(r.clip) == "" and hb.intersects(ob[1]):
				r.clip = "%s (%s at %s)" % [str(ob[0]), ph, str((e.at as Vector2).round())]
		if ph == "load" and float(r.berth_t) < 0.0:
			r.berth_t = HallMarket.clock()
		var jid := ("hall:" if kind == "pick" else "hallbuy:") + id
		if float(r.berth_t) < 0.0 and not TW.crates.is_empty() and str(TW.job.get("id", "")) == jid:
			r.crate_early = true
		if ph == "out" and TW.boom > 0.0:
			r.boom_out_leaving = true
		# the camera: on the berth for the pictures, or on the far side of the port
		if look_away:
			g.cam_override = PS.box("process").get_center()
			g.zoom_override = 1920.0 / (90.0 * m)
		else:
			g.zoom_override = 1920.0 / (95.0 * m)
			g.cam_override = b.position + Vector2(66.0, 16.0) * m
			if ph == "in":
				# ride along while it is far out, then hold on the berth
				var at: Vector2 = b.position + (e.at as Vector2) * m
				g.cam_override = Vector2(maxf(at.x - 20.0 * m, b.position.x + 66.0 * m), b.position.y + 16.0 * m)
			if ph == "in" and r.end_d < 40.0 and not shot.has("in"):
				shot["in"] = true
				await _snap(label + "_1_in")
			if ph == "load" and TW.crane_step == "down_hold" and TW.boom >= 1.0 and not shot.has("berth"):
				shot["berth"] = true
				await _snap(label + "_2_alongside")
			if ph == "load" and not shot.has("unload") and TW.crates.size() >= 1 and TW.crates.any(func(c): return str(c.at) == "belt") and TW.crane_step in ["to_end", "down_belt", "back_up", "to_hold"]:
				shot["unload"] = true
				await _snap(label + "_3_crates")
			if ph == "out" and r.end_d > 25.0 and not shot.has("out"):
				shot["out"] = true
				await _snap(label + "_4_out")
	g.cam_override = Vector2.INF
	g.zoom_override = 0.0
	return r


func _report(r: Dictionary, what: String) -> void:
	check(r.seen and r.gone and not r.vanished, "%s: followed from its start until it was out past FAR (vanished: %s)" % [what, str(r.vanished)])
	check(int(r.hidden) == 0, "%s: its node in the tree and visible every frame (%d frames not)" % [what, int(r.hidden)])
	check(int(r.faded) == 0, "%s: drawn whole every frame, no fading in or out (%d frames faded)" % [what, int(r.faded)])
	check(str(r.clip) == "", "%s: its hull never crossed the station or any works (%s)" % [what, str(r.clip) if str(r.clip) != "" else "clear"])
	check(float(r.start_d) >= CS.FAR * 0.98 and float(r.end_d) >= CS.FAR * 0.9, "%s: in from %.0f m out, gone at %.0f m out" % [what, float(r.start_d), float(r.end_d)])
	check(r.phases.has("in") and r.phases.has("load") and r.phases.has("out"), "%s: in, alongside, out (%s)" % [what, str(r.phases.keys())])
	check(not r.crate_early, "%s: no crate on the dock before it lay alongside" % what)
	check(not r.boom_out_leaving, "%s: the crane's boom was in before it left" % what)


func _run() -> void:
	Txt.zh = true
	_career()
	_spawn()
	await _frames(20)
	HallMarket.tick(0.1)
	FW.on = false   # no trains: the order goes straight to its ship (the trains have their own tests)
	# 1. something bought: its seller's freighter brings it; the camera on the berth
	var b := HallMarket.buy("p_battery", 2)
	check(b.ok and HallMarket.deliveries().size() == 1, "bought 2 batteries: paid, on their way by freighter")
	var did := str(HallMarket.deliveries()[0].id)
	var own0 := RepairBill.own_of("p_battery").size()
	var r := await _follow(did, "drop", "buy", false)
	_report(r, "the seller's freighter")
	# its crates run on along the belt into the intake after it has gone
	for i in 60 * 60:
		if bool(HallMarket.delivery(did).get("landed", false)):
			break
		await process_frame
	var d := HallMarket.delivery(did)
	check(float(d.get("landed_at", -1.0)) >= float(d.get("berthed_at", 1e9)), "stored after it berthed, never before")
	var landed := float(d.get("landed_at", -1.0))
	check(landed > 0.0 and float(r.berth_t) > 0.0 and landed > float(r.berth_t) + 1.0, "the batteries were stored %.1f s after it berthed (berthed %.1f, stored %.1f)" % [landed - float(r.berth_t), float(r.berth_t), landed])
	check(RepairBill.own_of("p_battery").size() == own0 + 2, "both batteries in the stores (%d → %d)" % [own0, RepairBill.own_of("p_battery").size()])
	# 2. an order: its client's freighter comes for the crates; the camera on the far side of the port
	var os: Array = HallMarket.orders()
	os.append({"id": "OTS", "client": "北辰船务", "cat": "equip", "kind": "p_battery", "n": 1.0, "lv": 1, "price": 4000.0, "k": 1.3, "at": HallMarket.clock(), "due": HallMarket.clock() + 900.0, "state": "open", "got": 0.0, "held": []})
	HallMarket.data().orders = os
	var tk := HallMarket.take("OTS")
	check(tk.get("ok", false), "the order taken and made up")
	var r2 := await _follow("OTS", "pick", "order", true)
	_report(r2, "the client's freighter (camera far away)")
	var o := HallMarket.order("OTS")
	check(o.is_empty() or bool(o.get("loaded", false)), "its crate loaded by the dock's crane, not skipped")
	check(TW.handed >= 2, "the dock handed over both (%d)" % TW.handed)
	FW.on = true
	print("trade_ship_check: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
