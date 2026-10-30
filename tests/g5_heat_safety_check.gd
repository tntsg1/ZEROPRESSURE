extends "res://tests/g5_industrial_cycle_check.gd"
# Adversarial fixtures for cancellation, utility debt and corrupt snapshots.
# Reuses real dispatch/collision/receiver integration; no fake successful heat.
func run() -> void:
	Career.path = "user://zp_test_g5_heat_safety_career.json"
	SaveGame.path = "user://zp_test_g5_heat_safety_field.json"
	SaveGame.allow_test = true
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.market = true
	Career.data.money = 100000.0
	Career.data.port = {"trade":1,"process":1,"power":1} # 34 号: the furnace needs the power district for its 24 MW
	await spawn()
	Exchange.command("view")
	Exchange.command("post",{"side":"buy","item":"ferrous_scrap","grade":1,"quantity":1.0,"price":500.0})
	for i in 1600:
		await frames(1)
		if float(Career.data.exchange.actors.company.stock.get("ferrous_scrap:1",0.0)) >= 1.0: break
	var warehouse_fixture := Career.data.duplicate(true)
	g.drone.global_position = g.industrial_heat.site()
	g.drone.freeze = true
	var result: Dictionary = g.industrial_heat.begin(1.0)
	var reserved_lot: Dictionary = Career.data.exchange.actors.company.lots[str(heat().source_lots[0].source_id)]
	var reserved_available: float = reserved_lot.available
	reserved_lot.available = float(reserved_lot.total)
	var malformed_before := JSON.stringify(Career.data)
	check(not g.industrial_heat.cancel().ok and JSON.stringify(Career.data) == malformed_before,"unmaterialized cancellation cannot double-credit an already available source in a damaged reservation snapshot")
	reserved_lot.available = reserved_available
	check(result.ok and g.industrial_heat.cancel().ok and not Career.production_busy(),"unmaterialized reserved warehouse feed can be cancelled before any transport or input")
	check(float(Career.data.exchange.actors.company.stock.get("ferrous_scrap:1",0.0)) == 1.0 and g.plant.smelter.input_t == 0.0,"unused reservation returns exactly its original available material without producing metal")
	var cancelled_fixture := Career.data.duplicate(true)
	var before := JSON.stringify(Career.data)
	check(not g.industrial_heat.cancel().ok and JSON.stringify(Career.data) == before,"repeated cancellation cannot duplicate source availability")
	check(g.industrial_heat.begin(1.0).ok,"a cancelled empty furnace can start another legitimate reservation")
	for i in 2400:
		await frames(1)
		if int(heat().transport.get("waypoint",0)) >= 1: break
	check(is_instance_valid(g.industrial_heat.body) and g.industrial_heat.cancel().ok and heat().state == "raw_return","already moving cargo reverses its actually traversed route on cancellation")
	check(Career.production_busy() and float(Career.data.exchange.actors.company.stock.get("ferrous_scrap:1",0.0)) == 0.0,"returning material stays reserved until physically back inside its warehouse")
	g.industrial_heat.checkpoint()
	SaveGame.save(g)
	await release()
	Career.data = {}
	Career.load_or_new()
	await spawn(true)
	# Corrupt ledger fixtures at a genuinely returning cargo's actual receiver.
	# No cargo is moved to the receiver by the test; it must finish its route.
	var return_sources: Array = heat().source_lots.duplicate(true)
	heat().source_lots.append(return_sources[0].duplicate(true))
	for i in 4000:
		await frames(1)
		if g.industrial_heat._inside(g.exchange_logistics.warehouse): break
	check(g.industrial_heat._inside(g.exchange_logistics.warehouse) and heat().state == "raw_return" and float(Career.data.exchange.actors.company.stock.get("ferrous_scrap:1",0.0)) == 0.0,"duplicate source slices cannot credit inventory even when the real returning cargo reaches its native warehouse receiver")
	heat().source_lots = [{"source_id":"MISSING","quantity":1.0}]
	check(not g.industrial_heat._receive() and heat().state == "raw_return","missing return source is refused atomically at the actual warehouse without invalid indexing")
	heat().source_lots = return_sources.duplicate(true)
	var return_lot: Dictionary = Career.data.exchange.actors.company.lots[str(return_sources[0].source_id)]
	var actual_available: float = return_lot.available
	return_lot.available = float(return_lot.total)
	check(not g.industrial_heat._receive() and heat().state == "raw_return","return receipt refuses a source whose existing availability would be credited beyond its original total")
	return_lot.available = actual_available
	check(await await_state("cancelled",4000),"actual mid-return disk reconstruction finishes the same native warehouse return")
	check(not Career.production_busy() and float(Career.data.exchange.actors.company.stock.get("ferrous_scrap:1",0.0)) == 1.0 and g.plant.smelter.input_t == 0.0,"warehouse return releases one original tonne without consumption or duplicate ingots")
	g.drone.global_position = g.industrial_heat.site()
	g.drone.freeze = true
	check(g.industrial_heat.begin(0.25).ok and await await_state("processing",16000),"quarter-tonne safety batch uses legitimate dispatch and actual furnace intake")
	check(not g.industrial_heat.cancel().ok,"already charged material cannot be magically returned as untouched cold stock")
	# Declared external cash drain exercises a same-frame competing business.
	Career.data.money = 0.0
	Career.data.exchange.actors.company.cash = 0.0
	g.industrial_heat.command("power",1.0)
	g.industrial_heat.command("feed",1.0)
	await frames(8)
	var energy: float = g.plant.smelter.electrical_j
	check(float(heat().get("energy_debt",0.0)) > 0.0 and g.plant.smelter.manual_supply_mw == 0.0 and Career.data.money == 0.0,"actual consumed energy becomes a payable obligation when cash runs out; supply stops without negative cash")
	# Terminal-state ledger fixture exercises replacement of a payable batch;
	# it is not claimed as a physical completed or written-off heat.
	var real_stage: String = heat().state
	heat().state = "written_off"
	var owed_before: float = heat().energy_debt
	result = g.industrial_heat.begin(0.25)
	check(not result.ok and str(result.get("reason","")).contains("电费") and float(heat().energy_debt) == owed_before,"a terminal batch with a real unpaid meter obligation cannot be replaced by a fresh debt-free heat")
	heat().state = real_stage
	await frames(30)
	check(g.plant.smelter.electrical_j == energy and float(heat().energy_cost) > 0.0,"unpaid supply cannot continue heating or erase its real energy cost")
	# Declared cash restoration tests paying the obligation, not trade profits.
	var debt: float = heat().energy_debt
	Career.data.money = 100.0
	Career.data.exchange.actors.company.cash = 100.0
	await frames(1)
	check(float(heat().energy_debt) == 0.0 and Career.data.money <= 100.0-debt+0.000001 and g.industrial_heat.waiting != "电费余额不足，已停止新增供电","newly available funds pay the actual accrued bill before supply resumes and clear the resolved power warning")
	check(g.industrial_heat.checkpoint(),"valid safety batch checkpoint saves normally")
	var valid := Career.data.duplicate(true)
	await release()
	# Invalid production-stage fixture: there is no successful output proof.
	Career.data = valid.duplicate(true)
	Career.data.industrial_heat.state = "product_transport"
	Career.data.industrial_heat.furnace.m_l = 1000.0
	var corrupt_model := JSON.stringify(Career.data.industrial_heat.furnace)
	Career.save()
	await spawn(false)
	await frames(120)
	check(g.industrial_heat.fault != "" and JSON.stringify(heat().furnace) == corrupt_model,"corrupt furnace restore locks the service without overwriting its original evidence")
	check(not is_instance_valid(g.industrial_heat.body) and float(Career.data.exchange.actors.company.stock.get("steel_billet:1",0.0)) == 0.0 and heat().state == "product_transport","invalid furnace cannot materialize a product consignment, accept goods or mark completion")
	check(not g.industrial_heat.checkpoint() and not g.industrial_heat.begin(1.0).ok and not g.industrial_heat.command("tap").ok,"fault blocks checkpoint and commands instead of replacing the bad record with empty scenery state")
	await release()
	# Valid thermal snapshot but forged product phase: no cooled outflow exists.
	Career.data = valid.duplicate(true)
	Career.data.industrial_heat.state = "product_transport"
	Career.data.industrial_heat.transport = {}
	Career.save()
	await spawn(false)
	check(g.industrial_heat.fault != "" and g.plant.smelter.manual_shipped_t == 0.0,"valid thermal snapshot with a forged product phase is rejected for missing actual outflow proof")
	await frames(1)
	check(not g.industrial_heat._receive() and float(Career.data.exchange.actors.company.stock.get("steel_billet:1",0.0)) == 0.0,"an uncompleted heat cannot gain inventory through a receipt call")
	await release()
	# Independent adversarial branch from the earlier actual warehouse receipt.
	Career.data = warehouse_fixture.duplicate(true)
	await spawn(false)
	g.drone.global_position = g.industrial_heat.site()
	g.drone.freeze = true
	check(g.industrial_heat.begin(1.0).ok,"loss-race branch reserves the earlier genuinely received source lot")
	for i in 1200:
		await frames(1)
		if is_instance_valid(g.industrial_heat.body): break
	if is_instance_valid(g.industrial_heat.body):
		var actual = g.industrial_heat.body.pieces[0]
		var cut: Dictionary = g.world.commit_cut(actual,PackedVector2Array([Vector2(-100,0),Vector2(100,0)]),100.0)
		result = g.industrial_heat.cancel()
		check(cut.gone and not result.ok and heat().state == "raw_transport" and float(Career.data.exchange.actors.company.stock.get("ferrous_scrap:1",0.0)) == 0.0,"same-frame cargo destruction cannot be acknowledged as a successful cancellation or refund before the loss flag updates")
		var cash_before: float = Career.data.money
		check(g.industrial_heat.write_off().ok and not Career.production_busy() and heat().state == "written_off" and float(heat().loss.refund) == 0.0,"explicit no-refund write-off records a failed batch and releases shared furnace occupation after actual cargo loss")
		check(Career.data.money == cash_before and float(Career.data.exchange.actors.company.stock.get("ferrous_scrap:1",0.0)) == 0.0 and heat().loss.mass_t == 1.0,"loss settlement does not refund cash, restore destroyed feed or call the failed batch a successful product")
		before = JSON.stringify(Career.data)
		check(not g.industrial_heat.write_off().ok and JSON.stringify(Career.data) == before,"repeating a completed loss disposition cannot consume another source slice or change money")
	else: check(false,"loss-race branch must materialize its real physical cargo")
	await release()
	# Historical-debt migration fixtures, not physical successful heats. Duplicate
	# copies represent one obligation; cash/debt must persist in one save.
	Career.data = warehouse_fixture.duplicate(true)
	Career.data.industrial_heat = {}
	Career.data.industrial_history = [{"id":"OLD-OWED","energy_debt":15.0},{"id":"OLD-OWED","energy_debt":15.0}]
	Career.data.money = 0.0
	Career.data.exchange.actors.company.cash = 0.0
	await spawn(false)
	g.drone.global_position = g.industrial_heat.site()
	g.drone.freeze = true
	check(float(g.industrial_heat.historical_debt().total) == 15.0 and not g.industrial_heat.begin(0.25).ok,"an overwritten old furnace obligation is recovered once by heat ID and blocks replacement without blocking salvage work")
	Career.data.money = 10.0
	Career.data.exchange.actors.company.cash = 10.0
	await frames(2)
	check(Career.data.money == 0.0 and float(g.industrial_heat.historical_debt().total) == 5.0,"partial payment of historical duplicate records charges only one bill and updates every matching copy")
	await release()
	Career.data = {}
	Career.load_or_new()
	await spawn(false)
	check(Career.data.money == 0.0 and float(g.industrial_heat.historical_debt().total) == 5.0,"partial historical debt payment survives actual career disk reload even with no current heat")
	Career.data.money = 20.0
	Career.data.exchange.actors.company.cash = 20.0
	await frames(2)
	check(Career.data.money == 15.0 and float(g.industrial_heat.historical_debt().total) == 0.0,"later cash pays the exact remaining historical balance without interest, duplicate charges or a reset")
	await release()
	Career.data = {}
	Career.load_or_new()
	await spawn(false)
	await frames(2)
	check(Career.data.money == 15.0 and float(g.industrial_heat.historical_debt().total) == 0.0,"paid historical balances remain settled after a second real disk reload")
	Career.data.industrial_heat = cancelled_fixture.industrial_heat.duplicate(true)
	Career.data.exchange.next = maxi(int(Career.data.exchange.next),int(cancelled_fixture.exchange.next))
	var old_id: String = heat().id
	Career.data.industrial_history = [{"id":old_id,"energy_debt":3.0},{"id":old_id,"energy_debt":7.0}]
	g.drone.global_position = g.industrial_heat.site()
	g.drone.freeze = true
	check(g.industrial_heat.begin(0.25).ok and heat().id != old_id and float(g.industrial_heat.historical_debt().total) == 0.0 and Career.data.money == 15.0,"replacing a legitimately debt-free current heat atomically reconciles its stale historical copies so paid debt cannot resurrect")
	check(g.industrial_heat.cancel().ok,"the replacement batch retains normal reversible unused reservation behavior")
	Career.data.industrial_history = [{"id":"CONFLICT","energy_debt":3.0},{"id":"CONFLICT","energy_debt":7.0}]
	before = JSON.stringify(Career.data.industrial_history)
	var conflict_cash: float = Career.data.money
	await frames(2)
	check(not g.industrial_heat.historical_debt().ok and JSON.stringify(Career.data.industrial_history) == before and Career.data.money == conflict_cash and not g.industrial_heat.begin(0.25).ok,"conflicting old debt copies remain intact and refuse arbitrary deductions or a new heat while the market clock continues")
	await release()
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G5 HEAT SAFETY %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
