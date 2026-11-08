extends RefCounted
# 128 号 第 6 段 (user 2026-11-07, design/成长版本/G5-G7…/128_seg6_碰撞不一致清单_2026-11-07.md): what is
# drawn solid is solid. Every district's floor where it is drawn (26.8 m, not the shell's line at
# 28: the consoles, machines and forklifts all stand on 26.8), the roof trusses, and the machines,
# frames, rails and guides each district's art draws bright, aligned with the art's own numbers.
# Box-local metres (60 × 28), built into PortStructure's walls (layer 4) with the old MACHINES and
# district_interiors' SOLIDS. Things that move (cranes' trolleys, forklifts, trains, the cryo
# stand, hung baskets) and the mouths pieces fly into are left out on purpose.

const FLOOR := 26.8
const TugW = preload("res://scripts/tug_works.gd")
const PS = preload("res://scripts/power_supply.gd")
const BalePress = preload("res://scripts/bale_press.gd")
const TW = preload("res://scripts/trade_works.gd")


# [Rect2 box-local m] for a district (its floor slab apart: floor_gaps)
static func rects(zone: String) -> Array:
	match zone:
		"power":
			return _power()
		"tug":
			return _tug()
		"cargo":
			return _cargo()
		"trade":
			return _trade()
		"process":
			return _process()
	return []


# the floor slab, 26.8 → 28, with the door's gap (a door in the floor) and the cargo hatch
static func floor_rects(zone: String) -> Array:
	if zone in ["salvage", "ring"] or not PortArt.ANGLE.has(zone):
		return []
	var gaps: Array = []
	var d: Array = PortArt.door_at(zone)
	var n: Vector2 = d[1]
	if n.y < -0.5:
		# the door sits in the floor: its centre in box-local metres
		var dx: float = (d[0] as Vector2).x - (PortArt.district_at(zone).x - PortArt.BOX.x * 0.5)
		gaps.append(Vector2(dx - PortStructure.DOOR * 0.5, dx + PortStructure.DOOR * 0.5))
	if zone == "cargo":
		gaps.append(Vector2(27.5, 32.5))
	gaps.sort_custom(func(a, b): return a.x < b.x)
	var out: Array = []
	var x := 0.0
	for gp in gaps:
		if gp.x > x:
			out.append(Rect2(x, FLOOR, gp.x - x, 28.0 - FLOOR))
		x = maxf(x, gp.y)
	if x < 60.0:
		out.append(Rect2(x, FLOOR, 60.0 - x, 28.0 - FLOOR))
	return out


# ---------------------------------------------------------------- 动力区
static func _power() -> Array:
	var out: Array = []
	# the main control screen and its frame (Jev 2026-11-07: a big screen hung there is a thing)
	out.append(Rect2(29.95, 3.35, 7.1, 10.1))
	# the battery berth on the roof: base plate and its three posts (scripts/power_supply_view.gd)
	out.append(PS.BASE)
	for x in PS.POSTS_X:
		out.append(Rect2(float(x) - 0.12, PS.POST_TOP, 0.24, PS.BASE.position.y - PS.POST_TOP))
	# the radiator arrays out on their booms either side (scripts/port_art.gd _power): panels and headers
	out.append(Rect2(-36.6, 7.8, 33.0, 12.4))
	out.append(Rect2(63.6, 7.8, 33.0, 12.4))
	return out


# ---------------------------------------------------------------- 拖船站
static func _tug() -> Array:
	var out: Array = []
	var g0 := 0.35
	var g1 := 1.6
	# the gantry: its box girder and its two lattice legs down to their bogies
	out.append(Rect2(1.2, g0, 21.6, g1 - g0))
	for lx: float in [TugW.LEGS.x, TugW.LEGS.y]:
		out.append(Rect2(lx - 0.4, g1, 0.8, 25.6 - g1))
		out.append(Rect2(lx - 1.3, 25.6, 2.6, 0.66))
	# the deck's columns to the floor; each berth's services post on the deck
	var y0: float = TugW.DECK_Y
	for cx: float in [23.0, 37.6, 51.4]:
		out.append(Rect2(cx - 0.32, y0 + 0.7, 0.64, FLOOR - y0 - 0.7))
	for i in 2:
		out.append(Rect2(float(TugW.BERTH_X[i]) + 6.6 - 0.3, y0 - 3.4, 0.6, 3.4))
		# the lift shaft's two guides from the deck down to the table
		var lx2 := TugW.lift_x(i)
		for sx in [-1.55, 1.55]:
			out.append(Rect2(lx2 + sx - 0.1, y0 + 0.75, 0.2, 22.6 - y0 - 0.75))
	# the push frame's stand on the floor right of the stern
	var st: Vector2 = TugW.FRAME_STAND
	out.append(Rect2(st.x - 1.3, st.y - 0.5, 2.6, 0.5))
	return out


# a company tug at home on the deck (its hull: scripts/tug_station_art.gd _tug), local to its berth point
const TUG_HULL := [Vector2(-5.6, -0.6), Vector2(5.0, -0.6), Vector2(5.9, -1.5), Vector2(5.9, -3.1), Vector2(4.6, -4.5), Vector2(-3.0, -4.5), Vector2(-5.6, -3.7)]


# ---------------------------------------------------------------- 货运区
static func _cargo() -> Array:
	var out: Array = []
	# the two banks of racking: top tie 8.8 down to the lowest beam (21.26); the bottom bay is where
	# the rack's mouth stands (scripts/cargo_floor.gd), open. Bank A leaves the freight line through
	# it clear (the train runs 12.6–15.7 m: 12.4–16.0 kept open)
	out.append(Rect2(5.87, 8.8, 10.26, 12.4 - 8.8))
	out.append(Rect2(5.87, 16.0, 10.26, 21.26 - 16.0))
	out.append(Rect2(41.87, 8.8, 10.26, 21.26 - 8.8))
	# the roof trusses and the stacker crane's runway under them
	out.append(Rect2(0.0, 0.0, 60.0, 1.3))
	out.append(Rect2(5.4, 1.62, 49.2, 0.63))
	# the warehouse board (Jev 2026-11-07: a hung screen is a thing)
	out.append(Rect2(19.25, 3.25, 21.5, 5.5))
	# the roller line on its stands, the forklifts' chargers
	out.append(Rect2(34.0, 25.75, 18.0, FLOOR - 25.75))
	for cx: float in [23.4, 36.6]:
		out.append(Rect2(cx - 0.4, FLOOR - 1.7, 0.8, 1.7))
	return out


# ---------------------------------------------------------------- 贸易港
static func _trade() -> Array:
	var out: Array = []
	# the quote board (and its bezel)
	out.append(Rect2(17.75, 0.25, 36.5, 6.4))
	# each booth: the sign, the glass and the desk
	for i in 3:
		var x0 := 20.0 + i * 12.0
		out.append(Rect2(x0 - 0.3, 6.9, 9.6, 10.0 - 6.9))
	# the hall floor over the dock, and its three columns down through the dock
	var s: Vector2 = TW.SLAB
	out.append(Rect2(TW.SLAB_X, s.x, 60.0 - TW.SLAB_X, s.y - s.x))
	for cx: float in [22.0, 34.5, 45.0]:
		out.append(Rect2(cx - 0.3, s.y, 0.6, FLOOR - s.y))
	# the dock: the intake frame, the belt on its legs, the weighbridge's display post, the sealer
	var by: float = TW.BELT_Y
	out.append(Rect2(TW.INTAKE_X - 1.4, by - 2.4, 1.4, 2.4 + (FLOOR - by)))
	out.append(Rect2(TW.INTAKE_X, by, TW.BELT_END + 0.9 - TW.INTAKE_X, FLOOR - by))
	out.append(Rect2(TW.WEIGH.y, by - 5.4, 2.4, 1.3))
	out.append(Rect2(TW.WEIGH.y + 0.4, by - 4.1, 0.25, 4.1))
	out.append(Rect2(TW.SEAL_X - 1.2, by - 3.7, 2.4, 0.5))
	for sx in [-1.0, 1.0]:
		out.append(Rect2(TW.SEAL_X + sx - 0.1, by - 3.2, 0.2, 3.2))
	# the dock crane's girder under the slab
	out.append(Rect2(46.0, TW.CRANE_Y - 0.4, 13.0, 0.5))
	# the east wall: the two airlocks' frames, the cart lift's guides
	for lk: Vector2 in TW.LOCKS:
		out.append(Rect2(58.8, lk.x - 0.3, 1.2, lk.y - lk.x + 0.6))
	for gx in [56.9, 58.1]:
		out.append(Rect2(gx - 0.1, TW.LOCKS[0].x, 0.2, s.x - TW.LOCKS[0].x))
	return out


# ---------------------------------------------------------------- 加工区
# Under the gallery only (its walkway 7.4–7.8 m, the glass to 8.9): the corridor over it and the
# gallery itself stay as they were (tests/seg4_sketch.gd flies them)
static func _process() -> Array:
	var out: Array = []
	# the roof truss (0.4–1.3 m), over the corridor's ceiling at 1.9
	out.append(Rect2(0.0, 0.0, 60.0, 1.3))
	# the hall crane's runway girder under the gallery (process_art: 2.42–3.3 in the bay's metres, 7 m lower)
	out.append(Rect2(0.3, 9.42, 36.3, 0.88))
	# the charging basket's stand on its wall brackets over the transformer
	out.append(Rect2(1.4, 14.4, 5.4, 0.26))
	# the arc furnace: its hood, the vessel, the electrode mast (the facility card's rect, up to the hood)
	out.append(Rect2(12.4, 13.5, 7.4, 24.85 - 13.5))
	# the baler's frame: crosshead to the floor between its columns
	out.append(Rect2(BalePress.HEAD.position.x, BalePress.HEAD.position.y, BalePress.HEAD.size.x, FLOOR - BalePress.HEAD.position.y))
	# the furnace deck (process_art _decks: 18.4 in the bay's metres) on its columns to the floor
	out.append(Rect2(9.0, 25.4, 21.4, FLOOR - 25.4))
	# the casting line's roller table over the deck (measured off the art: cast_art.gd)
	out.append(Rect2(19.0, 23.4, 8.5, 25.4 - 23.4))
	# the mould rack's shelf hung off the runway (the blocks on it move)
	out.append(Rect2(21.35, 20.7, 7.25, 0.42))
	# the reheat furnace, the mill stands and their tables, to the floor
	out.append(Rect2(42.8, 16.4, 16.6, FLOOR - 16.4))
	return out
