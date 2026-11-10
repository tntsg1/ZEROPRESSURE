extends "res://tests/guide_check.gd"
# 45 号: the hulk market in the Delta Force layout. One card per listing with the ship's own side
# view; the size filter; a card opens the window, its inspections and its buy; my ships as cards
# with resale. Shots. Own test saves only.
#   tools/run_test.sh tests/ship_market_ui_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_ship_market_ui_career.json"
	SaveGame.path = "user://zp_test_ship_market_ui_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _cards(ui) -> Array:
	return ui.find_children("*", "ShipThumb", true, false).filter(func(c): return c.is_visible_in_tree() and not ui.detail_win.is_ancestor_of(c))


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 5000000.0
	Career.data.port = {"salvage": 1, "trade": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"starmap_tour": true}
	Career.data.offers = []
	Career.save()
	await _spawn()
	await _frames(90)
	g.open_star_map("find")
	await _frames(8)
	var nav = g.console_ui
	var market: Button
	for b in nav.tab_find.get_parent().get_children():
		if b is Button and b.text == "二手船市":
			market = b
	check(market != null and not market.disabled and market.get_parent() == nav.tab_ships.get_parent(), "the star map's market is beside Find and Shipping")
	if market == null:
		quit(1)
		return
	Cap.save(root, "res://tests/out/star_map_market_entry_zh.png")
	market.pressed.emit()
	await _frames(8)
	var ui = g.console_ui
	var n: int = ShipMarket.data().listings.size()
	# 133 号: the fifteen kept listings and the endless feed; only the cards on screen are built
	var kept_in: bool = ShipMarket.data().listings.all(func(l): return ui._items.any(func(e): return str(e.id) == str(l.id)))
	check(ui != null and n == 15 and kept_in and ui._items.size() > 15 and _cards(ui).size() >= 6 and _cards(ui).size() <= 30, "the market opens with its fifteen kept listings among %d, %d cards built" % [ui._items.size(), _cards(ui).size()])
	var outlined := true
	for c in _cards(ui):
		outlined = outlined and not ShipThumb.shape_of(c.offer).outline.is_empty()
	check(outlined, "every picture is the ship's own outline")
	Cap.save(root, "res://tests/out/ship_market_cards_zh.png")
	ui._cat("small")
	await _frames(3)
	var small := 0
	for l in ShipMarket.data().listings:
		if ui.length_of(l) <= 40.0:
			small += 1
	var small_in: int = ui._items.filter(func(e): return not e.has("m")).size()
	check(small_in == small and ui._items.all(func(e): return float(Market.type_of(str(e.ship)).get("length", 99.0)) <= 40.0), "the small filter shows the small ones (%d kept, %d in all)" % [small, ui._items.size()])
	ui._cat("all")
	await _frames(3)
	var pick: Dictionary = {}
	for l in ShipMarket.data().listings:
		if ShipMarket.fits(l):
			pick = l
			break
	ui.chosen = str(pick.id)
	ui._detail()
	await _frames(4)
	check(ui.detail_win.visible and ui.dimmer.visible, "a card opens its window over a darkened page")
	for b in ui.detail_win.find_children("*", "Button", true, false):
		if str(b.text).begins_with("结构检验"):
			b.pressed.emit()
			break
	await _frames(3)
	check(ShipMarket.listing(str(pick.id)).inspected.has("structure"), "the structure check from the window")
	Cap.save(root, "res://tests/out/ship_market_detail_zh.png")
	var bought := false
	for b in ui.detail_win.find_children("*", "Button", true, false):
		if str(b.text).begins_with("买下并拖回") and not b.disabled:
			b.pressed.emit()
			bought = true
			break
	await _frames(3)
	check(bought and not ShipMarket.asset(str(pick.id)).is_empty() and not ui.detail_win.visible, "bought from the window")
	ui._cat("mine")
	await _frames(4)
	var resale := false
	for b in ui.find_children("*", "Button", true, false):
		if str(b.text) == "挂牌转售":
			resale = true
	check(resale and _cards(ui).size() == 1, "my ships: its card, with resale")
	Cap.save(root, "res://tests/out/ship_market_mine_zh.png")
	# 121 号: a hulk too long for the berth says so on its button, and a press says why, buys nothing
	ui._cat("all")
	await _frames(3)
	var big: Dictionary = {}
	for l in ShipMarket.data().listings:
		if not ShipMarket.fits(l):
			big = l
			break
	if big.is_empty():
		var l2: Dictionary = ShipMarket.data().listings[0]
		l2.offer.ship = "ark01" if Market.type_of("ark01").size() > 0 else str(l2.offer.ship)
		big = l2
	check(not ShipMarket.fits(big), "a listing too long for the berth (%s)" % str(big.offer.ship))
	ui.chosen = str(big.id)
	ui._detail()
	await _frames(4)
	var said := false
	for b in ui.detail_win.find_children("*", "Button", true, false):
		if str(b.text) == "空间不够大，无法购买":
			check(not b.disabled, "the button says it, and can be pressed")
			b.pressed.emit()
			said = true
			break
	await _frames(3)
	var note_ok := false
	for lb in ui.detail_win.find_children("*", "Label", true, false):
		if lb.visible and str(lb.text).contains("船坞最长只放得下"):
			note_ok = true
	check(said and note_ok and ShipMarket.asset(str(big.id)).is_empty() and ui.detail_win.visible, "pressed: why under the button, nothing bought, the window stays")
	Cap.save(root, "res://tests/out/ship_market_noroom_zh.png")
	ui.close()
	g.queue_free()
	await _frames(4)
	print("SHIP MARKET UI %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
