extends "res://tests/guide_check.gd"
# User 2026-10-26: training is the main line's, not a choice. The base course TS-1 comes between
# the prologue's tow home and the first real ship (owed until passed, no skipping it); a ship with
# a mechanism not trained for sends "start stripping" through those special courses first; the
# terminal has no training page. Own test saves only.
#   tools/run_test.sh tests/training_mandatory_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_training_mandatory_career.json"
	SaveGame.path = "user://zp_test_training_mandatory_save.json"
	SaveGame.train_path = "user://zp_test_training_mandatory_training.json"   # never the player's training file
	SaveGame.allow_test = true
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.save()
	# ---- TS-1 before the first ship
	check(Game.ts1_due(), "a new career owes the base course")
	Career.data.cert_kind = "full"
	check(not Game.ts1_due(), "passed: nothing owed")
	Career.data.cert_kind = "prologue"
	Career.data.history = [{"id": "TUG-001"}]
	check(not Game.ts1_due(), "an older career past its first ship is not sent back to it")
	Career.data.history = []
	Game.start_ship = "berth"
	await _spawn()
	await _frames(10)
	# 开局重做 (owner 2026-11-10): the prologue over, the first ship comes first; TS-1 once it is stripped
	check(Game.TS1_AFTER_FIRST, "(the course comes after the first ship)")
	g.finish_prologue()
	await _frames(2)
	check(Game.start_ship != "ts1" and Career.data.get("ts1_after", false) and not Career.data.get("ts1_required", false), "the tow home over: the first ship next, not TS-1 (start ship %s)" % Game.start_ship)
	check(not Game.ts1_due(), "  nothing owed before the first ship")
	Career.data.history = [{"id": "TUG-001"}]
	check(Game.ts1_due() and Game.ts1_after_due(), "TUG-001 stripped: the course is owed now")
	g._to_berth()
	check(Game.start_ship == "ts1" and Career.data.get("ts1_required", false), "  the way back to the berth goes into TS-1 (start ship %s), and it is required" % Game.start_ship)
	# the old order still holds with the switch off (a career begun before keeps its own)
	Game.TS1_AFTER_FIRST = false
	Career.data.erase("ts1_after")
	Career.data.erase("ts1_required")
	Career.data.history = []
	g.finish_prologue()
	check(Game.start_ship == "ts1" and Career.data.get("ts1_required", false), "switch off: the tow home over, TS-1 next (start ship %s), and it is required" % Game.start_ship)
	Game.TS1_AFTER_FIRST = true
	await _frames(2)
	# no skipping it from the pause menu
	g.training = true
	var items: Array = g.hud._menu_items().map(func(it): return str(it[0]))
	check(not items.has("skip"), "the pause menu offers no skip while it is required (%s)" % str(items))
	Career.data.erase("ts1_required")
	g.training = false
	# passing it clears the requirement
	Career.data.ts1_required = true
	Career.data.cert_kind = "full"
	g.after_training("contract")
	await _frames(2)
	check(not Career.data.has("ts1_required"), "passed: the requirement is cleared")
	g.queue_free()
	await _frames(4)
	# ---- special courses are required
	var cls: String = Codex.CLASSES[0]
	var ship: String = Codex.CLASS_SHIPS[cls][0]
	Career.data.erase("codex_certs")
	check(Codex.COURSES_REQUIRED and Codex.required(ship).has(cls), "a ship with an untrained mechanism (%s on %s) requires its course" % [cls, ship])
	Codex.certify(cls)
	check(not Codex.required(ship).has(cls), "trained: no longer required")
	# ---- no training page on the terminal
	var term_script = load("res://scripts/terminal.gd")
	var pages: Array = term_script.APPS.map(func(a): return int(a[0]))
	check(not pages.has(7), "the terminal has no training page (%s)" % str(pages))
	print("TRAINING MANDATORY %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
