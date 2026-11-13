extends SceneTree
# 104 号 (user 2026-10-28): growth is new dismantling methods. Learned by a borrow job or an
# achievement (the facilities by building them), tiers bought with money, the old volumes'
# numbers inside the tiers, a career from before keeps what it owns. Own test files only.
#   godot --headless --path . --fixed-fps 60 -s tests/methods_check.gd
var fails := 0
var finished := false


func _initialize() -> void:
	_run()


func _process(_dt: float) -> bool:
	return finished


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Txt.zh = true
	Career.path = "user://zp_test_methods_career.json"
	SaveGame.path = "user://zp_test_methods_save.json"
	SaveGame.allow_test = true

	# ---- a new career: nothing learned, the order, the wait, the tools locked
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.money = 1000000.0
	check(Methods.ORDER.all(func(id): return not Methods.learned(id)) and Methods.next_id() == "section", "new career: nothing learned, next is %s" % Methods.next_id())
	check(Gear.locked_by("anchor") == "section" and Gear.reason("anchor").contains("整段拖走"), "the anchor can't be bought before its method: %s" % Gear.reason("anchor"))
	Career.data.done = 1
	check(Methods.borrow_reason("pump").contains("4 单"), "a borrow job waits for its turn: %s" % Methods.borrow_reason("pump"))
	check(Methods.borrow_reason("auto").contains("施工队"), "a facility method is built, not borrowed: %s" % Methods.borrow_reason("auto"))

	# ---- the rigging order teaches whole sections; the anchor is not granted twice
	var learned: Array = Methods.settle({"id": "G4-RIGGING-0001", "ship": "gr7"}, {}, 2, [], {"id": "rigging", "completed": true})
	check(learned == ["section"] and Methods.level("section") == 1 and int(Career.data.gear.get("anchor", 0)) == 0, "rigging done: whole sections learned (%s), the order gives the anchor itself" % str(learned))
	check(Gear.locked_by("anchor") == "" and Methods.next_id() == "pump", "the anchor can be bought; next is %s" % Methods.next_id())

	# ---- the pump's borrow job: open at 5 done, lends the pump, no fee; finished, learned
	Career.data.done = 5
	check(Methods.borrow_reason("pump") == "", "pump's borrow job open at 5 jobs (%s)" % Methods.borrow_reason("pump"))
	var o := Methods.borrow_offer("pump")
	check(not o.is_empty() and o.ship == "gr7" and float(o.fee) == 0.0 and o.lend == {"pump": 1} and o.borrow == "pump", "the offer: %s, fee %s, lends %s" % [o.get("ship", ""), str(o.get("fee", -1)), str(o.get("lend", {}))])
	check(Methods.take("pump") == "" and Career.active().get("borrow", "") == "pump", "taken: the contract in hand is the borrow job")
	learned = Methods.settle(Career.active(), {"incidents": [{"x": 1}]}, 1, [], {})
	check(learned == ["pump"] and int(Career.data.gear.get("pump", 0)) == 1, "passed: pumping learned, one pump on the shelf (%s)" % str(learned))
	Career.data.active = {}
	var failed: Array = Methods.settle({"borrow": "field", "ship": "m14"}, {"incidents": [1]}, 0, [], {})
	check(failed.is_empty() and not Methods.learned("field"), "a failed borrow job teaches nothing")

	# ---- tiers: money, the kit numbers
	var money0 := float(Career.data.money)
	check(Methods.buy("pump") == "" and Methods.level("pump") == 2 and is_equal_approx(float(Career.data.money), money0 - 22000.0), "pump tier II bought for $22,000")
	var k: Dictionary = Methods.kit()
	check(int(k.get("skill_pump_rate", 0)) == 1 and int(k.get("skill_hose_range", 0)) == 1 and is_equal_approx(Growth.value(k, "pump_rate"), 2.0), "tier II: pumps 2×, hose 5.5 m (%s)" % str(k))
	Career.data.money = 0.0
	check(Methods.buy("pump").contains("还差"), "short of money: refused (%s)" % Methods.buy("pump"))
	Career.data.money = 1000000.0

	# ---- 128 号 第 7 段: the furnace-count achievement is gone; the field grapple comes from its borrow job
	learned = Methods.settle({"ship": "tug"}, {}, 1, ["field"], {})
	check(learned.is_empty() and not Methods.learned("field"), "100 pieces into the furnace no longer teach the field grapple (%s)" % str(learned))
	learned = Methods.settle({"ship": "m14", "borrow": "field"}, {}, 1, [], {})
	check(learned == ["field"] and is_equal_approx(Growth.value(Methods.kit(), "grapple_multi"), 4.0), "its borrow job passed: field grapple learned, 4 at once")
	Methods.buy("field")
	k = Methods.kit()
	check(is_equal_approx(Growth.value(k, "grapple_multi"), 7.0) and is_equal_approx(Growth.value(k, "grapple_mass"), 5.0), "field tier II: 7 at once, single grab 5 t")

	# ---- facilities: the hauler learns machines feeding the mouths, more of them are its tiers
	var up: Dictionary = Career.data.upgrades
	up.hauler = 1
	check(Methods.level("auto") == 1 and Methods.buy_reason("auto").contains("施工队"), "hauler built: machines feed the mouths; the next tier is a build (%s)" % Methods.buy_reason("auto"))
	up.hauler2 = 1
	check(Methods.level("auto") == 2 and int(Methods.kit().get("skill_wrench_multi", 0)) == 1, "second hauler: tier II, a wrench pass takes 2")
	up.crane = 1
	check(Methods.level("crane") == 1 and Methods.crane_t() == 12.0, "crane built: lift it whole, 12 t")
	Methods.buy("crane")
	check(Methods.crane_t() == 16.0, "crane tier II: 16 t")

	# ---- the props method is gone (2026-11-12): eight methods; an old career's prop entries dropped on loading
	check(Methods.ORDER.size() == 8 and not Methods.ORDER.has("prop") and Methods.OPEN_AT.size() == Methods.ORDER.size(), "eight methods, the props one gone, each with its opening")
	check(not Methods.learn("prop", true) and Methods.level("prop") == 0 and Methods.name_of("prop") == "prop", "learning the removed method does nothing")
	var old_m: Dictionary = Career.data.get("methods", {}).duplicate()
	Career.data.methods["prop"] = 2
	Career.data["borrows"] = {"prop": 1, "pump": 1}
	Career.data["gear"] = {"prop": 2, "anchor": 1}
	Career.data["feats"] = {"propped": {"ship": "cf90"}, "watch": {"ship": "fr26"}}
	Methods.drop_removed()
	check(not Career.data.methods.has("prop") and Career.data.borrows == {"pump": 1} and Career.data.gear == {"anchor": 1} and Career.data.feats.keys() == ["watch"], "an old save's props dropped, the rest kept")
	check(Career.data.methods.size() == old_m.size(), "the methods it had are all still there")
	Methods.buy("section")
	check(Methods.winch_k() == 1.5, "sections tier II: winch 1.5×")

	# ---- the cutter needs a plan; the second strip of a type teaches it
	Career.data.done = 20
	check(Methods.borrow_reason("cutter").contains("方案"), "no plan yet: %s" % Methods.borrow_reason("cutter"))
	learned = Methods.settle({"ship": "s09", "borrow": "x"}, {}, 1, [], {})
	learned = Methods.settle({"ship": "s09"}, {}, 1, [], {})
	check(learned.is_empty(), "a borrow job does not count toward stripping a type twice")
	learned = Methods.settle({"ship": "s09"}, {}, 1, [], {})
	check(learned.has("cutter") and int(Methods.kit().get("cutter", 0)) == 1, "the same type a second time: the cutter learned (%s)" % str(learned))

	# ---- precision inspection: $500k delivered whole over all jobs
	Methods.settle({"ship": "gr7"}, {"gear": {"equip_v": 300000.0}}, 1, [], {})
	check(not Methods.learned("precise"), "$300k delivered: not yet")
	learned = Methods.settle({"ship": "gr7"}, {"gear": {"equip_v": 250000.0}}, 1, [], {})
	check(learned.has("precise") and Methods.kit().has("scan_kit"), "$550k: precision inspection learned, the inspection kit with it")

	# ---- a career from before: what it owns is learned (user Q5 A)
	var old := Career.fresh()
	old.erase("methods")
	old.erase("methods_v")
	old.gear = {"anchor": 1, "probe": 2}
	old.upgrades = {"scan_kit": 1, "pump2": 1}
	old.plans = {"gr7": [{"a": 1}]}
	Career.data = old
	Career.save()
	Career.data = {}
	Career.load_or_new()
	var m: Dictionary = Career.data.get("methods", {})
	check(Methods.learned("section") and Methods.level("pump") == 2 and Methods.learned("probe") and Methods.learned("precise") and Methods.learned("cutter") and not Methods.learned("field"),
		"an old career: owned anchor/probe/scan kit/pump II/plans are learned (%s)" % str(m))
	Career.data.methods = {}
	Career.save()
	Career.data = {}
	Career.load_or_new()
	check(Career.data.get("methods", {}).is_empty(), "a career past the migration is not migrated again")

	# ---- on the berth: the field grapple's level reaches the drone; the plan wants the cutter
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.money = 100000.0
	Career.data.done = 8
	Career.data.methods = {"section": 1, "pump": 1}
	Career.data.upgrades = {"berth88": 1}
	Career.save()
	check(Methods.borrow_reason("field") == "" and Methods.ship_for("field") == "m14", "field grapple's borrow job on %s" % Methods.ship_for("field"))
	Methods.take("field")
	Game.contract = Career.active()
	Game.start_ship = str(Game.contract.ship)
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(3)
	check(g.career() and is_equal_approx(g.skill_value("grapple_multi"), 4.0), "on the borrow job the field grapple is fitted: %s at once" % str(g.skill_value("grapple_multi")))
	check(Methods.useful(g).has("field") and Methods.useful_text(g).contains("范围抓钩"), "the card names it: %s" % Methods.useful_text(g))
	g.queue_free()
	await _frames(2)
	print("METHODS %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
