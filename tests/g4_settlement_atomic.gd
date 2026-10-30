extends SceneTree
var g: Node
var checks := 0
var fails := 0
const CAREER := "user://zp_test_g4_atomic_career.json"
const FIELD := "user://zp_test_g4_atomic_field.json"
func _initialize() -> void: _run.call_deferred()
func frames(n: int) -> void:
	for k in n: await process_frame
func check(ok: bool,what: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",what])
func spawn(job: Dictionary) -> void:
	Game.start_ship = "tug"
	Game.contract = job.duplicate(true)
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	await frames(6)
	g.tutorial = null
func _run() -> void:
	Career.path = CAREER
	SaveGame.path = FIELD
	SaveGame.allow_test = true
	Career.data = Career.fresh()
	Career.data.money = 10000.0
	Career.data.gear = {"probe":2,"anchor":2}
	Career.data.loadout = {"mods":[],"deploy":{"probe":1,"anchor":1}}
	var job := {"id":"G4-ATOMIC-001","ship":"tug","fee":0,"time":900,"fee_paid":true,"kit":{},"items":{}}
	Career.gear_out(job)
	Career.data.active = job.duplicate(true)
	Career.save()
	await spawn(job)
	var port = null
	var sw = null
	for c in g.world.ctrls.values():
		if c.kind == "port" and c.medium == "gas": port = c
		if c.kind == "switch": sw = c
	check(port != null and sw != null,"real fittings are available for a deployed probe and manual recording")
	if port == null or sw == null: quit(1);return
	g.gear.act({"kind":"place","type":"probe","ctrl":port,"pos":g.world.ctrl_world(port)})
	g.do_wrench({"kind":"ctrl","ctrl":sw,"pos":g.world.ctrl_world(sw)})
	check(g.gear.units.size() == 1 and not g.plan.rec.is_empty(),"the live site has deployed equipment and a valid recorded operation")
	g.income_equip = 5000.0
	SaveGame.save(g)
	var field_before := FileAccess.get_file_as_string(FIELD)
	var saved_field := SaveGame.read()
	var data_before := JSON.stringify(Career.data)
	var disk_before := FileAccess.get_file_as_string(CAREER)
	var gear_before: Dictionary = g.gear.save_state()
	Career.path = "user://zp_g4_missing_parent_%d/sub/career.json" % Time.get_ticks_usec()
	g.finish_contract(true)
	check(not g.ended and g.state == "play" and g.settlement_retry_required,"failed career persistence leaves the ship playable with an explicit retry state")
	check(JSON.stringify(Career.data) == data_before,"a failed write rolls back cash, debt, equipment, notes and plans together")
	check(FileAccess.get_file_as_string(CAREER) == disk_before,"the prior career file is unchanged by the failed transaction")
	check(FileAccess.get_file_as_string(FIELD) == field_before,"the only field snapshot is not cleared before the career commits")
	check(g.gear.save_state() == gear_before,"a deployed probe is not finalized or lost when settlement fails")
	check(g.plan.result_key == "" and not g.plan.rec.is_empty(),"a failed write does not falsely report the recorded plan as saved")
	g.finish_contract(false)
	check(not g.ended and g.state == "play","automatic completion does not repeatedly retry a failed write")
	Career.path = CAREER
	var report: Dictionary = g.settle_report()
	g.finish_contract(true)
	check(g.ended and g.state == "ending" and int(Career.data.done) == 1,"manual retry commits the real settlement exactly once")
	check(Career.data.get("settled_jobs",{}).has(job.id),"the completed contract identity is part of the same durable commit")
	check(not FileAccess.file_exists(FIELD) and FileAccess.file_exists(FIELD+".done"),"the field snapshot is retired only after successful career persistence")
	check(g.gear.units.is_empty() and int(Career.data.gear.probe) == 1 and int(Career.data.gear.anchor) == 2,"deployment loss and returned equipment are applied once after commit")
	var once := JSON.stringify(Career.data)
	var repeated: Dictionary = Career.settle(report)
	check(repeated.get("already_settled",false) and JSON.stringify(Career.data) == once,"the settlement API refuses duplicate payout for the same job ID")
	g.queue_free()
	await frames(5)
	# Recreate the crash window: career committed but the old field still exists.
	SaveGame.write_file(FIELD,saved_field)
	SaveGame.load_requested = true
	await spawn(job)
	var before_recovery := JSON.stringify(Career.data)
	g.finish_contract(true)
	check(g.ended and g.career_result.get("already_settled",false),"an old field after a committed settlement is recognized on scene reconstruction")
	check(JSON.stringify(Career.data) == before_recovery,"crash-window recovery cannot duplicate cash, parts, gear or progress")
	check(not FileAccess.file_exists(FIELD),"recovering a committed contract retires its stale field snapshot")
	g.queue_free()
	await frames(5)
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G4 ATOMIC SETTLEMENT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
