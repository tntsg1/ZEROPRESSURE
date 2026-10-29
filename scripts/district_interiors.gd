extends Node2D
# The districts' insides, thickened (design/…/40 号): pipes, platforms and moving machinery
# in each of the six — the power district's coolant loop, turbine and pumps; the tug works'
# gantry and fuel; the processing district's fume duct, baghouse and furnace transformer; the
# trade hall's pneumatic tubes; the cargo district's stacker crane, crates and rollers; the
# hub's pipe gallery. Back-wall work has no collision; the few floor-standing pieces (SOLIDS)
# are walls of scripts/port_structure.gd, clear of the doors and both consoles (Jev B 0.98).
# They run on the district's real state: unpowered below stage 1, faster while it works
# (Jev B 0.96). The still parts are one batched mesh, redrawn only when the district the
# operator is in or its stage changes; the moving parts are a small node drawn every frame,
# only for the district the operator is in (Jev A 0.99). Box-local metres (60 × 28, door
# side from PortArt.door_at); widths in metres, so zoom never redraws.

const CanvasBatch = preload("res://scripts/canvas_batch.gd")
const TugArt = preload("res://scripts/tug_station_art.gd")
const TugWorks = preload("res://scripts/tug_works.gd")

# floor-standing pieces with collision, box-local metres: [id, position, size]
const SOLIDS := {
	"power": [["turbine", Vector2(38, 7), Vector2(17, 6)], ["pumps", Vector2(4, 21), Vector2(9, 5.8)]],
	"tug": [["fuel", Vector2(42.7, 12.4), Vector2(3.9, 14.4)], ["bins", Vector2(47.2, 19.4), Vector2(4.6, 7.4)]],
	"process": [["baghouse", Vector2(31, 19), Vector2(8, 7.8)], ["transformer", Vector2(2, 20), Vector2(6, 6.8)]],
	"trade": [],
	"cargo": [["pallets", Vector2(53, 21), Vector2(5, 5.8)]],
}
const NAMES := {
	"turbine": ["汽轮发电机", "TURBINE-GENERATOR"], "pumps": ["主冷却泵", "COOLANT PUMPS"],
	"fuel": ["推进剂储罐", "PROPELLANT TANK"], "bins": ["零件箱", "PARTS BINS"], "gantry": ["龙门吊", "GANTRY"],
	"baghouse": ["除尘布袋室", "BAGHOUSE"], "transformer": ["炉用变压器", "FURNACE TRANSFORMER"], "duct": ["排烟道", "FUME DUCT"],
	"sorter": ["传单分拣", "TUBE SORTER"], "tube": ["气动传单管", "PNEUMATIC TUBE"],
	"pallets": ["托盘", "PALLETS"], "stacker": ["堆垛吊车", "STACKER CRANE"], "rollers": ["辊道", "ROLLER LINE"],
	"gallery": ["主管廊", "PIPE GALLERY"], "catwalk": ["检修走台", "CATWALK"],
}

var game
var font: Font
var moving: Node2D
var _key := ""                 # what the still parts were drawn for
var draws := 0                 # tests: still-part redraws
var t := 0.0
var speed := {}                # zone → how fast its machinery runs now (0 still … 1 working hard)
var phase := {}                # zone → its machinery's running phase
var power_mw := 0.0            # what the bus draws now (the turbine's readout)
var tug_art                    # 96 号: the tug station's machines (scripts/tug_station_art.gd)
var card                       # 96 号: the hover card
var tug_tick_us := 0.0         # 96 号: what the tug station costs a frame (µs, smoothed): its machines' step
var tug_draw_us := 0.0         # … and its moving parts' drawing (the commands; the GPU's share is apart)


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func solid_rects(zone: String) -> Array:
	var out: Array = []
	if not PortArt.ANGLE.has(zone) or zone == "salvage":
		return out
	var r := PortStructure.box(zone)
	var m := PortStructure.M()
	for s in SOLIDS.get(zone, []):
		out.append(Rect2(r.position + (s[1] as Vector2) * m, (s[2] as Vector2) * m))
	return out


func _ready() -> void:
	z_index = 0
	font = Fonts.get_font("Medium")
	moving = Node2D.new()
	moving.draw.connect(_draw_moving)
	add_child(moving)
	TugWorks.reset()
	tug_art = TugArt.new()
	tug_art.font = font
	# 96 号: the facility card over the machines (scripts/facility_card.gd)
	card = preload("res://scripts/facility_card.gd").new()
	card.items = func() -> Array: return tug_art.hover_items() if visible and _zone() == "tug" else []
	add_child(card)


func _zone() -> String:
	var st = get_parent()
	return str(st.inside) if st != null and st.get("inside") != null else ""


# how hard each district works now (0 off, ~0.3 idle with power, 1 busy)
func _busy(zone: String) -> float:
	var stage := Port.stage(zone) if zone != "ring" else Port.stage("power")
	if stage < 1:
		return 0.0
	var k := 0.3
	match zone:
		"power":
			var mw := 0.0
			for l in Grid.loads(game):
				mw += float(l.mw)
			power_mw = mw
			k = clampf(mw / maxf(1.0, Grid.capacity()), 0.15, 1.0)
		"process":
			var p = game.get("plant")
			if p != null and is_instance_valid(p) and (float(p.smelter.power) > 0.1 or bool(p.scrapline.company_powered)):
				k = 1.0
		"trade":
			var th = game.get("trade_hall")
			if th != null and is_instance_valid(th) and not th._local_trade().is_empty():
				k = 1.0
		"cargo":
			for tr in Career.data.get("exchange", {}).get("trades", []):
				if str(tr.state) in ["awaiting_dispatch", "loading", "in_transit"]:
					k = 1.0
					break
		"tug":
			var b = game.get("boat")
			if b != null and is_instance_valid(b) and str(b.pad) == "":
				k = 1.0
		"ring":
			var tr2 = game.get("tram")
			if tr2 != null and is_instance_valid(tr2) and bool(tr2.get("riding")):
				k = 1.0
	return k


func _process(dt: float) -> void:
	# 96 号: the tug station works whether or not anyone is inside to see it
	if game != null and game.in_berth() and game.career():
		var t0 := Time.get_ticks_usec()
		TugWorks.tick(dt)
		tug_tick_us = lerpf(tug_tick_us, float(Time.get_ticks_usec() - t0), 0.05)
	if card != null:
		card.game = game
	# the station's one-shots, heard only near it (the berth would hear them faintly otherwise)
	if not TugWorks.events.is_empty():
		var near := _tug_near()
		for e in TugWorks.events:
			if near > 0.0 and game != null and game.get("sfx") != null:
				game.sfx.play(str(e[0]), PortStructure.box("tug").position + (e[1] as Vector2) * PortStructure.M(), 0.75 * near)
		TugWorks.events.clear()
	var zone := _zone()
	visible = zone != "" and game != null and game.in_berth()
	if not visible:
		return
	t += dt
	var target := _busy(zone)
	speed[zone] = move_toward(float(speed.get(zone, target)), target, dt * 0.5)
	phase[zone] = float(phase.get(zone, 0.0)) + dt * float(speed[zone])
	if zone == "cargo":
		_watch_stock(dt)
	var sig := ""
	if zone == "cargo":
		sig = _stock_sig()
	elif zone == "power":
		sig = "%d/%s" % [int(_power_frac() * 10.0), _feeders_sig()]
	elif zone == "tug":
		sig = str(lod())
	var key := "%s/%d/%s" % [zone, Port.stage(zone) if zone != "ring" else Port.stage("power"), sig]
	if key != _key:
		_key = key
		queue_redraw()
	moving.queue_redraw()


# ------------------------------------------------------------------ helpers (box-local metres)
var _r := Rect2()
var _m := 1.0


func _p(v: Vector2) -> Vector2:
	return _r.position + v * _m


func _pipe(cb, pts: Array, wm: float, col: Color) -> void:
	var pv := PackedVector2Array()
	for v in pts:
		pv.append(_p(v))
	cb.draw_polyline(pv, Color(0.02, 0.022, 0.026), (wm + 0.25) * _m)
	cb.draw_polyline(pv, col, wm * _m)


func _box(cb, pos: Vector2, size: Vector2, edge: Color, fill := Color(0.05, 0.053, 0.06)) -> void:
	var rr := Rect2(_p(pos), size * _m)
	cb.draw_rect(rr, fill)
	cb.draw_rect(rr, edge, false, 0.12 * _m)


func _label(cb, at: Vector2, id: String, col: Color) -> void:
	var n: Array = NAMES.get(id, [id, id])
	cb.draw_string(font, _p(at), n[0] if Txt.zh else n[1], HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.75 * _m), col)


func _catwalk(cb, x0: float, x1: float, y: float, ladder_x := -1.0, ladder_to := 0.0) -> void:
	var col := Pal.ink(0.32)
	cb.draw_line(_p(Vector2(x0, y)), _p(Vector2(x1, y)), col, 0.25 * _m)
	cb.draw_line(_p(Vector2(x0, y - 1.1)), _p(Vector2(x1, y - 1.1)), Pal.ink(0.2), 0.08 * _m)
	var x := x0
	while x <= x1 + 0.01:
		cb.draw_line(_p(Vector2(x, y)), _p(Vector2(x, y - 1.1)), Pal.ink(0.2), 0.08 * _m)
		x += 2.0
	if ladder_x >= 0.0:
		for sx in [-0.4, 0.4]:
			cb.draw_line(_p(Vector2(ladder_x + sx, y)), _p(Vector2(ladder_x + sx, ladder_to)), Pal.ink(0.25), 0.08 * _m)
		var yy := y + 0.6
		while yy < ladder_to:
			cb.draw_line(_p(Vector2(ladder_x - 0.4, yy)), _p(Vector2(ladder_x + 0.4, yy)), Pal.ink(0.2), 0.06 * _m)
			yy += 0.6


func _tray(cb, pts: Array) -> void:
	_pipe(cb, pts, 0.35, Pal.ink(0.22))


# ------------------------------------------------------------------ the still parts
func _draw() -> void:
	var zone := _zone()
	if zone == "" or game == null:
		return
	draws += 1
	_m = PortStructure.M()
	var cb = CanvasBatch.new(self)
	var on := (Port.stage(zone) if zone != "ring" else Port.stage("power")) >= 1
	var lit := Pal.tint(Pal.AIR, 0.55, 1.1) if on else Pal.ink(0.3)
	var hot := Pal.heat(0.55, 1.0) if on else Pal.ink(0.3)
	if zone == "ring":
		_ring_still(cb)
		cb.flush()
		return
	_r = PortStructure.box(zone)
	match zone:
		"power":
			# coolant loop: reactor heads → header along the ceiling → turbine; returns under the floor plates to the pumps
			_pipe(cb, [Vector2(9, 6), Vector2(9, 3), Vector2(46, 3), Vector2(46, 7)], 0.7, hot)
			_pipe(cb, [Vector2(20, 6), Vector2(20, 3)], 0.7, hot)
			_pipe(cb, [Vector2(52, 13), Vector2(52, 16), Vector2(34, 16), Vector2(34, 24.5), Vector2(13, 24.5)], 0.6, lit)
			_pipe(cb, [Vector2(6, 21), Vector2(6, 18)], 0.6, lit)
			_pipe(cb, [Vector2(11, 21), Vector2(11, 19.5), Vector2(20, 19.5), Vector2(20, 18)], 0.6, lit)
			_tray(cb, [Vector2(47, 18), Vector2(47, 1.3), Vector2(58, 1.3)])
			_tray(cb, [Vector2(55, 7), Vector2(57, 7), Vector2(57, 22), Vector2(54, 22)])
			_catwalk(cb, 3.0, 26.0, 5.0, 25.0, 18.0)
			# 48 号 (player 2026-10-25: "not plain geometry — detail, hardcore"): each machine drawn as
			# what it is; the rods sit as deep as the load asks, the breakers as the feeders stand
			var frac := _power_frac()
			_reactor(cb, Vector2(5, 6), "A", frac, on)
			_reactor(cb, Vector2(16, 6), "B", frac, on)
			_turbine_set(cb, on)
			_pumps(cb, on)
			_switchgear(cb)
			_label(cb, Vector2(3, 4.2), "catwalk", Pal.ink(0.45))
		"tug":
			# 96 号: the whole station as the machines it holds (scripts/tug_station_art.gd)
			tug_art.r = _r
			tug_art.m = _m
			cb.flush()
			tug_art.still(self, on, lod(), Port.stage("tug"))
		"process":
			# the fume hood over the arc furnace, the duct along the ceiling, the baghouse on the floor
			_pipe(cb, [Vector2(16, 7.5), Vector2(16, 1.6), Vector2(35, 1.6), Vector2(35, 19)], 1.1, Pal.ink(0.32))
			cb.draw_colored_polygon(PackedVector2Array([_p(Vector2(13, 8)), _p(Vector2(19, 8)), _p(Vector2(17, 6.6)), _p(Vector2(15, 6.6))]), Pal.ink(0.2))
			_box(cb, Vector2(31, 19), Vector2(8, 7.8), Pal.ink(0.5))
			for i in 5:
				cb.draw_line(_p(Vector2(32 + i * 1.5, 20.5)), _p(Vector2(32 + i * 1.5, 25.5)), Pal.ink(0.2), 0.3 * _m)
			_pipe(cb, [Vector2(39, 21), Vector2(42, 21), Vector2(42, 0.8)], 0.5, Pal.ink(0.25))
			# the transformer and its bus to the electrode arms
			_box(cb, Vector2(2, 20), Vector2(6, 6.8), Pal.ink(0.5))
			for i in 3:
				cb.draw_line(_p(Vector2(2.6 + i * 1.8, 20.6)), _p(Vector2(2.6 + i * 1.8, 26.2)), Pal.ink(0.18), 0.4 * _m)
			_pipe(cb, [Vector2(7, 20), Vector2(7, 17.5), Vector2(11, 17.5), Vector2(11, 9.5), Vector2(13, 9.5)], 0.35, hot)
			_catwalk(cb, 20.0, 30.0, 4.6, 29.0, 9.0)
			_label(cb, Vector2(31, 18.4), "baghouse", Pal.ink(0.6))
			_label(cb, Vector2(2, 19.4), "transformer", Pal.ink(0.6))
			_label(cb, Vector2(21, 1.2), "duct", Pal.ink(0.45))
		"trade":
			# 52 号: the hall kept clear — only a light strip along the ceiling
			cb.draw_line(_p(Vector2(16, 0.8)), _p(Vector2(56, 0.8)), Pal.tint(Pal.AIR, 0.35 if on else 0.1, 1.1), 0.2 * _m)
		"cargo":
			cb.draw_line(_p(Vector2(8, 2)), _p(Vector2(52, 2)), Pal.ink(0.4), 0.4 * _m)
			# 46 号 (player 2026-10-25: "what are these red, yellow, blue, green things? put what I
			# bought and the billets I made in here"): rack shelves over the two bays, and on them
			# the stock actually held — each goods as itself, its pile by its tonnes, its name
			# 73 号: eight rows, A1–A4 and B1–B4, each with its use and how long a pick takes
			for bx in [6.0, 42.0]:
				for lv in 4:
					cb.draw_line(_p(Vector2(bx, 12 + lv * 3.0)), _p(Vector2(bx + 10, 12 + lv * 3.0)), Pal.ink(0.35), 0.15 * _m)
				for px in [bx, bx + 10.0]:
					cb.draw_line(_p(Vector2(px, 9)), _p(Vector2(px, 21)), Pal.ink(0.3), 0.15 * _m)
			var stock := _stock()
			var per_row := {}
			for k in stock:
				if float(stock[k]) > 0.004:
					var ri := Warehouse.row_for(str(k))
					if not per_row.has(ri):
						per_row[ri] = []
					per_row[ri].append(str(k))
			for ri in Warehouse.ROWS.size():
				var at: Vector2 = Warehouse.ROW_AT[ri]
				# under the shelf, right-aligned: clear of the works desk's sign at bay A's left
				cb.draw_string(font, _p(Vector2(at.x, at.y + 0.75)), Warehouse.row_text(ri, game), HORIZONTAL_ALIGNMENT_RIGHT, 9.8 * _m, int(0.42 * _m), Pal.tint(Pal.AIR, 0.6, 1.0))
				var list: Array = per_row.get(ri, [])
				for n in list.size():
					_pile(cb, str(list[n]), float(stock[list[n]]), at + Vector2(0.0, 0.0), n, list.size())
			var parts: int = Career.data.get("parts", []).size()
			if parts > 0:
				for i in mini(parts, 3):
					cb.draw_rect(Rect2(_p(Vector2(53.4 + i * 1.5, 19.6)), Vector2(1.3, 1.3) * _m), Pal.tint(Pal.AIR, 0.35, 0.9))
				cb.draw_string(font, _p(Vector2(53, 19.2)), w("零件 %d 件", "%d PARTS") % parts, HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.6 * _m), Pal.ink(0.75))
			cb.draw_line(_p(Vector2(34, 25.6)), _p(Vector2(52, 25.6)), Pal.ink(0.35), 0.2 * _m)
			_box(cb, Vector2(53, 21), Vector2(5, 5.8), Pal.ink(0.5))
			for i in 3:
				cb.draw_line(_p(Vector2(53, 22.8 + i * 1.6)), _p(Vector2(58, 22.8 + i * 1.6)), Pal.ink(0.25), 0.2 * _m)
			_label(cb, Vector2(53, 20.4), "pallets", Pal.ink(0.6))
			_label(cb, Vector2(34, 25.0), "rollers", Pal.ink(0.45))
			_label(cb, Vector2(9, 1.4), "stacker", Pal.ink(0.5))
	cb.flush()


func _ring_still(cb) -> void:
	var c := PortStructure.centre()
	var m := PortStructure.M()
	for zone in PortArt.ANGLE:
		var a: float = ((PortStructure.door(zone)[0] as Vector2) - c).angle()
		var on := Port.stage(zone) >= 1
		var col := Pal.tint(Pal.AIR, 0.28, 1.0) if on else Pal.ink(0.14)
		for s in [-1.2, 1.2]:
			var off: Vector2 = Vector2.from_angle(a).orthogonal() * s * m
			cb.draw_line(c + Vector2.from_angle(a) * (PortArt.CORE_R + 1.0) * m + off, c + Vector2.from_angle(a) * (PortArt.HUB_R - 1.0) * m + off, Color(0.02, 0.022, 0.026), 0.4 * m)
			cb.draw_line(c + Vector2.from_angle(a) * (PortArt.CORE_R + 1.0) * m + off, c + Vector2.from_angle(a) * (PortArt.HUB_R - 1.0) * m + off, col, 0.22 * m)
	cb.draw_arc(c, (PortArt.CORE_R + 1.0) * m, 0.0, TAU, 64, Pal.ink(0.3), 0.6 * m)
	cb.draw_string(font, c + Vector2(-3.0, -(PortArt.CORE_R + 2.0)) * m, w("主管廊", "PIPE GALLERY"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.75 * m), Pal.ink(0.5))


# ------------------------------------------------------------------ the moving parts
func _draw_moving() -> void:
	var zone := _zone()
	if zone == "" or game == null:
		return
	_m = PortStructure.M()
	var ph := float(phase.get(zone, 0.0))
	var k := float(speed.get(zone, 0.0))
	if zone == "ring":
		var c := PortStructure.centre()
		var m := _m
		var a0 := ph * 0.6
		for i in 12:
			var a := a0 + TAU * i / 12.0
			moving.draw_line(c + Vector2.from_angle(a) * (PortArt.CORE_R + 0.5) * m, c + Vector2.from_angle(a) * (PortArt.CORE_R + 1.5) * m, Pal.tint(Pal.AIR, 0.3 + 0.5 * k, 1.2), 0.3 * m)
		for zone2 in PortArt.ANGLE:
			if Port.stage(zone2) < 1:
				continue
			var a2: float = ((PortStructure.door(zone2)[0] as Vector2) - c).angle()
			var f := fmod(ph * 2.0 + zone2.length() * 0.37, 1.0)
			var at := c + Vector2.from_angle(a2) * lerpf(PortArt.CORE_R + 1.0, PortArt.HUB_R - 1.0, f) * m
			moving.draw_circle(at + Vector2.from_angle(a2).orthogonal() * 1.2 * m, 0.2 * m, Pal.tint(Pal.AIR, 0.8, 1.3))
		return
	_r = PortStructure.box(zone)
	match zone:
		"power":
			# the shaft turning (marks on the coupling and the exciter) and the flow in the hot leg
			for cx in [50.2, 54.8]:
				for i in 3:
					var a := ph * 9.0 + TAU * i / 3.0
					moving.draw_line(_p(Vector2(cx, 10.0)), _p(Vector2(cx, 10.0)) + Vector2.from_angle(a) * 0.6 * _m, Pal.ink(0.5 + 0.3 * k), 0.12 * _m)
			_flow([Vector2(9, 6), Vector2(9, 3), Vector2(46, 3), Vector2(46, 7)], ph * 3.0, Pal.heat(0.9, 1.3), k)
			_flow([Vector2(52, 13), Vector2(52, 16), Vector2(34, 16), Vector2(34, 24.5), Vector2(13, 24.5)], ph * 3.0, Pal.tint(Pal.AIR, 0.8, 1.2), k)
			var p_on: bool = Port.stage("power") >= 1
			if p_on:
				moving.draw_string(font, _p(Vector2(39, 14.3)), "%.1f MW" % power_mw, HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.7 * _m), Pal.tint(Pal.AIR, 0.8, 1.2))
			_power_state(p_on, k)
		"tug":
			tug_art.r = _r
			tug_art.m = _m
			var t1 := Time.get_ticks_usec()
			tug_art.moving(moving, t, Port.stage("tug") >= 1, lod())
			tug_draw_us = lerpf(tug_draw_us, float(Time.get_ticks_usec() - t1), 0.05)
		"process":
			_flow([Vector2(16, 7.5), Vector2(16, 1.6), Vector2(35, 1.6), Vector2(35, 19)], ph * 2.0, Pal.heat(0.6, 1.1), k if k > 0.5 else 0.0)
			# the baghouse's pulse-jet: a short flash in turn on each bag
			if k > 0.5:
				var bag := int(ph * 2.0) % 5
				moving.draw_line(_p(Vector2(32 + bag * 1.5, 20.5)), _p(Vector2(32 + bag * 1.5, 25.5)), Pal.tint(Pal.AIR, 0.7, 1.3), 0.3 * _m)
		"trade":
			pass
		"cargo":
			# the stacker: parked and dark until stock really moves, then one lift for that goods
			var cr := crane_pose()
			var x3: float = cr.x
			var drop: float = cr.hook
			var on: bool = not haul.is_empty()
			moving.draw_rect(Rect2(_p(Vector2(x3 - 2.0, 1.4)), Vector2(4.0, 1.4) * _m), Pal.heat(0.6, 1.0) if on else Pal.ink(0.3))
			moving.draw_line(_p(Vector2(x3, 2.8)), _p(Vector2(x3, drop)), Pal.ink(0.5), 0.08 * _m)
			moving.draw_rect(Rect2(_p(Vector2(x3 - 1.3, drop)), Vector2(2.6, 0.5) * _m), Pal.ink(0.7))
			if cr.load:
				_unit(moving, str(haul.key), Vector2(x3 - 1.2, drop + 0.5), 2.4)
			# 73 号: the forklifts, from the hatch to their row and back
			var jobs: Array = Warehouse.data().jobs
			for fi in mini(Warehouse.forklifts(), jobs.size()):
				var j: Dictionary = jobs[fi]
				var pr := clampf(1.0 - float(j.left) / maxf(0.01, float(j.total)), 0.0, 1.0)
				var row_p: Vector2 = Warehouse.ROW_AT[int(j.row)] + Vector2(4.0 + fi * 1.5, -0.2)
				var hatch := Warehouse.HATCH + Vector2(fi * 2.0, -0.6)
				var fp := hatch.lerp(row_p, pr * 2.0) if pr < 0.5 else row_p.lerp(hatch, (pr - 0.5) * 2.0)
				var loaded: bool = (pr >= 0.5) if not str(j.dir) in ["in", "store"] else (pr < 0.5)
				moving.draw_rect(Rect2(_p(fp + Vector2(-1.1, -1.0)), Vector2(2.2, 1.0) * _m), Pal.heat(0.7, 1.0))
				moving.draw_line(_p(fp + Vector2(1.1, -1.8)), _p(fp + Vector2(1.1, 0.0)), Pal.ink(0.7), 0.12 * _m)
				moving.draw_line(_p(fp + Vector2(1.1, -0.1)), _p(fp + Vector2(2.2, -0.1)), Pal.ink(0.7), 0.1 * _m)
				moving.draw_circle(_p(fp + Vector2(-0.6, 0.1)), 0.3 * _m, Pal.ink(0.5))
				moving.draw_circle(_p(fp + Vector2(0.6, 0.1)), 0.3 * _m, Pal.ink(0.5))
				if loaded:
					_unit(moving, str(j.key), fp + Vector2(1.2, -1.6), 1.2)
			for i in 9:
				var rx := 34.5 + i * 2.0
				var a3 := roll * 8.0 + i
				moving.draw_circle(_p(Vector2(rx, 26.1)), 0.45 * _m, Pal.ink(0.3), false, 0.08 * _m)
				moving.draw_line(_p(Vector2(rx, 26.1)), _p(Vector2(rx, 26.1)) + Vector2.from_angle(a3) * 0.45 * _m, Pal.ink(0.5), 0.08 * _m)


# ------------------------------------------------------------------ the power district (48 号)
func _power_frac() -> float:
	return clampf(power_mw / maxf(1.0, Grid.capacity()), 0.0, 1.0)


const FEEDERS := ["base", "heat", "sort", "trolley", "crane", "tram"]
func _feeders_on() -> Dictionary:
	var on := {}
	if game == null:
		return on
	for l in Grid.loads(game):
		if str(l.state) in ["run", "base"]:
			on[str(l.id)] = true
	return on


func _feeders_sig() -> String:
	var on := _feeders_on()
	var s := ""
	for f in FEEDERS:
		s += "1" if on.has(f) else "0"
	return s


# a reactor in section: the shield, the vessel with its heads, the core's fuel assemblies, the
# control rod drives on top and the rods in as deep as the load lets them out
func _reactor(cb, at: Vector2, name: String, frac: float, on: bool) -> void:
	var shield := Rect2(_p(at), Vector2(8, 12) * _m)
	cb.draw_rect(shield, Color(0.09, 0.095, 0.1))
	cb.draw_rect(shield, Pal.ink(0.6), false, 0.12 * _m)
	var inner := Rect2(_p(at + Vector2(0.8, 0.8)), Vector2(6.4, 10.4) * _m)
	cb.draw_rect(inner, Color(0.035, 0.04, 0.045))
	# the vessel: a shell with dished heads
	var vx0 := at.x + 2.0
	var vx1 := at.x + 6.0
	var vt := at.y + 3.4
	var vb := at.y + 9.6
	cb.draw_rect(Rect2(_p(Vector2(vx0, vt)), Vector2(vx1 - vx0, vb - vt) * _m), Color(0.13, 0.135, 0.14))
	cb.draw_line(_p(Vector2(vx0, vt)), _p(Vector2(vx0, vb)), Pal.ink(0.8), 0.14 * _m)
	cb.draw_line(_p(Vector2(vx1, vt)), _p(Vector2(vx1, vb)), Pal.ink(0.8), 0.14 * _m)
	cb.draw_arc(_p(Vector2((vx0 + vx1) * 0.5, vt)), 2.0 * _m, PI, TAU, 20, Pal.ink(0.8), 0.14 * _m)
	cb.draw_arc(_p(Vector2((vx0 + vx1) * 0.5, vb)), 2.0 * _m, 0.0, PI, 20, Pal.ink(0.8), 0.14 * _m)
	# the core: fuel assemblies, glowing with the load
	for i in 4:
		for j in 3:
			var fa := Rect2(_p(Vector2(vx0 + 0.25 + i * 0.9, at.y + 6.6 + j * 0.9)), Vector2(0.75, 0.75) * _m)
			cb.draw_rect(fa, Pal.heat(0.15 + 0.6 * frac, 1.0) if on else Color(0.12, 0.12, 0.12))
			cb.draw_rect(fa, Pal.ink(0.4), false, 0.04 * _m)
	# the drives on top and the rods: in deeper at a light load
	var depth := lerpf(3.0, 0.6, frac) if on else 3.2
	for i in 4:
		var rx := vx0 + 0.6 + i * 0.9
		cb.draw_rect(Rect2(_p(Vector2(rx - 0.25, at.y + 0.3)), Vector2(0.5, 1.6) * _m), Color(0.16, 0.17, 0.18))
		cb.draw_rect(Rect2(_p(Vector2(rx - 0.25, at.y + 0.3)), Vector2(0.5, 1.6) * _m), Pal.ink(0.6), false, 0.05 * _m)
		cb.draw_line(_p(Vector2(rx, at.y + 1.9)), _p(Vector2(rx, at.y + 6.6 + depth)), Pal.ink(0.75), 0.1 * _m)
	# the primary nozzles out to the steam generator line
	cb.draw_line(_p(Vector2(vx1, at.y + 5.0)), _p(Vector2(at.x + 7.6, at.y + 5.0)), Pal.heat(0.7, 1.0) if on else Pal.ink(0.3), 0.3 * _m)
	cb.draw_string(font, _p(at + Vector2(0.3, -0.3)), w("反应堆 %s · 控制棒抽出 %d%%", "REACTOR %s · RODS %d%% OUT") % [name, int(round((1.0 - depth / 3.2) * 100.0))], HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.5 * _m), Pal.ink(0.75))


# the turbine-generator on its block (38..55 × 7..13): HP and LP casings, the shaft, the coupling,
# the generator with its cooling fins, the exciter; the condenser under the LP casing
func _turbine_set(cb, on: bool) -> void:
	var y := 10.0
	cb.draw_rect(Rect2(_p(Vector2(38, 12.2)), Vector2(17, 0.8) * _m), Color(0.1, 0.105, 0.11))
	# HP casing, small; LP casing, big
	cb.draw_colored_polygon(PackedVector2Array([_p(Vector2(38.6, y - 1.0)), _p(Vector2(42.4, y - 1.6)), _p(Vector2(42.4, y + 1.6)), _p(Vector2(38.6, y + 1.0))]), Color(0.15, 0.16, 0.17))
	cb.draw_polyline(PackedVector2Array([_p(Vector2(38.6, y - 1.0)), _p(Vector2(42.4, y - 1.6)), _p(Vector2(42.4, y + 1.6)), _p(Vector2(38.6, y + 1.0)), _p(Vector2(38.6, y - 1.0))]), Pal.ink(0.8), 0.1 * _m)
	cb.draw_colored_polygon(PackedVector2Array([_p(Vector2(42.8, y - 1.6)), _p(Vector2(49.4, y - 2.6)), _p(Vector2(49.4, y + 2.0)), _p(Vector2(42.8, y + 1.6))]), Color(0.14, 0.15, 0.16))
	cb.draw_polyline(PackedVector2Array([_p(Vector2(42.8, y - 1.6)), _p(Vector2(49.4, y - 2.6)), _p(Vector2(49.4, y + 2.0)), _p(Vector2(42.8, y + 1.6)), _p(Vector2(42.8, y - 1.6))]), Pal.ink(0.8), 0.1 * _m)
	for bx in [44.2, 45.6, 47.0, 48.4]:
		cb.draw_line(_p(Vector2(bx, y - 1.9)), _p(Vector2(bx, y + 1.7)), Pal.ink(0.3), 0.05 * _m)
	# the shaft through, the coupling
	cb.draw_line(_p(Vector2(38.2, y)), _p(Vector2(55.2, y)), Pal.ink(0.7), 0.18 * _m)
	cb.draw_circle(_p(Vector2(50.2, y)), 0.6 * _m, Color(0.12, 0.12, 0.13))
	cb.draw_arc(_p(Vector2(50.2, y)), 0.6 * _m, 0.0, TAU, 12, Pal.ink(0.7), 0.08 * _m)
	# the generator: stator with fins, the exciter at the end
	var gen := Rect2(_p(Vector2(51.0, y - 1.8)), Vector2(3.2, 3.6) * _m)
	cb.draw_rect(gen, Color(0.13, 0.14, 0.15))
	cb.draw_rect(gen, Pal.tint(Pal.AIR, 0.6, 1.0) if on else Pal.ink(0.5), false, 0.1 * _m)
	for fy in range(6):
		cb.draw_line(_p(Vector2(51.0, y - 1.5 + fy * 0.6)), _p(Vector2(54.2, y - 1.5 + fy * 0.6)), Pal.ink(0.25), 0.05 * _m)
	cb.draw_circle(_p(Vector2(54.8, y)), 0.7 * _m, Color(0.12, 0.12, 0.13))
	cb.draw_arc(_p(Vector2(54.8, y)), 0.7 * _m, 0.0, TAU, 12, Pal.ink(0.7), 0.08 * _m)
	# the condenser under the LP casing, cooling water in and out
	cb.draw_rect(Rect2(_p(Vector2(43.4, y + 2.0)), Vector2(5.6, 0.9) * _m), Color(0.1, 0.12, 0.14))
	cb.draw_rect(Rect2(_p(Vector2(43.4, y + 2.0)), Vector2(5.6, 0.9) * _m), Pal.tint(Pal.AIR, 0.5, 1.0), false, 0.06 * _m)
	cb.draw_string(font, _p(Vector2(38.4, 6.4)), w("汽轮发电机 · 高压缸 / 低压缸 / 发电机 / 励磁机 · 冷凝器", "TURBINE-GENERATOR · HP / LP / GENERATOR / EXCITER · CONDENSER"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.5 * _m), Pal.ink(0.75))


# the main coolant pumps (4..13 × 21..26.8): three motor-pump sets, motor above, volute below
func _pumps(cb, on: bool) -> void:
	for i in 3:
		var x := 5.4 + i * 3.0
		cb.draw_rect(Rect2(_p(Vector2(x - 0.8, 21.4)), Vector2(1.6, 2.2) * _m), Color(0.14, 0.15, 0.16))
		cb.draw_rect(Rect2(_p(Vector2(x - 0.8, 21.4)), Vector2(1.6, 2.2) * _m), Pal.ink(0.7), false, 0.07 * _m)
		for k in 4:
			cb.draw_line(_p(Vector2(x - 0.8, 21.7 + k * 0.45)), _p(Vector2(x + 0.8, 21.7 + k * 0.45)), Pal.ink(0.3), 0.04 * _m)
		cb.draw_circle(_p(Vector2(x, 24.9)), 1.0 * _m, Color(0.12, 0.13, 0.14))
		cb.draw_arc(_p(Vector2(x, 24.9)), 1.0 * _m, 0.0, TAU, 16, Pal.tint(Pal.AIR, 0.6, 1.0) if on else Pal.ink(0.5), 0.08 * _m)
		cb.draw_line(_p(Vector2(x, 23.6)), _p(Vector2(x, 23.9)), Pal.ink(0.7), 0.15 * _m)
	cb.draw_string(font, _p(Vector2(4, 20.6)), w("主冷却泵 ×3", "COOLANT PUMPS ×3"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.5 * _m), Pal.ink(0.75))


# the switchgear (40..54 × 18..23): a row of cubicles, one per feeder; on the door a lamp (lit when
# its breaker is closed) and an ammeter; the busbar along the top
func _switchgear(cb) -> void:
	var on := _feeders_on()
	for i in 3:
		cb.draw_line(_p(Vector2(40.2, 18.2 + i * 0.25)), _p(Vector2(53.8, 18.2 + i * 0.25)), Pal.heat(0.55, 1.0), 0.08 * _m)
	var names := [["基础", "BASE"], ["电弧炉", "EAF"], ["分选", "SORT"], ["吊轨", "RAIL"], ["码头吊", "CRANE"], ["接驳", "TRAM"]]
	for i in FEEDERS.size():
		var x := 40.2 + i * 2.27
		var door := Rect2(_p(Vector2(x, 19.0)), Vector2(2.1, 4.0) * _m)
		cb.draw_rect(door, Color(0.12, 0.13, 0.14))
		cb.draw_rect(door, Pal.ink(0.6), false, 0.06 * _m)
		var closed := on.has(FEEDERS[i])
		cb.draw_circle(_p(Vector2(x + 0.5, 19.6)), 0.25 * _m, Pal.tint(Pal.FLUID, 0.95, 1.3) if closed else Pal.heat(0.5, 1.0))
		cb.draw_arc(_p(Vector2(x + 1.4, 20.4)), 0.45 * _m, PI, TAU, 10, Pal.ink(0.6), 0.05 * _m)
		cb.draw_line(_p(Vector2(x + 0.3, 21.6)), _p(Vector2(x + 1.8, 21.6)), Pal.ink(0.35), 0.05 * _m)
		cb.draw_string(font, _p(Vector2(x + 0.2, 22.7)), names[i][0] if Txt.zh else names[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.42 * _m), Pal.ink(0.8))
	cb.draw_string(font, _p(Vector2(40.2, 17.6)), w("配电柜 · 每面柜一条馈线（绿灯 = 合闸）", "SWITCHGEAR · ONE FEEDER EACH (GREEN = CLOSED)"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.5 * _m), Pal.ink(0.75))


# ------------------------------------------------------------------ the tug station's shop (47 号, 96 号)
# 1 with the drone inside the tug station, falling to 0 some 30 m out
func _tug_near() -> float:
	if game == null or game.get("drone") == null:
		return 0.0
	var b := PortStructure.box("tug").grow(30.0 * PortStructure.M())
	var p: Vector2 = game.drone.global_position
	if not b.has_point(p):
		return 0.0
	return 1.0 if PortStructure.box("tug").has_point(p) else 0.5

# how much to draw: 1 (every bolt) when a metre is big enough on screen to see them
func lod() -> int:
	var z := get_viewport().get_canvas_transform().get_scale().x if is_inside_tree() else 1.0
	return 1 if _m * z >= 14.0 or PortStructure.M() * z >= 14.0 else 0


# ------------------------------------------------------------------ the warehouse's real stock (46 号)
# where each goods lies: bay A (left) the feed, bay B (right) the products; [x0, shelf y]
const SHELF := {"mixed_metal:0": [6.0, 15.0], "ferrous_scrap:0": [6.0, 18.0], "ferrous_scrap:1": [6.0, 21.0],
	"steel_billet:1": [42.0, 15.0], "steel_billet:0": [42.0, 18.0], "steel_billet:2": [47.0, 18.0], "nonferrous_mix:0": [42.0, 21.0]}
const UNIT_T := 0.5            # one bundle, bale, bag or skip on the shelf
const PARK_X := 9.0            # the stacker's parking spot
const HATCH_AT := Vector2(30.0, 26.0)
const HAUL_S := 6.0
var haul := {}                 # {key, dir (+1 in / -1 out), t} while the stacker carries one
var roll := 0.0
var _seen := {}                # the stock the stacker last saw
var _seen_ok := false


func _stock() -> Dictionary:
	return Career.data.get("exchange", {}).get("actors", {}).get("company", {}).get("stock", {})


func _stock_sig() -> String:
	var parts: Array = []
	var st := _stock()
	for k in st:
		parts.append("%s=%.2f" % [str(k), float(st[k])])
	return ",".join(parts) + "/%d/%s/%d" % [Career.data.get("parts", []).size(), str(Warehouse.rows()), int(Warehouse.k(game) * 10.0)]


# stock that really changed starts one lift: in from the floor hatch, or out to it
func _watch_stock(dt: float) -> void:
	var st := _stock()
	if not _seen_ok:
		for k in st:
			_seen[k] = float(st.get(k, 0.0))
		_seen_ok = true
	if haul.is_empty():
		for k in st:
			var now := float(st.get(k, 0.0))
			if absf(now - float(_seen.get(k, 0.0))) > 0.004:
				haul = {"key": k, "dir": 1 if now > float(_seen.get(k, 0.0)) else -1, "t": 0.0}
				_seen[k] = now
				break
	else:
		haul.t = float(haul.t) + dt
		roll += dt
		if float(haul.t) >= HAUL_S:
			haul = {}


func slot_at(k: String) -> Vector2:
	var at: Vector2 = Warehouse.ROW_AT[Warehouse.row_for(k)]
	return Vector2(at.x + 2.0, at.y - 1.6)


# where the stacker's trolley and hook are now, and whether it holds the load
func crane_pose() -> Dictionary:
	if haul.is_empty():
		return {"x": PARK_X, "hook": 3.4, "load": false}
	var k := float(haul.t) / HAUL_S
	var a: Vector2 = HATCH_AT if int(haul.dir) > 0 else slot_at(str(haul.key))
	var b: Vector2 = slot_at(str(haul.key)) if int(haul.dir) > 0 else HATCH_AT
	if k < 0.2:
		return {"x": lerpf(PARK_X, a.x, k / 0.2), "hook": 3.4, "load": false}
	if k < 0.35:
		return {"x": a.x, "hook": lerpf(3.4, a.y - 1.0, (k - 0.2) / 0.15), "load": k > 0.33}
	if k < 0.75:
		var u := (k - 0.35) / 0.4
		return {"x": lerpf(a.x, b.x, u), "hook": lerpf(a.y - 1.0, b.y - 1.0, u) - sin(u * PI) * 6.0, "load": true}
	if k < 0.85:
		return {"x": b.x, "hook": b.y - 1.0, "load": k < 0.83}
	return {"x": lerpf(b.x, PARK_X, (k - 0.85) / 0.15), "hook": 3.4, "load": false}


# one shelf unit of a goods, drawn as itself (a bundle of billets, a bale, a bag, a skip)
func _unit(ci, k: String, at: Vector2, wm: float) -> void:
	# 55 号: the same picture as on the exchange and the hall's screens (GoodsArt, 160 × 100)
	var h := wm * 100.0 / 160.0
	var r := Rect2(_p(at + Vector2(0.0, 1.4 - h)), Vector2(wm, h) * _m)
	var parts := k.split(":")
	GoodsArt.draw(ci, r, parts[0], int(parts[1]) if parts.size() > 1 else 0)


func _pile(cb, k: String, have: float, row_at: Vector2 = Vector2.INF, n: int = 0, of: int = 1) -> void:
	var s: Array = [row_at.x, row_at.y] if row_at != Vector2.INF else SHELF.get(k, [6.0, 15.0])
	var wide := 9.4 / maxf(1.0, of)
	var x0 := float(s[0]) + 0.3 + n * wide
	var y_shelf := float(s[1])
	var units := clampi(int(ceil(have / UNIT_T)), 1, 12)
	# 55 号: each unit 2.4 m wide so the picture reads at the warehouse's usual zoom
	var per_row := maxi(1, int(wide / 2.5))
	for i in mini(units, per_row):
		_unit(cb, k, Vector2(x0 + i * 2.5, y_shelf - 1.5), 2.4)
	# bay A's labels start clear of the works desk's sign at its left
	var lx := x0 + (3.6 if float(s[0]) < 20.0 and y_shelf > 16.0 and n == 0 else 0.0)
	cb.draw_string(font, _p(Vector2(lx, y_shelf - 1.7)), "%s · %.2f t" % [Ops.item_name(k), have], HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.55 * _m), Pal.ink(0.8))


# light pulses running along a pipe, spaced 3 m, as fast as the district works
func _flow(pts: Array, run: float, col: Color, k: float) -> void:
	if k <= 0.01:
		return
	var total := 0.0
	for i in range(1, pts.size()):
		total += (pts[i] as Vector2).distance_to(pts[i - 1])
	var s := fmod(run * 3.0, 3.0)
	while s < total:
		var left := s
		for i in range(1, pts.size()):
			var seg := (pts[i] as Vector2).distance_to(pts[i - 1])
			if left <= seg:
				moving.draw_circle(_p((pts[i - 1] as Vector2).lerp(pts[i], left / seg)), 0.22 * _m, col)
				break
			left -= seg
		s += 3.0


# ------------------------------------------------------------------ 91 号: the power district reads its own state
# (user 2026-10-27: "像动力区那几个核动力炉，它应该怎么做…对玩家更有利" — Jev A: say at a glance
# whether it runs, why not, what fixing it does, and where the power goes)
var _loads: Array = []
var _loads_t := 0.0


func _power_loads() -> Array:
	if t - _loads_t > 0.5 or _loads.is_empty():
		_loads_t = t
		_loads = Grid.loads(game) if game != null else []
	return _loads


func _plate(rect_m: Rect2, edge: Color, lines: Array) -> void:
	var r := Rect2(_p(rect_m.position), rect_m.size * _m)
	moving.draw_rect(r, Color(0.02, 0.022, 0.026, 0.86))
	moving.draw_rect(Rect2(r.position, Vector2(0.25 * _m, r.size.y)), edge)
	moving.draw_rect(r, Color(edge.r, edge.g, edge.b, 0.35), false, 0.06 * _m)
	var y := r.position.y + 0.95 * _m
	for ln in lines:
		var size: float = ln[1]
		moving.draw_string(font, Vector2(r.position.x + 0.7 * _m, y), str(ln[0]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 1.0 * _m, int(size * _m), ln[2])
		y += size * _m * 1.45


func _power_state(on: bool, k: float) -> void:
	var frac := _power_frac()
	if not on:
		# shut down, and why: the plain words, what fixing it does, where to fix it
		var blink := 0.55 + 0.45 * absf(sin(t * 2.2))
		_plate(Rect2(Vector2(4.4, 12.4), Vector2(21.0, 7.4)), Color(1.0, 0.35, 0.25, blink), [
			[w("停堆 · 冷态 · 没有电", "SHUT DOWN · COLD · NO POWER"), 0.95, Color(1.0, 0.45, 0.35)],
			[w("动力区还没修好（第 1 期），两座堆都停着。", "The power district isn't fixed yet (stage 1): both reactors are down."), 0.55, Pal.ink(0.85)],
			[w("修好后：堆启动、汽轮机转起来，各区才有电，干活更快。", "Fixed: the reactors start, the turbine turns, the districts get power."), 0.55, Pal.ink(0.85)],
			[w("去修：船坞终端 → 成长与建设 → 零压港 → 动力区", "Fix it: berth terminal → growth → the port → power"), 0.55, Color(UiSkin.ACCENT)],
		])
		_plate(Rect2(Vector2(38.4, 13.6), Vector2(12.0, 1.9)), Pal.ink(0.5), [[w("汽轮机停机 · 0 rpm", "TURBINE STOPPED · 0 rpm"), 0.6, Pal.ink(0.7)]])
		return
	# running: what it puts out against what it can, the load as a bar, the cores breathing with it
	var cap := Grid.capacity()
	var bar_w := 10.0
	_plate(Rect2(Vector2(25.6, 6.8), Vector2(11.8, 5.2)), Color(UiSkin.DATA), [
		[w("运行中", "RUNNING"), 0.85, Color(UiSkin.DATA)],
		[w("输出 %.1f MW / 容量 %.0f MW", "OUT %.1f MW / CAP %.0f MW") % [power_mw, cap], 0.55, Pal.ink(0.9)],
		[w("负荷 %d%%", "LOAD %d%%") % int(round(frac * 100.0)), 0.55, Pal.ink(0.9)],
	])
	var bar := Rect2(_p(Vector2(26.3, 11.2)), Vector2(bar_w, 0.35) * _m)
	moving.draw_rect(bar, Pal.ink(0.12))
	moving.draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Pal.heat(0.9, 1.2) if frac > 0.85 else Color(UiSkin.DATA))
	for at in [Vector2(9, 15.5), Vector2(20, 15.5)]:
		var pulse := 0.6 + 0.4 * sin(t * 1.3 + at.x)
		moving.draw_circle(_p(at), (1.6 + 0.5 * frac) * _m, Pal.heat(0.05 + 0.12 * frac * pulse, 1.4))
	# where it goes: each feeder's draw under its panel
	var by_id := {}
	for l in _power_loads():
		by_id[str(l.id)] = l
	for i in FEEDERS.size():
		var x := 40.2 + i * 2.27
		var l = by_id.get(FEEDERS[i])
		var mw: float = float(l.mw) if l != null else 0.0
		var st := str(l.state) if l != null else ""
		var col := Pal.tint(Pal.FLUID, 0.95, 1.2) if st in ["run", "base"] and mw > 0.01 else (Pal.heat(0.9, 1.2) if st == "short" else Pal.ink(0.45))
		var txt := ("%.1f" % mw) if mw > 0.01 else "—"
		if st == "short":
			txt = w("缺电", "SHORT")
		moving.draw_string(font, _p(Vector2(x + 0.2, 23.6)), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.5 * _m), col)
