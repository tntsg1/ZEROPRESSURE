extends Control
# A · 工业仪表 (Braun / Teenage Engineering): a warm light-grey instrument panel,
# recessed dark displays for numbers, physical keys that press in, LEDs and a
# selector knob. Everything sits on a strict 12-column grid (64 px margins).

const K = preload("res://scripts/ui_demo/demo_kit.gd")

const O := K.ORANGE

# light = the first proposal; dark1 = 炭黑 (matte charcoal); dark2 = 黑金属 (anodised)
const PAL := {
	"light": {"bg": Color(0.835, 0.822, 0.795), "face": Color(0.888, 0.876, 0.852), "face_dn": Color(0.86, 0.85, 0.825),
		"ink": Color(0.10, 0.10, 0.105), "ink2": Color(0.36, 0.35, 0.335), "ink3": Color(0.53, 0.515, 0.49),
		"screen": Color(0.085, 0.088, 0.095), "scr_ink": Color(0.90, 0.90, 0.88), "rim": Color(0.72, 0.705, 0.68),
		"shadow": Color(0.25, 0.22, 0.18, 0.28), "hi": Color(1, 1, 1, 0.75), "lo": Color(0.3, 0.27, 0.22, 0.25),
		"brush": 0.012, "knob": Color(0.95, 0.94, 0.92), "knob_cap": Color(0.9, 0.89, 0.865), "knob_tick": Color(0.6, 0.58, 0.55, 0.6),
		"cap": Color(0.10, 0.10, 0.105), "cap_ink": Color(1, 1, 1), "tab": Color(0.10, 0.10, 0.105), "rule_hi": Color(1, 1, 1, 0.5),
		"metal": false, "grain": false},
	"dark1": {"bg": Color(0.034, 0.035, 0.039), "face": Color(0.098, 0.1, 0.108), "face_dn": Color(0.078, 0.08, 0.087),
		"ink": Color(0.9, 0.9, 0.895), "ink2": Color(0.6, 0.6, 0.6), "ink3": Color(0.42, 0.42, 0.43),
		"screen": Color(0.012, 0.013, 0.015), "scr_ink": Color(0.9, 0.9, 0.89), "rim": Color(0.055, 0.056, 0.062),
		"shadow": Color(0, 0, 0, 0.7), "hi": Color(1, 1, 1, 0.07), "lo": Color(0, 0, 0, 0.5),
		"brush": 0.0, "knob": Color(0.16, 0.162, 0.172), "knob_cap": Color(0.125, 0.127, 0.135), "knob_tick": Color(1, 1, 1, 0.18),
		"cap": Color(0.19, 0.192, 0.2), "cap_ink": Color(0.92, 0.92, 0.92), "tab": Color(0.012, 0.013, 0.015), "rule_hi": Color(1, 1, 1, 0.04),
		"metal": false, "grain": true},
	"dark2": {"bg": Color(0.045, 0.047, 0.052), "face": Color(0.14, 0.145, 0.155), "face_dn": Color(0.115, 0.119, 0.128),
		"ink": Color(0.93, 0.93, 0.93), "ink2": Color(0.64, 0.65, 0.66), "ink3": Color(0.45, 0.46, 0.475),
		"screen": Color(0.014, 0.015, 0.018), "scr_ink": Color(0.9, 0.9, 0.89), "rim": Color(0.07, 0.072, 0.078),
		"shadow": Color(0, 0, 0, 0.75), "hi": Color(1, 1, 1, 0.2), "lo": Color(0, 0, 0, 0.55),
		"brush": 0.0, "knob": Color(0.3, 0.305, 0.32), "knob_cap": Color(0.19, 0.195, 0.205), "knob_tick": Color(0, 0, 0, 0.55),
		"cap": Color(0.25, 0.255, 0.27), "cap_ink": Color(0.95, 0.95, 0.95), "tab": Color(0.014, 0.015, 0.018), "rule_hi": Color(1, 1, 1, 0.06),
		"metal": true, "grain": false},
}

var variant := "light"
var P: Dictionary = PAL.light
var BG: Color
var FACE: Color
var INK: Color
var INK2: Color
var INK3: Color
var SCREEN: Color
var SCR_INK: Color
var sel := 0.0  # selected key, fractional while the selection slides
var t := 0.0


func set_variant(v: String) -> void:
	variant = v
	P = PAL[v]
	BG = P.bg
	FACE = P.face
	INK = P.ink
	INK2 = P.ink2
	INK3 = P.ink3
	SCREEN = P.screen
	SCR_INK = P.scr_ink
	queue_redraw()


func _init() -> void:
	set_variant("light")


func _ready() -> void:
	size = Vector2(1920, 1080)


func _raised(r: Rect2, radius: int = 10, face: Color = FACE) -> void:
	K.box(self, r, face, radius, Color(0, 0, 0, 0), 0, P.shadow, 10, Vector2(0, 4))
	_finish(r, radius)


# surface treatment shared by raised panels and keys
func _finish(r: Rect2, radius: int) -> void:
	if P.metal:
		# anodised aluminium: light falls from the top, fine horizontal brushing
		K.vgrad(self, Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, r.size.y * 0.5)), Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.0))
		var y := r.position.y + 3.0
		var k := 0
		while y < r.end.y - 3:
			var a := 0.008 + 0.012 * float((k * 7919) % 7) / 7.0
			draw_line(Vector2(r.position.x + 4, y), Vector2(r.end.x - 4, y), Color(1, 1, 1, a), 1.0)
			y += 2.0
			k += 1
		# chamfer: a bright top edge, a softer one down the left, dark lip below
		draw_line(r.position + Vector2(radius, 0.5), Vector2(r.end.x - radius, r.position.y + 0.5), P.hi, 1.0)
		draw_line(r.position + Vector2(radius * 0.6, 1.5), Vector2(r.end.x - radius * 0.6, r.position.y + 1.5), Color(1, 1, 1, 0.06), 1.0)
		draw_line(r.position + Vector2(0.5, radius), Vector2(r.position.x + 0.5, r.end.y - radius), Color(1, 1, 1, 0.07), 1.0)
		draw_line(Vector2(r.position.x + radius, r.end.y - 0.5), r.end - Vector2(radius, 0.5), P.lo, 1.0)
		return
	if P.grain:
		# matte: a whisper of top light, nothing shiny
		K.vgrad(self, Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, minf(60, r.size.y * 0.4))), Color(1, 1, 1, 0.018), Color(1, 1, 1, 0.0))
	draw_line(r.position + Vector2(radius, 1), Vector2(r.end.x - radius, r.position.y + 1), P.hi, 1.5)
	draw_line(Vector2(r.position.x + radius, r.end.y - 1), r.end - Vector2(radius, 1), P.lo, 1.0)


func _screen(r: Rect2) -> void:
	# a recessed window: dark glass, inner shadow along the top
	K.box(self, r.grow(3), P.rim, 9)
	K.box(self, r, SCREEN, 7)
	K.vgrad(self, Rect2(r.position + Vector2(6, 2), Vector2(r.size.x - 12, 18)), Color(0, 0, 0, 0.5), Color(0, 0, 0, 0))
	# faint glass sheen (fainter on the dark panels, where it reads as glare)
	var sheen := 0.016 if variant == "light" else 0.007
	draw_polygon(PackedVector2Array([r.position + Vector2(r.size.x * 0.55, 0), r.position + Vector2(r.size.x * 0.75, 0), r.position + Vector2(r.size.x * 0.45, r.size.y), r.position + Vector2(r.size.x * 0.25, r.size.y)]),
		PackedColorArray([Color(1, 1, 1, sheen), Color(1, 1, 1, sheen), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))
	if variant != "light":
		# recessed: the lower lip of the cut-out catches a little light
		draw_line(Vector2(r.position.x + 8, r.end.y + 2.5), Vector2(r.end.x - 8, r.end.y + 2.5), Color(1, 1, 1, 0.07 if P.metal else 0.045), 1.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	# very fine vertical brushing on the faceplate
	if P.brush > 0.0:
		for x in range(0, 1920, 3):
			draw_line(Vector2(x, 0), Vector2(x, 1080), Color(1, 1, 1, P.brush + P.brush * float((x * 7919) % 5) / 5.0), 1.0)
	elif P.metal:
		K.vgrad(self, Rect2(0, 0, 1920, 1080), Color(1, 1, 1, 0.012), Color(0, 0, 0, 0.0))
	_header()
	_next()
	_berth()
	_keys()
	_footer()


func _header() -> void:
	K.txt(self, Vector2(64, 66), "ZERO PRESSURE  ·  DOCK TERMINAL  ·  MODEL 123", 13, INK3, "Medium", 0.0, 2)
	K.txt(self, Vector2(62, 124), K.D.title, 46, INK, "SemiBold")
	K.led(self, Vector2(70, 154), 5, true, O, INK3)
	K.txt(self, Vector2(88, 160), K.D.online, 17, INK, "Medium")
	K.txt(self, Vector2(136, 160), K.D.station, 17, INK2, "Regular", 0.0, 1)
	# selector knob: points at the selected door
	var kc := Vector2(880, 108)
	for i in 4:
		var a := deg_to_rad(-150.0 + i * 40.0)
		var p := kc + Vector2.from_angle(a) * 64
		draw_line(kc + Vector2.from_angle(a) * 46, kc + Vector2.from_angle(a) * 52, INK if roundi(sel) == i else INK3, 2.0)
		K.txt(self, p + Vector2(0, 6), str(i + 1), 15, O if roundi(sel) == i else INK2, "SemiBold", 0.5)
	draw_circle(kc + Vector2(0, 5), 41, P.shadow)
	draw_circle(kc, 40, P.knob)
	for k in 36:
		var a := k * TAU / 36.0
		draw_line(kc + Vector2.from_angle(a) * 35, kc + Vector2.from_angle(a) * 40, P.knob_tick, 1.0)
	draw_circle(kc, 30, P.knob_cap)
	if variant != "light":
		# a lit rim on the top half of the cap, shade on the bottom
		draw_arc(kc, 29.5, PI * 1.1, PI * 1.9, 24, Color(1, 1, 1, 0.16 if P.metal else 0.08), 1.5)
		draw_arc(kc, 29.5, PI * 0.15, PI * 0.85, 24, Color(0, 0, 0, 0.5), 1.5)
		draw_arc(kc, 40, PI * 1.15, PI * 1.85, 24, Color(1, 1, 1, 0.12 if P.metal else 0.06), 1.0)
	var pa := deg_to_rad(-150.0 + sel * 40.0)
	draw_line(kc + Vector2.from_angle(pa) * 8, kc + Vector2.from_angle(pa) * 28, O, 4.0)
	K.txt(self, kc + Vector2(0, 72), "SELECT", 11, INK3, "Medium", 0.5, 2)
	# funds display
	var fr := Rect2(1064, 46, 392, 112)
	_screen(fr)
	K.txt(self, fr.position + Vector2(18, 28), "资金", 14, Color(SCR_INK, 0.55))
	K.txt(self, fr.position + Vector2(56, 28), "FUNDS", 11, Color(SCR_INK, 0.35), "Medium", 0.0, 2)
	K.txt(self, Vector2(fr.end.x - 20, fr.end.y - 22), K.D.funds, 58, SCR_INK, "Light", 1.0)
	# reputation display: 12 segments, 9 lit
	var rr := Rect2(1480, 46, 376, 112)
	_screen(rr)
	K.txt(self, rr.position + Vector2(18, 28), "声望", 14, Color(SCR_INK, 0.55))
	K.txt(self, rr.position + Vector2(56, 28), "REPUTATION", 11, Color(SCR_INK, 0.35), "Medium", 0.0, 2)
	K.txt(self, Vector2(rr.end.x - 20, rr.position.y + 66), K.D.rep, 34, SCR_INK, "Medium", 1.0)
	var sw := (rr.size.x - 36 - 11 * 4) / 12.0
	for i in 12:
		var sr := Rect2(rr.position.x + 18 + i * (sw + 4), rr.end.y - 32, sw, 10)
		draw_rect(sr, O if i < K.D.rep_have else Color(1, 1, 1, 0.09))
	K.txt(self, Vector2(rr.end.x - 20, rr.end.y - 6), K.D.rep_left, 12, Color(SCR_INK, 0.5), "Regular", 1.0)
	draw_line(Vector2(64, 196), Vector2(1856, 196), Color(INK, 0.18), 1.0)
	draw_line(Vector2(64, 197), Vector2(1856, 197), P.rule_hi, 1.0)


func _next() -> void:
	var r := Rect2(64, 216, 1792, 84)
	_raised(r, 10)
	K.box(self, Rect2(r.position, Vector2(150, r.size.y)), P.tab, 10)
	draw_rect(Rect2(r.position + Vector2(140, 0), Vector2(10, r.size.y)), P.tab)
	K.led(self, r.position + Vector2(26, 42), 5, true, O, INK3)
	K.txt(self, r.position + Vector2(48, 49), K.D.next_kicker, 20, Color(1, 1, 1), "SemiBold")
	K.txt(self, r.position + Vector2(182, 32), K.D.next_chapter, 15, INK2, "Medium", 0.0, 1)
	K.txt(self, r.position + Vector2(182, 66), K.D.next_body, 26, INK, "Medium")


func _berth() -> void:
	var r := Rect2(64, 324, 1792, 432)
	_raised(r, 12)
	K.txt(self, r.position + Vector2(28, 48), K.D.berth_title, 28, INK, "SemiBold")
	K.txt(self, r.position + Vector2(186, 47), K.D.berth_sub, 16, INK2)
	K.txt(self, Vector2(r.position.x + 1300, r.position.y + 46), "BERTH 07 · SECTION", 11, INK3, "Medium", 1.0, 2)
	var sr := Rect2(r.position + Vector2(28, 72), Vector2(1272, 334))
	_screen(sr)
	K.berth(self, Rect2(sr.position + Vector2(40, 30), Vector2(sr.size.x - 110, sr.size.y - 72)),
		{"line": SCR_INK, "dim": Color(SCR_INK, 0.45), "faint": Color(SCR_INK, 0.06), "label": Color(SCR_INK, 0.8), "lsize": 14, "cone": 0.22, "num": Color(SCR_INK, 0.06), "tag_bg": Color(SCREEN, 0.9)})
	# right column: tug bay + facilities
	var x := r.position.x + 1334
	K.txt(self, Vector2(x, r.position.y + 96), K.D.tug_head, 14, INK3, "Medium", 0.0, 1)
	K.led(self, Vector2(x + 6, r.position.y + 124), 5, false, O, Color(INK, 0.25))
	K.txt(self, Vector2(x + 22, r.position.y + 131), K.D.tug_body, 20, INK, "Medium")
	draw_line(Vector2(x, r.position.y + 160), Vector2(r.end.x - 28, r.position.y + 160), Color(INK, 0.15), 1.0)
	K.txt(self, Vector2(x, r.position.y + 190), "船坞设施", 14, INK3, "Medium", 0.0, 1)
	K.txt(self, Vector2(r.end.x - 28, r.position.y + 192), "12 / 12", 22, INK, "Light", 1.0)
	for i in K.FAC.size():
		var cx := x + (i % 2) * 220
		var cy := r.position.y + 228 + (i / 2) * 32
		draw_circle(Vector2(cx + 5, cy - 6), 4.5, INK)
		K.txt(self, Vector2(cx + 18, cy), K.FAC[i], 16, INK)


func _keys() -> void:
	var w := (1792.0 - 3 * 24) / 4.0
	for i in 4:
		var c: Dictionary = K.CARDS[i]
		var on := 1.0 - clampf(absf(sel - i), 0.0, 1.0)
		var r := Rect2(64 + i * (w + 24), 784 + 4 * on, w, 176)
		if on > 0.01:
			# pressed: sits 4 px lower, shadow almost gone, inner shade on the top
			# edge, an orange lip along the bottom and its lamp lit
			var sh: Color = P.shadow
			K.box(self, r, FACE.lerp(P.face_dn, on), 12, Color(0, 0, 0, 0), 0, Color(sh, sh.a * (1.0 - 0.65 * on)), 10 - int(6 * on), Vector2(0, 4 - 3 * on))
			if P.metal:
				_finish(r, 12)
			K.vgrad(self, Rect2(r.position + Vector2(10, 0), Vector2(r.size.x - 20, 12)), Color(0, 0, 0, (0.16 if variant == "light" else 0.45) * on), Color(0, 0, 0, 0.0))
			K.box(self, Rect2(r.position.x + 24, r.end.y - 8, r.size.x - 48, 4), Color(O, on), 2)
			K.led(self, Vector2(r.end.x - 26, r.position.y + 26), 5, true, Color(O, on), INK3)
		else:
			_raised(r, 12)
		K.txt(self, r.position + Vector2(24, 62), c.key, 54, INK if on < 0.5 else O, "Light")
		K.txt(self, r.position + Vector2(24, 104), c.name, 28, INK, "SemiBold")
		K.txt(self, r.position + Vector2(24, 128), c.en, 11, INK3, "Medium", 0.0, 2)
		K.txt(self, r.position + Vector2(24, 154), c.foot, 15, INK2)
		if c.meta != "":
			K.txt(self, Vector2(r.end.x - 44, r.position.y + 112), c.meta, 15, INK, "Medium", 1.0)
		K.icon(self, i, Rect2(r.end.x - 170, r.position.y + 22, 112, 64), INK, O, t)
		# something new inside: a black dot and 有新 beside the English caption
		if c.fresh:
			var fx: float = r.position.x + 24 + K.width(c.en, 11, "Medium", 2) + 18
			draw_circle(Vector2(fx + 4, r.position.y + 124), 4.5, INK)
			K.txt(self, Vector2(fx + 14, r.position.y + 129), "有新", 13, INK)


func _footer() -> void:
	K.txt(self, Vector2(64, 1030), K.D.footer, 15, INK2)
	var x := 1856.0
	for i in range(K.SIDE_KEYS.size() - 1, -1, -1):
		var k: Array = K.SIDE_KEYS[i]
		var lw := K.width(k[0], 17, "Medium")
		var bw := lw + 82
		var r := Rect2(x - bw, 1000, bw, 46)
		_raised(r, 8)
		K.txt(self, r.position + Vector2(18, 30), k[0], 17, INK, "Medium")
		var kr := Rect2(r.end.x - 52, r.position.y + 10, 38, 26)
		if variant != "light":
			K.box(self, Rect2(kr.position + Vector2(0, 2), kr.size), Color(0, 0, 0, 0.7), 5)
		K.box(self, kr, P.cap, 5)
		if variant != "light":
			draw_line(kr.position + Vector2(5, 0.5), Vector2(kr.end.x - 5, kr.position.y + 0.5), Color(1, 1, 1, 0.22), 1.0)
		K.txt(self, kr.get_center() + Vector2(0, 6), k[1], 14, P.cap_ink, "SemiBold", 0.5)
		x -= bw + 16
