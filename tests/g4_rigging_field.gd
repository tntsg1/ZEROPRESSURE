extends SceneTree
# Uses the actual saved reward of g4_access_field.gd as its seed. Production
# tools/cables/physics perform all load motion. Operator positioning is staged;
# this is not a claim of human piloting or subjective pacing validation.
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
func cut_at(prefix: String, at: Vector2, delta: Vector2) -> void:
	var p = null
	for q in g.world.pieces.values():
		if not q.gone and q.key.begins_with(prefix) and g.world.piece_contains(q,at):
			p = q
			break
	if p == null:
		check(false,"authored cut still finds "+prefix+" at "+str(at/Geom.M))
		return
	g.cut_kerf(p,PackedVector2Array([at-delta,at+delta]))
	await frames(2)
func unfix(p) -> void:
	for j in g.world.joints_of(p).duplicate():
		if j.type not in ["bolt","lock","clamp"]: continue
		g.do_wrench({"kind":"joint","joint":j,"pos":g.world.joint_world(j)})
		await frames(2)
func pull_to(point: Vector2, label: String) -> bool:
	for i in 2400:
		await process_frame
		if g.work_order.complete(): return true
		if g.tools.held_body == null:
			var target = g.world.key_piece("C-02")
			if target != null and target.body != null and target.body.capture != null:
				print("GRAPPLE HANDOFF ",label," to ",target.body.capture)
				return true
			print("GRAPPLE LOST ",label," incidents=",g.incidents)
			return false
		var grab: Vector2 = g.tools.grab_point()
		g.drone.global_position = grab+Vector2(0,-2.5*Geom.M)
		g.drone.linear_velocity = Vector2.ZERO
		g.bot.aim = point
		if grab.distance_to(point)<4.0 and g.tools.held_body.linear_velocity.length()<12.0:
			print("GRAPPLE WAYPOINT ",label," reached ",grab/Geom.M)
			return true
	print("GRAPPLE WAIT ",label," point=",g.tools.grab_point()/Geom.M," goal=",point/Geom.M)
	return false
func _run() -> void:
	Career.path = "user://zp_test_g4_access_field_career.json"
	Career.data = {}
	Career.load_or_new()
	check(Orders.done("access") and Career.active().is_empty(),"second commission starts from the actual completed first-commission save")
	if fails > 0:
		quit(1)
		return
	Career.path = "user://zp_test_g4_rigging_field_career.json"
	Career.save()
	SaveGame.path = "user://zp_test_g4_rigging_field_save.json"
	SaveGame.allow_test = false
	SaveGame.load_requested = false
	check(Orders.take("rigging") == "","real progression unlock signs the mounted-section source")
	Game.start_ship = "gr7"
	Game.contract = Career.active()
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	await frames(8)
	g.tutorial = null
	g.drone.global_position = Vector2(-5,-12)*Geom.M
	var book = g.plan.packages
	check(book.authorize(["preset:gr7:preparation"]),"factory safety package remains selectable beside the saved custom access cuts")
	g.plan.package_mode = true
	g.plan.running = true
	Engine.time_scale = 4.0
	for i in 26000:
		await process_frame
		if not g.plan.running: break
	check(book.complete(book._job("preset:gr7:preparation")) and g.incidents.is_empty(),"actual safety process completes on the second authored source")
	Engine.time_scale = 1.0
	for rib in [["p51",14.55],["p52",18.85]]:
		for y in [-1.5,0.0,1.5]: await cut_at(rib[0],Vector2(rib[1],y)*Geom.M,Vector2(0.3,0)*Geom.M)
		for p in g.world.pieces.values():
			if not p.gone and p.key.begins_with(rib[0]): await unfix(p)
	for x in [15.3,20.2]: await cut_at("RAIL-C",Vector2(x,-3.4)*Geom.M,Vector2(0,0.3)*Geom.M)
	for p in g.world.pieces.values():
		if not p.gone and p.key.begins_with("RAIL-C") and g.world.piece_contains(p,Vector2(17.0,-3.4)*Geom.M): await unfix(p)
	var target = g.world.key_piece("C-02")
	var mount = g.world.key_piece("FP-C2")
	check(target.intact and target.cond >= 0.99 and mount.body == null,"clearance cuts leave the target and its still-mounted floor plate intact")
	g.gear.act({"kind":"place","type":"anchor","piece":mount,"pos":Geom.centroid(mount.poly)})
	var anchors: Array = g.gear.units.filter(func(u):return u.type == "anchor")
	check(anchors.size() == 1 and anchors[0].lent and anchors[0].mode == "hold","borrowed anchor is physically deployed in the new cable-lock mode")
	var c = g.world.ctrls["E-D01"]
	g.gear.act({"kind":"place","type":"probe","ctrl":c,"pos":g.world.ctrl_world(c)})
	check(g.gear.units.any(func(u):return u.type == "probe" and u.lent),"the loaned probe is actually deployed through the normal tool system")
	# Undo the external mounting bolts while preserving the two cargo locks.
	for j in g.world.joints_of(mount).duplicate():
		var other = g.world.pieces.get(j.b if j.a == mount.id else j.a)
		if other == target or j.type != "bolt": continue
		g.do_wrench({"kind":"joint","joint":j,"pos":g.world.joint_world(j)})
		await frames(2)
	await frames(10)
	check(target.body != null and target.body == mount.body and not target.body.freeze,"real unbolting releases a dynamic cargo-and-floor assembly without cutting its plate")
	for i in 900:
		await process_frame
		if g.work_order.stable: break
	check(g.work_order.stable,"the real free assembly satisfies the one-second stability milestone")
	for u in g.gear.units.duplicate(): g.gear.retrieve(u)
	check(g.gear.units.is_empty() and int(g.gear.carried_counts().get("anchor",0)) >= 1,"anchor and probe are retrieved before hauling instead of being silently discarded")
	var body = target.body
	var center: Vector2 = body.global_transform*body.center_of_mass
	g.drone.global_position = center+Vector2(0,-2.5*Geom.M)
	g.drone.linear_velocity = Vector2.ZERO
	g.tools.set_tool(3,true,true)
	g.bot.aim = center
	g.bot.lmb = true
	await frames(8)
	check(g.tools.held_body == body and body.total_mass() <= g.grab_max(),"normal grapple input grips the full assembly within its real load rating")
	var route := [Vector2(center.x,0.0),Vector2(17.9*Geom.M,0.0),Vector2(17.9,-6.5)*Geom.M,Dock.zpos("equip_bulk")+Vector2(0,1.6*Geom.M)]
	for i in route.size():
		if not await pull_to(route[i],"%d" % (i+1)): break
	g.bot.lmb = false
	await frames(200)
	check(g.work_order.complete(),"normal grapple forces deliver intact C-02 with the complete FP-C2 to actual equipment recovery")
	check(g.incidents.is_empty(),"the full mounted-section route causes no incident")
	if g.work_order.complete():
		g.finish_contract(true)
		await frames(2)
		check(g.order_review != null and not g.ended,"mounted-section delivery can be reviewed before committing the owned anchor reward")
		if g.order_review != null: g.order_review.confirm_button.pressed.emit()
		await frames(5)
		check(Orders.done("rigging") and int(Career.data.gear.get("anchor",0)) == 1,"settlement grants one owned anchor and returns the borrowed gear without duplicating it")
		check(Orders.reason("heavy") == "","actual saved engineering progress opens the heavy delivery choices")
	g.queue_free()
	await frames(5)
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G4 RIGGING FIELD %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
