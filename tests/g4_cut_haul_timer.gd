extends "res://tests/plan_laser_check.gd"
# Declared plate/loose-stock fixtures. The player beam creates the recording;
# real executor ticks must cut while an unrelated unserviceable haul waits.
# This is a focused physical timer regression, not whole-ship acceptance.
func _run() -> void:
	Txt.cfg_path = "user://zp_test_g4_cut_haul_timer_settings.cfg"
	SaveGame.allow_test = false
	SaveGame.path = "user://zp_test_g4_cut_haul_timer_field.json"
	SaveGame.train_path = "user://zp_test_g4_cut_haul_timer_train.json"
	Career.path = "user://zp_test_g4_cut_haul_timer_career.json"
	Career.data = Career.fresh()
	Career.data.active = {}
	await scene()
	g.bot.aim = AT+Vector2(0,11)
	g.bot.lmb = true
	await frames(60)
	g.bot.aim = AT+Vector2(0,16)
	await frames(20)
	g.bot.lmb = false
	await frames(8)
	var learned: Array = g.plan.rec.duplicate(true)
	check(not learned.is_empty(),"a normal held beam supplies actual geometric cut steps")
	g.queue_free()
	await frames(5)
	await scene()
	var p = g.world.add_piece("hull",Geom.rect_poly(Rect2(AT+Vector2(140,-20),Vector2(40,40))),{"key":"WAITING-STOCK","density":100.0})
	g.world.rebuild_cols(p)
	g.world.relink()
	await frames(5)
	check(p.body != null and not g.plan.game.plan_mark(p.body,"metal"),"declared full-size stock is a real body with no eligible delivery machine")
	var keys: Array = g.plan._body_keys(p.body)
	g.plan.steps = learned.duplicate(true)
	g.plan.package_mode = false
	g.plan.preset = false
	g.plan.haul_watch = [{"keys":keys,"zone":"metal"}]
	g.plan.i = 0
	g.plan.running = true
	# Arrival is now real flight from the maintenance berth. Bound that travel
	# separately, then keep the original 900-frame work deadline unchanged.
	var arrived := false
	for frame in 1800:
		await process_frame
		if int(g.ops.get("plan",0)) > 0:
			arrived = true
			break
	check(arrived,"the physical cutter reaches the work site and actually starts material work")
	for frame in 900:
		await process_frame
		if g.plan.i >= learned.size(): break
	print("TIMER RESULT i=",g.plan.i,"/",learned.size()," elapsed=",g.plan.step_t," wait=",g.plan.wait)
	check(g.plan.i == learned.size(),"an unrelated blocked haul cannot reset real cutting work every half second")
	check(not p.gone and g.plan.haul_watch.size() == 1,"blocked stock remains real and pending rather than being deleted or counted delivered")
	check(int(g.ops.get("plan",0)) > 0 and g.incidents.is_empty(),"actual machine cuts commit with no incident")
	g.queue_free()
	await frames(5)
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("CUT HAUL TIMER %s (%d checks, %d failed); declared physical fixtures" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
