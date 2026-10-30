extends SceneTree
var g: Node
var checks := 0
var fails := 0
func _initialize() -> void: _run.call_deferred()
func frames(n: int) -> void:
	for k in n: await process_frame
func check(ok: bool,what: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",what])
func _run() -> void:
	Career.path = "user://zp_test_g4_roof_career.json"
	SaveGame.path = "user://zp_test_g4_roof_save.json"
	SaveGame.allow_test = true
	Career.data = Career.fresh()
	Career.save()
	Game.start_ship = "gr7"
	Game.contract = {"id":"G4-ROOF-CHECK","ship":"gr7","fee":0,"time":1800,"kit":{"hauler":1}}
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO,"kit":{"hauler":1}}
	root.add_child(g)
	await frames(8)
	g.tutorial = null
	var book = g.plan.packages
	check(book.catalogue.any(func(d):return d.id == "gr7:roof:access"),"the existing GR-7 offers a ready-to-use authored local cutting package")
	check(book.authorize(["preset:gr7:preparation","gr7:roof:access"]),"preparation and local cutting can be authorized together")
	g.plan.package_mode = true
	g.plan.running = true
	var previous := ""
	for k in 30000:
		await process_frame
		var preparation = book._job("preset:gr7:preparation").worker
		var roof = book._job("gr7:roof:access").worker
		var status := "%d/%d %s · cut %d %s" % [preparation.i,preparation.steps.size(),preparation.wait_arg,roof.i,roof.wait]
		if status != previous:
			print(status)
			previous = status
		if not g.plan.running: break
		if book.complete(book._job("preset:gr7:preparation")) and roof.wait != "": break
	var roof_job = book._job("gr7:roof:access")
	check(book.complete(book._job("preset:gr7:preparation")),"the authored safety procedure actually depressurizes and isolates the ship")
	check(book.complete(roof_job),"the real GR-7 skin reaches both verified cut results")
	var detached := false
	for p in g.world.pieces.values():
		if p.key.begins_with("p7") and p.body != null and not p.gone: detached = true
	check(detached,"the cargo skin fragment actually separates into a physical body")
	var cargo = g.world.key_piece("C-01")
	check(cargo != null and cargo.intact and cargo.cond >= 0.99,"the preserved cargo remains intact")
	check(g.incidents.is_empty(),"preparation and automatic local cutting cause no incident")
	check(int(g.ops.get("cut",0)) == 0 and int(g.ops.get("plan",0)) > 0,"the preset is available without recording manual cuts first")
	g.queue_free()
	await frames(5)
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec() < drain: await process_frame
	print("G4 ROOF %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
