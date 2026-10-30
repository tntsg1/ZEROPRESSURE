extends SceneTree
# Reproduce the player's affordable-but-blocked net and missing pump target.
const Cap = preload("res://tests/cap.gd")
var failures := 0
var term: Node

func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Career.path = "user://zp_test_construction_targets.json"
	SaveGame.path = "user://zp_test_construction_targets_job.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run()

func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok:
		failures += 1

func frames(n: int = 4) -> void:
	for i in n:
		await process_frame

func click(button: Button) -> void:
	await click_at(button.get_global_rect().get_center())

func click_at(at: Vector2) -> void:
	term.pointer_override = at
	await frames(2)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await frames()

func fixture() -> void:
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.market = true
	Career.data.money = 20940.0
	Career.data.loan = 0.0
	Career.data.rep = 3
	Career.data.upgrades = {"hauler": 1}
	Career.data.structure_t = 9.0
	Career.data.parts = []
	Career.data.seen = {"market": true, "market_liang": true, "level": "trainee"}
	Career.data.port = {"power": 0, "trade": 0, "salvage": 0, "process": 0}

func _run() -> void:
	fixture()
	var mismatches: Array = []
	# Cover the same source of truth for every repair, with/without stock and power.
	for money in [1000.0, 20940.0, 10000000.0]:
		for stock in [0.0, 500.0]:
			for power in [0, 1]:
				Career.data.money = money
				Career.data.structure_t = stock
				Career.data.port.power = power
				for repair in Repair.ITEMS:
					var node := Route.find("buy:" + str(repair[0]))
					var expected := Repair.reason(str(repair[0]), Repair.parts_for(str(repair[0])).ok)
					if node.is_empty() or bool(node.ready) != (expected == "") or (not node.done and expected != "" and Route.missing(node) != expected):
						mismatches.append(str(repair[0]))
	check(mismatches.is_empty(), "all repair cards agree with actual construction rules across cash, stock and power: " + str(mismatches))
	fixture()
	Career.save()
	term = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	await frames(40)
	term.set_tab(5)
	var desk = term.route_panel
	desk.select_key("buy:net05")
	await frames(25)
	check(not desk.chosen().ready and desk.action_button.disabled, "net upgrade cannot show BUILD when the basic net is broken")
	check(Route.missing(desk.chosen()).contains(Repair.name_of("net_fix")), "blocked card names the missing basic net")
	Cap.save(root, "res://tests/out/construction_net_blocked.png")
	var links: Array = desk.detail.get_children().filter(func(node): return node is Button and node.text.begins_with("查看前置建设") and node.text.contains(Repair.name_of("net_fix")))
	check(links.size() == 1, "the missing prerequisite has a direct construction link")
	if not links.is_empty():
		await click(links[0])
	check(desk.chosen().key == "buy:net_fix" and not desk.action_button.disabled, "prerequisite link selects the actual basic net repair")
	# 65 号: a repair is built on site, not bought: the order takes its money (a quarter of the
	# crew's price when the berth's own parts and structure go in, 74 号) and the crew works on;
	# the facility is the berth's only when the job is done
	var m0 := float(Career.data.money)
	var price := float(desk.chosen().price)
	await click(desk.action_button)
	check(Works.busy() and str(Works.current().id) == "net_fix" and not Repair.done("net_fix") and is_equal_approx(float(Career.data.money), m0 - price),
		"BUILD orders the basic net: %s taken, the crew at work, not yet the berth's" % Pal.money(price))
	Works.advance(float(Works.current().left) + 1.0)
	check(Repair.done("net_fix") and not Works.busy(), "the crew's time run out: the basic net is built")
	desk.select_key("buy:net05")
	await frames()
	price = float(desk.chosen().price)
	check(desk.chosen().ready and not desk.action_button.disabled and price > 0.0 and price <= Repair.price("net05", false), "net upgrade becomes available at the actual price (%s)" % Pal.money(price))
	m0 = float(Career.data.money)
	await click(desk.action_button)
	Works.advance(float(Works.current().get("left", 0.0)) + 1.0)
	check(Repair.done("net05") and is_equal_approx(float(Career.data.money), m0 - price), "real BUILD click builds the upgraded net and deducts exactly %s" % Pal.money(price))
	desk.refresh()
	await frames()
	check(desk.action_button.disabled, "completed construction blocks repeat charges")
	var disk := SaveGame.read_career(Career.path)
	check(int(disk.upgrades.get("net05", 0)) == 1 and is_equal_approx(float(disk.money), m0 - price), "net construction persists to disk")
	# Both dashboard and header must open the very pump they advertise.
	fixture()
	Career.data.route_goals = ["buy:pump2"]
	term._goals_t = -1.0
	term.set_tab(-1)
	await frames(25)
	var decisions: Array = Ops.decisions()
	var pump_rows := decisions.filter(func(row): return row.go == "route:buy:pump2")
	check(not pump_rows.is_empty() and str(pump_rows[0].title).contains("升级"), "dashboard labels the pump as an upgrade target")
	# the home screen lists only what has gone wrong now (Ops.problems); a target's row goes where
	# the dashboard's own link does
	if not pump_rows.is_empty():
		term.ops_go(str(pump_rows[0].go))
		await frames(4)
	check(term.tab == 5 and desk.chosen().key == "buy:pump2" and desk.category == 5, "dashboard target opens the exact pump in equipment upgrades")
	await frames(25)
	var pump_price := float(desk.chosen().price)
	var short := pump_price - float(Career.data.money)
	check(desk.action_button.disabled and Route.missing(desk.chosen()) == "还差 " + Pal.money(short), "20940 cash correctly shows the pump short by %s" % Pal.money(short))
	Cap.save(root, "res://tests/out/construction_pump_target.png")
	# the header's pinned targets show once the reputation page has been opened
	if Career.data.has("term_open") and not Career.data.term_open.has("rep"):
		if Career.data.term_open is Array:
			Career.data.term_open.append("rep")
		else:
			Career.data.term_open["rep"] = true
	term.set_tab(-1)
	term._goals_t = -1.0
	await frames(25)
	# the main line takes the header's first place when there is one (28 号 Q17)
	await click_at(term._goal_rect(1 if Mainline.chapter() != "" else 0).get_center())
	check(term.tab == 5 and desk.chosen().key == "buy:pump2", "header target also selects the exact pump")
	Career.data.money = pump_price
	desk.refresh()
	await frames()
	await click(desk.action_button)
	Works.advance(float(Works.current().get("left", 0.0)) + 1.0)
	check(int(Career.data.upgrades.get("pump2", 0)) == 1 and is_equal_approx(float(Career.data.money), 0.0), "real upgrade click builds the pump for %s" % Pal.money(pump_price))
	check(desk.action_button.disabled, "pump cannot be bought twice")
	disk = SaveGame.read_career(Career.path)
	check(int(disk.upgrades.get("pump2", 0)) == 1, "pump upgrade persists to disk")
	Txt.zh = false
	desk.select_key("buy:net05")
	await frames(20)
	Cap.save(root, "res://tests/out/construction_net_en.png")
	print("CONSTRUCTION TARGET %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
