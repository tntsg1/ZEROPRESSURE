extends Node2D
# The port as a place (2026-10-24, design/成长版本/G5-G7_工业港成长重设计_2026-10-22/20):
# the compact station's walls, doors, corridors and interiors, in the same geometry
# PortArt draws. Each district is a shell with a 6 m door on the side facing the hub,
# every spoke is a walled corridor open at both ends, the hub's outer ring is open
# where the spokes meet it (Jev A 0.99). Inside each district: a floor, two or three
# machines with their own collision, the engineering desk (the works page) and the
# district's business console (scripts/district_panel.gd). Only at the empty berth
# of a career, like scripts/port_access.gd.
class_name PortStructure

var game
var t := 0.0
var inside := ""                 # the zone the operator is in ("" outside)
var walls: StaticBody2D
var interiors                    # the districts' pipes, platforms and machinery (40 号)
const Interiors = preload("res://scripts/district_interiors.gd")
var hub                          # 109 号: the central transfer ring's machines (scripts/hub_view.gd)
const ConsoleArt = preload("res://scripts/console_art.gd")
const DOOR := 6.0                # m: a district's door
const HALF := 3.0                # m: half a corridor's width (PortArt's truss)
const HALF_SALVAGE := 5.5        # 130 号: the berth's corridor, wide enough for a freight siding beside the line


static func half(zone: String) -> float:
	return HALF_SALVAGE if zone == "salvage" else HALF
# 129/130 号: the hub's business console, ° and m from the centre. 130 号 review: at 152°, R 17 it stood
# squeezed against the carousel; now on the hub stop's platform (inside the loop, Tram.RING_A 140°),
# at its free end, the way a district's console stands by its stop (outside the loop is past the
# hub's wall, HUB_R 24)
const RING_CONSOLE := Vector2(146.0, 18.6)
const RING_DESK := Vector2(133.0, 18.6)
const RING_FOOT := 1.6                       # 130 号: its stand, m (2.8 reached over the shuttle's rails)
const REACH := 4.0               # m: how close to a console counts
const HATCH := 4.0               # m: the cargo district's floor hatch over the yard
# per zone: the machines inside, as rects in the box's local metres (origin: box top-left)
const MACHINES := {
	# 100 号: the three reactor bays in their shields (the third empty until stage 2), the switchgear
	"power": [["reactor_a", Vector2(0.8, 3.2), Vector2(9.4, 14.4)], ["reactor_b", Vector2(10.4, 3.2), Vector2(9.4, 14.4)], ["reactor_c", Vector2(20.0, 3.2), Vector2(9.4, 14.4)],
		["switchgear", Vector2(38.6, 18.6), Vector2(15.05, 8.2)]],
	"tug": [["table", Vector2(23.2, 22.3), Vector2(19.1, 4.5)], ["rack", Vector2(39.2, 0.5), Vector2(12.4, 5.2)], ["deck", Vector2(22.6, 10.8), Vector2(29.2, 0.7)]],
	# the processing district's works are the real machines now (scripts/process_plant.gd, 30 号)
	"process": [],
	# the trade hall's counters and quote board are scripts/trade_hall.gd (38 号)
	"trade": [],
	"cargo": [["stack_a", Vector2(6, 12), Vector2(10, 9)], ["stack_b", Vector2(42, 12), Vector2(10, 9)]],
}
const DRAWN_INSIDE := ["cradle", "table", "deck", "rack", "reactor_a", "reactor_b", "reactor_c", "switchgear"]
const NAMES := {
	"reactor_a": ["反应堆 A", "REACTOR A"], "reactor_b": ["反应堆 B", "REACTOR B"], "reactor_c": ["机位 C", "BAY C"], "switchgear": ["配电柜", "SWITCHGEAR"],
	"cradle": ["拖船托架", "TUG CRADLE"], "table": ["吊舱检修台", "POD SERVICE TABLE"], "deck": ["拖船甲板", "TUG DECK"], "rack": ["备件架", "PARTS RACK"],
	"crusher": ["预处理机", "PRE-SHREDDER"], "furnace": ["精炼炉位", "REFINING BAY"],
	"counter": ["港务窗口", "PORT COUNTER"], "bench": ["候客席", "WAITING"],
	"stack_a": ["货位 A", "BAY A"], "stack_b": ["货位 B", "BAY B"],
}


func active() -> bool:
	return game != null and game.in_berth() and game.career()


static func M() -> float:
	return Geom.M * PortArt.PM


static func centre() -> Vector2:
	return Backdrop.port_centre_px()


# a district's shell, world px
static func box(zone: String) -> Rect2:
	return Rect2(centre() + PortArt.district_at(zone) * M() - PortArt.BOX * 0.5 * M(), PortArt.BOX * M())


# where the spoke from the hub meets the shell: the door's centre, and the inward normal
static func door(zone: String) -> Array:
	var d: Array = PortArt.door_at(zone)
	return [centre() + d[0] * M(), d[1]]


# the two consoles inside a district: [business console, engineering desk]
static func consoles(zone: String) -> Array:
	var m := M()
	if zone == "ring":
		var c := centre()
		# 109 号: on the service deck outside the carousel's pit (was 7, 13: over the turning cradles).
		# 129 号: moved to the berth spoke's far side (it was at 76°, R 18.6: a metre from the berth arm's
		# turret, the arm's links over it all the time and its stand over the shuttle's loop) — the deck
		# between the salvage and processing spokes is clear; the desk beside it
		return [c + Vector2.from_angle(deg_to_rad(RING_CONSOLE.x)) * RING_CONSOLE.y * m, c + Vector2.from_angle(deg_to_rad(RING_DESK.x)) * RING_DESK.y * m]
	var d := door(zone)
	var p: Vector2 = d[0]
	var n: Vector2 = d[1]
	var tg := n.orthogonal()
	# 128 号 第 4 段: the processing district's business terminal stands in its gallery
	if zone == "process" and preload("res://scripts/process_gallery.gd").on():
		return [preload("res://scripts/process_gallery.gd").term("business"), p + n * 5.0 * m - tg * 5.0 * m]
	return [p + n * 5.0 * m + tg * 5.0 * m, p + n * 5.0 * m - tg * 5.0 * m]


static func console_spot(zone: String) -> Vector2:
	return consoles(zone)[0]


static func works_spot(zone: String) -> Vector2:
	return consoles(zone)[1]


func near_console() -> String:
	if not active() or game.drone == null or not game.drone.alive:
		return ""
	for zone in Port.ZONES:
		if zone == "salvage":
			continue
		if game.drone.global_position.distance_to(console_spot(zone)) <= REACH * Geom.M:
			return zone
	return ""


# the zone the point is inside ("" when outside every shell and the hub)
static func zone_at(p: Vector2) -> String:
	if p.distance_to(centre()) <= PortArt.HUB_R * M():
		return "ring"
	for zone in Port.ZONES:
		if zone in ["salvage", "ring"]:
			continue
		if box(zone).has_point(p):
			return zone
	return ""


func _ready() -> void:
	z_index = 2
	z_as_relative = false
	walls = StaticBody2D.new()
	walls.name = "PortWalls"
	walls.collision_layer = 4
	walls.collision_mask = 0
	add_child(walls)
	# 128 号 第 4 段: the processing district's gallery, solid to the drone only (scripts/process_gallery.gd)
	gallery_walls = StaticBody2D.new()
	gallery_walls.name = "GalleryWalls"
	gallery_walls.collision_layer = 16
	gallery_walls.collision_mask = 0
	add_child(gallery_walls)
	if preload("res://scripts/process_gallery.gd").on():
		for e in preload("res://scripts/process_gallery.gd").edges():
			_seg_on(gallery_walls, e[0], e[1])
	_build()
	interiors = Interiors.new()
	interiors.game = game
	add_child(interiors)
	hub = preload("res://scripts/hub_view.gd").new()
	hub.game = game
	add_child(hub)
	# 128 号 第 5 段 (草图): batteries, overload, the cryo run (scripts/power_supply_view.gd)
	power5 = preload("res://scripts/power_supply_view.gd").new()
	power5.game = game
	add_child(power5)
var power5


# a wall from a to b: a thin solid slab (a zero-width segment lets a fast drone slip through)
func _seg(a: Vector2, b: Vector2) -> void:
	if a.distance_to(b) < 1.0:
		return
	var sh := RectangleShape2D.new()
	sh.size = Vector2(a.distance_to(b), 0.5 * M())
	var cs := CollisionShape2D.new()
	cs.shape = sh
	cs.position = (a + b) * 0.5
	cs.rotation = (b - a).angle()
	walls.add_child(cs)


var gallery_walls: StaticBody2D
func _seg_on(body: StaticBody2D, a: Vector2, b: Vector2) -> void:
	var sh := RectangleShape2D.new()
	sh.size = Vector2(a.distance_to(b) + 0.25 * M(), 0.5 * M())
	var cs := CollisionShape2D.new()
	cs.shape = sh
	cs.position = (a + b) * 0.5
	cs.rotation = (b - a).angle()
	body.add_child(cs)


func _rect(r: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	cs.shape = sh
	cs.position = r.get_center()
	walls.add_child(cs)


# an edge from a to b with a gap of width w centred at g (g on the edge)
func _edge_with_gap(a: Vector2, b: Vector2, g: Vector2, w: float) -> void:
	var dir := (b - a).normalized()
	var k := (g - a).dot(dir)
	var len := a.distance_to(b)
	if k - w * 0.5 <= 0.0 or k + w * 0.5 >= len:
		_seg(a, b)
		return
	_seg(a, a + dir * (k - w * 0.5))
	_seg(a + dir * (k + w * 0.5), b)


func _build() -> void:
	var m := M()
	var c := centre()
	# the hub's outer ring, open where each spoke arrives
	var gaps: Array = []
	for zone in PortArt.ANGLE:
		gaps.append([(PortArt.door_at(zone)[0] as Vector2).angle(), half(zone)])
	var segs := 96
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var mid := (a0 + a1) * 0.5
		var open := false
		for ga in gaps:
			if absf(angle_difference(mid, float(ga[0]))) < (float(ga[1]) + 1.5) / PortArt.HUB_R:
				open = true
		if open:
			continue
		_seg(c + Vector2.from_angle(a0) * PortArt.HUB_R * m, c + Vector2.from_angle(a1) * PortArt.HUB_R * m)
	# the districts: shells with a door, corridors, machines
	for zone in PortArt.ANGLE:
		var d := door(zone)
		var p: Vector2 = d[0]
		var n: Vector2 = d[1]
		# the corridor runs straight from the hub's rim to the door; its walls stop a metre short
		var axis := (p - c).normalized()
		var a0 := c + axis * PortArt.HUB_R * m
		var a1 := p - axis * 1.0 * m
		var side := axis.orthogonal() * half(zone) * m
		if zone != "salvage":
			var r := box(zone)
			var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
			for i in 4:
				var e0: Vector2 = corners[i]
				var e1: Vector2 = corners[(i + 1) % 4]
				# the door sits on the edge the spoke meets
				var on_edge: bool = absf((p - e0).cross(e1 - e0)) < 1.0 * m * e0.distance_to(e1)
				if on_edge:
					_edge_with_gap(e0, e1, p, DOOR * m)
				elif zone == "cargo" and i == 2:
					# the floor hatch above the warehouse yard, where the rail comes up (30 号)
					_edge_with_gap(e0, e1, Vector2(r.get_center().x, r.end.y), HATCH * m)
				else:
					_seg(e0, e1)
			for mc in MACHINES.get(zone, []):
				_rect(Rect2(r.position + mc[1] * m, mc[2] * m))
			for sr in Interiors.solid_rects(zone):
				_rect(sr)
		# the corridor's two walls
		_seg(a0 + side, a1 + side)
		_seg(a0 - side, a1 - side)


func _process(dt: float) -> void:
	t += dt
	visible = active()
	if not visible:
		PortArt.inside = ""
		return
	inside = zone_at(game.drone.global_position) if game.drone != null else ""
	PortArt.inside = inside
	if inside != "" and not game.in_vehicle():
		Tram.discover(inside)
	queue_redraw()


func _draw() -> void:
	if not active():
		return
	var m := M()
	var z: float = maxf(game.cam_zoom(), 0.02)
	var lw := 1.0 / z
	var c := centre()
	var font := Fonts.get_font("Medium")
	var near := near_console()
	# the walls as the player sees them: a dark band with a light edge, doors with posts
	var wall_col := Pal.ink(0.28)
	for zone in PortArt.ANGLE:
		var d := door(zone)
		var p: Vector2 = d[0]
		var n: Vector2 = d[1]
		var tg := n.orthogonal()
		# 108 号 帧率: a district out of view (its box, its door and its corridor) is not drawn
		var zr := Rect2(p, Vector2.ZERO).expand(c + (p - c).normalized() * PortArt.HUB_R * m)
		if zone != "salvage":
			zr = zr.merge(box(zone))
		if not ViewCull.sees(game, zr):
			continue
		if zone != "salvage":
			var r := box(zone)
			draw_rect(r, wall_col, false, 3.0 * lw)
			if zone == "cargo":
				var hc := Vector2(r.get_center().x, r.end.y)
				draw_line(hc - Vector2(HATCH * 0.5 * m, 0), hc + Vector2(HATCH * 0.5 * m, 0), Color(0.02, 0.022, 0.026), 5.0 * lw)
				for sx in [-1.0, 1.0]:
					draw_line(hc + Vector2(sx * HATCH * 0.5 * m, 0), hc + Vector2(sx * HATCH * 0.5 * m, -1.0 * m), Pal.tint(Pal.AIR, 0.6, 1.2), 3.0 * lw)
			# the door: a gap in the wall, posts and a lintel light
			var g0 := p - tg * DOOR * 0.5 * m
			var g1 := p + tg * DOOR * 0.5 * m
			draw_line(g0, g1, Color(0.02, 0.022, 0.026), 5.0 * lw)
			for gp in [g0, g1]:
				draw_line(gp, gp + n * 1.2 * m, Pal.tint(Pal.AIR, 0.7, 1.3), 3.0 * lw)
			var lamp := Pal.tint(Pal.AIR, 0.5 + 0.3 * sin(t * 3.0), 1.4)
			draw_circle(p + n * 0.6 * m, 0.25 * m, lamp)
			if inside == zone:
				_interior(zone, r, m, lw, font, z)
		# corridor walls
		var axis := (p - c).normalized()
		var a0 := c + axis * PortArt.HUB_R * m
		var a1 := p - axis * 1.0 * m
		var side := axis.orthogonal() * half(zone) * m
		draw_line(a0 + side, a1 + side, wall_col, 2.0 * lw)
		draw_line(a0 - side, a1 - side, wall_col, 2.0 * lw)
	# the hub's floor and machines: scripts/hub_view.gd (109 号)
	# the consoles: the business console (cyan) and the engineering desk (heat) of every district
	for zone in Port.ZONES:
		if zone == "salvage":
			continue
		var cs := consoles(zone)
		if not ViewCull.sees(game, Rect2(cs[0], Vector2.ZERO).grow(8.0 * m)):
			continue
		_console(cs[0], zone, near == zone, Txt.t("pt_console_open") % Keys.label("use"))
	# the hint when the operator enters a district
	if inside != "" and z >= 0.1:
		var p: Vector2 = game.drone.global_position + Vector2(0, -3.0 * m)
		draw_set_transform(p, 0, Vector2.ONE / z)
		draw_string(font, Vector2(-60, 0), Port.name_of(inside), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.7))
		draw_set_transform(Vector2.ZERO)


# 103 号: every console a floor-standing industrial console, the district's figures on its screen
# (scripts/console_art.gd); the column reaches the floor strip (the hub's: a short stand)
func _console(p: Vector2, zone: String, on: bool, hint: String) -> void:
	var m := M()
	var foot := RING_FOOT
	if zone != "ring":
		foot = (box(zone).end.y - 1.2 * m - p.y) / m
	ConsoleArt.draw(self, p, foot, Txt.t("pt_console_business") + " · " + Port.name_of(zone), hint, on, ConsoleArt.summary(zone, game), t)


# the inside of a district: floor grid, the machines, their plates
# the warehouse's stock as it stands (23 号 Q31; drawn only): loose metal heaped in bay A by
# kind, billets stacked in bay B a tonne to a bar; the heap's height follows the tonnes
func _stock(r: Rect2, m: float, lw: float, font: Font, z: float) -> void:
	var stock: Dictionary = Career.data.get("exchange", {}).get("actors", {}).get("company", {}).get("stock", {})
	if stock.is_empty():
		return
	var heaps := [["mixed_metal:0", Color(0.36, 0.33, 0.3)], ["ferrous_scrap:0", Color(0.3, 0.3, 0.33)], ["ferrous_scrap:1", Color(0.42, 0.42, 0.46)], ["nonferrous_mix:0", Color(0.55, 0.4, 0.26)]]
	var bay_a := Rect2(r.position + Vector2(6, 12) * m, Vector2(10, 9) * m)
	var slot := bay_a.size.x / heaps.size()
	for i in heaps.size():
		var t := float(stock.get(heaps[i][0], 0.0))
		if t <= 0.001:
			continue
		# a 30° heap of bulk scrap at ~2.5 t/m³, 0.6 m deep: its height from its cross-section
		var h := minf(bay_a.size.y - 0.4 * m, sqrt(t / 2.5 / 0.6 * tan(deg_to_rad(30.0))) * m)
		var cx := bay_a.position.x + slot * (i + 0.5)
		var base := bay_a.end.y
		var half := minf(slot * 0.5, h / tan(deg_to_rad(30.0)))
		var poly := PackedVector2Array([Vector2(cx - half, base), Vector2(cx - half * 0.3, base - h * 0.92), Vector2(cx, base - h), Vector2(cx + half * 0.35, base - h * 0.88), Vector2(cx + half, base)])
		draw_colored_polygon(poly, heaps[i][1])
		draw_polyline(poly, Pal.ink(0.55), lw)
		if z >= 0.2 and Pal.labels:
			draw_set_transform(Vector2(cx - half, base - h - 0.4 * m), 0, Vector2.ONE / z)
			draw_string(font, Vector2.ZERO, "%s %.2f t" % [Ops.item_name(heaps[i][0]), t], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.75))
			draw_set_transform(Vector2.ZERO)
	var billets := float(stock.get("steel_billet:1", 0.0))
	if billets > 0.001:
		var bay_b := Rect2(r.position + Vector2(42, 12) * m, Vector2(10, 9) * m)
		# a 1 t billet: 150 × 150 mm, 5.7 m long, seen end-on in rows of five on dunnage
		var n := int(ceil(billets - 0.001))
		var bw := 1.6 * m
		var bh := 0.5 * m
		for k in mini(n, 60):
			var row := k / 5
			var col := k % 5
			var br := Rect2(bay_b.position.x + 0.5 * m + col * (bw + 0.15 * m), bay_b.end.y - (row + 1) * (bh + 0.12 * m), bw, bh)
			draw_rect(br, Color(0.3, 0.31, 0.34))
			draw_rect(br, Pal.ink(0.6), false, lw)
		if z >= 0.2 and Pal.labels:
			draw_set_transform(Vector2(bay_b.position.x, bay_b.end.y - (int((mini(n, 60) - 1) / 5) + 1) * (bh + 0.12 * m) - 0.4 * m), 0, Vector2.ONE / z)
			draw_string(font, Vector2.ZERO, "%s %.2f t" % [Ops.item_name("steel_billet:1"), billets], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.75))
			draw_set_transform(Vector2.ZERO)


func _interior(zone: String, r: Rect2, m: float, lw: float, font: Font, z: float) -> void:
	# 101 号: the processing district draws its own hall, floor and all (scripts/process_art.gd); this
	# veil over it dimmed the furnace and the line
	if zone in ["process", "cargo"]:
		return
	draw_rect(r, Color(0.03, 0.034, 0.04, 0.55))
	var gx := r.position.x
	while gx < r.end.x:
		draw_line(Vector2(gx, r.position.y), Vector2(gx, r.end.y), Pal.ink(0.05), lw)
		gx += 4.0 * m
	var gy := r.position.y
	while gy < r.end.y:
		draw_line(Vector2(r.position.x, gy), Vector2(r.end.x, gy), Pal.ink(0.05), lw)
		gy += 4.0 * m
	# a floor strip with hazard marks along the bottom
	var floor_y := r.end.y - 1.2 * m
	draw_line(Vector2(r.position.x, floor_y), Vector2(r.end.x, floor_y), Pal.ink(0.3), 2.0 * lw)
	var hx := r.position.x
	while hx < r.end.x - 1.0 * m:
		draw_line(Vector2(hx, floor_y + 0.3 * m), Vector2(hx + 0.8 * m, floor_y + 0.9 * m), Pal.heat(0.35, 1.0), lw)
		hx += 2.0 * m
	var n := Port.stage(zone)
	for mc in MACHINES.get(zone, []):
		# 47 号: these are drawn as the things they are (scripts/district_interiors.gd); here only
		# their collision stands
		if mc[0] in DRAWN_INSIDE:
			continue
		var mr := Rect2(r.position + mc[1] * m, mc[2] * m)
		draw_rect(mr, Color(0.05, 0.053, 0.06))
		draw_rect(mr, Pal.ink(0.5), false, 1.5 * lw)
		# hatching to say it is solid
		var x := mr.position.x - mr.size.y
		while x < mr.end.x:
			var p0 := Vector2(maxf(x, mr.position.x), mr.position.y + minf(mr.size.y, maxf(0.0, mr.position.x - x)))
			var p1 := Vector2(minf(x + mr.size.y, mr.end.x), mr.end.y - maxf(0.0, x + mr.size.y - mr.end.x))
			if p1.x > p0.x:
				draw_line(p0, p1, Pal.ink(0.08), lw)
			x += 1.5 * m
		# a status lamp: lit once the district has its first stage
		draw_circle(mr.position + Vector2(0.5, 0.5) * m, 0.2 * m, Pal.heat(0.9, 1.5) if n >= 1 else Pal.ink(0.15))
		if z >= 0.2 and Pal.labels:
			draw_set_transform(mr.position + Vector2(0, -0.3 * m), 0, Vector2.ONE / z)
			var name: Array = NAMES.get(mc[0], [mc[0], mc[0]])
			draw_string(font, Vector2.ZERO, name[0] if Txt.zh else name[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.6))
			draw_set_transform(Vector2.ZERO)
	# 46 号: the cargo district's stock is drawn on its shelves (scripts/district_interiors.gd)
	# the engineering desk's label next to the business console (port_access draws the desk itself)
	var ws := works_spot(zone)
	# no desks any more (port_access.gd DESKS): nothing to label
	if z >= 0.2 and preload("res://scripts/port_access.gd").DESKS:
		draw_set_transform(ws + Vector2(0, 2.4 * m), 0, Vector2.ONE / z)
		draw_string(font, Vector2(-30, 0), Txt.t("pt_access_terminal"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.heat(0.7, 1.0))
		draw_set_transform(Vector2.ZERO)
