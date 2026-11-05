extends Node2D
# 131 号 (user 2026-11-05: "它从哪冒出来的？…你可以说这是一个小终端，然后有一根线连到我的货运区，毕竟
# 货运区才是主仓库嘛"; Q: A). The stores terminal's line to the cargo district: from the gland on the
# terminal's hood up the berth's wall in a cable tray, along the ceiling under the rail, through the
# ceiling in a junction box left of the gate, across the berth's corridor on a short cable bridge,
# up the corridor's wall, round the ring's outer wall, down the cargo corridor and into a junction box
# on the cargo district's wall beside its door. Clamps every few metres; the tray's own ribs; a faint
# light runs along the core when the stores talk (a shader on the core, everything else one cached
# mesh, rebuilt only when the berth or the port moves).

const MeshPen = preload("res://scripts/mesh_pen.gd")
const PortStructure = preload("res://scripts/port_structure.gd")

var game
var t := 0.0
var _key := ""
var _body: ArrayMesh
var _core: ArrayMesh
var _labels: Array = []          # [world px, text]
var _raw := PackedVector2Array()
var _boxes: Array = []
var _thin := PackedVector2Array()
var glow: Node2D
static var _shader: Shader


func _init() -> void:
	z_index = 3
	z_as_relative = false


func _ready() -> void:
	glow = Node2D.new()
	glow.z_index = 3
	glow.z_as_relative = false
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	glow.material = mat
	glow.draw.connect(func():
		if _core != null:
			glow.draw_mesh(_core, null))
	add_child(glow)


func on() -> bool:
	return game != null and StoreBook.ON and Consoles.rack_on() and game.career()


func _process(dt: float) -> void:
	t += dt
	visible = on()
	if not visible:
		return
	var k := "%.1f/%.1f/%.1f/%.1f" % [Dock.centre().x, Dock.RAIL_Y, PortStructure.centre().x, PortStructure.centre().y]
	if k != _key:
		_key = k
		_build()
		queue_redraw()
		glow.queue_redraw()
	queue_redraw()
	(glow.material as ShaderMaterial).set_shader_parameter("time", t)
	(glow.material as ShaderMaterial).set_shader_parameter("tint", Pal.tint(Pal.VOLT, 1.0, 1.4))


# ---------------------------------------------------------------- the run

static func gland() -> Vector2:
	# the hex nut on the terminal's right side (scripts/console_art.gd "store", at Consoles.KIOSK_K)
	return Consoles.kiosk_at() + Vector2(1.46, -0.94) * PortStructure.M() * Consoles.KIOSK_K


# the run in world px: [points, the indices where a junction box sits]
static func run() -> Dictionary:
	var M := Geom.M
	var pm := PortStructure.M()
	var g := gland()
	var gx: float = clampf(Dock.centre().x, Dock.TOWER_X + 3.0, Dock.ARM_X1 - 3.0) * M
	var ceil_y := Dock.RAIL_Y * M
	var tray_y := ceil_y + 0.75 * M
	var wall_x := (Dock.TOWER_X + 4.2) * M        # clear of the berth terminal on the tower wall
	var c := PortStructure.centre()
	var R := PortArt.HUB_R * pm
	var half_s := PortStructure.half("salvage") * pm
	var up_x := gx + half_s - 0.9 * pm            # up the corridor's right wall
	var bridge_y := ceil_y - 2.6 * M
	# through the ceiling well clear of the gate and its markers
	var jb1 := Vector2(gx - 6.5 * M, ceil_y)
	var pts := PackedVector2Array([g, g + Vector2(0.25 * M, 0), Vector2(wall_x, g.y), Vector2(wall_x, tray_y),
		Vector2(jb1.x, tray_y), jb1, Vector2(jb1.x, bridge_y), Vector2(up_x, bridge_y)])
	# up the wall to the ring
	var dy := sqrt(maxf(R * R - (up_x - c.x) * (up_x - c.x), 0.0))
	var a0 := (Vector2(up_x, c.y + dy) - c).angle()
	var r_in := R - 0.9 * pm
	pts.append(c + Vector2.from_angle(a0) * (R + 0.6 * pm))
	# round the ring's outer wall to the cargo corridor, the cable on its side towards the berth
	var door: Array = PortStructure.door("cargo")
	var dp: Vector2 = door[0]
	var axis := (dp - c).normalized()
	var off := axis.orthogonal()
	if off.dot(Vector2.from_angle(a0) - axis) < 0.0:
		off = -off
	var side := (PortStructure.half("cargo") - 0.7) * pm
	var a1 := (c + axis * R + off * side - c).angle()
	var span := angle_difference(a0, a1)
	var n := maxi(3, int(absf(span) / deg_to_rad(4.0)))
	for i in n + 1:
		pts.append(c + Vector2.from_angle(a0 + span * float(i) / n) * r_in)
	pts.append(c + axis * (R + 0.6 * pm) + off * side)
	# down the corridor, then along the shell's wall past the door's edge into the box
	var end_in := dp - axis * 1.6 * pm + off * side
	pts.append(end_in)
	var jb2 := dp + off * (PortStructure.DOOR * 0.5 + 1.1) * pm - axis * 0.5 * pm
	pts.append(jb2)
	return {"pts": pts, "boxes": [5, pts.size() - 1], "berth_end": 5}


# ---------------------------------------------------------------- the drawing

# a polyline with its corners rounded (r px), so the cable bends like a cable
static func _fillet(p: PackedVector2Array, r: float) -> PackedVector2Array:
	var out := PackedVector2Array([p[0]])
	for i in range(1, p.size() - 1):
		var a := p[i - 1]
		var b := p[i]
		var c := p[i + 1]
		var d0 := (b - a)
		var d1 := (c - b)
		var rr := minf(r, minf(d0.length(), d1.length()) * 0.45)
		if rr < 1.0 or absf(d0.normalized().cross(d1.normalized())) < 0.05:
			out.append(b)
			continue
		var s := b - d0.normalized() * rr
		var e := b + d1.normalized() * rr
		for k in 7:
			var u := k / 6.0
			out.append(s.lerp(b, u).lerp(b.lerp(e, u), u))
	out.append(p[p.size() - 1])
	return out


func _build() -> void:
	var M := Geom.M
	var r := run()
	var raw: PackedVector2Array = r.pts
	_raw = raw
	_boxes = r.boxes
	_thin = _fillet(raw, 0.6 * M)
	var pts := _fillet(raw, 0.6 * M)
	var pen := MeshPen.new()
	var tray := Color(0.11, 0.115, 0.125)
	var tray_edge := Pal.ink(0.42)
	var dark := Color(0.018, 0.02, 0.024)
	var sheath := Color(0.075, 0.08, 0.09)
	# the tray: a shallow channel under the cable, its two lips, a rib every 0.6 m (only along the
	# straight runs on the walls; the cable bridge has its own little truss)
	for i in range(1, raw.size()):
		var a := raw[i - 1]
		var b := raw[i]
		var L := a.distance_to(b)
		if L < 0.8 * M:
			continue
		var d := (b - a) / L
		var nrm := d.orthogonal()
		var wdt := 0.34 * M
		pen.line(a, b, tray, wdt)
		pen.line(a + nrm * wdt * 0.5, b + nrm * wdt * 0.5, tray_edge, 0.035 * M)
		pen.line(a - nrm * wdt * 0.5, b - nrm * wdt * 0.5, tray_edge, 0.035 * M)
		var s := 0.3 * M
		while s < L:
			var q := a + d * s
			pen.line(q - nrm * wdt * 0.5, q + nrm * wdt * 0.5, Pal.ink(0.2), 0.03 * M)
			s += 0.6 * M
	# the cable bridge across the corridor: two chords and their diagonals
	var b0 := raw[6]
	var b1 := raw[7]
	var bn := Vector2(0, -0.35 * M)
	pen.line(b0 + bn, b1 + bn, Pal.ink(0.32), 0.05 * M)
	pen.line(b0 - bn, b1 - bn, Pal.ink(0.32), 0.05 * M)
	var bs := 0.0
	var bl := b0.distance_to(b1)
	var flip := 1.0
	while bs + 0.7 * M <= bl:
		var p0 := b0.lerp(b1, bs / bl)
		var p1 := b0.lerp(b1, (bs + 0.7 * M) / bl)
		pen.line(p0 + bn * flip, p1 - bn * flip, Pal.ink(0.22), 0.03 * M)
		flip = -flip
		bs += 0.7 * M
	# the cable: a dark rim, the sheath, a thin highlight on one side
	for i in range(1, pts.size()):
		pen.line(pts[i - 1], pts[i], dark, 0.2 * M)
	for i in pts.size():
		pen.circle(pts[i], 0.1 * M, dark, 8)
	for i in range(1, pts.size()):
		pen.line(pts[i - 1], pts[i], sheath, 0.13 * M)
	for i in range(1, pts.size() - 1):
		pen.circle(pts[i], 0.065 * M, sheath, 8)
	for i in range(1, pts.size()):
		var d := (pts[i] - pts[i - 1]).normalized().orthogonal()
		pen.line(pts[i - 1] + d * 0.035 * M, pts[i] + d * 0.035 * M, Color(1, 1, 1, 0.08), 0.02 * M)
	# the clamps: a saddle over the cable every 2.4 m, two screws into the tray
	var acc := 0.0
	var next := 1.2 * M
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var L := a.distance_to(b)
		while next <= acc + L:
			var q := a.lerp(b, (next - acc) / maxf(L, 0.001))
			var d := (b - a).normalized()
			var nrm := d.orthogonal()
			var cr := PackedVector2Array([q - d * 0.07 * M - nrm * 0.17 * M, q + d * 0.07 * M - nrm * 0.17 * M, q + d * 0.07 * M + nrm * 0.17 * M, q - d * 0.07 * M + nrm * 0.17 * M])
			pen.poly(cr, Color(0.2, 0.21, 0.225))
			pen.polyline(cr, Pal.ink(0.55), 0.015 * M, true)
			pen.circle(q - nrm * 0.12 * M, 0.025 * M, Pal.ink(0.7), 6)
			pen.circle(q + nrm * 0.12 * M, 0.025 * M, Pal.ink(0.7), 6)
			next += 2.4 * M
		acc += L
	# the junction boxes where it goes through a wall: a box with its lid, four screws, the glands
	for bi in r.boxes:
		var at: Vector2 = raw[bi]
		var br := Rect2(at - Vector2(0.45, 0.32) * M, Vector2(0.9, 0.64) * M)
		pen.rect(br.grow(0.04 * M), dark)
		pen.rect(br, Color(0.14, 0.148, 0.16))
		pen.rect(br, Pal.ink(0.6), false, 0.03 * M)
		pen.rect(br.grow(-0.08 * M), Pal.ink(0.3), false, 0.02 * M)
		for cx in [-1.0, 1.0]:
			for cy in [-1.0, 1.0]:
				pen.circle(at + Vector2(cx * 0.35, cy * 0.23) * M, 0.03 * M, Pal.ink(0.7), 6)
		pen.hatch(Rect2(br.position + Vector2(0.12, 0.12) * M, Vector2(0.3, 0.14) * M), Pal.heat(0.6, 1.0), 0.02 * M, 0.06 * M)
	_body = pen.mesh()
	# the core the light runs on: UV.x = metres from the terminal
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var s0 := 0.0
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var L := a.distance_to(b)
		if L < 0.5:
			continue
		var nrm := (b - a).normalized().orthogonal() * 0.03 * M
		var u0 := s0 / M
		var u1 := (s0 + L) / M
		var q := [a - nrm, b - nrm, b + nrm, a + nrm]
		var u := [u0, u1, u1, u0]
		for idx in [0, 1, 2, 0, 2, 3]:
			verts.append(q[idx])
			uvs.append(Vector2(u[idx], 0.0))
			cols.append(Color.WHITE)
		s0 += L
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cols
	_core = ArrayMesh.new()
	_core.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	(glow.material as ShaderMaterial).set_shader_parameter("total", s0 / M)
	# where it leads, stencilled beside each box
	_labels = [[raw[5] + Vector2(-0.45, 0.8) * M, ("→ 货运区 · 主仓库" if Txt.zh else "→ CARGO · MAIN STORES")],
		[raw[raw.size() - 1] + Vector2(0.62, -0.05) * M, ("仓库线 · 来自七号船坞" if Txt.zh else "STORES LINE · FROM BERTH 07")]]


func _draw() -> void:
	if _body == null:
		return
	draw_mesh(_body, null)
	# the boxes' lamps: green while the line is up, a blink as each signal passes
	var M := Geom.M
	for bi in _boxes:
		var at: Vector2 = _raw[bi] + Vector2(0.28, 0.0) * M
		var blink := 0.6 + 0.4 * absf(sin(t * 2.2 + float(bi)))
		draw_circle(at, 0.065 * M, Pal.tint(Pal.FLUID, 0.9 * blink, 1.3))
	var z: float = maxf(get_canvas_transform().get_scale().x, 0.02)
	# far out the cable is a hair: a line a pixel and a half wide on the screen keeps it readable
	if M * z < 14.0 and _thin.size() > 1:
		draw_polyline(_thin, Color(0.0, 0.0, 0.0, 0.6), 3.2 / z)
		draw_polyline(_thin, Pal.tint(Pal.VOLT, 0.55, 1.1), 1.5 / z)
		for bi in _boxes:
			draw_rect(Rect2(_raw[bi] - Vector2(3.0, 2.2) / z, Vector2(6.0, 4.4) / z), Pal.ink(0.7))
	if M * z < 10.0:
		return
	var font := Fonts.get_font("SemiBold")
	for lb in _labels:
		draw_set_transform(lb[0], 0.0, Vector2.ONE / z)
		draw_string(font, Vector2(0, 5), str(lb[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.62))
	draw_set_transform(Vector2.ZERO)


const SHADER := """
shader_type canvas_item;
render_mode blend_add, unshaded;
uniform float total = 300.0;
uniform float time = 0.0;
uniform vec4 tint : source_color = vec4(0.4, 0.8, 1.0, 1.0);
void fragment() {
	// a short pulse from the cargo district to the terminal every few seconds, very faint, and the
	// core a hair lit all along
	float head = total - mod(time * 28.0, total + 40.0);
	float d = UV.x - head;
	float pulse = exp(-d * d / 6.0) + 0.35 * exp(-max(d, 0.0) / 9.0) * step(0.0, d) * step(d, 18.0);
	COLOR = vec4(tint.rgb, 0.05 + 0.32 * pulse);
}
"""
