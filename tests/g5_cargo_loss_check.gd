extends SceneTree
# Adversarial geometric-cut fixture on a real physically dispatched cargo.
# Not player laser-input/whole-ship proof. Destruction must NEVER count as delivery.
const Exchange = preload("res://scripts/industrial_exchange.gd")
var g: Node
var checks := 0
var fails := 0
var job := {"id":"G5-CARGO-LOSS","ship":"pod","fee":0,"kit":{},"items":{}}
func _initialize() -> void:
	# 73 号: this test is about cargo lost in transit, not the racks: goods leave at once
	Warehouse.ON = false
	# 64 号: this checks the older feed chain (bought / kept scrap, sorting); kept in code, switched off in play
	Career.INGOTS = false
	preload("res://scripts/industrial_exchange.gd").INGOTS = false
	run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
func spawn(restore: bool = false) -> void:
	Game.contract = job.duplicate(true)
	Game.start_ship = "pod"
	SaveGame.load_requested = restore
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	await frames(8)
	g.tutorial = null
func release() -> void:
	g.queue_free()
	await frames(5)
func run() -> void:
	Career.path = "user://zp_test_g5_loss_career.json"
	SaveGame.path = "user://zp_test_g5_loss_field.json"
	SaveGame.allow_test = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.money = 100000.0
	Career.data.port = {"trade":1}
	Career.data.active = job.duplicate(true)
	await spawn()
	# the belt's merchants trading mixed metal among themselves (the older feed chain this fixture
	# runs on, INGOTS off) would hold the port carrier: kept off the book, as the other G5 checks do
	var viewed: bool = Exchange.command("view").ok
	Career.data.exchange.belt_quiet = true
	# 31 号: a deal with a belt merchant goes by freighter (Shipping.orbital), only the port's own
	# counters (the first Shipping.FIXED) by the port carrier this fixture is about: the belt's
	# opening orders and the freights they already matched are taken off the book
	var port_side := func(who): return who == Exchange.PLAYER or (str(who).begins_with("merchant_") and Shipping.merchant_index(str(who)) < Shipping.FIXED)
	Career.data.exchange.trades = Career.data.exchange.trades.filter(func(t): return t.buyer == Exchange.PLAYER or t.seller == Exchange.PLAYER)
	Career.data.exchange.orders = Career.data.exchange.orders.filter(func(o): return port_side.call(o.owner))
	# a port counter offers mixed metal from its own opening lot (when none is on the book yet)
	var st: Dictionary = Career.data.exchange
	if not st.orders.any(func(o): return o.state == "open" and o.side == "sell" and o.item == "mixed_metal" and o.owner != Exchange.PLAYER):
		for who in ["merchant_00", "merchant_01", "merchant_02"]:
			if float(st.actors[who].stock.get(Exchange.lot_key("mixed_metal", 0), 0.0)) >= 1.0:
				Exchange.post(st, who, "sell", "mixed_metal", 0, 1.0, 320.0)
				break
	check(viewed and Exchange.command("post",{"side":"buy","item":"mixed_metal","grade":0,"quantity":1.0,"price":1000.0}).ok,"actual finite seller and reserved player funds form a legitimate consignment")
	var trade: Dictionary = Career.data.exchange.trades.filter(func(row):return row.buyer == "company")[0]
	var identity := str(trade.id)
	for i in 100:
		await process_frame
		if g.exchange_logistics.active == identity and is_instance_valid(g.exchange_logistics.body): break
	var service = g.exchange_logistics
	check(service.active == identity and is_instance_valid(service.body),"ordinary carrier materializes the reserved real cargo before any destructive fixture")
	if not is_instance_valid(service.body): quit(1);return
	var cargo = service.body
	trade = Career.data.exchange.trades.filter(func(row):return row.id == identity)[0]
	var key := str(trade.cargo_key)
	var original_at: Vector2 = cargo.global_position
	g.world.position += Vector2(300,0)
	await frames(3)
	check(cargo.get_parent() == service and cargo.global_position.distance_to(original_at) < 10.0,"salvage hull transform cannot drag station-owned consignment away")
	var before := JSON.stringify(Career.data)
	var bad := Exchange.confirm_local_receipt(identity,cargo,service.warehouse)
	check(not bad.ok and JSON.stringify(Career.data) == before,"cargo outside actual receiving geometry grants neither delivery nor money")
	var piece = cargo.pieces[0]
	var result: Dictionary = g.world.commit_cut(piece,PackedVector2Array([Vector2(-100,0),Vector2(100,0)]),100.0)
	await frames(5)
	check(result.gone and g.world.key_piece(key) == null and service.waiting == "cargo_missing","actual geometric cut consumes the full declared cargo and service stops without replacing it")
	var money: float = Career.data.money
	var escrow: float = trade.escrow
	check(trade.state != "delivered" and Career.data.material_batches.is_empty() and escrow > 0.0,"destroyed goods are not accepted, paid out or silently refunded")
	check(Career.save(),"pending financial obligation is durably saved")
	SaveGame.save(g)
	var field := SaveGame.read()
	check(field.get("exchange_cargo",{}).get("materialized",{}).get(identity,false) and not field.world.pieces.any(func(row):return row.key == key),"atomic field contains loss evidence and no invented cargo body")
	await release()
	Career.data = {}
	Career.load_or_new()
	await spawn(true)
	await frames(360)
	trade = Career.data.exchange.trades.filter(func(row):return row.id == identity)[0]
	check(g.world.key_piece(key) == null and g.exchange_logistics.waiting == "cargo_missing","actual career and field reconstruction cannot rematerialize destroyed consignment")
	check(trade.state != "delivered" and float(trade.escrow) == escrow and Career.data.money == money and Career.data.material_batches.is_empty(),"reload preserves pending escrow without duplicating goods, proceeds or buyer cash")
	await release()
	Career.data = {}
	Career.load_or_new()
	await spawn(false)
	await frames(120)
	check(g.world.key_piece(key) == null and g.exchange_logistics.waiting == "cargo_missing","new contract scene without the former field snapshot still cannot remint a known lost consignment")
	await release()
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G5 CARGO LOSS %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
