extends "res://tests/guide_check.gd"
# 45 号: the exchange in the Delta Force layout (player picked A). Tabs; buying from a goods card
# through a seller row to the confirm; the sell window's chart is the book; its default price
# sells at once and is paid; the port buyback pays 70 %; the records read in plain words; a
# company counter opens on the right page. Shots of each page. Own test saves only.
#   tools/run_test.sh tests/exchange_ui_check.gd --fixed-fps 60
const Ex = preload("res://scripts/industrial_exchange.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_exchange_ui_career.json"
	SaveGame.path = "user://zp_test_exchange_ui_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _give(key: String, t: float) -> void:
	var st: Dictionary = Career.data.exchange
	var id := "TEST-%s" % key
	st.actors.company.lots[id] = {"id": id, "key": key, "available": t, "total": t, "origin": "manufactured"}
	st.actors.company.stock[key] = float(st.actors.company.stock.get(key, 0.0)) + t
	Career.save()


func _btn(prefix: String) -> Button:
	for b in g.console_ui.find_children("*", "Button", true, false):
		if str(b.text).begins_with(prefix) and b.is_visible_in_tree():
			return b
	return null


func _run() -> void:
	# 128 号 第 2 段: this tests the old exchange (order book, before the warehouse and the new trade hall):
	# the legacy switch, as the other pre-128 tests do
	StoreBook.ON = false
	HallMarket.ON = false
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 300000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.save()
	await _spawn()
	await _frames(10)
	check(Ex.command("view").ok, "the exchange is open")
	g.open_exchange()
	await _frames(6)
	var ui = g.console_ui
	check(ui != null and ui.tab == "buy", "it opens on buying")
	for t in ["购买", "出售", "交易记录", "航运", "船市"]:
		check(_btn(t) != null, "tab: %s" % t)
	await _frames(70)
	Cap.save(root, "res://tests/out/exchange_buy_zh.png")
	# buying: a card, a seller row, the confirm (64 号: nobody offers raw feed now — a merchant
	# offers ingots for the test)
	Ex.post(Career.data.exchange, "merchant_00", "sell", "ferrous_scrap", 1, 2.0, 180.0)
	Career.save()
	ui.item = "ferrous_scrap"
	ui.grade = 1
	ui.sellers_open = true
	ui._stamp = ""
	ui.refresh()
	await _frames(3)
	var b := _btn("购买")
	var rows := 0
	for x in ui.find_children("*", "Button", true, false):
		if str(x.text) == "购买" and not x in ui.tab_keys.values():
			rows += 1
	check(rows >= 1, "the grade 1 feed's sellers, one buy button a row (%d)" % rows)
	Cap.save(root, "res://tests/out/exchange_sellers_zh.png")
	for x in ui.find_children("*", "Button", true, false):
		if str(x.text) == "购买" and not x.disabled and not x in ui.tab_keys.values():
			x.pressed.emit()
			break
	await _frames(3)
	check(ui.purchase.visible and ui.purchase.ok_button_text == "确认购买", "buy opens the quantity confirm")
	var cash := float(Career.data.money)
	ui.purchase_quantity.value = 0.5
	ui.confirm_purchase()
	ui.purchase.hide()
	await _frames(3)
	check(float(Career.data.money) < cash, "confirmed: paid for 0.5 t")
	# selling: the chart is the book, the default price sells at once
	_give("steel_billet:1", 1.5)
	ui._tab("sell")
	await _frames(60)
	Cap.save(root, "res://tests/out/exchange_sell_cards_zh.png")
	ui.open_sell("steel_billet", 1)
	await _frames(4)
	var st: Dictionary = Career.data.exchange
	var rows_b: Array = ui.bar_rows(st, "steel_billet", 1)
	var bid_t := 0.0
	for o in st.orders:
		if str(o.state) == "open" and str(o.item) == "steel_billet" and int(o.grade) == 1 and str(o.side) == "buy" and str(o.owner) != "company" and o.get("exclusive_seller", "company") == "company" and not o.has("target_order"):
			bid_t += float(o.remaining)
	var chart_t := 0.0
	for r in rows_b:
		chart_t += float(r.buy)
	check(not rows_b.is_empty() and absf(chart_t - bid_t) < 0.001, "the chart's bids are the book's (%.2f t)" % chart_t)
	var bid := Ex.best_bid(st, "steel_billet", 1)
	check(not bid.is_empty() and is_equal_approx(ui.sell_price.value, float(bid.price)), "the price starts at the best bid (%s)" % Pal.money(ui.sell_price.value))
	Cap.save(root, "res://tests/out/exchange_sell_window_zh.png")
	# user 2026-10-26: the price by hand — a click on a column takes its price; the slider any price
	var pb = ui.sell_bars
	var wcol: float = minf((pb.size.x - 20.0) / rows_b.size(), 110.0)
	var x0c: float = (pb.size.x - wcol * rows_b.size()) * 0.5
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(x0c + wcol * 0.5, pb.size.y * 0.5)
	pb._gui_input(click)
	await _frames(2)
	check(is_equal_approx(ui.sell_price.value, float(rows_b[0].price)), "a click on the first column takes its price (%s)" % Pal.money(ui.sell_price.value))
	ui.sell_price_slide.value = ui.sell_price_slide.max_value * 0.8
	await _frames(2)
	check(absf(ui.sell_price.value - ui.sell_price_slide.max_value * 0.8) < 1.0 and ui.sell_price_slide.max_value > float(rows_b.back().price) * 2.0, "the slider sets any price, well past the book (%s)" % Pal.money(ui.sell_price.value))
	ui.sell_price.value = 12345.0
	await _frames(2)
	check(is_equal_approx(ui.sell_price_slide.value, 12345.0), "a typed price moves the slider with it")
	ui.sell_price.value = float(bid.price)
	ui.sell_qty.value = 0.5
	cash = float(Career.data.money)
	ui.list_it()
	await _frames(3)
	check(float(Career.data.money) > cash + 400.0, "listed at it: sold and paid at once (+%s)" % Pal.money(float(Career.data.money) - cash))
	# the port buyback
	ui.open_sell("steel_billet", 1)
	await _frames(2)
	ui.sell_qty.value = 0.5
	cash = float(Career.data.money)
	ui.sell_to_port()
	await _frames(3)
	var want := 0.5 * Ex.buyback_price("steel_billet:1") * (1.0 - Ex.FEE)
	check(absf(float(Career.data.money) - cash - want) < 1.0, "the port buys back at 70%% (+%s of %s)" % [Pal.money(float(Career.data.money) - cash), Pal.money(want)])
	# records
	_give("nonferrous_mix:0", 0.4)
	Ex.command("post", {"side": "sell", "item": "nonferrous_mix", "grade": 0, "quantity": 0.4, "price": 9000.0})
	ui._tab("records")
	await _frames(60)
	var recs: Array = ui.record_rows(Career.data.exchange)
	var kinds := {}
	for r in recs:
		kinds[str(r.state).split(" ")[0]] = true
	check(kinds.has("挂牌中") and kinds.has("已卖出"), "records in plain words: %s" % str(kinds.keys()))
	check(_btn("撤回") != null, "a listing can be withdrawn from its row")
	Cap.save(root, "res://tests/out/exchange_records_zh.png")
	ui.close()
	await _frames(4)
	# a counter: the clients' counter opens on selling
	g.open_exchange("company:merchant_01")
	await _frames(4)
	check(g.console_ui != null and g.console_ui.tab == "sell", "a client's counter opens on selling")
	g.console_ui.close()
	await _frames(4)
	g.open_exchange("feed")
	await _frames(4)
	check(g.console_ui != null and g.console_ui.item == "ferrous_scrap" and g.console_ui.grade == 1 and g.console_ui.sellers_open, "the feed shortcut opens on grade 1 feed's sellers")
	g.console_ui.close()
	g.queue_free()
	await _frames(4)
	print("EXCHANGE UI %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
