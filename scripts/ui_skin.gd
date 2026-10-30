class_name UiSkin
# The pages' look (50 号; player picked "minimal future" from the samples): a dark diagonal
# ground with one warm glow drifting across it and a soft light that follows the pointer; glass
# cards — a faint white fill, a hairline edge, round corners — that lift on hover; thin type with
# wide spacing; one warm accent for what you press, a data blue for figures. Pages fade their
# cards in one after another and roll their figures up from nought; with reduced motion in the
# settings everything simply appears.

const BG0 := Color("14181d")
const BG1 := Color("0c0e11")
const BG2 := Color("151a1f")
const ACCENT := Color("ff8a50")
const DATA := Color("6fd3ff")
const INK := Color(0.93, 0.95, 0.96)
const DIM := Color(0.6, 0.65, 0.69)
const RADIUS := 16


static func motion() -> bool:
	return Txt.anim_level() >= 1


static func glass(fill := 0.04, edge := 0.08, radius := RADIUS, pad := 12.0, edge_col := Color(1, 1, 1)) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(1, 1, 1, fill)
	b.border_color = Color(edge_col.r, edge_col.g, edge_col.b, edge)
	b.set_border_width_all(1)
	b.set_corner_radius_all(radius)
	b.anti_aliasing = true
	for side in ["left", "right", "top", "bottom"]:
		b.set("content_margin_" + side, pad)
	return b


static func solid(col: Color, radius := 12, pad := 12.0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = col
	b.set_corner_radius_all(radius)
	b.anti_aliasing = true
	for side in ["left", "right", "top", "bottom"]:
		b.set("content_margin_" + side, pad)
	return b


static func lifted(fill := 0.07, radius := RADIUS, pad := 12.0) -> StyleBoxFlat:
	var b := glass(fill, 0.4, radius, pad, ACCENT)
	b.shadow_color = Color(0, 0, 0, 0.5)
	b.shadow_size = 18
	b.shadow_offset = Vector2(0, 8)
	return b


static func clear() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


# the theme every page of the new look starts from
static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = Fonts.get_font("Regular")
	t.default_font_size = 16
	t.set_color("font_color", "Label", INK)
	for cls in ["Button", "OptionButton", "CheckButton"]:
		t.set_stylebox("normal", cls, glass(0.04, 0.08, 12, 10.0))
		t.set_stylebox("hover", cls, glass(0.08, 0.3, 12, 10.0, ACCENT))
		t.set_stylebox("pressed", cls, glass(0.12, 0.5, 12, 10.0, ACCENT))
		t.set_stylebox("disabled", cls, glass(0.02, 0.04, 12, 10.0))
		t.set_stylebox("focus", cls, clear())
		t.set_color("font_color", cls, INK)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_pressed_color", cls, Color.WHITE)
		t.set_color("font_disabled_color", cls, Color(1, 1, 1, 0.48))   # 91 号: still reads, still shut
	for cls in ["LineEdit", "SpinBox"]:
		t.set_stylebox("normal", "LineEdit", glass(0.05, 0.12, 10, 8.0))
		t.set_stylebox("focus", "LineEdit", glass(0.07, 0.5, 10, 8.0, ACCENT))
	t.set_color("font_color", "LineEdit", INK)
	t.set_stylebox("panel", "PanelContainer", glass())
	t.set_stylebox("panel", "PopupMenu", solid(Color("1a1f25"), 10, 8.0))
	t.set_stylebox("panel", "AcceptDialog", solid(Color("1a1f25"), 16, 18.0))
	t.set_stylebox("slider", "HSlider", solid(Color(1, 1, 1, 0.1), 3, 2.0))
	t.set_stylebox("grabber_area", "HSlider", solid(ACCENT, 3, 2.0))
	t.set_stylebox("grabber_area_highlight", "HSlider", solid(ACCENT.lightened(0.2), 3, 2.0))
	t.set_stylebox("scroll", "VScrollBar", clear())
	t.set_stylebox("grabber", "VScrollBar", solid(Color(1, 1, 1, 0.12), 4, 0.0))
	t.set_stylebox("grabber_highlight", "VScrollBar", solid(Color(1, 1, 1, 0.25), 4, 0.0))
	t.set_stylebox("separator", "HSeparator", solid(Color(1, 1, 1, 0.08), 0, 0.0))
	return t


static func accent_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", solid(ACCENT, 12, 12.0))
	b.add_theme_stylebox_override("hover", solid(ACCENT.lightened(0.12), 12, 12.0))
	b.add_theme_stylebox_override("pressed", solid(ACCENT.darkened(0.1), 12, 12.0))
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color("1a0d05"))


# a page tab: plain text, the chosen one underlined in the accent
static func tab_button(b: Button, on: bool) -> void:
	var under := StyleBoxFlat.new()
	under.bg_color = Color(0, 0, 0, 0)
	under.border_color = ACCENT
	under.border_width_bottom = 2 if on else 0
	for side in ["left", "right"]:
		under.set("content_margin_" + side, 14.0)
	under.content_margin_top = 8.0
	under.content_margin_bottom = 8.0
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, under)
	b.add_theme_color_override("font_color", Color.WHITE if on else DIM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)


static func label(s: String, px := 16, col := INK) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# cards fade in and rise one after another
static func enter(nodes: Array, step := 0.06) -> void:
	if not motion():
		return
	var i := 0
	for n in nodes:
		if not n is Control:
			continue
		var c: Control = n
		c.modulate.a = 0.0
		var tw := c.create_tween()
		tw.tween_interval(step * i)
		tw.tween_property(c, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		i += 1


# a figure rolled up from nought: fmt is given the value
static func count(l: Label, to: float, fmt: Callable, secs := 0.9) -> void:
	if not motion():
		l.text = fmt.call(to)
		return
	l.text = fmt.call(0.0)
	var tw := l.create_tween()
	tw.tween_method(func(v: float): l.text = fmt.call(v), 0.0, to, secs).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# a card that lifts on hover (the shadow deepens, the edge warms) and gives on press
static func hover_lift(b: Button, pad := 12.0) -> void:
	b.add_theme_stylebox_override("normal", glass(0.04, 0.08, RADIUS, pad))
	b.add_theme_stylebox_override("hover", lifted(0.07, RADIUS, pad))
	b.add_theme_stylebox_override("pressed", lifted(0.1, RADIUS, pad))
	b.add_theme_stylebox_override("focus", clear())
	b.mouse_entered.connect(func():
		b.pivot_offset = b.size * 0.5
		if motion():
			b.create_tween().tween_property(b, "scale", Vector2(1.025, 1.025), 0.15).set_trans(Tween.TRANS_CUBIC))
	b.mouse_exited.connect(func():
		if motion():
			b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_CUBIC)
		else:
			b.scale = Vector2.ONE)


# the ground behind a page: the diagonal dark gradient, one warm glow drifting, and a soft light
# where the pointer is
class Ground extends Control:
	var t := 0.0
	var glow: Texture2D
	var mouse := Vector2(-9999, -9999)

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 256
		gt.height = 256
		glow = gt

	func _process(dt: float) -> void:
		t += dt
		mouse = get_local_mouse_position()
		queue_redraw()

	func _draw() -> void:
		var s := size
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]), PackedColorArray([BG0, BG1.lerp(BG0, 0.3), BG2, BG1]))
		var k := 0.5 + 0.5 * sin(t * TAU / 18.0) if UiSkin.motion() else 0.5
		var gc := Vector2(s.x * (0.92 - 0.12 * k), s.y * (-0.05 + 0.15 * k))
		var gr := s.x * 0.42
		draw_texture_rect(glow, Rect2(gc - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.16))
		if Rect2(Vector2.ZERO, s).has_point(mouse):
			draw_texture_rect(glow, Rect2(mouse - Vector2(300, 300), Vector2(600, 600)), false, Color(1, 1, 1, 0.05))


# a goods picture as a control
class Goods extends Control:
	var item := ""
	var grade := 0

	func _init(it := "", gr := 0) -> void:
		item = it
		grade = gr
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		GoodsArt.draw(self, Rect2(Vector2.ZERO, size), item, grade)


# ---------------------------------------------------------------- for hand-drawn pages (the terminal)
static var _glow: Texture2D
static var _boxes := {}
static var field := false     # 91 号: on site the boxes are the drone feed's overlay (scripts/hud.gd sets it while it draws)


static func glow_tex() -> Texture2D:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 256
		gt.height = 256
		_glow = gt
	return _glow


# the ground, drawn straight onto a canvas item: gradient, drifting warm glow, the pointer's light
static func draw_ground(ci: CanvasItem, s: Vector2, t: float, mouse: Vector2) -> void:
	ci.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]), PackedColorArray([BG0, BG1.lerp(BG0, 0.3), BG2, BG1]))
	var k := 0.5 + 0.5 * sin(t * TAU / 18.0) if motion() else 0.5
	var gc := Vector2(s.x * (0.92 - 0.12 * k), s.y * (-0.05 + 0.15 * k))
	var gr := s.x * 0.42
	ci.draw_texture_rect(glow_tex(), Rect2(gc - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.16))
	if Rect2(Vector2.ZERO, s).has_point(mouse):
		ci.draw_texture_rect(glow_tex(), Rect2(mouse - Vector2(300, 300), Vector2(600, 600)), false, Color(1, 1, 1, 0.05))


# a rounded box for hand-drawn panels, cached by kind and quantised strength (drawn every frame)
static func box(kind: String, a: float, k := 0.0) -> StyleBoxFlat:
	var key := "%s/%d/%d/%s" % [kind, int(round(clampf(a, 0.0, 1.0) * 20.0)), int(round(clampf(k, 0.0, 1.0) * 10.0)), "f" if field else ""]
	if _boxes.has(key):
		return _boxes[key]
	var aa: float = round(clampf(a, 0.0, 1.0) * 20.0) / 20.0
	var kk: float = round(clampf(k, 0.0, 1.0) * 10.0) / 10.0
	var b := StyleBoxFlat.new()
	b.anti_aliasing = true
	b.set_border_width_all(1)
	match kind:
		"raised":
			b.bg_color = Color(1, 1, 1, (0.04 + 0.05 * kk) * aa)
			b.border_color = Color(1, 1, 1, 0.08 * aa).lerp(Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.45 * aa), kk)
			b.set_corner_radius_all(14)
			if kk > 0.0:
				b.shadow_color = Color(0, 0, 0, 0.45 * aa * kk)
				b.shadow_size = int(16 * kk)
				b.shadow_offset = Vector2(0, 6 * kk)
		"sunk":
			b.bg_color = Color(0, 0, 0, 0.22 * aa).lerp(Color(1, 1, 1, 0.06 * aa), kk)
			b.border_color = Color(1, 1, 1, 0.05 * aa)
			b.set_corner_radius_all(12)
		"screen":
			b.bg_color = Color(0, 0, 0, 0.22 * aa)
			b.border_color = Color(1, 1, 1, 0.04 * aa)
			b.set_corner_radius_all(10)
		# 54 号: the on-site panel — dark enough over the scene to read, rounded, warm when chosen
		"panel":
			b.bg_color = Color(BG0.r, BG0.g, BG0.b, 0.86 * aa)
			b.border_color = Color(1, 1, 1, 0.09 * aa).lerp(Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.55 * aa), kk)
			b.set_corner_radius_all(14)
		# 54 号: small labels and readouts over the scene
		"tag":
			b.bg_color = Color(BG0.r, BG0.g, BG0.b, 0.88 * aa)
			b.border_color = Color(1, 1, 1, 0.07 * aa)
			b.set_corner_radius_all(7)
		"ring":
			b.draw_center = false
			b.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.7 * aa)
			b.set_border_width_all(2)
			b.set_corner_radius_all(16)
		"accent":
			b.bg_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, aa).lightened(0.12 * kk)
			b.border_color = Color(0, 0, 0, 0)
			b.set_corner_radius_all(12)
			if kk > 0.0:
				b.shadow_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35 * aa * kk)
				b.shadow_size = int(18 * kk)
	# 91 号 遥控 Q6 C: the feed's overlay — a thin dark backing to read on, square cut, no glass
	if field and kind in ["raised", "panel"]:
		# user: “像相机 HUD 一样” — no card behind it: a faint shade so text reads, the chosen
		# one underlined in the accent
		b.bg_color = Color(0.0, 0.0, 0.0, 0.12 * aa)
		b.set_border_width_all(0)
		b.border_width_bottom = 2 if kk > 0.05 else 0
		b.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.9 * aa * kk)
		b.set_corner_radius_all(0)
		b.shadow_size = 0
	elif field and kind in ["sunk", "screen"]:
		b.bg_color = Color(1, 1, 1, 0.06 * aa)
		b.set_border_width_all(0)
		b.set_corner_radius_all(0)
	elif field and kind == "tag":
		b.bg_color = Color(0.0, 0.0, 0.0, 0.4 * aa)
		b.set_border_width_all(0)
		b.set_corner_radius_all(0)
		b.shadow_size = 0
	elif field and kind in ["ring", "accent"]:
		b.set_corner_radius_all(1)
	_boxes[key] = b
	return b
