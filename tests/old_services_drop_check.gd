extends "res://tests/guide_check.gd"
# 128 号 第 6 段 (user 2026-11-07): the third-party storage (depot.gd) and the tug charters
# (charter.gd) are deleted, code and all. An old save that still holds them — offers, a lot on a
# client row with crates on the counter, a forklift job for it, a tug out on a charter — loads
# without an error: both are dropped, the tug is home, the client row is sundries again, the
# forklift job is gone, and the berth with the tug and cargo consoles runs. Own test saves only.
#   tools/run_test.sh tests/old_services_drop_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_oldsvc_career.json"
	SaveGame.path = "user://zp_test_oldsvc_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _old_save() -> Dictionary:
	var d := Career.fresh()
	d.seed = 20261107
	d.market = true
	d.money = 120000.0
	d.certified = true
	d.prologue_done = true
	d.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1, "tug": 1}
	d.seen = {"belt_prelude": true, "first_ship": true, "intro": true}
	d.drill = {"granted": true, "done": true}
	# what depot.gd kept (77 号 / 85 号)
	d.depot = {"offers": [{"id": "DP-004", "client": "天衡物流", "key": "steel_billet:1", "t": 8.0, "periods": 3, "fee": 400.0, "handling": 150.0, "age": 20.0}],
		"lots": [{"id": "DP-003", "client": "恒岳工业", "key": "steel_plate:1", "t": 10.0, "row": 7, "fee": 350.0, "handling": 120.0, "left": 2, "state": "dock",
			"crates": [{"t": 5.0, "at": "dock"}, {"t": 5.0, "at": "B4"}]}],
		"t": 120.0, "n": 4, "auto": {"on": true, "min_fee": 300.0, "keep_free": 0.0, "max_lots": 3, "stop_new": false, "fork": false}, "earned": 1400.0, "spent": 90.0}
	# what charter.gd kept: TG-1 is out on a job
	d.charter = {"offers": [{"id": "CH-007", "client": "远岫工场", "from": 2, "to": 0, "t": 12.0, "dv": 1.4, "fee": 8000.0, "secs": 90.0, "age": 30.0}],
		"jobs": [{"id": "CH-006", "tug": "TG-1", "left": 44.0, "secs": 90.0, "fee": 7000.0}],
		"t": 60.0, "n": 7, "wear": {"TG-1": 2}, "service": {"TG-1": 12.0},
		"auto": {"on": true, "min_net": 2000.0, "keep_one": true, "max_jobs": 1, "stop_new": false}, "earned": 21000.0, "spent": 6000.0}
	d.tug_last = {"TG-1": "charter"}
	d.tug_charge = {"TG-1": 0.2}
	d.wh = {"rows": ["ingot", "ingot", "scrap", "nonferrous", "billet", "stock", "parts", "client"],
		"jobs": [{"id": "DEPOT-IN:DP-003", "key": "steel_plate:1", "qty": 5.0, "row": 7, "dir": "in", "left": 6.0, "total": 8.0}], "done": []}
	return d


func _run() -> void:
	Txt.zh = true
	# the old save on disk, then a load the way the game loads it
	check(SaveGame.write_file(Career.path, _old_save()), "the old save is written to its own test file")
	Career.data = {}
	Career.load_or_new()
	check(not Career.data.is_empty() and float(Career.data.money) == 120000.0, "it loads (money kept: %s)" % Pal.money(float(Career.data.get("money", 0.0))))
	check(not Career.data.has("depot"), "the third-party storage is dropped")
	check(not Career.data.has("charter"), "the tug charters are dropped")
	check(str(Career.data.get("tug_last", {}).get("TG-1", "")) == "own", "TG-1 is no longer out on a charter")
	check(not Career.data.wh.rows.has("client") and str(Career.data.wh.rows[7]) == "misc", "the clients' row is sundries again")
	check(Career.data.wh.jobs.is_empty(), "the forklift job for a client's goods is gone")
	check(not "client" in Warehouse.USES, "no row can be given to clients' goods any more")
	# it saves and reads back without them
	Career.save()
	var back := SaveGame.read_career(Career.path)
	check(not back.has("depot") and not back.has("charter"), "saved again, neither comes back")
	# the berth runs with it: the tug and cargo consoles, a minute of the port's clock
	await _spawn()
	await _frames(30)
	check(TugFleet.count() < 1 or TugFleet.home(0), "TG-1 is home in the port")
	for z in ["tug", "cargo"]:
		g.drone.global_position = PortStructure.console_spot(z)
		await _frames(10)
		g.open_district(z)
		await _frames(20)
		var tx := _texts(g.console_ui) if g.console_ui != null else ""
		check(g.console_ui != null and not tx.contains("拖船外运") and not tx.contains("第三方仓储") and not tx.contains("接这单"), "the %s console opens, without either service" % z)
		if g.console_ui != null:
			g.console_ui.close()
		await _frames(4)
	g.drone.global_position = preload("res://scripts/cargo_floor.gd").mouth("A")
	await _frames(10)
	check(g.cargo_floor != null and g.cargo_floor.use(), "the rack mouth still opens the stores")
	await _frames(10)
	if g.has_method("close_counter"):
		g.close_counter()
	await _frames(120)
	check(not Career.data.has("depot") and not Career.data.has("charter"), "two seconds of play later, neither has come back")
	g.queue_free()
	await _frames(4)
	print("OLD SERVICES DROP %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()


func _texts(n: Node) -> String:
	var out := ""
	if n is Label or n is Button or n is RichTextLabel:
		out += str(n.text) + "\n"
	for c in n.get_children():
		out += _texts(c)
	return out
