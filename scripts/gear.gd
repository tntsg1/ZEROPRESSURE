class_name Gear
extends Node2D
# Field gear (G1, design/G1_短循环设计稿_2026-10-21.md): the things a berth owns
# as objects and takes out on a job. Three deployable tools that are put on the
# ship by hand and have to be fetched back, and three drone modules that fall
# off at the crash site when the drone is lost.
#   anchor  a towing anchor shot onto a hull piece; its line runs to a winch on
#           the scrap trough. Once the piece comes free the winch hauls the
#           whole section down into the trough, whatever it weighs. When the
#           section goes into the furnace the anchor is left at the winch post.
#   pump    an independent pump stuck on any wall of a pressurised room, or on a
#           tank or bottle: it draws through its own tap, no port needed. It
#           goes down the mouth with its piece if it is left on it.
#   probe   a monitoring probe left on a test point, a port or a piece: the
#           reading stays live, and a real change is called out on the radio.
#   prop    97 号 (user 2026-10-28, CF-90): a temporary prop stood on the berth floor under a
#           container wall's bay. It takes that bay and every bay outboard of it off the bays
#           inboard (scripts/boxbeam.gd), so those can be emptied first. It is rated PROP_T: past
#           that it bows, and after PROP_GIVE it buckles and is gone, the load back on the wall.
# The catalogue, prices and what unlocks them live here too (static), as does
# what a contract's engineering achievements open (Career.feats).
# State that survives a save: what is carried, what is deployed where, what
# lies dropped, what was lost.

const DEPLOY := ["anchor", "pump", "probe", "prop"]
const MODS := []                  # the drone modules were dropped in G2 (player: no use); PRICE keeps theirs for the refund
const OLD_MODS := ["mod_bumper", "mod_hover", "mod_rack"]
const PRICE := {"anchor": 18000.0, "pump": 14000.0, "probe": 6000.0, "prop": 12000.0, "mod_bumper": 16000.0, "mod_hover": 12000.0, "mod_rack": 20000.0}
# 128 号 第 7 段 (user 2026-11-09 "连范围抓钩一起删"): the achievements Section Separated, Pressure
# Equipment Recovered and the field grapple's are gone. The tools come with learning their method
# (the rigging order, the GR-7 borrow job, the field grapple's borrow job); an old save's entries for
# them stay in Career.data.feats, unread.
const FEATS := []
const REMOVED_FEATS := ["section", "pressure", "field"]
const FEAT_GRANT := {}
const MOD_SLOTS := 3
const DEPLOY_SLOTS := 2
const RACK_EXTRA := 1
const SECTION_T := 6.0            # t: a whole this heavy into a mouth is a section separated
const PRESSURE_KPA := 300.0       # a bottle that started at least this full, delivered whole and safe
const REEL_V := 1.1 * 48.0        # px/s the winch hauls at
const REEL_ACC := 6.0             # 1/s: how hard it steers the load's speed
const PUMP_RATE_ROOM := 7.0       # m²/s of a room, through the pump's tap (a port draws 9)
const PUMP_RATE_VESSEL := 0.16    # of a vessel (a port draws 0.2)
const PROBE_TICK := 0.5           # s between the probe's readings
const DEPLOY_T := 0.7             # s to put a tool on
const PICK_R := 1.1 * 48.0        # px: a dropped thing or a unit this close to the pointer is the target
const DROP_DRIFT := 18.0          # px/s a dropped module drifts off at
const PROP_T := 60.0              # t a prop is rated for (about two full bays of containers)
const PROP_GIVE := 1.5            # s over its rating before it buckles
# how much a probe's reading has to move before it is called out, by reading kind
const PROBE_STEP := {"pressure": 10.0, "volts": 1.0, "fluid": 0.05, "temp": 8.0, "field": 2.0, "bio": 0.05, "o2": 0.03, "sample": 0.03}

var game
var world
var carried: Array = []       # [{type, lent}] deployables on the drone, not yet put down
var mods: Array = []          # [{type, lent}] modules fitted on the drone
var units: Array = []         # deployed: {type, lent, uid, piece, ctrl, local, post, keys, last, t, done}
var drops: Array = []         # lying about: {type, lent, pos, vel}
var lost: Array = []          # gone for good: {type, lent, why}
var sel := 0                  # which carried type the deploy tool has in hand
var hold_mode := false         # lock cable length for intact section handling
var next_uid := 1
var t := 0.0
var hint_said := {}


func _init() -> void:
	z_index = 7
	z_as_relative = false


# ---------------------------------------------------------------- catalogue

static func is_deploy(type: String) -> bool:
	return type in DEPLOY


static func is_mod(type: String) -> bool:
	return type in MODS


static func name_of(type: String) -> String:
	return Txt.t("gear_" + type)


static func price(type: String) -> float:
	return float(PRICE.get(type, 0.0))


# 104 号: the dismantling method a type still needs ("" when it can be bought)
static func locked_by(type: String) -> String:
	var m := Methods.of_gear(type)
	return "" if m == "" or Methods.learned(m) else m


# why it cannot be bought now ("" when it can)
static func reason(type: String) -> String:
	if not PRICE.has(type):
		return Txt.t("gear_unknown")
	var need := locked_by(type)
	if need != "":
		return Txt.t("gear_needs_method") % Methods.name_of(need)
	if float(Career.data.get("money", 0.0)) < price(type):
		return Txt.t("tm_short") % Pal.money(price(type) - float(Career.data.money))
	return ""


# the berth's stock of a type (on the shelf now, not out on the job)
static func stock(type: String) -> int:
	return int(Career.data.get("gear", {}).get(type, 0))


# buy one: into the warehouse, paid now; a failed write leaves the funds alone
static func buy(type: String) -> String:
	var why := reason(type)
	if why != "":
		return why
	var before := Career.data
	Career.data = before.duplicate(true)
	Career.data.money = float(Career.data.money) - price(type)
	var g: Dictionary = Career.data.get("gear", {})
	g[type] = int(g.get(type, 0)) + 1
	Career.data.gear = g
	var desk: Dictionary = Career.data.get("desk", {})
	desk.buy = int(desk.get("buy", 0)) + 1
	Career.data.desk = desk
	if not Career.save():
		Career.data = before
		return Txt.t("gr_save_failed")
	return ""


static func deploy_slots(mod_list: Array) -> int:
	var n := DEPLOY_SLOTS + Port.deploy_bonus()
	for m in mod_list:
		if (m.type if m is Dictionary else str(m)) == "mod_rack":
			n += RACK_EXTRA
	return n


# ---------------------------------------------------------------- on the job

func setup(g) -> void:
	game = g
	hold_mode = bool(g.job.get("rigging_hold",false))
	world = g.world
	if not world.piece_reframed.is_connected(_on_reframed):
		world.piece_reframed.connect(_on_reframed)
	var jg: Dictionary = g.job.get("gear", {})
	for m in jg.get("mods", []):
		mods.append({"type": str(m), "lent": false})
	var dep: Dictionary = jg.get("deploy", {})
	for type in dep:
		for i in int(dep[type]):
			carried.append({"type": str(type), "lent": false})
	var lend: Dictionary = jg.get("lent", {}).duplicate()
	# 97 号: a ship can come with gear lent for it (CF-90: two props)
	for type in g.ship.get("lend", {}):
		lend[type] = maxi(int(lend.get(type, 0)), int(g.ship.lend[type]))
	for type in lend:
		for i in int(lend[type]):
			if is_deploy(str(type)):
				carried.append({"type": str(type), "lent": true})
			else:
				mods.append({"type": str(type), "lent": true})
	# a test can hand the drone gear straight away
	if g.bot != null and g.bot.has("gear"):
		for type in g.bot.gear:
			for i in int(g.bot.gear[type]):
				(mods if is_mod(str(type)) else carried).append({"type": str(type), "lent": false})
	sel = 0


# a piece changed frame (it came loose, or was cut): the spots on it go with it
func _on_reframed(p, t: Transform2D) -> void:
	for u in units:
		if u.piece == p.id:
			u.local = t * u.local


func active() -> bool:
	return not (carried.is_empty() and mods.is_empty() and units.is_empty() and drops.is_empty())


func has_mod(type: String) -> bool:
	for m in mods:
		if m.type == type:
			return true
	return false


# the deployables in hand, by type: {type: count}
func carried_counts() -> Dictionary:
	var out := {}
	for c in carried:
		out[c.type] = int(out.get(c.type, 0)) + 1
	return out


func carried_types() -> Array:
	var out: Array = []
	for c in carried:
		if not c.type in out:
			out.append(c.type)
	return out


# the type the deploy tool has in hand ("" with nothing to put down)
func in_hand() -> String:
	var types := carried_types()
	if types.is_empty():
		return ""
	sel = clampi(sel, 0, types.size() - 1)
	return types[sel]


func cycle() -> String:
	var types := carried_types()
	if types.size() <= 1:
		return in_hand()
	sel = (sel + 1) % types.size()
	return types[sel]


func _take_carried(type: String) -> Dictionary:
	# a lent unit goes first: the berth's own stays in hand for later
	var best := -1
	for i in carried.size():
		if carried[i].type == type and (best < 0 or (carried[i].lent and not carried[best].lent)):
			best = i
	if best < 0:
		return {}
	return carried.pop_at(best)


# ---------------------------------------------------------------- targets

# what the deploy tool can act on at a point: a unit to take back, or where the type in
# hand goes. `ctrl_h` is the control under the pointer (a probe goes on it), `piece_h`
# the piece (an anchor or a pump goes on that, whatever control sits near)
func target(aim: Vector2, ctrl_h: Dictionary, piece_h: Dictionary) -> Dictionary:
	var u := unit_at(aim)
	if not u.is_empty():
		return {"kind": "unit", "unit": u, "pos": unit_pos(u), "d": 0.0, "label": name_of(u.type)}
	var type := in_hand()
	if type == "":
		return {}
	var p = piece_h.get("piece") if piece_h.get("kind", "") == "piece" else null
	match type:
		"anchor":
			if p != null and p.cls != "equip" and not _anchored(p):
				return {"kind": "place", "type": type, "piece": p, "pos": piece_h.pos, "d": 0.0, "label": p.tag}
		"pump":
			if p != null:
				var vol := _pump_vol(p, piece_h.pos)
				if vol != "" and not _pumped(p):
					return {"kind": "place", "type": type, "piece": p, "pos": piece_h.pos, "d": 0.0, "label": p.tag, "vol": vol}
		"prop":
			# under a bay of a container wall: it stands on the floor under that bay's bottom chord
			var bx = game.boxbeam
			if p != null and bx != null and bx.active():
				var bay: int = bx.bay_of(p)
				var chord = world.tag("BC-%d" % (bay + 1)) if bay >= 0 else null
				if bay >= 0 and bay != int(bx.cfg.get("support", 0)) and chord != null and not chord.gone and chord.body == null and _prop_at(bay).is_empty():
					var bb := Geom.bbox(world.world_poly(chord))
					var at := Vector2(clampf(piece_h.pos.x, bb.position.x + 1.0 * Geom.M, bb.end.x - 1.0 * Geom.M), bb.end.y)
					return {"kind": "place", "type": type, "piece": chord, "pos": at, "d": 0.0, "label": ("第 %d 列" if Txt.zh else "BAY %d") % (bay + 1), "bay": bay}
		"probe":
			if ctrl_h.get("kind", "") == "ctrl" and ctrl_h.ctrl.kind in ["port", "test", "discharge", "probe"] and not _probed_ctrl(ctrl_h.ctrl.id):
				return {"kind": "place", "type": type, "ctrl": ctrl_h.ctrl, "pos": ctrl_h.pos, "d": 0.0, "label": ctrl_h.ctrl.id}
			if p != null and not _probed_piece(p):
				return {"kind": "place", "type": type, "piece": p, "pos": piece_h.pos, "d": 0.0, "label": p.tag}
	return {}


# the prop under a bay ({} when none)
func _prop_at(bay: int) -> Dictionary:
	for u in units:
		if u.type == "prop" and int(u.get("bay", -1)) == bay:
			return u
	return {}


func props() -> Array:
	return units.filter(func(u): return u.type == "prop")


# a prop past its rating too long: it buckles and is gone (the wall takes its load back)
func buckle(u: Dictionary) -> void:
	if not units.has(u):
		return
	var at := unit_pos(u)
	units.erase(u)
	lost.append({"type": u.type, "lent": u.lent, "why": "gear_why_buckled"})
	game.incident("prop_buckle", "bay %d" % (int(u.bay) + 1))
	game.say("prop_buckle", at + Vector2(0, -40), str(int(u.bay) + 1))
	game.sfx.play("hull_break", at, 0.8, 1.05)
	game.shake(0.45)
	game.fx.sparks(at, Vector2.UP, 16, Pal.heat(1.0, 2.0), 260.0, 0.4, PI)


func _anchored(p) -> bool:
	for u in units:
		if u.type == "anchor" and u.piece == p.id:
			return true
	return false


func _pumped(p) -> bool:
	for u in units:
		if u.type == "pump" and u.piece == p.id:
			return true
	return false


func _probed_ctrl(id: String) -> bool:
	for u in units:
		if u.type == "probe" and u.ctrl == id:
			return true
	return false


func _probed_piece(p) -> bool:
	for u in units:
		if u.type == "probe" and u.ctrl == "" and u.piece == p.id:
			return true
	return false


# the gas volume (a vessel's, or the room behind a wall) or fluid tank a pump on this piece draws from
func _pump_vol(p, at: Vector2) -> String:
	var s = game.sys
	var tv: String = s.tank_vol(p)
	if tv != "":
		return tv
	if s.fluid_in_piece(p) != "":
		return "fluid:" + s.fluid_in_piece(p)
	if p.body != null:
		return ""
	# a wall: the room on either side of it with pressure in it
	var best := ""
	var bp := 1.0
	var c: Vector2 = world.frame(p) * Geom.centroid(p.poly)
	for n in 12:
		var room: String = world.room_at(c + Vector2.from_angle(TAU * n / 12.0) * 0.8 * Geom.M)
		if room != "" and s.P(room) > bp:
			bp = s.P(room)
			best = room
	if best == "" and p.room != "" and s.P(p.room) > 1.0:
		best = p.room
	return best


func unit_at(aim: Vector2) -> Dictionary:
	var best := {}
	var bd := PICK_R
	for u in units:
		var d := unit_pos(u).distance_to(aim)
		if d < bd:
			bd = d
			best = u
	return best


func drop_at(aim: Vector2) -> Dictionary:
	var best := {}
	var bd := PICK_R
	for d in drops:
		var dd: float = d.pos.distance_to(aim)
		if dd < bd:
			bd = dd
			best = d
	return best


func unit_pos(u: Dictionary) -> Vector2:
	if u.ctrl != "":
		var c = world.ctrls.get(u.ctrl)
		if c != null:
			return world.ctrl_world(c)
	var p = world.pieces.get(u.piece)
	if p != null and not p.gone:
		return world.frame(p) * u.local
	return u.get("post", Vector2.ZERO)


# ---------------------------------------------------------------- deploying and taking back

# the deploy tool's click landed: put the type in hand on the target, or take a unit back
func act(tg: Dictionary) -> void:
	if tg.get("kind", "") == "unit":
		retrieve(tg.unit)
		return
	if tg.get("kind", "") != "place":
		return
	var item := _take_carried(tg.type)
	if item.is_empty():
		return
	var u := {"type": tg.type, "lent": item.lent, "uid": next_uid, "piece": -1, "ctrl": "", "local": Vector2.ZERO, "post": Vector2.ZERO, "keys": [], "last": {}, "t": 0.0, "done": false}
	next_uid += 1
	if tg.has("piece"):
		u.piece = tg.piece.id
		u.local = world.frame(tg.piece).affine_inverse() * tg.pos
	if tg.has("ctrl"):
		u.ctrl = tg.ctrl.id
		var cp = world.pieces.get(tg.ctrl.piece)
		if cp != null:
			u.piece = cp.id
			u.local = world.frame(cp).affine_inverse() * tg.pos
	placed[tg.type] = int(placed.get(tg.type, 0)) + 1
	match tg.type:
		"anchor":
			u.post = Dock.trough_below(tg.pos)
			u.mode = "hold" if hold_mode else "reel"
			u.rest = u.post.distance_to(tg.pos)
		"pump":
			u.vol = tg.vol
			game.sys.taps[u.uid] = _tap_for(u)
		"prop":
			u.bay = int(tg.bay)
			u.post = Vector2(tg.pos.x, maxf(tg.pos.y + 0.6 * Geom.M, Dock.TROUGH_Y * Geom.M))
			u.load = 0.0
			u.over = 0.0
		"probe":
			# the first reading is the operator's own measurement: the probe keeps it live
			var tgm := {"kind": "ctrl", "ctrl": tg.ctrl, "pos": tg.pos} if tg.has("ctrl") else {"kind": "inspect", "piece": tg.piece, "pos": tg.pos}
			var before: Array = game.sys.readings.keys()
			game.do_measure(tgm)
			for k in game.sys.readings:
				if not k in before or _key_of(tgm) == k:
					u.keys.append(str(k))
			for k in u.keys:
				var r: Dictionary = game.sys.readings[k]
				r.live = true
				u.last[k] = float(r.val)
	units.append(u)
	game.log_op("deploy")
	game.sfx.play("hose_on", tg.pos)
	game.fx.ring(tg.pos, 6.0, 40.0, 0.4, Pal.heat(0.9, 1.4), 1.6)
	game.say("gear_placed", tg.pos, name_of(tg.type))
	if tg.type == "anchor":
		_hint("g4_anchor_locked" if u.get("mode","reel") == "hold" else "gear_anchor_set")
		if Career.usable() and not Career.data.is_empty() and not Career.data.get("seen", {}).has("gear_anchor"):
			var seen: Dictionary = Career.data.get("seen", {})
			seen["gear_anchor"] = true
			Career.data.seen = seen
			Copy.say(game.radio, "L_gear_anchor")
	elif tg.type == "pump":
		_hint("gear_pump_set")
	elif tg.type == "prop":
		_hint("gear_prop_set")
	else:
		_hint("gear_probe_set")


func _key_of(tgm: Dictionary) -> String:
	if tgm.kind == "ctrl":
		return str(tgm.ctrl.id)
	return "P:%d" % tgm.piece.id


func _tap_for(u: Dictionary) -> Dictionary:
	var vol: String = u.vol
	if vol.begins_with("fluid:"):
		return {"fluid": vol.substr(6), "vol": "", "rate": 1.0}
	return {"vol": vol, "fluid": "", "rate": PUMP_RATE_VESSEL if game.sys.vessel_cfg.has(vol) else PUMP_RATE_ROOM}


func retrieve(u: Dictionary) -> void:
	if not units.has(u):
		return
	var at := unit_pos(u)
	_unhook(u)
	units.erase(u)
	carried.append({"type": u.type, "lent": u.lent})
	game.log_op("deploy")
	game.sfx.play("unplug", at)
	game.fx.ring(at, 4.0, 26.0, 0.35, Pal.ink(0.8, 1.3))
	game.say("gear_taken", at, name_of(u.type))


# the unit's hold on the ship is undone (its tap, its live readings)
func _unhook(u: Dictionary) -> void:
	match u.type:
		"pump":
			game.sys.taps.erase(u.uid)
		"probe":
			for k in u.keys:
				if game.sys.readings.has(k):
					game.sys.readings[k].erase("live")


# a dropped thing picked up off the floor (the grapple or the deploy tool over it)
func pick(d: Dictionary) -> void:
	if not drops.has(d):
		return
	drops.erase(d)
	(mods if is_mod(d.type) else carried).append({"type": d.type, "lent": d.lent})
	game.sfx.play("grab", d.pos)
	game.fx.ring(d.pos, 4.0, 30.0, 0.35, Pal.ink(0.8, 1.3))
	game.say("gear_picked", d.pos, name_of(d.type))


# the drone is gone: everything on it falls off where it was
func on_drone_destroyed(at: Vector2) -> void:
	var n := 0
	for m in mods + carried:
		var a := randf() * TAU
		drops.append({"type": m.type, "lent": m.lent, "pos": at + Vector2.from_angle(a) * randf_range(10.0, 40.0), "vel": Vector2.from_angle(a) * randf_range(DROP_DRIFT * 0.5, DROP_DRIFT)})
		n += 1
	mods = []
	carried = []
	if n > 0:
		game.say("gear_dropped", at + Vector2(0, -80), str(n))
		_hint("gear_dropped")


# a body went down a mouth: the units on it go with it; a heavy whole is a section separated;
# a bottle that started full, delivered whole to the equipment bay, is pressure equipment recovered
func on_swallowed(b, zone: String) -> void:
	for u in units.duplicate():
		var p = world.pieces.get(u.piece)
		if p == null or not b.pieces.has(p):
			continue
		if u.type == "anchor":
			# the anchor is cast off at the winch post, to be fetched
			_unhook(u)
			units.erase(u)
			drops.append({"type": u.type, "lent": u.lent, "pos": u.post + Vector2(0, -0.6 * Geom.M), "vel": Vector2.ZERO})
			game.say("gear_anchor_off", u.post + Vector2(0, -40))
		else:
			_unhook(u)
			units.erase(u)
			lost.append({"type": u.type, "lent": u.lent, "why": "gear_why_mouth"})
			game.say("gear_lost_mouth", Dock.zpos(zone) + Vector2(0, -50), name_of(u.type))
	# scrap into the furnace (kept for the job's record); equipment delivered whole (precision
	# inspection's, counted over all jobs at settlement)
	if zone == "metal" and b.total_mass() > Methods.FIELD_MIN_T:
		furnace_n += 1
	if zone == "equip":
		for p in b.pieces:
			if p.cls == "equip" and p.intact:
				equip_v += float(p.value)
	# 128 号 第 7 段 (user 2026-11-09): the pressure feat is no longer a full bottle delivered —
	# it is a charged store emptied by an independent pump (_step_pump)


var feats_now := {}           # feat -> the number that earned it, this contract
var placed := {}              # 108 号: units set on the ship this contract, by type (the showcase's count)
var furnace_n := 0            # bodies into the furnace this contract
var equip_v := 0.0            # equipment delivered whole this contract ($)


func _feat(id: String, measure: float) -> void:
	if feats_now.has(id):
		return
	feats_now[id] = measure
	var had: bool = Career.data.get("feats", {}).has(id) if not Career.data.is_empty() else false
	game.sfx.play("ok")
	game.say("feat_new" if not had else "feat_again", game.drone.global_position + Vector2(0, -60), Txt.t("feat_" + id))
	if not had:
		Copy.say(game.radio, "L_feat_first")


# ---------------------------------------------------------------- every step

func _physics_process(dt: float) -> void:
	if game == null or game.state != "play" or game.paused_sim:
		return
	t += dt
	for u in units.duplicate():
		var p = world.pieces.get(u.piece)
		if u.piece >= 0 and (p == null or p.gone):
			# its piece went some way other than a mouth (debris, cut away): the unit is gone with it
			_unhook(u)
			units.erase(u)
			lost.append({"type": u.type, "lent": u.lent, "why": "gear_why_gone"})
			continue
		match u.type:
			"anchor": _step_anchor(u, p, dt)
			"pump": _step_pump(u, p, dt)
			"probe": _step_probe(u, dt)
	for d in drops:
		d.pos += d.vel * dt
		d.vel *= exp(-0.4 * dt)
		var pull: Vector2 = game.dock.field_pull(d.pos)
		if pull != Vector2.ZERO:
			d.vel += pull * dt * 3.0
	# 108 号 帧率: only while its part of the port is in view (scripts/view_cull.gd)
	if ViewCull.sees_zone(game, "salvage", 80.0):
		queue_redraw()


# the winch: the piece still on the ship is only lined; once free, the whole it is in is
# hauled down to the trough at a walking pace, however heavy, and its spin is killed
func _step_anchor(u: Dictionary, p, dt: float) -> void:
	var b = p.body
	if b == null or not is_instance_valid(b) or b.capture != null:
		return
	if game.tools.held_body == b:
		return
	var at := unit_pos(u)
	var to: Vector2 = u.post - at
	var dist := to.length()
	if u.get("mode","reel") == "hold":
		# A locked cable only pulls when taut. There is no positional teleport,
		# freezing, sideways thrust or force from a slack cable.
		var stretch := maxf(0.0,dist-float(u.get("rest",dist)))
		if stretch <= 0.0 or dist < 0.01: return
		var offset: Vector2 = at-b.global_position
		var point_v: Vector2 = b.linear_velocity + Vector2(-offset.y,offset.x)*b.angular_velocity
		var direction := to/dist
		var tension: float = b.total_mass()*clampf(stretch*80.0-point_v.dot(direction)*18.0,0.0,600.0)
		b.apply_force(direction*tension,offset)
		b.settle = 0.0
		return
	if game.auto_paused: return
	if dist < 0.3 * Geom.M:
		return
	var v_des := to.normalized() * REEL_V * Methods.winch_k() * clampf(dist / (1.5 * Geom.M), 0.3, 1.0)
	var m: float = b.total_mass()
	var f: Vector2 = (v_des - b.linear_velocity) * m * REEL_ACC
	b.apply_central_force(f.limit_length(m * 600.0))
	b.angular_velocity *= exp(-2.5 * dt)
	b.settle = 0.0
	# the load is at the trough but the belt will not take it (whole equipment or a hazard on it)
	if dist < 1.2 * Geom.M and not game.dock.is_scrap(b):
		_hint("gear_anchor_not_scrap")


func _step_pump(u: Dictionary, p, dt: float) -> void:
	var tap: Dictionary = game.sys.taps.get(u.uid, {})
	if tap.is_empty():
		game.sys.taps[u.uid] = _tap_for(u)
		return
	var left := 0.0
	if tap.vol != "":
		left = game.sys.P(tap.vol)
	elif tap.fluid != "":
		left = game.sys.fluid(tap.fluid) / maxf(0.001, float(game.sys.fvol[tap.fluid].get("full", game.sys.fvol[tap.fluid].amount)))
	if left < 1.0 * (0.01 if tap.fluid != "" else 1.0) and not u.done:
		u.done = true
		game.say("gear_pump_done", unit_pos(u), name_of("pump"))
		game.sfx.play("ok", unit_pos(u))


func _step_probe(u: Dictionary, dt: float) -> void:
	u.t += dt
	if u.t < PROBE_TICK:
		return
	u.t = 0.0
	var s = game.sys
	for k in u.keys:
		var r = s.readings.get(k)
		if r == null:
			continue
		r.live = true
		s.refresh_reading(r, true)
		var last: float = float(u.last.get(k, r.val))
		var step: float = float(PROBE_STEP.get(r.kind, 1.0))
		if r.kind == "pressure":
			step = maxf(step, absf(last) * 0.15)
		if absf(float(r.val) - last) >= step:
			game.say("gear_probe_change", unit_pos(u) + Vector2(0, -30), "%s  %s" % [r.at, r.text])
			game.sfx.play("warn", unit_pos(u), 0.6)
			# 108 号 Q15: the second tier stops the beam on a real change
			if Methods.level("probe") >= 2 and game.tools != null and game.tools.probe_stop():
				game.say("gear_probe_stop", game.drone.global_position + Vector2(0, -44), "%s  %s" % [r.at, r.text])
			u.last[k] = float(r.val)


func _hint(key: String) -> void:
	if hint_said.has(key):
		return
	hint_said[key] = true
	game.hud.show_hint(Txt.t("hint_" + key))


# ---------------------------------------------------------------- the end of the contract

# what is still out on the ship when the job ends is lost
func settlement_report() -> Dictionary:
	var result := report()
	for u in units:
		result.lost.append({"type":u.type,"lent":u.lent,"why":"gear_why_left"})
	for d in drops:
		result.lost.append({"type":d.type,"lent":d.lent,"why":"gear_why_dropped"})
	return result


func finalize() -> void:
	for u in units:
		_unhook(u)
		lost.append({"type": u.type, "lent": u.lent, "why": "gear_why_left"})
	units = []
	for d in drops:
		lost.append({"type": d.type, "lent": d.lent, "why": "gear_why_dropped"})
	drops = []


# for the books: what came back, what did not, what was achieved
func report() -> Dictionary:
	var back: Array = []
	for m in mods + carried:
		back.append({"type": m.type, "lent": m.lent})
	return {"back": back, "lost": lost.duplicate(true), "feats": feats_now.duplicate(), "equip_v": equip_v}


# ---------------------------------------------------------------- saving

func save_state() -> Dictionary:
	var us: Array = []
	for u in units:
		var d: Dictionary = u.duplicate(true)
		d.local = [u.local.x, u.local.y]
		d.post = [u.post.x, u.post.y]
		us.append(d)
	var ds: Array = []
	for d in drops:
		ds.append({"type": d.type, "lent": d.lent, "pos": [d.pos.x, d.pos.y], "vel": [d.vel.x, d.vel.y]})
	return {"carried": carried.duplicate(true), "mods": mods.duplicate(true), "units": us, "drops": ds, "lost": lost.duplicate(true),
		"sel": sel, "hold_mode":hold_mode, "uid": next_uid, "feats": feats_now.duplicate(), "hints": hint_said.keys(), "furnace_n": furnace_n, "equip_v": equip_v}


func load_state(d: Dictionary) -> void:
	carried = []
	for c in d.get("carried", []):
		carried.append({"type": str(c.type), "lent": bool(c.lent)})
	mods = []
	for m in d.get("mods", []):
		mods.append({"type": str(m.type), "lent": bool(m.lent)})
	units = []
	for ud in d.get("units", []):
		var u := {"type": str(ud.type), "lent": bool(ud.lent), "uid": int(ud.uid), "piece": int(ud.piece), "ctrl": str(ud.ctrl),
			"local": Vector2(float(ud.local[0]), float(ud.local[1])), "post": Vector2(float(ud.post[0]), float(ud.post[1])),
			"keys": ud.get("keys", []), "last": ud.get("last", {}), "t": 0.0, "done": bool(ud.get("done", false))}
		if ud.has("vol"):
			u.vol = str(ud.vol)
		if ud.has("mode"): u.mode = str(ud.mode)
		if ud.has("bay"):
			u.bay = int(ud.bay)
			u.load = float(ud.get("load", 0.0))
			u.over = float(ud.get("over", 0.0))
		if ud.has("rest"): u.rest = float(ud.rest)
		var p = world.pieces.get(u.piece)
		if u.piece >= 0 and (p == null or p.gone):
			lost.append({"type": u.type, "lent": u.lent, "why": "gear_why_gone"})
			continue
		if u.type == "pump":
			game.sys.taps[u.uid] = _tap_for(u)
		elif u.type == "probe":
			for k in u.keys:
				if game.sys.readings.has(k):
					game.sys.readings[k].live = true
		units.append(u)
	drops = []
	for dd in d.get("drops", []):
		drops.append({"type": str(dd.type), "lent": bool(dd.lent), "pos": Vector2(float(dd.pos[0]), float(dd.pos[1])), "vel": Vector2(float(dd.vel[0]), float(dd.vel[1]))})
	lost = []
	for l in d.get("lost", []):
		lost.append({"type": str(l.type), "lent": bool(l.lent), "why": str(l.why)})
	sel = int(d.get("sel", 0))
	hold_mode = bool(d.get("hold_mode",false))
	next_uid = int(d.get("uid", 1))
	feats_now = d.get("feats", {})
	# a job saved before 128 号 第 7 段 may carry a removed achievement: dropped without a word
	for f in REMOVED_FEATS:
		feats_now.erase(f)
	furnace_n = int(d.get("furnace_n", 0))
	equip_v = float(d.get("equip_v", 0.0))
	for h in d.get("hints", []):
		hint_said[str(h)] = true
	queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if game == null or world == null:
		return
	var z: float = game.cam_zoom()
	var lw := 1.4 / z
	for u in units:
		var at := unit_pos(u)
		var col := Pal.heat(0.9, 1.3) if u.lent else Pal.ink(0.9, 1.2)
		match u.type:
			"anchor":
				# the line to the winch post, and the post
				draw_line(at, u.post, Pal.heat(0.55, 1.2), lw * 1.6, true)
				draw_rect(Rect2(u.post - Vector2(8, 4) / z, Vector2(16, 8) / z), Pal.ink(0.7), false, lw)
				if u.get("mode","reel") == "hold":
					draw_arc(u.post+Vector2(0,-7)/z,4.0/z,PI,TAU,10,Pal.ink(0.85),lw)
					draw_rect(Rect2(u.post+Vector2(-5,-7)/z,Vector2(10,7)/z),Pal.ink(0.85),false,lw)
				for i in 3:
					var a := TAU * i / 3.0 + PI * 0.5
					draw_line(at, at + Vector2.from_angle(a) * 9.0 / z, col, lw * 1.5)
				draw_circle(at, 3.0 / z, col)
			"pump":
				draw_rect(Rect2(at - Vector2(7, 5) / z, Vector2(14, 10) / z), col, false, lw)
				var k := fmod(t * 2.0, 1.0)
				draw_arc(at, (3.0 + 4.0 * k) / z, 0.0, TAU, 16, Pal.tint(Pal.FLUID, 0.9 * (1.0 - k), 1.3), lw, true)
				if u.done:
					draw_line(at + Vector2(-4, 0) / z, at + Vector2(-1, 3) / z, Pal.tint(Pal.FLUID, 0.95, 1.4), lw * 1.4)
					draw_line(at + Vector2(-1, 3) / z, at + Vector2(5, -3) / z, Pal.tint(Pal.FLUID, 0.95, 1.4), lw * 1.4)
			"prop":
				_draw_prop(u, at, z, lw)
			"probe":
				var pulse := 0.6 + 0.4 * sin(t * 4.0)
				draw_arc(at, 6.0 / z, 0.0, TAU, 16, col, lw, true)
				draw_circle(at, 2.0 / z * pulse + 1.0 / z, Pal.heat(pulse, 1.5))
	for d in drops:
		var p: Vector2 = d.pos
		var col2 := Pal.heat(0.9, 1.4) if d.lent else Pal.ink(0.95, 1.4)
		var pulse2 := 0.7 + 0.3 * sin(t * 5.0)
		draw_arc(p, 8.0 / z * pulse2, 0.0, TAU, 16, col2, lw, true)
		draw_rect(Rect2(p - Vector2(4, 4) / z, Vector2(8, 8) / z), col2, false, lw)


# 97 号: a screw-jack prop from the floor to the chord: its base plate, the outer tube, the screw
# and its head; it bows sideways as it goes over its rating; its load beside it, a fixed size
func _draw_prop(u: Dictionary, top: Vector2, z: float, lw: float) -> void:
	var base: Vector2 = u.post
	var k := clampf(float(u.get("load", 0.0)) / Methods.prop_t(), 0.0, 2.0)
	var bow := clampf(float(u.get("over", 0.0)) / Methods.prop_give(), 0.0, 1.0)
	var col := Pal.heat(0.95, 1.4) if k > 1.0 else (Pal.heat(0.75, 1.1) if k > 0.85 else Pal.ink(0.9, 1.15))
	var h := base.y - top.y
	var w := 0.35 * Geom.M
	# base plate and head plate
	draw_rect(Rect2(base + Vector2(-w * 1.6, -0.12 * Geom.M), Vector2(w * 3.2, 0.12 * Geom.M)), Color(0.08, 0.085, 0.095), true)
	draw_rect(Rect2(base + Vector2(-w * 1.6, -0.12 * Geom.M), Vector2(w * 3.2, 0.12 * Geom.M)), col, false, lw)
	draw_rect(Rect2(top + Vector2(-w * 1.3, 0), Vector2(w * 2.6, 0.1 * Geom.M)), col, false, lw)
	# the column: two tubes, bowed by the overload (a sine across its height)
	var pts_l := PackedVector2Array()
	var pts_r := PackedVector2Array()
	for i in 9:
		var f := i / 8.0
		var off := sin(f * PI) * bow * 0.5 * Geom.M
		var y := base.y - 0.12 * Geom.M - f * (h - 0.22 * Geom.M)
		var half := w * (1.0 if f < 0.55 else 0.6)
		pts_l.append(Vector2(base.x - half + off, y))
		pts_r.append(Vector2(base.x + half + off, y))
	draw_polyline(pts_l, col, lw * 1.3)
	draw_polyline(pts_r, col, lw * 1.3)
	# the screw's threads in the upper half, the crank pin at the collar
	for i in 5:
		var f2 := 0.6 + i * 0.07
		var yy := base.y - 0.12 * Geom.M - f2 * (h - 0.22 * Geom.M)
		var o2 := sin(f2 * PI) * bow * 0.5 * Geom.M
		draw_line(Vector2(base.x - w * 0.6 + o2, yy), Vector2(base.x + w * 0.6 + o2, yy - 0.05 * Geom.M), Pal.ink(0.5), lw)
	var cy := base.y - 0.12 * Geom.M - 0.55 * (h - 0.22 * Geom.M)
	draw_line(Vector2(base.x - w * 1.8, cy), Vector2(base.x + w * 1.8, cy), col, lw * 1.2)
	# the load, by it
	var font: Font = game.hud.font if game.hud != null else ThemeDB.fallback_font
	var txt := "%s %.0f / %.0f t" % ["撑杆" if Txt.zh else "PROP", float(u.get("load", 0.0)), Methods.prop_t()]
	var sk := 1.0 / maxf(z, 0.05)
	draw_set_transform(Vector2(base.x + w * 2.4, cy), 0.0, Vector2(sk, sk))
	draw_string_outline(font, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0.02, 0.022, 0.028, 0.85))
	draw_string(font, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
	draw_set_transform(Vector2.ZERO)

