extends "res://tests/guide_check.gd"
# user 2026-10-26 ("只有拆船的时候可以esc出现提前结束合同，终端里可以有"): while a ship is being
# stripped the pause menu has 提前结束合同 (two clicks) and so does the terminal; over the empty
# berth neither shows it. Own saves only.
#   tools/run_test.sh tests/end_contract_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_end_contract_career.json"
	SaveGame.path = "user://zp_test_end_contract_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _contract() -> void:
	Game.start_ship = "gr7"
	Game.contract = {"id": "END-EARLY", "ship": "gr7", "fee": 0, "kit": {}}
	# the career's live contract is this one (settling another is refused)
	Career.data.active = Game.contract.duplicate(true)
	Career.data.erase("settled_jobs")
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 200:
		if g.state == "play":
			break
		await _frames(1)
	g.tutorial = null


func _ids() -> Array:
	return g.hud._menu_items().map(func(x): return x[0])


func _run() -> void:
	Txt.zh = true
	Career.start_new()
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true, "starmap_tour": true}
	Career.save()
	# on a contract: the pause menu
	await _contract()
	check(g.state == "play" and g.can_end_early(), "stripping a ship: it can be ended early")
	g.toggle_menu()
	await _frames(30)
	check(_ids() == ["resume", "end", "settings", "title"], "the pause menu: resume, end contract, settings, back (%s)" % str(_ids()))
	g.hud.menu_hover = _ids().find("end")
	g.hud._menu_click()
	await _frames(20)
	check(not g.ended and g.menu_open, "one click only asks again")
	Cap.save(root, "res://tests/out/end_contract_menu_zh.png")
	g.hud.menu_hover = _ids().find("end")
	g.hud._menu_click()
	await _frames(10)
	check(g.ended, "the second click ends the contract")
	g.queue_free()
	await _frames(4)
	# on a contract: the terminal
	await _contract()
	g.open_console("terminal")
	await _frames(40)
	var term = g.console_ui
	check(term != null and term.end_button.visible, "the terminal on site has 提前结束合同")
	Cap.save(root, "res://tests/out/end_contract_terminal_zh.png")
	term.end_button.pressed.emit()
	await _frames(4)
	check(not g.ended and g.console_ui != null, "one click only asks again")
	term.end_button.pressed.emit()
	await _frames(10)
	check(g.ended and g.console_ui == null, "the second click closes the terminal and ends the contract")
	g.queue_free()
	await _frames(4)
	# the empty berth: neither
	await _spawn()
	await _frames(20)
	check(not g.can_end_early(), "the empty berth: nothing to end")
	g.toggle_menu()
	await _frames(4)
	check(_ids() == ["resume", "settings", "title"], "the pause menu: resume, settings, back (%s)" % str(_ids()))
	g.toggle_menu()
	await _frames(4)
	g.open_console("terminal")
	await _frames(10)
	check(g.console_ui != null and not g.console_ui.end_button.visible, "the berth's terminal has no end button")
	g.queue_free()
	await _frames(4)
	print("END CONTRACT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
