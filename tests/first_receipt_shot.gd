extends "res://tests/guide_check.gd"
# 108 号 Q3: the career's first whole machine delivered gets its own receipt, once: the winch of
# TUG-001 into the equipment mouth — its name, its value rolling up, "已入架", the till's sound.
# The second machine gets none. Own test saves only.
#   tools/run_test.sh tests/first_receipt_shot.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_receipt_career.json"
	SaveGame.path = "user://zp_test_receipt_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _receipts() -> Array:
	return g.get_children().filter(func(n): return n.get_script() != null and str(n.get_script().resource_path).ends_with("first_receipt.gd"))


func _deliver(tag: String) -> void:
	var p = g.world.tag(tag)
	for j in g.world.joints_of(p).duplicate():
		g.world.kill_joint(j)
	for l in g.world.lines_of(p).duplicate():
		g.world.kill_line(l)
	g.world.relink()
	await _frames(4)
	p = g.world.tag(tag)
	p.body.set_meta("hauled", true)
	g.on_swallowed(p.body, "equip")
	await _frames(2)


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true}
	Career.data.active = Career.opening(0)
	Career.save()
	Game.start_ship = str(Career.active().ship)
	Game.contract = Career.active()
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(20)
	var money0 := float(Career.data.money)
	await _deliver("WINCH-T")
	var rs := _receipts()
	check(rs.size() == 1 and Career.data.seen.has("first_receipt"), "the first whole machine in: a receipt")
	check(g.feed.is_empty() and g.fx.numbers.is_empty(), "the first receipt is the only per-item amount on screen")
	if rs.size() == 1:
		var r = rs[0]
		check(str(r.item).contains("WINCH-T") and float(r.value) > 1000.0, "it names the winch and what was paid (%s, %s)" % [r.item, Pal.money(float(r.value))])
		check(absf(float(Career.data.money) - money0 - float(r.value)) < 1.0, "108 号 b: bought on the spot, the cash is in the account now (%s → %s)" % [Pal.money(money0), Pal.money(float(Career.data.money))])
		check(not g.parts_in.any(func(p): return str(p.tag) == "WINCH-T") and absf(float(g.spot_paid) - float(r.value)) < 1.0, "bought, not on the rack; the job remembers what it paid")
		# the settlement takes it off: the winch is not paid twice
		var rep: Dictionary = g.settle_report()
		var before := float(Career.data.money)
		var gross := float(rep.earned) - float(rep.losses) + float(rep.bonus)
		var res: Dictionary = Career.settle(rep)
		check(absf(float(res.get("spot_paid", 0.0)) - float(r.value)) < 1.0, "the settlement lists the spot payment (%s)" % Pal.money(float(res.get("spot_paid", 0.0))))
		check(float(res.money) - before <= gross - float(r.value) + 1.0, "and does not pay it again (+%s on %s earned)" % [Pal.money(float(res.money) - before), Pal.money(gross)])
	await _frames(110)
	Cap.save(root, "res://tests/out/first_receipt_zh.png")
	await _frames(300)
	check(_receipts().is_empty(), "it goes by itself")
	await _deliver("NAV-T")
	check(_receipts().is_empty(), "the second machine: no receipt")
	check(g.feed.is_empty() and g.fx.numbers.size() == 1, "later equipment shows one price beside the receiver")
	print("FIRST RECEIPT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
