class_name Orbits
# Heliocentric two-body mechanics for the shipping (design/…/23 Q7/Q8, 31 号): the Sun, Mars and
# Jupiter for reference, the port and ten belt stations on Kepler ellipses in the ecliptic,
# freighters on Lambert transfers. Units: AU, days; Δv shown in km/s. Scalars are 64-bit floats
# throughout (Vector2 is 32-bit: kept for drawing only).
# The clock: a day and a half of orbit time to one second of play (Q8: a near station ~1 min;
# the best runs top out near 270 days, ~3 min), the true days shown beside it.

const MU := 2.959122082855911e-4    # AU³/day²: the Sun's GM
const KMS := 1731.456837            # km/s per AU/day
const DAYS_PER_S := 1.5            # orbit days per second of play

# [id, zh, en, a (AU), e, ϖ longitude of perihelion (°), M0 mean anomaly at day 0 (°)]
const PLANETS := [
	# user 2026-10-26: "那些行星、地球什么的，你也加上" — the inner planets too (J2000 elements)
	["mercury", "水星", "MERCURY", 0.3871, 0.2056, 77.46, 174.8],
	["venus", "金星", "VENUS", 0.7233, 0.0068, 131.6, 50.1],
	["earth", "地球", "EARTH", 1.0000, 0.0167, 102.9, 357.5],
	["mars", "火星", "MARS", 1.5237, 0.0934, 336.04, 19.4],
	["jupiter", "木星", "JUPITER", 5.2034, 0.0484, 14.75, 140.0],
]
const PORT := ["port", "零压港", "ZERO PRESSURE PORT", 2.58, 0.06, 120.0, 0.0]
# the belt stations, after the real bodies they sit by (elements rounded from the real ones)
const STATIONS := [
	["ceres", "谷神星站", "CERES STATION", 2.767, 0.079, 153.9, 95.0],
	["vesta", "灶神星站", "VESTA STATION", 2.362, 0.089, 255.0, 205.0],
	["pallas", "智神星站", "PALLAS STATION", 2.773, 0.230, 123.0, 310.0],
	["hygiea", "健神星站", "HYGIEA STATION", 3.142, 0.112, 235.5, 40.0],
	["juno", "婚神星站", "JUNO STATION", 2.669, 0.257, 58.0, 150.0],
	["psyche", "灵神星站", "PSYCHE STATION", 2.924, 0.134, 19.0, 265.0],
	["eunomia", "司法星站", "EUNOMIA STATION", 2.643, 0.187, 31.0, 20.0],
	["davida", "戴维星站", "DAVIDA STATION", 3.165, 0.190, 84.8, 175.0],
	["interamnia", "英特拉姆尼亚站", "INTERAMNIA STATION", 3.060, 0.155, 15.0, 330.0],
	["themis", "司理星站", "THEMIS STATION", 3.130, 0.130, 143.0, 250.0],
]


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func name_of(el: Array) -> String:
	return el[1] if Txt.zh else el[2]


static func station(i: int) -> Array:
	return STATIONS[posmod(i, STATIONS.size())]


# position and velocity on an ellipse at a day: [x, y, vx, vy]
static func state(el: Array, day: float) -> Array:
	var a: float = el[3]
	var e: float = el[4]
	var varpi := deg_to_rad(float(el[5]))
	var n := sqrt(MU / (a * a * a))
	var m := fposmod(deg_to_rad(float(el[6])) + n * day, TAU)
	var big_e := m if e < 0.8 else PI
	for i in 30:
		var d := (big_e - e * sin(big_e) - m) / (1.0 - e * cos(big_e))
		big_e -= d
		if absf(d) < 1e-13:
			break
	var ce := cos(big_e)
	var se := sin(big_e)
	var b := a * sqrt(1.0 - e * e)
	# in the orbit's own frame (perihelion on +x), then turned by ϖ
	var px := a * (ce - e)
	var py := b * se
	var edot := n / (1.0 - e * ce)
	var vx := -a * se * edot
	var vy := b * ce * edot
	var c := cos(varpi)
	var s := sin(varpi)
	return [px * c - py * s, px * s + py * c, vx * c - vy * s, vx * s + vy * c]


static func pos(el: Array, day: float) -> Vector2:
	var st := state(el, day)
	return Vector2(st[0], st[1])


static func period(el: Array) -> float:
	var a: float = el[3]
	return TAU * sqrt(a * a * a / MU)


# Stumpff functions
static func _c(z: float) -> float:
	if z > 1e-8:
		return (1.0 - cos(sqrt(z))) / z
	if z < -1e-8:
		return (cosh(sqrt(-z)) - 1.0) / -z
	return 0.5 - z / 24.0


static func _s(z: float) -> float:
	if z > 1e-8:
		var sz := sqrt(z)
		return (sz - sin(sz)) / (sz * sz * sz)
	if z < -1e-8:
		var sz := sqrt(-z)
		return (sinh(sz) - sz) / (sz * sz * sz)
	return 1.0 / 6.0 - z / 120.0


# where a body starting at r0, v0 is dt days later (universal variables; any conic): [x, y, vx, vy]
static func propagate(r0: Array, v0: Array, dt: float) -> Array:
	var x0: float = r0[0]
	var y0: float = r0[1]
	var vx0: float = v0[0]
	var vy0: float = v0[1]
	var r := sqrt(x0 * x0 + y0 * y0)
	var vr := (x0 * vx0 + y0 * vy0) / r
	var alpha := 2.0 / r - (vx0 * vx0 + vy0 * vy0) / MU
	var smu := sqrt(MU)
	var chi := smu * absf(alpha) * dt
	for i in 60:
		var z := alpha * chi * chi
		var c := _c(z)
		var s := _s(z)
		var f := r * vr / smu * chi * chi * c + (1.0 - alpha * r) * chi * chi * chi * s + r * chi - smu * dt
		var df := r * vr / smu * chi * (1.0 - alpha * chi * chi * s) + (1.0 - alpha * r) * chi * chi * c + r
		var d := f / df
		chi -= d
		if absf(d) < 1e-12:
			break
	var z2 := alpha * chi * chi
	var ff := 1.0 - chi * chi / r * _c(z2)
	var gg := dt - chi * chi * chi / smu * _s(z2)
	var x := ff * x0 + gg * vx0
	var y := ff * y0 + gg * vy0
	var r2 := sqrt(x * x + y * y)
	var fd := smu / (r * r2) * (alpha * chi * chi * chi * _s(z2) - chi)
	var gd := 1.0 - chi * chi / r2 * _c(z2)
	return [x, y, fd * x0 + gd * vx0, fd * y0 + gd * vy0]


# the prograde single-revolution transfer from r1 to r2 in tof days: [v1x, v1y, v2x, v2y]
# (universal-variable Lambert; bisection on z, which is monotone in the time of flight)
static func lambert(r1: Array, r2: Array, tof: float) -> Array:
	var x1: float = r1[0]
	var y1: float = r1[1]
	var x2: float = r2[0]
	var y2: float = r2[1]
	var m1 := sqrt(x1 * x1 + y1 * y1)
	var m2 := sqrt(x2 * x2 + y2 * y2)
	var cos_d := clampf((x1 * x2 + y1 * y2) / (m1 * m2), -1.0, 1.0)
	var dth := acos(cos_d)
	if x1 * y2 - y1 * x2 < 0.0:
		dth = TAU - dth
	# a transfer of exactly 180° has no plane: lean it a hair prograde
	if absf(sin(dth)) < 1e-6:
		dth += 1e-4
	var big_a := sin(dth) * sqrt(m1 * m2 / (1.0 - cos(dth)))
	var smu := sqrt(MU)
	var yz := func(z: float) -> float: return m1 + m2 + big_a * (z * _s(z) - 1.0) / sqrt(_c(z))
	var tz := func(z: float) -> float:
		var y: float = yz.call(z)
		if y < 0.0:
			return -1.0
		return (pow(y / _c(z), 1.5) * _s(z) + big_a * sqrt(y)) / smu
	var lo := -40.0 * PI * PI
	var hi := 4.0 * PI * PI - 1e-6
	# y(z) must be positive: raise the lower bound until it is
	if float(yz.call(lo)) < 0.0:
		var a0 := lo
		var b0 := hi
		for i in 100:
			var mid := (a0 + b0) * 0.5
			if float(yz.call(mid)) < 0.0:
				a0 = mid
			else:
				b0 = mid
		lo = b0
	var z := 0.0
	for i in 200:
		z = (lo + hi) * 0.5
		var t: float = tz.call(z)
		if t < 0.0 or t < tof:
			lo = z
		else:
			hi = z
		if hi - lo < 1e-12:
			break
	var y: float = yz.call(z)
	var f := 1.0 - y / m1
	var g := big_a * sqrt(y / MU)
	var gd := 1.0 - y / m2
	return [(x2 - f * x1) / g, (y2 - f * y1) / g, (gd * x2 - x1) / g, (gd * y2 - y1) / g]


# a freighter's run from one body to another leaving now (Q7/Q8): of the single-revolution
# Lambert arcs from 45 days to a year, the one a carrier would fly — the least Δv with each
# day on the way costing as much as COST_PER_DAY km/s (freight is paid on time too); an arc
# is taken only if it really arrives
const COST_PER_DAY := 0.3
# 57 号 (23 号 Q16: "near about a minute, far about six"): the cheapest run first; a run of over
# STRETCH_FROM days is then flown slower — the cheapest real transfer near T × (1 + (T − 100) / 170)
# days — so the far stations take ~6 minutes while the map stays true (the clock is not touched)
const STRETCH_FROM := 100.0
const STRETCH_SPAN := 170.0


const STRETCH_MAX := 540.0      # days: six minutes at the clock's 1.5 days a second


static func stretched(tof: float) -> float:
	return tof if tof <= STRETCH_FROM else minf(STRETCH_MAX, tof * (1.0 + (tof - STRETCH_FROM) / STRETCH_SPAN))


static func transfer(from_el: Array, to_el: Array, day: float) -> Dictionary:
	var best := _transfer(from_el, to_el, day, 45.0, 360.0)
	if best.is_empty() or float(best.tof) <= STRETCH_FROM:
		return best
	var want := stretched(float(best.tof))
	var slow := _transfer(from_el, to_el, day, want - 40.0, want)
	if slow.is_empty():
		return best
	slow.tof_fast = float(best.tof)
	return slow


static func _transfer(from_el: Array, to_el: Array, day: float, t0: float, t1: float, per_day := COST_PER_DAY) -> Dictionary:
	var s1 := state(from_el, day)
	var best := {}
	var best_cost := INF
	var tof := t0
	while tof <= t1:
		var s2 := state(to_el, day + tof)
		var cross: float = s1[0] * s2[1] - s1[1] * s2[0]
		var dot: float = s1[0] * s2[0] + s1[1] * s2[1]
		# straight across the Sun the arc's plane is undefined
		if dot > 0.0 or absf(atan2(cross, dot)) < PI - 0.05:
			var v := lambert([s1[0], s1[1]], [s2[0], s2[1]], tof)
			var end := propagate([s1[0], s1[1]], [v[0], v[1]], tof)
			if is_finite(v[0]) and Vector2(end[0] - s2[0], end[1] - s2[1]).length() < 1e-4:
				var dv1 := sqrt(pow(v[0] - s1[2], 2) + pow(v[1] - s1[3], 2)) * KMS
				var dv2 := sqrt(pow(v[2] - s2[2], 2) + pow(v[3] - s2[3], 2)) * KMS
				var cost := dv1 + dv2 + per_day * tof
				if cost < best_cost:
					best_cost = cost
					best = {"depart": day, "tof": tof, "r1": [s1[0], s1[1]], "v1": [v[0], v[1]], "dv1": dv1, "dv2": dv2}
		tof += 5.0
	return best


# where a freighter on its transfer is, a share k of the way (0..1)
static func on_transfer(tr: Dictionary, k: float) -> Vector2:
	var st := propagate(tr.r1, tr.v1, float(tr.tof) * clampf(k, 0.0, 1.0))
	return Vector2(st[0], st[1])
