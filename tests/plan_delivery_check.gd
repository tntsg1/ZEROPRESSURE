extends SceneTree
# G4 dispatch is not delivery. Exercise the real hauler and recovery mouth.
var g: Node
var fails := 0
var checks := 0
func _initialize() -> void:
	_run.call_deferred()
func frames(n: int) -> void:
	for k in n: await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])
func _run() -> void:
	SaveGame.allow_test = false
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "pod"
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO,"kit":{"hauler":1}}
	root.add_child(g)
	await frames(10)
	g.tutorial = null
	g.plan.set_physics_process(false)
	g.hauler.set_physics_process(false)
	var pos: Vector2 = Dock.zpos("equip") + Dock.ZONES.equip.face * 3.0 * Geom.M
	var poly := PackedVector2Array([pos+Vector2(-9,-9),pos+Vector2(9,-9),pos+Vector2(9,9),pos+Vector2(-9,9)])
	var p = g.world.add_piece("cargo",poly,{"key":"G4-DELIVERY","tag":"G4-DELIVERY","cls":"equip","value":100.0,"mass":0.1})
	g.world.make_body([p],null)
	var b = p.body
	b.freeze = true
	g.plan.steps = [{"do":"haul","keys":[p.key],"zone":"equip","pre":[]}]
	g.plan.i = 0
	g.plan.running = false
	g.plan.haul_watch = [{"keys":[p.key],"zone":"equip"}]
	g.plan._watch_hauls()
	check(not g.hauler.queue.has(b),"stopped plans do not dispatch queued work")
	g.plan.running = true
	g.plan._watch_hauls()
	check(g.arm != null and g.arm.queue.has(b) and g.plan.haul_watch.size() == 1,"dispatch queues the real rail arm but keeps delivery outstanding")
	check(g.arm._zone_for(b) == "equip","rail arm follows the recorded destination")
	b.set_meta("plan_zone","metal")
	check(g.arm._zone_for(b) == "metal","explicit destination is not silently replaced by automatic sorting")
	b.set_meta("plan_zone","equip")
	g.plan.i = 1
	g.plan._physics_process(1.0 / 60.0)
	check(g.plan.running and g.plan.status()[1] != Txt.t("plan_done"),"end of instruction list is not the end of outstanding delivery")
	g.plan.cancel()
	check(not g.arm.queue.has(b) and not b.has_meta("plan_zone"),"P cancellation revokes this plan's queued load and destination override")
	check(g.plan.toggle() != "plan_done" and g.plan.running,"unfinished delivery can resume after the instruction list")
	var saved: Dictionary = g.plan.save_state()
	g.plan.haul_watch.clear()
	g.plan.load_state(saved)
	check(g.plan.haul_watch.size() == 1,"outstanding delivery survives plan state round trip")
	g.plan._watch_hauls()
	b.freeze = false
	g.hauler.pos = pos + Vector2(40,20)
	g.drone.global_position = Vector2(-5,-12) * Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	g.hauler.set_physics_process(true)
	g.plan.set_physics_process(true)
	for k in 4200:
		await process_frame
		if g.plan.haul_watch.is_empty(): break
	check(g.plan.haul_watch.is_empty(),"real rail-arm transport and normal swallowing acknowledge delivery")
	await frames(4)
	check(not g.plan.running and g.plan.status()[1] == Txt.t("plan_done"),"plan completes only after the recovery event")
	check(g.income_equip > 0,"equipment actually reached the paying equipment bay")
	g.queue_free()
	await frames(4)
	# The audio mixer runs on wall time even when --fixed-fps simulates rapidly.
	var drain_until := Time.get_ticks_msec() + 250
	while Time.get_ticks_msec() < drain_until: await process_frame
	print("PLAN DELIVERY %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
