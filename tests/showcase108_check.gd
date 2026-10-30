extends "res://tests/guide_check.gd"
# 108 号 Q14/Q6: a method learned puts a ship laid out for it on the ship market, marked
# "试试新拆法", once, staying until bought; its settlement says what the method did against the
# same type stripped before, or the job's own standard time and value. Own test saves only.
#   tools/run_test.sh tests/showcase108_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_showcase108_career.json"
	SaveGame.path = "user://zp_test_showcase108_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _shows() -> Array:
	return ShipMarket.data().listings.filter(func(l): return l.has("showcase"))


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.port = {"trade": 1, "tug": 2}
	Career.data.money = 200000.0
	Career.data.story_job = {}
	Career.data.active = {}
	Career.save()
	ShipMarket.refresh()
	check(_shows().is_empty(), "nothing learned: no showcase")
	Career.data.methods = {"pump": 1}
	ShipMarket.refresh()
	var sh := _shows()
	check(sh.size() == 1 and str(sh[0].showcase) == "pump" and str(sh[0].offer.ship) == "gr7", "抽气液 learned: a GR-7 laid out for it is listed (%s)" % (str(sh[0].offer.ship) if not sh.is_empty() else "-"))
	if sh.is_empty():
		quit(1)
		return
	var l: Dictionary = sh[0]
	check(float(l.expires) > Shipping.day() + 1.0e6 and str(Career.data.showcases.get("pump", "")) == "listed", "it stays until bought; the career marks it listed")
	check(float(l.price) > 0.0 and float(l.price) < float(l.offer.value), "a fair price under its value (%s of %s)" % [Pal.money(float(l.price)), Pal.money(float(l.offer.value))])
	ShipMarket.refresh()
	check(_shows().size() == 1, "listed once")
	# the card says so
	var panel = preload("res://scripts/ship_market_panel.gd").new()
	root.add_child(panel)
	await _frames(4)
	var card: Button = panel._listing_card(l)
	var texts := card.find_children("*", "Label", true, false).map(func(x): return str(x.text))
	check(texts.any(func(t): return t.contains("试试新拆法") and t.contains(Methods.name_of("pump"))), "its card is marked 试试新拆法 · %s" % Methods.name_of("pump"))
	panel.queue_free()
	# the settlement of the job: what the pumps did, against GR-7 last time
	Career.data.history = [{"id": "GR-OLD", "ship": "gr7", "net": 30000.0, "time": 1500.0}]
	var a: Dictionary = l.offer.duplicate(true)
	a.id = "SC-1"
	Career.data.active = a
	var res: Dictionary = Career.settle({"earned": 52000.0, "losses": 0.0, "bonus": 0.0, "time": 1100.0, "grade": 2, "rate": 0.9, "uses": {"pump": 2}})
	var sc: Dictionary = res.get("showcase", {})
	check(str(sc.get("id", "")) == "pump" and str(sc.get("use", "")).contains("2 台"), "the settlement says what the method did (%s)" % str(sc.get("use", "")))
	check(sc.has("before") and is_equal_approx(float(sc.before.time), 1500.0), "against GR-7 stripped before: %s" % str(sc.get("before", {})))
	check(str(Career.data.showcases.get("pump", "")) == "done", "the showcase is done")
	print("SHOWCASE108 %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
