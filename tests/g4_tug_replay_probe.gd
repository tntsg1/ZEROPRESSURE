extends "res://tests/g4_whole_ship_check.gd"
# Diagnostic only: resumes an actual test-created mid-plan field. It cannot
# establish a fresh two-ship acceptance result or supply a manual baseline.
var load_trace := {}
func trace_load(key: String) -> void:
	var p = g.world.key_piece(key)
	if p == null: return
	var b = p.body
	var pos: Vector2 = g.world.frame(p)*Geom.centroid(p.poly)
	var status := "%s:%s:%s:%s:%s:%s:%s" % [p.gone,p.intact,str(b.capture) if is_instance_valid(b) else "attached",str(b.get_meta("arm_by","")) if is_instance_valid(b) else "",str(b.get_meta("plan_zone","")) if is_instance_valid(b) else "",g.hauler.state,g.hauler.zone]
	var old: Dictionary = load_trace.get(key,{})
	if status != old.get("status","") or pos.distance_to(old.get("pos",pos)) > 3.0*Geom.M:
		print("LOAD TRACE key=",key," step=",g.plan.i," pos=",pos/Geom.M," intact=",p.intact," cond=",p.cond," temp=",p.temp," capture=",str(b.capture) if is_instance_valid(b) else "attached"," carrier=",str(b.get_meta("arm_by","")) if is_instance_valid(b) else ""," intended=",str(b.get_meta("plan_zone","")) if is_instance_valid(b) else ""," hauler=",g.hauler.state,"/",g.hauler.zone," claw=",g.hauler.pos/Geom.M," goal=",g.hauler._goal/Geom.M)
		load_trace[key] = {"status":status,"pos":pos}
func _run() -> void:
	Txt.cfg_path = "user://zp_test_g4_replay_probe_settings.cfg"
	Career.path = "user://zp_test_plancut_physical_career.json"
	SaveGame.path = "user://zp_test_plancut_physical_field.json"
	SaveGame.allow_test = true
	Career.data = {}
	Career.load_or_new()
	await spawn(true)
	var actor = Operator.new(g)
	g.plan.package_mode = false
	g.plan.toggle()
	var same := 0
	var last := ""
	for frame in 60000:
		await process_frame
		trace_load("BAT-T")
		trace_load("TOP-2")
		if g.ended: break
		release_requested()
		if g.plan.wait in ["plan_measure","plan_differs"]: await actor.read_requested()
		var progress := "%d:%s:%d" % [g.plan.i,g.plan.wait,g.ledger.size()]
		if progress != last:
			print("REPLAY PROBE ",progress)
			last = progress
			same = 0
		else: same += 1
		if same > 2400 and g.plan.wait != "": break
		if g.plan.haul_watch.any(func(w):return w.get("failed",false)):
			for pending in g.plan.haul_watch:
				if pending.get("failed",false): print("REPLAY FAILED DELIVERY ",pending," actual_event=",paid_events.get(JSON.stringify(pending.keys),{}))
			break
	if g.plan.i < g.plan.steps.size():
		var step: Dictionary = g.plan.steps[g.plan.i]
		var p = g.world.key_piece(str(step.get("key","")))
		print("REPLAY EXPECTED ",step)
		if p != null:
			print("REPLAY ACTUAL SHAPE ",g.plan._shape(p))
			print("REPLAY ACTUAL LINKS ",g.plan._links(p))
		print("REPLAY EXECUTION running=",g.plan.running," timer=",g.plan.step_t," game=",g.state," auto_paused=",g.auto_paused)
	print("REPLAY DIAGNOSTIC ended=",g.ended," cuts=",machine_cuts," rate=",g.recovery_rate()," wait=",g.plan.wait," / ",g.plan.wait_arg," incidents=",g.incidents)
	await dispose()
	await finish()
func finish() -> void:
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("REPLAY DIAGNOSTIC ONLY; no whole-ship acceptance verdict")
	quit(0)
