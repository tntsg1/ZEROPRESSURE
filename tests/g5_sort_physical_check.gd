extends "res://tests/g5_industrial_cycle_check.gd"
# Restored facilities, finite authored merchant material and an operator at the
# panel are fixtures. Cargo uses native collision/receivers and actual dispatch;
# in-machine parcels are the mechanical model, not Godot rigid-body particles.
var sort_steps := 0.0
var sort_previous := Vector2.INF
var sort_key := ""
func frames(n: int) -> void:
	for i in n:
		await process_frame
		if g == null or not is_instance_valid(g.industrial_sort.body): continue
		var actual = g.industrial_sort.body
		if actual.pieces.is_empty(): continue
		var key := str(actual.pieces[0].key)
		if key == sort_key and sort_previous.is_finite(): sort_steps = maxf(sort_steps,sort_previous.distance_to(actual.global_position))
		sort_key = key
		sort_previous = actual.global_position
func sort_state(target: String,limit: int = 16000) -> bool:
	for i in limit:
		await frames(1)
		if g.industrial_sort.heat().get("state","") == target: return true
		if i%2400 == 2399: print("SORT WAIT ",g.industrial_sort.heat().get("state","")," transport=",g.industrial_sort.heat().get("transport",{})," reason=",g.industrial_sort.waiting," body=",g.industrial_sort.body.global_position if is_instance_valid(g.industrial_sort.body) else Vector2.INF," robot=",g.industrial_sort.robot.global_position)
	return false
func run() -> void:
	Career.path = "user://zp_test_g5_sort_physical_career.json"
	SaveGame.path = "user://zp_test_g5_sort_physical_field.json"
	SaveGame.allow_test = true
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.market = true
	Career.data.money = 100000.0
	Career.data.port = {"trade":1,"process":1}
	await spawn()
	Exchange.command("view")
	_local_only()
	check(Exchange.command("view").ok and Exchange.command("post",{"side":"buy","item":"mixed_metal","grade":0,"quantity":1.0,"price":420.0}).ok,"company buys a finite actual mixed-metal consignment through the real exchange")
	var trade: Dictionary = Career.data.exchange.trades.filter(func(row):return row.buyer == "company" and row.item == "mixed_metal")[0]
	var physical_source: Dictionary = Exchange.source_profile(Career.data.exchange.actors[trade.seller],trade.source_lots,1.0)
	check(physical_source.ok and float(physical_source.profile.nonmagnetic_share)>0.0 and float(physical_source.profile.nonmagnetic_share)<1.0,"source's actual preexisting material profile contains two nonzero streams instead of deriving composition from the desired output")
	for i in 2400:
		await frames(1)
		if float(Career.data.exchange.actors.company.stock.get("mixed_metal:0",0.0)) >= 1.0: break
	check(float(Career.data.exchange.actors.company.stock.get("mixed_metal:0",0.0)) == 1.0,"mixed feed becomes available only after native warehouse delivery")
	check(not g.industrial_sort.begin(1.0).ok,"remote start of the site-operated sorting line is refused")
	g.drone.global_position = g.industrial_sort.site()
	g.drone.freeze = true
	var event := InputEventKey.new()
	event.physical_keycode = Keys.codes("use")[0]
	event.pressed = true
	g._unhandled_input(event)
	await frames(2)
	check(g.console_ui != null and g.console_ui.get_script() == preload("res://scripts/sort_panel.gd") and not paused,"actual sorting site use input opens the native live controls")
	check(press("把仓库废料送到分选机（只分选，两路产物回仓）") and Career.production_busy(),"native reservation commits exactly one company batch and reserves the shared machines")
	check(float(Career.data.exchange.actors.company.stock.get("mixed_metal:0",0.0)) == 0.0 and g.plant.scrapline.company_input == 0.0,"reservation does not immediately invent an in-machine batch or leave sellable duplicate raw stock")
	check(await sort_state("processing"),"complete colliding mixed feed reaches the actual intake by continuous around-berth transport")
	if g.industrial_sort.heat().state != "processing": await release(); quit(1); return
	check(g.plant.scrapline.company_input == 1.0 and not g.plant.scrapline.company_powered and g.plant.smelter.input_t == 0.0,"actual intake consumes the source once and leaves cold material waiting for site drive start, outside the furnace")
	check(press("启动分选驱动"),"native drive control starts the real shredder and separator model")
	await frames(250)
	check(g.plant.scrapline.company_energy_j > 0.0 and not g.plant.scrapline.company_complete(),"processing takes actual powered mechanism time and measured electrical energy")
	check(g.industrial_sort.checkpoint(),"mid-processing mechanical state and custody checkpoint saves to the isolated career")
	SaveGame.save(g)
	var saved_id: String = g.industrial_sort.heat().id
	await release()
	Career.data = {}
	Career.load_or_new()
	await spawn(true)
	check(g.industrial_sort.fault == "" and g.industrial_sort.heat().id == saved_id and g.plant.scrapline.company_input == 1.0,"actual career/field disk reload resumes the same source, mechanism and parcel RNG")
	check(await sort_state("product_transport"),"only actual fragment milling and separation permit two physical output consignments")
	check(float(Career.data.exchange.actors.company.stock.get("ferrous_scrap:0",0.0)) == 0.0 and float(Career.data.exchange.actors.company.stock.get("nonferrous_mix:0",0.0)) == 0.0,"finished buffers in the plant are not yet usable warehouse inventory")
	check(await sort_state("complete"),"courier physically returns both nonzero outputs around the berth, including an empty trip back for the second stream")
	if g.industrial_sort.heat().state != "complete": await release(); quit(1); return
	var nf: float = physical_source.profile.nonmagnetic_share
	var stock: Dictionary = Career.data.exchange.actors.company.stock
	check(absf(float(stock.get("ferrous_scrap:0",0.0))-(1.0-nf))<0.000001 and absf(float(stock.get("nonferrous_mix:0",0.0))-nf)<0.000001,"two actual warehouse receipts preserve the source's independently known magnetic and nonmagnetic masses")
	check(float(stock.get("ferrous_scrap:1",0.0)) == 0.0 and g.plant.smelter.input_t == 0.0,"sorting alone cannot forge certified furnace feed or secretly charge the manual furnace")
	check(not Career.production_busy() and not g.exchange_logistics.production_lane and sort_steps <= 10.5,"complete receipt releases shared capacity, freight lane and continuous bounded native cargo motion")
	var cash: float = Career.data.money
	# Sell the actual durable lot amounts. Expected source fractions above are
	# independent evidence; JSON can round 0.30000000000000004 to 0.3 and does
	# not create a right to sell more than the persisted physical receipt.
	_local_only()
	check(Exchange.command("post",{"side":"sell","item":"ferrous_scrap","grade":0,"quantity":float(stock["ferrous_scrap:0"]),"price":350.0}).ok and Exchange.command("post",{"side":"sell","item":"nonferrous_mix","grade":0,"quantity":float(stock["nonferrous_mix:0"]),"price":700.0}).ok,"both real ungraded streams can be sold against finite funded buyers without pretending to be steel")
	for i in 5000:
		await frames(1)
		var remaining: Array = Career.data.exchange.trades.filter(func(row):return row.seller == "company" and row.state != "delivered")
		if remaining.is_empty(): break
	# 31 号: only the belt's merchants take the nonferrous mix, and they ship by freighter
	# (tests/shipping_check.gd); with them kept off the book here, its ask stays open
	var nf_open: bool = Career.data.exchange.orders.any(func(o): return o.owner == "company" and o.state == "open" and o.item == "nonferrous_mix")
	check(Career.data.money > cash and float(Career.data.exchange.actors.company.stock.get("ferrous_scrap:0",0.0)) == 0.0 and float(Career.data.exchange.actors.company.stock.get("nonferrous_mix:0",0.0)) == 0.0 and nf_open,"the local buyer receives and pays for the ferrous stream; the nonferrous ask waits for the belt")
	print("MEASURE sorting_net_profit=",Career.data.money-100000.0," energy_cost=",g.industrial_sort.heat().energy_cost," max_cargo_step_px=",sort_steps," nonmagnetic_share=",nf)
	check(g.industrial_sort.checkpoint(),"completed sorting record remains checkpointable after the line returns to legacy idle mode")
	SaveGame.save(g)
	await release()
	Career.data = {}
	Career.load_or_new()
	await spawn(true)
	check(g.industrial_sort.fault == "" and g.industrial_sort.heat().state == "complete" and not Career.production_busy() and not g.plant.scrapline.company_mode,"fully received and subsequently sold outputs reload against their actual preserved source/lot/receipt records without restarting the line")
	var valid := Career.data.duplicate(true)
	await release()
	# Corrupt semantic snapshots, not claims of extra actual production.
	for kind in ["missing_receipt","wrong_id","wrong_profile","missing_source"]:
		Career.data = valid.duplicate(true)
		var batch: Dictionary = Career.data.industrial_sort
		if kind == "missing_receipt": batch.output_index = 1; batch.received = batch.received.slice(0,1)
		elif kind == "wrong_id": batch.line.company_id = "UNRELATED-SORT"
		elif kind == "wrong_profile": batch.profile.nonmagnetic_share = 0.9
		else: Career.data.exchange.sources.erase(str(batch.id)+"/NF")
		var evidence := JSON.stringify(batch)
		await spawn(false)
		await frames(10)
		check(g.industrial_sort.fault != "" and JSON.stringify(g.industrial_sort.heat()) == evidence and not is_instance_valid(g.industrial_sort.body),"corrupt completed-sort "+kind+" keeps its evidence and cannot bypass receipt/identity checks or spawn substitute output")
		await release()
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G5 SORT PHYSICAL %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)

# 31 号: the belt's merchants ship by freighter now; these checks are about the port's own
# local freight, so only the three big companies' counters stay open for them
func _local_only() -> void:
	for o in Career.data.get("exchange",{}).get("orders",[]):
		if str(o.get("owner","")).begins_with("merchant_") and int(str(o.owner).substr(9)) >= 3:
			o.state = "cancelled"
	# and no belt merchant comes back to the book while these checks run
	if not Career.data.get("exchange",{}).is_empty(): Career.data.exchange.belt_quiet = true
