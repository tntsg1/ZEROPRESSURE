extends Control
# D · 极简编辑排版: no cards, no boxes. A magazine page: a headline for the berth
# state, a huge funds figure, the next step as a pull quote, the cross-section as
# a quiet illustration, and the four doors as a table of contents split by
# hairlines. Hierarchy comes from size, weight and space alone.

const K = preload("res://scripts/ui_demo/demo_kit.gd")

const BG := Color(0.04, 0.041, 0.045)
const INK := Color(0.94, 0.94, 0.935)
const INK2 := Color(0.6, 0.6, 0.6)
const INK3 := Color(0.38, 0.38, 0.39)
const HAIR := Color(1, 1, 1, 0.14)
const O := K.ORANGE
const L := 96.0
const R := 1824.0

var sel := 0.0
var t := 0.0


func _ready() -> void:
	size = Vector2(1920, 1080)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	_masthead()
	_hero()
	_quote()
	_figure()
	_contents()
	_footer()


func _masthead() -> void:
	var x := L
	x += K.txt(self, Vector2(x, 78), K.D.title, 18, INK, "SemiBold") + 18
	x += K.txt(self, Vector2(x, 78), K.D.station, 15, INK2, "Regular", 0.0, 2) + 22
	draw_circle(Vector2(x + 4, 72), 3.5, O)
	K.txt(self, Vector2(x + 14, 78), K.D.online, 15, INK2)
	var rx := R
	for i in range(K.SIDE_KEYS.size() - 1, -1, -1):
		var k: Array = K.SIDE_KEYS[i]
		var kw := K.width(k[1], 13, "SemiBold", 1)
		K.txt(self, Vector2(rx, 78), k[1], 13, INK3, "SemiBold", 1.0, 1)
		rx -= kw + 10
		rx -= K.txt(self, Vector2(rx, 78), k[0], 16, INK, "Regular", 1.0) + 40
	draw_line(Vector2(L, 104), Vector2(R, 104), HAIR, 1.0)


func _hero() -> void:
	K.txt(self, Vector2(L, 148), "船坞 07", 14, INK3, "Medium", 0.0, 2)
	K.txt(self, Vector2(L - 6, 290), K.D.berth_title, 132, INK, "SemiBold")
	K.txt(self, Vector2(L, 340), K.D.berth_sub + "　·　" + K.D.tug_body, 19, INK2)
	# funds and reputation, right column
	K.txt(self, Vector2(R, 148), "资金", 14, INK3, "Medium", 1.0, 2)
	K.txt(self, Vector2(R + 4, 268), K.D.funds, 118, INK, "Light", 1.0)
	var bx := 1300.0
	K.txt(self, Vector2(bx, 336), "声望", 14, INK3, "Medium", 0.0, 2)
	K.txt(self, Vector2(bx + 52, 340), K.D.rep, 22, INK, "Medium")
	K.txt(self, Vector2(R, 340), K.D.rep_left, 14, INK2, "Regular", 1.0)
	var y := 356.0
	draw_line(Vector2(bx, y), Vector2(R, y), Color(1, 1, 1, 0.16), 2.0)
	draw_line(Vector2(bx, y), Vector2(bx + (R - bx) * K.D.rep_have / float(K.D.rep_need), y), O, 2.0)


func _quote() -> void:
	var y := 420.0
	draw_line(Vector2(L, y), Vector2(L, y + 82), O, 3.0)
	K.txt(self, Vector2(L + 28, y + 18), K.D.next_kicker + "　" + K.D.next_chapter, 15, O, "Medium", 0.0, 1)
	K.txt(self, Vector2(L + 26, y + 72), K.D.next_body, 40, INK, "Light")


func _figure() -> void:
	draw_line(Vector2(L, 548), Vector2(R, 548), HAIR, 1.0)
	K.txt(self, Vector2(L, 580), "图 1　船坞剖面", 13, INK3, "Medium", 0.0, 1)
	K.berth(self, Rect2(L + 10, 604, 1100, 196), {"line": Color(INK, 0.8), "dim": Color(INK, 0.32), "faint": Color(INK, 0.0),
		"label": INK2, "lsize": 13, "cone": 0.12, "big07": false, "grid": false, "tags": false, "tag_bg": BG})
	# facilities as an index, two columns
	var x0 := 1300.0
	K.txt(self, Vector2(x0, 580), "船坞设施", 13, INK3, "Medium", 0.0, 1)
	K.txt(self, Vector2(R, 580), "已修 12 / 12", 13, INK2, "Regular", 1.0)
	for i in K.FAC.size():
		var cx := x0 + (i % 2) * 270
		var cy := 622 + (i / 2) * 32
		K.txt(self, Vector2(cx, cy), "%02d" % (i + 1), 12, INK3, "Medium")
		K.txt(self, Vector2(cx + 30, cy + 1), K.FAC[i], 17, INK)
		K.txt(self, Vector2(cx + 250, cy + 1), "✓", 14, INK3, "Regular", 1.0)


func _contents() -> void:
	var top := 860.0
	draw_line(Vector2(L, top), Vector2(R, top), HAIR, 1.0)
	var cw := (R - L) / 4.0
	# the selected column's rule slides along the top hairline
	draw_rect(Rect2(L + sel * cw, top - 1, cw - 24, 3), O)
	for i in 4:
		var c: Dictionary = K.CARDS[i]
		var on := 1.0 - clampf(absf(sel - i), 0.0, 1.0)
		var x := L + i * cw
		if i > 0:
			draw_line(Vector2(x - 12, top + 22), Vector2(x - 12, top + 140), HAIR, 1.0)
		K.txt(self, Vector2(x, top + 70), "0" + c.key, 56, INK3.lerp(O, on), "Light")
		K.txt(self, Vector2(x + 90, top + 66), c.name, 32, INK2.lerp(INK, maxf(on, 0.55)), "SemiBold")
		var meta: String = c.meta if c.meta != "" else ""
		if meta != "":
			K.txt(self, Vector2(x + cw - 36, top + 64), meta, 16, INK2, "Regular", 1.0)
		K.txt(self, Vector2(x, top + 112), c.foot, 15, INK2)
		if c.fresh:
			K.txt(self, Vector2(x, top + 140), "有新内容", 14, INK, "Medium")
		if on > 0.5:
			K.txt(self, Vector2(x + cw - 36, top + 140), "Enter →", 14, O, "Medium", 1.0, 1)


func _footer() -> void:
	draw_line(Vector2(L, 1028), Vector2(R, 1028), HAIR, 1.0)
	K.txt(self, Vector2(L, 1056), K.D.footer, 14, INK3)
	K.txt(self, Vector2(R, 1056), "ZERO PRESSURE", 12, INK3, "Medium", 1.0, 3)
