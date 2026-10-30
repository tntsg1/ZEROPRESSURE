extends SceneTree
# The operations overview (design/成长版本/G5-G7_工业港成长重设计_2026-10-22/22_*): the
# terminal's home screen shows the port's four cells and what waits on the operator,
# read from the real career; its cells and rows lead to the right pages; the eight keys
# still open their pages; the empty berth's HUD carries the four-lamp strip; the
# native consoles wear the shared skin. Own test saves only.
#   godot --headless --path . --fixed-fps 60 -s tests/ops_overview_check.gd
#   tools/run_test.sh tests/ops_overview_check.gd --fixed-fps 60     (with pictures)
const Cap = preload("res://tests/cap.gd")
const Exchange = preload("res://scripts/industrial_exchange.gd")
var finished := false
var fails := 0
var passes := 0


func _initialize() -> void:
	# 68 号: this test reads the hulks the market drew by itself (before the star-map sweep)
	Scan.ON = false
	Career.path = "user://zp_test_ops_career.json"
	SaveGame.path = "user://zp_test_ops_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _process(_dt: float) -> bool:
	return finished


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
		print("PASS ", what)
	else:
		fails += 1
		print("FAIL ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _titles(decs: Array) -> String:
	return " | ".join(decs.map(func(d): return str(d.title)))


func _berth() -> Node:
	Game.start_ship = "berth"
	Game.contract = {}
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(6)
	return g


func _click(term: Node, at: Vector2) -> void:
	term.pointer_override = at
	await _frames(2)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	term._gui_input(ev)
	await _frames(2)


func _key(term: Node, code: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = true
	term._unhandled_input(ev)
	await _frames(2)


func _run() -> void:
	Txt.zh = true
	Career.data = {}
	Career.start_new()
	Career.data.market = true
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.money = 60000.0
	Career.data.port["trade"] = 1
	Career.data.port["salvage"] = 1
	Career.save()

	# 1. a fresh port: only the berth (51 号: a system's cell appears once it exists)
	var cells := Ops.cells()
	check(cells.size() == 1 and str(cells[0].id) == "berth", "a fresh port: only the berth's cell (%d)" % cells.size())
	# built up: all four
	Career.data.port["power"] = 1
	Career.data.port["process"] = 1
	Career.data.port["tug"] = 1
	cells = Ops.cells()
	check(cells.size() == 4 and cells.all(func(c): return str(c.value) != "" and not c.lines.is_empty()), "four cells, each with a figure and lines")
	check(str(cells[2].value) == "空闲", "no contract: the berth cell says empty (%s)" % cells[2].value)
	# 34 号: the grid cell reads the real bus — the base load on the district's own sets (70 号: 2 of 30 MW)
	check(str(cells[0].value) == "2.0 / 30 MW" and str(cells[0].lines).find("余量 28.0 MW") >= 0, "the grid cell reads the real bus (%s)" % cells[0].value)
	var decs := Ops.decisions()
	check(decs.any(func(d): return str(d.go).begins_with("route:")), "the next build goal is a decision (%s)" % _titles(decs))

	# 2. fixtures: a heat on with power owed, a client order short, a queued ship in, mixed metal in stock
	check(Exchange.command("view").ok, "the exchange opens on the test career")
	check(Exchange.command("customer_accept", {"offer_id": "PORT-STEEL-01"}).ok, "a client order accepted")
	var stock: Dictionary = Career.data.exchange.actors.company.stock
	stock["mixed_metal:0"] = 1.0
	stock["steel_billet:1"] = 0.4
	Career.data.industrial_heat = {"id": "HEAT-T1", "state": "processing", "quantity": 1.0, "energy_debt": 320.0, "energy_cost": 0.0}
	Career.ensure_offers(Market.make)
	var held: Dictionary = Career.data.offers[0].duplicate(true)
	held.held = true
	Career.data.offers.append(held)
	Career.data.money = 60000.0
	decs = Ops.decisions()
	print("  decisions: ", _titles(decs))
	check(not decs.is_empty() and int(decs[0].level) == Ops.DANGER and str(decs[0].title).find("电费") >= 0, "power owed comes first, as a danger")
	check(decs.any(func(d): return str(d.go) == "site:heat" and str(d.title).find("HEAT-T1") >= 0), "the heat waiting on the operator at the furnace")
	var gap: Array = decs.filter(func(d): return str(d.go) == "clients" and str(d.title).find("还差 1.00 t") >= 0)
	check(gap.size() == 1 and str(gap[0].why).find("0.40") >= 0, "the client gap names the shortfall and what is in stock")
	check(decs.any(func(d): return str(d.title).find("排队的大船") >= 0), "the queued big ship is in")
	check(decs.size() <= Ops.MAX_DECISIONS, "at most %d decisions" % Ops.MAX_DECISIONS)
	var levels: Array = decs.map(func(d): return int(d.level))
	var sorted := levels.duplicate()
	sorted.sort()
	check(levels == sorted, "worst first")
	cells = Ops.cells()
	check(str(cells[0].lines[0]).find("待缴") >= 0 and cells[0].lamp == "danger", "the grid cell shows the power owed, lamp red")
	check(str(cells[3].value) == "炉次进行中", "the production cell shows the heat on")
	Career.save()

	# 3. the home screen over the empty berth
	var g: Node = await _berth()
	await _frames(20)
	if DisplayServer.get_name() != "headless":
		# 61 号 (60 号 Q8): no status strip in the empty berth any more
		check(g.hud.ops_strip.is_empty(), "the empty berth's HUD draws no status strip (61 号)")
		Cap.save(root, "res://tests/out/ops_hud_zh.png")
	g.open_console("terminal")
	await _frames(8)
	var term: Node = g.console_ui
	check(term != null and term.tab == term.HOME, "B: the terminal opens on its home screen")
	term._skip_boot()
	await _frames(30)
	# 61 号: one "next" card, and only what is actually wrong
	var only_danger := true
	for d in term._ops_decs:
		only_danger = only_danger and int(d.level) == Ops.DANGER
	check(term._ops_cells.is_empty() and not term._ops_decs.is_empty() and only_danger and Mainline.step().get("text", "") != "", "the home shows the next step and only real problems (%d)" % term._ops_decs.size())
	for i in term.APPS.size():
		var r: Rect2 = term._tile_rect(i)
		check(Rect2(Vector2.ZERO, term.size).encloses(r) and not r.intersects(term._decs_box()) and not r.intersects(term._cell_rect(0)), "key %d sits in its row, clear of the overview" % (i + 1))
	Cap.save(root, "res://tests/out/ops_home_zh.png")
	# 61 号: the next-step card's "take me" sits on screen, clear of the keys
	var nr: Rect2 = term._next_go_rect()
	check(Rect2(Vector2.ZERO, term.size).encloses(nr) and not nr.intersects(term._tile_rect(0)), "the next step's take-me button is on screen")
	term.set_tab(term.HOME)
	await _frames(20)
	# a site decision says where, it does not open a page
	var site := -1
	for i in term._ops_decs.size():
		if str(term._ops_decs[i].go) == "site:heat":
			site = i
	check(site >= 0, "the heat decision is on the home screen")
	if site >= 0:
		await _click(term, term._dec_rect(site).get_center())
		# 27 号: a site decision starts the on-site guide and closes the terminal
		check(g.console_ui == null and g.guide.task == "heat", "a site decision starts the heat guide on site")
		g.guide.stop()
		g.open_console("terminal")
		await _frames(6)
		g.console_ui._skip_boot()
		await _frames(10)
		term = g.console_ui
	# the keys still open their pages
	# 53 号: four keys left — contracts, berth, growth, training; 5–8 do nothing
	check(term.APPS.size() == 4, "the home row has four keys (radio, ledger, supplies, tools gone)")
	await _key(term, KEY_3)
	check(term.tab == 5, "key 3 opens growth and construction")
	term.set_tab(term.HOME)
	await _frames(4)
	await _key(term, KEY_6)
	check(term.tab == term.HOME, "key 6 does nothing")
	term.set_tab(term.HOME)
	await _frames(4)
	await _key(term, KEY_2)
	check(term.tab == 1, "key 2 opens the berth repairs")
	term.set_tab(term.HOME)
	await _frames(4)
	# the clients' page of the exchange (61 号: no longer a home row; opened as a step's "take me" would)
	var gi := 0
	if gi >= 0:
		term.ops_go("clients")
		await _frames(6)
		var ex = g.console_ui
		check(ex != null and ex.get_script() == preload("res://scripts/exchange_panel.gd") and str(ex.tab) == "sell", "the client gap opens the exchange on selling (45 号: the clients are its bids)")
		check(ex != null and ex.theme != null and ex.theme.has_stylebox("panel", "PanelContainer"), "the exchange wears the new skin (50 号)")
		if ex != null and ex.has_method("close_guide"):
			ex.close_guide()
		await _frames(10)
		Cap.save(root, "res://tests/out/ops_exchange_zh.png")
		if ex != null:
			ex.close()
		await _frames(4)
	else:
		check(false, "the client gap is on the home screen")
	if g.console_ui != null:
		g.console_ui.close()
	await _frames(4)

	# 4. 1280 × 720: everything still on screen
	root.content_scale_size = Vector2i(1280, 720)
	await _frames(4)
	g.open_console("terminal")
	await _frames(6)
	term = g.console_ui
	term._skip_boot()
	await _frames(30)
	var inside := true
	for i in term.APPS.size():
		inside = inside and Rect2(Vector2.ZERO, term.size).encloses(term._tile_rect(i))
	for i in term._ops_decs.size():
		inside = inside and term._decs_box().encloses(term._dec_rect(i)) and not term._dec_rect(i).intersects(term._tile_rect(0))
	check(inside, "1280 × 720: cells, decisions and keys all fit (%s)" % str(term.size))
	Cap.save(root, "res://tests/out/ops_home_1280_zh.png")
	term.close()
	await _frames(4)
	root.content_scale_size = Vector2i(1920, 1080)
	await _frames(4)

	# 5. the native consoles share the skin; the ring's console shows the cells
	g.open_district("ring")
	await _frames(10)
	var ring = g.console_ui
	check(ring != null and ring.find_children("*", "", true, false).any(func(n): return n.get_script() != null and n.get("cells") != null), "the ring's business console draws the overview")
	check(ring != null and ring.theme != null and ring.theme.has_stylebox("tab_selected", "TabContainer"), "the district console wears the shared skin")
	Cap.save(root, "res://tests/out/ops_ring_zh.png")
	if ring != null:
		ring.close()
	await _frames(4)
	g.open_transit("tram", "power")
	await _frames(6)
	check(g.console_ui != null and g.console_ui.theme.has_stylebox("tab_selected", "TabContainer"), "the destination list wears the shared skin")
	if g.console_ui != null:
		g.console_ui.close()
	await _frames(4)
	g.queue_free()
	await _frames(4)
	print("ops_overview_check: %d passed, %d failed" % [passes, fails])
	print("OPS_OVERVIEW " + ("PASS" if fails == 0 else "FAIL"))
	finished = true
