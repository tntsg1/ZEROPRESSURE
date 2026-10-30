extends "res://tests/guide_check.gd"
# 66 号: what ship turns up is decided by the berth's length alone (no reputation gate), and the
# growth page has no ship catalogue. Also times the frame with the terminal's home and the exchange
# open (the play-test "it lags"). Own saves only.
#   tools/run_test.sh tests/berth_unlock_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_berth_unlock_career.json"
	SaveGame.path = "user://zp_test_berth_unlock_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _ships(career: Dictionary, n: int) -> Dictionary:
	var seen := {}
	for sd in n:
		var rng := RandomNumberGenerator.new()
		rng.seed = sd * 31 + 5
		seen[Market.pick_ship(rng, career, 3)] = true
	return seen


func _wall(n: int = 120) -> float:
	await _frames(15)
	var t0 := Time.get_ticks_usec()
	await _frames(n)
	return (Time.get_ticks_usec() - t0) / 1000.0 / n


func _run() -> void:
	Txt.zh = true
	# ---- by the berth alone
	var small := Career.fresh()
	small.rep = 0
	var big := Career.fresh()
	big.rep = 0
	big.upgrades["berth88"] = 1
	var s_small := _ships(small, 400)
	var s_big := _ships(big, 400)
	var too_long := false
	for sh in s_small:
		too_long = too_long or float(Market.type_of(str(sh)).get("length", 0.0)) > Dock.owned(small.upgrades) - 6.0
	check(not too_long, "a 50 m berth never gets a ship longer than it can take (%d types)" % s_small.size())
	var gated := false
	for e in Market.POOL:
		if int(e[2]) > 0 and s_big.has(str(e[0])):
			gated = true
	check(gated and s_big.size() > s_small.size(), "an 88 m berth at reputation 0 gets ships that used to need reputation (%d types)" % s_big.size())
	# ---- the growth page and the frame
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 300000.0
	Career.data.port = {"salvage": 1, "trade": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.save()
	await _spawn()
	await _frames(20)
	var berth_ms := await _wall()
	g.open_console("terminal")
	await _frames(6)
	var term = g.console_ui
	term._skip_boot()
	var home_ms := await _wall()
	term.set_tab(5)
	await _frames(20)
	check(term.route_panel.categories.get_child_count() == 3, "the growth page: berth repairs, the port, equipment upgrades — no ship catalogue")
	term.close()
	await _frames(6)
	g.open_exchange()
	await _frames(20)
	var ex_ms := await _wall()
	if g.console_ui != null:
		g.console_ui.close()
	await _frames(6)
	print("PERF UI  berth %.2f ms · terminal home %.2f ms · exchange %.2f ms" % [berth_ms, home_ms, ex_ms])
	check(home_ms <= 16.7 and ex_ms <= 16.7, "the terminal's home and the exchange hold 60 fps (%.1f / %.1f ms)" % [home_ms, ex_ms])
	g.queue_free()
	await _frames(4)
	print("BERTH UNLOCK %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
