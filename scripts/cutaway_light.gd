extends Node2D
# 工业剖面: local light on the metal, drawn additive over the cached ship strips (which are not
# touched). Only while Pal.solid is on.
#  - the laser's front while cutting: the plates within a few metres catch a warm light on their
#    faces and their edges glow, falling off with distance and flickering with the arc (every frame)
#  - (v2, user 2026-11-10 "克制") the standing lights: a lit work lamp lights the edges of the
#    structure round it, a heavy machine with power shows a small status light that touches its
#    own corner, an engine's hot end warms the edges beside it. Redrawn only when what is lit
#    changes (a child node), so standing still costs nothing.

const R := 4.5 * 48.0       # px: how far the laser's light reaches
const LAMP_R := 3.4 * 48.0  # px: a work lamp's reach on the structure
const ENGINE_R := 2.2 * 48.0
const LAMP_C := Color(1.0, 0.93, 0.82)
const LaserSkin = preload("res://scripts/drone_skins.gd")   # the laser light in the airframe's beam colour
const LED := {"engine": Color(1.0, 0.62, 0.25), "reactor": Color(1.0, 0.62, 0.25), "tank": Color(0.56, 0.83, 0.9),
	"pipe": Color(0.56, 0.83, 0.9), "cargo": Color(0.62, 0.88, 0.62)}

var world
var _was := false
var _t := 0.0
var stand: Node2D
var _sig := 0
var _chk := 0
static var stand_draws := 0     # tests: how often the standing lights redrew
static var stand_us := 0


func _init() -> void:
	z_index = 4
	z_as_relative = false
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	stand = Node2D.new()
	stand.show_behind_parent = true
	stand.use_parent_material = true
	stand.draw.connect(_draw_stand)
	add_child(stand)


func _on() -> bool:
	if not Pal.solid or world == null or world.game == null:
		return false
	var tl = world.game.tools
	return tl != null and tl.cutting


func _process(dt: float) -> void:
	if Cutaway.skip.has("light"):
		visible = false
		return
	_t += dt
	var on := _on()
	if on or _was:
		queue_redraw()
	_was = on
	# the standing lights: look again a few times a second whether what is lit has changed
	_chk -= 1
	if _chk <= 0:
		_chk = 12
		var s := _stand_sig()
		if s != _sig:
			_sig = s
			stand.queue_redraw()


func _stand_sig() -> int:
	if not Pal.solid or world == null or world.game == null or world.game.sys == null:
		return 0
	var h := [world.order.size(), world.rooms.size()]
	for n in world.rooms:
		var r = world.rooms[n]
		h.append(r.revealed)
		h.append(r.get("lit", false))
	var lamps: Dictionary = world.game.ship.get("power", {}).get("lamps", {})
	for n in lamps:
		var l = world.tag(lamps[n])
		h.append(l != null and l.body == null and l.get_meta("lit", false))
	return hash(h)


func _near(f: Vector2, r: float) -> Array:
	var near: Array = []
	var ch: float = world.CHUNK
	for i in range(int(floor((f.x - r) / ch)), int(floor((f.x + r) / ch)) + 1):
		near.append_array(world._chunk_lists.get(i, []))
	return near


func _visible(p) -> bool:
	if p.gone or p.body != null:
		return false
	return not (p.room != "" and world.rooms.has(p.room) and not world.rooms[p.room].revealed)


# the edges of the structure near f, lit by a light of colour c, falling off over r
func _edges(segs: PackedVector2Array, sc: PackedColorArray, f: Vector2, r: float, c: Color, peak: float, skip = null) -> void:
	var reach := Rect2(f - Vector2(r, r), Vector2(r, r) * 2.0)
	for p in _near(f, r):
		if p == skip or not _visible(p):
			continue
		var poly: PackedVector2Array = p.poly
		if not Geom.bbox(poly).intersects(reach):
			continue
		var n := poly.size()
		for i in n:
			var a := poly[i]
			var b := poly[(i + 1) % n]
			var d := Geometry2D.get_closest_point_to_segment(f, a, b).distance_to(f)
			var k := clampf(1.0 - d / r, 0.0, 1.0)
			if k <= 0.03:
				continue
			# an edge facing the light catches it; one edge-on to it barely
			var nrm := (b - a).orthogonal().normalized()
			var face := absf(nrm.dot((f - (a + b) * 0.5).normalized()))
			segs.append(a)
			segs.append(b)
			sc.append(Color(c.r, c.g, c.b, peak * k * k * (0.3 + 0.7 * face)))


func _draw_stand() -> void:
	stand_draws += 1
	var t0 := Time.get_ticks_usec()
	_draw_stand_inner()
	stand_us += Time.get_ticks_usec() - t0


func _draw_stand_inner() -> void:
	if not Pal.solid or world == null or world.game == null or world.game.sys == null:
		return
	var tex: Texture2D = world.game.fx.glow_tex
	var segs := PackedVector2Array()
	var sc := PackedColorArray()
	var any_lit := false
	# work lamps
	var lamps: Dictionary = world.game.ship.get("power", {}).get("lamps", {})
	for n in lamps:
		var lamp = world.tag(lamps[n])
		if lamp == null or lamp.body != null:
			continue
		if world.rooms.has(n):
			if not world.rooms[n].revealed or not world.rooms[n].lit:
				continue
		elif not lamp.get_meta("lit", false):
			continue
		any_lit = true
		var c := Geom.centroid(lamp.poly)
		_edges(segs, sc, c, LAMP_R, LAMP_C, 0.22, lamp)
	# status lights on the heavy machines that have power, and the engines' warm ends
	for id in world.order:
		var p = world.pieces[id]
		if p.cls != "equip" or not _visible(p) or not p.intact:
			continue
		var m := Cutaway.material(p)
		if not LED.has(m):
			continue
		var bb := Geom.bbox(p.poly)
		if bb.size.x < 24.0 or bb.size.y < 16.0:
			continue
		var powered: bool = any_lit if p.room == "" or not world.rooms.has(p.room) else bool(world.rooms[p.room].get("lit", false))
		if powered:
			var at := Vector2(bb.end.x - 6.0, bb.position.y + 6.0)
			var lc: Color = LED[m]
			stand.draw_texture_rect(tex, Rect2(at - Vector2(16, 16), Vector2(32, 32)), false, Color(lc.r, lc.g, lc.b, 0.22))
			stand.draw_rect(Rect2(at - Vector2(1.5, 1.5), Vector2(3, 3)), Color(lc.r * 1.4, lc.g * 1.4, lc.b * 1.4, 0.95))
			_edges(segs, sc, at, 1.1 * 48.0, lc, 0.1, p)
		if p.art in ["nozzle", "eng_core"]:
			_edges(segs, sc, Geom.centroid(p.poly), ENGINE_R, Pal.HEAT, 0.12, p)
	if not segs.is_empty():
		stand.draw_multiline_colors(segs, sc, 1.6)


func _draw() -> void:
	if not _on():
		return
	var f: Vector2 = world.game.tools.front
	var flick := 0.86 + 0.1 * sin(_t * 47.0) + 0.06 * sin(_t * 113.0)
	var fp := PackedVector2Array()
	var fc := PackedColorArray()
	var fi := PackedInt32Array()
	var segs := PackedVector2Array()
	var sc := PackedColorArray()
	var reach := Rect2(f - Vector2(R, R), Vector2(R, R) * 2.0)
	# 60 FPS: only the strips the light reaches (ARK-01 has thousands of pieces)
	for p in _near(f, R):
		if not _visible(p):
			continue
		var poly: PackedVector2Array = p.poly
		if not Geom.bbox(poly).intersects(reach):
			continue
		var tri: PackedInt32Array = world._tri_cached(p)
		if not tri.is_empty():
			var base := fp.size()
			fp.append_array(poly)
			for v in poly:
				var k := clampf(1.0 - v.distance_to(f) / R, 0.0, 1.0)
				fc.append(LaserSkin.lheat(0.16 * k * k * flick, 1.0))
			for i in tri:
				fi.append(base + i)
	_edges(segs, sc, f, R, LaserSkin.lheat(1.0, 1.6), 0.75 * flick)
	if not fi.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), fi, fp, fc)
	if not segs.is_empty():
		draw_multiline_colors(segs, sc, 2.0)
	var tex: Texture2D = world.game.fx.glow_tex
	draw_texture_rect(tex, Rect2(f - Vector2(R, R) * 0.7, Vector2(R, R) * 1.4), false, LaserSkin.lheat(0.12 * flick, 1.0))
	draw_texture_rect(tex, Rect2(f - Vector2(30, 30), Vector2(60, 60)), false, LaserSkin.lheat(0.5 * flick, 1.6))
