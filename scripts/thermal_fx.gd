extends Node2D
# EV-55's hull seen hot — drawing only, scripts/thermal.gd keeps every number
# (design/机制动画缺口_20261110.md: "820 °C and the tiles look like any plate").
#   Every part still on the ship in a zone glows with its zone's temperature: dull red
#   from about 250 °C, orange-yellow at the shield's 820 °C, a slow flicker across it (no
#   heat haze: there is no air to rise in). As a zone cools (faster with the berth's cooling
#   loop) its glow dies down with it; at a safe heat nothing shows.
# Additive over the strips; the parts' triangles kept until the ship changes (world.gone_n).

const GLOW_FROM := 240.0      # °C where the glow starts to show
const GLOW_FULL := 850.0

var th
var game
var world
var _cache := {}              # zone -> [verts, idx, per-vertex phase, outline segs]
var _sig := -1
var _t := 0.0


func setup(t) -> void:
	th = t
	game = t.game
	world = t.world
	z_index = 4
	z_as_relative = false
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	world.add_child(self)


func _rebuild() -> void:
	_cache.clear()
	for id in world.order:
		var p = world.pieces[id]
		if p.gone or p.body != null or p.poly.size() < 3:
			continue
		var z: String = th.zone_of(p)
		if z == "":
			continue
		if not _cache.has(z):
			_cache[z] = [PackedVector2Array(), PackedInt32Array(), PackedFloat32Array(), PackedVector2Array()]
		var e: Array = _cache[z]
		var tri := Geometry2D.triangulate_polygon(p.poly)
		if tri.is_empty():
			continue
		var base: int = (e[0] as PackedVector2Array).size()
		# equipment inside holds less of the heat than the plates outside
		var w := 0.45 if p.cls == "equip" else 1.0
		for v in p.poly:
			e[0].append(v)
			e[2].append(w * 1000.0 + fposmod(v.x * 0.013 + v.y * 0.007, TAU))
		for k in tri:
			e[1].append(base + k)
		var n: int = p.poly.size()
		for i in n:
			e[3].append(p.poly[i])
			e[3].append(p.poly[(i + 1) % n])


func _process(dt: float) -> void:
	if th == null or not th.active():
		return
	if not (game.paused_sim or game.state != "play"):
		_t += dt
	var sig: int = world.gone_n * 7919 + world.order.size()
	if sig != _sig:
		_sig = sig
		_rebuild()
	queue_redraw()


static func glow_k(T: float) -> float:
	return clampf((T - GLOW_FROM) / (GLOW_FULL - GLOW_FROM), 0.0, 1.0)


# the colour of metal at a heat: dull red, cherry, orange, toward yellow
static func glow_col(k: float) -> Color:
	var dull := Color(0.55, 0.06, 0.02)
	var cherry := Color(0.95, 0.18, 0.05)
	var orange := Color(1.0, 0.5, 0.14)
	if k < 0.5:
		return dull.lerp(cherry, k / 0.5)
	return cherry.lerp(orange, (k - 0.5) / 0.5)


func _draw() -> void:
	if th == null or not th.active():
		return
	for z in _cache:
		var k := glow_k(th.zone_temp(z))
		if k <= 0.001:
			continue
		var e: Array = _cache[z]
		var verts: PackedVector2Array = e[0]
		var ph: PackedFloat32Array = e[2]
		var cols := PackedColorArray()
		cols.resize(verts.size())
		var base := glow_col(k)
		for i in verts.size():
			var wk: float = 1.0 if ph[i] >= 1000.0 else 0.45
			var fl := 0.86 + 0.14 * sin(_t * 1.7 + fposmod(ph[i], 1000.0) * 3.0)
			var a := (0.10 + 0.42 * k) * fl * wk
			cols[i] = Color(base.r, base.g, base.b, a)
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), e[1], verts, cols)
		# the edges brighter: they shed the heat
		draw_multiline(e[3], Color(base.r, base.g * 1.2, base.b, 0.22 + 0.5 * k), 1.2)
