extends "res://tests/g4_whole_ship_check.gd"
# Focused real-input regression for omitted end-of-stroke dot kerfs. This
# verifies geometry/identity only; it is not whole-ship recovery evidence.
func _run() -> void:
	Txt.cfg_path = "user://zp_test_g4_cut_tail_settings.cfg"
	Career.path = "user://zp_test_g4_cut_tail_career.json"
	SaveGame.path = "user://zp_test_g4_cut_tail_field.json"
	SaveGame.allow_test = false
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.market = true
	Career.data.done = 3
	Career.data.money = 200000.0
	Career.data.methods = {"cutter": 1}   # 104 号: the cutter working a plan is a learned method
	Career.save()
	take_tug()
	await spawn()
	var actor = Operator.new(g)
	check(await actor.safe(),"source safety uses actual pumped gas and powered doors")
	await actor.disconnect_all()
	for x in [2.9,4.5,6.1,7.7]:
		check(await actor.stroke(Vector2(x,3.4),Vector2(x,2.5),"tail regression"),"normal held beam commits a physical keel cut at %.1f" % x)
	var door_areas := {}
	for key in ["HATCH-A","DR-AM"]: door_areas[key] = Geom.area(g.world.world_poly(g.world.key_piece(key)))
	for pair in [["p6","HATCH-A"],["HATCH-A","p8"],["DR-AM","BH-AM"]]:
		var a = g.world.key_piece(pair[0])
		var b = g.world.key_piece(pair[1])
		var welds: Array = g.world.joints_of(a).filter(func(j):return j.type == "weld" and (j.a == b.id or j.b == b.id))
		check(not welds.is_empty() and await actor.cut_seam(welds),"normal frame-side laser releases the actual door welds: "+str(pair))
	for key in door_areas:
		var door = g.world.key_piece(key)
		check(door != null and not door.gone and absf(Geom.area(g.world.world_poly(door))-float(door_areas[key]))/float(door_areas[key]) < 0.0001,"frame cutting preserves the actual complete door material: "+key)
	check(not g.plan.rec.any(func(st):return st.get("do","") == "cut" and st.get("key","") in ["HATCH-A","DR-AM"]),"the taught automatic route contains no door-material cuts")
	var learned: Array = g.plan.rec.duplicate(true)
	var dots: Array = learned.filter(func(st):return st.get("do","") == "cut" and st.pl.size() == 2 and st.pl[0] == st.pl[1])
	# 87-1: the beam now pays for the slot its spot melts ahead of the front, so a held stroke no
	# longer races to its end and sits there leaving a dot; any dot that is recorded must replay
	print("end-of-stroke dot kerfs in the recording: %d" % dots.size())
	var source_signature := factory_signature()
	var source_sequence: int = g.world.key_piece("KEEL").cut_seq
	await dispose()
	await spawn()
	actor = Operator.new(g)
	g.plan.steps = learned.duplicate(true)
	g.plan.package_mode = false
	g.plan.toggle()
	var disconnected := false
	# the operator reached the DR-AM / BH-AM seam inside a closed compartment (the test places the
	# drone at each stroke); the berth's cutter can only fly, so there it waits for the operator
	var blocked := 0
	var waited := false
	for frame in 15000:
		await process_frame
		if g.plan.i >= learned.size(): break
		if g.plan.wait == "plan_cutter_wait" and str(g.plan.wait_arg) == "BH-AM" and g.plan.cutter_service().reason == "route_blocked":
			blocked += 1
		else:
			blocked = 0
		if blocked > 0:
			if blocked == 90 and not waited:
				waited = true
				var a = g.world.key_piece("DR-AM")
				var b = g.world.key_piece("BH-AM")
				var welds: Array = g.world.joints_of(a).filter(func(j):return j.type == "weld" and (j.a == b.id or j.b == b.id))
				check(not welds.is_empty(), "the berth's cutter waits at the seam in the closed compartment instead of sitting at a spot it cannot reach")
				check(await actor.cut_seam(welds), "the operator cuts that seam by hand and the plan goes on")
		if g.plan.wait in ["plan_measure","plan_differs"]: await actor.read_changed()
		if not disconnected and g.plan.i < learned.size() and learned[g.plan.i].get("do","") == "cut":
			await actor.disconnect_all()
			disconnected = true
	# Match the source operator's post-release wait: World creates/reframes
	# genuinely detached bodies on its following physics tick.
	await frames(10)
	print("TAIL REPLAY index=",g.plan.i,"/",learned.size()," wait=",g.plan.wait," / ",g.plan.wait_arg)
	check(g.plan.i == learned.size(),"all recorded real strokes and dot kerfs replay without a structure stop")
	check(g.world.key_piece("KEEL").cut_seq == source_sequence,"replay preserves the actual keel fragment sequence")
	if factory_signature() != source_signature:
		var expected: Array = JSON.parse_string(source_signature)
		var actual: Array = JSON.parse_string(factory_signature())
		for entry in expected:
			var found: Array = actual.filter(func(q):return q[0] == entry[0])
			if found.is_empty() or found[0] != entry: print("TAIL DIFFERENCE expected=",entry," actual=",found)
	check(factory_signature() == source_signature,"all actual resulting piece shapes, child identities and full connection signatures match")
	check(g.incidents.is_empty(),"the real replay remains incident-free")
	await dispose()
	await finish()
func finish() -> void:
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("CUT TAIL %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
