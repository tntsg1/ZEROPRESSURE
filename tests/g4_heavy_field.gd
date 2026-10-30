extends SceneTree
# Two actual routes from the saved second-commission result. --whole preserves
# the original cradle and its underside shell as a near-capacity crane module;
# default recovers the two devices separately through an authored roof opening.
# Tool actions use production APIs. Operator positioning is staged, loads never
# receive test-assigned transforms, and this is not a human pacing claim.
const Orders = preload("res://scripts/work_orders.gd")
var g: Node
var checks := 0
var fails := 0
var whole := false
func _initialize() -> void: _run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
func cut_at(key: String, at: Vector2, delta: Vector2) -> void:
	var p = null
	for q in g.world.pieces.values():
		if not q.gone and (q.key == key or q.key.begins_with(key+"~")) and g.world.piece_contains(q,at):
			p = q
			break
	if p == null:
		check(false,"production cut finds "+key+" at "+str(at/Geom.M))
		return
	g.cut_kerf(p,PackedVector2Array([at-delta,at+delta]))
	await frames(3)
func unplug_lines(ids: Array) -> void:
	for id in ids:
		var line = g.world.lines[id]
		if not line.alive: continue
		g.do_wrench({"kind":"connector","line":line,"end":0,"pos":g.world.line_end_world(line,0)})
		await frames(3)
func mark(p) -> void:
	if p == null or p.body == null:
		check(false,"marked target is a real free body")
		return
	for machine in g.haulers():
		if machine.body == p.body or machine.queue.has(p.body): return
	if g.crane != null and (g.crane.body == p.body or g.crane.queue.has(p.body)): return
	g.aim = g.world.frame(p)*Geom.centroid(p.poly)
	g.mark_salvage()
func wait_for_piece(p, label: String) -> bool:
	for i in 3600:
		await process_frame
		if p.gone:
			print("SEPARATE CLEARANCE DELIVERED ",label)
			return true
	print("SEPARATE CLEARANCE WAIT ",label," state=",g.hauler.state," reason=",g.hauler.wait_reason)
	if is_instance_valid(g.hauler.body):
		print("WAIT ROUTE ",g.hauler.route.slice(0,mini(6,g.hauler.route.size()))," pos=",g.hauler.pos," body_com=",g.hauler.body.global_transform*g.hauler.body.center_of_mass," normal=",g.hauler.body.get_meta("carrier_normal",Vector2.ZERO))
	return false
func whole_route() -> void:
	var mount = g.world.key_piece("K4")
	g.gear.act({"kind":"place","type":"anchor","piece":mount,"pos":Geom.centroid(mount.poly)})
	check(g.gear.units.any(func(u):return u.type == "anchor" and u.mode == "hold"),"whole route uses cable support before releasing the heavy module")
	await unplug_lines(["q1","q3"])
	await cut_at("K3",Vector2(26.55,3.4)*Geom.M,Vector2(0,0.45)*Geom.M)
	await cut_at("p19",Vector2(26.55,3.85)*Geom.M,Vector2(0,0.45)*Geom.M)
	await cut_at("p42",Vector2(27.0,2.8)*Geom.M,Vector2(0.3,0)*Geom.M)
	# Keep the original K4 bolts and the underside skin. Release only the
	# external engine-beam bolt and the dock clamp; welded material is cut.
	for j in g.world.joints.duplicate():
		if not j.alive: continue
		var a = g.world.pieces.get(j.a)
		var b = g.world.pieces.get(j.b)
		var external: bool = j.type == "bolt" and a != null and b != null and ((a.key == "BEAM-B" and b.key == "p16") or (b.key == "BEAM-B" and a.key == "p16"))
		if external or j.type == "clamp" and str(j.get_meta("tag","")) == "CL-04":
			g.do_wrench({"kind":"joint","joint":j,"pos":g.world.joint_world(j)})
			await frames(3)
	await frames(90)
	var load = mount.body
	check(load != null and g.world.key_piece("CP-E").body == load and g.world.key_piece("RAD").body == load,"real cuts and external release free pump, radiator and intact cradle as one connected module")
	if load == null: return
	print("WHOLE MODULE tonnes=",load.total_mass()," keys=",load.pieces.map(func(p):return p.key)," bounds=",preload("res://scripts/load_motion.gd").bounds(load))
	check(load.total_mass() > Hauler.MAX_T and load.total_mass() <= Crane.MAX_T,"whole module requires the actual crane and remains within its unchanged 12 t rating")
	check(g.work_order.accepts_assembly(load) and g.judge(load,"equip").ok and g.hud._zone_for(load) == "equip","qualified physical cradle assembly is accepted and guided to equipment recovery despite its structural mass")
	for u in g.gear.units.duplicate(): g.gear.retrieve(u)
	mark(mount)
	check(g.crane.queue.has(load) or g.crane.body == load,"normal mark dispatches the real heavy module to the crane")
func separate_route() -> void:
	# Two manageable skin/rail segments open a passage wide enough for RAD,
	# without relying on the crane or deleting a welded connection directly.
	for x in [24.35,25.45,26.55]:
		await cut_at("p11",Vector2(x,-3.75)*Geom.M,Vector2(0,0.4)*Geom.M)
		await cut_at("RAIL-C",Vector2(x,-3.4)*Geom.M,Vector2(0,0.3)*Geom.M)
	await unplug_lines(["q1","q3","q4"])
	# Open the door-frame welds as well. A released radiator can rotate, so
	# preserving only the original 2 m aperture is not a reliable loaded exit.
	await cut_at("p41",Vector2(26.9,0.0)*Geom.M,Vector2(0,0.8)*Geom.M)
	await cut_at("p42",Vector2(26.9,2.825)*Geom.M,Vector2(0,0.3)*Geom.M)
	# CP-E occupies the turn between the deck and door frame. Clear it before
	# the taller cabinet; the cabinet must in turn leave before releasing RAD.
	# Releasing all three together creates a genuine physical traffic jam.
	for key in ["CP-E","TCAB","RAD"]:
		var p = g.world.key_piece(key)
		for j in g.world.joints_of(p).duplicate():
			if j.type != "bolt": continue
			g.do_wrench({"kind":"joint","joint":j,"pos":g.world.joint_world(j)})
			await frames(3)
		await frames(3)
		check(p.body != null and p.intact and p.cond >= 0.99 and p.body.total_mass() <= Hauler.MAX_T,"separate "+key+" becomes an intact hauler-sized free body through normal disconnection")
		mark(p)
		var received: bool = await wait_for_piece(p,key)
		check(received,"separate route receives "+key+" before releasing the next constrained load")
		if not received: return
func _run() -> void:
	whole = "--whole" in OS.get_cmdline_user_args()
	Career.path = "user://zp_test_g4_rigging_field_career.json"
	Career.data = {}
	Career.load_or_new()
	check(Orders.done("rigging") and Career.active().is_empty(),"heavy delivery starts from the actual completed cable-and-floor commission")
	if fails > 0:
		quit(1)
		return
	Career.path = "user://zp_test_g4_heavy_%s_career.json" % ("whole" if whole else "separate")
	Career.save()
	SaveGame.allow_test = false
	SaveGame.load_requested = false
	var resume := "--resume" in OS.get_cmdline_user_args()
	SaveGame.path = "user://zp_test_g4_heavy_%s_fixture.json" % ("whole" if whole else "separate")
	SaveGame.allow_test = true
	SaveGame.load_requested = resume
	var options := Orders.reward_options()
	var reward := "buffer" if options.has("buffer") else str(options[0])
	check(Orders.take("heavy",reward,whole) == "","real heavy source signs with the selected facility and route")
	Game.start_ship = "gr7"
	Game.contract = Career.active()
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	await frames(8)
	g.tutorial = null
	g.autosave_t = -1000000.0
	g.drone.global_position = Vector2(-5,-12)*Geom.M
	if resume:
		print("RESTORED real prepared heavy-route fixture")
		for key in (["K4"] if whole else ["CP-E","RAD"]):
			var p = g.world.key_piece(key)
			if p != null and p.body != null: mark(p)
		if "--diagnose" in OS.get_cmdline_user_args():
			g.hauler.halt()
			g.hauler.queue.clear()
			var rad = g.world.key_piece("RAD")
			if rad != null and rad.body != null:
				g.hauler.pos = rad.body.global_transform*rad.body.center_of_mass
				g.hauler.vel = Vector2.ZERO
				mark(rad)
	else:
		await prepare_source()
		SaveGame.save(g)
	await finish_route(reward)

func prepare_source() -> void:
	var book = g.plan.packages
	check(book.authorize(["preset:gr7:preparation"]),"built-in safety remains usable beside the second commission's learned cuts")
	g.plan.package_mode = true
	g.plan.running = true
	Engine.time_scale = 4.0
	for i in 26000:
		await process_frame
		if not g.plan.running: break
	Engine.time_scale = 1.0
	check(book.complete(book._job("preset:gr7:preparation")) and g.incidents.is_empty(),"real third-source preparation cools and drains the actual loop before unplugging")
	var c = g.world.ctrls["E-D01"]
	g.gear.act({"kind":"place","type":"probe","ctrl":c,"pos":g.world.ctrl_world(c)})
	if whole: await whole_route()
	else: await separate_route()
	for u in g.gear.units.duplicate(): g.gear.retrieve(u)

func finish_route(reward: String) -> void:
	var last := ""
	var last_position := Vector2.INF
	var last_state := ""
	var stationary := 0
	for i in 12000:
		await process_frame
		if g.work_order.complete(): break
		var m = g.crane if whole else g.hauler
		if "--diagnose" in OS.get_cmdline_user_args() and m.state == "carry" and m.wait_reason != "":
			var half: Vector2 = preload("res://scripts/load_motion.gd").half_extents(m.body)
			var way: PackedVector2Array = g.nav_grid().payload_path(m.pos,m._drop_point(m.zone),half)
			print("RAD DIAG half_px=",half," box=",preload("res://scripts/load_motion.gd").bounds(m.body)," angle=",m.body.rotation," waypoints=",way.size()," profiles=",g.nav_grid().box_grids.keys()," precise=",g.nav_grid().box_precise.keys())
			for p in g.world.pieces.values():
				if not g.world.static_cols.has(p.id): continue
				var bb := Geom.bbox(g.world.world_poly(p))
				if bb.intersects(Rect2(Vector2(24,-5)*Geom.M,Vector2(9,8)*Geom.M)): print("RAD STATIC ",p.key," ",bb)
			break
		if m.pos.distance_to(last_position) > 3.0 or m.state != last_state:
			last_position = m.pos
			last_state = m.state
			stationary = 0
		else: stationary += 1
		if stationary > 1800:
			print("FIELD ROUTE STALLED for 30 simulated seconds: ",m.state," ",m.wait_reason)
			if is_instance_valid(m.body):
				print("STALLED LOAD box=",preload("res://scripts/load_motion.gd").bounds(m.body)," half=",preload("res://scripts/load_motion.gd").half_extents(m.body)," mask=",m.body.collision_mask)
				var nav = g.nav_grid()
				var target: Vector2 = m._drop_point(m.zone)
				print("NAV QUERY from=",m.pos/Geom.M," to=",target/Geom.M," half=",preload("res://scripts/load_motion.gd").half_extents(m.body)," way=",nav.payload_path(m.pos,target,preload("res://scripts/load_motion.gd").half_extents(m.body)))
				print("ACTUAL ROUTE ",m.route.slice(0,mini(8,m.route.size()))," normal=",m.body.get_meta("carrier_normal",Vector2.ZERO)," off=",m.off," com_delta=",m.body.global_transform*m.body.center_of_mass-m.pos)
				for piece in g.world.pieces.values():
					if not g.world.static_cols.has(piece.id): continue
					var bb := Geom.bbox(g.world.world_poly(piece))
					if bb.intersects(Rect2(Vector2(24,-4)*Geom.M,Vector2(12,8)*Geom.M)): print("LOCAL STATIC ",piece.key," ",bb.position/Geom.M," ",bb.size/Geom.M)
				var pose: Transform2D = m.body.global_transform
				for point in [Vector2(31.2,1.825),Vector2(25.45,1.825),Vector2(25.45,-5.6),Vector2(36,-5.6),Vector2(36,-6.5)]:
					var delta: Vector2 = point*Geom.M-pose*m.body.center_of_mass
					var hit := KinematicCollision2D.new()
					var blocked: bool = m.body.test_move(pose,delta,hit)
					print("READ-ONLY NATIVE ROUTE to=",point," blocked=",blocked," collider=",hit.get_collider_shape() if blocked else null)
					pose.origin += delta
			break
		var line := "%s %s at=%s payload=%s" % [m.state,m.wait_reason,str(m.pos/Geom.M),str(m.body.pieces.map(func(p):return p.key)) if is_instance_valid(m.body) else "none"]
		if i%900 == 0 and line != last:
			print(line)
			if is_instance_valid(m.body): print("OBSTACLE ",m.body.get_meta("carrier_obstacle","none"))
			last = line
	check(g.work_order.complete(),"actual %s route reaches equipment intake and reserves both required devices" % ("whole" if whole else "separate"))
	check(g.incidents.is_empty(),"physical heavy delivery route causes no incident")
	if g.work_order.complete():
		var proof: bool = g.work_order.receipts.any(func(r):return r.get("assembled",false) and r.keys.has("K4"))
		check(proof == whole,"whole-assembly credit comes from the actual received body, not the route selection flag")
		g.finish_contract(true)
		await frames(2)
		check(g.order_review != null and not g.ended,"actual heavy delivery reaches engineering review before money or facility commitment")
		if g.order_review != null: g.order_review.confirm_button.pressed.emit()
		await frames(5)
		var result: Dictionary = g.career_result.get("work_order",{})
		check(Orders.done("heavy") and Repair.done(reward),"the physical delivery commits its chosen real berth facility")
		var expected := 0.0 if whole else float(Repair.find(reward)[3])*0.2
		check(is_equal_approx(float(result.get("cash_cost",-1)),expected),"assembly fee follows actual route: expected $%.0f, recorded $%.0f" % [expected,float(result.get("cash_cost",-1))])
		print("ROUTE RESULT ",result," operations=",g.ops," times=",g.time_by)
	g.queue_free()
	await frames(5)
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G4 HEAVY %s %s (%d checks, %d failed)" % ["WHOLE" if whole else "SEPARATE","PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
