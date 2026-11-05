extends RefCounted
# 星图的动效曲线与形状（2026-11-04，用户点名的 motion-prompt 条目），按原版时长与缓动移植成 Godot。
# Motion Prompt #001-024 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#001
# Motion Prompt #121-144 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#121
# Motion Prompt #049-072 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#049
# Motion Prompt #145-168 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#145


# ---------------------------------------------------------------- the kit's curves (motion kit)

static func P(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


static func eIO(x: float) -> float:
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0


static func eIOs(x: float) -> float:
	return 2.0 * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 2.0) / 2.0


static func eOut(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


static func eOut5(x: float) -> float:
	return 1.0 - pow(1.0 - x, 5.0)


static func backOut(x: float, s := 1.70158) -> float:
	return 1.0 + (s + 1.0) * pow(x - 1.0, 3.0) + s * pow(x - 1.0, 2.0)


# ---------------------------------------------------------------- #012 Shape morph
# Motion Prompt #012 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#012
# 每个轮廓 240 个点，同序号线性插值；形变 0.58 秒，backOut(s = 1.6) 略过冲；过程中放大
# 1 + 0.07·sin(π·进度)；颜色二次缓入缓出。这里的轮廓：未分析的菱形 ◇、船的标记 ▲、石头的
# 不规则多边形；悬停时的圆圈准星和方括号锁定框。

const MN := 240
const MORPH_S := 0.58


# a closed polygon as MN points, every point the polygon's edge on the ray at its angle (the same
# angles for every shape, from straight up clockwise, so index i always pairs with index i)
static func outline(verts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in MN:
		var a := float(i) / MN * TAU - PI * 0.5
		var d := Vector2(cos(a), sin(a))
		var best := 0.0
		for j in verts.size():
			var p := verts[j]
			var q := verts[(j + 1) % verts.size()]
			var e := q - p
			var den := d.x * e.y - d.y * e.x
			if absf(den) < 1e-6:
				continue
			var tt := (p.x * e.y - p.y * e.x) / den
			var u := (p.x * d.y - p.y * d.x) / den
			if tt > 0.0 and u >= -1e-4 and u <= 1.0 + 1e-4:
				best = tt if best == 0.0 else minf(best, tt)
		out.append(d * best)
	return out


static var _shapes := {}


static func shape(name: String, seed := 0) -> PackedVector2Array:
	var key := "%s%d" % [name, seed]
	if _shapes.has(key):
		return _shapes[key]
	var o: PackedVector2Array
	match name:
		"circle":
			o = PackedVector2Array()
			for i in MN:
				var a := float(i) / MN * TAU - PI * 0.5
				o.append(Vector2(cos(a), sin(a)))
		"diamond":
			o = outline(PackedVector2Array([Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]))
		"square":
			o = outline(PackedVector2Array([Vector2(-0.8, -0.8), Vector2(0.8, -0.8), Vector2(0.8, 0.8), Vector2(-0.8, 0.8)]))
		"ship":
			# the ship marker, pointing up like the found hulks' triangles (centred on its middle)
			o = outline(PackedVector2Array([Vector2(0, -1.2), Vector2(1.0, 0.85), Vector2(-1.0, 0.85)]))
		"rock":
			var rng := RandomNumberGenerator.new()
			rng.seed = seed
			var v := PackedVector2Array()
			var n := 7
			for i in n:
				var a := float(i) / n * TAU - PI * 0.5 + rng.randf_range(-0.25, 0.25)
				v.append(Vector2(cos(a), sin(a)) * rng.randf_range(0.62, 1.0))
			o = outline(v)
	_shapes[key] = o
	return o


# the morph at time s since it began: [points blended, colour blend, scale]
static func morph_k(s: float) -> Array:
	var pr := P(s, 0.0, MORPH_S)
	return [backOut(pr, 1.6), eIOs(pr), 1.0 + 0.07 * sin(PI * pr)]


static func blend(a: PackedVector2Array, b: PackedVector2Array, p: float, at: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(MN)
	for i in MN:
		out[i] = at + a[i].lerp(b[i], p) * r
	return out


# ---------------------------------------------------------------- #125 Pulse
# Motion Prompt #125 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#125
# 每 1.175 秒一次“扑通扑通”双拍：放大 1 + 0.26·G(0.2, 0.065) + 0.15·G(0.44, 0.07)；两圈轮廓在
# 0.16 秒和 0.40 秒放出，0.8 秒内 1.2→2.4 倍（三次缓出），不透明度 0.75→0（第二圈 60%），线宽变细。

const BEAT := 1.175


static func beat_scale(lu: float) -> float:
	var g := func(c: float, s: float) -> float: return exp(-pow((lu - c) / s, 2.0))
	return 1.0 + 0.26 * g.call(0.2, 0.065) + 0.15 * g.call(0.44, 0.07) + 0.26 * exp(-pow((lu - BEAT - 0.2) / 0.065, 2.0))


# the two rings at lu: [[scale, alpha, width k (1 at the start, 0 at the end)], ...]
static func beat_rings(lu: float) -> Array:
	var out: Array = []
	for spec in [[0.16, 1.0], [0.4, 0.6]]:
		var q := P(lu, spec[0], spec[0] + 0.8)
		if q <= 0.0 or q >= 1.0:
			continue
		out.append([1.2 + 1.2 * eOut(q), (1.0 - q) * 0.75 * float(spec[1]), 1.0 - q])
	return out


# ---------------------------------------------------------------- #004 Line draw
# Motion Prompt #004 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#004
# 线条按修剪路径画出：0.4–1.95 秒三次缓入缓出；画的时候先端骑着一个点；箭头在 1.9–2.2 秒
# backOut(s = 2.5) 张开。这里画的是拖船航线。

static func draw_on(age: float) -> float:
	return eIO(P(age, 0.4, 1.95))


static func arrow_open(age: float) -> float:
	return backOut(P(age, 1.9, 2.2), 2.5)


# ---------------------------------------------------------------- #069 Skeleton screen
# Motion Prompt #069 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#069
# 内容 0.15 秒（线性）换成同形状的圆角骨架块；一道 160 宽的光带（两端透明、中间 0.75）每 0.9 秒从
# 左外侧扫到右外侧，只画在骨架块上；结束时 0.3 秒（线性）换回内容。

const SKEL_IN := 0.15
const SKEL_SWEEP := 0.9
const SKEL_BAND := 160.0


# ---------------------------------------------------------------- #005 Mask reveal
# Motion Prompt #005 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#005
# 一条线 0.1–0.5 秒从中间长出（三次缓入缓出）；文字只在线的上方可见，0.35–1.0 秒从下方升到位
# （五次缓出）；不改不透明度，只靠裁剪。这里线在升完后 2.05–2.3 秒缩掉（原版的退场线）。

static func reveal_line(s: float) -> float:
	return eIO(P(s, 0.1, 0.5)) * (1.0 - eIO(P(s, 2.05, 2.3)))


# how far below its place the words still are, 0..1 of the drop
static func reveal_drop(s: float, delay := 0.0) -> float:
	return 1.0 - eOut5(P(s, 0.35 + delay, 1.0 + delay))


# ---------------------------------------------------------------- #154 Spotlight hover
# Motion Prompt #154 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#154
# 光点就在指针上，不滞后：卡片里面只亮一个半径 115 的白色径向光（中心 0.34→0），不溢出卡片；
# 卡片描边按到指针的距离发光，半径 120 的橙色径向光。实现在 star_map_fx.gd 的 SHEEN 着色器。

# ---------------------------------------------------------------- #016 Parallax
# Motion Prompt #016 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#016
# 镜头平移 ±108 px，各层按 平移 × 系数 反向移动，从远到近 0.05、0.1、0.28、0.6、1.25、2.1；越远越暗。
# 实现在 star_map_fx.gd 的 SPACE 着色器（远星 0.05、星尘 0.1、中层星 0.28、近层亮星 0.6）。
const PAN_PX := 108.0
