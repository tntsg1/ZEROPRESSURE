class_name Charcoal
extends RefCounted
const KeyFx = preload("res://scripts/ui_kit/key_fx.gd")
# A-暗1 炭黑 (user 2026-11-10, picked from four proposals): the UI as a dark instrument —
# near-black ground, matte charcoal panels with real thickness and a soft shadow, number
# windows one step blacker and recessed, LEDs, a selector knob, numbered keys that press in
# with an orange lip, dark keycaps. Orange is the one accent and only marks what matters
# (the selection, a lit lamp, a warning). Static drawing calls for any CanvasItem, plus button
# styles for real Buttons; style boxes are cached so a frame allocates nothing.

const ACCENT := Color(1.0, 0.353, 0.122)
const BG := Color(0.034, 0.035, 0.039)
const FACE := Color(0.098, 0.1, 0.108)
const FACE_HI := Color(0.112, 0.114, 0.123)
const FACE_DN := Color(0.078, 0.08, 0.087)
const SCREEN := Color(0.012, 0.013, 0.015)
const RIM := Color(0.055, 0.056, 0.062)
const INK := Color(0.9, 0.9, 0.895)
const INK2 := Color(0.6, 0.6, 0.6)
const INK3 := Color(0.42, 0.42, 0.43)
const SHADOW := Color(0, 0, 0, 0.7)
const CAP := Color(0.19, 0.192, 0.2)
const RADIUS := 12

static var _boxes := {}


static func ink(a: float = 1.0, level: int = 1) -> Color:
	var c: Color = [INK, INK, INK2, INK3][clampi(level, 0, 3)]
	return Color(c, c.a * a)


static func accent(a: float = 1.0) -> Color:
	return Color(ACCENT, a)


# a rounded box, cached by its look; alpha is applied through modulate-free colours
static func _box(key: String, bg: Color, radius: int, shadow: Color, ssize: int, soff: Vector2) -> StyleBoxFlat:
	var k := "%s|%s|%d|%s|%d|%s" % [key, bg, radius, shadow, ssize, soff]
	if _boxes.has(k):
		return _boxes[k]
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 6
	sb.anti_aliasing = true
	if ssize > 0:
		sb.shadow_color = shadow
		sb.shadow_size = ssize
		sb.shadow_offset = soff
	if _boxes.size() > 512:
		_boxes.clear()
	_boxes[k] = sb
	return sb


static func _q(a: float) -> float:
	# alpha quantised so the cache stays small while things fade
	return snappedf(clampf(a, 0.0, 1.0), 0.05)


static func vgrad(ci: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


# ---------------------------------------------------------------- ground and surfaces

static func ground(ci: CanvasItem, s: Vector2, a: float = 1.0) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, s), Color(BG, a))
	# the room's light falls from above, very faintly
	vgrad(ci, Rect2(0, 0, s.x, s.y * 0.45), Color(1, 1, 1, 0.012 * a), Color(1, 1, 1, 0.0))


# a raised panel: matte face, a soft shadow under it, a faint lit top edge and a dark lip.
# press 0..1 sinks it (the shadow shrinks); returns the face rect as drawn
static func panel(ci: CanvasItem, r: Rect2, a: float = 1.0, press: float = 0.0, face: Color = FACE, radius: int = RADIUS) -> Rect2:
	if a <= 0.0:
		return r
	var qa := _q(a)
	r.position.y += 4.0 * press
	var sh := Color(SHADOW, SHADOW.a * qa * (1.0 - 0.65 * press))
	var f := face.lerp(FACE_DN, press)
	ci.draw_style_box(_box("p", Color(f, qa), radius, sh, 10 - int(6 * press), Vector2(0, 4.0 - 3.0 * press)), r)
	vgrad(ci, Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, minf(60.0, r.size.y * 0.4))), Color(1, 1, 1, 0.018 * a), Color(1, 1, 1, 0.0))
	ci.draw_line(r.position + Vector2(radius, 1), Vector2(r.end.x - radius, r.position.y + 1), Color(1, 1, 1, 0.07 * a * (1.0 - press)), 1.5)
	ci.draw_line(Vector2(r.position.x + radius, r.end.y - 1), r.end - Vector2(radius, 1), Color(0, 0, 0, 0.5 * a), 1.0)
	if press > 0.0:
		# pressed in: the top edge falls into shade
		vgrad(ci, Rect2(r.position + Vector2(radius * 0.8, 0), Vector2(r.size.x - radius * 1.6, 12)), Color(0, 0, 0, 0.45 * press * a), Color(0, 0, 0, 0.0))
	return r


# a key drawn by a page (a tab, a numbered key, a card that is clicked): the panel, answering the
# pointer (scripts/ui_kit/key_fx.gd, 用户选定 A+B) — it rises under the pointer or the keyboard (a lit
# face counts as that), sinks while held, springs back, and a brushed light follows the pointer
# across it. Returns the face rect as drawn: draw the key's words relative to it and they travel too.
# Plates (sheets, side boards, windows) stay Charcoal.panel: they do not move.
static func key(ci: CanvasItem, r: Rect2, a: float = 1.0, press: float = 0.0, face: Color = FACE, radius: int = RADIUS) -> Rect2:
	if a <= 0.0:
		return r
	var hint := face.r >= FACE_HI.r - 0.0015
	var st: Dictionary = KeyFx.track(ci, r, hint)
	if st.is_empty():
		return panel(ci, r, a, press, face, radius)
	var mot: bool = KeyFx.motion()
	var hov: float = float(st.hov) if mot else 0.0
	var prs: float = clampf(float(st.prs), -0.2, 1.2)
	var rr := r
	rr.position.y -= KeyFx.LIFT * hov
	if hov > 0.01:
		# the longer shadow of a key lifted off the plate
		ci.draw_style_box(_box("klift", Color(0, 0, 0, 0), radius, Color(0, 0, 0, 0.32 * _q(a) * clampf(hov, 0.0, 1.0)), 4 + int(6.0 * clampf(hov, 0.0, 1.0)), Vector2(0, 3.0 + 4.0 * hov)), rr)
	var fr := panel(ci, rr, a, clampf(maxf(press, prs * 0.75), 0.0, 1.0), face, radius)
	if mot and hov > 0.01 and a > 0.4:
		KeyFx._light(ci, fr, float(st.mx), clampf(hov, 0.0, 1.0) * a)
	return fr


# a recessed window one step blacker than the panel, for numbers and live drawings
static func display(ci: CanvasItem, r: Rect2, a: float = 1.0, radius: int = 7) -> void:
	if a <= 0.0:
		return
	var qa := _q(a)
	ci.draw_style_box(_box("rim", Color(RIM, qa), radius + 2, Color(), 0, Vector2.ZERO), r.grow(3))
	ci.draw_style_box(_box("scr", Color(SCREEN, qa), radius, Color(), 0, Vector2.ZERO), r)
	vgrad(ci, Rect2(r.position + Vector2(6, 2), Vector2(r.size.x - 12, minf(18.0, r.size.y * 0.3))), Color(0, 0, 0, 0.5 * a), Color(0, 0, 0, 0))
	# a faint diagonal sheen across the glass
	var w := r.size.x
	ci.draw_polygon(PackedVector2Array([r.position + Vector2(w * 0.55, 0), r.position + Vector2(w * 0.72, 0), r.position + Vector2(w * 0.5, r.size.y), r.position + Vector2(w * 0.33, r.size.y)]),
		PackedColorArray([Color(1, 1, 1, 0.007 * a), Color(1, 1, 1, 0.007 * a), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))
	# the cut-out's lower lip catches a little light
	ci.draw_line(Vector2(r.position.x + 8, r.end.y + 2.5), Vector2(r.end.x - 8, r.end.y + 2.5), Color(1, 1, 1, 0.045 * a), 1.0)


# ---------------------------------------------------------------- parts

# an indicator: lit (with a soft halo and a glint) or a dark lens
static func led(ci: CanvasItem, p: Vector2, on: bool, a: float = 1.0, r: float = 5.0, col: Color = ACCENT) -> void:
	if a <= 0.0:
		return
	if on:
		for i in 4:
			ci.draw_circle(p, r * (3.0 - i * 0.5), Color(col, (0.04 + i * 0.03) * a))
		ci.draw_circle(p, r, Color(col, a))
		ci.draw_circle(p - Vector2(r, r) * 0.3, r * 0.35, Color(1, 1, 1, 0.55 * a))
	else:
		# a dark lens: a shade darker than the panel with a faint rim
		ci.draw_circle(p, r + 1.0, Color(1, 1, 1, 0.05 * a))
		ci.draw_circle(p, r, Color(0.02, 0.021, 0.024, a))


# the selector knob: n positions on an arc, the pointer at sel_f (may be fractional while it
# turns); sc scales it (the radii, not the type, so the numbers stay crisp)
static func knob(ci: CanvasItem, font: Font, c: Vector2, sel_f: float, n: int, a: float = 1.0, label: String = "SELECT", sc: float = 1.0) -> void:
	if a <= 0.0 or n <= 0:
		return
	var span := 120.0 if n <= 4 else 200.0
	var step := span / maxf(1.0, n - 1)
	var a0 := -90.0 - span * 0.5
	var on := roundi(sel_f)
	for i in n:
		var ang := deg_to_rad(a0 + i * step)
		var d := Vector2.from_angle(ang)
		ci.draw_line(c + d * 46 * sc, c + d * 52 * sc, Color(INK if on == i else INK3, a), 2.0)
		var s := str(i + 1)
		var tw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		ci.draw_string(font, c + d * 64 * sc + Vector2(-tw * 0.5, 5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(ACCENT if on == i else INK2, a))
	ci.draw_circle(c + Vector2(0, 5 * sc), 41 * sc, Color(SHADOW, SHADOW.a * a))
	ci.draw_circle(c, 40 * sc, Color(0.16, 0.162, 0.172, a))
	for k in 36:
		var ka := k * TAU / 36.0
		ci.draw_line(c + Vector2.from_angle(ka) * 35 * sc, c + Vector2.from_angle(ka) * 40 * sc, Color(1, 1, 1, 0.18 * a), 1.0)
	ci.draw_circle(c, 30 * sc, Color(0.125, 0.127, 0.135, a))
	ci.draw_arc(c, 29.5 * sc, PI * 1.1, PI * 1.9, 24, Color(1, 1, 1, 0.08 * a), 1.5, true)
	ci.draw_arc(c, 29.5 * sc, PI * 0.15, PI * 0.85, 24, Color(0, 0, 0, 0.5 * a), 1.5, true)
	ci.draw_arc(c, 40 * sc, PI * 1.15, PI * 1.85, 24, Color(1, 1, 1, 0.06 * a), 1.0, true)
	var pa := Vector2.from_angle(deg_to_rad(a0 + sel_f * step))
	ci.draw_line(c + pa * 8 * sc, c + pa * 28 * sc, Color(ACCENT, a), 4.0 * maxf(0.75, sc), true)
	if label != "":
		var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		ci.draw_string(font, c + Vector2(-lw * 0.5, 72 * sc), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(INK3, a))


# a flat rounded slab of one colour (a black tab, a label strip)
static func slab(ci: CanvasItem, r: Rect2, col: Color, radius: int = RADIUS) -> void:
	ci.draw_style_box(_box("slab", Color(col, snappedf(col.a, 0.05)), radius, Color(), 0, Vector2.ZERO), r)


# how far a panel still has to fall as it settles into place (raw 0..1 → px, ≤0 = above)
static func settle(raw: float, dist: float = 22.0) -> float:
	return -(1.0 - Pal.back(clampf(raw, 0.0, 1.0), 1.4)) * dist


# a small keycap with its key's name (F3, ESC, 1…)
static func keycap(ci: CanvasItem, font: Font, r: Rect2, key: String, a: float = 1.0, down: float = 0.0) -> void:
	if a <= 0.0:
		return
	var qa := _q(a)
	r.position.y += 1.5 * down
	ci.draw_style_box(_box("cs", Color(0, 0, 0, 0.7 * qa), 5, Color(), 0, Vector2.ZERO), Rect2(r.position + Vector2(0, 2.0 - 1.5 * down), r.size))
	ci.draw_style_box(_box("cap", Color(CAP.lerp(FACE_DN, down), qa), 5, Color(), 0, Vector2.ZERO), r)
	ci.draw_line(r.position + Vector2(5, 0.5), Vector2(r.end.x - 5, r.position.y + 0.5), Color(1, 1, 1, 0.22 * a * (1.0 - down)), 1.0)
	var fs := 14 if r.size.y >= 24.0 else 12
	var tw := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(font, Vector2(r.get_center().x - tw * 0.5, r.get_center().y + fs * 0.36), key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.92, 0.92, 0.92, a))


# the selection's orange lip, slid along the bottom of whichever key is chosen
static func lip(ci: CanvasItem, r: Rect2, a: float = 1.0) -> void:
	if a <= 0.0:
		return
	ci.draw_style_box(_box("lip", Color(ACCENT, _q(a)), 2, Color(), 0, Vector2.ZERO), r)


# a section's head: the title, a quieter line beside it, an engraved caption on the right
static func section(ci: CanvasItem, font_s: Font, font: Font, p: Vector2, title: String, sub: String, a: float = 1.0, right_x: float = -1.0, caption: String = "") -> void:
	ci.draw_string(font_s, p, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, ink(a))
	if sub != "":
		var tw := font_s.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		ci.draw_string(font, p + Vector2(tw + 26, -1), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink(a, 2))
	if caption != "" and right_x > 0.0:
		var cw := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		ci.draw_string(font, Vector2(right_x - cw, p.y - 2), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink(a, 3))


# an engraved rule under a header: a dark groove with a faint light edge below it
static func groove(ci: CanvasItem, x0: float, x1: float, y: float, a: float = 1.0) -> void:
	ci.draw_line(Vector2(x0, y), Vector2(x1, y), Color(0, 0, 0, 0.55 * a), 1.0)
	ci.draw_line(Vector2(x0, y + 1), Vector2(x1, y + 1), Color(1, 1, 1, 0.04 * a), 1.0)


# segments of a level gauge: have of n lit
static func segments(ci: CanvasItem, r: Rect2, have: float, n: int, a: float = 1.0) -> void:
	n = maxi(1, n)
	var gap := 4.0 if n <= 16 else 2.0
	var sw := (r.size.x - gap * (n - 1)) / n
	for i in n:
		var lit := clampf(have - i, 0.0, 1.0)
		var sr := Rect2(r.position.x + i * (sw + gap), r.position.y, sw, r.size.y)
		ci.draw_rect(sr, Color(1, 1, 1, 0.09 * a))
		if lit > 0.0:
			ci.draw_rect(Rect2(sr.position, Vector2(sw * lit, sr.size.y)), Color(ACCENT, a))


# ---------------------------------------------------------------- real buttons

# a Button as a dark key: raised, sinks when held, the key's name on a keycap at its right
static func style_button(b: Button, key: String = "") -> void:
	var pad_r := 18.0 + (56.0 if key != "" else 0.0)
	var mk := func(face: Color, sh: float, soff: float, edge: float) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = face
		sb.set_corner_radius_all(8)
		sb.anti_aliasing = true
		sb.shadow_color = Color(0, 0, 0, sh)
		sb.shadow_size = 8
		sb.shadow_offset = Vector2(0, soff)
		sb.border_width_top = 1
		sb.border_color = Color(1, 1, 1, edge)
		sb.content_margin_left = 18.0
		sb.content_margin_right = pad_r
		sb.content_margin_top = 8.0
		sb.content_margin_bottom = 8.0
		return sb
	b.add_theme_stylebox_override("normal", mk.call(FACE, 0.7, 4.0, 0.07))
	b.add_theme_stylebox_override("hover", mk.call(FACE_HI, 0.7, 4.0, 0.1))
	b.add_theme_stylebox_override("pressed", mk.call(FACE_DN, 0.35, 1.0, 0.0))
	b.add_theme_stylebox_override("hover_pressed", mk.call(FACE_DN, 0.35, 1.0, 0.0))
	b.add_theme_stylebox_override("disabled", mk.call(Color(FACE, 0.6), 0.4, 3.0, 0.03))
	var fo := StyleBoxFlat.new()
	fo.draw_center = false
	fo.set_corner_radius_all(10)
	fo.set_border_width_all(2)
	fo.border_color = ACCENT
	fo.expand_margin_left = 3
	fo.expand_margin_right = 3
	fo.expand_margin_top = 3
	fo.expand_margin_bottom = 3
	b.add_theme_stylebox_override("focus", fo)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", Color(INK3, 0.8))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# 用户选定 A+B: the key answers the pointer (scripts/ui_kit/key_fx.gd)
	KeyFx.attach(b)
	if key != "":
		b.set_meta("charcoal_key", key)
		if not b.draw.is_connected(_button_cap.bind(b)):
			b.draw.connect(_button_cap.bind(b))


static func _button_cap(b: Button) -> void:
	var key := str(b.get_meta("charcoal_key", ""))
	if key == "":
		return
	var down := 1.0 if b.button_pressed or (b.is_hovered() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) else 0.0
	var f: Font = Fonts.get_font("SemiBold")
	var kw := maxf(38.0, f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 16.0)
	var r := Rect2(b.size.x - kw - 12.0, b.size.y * 0.5 - 13.0, kw, 26.0)
	keycap(b, f, r, key, 0.45 if b.disabled or b.get_meta("locked", false) else 1.0, down)


# "交易行 · 买入 / 出售 [F8]" → ["交易行 · 买入 / 出售", "F8"]
static func split_key(text: String) -> Array:
	var i := text.rfind("[")
	if i > 0 and text.ends_with("]"):
		return [text.substr(0, i).strip_edges(), text.substr(i + 1, text.length() - i - 2)]
	return [text, ""]


# ---------------------------------------------------------------- side consoles (港区侧栏, 2026-11-10)

# the side console's body: one matte charcoal slab with real thickness — a firm shadow under it, a
# faint lit top edge, nothing tinted, nothing see-through
static func side_box(pad: float = 20.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = FACE
	sb.set_corner_radius_all(RADIUS + 2)
	sb.corner_detail = 6
	sb.anti_aliasing = true
	sb.shadow_color = Color(0, 0, 0, 0.72)
	sb.shadow_size = 16
	sb.shadow_offset = Vector2(0, 6)
	sb.border_width_top = 1
	sb.border_color = Color(1, 1, 1, 0.075)
	sb.content_margin_left = pad + 2.0
	sb.content_margin_right = pad + 2.0
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb


# a recessed black window as a StyleBox (for Labels and containers that hold figures)
static func well_box(pad: float = 12.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = SCREEN
	sb.set_corner_radius_all(7)
	sb.anti_aliasing = true
	sb.border_width_top = 2
	sb.border_color = Color(0, 0, 0, 0.6)
	sb.expand_margin_left = 0
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.8
	sb.content_margin_bottom = pad * 0.8
	return sb


# "按 [Esc] 关闭面板" / "CLOSE [Esc]" / "带我去 [Enter]" on a dark key: the words on the left, the key's
# name on a keycap at the right. The Button's text is left as it was (tests and the back stack read it);
# only its drawing changes. Returns false when the text names no key.
static func key_text(b: Button) -> bool:
	var t := b.text
	var i := t.rfind("[")
	var j := t.rfind("]")
	if i < 0 or j < i:
		return false
	b.set_meta("charcoal_words", true)
	if not b.draw.is_connected(_key_text_draw.bind(b)):
		b.draw.connect(_key_text_draw.bind(b))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color(0, 0, 0, 0))
	return true


static func split_words(t: String) -> Array:
	var i := t.rfind("[")
	var j := t.rfind("]")
	if i < 0 or j < i:
		return [t, ""]
	var key := t.substr(i + 1, j - i - 1)
	var words := (t.substr(0, i) + t.substr(j + 1)).strip_edges()
	for lead in ["按 ", "按", "Press ", "PRESS "]:
		if words.begins_with(lead):
			words = words.substr(lead.length()).strip_edges()
	return [words, key]


static func _key_text_draw(b: Button) -> void:
	var sp := split_words(b.text)
	var down := 1.0 if b.button_pressed or (b.is_hovered() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) else 0.0
	var a := 0.55 if b.disabled else 1.0
	var fk: Font = Fonts.get_font("SemiBold")
	var kw := maxf(40.0, fk.get_string_size(str(sp[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 18.0)
	var kr := Rect2(b.size.x - kw - 12.0, b.size.y * 0.5 - 13.0 + 1.5 * down, kw, 26.0)
	keycap(b, fk, kr, str(sp[1]), a, down)
	var f: Font = b.get_theme_font("font")
	var px := b.get_theme_font_size("font_size")
	var room := kr.position.x - 18.0 - 14.0
	var s := str(sp[0])
	var tw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var x := 18.0 if b.alignment == HORIZONTAL_ALIGNMENT_LEFT else maxf(18.0, 18.0 + (room - tw) * 0.5)
	var y := b.size.y * 0.5 + px * 0.36 + 1.5 * down
	var col := INK if not b.disabled else Color(INK3, 0.9)
	if b.is_hovered() and not b.disabled:
		col = Color(1, 1, 1)
	b.draw_string(f, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, room, px, col)


# a status as a lamp and a short word: lit (orange = needs you, white = fine) or a dark lens
static func status(ci: CanvasItem, font: Font, p: Vector2, word: String, state: String, a: float = 1.0, px: int = 15) -> float:
	var lit := state != "idle"
	var col := ACCENT if state in ["warn", "danger"] else Color(0.92, 0.93, 0.9)
	led(ci, p + Vector2(5, -px * 0.32), lit, a, 4.0, col)
	ci.draw_string(font, p + Vector2(16, 0), word, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(INK if state != "idle" else INK2, a))
	return 16.0 + font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x


# ---------------------------------------------------------------- choices and cards (船市, 2026-11-10)

# a choice among several (a filter, an order): a dark key with a lamp at its left; the chosen one
# sits pressed in, its lamp lit and the orange lip along its foot. on: is it the chosen one now
# (read at every draw, so flipping it needs only queue_redraw)
static func style_choice(b: Button, on: Callable) -> void:
	style_button(b)
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb: StyleBoxFlat = (b.get_theme_stylebox(st) as StyleBoxFlat).duplicate()
		sb.content_margin_left = 34.0
		sb.content_margin_right = 16.0
		b.add_theme_stylebox_override(st, sb)
	b.set_meta("charcoal_on", on)
	if not b.draw.is_connected(_choice_draw.bind(b)):
		b.draw.connect(_choice_draw.bind(b))


static func _choice_draw(b: Button) -> void:
	var on: Callable = b.get_meta("charcoal_on", Callable())
	var lit := on.is_valid() and bool(on.call())
	led(b, Vector2(18.0, b.size.y * 0.5), lit, 0.55 if b.disabled else 1.0, 4.0)
	if lit:
		# pressed in: the face one step darker, the lip along the foot
		b.draw_rect(Rect2(Vector2(2, 2), b.size - Vector2(4, 4)), Color(0, 0, 0, 0.18))
		lip(b, Rect2(10.0, b.size.y - 4.0, b.size.x - 20.0, 3.0))


# a whole card as one raised key: matte face, firm shadow; lighter under the pointer, sunk when held
static func card_boxes(pad: float = 14.0) -> Dictionary:
	var mk := func(face: Color, sh: float, ssize: int, soff: float, edge: float) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = face
		sb.set_corner_radius_all(RADIUS)
		sb.corner_detail = 6
		sb.anti_aliasing = true
		sb.shadow_color = Color(0, 0, 0, sh)
		sb.shadow_size = ssize
		sb.shadow_offset = Vector2(0, soff)
		sb.border_width_top = 1
		sb.border_color = Color(1, 1, 1, edge)
		for side in ["left", "right", "top", "bottom"]:
			sb.set("content_margin_" + side, pad)
		return sb
	return {"normal": mk.call(FACE, 0.7, 12, 5.0, 0.07), "hover": mk.call(FACE_HI, 0.75, 14, 6.0, 0.11),
		"pressed": mk.call(FACE_DN, 0.4, 6, 2.0, 0.0), "hover_pressed": mk.call(FACE_DN, 0.4, 6, 2.0, 0.0),
		"disabled": mk.call(Color(FACE, 0.55), 0.35, 8, 3.0, 0.03), "focus": StyleBoxEmpty.new()}


static func style_card(b: Button, pad: float = 14.0) -> void:
	var bx := card_boxes(pad)
	for k in bx:
		b.add_theme_stylebox_override(k, bx[k])
	KeyFx.attach(b)


# a small lamp-and-word tag (a showcase's method, a held quote): a Control of its own
class LedTag extends Control:
	var text := ""
	var px := 13
	var col := ACCENT
	var lit := true

	func _init(t: String = "", c: Color = ACCENT, size_px: int = 13) -> void:
		text = t
		col = c
		px = size_px
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size.y = px + 8

	func set_text(t: String) -> void:
		if t != text:
			text = t
			update_minimum_size()
			queue_redraw()

	func _get_minimum_size() -> Vector2:
		var f: Font = Fonts.get_font("Medium")
		return Vector2(18.0 + f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x, px + 8)

	func _draw() -> void:
		var f: Font = Fonts.get_font("Medium")
		var cy := size.y * 0.5
		Charcoal.led(self, Vector2(6.0, cy), lit, 1.0, 3.5, col)
		draw_string(f, Vector2(16.0, cy + px * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col if lit else Charcoal.INK2)


# ---------------------------------------------------------------- tidy line breaks (2026-11-10)

const _NO_LEAD := "。，、；：？！）」』】》〉…—．,.;:?!)%"
static var _fitw := {}


# the width to wrap `text` at so its last line is not a lone scrap: at least 4 characters of Chinese
# (or two English words), and no punctuation starting a line. It narrows the width a step at a time,
# 15 % at most, and gives the width back unchanged when nothing helps. Draw and measure with the
# width it returns (draw_multiline_string / get_multiline_string_size, the same size)
static func fit_width(font: Font, text: String, width: float, px: int) -> float:
	var key := "%s|%d|%d|%d" % [text, int(width), px, font.get_rid().get_id()]
	if _fitw.has(key):
		return _fitw[key]
	var out := width
	var w := width
	while w >= width * 0.85:
		if _lines_ok(font, text, w, px):
			out = w
			break
		w -= maxf(4.0, width * 0.015)
	if _fitw.size() > 2048:
		_fitw.clear()
	_fitw[key] = out
	return out


static func _lines_ok(font: Font, text: String, w: float, px: int) -> bool:
	var tp := TextParagraph.new()
	tp.width = w
	tp.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
	tp.add_string(text, font, px)
	var n := tp.get_line_count()
	if n <= 1:
		return true
	for i in n:
		var rg := tp.get_line_range(i)
		var ln := text.substr(rg.x, rg.y - rg.x).strip_edges()
		if i > 0 and ln != "" and _NO_LEAD.contains(ln[0]):
			return false
		if i == n - 1:
			var cjk := false
			for ch in ln:
				if ch.unicode_at(0) >= 0x2E80:
					cjk = true
					break
			if cjk:
				var chars := ln.replace(" ", "").length()
				if chars < 4:
					return false
			elif ln.split(" ", false).size() < 2:
				return false
	return true


# one line held to a width: the type steps down a pixel at a time (to min_px), then the end is cut with
# "…". Returns [text, px] to draw with (the single-line partner of fit_width)
static func fit_line(font: Font, text: String, width: float, px: int, min_px: int = 10) -> Array:
	var p := px
	while p > min_px and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, p).x > width:
		p -= 1
	var t := text
	if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, p).x > width:
		while t.length() > 1 and font.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, p).x > width:
			t = t.substr(0, t.length() - 1)
		t = t.strip_edges() + "…"
	return [t, p]


# ---------------------------------------------------------------- frosted plates (现场 HUD, 2026-11-11)

# a frosted HUD plate (user 2026-11-11: "稍微有一点透明或者之类的质感"): see-through charcoal, smooth (no
# grain), a soft light from the top, a thin lit lip along its top, a dark line along its foot; `lit` warms
# the lip (the slot in hand). The scene shows through dimmed, the words on it keep their contrast
static func frost(ci: CanvasItem, r: Rect2, a: float = 1.0, radius: int = 10, lit: float = 0.0, fill: float = 0.62) -> void:
	if a <= 0.0:
		return
	var qa := _q(a)
	# smooth (user 2026-11-11: the grain looked like sandpaper): an even see-through face, a soft light
	# from the top fading down, nothing speckled
	ci.draw_style_box(_box("frost", Color(0.035, 0.036, 0.04, fill * qa), radius, Color(0, 0, 0, 0.35 * qa), 8, Vector2(0, 3)), r)
	vgrad(ci, Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, minf(40.0, r.size.y * 0.5))), Color(1, 1, 1, 0.045 * a), Color(1, 1, 1, 0.0))
	var lip := Color(1, 1, 1, 0.16 * a).lerp(Color(ACCENT, 0.9 * a), clampf(lit, 0.0, 1.0))
	ci.draw_line(r.position + Vector2(radius, 0.5), Vector2(r.end.x - radius, r.position.y + 0.5), lip, 1.0 + lit)
	ci.draw_line(Vector2(r.position.x + radius, r.end.y - 0.5), r.end - Vector2(radius, 0.5), Color(0, 0, 0, 0.4 * a), 1.0)
