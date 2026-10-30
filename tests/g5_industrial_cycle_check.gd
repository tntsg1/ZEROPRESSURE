extends SceneTree
# Declared restored industrial district and operator initially at its panel.
# Real merchant purchase, native collision/transport/receivers, existing furnace,
# real warehouse inventory and customer payment. No direct load placement/deletion.
const Exchange = preload("res://scripts/industrial_exchange.gd")
var g: Node
var checks := 0
var fails := 0
var max_step := 0.0
var last_key := ""
var last_at := Vector2.INF
var bad_heat := false
func _initialize() -> void:
	# 73 号: this test is about the physical feed and delivery runs, not the racks: goods leave at once
	Warehouse.ON = false
	# 64 号: this checks the older feed chain (bought / kept scrap, sorting); kept in code, switched off in play
	Career.INGOTS = false
	preload("res://scripts/industrial_exchange.gd").INGOTS = false
	run.call_deferred()
func frames(n: int) -> void:
	for i in n:
		await process_frame
		if g != null and is_instance_valid(g.industrial_heat.body):
			var body = g.industrial_heat.body
			var key: String = str(body.pieces[0].key) if not body.pieces.is_empty() else ""
			if key == last_key and last_at.is_finite(): max_step = maxf(max_step,last_at.distance_to(body.global_position))
			last_key = key
			last_at = body.global_position
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
func press(text: String) -> bool:
	for node in g.console_ui.find_children("*","Button",true,false):
		if node.text == text:
			node.pressed.emit()
			return true
	return false
func spawn(restore: bool = false) -> void:
	Game.contract = {}
	Game.start_ship = "berth"
	SaveGame.load_requested = restore
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	await frames(8)
	g.tutorial = null
func release() -> void:
	g.queue_free()
	g = null
	await frames(5)
func heat() -> Dictionary: return Career.data.get("industrial_heat",{})
func await_state(target: String,limit: int) -> bool:
	for i in limit:
		await frames(1)
		if heat().get("state","") == target: return true
		if i%2400 == 2399:
			print("WAIT ",heat().get("state","")," -> ",target," reason=",g.industrial_heat.waiting," at=",g.industrial_heat.body.global_position if is_instance_valid(g.industrial_heat.body) else Vector2.INF," transport=",heat().get("transport",{}))
	return false
func run() -> void:
	bad_heat = OS.get_cmdline_user_args().has("--overheat")
	Career.path = "user://zp_test_g5_industrial_career.json"
	SaveGame.path = "user://zp_test_g5_industrial_field.json"
	SaveGame.allow_test = true
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.market = true
	Career.data.money = 100000.0
	Career.data.port = {"trade":1,"process":1,"power":1} # 34 号: the furnace needs the power district for its 24 MW
	await spawn()
	check(g.industrial_heat != null and g.in_berth(),"actual empty career berth owns the existing furnace production service")
	var result := Exchange.command("view")
	if not bad_heat:
		check(Exchange.command("customer_accept",{"offer_id":"PORT-STEEL-01"}).ok,"company accepts a finite funded ordinary customer demand before buying and producing its input")
	Exchange.command("view")
	_local_only()
	check(result.ok and Exchange.command("post",{"side":"buy","item":"ferrous_scrap","grade":1,"quantity":1.0,"price":500.0}).ok,"player buys a finite inspected ferrous feedstock consignment with actual funds")
	for i in 1600:
		await frames(1)
		if float(Career.data.exchange.actors.company.stock.get("ferrous_scrap:1",0.0)) >= 1.0: break
	check(float(Career.data.exchange.actors.company.stock.get("ferrous_scrap:1",0.0)) == 1.0,"actual local carrier physically warehouses the purchased feed before it can be reserved")
	check(not g.industrial_heat.begin(1.0).ok,"starting a manual heat remotely is rejected")
	# Explicit operator-location fixture; not claimed as native flight proof.
	g.drone.global_position = g.industrial_heat.site()
	g.drone.freeze = true
	var event := InputEventKey.new()
	event.physical_keycode = Keys.codes("use")[0]
	event.pressed = true
	g._unhandled_input(event)
	await frames(2)
	check(g.console_ui != null and not paused,"real site interaction opens the live native furnace controls")
	if g.console_ui == null: quit(1);return
	check(press("把仓库炉料送到炉口") and Career.production_busy(),"native reserve button starts one persistent company heat")
	check(float(Career.data.exchange.actors.company.stock.get("ferrous_scrap:1",0.0)) == 0.0 and g.plant.smelter.bunker == 0.0,"reserved warehouse feed is neither sellable twice nor instantly inside the furnace")
	var before := JSON.stringify(Career.data)
	check(Career.take_trial("power").is_empty() and JSON.stringify(Career.data) == before,"occupied shared furnace cannot launch another salvage trial or alter funds")
	check(await await_state("processing",16000),"full colliding feed travels from the real warehouse around the berth to the actual furnace intake")
	if heat().get("state","") != "processing":
		check(false,"physical input route must pass before any process/product proof")
		g.console_ui.close()
		await release()
		quit(1)
		return
	check(g.plant.smelter.bunker > 0.999999 and g.plant.smelter.input_t > 0.999999,"only actual full-body intake receipt charges the existing cold furnace")
	# 36 号: one press — charging on, arcs struck, automatic power
	await frames(2)
	check(press("通电熔化"),"one press strikes the arcs and starts the real screw feeder (%s · %s)" % [g.console_ui.main.text, g.industrial_heat.waiting])
	await frames(2400)
	check(g.plant.smelter.T > 20.0 and g.plant.smelter.m_l < 1.0 and float(heat().energy_cost) > 0.0,"cold material requires actual heating and paid metered electricity")
	var model: Dictionary = g.plant.smelter.manual_snapshot()
	check(g.industrial_heat.checkpoint(),"mid-heat model, custody and power payment checkpoint is durably saved")
	SaveGame.save(g)
	await release()
	Career.data = {}
	Career.load_or_new()
	await spawn(true)
	var resumed_dt: float = g.plant.smelter.t-float(model.t)
	var meter_delta: float = g.plant.smelter.electrical_j-float(model.electrical_j)
	check(absf(g.plant.smelter.input_t-float(model.input_t)) < 0.000001 and resumed_dt >= 0.0 and resumed_dt < 1.0 and absf(meter_delta-resumed_dt*g.plant.smelter.P_RATED*1e6) < 1.0,"actual career/field reload resumes the same charged furnace; meter advances only by its real resumed simulation time")
	g.drone.global_position = g.industrial_heat.site()
	g.drone.freeze = true
	g.open_heat()
	var target_temperature := 1715.0 if bad_heat else 1640.0 # the automatic power holds the bath just above tapping heat
	for i in 18000:
		await frames(1)
		if g.plant.smelter.T >= target_temperature and g.plant.smelter.m_l > 0.999999: break
	check(g.plant.smelter.T >= target_temperature and g.plant.smelter.m_l > 0.999999,"paid heat balance fully melts the actual supplied tonne")
	if bad_heat:
		g.console_ui.power.value = 0.0
		check(press("应用"),"operator stops the real heater after actually overheating the bath")
		for i in 12000:
			await frames(1)
			if g.plant.smelter.T <= 1685.0: break
	check(press("测温取样"),"native sample control actuates the actual immersion probe")
	await frames(310)
	check(g.plant.smelter.sample_count == 1 and g.plant.smelter.dip == 0.0 and press("倾炉出钢"),"only actual completed and retracted probe permits the native tap command")
	check(await await_state("product_transport",16000),"real tilt, gate, mould cooling and indexing create a physical output consignment")
	check(float(Career.data.exchange.actors.company.stock.get("steel_billet:1",0.0)) == 0.0,"cooled product in transit is not yet available warehouse inventory")
	check(await await_state("complete",16000),"actual cooled output travels continuously back around the berth into the real warehouse")
	check(max_step <= 10.5,"production cargo keeps continuous bounded motion and never teleports between facilities")
	var output_grade := 0 if bad_heat else 1
	var output_key := Exchange.lot_key("steel_billet",output_grade)
	check(not Career.production_busy() and is_equal_approx(float(Career.data.exchange.actors.company.stock.get(output_key,0.0)),1.0),"actual warehouse receipt alone releases the berth and grants exactly the manufactured mass at its measured process grade")
	check(int(heat().quality.grade) == output_grade and heat().quality.trace.sample_valid and float(heat().quality.trace.poured_t) > 0.999999,"warehouse batch retains real temperature/probe/outflow proof for its actual output grade")
	if bad_heat:
		check(float(Career.data.exchange.actors.company.stock.get("steel_billet:1",0.0)) == 0.0 and not Exchange.command("post",{"side":"sell","item":"steel_billet","grade":1,"quantity":1.0,"price":1000.0}).ok,"off-spec physical production cannot masquerade as qualified grade-one inventory")
	check(is_equal_approx(float(heat().energy_cost),g.plant.smelter.electrical_j/3.6e9*Grid.OWN_PRICE),"industrial electricity cost follows actual inverter input rather than product timers")
	var cash: float = Career.data.money
	var sale: Dictionary = Exchange.command("post",{"side":"sell","item":"steel_billet","grade":output_grade,"quantity":1.0,"price":200.0}) if bad_heat else Exchange.command("customer_ship",{"offer_id":"PORT-STEEL-01","quantity":1.0})
	check(sale.ok,"actual manufactured lot is legally reserved against a funded customer bid")
	# 37 号: paid on the sale; the courier still delivers it for real
	for i in 4800:
		await frames(1)
		if Career.data.money > cash and (bad_heat or Exchange.customer_status(Career.data.exchange,"PORT-STEEL-01").delivered >= 1.0): break
	if bad_heat:
		check(Career.data.money > cash and Career.data.money < 100000.0 and float(Career.data.exchange.actors.company.stock.get(output_key,0.0)) == 0.0,"off-spec customer really pays a lower price: the metal is sold once but the overheated batch makes an actual net loss")
	else:
		check(Career.data.money > 100000.0 and float(Career.data.exchange.actors.company.stock.get(output_key,0.0)) == 0.0,"real customer delivery pays nonzero net income after source purchase, electricity and transaction fee")
		var contract: Dictionary = Exchange.customer_status(Career.data.exchange,"PORT-STEEL-01")
		check(contract.state == "complete" and contract.delivered == 1.0,"ordinary accepted customer demand completes only after nonzero actual manufactured output and real customer receipt")
	print("MEASURE net_profit=",Career.data.money-100000.0," power_cost=",heat().energy_cost," maximum_motion_px=",max_step)
	if g.console_ui != null: g.console_ui.close()
	await release()
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G5 INDUSTRIAL CYCLE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)

# 31 号: the belt's merchants ship by freighter now; these checks are about the port's own
# local freight, so only the three big companies' counters stay open for them
func _local_only() -> void:
	for o in Career.data.get("exchange",{}).get("orders",[]):
		if str(o.get("owner","")).begins_with("merchant_") and int(str(o.owner).substr(9)) >= 3:
			o.state = "cancelled"
	# and no belt merchant comes back to the book while these checks run
	if not Career.data.get("exchange",{}).is_empty(): Career.data.exchange.belt_quiet = true
