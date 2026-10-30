extends SceneTree
# Diagnostic development step toward the unchanged whole-ship gate. A successful
# probe only proves actual source-ship cutting, not full two-ship acceptance.
var g: Node
func _initialize() -> void: _run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func _run() -> void:
	Txt.cfg_path = "user://zp_test_g4_tug_probe_settings.cfg"
	Career.path = "user://zp_test_g4_tug_physical_probe_career.json"
	SaveGame.path = "user://zp_test_g4_tug_physical_probe_field.json"
	var resume := "--resume" in OS.get_cmdline_user_args()
	if resume:
		Career.data = {}
		Career.load_or_new()
	else:
		await fresh_career()
	SaveGame.allow_test = true
	SaveGame.load_requested = resume
	Game.contract = Career.active()
	Game.start_ship = "tug"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"consum":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	print("TUG TEST wall frame cap was ",Engine.max_fps,"; fixed simulation stays at 60 FPS / ",Engine.physics_ticks_per_second," physics ticks")
	Engine.max_fps = 0
	await frames(8)
	g.tutorial = null
	g.autosave_t = -1000000.0
	g.drone.global_position = Vector2(-5,-12)*Geom.M
	var actor = preload("res://tests/g4_tug_operator.gd").new(g)
	actor.stream_manual = "--haul" in OS.get_cmdline_user_args()
	var ok := true
	if not resume:
		ok = await actor.safe()
		g.auto_paused = true
		print("TUG PHYSICAL SAFE ",ok," errors=",actor.errors)
		if ok: await actor.disconnect_all()
		if ok: ok = await actor.segment_heavy()
		if ok: ok = await actor.separate_shell()
		if ok: await actor.unfix_all()
		await frames(30)
		if ok: SaveGame.save(g)
	for b in g.world.bodies:
		if is_instance_valid(b): print("TUG LOAD mass=",b.total_mass()," keys=",b.pieces.map(func(p):return p.key))
	var fixed: Array = []
	for p in g.world.pieces.values():
		if not p.gone and p.body == null: fixed.append(p.key)
	print("TUG FIXED ",fixed," remaining joints=",g.world.joints.filter(func(j):return j.alive).size())
	if ok and "--haul" in OS.get_cmdline_user_args(): ok = await actor.deliver_all_by_hand()
	print("TUG PHYSICAL PROBE safe=",ok," cuts=",g.plan.cuts_rec," hauls=",g.plan.hauls_rec," ended=",g.ended," rate=",g.recovery_rate()," ops=",g.ops," errors=",actor.errors," incidents=",g.incidents)
	var result: bool = ok and actor.errors.is_empty() and g.plan.cuts_rec > 0 and g.incidents.is_empty()
	g.queue_free()
	await frames(5)
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	quit(0 if result else 1)

func fresh_career() -> void:
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.market = true
	Career.data.done = 3
	Career.data.money = 200000.0
	Career.data.upgrades = {"lights":1,"net_fix":1,"furnace_main":1,"hauler":1}
	Career.save()
	var offer := Market.offer_for(777001,Career.data,1,"full","tug")
	Career.data.offers = [offer]
	Career.accept(0)
