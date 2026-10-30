extends SceneTree
# G2 acceptance (design/G2_破败船坞修缮设计稿_2026-10-21.md): the run-down berth.
#   1  a new career starts with the three base facilities broken; an old career keeps them
#   2  equipment classes: G-01 power, CP-E thermal, ENG-C drive, C-01 nothing
#   3  the bot takes a Heron apart: the classed equipment is shelved, not paid; structure
#      goes on by the tonne; the settlement shows the shelf and the next repair
#   4  repairs: with parts at a quarter of the price (74 号) (the parts leave the shelf), with money at full
#      price, prerequisites hold, a failed write changes nothing, the repair is written
#      into upgrades and queued for the show
#   5  the shelf: a part sold for its worth, sell all
#   6  the loan: credit by level, interest by level, borrowing adds to funds and loan, a
#      settlement takes its installment at the level's rate
#   7  the dropped drone modules are refunded on load
#   8  the repair tasks carry their repair target and the parts for it
# Test files only; the player's career is never touched.
# godot --headless --path . --fixed-fps 60 -s tests/repair_check.gd

const Bot = preload("res://tests/salvage_bot.gd")
const BOT := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "warp": true}
var fails := 0
var checks := 0
var finished := false


func _initialize() -> void:
	Career.path = "user://zp_test_repair_career.json"
	SaveGame.path = "user://zp_test_repair_save.json"
	SaveGame.train_path = "user://zp_test_repair_training.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path, SaveGame.train_path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	_run()


func _process(_dt: float) -> bool:
	return finished


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _game() -> Node:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = BOT.duplicate()
	root.add_child(scene)
	return scene


func _run() -> void:
	print("REPAIR: a new career")
	Career.data = {}
	Career.start_new()
	var d := Career.data
	check(not d.upgrades.has("lights") and not d.upgrades.has("net_fix") and not d.upgrades.has("furnace_main"), "a new career: lighting, net and furnace broken")
	check(d.parts.is_empty() and float(d.structure_t) == 0.0 and Career.credit_limit() == 50000.0 and Career.rate() == 0.03, "empty shelf; trainee credit 50,000 at 3%%")
	# an old career: never had the fields, has worked three jobs, bought two modules
	var old := Career.fresh()
	for k in ["parts", "structure_t", "repairs", "repaired_pending", "berth_v"]:
		old.erase(k)
	old.done = 3
	old.market = true
	old.active = {}
	old.money = 10000.0
	old.gear = {"mod_bumper": 1, "mod_rack": 2, "probe": 1}
	old.loadout = {"mods": ["mod_bumper"], "deploy": {"probe": 1}}
	Career.data = old
	Career.save()
	Career.data = {}
	Career.load_or_new()
	d = Career.data
	check(d.upgrades.has("lights") and d.upgrades.has("net_fix") and d.upgrades.has("furnace_main"), "an old career keeps the base facilities it worked with")
	check(not d.gear.has("mod_bumper") and not d.gear.has("mod_rack") and int(d.gear.probe) == 1 and absf(float(d.money) - (10000.0 + 16000.0 + 40000.0)) < 1.0 and d.loadout.mods.is_empty(), "the dropped modules refunded: funds %d" % int(d.money))
	# ---- back to a fresh career with the market open, for the rest
	Career.data = {}
	Career.start_new()
	d = Career.data
	d.market = true
	d.done = 3
	d.money = 60000.0
	d.story_job = {}
	d.active = {}
	Career.save()
	# ---- 2: classes on a Heron
	var ot := Career.take_trial("g1c")
	check(not ot.is_empty() and ot.repair == "furnace_main" if ot.has("repair") else Career.TRIALS.g1c.repair == "furnace_main", "repair task C targets the furnace main fire")
	Game.start_ship = ot.ship
	Game.contract = Career.active()
	var g = _game()
	await _frames(3)
	var cls := {}
	for tag in ["G-01", "B-01", "CAP-01", "CP-E", "RAD", "ENG-C", "NAV-01", "C-01", "SEAT-P", "TK-B1"]:
		var p = g.world.tag(tag)
		cls[tag] = Repair.class_of(p, g.sys) if p != null else "?"
	check(cls["G-01"] == "power" and cls["B-01"] == "power" and cls["CAP-01"] == "power", "power: generator, battery, capacitor (%s)" % str(cls))
	check(cls["CP-E"] == "thermal" and cls["RAD"] == "" , "thermal: the coolant pump; the radiator is too cheap to shelve (%s / %s)" % [cls["CP-E"], cls["RAD"]])
	check(cls["ENG-C"] == "drive" and cls["NAV-01"] == "drive", "drive: engine, nav computer")
	check(cls["C-01"] == "" and cls["SEAT-P"] == "" and cls["TK-B1"] == "", "cargo, seats and bottles are only money")
	# ---- 3: the bot takes it apart
	var money_before := float(Career.data.money)
	var bot = Bot.new(g)
	while not bot.step():
		await process_frame
	await _frames(5)
	var sum: Dictionary = bot.summary()
	print("  G1C: ", sum)
	check(sum.ended, "the bot finished the Heron")
	var cr: Dictionary = g.career_result
	var pr: Dictionary = cr.get("parts", {})
	d = Career.data
	check(pr.tags.size() >= 5 and "G-01" in pr.tags and "CP-E" in pr.tags and float(pr.value) > 10000.0, "parts shelved: %s worth %d" % [str(pr.tags), int(pr.value)])
	check(float(pr.tons) > 10.0 and float(d.structure_t) == float(pr.tons), "structure by the tonne: %.1f t" % float(pr.tons))
	check(d.parts.size() == pr.tags.size(), "the shelf holds them")
	var expect: float = money_before + float(sum.net) + (float(cr.fee) if cr.prepaid else 0.0) + float(cr.bonus) - float(pr.value) - float(cr.installment) - float(cr.interest) - float(cr.get("tow", 0.0)) - float(cr.get("ingot_value", 0.0))
	check(absf(float(d.money) - expect) < 1.0, "cash = net − parts value − the scrap now ingots (64 号): %d (%d)" % [int(d.money), int(expect)])
	var sg: Dictionary = cr.get("suggest", {})
	check(not sg.is_empty() and sg.has("name"), "the settlement suggests the next repair: %s" % str(sg.get("name", "")))
	var rows: Array = g.hud.career_rows()
	check(rows.any(func(r): return r[0] == "e_parts_in") and rows.any(func(r): return r[0] == "e_next_repair"), "the settlement rows list the shelf and the next repair")
	check(int(d.trials.g1c) == 1, "the task counted")
	g.queue_free()
	await _frames(2)
	# ---- 4: repairs
	var pf := Repair.parts_for("lights")
	check(pf.ok and pf.picked.power.size() == 2, "lighting: two power parts ready on the shelf")
	check(Repair.reason("hauler", true) != "" and Repair.reason("hauler", true).find(Repair.name_of("lights")) >= 0, "the hauler waits on the lighting first")
	var money0 := float(d.money)
	var shelf0: int = d.parts.size()
	var good_path := Career.path
	Career.path = "user://"
	var why := Repair.fix("lights", true)
	Career.path = good_path
	check(why != "" and not Career.data.upgrades.has("lights") and Career.data.parts.size() == shelf0 and float(Career.data.money) == money0, "a repair that cannot be written changes nothing (%s)" % why)
	why = Repair.fix("lights", true)
	d = Career.data
	check(why == "" and d.upgrades.has("lights") and d.parts.size() == shelf0 - 2 and absf(float(d.money) - (money0 - 3500.0)) < 1.0, "lighting repaired with parts: two parts gone, a quarter of the price paid (%d)" % int(d.money))
	check(d.repaired_pending == ["lights"] and d.repairs.size() == 1 and d.repairs[0].with_parts, "queued for the show and logged")
	check(Repair.reason("hauler", true) != Txt.t("tm_needs") % Repair.name_of("lights"), "the hauler no longer waits on the lighting")
	money0 = float(d.money)
	why = Repair.fix("buffer", false)
	d = Career.data
	check(why == "" and d.upgrades.has("buffer") and absf(float(d.money) - (money0 - 30000.0)) < 1.0 and float(d.structure_t) == float(pr.tons), "the buffer with money alone: full price, the structure untouched")
	check(Repair.fix("lights", true) == Txt.t("tm_owned"), "a repaired item cannot be repaired again")
	# ---- 5: the shelf
	var part: Dictionary = d.parts[0]
	var worth := Repair.part_worth(part)
	money0 = float(d.money)
	check(Repair.sell(str(part.uid)) == "" and absf(float(Career.data.money) - (money0 + worth)) < 1.0 and Career.data.parts.size() == shelf0 - 3, "a part sold for %d" % int(worth))
	var rest := 0.0
	for pp in Career.data.parts:
		rest += Repair.part_worth(pp)
	money0 = float(Career.data.money)
	var got := Repair.sell_all()
	check(absf(got - rest) < 1.0 and Career.data.parts.is_empty() and absf(float(Career.data.money) - (money0 + rest)) < 1.0, "sell all: +%d, the shelf empty" % int(got))
	# ---- 6: the loan
	d = Career.data
	d.rep = 0
	check(Career.credit_limit() == 50000.0 and Career.rate() == 0.03, "trainee: 50,000 at 3%%")
	d.rep = 16
	check(Career.credit_limit() == 400000.0 and Career.rate() == 0.015, "senior: 400,000 at 1.5%%")
	d.rep = 0
	money0 = float(d.money)
	var lent := Career.borrow(80000.0)
	check(lent == 50000.0 and absf(float(Career.data.money) - (money0 + 50000.0)) < 1.0 and float(Career.data.loan) == 50000.0 and Career.credit_left() == 0.0, "borrowing is capped at the credit: lent %d" % int(lent))
	check(Career.borrow(1000.0) == 0.0, "nothing more to borrow")
	var due := Career.due_for({"scope": "full"})
	check(absf(due - (20000.0 + 1500.0)) < 1.0, "a full job would take the installment and 3%% interest: %d" % int(due))
	check(Career.repay(50000.0) == 50000.0 and float(Career.data.loan) == 0.0 and Career.credit_left() == 50000.0, "paid back: the credit is free again")
	# ---- 8: the repair tasks
	for id in Career.TRIALS:
		var spec: Dictionary = Career.TRIALS[id]
		check(spec.has("repair") and not Repair.find(str(spec.repair)).is_empty(), "task %s targets %s" % [id, Repair.name_of(str(spec.get("repair", "")))])
	# the Swift carries power parts for the lighting
	var s09 := Ship.load_data("s09")
	var power := 0
	for pd in s09.pieces:
		if pd.get("cls", "") == "equip" and pd.get("tag", "") != "":
			var fake := {"cls": "equip", "intact": true, "tag": pd.tag, "value": float(pd.get("value", 0.0)), "name_key": str(pd.get("name_key", "")), "hazard": str(pd.get("hazard", ""))}
			if float(fake.value) >= Repair.PART_MIN_VALUE and Repair._class_of_data(fake) == "power":
				power += 1
	check(power >= 2, "the Swift carries %d power parts for the lighting" % power)
	check(not Repair.ships_with("power").is_empty(), "ships with power parts: %s" % str(Repair.ships_with("power")))
	print("REPAIR %s  (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	finished = true
