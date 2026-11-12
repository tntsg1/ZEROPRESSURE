class_name Ax40Author
# Authoring script for AX-40 "Backfire", a 40 m antimatter storage ship (design/新船点子_10艘_详细版_
# 20261111.md §4; user 2026-11-11 picked it first of the ten). Not part of the game:
# tools/ship_export.gd runs it and writes ships/ax40.json. Metres, x bow (0) to the stern (40), y down.
#
# Small and dense. Three compartments: B the bridge (the pilot's and the trap physicist's consoles,
# the crew's bunk and life support under the deck), T the trap hall (the storage trap in the middle,
# a sphere inside its ring magnets and a thick shield, hung between two cradle struts from the roof
# and the floor; round it the magnet supply, the cryocooler for the coils, the ion pumps, the
# positron injector on its stand, the trap's control rack), E the engine room (the battery and the
# main switchboard, the ion engine and its power processor, the xenon tank).
# What it asks of you (scripts/antimatter.gd): the trap's confinement runs on the main bus only —
# battery, main switch K-M, the switchboard, cable A1, the magnet supply MPS, cable A2, the trap.
# Lose any of it and the trap annihilates at once: no backup battery, no count. The portable
# confinement supply (lent with the ship, scripts/gear.gd "confine") goes on the trap first; the
# trap reads "dual supply" and only then may the bus go. The trap is 9 t: unbolted from its two
# struts and craned whole into the antimatter cradle (Dock zone "anti").

const K = preload("res://tools/authoring/kit.gd")
const T := 0.45
const OUT := [Vector2(0, -2.5), Vector2(3, -4.5), Vector2(11, -4.5), Vector2(12, -7), Vector2(28, -7), Vector2(29, -4.5), Vector2(37, -4.5), Vector2(40, -3),
	Vector2(40, 3), Vector2(37, 4.5), Vector2(29, 4.5), Vector2(28, 7), Vector2(12, 7), Vector2(11, 4.5), Vector2(3, 4.5), Vector2(0, 2.5)]
const BH := [11.0, 29.0]
const TC := Vector2(20.0, 0.0)     # the trap's centre
const TR := 2.35                   # its module's half-size (an octagon)
const FLOORK := ["hull", "deck", "beam", "strut", "fixture"]

static var w
static var by_tag := {}
static var n_auto := 0


static func build(world) -> void:
	K.begin(world, "AX40")
	w = world
	by_tag = K.by_tag
	n_auto = 0
	_hull()
	_inner()
	_bridge()
	_trap()
	_hall()
	_engine()
	_lines()
	_controls()
	_rooms()
	K.clamp(1, 15.5, 7.0, 6.8)
	K.clamp(2, 24.5, 7.0, 6.8)
	K.clamp(3, 33.0, 4.5, 4.3)


static func rooms_only(world) -> void:
	K.begin(world, "AX40")
	w = world
	_rooms()


static func _auto(p: String) -> String:
	n_auto += 1
	return "%s%d" % [p, n_auto]


static func E(tag: String, art: String, x0: float, y0: float, x1: float, y1: float, room: String, o: Dictionary):
	var opts := {"fragile": 0.4, "room": room}
	opts.merge(o, true)
	return K.equip(tag if tag != "" else _auto(art.left(4).to_upper() + "-"), art, K.rect(x0, y0, x1, y1), opts)


# a row along a floor (up -1) or under a ceiling (up +1), keeping clear of the spans in keep
static func _row(room: String, floor_y: float, up: float, x0: float, x1: float, items: Array, keep: Array = []) -> Array:
	var out: Array = []
	var x := x0
	for it in items:
		if it is float or it is int:
			x += float(it)
			continue
		var wd: float = it[2]
		var h: float = it[3]
		for kp in keep:
			if x < float(kp[1]) + 0.2 and x + wd > float(kp[0]) - 0.2:
				x = float(kp[1]) + 0.25
		if x + wd > x1 + 0.001:
			push_warning("AX40 row %s: %s does not fit (%.1f + %.1f > %.1f)" % [room, it[0], x, wd, x1])
			continue
		var ya: float = floor_y + up * 0.05
		var yb: float = floor_y + up * (0.05 + h)
		var p = E(it[0], it[1], x, minf(ya, yb), x + wd, maxf(ya, yb), room, it[4])
		for bx in [x + minf(0.3, wd * 0.25), x + wd - minf(0.3, wd * 0.25)]:
			K.bolt(p, K.at(bx, floor_y - up * 0.15, FLOORK), bx, floor_y)
		out.append(p)
		x += wd + 0.3
	return out


static func _lamp(tag: String, x: float, ceil_y: float, room: String) -> void:
	K.lamp(tag, x, ceil_y, room, K.at(x, ceil_y - 0.15, FLOORK))


# ---------------------------------------------------------------- the hull

static func _hull() -> void:
	var glass := {"cls": "equip", "dest": "equip", "art": "glass", "mass": 0.12, "value": 2400.0, "fragile": 0.6, "density": 0.8, "cut_speed": 260.0, "name_key": "p_nose_glass"}
	# edges: 0 bow upper slope, 1 bridge roof, 2 fore shoulder, 3 hall roof, 4 aft shoulder, 5 engine roof,
	# 6 stern upper slope, 7 stern, 8 stern lower slope, 9 engine floor, 10 aft keel shoulder, 11 hall floor,
	# 12 fore keel shoulder, 13 bridge floor, 14 bow lower slope, 15 nose
	K.ring(OUT, T, {1: [0.3, 0.6], 3: [0.18, 0.36, 0.5, 0.64, 0.82], 5: [0.4], 7: [0.5], 9: [0.5], 11: [0.15, 0.3, 0.42, 0.58, 0.7, 0.85], 13: [0.35, 0.7], 15: [0.25, 0.75]}, {
		"15:1": glass.merged({"tag": "WIN-B"}),
		"14:0": {"kind": "hatch", "door": true, "tag": "HT-B", "open_dir": Vector2(-1.2, -0.6) * Geom.M, "cut_speed": 200.0},
		"7:0": {"kind": "hatch", "door": true, "tag": "HT-E", "open_dir": Vector2(0, -1.4) * Geom.M, "cut_speed": 200.0},
	}, {"density": 1.6, "barrier": true, "cut_speed": 210.0, "name_key": "p_hull"}, "HA")
	for j in w.joints_of(by_tag["WIN-B"]):
		j.type = "bolt"


static func _inner() -> void:
	var B := {"density": 1.5, "barrier": true, "cut_speed": 200.0, "name_key": "p_bulkhead"}
	for i in 2:
		var x: float = BH[i]
		var u = K.plate("BH%d-U" % i, K.R(x - 0.22, -4.05, x + 0.22, 1.0), B, "hull")
		var d = K.plate("D-%d" % i, K.R(x - 0.22, 1.0, x + 0.22, 3.4), {"density": 1.3, "barrier": true, "cut_speed": 190.0, "door": true, "open_dir": Vector2(0, -2.2) * Geom.M}, "door")
		var l = K.plate("BH%d-L" % i, K.R(x - 0.22, 3.4, x + 0.22, 4.05), B, "hull")
		K.bolt(u, K.at(x, -4.25, ["hull"]), x, -4.05, "weld")
		K.bolt(l, K.at(x, 4.25, ["hull"]), x, 4.05, "weld")
		K.bolt(u, d, x, 1.0, "weld")
		K.bolt(l, d, x, 3.4, "weld")
	var D := {"density": 0.9, "barrier": false, "cut_speed": 230.0, "name_key": "p_deck"}
	var db = K.plate("DK-B", K.R(3.2, 0.0, 10.78, 0.25), D, "deck")
	K.bolt(db, K.at(10.9, 0.12, ["hull"]), 10.78, 0.12, "weld")
	var de = K.plate("DK-E", K.R(29.22, 0.0, 37.6, 0.25), D, "deck")
	K.bolt(de, K.at(29.1, 0.12, ["hull"]), 29.22, 0.12, "weld")
	# each deck's free end stands on a stanchion down to the floor (a cantilever, once the bulkhead
	# was cut, came away with its consoles and tore their cables)
	var S := {"density": 1.4, "barrier": false, "cut_speed": 200.0, "name_key": "p_ax_cradle"}
	var sb = K.plate("ST-B", K.R(3.25, 0.25, 3.5, 4.05), S, "strut")
	K.bolt(sb, db, 3.37, 0.25, "weld")
	K.bolt(sb, K.at(3.37, 4.25, ["hull"]), 3.37, 4.05, "weld")
	var se = K.plate("ST-E", K.R(37.2, 0.25, 37.45, 4.05), S, "strut")
	K.bolt(se, de, 37.32, 0.25, "weld")
	K.bolt(se, K.at(37.0, 4.25, ["hull"]), 37.32, 4.05, "weld")


# ---------------------------------------------------------------- B, the bridge

static func _bridge() -> void:
	K.seat("SEAT-P", Rect2(4.0, -1.15, 0.8, 1.1), {"mass": 0.08, "value": 2400.0, "room": "B", "name_key": "p_seat_pilot"})
	for x in [4.25, 4.55]:
		K.bolt(by_tag["SEAT-P"], K.at(x, 0.12, FLOORK), x, 0.0)
	_row("B", 0.0, -1.0, 5.1, 10.6, [["CON-P", "console", 1.3, 1.2, {"mass": 0.2, "value": 12000.0, "name_key": "p_ax_helm"}],
		["CON-T", "console", 1.3, 1.25, {"mass": 0.2, "value": 16000.0, "name_key": "p_ax_trap_console"}],
		["NAV", "nav_rack", 0.9, 3.2, {"mass": 0.3, "value": 22000.0, "fragile": 0.5, "name_key": "p_nav_rack"}],
		["LOG-A", "blackbox", 0.6, 0.5, {"mass": 0.06, "value": 9000.0, "name_key": "p_ax_log"}]])
	_row("B", -4.05, 1.0, 3.6, 10.6, [["", "screen", 1.4, 0.8, {"mass": 0.04, "value": 2600.0, "name_key": "p_ark_screen"}], ["", "overhead", 1.3, 0.45, {"mass": 0.04, "value": 1800.0, "name_key": "p_ark_overhead"}],
		["COMM", "aux", 1.0, 0.7, {"mass": 0.06, "value": 6000.0, "name_key": "p_comms"}], ["", "junction", 0.6, 0.4, {"mass": 0.04, "value": 600.0, "name_key": "p_junction"}]])
	_lamp("LAMP-B", 5.4, -4.05, "B")
	_row("B", 4.05, -1.0, 5.6, 10.6, [["", "bunk", 2.0, 1.4, {"mass": 0.18, "value": 1500.0, "name_key": "p_crew_bunk"}],
		["ENV-B", "env", 1.3, 1.6, {"mass": 0.4, "value": 9000.0, "name_key": "p_env_control"}], ["", "o2cab", 0.7, 1.0, {"mass": 0.12, "value": 2200.0, "name_key": "p_o2cab"}]])
	_row("B", 0.25, 1.0, 4.4, 10.6, [["", "cabinet", 1.2, 0.6, {"mass": 0.08, "value": 1200.0, "name_key": "p_svc_cabinet"}], ["", "locker", 0.8, 0.9, {"mass": 0.08, "value": 900.0, "name_key": "p_locker"}],
		["", "junction", 0.6, 0.4, {"mass": 0.04, "value": 600.0, "name_key": "p_junction"}], ["DOSE-B", "aux", 0.7, 0.6, {"mass": 0.05, "value": 4000.0, "name_key": "p_ax40_gamma"}]])
	K.lamp("LAMP-B2", 7.0, 0.25, "B", by_tag["DK-B"])


# ---------------------------------------------------------------- T, the trap and its cradle

static func _octagon(c: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 8:
		out.append((c + Vector2.from_angle(TAU * (i + 0.5) / 8.0) * r / cos(PI / 8.0)) * Geom.M)
	return out


static func _trap() -> void:
	# the module: the sphere in its ring magnets and shield, one 9 t piece
	var poly := _octagon(TC, TR)
	var tr = K.equip("TRAP", "module", K.mbox(poly), {"mass": 9.0, "value": 80000.0, "fragile": 0.12, "room": "T", "mandatory": true, "hazard": "antimatter",
		"dest": "anti", "cut_speed": 60.0, "density": 6.0, "name_key": "p_ax_trap"}, poly)
	# the cradle struts: from the roof down onto the module, from the floor up under it
	var su = K.plate("SUP-U", K.R(TC.x - 0.55, -6.55, TC.x + 0.55, TC.y - TR + 0.02), {"density": 2.0, "barrier": false, "cut_speed": 170.0, "name_key": "p_ax_cradle"}, "strut")
	var sd = K.plate("SUP-D", K.R(TC.x - 0.55, TC.y + TR - 0.02, TC.x + 0.55, 6.55), {"density": 2.0, "barrier": false, "cut_speed": 170.0, "name_key": "p_ax_cradle"}, "strut")
	K.bolt(su, K.at(TC.x, -6.75, ["hull"]), TC.x - 0.3, -6.55, "weld")
	K.bolt(su, K.at(TC.x, -6.75, ["hull"]), TC.x + 0.3, -6.55, "weld")
	K.bolt(sd, K.at(TC.x, 6.75, ["hull"]), TC.x - 0.3, 6.55, "weld")
	K.bolt(sd, K.at(TC.x, 6.75, ["hull"]), TC.x + 0.3, 6.55, "weld")
	K.bolt(tr, su, TC.x - 0.35, TC.y - TR, "bolt", "TB-1")
	K.bolt(tr, su, TC.x + 0.35, TC.y - TR, "bolt", "TB-2")
	K.bolt(tr, sd, TC.x - 0.35, TC.y + TR, "bolt", "TB-3")
	K.bolt(tr, sd, TC.x + 0.35, TC.y + TR, "bolt", "TB-4")


static func _hall() -> void:
	var keep := [[TC.x - TR - 0.1, TC.x + TR + 0.1], [25.0, 25.7]]
	# the floor: the magnet supply (the trap's), the cryocooler, the ion pumps, the trap's rack
	_row("T", 6.55, -1.0, 12.5, 27.5, [["MPS", "swb", 1.5, 2.6, {"mass": 0.9, "value": 34000.0, "fragile": 0.35, "name_key": "p_ax_magnet_psu"}],
		["CRY", "freezer", 1.4, 1.9, {"mass": 0.6, "value": 18000.0, "name_key": "p_ax_cryocooler"}],
		["VAC-P", "pump", 1.0, 1.1, {"mass": 0.25, "value": 9000.0, "name_key": "p_ax_ion_pump"}],
		["TRAP-CTL", "nav_rack", 1.1, 3.0, {"mass": 0.35, "value": 28000.0, "fragile": 0.5, "name_key": "p_ax_trap_rack"}],
		["", "suit", 0.6, 1.8, {"mass": 0.1, "value": 5000.0, "name_key": "p_suit"}],
		["HE-B", "gastank", 0.8, 2.0, {"mass": 0.25, "value": 3000.0, "hazard": "gas_tank", "name_key": "p_ax_he_buffer"}]], keep)
	# under the roof: the coils' cold heads, the gamma counters, the cable trays, the lamps
	_row("T", -6.55, 1.0, 12.8, 27.4, [["CH-1", "pump", 1.1, 0.9, {"mass": 0.15, "value": 11000.0, "name_key": "p_ax_cold_head"}],
		["GM-1", "aux", 0.7, 0.6, {"mass": 0.05, "value": 4000.0, "name_key": "p_ax40_gamma"}], ["", "junction", 0.6, 0.4, {"mass": 0.04, "value": 600.0, "name_key": "p_junction"}],
		["CH-2", "pump", 1.1, 0.9, {"mass": 0.15, "value": 11000.0, "name_key": "p_ax_cold_head"}],
		["GM-2", "aux", 0.7, 0.6, {"mass": 0.05, "value": 4000.0, "name_key": "p_ax40_gamma"}]], [[TC.x - 0.8, TC.x + 0.8]])
	_lamp("LAMP-T1", 22.4, -6.55, "T")
	_lamp("LAMP-T2", 26.2, -6.55, "T")
	# the positron injector: a beamline from the hall's aft end into the trap, on its own stand
	var stand = K.plate("SUP-I", K.R(25.05, 0.45, 25.65, 6.55), {"density": 1.6, "barrier": false, "cut_speed": 180.0, "name_key": "p_ax_cradle"}, "strut")
	K.bolt(stand, K.at(25.35, 6.75, ["hull"]), 25.35, 6.55, "weld")
	var inj = E("INJ", "insp", TC.x + TR + 0.25, -0.45, 27.9, 0.45, "T", {"mass": 0.5, "value": 26000.0, "fragile": 0.5, "name_key": "p_ax_injector"})
	K.bolt(inj, stand, 25.1, 0.45)
	K.bolt(inj, stand, 25.6, 0.45)
	# the trap's readout panel on the fore bulkhead, at eye height
	var pnl = E("CONF-P", "panel", 11.3, -3.2, 12.4, -1.5, "T", {"mass": 0.06, "value": 7000.0, "name_key": "p_ax_confine_panel"})
	K.bolt(pnl, by_tag["BH0-U"], 11.22, -2.9)
	K.bolt(pnl, by_tag["BH0-U"], 11.22, -1.8)
	# two galleries off the bulkheads, each crowded with the trap's own kit
	var G := {"density": 0.9, "barrier": false, "cut_speed": 230.0, "name_key": "p_deck"}
	var gl = K.plate("DK-T1", K.R(11.22, -0.6, 15.9, -0.35), G, "deck")
	K.bolt(gl, by_tag["BH0-U"], 11.22, -0.47, "weld")
	_row("T", -0.6, -1.0, 12.5, 15.8, [["HV-I", "cabinet", 1.1, 1.5, {"mass": 0.25, "value": 12000.0, "name_key": "p_ax_hv_supply"}],
		["RGA", "aux", 0.8, 0.7, {"mass": 0.06, "value": 15000.0, "fragile": 0.5, "name_key": "p_ax_rga"}],
		["", "junction", 0.6, 0.4, {"mass": 0.04, "value": 600.0, "name_key": "p_junction"}]])
	_row("T", -0.35, 1.0, 12.6, 15.8, [["TC-MON", "aux", 0.9, 0.5, {"mass": 0.04, "value": 5000.0, "name_key": "p_ax_temp_monitor"}],
		["", "junction", 0.6, 0.4, {"mass": 0.04, "value": 600.0, "name_key": "p_junction"}]])
	var gr = K.plate("DK-T2", K.R(22.9, -2.2, 28.78, -1.95), G, "deck")
	K.bolt(gr, by_tag["BH1-U"], 28.78, -2.07, "weld")
	_row("T", -2.2, -1.0, 23.0, 28.6, [["QD", "cabinet", 1.3, 1.7, {"mass": 0.2, "value": 5000.0, "name_key": "p_ax_quench_dump"}],
		["BGC", "panel", 1.0, 1.1, {"mass": 0.08, "value": 8000.0, "name_key": "p_ax_buffer_gas"}],
		["MOD-C", "aux", 0.9, 1.3, {"mass": 0.08, "value": 11000.0, "name_key": "p_ax_moderator"}],
		["", "junction", 0.6, 0.4, {"mass": 0.04, "value": 600.0, "name_key": "p_junction"}]])
	_row("T", -1.95, 1.0, 23.4, 28.6, [["GM-3", "aux", 0.7, 0.6, {"mass": 0.05, "value": 4000.0, "name_key": "p_ax40_gamma"}],
		["", "junction", 0.6, 0.4, {"mass": 0.04, "value": 600.0, "name_key": "p_junction"}]])


# ---------------------------------------------------------------- E, the engine room

static func _engine() -> void:
	_row("E", 0.0, -1.0, 29.6, 37.4, [["PPU", "cabinet", 1.4, 2.2, {"mass": 0.5, "value": 16000.0, "name_key": "p_ax_ppu"}],
		["XE-T", "gastank", 1.0, 2.6, {"mass": 0.6, "value": 7000.0, "hazard": "gas_tank", "name_key": "p_ax_xenon_tank"}],
		["ENG", "pump", 3.0, 2.4, {"mass": 1.6, "value": 42000.0, "name_key": "p_ax_ion_engine"}]])
	_row("E", -4.05, 1.0, 32.5, 36.3, [["", "junction", 0.6, 0.4, {"mass": 0.04, "value": 600.0, "name_key": "p_junction"}], ["ENV-E", "env", 1.2, 0.9, {"mass": 0.2, "value": 4000.0, "name_key": "p_env_control"}],
		["", "overhead", 1.2, 0.45, {"mass": 0.04, "value": 1500.0, "name_key": "p_ark_overhead"}]])
	_lamp("LAMP-E", 36.4, -4.05, "E")
	_row("E", 4.05, -1.0, 29.6, 37.0, [["BAT-E", "battery", 1.7, 1.6, {"mass": 1.1, "value": 9000.0, "hazard": "battery", "name_key": "p_battery"}],
		["SWB-E", "swb", 1.2, 2.5, {"mass": 0.4, "value": 6000.0, "name_key": "p_swb"}],
		["CWP", "pump", 1.0, 1.0, {"mass": 0.2, "value": 3500.0, "name_key": "p_coolant_pump"}],
		["", "locker", 0.8, 0.9, {"mass": 0.08, "value": 900.0, "name_key": "p_locker"}]])
	K.lamp("LAMP-E2", 33.0, 0.25, "E", by_tag["DK-E"])


# ---------------------------------------------------------------- lines

static func _cen(t: String) -> Vector2:
	return Geom.centroid(by_tag[t].poly) / Geom.M


static func _c(id: String, a: String, b: String, via: Array = []) -> void:
	K.line(id, "cable", "power", a, _cen(a), b, _cen(b), via)


static func _p(id: String, net: String, a: String, b: String, via: Array = []) -> void:
	K.line(id, "pipe", net, a, _cen(a), b, _cen(b), via)


static func _lines() -> void:
	_c("p1", "BAT-E", "SWB-E")
	# the confinement chain: the bus to the magnet supply, the supply to the trap
	_c("A1", "SWB-E", "MPS", [Vector2(30.6, 3.0), Vector2(29.6, 5.6), Vector2(12.4, 5.6)])
	_c("A2", "MPS", "TRAP", [Vector2(13.25, 3.4), Vector2(17.0, 3.4), Vector2(17.0, 0.0)])
	_c("p2", "SWB-E", "CRY", [Vector2(30.6, 3.2), Vector2(29.6, 5.8), Vector2(14.3, 5.8)])
	_c("p3", "SWB-E", "VAC-P", [Vector2(30.6, 3.4), Vector2(29.6, 6.0), Vector2(16.0, 6.0)])
	_c("p4", "SWB-E", "TRAP-CTL", [Vector2(30.6, 3.6), Vector2(29.6, 6.2), Vector2(23.4, 6.2)])
	_c("p5", "SWB-E", "PPU")
	_c("p6", "PPU", "ENG")
	_c("p7", "SWB-E", "LAMP-E")
	_c("p8", "SWB-E", "LAMP-E2")
	_c("p9", "SWB-E", "LAMP-T2", [Vector2(30.6, -0.6), Vector2(29.6, -5.8), Vector2(26.2, -5.8)])
	_c("p10", "SWB-E", "LAMP-T1", [Vector2(30.6, -0.8), Vector2(29.6, -6.0), Vector2(22.4, -6.0)])
	_c("p11", "SWB-E", "ENV-B", [Vector2(30.6, 3.8), Vector2(29.6, 6.35), Vector2(10.4, 6.35), Vector2(10.4, 3.2)])
	_c("p12", "SWB-E", "NAV", [Vector2(30.6, -1.0), Vector2(29.6, -6.2), Vector2(11.4, -6.2), Vector2(9.9, -3.6)])
	_c("p13", "NAV", "CON-P")
	_c("p14", "NAV", "CON-T")
	_c("p15", "NAV", "LAMP-B")
	_c("p16", "NAV", "COMM")
	_c("p17", "SWB-E", "ENV-E")
	_c("p18", "CRY", "CH-1", [Vector2(14.6, 3.2), Vector2(12.2, 3.2), Vector2(12.2, -5.3), Vector2(13.35, -5.3)])
	_c("p19", "CRY", "CH-2", [Vector2(15.2, 3.0), Vector2(16.5, 3.0), Vector2(16.5, -5.3)])
	_c("p21", "TRAP-CTL", "CONF-P", [Vector2(23.4, 3.4), Vector2(12.0, 3.4), Vector2(11.9, -1.4)])
	_c("p23", "NAV", "LAMP-B2")
	_c("p24", "TRAP-CTL", "HV-I", [Vector2(23.4, 3.8), Vector2(16.3, 3.8), Vector2(16.3, -1.3)])
	_c("p25", "TRAP-CTL", "BGC", [Vector2(22.9, 4.0), Vector2(22.9, -2.8), Vector2(24.8, -2.8)])
	_c("p26", "TRAP-CTL", "MOD-C", [Vector2(22.75, 4.2), Vector2(22.75, -3.1), Vector2(26.2, -3.1)])
	_c("p27", "HV-I", "INJ", [Vector2(16.1, -1.3), Vector2(16.1, 3.0), Vector2(22.45, 3.0), Vector2(22.45, 0.2)])
	# the coils' helium, the engine's xenon, the cooling water
	_p("h1", "he", "HE-B", "CRY")
	_p("x1", "xe", "XE-T", "ENG")
	_p("w1", "cw", "CWP", "CRY", [Vector2(34.0, 3.4), Vector2(29.6, 5.4), Vector2(14.0, 5.4)])
	_p("w2", "cw", "CWP", "PPU", [Vector2(34.0, 2.6), Vector2(30.3, 2.6)])


# ---------------------------------------------------------------- controls

static func _controls() -> void:
	var sw = by_tag["SWB-E"]
	var sc := _cen("SWB-E")
	K.ctrl("K-M", "switch", sw, sc + Vector2(-0.3, -0.7), {"target": "K-M", "state": true, "hidden_room": "E"})
	K.ctrl("E-1", "test", sw, sc + Vector2(0.3, -0.7), {"medium": "volt", "target": "bus", "hidden_room": "E"})
	# the trap's own reading, at the readout panel
	K.ctrl("CONF", "probe", by_tag["CONF-P"], _cen("CONF-P") + Vector2(0.0, 0.3), {"medium": "confine", "target": "TRAP", "hidden_room": "T"})
	K.ctrl("G-XE", "port", by_tag["XE-T"], _cen("XE-T") + Vector2(0, -0.9), {"medium": "gas", "target": "XE", "hidden_room": "E"})
	K.ctrl("G-HE", "port", by_tag["HE-B"], _cen("HE-B") + Vector2(0, -0.8), {"medium": "gas", "target": "HEB", "hidden_room": "T"})
	K.ctrl("PW", "port", by_tag["CWP"], _cen("CWP") + Vector2(0, -0.3), {"medium": "water", "target": "cw", "hidden_room": "E"})
	K.ctrl("G-B", "port", K.at(0.2, -1.6, ["hull"]), Vector2(-0.2, -1.6), {"medium": "gas", "target": "B"})
	K.ctrl("G-T", "port", K.at(17.0, 7.0, ["hull"]), Vector2(17.0, 7.15), {"medium": "gas", "target": "T"})
	K.ctrl("G-E", "port", K.at(39.8, 1.8, ["hull"]), Vector2(40.2, 1.8), {"medium": "gas", "target": "E"})
	for t in ["HT-B", "HT-E"]:
		K.door(t, "")
	K.door("D-0", "B")
	K.door("D-1", "E")


static func _rooms() -> void:
	var fi := K.inner(OUT, T)
	w.add_room("B", K.mp([fi[15], fi[0], fi[1], Vector2(BH[0] - 0.22, fi[1].y), Vector2(BH[0] - 0.22, fi[14].y), fi[14]]))
	w.add_room("T", K.mp([Vector2(BH[0] + 0.22, fi[2].y + (BH[0] + 0.22 - fi[2].x) * (fi[3].y - fi[2].y) / (fi[3].x - fi[2].x)), fi[3], fi[4],
		Vector2(BH[1] - 0.22, fi[5].y + (BH[1] - 0.22 - fi[5].x) * (fi[4].y - fi[5].y) / (fi[4].x - fi[5].x)),
		Vector2(BH[1] - 0.22, fi[10].y + (BH[1] - 0.22 - fi[10].x) * (fi[11].y - fi[10].y) / (fi[11].x - fi[10].x)), fi[11], fi[12],
		Vector2(BH[0] + 0.22, fi[13].y + (BH[0] + 0.22 - fi[13].x) * (fi[12].y - fi[13].y) / (fi[12].x - fi[13].x))]))
	w.add_room("E", K.mp([Vector2(BH[1] + 0.22, fi[5].y), fi[6], fi[7], fi[8], fi[9], Vector2(BH[1] + 0.22, fi[9].y)]))


static func meta() -> Dictionary:
	return {
		"id": "ax40",
		"name": "AX-40 BACKFIRE",
		"title": ["AX-40「逆火」反物质储存船 · 40 m", "AX-40 BACKFIRE · ANTIMATTER STORAGE SHIP · 40 m"],
		"contract": "AX-40",
		"length": 40.0,
		"value": {"total": 420000.0, "metal": 6000.0},
		"clamps": [[15.5, 7.0], [24.5, 7.0], [33.0, 4.5]],
		"room_names": {"B": "room_axB", "T": "room_axT", "E": "room_axE"},
		"gas": {"rooms": {"B": 101.0, "T": 101.0, "E": 101.0},
			"vessels": {"XE": {"V": 0.3, "kpa": 4200.0, "piece": "XE-T", "burst": 400.0},
				"HEB": {"V": 0.12, "kpa": 1600.0, "piece": "HE-B", "burst": 300.0}},
			"valves": [], "value": 64000.0},
		"antimatter": {"trap": "TRAP", "switch": "K-M", "supply": "MPS", "bus": "SWB-E", "source": "BAT-E", "lines": ["p1", "A1", "A2"], "panel": "CONF-P", "probe": "CONF", "near": 1.5},
		"lend": {"confine": 1},
		"kit_lend": {"crane": 1},
		"power": {
			"bus": "SWB-E",
			"sources": [
				{"piece": "BAT-E", "kind": "battery", "volts": 220.0, "local_volts": 48.0, "cable": "p1", "switch": "K-M", "charge": 0.95, "drain": 0.0},
			],
			"lamps": {"B": "LAMP-B", "T": "LAMP-T1", "E": "LAMP-E"},
		},
		"fluids": {"volumes": {
			"cw": {"fluid": "water", "amount": 0.1, "nets": ["cw"], "piece": "CWP", "port": "PW", "full": 0.15, "leak": 0.08, "leak_min": 0.004, "pump": [0.06, 0.004]},
			"xeline": {"fluid": "n2", "amount": 0.0, "nets": ["xe"]},
			"heline": {"fluid": "n2", "amount": 0.0, "nets": ["he"]},
		}, "joins": [], "value": {"water": 300.0}},
		"ctrls_cfg": {"G-B": {"rate": 14.0}, "G-T": {"rate": 24.0}, "G-E": {"rate": 14.0}, "G-XE": {"rate": 0.6}, "G-HE": {"rate": 0.5}},
		"labels": {"TRAP": "TRAP", "MPS": "MAG PSU", "HV-I": "HV", "RGA": "RGA", "BGC": "BUFFER", "MOD-C": "MOD", "SWB-E": "BUS", "BAT-E": "BAT", "CRY": "CRYO", "TRAP-CTL": "TRAP CTL", "INJ": "e+ INJ", "CONF-P": "CONFINE",
			"ENG": "ION", "PPU": "PPU", "XE-T": "Xe", "HE-B": "He", "NAV": "NAV", "QD": "QUENCH"},
		"hints": {},
		"market": {
			"class": "AX", "name": ["反物质储存船", "ANTIMATTER STORAGE SHIP"], "time": 24.0,
			"rooms": {"B": [0.2, 40.0, 101.0], "T": [0.2, 40.0, 101.0], "E": [0.2, 40.0, 101.0]},
			"charge": {"BAT-E": [0.85, 1.0]},
			"fluids": {},
			"knockable": ["CON-P", "COMM"],
			"drift": [],
			"section_x": 11.0,
			"slots": {"fire_system": {"x": 36.75, "y0": 4.05 - 1.4, "y1": 4.05, "base": ["HA9-0", 4.05], "room": "E", "port": [37.1, 4.05 - 1.33]}},
			"mechanisms": true,
		},
		"procedures": {
			"TRAP": [
				{"do": "hose", "ctrl": "G-B"},
				{"do": "hose", "ctrl": "G-T"},
				{"do": "hose", "ctrl": "G-E"},
				{"do": "wait", "until": {"P": ["B", "<", 5.0]}, "max": 200.0},
				{"do": "wait", "until": {"P": ["T", "<", 5.0]}, "max": 200.0},
				{"do": "wait", "until": {"P": ["E", "<", 5.0]}, "max": 200.0},
				{"do": "operate", "ctrl": "HT-B"},
				{"do": "wait", "until": {"open": ["B"]}, "max": 20.0},
				{"do": "operate", "ctrl": "D-0"},
				{"do": "wait", "until": {"open": ["T"]}, "max": 20.0},
				{"do": "operate", "ctrl": "HT-E"},
				{"do": "wait", "until": {"open": ["E"]}, "max": 20.0},
				{"do": "measure", "ctrl": "CONF"},
				{"do": "deploy", "gear": "confine", "piece": "TRAP"},
				{"do": "wait", "until": {"mod": ["anti", "dual", ">", 0.5]}, "max": 10.0},
				{"do": "operate", "ctrl": "K-M"},
				{"do": "free", "piece": "TRAP"},
				{"do": "deliver", "piece": "TRAP", "zone": "anti"},
			],
		},
	}
