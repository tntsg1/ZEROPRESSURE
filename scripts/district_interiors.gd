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
const PowerArt = preload("res://scripts/power_station_art.gd")
const PowerWorks = preload("res://scripts/power_works.gd")
const ProcArt = preload("res://scripts/process_art.gd")
const ProcWorks = preload("res://scripts/process_works.gd")
const CargoArt = preload("res://scripts/cargo_art.gd")
const CargoWorks = preload("res://scripts/cargo_works.gd")

# floor-standing pieces with collision, box-local metres: [id, position, size]
const SOLIDS := {
	# 100 号: the turbine deck, the condenser under it, the fuel cells, the feed pumps, the radiator pumps
	"power": [["turbine", Vector2(37.6, 6.2), Vector2(20.4, 6.4)], ["condenser", Vector2(43.0, 12.6), Vector2(6.6, 3.8)], ["fuelcell", Vector2(0.8, 19.6), Vector2(8.0, 7.2)],
		["feedpumps", Vector2(10.0, 23.4), Vector2(10.4, 3.4)], ["radpumps", Vector2(54.4, 19.4), Vector2(5.2, 7.4)]],
	"tug": [["fuel", Vector2(42.7, 16.8), Vector2(3.9, 10.0)], ["bins", Vector2(47.2, 19.4), Vector2(4.6, 7.4)]],
	"process": [["baghouse", Vector2(30.6, 10.2), Vector2(6.1, 7.4)], ["transformer", Vector2(2, 20), Vector2(6, 6.8)]],
	"trade": [],
	"cargo": [["pallets", Vector2(53, 21), Vector2(5, 5.8)]],
}
const NAMES := {
	"turbine": ["汽轮发电机", "TURBINE-GENERATOR"], "pumps": ["主冷却泵", "COOLANT PUMPS"], "condenser": ["冷凝器", "CONDENSER"],
	"fuelcell": ["应急燃料电池", "FUEL CELLS"], "feedpumps": ["给水泵", "FEED PUMPS"], "radpumps": ["散热泵", "RADIATOR PUMPS"],
	"fuel": ["推进剂储罐", "PROPELLANT TANK"], "bins": ["零件箱", "PARTS BINS"], "gantry": ["龙门吊", "GANTRY"],
	"baghouse": ["除尘布袋室", "BAGHOUSE"], "transformer": ["炉用变压器", "FURNACE TRANSFORMER"], "duct": ["排烟道", "FUME DUCT"],
	"sorter": ["传单分拣", "TUBE SORTER"], "tube": ["气动传单管", "PNEUMATIC TUBE"],
	"pallets": ["托盘", "PALLETS"], "stacker": ["堆垛吊车", "STACKER CRANE"], "rollers": ["辊道", "ROLLER LINE"],
	"gallery": ["主管廊", "PIPE GALLERY"], "catwalk": ["检修走台", "CATWALK"],
}

var game
var hall: Node2D              # 2026-11-12: the district's hall, under the port's drawing (_draw_hall)
var font: Font
var moving: Node2D
var _key := ""                 # what the still parts were drawn for
var draws := 0                 # tests: still-part redraws
var t := 0.0
var speed := {}                # zone → how fast its machinery runs now (0 still … 1 working hard)
var phase := {}                # zone → its machinery's running phase
var power_mw := 0.0            # what the bus draws now (the turbine's readout)
var power_art                  # 100 号: the power district's plant (scripts/power_station_art.gd)
var power_tick_us := 0.0       # tests: its plant's step, and its moving parts' drawing a frame (µs, smoothed)
var power_draw_us := 0.0
var _pw_read_t := 0.0
var power_words: Node2D        # its plates' and meters' words, redrawn five times a second
var _pw_words_t := 0.0
var tug_art                    # 96 号: the tug station's machines (scripts/tug_station_art.gd)
var card                       # 96 号: the hover card
var tug_tick_us := 0.0         # 96 号: what the tug station costs a frame (µs, smoothed): its machines' step
var tug_draw_us := 0.0         # … and its moving parts' drawing (the commands; the GPU's share is apart)
# 101 号: the processing district as a steelworks (scripts/process_art.gd, process_works.gd): its still
# hall behind the furnace, the moving parts behind and in front of it, the arcs' light added on top
var proc_art
var proc_still: Node2D
var proc_back: Node2D
var proc_front: Node2D
var proc_glow: Node2D
var proc_plates: Node2D        # the plates' text: four times a second (shaped text is dear)
var _plates_t := 0.0
# 102 号: the cargo district as a warehouse (scripts/cargo_art.gd, cargo_works.gd), on the same layers
var cargo_art
var cargo_still: Node2D
var cargo_back: Node2D
var cargo_front: Node2D
var cargo_glow: Node2D
var cargo_plates: Node2D
var _cargo_key := ""
var _cplates_t := 0.0
var _cplates_sig := ""
var cargo_tick_us := 0.0       # tests: the machines' step, their drawing a frame (µs, smoothed)
var cargo_draw_us := 0.0
var cargo_front_us := 0.0
var _proc_key := ""
var _glow_tex: Texture2D
var proc_tick_us := 0.0        # tests: the machines' step, and their drawing a frame (µs, smoothed)
var proc_draw_us := 0.0
var proc_front_us := 0.0


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
	# 2026-11-12: a district's hall (scripts/district_style.gd) under everything in it — the port's own
	# drawing is z 2 (its consoles), this node's a child of it and drawn after it; the districts' still
	# layers are z 0 (_layer), so the hall is z 0 too, added before them
	hall = Node2D.new()
	hall.z_as_relative = false
	hall.z_index = 0
	hall.draw.connect(_draw_hall)
	add_child(hall)
	font = Fonts.get_font("Medium")
	moving = Node2D.new()
	moving.draw.connect(_draw_moving)
	add_child(moving)
	TugWorks.reset()
	# 128 号 第 3 段: the districts' broken look and their lighting up when mended, under the game
	# itself (this node is hidden while nobody is in a district) — scripts/revive_host.gd
	if game != null and not game.has_meta("revive_host"):
		var rh = preload("res://scripts/revive_host.gd").new()
		rh.game = game
		rh.interiors = self
		game.set_meta("revive_host", rh)
		game.add_child.call_deferred(rh)
	tug_art = TugArt.new()
	tug_art.font = font
	# 96 号: the facility card over the machines (scripts/facility_card.gd)
	card = preload("res://scripts/facility_card.gd").new()
	card.items = func() -> Array:
		if not visible:
			# 105 号: out in the berth, the terminal on the tower and the parts rack
			return _desk_items("") if game != null and game.in_berth() else []
		var list: Array = []
		if _zone() == "tug":
			list = tug_art.hover_items()
		elif _zone() == "process":
			list = proc_art.hover_items(game)
		elif _zone() == "cargo":
			list = cargo_art.hover_items(game)
		elif _zone() == "power":
			list = power_art.hover_items(Port.stage("power"))
		elif _zone() == "ring" and get_parent() != null and get_parent().get("hub") != null:
			# 109 号: the carousel, its drives and arms, the bridge
			list = get_parent().hub.art.hover_items(game)
		# 103 号: the district's business console has its card too; 105 号: and its work desks
		return list + [_console_item(_zone())] + _desk_items(_zone())
	add_child(card)
	PowerWorks.reset()
	power_art = PowerArt.new()
	power_art.font = font
	power_words = Node2D.new()
	power_words.draw.connect(_draw_power_words)
	add_child(power_words)
	move_child(power_words, 0)
	ProcWorks.reset()
	proc_art = ProcArt.new()
	proc_art.font = font
	_glow_tex = Fx.make_glow_texture(1.6)
	# behind the furnace and the line (scripts/process_plant.gd draws them at 1), in front of them, light
	proc_still = _layer(0, _draw_proc_still)
	proc_back = _layer(0, _draw_proc_back)
	proc_front = _layer(3, _draw_proc_front)
	proc_glow = _layer(3, _draw_proc_glow)
	proc_plates = _layer(3, _draw_proc_plates)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	proc_glow.material = add
	CargoWorks.reset()
	cargo_art = CargoArt.new()
	cargo_art.font = font
	cargo_still = _layer(0, _draw_cargo_still)
	cargo_back = _layer(0, _draw_cargo_back)
	cargo_front = _layer(3, _draw_cargo_front)
	cargo_glow = _layer(3, _draw_cargo_glow)
	cargo_plates = _layer(3, _draw_cargo_plates)
	cargo_glow.material = add


func _layer(z: int, draw: Callable) -> Node2D:
	var n := Node2D.new()
	n.z_index = z
	n.z_as_relative = false
	n.visible = false
	n.draw.connect(draw)
	add_child(n)
	return n


func _zone() -> String:
	var st = get_parent()
	# 无缝进出: the district being shown (the drone in it, nearing it or just out of it)
	return str(st.view) if st != null and st.get("view") != null else ""


# how hard each district works now (0 off, ~0.3 idle with power, 1 busy)
func _busy(zone: String) -> float:
	var stage := Port.stage(zone) if zone != "ring" else Port.stage("power")
	if stage < 1:
		return 0.0
	# 128 号 第 3 段: lighting up after its mending, the machinery starts in turn (district_revive.gd)
	var held := preload("res://scripts/district_revive.gd").held(zone)
	if held >= 0.0:
		return held
	var k := 0.3
	match zone:
		"power":
			power_mw = PowerWorks.own + PowerWorks.shore
			k = clampf(PowerWorks.frac(), 0.15, 1.0)
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
	# 101 号: the processing district's machines run on its real state, seen or not
	if game != null and game.in_berth() and game.career():
		var t1 := Time.get_ticks_usec()
		ProcWorks.tick(game, dt)
		proc_tick_us = lerpf(proc_tick_us, float(Time.get_ticks_usec() - t1), 0.05)
		if not ProcWorks.events.is_empty():
			var inside := game.drone != null and PortStructure.box("process").grow(6.0 * PortStructure.M()).has_point(game.drone.global_position)
			for e in ProcWorks.events:
				if inside and game.get("sfx") != null:
					game.sfx.play(str(e[0]), PortStructure.box("process").position + (e[1] as Vector2) * PortStructure.M(), 0.7)
			ProcWorks.events.clear()
	# 100 号: the power district's plant, run on the grid's real figures (read four times a second)
	if game != null and game.in_berth() and game.career():
		var t2 := Time.get_ticks_usec()
		_pw_read_t -= dt
		var rd := {}
		if _pw_read_t <= 0.0:
			_pw_read_t = 0.25
			rd = PowerWorks.read(game)
		PowerWorks.tick(dt, rd)
		power_tick_us = lerpf(power_tick_us, float(Time.get_ticks_usec() - t2), 0.05)
		if not PowerWorks.events.is_empty():
			var pn := power_near()
			for e in PowerWorks.events:
				if pn > 0.0 and game.get("sfx") != null:
					game.sfx.play(str(e[0]), PortStructure.box("power").position + (e[1] as Vector2) * PortStructure.M(), 0.7 * pn)
			PowerWorks.events.clear()
	# 102 号: the warehouse's trucks and crane run on its real jobs, seen or not
	if game != null and game.in_berth() and game.career():
		var t3 := Time.get_ticks_usec()
		var cp := crane_pose()
		cp["key"] = str(haul.get("key", ""))
		CargoWorks.tick(game, dt, cp)
		cargo_tick_us = lerpf(cargo_tick_us, float(Time.get_ticks_usec() - t3), 0.05)
		if not CargoWorks.events.is_empty():
			var inside_c := game.drone != null and PortStructure.box("cargo").grow(6.0 * PortStructure.M()).has_point(game.drone.global_position)
			for e in CargoWorks.events:
				if inside_c and game.get("sfx") != null:
					game.sfx.play(str(e[0]), PortStructure.box("cargo").position + (e[1] as Vector2) * PortStructure.M(), 0.6)
			CargoWorks.events.clear()
	if not TugWorks.events.is_empty():
		var near := _tug_near()
		for e in TugWorks.events:
			if near > 0.0 and game != null and game.get("sfx") != null:
				game.sfx.play(str(e[0]), PortStructure.box("tug").position + (e[1] as Vector2) * PortStructure.M(), 0.75 * near)
		TugWorks.events.clear()
	var zone := _zone()
	visible = zone != "" and game != null and game.in_berth()
	power_words.visible = visible and zone == "power"
	for n in [proc_still, proc_back, proc_front, proc_glow, proc_plates]:
		n.visible = visible and zone == "process"
	for n in [cargo_still, cargo_back, cargo_front, cargo_glow, cargo_plates]:
		n.visible = visible and zone == "cargo"
	if not visible:
		return
	if zone == "power":
		_pw_words_t -= dt
		if _pw_words_t <= 0.0:
			_pw_words_t = 0.2
			power_words.queue_redraw()
	if zone == "process":
		var pk := "%d/%d" % [int(Port.stage("process") >= 1), lod()]
		if pk != _proc_key:
			_proc_key = pk
			proc_still.queue_redraw()
		proc_back.queue_redraw()
		proc_front.queue_redraw()
		proc_glow.queue_redraw()
		_plates_t -= dt
		if _plates_t <= 0.0:
			_plates_t = 0.25
			proc_plates.queue_redraw()
	if zone == "cargo":
		var ck := "%d/%d/%d" % [int(Port.stage("cargo") >= 1), lod(), ProcessQueue.entries().reduce(func(acc, e): return acc + int(float(e.melted) * 10.0) + 1000, 0)]
		if ck != _cargo_key:
			_cargo_key = ck
			cargo_still.queue_redraw()
		cargo_back.queue_redraw()
		cargo_front.queue_redraw()
		cargo_glow.queue_redraw()
		_cplates_t -= dt
		if _cplates_t <= 0.0:
			_cplates_t = 0.25
			var sig2: String = cargo_art.plates_sig(game)
			if sig2 != _cplates_sig:
				_cplates_sig = sig2
				cargo_plates.queue_redraw()
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
		sig = str(lod())
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
		# 109 号: the hub is scripts/hub_view.gd's
		cb.flush()
		return
	_r = PortStructure.box(zone)
	match zone:
		"power":
			# 100 号: the plant as its three loops (scripts/power_station_art.gd)
			power_art.r = _r
			power_art.m = _m
			cb.flush()
			if DistrictStyle.on() and DistrictStyle.halls:
				hall.queue_redraw()
			power_art.still(self, Port.stage("power"), lod())
		"tug":
			# 96 号: the whole station as the machines it holds (scripts/tug_station_art.gd)
			tug_art.r = _r
			tug_art.m = _m
			cb.flush()
			if DistrictStyle.on():
				DistrictStyle.back_wall(self, _r, _m, on, tug_art.FLOOR)
			tug_art.still(self, on, lod(), Port.stage("tug"))
		"process":
			# 101 号: drawn by scripts/process_art.gd on its own layers; 2026-11-12 the hall behind it
			if DistrictStyle.on() and DistrictStyle.halls:
				hall.queue_redraw()
		"trade":
			if DistrictStyle.on() and DistrictStyle.halls:
				# 2026-11-12: the tug station's interior carried here (scripts/district_style.gd trade_hall),
				# on its own layer under the port's drawing (_draw_hall): drawn here, over the port, it hid
				# the business console the port draws
				hall.queue_redraw()
			else:
				# 52 号: the hall kept clear — only a light strip along the ceiling
				cb.draw_line(_p(Vector2(16, 0.8)), _p(Vector2(56, 0.8)), Pal.tint(Pal.AIR, 0.35 if on else 0.1, 1.1), 0.2 * _m)
		"cargo":
			# 102 号: the hall, the racks, the floor and the machines are scripts/cargo_art.gd; here the
			# stock on its rows (46 号, 73 号) and the parts. 2026-11-12: the hall behind it (_draw_hall)
			if DistrictStyle.on() and DistrictStyle.halls:
				hall.queue_redraw()
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
				# 102 号: each row's use and pick time are on the warehouse board (scripts/cargo_art.gd)
				var list: Array = per_row.get(ri, [])
				for n in list.size():
					_pile(cb, str(list[n]), float(stock[list[n]]), at + Vector2(0.0, 0.0), n, list.size())
			var parts: int = Career.data.get("parts", []).size()
			if parts > 0:
				for i in mini(parts, 3):
					cb.draw_rect(Rect2(_p(Vector2(53.4 + i * 1.5, 19.6)), Vector2(1.3, 1.3) * _m), Pal.tint(Pal.AIR, 0.35, 0.9))
				cb.draw_string(font, _p(Vector2(53, 19.2)), w("零件 %d 件", "%d PARTS") % parts, HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.6 * _m), Pal.ink(0.75))
	cb.flush()


# 2026-11-12: the district's hall (scripts/district_style.gd), gathered into a few triangle batches
# (hundreds of plates and lines replayed as single commands cost 0.6 ms a frame); redrawn with the still
# parts only
func _draw_hall() -> void:
	var zone := _zone()
	if zone not in ["trade", "process", "cargo", "power"] or game == null or not DistrictStyle.on() or not DistrictStyle.halls:
		return
	var r := PortStructure.box(zone)
	var m := PortStructure.M()
	var on := Port.stage(zone) >= 1
	var h0 := Time.get_ticks_usec()
	DistrictStyle.back_wall(hall, r, m, on, 26.8)
	var cb = CanvasBatch.new(hall)
	match zone:
		"trade":
			DistrictStyle.trade_hall(cb, r, m, on)
		"process":
			DistrictStyle.process_hall(cb, r, m, on)
		"cargo":
			DistrictStyle.cargo_hall(cb, r, m, on)
		"power":
			DistrictStyle.power_hall(cb, r, m, on)
	cb.flush()
	DistrictStyle.hall_us = float(Time.get_ticks_usec() - h0)


# ------------------------------------------------------------------ the moving parts
func _draw_moving() -> void:
	var zone := _zone()
	if zone == "" or game == null:
		return
	_m = PortStructure.M()
	var ph := float(phase.get(zone, 0.0))
	var k := float(speed.get(zone, 0.0))
	if zone == "ring":
		# 109 号: the carousel and its arms are scripts/hub_view.gd's
		return
	_r = PortStructure.box(zone)
	match zone:
		"power":
			power_art.r = _r
			power_art.m = _m
			var t3 := Time.get_ticks_usec()
			power_art.moving(moving, t, Port.stage("power"), lod())
			power_draw_us = lerpf(power_draw_us, float(Time.get_ticks_usec() - t3), 0.05)
		"tug":
			tug_art.r = _r
			tug_art.m = _m
			var t1 := Time.get_ticks_usec()
			tug_art.moving(moving, t, Port.stage("tug") >= 1, lod())
			tug_draw_us = lerpf(tug_draw_us, float(Time.get_ticks_usec() - t1), 0.05)
		"process":
			pass
		"trade":
			pass
		"cargo":
			# 102 号: the trucks, the crane and the rollers are drawn by scripts/cargo_art.gd
			pass


# ------------------------------------------------------------------ the warehouse (102 号)
func _cargo_ready() -> bool:
	_m = PortStructure.M()
	cargo_art.r = PortStructure.box("cargo")
	cargo_art.m = _m
	return game != null and _zone() == "cargo"


func _draw_cargo_still() -> void:
	if _cargo_ready():
		cargo_art.still(cargo_still, Port.stage("cargo") >= 1, lod())


func _draw_cargo_back() -> void:
	if _cargo_ready():
		var t0 := Time.get_ticks_usec()
		cargo_art.moving_back(cargo_back, t, Port.stage("cargo") >= 1, game)
		cargo_draw_us = lerpf(cargo_draw_us, float(Time.get_ticks_usec() - t0), 0.05)


func _draw_cargo_front() -> void:
	if _cargo_ready():
		var t0 := Time.get_ticks_usec()
		cargo_art.front(cargo_front, t, Port.stage("cargo") >= 1, lod(), game)
		cargo_front_us = lerpf(cargo_front_us, float(Time.get_ticks_usec() - t0), 0.05)


func _draw_cargo_glow() -> void:
	if _cargo_ready():
		cargo_art.glow(cargo_glow, _glow_tex, t, game)


func _draw_cargo_plates() -> void:
	if _cargo_ready():
		cargo_art.plates(cargo_plates, t, Port.stage("cargo") >= 1, game)


# ------------------------------------------------------------------ the processing district (101 号)
func _proc_ready() -> bool:
	_m = PortStructure.M()
	proc_art.r = PortStructure.box("process")
	proc_art.m = _m
	return game != null and _zone() == "process"


func _draw_proc_still() -> void:
	if _proc_ready():
		proc_art.still(proc_still, Port.stage("process") >= 1, lod())


func _draw_proc_back() -> void:
	if _proc_ready():
		var t0 := Time.get_ticks_usec()
		proc_art.moving_back(proc_back, t, Port.stage("process") >= 1, lod(), game)
		proc_draw_us = lerpf(proc_draw_us, float(Time.get_ticks_usec() - t0), 0.05)


func _draw_proc_plates() -> void:
	if _proc_ready():
		proc_art.plates(proc_plates, t, Port.stage("process") >= 1, game)


func _draw_proc_front() -> void:
	if _proc_ready():
		var t0 := Time.get_ticks_usec()
		proc_art.front(proc_front, t, Port.stage("process") >= 1, lod(), game)
		proc_front_us = lerpf(proc_front_us, float(Time.get_ticks_usec() - t0), 0.05)


func _draw_proc_glow() -> void:
	if _proc_ready():
		proc_art.glow(proc_glow, _glow_tex, t, game)


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


func _draw_power_words() -> void:
	power_art.r = PortStructure.box("power")
	power_art.m = PortStructure.M()
	power_art.words(power_words, t, Port.stage("power"), lod())


# 103 号: the business console's card (its use, its figures now, how to open it)
func _console_item(zone: String) -> Dictionary:
	var at := PortStructure.console_spot(zone)
	var m := PortStructure.M()
	var s: Dictionary = preload("res://scripts/console_art.gd").summary(zone, game)
	return {"rect": Rect2(at + Vector2(-1.5, -1.8) * m, Vector2(3.0, 4.0) * m), "title": Txt.t("pt_console_business") + " · " + Port.name_of(zone),
		"use": str(s.use), "now": str(s.now), "can": str(s.can), "lamp": str(s.lamp)}


# 105 号: the work desks' cards — in the processing district the furnace desk, the sorting desk and
# the assay bench; in the berth the terminal on the tower and the parts rack
func _desk_items(zone: String) -> Array:
	var out: Array = []
	if game == null:
		return out
	var CA = preload("res://scripts/console_art.gd")
	var m := PortStructure.M()
	var add := func(at: Vector2, kind: String, title: String, use: String, now: String, can: String, lamp: String) -> void:
		var e: Rect2 = CA.extent(kind, minf(3.0, CA.foot_at(at)))
		out.append({"rect": Rect2(at + e.position * m, e.size * m), "title": title, "use": use, "now": now, "can": can, "lamp": lamp})
	var use_key := Keys.label("use")
	if zone == "process":
		var h = game.get("industrial_heat")
		if h != null and is_instance_valid(h):
			var b: Dictionary = h.heat()
			add.call(h.site(), "furnace", w("炉体操作台", "FURNACE DESK"), w("电弧炉的操作台：投炉、熔炼、出钢，看功率和电价。挡板后的观察窗随炉火发亮。", "The arc furnace's desk: charge, melt, tap; the power and its price. The viewing port glows with the fire."),
				Ops.batch_state(b), w("飞到台前按 %s 打开炉体操作。", "At the desk press %s.") % use_key, "work" if str(b.get("state", "")) == "processing" else "ok")
		var so = game.get("industrial_sort")
		if ProcessLine.LEGACY_DESKS and so != null and is_instance_valid(so):
			var b2: Dictionary = so.heat()
			add.call(so.site(), "sort", w("分选台", "SORTING DESK"), w("分选线的操作台：把混合废料分成铁、有色和弃料。急停拉绳沿着线拉过去。", "The sorting line's desk: mixed scrap into iron, non-ferrous and reject. The stop cord runs along the line."),
				Ops.batch_state(b2), w("飞到台前按 %s 打开分选操作。", "At the desk press %s.") % use_key, "work" if str(b2.get("state", "")) == "processing" else "ok")
		var asy = game.get("industrial_assay")
		if ProcessLine.LEGACY_DESKS and asy != null and is_instance_valid(asy):
			add.call(asy.site(), "assay", w("化验位", "ASSAY BENCH"), w("光谱仪读出一批料的铁和杂质含量，转盘上是样品杯。化验过的料卖价更准。", "The spectrometer reads a lot's iron and impurity; the carousel holds the sample cups. An assayed lot sells at its true worth."),
				(w("化验中", "READING") if asy.running() else w("有 %d 批可化验", "%d LOTS TO ASSAY") % asy.candidates().size()), w("飞到台前按 %s 打开化验。", "At the bench press %s.") % use_key, "work" if asy.running() else "ok")
	elif zone == "":
		var c = game.get("consoles")
		if c != null and is_instance_valid(c):
			add.call(Consoles.centre(0) + Vector2(0.55, 0.0) * m, "wall", w("船坞终端", "BERTH TERMINAL"), w("船坞的电脑：接合同、买装备、管船坞和成长建设。和随时按 %s 打开的是同一台。", "The berth's computer: contracts, gear, the berth and its growth. The same one %s opens anywhere.") % Keys.label("terminal"),
				Pal.money(float(Career.data.get("money", 0.0))) if not Career.data.is_empty() else "", w("飞到它前面按 %s 打开。", "In front of it press %s.") % use_key, "ok")
			if Consoles.rack_on() and game.career():
				var n: int = Career.data.get("parts", []).size()
				if StoreBook.live():
					add.call(Consoles.kiosk_at(), "store", w("仓库终端", "STORES TERMINAL"), w("主仓库在货运区，这台小终端用线缆连过去。拆回来的东西都在公司仓库里：在这里可以卖给回收站，或者留着。", "The main stores are in the cargo district; this little terminal is wired to them. Everything off the ships is in the company stores: sell it to the recycling station here, or keep it."),
						w("已用 %d/%d 格", "%d/%d CELLS") % [StoreBook.used(), StoreBook.cap()], w("飞到终端前按 %s 打开仓库。之后在哪都能按 F3。", "At the terminal press %s. Then F3 anywhere.") % use_key, "ok")
				else:
					add.call(Consoles.rack_centre() + Vector2(0.2, 0.0) * m, "rack", w("零件架", "PARTS RACK"), w("拆下来留着的零件放在这里，一格一件。货运区修好后零件改放仓库货架。", "The parts kept from the ships, one to a cubby. Once the cargo district is mended they live on its racks."),
						w("%d 件" % n, "%d PARTS" % n), w("飞到架前按 %s 打开零件架。", "At the rack press %s.") % use_key, "ok" if n > 0 else "off")
	return out


# 100 号: the same for the power district
func power_near() -> float:
	if game == null or game.get("drone") == null:
		return 0.0
	var p: Vector2 = game.drone.global_position
	if PortStructure.box("power").has_point(p):
		return 1.0
	return 0.5 if PortStructure.box("power").grow(30.0 * PortStructure.M()).has_point(p) else 0.0

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
	# 102 号: two goods on a row: their names stacked over the row's left end, not run into each other
	var lx := float(s[0]) + 0.3
	cb.draw_string(font, _p(Vector2(lx, y_shelf - 1.75 - n * 0.6)), "%s · %.2f t" % [Ops.item_name(k), have], HORIZONTAL_ALIGNMENT_LEFT, 9.4 * _m, int(0.5 * _m), Pal.ink(0.85))


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
