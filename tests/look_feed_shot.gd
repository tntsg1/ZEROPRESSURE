extends SceneTree
# 91 号 遥控与沉浸样片：出舱 → 飞向 M-14 → 头灯照进黑暗 → 贴近船体（信号变差）→ 切割
#   tools/run_test.sh tests/look_feed_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_lookfeed_career.json"
	SaveGame.path = "user://zp_test_lookfeed_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func deg2rad_safe(x: float) -> float:
	return x * PI / 180.0


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "m14"
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "gauge": true}
	root.add_child(g)
	await _frames(40)
	g.tutorial = null
	var fails := 0
	var d = g.drone
	# 1: just out of the bay, looking toward the ship
	d.global_position = Dock.BAY * Geom.M + Vector2(3.0 * Geom.M, 1.0 * Geom.M)
	d.reset_physics_interpolation()
	g.bot.aim = d.global_position + Vector2(8.0 * Geom.M, 2.0 * Geom.M)
	await _frames(40)
	g.bot.move = Vector2(1, 0.25)
	await _frames(24)
	Cap.save(root, "res://tests/out/look_feed_0_out.png")
	print("ride offset while accelerating: ", g.look.cam_offset.snapped(Vector2(0.1, 0.1)))
	if g.look.cam_offset.length() < 2.0:
		print("FAIL the camera doesn't ride the drone's start")
		fails += 1
	# 2: across to the ship, the lamp on the hull
	await _frames(60)
	g.bot.move = Vector2.ZERO
	g.bot.brake = true
	await _frames(30)
	g.bot.brake = false
	var hull = g.world.tag("ARMOR-U")
	var hc: Vector2 = g.world.frame(hull) * Geom.centroid(hull.poly)
	d.global_position = hc + Vector2(-3.0 * Geom.M, -1.5 * Geom.M)
	d.linear_velocity = Vector2.ZERO
	d.reset_physics_interpolation()
	g.bot.aim = hc + Vector2(6.0 * Geom.M, 3.0 * Geom.M)
	await _frames(50)
	Cap.save(root, "res://tests/out/look_feed_1_lamp.png")
	# 3: into a room of the ship — the link through the plating breaks up
	var room_at := Vector2.INF
	for n in g.world.rooms:
		var r = g.world.rooms[n]
		room_at = Geom.centroid(r.poly)
		break
	if room_at != Vector2.INF:
		d.global_position = room_at
		d.reset_physics_interpolation()
		g.bot.aim = room_at + Vector2(5.0 * Geom.M, 0)
		# user 2026-10-28 ("一进到内部屏幕就不停地闪…闪一两下就够了"): the picture tears as the link
		# drops, briefly, then holds steady however long the drone stays inside
		var torn := 0
		var late := 0
		for f in 240:
			await process_frame
			if float(g.look.post_mat.get_shader_parameter("interference")) > 0.0:
				torn += 1
				if f >= 60:
					late += 1
			if f == 39:
				Cap.save(root, "res://tests/out/look_feed_2_inside.png")
		print("signal inside: %.2f · torn %d frames of 240, %d after the first second" % [g.look.signal_k, torn, late])
		if g.look.signal_k > 0.6:
			print("FAIL the plating doesn't cut the link")
			fails += 1
		if torn == 0 or torn > 24 or late > 0:
			print("FAIL into the hull: a glitch or two, then a steady picture")
			fails += 1
	# 4: the beam into the plate
	d.global_position = hc + Vector2(-1.0 * Geom.M, -4.0 * Geom.M)
	d.reset_physics_interpolation()
	g.tools.tool = 2
	g.bot.aim = hc + Vector2(-1.0 * Geom.M, 1.0 * Geom.M)
	g.bot.lmb = true
	await _frames(50)
	g.bot.gauge_at = g.get_viewport().get_canvas_transform() * g.bot.aim
	await _frames(10)
	Cap.save(root, "res://tests/out/look_feed_3_cut.png")
	g.bot.lmb = false
	# 5: the pointer over the link and over the unit's panel
	Look.test_mouse = Vector2(960, 34)
	await _frames(30)
	Cap.save(root, "res://tests/out/look_feed_4_link.png")
	Look.test_mouse = Vector2(200, 1010)
	await _frames(30)
	Cap.save(root, "res://tests/out/look_feed_5_unit.png")
	Look.test_mouse = Vector2.INF
	# 6: a zoom: the lens loses focus and hunts back
	g.zoom_target = g.zoom_target * 0.55
	await _frames(6)
	Cap.save(root, "res://tests/out/look_feed_6_zoom.png")
	print("focus while zooming: %.2f" % g.look.focus)
	if absf(g.look.focus) < 0.1:
		print("FAIL no focus breathing on a zoom")
		fails += 1
	# 7: the lamp swings round, not at once
	var a0: float = g.look.beam_ang
	g.bot.aim = d.global_position + (d.global_position - g.bot.aim)
	await _frames(3)
	var turned: float = absf(wrapf(g.look.beam_ang - a0, -PI, PI))
	print("lamp turned %.0f° in 3 frames" % rad_to_deg(turned))
	if turned > deg2rad_safe(80.0):
		print("FAIL the lamp snaps round")
		fails += 1
	print("feed_shot: %d fails" % fails)
	quit(fails)
