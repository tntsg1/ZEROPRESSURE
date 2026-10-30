extends "res://tests/guide_check.gd"
# User 2026-10-26: training is the main line's, not a choice. The base course TS-1 comes between
# the prologue's tow home and the first real ship (owed until passed, no skipping it); a ship with
# a mechanism not trained for sends "start stripping" through those special courses first; the
# terminal has no training page. Own test saves only.
#   tools/run_test.sh tests/training_mandatory_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_training_mandatory_career.json"
	SaveGame.path = "user://zp_test_training_mandatory_save.json"
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
	# the prologue over: straight into TS-1, marked as required
	Game.start_ship = "berth"
	await _spawn()
	await _frames(10)
	g.finish_prologue()
	await _frames(2)
	check(Game.start_ship == "ts1" and Career.data.get("ts1_required", false), "the tow home over: TS-1 next (start ship %s), and it is required" % Game.start_ship)
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
