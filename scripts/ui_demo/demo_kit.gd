extends RefCounted
# UI style proposals for the berth terminal's home page (demo only, not wired
# into the game). Shared data, text helpers and the berth cross-section that all
# four styles draw in their own palette. tests/ui_style_demo.gd takes the shots.

const ORANGE := Color(1.0, 0.353, 0.122)

const D := {
	"title": "船坞终端",
	"station": "123 · CHARON-DISPATCH",
	"online": "在线",
	"funds": "$714,573",
	"rep": "资深",
	"rep_have": 9, "rep_need": 12, "rep_left": "距下一级还差 3 点",
	"next_kicker": "下一步",
	"next_chapter": "第 11 章 · 远航者",
	"next_body": "远航者工程还没做好，以后的版本开放。",
	"berth_title": "船坞空着",
	"berth_sub": "船坞设施已修 12 / 12 · 拖船区 0 艘",
	"tug_head": "拖船区",
	"tug_body": "空着——去「找船」派拖船",
	"fac_head": "船坞设施 · 已修 12 / 12",
	"footer": "1–4 应用 · ←→↑↓ 选择 · Enter 确认 · O 设置 · Esc 回首页 / 回到船坞",
}

const FAC := ["照明与配电", "缓冲平台", "碎屑网", "作业区管理", "熔炉主火", "碎屑网升级",
	"初级搬运无人机", "第二台搬运无人机", "第二设备回收口", "工业回收机械臂", "可移动炉口", "重型起重机"]

# the four doors off the home page; "fresh" = something new waits inside
const CARDS := [
	{"key": "1", "name": "找船", "en": "SURVEY", "meta": "信号 12  ·  是船 3", "foot": "0 份报价", "fresh": true},
	{"key": "2", "name": "船坞", "en": "BERTH", "meta": "12 / 12", "foot": "待修 0 项 · 已修 18 项 · 仓库零件 10 件", "fresh": true},
	{"key": "3", "name": "拆法与建设", "en": "METHODS", "meta": "", "foot": "接下来能解锁的船、设备和设施", "fresh": false},
	{"key": "4", "name": "无人机升级", "en": "DRONE", "meta": "3 / 3", "foot": "工具升级已安装 3/3", "fresh": false},
]

const SIDE_KEYS := [["仓库", "F3"], ["电网调度", "F5"], ["交易行 · 买入 / 出售", "F8"]]

static var _fonts := {}


# weight: Light / Regular / Medium / SemiBold; spacing = extra px per glyph;
# tnum = fixed-width digits so numbers don't wobble when they change
static func font(weight: String = "Regular", spacing: int = 0, tnum: bool = true) -> Font:
	var k := "%s|%d|%s" % [weight, spacing, tnum]
	if _fonts.has(k):
		return _fonts[k]
	var fv := FontVariation.new()
	fv.base_font = Fonts.get_font(weight)
	fv.spacing_glyph = spacing
	if tnum:
		fv.opentype_features = {"tnum": 1}
	_fonts[k] = fv
	return fv


static func width(s: String, size: int, weight: String = "Regular", spacing: int = 0) -> float:
	return font(weight, spacing).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


# pos is the baseline's left end (or right end with align=1, centre with align=0.5)
static func txt(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, weight: String = "Regular", align: float = 0.0, spacing: int = 0) -> float:
	var w := width(s, size, weight, spacing)
	ci.draw_string(font(weight, spacing), pos - Vector2(w * align, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	return w


static func zig(ci: CanvasItem, a: Vector2, b: Vector2, h: float, step: float, col: Color, w: float = 1.0) -> void:
	var n := maxi(1, int((b.x - a.x) / step))
	var pts := PackedVector2Array()
	for i in n + 1:
		pts.append(Vector2(lerpf(a.x, b.x, float(i) / n), a.y + (h if i % 2 else 0.0)))
	ci.draw_polyline(pts, col, w)


static func hatch(ci: CanvasItem, r: Rect2, step: float, col: Color, w: float = 1.0) -> void:
	var x := r.position.x - r.size.y
	while x < r.end.x:
		var a := Vector2(x, r.end.y)
		var b := Vector2(x + r.size.y, r.position.y)
		# clip both ends into the rect
		if a.x < r.position.x:
			a = Vector2(r.position.x, r.end.y - (r.position.x - a.x))
		if b.x > r.end.x:
			b = Vector2(r.end.x, r.position.y + (b.x - r.end.x))
		ci.draw_line(a, b, col, w)
		x += step


static func corners(ci: CanvasItem, r: Rect2, len: float, col: Color, w: float = 1.0) -> void:
	for c in [[r.position, 1, 1], [Vector2(r.end.x, r.position.y), -1, 1], [Vector2(r.position.x, r.end.y), 1, -1], [r.end, -1, -1]]:
		var p: Vector2 = c[0]
		ci.draw_line(p, p + Vector2(len * c[1], 0), col, w)
		ci.draw_line(p, p + Vector2(0, len * c[2]), col, w)


static func led(ci: CanvasItem, at: Vector2, r: float, on: bool, col: Color, off_col: Color) -> void:
	if on:
		for i in 4:
			ci.draw_circle(at, r * (3.2 - i * 0.55), Color(col, 0.05 + i * 0.03))
		ci.draw_circle(at, r, col)
		ci.draw_circle(at - Vector2(r, r) * 0.3, r * 0.35, Color(1, 1, 1, 0.55))
	else:
		ci.draw_circle(at, r, off_col)


# The berth cross-section. o: line, dim, faint, acc, label, fill (Colors),
# lsize (label px), hi (part to light in the accent), big07 (bool), grid (bool),
# tags (bool: the ✓ tags), cone (lamp light alpha).
# Returns anchor points for callouts.
static func berth(ci: CanvasItem, r: Rect2, o: Dictionary) -> Dictionary:
	var X := func(f: float) -> float: return r.position.x + r.size.x * f
	var Y := func(f: float) -> float: return r.position.y + r.size.y * f
	var line: Color = o.get("line", Color(0.85, 0.86, 0.88))
	var dim: Color = o.get("dim", Color(line, 0.45))
	var faint: Color = o.get("faint", Color(line, 0.08))
	var acc: Color = o.get("acc", ORANGE)
	var lab: Color = o.get("label", line)
	var ls: int = o.get("lsize", 14)
	var hi: String = o.get("hi", "")
	var fy: float = Y.call(0.86)
	# fine grid behind
	if o.get("grid", true):
		var gx := 0.06
		while gx < 0.98:
			ci.draw_line(Vector2(X.call(gx), Y.call(0.13)), Vector2(X.call(gx), fy), faint, 1.0)
			gx += 0.06
		for gy in [0.3, 0.48, 0.66]:
			ci.draw_line(Vector2(X.call(0.02), Y.call(gy)), Vector2(X.call(0.98), Y.call(gy)), faint, 1.0)
	# the hull number, huge and quiet
	if o.get("big07", true):
		var hs := int(r.size.y * 0.42)
		txt(ci, Vector2(X.call(0.5), Y.call(0.79)), "07", hs, o.get("num", Color(line, 0.07)), "SemiBold", 0.5)
	# overhead truss
	ci.draw_line(Vector2(X.call(0.02), Y.call(0.03)), Vector2(X.call(0.98), Y.call(0.03)), line, 1.5)
	ci.draw_line(Vector2(X.call(0.02), Y.call(0.09)), Vector2(X.call(0.98), Y.call(0.09)), line, 1.5)
	zig(ci, Vector2(X.call(0.02), Y.call(0.03)), Vector2(X.call(0.98), Y.call(0.03)), r.size.y * 0.06, r.size.x * 0.03, dim)
	ci.draw_line(Vector2(X.call(0.02), Y.call(0.13)), Vector2(X.call(0.98), Y.call(0.13)), dim, 1.0)
	# left wall truss
	ci.draw_line(Vector2(X.call(0.0), Y.call(0.03)), Vector2(X.call(0.0), fy), line, 1.5)
	ci.draw_line(Vector2(X.call(0.02), Y.call(0.03)), Vector2(X.call(0.02), fy), line, 1.5)
	var yy := 0.03
	while yy < 0.84:
		ci.draw_line(Vector2(X.call(0.0), Y.call(yy)), Vector2(X.call(0.02), Y.call(yy + 0.05)), dim, 1.0)
		yy += 0.05
	# gantry column of the crane
	var col_r := Rect2(X.call(0.105), Y.call(0.0), r.size.x * 0.035, fy - Y.call(0.0))
	ci.draw_rect(col_r, Color(line, 0.05))
	ci.draw_line(col_r.position, Vector2(col_r.position.x, col_r.end.y), dim, 1.0)
	ci.draw_line(Vector2(col_r.end.x, col_r.position.y), col_r.end, dim, 1.0)
	# hook
	ci.draw_line(Vector2(X.call(0.08), Y.call(0.13)), Vector2(X.call(0.08), Y.call(0.21)), dim, 1.0)
	ci.draw_rect(Rect2(X.call(0.072), Y.call(0.13), r.size.x * 0.016, 4), line)
	ci.draw_rect(Rect2(X.call(0.077), Y.call(0.21), 6, 6), line)
	# lamps and their light
	var lamp_hi := hi == "lamp"
	for lx in [0.235, 0.355]:
		var top := Vector2(X.call(lx), Y.call(0.14))
		var w0 := r.size.x * 0.006
		var w1 := r.size.x * 0.045
		var ca: float = o.get("cone", 0.32)
		var cc: Color = acc if lamp_hi else line
		ci.draw_polygon(PackedVector2Array([top + Vector2(-w0, 0), top + Vector2(w0, 0), Vector2(top.x + w1, fy), Vector2(top.x - w1, fy)]),
			PackedColorArray([Color(cc, ca), Color(cc, ca), Color(cc, 0.0), Color(cc, 0.0)]))
		ci.draw_rect(Rect2(top + Vector2(-8, -5), Vector2(16, 5)), acc if lamp_hi else line)
	# floor, conveyor and hatched slab
	ci.draw_line(Vector2(X.call(0.02), fy), Vector2(X.call(0.98), fy), line, 2.0)
	ci.draw_line(Vector2(X.call(0.04), Y.call(0.84)), Vector2(X.call(0.88), Y.call(0.84)), dim, 2.0)
	hatch(ci, Rect2(X.call(0.02), fy + 3, r.size.x * 0.96, r.size.y * 0.05), 7.0, Color(line, 0.25))
	# debris net
	var nc: Color = acc if hi == "net" else dim
	for k in 3:
		zig(ci, Vector2(X.call(0.07), Y.call(0.795) + k * 3), Vector2(X.call(0.2), Y.call(0.795) + k * 3), 4, 5, nc)
	# furnace main fire
	var fr := Rect2(X.call(0.465), Y.call(0.80), r.size.x * 0.03, r.size.y * 0.04)
	ci.draw_rect(fr, Color(acc, 0.85) if hi == "furnace" else Color(line, 0.3))
	ci.draw_rect(fr, acc if hi == "furnace" else line, false, 1.0)
	# small drone parked under the truss
	var dr := Vector2(X.call(0.385), Y.call(0.23))
	var dc: Color = acc if hi == "drone" else line
	ci.draw_rect(Rect2(dr - Vector2(14, 4), Vector2(28, 8)), Color(dc, 0.25))
	ci.draw_rect(Rect2(dr - Vector2(14, 4), Vector2(28, 8)), dc, false, 1.0)
	ci.draw_line(dr + Vector2(-20, -7), dr + Vector2(-8, -7), dc, 1.0)
	ci.draw_line(dr + Vector2(8, -7), dr + Vector2(20, -7), dc, 1.0)
	# hazmat port marker, on the open (tug) end
	var hz := Rect2(X.call(0.895), Y.call(0.79), r.size.x * 0.03, r.size.y * 0.025)
	ci.draw_rect(hz, Color(acc, 0.6))
	# the open end: where the tug brings ships in
	var entry := Vector2(X.call(0.98), Y.call(0.48))
	var ec: Color = acc if hi == "entry" else dim
	for k in 3:
		var ex: float = entry.x + 14 + k * 12
		ci.draw_line(Vector2(ex, entry.y - 10), Vector2(ex - 8, entry.y), ec, 1.5)
		ci.draw_line(Vector2(ex - 8, entry.y), Vector2(ex, entry.y + 10), ec, 1.5)
	# port labels under the slab
	var py: float = fy + r.size.y * 0.05 + ls + 6
	if o.get("ports", true):
		txt(ci, Vector2(X.call(0.385), py), "设备口", ls, lab, "Regular", 0.5)
		txt(ci, Vector2(X.call(0.48), py), "金属口", ls, lab, "Regular", 0.5)
		txt(ci, Vector2(X.call(0.91), py), "危险品口", ls, acc, "Regular", 0.5)
		for px in [0.385, 0.48, 0.91]:
			ci.draw_line(Vector2(X.call(px), fy + r.size.y * 0.055), Vector2(X.call(px), py - ls - 2), Color(lab, 0.4), 1.0)
	if o.get("tags", true):
		_tag(ci, Vector2(X.call(0.255), Y.call(0.13)), Vector2(X.call(0.27), Y.call(0.06)), "照明与配电 ✓", ls, lab, o)
		_tag(ci, Vector2(X.call(0.13), Y.call(0.79)), Vector2(X.call(0.15), Y.call(0.70)), "碎屑网 ✓", ls, lab, o)
		_tag(ci, Vector2(X.call(0.48), Y.call(0.80)), Vector2(X.call(0.5), Y.call(0.70)), "熔炉主火 ✓", ls, lab, o)
	return {"lamp": Vector2(X.call(0.355), Y.call(0.14)), "net": Vector2(X.call(0.13), Y.call(0.8)),
		"furnace": fr.get_center(), "drone": dr, "entry": entry, "haz": hz.get_center(), "floor": fy,
		"berth": Vector2(X.call(0.76), Y.call(0.84))}


static func _tag(ci: CanvasItem, from: Vector2, to: Vector2, s: String, ls: int, col: Color, o: Dictionary) -> void:
	var bg: Color = o.get("tag_bg", Color(0, 0, 0, 0))
	ci.draw_line(from, to, Color(col, 0.7), 1.0)
	var w := width(s, ls)
	if bg.a > 0.0:
		ci.draw_rect(Rect2(to + Vector2(2, -ls - 3), Vector2(w + 10, ls + 8)), bg)
	ci.draw_line(to, to + Vector2(0, -ls - 2), col, 1.0)
	txt(ci, to + Vector2(7, -3), s, ls, col)


static func box(ci: CanvasItem, r: Rect2, bg: Color, radius: int = 0, border: Color = Color(0, 0, 0, 0), bw: int = 0,
		shadow: Color = Color(0, 0, 0, 0), ssize: int = 0, soff: Vector2 = Vector2.ZERO) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 8
	sb.anti_aliasing = true
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	if ssize > 0:
		sb.shadow_color = shadow
		sb.shadow_size = ssize
		sb.shadow_offset = soff
	ci.draw_style_box(sb, r)


static func vgrad(ci: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


# tiny pictograms for the four doors, drawn in a w×h box
static func icon(ci: CanvasItem, which: int, r: Rect2, col: Color, acc: Color, t: float = 0.0) -> void:
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y)
	match which:
		0:  # survey radar
			for k in 3:
				ci.draw_arc(c, s * (0.18 + k * 0.16), 0, TAU, 48, Color(col, 0.5), 1.0)
			ci.draw_line(c - Vector2(s * 0.5, 0), c + Vector2(s * 0.5, 0), Color(col, 0.3), 1.0)
			ci.draw_line(c - Vector2(0, s * 0.5), c + Vector2(0, s * 0.5), Color(col, 0.3), 1.0)
			var a := -2.2 + t
			for k in 10:
				ci.draw_line(c, c + Vector2.from_angle(a - k * 0.05) * s * 0.5, Color(acc, 0.5 - k * 0.045), 2.0)
			ci.draw_circle(c + Vector2(s * 0.12, s * 0.2), 3.5, acc)
			ci.draw_circle(c + Vector2(-s * 0.25, -s * 0.08), 2.5, col)
			ci.draw_circle(c + Vector2(s * 0.3, -s * 0.22), 2.5, col)
		1:  # berth
			var rr := Rect2(r.position + Vector2(0, s * 0.2), Vector2(r.size.x, r.size.y - s * 0.3))
			ci.draw_line(rr.position, Vector2(rr.end.x, rr.position.y), col, 1.5)
			zig(ci, rr.position, Vector2(rr.end.x, rr.position.y), 6, 10, Color(col, 0.6))
			ci.draw_line(rr.position, Vector2(rr.position.x, rr.end.y), col, 1.5)
			ci.draw_line(Vector2(rr.position.x, rr.end.y), rr.end, col, 1.5)
			for lx in [0.35, 0.65]:
				var top := Vector2(rr.position.x + rr.size.x * lx, rr.position.y + 6)
				ci.draw_polygon(PackedVector2Array([top, Vector2(top.x + 14, rr.end.y), Vector2(top.x - 14, rr.end.y)]),
					PackedColorArray([Color(col, 0.35), Color(col, 0.0), Color(col, 0.0)]))
		2:  # build: a row of slots, one still unknown
			var n := 5
			var w := r.size.x / n
			for k in n:
				var b := Rect2(r.position.x + k * w + 3, c.y - w * 0.4, w - 6, w * 0.8)
				if k == 3:
					ci.draw_dashed_line(b.position, Vector2(b.end.x, b.position.y), col, 1.0, 3.0)
					ci.draw_dashed_line(Vector2(b.position.x, b.end.y), b.end, col, 1.0, 3.0)
					ci.draw_dashed_line(b.position, Vector2(b.position.x, b.end.y), col, 1.0, 3.0)
					ci.draw_dashed_line(Vector2(b.end.x, b.position.y), b.end, col, 1.0, 3.0)
					txt(ci, b.get_center() + Vector2(0, 6), "?", 16, col, "Medium", 0.5)
				else:
					ci.draw_rect(b, Color(col, 0.18 if k < 3 else 0.06))
					ci.draw_rect(b, Color(col, 0.7 if k < 3 else 0.3), false, 1.0)
		3:  # drone
			var hw := s * 0.42
			var hh := s * 0.2
			var pts := PackedVector2Array([c + Vector2(-hw, 0), c + Vector2(-hw * 0.6, -hh), c + Vector2(hw * 0.6, -hh), c + Vector2(hw, 0), c + Vector2(hw * 0.6, hh), c + Vector2(-hw * 0.6, hh), c + Vector2(-hw, 0)])
			ci.draw_polyline(pts, col, 1.5)
			ci.draw_arc(c, hh * 0.5, 0, TAU, 24, col, 1.5)
