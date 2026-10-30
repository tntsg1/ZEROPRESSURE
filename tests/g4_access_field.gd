extends SceneTree
# Authored GR-7 engineering source: use production safety, laser, wrench,
# hauler, physical mouths and Career settlement. Drone positioning is staged;
# this verifies the field route, not human piloting or subjective pacing.
const Orders = preload("res://scripts/work_orders.gd")
var g: Node
var checks := 0
var fails := 0
func _initialize() -> void: _run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
func unfix(piece) -> void:
	for j in g.world.joints_of(piece).duplicate():
		g.do_wrench({"kind":"joint","joint":j,"pos":g.world.joint_world(j)})
		await frames(2)
func _run() -> void:
	Career.path = "user://zp_test_g4_access_field_career.json"
	SaveGame.path = "user://zp_test_g4_access_field_save.json"
	SaveGame.allow_test = true
	var resume := "--resume" in OS.get_cmdline_user_args()
	SaveGame.load_requested = resume
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.market = true
	Career.data.done = 3
	Career.data.money = 50000.0
	Career.save()
	var why := Orders.take("access")
	check(why == "","real engineering entry signs the authored access commission: "+why)
	if why != "":
		quit(1)
		return
	Game.start_ship = "gr7"
	Game.contract = Career.active()
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	await frames(8)
	g.tutorial = null
	g.drone.global_position = Vector2(-5,-12)*Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	if not resume:
		await prepare_field()
		SaveGame.save(g)
	else:
		print("Restored isolated snapshot after actual authored preparation, cuts and disconnects")
	var cargo = g.world.key_piece("C-03")
	if cargo.body != null:
		if "--diagnose" in OS.get_cmdline_user_args():
			g.hauler.halt()
			g.hauler.queue.clear()
			g.hauler.pos = cargo.body.global_transform*cargo.body.center_of_mass
			g.hauler.vel = Vector2.ZERO
		g.aim = g.world.frame(cargo)*Geom.centroid(cargo.poly)
		g.mark_salvage()
	var last := ""
	var dumped := false
	var state_before := ""
	for i in 9000:
		await process_frame
		var h = g.hauler
		if h.state != state_before:
			print("STATE ",state_before," -> ",h.state," carrier=",h.pos/Geom.M," cargo=",cargo.body.global_position/Geom.M if cargo.body != null else Vector2.INF)
			state_before = h.state
		if "--diagnose" in OS.get_cmdline_user_args() and h.body == cargo.body and h.wait_reason == "load_obstructed":
			print("NATIVE BLOCK ",h.body.get_meta("carrier_obstacle","none")," normal=",h.body.get_meta("carrier_normal",Vector2.ZERO)," route=",h.route," position=",h.pos," vel=",h.vel)
			for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
				print("TEST MOTION ",direction," = ",preload("res://scripts/load_motion.gd").clear_to(h.body,direction*6))
			break
		var status := "%s %s pos=%s cargo=%s load=%s box_px=%s zone=%s" % [h.state,h.wait_reason,str(h.pos/Geom.M),str(cargo.body.global_position/Geom.M) if cargo.body != null else "gone",str(h.body.pieces.map(func(p):return p.key)) if is_instance_valid(h.body) else "none",str(preload("res://scripts/load_motion.gd").bounds(h.body)) if is_instance_valid(h.body) else "none",h.zone]
		if i % 600 == 0 and status != last:
			print(status)
			if is_instance_valid(h.body): print("COLLISION ",h.body.get_meta("carrier_obstacle","none"))
			last = status
		if not dumped and h.body == cargo.body and h.state == "carry" and h.wait_reason != "":
			dumped = true
			print("NAV profiles=",g.nav_grid().box_grids.keys()," precise=",g.nav_grid().box_precise.keys())
			var nav = g.nav_grid()
			var destination: Vector2 = h._drop_point(h.zone)
			var half: Vector2 = preload("res://scripts/load_motion.gd").half_extents(h.body)
			var way: PackedVector2Array = nav.payload_path(h.pos,destination,half)
			var key := Vector2i(ceili(half.x),ceili(half.y))
			var grid: AStarGrid2D = nav.box_grids[key]
			print("NAV details half=",half," to=",destination," nodes=",way.size()," from_cell=",nav._open_near(grid,h.pos)," solid=",grid.is_point_solid(nav._open_near(grid,h.pos))," to_cell=",nav._open_near(grid,destination)," solid=",grid.is_point_solid(nav._open_near(grid,destination))," refined=",nav.box_precise.keys())
			for piece in g.world.pieces.values():
				if not g.world.static_cols.has(piece.id): continue
				var box := Geom.bbox(g.world.world_poly(piece))
				if box.intersects(Rect2(Vector2(18,-5)*Geom.M,Vector2(4.5,8.5)*Geom.M)):
					print("EXIT ATTACHED ",piece.key," ",box," door=",piece.door," open=",piece.open_t)
		if g.work_order.complete(): break
	check(g.work_order.complete(),"actual C-03 reaches equipment recovery and becomes an engineering reservation")
	check(g.incidents.is_empty(),"the complete physical access route causes no incident")
	if g.work_order.complete():
		g.finish_contract(true)
		await frames(2)
		check(g.order_review != null and not g.ended,"actual recovered cargo reaches the pre-commit engineering choice")
		if g.order_review != null: g.order_review.confirm_button.pressed.emit()
		await frames(5)
		check(Orders.done("access") and Career.data.work_orders.methods.get("locked_anchor",false),"early settlement commits delivery and unlocks the next physical method")
		check(Orders.reason("rigging") == "","second commission becomes available through the actual saved result")
	g.queue_free()
	await frames(5)
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G4 ACCESS FIELD %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)

func prepare_field() -> void:
	Engine.time_scale = 4.0
	g.plan.toggle()
	for i in 26000:
		await process_frame
		if not g.plan.running: break
	check(g.plan.i == g.plan.steps.size() and g.incidents.is_empty(),"actual preparation opens the cargo hatch and makes systems safe without accidents")
	Engine.time_scale = 1.0
	# The overhead rail and its rib obstruct the otherwise open cargo hatch.
	# Unbolt the rib, then cut manageable rail sections. No connections are
	# deleted by the test and no load position is assigned.
	# A full-height rib cannot turn under the ship. Cut it to manageable
	# lengths before releasing its two anchored halves.
	g.cut_kerf(g.world.key_piece("p52"),PackedVector2Array([Vector2(18.6,0)*Geom.M,Vector2(19.1,0)*Geom.M]))
	for p in g.world.pieces.values():
		if not p.gone and p.key.begins_with("p52"): await unfix(p)
	for x in [18.1,20.0,21.0,22.2]:
		var point := Vector2(x,-3.4)*Geom.M
		var rail = null
		for p in g.world.pieces.values():
			if not p.gone and p.key.begins_with("RAIL-C") and g.world.piece_contains(p,point):
				rail = p
				break
		if rail == null:
			check(false,"rail piece exists at authored kerf %.1f" % x)
			continue
		g.cut_kerf(rail,PackedVector2Array([Vector2(x,-3.65)*Geom.M,Vector2(x,-3.15)*Geom.M]))
		await frames(3)
	check(g.plan.cuts_rec >= 5,"real field laser operations record the rib cut and four access kerfs")
	var cargo = g.world.key_piece("C-03")
	for line in g.world.lines.values():
		if line.alive and (line.a == cargo.id or line.b == cargo.id):
			var end := 0 if line.a == cargo.id else 1
			g.do_wrench({"kind":"connector","line":line,"end":end,"pos":g.world.line_end_world(line,end)})
	await unfix(cargo)
	await frames(8)
	check(cargo.body != null and cargo.intact and cargo.cond >= 0.99,"normal disconnection and unlocking free the actual intact target")
