extends "res://tests/guide_check.gd"
# 73 号: the warehouse as a real store. Eight rows with default uses; the farther a row from the
# floor hatch the longer a pick; a row's use can be changed and goods follow it; goods with no
# row of their own go to the sundries row; a pick waits for a forklift (one at stage 0, two
# with the cargo district), which runs on the grid (the cargo group) and crawls on its own
# battery without it; the racks and the forklifts are drawn; the racks page on the district's
# console changes a row. Own saves only.
#   tools/run_test.sh tests/warehouse_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_warehouse_career.json"
	SaveGame.path = "user://zp_test_warehouse_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.money = 300000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1}
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(300000.0)
	Career.save()
	# ---- the rows
	check(Warehouse.rows() == Warehouse.DEFAULT and Warehouse.row_for("ferrous_scrap:1") == 0 and Warehouse.row_for("steel_billet:1") == 4, "default racks: ingots on A1, billets on B1")
	check(Warehouse.trip(0) > Warehouse.trip(3) + 1.0, "a row far from the hatch is slower (A1 %.0f s, A4 %.0f s)" % [Warehouse.trip(0), Warehouse.trip(3)])
	check(Warehouse.set_row(0, "misc").ok and Warehouse.set_row(3, "ingot").ok and Warehouse.row_for("ferrous_scrap:1") == 1, "A1 to sundries, A4 to ingots: ingots now go to A2, the first ingot row")
	Warehouse.set_row(1, "parts")
	check(Warehouse.row_for("ferrous_scrap:1") == 3, "A2 to parts: the ingots are on A4, nearer the hatch")
	Warehouse.set_row(5, "billet")
	check(not Warehouse.has_row("steel_section:1") and Warehouse.row_for("steel_section:1") == 0, "no row for sections: they go to the sundries row (A1)")
	Warehouse.reset_rows()
	check(Warehouse.rows() == Warehouse.DEFAULT, "back to the default racks")
	# ---- a pick
	check(Warehouse.forklifts() == 1, "one forklift before the cargo district works")
	Warehouse.ask_out("T1", "ferrous_scrap:1", 1.0)
	check(not Warehouse.ready("T1") and Warehouse.wait_text("T1").contains("叉车"), "a pick waits for the forklift: %s" % Warehouse.wait_text("T1"))
	Warehouse.advance(null, Warehouse.trip(0) - 1.0)
	check(not Warehouse.ready("T1"), "not before its trip is done")
	Warehouse.advance(null, 1.5)
	check(Warehouse.ready("T1"), "then it is at the hatch")
	Warehouse.consume("T1")
	Warehouse.ask_out("T2", "ferrous_scrap:1", 1.0)
	Warehouse.ask_out("T3", "steel_billet:1", 1.0)
	check(Warehouse.wait_text("T3").contains("前面还有"), "one forklift: the second pick waits its turn")
	Career.data.port["cargo"] = 1
	check(Warehouse.forklifts() == 2 and Warehouse.wait_text("T3").contains("叉车"), "two forklifts with the cargo district: both drive")
	Career.save()
	var keep := JSON.stringify(JSON.parse_string(JSON.stringify(Career.data.wh)))
	Career.data = {}
	Career.load_or_new()
	check(JSON.stringify(JSON.parse_string(JSON.stringify(Career.data.get("wh", {})))) == keep, "the racks and the moves are in the save")
	# ---- on the grid
	await _spawn()
	await _frames(20)
	var al := Grid.dispatch(g)
	check(al.has("forklift_0") and al.has("forklift_1") and is_equal_approx(float(al.forklift_0.own), 0.4), "the forklifts draw 0.4 MW each, the cargo group")
	var fake := preload("res://tests/grid_check.gd").Fake.new()
	fake.group = "salvage"
	fake.mw = 24.0
	root.add_child(fake)
	Grid.add_load_source(fake)
	await _frames(2)
	check(is_equal_approx(Warehouse.k(g), Warehouse.FLOOR), "a 24 MW load ahead at 6 MW: they crawl on their batteries (%.2f)" % Warehouse.k(g))
	var left0 := float(Warehouse.job("T2").left)
	Warehouse.advance(g, 10.0)
	check(is_equal_approx(left0 - float(Warehouse.job("T2").left), 1.0), "ten seconds move them one")
	fake.queue_free()
	await _frames(2)
	# ---- drawn
	Career.data.exchange.actors.company.stock["ferrous_scrap:1"] = 3.0
	Career.data.exchange.actors.company.stock["steel_billet:1"] = 1.5
	g.drone.global_position = PortStructure.box("cargo").get_center()
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(30)
	g.cam_override = PortStructure.box("cargo").get_center()
	g.zoom_override = 0.55
	await _frames(40)
	Cap.save(root, "res://tests/out/warehouse_racks_zh.png")
	g.cam_override = null
	g.zoom_override = -1.0
	# ---- the racks, at the racks (85 号): E under the left rack opens A1–A4 only
	g.drone.global_position = preload("res://scripts/cargo_floor.gd").mouth("A")
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(10)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	ev.pressed = true
	g._unhandled_input(ev)
	await _frames(20)
	var ui = g.console_ui
	check(ui != null and str(ui.get("side")) == "A" and ui.rows_box.get_child_count() == 4, "E under the left rack opens its four rows only")
	Cap.save(root, "res://tests/out/warehouse_console_zh.png")
	var pick: OptionButton = ui.rows_box.get_child(2).find_children("*", "OptionButton", true, false)[0]
	pick.select(Warehouse.USES.find("billet"))
	pick.item_selected.emit(Warehouse.USES.find("billet"))
	await _frames(4)
	check(str(Warehouse.rows()[2]) == "billet" and ui.message.text.contains("A3"), "a row changed at its rack: %s" % ui.message.text)
	ui.close()
	g.queue_free()
	await _frames(4)
	print("WAREHOUSE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
