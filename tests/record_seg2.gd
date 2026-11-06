extends "res://tests/record108.gd"
# 128 号 第 2 段 video for the owner (~30 s): the stores' price ladder and one-key listing → the sell
# page's curve and own price → the buy page → the order board, taking an order → its crate on the
# freight train → the client's freighter coming in, loaded at the dock, leaving. Own test saves only.
#   tools/run_test.sh tests/record_seg2.gd --write-movie recordings/seg2.avi --fixed-fps 30

const PS = preload("res://scripts/port_structure.gd")
const FW = preload("res://scripts/freight_works.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_recseg2_career.json"
	SaveGame.path = "user://zp_test_recseg2_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _part(uid: String, nk: String, v: float, tag: String, mass: float) -> Dictionary:
	return {"uid": uid, "nk": nk, "cls": "power", "cond": 1.0, "value": v, "ship": "tug", "tag": tag, "mass": mass, "job": "TUG-001"}


func _key(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = true
	root.push_input(ev)


func _run() -> void:
	Txt.zh = true
	cap_total = 5
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.prologue_done = true
	Career.data.onboard = "done"
	Career.data.history = [{"id": "TUG-001"}, {"id": "S09-001"}]
	Career.data.seen = {"port_walk": true, "first_ship": true, "intro": true, "belt_prelude": true, "first_tow": true, "store_guide_done": true, "store_counter": true}
	Career.data.port = {"salvage": 1, "trade": 1}
	Career.data.upgrades = {"lights": 1, "furnace_main": 1, "net_fix": 1}
	Career.data.parts = [_part("s1", "p_battery", 2000.0, "BAT-T", 0.4), _part("s2", "p_nav", 4000.0, "NAV-T", 0.25),
		_part("s3", "p_battery", 2100.0, "BAT-T", 0.4), _part("s4", "p_pump", 3000.0, "PUMP-T", 0.5)]
	Career.data.goods = [{"uid": "gq1", "cat": "equip", "nk": "p_generator", "name": "", "value": 9000.0, "ship": "tug", "tag": "GEN-T", "mass": 1.0}]
	Career.data.structure_t = 4.0
	Career.data.money = 30000.0
	Career.data.migrations = [{"id": "128_hall"}]
	Career.data.hall = {"v": 1, "clock": 2400.0, "seq": 0, "listings": [], "orders": [], "rep": 2, "next_order": 2400.0, "sold": [], "bought": [], "done_n": 2}
	Career.save()
	_caption_layer()
	Game.start_ship = "berth"
	Game.contract = {}
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(20)
	g.tutorial = null
	HallMarket.tick(0.1)
	# an order for the battery that will ride the train later
	var os: Array = HallMarket.orders()
	os.push_front({"id": "V1", "client": "北辰船务", "cat": "equip", "kind": "p_battery", "n": 1.0, "lv": 1, "price": 2600.0, "k": 1.3, "at": HallMarket.clock(), "due": HallMarket.clock() + 900.0, "state": "open", "got": 0.0, "held": []})
	HallMarket.data().orders = os
	# taken now: by the last beat its crate is on a train
	HallMarket.take("V1")
	await _frames(20)

	_beat(1, "仓库页直接写出价格阶梯", "回收站 · 交易行约 · 订单　点“交易行”就按建议价一键挂单，按真实时间成交，扣 5% 手续费")
	g.open_store()
	await _secs(0.8)
	var sp = g.console_ui
	sp.select("p:s2")
	await _secs(1.8)
	sp.list_sel()
	await _secs(2.2)
	sp._close()
	await _secs(0.4)

	_beat(2, "懂行的看价格曲线自己定价", "近 30 分钟价格 · 平均线 · ±10% 浮动　要价越高卖得越慢，到账和成交时间实时算")
	g.open_hall("sell", "g:gq1")
	await _secs(0.8)
	var hp = g.console_ui
	hp.custom = false
	await _secs(1.4)
	hp.custom = true
	for i in 40:
		hp.price_k = 1.0 + 0.15 * float(i) / 39.0
		await _secs(1.0 / 30.0)
	await _secs(0.8)

	_beat(3, "买页：别家公司的设备和钢材", "比自己拆的贵；修缮缺料时，交易行开放后就从这里按 1.35 倍市价买")
	hp.set_tab("buy")
	hp.buy_sel = "p_battery"
	await _secs(3.0)

	_beat(4, "订单板：最多 8 张，按信誉给价", "接单后自动从仓库备货　备货 → 火车 → 客户飞船 → 到账　缺货时写清出路")
	hp.set_tab("orders")
	for o2 in HallMarket.orders():
		if str(o2.state) == "open" and HallMarket.have_of(str(o2.cat), str(o2.kind)) < float(o2.n):
			hp.ord_sel = str(o2.id)
			break
	await _secs(1.4)
	_key(KEY_ENTER)
	await _secs(2.4)
	hp.close()
	await _secs(0.3)

	_beat(5, "交付看得见：火车送货，客户货船来取", "主机加速、反推刹车，靠进贸易港驳船口，吊车装舱；倒出、掉头、点火离港")
	var found = null
	# a train with an order's crate aboard (else one with any crate)
	for k in 2:
		for tr in FW.trains:
			for wg in tr.wag:
				if wg is Dictionary and (str(wg.get("order", "")) != "" or k == 1) and found == null:
					found = tr
		if found != null:
			break
		await process_frame
	if found != null:
		g.zoom_override = 1920.0 / (50.0 * Geom.M)
		for k in int(2.5 * FPS):
			g.cam_override = FW.cars(found)[1][0]
			cap_t += 1.0 / FPS
			await process_frame
	var b: Rect2 = PS.box("trade")
	g.cam_override = b.get_center() + Vector2(b.size.x * 0.55, 0.0)
	g.zoom_override = 1920.0 / (b.size.x * 2.2)
	# one freighter at the berth: any other order already there waits its turn
	for x in HallMarket.orders():
		if str(x.state) == "ship" and str(x.id) != "V1":
			x.state = "rail"
			x.rail_at = HallMarket.clock()
	var o := HallMarket.order("V1")
	o.state = "ship"
	o.ship_at = HallMarket.clock() - 4.0
	o.crates = 1
	await _secs(HallMarket.SHIP_IN - 4.0 + 3.0)
	HallMarket.mark_loaded("V1")
	await _secs(HallMarket.SHIP_OUT * 0.55)
	quit()
