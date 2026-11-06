extends Node2D
# 128 号 第 2 段 (user: "有订单时港口有客户小飞船进出，鼠标悬停能看到是谁、来取什么；美术要和无人机、接驳车一样
# 精细，守惯性"). The order board's clients, seen:
#   - a new order: the client's courier comes in to the trade port's east wall, lies at a visitors'
#     airlock a few seconds (the order is posted) and goes again;
#   - a pick-up: the client's freighter comes into the lighter port under the east wall, the dock's
#     crane swings the order's crates into its hold (scripts/trade_works.gd), and it leaves.
# Strict inertia (feedback-strict-inertia): it speeds up on its main engine, coasts, and brakes on the
# retro thrusters in its bow, the flames drawn as hard as the push; leaving it backs out on the
# retros, turns end for end on its attitude jets while it drifts clear, and burns away. Everything
# follows HallMarket's clock (real time played), so a save reloaded mid-way puts it where it was.
# Side view as the trade port's dock (bow −x into the wall). Drawn in world px with one draw_mesh
# a part; hovering it shows who it is and what it came for (scripts/facility_card.gd).

const MeshPen = preload("res://scripts/mesh_pen.gd")
const FastDraw = preload("res://scripts/fast_draw.gd")
const TW = preload("res://scripts/trade_works.gd")
const FACE := Color(0.118, 0.124, 0.136)
const FACE2 := Color(0.17, 0.178, 0.192)
const DARK := Color(0.06, 0.064, 0.072)
const VOID := Color(0.025, 0.027, 0.031)
const FREIGHTER_L := 16.5        # m, bow to stern (the lighter port's slip)
const COURIER_L := 11.0
const POST_IN := 7.0             # s: a courier in, alongside, out
const POST_HOLD := 5.0
const POST_OUT := 7.0
const FAR := 170.0               # m east of the berth where they come from and go to

static var visits := {}          # new orders' couriers: oid -> {who, what, t0, lock}

var game
var card
var _meshes := {}
var t := 0.0
var drawn := 0                   # tests: ships drawn last frame
var last := []                   # tests: [{oid, kind, pos (world px), flip, main, retro, rcs}]


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


# a new order's courier (HallMarket.tick, when an order is posted)
static func visit(oid: String, who: String, what: String) -> void:
	if visits.size() >= 3:
		return
	var used := {}
	for v in visits.values():
		used[int(v.lock)] = true
	visits[oid] = {"who": who, "what": what, "t0": HallMarket.clock(), "lock": 0 if not used.has(0) else 1}


func _ready() -> void:
	z_index = 5
	z_as_relative = false
	card = preload("res://scripts/facility_card.gd").new()
	card.game = game
	card.items = _items
	add_child(card)


func active() -> bool:
	return game != null and game.in_berth() and game.career() and not Career.data.is_empty() and HallMarket.open()


func _process(dt: float) -> void:
	t += dt
	visible = active()
	HallMarket.watched = visible and game.get("trade_hall") != null and is_instance_valid(game.trade_hall) and game.trade_hall.visible
	var hide := false
	for o in HallMarket.orders():
		if str(o.state) == "ship":
			var ph := HallMarket.ship_phase(o)
			if str(ph[0]) == "load":
				hide = true
				TW.lighter_k = 1.0
				if not TW.job.is_empty() and str(TW.job.id) == "hall:" + str(o.id) and bool(TW.job.done):
					HallMarket.mark_loaded(str(o.id))
	if TW.lighter_hide and not hide:
		# it has left with the crates: no lighter of the old kind follows it out
		TW.lighter_k = 0.0
		TW.hold = 0
		TW.linger = 0.0
	TW.lighter_hide = hide
	for id in visits.keys():
		if HallMarket.clock() - float(visits[id].t0) > POST_IN + POST_HOLD + POST_OUT:
			visits.erase(id)
	if visible:
		queue_redraw()


# ---------------------------------------------------------------- where they are

static func _m() -> float:
	return PortStructure.M()


static func _local(p: Vector2) -> Vector2:
	return PortStructure.box("trade").position + p * _m()


# accelerate, coast, brake over u 0 … 1: the share of the way gone and which engine pushes
# (fractions 0.4 / 0.2 / 0.4; the speed peaks at 1/0.6 of the mean)
static func _profile(u: float) -> Array:
	u = clampf(u, 0.0, 1.0)
	var v := 1.0 / 0.6
	var a := v / 0.4
	if u < 0.4:
		return [0.5 * a * u * u, "main", u / 0.4]
	if u < 0.6:
		return [0.5 * a * 0.16 + v * (u - 0.4), "", 0.0]
	var d := u - 0.6
	return [0.5 * a * 0.16 + v * 0.2 + v * d - 0.5 * a * d * d, "retro", 1.0 - d / 0.4]


# leaving over u 0 … 1: back out on the retros, turn end for end drifting, burn away.
# -> [m gone east, flip 1 (bow −x) … −1 (bow +x), engine, push 0 … 1]
static func _leave(u: float, total: float) -> Array:
	u = clampf(u, 0.0, 1.0)
	var v1 := 5.0
	var ta := 0.35 * total
	var tb := 0.25 * total
	var s := u * total
	if s < ta:
		var half := ta * 0.5
		var a1 := v1 / half
		if s < half:
			return [0.5 * a1 * s * s, 1.0, "retro", 1.0]
		return [0.5 * a1 * half * half + v1 * (s - half), 1.0, "", 0.0]
	var d_a := 0.5 * v1 / (ta * 0.5) * pow(ta * 0.5, 2.0) + v1 * ta * 0.5
	if s < ta + tb:
		var k := (s - ta) / tb
		return [d_a + v1 * (s - ta), cos(PI * smoothstep(0.0, 1.0, k)), "rcs", sin(PI * k)]
	var tc := s - ta - tb
	return [d_a + v1 * tb + v1 * tc + 0.5 * 12.0 * tc * tc, -1.0, "main", 1.0]


# every ship now: [{oid, kind, who, what, at (box m, its centre), flip, eng, push, alpha, len}]
static func ships() -> Array:
	var out: Array = []
	for o in HallMarket.orders():
		if str(o.state) != "ship":
			continue
		var berth := Vector2(52.0 + FREIGHTER_L * 0.5, TW.LIGHTER_Y)
		var ph := HallMarket.ship_phase(o)
		var e := {"phase": str(ph[0]), "crates": int(o.get("crates", 1)), "oid": str(o.id), "kind": "pick", "who": str(o.client), "what": HallMarket.want_name(o), "len": FREIGHTER_L, "flip": 1.0, "eng": "", "push": 0.0, "alpha": 1.0, "say": HallMarket.order_state_text(o)}
		match str(ph[0]):
			"in":
				var pr := _profile(float(ph[1]))
				e.at = berth + Vector2(FAR * (1.0 - float(pr[0])), 0.0)
				e.eng = pr[1]
				e.push = pr[2]
				e.alpha = clampf(float(ph[1]) * 6.0, 0.0, 1.0)
			"load":
				e.at = berth
			_:
				var lv := _leave(float(ph[1]), HallMarket.SHIP_OUT)
				e.at = berth + Vector2(float(lv[0]), 0.0)
				e.flip = lv[1]
				e.eng = lv[2]
				e.push = lv[3]
				e.alpha = clampf((1.0 - float(ph[1])) * 5.0, 0.0, 1.0)
		out.append(e)
	for oid in visits:
		var v: Dictionary = visits[oid]
		var lk: Vector2 = TW.LOCKS[int(v.lock)]
		var berth := Vector2(60.0 + 0.6 + COURIER_L * 0.5, (lk.x + lk.y) * 0.5)
		var s := HallMarket.clock() - float(v.t0)
		var e := {"oid": str(oid), "kind": "post", "who": str(v.who), "what": str(v.what), "len": COURIER_L, "flip": 1.0, "eng": "", "push": 0.0, "alpha": 1.0,
			"say": w("来下新订单", "POSTING A NEW ORDER")}
		if s < POST_IN:
			var pr := _profile(s / POST_IN)
			e.at = berth + Vector2(FAR * (1.0 - float(pr[0])), 0.0)
			e.eng = pr[1]
			e.push = pr[2]
			e.alpha = clampf(s / POST_IN * 6.0, 0.0, 1.0)
		elif s < POST_IN + POST_HOLD:
			e.at = berth
		else:
			var u := (s - POST_IN - POST_HOLD) / POST_OUT
			var lv := _leave(u, POST_OUT)
			e.at = berth + Vector2(float(lv[0]), 0.0)
			e.flip = lv[1]
			e.eng = lv[2]
			e.push = lv[3]
			e.alpha = clampf((1.0 - u) * 5.0, 0.0, 1.0)
		out.append(e)
	return out


# ---------------------------------------------------------------- drawing

func _mesh(key: String, build: Callable) -> ArrayMesh:
	if not _meshes.has(key):
		var pen := MeshPen.new()
		build.call(pen)
		_meshes[key] = pen.mesh()
	return _meshes[key]


static func _ink(a: float) -> Color:
	return Pal.ink(a)


# the client's freighter, side view, its centre at the origin, bow −x. The hold well amidships takes
# the dock's crates (TradeWorks draws them at the lighter's places: 3.0 + i·1.75 m from the bow).
static func build_freighter(p) -> void:
	var L := FREIGHTER_L
	var x0 := -L * 0.5
	var edge := _ink(0.82)
	var hull := PackedVector2Array([Vector2(x0, 0.0), Vector2(x0 + 0.5, 1.6), Vector2(x0 + 1.6, 2.8), Vector2(x0 + 15.0, 2.8), Vector2(x0 + 16.5, 1.2), Vector2(x0 + 16.5, -0.25), Vector2(x0, -0.25)])
	p.poly(hull, Color(0.1, 0.106, 0.118))
	# the lower hull's plating: a darker keel band, the seams and the rivet rows
	p.poly(PackedVector2Array([Vector2(x0 + 1.6, 2.8), Vector2(x0 + 15.0, 2.8), Vector2(x0 + 15.6, 2.15), Vector2(x0 + 1.0, 2.15)]), DARK)
	for k in 6:
		var sx := x0 + 2.6 + k * 2.2
		p.line(Vector2(sx, 0.1), Vector2(sx, 2.75), _ink(0.16), 0.035)
	for k in 26:
		p.circle(Vector2(x0 + 1.4 + k * 0.56, 1.0), 0.04, _ink(0.3), 5)
	p.line(Vector2(x0 + 0.5, 1.6), Vector2(x0 + 16.4, 1.6), _ink(0.2), 0.03)
	# the hold well (open) with its coaming and ribs
	p.rect(Rect2(x0 + 2.5, -0.25, 7.0, 0.4), VOID)
	p.rect(Rect2(x0 + 2.3, -0.55, 0.25, 0.35), FACE2)
	p.rect(Rect2(x0 + 9.45, -0.55, 0.25, 0.35), FACE2)
	for k in 7:
		p.line(Vector2(x0 + 2.9 + k * 1.0, -0.2), Vector2(x0 + 2.9 + k * 1.0, 0.12), _ink(0.22), 0.04)
	# warning hatching on the coaming's lip
	p.hatch(Rect2(x0 + 0.6, 0.3, 9.0, 0.45), Pal.heat(0.38, 1.0), 0.08, 0.6)
	# the wheelhouse aft: glass, a door, the mast with its lamp and aerial
	p.rect(Rect2(x0 + 11.5, -2.8, 3.6, 2.55), FACE2)
	p.rect(Rect2(x0 + 11.75, -2.5, 3.1, 0.75), Pal.tint(Pal.AIR, 0.38, 1.1))
	for k in 3:
		p.line(Vector2(x0 + 12.75 + k * 0.85, -2.5), Vector2(x0 + 12.75 + k * 0.85, -1.75), FACE2, 0.06)
	p.rect(Rect2(x0 + 12.0, -1.45, 0.6, 1.15), DARK)
	p.rect(Rect2(x0 + 12.0, -1.45, 0.6, 1.15), _ink(0.45), false, 0.03)
	p.rect(Rect2(x0 + 11.5, -2.8, 3.6, 2.55), _ink(0.62), false, 0.05)
	p.line(Vector2(x0 + 13.3, -2.8), Vector2(x0 + 13.3, -4.3), _ink(0.6), 0.06)
	p.line(Vector2(x0 + 12.7, -3.7), Vector2(x0 + 13.9, -3.7), _ink(0.45), 0.04)
	p.line(Vector2(x0 + 14.4, -2.8), Vector2(x0 + 14.9, -3.6), _ink(0.4), 0.03)
	# the main engine aft: its mount, the bell (exhaust +x)
	p.rect(Rect2(x0 + 16.3, -0.1, 0.5, 1.6), FACE2)
	p.poly(PackedVector2Array([Vector2(x0 + 16.8, 0.15), Vector2(x0 + 17.9, -0.25), Vector2(x0 + 17.9, 1.75), Vector2(x0 + 16.8, 1.35)]), Color(0.1, 0.098, 0.096))
	p.polyline(PackedVector2Array([Vector2(x0 + 16.8, 0.15), Vector2(x0 + 17.9, -0.25), Vector2(x0 + 17.9, 1.75), Vector2(x0 + 16.8, 1.35)]), _ink(0.6), 0.05, true)
	for k in 3:
		p.line(Vector2(x0 + 17.05 + k * 0.28, 0.05 - k * 0.1), Vector2(x0 + 17.05 + k * 0.28, 1.45 + k * 0.1), _ink(0.22), 0.025)
	# the bow's retro thrusters (exhaust −x) and the attitude jets at the four corners
	for ry in [0.25, 2.0]:
		p.rect(Rect2(x0 + 0.3, ry - 0.22, 0.7, 0.44), FACE2)
		p.poly(PackedVector2Array([Vector2(x0 + 0.3, ry - 0.16), Vector2(x0 - 0.15, ry - 0.26), Vector2(x0 - 0.15, ry + 0.26), Vector2(x0 + 0.3, ry + 0.16)]), DARK)
	for c in [Vector2(x0 + 1.9, -0.4), Vector2(x0 + 14.6, -3.0), Vector2(x0 + 1.9, 2.95), Vector2(x0 + 14.6, 2.95)]:
		p.rect(Rect2(c - Vector2(0.22, 0.14), Vector2(0.44, 0.28)), FACE2)
		p.rect(Rect2(c - Vector2(0.22, 0.14), Vector2(0.44, 0.28)), _ink(0.45), false, 0.025)
	# the fenders along the side, the docking clamp at the bow
	for k in 4:
		p.rect(Rect2(x0 + 1.8 + k * 3.4, 2.75, 1.2, 0.3), Color(0.03, 0.03, 0.035))
	p.rect(Rect2(x0 - 0.35, -0.2, 0.35, 0.6), FACE2)
	# the client's band (the accent) under the wheelhouse
	p.rect(Rect2(x0 + 10.6, 0.25, 5.2, 0.22), Color(UiSkin.ACCENT, 0.75))
	p.polyline(hull, edge, 0.08, true)


# the courier that comes to post an order: a small ship, bow −x to the airlock
static func build_courier(p) -> void:
	var x0 := -COURIER_L * 0.5
	var edge := _ink(0.78)
	var hull := PackedVector2Array([Vector2(x0, 0.0), Vector2(x0 + 2.0, -1.7), Vector2(x0 + 9.6, -1.7), Vector2(x0 + 11.0, -0.9), Vector2(x0 + 11.0, 0.9), Vector2(x0 + 9.6, 1.7), Vector2(x0 + 2.0, 1.7)])
	p.poly(hull, Color(0.085, 0.09, 0.1))
	p.poly(PackedVector2Array([Vector2(x0 + 2.0, 1.7), Vector2(x0 + 9.6, 1.7), Vector2(x0 + 10.4, 1.25), Vector2(x0 + 1.5, 1.25)]), DARK)
	p.poly(PackedVector2Array([Vector2(x0 + 0.9, -0.8), Vector2(x0 + 2.4, -1.45), Vector2(x0 + 3.9, -1.45), Vector2(x0 + 3.9, -0.05), Vector2(x0 + 0.9, -0.05)]), Pal.tint(Pal.AIR, 0.38, 1.1))
	p.line(Vector2(x0 + 2.4, -1.45), Vector2(x0 + 2.4, -0.05), Color(0.085, 0.09, 0.1), 0.06)
	for sx in [5.0, 7.6]:
		p.line(Vector2(x0 + sx, -1.7), Vector2(x0 + sx, 1.7), _ink(0.2), 0.04)
	for k in 14:
		p.circle(Vector2(x0 + 2.4 + k * 0.52, 0.55), 0.035, _ink(0.28), 5)
	p.rect(Rect2(x0 + 0.15, -0.55, 0.45, 1.1), FACE2)
	p.rect(Rect2(x0 + 0.15, -0.55, 0.45, 1.1), _ink(0.5), false, 0.03)
	for ky in [-0.8, 0.8]:
		p.poly(PackedVector2Array([Vector2(x0 + 11.0, ky - 0.45), Vector2(x0 + 12.3, ky - 0.72), Vector2(x0 + 12.3, ky + 0.72), Vector2(x0 + 11.0, ky + 0.45)]), Color(0.1, 0.098, 0.096))
		p.polyline(PackedVector2Array([Vector2(x0 + 11.0, ky - 0.45), Vector2(x0 + 12.3, ky - 0.72), Vector2(x0 + 12.3, ky + 0.72), Vector2(x0 + 11.0, ky + 0.45)]), _ink(0.55), 0.04, true)
	for ry in [-1.0, 1.0]:
		p.rect(Rect2(x0 + 0.9, ry - 0.18, 0.55, 0.36), FACE2)
	for c in [Vector2(x0 + 8.8, -1.85), Vector2(x0 + 8.8, 1.85)]:
		p.rect(Rect2(c - Vector2(0.2, 0.12), Vector2(0.4, 0.24)), FACE2)
	p.rect(Rect2(x0 + 6.0, -0.15, 3.2, 0.2), Color(UiSkin.ACCENT, 0.7))
	p.polyline(hull, edge, 0.08, true)


# a plume: from `at` along `dir` (unit), `len` m long, its width at the nozzle `wid` m
func _plume(at: Vector2, dir: Vector2, length: float, wid: float, k: float) -> void:
	if k <= 0.02:
		return
	var m := _m()
	var flick := 0.85 + 0.15 * sin(t * 47.0 + at.x) * sin(t * 31.0)
	var n := dir.orthogonal()
	var tip := at + dir * length * k * flick * m
	var a := at + n * wid * 0.5 * m
	var b := at - n * wid * 0.5 * m
	draw_colored_polygon(PackedVector2Array([a, tip, b]), Pal.heat(0.55 * k, 1.4))
	var tip2 := at + dir * length * 0.5 * k * flick * m
	draw_colored_polygon(PackedVector2Array([at + n * wid * 0.25 * m, tip2, at - n * wid * 0.25 * m]), Pal.tint(Pal.AIR, 0.8 * k, 1.8))


func _draw() -> void:
	drawn = 0
	last = []
	if not visible:
		return
	var m := _m()
	var box := PortStructure.box("trade")
	for e in ships():
		var at := box.position + (e.at as Vector2) * m
		if not ViewCull.sees(game, Rect2(at - Vector2(12, 6) * m, Vector2(24, 12) * m)):
			continue
		var flip := float(e.flip)
		var sx := flip if absf(flip) > 0.04 else 0.04 * signf(flip if flip != 0.0 else 1.0)
		var a := float(e.alpha)
		var mesh := _mesh("freighter", build_freighter) if str(e.kind) == "pick" else _mesh("courier", build_courier)
		# its shadow on the deck plating below (and a plain fill first: a canvas item whose first
		# command is a mesh was not drawn at all)
		draw_rect(Rect2(at + Vector2(-float(e.len) * 0.5 + 0.6, 3.2) * m, Vector2(float(e.len) - 1.2, 0.5) * m), Color(0, 0, 0, 0.18 * float(e.alpha)))
		var half := float(e.len) * 0.5
		var eng := str(e.eng)
		var push := float(e.push)
		# the push: the main engine's plume aft (away from the bow), the retros' forward, the jets' puffs
		var aft := Vector2(signf(sx), 0.0)
		if eng == "main":
			if str(e.kind) == "pick":
				_plume(at + Vector2((half + 1.4) * sx, 0.75) * m, aft, 6.5, 1.6, push * a)
			else:
				for ky in [-0.8, 0.8]:
					_plume(at + Vector2((half + 1.3) * sx, ky) * m, aft, 4.5, 1.1, push * a)
		elif eng == "retro":
			var ys := [0.25, 2.0] if str(e.kind) == "pick" else [-1.0, 1.0]
			for ry in ys:
				_plume(at + Vector2((-half - 0.15) * sx, float(ry)) * m, -aft, 2.6, 0.45, push * a)
		elif eng == "rcs":
			var cs := [Vector2(-half + 1.9, -0.4), Vector2(half - 1.9, 2.95)] if str(e.kind) == "pick" else [Vector2(-half + 2.0, -1.85), Vector2(half - 2.2, 1.85)]
			for i in cs.size():
				var c: Vector2 = cs[i]
				_plume(at + Vector2(c.x * sx, c.y) * m, Vector2(0.0, -1.0 if i == 0 else 1.0), 1.2, 0.3, push * a)
		draw_mesh(mesh, null, Transform2D(0.0, Vector2(sx * m, m), 0.0, at), Color(1, 1, 1, a))
		# leaving, the order's crates ride in its hold
		if str(e.kind) == "pick" and str(e.get("phase", "")) == "out":
			for i in int(e.get("crates", 1)):
				var cx := (-half + 3.0 + i * 1.75 + TW.CRATE.x * 0.5) * sx
				var r := Rect2(at + Vector2(cx - TW.CRATE.x * 0.5 * absf(sx), -TW.CRATE.y) * m, Vector2(TW.CRATE.x * absf(sx), TW.CRATE.y) * m)
				draw_rect(r, Color(FACE2, a))
				draw_rect(r, Pal.ink(0.6 * a), false, 1.0)
		# its lamps: the masthead lamp blinks, the bow's clearance lamp steady
		var blink := 1.0 if fmod(t + float(e.at.x) * 0.01, 1.4) < 0.18 else 0.25
		if str(e.kind) == "pick":
			FastDraw.circle(self, at + Vector2((-half + 13.3) * sx, -4.3) * m, 0.16 * m, Pal.heat(blink * a, 1.6))
			FastDraw.circle(self, at + Vector2((-half - 0.2) * sx, -0.1) * m, 0.11 * m, Pal.tint(Pal.AIR, 0.8 * a, 1.5))
		else:
			FastDraw.circle(self, at + Vector2((-half + 8.0) * sx, -1.8) * m, 0.13 * m, Pal.heat(blink * a, 1.6))
		drawn += 1
		last.append({"oid": str(e.oid), "kind": str(e.kind), "pos": at, "flip": flip, "eng": eng, "push": push})


# ---------------------------------------------------------------- hover

func _items() -> Array:
	if not visible:
		return []
	var out: Array = []
	var m := _m()
	var box := PortStructure.box("trade")
	for e in ships():
		var at := box.position + (e.at as Vector2) * m
		var half := float(e.len) * 0.5 + 1.5
		var pick := str(e.kind) == "pick"
		out.append({"rect": Rect2(at - Vector2(half, 4.5) * m, Vector2(half * 2.0, 8.0) * m),
			"title": (w("%s 的货船", "%s'S FREIGHTER") if pick else w("%s 的小飞船", "%s'S COURIER")) % str(e.who),
			"use": (w("来取订单的货：%s", "COMING FOR AN ORDER: %s") if pick else w("来订单板下单：%s", "POSTING AN ORDER: %s")) % str(e.what),
			"now": str(e.say),
			"can": w("订单板（F8 · 订单）里接单，仓库自动备货，货运火车送到贸易港，它来取走。", "Take orders on the order board (F8 · ORDERS): the stores make them up, the freight train brings them to the trade port, a ship like this takes them."),
			"lamp": "work"})
	return out
