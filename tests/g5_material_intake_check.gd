extends SceneTree
# Declared load/ownership fixtures, real native receiving, disk reconstruction
# and Career transaction. This is not an owned-ship market or human playtest.
const Batches = preload("res://scripts/material_batches.gd")
const CAREER := "user://zp_test_g5_material_career.json"
const FIELD := "user://zp_test_g5_material_field.json"
var g: Node
var checks := 0
var fails := 0
var receipts := 0
var notices: Array = []
var replayed := false

func _initialize() -> void:
	# 64 号: this checks the older feed chain (bought / kept scrap, sorting); kept in code, switched off in play
	Career.INGOTS = false
	preload("res://scripts/industrial_exchange.gd").INGOTS = false
	run.call_deferred()
func frames(n: int) -> void:
	for k in n: await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])
func spawn(job: Dictionary, restore: bool = false) -> void:
	Game.start_ship = "pod"
	Game.contract = job.duplicate(true)
	SaveGame.load_requested = restore
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	await frames(8)
	g.tutorial = null
	g.load_received.connect(func(keys,zone,value,identity):
		receipts += 1
		notices.append({"keys":keys.duplicate(),"zone":zone,"value":value,"job":identity}))
func deliver(key: String):
	var at: Vector2 = Dock.zpos("metal") + Dock.ZONES.metal.face * 38.0
	var piece = g.world.add_piece("plate", Geom.rect_poly(Rect2(at-Vector2(18,10),Vector2(36,20))), {"key":key,"mass":0.25,"cls":"metal"})
	g.world.make_body([piece],null)
	piece.body.freeze = true
	check(piece.body.collision_mask == FreeBody.MASK and not piece.gone, "declared plate starts with its full native collision shape")
	for k in 600:
		await process_frame
		if piece.gone: break
	check(piece.gone, "actual metal receiver captures and completes the load")
	return piece
func deliver_mixed() -> void:
	var at: Vector2 = Dock.zpos("metal") + Dock.ZONES.metal.face * 38.0
	var raw = g.world.add_piece("plate", Geom.rect_poly(Rect2(at-Vector2(18,10),Vector2(18,20))), {"key":"G5-MIX-RAW","mass":0.25,"cls":"metal"})
	var sold = g.world.add_piece("cargo", Geom.rect_poly(Rect2(at-Vector2(0,10),Vector2(18,20))), {"key":"G5-MIX-EQUIP","mass":0.1,"cls":"equip","value":1000.0})
	g.world.make_body([raw,sold],null)
	var body = raw.body
	body.freeze = true
	var expected: float = g.piece_value(sold,"metal")
	var cash: float = g.income_metal
	var count: int = g.ledger.size()
	var before := receipts
	var reenter := func(keys,_zone,_value,_job):
		if keys.has("G5-MIX-RAW") and not replayed:
			replayed = true
			# Replay the notification while the actual body still exists, before
			# its original receiver commit has finished all downstream effects.
			g.on_swallowed(body,"metal")
	g.load_received.connect(reenter)
	check(body.collision_mask == FreeBody.MASK and expected > 0.0, "mixed load uses native collision and has a positive non-retained sale")
	for k in 600:
		await process_frame
		if raw.gone: break
	g.load_received.disconnect(reenter)
	check(raw.gone and sold.gone and replayed, "actual mixed load is received and its callback is deliberately replayed")
	check(is_equal_approx(g.income_metal-cash,expected) and g.material_receipts.size() == 2 and is_zero_approx(g.structure_t), "mixed callback replay cannot duplicate cash, raw stock or repair stock")
	check(receipts == before+1 and g.ledger.size() == count+1, "mixed callback replay emits and logs only one receipt")
	check(notices[-1].keys == ["G5-MIX-EQUIP","G5-MIX-RAW"] and notices[-1].zone == "metal" and notices[-1].job == g.job.id and is_equal_approx(notices[-1].value,expected), "actual receipt identifies both pieces and only the paid cash component")
func release() -> void:
	g.queue_free()
	await frames(5)
func run() -> void:
	Career.path = CAREER
	SaveGame.path = FIELD
	SaveGame.allow_test = true
	Career.data = Career.fresh()
	Career.data.money = 20000.0
	var job := {"id":"G5-RAW-001","ship":"pod","fee":0,"time":0,"fee_paid":true,"kit":{},"items":{},
		"material_policy":{"version":1,"metal":"retain","owner":"company","asset_id":"FIXTURE-OWNED-001"}}
	Career.data.active = job.duplicate(true)
	check(not Batches.retains({"id":"OLD"}) and Career.data.material_batches.is_empty(), "legacy/new career does not invent raw stock or transfer commission ownership")
	var wrong := job.duplicate(true)
	wrong.material_policy.owner = "customer"
	check(not Batches.retains(wrong), "a customer-owned policy cannot retain company material")
	await spawn(job)
	check(g.material_receipts.is_empty() and g.dock.smelter.m_l > 0.0, "running furnace heel/scenery creates no commercial inventory")
	var cash_before: float = g.earned()
	var rate_before: float = g.recovery_rate()
	await deliver("G5-RAW-PLATE")
	check(receipts == 1 and g.material_receipts.size() == 1, "one actual receiver commit creates exactly one identified raw receipt")
	check(is_equal_approx(float(g.material_receipts[0].mass_t),0.25) and g.material_receipts[0].state == "raw_received", "actual mass stays raw, without invented grade or cast products")
	check(is_equal_approx(g.earned(),cash_before) and is_zero_approx(g.income_metal) and is_zero_approx(g.structure_t), "retained raw metal grants neither cash nor duplicate legacy repair stock")
	check(g.recovery_rate() > rate_before and g.material_recovery_value > 0.0, "nonzero retained recovery still improves real recovery percentage")
	check(Career.data.material_batches.is_empty(), "unsettled raw stock is not credited to the durable career early")
	await deliver_mixed()
	var mixed_cash: float = g.income_metal
	SaveGame.save(g)
	var saved := SaveGame.read()
	check(not saved.is_empty() and saved.game.material_receipts.size() == 2 and saved.game.receiver_commits.size() == 3, "field disk snapshot includes raw receipts and every mixed-load commit identity")
	await release()
	await spawn(job,true)
	check(g.material_receipts.size() == 2 and g.receiver_commits.size() == 3 and g.material_recovery_value > 0.0 and is_equal_approx(g.income_metal,mixed_cash), "actual scene reconstruction restores raw stock, guards and cash without paying again")
	var report: Dictionary = g.settle_report()
	var before := JSON.stringify(Career.data)
	var wrong_job := report.duplicate(true)
	wrong_job.job_id = "ANOTHER-CONTRACT"
	var mismatch := Career.settle(wrong_job)
	check(mismatch.get("save_failed",false) and mismatch.get("reason","") == "settlement_job_mismatch" and JSON.stringify(Career.data) == before, "top-level report ID must match the actual active contract before any change")
	Career.path = "user://zp_g5_missing_%d/sub/career.json" % Time.get_ticks_usec()
	var result := Career.settle(report)
	check(result.get("save_failed",false) and JSON.stringify(Career.data) == before, "failed career disk commit rolls back raw inventory with cash and progression")
	Career.path = CAREER
	var invalid := report.duplicate(true)
	invalid.material_receipts.append(invalid.material_receipts[0].duplicate(true))
	result = Career.settle(invalid)
	check(result.get("save_failed",false) and JSON.stringify(Career.data) == before, "duplicate raw receipt rejects the entire transaction without partial credit")
	invalid = report.duplicate(true)
	invalid.material_receipts[0].asset_id = "ANOTHER-ASSET"
	result = Career.settle(invalid)
	check(result.get("save_failed",false) and JSON.stringify(Career.data) == before, "a receipt from a different asset cannot enter company inventory")
	result = Career.settle(report)
	check(not result.get("save_failed",false) and result.materials.batches == 2 and Career.data.material_batches.size() == 2, "normal atomic settlement persists both actual raw batches")
	var disk := SaveGame.read_career(CAREER)
	check(disk.material_batches == Career.data.material_batches, "career checksum file contains the same unique raw batch")
	before = JSON.stringify(Career.data)
	result = Career.settle(report)
	check(result.get("already_settled",false) and JSON.stringify(Career.data) == before, "retry cannot pay or stock the same job twice")
	await release()
	var legacy := {"id":"G5-LEGACY-001","ship":"pod","fee":0,"time":0,"kit":{},"items":{}}
	Career.data.active = legacy.duplicate(true)
	await spawn(legacy)
	await deliver("G5-LEGACY-PLATE")
	check(g.income_metal > 0.0 and is_equal_approx(g.structure_t,0.25) and g.material_receipts.is_empty(), "legacy contracts retain actual cash payment and original repair-stock behavior")
	SaveGame.save(g)
	var old_field := SaveGame.read()
	old_field.game.erase("material_receipts")
	old_field.game.erase("receiver_commits")
	SaveGame.write_file(FIELD,old_field)
	var legacy_cash: float = g.income_metal
	await release()
	await spawn(legacy,true)
	check(g.material_receipts.is_empty() and g.receiver_commits.is_empty() and is_equal_approx(g.income_metal,legacy_cash) and is_equal_approx(g.structure_t,0.25), "pre-G5 field disk reconstructs without new fields and preserves prior cash/repair stock")
	await release()
	var current := Career.data.duplicate(true)
	var old_career := Career.fresh()
	old_career.erase("material_batches")
	old_career.money = 12345.0
	old_career.done = 39
	old_career.structure_t = 7.25
	old_career.company = "LEGACY-COMPANY"
	old_career.user_extension = {"keep":true}
	Career.data = old_career
	Career.save()
	Career.data = {}
	Career.load_or_new()
	check(Career.data.material_batches.is_empty() and int(Career.data.done) == 39 and Career.data.company == "LEGACY-COMPANY" and is_equal_approx(Career.data.structure_t,7.25) and is_equal_approx(Career.data.money,12345.0) and Career.data.user_extension.keep, "pre-G5 career disk migrates to empty raw stock while preserving money, 39 jobs, company and extension data")
	Career.data = current
	Career.save()
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G5 MATERIAL INTAKE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
