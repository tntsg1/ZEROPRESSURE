extends "res://tests/guide_check.gd"
# 107 号 Q5/Q6: the star map's find page — the next step and its button on top, the sectors folded to
# one line, a hulk found is its own tug button on its signal row, a hulk towed says so on its row,
# the inset keeps off the picked sector, the names on the chart placed apart. Own test saves only.
#   tools/run_test.sh tests/starmap107_shot.gd --fixed-fps 60 -- tag=v1
var tag := "v1"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
	Career.path = "user://zp_test_starmap107_career.json"
	SaveGame.path = "user://zp_test_starmap107_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _analyse_all(sector: int) -> void:
	for sg in Scan.signals(sector):
		if not sg.get("known", false):
			Scan.analyze(str(sg.id))
			Scan.finish()


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "starmap_tour": true}
	Career.data.money = 120000.0
	Career.save()
	Scan.ON = true
	await _spawn()
	await _frames(20)
	var ord: Array = Scan.order()
	# the nearest sector: swept, all analysed, its hulk sent for (towing)
	Scan.sweep(ord[0])
	Scan.finish()
	_analyse_all(ord[0])
	g.open_star_map("find")
	await _frames(10)
	var sm = g.console_ui
	var towed := ""
	var fi: Array = Scan.found()
	if not fi.is_empty():
		towed = str(Career.data.offers[fi[0]].get("scan_sig", ""))
		sm._send(fi[0])
	await _frames(10)
	# the second: swept, analysed, its hulk waiting for a tug
	Scan.sweep(ord[1])
	Scan.finish()
	_analyse_all(ord[1])
	Scan.sweep(ord[2])
	Scan.finish()
	sm.sel_sector = ord[1]
	sm.sel_sig = ""
	sm._sig_key = ""
	sm._fill()
	await _frames(40)
	var sends: Array = sm.find_box.find_children("Send_*", "Button", true, false)
	var any_ship := Scan.signals(ord[1]).any(func(s): return str(s.get("kind", "")) == "ship")
	check(not any_ship or sends.size() >= 1, "a hulk found is its own tug button on its row (%d)" % sends.size())
	check(sm.find_box.find_child("SectorPicked", true, false) != null, "the picked sector folds to one line")
	var p: Vector2 = sm._to(Orbits.pos(Orbits.station(ord[1]), Shipping.day()))
	check(not sm._inset_rect().grow(10).has_point(p), "the inset keeps off the picked sector")
	Cap.save(root, "res://tests/out/starmap107_%s_found.png" % tag)
	# the first sector: its hulk's row says it is under tow
	sm.sel_sector = ord[0]
	sm._sig_key = ""
	sm._fill()
	await _frames(60)
	if towed != "":
		var row = sm.find_box.find_child("Sig_" + towed, true, false)
		check(row != null and ("拖运途中" in str(row.text) or "已拖回港" in str(row.text)), "the towed hulk's row says where it is (%s)" % (str(row.text) if row != null else "-"))
	var p0: Vector2 = sm._to(Orbits.pos(Orbits.station(ord[0]), Shipping.day()))
	check(not sm._inset_rect().grow(10).has_point(p0), "the inset moved off this sector too")
	Cap.save(root, "res://tests/out/starmap107_%s_towing.png" % tag)
	print("STARMAP107 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
