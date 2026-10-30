extends Node2D
const FastDraw = preload("res://scripts/fast_draw.gd")
# 87-2: a cable cut while it was pulled tight does not just stop at the kerf. The two ends spring
# back towards what they are fixed to (the tension it held goes into them), overshoot and curl,
# and in no gravity settle as a loose, wavy tail; the stiffer and tighter the cable, the harder
# and further it whips. Simulated as a chain of points (Verlet, length constraints, the fixed end
# pinned); when it has come to rest its shape is handed to the world, which draws it from then on
# instead of the old straight stub. A tensioned member (a stay, a rod, a tether segment) snapping
# goes through the same: snap() with its centre line, both ends free to whip.

const SEG := 10.0             # px between the chain's points
const LIFE := 4.0             # s at most before a tail is frozen where it is
const DAMP := 1.6             # 1/s: what the cable's own stiffness and the air of the hull take out
const ITER := 4

var world
var ropes: Array = []         # {line, side, pts, prev, rest, pin, t, tension}


# a cut line: its two halves, each pinned at its far end. tension 0..1
func cut_line(l, a_side: PackedVector2Array, b_side: PackedVector2Array, tension: float) -> void:
	if a_side.size() >= 2:
		_spawn(l, "tail_a", a_side, [0], tension)
	if b_side.size() >= 2:
		var rev := PackedVector2Array()
		for i in range(b_side.size() - 1, -1, -1):
			rev.append(b_side[i])
		_spawn(l, "tail_b", rev, [0], tension)


# a tensioned member that snapped: both halves whip from the break, pinned where they were fixed
func snap(centre: PackedVector2Array, at: Vector2, tension: float) -> void:
	if centre.size() < 2:
		return
	var best := 0
	var bd := INF
	for i in centre.size():
		var d := centre[i].distance_to(at)
		if d < bd:
			bd = d
			best = i
	var a := PackedVector2Array()
	for i in range(0, best + 1):
		a.append(centre[i])
	var b := PackedVector2Array()
	for i in range(centre.size() - 1, best - 1, -1):
		b.append(centre[i])
	if a.size() >= 2:
		_spawn(null, "", a, [0], tension)
	if b.size() >= 2:
		_spawn(null, "", b, [0], tension)


# 87-7: a tensioned member (a stay, a rod) that snapped: its line, end to end along its length,
# whips from the break (the member itself stays where the game keeps it)
func snap_member(world_poly: PackedVector2Array, at: Vector2, tension: float) -> void:
	if world_poly.size() < 2:
		return
	var a := world_poly[0]
	var b := world_poly[1]
	var best := -1.0
	for i in world_poly.size():
		for j in range(i + 1, world_poly.size()):
			var d := world_poly[i].distance_squared_to(world_poly[j])
			if d > best:
				best = d
				a = world_poly[i]
				b = world_poly[j]
	var pts := PackedVector2Array()
	for k in 9:
		pts.append(a.lerp(b, float(k) / 8.0))
	snap(pts, at, tension)


const MAX_PTS := 16            # 60 FPS: a long cable is simulated in longer links, not more of them


func _spawn(l, side: String, path: PackedVector2Array, pins: Array, tension: float) -> void:
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	var seg := maxf(SEG, length / float(MAX_PTS - 1))
	var pts := _resample(path, seg)
	if pts.size() < 3:
		return
	var n := pts.size()
	var prev := pts.duplicate()
	# the stored tension: every point but the pinned one is flung back towards the pin, the free
	# end hardest; a little sideways kick so it curls instead of folding straight back
	var dir := (pts[0] - pts[n - 1]).normalized()
	var side_n := Vector2(-dir.y, dir.x)
	var seed := float(hash(str(path[0]) + side)) * 0.001
	for i in range(1, n):
		var f := float(i) / float(n - 1)
		var v := dir * (180.0 + 520.0 * tension) * f + side_n * sin(seed + f * 7.0) * (60.0 + 140.0 * tension) * f
		prev[i] = pts[i] - v / 60.0
	# a cable holding tension was stretched: released, it is shorter than the route it ran
	var rest := seg * (1.0 - 0.06 * tension)
	# which points are held, looked up by index in the inner loop
	var mask := PackedByteArray()
	mask.resize(n)
	for i in pins:
		if int(i) >= 0 and int(i) < n:
			mask[int(i)] = 1
	ropes.append({"line": l, "side": side, "pts": pts, "prev": prev, "rest": rest, "pins": pins, "mask": mask, "t": 0.0, "tension": tension})
	if l != null:
		l.set_meta(side + "_live", true)
	set_process(true)


func _resample(path: PackedVector2Array, seg: float = SEG) -> PackedVector2Array:
	var out := PackedVector2Array([path[0]])
	var carry := 0.0
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		var d := a.distance_to(b)
		var s := seg - carry
		while s <= d:
			out.append(a.lerp(b, s / d))
			s += seg
		carry = d - (s - seg)
	if out[out.size() - 1].distance_to(path[path.size() - 1]) > 1.0:
		out.append(path[path.size() - 1])
	return out


var cost_us := 0               # the last step's simulation (µs)

func _process(dt: float) -> void:
	if ropes.is_empty():
		set_process(false)
		return
	var t0 := Time.get_ticks_usec()
	dt = minf(dt, 1.0 / 30.0)
	var keep: Array = []
	for r in ropes:
		r.t += dt
		var pts: PackedVector2Array = r.pts
		var prev: PackedVector2Array = r.prev
		var mask: PackedByteArray = r.mask
		var rest: float = r.rest
		var k := exp(-DAMP * dt)
		var moving := 0.0
		for i in pts.size():
			if mask[i] == 1:
				continue
			var v := (pts[i] - prev[i]) * k
			prev[i] = pts[i]
			pts[i] += v
			moving = maxf(moving, v.length())
		for it in ITER:
			for i in range(1, pts.size()):
				var d := pts[i] - pts[i - 1]
				var ln := d.length()
				if ln < 0.0001:
					continue
				var err := (ln - rest) / ln
				var a_pin: bool = mask[i - 1] == 1
				var b_pin: bool = mask[i] == 1
				if a_pin and b_pin:
					continue
				if a_pin:
					pts[i] -= d * err
				elif b_pin:
					pts[i - 1] += d * err
				else:
					pts[i - 1] += d * err * 0.5
					pts[i] -= d * err * 0.5
		r.pts = pts
		r.prev = prev
		if r.t > LIFE or (r.t > 0.6 and moving < 0.05):
			_freeze(r)
		else:
			keep.append(r)
	ropes = keep
	queue_redraw()
	cost_us = Time.get_ticks_usec() - t0


func _freeze(r: Dictionary) -> void:
	var l = r.line
	if l == null:
		return
	l.remove_meta(str(r.side) + "_live")
	l.set_meta(str(r.side), r.pts)
	if world != null:
		world.redraw_near([world.pieces.get(l.a), world.pieces.get(l.b)])


func live() -> int:
	return ropes.size()


func _draw() -> void:
	for r in ropes:
		var pts: PackedVector2Array = r.pts
		var hot: float = clampf(1.0 - float(r.t) / 0.5, 0.0, 1.0) * float(r.tension)
		var pipe: bool = r.line != null and r.line.kind != "cable"
		if pipe:
			FastDraw.polyline(self, pts, Pal.ink(0.5), 4.2, false)
			FastDraw.polyline(self, pts, Color(0.05, 0.053, 0.06, 1.0), 2.0, false)
		else:
			FastDraw.polyline(self, pts, Pal.ink(0.38 + 0.4 * hot), 1.6 + hot, false)
		# the frayed end
		var e := pts[pts.size() - 1]
		FastDraw.circle(self, e, 1.6, Pal.heat(0.4 + 0.5 * hot, 1.2 + hot))
