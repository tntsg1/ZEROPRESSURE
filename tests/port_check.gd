extends SceneTree
# G6 acceptance (design/成长版本/G6_零压港六区.md): the port's works.
#   1  a new career: every district dark; the tug station down costs a towing fee at
#      settlement; the trade port adds nothing yet
#   2  a stage built with parts takes them off the shelf at a quarter of the money (74 号); with money
#      alone at the full price; prerequisites hold (the ring waits on power and the tug);
#      a failed write changes nothing; the stage is queued for the show
#   3  the backdrop draws the port (no script error with every stage lit)
#   4  the promised effects: the power district gates the heavy repairs; the trade port
#      weights the star rolls; the cargo district adds a deploy slot and restocks; a big
#      ship queues one contract with one tug and comes back held; the port's works are goals
# godot --headless --path . --fixed-fps 60 -s tests/port_check.gd

var fails := 0
var checks := 0
var finished := false


func _initialize() -> void:
	# 68 号: this test reads the hulks the market drew by itself (before the star-map sweep)
	Scan.ON = false
	Career.path = "user://zp_test_port_career.json"
	SaveGame.path = "user://zp_test_port_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	_run()


func _process(_dt: float) -> bool:
	return finished


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	# 128 号 第 3 段: this test reads the two old ways to pay (parts or cash); the one "修" is seg3_check's
	preload("res://scripts/repair_bill.gd").ON = false
	print("PORT: a new career")
	Career.data = {}
	Career.start_new()
	var d := Career.data
	check(Port.total_stages() == 0 and Port.tow_fee() == 0.0 and Port.trade_k() == 1.0, "every district dark: no trade bonus, and no towing fee at the settlement (123 号: paid when the tug goes)")
	d.market = true
	d.done = 3
	d.money = 100000.0
	d.active = {"id": "T-1", "ship": "gr7", "scope": "full", "fee": 0.0, "fee_paid": true, "kit": {}, "items": {}}
	var res := Career.settle({"earned": 50000.0, "losses": 0.0, "rate": 0.9, "grade": 2, "time": 100.0, "fee": 0.0, "bonus": 0.0, "used": {}, "ops": {}})
	check(float(res.tow) == 0.0 and float(res.trade_bonus) == 0.0 and absf(float(Career.data.money) - (100000.0 + 50000.0)) < 1.0, "123 号: no second towing fee off the settlement (%d)" % int(Career.data.money))
	# ---- 2: stages
	d = Career.data
	d.parts = [
		{"uid": "a:G-01", "cls": "power", "tag": "G-01", "nk": "p_gen", "cond": 0.8, "value": 16000.0, "ship": "gr7", "job": "T"},
		{"uid": "a:B-01", "cls": "power", "tag": "B-01", "nk": "p_battery", "cond": 0.7, "value": 2000.0, "ship": "gr7", "job": "T"},
		{"uid": "a:ENG-C", "cls": "drive", "tag": "ENG-C", "nk": "p_engc", "cond": 0.9, "value": 11000.0, "ship": "gr7", "job": "T"},
		{"uid": "a:NAV-01", "cls": "drive", "tag": "NAV-01", "nk": "p_nav", "cond": 0.9, "value": 6000.0, "ship": "gr7", "job": "T"},
	]
	d.structure_t = 30.0
	d.money = 200000.0
	Career.save()
	check(Port.reason("ring", true).find(Port.name_of("power")) >= 0, "the ring waits on the power district and the tug station")
	var good := Career.path
	Career.path = "user://"
	var why := Port.fix("power", true)
	Career.path = good
	check(why != "" and Port.stage("power") == 0 and Career.data.parts.size() == 4 and float(Career.data.money) == 200000.0, "a stage that cannot be written changes nothing (%s)" % why)
	check(Port.fix("power", true) == "" and Port.stage("power") == 1 and Career.data.parts.size() == 2 and absf(float(Career.data.money) - 195000.0) < 1.0, "power stage 1 with parts: two power parts gone, a quarter of the money (74 号: the crew's wages)")
	check(Career.data.repaired_pending == ["port:power:1"], "queued for the show back at the berth")
	check(Port.fix("tug", false) == "" and Port.stage("tug") == 1 and absf(float(Career.data.money) - 165000.0) < 1.0 and Career.data.parts.size() == 2, "the tug station with money alone: full price, the shelf untouched")
	check(Port.tow_fee() == 0.0, "no towing fee any more")
	check(Port.fix("salvage", true) == "" and absf(float(Career.data.structure_t) - 20.0) < 0.01, "the salvage district stage 1 took 10 t of structure")
	check(Port.reason("ring", true) != "" and Port.reason("ring", true).find(Port.name_of("power")) < 0, "the ring's prerequisites met; it waits on parts or money now")
	check(Port.fix("trade", false) == "" and Port.trade_k() == 1.1, "the trade port stage 1: equipment sells 10 % better")
	Career.data.active = {"id": "T-2", "ship": "gr7", "scope": "full", "fee": 0.0, "fee_paid": true, "kit": {}, "items": {}}
	var m0 := float(Career.data.money)
	var res2 := Career.settle({"earned": 50000.0, "losses": 0.0, "rate": 0.9, "grade": 2, "time": 100.0, "fee": 0.0, "bonus": 0.0, "used": {}, "ops": {}})
	check(float(res2.trade_bonus) == 5000.0 and float(res2.tow) == 0.0 and absf(float(Career.data.money) - (m0 + 55000.0)) < 1.0, "a settlement with the trade bonus and no towing fee")
	# ---- 4: the promised effects
	check(Repair.reason("crane", false).find(Txt.t("rp_need_power").substr(0, 6)) >= 0 or Port.stage("power") >= 1, "the crane waits for the power district")
	Career.data.port["power"] = 0
	Career.data.upgrades["lights"] = true
	Career.data.upgrades["buffer"] = true
	check(Repair.reason("crane", false) == Txt.t("rp_need_power"), "without the power district the crane says why (%s)" % Repair.reason("crane", false))
	Career.data.port["power"] = 1
	check(Repair.reason("crane", false) != Txt.t("rp_need_power"), "with the power district the crane moves on to its own wants")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var hi := {1: 0, 2: 0, 3: 0}
	for i in 600:
		hi[Market.roll_stars(rng, 3, Port.star_weight_of({"port": {"trade": 2}}))] += 1
	var lo := {1: 0, 2: 0, 3: 0}
	for i in 600:
		lo[Market.roll_stars(rng, 3, Port.star_weight_of({"port": {}}))] += 1
	check(hi[3] > lo[3] * 1.6 and lo[1] > 0 and hi[1] > 0, "the trade port at stage 2 rolls three stars far more often (%d vs %d of 600)" % [hi[3], lo[3]])
	var slots0 := Gear.deploy_slots([])
	Career.data.port["cargo"] = 1
	check(Gear.deploy_slots([]) == slots0 + 1, "the cargo district at stage 1: one more deploy slot (%d)" % Gear.deploy_slots([]))
	Career.data.port["cargo"] = 2
	Career.data.consum = {"lens": [], "cap": [{"tier": 1, "left": 5.0}], "probe": []}
	var m1 := float(Career.data.money)
	var rs := Consum.restock()
	# tool consumables were retired on 2026-10-23: the restock is gone with them, nothing is bought
	check(rs.is_empty() and absf(m1 - float(Career.data.money)) < 0.01, "the cargo district at stage 2 no longer restocks retired consumables (%s)" % str(rs))
	check(Port.queues_big({"port": {"tug": 1}}, 80.0) and not Port.queues_big({"port": {"tug": 2}}, 80.0) and not Port.queues_big({"port": {}}, 42.0), "a ship longer than the standard berth queues until the tug station's stage 2")
	Career.data.offers = [{"id": "Q-1", "ship": "gr7", "queued": true, "fee": 0.0}, {"id": "Q-2", "ship": "gr7", "fee": 0.0}]
	Career.data.active = {}
	check(Career.accept(0).is_empty() and Career.active().is_empty(), "a queued offer cannot be taken outright")
	check(Career.hold(0) and Career.data.offers.size() == 1 and Career.data.held.id == "Q-1" and not Career.data.held.has("queued"), "it is held instead")
	Career.data.offers = []
	Career.ensure_offers(func(_seed, _c): return [{"id": "N-1"}, {"id": "N-2"}, {"id": "N-3"}])
	check(Career.data.offers.size() == 3 and Career.data.offers[2].id == "Q-1" and Career.data.offers[2].get("held", false) and Career.data.held.is_empty(), "on the next market it is the last card, ready")
	var keys: Array = Route.nodes().map(func(n): return str(n.key))
	check(keys.has("port:ring") and keys.has("port:cargo") and Route.find("port:ring").kind == "port", "the port's works are route nodes (goals and pins)")
	check(Route.missing(Route.find("port:ring")) != "" , "a port goal says what it still wants (%s)" % Route.missing(Route.find("port:ring")))
	# ---- 3: the backdrop with everything lit
	for z in Port.ZONES:
		Career.data.port[z] = 2
	Career.data.active = {}
	Game.start_ship = "berth"
	Game.contract = {}
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(30)
	check(g.state == "play" and Port.total_stages() == 14, "the berth draws with the whole port lit (%d stages)" % Port.total_stages())
	g.queue_free()
	await _frames(2)
	print("PORT %s  (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	finished = true
