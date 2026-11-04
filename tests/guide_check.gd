extends SceneTree
# 27 号: the on-site guide. A decision clicked on the terminal's home screen closes the terminal
# and starts its task; each step follows the real state (where the drone is, the open panel, the
# batch, the furnace); the button to press is lit; the read-out plates step back; a finished
# task chains to the next. Own test saves only.
#   tools/run_test.sh tests/guide_check.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")
const Exchange = preload("res://scripts/industrial_exchange.gd")
const GuideCopy = preload("res://scripts/onboarding_text.gd")
var g: Node
var fails := 0
var checks := 0


func _initialize() -> void:
	Career.path = "user://zp_test_guide_career.json"
	SaveGame.path = "user://zp_test_guide_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _spawn() -> void:
	Game.start_ship = "berth"
	Game.contract = {}
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(10)
	g.tutorial = null


func _lit(prefix: String) -> bool:
	if g.console_ui == null:
		return false
	for b in g.console_ui.find_children("*", "Button", true, false):
		if str(b.text).begins_with(prefix) and b.has_meta("guide_lit"):
			return true
	return false


func _press(prefix: String) -> bool:
	for b in g.console_ui.find_children("*", "Button", true, false):
		if str(b.text).begins_with(prefix) and not b.disabled:
			b.pressed.emit()
			return true
	return false


func _title() -> String:
	return str(g.guide.step.get("title", ""))


func _until(cond: Callable, limit: int) -> bool:
	for i in limit:
		await _frames(1)
		if cond.call():
			return true
	return false


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.market = true
	Career.data.money = 100000.0
	Career.data.port = {"trade": 1, "process": 1, "power": 1}
	Career.save()
	await _spawn()
	# 2 t of own keel scrap in the warehouse (as a retained receipt would leave it)
	check(Exchange.command("view").ok, "the exchange opens")
	var actor: Dictionary = Career.data.exchange.actors.company
	actor.lots["G-KEEL"] = {"id": "G-KEEL", "key": "mixed_metal:0", "available": 2.0, "total": 2.0, "origin": "receiver", "material_profile": {"version": 1, "nonmagnetic_share": 0.03, "basis": "ship_structure_keel"}}
	actor.stock["mixed_metal:0"] = 2.0
	Career.save()

	# 1. the decision on the home screen starts the guide
	g.open_console("terminal")
	await _frames(6)
	var term = g.console_ui
	term._skip_boot()
	await _frames(30)
	# 61 号: the home no longer lists chances; the same "site:sort" go, as a next step's "take me" sends it
	check(Ops.decisions(g).any(func(d): return str(d.go) == "site:sort"), "the unsorted metal is still known to the port's books")
	term.ops_go("site:sort")
	await _frames(10)
	check(g.console_ui == null and g.guide.task == "sort", "taking it closes the terminal and starts the sorting guide")
	check(_title().begins_with("飞到分选台") and g.guide.step.target == g.industrial_sort.site(), "step one: fly to the sorting desk (%s)" % _title())
	check(Guide.quiet, "the read-out plates step back while it runs")
	Cap.save(root, "res://tests/out/guide_arrow_zh.png")

	# 2. at the desk, the panel, the lit button
	g.drone.global_position = g.industrial_sort.site()
	g.drone.freeze = true
	await _frames(20)
	check(_title().begins_with("按 E"), "at the desk: press E (%s)" % _title())
	g.open_sort()
	await _frames(20)
	check(_title().find("整线加工") >= 0 and _lit("整线加工"), "the panel open: run the line, and that button is lit (%s)" % _title())
	Cap.save(root, "res://tests/out/guide_sort_panel_zh.png")
	g.console_ui.quantity.value = 2.0
	check(_press(GuideCopy.text("sort.send_feed")), "feed sent")
	check(await _until(func(): return str(Career.data.get("industrial_sort", {}).get("state", "")) == "processing", 16000), "the feed reaches the line")
	await _frames(20)
	check(_title().find("启动分选驱动") >= 0 and _lit("启动分选驱动"), "next: start the drives, lit (%s)" % _title())
	check(_press("启动分选驱动"), "drives started")
	await _frames(20)
	check(_title().find("磁选进行中") >= 0, "then it says the line is running (%s)" % _title())
	check(await _until(func(): return g.guide.task == "assay", 30000), "sorted: the guide moves on to the assay by itself")
	check(str(g.guide.note).find("接着：化验") >= 0, "and says why (%s)" % g.guide.note)
	g.console_ui.close()
	await _frames(20)
	check(_title().begins_with("飞到化验位") and str(g.guide.step.purpose).find("和旁边的熔炉无关") >= 0, "assay step one names the bench and what it is for")

	# 3. the furnace's steps follow the furnace (a fixture of its state, not a whole heat)
	g.guide.begin("heat")
	# a fixture heat: the meter already paid up, so the fixture bills nothing
	Career.data.industrial_heat = {"id": "HEAT-FIX", "state": "processing", "quantity": 1.0, "electric_paid_j": 1.0e30, "energy_cost": 0.0, "energy_debt": 0.0, "transport": {}, "source_lots": []}
	var f = g.plant.smelter
	var keep := {"manual_power": f.manual_power, "bunker": f.bunker, "manual_feed": f.manual_feed, "m_s": f.m_s, "m_l": f.m_l, "T": f.T, "sample_count": f.sample_count, "tc_age": f.tc_age, "dip": f.dip, "lance_phase": f.lance_phase, "phase": f.phase}
	f.phase = "melt"
	f.manual_power = 0.0
	f.bunker = 1.0
	f.manual_feed = false
	g.drone.global_position = g.industrial_heat.site()
	await _frames(20)
	g.open_heat()
	await _frames(12)
	check(_title().find("通电熔化") >= 0 and _lit(GuideCopy.text("heat.melt")), "power off, feed waiting: one press, lit (%s)" % _title())
	f.manual_power = 1.0
	Career.data.industrial_heat.auto = true
	f.manual_feed = true
	f.bunker = 0.0
	f.m_s = 0.4
	f.T = 1500.0
	await _frames(12)
	check(_title().find("加热熔化中") >= 0 and str(g.guide.step.text).find("1710") >= 0, "melting: the temperature and the limit (%s)" % _title())
	f.m_s = 0.0
	f.m_l = 0.4                # 125 号: melted is a bath in the furnace (an empty one is cooling billets)
	f.T = 1660.0
	f.sample_count = 0
	await _frames(12)
	check(_title().find("测温取样") >= 0 and _lit("测温取样"), "melted: take a sample")
	f.sample_count = 1
	f.tc_age = 1.0
	f.dip = 0.0
	f.lance_phase = "idle"
	await _frames(12)
	check(_title().find("倾炉出钢") >= 0 and _lit("倾炉出钢"), "sampled: tilt and tap")
	Cap.save(root, "res://tests/out/guide_heat_zh.png")
	for k in keep:
		f.set(k, keep[k])
	Career.data.industrial_heat = {}
	g.console_ui.close()
	await _frames(4)

	# 4. a client's gap starts where the company's steel stands
	actor = Career.data.exchange.actors.company
	var save_stock: Dictionary = actor.stock.duplicate()
	actor.stock = {}
	for k in actor.lots.keys():
		actor.lots[k].available = 0.0
	check(Guide.first_for_clients() == "buy_feed", "nothing of our own: buy feed first")
	actor.stock["ferrous_scrap:1"] = 1.0
	check(Guide.first_for_clients() == "heat", "grade 1 feed in stock: the furnace")
	actor.stock["steel_billet:1"] = 1.0
	check(Guide.first_for_clients() == "clients", "billets in stock: ship them")
	actor.stock = save_stock
	g.guide.begin("buy_feed")
	actor.stock["ferrous_scrap:1"] = 0.0
	await _frames(12)
	check(str(g.guide.step.get("action", "")) == "feed", "buying feed: the card offers to open the exchange")
	g.guide.act()
	await _frames(10)
	check(g.console_ui != null and g.console_ui.get_script() == preload("res://scripts/exchange_panel.gd") and g.console_ui.item == "ferrous_scrap" and g.console_ui.grade == 1, "it opens on grade 1 ferrous feed")
	if g.console_ui != null and g.console_ui.has_method("close_guide"):
		g.console_ui.close_guide()
	await _frames(15)
	check(_lit("购买"), "the sellers' buy buttons are lit")
	Cap.save(root, "res://tests/out/guide_buy_zh.png")
	g.console_ui.close()
	await _frames(4)

	# 5. it survives the scene; the end key clears it
	check(str(SaveGame.read_career(Career.path).get("guide_task", "")) == "buy_feed", "the task is on the career")
	var g2 := Guide.new()
	root.add_child(g2)
	check(g2.task == "buy_feed", "a new berth scene picks it up")
	g2.queue_free()
	g.guide.stop()
	await _frames(4)
	check(not g.guide.active() and not Guide.quiet and not Career.data.has("guide_task"), "ending it clears the task and brings the plates back")
	g.queue_free()
	await _frames(4)
	print("GUIDE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
