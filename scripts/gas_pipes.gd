extends Node2D
# The pipelines that feed the gas line across the port (2026-11-11, user: "我在拆船厂拆船收集的气体，
# 存进罐子后，会通过管道流到加工区……这样就能让玩家知道这个液体处理是干啥的"). Drawing and a film:
# the numbers are scripts/gas_line.gd's (a ship's batch "transit" along the pipe, 30 s) and
# scripts/power_supply.gd's (the cryo tug filling, drawing on the warehouse's LH2 / LOX tanks).
#   The gas run: the berth's recovery receiver (between the dock and the parts store) up the
#   rack outside the hub's rail, west along it, up the processing district's far side into the
#   gas bay's receiving coupling (scripts/gas_plant.gd). A batch on its way is a slug of grey-white
#   gas moving along it at the pace the data gives, a flow readout riding with it.
#   The cryo run (Jev A 0.91: as the data has it — the LH2 / LOX tanks salvaged off ships are goods
#   in the cargo district's warehouse; the tug draws on them at the processing district's roof
#   stand): the warehouse's transfer skid, across the berth bridge on a pipe bridge, alongside the
#   gas rack, up past the gas bay to the stand. It runs only while the tug fills there: LH2 all but
#   colourless with a cold mist, LOX pale blue.
#   The film: the first time a batch is piped, ~11 s the camera follows it from the receiver to
#   the plant, the tanks and the stand, with a line of where it goes; any key or click ends it.
#   It plays once; "看流程" on the gas bay's readout board plays it again.
# Port metres (PortStructure.centre() the origin, y down); the still parts are one mesh.

const MeshPen = preload("res://scripts/mesh_pen.gd")
const LC = preload("res://scripts/liquid_colors.gd")
const PS = preload("res://scripts/power_supply.gd")

# cutaway pipe material (scripts/cutaway.gd MATS.pipe): body, lit edge, rim
const BODY := Color(0.12, 0.124, 0.132)
const LIT := Color(0.33, 0.338, 0.355)
const RIM := Color(0.035, 0.036, 0.04)
const STEEL := Color(0.09, 0.094, 0.104)
const FACE := Color(0.118, 0.124, 0.136)
const FACE2 := Color(0.15, 0.158, 0.172)
const VOID := Color(0.025, 0.027, 0.031)
const LIGHT := Vector2(-0.45, -0.89)          # Look.LIGHT_DIR

# the berth's gas recovery receiver (user 2026-11-11: "它难道不应该是在底下吗？", then "它没有随着我舱室的
# 变大而变大"): it belongs to the berth, not the port. Outside the berth's left tower (the end that never
# moves: the berth grows to the right and the port slides over it), standing on the salvage district's quay
# truss (its top 3 m under the floor, scripts/port_art.gd _salvage, where the parts store stands too) in the
# gap between the parts store (its right wall 18 m left of the berth's origin) and the tower; the hoses'
# recovery header comes out through the tower's foot. Its riser climbs outside the tower to over the boom,
# runs along the boom's top to the port's fixed run (G_TAIL) and on up. Laid out again whenever the berth
# changes (its length, its lift / drop, the port over it): _layout().
# Bigger berths, bigger receivers (by the longest berth paid for, so it never changes size while the berth
# folds out or back): up to 88 m one drum, the 120 m berth a big one, 200 m and on two big ones, stacked
# on a frame (the gap is only so wide).
const RECV_SIZE := [Vector2(6.0, 3.0), Vector2(7.0, 4.0)]
const G_TAIL := [Vector2(-35.3, 45.0), Vector2(-168.0, 45.0), Vector2(-168.0, 11.0), Vector2(-164.9, 11.0)]
const RECV_OUT := 2.4          # m: the drum's end clear of the tower's outer face
const QUAY_DOWN := 3.0         # m: the quay truss's top under the berth's floor (port_art _salvage)
const STORE_X1 := -18.0        # m: the parts store's right wall (port_art _salvage)
const OVER_BOOM := 2.5         # m: the run along the boom's top, over the berth's top
const SKID := Rect2(40.6, 64.6, 6.0, 3.4)     # the warehouse's cryo transfer skid, hung under the cargo district
const C_PATH := [Vector2(43.6, 68.0), Vector2(43.6, 70.0), Vector2(-37.8, 70.0), Vector2(-37.8, 47.4), Vector2(-170.6, 47.4), Vector2(-170.6, -24.0), Vector2(-123.1, -24.0), Vector2(-123.1, -15.8)]
# 2026-11-11 (user: "要，按我说的改"): the tug station's cryo collection tanks, hung under its floor
# over the processing district's roof, and their two runs to the gas bay's LH2 and LOX tanks
const TUG_LH2 := Rect2(-110.0, -24.25, 10.0, 3.3)
const TUG_LOX := Rect2(-110.0, -21.2, 7.5, 3.2)
const L_PATH := [Vector2(-110.0, -22.6), Vector2(-146.5, -22.6), Vector2(-146.5, -6.4)]
const X_PATH := [Vector2(-110.0, -19.6), Vector2(-130.8, -19.6), Vector2(-130.8, -9.0)]
const G_W := 0.8
const C_W := 0.9
const FILM_S := 13.5
const TF = preload("res://scripts/tank_fill_fx.gd")
const BTN := Rect2(-145.35, -8.5, 2.6, 0.9)   # "看流程" just under the gas bay's readout board

var game
var font: Font
var glow: Node2D
var _mesh_c := {}
var _flat := {}
var _t := 0.0
var _m := 48.0
var _o := Vector2.ZERO
var _len_g := 0.0
var _len_c := 0.0
var _mist: Array = []          # [port m, vel m/s, age, life, size]
var film := -1.0               # s into the film, -1 none
var _film_layer: CanvasLayer
var _film_card: Control
var _took_cam := false
var us := Vector3.ZERO           # perf tests: µs process, draw, glow
var tf                            # a tank_fill_fx for the tug tanks' liquid (not in the tree)
var _tanks := {}
var _len_l := 0.0
var _len_x := 0.0
var recv: Array = []            # the receiver drums (port m), laid out with the berth
var plinth := Rect2()
var h_path: Array = []
var g_path: Array = []           # the gas run: the receiver's riser, along the boom, G_TAIL
var _lay := ""
var _recv_mesh: ArrayMesh
var _recv_key := ""


# how big a receiver the berth has: 0 one drum, 1 one big drum, 2 two big drums
static func recv_tier(g) -> int:
	var own := Dock.owned(g._upgrades_for_berth() if g != null and g.has_method("_upgrades_for_berth") else {})
	own = maxf(own, Dock.floor_end)
	return 0 if own < 119.0 else (1 if own < 199.0 else 2)


# a point in the berth's metres (the berth at the world's origin) in port metres
func _dk(v: Vector2) -> Vector2:
	return (v * Geom.M - _o) / _m


func _layout() -> void:
	_m = PortStructure.M()
	_o = PortStructure.centre()
	var tier := recv_tier(game)
	var key := str([tier, snappedf(Dock.FLOOR_Y, 0.02), snappedf(Dock.BOUNDS.position.y, 0.02), _o.round()])
	if key == _lay:
		return
	_lay = key
	var sz: Vector2 = RECV_SIZE[mini(tier, 1)]
	var q := Dock.FLOOR_Y + QUAY_DOWN    # the quay truss's top
	var x1 := Dock.TOWER_X - RECV_OUT
	var x0 := x1 - sz.x
	plinth = Rect2(_dk(Vector2(x0 - 0.4, q - 0.9)), Vector2(sz.x + 0.8, 0.9))
	recv = []
	var y1 := q - 1.3                     # the lowest drum's underside (on its saddles)
	for i in (2 if tier >= 2 else 1):
		recv.append(Rect2(_dk(Vector2(x0, y1 - sz.y)), sz))
		y1 -= sz.y + 1.7                  # the next one up on the frame's beam
	var r0: Rect2 = recv[0]
	var top: Rect2 = recv[-1]
	var tx := _dk(Vector2(Dock.TOWER_X, 0.0)).x
	h_path = [Vector2(tx + 0.3, r0.get_center().y), Vector2(tx - 0.2, r0.get_center().y), Vector2(r0.end.x, r0.get_center().y)]
	var rx := top.end.x - 1.4
	var yj := _dk(Vector2(0.0, Dock.BOUNDS.position.y - OVER_BOOM)).y
	g_path = [Vector2(rx, top.position.y), Vector2(rx, yj)]
	if absf(rx - float(G_TAIL[0].x)) > 0.3:
		g_path.append(Vector2(G_TAIL[0].x, yj))
	g_path.append_array(G_TAIL)
	_len_g = _length(g_path)


# everything the receiver set takes (port m): the regression's and the culling's box
func recv_rect() -> Rect2:
	var r := plinth
	for d in recv:
		r = r.merge(d)
	for pv in h_path:
		r = r.expand(pv)
	return r.grow(0.6)


func _ready() -> void:
	z_index = 2
	z_as_relative = false
	font = Fonts.get_font("Regular")
	glow = Node2D.new()
	glow.z_index = 3
	glow.z_as_relative = false
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	glow.draw.connect(_draw_glow)
	add_child(glow)
	_layout()
	_len_c = _length(C_PATH)
	_len_l = _length(L_PATH)
	_len_x = _length(X_PATH)
	tf = TF.new()
	tf.game = game
	tf._ready()


func _exit_tree() -> void:
	_end_film()
	if tf != null and is_instance_valid(tf):
		tf.free()


# shown wherever the port is, the empty berth or a ship being stripped (its gas comes this way)
func active() -> bool:
	return game != null and game.career() and GasLine.built()


func cryo_on() -> bool:
	return PS.ENABLED and Port.stage("process") >= 1


func _p(v: Vector2) -> Vector2:
	return _o + v * _m


func _length(path: Array) -> float:
	var L := 0.0
	for i in range(1, path.size()):
		L += (path[i] as Vector2).distance_to(path[i - 1])
	return L


func _along(path: Array, s: float) -> Vector2:
	for i in range(1, path.size()):
		var a: Vector2 = path[i - 1]
		var b: Vector2 = path[i]
		var L := a.distance_to(b)
		if s <= L:
			return a.lerp(b, s / maxf(0.0001, L))
		s -= L
	return path[path.size() - 1]


func view_rect() -> Rect2:
	var r := Rect2(Vector2(-176.0, -30.0), Vector2(230.0, 170.0))
	for pv in g_path:
		r = r.expand(pv)
	r = r.merge(recv_rect())
	return Rect2(_p(r.position), r.size * _m)


func _on_screen() -> bool:
	var inv: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var s: Vector2 = get_viewport().get_visible_rect().size
	return Rect2(inv * Vector2.ZERO, Vector2.ZERO).expand(inv * s).intersects(view_rect())


func _zoom() -> float:
	return get_viewport().get_canvas_transform().get_scale().x


# ---------------------------------------------------------------- state

# the batches on their way: [id, 0..1 along, kg]
func transits() -> Array:
	var out: Array = []
	for b in GasLine.data().batches:
		if str(b.state) == "transit":
			out.append([str(b.id), clampf(1.0 - float(b.get("t_left", 0.0)) / maxf(0.01, float(b.get("t_total", GasLine.TRANSIT_S))), 0.0, 1.0), GasLine.mass(b)])
	return out


# the tug station's LH2 / LOX on their way: [kind, 0..1 along, kg]
func cryo_transits() -> Array:
	var out: Array = []
	for c in GasLine.data().get("cryo_pipe", []):
		out.append([str(c.kind), clampf(1.0 - float(c.t_left) / maxf(0.01, float(c.t_total)), 0.0, 1.0), float(c.kg)])
	return out


func _cryo_phase() -> String:
	if not PS.ENABLED:
		return "home"
	return str(PS.d().get("cryo", {}).get("phase", "home"))


func _cryo_flow() -> float:
	var ph := _cryo_phase()
	if ph == "p_fill":
		return 1.0
	if ph == "p_precool":
		return 0.3
	return 0.0


func _process(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	_process_now(dt)
	us.x = Time.get_ticks_usec() - t0


func _process_now(dt: float) -> void:
	_layout()
	visible = active()
	if not visible:
		_end_film()
		return
	_t += dt
	# the cryo run breathes a cold mist at its flanges while LH2 runs in it
	var cf := _cryo_flow() if cryo_on() else 0.0
	for q in _mist:
		q[0] = (q[0] as Vector2) + (q[1] as Vector2) * dt
		q[2] = float(q[2]) + dt
	_mist = _mist.filter(func(q): return float(q[2]) < float(q[3]))
	if cf > 0.0 and randf() < 8.0 * cf * dt and _mist.size() < 24:
		var at := _along(C_PATH, randf() * _len_c)
		_mist.append([at, Vector2.from_angle(randf() * TAU) * randf_range(0.3, 0.9), 0.0, randf_range(1.5, 3.0), randf_range(0.6, 1.4)])
	_tick_tug_tanks(dt)
	_film_tick(dt)
	if _on_screen() or film >= 0.0:
		queue_redraw()
		glow.queue_redraw()


func _tick_tug_tanks(dt: float) -> void:
	if _tanks.is_empty():
		var xf := Transform2D(0.0, _o)
		for k in ["lh2", "lox"]:
			var r: Rect2 = TUG_LH2 if k == "lh2" else TUG_LOX
			var inner := Rect2((r.position + Vector2(0.4, 0.4)) * _m, (r.size - Vector2(0.8, 0.8)) * _m)
			var e: Dictionary = tf._tank("", null, tf._capsule(inner, true), xf, k, 1.0, tf._capsule(Rect2(r.position * _m, r.size * _m), true), "")
			e["pd"] = Vector2.LEFT
			e["slow"] = true
			e["boil_k"] = 0.25
			tf._levels(e)
			_tanks[k] = e
	tf._t = _t
	var sending := {}
	for c in cryo_transits():
		sending[str(c[0])] = true
	var tc := TugYard.cryo()
	for k in _tanks:
		var e: Dictionary = _tanks[k]
		e["k_now"] = clampf(float(tc[k]) / TugYard.cryo_cap(k), 0.0, 1.0)
		e.flow = Pal.damp(float(e.flow), 1.0 if sending.has(k) else 0.0, 3.0, dt)
		e.xf = Transform2D(0.0, _o)


# ---------------------------------------------------------------- meshes (port metres)

func _mesh(key: String, build: Callable) -> ArrayMesh:
	if not _mesh_c.has(key):
		var pen := MeshPen.new()
		build.call(pen)
		_mesh_c[key] = pen.mesh()
	return _mesh_c[key]


func _ink(a: float) -> Color:
	return Pal.ink(a)


# a pipe as the cutaway draws one: dark rim, body, a lit edge toward the light; flanges every
# 12 m, an elbow at each bend, a support under it every 6 m (a shoe on a T-post)
func _pipe(p, path: Array, w: float, jacket: bool) -> void:
	var pv := PackedVector2Array(path)
	if not Pal.solid:
		# the old line-art picture (F9): the pipe as its two walls, its bends ringed, nothing lit
		p.polyline(pv, _ink(0.45), w + 0.14)
		p.polyline(pv, Color(0.02, 0.022, 0.026), w - 0.1)
		for i in range(1, pv.size() - 1):
			p.ring(pv[i], w * 0.7, _ink(0.4), 0.06, 12)
		return
	p.polyline(pv, RIM, w + 0.18)
	p.polyline(pv, BODY, w)
	for i in range(1, pv.size()):
		var a := pv[i - 1]
		var b := pv[i]
		var d := (b - a).normalized()
		var n := d.orthogonal()
		if n.dot(LIGHT) < 0.0:
			n = -n
		p.line(a + n * w * 0.32, b + n * w * 0.32, LIT, w * 0.16)
		var L := a.distance_to(b)
		var s := 6.0
		while s < L - 1.0:
			var c := a + d * s
			if int(s / 6.0) % 2 == 0:
				# a flange pair: thin collars standing just proud of the pipe
				for o: float in [0.0, 0.28]:
					p.line(c - n * (w * 0.68) + d * o, c + n * (w * 0.68) + d * o, Color(0.2, 0.207, 0.222), 0.09)
			else:
				# a pipe shoe clamping it to the rack under it
				p.line(c - n * (w * 0.55) - d * 0.45, c - n * (w * 0.55) + d * 0.45, STEEL, 0.2)
			s += 6.0
		# the rack it rides on, away from the light: a light truss (two chords, posts, diagonals)
		# wherever the run crosses open space, so nothing hangs in the air
		if L > 6.0:
			var o1 := -n * (w * 0.62)
			var o2 := -n * (w * 0.62 + 1.1)
			p.line(a + o1, b + o1, STEEL, 0.16)
			p.line(a + o2, b + o2, STEEL, 0.16)
			p.line(a + o2, b + o2, _ink(0.22), 0.04)
			var k2 := 0.0
			var up := true
			while k2 < L - 0.1:
				var k3 := minf(L, k2 + 2.2)
				p.line(a + d * k2 + o1, a + d * k2 + o2, STEEL, 0.1)
				p.line(a + d * k2 + (o1 if up else o2), a + d * k3 + (o2 if up else o1), _ink(0.2), 0.06)
				k2 = k3
				up = not up
		if jacket:
			# the vacuum jacket's convolutions
			var k := 1.5
			while k < L - 0.5:
				var c2 := a + d * k
				p.line(c2 - n * (w * 0.5), c2 + n * (w * 0.5), _ink(0.16), 0.05)
				k += 1.5
	for i in range(1, pv.size() - 1):
		p.circle(pv[i], w * 0.78, FACE2, 12)
		p.ring(pv[i], w * 0.78, _ink(0.4), 0.06, 12)


# the receiver set (port m, laid out with the berth): the run, the header, the drums on their plinth
func _recv_set(p) -> void:
	_pipe(p, g_path, G_W, false)
	p.rect(plinth, Color(0.07, 0.074, 0.082))
	p.rect(plinth, _ink(0.4), false, 0.06)
	p.hatch(plinth.grow(-0.1), _ink(0.08), 0.04, 0.4)
	# the frame the upper drum stands on: two columns off the plinth and a beam
	if recv.size() > 1:
		var r1: Rect2 = recv[1]
		var by := r1.end.y + 0.3
		for cx: float in [r1.position.x - 0.45, r1.end.x + 0.45]:
			p.rect(Rect2(cx - 0.22, by, 0.44, plinth.position.y - by), STEEL)
			p.line(Vector2(cx - 0.22, by), Vector2(cx - 0.22, plinth.position.y), _ink(0.3), 0.05)
		p.rect(Rect2(r1.position.x - 0.7, by, r1.size.x + 1.4, 0.45), STEEL)
		p.line(Vector2(r1.position.x - 0.7, by), Vector2(r1.end.x + 0.7, by), _ink(0.4), 0.06)
		# a cross brace behind the lower drum's ends
		p.line(Vector2(r1.position.x - 0.45, by + 0.45), Vector2(r1.position.x + 0.6, by + 1.4), STEEL, 0.14)
		p.line(Vector2(r1.end.x + 0.45, by + 0.45), Vector2(r1.end.x - 0.6, by + 1.4), STEEL, 0.14)
	for i in recv.size():
		var r: Rect2 = recv[i]
		var base := plinth.position.y if i == 0 else (recv[1] as Rect2).end.y + 0.3
		# a drum lying in two saddles, its gauge and relief
		for sx: float in [r.position.x + 1.3, r.end.x - 1.3]:
			p.poly(PackedVector2Array([Vector2(sx - 0.8, base), Vector2(sx - 0.5, r.get_center().y + 0.6), Vector2(sx + 0.5, r.get_center().y + 0.6), Vector2(sx + 0.8, base)]), STEEL)
			p.line(Vector2(sx - 0.9, base), Vector2(sx + 0.9, base), _ink(0.4), 0.08)
		var v := PackedVector2Array()
		var dh := 1.0
		var cy := r.get_center().y
		for k in 11:
			var a: float = -PI * 0.5 + PI * k / 10.0
			v.append(Vector2(r.end.x - dh + cos(a) * dh, cy + sin(a) * r.size.y * 0.5))
		for k in 11:
			var a: float = PI * 0.5 + PI * k / 10.0
			v.append(Vector2(r.position.x + dh + cos(a) * dh, cy + sin(a) * r.size.y * 0.5))
		p.poly(v, FACE)
		p.polyline(v, _ink(0.55), 0.1, true)
		var n := int((r.size.x - 3.0) / 1.5)
		for k in n:
			var x := r.position.x + 2.0 + k * 1.5
			p.line(Vector2(x, r.position.y), Vector2(x, r.end.y), _ink(0.14), 0.06)
		p.circle(Vector2(r.position.x + 1.5, cy - 0.3), 0.5, VOID, 14)
		p.ring(Vector2(r.position.x + 1.5, cy - 0.3), 0.5, _ink(0.45), 0.07, 14)
		if i == recv.size() - 1 and i > 0:
			pass
		elif i < recv.size() - 1:
			# the balance line up to the drum over it, at the far end
			var ru: Rect2 = recv[i + 1]
			_pipe(p, [Vector2(r.position.x + 0.9, r.position.y), Vector2(r.position.x + 0.9, ru.end.y)], 0.45, false)
		else:
			p.rect(Rect2(r.position.x + 2.6, r.position.y - 0.5, 0.3, 0.5), FACE2)   # the relief valve
	_pipe(p, h_path, 0.5, false)
	# the recovery header's flange where it leaves the tower's foot
	var h0: Vector2 = h_path[1]
	p.rect(Rect2(h0.x - 0.3, h0.y - 0.7, 0.6, 1.4), FACE2)
	p.rect(Rect2(h0.x - 0.3, h0.y - 0.7, 0.6, 1.4), _ink(0.5), false, 0.05)
	# the riser's clamps to the tower, every few metres
	var rx := float(g_path[0].x)
	var ty := _dk(Vector2(0.0, Dock.RAIL_Y - 2.6)).y
	var y := float(g_path[0].y) - 3.0
	var tx := _dk(Vector2(Dock.TOWER_X, 0.0)).x
	if recv.size() > 1:
		p.rect(Rect2(rx - 0.15, float(g_path[0].y) - 0.6, 0.3, 0.6), FACE2)   # the relief valve, on top
	while y > ty + 1.0:
		p.line(Vector2(rx + G_W * 0.5, y), Vector2(tx, y), STEEL, 0.18)
		y -= 4.0


func _still(p) -> void:
	_tug_group(p)
	if cryo_on():
		_pipe(p, C_PATH, C_W, true)
		# the warehouse's transfer skid: a box, its pump, the coupling for the tanks
		for hx: float in [SKID.position.x + 0.5, SKID.end.x - 0.5]:
			p.line(Vector2(hx, 64.2), Vector2(hx, SKID.position.y), STEEL, 0.22)
		p.rect(SKID, FACE)
		p.rect(SKID, _ink(0.55), false, 0.08)
		p.circle(SKID.position + Vector2(1.6, 2.0), 1.1, STEEL, 16)
		p.ring(SKID.position + Vector2(1.6, 2.0), 1.1, _ink(0.45), 0.06, 16)
		p.rect(Rect2(SKID.position.x + 3.2, SKID.position.y + 0.8, 2.2, 2.4), VOID)
		p.rect(Rect2(SKID.position.x + 3.2, SKID.position.y + 0.8, 2.2, 2.4), _ink(0.4), false, 0.05)
		# the pipe bridge over the berth bridge: a truss span carrying it
		var bx0 := -9.0
		var bx1 := 9.0
		var by := 70.0
		p.rect(Rect2(bx0, by - 1.6, bx1 - bx0, 0.25), STEEL)
		p.rect(Rect2(bx0, by + 1.2, bx1 - bx0, 0.25), STEEL)
		var x := bx0
		var up := true
		while x < bx1 - 0.1:
			p.line(Vector2(x, by + (1.3 if up else -1.5)), Vector2(x + 1.5, by + (-1.5 if up else 1.3)), _ink(0.28), 0.12)
			x += 1.5
			up = not up


# the tug station's collection tanks: two jacketed tanks lying in a frame hung from its floor
func _tug_group(p) -> void:
	_pipe(p, L_PATH, 0.7, true)
	_pipe(p, X_PATH, 0.7, true)
	var fr := Rect2(-111.0, -25.7, 12.0, 7.9)
	for hx: float in [fr.position.x + 0.4, fr.end.x - 0.4, fr.position.x + 6.0]:
		p.line(Vector2(hx, fr.position.y), Vector2(hx, fr.end.y), STEEL, 0.32)
		p.line(Vector2(hx - 0.16, fr.position.y), Vector2(hx - 0.16, fr.end.y), _ink(0.3), 0.04)
	p.line(Vector2(fr.position.x, fr.position.y + 0.15), Vector2(fr.end.x, fr.position.y + 0.15), STEEL, 0.3)
	p.line(Vector2(fr.position.x, fr.end.y - 0.15), Vector2(fr.end.x, fr.end.y - 0.15), STEEL, 0.3)
	p.line(Vector2(fr.position.x + 0.4, fr.position.y + 0.3), Vector2(fr.end.x - 0.4, fr.end.y - 0.3), _ink(0.2), 0.06)
	for r: Rect2 in [TUG_LH2, TUG_LOX]:
		var outer: PackedVector2Array = tf._capsule(r, true)
		var inner: PackedVector2Array = tf._capsule(Rect2(r.position + Vector2(0.4, 0.4), r.size - Vector2(0.8, 0.8)), true)
		p.poly(outer, STEEL)
		p.polyline(outer, _ink(0.6), 0.08, true)
		p.poly(inner, Color(0.04, 0.044, 0.052))
		p.polyline(inner, _ink(0.4), 0.05, true)
		# saddles on the frame's cross member, the relief valve on top
		for sx: float in [r.position.x + 1.5, r.end.x - 1.5]:
			p.poly(PackedVector2Array([Vector2(sx - 0.6, r.end.y + 0.2), Vector2(sx - 0.4, r.end.y - 0.3), Vector2(sx + 0.4, r.end.y - 0.3), Vector2(sx + 0.6, r.end.y + 0.2)]), STEEL)
		p.rect(Rect2(r.end.x - 2.4, r.position.y - 0.4, 0.3, 0.4), FACE2)
	# a warning band on the hydrogen tank
	p.hatch(Rect2(TUG_LH2.position.x + 3.0, TUG_LH2.position.y + 0.06, 1.0, 0.32), Pal.tint(Pal.heat(0.6, 1.0), 0.35, 1.0), 0.05, 0.18)


# a white disc (the gas slug, mist): laid with its colour
func _disc() -> ArrayMesh:
	return _mesh("disc", func(p):
		p.circle(Vector2.ZERO, 1.0, Color(1, 1, 1, 0.45), 18)
		p.circle(Vector2.ZERO, 0.6, Color(1, 1, 1, 0.75), 14)
		p.circle(Vector2.ZERO, 0.3, Color(1, 1, 1, 1.0), 10))


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var t0 := Time.get_ticks_usec()
	_draw_now()
	us.y = Time.get_ticks_usec() - t0


func _draw_now() -> void:
	if not active() or not (_on_screen() or film >= 0.0):
		return
	draw_rect(view_rect(), Color(0, 0, 0, 0), false, 1.0)
	draw_mesh(_mesh("still%d%d" % [int(cryo_on()), int(Pal.solid)], func(p): _still(p)), null, Transform2D(0.0, Vector2(_m, _m), 0.0, _o))
	var rk := _lay + str(Pal.solid)
	if rk != _recv_key:
		_recv_key = rk
		var pen := MeshPen.new()
		_recv_set(pen)
		_recv_mesh = pen.mesh()
	draw_mesh(_recv_mesh, null, Transform2D(0.0, Vector2(_m, _m), 0.0, _o))
	# the tug tanks' LH2 / LOX, as the ships' tanks are drawn
	for k in ["lh2", "lox"]:
		var e: Dictionary = _tanks.get(k, {})
		if not e.is_empty():
			var verts := PackedVector2Array()
			var cols := PackedColorArray()
			var idx := PackedInt32Array()
			tf.emit_liquid(e, e.xf, self, verts, cols, idx)
			if not idx.is_empty():
				RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, verts, cols)
	for q in _mist:
		var u: float = float(q[2]) / float(q[3])
		var sz: float = float(q[4]) * (0.6 + 0.6 * u)
		draw_mesh(_disc(), null, Transform2D(0.0, Vector2(sz * _m, sz * _m), 0.0, _p(q[0])), Color(0.9, 0.94, 1.0, 0.05 * sin(u * PI)))
	# the readouts riding with what flows (close enough to read)
	if _zoom() * _m >= 2.0:
		for tr in transits():
			var at := _along(g_path, float(tr[1]) * _len_g)
			draw_string(font, _p(at + Vector2(1.6, -1.4)), "%s %.1f t · %.0f kg/s" % [str(tr[0]), float(tr[2]) / 1000.0, float(tr[2]) / maxf(1.0, GasLine.TRANSIT_S)], HORIZONTAL_ALIGNMENT_LEFT, -1, int(1.4 * _m), Pal.ink(0.75))
		for ct in cryo_transits():
			var path: Array = L_PATH if str(ct[0]) == "lh2" else X_PATH
			var at3 := _along(path, float(ct[1]) * (_len_l if str(ct[0]) == "lh2" else _len_x))
			draw_string(font, _p(at3 + Vector2(1.2, -0.9)), "%s %.0f kg · %.0f kg/s" % ["LH2" if str(ct[0]) == "lh2" else "LOX", float(ct[2]), float(ct[2]) / maxf(1.0, GasLine.CRYO_S)], HORIZONTAL_ALIGNMENT_LEFT, -1, int(clampf(0.6 * _m, 11.0 / maxf(0.01, _zoom()), 1.4 * _m)), Pal.ink(0.75))
		if _zoom() * _m >= 6.0:
			var tc2 := TugYard.cryo()
			draw_string(font, _p(Vector2(-98.6, -23.0)), "LH2 %.0f / %.0f kg" % [float(tc2.lh2), TugYard.cryo_cap("lh2")], HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.6 * _m), Pal.ink(0.6))
			draw_string(font, _p(Vector2(-98.6, -19.8)), "LOX %.0f / %.0f kg" % [float(tc2.lox), TugYard.cryo_cap("lox")], HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.6 * _m), Pal.ink(0.6))
		if cryo_on() and _cryo_flow() > 0.0:
			var c: Dictionary = PS.d().get("cryo", {})
			var at2 := _along(C_PATH, _len_c * 0.5)
			draw_string(font, _p(at2 + Vector2(1.6, -1.6)), "LH2 %.0f kg · LOX %.0f kg" % [float(c.get("h2_kg", 0.0)), float(c.get("o2_kg", 0.0))], HORIZONTAL_ALIGNMENT_LEFT, -1, int(1.4 * _m), Pal.ink(0.75))
	# the replay button under the gas bay's readout board
	if _zoom() * _m >= 6.0:
		var br := Rect2(_p(BTN.position), BTN.size * _m)
		draw_rect(br, Color(0.02, 0.025, 0.03))
		draw_rect(br, Pal.ink(0.5), false, maxf(1.0, 0.04 * _m))
		draw_string(font, br.position + Vector2(0.15, 0.62) * _m, "▶ 看流程", HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.42 * _m), Pal.ink(0.75))


func _draw_glow() -> void:
	var t0 := Time.get_ticks_usec()
	_draw_glow_now()
	us.z = Time.get_ticks_usec() - t0


func _draw_glow_now() -> void:
	if not active() or not (_on_screen() or film >= 0.0):
		return
	var tv := PackedVector2Array()
	var tc := PackedColorArray()
	var hw := maxf(0.18 * _m, 0.8 / maxf(0.0001, _zoom()))
	# a batch on its way: the gas front, grey-white, the dashes behind it to the receiver
	var grey := Color(0.86, 0.87, 0.9)
	for tr in transits():
		var s_front: float = float(tr[1]) * _len_g
		_dashes(tv, tc, g_path, 0.0, s_front, grey, 0.55, 9.0, hw)
		_slug(g_path, s_front, grey, 1.0)
	# the tug station's LH2 / LOX on their way to the gas bay
	for ct in cryo_transits():
		var lh := str(ct[0]) == "lh2"
		var col := LC.of("lh2") if lh else LC.of("lox")
		var path: Array = L_PATH if lh else X_PATH
		var s_front: float = float(ct[1]) * (_len_l if lh else _len_x)
		_dashes(tv, tc, path, 0.0, s_front, col, 0.4 if lh else 0.6, 7.0, hw * 0.7)
		_slug(path, s_front, col, 0.7 if lh else 1.0)
	var gs := PackedVector2Array()
	var gc := PackedColorArray()
	for k in _tanks:
		tf.emit_glow(_tanks[k], (_tanks[k] as Dictionary).xf, glow, gs, gc)
	if film >= 0.0:
		var fs := _film_tracer()
		if not fs.is_empty():
			_slug(fs[0], float(fs[1]), Color(1.0, 1.0, 1.0), 1.0)
	# the cryo run while the tug fills: LH2 (all but colourless) and LOX (pale blue) side by side
	if cryo_on():
		var cf := _cryo_flow()
		if cf > 0.0:
			var h2 := LC.of("lh2")
			var o2 := LC.of("lox")
			_dashes(tv, tc, C_PATH, 0.0, _len_c, Color(h2.r, h2.g, h2.b), 0.35 * cf, 7.0, hw * 0.7, -0.2)
			_dashes(tv, tc, C_PATH, 0.0, _len_c, o2, 0.6 * cf, 7.0, hw * 0.7, 0.2)
	if not tv.is_empty():
		RenderingServer.canvas_item_add_triangle_array(glow.get_canvas_item(), PackedInt32Array(), tv, tc)


# the dashes of what runs in a pipe from s0 to s1 (m along it), moving at speed m/s
func _dashes(tv: PackedVector2Array, tc: PackedColorArray, path: Array, s0: float, s1: float, col: Color, a: float, speed: float, hw: float, side := 0.0) -> void:
	var c := Color(col.r, col.g, col.b, a)
	var step := 4.0
	var x := s0 + fposmod(_t * speed, step)
	while x < s1:
		var p0 := _along(path, x)
		var p1 := _along(path, minf(s1, x + 1.6))
		var d := (p1 - p0)
		if d.length() > 0.001:
			var n := d.normalized().orthogonal()
			var q0 := _p(p0 + n * side)
			var q1 := _p(p1 + n * side)
			var nn := n * hw
			tv.append_array(PackedVector2Array([q0 - nn, q1 - nn, q1 + nn, q0 - nn, q1 + nn, q0 + nn]))
			tc.append_array(PackedColorArray([c, c, c, c, c, c]))
		x += step


# the gas front: a soft bright slug
func _slug(path: Array, s: float, col: Color, a: float) -> void:
	var at := _along(path, s)
	for k in 3:
		var back := _along(path, maxf(0.0, s - k * 1.6))
		glow.draw_mesh(_disc(), null, Transform2D(0.0, Vector2(1.3 - k * 0.3, 1.3 - k * 0.3) * _m, 0.0, _p(back)), Color(col.r, col.g, col.b, 0.35 * a * (1.0 - k * 0.25)))
	glow.draw_mesh(_disc(), null, Transform2D(0.0, Vector2(0.9, 0.9) * _m, 0.0, _p(at)), Color(col.r, col.g, col.b, 0.8 * a))


# ---------------------------------------------------------------- the film

func film_due() -> bool:
	if Career.data.get("seen", {}).get("gas_flow_film", false):
		return false
	return not transits().is_empty() or not cryo_transits().is_empty()


func play_film() -> void:
	if film >= 0.0 or game == null:
		return
	film = 0.0
	_took_cam = true
	_film_layer = CanvasLayer.new()
	_film_layer.layer = 40
	add_child(_film_layer)
	_film_card = Control.new()
	_film_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_film_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_film_card.draw.connect(_draw_film_card)
	_film_layer.add_child(_film_card)
	var seen: Dictionary = Career.data.get("seen", {})
	seen["gas_flow_film"] = true
	Career.data.seen = seen
	Career.save()


func _end_film() -> void:
	if film < 0.0:
		return
	film = -1.0
	if _took_cam and game != null and is_instance_valid(game):
		game.cam_override = null
		game.zoom_override = -1.0
	_took_cam = false
	if _film_layer != null and is_instance_valid(_film_layer):
		_film_layer.queue_free()
	_film_layer = null
	_film_card = null


# the film's tracer: [path, m along it] or [] (the tug's LH2 to the bay, then the ship's gas)
func _film_tracer() -> Array:
	if film >= 1.4 and film < 3.4:
		return [L_PATH, clampf((film - 1.4) / 2.0, 0.0, 1.0) * _len_l]
	if film >= 4.6 and film < 8.0:
		return [g_path, clampf((film - 4.6) / 3.4, 0.0, 1.0) * _len_g]
	return []


# the shots: [camera target (port m), zoom (screen px a port m)]
func _shot() -> Array:
	if film < 1.4:
		return [TUG_LH2.get_center() + Vector2(-2.0, 2.0), 22.0]
	if film < 3.4:
		var tr := _film_tracer()
		return [_along(L_PATH, float(tr[1])) if not tr.is_empty() else Vector2(-146.0, -10.0), 16.0]
	if film < 4.6:
		return [(recv[0] as Rect2).get_center() + Vector2(4.0, -2.0), 14.0]
	if film < 8.0:
		var tr2 := _film_tracer()
		var u := clampf((film - 4.6) / 3.4, 0.0, 1.0)
		return [_along(g_path, float(tr2[1])) if not tr2.is_empty() else Vector2(-160.0, 11.0), lerpf(9.0, 6.0, sin(u * PI))]
	if film < 10.2:
		return [Vector2(-145.0, 0.0), 30.0]
	if film < 11.8:
		return [Vector2(-131.0, 2.0), 34.0]
	return [Vector2(-128.0, -14.0), 26.0]


func _film_tick(dt: float) -> void:
	if film < 0.0:
		if film_due() and game.state == "play" and game.cam_override == null:
			play_film()
		return
	film += dt
	if film >= FILM_S or game.state != "play":
		_end_film()
		return
	var sh := _shot()
	var target: Vector2 = _p(sh[0])
	var z: float = float(sh[1]) / _m
	# eased toward the shot (the camera's own smoothing does the rest)
	var cur: Vector2 = game.cam_override if game.cam_override != null else target
	game.cam_override = cur.lerp(target, clampf(dt * 5.0, 0.0, 1.0))
	game.zoom_override = lerpf(game.zoom_override if game.zoom_override > 0.0 else z, z, clampf(dt * 4.0, 0.0, 1.0))
	if _film_card != null:
		_film_card.queue_redraw()


# any key or click ends the film; a click on "看流程" plays it
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if film >= 0.0:
		if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
			_end_film()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _zoom() * _m >= 6.0:
		var wp: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * (event as InputEventMouseButton).position
		if Rect2(_p(BTN.position), BTN.size * _m).has_point(wp) and game.state == "play":
			play_film()
			get_viewport().set_input_as_handled()


# the line of where it goes (placeholder words, 〔〕), the step now lit
const STEPS := [["〔来源〕拖船站抽回的液氢 · 液氧", 0.0], ["〔来源〕拆船回收的气体", 3.4], ["〔管道〕送往加工区", 4.6], ["〔分离 / 液化〕", 8.0], ["〔储罐〕液氧 · 液氢", 10.2], ["〔出货〕拖船 → 燃料电池 · 交易所", 11.8]]


func _draw_film_card() -> void:
	var c := _film_card
	var vs: Vector2 = c.get_viewport_rect().size
	var h := 64.0
	var y := 118.0                       # under the top bar, clear of the tool row at the bottom
	c.draw_rect(Rect2(0.0, y - 14.0, vs.x, h + 28.0), Color(0, 0, 0, 0.45))
	var x := 80.0
	var fb := Fonts.get_font("Medium")
	for i in STEPS.size():
		var on := film >= float(STEPS[i][1])
		var now := on and (i == STEPS.size() - 1 or film < float(STEPS[i + 1][1]))
		var col := Pal.heat(0.95, 1.3) if now else (Pal.ink(0.85) if on else Pal.ink(0.3))
		var s: String = STEPS[i][0]
		c.draw_string(fb, Vector2(x, y + 40.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, col)
		x += fb.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 24.0
		if i < STEPS.size() - 1:
			c.draw_string(fb, Vector2(x, y + 40.0), "→", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Pal.ink(0.45))
			x += 44.0
	c.draw_string(fb, Vector2(vs.x - 300.0, y + h + 40.0), "〔任意键跳过〕", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Pal.ink(0.55))
