extends "res://tests/g5_exchange_check.gd"
# Explicit financial fixtures. No claims of physical delivery or human play.
func run() -> void:
	var state := Exchange.fresh(1000.0)
	for actor in state.actors.values():
		actor.stock = {}
		actor.lots = {}
	fixture_stock(state,"merchant_00",3.0)
	fixture_stock(state,"merchant_01",2.0)
	var cheap := Exchange.post(state,"merchant_00","sell","mixed_metal",0,3.0,90.0)
	var dear := Exchange.post(state,"merchant_01","sell","mixed_metal",0,2.0,100.0)
	var total_cash := money(state)
	var total_goods := goods(state)
	var result := Exchange.buy_quote(state,dear.order_id,0.5,100.0)
	check(result.ok and state.trades.size() == 1 and state.trades[0].sell_order == dear.order_id,"explicit purchase selects that exact seller even when another seller is cheaper")
	check(state.trades[0].unit_price == 100.0 and state.trades[0].quantity == 0.5 and state.trades[0].escrow == 50.0,"seller price and requested quantity produce exact real escrow")
	check(Exchange.book(state,"mixed_metal",0,"sell")[0].remaining == 3.0,"unselected cheaper offer is untouched")
	check(state.actors.company.cash == 950.0 and is_equal_approx(money(state),total_cash) and is_equal_approx(goods(state),total_goods),"cash and material conserved; undelivered purchases do not become warehouse stock")
	for request in [{"q":2.0,"p":100.0},{"q":0.0,"p":100.0},{"q":-1.0,"p":100.0},{"q":INF,"p":100.0},{"q":NAN,"p":100.0},{"q":0.5,"p":101.0}]:
		var before := JSON.stringify(state)
		result = Exchange.buy_quote(state,dear.order_id,float(request.q),float(request.p))
		check(not result.ok and JSON.stringify(state) == before,"invalid/excess/stale purchase changes no funds, orders or source slices: "+str(request))
	result = Exchange.buy_quote(state,dear.order_id,1.5,100.0)
	check(result.ok and state.trades[-1].sell_order == dear.order_id and state.trades[-1].quantity == 1.5,"remaining seller quantity can be purchased exactly")
	var before := JSON.stringify(state)
	result = Exchange.buy_quote(state,dear.order_id,0.1,100.0)
	check(not result.ok and JSON.stringify(state) == before,"sold-out quote never falls back to another seller or leaves a bid")
	state.actors.company.cash = 0.0
	before = JSON.stringify(state)
	result = Exchange.buy_quote(state,cheap.order_id,1.0,90.0)
	check(not result.ok and JSON.stringify(state) == before,"insufficient funds leave quote and source reservation intact")
	Exchange.cancel(state,"merchant_00",cheap.order_id)
	before = JSON.stringify(state)
	result = Exchange.buy_quote(state,cheap.order_id,1.0,90.0)
	check(not result.ok and JSON.stringify(state) == before,"withdrawn quote rejected without mutation")
	Career.path = "user://zp_test_market_direct_career.json"
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.port = {"trade":1}
	Career.data.money = 10000.0
	Exchange.command("view")
	var quote: Dictionary = Exchange.book(Career.data.exchange,"ferrous_scrap",1,"sell")[0]
	before = JSON.stringify(Career.data)
	var path_before := Career.path
	Career.path = "user://missing_direct_buy_directory/career.json"
	result = Exchange.command("buy_quote",{"order_id":quote.id,"price":quote.price,"quantity":0.25})
	check(not result.ok and result.reason == "save_failed" and JSON.stringify(Career.data) == before,"failed save atomically restores career, funds and seller inventory")
	Career.path = path_before
	result = Exchange.command("buy_quote",{"order_id":quote.id,"price":quote.price,"quantity":0.25})
	check(result.ok and is_equal_approx(Career.data.money,10000.0-0.25*float(quote.price)),"career command persists exact seller purchase")
	# JSON persistence converts StringName keys and integer Variants. Compare
	# the full JSON-domain state, not in-memory Variant key types.
	var persisted: Dictionary = JSON.parse_string(JSON.stringify(Career.data.exchange))
	Career.data = {}
	Career.load_or_new()
	check(Career.data.exchange == persisted,"quoted purchase survives real career reload with all orders, consignments, sources and funds unchanged")
	print("MARKET DIRECT BUY %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
