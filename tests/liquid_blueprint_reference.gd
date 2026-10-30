extends RefCounted
# Frozen pre-optimization routines used only for visual and merge equivalence.

class Liquid extends "res://scripts/liquids.gd":
	func _merge() -> void:
		var cell := 1.2 * Geom.M
		var grid := {}
		for i in blobs.size():
			var b = blobs[i]
			var key := Vector2i(int(floor(b.pos.x / cell)), int(floor(b.pos.y / cell)))
			if not grid.has(key):
				grid[key] = []
			grid[key].append(i)
		var gone := {}
		for key in grid:
			for i in grid[key]:
				if gone.has(i):
					continue
				var a = blobs[i]
				for dx in [-1, 0, 1]:
					for dy in [-1, 0, 1]:
						for j in grid.get(key + Vector2i(dx, dy), []):
							if j <= i or gone.has(j):
								continue
							var c = blobs[j]
							if c.look != a.look or a.ice or c.ice or float(a.t) < 0.5 or float(c.t) < 0.5:
								continue
							var rr: float = (radius_m(a.vol) + radius_m(c.vol)) * Geom.M * RHO_GAP
							var d: Vector2 = c.pos - a.pos
							if d.length() > rr:
								continue
							# they coalesce when they come together gently (or one already lies on a
							# surface); a fast glancing pass just goes by
							var rel: Vector2 = c.vel - a.vel
							if int(a.stuck) < 0 and int(c.stuck) < 0:
								# flying apart (the pieces of a burst), or a fast pass: no
								var parting: bool = rel.dot(d) > 0.0 and rel.length() > 0.15 * Geom.M
								if parting or rel.length() > 1.2 * Geom.M:
									continue
							var m: float = float(a.vol) + float(c.vol)
							if int(a.stuck) < 0 and int(c.stuck) < 0:
								a.vel = (a.vel * float(a.vol) + c.vel * float(c.vol)) / m
							a.pos = (a.pos * float(a.vol) + c.pos * float(c.vol)) / m
							if int(c.stuck) >= 0 and int(a.stuck) < 0:
								a.stuck = c.stuck
								a.loc = c.loc
								a.nrm = c.nrm
							a.vol = m
							a.t = minf(float(a.t), float(c.t))
							a.quiet = a.quiet and c.quiet
							a.ph = float(a.ph) + 1.3
							gone[j] = true
		if gone.is_empty():
			return
		var keep: Array = []
		for i in blobs.size():
			if not gone.has(i):
				keep.append(blobs[i])
		blobs = keep


	func _draw() -> void:
		for f in frost:
			var a: float = 0.45 * (1.0 - float(f[1]) / 24.0)
			var c: Vector2 = f[0]
			var sz: float = float(f[2])
			for k in 6:
				var d := Vector2.from_angle(k * TAU / 6.0 + float(c.x) * 0.1)
				draw_line(c + d * sz * 0.2, c + d * sz, Pal.ink(a), 1.0, false)
				draw_line(c + d * sz * 0.6, c + d * sz * 0.6 + d.rotated(0.8) * sz * 0.25, Pal.ink(a * 0.7), 1.0, false)
		for j in jets:
			_draw_jet(j)
		for b in blobs:
			_draw_blob(b)


	func _draw_jet(j: Array) -> void:
		var at: Vector2 = j[0]
		var dir: Vector2 = j[1]
		var flow: float = float(j[2])
		var look: String = j[3]
		var cryo: bool = look in CRYO
		var len_px: float = clampf(0.3 + flow * 12.0, 0.3, 1.4) * Geom.M
		var w0: float = clampf(1.5 + flow * 40.0, 1.5, 5.0)
		var nrm := Vector2(-dir.y, dir.x)
		var col := Pal.tint(Pal.FLUID, 0.85, 1.4 if cryo else 1.1)
		var n := 10
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		for k in n + 1:
			var f: float = float(k) / n
			# the neck: waves along it growing until it breaks
			var wv: float = w0 * (1.0 - f * 0.55) * (1.0 + 0.35 * f * sin(f * 18.0 - _t * 22.0))
			var c: Vector2 = at + dir * len_px * f
			left.append(c + nrm * wv * 0.5)
			right.append(c - nrm * wv * 0.5)
		draw_polyline(left, col, 1.0, false)
		draw_polyline(right, col, 1.0, false)
		# the drops just pinched off its end
		for k in 3:
			var f2: float = 1.08 + k * 0.1 + fposmod(_t * 3.0, 0.1)
			draw_arc(at + dir * len_px * f2, w0 * 0.45, 0.0, TAU, 8, col, 1.0, false)
		if cryo:
			for k in 3:
				var f3: float = fposmod(_t * 1.5 + k * 0.33, 1.0)
				draw_arc(at + dir * len_px * f3 * 1.4 + nrm * sin(f3 * 9.0 + k) * 6.0, 3.0 + f3 * 10.0, 0.0, TAU, 10, Pal.ink(0.12 * (1.0 - f3)), 1.0, false)


	func _draw_blob(b: Dictionary) -> void:
		var r: float = maxf(1.6, radius_m(b.vol) * Geom.M)
		var c: Vector2 = b.pos
		var look: String = b.look
		var col := Pal.tint(Pal.FLUID, 0.75, 1.2)
		var w := 1.2
		match look:
			"lhe", "lh2", "lng", "ln2":
				col = Pal.tint(Pal.FLUID, 0.95, 1.6)
				w = 0.9
			"fuel", "mmh":
				col = Pal.tint(Pal.FLUID, 0.8, 1.0)
				w = 1.8
			"nto":
				# nitrogen tetroxide: yellow-orange liquid
				col = Color(0.95, 0.6, 0.28, 0.9)
				w = 1.6
			"mud":
				col = Pal.ink(0.35)
				w = 1.4
		if b.ice:
			# a ball of ice: faceted, still
			var pts := PackedVector2Array()
			for k in 7:
				var a: float = k * TAU / 7.0 + float(b.ph)
				pts.append(c + Vector2.from_angle(a) * r * (0.9 + 0.12 * sin(a * 3.0 + float(b.ph))))
			pts.append(pts[0])
			draw_polyline(pts, Pal.ink(0.7), 1.1, false)
			draw_line(pts[0], pts[3], Pal.ink(0.25), 1.0, false)
			draw_line(pts[1], pts[5], Pal.ink(0.2), 1.0, false)
			return
		var stuck: bool = int(b.stuck) >= 0
		var n := 10 if r < 4.0 else (16 if r < 10.0 else 24)
		# surface-tension wobble: the fundamental modes, slower and larger for a big globule
		var amp: float = 0.0 if r < 2.5 else clampf(0.02 + r * 0.004, 0.0, 0.12) * exp(-float(b.t) * 0.15) + (0.03 if r > 6.0 else 0.0)
		var freq: float = 9.0 / sqrt(maxf(r, 1.0))
		if look == "mud":
			amp *= 0.3
		var pts2 := PackedVector2Array()
		var t_ax := Vector2.ZERO
		if stuck:
			t_ax = Vector2(-b.nrm.y, b.nrm.x)
		for k in n + 1:
			var a2: float = k * TAU / n
			var rr: float = r * (1.0 + amp * sin(2.0 * a2 + _t * freq + float(b.ph)) + amp * 0.5 * sin(3.0 * a2 - _t * freq * 1.4 + float(b.ph) * 2.0))
			var off: Vector2 = Vector2.from_angle(a2) * rr
			if stuck:
				# wetted on: spread flat along the surface
				var along: float = off.dot(t_ax)
				var out: float = off.dot(b.nrm)
				off = t_ax * along * 1.5 + b.nrm * (out * 0.45 + r * 0.1)
			pts2.append(c + off)
		# its body, faintly filled (the outline closes on itself; the fill must not repeat a point)
		var body: PackedVector2Array = pts2.slice(0, n)
		if r > 2.5 and not Geometry2D.triangulate_polygon(body).is_empty():
			draw_colored_polygon(body, Pal.ink(0.12) if look == "mud" else Color(col.r, col.g, col.b, 0.07))
		draw_polyline(pts2, col, w, false)
		if r < 3.0:
			return
		match look:
			"water", "glycol":
				# the highlight the light makes on a clear sphere
				draw_arc(c + Vector2(-r * 0.28, -r * 0.28), r * 0.42, PI * 1.05, PI * 1.55, 6, Pal.ink(0.55), 1.0, false)
				if look == "glycol":
					draw_arc(c, r * 0.78, 0.0, TAU, n, Color(col.r, col.g, col.b, 0.3), 1.0, false)
			"fuel", "mmh", "nto":
				# the oily film swirling inside
				var sw: float = _t * 0.8 + float(b.ph)
				draw_arc(c, r * 0.55, sw, sw + 2.2, 8, Color(col.r, col.g, col.b, 0.5), 1.0, false)
				draw_arc(c, r * 0.3, -sw * 1.3, -sw * 1.3 + 1.8, 6, Color(col.r, col.g, col.b, 0.35), 1.0, false)
				draw_arc(c + Vector2(-r * 0.3, -r * 0.3), r * 0.35, PI * 1.1, PI * 1.5, 5, Pal.ink(0.4), 1.0, false)
			"lhe", "lh2", "lng", "ln2":
				# boiling: vapour bubbles nucleating inside and rising out of it
				for k in 3:
					var bp: Vector2 = c + Vector2.from_angle(float(b.ph) * 3.0 + k * 2.1 + _t * 2.0) * r * fposmod(_t * 0.9 + k * 0.33, 1.0) * 0.8
					draw_arc(bp, maxf(0.8, r * 0.12), 0.0, TAU, 6, Pal.ink(0.5), 1.0, false)
			"mud":
				for k in mini(8, int(r * 0.6)):
					var gp: Vector2 = c + Vector2.from_angle(k * 2.4 + float(b.ph)) * r * fposmod(k * 0.37, 0.8)
					draw_rect(Rect2(gp, Vector2(1.4, 1.4)), Pal.ink(0.5))


class Drawing extends Blueprint:
	func _dpoly(poly: PackedVector2Array, c: Color, w: float) -> void:
		if not _poly_dashes.has(poly):
			var points := PackedVector2Array()
			for i in poly.size():
				_dash_points(points, poly[i], poly[(i + 1) % poly.size()])
			_poly_dashes[poly] = points
		var points: PackedVector2Array = _poly_dashes[poly]
		if not points.is_empty():
			draw_multiline(points, c, w)


	func _dpath(path: PackedVector2Array, c: Color, w: float) -> void:
		if not _path_dashes.has(path):
			var points := PackedVector2Array()
			for i in path.size() - 1:
				_dash_points(points, path[i], path[i + 1], 5.0)
			_path_dashes[path] = points
		var points: PackedVector2Array = _path_dashes[path]
		if not points.is_empty():
			draw_multiline(points, c, w)


	func _label_occupied(r: Rect2) -> bool:
		for placed in _placed:
			if placed.intersects(r): return true
		return false


	func _remember_label(r: Rect2) -> void:
		_placed.append(r)


	func _point_label(at: Vector2, text: String, col: Color) -> void:
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 6.0
		var base := at * _z
		for off in [Vector2(8, -7), Vector2(8, 19), Vector2(8, -25), Vector2(8, 37), Vector2(-w - 8, -7), Vector2(-w - 8, 19)]:
			var r := Rect2(base + off + Vector2(-3, -14), Vector2(w, 18))
			if not _label_occupied(r):
				_remember_label(r)
				_label(at, text, 14, col, off)
				return
		_label(at, text, 14, col, Vector2(8, -7))


	func _label(at: Vector2, text: String, size_px: int, col: Color, off: Vector2 = Vector2(4, -4)) -> void:
		if text == "":
			return
		draw_set_transform(at, 0.0, Vector2.ONE / _z)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		draw_rect(Rect2(off + Vector2(-3, -size_px * 0.95), Vector2(w + 6, size_px * 1.25)), Color(0.02, 0.03, 0.05, 0.72 * k))
		draw_string(font, off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


	func _draw() -> void:
		if k < 0.01:
			return
		var z: float = game.cam_zoom()
		_z = z
		_placed = []
		var lw := 1.1 / z
		var a := k
		var col := Color(0.62, 0.86, 1.0, 0.75 * a)
		var dim := Color(0.62, 0.86, 1.0, 0.35 * a)
		# sweep: the drawing draws itself from bow to stern
		var sweep := x0 + Pal.ease_out(k) * (x1 - x0)
		draw_rect(Rect2(x0, -6.0 * 48.0, minf(sweep - x0, x1 - x0), 12.0 * 48.0), Color(0.02, 0.03, 0.05, 0.55 * a))
		for r in rooms:
			_dpoly(r[0], col, lw * 1.3)
			_label(r[2], game.txt(r[1]), 17, col, Vector2.ZERO)
		for e in equip:
			if Geom.bbox(e[0]).position.x > sweep:
				continue
			_dpoly(e[0], dim, lw)
			_label(Geom.bbox(e[0]).position, e[1], 13, Color(0.62, 0.86, 1.0, 0.6 * a))
		for r in runs:
			var path: PackedVector2Array = r[0]
			if path.is_empty() or path[0].x > sweep:
				continue
			_dpath(path, Color(0.62, 0.86, 1.0, (0.55 if r[2] == "pipe" else 0.4) * a), lw * (1.6 if r[2] == "pipe" else 1.0))
			if r[1] != "":
				_label(path[path.size() / 2], r[1], 12, Color(0.62, 0.86, 1.0, 0.55 * a))
		for p in points:
			var pos: Vector2 = p[0]
			if pos.x > sweep:
				continue
			var s := 5.0 / z
			match p[2]:
				"valve":
					draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -s), pos + Vector2(s, 0), pos + Vector2(0, s), pos + Vector2(-s, 0)]), col)
				"port", "test", "discharge", "socket", "probe", "degauss", "seal":
					draw_arc(pos, s, 0.0, TAU, 14, col, lw * 1.4, true)
				"clamp":
					draw_rect(Rect2(pos - Vector2(s, 0), Vector2(s * 2, s)), dim, false, lw)
				_:
					draw_rect(Rect2(pos - Vector2(s, s) * 0.7, Vector2(s, s) * 1.4), col, false, lw)
			if p[1] != "":
				_point_label(pos, p[1], Color(0.62, 0.86, 1.0, 0.9 * a))
		_label(Vector2(x0 + 2.0 * 48.0, y_top - 1.2 * 48.0), game.ship.get("name", "") + "  ·  " + game.txt("blueprint"), 18, col, Vector2.ZERO)
		if has_notes():
			_draw_notes(lw, a)


