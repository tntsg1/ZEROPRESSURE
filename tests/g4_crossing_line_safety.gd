extends "res://tests/plan_laser_check.gd"
# Normal beam teaches a real plate cut. A separate, declared pressurized
# pipe fixture crosses it without attaching to the target plate. The removed
# sensor case is an explicit availability-state fixture, not a delivery proof.
func _run() -> void:
	Txt.cfg_path = "user://zp_test_g4_crossing_settings.cfg"
	SaveGame.allow_test = false
	SaveGame.path = "user://zp_test_g4_crossing_field.json"
	Career.path = "user://zp_test_g4_crossing_career.json"
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
	check(not learned.is_empty(),"normal held beam records the actual plate cut")
	g.queue_free()
	await frames(5)
	await scene()
	var target = g.world.key_piece("G4-PLATE")
	var left = g.world.add_piece("hull",Geom.rect_poly(Rect2(AT+Vector2(-90,-24),Vector2(16,16))),{"key":"PIPE-LEFT"})
	var right = g.world.add_piece("hull",Geom.rect_poly(Rect2(AT+Vector2(74,-24),Vector2(16,16))),{"key":"PIPE-RIGHT"})
	g.world.add_joint(left,null,"clamp",AT+Vector2(-82,-16))
	g.world.add_joint(right,null,"clamp",AT+Vector2(82,-16))
	var cross_at := Vector2(float(learned[0].pl[1][0]),float(learned[0].pl[1][1]))
	g.world.add_line("G4-CROSSING-PIPE","pipe","g4_cross",left,AT+Vector2(-82,-16),right,AT+Vector2(82,-16),PackedVector2Array([cross_at+Vector2(-82,0),cross_at+Vector2(82,0)]))
	# Explicit hazardous fluid state: this fixture does not claim real pumping.
	g.sys.fvol["G4-CROSS"] = {"amount":1.0,"full":1.0,"fluid":"coolant","nets":["g4_cross"],"leak_min":0.02}
	g.plan.steps = learned.duplicate(true)
	g.plan.i = 0
	g.plan.preset = false
	g.plan.package_mode = false
	g.plan.running = true
	var before: Array = g.plan._shape(target)
	var incidents: int = g.incidents.size()
	g.plan._step_cut(g.plan.steps[0],100.0)
	check(g.plan.wait == "plan_cut_pipe" and g.plan.wait_arg == "G4-CROSSING-PIPE","an unrelated crossing pressurized pipe blocks and names the actual line")
	check(g.plan.i == 0 and g.plan._shape(target) == before and g.world.lines["G4-CROSSING-PIPE"].alive,"blocking leaves actual target material and crossing pipe unchanged")
	check(g.incidents.size() == incidents,"crossing-line preflight prevents an actual leak cut")
	g.sys.fvol["G4-CROSS"].amount = 0.0
	# Safe now, but the physical cutter must still arrive and perform its
	# finite-speed work. A synthetic 100-second call cannot bypass that travel.
	for frame in 1800:
		await process_frame
		if g.plan.i >= 1: break
	g.plan.running = false
	check(g.plan.i == 1 and g.plan._shape(target) != before,"safe drained line allows the real production kerf to commit")
	g.queue_free()
	await frames(5)
	await scene()
	target = g.world.key_piece("G4-PLATE")
	var site = null
	for c in g.world.ctrls.values():
		if c.kind == "test" and c.medium == "volt" and g.world.ctrl_alive(c):
			site = c
			break
	check(site != null,"availability fixture uses an actual existing bus test point")
	if site != null:
		g.do_measure({"kind":"ctrl","ctrl":site,"pos":g.world.ctrl_world(site)})
		var reading: Dictionary = g.sys.readings[site.id]
		var step: Dictionary = learned[0].duplicate(true)
		step.pre = [{"key":site.id,"kind":"volts","val":reading.val}]
		g.plan.steps = [step]
		g.plan.i = 0
		g.plan.running = true
		before = g.plan._shape(target)
		g.world.pieces[site.piece].gone = true # Declared sensor-unavailable negative state only.
		g.plan._step_cut(step,100.0)
		check(g.plan.wait == "plan_changed" and not g.plan.running and g.plan.i == 0,"a no-longer-present sensor cannot authorize replay with its historical reading")
		check(g.plan._shape(target) == before,"missing sensor never removes target material")
	g.queue_free()
	await frames(5)
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("CROSSING LINE SAFETY %s (%d checks, %d failed); declared pipe/availability fixtures, actual kerf" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
