extends RefCounted
# 无人机外观款式（用户 2026-11-10：“再多增加 5 个样式，都要和现在这样一样酷炫”）。
# 阶段一设计稿：五款新机体的程序画法。数值、手感、碰撞体（半径 20）完全不变，
# 只换外形、推进火焰、头灯、机械臂与抓钩、强调色和声音参数。
# 所有新款都在机体自己的坐标系里画（x 指向机头），开头把画布转到机头方向，
# 共用 scripts/drone_art.gd 的光圈镜头、工具头、描边、细节开关（lite）。
# 喷口表 jets() 由画法和粒子共用：[位置, 喷出方向, 强度 0..1, 口径, 火焰样式]，
# 推力换算与原版一致（加速向前推 → 尾焰；减速 → 反推；侧推 → 对侧喷）。
#   st 与 drone_art.gd 相同：heading tool open t thrust dash boot base_xf

const Art = preload("res://scripts/drone_art.gd")
const FastDraw = preload("res://scripts/fast_draw.gd")
const HULL := Art.HULL
const HULL_HI := Art.HULL_HI
const HULL_LO := Color(0.045, 0.048, 0.056)

# 款式表（名字为占位稿，等用户定稿）
#   accent  强调色（只用在灯带、涂装、指示灯；工具色仍归工具，是玩法信息）
#   flame   火焰样式   lamp 头灯：[光色, 光锥宽度倍数, 射程倍数, 形状说明]
#   sound   只改已有素材的参数：推进循环音高、抓取/出舱单次音高
#   price   建议售价（原版 0）
const SKINS := {
	"arrowring": {"zh": "H1 箭环", "en": "H1 ARROW-RING", "accent": Color(0.95, 0.96, 1.0), "flame": "torch",
		"lamp": [Color(0.86, 0.93, 1.0), 1.0, 1.0], "sound": [1.0, 1.0], "price": 0},
	"anvil": {"zh": "铁砧 HX-6", "en": "ANVIL HX-6", "accent": Color(1.0, 0.72, 0.16), "flame": "bell",
		"lamp": [Color(1.0, 0.9, 0.72), 1.55, 0.8], "sound": [0.78, 0.85], "price": 25000},
	"swift": {"zh": "雨燕 R7", "en": "SWIFT R7", "accent": Color(0.58, 1.0, 0.3), "flame": "needle",
		"lamp": [Color(0.9, 1.0, 0.92), 0.55, 1.35], "sound": [1.28, 1.15], "price": 38000},
	"greyhawk": {"zh": "灰隼 M-07", "en": "GREYHAWK M-07", "accent": Color(1.0, 0.2, 0.28), "flame": "petal",
		"lamp": [Color(1.0, 0.78, 0.8), 0.8, 1.1], "sound": [0.92, 0.9], "price": 52000},
	"astrolabe": {"zh": "星盘 SR-3", "en": "ASTROLABE SR-3", "accent": Color(0.68, 0.56, 1.0), "flame": "ion",
		"lamp": [Color(0.86, 0.84, 1.0), 1.25, 1.0], "sound": [1.12, 1.25], "price": 64000},
	"patchwork": {"zh": "拼板", "en": "PATCHWORK", "accent": Color(0.34, 0.9, 0.74), "flame": "sputter",
		"lamp": [Color(1.0, 0.86, 0.55), 1.0, 0.9], "sound": [0.88, 0.95], "price": 80000},
}
const ORDER := ["arrowring", "anvil", "swift", "greyhawk", "astrolabe", "patchwork"]
const DEFAULT := "arrowring"

# 2026-11-10 用户：“他们各自激光颜色也改一下吧”。Each airframe's beam: [hue, white-hot core].
# H1 keeps the stock beam (Pal.heat and the original cores). Only the beam itself — the beam,
# its core and halo, the light at the cut's edge, the sparks, the pending kerfs, the hit flash,
# the cutaway's laser light — not the colour of hot metal, which is the material's own.
const LASER := {
	"anvil": [Color(1.0, 0.7, 0.08), Color(2.1, 1.9, 1.15)],      # amber
	"swift": [Color(0.32, 1.0, 0.22), Color(1.55, 2.2, 1.45)],    # green
	"greyhawk": [Color(1.0, 0.07, 0.4), Color(2.3, 1.2, 1.55)],   # crimson (rose, apart from H1's orange and the warning's red)
	"astrolabe": [Color(0.42, 0.36, 1.0), Color(1.55, 1.5, 2.5)], # blue-violet
	"patchwork": [Color(1.0, 0.86, 0.66), Color(2.3, 2.2, 2.0), true],  # warm white (grows evenly: stays white, not orange)
}


# the beam's colour as Pal.heat gives it (a, brightness k): the main hue grows with k, the
# others more slowly, so a bright beam keeps its colour instead of washing white
static func lheat(a: float = 1.0, k: float = 1.0, id: String = "") -> Color:
	if id == "":
		id = current()
	if not LASER.has(id):
		return Pal.heat(a, k)
	var h: Color = LASER[id][0]
	if k <= 1.0:
		return Color(h.r * k, h.g * k, h.b * k, a)
	if (LASER[id] as Array).size() > 2:
		return Color(h.r * k, h.g * k, h.b * k, a)
	var m := maxf(h.r, maxf(h.g, h.b))
	var f := func(ch: float) -> float: return ch * k if ch >= m * 0.99 else ch * (1.0 + (k - 1.0) * 0.3)
	return Color(f.call(h.r), f.call(h.g), f.call(h.b), a)


# a white-hot part of the beam: the stock colour given, turned to this airframe's core at the
# same brightness and alpha
static func lcore(stock: Color, id: String = "") -> Color:
	if id == "":
		id = current()
	if not LASER.has(id):
		return stock
	var c: Color = LASER[id][1]
	var b := maxf(stock.r, maxf(stock.g, stock.b)) / maxf(c.r, maxf(c.g, c.b))
	return Color(c.r * b, c.g * b, c.b * b, stock.a)

# 中文为占位稿，等用户定稿
const BLURB := {
	"arrowring": ["原版机体。箭头底盘托着旋转环核，翼尖双主推，口器式双爪。", "The stock airframe: an arrow chassis round a turning ring core, twin mains at the wing tips, mandible claws."],
	"anvil": ["重型工业拖曳。方厚装甲箱体、黄黑警示推杆、液压臂配三指重爪，双方灯照得宽。", "Heavy tow rig: an armoured box with a striped push bumper, hydraulic arms with three-finger grabs, twin floodlamps."],
	"swift": ["轻量竞速。针形机身、后掠翼，尾部单大主推带激波环，铅笔光束照得远。", "Light racer: a needle fuselage and swept wings, one big main with shock diamonds, a pencil beam that reaches far."],
	"greyhawk": ["军用退役改装。多面机身涂装磨掉、炮管锯断封口，矢量喷口和反推门，红色缝隙面罩灯。", "Ex-military refit: a faceted airframe sanded bare, the gun cut and capped, vectoring nozzles and reverser doors, a red slit visor."],
	"astrolabe": ["科研探测。仪器圆盘带扫描环，前置抛物面天线兼环形灯，离子主推、冷气微推，伸缩采样臂。", "Survey craft: an instrument disc with a scan ring, a dish with a ring lamp, ion mains and cold-gas puffers, telescoping arms."],
	"patchwork": ["老式手工拼装。拼接板、铆钉、胶带和外露管线，两台不一样大的发动机会咳嗽，老车灯，一边吊钩一边钳子。", "Home-built: riveted patches, tape and bare pipes, two mismatched engines that cough, an old car headlamp, a hook and a pair of pliers."],
}


static func name_of(id: String) -> String:
	var sk: Dictionary = SKINS.get(id, SKINS[DEFAULT])
	return str(sk.zh) if Txt.zh else str(sk.en)


static func blurb(id: String) -> String:
	var b: Array = BLURB.get(id, BLURB[DEFAULT])
	return str(b[0]) if Txt.zh else str(b[1])


static func price(id: String) -> float:
	return float(SKINS.get(id, {}).get("price", 0))


# the save: "drone_skin" the one flown, "drone_skins" those owned (the stock one always);
# a career from before has neither and flies the stock one
static func owned() -> Array:
	var out: Array = [DEFAULT]
	for id in Career.data.get("drone_skins", []):
		if SKINS.has(str(id)) and not out.has(str(id)):
			out.append(str(id))
	return out


static func owns(id: String) -> bool:
	return owned().has(id)


static func current() -> String:
	var id := str(Career.data.get("drone_skin", DEFAULT))
	return id if SKINS.has(id) and owns(id) else DEFAULT


# buy with the company's funds; "" when done, otherwise why not (the caller shows it)
static func buy(id: String) -> String:
	if not SKINS.has(id):
		return "?"
	if owns(id):
		return words("已拥有", "ALREADY OWNED")
	var d := Career.data
	var cost := price(id)
	if float(d.get("money", 0.0)) < cost:
		return words("资金不足，还差 %s", "NOT ENOUGH FUNDS · %s SHORT") % Pal.money(cost - float(d.get("money", 0.0)))
	var before := d.duplicate(true)
	d.money = float(d.money) - cost
	var list: Array = d.get("drone_skins", []).duplicate()
	list.append(id)
	d["drone_skins"] = list
	d["drone_skin"] = id
	if Career.usable() and not Career.save():
		Career.data = before
		return Txt.t("gr_save_failed")
	return ""


# fly another one already owned; false if not owned
static func equip(id: String) -> bool:
	if not owns(id):
		return false
	Career.data["drone_skin"] = id
	if Career.usable():
		Career.save()
	return true


static func words(zh: String, en: String) -> String:
	return zh if Txt.zh else en


# the exhaust puffs' colour (the game's fx.puff), by flame
static func puff_col(id: String) -> Color:
	match str(SKINS.get(id, {}).get("flame", "")):
		"bell": return Color(1.0, 0.6, 0.2, 0.12)
		"needle": return Color(0.6, 1.0, 0.5, 0.1)
		"petal": return Color(1.0, 0.45, 0.6, 0.1)
		"ion": return Color(0.55, 0.52, 1.0, 0.1)
		"sputter": return Color(0.95, 0.88, 0.75, 0.14)
	return Pal.heat(0.12, 1.0)


# ---------------------------------------------------------------- sound
# Each airframe's sound: the existing recordings with their pitch moved (no new sounds).
# sfx.gd is not changed: this node runs after it each frame (process_priority) and scales
# the pitch it set on the thrust loop, and the pitch of a "launch" / "grab" just started
# by the operator's drone (played without a position, at full volume).
class SoundTrim extends Node:
	var drone
	var _loop_set := -1.0
	var _voice_set := {}

	func _init() -> void:
		process_priority = 1000
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_dt: float) -> void:
		if drone == null or drone.game == null or drone.game.get("sfx") == null:
			return
		var sfx = drone.game.sfx
		var sk: Array = SKINS[drone.skin_id()].sound
		var lp = sfx.loops.get("thrust_loop")
		if lp != null:
			# only on top of a value sfx.gd has just set (never twice on the same one)
			if not is_equal_approx(lp.pitch_scale, _loop_set):
				lp.pitch_scale = lp.pitch_scale * float(sk[0])
			_loop_set = lp.pitch_scale
		var one := [sfx.streams.get("launch"), sfx.streams.get("grab")]
		for v in sfx.voices:
			if not v.playing or not one.has(v.stream) or v.volume_db < -0.05:
				continue
			var last = _voice_set.get(v)
			if last != null and is_equal_approx(v.pitch_scale, float(last)):
				continue
			v.pitch_scale = v.pitch_scale * float(sk[1])
			_voice_set[v] = v.pitch_scale


static func ink(a: float, k: float = 1.0) -> Color:
	return Art.ink(a, k)


static func acc(id: String, a: float, k: float = 1.0) -> Color:
	var c: Color = SKINS[id].accent
	return lit(Color(c.r * k, c.g * k, c.b * k, a))


# a coloured light: under a blueprint tint (Art.tint, the terminal's and the skill book's
# drawings) it turns the tint's colour at the same brightness
static func lit(c: Color) -> Color:
	var tn: Color = Art.tint
	if tn == Color(1, 1, 1):
		return c
	var k := maxf(c.r, maxf(c.g, c.b)) * 0.9
	return Color(tn.r * k, tn.g * k, tn.b * k, c.a)


# ------------------------------------------------------------ entry points

static func draw(ci: CanvasItem, id: String, st: Dictionary) -> void:
	if id == "arrowring" or not SKINS.has(id):
		Art.draw(ci, "arrowring", st)
		var tj := turn_jets("arrowring", float(st.get("turn", 0.0)))
		if not tj.is_empty() and float(st.get("boot", 1.0)) >= 1.0:
			var b0: Transform2D = st.get("base_xf", Transform2D.IDENTITY)
			ci.draw_set_transform_matrix(b0 * Transform2D(float(st.heading), Vector2.ZERO))
			for j in tj:
				Art.flame(ci, j[0], j[1], j[2], j[3], float(st.t) + float(j[0].x) * 0.1, false)
			ci.draw_set_transform_matrix(b0)
		return
	var base: Transform2D = st.get("base_xf", Transform2D.IDENTITY)
	var h: float = st.heading
	ci.draw_set_transform_matrix(base * Transform2D(h, Vector2.ZERO))
	var ls := st.duplicate()
	ls.heading = 0.0
	ls.base_xf = base * Transform2D(h, Vector2.ZERO)
	ls.lth = (st.get("thrust", Vector2.ZERO) as Vector2).rotated(-h)
	ls.skin = id
	ci.draw_rect(Rect2(-34, -34, 68, 68), Color(0, 0, 0, 0))
	var boot: float = st.get("boot", 1.0)
	if boot < 1.0:
		_boot(ci, id, ls, boot)
	else:
		match id:
			"anvil": _anvil(ci, ls)
			"swift": _swift(ci, ls)
			"greyhawk": _greyhawk(ci, ls)
			"astrolabe": _astrolabe(ci, ls)
			"patchwork": _patchwork(ci, ls)
	ci.draw_set_transform_matrix(base)


# the outline used for afterimages and the hit flash (local frame, x forward)
static func hull(id: String) -> PackedVector2Array:
	match id:
		"anvil": return PackedVector2Array(ANVIL)
		"swift": return PackedVector2Array(SWIFT)
		"greyhawk": return PackedVector2Array(HAWK)
		"astrolabe": return _disc(13.0, 20)
		"patchwork": return PackedVector2Array(PATCH)
	return PackedVector2Array(Art.ARROW)


# where the core glow sits (local)
static func core(id: String) -> Vector2:
	match id:
		"anvil": return Vector2(-1, 0)
		"swift": return Vector2(11, 0)
		"greyhawk": return Vector2(2, 0)
		"astrolabe": return Vector2(1, 0)
		"patchwork": return Vector2(0, 0)
	return Vector2(-2, 0)


# the jets in the world frame turned to the heading (for the exhaust puffs, like arrowring_jets)
static func jets_world(id: String, st: Dictionary) -> Array:
	var h: float = st.heading
	if id == "arrowring":
		var aj: Array = Art.arrowring_jets(st)
		for j in turn_jets(id, float(st.get("turn", 0.0))):
			aj.append([(j[0] as Vector2).rotated(h), (j[1] as Vector2).rotated(h), j[2]])
		return aj
	var out: Array = []
	for j in jets(id, (st.get("thrust", Vector2.ZERO) as Vector2).rotated(-h), float(st.get("turn", 0.0))):
		out.append([(j[0] as Vector2).rotated(h), (j[1] as Vector2).rotated(h), j[2]])
	return out


static func _side(lth: Vector2, s: float) -> float:
	return clampf(-lth.y * s, 0.0, 1.0)


# [pos, dir, strength, width, style] in the drone's frame. 2026-11-10 用户：“除了主发动机有很大的
# 尾焰，其他发动机的尾焰都很小”: every nozzle burns at its full share of the push it gives — the
# braking, side and attitude jets as the mains, in the mains' own style — so a brake or a side
# step lights them as plainly as a burn ahead lights the mains. turn: the airframe's angular
# acceleration, -1..1 (the attitude jets at nose and tail, opposite sides, push it round).
static func jets(id: String, lth: Vector2, turn: float = 0.0) -> Array:
	var fwd := clampf(lth.x, 0.0, 1.0)
	var brake := clampf(-lth.x, 0.0, 1.0)
	var out: Array = []
	match id:
		"anvil":
			for s: float in [-1.0, 1.0]:
				out.append([Vector2(-20.5, 8 * s), Vector2.LEFT, fwd, 3.4, "bell"])
				var d := Vector2(0, s) * _side(lth, s) + Vector2(1, 0) * brake
				d = d.normalized() if d.length() > 0.05 else Vector2(0, s)
				out.append([Vector2(11, 19.5 * s) + d * 3.6, d, maxf(_side(lth, s), brake), 2.6, "bell"])
		"swift":
			out.append([Vector2(-23.5, 0), Vector2.LEFT, fwd, 4.2, "needle"])
			for s: float in [-1.0, 1.0]:
				out.append([Vector2(-11.5, 19.5 * s), Vector2.RIGHT, brake, 2.0, "needle"])
				out.append([Vector2(-13.5, 21 * s), Vector2(0, s), _side(lth, s), 2.0, "needle"])
		"greyhawk":
			var tilt := clampf(lth.y, -1.0, 1.0) * 0.45
			for s: float in [-1.0, 1.0]:
				out.append([Vector2(-18, 7 * s), Vector2(-1, -tilt).normalized(), fwd, 2.8, "petal"])
				# thrust reversers: the flow turned forward and out of the slots by the nozzles
				out.append([Vector2(-11, 11.5 * s), Vector2(0.62, 0.78 * s).normalized(), brake, 2.4, "petal"])
				out.append([Vector2(1, 17.5 * s), Vector2(0, s), _side(lth, s), 2.2, "petal"])
		"astrolabe":
			for s: float in [-1.0, 1.0]:
				out.append([Vector2(-15.5, 5 * s), Vector2.LEFT, fwd, 2.4, "ion"])
				out.append([Vector2(11.2, 8.6 * s), Vector2.RIGHT, brake, 2.0, "ion"])
				for x: float in [-8.6, 8.6]:
					out.append([Vector2(x, 11.4 * s), Vector2(0, s), _side(lth, s), 1.8, "ion"])
		"patchwork":
			out.append([Vector2(-21.5, -13), Vector2.LEFT, fwd, 3.6, "sputter"])
			out.append([Vector2(-19.5, 9), Vector2.LEFT, fwd, 2.6, "sputter"])
			out.append([Vector2(17.5, -11.5), Vector2.RIGHT, brake, 2.6, "sputter"])
			out.append([Vector2(-1, -16.8), Vector2.UP, _side(lth, -1.0), 2.2, "sputter"])
			out.append([Vector2(-3, 15.8), Vector2.DOWN, _side(lth, 1.0), 2.2, "sputter"])
	out.append_array(turn_jets(id, turn))
	return out


# the attitude jets: [nose x, nose half-width, tail x, tail half-width] at the hull's edge; a turn
# toward +angle pushes the nose to +y (its jet blows -y) and the tail to -y (its jet blows +y)
const ATTITUDE := {
	"arrowring": [12.0, 7.5, -10.5, 8.5], "anvil": [19.0, 13.0, -17.0, 10.5], "swift": [20.0, 3.2, -17.0, 4.0],
	"greyhawk": [16.0, 6.0, -15.5, 4.0], "astrolabe": [9.3, 9.3, -9.3, 9.3], "patchwork": [19.0, 4.5, -15.0, 9.0],
}


static func turn_jets(id: String, turn: float) -> Array:
	var f := clampf(absf(turn), 0.0, 1.0)
	if f < 0.04 or not ATTITUDE.has(id):
		return []
	var g: Array = ATTITUDE[id]
	var sg := signf(turn)
	var style := str(SKINS[id].flame)
	return [[Vector2(g[0], -sg * g[1]), Vector2(0, -sg), f, 1.8, style], [Vector2(g[2], sg * g[3]), Vector2(0, sg), f, 1.8, style]]


# ------------------------------------------------------------ flames

static func _hdr(c: Color, k: float, a: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, a)


# a flame shape lit from its root: cols per point. 60 FPS: never draw_polygon (a vertex buffer
# of its own per call, 14-47 µs, scripts/fast_draw.gd); a convex shape of more corners is a fan
# of primitives (0.2-0.3 µs each)
static func gpoly(ci: CanvasItem, pts: PackedVector2Array, cols: PackedColorArray) -> void:
	if pts.size() <= 4:
		ci.draw_primitive(pts, cols, PackedVector2Array())
		return
	var none := PackedVector2Array()
	for i in range(1, pts.size() - 1):
		ci.draw_primitive(PackedVector2Array([pts[0], pts[i], pts[i + 1]]), PackedColorArray([cols[0], cols[i], cols[i + 1]]), none)


static func fade(c: Color, k: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * k)


# the flame's length before its flicker: [at a whisper, added at full push] per style, the same
# for every nozzle of the airframe; a narrower nozzle burns a little shorter (never under 80 %)
const FLAME_LEN := {"bell": [7.0, 13.0], "needle": [12.0, 28.0], "petal": [6.0, 12.0], "ion": [10.0, 20.0],
	"gas": [4.0, 7.0], "sputter": [8.0, 16.0], "torch": [8.0, 16.0]}


static func flame_size(w: float) -> float:
	return clampf(0.7 + 0.1 * w, 0.8, 1.0)


static func flame_len(style: String, f: float, w: float) -> float:
	var l: Array = FLAME_LEN.get(style, FLAME_LEN.torch)
	return (float(l[0]) + float(l[1]) * f) * (1.0 if style == "torch" else flame_size(w))


static func flame(ci: CanvasItem, style: String, base: Vector2, d: Vector2, f: float, w: float, t: float, dash: bool) -> void:
	if f < 0.04:
		return
	var n := Vector2(-d.y, d.x)
	var dk := 1.6 if dash else 1.0
	var ph := base.x * 1.7 + base.y * 2.3
	var small := flame_size(w)
	match style:
		"bell":
			# heavy: a fat short bell of amber, two hot prongs, the throat glowing
			var flick := 0.9 + 0.1 * sin(t * 43.0 + ph)
			var ln := flame_len(style, f, w) * flick * dk
			var c := _hdr(Color(1.0, 0.58, 0.16), 1.7, 0.6 * f)
			gpoly(ci, PackedVector2Array([base + n * w, base + n * w * 1.45 + d * ln * 0.45, base + d * ln, base - n * w * 1.45 + d * ln * 0.45, base - n * w]),
				PackedColorArray([c, fade(c, 0.7), fade(c, 0.0), fade(c, 0.7), c]))
			var hc := Color(1.9, 1.45, 0.85, 0.9 * f)
			for s: float in [-1.0, 1.0]:
				var b2 := base + n * w * 0.42 * s
				gpoly(ci, PackedVector2Array([b2 + n * w * 0.32, b2 + d * ln * 0.62, b2 - n * w * 0.32]), PackedColorArray([hc, fade(hc, 0.1), hc]))
			ci.draw_line(base + n * w * 1.05, base - n * w * 1.05, Color(2.2, 1.3, 0.5, 0.9 * f), 1.4)
		"needle":
			# racer: a long thin lance of white-green with shock diamonds down it
			var flick := 0.92 + 0.08 * sin(t * 71.0 + ph)
			var ln := flame_len(style, f, w) * flick * dk
			var c := _hdr(Color(0.55, 1.0, 0.45), 1.7, 0.55 * f)
			gpoly(ci, PackedVector2Array([base + n * w * 0.8, base + d * ln, base - n * w * 0.8]), PackedColorArray([c, fade(c, 0.0), c]))
			var hc := Color(1.6, 1.9, 1.5, 0.95 * f)
			gpoly(ci, PackedVector2Array([base + n * w * 0.32, base + d * ln * 0.7, base - n * w * 0.32]), PackedColorArray([hc, fade(hc, 0.2), hc]))
			if not Art.lite and w > 2.0:
				for i in 4:
					var u := 0.16 + 0.17 * i
					var p := base + d * ln * u
					var r := w * 0.42 * (1.0 - 0.18 * i)
					FastDraw.poly(ci, PackedVector2Array([p + d * r * 1.6, p + n * r, p - d * r * 1.6, p - n * r]), Color(1.8, 2.1, 1.7, 0.75 * f * (1.0 - 0.2 * i)))
		"petal":
			# ex-military: a short cold blue-white plume, the nozzle petals glowing red
			var flick := 0.88 + 0.12 * sin(t * 57.0 + ph)
			var ln := flame_len(style, f, w) * flick * dk
			var c := _hdr(Color(1.0, 0.3, 0.5), 1.6, 0.5 * f)
			gpoly(ci, PackedVector2Array([base + n * w * 0.9, base + n * w * 0.5 + d * ln * 0.7, base + d * ln, base - n * w * 0.5 + d * ln * 0.7, base - n * w * 0.9]),
				PackedColorArray([c, fade(c, 0.45), fade(c, 0.0), fade(c, 0.45), c]))
			var hc := Color(2.2, 1.3, 1.55, 0.9 * f)
			gpoly(ci, PackedVector2Array([base + n * w * 0.4, base + d * ln * 0.55, base - n * w * 0.4]), PackedColorArray([hc, fade(hc, 0.15), hc]))
			for s: float in [-1.0, 1.0]:
				ci.draw_line(base + n * w * s, base + n * w * 0.75 * s + d * 1.6, Color(2.2, 0.25, 0.6, 0.85 * f), 1.2)
		"ion":
			# research: a steady straight plume of violet fading out, the grid lit at its root
			var sh := 0.96 + 0.04 * sin(t * 9.0 + ph)
			var ln := flame_len(style, f, w) * sh * dk
			var c := _hdr(Color(0.52, 0.5, 1.0), 1.6, 0.34 * f)
			gpoly(ci, PackedVector2Array([base + n * w, base + n * w * 1.35 + d * ln, base - n * w * 1.35 + d * ln, base - n * w]), PackedColorArray([c, fade(c, 0.0), fade(c, 0.0), c]))
			var hc := _hdr(Color(0.62, 0.6, 1.0), 2.2, 0.7 * f)
			gpoly(ci, PackedVector2Array([base + n * w * 0.7, base + n * w * 0.35 + d * ln * 0.55, base - n * w * 0.35 + d * ln * 0.55, base - n * w * 0.7]), PackedColorArray([hc, fade(hc, 0.0), fade(hc, 0.0), hc]))
			ci.draw_line(base + n * w * 0.9, base - n * w * 0.9, Color(1.5, 1.4, 2.4, 0.95 * f), 1.2)
		"gas":
			# cold-gas puffers: a short white-blue cone that spreads and vanishes, no fire
			var ln := (4.0 + 7.0 * f) * dk
			var c := Color(1.1, 1.15, 1.5, 0.5 * f)
			gpoly(ci, PackedVector2Array([base + n * w * 0.5, base + n * w * 2.2 + d * ln, base - n * w * 2.2 + d * ln, base - n * w * 0.5]), PackedColorArray([c, fade(c, 0.0), fade(c, 0.0), c]))
			var hc := Color(1.6, 1.65, 2.0, 0.8 * f)
			gpoly(ci, PackedVector2Array([base + n * w * 0.4, base + d * ln * 0.45, base - n * w * 0.4]), PackedColorArray([hc, fade(hc, 0.0), hc]))
		"sputter":
			# home-built: a ragged yellow-orange flame that coughs now and then
			var cough := sin(t * 6.3 + ph * 3.0) * sin(t * 2.9 + ph)
			var fk := f * (0.35 if cough > 0.82 else 1.0)
			var ln := flame_len(style, fk, w) * (0.8 + 0.2 * sin(t * 53.0 + ph)) * dk
			var c := _hdr(Color(1.0, 0.86, 0.66), 1.5, 0.6 * fk)
			# the ragged edge as a strip of quads, left and right at each step, ending at the tip
			var m := 6
			var none := PackedVector2Array()
			var l0 := base + n * w
			var r0 := base - n * w
			var c0 := c
			for i in range(1, m):
				var u := float(i) / m
				var jl := 0.65 + 0.35 * sin(t * 37.0 + i * 2.1 + ph) + (0.25 if i % 2 == 0 else -0.1)
				var jr := 0.65 + 0.35 * sin(t * 41.0 + i * 1.7 + ph) + (0.25 if i % 2 == 1 else -0.1)
				var l1 := base + d * ln * u + n * w * (1.0 - u) * jl * 1.2
				var r1 := base + d * ln * u - n * w * (1.0 - u) * jr * 1.2
				var c1 := fade(c, 1.0 - u)
				ci.draw_primitive(PackedVector2Array([l0, l1, r1, r0]), PackedColorArray([c0, c1, c1, c0]), none)
				l0 = l1
				r0 = r1
				c0 = c1
			ci.draw_primitive(PackedVector2Array([l0, base + d * ln, r0]), PackedColorArray([c0, fade(c, 0.0), c0]), none)
			var hc := Color(2.2, 2.05, 1.8, 0.9 * fk)
			gpoly(ci, PackedVector2Array([base + n * w * 0.45, base + d * ln * 0.5, base - n * w * 0.45]), PackedColorArray([hc, fade(hc, 0.15), hc]))
		_:
			Art.flame(ci, base, d, f, w, t, dash)


static func _jets(ci: CanvasItem, id: String, st: Dictionary) -> void:
	for j in jets(id, st.lth, float(st.get("turn", 0.0))):
		flame(ci, j[4], j[0], j[1], j[2], j[3], st.t + float(j[0].x) * 0.1, st.get("dash", false))


# ------------------------------------------------------------ shared parts

static func shape(ci, pts: PackedVector2Array, fill: Color, a: float = 0.95, w: float = 1.5) -> void:
	fill_poly(ci, pts, fill)
	ring(ci, pts, ink(a), w)


# a closed outline as one multiline; the segments of a shape drawn again and again are kept
static var _rings := {}


static func ring(ci, pts: PackedVector2Array, col: Color, w: float) -> void:
	if w > FastDraw.THICK or not ci is CanvasItem:
		var c := pts.duplicate()
		c.append(pts[0])
		FastDraw.polyline(ci, c, col, w, true)
		return
	var key := [pts, w]
	var segs = _rings.get(key)
	if segs == null:
		if _rings.size() > 256:
			_rings.clear()
		var sg := PackedVector2Array()
		var h := (w + FastDraw.AA_W) * 0.5
		for i in pts.size():
			var a2: Vector2 = pts[i]
			var b2: Vector2 = pts[(i + 1) % pts.size()]
			var dd := (b2 - a2).normalized() * h
			sg.append(a2 - dd)
			sg.append(b2 + dd)
		segs = sg
		_rings[key] = segs
	ci.draw_multiline(segs, col, w + FastDraw.AA_W)


# 60 FPS: the bodies are fixed shapes in the drone's frame, so each concave one is
# triangulated once and kept (FastDraw.poly would triangulate it every frame)
static var _tri := {}


static func fill_poly(ci, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() <= 4:
		FastDraw.poly(ci, pts, col)
		return
	var ix = _tri.get(pts)
	if ix == null:
		if _tri.size() > 256:
			_tri.clear()
		ix = Geometry2D.triangulate_polygon(pts)
		_tri[pts] = ix
	var one := PackedColorArray([col])
	var none := PackedVector2Array()
	for k in range(0, (ix as PackedInt32Array).size(), 3):
		ci.draw_primitive(PackedVector2Array([pts[ix[k]], pts[ix[k + 1]], pts[ix[k + 2]]]), one, none)


# 60 FPS: the parts of an airframe that never move in its own frame are recorded once (per
# detail level and blueprint tint) into one mesh of triangles and drawn with one call a frame;
# only what moves or glows (arms, nozzles, lamps, the eye, flames) is drawn live
static var _meshes := {}


static func layer(ci: CanvasItem, key: String, fn: Callable) -> void:
	var k := "%s|%d|%s" % [key, int(Art.lite), Art.tint.to_html()]
	var m = _meshes.get(k)
	if m == null:
		var rec := MeshRec.new()
		fn.call(rec)
		m = rec.mesh()
		_meshes[k] = m
	ci.draw_mesh(m, null)


# a stand-in canvas that turns the draw calls into one triangle list, in order
class MeshRec extends RefCounted:
	var p := PackedVector2Array()
	var c := PackedColorArray()

	func _tri(a: Vector2, b: Vector2, d: Vector2, ca: Color, cb: Color, cd: Color) -> void:
		p.append(a)
		p.append(b)
		p.append(d)
		c.append(ca)
		c.append(cb)
		c.append(cd)

	func _seg(a: Vector2, b: Vector2, col: Color, w: float) -> void:
		if w <= 0.0:
			w = 1.0
		var d := b - a
		var ln := d.length()
		if ln < 0.0001:
			return
		d = d / ln * w * 0.5
		var n := Vector2(-d.y, d.x)
		var a0 := a - d * 0.5
		var b0 := b + d * 0.5
		_tri(a0 - n, a0 + n, b0 + n, col, col, col)
		_tri(a0 - n, b0 + n, b0 - n, col, col, col)

	func draw_line(a: Vector2, b: Vector2, col: Color, w: float = -1.0, _aa: bool = false) -> void:
		_seg(a, b, col, w)

	func draw_multiline(pts: PackedVector2Array, col: Color, w: float = -1.0, _aa: bool = false) -> void:
		for i in range(0, pts.size() - 1, 2):
			_seg(pts[i], pts[i + 1], col, w)

	func draw_polyline(pts: PackedVector2Array, col: Color, w: float = -1.0, _aa: bool = false) -> void:
		for i in pts.size() - 1:
			_seg(pts[i], pts[i + 1], col, w)

	func draw_arc(o: Vector2, r: float, a0: float, a1: float, n: int, col: Color, w: float = -1.0, _aa: bool = false) -> void:
		# a band of quads, joint to joint, so a faint ring has no darker joints
		if w <= 0.0:
			w = 1.0
		var steps := maxi(n - 1, 1)
		var ri := r - w * 0.5
		var ro := r + w * 0.5
		for i in steps:
			var u0 := Vector2.from_angle(lerpf(a0, a1, float(i) / steps))
			var u1 := Vector2.from_angle(lerpf(a0, a1, float(i + 1) / steps))
			_tri(o + u0 * ri, o + u0 * ro, o + u1 * ro, col, col, col)
			_tri(o + u0 * ri, o + u1 * ro, o + u1 * ri, col, col, col)

	func draw_circle(o: Vector2, r: float, col: Color, filled: bool = true, w: float = -1.0, _aa: bool = false) -> void:
		var n := 12 if r < 2.5 else 28
		if not filled:
			draw_arc(o, r, 0.0, TAU, n + 1, col, w)
			return
		for i in n:
			_tri(o, o + Vector2.from_angle(TAU * i / n) * r, o + Vector2.from_angle(TAU * (i + 1) / n) * r, col, col, col)

	func draw_colored_polygon(pts: PackedVector2Array, col: Color, _uvs: PackedVector2Array = PackedVector2Array(), _tex: Texture2D = null) -> void:
		var ix := Geometry2D.triangulate_polygon(pts)
		for k in range(0, ix.size(), 3):
			_tri(pts[ix[k]], pts[ix[k + 1]], pts[ix[k + 2]], col, col, col)

	func draw_primitive(pts: PackedVector2Array, cols: PackedColorArray, _uvs: PackedVector2Array, _tex: Texture2D = null) -> void:
		var cl := func(i: int) -> Color: return cols[mini(i, cols.size() - 1)]
		_tri(pts[0], pts[1], pts[2], cl.call(0), cl.call(1), cl.call(2))
		if pts.size() == 4:
			_tri(pts[0], pts[2], pts[3], cl.call(0), cl.call(2), cl.call(3))

	func draw_rect(r: Rect2, col: Color, filled: bool = true, w: float = -1.0, _aa: bool = false) -> void:
		var q := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		if filled:
			_tri(q[0], q[1], q[2], col, col, col)
			_tri(q[0], q[2], q[3], col, col, col)
		else:
			for i in 4:
				_seg(q[i], q[(i + 1) % 4], col, w)

	func mesh() -> ArrayMesh:
		var am := ArrayMesh.new()
		if p.is_empty():
			return am
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = p
		arrays[Mesh.ARRAY_COLOR] = c
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return am


static func mirror(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(pts.size() - 1, -1, -1):
		var p: Vector2 = pts[i]
		out.append(Vector2(p.x, -p.y))
	return out


# a beam from a to b, wa wide at a and wb at b
static func quad(a: Vector2, b: Vector2, wa: float, wb: float) -> PackedVector2Array:
	var n := (b - a).normalized().orthogonal()
	return PackedVector2Array([a + n * wa * 0.5, b + n * wb * 0.5, b - n * wb * 0.5, a - n * wa * 0.5])


static func joint(ci: CanvasItem, p: Vector2, r: float) -> void:
	FastDraw.circle(ci, p, r, HULL_HI)
	if not Art.lite:
		FastDraw.arc(ci, p, r, 0.0, TAU, 10, ink(0.85), 0.9, true)
		FastDraw.circle(ci, p, r * 0.32, ink(0.6))


static func bolt(ci, p: Vector2, a: float = 0.5) -> void:
	if not Art.lite:
		FastDraw.circle(ci, p, 0.6, ink(a))


static func _disc(r: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		out.append(Vector2.from_angle(TAU * i / n) * r)
	return out


# a navigation light that blinks on its own beat
static func nav(ci: CanvasItem, p: Vector2, col: Color, t: float, phase: float, rate: float = 1.1) -> void:
	var on := fposmod(t * rate + phase, 1.0) < 0.16
	FastDraw.circle(ci, p, 1.0 if on else 0.7, lit(Color(col.r * (1.8 if on else 0.6), col.g * (1.8 if on else 0.6), col.b * (1.8 if on else 0.6), 1.0 if on else 0.7)))


static func _tool(ci: CanvasItem, st: Dictionary, at: Vector2) -> void:
	var base: Transform2D = st.base_xf
	ci.draw_set_transform_matrix(base * Transform2D(0.0, at))
	Art.tool_head(ci, Vector2.ZERO, st.tool, st.open, st.t)
	if st.tool == 2 and st.has("skin") and LASER.has(str(st.skin)):
		# the lens burns in this airframe's beam colour (over the stock orange one)
		var e := Pal.ease_io(clampf(float(st.open), 0.0, 1.0))
		FastDraw.circle(ci, Vector2(10.0 * e, 0), 2.2, lheat(0.95 * e, 2.6, str(st.skin)))
	ci.draw_set_transform_matrix(base)


# the launch: the outline draws on, the fill and the eye come up (as H1's)
static func _boot(ci: CanvasItem, id: String, st: Dictionary, boot: float) -> void:
	var b1 := clampf(boot / 0.55, 0.0, 1.0)
	var b2 := clampf((boot - 0.45) / 0.55, 0.0, 1.0)
	var hp := hull(id)
	fill_poly(ci, hp, Color(HULL.r, HULL.g, HULL.b, b2))
	Art.outline_part(ci, hp, ink(0.95, 1.0 + 0.8 * (1.0 - b2)), 1.6, b1)
	if b2 > 0.0:
		Art.iris(ci, core(id), 5.0 * (0.5 + 0.5 * b2), minf(float(st.open), b2), 6, st.t * 0.4 + (1.0 - b2) * 6.0, Art.tool_col(st.tool, 0.95 * b2, 1.35))


# ------------------------------------------------------------ 1 · ANVIL  重型工业拖曳

# a squat armoured box with a push bumper; two big rectangular mains, two
# outrigger pods for braking and side push, two hydraulic arms with three-finger grabs
const ANVIL := [Vector2(18, -12), Vector2(20, -8), Vector2(20, 8), Vector2(18, 12), Vector2(-10, 14.5), Vector2(-17, 10.5), Vector2(-17, -10.5), Vector2(-10, -14.5)]
const ANVIL_DECK := [Vector2(15, -9), Vector2(17, -6.5), Vector2(17, 6.5), Vector2(15, 9), Vector2(-8, 11.5), Vector2(-13.5, 7.5), Vector2(-13.5, -7.5), Vector2(-8, -11.5)]


static func _hyd_arm(ci: CanvasItem, sh: Vector2, s: float, rc: float, t: float) -> void:
	var a1 := s * lerpf(1.25, 0.32, rc) + 0.04 * sin(t * 1.7 + s) * s
	var el := sh + Vector2.from_angle(a1) * 8.0
	var a2 := s * lerpf(-0.55, -0.12, rc)
	var tip := el + Vector2.from_angle(a2) * lerpf(6.5, 10.5, rc)
	# the jack: a cylinder on the hull, its rod pushing the upper arm
	var jb := Vector2(9, 8.5 * s)
	var jt := sh.lerp(el, 0.6)
	var jm := jb.lerp(jt, 0.55)
	ci.draw_line(jb, jm, ink(0.6), 2.2, true)
	ci.draw_line(jm, jt, ink(0.95, 1.2), 1.0, true)
	shape(ci, quad(sh, el, 4.0, 3.2), HULL_HI, 0.85, 1.0)
	shape(ci, quad(el, tip, 3.0, 2.4), HULL_HI, 0.85, 1.0)
	joint(ci, sh, 2.3)
	joint(ci, el, 1.9)
	# three heavy fingers, two-jointed, closing in as they reach
	var spread := 0.45 + 0.5 * rc
	for k in 3:
		var fa := a2 + (k - 1) * spread
		var k1 := tip + Vector2.from_angle(fa) * 2.6
		var k2 := k1 + Vector2.from_angle(fa - (k - 1) * 0.7) * 2.4
		ci.draw_line(tip, k1, ink(0.9), 1.7, true)
		ci.draw_line(k1, k2, ink(0.95), 1.3, true)
	FastDraw.circle(ci, tip, 1.4, HULL_HI)


static func _anvil_a(ci) -> void:
	for s: float in [-1.0, 1.0]:
		shape(ci, quad(Vector2(11, 12 * s), Vector2(11, 19.5 * s), 3.2, 2.6), HULL_HI, 0.6, 1.0)


static func _anvil_b(ci) -> void:
	# hull, deck, seams, bolts
	shape(ci, PackedVector2Array(ANVIL), HULL, 0.95, 1.7)
	fill_poly(ci, PackedVector2Array(ANVIL_DECK), HULL_HI)
	if not Art.lite:
		ring(ci, PackedVector2Array(ANVIL_DECK), ink(0.22), 0.8)
		ci.draw_line(Vector2(6, -10.6), Vector2(6, 10.6), ink(0.3), 0.8)
		ci.draw_line(Vector2(-8, -11.5), Vector2(-8, 11.5), ink(0.3), 0.8)
		for s: float in [-1.0, 1.0]:
			ci.draw_line(Vector2(-13.5, 5 * s), Vector2(6, 5 * s), ink(0.18), 0.8)
			for x: float in [-11.0, -4.0, 3.0, 10.0, 15.0]:
				bolt(ci, Vector2(x, (9.2 if x > 5.0 else 9.8) * s))
		# vent louvres on the rear deck
		for i in 4:
			var x := -12.0 + i * 1.3
			ci.draw_line(Vector2(x, -3.4), Vector2(x, 3.4), ink(0.28), 0.8)
	# the push bumper: hazard stripes, three rubber pads
	var bump := PackedVector2Array([Vector2(19, -13.5), Vector2(23.5, -12.5), Vector2(23.5, 12.5), Vector2(19, 13.5)])
	shape(ci, bump, HULL_HI, 0.9, 1.2)
	if not Art.lite:
		var y := -12.0
		var i := 0
		while y < 11.0:
			if i % 2 == 0:
				FastDraw.poly(ci, PackedVector2Array([Vector2(19.6, y), Vector2(19.6, y + 1.7), Vector2(23.0, y + 3.6), Vector2(23.0, y + 1.9)]), acc("anvil", 0.8, 1.0))
			y += 2.4
			i += 1
	for py: float in [-9.0, 0.0, 9.0]:
		var pad := PackedVector2Array([Vector2(23.5, py - 2.4), Vector2(25.2, py - 2.0), Vector2(25.2, py + 2.0), Vector2(23.5, py + 2.4)])
		shape(ci, pad, HULL_LO, 0.75, 0.9)
	# the two floodlamps' housings at the bumper's corners
	for s: float in [-1.0, 1.0]:
		var lp := Vector2(21.2, 15.2 * s)
		shape(ci, PackedVector2Array([lp + Vector2(-1.6, -1.8), lp + Vector2(1.8, -1.8), lp + Vector2(1.8, 1.8), lp + Vector2(-1.6, 1.8)]), HULL_HI, 0.85, 0.9)
	# rear mains: big rectangular bells
	for s: float in [-1.0, 1.0]:
		var m := Vector2(-17, 8 * s)
		shape(ci, PackedVector2Array([m + Vector2(1, -3.2), m + Vector2(-3.5, -4.4), m + Vector2(-3.5, 4.4), m + Vector2(1, 3.2)]), HULL_HI, 0.9, 1.1)
		if not Art.lite:
			for k in 3:
				ci.draw_line(m + Vector2(-1.0 - k, -3.4 - k * 0.3), m + Vector2(-1.0 - k, 3.4 + k * 0.3), ink(0.2), 0.7)
	# the reactor hatch in the middle: a square housing, corner clamps
	var hatch := PackedVector2Array([Vector2(5, -6), Vector2(6, -5), Vector2(6, 5), Vector2(5, 6), Vector2(-7, 6), Vector2(-8, 5), Vector2(-8, -5), Vector2(-7, -6)])
	shape(ci, hatch, HULL, 0.9, 1.2)
	if not Art.lite:
		for c: Vector2 in [Vector2(5, -6), Vector2(5, 6), Vector2(-7, -6), Vector2(-7, 6)]:
			var sx := signf(c.x + 1.0)
			var sy := signf(c.y)
			ci.draw_line(c + Vector2(-sx * 2.5, 0), c, ink(0.8), 1.1)
			ci.draw_line(c, c + Vector2(0, -sy * 2.5), ink(0.8), 1.1)


static func _anvil(ci: CanvasItem, st: Dictionary) -> void:
	var t: float = st.t
	var lth: Vector2 = st.lth
	var rc := Art.claw_reach(st)
	var brake := clampf(-lth.x, 0.0, 1.0)
	layer(ci, "anvil_a", _anvil_a)
	# the outrigger box pods turn to blow where needed
	for s: float in [-1.0, 1.0]:
		var side := _side(lth, s)
		var d := Vector2(0, s) * side + Vector2(1, 0) * brake
		d = d.normalized() if d.length() > 0.05 else Vector2(0, s)
		var at := Vector2(11, 19.5 * s)
		var n := d.orthogonal()
		var box := PackedVector2Array([at - d * 3.2 + n * 3.0, at + d * 3.0 + n * 2.6, at + d * 3.0 - n * 2.6, at - d * 3.2 - n * 3.0])
		shape(ci, box, HULL, 0.9, 1.1)
		if not Art.lite:
			ci.draw_line(at - d * 1.0 + n * 2.6, at - d * 1.0 - n * 2.6, ink(0.35), 0.8)
	layer(ci, "anvil_b", _anvil_b)
	# the lamps' faces, the bells' throats lit with the burn, the breathing bars
	var fwd := clampf(lth.x, 0.0, 1.0)
	for s: float in [-1.0, 1.0]:
		var lp := Vector2(21.2, 15.2 * s)
		ci.draw_line(lp + Vector2(1.6, -1.5), lp + Vector2(1.6, 1.5), lit(Color(2.2, 2.0, 1.6, 1.0)), 1.4)
		var m := Vector2(-17, 8 * s)
		ci.draw_line(m + Vector2(-3.4, -4.0), m + Vector2(-3.4, 4.0), lit(Color(1.6, 0.93, 0.26, 0.3 + 0.7 * fwd)), 1.0)
	var br := 0.5 + 0.5 * sin(t * 2.2)
	for s: float in [-1.0, 1.0]:
		ci.draw_line(Vector2(-6, 7.6 * s), Vector2(4, 7.6 * s), acc("anvil", 0.35 + 0.45 * br, 1.0 + 0.8 * br), 1.2)
	Art.iris(ci, Vector2(-1, 0), 4.8, st.open, 6, t * 0.4, Art.tool_col(st.tool, 0.95, 1.35))
	# rear corner beacons
	for s: float in [-1.0, 1.0]:
		nav(ci, Vector2(-12, 12.6 * s), Color(1.0, 0.72, 0.16), t, 0.5 if s > 0 else 0.0, 0.9)
	for s: float in [-1.0, 1.0]:
		_hyd_arm(ci, Vector2(15, 8.5 * s), s, rc, t)
	_jets(ci, "anvil", st)
	_tool(ci, st, Vector2(25.5, 0))


# ------------------------------------------------------------ 2 · SWIFT  轻量竞速

# a needle fuselage, swept wings, canards; one big round main at the tail,
# wing-tip puffers for brake and side push, two slim pincers tucked under the nose
const SWIFT := [Vector2(31, 0), Vector2(21, -3), Vector2(6, -5), Vector2(-10, -19.5), Vector2(-16, -19.5), Vector2(-14, -5), Vector2(-19, -3.5), Vector2(-19, 3.5), Vector2(-14, 5), Vector2(-16, 19.5), Vector2(-10, 19.5), Vector2(6, 5), Vector2(21, 3)]
const SWIFT_BODY := [Vector2(31, 0), Vector2(21, -3), Vector2(6, -5), Vector2(-14, -5), Vector2(-19, -3.5), Vector2(-19, 3.5), Vector2(-14, 5), Vector2(6, 5), Vector2(21, 3)]
const SWIFT_WING := [Vector2(7, -4.5), Vector2(-10, -19.5), Vector2(-16, -19.5), Vector2(-13, -4.5)]


static func _pincer(ci: CanvasItem, sh: Vector2, s: float, rc: float, t: float) -> void:
	var el := sh + Vector2(lerpf(5.0, 6.0, rc), s * lerpf(0.6, 3.6, rc))
	var tip := el + Vector2(lerpf(4.5, 9.0, rc), s * lerpf(-0.6, -1.4, rc))
	ci.draw_line(sh, el, ink(0.85), 1.5, true)
	ci.draw_line(el, tip, ink(0.85), 1.2, true)
	var op := 0.18 + 0.55 * rc
	ci.draw_line(tip, tip + Vector2.from_angle(s * op) * 3.0, ink(0.95), 1.0, true)
	ci.draw_line(tip, tip + Vector2.from_angle(-s * (0.5 + op)) * 2.4, ink(0.95), 1.0, true)
	if not Art.lite:
		for j: Vector2 in [sh, el]:
			FastDraw.circle(ci, j, 1.2, HULL_HI)
			FastDraw.arc(ci, j, 1.2, 0.0, TAU, 8, ink(0.85), 0.8, true)


static func _swift_a(ci) -> void:
	# wings under the body, wing-tip puffer pods
	for s: float in [-1.0, 1.0]:
		var wing := PackedVector2Array(SWIFT_WING) if s < 0 else mirror(SWIFT_WING)
		shape(ci, wing, HULL, 0.95, 1.4)
		if not Art.lite:
			# leading-edge highlight, two chevrons in the accent
			ci.draw_line(Vector2(5, -5.2 * s), Vector2(-10, -19.0 * s), ink(0.45, 1.2), 0.8, true)
			for k in 2:
				var x0 := -4.0 - k * 3.2
				FastDraw.polyline(ci, PackedVector2Array([Vector2(x0 + 2.0, -7.5 * s), Vector2(x0, -10.5 * s), Vector2(x0 - 2.0, -13.5 * s)]), acc("swift", 0.75 - 0.25 * k, 1.0), 1.0, true)
		FastDraw.circle(ci, Vector2(-13.5, 19.5 * s), 2.0, HULL_HI)
		FastDraw.arc(ci, Vector2(-13.5, 19.5 * s), 2.0, 0.0, TAU, 10, ink(0.85), 0.9, true)


static func _swift_b(ci) -> void:
	shape(ci, PackedVector2Array(SWIFT_BODY), HULL, 0.95, 1.5)
	fill_poly(ci, PackedVector2Array([Vector2(25, 0), Vector2(18, -2.0), Vector2(-13, -2.6), Vector2(-13, 2.6), Vector2(18, 2.0)]), HULL_HI)
	# canards
	for s: float in [-1.0, 1.0]:
		shape(ci, PackedVector2Array([Vector2(19, -2.6 * s), Vector2(13.5, -8.0 * s), Vector2(11.0, -8.0 * s), Vector2(12.5, -3.6 * s)]) if s < 0 else PackedVector2Array([Vector2(12.5, 3.6), Vector2(11.0, 8.0), Vector2(13.5, 8.0), Vector2(19, 2.6)]), HULL, 0.85, 1.0)
	if not Art.lite:
		ci.draw_line(Vector2(4, 0), Vector2(-13, 0), acc("swift", 0.4, 1.0), 1.0)
		for x: float in [-7.0, -1.0, 21.0]:
			ci.draw_line(Vector2(x, -2.4), Vector2(x, 2.4), ink(0.25), 0.7)
	# the canopy: a long sensor glass (the eye goes in it)
	var canopy := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		canopy.append(Vector2(11 + cos(a) * 6.5, sin(a) * 2.8))
	shape(ci, canopy, HULL_LO, 0.75, 1.0)
	if not Art.lite:
		ci.draw_line(Vector2(7, -1.8), Vector2(15.5, -1.8), ink(0.35, 1.0), 0.6)
	# the main: a round bell at the tail
	shape(ci, PackedVector2Array([Vector2(-17.5, -3.8), Vector2(-23.5, -5.4), Vector2(-23.5, 5.4), Vector2(-17.5, 3.8)]), HULL_HI, 0.9, 1.1)
	if not Art.lite:
		ci.draw_line(Vector2(-20.5, -4.6), Vector2(-20.5, 4.6), ink(0.3), 0.7)


static func _swift(ci: CanvasItem, st: Dictionary) -> void:
	var t: float = st.t
	var lth: Vector2 = st.lth
	var rc := Art.claw_reach(st)
	var dash: bool = st.get("dash", false)
	layer(ci, "swift_a", _swift_a)
	for s: float in [-1.0, 1.0]:
		nav(ci, Vector2(-15.2, 19.5 * s), Color(0.58, 1.0, 0.3), t, 0.0 if s < 0 else 0.5, 1.6)
	# pincers under the nose (drawn before the body so they tuck under it stowed)
	for s: float in [-1.0, 1.0]:
		_pincer(ci, Vector2(15, 2.4 * s), s, rc, t)
	layer(ci, "swift_b", _swift_b)
	if not Art.lite:
		# a light chasing down the spine stripe (faster at full burn)
		var fwd := clampf(lth.x, 0.0, 1.0)
		var u := fposmod(t * (1.2 + 3.0 * fwd + (2.0 if dash else 0.0)), 1.0)
		var px := lerpf(4.0, -13.0, u)
		ci.draw_line(Vector2(px, 0), Vector2(px - 3.0, 0), acc("swift", 0.95, 2.4), 1.2)
	Art.iris(ci, Vector2(11, 0), 2.7, st.open, 5, t * 0.6, Art.tool_col(st.tool, 0.95, 1.35))
	# the afterburner ring glows on a dash; the pencil lamp at the very nose
	ci.draw_line(Vector2(-23.3, -5.0), Vector2(-23.3, 5.0), acc("swift", 0.9 if dash else 0.35, 2.2 if dash else 1.0), 1.1)
	ci.draw_line(Vector2(29.0, -0.9), Vector2(29.0, 0.9), lit(Color(2.0, 2.3, 2.0, 1.0)), 1.4)
	_jets(ci, "swift", st)
	_tool(ci, st, Vector2(31, 0))


# ------------------------------------------------------------ 3 · GREYHAWK  军用退役改装

# a faceted low-observable airframe, its insignia sanded off and the gun cut
# away and capped; vectoring nozzles, thrust-reverser slots, mantis blade arms
const HAWK := [Vector2(27, 0), Vector2(15, -6), Vector2(9, -14), Vector2(-5, -18.5), Vector2(-14, -12), Vector2(-12, -5), Vector2(-17, -2), Vector2(-17, 2), Vector2(-12, 5), Vector2(-14, 12), Vector2(-5, 18.5), Vector2(9, 14), Vector2(15, 6)]


static func _blade_arm(ci: CanvasItem, sh: Vector2, s: float, rc: float, t: float) -> void:
	var a1 := s * lerpf(0.9, 0.22, rc)
	var el := sh + Vector2.from_angle(a1) * 7.5
	var a2 := s * lerpf(-0.75, -0.08, rc)
	var tip := el + Vector2.from_angle(a2) * lerpf(6.0, 11.0, rc)
	# upper: a flat kite
	var n1 := (el - sh).normalized().orthogonal()
	shape(ci, PackedVector2Array([sh, sh.lerp(el, 0.5) + n1 * 1.8, el, sh.lerp(el, 0.5) - n1 * 1.8]), HULL_HI, 0.85, 0.9)
	# forearm: a blade narrowing to a point
	var n2 := (tip - el).normalized().orthogonal()
	shape(ci, PackedVector2Array([el + n2 * 1.4, tip, el - n2 * 1.4]), HULL_HI, 0.9, 0.9)
	# the hinged thumb blade: opens with the reach
	var ta := a2 - s * (0.25 + 0.7 * rc)
	var tb := tip.lerp(el, 0.35)
	var tt := tb + Vector2.from_angle(ta) * (3.5 + 1.5 * rc)
	shape(ci, PackedVector2Array([tb + n2 * 0.7, tt, tb - n2 * 0.7]), HULL_HI, 0.95, 0.8)
	joint(ci, sh, 1.9)
	joint(ci, el, 1.6)


static func _hawk_a(ci) -> void:
	shape(ci, PackedVector2Array(HAWK), HULL, 0.95, 1.6)
	# facets: the upper-left planes catch the berth's light, the lower-right stay dark
	fill_poly(ci, PackedVector2Array([Vector2(15, -6), Vector2(9, -14), Vector2(-5, -18.5), Vector2(-3, -6), Vector2(4, -4.5)]), HULL_HI)
	FastDraw.poly(ci, PackedVector2Array([Vector2(27, 0), Vector2(15, -6), Vector2(4, -4.5), Vector2(6, 0)]), Color(0.13, 0.135, 0.152))
	fill_poly(ci, PackedVector2Array([Vector2(15, 6), Vector2(9, 14), Vector2(-5, 18.5), Vector2(-3, 6), Vector2(4, 4.5)]), HULL_LO)
	if not Art.lite:
		for seg: Array in [[Vector2(27, 0), Vector2(6, 0)], [Vector2(15, -6), Vector2(4, -4.5)], [Vector2(15, 6), Vector2(4, 4.5)], [Vector2(4, -4.5), Vector2(-3, -6)], [Vector2(4, 4.5), Vector2(-3, 6)], [Vector2(-3, -6), Vector2(-5, -18.5)], [Vector2(-3, 6), Vector2(-5, 18.5)], [Vector2(-3, -6), Vector2(-12, -5)], [Vector2(-3, 6), Vector2(-12, 5)]]:
			ci.draw_line(seg[0], seg[1], ink(0.26), 0.8, true)
		# kill tallies on the left wing, struck through when it was sold off
		for k in 4:
			ci.draw_line(Vector2(-4.5 + k * 1.3, -10.5), Vector2(-4.5 + k * 1.3, -13.0), ink(0.5), 0.7)
		ci.draw_line(Vector2(-5.2, -10.2), Vector2(0.2, -13.4), ink(0.5), 0.7)
		ci.draw_line(Vector2(-6.0, -11.8), Vector2(1.0, -11.8), acc("greyhawk", 0.55, 1.0), 0.9)
		# the old roundel on the right wing, sanded down to a ghost
		FastDraw.arc(ci, Vector2(-2, 12), 2.6, 0.0, TAU, 14, ink(0.2), 0.8, true)
		FastDraw.arc(ci, Vector2(-2, 12), 2.6, 2.4, 3.6, 6, acc("greyhawk", 0.45, 1.0), 0.9, true)
		# side louvres at the wings' mid edges
		for s: float in [-1.0, 1.0]:
			for k in 3:
				ci.draw_line(Vector2(-1 + k * 1.4, 15.6 * s), Vector2(0.4 + k * 1.4, 16.6 * s), ink(0.4), 0.7)
	# the cut-off gun on the left wing root: barrel and blank cap
	shape(ci, PackedVector2Array([Vector2(1, -9.8), Vector2(10, -9.8), Vector2(10, -8.2), Vector2(1, -8.2)]), HULL_HI, 0.8, 0.9)
	ci.draw_rect(Rect2(Vector2(10, -10.3), Vector2(1.4, 2.6)), ink(0.75))
	# the recessed eye's angular hatch, the visor's housing
	shape(ci, PackedVector2Array([Vector2(8, 0), Vector2(5, -5), Vector2(-1, -5), Vector2(-4, 0), Vector2(-1, 5), Vector2(5, 5)]), HULL_LO, 0.8, 1.1)
	shape(ci, PackedVector2Array([Vector2(18.5, -3.2), Vector2(20.5, -2.4), Vector2(20.5, 2.4), Vector2(18.5, 3.2)]), HULL_LO, 0.7, 0.8)


static func _greyhawk(ci: CanvasItem, st: Dictionary) -> void:
	var t: float = st.t
	var lth: Vector2 = st.lth
	var rc := Art.claw_reach(st)
	var brake := clampf(-lth.x, 0.0, 1.0)
	for s: float in [-1.0, 1.0]:
		_blade_arm(ci, Vector2(13, 5.2 * s), s, rc, t)
	layer(ci, "hawk_a", _hawk_a)
	if not Art.lite:
		# the weld bead where the gun was cut
		FastDraw.polyline(ci, PackedVector2Array([Vector2(5.8, -10.2), Vector2(6.4, -9.4), Vector2(5.8, -8.6), Vector2(6.4, -7.8)]), lit(Color(1.6, 0.9, 0.5, 0.6)), 0.7)
	# vectoring nozzles: the petals turn with the push; reverser doors open on a brake
	var fwd := clampf(lth.x, 0.0, 1.0)
	var tilt := clampf(lth.y, -1.0, 1.0) * 0.45
	for s: float in [-1.0, 1.0]:
		var m := Vector2(-15, 7 * s)
		var d := Vector2(-1, -tilt).normalized() if fwd > 0.05 else Vector2.LEFT
		var n := d.orthogonal()
		var noz := PackedVector2Array([m + n * 2.6 - d * 1.5, m + n * 2.0 + d * 3.0, m - n * 2.0 + d * 3.0, m - n * 2.6 - d * 1.5])
		shape(ci, noz, HULL_HI, 0.9, 1.0)
		if not Art.lite:
			ci.draw_line(m + n * 2.2 + d * 1.2, m - n * 2.2 + d * 1.2, ink(0.3), 0.7)
		var hinge := Vector2(-12.5, 9.8 * s)
		var door := hinge + Vector2.from_angle(PI + s * (0.4 - 1.2 * brake) * -1.0) * 3.2
		ci.draw_line(hinge, door, ink(0.9), 1.3, true)
	Art.iris(ci, Vector2(2, 0), 4.2, st.open, 6, -t * 0.3, Art.tool_col(st.tool, 0.95, 1.35))
	# the visor lamp: a red-filtered slit across the nose
	ci.draw_line(Vector2(19.6, -2.4), Vector2(19.6, 2.4), acc("greyhawk", 1.0, 1.5), 1.1)
	# wing-tip nav lights and a tail strobe
	nav(ci, Vector2(-5, -17.4), Color(1.0, 0.2, 0.28), t, 0.0, 0.8)
	nav(ci, Vector2(-5, 17.4), Color(1.0, 0.2, 0.28), t, 0.0, 0.8)
	nav(ci, Vector2(-16, 0), Color(1, 1, 1), t, 0.4, 1.3)
	_jets(ci, "greyhawk", st)
	_tool(ci, st, Vector2(27, 0))


# ------------------------------------------------------------ 4 · ASTROLABE  科研探测

# a round instrument disc with a scan ring round the eye; a dish forward with
# a ring lamp on its rim, solar wings, two sensor booms trailing; grid-ion
# mains and cold-gas puffers on the rim; two telescoping sample arms
static func _tele_arm(ci: CanvasItem, sh: Vector2, s: float, rc: float, t: float) -> void:
	var a := s * lerpf(0.55, 0.22, rc)
	var d := Vector2.from_angle(a)
	var n := d.orthogonal()
	var ln := lerpf(7.0, 17.0, rc)
	var ws := [2.8, 2.1, 1.4]
	var start := 0.0
	for k in 3:
		var seg := ln * (0.42 if k == 0 else 0.33)
		var p0 := sh + d * start
		var p1 := sh + d * (start + seg + (0.8 if k < 2 else 0.0))
		shape(ci, quad(p0, p1, ws[k], ws[k]), HULL_HI, 0.85, 0.8)
		start += seg
	var tip := sh + d * ln
	joint(ci, sh, 1.9)
	# three soft fingers curling round the target as they open
	var op := 0.35 + 0.55 * rc
	for k in 3:
		var fa := a + (k - 1) * op
		var c1 := tip + Vector2.from_angle(fa) * 2.2
		var c2 := c1 + Vector2.from_angle(fa - (k - 1) * 0.9) * 2.0
		FastDraw.polyline(ci, PackedVector2Array([tip, c1, c2]), ink(0.9), 0.9, true)
	FastDraw.circle(ci, tip, 1.1, acc("astrolabe", 0.9, 1.6))


static func _astro_a(ci) -> void:
	# sensor booms trailing back with their magnetometers
	for s: float in [-1.0, 1.0]:
		var b0 := Vector2(-9, 6.5 * s)
		var b1 := Vector2(-25, 11 * s)
		ci.draw_line(b0, b1, ink(0.6), 1.0, true)
		if not Art.lite:
			var mid := b0.lerp(b1, 0.55)
			shape(ci, PackedVector2Array([mid + Vector2(1.4, 0), mid + Vector2(0, 1.4), mid + Vector2(-1.4, 0), mid + Vector2(0, -1.4)]), HULL_HI, 0.7, 0.7)
	# solar wings on short struts, cells drawn in
	for s: float in [-1.0, 1.0]:
		ci.draw_line(Vector2(-2, 11 * s), Vector2(-2, 14 * s), ink(0.6), 1.6)
		shape(ci, PackedVector2Array([Vector2(-8, 14 * s), Vector2(4, 14 * s), Vector2(4, 22 * s), Vector2(-8, 22 * s)]), Color(0.05, 0.055, 0.085), 0.85, 1.0)
		if not Art.lite:
			for k in 3:
				ci.draw_line(Vector2(-5 + k * 3, 14 * s), Vector2(-5 + k * 3, 22 * s), ink(0.22), 0.6)
			ci.draw_line(Vector2(-8, 18 * s), Vector2(4, 18 * s), ink(0.22), 0.6)
	# grid-ion mains on the rim at the back
	for s: float in [-1.0, 1.0]:
		var m := Vector2(-13.5, 5 * s)
		shape(ci, PackedVector2Array([m + Vector2(1.5, -2.8), m + Vector2(-2, -3.2), m + Vector2(-2, 3.2), m + Vector2(1.5, 2.8)]), HULL_HI, 0.9, 1.0)
		if not Art.lite:
			for k in 3:
				ci.draw_line(m + Vector2(-1.9, -2.2 + k * 2.2), m + Vector2(-0.6, -2.2 + k * 2.2), ink(0.45), 0.6)
	# the disc: rim bays, ribs
	FastDraw.circle(ci, Vector2.ZERO, 13.0, HULL)
	FastDraw.arc(ci, Vector2.ZERO, 13.0, 0.0, TAU, 32, ink(0.95), 1.6, true)
	FastDraw.arc(ci, Vector2.ZERO, 9.8, 0.0, TAU, 28, ink(0.28), 0.8, true)
	if not Art.lite:
		for k in 8:
			var a := TAU * k / 8.0 + PI / 8.0
			ci.draw_line(Vector2.from_angle(a) * 9.8, Vector2.from_angle(a) * 13.0, ink(0.3), 0.8)
		# cold-gas quads on the rim
		for q: Vector2 in [Vector2(8.6, 8.6), Vector2(8.6, -8.6), Vector2(-8.6, 8.6), Vector2(-8.6, -8.6)]:
			FastDraw.circle(ci, q * 1.08, 1.2, HULL_HI)
			FastDraw.arc(ci, q * 1.08, 1.2, 0.0, TAU, 8, ink(0.75), 0.7, true)
	FastDraw.circle(ci, Vector2(1, 0), 6.0, HULL_HI)
	FastDraw.arc(ci, Vector2(1, 0), 6.0, 0.0, TAU, 20, ink(0.8), 1.0, true)


const DISH_C := Vector2(25, 0)


static func _astro_b(ci) -> void:
	# the dish forward: concave to the front, a feed on its struts
	var dish := PackedVector2Array()
	for i in 11:
		dish.append(DISH_C + Vector2.from_angle(PI - 0.72 + 1.44 * i / 10.0) * 10.0)
	var bowl := dish.duplicate()
	bowl.append_array(_dish_lip())
	fill_poly(ci, bowl, HULL_HI)
	FastDraw.polyline(ci, dish, ink(0.9), 1.3, true)
	var focus := Vector2(22, 0)
	for e: Vector2 in [dish[0], dish[10]]:
		ci.draw_line(e, focus, ink(0.55), 0.7, true)
	FastDraw.circle(ci, focus, 1.2, HULL_HI)
	FastDraw.arc(ci, focus, 1.2, 0.0, TAU, 8, ink(0.9), 0.8, true)


static func _dish_lip() -> PackedVector2Array:
	var lip := PackedVector2Array()
	for i in range(10, -1, -1):
		lip.append(DISH_C + Vector2.from_angle(PI - 0.6 + 1.2 * i / 10.0) * 8.6 + Vector2(-1.2, 0))
	return lip


static func _astrolabe(ci: CanvasItem, st: Dictionary) -> void:
	var t: float = st.t
	var rc := Art.claw_reach(st)
	layer(ci, "astro_a", _astro_a)
	for s: float in [-1.0, 1.0]:
		nav(ci, Vector2(-25, 11 * s), Color(0.68, 0.56, 1.0), t, 0.0 if s < 0 else 0.33, 0.7)
		if not Art.lite:
			# a glint sweeping across the solar wing
			var gl := fposmod(t * 0.35 + (0.5 if s > 0 else 0.0), 1.0)
			var gx := lerpf(-8.0, 4.0, gl)
			ci.draw_line(Vector2(gx, 14.4 * s), Vector2(gx + 1.5, 21.6 * s), acc("astrolabe", 0.35 * sin(gl * PI), 1.6), 0.8)
	if not Art.lite:
		# the scan ring turning round the eye, one tick lit
		var sp := t * 0.9
		var ticks := PackedVector2Array()
		for k in range(1, 16):
			var a := sp + TAU * k / 16.0
			ticks.append(Vector2.from_angle(a) * 7.0)
			ticks.append(Vector2.from_angle(a) * 7.8)
		ci.draw_multiline(ticks, ink(0.35), 0.7)
		ci.draw_line(Vector2.from_angle(sp) * 7.0, Vector2.from_angle(sp) * 8.6, acc("astrolabe", 1.0, 2.2), 1.0)
	Art.iris(ci, Vector2(1, 0), 4.6, st.open, 7, t * 0.25, Art.tool_col(st.tool, 0.95, 1.35))
	# the arms under the dish
	for s: float in [-1.0, 1.0]:
		_tele_arm(ci, Vector2(10, 6.5 * s), s, rc, t)
	layer(ci, "astro_b", _astro_b)
	# the ring lamp on the dish's rim
	FastDraw.polyline(ci, _dish_lip(), lit(Color(1.6, 1.55, 2.2, 0.9)), 1.0, true)
	_jets(ci, "astrolabe", st)
	_tool(ci, st, Vector2(25, 0))


# ------------------------------------------------------------ 5 · PATCHWORK  老式手工拼装

# a lopsided hull of plates riveted over each other, taped and piped; a big
# can engine bolted on the left and a small box one on the right, a reversed
# nozzle at the front for braking, spray-can side jets; one old car headlamp
# on a bracket; a crane hook on a boom for one arm and pliers for the other
const PATCH := [Vector2(23, -2), Vector2(17, -9), Vector2(5, -12.5), Vector2(-6, -15.5), Vector2(-15, -10.5), Vector2(-14.5, 1), Vector2(-17.5, 9), Vector2(-8, 14.5), Vector2(6, 12.5), Vector2(15.5, 7.5), Vector2(21.5, 3.5)]


static func _hook_arm(ci: CanvasItem, rc: float, t: float) -> void:
	var b0 := Vector2(12, -6)
	var b1 := Vector2(lerpf(19.0, 27.0, rc), lerpf(-9.5, -7.0, rc))
	shape(ci, quad(b0, b1, 2.6, 1.8), HULL_HI, 0.8, 0.9)
	if not Art.lite:
		# a lattice boom: cross-bracing ticks
		for k in 3:
			var u := 0.2 + 0.3 * k
			var p := b0.lerp(b1, u)
			ci.draw_line(p + Vector2(-1, -1.0), p + Vector2(1, 1.0), ink(0.4), 0.6)
	joint(ci, b0, 1.8)
	# the cable runs ahead and the hook sways on it
	var sway := 0.25 * sin(t * 1.6) * (1.0 - 0.6 * rc)
	var hk := b1 + Vector2.from_angle(sway) * (3.5 + 2.5 * rc)
	ci.draw_line(b1, hk, ink(0.7), 0.8, true)
	FastDraw.circle(ci, b1, 1.0, ink(0.8))
	# the hook: a J opening sideways, its point barbed
	var ha := sway
	FastDraw.arc(ci, hk + Vector2.from_angle(ha) * 2.2, 2.2, ha + PI, ha + PI + PI * 1.25, 10, ink(0.95), 1.4, true)
	var pt := hk + Vector2.from_angle(ha) * 2.2 + Vector2.from_angle(ha + PI * 2.25) * 2.2
	ci.draw_line(pt, pt + Vector2.from_angle(ha + PI * 0.8) * 1.4, ink(0.95), 1.1, true)


static func _pliers(ci: CanvasItem, rc: float, t: float) -> void:
	var sh := Vector2(13, 6.5)
	var el := sh + Vector2.from_angle(lerpf(0.9, 0.35, rc)) * 7.0
	var tip := el + Vector2.from_angle(lerpf(-0.4, -0.05, rc)) * lerpf(5.0, 9.0, rc)
	ci.draw_line(sh, el, ink(0.8), 2.2, true)
	ci.draw_line(el, tip, ink(0.8), 1.7, true)
	joint(ci, sh, 1.8)
	joint(ci, el, 1.5)
	# two crossed jaws round a pivot bolt
	var d := (tip - el).normalized()
	var op := 0.15 + 0.5 * rc
	for s: float in [-1.0, 1.0]:
		ci.draw_line(tip - d.rotated(s * 0.4) * 1.5, tip + d.rotated(-s * op) * 3.6, ink(0.95), 1.2, true)
	FastDraw.circle(ci, tip, 0.8, ink(0.8))


static func _patch_a(ci) -> void:
	# the bolted-on engines and their brackets, the spray cans on the flanks
	ci.draw_line(Vector2(-10, -11.5), Vector2(-11, -13), ink(0.6), 1.8)
	ci.draw_line(Vector2(-14, 7), Vector2(-14, 8), ink(0.6), 1.8)
	shape(ci, PackedVector2Array([Vector2(-8, -16.5), Vector2(-17.5, -16.5), Vector2(-17.5, -9.5), Vector2(-8, -9.5)]), HULL_HI, 0.9, 1.2)
	FastDraw.arc(ci, Vector2(-8, -13), 3.5, -PI / 2.0, PI / 2.0, 8, ink(0.9), 1.2, true)
	if not Art.lite:
		for x: float in [-11.0, -15.0]:
			ci.draw_line(Vector2(x, -16.5), Vector2(x, -9.5), ink(0.4), 0.8)
	shape(ci, PackedVector2Array([Vector2(-17.5, -15.5), Vector2(-21.5, -17), Vector2(-21.5, -9), Vector2(-17.5, -10.5)]), HULL, 0.85, 1.0)
	shape(ci, PackedVector2Array([Vector2(-11, 6.3), Vector2(-17, 6.3), Vector2(-17, 11.7), Vector2(-11, 11.7)]), HULL_HI, 0.85, 1.0)
	shape(ci, PackedVector2Array([Vector2(-17, 7.2), Vector2(-19.5, 6.6), Vector2(-19.5, 11.4), Vector2(-17, 10.8)]), HULL, 0.8, 0.9)
	for c: Vector2 in [Vector2(-1, -15.2), Vector2(-3, 14.2)]:
		var sy := signf(c.y)
		shape(ci, PackedVector2Array([c + Vector2(-1.6, -sy * 0.3), c + Vector2(1.6, -sy * 0.3), c + Vector2(1.2, sy * 1.6), c + Vector2(-1.2, sy * 1.6)]), HULL_HI, 0.8, 0.8)


static func _patch_b(ci) -> void:
	shape(ci, PackedVector2Array(PATCH), HULL, 0.92, 1.5)
	# plates riveted over the hull, each a different hand
	var plates := [
		[Vector2(6, -11.5), Vector2(16, -8.5), Vector2(14, -2.5), Vector2(4, -4.5)],
		[Vector2(-11, 2), Vector2(-2, 4), Vector2(-4, 12), Vector2(-14, 9.5)],
		[Vector2(-5, -14.5), Vector2(4, -11), Vector2(2, -6.5), Vector2(-7, -7.5)],
	]
	for i in plates.size():
		var pl := PackedVector2Array(plates[i])
		FastDraw.poly(ci, pl, HULL_HI if i != 1 else Color(0.09, 0.094, 0.104))
		ring(ci, pl, ink(0.5), 0.9)
		if not Art.lite:
			for k in pl.size():
				var a := pl[k]
				var b := pl[(k + 1) % pl.size()]
				for u: float in [0.25, 0.5, 0.75]:
					bolt(ci, a.lerp(b, u) + (pl[(k + 2) % pl.size()] - a.lerp(b, u)).normalized() * 0.9, 0.45)
	if not Art.lite:
		# verdigris on the middle plate, the patch's green
		FastDraw.poly(ci, PackedVector2Array([Vector2(-10, 3.5), Vector2(-5, 5), Vector2(-6.5, 9), Vector2(-11.5, 7.5)]), acc("patchwork", 0.14, 1.0))
		# duct tape over a seam
		ci.draw_line(Vector2(9.5, -11), Vector2(11, 10), ink(0.45), 3.2)
		for k in 6:
			var p := Vector2(9.5, -11).lerp(Vector2(11, 10), (k + 0.5) / 6.0)
			ci.draw_line(p + Vector2(-1.4, -0.6), p + Vector2(1.4, 0.6), HULL, 0.5)
		# the pressure gauge's face
		FastDraw.circle(ci, Vector2(-9, -2.5), 2.2, HULL_LO)
		FastDraw.arc(ci, Vector2(-9, -2.5), 2.2, 0.0, TAU, 12, ink(0.8), 0.8, true)
	# the pipe from the can round to the front nozzle, two clamps on it
	var pipe := PackedVector2Array([Vector2(-8, -12.5), Vector2(-3, -12.8), Vector2(4, -12.0), Vector2(10, -11.6), Vector2(14, -11.3), Vector2(16.5, -11.5)])
	FastDraw.polyline(ci, pipe, ink(0.75), 1.5, true)
	if not Art.lite:
		FastDraw.polyline(ci, pipe, HULL, 0.5, true)
		for p: Vector2 in [Vector2(-3, -12.8), Vector2(10, -11.6)]:
			ci.draw_line(p + Vector2(0, -1.4), p + Vector2(0, 1.4), ink(0.9), 1.0)
	# the reversed nozzle at the front, bolted on the wrong way round
	shape(ci, PackedVector2Array([Vector2(15, -13), Vector2(17.5, -14), Vector2(17.5, -9), Vector2(15, -10)]), HULL_HI, 0.85, 0.9)
	# the porthole round the eye, six bolts round it
	FastDraw.circle(ci, Vector2.ZERO, 6.4, HULL_HI)
	FastDraw.arc(ci, Vector2.ZERO, 6.4, 0.0, TAU, 20, ink(0.9), 1.3, true)
	if not Art.lite:
		for k in 6:
			bolt(ci, Vector2.from_angle(TAU * k / 6.0 + 0.3) * 5.4, 0.7)


static func _patch_c(ci) -> void:
	# the car headlamp on its bracket, chrome rim
	ci.draw_line(Vector2(15, 5), Vector2(19.5, 7.5), ink(0.6), 1.2)
	FastDraw.circle(ci, Vector2(20, 7.8), 3.0, HULL_HI)
	FastDraw.arc(ci, Vector2(20, 7.8), 3.0, 0.0, TAU, 14, ink(0.95, 1.0), 1.0, true)


static func _patchwork(ci: CanvasItem, st: Dictionary) -> void:
	var t: float = st.t
	var lth: Vector2 = st.lth
	var rc := Art.claw_reach(st)
	layer(ci, "patch_a", _patch_a)
	# the hook boom goes under the hull's top edge
	_hook_arm(ci, rc, t)
	layer(ci, "patch_b", _patch_b)
	if not Art.lite:
		var na := -2.3 + 1.6 + 0.12 * sin(t * 23.0) + 0.6 * clampf(lth.length(), 0.0, 1.0)
		ci.draw_line(Vector2(-9, -2.5), Vector2(-9, -2.5) + Vector2.from_angle(na) * 1.7, acc("patchwork", 1.0, 1.8), 0.7)
	Art.iris(ci, Vector2.ZERO, 4.3, st.open, 6, t * 0.4, Art.tool_col(st.tool, 0.95, 1.35))
	# a string of status LEDs, one of them dead
	if not Art.lite:
		for k in 4:
			var on := k != 2 and fposmod(t * 1.3 + k * 0.27, 1.0) < 0.7
			FastDraw.circle(ci, Vector2(3 + k * 1.8, 8.6), 0.55, acc("patchwork", 1.0, 2.0) if on else ink(0.25))
	_pliers(ci, rc, t)
	layer(ci, "patch_c", _patch_c)
	var flick := 0.75 if sin(t * 4.1) * sin(t * 11.7) > 0.8 else 1.0
	FastDraw.circle(ci, Vector2(20.6, 7.8), 1.9, lit(Color(2.0 * flick, 1.7 * flick, 1.0 * flick, 1.0)))
	_jets(ci, "patchwork", st)
	_tool(ci, st, Vector2(23, 0))
