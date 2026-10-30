extends "res://tests/guide_check.gd"
# 48 号: the operator's hand on the grid (Q38) and the control screen (Q40). A lower furnace cap
# gets a heat admitted where the full rating would wait; a running heat can be held down but not
# raised past its share; deferred heats do not ask; "own sets only" never takes shore power and
# "own + shore automatically" takes it without asking at the desk. The screen reads the real
# loads, and keeps a trend. Own test saves only.
#   tools/run_test.sh tests/power_control_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_power_control_career.json"
	SaveGame.path = "user://zp_test_power_control_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 300000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 0, "cargo": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.save()
	await _spawn()
	await _frames(10)
	# 70 号: stage 0 makes 6 MW, the base takes 2: a heat runs at once on the 4 MW left
	Career.data.industrial_heat = {"id": "HEAT-T", "state": "processing", "quantity": 1.0, "grid": {"own": 0.0, "shore": 0.0, "dyn": true}}
	var batch := {"state": "processing", "grid": {}}
	check(not Grid.admit_heat(g, batch).is_empty() and is_equal_approx(float(Grid.alloc(g, "heat").own), 4.0), "no queue: the heat is on the bus with the 4 MW there is")
	Career.data.port["power"] = 1
	check(Grid.set_ctl("furnace_cap", 12.0).ok and is_equal_approx(float(Grid.alloc(g, "heat").own), 12.0), "at stage 1, capped at 12 MW, it takes 12 (%s)" % str(Grid.alloc(g, "heat")))
	Grid.set_ctl("furnace_cap", 24.0)
	Career.data.port["power"] = 0
	# the line
	Grid.set_ctl("line", "own_only")
	Career.data.industrial_heat.shore_asked = true
	check(float(Grid.alloc(g, "heat").shore) == 0.0, "own sets only: no shore even when asked")
	Career.data.industrial_heat.shore_asked = false
	Grid.set_ctl("line", "auto_shore")
	var adm2 := Grid.alloc(g, "heat")
	check(is_equal_approx(float(adm2.own), 4.0) and is_equal_approx(float(adm2.shore), 12.0), "own + shore automatically: the shore makes it up unasked (%s)" % str(adm2))
	Grid.set_ctl("line", "auto")
	Career.data.industrial_heat = {}
	# deferred
	Grid.set_ctl("defer", true)
	Grid.set_ctl("furnace_cap", 6.0)
	check(Grid.admit_heat(g, {"state": "processing", "grid": {}}).is_empty(), "deferred: a new heat does not ask")
	Career.data.industrial_heat = {"id": "HEAT-T", "state": "processing", "quantity": 1.0, "grid": {}}
	check(Grid.wait_text(g).find("延后") >= 0, "and the wait says why: %s" % Grid.wait_text(g))
	Grid.set_ctl("defer", false)
	# a running heat: down at once, not up past its share
	Career.data.industrial_heat = {"id": "HEAT-T", "state": "processing", "quantity": 1.0, "grid": {"own": 12.0, "shore": 0.0}}
	var down := Grid.set_ctl("furnace_cap", 8.0)
	check(down.ok and str(down.note).find("立即降到") >= 0, "running: lowered at once (%s)" % str(down.note))
	var up := Grid.set_ctl("furnace_cap", 20.0)
	check(up.ok and str(up.note).find("下一炉") >= 0, "running: more only from the next heat (%s)" % str(up.note))
	Career.data.industrial_heat = {}
	Grid.set_ctl("furnace_cap", 24.0)
	# the screen
	g.open_power_screen()
	await _frames(130)
	var ui = g.console_ui
	check(ui != null and ui.get_script() == preload("res://scripts/power_panel.gd"), "the control screen opens")
	var rd: Dictionary = ui.readings()
	var total := 0.0
	for l in Grid.loads(g):
		total += float(l.mw)
	check(is_equal_approx(float(rd.total), total) and int(rd.units) == 1, "its bus reads the real loads (%.1f MW, %d set)" % [total, int(rd.units)])
	check(ui.gauges.get_child_count() == 3, "three gauges for the one set")
	check(Grid.history.size() >= 1, "the trend has samples (%d)" % Grid.history.size())
	Cap.save(root, "res://tests/out/power_screen_zh.png")
	ui.close()
	g.queue_free()
	await _frames(4)
	print("POWER CONTROL %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
