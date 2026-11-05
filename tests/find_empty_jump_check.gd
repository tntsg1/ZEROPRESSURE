extends "res://tests/guide_check.gd"
# The find-ships page with nothing on it goes straight to the star map's sweep (user 2026-10-28,
# 截图：找船页只有一行“还没找到船。点上面‘星图扫描找船’…”："这个我都说多少次了，如果二手船是一点东西
# 都没有的话，直接跳到星图的扫描界面"). With a card on it, or the hulk market open, the page stays.
# Own test saves only.
#   tools/run_test.sh tests/find_empty_jump_check.gd


func _initialize() -> void:
	Career.path = "user://zp_test_find_empty_career.json"
	SaveGame.path = "user://zp_test_find_empty_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _term():
	for k in 120:
		if g.console_ui == null:
			break
		await process_frame
	g.open_console("terminal")
	await _frames(12)
	return g.console_ui


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.offers = []
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "starmap_tour": true}
	Career.data.money = 20000.0
	Career.save()
	Scan.ON = true
	await _spawn()
	await _frames(20)
	var term = await _term()
	check(term != null and term.get_script() == preload("res://scripts/terminal.gd"), "the terminal opens")
	check(not ShipMarket.open() and term.offers().is_empty(), "no hulk found, no market: nothing for the find-ships page")
	term.set_tab(0)
	await _frames(12)
	check(g.console_ui != null and g.console_ui.has_method("_fill_find") and g.console_ui.mode == "find", "Find ships asked for: the star map's sweep opens instead (%s)" % (g.console_ui.get_script().resource_path if g.console_ui != null else "-"))
	if g.console_ui != null:
		g.console_ui.close()
		await _frames(12)
	# 2026-11-04 (user: "二手船市里没找到船，怎么还是跳到这个二手船市里呢"): the hulk market open,
	# still no hulk found and none on the way — the sweep all the same, with a key to the hulk market
	Career.data.port = Career.data.get("port", {}).duplicate()
	Career.data.port.trade = 1
	Career.save()
	check(ShipMarket.open() and ShipMarket.on_the_way().is_empty(), "the hulk market is open, nothing on the way")
	term = await _term()
	term.set_tab(0)
	await _frames(12)
	var sm = g.console_ui
	check(sm != null and sm.has_method("_fill_find") and sm.mode == "find", "market open, no hulk: Find ships still opens the star map's sweep")
	var key_ok := false
	if sm != null:
		for b in sm.find_children("*", "Button", true, false):
			if str(b.text).contains("二手船市"):
				key_ok = b.visible and not b.disabled
	check(key_ok, "the star map's find page has the key to the hulk market")
	if sm != null:
		Cap.save(root, "res://tests/out/find_empty_market_open.png")
		sm.close()
		await _frames(12)
	# a hulk found: its card is there, the page stays
	Scan.ON = false
	Career.data.offers = Market.make(4242, Career.data).slice(0, 1)
	Scan.ON = true
	Career.save()
	term = await _term()
	term.set_tab(0)
	await _frames(6)
	check(g.console_ui == term and term.tab == 0, "with a hulk card the find-ships page opens as before")
	term.close()
	await _frames(12)
	print("FIND EMPTY JUMP %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
