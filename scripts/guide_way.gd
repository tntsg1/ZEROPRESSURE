extends RefCounted
# 131 号 (user 2026-11-05, a shot of the port walk's step 2: the ring far off the screen, only the
# small arrow over the drone — "不知道往哪飞"; Q: A). How every "fly there" guide shows the way, the
# same for the port walk, the stores' first visit and the first ship (beside scripts/guide_mark.gd,
# which draws the target's brackets and the drone's small arrow):
#   floor    a row of lit chevrons on the floor along the way that can really be flown — out of the
#            berth's gate, up the corridor, round the ring's deck, down the next corridor, in at the
#            door — never through a wall; a slow bright wave runs along them towards the target.
#            One cached mesh (rebuilt only when the way changes) under a small shader
#   edge     the target off the screen: a big arrow on the screen's edge where it lies, the name and
#            the metres still to go ("中央转运环 · 还有 120 m"), live
#   prefix   the card's title gets the way in front ("往上飞 → "), from where the target lies
#            from the drone now; the guide's own words after it unchanged
# Close to the target all three fold away. The camera is never moved.
#   var way := GuideWay.new(); way.attach(self)        # in the guide's _ready
#   way.update(game, from, to, dt)                      # each frame (to = Vector2.INF: none)
#   way.draw_edge(self, name, colour, avoid)            # in the guide's _draw
#   title.text = way.prefix() + words

const FastDraw = preload("res://scripts/fast_draw.gd")
const PortStructure = preload("res://scripts/port_structure.gd")

const NEAR_M := 9.0          # m of way left: everything folds away
const SPACING := 2.8         # m between chevrons
const FLOOR_MIN := 14.0      # m: a way shorter than this (and straight) gets no floor arrows
const DECK_R := 20.0         # m: the ring's deck the way goes round on (between the two rings)

var layer: Node2D            # the floor chevrons (their own canvas item: the shader is theirs)
var path := PackedVector2Array()
var length_m := 0.0          # the way left, m
var show := 0.0              # 0..1: the floor and the edge arrow fade in and out together
var floor_on := true         # false: only the edge arrow (the first ship and the belt: no corridors there)
var to := Vector2.INF
var _from := Vector2.INF
var _repath := 0.0
var _built_from := Vector2.INF
var _key := ""
var _sector := -1            # the prefix's direction (0 right, 2 down, 4 left, 6 up), kept a little sticky
var _t := 0.0
var _game
var _mesh: ArrayMesh

static var _shader: Shader


func attach(host: Node) -> void:
	layer = Node2D.new()
	layer.name = "GuideWayFloor"
	layer.z_index = 5            # over the corridors' rails and the shuttle's line, under the drone
	layer.z_as_relative = false
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	layer.material = mat
	layer.draw.connect(_draw_floor)
	host.add_child(layer)


# from: the drone; to: the target (Vector2.INF: none)
func update(game, from: Vector2, target: Vector2, dt: float) -> void:
	_game = game
	_t += dt
	var moved := target != to
	to = target
	_from = from
	if to == Vector2.INF or from == Vector2.INF:
		path = PackedVector2Array()
		length_m = 0.0
		show = move_toward(show, 0.0, dt * 4.0)
		_sector = -1
		_sync(dt)
		return
	_repath -= dt
	if moved or _repath <= 0.0 or path.is_empty():
		_repath = 0.25
		path = route(game, from, to)
	else:
		path[0] = from
	length_m = _len(path) / Geom.M
	var want := 1.0 if length_m > NEAR_M else 0.0
	show = move_toward(show, want, dt * (2.5 if want > show else 4.0))
	_sync(dt)


func _sync(_dt: float) -> void:
	if layer == null or not is_instance_valid(layer):
		return
	var on := floor_on and show > 0.01 and path.size() >= 2 and (path.size() > 2 or length_m > FLOOR_MIN)
	layer.visible = on
	if not on:
		return
	var mat := layer.material as ShaderMaterial
	mat.set_shader_parameter("total", length_m)
	mat.set_shader_parameter("time", _t)
	mat.set_shader_parameter("fade", show)
	mat.set_shader_parameter("tint", UiSkin.ACCENT)
	# rebuilt when the way's bends change, or the drone has moved a metre and a half
	var k := ""
	for i in range(1, path.size()):
		k += "%d,%d;" % [int(path[i].x / 8.0), int(path[i].y / 8.0)]
	if k != _key or _built_from == Vector2.INF or _built_from.distance_to(_from) > 1.5 * Geom.M:
		_key = k
		_built_from = _from
		layer.queue_redraw()


# gone at once (the guide over, a page open)
func hide() -> void:
	show = 0.0
	to = Vector2.INF
	path = PackedVector2Array()
	_sector = -1
	if layer != null and is_instance_valid(layer):
		layer.visible = false


func near() -> bool:
	return to == Vector2.INF or length_m <= NEAR_M


# "往上飞 → " (or "" once close): where the target lies from the drone, eight ways
func prefix() -> String:
	if to == Vector2.INF or _from == Vector2.INF or length_m <= NEAR_M + 3.0:
		return ""
	var a := rad_to_deg((to - _from).angle())
	var s := posmod(int(round(a / 45.0)), 8)
	# sticky: keep the last way until the target is well into the next sector
	if _sector >= 0 and absf(angle_difference(deg_to_rad(a), deg_to_rad(_sector * 45.0))) < deg_to_rad(30.0):
		s = _sector
	_sector = s
	var pair: Array = WAYS[["r", "dr", "d", "dl", "l", "ul", "u", "ur"][s]]
	return str(pair[0] if Txt.zh else pair[1]) + " → "


const WAYS := {
	"r": ["往右飞", "FLY RIGHT"], "dr": ["往右下飞", "FLY DOWN-RIGHT"], "d": ["往下飞", "FLY DOWN"], "dl": ["往左下飞", "FLY DOWN-LEFT"],
	"l": ["往左飞", "FLY LEFT"], "ul": ["往左上飞", "FLY UP-LEFT"], "u": ["往上飞", "FLY UP"], "ur": ["往右上飞", "FLY UP-RIGHT"],
}


# ---------------------------------------------------------------- the way

static func _len(p: PackedVector2Array) -> float:
	var n := 0.0
	for i in range(1, p.size()):
		n += p[i - 1].distance_to(p[i])
	return n


# where a point is: [kind, zone] — "ring", "berth" (inside the berth, under the gate), "box" (in a
# district's shell), "corr" (in a corridor, the berth's own included up to its gate), "open"
static func _where(p: Vector2) -> Array:
	var c := PortStructure.centre()
	var m := PortStructure.M()
	if p.distance_to(c) <= PortArt.HUB_R * m:
		return ["ring", ""]
	var berth := Rect2(Dock.BOUNDS.position * Geom.M, Dock.BOUNDS.size * Geom.M)
	if berth.has_point(p) and p.y > Dock.RAIL_Y * Geom.M:
		return ["berth", "salvage"]
	for zone in PortArt.ANGLE:
		if zone == "salvage":
			continue
		if PortStructure.box(zone).has_point(p):
			return ["box", zone]
	for zone in PortArt.ANGLE:
		var ends := _axis(zone)
		var a: Vector2 = ends[0]
		var b: Vector2 = ends[1]
		var ab := b - a
		var k := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1.0), 0.0, 1.0)
		if k > 0.0 and k < 1.0 and p.distance_to(a + ab * k) <= (PortStructure.half(zone) + 2.0) * m:
			return ["corr", zone]
	return ["open", ""]


# a corridor's middle line: from the ring's rim out to its door (the berth's: to above its gate)
static func _axis(zone: String) -> Array:
	var c := PortStructure.centre()
	var m := PortStructure.M()
	var d: Vector2 = PortStructure.door(zone)[0]
	var dir := (d - c).normalized()
	var a := c + dir * PortArt.HUB_R * m
	if zone == "salvage":
		return [a, Vector2(_gate_x(), Dock.RAIL_Y * Geom.M - 3.0 * Geom.M)]
	return [a, d]


static func _gate_x() -> float:
	return clampf(Dock.centre().x, Dock.TOWER_X + 3.0, Dock.ARM_X1 - 3.0) * Geom.M


static func _proj(zone: String, p: Vector2) -> Vector2:
	var ends := _axis(zone)
	var a: Vector2 = ends[0]
	var ab: Vector2 = ends[1] - a
	return a + ab * clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1.0), 0.0, 1.0)


# the points from p out to its corridor's rim on the ring (the rim last), by where p is
static func _out(p: Vector2, w: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var zone: String = w[1]
	match w[0]:
		"berth":
			# under the gate, through it, then up the berth's corridor
			out.append(Vector2(_gate_x(), maxf(Dock.RAIL_Y * Geom.M + 3.0 * Geom.M, minf(p.y, Dock.RAIL_Y * Geom.M + 6.0 * Geom.M))))
			out.append(_axis("salvage")[1])
		"box":
			var d: Array = PortStructure.door(zone)
			out.append(d[0] + d[1] * 4.0 * PortStructure.M())
			out.append(d[0])
		"corr":
			out.append(_proj(zone, p))
	if w[0] in ["berth", "box", "corr"]:
		out.append(_axis(zone)[0])
	return out


static func _depth(kind: String) -> int:
	return {"corr": 1, "berth": 2, "box": 2}.get(kind, 0)


# the way from a to b as it can be flown: corridors, doors, the gate, the ring's deck
static func route(game, a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array([a])
	var ps = game.get("port_structure") if game != null else null
	if ps == null or not is_instance_valid(ps) or not ps.active():
		pts.append(b)
		return pts
	var wa := _where(a)
	var wb := _where(b)
	if wa[0] == "open" or wb[0] == "open" or wa == wb:
		pts.append(b)
		return pts
	var oa := _out(a, wa)
	var ob := _out(b, wb)
	if wa[1] != "" and wa[1] == wb[1]:
		# the same district (its corridor and its shell, or the berth and its corridor): only as far
		# out as the shallower one
		if _depth(wa[0]) > _depth(wb[0]):
			oa.resize(oa.size() - 1)
			pts.append_array(oa)
		elif _depth(wa[0]) < _depth(wb[0]):
			ob.resize(ob.size() - 1)
			ob.reverse()
			pts.append_array(ob)
		pts.append(b)
		return _tidy(pts)
	pts.append_array(oa)
	if wa[0] != "ring" and wb[0] != "ring":
		# rim to rim round the ring's deck, the short way
		var c := PortStructure.centre()
		var m := PortStructure.M()
		var a0 := (oa[oa.size() - 1] - c).angle()
		var a1 := (ob[ob.size() - 1] - c).angle()
		var span := angle_difference(a0, a1)
		var n := maxi(2, int(absf(span) / deg_to_rad(9.0)))
		for i in n + 1:
			pts.append(c + Vector2.from_angle(a0 + span * float(i) / n) * DECK_R * m)
	var rb := ob.duplicate()
	rb.reverse()
	pts.append_array(rb)
	pts.append(b)
	return _tidy(pts)


# no point a metre from the last
static func _tidy(p: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in p:
		if out.is_empty() or out[out.size() - 1].distance_to(q) > 1.0 * Geom.M:
			out.append(q)
	if out[out.size() - 1] != p[p.size() - 1]:
		out[out.size() - 1] = p[p.size() - 1]
	return out


# ---------------------------------------------------------------- the floor

# the chevrons laid back from the target, so they stay put as the drone flies; UV.x is the metres
# from each to the target (the shader's wave and both ends' fades run on it)
func _draw_floor() -> void:
	if path.size() < 2:
		return
	var M := Geom.M
	var total := _len(path)
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var hw := 0.78 * M          # half the chevron's width
	var deep := 0.55 * M        # how far its arms sweep back
	var th := 0.2 * M           # the arms' thickness (the shader feathers both edges)
	# the segments, from the target back
	var seg_len := PackedFloat32Array()
	for i in range(1, path.size()):
		seg_len.append(path[i - 1].distance_to(path[i]))
	var s := 2.2 * M            # from the target
	while s < total - 1.0 * M:
		# the point s back from the target, and the way's direction there
		var left := total - s
		var acc := 0.0
		var i := 0
		while i < seg_len.size() - 1 and acc + seg_len[i] < left:
			acc += seg_len[i]
			i += 1
		var p0 := path[i]
		var p1 := path[i + 1]
		var dir := (p1 - p0).normalized()
		var at := p0 + dir * (left - acc)
		var side := dir.orthogonal()
		var tip := at + dir * deep * 0.5
		var dm := s / M
		# twice: a wider dark shadow first (UV.y 2..3), then the lit arm (UV.y 0..1, edge to edge)
		for pass_i in 2:
			var grow := 0.09 * M if pass_i == 0 else 0.0
			for sg in [1.0, -1.0]:
				var o: Vector2 = side * hw * float(sg)
				var back: Vector2 = tip - dir * deep + o
				var n: Vector2 = (back - tip).normalized().orthogonal() * (th * 0.5 + grow) * float(sg)
				var ext: Vector2 = (back - tip).normalized() * grow
				var q := [tip - n - ext, back - n + ext, back + n + ext, tip + n - ext]
				var vy := [0.0, 0.0, 1.0, 1.0]
				for idx in [0, 1, 2, 0, 2, 3]:
					verts.append(q[idx])
					cols.append(Color.WHITE)
					uvs.append(Vector2(dm, float(vy[idx]) + (2.0 if pass_i == 0 else 0.0)))
		s += SPACING * M
	if verts.is_empty():
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	# kept: the canvas holds only the mesh's id, a mesh freed with this call would draw nothing
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	layer.draw_mesh(_mesh, null)


const SHADER := """
shader_type canvas_item;
render_mode blend_mix, unshaded;
uniform float total = 100.0;     // m of way left now
uniform float time = 0.0;
uniform float fade = 1.0;
uniform vec4 tint : source_color = vec4(1.0, 0.5, 0.2, 1.0);
void fragment() {
	float d = UV.x;                       // m from this chevron to the target
	float from_drone = total - d;
	// not under the drone, not on the target's brackets
	float a = smoothstep(1.5, 6.0, from_drone) * smoothstep(1.0, 4.0, d) * fade;
	// a bright wave running towards the target, every 22 m
	float w = fract(d / 22.0 + time * 0.55);
	float band = pow(w, 10.0);
	if (UV.y > 1.5) {
		// the shadow under the arm: it reads on the bright machines as well as on the dark floor
		float e = 1.0 - abs((UV.y - 2.0) * 2.0 - 1.0);
		COLOR = vec4(0.0, 0.0, 0.0, a * 0.4 * smoothstep(0.0, 0.5, e));
	} else {
		// feathered edges, the middle of the arm brightest
		float e = 1.0 - abs(UV.y * 2.0 - 1.0);
		float body = smoothstep(0.0, 0.3, e);
		vec3 c = mix(tint.rgb, vec3(1.0, 0.93, 0.85), 0.55 * band + 0.25 * smoothstep(0.5, 1.0, e) * band);
		COLOR = vec4(c, a * body * (0.5 + 0.5 * band));
	}
}
"""


# ---------------------------------------------------------------- the edge of the screen

# the target off the screen: a big arrow at the edge where it lies, its name and the metres left.
# avoid: a screen rect to keep out of (the guide's card)
func draw_edge(ci: CanvasItem, label: String, col: Color, avoid := Rect2()) -> void:
	if to == Vector2.INF or show <= 0.01:
		return
	var xf := ci.get_canvas_transform()
	var vs := ci.get_viewport_rect().size
	var sp: Vector2 = xf * to
	# the safe frame: off the top bar, the tool row and the minimap at the bottom
	var inner := Rect2(Vector2(96.0, 96.0), vs - Vector2(192.0, 96.0 + 190.0))
	if inner.grow(40.0).has_point(sp):
		return
	var mid := inner.get_center()
	var d := (sp - mid).normalized()
	# where the line from the middle to the target leaves the safe frame
	var kx := (inner.size.x * 0.5) / maxf(absf(d.x), 0.0001)
	var ky := (inner.size.y * 0.5) / maxf(absf(d.y), 0.0001)
	var at := mid + d * minf(kx, ky)
	var a := show
	var pulse := 0.5 + 0.5 * sin(_t * 3.4)
	ci.draw_set_transform_matrix(xf.affine_inverse())
	# the arrow: a big solid head with two chevrons trailing it, pushing outward
	var side := d.orthogonal()
	var push := 6.0 * pulse
	var tip := at + d * (22.0 + push)
	var base := tip - d * 40.0
	var head := PackedVector2Array([tip, base + side * 25.0, base + d * 10.0, base - side * 25.0])
	var dark := Color(0.02, 0.022, 0.028, 0.8 * a)
	ci.draw_colored_polygon(PackedVector2Array([head[0] + d * 3.0, head[1] + side * 3.0 - d * 2.0, head[2] - d * 2.0, head[3] - side * 3.0 - d * 2.0]), dark)
	FastDraw.poly(ci, PackedVector2Array([head[0], head[1], head[2]]), Color(col, a))
	FastDraw.poly(ci, PackedVector2Array([head[0], head[2], head[3]]), Color(col, a))
	for k in 2:
		var c0 := base - d * (14.0 + k * 16.0)
		var ca := a * (0.75 - 0.3 * k) * (0.6 + 0.4 * pulse)
		var chev := PackedVector2Array([c0 - side * 17.0 - d * 12.0, c0, c0 + side * 17.0 - d * 12.0])
		ci.draw_polyline(chev, Color(0, 0, 0, 0.5 * a), 6.0)
		ci.draw_polyline(chev, Color(col, ca), 3.0)
	# the plate: name · metres, on the inner side of the arrow, kept on the screen and off the card
	var font: Font = Fonts.get_font("Medium")
	var fs := 18
	var txt := label + (" · 还有 %d m" if Txt.zh else " · %d m TO GO") % int(round(length_m))
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var size := Vector2(tw + 34.0, 34.0)
	# beside the arrow, never on it: as far in as the arrow's tail and half the plate along the line
	var pc := at - d * (60.0 + absf(d.x) * size.x * 0.5 + absf(d.y) * size.y * 0.5)
	var pos := pc - size * 0.5
	pos.x = clampf(pos.x, 16.0, vs.x - size.x - 16.0)
	pos.y = clampf(pos.y, 16.0, vs.y - size.y - 16.0)
	var r := Rect2(pos, size)
	if avoid.size != Vector2.ZERO and r.intersects(avoid.grow(8.0)):
		# under the card if it is up there, else beside it
		if avoid.end.y + 12.0 + size.y < vs.y:
			r.position.y = avoid.end.y + 12.0
		else:
			r.position.x = avoid.position.x - size.x - 12.0
	ci.draw_rect(r, Color(0.02, 0.022, 0.028, 0.95 * a))
	ci.draw_rect(Rect2(r.position, Vector2(3.0, r.size.y)), Color(col, a))
	ci.draw_rect(r, Color(col.r, col.g, col.b, 0.45 * a), false, 1.0)
	ci.draw_string(font, r.position + Vector2(16.0, 24.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Pal.ink(0.96), a))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
