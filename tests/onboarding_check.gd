extends "res://tests/guide_check.gd"
# 80 号: the new player's first half hour as one guide. The stage comes from the save's real
# state; the terminal keeps shut what the stage doesn't use and says why; the star map's find
# page always says the next step and the first time it opens shows its parts one by one; an
# older save (no onboard key) gets nothing locked; a TUG-001 job loaded part-way gets its guide
# back at the step it is at. Own test saves only.
#   tools/run_test.sh tests/onboarding_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_onboarding_career.json"
	SaveGame.path = "user://zp_test_onboarding_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _career(stage_to: String) -> void:
	Career.data = Career.fresh()
	Career.data.onboard = "on"
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true}
	if stage_to in ["find", "lights", "done"]:
		Career.data.history = [{"id": "TUG-001", "ship": "tug", "net": 9000.0}]
	if stage_to in ["lights", "done"]:
		Career.data.seen["first_tow"] = true
	if stage_to == "done":
		Career.data.upgrades["lights"] = true
	Career.save()


func _run() -> void:
	Txt.zh = true
	# ---- stages from the save's state
	Career.data = Career.fresh()
	Career.data.onboard = "on"
	check(Onboard.stage() == "prologue", "a new career starts in the prologue stage")
	Career.data.prologue_done = true
	check(Onboard.stage() == "ship1", "prologue done: the first ship")
	_career("find")
	check(Onboard.stage() == "find", "TUG-001 stripped: find the second hulk")
	check(Onboard.locks(1) and Onboard.locks(5) and Onboard.locks(7) and not Onboard.locks(0), "find: only 找船 is open")
	check(Onboard.lock_reason().contains("找船"), "and the lock says why: %s" % Onboard.lock_reason())
	check(Mainline.step().text.contains("找第二艘船") and Mainline.step().text.contains("免费"), "the main-line card says the next step: %s" % Mainline.step().text)
	_career("lights")
	check(Onboard.stage() == "lights" and not Onboard.locks(0) and not Onboard.locks(1) and Onboard.locks(5), "the tug sent: mend the lights (找船 and 装备 open)")
	check(Mainline.step().text.contains("照明坏了"), "the card says why the lights: %s" % Mainline.step().text)
	Career.data.history.append({"id": "F-2", "ship": "tug"})
	check(Onboard.stage() == "", "never a dead end: with the second hulk stripped the lock lifts anyway")
	_career("done")
	Mainline.step()
	check(str(Career.data.onboard) == "done" and not Onboard.active() and not Onboard.locks(5), "the lights under way: the guide is over and kept so in the save")
	# ---- an older save: nothing locked
	_career("find")
	Career.data.erase("onboard")
	check(Onboard.stage() == "" and not Onboard.locks(1), "an older save (no onboard key) gets nothing locked")
	# ---- the terminal in the find stage
	_career("find")
	Career.data.money = 0.0
	Career.save()
	Scan.ON = true
	await _spawn()
	await _frames(20)
	g.open_console("terminal")
	await _frames(8)
	var term = g.console_ui
	term._skip_boot()
	await _frames(20)
	check(term._locked(1) and term._locked(5) and not term._locked(0) and term._lock_reason(1).contains("找船"), "the terminal's 装备 and 成长 tiles are locked, 找船 open: %s" % term._lock_reason(1))
	Cap.save(root, "res://tests/out/onboarding_terminal_zh.png")
	term.close()
	await _frames(6)
	# ---- the star map: the tour, then the next step line as the sweep goes on
	g.open_star_map("find")
	await _frames(10)
	var sm = g.console_ui
	check(sm.tour_on() and sm._tour_i == 0, "the first time the find page opens, its parts are shown one by one")
	Cap.save(root, "res://tests/out/onboarding_tour1_zh.png")
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	sm._input(space)
	await _frames(4)
	check(sm._tour_i == 1, "space: the next part (%s)" % str(sm._tour_steps()[1][1]))
	check(Career.guide_at("find_tour") == 1, "the save keeps the part reached (a quit goes on from it)")
	Cap.save(root, "res://tests/out/onboarding_tour2_zh.png")
	for i in 6:
		sm._input(space)
	await _frames(4)
	check(not sm.tour_on() and Career.data.seen.get("starmap_tour", false), "after the last part the tour ends and is not shown again")
	check(sm.next_line().contains("扫描"), "the next step: sweep (%s)" % sm.next_line())
	var near: int = Scan.order()[0]
	sm.sel_sector = near
	Scan.sweep(near)
	check(sm.next_line().contains("等一下"), "sweeping: wait (%s)" % sm.next_line())
	Scan.advance(Scan.SWEEP_S + 1.0)
	check(sm.next_line().contains("分析"), "swept: pick a signal and analyse it (%s)" % sm.next_line())
	var ship_sig := ""
	for s in Scan.signals(near):
		if str(s.get("kind", "")) == "ship" and ship_sig == "":
			ship_sig = str(s.id)
	Scan.analyze(ship_sig)
	Scan.advance(Scan.ANALYZE_S + 1.0)
	sm._sig_key = ""
	sm._fill()
	await _frames(6)
	check(sm.next_line().contains("派拖船去拖") and sm.next_line().contains("免费"), "a hulk found: send the tug, the first on Liang (%s)" % sm.next_line())
	Cap.save(root, "res://tests/out/onboarding_found_zh.png")
	sm._send(Scan.found()[0])
	await _frames(4)
	check(Onboard.stage() == "lights" and float(Career.data.get("tow_owed", 0.0)) == 0.0 and ShipMarket.on_the_way().size() == 1, "sent free (nothing owed): on to the lights")
	check(sm.next_line().contains("拖船在路上"), "the tug out: when it comes and what then (%s)" % sm.next_line())
	sm.close()
	await _frames(4)
	# user 2026-10-26: "拖了半天了也没进度" — the calendar waited for the exchange to be opened once;
	# a new career that never opened it had its tug flying for ever
	Career.data.erase("exchange")
	var left0 := float(ShipMarket.on_the_way()[0].left_s)
	for k in int(left0) + 20:
		g.freight_pier._physics_process(1.0)
	var home := false
	for a in ShipMarket.data().assets:
		if str(a.state) in ["arrived", "berth"]:
			home = true
	check(ShipMarket.on_the_way().is_empty() and home, "the exchange never opened: the tug still comes home (%d s)" % int(left0))
	# user 2026-10-26: "它到了，那我应该怎么去接它？" — announced on the spot, the terminal opens on its card
	var arr: Dictionary = g.arrival.duplicate()
	check(not arr.is_empty() and str(arr.get("name", "")) != "", "it is announced on screen: %s" % str(arr))
	await _frames(20)
	Cap.save(root, "res://tests/out/onboarding_arrival_zh.png")
	g.open_console("terminal")
	await _frames(8)
	var t2 = g.console_ui
	t2._skip_boot()
	await _frames(10)
	check(t2.tab == 0 and str(t2.offers()[t2.sel].get("id", "")) == str(arr.get("id", "")) and g.arrival.is_empty(), "the terminal opens under Find ships with its card selected")
	Cap.save(root, "res://tests/out/onboarding_arrival_terminal_zh.png")
	t2.close()
	await _frames(6)
	g.queue_free()
	await _frames(4)
	print("ONBOARDING %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
