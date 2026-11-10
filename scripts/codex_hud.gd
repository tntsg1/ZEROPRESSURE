class_name CodexHud
extends CanvasLayer
# The card for something met for the first time (scripts/codex.gd): under the
# contract panel (under the task list in training), the thing's own drawing on
# the left, three sentences on the right — what it is, why it is dangerous,
# what to do. Never pauses; I opens the book on it, a click on the card too,
# the cross (or Backspace) puts it away. The mouse on the card holds it.

const W := 520.0
const ART_W := 118.0
const TXT_W := 362.0
const FS := 14
const LINE_H := 19.0

var game: Game
var c: Control
var font: Font
var font_b: Font
var k := 0.0                  # slide in / out
var shown := ""               # the entry being drawn (stays while sliding out)
var page = null               # the book, while open
var rect := Rect2()
var brief_rect := Rect2()     # the contract card's "new on this ship" block
var card_button: Button
var close_button: Button


func _ready() -> void:
	layer = 23
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
	c = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_draw_card)
	add_child(c)
	card_button = Button.new()
	card_button.flat = true
	card_button.tooltip_text = "打开图鉴" if Txt.zh else "OPEN CODEX"
	card_button.pressed.connect(func():
		if game.codex.card != "": open_book(game.codex.card))
	c.add_child(card_button)
	close_button = Button.new()
	close_button.flat = true
	close_button.tooltip_text = "关闭提示 [Backspace]" if Txt.zh else "DISMISS [Backspace]"
	close_button.pressed.connect(dismiss_card)
	c.add_child(close_button)
	for button in [card_button,close_button]:
		button.visible = false
		for state in ["normal","hover","pressed","focus"]:
			button.add_theme_stylebox_override(state,StyleBoxEmpty.new())


func _process(dt: float) -> void:
	if game == null or game.codex == null:
		return
	var cx: Codex = game.codex
	if cx.card != "":
		shown = cx.card
	# 110 号: the berth extension's card rides along with the build itself
	var on_build: bool = game.state == "build" and cx.card == Codex.BUILD_CARD
	var want := 1.0 if cx.card != "" and (game.state == "play" or on_build) and not game.menu_open and page == null else 0.0
	k = Pal.damp(k, want, 12.0 if want > 0.5 else 16.0, dt)
	if k < 0.01 and cx.card == "":
		shown = ""
	cx.held = cx.card != "" and rect.has_point(c.get_local_mouse_position()) and k > 0.5
	var interactive := cx.card != "" and k > 0.5 and game.state == "play" and not game.menu_open and page == null and not game.settings_panel.is_open
	card_button.visible = interactive
	close_button.visible = interactive
	card_button.position = rect.position
	card_button.size = rect.size
	close_button.position = _close_rect().position
	close_button.size = _close_rect().size
	c.queue_redraw()
	if card_c != null:
		card_c.queue_redraw()

func pointer_over_card() -> bool:
	return card_button != null and card_button.visible and rect.has_point(c.get_local_mouse_position())

func dismiss_card() -> void:
	game.codex.dismiss()
	# Consume the whole press, including a held mouse after the card fades.
	game.modal_release = true
	game.tools.lmb = false
	game.prev_lmb = false


func _input(ev: InputEvent) -> void:
	if game == null or game.codex == null or page != null:
		return
	if game.state != "play" or game.settings_panel.is_open:
		return
	if Keys.pressed(ev, "codex") and not game.menu_open:
		if game.contract_open:
			open_brief()
		else:
			open_book(game.codex.card if game.codex.card != "" else game.codex.last)
		get_viewport().set_input_as_handled()
		return
	if game.codex.card == "" or k < 0.5:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == KEY_BACKSPACE:
		dismiss_card()
		get_viewport().set_input_as_handled()


# the book on this ship's own mechanisms (from the contract card)
func open_brief() -> void:
	var l := Codex.ship_entries(game.ship_id)
	open_book(l[0] if not l.is_empty() else "", "", not l.is_empty())


# the book over the game, play paused while it is open
func open_book(focus: String = "", filter_ship: String = "", ship_only: bool = false) -> void:
	if page != null:
		return
	Playtest.help("图鉴" if Txt.zh else "CODEX")
	var was_paused := get_tree().paused
	get_tree().paused = true
	if game.codex.card != "" and focus == game.codex.card:
		game.codex.dismiss()
	page = CodexPage.open(game, focus, filter_ship if filter_ship != "" else game.ship_id, func():
		page = null
		get_tree().paused = was_paused and game.menu_open, ship_only)
	game.sfx.play("menu")


# on the contract card: the ship's own mechanisms, named, and where to read about them
func draw_brief(ci: CanvasItem, at: Vector2, w: float, a: float) -> void:
	var l := Codex.ship_entries(game.ship_id)
	if l.is_empty():
		brief_rect = Rect2()
		return
	var y := at.y
	UI.text(ci, font, Txt.t("cxu_brief"), Vector2(at.x, y), 13, Pal.heat(0.85 * a, 1.0))
	y += 26.0
	var shown_n := mini(l.size(), 4)
	for i in shown_n:
		ci.draw_rect(Rect2(at.x + 3, y - 9, 6, 6), Pal.heat(0.8 * a, 1.1))
		UI.text(ci, font, Codex.title(l[i]), Vector2(at.x + 20, y), 16, Pal.ink(0.9 * a))
		y += 24.0
	if l.size() > shown_n:
		UI.text(ci, font, "+%d" % (l.size() - shown_n), Vector2(at.x + 20, y), 14, Pal.ink(0.5 * a))
		y += 22.0
	UI.text(ci, font, Txt.t("cxu_brief_more") % Keys.label("codex"), Vector2(at.x, y + 4), 13, Pal.ink(0.5 * a))
	brief_rect = Rect2(at - Vector2(8, 22), Vector2(w, y + 14.0 - at.y + 22.0))
	if brief_rect.has_point(ci.get_local_mouse_position()):
		ci.draw_rect(brief_rect, Pal.ink(0.2 * a), false, 1.0)


# 110 号 (user 2026-10-29, Q4 A): the card stands on the right under the earnings, always, so it
# never covers the contract panel, the asset board or the hint cards on the left
const TOP := 150.0
const EDGE := 22.0


func _anchor() -> Vector2:
	# 128 号 第 7 段 (user 2026-11-09): a guide card up on the right (the first ship's coach,
	# the warehouse guide) keeps its place; the first-meeting card waits below it
	var top := TOP
	var x := c.size.x - EDGE - W
	if game != null:
		for o in [game.coach, game.store_guide]:
			if o == null or not is_instance_valid(o) or not ("card" in o):
				continue
			var pc = o.card
			if pc == null or not is_instance_valid(pc) or not pc.is_visible_in_tree():
				continue
			var r: Rect2 = pc.get_global_rect()
			if r.end.x > x and r.position.x < x + W:
				top = maxf(top, r.end.y + 12.0)
	return Vector2(x, top)


func _close_rect() -> Rect2:
	return Rect2(rect.end.x - 42.0, rect.position.y + 2.0, 38.0, 38.0)


# ---------------------------------------------------------------- drawing

static func wrap_lines(f: Font, text: String, width: float, size_px: int) -> int:
	var tl := TextParagraph.new()
	tl.add_string(text, f, size_px)
	tl.width = width
	tl.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	return tl.get_line_count()


# the card's paragraphs are shaped once (the card is redrawn every frame while it is up)
var _paras := {}


func _para(text: String, pos: Vector2, width: float, size_px: int, col: Color, f: Font = null, on: CanvasItem = null) -> float:
	var fo := f if f != null else font
	var pk := "%s|%d|%d|%d" % [text, int(width), size_px, fo.get_instance_id()]
	var tl: TextParagraph = _paras.get(pk)
	if tl == null:
		if _paras.size() > 64:
			_paras.clear()
		tl = TextParagraph.new()
		tl.add_string(text, fo, size_px)
		tl.width = width
		tl.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		_paras[pk] = tl
	var y := pos.y
	for i in tl.get_line_count():
		tl.draw_line((on if on != null else card_c).get_canvas_item(), Vector2(pos.x, y), i, col)
		y += LINE_H
	return y - pos.y


# the width of the "what / danger / do" labels in front of the sentences
static func label_w() -> float:
	# 2026-11-09: measured, so the owner's four-character labels ("基本介绍"…) never run into the text
	var f: Font = Fonts.get_font("Regular")
	var w := 0.0
	for part in ["a", "b", "c"]:
		w = maxf(w, f.get_string_size(Txt.t("cxu_" + part), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x)
	return maxf(44.0 if Txt.zh else 62.0, ceilf(w) + 12.0)


var _heights := {}


func card_height(id: String) -> float:
	var hk := "%s|%s" % [id, Txt.zh]
	if _heights.has(hk):
		return _heights[hk]
	_heights[hk] = _card_height(id)
	return _heights[hk]


func _card_height(id: String) -> float:
	var h := 64.0

	for part in ["a", "b", "c"]:
		h += wrap_lines(font, Codex.line(id, part), TXT_W - label_w(), FS) * LINE_H + 8.0
	return maxf(h + 30.0, 64.0 + ART_W * 0.8 + 30.0)


# ---------------------------------------------------------------- 2026-11-05: the card as a holographic file
# (user: the first-meeting card "不够酷"; 问答 C). A scan line wipes the card down onto the screen
# (0.5 s, easeInOutCubic) with the "file called up" sound; the title rises from behind its line (#005);
# its archive number and kind mark top left, fine corner brackets, a danger bar of 1–3 cells by the
# danger line, a card of 3 cells breathing orange at its edge; the time left a thin line with light
# running along it. The words are the user's, unchanged. Reduced motion: it is simply there, still.

const SCAN_S := 0.5
var card_c: Control           # the card itself, drawn in its own space and clipped to the scan
var title_rt: BenchFx.RiseText
var _scan_t := 9.0
var _for := ""


func _card_nodes() -> void:
	if card_c != null:
		return
	card_c = Control.new()
	card_c.clip_contents = true
	card_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_c.draw.connect(_draw_card_local)
	c.add_child(card_c)
	c.move_child(card_c, 0)
	title_rt = BenchFx.RiseText.new("", font_b, 19, Pal.ink(0.97))
	title_rt.position = Vector2(18, 26)
	title_rt.size = Vector2(W - 80.0, 27)
	card_c.add_child(title_rt)


func _draw_card() -> void:
	_card_nodes()
	if shown == "" or k < 0.01:
		card_c.visible = false
		if shown == "":
			_for = ""
		return
	var id := shown
	if id != _for:
		# a new card: the scan, the title's rise, the sound of the file being called up
		_for = id
		_scan_t = 0.0
		title_rt.set_text(Codex.title(id))
		if BenchFx.on():
			title_rt.start(BenchFx.now() + 0.12)
		if game != null and game.get("sfx") != null:
			game.sfx.play("codex_card", Vector2.INF, 0.8)
	_scan_t += get_process_delta_time()
	var scan := BenchFx.e_io(_scan_t / SCAN_S) if BenchFx.on() else 1.0
	var a := clampf(k, 0.0, 1.0)
	var leaving: bool = game.codex.card != id
	var slide := (1.0 - Pal.ease_out(a)) * 60.0 if leaving else 0.0
	var h := card_height(id)
	var p := _anchor() + Vector2(slide, 0.0)
	rect = Rect2(p, Vector2(W, h))
	card_c.visible = true
	card_c.position = p
	card_c.size = Vector2(W, maxf(1.0, h * scan))
	card_c.modulate.a = a
	card_c.queue_redraw()
	# the scan line at the card's lower edge while it wipes on, with its glow
	if scan < 1.0:
		var y := p.y + h * scan
		c.draw_texture_rect(UiSkin.glow_tex(), Rect2(p.x - 20.0, y - 10.0, W + 40.0, 20.0), false, Color(UiSkin.DATA, 0.35 * a))
		c.draw_rect(Rect2(p.x - 6.0, y - 1.0, W + 12.0, 2.0), Color(UiSkin.DATA, 0.95 * a))


static var prof_us := 0      # tests: microseconds spent drawing the card each frame, summed
static var prof_n := 0


# the card in two layers: what does not move (the glass, the head, the sentences, the foot) drawn once
# per card; what moves (the drawing, the danger cells and edge, the time line, the close key's light)
# every frame
var static_c: Control
var _static_for := ""
var _cells_at := Vector2.ZERO


var moving_c: Control


func _draw_card_local() -> void:
	if static_c == null:
		static_c = Control.new()
		static_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		static_c.draw.connect(_draw_static)
		card_c.add_child(static_c)
		card_c.move_child(static_c, 0)
		moving_c = Control.new()
		moving_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		moving_c.draw.connect(_draw_moving_timed)
		card_c.add_child(moving_c)
		card_c.move_child(moving_c, 1)
	var key := "%s|%s" % [shown, Txt.zh]
	if key != _static_for:
		_static_for = key
		static_c.size = Vector2(W, card_height(shown))
		static_c.queue_redraw()
	moving_c.size = Vector2(W, card_height(shown))
	moving_c.queue_redraw()


func _draw_moving_timed() -> void:
	var t0 := Time.get_ticks_usec()
	_draw_moving()
	prof_us += Time.get_ticks_usec() - t0
	prof_n += 1


func _draw_static() -> void:
	var id := shown
	if id == "":
		return
	var ci := static_c
	var e: Dictionary = CodexData.E.get(id, {})
	var h := card_height(id)
	var lv := CodexFx.level(id)
	var r := Rect2(Vector2.ZERO, Vector2(W, h))
	# the glass: dark, faint scan rows, a hairline edge, the corner brackets, the kind's colour bar
	ci.draw_rect(r, Color(0.022, 0.025, 0.03, 0.94))
	ci.draw_texture_rect(CodexFx.rows_tex(), r, true, Color(1, 1, 1, 0.018))
	ci.draw_rect(r, Pal.ink(0.2), false, 1.0)
	CodexFx.brackets(ci, r.grow(-4.0), Pal.ink(0.55) if lv < 3 else Color(UiSkin.ACCENT, 0.9), 12.0)
	var acc := Pal.tint(Pal.AIR, 1.0, 1.1) if e.get("cat", "") != "mech" else Pal.heat(1.0, 1.05)
	ci.draw_rect(Rect2(Vector2.ZERO, Vector2(3, h)), acc)
	# the head: kind mark, archive number, kind · first met (the title rises in its own layer)
	_cat_mark(ci, str(e.get("cat", "device")), Vector2(24, 17), acc)
	var code := CodexFx.code(id)
	UI.text(ci, font_b, code, Vector2(36, 22), 12, Color(UiSkin.DATA, 0.95))
	var cw: float = font_b.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	ci.draw_line(Vector2(42 + cw, 13), Vector2(42 + cw, 23), Pal.ink(0.3), 1.0)
	var cat_l: String = Txt.t("cxu_cat_" + str(e.get("cat", "device"))) + " · " + Txt.t("cxu_first")
	UI.text(ci, font, cat_l, Vector2(50 + cw, 22), 12, Pal.tint(acc, 0.85, 1.0))
	title_rt.set_text(Codex.title(id))
	# the three sentences (the danger cells under "danger" are drawn with what moves)
	var x := 18.0 + ART_W + 8.0
	var y := 74.0
	for part in ["a", "b", "c"]:
		var lab: String = Txt.t("cxu_" + part)
		var col: Color = Pal.heat(0.9, 1.1) if part == "b" else (Pal.tint(Pal.FLUID, 0.9, 1.0) if part == "c" else Pal.ink(0.55))
		UI.text(ci, font, lab, Vector2(x, y + 1), 12, col)
		if part == "b":
			_cells_at = Vector2(x, y + 7.0)
		y += _para(Codex.line(id, part), Vector2(x + label_w(), y - 14.0), TXT_W - label_w(), FS, Pal.ink(0.9), null, ci) + 8.0
	UI.text(ci, font, Txt.t("cxu_more") % Keys.label("codex"), Vector2(18, h - 12), 12, Pal.ink(0.45))


func _draw_moving() -> void:
	var id := shown
	if id == "":
		return
	var ci := moving_c
	var h := card_height(id)
	var t := CodexFx.now()
	var lv := CodexFx.level(id)
	# three cells of danger: the edge breathes orange
	if lv >= 3:
		var br := 0.5 + 0.5 * sin(t * 2.2) if t > 0.0 else 0.6
		ci.draw_rect(Rect2(Vector2.ONE, Vector2(W, h) - Vector2(2, 2)), Color(UiSkin.ACCENT, 0.25 + 0.45 * br), false, 1.5)
		ci.draw_texture_rect(UiSkin.glow_tex(), Rect2(-30, -30, W + 60, 60), false, Color(UiSkin.ACCENT, 0.05 * br))
	# the close cross, lit under the pointer
	var cr := Rect2(W - 42.0, 2.0, 38.0, 38.0)
	var hot := cr.has_point(ci.get_local_mouse_position())
	ci.draw_line(cr.position + Vector2(7, 7), cr.end - Vector2(7, 7), Pal.ink(0.8 if hot else 0.4), 1.5, true)
	ci.draw_line(Vector2(cr.end.x - 7, cr.position.y + 7), Vector2(cr.position.x + 7, cr.end.y - 7), Pal.ink(0.8 if hot else 0.4), 1.5, true)
	# the drawing, alive on its instrument screen
	draw_art(ci, id, Rect2(Vector2(18, 66), Vector2(ART_W - 10.0, ART_W * 0.8)), font, 1.0, t)
	# the danger level, 1–3 cells
	for i in 3:
		var on := i < lv
		var pulse := 1.0 if lv < 3 or t <= 0.0 else 0.7 + 0.3 * sin(t * 2.2)
		ci.draw_rect(Rect2(_cells_at + Vector2(i * 11.0, 0), Vector2(9.0, 3.0)), Pal.heat(0.95 * pulse, 1.2) if on else Pal.ink(0.14))
	# the time left: a line with light running along it
	if game.codex.card == id:
		var left := 1.0 - clampf(game.codex.card_t / Codex.SHOW_T, 0.0, 1.0)
		var lw := (W - 3.0) * left
		ci.draw_rect(Rect2(3, h - 2, lw, 1.5), Color(UiSkin.DATA, 0.3))
		if t > 0.0 and lw > 30.0:
			var hx := 3.0 + CodexFx.fract(t * 0.6) * lw
			ci.draw_texture_rect(UiSkin.glow_tex(), Rect2(hx - 22.0, h - 9.0, 44.0, 14.0), false, Color(UiSkin.DATA, 0.4))
			ci.draw_rect(Rect2(maxf(3.0, hx - 18.0), h - 2.5, minf(18.0, hx - 3.0), 2.0), Color(UiSkin.DATA, 0.95))


# a small mark for the kind: structure a hex, device a box, mechanism a gear, system rings
func _cat_mark(ci: CanvasItem, cat: String, at: Vector2, col: Color) -> void:
	match cat:
		"struct":
			var hx := PackedVector2Array()
			for i in 7:
				hx.append(at + Vector2.from_angle(i * TAU / 6.0) * 5.5)
			ci.draw_polyline(hx, col, 1.2, true)
		"mech":
			ci.draw_arc(at, 4.0, 0, TAU, 16, col, 1.2, true)
			for i in 6:
				var d := Vector2.from_angle(i * TAU / 6.0)
				ci.draw_line(at + d * 4.0, at + d * 6.5, col, 1.6)
		"sys":
			ci.draw_arc(at, 2.5, 0, TAU, 12, col, 1.2, true)
			ci.draw_arc(at, 5.5, 0, TAU, 20, Color(col, 0.6), 1.0, true)
		_:
			ci.draw_rect(Rect2(at - Vector2(5, 4), Vector2(10, 8)), col, false, 1.2)
			ci.draw_line(at + Vector2(-5, -1), at + Vector2(5, -1), Color(col, 0.6), 1.0)


# an entry's own drawing in a box, on its instrument screen and alive (scripts/codex_fx.gd): the line
# art the game draws the thing with (a slow breath, a scan running down it, its marks pulsing), or its
# sign with its own loop; t < 0: now (0 with reduced motion: still)
static func draw_art(ci: CanvasItem, id: String, box: Rect2, f: Font, a: float = 1.0, t: float = -1.0) -> void:
	if t < 0.0:
		t = CodexFx.now()
	var e: Dictionary = CodexData.E.get(id, {})
	var art := Codex.draw_art(id)
	var sz: Array = e.get("size", [])
	var aspect: float = float(sz[0]) / float(sz[1]) if sz.size() == 2 else 1.4
	var w := box.size.x
	var h := w / aspect
	if h > box.size.y:
		h = box.size.y
		w = h * aspect
	var r := Rect2(box.position + (box.size - Vector2(w, h)) * 0.5, Vector2(w, h))
	var g := str(e.get("glyph", e.get("cat", ""))) if art == "" else ""
	# the heat sign's grid is drawn by its shader, bent by the heat (still: the plain grid)
	var hot := g in ["heat", "fire"] and t > 0.0 and CodexFx.shimmer_free(ci)
	# the instrument screen fills the whole box (a long thin machine sits in its middle); the heat
	# signs bend its grid in their shader
	var scr := box
	CodexFx.screen(ci, scr, a, not hot)
	if art == "":
		CodexFx.glyph(ci, g, r, a, t)
		if hot:
			CodexFx.shimmer(ci, scr)
		return
	var bob := sin(t * 1.4) * 0.8
	ci.draw_set_transform(r.position + Vector2(0, bob), 0.0, Vector2.ONE)
	Art.draw(ci, art, r.size, null, f)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	CodexFx.scan(ci, scr, a, t)
	for m in e.get("marks", []):
		var at := r.position + Vector2(float(m[0]) * r.size.x, float(m[1]) * r.size.y + bob)
		var pr := 2.5 + (0.8 * sin(t * 3.0) if t > 0.0 else 0.0)
		ci.draw_arc(at, pr + 3.0, 0, TAU, 16, Pal.heat(0.35 * a, 1.2), 1.0, true)
		ci.draw_circle(at, pr, Pal.heat(a, 1.2))
		ci.draw_line(at, Vector2(at.x, r.end.y + 10.0), Pal.heat(0.6 * a, 1.0), 1.0, true)


# kept for anything that drew a sign directly: now the living one
static func _glyph(ci: CanvasItem, g: String, r: Rect2, a: float) -> void:
	CodexFx.screen(ci, r, a)
	CodexFx.glyph(ci, g, r, a, CodexFx.now())
