extends SceneTree
# Start from a real completed engineering route, then take an ordinary contract.
# A small declared loose-body fixture tests the restored platform's physical
# damping; it is not evidence of another human-played salvage operation.
const Orders = preload("res://scripts/work_orders.gd")
var checks := 0
var fails := 0
func _initialize() -> void: _run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
func _run() -> void:
	SaveGame.allow_test = false
	SaveGame.load_requested = false
	for route in ["separate","whole"]:
		Career.path = "user://zp_test_g4_heavy_%s_career.json" % route
		Career.data = {}
		Career.load_or_new()
		check(Orders.done("heavy") and Repair.done("buffer") and Career.active().is_empty(),route+": reloads the actual delivered facility reward")
		if not Orders.done("heavy"): continue
		Career.path = "user://zp_test_g4_facility_return_%s.json" % route
		Career.save()
		var offer := Market.offer_for(441224,Career.data,1,"full","pod")
		Career.data.offers = [offer]
		var job: Dictionary = Career.accept(0)
		check(not job.is_empty() and job.get("kit",{}).has("buffer"),route+": the next ordinary contract inherits the engineering-built platform")
		Game.contract = job
		Game.start_ship = "pod"
		var g = load("res://scenes/main.tscn").instantiate()
		g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
		root.add_child(g)
		await frames(8)
		g.tutorial = null
		g.drone.global_position = Vector2(10,-5)*Geom.M
		var at := Dock.BUFFER.get_center()*Geom.M
		var p = g.world.add_piece("cargo",PackedVector2Array([at+Vector2(-8,-8),at+Vector2(8,-8),at+Vector2(8,8),at+Vector2(-8,8)]),{"key":"G4-PLATFORM-PROBE","cls":"equip","mass":0.1})
		g.world.make_body([p],null)
		var body = p.body
		body.ghost = 0.0
		body.calm = 0.0
		body.linear_velocity = Vector2(40,0)
		check(g.has_upgrade("buffer") and g.dock.in_buffer(body),route+": saved reward activates the real platform region in the new field")
		await frames(60)
		check(body.capture == null and body.linear_velocity.length() < 5.0 and g.dock.in_buffer(body),route+": the restored platform physically arrests a drifting load without selling it")
		check(not g.job.get("kit",{}).has("crane"),route+": the rented engineering crane has not become a permanent upgrade")
		g.queue_free()
		await frames(5)
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G4 FACILITY RETURN %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
