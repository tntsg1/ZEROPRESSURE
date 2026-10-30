extends "res://tests/g5_heat_ui_visual.gd"
# Actual native Viewport mouse targeting; facility/cash fixture only. No OS
# pointer automation and no claim of human usability or final industrial art.
func run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Career.path = "user://zp_test_g5_customer_ui_career.json"
	SaveGame.path = "user://zp_test_g5_customer_ui_field.json"
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
		g.open_exchange()
		await frames(8)
		var panel = g.console_ui
		check(panel != null and not paused,"ordinary client page opens through the real remote exchange at "+str(size))
		var tabs: TabContainer = panel.find_children("*","TabContainer",true,false)[0]
		tabs.current_tab = 2
		await mouse_click(find_button("结构钢坯\n查看报价与挂单"))
		check(panel.item == "steel_billet" and panel.grades.item_count == 3,"expanded commodity directory scrolls to its final steel card and accepts real native mouse selection")
		# Each viewport uses a different finite customer, so acceptance is real.
		panel.customer_picker.select(0 if size.x == 1280 else 1)
		panel._stamp = ""
		panel.refresh()
		await frames(5)
		var identity := str(panel.customer_picker.get_item_metadata(panel.customer_picker.selected))
		var before: float = Career.data.money
		check(panel.customer_accept.get_global_rect().end.x <= size.x and panel.customer_info.text.contains("未扣原料"),"native contract page fits the width and distinguishes net sales from profit")
		await capture("g5_customer_terms_%dx%d" % [size.x,size.y])
		await mouse_click(panel.customer_accept)
		check(Exchange.customer_status(Career.data.exchange,identity).state == "active" and Career.data.money == before,"real viewport mouse click accepts one finite client demand without giving advance money")
		await mouse_click(panel.customer_ship)
		check(Exchange.customer_status(Career.data.exchange,identity).matched == 0.0 and panel.message.text.contains("库存不足"),"real native dispatch control refuses unowned inventory instead of advancing the contract")
		await capture("g5_customer_ui_%dx%d" % [size.x,size.y])
		# Explicit numerical ledger fixture for an otherwise unshippable tail.
		# It is not a claimed physical receipt or another earned product.
		if size.x == 1280:
			var order_id := str(Exchange.customer_status(Career.data.exchange,identity).order_id)
			for order in Career.data.exchange.orders:
				if order.id != order_id: continue
				var reserve: float = Exchange.EPS*0.5*float(order.price)
				Career.data.exchange.actors[order.owner].cash += float(order.cash_reserved)-reserve
				order.remaining = Exchange.EPS*0.5
				order.cash_reserved = reserve
			panel._stamp = ""
			panel.refresh()
			check(panel.customer_ship.disabled and not panel.customer_cancel.disabled,"native page keeps cancellation enabled for a declared sub-epsilon tail that cannot be shipped")
		await mouse_click(panel.customer_cancel)
		check(Exchange.customer_status(Career.data.exchange,identity).state == "cancelled" and Career.data.money == before,"native scrolling reaches cancellation and returns only uncommitted customer funds")
		await mouse_click(find_button("返回 [Esc]"))
		check(g.console_ui == null and not paused,"native close remains clickable after customer interactions at "+str(size))
	await release()
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G5 CUSTOMER UI %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
