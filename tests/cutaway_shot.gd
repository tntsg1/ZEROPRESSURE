extends SceneTree
# 工业剖面样片：同一次运行、同一镜头下拍 Pal.solid 关/开，再拍一张开着的切割中。
# Own test saves only.
#   tools/run_test.sh tests/cutaway_shot.gd --fixed-fps 60 -- [ship=gr7] [only=after]
const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_cutaway_career.json"
	SaveGame.path = "user://zp_test_cutaway_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _park(g, at: Vector2) -> void:
	g.drone.global_position = at
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()


func _hold(g, at: Vector2, z: float, drone_at: Vector2, n: int) -> void:
	for i in n:
		g.cam_override = at
		g.zoom_override = z
		g.zoom_now = z
		g.cam_pos = at
		_park(g, drone_at)
		await process_frame


func _set_solid(g, on: bool) -> void:
	Pal.solid = on
	g.world._full_redraw = true
	g.world.queue_redraw()
	for n in g.world.find_children("*", "CanvasItem", true, false):
		n.queue_redraw()


func _run() -> void:
	var sid := "gr7"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ship="):
			sid = a.substr(5)
	Txt.zh = true
	Backdrop.t_fixed = 3.0
	Career.data = Career.fresh()
	Career.data.port = {"power": 2, "salvage": 1, "process": 2, "tug": 1, "trade": 1, "cargo": 1, "ring": 0}
	Career.save()
	Game.contract = {}
	Game.start_ship = sid
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": {"crane": true}}
	root.add_child(g)
	await _frames(10)
	g.job = {"id": "cutaway-shot", "ship": sid}
	await _frames(50)
	g.tutorial = null
	var bb := Rect2()
	var first := true
	for id in g.world.order:
		var p = g.world.pieces[id]
		var b := Geom.bbox(g.world.frame(p) * p.poly)
		bb = b if first else bb.merge(b)
		first = false
	var c := bb.get_center()
	var zw := minf(1920.0 * 0.86 / bb.size.x, 1080.0 * 0.8 / bb.size.y)
	var park := c + Vector2(-bb.size.x * 0.5 - 6.0 * Geom.M, -bb.size.y * 0.5 - 4.0 * Geom.M)
	# whole ship, and the engine end close
	var eng = g.world.tag("p_engc") if g.world.has_method("tag") else null
	var ec: Vector2 = c + Vector2(bb.size.x * 0.3, 0)
	for id in g.world.order:
		var p = g.world.pieces[id]
		if str(p.get("name_key") if "name_key" in p else "") == "p_engc":
			ec = g.world.frame(p) * Geom.centroid(p.poly)
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.art == "eng_core" and p.body == null:
			ec = g.world.frame(p) * Geom.centroid(p.poly)
	# the default zoom (as play starts), the whole ship, and one close look
	var views := [["whole", zw, c], ["near", Game.CAM_ZOOM, ec + Vector2(-8.0, 0.0) * Geom.M], ["close", 1.4, ec + Vector2(-6.0, 0.5) * Geom.M]]
	# clean: no HUD / feed overlay (default keeps the game as it is played)
	if "clean" in OS.get_cmdline_user_args():
		g.hud.visible = false
		if g.look != null and g.look.osd != null:
			g.look.osd.visible = false
	for tag in ["before", "after"]:
		_set_solid(g, tag == "after")
		for v in views:
			await _hold(g, v[2], v[1], park, 30)
			Cap.save(root, "res://tests/out/cutaway_%s_%s_%s.png" % [tag, sid, v[0]])
			var sr: Rect2 = root.get_viewport().get_canvas_transform() * bb
			print("shot %s %s rect %d %d %d %d" % [tag, v[0], sr.position.x, sr.position.y, sr.end.x, sr.end.y])
	if "quick" in OS.get_cmdline_user_args():
		Pal.solid = false
		g.queue_free()
		await _frames(6)
		quit(0)
		return
	# the berth's heavy crane: its rail and trolley
	if g.crane != null:
		var ca: Vector2 = Vector2(g.crane.pos.x, Crane.rail_y() + 2.0 * Geom.M)
		for tag in ["before", "after"]:
			_set_solid(g, tag == "after")
			g.crane.queue_redraw()
			await _hold(g, ca, 1.6, park, 30)
			Cap.save(root, "res://tests/out/cutaway_%s_%s_crane.png" % [tag, sid])
			print("shot crane %s" % tag)
	else:
		print("no crane")
	# cutting a hull plate near the engine, solid on
	var tgt = null
	var best := INF
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.kind == "hull" and p.body == null and not p.gone:
			var pc: Vector2 = g.world.frame(p) * Geom.centroid(p.poly)
			var d := pc.distance_to(ec)
			if d < best:
				best = d
				tgt = p
	if tgt != null:
		var at: Vector2 = g.world.frame(tgt) * Geom.centroid(tgt.poly)
		g.tools.tool = 2
		g.bot.aim = at
		g.bot.lmb = true
		var dp := at + Vector2(-3.0, -3.5) * Geom.M
		await _hold(g, at, 0.62, dp, 50)
		Cap.save(root, "res://tests/out/cutaway_after_%s_cut.png" % sid)
		_set_solid(g, false)
		await _hold(g, at, 0.62, dp, 4)
		Cap.save(root, "res://tests/out/cutaway_before_%s_cut.png" % sid)
		g.bot.lmb = false
		print("shot cut")
	Pal.solid = false
	g.queue_free()
	await _frames(6)
	quit(0)
