extends "res://tests/g5_industrial_cycle_check.gd"
# Existing finite merchant stock and restored facilities are declared fixtures.
# Acceptance, escrow, physical shipment/receiver, partial payment and reload use
# production code; this does not claim furnace production or human playtesting.
func customer(identity: String = "PORT-STEEL-01") -> Dictionary:
	return Exchange.customer_status(Career.data.exchange,identity)
func received(identity: String) -> bool:
	for i in 3000:
		await frames(1)
		var matches: Array = Career.data.exchange.trades.filter(func(row):return row.id == identity)
		if not matches.is_empty() and matches[0].state == "delivered": return true
	return false
func run() -> void:
	Career.path = "user://zp_test_g5_customer_career.json"
	SaveGame.path = "user://zp_test_g5_customer_field.json"
	SaveGame.allow_test = true
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.market = true
	Career.data.money = 100000.0
	Career.data.port = {"trade":0,"process":1}
	await spawn()
	check(Exchange.command("view").ok and customer().state == "available" and not Exchange.command("customer_accept",{"offer_id":"PORT-STEEL-01"}).ok,"customer demands are browsable but cannot be accepted before the actual trade facility is restored")
	Career.data.port.trade = 1 # Declared restored-facility fixture, not repair proof.
	# Remove the client's independent public bid before offering its exclusive
	# contract; otherwise the finite NPC's stock legitimately fills that bid.
	for order in Career.data.exchange.orders:
		if order.owner == "merchant_01" and order.item == "steel_billet" and order.state == "open": Exchange.cancel(Career.data.exchange,"merchant_01",str(order.id))
	var player_cash: float = Career.data.money
	var client_cash: float = Career.data.exchange.actors.merchant_01.cash
	check(Exchange.command("customer_accept",{"offer_id":"PORT-STEEL-01"}).ok,"company accepts a finite standing structural billet demand through the actual atomic adapter")
	check(Career.data.money == player_cash and Career.data.exchange.actors.merchant_01.cash == client_cash-Exchange.BILLET_PRICE and customer().matched == 0.0 and customer().delivered == 0.0,"acceptance reserves the client's real billet budget (108 号: $550 a tonne) without advance money, invented stock or false progress")
	var before := JSON.stringify(Career.data)
	# 37 号: the client's budget stands on the book by itself; accepting again changes nothing
	check(Exchange.command("customer_accept",{"offer_id":"PORT-STEEL-01"}).ok and Career.data.exchange.orders.filter(func(o): return o.get("contract_id","") == "PORT-STEEL-01").size() == 1 and Career.data.exchange.actors.merchant_01.cash == client_cash-Exchange.BILLET_PRICE,"repeated acceptance cannot lock a second budget or grant another reward")
	check(not Exchange.command("customer_ship",{"offer_id":"PORT-STEEL-01","quantity":0.4}).ok and customer().matched == 0.0,"unowned or unreceived qualifying products cannot be committed to a customer")
	# A real finite NPC posts its opening stock, not a generated player product.
	check(Exchange.post(Career.data.exchange,"merchant_00","sell","steel_billet",1,1.0,600.0).ok and customer().matched == 0.0,"other suppliers cannot consume the budget exclusively reserved for the player's accepted demand")
	check(Exchange.command("post",{"side":"buy","item":"steel_billet","grade":1,"quantity":1.0,"price":600.0}).ok,"player legally buys the finite qualifying stock rather than injecting a fulfilled inventory fixture")
	var buys: Array = Career.data.exchange.trades.filter(func(row):return row.buyer == "company" and row.item == "steel_billet")
	check(not buys.is_empty() and await received(str(buys[0].id)),"purchased qualifying steel becomes usable only after its actual native warehouse delivery")
	if buys.is_empty() or float(Career.data.exchange.actors.company.stock.get("steel_billet:1",0.0))<1.0:
		await release()
		quit(1)
		return
	var cash_before_ship: float = Career.data.money
	check(Exchange.command("customer_ship",{"offer_id":"PORT-STEEL-01","quantity":0.4}).ok,"company explicitly commits a partial shipment from its actual warehouse lot")
	var sales: Array = Career.data.exchange.trades.filter(func(row):return row.buy_order == customer().order_id)
	var identity := str(sales[0].id)
	# 37 号: paid on the sale; receipt still waits for the real delivery
	var paid := 0.4*Exchange.BILLET_PRICE*(1.0-Exchange.FEE)
	check(customer().matched == 0.4 and customer().delivered == 0.0 and is_equal_approx(Career.data.money, cash_before_ship+paid),"the sale is paid at once; it is not counted as received before native arrival")
	check(Exchange.command("customer_cancel",{"offer_id":"PORT-STEEL-01"}).ok and customer().state == "cancelled" and customer().delivered == 0.0,"cancelling uncommitted remainder keeps the existing shipment and does not fabricate delivery")
	check(absf(float(Career.data.exchange.actors.merchant_01.cash)-(client_cash-0.4*Exchange.BILLET_PRICE))<0.000001 and is_equal_approx(Career.data.money, cash_before_ship+paid),"only the uncommitted 0.6 t of the customer reserve is released; the 0.4 t sale stays paid")
	Career.save()
	SaveGame.save(g)
	await release()
	Career.data = {}
	Career.load_or_new()
	await spawn(true)
	check(customer().state == "cancelled" and customer().matched == 0.4 and customer().delivered == 0.0,"partial commitment and cancellation survive real career and field disk reload")
	check(await received(identity) and absf(float(customer().delivered)-0.4)<0.000001,"the original committed cargo still reaches the actual customer receiver after remainder cancellation and reload")
	check(absf(Career.data.money-(cash_before_ship+0.4*Exchange.BILLET_PRICE*(1.0-Exchange.FEE)))<0.000001,"customer pays exactly the actual 0.4-tonne receipt less the two-percent service fee")
	var settled: float = Career.data.money
	check(Exchange.confirm_local_receipt(identity,null,null).get("already_delivered",false) and Career.data.money == settled,"repeating an already committed physical receipt never pays twice")
	check(not Exchange.command("customer_accept",{"offer_id":"PORT-STEEL-01"}).ok,"a cancelled finite demand cannot be reopened to reset its budget or rewards")
	check(Exchange.command("customer_accept",{"offer_id":"SHOP-STEEL-01"}).ok and Exchange.command("customer_ship",{"offer_id":"SHOP-STEEL-01","quantity":0.5}).ok,"a separate finite customer accepts a full shipment using the remaining real stock")
	sales = Career.data.exchange.trades.filter(func(row):return row.buy_order == customer("SHOP-STEEL-01").order_id)
	check(customer("SHOP-STEEL-01").state == "active" and customer("SHOP-STEEL-01").delivered == 0.0,"a fully matched demand stays incomplete until its actual shipment arrives")
	check(await received(str(sales[0].id)) and customer("SHOP-STEEL-01").state == "complete" and customer("SHOP-STEEL-01").delivered == 0.5,"full order completion is derived from a nonzero actual native customer receipt")
	check(absf(float(Career.data.exchange.actors.company.stock.get("steel_billet:1",0.0))-0.1)<0.000001,"partial and full customer orders conserve the purchased tonne and leave the correct usable remainder")
	# Standalone numeric ledger fixture: not another physical delivery proof.
	var tail_state: Dictionary = Exchange.fresh(1000.0)
	Exchange.customer_command(tail_state,"customer_accept","PORT-STEEL-01")
	var tail_order: Dictionary = tail_state.orders[0]
	var tail := Exchange.EPS*0.5
	tail_order.remaining = tail
	tail_order.cash_reserved = tail*Exchange.BILLET_PRICE
	tail_state.trades.append({"buy_order":tail_order.id,"state":"delivered","quantity":1.0-tail})
	check(Exchange.customer_status(tail_state,"PORT-STEEL-01").state == "active" and Exchange.customer_command(tail_state,"customer_cancel","PORT-STEEL-01").ok and tail_order.cash_reserved == 0.0,"declared sub-epsilon remainder fixture stays open and cancellable instead of falsely completing with reserved client cash")
	await release()
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G5 CUSTOMER CONTRACT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
