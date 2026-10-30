extends SceneTree
# Financial/state fixtures only. Does not claim physical shipping or playtesting.
const Exchange = preload("res://scripts/industrial_exchange.gd")
const FILE := "user://zp_test_g5_exchange_career.json"
var checks := 0
var fails := 0
func _initialize() -> void:
	# 64 号: this checks the older feed chain (bought / kept scrap, sorting); kept in code, switched off in play
	Career.INGOTS = false
	preload("res://scripts/industrial_exchange.gd").INGOTS = false
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
func money(state: Dictionary) -> float:
	var total := 0.0
	for actor in state.actors.values(): total += float(actor.cash)
	for order in state.orders: total += float(order.cash_reserved)
	for trade in state.trades: total += float(trade.escrow)
	return total
func goods(state: Dictionary) -> float:
	var total := 0.0
	for actor in state.actors.values():
		for quantity in actor.stock.values(): total += float(quantity)
	for order in state.orders:
		if order.side == "sell" and order.state == "open": total += float(order.remaining)
	for trade in state.trades: total += float(trade.quantity)
	return total
func fixture_stock(state: Dictionary, owner: String, quantity: float) -> void:
	# Declared financial source, not claimed as physical player receipt.
	var identity := "fixture:"+owner
	state.actors[owner].stock = {"mixed_metal:0":quantity}
	state.actors[owner].lots = {identity:{"id":identity,"key":"mixed_metal:0","available":quantity,"total":quantity,"origin":"declared_fixture"}}
func run() -> void:
	var state := Exchange.fresh(1000.0)
	for actor in state.actors.values():
		actor.stock = {}
		actor.lots = {}
	fixture_stock(state,"merchant_00",3.0)
	fixture_stock(state,"merchant_01",2.0)
	fixture_stock(state,"company",6.0)
	var initial_money := money(state)
	var initial_goods := goods(state)
	Exchange.post(state,"merchant_00","sell","mixed_metal",0,3.0,100.0)
	Exchange.post(state,"merchant_01","sell","mixed_metal",0,2.0,90.0)
	var result := Exchange.post(state,"company","buy","mixed_metal",0,5.0,110.0)
	check(result.ok and state.trades.size() == 2 and state.trades[0].unit_price == 90.0 and state.trades[1].unit_price == 100.0, "price-compatible bids consume cheapest resting offers first")
	check(is_equal_approx(state.actors.company.cash,520.0) and is_equal_approx(money(state),initial_money), "price improvement releases unused reserve; total cash plus escrow is conserved")
	check(is_equal_approx(state.actors.company.stock["mixed_metal:0"],6.0) and is_equal_approx(goods(state),initial_goods), "matching creates traceable consignment, without granting undelivered player stock")
	check(state.trades.all(func(trade):return trade.state == "awaiting_dispatch" and trade.escrow > 0.0), "matched consignments await actual shipping and keep buyer funds in escrow")
	# Keep the long-running NPC market independent of the later partial-sale
	# fixture: companies are allowed to place better real bids while time passes.
	var expiry := state.duplicate(true)
	result = Exchange.post(expiry,"company","buy","mixed_metal",0,10.0,1.0)
	var permanent := str(result.order_id)
	Exchange.advance(expiry,999999.0)
	var permanent_order: Dictionary = expiry.orders.filter(func(order):return order.id == permanent)[0]
	check(permanent_order.state == "open" and permanent_order.remaining == 10.0, "player limit order survives arbitrarily advanced game time without expiry")
	var cash: float = expiry.actors.company.cash
	result = Exchange.cancel(expiry,"company",permanent)
	check(result.ok and is_equal_approx(expiry.actors.company.cash,cash+10.0), "free cancellation returns all unfilled buy funds")
	result = Exchange.post(state,"company","sell","mixed_metal",0,4.0,150.0)
	var sell_id := str(result.order_id)
	var before := JSON.stringify(state)
	var denied := Exchange.post(state,"company","sell","mixed_metal",0,3.0,150.0)
	check(not denied.ok and JSON.stringify(state) == before, "the same reserved tonnes cannot back a second sale")
	denied = Exchange.cancel(state,"merchant_00",sell_id)
	check(not denied.ok and JSON.stringify(state) == before, "another company cannot cancel or release player reservations")
	cash = float(state.actors.company.cash)
	Exchange.post(state,"merchant_02","buy","mixed_metal",0,2.0,160.0)
	# 37 号 (player 2026-10-25: "list it, someone buys, done"): the seller is paid on the sale
	check(float(state.actors.company.cash) > cash, "the seller is paid when the sale matches (37 号)")
	result = Exchange.cancel(state,"company",sell_id)
	check(result.ok and is_equal_approx(state.actors.company.stock["mixed_metal:0"],4.0) and state.trades[-1].quantity == 2.0, "partial cancellation releases only unsold stock and retains matched obligations")
	check(is_equal_approx(money(state),initial_money) and is_equal_approx(goods(state),initial_goods), "partial matches and both cancellation paths conserve funds and tonnes")
	check(state.trades[-1].source_lots == [{"source_id":"fixture:company","quantity":2.0}] and is_equal_approx(state.actors.company.lots["fixture:company"].available,4.0), "matched consignment retains exact source slice while cancellation releases only unmatched source stock")
	before = JSON.stringify(state)
	for quantity in [0.0,-1.0,INF,NAN]:
		denied = Exchange.post(state,"company","buy","mixed_metal",0,quantity,1.0)
		check(not denied.ok and JSON.stringify(state) == before, "invalid order quantity cannot mutate finances: %s" % str(quantity))
	denied = Exchange.post(state,"company","buy","mixed_metal",99,1.0,1.0)
	check(not denied.ok and JSON.stringify(state) == before, "unsupported quality cannot masquerade as interchangeable inventory")
	var source := {"id":"DECLARED-RECEIPT","mass_t":0.25,"state":"raw_received","material":"ungraded_scrap"}
	Exchange.import_received(state,[source])
	Exchange.import_received(state,[source])
	check(is_equal_approx(goods(state),initial_goods+0.25), "settled source identity is imported once, without regenerating stock on reopening")
	var near := Exchange.fresh(1000.0)
	fixture_stock(near,"merchant_00",1.0)
	fixture_stock(near,"merchant_01",1.0)
	Exchange.post(near,"merchant_00","sell","mixed_metal",0,1.0,100.0004)
	Exchange.post(near,"merchant_01","sell","mixed_metal",0,1.0,100.0003)
	Exchange.post(near,"company","buy","mixed_metal",0,1.0,101.0)
	check(near.trades[0].seller == "merchant_01" and near.trades[0].unit_price == 100.0003, "nearby but unequal asks retain strict cheapest-price priority")
	near = Exchange.fresh(1000.0)
	fixture_stock(near,"company",1.0)
	Exchange.post(near,"merchant_00","buy","mixed_metal",0,1.0,100.0003)
	Exchange.post(near,"merchant_01","buy","mixed_metal",0,1.0,100.0004)
	Exchange.post(near,"company","sell","mixed_metal",0,1.0,99.0)
	check(near.trades[0].buyer == "merchant_01", "nearby but unequal bids retain strict highest-price priority")
	var tail := Exchange.fresh(1000.0)
	fixture_stock(tail,"merchant_00",1.0)
	Exchange.post(tail,"merchant_00","sell","mixed_metal",0,1.0,100.0)
	result = Exchange.post(tail,"company","buy","mixed_metal",0,1.0000005,100.0)
	var tail_id := str(result.order_id)
	var tail_order: Dictionary = tail.orders.filter(func(order):return order.id == tail_id)[0]
	check(tail_order.state == "open" and tail_order.remaining > 0.0 and tail_order.cash_reserved > 0.0, "tiny positive buy tail stays open with visible cancellable reserve")
	result = Exchange.cancel(tail,"company",tail_id)
	check(result.ok and is_equal_approx(tail.actors.company.cash,900.0), "cancelling tiny buy tail releases every unspent credit")
	tail = Exchange.fresh(1000.0)
	fixture_stock(tail,"company",1.0000005)
	Exchange.post(tail,"merchant_00","buy","mixed_metal",0,1.0,100.0)
	result = Exchange.post(tail,"company","sell","mixed_metal",0,1.0000005,100.0)
	tail_id = str(result.order_id)
	tail_order = tail.orders.filter(func(order):return order.id == tail_id)[0]
	check(tail_order.state == "open" and tail_order.remaining > 0.0, "tiny positive sell tail is not falsely labelled fully filled")
	result = Exchange.cancel(tail,"company",tail_id)
	check(result.ok and tail.actors.company.stock["mixed_metal:0"] > 0.0, "cancelling tiny sell tail releases its exact remaining goods")
	var legacy := Exchange.fresh(1000.0)
	Exchange.import_received(legacy,[{"id":"LEGACY-ACTUAL-SOURCE","mass_t":2.0,"material":"ungraded_scrap","state":"raw_received"}])
	var old_sell := Exchange.post(legacy,"company","sell","mixed_metal",0,1.5,300.0)
	Exchange.post(legacy,"merchant_01","buy","mixed_metal",0,0.5,300.0)
	Exchange.post(legacy,"merchant_03","buy","mixed_metal",0,0.5,300.0)
	check(legacy.trades.size() == 2 and legacy.trades.all(func(trade):return trade.source_lots == [{"source_id":"LEGACY-ACTUAL-SOURCE","quantity":0.5}]), "one source batch splits into two distinct consignments with exact non-overlapping quantities")
	var old_money := money(legacy)
	var old_goods := goods(legacy)
	legacy.version = 1
	legacy.seeded = true
	for actor in legacy.actors.values(): actor.erase("lots")
	for order in legacy.orders: order.erase("source_lots")
	for trade in legacy.trades: trade.erase("source_lots")
	var migrated := legacy.duplicate(true)
	check(Exchange.migrate(migrated).ok and migrated.version == 2 and money(migrated) == old_money and goods(migrated) == old_goods, "aggregate-only exchange migration preserves actual pending escrow, orders and tonnes")
	var migrated_sell: Dictionary = migrated.orders.filter(func(order):return order.id == old_sell.order_id)[0]
	check(migrated_sell.source_lots[0].source_id == "LEGACY-ACTUAL-SOURCE" and migrated.trades[0].source_lots[0].source_id == "LEGACY-ACTUAL-SOURCE", "legacy migration reconstructs both sold and unsold slices from original receiver identity")
	var corrupt := legacy.duplicate(true)
	corrupt.sources = {}
	before = JSON.stringify(corrupt)
	check(not Exchange.migrate(corrupt).ok and JSON.stringify(corrupt) == before, "legacy migration with missing player source evidence fails without inventing stock or discarding the old state")
	Career.path = FILE
	Career.data = Career.fresh()
	Career.data.money = 1000.0
	before = JSON.stringify(Career.data)
	result = Exchange.command("view")
	check(not result.ok and JSON.stringify(Career.data) == before, "new career cannot open business market before existing first-job unlock")
	Career.data.market = true
	result = Exchange.command("view")
	check(result.ok and Career.data.exchange.actors.size() == 26 and Career.data.exchange.actors.has("sort_supplier") and range(24).all(func(i):return Career.data.exchange.actors.has("merchant_%02d"%i)) and Career.data.money == 1000.0, "browsing preserves player and all 24 merchant identities plus the finite sorting supplier without charging trade repair again")
	before = JSON.stringify(Career.data)
	result = Exchange.command("post",{"side":"buy","item":"mixed_metal","grade":0,"quantity":2.0,"price":100.0})
	check(not result.ok and result.reason == "trade_repair_required" and JSON.stringify(Career.data) == before, "unrepaired trade district allows browsing but blocks new commercial trades")
	Career.data.port.trade = 1 # declared repaired-stage fixture, not a repair playthrough
	result = Exchange.command("post",{"side":"buy","item":"mixed_metal","grade":0,"quantity":2.0,"price":100.0})
	check(result.ok and is_equal_approx(Career.data.money,800.0), "production adapter reserves actual career cash and persists the order together")
	var order_id := str(result.order_id)
	var disk := SaveGame.read_career(FILE)
	var disk_order: Dictionary = disk.exchange.orders.filter(func(order):return order.id == order_id)[0]
	check(is_equal_approx(disk.money,800.0) and disk_order.remaining == 2.0 and disk_order.owner == "company", "checksum career file includes the same reserved order and spendable cash")
	Career.data = {}
	Career.load_or_new()
	check(Career.data.exchange.orders.any(func(order):return order.id == order_id and order.state == "open") and is_equal_approx(Career.data.money,800.0), "actual career disk load preserves permanent order and escrow without reposting")
	before = JSON.stringify(Career.data)
	Career.path = "user://zp_g5_exchange_missing_%d/sub/career.json" % Time.get_ticks_usec()
	result = Exchange.command("cancel",{"order_id":order_id})
	check(not result.ok and result.reason == "save_failed" and JSON.stringify(Career.data) == before, "failed cancellation disk commit rolls back released cash and order state together")
	Career.path = FILE
	result = Exchange.command("cancel",{"order_id":order_id})
	check(result.ok and is_equal_approx(Career.data.money,1000.0), "successful retry releases exact remaining funds once")
	before = JSON.stringify(Career.data)
	result = Exchange.command("cancel",{"order_id":order_id})
	check(not result.ok and JSON.stringify(Career.data) == before, "repeated cancellation cannot create money")
	Career.data.exchange = legacy
	Career.save()
	Career.data = {}
	Career.load_or_new()
	result = Exchange.command("view")
	check(result.ok and Career.data.exchange.version == 2 and Career.data.exchange.trades[0].source_lots[0].source_id == "LEGACY-ACTUAL-SOURCE" and is_equal_approx(Career.data.money,1000.0), "actual v1 career disk upgrades sources through the production adapter without reposting or paying out")
	print("G5 EXCHANGE STATE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
