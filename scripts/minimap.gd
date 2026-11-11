extends Control
const FastDraw = preload("res://scripts/fast_draw.gd")
# P.6 (player 2026-10-17: "I can't see the whole ship; hauling something big I
# can't see the mouth I'm going to"): a map of the berth that stays on screen,
# bottom right. The ship as it stands (rooms nobody has opened stay dark
# blocks), what is loose, the three mouths where they sit on their rails, the
# drone, what it hauls and the line to where that goes, and the frame of the
# view. The ship layer is redrawn only when the ship changes; the rest a few
# times a second.

const W := 330.0
const PAD := 12.0             # 炭黑: room for the bezel round the black window
const SHIP_EVERY := 0.5       # s between checks that the ship changed
const LIVE_EVERY := 1.0 / 20.0

var game
var ship_layer: Control
var live_layer: Control
var origin := Vector2.ZERO    # m: the map's top left in the berth
var scale_m := 1.0            # px per m
var map_size := Vector2(W, 120.0)
var _cache := {}              # piece id (or "room:name") -> {h, s, pts, tri, col}
var _pts := PackedVector2Array()
var _cols := PackedColorArray()
var _idx := PackedInt32Array()
var _ship_sig := []
var _ship_t := 99.0
var _live_t := 99.0
var t := 0.0
# 68 号 §6: what the map shows follows where the drone is — the berth, the station's halls and
# corridors, or the space round the station (in the work boat or out past the shells)
var mode := "berth"
var port_layer: Control
var _port_origin := Vector2.ZERO     # world px at the map's top left
var _port_k := 1.0                   # map px per world px
var _port_t := 99.0
# 109 号 (user 2026-10-29: "右下角的小地图也一并优化得酷炫一点"): the station drawn as a tactical map —
# what stands still (the districts, the corridors, the hub, the rails, the words) on a layer redrawn
# only when it changes, what moves (the sweep, the power going down the corridors, the carousel, the
# shuttle and its trail, the drone and its view) on its own layer thirty times a second
var port_live: Control
var _port_sig := ""
var _trail: Array = []               # the shuttle's last places, map px
var draw_us := 0.0                   # tests: the moving layer's drawing (µs, smoothed)
const PORT_EVERY := 1.0 / 30.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ship_layer = Control.new()
	ship_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ship_layer.draw.connect(_draw_ship)
	add_child(ship_layer)
	live_layer = Control.new()
	live_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	live_layer.draw.connect(_draw_live)
	add_child(live_layer)
	port_layer = Control.new()
	port_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	port_layer.draw.connect(_draw_port)
	port_layer.visible = false
	add_child(port_layer)
	port_live = Control.new()
	port_live.mouse_filter = Control.MOUSE_FILTER_IGNORE
	port_live.draw.connect(_draw_port_live)
	port_live.visible = false
	add_child(port_live)


# the berth's frame in metres, and the scale that fits it to the map's width
func layout() -> void:
	# from just over the boom down to the floor: nothing works above the boom
	var top := Dock.RAIL_Y - 1.4
	var r := Rect2(Dock.TOWER_X - 1.0, top, Dock.FLOOR_X1 - Dock.TOWER_X + 3.0, Dock.FLOOR_Y + 1.0 - top)
	origin = r.position
	scale_m = (W - PAD * 2.0) / r.size.x
	map_size = Vector2(W, r.size.y * scale_m + PAD * 2.0 + TITLE_H)
	size = map_size
	ship_layer.size = map_size
	live_layer.size = map_size


func to_map(w: Vector2) -> Vector2:
	return (w / Geom.M - origin) * scale_m + Vector2(PAD, PAD)


func _process(dt: float) -> void:
	t += dt
	if game == null or game.world == null:
		return
	var m := where()
	if m != mode:
		mode = m
		ship_layer.visible = mode == "berth"
		live_layer.visible = mode == "berth"
		port_layer.visible = mode != "berth"
		port_live.visible = mode != "berth"
		_port_sig = ""
		if mode == "berth":
			layout()
		else:
			_layout_port()
	if mode != "berth":
		_port_t += dt
		if _port_t >= PORT_EVERY:
			_port_t = 0.0
			var sig := _port_signature()
			if sig != _port_sig:
				_port_sig = sig
				port_layer.queue_redraw()
			port_live.queue_redraw()
		return
	_ship_t += dt
	if _ship_t >= SHIP_EVERY:
		_ship_t = 0.0
		var w = game.world
		var sig := [w.pieces.size(), w.bodies.size(), Dock.FLOOR_X1]
		var gone := 0
		var shown := 0
		for id in w.pieces:
			var p = w.pieces[id]
			if p.gone:
				gone += 1
		for n in w.rooms:
			if w.rooms[n].revealed:
				shown += 1
		sig.append_array([gone, shown])
		if sig != _ship_sig:
			_ship_sig = sig
			_rebuild_ship()
	_live_t += dt
	if _live_t >= LIVE_EVERY:
		_live_t = 0.0
		live_layer.queue_redraw()


func _rebuild_ship() -> void:
	layout()
	var w = game.world
	var keep := {}
	var parts: Array = []
	for n in w.rooms:
		var r: Dictionary = w.rooms[n]
		if not r.revealed:
			parts.append(_part("room:" + n, r.poly, Color(0.11, 0.115, 0.13, 0.95), keep))
	for id in w.pieces:
		var p = w.pieces[id]
		if p.gone or p.body != null or w.room_hidden(p.room):
			continue
		var col := Pal.ink(0.2)
		if p.cls == "equip" and p.intact:
			col = Pal.ink(0.55)
		elif p.kind in ["keel", "beam", "rail"]:
			col = Pal.ink(0.32)
		parts.append(_part(id, w.world_poly(p), col, keep))
	_cache = keep
	# one triangle list for the lot: a single draw call, triangulated once per piece
	_pts = PackedVector2Array()
	_cols = PackedColorArray()
	_idx = PackedInt32Array()
	for e in parts:
		if e.tri.is_empty():
			continue
		var base := _pts.size()
		_pts.append_array(e.pts)
		for i in e.pts.size():
			_cols.append(e.col)
		for i in e.tri:
			_idx.append(base + i)
	ship_layer.queue_redraw()


# a piece (or a dark room) in map px, triangulated; reused while it hasn't changed
func _part(key, poly: PackedVector2Array, col: Color, keep: Dictionary) -> Dictionary:
	var h := hash(poly)
	var e: Dictionary = _cache.get(key, {})
	if e.is_empty() or e.h != h or e.s != scale_m:
		var mp := Geom.simplify(_map_poly(poly), 0.5)
		if mp.size() < 3:
			mp = _map_poly(poly)
		e = {"h": h, "s": scale_m, "pts": mp, "tri": Geometry2D.triangulate_polygon(mp), "col": col}
	e.col = col
	keep[key] = e
	return e


# a loose piece's triangles, corner by corner in its own frame (none for an outline that crosses
# itself), kept until its shape changes
func _tris(p) -> PackedVector2Array:
	var sig: int = p.poly.size() * 7919 + p.cut_seq
	if p.get_meta("mm_sig", -1) != sig:
		var out := PackedVector2Array()
		if p.poly.size() >= 3:
			for i in Geometry2D.triangulate_polygon(p.poly):
				out.append(p.poly[i])
		p.set_meta("mm_sig", sig)
		p.set_meta("mm_tri", out)
	return p.get_meta("mm_tri")


func _map_poly(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(poly.size())
	for i in poly.size():
		out[i] = to_map(poly[i])
	return out


func _draw_ship() -> void:
	_bezel(ship_layer)
	# the berth: floor, boom and rail, trough
	var fl0 := to_map(Vector2(Dock.TOWER_X, Dock.FLOOR_Y) * Geom.M)
	var fl1 := to_map(Vector2(Dock.FLOOR_X1, Dock.FLOOR_Y) * Geom.M)
	ship_layer.draw_line(fl0, fl1, Pal.ink(0.35), 1.4)
	ship_layer.draw_line(to_map(Vector2(Dock.TOWER_X, Dock.RAIL_Y) * Geom.M), to_map(Vector2(Dock.equip_rail_x1() + 2.6, Dock.RAIL_Y) * Geom.M), Pal.ink(0.3), 1.2)
	ship_layer.draw_line(to_map(Vector2(Dock.TOWER_X + 0.3, -12.6) * Geom.M), fl0, Pal.ink(0.3), 1.4)
	var tr0 := to_map(Vector2(Dock.TROUGH_X0, Dock.TROUGH_Y) * Geom.M)
	var tr1 := to_map(Vector2(Dock.TROUGH_X1, Dock.TROUGH_Y) * Geom.M)
	ship_layer.draw_line(tr0, tr1, Pal.ink(0.22), 1.0)
	if not _idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ship_layer.get_canvas_item(), _idx, _pts, _cols)
	# 109 号: the same corners and title strip, with a scale, as the station's map
	_frame(ship_layer, game.txt("minimap"), scale_m)


func _draw_live() -> void:
	if game == null or game.world == null:
		return
	var ci := live_layer
	var w = game.world
	var tl = game.tools
	# world to map, as to_map() has it
	var k := scale_m / Geom.M
	var map_xf := Transform2D(Vector2(k, 0.0), Vector2(0.0, k), Vector2(PAD, PAD) - origin * scale_m)
	var soup := PackedVector2Array()
	# loose bodies, live
	for b in w.bodies:
		if not is_instance_valid(b):
			continue
		var held: bool = tl != null and tl.held_body == b
		var col := Pal.ink(0.75)
		if held:
			col = Dock.zone_col(game.hud._zone_for(b), 1.0, 1.3)
		if not held:
			# 60 FPS (2026-10-27): each piece's triangles worked out once per shape, all of them
			# sent as one array (a polygon call per piece costs the renderer a buffer of its own:
			# 250 loose pieces took 5 ms every third frame)
			var xf: Transform2D = map_xf * b.global_transform
			for p in b.pieces:
				if not p.door:
					soup.append_array(xf * _tris(p))
			continue
		for p in b.pieces:
			var mp := _map_poly(w.world_poly(p))
			# a sliver too thin for the map (a torn film panel at this scale) would not triangulate
			if mp.size() >= 3 and not Geometry2D.triangulate_polygon(mp).is_empty():
				FastDraw.poly(ci, mp, Color(col.r, col.g, col.b, 0.5 if held else 0.35))
				if held:
					var ol := mp.duplicate()
					ol.append(mp[0])
					FastDraw.polyline(ci, ol, col, 1.2, true)
	if not soup.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), PackedInt32Array(), soup, PackedColorArray([Color(Pal.ink(0.75), 0.35)]))
	# the mouths where they sit
	for id in Dock.ZONES:
		var mp := to_map(Dock.zpos(id))
		var f: Vector2 = Dock.ZONES[id].face
		var side := Vector2(-f.y, f.x)
		var hw: float = Dock.ZONES[id].w * 0.5 * scale_m + 2.0
		var col := Dock.zone_col(id, 0.95, 1.2)
		FastDraw.poly(ci, PackedVector2Array([mp + side * hw, mp - side * hw, mp - side * hw * 0.5 - f * 5.0, mp + side * hw * 0.5 - f * 5.0]), col)
	# what is hauled: a line to where it goes
	if tl != null and tl.held_body != null and is_instance_valid(tl.held_body) and not tl.overweight:
		var zone: String = game.hud._zone_for(tl.held_body)
		var from := to_map(tl.held_body.global_transform * tl.held_body.center_of_mass)
		var to := to_map(Dock.zpos(zone))
		var col := Dock.zone_col(zone, 0.9, 1.3)
		var n := int(from.distance_to(to) / 6.0)
		var ph := fposmod(t * 2.0, 1.0)
		for i in n:
			if i % 2 == 0:
				var a := from.lerp(to, (i + ph) / maxf(1.0, n))
				var b2 := from.lerp(to, minf(1.0, (i + 1 + ph) / maxf(1.0, n)))
				ci.draw_line(a, b2, col, 1.8)
		# the target: an orange ring breathing round the mouth it goes to, a lamp at its heart
		FastDraw.arc(ci, to, 6.0 + 2.0 * sin(t * 6.0), 0.0, TAU, 16, Color(Charcoal.ACCENT, 0.9), 1.4, true)
		Charcoal.led(ci, to, true, 1.0, 2.4)
	# the view
	var vs: Vector2 = get_viewport_rect().size
	var cam = game.cam
	if cam != null and cam.zoom.x > 0.0:
		var half: Vector2 = vs * 0.5 / cam.zoom.x
		var r := Rect2(to_map(cam.global_position - half), (half * 2.0) / Geom.M * scale_m)
		r = r.intersection(window_rect().grow(-1.0))
		if r.has_area():
			ci.draw_rect(r, Color(1, 1, 1, 0.22), false, 1.0)
	# the drone
	if game.drone != null:
		var dp := to_map(game.drone.global_position)
		var pulse := 0.5 + 0.5 * sin(t * 5.0)
		# 炭黑: you are the orange mark, its heading an arrow (as on the station's map)
		var v: Vector2 = game.drone.linear_velocity
		var dir := v.normalized() if v.length() > 8.0 else Vector2.UP.rotated(game.drone.rotation)
		FastDraw.circle(ci, dp, 5.0 + 3.0 * pulse, Color(Charcoal.ACCENT, 0.16 * (1.0 - pulse)))
		FastDraw.poly(ci, PackedVector2Array([dp + dir * 6.5, dp + dir.orthogonal() * 3.4 - dir * 2.8, dp - dir.orthogonal() * 3.4 - dir * 2.8]), Charcoal.ACCENT)




# ---------------------------------------------------------------- the station (68 号 §6)

static func berth_px() -> Rect2:
	return Rect2(Dock.BOUNDS.position * Geom.M, Dock.BOUNDS.size * Geom.M)


# "berth", "port" (in the station's halls and corridors) or "outside" (the boat, open space)
func where() -> String:
	if game == null or game.drone == null:
		return "berth"
	if game.boat != null and is_instance_valid(game.boat) and game.boat.aboard:
		return "outside"
	if not game.in_berth() or not game.career():
		return "berth"
	var p: Vector2 = game.drone.global_position
	if berth_px().has_point(p):
		return "berth"
	if PortStructure.zone_at(p) != "" or _corridor(p):
		return "port"
	return "outside"


# on a spoke between the hub and a district's door
func _corridor(p: Vector2) -> bool:
	var c := PortStructure.centre()
	var m := PortStructure.M()
	for zone in Port.ZONES:
		if zone in ["ring", "salvage"]:
			continue
		var d: Array = PortStructure.door(zone)
		var a: Vector2 = c + (d[0] - c).normalized() * PortArt.HUB_R * m
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, a, d[0])
		if q.distance_to(p) <= (PortStructure.HALF + 1.0) * m:
			return true
	return false


func _station_rect() -> Rect2:
	var r := Rect2(PortStructure.centre(), Vector2.ZERO)
	for zone in Port.ZONES:
		if zone in ["ring", "salvage"]:
			continue
		r = r.merge(PortStructure.box(zone))
	return r.merge(berth_px())


func _layout_port() -> void:
	var r := _station_rect().grow(6.0 * Geom.M)
	if mode == "outside":
		r = r.grow(r.size.x * 0.35)
		if game.drone != null:
			r = r.expand(game.drone.global_position).grow(20.0 * Geom.M)
	_port_k = minf((W - PAD * 2.0) / r.size.x, 240.0 / r.size.y)
	_port_origin = r.position
	map_size = Vector2(W, r.size.y * _port_k + PAD * 2.0 + TITLE_H)
	size = map_size
	for n in [port_layer, port_live]:
		n.size = map_size
		n.clip_contents = true
	_port_sig = ""
	_trail.clear()


const TITLE_H := 18.0


func pmap(w: Vector2) -> Vector2:
	return (w - _port_origin) * _port_k + Vector2(PAD, PAD)


func _here() -> String:
	return PortStructure.zone_at(game.drone.global_position) if game.drone != null else ""


func _see_through() -> bool:
	# 2026-11-10 炭黑 (user: "右下角的扫描也很难看"): the map is a solid instrument now, on site too —
	# the scene (trusses, rails, the mouths' signs) no longer shows through it
	return false


# the map's body: a charcoal bezel with its thickness and shadow, a black window inside it, the
# title and the scale engraved on the bezel's foot
func window_rect() -> Rect2:
	return Rect2(Vector2(5, 5), map_size - Vector2(10, 10 + TITLE_H))


func _bezel(ci: CanvasItem) -> void:
	Charcoal.panel(ci, Rect2(Vector2.ZERO, map_size), 1.0, 0.0, Charcoal.FACE, 9)
	Charcoal.display(ci, window_rect(), 1.0, 5)


# what the still layer shows; a change redraws it
func _port_signature() -> String:
	var st := []
	for z in Port.ZONES:
		st.append(Port.stage(z))
	if mode == "outside" and game.drone != null and not berth_px().has_point(game.drone.global_position):
		# keep the drone in the frame as it flies about
		var dp := pmap(game.drone.global_position)
		if not Rect2(Vector2(PAD, PAD), map_size - Vector2(PAD, PAD) * 2.0).has_point(dp):
			_layout_port()
	return "%s|%s|%s|%s|%s|%s|%d|%d" % [mode, _here(), st, Tram.found(), _see_through(), Txt.zh, int(map_size.y), int(_port_origin.x)]


static func _codes() -> Dictionary:
	return {"power": "PWR-1", "salvage": "SLV-2", "process": "PRC-3", "tug": "TUG-4", "trade": "TRD-5", "cargo": "CGO-6"}


# the map's corners: a bracket at each, ticks along the top, the title strip along the foot with a scale
func _frame(ci: CanvasItem, title: String, k_px_m: float) -> void:
	var font: Font = game.hud.font
	var ty := map_size.y - 8.0
	# the scanning lamp, then the title (where you are), engraved on the bezel's foot
	Charcoal.led(ci, Vector2(PAD + 2.0, ty - 4.0), true, 1.0, 2.6, Color(0.92, 0.93, 0.9))
	ci.draw_string(font, Vector2(PAD + 10.0, ty), title, HORIZONTAL_ALIGNMENT_LEFT, map_size.x - 120.0, 11, Charcoal.INK2)
	# a scale bar: a round number of metres no longer than 60 px
	if k_px_m > 0.0:
		var metres := 10.0
		for mm: float in [10.0, 20.0, 25.0, 50.0, 100.0, 200.0, 500.0]:
			if mm * k_px_m <= 60.0:
				metres = mm
		var bw := metres * k_px_m
		var x1 := map_size.x - PAD - 2.0
		var x0 := x1 - bw
		var by := ty - 4.0
		ci.draw_line(Vector2(x0, by), Vector2(x1, by), Charcoal.INK2, 1.0)
		for x: float in [x0, x1]:
			ci.draw_line(Vector2(x, by - 3.0), Vector2(x, by + 2.0), Charcoal.INK2, 1.0)
		ci.draw_string(font, Vector2(x0 - 46.0, ty), "%d m" % int(metres), HORIZONTAL_ALIGNMENT_RIGHT, 42.0, 10, Charcoal.INK3)


func _draw_port() -> void:
	var ci := port_layer
	var font: Font = game.hud.font
	var full := Rect2(Vector2.ZERO, map_size)
	_bezel(ci)
	var c := PortStructure.centre()
	var m := PortStructure.M()
	var k := _port_k
	var here := _here()
	var cp := pmap(c)
	# the grid: every 25 m of the station
	var step := 25.0 * m * k
	var area := Rect2(Vector2(PAD, PAD), map_size - Vector2(PAD * 2.0, PAD * 2.0 + TITLE_H))
	if step >= 6.0:
		var x := fposmod(cp.x - area.position.x, step) + area.position.x
		while x < area.end.x:
			ci.draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), Pal.ink(0.022), 1.0)
			x += step
		var y := fposmod(cp.y - area.position.y, step) + area.position.y
		while y < area.end.y:
			ci.draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Pal.ink(0.022), 1.0)
			y += step
	# range rings round the hub, every 40 m, dashed
	for ring: int in [1, 2, 3]:
		var rr: float = ring * 40.0 * m * k
		for i in 48:
			if i % 2 == 0:
				FastDraw.arc(ci, cp, rr, TAU * i / 48.0, TAU * (i + 1) / 48.0, 3, Pal.ink(0.07), 1.0)
	# the corridors: tubes from the hub to each door
	for zone in Port.ZONES:
		if zone in ["ring", "salvage"]:
			continue
		var d: Array = PortStructure.door(zone)
		var pa := pmap(c + (d[0] - c).normalized() * PortArt.HUB_R * m)
		var pd := pmap(d[0])
		var wpx := maxf(3.0, PortStructure.HALF * 2.0 * m * k)
		var nrm := (pd - pa).normalized().orthogonal() * wpx * 0.5
		ci.draw_line(pa, pd, Color(0.075, 0.077, 0.083), wpx)
		var ec := Pal.ink(0.32 if Port.stage(zone) >= 1 else 0.16)
		ci.draw_line(pa + nrm, pd + nrm, ec, 1.0)
		ci.draw_line(pa - nrm, pd - nrm, ec, 1.0)
	# the hub: its rim, the carousel's pit, the core
	var hr := PortArt.HUB_R * m * k
	FastDraw.circle(ci, cp, hr, Color(0.07, 0.072, 0.078))
	FastDraw.arc(ci, cp, hr, 0.0, TAU, 48, Charcoal.ACCENT if here == "ring" else Pal.ink(0.42), 1.3, true)
	FastDraw.arc(ci, cp, 14.6 * m * k, 0.0, TAU, 40, Pal.ink(0.2), 1.0, true)
	FastDraw.arc(ci, cp, 8.4 * m * k, 0.0, TAU, 32, Pal.ink(0.2), 1.0, true)
	FastDraw.circle(ci, cp, 2.2 * m * k + 1.0, Pal.ink(0.55) if Port.stage("ring") >= 1 else Pal.ink(0.25))
	# the shuttle's rails and its stops (the ones it may ride to lit)
	var rail := Pal.ink(0.2)
	FastDraw.arc(ci, cp, Tram.LOOP_R * m * k, 0.0, TAU, 40, rail, 1.0)
	var known := Tram.found()
	for s in Tram.stations():
		if s != "ring":
			var lg: Array = Tram._leg(s)
			for i in range(1, lg.size()):
				ci.draw_line(pmap(lg[i - 1]), pmap(lg[i]), rail, 1.0)
	for s in Tram.stations():
		var sp := pmap(Tram.station_at(s))
		var on: bool = s in known
		ci.draw_rect(Rect2(sp - Vector2(2, 2), Vector2(4, 4)), Pal.ink(0.7) if on else Color(0.05, 0.052, 0.058))
		if not on:
			ci.draw_rect(Rect2(sp - Vector2(2, 2), Vector2(4, 4)), Pal.ink(0.3), false, 1.0)
	# the districts: a block each, its code, its name, a pip for each stage built; a dead one hatched
	for zone in Port.ZONES:
		if zone in ["ring", "salvage"]:
			continue
		var b := PortStructure.box(zone)
		var mr := Rect2(pmap(b.position), b.size * k)
		var lit: bool = zone == here
		var st := Port.stage(zone)
		# 炭黑: a district a dark block and its name in small clear type (no code tags, no stage pips);
		# the one you are in: an orange edge and its lamp
		ci.draw_rect(mr, Color(0.095, 0.097, 0.105) if st > 0 else Color(0.06, 0.062, 0.068))
		if st == 0:
			var hx := mr.position.x - mr.size.y
			while hx < mr.end.x:
				var a0 := Vector2(hx, mr.end.y)
				var a1 := Vector2(hx + mr.size.y, mr.position.y)
				var seg := Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a0, a1]), PackedVector2Array([mr.position, Vector2(mr.end.x, mr.position.y), mr.end, Vector2(mr.position.x, mr.end.y)]))
				for sg in seg:
					if sg.size() >= 2:
						ci.draw_line(sg[0], sg[1], Pal.ink(0.06), 1.0)
				hx += 6.0
		if lit:
			ci.draw_rect(mr, Color(Charcoal.ACCENT, 0.95), false, 1.2)
		# the English names are too long for a block this small: the short ones (as the guide cards have)
		var nm: String = Port.name_of(zone) if Txt.zh else str({"power": "POWER", "process": "PROCESS", "cargo": "CARGO", "tug": "TUGS", "trade": "TRADE"}.get(zone, Port.name_of(zone)))
		var nw: float = font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var tx := mr.get_center().x - nw * 0.5 + (5.0 if lit else 0.0)
		if lit:
			Charcoal.led(ci, Vector2(tx - 8.0, mr.get_center().y + 0.5), true, 1.0, 2.6)
		ci.draw_string(font, Vector2(tx, mr.get_center().y + 4.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Charcoal.INK if lit else (Charcoal.INK2 if st > 0 else Charcoal.INK3))
	# the berth
	var br := Rect2(pmap(berth_px().position), berth_px().size * k)
	ci.draw_rect(br, Color(0.075, 0.077, 0.083))
	if here == "salvage":
		ci.draw_rect(br, Color(Charcoal.ACCENT, 0.95), false, 1.2)
	ci.draw_string(font, br.position + Vector2(5, 13), Ops.w("七号坞", "BERTH 07"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Charcoal.INK if here == "salvage" else Charcoal.INK2)
	var title := Ops.w("零压港 · 港站全图", "ZERO PRESSURE PORT") if mode == "port" else Ops.w("站外 · 港站周边", "OUTSIDE THE STATION")
	if here != "" and mode == "port":
		title += " · " + (Ops.w("中央环", "THE RING") if here == "ring" else Port.name_of(here))
	_frame(ci, title, Geom.M * k)


# a wedge swept round the hub, bright at its leading edge (vertex colours)
func _sweep(ci: CanvasItem, cp: Vector2, r: float, a: float, trail: float, col: Color) -> void:
	var n := 10
	var pts := PackedVector2Array([cp])
	var cols := PackedColorArray([Color(col, col.a * 0.6)])
	for i in n + 1:
		var f := float(i) / n
		pts.append(cp + Vector2.from_angle(a - trail * (1.0 - f)) * r)
		cols.append(Color(col, col.a * f * f))
	ci.draw_polygon(pts, cols)
	ci.draw_line(cp, cp + Vector2.from_angle(a) * r, Color(col, minf(1.0, col.a * 3.0)), 1.0)


const HubW = preload("res://scripts/hub_works.gd")


func _draw_port_live() -> void:
	var t0 := Time.get_ticks_usec()
	var ci := port_live
	var c := PortStructure.centre()
	var m := PortStructure.M()
	var k := _port_k
	var cp := pmap(c)
	var here := _here()
	# the sweep from the hub, and a ping on each working district as it passes
	# (a radar's disc: as far as the nearest edge of the map, so it never leaves it)
	var area := Rect2(Vector2(PAD, PAD), map_size - Vector2(PAD * 2.0, PAD * 2.0 + TITLE_H))
	var reach := minf(minf(cp.x - area.position.x, area.end.x - cp.x), minf(cp.y - area.position.y, area.end.y - cp.y))
	var sa := fmod(t * 1.1, TAU)
	if reach > 20.0:
		# 炭黑: one fine sweep line, no tinted wedge
		ci.draw_line(cp, cp + Vector2.from_angle(sa) * reach, Color(1, 1, 1, 0.12), 1.0)
	for zone in Port.ZONES:
		if zone in ["ring", "salvage"] or Port.stage(zone) < 1:
			continue
		var b := PortStructure.box(zone)
		var behind := wrapf(sa - (pmap(b.get_center()) - cp).angle(), 0.0, TAU)
		if behind < 1.4:
			var e := behind / 1.4
			ci.draw_rect(Rect2(pmap(b.position), b.size * k).grow(1.0 + 3.0 * e), Color(1, 1, 1, 0.22 * (1.0 - e)), false, 1.0)
	# power down the corridors: in from the power district, out to each by what it draws
	for zone in Port.ZONES:
		if zone in ["ring", "salvage"]:
			continue
		var mw := PortArt._feeder_mw(zone)
		if mw <= 0.005:
			continue
		var d: Array = PortStructure.door(zone)
		var pa := pmap(c + (d[0] - c).normalized() * PortArt.HUB_R * m)
		var pd := pmap(d[0])
		var L := pa.distance_to(pd)
		var gap := 9.0
		var vc := Color(1, 1, 1, 0.3 + 0.35 * clampf(mw / 12.0, 0.0, 1.0))
		var dd := fmod(t * (10.0 + 6.0 * sqrt(mw)), gap)
		while dd < L:
			var f := dd / L if zone != "power" else 1.0 - dd / L
			ci.draw_rect(Rect2(pa.lerp(pd, f) - Vector2(1, 1), Vector2(2, 2)), vc)
			dd += gap
	# the carousel turning: its twelve cradles, the loaded ones bright
	var cr := HubW.R_CRADLE * m * k
	for i in HubW.SLOTS:
		var u := Vector2.from_angle(HubW.theta + i * HubW.PITCH)
		var loaded: bool = i < HubW.cradles.size() and HubW.cradles[i] != null
		ci.draw_line(cp + u * (cr - 1.5), cp + u * (cr + 1.5), Pal.ink(0.9) if loaded else Pal.ink(0.3), 2.0 if loaded else 1.0)
	# where the operator is: brackets closing in round it
	var pulse := 0.5 + 0.5 * sin(t * 4.0)
	if here == "ring":
		var hr := PortArt.HUB_R * m * k + 3.0 + 2.0 * pulse
		for i in 4:
			var a0 := TAU * i / 4.0 + PI / 4.0
			FastDraw.arc(ci, cp, hr, a0 - 0.25, a0 + 0.25, 6, Color(Charcoal.ACCENT, 0.9), 1.5)
	elif here != "":
		var b := PortStructure.box(here) if here != "salvage" else berth_px()
		var mr := Rect2(pmap(b.position), b.size * k).grow(2.0 + 2.0 * pulse)
		for cx: float in [0.0, 1.0]:
			for cy: float in [0.0, 1.0]:
				var p := mr.position + mr.size * Vector2(cx, cy)
				var sx := 1.0 if cx == 0.0 else -1.0
				var sy := 1.0 if cy == 0.0 else -1.0
				ci.draw_line(p, p + Vector2(6.0 * sx, 0), Color(Charcoal.ACCENT, 0.95), 1.5)
				ci.draw_line(p, p + Vector2(0, 6.0 * sy), Color(Charcoal.ACCENT, 0.95), 1.5)
	# the shuttle, and where it has just been
	if game.tram != null and is_instance_valid(game.tram):
		var tp := pmap(game.tram.position_px)
		if _trail.is_empty() or (_trail[_trail.size() - 1] as Vector2).distance_to(tp) > 1.5:
			_trail.append(tp)
			if _trail.size() > 28:
				_trail.pop_front()
		for i in range(1, _trail.size()):
			ci.draw_line(_trail[i - 1], _trail[i], Pal.ink(0.45 * float(i) / _trail.size()), 2.0)
		ci.draw_rect(Rect2(tp - Vector2(3, 3), Vector2(6, 6)), Pal.ink(0.95))
	# 130 号: the freight trains, a short bar each along the rails
	var FW = preload("res://scripts/freight_works.gd")
	if FW.on:
		for tr in FW.trains:
			var hp := pmap(tr.pos)
			var bp2 := pmap(FW.behind(tr, 8.7 * Geom.M))
			ci.draw_line(hp, bp2, Pal.ink(0.6), 3.0)
			ci.draw_rect(Rect2(hp - Vector2(2, 2), Vector2(4, 4)), Pal.ink(0.95))
	# 货船穿模 (user 2026-11-10: "完全看不到货船在哪里"): the trade port's freighters — a hull bar, its
	# bow lit, and a ring breathing round it while it comes in or lies alongside
	if HallMarket.open():
		var CS = preload("res://scripts/client_ships.gd")
		var tb := PortStructure.box("trade")
		for e in CS.ships():
			if str(e.kind) == "post":
				continue
			var sp := pmap(tb.position + (e.at as Vector2) * m)
			var hl := maxf(3.0, float(e.len) * 0.5 * m * k)
			var fl := signf(float(e.flip)) if absf(float(e.flip)) > 0.04 else 1.0
			ci.draw_line(sp - Vector2(hl * fl, 0), sp + Vector2(hl * fl, 0), Pal.ink(0.75), 3.0)
			ci.draw_rect(Rect2(sp - Vector2(hl * fl, 0) - Vector2(1.5, 1.5), Vector2(3, 3)), Pal.ink(0.95, 1.3))
			if str(e.phase) != "out":
				FastDraw.arc(ci, sp, 6.0 + 4.0 * pulse, 0.0, TAU, 16, Color(1, 1, 1, 0.5 * (1.0 - pulse)), 1.0)
	# the work boat
	if game.boat != null and is_instance_valid(game.boat):
		var bp := pmap(game.boat.global_position)
		ci.draw_rect(Rect2(bp - Vector2(4, 2.5), Vector2(8, 5)), Pal.ink(0.85))
	# the drone: the view it has, its heading, a ring breathing round it
	if game.drone != null:
		var dp := pmap(game.drone.global_position)
		if game.cam != null and game.cam_zoom() > 0.0:
			var half: Vector2 = get_viewport_rect().size * 0.5 / game.cam_zoom()
			var vr := Rect2(pmap(game.cam.global_position - half), half * 2.0 * k).intersection(window_rect().grow(-1.0))
			ci.draw_rect(vr, Color(1, 1, 1, 0.03))
			ci.draw_rect(vr, Color(1, 1, 1, 0.22), false, 1.0)
		var v: Vector2 = game.drone.linear_velocity
		var dir := v.normalized() if v.length() > 8.0 else Vector2.UP.rotated(game.drone.rotation)
		# 炭黑: you are the orange mark — a soft halo, the arrow of your heading
		FastDraw.circle(ci, dp, 6.0 + 4.0 * pulse, Color(Charcoal.ACCENT, 0.16 * (1.0 - pulse)))
		FastDraw.poly(ci, PackedVector2Array([dp + dir * 7.5, dp + dir.orthogonal() * 3.8 - dir * 3.2, dp - dir.orthogonal() * 3.8 - dir * 3.2]), Charcoal.ACCENT)
	draw_us = lerpf(draw_us, float(Time.get_ticks_usec() - t0), 0.1)
