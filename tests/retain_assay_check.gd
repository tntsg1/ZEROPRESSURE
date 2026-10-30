extends "res://tests/g5_industrial_cycle_check.gd"
# G5.1 (design/…/19_G5.1_留料与检验): the company's own steel from a ship it took apart.
# The loadout switch keeps a job's structural scrap; the native metal mouth books it as
# raw material instead of cash; it is sorted on the real line, read at the assay bench,
# melted in the real furnace and delivered to a funded client who pays. Fixtures: the
# operator set down at each desk, declared plates fed to the native receiver (as in
# g5_material_intake_check), restored districts. Own test saves only.
#   godot --headless --path . --fixed-fps 60 -s tests/retain_assay_check.gd
const Assay = preload("res://scripts/industrial_assay.gd")
const CAREER := "user://zp_test_retain_assay_career.json"
const FIELD := "user://zp_test_retain_assay_field.json"
const PLATES := 4
const PLATE_T := 0.5


func job_of(id: String) -> Dictionary:
	return {"id": id, "ship": "pod", "fee": 0, "time": 0, "fee_paid": true, "kit": {}, "items": {}, "scope": "full"}


func spawn_job(job: Dictionary) -> void:
	Game.start_ship = "pod"
	Game.contract = job.duplicate(true)
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await frames(8)
	g.tutorial = null


func deliver(key: String) -> bool:
	var at: Vector2 = Dock.zpos("metal") + Dock.ZONES.metal.face * 38.0
	var piece = g.world.add_piece("keel", Geom.rect_poly(Rect2(at - Vector2(18, 10), Vector2(36, 20))), {"key": key, "mass": PLATE_T, "cls": "metal"})
	g.world.make_body([piece], null)
	piece.body.freeze = true
	for k in 600:
		await frames(1)
		if piece.gone:
			break
	return piece.gone


# one contract with four keel plates into the metal mouth; returns the cash it brought
func run_job(id: String, keep: bool) -> float:
	Career.data.active = job_of(id)
	# the loadout page, as the player meets it
	var host := Control.new()
	root.add_child(host)
	var page := LoadoutPanel.open(host, Callable(), Callable())
	await frames(3)
	check(page.retain_btn != null, "%s: the loadout page offers the scrap switch" % id)
	if page.retain_btn != null:
		page.retain_btn.button_pressed = keep
		await frames(1)
	page.go()
	host.queue_free()
	check(Career.retaining() == keep and SaveGame.read_career(CAREER).active.has("material_policy") == keep, "%s: the switch %s, saved on the contract in hand" % [id, "on" if keep else "off"])
	await spawn_job(Career.active())
	var ok := true
	for i in PLATES:
		ok = await deliver("%s-KEEL-%d" % [id, i]) and ok
	check(ok, "%s: four keel plates go through the native metal mouth" % id)
	if keep:
		check(g.material_receipts.size() == PLATES and is_zero_approx(g.income_metal) and is_zero_approx(g.structure_t), "kept: four raw receipts, no cash, no repair structure")
		check(g.material_receipts.all(func(r): return r.material_profile.basis == "ship_structure_keel" and is_equal_approx(float(r.material_profile.nonmagnetic_share), 0.03)), "each receipt carries what a keel is made of")
	else:
		check(g.material_receipts.is_empty() and g.income_metal > 0.0 and is_equal_approx(g.structure_t, PLATES * PLATE_T), "not kept: paid at the mouth and counted as structure, as before")
	var report: Dictionary = g.settle_report()
	var cash := float(Career.data.money)
	var result := Career.settle(report)
	check(not result.get("save_failed", false), "%s settles" % id)
	if keep:
		check(is_equal_approx(float(result.materials.mass_t), PLATES * PLATE_T) and float(result.retained_value) > 0.0, "the settlement says %.1f t kept and $%.0f not taken" % [PLATES * PLATE_T, float(result.get("retained_value", 0.0))])
		retained_value = float(result.retained_value)
		g.career_result = result
		var keys: Array = g.hud.career_rows().map(func(row): return str(row[0]))
		check(keys.has("e_retained") and keys.has("e_retained_cash") and keys.has("e_retained_next"), "the settlement page shows the kept tonnes, the cash not taken and where to go next")
		var again := Career.settle(report)
		check(again.get("already_settled", false) and Career.data.material_batches.size() == PLATES, "a retried settlement books nothing twice")
	g.queue_free()
	g = null
	await frames(5)
	return float(Career.data.money) - cash


var retained_value := 0.0


func use_at(site: Vector2) -> void:
	g.drone.global_position = site
	g.drone.freeze = true
	var event := InputEventKey.new()
	event.physical_keycode = Keys.codes("use")[0]
	event.pressed = true
	g._unhandled_input(event)
	await frames(2)


func press_prefix(text: String) -> bool:
	for node in g.console_ui.find_children("*", "Button", true, false):
		if node.text.begins_with(text) and not node.disabled:
			node.pressed.emit()
			return true
	return false


func stock(key: String) -> float:
	return float(Career.data.exchange.actors.company.stock.get(key, 0.0))


func sort_state(target: String, limit: int = 16000) -> bool:
	for i in limit:
		await frames(1)
		if str(Career.data.get("industrial_sort", {}).get("state", "")) == target:
			return true
		if i % 2400 == 2399:
			var s = g.industrial_sort
			print("SORT WAIT ", s.heat().get("state", ""), " reason=", s.waiting, " fault=", s.fault, " body=", s.body.global_position if is_instance_valid(s.body) else Vector2.INF, " robot=", s.robot.global_position)
	return false


func assay_done(limit: int = 3000) -> bool:
	for i in limit:
		await frames(1)
		if str(Career.data.get("assay", {}).get("state", "")) == "complete":
			return true
	return false


func run() -> void:
	Career.path = CAREER
	SaveGame.path = FIELD
	SaveGame.allow_test = true
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.story_job = {}
	Career.data.market = true
	Career.data.money = 100000.0
	# the trade port's bonus stays off while the two jobs are compared
	Career.data.port = {"trade": 0, "process": 1, "power": 1}
	Career.save()

	# 1. the switch: off pays as before, on keeps the scrap and gives up exactly its cash
	var paid := await run_job("G51-OFF", false)
	check(Career.data.material_batches.is_empty(), "switch off: no raw stock")
	var kept := await run_job("G51-ON", true)
	check(absf((paid - kept) - retained_value) < 1.0, "the cash given up is the salvage value of what was kept (%.0f vs %.0f)" % [paid - kept, retained_value])
	var rescue := job_of("G51-RESCUE")
	rescue.scope = "rescue"
	check(not Career.can_retain(rescue), "a rescue job has no switch")

	# 2. into the warehouse with its record, then the real sorting line
	Career.data.port["trade"] = 1
	Career.save()
	await spawn()
	check(Exchange.command("view").ok and is_equal_approx(stock("mixed_metal:0"), PLATES * PLATE_T), "the kept scrap is company stock: %.1f t unsorted metal" % stock("mixed_metal:0"))
	var lots: Dictionary = Career.data.exchange.actors.company.lots
	check(lots.values().filter(func(l): return l.get("origin", "") == "receiver" and Assay.described(l)).size() == PLATES, "each own-salvage lot keeps its material record (the sorting line needs it)")
	await use_at(g.industrial_sort.site())
	check(g.console_ui != null and g.console_ui.get_script() == preload("res://scripts/sort_panel.gd"), "E at the sorting desk")
	g.console_ui.quantity.value = PLATES * PLATE_T
	check(press_prefix("把仓库废料送到分选机"), "the whole 2 t reserved for sorting")
	check(await sort_state("processing"), "the courier brings it to the line")
	check(press("启动分选驱动"), "drives started")
	check(await sort_state("complete", 30000), "both streams back in the warehouse")
	g.console_ui.close()
	await frames(2)
	var fe := stock("ferrous_scrap:0")
	check(absf(fe - PLATES * PLATE_T * 0.97) < 1e-6 and absf(stock("nonferrous_mix:0") - PLATES * PLATE_T * 0.03) < 1e-6, "keel steel sorts 97 / 3 (%.3f t ferrous, unrated)" % fe)
	check(Ops.next_step().go == "site:assay", "the next step points to the assay bench (%s)" % Ops.next_step().text)

	# 3. the assay bench
	check(not g.industrial_assay.begin(Assay.candidates()[0].id).ok if not Assay.candidates().is_empty() else false, "the bench refuses a remote start")
	await use_at(g.industrial_assay.site())
	check(g.console_ui != null and g.console_ui.get_script() == preload("res://scripts/assay_panel.gd"), "E at the assay bench opens its console")
	var cash := float(Career.data.money)
	# a failed disk write changes nothing
	var cand: Array = Assay.candidates()
	check(cand.size() == 1 and cand[0].kind == "grade", "one lot to grade: the sorted ferrous stream")
	var snapshot := JSON.stringify(Career.data)
	Career.path = "user://zp_retain_missing_%d/sub/career.json" % Time.get_ticks_usec()
	check(not g.industrial_assay.begin(cand[0].id).ok and JSON.stringify(Career.data) == snapshot, "a failed save starts nothing and charges nothing")
	Career.path = CAREER
	check(press_prefix("定级"), "the lot sent to the spectrometer")
	check(g.industrial_assay.running() and is_zero_approx(stock("ferrous_scrap:0")) and is_equal_approx(float(Career.data.money), cash - Assay.FEE), "the lot is locked (not sellable) and the fee is paid")
	check(await assay_done(), "about 30 s on the spectrometer")
	var a: Dictionary = Career.data.assay
	check(a.result == "grade_1" and absf(float(a.cert.impurity) - (0.006 + 0.1 * 0.03)) < 1e-9, "keel steel reads %.2f %% impurity: grade 1" % (float(a.cert.impurity) * 100.0))
	check(absf(stock("ferrous_scrap:1") - fe) < 1e-6 and is_zero_approx(stock("ferrous_scrap:0")), "mass kept: %.3f t of grade 1 feed in, nothing left unrated" % stock("ferrous_scrap:1"))
	var parent: Dictionary = Career.data.exchange.actors.company.lots[str(a.lot)]
	check(absf(float(parent.consumed) - fe) < 1e-6 and parent.has("assay") and Assay.candidates().is_empty(), "the unrated lot is spent into the graded one and cannot be read again")
	g.console_ui.close()
	await frames(2)
	SaveGame.save(g)
	var disk := SaveGame.read_career(CAREER)
	check(disk.assay.result == "grade_1" and absf(float(disk.exchange.actors.company.stock["ferrous_scrap:1"]) - fe) < 1e-6, "the result is on disk")

	# 4. the same source reads the same; a dirty one fails; an old one gets its record
	var actor: Dictionary = Career.data.exchange.actors.company
	check(is_equal_approx(Assay.share_of(actor, parent), 0.03), "reading the same lot again gives the same share")
	actor.lots["FIX-DIRTY"] = {"id": "FIX-DIRTY", "key": "mixed_metal:0", "available": 0.0, "total": 1.0, "origin": "fixture", "consumed": 1.0, "material_profile": {"version": 1, "nonmagnetic_share": 0.40, "basis": "fixture"}}
	actor.lots["FIX-DIRTY/FE"] = {"id": "FIX-DIRTY/FE", "key": "ferrous_scrap:0", "available": 0.6, "total": 0.6, "origin": "magnetic_separation", "parents": [{"source_id": "FIX-DIRTY", "quantity": 1.0}]}
	actor.stock["ferrous_scrap:0"] = 0.6
	actor.lots["FIX-OLD"] = {"id": "FIX-OLD", "key": "mixed_metal:0", "available": 0.5, "total": 0.5, "origin": "receiver"}
	actor.stock["mixed_metal:0"] = stock("mixed_metal:0") + 0.5
	Career.save()
	await use_at(g.industrial_assay.site())
	check(g.industrial_assay.begin("FIX-DIRTY/FE").ok and await assay_done(), "a lot from a dirty source is read")
	check(Career.data.assay.result == "unrated" and is_equal_approx(stock("ferrous_scrap:0"), 0.6) and float(Career.data.assay.cert.impurity) > Assay.LIMIT, "it fails (%.1f %% impurity) and goes back to stock unrated" % (float(Career.data.assay.cert.impurity) * 100.0))
	check(not Assay.candidates().any(func(c): return c.id == "FIX-DIRTY/FE"), "a failed lot is not offered again (it would read the same)")
	check(Assay.candidates().any(func(c): return c.id == "FIX-OLD" and c.kind == "describe"), "an old receipt with no record is offered for a reading")
	check(g.industrial_assay.begin("FIX-OLD").ok and await assay_done(), "the old lot is read")
	var old: Dictionary = Career.data.exchange.actors.company.lots["FIX-OLD"]
	check(Assay.described(old) and old.material_profile.basis == "assay_conservative" and Exchange.source_profile(Career.data.exchange.actors.company, [{"source_id": "FIX-OLD", "quantity": 0.5}], 0.5).ok, "it now has a record and the sorting line would take it")
	if g.console_ui != null:
		g.console_ui.close()
	await frames(2)

	# 5. the furnace and the client: own steel paid for
	check(Exchange.command("customer_accept", {"offer_id": "PORT-STEEL-01"}).ok, "a client order for 1 t of grade 1 billet")
	check(Ops.next_step().go == "site:heat", "the next step points to the furnace (%s)" % Ops.next_step().text)
	await use_at(g.industrial_heat.site())
	g.console_ui.quantity.value = 1.0
	check(press("把仓库炉料送到炉口"), "1 t of own grade 1 feed reserved for the furnace")
	check(await await_state("processing", 16000), "it reaches the furnace")
	await frames(2)
	check(press("通电熔化"), "one press: arcs struck, feeder on, power automatic")
	for i in 20000:
		await frames(1)
		if g.plant.smelter.T >= 1640.0 and g.plant.smelter.m_l > 0.999999:
			break
	check(g.plant.smelter.m_l > 0.999999, "melted")
	check(press("测温取样"), "sampled")
	await frames(310)
	check(press("倾炉出钢"), "tapped")
	check(await await_state("complete", 20000), "billet back in the warehouse")
	check(is_equal_approx(stock("steel_billet:1"), 1.0), "1 t of grade 1 billet from the company's own salvage")
	var before_sale := float(Career.data.money)
	check(Exchange.command("customer_ship", {"offer_id": "PORT-STEEL-01", "quantity": 1.0}).ok, "shipped to the client")
	# 37 号: paid on the sale; the courier still delivers it to the client
	for i in 4800:
		await frames(1)
		if float(Career.data.money) > before_sale and Exchange.customer_status(Career.data.exchange, "PORT-STEEL-01").state == "complete":
			break
	check(float(Career.data.money) > before_sale and Exchange.customer_status(Career.data.exchange, "PORT-STEEL-01").state == "complete", "the client received it and paid $%.0f" % (float(Career.data.money) - before_sale))
	if g.console_ui != null:
		g.console_ui.close()
	await release()
	print("RETAIN ASSAY %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(0 if fails == 0 else 1)
