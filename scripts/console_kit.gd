extends RefCounted
# 132 号 控制台规范 (design/132_控制台规范与情境引导_草图稿_2026-11-07.md §一; user 2026-11-07 "全按推荐"):
#   字号 — body and keys 20 at least, readings 24–32, page notes 16 at the smallest;
#   one orange main key a page, on Enter; the rest under "更多 ›";
#   the side consoles 730 px at most (the machine stays in view), the site desks a 520 px card on the
#   machine's far side;
#   a line under the title, always there: "现在用得上：……" (orange) or "现在不用管：……" (grey) — whether
#   to do anything now and why, the same thing the main key does;
#   only Enter and Esc on a page.
# The pieces every one of those pages shares.

const W_SIDE := 730.0
const W_CARD := 520.0
const BODY := 20
const SMALL := 16
const READ := 28
const ORANGE_INK := Color(0.08, 0.06, 0.05)


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func head_of(use: bool) -> String:
	return NowLine.head(use)


# the line itself, for pages built of controls
class NowLine extends Control:
	var use := false
	var text := ""
	var _h := 50.0

	func _init() -> void:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 50)
		resized.connect(_fit)

	func set_now(u: bool, t: String) -> void:
		if u == use and t == text:
			return
		use = u
		text = t
		_fit()
		queue_redraw()

	static func head(u: bool) -> String:
		return ("当前需要关注：" if u else "目前无需处理：") if Txt.zh else ("WORTH DOING NOW: " if u else "NOTHING NEEDED: ")

	func full() -> String:
		return head(use) + text

	func _fit() -> void:
		var f := Fonts.get_font("Medium")
		var wd := maxf(80.0, size.x - 32.0)
		var hh := f.get_multiline_string_size(full(), HORIZONTAL_ALIGNMENT_LEFT, wd, 20).y
		var want := maxf(50.0, hh + 20.0)
		if absf(want - _h) > 0.5:
			_h = want
			custom_minimum_size.y = want

	func _draw() -> void:
		paint(self, Rect2(Vector2.ZERO, size), use, text, 20)

	# the line on any canvas (returns its height)
	static func paint(ci: CanvasItem, r: Rect2, u: bool, t: String, px: int) -> float:
		var fb := Fonts.get_font("SemiBold")
		var f := Fonts.get_font("Medium")
		var hd := head(u)
		var hw := fb.get_string_size(hd, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var tw := r.size.x - 32.0 - hw
		var lines := f.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, tw, px).y
		var h := maxf(r.size.y, lines + 20.0)
		var rr := Rect2(r.position, Vector2(r.size.x, h))
		var acc := UiSkin.ACCENT
		if u:
			ci.draw_rect(rr, Color(acc, 0.15))
			ci.draw_rect(rr, Color(acc, 0.9), false, 1.5)
		else:
			ci.draw_rect(rr, Color(1, 1, 1, 0.045))
			ci.draw_rect(rr, Pal.ink(0.22), false, 1.0)
		var base := rr.position.y + 10.0 + px * 0.95
		ci.draw_string(fb, Vector2(rr.position.x + 16.0, base), hd, HORIZONTAL_ALIGNMENT_LEFT, -1, px, acc.lightened(0.1) if u else Pal.ink(0.55))
		ci.draw_multiline_string(f, Vector2(rr.position.x + 16.0 + hw, base), t, HORIZONTAL_ALIGNMENT_LEFT, tw, px, -1, Pal.ink(0.96 if u else 0.62))
		return h


# the line drawn straight onto a hand-drawn page (returns its height)
static func draw_now(ci: CanvasItem, r: Rect2, use: bool, text: String, px: int = BODY) -> float:
	return NowLine.paint(ci, r, use, text, px)


# the page's one main key: solid orange with dark words (as the processing console's, sketch 2)
static func orange(b: Button, px: int = 22) -> void:
	b.add_theme_font_size_override("font_size", px)
	b.add_theme_font_override("font", Fonts.get_font("SemiBold"))
	for st in ["normal", "hover", "pressed", "focus"]:
		var kb := UiSkin.solid(UiSkin.ACCENT.lightened(0.1) if st == "hover" else (UiSkin.ACCENT.darkened(0.12) if st == "pressed" else UiSkin.ACCENT), 8, 12.0)
		b.add_theme_stylebox_override(st, kb)
	b.add_theme_stylebox_override("disabled", UiSkin.solid(Color(1, 1, 1, 0.05), 8, 12.0))
	for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(fc, ORANGE_INK)
	b.add_theme_color_override("font_disabled_color", Pal.ink(0.45))
	b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, 58.0)
	BenchFx.primary(b)


# back to a plain key (a key that was the main one a moment ago)
static func plain(b: Button, px: int = BODY) -> void:
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.remove_theme_stylebox_override(st)
	for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.remove_theme_color_override(fc)
	b.add_theme_font_size_override("font_size", px)
	BenchFx.primary(b, false)


# the page's title on the left, its code small and grey in the corner (no codes as titles)
static func header(title: String, code: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var t := Label.new()
	t.text = title
	t.add_theme_font_override("font", Fonts.get_font("SemiBold"))
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", Pal.ink(0.97))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	var c := Label.new()
	c.text = code
	c.add_theme_font_size_override("font_size", 14)
	c.add_theme_color_override("font_color", Pal.ink(0.35))
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(c)
	return row


static func text(value: String, px: int = BODY, ink: float = 0.92) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", Pal.ink(ink))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func key(value: String, cb: Callable, px: int = BODY) -> Button:
	var b := Button.new()
	b.text = value
	b.custom_minimum_size.y = 48
	b.add_theme_font_size_override("font_size", px)
	b.pressed.connect(cb)
	return b


# a solid dark side pane at most W_SIDE wide (the right of the screen)
static func solid(host: Control, width: float = W_SIDE) -> VBoxContainer:
	var column := OpsSkin.pane(host, Pal.tint(Pal.AIR, 1.0, 1.2), width)
	var pane := host.get_node_or_null("Pane") as PanelContainer
	if pane != null:
		var box := UiSkin.solid(Color(0.043, 0.048, 0.057, 1.0), 14, 22.0)
		box.set_border_width_all(1)
		box.border_color = Color(1, 1, 1, 0.08)
		box.shadow_color = Color(0, 0, 0, 0.55)
		box.shadow_size = 24
		pane.add_theme_stylebox_override("panel", box)
	column.add_theme_constant_override("separation", 14)
	return column


# a site desk as a card W_CARD wide, as tall as it needs, on the far side of the machine it runs:
# the machine on the right half of the screen puts the card on the left
static func card_side(host: Control, machine_screen_x: float) -> void:
	var pane := host.get_node_or_null("Pane") as PanelContainer
	if pane == null:
		return
	var vw := host.get_viewport_rect().size.x
	var left := machine_screen_x > vw * 0.5
	if left:
		pane.set_anchors_preset(Control.PRESET_TOP_LEFT)
		pane.offset_left = 24.0
		pane.offset_right = 24.0 + W_CARD
	else:
		pane.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		pane.offset_left = -W_CARD - 24.0
		pane.offset_right = -24.0
	pane.offset_top = 132.0
	pane.set_meta("card_left", left)
	host.set_meta("card_left", left)


# each frame: the card as tall as its content (the pane's scroll would hold it flat otherwise)
static func card_fit(host: Control) -> void:
	var pane := host.get_node_or_null("Pane") as PanelContainer
	if pane == null:
		return
	var outer := pane.get_child(0) as VBoxContainer
	if outer == null or outer.get_child_count() < 2:
		return
	var scroll := outer.get_child(0) as ScrollContainer
	var col := scroll.get_child(0) as Control if scroll != null and scroll.get_child_count() > 0 else null
	if col == null:
		return
	var vh := host.get_viewport_rect().size.y
	var want := minf(col.get_combined_minimum_size().y, vh - pane.offset_top - 60.0 - 120.0)
	scroll.custom_minimum_size.y = want
	pane.offset_bottom = pane.offset_top + want + 120.0
	pane.size.y = 0.0


# where a node of the world is on the screen (the side a card goes)
static func screen_x(game, at: Vector2) -> float:
	if game == null or not is_instance_valid(game) or not at.is_finite():
		return 0.0
	return (game.get_viewport().get_canvas_transform() * at).x
