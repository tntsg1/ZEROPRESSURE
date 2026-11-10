extends "res://tests/guide_check.gd"
# 133 号: the hulk market reads as ships someone is selling. Every card has its seller, its time
# up and left, who is looking, the tow and its price against value; the same listing gives the
# same seller every time; the window sets the seller's word against the checks and says how to
# buy. Shots of the page and a window (zh), and the page in English. Own test saves only.
#   tools/run_test.sh tests/ship_market_face_shot.gd --fixed-fps 60

const Face := preload("res://scripts/listing_face.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_ship_market_face_career.json"
	SaveGame.path = "user://zp_test_ship_market_face_save.json"
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
	Career.data.money = 900000.0
	Career.data.port = {"salvage": 1, "trade": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"starmap_tour": true}
	Career.data.offers = []
	Career.save()
	await _spawn()
	await _frames(60)
	ShipMarket.refresh()
	# age the listings a little so the clocks and the watchers read like a market that has run
	for l in ShipMarket.data().listings:
		var life := float(l.expires) - float(l.listed)
		l.listed = float(l.listed) - life * randf_range(0.1, 0.8)
		l.expires = float(l.listed) + life
	g.open_ship_market()
	await _frames(70)
	var ui = g.console_ui
	var ls: Array = ShipMarket.data().listings
	var same := true
	var kinds := {}
	for l in ls:
		var a: Dictionary = Face.seller(l)
		var b: Dictionary = Face.seller(l)
		same = same and str(a.name) == str(b.name) and str(a.line) == str(b.line) and Face.interest(l) == Face.interest(l)
		kinds[str(a.kind)] = true
	check(same, "a listing's seller and watchers are the same every time")
	check(kinds.size() >= 3, "sellers of several kinds on one page (%s)" % str(kinds.keys()))
	var texts: Array = ui.find_children("*", "Label", true, false).map(func(x): return str(x.text))
	check(texts.any(func(t): return t.begins_with("在售 · 已上架")), "cards say they are on sale and how long")
	check(texts.any(func(t): return t.contains("距离下架还有")), "cards say how long they have left")
	check(texts.any(func(t): return t.contains("人正在关注")), "cards say who is looking")
	check(texts.any(func(t): return t.begins_with("低于估价")), "cards set the price against value")
	Cap.save(root, "res://tests/out/ship_market_133_list_zh.png")
	# a window: a listing whose word clashes with its rating if there is one, structure checked
	var pick: Dictionary = ls[0]
	var best := -1
	for l in ls:
		if not ShipMarket.fits(l):
			continue
		var sc := (2 if Face.clash(l) else 0) + (1 if l.offer.get("traps", []).any(func(t): return ShipMarket.category(t) == "structure") else 0)
		if sc > best:
			best = sc
			pick = l
	ShipMarket.inspect(str(pick.id), "structure")
	ui.chosen = str(pick.id)
	ui._detail()
	await _frames(6)
	var wt: Array = ui.detail_win.find_children("*", "Label", true, false).map(func(x): return str(x.text))
	check(wt.has("卖家描述") and wt.has("检验结果") and wt.has("怎么买"), "the window sets the seller's word against the checks and says how to buy")
	check(wt.has(str(Face.seller(pick).name)), "the window names the seller")
	var buy := false
	for b in ui.detail_win.find_children("*", "Button", true, false):
		buy = buy or str(b.text).begins_with("买下并拖回")
	check(buy, "the buy is still there")
	Cap.save(root, "res://tests/out/ship_market_133_detail_zh.png")
	ui.detail_win.visible = false
	# English
	Txt.zh = false
	ui._fill()
	await _frames(40)
	var en: Array = ui.find_children("*", "Label", true, false).filter(func(x): return not ui.detail_win.is_ancestor_of(x)).map(func(x): return str(x.text))
	check(en.any(func(t): return t.begins_with("FOR SALE · LISTED FOR")) and not en.any(func(t): return t.contains("距离下架")), "the English page is English")
	Cap.save(root, "res://tests/out/ship_market_133_list_en.png")
	ui._detail()
	await _frames(6)
	Cap.save(root, "res://tests/out/ship_market_133_detail_en.png")
	Txt.zh = true
	ui.close()
	g.queue_free()
	await _frames(4)
	print("SHIP MARKET FACE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
