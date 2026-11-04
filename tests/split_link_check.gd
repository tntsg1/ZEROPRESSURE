extends SceneTree
# 2026-11-04 拆船“看起来分开、其实连着”：电缆/管线不再像焊缝一样把件钉在一起。
# JD-38 斑鸠级上按固定种子随机下激光切口，每轮查：
#   A 散落刚体里没有只靠电缆相连的几块（一个刚体 = 一组焊缝/螺栓连着的件）
#   B 还挂在船上的件要么由固定件连到船上，要么只靠电缆但仍贴着船上的结构（还坐在安装位）
#   C 两个散件之间的电缆是松弛的系绳，拉过长度会从接头处扯断
# 旧规则（World.legacy_lines）下同样的切法必须查出问题，证明复现成立。
# 截图（非 headless）：tests/out/split_link_before.png / split_link_after.png
#   tools/run_test.sh tests/split_link_check.gd --fixed-fps 60 -- [ship=jd38] [rounds=40] [seeds=1,2,3]
# Own test saves only.

const Cap = preload("res://tests/cap.gd")
var fails := 0


func _initialize() -> void:
	Career.path = "user://zp_test_split_career.json"
	SaveGame.path = "user://zp_test_split_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _load(ship: String):
	Career.data = Career.fresh()
	Career.save()
	Game.contract = {}
	Game.start_ship = ship
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(60)
	g.tutorial = null
	return g


func _run() -> void:
	var ship := "jd38"
	var rounds := 40
	var seeds := [1, 2, 3]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ship="): ship = a.substr(5)
		elif a.begins_with("rounds="): rounds = int(a.substr(7))
		elif a.begins_with("seeds="): seeds = Array(a.substr(6).split(",")).map(func(x): return int(x))
	Txt.zh = true
	var legacy_bad := 0
	var new_bad := 0
	var tethers_seen := 0
	for legacy in [true, false]:
		World.legacy_lines = legacy
		for sd in seeds:
			var g = await _load(ship)
			var w = g.world
			var rng := RandomNumberGenerator.new()
			rng.seed = sd
			var bb := _bbox(w)
			for r in rounds:
				var a := bb.position + Vector2(rng.randf(), rng.randf()) * bb.size
				var b := a + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.0, 9.0) * Geom.M
				_cut(w, a, b)
				w.relink()
				await _frames(2)
				var d := diag(w)
				var n: int = d.body.size() + d.hanging.size()
				if legacy:
					legacy_bad += n
				else:
					new_bad += n
					tethers_seen = maxi(tethers_seen, w.tethers.size())
					for s in d.body + d.hanging:
						print("   seed %d round %d: %s" % [sd, r, s])
			if not legacy and sd == seeds[0]:
				await _tether_snap(g)
			g.queue_free()
			await _frames(4)
	for legacy in [true, false]:
		World.legacy_lines = legacy
		await _focus_shot(ship, legacy)
	World.legacy_lines = false
	print("legacy rule: %d cable-only links over the runs; new rule: %d; most tethers at once %d" % [legacy_bad, new_bad, tethers_seen])
	_check(legacy_bad > 0, "旧规则下复现：只靠电缆的悬空件/一体刚体（%d 次）" % legacy_bad)
	_check(new_bad == 0, "新规则：散落刚体只按固定件分组，悬空件不再被电缆钉住（%d 次）" % new_bad)
	await _bracket_check(ship)
	print("SPLIT_LINK %s" % ("OK" if fails == 0 else "FAILED %d" % fails))
	quit(1 if fails > 0 else 0)


# the same scene under both rules: JD-38's avionics rack AV with its fixings undone, its power
# cable still in; it was bolted 0.2 m off bulkhead B1-T, so it sits against nothing
func _focus_shot(ship: String, legacy: bool) -> void:
	if ship != "jd38":
		return
	var g = await _load(ship)
	var w = g.world
	for n in w.rooms.keys():
		w.reveal(n, Geom.centroid(w.rooms[n].poly))
	await _frames(60)
	var av = w.tag("AV")
	# a kerf all round it, just outside its edge (what a player cutting it out does), then its bolts
	var r := Geom.bbox(av.poly).grow(5.0)
	var loop := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
	for id in w.order.duplicate():
		var q = w.pieces.get(id)
		if q != null and not q.gone and q != av and q.body == null and Geom.bbox(q.poly).intersects(r.grow(6.0)):
			w.commit_cut(q, loop)
	for j in w.joints_of(av):
		w.kill_joint(j)
	w.relink()
	await _frames(2)
	var at: Vector2 = w.frame(av) * Geom.centroid(av.poly)
	if legacy:
		_check(av.body == null, "旧规则：AV 螺栓全拆、只剩电源线，仍钉在原处")
	else:
		_check(av.body != null, "新规则：AV 螺栓全拆、四周不贴结构，脱离成自由件")
		_check(w.tethers.any(func(l): return l.a == av.id or l.b == av.id), "新规则：AV 的电源线成了画得出的系绳")
		# drift it off a little, as a nudge would
		av.body.linear_velocity = Vector2(-40.0, 25.0)
		for l in w.tethers:
			print("   tether ", l.id, " ", (w.line_end_world(l, 0) / Geom.M).snapped(Vector2(0.1, 0.1)), " -> ", (w.line_end_world(l, 1) / Geom.M).snapped(Vector2(0.1, 0.1)), " rest %.1f m" % (float(l.get_meta("rest")) / Geom.M))
	g.zoom_target = 1.6
	for i in 70:
		g.drone.global_position = at + Vector2(-5.0, -2.5) * Geom.M
		g.drone.linear_velocity = Vector2.ZERO
		await process_frame
	if not legacy and av.body != null:
		var mine: Array = w.lines.values().filter(func(l): return l.a == av.id or l.b == av.id)
		_check(not mine.is_empty() and mine.all(func(l): return l.alive), "轻推后 AV 的 %d 根电源线都没被扯断（绷直后挡住，不会自己断）" % mine.size())
	Cap.save(root, "res://tests/out/split_link_%s.png" % ("before" if legacy else "after"))
	g.queue_free()
	await _frames(4)


# C: a tether pulled past its length tears out at a plug
func _tether_snap(g) -> void:
	var w = g.world
	if w.tethers.is_empty():
		# make one: cut a powered device's fixings and the structure round it free
		_check(false, "切到最后应有至少一根两散件之间的系绳")
		return
	var l = w.tethers[0]
	var pa = w.pieces[l.a]
	var pb = w.pieces[l.b]
	var mover = pa.body if pa.body != null else pb.body
	var snapped := []
	w.tether_snapped.connect(func(line, _p, _at): snapped.append(line))
	var rest: float = l.get_meta("rest")
	var d0: float = w.line_end_world(l, 0).distance_to(w.line_end_world(l, 1))
	_check(d0 <= rest + w.TETHER_GIVE, "系绳刚生成时没拉紧（%.1f / %.1f m）" % [d0 / Geom.M, rest / Geom.M])
	var path: PackedVector2Array = w.tether_path(l)
	_check(path.size() >= 3 and path[0].distance_to(w.line_end_world(l, 0)) < 0.5, "系绳从接头画起")
	var other_end: Vector2 = w.line_end_world(l, 1 if mover == pa.body else 0)
	var away: Vector2 = (mover.global_position - other_end).normalized()
	if away == Vector2.ZERO:
		away = Vector2.UP
	mover.global_position += away * (rest + 3.0 * Geom.M)
	mover.reset_physics_interpolation()
	await _frames(4)
	_check(not l.alive, "系绳被拉过长度后断开")
	await _frames(2)
	_check(snapped.has(l), "断开时发出 tether_snapped（接头扯断）")


# the bracket a fixing across a gap is drawn with: JD-38's AV is bolted 0.2 m off bulkhead B1-T
func _bracket_check(ship: String) -> void:
	if ship != "jd38":
		return
	var g = await _load(ship)
	var w = g.world
	var av = w.tag("AV")
	var bk = w.tag("B1-T")
	var j = null
	for q in w.joints_of(av):
		if q.b == bk.id or q.a == bk.id:
			j = q
	_check(j != null, "AV 与 B1-T 有固定件")
	if j != null:
		var out := PackedVector2Array()
		var pa = w.pieces[j.a]
		var pb = w.pieces[j.b]
		w._bridge(out, pa, pb, j.pos)
		var span := 0.0
		for i in range(0, out.size(), 2):
			span += out[i].distance_to(out[i + 1])
		_check(span >= 0.15 * Geom.M, "跨 0.2 m 缝的螺栓画成连接片（%.2f m）" % (span / Geom.M))
		_check(w._gap.has(j.id), "这个螺栓在要画连接片的名单里")
		# a fixing on a shared edge gets none
		var flush = null
		for q in w.joints:
			if q.alive and q.type == "weld" and q.b != Model.ANCHOR:
				var o := PackedVector2Array()
				w._bridge(o, w.pieces[q.a], w.pieces[q.b], q.pos)
				if o.is_empty():
					flush = q
					break
		_check(flush != null and not w._gap.has(flush.id), "贴合的焊缝不画连接片")
		# a cut through a bracketed part keeps the list right: cut AV in two, its bolt is checked again
		var av_mid: Vector2 = Geom.centroid(av.poly)
		w.commit_cut(av, PackedVector2Array([av_mid + Vector2(-3.0, -1.0) * Geom.M, av_mid + Vector2(3.0, -1.0) * Geom.M]))
		var still := false
		for q in w.joints:
			if q.alive and q.type == "bolt" and (w.pieces[q.a].key.begins_with("AV") or w.pieces[q.b] == bk) and (q.b == bk.id or q.a == bk.id):
				var o2 := PackedVector2Array()
				w._bridge(o2, w.pieces[q.a], w.pieces[q.b], q.pos)
				if not o2.is_empty():
					still = still or w._gap.has(q.id)
					if not w._gap.has(q.id):
						still = false
						break
		_check(still, "切开 AV 后，跨缝螺栓仍在连接片名单里")
	g.queue_free()
	await _frames(4)


func _bbox(w) -> Rect2:
	var bb := Rect2()
	var first := true
	for id in w.order:
		for q in w.world_poly(w.pieces[id]):
			if first:
				bb = Rect2(q, Vector2.ZERO)
				first = false
			else:
				bb = bb.expand(q)
	return bb


func _cut(w, a: Vector2, b: Vector2) -> void:
	var wpl := PackedVector2Array()
	var n := int(a.distance_to(b) / 3.0) + 1
	for i in n + 1:
		wpl.append(a.lerp(b, float(i) / n))
	w.cut_lines(wpl)
	for id in w.order.duplicate():
		var p = w.pieces.get(id)
		if p == null or p.gone:
			continue
		var inv: Transform2D = w.frame(p).affine_inverse()
		var bbp := Geom.bbox(p.poly).grow(8.0)
		var sub := PackedVector2Array()
		for q in wpl:
			var lq: Vector2 = inv * q - w.door_offset(p)
			if bbp.has_point(lq):
				sub.append(lq)
		if sub.size() >= 2:
			w.commit_cut(p, sub)


# how many groups (by fixings alone) a set of pieces falls into
static func _groups(w, list: Array) -> int:
	var ids := {}
	for p in list:
		ids[p.id] = p.id
	var find := func(x):
		while ids[x] != x:
			x = ids[x]
		return x
	for j in w.joints:
		if j.alive and ids.has(j.a) and ids.has(j.b):
			var ra = find.call(j.a)
			var rb = find.call(j.b)
			if ra != rb:
				ids[ra] = rb
	var roots := {}
	for k in ids:
		roots[find.call(k)] = true
	return roots.size()


# A: bodies made of several groups; B: attached groups no fixing anchors and that touch nothing held
static func diag(w) -> Dictionary:
	var out := {"body": [], "hanging": []}
	for b in w.bodies:
		if is_instance_valid(b) and _groups(w, b.pieces) > 1:
			out.body.append("一个刚体里有 %d 组只靠电缆相连: %s" % [_groups(w, b.pieces), str(b.pieces.map(func(q): return q.tag + "/" + q.kind))])
	# fixings-only union over attached pieces, with the anchor
	var par := {}
	var att: Array = []
	for id in w.order:
		var p = w.pieces[id]
		if not p.gone and p.body == null:
			par[id] = id
			att.append(p)
	par[Model.ANCHOR] = Model.ANCHOR
	var find := func(x):
		while par[x] != x:
			x = par[x]
		return x
	for j in w.joints:
		if j.alive and par.has(j.a) and par.has(j.b):
			var ra = find.call(j.a)
			var rb = find.call(j.b)
			if ra != rb:
				par[ra] = rb
	var anchor = find.call(Model.ANCHOR)
	# held by a line alone, a group must still sit against attached structure outside it
	var groups := {}
	for p in att:
		var r = find.call(p.id)
		if r != anchor:
			if not groups.has(r):
				groups[r] = []
			groups[r].append(p)
	for r in groups:
		var sits := false
		for p in groups[r]:
			for q in att:
				if find.call(q.id) == r:
					continue
				if Geom.bbox(w._drawn_poly(q)).grow(3.0).intersects(Geom.bbox(w._drawn_poly(p))) and World._polys_touch(w._drawn_poly(p), w._drawn_poly(q), World.SIT_GAP):
					sits = true
					break
			if sits:
				break
		if not sits:
			out.hanging.append("只靠电缆悬空的一组: %s" % str(groups[r].map(func(q): return "%s(%s) %s" % [q.tag, q.kind, (w.frame(q) * Geom.centroid(q.poly) / Geom.M).snapped(Vector2(0.1, 0.1))])))
	return out
