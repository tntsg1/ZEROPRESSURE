extends SceneTree
# Growth desk: route model compatibility, real mouse/keyboard purchases,
# disk persistence, save rollback, facility locks, ship pagination and screenshots.
# Uses a dedicated test career and a non-focusing window; no player save is touched.

const Cap = preload("res://tests/cap.gd")
var fails := 0
var term


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Career.path = "user://zp_test_route_career.json"
	for ext in ["", ".bak", ".tmp", ".old"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.path + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _career() -> void:
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.market = true
	Career.data.done = 4
	Career.data.money = 41250.0
	Career.data.loan = 36000.0
	Career.data.in_debt = true
	Career.data.rep = 7
	Career.data.seen = {"market": true}
	Career.data.port["power"] = 1 # Supply is present; these cases isolate cash/prerequisite gates.
	Career.data.upgrades = {"scan_kit": true, "net05": true, "hauler": true, "lights": 1, "net_fix": 1, "furnace_main": 1}   # the base repairs made: port2 needs the lighting (G2)
	Career.data.history = [{"id": "TUG-001", "ship": "tug"}, {"id": "S09-001", "ship": "s09"}, {"id": "GR-001", "ship": "gr7"}, {"id": "M-1", "ship": "gr7"}]
	Career.save()


func _keys(ns: Array) -> Array:
	return ns.map(func(n): return n.key)


func _run() -> void:
	_career()
	# ---------------------------------------------------------------- the model
	var ns := Route.nodes()
	var ships := ns.filter(func(n): return n.kind == "ship").map(func(n): return n.id)
	# the eight older ships in the order the career has always met them; every ship by reputation
	var old := ["tug", "s09", "gr7", "pod", "h22", "m14", "med47", "fr26"]
	var reps: Array = ships.map(func(id): return int(Market.POOL.filter(func(e): return e[0] == id)[0][2]))
	var rising := true
	for i in range(1, reps.size()):
		if reps[i] < reps[i - 1]:
			rising = false
	check(ships.filter(func(id): return id in old) == old and rising and ships.size() == Market.POOL.size(), "ships in the order a career meets them: %s" % [ships])
	var m14 := Route.find("ship:m14")
	check(not m14.done and Route.missing(m14) == "还差 1 点声望 · 船坞要扩大才放得下", "M-14 one reputation point short: %s" % Route.missing(m14))
	var med := Route.find("ship:med47")
	check(med.conds.size() == 3 and not med.conds[1].ok, "MED-47 needs reputation, the berth extension and the market")
	check(m14.conds.size() == 3 and not m14.conds[1].ok, "M-14 (58 m) needs the berth extension too")
	check(Route.find("ship:gr7").done and int(Route.find("ship:gr7").stripped) == 2, "the Heron open, stripped twice")
	check(Route.find("buy:hauler").done and not Route.find("buy:hauler2").ready and Route.missing(Route.find("buy:hauler2")).contains("$18,750"), "second hauler: first one owned, money short")
	var buys := ns.filter(func(n): return n.kind == "buy")
	check(buys.size() == Route.buys().size() and Repair.BASE.all(func(id): return buys.any(func(n): return n.id == id)), "all %d upgrades and repairs include selectable base prerequisites" % buys.size())
	# ---------------------------------------------------------------- pins
	check(Route.pins().is_empty(), "nothing pinned on a fresh career")
	var auto := Route.goals()
	check(auto.size() == 2 and not auto[0].pinned and not auto[0].ready, "two automatic goals, still to earn first: %s" % [_keys(auto)])
	check(Route.toggle("ship:m14") and Route.toggle("buy:hauler2"), "pin M-14 and the second hauler")
	check(Route.pins() == ["ship:m14", "buy:hauler2"], "two pins in order")
	check(not Route.pins().any(func(k): return str(k).begins_with("skill:")), "no skill goals since the skill book was withdrawn (G3)")
	Route.toggle("ship:m14")
	var disk := FileAccess.get_file_as_string(Career.path)
	check(disk.contains("buy:hauler2") and not disk.contains("ship:m14"), "pins saved to the career file (M-14 unpinned again)")
	# a goal reached drops out and the slot falls back to the closest
	Career.data.rep = 8
	Career.data.upgrades.berth88 = true
	var gs := Route.goals()
	check(gs.size() == 2 and gs[0].key == "buy:hauler2" and not gs[1].pinned, "M-14 reached: it leaves the goals, an automatic one fills in: %s" % [_keys(gs)])
	Career.data.rep = 7
	Career.data.upgrades.erase("berth88")
	# ---------------------------------------------------------------- the new growth desk
	Career.data.money = 278484.0
	Career.data.rep = 9
	term = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	await _frames(40)
	term.set_tab(5)
	await _frames(30)
	var desk = term.route_panel
	check(desk.visible and desk.cards.size() == desk.PAGE_SIZE, "growth desk opens on the berth repairs, a page of %d" % desk.PAGE_SIZE)
	# the techniques category (G3): the achievements, nothing to buy
	desk.select_key("feat:section")
	await _frames(3)
	check(desk.category == 3 and desk.chosen().key == "feat:section" and desk.action_button == null, "the techniques category lists the achievements with nothing to buy")
	await _frames(30)
	Cap.save(root, "res://tests/out/route_growth_zh.png")
	# Buy from the same page, and enforce both prerequisites and funds.
	# the second equipment mouth draws on the port's grid (G6): the power district first
	Career.data.port["power"] = 1
	desk.select_key("buy:port2")
	await _frames(4)
	var money := float(Career.data.money)
	await _click(desk.action_button)
	# 65 号: the click pays and starts the crew; the facility is the berth's when built
	check(Works.busy() and str(Works.current().id) == "port2" and float(Career.data.money) == money - 50000.0 and desk.action_button.disabled, "real click pays and starts the crew without leaving growth; no second order meanwhile")
	Works.finish()
	desk.refresh()
	await _frames(3)
	check(Career.data.upgrades.has("port2") and desk.action_button.disabled, "built: the berth's, and it cannot be charged twice")
	desk.select_key("buy:berth120")
	await _frames(3)
	check(desk.action_button.disabled, "missing earlier extension blocks construction")
	# Save failures must not keep the charge or install a facility.
	desk.select_key("buy:buffer")
	await _frames(3)
	money = float(Career.data.money)
	var valid_path := Career.path
	Career.path = "user://route_missing_directory/career.json"
	desk.purchase()
	check(not Career.data.upgrades.has("buffer") and float(Career.data.money) == money, "failed facility persistence rolls back money and ownership")
	Career.path = valid_path
	desk.select_key("buy:hauler2")
	await _frames(20)
	Cap.save(root, "res://tests/out/route_build_zh.png")
	# All ships are reachable through pages with disjoint card rectangles.
	desk.select_category(2)
	var reached := {}
	for p in ceili(float(Market.POOL.size()) / desk.PAGE_SIZE):
		await _frames(3)
		check(desk.cards.size() <= 6, "ship page %d has at most six cards" % (p + 1))
		for i in desk.cards.size():
			var r: Rect2 = desk.cards[i].get_global_rect()
			check(desk.get_global_rect().encloses(r), "card stays within growth desk")
			for j in range(i + 1, desk.cards.size()):
				check(not r.intersects(desk.cards[j].get_global_rect()), "ship cards do not overlap")
			reached[desk.entries[p * desk.PAGE_SIZE + i].key] = true
		if not desk.following.disabled:
			await _click(desk.following)
	check(reached.size() == Market.POOL.size(), "every ship reachable through real pagination clicks")
	desk.select_key("ship:m14")
	await _frames(3)
	var prerequisite_buttons: Array = desk.detail.get_children().filter(func(n): return n is Button and n.text == "查看前置建设")
	check(prerequisite_buttons.size() == 1, "locked ship links to its required extension")
	if not prerequisite_buttons.is_empty():
		await _click(prerequisite_buttons[0])
		check(desk.chosen().key == "buy:berth88", "required construction opens directly inside growth desk")
	desk.select_key("ship:ark01")
	await _frames(20)
	Cap.save(root, "res://tests/out/route_ships_zh.png")
	term.set_tab(-1)
	# the main line takes the strip's first place (28 号); the career goals follow
	term._open_goal(1 if Mainline.chapter() != "" else 0)
	check(term.tab == 5 and desk.chosen().key == Route.goals()[0].key, "header goals open the corresponding actionable detail")
	# On-site skills work, permanent construction retains the between-job rule.
	term.overlay = true
	term.between = false
	desk.select_key("buy:buffer")
	await _frames(3)
	check(desk.action_button.disabled, "on-site construction remains locked")
	money = float(Career.data.money)
	desk.purchase()
	check(float(Career.data.money) == money and not Career.data.upgrades.has("buffer"), "on-site purchase cannot bypass the existing lock")
	term.overlay = false
	Txt.zh = false
	desk.refresh()
	desk.select_key("buy:pump2")
	await _frames(20)
	Cap.save(root, "res://tests/out/route_growth_en.png")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	desk.select_category(2)
	await _frames(20)
	Cap.save(root, "res://tests/out/route_ships_1280.png")
	check(desk.get_global_rect().encloses(desk.detail_scroll.get_global_rect()), "detail panel stays within resized viewport")
	Txt.zh = true
	print("ROUTE %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(0 if fails == 0 else 1)


func _click(button: Button) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await _frames(4)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await _frames(4)
