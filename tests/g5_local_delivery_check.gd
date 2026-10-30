extends SceneTree
# Declared local merchant opening stocks; native cargo, carrier, obstacle,
# collision sweeps and receiver commit. Not orbital-route or human playtesting.
const Exchange = preload("res://scripts/industrial_exchange.gd")
const Loads = preload("res://scripts/load_motion.gd")
const CAREER := "user://zp_test_g5_local_delivery_career.json"
const FIELD := "user://zp_test_g5_local_delivery_field.json"
var g: Node
var job := {"id":"G5-LOCAL-001","ship":"pod","fee":0,"kit":{},"items":{}}
var checks := 0
var fails := 0
func _initialize() -> void:
	# 73 号: this test is about the physical feed and delivery runs, not the racks: goods leave at once
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
func trade(identity: String) -> Dictionary:
	return Career.data.exchange.trades.filter(func(row):return row.id == identity)[0]
func player_quantity() -> float:
	return float(Career.data.exchange.actors.company.stock.get("mixed_metal:0",0.0))
func run() -> void:
	Career.path = CAREER
	SaveGame.path = FIELD
	SaveGame.allow_test = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.port = {"trade":1}
	Career.data.money = 100000.0
	Career.data.active = job.duplicate(true)
	await spawn()
	var service = g.exchange_logistics
	check(service != null and service.warehouse is Area2D, "actual game owns a physical warehouse receiver and freight carrier")
	var obstacle_at: Vector2 = service.global_position
	var obstacle = g.world.add_piece("cargo",Geom.rect_poly(Rect2(obstacle_at-Vector2(6,50),Vector2(12,100))),{"key":"LOCAL-BLOCKER","mass":1.0,"scope":false})
	g.world.make_body([obstacle],null)
	var obstacle_body = obstacle.body
	obstacle_body.freeze = true
	obstacle_body.capture = "declared_obstacle"
	check(Exchange.command("view").ok, "local market initializes real finite merchant inventory")
	# the belt's merchants trading among themselves (INGOTS off here) would hold the port carrier
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
	var result := Exchange.command("post",{"side":"buy","item":"mixed_metal","grade":0,"quantity":1.0,"price":1000.0})
	check(result.ok, "player legally funds a real matched local purchase")
	var purchases: Array = Career.data.exchange.trades.filter(func(row):return row.buyer == "company")
	if purchases.is_empty(): check(false,"purchase matched a finite merchant offer");quit(1);return
	var identity := str(purchases[0].id)
	var paid: float = Career.data.money
	check(player_quantity() == 0.0 and trade(identity).state == "awaiting_dispatch", "matched purchase is not usable warehouse stock before physical delivery")
	var prior := Vector2.INF
	var max_jump := 0.0
	for i in 800:
		await process_frame
		if is_instance_valid(service.body) and service.active == identity:
			var at: Vector2 = service.body.global_position
			if prior.is_finite(): max_jump = maxf(max_jump,at.distance_to(prior))
			prior = at
	check(service.active == identity and service.waiting == "cargo_obstructed" and trade(identity).state != "delivered", "full-size cargo physically stops at an obstruction instead of phasing through")
	check(player_quantity() == 0.0 and Career.data.money == paid and is_instance_valid(service.body) and service.body.collision_mask == FreeBody.MASK, "blocked cargo grants no stock, refund or payout and keeps native collision")
	check(max_jump <= 5.0, "carrier advances continuously at its actual speed; no cargo teleport")
	for i in 100:
		check_move(Loads.move(obstacle_body,Vector2(0,-2)))
		await process_frame
	check(not obstacle.gone and obstacle_body.global_position.y < obstacle_at.y-150, "declared blocker is physically swept out through the real opening, not deleted")
	check(trade(identity).state == "in_transit" and is_instance_valid(service.body), "actual delivery resumes after the route is physically clear")
	if not is_instance_valid(service.body): quit(1);return
	var cargo_key := str(trade(identity).cargo_key)
	var saved_at: Vector2 = service.body.global_position
	Career.save()
	SaveGame.save(g)
	var stale_field := SaveGame.read()
	check(not stale_field.is_empty(), "mid-transport scene and career snapshots really exist")
	await release()
	Career.data = {}
	Career.load_or_new()
	await spawn(true)
	service = g.exchange_logistics
	var restored = g.world.key_piece(cargo_key)
	check(restored != null and restored.body != null and restored.body.global_position.distance_to(saved_at) < 20.0 and g.world.pieces.values().filter(func(piece):return not piece.gone and piece.key == cargo_key).size() == 1, "actual field reconstruction resumes the same single cargo near its saved physical pose")
	for i in 1200:
		await process_frame
		if trade(identity).state == "delivered": break
	check(trade(identity).state == "delivered" and is_equal_approx(player_quantity(),1.0), "native warehouse overlap and full-body receipt produce exactly one usable tonne")
	check(trade(identity).has("receipt") and is_equal_approx(trade(identity).receipt.mass_t,1.0) and Career.data.money == paid and float(trade(identity).escrow) == 0.0, "actual receiver proof releases escrow without granting the buyer free cash")
	check(Career.data.material_batches.any(func(batch):return batch.id == "DELIVERED:"+identity and batch.source_lots == trade(identity).source_lots), "warehouse inventory retains the consumed merchant source identities")
	var once := JSON.stringify(Career.data)
	result = Exchange.confirm_local_receipt(identity,null,service.warehouse)
	check(result.get("already_delivered",false) and JSON.stringify(Career.data) == once, "repeated delivery commit cannot duplicate inventory or payment")
	# a port counter bidding for it (the belt's bids went by freighter and are off this book)
	if not Career.data.exchange.orders.any(func(o): return o.state == "open" and o.side == "buy" and o.item == "mixed_metal" and o.owner != Exchange.PLAYER):
		Exchange.post(Career.data.exchange, "merchant_01", "buy", "mixed_metal", 0, 1.0, 300.0)
	var before_sale: float = Career.data.money
	result = Exchange.command("post",{"side":"sell","item":"mixed_metal","grade":0,"quantity":1.0,"price":1.0})
	var sales: Array = Career.data.exchange.trades.filter(func(row):return row.seller == "company")
	check(result.ok and not sales.is_empty() and player_quantity() == 0.0, "actual received stock can be reserved for an outgoing sale once")
	if sales.is_empty(): quit(1);return
	var sale_id := str(sales[0].id)
	for i in 800:
		await process_frame
		if service.active == sale_id and trade(sale_id).state == "in_transit": break
	var sale_before: float = Career.data.money
	Career.path = "user://zp_g5_delivery_missing_%d/sub/career.json" % Time.get_ticks_usec()
	for i in 800:
		await process_frame
		if service.waiting == "save_failed": break
	check(service.waiting == "save_failed" and trade(sale_id).state != "delivered" and Career.data.money == sale_before and is_instance_valid(service.body), "failed payout persistence holds the actual delivered cargo and rolls back money/consumption together")
	Career.path = CAREER
	for i in 300:
		await process_frame
		if trade(sale_id).state == "delivered": break
	# 37 号: a company sale is paid when it sells; the handoff only moves the goods
	var expected := float(trade(sale_id).quantity)*float(trade(sale_id).unit_price)-float(trade(sale_id).fee)
	check(trade(sale_id).state == "delivered" and trade(sale_id).get("paid", false) and is_equal_approx(Career.data.money, before_sale + expected) and is_equal_approx(Career.data.money, sale_before) and player_quantity() == 0.0,
		"the sale paid its net proceeds once, when it sold; the retried handoff after the failed save pays nothing more")
	once = JSON.stringify(Career.data)
	result = Exchange.confirm_local_receipt(sale_id,null,service.client)
	check(result.get("already_delivered",false) and JSON.stringify(Career.data) == once, "outgoing delivery cannot pay a second time")
	var final_money: float = Career.data.money
	await release()
	SaveGame.write_file(FIELD,stale_field)
	await spawn(true)
	await frames(5)
	check(Career.data.money == final_money and player_quantity() == 0.0 and g.world.key_piece(cargo_key) == null, "old field after durable delivery retires only its stale received cargo without duplicate goods or proceeds")
	await release()
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G5 LOCAL PHYSICAL DELIVERY %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
func check_move(ok: bool) -> void:
	if not ok:
		check(false,"blocker clearance movement retains full native collision")
