extends "res://tests/plan_laser_check.gd"
# Declared anchored plate; normal production WorkPlan and actual rigid-body
# cutter perform the material work. No cargo position/deletion shortcuts.
func _run() -> void:
	SaveGame.allow_test = false
	SaveGame.path = "user://zp_test_cutter_plan_field.json"
	Career.path = "user://zp_test_cutter_plan_career.json"
	await scene()
	g.bot.lmb = false
	var p = g.world.key_piece("G4-PLATE")
	var before: Array = g.plan._shape(p)
	g.plan.steps = [{"do":"cut","key":"G4-PLATE","pl":[[AT.x,AT.y-14],[AT.x,AT.y+14]],"pre":[],"rooms":[],"kerf":World.KERF}]
	g.plan.preset = false
	g.plan.package_mode = false
	g.plan.running = true
	await frames(12)
	check(g.plan._shape(p) == before,"material is unchanged while the actual cutter is still at its distant berth")
	var service = g.plan.cutter_service()
	check(service.robot is RigidBody2D and service.robot.global_position.distance_to(AT) > 200,"plan has assigned a distinct physical machine, not the player's drone")
	var partial := false
	var moved := false
	var start: Vector2 = service.robot.global_position
	for k in 4000:
		await process_frame
		moved = moved or service.robot.global_position.distance_to(start) > 100.0
		if g.plan._shape(p) != before and g.plan.i == 0: partial = true
		if g.plan.i == 1: break
	print("CUTTER INTEGRATION i=",g.plan.i," wait=",g.plan.wait," pos=",service.robot.global_position," reason=",service.reason," motion=",g.plan.cut_motion)
	check(moved,"the cutter actually travels from its berth under physics")
	check(partial,"real target geometry changes progressively before the recorded stroke is finished")
	check(g.plan.i == 1,"actual robot finishes the declared structural cut")
	check(g.world.bodies.any(func(b):return b.pieces.any(func(q):return q.key.begins_with("G4-PLATE"))),"material cutting creates an actual free fragment")
	g.plan.cancel()
	check(not service.robot.beam_on and not service.robot.commanded,"production plan cancellation shuts down the physical executor")
	g.queue_free()
	await frames(6)
	print("G4 CUTTER PLAN FIXTURE: %d checks, %d failures; not the original two-ship gate" % [checks,fails])
	var drain_until := Time.get_ticks_msec()+250
	while Time.get_ticks_msec() < drain_until: await process_frame
	quit(1 if fails else 0)
