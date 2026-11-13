extends SceneTree
# A player beam, not SalvageBot's direct joint deletion, supplies the recording.
var g: Node
var fails := 0
var checks := 0
const AT := Vector2(30,-6) * Geom.M
func _initialize() -> void: _run.call_deferred()
func frames(n: int) -> void:
	for k in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
func scene(fixture: bool = true) -> void:
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "pod"
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	await frames(10)
	g.tutorial = null
	g.drone.global_position = AT + Vector2(0,-90)
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.freeze = true
	g.tools.set_tool(2,true)
	if not fixture: return
	var poly := PackedVector2Array([AT+Vector2(-32,-12),AT+Vector2(32,-12),AT+Vector2(32,12),AT+Vector2(-32,12)])
	var p = g.world.add_piece("hull",poly,{"key":"G4-PLATE","tag":"G4-PLATE","density":2.0})
	g.world.add_joint(p,null,"clamp",AT+Vector2(28,0))
	g.world.rebuild_cols(p)
func _run() -> void:
	SaveGame.allow_test = false
	SaveGame.path = "user://zp_test_g4_laser_save.json"
	SaveGame.train_path = "user://zp_test_g4_laser_train.json"
	Career.path = "user://zp_test_g4_laser_career.json"
	await scene()
	# The operator must still learn new manual work while another package waits.
	g.plan.packages.catalogue = [{"id":"waiting","version":1,"label":"Waiting for another target","steps":[{"do":"cut","key":"LATER-TARGET","pl":[[0,0],[0,1]],"pre":[]}]}]
	g.plan.packages.authorize(["waiting"])
	g.plan.package_mode = true
	g.plan.running = true
	g.bot.aim = AT + Vector2(0,11)
	g.bot.lmb = true
	await frames(60)
	g.bot.aim = AT + Vector2(0,16)
	await frames(20)
	g.bot.lmb = false
	await frames(8)
	var learned: Array = g.plan.rec.duplicate(true)
	check(g.plan.running,"the operator works while an independent machine package is paused")
	print("LEARNED ",learned)
	check(learned.any(func(s):return s.get("do","") == "cut"),"a normal held laser records structural cuts")
	var bodies := 0
	for id in g.world.order:
		var q = g.world.pieces[id]
		if q.key.begins_with("G4-PLATE"):
			print("FRAGMENT ",q.key," gone=",q.gone," body=",q.body," area=",Geom.area(q.poly)," joints=",g.world.joints_of(q).size())
	for b in g.world.bodies:
		for p in b.pieces:
			if p.key.begins_with("G4-PLATE"): bodies += 1
	check(bodies > 0,"the player beam actually frees a plate fragment")
	var keys: Array = []
	for b in g.world.bodies:
		for p in b.pieces:
			if p.key.begins_with("G4-PLATE"): keys.append(p.key)
	check(not keys.is_empty() and keys.all(func(k):return k != ""),"cut fragments retain replayable stable identities")
	var manual := int(g.ops.get("cut",0))
	check(manual > 0,"actual player cutting is counted")
	g.queue_free()
	await frames(4)
	await scene()
	g.plan.steps = learned
	g.plan.i = 0
	g.plan.running = true
	for k in 1800:
		await process_frame
		if not g.plan.running: break
	print("REPLAY i=%d/%d wait=%s bodies=%d" % [g.plan.i,learned.size(),g.plan.wait,g.world.bodies.size()])
	if g.plan.i < learned.size():
		var cutter = g.plan.cutter_service()
		print("CUTTER WAIT reason=",cutter.reason," pos=",cutter.robot.global_position," station=",cutter.station," body_reason=",cutter.robot.reason," velocity=",cutter.robot.linear_velocity," motion=",g.plan.cut_motion)
		var stalled = g.world.key_piece(str(g.plan.steps[g.plan.i].key))
		for shape in cutter.shapes(stalled): print("ACTUAL CUTTER TARGET COLLIDER ",shape.polygon)
		if not g.plan.cut_motion.is_empty():
			var f: Array = g.plan.cut_motion.front
			var point := Vector2(float(f[0]),float(f[1]))
			print("VERTICAL CONTACT open=",cutter._open(point+Vector2(0,-48))," hit=",cutter._contact_from(point+Vector2(0,-48),point,World.KERF,cutter.shapes(stalled)))
	check(g.plan.i == learned.size() and not g.plan.running,"the next identical fixture executes the entire recorded sequence")
	var replay_keys: Array = []
	for b in g.world.bodies:
		for p in b.pieces:
			if p.key.begins_with("G4-PLATE"): replay_keys.append(p.key)
	keys.sort()
	replay_keys.sort()
	print("RECORDED FRAGMENT KEYS ",keys," REPLAYED FRAGMENT KEYS ",replay_keys)
	check(keys == replay_keys and not keys.is_empty(),"machine replay frees the same keyed fragments")
	check(int(g.ops.get("cut",0)) == 0 and int(g.ops.get("plan",0)) > 0,"machine cuts are not misreported as manual cuts")
	check(g.incidents.is_empty(),"the physical replay causes no incident")
	g.queue_free()
	await frames(4)
	await scene()
	var p = g.world.key_piece("G4-PLATE")
	var extra = g.world.add_joint(p,null,"clamp",AT+Vector2(-28,0))
	g.plan.steps = learned.duplicate(true)
	g.plan.running = true
	await frames(20)
	check(g.plan.i == 0 and g.plan.wait == "plan_cut_structure","a new local reinforcement pauses before cutting")
	check(g.plan._shape(p) == learned[0].before,"structural mismatch never removes material")
	extra.alive = false
	# A physically unrelated change must not invalidate the local package.
	var other = g.world.add_piece("hull",PackedVector2Array([AT+Vector2(100,-8),AT+Vector2(116,-8),AT+Vector2(116,8),AT+Vector2(100,8)]),{"key":"UNRELATED"})
	g.world.add_joint(other,null,"clamp",AT+Vector2(110,0))
	g.world.add_line("G4-NEW-CABLE","cable","none",p,AT,other,AT+Vector2(105,0),PackedVector2Array([AT,AT+Vector2(105,0)]))
	await frames(10)
	check(g.plan.i == 0 and g.plan.wait == "plan_cut_structure","an added dead cable still changes the local connection graph")
	g.world.kill_line(g.world.lines["G4-NEW-CABLE"])
	for k in 1800:
		await process_frame
		if not g.plan.running: break
	check(g.plan.i == learned.size(),"unrelated structure changes do not invalidate the local process")
	g.queue_free()
	await frames(4)
	await scene()
	p = g.world.key_piece("G4-PLATE")
	var st: Dictionary = learned[0]
	var pl := PackedVector2Array()
	for q in st.pl: pl.append(Vector2(q[0],q[1]))
	g.cut_kerf(p,pl,float(st.kerf))
	g.plan.steps = learned.duplicate(true)
	g.plan.i = 0
	g.plan.running = true
	var before_ops: int = g.ops.get("plan",0)
	g.plan._step_cut(g.plan.steps[0],1.0/60.0)
	check(g.plan.i == 1 and int(g.ops.get("plan",0)) == before_ops,"an exactly completed manual cut skips without duplicate machine work")
	# A truncated manual notch must not skip the rest of the process.
	check(learned.size() > 1 and g.plan.i < learned.size(),"a partial manual notch does not complete the entire plate process")
	var disk := JSON.parse_string(JSON.stringify(g.plan.save_state())) as Dictionary
	g.plan.steps.clear()
	g.plan.load_state(disk)
	check(g.plan.steps.size() == learned.size() and g.plan.i == 1,"execution steps and partial progress survive JSON serialization")
	# Use a real pressure volume and its measurement port from the loaded ship.
	var room := ""
	for name in g.sys.vols:
		if g.plan._gas_port(str(name)) != "":
			room = str(name)
			break
	check(room != "","the safety test has a real pressure volume and measurement port")
	if room != "":
		var st1: Dictionary = g.plan.steps[1]
		var target = g.world.key_piece(str(st1.key))
		var shape_before: Array = g.plan._shape(target)
		st1.rooms = [room]
		g.sys.vols[room].n = 80.0 * float(g.sys.vols[room].V)
		g.plan._step_cut(st1,100.0)
		print("PRESSURE wait=",g.plan.wait," P=",g.sys.P(room)," shape=",g.plan._shape(target)," expected=",st1.before)
		check(g.plan.wait == "plan_cut_pressure" and g.plan.i == 1 and g.plan._shape(target) == shape_before,"actual pressure pauses before material is cut")
		g.sys.vols[room].n = 0.0
		var port: String = g.plan._gas_port(room)
		st1.pre = [{"key":port,"kind":"pressure","val":0.0}]
		g.sys.readings.erase(port)
		g.plan._step_cut(st1,100.0)
		# 2026-11-12: on a plan run the drone goes to read it (as_plan_fly / as_plan_reading); nothing is cut meanwhile
		check(g.plan.wait in ["plan_measure", "as_plan_fly", "as_plan_reading"] and g.plan._shape(target) == shape_before,"missing fresh evidence pauses even after the volume becomes safe")
	g.plan.cancel()
	var cut_seq: int = g.world.key_piece("G4-PLATE").cut_seq
	SaveGame.allow_test = true
	SaveGame.save(g)
	check(not SaveGame.read(SaveGame.file_for(g)).is_empty(),"the actual atomic save file contains this partially cut world")
	g.queue_free()
	await frames(4)
	SaveGame.load_requested = true
	await scene(false)
	p = g.world.key_piece("G4-PLATE")
	check(p != null and p.cut_seq == cut_seq,"cut fragment sequence survives full world reconstruction from disk")
	check(g.plan.steps.size() == learned.size() and g.plan.i == 1,"full disk reload restores the exact execution sequence and partial progress")
	check(not g.plan.running,"disk reload waits for operator authorization rather than cutting immediately")
	g.queue_free()
	await frames(4)
	print("PLAN LASER %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	var drain_until := Time.get_ticks_msec() + 250
	while Time.get_ticks_msec() < drain_until: await process_frame
	quit(0 if fails == 0 else 1)
