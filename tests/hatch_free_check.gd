extends SceneTree
# Playtest bug (2026-11-12): "拆第一艘货船的时候，货舱门打开的情况下舱门没有碰撞体积；这时把舱门连根切下，
# 直接没法合上了，于是我既不能直接牵引、又不能分割成小块牵引"; the user then: "舱门的问题确实有，就是打开后的
# 切割会有问题". For every door / hatch of a ship, cut the way the laser cuts (the pieces under the beam,
# each in its own frame, at the place they are drawn), in these orders:
#   free   open -> cut every hinge where it is drawn: the door comes loose where it stood; it collides,
#          is picked and taken by the grapple there; its mass is whole
#   half   open -> cut across the middle: the beam bites the open door (not the place it shuts to);
#          every part stays where it was drawn; the part still hinged stays solid there, a part cut
#          off comes loose; each part is picked; the mass is shared out
#   small  open -> cut the hinges -> cut the loose door across: every part loose, picked, taken
#   toggle open -> cut the hinges -> work its control: nothing slides, nothing jumps
#   shut   shut -> cut the hinges -> work its control: the same
# Own test saves only. Stills proofs/playtest_fix_hatch_<tag>_<mode>.png (with a window and a tag).
#   tools/run_test.sh tests/hatch_free_check.gd --fixed-fps 60 -- <ship> <tag> [modes,comma,separated]
#   godot --headless --path . --fixed-fps 60 -s tests/hatch_free_check.gd -- all|rest
const Cap = preload("res://tests/cap.gd")
const MODES := ["free", "half", "small", "toggle", "shut"]
const DEMO := ["belt", "pod", "tug", "s09", "gr7", "h22", "jd38", "qc30", "st40"]
var g: Node
var W
var fails := 0
var checks := 0


func _initialize() -> void:
	Career.path = "user://zp_test_hatchfree_career.json"
	SaveGame.path = "user://zp_test_hatchfree_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(cond: Callable, limit: int) -> bool:
	for i in limit:
		await _frames(1)
		if cond.call():
			return true
	return false


func _hit(at: Vector2, mask: int) -> Array:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = at
	q.collision_mask = mask
	q.collide_with_bodies = true
	var out: Array = []
	for r in W.get_world_2d().direct_space_state.intersect_point(q, 16):
		out.append(r.collider)
	return out


# a point well inside the piece as drawn
func _inside(p) -> Vector2:
	var wp: PackedVector2Array = W.world_poly(p)
	var c := Geom.centroid(wp)
	if Geometry2D.is_point_in_polygon(c, wp):
		return c
	for k in [0.2, 0.4, 0.6]:
		for v in wp:
			var t := v.lerp(c, k)
			if Geometry2D.is_point_in_polygon(t, wp):
				return t
	return c


# a point of the part the pointer takes it at (loose parts just cut can lie one over another, as any
# pile: the one on top is taken first); INF if it is covered all over
func _pick_pt(q) -> Vector2:
	var wp: PackedVector2Array = W.world_poly(q)
	var c := _inside(q)
	if _top(c) == q:
		return c
	var bb := Geom.bbox(wp)
	for ix in 10:
		for iy in 10:
			var tp := bb.position + bb.size * Vector2((ix + 0.5) / 10.0, (iy + 0.5) / 10.0)
			if Geometry2D.is_point_in_polygon(tp, wp) and _top(tp) == q:
				return tp
	return Vector2.INF


# what the pointer takes there (loose parts above the attached ship, as the grapple sees it)
func _top(at: Vector2):
	var l: Array = W.pieces_at(at)
	return l[0] if not l.is_empty() else null


# where a fixing is drawn (world.draw_joints_of: a door's fixings slide with it)
func _jdrawn(j) -> Vector2:
	var pa = W.pieces.get(j.a)
	return W.frame(pa) * (j.pos + W.door_offset(pa)) if pa != null else j.pos


# a laser stroke from a to b (world): every piece under it is cut there, in its own frame
func _stroke(a: Vector2, b: Vector2) -> void:
	var hit := {}
	for i in 25:
		for q in W.pieces_at(a.lerp(b, i / 24.0)):
			hit[q.id] = q
	for q in hit.values():
		if q.gone:
			continue
		var inv: Transform2D = W.frame(q).affine_inverse()
		var off: Vector2 = W.door_offset(q)
		W.commit_cut(q, PackedVector2Array([inv * a - off, inv * b - off]))


func _cut_hinges(d) -> void:
	# a cable or pipe to it holds it in place too (world._hold_by_lines): cut those as well
	for id in W.lines:
		var l = W.lines[id]
		if l.alive and (l.a == d.id or l.b == d.id):
			W.kill_line(l)
	var c := _inside(d)
	for j in W.joints_of(d):
		var at := _jdrawn(j)
		var dir := (at - c).normalized().orthogonal() if at.distance_to(c) > 1.0 else Vector2.RIGHT
		_stroke(at - dir * 0.15 * Geom.M, at + dir * 0.15 * Geom.M)


# a stroke right across the door's middle, along its short side, where it is drawn
func _across(d) -> void:
	var bb := Geom.bbox(d.poly)
	var c := bb.get_center()
	var a: Vector2
	var b: Vector2
	if bb.size.x >= bb.size.y:
		a = Vector2(c.x, bb.position.y - 10.0)
		b = Vector2(c.x, bb.end.y + 10.0)
	else:
		a = Vector2(bb.position.x - 10.0, c.y)
		b = Vector2(bb.end.x + 10.0, c.y)
	var xf: Transform2D = W.frame(d)
	var off: Vector2 = W.door_offset(d)
	_stroke(xf * (a + off), xf * (b + off))


# the kerf eats metal: what is left keeps the door's mass per area (no mass made or lost otherwise)
func _density_ok(parts: Array, mass0: float, area0: float) -> Array:
	var m := 0.0
	var ar := 0.0
	for q in parts:
		m += q.mass
		ar += absf(Geom.area(q.poly))
	var k0 := mass0 / maxf(area0, 1.0)
	var k := m / maxf(ar, 1.0)
	return [absf(k - k0) <= 0.02 * k0 and m <= mass0 * 1.001, "%.3f t of %.3f t, %.0f%% of the area" % [m, mass0, 100.0 * ar / maxf(area0, 1.0)]]


func _parts_of(d, key: String) -> Array:
	return W.order.map(func(i): return W.pieces[i]).filter(func(q): return not q.gone and (q == d or str(q.key).begins_with(key + "~")))


func _ctrl_for(d):
	if str(d.tag) == "":
		return null
	for c in W.ctrls.values():
		if str(c.target) == str(d.tag) or Ship.ctrl_cfg(g.ship, c.id).get("doors", []).has(d.tag):
			return c
	return null


func _grab_ok(q, pt: Vector2) -> bool:
	g.tools.set_tool(3, true)
	# (the drone is not moved: put down on the parts it knocked them flying)
	# the pointer on the part where it is now (parts at rest in space still ease apart a little)
	for k in 3:
		q.body.linear_velocity = Vector2.ZERO
		q.body.angular_velocity = 0.0
		var pp := _pick_pt(q)
		g.bot.aim = pp if pp != Vector2.INF else _inside(q)
		await _frames(3)
		var hv: Dictionary = g.tools.hover
		if hv.get("kind", "") == "piece" and hv.get("piece") == q:
			return true
	if g.tools.hover.is_empty():
		print("    (no hover: drone alive %s, tool_ok %s, hidden %s, tool %d, state %s menu %s contract %s paused %s console %s, pieces there %s, aim %s)" % [g.drone.alive, g.tool_ok(3), W.hidden(_inside(q)), g.tools.tool, g.state, g.menu_open, g.contract_open, g.paused_sim, g.console_ui != null, W.pieces_at(_inside(q)).map(func(x): return x.key), str(g.tools.aim.round())])
	return false


func _shot(name: String, tag: String, at: Vector2) -> void:
	if DisplayServer.get_name() == "headless" or tag == "":
		return
	g.drone.global_position = at + Vector2(0.0, 4.0) * Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()
	g.cam_pos = at
	await _frames(20)
	Cap.save(root, "res://proofs/playtest_fix_hatch_%s_%s.png" % [tag, name])


func _game(ship: String) -> void:
	Game.contract = {}
	Game.start_ship = ship
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(10)
	W = g.world
	g.tutorial = null
	# the first ship's coached steps open the tools one by one; here every tool is open (as by then)
	if g.prologue != null and is_instance_valid(g.prologue):
		g.prologue.done = true
	g.coach = null
	g.port_walk = null
	if g.drone != null:
		g.drone.alive = true
		g.drone.spawn_t = 3.0
	if g.sys != null:
		g.sys.aux = true


# the loose parts: each collides, is picked and taken where it is drawn
func _loose_ok(parts: Array, nm: String, grab: bool) -> void:
	var ok := not parts.is_empty()
	var why := ""
	for q in parts:
		q.body.linear_velocity = Vector2.ZERO
		q.body.angular_velocity = 0.0
	await _frames(2)
	for q in parts:
		var pt := _inside(q)
		if not q.body in _hit(pt, q.body.collision_layer):
			ok = false
			why += " %s:no-col(layer %d ghost %.2f calm %.2f shapes %d)" % [q.key, q.body.collision_layer, q.body.ghost, q.body.calm, q.body.get_child_count()]
		elif _pick_pt(q) == Vector2.INF:
			# lying wholly under another loose part (a pile: that one is taken first) is not a miss
			var top = _top(pt)
			if top == null or top.body == null:
				ok = false
				why += " %s:not-picked" % q.key
			else:
				print("    %s lies under %s (loose): taken after it" % [q.key, top.key])
				continue
		elif q.door:
			ok = false
			why += " %s:still-a-door" % q.key
		elif grab and not await _grab_ok(q, pt):
			ok = false
			var hv: Dictionary = g.tools.hover
			why += " %s:grapple-misses(hover %s %s %s)" % [q.key, hv.get("kind", "-"), hv.get("piece").key if hv.get("piece") != null else "", hv.get("reason", "")]
	check(ok, nm + ": every loose part collides, is picked%s where it is drawn%s" % [" and taken" if grab else "", why])


func _one(ship: String, mode: String, tag: String) -> void:
	await _game(ship)
	if g.tools == null or g.drone == null:
		print("%s: no drone here (a training rig), skipped" % ship)
		g.queue_free()
		await _frames(4)
		return
	var doors: Array = W.order.map(func(i): return W.pieces[i]).filter(func(p): return p.door and not p.gone and p.body == null and p.open_dir.length() > 4.0)
	print("%s %s: %d doors" % [ship, mode, doors.size()])
	var n := 0
	for d in doors:
		n += 1
		if n > 3:
			break
		var nm := "%s %s %s" % [ship, mode, d.key]
		var key: String = d.key
		var mass0: float = d.mass
		var area0: float = absf(Geom.area(d.poly))
		if mode != "shut":
			d.door_open = true
		for rn in W.rooms:
			W.reveal(rn, Geom.centroid(W.world_poly(d)))
		await _frames(60)
		var at := _inside(d)
		var poly0: PackedVector2Array = W.world_poly(d)
		if mode != "shut":
			check(W.static_cols.has(d.id) and _hit(at, W.STATIC_LAYER).size() > 0, nm + ": opened, solid where it stands")
		if n == 1:
			await _shot(mode + "_1", tag, at)
		if mode == "half":
			_across(d)
			var parts := _parts_of(d, key)
			check(parts.size() >= 2, nm + ": the beam bites the open door (%d parts)" % parts.size())
			var stay := true
			for q in parts:
				var pt := _inside(q)
				if not Geometry2D.is_point_in_polygon(pt, poly0):
					stay = false
					print("  %s at %s m off the open door" % [q.key, str((pt - Geom.centroid(poly0)) / Geom.M)])
			check(stay, nm + ": every part where the open door was drawn")
			var dk := _density_ok(parts, mass0, area0)
			check(dk[0], nm + ": the mass shared out by area (%s)" % dk[1])
			check(parts.all(func(q): return not q.door), nm + ": its parts slide no more")
			await _frames(40)
			var attached := parts.filter(func(q): return not q.gone and q.body == null)
			var loose := parts.filter(func(q): return not q.gone and q.body != null)
			var att_ok := true
			for q in attached:
				var pt := _inside(q)
				if not Geometry2D.is_point_in_polygon(pt, poly0) or _hit(pt, W.STATIC_LAYER).is_empty() or not W.pieces_at(pt).has(q):
					att_ok = false
					print("  %s: in place %s, solid %s, picked %s" % [q.key, Geometry2D.is_point_in_polygon(pt, poly0), not _hit(pt, W.STATIC_LAYER).is_empty(), W.pieces_at(pt).has(q)])
			check(att_ok, nm + ": the part still hinged stays solid and picked where it was (%d attached, %d loose)" % [attached.size(), loose.size()])
			if not loose.is_empty():
				await _loose_ok(loose, nm, true)
			if n == 1:
				await _shot(mode + "_2", tag, at)
			continue
		_cut_hinges(d)
		await _until(func(): return d.body != null, 30)
		check(W.joints_of(d).is_empty(), nm + ": every hinge cut where it is drawn")
		check(d.body != null, nm + ": it comes loose")
		if d.body == null:
			continue
		var at0 := _inside(d)
		check(at0.distance_to(at) < 0.6 * Geom.M or Geometry2D.is_point_in_polygon(at0, poly0), nm + ": loose where it stood (%.2f m, off %s m, slide %.2f m, %d hinge parts)" % [at0.distance_to(at) / Geom.M, str((at0 - at) / Geom.M), d.open_dir.length() / Geom.M, _parts_of(d, key).size()])
		var parts := _parts_of(d, key)
		var dk := _density_ok(parts, mass0, area0)
		check(dk[0], nm + ": its mass by what is left of it (%s)" % dk[1])
		await _frames(30)
		if mode == "free":
			await _loose_ok(parts.filter(func(q): return q.body != null), nm, true)
			if n == 1:
				await _shot(mode + "_2", tag, _inside(d))
		elif mode == "small":
			d.body.linear_velocity = Vector2.ZERO
			d.body.angular_velocity = 0.0
			# cut while it is still easing out of its pocket in the hull (the beam takes what lies under
			# the door too: a part of that born inside the door must not throw either of them)
			var bb0 := Geom.bbox(d.poly)
			# the parts the hinge cuts left (a sliver may stay on a hinge) are not this cut's
			var before_ids := _parts_of(d, key).filter(func(q): return q != d).map(func(q): return q.id)
			_across(d)
			var cut_n := _parts_of(d, key).filter(func(q): return not q.id in before_ids).size()
			var born := {}
			for q in _parts_of(d, key):
				if not q.id in before_ids:
					born[q.id] = _inside(q)
			await _frames(20)
			var far := 0.0
			for q in _parts_of(d, key):
				if born.has(q.id):
					far = maxf(far, _inside(q).distance_to(born[q.id]))
					if _inside(q).distance_to(born[q.id]) > 1.5 * Geom.M and q.body != null:
						print("    moved %s: v %s w %.2f ghost %.2f clearing %.2f layer %d mask %d mass %.3f" % [q.key, str(q.body.linear_velocity.round()), q.body.angular_velocity, q.body.ghost, q.body.clearing, q.body.collision_layer, q.body.collision_mask, q.body.total_mass()])
			var fast := 0.0
			for q in _parts_of(d, key):
				if born.has(q.id) and q.body != null:
					fast = maxf(fast, q.body.linear_velocity.length())
			check(far < 3.0 * Geom.M and fast < 3.0 * Geom.M, nm + ": no part thrown (the farthest moved %.2f m in 1/3 s, the fastest %.1f m/s)" % [far / Geom.M, fast / Geom.M])
			# a cut-off under the debris limit goes straight to the debris net (game._bodies_upkeep)
			var ps := _parts_of(d, key).filter(func(q): return not q.id in before_ids)
			if cut_n > ps.size():
				print("  %s: %d of %d parts small enough for the debris net" % [key, cut_n - ps.size(), cut_n])
			if cut_n < 2:
				for i in W.order:
					var q = W.pieces[i]
					if str(q.key).begins_with(key):
						print("    %s gone %s body %s area %.3f m2" % [q.key, q.gone, q.body != null, absf(Geom.area(q.poly)) / (Geom.M * Geom.M)])
				print("  %s: %d parts before, bbox %s m, area %.2f m2, gone %s" % [key, parts.size(), str(bb0.size / Geom.M), absf(Geom.area(d.poly)) / (Geom.M * Geom.M), d.gone])
			check(cut_n >= 2, nm + ": the loose door cut across (%d parts)" % cut_n)
			check(ps.all(func(q): return q.body != null), nm + ": every part loose")
			await _loose_ok(ps.filter(func(q): return q.body != null), nm, true)
			if n == 1:
				await _shot(mode + "_2", tag, _inside(d))
		else:
			var c = _ctrl_for(d)
			# born in its pocket in the hull, it eases out first (as any part born inside the ship)
			await _until(func(): return d.body.ghost <= 0.0, 240)
			await _frames(10)
			d.body.linear_velocity = Vector2.ZERO
			d.body.angular_velocity = 0.0
			await _frames(2)
			# its own drift, without the control (a part at rest in space stays at rest)
			var drift0 := _inside(d)
			await _frames(50)
			var drift := _inside(d).distance_to(drift0)
			d.body.linear_velocity = Vector2.ZERO
			d.body.angular_velocity = 0.0
			await _frames(2)
			var before := _inside(d)
			var open0: bool = d.door_open
			if c != null:
				g.do_wrench({"kind": "ctrl", "ctrl": c, "pos": W.ctrl_world(c)})
				await _frames(50)
			else:
				# no control of its own (worked by a hatch lever, or none): flip what one would
				d.door_open = not d.door_open
				await _frames(50)
				d.door_open = open0
			d.body.linear_velocity = Vector2.ZERO
			check(not d.door and d.door_open == open0, nm + ": its control (%s) does nothing to it now" % ("worked" if c != null else "none: state flipped"))
			var moved := _inside(d).distance_to(before)
			check(moved < 0.5 * Geom.M or moved < drift * 1.5 + 0.1 * Geom.M, nm + ": nothing slides or jumps (%.2f m; %.2f m adrift on its own without the control; ghost %.2f calm %.2f v %.0f)" % [moved / Geom.M, drift / Geom.M, d.body.ghost, d.body.calm, d.body.linear_velocity.length()])
			await _loose_ok([d], nm, true)
			if n == 1:
				await _shot(mode + "_2", tag, _inside(d))
	g.queue_free()
	await _frames(4)


func _run() -> void:
	Txt.zh = true
	var a := OS.get_cmdline_user_args()
	var ship := a[0] if a.size() > 0 else "belt"
	var tag := a[1] if a.size() > 1 else ""
	var modes: Array = Array(a[2].split(",")) if a.size() > 2 else MODES
	var list: Array = [ship]
	if ship == "all":
		list = DEMO
	elif ship == "rest":
		# every other ship with doors (the full game): the orders that cut the open door itself
		list = []
		modes = ["half", "small"] if a.size() <= 2 else modes
		for f in DirAccess.get_files_at("res://ships"):
			var id := f.get_basename()
			if f.ends_with(".json") and not id in DEMO and id != "berth" and not id.begins_with("sp_") and FileAccess.get_file_as_string("res://ships/" + f).contains("\"open_dir\""):
				list.append(id)
	for s in list:
		for m in modes:
			await _one(s, m, tag)
	print("hatch_free_check: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
