extends "res://tests/g4_arm_extract_check.gd"
# A normal operator-marked queue entry, blocked by actual attached walls,
# falls back to the authorized clipping arm without becoming a plan dispatch.
func run() -> void:
	SaveGame.allow_test = false
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "pod"
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO,"kit":{"hauler":1}}
	root.add_child(g)
	await frames(10)
	g.tutorial = null
	g.drone.global_position = Vector2(-5,-12)*Geom.M
	g.drone.freeze = true
	g.load_received.connect(func(keys,zone,value,job): receipts.append({"keys":keys.duplicate(),"zone":zone,"value":value,"job":job}))
	var center := Vector2(30,0)*Geom.M
	var piece = g.world.add_piece("cargo",Geom.rect_poly(Rect2(center-Vector2(12,12),Vector2(24,24))),{"key":"MANUAL-RESCUE","cls":"equip","value":300.0,"mass":0.1})
	g.world.make_body([piece],null)
	piece.body.freeze = true
	for box in [Rect2(center+Vector2(-80,-80),Vector2(160,16)),Rect2(center+Vector2(-80,64),Vector2(160,16)),Rect2(center+Vector2(-80,-80),Vector2(16,160)),Rect2(center+Vector2(64,-80),Vector2(16,160))]:
		var wall = g.world.add_piece("hull",Geom.rect_poly(box),{"key":"MANUAL-WALL-%d" % g.world.pieces.size()})
		g.world.add_joint(wall,null,"clamp",box.get_center())
		g.world.rebuild_cols(wall)
	await frames(8)
	piece.body.set_meta("manual_mark",true)
	g.hauler.queue.append(piece.body)
	var handed_over := false
	for k in 3000:
		await process_frame
		if g.arm != null: handed_over = true
		if not receipts.is_empty(): break
	check(handed_over,"a real blocked operator-marked pickup hands over to the rail arm")
	check(receipts.size() == 1 and receipts[0].keys == ["MANUAL-RESCUE"] and receipts[0].zone == "equip" and piece.gone,"manual fallback completes actual equipment intake instead of remaining stuck")
	g.queue_free()
	await frames(5)
	var drain_until := Time.get_ticks_msec()+250
	while Time.get_ticks_msec() < drain_until: await process_frame
	print("G4 MANUAL ARM RESCUE: %d checks, %d failures" % [checks,fails])
	quit(1 if fails else 0)
