extends SceneTree
# ARK-01 帧率专项：近景 / 全景 / 切割中 / 读档后 / 250 散件，每帧记墙钟帧时间、process、
# 单次物理步、渲染 CPU、本帧物理步数；toggle 时逐个关掉节点的 process / physics，
# 再关物理服务器，量各自省下的毫秒。Own test saves only.
#   tools/run_test.sh tests/ark_fps_probe.gd -- scene=near [toggle] [frames=120]
var g: Node
var ticks := 0


func _initialize() -> void:
	Career.path = "user://zp_test_arkfps_career.json"
	SaveGame.path = "user://zp_test_arkfps_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	physics_frame.connect(func(): ticks += 1)
	_run.call_deferred()


func _pct(a: Array, q: float) -> float:
	var s := a.duplicate()
	s.sort()
	return s[clampi(int(s.size() * q), 0, s.size() - 1)]


func _mean(a: Array) -> float:
	var m := 0.0
	for x in a:
		m += x
	return m / maxf(a.size(), 1)


var vis := false
var ab := 0
var ab_hz := false
var ship := "ark01"
var passes := false
var items_exp := false
var vis_depth := 1
var park_at = null
var park_cam = null
var park_z := -1.0


func _park() -> void:
	if park_at != null:
		g.drone.global_position = park_at
		g.drone.linear_velocity = Vector2.ZERO
	if park_cam != null:
		g.cam_override = park_cam
		g.zoom_override = park_z


func _measure(n: int) -> Dictionary:
	var vp := root.get_viewport_rid()
	var d := {"frame": [], "proc": [], "phys": [], "cpu": [], "ticks": []}
	Prof.reset()
	World.prof.clear()
	for i in n:
		_park()
		var t0 := ticks
		var t1 := Time.get_ticks_usec()
		await process_frame
		d.frame.append((Time.get_ticks_usec() - t1) / 1000.0)
		d.proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		d.phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		d.cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
		d.ticks.append(ticks - t0)
		Prof.roll()
	d.prof = Prof.sum.duplicate()
	d.wprof = World.prof.duplicate()
	d.peak = Prof.peak.duplicate()
	return d


func _line(tag: String, d: Dictionary) -> String:
	return "%s vs%d frame p50 %.2f min %.2f mean %.2f p95 %.2f p99 %.2f | proc mean %.2f p95 %.2f | phys/tick mean %.2f | ticks %.2f | rcpu %.2f" % [
		tag, DisplayServer.window_get_vsync_mode(), _pct(d.frame, 0.5), _pct(d.frame, 0.0), _mean(d.frame), _pct(d.frame, 0.95), _pct(d.frame, 0.99), _mean(d.proc), _pct(d.proc, 0.95),
		_mean(d.phys), _mean(d.ticks), _mean(d.cpu)]


func _game(ship: String, kit: Dictionary) -> Node:
	Game.contract = {}
	Game.start_ship = ship
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": kit}
	root.add_child(scene)
	for i in 10:
		await process_frame
	scene.tutorial = null
	return scene


func _all(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_all(c, out)


func _run() -> void:
	var scen := "near"
	var frames := 120
	var toggle := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ship="):
			ship = a.substr(5)
		if a == "hz":
			ab_hz = true
		if a.begins_with("ab="):
			ab = int(a.substr(3))
		if a == "items":
			items_exp = true
		if a == "passes":
			passes = true
		if a == "vis":
			vis = true
		elif a.begins_with("vis="):
			vis = true
			vis_depth = int(a.substr(4))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("scene="):
			scen = a.substr(6)
		elif a.begins_with("frames="):
			frames = int(a.substr(7))
		elif a == "toggle":
			toggle = true
		elif a == "novsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.port = {"power": 2, "salvage": 1, "process": 2, "tug": 1, "trade": 1, "cargo": 1, "ring": 0}
	Career.save()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	if scen == "stress":
		await _stress(frames, toggle)
	else:
		await _ark(scen, frames, toggle)
	SaveGame.clear()
	quit(0)


func _ark(scen: String, frames: int, toggle: bool) -> void:
	SaveGame.clear()
	g = await _game(ship, {"crane": true})
	g.job = {"id": "ark-fps", "ship": ship}
	if scen == "load":
		for i in 30:
			await process_frame
		SaveGame.save(g)
		g.queue_free()
		await process_frame
		await process_frame
		SaveGame.load_requested = true
		g = await _game(ship, {"crane": true})
	for i in 90:
		await process_frame
	var tgt = null
	var big := 0.0
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.kind == "hull" and p.body == null and not p.gone:
			var ar := Geom.area(p.poly)
			if ar > big:
				big = ar
				tgt = p
	var at: Vector2 = Geom.centroid(tgt.poly)
	park_at = at + Vector2(-3.0, -3.5) * Geom.M
	park_cam = at
	park_z = Game.CAM_ZOOM
	if scen == "whole":
		var sb := Rect2()
		var f0 := true
		for id in g.world.order:
			var b := Geom.bbox(g.world.pieces[id].poly)
			sb = b if f0 else sb.merge(b)
			f0 = false
		park_cam = sb.get_center()
		park_z = minf(1920.0 * 0.86 / sb.size.x, 1080.0 * 0.8 / sb.size.y)
	g.tools.tool = 2
	g.bot.aim = at
	g.bot.lmb = scen == "cut"
	for i in 30:
		_park()
		await process_frame
	await _report(scen, frames, toggle)
	g.bot.lmb = false


func _stress(frames: int, toggle: bool) -> void:
	g = await _game("tug", {"skill_grapple_multi": 3})
	for i in 30:
		await process_frame
	var mats := ["steel", "al", "ti", "ceramic", "composite"]
	var c := Vector2(43.0 * Geom.M, -7.0 * Geom.M)
	for i in 250:
		var at := c + Vector2((i % 25) * 0.85 * Geom.M - 10.6 * Geom.M, (i / 25) * 1.0 * Geom.M - 5.0 * Geom.M)
		var h := Vector2(14, 10)
		var poly := PackedVector2Array([at - h, at + Vector2(h.x, -h.y), at + h, at + Vector2(-h.x, h.y)])
		g.world.add_piece("plate", poly, {"mat": mats[i % 5], "mass": 0.2})
	g.world.dirty_links = true
	for i in 240:
		await process_frame
	g.tools.tool = 3
	g.tools.toggle_multi(false)
	g.drone.global_position = c + Vector2(0, 7.0 * Geom.M)
	g.bot.aim = c + Vector2(0, -1.0 * Geom.M)
	g.bot.lmb = true
	await process_frame
	await process_frame
	await process_frame
	for i in 30:
		var a := c + Vector2(i * 0.8 * Geom.M - 12.0 * Geom.M, 9.0 * Geom.M)
		g.world.rope_fx.snap(PackedVector2Array([a, a + Vector2(0, 3.0 * Geom.M), a + Vector2(0, 6.0 * Geom.M)]), a + Vector2(0, 3.0 * Geom.M), 0.8)
	print("STRESS bodies %d held %d" % [g.world.bodies.size(), g.tools.multi.held.size()])
	await _report("stress", frames, toggle)


func _report(scen: String, frames: int, toggle: bool) -> void:
	if ab > 0:
		await _ab(scen, frames)
		return
	var d := await _measure(frames)
	print(_line("BASE %s" % scen, d))
	print("PHYS2D active %d pairs %d islands %d | bodies %d joints %d pieces %d" % [
		Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS), Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS),
		Performance.get_monitor(Performance.PHYSICS_2D_ISLAND_COUNT), g.world.bodies.size(), g.world.joints.size(), g.world.pieces.size()])
	var keys: Array = d.prof.keys()
	keys.sort_custom(func(a, b): return d.prof[a] > d.prof[b])
	var tot := 0.0
	for k in keys:
		tot += d.prof[k] / 1000.0 / frames
	print("FUNC (nested sums overlap) top-level sum %.2f ms/frame" % tot)
	for k in keys.slice(0, 45):
		print("FUNC %7.3f ms/frame  peak %6.2f  %s" % [d.prof[k] / 1000.0 / frames, d.peak[k] / 1000.0, k])
	var wk: Array = d.wprof.keys()
	wk.sort_custom(func(a, b): return d.wprof[a] > d.wprof[b])
	for k in wk.slice(0, 12):
		print("WPROF %7.3f ms/frame (max-keys are one worst call)  %s" % [d.wprof[k] / 1000.0 / frames, k])
	print("OBJ nodes %d draw calls %d" % [Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	if vis:
		await _vis(_mean(d.cpu), _mean(d.frame))
	if passes:
		await _passes(_mean(d.cpu))
	if items_exp:
		await _items_exp()
	if not toggle:
		return
	var base := _mean(d.frame)
	var base_proc := _mean(d.proc)
	var base_phys := _mean(d.phys)
	# the physics server's step alone
	PhysicsServer2D.set_active(false)
	await process_frame
	var dp := await _measure(60)
	PhysicsServer2D.set_active(true)
	print("TOGGLE physics server off: frame %.2f (saves %.2f) phys/tick %.2f (saves %.2f)" % [_mean(dp.frame), base - _mean(dp.frame), _mean(dp.phys), base_phys - _mean(dp.phys)])
	var nodes := []
	_all(g, nodes)
	var rows := []
	for nd in nodes:
		var pp: bool = nd.is_physics_processing()
		var p: bool = nd.is_processing()
		if not pp and not p:
			continue
		for half in ["process", "physics"]:
			if half == "process" and not p:
				continue
			if half == "physics" and not pp:
				continue
			if half == "process":
				nd.set_process(false)
			else:
				nd.set_physics_process(false)
			await process_frame
			var dd := await _measure(30)
			nd.set_process(p)
			nd.set_physics_process(pp)
			var sv := (base_proc - _mean(dd.proc)) if half == "process" else (base_phys - _mean(dd.phys))
			rows.append([sv, half, str(g.get_path_to(nd)), nd.get_script().resource_path.get_file() if nd.get_script() else nd.get_class()])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows.slice(0, 25):
		print("TOGGLE %6.2f ms  %s  %s  (%s)" % r)
	print("TOGGLE nodes processing: %d" % rows.size())


# render CPU by drawing: each visible canvas item (two levels down the scene, and the
# world's layers) hidden in turn
func _vis(base_cpu: float, base_frame: float) -> void:
	var items := []
	var stack := [[g, 0]]
	while not stack.is_empty():
		var e = stack.pop_back()
		var n: Node = e[0]
		for c in n.get_children():
			if c is CanvasItem and c.visible:
				items.append(c)
			if e[1] < vis_depth and (c is CanvasItem or c is CanvasLayer or c is Node):
				stack.append([c, e[1] + 1])
	print("VIS items %d" % items.size())
	items = items.filter(func(it): return not (it is CollisionShape2D) and not (it is RigidBody2D and it != g.drone) and not (it is StaticBody2D))
	items = items.slice(0, 160)
	var rows := []
	for it in items:
		it.visible = false
		await process_frame
		var dd := await _measure(20)
		it.visible = true
		rows.append([base_cpu - _mean(dd.cpu), base_frame - _mean(dd.frame), str(g.get_path_to(it)), it.get_script().resource_path.get_file() if it.get_script() else it.get_class(), it.get_child_count()])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows.slice(0, 40):
		print("VIS rcpu -%5.2f frame -%6.2f  %s (%s, %d children)" % r)


func _passes(base_cpu: float) -> void:
	var groups := []
	for k in g.world._pass_roots:
		groups.append(["world pass " + str(k), [g.world._pass_roots[k]]])
	for c in g.world.get_children():
		if c is CanvasItem and c.visible and not (c in g.world._pass_roots.values()) and not (c is StaticBody2D):
			groups.append(["world child %s (%s, %d ch)" % [c.name, c.get_script().resource_path.get_file() if c.get_script() else c.get_class(), c.get_child_count()], [c]])
	for c in g.dock.get_children():
		if c is CanvasItem and c.visible:
			groups.append(["dock child %s (%s, %d ch)" % [c.name, c.get_script().resource_path.get_file() if c.get_script() else c.get_class(), c.get_child_count()], [c]])
	var rows := []
	for gr in groups:
		var on1 := _mean((await _measure(24)).cpu)
		for it in gr[1]:
			it.visible = false
		await process_frame
		var off := _mean((await _measure(24)).cpu)
		for it in gr[1]:
			it.visible = true
		await process_frame
		var on2 := _mean((await _measure(24)).cpu)
		rows.append([(on1 + on2) * 0.5 - off, gr[0]])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows:
		print("PASS rcpu saves %5.2f  %s" % r)


# before / after in turn, the same scene and camera, ab rounds of each (World.ark_old)
func _ab(scen: String, frames: int) -> void:
	var res := {true: {"frame": [], "proc": [], "cpu": [], "ticks": []}, false: {"frame": [], "proc": [], "cpu": [], "ticks": []}}
	for round in ab * 2:
		var old := round % 2 == 0
		if ab_hz:
			Look.TICKS = 120 if old else 60
			Look.time_k(1.0)
		else:
			World.ark_old = old
		for i in 20:
			_park()
			await process_frame
		var d := await _measure(frames)
		for k in ["frame", "proc", "cpu", "ticks"]:
			res[old][k].append_array(d[k])
	World.ark_old = false
	Look.TICKS = int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 120))
	Look.time_k(1.0)
	for old in [true, false]:
		var d: Dictionary = res[old]
		var lows: Array = d.frame.duplicate()
		lows.sort()
		var n1 := maxi(1, lows.size() / 100)
		var worst := 0.0
		for i in n1:
			worst += lows[lows.size() - 1 - i]
		worst /= n1
		print("AB %s %s vs%d  mean %.2f  p50 %.2f  p95 %.2f  p99 %.2f  1%%low(fps) %.1f  ticks %.2f  rcpu %.2f  n %d" % [scen, ("120Hz " if old else "60Hz  ") if ab_hz else ("BEFORE" if old else "AFTER "), DisplayServer.window_get_vsync_mode(),
			_mean(d.frame), _pct(d.frame, 0.5), _pct(d.frame, 0.95), _pct(d.frame, 0.99), 1000.0 / worst, _mean(d.ticks), _mean(d.cpu), d.frame.size()])


func _cpu(n: int) -> float:
	return _mean((await _measure(n)).cpu)


# render CPU against the number of canvas items: empty ones, then ones with a little drawing; and the
# strips' passes each hidden alone vs all at once
func _items_exp() -> void:
	var holder := Node2D.new()
	g.world.add_child(holder)
	var b0 := await _cpu(40)
	for i in 1000:
		var n := Node2D.new()
		n.position = Vector2(randf() * 30000.0, randf() * 3000.0 - 1500.0)
		holder.add_child(n)
	await process_frame
	var b1 := await _cpu(40)
	for c in holder.get_children():
		c.draw.connect(func(): c.draw_rect(Rect2(0, 0, 40, 40), Color(1, 1, 1, 0.02)))
		c.queue_redraw()
	await process_frame
	var b2 := await _cpu(40)
	holder.queue_free()
	await process_frame
	var b3 := await _cpu(40)
	print("ITEMS base %.2f | +1000 empty %.2f | +1000 one-rect %.2f | removed %.2f" % [b0, b1, b2, b3])
	var pl: Node2D = g.world.piece_layer
	var vis_roots := []
	for k in g.world._pass_roots:
		var r: Node2D = g.world._pass_roots[k]
		print("ITEMS pass %s visible %s children %d" % [k, r.visible, r.get_child_count()])
		if r.visible:
			vis_roots.append(r)
	var on1 := await _cpu(40)
	for r in vis_roots:
		r.visible = false
	await process_frame
	var off := await _cpu(40)
	for r in vis_roots:
		r.visible = true
	pl.visible = false
	await process_frame
	var offp := await _cpu(40)
	pl.visible = true
	await process_frame
	var on2 := await _cpu(40)
	print("ITEMS strips on %.2f/%.2f | visible passes hidden %.2f | piece_layer hidden %.2f | piece_layer children %d" % [on1, on2, off, offp, pl.get_child_count()])
