class_name Hmi
# 2026-11-10 炭黑: the boxes come from UiSkin.box (now the dark instrument look); lamps are
# Charcoal LEDs; "fine / fitted" lamps glow white rather than green (orange stays for warnings
# and what is chosen); readouts sit in recessed black windows.
# The berth terminal's look. Was the industrial HMI (P.7, 2026-10-18); since 50 号 (player
# 2026-10-25 picked "minimal future") the same calls draw the new look: glass panels with round
# corners that warm and lift when pointed at, soft inset screens, plain titles with an accent
# tick, soft-glowing lamps, thin gauges, solid accent push buttons and underline tabs.
# All alpha-aware (a), so the self-test can bring each part up.
#
# Lamps: FLUID green = fitted / ready / fine, INK white = can be had, HEAT =
# short of money / warning / chosen.

const BG := Color(0.075, 0.08, 0.088)
const HEAD := Color(0.11, 0.115, 0.125)
const PANEL := Color(0.1, 0.105, 0.115)
const PANEL_HI := Color(0.13, 0.135, 0.15)
const PANEL_LO := Color(0.085, 0.09, 0.1)
const SCREEN := Color(0.02, 0.024, 0.028)
const PLATE := Color(0.02, 0.022, 0.026)

# the lamp test during the self-test: every lamp lit while it runs
static var lamp_test := false


static func ok_col(a: float = 1.0) -> Color:
	return Color(0.86, 0.88, 0.86, a)


static func warn_col(a: float = 1.0) -> Color:
	return Color(UiSkin.ACCENT.r, UiSkin.ACCENT.g, UiSkin.ACCENT.b, a)


static func can_col(a: float = 1.0) -> Color:
	return Pal.ink(0.9 * a, 1.25)


# how lit a panel fill asks to be (the callers pass PANEL … PANEL_HI for rest … hover)
static func _lift(fill: Color) -> float:
	return clampf((fill.get_luminance() - PANEL.get_luminance()) / maxf(0.001, PANEL_HI.get_luminance() - PANEL.get_luminance()), 0.0, 1.0)


# a glass panel; warmer edge and a shadow the more it is lit (hover)
static func raised(ci: CanvasItem, r: Rect2, a: float = 1.0, fill: Color = PANEL) -> void:
	if a <= 0.0:
		return
	ci.draw_style_box(UiSkin.box("raised", a, _lift(fill) * 0.6), r)


# set into the page (a key held down, a slot, a row)
static func sunk(ci: CanvasItem, r: Rect2, a: float = 1.0, fill: Color = PANEL_LO) -> void:
	if a <= 0.0:
		return
	ci.draw_style_box(UiSkin.box("sunk", a, _lift(fill)), r)


# a soft inset for drawings and the big numbers
static func screen(ci: CanvasItem, r: Rect2, a: float = 1.0, grid: bool = false) -> void:
	if a <= 0.0:
		return
	ci.draw_style_box(UiSkin.box("screen", a), r)
	if grid:
		var gx := r.position.x + 20.0
		while gx < r.end.x - 4.0:
			var gy := r.position.y + 20.0
			while gy < r.end.y - 4.0:
				ci.draw_circle(Vector2(gx, gy), 1.0, Color(1, 1, 1, 0.06 * a))
				gy += 40.0
			gx += 40.0


# a title: plain light type with an accent tick before it
static func plate(ci: CanvasItem, font: Font, r: Rect2, s: String, size: int, a: float = 1.0, col: Color = Color(0.95, 0.96, 1.0)) -> void:
	ci.draw_rect(Rect2(r.position.x, r.get_center().y - size * 0.45, 3, size * 0.9), Color(UiSkin.ACCENT.r, UiSkin.ACCENT.g, UiSkin.ACCENT.b, a))
	ci.draw_string(font, r.position + Vector2(14, r.size.y * 0.5 + size * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24, size, Color(col.r, col.g, col.b, col.a * a))


# a status lamp: lit with a soft glow, or an empty ring
static func lamp(ci: CanvasItem, p: Vector2, col: Color, on: bool, a: float = 1.0, r: float = 7.0) -> void:
	var lit := on or lamp_test
	Charcoal.led(ci, p, lit, a * col.a if lit else a, r * 0.72, Color(col.r, col.g, col.b))


# a thin bar gauge: how full (0..1) in col on a faint track; `to` (when above frac) after it in the accent
static func gauge(ci: CanvasItem, r: Rect2, frac: float, col: Color, a: float = 1.0, segs: int = 10, to: float = -1.0) -> void:
	var h := minf(r.size.y, 8.0)
	var tr := Rect2(r.position.x, r.get_center().y - h * 0.5, r.size.x, h)
	ci.draw_rect(tr, Color(1, 1, 1, 0.07 * a))
	if to > frac:
		ci.draw_rect(Rect2(tr.position, Vector2(tr.size.x * clampf(to, 0.0, 1.0), h)), Color(UiSkin.ACCENT.r, UiSkin.ACCENT.g, UiSkin.ACCENT.b, 0.8 * a))
	ci.draw_rect(Rect2(tr.position, Vector2(tr.size.x * clampf(frac, 0.0, 1.0), h)), Color(col.r, col.g, col.b, col.a * a))
	# the segment marks, faint
	for i in range(1, segs):
		var x := tr.position.x + tr.size.x * i / segs
		ci.draw_line(Vector2(x, tr.position.y), Vector2(x, tr.end.y), Color(0, 0, 0, 0.35 * a), 1.0)


# the push button: solid accent when it can act (lifting and glowing on hover), glass when not;
# shaken sideways when it can't act
# old / swap: the label it showed before, crossfading out as swap goes 0 → 1
static func push(ci: CanvasItem, font: Font, r: Rect2, label: String, ok: bool, hover: float, a: float, t: float, shake: float = 0.0, note: String = "", key: String = "ENTER", down: float = 0.0, old: String = "", swap: float = 1.0) -> void:
	r.position.x += sin(t * 70.0) * 9.0 * shake * shake
	r.position.y += 2.0 * down - (2.0 * hover if ok else 0.0)
	if ok:
		ci.draw_style_box(UiSkin.box("accent", a, hover), r)
	else:
		ci.draw_style_box(UiSkin.box("sunk", a, 0.3), r)
	var ink := Color(0.1, 0.05, 0.02) if ok else Pal.ink(0.5)
	var lx := r.position.x + 28.0
	# room on the right only for the key's name when there is one ("TAKE ME" was cut to "TAKE M")
	var rpad := (font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 44.0) if key != "" and ok else 20.0
	var lh := 28 if r.size.y >= 64.0 else 21
	# a label that won't fit steps down a little before it would be cut
	var room := r.end.x - (r.position.x + 28.0) - ((font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 44.0) if key != "" and ok else 20.0)
	while lh > 15 and font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, lh).x > room:
		lh -= 1
	var ly := r.position.y + r.size.y * 0.5 + lh * 0.36 - (8.0 if note != "" else 0.0)
	if old != "" and swap < 1.0:
		ci.draw_string(font, Vector2(lx, ly - 8.0 * swap), old, HORIZONTAL_ALIGNMENT_LEFT, r.end.x - lx - rpad, lh, Color(ink.r, ink.g, ink.b, a * (1.0 - swap)))
	ci.draw_string(font, Vector2(lx, ly + 8.0 * (1.0 - swap)), label, HORIZONTAL_ALIGNMENT_LEFT, r.end.x - lx - rpad, lh, Color(ink.r, ink.g, ink.b, a * swap))
	if note != "":
		ci.draw_string(font, Vector2(lx, r.position.y + r.size.y * 0.5 + 22.0), note, HORIZONTAL_ALIGNMENT_LEFT, r.end.x - lx - 20.0, 14, Color(0.15, 0.07, 0.02, a) if ok else warn_col(0.9 * a))
	if key != "" and ok:
		var kw := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		ci.draw_string(font, Vector2(r.end.x - 22.0 - kw, r.position.y + r.size.y * 0.5 + 6.0), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.1, 0.05, 0.02, 0.55 * a))


# a tab: plain type, the open one bright with the accent line under it
static func rocker(ci: CanvasItem, font: Font, r: Rect2, label: String, on: bool, hover: float, a: float, down: float = 0.0) -> void:
	r.position.y += 2.0 * down
	if hover > 0.0 and not on:
		ci.draw_style_box(UiSkin.box("sunk", a * hover, 1.0), r)
	if on:
		ci.draw_rect(Rect2(r.position.x + 14, r.end.y - 3, r.size.x - 28, 2), Color(UiSkin.ACCENT.r, UiSkin.ACCENT.g, UiSkin.ACCENT.b, a))
	ci.draw_string(font, r.position + Vector2(18, r.size.y * 0.5 + 7.0), label, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 26.0, 20, Pal.ink((0.98 if on else (0.85 if hover > 0.5 else 0.6)) * a))


# a figure on its card: the label small and dim, the figure large and light, its lamp
static func readout(ci: CanvasItem, font_s: Font, font: Font, r: Rect2, label: String, value: String, col: Color, lamp_col: Color, a: float, size: int = 32) -> void:
	Charcoal.display(ci, r, a)
	ci.draw_string(font, r.position + Vector2(16, 26), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.55 * a))
	var vw := font_s.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font_s, Vector2(r.end.x - 16 - vw, r.end.y - 14), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col.r, col.g, col.b, col.a * a))
	lamp(ci, r.position + Vector2(r.size.x - 20, 20), lamp_col, true, a, 5.0)
