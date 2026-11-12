extends "res://tests/hold_nocollide_check.gd"
# 2026-11-11 排队拧: its card on the terminal's drone page (under the two tunnels'), chosen, locked
# (a new career) and buyable (one job done). Saves tests/out/wrench_queue_card_<state>.png.
#   tools/run_test.sh tests/wrench_queue_card_shot.gd --fixed-fps 60

func _initialize() -> void:
	Career.path = "user://zp_test_wqcard_career.json"
	SaveGame.path = "user://zp_test_wqcard_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	for state in ["locked", "open", "bought"]:
		Career.start_new()
		Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true, "starmap_tour": true}
		Career.data.market = true
		Career.data.money = 60000.0
		Career.data.done = 0 if state == "locked" else 1
		if state == "bought":
			Career.data.upgrades["wrench_queue"] = 1
		Career.save()
		Game.start_ship = "berth"
		Game.contract = {}
		SaveGame.load_requested = false
		g = load("res://scenes/main.tscn").instantiate()
		g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
		root.add_child(g)
		await _frames(10)
		g.tutorial = null
		g.open_console("terminal")
		await _frames(10)
		var term = g.console_ui
		term._skip_boot()
		term.set_tab(Terminal.DRONE_PAGE)
		await _frames(30)
		var i: int = term._wq_i()
		term.sel = i
		await _frames(40)
		var r: Rect2 = term._item_rect(i)
		print("  %s: card %d rect %s, deal_t %.2f, items %d, why '%s'" % [state, i, r, term.deal_t, term.items().size(), term._late_why("wrench_queue")])
		check(term.items()[i][0] == "wrench_queue", "%s: the card is the queued wrench" % state)
		check(r.size.x > 0 and r.end.y < term.size.y, "%s: its card on the page" % state)
		check((term._late_why("wrench_queue") != "") == (state == "locked"), "%s: locked only before the first job" % state)
		check(g.has_upgrade("wrench_queue") == (state == "bought"), "%s: fitted only once bought (berth)" % state)
		Cap.save(root, "res://tests/out/wrench_queue_card_%s.png" % state)
		g.queue_free()
		await _frames(6)
	print("wrench_queue_card_shot: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
