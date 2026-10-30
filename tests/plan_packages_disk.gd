extends SceneTree
var g: Node
var checks := 0
var fails := 0
func _initialize() -> void:
	# 61 号 hides the work plans in play (G4_OPEN); these check the plans themselves
	Game.G4_OPEN = true
	_run.call_deferred()
func frames(n: int) -> void:
	for k in n: await process_frame
func check(ok: bool,what: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",what])
func spawn() -> void:
	Game.contract = {}
	Game.start_ship = "pod"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO,"kit":{"hauler":1}}
	root.add_child(g)
	await frames(6)
	g.tutorial = null
	g.drone.global_position = Vector2(-5,-12)*Geom.M
func _run() -> void:
	# the work plans are put away in the game (G4); their tests switch them on (as tests/plan_settlement.gd)
	Game.G4_OPEN = true
	Career.path = "user://zp_test_g4_package_disk_career.json"
	SaveGame.path = "user://zp_test_g4_package_disk_save.json"
	Career.data = Career.fresh()
	Career.save()
	SaveGame.allow_test = true
	await spawn()
	g.plan.set_physics_process(false)
	g.hauler.set_physics_process(false)
	var at: Vector2 = Dock.zpos("equip")+Dock.ZONES.equip.face*3.0*Geom.M
	var p = g.world.add_piece("cargo",PackedVector2Array([at+Vector2(-9,-9),at+Vector2(9,-9),at+Vector2(9,9),at+Vector2(-9,9)]),{"key":"DISK-LOAD","cls":"equip","mass":0.1,"value":100.0})
	g.world.make_body([p],null)
	p.body.set_meta("manual_mark",true)
	g.plan.packages.catalogue = [{"id":"haul","version":1,"label":"Pending equipment delivery","steps":[{"do":"haul","keys":[p.key],"zone":"equip","pre":[]}]}]
	g.plan.packages.authorize(["haul"])
	g.plan.package_mode = true
	g.plan.running = true
	g.plan.packages.tick(1.0)
	g.plan.packages.tick(1.0)
	# planned loads go to the rail arm now (game.gd arm_extract: "a rail arm extracts planned loads
	# through hulls", the owner's choice), not the hauler's queue
	check(p.body.get_meta("arm_extraction",false) and p.body.get_meta("plan_dispatch",false),"the real load is given to the arm before the disk save")
	SaveGame.save(g)
	check(not SaveGame.read().is_empty(),"the active package and physical world are written atomically")
	g.queue_free()
	await frames(5)
	SaveGame.load_requested = true
	await spawn()
	var book = g.plan.packages
	var job = book._job("haul")
	check(g.plan.package_mode and job != null and job.worker.i == 1 and job.worker.haul_watch.size() == 1,"full scene reconstruction restores outstanding package delivery")
	var restored = g.world.key_piece("DISK-LOAD")
	check(restored != null and restored.body.get_meta("manual_mark",false) and restored.body.get_meta("plan_dispatch",false),"body ownership and deliberate marking survive disk reload")
	check(not g.plan.running and g.hauler.queue.is_empty(),"reloading does not dispatch work without renewed authorization")
	check(book.catalogue.any(func(d):return d.id == "haul") and g.plan.has_plan(),"the saved authorized revision remains available in the preview")
	g.plan.toggle()
	for k in 4200:
		await process_frame
		if not g.plan.running: break
	check(book.complete(job) and g.income_equip > 0,"resuming after disk reload physically delivers the outstanding load")
	check(g.plan.status()[1] == Txt.t("plan_done"),"delivery reaches the correct completed package state")
	g.queue_free()
	await frames(5)
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("PACKAGE DISK %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
