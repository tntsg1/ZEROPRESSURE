extends Node2D
# MD-160's flywheels seen turning — drawing only, scripts/flywheel.gd keeps every number
# (design/机制动画缺口_20261110.md: "20,000 rpm and the wheel stands still").
#   Each wheel still on the ship is out of the strips (world.live) and drawn here turned to
#   its angle: at speed a blur of streaks round it and its spokes smeared, slowing visibly
#   as the brake takes the rpm off, standing still when it has stopped. The brake on it:
#   dry, sparks thrown off the rim at the pads and the caliper glowing hotter as it goes
#   toward burning out; cooled, the coolant flashing to vapour where the pads bite.

const VIS_MAX := 7.5          # rad/s shown at full speed (anything faster only strobes)

var fw
var game
var world
var glow: Node2D
var _ang := {}
var _w := {}
var _t := 0.0
var _emit := {}
var _ids := {}


func setup(f) -> void:
	fw = f
	game = f.game
	world = f.world
	z_index = 1
	z_as_relative = false
	world.add_child(self)
	world.move_child(self, world.piece_layer.get_index() + 1)
	glow = Node2D.new()
	glow.z_index = 4
	glow.z_as_relative = false
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = m
	glow.draw.connect(_draw_glow)
	world.add_child(glow)
	for w in fw.cfg.get("wheels", {}):
		_ang[w] = float(hash(w) % 628) * 0.01
		_w[w] = 0.0


func _wheel(w: String):
	var p = world.tag(w)
	return p if p != null and not p.gone and p.body == null and not fw.loose.has(w) else null


# rad/s shown: the real speed while it can be followed, a fast blur above that
func _vis(w: String) -> float:
	var rpm: float = float(fw.rpm.get(w, 0.0))
	var real := rpm * TAU / 60.0
	return minf(real, 0.25 + (VIS_MAX - 0.25) * sqrt(clampf(rpm / 20000.0, 0.0, 1.0))) if rpm > 0.01 else 0.0


func _braked(w: String) -> bool:
	var e: Dictionary = fw.cfg.wheels[w]
	return game.sys.on(str(e.get("brake", ""))) and not fw.burnt.has(w) and float(fw.rpm.get(w, 0.0)) > 0.0


# where the pads bite: the rim nearest the caliper
func _bite(w: String, p) -> Array:
	var c := Geom.centroid(p.poly)
	var r := Geom.bbox(p.poly).size.x * 0.5
	var cal = world.tag(str(fw.cfg.wheels[w].get("caliper", "")))
	var to := Vector2.UP
	if cal != null and not cal.gone:
		to = (world.frame(cal) * Geom.centroid(cal.poly) - c).normalized()
	return [c + to * r * 0.97, to, c, r]


func _process(dt: float) -> void:
	if fw == null or not fw.active() or game == null:
		return
	if game.paused_sim or game.state != "play":
		queue_redraw()
		glow.queue_redraw()
		return
	_t += dt
	for w in fw.cfg.wheels:
		if fw.loose.has(w):
			_w[w] = Pal.damp(float(_w[w]), _vis(w), 4.0, dt)
			_ang[w] = fposmod(float(_ang[w]) + float(_w[w]) * dt, TAU)
		var p = _wheel(w)
		if p == null:
			if _ids.has(w):
				world.live.erase(_ids[w])
				var q = world.pieces.get(_ids[w])
				if q != null and not q.gone:
					world.redraw_near([q])
				_ids.erase(w)
			continue
		if not world.live.has(p.id):
			world.live[p.id] = true
			_ids[w] = p.id
			world.redraw_near([p])
		_w[w] = Pal.damp(float(_w[w]), _vis(w), 4.0, dt)
		_ang[w] = fposmod(float(_ang[w]) + float(_w[w]) * dt, TAU)
		if _braked(w):
			var b := _bite(w, p)
			var tang: Vector2 = (b[1] as Vector2).orthogonal()
			var k := clampf(float(fw.rpm[w]) / 20000.0, 0.0, 1.0)
			var cooled: bool = game.sys.on(str(fw.cfg.wheels[w].get("cool", "")))
			_emit[w] = float(_emit.get(w, 0.0)) + dt
			if cooled and float(_emit[w]) > 0.12:
				_emit[w] = 0.0
				game.fx.puff(b[0] + tang * 6.0, (tang * 40.0 + (b[1] as Vector2) * 30.0) * (0.4 + k), 1.2, 6.0, 26.0 + 20.0 * k, Pal.ink(0.22))
			elif not cooled and float(_emit[w]) > 0.05:
				_emit[w] = 0.0
				game.fx.sparks(b[0], tang, 3 + int(5.0 * k), Pal.heat(1.0, 2.2), 120.0 + 520.0 * sqrt(k), 0.45, 0.35)
	queue_redraw()
	glow.queue_redraw()


func _draw() -> void:
	if fw == null or not fw.active():
		return
	# a wheel torn loose still turns inside its housing (magnetic bearings, a vacuum: it coasts
	# for days); the housing tumbles slowly with the body, the wheel's blur keeps its own speed
	for w in fw.cfg.wheels:
		if not fw.loose.has(w):
			continue
		var q = world.tag(w)
		if q == null or q.gone or q.body == null or float(fw.rpm.get(w, 0.0)) <= 0.01:
			continue
		var qxf: Transform2D = world.frame(q)
		var qc: Vector2 = qxf * Geom.centroid(q.poly)
		var qb := Geom.bbox(q.poly)
		var qr: float = minf(qb.size.x, qb.size.y) * 0.46
		var qs: float = clampf(float(_w.get(w, 0.0)) / VIS_MAX, 0.0, 1.0)
		for k in 7:
			var rr := qr * (0.32 + 0.1 * k)
			var a0 := float(_ang[w]) + k * 0.93
			var L := 0.12 + 1.5 * qs
			for m in 2:
				var aa := a0 + m * PI
				draw_arc(qc, rr, aa - L, aa, 14, Pal.ink((0.06 + 0.22 * qs) * (1.0 - k * 0.06)), 1.2)
		draw_arc(qc, qr * 0.985, 0.0, TAU, 48, Pal.ink(0.08 + 0.2 * qs), 1.0)
	for w in fw.cfg.wheels:
		var p = _wheel(w)
		if p == null or not world.live.has(p.id):
			continue
		var c := Geom.centroid(p.poly)
		var r := Geom.bbox(p.poly).size.x * 0.5
		var spd: float = float(_w[w]) / VIS_MAX
		# the vacuum housing stays put on the ship; only the wheel drawn inside it turns to its
		# angle (user 2026-11-10: "它整个方形也在转" — the housing's fill and outline used to be
		# turned with it)
		_draw_wheel(p, c, float(_ang[w]))
		# at speed: streaks round it (the eye can't follow its spokes, only their blur)
		if spd > 0.02:
			for k in 7:
				var rr := r * (0.32 + 0.1 * k)
				var a0 := float(_ang[w]) + k * 0.93
				var L := 0.12 + 1.5 * spd
				for m in 2:
					var aa := a0 + m * PI
					draw_arc(c, rr, aa - L, aa, 14, Pal.ink((0.06 + 0.22 * spd) * (1.0 - k * 0.06)), 1.2)
			# the hum: a bright band on the rim
			draw_arc(c, r * 0.985, 0.0, TAU, 48, Pal.ink(0.08 + 0.2 * spd), 1.0)


# the housing drawn still (its ground and outline, and in the cutaway look its material's
# shading), the wheel's own drawing turned to its angle between them. Not world.draw_pieces
# with "art" under a turn: in the cutaway look that part carries the housing's shading and
# outline too, so the square would turn with the wheel.
func _draw_wheel(p, c: Vector2, ang: float) -> void:
	world.draw_pieces(self, [p], "fill")
	world.draw_pieces(self, [p], "line")
	if p.art != "":
		draw_set_transform_matrix(Transform2D(ang, c) * Transform2D(0.0, -c))
		Art.EQ.batch_begin()
		Art.EQ.bxf = p.art_xf
		Art.draw(self, p.art, p.art_size, p, world.font)
		Art.EQ.bxf = Transform2D.IDENTITY
		Art.EQ.batch_end(self)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		if Pal.solid:
			Art.EQ.batch_begin()
			Cutaway._volume(world, p, p.poly, str(Cutaway.style(world, p)[4]))
			Art.EQ.batch_end(self)
	var ol: PackedVector2Array = p.poly.duplicate()
	if ol.size() > 2:
		ol.append(ol[0])
		draw_polyline(ol, Pal.ink(0.62), 1.5, true)


func _draw_glow() -> void:
	if fw == null or not fw.active():
		return
	for w in fw.cfg.wheels:
		var p = _wheel(w)
		if p == null:
			continue
		var cal = world.tag(str(fw.cfg.wheels[w].get("caliper", "")))
		if cal == null or cal.gone:
			continue
		var cc: Vector2 = world.frame(cal) * Geom.centroid(cal.poly)
		var dry: float = clampf(float(fw._dry.get(w, 0.0)) / float(fw.cfg.get("burn", 8.0)), 0.0, 1.0)
		var b := _bite(w, p)
		if _braked(w):
			var k := clampf(float(fw.rpm[w]) / 20000.0, 0.0, 1.0)
			var cooled: bool = game.sys.on(str(fw.cfg.wheels[w].get("cool", "")))
			# the pads on the rim: a hot line where they bite
			var ang: float = (b[1] as Vector2).angle()
			var hot := Pal.heat(0.35 + 0.5 * (0.0 if cooled else 1.0) * (0.4 + 0.6 * k), 1.6) if not cooled else Pal.tint(Pal.AIR, 0.35, 1.2)
			draw_arc_on(glow, b[2], float(b[3]) * 0.97, ang - 0.09, ang + 0.09, hot, 3.0)
		if dry > 0.01:
			# the caliper heating up as it takes the brake dry, red to yellow
			var flick := 0.9 + 0.1 * sin(_t * 13.0 + cc.x)
			_disc(glow, cc, (0.9 + 1.4 * dry) * Geom.M, Pal.heat((0.12 + 0.5 * dry) * flick, 1.0 + 1.2 * dry))
		if fw.burnt.has(w):
			_disc(glow, cc, 0.7 * Geom.M, Pal.heat(0.12 + 0.06 * sin(_t * 3.0), 0.8))


static func draw_arc_on(ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float, col: Color, wd: float) -> void:
	ci.draw_arc(c, r, a0, a1, 8, col, wd)


# a soft disc of light, bright at its middle
static func _disc(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var n := 20
	var pts := PackedVector2Array([c])
	var cols := PackedColorArray([col])
	var idx := PackedInt32Array()
	for k in n:
		pts.append(c + Vector2.from_angle(TAU * k / n) * r)
		cols.append(Color(col.r, col.g, col.b, 0.0))
	for k in n:
		idx.append_array([0, 1 + k, 1 + (k + 1) % n])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)
