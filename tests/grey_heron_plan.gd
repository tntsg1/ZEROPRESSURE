extends SceneTree
const Cap = preload("res://tests/cap.gd")
var fails := 0
var checks := 0
var g: Node
func _initialize() -> void:
	_run.call_deferred()
func frames(n: int) -> void:
	for k in n: await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
func spawn(job: Dictionary) -> Node:
	Game.contract = job
	Game.start_ship = "gr7"
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(scene)
	return scene
func run_plan(label: String) -> void:
	if "--capture" in OS.get_cmdline_user_args() and label == "reported GR-59":
		g.cam_override = Vector2(1008,-80)
		g.cam_pos = g.cam_override
		g.cam_vel = Vector2.ZERO
		g.zoom_override = 0.57
		g.zoom_now = 0.57
		g.hud.t = 5.0
		await frames(5)
		await RenderingServer.frame_post_draw
		Cap.save(root,"res://proofs/grey_plan_ready.png")
	check(g.plan.preset and g.plan.has_plan(),label + ": preset exists without a learned plan")
	check(g.plan.toggle() == "plan_preset_running",label + ": P starts automatic preparation")
	await frames(30)
	check(g.plan.toggle() == "plan_stopped",label + ": P pauses")
	var paused_at: int = g.plan.i
	await frames(30)
	check(g.plan.i == paused_at,label + ": paused plan performs no steps")
	var restored := WorkPlan.new()
	restored.setup(g)
	restored.load_state(g.plan.save_state())
	check(restored.preset and restored.i == paused_at,label + ": preset progress survives save/resume")
	restored.free()
	g.plan.toggle()
	var last := -1
	for n in 20000:
		if g.plan.i != last:
			last = g.plan.i
			print(label," step ",last,"/",g.plan.steps.size()," ",g.plan.wait," ",g.plan.wait_arg)
		if not g.plan.running: break
		await process_frame
	print(label," FINAL ",g.plan.i," ",g.plan.wait," ",g.plan.wait_arg," rooms=",g.world.rooms.keys()," gas=",g.sys.P("A"),"/",g.sys.P("C"),"/",g.sys.P("D")," T=",g.sys.loop_T," fuel=",g.sys.fluid("fuel")," coolant=",g.sys.fluid("cool")," incidents=",g.incidents)
	check(g.plan.i == g.plan.steps.size(),label + ": completes with no manual measurements or room reveals")
	check(g.incidents.is_empty(),label + ": no preparation incidents")
	check(not g.sys.bus_live and not g.sys.aux and not g.sys.running("G-01"),label + ": generator, main bus and dock supply are off")
	check(g.sys.P("A") <= 1 and g.sys.P("C") <= 1 and g.sys.P("D") <= 1,label + ": compartments depressurized")
	check(g.sys.fluid("fuel") < 0.01 and g.sys.fluid("cool") < 0.01 and g.sys.loop_T <= 55,label + ": fluids recovered and loop cooled")
	check(g.plan.rec.is_empty(),label + ": automatic steps never become a manual recording")
	if "--capture" in OS.get_cmdline_user_args() and label == "reported GR-59":
		await RenderingServer.frame_post_draw
		Cap.save(root,"res://proofs/grey_plan_done.png")
	g.queue_free()
	await frames(3)
func _run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Career.path = "user://zp_test_grey_plan_career.json"
	SaveGame.path = "user://zp_test_grey_plan_save.json"
	Career.data = Career.fresh()
	Career.save()
	Engine.time_scale = 4.0
	g = spawn({"id":"PRESET-BASE","ship":"gr7","fee":0})
	await frames(5)
	await run_plan("factory")
	g = spawn({"id":"PRESET-VARIANT","ship":"gr7","variant":1498002416,"stars":3,"fee":0})
	await frames(5)
	# A partially prepared ship must not have its switches/hoses reversed.
	g._operate(g.world.ctrls["K-G"],g.world.ctrl_world(g.world.ctrls["K-G"]))
	g._operate(g.world.ctrls["V-C01"],g.world.ctrl_world(g.world.ctrls["V-C01"]))
	g.do_hose({"ctrl":g.world.ctrls["GAS-AB"],"pos":g.world.ctrl_world(g.world.ctrls["GAS-AB"])},true)
	g.plan.load_state({"i":24,"rec":[]})
	check(g.plan.i == 0,"an old save without preset metadata starts safely at the first state check")
	await run_plan("partial variant")
	g = spawn({"id":"041-GR-59","reg":"GR-59","ship":"gr7","variant":736589889,"traps":["fire_system"],"stars":1,"scope":"full","fee":0})
	await frames(5)
	await run_plan("reported GR-59")
	g = spawn({"id":"PRESET-GUARD","ship":"gr7","fee":0})
	await frames(5)
	g.world.ctrls.erase("V-C01")
	g.plan.toggle()
	# the preset steps on its own clock (STEP_TIME): wait for its verdict, not a fixed 35 frames
	for k in 240:
		if g.plan.wait != "": break
		await frames(1)
	check(not g.plan.running and g.plan.wait == "plan_changed" and g.plan.i == 0,"missing fitting stops the preset before any dependent action")
	g.queue_free()
	await frames(3)
	g = spawn({"id":"PRESET-DEAD-LEG","ship":"gr7","fee":0})
	await frames(5)
	g.plan.i = 10
	g.plan.toggle()
	for k in 240:
		if g.plan.wait != "": break
		await frames(1)
	check(g.plan.i == 10 and g.plan.wait == "plan_preset_blocked" and not g.world.tag("HATCH-1").door_open,"an empty dead-leg reading with its valve shut cannot authorize opening the pressurized hold")
	g.queue_free()
	await frames(3)
	Career.data.plans.gr7 = [{"do":"w","ctrl":"K-G","pre":[]}]
	g = spawn({"id":"PRESET-CUSTOM","ship":"gr7","fee":0})
	await frames(5)
	check(not g.plan.preset and g.plan.steps.size() == 1,"an existing player-recorded plan takes priority")
	g.queue_free()
	await frames(3)
	Engine.time_scale = 1.0
	print("GREY HERON PRESET %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
