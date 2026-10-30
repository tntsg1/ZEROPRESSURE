extends "res://tests/g5_sort_physical_check.gd"
# Queue/cash/unknown-description adversarial fixtures, native declared foreign
# scrap and actual geometry loss. Neither direct player laser nor human testing.
func run() -> void:
	Career.path = "user://zp_test_g5_sort_safety_career.json"
	SaveGame.path = "user://zp_test_g5_sort_safety_field.json"
	SaveGame.allow_test = true
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.market = true
	Career.data.money = 100000.0
	Career.data.port = {"trade":1,"process":1}
	await spawn()
	Exchange.command("view")
	Exchange.command("view")
	_local_only()
	Exchange.command("post",{"side":"buy","item":"mixed_metal","grade":0,"quantity":2.0,"price":420.0})
	for i in 3000:
		await frames(1)
		if float(Career.data.exchange.actors.company.stock.get("mixed_metal:0",0.0)) >= 2.0: break
	check(float(Career.data.exchange.actors.company.stock.get("mixed_metal:0",0.0)) == 2.0,"safety branch buys and physically receives its two real tonnes before any adversarial fixture")
	g.drone.global_position = g.industrial_sort.site()
	g.drone.freeze = true
	var actor: Dictionary = Career.data.exchange.actors.company
	var profiles := {}
	for identity in actor.lots:
		if actor.lots[identity].key != "mixed_metal:0": continue
		profiles[identity] = actor.lots[identity].material_profile.duplicate(true)
		actor.lots[identity].erase("material_profile")
	check(not g.industrial_sort.begin(1.0).ok and float(Career.data.exchange.actors.company.stock["mixed_metal:0"]) == 2.0 and not Career.production_busy(),"unknown old-source fixture cannot acquire a made-up split or lose its raw stock on failed reservation")
	for identity in profiles: Career.data.exchange.actors.company.lots[identity].material_profile = profiles[identity]
	# Declared already-accepted legacy queue fixture; begin must wait before
	# that pre-existing metal can be mistaken for the next company's batch.
	var at: Vector2 = Dock.trough_below(Vector2(Dock.metal_home*Geom.M,0))
	var old = g.world.add_piece("plate",Geom.rect_poly(Rect2(at-Vector2(24,24),Vector2(48,48))),{"key":"PREEXISTING-SCRAP","mass":0.2,"scope":false})
	g.world.make_body([old],null)
	g.dock._start_convey(old.body)
	# 30 号: the company's line is the processing district's now; scrap on the berth's own
	# conveyor goes to the berth's line and holds nothing up
	check(g.industrial_sort.begin(1.0).ok and await sort_state("processing"),"scrap on the berth's own conveyor no longer holds up the company batch")
	var foreign = g.world.add_piece("plate",Geom.rect_poly(Rect2(at-Vector2(24,24),Vector2(48,48))),{"key":"UNRELATED-SCRAP","mass":0.2,"scope":false})
	g.world.make_body([foreign],null)
	foreign.body.freeze = true
	await frames(12)
	check(g.plant.scrapline.in_process_mass() == 1.0 and g.judge(foreign.body,"metal").ok and g.dock.scrapline != g.plant.scrapline,"berth scrap is the berth line's; the company batch in the district's line is untouched")
	check(g.industrial_sort.command("start").ok,"site drive starts after actual company intake")
	await frames(200)
	var save_path: String = Career.path
	var saved_line := JSON.stringify(g.industrial_sort.heat().line)
	Career.path = "user://zp_test_sort_atomic_missing_parent/no_such_subfolder/career.json"
	var failed_stop: Dictionary = g.industrial_sort.command("stop")
	Career.path = save_path
	check(not failed_stop.ok and g.plant.scrapline.company_powered and JSON.stringify(g.industrial_sort.heat().line) == saved_line,"failed drive-stop save rolls back both live machinery and persistent in-memory snapshot instead of later committing a refused command")
	Career.data.money = 0.0 # Competing-business cash-drain fixture, not profits.
	Career.data.exchange.actors.company.cash = 0.0
	await frames(3)
	var energy: float = g.plant.scrapline.company_energy_j
	check(float(g.industrial_sort.heat().energy_debt)>0.0 and not g.plant.scrapline.company_powered,"actual spent drive energy becomes a payable debt and stops cold processing when funds run out")
	await frames(15)
	check(g.plant.scrapline.company_energy_j == energy,"unpaid stopped drives cannot continue processing on free electricity")
	Career.data.money = 100.0 # Declared funds restoration, not a trade receipt.
	Career.data.exchange.actors.company.cash = 100.0
	await frames(2)
	check(g.industrial_sort.heat().energy_debt == 0.0 and not g.plant.scrapline.company_powered and g.industrial_sort.command("start").ok,"restored cash pays the actual bill; safe cold machinery requires an explicit restart")
	check(await sort_state("product_transport"),"resumed actual process reaches its two real output buffers")
	for i in 100:
		await frames(1)
		if is_instance_valid(g.industrial_sort.body) and g.industrial_sort.heat().transport.get("claimed",false): break
	var batch: Dictionary = g.industrial_sort.heat()
	var identity: String = batch.id
	var remainder: float = g.plant.scrapline.company_nf
	var consumed := 0.0
	for slice in batch.source_lots: consumed += float(Career.data.exchange.actors.company.lots[str(slice.source_id)].consumed)
	var cut: Dictionary = g.world.commit_cut(g.industrial_sort.body.pieces[0],PackedVector2Array([Vector2(-100,0),Vector2(100,0)]),100.0)
	var cash: float = Career.data.money
	check(cut.gone and not g.industrial_sort.cancel().ok and g.industrial_sort.write_off().ok,"actual geometry loss cannot be refunded as intact feed but permits an explicit failed batch write-off")
	var waste = g.world.key_piece(identity+"/WASTE/NF")
	check(waste != null and waste.body != null and absf(waste.mass-remainder)<0.000001 and not waste.scope and waste.body.collision_mask == FreeBody.MASK and g.piece_value(waste,"metal") == 0.0,"unshipped coproduct becomes actual unpaid full-collision waste at its real outlet instead of vanishing from a cleared buffer")
	check(not Career.production_busy() and g.plant.scrapline.company_fe+g.plant.scrapline.company_nf == 0.0 and Career.data.money == cash and g.industrial_sort.heat().loss.refund == 0.0,"failed disposition releases the line without refund, product stock or a permanent buffer softlock")
	var after := 0.0
	for slice in g.industrial_sort.heat().source_lots: after += float(Career.data.exchange.actors.company.lots[str(slice.source_id)].consumed)
	check(after == consumed and not g.industrial_sort.write_off().ok,"product loss never consumes source material twice or permits duplicate write-off")
	check(g.industrial_sort.begin(0.25).ok and g.industrial_sort.cancel().ok,"remaining genuine warehouse feed can reserve a new batch and reverse its unused reservation after disposal")
	Career.save()
	SaveGame.save(g)
	await release()
	Career.data = {}
	Career.load_or_new()
	await spawn(true)
	await frames(5)
	waste = g.world.key_piece(identity+"/WASTE/NF")
	check(waste != null and absf(waste.mass-remainder)<0.000001 and Career.data.sorting_disposals.size() == 1,"actual waste geometry and its one-time materialization record survive a real field/career reload without a second coproduct")
	# Pending-record fixture with an already present whole native waste body.
	# A failed authorization save must not expose another generation permit.
	Career.data.sorting_disposals[0].issued = false
	Career.path = "user://zp_test_sort_atomic_missing_parent/no_such_subfolder/career.json"
	g.industrial_sort._materialize_disposals()
	Career.path = save_path
	check(not Career.data.sorting_disposals[0].issued and g.world.key_piece(identity+"/WASTE/NF") == waste and absf(waste.mass-remainder)<0.000001,"failed disposal authorization save keeps the prior manifest and existing whole body without duplicate generation")
	Career.data.sorting_disposals[0].issued = true
	var destroyed: Dictionary = g.world.commit_cut(waste,PackedVector2Array([Vector2(-100,0),Vector2(100,0)]),100.0)
	g.industrial_sort._materialize_disposals()
	check(destroyed.gone and g.world.key_piece(identity+"/WASTE/NF") == null,"destroyed actually issued waste is never recreated from the loss record")
	Career.save()
	SaveGame.save(g)
	await release()
	Career.data = {}
	Career.load_or_new()
	await spawn(true)
	await frames(5)
	check(g.world.key_piece(identity+"/WASTE/NF") == null and Career.data.sorting_disposals[0].issued,"actual destruction and durable one-time issuance survive another disk reload with no replacement metal")
	await release()
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G5 SORT SAFETY %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)

# 31 号: the belt's merchants ship by freighter now; these checks are about the port's own
# local freight, so only the three big companies' counters stay open for them
func _local_only() -> void:
	for o in Career.data.get("exchange",{}).get("orders",[]):
		if str(o.get("owner","")).begins_with("merchant_") and int(str(o.owner).substr(9)) >= 3:
			o.state = "cancelled"
	# and no belt merchant comes back to the book while these checks run
	if not Career.data.get("exchange",{}).is_empty(): Career.data.exchange.belt_quiet = true
