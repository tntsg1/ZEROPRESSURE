extends SceneTree
# Full tug acceptance. Same physical source version, distinct accepted contracts.
# Pilot positions are staged; cargo is moved only by normal grapple/carrier
# physics. Test-private careers only. No abstract SalvageBot stripping.
const Operator = preload("res://tests/g4_tug_operator.gd")
const SOURCE := 777001
var g: Node
var checks := 0
var fails := 0
var receipts := {}
var inflight := {}
var paid_events := {}
var observation := {}
var machine_cuts := 0
var machine_controls := 0
var release_clock := 0
func _initialize() -> void: _run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
func remaining_scope() -> Array:
	var keys: Array = []
	for p in g.world.pieces.values():
		if p.scope and not p.gone: keys.append(p.key)
	return keys
func _process(_dt: float) -> bool:
	if is_instance_valid(g) and g.is_inside_tree():
		observe_receipts()
		observe_work()
	return false
func observe_receipts() -> void:
	if g.dock == null: return
	for entry in g.dock.swallowing:
		var body = entry[0]
		if not is_instance_valid(body): continue
		var keys: Array = body.pieces.map(func(p):return p.key)
		keys.sort()
		var id := JSON.stringify(keys)
		if receipts.has(id): continue
		# Update references after a real field reconstruction too.
		inflight[id] = {"keys":keys,"zone":Dock.kind(str(entry[1])),"pieces":body.pieces.duplicate(),"ledger":g.ledger.size(),"manual":body.get_meta("hauled",false) and float(body.get_meta("arm_drop",-1.0)) < 0.0}
	for id in inflight.keys():
		var entry: Dictionary = inflight[id]
		var event: Dictionary = paid_events.get(id,{})
		if entry.pieces.all(func(p):return p.gone) and event.get("zone","") == entry.zone and event.get("job","") == str(g.job.get("id","")) and float(event.get("value",-1.0)) >= 0.0:
			receipts[id] = {"keys":entry.keys,"zone":entry.zone,"manual":entry.manual}
			inflight.erase(id)
func on_real_load_received(keys: Array,zone: String,value: float,job_id: String) -> void:
	# A different concurrent delivery cannot supply this load's evidence.
	paid_events[JSON.stringify(keys)] = {"keys":keys.duplicate(),"zone":zone,"value":value,"job":job_id}
	for pending in g.plan.haul_watch:
		if pending.keys == keys and str(pending.zone) != zone:
			print("REAL WRONG RECEIVER keys=",keys," expected=",pending.zone," actual=",zone," value=",value)
func observe_work() -> void:
	if g.plan == null: return
	if not observation.is_empty() and observation.scene == g.get_instance_id():
		if observation.get("active",false) and g.plan.i > int(observation.i):
			if observation.kind == "cut":
				var p = observation.piece
				if p != null and (p.gone or g.plan._shape(p) != observation.shape) and int(g.ops.get("plan",0)) > int(observation.ops): machine_cuts += 1
			elif observation.kind in ["w","h"]:
				var c = g.world.ctrls.get(observation.ctrl)
				if c != null:
					var value: bool = g.sys.hoses.has(c.id) if observation.kind == "h" else c.state
					if value != bool(observation.value) and int(g.ops.get("plan",0)) > int(observation.ops): machine_controls += 1
	observation = {"scene":g.get_instance_id(),"active":false}
	if not g.plan.running or g.plan.i >= g.plan.steps.size(): return
	var st: Dictionary = g.plan.steps[g.plan.i]
	observation.merge({"active":true,"i":g.plan.i,"kind":str(st.get("do","")),"ops":int(g.ops.get("plan",0))})
	if observation.kind == "cut":
		var p = g.world.key_piece(str(st.key))
		observation.piece = p
		observation.shape = g.plan._shape(p) if p != null else []
		observation.active = p != null and not p.gone and p.body == null
	elif observation.kind in ["w","h"]:
		observation.ctrl = str(st.ctrl)
		var c = g.world.ctrls.get(str(st.ctrl))
		observation.value = (g.sys.hoses.has(c.id) if observation.kind == "h" else c.state) if c != null else false
func reset_observer() -> void:
	receipts.clear()
	inflight.clear()
	paid_events.clear()
	observation.clear()
	machine_cuts = 0
	machine_controls = 0
func take_tug() -> Dictionary:
	var offer := Market.offer_for(SOURCE,Career.data,1,"full","tug")
	Career.data.offers = [offer]
	return Career.accept(0)
func spawn(resume: bool = false) -> void:
	SaveGame.load_requested = resume
	Game.contract = Career.active()
	Game.start_ship = "tug"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"consum":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	g.load_received.connect(on_real_load_received)
	Engine.max_fps = 0
	await frames(8)
	g.tutorial = null
	g.autosave_t = -1000000.0
	g.drone.global_position = Vector2(-5,-12)*Geom.M
func factory_signature() -> String:
	var entries: Array = []
	for p in g.world.pieces.values():
		entries.append([p.key,g.plan._shape(p),g.plan._links(p)])
	entries.sort_custom(func(a,b):return a[0]<b[0])
	return JSON.stringify(entries)
func physical_work() -> Dictionary:
	# Same observed atomic units on both ships; queue/dispatch events never
	# count as deliveries. Legacy OP_CAT remains an unchanged diagnostic.
	var manual := 0
	for st in g.plan.rec:
		if st.get("do","") == "cut" and st.get("before",[]) != st.get("after",[]): manual += 1
	for key in ["unfix","unplug","door","remeasure","repair","measure","isolate","hose"]:
		manual += int(g.ops.get(key,0))
	var machine := machine_cuts+machine_controls
	for receipt in receipts.values():
		if receipt.manual: manual += 1
		else: machine += 1
	var actions := 0
	for key in ["cut","haul_scrap","deliver_equip","deliver_hazard","unfix","unplug","door","remeasure","repair","measure","isolate","hose"]:
		actions += int(g.ops.get(key,0))
	return {"manual":manual,"manual_actions":actions,"machine":machine,"share":float(manual)/maxf(1.0,manual+machine),"legacy_categories":Game.op_share(g.ops)}
func release_requested() -> void:
	# The player retains unbolting and unplugging decisions. Only detach the
	# external removable fixing of a target the saved route is waiting for.
	release_clock += 1
	if release_clock%3 != 0: return
	for pending in g.plan.haul_watch:
		for key in pending.keys:
			var p = g.world.key_piece(str(key))
			if p == null or p.gone: continue
			if p.body != null and g.plan._body_keys(p.body) == pending.keys: continue
			for j in g.world.joints_of(p):
				if not j.alive or j.type not in ["bolt","lock","clamp"]: continue
				var other = g.world.pieces.get(j.b if j.a == p.id else j.a)
				if other != null and pending.keys.has(other.key): continue
				g.do_wrench({"kind":"joint","joint":j,"pos":g.world.joint_world(j)})
				return
func dispose() -> void:
	if is_instance_valid(g): g.queue_free()
	await frames(5)
	g = null
	observation.clear()
func _run() -> void:
	Txt.cfg_path = "user://zp_test_plancut_physical_settings.cfg"
	Career.path = "user://zp_test_plancut_physical_career.json"
	SaveGame.path = "user://zp_test_plancut_physical_field.json"
	SaveGame.allow_test = true
	SaveGame.load_requested = false
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.market = true
	Career.data.done = 3
	Career.data.money = 200000.0
	Career.data.upgrades = {"lights":1,"net_fix":1,"furnace_main":1,"hauler":1}
	Career.data.methods = {"cutter": 1}   # 104 号: the cutter working a plan is a learned method
	Career.save()
	var first := take_tug()
	check(not first.is_empty(),"ship A is a real accepted whole-tug contract")
	await spawn()
	var original := factory_signature()
	var actor = Operator.new(g)
	actor.stream_manual = true
	var safe: bool = await actor.safe()
	check(safe and g.incidents.is_empty(),"ship A completes actual safety procedures before cutting")
	g.auto_paused = true
	if safe: await actor.disconnect_all()
	var worked: bool = safe and await actor.segment_heavy()
	if worked: worked = await actor.separate_shell()
	if worked: await actor.unfix_all()
	if worked and actor.errors.is_empty(): worked = await actor.deliver_all_by_hand()
	await frames(5)
	observe_receipts()
	check(worked and actor.errors.is_empty() and g.ended and g.incidents.is_empty(),"ship A is fully dismantled and physically delivered without an incident: "+str(actor.errors))
	check(remaining_scope().is_empty(),"ship A leaves zero actual contract-scope pieces: "+str(remaining_scope()))
	check(g.recovery_rate() >= 0.9,"ship A recovers at least 90 percent of the actual full contract value")
	print("WHOLE A RECOVERY rate=",g.recovery_rate()," ledger=",g.ledger)
	var learned: Array = Career.data.get("plans",{}).get("tug",[]).duplicate(true)
	var cuts: Array = learned.filter(func(st):return st.get("do","") == "cut")
	var hauls: Array = learned.filter(func(st):return st.get("do","") == "haul")
	var controls: Array = learned.filter(func(st):return st.get("do","") in ["w","h"])
	check(cuts.size() >= 10 and hauls.size() >= 10 and not controls.is_empty(),"settlement saves positive real work: %d cuts, %d delivered loads, %d controls" % [cuts.size(),hauls.size(),controls.size()])
	var source_work := physical_work()
	var source_rate: float = g.recovery_rate()
	print("WHOLE A WORK ",source_work," ops=",g.ops)
	var worn := bool(g.bot.get("consum",false))
	for tool in Consum.TOOLS:
		worn = worn and Consum.left(g,tool) >= 0.0 and Consum.left(g,tool) < Consum.capacity(tool,Consum.tier(g,tool))
	print("WHOLE A ACTUAL CONSUMABLES ",g.job.get("consum",{}))
	# 2026-10-23 the player cancelled hand-tool consumables (Consum.ENABLED false): with them off the
	# wear check is moot; it still holds while they are on
	check(worn or not Consum.ENABLED,"source cutting, grappling and inspection use actual consumable wear without bot exemptions (consumables %s)" % ("on" if Consum.ENABLED else "cancelled 10-23"))
	check(int(source_work.manual) > 0 and source_work.share > 0.0,"the full first-ship manual-work baseline is positive")
	await dispose()
	if fails > 0:
		await finish()
		return
	reset_observer()
	var second := take_tug()
	check(not second.is_empty() and second.id != first.id,"ship B is a distinct normally accepted contract, not a replayed settlement")
	await spawn()
	check(factory_signature() == original,"two full baseline ships have genuinely matching factory geometry and connections")
	check(g.plan.steps == learned,"ship B loads the actual settled recording")
	actor = Operator.new(g)
	await actor.read_changed()
	check(g.incidents.is_empty() and g.sys.bus_live,"ship B starts powered and intact; the recording must perform its actual safety preparation")
	g.plan.package_mode = false
	var message: String = g.plan.toggle()
	if OS.get_environment("ZP_CUTTER_TRACE") != "": g.plan.cutter_service().set_meta("trace", true)
	check(g.plan.running,"P authorizes the recorded route: "+message)
	var saved := false
	var stuck := 0
	var progress := ""
	var disconnected := false
	for frame in 60000:
		await process_frame
		if g.ended: break
		release_requested()
		if g.plan.wait in ["plan_measure","plan_differs"]: await actor.read_requested()
		if not disconnected and g.plan.i < learned.size() and learned[g.plan.i].get("do","") == "cut":
			check(not g.sys.bus_live and g.sys.P("A") <= 5.0 and g.sys.P("M") <= 5.0 and g.sys.P("O2") <= 5.0 and g.sys.fluid("fuel") <= 0.02,"replayed controls physically depressurize and isolate ship B before the first cut")
			await actor.disconnect_all()
			disconnected = true
		if not saved and machine_cuts > 0 and g.plan.i < learned.size():
			var index: int = g.plan.i
			var watch: int = g.plan.haul_watch.size()
			SaveGame.save(g)
			await dispose()
			await spawn(true)
			actor = Operator.new(g)
			check(g.plan.i == index and g.plan.haul_watch.size() == watch and not g.plan.running,"real mid-plan disk reconstruction preserves progress and awaits renewed authorization")
			g.plan.toggle()
			saved = true
		# 2026-10-25 (design 03 §G7.1 "player takeover"): a cut the machine cannot reach from any
		# work position (a seam under the keel, the hand laser needs only range) is finished by the
		# operator by hand, and the machine carries on from the next step
		if g.plan.running and g.plan.wait == "plan_cutter_wait" and stuck > 600 and g.plan.i < g.plan.steps.size():
			await take_over_cut(actor)
			stuck = 0
		var current := "%d:%s:%d:%d" % [g.plan.i,g.plan.wait,g.ledger.size(),int(g.ops.get("unfix",0))]
		if current != progress:
			progress = current
			stuck = 0
		else: stuck += 1
		if frame%1200 == 0:
			print("WHOLE B ",current," hauling=",g.hauler.state," / ",g.hauler.wait_reason)
			var cs = g.plan.cutter_service()
			print("  CUTTER reason=",cs.reason," station=",cs.station," robot=",cs.robot.global_position," robot_reason=",cs.robot.reason)
		if stuck > 2400:
			print("WHOLE B BLOCKED ",current," target=",g.plan.wait_arg," transport=",g.plan.transport_wait())
			if g.plan.i < g.plan.steps.size(): print("BLOCKED STEP ",g.plan.steps[g.plan.i])
			var kp = g.world.key_piece(str(g.plan.steps[g.plan.i].get("key",""))) if g.plan.i < g.plan.steps.size() else null
			if kp != null: print("BLOCKED SHAPE ", g.plan._shape(kp), " links=", g.plan._links(kp), " motion=", g.plan.cut_motion, " air=", g.plan._air_only(kp, PackedVector2Array([Vector2(float(g.plan.cut_motion.get("front",[0,0])[0]), float(g.plan.cut_motion.get("front",[0,0])[1])), Vector2(674.4, -167.56)]), 3.4))
			_probe_cutter()
			break
	await frames(5)
	observe_receipts()
	check(saved,"the actual replay exercised a mid-plan field save and reload")
	check(g.ended and g.incidents.is_empty(),"ship B completes actual full-ship recovery with no incident")
	check(remaining_scope().is_empty(),"ship B leaves zero actual contract-scope pieces: "+str(remaining_scope()))
	check(g.recovery_rate() >= 0.9 and g.recovery_rate() >= source_rate-0.005,"ship B completes comparable recovery, rather than abandoning the difficult cargo")
	check(machine_cuts >= maxi(10,ceili(cuts.size()*0.5)),"actual observed machine cuts cover at least half the recorded cuts: %d / %d" % [machine_cuts,cuts.size()])
	check(int(g.ops.get("plan",0)) >= machine_cuts,"production machine-operation accounting includes the actual applied cuts")
	var delivered := 0
	for haul in hauls:
		var id := JSON.stringify(haul.keys)
		if receipts.has(id) and receipts[id].zone == haul.zone: delivered += 1
	check(delivered == hauls.size(),"all %d recorded loads actually enter their recorded paying receivers (%d observed)" % [hauls.size(),delivered])
	var replay_work := physical_work()
	print("WHOLE B WORK ",replay_work," actual machine cuts=",machine_cuts," ops=",g.ops)
	check(replay_work.share < 0.5 and replay_work.share < source_work.share,"normalized manual physical-work share falls below 50 percent: %.1f%% -> %.1f%%" % [source_work.share*100,replay_work.share*100])
	check(int(replay_work.manual)*2 < int(source_work.manual),"absolute observed manual work also falls by more than half, without inflating a dispatch counter")
	check(int(replay_work.manual_actions)*2 < int(source_work.manual_actions),"counted manual work operations also fall by more than half, counting each held beam stroke once: %d -> %d; staged pilot movement is not human input-effort evidence" % [source_work.manual_actions,replay_work.manual_actions])
	check(int(replay_work.machine) > int(source_work.machine),"the machine performs more actual completed work than on ship A")
	await dispose()
	if fails == 0:
		await safety_stops(learned)
		await excluded_cut_fixtures()
	await finish()
func safety_stops(learned: Array) -> void:
	# Pressure and stale readings are explicit hazard fixtures on a real third
	# tug. Their setup is not counted as physical recovery or human playtesting.
	take_tug()
	await spawn()
	var actor = Operator.new(g)
	await actor.read_changed()
	g.plan.package_mode = false
	g.plan.toggle()
	var first_cut := -1
	for index in g.plan.steps.size():
		if g.plan.steps[index].get("do","") == "cut":
			first_cut = index
			break
	for frame in 9000:
		if g.plan.i >= first_cut: break
		if g.plan.wait in ["plan_measure","plan_differs"]: await actor.read_requested()
		await process_frame
	if g.plan.i == first_cut: await actor.disconnect_all()
	check(first_cut >= 0 and g.plan.i == first_cut,"the recorded first cut exists and its real prerequisites are reached before the manual-skip check")
	if first_cut >= 0 and g.plan.i == first_cut:
		g.plan.cancel()
		var cut: Dictionary = g.plan.steps[first_cut]
		var piece = g.world.key_piece(str(cut.key))
		var path := PackedVector2Array()
		for point in cut.pl: path.append(Vector2(point[0],point[1]))
		g.cut_kerf(piece,g.world.frame(piece)*path,float(cut.get("kerf",World.KERF)))
		var manual_after: Array = g.plan._shape(piece)
		var operations: int = g.ops.get("plan",0)
		check(manual_after == cut.after,"production manual cut creates the actual expected geometry, rather than an artificial completion flag")
		g.plan.toggle()
		for frame in 600:
			await process_frame
			if g.plan.i > first_cut: break
		check(g.plan.i > first_cut and int(g.ops.get("plan",0)) == operations and g.plan._shape(piece) == manual_after,"an actually completed manual cut is skipped without a second machine cut")
	var selected := -1
	for frame in 6000:
		if g.plan.i < g.plan.steps.size():
			var st: Dictionary = g.plan.steps[g.plan.i]
			var p = g.world.key_piece(str(st.get("key","")))
			if st.get("do","") == "cut" and not st.get("rooms",[]).is_empty() and p != null and p.body == null:
				selected = g.plan.i
				break
		release_requested()
		await actor.read_changed()
		await process_frame
	check(selected >= 0,"a genuine eligible recorded cut beside a room is reached on ship C")
	if selected >= 0:
		var step: Dictionary = g.plan.steps[selected]
		var target = g.world.key_piece(str(step.key))
		var before: Array = g.plan._shape(target)
		var room: String = step.rooms[0]
		var gas_before: float = g.sys.vols[room].n
		g.sys.vols[room].n = 80.0*float(g.sys.vols[room].V)
		await frames(4)
		check(g.plan.i == selected and g.plan.wait == "plan_cut_pressure" and g.plan.wait_arg == room and g.plan._shape(target) == before,"pressure fixture stops before material removal and names its actual room")
		g.sys.vols[room].n = gas_before
		await actor.read_changed()
		var port: String = g.plan._gas_port(room)
		if g.sys.readings.has(port): g.sys.readings[port].ver = -999
		await frames(4)
		check(g.plan.i == selected and g.plan.wait == "plan_measure" and g.plan._shape(target) == before,"stale pressure evidence cannot authorize the same cut")
		await actor.read_changed()
		for i in 1200:
			await process_frame
			if g.plan.i > selected: break
		check(g.plan.i > selected,"a genuine fresh measurement resumes the previously blocked cut")
	await dispose()
func excluded_cut_fixtures() -> void:
	# Separate negative fixtures. They deliberately cause damage and cannot
	# count as clean salvage, recovery or manual-work reduction evidence.
	await spawn()
	g.plan.cancel()
	var before: int = g.plan.rec.size()
	var p = g.world.key_piece("POD-T")
	await negative_beam(Vector2(11.6,3.45),Vector2(11.6,5.05))
	check(not p.intact,"negative fixture uses a normal beam to actually damage intact equipment")
	check(g.plan.rec.size() == before and not g.plan.rec.any(func(st):return st.get("do","") == "cut" and str(st.get("key","")) == "POD-T"),"cutting intact equipment is excluded from the saved operation recording")
	await dispose()
	await spawn()
	g.plan.cancel()
	# The injected pressure is an explicit hazard fixture, not safety prep.
	g.sys.vols.A.n = 80.0*float(g.sys.vols.A.V)
	before = g.plan.rec.size()
	var incidents: int = g.incidents.size()
	await negative_beam(Vector2(3.5,-4.7),Vector2(3.5,-3.95))
	check(g.incidents.size() > incidents,"negative fixture's real hull cut actually triggers a pressure incident")
	check(g.plan.rec.size() == before and g.plan.record_blocked != "","the incident cut is excluded and recording stops at its valid prefix")
	await dispose()
func negative_beam(a_m: Vector2,b_m: Vector2) -> void:
	var a := a_m*Geom.M
	var b := b_m*Geom.M
	g.bot.lmb = false
	g.tools.set_tool(2,true,true)
	g.drone.freeze = true
	g.drone.global_position = a-(b-a).normalized()*1.4*Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	g.bot.aim = a
	g.bot.lmb = true
	await frames(3)
	g.bot.aim = b
	for frame in 600:
		await process_frame
		if g.tools.front.distance_to(b) < 0.6: break
	g.bot.lmb = false
	await frames(10)
func finish() -> void:
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("PLAN-CUT PHYSICAL %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)


# diagnostics for a blocked cutter: what each candidate work position overlaps or sees first
func _probe_cutter() -> void:
	var cs = g.plan.cutter_service()
	var st: Dictionary = g.plan.steps[g.plan.i]
	var p = null
	for q in g.world.pieces.values():
		if str(q.key) == str(st.key) and not q.gone:
			p = q
	if p == null:
		print("PROBE no live piece with key ", st.key)
		return
	var pl := PackedVector2Array()
	for q in st.pl: pl.append(Vector2(float(q[0]), float(q[1])))
	var front := pl[0]
	if str(g.plan.cut_motion.get("key", "")) == str(st.key) and g.plan.cut_motion.has("front"):
		front = Vector2(float(g.plan.cut_motion.front[0]), float(g.plan.cut_motion.front[1]))
	var at: Vector2 = g.world.frame(p) * front
	var targets: Array = cs.shapes(p)
	print("PROBE at=", at, " contact=", cs.contact(p, at, float(st.get("kerf", 3.4))), " body=", p.body != null, " shapes=", targets.size(), " door=", p.door, " gone=", p.gone, " robot=", cs.robot.global_position)
	var space = cs.get_world_2d().direct_space_state
	for distance in [48.0, 80.0, 108.0]:
		for k in 16:
			var c: Vector2 = at + Vector2.from_angle(TAU * k / 16.0) * distance
			var q := PhysicsShapeQueryParameters2D.new()
			q.shape = cs.robot.get_child(0).shape
			q.transform = Transform2D(0, c)
			q.collision_mask = cs.robot.collision_mask
			q.exclude = [cs.robot.get_rid()]
			var over: Array = space.intersect_shape(q, 1)
			var dir := c.direction_to(at)
			var ray := PhysicsRayQueryParameters2D.create(c + dir * (18.0), at + dir * 4.4, cs.robot.collision_mask, [cs.robot.get_rid()])
			ray.hit_from_inside = true
			var hit: Dictionary = space.intersect_ray(ray)
			var hit_name := "-"
			if not hit.is_empty():
				var own = hit.collider.shape_owner_get_owner(hit.collider.shape_find_owner(int(hit.shape)))
				var who := "?"
				for pc in g.world.pieces.values():
					if g.world.static_cols.get(pc.id, []).has(own): who = str(pc.key)
				hit_name = "%s d_at=%.1f target=%s" % [who, (hit.position as Vector2).distance_to(at), targets.has(own)]
			hit_name += " cs=" + str(cs._contact_from(c, at, float(st.get("kerf", 3.4)), targets).is_finite())
			var over_name := "-" if over.is_empty() else str(over[0].collider.name) + "/" + str(over[0].collider.get_class())
			print("  d=", distance, " k=", k, " open=", over.is_empty(), " over=", over_name, " hit=", hit_name)


var takeovers := 0
# the operator finishes the recorded stroke the machine is stuck on, with the hand laser
func take_over_cut(actor) -> void:
	var st: Dictionary = g.plan.steps[g.plan.i]
	var kp = g.world.key_piece(str(st.get("key","")))
	if kp == null or kp.body != null or kp.gone: return
	var pts := PackedVector2Array()
	var from := 1
	var front := Vector2(float(st.pl[0][0]), float(st.pl[0][1]))
	if str(g.plan.cut_motion.get("key","")) == str(st.key) and g.plan.cut_motion.has("front"):
		front = Vector2(float(g.plan.cut_motion.front[0]), float(g.plan.cut_motion.front[1]))
		from = int(g.plan.cut_motion.get("segment",1))
	pts.append(front)
	for k in range(from, st.pl.size()): pts.append(Vector2(float(st.pl[k][0]), float(st.pl[k][1])))
	var xf: Transform2D = g.world.frame(kp)
	print("WHOLE B TAKEOVER step ", g.plan.i, " ", st.key, " points ", pts.size())
	g.plan.running = false
	g.plan._release_cutter()
	g.plan.cut_motion.clear()
	for k in range(1, pts.size()):
		if kp.gone or kp.body != null: break
		await actor.stroke(xf*pts[k-1]/Geom.M, xf*pts[k]/Geom.M, "takeover "+str(st.key))
	takeovers += 1
	g.plan.wait = ""
	g.plan.running = true
