class_name CleanRun
extends Node2D
# 认真拆有奖励 (design/认真拆有奖励_设计稿_20261111.md, user 2026-11-11 "认真拆，有奖励的话你可以搞一下"):
# taking a ship apart the careful way is worth more, the careless way costs nothing new.
#   clean   a whole machine into its mouth with nothing left in it (its battery run down, its
#           bottle vented, its tank drained), not knocked about (≤ 5 points of condition this job)
#           and no mishap on it. A hazard (fuel, acid, the hard kind) into the hazard mouth counts too.
#   combo   one step a clean machine, +0.5 % of its price a step, ten steps the most (+5 %); broken by a
#           mishap, a whole machine into the furnace, a cut into one, a knock of 5 points or more,
#           a real incident. Never by time.
#   grade   S / A / B on G = 0.75·C + 0.25·R (C: clean share of the whole machines by value, R: the
#           share of the ship's gas and liquid recovered; a ship with none: G = C). S ≥ 0.90 and no real
#           incident: +3 % of the job's income; A ≥ 0.70: +1.5 %; B nothing.
# A machine with something harmless still in it (a charge, air, water, coolant…) taken into the
# equipment mouth has a small mishap (scripts/mishap.gd) and is taken once it has thrown it out.
# The training course, the exam and the belt keep the old rules.
# Drawn in the world: the "clean" plates over the mouth.

static var ON := true

const STEP := 0.005            # of a clean machine's price, a combo step
const CAP_N := 10
const COND_SLACK := 0.05       # condition a machine may lose this job and still be clean
const BREAK_DENT := 0.05       # one knock this big breaks the combo
const S_AT := 0.90
const A_AT := 0.70
const S_BONUS := 0.03
const A_BONUS := 0.015
const GAS_LEFT_KPA := 20.0     # a bottle above this (and above 5 % of what it held) still holds gas
const BATT_LEFT := 0.05        # of its charge at the start
const CAP_LEFT := 0.05
# what is harmless when it comes out in the berth (vacuum: oxygen has nothing to burn with)
const BENIGN_LIQ := ["water", "coolant", "hydraulic", "glycol", "nutrient", "refrigerant"]
const HARD_LOOKS := ["lh2", "lhe", "lng", "ln2", "fuel", "mmh", "n2o4"]
# 2026-11-11 (评审: the lazy route may not pay more than ~10 % over the old one on any ship): a machine whose
# harmless leftovers were thrown out in a mishap or emptied on the drain rack keeps `lazy_k` of its price —
# worked out for each ship as it comes in so that what the lazy route pays for its machines is at most
# LAZY_CAP × what the old route paid (leftovers refused, 40 % at the hazard mouth), never under 40 %.
# A ship with few such machines keeps 1.0. tools/clean_run_calib.py works the same sum.
const LAZY_CAP := 1.05
const LAZY_FLOOR := 0.4
const MAJOR := ["blowout", "fire", "arc", "burst", "blast", "prop_blast", "o2_fire", "tank_burst", "tank_rupture", "drone_lost", "furnace"]
const LIQ = preload("res://scripts/liquids.gd")
const PowerSupply = preload("res://scripts/power_supply.gd")

var game
var prof_draw_us := 0
var prof_us := 0             # µs this node spent this run in _draw / _process / _physics_process (tests/clean_run_perf.gd)
var cond0 := {}               # piece id (str) -> condition at the start
var charge0 := {}             # source tag -> charge at the start
var kpa0 := {}                # vessel id -> pressure at the start
var base_value := 0.0         # the whole machines in the contract, at their full price
var lazy_k := 1.0             # this ship's lazy pay share (LAZY_CAP)
var batt_value0 := 0.0        # the ship's batteries' charge at the start, at the grid batteries' price
var clean_value := 0.0
var clean_n := 0
var whole_n := 0
var combo := 0
var best := 0
var bonus_cash := 0.0
var counted := {}             # piece id (str) -> true: judged at a mouth
var mishap_ids := {}          # piece id (str) -> kind
var drained_ids := {}         # piece id (str) -> kind: emptied on the drain rack (scripts/mishap.gd)
var mishaps: Array = []       # [kind, tag, value lost]
var major := false
var broke_t := -9.0           # playtime the combo last broke (the chip shakes)
var broke_n := 0              # the streak it broke at
var pop_t := -9.0             # playtime of the last clean (the chip pops)
var pops: Array = []          # [world pos, combo, t, text]
var _font: Font = null
var _tw_cache := {}           # a plate's words -> their width


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func setup(g) -> void:
	game = g
	z_index = 60
	_snapshot()


func active() -> bool:
	if not ON or game == null or game.training or game.exam != null or game.belt:
		return false
	return game.scope() != "rescue"


func _snapshot() -> void:
	var s = game.sys
	cond0 = {}
	base_value = 0.0
	whole_n = 0
	for id in game.world.order:
		var p = game.world.pieces[id]
		if p.cls == "equip" and p.intact and p.scope and not p.gone:
			cond0[str(p.id)] = p.cond
			base_value += float(p.value)
			whole_n += 1
	charge0 = {}
	for t in s.src:
		charge0[t] = float(s.src[t].get("charge", 1.0))
	for t in s.iso:
		charge0[t] = float(s.iso[t].get("charge", 1.0))
	kpa0 = {}
	for v in s.vessel_cfg:
		kpa0[v] = s.P(v)
	batt_value0 = _batt_value0()
	lazy_k = _lazy_share()


# ---------------------------------------------------------------- what is still in a machine

func _gas_benign(v: String) -> bool:
	var k: String = v.to_lower() + " " + str(game.sys.vessel_cfg.get(v, {}).get("gas", "")).to_lower()
	return k.find("h2") < 0 and k.find("fuel") < 0 and k.find("prop") < 0


func _liq_benign(fv: Dictionary) -> bool:
	return str(fv.get("fluid", "")) in BENIGN_LIQ and not LIQ.look_of(fv) in HARD_LOOKS


# what a whole machine still holds: "" nothing, "batt" "cap" "gas" "liq" something harmless,
# "hard" something that only the hazard mouth takes
func residual(p) -> String:
	var s = game.sys
	if s == null or p == null or p.cls != "equip" or not p.intact:
		return ""
	if p.hazard in Systems.HAZARD_ONLY:
		return "hard"
	var fv: String = s.fluid_in_piece(p)
	if fv != "" and float(s.fvol[fv].amount) > float(s.fvol[fv].get("hazard", 0.02)):
		return "liq" if _liq_benign(s.fvol[fv]) else "hard"
	var gv: String = s.tank_vol(p)
	if gv != "" and not s.vessel_cfg[gv].get("sealed", false):
		var pk: float = s.P(gv)
		if pk > maxf(GAS_LEFT_KPA, 0.05 * float(kpa0.get(gv, pk))):
			if not _gas_benign(gv):
				return "hard" if s.bursts(p) else ""
			return "gas"
	if p.tag != "":
		var e = s.src.get(p.tag, s.iso.get(p.tag))
		if e != null:
			var kd: String = str(e.get("kind", "battery"))
			var ch: float = float(e.get("charge", 0.0))
			if kd == "cap" and ch > CAP_LEFT:
				return "cap"
			if kd == "battery" and ch > BATT_LEFT * float(charge0.get(p.tag, 1.0)) and ch > 0.01:
				return "batt"
	return ""


static func benign(kind: String) -> bool:
	return kind in ["batt", "cap", "gas", "liq"]


# the body's harmless leftover that the equipment mouth would throw out first ("" none, or a hard one)
func body_residual(b) -> String:
	var out := ""
	for p in b.pieces:
		var k := residual(p)
		if k == "hard":
			return ""
		if benign(k) and (out == "" or ["gas", "liq", "cap", "batt"].find(k) < ["gas", "liq", "cap", "batt"].find(out)):
			out = k
	return out


func _lazy_share() -> float:
	var o := 0.0
	var r_old := 0.0
	var r_new := 0.0
	for id in game.world.order:
		var p = game.world.pieces[id]
		if p.cls != "equip" or not p.intact or not p.scope or p.gone:
			continue
		var v: float = float(p.value) * clampf(float(p.cond), 0.0, 1.0)
		var k := residual(p)
		if k == "":
			o += v
		elif benign(k):
			r_new += v
			r_old += v * (0.4 if game.sys.dest_of(p) == "hazard" else 1.0)
	if r_new <= 0.5:
		return 1.0
	return clampf((LAZY_CAP * (o + r_old) - o) / r_new, LAZY_FLOOR, 1.0)


# a machine's leftovers thrown out or drained: it keeps lazy_k of its price (scripts/mishap.gd)
func lazy_cut(p) -> void:
	if lazy_k >= 0.9999 or p == null or p.cls != "equip" or not p.intact:
		return
	var before: float = float(p.value)
	p.value = before * lazy_k
	game.note_loss("dv_leftover", str(p.tag), (before - float(p.value)) * clampf(float(p.cond), 0.0, 1.0))


# ---------------------------------------------------------------- the mouths

# game.on_swallowed, before what the machine held is emptied
func on_intake(b, zone: String, at: Vector2) -> void:
	if not active():
		return
	# a machine's load (hauler, crane, arm): what it took with its leftovers in is neither clean nor a
	# break — the drain rack that empties them comes later (design §7.1)
	var machine: bool = b.has_meta("arm_drop") or b.get_meta("arm", false)
	for p in b.pieces:
		if p.cls != "equip" or not p.scope:
			continue
		var key := str(p.id)
		if counted.has(key):
			continue
		counted[key] = true
		if not p.intact:
			continue
		if zone == "metal":
			brk("furnace")
			continue
		var k := residual(p)
		if (benign(k) and (zone == "hazard" or machine)) or drained_ids.has(key):
			continue            # harmless leftovers taken the hazard way: neither clean nor a break
		var ok: bool = cond0.has(key) and float(cond0[key]) - float(p.cond) <= COND_SLACK + 0.0001 and not mishap_ids.has(key)
		ok = ok and (k == "" or (zone == "hazard" and k == "hard"))
		if zone == "equip" and k == "hard":
			ok = false
		if ok:
			_clean(p, zone, at)
		else:
			brk("dirty")


func _clean(p, zone: String, at: Vector2) -> void:
	combo += 1
	best = maxi(best, combo)
	clean_n += 1
	clean_value += float(p.value)
	var v: float = game.piece_value(p, zone)
	bonus_cash += v * STEP * mini(combo, CAP_N)
	pop_t = game.playtime
	# out in the berth in front of the mouth (`at`), a later one a step further out while the last still shows
	pops.append([at + Vector2(3.2 * Geom.M + randf_range(-6, 6), minf(pops.size(), 3) * 46.0), combo, 0.0])
	var pitch := 1.0 + 0.02 * float(mini(combo, 10) - 1)
	game.sfx.play("ok", Vector2.INF, 0.9, pitch)
	if combo == 5 or combo == 10:
		game.sfx.play("points", Vector2.INF, 0.8)
	queue_redraw()


func brk(_why: String) -> void:
	if combo > 0:
		broke_t = game.playtime
		broke_n = combo
		if game.sfx != null:
			game.sfx.play("deny", Vector2.INF, 0.5)
	combo = 0


# game._dent: one knock of 5 points or more
func on_dent(p, before: float, after: float) -> void:
	if active() and p.cls == "equip" and p.intact and before - after >= BREAK_DENT - 0.0001:
		brk("dent")


func on_cut_equip() -> void:
	if active():
		brk("cut")


func on_incident(kind: String) -> void:
	if active() and kind in MAJOR:
		major = true
		brk("incident")


func on_mishap(p, kind: String, lost: float) -> void:
	mishap_ids[str(p.id)] = kind
	mishaps.append([kind, str(p.tag), snappedf(lost, 1.0)])
	brk("mishap")


# ---------------------------------------------------------------- a battery's charge, fed back (design §2.2)
# The hose tool on a charged battery's terminals (a machine of the ship, loose or not): a feedback lead
# from the drone, the charge drawn out over a few seconds into the port's grid batteries (Career.power5),
# what they cannot take paid at the grid batteries' price. Paid on what the battery held when the ship
# came in, never more (nothing charges it on site, but nothing could then be sold twice).
const BAT_MWH_T := 0.4          # MWh a tonne of a ship's battery pack holds
const BAT_EFF := 0.9
const BAT_PRICE := 600.0        # $/MWh: what the port pays for a battery block's energy (power_supply.gd)
const FEED_S := 5.0             # s a full battery takes to run down
const LEAD_M := 9.0             # m the lead reaches from the drone
var feeds := {}                 # source tag -> {piece}
var batt_grid := 0.0            # MWh fed into the port's grid batteries this job
var batt_cash := 0.0            # $ for what they could not take
var batt_mwh := 0.0             # MWh fed altogether


func batt_mwh_of(p, charge: float) -> float:
	return float(p.mass) * BAT_MWH_T * charge * BAT_EFF


# a battery the lead can be put on: a whole machine of the ship with charge left in it
func feedable(p) -> bool:
	return active() and p != null and not p.gone and residual(p) == "batt"


func feed_toggle(p) -> bool:
	if feeds.has(p.tag):
		feeds.erase(p.tag)
		game.sfx.play("unplug")
		return true
	if not feedable(p):
		return false
	feeds[p.tag] = {"piece": p}
	game.sfx.play("plug")
	game.say("feed_on", game.world.frame(p) * Geom.centroid(p.poly) + Vector2(0, -40))
	return true


func _physics_process(dt: float) -> void:
	var _pt := Time.get_ticks_usec()
	_physics_process_inner(dt)
	prof_us += Time.get_ticks_usec() - _pt


func _physics_process_inner(dt: float) -> void:
	if feeds.is_empty() or game == null or game.paused_sim:
		return
	var s = game.sys
	for tag in feeds.keys():
		var p = feeds[tag].piece
		var e = s.src.get(tag, s.iso.get(tag))
		if p == null or p.gone or e == null or not p.intact:
			feeds.erase(tag)
			continue
		var at: Vector2 = game.world.frame(p) * Geom.centroid(p.poly)
		if at.distance_to(game.drone.global_position) > LEAD_M * Geom.M or not game.drone.alive:
			feeds.erase(tag)
			game.say("feed_off", at + Vector2(0, -40))
			continue
		var c0: float = float(charge0.get(tag, e.charge))
		var ch: float = float(e.charge)
		var take: float = minf(ch, c0 * dt / FEED_S + 0.0001)
		# never paid for more than the battery held at the start
		var paid: float = maxf(0.0, minf(take, ch - maxf(0.0, ch - c0)))
		e.charge = ch - take
		_credit(batt_mwh_of(p, paid))
		if randf() < 0.3:
			game.fx.sparks(at, Vector2.UP, 1, Pal.tint(Pal.VOLT, 1.0, 1.8), 90.0, 0.2, PI)
		if float(e.charge) <= 0.0005:
			feeds.erase(tag)
			game.sfx.play("step_done", at)
			game.say("feed_done", at + Vector2(0, -40), "%.2f" % batt_mwh_of(p, c0))
			game.fx.number(at + Vector2(0, -60), "+%.2f MWh" % batt_mwh_of(p, c0), Charcoal.accent(1.0), 18)
	queue_redraw()


# into the port's grid batteries first, what does not fit for cash
func _credit(mwh: float) -> void:
	if mwh <= 0.0:
		return
	batt_mwh += mwh
	var left := mwh
	if PowerSupply.on():
		var ps: Dictionary = PowerSupply.d()
		for sl in ps.get("slots", []):
			if sl.is_empty() or left <= 0.0:
				continue
			var cap: float = float(PowerSupply.SIZES.get(str(sl.get("size", "")), {}).get("mwh", 0.0))
			var room: float = maxf(0.0, cap - float(sl.get("left", 0.0)))
			var put := minf(room, left)
			sl.left = float(sl.get("left", 0.0)) + put
			batt_grid += put
			left -= put
	batt_cash += left * BAT_PRICE


# the ship's batteries' worth at the start (the leftovers' share of the grade counts them)
func _batt_value0() -> float:
	var v := 0.0
	for id in game.world.order:
		var p = game.world.pieces[id]
		if p.cls == "equip" and p.scope and p.tag != "" and charge0.has(p.tag):
			var e = game.sys.src.get(p.tag, game.sys.iso.get(p.tag))
			if e != null and str(e.get("kind", "battery")) == "battery":
				v += batt_mwh_of(p, float(charge0[p.tag])) * BAT_PRICE
	return v


# ---------------------------------------------------------------- the grade

func clean_share() -> float:
	return clamp(clean_value / base_value, 0.0, 1.0) if base_value > 0.5 else 0.0


# the share of the ship's gas and liquid (by value) recovered; -1 when it had none worth anything
func residual_share() -> float:
	var s = game.sys
	var gv0: float = float(s.cfg.get("gas", {}).get("value", 0.0))
	var fvals: Dictionary = s.cfg.get("fluids", {}).get("value", {})
	var bv0: float = batt_value0
	var tot := gv0 + bv0
	var rec := gv0 * clampf(s.gas_recovered / maxf(s.gas0, 1.0), 0.0, 1.0) + minf(bv0, batt_mwh * BAT_PRICE)
	for f in fvals:
		if float(s.fluid0.get(f, 0.0)) > 0.0:
			tot += float(fvals[f])
			rec += float(fvals[f]) * clampf(float(s.fluid_rec.get(f, 0.0)) / float(s.fluid0[f]), 0.0, 1.0)
	return rec / tot if tot > 1.0 else -1.0


func score() -> float:
	var r := residual_share()
	return clean_share() if r < 0.0 else 0.75 * clean_share() + 0.25 * r


# "S" | "A" | "B" ("" where nothing is graded)
func grade() -> String:
	if not active() or whole_n == 0:
		return ""
	var g := score()
	if g >= S_AT - 0.00001 and not major:
		return "S"
	if g >= A_AT - 0.00001:
		return "A"
	return "B"


func grade_share() -> float:
	match grade():
		"S": return S_BONUS
		"A": return A_BONUS
	return 0.0


func combo_share() -> float:
	return STEP * mini(combo, CAP_N)


# ---------------------------------------------------------------- saving

func to_save() -> Dictionary:
	return {"cond0": cond0, "charge0": charge0, "kpa0": kpa0, "base": base_value, "cv": clean_value, "cn": clean_n, "wn": whole_n,
		"combo": combo, "best": best, "bonus": bonus_cash, "counted": counted, "mishap_ids": mishap_ids, "mishaps": mishaps, "major": major,
		"drained": drained_ids, "bgrid": batt_grid, "bcash": batt_cash, "bmwh": batt_mwh, "bv0": batt_value0, "lazy_k": lazy_k}


func from_save(d: Dictionary) -> void:
	if d.is_empty():
		return
	cond0 = d.get("cond0", cond0)
	charge0 = d.get("charge0", charge0)
	kpa0 = d.get("kpa0", kpa0)
	base_value = float(d.get("base", base_value))
	clean_value = float(d.get("cv", 0.0))
	clean_n = int(d.get("cn", 0))
	whole_n = int(d.get("wn", whole_n))
	combo = int(d.get("combo", 0))
	best = int(d.get("best", 0))
	bonus_cash = float(d.get("bonus", 0.0))
	counted = d.get("counted", {})
	mishap_ids = d.get("mishap_ids", {})
	mishaps = d.get("mishaps", [])
	major = bool(d.get("major", false))
	drained_ids = d.get("drained", {})
	batt_grid = float(d.get("bgrid", 0.0))
	batt_cash = float(d.get("bcash", 0.0))
	batt_mwh = float(d.get("bmwh", 0.0))
	batt_value0 = float(d.get("bv0", batt_value0))
	lazy_k = float(d.get("lazy_k", lazy_k))


# ---------------------------------------------------------------- the plates over the mouth

func _process(dt: float) -> void:
	var _pt := Time.get_ticks_usec()
	_process_inner(dt)
	prof_us += Time.get_ticks_usec() - _pt


func _process_inner(dt: float) -> void:
	if pops.is_empty():
		if not feeds.is_empty():
			queue_redraw()
		return
	for q in pops:
		q[2] += dt
	pops = pops.filter(func(q): return q[2] < 1.9)
	queue_redraw()


func _draw() -> void:
	var _pt := Time.get_ticks_usec()
	_draw_inner()
	prof_us += Time.get_ticks_usec() - _pt
	prof_draw_us += Time.get_ticks_usec() - _pt


func _draw_inner() -> void:
	# the feedback leads: drone to battery, orange, a little slack
	for tag in feeds:
		var p = feeds[tag].piece
		if p == null or p.gone:
			continue
		var a: Vector2 = game.drone.global_position
		var b: Vector2 = game.world.frame(p) * Geom.centroid(p.poly)
		var mid: Vector2 = (a + b) * 0.5 + Vector2(0, 0.3 * a.distance_to(b) * 0.25)
		var pts := PackedVector2Array()
		for i in 17:
			var u := i / 16.0
			pts.append(a.lerp(mid, u).lerp(mid.lerp(b, u), u))
		draw_polyline(pts, Charcoal.accent(0.85), 2.0)
		draw_circle(b, 4.0, Charcoal.accent(1.0))
	if pops.is_empty():
		return
	var z: float = maxf(0.05, game.cam_zoom()) if game.cam != null else 1.0
	if _font == null:
		_font = Fonts.get_font("SemiBold")
	var fb: Font = _font
	for q in pops:
		var t: float = q[2]
		var k_in := Pal.back(clampf(t / 0.22, 0.0, 1.0), 2.2)
		var a := clampf(t / 0.08, 0.0, 1.0) * clampf((1.9 - t) / 0.5, 0.0, 1.0)
		var rise := -26.0 * Pal.ease_out(clampf((t - 0.6) / 1.3, 0.0, 1.0))
		var n: int = int(q[1])
		var label := w("干净", "CLEAN") + ("  ×%d" % n if n >= 2 else "")
		var px := 18
		# shaped once a label (draw_string shapes it again every frame)
		if not _tw_cache.has(label):
			var tl := TextLine.new()
			tl.add_string(label, fb, px)
			_tw_cache[label] = tl
		var tl2: TextLine = _tw_cache[label]
		var tw: float = tl2.get_size().x
		var wd := tw + 50.0
		var ht := 34.0
		var sc := lerpf(0.6, 1.0, k_in) * 1.35 / z
		draw_set_transform(q[0] + Vector2(0, rise / z), 0.0, Vector2(sc, sc))
		var r := Rect2(-wd * 0.5, -ht * 0.5, wd, ht)
		draw_rect(r.grow(2.0), Color(0, 0, 0, 0.55 * a))
		draw_rect(r, Color(Charcoal.FACE, 0.96 * a))
		draw_rect(Rect2(r.position, Vector2(4.0, ht)), Charcoal.accent(a))
		# the tick
		var c0 := r.position + Vector2(16, ht * 0.52)
		# the tick as two plain strokes (a wide antialiased polyline is rebuilt slowly every frame)
		draw_line(c0, c0 + Vector2(5, 5), Charcoal.accent(a), 3.0)
		draw_line(c0 + Vector2(5, 5), c0 + Vector2(14, -7), Charcoal.accent(a), 3.0)
		tl2.draw(get_canvas_item(), r.position + Vector2(38, ht * 0.5 - tl2.get_size().y * 0.5), Color(Charcoal.INK, a))
	draw_set_transform(Vector2.ZERO)
