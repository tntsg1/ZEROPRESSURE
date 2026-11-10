extends "res://tests/seg4_sketch.gd"
# 132 号 情境引导 + 控制台规范: the situation cards come once each, pause the game, put the main line's
# voice, its mark and the first-meeting card out of the way while up (one hint on the screen), give
# them back after; the setting turns them off; "带我去" leads; the book shows them again. The four
# console pages by the new rules (the top line, one orange key on Enter, 730 / 520 px). With
# "-- shots" the screenshots for the report. Own test saves only.
#   tools/run_test.sh tests/guide132_check.gd --fixed-fps 60 -- shots

const GC = preload("res://scripts/guide_cards.gd")
const PS5 = preload("res://scripts/power_supply.gd")
const SHOT := "res://tests/out/guide132_%s.png"
var shots := false


func _initialize() -> void:
	Career.path = "user://zp_test_g132_career.json"
	SaveGame.path = "user://zp_test_g132_save.json"
	SaveGame.allow_test = true
	shots = "shots" in OS.get_cmdline_user_args()
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _snap(name: String) -> void:
	if not shots:
		return
	await _frames(3)
	Cap.save(root, SHOT % name)
	print("  shot ", name)


func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	root.push_input(ev)
	await _frames(6)


# every hint on the screen now: the card, the main line's voice, its mark, the first-meeting card, the top hint line
func _hints() -> Array:
	var out: Array = []
	if GC.showing():
		out.append("card")
	var h = g.hud
	if h.voice != null and is_instance_valid(h.voice) and h.voice.is_visible_in_tree():
		out.append("voice")
	if h.need_mark != null and is_instance_valid(h.need_mark) and h.need_mark.visible and h.need_mark.target != Vector2.INF:
		out.append("mark")
	if g.codex_hud != null and g.codex_hud.visible and g.codex_hud.get("card_c") != null and g.codex_hud.card_c.visible:
		out.append("codex card")
	if h.hint_on():
		out.append("hint")
	return out


func _wait_card(limit := 240) -> bool:
	for i in limit:
		if GC.showing():
			return true
		await _frames(1)
	return false


# the voice the main line keeps in the corner, there before the card and back after it
func _voice_on() -> bool:
	return g.hud.voice != null and is_instance_valid(g.hud.voice) and g.hud.voice.is_visible_in_tree()


func _card_case(id: String, label: String) -> void:
	var before := _voice_on()
	check(await _wait_card(), "%s: the card comes up" % label)
	var c = GC.card
	check(c != null and str(c.id) == id, "%s: it is the %s card (%s)" % [label, id, str(c.id) if c != null else "none"])
	await _frames(20)
	check(paused, "%s: the game is paused under it" % label)
	var hs := _hints()
	check(hs == ["card"], "%s: one hint on the screen (%s)" % [label, str(hs)])
	check(c.lines.size() >= 1 and c.lines.size() <= 3 and str(c.title) != "", "%s: a title and 1–3 lines (%d)" % [label, c.lines.size()])
	await _snap("card_" + id)
	await _key(KEY_ESCAPE)
	await _frames(20)
	check(not GC.showing() and not paused, "%s: Esc closes it and the game goes on" % label)
	if before:
		check(_voice_on(), "%s: the main line's voice is back" % label)


func _run() -> void:
	_career()
	Career.data.port["tug"] = 1
	HallMarket.data().orders = []
	Txt.guide_cards = true
	GC.force_on = true
	GC.reset()
	await _spawn()
	await _frames(30)
	# ---- 1 the stores nearly full: a real moment
	StoreBook._add_raw(Ex.INGOT, 420.0, "TUG-001", "tug")
	check(float(StoreBook.used()) >= 0.8 * StoreBook.cap(), "the stores are 80 %% full (%d / %d)" % [StoreBook.used(), StoreBook.cap()])
	await _card_case("store_full", "stores full")
	check(Career.data.get("main_card", {}).has("cargo"), "the main line's own cargo card is not opened as well")
	# once only: the moment is still there, no second card
	GC._gap = 999.0
	await _frames(120)
	check(not GC.showing() and GC.shown_log.count("store_full") == 1, "the stores card comes once (%s)" % str(GC.shown_log))
	# ---- 2 short of power: the moment made by hand (the figures from the grid as it would be)
	GC.test_due["power_short"] = {"n": 19, "who": "拆船区排第一，先拿满；加工区功率 8%，贸易港功率 0%。", "groups": [["拆船区", 100], ["加工区", 8], ["贸易港", 0]]}
	GC._gap = 999.0
	await _card_case("power_short", "short of power")
	check(GC.title("power_short", {"n": 19}) == "电力不足—功率 19%", "the title says 电力不足—功率 19%%")
	# ---- 3 the first trip: a real moment, "带我去" leads to the set
	GC._gap = 999.0
	PS5.d().gens.tg.trip = true
	check(await _wait_card(), "trip: the card comes up")
	check(GC.card != null and str(GC.card.id) == "first_trip", "trip: it is the trip card")
	await _snap("card_first_trip")
	await _key(KEY_ENTER)
	await _frames(20)
	var leads: Array = g.get_children().filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("guide_lead.gd"))
	check(not GC.showing() and leads.size() == 1, "trip: Enter closes it and puts a way to the set on the screen (%d)" % leads.size())
	PS5.d().gens.tg.trip = false
	for l in leads:
		l.queue_free()
	# ---- 4 a district entered and the drone stopped: a real moment
	GC._gap = 999.0
	g.drone.global_position = PortStructure.box("power").get_center()
	g.drone.linear_velocity = Vector2(400, 0)
	await _frames(30)
	check(not GC.showing(), "zone: not while the drone is moving")
	g.drone.linear_velocity = Vector2.ZERO
	await _card_case("zone_power", "zone")
	# ---- 5 the setting off: no card; on again: the card
	Txt.guide_cards = false
	GC._gap = 999.0
	g.drone.global_position = PortStructure.box("tug").get_center()
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(90)
	check(not GC.showing(), "the setting off: no card in the tug station")
	Txt.guide_cards = true
	check(await _wait_card(), "the setting on again: the card comes")
	await _key(KEY_ESCAPE)
	await _frames(10)
	# ---- 6 the power card has no "带我去" (2026-11-09, owner): Enter only closes it
	GC.test_due.erase("power_short")
	Career.data.guide_seen.erase("power_short")
	GC.test_due["power_short"] = {"n": 19, "who": "", "groups": []}
	GC._gap = 999.0
	check(await _wait_card(), "power again (seen cleared): the card comes")
	await _key(KEY_ENTER)
	await _frames(20)
	check(not GC.showing() and (g.console_ui == null or g.console_ui.get("zone") != "power"), "Enter closes the card and goes nowhere")
	GC.test_due = {}
	# ---- 7 a console the first time: the card comes with the page; the page stays after it
	g.drone.global_position = PortStructure.console_spot("trade")
	g.drone.linear_velocity = Vector2.ZERO
	_put(PortStructure.console_spot("trade") + Vector2(-6.0, 3.0) * Geom.M, 0.9)
	await _frames(20)
	_trade_pier()
	g.open_district("trade")
	check(await _wait_card(60), "the trade console the first time: its card")
	check(GC.card != null and str(GC.card.id) == "console_trade", "it is the trade console's card")
	await _snap("card_console_trade")
	await _key(KEY_ESCAPE)
	await _frames(30)
	var d = g.console_ui
	check(d != null and d.get("trade_box") != null, "the trade console stays open after the card")
	check(_pane_w(d) <= 730.0, "trade console ≤ 730 px (%.0f)" % _pane_w(d))
	check(d.now_line.use and str(d.now_line.text).find("港口有人") >= 0, "top line: 现在用得上 the visitor (%s)" % d.now_line.text)
	check(d.trade_key.is_visible_in_tree() and d.trade_key.get_meta("bfx_primary", false), "one orange key on Enter (%s)" % d.trade_key.text)
	var five: Array = d.find_children("*", "Button", true, false).filter(func(b): return str(b.text).begins_with("小幅还价"))
	check(five.is_empty(), "no row of five haggle keys")
	await _snap("panel_trade")
	var cash0: float = float(Career.data.money)
	await _key(KEY_ENTER)
	await _frames(20)
	check(absf(float(Career.data.money) - cash0) > 1.0, "Enter does the deal (cash %.0f → %.0f)" % [cash0, float(Career.data.money)])
	await _key(KEY_ESCAPE)
	await _frames(30)
	# ---- 8 the exchange's orders
	_orders()
	g.open_hall("orders")
	check(await _wait_card(60), "the exchange the first time: its card")
	await _key(KEY_ESCAPE)
	await _frames(40)
	var hp = g.console_ui
	var nw: Array = hp.now_of()
	check(bool(nw[0]) and str(nw[1]).find("仓库里已经有了") >= 0, "orders top line: 现在用得上 (%s)" % str(nw[1]))
	check(str(hp._cards()[0].id) == "OA" and hp.ord_sel == "OA", "the order that can go now is first and picked")
	await _snap("panel_orders")
	await _key(KEY_ENTER)
	await _frames(10)
	check(str(HallMarket.order("OA").state) != "open", "Enter takes it (%s)" % str(HallMarket.order("OA").state))
	await _key(KEY_ESCAPE)
	await _frames(30)
	# ---- 9 the processing queue
	ProcessLine.queue_ingots(2.0)
	ProcessLine.queue_ingots(4.0)
	ProcessLine.queue_ingots(2.0, {"kind": "sell"}, "small")
	var Gal = preload("res://scripts/process_gallery.gd")
	g.drone.global_position = Gal.term("furnace")
	g.drone.linear_velocity = Vector2.ZERO
	_put(PortStructure.box("process").position + Vector2(20.0, 18.0) * Geom.M, 0.7)
	await _frames(20)
	g.open_queue_panel()
	check(await _wait_card(60), "the queue the first time: its card")
	await _key(KEY_ESCAPE)
	await _frames(40)
	var q = g.console_ui
	check(q._rect().size.x <= 730.0, "queue ≤ 730 px (%.0f)" % q._rect().size.x)
	check(q._btns.has("more") and not q._btns.has("auto"), "the switch is folded under 更多")
	await _snap("panel_queue")
	q._press("more")
	await _frames(10)
	check(q._btns.has("auto"), "更多 opens the switch")
	await _key(KEY_ESCAPE)
	await _frames(10)
	check(g.console_ui != null and not q.more_open, "Esc folds 更多 first")
	await _key(KEY_ESCAPE)
	await _frames(30)
	# ---- 10 the processing console
	Career.data.upgrades["gas_line"] = 1
	Career.data.upgrades["lox_tank"] = 1
	GasLine.receive({"o2": 13.0, "n2": 45.0}, "TUG-001")
	GasLine.data().o2.ind = 420.0
	GasLine.data().lox.kg = 3600.0
	g.open_district("process")
	check(await _wait_card(60), "the gas console the first time: its card")
	await _key(KEY_ESCAPE)
	await _frames(40)
	var pz = g.console_ui
	check(_pane_w(pz) <= 730.0, "gas console ≤ 730 px (%.0f)" % _pane_w(pz))
	check(pz.get("call_box") == null and pz.find_children("*", "Button", true, false).filter(func(b): return str(b.text).begins_with("接下")).is_empty(), "no passing ship's order on the gas console")
	check(pz.now_line.use and pz.next_key.get_meta("bfx_primary", false) and str(pz.now_line.text) == "分离一批气体", "the next step is the one orange key, the top line says it (%s)" % pz.now_line.text)
	await _snap("panel_gas")
	await _key(KEY_ESCAPE)
	await _frames(30)
	# ---- 10b the furnace desk: a 520 px card on the far side of the furnace
	g.drone.global_position = g.industrial_heat.site()
	g.drone.linear_velocity = Vector2.ZERO
	_put(g.industrial_heat.site() + Vector2(4.0, 4.0) * Geom.M, 0.85)
	await _frames(30)
	g.open_heat()
	check(await _wait_card(60), "the furnace desk the first time: its card")
	await _key(KEY_ESCAPE)
	await _frames(40)
	var hd = g.console_ui
	check(hd != null and _pane_w(hd) <= 521.0, "furnace desk: a 520 px card (%.0f)" % (_pane_w(hd) if hd != null else 0.0))
	check(hd != null and hd.main.get_meta("bfx_primary", false) and hd.now_line.text != "", "furnace desk: one orange key, the top line (%s)" % (hd.now_line.text if hd != null else ""))
	await _snap("panel_heat")
	await _key(KEY_ESCAPE)
	await _frames(30)
	# ---- 11 the mill card
	var stk: Dictionary = Career.data.exchange.actors.company.stock
	stk[Mill.FEED] = 2.0
	g.drone.global_position = preload("res://scripts/mill_line.gd").pedestal()
	_put(preload("res://scripts/mill_line.gd").pedestal() + Vector2(2.0, 4.0) * Geom.M, 0.85)
	await _frames(20)
	g.open_mill()
	check(await _wait_card(60), "the mill the first time: its card")
	await _key(KEY_ESCAPE)
	await _frames(40)
	var m = g.console_ui
	check(_pane_w(m) <= 521.0, "mill: a 520 px card (%.0f)" % _pane_w(m))
	check(m.now_line.text != "", "mill: the top line (%s)" % m.now_line.text)
	await _snap("panel_mill")
	await _key(KEY_ESCAPE)
	await _frames(30)
	# ---- 12 the book shows them again
	var pg = CodexPage.open(g, "")
	await _frames(10)
	pg._set_cat(Codex.CATS.size())
	await _frames(10)
	check(pg.rows().size() >= 6, "the book's 讲解 tab lists the cards seen (%d)" % pg.rows().size())
	pg.replay()
	await _frames(20)
	check(GC.showing() and GC.card.replay and str(GC.card.go) == "", "Enter in the book shows the card again (no 带我去)")
	await _snap("book_replay")
	await _key(KEY_ESCAPE)
	await _frames(10)
	check(not GC.showing(), "and Esc closes it")
	pg.close()
	await _frames(10)
	check(GC.shown_log.count("store_full") == 1 and GC.shown_log.count("first_trip") == 1 and GC.shown_log.count("zone_power") == 1, "each card once (%s)" % str(GC.shown_log))
	print("GUIDE132 %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	g.queue_free()
	await _frames(4)
	quit()


func _pane_w(p) -> float:
	var pane := p.get_node_or_null("Pane") as Control
	return pane.size.x if pane != null else 0.0


# two visitors at the pier and the companies' offers
func _trade_pier() -> void:
	var d := TradePeople.vis()
	d.list = []
	for i in 2:
		var v := TradePeople.arrive()
		v.state = "waiting"
		v.want = "buy"
		v.key = Ex.INGOT
		v.qty = 2.0
		v.price = snappedf(TradePeople.Exchange.ref_price(Ex.INGOT) * 1.08, 10.0)
		v.temper = "frank"
	TradePeople.vis().list[1].want = "sell"
	var orgs := TradePeople.orgs()
	for who in orgs:
		orgs[who].rep = 3
		orgs[who].offer = TradePeople._offer_for(who)


func _orders() -> void:
	var c := HallMarket.clock()
	HallMarket.data().orders = [
		{"id": "OA", "client": "恒岳工业", "cat": "raw", "kind": Ex.INGOT, "n": 2.0, "lv": 1, "price": 2600.0, "k": 1.3, "at": c, "due": c + 720.0, "state": "open", "got": 0.0, "held": []},
		{"id": "OB", "client": "天衡物流", "cat": "raw", "kind": "steel_slab:1", "n": 3.0, "lv": 1, "price": 3900.0, "k": 1.3, "at": c, "due": c + 600.0, "state": "open", "got": 0.0, "held": []},
		{"id": "OC", "client": "星港建设", "cat": "raw", "kind": "steel_slab:1", "n": 2.0, "lv": 1, "price": 2600.0, "k": 1.3, "at": c - 300.0, "due": c + 900.0, "state": "rail", "got": 2.0, "held": []}]
