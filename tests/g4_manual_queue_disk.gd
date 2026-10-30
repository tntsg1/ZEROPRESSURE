extends SceneTree
# Real field disk round-trip for explicit manual delivery order. Planned-only
# work (even with a historical manual mark) must remain unauthorized.
var g: Node
var checks := 0
var fails := 0
const FIELD := "user://zp_test_g4_manual_queue_save.json"
func _initialize() -> void: _run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
func spawn() -> void:
	Game.start_ship = "pod"
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO,"kit":{"hauler":1}}
	root.add_child(g)
	await frames(6)
	g.tutorial = null
	g.drone.global_position = Vector2(-5,-12)*Geom.M
func box(at: Vector2,key: String):
	var p = g.world.add_piece("cargo",PackedVector2Array([at+Vector2(-9,-9),at+Vector2(9,-9),at+Vector2(9,9),at+Vector2(-9,9)]),{"key":key,"cls":"equip","value":100.0,"mass":0.1})
	g.world.make_body([p],null)
	p.body.freeze = true
	p.body.linear_velocity = Vector2.ZERO
	p.body.angular_velocity = 0.0
	return p
func _run() -> void:
	Career.path = "user://zp_test_g4_manual_queue_career.json"
	Career.data = Career.fresh()
	Career.save()
	SaveGame.path = FIELD
	SaveGame.allow_test = true
	SaveGame.load_requested = false
	await spawn()
	g.toggle_auto()
	var a = box(Vector2(30,0)*Geom.M,"MANUAL-A")
	var b = box(Vector2(32,0)*Geom.M,"MANUAL-B")
	var p = box(Vector2(34,0)*Geom.M,"PLAN-ONLY")
	for piece in [b,a]:
		g.aim = Geom.centroid(g.world.world_poly(piece))
		g.mark_salvage()
	g.plan_mark(p.body,"equip")
	p.body.set_meta("manual_mark",true)
	g.plan.preset = false
	g.plan.steps = [{"do":"haul","keys":[p.key],"zone":"equip","pre":[]}]
	g.plan.i = 1
	g.plan.haul_watch = [{"keys":[p.key],"zone":"equip"}]
	g.plan.running = false
	var pose: Vector2 = b.body.global_position
	SaveGame.save(g)
	var data: Dictionary = SaveGame.read()
	check(data.get("operator_hauls",[]).size() == 2 and data.operator_hauls[0].keys == ["MANUAL-B"] and data.operator_hauls[1].keys == ["MANUAL-A"],"disk records explicit operator queue order and excludes the plan-owned load")
	check(data.get("auto_paused",false),"global machine pause is part of the actual field save")
	g.queue_free()
	await frames(5)
	SaveGame.load_requested = true
	await spawn()
	a = g.world.key_piece("MANUAL-A")
	b = g.world.key_piece("MANUAL-B")
	p = g.world.key_piece("PLAN-ONLY")
	check(g.auto_paused and g.hauler.body == null,"loaded machine pause prevents automatic pickup before operator resume")
	check(g.hauler.queue == [b.body,a.body],"full scene reconstruction restores the original manual delivery sequence")
	check(not g.plan.running and not g.hauler.queue.has(p.body),"saved plan dispatch still requires renewed authorization even if its old manual mark exists")
	check(b.body.global_position.distance_to(pose) < 0.1,"queue recovery keeps the physical load at its saved location")
	g.toggle_auto()
	await frames(2)
	check(g.hauler.body == b.body,"resuming the real machine starts the first restored operator command")
	g.queue_free()
	await frames(5)
	# Compatible older field with only per-body marks and no queue/pause fields.
	data.erase("operator_hauls")
	data.erase("auto_paused")
	var file := FileAccess.open(FIELD,FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	SaveGame.load_requested = true
	await spawn()
	a = g.world.key_piece("MANUAL-A")
	b = g.world.key_piece("MANUAL-B")
	p = g.world.key_piece("PLAN-ONLY")
	var resumed: Array = g.hauler.queue.duplicate()
	if is_instance_valid(g.hauler.body): resumed.append(g.hauler.body)
	check(not g.auto_paused and resumed.has(a.body) and resumed.has(b.body),"legacy per-object marks recover manual intent with a compatible default pause state")
	check(not resumed.has(p.body) and not g.plan.running,"legacy recovery cannot bypass saved plan authorization")
	# Real scheduling: an explicit request interrupts unasked approach, while
	# a physically gripped delivery keeps its place until it reaches intake.
	g.hauler.halt()
	g.hauler.queue.clear()
	g.hauler._set_off(a.body,true)
	g.hauler.queue.append(b.body)
	await frames(2)
	check(g.hauler.body == b.body and not a.body.get_meta("arm",false),"explicit delivery preempts an unasked pickup and releases its claim")
	g.hauler.pos = b.body.global_transform*b.body.center_of_mass
	g.hauler.vel = Vector2.ZERO
	for i in 90:
		await process_frame
		if g.hauler.state == "carry": break
	check(g.hauler.state == "carry","priority target is physically gripped through the normal machine state")
	g.hauler.queue.append(a.body)
	await frames(2)
	check(g.hauler.body == b.body and g.hauler.queue.has(a.body),"a subsequent request does not drop an already carried load")
	g.queue_free()
	await frames(5)
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G4 MANUAL QUEUE DISK %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
