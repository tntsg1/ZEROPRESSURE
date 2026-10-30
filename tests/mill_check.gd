extends "res://tests/guide_check.gd"
# 74 号: the rolling mill and repairs with the materials brought. A tonne of grade-1 billet
# comes down from its rack, is rolled (8 MW, the processing group) into plate or sections and
# goes back onto the racks; short of billet or busy it says why; the warehouse's plate counts
# as hull plate and the new sections need is taken off its rack; with the materials brought a
# repair costs a quarter (the crew's wages); what is missing says where to get it; the
# merchants sell plate and sections. Own saves only.
#   tools/run_test.sh tests/mill_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_mill_career.json"
	SaveGame.path = "user://zp_test_mill_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _stock() -> Dictionary:
	return Career.data.exchange.actors.company.stock


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "cargo": 1}
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	_stock()["steel_billet:1"] = 1.5
	Career.save()
	check(Exchange.CATALOG.has("steel_plate") and Exchange.CATALOG.has("steel_section") and Ops.item_name("steel_plate:1").begins_with("钢板"), "plate and sections are goods of the exchange")
	var sellers := 0
	for a in Career.data.exchange.actors:
		if float(Career.data.exchange.actors[a].get("stock", {}).get("steel_section:1", 0.0)) > 0.0:
			sellers += 1
	check(sellers > 0, "merchants hold sections to sell (%d)" % sellers)
	# ---- a pass
	check(Mill.block("plate") == "" and Mill.start("plate").ok, "a pass of plate starts")
	check(is_equal_approx(float(_stock()["steel_billet:1"]), 0.5) and str(Mill.job().state) == "fetch", "a tonne of billet is taken; it comes down from its rack first")
	check(Mill.block("section").contains("正在轧"), "busy: %s" % Mill.block("section"))
	check(not Mill.advance(null, 1.0) and Mill.status().contains("等钢坯"), "the mill waits for the forklift: %s" % Mill.status())
	Warehouse.advance(null, Warehouse.trip(Warehouse.row_for("steel_billet:1")) + 0.5)
	Mill.advance(null, 0.1)
	check(str(Mill.job().state) == "roll", "the billet is in: rolling")
	check(not Mill.advance(null, Mill.ROLL_S - 2.0), "not before its time")
	check(Mill.advance(null, 3.0) and is_equal_approx(float(_stock().get("steel_plate:1", 0.0)), 1.0) and not Mill.busy(), "a tonne of plate on the racks")
	check(Mill.block("section").contains("不到 1 吨"), "short of billet it says why: %s" % Mill.block("section"))
	check(Warehouse.row_for("steel_plate:1") == 5, "plate goes to B2 (sections and plate)")
	# ---- on the grid
	_stock()["steel_billet:1"] = 1.0
	Mill.start("section")
	Career.data.mill.state = "roll"
	await _spawn()
	await _frames(20)
	var al := Grid.dispatch(g)
	check(al.has("mill") and is_equal_approx(float(al.mill.own), 4.0) and is_equal_approx(Mill.k(g), 0.5), "rolling, the mill asks 8 MW of the processing group: at 6 MW it gets 4, half speed")
	g.drone.global_position = PortStructure.console_spot("process")
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(10)
	g.open_district("process")
	await _frames(20)
	Cap.save(root, "res://tests/out/mill_console_zh.png")
	if g.console_ui != null:
		check(not g.console_ui.find_children("*", "Button", true, false).any(func(x): return str(x.text).begins_with("轧钢板")), "85 号: no roll buttons on the console any more")
		g.console_ui.close()
	await _frames(4)
	# ---- 85 号: the mill on site — the pedestal, its panel, a recipe, rolling on
	Career.data.erase("mill")
	_stock()["steel_billet:1"] = 3.0
	var ML = preload("res://scripts/mill_line.gd")
	check(g.mill_line != null and g.mill_line.visible, "the mill stands in the processing district")
	g.drone.global_position = ML.pedestal()
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(6)
	check(g.mill_line.near(), "at the pedestal")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	ev.pressed = true
	g._unhandled_input(ev)
	await _frames(6)
	var mp = g.console_ui
	check(mp != null and mp.has_method("_pick"), "E at the pedestal opens the mill's own panel")
	mp._pick("section")
	check(str(Mill.cfg().product) == "section" and mp.tiles.section.button_pressed and not mp.tiles.plate.button_pressed, "a recipe tile picks sections")
	mp.loop_b.button_pressed = true
	await _frames(2)
	check(bool(Mill.cfg().loop), "rolling on is set")
	mp._once()
	await _frames(4)
	check(Mill.busy() and str(Mill.job().product) == "section", "one pass of sections started")
	Warehouse.advance(g, Warehouse.trip(Warehouse.row_for("steel_billet:1")) + 0.5)
	Mill.advance(g, 0.1)
	Mill.advance(g, Mill.ROLL_S * 0.4)
	await _frames(10)
	Cap.save(root, "res://tests/out/mill_panel_zh.png")
	mp.close()
	await _frames(4)
	g.cam_override = ML.centre()
	g.zoom_override = 0.55
	await _frames(20)
	Cap.save(root, "res://tests/out/mill_world_zh.png")
	g.cam_override = null
	g.zoom_override = -1.0
	Mill.advance(g, Mill.ROLL_S * 3.0)
	check(Mill.busy() and float(_stock().get("steel_section:1", 0.0)) >= 1.0, "a tonne done, rolling on took the next (%.1f t billet left)" % float(_stock()["steel_billet:1"]))
	Mill.set_loop(false)
	Career.data.erase("mill")
	g.queue_free()
	await _frames(4)
	# ---- repairs with the materials
	Career.data.structure_t = 5.0
	_stock()["steel_plate:1"] = 20.0
	_stock()["steel_section:1"] = 6.0
	var pf := Repair.parts_for("berth88")
	check(is_equal_approx(float(pf.tons), 25.0) and is_equal_approx(float(pf.section_missing), 9.0), "berth 88: 5 t kept plate + 20 t rolled count as 25 t hull plate; 9 t of sections short")
	var why := Repair.reason("berth88", true)
	check(why.contains("型材") and why.contains("轧成型材"), "it says what is short and where to get it: %s" % why)
	_stock()["steel_section:1"] = 15.0
	check(is_equal_approx(Repair.price("berth88", true), 240000.0 * 0.25), "with the materials, a quarter of the price (the crew)")
	check(Repair.fix("berth88", true) == "", "berth 88 built with the materials")
	check(float(Career.data.structure_t) == 0.0 and is_equal_approx(float(_stock()["steel_plate:1"]), 0.0) and is_equal_approx(float(_stock()["steel_section:1"]), 0.0), "the kept plate first, then the rolled plate, and the sections, all used")
	check(Port.needs("cargo", 2).has("section") and Port.needs("ring", 2).has("section"), "the cargo district's and the ring's second stages need sections")
	print("MILL %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
