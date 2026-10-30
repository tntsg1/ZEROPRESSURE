extends SceneTree
# Real FreeBody physics and the actual hauler state machine. No player saves.
var failures := 0
var g: Node
const DT := 1.0 / 120.0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
	if not ok: failures += 1

func plate(at: Vector2, tonnes: float, tag: String, half: Vector2 = Vector2(8,8)):
	var poly := PackedVector2Array([at - half,at + Vector2(half.x,-half.y),at + half,at + Vector2(-half.x,half.y)])
	var p = g.world.add_piece("hull",poly,{"density": tonnes / (4 * half.x * half.y / (Geom.M * Geom.M)),"tag":tag})
	g.world.make_body([p],null)
	p.body.linear_velocity = Vector2.ZERO
	return p.body

func tick(h, seconds: float) -> void:
	for i in ceili(seconds / DT):
		await physics_frame
		h._physics_process(DT)

func _run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "pod"
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO,"kit":{"hauler":1,"hauler2":1}}
	root.add_child(g)
	for i in 15: await process_frame
	g.tutorial = null
	g.hauler.set_physics_process(false)
	g.hauler2.set_physics_process(false)
	g.drone.global_position = Vector2(-4,-12) * Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	var h = g.hauler
	var center := Vector2(30,-6) * Geom.M
	var target = plate(center,0.1,"CLEAR-TARGET")
	var blocker = plate(center + Vector2(24,0),3.0,"CLEAR-BLOCKER")
	var start: Vector2 = blocker.global_position
	h.pos = center - Vector2(160,0)
	h.vel = Vector2.ZERO
	h._set_off(target)
	var picked := false
	for i in 1440:
		await physics_frame
		h._physics_process(DT)
		if h.state == "carry":
			picked = true
			break
	if picked: await tick(h,0.5)
	print("BLOCKED PICKUP state=%s gap=%.2f blocker displacement=%.2f" % [h.state,h.pos.distance_to(target.global_transform * target.center_of_mass),blocker.global_position.distance_to(start)])
	check(picked,"adjacent loose debris no longer holds pickup in a permanent avoidance equilibrium")
	check(blocker.global_position.distance_to(start) > 8,"obstruction actually moves through physics rather than being ignored")
	check(blocker.linear_velocity.length() < 100,"clearance pushes remain gentle instead of flinging the obstruction")
	h.halt()
	# Separate each case from earlier drifting debris, outside the authored ship.
	center = Vector2(40,-6) * Geom.M
	var protected_body = plate(center + Vector2(24,0),1,"CLEAR-CLAIMED")
	protected_body.set_meta("arm",true)
	protected_body.set_meta("arm_by","hauler2")
	var protected_start: Vector2 = protected_body.global_position
	h.pos = center - Vector2(80,0)
	h.vel = Vector2.ZERO
	h.state = "reach"
	h.body = null
	for i in 240:
		await physics_frame
		h._fly(center,DT)
	check(protected_body.global_position.distance_to(protected_start) < 1,"another machine's claimed cargo is never pushed aside")
	protected_body.set_meta("arm",false)
	protected_body.freeze = true
	h.pos = center - Vector2(80,0)
	h.vel = Vector2.ZERO
	for i in 120:
		await physics_frame
		h._fly(center,DT)
	check(protected_body.global_position.distance_to(protected_start) < 1,"frozen cargo remains untouched")
	# A player-held object retains control, even if not frozen.
	protected_body.freeze = false
	g.tools.held_body = protected_body
	h.pos = center - Vector2(80,0)
	h.vel = Vector2.ZERO
	for i in 120:
		await physics_frame
		h._fly(center,DT)
	check(protected_body.global_position.distance_to(protected_start) < 1,"player-held cargo is excluded from clearance forces")
	g.tools.held_body = null
	# A long plate's centre is outside the old avoidance radius, but its edge
	# still blocks the grip. This must use actual shape distance.
	center = Vector2(36,-10) * Geom.M
	var long_target = plate(center,0.1,"CLEAR-LONG-TARGET")
	var long_block = plate(center + Vector2(24,150),1.2,"CLEAR-LONG-EDGE",Vector2(8,180))
	var long_start: Vector2 = long_block.global_position
	h.pos = center - Vector2(160,0)
	h.vel = Vector2.ZERO
	h._set_off(long_target)
	for i in 1440:
		await physics_frame
		h._physics_process(DT)
		if h.state == "carry": break
	check(h.state == "carry","pickup beside the edge of a long plate completes")
	check(long_block.global_position.distance_to(long_start) > 1,"long obstacles are pushed using their nearby edge rather than a distant centre")
	h.halt()
	center = Vector2(44,-10) * Geom.M
	var crowded_target = plate(center,0.1,"CLEAR-CROWD-TARGET")
	var crowd: Array = []
	for offset in [Vector2(-28,-26),Vector2(28,-26),Vector2(-28,26),Vector2(28,26)]:
		crowd.append(plate(center + offset,0.3,"CLEAR-CROWD-%d" % crowd.size()))
	h.pos = center - Vector2(160,0)
	h.vel = Vector2.ZERO
	h._set_off(crowded_target)
	for i in 1440:
		await physics_frame
		h._physics_process(DT)
		if h.state == "carry": break
	check(h.state == "carry","a target surrounded by several pieces is still picked up")
	h.halt()
	center = Vector2(50,-10) * Geom.M
	var excluded = plate(center + Vector2(24,0),1,"CLEAR-KEEPOUT")
	var excluded_start: Vector2 = excluded.global_position
	g.keepout = [Rect2(center - Vector2(12,30),Vector2(70,60))]
	h.pos = center - Vector2(80,0)
	h.vel = Vector2.ZERO
	h.state = "reach"
	h.body = null
	for i in 120:
		await physics_frame
		h._fly(center,DT)
	check(excluded.global_position.distance_to(excluded_start) < 1,"keep-out zone debris is not moved by clearance")
	g.keepout.clear()
	h.body = null
	h.state = "idle"
	g.queue_free()
	for i in 4: await process_frame
	print("HAULER CLEARANCE %s (%d failures)" % ["PASS" if failures == 0 else "FAIL",failures])
	quit(0 if failures == 0 else 1)
