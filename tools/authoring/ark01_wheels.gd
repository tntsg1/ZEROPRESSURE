extends RefCounted
# ARK-01 改造方案 2 第 1 段样片：两个套在主轴上的居住环改成侧挂转轮（转轴垂直于屏幕）。
# Not part of the game yet: tests/ark_wheel_shot.gd loads ships/ark01.json, runs apply() on it
# and hands the result to Ship.override("ark01", ...). Once the owner approves the look this
# moves into tools/authoring/ark01_author.gd and ships/ark01.json is exported from it.
#
# What it does to the file (metres, y down, the spine's axis y = 0):
#   each ring's old content is split in three bands by |y|:
#     hub    (9.6 .. hub top)      -> the still bearing housing at the wheel's centre (doesn't turn)
#     spokes (hub top .. rim in)   -> squeezed to short spokes (hull plates scaled, equipment moved)
#     rim    (rim in .. rim out)   -> moved in: the old top module becomes the wheel's top module,
#                                     the bottom one its bottom module (floors still outward)
#   and the whole lot is lifted (ring A, above the spine) or dropped (ring B, below) so the
#   wheel's swept circle clears the spine by GAP. Spokes + rim modules + the new rim trusses
#   are the wheel ("members": what turns); the housing and the rollers stay put.
#   New: a rim truss on either side joining the two modules (a wheel, not a dumbbell), and
#   the pylon (an A-frame of two struts and the access tube's two walls) from the spine's
#   chords to the housing, drawn behind the wheel (first in the piece list).
#   Joints between something moved and something left on the spine are dropped; the pylon's
#   welds hold the housing, the old spoke-to-hub welds stand for the bearing.

const GAP := 3.0                  # m between the spine (|y| 9.65) and the wheel's swept circle
const SPINE_Y := 9.65
const HUB_Y0 := 9.6               # the old hub halves' inner face (on the spine)

# ring: x range of its content, old hub top |y|, old rim inner |y|, old rim outer |y|,
#   new hub half-gap (the bearing core between the housing's halves), new spoke start (clears the
#   housing's corners as it turns), new rim inner, side of the spine (-1 above), turning (+1 cw)
const R := {
	"A": {"x0": 66.0, "x1": 104.0, "cx": 85.0, "hub": 17.0, "rin": 96.0, "rout": 114.0,
		"g": 4.0, "s0": 15.5, "rin2": 21.5, "side": -1.0, "dir": 1.0, "rpm": 3.0, "decel": 0.0125, "tube": 85.0},
	"B": {"x0": 166.0, "x1": 220.0, "cx": 193.0, "hub": 18.0, "rin": 100.0, "rout": 122.0,
		"g": 2.0, "s0": 16.2, "rin2": 20.2, "side": 1.0, "dir": -1.0, "rpm": 2.6, "decel": 0.0075, "tube": 198.0},
}


static func info() -> Dictionary:
	var out := {}
	for r in R:
		var e: Dictionary = R[r]
		var rout2: float = e.rout - e.rin + e.rin2
		var half: float = (e.x1 - e.x0) * 0.5 - 2.0       # the module's half width (x 68..102 / 168..218)
		var sweep: float = sqrt(rout2 * rout2 + half * half)
		var cy: float = e.side * (SPINE_Y + GAP + sweep)
		out[r] = {"cx": e.cx, "cy": cy, "rout": rout2, "sweep": sweep, "half": half}
	return out


# |y| (and which side) of an old point -> its new y (only for points in a ring's x range, |y| >= 7)
static func _map_y(e: Dictionary, cy: float, y: float) -> float:
	var a := absf(y)
	var s := signf(y) if y != 0.0 else 1.0
	var b: float
	if a < e.hub:
		b = a - HUB_Y0 + e.g
	elif a < e.rin:
		b = e.s0 + (a - e.hub) * (e.rin2 - e.s0) / (e.rin - e.hub)
	else:
		b = a - e.rin + e.rin2
	return cy + s * b


static func _ring_at(x: float) -> String:
	for r in R:
		if x >= R[r].x0 and x <= R[r].x1:
			return r
	return ""


static func _pt(info_: Dictionary, p: Array) -> Array:
	var x := float(p[0])
	var y := float(p[1])
	var r := _ring_at(x)
	if r == "" or absf(y) < 7.0:
		return [x, y]
	return [x, _map_y(R[r], float(info_[r].cy), y)]


static func _bbox(poly: Array) -> Rect2:
	var a := Vector2(INF, INF)
	var b := Vector2(-INF, -INF)
	for v in poly:
		a = Vector2(minf(a.x, float(v[0])), minf(a.y, float(v[1])))
		b = Vector2(maxf(b.x, float(v[0])), maxf(b.y, float(v[1])))
	return Rect2(a, b - a)


static func apply(d: Dictionary) -> Dictionary:
	# a file already turned is left as it is
	if bool(d.get("rings", {}).get("wheels", false)):
		return d
	var inf := info()
	_dress(d)
	# the inching drive's switch, on the brake console beside the lock (old coordinates: moved with it)
	d.ctrls.append({"at": [79.65, -10.95], "hidden_room": "HAU", "id": "INCH-A", "kind": "switch", "piece": "BCTL-A", "target": "INCH-A"})
	d.ctrls.append({"at": [185.65, -10.95], "hidden_room": "HBU", "id": "INCH-B", "kind": "switch", "piece": "BCTL-B", "target": "INCH-B"})
	var cls := {}            # tag -> "house" | "wheel" (moved); absent: left where it is
	var ring_of := {}
	for pd in d.pieces:
		var bb := _bbox(pd.poly)
		var c := bb.get_center()
		var r := _ring_at(c.x)
		if r == "":
			continue
		var tag := str(pd.tag)
		if tag.begins_with("BR%s-" % r):
			cls[tag] = "house"
		elif absf(c.y) >= SPINE_Y:
			cls[tag] = "house" if absf(c.y) < R[r].hub else "wheel"
		else:
			continue
		ring_of[tag] = r
	# move the pieces
	for pd in d.pieces:
		var tag := str(pd.tag)
		if not cls.has(tag):
			continue
		var r: String = ring_of[tag]
		var e: Dictionary = R[r]
		var cy: float = inf[r].cy
		var bb := _bbox(pd.poly)
		var c := bb.get_center()
		var in_spoke: bool = absf(c.y) >= e.hub and absf(c.y) < e.rin
		var scaled: bool = in_spoke and str(pd.kind) == "hull"
		var dy := _map_y(e, cy, c.y) - c.y
		var np: Array = []
		for v in pd.poly:
			np.append([float(v[0]), _map_y(e, cy, float(v[1])) if scaled else float(v[1]) + dy])
		if scaled:
			var k: float = (_bbox(np).size.y / maxf(bb.size.y, 0.001))
			pd.mass = float(pd.mass) * k
		pd.poly = np
		if pd.has("art_xf"):
			var a: Array = pd.art_xf
			if scaled:
				var o := Vector2(float(a[4]), float(a[5]))
				a[5] = _map_y(e, cy, o.y)
			else:
				a[5] = float(a[5]) + dy
			pd.art_xf = a
	# joints: dropped across moved / left; the rest follow
	var keep: Array = []
	var pos := {}
	for pd in d.pieces:
		pos[str(pd.tag)] = _bbox(pd.poly).get_center()
	for j in d.joints:
		var ma := cls.has(str(j.a))
		var mb := cls.has(str(j.b))
		if ma != mb:
			continue
		if ma:
			var r: String = ring_of[str(j.a)]
			var at: Array = j.at
			var y := float(at[1])
			# a joint inside a moved piece moves with it (a spoke's equipment was moved, not scaled)
			var wa: bool = cls[str(j.a)] == "wheel"
			var wb: bool = cls[str(j.b)] == "wheel"
			j.at = [float(at[0]), _map_y(R[r], float(inf[r].cy), y)]
			if wa != wb:
				j["bearing"] = true
		keep.append(j)
	d.joints = keep
	# lines and controls
	for l in d.lines:
		var path: Array = []
		for v in l.path:
			path.append(_pt(inf, v))
		l.path = path
		l.pa = _pt(inf, l.pa)
		l.pb = _pt(inf, l.pb)
	for ct in d.ctrls:
		var tag := str(ct.get("piece", ""))
		if cls.has(tag):
			ct.at = _pt(inf, ct.at)
	for rm in d.rooms:
		var bb := _bbox(rm.poly)
		var r := _ring_at(bb.get_center().x)
		if r == "" or absf(bb.get_center().y) < SPINE_Y:
			continue
		var np: Array = []
		for v in rm.poly:
			np.append(_pt(inf, v))
		rm.poly = np
	# the rim trusses (part of the wheel) and the pylon (left on the ship, drawn behind)
	var front: Array = []
	for r in R:
		var e: Dictionary = R[r]
		var cx: float = e.cx
		var cy: float = inf[r].cy
		var half: float = inf[r].half
		var rin2: float = e.rin2
		var rout2: float = inf[r].rout
		var rt: float = (rin2 + rout2) * 0.5 + 1.0          # the truss runs through the modules' side walls
		var a_lim: float = asin(clampf(half / rt, -1.0, 1.0))  # from the vertical, where it meets a module
		var n := 7
		for side in [-1.0, 1.0]:
			var prev := ""
			for k in n:
				var t0: float = lerpf(a_lim, PI - a_lim, float(k) / n)
				var t1: float = lerpf(a_lim, PI - a_lim, float(k + 1) / n)
				var tag := "RT%s%s%d" % [r, "E" if side > 0.0 else "W", k]
				# a lattice: an outer chord (this piece), an inner chord, a post and a diagonal between them
				var ro_: float = rt + 0.95
				var ri_: float = rt - 0.95
				var chord_o: Array = [_arc_pt(cx, cy, side, t0, ro_ + 0.2), _arc_pt(cx, cy, side, t1, ro_ + 0.2), _arc_pt(cx, cy, side, t1, ro_ - 0.2), _arc_pt(cx, cy, side, t0, ro_ - 0.2)]
				var chord_i: Array = [_arc_pt(cx, cy, side, t0, ri_ + 0.2), _arc_pt(cx, cy, side, t1, ri_ + 0.2), _arc_pt(cx, cy, side, t1, ri_ - 0.2), _arc_pt(cx, cy, side, t0, ri_ - 0.2)]
				var a0: Array = _arc_pt(cx, cy, side, t0, ri_)
				var a1: Array = _arc_pt(cx, cy, side, t1, ro_)
				var b0: Array = _arc_pt(cx, cy, side, t0, ro_)
				var diag: Array = _bar(a0, a1, 0.13)
				var post: Array = _bar(b0, a0, 0.13)
				d.pieces.append({"cut_speed": 140.0, "density": 1.6, "key": tag, "kind": "beam", "mass": 4.0, "name_key": "p_spar", "poly": chord_o, "tag": tag})
				cls[tag] = "wheel"
				ring_of[tag] = r
				for extra in [["I", chord_i, 4.0], ["D", diag, 1.2], ["P", post, 1.0]]:
					var et: String = tag + str(extra[0])
					d.pieces.append({"cut_speed": 160.0, "density": 1.4, "key": et, "kind": "strut", "mass": extra[2], "name_key": "p_post", "poly": extra[1], "tag": et})
					cls[et] = "wheel"
					ring_of[et] = r
					d.joints.append({"a": tag, "b": et, "at": b0 if str(extra[0]) == "P" else a1, "type": "weld"})
				var tm: float = (t0 + t1) * 0.5
				if prev != "":
					d.joints.append({"a": prev, "b": tag, "at": [cx + side * sin(t0) * rt, cy - cos(t0) * rt], "type": "weld"})
				prev = tag
			# the truss's ends welded into the two modules' side walls
			for t in [a_lim, PI - a_lim]:
				var at := Vector2(cx + side * sin(t) * rt, cy - cos(t) * rt)
				var near := _nearest(d, cls, at, "wheel", r, ring_of, ["RT"])
				var end_tag := "RT%s%s%d" % [r, "E" if side > 0.0 else "W", 0 if t == a_lim else n - 1]
				if near != "":
					d.joints.append({"a": end_tag, "b": near, "at": [at.x, at.y], "type": "weld"})
		# the pylon: two struts from the chords to the housing's spine-side face, the access tube's walls
		var face: float = cy - e.side * (e.hub - HUB_Y0 + e.g)     # the housing's face toward the spine
		var chord_y: float = e.side * 8.4
		var chords := {"A": ["CT-1", "CT-2"], "B": ["CB-4", "CB-5"]}
		var parts: Array = [
			["PY%s-W" % r, cx - 13.0, chord_y, cx - 5.0, face, 1.4, chords[r][0]],
			["PY%s-E" % r, cx + 13.0, chord_y, cx + 5.0, face, 1.4, chords[r][1]],
			["PY%s-TW" % r, e.tube - 1.6, e.side * SPINE_Y, e.tube - 1.6, face, 0.5, ""],
			["PY%s-TE" % r, e.tube + 1.6, e.side * SPINE_Y, e.tube + 1.6, face, 0.5, ""],
		]
		for pp in parts:
			var a := Vector2(pp[1], pp[2])
			var b := Vector2(pp[3], pp[4])
			var nrm := (b - a).normalized().orthogonal() * float(pp[5]) * 0.5
			var poly := [[a.x - nrm.x, a.y - nrm.y], [b.x - nrm.x, b.y - nrm.y], [b.x + nrm.x, b.y + nrm.y], [a.x + nrm.x, a.y + nrm.y]]
			var tag: String = pp[0]
			front.append({"cut_speed": 120.0, "density": 2.0, "key": tag, "kind": "beam", "mass": 20.0, "name_key": "p_spar", "poly": poly, "tag": tag})
			var low := str(pp[6])
			if low == "":
				low = _nearest_any(d, a, cls, false)
			d.joints.append({"a": tag, "b": low, "at": [a.x, a.y], "type": "weld"})
			var hi := _nearest(d, cls, b, "house", r, ring_of, [])
			if hi != "":
				d.joints.append({"a": tag, "b": hi, "at": [b.x, b.y], "type": "weld"})
		# the main bearing between the housing's halves (doesn't turn), and on each spoke its lift's
		# two guide rails and a cable tray (they turn with the wheel)
		var br_r: float = maxf(e.g - 0.5, 1.2)
		var circ: Array = []
		for i in 24:
			var a := TAU * (i + 0.5) / 24.0
			circ.append([cx + cos(a) * br_r, cy + sin(a) * br_r])
		var brg := "MBRG-%s" % r
		d.pieces.append({"art": "drum", "art_size": [br_r * 2.0, br_r * 2.0], "art_xf": [1.0, 0.0, 0.0, 1.0, cx - br_r, cy - br_r], "cls": "equip", "cut_speed": 120.0,
			"density": 1.0, "dest": "equip", "key": brg, "kind": "equip", "mass": 6.0, "name_key": "p_ark_roller", "poly": circ, "tag": brg, "value": 24000.0})
		cls[brg] = "house"
		ring_of[brg] = r
		for side2 in [-1.0, 1.0]:
			var hn := _nearest(d, cls, Vector2(cx, cy + side2 * e.g), "house", r, ring_of, ["MBRG"])
			if hn != "":
				d.joints.append({"a": brg, "b": hn, "at": [cx, cy + side2 * (br_r - 0.2)], "type": "bolt"})
		for rm in d.rooms:
			var nm := str(rm.name)
			if not nm.begins_with("S%s" % r):
				continue
			var sb := _bbox(rm.poly)
			var k2 := 0
			for rx in [sb.position.x + 0.15, sb.end.x - 0.27]:
				k2 += 1
				var rt_tag := "SRL-%s%d" % [nm, k2]
				d.pieces.append({"cut_speed": 200.0, "density": 2.0, "key": rt_tag, "kind": "strut", "mass": 0.4, "name_key": "p_post", "room": nm,
					"poly": [[rx, sb.position.y + 0.3], [rx + 0.12, sb.position.y + 0.3], [rx + 0.12, sb.end.y - 0.3], [rx, sb.end.y - 0.3]], "tag": rt_tag})
				cls[rt_tag] = "wheel"
				ring_of[rt_tag] = r
				var hw := _nearest(d, cls, Vector2(rx, sb.get_center().y), "wheel", r, ring_of, ["SRL", "CTR"])
				if hw != "":
					d.joints.append({"a": rt_tag, "b": hw, "at": [rx + 0.06, sb.get_center().y], "type": "bolt"})
			var ct_tag := "CTR-%s" % nm
			var tx: float = sb.get_center().x - 0.2
			d.pieces.append({"art": "overhead", "art_size": [sb.size.y - 1.0, 0.4], "art_xf": [0.0, 1.0, -1.0, 0.0, tx + 0.4, sb.position.y + 0.5], "cls": "equip", "cut_speed": 140.0,
				"density": 1.0, "dest": "equip", "key": ct_tag, "kind": "equip", "mass": 0.1, "name_key": "p_ark_overhead", "room": nm,
				"poly": [[tx, sb.position.y + 0.5], [tx + 0.4, sb.position.y + 0.5], [tx + 0.4, sb.end.y - 0.5], [tx, sb.end.y - 0.5]], "tag": ct_tag, "value": 600.0})
			cls[ct_tag] = "wheel"
			ring_of[ct_tag] = r
			var hc := _nearest(d, cls, Vector2(tx, sb.get_center().y), "wheel", r, ring_of, ["CTR"])
			if hc != "":
				d.joints.append({"a": ct_tag, "b": hc, "at": [tx + 0.2, sb.get_center().y], "type": "bolt"})
	d.pieces = front + d.pieces
	# the rings' config: where they are now, what turns
	var rc: Dictionary = d.rings
	for r in R:
		var e: Dictionary = R[r]
		var rg: Dictionary = rc.rings[r]
		rg.hub = [e.cx, inf[r].cy]
		rg.radius = inf[r].rout
		rg.rpm = e.rpm
		rg.decel = e.decel
		rg.dir = e.dir
		rg.sweep = inf[r].sweep
		rg.area = []
		var mem: Array = []
		var house: Array = []
		for t in cls:
			if ring_of[t] == r:
				(mem if cls[t] == "wheel" else house).append(t)
		rg.members = mem
		rg.housing = house
		rg.inch = "INCH-%s" % r
	rc.cap_k = 0.55
	rc.mismatch = 0.2
	rc.wheels = true
	return d


static func _nearest(d: Dictionary, cls: Dictionary, at: Vector2, want: String, r: String, ring_of: Dictionary, skip: Array) -> String:
	var best := ""
	var bd := INF
	for pd in d.pieces:
		var t := str(pd.tag)
		if cls.get(t, "") != want or ring_of.get(t, "") != r:
			continue
		var bad := false
		for s in skip:
			if t.begins_with(s):
				bad = true
		if bad:
			continue
		var dd := _bbox(pd.poly).get_center().distance_to(at)
		if dd < bd:
			bd = dd
			best = t
	return best


static func _nearest_any(d: Dictionary, at: Vector2, cls: Dictionary, moved: bool) -> String:
	var best := ""
	var bd := INF
	for pd in d.pieces:
		var t := str(pd.tag)
		if cls.has(t) != moved:
			continue
		var dd := _bbox(pd.poly).get_center().distance_to(at)
		if dd < bd:
			bd = dd
			best = t
	return best


static func _arc_pt(cx: float, cy: float, side: float, t: float, rr: float) -> Array:
	return [cx + side * sin(t) * rr, cy - cos(t) * rr]


static func _bar(a: Array, b: Array, hw: float) -> Array:
	var dv := Vector2(float(b[0]) - float(a[0]), float(b[1]) - float(a[1])).normalized().orthogonal() * hw
	return [[a[0] - dv.x, a[1] - dv.y], [b[0] - dv.x, b[1] - dv.y], [b[0] + dv.x, b[1] + dv.y], [a[0] + dv.x, a[1] + dv.y]]


# ---------------------------------------------------------------- dressing the rim modules
# The old rim modules (old coordinates, before the move): each deck 5-6 m tall had one row of
# equipment on its floor. Filled the way the rest of the ship is: a duct / cable tray run under
# each ceiling, wall cabinets and panels at mid height, the floor's gaps filled with what the
# module is for (cabins: lockers, shelves, crates; galley: shelves, water; life support: traps,
# panels, pumps; the farm: water treatment, traps, crates), an upper berth over each bed, the
# cold store's crates two high. Each bolted to the deck or wall it stands on (or the crate under it).

const DRESS := {
	"AU": {"room": "RAU", "x": [68.6, 101.4], "floors": [-113.35, -107.85, -101.85], "ceils": [-108.15, -102.15, -96.6], "up": 1.0},
	"AL": {"room": "RAL", "x": [68.6, 101.4], "floors": [113.35, 107.85, 101.85], "ceils": [108.15, 102.15, 96.6], "up": -1.0},
	"BU": {"room": "RBU", "x": [168.6, 217.4], "floors": [-121.35, -114.85, -107.85], "ceils": [-115.15, -108.15, -100.6], "up": 1.0},
	"BL": {"room": "RBL", "x": [168.6, 217.4], "floors": [121.35, 114.85, 107.85], "ceils": [115.15, 108.15, 100.6], "up": -1.0},
}
# [template tag, width, height] by ring and deck (0 outer .. 2 inner)
const FLOOR_KIT := {
	"A": [[["LOCK-86", 0.9, 1.9], ["EFFE-94", 0.6, 0.5], ["SHEL-445", 1.2, 1.4]],
		[["SHEL-445", 1.2, 1.4], ["DISP-463", 0.6, 1.2], ["LOCK-86", 0.9, 1.9]],
		[["TRAP-128", 0.6, 0.8], ["PANE-93", 0.8, 1.0], ["PMP-L1", 1.8, 1.6]]],
	"B": [[["WT-8", 2.2, 2.4], ["TRAP-128", 0.6, 0.8], ["EFFE-94", 0.6, 0.5]],
		[["EFFE-94", 0.6, 0.5], ["SHEL-445", 1.2, 1.4], ["LOCK-86", 0.9, 1.9]],
		[["PMP-L1", 1.8, 1.6], ["TRAP-128", 0.6, 0.8], ["PANE-93", 0.8, 1.0]]],
}
const WALL_KIT := [["SHEL-445", 1.2, 0.6], ["PANE-93", 0.8, 0.8], ["SHEL-445", 1.6, 0.6]]
const STRUCT := ["hull", "deck", "beam", "strut"]


static func _dress(d: Dictionary) -> void:
	var tpl := {}
	for pd in d.pieces:
		tpl[str(pd.tag)] = pd
	var n_new := [0]
	for key in DRESS:
		var m: Dictionary = DRESS[key]
		var ring: String = key.left(1)
		var x0: float = m.x[0] + 0.7
		var x1: float = m.x[1] - 0.7
		var up: float = m.up
		var lo_y: float = minf(m.floors[0], m.ceils[2])
		var hi_y: float = maxf(m.floors[0], m.ceils[2])
		var occ: Array = []          # Rect2 of what is in the module already
		var structs: Array = []
		for pd in d.pieces:
			var bb := _bbox(pd.poly)
			if bb.end.x < m.x[0] or bb.position.x > m.x[1] or bb.end.y < lo_y - 0.5 or bb.position.y > hi_y + 0.5:
				continue
			if str(pd.kind) in STRUCT:
				structs.append(pd)
				if str(pd.kind) in ["hull", "deck"]:
					continue
			occ.append(bb.grow(0.12))
		for deck in 3:
			var fl: float = m.floors[deck]
			var ce: float = m.ceils[deck]
			# upper berths over the beds (cabins)
			if ring == "A" and deck == 0:
				for pd in d.pieces.duplicate():
					if str(pd.get("art", "")) == "bed" and str(pd.get("room", "")) == m.room:
						var bb := _bbox(pd.poly)
						var y_a: float = fl + up * 1.45
						var y_b: float = fl + up * 2.95
						_add(d, tpl, "BUNK-98", bb.position.x, minf(y_a, y_b), bb.end.x, maxf(y_a, y_b), m.room, occ, structs, Vector2(bb.get_center().x, fl - up * 0.15), n_new)
			# the ceiling run
			var cy_a: float = ce - up * 0.05
			var cy_b: float = ce - up * 0.55
			_fill_band(d, tpl, [["OVER-88", 3.0, 0.5], ["OVER-88", 2.2, 0.5]], x0, x1, minf(cy_a, cy_b), maxf(cy_a, cy_b), up > 0.0, m.room, occ, structs, ce + up * 0.15, 0.6, n_new)
			# wall cabinets and panels at mid height (where the deck is tall enough)
			if absf(ce - fl) > 4.0:
				var wy_a: float = ce - up * 1.55
				var wy_b: float = ce - up * 0.95
				_fill_band(d, tpl, WALL_KIT, x0, x1, minf(wy_a, wy_b), maxf(wy_a, wy_b), up > 0.0, m.room, occ, structs, ce + up * 0.15, 2.2, n_new)
			# the floor's gaps
			_fill_floor(d, tpl, FLOOR_KIT[ring][deck], x0, x1, fl, up, m.room, occ, structs, n_new)
	# the cold store: crates two high in its gaps
	for rm in d.rooms:
		if str(rm.name) != "CS":
			continue
		var sb := _bbox(rm.poly)
		var cs_structs: Array = []
		var cs_occ: Array = []
		for pd in d.pieces:
			var bb := _bbox(pd.poly)
			if not bb.intersects(sb.grow(0.4)):
				continue
			if str(pd.kind) in STRUCT:
				cs_structs.append(pd)
			else:
				cs_occ.append(bb.grow(0.12))
		_fill_floor(d, tpl, [["EFFE-94", 0.6, 0.5], ["EFFE-94", 0.6, 0.5]], sb.position.x + 0.3, sb.end.x - 0.3, sb.end.y - 0.05, -1.0, "CS", cs_occ, cs_structs, n_new, 2)


# fill the gaps of a horizontal band [ya, yb] between x0 and x1 with the kit's items in turn;
# items hang from the band's ceiling side (top: the ceiling is the band's high-y edge when up > 0)
static func _fill_band(d: Dictionary, tpl: Dictionary, kit: Array, x0: float, x1: float, ya: float, yb: float, ceil_high: bool, room: String, occ: Array,
		structs: Array, mount_y: float, gap: float, n_new: Array) -> void:
	var x := x0
	var i := 0
	var guard := 0
	while x < x1 - 0.4 and guard < 400:
		guard += 1
		var it: Array = kit[i % kit.size()]
		var w: float = it[1]
		var h: float = minf(float(it[2]), yb - ya)
		var r := Rect2(x, yb - h if ceil_high else ya, w, h)
		if r.end.x > x1:
			break
		var hit := false
		for o in occ:
			if (o as Rect2).intersects(r):
				hit = true
				x = maxf(x + 0.3, (o as Rect2).end.x + 0.05)
				break
		if hit:
			continue
		_add(d, tpl, str(it[0]), r.position.x, r.position.y, r.end.x, r.end.y, room, occ, structs, Vector2(r.get_center().x, mount_y), n_new)
		x = r.end.x + gap
		i += 1


# fill a floor's gaps: items stand on the floor (up: the way into the room), stacked `stack` high
static func _fill_floor(d: Dictionary, tpl: Dictionary, kit: Array, x0: float, x1: float, fl: float, up: float, room: String, occ: Array,
		structs: Array, n_new: Array, stack: int = 1) -> void:
	var x := x0
	var i := 0
	var guard := 0
	while x < x1 - 0.4 and guard < 400:
		guard += 1
		var it: Array = kit[i % kit.size()]
		var w: float = it[1]
		var h: float = it[2]
		var ya: float = fl + up * 0.05
		var yb: float = fl + up * (0.05 + h * stack)
		var r := Rect2(x, minf(ya, yb), w, absf(yb - ya))
		if r.end.x > x1:
			break
		var hit := false
		for o in occ:
			if (o as Rect2).intersects(r):
				hit = true
				x = maxf(x + 0.3, (o as Rect2).end.x + 0.05)
				break
		if hit:
			continue
		var below := ""
		for k in stack:
			var sa: float = fl + up * (0.05 + h * k)
			var sb2: float = fl + up * (0.05 + h * (k + 1))
			below = _add(d, tpl, str(it[0]), x, minf(sa, sb2), x + w, maxf(sa, sb2), room, occ, structs, Vector2(x + w * 0.5, fl - up * 0.15), n_new, below)
		x += w + 0.3
		i += 1


static func _add(d: Dictionary, tpl: Dictionary, from: String, x0: float, y0: float, x1: float, y1: float, room: String, occ: Array, structs: Array,
		mount: Vector2, n_new: Array, on: String = "") -> String:
	if not tpl.has(from):
		return ""
	var pd: Dictionary = tpl[from].duplicate(true)
	n_new[0] += 1
	var tag := "WX-%d" % n_new[0]
	pd.tag = tag
	pd.key = tag
	pd.erase("mandatory")
	pd.poly = [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]
	pd.room = room
	if pd.has("art"):
		pd.art_size = [x1 - x0, y1 - y0]
		pd.art_xf = [1.0, 0.0, 0.0, 1.0, x0, y0]
	# small fittings: worth a fraction of the template's (the job's worth is in the big machines)
	if pd.has("value"):
		pd.value = minf(float(pd.value), 1500.0) * 0.5
	d.pieces.append(pd)
	occ.append(Rect2(x0, y0, x1 - x0, y1 - y0).grow(0.12))
	var host := on
	var at := Vector2((x0 + x1) * 0.5, y0)
	if host == "":
		at = mount
		var bd := INF
		for s in structs:
			var bb := _bbox(s.poly)
			var dd: float = 0.0 if bb.grow(0.05).has_point(mount) else bb.get_center().distance_to(mount) + 1000.0
			if dd < bd:
				bd = dd
				host = str(s.tag)
	if host != "":
		d.joints.append({"a": tag, "b": host, "at": [at.x, at.y], "type": "bolt"})
	return tag
