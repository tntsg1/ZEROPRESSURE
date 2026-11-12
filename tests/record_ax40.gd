extends "res://tests/record108.gd"
# AX-40 逆火, stage 2 (about 40 s): the chain marked, the wrench at the main switch, the portable
# confinement supply taking over, the bus off, the trap to its cradle; then the other way — the main
# switch first — and the annihilation on the real ship. Captions up top. Own test saves only.
#   tools/run_test.sh tests/record_ax40.gd --write-movie recordings/record_ax40.avi --fixed-fps 30


func _initialize() -> void:
	Career.path = "user://zp_test_recax40_career.json"
	SaveGame.path = "user://zp_test_recax40_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _game() -> void:
	Career.data = Career.fresh()
	Career.data.port = {"power": 2, "salvage": 1, "process": 2, "tug": 1, "trade": 1, "cargo": 1, "ring": 0}
	Career.save()
	Game.contract = {}
	Game.start_ship = "ax40"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 10: await process_frame
	g.job = {"id": "ax40-rec", "ship": "ax40"}
	for i in 40: await process_frame


func _ctrl(id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _park(at: Vector2) -> void:
	g.drone.global_position = at
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()


func _run() -> void:
	Txt.zh = true
	cap_total = 6
	_caption_layer()
	cap_layer.offset = Vector2(0, -760)
	await _game()
	var a = g.anti
	var tr = a.trap
	var tc: Vector2 = g.world.frame(tr) * Geom.centroid(tr.poly)
	var M := Geom.M
	g.cam_override = tc
	g.zoom_override = 1080.0 / (30.0 * M)
	_park(tc + Vector2(-10.0, -1.0) * M)
	_beat(1, "AX-40 逆火 · 反物质储存船", "储存阱只靠主电，整条供电链常显“断电即湮灭”")
	await _secs(3.0)
	# vented and opened up, quickly
	for id in ["G-B", "G-T", "G-E"]:
		g.do_hose(_ctrl(id))
	_beat(2, "先泄压、开舱（加速）", "放气、开门都可以照常做")
	Engine.time_scale = 6.0
	for i in 60 * 40:
		cap_t += 1.0 / FPS
		cap.queue_redraw()
		await process_frame
		if g.sys.P("B") < 5.0 and g.sys.P("T") < 5.0 and g.sys.P("E") < 5.0:
			break
	Engine.time_scale = 1.0
	for id in ["HT-B", "D-0", "HT-E"]:
		g.do_wrench(_ctrl(id))
		await _secs(0.4)
	await _secs(1.0)
	# the wrench at the main switch: the chain lights up
	var km: Vector2 = g.world.ctrl_world(g.world.ctrls["K-M"])
	g.cam_override = (km + tc) * 0.5
	g.zoom_override = 1080.0 / (22.0 * M)
	_park(km + Vector2(-3.0, -2.5) * M)
	g.tools.tool = 2
	_beat(3, "习惯性去拉主闸", "扳手一靠近，整条供电链亮起警示：断电即湮灭")
	for i in int(3.5 * FPS):
		g.bot.aim = km.lerp(km + Vector2(16, -6), clampf(i / 40.0, 0.0, 1.0)) + Vector2(-60, -40) * (1.0 - clampf(i / 40.0, 0.0, 1.0))
		cap_t += 1.0 / FPS
		cap.queue_redraw()
		await process_frame
	# the portable supply on the trap
	g.tools.tool = 1
	g.bot.aim = tc + Vector2(0, -9.0) * M
	g.cam_override = tc
	g.zoom_override = 1080.0 / (13.0 * M)
	_park(tc + Vector2(-4.0, -3.2) * M)
	await _secs(0.6)
	g.do_measure(_ctrl("CONF"))
	g.gear.act({"kind": "place", "type": "confine", "piece": tr, "pos": tc + Vector2(0, -2.2) * M})
	_beat(4, "先接便携约束电源", "接管线圈负载，读数变成“双路供电”")
	await _secs(3.2)
	g.do_measure(_ctrl("CONF"))
	await _secs(1.2)
	# now the bus may go
	g.do_wrench(_ctrl("K-M"))
	_beat(5, "这时才可以断主电", "便携电源接着供电，储存阱仍在约束中")
	await _secs(2.0)
	for j in g.world.joints_of(tr).duplicate():
		if j.type in ["bolt", "lock"]:
			g.do_wrench({"kind": "joint", "joint": j, "pos": g.world.joint_world(j)})
			await _secs(0.15)
	for l in g.world.lines_of(tr).duplicate():
		var end := 0 if l.a == tr.id else 1
		g.do_wrench({"kind": "connector", "line": l, "end": end, "pos": g.world.line_end_world(l, end)})
	await _secs(0.5)
	# craned whole to the cradle (the hook's trip shortened for the video)
	var mouth: Vector2 = Dock.zpos("anti")
	var b = tr.body
	var from: Vector2 = b.global_position
	var to: Vector2 = mouth + Vector2(0, 2.6) * M - b.global_transform.basis_xform(b.center_of_mass)
	_beat(6, "整件吊进反物质回收架", "核心资产 $80,000")
	for i in int(4.0 * FPS):
		var u := Pal.ease_io(clampf(i / (3.2 * FPS), 0.0, 1.0))
		if is_instance_valid(b) and not tr.gone:
			b.global_position = from.lerp(to, u)
			b.linear_velocity = Vector2.ZERO
			b.angular_velocity = 0.0
		g.cam_override = (from.lerp(to, u) + Vector2(0, -1.0) * M)
		g.zoom_override = 1080.0 / (18.0 * M)
		cap_t += 1.0 / FPS
		cap.queue_redraw()
		await process_frame
	for i in int(2.5 * FPS):
		if is_instance_valid(b) and not tr.gone:
			b.global_position = mouth - b.global_transform.basis_xform(b.center_of_mass)
		cap_t += 1.0 / FPS
		cap.queue_redraw()
		await process_frame
	await _secs(1.5)
	g.queue_free()
	for i in 120: await process_frame
	# the other way
	await _game()
	a = g.anti
	tr = a.trap
	tc = g.world.frame(tr) * Geom.centroid(tr.poly)
	g.cam_override = tc
	g.zoom_override = 1080.0 / (22.0 * M)
	cap_total = 7
	_beat(7, "反过来：不接便携电源就拉主闸", "约束一断电，正反物质当场湮灭")
	await _secs(2.0)
	g.do_wrench(_ctrl("K-M"))
	while g.nuke == null:
		await process_frame
	var nk = g.nuke
	while nk.t < 10.0 and not nk.finished:
		cap_t += 1.0 / FPS
		cap.queue_redraw()
		await process_frame
	g.queue_free()
	for i in 120: await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.path))
	quit()
