extends "res://tests/guide_check.gd"
# 86 号: the terminal's「船坞」page. A new career knows none of the three faults (grey question
# marks, nothing logged); flying within 8 m of one finds it (framed, one line, logged); the main
# line and the guide send the drone to look first; a found fault's mark opens a small card with
# the two ways to pay; the expansion plans are cards under the drawing, a picked one framed on it;
# an old career has the faults known; the parts are on the rack under the terminal (the cargo
# district's racks once mended); the drone's upgrades are on the loadout page. Own saves only.
#   tools/run_test.sh tests/berth_page_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_berth_page_career.json"
	SaveGame.path = "user://zp_test_berth_page_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _page():
	g.open_console("terminal")
	await _frames(10)
	var term = g.console_ui
	term._skip_boot()
	term.set_tab(1)
	await _frames(30)
	return term


func _shut() -> void:
	if g.console_ui != null and g.console_ui.has_method("close"):
		g.console_ui.close()
	await _frames(6)


func _run() -> void:
	Txt.zh = true
	Career.start_new()
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true, "starmap_tour": true}
	Career.data.money = 20000.0
	Career.save()
	await _spawn()
	await _frames(20)
	# a new career: nothing known
	check(not Repair.found("lights") and not Repair.found("net_fix") and not Repair.found("furnace_main"), "a new career knows none of the three faults")
	check(Repair.open_items().all(func(o): return not Repair.is_fault(str(o.id))), "an unseen fault is not suggested")
	var ps := Repair.plans()
	check("buffer" in ps and "berth88" in ps and "gas_line" in ps and not "hauler" in ps and not "lights" in ps, "the plans: what has its prerequisites done, no faults (%s)" % str(ps))
	var term = await _page()
	var pg = term.repair_panel
	check(int(pg.head_counts[0]) == 0 and pg.heading.text == "船坞", "the status window: nothing logged (%s)" % str(pg.head_counts))
	check(pg.buttons.size() == ps.size(), "one card per plan (%d)" % pg.buttons.size())
	check(pg.find_children("*", "Button", true, false).all(func(b): return not str(b.text).begins_with(Txt.t("rp_sell"))), "no parts shelf on the page")
	pg._map_input(_click_at(pg._spot("lights")))
	await _frames(4)
	check(not pg.card.visible, "a question mark opens no card")
	Cap.save(root, "res://tests/out/berth_page_unseen_zh.png")
	# the main line and the guide: go and look first
	check(Mainline._repair_step("lights").text.contains("先飞去看"), "main line: go and look first (%s)" % Mainline._repair_step("lights").text)
	await _shut()
	g.guide.begin("repair", "lights")
	var st: Dictionary = g.guide._compute()
	check(st.get("target", Vector2.INF) == RepairShow.spot("lights"), "the guide points at the lamp (%s)" % str(st.get("title", "")))
	g.guide.stop()
	# fly up to the lamp
	var spot := RepairShow.spot("lights")
	for i in 40:
		g.drone.global_position = spot + Vector2(0, 3.0 * Geom.M)
		g.drone.linear_velocity = Vector2.ZERO
		await _frames(1)
	check(Repair.found("lights"), "within 8 m: found")
	check(g.get_children().any(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("fault_callout.gd")), "framed with one line")
	g.cam_override = spot
	await _frames(8)
	Cap.save(root, "res://tests/out/berth_fault_found_zh.png")
	g.cam_override = null
	check(Mainline._repair_step("lights").text.contains("还需要") or Mainline._repair_step("lights").text.contains("去修"), "main line: now what it takes (%s)" % Mainline._repair_step("lights").text)
	check(Repair.open_items().any(func(o): return str(o.id) == "lights"), "found: suggested")
	# the found fault's card
	term = await _page()
	pg = term.repair_panel
	check(int(pg.head_counts[0]) == 1, "the status window: one logged (%s)" % str(pg.head_counts))
	pg._map_input(_click_at(pg._spot("lights")))
	await _frames(10)
	check(pg.card.visible and pg.selected == "lights", "a red mark opens its card")
	var keys: Array = pg.card.find_children("*", "Button", true, false).map(func(b): return str(b.text))
	check(keys.any(func(t): return t.begins_with(Txt.t("rp_fix_parts"))) and keys.any(func(t): return t.begins_with(Txt.t("rp_fix_cash"))), "the card: both ways to pay")
	check(Rect2(Vector2.ZERO, pg.size).encloses(Rect2(pg.card.position, pg.card.size)), "the card stays on the page")
	Cap.save(root, "res://tests/out/berth_page_card_zh.png")
	# a plan: its place framed, the card beside it; again closes it
	pg._toggle("buffer")
	await _frames(10)
	check(pg.card.visible and pg.selected == "buffer" and pg._place("buffer").size != Vector2.ZERO, "a plan card: its place framed, its card shown")
	Cap.save(root, "res://tests/out/berth_page_plan_zh.png")
	pg._toggle("buffer")
	await _frames(4)
	check(not pg.card.visible and pg.selected == "", "pressed again: closed, nothing framed")
	pg._toggle("gas_line")
	await _frames(10)
	check(pg.card.visible and pg._place("gas_line").size == Vector2.ZERO, "a plan with no place: its card, no frame")
	await _shut()
	# the parts rack under the terminal
	check(Consoles.rack_on(), "the rack is in the berth while the cargo district is broken")
	for i in 6:
		g.drone.global_position = Consoles.rack_centre()
		g.drone.linear_velocity = Vector2.ZERO
		await _frames(1)
	check(g.consoles.near() == "rack", "at the rack: E opens it")
	g.open_parts_rack()
	await _frames(20)
	check(g.console_ui != null and g.console_ui.get_script().resource_path.ends_with("parts_rack_panel.gd"), "the rack's own panel")
	Cap.save(root, "res://tests/out/berth_parts_rack_zh.png")
	g.console_ui.close()
	await _frames(4)
	var port: Dictionary = Career.data.get("port", {})
	port["cargo"] = 1
	Career.data.port = port
	# 128 号: with the warehouse (StoreBook.ON) the rack is its counter and stays, mended or not
	if StoreBook.ON:
		check(Consoles.rack_on(), "the cargo district mended: the rack stays (the warehouse counter, 128 号)")
	else:
		check(not Consoles.rack_on(), "the cargo district mended: the berth rack is gone")
	g.open_shelf("A")
	await _frames(10)
	check(g.console_ui != null and g.console_ui.find_child("PartsRack", true, false) != null, "and its left racks hold the parts")
	g.console_ui.close()
	await _frames(4)
	port["cargo"] = 0
	# the drone's upgrades on the loadout page
	term = await _page()
	var lp := LoadoutPanel.open(term, func(): pass, func(): pass)
	await _frames(10)
	# the drone's own upgrades moved to the terminal's drone page (the loadout leaves them out)
	check(lp.find_child("Fitted_scan_kit", true, false) == null and term.SHOP.slice(0, term.DRONE_UPGRADES).any(func(it): return it[0] == "scan_kit"), "the drone's upgrades are sold on the drone page, not the loadout")
	lp.queue_free()
	await _shut()
	# an old career (its first ship stripped) knew the faults already
	Career.data.erase("faults_found")
	Career.data.history = [{"id": "TUG-001"}]
	Repair.migrate()
	check(Repair.found("net_fix") and Repair.found("furnace_main"), "an old career: all three known")
	g.queue_free()
	await _frames(4)
	print("BERTH PAGE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)


func _click_at(p: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = p
	return ev
