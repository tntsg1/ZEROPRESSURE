extends "res://tests/g5_heat_ui_visual.gd"
# Native viewport input and screenshots; facilities/cash are declared fixtures.
func run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Career.path = "user://zp_test_market_direct_ui_career.json"
	SaveGame.path = "user://zp_test_market_direct_ui_field.json"
	SaveGame.allow_test = true
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.market = true
	Career.data.money = 100000.0
	Career.data.port = {"trade":1,"process":1}
	Txt.zh = true
	await spawn()
	for size in [Vector2i(1280,720),Vector2i(1600,900)]:
		root.content_scale_size = size
		root.size = size
		g.open_console("terminal")
		await frames(5)
		var terminal = g.console_ui
		terminal.set_tab(5)
		terminal.route_panel.select_key("port:trade")
		await frames(65)
		check(terminal.exchange_button.get_global_rect().size.x >= 350 and terminal.exchange_button.get_global_rect().position.y > size.y-85,"dedicated full-size exchange entry does not overlap the engineering goal strip at "+str(size))
		await capture("market_entry_%dx%d" % [size.x,size.y])
		await mouse_click(terminal.exchange_button)
		await frames(5)
		var panel = g.console_ui
		check(panel != null and panel.offer_buttons.size() >= 2,"actual market presents multiple individually priced seller purchase buttons")
		panel.max_price.value = 1.0
		check(panel.offer_buttons.is_empty(),"left price filter removes listings above the maximum")
		panel.max_price.value = 0.0
		check(panel.offer_buttons.size() >= 2,"clearing the price ceiling restores real seller listings")
		await capture("market_multi_sellers_%dx%d" % [size.x,size.y])
		# Freeze explicitly for stable native UI selection; live-clock behavior
		# remains covered independently by g5_exchange_ui_check.gd.
		panel.toggle_pause()
		panel.select_item("ferrous_scrap")
		await frames(5)
		var rows: Array = Exchange.book(Career.data.exchange,"ferrous_scrap",1,"sell")
		var quote: Dictionary = rows[0]
		await capture("market_quotes_%dx%d" % [size.x,size.y])
		await mouse_click(panel.offer_buttons[str(quote.id)])
		check(panel.purchase.visible and panel.purchase_quantity.max_value == float(quote.remaining),"real mouse click opens selected seller confirmation with that seller's exact quantity cap")
		panel.purchase_quantity.value = 100000.0
		check(panel.purchase_quantity.value == float(quote.remaining),"quantity control cannot exceed selected seller's stock")
		panel.purchase_quantity.value = 0.25
		panel.update_purchase_total()
		await frames(3)
		if root.gui_embed_subwindows: await capture("market_purchase_%dx%d" % [size.x,size.y])
		var before: float = Career.data.money
		var trades_before: int = Career.data.exchange.trades.size()
		# Dialog may be an embedded or a separate native Window; route actual
		# mouse events into its own viewport, never emit the confirmed signal.
		var confirm: Button = panel.purchase.get_ok_button()
		var point := confirm.get_global_rect().get_center()
		var down := InputEventMouseButton.new()
		down.position = point
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		if root.gui_embed_subwindows:
			down.position += Vector2(panel.purchase.position)
			root.push_input(down,true)
		else: panel.purchase.push_input(down,true)
		await frames(1)
		var up := down.duplicate()
		up.pressed = false
		if root.gui_embed_subwindows: root.push_input(up,true)
		else: panel.purchase.push_input(up,true)
		await frames(4)
		check(not panel.purchase.visible and Career.data.exchange.trades.size() == trades_before+1,"native confirmation mouse input commits exactly one consignment")
		var trade: Dictionary = Career.data.exchange.trades[-1]
		check(trade.sell_order == quote.id and trade.quantity == 0.25 and is_equal_approx(before-Career.data.money,0.25*float(quote.price)),"purchase uses selected order, exact quantity and price; no fallback seller")
		check(panel.message.text.contains("买好了") and panel.message.text.contains("下方炉台") and panel.message.text.contains("把仓库炉料送到炉口") and trade.state != "delivered","successful purchase explains warehouse receipt, furnace location and bring-feed action without granting instant stock")
		await mouse_click(find_button("返回 [Esc]"))
		check(g.console_ui == null and not paused,"closing purchased market resumes original world")
	for i in 2400:
		var pending: Array = Career.data.exchange.trades.filter(func(row):return row.buyer == Exchange.PLAYER and row.state != "delivered")
		if pending.is_empty(): break
		await frames(1)
	var bought: Array = Career.data.exchange.trades.filter(func(row):return row.buyer == Exchange.PLAYER)
	check(bought.size() == 2 and bought.all(func(row):return row.state == "delivered"),"both directly purchased consignments reach the actual native warehouse receiver")
	check(is_equal_approx(float(Career.data.exchange.actors.company.stock.get("ferrous_scrap:1",0.0)),0.5),"real receipts grant exactly the bought half-tonne once")
	await release()
	print("MARKET DIRECT UI %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
