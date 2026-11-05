extends "res://tests/guide_check.gd"
# 64 号: one source of material. A settled job pays no cash for the furnace's scrap; it lands in
# the warehouse as ingots (the tonnes it reported), the result says so; the exchange offers no raw
# scrap to buy, its merchants bid for ingots, ingots listed sell for cash; the furnace desk's feed
# is the ingot; the keep-the-scrap switch is gone; the main line's steel steps speak plainly.
#   tools/run_test.sh tests/ingot_check.gd --fixed-fps 60
const Ex = preload("res://scripts/industrial_exchange.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_ingot_career.json"
	SaveGame.path = "user://zp_test_ingot_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.money = 100000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.save()
	check(Ex.command("view").ok, "the exchange is open")
	# ---- a settlement: the scrap is ingots, not cash
	Career.data.active = {"id": "ING-1", "ship": "gr7", "fee": 0.0, "fee_paid": true, "scope": "full"}
	Career.save()
	var cash0 := float(Career.data.money)
	var stock0 := float(Career.data.exchange.actors.company.stock.get(Ex.INGOT, 0.0))
	var r := Career.settle({"job_id": "ING-1", "earned": 50000.0, "losses": 0.0, "grade": 2, "ingot_value": 12000.0, "ingot_t": 80.0})
	var tow := Port.tow_fee()
	var trade_bonus := snappedf(50000.0 * (Port.trade_k() - 1.0), 1.0)
	var expect := cash0 + 50000.0 + trade_bonus - tow - 12000.0 - float(r.get("installment", 0.0)) - float(r.get("interest", 0.0))
	check(absf(float(Career.data.money) - expect) < 1.0, "the furnace's scrap paid no cash (%s, expected %s)" % [Pal.money(float(Career.data.money)), Pal.money(expect)])
	var stock1 := float(Career.data.exchange.actors.company.stock.get(Ex.INGOT, 0.0))
	check(absf(stock1 - stock0 - 80.0) < 0.01 and absf(float(r.get("ingot_t", 0.0)) - 80.0) < 0.01, "80 t of ingots in the warehouse, and the result says so")
	Ex.command("view")
	check(absf(float(Career.data.exchange.actors.company.stock.get(Ex.INGOT, 0.0)) - stock1) < 0.01, "imported once only")
	# ---- the exchange: no raw scrap offered; merchants bid for ingots
	check(not Ex.buyable("mixed_metal:0") and not Ex.buyable("nonferrous_mix:0") and not Ex.buyable("ferrous_scrap:0") and Ex.buyable(Ex.INGOT), "raw scrap is not offered to buy")
	var bids := 0
	var scrap_sells := 0
	for o in Career.data.exchange.orders:
		if str(o.state) != "open" or str(o.owner) == Ex.PLAYER:
			continue
		if str(o.side) == "buy" and str(o.item) == "ferrous_scrap" and int(o.grade) == 1:
			bids += 1
		if str(o.side) == "sell" and str(o.item) in ["mixed_metal", "nonferrous_mix"]:
			scrap_sells += 1
	check(bids >= 2 and scrap_sells == 0, "merchants bid for ingots (%d) and sell no raw scrap" % bids)
	check(Ops.item_name(Ex.INGOT) == "钢锭", "the grade-1 feed is called ingots (%s)" % Ops.item_name(Ex.INGOT))
	# ---- ingots listed sell for cash
	cash0 = float(Career.data.money)
	var post := Ex.command("post", {"side": "sell", "item": "ferrous_scrap", "grade": 1, "quantity": 10.0, "price": 140.0})
	check(post.ok and float(Career.data.money) > cash0 + 1000.0, "10 t of ingots listed at $140 sell (%s → %s)" % [Pal.money(cash0), Pal.money(float(Career.data.money))])
	check(not Career.can_retain({"id": "x", "scope": "full"}), "the keep-the-scrap switch is gone")
	# ---- the main line's steel steps
	var plain := true
	for t in ["heat", "buy_feed", "clients"]:
		var s := str(Mainline.step("process").get("text", ""))
		plain = plain and s.find("炉料") < 0 and s.find("等级") < 0
	check(plain, "the steel chapter speaks of ingots and billets (%s)" % str(Mainline.step("process").get("text", "")))
	# ---- on site: the furnace desk's feed is the ingot; the exchange's sell page; the shelves
	await _spawn()
	await _frames(20)
	check(g.industrial_heat._feed_key() == Ex.INGOT, "the furnace desk's feed is the ingot")
	g.open_exchange("sell")
	await _frames(40)
	var ex = g.console_ui
	if ex != null and ex.has_method("_goods"):
		var any_raw := false
		ex.tab = "buy"
		for gd in ex._goods():
			any_raw = any_raw or str(gd[0]) in ["mixed_metal", "nonferrous_mix"]
		check(not any_raw, "the buy page lists no raw scrap")
		ex.tab = "sell"
	Cap.save(root, "res://tests/out/ingot_sell_zh.png")
	if ex != null:
		ex.close()
	await _frames(6)
	g.queue_free()
	await _frames(4)
	print("INGOT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
