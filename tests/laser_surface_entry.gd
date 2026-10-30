extends SceneTree
const Cap = preload("res://tests/cap.gd")
const M := 48.0
var fails := 0
var g: Node
func _initialize() -> void:
	_run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
	if not ok: fails += 1
func remaining(tag: String, at: Vector2) -> bool:
	for p in g.world.pieces_at(at):
		if p.tag == tag or str(p.get_meta("origin","")) == tag: return true
	return false
func hold(at: Vector2, pilot: Vector2) -> void:
	g.bot.lmb = false
	await frames(45)
	g.drone.global_position = pilot
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()
	g.bot.aim = at
	g.bot.lmb = true
	await frames(45)
func _run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "ev55"
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	await frames(10)
	g.tutorial = null
	g.drone.alive = true
	g.drone.spawn_t = 3
	var skin = g.world.tag("HE1-5")
	check(skin != null,"the screenshot's EV-55 upper living-quarter skin is loaded")
	if skin == null:
		quit(1)
		return
	var xf: Transform2D = g.world.frame(skin)
	var aim := xf * (Vector2(31.25,-3.85) * M)
	var pilot := xf * (Vector2(30.85,-5.8) * M)
	# Sample on the incident beam, rather than vertically below the cursor:
	# the operator stands to its left, so the actual cut crosses here.
	var inside := pilot.lerp(aim,(-4.2 + 5.8) / (-3.85 + 5.8))
	g.cam_override = xf * (Vector2(31.1,-4.3) * M)
	g.zoom_override = 2.6
	await frames(10)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		Cap.save(root,"res://proofs/laser_surface_before.png")
	check(remaining("HE1-5",inside),"uncut skin exists in front of the hidden room")
	await hold(aim,pilot)
	print("SURFACE front=%s pending=%d cuts=%d" % [g.tools.front,g.tools.pending.size(),g.tools.stroke_cuts])
	check(not remaining("HE1-5",inside),"holding on the hidden-room boundary pierces the visible ship skin before release")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		Cap.save(root,"res://proofs/laser_surface_after.png")
	var screen_piece = g.world.tag("SCRE-14")
	check(screen_piece != null and not screen_piece.gone and screen_piece.intact,"nearby room equipment is not cut by the boundary fix")
	g.bot.lmb = false
	await frames(45)
	var at := Vector2(24,-11) * M
	var poly := PackedVector2Array([at + Vector2(-35,-12),at + Vector2(35,-12),at + Vector2(35,12),at + Vector2(-35,12)])
	var bar = g.world.add_piece("hull",poly,{"tag":"SURFACE-BAR","density":1.0})
	g.world.add_joint(bar,null,"clamp",at + Vector2(30,0))
	g.world.rebuild_cols(bar)
	await hold(at + Vector2(0,11),at + Vector2(0,-90))
	check(not remaining("SURFACE-BAR",at),"a stationary cursor cuts from the exposed face into a plain plate")
	g.bot.lmb = false
	await frames(45)
	var far := at + Vector2(300,0)
	var far_poly := PackedVector2Array([far + Vector2(-20,-12),far + Vector2(20,-12),far + Vector2(20,12),far + Vector2(-20,12)])
	var far_bar = g.world.add_piece("hull",far_poly,{"tag":"SURFACE-FAR"})
	g.world.add_joint(far_bar,null,"clamp",far + Vector2(15,0))
	g.world.rebuild_cols(far_bar)
	await hold(far,at)
	check(remaining("SURFACE-FAR",far),"a stationary cursor beyond tool range cannot cut distant material")
	g.bot.lmb = false
	g.queue_free()
	await frames(4)
	print("LASER SURFACE %s (%d failures)" % ["PASS" if fails == 0 else "FAIL",fails])
	quit(0 if fails == 0 else 1)
