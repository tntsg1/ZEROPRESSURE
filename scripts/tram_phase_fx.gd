extends Node2D
# 相位接驳 (user 2026-11-11: "你干脆把车改成‘能量子隧穿’的，从开局就可以量子隧穿，这样看起来合理一点。到时候写一个
# 提示卡展示这种现象就可以了"): the shuttle runs through the freight trains (Tram.phase_through). While a car
# of it overlaps a freight car it is drawn tunnelling in the grapple's language (scripts/tunnel_fx.gd):
# two phase-split outlines, air-blue and violet, broken into screen pixels; echoes of where it was a
# moment ago; the overlap itself dithered with |ψ|² pixels and travelling fringes; a thin halo where it
# goes in and where it comes out. The car body itself fades back while it is in (scripts/tram.gd's
# self_modulate). Only while they overlap; otherwise the car is drawn as ever. Sounds: the existing
# cues at other pitches (holo, reveal, static_arc, mirror_lock) — no synthesis.
# The first crossing the player sees opens the "相位接驳" card (scripts/guide_cards.gd, phase_shuttle).
# A child of the tram (scripts/tram.gd adds it); tests read `stats`.

const FW = preload("res://scripts/freight_works.gd")
const FArt = preload("res://scripts/freight_art.gd")
const GuideCards = preload("res://scripts/guide_cards.gd")

const ECHOES := 4             # past outlines kept
const ECHO_DT := 0.05         # s between them
const HALO_LIFE := 0.8        # s an entry / exit halo lives
const MAX_DOTS := 360         # dithered dots in the overlap, per frame
const SEE_M := 90.0           # the drone this near (or aboard): the player sees the crossing (the card)
const FADE := 0.42            # the car's own drawing, fully in

var tram
var t := 0.0
var e := 0.0                  # 0 out .. 1 in (eased)
var inside := false
var parts: Array = []         # the overlaps now: PackedVector2Array
var polys: Array = []         # the shuttle's two cars now
var hist: Array = []          # past polys
var ht := 0.0
var st := 0.0
var rings: Array = []         # {p, life, age}
var centre := Vector2.ZERO
var stats := {"inside": false, "entries": 0, "exits": 0, "halos": 0, "frames_in": 0}
static var crossings := 0     # tests: crossings of any shuttle since start


func _init() -> void:
	z_index = 9
	z_as_relative = false
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


static func rect_poly(c: Vector2, ang: float, l: float, w: float) -> PackedVector2Array:
	var xf := Transform2D(ang, c)
	var h := l * 0.5
	var k := w * 0.5
	return PackedVector2Array([xf * Vector2(-h, -k), xf * Vector2(h, -k), xf * Vector2(h, k), xf * Vector2(-h, k)])


# the freight cars near the shuttle, as outlines
func _freight_polys(near: Vector2) -> Array:
	var out: Array = []
	if not FW.on:
		return out
	var M := Geom.M
	for tr in FW.trains:
		if (tr.pos as Vector2).distance_to(near) > 22.0 * M:
			continue
		for c in FW.cars(tr):
			var wd: float = FArt.LOCO_W if str(c[3]) == "loco" else FArt.WAGON_W
			out.append(rect_poly(c[0], float(c[1]), float(c[2]) * M, wd * 0.92 * M))
	return out


func _process(dt: float) -> void:
	if tram == null or not is_instance_valid(tram) or not tram.active():
		return
	t += dt
	polys = tram.car_polys()
	parts = []
	var c := Vector2.ZERO
	if Tram.phase_through and not polys.is_empty():
		var near: Vector2 = tram.position_px
		for fp in _freight_polys(near):
			var fb := Geom.bbox(fp)
			for tp in polys:
				if not fb.intersects(Geom.bbox(tp)):
					continue
				for part in Geometry2D.intersect_polygons(tp, fp):
					if absf(Geom.area(part)) > 0.05 * Geom.M * Geom.M:
						parts.append(part)
						c += Geom.centroid(part)
	var now_in := not parts.is_empty()
	if now_in:
		centre = c / float(parts.size())
		stats.frames_in += 1
	e = move_toward(e, 1.0 if now_in else 0.0, dt * (7.0 if now_in else 2.6))
	var game = tram.game
	if now_in and not inside:
		_halo(centre)
		stats.entries += 1
		crossings += 1
		if game != null and game.get("sfx") != null:
			game.sfx.play("holo", centre, 0.7, 0.62)
			game.sfx.play("reveal", centre, 0.4, 1.55)
		_maybe_card(game)
	elif inside and not now_in:
		_halo(centre)
		stats.exits += 1
		if game != null and game.get("sfx") != null:
			game.sfx.play("mirror_lock", centre, 0.45, 1.3)
	inside = now_in
	stats.inside = now_in
	if now_in and game != null and game.get("sfx") != null:
		st -= dt
		if st <= 0.0:
			st = 0.26
			game.sfx.play("static_arc", centre, 0.1, 2.0 + randf() * 0.4)
	ht -= dt
	if ht <= 0.0:
		ht = ECHO_DT
		if e > 0.01:
			hist.push_back(polys.duplicate())
		else:
			hist.clear()
		while hist.size() > ECHOES:
			hist.pop_front()
	for r in rings:
		r.age += dt
	rings = rings.filter(func(r): return r.age < r.life)
	# the car's own drawing fades back while it is in (the tunnelling outline is the car then)
	tram.self_modulate = Color(1, 1, 1, lerpf(1.0, FADE, e))
	if e > 0.0 or not rings.is_empty() or get_meta("drawn", false):
		queue_redraw()


func _maybe_card(game) -> void:
	if game == null or not is_instance_valid(game):
		return
	var d = game.get("drone")
	var seen: bool = tram.riding or (d != null and is_instance_valid(d) and (d.global_position as Vector2).distance_to(tram.position_px) < SEE_M * Geom.M)
	if seen:
		GuideCards.note("phase_shuttle")


func _halo(p: Vector2) -> void:
	rings.append({"p": p, "life": HALO_LIFE, "age": 0.0})
	stats.halos += 1


func _hash(x: int, y: int, k: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (k * 83492791)
	return float(absi(h) % 1000) / 1000.0


# an outline broken into screen pixels (snapped to a q grid), each flickering in phase
func _quant(poly: PackedVector2Array, q: float, col: Color, off: Vector2, flick: float) -> void:
	var last := Vector2.INF
	var frame := int(t * 30.0)
	for i in poly.size():
		var a: Vector2 = poly[i] + off
		var b: Vector2 = poly[(i + 1) % poly.size()] + off
		var n := maxi(1, int(a.distance_to(b) / q))
		for k in n:
			var p := a.lerp(b, float(k) / float(n))
			var s := Vector2(floorf(p.x / q), floorf(p.y / q))
			if s == last:
				continue
			last = s
			if flick > 0.0 and _hash(int(s.x), int(s.y), frame) < flick:
				continue
			draw_rect(Rect2(s * q + Vector2(q * 0.1, q * 0.1), Vector2(q * 0.8, q * 0.8)), col)


func _draw() -> void:
	if tram == null or tram.game == null:
		return
	var game = tram.game
	var z: float = maxf(0.02, game.cam_zoom())
	set_meta("drawn", e > 0.0 or not rings.is_empty())
	var q := 4.0 / z
	var air := Pal.AIR
	var violet := Pal.VOLT
	if e > 0.01:
		var u := Vector2.from_angle(float(tram.heading))
		var perp := Vector2(-u.y, u.x)
		# echoes of where it was a moment ago, oldest faintest
		for k in hist.size():
			var age := float(hist.size() - k) / float(hist.size() + 1)
			for poly in hist[k]:
				_quant(poly, q * (1.0 + age), Pal.tint(air if k % 2 == 0 else violet, (1.0 - age) * 0.3 * e, 1.3), Vector2.ZERO, 0.35 + 0.4 * age)
		# the car: two phase-split pixel outlines that flicker
		var split := (1.6 + 1.3 * sin(t * 23.0)) / z
		for poly in polys:
			_quant(poly, q, Pal.tint(air, 0.75 * e, 1.25), perp * split, 0.16)
			_quant(poly, q, Pal.tint(violet, 0.5 * e, 1.3), -perp * split, 0.28)
		# where it is inside a freight car: fringes travelling with it and |ψ|² pixels
		var lam := 7.0 / z
		var lam2 := 7.9 / z
		var dots := 0
		for part in parts:
			var bb := Geom.bbox(part)
			var c := bb.get_center()
			var half := bb.size.length() * 0.5 + lam
			var s0 := -half
			while s0 <= half:
				var mid := c + u * s0
				var beat := (0.5 + 0.5 * cos(TAU * s0 / lam - t * 14.0)) * (0.5 + 0.5 * cos(TAU * s0 / lam2 + t * 9.0))
				if beat > 0.08:
					for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([mid - perp * half, mid + perp * half]), part):
						if seg.size() >= 2:
							draw_line(seg[0], seg[seg.size() - 1], Pal.tint(air if beat > 0.45 else Pal.INK, (0.06 + 0.3 * beat) * e, 0.9), 1.6 / z)
				s0 += lam * 0.5
			var gstep := q * 2.0
			var frame := int(t * 24.0)
			var gx := floorf(bb.position.x / gstep)
			while gx * gstep <= bb.end.x and dots < MAX_DOTS:
				var gy := floorf(bb.position.y / gstep)
				while gy * gstep <= bb.end.y and dots < MAX_DOTS:
					var p := Vector2(gx, gy) * gstep + Vector2.ONE * gstep * 0.5
					if Geometry2D.is_point_in_polygon(p, part) and _hash(int(gx), int(gy), frame) < 0.38:
						draw_rect(Rect2(p - Vector2.ONE * q * 0.4, Vector2.ONE * q * 0.8), Pal.ink(0.28 * e, 0.9))
						dots += 1
					gy += 1.0
				gx += 1.0
			_quant(part, q, Pal.ink(0.6 * e, 1.1), Vector2.ZERO, 0.1)
	# the thin halo where it went in and where it came out
	for r in rings:
		var k: float = r.age / r.life
		var rad: float = (70.0 * Pal.ease_out(k) + 3.0) / z
		var a: float = (1.0 - k) * (1.0 - k)
		draw_arc(r.p, rad, 0.0, TAU, 64, Pal.tint(air, 0.75 * a, 1.5), 1.6 / z, true)
		draw_arc(r.p, rad * 0.8, 0.0, TAU, 48, Pal.tint(violet, 0.4 * a, 1.4), 1.0 / z, true)
