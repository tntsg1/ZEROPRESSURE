extends "res://tests/guide_check.gd"
# 38 号: the trade hall — three company counters in the trade district with their own collision,
# E at a counter opens the exchange at that company, the quote board reads the book, and the
# client lighter comes alongside the warehouse yard for a port-counter trade and leaves after.
#   tools/run_test.sh tests/trade_hall_check.gd --fixed-fps 60
const Ex = preload("res://scripts/industrial_exchange.gd")


func _initialize() -> void:
	# 64 号: these check buying and its freight / lighter delivery from merchants' sell orders;
	# merchants no longer offer scrap in play, so they run on the older rules
	Career.INGOTS = false
	preload("res://scripts/industrial_exchange.gd").INGOTS = false
	Career.path = "user://zp_test_trade_hall_career.json"
	SaveGame.path = "user://zp_test_trade_hall_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 300000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.save()
	await _spawn()
	await _frames(10)
	check(Ex.command("view").ok, "the exchange is open")
	var th = g.trade_hall
	var box := PortStructure.box("trade")
	var inside := true
	for i in 3:
		inside = inside and box.encloses(Tram_rect(th.counter_rect(i)))
	check(th != null and inside, "three counters stand inside the trade district")
	var space: PhysicsDirectSpaceState2D = g.get_world_2d().direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	q.position = th.counter_rect(1).get_center() + Vector2(0, th.counter_rect(1).size.y * 0.25)
	q.collision_mask = 4
	check(not space.intersect_point(q, 4).is_empty(), "a counter's desk is solid")
	# the board reads the book
	var rows: Array = th.board()
	var ok := not rows.is_empty()
	var st: Dictionary = Career.data.exchange
	for row in rows:
		if str(row.name) == Ops.item_name("mixed_metal:0"):
			var best := INF
			for o in st.orders:
				if str(o.side) == "sell" and str(o.state) == "open" and str(o.item) == "mixed_metal" and str(o.owner) != "company":
					best = minf(best, float(o.price))
			ok = ok and is_equal_approx(float(row.ask), best)
	check(ok, "the quote board's best ask is the book's")
	# served at a counter
	g.drone.global_position = th.counter_spot(0)
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(30)
	check(th.near_counter() == "merchant_00", "at the first counter")
	var view: Vector2 = th.counter_rect(1).get_center() + Vector2(0, 7) * Geom.M
	g.cam_override = view
	g.cam_pos = view
	g.zoom_override = 0.5
	g.zoom_now = 0.5
	await _frames(70)
	Cap.save(root, "res://tests/out/trade_hall_zh.png")
	g.cam_override = null
	g.zoom_override = -1.0
	var ev := InputEventKey.new()
	ev.physical_keycode = Keys.codes("use")[0]
	ev.pressed = true
	g._unhandled_input(ev)
	await _frames(10)
	check(g.console_ui != null and g.console_ui.get_script() == preload("res://scripts/exchange_panel.gd") and str(g.console_ui.start_page) == "company:merchant_00", "E at the counter opens the exchange at that company")
	if g.console_ui != null:
		g.console_ui.close()
	await _frames(6)
	# a buy from a port counter: the client lighter comes alongside the yard, and leaves after
	var o := {}
	for row in st.orders:
		if str(row.owner) == "merchant_00" and str(row.side) == "sell" and str(row.state) == "open" and float(row.remaining) >= 0.5:
			o = row
	if not o.is_empty():
		check(Ex.command("buy_quote", {"order_id": str(o.id), "quantity": minf(1.0, float(o.remaining)), "price": float(o.price)}).ok, "bought at the port counter")
		var came := false
		for i in 900:
			await _frames(1)
			if th.lighter_k >= 1.0:
				came = true
				break
		check(came, "the client lighter comes alongside the yard")
		var yard_view: Vector2 = g.exchange_logistics.global_position + Vector2(-8, 0) * Geom.M
		g.cam_override = yard_view
		g.cam_pos = yard_view
		g.zoom_override = 0.4
		g.zoom_now = 0.4
		await _frames(70)
		Cap.save(root, "res://tests/out/trade_lighter_zh.png")
		g.cam_override = null
		g.zoom_override = -1.0
		var gone := false
		for i in 6000:
			await _frames(1)
			if th.lighter_k <= 0.0:
				gone = true
				break
		check(gone, "delivered, it leaves")
	else:
		check(false, "merchant_00 has something to sell")
	g.queue_free()
	await _frames(4)
	print("TRADE HALL %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()


func Tram_rect(r: Rect2) -> Rect2:
	return r
