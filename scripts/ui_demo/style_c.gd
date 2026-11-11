extends Control
# C · 蓝图剖面: the berth cross-section is the page. The four doors are callouts
# with leaders to the part they open (survey → the open end where tugs come in,
# berth → the floor, methods → the furnace, drone → the parked drone). Funds,
# reputation and the station sit in the drawing's title block; facilities are
# the parts list; the next step is the revision note.

const K = preload("res://scripts/ui_demo/demo_kit.gd")

const BG := Color(0.05, 0.055, 0.062)
const INK := Color(0.9, 0.91, 0.92)
const INK2 := Color(0.62, 0.64, 0.66)
const INK3 := Color(0.4, 0.42, 0.44)
const RULE := Color(1, 1, 1, 0.22)
const O := K.ORANGE

var sel := 0.0
var t := 0.0


func _ready() -> void:
	size = Vector2(1920, 1080)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	for x in range(24, 1897, 16):
		draw_line(Vector2(x, 24), Vector2(x, 1056), Color(1, 1, 1, 0.045 if (x - 24) % 80 == 0 else 0.018), 1.0)
	for y in range(24, 1057, 16):
		draw_line(Vector2(24, y), Vector2(1896, y), Color(1, 1, 1, 0.045 if (y - 24) % 80 == 0 else 0.018), 1.0)
	_sheet()
	_heading()
	var a := K.berth(self, Rect2(150, 262, 1400, 456), {"line": INK, "dim": Color(INK, 0.45), "faint": Color(INK, 0.0),
		"label": INK2, "lsize": 15, "cone": 0.2, "num": Color(INK, 0.045), "grid": false, "tag_bg": BG,
		"hi": ["entry", "berth", "furnace", "drone"][roundi(sel)]})
	_dimension(a)
	_callouts(a)
	_parts()
	_title_block()
	_footer()


func _sheet() -> void:
	# drawing border with zone marks, like a real sheet
	var r := Rect2(24, 24, 1872, 1032)
	draw_rect(r, RULE, false, 1.0)
	for i in 12:
		var x := r.position.x + r.size.x * (i + 0.5) / 12.0
		K.txt(self, Vector2(x, 18), str(i + 1), 10, INK3, "Medium", 0.5)
		draw_line(Vector2(r.position.x + r.size.x * i / 12.0, 24), Vector2(r.position.x + r.size.x * i / 12.0, 32), RULE, 1.0)
	for i in 6:
		var y := r.position.y + r.size.y * (i + 0.5) / 6.0
		K.txt(self, Vector2(14, y + 4), "ABCDEF"[i], 10, INK3, "Medium", 0.5)
		draw_line(Vector2(24, r.position.y + r.size.y * i / 6.0), Vector2(32, r.position.y + r.size.y * i / 6.0), RULE, 1.0)


func _heading() -> void:
	draw_circle(Vector2(70, 66), 4, O)
	K.txt(self, Vector2(82, 72), K.D.online, 15, INK, "Medium")
	K.txt(self, Vector2(124, 72), K.D.title + "  ·  " + K.D.station, 15, INK2, "Regular", 0.0, 1)
	K.txt(self, Vector2(62, 136), K.D.berth_title, 56, INK, "SemiBold")
	K.txt(self, Vector2(64, 176), K.D.berth_sub, 18, INK2)
	K.txt(self, Vector2(64, 200), "SECTION A-A · BERTH 07 · 1:400", 12, INK3, "Medium", 0.0, 2)
	# next step as the revision note, top right
	var r := Rect2(1236, 56, 620, 112)
	draw_rect(r, Color(BG, 0.92))
	draw_rect(r, RULE, false, 1.0)
	draw_rect(Rect2(r.position, Vector2(4, r.size.y)), O)
	draw_line(Vector2(r.position.x + 96, r.position.y), Vector2(r.position.x + 96, r.end.y), RULE, 1.0)
	K.txt(self, r.position + Vector2(48, 44), K.D.next_kicker, 18, O, "SemiBold", 0.5)
	K.txt(self, r.position + Vector2(48, 70), "REV 11", 11, INK3, "Medium", 0.5, 2)
	K.txt(self, r.position + Vector2(116, 40), K.D.next_chapter, 15, INK2, "Medium", 0.0, 1)
	K.txt(self, r.position + Vector2(116, 84), K.D.next_body, 25, INK, "Medium")


func _dimension(a: Dictionary) -> void:
	# overall length dimension under the slab
	var y := 742.0
	var x0 := 150.0
	var x1 := 1550.0
	draw_line(Vector2(x0, y), Vector2(x1, y), INK3, 1.0)
	for x in [x0, x1]:
		draw_line(Vector2(x, y - 8), Vector2(x, y + 8), INK3, 1.0)
	var s := "船坞长 200 m"
	var w := K.width(s, 13) + 16
	draw_rect(Rect2((x0 + x1) * 0.5 - w * 0.5, y - 10, w, 20), BG)
	K.txt(self, Vector2((x0 + x1) * 0.5, y + 5), s, 13, INK2, "Regular", 0.5)


func _balloon(at: Vector2, n: String, on: float) -> void:
	draw_circle(at, 17, BG)
	if on > 0.5:
		draw_circle(at, 17, O)
		K.txt(self, at + Vector2(0, 7), n, 19, BG, "SemiBold", 0.5)
	else:
		draw_arc(at, 17, 0, TAU, 40, INK, 1.5)
		K.txt(self, at + Vector2(0, 7), n, 19, INK, "SemiBold", 0.5)


# leader from a part to a label; elbow = the corner point
func _leader(from: Vector2, elbow: Vector2, to: Vector2, on: float) -> void:
	var c: Color = Color(INK, 0.55).lerp(O, on)
	draw_circle(from, 4, c)
	draw_line(from, elbow, c, 1.5 if on > 0.5 else 1.0)
	draw_line(elbow, to, c, 1.5 if on > 0.5 else 1.0)


func _label(p: Vector2, i: int, width: float, lines: Array) -> void:
	var c: Dictionary = K.CARDS[i]
	var on := 1.0 - clampf(absf(sel - i), 0.0, 1.0)
	var h := 56.0 + lines.size() * 24.0
	var r := Rect2(p, Vector2(width, h))
	draw_rect(r, Color(BG, 0.94))
	draw_rect(r, Color(RULE, 1.0).lerp(O, on), false, 1.0 + on)
	_balloon(p + Vector2(28, 28), c.key, on)
	K.txt(self, p + Vector2(56, 38), c.name, 24, INK, "SemiBold")
	var nx := 56 + K.width(c.name, 24, "SemiBold") + 10
	if c.fresh:
		draw_circle(p + Vector2(nx + 4, 30), 4, INK)
		K.txt(self, p + Vector2(nx + 14, 35), "有新", 13, INK2)
	var y := 64.0
	for ln in lines:
		K.txt(self, p + Vector2(56, y), ln, 15, INK2)
		y += 24.0
	if on > 0.5:
		K.txt(self, Vector2(r.end.x - 14, r.position.y + 36), "Enter →", 13, O, "SemiBold", 1.0, 1)


func _callouts(a: Dictionary) -> void:
	var on := func(i: int) -> float: return 1.0 - clampf(absf(sel - i), 0.0, 1.0)
	# 1 survey → the open end
	var e: Vector2 = a.entry + Vector2(36, 0)
	_leader(e, Vector2(1640, e.y), Vector2(1640, 372), on.call(0))
	_label(Vector2(1584, 268), 0, 272, ["信号 12  ·  是船 3", "0 份报价"])
	# tug bay note under it
	K.txt(self, Vector2(1590, 560), K.D.tug_head + " · TUG BAY", 12, INK3, "Medium", 0.0, 2)
	K.txt(self, Vector2(1856, 560), "0 艘", 15, INK2, "Regular", 1.0)
	K.txt(self, Vector2(1590, 590), K.D.tug_body, 17, INK)
	# 4 drone → parked drone, label above the truss
	var d: Vector2 = a.drone
	_leader(d + Vector2(0, -8), Vector2(d.x, 214), Vector2(d.x + 30, 214), on.call(3))
	_label(Vector2(d.x + 30, 150), 3, 300, ["工具升级已安装 3/3"])
	# 3 methods → furnace; 2 berth → the floor
	var f: Vector2 = a.furnace
	# around the 金属口 label: along the floor first, then down
	_leader(f, Vector2(f.x + 64, f.y), Vector2(f.x + 64, 770), on.call(2))
	_label(Vector2(f.x + 30, 770), 2, 340, ["接下来能解锁的船、设备和设施"])
	var b: Vector2 = a.berth
	_leader(b, Vector2(b.x, 808), Vector2(b.x + 20, 808), on.call(1))
	_label(Vector2(b.x + 20, 770), 1, 380, ["待修 0 项 · 已修 18 项 · 仓库零件 10 件"])


func _parts() -> void:
	var r := Rect2(64, 784, 640, 192)
	K.txt(self, r.position + Vector2(0, 16), "船坞设施明细", 16, INK, "SemiBold")
	K.txt(self, Vector2(r.end.x, r.position.y + 16), "已修 12 / 12", 16, INK2, "Regular", 1.0)
	var top := r.position.y + 32
	var cw := r.size.x / 3.0
	var rh := 38.0
	draw_line(Vector2(r.position.x, top), Vector2(r.end.x, top), RULE, 1.0)
	for i in K.FAC.size():
		var cx := r.position.x + (i % 3) * cw
		var cy := top + (i / 3) * rh
		K.txt(self, Vector2(cx + 4, cy + 26), "%02d" % (i + 1), 12, INK3, "Medium")
		K.txt(self, Vector2(cx + 30, cy + 27), K.FAC[i], 16, INK)
		K.txt(self, Vector2(cx + cw - 12, cy + 27), "✓", 15, INK2, "Regular", 1.0)
		if i % 3 == 0:
			draw_line(Vector2(r.position.x, cy + rh), Vector2(r.end.x, cy + rh), Color(1, 1, 1, 0.1), 1.0)
	for k in [1, 2]:
		draw_line(Vector2(r.position.x + k * cw, top), Vector2(r.position.x + k * cw, top + rh * 4), Color(1, 1, 1, 0.1), 1.0)


func _title_block() -> void:
	var r := Rect2(1236, 866, 620, 128)
	draw_rect(r, Color(BG, 0.94))
	draw_rect(r, RULE, false, 1.0)
	draw_line(Vector2(r.position.x + 330, r.position.y), Vector2(r.position.x + 330, r.end.y), RULE, 1.0)
	K.txt(self, r.position + Vector2(16, 26), "资金 · FUNDS", 11, INK3, "Medium", 0.0, 2)
	K.txt(self, r.position + Vector2(14, 100), K.D.funds, 58, INK, "Light")
	var x := r.position.x + 346
	K.txt(self, Vector2(x, r.position.y + 26), "声望 · REPUTATION", 11, INK3, "Medium", 0.0, 2)
	K.txt(self, Vector2(x, r.position.y + 72), K.D.rep, 32, INK, "Medium")
	var bw := r.end.x - 16 - x
	draw_rect(Rect2(x, r.position.y + 90, bw, 6), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(x, r.position.y + 90, bw * K.D.rep_have / float(K.D.rep_need), 6), O)
	for k in range(1, 12):
		draw_line(Vector2(x + bw * k / 12.0, r.position.y + 90), Vector2(x + bw * k / 12.0, r.position.y + 96), BG, 1.0)
	K.txt(self, Vector2(x, r.position.y + 118), K.D.rep_left, 13, INK2)


func _footer() -> void:
	K.txt(self, Vector2(64, 1036), K.D.footer, 15, INK2)
	var x := 1856.0
	for i in range(K.SIDE_KEYS.size() - 1, -1, -1):
		var k: Array = K.SIDE_KEYS[i]
		var lw := K.width(k[0], 16, "Medium")
		var kw := K.width(k[1], 13, "SemiBold") + 12
		var bw := lw + kw + 30
		var r := Rect2(x - bw, 1008, bw, 38)
		draw_rect(r, Color(BG, 0.94))
		draw_rect(r, RULE, false, 1.0)
		K.txt(self, r.position + Vector2(12, 25), k[0], 16, INK, "Medium")
		var kr := Rect2(r.end.x - kw - 10, r.position.y + 9, kw, 20)
		draw_rect(kr, Color(1, 1, 1, 0.85))
		K.txt(self, kr.get_center() + Vector2(0, 5), k[1], 13, BG, "SemiBold", 0.5)
		x -= bw + 12
