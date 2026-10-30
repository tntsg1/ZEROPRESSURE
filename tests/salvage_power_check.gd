extends "res://tests/guide_check.gd"
# 71 号: the berth on the grid. In a career's contract the laser (while it fires), the trough's
# conveyor and the berth furnace are the salvage group's loads; the small ones are served
# first, the furnace takes the rest; each runs at what it is given (the laser keeps 15 %, the
# belt 20 %); at power stage 1 all run full; put last in the order they slow; the training
# course is not on the grid; the HUD says when the berth is short. Own saves only.
#   tools/run_test.sh tests/salvage_power_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_salvage_power_career.json"
	SaveGame.path = "user://zp_test_salvage_power_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _ship(job: Dictionary) -> void:
	Game.contract = job
	Game.start_ship = str(job.ship)
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(12)
	g.tutorial = null


func _run() -> void:
	Txt.zh = true
	Grid.BOTS = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.port = {"salvage": 1, "power": 0}
	Career.data.active = Career.opening(1)
	Career.save()
	await _ship(Career.active())
	check(Grid.applies(g), "a career's contract is on the grid")
	# the furnace melting (scrap in its bunker): it asks for its 24 MW
	g.dock.smelter.bunker = 2.0
	var al := Grid.dispatch(g)
	check(float(al.laser.own) == 0.0 and is_equal_approx(float(al.mouth.own) + float(al.berth_furnace.own), 4.0), "the laser asks nothing until it fires; the belt and the furnace share the 4 MW")
	check(is_equal_approx(float(al.mouth.own) / float(al.berth_furnace.own), 0.8 / 24.0), "by demand (belt %.2f, furnace %.2f MW)" % [float(al.mouth.own), float(al.berth_furnace.own)])
	await _frames(3)
	check(is_equal_approx(g.dock.smelter.grid_cap, float(Grid.dispatch(g).berth_furnace.own)), "and the furnace heats on no more than that (%.2f MW)" % g.dock.smelter.grid_cap)
	# the laser fires
	g.tools.tool = 2
	g.tools.cutting = true
	al = Grid.dispatch(g)
	var lk := Grid.salvage_k(g, "laser", 0.15)
	check(is_equal_approx(float(al.laser.own), 4.0 * 1.5 / 26.3) and lk < 0.2, "firing while the furnace melts, the laser gets its share: %d%% speed" % int(lk * 100.0))
	# the furnace empty: it asks only to stay hot, the laser gets more
	g.dock.smelter.bunker = 0.0
	g.dock.smelter.m_s = 0.0
	g.dock.smelter.phase = "hold"
	al = Grid.dispatch(g)
	check(Grid.salvage_k(g, "laser", 0.15) > lk * 1.5, "with nothing to melt the furnace asks only to stay hot: the laser at %d%%" % int(Grid.salvage_k(g, "laser", 0.15) * 100.0))
	g.dock.smelter.bunker = 2.0
	await _frames(70)
	check(g.hud._sp_text.begins_with("电不够"), "the HUD says the berth is short: %s" % g.hud._sp_text)
	Cap.save(root, "res://tests/out/salvage_power_short_zh.png")
	# salvage put last, a big load ahead of it
	var fake := preload("res://tests/grid_check.gd").Fake.new()
	fake.group = "process"
	fake.mw = 24.0
	root.add_child(fake)
	Grid.add_load_source(fake)
	Grid.set_ctl("order", ["process", "cargo", "tug", "salvage"])
	al = Grid.dispatch(g)
	check(float(al.laser.own) == 0.0 and is_equal_approx(Grid.salvage_k(g, "laser", 0.15), 0.15) and is_equal_approx(Grid.salvage_k(g, "mouth", 0.2), 0.2), "salvage last behind a 24 MW load: the laser and the belt fall back on their reserves")
	await _frames(3)
	check(g.dock.smelter.grid_cap == 0.0, "the furnace gets nothing")
	fake.queue_free()
	Grid.set_ctl("order", Grid.GROUPS.duplicate())
	# stage 1: all full
	Career.data.port["power"] = 1
	await _frames(3)
	check(is_equal_approx(Grid.salvage_k(g, "laser", 0.15), 1.0) and is_equal_approx(Grid.salvage_k(g, "mouth", 0.2), 1.0) and is_equal_approx(g.dock.smelter.grid_cap, 24.0), "at stage 1 the berth runs full")
	g.tools.cutting = false
	g.queue_free()
	await _frames(4)
	# the first ship: the port authority's line
	Career.data.port["power"] = 0
	Career.data.active = Career.opening(0)
	Career.save()
	await _ship(Career.active())
	g.tools.tool = 2
	g.tools.cutting = true
	g.dock.smelter.bunker = 2.0
	check(Grid.first_ship(g) and Grid.salvage_k(g, "laser", 0.15) == 1.0 and is_equal_approx(g.dock.smelter.grid_cap if g.dock.smelter.grid_cap > 0.0 else 24.0, 24.0), "TUG-001 rides the subsidised line: full speed at 6 MW")
	await _frames(70)
	check(g.hud._sp_text == "", "and nothing on the HUD")
	g.tools.cutting = false
	g.queue_free()
	await _frames(4)
	# a bot without the switch: not on the grid
	Career.data.port["power"] = 0
	Grid.BOTS = false
	await _ship(Career.active())
	check(not Grid.applies(g) and Grid.salvage_k(g, "laser", 0.15) == 1.0, "a bot's run without the switch is not on the grid")
	g.queue_free()
	await _frames(4)
	print("SALVAGE POWER %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
