extends "res://tests/guide_check.gd"
# The tester's "skip every guide" (F12 workbench): a fresh career comes out with the prologue,
# TS-1, the courses, the first ship and every tour behind it, nothing owed, the berth empty; the
# row is on the title, on site and at the terminal. Own test saves only.
#   godot --path . --headless -s tests/dev_skip_guide_check.gd


func _initialize() -> void:
	Career.path = "user://zp_test_dev_skip_career.json"
	SaveGame.path = "user://zp_test_dev_skip_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.onboard = "on"
	Career.save()
	check(Onboard.active() and Game.ts1_due(), "a fresh career owes the guides")
	DevPanel.skip_guides()
	var d := Career.data
	check(not Onboard.active() and Onboard.stage() == "", "the onboarding is done")
	check(not Game.ts1_due(), "TS-1 is not owed")
	var owed := []
	for id in DevPanel.SHIPS:
		owed += Codex.required(str(id))
	check(owed.is_empty(), "no course is owed for any ship (%s)" % str(owed))
	check(not preload("res://scripts/port_walk.gd").due() and not preload("res://scripts/port_tour.gd").due(), "the port tours are not due")
	check(d.seen.get("first_ship", false) and d.seen.get("starmap_tour", false), "the first ship and the star map tour are seen")
	check(d.get("active", {}).is_empty(), "the prologue's tug no longer waits at the berth")
	check(Tram.found().size() == Tram.stations().size(), "every shuttle stop is known")
	var n: int = d.history.size()
	DevPanel.skip_guides()
	check(Career.data.history.size() == n, "run twice, nothing doubles")
	# the row on every screen
	for where in ["title", "game", "terminal"]:
		var p := DevPanel.new()
		p.where = where
		check(p.rows().any(func(r): return r[1] == "dev_skip_guide"), "the row is on the %s workbench" % where)
		p.free()
	# pressed on site: straight back to the career's berth, no guide running
	Career.data = Career.fresh()
	Career.data.onboard = "on"
	Career.save()
	await _spawn()
	await _frames(10)
	var dev = null
	for c in g.get_children():
		if c is DevPanel:
			dev = c
	check(dev != null, "the workbench is there on site")
	if dev != null:
		var i: int = dev.rows().map(func(r): return r[1]).find("dev_skip_guide")
		dev.run(i + 1)
		await _frames(40)
		var ng = root.get_children().filter(func(x): return x is Game)
		var gg = ng.back() if not ng.is_empty() else null
		check(gg != null and gg.in_berth() and gg.state == "play" and gg.guide_coach() == null and gg.tutorial == null, "pressed on site: back in the empty berth, no guide running")
		check(not Onboard.active() and Career.data.seen.get("port_walk", false), "  with the save marked done")
	print("DEV SKIP GUIDE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
