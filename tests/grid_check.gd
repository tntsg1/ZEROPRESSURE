extends "res://tests/guide_check.gd"
# 70 号 (from 34 号): the port's grid, shared out by priority. Own generation 6 / 30 / 80 MW by
# the power district's stage; the base (2 MW) first; then the groups in the operator's order
# (default salvage, cargo, process, tug), each shared by demand; no queue — a heat runs at once
# on what it is given and melts slower when short; the shore line tops it up (dearer); the
# training run rides the subsidised line; an older save's "company first" becomes processing
# ahead of salvage. Own test saves only.
#   tools/run_test.sh tests/grid_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_grid_career.json"
	SaveGame.path = "user://zp_test_grid_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _heat(state: String) -> void:
	Career.data.industrial_heat = {"id": "H-G", "state": state, "quantity": 1.0, "source_lots": [], "furnace": g.plant.smelter.manual_snapshot(),
		"transport": {}, "electric_paid_j": float(g.plant.smelter.electrical_j), "energy_cost": 0.0, "created": 0.0}


# a load of its own on the bus, for the order checks
class Fake extends Node:
	var group := "salvage"
	var mw := 3.0
	func grid_loads() -> Array:
		return [{"id": "fake_" + group, "name": "FAKE", "group": group, "rated": mw, "demand": mw, "mw_now": -1.0, "state": "run"}]


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	Career.save()
	await _spawn()
	await _frames(20)
	check(Grid.capacity() == 6.0, "a ruined power district makes 6 MW")
	check(is_equal_approx(Grid.headroom(g), 4.0), "the base takes 2 MW first: 4 MW to spare (%.1f)" % Grid.headroom(g))
	# a heat with its feed in, at stage 0: no queue, it runs on what there is
	_heat("processing")
	await _frames(10)
	var h: Dictionary = Career.data.industrial_heat
	check(not h.get("grid", {}).is_empty() and is_equal_approx(g.plant.smelter.manual_supply_mw, 4.0), "the heat runs at once on the 4 MW there is (%.1f MW)" % g.plant.smelter.manual_supply_mw)
	check(is_equal_approx(Grid.k(g, "heat"), 4.0 / 24.0), "at a sixth of its speed (%.2f)" % Grid.k(g, "heat"))
	check(str(g.industrial_heat.waiting).begins_with("电不够"), "the furnace desk says why (%s)" % g.industrial_heat.waiting)
	var decs := Ops.decisions(g)
	check(decs.any(func(o): return str(o.title).find("电不够") >= 0), "the home screen lists the furnace short of power")
	var cell: Dictionary = Ops._grid(g)
	check(str(cell.lamp) == "warn" and str(cell.value).ends_with("6 MW"), "the grid cell reads the real bus (%s, %s)" % [cell.value, cell.lamp])
	# the shore line tops it up
	check(g.industrial_heat.ask_shore().ok, "asked for shore power at the desk")
	await _frames(6)
	h = Career.data.industrial_heat
	check(is_equal_approx(float(h.grid.own), 4.0) and is_equal_approx(float(h.grid.shore), 12.0) and is_equal_approx(g.plant.smelter.manual_supply_mw, 16.0), "4 MW own + 12 MW shore = 16 MW")
	check(is_equal_approx(Grid.price(h), (4.0 * Grid.OWN_PRICE + 12.0 * Grid.SHORE_PRICE) / 16.0), "billed by share ($%.0f/MWh)" % Grid.price(h))
	check(not g.industrial_heat.ask_shore().ok, "asked once is enough")
	# stage 1: full power on its own
	Career.data.port["power"] = 1
	_heat("processing")
	await _frames(6)
	h = Career.data.industrial_heat
	check(is_equal_approx(float(h.grid.own), 24.0) and float(h.grid.shore) == 0.0 and Grid.price(h) == Grid.OWN_PRICE, "with the district at stage 1 a heat runs full on the port's own sets")
	check(is_equal_approx(Grid.headroom(g), 30.0 - 2.0 - 24.0) and g.industrial_heat.waiting == "", "4 MW stays spare, nothing to say")
	# the order: a salvage load first by default, processing first once moved up
	var fake := Fake.new()
	fake.mw = 6.0
	root.add_child(fake)
	Grid.add_load_source(fake)
	Career.data.port["power"] = 0
	Career.data.industrial_heat.shore_asked = false
	await _frames(3)
	check(is_equal_approx(float(Grid.alloc(g, "fake_salvage").own), 4.0) and is_equal_approx(float(Grid.alloc(g, "heat").own), 0.0), "salvage first: it takes the 4 MW, the furnace gets none")
	var r := Grid.set_ctl("order", Grid.moved("process", -1))
	r = Grid.set_ctl("order", Grid.moved("process", -1))
	check(r.ok and Grid.order()[0] == "process", "processing moved to the front (%s)" % str(r.get("note", "")))
	await _frames(3)
	check(is_equal_approx(float(Grid.alloc(g, "heat").own), 4.0) and is_equal_approx(float(Grid.alloc(g, "fake_salvage").own), 0.0), "now the furnace takes it")
	check(not Grid.set_ctl("order", ["process", "salvage"]).ok, "an order without all four groups is refused")
	# within a group: by demand
	fake.group = "process"
	await _frames(3)
	var a1 := float(Grid.alloc(g, "heat").own)
	var a2 := float(Grid.alloc(g, "fake_process").own)
	check(is_equal_approx(a1 + a2, 4.0) and is_equal_approx(a1 / a2, 24.0 / 6.0), "inside a group shared by demand (%.2f / %.2f)" % [a1, a2])
	fake.queue_free()
	await _frames(2)
	# the catch-up after a contract: the berth furnace first only if salvage comes first
	Grid.set_ctl("order", Grid.GROUPS.duplicate())
	Career.data.port["power"] = 1
	check(is_equal_approx(Grid.contract_supply(h), 30.0 - 2.0 - 24.0), "while a contract ran the heat had what the berth furnace left (%.0f MW)" % Grid.contract_supply(h))
	Career.data.port["power"] = 2
	check(is_equal_approx(Grid.contract_supply(h), 24.0), "with stage 2 it had its full share")
	# an older save's two-way priority
	Career.data.grid_ctl = {"priority": "company"}
	check(Grid.order()[0] == "process", "an older save's \"company first\" reads as processing first")
	Career.data.grid_ctl = {}
	# the training run's line
	_heat("processing")
	Career.data.industrial_heat.drill = true
	Career.data.port["power"] = 0
	await _frames(6)
	h = Career.data.industrial_heat
	check(h.grid.get("free", false) and Grid.price(h) == 0.0 and g.plant.smelter.manual_supply_mw == 24.0, "the training run's heat rides the port authority's line, free")
	check(is_equal_approx(Grid.headroom(g), 4.0), "and takes nothing from the bus")
	# the control screen with a short heat
	_heat("processing")
	Career.data.port["power"] = 0
	await _frames(6)
	g.drone.global_position = PortStructure.console_spot("power")
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(10)
	g.open_district("power")
	await _frames(20)
	Cap.save(root, "res://tests/out/grid_bus_zh.png")
	if g.console_ui != null:
		g.console_ui.close()
	Career.data.industrial_heat = {}
	g.queue_free()
	await _frames(4)
	print("GRID %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
