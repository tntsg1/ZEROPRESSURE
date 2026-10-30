extends SceneTree
# Explicitly authorized clipping extraction, not a collision-safe haul test.
# Enclosure and loose equipment are declared fixtures; actual arm motion and
# normal receiving/settlement provide the evidence, never a preset receipt.
var g: Node
var checks := 0
var fails := 0
var receipts: Array = []
class CancelAtCapture:
	extends Node
	var scene
	var checked := false
	var preserved := false
	func _physics_process(_dt: float) -> void:
		if checked or scene.arm == null: return
		scene.arm.process_physics_priority = 10
		var load_body = scene.arm.body
		if not is_instance_valid(load_body) or load_body.capture == null: return
		var mask: int = load_body.collision_mask
		var layer: int = load_body.collision_layer
		var frozen: bool = load_body.freeze
		checked = true
		scene.plan.cancel()
		preserved = load_body.collision_mask == mask and load_body.collision_layer == layer and load_body.freeze == frozen and load_body.capture != null
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for k in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
func run() -> void:
	SaveGame.allow_test = false
	SaveGame.path = "user://zp_test_arm_extract_field.json"
	SaveGame.train_path = "user://zp_test_arm_extract_train.json"
	Career.path = "user://zp_test_arm_extract_career.json"
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "pod"
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO,"kit":{"hauler":1}}
	root.add_child(g)
	await frames(10)
	g.tutorial = null
	g.hauler.set_physics_process(false)
	g.drone.global_position = Vector2(-5,-12)*Geom.M
	g.drone.freeze = true
	g.load_received.connect(func(keys,zone,value,job): receipts.append({"keys":keys.duplicate(),"zone":zone,"value":value,"job":job}))
	var center := Vector2(30,0)*Geom.M
	var piece = g.world.add_piece("cargo",Geom.rect_poly(Rect2(center-Vector2(12,12),Vector2(24,24))),{"key":"ARM-ENCLOSED","cls":"equip","value":500.0,"mass":0.1})
	g.world.make_body([piece],null)
	var load_body = piece.body
	load_body.freeze = true
	for box in [Rect2(center+Vector2(-50,-50),Vector2(100,10)),Rect2(center+Vector2(-50,40),Vector2(100,10)),Rect2(center+Vector2(-50,-50),Vector2(10,100)),Rect2(center+Vector2(40,-50),Vector2(10,100))]:
		var wall = g.world.add_piece("hull",Geom.rect_poly(box),{"key":"ARM-WALL-%d" % g.world.pieces.size()})
		g.world.add_joint(wall,null,"clamp",box.get_center())
		g.world.rebuild_cols(wall)
	# Let the normal newly-freed-body collision grace expire before proving
	# the enclosure; otherwise this would test the spawn grace, not the walls.
	for k in 60:
		await process_frame
		if load_body.ghost <= 0.0: break
	await frames(8)
	print("ENCLOSURE before extraction pos=",load_body.global_position," mask=",load_body.collision_mask," ghost=",load_body.ghost," walls=",g.world.static_cols.size())
	check(load_body.test_move(load_body.global_transform,Vector2(0,-80)),"actual enclosure blocks the full load before extraction")
	g.plan.steps = [{"do":"haul","keys":[piece.key],"zone":"equip","pre":[]}]
	g.plan.haul_watch = [{"keys":[piece.key],"zone":"equip"}]
	g.plan.i = 1
	g.plan.running = true
	g.plan._watch_hauls()
	check(g.arm != null and g.arm.queue.has(load_body),"authorized plan assigns the real rail arm instead of a pathfinding drone")
	check(not g.plan.haul_watch.is_empty() and receipts.is_empty(),"assignment does not fake delivery or settlement")
	var original: Vector2 = load_body.global_position
	var carried := false
	var clipped := false
	var max_step := 0.0
	var previous := original
	var snapshot := false
	var saved_income := 0.0
	for k in 2400:
		await process_frame
		if is_instance_valid(load_body) and load_body.capture == null:
			max_step = maxf(max_step,load_body.global_position.distance_to(previous))
			previous = load_body.global_position
			if g.arm.state == "carry":
				carried = true
				clipped = clipped or load_body.global_position.distance_to(original) > 80.0
				if not snapshot and load_body.global_position.distance_to(original) > 20.0:
					SaveGame.allow_test = true
					saved_income = g.income_equip
					SaveGame.save(g)
					var disk: Dictionary = SaveGame.read(SaveGame.file_for(g))
					snapshot = not disk.is_empty() and disk.world.bodies.any(func(entry): return entry.get("arm_parked",false))
		if not receipts.is_empty(): break
	check(carried and clipped,"arm visibly carries the actual enclosed load through the obstruction")
	check(max_step < 12.0,"extraction moves continuously rather than teleporting the load")
	check(receipts.size() == 1 and receipts[0].keys == ["ARM-ENCLOSED"] and receipts[0].zone == "equip" and receipts[0].value > 0,"normal equipment mouth emits exactly one correct paid receipt")
	check(piece.gone and g.plan.haul_watch.is_empty(),"only actual receiver completion removes the piece and finishes the delivery")
	check(g.income_equip > 0 and g.incidents.is_empty(),"equipment settlement remains intact without a fabricated incident-free result")
	check(snapshot,"actual mid-carry disk save marks the extracted physical load for safe parking")
	g.queue_free()
	await frames(5)
	receipts.clear()
	SaveGame.load_requested = true
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "pod"
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO,"kit":{"hauler":1}}
	root.add_child(g)
	await frames(10)
	g.tutorial = null
	g.load_received.connect(func(keys,zone,value,job): receipts.append({"keys":keys.duplicate(),"zone":zone,"value":value,"job":job}))
	var restored = g.world.key_piece("ARM-ENCLOSED")
	check(restored != null and restored.body != null,"actual field reload reconstructs the carried equipment")
	if restored != null and restored.body != null:
		var parked = restored.body
		var parked_at: Vector2 = parked.global_position
		await frames(60)
		check(parked.get_meta("arm_parked",false) and parked.freeze and parked.collision_mask == 0 and parked.global_position.distance_to(parked_at) < 0.01,"loaded extraction stays parked inside geometry without drifting or auto-delivering")
		check(not g.plan.running and receipts.is_empty(),"disk reload requires new authorization and cannot invent a receipt")
		var race := CancelAtCapture.new()
		race.scene = g
		race.process_physics_priority = 5
		g.add_child(race)
		g.plan.toggle()
		for k in 2400:
			await process_frame
			if not receipts.is_empty(): break
		check(receipts.size() == 1 and receipts[0].zone == "equip" and restored.gone,"reauthorized rail arm resumes actual extraction and receiver completion")
		check(receipts.size() == 1 and absf(g.income_equip-saved_income-float(receipts[0].value)) < 0.001,"loaded contract books exactly one real receiver payment")
		check(race.checked and race.preserved,"cancellation immediately after actual Dock capture preserves receiver freeze and collision ownership")
	# A newly assigned load starts inside a WRONG mouth's physical catch. Its
	# dispatch-to-receipt reservation must protect it even before the claw grips.
	receipts.clear()
	var wrong_at: Vector2 = Dock.zpos("hazard")
	var protected_piece = g.world.add_piece("cargo",Geom.rect_poly(Rect2(wrong_at-Vector2(10,10),Vector2(20,20))),{"key":"ARM-RECEIVER-LOCK","cls":"equip","value":250.0,"mass":0.1})
	g.world.make_body([protected_piece],null)
	protected_piece.body.freeze = true
	g.plan.steps = [{"do":"haul","keys":[protected_piece.key],"zone":"equip","pre":[]}]
	g.plan.i = 1
	g.plan.haul_watch = [{"keys":[protected_piece.key],"zone":"equip"}]
	g.plan.running = true
	g.plan._watch_hauls()
	await frames(20)
	check(not protected_piece.gone and protected_piece.body.capture == null and receipts.is_empty(),"wrong mouth cannot steal an assigned load before the distant arm reaches it")
	for k in 2400:
		await process_frame
		if not receipts.is_empty(): break
	check(receipts.size() == 1 and receipts[0].keys == ["ARM-RECEIVER-LOCK"] and receipts[0].zone == "equip" and protected_piece.gone,"load leaves the wrong mouth and receives exactly one payment at its assigned equipment mouth")
	g.queue_free()
	await frames(5)
	var drain_until := Time.get_ticks_msec()+250
	while Time.get_ticks_msec() < drain_until: await process_frame
	print("G4 ARM EXTRACTION: %d checks, %d failures; declared fixtures, not whole-ship acceptance" % [checks,fails])
	quit(1 if fails else 0)
