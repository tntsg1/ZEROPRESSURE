extends "res://tests/guide_check.gd"
# 2026-11-04 (user): "电弧炉暂停" at the power screen stops the heat in the furnace at once — it waits
# for power — and "电弧炉工作" lets it warm up again. The real chain: the power screen's key → Grid's
# setting → the dispatch's share for the heat (Grid.heat_supply) → the real furnace model
# (scripts/smelter.gd) heating on that share. No confirm box; the note says what happened; the
# furnace desk says it is paused and how to undo it, with the way to the power screen.
#   tools/run_test.sh tests/furnace_pause_check.gd --fixed-fps 60

const Furnace = preload("res://scripts/smelter.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_furnace_pause_career.json"
	SaveGame.path = "user://zp_test_furnace_pause_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


# the furnace heated for s seconds on what the grid gives the heat
func _heat(f, heat: Dictionary, s: float) -> void:
	for i in int(s * 60.0):
		f.manual_supply_mw = Grid.heat_supply(g, heat)
		f.step(1.0 / 60.0)


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.money = 50000.0
	Career.data.port = {"trade": 1, "process": 1, "power": 1}
	Career.save()
	await _spawn()
	await _frames(20)
	# the port's own furnace service is held still: this heat is driven here, on the real grid and model
	if g.industrial_heat != null:
		g.industrial_heat.process_mode = Node.PROCESS_MODE_DISABLED
	Grid.set_ctl("defer", false)
	Grid.set_ctl("line", "auto")
	# a heat on the grid, and a real furnace with a cold charge, power on, feeding
	var heat := {"id": "HEAT-P", "state": "processing", "quantity": 2.0, "grid": {"own": 0.0, "shore": 0.0}}
	Career.data.industrial_heat = heat
	var f = Furnace.new()
	f.begin_manual()
	f.manual_charge(2.0)
	f.manual_command("feed", 1.0)
	f.manual_command("power", 1.0)
	_heat(f, heat, 20.0)
	var t1: float = f.T
	check(t1 > 25.0 and Grid.heat_supply(g, heat) > 0.5, "running: the heat gets power and warms (%.0f °C, %.1f MW)" % [t1, Grid.heat_supply(g, heat)])
	# paused at the power screen: at once, no confirm, a note of what happens
	g.open_power_screen()
	await _frames(40)
	var ui = g.console_ui
	ui.furnace_pause.pressed.emit()
	await _frames(3)
	check(bool(Grid.ctl().defer), "电弧炉暂停: set at once")
	check(not ui.confirm.visible, "no confirm box")
	check(ui.msg.text.contains("电弧炉已暂停") and ui.msg.text.contains("停下等电"), "the note says the heat stops and waits (%s)" % ui.msg.text)
	Cap.save(root, "res://tests/out/furnace_pause_note.png")
	ui.close()
	await _frames(20)
	_heat(f, heat, 1.0)          # what was already in the furnace settles
	var t2: float = f.T
	_heat(f, heat, 20.0)
	var t3: float = f.T
	check(Grid.heat_supply(g, heat) == 0.0, "paused: the heat is given no power (%.2f MW)" % Grid.heat_supply(g, heat))
	check(t3 <= t2 + 0.01, "paused: the heat in the furnace no longer warms (%.1f → %.1f °C)" % [t2, t3])
	check(Grid.wait_text(g).contains("暂停") and Grid.wait_text(g).contains("停下等电"), "the wait says it truly (%s)" % Grid.wait_text(g))
	check(not str(Grid.set_ctl("defer", true).get("note", "")).contains("不受影响"), "no 'the running one is untouched' any more")
	# the furnace desk: paused, how to undo it, the way to the power screen
	var hp = preload("res://scripts/heat_panel.gd").new()
	hp.service = g.industrial_heat
	var was_heat: Dictionary = g.industrial_heat.heat() if g.industrial_heat != null and g.industrial_heat.has_method("heat") else {}
	var n: Array = hp._next() if g.industrial_heat != null and str(was_heat.get("state", "")) == "processing" else []
	if not n.is_empty():
		check(str(n[0]).contains("电弧炉已暂停（供电屏）") and str(n[0]).contains("电弧炉工作"), "the desk says paused and how to undo it (%s)" % str(n[0]))
	hp.free()
	# running again: it warms up again
	g.open_power_screen()
	await _frames(40)
	ui = g.console_ui
	ui.furnace_run.pressed.emit()
	await _frames(3)
	check(not bool(Grid.ctl().defer) and ui.msg.text.contains("继续升温"), "电弧炉工作: back at once, the note says so (%s)" % ui.msg.text)
	ui.close()
	await _frames(20)
	_heat(f, heat, 20.0)
	var t4: float = f.T
	check(t4 > t3 + 5.0, "running again: the heat warms up again (%.1f → %.1f °C)" % [t3, t4])
	Career.data.industrial_heat = {}
	print("FURNACE PAUSE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
