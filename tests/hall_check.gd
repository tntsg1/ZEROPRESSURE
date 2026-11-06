extends "res://tests/guide_check.gd"
# 128 号 第 2 段 交易行与订单板 (scripts/hall_market.gd, hall_panel.gd, client_ships.gd). Rules: a listing
# sells in real time (nearer the market sooner), less 5 %; the drift stays within ±10 %; an order is
# taken, made up from the stores (and as goods come in), sent, collected, paid; the reputation grows
# and raises the price; the buy page puts goods in the stores; the one-key mending buys what it lacks
# here once open; the old exchange's open listings come back once (the save copied aside first).
# On screen (with "shots"): the sell page with the curve, the own-price slider, the buy page, the order
# board, the train and the client ship. Own test saves only.
#   tools/run_test.sh tests/hall_check.gd --fixed-fps 60 [-- shots]

const OUT := "res://tests/out/hall_%s.png"
const RepairBill = preload("res://scripts/repair_bill.gd")
const PS = preload("res://scripts/port_structure.gd")
const CS = preload("res://scripts/client_ships.gd")
const FW = preload("res://scripts/freight_works.gd")
var want_shots := false


func _initialize() -> void:
	Career.path = "user://zp_test_hall_career.json"
	SaveGame.path = "user://zp_test_hall_save.json"
	SaveGame.allow_test = true
	want_shots = "shots" in OS.get_cmdline_user_args()
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _snap(name: String) -> void:
	if not want_shots:
		return
	await _frames(3)
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
	Career.data.parts = [_part("s1", "p_battery", 2000.0, "BAT-T", 0.4), _part("s2", "p_nav", 4000.0, "NAV-T", 0.25),
		_part("s3", "p_battery", 2100.0, "BAT-T", 0.4), _part("s4", "p_pump", 3000.0, "PUMP-T", 0.5)]
	Career.data.structure_t = 4.0
	Career.data.money = 30000.0
	Career.data.migrations = [{"id": "128_hall"}]
	Career.save()


func _tick(s: float, step := 0.5) -> void:
	var n := int(s / step)
	for i in n:
		HallMarket.tick(step)


func _money() -> float:
	return float(Career.data.get("money", 0.0))


func _rules() -> void:
	_career()
	check(HallMarket.open(), "the trade port mended: the exchange is open")
	HallMarket.tick(0.1)
	check(HallMarket.orders().size() == HallMarket.FIRST_ORDERS, "opening: %d orders on the board at once" % HallMarket.orders().size())
	# drift: within ±10 %, smooth, changes over time
	var lo := 9.0
	var hi := 0.0
	for i in 400:
		var f := HallMarket.drift("p_battery", i * 13.0)
		lo = minf(lo, f)
		hi = maxf(hi, f)
	check(lo >= 0.9 - 1e-6 and hi <= 1.1 + 1e-6 and hi - lo > 0.1, "the drift stays within ±10%% and moves (%.3f … %.3f)" % [lo, hi])
	check(absf(HallMarket.drift("p_battery", 100.0) - HallMarket.drift("p_battery", 101.0)) < 0.01, "the drift is smooth second to second")
	check(HallMarket.fill_secs(100.0, 100.0) < HallMarket.fill_secs(110.0, 100.0) and HallMarket.fill_secs(90.0, 100.0) < HallMarket.fill_secs(100.0, 100.0), "nearer the market (or under it) sells sooner")
	# 一键挂单 at the suggested price
	var u: Dictionary = StoreBook.units().filter(func(x): return str(x.id) == "p:s2")[0]
	var mkt := HallMarket.market_now(u)
	var m0 := _money()
	var r := HallMarket.list("p:s2")
	check(r.ok and absf(float(r.price) - mkt) < 1.0, "one key: listed at the market now (%s)" % Pal.money(float(r.get("price", 0.0))))
	check(not StoreBook.units().any(func(x): return str(x.id) == "p:s2"), "a listed thing leaves the stores' grid")
	_tick(10.0)
	check(HallMarket.listings().size() == 1 and _money() == m0, "not sold after 10 s (real time)")
	_tick(float(r.secs) + 20.0)
	check(HallMarket.listings().is_empty(), "sold in real time (about %d s)" % int(r.secs))
	var sold: Dictionary = HallMarket.data().sold[-1]
	check(absf(_money() - m0 - float(sold.price) * 0.95) <= 1.0, "paid the price less 5%%: +%s of %s" % [Pal.money(_money() - m0), Pal.money(float(sold.price))])
	# an own price far over the market waits; withdrawn it comes back
	var r2 := HallMarket.list("p:s4", HallMarket.market_now(StoreBook.units().filter(func(x): return str(x.id) == "p:s4")[0]) * 1.4)
	_tick(120.0)
	check(r2.ok and HallMarket.listings().size() == 1, "at 140%% of market it is still waiting after 2 min (%s)" % HallMarket.eta_text(float(r2.get("secs", 0.0))))
	var c := HallMarket.cancel(str(r2.id))
	check(c.ok and StoreBook.units().any(func(x): return str(x.id) == "p:s4"), "withdrawn: back in the stores")
	# orders: one for batteries, taken, made up from the stores, sent, collected, paid
	var os: Array = HallMarket.orders()
	os.append({"id": "OT1", "client": "测试客户", "cat": "equip", "kind": "p_battery", "n": 2.0, "lv": 1, "price": 6000.0, "k": 1.3, "at": HallMarket.clock(), "due": HallMarket.clock() + 900.0, "state": "open", "got": 0.0, "held": []})
	HallMarket.data().orders = os
	var rep0 := HallMarket.rep()
	var t := HallMarket.take("OT1")
	check(t.ok and str(HallMarket.order("OT1").state) == "rail", "taken: both batteries put aside from the stores at once (%s)" % str(HallMarket.order("OT1").get("state", "")))
	check(RepairBill.own_of("p_battery").is_empty(), "the batteries left the stores")
	m0 = _money()
	_tick(1.0)
	check(str(HallMarket.order("OT1").state) == "ship", "no trains here: on to the client ship")
	var phases := {}
	for i in 80:
		HallMarket.tick(0.5)
		var o := HallMarket.order("OT1")
		if str(o.get("state", "")) == "ship":
			phases[str(HallMarket.ship_phase(o)[0])] = true
	check(phases.has("in") and phases.has("load") and phases.has("out"), "the ship comes in, lies alongside, leaves (%s)" % str(phases.keys()))
	check(str(HallMarket.order("OT1").get("state", "")) == "done" or HallMarket.order("OT1").is_empty(), "the order is done")
	check(absf(_money() - m0 - 6000.0) < 1.0, "paid the order's price at once (+%s)" % Pal.money(_money() - m0))
	check(HallMarket.rep() == rep0 + 1, "the reputation +1")
	# making up as goods come in: an order for 2 pumps with 1 in store
	os = HallMarket.orders()
	os.append({"id": "OT2", "client": "测试客户", "cat": "equip", "kind": "p_pump", "n": 2.0, "lv": 1, "price": 9000.0, "k": 1.3, "at": HallMarket.clock(), "due": HallMarket.clock() + 900.0, "state": "open", "got": 0.0, "held": []})
	HallMarket.data().orders = os
	HallMarket.take("OT2")
	check(str(HallMarket.order("OT2").state) == "taken" and int(HallMarket.order("OT2").got) == 1, "short: one pump put aside, waiting for one more")
	var gs: Array = Career.data.get("goods", [])
	gs.append({"uid": "gp2", "cat": "equip", "nk": "p_pump", "name": "泵", "value": 3000.0, "ship": "tug", "tag": "PUMP-T", "mass": 0.5})
	Career.data.goods = gs
	_tick(1.0)
	check(str(HallMarket.order("OT2").state) in ["rail", "ship"], "the second pump came in: made up by itself and sent")
	# a lapsed order: no penalty, nothing kept
	os = HallMarket.orders()
	os.append({"id": "OT3", "client": "测试客户", "cat": "equip", "kind": "p_winch", "n": 1.0, "lv": 1, "price": 9000.0, "k": 1.3, "at": HallMarket.clock(), "due": HallMarket.clock() + 5.0, "state": "open", "got": 0.0, "held": []})
	HallMarket.data().orders = os
	m0 = _money()
	var r0 := HallMarket.rep()
	_tick(10.0)
	check(str(HallMarket.order("OT3").get("state", "gone")) == "gone" and _money() == m0 and HallMarket.rep() == r0, "lapsed: gone, no fine, the reputation kept")
	# the reputation raises the level, bigger orders, better prices
	HallMarket.data().rep = 15
	check(HallMarket.level() == 4 and HallMarket.order_k(4) > HallMarket.order_k(1), "15 points: level 4, a better price (%.2f × market against %.2f)" % [HallMarket.order_k(4), HallMarket.order_k(1)])
	var big := 0.0
	for i in 20:
		var o2 := HallMarket._new_order()
		big = maxf(big, float(o2.n))
	check(big >= 2.0, "level 4: bigger orders (up to %.0f)" % big)
	check(HallMarket.live_orders().size() <= HallMarket.MAX_ORDERS, "at most 8 orders at once")
	_tick(1200.0, 2.0)
	check(HallMarket.live_orders().size() <= HallMarket.MAX_ORDERS and HallMarket.live_orders().size() >= 3, "20 minutes on: new orders came, never more than 8 (%d)" % HallMarket.live_orders().size())
	# 买: a machine into the stores, dearer than one's own
	m0 = _money()
	var each := HallMarket.buy_each("p_radiator")
	var b := HallMarket.buy("p_radiator", 1)
	check(b.ok and absf(m0 - _money() - each) < 1.0 and RepairBill.own_of("p_radiator").size() == 1, "bought a radiator for %s: in the stores" % Pal.money(each))
	check(each > RepairBill.kind_price("p_radiator") * 1.2, "dearer than one's own salvage (%s against %s)" % [Pal.money(each), Pal.money(RepairBill.kind_price("p_radiator"))])
	var st0 := float(Career.data.structure_t)
	HallMarket.buy(HallMarket.STEEL, 5.0)
	check(absf(float(Career.data.structure_t) - st0 - 5.0) < 0.01, "5 t of repair steel bought into its slot")
	Career.data.money = 10.0
	check(not HallMarket.buy("p_engine", 1).ok, "not enough cash: refused")
	Career.data.money = 200000.0
	# the one-key mending buys its lack here, at the buy page's price
	var bill := RepairBill.of("process")
	var row: Dictionary = bill.rows[0]
	check(bool(bill.get("at_hall", false)) and absf(float(row.each) - HallMarket.buy_each(str(row.nk))) < 1.0, "the mending's price is the buy page's (%s for %s)" % [Pal.money(float(row.each)), str(row.name)])
	check(RepairBill.short_line(bill).find("交易行") >= 0, "the mending says it buys on the exchange: " + RepairBill.short_line(bill))
	var nb: int = HallMarket.data().bought.size()
	m0 = _money()
	Works.BUILD_TIME = false
	var why := RepairBill.pay("process")
	check(why == "" and absf(m0 - _money() - float(bill.buy_cash)) < 1.0 and HallMarket.data().bought.size() > nb, "mended: what it lacked was bought on the exchange (%s, %d buys booked)" % [Pal.money(float(bill.buy_cash)), HallMarket.data().bought.size() - nb])


# an old save: the old exchange's open company listing is withdrawn once, copied aside first
func _migration() -> void:
	_career()
	Career.data.migrations = []
	Career.data.erase("hall")
	var ex := StoreBook.Exchange.fresh(float(Career.data.money))
	Career.data.exchange = ex
	var batch := {"id": "ingot:old", "job_id": "old", "ship": "tug", "mass_t": 4.0, "value": 1200.0}
	Career.data.ingot_batches = [batch]
	StoreBook.Exchange.import_ingots(ex, [batch])
	var p := StoreBook.Exchange.post(ex, StoreBook.Exchange.PLAYER, "sell", "ferrous_scrap", 1, 3.0, 9000.0)
	Career.data.parts[0]["listed"] = {"ask": 2000.0, "t": 0.0}
	Career.save()
	check(p.ok and StoreBook.listed_t(StoreBook.Exchange.INGOT) > 2.9, "an old save: 3 t of ingots held by an old listing")
	var bdir := ProjectSettings.globalize_path("user://zp_test_backup")
	var before := DirAccess.get_directories_at(bdir).size() if DirAccess.dir_exists_absolute(bdir) else 0
	HallMarket.tick(0.1)
	check(StoreBook.listed_t(StoreBook.Exchange.INGOT) < 0.01 and float(StoreBook.raw_stock().get(StoreBook.Exchange.INGOT, 0.0)) > 3.9, "the old listing withdrawn: the ingots back in the stores")
	check(not Career.data.parts[0].has("listed"), "the old part listing taken down")
	check(Career.data.migrations.any(func(m): return str(m.id) == "128_hall"), "logged once in migrations")
	check(DirAccess.get_directories_at(bdir).size() > before, "the save copied aside before the change")
	var n := HallMarket.migrate()
	check(n == 0, "not done twice")


# on screen: the pages, the train and the ship
func _screen() -> void:
	_career()
	Career.data.goods = [{"uid": "gq1", "cat": "equip", "nk": "p_generator", "name": "", "value": 9000.0, "ship": "tug", "tag": "GEN-T", "mass": 1.0}]
	Career.save()
	HallMarket.events = []
	_spawn()
	await _frames(20)
	HallMarket.tick(0.1)
	# the store's keys say the ladder and work
	g.open_store()
	await _frames(10)
	var sp = g.console_ui
	sp.select("p:s1")
	await _frames(4)
	check(sp.trade_open() and sp.trade_net(sp._item("p:s1")) > 0.0, "the stores' exchange key is live: ~%s" % Pal.money(sp.trade_net(sp._item("p:s1"))))
	sp.close() if sp.has_method("close") else sp._close()
	await _frames(10)
	g.open_hall("sell", "p:s1")
	await _frames(30)
	var hp = g.console_ui
	check(hp != null and hp.get_script() == preload("res://scripts/hall_panel.gd"), "F8 / the stores open the new exchange page")
	hp.custom = false
	await _frames(40)
	await _snap("1_sell")
	hp.custom = true
	hp.price_k = 1.12
	await _frames(20)
	await _snap("2_own_price")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	hp._unhandled_input(ev)
	await _frames(4)
	check(hp.custom == false and g.console_ui == hp, "Esc steps back: the slider closes, the page stays")
	hp.set_tab("buy")
	hp.buy_sel = "p_battery"
	await _frames(40)
	await _snap("3_buy")
	hp.set_tab("orders")
	var o0: Dictionary = HallMarket.orders()[0]
	HallMarket.take(str(o0.id))
	await _frames(40)
	await _snap("4_orders")
	hp._unhandled_input(ev)
	await _frames(10)
	check(g.console_ui == null, "Esc again closes the page")
	# an order for a battery, made up and on its way: the train, then the client's ship
	var os: Array = HallMarket.orders()
	os.append({"id": "OS1", "client": "北辰船务", "cat": "equip", "kind": "p_battery", "n": 1.0, "lv": 1, "price": 4000.0, "k": 1.3, "at": HallMarket.clock(), "due": HallMarket.clock() + 900.0, "state": "open", "got": 0.0, "held": []})
	HallMarket.data().orders = os
	HallMarket.take("OS1")
	check(str(HallMarket.order("OS1").state) == "rail" and bool(HallMarket.order("OS1").get("sent", false)), "made up: on the freight train (an order crate queued)")
	check(FW.queue.any(func(q): return str(q.get("order", "")) == "OS1"), "the freight queue carries the order's crate")
	var b: Rect2 = PS.box("trade")
	g.cam_override = b.get_center() + Vector2(b.size.x * 0.55, 0.0)
	g.zoom_override = 1920.0 / (b.size.x * 2.2)
	var seen_ship := false
	var seen_main := false
	var seen_retro := false
	var shot_in := false
	var shot_load := false
	var shot_train := false
	for i in 60 * 150:
		await process_frame
		var o := HallMarket.order("OS1")
		if not shot_train and str(o.get("state", "")) == "rail":
			for tr in FW.trains:
				for wg in tr.wag:
					if wg is Dictionary and str(wg.get("order", "")) == "OS1" and tr.moving:
						shot_train = true
				if shot_train:
					g.zoom_override = 1920.0 / (50.0 * Geom.M)
					for k in 90:
						g.cam_override = FW.cars(tr)[1][0]
						await process_frame
					await _snap("5a_train")
					g.cam_override = b.get_center() + Vector2(b.size.x * 0.55, 0.0)
					g.zoom_override = 1920.0 / (b.size.x * 2.2)
					break
		if str(o.get("state", "")) == "ship":
			var ph := HallMarket.ship_phase(o)
			for e in g.client_ships.last:
				if str(e.oid) == "OS1":
					seen_ship = true
					seen_main = seen_main or str(e.eng) == "main"
					seen_retro = seen_retro or str(e.eng) == "retro"
			if str(ph[0]) == "in" and float(ph[1]) > 0.75 and not shot_in:
				shot_in = true
				await _snap("5_ship_in")
			if str(ph[0]) == "load" and not shot_load and float(HallMarket.clock() - float(o.ship_at)) > HallMarket.SHIP_IN + 2.0:
				shot_load = true
				await _snap("6_ship_load")
		if str(o.get("state", "")) in ["done", ""] or o.is_empty():
			break
	check(shot_train, "the order's crate seen riding a freight train")
	check(seen_ship and seen_main and seen_retro, "the client ship drawn, speeding up on its main engine and braking on its retros")
	check(HallMarket.order("OS1").is_empty() or str(HallMarket.order("OS1").state) == "done", "the order collected and paid")
	g.cam_override = Vector2.INF
	g.zoom_override = 0.0


func _run() -> void:
	Txt.zh = true
	if not "screen" in OS.get_cmdline_user_args():
		_rules()
		_migration()
	if DisplayServer.get_name() != "headless":
		await _screen()
	print("hall_check: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
