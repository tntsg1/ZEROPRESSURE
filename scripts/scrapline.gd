extends RefCounted
# The pre-processing line between the scrap mouth and the furnace (player
# 2026-10-20: "a part goes in, and below you see a small copy of it: the shredder
# grinds it to powder, then it melts into liquid iron"; "the press really has to
# squash a tonne of plate into a puck"). The mouth still takes the scrap at once
# and pays for it; this is what happens to it afterwards, shown with the part's
# own outline:
#   a diverter sends plate (hull, deck, bulkhead, hatch, door) to a baling press:
#   the lid ram squashes it down, the side ram across, the end gate opens and a
#   puck about 5.5 t/m³ rolls out to the furnace's bunker;
#   everything else goes to a twin-shaft shredder whose counter-rotating hook teeth
#   bite the part in from below, a hammer mill beats the pieces through a 25 mm
#   screen, and a magnetic drum keeps the iron (a vibrating pan feeds it into the
#   furnace) and throws the aluminium and copper off into a bin of their own
#   (Jev A 0.94 / 0.91).
# Nothing here holds anything up: the line runs faster when it falls behind.
# Geometry in metres from the furnace axis X and the floor line F (y down).

const M := 48.0
const PLATE_KINDS := ["hull", "plate", "deck", "bulkhead", "hatch", "door"]
const PUCK_RHO := 5.5          # t/m³ of a pressed puck
const DEPTH := 0.6             # m: the press box's depth (into the screen)
const NONFERROUS := 0.06       # share of shredded scrap the drum throws off
const PRESS_T := [0.8, 2.0, 2.4, 0.8, 0.9, 0.65, 1.8, 1.8] # load/down/across/hold/unload/gate/eject/return
const PRESS_X0 := -9.0         # the press box's inside
const PRESS_X1 := -4.9
const PRESS_Y0 := 2.05
const PRESS_Y1 := 3.95
const ROT_Y := 2.95            # the shredder's rotor shafts
const ROT_L := 4.6
const ROT_R := 5.4
const ROT_RAD := 0.38
const MILL := Vector2(5.0, 4.3)
const MILL_R := 0.62
const DRUM := Vector2(5.0, 5.35)
const DRUM_R := 0.28

var X := 21.0
var quiet := false            # the district's works: big names only, no read-out plate (36 号)
var floor_y := NAN            # m: the line's floor where it is not the berth's (process_plant.gd)
var game
var smelter
var t := 0.0
var arriving: Array = []      # items on their way from the mouth: {item, t, dur, from}
var press_q: Array = []
var shred_q: Array = []
var press = null              # the item in the press: {polys, w, h, mass, s, ph, pt, seed}
var shred = null              # the item in the shredder
var pucks: Array = []         # [x (m), mass, w, h]: on the rollers to the bunker
var frags: Array = []         # [pos, vel, rot, spin, size, stage, life]: shredder pieces into the mill
var fines: Array = []         # [pos, vel, ferrous, stage, a]: powder through the screen
var divert := 0.0             # the diverter's flap: -1 to the press, +1 to the shredder
var divert_goal := 0.0
var force := 0.0              # kN on the press's main cylinder
var torque := 0.0             # kN·m on the shredder's shafts
var pucks_made := 0
var shredded := 0.0
var ferrous := 0.0
var nonferrous := 0.0
var lid_y := PRESS_Y0
var side_x := PRESS_X0
var out_gate := 0.0
var rotor_angle := 0.0
var rotor_speed := 1.2
var mill_angle := 0.0
var mill_speed := 0.0
var drum_angle := 0.0
var separated_t := 0.0
var probe_flow_mass := 0.0
var parcel_no := 0
var drive_rate := 1.0
var company_mode := false
var company_powered := false
var company_id := ""
var company_input := 0.0
var company_nonferrous_share := 0.0
var company_fe := 0.0
var company_nf := 0.0
var company_released_fe := 0.0
var company_released_nf := 0.0
var company_energy_j := 0.0
var company_running_s := 0.0
var company_rng := RandomNumberGenerator.new()
const COMPANY_WATTS := 240000.0 # drive input, provisional equipment rating
const COMPANY_FIELDS := ["t","arriving","press_q","shred_q","press","shred","pucks","frags","fines","divert","divert_goal","force","torque","pucks_made","shredded","ferrous","nonferrous","lid_y","side_x","out_gate","rotor_angle","rotor_speed","mill_angle","mill_speed","drum_angle","separated_t","probe_flow_mass","parcel_no","drive_rate","company_mode","company_powered","company_id","company_input","company_nonferrous_share","company_fe","company_nf","company_released_fe","company_released_nf","company_energy_j","company_running_s"]

func _random() -> float: return company_rng.randf() if company_mode else randf()
func _range(a: float,b: float) -> float: return lerpf(a,b,_random())
func _seed_number() -> int: return company_rng.randi()%1000 if company_mode else randi()%1000
func in_process_mass() -> float:
	var total := waiting_mass()
	if press != null and not press.sent: total += float(press.mass)
	if shred != null: total += float(shred.mass)*(1.0-float(shred.made)/26.0)
	for fragment in frags: total += float(fragment[7])
	for fine in fines: total += float(fine[5])
	for puck in pucks: total += float(puck[1])
	return total

func begin_company(identity: String,polys: Array,mass: float,nonmagnetic_share: float,seed_value: int) -> bool:
	if identity == "" or not is_finite(mass) or mass <= 0.0 or not is_finite(nonmagnetic_share) or nonmagnetic_share < 0.0 or nonmagnetic_share > 1.0: return false
	if in_process_mass() > 0.000001 or company_fe+company_nf > 0.000001: return false
	if polys.is_empty(): return false
	for poly in polys:
		if not poly is PackedVector2Array or poly.size()<3: return false
		for point in poly:
			if not point.is_finite(): return false
		if Geometry2D.triangulate_polygon(poly).is_empty(): return false
	company_mode = true
	company_powered = false
	company_id = identity
	company_input = mass
	company_nonferrous_share = nonmagnetic_share
	company_fe = 0.0
	company_nf = 0.0
	company_released_fe = 0.0
	company_released_nf = 0.0
	company_energy_j = 0.0
	company_running_s = 0.0
	company_rng.seed = seed_value
	# Mixed metal must pass the shredder and actual separator, never the plate
	# bypass which was only designed for known structural ferrous plates.
	take(polys,mass,["company_mixed"],X)
	return true

func company_complete() -> bool:
	return company_mode and company_input > 0.0 and in_process_mass() <= 0.000001 and absf(company_fe+company_nf+company_released_fe+company_released_nf-company_input) < 0.000001

func claim_company(ferromagnetic: bool,amount: float) -> bool:
	if not company_complete() or not is_finite(amount) or amount <= 0.0: return false
	var available := company_fe if ferromagnetic else company_nf
	if absf(available-amount) > 0.000001: return false
	if ferromagnetic:
		company_fe = 0.0
		company_released_fe += amount
	else:
		company_nf = 0.0
		company_released_nf += amount
	return true

func company_snapshot() -> Dictionary:
	if not company_mode: return {}
	var result := {"version":2,"rng":str(company_rng.state)}
	for field in COMPANY_FIELDS: result[field] = _pack(get(field))
	return result

static func _pack(value):
	if value is Vector2: return {"$v2":[value.x,value.y]}
	if value is Vector3: return {"$v3":[value.x,value.y,value.z]}
	if value is PackedVector2Array: return {"$poly":Array(value).map(func(point):return [point.x,point.y])}
	if value is Array: return value.map(func(entry):return _pack(entry))
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = _pack(value[key])
		return result
	return value

static func _unpack(value,depth: int = 0) -> Array:
	if depth > 16: return [false,null]
	if value is float or value is int: return [is_finite(float(value)),value]
	if value == null or value is String or value is bool: return [true,value]
	if value is Array:
		if value.size() > 10000: return [false,null]
		var result: Array = []
		for entry in value:
			var decoded := _unpack(entry,depth+1)
			if not decoded[0]: return [false,null]
			result.append(decoded[1])
		return [true,result]
	if not value is Dictionary: return [false,null]
	for tag in ["$v2","$v3","$poly"]:
		if not value.has(tag): continue
		if value.size() != 1 or not value[tag] is Array: return [false,null]
		var parts: Array = value[tag]
		if tag == "$poly":
			if parts.size() > 1024: return [false,null]
			var poly := PackedVector2Array()
			for point in parts:
				if not point is Array or point.size() != 2: return [false,null]
				for number in point:
					if not (number is float or number is int) or not is_finite(float(number)): return [false,null]
				poly.append(Vector2(float(point[0]),float(point[1])))
			return [true,poly]
		if parts.size() != (2 if tag == "$v2" else 3): return [false,null]
		for number in parts:
			if not (number is float or number is int) or not is_finite(float(number)): return [false,null]
		return [true,Vector2(parts[0],parts[1]) if tag == "$v2" else Vector3(parts[0],parts[1],parts[2])]
	var result := {}
	for key in value:
		var decoded := _unpack(value[key],depth+1)
		if not decoded[0]: return [false,null]
		result[key] = decoded[1]
	return [true,result]

func restore_company(snapshot: Dictionary) -> bool:
	# Validate on an isolated instance before touching the live mechanism. No
	# global RNG is sampled by decoding or reconstructing this private stream.
	if int(snapshot.get("version",0)) not in [1,2] or not str(snapshot.get("rng","")).is_valid_int(): return false
	var saved := snapshot.duplicate(true)
	if int(saved.version) == 1 and not saved.has("company_running_s"):
		if not _numeric_fields(saved,["company_energy_j"]) or float(saved.company_energy_j)<0.0: return false
		saved.company_running_s = float(saved.company_energy_j)/COMPANY_WATTS
	var candidate = get_script().new()
	for field in COMPANY_FIELDS:
		if not saved.has(field): return false
		var decoded := _unpack(saved[field])
		if not decoded[0]: return false
		var prototype = candidate.get(field)
		var value = decoded[1]
		if prototype is float or prototype is int:
			if not (value is float or value is int): return false
		elif prototype != null and typeof(prototype) != typeof(value): return false
		elif field in ["press","shred"] and value != null and not value is Dictionary: return false
		candidate.set(field,value)
	if not candidate._valid_company(): return false
	for field in COMPANY_FIELDS: set(field,candidate.get(field))
	company_rng.state = int(str(snapshot.rng))
	return true

static func _numeric_fields(value: Dictionary,fields: Array) -> bool:
	for field in fields:
		if not value.has(field) or not (value[field] is float or value[field] is int) or not is_finite(float(value[field])): return false
	return true

func _valid_company() -> bool:
	if not company_mode or company_id == "" or company_input <= 0.0 or company_nonferrous_share < 0.0 or company_nonferrous_share > 1.0: return false
	for amount in [company_fe,company_nf,company_released_fe,company_released_nf,company_energy_j]:
		if amount < 0.0: return false
	if company_running_s < 0.0 or absf(company_energy_j-company_running_s*COMPANY_WATTS)>0.1: return false
	if company_fe+company_released_fe > company_input*(1.0-company_nonferrous_share)+0.000001 or company_nf+company_released_nf > company_input*company_nonferrous_share+0.000001: return false
	# Company mode admits one shredded batch, not legacy pressing work.
	if press != null or not press_q.is_empty() or not pucks.is_empty(): return false
	var items: Array = shred_q.duplicate()
	for arrival in arriving:
		if not arrival is Dictionary or not arrival.has_all(["item","t","dur","from"]): return false
		if not _numeric_fields(arrival,["t","dur","from"]): return false
		if not arrival.item is Dictionary or float(arrival.dur) <= 0.0 or float(arrival.t) < 0.0: return false
		items.append(arrival.item)
	if shred != null:
		if not shred.has_all(["s","y","pt","made","bit_acc"]): return false
		if not _numeric_fields(shred,["s","y","pt","made","bit_acc"]): return false
		if float(shred.made) < 0.0 or float(shred.made) > 26.0: return false
		items.append(shred)
	if items.size() > 1: return false
	for item in items:
		if not item is Dictionary or not item.has_all(["polys","mass","route","w","h","seed","dirty"]): return false
		if not _numeric_fields(item,["mass","w","h","seed","dirty"]): return false
		if item.route != "shred" or float(item.mass) <= 0.0 or float(item.w) <= 0.0 or float(item.h) <= 0.0 or not item.polys is Array: return false
		for poly in item.polys:
			if not poly is PackedVector2Array or poly.size() < 3: return false
	for fragment in frags:
		if not fragment is Array or fragment.size() != 12 or not fragment[0] is Vector2 or not fragment[1] is Vector2: return false
		for index in range(2,12):
			if not (fragment[index] is float or fragment[index] is int): return false
		if int(fragment[5]) not in [0,1] or float(fragment[7]) < 0.0: return false
	for fine in fines:
		if not fine is Array or fine.size() != 10 or not fine[0] is Vector2 or not fine[1] is Vector2 or not fine[2] is bool or not fine[7] is Vector2 or not fine[8] is Vector2: return false
		for index in [3,4,5,6,9]:
			if not (fine[index] is float or fine[index] is int): return false
		if int(fine[3]) not in [0,1,2,3] or float(fine[5]) < 0.0: return false
	return absf(in_process_mass()+company_fe+company_nf+company_released_fe+company_released_nf-company_input) < 0.000001


func plate_like(kinds: Array) -> bool:
	if kinds.is_empty():
		return false
	for k in kinds:
		if not k in PLATE_KINDS:
			return false
	return true


# a body the mouth took: its pieces' outlines (m, around its middle), mass (t), the
# pieces' kinds, where along the floor the mouth was (m)
func take(polys: Array, mass: float, kinds: Array, from_x: float) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in polys:
		for q in p:
			lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
			hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	if lo.x == INF:
		lo = Vector2(-0.3, -0.3)
		hi = Vector2(0.3, 0.3)
	var c := (lo + hi) * 0.5
	var cp: Array = []
	for p in polys:
		var pp := PackedVector2Array()
		for q in p:
			pp.append(q - c)
		cp.append(pp)
	var it := {"polys": cp, "w": maxf(0.05, hi.x - lo.x), "h": maxf(0.05, hi.y - lo.y), "mass": mass, "seed": _seed_number(),
		"route": "press" if plate_like(kinds) else "shred", "dirty": 0.0 if plate_like(kinds) else (1.0 if kinds.has("equip") else 0.4)}
	arriving.append({"item": it, "t": 0.0, "dur": 2.0 + absf(from_x - X) / 3.0, "from": from_x})


func busy() -> int:
	return arriving.size() + press_q.size() + shred_q.size() + (1 if press != null else 0) + (1 if shred != null else 0)


func waiting_mass() -> float:
	var m := 0.0
	for a in arriving:
		m += float(a.item.mass)
	for q in press_q + shred_q:
		m += float(q.mass)
	return m


# ---------------------------------------------------------------- per frame

func step(dt: float) -> void:
	if dt <= 0.0:
		return
	if company_mode and not company_powered: return
	# A slow frame must not let a fragment skip the mill's throat or a ram
	# skip its gate interlock. Rendering remains once per actual frame.
	if dt > 1.0 / 30.0:
		var left := dt
		while left > 0.000001:
			var slice := minf(left,1.0 / 60.0)
			step(slice)
			left -= slice
		return
	if company_mode and not company_complete():
		company_energy_j += COMPANY_WATTS*dt
		company_running_s += dt
	t += dt
	drive_rate = move_toward(drive_rate,2.0 if busy() > 4 else 1.0,dt * 0.5)
	var hurry := drive_rate
	# arrivals: along the belt, down the chute, through the diverter
	for a in arriving.duplicate():
		a.t += dt * hurry
		if a.t >= a.dur:
			arriving.erase(a)
			if a.item.route == "press":
				press_q.append(a.item)
			else:
				shred_q.append(a.item)
	if not arriving.is_empty():
		divert_goal = -1.0 if arriving[0].item.route == "press" else 1.0
	divert = move_toward(divert, divert_goal, dt * 3.0)
	_step_press(dt * hurry)
	_step_shred(dt * hurry)
	rotor_speed = move_toward(rotor_speed, 1.2 if shred == null else lerpf(2.9,1.6,clampf(torque / 160.0,0,1)), dt * 2.8)
	rotor_angle += rotor_speed * dt
	mill_speed = move_toward(mill_speed,14.0 if shred != null or not frags.is_empty() else 3.0,dt * 12)
	mill_angle += mill_speed * dt
	drum_angle -= 2.4 * dt
	_step_bits(dt)


func _step_press(dt: float) -> void:
	if press == null:
		force = move_toward(force, 0.0, 3000.0 * dt)
		if press_q.is_empty():
			return
		press = press_q.pop_front()
		press.s = minf(1.0, minf(3.6 / press.w, 1.6 / press.h))
		var area := float(press.mass) / PUCK_RHO / DEPTH
		var ph := clampf(sqrt(area / 1.25), 0.16, 1.1)
		press.ph_ = minf(ph, press.h * press.s)
		press.pw_ = minf(clampf(ph * 1.25, 0.2, 1.4), press.w * press.s)
		press.ph = 0
		press.pt = 0.0
		press.pose0 = Vector3(lid_y,side_x,out_gate)
		press.sent = false
		_sfx("hiss", 0.5)
	while dt > 0.000001 and press != null:
		var ph: int = press.ph
		var slice := minf(dt,float(PRESS_T[ph]) - float(press.pt))
		press.pt += slice
		dt -= slice
		var k := clampf(press.pt / PRESS_T[ph],0,1)
		var goal: Vector3 = press.pose0
		match ph:
			0: goal = Vector3(PRESS_Y0,PRESS_X0,0)
			1: goal.x = PRESS_Y1 - press.ph_ - 0.02
			2: goal.y = PRESS_X1 - press.pw_ - 0.02
			4: goal = Vector3(PRESS_Y0,side_x if k == 0 else PRESS_X1 - press.pw_ - 0.12,0)
			5: goal.z = 1.0
			6: goal.y = PRESS_X1 + 1.4
			7: goal = Vector3(PRESS_Y0,PRESS_X0,1)
		var pose: Vector3 = (press.pose0 as Vector3).lerp(goal,Pal.ease_io(k))
		lid_y = pose.x
		side_x = pose.y
		out_gate = pose.z
		if ph == 7: out_gate = 1.0 - Pal.ease_io(clampf((k - 0.65) / 0.35,0,1))
		var target_force := 0.0
		if ph == 1: target_force = 2400 * k * k
		elif ph == 2: target_force = 2400 + 1600 * k * k
		elif ph == 3: target_force = 4000
		elif ph == 4: target_force = 4000 * (1.0 - Pal.ease_io(k))
		force = move_toward(force,target_force,10000 * slice)
		if k < 1.0: break
		if ph == 6:
			# Last in-box position equals the first roller position, including
			# the piston take-up. Never restart a block at the closed gate.
			pucks.append([side_x + 0.02,press.mass,press.pw_,press.ph_,press.seed])
			pucks_made += 1
			press.sent = true
		press.ph += 1
		press.pt = 0.0
		press.pose0 = Vector3(lid_y,side_x,out_gate)
		if press.ph >= PRESS_T.size(): press = null
		elif press.ph in [1,2,4,5]: _sfx("hiss",0.45)


func press_shape() -> Dictionary:
	if press == null: return {}
	var hs: float = press.h * press.s
	var ws: float = press.w * press.s
	var h := minf(hs,maxf(float(press.ph_),PRESS_Y1 - lid_y - 0.02)) if press.ph >= 1 else hs
	var w := minf(ws,maxf(float(press.pw_),PRESS_X1 - side_x - 0.02)) if press.ph >= 2 else ws
	if press.ph >= 3:
		h = press.ph_
		w = press.pw_
	var left := maxf(PRESS_X1 - w,side_x + 0.02) if press.ph == 6 else PRESS_X1 - w
	var at := Vector2(left + w * 0.5,PRESS_Y1 - h * 0.5)
	if press.ph == 0:
		at = Vector2(-4.6,1.9).lerp(at,Pal.ease_io(press.pt / PRESS_T[0]))
	return {"at":at,"w":w,"h":h,"sx":w / ws,"sy":h / hs}


func _step_shred(dt: float) -> void:
	if shred == null:
		torque = move_toward(torque, 4.0, 60.0 * dt)
		if shred_q.is_empty():
			return
		shred = shred_q.pop_front()
		shred.s = minf(1.0, minf(1.5 / shred.w, 1.2 / shred.h))
		shred.y = 1.95 - shred.h * shred.s * 0.5
		shred.pt = 0.0
		shred.made = 0.0
		shred.bit_acc = 0.0
	shred.pt += dt
	var hs: float = shred.h * shred.s
	if shred.pt < 0.6:
		return
	# fed down into the nip: the part below the bite line is gone into pieces
	var v := 0.45 * clampf(1.2 / maxf(0.3, float(shred.mass)), 0.4, 1.4) * (0.7 + 0.3 * absf(sin(rotor_angle * 3.0)))
	shred.y += v * dt
	var bitten := clampf((shred.y + hs * 0.5 - ROT_Y) / hs, 0.0, 1.0)
	torque = lerpf(torque, 20.0 + 70.0 * clampf(float(shred.mass), 0.1, 2.0), 1.0 - exp(-6.0 * dt))
	var want := int(bitten * 26.0)
	while shred.made < want:
		shred.made += 1
		parcel_no += 1
		var x := clampf(_range(ROT_L - 0.2, ROT_R + 0.2), 4.35, 5.65)
		frags.append([Vector2(x, ROT_Y + 0.2), Vector2(_range(-0.3, 0.3), _range(0.8, 1.3)), rotor_angle, _range(-8, 8), _range(0.05, 0.11), 0, 0.0, float(shred.mass) / 26.0, float(shred.dirty),0.0,0.0,parcel_no])
		if _random() < 0.3:
			_sfx("crack", 0.35)
	if bitten >= 1.0:
		shredded += float(shred.mass)
		shred = null


# the pieces into the mill, the powder over the drum, the pucks along their rollers
func _step_bits(dt: float) -> void:
	for f in frags.duplicate():
		f[6] += dt
		if f[5] == 0:
			f[0].x = move_toward(f[0].x,MILL.x,dt * 0.55)
			f[0].y += f[1].y * dt
			f[2] += f[3] * dt
			if f[0].distance_to(MILL) <= MILL_R - 0.04:
				f[5] = 1
				f[6] = 0.0
				f[9] = (f[0] - MILL).angle()
				f[10] = f[0].distance_to(MILL)
		else:
			# Capture at the entry angle/radius; accelerate into the rotor rather
			# than snapping to a time-derived point on its opposite side.
			f[9] += mill_speed * clampf(f[6] / 0.25,0,1) * dt
			f[10] = move_toward(f[10],MILL_R * 0.48,dt * 0.6)
			f[0] = MILL + Vector2.from_angle(f[9]) * f[10]
			f[2] += f[3] * dt
			f[4] = maxf(0.025,f[4] - dt * 0.045)
			if f[6] >= 0.65:
				frags.erase(f)
				# Each visual parcel owns an exact share of this fragment's mass.
				# No timer credits the furnace before those parcels reach it.
				for q in 3:
					var fe := q < 2
					var share := company_nonferrous_share if company_mode else NONFERROUS
					var mass: float = f[7] * ((1.0 - share) * 0.5 if fe else share)
					var exit := MILL + Vector2(_range(-0.22,0.22),MILL_R * 0.94)
					parcel_no += 1
					fines.append([f[0],Vector2.ZERO,fe,0,0.0,mass,f[8],f[0],exit,parcel_no])
	for p in fines.duplicate():
		match int(p[3]):
			0:
				p[4] += dt
				if p[4] < 0.32:
					p[0] = (p[7] as Vector2).lerp(p[8],Pal.ease_io(p[4] / 0.32))
				else:
					p[0] = (p[8] as Vector2).lerp(DRUM + Vector2(0,-DRUM_R - 0.02),clampf((p[4] - 0.32) / 0.7,0,1))
				if p[4] >= 1.02:
					p[3] = 1
					p[4] = -PI * 0.5
			1:
				if p[2]:
					p[4] -= 2.4 * dt
					p[0] = DRUM + Vector2.from_angle(p[4]) * (DRUM_R + 0.02)
					if p[4] <= -PI - 0.25:
						p[3] = 2
						p[7] = p[0]
						p[4] = 0.0
				else:
					# Separate at the tangent. The enclosed chute carries this stream
					# into its own bin; material is accounted only after landing.
					p[3] = 3
					p[7] = p[0]
					p[4] = 0.0
			2:
				p[4] += dt
				if p[4] < 0.4:
					p[0] = (p[7] as Vector2).lerp(Vector2(4.65,5.68),Pal.ease_io(p[4] / 0.4))
				else:
					var u: float = clampf((p[4] - 0.4) / 2.8,0,1)
					p[0] = Vector2(4.65,5.68).lerp(Vector2(0.7,6.08),u)
				if p[4] >= 3.2:
					fines.erase(p)
					ferrous += float(p[5])
					probe_flow_mass += float(p[5])
					if company_mode: company_fe += float(p[5])
					elif smelter != null: smelter.charge(float(p[5]),X,float(p[6]),true)
			3:
				p[4] += dt
				var u: float = clampf(p[4] / 0.85,0,1)
				var middle := Vector2(5.72,5.37)
				var end := Vector2(5.92,6.04)
				p[0] = (p[7] as Vector2).lerp(middle,u).lerp(middle.lerp(end,u),u)
				if u >= 1.0:
					fines.erase(p)
					nonferrous += float(p[5]) * 1000.0
					separated_t += float(p[5])
					if company_mode: company_nf += float(p[5])
	for pk in pucks.duplicate():
		pk[0] = move_toward(float(pk[0]), -1.0, 1.2 * dt)
		if float(pk[0]) <= -1.0:
			pucks.erase(pk)
			if smelter != null:
				smelter.charge(float(pk[1]), X, 0.0, true)


func _sfx(name: String, vol: float) -> void:
	if game != null and game.sfx != null:
		game.sfx.play(name, Vector2(X, (Dock.FLOOR_Y if is_nan(floor_y) else floor_y) + 3.0) * M, vol)


# ---------------------------------------------------------------- drawing

func _p(x: float, y: float, F: float) -> Vector2:
	return Vector2(X + x, F + y) * M


func arrival_at(a: Dictionary) -> Vector2:
	var belt := maxf(0.0,float(a.dur) - 2.0)
	if a.t < belt: return Vector2(lerpf(a.from,X,a.t / maxf(0.001,belt)) - X,0.8)
	if a.t < belt + 0.7: return Vector2(0,lerpf(0.8,1.55,(a.t - belt) / 0.7))
	return Vector2(0,1.55).lerp(Vector2(-4.6,1.9) if a.item.route == "press" else Vector2(3.4,1.6),Pal.ease_io(clampf((a.t - belt - 0.7) / 1.3,0,1)))


func _rect(ci, x0: float, y0: float, x1: float, y1: float, F: float, fill_c: Color, edge: Color = Color(0, 0, 0, 0), w: float = 1.0) -> void:
	var r := Rect2(_p(x0, y0, F), Vector2(x1 - x0, y1 - y0) * M)
	ci.draw_rect(r, fill_c)
	if edge.a > 0.0:
		ci.draw_rect(r, edge, false, w)


# an item's outline drawn at (m), scaled, squashed toward an anchor and crumpled as it goes
func _item(ci, it: Dictionary, at: Vector2, F: float, sx: float, sy: float, crumple: float, col: Color, edge: Color, clip_y: float = INF) -> void:
	var s: float = it.s
	var i := 0
	for poly in it.polys:
		var pts := PackedVector2Array()
		for q in poly:
			var n := Vector2(sin(float(i) * 12.99 + float(it.seed)), cos(float(i) * 7.31 + float(it.seed))) * crumple
			var v: Vector2 = at + Vector2(q.x * s * sx, q.y * s * sy) + n
			if clip_y < INF:
				var contact := clampf((v.y - clip_y + 0.24) / 0.24,0,1)
				v.x += 0.035 * contact * sin(rotor_angle * 6.0 + q.x * 9.0)
				v.y += 0.06 * contact
			pts.append(v)
			i += 1
		if clip_y < INF:
			var cut := Geometry2D.intersect_polygons(pts, PackedVector2Array([Vector2(-100, -100), Vector2(100, -100), Vector2(100, clip_y), Vector2(-100, clip_y)]))
			for c in cut:
				_poly(ci, c, F, col, edge)
		elif pts.size() >= 3:
			_poly(ci, pts, F, col, edge)


func _poly(ci, pts: PackedVector2Array, F: float, col: Color, edge: Color) -> void:
	var w := PackedVector2Array()
	for p in pts:
		w.append(_p(p.x, p.y, F))
	if Geometry2D.triangulate_polygon(w).is_empty():
		return
	ci.draw_colored_polygon(w, col)
	w.append(w[0])
	ci.draw_polyline(w, edge, 1.0)


func draw(ci, F: float, mx: float, font: Font, font_b: Font, zoom: float, txt: Callable) -> void:
	var ink := Pal.ink(0.42)
	if zoom < 0.55:
		# far out: the machines' outlines
		_rect(ci, PRESS_X0 - 0.2, PRESS_Y0 - 0.2, PRESS_X1 + 0.2, PRESS_Y1 + 0.2, F, Color(0.06, 0.063, 0.072), ink)
		_rect(ci, 4.15, 1.85, 5.85, 3.55, F, Color(0.03, 0.031, 0.036), ink)
		ci.draw_circle(_p(MILL.x, MILL.y, F), MILL_R * M, Color(0.03, 0.031, 0.036))
		ci.draw_circle(_p(DRUM.x, DRUM.y, F), DRUM_R * M, Color(0.08, 0.083, 0.095))
		ci.draw_rect(Rect2(_p(10.5, 0.95, F), Vector2(6.9, 2.4) * M), Color(0.035, 0.037, 0.042, 0.96))
		return
	var steel := Color(0.06, 0.063, 0.072)
	var part_c := Color(0.2, 0.2, 0.215)
	var part_e := Pal.ink(0.55)
	# ---- the chute from the mouth's throat, and the return belt when the mouth has moved
	_rect(ci, -0.5, 0.45, 0.5, 1.2, F, Color(0.035, 0.037, 0.042), Pal.ink(0.3))
	if absf(mx - X) > 0.3:
		var bx0 := minf(mx, X)
		var bx1 := maxf(mx, X)
		ci.draw_rect(Rect2(_p(bx0 - X - 0.4, 0.62, F), Vector2(bx1 - bx0 + 0.8, 0.36) * M), Color(0.04, 0.042, 0.048))
		ci.draw_line(_p(bx0 - X - 0.4, 0.62, F), _p(bx1 - X + 0.4, 0.62, F), ink, 1.0)
		ci.draw_line(_p(bx0 - X - 0.4, 0.98, F), _p(bx1 - X + 0.4, 0.98, F), ink, 1.0)
		var sl := PackedVector2Array()
		var x := bx0 + fposmod(t * 2.5, 0.5)
		while x < bx1:
			sl.append_array([Vector2(x, F + 0.66) * M, Vector2(x, F + 0.94) * M])
			x += 0.5
		if not sl.is_empty():
			ci.draw_multiline(sl, Pal.ink(0.16), 1.6)
		ci.draw_line(Vector2(mx, F + 0.45) * M, Vector2(mx, F + 0.62) * M, ink, 2.0)
		_label(ci, font, Vector2(mx + 0.6 * signf(X - mx), F + 1.45) * M, txt.call("fu_belt"), zoom)
	# what is on its way: a small copy of the part, along the belt and down the chute
	for a in arriving:
		var p := arrival_at(a)
		var it: Dictionary = a.item
		var tmp := it.duplicate()
		tmp.s = minf(0.5 / it.w, 0.4 / it.h)
		_item(ci, tmp, p, F, 1.0, 1.0, 0.0, part_c, part_e)
	# ---- the diverter
	_rect(ci, -0.9, 1.2, 0.9, 1.75, F, Color(0.04, 0.042, 0.048), Pal.ink(0.45), 1.2)
	var fa := deg_to_rad(42.0) * divert
	ci.draw_line(_p(0.0, 1.25, F), _p(0.0, 1.25, F) + Vector2.from_angle(PI * 0.5 + fa) * 0.5 * M, Pal.ink(0.75), 3.0)
	ci.draw_circle(_p(0.0, 1.25, F), 3.0, Pal.ink(0.7))
	_label(ci, font, _p(1.0, 1.42, F), txt.call("sl_divert"), zoom)
	# chutes out of it: left to the press, right to the shredder
	ci.draw_polyline(PackedVector2Array([_p(-0.6, 1.75, F), _p(-4.6, 2.05, F)]), ink, 1.4)
	ci.draw_polyline(PackedVector2Array([_p(-0.6, 1.55, F), _p(-4.8, 1.85, F)]), ink, 1.4)
	ci.draw_polyline(PackedVector2Array([_p(0.6, 1.55, F), _p(3.8, 1.8, F)]), ink, 1.4)
	ci.draw_polyline(PackedVector2Array([_p(0.6, 1.75, F), _p(4.1, 2.05, F)]), ink, 1.4)
	_draw_press(ci, F, font, zoom, txt, steel, part_c, part_e)
	_draw_shredder(ci, F, font, zoom, txt, steel, part_c, part_e)
	_panel(ci, F, font, font_b, txt, zoom)


func _draw_press(ci, F: float, font: Font, zoom: float, txt: Callable, steel: Color, part_c: Color, part_e: Color) -> void:
	# the box: thick walls, the side-ram cylinder to the left, the lid cylinder above
	_rect(ci, PRESS_X0 - 0.2, PRESS_Y0 - 0.2, PRESS_X1 + 0.2, PRESS_Y1 + 0.2, F, steel, Pal.ink(0.6), 1.6)
	_rect(ci, PRESS_X0, PRESS_Y0, PRESS_X1, PRESS_Y1, F, Color(0.025, 0.026, 0.03))
	for q in 6:
		var rx := PRESS_X0 + 0.3 + q * 0.7
		ci.draw_line(_p(rx, PRESS_Y0 - 0.2, F), _p(rx, PRESS_Y0 - 0.05, F), Pal.ink(0.35), 2.0)
		ci.draw_line(_p(rx, PRESS_Y1 + 0.05, F), _p(rx, PRESS_Y1 + 0.2, F), Pal.ink(0.35), 2.0)
	_rect(ci, -12.3, 2.55, PRESS_X0 - 0.2, 3.45, F, Color(0.08, 0.083, 0.095), Pal.ink(0.5), 1.2)
	_rect(ci, -7.35, 0.7, -6.55, PRESS_Y0 - 0.2, F, Color(0.08, 0.083, 0.095), Pal.ink(0.5), 1.2)
	# Persistent ram positions continue across every phase, including return.
	var gate := out_gate
	var it = press
	if it != null and not it.sent:
		var shape := press_shape()
		var at: Vector2 = shape.at
		var k: float = clampf(it.pt / PRESS_T[it.ph],0,1)
		var dense := Pal.ease_io(k) if it.ph == 3 else (1.0 if it.ph > 3 else 0.0)
		if dense < 0.999:
			var temp: Dictionary = it.duplicate()
			if it.ph == 0: temp.s = lerpf(minf(0.5 / it.w,0.4 / it.h),it.s,Pal.ease_io(k))
			_item(ci,temp,at,F,shape.sx,shape.sy,0.025 * (2.0 - shape.sx - shape.sy),Color(part_c,1.0 - dense),Color(part_e,1.0 - dense))
		if dense > 0.001:
			_puck(ci,at,it.pw_,it.ph_,F,it.seed,dense)
	# lid platen and side platen, with their rods back to the cylinders
	_rect(ci, PRESS_X0, lid_y - 0.1, PRESS_X1, lid_y, F, Color(0.11, 0.115, 0.13), Pal.ink(0.7), 1.2)
	ci.draw_line(_p(-6.95, PRESS_Y0 - 0.2, F), _p(-6.95, lid_y - 0.1, F), Pal.ink(0.8), 4.0)
	_rect(ci, side_x - 0.1, PRESS_Y0, side_x, PRESS_Y1, F, Color(0.11, 0.115, 0.13), Pal.ink(0.7), 1.2)
	ci.draw_line(_p(PRESS_X0 - 0.2, 3.0, F), _p(side_x - 0.1, 3.0, F), Pal.ink(0.8), 5.0)
	# the end gate lifts to let the puck out
	_rect(ci, PRESS_X1, PRESS_Y0 - gate * 2.1, PRESS_X1 + 0.2, PRESS_Y1 - gate * 2.1, F, Color(0.1, 0.104, 0.115), Pal.ink(0.6), 1.2)
	# the force gauge on the box
	var gc := _p(-10.6, 2.0, F)
	ci.draw_arc(gc, 13.0, PI * 0.75, PI * 2.25, 20, Pal.ink(0.55), 1.4)
	ci.draw_line(gc, gc + Vector2.from_angle(PI * 0.75 + PI * 1.5 * force / 4500.0) * 11.0, Pal.heat(0.95, 1.4), 1.6)
	# the rollers out to the bunker, and the pucks on them
	ci.draw_line(_p(PRESS_X1 + 0.2, PRESS_Y1 + 0.05, F), _p(-1.0, PRESS_Y1 + 0.05, F), Pal.ink(0.45), 1.4)
	var rx2 := PRESS_X1 + 0.35
	while rx2 < -1.0:
		ci.draw_arc(_p(rx2, PRESS_Y1 + 0.12, F), 0.06 * M, 0.0, TAU, 8, Pal.ink(0.35), 1.0)
		rx2 += 0.32
	for pk in pucks:
		_puck(ci, Vector2(float(pk[0]) + float(pk[2]) * 0.5, PRESS_Y1 - float(pk[3]) * 0.5), float(pk[2]), float(pk[3]), F, int(pk[4]))
	_label(ci, font, _p(PRESS_X0 - 3.2, PRESS_Y0 - 0.45, F), txt.call("sl_press_l"), zoom)
	_label(ci, font, _p(PRESS_X1 + 0.3, PRESS_Y1 + 0.5, F), txt.call("sl_out_l"), zoom)


# a pressed puck: dense, its folded layers showing as wavy lines across its face
func _puck(ci, c: Vector2, w: float, h: float, F: float, seed: int, opacity: float = 1.0) -> void:
	var r := Rect2(_p(c.x - w * 0.5, c.y - h * 0.5, F), Vector2(w, h) * M)
	ci.draw_rect(r, Color(0.23, 0.225, 0.23,opacity))
	var n := maxi(2, int(h / 0.06))
	for i in n:
		var yy := r.position.y + (i + 0.5) * r.size.y / n
		var pts := PackedVector2Array()
		for q in 7:
			var xx := r.position.x + r.size.x * q / 6.0
			pts.append(Vector2(xx, yy + 1.5 * sin(q * 2.1 + i * 1.7 + seed)))
		ci.draw_polyline(pts, Color(0.38, 0.37, 0.38,opacity), 1.0)
	ci.draw_rect(r, Pal.ink(0.6 * opacity), false, 1.2)


func _draw_shredder(ci, F: float, font: Font, zoom: float, txt: Callable, steel: Color, part_c: Color, part_e: Color) -> void:
	# the hopper narrowing to the cutting chamber
	var hop := PackedVector2Array([_p(3.8, 1.85, F), _p(6.2, 1.85, F), _p(5.8, 2.35, F), _p(4.2, 2.35, F)])
	ci.draw_colored_polygon(hop, Color(0.035, 0.037, 0.042))
	var hc := hop.duplicate()
	hc.append(hop[0])
	ci.draw_polyline(hc, Pal.ink(0.55), 1.4)
	_rect(ci, 4.15, 2.35, 5.85, 3.55, F, Color(0.03, 0.031, 0.036), Pal.ink(0.6), 1.6)
	# the part going in: drawn only above the bite line, the rest already in pieces
	if shred != null:
		var at := Vector2(5.0, float(shred.y))
		var item: Dictionary = shred.duplicate()
		if float(shred.pt) < 0.6:
			var load := Pal.ease_io(float(shred.pt) / 0.6)
			at = Vector2(3.4, 1.6).lerp(Vector2(5.0, float(shred.y)), load)
			item.s = lerpf(minf(0.5 / item.w,0.4 / item.h),shred.s,load)
		_item(ci, item, at, F, 1.0, 1.0, 0.012 * clampf((shred.y - 2.3) / 0.6,0,1), part_c, part_e, ROT_Y)
	# the two rotors, turning toward each other, hook teeth biting down between them
	var spin := rotor_angle
	for r in [[ROT_L, 1.0], [ROT_R, -1.0]]:
		var c := _p(float(r[0]), ROT_Y, F)
		var dir: float = r[1]
		ci.draw_circle(c, ROT_RAD * 0.62 * M, Color(0.1, 0.104, 0.115))
		ci.draw_arc(c, ROT_RAD * 0.62 * M, 0.0, TAU, 20, Pal.ink(0.55), 1.2)
		for q in 6:
			var a := spin * dir + TAU * q / 6.0
			# Replace triangular gear symbols with hooked cutting inserts:
			# a recessed heel, square shear face and replaceable bolted tip.
			var tooth := PackedVector2Array()
			for polar in [[-0.15,0.6],[-0.06,0.82],[0.05,1.0],[0.25,1.0],[0.25,0.78],[0.43,0.7],[0.49,0.6]]:
				tooth.append(c + Vector2.from_angle(a + float(polar[0]) * dir) * float(polar[1]) * ROT_RAD * M)
			ci.draw_colored_polygon(tooth,Color(0.25,0.26,0.28))
			tooth.append(tooth[0])
			ci.draw_polyline(tooth,Pal.ink(0.7),1.0)
			var bolt := c + Vector2.from_angle(a + 0.12 * dir) * ROT_RAD * 0.75 * M
			ci.draw_circle(bolt,1.1,Pal.ink(0.65))
		ci.draw_circle(c, 0.07 * M, Pal.ink(0.6))
		for q in 4:
			var angle := spin * dir + TAU * q / 4
			ci.draw_circle(c + Vector2.from_angle(angle) * 0.14 * M,1.0,Pal.ink(0.65))
	# Guided feed rollers hold the charge against the teeth in the vacuum berth.
	for feed_x in [4.15,5.85]:
		var fc := _p(feed_x,2.13,F)
		ci.draw_circle(fc,0.13 * M,steel)
		ci.draw_arc(fc,0.13 * M,0,TAU,14,Pal.ink(0.55),1.2)
		var feed_a := rotor_angle * (1 if feed_x < 5 else -1)
		ci.draw_line(fc - Vector2.from_angle(feed_a) * 0.1 * M,fc + Vector2.from_angle(feed_a) * 0.1 * M,Pal.ink(0.6),1)
	# the drive: motors and gearboxes on the right
	_rect(ci, 5.95, 2.45, 6.75, 3.35, F, Color(0.07, 0.073, 0.082), Pal.ink(0.45), 1.2)
	ci.draw_arc(_p(6.35, 2.9, F), 0.25 * M, 0.0, TAU, 14, Pal.ink(0.4), 1.0)
	_label(ci, font, _p(3.8, 1.75, F), txt.call("sl_shred_l"), zoom)
	# chute down into the hammer mill
	ci.draw_line(_p(4.35, 3.55, F), _p(4.55, 3.75, F), Pal.ink(0.45), 1.4)
	ci.draw_line(_p(5.65, 3.55, F), _p(5.45, 3.75, F), Pal.ink(0.45), 1.4)
	# the mill: its housing, the rotor with swinging hammers, the screen underneath
	var mc := _p(MILL.x, MILL.y, F)
	ci.draw_circle(mc, MILL_R * M, Color(0.03, 0.031, 0.036))
	ci.draw_arc(mc, MILL_R * M, PI * 0.85, PI * 2.15, 28, Pal.ink(0.6), 1.6)
	var ms := mill_angle
	for q in 4:
		var a2 := ms + TAU * q / 4.0
		var pv := mc + Vector2.from_angle(a2) * 0.22 * M
		var swing := a2 + 0.25 * sin(t * 30.0 + q)
		ci.draw_line(mc, pv, Pal.ink(0.5), 2.0)
		ci.draw_line(pv, pv + Vector2.from_angle(swing) * 0.26 * M, Color(0.35, 0.35, 0.37), 5.0)
	ci.draw_circle(mc, 0.08 * M, Pal.ink(0.6))
	# the screen: an arc of bars with gaps the powder passes
	var bars := PackedVector2Array()
	for q in 14:
		var a3 := lerpf(PI * 0.15, PI * 0.85, q / 13.0)
		bars.append_array([mc + Vector2.from_angle(a3) * (MILL_R - 0.05) * M, mc + Vector2.from_angle(a3) * (MILL_R + 0.03) * M])
	ci.draw_multiline(bars, Pal.ink(0.55), 2.0)
	# Enclosed guide throat: material leaves the screen at the bottom and
	# meets the separator at its crown, rather than falling beside it.
	ci.draw_polyline(PackedVector2Array([_p(4.7,4.85,F),_p(4.86,5.02,F),_p(4.86,5.08,F)]),Pal.ink(0.45),1.2)
	ci.draw_polyline(PackedVector2Array([_p(5.3,4.85,F),_p(5.14,5.02,F),_p(5.14,5.08,F)]),Pal.ink(0.45),1.2)
	_label(ci, font, _p(MILL.x + MILL_R + 0.15, MILL.y, F), txt.call("sl_mill_l"), zoom)
	# the shredded pieces, the powder
	for f in frags:
		var c2 := _p(f[0].x, f[0].y, F)
		var sz: float = f[4] * M
		var pts := PackedVector2Array()
		for q in 4:
			pts.append(c2 + Vector2.from_angle(f[2] + q * 1.7) * sz * (0.6 + 0.4 * float(q % 2)))
		ci.draw_colored_polygon(pts, Color(0.36, 0.36, 0.38))
	var dots_fe := PackedVector2Array()
	for p in fines:
		var c3 := _p(p[0].x, p[0].y, F)
		if p[2] or p[3] == 0:
			dots_fe.append(c3)
		else:
			ci.draw_circle(c3, 0.8, Color(0.85, 0.55, 0.3))
	Dock._dots(ci, dots_fe, 1.3, Color(0.55, 0.56, 0.6))
	# the magnetic drum: the magnet's arc inside it, the shell turning round it
	var dc := _p(DRUM.x, DRUM.y, F)
	ci.draw_circle(dc, DRUM_R * M, Color(0.08, 0.083, 0.095))
	ci.draw_arc(dc, DRUM_R * 0.75 * M, PI * 0.45, PI * 1.6, 14, Pal.tint(Pal.VOLT, 0.8, 1.2), 3.0)
	for q in 8:
		var a4 := drum_angle + TAU * q / 8.0
		ci.draw_line(dc + Vector2.from_angle(a4) * DRUM_R * 0.85 * M, dc + Vector2.from_angle(a4) * DRUM_R * M, Pal.ink(0.5), 1.0)
	ci.draw_arc(dc, DRUM_R * M, 0.0, TAU, 20, Pal.ink(0.6), 1.4)
	ci.draw_line(_p(4.68,5.44,F),_p(4.63,5.67,F),Pal.ink(0.55),1.5)
	ci.draw_polyline(PackedVector2Array([_p(5.05,5.08,F),_p(5.75,5.25,F),_p(6.03,5.5,F)]),Pal.ink(0.3),1.0)
	_label(ci, font, _p(DRUM.x + 0.35, DRUM.y - 0.2, F), txt.call("sl_drum_l"), zoom)
	# the vibrating pan to the furnace's port, the non-ferrous bin
	ci.draw_line(_p(4.65, 5.66, F), _p(0.7, 6.06, F), Pal.ink(0.55), 2.0)
	ci.draw_line(_p(4.65, 5.74, F), _p(0.7, 6.14, F), Pal.ink(0.25), 1.0)
	_label(ci, font, _p(1.6, 5.7, F), txt.call("sl_pan_l"), zoom)
	_rect(ci, 5.5, 5.45, 6.35, 6.15, F, Color(0.04, 0.042, 0.048), Pal.ink(0.45), 1.2)
	var nf := clampf((company_nf*1000.0 if company_mode else nonferrous) / 400.0, 0.0, 1.0)
	_rect(ci, 5.55, 6.1 - 0.6 * nf, 6.3, 6.1, F, Color(0.6, 0.42, 0.25, 0.75))
	_label(ci, font, _p(6.45, 5.9, F), txt.call("sl_bin_l"), zoom)


func _label(ci, font: Font, at: Vector2, s: String, zoom: float) -> void:
	# the processing district's line names its parts only when you are close (36 号)
	if quiet and zoom < 1.6:
		return
	var a := clampf((zoom - 0.8) / 0.3, 0.0, 1.0)
	if a > 0.01:
		ci.draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.5 * a))


# the plate: what the line is doing, in numbers
func _panel(ci, F: float, font: Font, font_b: Font, txt: Callable, zoom: float) -> void:
	var r := Rect2(_p(10.5, 0.95, F), Vector2(6.9, 2.4) * M)
	if zoom < 0.3 or Guide.quiet or quiet:
		return
	ci.draw_rect(r, Color(0.035, 0.037, 0.042, 0.96))
	ci.draw_rect(Rect2(r.position, Vector2(4, r.size.y)), Pal.ink(0.8))
	ci.draw_rect(r, Pal.ink(0.3), false, 1.0)
	var x := r.position.x + 14.0
	var y := r.position.y + 20.0
	ci.draw_string(font_b, Vector2(x, y), txt.call("sl_title"), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24.0, 12, Pal.ink(0.92))
	var lines := [
		txt.call("sl_press") % [int(force), lerpf(0.5, PUCK_RHO, clampf(force / 4000.0, 0.0, 1.0)), pucks_made],
		txt.call("sl_shred") % [int(rotor_speed * 60 / TAU), torque, shredded],
		txt.call("sl_mill") % [int(mill_speed * 60 / TAU), ferrous, nonferrous],
		txt.call("sl_queue") % [busy(), waiting_mass()],
	]
	for i in lines.size():
		ci.draw_string(font, Vector2(x, y + 21.0 + i * 18.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24.0, 12, Pal.ink(0.66))


# a string's width, measured once (shaping text is what made the plant's frame slow)
var _widths := {}


func _tw(font: Font, s: String, size: int) -> float:
	var k := "%d|%d|%s" % [font.get_instance_id(), size, s]
	if not _widths.has(k):
		_widths[k] = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return _widths[k]
