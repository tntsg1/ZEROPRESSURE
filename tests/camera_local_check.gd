extends SceneTree
# A wheel pullback over ARK-01 must show the surrounding structure before it
# frames the whole ship. Exercise the real wheel handler and camera integrator.
const Cap = preload("res://tests/cap.gd")
var fails := 0
var g: Game

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, what: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])
	if not ok: fails += 1

func wheel(outward: bool, count: int = 1) -> void:
	for i in count:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_DOWN if outward else MOUSE_BUTTON_WHEEL_UP
		ev.pressed = true
		g._unhandled_input(ev)

func step(n: int) -> void:
	for i in n: g._camera(1.0 / 60.0)

func place(at: Vector2) -> void:
	g.drone.global_position = at
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()
	g.aim = at
	g.cam_pos = at
	g.cam_vel = Vector2.ZERO
	g.cam_pan = Vector2.ZERO
	g.zoom_now = Game.CAM_ZOOM
	g.zoom_target = Game.CAM_ZOOM
	g.cam_override = null
	g.zoom_override = -1.0
	g.overview = false
	g.trauma = 0.0
	g.punch = Vector2.ZERO
	g.rmb_down = false
	step(1)

func drone_visible() -> bool:
	var half := root.get_visible_rect().size * 0.5 / g.zoom_now
	return Rect2(g.cam_pos - half, half * 2).has_point(g.drone.global_position)

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	g.cam.force_update_scroll()
	g.world.queue_redraw()
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	Cap.save(root, "res://proofs/" + name + ".png")

func _run() -> void:
	Career.path = "user://zp_test_camera_local_career.json"
	SaveGame.path = "user://zp_test_camera_local_save.json"
	Txt.cfg_path = "user://zp_test_camera_local_settings.cfg"
	SaveGame.allow_test = true
	Txt.dev = false
	Game.start_ship = "ark01"
	Game.contract = {}
	root.add_child(preload("res://tests/test_window.gd").new())
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 6: await process_frame
	g.process_mode = Node.PROCESS_MODE_DISABLED
	g.cam.process_mode = Node.PROCESS_MODE_ALWAYS
	g.cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# This is a camera test: avoid collision resolution moving a manually placed
	# drone during screenshot frames (disabling callbacks does not freeze a body).
	g.drone.freeze = true
	g.state = "play"
	for room in g.world.rooms: g.world.reveal(room, g.world.rooms[room].bbox.get_center())
	var fit := g.zoom_min()
	var enter := fit * pow(Game.ZOOM_STEP, Game.OVERVIEW_ZOOM_STEPS)
	for metres in [Vector2(15, 0), Vector2(270, 0), Vector2(590, 0)]:
		var at: Vector2 = metres * Geom.M
		place(at)
		var local := true
		for i in 18:
			wheel(true)
			step(20)
			local = local and g.cam_pos.distance_to(at) < 0.1 and drone_visible()
		check(local and g.zoom_target > enter, "%s m: 18 wheel steps keep the surrounding structure centred locally" % metres)
		check(g.zoom_now < 0.4 and g.zoom_now > fit * 3.0, "local pullback widens the view without jumping to whole-ship scale")
		if metres.x == 15: await shot("camera_ark_local_bow")
		if metres.x == 590: await shot("camera_ark_local_stern")
		# Burst straight to the zoom limit: position must wait for visible zoom.
		wheel(true, 80)
		check(is_equal_approx(g.zoom_target, fit), "the wheel still reaches whole-ship fit")
		var premature_shift := false
		var lost := false
		for i in 360:
			var still_local := g.zoom_now >= enter
			step(1)
			if still_local and g.cam_pos.distance_to(at) > 0.1: premature_shift = true
			if not drone_visible(): lost = true
		check(not premature_shift, "a fast wheel burst waits until the last three visible zoom steps before recentering")
		check(not lost, "the drone stays in frame throughout local-to-whole transition")
		var half := root.get_visible_rect().size * 0.5 / g.zoom_now
		# Quarter-pixel allowance for the asymptotic spring/zoom convergence.
		check(Rect2(g.cam_pos - half, half * 2).grow(0.25 / g.zoom_now).encloses(g.focus_rect()), "the final view contains the complete ship and margin")
		wheel(false, 18)
		var lost_on_return := false
		for i in 360:
			step(1)
			if not drone_visible(): lost_on_return = true
		check(not lost_on_return, "a fast zoom-in keeps the local area visible while the camera returns")
		check(g.cam_pos.distance_to(at) < 0.1 and drone_visible(), "zooming back in restores the same local area")
	# Existing manual pan remains useful when inspecting a local structure.
	place(Vector2(270, 0) * Geom.M)
	g.cam_pan = Vector2(15, 3) * Geom.M
	g.rmb_down = true
	g.rmb_moved = 20.0
	wheel(true, 14)
	step(360)
	check(g.cam_pos.distance_to(g.drone.global_position + g.cam_pan) < 0.1, "local wheel zoom preserves a held right-drag pan")
	g.rmb_down = false
	step(360)
	check(g.cam_pos.distance_to(g.drone.global_position) < 0.1, "released pan still drifts back locally")
	# Z is a deliberate temporary whole-ship view, independent of wheel position.
	var local_zoom := g.zoom_target
	g.overview = true
	step(360)
	check(g.cam_pos.distance_to(g.focus_rect().get_center()) < 0.1 and is_equal_approx(g.zoom_now, fit), "held overview still frames the whole colony ship")
	await shot("camera_ark_whole")
	g.overview = false
	step(360)
	check(is_equal_approx(g.zoom_target, local_zoom) and g.cam_pos.distance_to(g.drone.global_position) < 0.1, "leaving overview restores the local wheel framing")
	g.queue_free()
	for i in 3: await process_frame
	print("LOCAL CAMERA %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(0 if fails == 0 else 1)
