extends Node2D
# ARK-01 改造方案 2（侧挂转轮）：转动画面、刹车、读数牌。Drawing only; scripts/rings.gd keeps
# every number (rpm, angle, brakes, capacitor, heat, lock). Made by rings.gd when the ship's "rings"
# says "wheels" (tools/authoring/ark01_wheels.gd).
#   Each wheel's pieces (its spokes, rim modules and rim trusses: the ring's "members") are out of
#   the strips (world.live) and drawn once, in every pass of the strips, under a pivot node at the
#   hub; turning the wheel only turns the pivot (no redraw a frame). The housing at the centre,
#   the pylon and the spine stay in the strips: they don't turn.
#   Cables with both ends on the wheel turn with it; a cable from the housing out onto the wheel
#   (through the slip ring) isn't drawn while it turns.
#   Beside each wheel, out of its swept circle, a readout board (charcoal, no frame): the rpm,
#   the two wheels' difference, the brake capacitor and temperature, the time to a stop at the
#   present braking, the angle to the lock pin.

const PASSES := ["shade", "fill", "block", "line", "line_far", "art", "joint"]
const BOARD := Vector2(23.0, 22.3)      # m

var rings
var game
var world
var _piv := {}            # ring -> [pivot nodes, one a pass]
var _mem := {}            # ring -> [pieces]
var _glow: Node2D        # the brake pads glowing as they bite (added light)
var _deco: Array = []     # the wheels' fitting-out drawn (scripts/rings_deco.gd): faint when close
var _emit := {}
var _hub := {}            # ring -> Vector2 px
var _streaks := {}        # ring -> its streaks' pivot (turns with it)
var _streak_k := {}       # ring -> the rpm step they were drawn at
var _board_sig := ""
var _board_s := 1.0        # the boards' scale: up to legible when the camera is far out
var _board: Node2D
var _lines := {}          # ring -> [lines on the wheel]
var _joints := {}         # ring -> [joints on the wheel]
var _rooms := {}          # ring -> [rooms on the wheel]
var _still := {}          # ring -> the housing's fitting-out node (doesn't turn)


func setup(rg) -> void:
	rings = rg
	game = rg.game
	world = rg.world
	world.add_child(self)
	for r in rings.cfg.rings:
		var e: Dictionary = rings.cfg.rings[r]
		var h: Array = e.get("hub", [0.0, 0.0])
		_hub[r] = Vector2(float(h[0]), float(h[1])) * Geom.M
		var list: Array = []
		var ids := {}
		for t in e.get("members", []):
			var p = world.tag(str(t))
			if p != null and not p.gone:
				list.append(p)
				ids[p.id] = true
				world.live[p.id] = true
		_mem[r] = list
		var on_wheel: Array = []
		for id in world.lines:
			var l = world.lines[id]
			var a: bool = ids.has(l.a)
			var b: bool = ids.has(l.b)
			if a and b:
				on_wheel.append(l)
			if a or b:
				world.hide_lines[id] = true
		_lines[r] = on_wheel
		var js: Array = []
		for j in world.joints:
			if ids.has(j.a) and ids.has(j.b):
				js.append(j)
		_joints[r] = js
		# the rooms on the wheel (its spokes' and modules'): their back turns with it
		var rms: Array = []
		for n in world.rooms:
			var inside := 0
			for p in list:
				if p.room == n:
					inside += 1
			if inside > 0 and _room_on_wheel(n, ids):
				rms.append(n)
				world.hide_rooms[n] = true
		_rooms[r] = rms
	# the speed streaks off the rim modules, redrawn as the rpm changes
	for r in _hub:
		var sp := Node2D.new()
		sp.z_index = 2
		sp.position = _hub[r]
		world.add_child(sp)
		sp.draw.connect(_draw_streaks.bind(sp, r))
		_streaks[r] = sp
	_board = Node2D.new()
	_board.z_index = 40
	_board.z_as_relative = false
	world.add_child(_board)
	_board.draw.connect(_draw_boards.bind(_board))
	world.redraw_all(true)
	world.line_layer.queue_redraw()


# a room is the wheel's when no piece off the wheel says it is in it
func _room_on_wheel(n: String, ids: Dictionary) -> bool:
	for id in world.order:
		var p = world.pieces[id]
		if p.room == n and not ids.has(p.id):
			return false
	return true


# the strips' pass roots are made at their first sync: hang the wheel's own under them then
func _build() -> void:
	for r in _hub:
		if rings.released.has(r):
			continue
		var nodes: Array = []
		for part in PASSES:
			var root: Node2D = world._pass_roots.get(part)
			if root == null:
				continue
			nodes.append(_pivot(root, r, _draw_wheel, part))
		nodes.append(_pivot(world.back_layer, r, _draw_backs, ""))
		# the fitting-out: turning with the wheel, over the fills, under the outlines and art
		var droot: Node2D = world._pass_roots.get("fill")
		if droot != null:
			var dp := _pivot(droot, r, _draw_deco, "")
			nodes.append(dp)
			_deco.append(dp)
			# the housing's (still)
			var hs := Node2D.new()
			hs.draw.connect(_draw_housing_deco.bind(hs, r))
			droot.add_child(hs)
			_deco.append(hs)
			_still[r] = hs
		_piv[r] = nodes


func _pivot(root: Node2D, r: String, fn: Callable, part: String) -> Node2D:
	var piv := Node2D.new()
	piv.position = _hub[r]
	var inner := Node2D.new()
	inner.position = -_hub[r]
	inner.draw.connect(fn.bind(inner, r, part))
	piv.add_child(inner)
	root.add_child(piv)
	return piv


func _process(dt: float) -> void:
	if rings == null or game == null:
		return
	if _piv.is_empty():
		if world._pass_roots.is_empty():
			return
		_build()
	var run: bool = game.state == "play" and not game.paused_sim
	var zk := clampf((game.cam_zoom() - World.ART_FADE.x) / (World.ART_FADE.y - World.ART_FADE.x), 0.0, 1.0) if game.cam != null else 0.0
	for dn in _deco:
		if is_instance_valid(dn):
			dn.modulate.a = lerpf(1.0, 0.22, zk)
	for r in _piv:
		var a: float = float(rings.ang.get(r, 0.0))
		for piv in _piv[r]:
			piv.rotation = a
		var sp = _streaks.get(r)
		if sp == null:
			continue
		sp.rotation = a
		if run:
			_brake_fx(r, dt)
		var k: float = 0.0 if rings.locked.has(r) else snappedf(clampf(float(rings.rpm.get(r, 0.0)) / 3.0, 0.0, 1.0), 0.02)
		if k != float(_streak_k.get(r, -1.0)):
			_streak_k[r] = k
			sp.queue_redraw()
	# the boards: redrawn only when what they read changes
	var z: float = game.cam_zoom() if game.cam != null else 1.0
	_board_s = clampf(snappedf(0.24 / maxf(z, 0.01), 0.1), 1.0, 3.0)
	var sig := _board_text_sig() + str(_board_s)
	if sig != _board_sig:
		_board_sig = sig
		_board.queue_redraw()


func _board_text_sig() -> String:
	var out := ""
	for r in _hub:
		out += "%.2f|%d|%d|%d|%s|%s|%d|%s|" % [float(rings.rpm.get(r, 0.0)), int(rings.cap_charge(r) * 100.0), int(rings.temp(r)), rings.brakes_on(r),
			rings.loads_live(r), rings.locked.has(r), int(round(to_pin(r))) if not rings.turning(r) else -1, rings.dumping(r)]
	return out + "%.1f" % rings.tq_left


# tests: hold a wheel at an angle (rad) and redraw its back (a room revealed later)
func hold(r: String, ang: float) -> void:
	rings.ang[r] = ang
	for piv in _piv.get(r, []):
		piv.rotation = ang
		for c in piv.get_children():
			c.queue_redraw()


func to_pin(r: String) -> float:
	return rings.to_pin(r)


# pinned at its hole: the wheel's pieces go back to the strips (they are where the file put them)
func release(r: String) -> void:
	for p in _mem.get(r, []):
		world.live.erase(p.id)
	for l in _lines.get(r, []):
		world.hide_lines.erase(l.id)
	for id in world.hide_lines.keys():
		var l = world.lines.get(id)
		if l == null:
			continue
		var on := false
		for p in _mem.get(r, []):
			if l.a == p.id or l.b == p.id:
				on = true
				break
		if on:
			world.hide_lines.erase(id)
	for n in _rooms.get(r, []):
		world.hide_rooms.erase(n)
	for piv in _piv.get(r, []):
		_deco.erase(piv)
		piv.queue_free()
	_piv.erase(r)
	if _still.has(r):
		_deco.erase(_still[r])
		_still[r].queue_free()
		_still.erase(r)
	if _streaks.has(r):
		_streaks[r].queue_free()
		_streaks.erase(r)
	_mem[r] = []
	world.line_layer.queue_redraw()
	_board.queue_redraw()


# torn off the wheel: no longer drawn with it (its body draws it)
func drop(pieces: Array) -> void:
	for r in _mem:
		var before: int = (_mem[r] as Array).size()
		_mem[r] = (_mem[r] as Array).filter(func(p): return not pieces.has(p))
		if (_mem[r] as Array).size() != before:
			for p in pieces:
				world.live.erase(p.id)
			for piv in _piv.get(r, []):
				for c in piv.get_children():
					c.queue_redraw()


# the brake pads where they bite on the wheel's inner race: red as they heat, sparks, smoke when dry
func _brake_fx(r: String, dt: float) -> void:
	var n: int = rings.brakes_on(r)
	if n <= 0 or not rings.turning(r) or rings.loads_live(r):
		return
	var e: Dictionary = rings.cfg.rings[r]
	var cool: bool = game.sys.on(str(e.get("cool", "")))
	var heat: float = clampf((rings.temp(r) - 30.0) / 290.0, 0.0, 1.0)
	_emit[r] = float(_emit.get(r, 0.0)) + dt
	if float(_emit[r]) < 0.09:
		return
	_emit[r] = 0.0
	var k := clampf(float(rings.rpm.get(r, 0.0)) / 3.0, 0.0, 1.0)
	var dir: float = float(e.get("dir", 1.0))
	for t in e.get("brake_pieces", {}).values():
		var p = world.tag(str(t))
		if p == null or p.gone:
			continue
		var at: Vector2 = Geom.centroid(p.poly)
		var tang: Vector2 = (at - _hub[r]).normalized().orthogonal() * dir
		game.fx.sparks(at, tang, 2 + int(3.0 * k), Pal.heat(0.8 + 0.4 * heat, 2.0), 140.0 + 260.0 * k, 0.35, 0.5)
		if heat > 0.25:
			game.fx.flash(at, 24.0 + 40.0 * heat, 0.12, Pal.heat(0.4 + 0.6 * heat, 1.6))
		if not cool and rings.temp(r) > 250.0:
			game.fx.puff(at, Vector2(randf_range(-20, 20), -30.0), 1.4, 6.0, 30.0, Pal.ink(0.18))


func _draw_wheel(ci: Node2D, r: String, part: String) -> void:
	var list: Array = _mem.get(r, [])
	if list.is_empty():
		return
	if part == "joint":
		world.draw_joints_of(ci, list, _joints[r])
		return
	world.draw_pieces(ci, list, part)
	if part == "line":
		for l in _lines[r]:
			if l.alive:
				world._draw_line_path(ci, l, l.path, 1.0)


func _draw_backs(ci: Node2D, r: String, _part: String) -> void:
	var shells: Dictionary = world._room_shells()
	for n in _rooms.get(r, []):
		if Pal.solid:
			Cutaway.back_room(world, ci, n, shells)
			continue
		var rm = world.rooms[n]
		ci.draw_colored_polygon(rm.poly, Pal.ROOM_LIT if rm.revealed else Color(0.03, 0.031, 0.035))


# a faint blur trailing each rim module (behind it, the way it turns), as long as it turns
func _draw_streaks(ci: Node2D, r: String) -> void:
	if true:
		var k: float = float(_streak_k.get(r, 0.0))
		if k <= 0.0:
			return
		var e: Dictionary = rings.cfg.rings[r]
		var dir: float = float(e.get("dir", 1.0))
		var c := Vector2.ZERO
		var ro: float = float(e.get("radius", 40.0)) * Geom.M
		var sw: float = float(e.get("sweep", ro / Geom.M)) * Geom.M
		for base in [-PI * 0.5, PI * 0.5]:
			var mid: float = base
			# behind the module: the far side from where it is going
			for i in 5:
				var rr: float = lerpf(ro * 0.62, sw * 0.99, float(i) / 4.0)
				var span: float = (0.18 + 0.32 * k) * (1.0 - 0.12 * i)
				var a1: float = mid - dir * 0.42
				var a0: float = a1 - dir * span
				var aa := minf(a0, a1)
				var bb := maxf(a0, a1)
				var pts := PackedVector2Array()
				var n := 12
				for j in n + 1:
					pts.append(c + Vector2.from_angle(lerpf(aa, bb, float(j) / n)) * rr)
				var cols := PackedColorArray()
				for j in n + 1:
					var f := float(j) / n
					var t := f if dir > 0.0 else 1.0 - f
					cols.append(Pal.ink((0.03 + 0.10 * k) * t))
				ci.draw_polyline_colors(pts, cols, 1.6)
		# the swept circle, very faint: where not to be while it turns
		ci.draw_arc(c, sw, 0.0, TAU, 96, Pal.ink(0.035 + 0.04 * k), 1.2, true)


func _w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _draw_boards(ci: Node2D) -> void:
	var font: Font = world.font
	if font == null:
		return
	var rs: Array = rings.cfg.rings.keys()
	var diff := 0.0
	if rs.size() >= 2:
		var a0: float = float(rings.cfg.rings[rs[0]].get("rpm0", rings.cfg.rings[rs[0]].get("rpm", 3.0)))
		var b0: float = float(rings.cfg.rings[rs[1]].get("rpm0", rings.cfg.rings[rs[1]].get("rpm", 3.0)))
		diff = absf(float(rings.rpm[rs[0]]) / maxf(a0, 0.01) - float(rings.rpm[rs[1]]) / maxf(b0, 0.01))
	var M := Geom.M
	for r in _piv:
		var e: Dictionary = rings.cfg.rings[r]
		var sw: float = float(e.get("sweep", 40.0)) * M
		var c: Vector2 = _hub[r]
		# beside the wheel, out of its swept circle: A to its right (over the spine), B to its left
		var right: bool = r == "A"
		# well clear of the swept circle (never over the wheel), a short tick pointing back at it
		var anchor := c + Vector2((sw + 12.0 * M) if right else -(sw + 12.0 * M), 0.0)
		var tick := Vector2(-1.0 if right else 1.0, 0.0) * 5.0 * M
		ci.draw_line(anchor, anchor + tick, Pal.ink(0.22), 2.0 * _board_s, true)
		ci.draw_circle(anchor + tick, 0.5 * M * _board_s, Pal.ink(0.3))
		# drawn about its edge by the wheel, scaled up when the camera is far out so it stays legible
		ci.draw_set_transform(anchor, 0.0, Vector2(_board_s, _board_s))
		var o := Vector2(0.0 if right else -BOARD.x * M, -BOARD.y * 0.5 * M)
		var sz := BOARD * M
		ci.draw_rect(Rect2(o, sz), Color(0.055, 0.058, 0.066, 0.9))
		ci.draw_rect(Rect2(o, Vector2(0.35 * M, sz.y)), Pal.heat(0.75, 1.0) if rings.turning(r) else Pal.ink(0.4))
		var x := o.x + 1.4 * M
		var y := o.y + 2.6 * M
		var fs := int(1.15 * M)
		var big := int(2.3 * M)
		var name := _w("A 环 · 居住", "RING A · HABITAT") if r == "A" else _w("B 环 · 农业", "RING B · FARM")
		ci.draw_string(font, Vector2(x, y), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.ink(0.55))
		var rpm: float = float(rings.rpm.get(r, 0.0))
		var arrow := "↻" if float(e.get("dir", 1.0)) > 0.0 else "↺"
		y += 3.4 * M
		ci.draw_string(font, Vector2(x, y), "%.2f" % rpm, HORIZONTAL_ALIGNMENT_LEFT, -1, big, Pal.ink(0.95))
		ci.draw_string(font, Vector2(x + 7.4 * M, y), _w("转/分 ", "RPM ") + arrow, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.ink(0.6))
		var g: float = pow(rpm * TAU / 60.0, 2.0) * float(e.get("radius", 40.0)) / 9.81
		ci.draw_string(font, Vector2(x + 13.6 * M, y), "%.2f g" % g, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.ink(0.45))
		# the rows
		var n: int = rings.brakes_on(r)
		var decel: float = float(e.get("decel", 0.01)) * n
		var eta := "—"
		if rings.turning(r) and n > 0 and not rings.loads_live(r):
			eta = "%d s" % int(ceil(rpm / maxf(decel, 0.0001)))
		elif not rings.turning(r):
			eta = _w("已停", "STOPPED")
		var pin := "—"
		if not rings.turning(r):
			pin = _w("已锁", "LOCKED") if rings.locked.has(r) else "%d°" % int(round(to_pin(r)))
		var rows := [
			[_w("负载", "LOADS"), _w("带电", "LIVE") if rings.loads_live(r) else _w("已断", "OFF"), rings.loads_live(r)],
			[_w("两轮差", "MISMATCH"), "%d%%" % int(round(diff * 100.0)), diff > 0.2],
			[_w("电容", "BRAKE CAP"), ("%d%% " % int(round(rings.cap_charge(r) * 100.0))) + (_w("泄放中", "DUMPING") if rings.dumping(r) else ""), rings.cap_charge(r) > 0.9],
			[_w("制动器", "BRAKES"), "%d · %d°C" % [n, int(rings.temp(r))], rings.temp(r) > 250.0],
			[_w("预计停转", "STOP IN"), eta, false],
			[_w("反扭", "TWIST IN"), ("%.1f s" % rings.tq_left) if rings.tq_left >= 0.0 else "—", rings.tq_left >= 0.0],
			[_w("距锁销", "TO PIN"), pin, false],
		]
		y += 1.0 * M
		for row in rows:
			y += 1.75 * M
			ci.draw_string(font, Vector2(x, y), str(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.ink(0.45))
			ci.draw_string(font, Vector2(x + 7.4 * M, y), str(row[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.heat(0.9, 1.4) if row[2] else Pal.ink(0.85))
			if str(row[0]) == _w("两轮差", "MISMATCH"):
				# the bar: 20 % is where the hull starts to twist
				var bx := x + 12.0 * M
				var bw := 8.0 * M
				ci.draw_rect(Rect2(Vector2(bx, y - 0.75 * M), Vector2(bw, 0.5 * M)), Pal.ink(0.1))
				ci.draw_rect(Rect2(Vector2(bx, y - 0.75 * M), Vector2(bw * clampf(diff / 0.4, 0.0, 1.0), 0.5 * M)), Pal.heat(0.9, 1.4) if diff > 0.2 else Pal.ink(0.6))
				ci.draw_line(Vector2(bx + bw * 0.5, y - 1.0 * M), Vector2(bx + bw * 0.5, y), Pal.ink(0.5), 1.5)
		# the author's line on the gravity (占位: the owner writes it)
		ci.draw_string(font, Vector2(x, o.y + sz.y - 0.9 * M), _w("【占位：按火星重力设计的说明】", "[PLACEHOLDER: built for Mars gravity]"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.9 * M), Pal.ink(0.3))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- the fitting-out (scripts/rings_deco.gd)

func _draw_deco(ci: Node2D, r: String, _part: String) -> void:
	var D = preload("res://scripts/rings_deco.gd").new()
	D.M = Geom.M
	var M := Geom.M
	var hub: Vector2 = _hub[r] / M
	var ids := {}
	for p in _mem.get(r, []):
		ids[p.id] = p
	var boxes := {}
	for n in _rooms.get(r, []):
		var rp: PackedVector2Array = world.rooms[n].poly
		var bb := Geom.bbox(rp)
		boxes[n] = Rect2(bb.position / M, bb.size / M)
	for n in boxes:
		var rb: Rect2 = boxes[n]
		if str(n).begins_with("S"):
			D.spoke(rb, rb.size.y > rb.size.x)
			continue
		if not str(n).begins_with("R"):
			continue
		# the module's decks, outer wall to inner
		var top_out: bool = absf(rb.position.y - hub.y) > absf(rb.end.y - hub.y)
		var y_out: float = rb.position.y if top_out else rb.end.y
		var y_in: float = rb.end.y if top_out else rb.position.y
		var up := 1.0 if top_out else -1.0
		var decks: Array = []
		for p in ids.values():
			if p.kind != "deck":
				continue
			var db := Geom.bbox(p.poly)
			var dc: Vector2 = db.get_center() / M
			if rb.has_point(dc):
				decks.append([db.position.y / M, db.end.y / M])
		decks.sort_custom(func(a, b): return absf(a[0] - y_out) < absf(b[0] - y_out))
		var faces: Array = [y_out]
		for dk in decks:
			faces.append(dk[0] if top_out else dk[1])
			faces.append(dk[1] if top_out else dk[0])
		faces.append(y_in)
		# rooms inside this one (the cold store): drawn as their own, left out of the deck they're on
		var subs: Array = []
		for m in boxes:
			if m != n and rb.encloses(boxes[m]) and not str(m).begins_with("S"):
				subs.append(m)
		for k in range(0, faces.size() - 1, 2):
			var fl: float = faces[k]
			var ce: float = faces[k + 1]
			var hh := absf(ce - fl)
			if hh < 1.5:
				continue
			var spans: Array = [[rb.position.x, rb.end.x]]
			for m in subs:
				var sb: Rect2 = boxes[m]
				if sb.get_center().y > minf(fl, ce) and sb.get_center().y < maxf(fl, ce):
					D.band(r, k / 2, sb.position.x, sb.end.x, sb.end.y if up < 0.0 else sb.position.y, up, sb.size.y, str(m))
					var cut: Array = []
					for sp in spans:
						if sb.position.x > sp[0]:
							cut.append([sp[0], sb.position.x - 0.4])
						if sb.end.x < sp[1]:
							cut.append([sb.end.x + 0.4, sp[1]])
					spans = cut
			for sp in spans:
				if float(sp[1]) - float(sp[0]) > 2.0:
					D.band(r, k / 2, float(sp[0]), float(sp[1]), fl, up, hh, str(n))
		D.plating(rb.position.x, rb.end.x, y_out, up)
	# the rim corridors: along each side's truss
	for side in ["E", "W"]:
		var angs: Array = []
		var rads: Array = []
		for p in ids.values():
			if str(p.tag) == "" or not str(p.tag).begins_with("RT%s%s" % [r, side]) or p.kind != "beam":
				continue
			var c: Vector2 = Geom.centroid(p.poly) / M - hub
			var a := c.angle()
			angs.append(wrapf(a, -PI, PI) if side == "E" else fposmod(a, TAU))
			rads.append(c.length())
		if angs.is_empty():
			continue
		var rt := 0.0
		for x in rads:
			rt += x
		rt /= rads.size()
		D.corridor(hub, rt - 0.95, angs.min() - 0.05, angs.max() + 0.05)
	D.draw_into(ci)


func _draw_housing_deco(ci: Node2D, r: String) -> void:
	var D = preload("res://scripts/rings_deco.gd").new()
	D.M = Geom.M
	var M := Geom.M
	var hub: Vector2 = _hub[r] / M
	var hu := Rect2()
	var hl := Rect2()
	for n in world.rooms:
		if str(n) == "H%sU" % r:
			var bb := Geom.bbox(world.rooms[n].poly)
			hu = Rect2(bb.position / M, bb.size / M)
		elif str(n) == "H%sL" % r:
			var bb := Geom.bbox(world.rooms[n].poly)
			hl = Rect2(bb.position / M, bb.size / M)
	if hu.size == Vector2.ZERO or hl.size == Vector2.ZERO:
		return
	var rad: float = maxf((hl.position.y - hu.end.y) * 0.5, 1.5)
	D.housing(hub, rad, [[Vector2(hub.x, hu.position.y), Vector2.DOWN], [Vector2(hub.x, hl.end.y), Vector2.UP]])
	D.draw_into(ci)
