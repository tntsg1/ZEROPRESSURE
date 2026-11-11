extends Control
# B · 战术终端: near-black, fixed-width digits and tracked caps, a hairline grid,
# scanlines, dense readouts. Zones are marked by corner ticks, never boxed. The
# four doors are a command list on the left; facilities a status matrix.

const K = preload("res://scripts/ui_demo/demo_kit.gd")

const BG := Color(0.028, 0.032, 0.038)
const INK := Color(0.9, 0.91, 0.92)
const INK2 := Color(0.6, 0.62, 0.64)
const INK3 := Color(0.38, 0.4, 0.42)
const LINE := Color(1, 1, 1, 0.1)
const O := K.ORANGE

var sel := 0.0
var t := 0.0


func _ready() -> void:
	size = Vector2(1920, 1080)


func _cap(at: Vector2, s: String, col: Color = INK3, size_px: int = 12) -> float:
	return K.txt(self, at, s, size_px, col, "Medium", 0.0, 2)


func _zone(r: Rect2, label: String, code: String) -> void:
	K.corners(self, r, 14, Color(1, 1, 1, 0.45), 1.0)
	_cap(r.position + Vector2(0, -10), label, INK2)
	K.txt(self, Vector2(r.end.x, r.position.y - 10), code, 12, INK3, "Medium", 1.0, 2)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	for x in range(0, 1921, 40):
		draw_line(Vector2(x, 0), Vector2(x, 1080), Color(1, 1, 1, 0.022), 1.0)
	for y in range(0, 1081, 40):
		draw_line(Vector2(0, y), Vector2(1920, y), Color(1, 1, 1, 0.022), 1.0)
	_top()
	_directive()
	_commands()
	_berth()
	_matrix()
	_footer()
	# scanlines; the live version adds a slow faint band rolling down
	for y in range(0, 1080, 3):
		draw_line(Vector2(0, y), Vector2(1920, y), Color(0, 0, 0, 0.16), 1.0)
	if t > 0.0:
		var by := fmod(t * 300.0, 1180.0) - 100.0
		K.vgrad(self, Rect2(0, by, 1920, 60), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.004))


func _top() -> void:
	_cap(Vector2(64, 40), "ZERO PRESSURE // DOCK TERMINAL", INK3)
	K.txt(self, Vector2(64, 84), K.D.title, 34, INK, "SemiBold")
	var x := 64 + K.width(K.D.title, 34, "SemiBold") + 26
	draw_circle(Vector2(x + 5, 73), 4, O)
	draw_arc(Vector2(x + 5, 73), 8 + fmod(t * 6, 4), 0, TAU, 24, Color(O, 0.35), 1.0)
	K.txt(self, Vector2(x + 18, 80), K.D.online, 17, INK, "Medium")
	K.txt(self, Vector2(x + 64, 80), K.D.station, 17, INK2, "Regular", 0.0, 2)
	# right: readouts separated by hairlines
	var fx := 1180.0
	draw_line(Vector2(fx - 28, 30), Vector2(fx - 28, 96), LINE, 1.0)
	_cap(Vector2(fx, 40), "资金 · FUNDS", INK3)
	K.txt(self, Vector2(fx, 88), K.D.funds, 40, INK, "Medium", 0.0, 1)
	var rx := 1520.0
	draw_line(Vector2(rx - 28, 30), Vector2(rx - 28, 96), LINE, 1.0)
	_cap(Vector2(rx, 40), "声望 · REP", INK3)
	K.txt(self, Vector2(rx, 84), K.D.rep, 30, INK, "Medium")
	for i in 12:
		var on: bool = i < K.D.rep_have
		var bx := rx + 76 + i * 22
		draw_rect(Rect2(bx, 64, 16, 18), O if on else Color(0, 0, 0, 0))
		if not on:
			draw_rect(Rect2(bx + 0.5, 64.5, 15, 17), Color(1, 1, 1, 0.3), false, 1.0)
	K.txt(self, Vector2(1856, 104), K.D.rep_left, 12, INK2, "Regular", 1.0)
	draw_line(Vector2(64, 120), Vector2(1856, 120), LINE, 1.0)
	for x2 in range(64, 1857, 16):
		draw_line(Vector2(x2, 120), Vector2(x2, 124 if x2 % 80 else 128), Color(1, 1, 1, 0.18), 1.0)


func _directive() -> void:
	var r := Rect2(64, 176, 432, 158)
	_zone(r, "下一步 // DIRECTIVE", "CH.11")
	K.txt(self, r.position + Vector2(22, 40), K.D.next_chapter, 16, O, "Medium", 0.0, 1)
	K.txt(self, r.position + Vector2(22, 84), "远航者工程还没做好，", 24, INK, "Medium")
	K.txt(self, r.position + Vector2(22, 120), "以后的版本开放。", 24, INK, "Medium")
	var cx := 22 + K.width("以后的版本开放。", 24, "Medium") + 6
	if fmod(t, 1.0) < 0.6:
		draw_rect(Rect2(r.position + Vector2(cx, 98), Vector2(12, 26)), Color(O, 0.9))


func _commands() -> void:
	var r := Rect2(64, 388, 432, 520)
	_zone(r, "入口 // COMMANDS", "4")
	var rh := 124.0
	# the highlight slides between rows
	var hy := r.position.y + 8 + sel * (rh + 4)
	draw_rect(Rect2(r.position.x, hy, r.size.x, rh), Color(O, 0.018))
	draw_rect(Rect2(r.position.x, hy, 4, rh), O)
	for i in 4:
		var c: Dictionary = K.CARDS[i]
		var y := r.position.y + 8 + i * (rh + 4)
		var on := 1.0 - clampf(absf(sel - i), 0.0, 1.0)
		var kc := INK2.lerp(O, on)
		var kr := Rect2(r.position.x + 22, y + 22, 40, 40)
		draw_rect(kr, Color(kc, 0.9), false, 1.0)
		K.txt(self, kr.get_center() + Vector2(0, 9), c.key, 24, kc, "Medium", 0.5)
		K.txt(self, Vector2(r.position.x + 80, y + 50), c.name, 26, INK, "SemiBold")
		_cap(Vector2(r.position.x + 82 + K.width(c.name, 26, "SemiBold") + 6, y + 49), c.en, INK3, 11)
		if c.fresh:
			var tw := K.width("NEW", 11, "SemiBold", 2) + 12
			draw_rect(Rect2(r.end.x - 14 - tw, y + 30, tw, 20), Color(1, 1, 1, 0.9))
			K.txt(self, Vector2(r.end.x - 20, y + 45), "NEW", 11, BG, "SemiBold", 1.0, 2)
		K.txt(self, Vector2(r.position.x + 80, y + 84), c.foot, 15, INK2)
		if c.meta != "":
			K.txt(self, Vector2(r.position.x + 80, y + 108), c.meta, 15, INK, "Medium", 0.0, 1)
		if on > 0.5:
			K.txt(self, Vector2(r.end.x - 20, y + 108), "ENTER →", 13, O, "SemiBold", 1.0, 2)
		if i < 3:
			draw_line(Vector2(r.position.x + 22, y + rh + 2), Vector2(r.end.x, y + rh + 2), Color(1, 1, 1, 0.06), 1.0)


func _berth() -> void:
	var r := Rect2(560, 176, 1296, 432)
	_zone(r, "船坞 // BERTH 07", "SECTION A-A")
	K.txt(self, r.position + Vector2(24, 52), K.D.berth_title, 30, INK, "SemiBold")
	K.txt(self, r.position + Vector2(24 + K.width(K.D.berth_title, 30, "SemiBold") + 18, 51), K.D.berth_sub, 16, INK2)
	# tug bay readout on the right of the header
	_cap(Vector2(r.end.x - 360, r.position.y + 32), "拖船区 · TUG BAY", INK3)
	K.txt(self, Vector2(r.end.x - 360, r.position.y + 58), K.D.tug_body, 18, INK, "Medium")
	K.txt(self, Vector2(r.end.x - 24, r.position.y + 34), "0 艘", 18, INK, "Medium", 1.0)
	var sr := Rect2(r.position + Vector2(40, 96), Vector2(r.size.x - 120, 286))
	# metre ticks along the bottom and left edge
	for i in 11:
		var x := sr.position.x + sr.size.x * i / 10.0
		draw_line(Vector2(x, sr.end.y + 34), Vector2(x, sr.end.y + 40), INK3, 1.0)
		K.txt(self, Vector2(x, sr.end.y + 54), "%d" % (i * 20), 11, INK3, "Regular", 0.5)
	var a := K.berth(self, sr, {"line": INK, "dim": Color(INK, 0.4), "faint": Color(INK, 0.05), "label": INK2, "lsize": 13, "cone": 0.16, "num": Color(INK, 0.05), "tag_bg": BG})
	# reticle on the open end, where the tug will come in
	var e: Vector2 = a.entry + Vector2(40, 0)
	draw_arc(e, 18, 0, TAU, 32, Color(O, 0.8), 1.0)
	for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(e + d * 12, e + d * 26, O, 1.0)


func _matrix() -> void:
	var r := Rect2(560, 696, 1296, 212)
	_zone(r, "船坞设施 // FACILITIES", "12 / 12  OK")
	var cw := (r.size.x - 3 * 8) / 4.0
	var ch := (r.size.y - 2 * 8) / 3.0
	for i in K.FAC.size():
		var cx := r.position.x + (i % 4) * (cw + 8)
		var cy := r.position.y + (i / 4) * (ch + 8)
		draw_rect(Rect2(cx, cy, cw, ch), Color(1, 1, 1, 0.012))
		draw_rect(Rect2(cx, cy, 2, ch), Color(1, 1, 1, 0.5))
		K.txt(self, Vector2(cx + 16, cy + 42), "%02d" % (i + 1), 13, INK3, "Medium", 0.0, 1)
		K.txt(self, Vector2(cx + 48, cy + 43), K.FAC[i], 18, INK, "Regular")
		K.txt(self, Vector2(cx + cw - 14, cy + 42), "OK", 13, INK2, "SemiBold", 1.0, 2)


func _footer() -> void:
	draw_line(Vector2(64, 960), Vector2(1856, 960), LINE, 1.0)
	K.txt(self, Vector2(64, 1012), ">", 18, O, "SemiBold")
	K.txt(self, Vector2(88, 1011), K.D.footer, 16, INK2)
	var x := 1856.0
	for i in range(K.SIDE_KEYS.size() - 1, -1, -1):
		var k: Array = K.SIDE_KEYS[i]
		var lw := K.width(k[0], 17, "Medium")
		var kw := K.width(k[1], 14, "SemiBold", 1) + 14
		var bw := lw + kw + 40
		var r := Rect2(x - bw, 984, bw, 42)
		K.corners(self, r, 8, Color(1, 1, 1, 0.5))
		var kr := Rect2(r.position.x + 12, r.position.y + 10, kw, 22)
		draw_rect(kr, Color(1, 1, 1, 0.12))
		K.txt(self, kr.get_center() + Vector2(0, 5), k[1], 14, INK, "SemiBold", 0.5, 1)
		K.txt(self, Vector2(kr.end.x + 12, r.position.y + 28), k[0], 17, INK, "Medium")
		x -= bw + 16
