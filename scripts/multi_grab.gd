extends RefCounted
const Crew = preload("res://scripts/crew.gd")
# 87-3: the grapple's range mode. X switches the grapple between one piece (as before) and a
# field round the pointer that takes hold of several loose pieces at once; Shift+X lifts the
# guard that keeps it off precision equipment, hazards and the ship's core assets. It takes any
# material (user 2026-10-27: a mixed mechanical and field grip, not magnetism alone).
#   Only loose pieces: nothing still fixed to the ship, nothing a mouth is already swallowing, no
#   piece an arm or a hauler has. Up to its count, nearest first, within its radius.
#   Each piece stays a body of its own: its own mass, collisions and inertia. The field pulls each
#   towards where it sat in the group when caught (its offset from the group's centre of mass,
#   carried with the tether's target), so the group keeps its layout, bumps through doorways
#   piece by piece, and each piece meets a recovery mouth by itself (each mouth judges each piece).
#   Its load: the field's power goes as the mass held. Over its rating it overloads: the pull is
#   shared out thinner (slower, swingier) and the field reads red; past half again it cannot hold
#   the farthest pieces and lets them go one by one.
#   An upgrade (Growth "grapple_multi"): none fitted, it is not there; each volume more pieces, a
#   wider field, more mass, a steadier hold.

const RADIUS := [0.0, 2.5, 3.5, 4.5]        # m, by volume
const MASS_K := [0.0, 1.0, 1.25, 1.5]       # x the single grapple's mass limit
const STEADY := [1.0, 1.0, 1.12, 1.25]      # damping on top of the grapple's own
const MW_PER_T := 0.06                      # the field's draw per tonne held
const MW_BASE := 0.04
const K := 22.0                             # 1/s²: the field's spring, per piece
const DROP_OVER := 1.5                      # of the rating: past this the far pieces slip

var tools
var game
var world
var on := false                 # range mode
var guard := true               # keeps off precision kit, hazards, core assets
# 108 号 Q15 (the field grapple's second tier is an ability, not a number): it can pick by what a
# piece is — "all", "steel" (loose steel and armour, no whole machine) or "equip" (whole machines)
var pick := "all"
const PICKS := ["all", "steel", "equip"]
var held: Array = []            # [{"body", "off": Vector2 (world, from the group's centre)}]
var overload := 0.0             # 0..: how far over the rating
var force := 0.0                # 0..1 of the field's pull in use (the hiss)


func setup(t) -> void:
	tools = t
	game = t.game
	world = t.world


func level() -> int:
	if game == null:
		return 0
	return maxi(0, [0, 4, 7, 11].find(int(round(game.skill_value("grapple_multi")))))


func fitted() -> bool:
	return level() > 0


func count() -> int:
	return [0, 4, 7, 11][level()]


func radius() -> float:
	return float(RADIUS[level()]) * Geom.M


func mass_cap() -> float:
	return float(MASS_K[level()]) * float(game.grab_max())


func mass_held() -> float:
	var m := 0.0
	for h in held:
		if is_instance_valid(h.body):
			m += float(h.body.total_mass())
	return m


func power_mw() -> float:
	return MW_BASE + MW_PER_T * mass_held() if not held.is_empty() else 0.0


func rated_mw() -> float:
	return MW_BASE + MW_PER_T * mass_cap()


# switch mode (X); the guard (Shift+X)
func toggle() -> bool:
	if not fitted():
		return false
	on = not on
	if not on:
		release(false)
	return true


func toggle_guard() -> void:
	guard = not guard


# the second tier and up picks by material
func can_pick() -> bool:
	return fitted() and level() >= 2


# X with the field on: the next pick; past the last, the field goes off. False: it went off
func next_pick() -> bool:
	var i := PICKS.find(pick) + 1
	if i >= PICKS.size():
		pick = "all"
		on = false
		release(false)
		return false
	pick = PICKS[i]
	release(false)
	return true


func picks(b) -> bool:
	match pick:
		"steel":
			for p in b.pieces:
				if (p.cls == "equip" and p.intact) or not Mat.id_of(p) in ["steel", "armor"]:
					return false
			return true
		"equip":
			return b.pieces.any(func(p): return p.cls == "equip" and p.intact)
	return true


# a precision unit, a hazard, a core asset: kept out unless the guard is off
func guarded(b) -> bool:
	for p in b.pieces:
		if p.hazard != "":
			return true
		if p.cls == "equip" and p.intact and (p.fragile >= 0.5 or p.value >= 15000.0 or p.mandatory):
			return true
	return false


# why it is guarded, as the Txt key said by the pointer ("" when it is not): the branches of guarded()
func guard_reason(b) -> String:
	for p in b.pieces:
		if p.hazard != "":
			return "as_mg_guard_hazard"
	for p in b.pieces:
		if p.cls == "equip" and p.intact:
			if p.value >= 15000.0:
				return "as_mg_guard_value"
			if p.fragile >= 0.5:
				return "as_mg_guard_fragile"
			if p.mandatory:
				return "as_mg_guard_keep"
	return ""


# what the field would take if caught now at this point: [[body, reason ""], ...] nearest first
func candidates(at: Vector2) -> Array:
	var out: Array = []
	if not fitted():
		return out
	var r := radius()
	for b in world.bodies:
		if not is_instance_valid(b) or b.pieces.is_empty():
			continue
		var com: Vector2 = b.global_transform * b.center_of_mass
		if com.distance_to(at) > r:
			continue
		var why := ""
		if b.capture != null:
			why = "swallowing"
		elif b.get_meta("arm", false) or b.has_meta("hauled_by") or Crew.owns(b, true):
			why = "busy"
		elif guard and guarded(b):
			why = "guarded"
		elif pick != "all" and not picks(b):
			why = "filtered"
		out.append([b, why, com.distance_to(at)])
	out.sort_custom(func(a, b): return a[2] < b[2])
	return out


# catch: the nearest free ones, up to the count, while the mass stays within half again the rating
func grab(at: Vector2) -> int:
	release(false)
	var m := 0.0
	var cap := mass_cap() * DROP_OVER
	for c in candidates(at):
		if c[1] != "" or held.size() >= count():
			continue
		var bm: float = c[0].total_mass()
		if m + bm > cap and not held.is_empty():
			continue
		held.append({"body": c[0]})
		m += bm
	if held.is_empty():
		return 0
	var centre := _centre()
	for h in held:
		h.off = (h.body.global_transform * h.body.center_of_mass) - centre
		h.body.tethered = true
	return held.size()


func _centre() -> Vector2:
	var s := Vector2.ZERO
	var m := 0.0
	for h in held:
		if not is_instance_valid(h.body):
			continue
		var bm: float = maxf(0.01, h.body.total_mass())
		s += (h.body.global_transform * h.body.center_of_mass) * bm
		m += bm
	return s / maxf(m, 0.0001)


func release(thrown: bool) -> void:
	for h in held:
		var b = h.body
		if not is_instance_valid(b):
			continue
		b.tethered = false
		b.set_meta("hauled", true)
		if not thrown:
			b.settle = FreeBody.SETTLE_T
	held = []
	overload = 0.0
	force = 0.0


# each piece pulled to its place in the group round the tether's target; the field shared out
func step(dt: float, target: Vector2) -> void:
	# pieces gone, swallowed or out of reach drop out of the field
	var reach_max: float = tools.reach(3) * 1.35
	var keep: Array = []
	for h in held:
		var b = h.body
		if not is_instance_valid(b) or b.pieces.is_empty() or b.capture != null or b.get_meta("arm", false) or Crew.owns(b, true):
			continue
		if (b.global_transform * b.center_of_mass).distance_to(tools.drone.global_position) > reach_max:
			b.tethered = false
			continue
		keep.append(h)
	held = keep
	if held.is_empty():
		overload = 0.0
		force = 0.0
		return
	var m := mass_held()
	var cap := mass_cap()
	overload = maxf(0.0, m / maxf(cap, 0.001) - 1.0)
	# past half again its rating the farthest piece slips
	if m > cap * DROP_OVER and held.size() > 1:
		var far := 0
		var fd := -1.0
		for i in held.size():
			var d: float = (held[i].body.global_transform * held[i].body.center_of_mass).distance_to(target)
			if d > fd:
				fd = d
				far = i
		var lost = held[far].body
		lost.tethered = false
		lost.settle = FreeBody.SETTLE_T
		held.remove_at(far)
		game.sfx.play("release", lost.global_position, 0.8, 0.8)
	# the pull each piece gets: the grapple's force shared by mass, thinner when overloaded
	var share := 1.0 / (1.0 + overload)
	var stable: float = game.skill_value("grapple_stable") * float(STEADY[level()])
	var fmax: float = tools.FMAX * maxf(1.0, game.grab_max() / 5.0) * game.skill_value("haul_speed")
	var total := Vector2.ZERO
	var used := 0.0
	for h in held:
		var b = h.body
		var bm: float = maxf(0.05, b.total_mass())
		var com: Vector2 = b.global_transform * b.center_of_mass
		var goal: Vector2 = target + h.off
		var c := 2.0 * 0.7 * sqrt(K * bm) * stable
		var f: Vector2 = ((goal - com) * K * bm - (b.linear_velocity - tools.drone.linear_velocity) * c) * share
		var cap_b := fmax * (bm / maxf(m, 0.01)) * 1.6
		f = f.limit_length(cap_b)
		used += f.length() / maxf(fmax, 0.001)
		b.apply_central_force(f)
		b.angular_velocity *= exp(-2.0 * stable * dt)
		total += f
	force = clampf(used, 0.0, 1.0)
	# the field pulls back on the drone, the way one load does
	var heavy := clampf(m / maxf(game.grab_max(), 0.001), 0.2, 1.0)
	tools.drone.external -= total.limit_length(Drone.ACCEL * tools.drone.mass * 0.2 * heavy) / stable


func holding() -> bool:
	return not held.is_empty()
