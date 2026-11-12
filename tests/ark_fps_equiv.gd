extends SceneTree
# ARK-01 帧率专项的等价检查：优化后的查询和原来的全表遍历在同一状态下给出完全相同的结果。
#  1. 激光近设备警告（tools._warn_equipment）：world.pieces_near 选出的 vs 遍历 world.order 选出的
#  2. systems.electric_piece：电缆索引 vs world.lines_of 全表
# 在 ARK-01 上、切下一些件变成散件之后各测数千个点 / 全部设备。Own test saves only.
#   tools/run_test.sh tests/ark_fps_equiv.gd
var g: Node
var fails := 0


func _initialize() -> void:
	Career.path = "user://zp_test_arkeq_career.json"
	SaveGame.path = "user://zp_test_arkeq_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _old_warn(front: Vector2, near: float):
	var best = null
	var bd := near
	for id in g.world.order:
		var q = g.world.pieces[id]
		if q.gone or q.cls != "equip" or not q.intact:
			continue
		# a turning wheel's pieces (scripts/rings.gd) are out of reach where the file put them
		if g.world.turning.has(id):
			continue
		var lp: Vector2 = g.world.frame(q).affine_inverse() * front - g.world.door_offset(q)
		var bb := Geom.bbox(q.poly).grow(near)
		if not bb.has_point(lp):
			continue
		var d := 0.0 if Geometry2D.is_point_in_polygon(lp, q.poly) else Geom.dist_to_boundary(lp, q.poly)
		if d <= bd:
			bd = d
			best = q
	return best


func _new_warn(front: Vector2, near: float):
	var best = null
	var bd := near
	for q in g.world.pieces_near(front, near + 2.0):
		if q.gone or q.cls != "equip" or not q.intact:
			continue
		var lp: Vector2 = g.world.frame(q).affine_inverse() * front - g.world.door_offset(q)
		var bb := Geom.bbox(q.poly).grow(near)
		if not bb.has_point(lp):
			continue
		var d := 0.0 if Geometry2D.is_point_in_polygon(lp, q.poly) else Geom.dist_to_boundary(lp, q.poly)
		if d <= bd:
			bd = d
			best = q
	return best


func _old_electric(p) -> bool:
	var s = g.sys
	if p.cls != "equip":
		return false
	if s.src.has(p.tag) or s.iso.has(p.tag) or p.tag == s.bus_tag:
		return true
	for l in g.world.lines_of(p):
		if l.kind == "cable":
			return true
	return false


func _compare(tag: String) -> void:
	var w = g.world
	var sb := Rect2()
	var f0 := true
	var eq: Array = []
	for id in w.order:
		var p = w.pieces[id]
		if p.gone:
			continue
		var b: Rect2 = Geom.bbox(w.world_poly(p))
		sb = b if f0 else sb.merge(b)
		f0 = false
		if p.cls == "equip":
			eq.append(p)
	var n := 0
	var bad := 0
	var hits := 0
	# random points over the ship, and points right at equipment edges / centres
	var pts: Array = []
	for i in 3000:
		pts.append(Vector2(randf_range(sb.position.x, sb.end.x), randf_range(sb.position.y, sb.end.y)))
	for p in eq.slice(0, 800):
		var wp: PackedVector2Array = w.world_poly(p)
		pts.append(Geom.centroid(wp))
		pts.append(wp[0] + Vector2(randf_range(-30, 30), randf_range(-30, 30)))
	for near in [36.0, 54.0]:
		for pt in pts:
			var a = _old_warn(pt, near)
			var b = _new_warn(pt, near)
			n += 1
			if a != null:
				hits += 1
			if a != b:
				bad += 1
	print("[%s] %s warn: %d queries, %d near equipment, %d differ" % ["PASS" if bad == 0 else "FAIL", tag, n, hits, bad])
	if bad > 0:
		fails += 1
	var eb := 0
	var et := 0
	for id in w.order:
		var p = w.pieces[id]
		if p.gone:
			continue
		if _old_electric(p) != g.sys.electric_piece(p):
			eb += 1
		if _old_electric(p):
			et += 1
	print("[%s] %s electric_piece: %d pieces, %d electric, %d differ" % ["PASS" if eb == 0 else "FAIL", tag, w.order.size(), et, eb])
	if eb > 0:
		fails += 1


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.save()
	SaveGame.clear()
	Game.contract = {}
	Game.start_ship = "ark01"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": {"crane": true}}
	root.add_child(g)
	for i in 40:
		await process_frame
	g.tutorial = null
	_compare("intact")
	# knock a few dozen pieces loose (their joints and cables gone), cut a few cables
	var n := 0
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.cls == "equip" and not p.gone and p.body == null and n < 40 and randf() < 0.1:
			for j in g.world.joints_of(p):
				g.world.kill_joint(j)
			n += 1
	var k := 0
	for lid in g.world.lines:
		var l = g.world.lines[lid]
		if l.alive and l.kind == "cable" and randf() < 0.15:
			g.world.kill_line(l)
			k += 1
	for i in 60:
		await process_frame
	print("  loosened %d, bodies now %d, cables cut %d" % [n, g.world.bodies.size(), k])
	_compare("after loosening")
	SaveGame.clear()
	print("ARK FPS EQUIV %s" % ("PASS" if fails == 0 else "FAIL"))
	quit(1 if fails > 0 else 0)
