extends Node2D
# IH-55's bags seen letting down — drawing only, scripts/softshell.gd keeps every number
# (design/机制动画缺口_20261110.md: "the bag was full, then it was flat").
#   While a bag is drawn down its film slackens: creases come up across it, deeper the lower
#   its pressure. When it folds (under "flat") it is seen going: the outline sinks onto the
#   spine over a second and a half, the film overshooting a little and settling; a ripped
#   bag comes down in a third of a second, its torn film flapping. Then it is the folded
#   piece the ship holds, drawn in the strips as before.

const FOLD_S := 1.4
const RIP_S := 0.35
const N := 96                  # points round the outline while it moves

var ss
var game
var world
var _poly0 := {}               # bag -> its full outline, resampled (px)
var _p0 := {}                  # bag -> the pressure it was blown up to
var _anim := {}                # bag -> {t, dur, from, rip}
var _was_folded := {}
var _ids := {}
var _t := 0.0


func setup(s) -> void:
	ss = s
	game = s.game
	world = s.world
	z_index = 1
	z_as_relative = false
	world.add_child(self)
	world.move_child(self, world.piece_layer.get_index() + 1)
	for b in ss.cfg.get("bags", {}):
		var p = world.tag(b)
		if p != null and not p.gone:
			_poly0[b] = _resample(p.poly)


static func _resample(poly: PackedVector2Array) -> PackedVector2Array:
	var n := poly.size()
	var L := 0.0
	for i in n:
		L += poly[i].distance_to(poly[(i + 1) % n])
	var out := PackedVector2Array()
	var step := L / N
	var i := 0
	var acc := 0.0
	var at := poly[0]
	out.append(at)
	while out.size() < N:
		var nx := poly[(i + 1) % n]
		var d := at.distance_to(nx)
		if acc + d >= step:
			at = at.lerp(nx, (step - acc) / maxf(d, 0.0001))
			out.append(at)
			acc = 0.0
		else:
			acc += d
			at = nx
			i += 1
			if i > n * 2:
				break
	return out


# where a point of the full bag lies once it is folded down onto the spine (softshell.gd _fold)
func _fold_of(b: String, v: Vector2) -> Vector2:
	var bb := Geom.bbox(_poly0[b])
	var side: float = float(ss.cfg.bags[b].get("side", -1))
	var edge: float = bb.end.y if side < 0.0 else bb.position.y
	var x0 := bb.position.x + bb.size.x * 0.1
	var x1 := bb.end.x - bb.size.x * 0.1
	var x := clampf(v.x, x0, x1)
	var f := (x - x0) / maxf(1.0, x1 - x0)
	return Vector2(x, edge + side * 1.4 * Geom.M * sin(PI * f) * (0.4 + 0.6 * absf(v.y - edge) / maxf(1.0, bb.size.y)))


func _process(dt: float) -> void:
	if ss == null or not ss.active() or game == null:
		return
	if game.paused_sim or game.state != "play":
		queue_redraw()
		return
	_t += dt
	for b in ss.cfg.bags:
		var p = world.tag(b)
		var e: Dictionary = ss.cfg.bags[b]
		if not _p0.has(b):
			_p0[b] = maxf(float(ss.cfg.get("flat", 3.0)) * 2.0, game.sys.P(str(e.get("vessel", ""))))
		var now: bool = ss.folded.has(b)
		if now and not _was_folded.get(b, true if not _poly0.has(b) else false) and _poly0.has(b) and p != null and not p.gone and p.body == null:
			_anim[b] = {"t": 0.0, "dur": RIP_S if ss.ripped.has(b) else FOLD_S, "rip": ss.ripped.has(b)}
			world.live[p.id] = true
			_ids[b] = p.id
			world.redraw_near([p])
		_was_folded[b] = now
	for b in _anim.keys():
		var a: Dictionary = _anim[b]
		a.t = float(a.t) + dt
		if float(a.t) >= float(a.dur):
			_anim.erase(b)
			if _ids.has(b):
				world.live.erase(_ids[b])
				var q = world.pieces.get(_ids[b])
				if q != null and not q.gone:
					world.redraw_near([q])
				_ids.erase(b)
	queue_redraw()


func _draw() -> void:
	if ss == null or not ss.active():
		return
	for b in ss.cfg.bags:
		var p = world.tag(b)
		if p == null or p.gone or p.body != null or not _poly0.has(b):
			continue
		var poly0: PackedVector2Array = _poly0[b]
		var st: Array = world._style(p)
		if _anim.has(b):
			var a: Dictionary = _anim[b]
			var u := clampf(float(a.t) / float(a.dur), 0.0, 1.0)
			# sinking onto the spine, overshooting a little and settling (a rip: straight down)
			var k := Pal.ease_in(u) if a.rip else Pal.ease_io(u) + 0.07 * sin(PI * clampf((u - 0.62) / 0.38, 0.0, 1.0))
			var pts := PackedVector2Array()
			for i in poly0.size():
				var v := poly0[i]
				var f := _fold_of(b, v)
				var wob := sin(i * 0.9 + _t * 22.0) * 6.0 * (1.0 - u) * (1.0 if a.rip else 0.3)
				pts.append(v.lerp(f, k) + Vector2(0.0, wob))
			var tri := Geometry2D.triangulate_polygon(pts)
			if not tri.is_empty():
				var cols := PackedColorArray()
				cols.resize(pts.size())
				cols.fill(st[0])
				RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), tri, pts, cols)
			pts.append(pts[0])
			draw_polyline(pts, st[1], 1.3)
			# the film's creases running across it as it comes down
			_creases(b, pts, 0.35 + 0.5 * (1.0 - u), u)
			continue
		if ss.folded.has(b):
			continue
		# still up: slackening as it is drawn down
		var P: float = game.sys.P(str(ss.cfg.bags[b].get("vessel", "")))
		var slack := clampf(1.0 - P / maxf(0.001, float(_p0.get(b, P))), 0.0, 1.0)
		if slack > 0.04:
			_creases(b, poly0, 0.12 + 0.5 * slack, slack)


# creases across a bag going soft: lines curving across the film, the shadow of each fold
func _creases(b: String, poly: PackedVector2Array, a: float, slack: float) -> void:
	var bb := Geom.bbox(poly)
	if bb.size.x < 4.0 or bb.size.y < 4.0:
		return
	var n := 7
	var segs := PackedVector2Array()
	for i in n:
		var x := bb.position.x + bb.size.x * (float(i) + 0.5 + 0.18 * sin(i * 2.1)) / n
		var line := PackedVector2Array()
		for m in 9:
			var f := float(m) / 8.0
			line.append(Vector2(x + sin(f * PI * 2.0 + i) * bb.size.x * 0.03 * (0.5 + slack), lerpf(bb.position.y - 2.0, bb.end.y + 2.0, f)))
		for seg in Geometry2D.clip_polyline_with_polygon(line, poly):
			for k in range(1, seg.size()):
				segs.append(seg[k - 1])
				segs.append(seg[k])
	if not segs.is_empty():
		draw_multiline(segs, Pal.ink(clampf(a, 0.0, 1.0) * 0.45), 1.0)
