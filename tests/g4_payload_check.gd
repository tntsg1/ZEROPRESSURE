extends SceneTree
# Controlled physical obstacles, not a claim of playing an authored commission.
# Both real carrier state machines must retain collision and refuse a doorway
# which fits an empty drone but not its 5.55 m load; removing the fixture wall
# must allow real intake and payment without moving the load by the test.
const Motion = preload("res://scripts/load_motion.gd")
var g: Node
var checks := 0
var fails := 0
func _initialize() -> void: _run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
func rect(at: Vector2, size: Vector2, key: String, mass: float, equipment: bool):
	var a := at-size*0.5
	var b := at+size*0.5
	return g.world.add_piece("cargo" if equipment else "hull",PackedVector2Array([a,Vector2(b.x,a.y),b,Vector2(a.x,b.y)]),{"key":key,"cls":"equip" if equipment else "metal","barrier":not equipment,"mass":mass,"value":200.0})
func fixture(machine: String) -> void:
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "pod"
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO,"kit":{machine:1}}
	root.add_child(g)
	await frames(8)
	g.tutorial = null
	g.drone.global_position = Vector2(-5,-12)*Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	var m = g.hauler if machine == "hauler" else g.crane
	var center := Vector2(Dock.zpos("equip_bulk").x,0)
	var p = rect(center,Vector2(5.55,1.25)*Geom.M,"PAYLOAD-"+machine,1.0 if machine == "hauler" else 5.0,true)
	g.world.make_body([p],null)
	var b = p.body
	b.freeze = true
	var left := Dock.BOUNDS.position.x*Geom.M
	var right := Dock.BOUNDS.end.x*Geom.M
	var gap := 3.0*Geom.M
	var walls: Array = []
	walls.append(rect(Vector2((left+center.x-gap*0.5)*0.5,-3*Geom.M),Vector2(center.x-gap*0.5-left,12),"LEFT",1,false))
	walls.append(rect(Vector2((right+center.x+gap*0.5)*0.5,-3*Geom.M),Vector2(right-center.x-gap*0.5,12),"RIGHT",1,false))
	# One side is attached non-barrier furniture, like the real cargo rail.
	# It still has collision and must be included in loaded navigation.
	walls[0].kind = "rib"
	walls[0].barrier = false
	for wall in walls: g.world.rebuild_cols(wall)
	await frames(8)
	g.nav_grid().dirty = true
	g.nav_grid()._built_frame = -100000
	check(not Motion.fits(b,Dock.ZONES.equip.w*Geom.M,Vector2.DOWN),machine+": real load is wider than the standard receiving mouth")
	check(Dock.for_load("equip",b) == "equip_bulk",machine+": oversized equipment is routed to the outside receiving rack")
	var empty: PackedVector2Array = g.nav_grid().path(center,center+Vector2(0,-6*Geom.M),26.0,false)
	var loaded: PackedVector2Array = g.nav_grid().payload_path(center,center+Vector2(0,-6*Geom.M),Motion.half_extents(b))
	check(not empty.is_empty() and loaded.is_empty(),machine+": doorway admits empty drone but refuses the actual payload footprint")
	if machine == "hauler":
		check(not m._delivery_reachable(b),"unasked unreachable scrap does not monopolize the hauler ahead of marked work")
	m.pos = center
	m.toggle(b)
	for i in 500:
		await process_frame
		if m.state == "carry" and m.wait_reason != "": break
	check(m.state == "carry" and b.collision_layer == 1 and b.collision_mask == FreeBody.MASK,machine+": real pickup retains all payload collisions")
	await frames(120)
	check(b.capture == null and b.global_position.y > -2.25*Geom.M and m.wait_reason != "",machine+": narrow doorway stops the load and reports an actionable wait")
	g.plan.steps = [{"do":"haul","keys":[p.key],"zone":"equip"}]
	g.plan.haul_watch = [{"keys":[p.key],"zone":"equip"}]
	g.plan.i = 1
	g.plan.running = true
	g.plan.package_mode = false
	g.plan.set_physics_process(false)
	check(g.plan.status()[1].contains(Txt.t(m.wait_reason)),machine+": plan panel identifies the blocked target and physical obstruction")
	if "--capture" in OS.get_cmdline_user_args() and machine == "hauler":
		g.cam_override = Dock.zpos("equip_bulk")+Vector2(0,150)
		g.cam_pos = g.cam_override
		g.cam_vel = Vector2.ZERO
		g.zoom_override = 1.2
		g.zoom_now = 1.2
		await frames(8)
		await RenderingServer.frame_post_draw
		preload("res://tests/cap.gd").save(root,"res://proofs/g4_bulk_receiving.png")
	# Specifically challenge the native sweep, independently of grid refusal.
	var before: Vector2 = b.global_position
	check(not Motion.move(b,Vector2(0,-6*Geom.M)) and b.global_position == before,machine+": full-body sweep rejects a displacement through the wall")
	for wall in walls: g.world.remove_piece(wall)
	g.nav_grid().dirty = true
	g.nav_grid()._built_frame = -100000
	for i in 2400:
		await process_frame
		if p.gone: break
	check(p.gone and g.income_equip > 0,machine+": clearing the doorway resumes actual transport, intake and payment")
	check(m.wait_reason == "",machine+": obstruction indication clears after delivery")
	g.queue_free()
	await frames(5)
func _run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	SaveGame.allow_test = false
	await fixture("hauler")
	await fixture("crane")
	await precise_corridor()
	await wide_load_clearance()
	await reachable_start_projection()
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G4 PAYLOAD %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)

func precise_corridor() -> void:
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "pod"
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO,"kit":{"hauler":1}}
	root.add_child(g)
	await frames(8)
	g.tutorial = null
	g.drone.global_position = Vector2(-5,-12)*Geom.M
	var center := Vector2(Dock.zpos("equip_bulk").x,0)
	var p = rect(center,Vector2(2.4,1.8)*Geom.M,"PRECISE-LOAD",1,true)
	g.world.make_body([p],null)
	p.body.freeze = true
	var left := Dock.BOUNDS.position.x*Geom.M
	var right := Dock.BOUNDS.end.x*Geom.M
	var gap := 2.7*Geom.M
	var a = rect(Vector2((left+center.x-gap*0.5)*0.5,-3*Geom.M),Vector2(center.x-gap*0.5-left,12),"PRECISE-LEFT",1,false)
	var b = rect(Vector2((right+center.x+gap*0.5)*0.5,-3*Geom.M),Vector2(right-center.x-gap*0.5,12),"PRECISE-RIGHT",1,false)
	g.world.rebuild_cols(a)
	g.world.rebuild_cols(b)
	await frames(6)
	g.nav_grid().dirty = true
	g.nav_grid()._built_frame = -100000
	var way: PackedVector2Array = g.nav_grid().payload_path(center,center+Vector2(0,-6*Geom.M),Motion.half_extents(p.body))
	check(not way.is_empty(),"full-size precise fallback finds the physically valid 2.7 m opening for a 2.4 m cargo")
	g.hauler.pos = center
	g.hauler.toggle(p.body)
	for i in 1800:
		await process_frame
		if p.gone: break
	check(p.gone and g.income_equip > 0,"real hauler traverses the narrow opening with collision retained and actually delivers")
	g.queue_free()
	await frames(5)

func wide_load_clearance() -> void:
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "pod"
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO,"kit":{"hauler":1}}
	root.add_child(g)
	await frames(8)
	g.tutorial = null
	g.drone.global_position = Vector2(-5,-12)*Geom.M
	var center := Vector2(Dock.zpos("equip_bulk").x,0)
	var p = rect(center,Vector2(5.55,1.25)*Geom.M,"WIDE-CLEARANCE",1,true)
	g.world.make_body([p],null)
	p.body.freeze = true
	var obstruction = rect(center+Vector2(5.55*Geom.M*0.5+4,-65),Vector2(16,16),"EDGE-OBSTRUCTION",0.3,false)
	g.world.make_body([obstruction],null)
	var blocker = obstruction.body
	var start: Vector2 = blocker.global_position
	check(start.distance_to(center) > Hauler.AVOID_R,"loaded-edge obstruction lies outside the old drone-centre clearance radius")
	g.hauler.pos = center
	g.hauler.toggle(p.body)
	for i in 1800:
		await process_frame
		if p.gone: break
	check(blocker.global_position.x > start.x+3.0,"gentle clearance actually pushes debris away from the wide load's edge")
	check(blocker.linear_velocity.length() < 100,"payload-edge clearing keeps the existing limited push budget")
	check(p.gone and g.income_equip > 0,"wide loaded transport clears loose debris and completes real delivery")
	g.queue_free()
	await frames(5)

func reachable_start_projection() -> void:
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "pod"
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO,"kit":{"hauler":1}}
	root.add_child(g)
	await frames(8)
	g.tutorial = null
	var at := Vector2(30,0)*Geom.M
	var load = rect(at,Vector2(20,20),"FLOOR-TOUCHING-LOAD",0.1,true)
	g.world.make_body([load],null)
	load.body.freeze = true
	var floor_piece = rect(at+Vector2(0,20),Vector2(120,8),"PROJECTION-FLOOR",1,false)
	g.world.rebuild_cols(floor_piece)
	await frames(5)
	var nav = g.nav_grid()
	nav._fresh()
	nav.origin = at-Vector2(6.5,6.5)*nav.CELL
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0,0,14,14)
	grid.update()
	grid.fill_solid_region(grid.region,true)
	var below := Vector2i(6,8)
	var above := Vector2i(6,3)
	grid.set_point_solid(below,false)
	grid.set_point_solid(above,false)
	check(nav._open_near(grid,at) == below,"nearest coarse start cell can lie across an actual floor")
	check(nav._payload_start(grid,at,load.body) == above,"payload start selection rejects the floor-crossing join and finds the reachable cell")
	check(not Motion.clear_to(load.body,Vector2(0,24)) and Motion.clear_to(load.body,Vector2(0,-36)),"start projection uses the real unchanged compound collision shape")
	# Isolate the contact response with a declared already-gripped fixture.
	# The original motion hits the floor; its tangent must stay above it.
	g.hauler.pos = at
	g.hauler._set_off(load.body)
	g.hauler.state = "carry"
	var before: Vector2 = load.body.global_position
	check(g.hauler._advance(Vector2(6,24)),"a blocked diagonal can retain a physically clear contact tangent")
	check(load.body.global_position.distance_to(before+Vector2(6,0)) < 0.05 and load.body.collision_mask == FreeBody.MASK,"contact sliding retains full collision and never crosses the floor")
	g.queue_free()
	await frames(5)
