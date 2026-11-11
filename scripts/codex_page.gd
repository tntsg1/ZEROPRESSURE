class_name CodexPage
extends Control
# The book (scripts/codex.gd): everything met so far, by kind — structures,
# devices, ship mechanisms, berth systems — each with its progress (devices
# 23/160). Unmet entries are grey silhouettes. The chosen entry: its drawing,
# the three sentences of its card and the working behind them, with numbers.
# "This ship" narrows the list to what the ship in hand carries.
# Opened with I on site (play paused), from the pause menu, the terminal, or
# straight onto a ship's entries from its contract card.
# Keys: ← → kind, ↑ ↓ entry, Tab this ship / everything, Esc or I close.

const LIST_X := 60.0
const LIST_W := 470.0
const ROW_H := 30.0
const DET_X := 590.0
const GuideCards = preload("res://scripts/guide_cards.gd")
const ARGS := {"n": "xx", "who": "", "client": "", "m": "3"}

var font: Font
var font_b: Font
var font_l: Font
var cat := 0
var sel := 0
var scroll := 0.0
var ship := ""                # the ship in hand ("" none)
var only_ship := false
var on_close: Callable
var t := 0.0
var hover_row := -1
var hover_tab := -1
var hover_filter := false
var hover_close := false
var det_scroll := 0.0


static func open(host: Node, focus: String = "", ship_id: String = "", closed: Callable = Callable(), ship_only: bool = false) -> CodexPage:
	var layer := CanvasLayer.new()
	layer.layer = 66
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(layer)
	var pg := CodexPage.new()
	pg.ship = ship_id
	pg.on_close = closed
	pg.only_ship = ship_only and ship_id != ""
	layer.add_child(pg)
	pg.focus(focus)
	return pg


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
	font_l = Fonts.get_font("Light")
	position = Vector2.ZERO
	size = get_viewport_rect().size


func focus(id: String) -> void:
	if id == "" or not CodexData.E.has(id):
		return
	cat = Codex.CATS.find(CodexData.E[id].cat)
	var l := rows()
	sel = maxi(0, l.find(id))
	if sel < 0 or l.find(id) < 0:
		only_ship = false
		l = rows()
		sel = maxi(0, l.find(id))
	_keep_in_view()


# the entries listed now: met ones first in the book's order, unmet after
func rows() -> Array:
	# 132 号: the last tab — the situation cards seen so far, shown again on Enter
	if _guide_tab():
		return GuideCards.seen_ids()
	var all: Array = Codex.ids(Codex.CATS[cat])
	if only_ship and ship != "":
		var mine := _ship_set()
		all = all.filter(func(id): return mine.has(id))
	var met: Array = all.filter(func(id): return Codex.seen(id))
	var unmet: Array = all.filter(func(id): return not Codex.seen(id))
	return met + unmet


# what the ship in hand carries: its mechanisms, its machines, its structures
var _mine := {}
func _ship_set() -> Dictionary:
	if not _mine.is_empty() or ship == "":
		return _mine
	for id in Codex.ship_entries(ship):
		_mine[id] = true
	var d := Ship.load_data(ship)
	for pd in d.get("pieces", []):
		var nk: String = pd.get("name_key", "")
		var art: String = Art.SH.BY_NAME.get(nk, Art.EQ.BY_NAME.get(nk, pd.get("art", "")))
		var id := Codex.device_entry(art)
		if id != "":
			_mine[id] = true
	for id in CodexData.E:
		var e: Dictionary = CodexData.E[id]
		if e.cat in ["struct", "sys"] and e.get("always", false):
			_mine[id] = true
	return _mine


func _guide_tab() -> bool:
	return cat == Codex.CATS.size()


func _ncat() -> int:
	return Codex.CATS.size() + 1


func _replay_rect() -> Rect2:
	return Rect2(DET_X, 190.0 + 360.0, 260.0, 58.0)


func replay() -> void:
	var id := chosen()
	if _guide_tab() and id != "" and not GuideCards.showing():
		GuideCards.show(null, id, ARGS, true, self)


func chosen() -> String:
	var l := rows()
	return l[sel] if sel >= 0 and sel < l.size() else ""


func close() -> void:
	var id := chosen()
	if id != "" and Codex.seen(id):
		Codex.read(id)
	if on_close.is_valid():
		on_close.call()
	get_parent().queue_free()


func _process(dt: float) -> void:
	t += dt
	if size != get_viewport_rect().size:
		position = Vector2.ZERO
		size = get_viewport_rect().size
	var m := get_local_mouse_position()
	hover_row = -1
	var l := rows()
	for i in l.size():
		if _row_rect(i).has_point(m) and _list_rect().has_point(m):
			hover_row = i
	hover_tab = -1
	for i in _ncat():
		if _tab_rect(i).has_point(m):
			hover_tab = i
	hover_filter = ship != "" and _filter_rect().has_point(m)
	hover_close = _close_rect().has_point(m)
	queue_redraw()


func _input(ev: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var handled := true
	if ev is InputEventKey and ev.pressed:
		match ev.physical_keycode:
			KEY_ESCAPE:
				close()
			KEY_ENTER, KEY_KP_ENTER:
				replay()
			KEY_LEFT, KEY_A:
				_set_cat(cat - 1)
			KEY_RIGHT, KEY_D:
				_set_cat(cat + 1)
			KEY_UP, KEY_W:
				_pick(sel - 1)
			KEY_DOWN, KEY_S:
				_pick(sel + 1)
			KEY_PAGEUP:
				_pick(sel - 10)
			KEY_PAGEDOWN:
				_pick(sel + 10)
			KEY_TAB:
				if ship != "":
					only_ship = not only_ship
					sel = 0
					scroll = 0.0
			_:
				if Keys.pressed(ev, "codex"):
					close()
	elif ev is InputEventMouseButton and ev.pressed:
		var m := get_local_mouse_position()
		match ev.button_index:
			MOUSE_BUTTON_LEFT:
				if hover_close:
					close()
				elif _guide_tab() and _replay_rect().has_point(m):
					replay()
				elif hover_tab >= 0:
					_set_cat(hover_tab)
				elif hover_filter:
					only_ship = not only_ship
					sel = 0
					scroll = 0.0
				elif hover_row >= 0:
					_pick(hover_row)
			MOUSE_BUTTON_WHEEL_UP:
				if _list_rect().has_point(m):
					scroll = maxf(0.0, scroll - ROW_H * 3.0)
				else:
					det_scroll = maxf(0.0, det_scroll - 40.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				if _list_rect().has_point(m):
					scroll = minf(_max_scroll(), scroll + ROW_H * 3.0)
				else:
					det_scroll += 40.0
			MOUSE_BUTTON_RIGHT:
				close()
	elif ev is InputEventMouseMotion:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _set_cat(i: int) -> void:
	cat = posmod(i, _ncat())
	sel = 0
	scroll = 0.0
	det_scroll = 0.0


func _pick(i: int) -> void:
	var id := chosen()
	if id != "" and Codex.seen(id):
		Codex.read(id)
	var n := rows().size()
	if n == 0:
		return
	sel = clampi(i, 0, n - 1)
	det_scroll = 0.0
	_keep_in_view()


func _keep_in_view() -> void:
	var lr := _list_rect()
	var y := sel * ROW_H
	if y < scroll:
		scroll = y
	elif y + ROW_H > scroll + lr.size.y:
		scroll = y + ROW_H - lr.size.y
	scroll = clampf(scroll, 0.0, _max_scroll())


func _max_scroll() -> float:
	return maxf(0.0, rows().size() * ROW_H - _list_rect().size.y)


# ---------------------------------------------------------------- layout

func _list_rect() -> Rect2:
	return Rect2(LIST_X, 206.0, LIST_W, size.y - 206.0 - 76.0)


func _row_rect(i: int) -> Rect2:
	var lr := _list_rect()
	return Rect2(lr.position.x, lr.position.y + i * ROW_H - scroll, lr.size.x, ROW_H - 2.0)


func _tab_rect(i: int) -> Rect2:
	return Rect2(LIST_X + i * 244.0, 116.0, 232.0, 56.0)


func _filter_rect() -> Rect2:
	return Rect2(size.x - 400.0, 116.0, 330.0, 56.0)


func _close_rect() -> Rect2:
	# 炭黑 v2: a key with its words and its keycap (was a bare ×)
	var tw := font_b.get_string_size("关闭" if Txt.zh else "CLOSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x if font_b != null else 40.0
	var w := tw + 96.0
	return Rect2(size.x - 60.0 - w, 40.0, w, 48.0)


# ---------------------------------------------------------------- draw

func _draw() -> void:
	var s := size
	# 炭黑 v2: the ground, the book's title; the kinds as numbered keys with their count in a black
	# window; the close a key with its keycap
	Charcoal.ground(self, s)
	UI.text(self, font_l, Txt.t("cxu_book"), Vector2(LIST_X, 80), 38, Pal.ink(0.97))
	UI.text(self, font, Txt.t("cxu_book_sub"), Vector2(LIST_X + 2, 104), 13, Pal.ink(0.5))
	var cr := _close_rect()
	var ck := Charcoal.key(self, cr, 1.0, 0.0, Charcoal.FACE_HI if hover_close else Charcoal.FACE, 9)
	UI.text(self, font_b, "关闭" if Txt.zh else "CLOSE", ck.position + Vector2(18, 31), 16, Pal.ink(0.95 if hover_close else 0.8))
	Charcoal.keycap(self, font_b, Rect2(ck.end.x - 60, ck.position.y + 11, 46, 26), "Esc")
	for i in _ncat():
		var r := _tab_rect(i)
		var on := i == cat
		var n: Vector2i = Codex.count(Codex.CATS[i]) if i < Codex.CATS.size() else Vector2i(GuideCards.seen_ids().size(), GuideCards.CARDS.size())
		var fr := Charcoal.key(self, r, 1.0, 1.0 if on else 0.0, Charcoal.FACE_HI if hover_tab == i and not on else Charcoal.FACE, 10)
		if on:
			Charcoal.lip(self, Rect2(fr.position.x + 12, fr.end.y - 6, fr.size.x - 24, 4))
		UI.text(self, font_l, "%d" % (i + 1), fr.position + Vector2(14, 37), 24, Charcoal.ACCENT if on else Pal.ink(0.45))
		UI.text(self, font_b, Txt.t("cxu_cat_" + (Codex.CATS[i] if i < Codex.CATS.size() else "guide")), fr.position + Vector2(40, 35), 17, Pal.ink(0.97 if on else 0.7))
		var nw := font_b.get_string_size("%d / %d" % [n.x, n.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 18.0
		var nr := Rect2(fr.end.x - nw - 10, fr.position.y + 14, nw, 26)
		Charcoal.display(self, nr, 1.0, 5)
		UI.text(self, font_b, "%d / %d" % [n.x, n.y], nr.position + Vector2(nw * 0.5, 18), 13, Pal.ink(0.92 if on else 0.6), 0)
	# this ship / everything: a choice key, its lamp lit while it narrows the list
	if ship != "":
		var fr2 := _filter_rect()
		var fk := Charcoal.key(self, fr2, 1.0, 1.0 if only_ship else 0.0, Charcoal.FACE_HI if hover_filter else Charcoal.FACE, 10)
		Charcoal.led(self, fk.position + Vector2(22, fk.size.y * 0.5), only_ship, 1.0, 4.5)
		if only_ship:
			Charcoal.lip(self, Rect2(fk.position.x + 12, fk.end.y - 6, fk.size.x - 24, 4))
		UI.text(self, font, Txt.t("cxu_ship_only") % _ship_name(), fk.position + Vector2(40, 34), 15, Pal.ink(0.9))
	_list()
	_detail()
	UI.text(self, font, Txt.t("cxu_keys") % Keys.label("codex"), Vector2(LIST_X, s.y - 30), 13, Pal.ink(0.45))


func _ship_name() -> String:
	var d := Ship.load_data(ship)
	var tt = d.get("title", null)
	if tt is Array and tt.size() == 2:
		return str(tt[0] if Txt.zh else tt[1]).split(" · ")[0]
	return Codex.code(ship)


func _list() -> void:
	var lr := _list_rect()
	var l := rows()
	Charcoal.display(self, lr.grow(8.0), 1.0, 10)
	if l.is_empty():
		UI.text(self, font, Txt.t("cxu_empty"), lr.position + Vector2(16, 30), 15, Pal.ink(0.4))
		return
	for i in l.size():
		var r := _row_rect(i)
		if r.end.y < lr.position.y or r.position.y > lr.end.y:
			continue
		var id: String = l[i]
		if _guide_tab():
			if i == sel:
				draw_rect(r, Charcoal.FACE)
				draw_rect(Rect2(r.position, Vector2(3, r.size.y)), Charcoal.ACCENT)
			UI.text(self, font, GuideCards.title(id, ARGS), r.position + Vector2(16, 20), 15, Pal.ink(0.95 if i == sel else 0.75))
			continue
		var met := Codex.seen(id)
		var on := i == sel
		if on:
			draw_rect(r, Charcoal.FACE)
			draw_rect(Rect2(r.position, Vector2(3, r.size.y)), Charcoal.ACCENT)
		elif i == hover_row:
			draw_rect(r, Color(0.06, 0.062, 0.068))
		if met:
			UI.text(self, font, Codex.title(id), r.position + Vector2(16, 20), 15, Pal.ink(0.95 if on else 0.75))
			if Codex.is_new(id):
				Charcoal.led(self, Vector2(r.end.x - 18, r.position.y + 14), true, 1.0, 3.5)
		else:
			UI.text(self, font, Txt.t("cxu_unmet"), r.position + Vector2(16, 20), 15, Pal.ink(0.25))
	# the scroll bar
	var total := l.size() * ROW_H
	if total > lr.size.y:
		var hh := lr.size.y * lr.size.y / total
		var yy := lr.position.y + (lr.size.y - hh) * (scroll / maxf(1.0, total - lr.size.y))
		draw_rect(Rect2(lr.end.x - 3, yy, 3, hh), Pal.ink(0.3))


func _detail() -> void:
	var id := chosen()
	var x := DET_X
	var w := size.x - DET_X - 70.0
	var top := 190.0
	Charcoal.panel(self, Rect2(x - 20, top + 8, w + 40, size.y - top - 84.0), 1.0, 0.0, Charcoal.FACE, 14)
	if id == "":
		return
	if _guide_tab():
		UI.text(self, font_b, GuideCards.title(id, ARGS), Vector2(x, top + 60), 30, Pal.ink(0.95))
		var yy := top + 120.0
		for s in GuideCards.lines(id, ARGS):
			UI.text(self, font, str(s), Vector2(x, yy), 20, Pal.ink(0.8))
			yy += 40.0
		var rr := _replay_rect()
		Charcoal.slab(self, rr, Charcoal.ACCENT, 10)
		UI.text(self, font_b, Txt.t("cxu_replay"), rr.position + Vector2(rr.size.x * 0.5, 38), 20, Color(0.08, 0.06, 0.05), 0)
		return
	var e: Dictionary = CodexData.E[id]
	var art_box := Rect2(x, top + 32, 420, 300)
	Charcoal.display(self, art_box.grow(6.0), 1.0, 10)
	if not Codex.seen(id):
		UI.text(self, font_l, "?", art_box.get_center() + Vector2(0, 26), 72, Pal.ink(0.15), 0)
		UI.text(self, font_b, Txt.t("cxu_unmet"), Vector2(x + 460, top + 70), 26, Pal.ink(0.4))
		UI.text(self, font, Txt.t("cxu_unmet_d"), Vector2(x + 460, top + 110), 15, Pal.ink(0.35))
		return
	CodexHud.draw_art(self, id, art_box, font, 1.0)
	var tx := x + 460.0
	var tw := w - 460.0
	UI.text(self, font, Txt.t("cxu_cat_" + str(e.cat)) + (("  ·  " + Txt.t("cxu_cls_" + str(e.cls))) if e.has("cls") else ""), Vector2(tx, top + 48), 13, Pal.ink(0.5))
	UI.text(self, font_b, Codex.title(id), Vector2(tx, top + 86), 30, Pal.ink(0.97))
	var y := top + 120.0
	for part in ["a", "b", "c"]:
		# 炭黑 v2: each line's lamp — the danger orange, the way white, the plain one dark
		var col: Color = Charcoal.ACCENT if part == "b" else (Pal.ink(0.95) if part == "c" else Pal.ink(0.55))
		Charcoal.led(self, Vector2(tx + 4, y + 11), part != "a", 1.0, 3.5, Charcoal.ACCENT if part == "b" else Color(0.92, 0.93, 0.9))
		UI.text(self, font_b, Txt.t("cxu_" + part), Vector2(tx + 14, y + 16), 12, col)
		y += _para(Codex.line(id, part), Vector2(tx + 80, y), tw - 80, 16, Pal.ink(0.92), 23.0) + 14.0
	# the working
	var wy := maxf(y, top + 350.0) + 14.0 - det_scroll
	Charcoal.groove(self, x, x + w, wy - 18)
	UI.text(self, font_b, Txt.t("cxu_x"), Vector2(x, wy + 6), 13, Pal.ink(0.55))
	_para(Codex.line(id, "x"), Vector2(x, wy + 18), w, 16, Pal.ink(0.82), 25.0)
	# which ships carry it
	var where: Array = e.get("ships", [])
	if not where.is_empty():
		var names: Array = []
		for sid in where:
			names.append(Codex.code(str(sid)))
		UI.text(self, font, Txt.t("cxu_ships") % ", ".join(names), Vector2(x, size.y - 92), 13, Pal.ink(0.45))


func _para(text: String, pos: Vector2, width: float, size_px: int, col: Color, lh: float) -> float:
	var tl := TextParagraph.new()
	tl.add_string(text, font, size_px)
	tl.width = width
	tl.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var y := pos.y
	for i in tl.get_line_count():
		tl.draw_line(get_canvas_item(), Vector2(pos.x, y), i, col)
		y += lh
	return y - pos.y
