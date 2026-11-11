extends "res://tests/guide_check.gd"
# 76 号 (G6.3): the gas line, from the hose to a passing freighter. What the hoses take is
# logged by species from the room's real air (or the tank's gas); with the gas line built it
# comes home as a batch instead of cash; separation conserves mass to the gram; taint lowers the
# purity and keeps oxygen from life-support grade; hydrogen stops a batch; the life-support test
# needs a clean certified source; liquefaction changes the phase not the mass, and a full tank
# stops it; without power the tank boils off (vented, logged), with power it holds; 132 号: no
# passing ship buys gas (an old save's supply orders are dropped); automation takes only standard batches and only once two were done by hand. Own saves only.
#   tools/run_test.sh tests/gas_line_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_gas_line_career.json"
	SaveGame.path = "user://zp_test_gas_line_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _ship(job: Dictionary) -> void:
	Game.contract = job
	Game.start_ship = str(job.ship)
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(12)
	g.tutorial = null


func _mass_out(d: Dictionary) -> float:
	return float(d.o2.ind) + float(d.o2.ok) + float(d.o2.ls) + float(d.n2) + float(d.residue) + float(d.waste)


func _run() -> void:
	# 2026-11-11: a ship's gas is piped to the line first (GasLine.TRANSIT_S); these checks are of
	# the line itself, so it arrives at once here (the pipe run: tests/gas_route_shot.gd)
	GasLine.TRANSIT_S = 0.0
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.money = 800000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1}
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.exchange = Exchange.fresh(800000.0)
	Career.data.active = Career.opening(1)
	Career.save()
	# ---- what the hoses take, by species
	await _ship(Career.active())
	var sys = g.sys
	var room := ""
	for n in sys.vols:
		if g.world.rooms.has(n) and float(sys.vols[n].n) > 10.0:
			room = n
			break
	sys.gas_take = {}
	sys._log_take(room, 100.0)
	var kg_air: float = 100.0 * 0.4105 * (0.21 * 0.032 + 0.78 * 0.028 + 0.01 * 0.040)
	var tk: Dictionary = sys.gas_take
	check(is_equal_approx(float(tk.o2) + float(tk.n2) + float(tk.ar), kg_air) and is_equal_approx(float(tk.o2), 100.0 * 0.4105 * 0.21 * 0.032), "a room's air by its share: 100 kPa·m³ = %.2f kg (O₂ %.2f kg)" % [kg_air, float(tk.o2)])
	check(sys.species_of("O2").has("o2") and sys.species_of("O2").size() == 1, "a tank named O2 is pure oxygen")
	var cash_before_line: float = sys.gas_value()
	Career.data.upgrades["gas_line"] = 1
	check(GasLine.keeping() and sys.gas_value() == 0.0, "with the gas line built the gas is no longer cashed at settlement")
	var rep: Dictionary = g.settle_report()
	check(not rep.get("gas_take", {}).is_empty(), "the settlement carries what the hoses took")
	var nb: int = GasLine.data().batches.size()
	GasLine.receive(rep.gas_take, "S09-001")
	check(GasLine.data().batches.size() == nb + 1 and is_equal_approx(GasLine.mass(GasLine.data().batches.back()), kg_air), "it comes home as a batch of known mixed gas (%.2f kg)" % kg_air)
	g.queue_free()
	await _frames(4)
	Career.data.active = {}
	# ---- separation: mass conserved, to the gram
	var d: Dictionary = GasLine.data()
	d.batches = []
	var b: Dictionary = GasLine.receive({"o2": 210.0, "n2": 780.0, "ar": 10.0}, "TEST")
	var in0 := _mass_out(d)
	check(GasLine.sep_block(str(b.id)) == "" and GasLine.separate(str(b.id)).ok, "a clean batch of 1 t goes into the column")
	check(GasLine.advance(null, GasLine.SEP_S_PER_T - 1.0).size() >= 0 and str(b.state) == "processing", "not before its time (30 s a tonne)")
	GasLine.advance(null, 2.0)
	var out := _mass_out(d) - in0
	check(str(b.state) == "done" and absf(out - 1000.0) < 0.1, "separated: products + residue = 1000 kg in (%.3f kg out)" % out)
	check(is_equal_approx(float(b.out.o2), 189.0) and is_equal_approx(float(b.out.n2), 741.0) and is_equal_approx(float(b.out.residue), 70.0), "189 kg O₂ (90 %%), 741 kg N₂, 70 kg residue — no 18 kg O₂ plus 100 kg left over")
	check(float(b.out.purity) >= GasLine.IND_PURITY and not bool(b.out.ls_ok), "an uncertified source: industrial oxygen, not life-support")
	# taint
	var tb: Dictionary = GasLine.receive({"o2": 210.0, "n2": 780.0, "ar": 5.0}, "TAINT")
	tb.bio = 5.0
	var a: Dictionary = GasLine.assess(tb)
	check(a.purity < GasLine.IND_PURITY and not GasLine.split(tb).o2 > 0.0, "0.5 %% culture taint: purity %.1f %% — no oxygen product, it all stays in the residue" % (a.purity * 100.0))
	var sp: Dictionary = GasLine.split(tb)
	check(absf(float(sp.o2) + float(sp.n2) + float(sp.residue) + float(sp.waste) - GasLine.mass(tb)) < 0.001 and is_equal_approx(float(sp.waste), 5.0), "and still conserved: the taint goes to the tainted waste")
	var heavy: Dictionary = GasLine.receive({"o2": 100.0, "n2": 300.0}, "DIRTY")
	heavy.bio = 20.0
	check(GasLine.sep_block(str(heavy.id)).contains("污染超限"), "over 2 %% taint: disposal only")
	# hydrogen
	var hb: Dictionary = GasLine.receive({"h2": 40.0, "o2": 50.0, "n2": 160.0}, "FUEL")
	check(GasLine.sep_block(str(hb.id)).contains("燃料危险"), "hydrogen in it: fuel hazard, it does not go into the column")
	var m0 := float(Career.data.money)
	check(GasLine.dispose(str(hb.id)).ok and float(Career.data.money) < m0 and str(hb.state) == "disposed", "controlled disposal costs money and it is gone on the record")
	# the supplier and the life-support test
	check(GasLine.buy_mixed(2.0).ok and is_equal_approx(m0 - float(Career.data.money) - GasLine.mass(hb) / 1000.0 * GasLine.DISPOSE_PER_T, 2.0 * GasLine.MIXED_PRICE), "2 t of known mixed gas bought from the belt supplier")
	GasLine.advance(null, GasLine.SUPPLY_S + 0.1)
	var sb: Dictionary = d.batches.back()
	check(bool(sb.certified) and is_equal_approx(GasLine.mass(sb), 2000.0), "it arrives a minute later, certified")
	GasLine.separate(str(sb.id))
	GasLine.advance(null, 61.0)
	check(float(d.o2.ok) > 0.0, "certified and clean: the oxygen is fit for the life-support test (%.0f kg)" % float(d.o2.ok))
	var ok0 := float(d.o2.ok)
	check(GasLine.ls_test().ok, "sent for the test")
	GasLine.advance(null, GasLine.LS_TEST_S + 0.1)
	check(is_equal_approx(float(d.o2.ls), ok0), "life-support grade oxygen: %.0f kg" % float(d.o2.ls))
	# ---- liquefaction and the tank
	check(GasLine.liq_block(500.0).contains("储罐"), "no tank yet: %s" % GasLine.liq_block(500.0))
	Career.data.upgrades["lox_tank"] = 1
	var gas0 := float(d.o2.ind) + float(d.o2.ok) + float(d.o2.ls)
	check(GasLine.liquefy(500.0).ok, "500 kg into the cold box")
	GasLine.advance(null, GasLine.LIQ_S_PER_T * 0.5 + 0.1)
	var gas1 := float(d.o2.ind) + float(d.o2.ok) + float(d.o2.ls)
	check(is_equal_approx(float(d.lox.kg), 500.0) and is_equal_approx(gas0 - gas1, 500.0), "the phase changes, not the mass: 500 kg less gas, 500 kg of LOX")
	check(str(d.lox.grade) == "ind", "industrial oxygen went in first: the tank holds industrial LOX")
	d.lox.kg = GasLine.TANK_CAP - 300.0
	check(GasLine.liq_block(500.0).contains("满"), "the tank nearly full: no more liquefying (%s)" % GasLine.liq_block(500.0))
	d.lox.kg = 6000.0
	# ---- boil-off: with no power to the cold box it vents, with power it holds
	await _spawn()
	await _frames(20)
	var fake := preload("res://tests/grid_check.gd").Fake.new()
	fake.group = "salvage"
	fake.mw = 30.0
	root.add_child(fake)
	Grid.add_load_source(fake)
	Career.data.port["power"] = 0
	await _frames(2)
	check(GasLine.k(g, "lox_hold") == 0.0, "a 30 MW load ahead at 6 MW: the cold box gets nothing")
	d.lox.kg = 6000.0
	var v0 := float(d.vented)
	GasLine.advance(g, 60.0)
	var lost := 6000.0 - float(d.lox.kg)
	check(lost > 200.0 and is_equal_approx(float(d.vented) - v0, lost), "a minute without cooling: %.0f kg boiled off and vented, logged" % lost)
	fake.queue_free()
	Career.data.port["power"] = 1
	await _frames(2)
	var hold0 := float(d.lox.kg)
	GasLine.advance(g, 60.0)
	check(is_equal_approx(float(d.lox.kg), hold0), "power back: the cold box holds it")
	d.lox.kg = 6000.0
	# ---- 132 号 (user 2026-11-07 "燃料外运也删了"): no passing ship buys gas any more
	var said_all: Array = []
	for i in 12:
		said_all += GasLine.advance(g, 60.0)
		await _frames(1)
	check(not d.has("callers") and not said_all.any(func(s): return str(s).find("补给") >= 0), "twelve minutes: no passing ship asks for supply (%d lines said)" % said_all.size())
	check(not GasLine.grid_loads().any(func(l): return str(l.id) == "lox_arm"), "no supply arm on the grid")
	check(not GasLine.set_auto("supply", true).ok, "no 'take supply orders' switch")
	# an old save: its supply orders and what they held back are dropped as it is read, no error
	d["callers"] = [{"id": "SUP-OLD", "ship": "远帆号-38", "want": "lox", "grade": "ind", "kg": 2000.0, "price": 0.6, "eta": 10.0, "stay": 60.0, "partial": false, "state": "accepted", "reserved": 2000.0, "got": 0.0, "t": 0.0}]
	d.auto["supply"] = true
	d.auto["keep_lox"] = 2000.0
	var d2 := GasLine.data()
	check(not d2.has("callers") and not d2.auto.has("supply") and not d2.auto.has("keep_lox"), "an old save's supply order and its switch are dropped")
	check(not GasLine.set_auto("buy", true).ok and d2.auto.keys().filter(func(k): return str(k) in ["buy", "buy_max_price", "buy_t", "cash_floor"]).is_empty(), "no feed-buying switch or bounds left")
	check(is_equal_approx(preload("res://scripts/power_supply.gd")._gas_lox(), float(d.lox.kg)), "the LOX the fuel cells may take is the whole tank (nothing held back)")
	# ---- automation
	d.made = 0
	check(not GasLine.set_auto("process", true).ok, "automatic separation only after two batches by hand")
	d.made = 2
	check(GasLine.set_auto("process", true).ok, "two done by hand: it may be switched on")
	for ob in d.batches:
		if str(ob.state) == "raw":
			ob.state = "disposed"
	var std: Dictionary = GasLine.receive({"o2": 21.0, "n2": 78.0, "ar": 1.0}, "AUTO")
	var odd: Dictionary = GasLine.receive({"h2": 5.0, "n2": 50.0}, "ODD")
	d.job = {}
	GasLine.advance(null, 0.1)
	check(str(std.state) == "processing" and str(odd.state) == "raw", "it takes the standard batch and leaves the hydrogen one waiting for the player")
	GasLine.set_auto("process", false)
	# ---- the save
	Career.save()
	var keep := JSON.stringify(JSON.parse_string(JSON.stringify(Career.data.gas)))
	Career.data = {}
	Career.load_or_new()
	check(JSON.stringify(JSON.parse_string(JSON.stringify(Career.data.get("gas", {})))) == keep, "the gas line's batches, products, tank and orders are in the save")
	# ---- the console
	g.queue_free()
	await _frames(4)
	await _spawn()
	await _frames(20)
	g.cam_override = preload("res://scripts/gas_works.gd").origin() + Vector2(10, 14) * PortStructure.M()
	g.zoom_override = 0.32
	await _frames(40)
	Cap.save(root, "res://tests/out/gas_works_zh.png")
	g.cam_override = null
	g.zoom_override = -1.0
	g.drone.global_position = PortStructure.console_spot("process")
	await _frames(10)
	g.open_district("process")
	await _frames(20)
	check(g.console_ui != null and g.console_ui.gas_box != null and g.console_ui.gas_box.get_child_count() > 4, "the processing console has the gas line page")
	Cap.save(root, "res://tests/out/gas_console_zh.png")
	if g.console_ui != null:
		g.console_ui.close()
	g.queue_free()
	await _frames(4)
	print("GAS LINE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
