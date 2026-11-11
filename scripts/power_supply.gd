extends RefCounted
# 128 号 第 5 段 动力 —— 草图 (2026-11-07 用户 grilling b b a a a a; design/…/128_港区从头设计… §七 and the
# 第 5 段 定案). What the power district gains, kept apart from scripts/grid.gd's rules:
#   batteries  — three sizes bought like goods at the power screen's order card (no confirm, a done note);
#                a delivery ship comes in from another system, holds station over the battery berth on
#                the roof (between the radiator fins, clear of the domes and the transformers), lowers the
#                block on its winch into a free slot, it plugs into the bus; spent, the shell is lifted off
#                by the next ship (or a pickup run). "Order another when low" stays.
#   overload   — each generator (Jev B 0.83: the turbine-generator and the fuel-cell set) has an overload
#                switch: +20 % while on, heat rising while the margin is used; full, it trips and stays
#                down until the wrench (tool 4) is held on it for a moment.
#   cryo       — the processing district's separated LH2 / LOX go by tug to the fuel cells, every time on
#                their own: precool, open, fill, frost, vent; the tug flies its legs under strict inertia
#                (accelerate, coast, brake; the plume opposite the acceleration). One route in the sketch.
# Everything is in port metres (from the port's centre, PortArt) or box-local metres (60 × 28).
# Saved in Career.data.power5. ENABLED off: nothing here changes the grid (older tests).

static var ENABLED := true

# 2026-11-07 校准 (Jev B 0.78): a battery's MWh at about ten times the sets' fuel ($60 → ~$600 / MWh).
# At the first shortage (ships 4–5: the power district still broken, 6 MW; the furnace given ~4 of its
# 24 MW, a 1.2 MWh heat dragging from ~3 to ~18 minutes) a small block doubles the furnace's share for
# ~2.5 heats at ~$360 a heat — worth it for an urgent order, while the district's first stage (~$25k)
# pays for itself within two hours of a short furnace. Cash then is $20–60k, a ship brings ~$20k.
const SIZES := {
	"s": {"zh": "小块", "en": "SMALL", "mwh": 1.5, "mw": 4.0, "price": 900.0, "eta": 40.0, "h": 1.7},
	"m": {"zh": "中块", "en": "MEDIUM", "mwh": 4.0, "mw": 8.0, "price": 2200.0, "eta": 75.0, "h": 2.3},
	"l": {"zh": "大块", "en": "LARGE", "mwh": 10.0, "mw": 12.0, "price": 5000.0, "eta": 120.0, "h": 2.9},
}
const ORDER := ["s", "m", "l"]
const SLOTS := 2
# the roof where the shore line's umbilical lay (it retires: bought power comes as batteries now),
# right of the transformers; the ship comes straight down the 8.8 m gap between two radiator fins
# (39–41.2 and 50–52.2), well clear of the work boat's pad 34 m over the roof's middle
const SLOT_X := [45.55, 47.55]            # box-local x of each slot's centre on the roof
const SLOT_W := 1.8
const HOVER_Y := -8.0                   # the ship's belly, over the transformers' bushings (-4), under the fins' foot (-12)
const SHIP_X := 45.65                     # in the fins' gap 41.2 … 50 (RCS quads included)
const SHIP_HALF := 3.8                  # m: the freighter's half width (between the fins: 0.9 m left, 0.3 m right)
const BAY_HALF := 2.2                   # m: the bay, wide enough for the trolley over either slot
const SHIP_H := 3.4
const APPROACH_S := 13.0                # the last part of the flight, seen
const LIFT_S := 5.0
const LOWER_S := 6.5
const LATCH_S := 1.6
const LEAVE_S := 9.0
const PICKUP_WAIT := 20.0
const LOW_AT := 0.25                    # auto reorder below this share left

const OVER_K := 0.2
const HEAT_UP := 1.0 / 40.0             # a second, the whole margin used
const HEAT_DOWN := 1.0 / 70.0
const REPAIR_S := 2.5
const REPAIR_M := 6.0
const REPAIR_AIM := 3.0
static var fixing := false

const FC_BASE := 6.0                    # the emergency set (it was the whole stage-0 plant)
const FC2_MW := 5.0                     # the second stack on delivered LH2 / LOX
const FC_TANK := 6.0                    # MWh the fuel cells' tanks hold
const RUN_MWH := 4.0                    # one tug run's most
const CRYO_LOW := 0.5
# 2026-11-07 (用户定): the runs carry what is really in stock, none when there is none. A fuel cell
# turns hydrogen's 33.3 kWh/kg (lower heating value) into electricity at about half, so a MWh out takes
# 60 kg of LH2 and, at 8 kg of oxygen to each kilo of hydrogen, 480 kg of LOX.
#   LOX: the processing district's gas line (separated, liquefied, in its tank) — 132 号: nothing held back for passing ships any more;
#        whole oxygen tanks taken off ships at the tug station and stored in the warehouse, by what they hold
#   LH2: the gas line makes none (hydrogen is disposed of); whole LH2 tanks from the tug station only
const H2_KG_MWH := 60.0
const O2_PER_H2 := 8.0
const LH2_RHO := 71.0                   # kg/m³
const LOX_RHO := 1141.0
const MIN_MWH := 0.5                    # less than this is not worth a run
const LH2_TANKS := ["p_lh2_tank", "p_sp_lh2_tank"]
const LOX_TANKS := ["p_o2_store", "p_ark_o2tank", "p_bl_o2_store"]

static var t := 0.0
static var batt_now := 0.0              # MW the batteries give now
static var _sig := ""


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func on() -> bool:
	return ENABLED and Career.usable() and not Career.data.is_empty()


static func d() -> Dictionary:
	if Career.data.is_empty():
		return {}
	if not Career.data.has("power5"):
		Career.data.power5 = fresh()
	return Career.data.power5


static func fresh() -> Dictionary:
	return {"slots": [{}, {}], "orders": [], "auto": false, "auto_size": "m", "pickup_t": -1.0,
		"gens": {"tg": {"over": false, "heat": 0.0, "trip": false, "fix": 0.0}, "fc": {"over": false, "heat": 0.0, "trip": false, "fix": 0.0}},
		"fc_fuel": 0.0, "cryo": {"phase": "home", "t": 0.0, "h2": 0.0, "o2": 0.0, "frost": 0.0, "runs": 0}, "first_install": false}


static func size_name(s: String) -> String:
	var z: Dictionary = SIZES.get(s, {})
	return w(str(z.get("zh", "")), str(z.get("en", "")))


# ---------------------------------------------------------------- generators

static func tg_rated() -> float:
	return maxf(0.0, Grid.CAPACITY[clampi(Port.stage("power"), 0, 2)] - FC_BASE)


static func gen_list() -> Array:
	var out: Array = []
	if tg_rated() > 0.0:
		out.append("tg")
	out.append("fc")
	return out


static func gen_name(id: String) -> String:
	return w("汽轮发电机", "TURBINE-GENERATOR") if id == "tg" else w("燃料电池组", "FUEL-CELL SET")


static func rated(id: String) -> float:
	return tg_rated() if id == "tg" else FC_BASE


static func gen_cap(id: String) -> float:
	var g: Dictionary = d().get("gens", {}).get(id, {})
	if g.get("trip", false):
		return 0.0
	return rated(id) * (1.0 + OVER_K if g.get("over", false) else 1.0)


static func fc2_mw() -> float:
	return FC2_MW if float(d().get("fc_fuel", 0.0)) > 0.0001 else 0.0


static func gens_mw() -> float:
	var s := 0.0
	for id in gen_list():
		s += gen_cap(id)
	return s + fc2_mw()


static func battery_mw() -> float:
	var s := 0.0
	for sl in d().get("slots", []):
		if not sl.is_empty() and float(sl.get("left", 0.0)) > 0.0001:
			s += float(SIZES[str(sl.size)].mw)
	return s


# what the port's own supply can give now (Grid.capacity() when ENABLED)
static func capacity() -> float:
	return gens_mw() + battery_mw()


static func set_over(id: String, on_: bool) -> Dictionary:
	var g: Dictionary = d().gens.get(id, {})
	if g.is_empty():
		return {"ok": false, "reason": w("找不到这台发电机", "NO SUCH SET")}
	if g.get("trip", false):
		return {"ok": false, "reason": w("%s 已经过热停机，需要先用维护工具完成修理。", "%s TRIPPED; MEND IT WITH THE WRENCH FIRST") % gen_name(id)}
	g.over = on_
	Career.save()
	return {"ok": true, "note": (w("%s 当前超载 %d%%，热量达到上限后会自动停机。", "%s OVERLOAD +%d%% · IT HEATS; FULL, IT TRIPS") if on_ else w("%s 已恢复额定功率，正在散热。", "%s BACK TO RATED · COOLING")) % ([gen_name(id), int(OVER_K * 100)] if on_ else [gen_name(id)])}


# box-local metres: where the wrench must be held for each set
static func repair_at(id: String) -> Vector2:
	return Vector2(52.6, 13.6) if id == "tg" else Vector2(9.4, 21.5)   # under the generator's end of the deck; beside the stacks


static func repair_step(id: String, dt: float) -> bool:
	var g: Dictionary = d().gens.get(id, {})
	if not g.get("trip", false):
		return false
	g.fix = float(g.get("fix", 0.0)) + dt / REPAIR_S
	if float(g.fix) >= 1.0:
		g.trip = false
		g.fix = 0.0
		g.heat = 0.35
		g.over = false
		Career.save()
		return true
	return false


# ---------------------------------------------------------------- batteries

static func pending() -> Array:
	return d().get("orders", []).filter(func(o): return str(o.size) != "")


# a slot a new block can go to (free first, then a spent shell) not already taken by a ship on its way
static func _target_slot() -> int:
	# a new block goes only into an empty slot; a spent shell is lifted off by the ship that comes past
	# (after it has set its block down) or by a pickup run
	var taken: Array = d().orders.map(func(o): return int(o.get("slot", -1)))
	var sl: Array = d().slots
	for i in SLOTS:
		if sl[i].is_empty() and not i in taken:
			return i
	return -1


# a slot with a spent shell no ship is coming for yet
static func _spent_slot(except := -1) -> int:
	var picks: Array = d().orders.map(func(o): return int(o.get("pick", -1)))
	var sl: Array = d().slots
	for i in SLOTS:
		if i != except and not sl[i].is_empty() and float(sl[i].get("left", 0.0)) <= 0.0001 and not i in picks:
			return i
	return -1


static func can_order(s: String) -> Dictionary:
	if not SIZES.has(s):
		return {"ok": false, "reason": w("找不到这种电池", "NO SUCH BLOCK")}
	if _target_slot() < 0:
		return {"ok": false, "reason": w("所有电池泊位都已占用，请等待电池用完并运走空壳后再下单。", "BOTH SLOTS IN USE: ORDER ONCE A SHELL HAS GONE")}
	if float(Career.data.get("money", 0.0)) < float(SIZES[s].price):
		return {"ok": false, "reason": w("现金不足，购买需要 $%s", "NOT ENOUGH MONEY: $%s") % _money(float(SIZES[s].price))}
	return {"ok": true}


static func order(s: String, auto_ := false) -> Dictionary:
	var c := can_order(s)
	if not c.ok:
		return c
	var z: Dictionary = SIZES[s]
	var slot := _target_slot()
	Career.data.money = float(Career.data.get("money", 0.0)) - float(z.price)
	if Career.data.get("exchange", {}).get("actors", {}).has("company"):
		Career.data.exchange.actors.company.cash = float(Career.data.money)
	# one ship on the roof at a time: a later order arrives after the one before it has gone
	var eta := float(z.eta)
	for o in d().orders:
		eta = maxf(eta, float(o.t) + LIFT_S + LOWER_S + LATCH_S + LEAVE_S + 2.0)
	d().orders.append({"size": s, "t": eta, "eta0": eta, "slot": slot, "phase": "transit", "pt": 0.0, "auto": auto_})
	d().auto_size = s
	Career.save()
	return {"ok": true, "note": w("电池已订购：%s 电池，容量 %.1f 兆瓦时，花费 $%s。预计 %d 秒后抵达港口，随后会吊装到 %s 号电池泊位。", "ORDERED: %s BLOCK %.1f MWh · $%s · IN ABOUT %d s, TO BERTH SLOT %s") % [size_name(s), float(z.mwh), _money(float(z.price)), int(ceil(eta)), "AB"[slot]]}


static func _money(v: float) -> String:
	var s := str(int(round(v)))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


static func set_auto(on_: bool) -> void:
	d().auto = on_
	Career.save()


static func left_mwh() -> float:
	var s := 0.0
	for sl in d().get("slots", []):
		if not sl.is_empty():
			s += float(sl.get("left", 0.0))
	return s


static func full_mwh() -> float:
	var s := 0.0
	for sl in d().get("slots", []):
		if not sl.is_empty():
			s += float(SIZES[str(sl.size)].mwh)
	return s


# the ship of the order now on the roof (or coming in sight), {} when none
static func ship() -> Dictionary:
	for o in d().get("orders", []):
		if str(o.phase) != "transit" or float(o.t) <= APPROACH_S:
			return o
	return {}


# the delivery ship's place, box-local metres, and its acceleration (m/s², for the plume)
static func ship_pose(o: Dictionary) -> Dictionary:
	if o.is_empty():
		return {}
	var hover := Vector2(SHIP_X, HOVER_Y)
	match str(o.phase):
		"transit":
			# coasting in at 22 m/s, then braking at 4 m/s² to a stop over the berth (the last 5.5 s)
			var tl := float(o.t)
			var vb := 22.0
			var ab := 4.0
			var tb := vb / ab
			if tl <= tb:
				var dist := 0.5 * ab * tl * tl
				return {"p": hover + Vector2(0, -dist), "a": Vector2(0, -ab), "v": Vector2(0, ab * tl)}
			var dist2 := 0.5 * ab * tb * tb + vb * (tl - tb)
			return {"p": hover + Vector2(0, -dist2), "a": Vector2.ZERO, "v": Vector2(0, vb)}
		"leave":
			var tt := float(o.pt)
			var al := 3.0
			return {"p": hover + Vector2(0, -0.5 * al * tt * tt), "a": Vector2(0, -al), "v": Vector2(0, -al * tt)}
		_:
			# holding station: the tiniest sideways drift trimmed by the RCS (the winch holds the height)
			return {"p": hover + Vector2(0.05 * sin(t * 0.7), 0.0), "a": Vector2(0.03 * cos(t * 0.7), 0.0), "v": Vector2.ZERO}


# the bay doors 0 shut … 1 open: opening over the last 3 s in, open while it works, shut once the hook is up
static func bay_doors(o: Dictionary) -> float:
	match str(o.get("phase", "")):
		"transit":
			return clampf((3.0 - float(o.t)) / 2.0, 0.0, 1.0)
		"leave":
			if o.get("carry", false):
				return 1.0          # the shell hangs under the bay all the way out
			return 1.0 - clampf((float(o.pt) - 1.6) / 1.4, 0.0, 1.0)
	return 1.0


# ---------------------------------------------------------------- the berth and the hoist, as shapes
# (2026-11-07 用户实机：船、吊索、电池块穿过导向架) One set of numbers for the drawing and the test.
# The cradle: a base plate, three posts (two outer ones flared outward at the top, one divider) — each
# slot an opening 1.93 m wide the 1.8 m block drops straight into. Box-local metres.
const POSTS_X := [44.5, 46.55, 48.6]
const POST_W := 0.12
const POST_TOP := -3.4
const BASE := Rect2(44.45, -0.7, 4.25, 0.7)
const FLARES := [Rect2(44.15, -3.9, 0.35, 0.5), Rect2(48.6, -3.9, 0.35, 0.5)]
const TROLLEY_DY := -0.73               # the trolley's sheaves under the belly
const LUG_GAP := 0.3                    # the spreader's pins over the block's lugs
const SPREADER := Vector2(1.6, 0.24)


static func block_h(sz: String) -> float:
	return float(SIZES.get(sz, SIZES.m).h)


# the hook's length that seats a block of height h on the base plate
static func seat_len(h: float) -> float:
	return (BASE.position.y - h - LUG_GAP - SPREADER.y) - (HOVER_Y + TROLLEY_DY + 0.4)


# the hook: how long, what it holds ("new" / "old" / ""), over which slot
static func hook(o: Dictionary) -> Dictionary:
	if o.is_empty():
		return {}
	var slot := int(o.get("slot", 0))
	if str(o.phase) == "lift_old" or (str(o.phase) == "leave" and o.get("carry", false)) or slot < 0:
		slot = maxi(0, int(o.get("pick", 0)))
	var pt := float(o.get("pt", 0.0))
	var new_h := block_h(str(o.size)) if str(o.size) != "" else block_h("m")
	match str(o.phase):
		"lift_old":
			# down empty onto the shell's lugs, then up with it
			var sz := str(o.get("old_size", d().slots[slot].get("size", "m") if not d().slots[slot].is_empty() else "m"))
			var drop0 := seat_len(block_h(sz))
			var k := pt / LIFT_S
			return {"slot": slot, "len": lerpf(1.0, drop0, 1.0 - absf(1.0 - 2.0 * Pal.ease_io(k))), "holds": "old" if k > 0.5 else "", "k": k, "size": sz}
		"lower":
			var k2 := Pal.ease_io(clampf(pt / LOWER_S, 0.0, 1.0))
			return {"slot": slot, "len": lerpf(1.0, seat_len(new_h), k2), "holds": "new", "k": k2, "size": str(o.size)}
		"latch":
			return {"slot": slot, "len": seat_len(new_h), "holds": "new", "k": 1.0, "latch": clampf(pt / LATCH_S, 0.0, 1.0), "size": str(o.size)}
		"leave":
			if o.get("carry", false):
				return {"slot": slot, "len": 1.0, "holds": "old", "k": 0.0, "size": str(o.get("old_size", "m"))}
			return {"slot": slot, "len": maxf(1.0, seat_len(new_h) * (1.0 - pt / 1.5)), "holds": "", "k": 0.0, "size": ""}
		_:
			return {"slot": slot, "len": 1.0, "holds": "new" if str(o.size) != "" else "", "k": 0.0, "size": str(o.size)}


# where everything on the hook is: the trolley, the spreader, the block (box-local metres)
static func hoist_geom(o: Dictionary) -> Dictionary:
	if o.is_empty():
		return {}
	var pose := ship_pose(o)
	var hk := hook(o)
	var slot := int(hk.slot)
	var p: Vector2 = pose.p
	var tx := clampf(float(SLOT_X[slot]) - p.x, -BAY_HALF + 0.3, BAY_HALF - 0.3)
	var trolley := Vector2(p.x + tx, p.y + TROLLEY_DY)
	var spx: float = SLOT_X[slot]
	var sp_y := trolley.y + 0.4 + float(hk.len)
	var holds := str(hk.holds)
	var hsz := str(hk.get("size", "m"))
	if hsz == "":
		hsz = "m"
	var h := block_h(hsz) if holds != "" else 0.0
	var blk := Rect2(spx - SLOT_W * 0.5, sp_y + SPREADER.y + LUG_GAP, SLOT_W, h) if holds != "" else Rect2()
	return {"pose": pose, "hook": hk, "slot": slot, "trolley": trolley, "spx": spx, "sp_y": sp_y, "holds": holds, "hsz": hsz, "h": h, "block": blk}


# what moves: the ship (RCS quads, mast and engine bells included), the cables under it, the spreader, the block
static func hoist_shapes(o: Dictionary) -> Array:
	var gm := hoist_geom(o)
	if gm.is_empty():
		return []
	var p: Vector2 = gm.pose.p
	var out: Array = [["ship", Rect2(p.x - SHIP_HALF - 0.42, p.y - SHIP_H - 1.3, 2.0 * SHIP_HALF + 0.84, SHIP_H + 1.3 + 0.78)]]
	var tr: Vector2 = gm.trolley
	var spx: float = gm.spx
	var sp_y: float = gm.sp_y
	if sp_y > p.y + 0.8:
		var x0 := minf(tr.x - 0.32, spx - 0.54)
		var x1 := maxf(tr.x + 0.32, spx + 0.54)
		out.append(["cables", Rect2(x0, p.y + 0.8, x1 - x0, sp_y - p.y - 0.8)])
	out.append(["spreader", Rect2(spx - SPREADER.x * 0.5, sp_y, SPREADER.x, SPREADER.y)])
	if gm.holds != "":
		out.append(["block", gm.block])
	return out


# the port's solid outlines around the berth: the cradle, the transformers, the fins, the work boat's pad,
# and the blocks standing in the other slot
static func berth_solids(except_slot := -1) -> Array:
	var out: Array = [["base", BASE]]
	for x in POSTS_X:
		out.append(["post", Rect2(float(x) - POST_W * 0.5, POST_TOP, POST_W, BASE.position.y - POST_TOP)])
	for f in FLARES:
		out.append(["flare", f])
	out.append(["transformer", Rect2(36.0, -4.0, 3.4, 4.0)])
	out.append(["transformer", Rect2(41.0, -4.0, 3.4, 4.0)])
	for i in 5:
		out.append(["fin", Rect2(6.0 + i * 11.0, -26.0, 2.2, 14.0)])
	out.append(["boat pad", Rect2(23.6, -31.2, 12.9, 1.4)])
	for i in SLOTS:
		var sl: Dictionary = d().slots[i]
		if i != except_slot and not sl.is_empty():
			var h := block_h(str(sl.size))
			out.append(["block in " + "AB"[i], Rect2(float(SLOT_X[i]) - SLOT_W * 0.5, BASE.position.y - h, SLOT_W, h)])
	return out


# every overlap of what moves with what stands, for one moment of an order ([] when clear)
static func clashes(o: Dictionary) -> Array:
	var gm := hoist_geom(o)
	if gm.is_empty():
		return []
	var out: Array = []
	for a in hoist_shapes(o):
		for b in berth_solids(int(gm.slot)):
			if (a[1] as Rect2).grow(-0.004).intersects((b[1] as Rect2).grow(-0.004)):
				out.append("%s × %s" % [a[0], b[0]])
	return out


static func _say(game, text: String) -> void:
	if game == null or not is_instance_valid(game) or game.get("messages") == null:
		return
	var at: Vector2 = PortStructure.box("power").position + Vector2(SHIP_X, -4.0) * PortStructure.M()
	game.messages.append(["ps5", at, 0.0, text])
	notes.append(text)


static var notes: Array = []   # what was said (tests; the panel shows the last)


static func _tick_orders(game, dt: float) -> void:
	var p := d()
	var keep: Array = []
	for o in p.orders:
		match str(o.phase):
			"transit":
				o.t = float(o.t) - dt
				if float(o.t) <= 0.0:
					o.t = 0.0
					o.phase = "lower" if str(o.size) != "" else ("lift_old" if int(o.get("pick", -1)) >= 0 else "leave")
					o.pt = 0.0
			"lift_old":
				o.pt = float(o.pt) + dt
				var pk := int(o.get("pick", -1))
				if float(o.pt) >= LIFT_S * 0.5 and pk >= 0 and not p.slots[pk].is_empty():
					o.old_size = str(p.slots[pk].get("size", "m"))
					o.carry = true
					p.slots[pk] = {}
				if float(o.pt) >= LIFT_S:
					o.phase = "leave"
					o.pt = 0.0
					Career.save()
			"lower":
				o.pt = float(o.pt) + dt
				if float(o.pt) >= LOWER_S:
					o.phase = "latch"
					o.pt = 0.0
			"latch":
				o.pt = float(o.pt) + dt
				if float(o.pt) >= LATCH_S:
					var z: Dictionary = SIZES[str(o.size)]
					p.slots[int(o.slot)] = {"size": str(o.size), "left": float(z.mwh), "t": 0.0}
					# then the spent shell in the other slot, if any, goes up with it
					o.pick = _spent_slot(int(o.slot))
					o.phase = "lift_old" if int(o.pick) >= 0 else "leave"
					o.pt = 0.0
					p.first_install = true
					Career.save()
					_say(game, w("电池已接入：%s，剩余电量 %.1f 兆瓦时，位于 %s 号泊位。现在可以为总线额外提供 %.0f 兆瓦的电力。", "BLOCK IN: %s %.1f MWh · SLOT %s · %.0f MW MORE ON THE BUS") % [size_name(str(o.size)), float(z.mwh), "AB"[int(o.slot)], float(z.mw)])
			"leave":
				o.pt = float(o.pt) + dt
				if float(o.pt) >= LEAVE_S:
					continue
		keep.append(o)
	p.orders = keep


# the bus drew `own` MW of the port's own supply this step: the sets give first, the batteries the rest
static func _drain(game, own: float, dt: float) -> void:
	var p := d()
	var from_gens := minf(own, gens_mw())
	# the fuel cells' second stack burns the delivered fuel for its share
	var base_gens := 0.0
	for id in gen_list():
		base_gens += gen_cap(id)
	var fc2_used := clampf(own - base_gens, 0.0, fc2_mw())
	p.fc_fuel = maxf(0.0, float(p.fc_fuel) - fc2_used * dt / 3600.0)
	var need := maxf(0.0, own - from_gens)
	batt_now = minf(need, battery_mw())
	var bmw := battery_mw()
	if need > 0.0001 and bmw > 0.0:
		for sl in p.slots:
			if sl.is_empty() or float(sl.left) <= 0.0001:
				continue
			var share := need * float(SIZES[str(sl.size)].mw) / bmw
			sl.left = maxf(0.0, float(sl.left) - share * dt / 3600.0)
			if float(sl.left) <= 0.0001:
				_say(game, w("%s 电池的电量已经用完，空壳会在送货飞船抵达后运走。", "SLOT %s SPENT: THE SHELL WAITS FOR A SHIP") % "AB"[p.slots.find(sl)])
	# each set's heat: rising while it runs over its rating, falling otherwise; full, it trips
	var left_own := own
	for id in gen_list():
		var g: Dictionary = p.gens[id]
		var out := minf(left_own, gen_cap(id))
		left_own -= out
		g["out"] = out
		var margin := rated(id) * OVER_K
		var over_used := clampf((out - rated(id)) / maxf(0.001, margin), 0.0, 1.0) if g.get("over", false) else 0.0
		if g.get("trip", false):
			g.heat = maxf(0.6, float(g.heat) - HEAT_DOWN * dt * 0.3)
		elif over_used > 0.02:
			g.heat = minf(1.0, float(g.heat) + HEAT_UP * over_used * dt)
			if float(g.heat) >= 1.0:
				g.trip = true
				g.over = false
				g.fix = 0.0
				Career.save()
				# 132 号: the first time, the situation card says it (not this line as well)
				if not load("res://scripts/guide_cards.gd").will_show("first_trip"):
					_say(game, w("%s 已经过热停机，需要使用维护工具（4）完成修理后才能重新启动。", "%s OVERHEATED AND TRIPPED: TAKE THE WRENCH (4) TO IT") % gen_name(id))
		else:
			g.heat = maxf(0.0, float(g.heat) - HEAT_DOWN * dt)


static func _auto(game, dt: float) -> void:
	var p := d()
	if bool(p.get("auto", false)) and pending().is_empty() and full_mwh() > 0.0 and left_mwh() < full_mwh() * LOW_AT:
		var r := order(str(p.get("auto_size", "m")), true)
		if r.ok:
			_say(game, w("电池电量即将耗尽，已自动订购一块新电池：", "LOW: ANOTHER ORDERED: ") + str(r.note))
	# a spent shell and no ship coming: a pickup run
	var spent := false
	for sl in p.slots:
		if not sl.is_empty() and float(sl.left) <= 0.0001:
			spent = true
	if spent and _spent_slot() >= 0 and not p.orders.any(func(o): return str(o.size) != "" and str(o.phase) != "leave"):
		p.pickup_t = float(p.get("pickup_t", -1.0))
		if p.pickup_t < 0.0:
			p.pickup_t = PICKUP_WAIT
		p.pickup_t -= dt
		if p.pickup_t <= 0.0:
			p.pickup_t = -1.0
			for i in [_spent_slot()]:
				if i >= 0:
					p.orders.append({"size": "", "t": APPROACH_S, "eta0": APPROACH_S, "slot": -1, "pick": i, "phase": "transit", "pt": 0.0})
	else:
		p.pickup_t = -1.0


# ---------------------------------------------------------------- the cryo run (processing → power)
# port metres; the tug flies behind its frame (two tanks: LH2 and LOX), the frame's centre is the pose.
# The legs: up off the processing district's roof (left of the tug station), along under the power
# district's radiator array, to the fuel cells' fill coupling on its left wall.

static func route() -> Array:
	var pb := PortArt.district_at("process") - PortArt.BOX * 0.5
	var wb := PortArt.district_at("power") - PortArt.BOX * 0.5
	var stand := pb + Vector2(6.0, -1.6)
	var dock := wb + Vector2(-5.2, 25.2)
	return [stand, Vector2(stand.x, stand.y - 6.0), Vector2(stand.x, dock.y), Vector2(dock.x - 6.0, dock.y), dock]


const A_MAX := 1.6       # m/s²
const V_MAX := 8.0       # m/s
const DOCK_V := 0.6      # the last metres crept in

# a straight leg run accelerate → coast → brake: [time, pos(s), vel, acc] at time tt
static func _leg(L: float, tt: float, vmax := V_MAX, amax := A_MAX) -> Array:
	var ta := vmax / amax
	var la := 0.5 * amax * ta * ta
	if 2.0 * la > L:
		ta = sqrt(L / amax)
		vmax = amax * ta
		la = 0.5 * L
	var tc := (L - 2.0 * la) / vmax
	var total := 2.0 * ta + tc
	if tt <= ta:
		return [total, 0.5 * amax * tt * tt, amax * tt, amax]
	if tt <= ta + tc:
		return [total, la + vmax * (tt - ta), vmax, 0.0]
	if tt <= total:
		var tb := tt - ta - tc
		return [total, la + vmax * tc + vmax * tb - 0.5 * amax * tb * tb, vmax - amax * tb, -amax]
	return [total, L, 0.0, 0.0]


static func _leg_time(i: int) -> float:
	var r := route()
	var slow: bool = i == 0 or i == r.size() - 2
	return _leg((r[i + 1] - r[i]).length(), 0.0, 1.2 if slow else V_MAX, 0.5 if slow else A_MAX)[0]


# phases and seconds: at the processing stand, the flight out, at the coupling, the flight back
const C_STEPS := [["p_precool", 3.0], ["p_fill", 6.0], ["p_close", 2.0], ["lift", 1.5], ["fly", 0.0], ["d_connect", 2.5],
	["d_precool", 3.5], ["d_fill", 8.0], ["d_close", 2.5], ["back", 0.0], ["set", 1.5]]


static func fly_total() -> float:
	var s := 0.0
	for i in route().size() - 1:
		s += _leg_time(i) + 0.8
	return s


static func cryo_pose(c: Dictionary) -> Dictionary:
	var r := route()
	var ph := str(c.get("phase", "home"))
	if ph in ["fly", "back"]:
		var tt := float(c.t)
		var legs := range(r.size() - 1)
		if ph == "back":
			legs.reverse()
		for i in legs:
			var a: Vector2 = r[i] if ph == "fly" else r[i + 1]
			var b: Vector2 = r[i + 1] if ph == "fly" else r[i]
			var slow: bool = i == 0 or i == r.size() - 2
			var lg := _leg((b - a).length(), 0.0, 1.2 if slow else V_MAX, 0.5 if slow else A_MAX)
			var total: float = lg[0]
			if tt <= total:
				var s := _leg((b - a).length(), tt, 1.2 if slow else V_MAX, 0.5 if slow else A_MAX)
				var dir := (b - a).normalized()
				return {"p": a + dir * float(s[1]), "v": dir * float(s[2]), "a": dir * float(s[3])}
			tt -= total
			if tt <= 0.8:
				return {"p": b, "v": Vector2.ZERO, "a": Vector2.ZERO}
			tt -= 0.8
		return {"p": r[r.size() - 1] if ph == "fly" else r[0], "v": Vector2.ZERO, "a": Vector2.ZERO}
	if ph in ["d_connect", "d_precool", "d_fill", "d_close"]:
		return {"p": r[r.size() - 1], "v": Vector2.ZERO, "a": Vector2.ZERO}
	return {"p": r[0], "v": Vector2.ZERO, "a": Vector2.ZERO}


static func _tank_goods(keys: Array) -> Array:
	return Career.data.get("goods", []).filter(func(gd): return str(gd.get("nk", "")) in keys and float(gd.get("liq_m3", 0.0)) > 0.0001)


static func stock_h2() -> float:
	# the gas line's own LH2 (piped in from the tug station's cryo tanks, 2026-11-11), what is
	# still in those tanks, and the LH2 tanks salvaged whole into the warehouse
	var kg := float(Career.data.get("gas", {}).get("lh2", {}).get("kg", 0.0)) + float(TugYard.cryo().lh2)
	for gd in _tank_goods(LH2_TANKS):
		kg += float(gd.liq_m3) * LH2_RHO
	return kg


static func _gas_lox() -> float:
	var gas: Dictionary = Career.data.get("gas", {})
	if gas.is_empty():
		return 0.0
	return maxf(0.0, float(gas.get("lox", {}).get("kg", 0.0)))


static func stock_o2() -> float:
	var kg := _gas_lox() + float(TugYard.cryo().lox)
	for gd in _tank_goods(LOX_TANKS):
		kg += float(gd.liq_m3) * LOX_RHO
	return kg


# what the next run can carry: [MWh, kg LH2, kg LOX] (0 when the stock is not enough)
static func next_run() -> Array:
	var room := maxf(0.0, FC_TANK - float(d().get("fc_fuel", 0.0)))
	var mwh := minf(minf(RUN_MWH, room), minf(stock_h2() / H2_KG_MWH, stock_o2() / (H2_KG_MWH * O2_PER_H2)))
	if mwh < MIN_MWH:
		return [0.0, 0.0, 0.0]
	return [mwh, mwh * H2_KG_MWH, mwh * H2_KG_MWH * O2_PER_H2]


# take it out of the stock (the gas line's tank first for the oxygen; tanks by turn)
static func _withdraw(h2: float, o2: float) -> void:
	var gl: Dictionary = Career.data.get("gas", {}).get("lh2", {})
	if not gl.is_empty():
		var t0 := minf(h2, float(gl.get("kg", 0.0)))
		gl.kg = float(gl.kg) - t0
		h2 -= t0
	# then the tug station's cryo tanks (not yet piped over)
	for kind in ["lh2", "lox"]:
		var want := h2 if kind == "lh2" else o2
		var t1 := minf(want, float(TugYard.cryo()[kind]))
		if t1 > 0.0:
			TugYard.set_cryo(kind, float(TugYard.cryo()[kind]) - t1)
			if kind == "lh2":
				h2 -= t1
			else:
				o2 -= t1
	for gd in _tank_goods(LH2_TANKS):
		if h2 <= 0.0001:
			break
		var take := minf(h2, float(gd.liq_m3) * LH2_RHO)
		gd.liq_m3 = snappedf(maxf(0.0, float(gd.liq_m3) - take / LH2_RHO), 0.0001)
		h2 -= take
	var gas: Dictionary = Career.data.get("gas", {})
	if not gas.is_empty():
		var t2 := minf(o2, _gas_lox())
		gas.lox.kg = float(gas.lox.kg) - t2
		o2 -= t2
	for gd in _tank_goods(LOX_TANKS):
		if o2 <= 0.0001:
			break
		var take2 := minf(o2, float(gd.liq_m3) * LOX_RHO)
		gd.liq_m3 = snappedf(maxf(0.0, float(gd.liq_m3) - take2 / LOX_RHO), 0.0001)
		o2 -= take2


static func cryo_status() -> String:
	var c: Dictionary = d().cryo
	if str(c.phase) != "home":
		return w("正在运送燃料：液氢 %.0f kg、液氧 %.0f kg，可提供 %.1f 兆瓦时电量。", "ON ITS WAY: %.0f kg LH2, %.0f kg LOX (%.1f MWh)") % [float(c.get("h2_kg", 0.0)), float(c.get("o2_kg", 0.0)), float(c.get("mwh", 0.0))]
	var nr := next_run()
	if float(nr[0]) <= 0.0:
		if float(d().get("fc_fuel", 0.0)) >= FC_TANK - MIN_MWH:
			return w("燃料电池的储罐已经装满，暂时无法继续补充燃料。", "THE FUEL CELLS' TANK IS FULL")
		return w("库存不足，无法运送燃料。当前液氢库存 %.0f kg（〔来源：拖船站从废船抽回的低温罐 · 仓库里的液氢罐〕），液氧库存 %.0f kg（〔来源：加工区气体生产线 · 拖船站抽回的液氧〕）。", "NO STOCK, NO RUN: %.0f kg LH2 (TANKS FROM THE TUG STATION) · %.0f kg LOX (THE GAS LINE)") % [stock_h2(), stock_o2()]
	return w("当前库存：液氢 %.0f kg、液氧 %.0f kg。燃料储罐低于一半时，会自动安排一次燃料运输。", "STOCK: %.0f kg LH2 · %.0f kg LOX · A RUN GOES BELOW HALF") % [stock_h2(), stock_o2()]


static func start_cryo() -> bool:
	var c: Dictionary = d().cryo
	if str(c.phase) != "home":
		return false
	var nr := next_run()
	if float(nr[0]) <= 0.0:
		return false
	c.mwh = nr[0]
	c.h2_kg = nr[1]
	c.o2_kg = nr[2]
	_withdraw(float(nr[1]), float(nr[2]))
	Career.save()
	c.phase = "p_precool"
	c.t = 0.0
	return true


static func _tick_cryo(game, dt: float) -> void:
	var p := d()
	var c: Dictionary = p.cryo
	if str(c.phase) == "home":
		c.frost = maxf(0.0, float(c.frost) - dt / 40.0)
		if CRYO_AUTO and float(p.fc_fuel) < FC_TANK * CRYO_LOW and Port.stage("process") >= 1:
			start_cryo()
		return
	c.t = float(c.t) + dt
	var ph := str(c.phase)
	var dur := 0.0
	for st in C_STEPS:
		if st[0] == ph:
			dur = float(st[1])
	if ph in ["fly", "back"]:
		dur = fly_total()
	match ph:
		"p_fill":
			c.h2 = clampf(float(c.t) / dur, 0.0, 1.0)
			c.o2 = c.h2
		"d_fill":
			var k := clampf(float(c.t) / dur, 0.0, 1.0)
			var before := float(c.h2)
			c.h2 = 1.0 - k
			c.o2 = 1.0 - k
			p.fc_fuel = minf(FC_TANK, float(p.fc_fuel) + (before - float(c.h2)) * float(c.get("mwh", RUN_MWH)))
	# frost grows from the precool on and while the tanks are full, fades once empty
	if ph in ["p_precool", "p_fill", "p_close", "lift", "fly", "d_connect", "d_precool", "d_fill"]:
		c.frost = minf(1.0, float(c.frost) + dt / 7.0)
	else:
		c.frost = maxf(0.0, float(c.frost) - dt / 30.0)
	if float(c.t) >= dur:
		var i := -1
		for k2 in C_STEPS.size():
			if C_STEPS[k2][0] == ph:
				i = k2
		c.t = 0.0
		if i < 0 or i == C_STEPS.size() - 1:
			c.phase = "home"
			c.runs = int(c.get("runs", 0)) + 1
		else:
			c.phase = C_STEPS[i + 1][0]
			if c.phase == "d_close":
				_say(game, w("液氢和液氧已补充到燃料电池储罐，第二组电堆现已启动，额外提供 %.0f 兆瓦电力。", "LH2 AND LOX IN: THE SECOND STACK +%.0f MW") % FC2_MW)


# ---------------------------------------------------------------- the step

static func tick(game, dt: float) -> void:
	if not on():
		return
	t += dt
	var own := 0.0
	if game != null and is_instance_valid(game):
		own = Grid.reserved(game)
	_drain(game, own, dt)
	_tick_orders(game, dt)
	_auto(game, dt)
	_tick_cryo(game, dt)
	# the wrench held on a tripped set mends it
	if game != null and is_instance_valid(game) and game.get("drone") != null and game.get("tools") != null:
		var tl = game.tools
		var dr = game.drone
		for id in gen_list():
			if not d().gens[id].get("trip", false):
				continue
			var at: Vector2 = PortStructure.box("power").position + repair_at(id) * PortStructure.M()
			# the drone close, the wrench (4) chosen, its aim on the set and the trigger held
			var aim: Vector2 = game.get("aim") if game.get("aim") != null else dr.global_position
			var aimed := aim.distance_to(at) < REPAIR_AIM * PortStructure.M()
			fixing = dr.global_position.distance_to(at) < REPAIR_M * PortStructure.M() and int(tl.tool) == 4 and aimed and (bool(tl.get("lmb")) or wrench_hold)
			if fixing:
				if repair_step(id, dt):
					_say(game, w("%s 已完成修理，并且重新启动。", "%s MENDED AND RUNNING") % gen_name(id))


static var wrench_hold := false
static var CRYO_AUTO := true      # tests: no run of its own   # tests: the trigger held (no real mouse)
