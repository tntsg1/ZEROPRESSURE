class_name SettingsPanel
extends CanvasLayer
# Settings, from the title and from the pause menu: three volumes, picture
# quality, language. Arrow keys or the mouse (left half of a row turns it
# down, right half up); every change is applied and saved at once.
# 公测反馈 #13 (in a window the key list was cut at the bottom): both pages list their rows in a
# clipped strip that scrolls (the wheel, the arrows, Page Up/Down, Home/End, the bar at its right);
# the title and the bottom button ("back", "reset the keys") stay on the screen.

signal closed

const ROWS := ["vol_master", "vol_music", "vol_sfx", "quality", "window", "anim", "reduce", "ui_scale", "calm", "film", "slowmo", "lang", "context", "codex_cards", "guide_cards", "playtest", "keys_row", "back"]
const RH := 46.0           # a settings row
const KH := 50.0           # a key row

var testing := false
var is_open := false
var k := 0.0
var sel := 0
var hover := -1
var c: Control
var lc: Control            # the scrolling strip, clipped: its rows are drawn in it
var cv: CanvasItem         # what the drawing helpers draw on now
var font: Font
var font_l: Font
var font_b: Font
var keys_open := false     # the key list instead of the settings
var ksel := 0
var waiting := false       # the next key press goes to Keys.ORDER[ksel]
var _t := 0.0              # the new skin's drifting glow (54 号)
var scroll := 0.0          # the settings strip, px from its top
var kscroll := 0.0         # the key strip
var view_h := 0.0          # tests: as if the screen were only this tall (0: as it is)
var _drag := false         # the bar's thumb held


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = Fonts.get_font("Regular")
	font_l = Fonts.get_font("Light")
	font_b = Fonts.get_font("Medium")
	c = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_draw_ui)
	add_child(c)
	lc = Control.new()
	lc.clip_contents = true
	lc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lc.draw.connect(_draw_strip)
	c.add_child(lc)
	cv = c


func open() -> void:
	is_open = true
	keys_open = false
	waiting = false
	sel = 0
	scroll = 0.0
	kscroll = 0.0


func close() -> void:
	if not is_open:
		return
	is_open = false
	closed.emit()


# ---------------------------------------------------------------- layout

func _view() -> Vector2:
	var s := c.size
	if view_h > 0.0:
		s.y = minf(s.y, view_h)
	return s


# a page's strip: its top and bottom on the screen, the full height of its rows, how far it scrolls
func _main_box() -> Dictionary:
	var s := _view()
	var full := (ROWS.size() - 1) * RH
	var top := maxf(76.0, s.y * 0.5 - 360.0)
	var bot := minf(top + full, s.y - 100.0)
	return {"top": top, "bot": bot, "full": full, "max": maxf(0.0, full - (bot - top))}


func _keys_box() -> Dictionary:
	var s := _view()
	var full := ceilf(Keys.ORDER.size() / 2.0) * KH
	var top := maxf(20.0, (s.y - (60.0 + full + 100.0)) * 0.5) + 60.0
	var bot := minf(top + full, s.y - 100.0)
	return {"top": top, "bot": bot, "full": full, "max": maxf(0.0, full - (bot - top))}


func _box() -> Dictionary:
	return _keys_box() if keys_open else _main_box()


func _row_rect(i: int) -> Rect2:
	var x := c.size.x * 0.5 - 390
	var b := _main_box()
	if i >= ROWS.size() - 1:
		return Rect2(x, b.bot + (i - (ROWS.size() - 1)) * RH, 780, 42)
	return Rect2(x, b.top + i * RH - scroll, 780, 42)


func _key_rect(i: int) -> Rect2:
	var s := c.size
	var b := _keys_box()
	if i >= Keys.ORDER.size():
		return Rect2(s.x * 0.5 - 300, b.bot + 12 + (i - Keys.ORDER.size()) * KH, 600, 42)
	return Rect2(s.x * 0.5 - 610 + (i % 2) * 620, b.top + (i / 2) * KH - kscroll, 600, 42)


# the strip on the screen (a click reaches a strip row only inside it)
func _strip() -> Rect2:
	var b := _box()
	return Rect2(0, b.top - 4, c.size.x, b.bot - b.top + 4)


func _bar() -> Rect2:
	var b := _box()
	return Rect2(c.size.x * 0.5 + (626.0 if keys_open else 418.0), b.top, 8, b.bot - b.top - 6)


func _cur_scroll() -> float:
	return kscroll if keys_open else scroll


func _set_scroll(v: float) -> void:
	v = clampf(v, 0.0, _box().max)
	if keys_open:
		kscroll = v
	else:
		scroll = v


# the chosen row brought into the strip
func _follow() -> void:
	var b := _box()
	var r: Rect2
	if keys_open:
		if ksel >= Keys.ORDER.size():
			return
		r = _key_rect(ksel)
	else:
		if sel >= ROWS.size() - 1:
			return
		r = _row_rect(sel)
	if r.position.y < b.top:
		_set_scroll(_cur_scroll() - (b.top - r.position.y))
	elif r.end.y > b.bot - 4.0:
		_set_scroll(_cur_scroll() + (r.end.y - (b.bot - 4.0)))


# the wheel, Page Up/Down, Home/End and the bar: true when the event was one of them
func _scroll_input(ev: InputEvent) -> bool:
	var b := _box()
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				var dir := -1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
				_set_scroll(_cur_scroll() + dir * (KH if keys_open else RH) * maxf(1.0, mb.factor))
			return true
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if not mb.pressed:
				var was := _drag
				_drag = false
				return was
			if b.max > 0.0 and _bar().grow_individual(8, 0, 8, 0).has_point(c.get_local_mouse_position()):
				_drag = true
				_bar_to(c.get_local_mouse_position().y)
				return true
	elif ev is InputEventMouseMotion and _drag:
		_bar_to(c.get_local_mouse_position().y)
		return true
	elif ev is InputEventKey and ev.pressed:
		var page: float = b.bot - b.top - 40.0
		match ev.physical_keycode:
			KEY_PAGEUP:
				_set_scroll(_cur_scroll() - page)
				return true
			KEY_PAGEDOWN:
				_set_scroll(_cur_scroll() + page)
				return true
			KEY_HOME:
				_set_scroll(0.0)
				return true
			KEY_END:
				_set_scroll(b.max)
				return true
	return false


func _thumb_h(b: Dictionary) -> float:
	var r := _bar()
	return maxf(30.0, r.size.y * (b.bot - b.top) / maxf(1.0, b.full))


func _bar_to(y: float) -> void:
	var b := _box()
	var r := _bar()
	var th := _thumb_h(b)
	_set_scroll((y - r.position.y - th * 0.5) / maxf(1.0, r.size.y - th) * b.max)


# ---------------------------------------------------------------- input

func _keys_input(ev: InputEvent) -> void:
	var n := Keys.ORDER.size() + 1
	if waiting:
		if ev is InputEventKey and ev.pressed and not ev.echo:
			if ev.physical_keycode != KEY_ESCAPE:
				Keys.bind(Keys.ORDER[ksel], ev.physical_keycode)
				Txt.save_settings(testing)
			waiting = false
		get_viewport().set_input_as_handled()
		return
	if _scroll_input(ev):
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventKey and ev.pressed:
		match ev.physical_keycode:
			KEY_ESCAPE:
				keys_open = false
			KEY_UP, KEY_W:
				ksel = (ksel + n - 2) % n
				_follow()
			KEY_DOWN, KEY_S:
				ksel = (ksel + 2) % n
				_follow()
			KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D:
				ksel = ksel ^ 1 if ksel < Keys.ORDER.size() - 1 or ksel % 2 == 1 else ksel
			KEY_ENTER, KEY_SPACE:
				_key_pick(ksel)
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var m := c.get_local_mouse_position()
		var st := _strip()
		for i in n:
			if _key_rect(i).has_point(m) and (i >= Keys.ORDER.size() or st.has_point(m)):
				ksel = i
				_key_pick(i)
	get_viewport().set_input_as_handled()


func _key_pick(i: int) -> void:
	if i >= Keys.ORDER.size():
		Keys.reset()
		Txt.save_settings(testing)
	else:
		waiting = true


func _input(ev: InputEvent) -> void:
	if not is_open:
		return
	if keys_open:
		_keys_input(ev)
		return
	if _scroll_input(ev):
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventKey and ev.pressed:
		match ev.physical_keycode:
			KEY_ESCAPE:
				close()
			KEY_UP, KEY_W:
				sel = (sel + ROWS.size() - 1) % ROWS.size()
				_follow()
			KEY_DOWN, KEY_S:
				sel = (sel + 1) % ROWS.size()
				_follow()
			KEY_LEFT, KEY_A:
				change(ROWS[sel], -1)
			KEY_RIGHT, KEY_D:
				change(ROWS[sel], 1)
			KEY_ENTER, KEY_SPACE:
				if ROWS[sel] == "back":
					close()
				elif ROWS[sel] == "keys_row":
					keys_open = true
				else:
					change(ROWS[sel], 1)
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			var m := c.get_local_mouse_position()
			var i := _row_at(m)
			if i >= 0:
				sel = i
				if ROWS[i] == "back":
					close()
				elif ROWS[i] == "keys_row":
					keys_open = true
				else:
					change(ROWS[i], -1 if m.x < _row_rect(i).get_center().x else 1)
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion:
		get_viewport().set_input_as_handled()


# the row under a point: a strip row only where the strip shows it, the back row under the strip
func _row_at(m: Vector2) -> int:
	var st := Rect2(0, _main_box().top - 4, c.size.x, _main_box().bot - _main_box().top + 4)
	for i in ROWS.size():
		if _row_rect(i).has_point(m) and (i >= ROWS.size() - 1 or st.has_point(m)):
			return i
	return -1


func change(row: String, dir: int) -> void:
	match row:
		"vol_master":
			Txt.vol_master = clampf(snappedf(Txt.vol_master + dir * 0.1, 0.1), 0.0, 1.0)
		"vol_music":
			Txt.vol_music = clampf(snappedf(Txt.vol_music + dir * 0.1, 0.1), 0.0, 1.0)
		"vol_sfx":
			Txt.vol_sfx = clampf(snappedf(Txt.vol_sfx + dir * 0.1, 0.1), 0.0, 1.0)
		"quality":
			Txt.quality = "low" if Txt.quality == "high" else "high"
		"lang":
			Txt.zh = not Txt.zh
		"context":
			Txt.context = not Txt.context
		"codex_cards":
			Txt.codex_cards = not Txt.codex_cards
		"guide_cards":
			Txt.guide_cards = not Txt.guide_cards
		"playtest":
			Txt.playtest = not Txt.playtest
		"window":
			var wi := Txt.WIN_MODES.find(Txt.win_mode)
			Txt.win_mode = Txt.WIN_MODES[(wi + (1 if dir >= 0 else -1) + Txt.WIN_MODES.size()) % Txt.WIN_MODES.size()]
			Txt.fullscreen = Txt.win_mode == "full"
		"calm":
			Txt.calm = not Txt.calm
		"reduce":
			Txt.reduce_motion = not Txt.reduce_motion
		"ui_scale":
			Txt.ui_scale = clampf(snappedf(Txt.ui_scale + 0.1 * (1 if dir >= 0 else -1), 0.1), 0.9, 1.3)
		"film":
			Txt.film = not Txt.film
		"slowmo":
			Txt.slowmo_on = not Txt.slowmo_on
		"anim":
			var i := Txt.ANIM_LEVELS.find(Txt.anim)
			Txt.anim = Txt.ANIM_LEVELS[(i + (1 if dir >= 0 else -1) + Txt.ANIM_LEVELS.size()) % Txt.ANIM_LEVELS.size()]
		"keys_row":
			keys_open = true
			return
	Txt.save_settings(testing)
	Settings.apply(get_viewport())


func value(row: String) -> String:
	match row:
		"vol_master":
			return "%d%%" % roundi(Txt.vol_master * 100.0)
		"vol_music":
			return "%d%%" % roundi(Txt.vol_music * 100.0)
		"vol_sfx":
			return "%d%%" % roundi(Txt.vol_sfx * 100.0)
		"quality":
			return Txt.t("s_q_" + Txt.quality)
		"lang":
			return "中文" if Txt.zh else "ENGLISH"
		"context":
			return Txt.t("s_on") if Txt.context else Txt.t("s_off")
		"codex_cards":
			return Txt.t("s_on") if Txt.codex_cards else Txt.t("s_off")
		"guide_cards":
			return Txt.t("s_on") if Txt.guide_cards else Txt.t("s_off")
		"playtest":
			return Txt.t("s_on") if Txt.playtest else Txt.t("s_off")
		"window":
			return Txt.t({"full": "s_win_full", "borderless": "s_win_borderless"}.get(Txt.win_mode, "s_win_window"))
		"calm":
			return Txt.t("s_off") if Txt.no_flash() else Txt.t("s_on")
		"reduce":
			return Txt.t("s_on") if Txt.reduce_motion else Txt.t("s_off")
		"ui_scale":
			return "%d%%" % roundi(Txt.ui_scale * 100.0)

		"film":
			return Txt.t("s_on") if Txt.film else Txt.t("s_off")
		"slowmo":
			return Txt.t("s_on") if Txt.slowmo_on else Txt.t("s_off")
		"anim":
			return Txt.t("s_anim_" + Txt.anim)
	return ""


func _process(dt: float) -> void:
	_t += dt
	k = Pal.damp(k, 1.0 if is_open else 0.0, 14.0, dt) if UiSkin.motion() else (1.0 if is_open else 0.0)
	hover = -1
	if is_open and not keys_open:
		hover = _row_at(c.get_local_mouse_position())
	if k > 0.005 or is_open:
		_set_scroll(_cur_scroll())       # a resized window: the strip kept in its range
		c.queue_redraw()
		lc.queue_redraw()


func _text(s: String, pos: Vector2, size_px: int, col: Color, f: Font = null, align: int = -1) -> void:
	var fo := f if f != null else font
	var x := pos.x
	if align == 0:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x * 0.5
	elif align == 1:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	cv.draw_string(fo, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


func _draw_ui() -> void:
	cv = c
	var st := _strip()
	lc.position = st.position
	lc.size = st.size
	if k < 0.005:
		return
	var s := c.size
	c.draw_set_transform(Vector2.ZERO)
	# 炭黑 v2: the charcoal ground, faded in with the page
	if k > 0.98:
		Charcoal.ground(c, s)
	else:
		c.draw_rect(Rect2(Vector2.ZERO, s), Color(Charcoal.BG, 0.96 * k))
	var b := _box()
	if keys_open:
		_text(Txt.t("s_keys_row"), Vector2(s.x * 0.5, b.top - 26), 30, Pal.ink(0.9 * k), font_l, 0)
		_draw_key(Keys.ORDER.size())
		_text(Txt.t("s_keys_help"), Vector2(s.x * 0.5, b.bot + 12 + 42 + 30), 13, Pal.ink(0.5 * k), font, 0)
		_draw_bar(b)
		return
	var x0 := s.x * 0.5 - 390
	_text(Txt.t("s_title"), Vector2(x0 - 4, b.top - 30), 34, Pal.ink(0.95 * k), font_l)
	# one plate under the rows; a groove between the groups (sound / picture and motion / language and help)
	Charcoal.panel(c, Rect2(Vector2(x0 - 22, b.top - 12), Vector2(780 + 44, b.bot - b.top + 34)), k, 0.0, Charcoal.FACE, 14)
	_draw_row(ROWS.size() - 1)
	_text(Txt.t("s_keys"), Vector2(s.x * 0.5, b.bot + RH + 44), 13, Pal.ink(0.45 * k), font, 0)
	_draw_bar(b)


# the strip's rows, clipped to it
func _draw_strip() -> void:
	if k < 0.005:
		return
	cv = lc
	lc.draw_set_transform(-lc.position)
	if keys_open:
		for i in Keys.ORDER.size():
			_draw_key(i)
	else:
		for i in ROWS.size() - 1:
			_draw_row(i)
	cv = c


# the bar at the strip's right and a fade at an edge with more beyond it, only when it scrolls
func _draw_bar(b: Dictionary) -> void:
	if b.max <= 0.0:
		return
	var r := _bar()
	c.draw_rect(Rect2(r.position.x + 3, r.position.y, 2, r.size.y), Pal.ink(0.12 * k))
	var th := _thumb_h(b)
	var y: float = r.position.y + (r.size.y - th) * _cur_scroll() / maxf(1.0, b.max)
	c.draw_rect(Rect2(r.position.x + 1, y, 6, th), Color(Charcoal.ACCENT, (0.9 if _drag else 0.6) * k))


func _draw_row(i: int) -> void:
	var row: String = ROWS[i]
	var r := _row_rect(i)
	r.position.y += (1.0 - Motion.stagger(k * 0.6, i, 0.04, 0.2)) * 16.0
	var on := i == sel or i == hover
	if i in [3, 11, 16]:
		Charcoal.groove(cv, r.position.x + 8, r.end.x - 8, r.position.y - 3, k)
	if row == "back":
		var br := Rect2(r.position.x, r.position.y + 4, r.size.x, 46)
		var fr := Charcoal.key(cv, br, k, 0.0, Charcoal.FACE_HI if on else Charcoal.FACE, 10)
		_text(Txt.t("s_back"), fr.position + Vector2(22, 31), 18, Pal.ink((0.97 if on else 0.75) * k), font_b)
		Charcoal.keycap(cv, font_b, Rect2(fr.end.x - 62, fr.position.y + 11, 48, 26), "Esc", k)
		if on:
			Charcoal.lip(cv, Rect2(fr.position.x + 14, fr.end.y - 6, fr.size.x - 28, 4), k)
		return
	# the chosen row lit, the orange lip at its left
	if on:
		cv.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, r.size.y), Color(Charcoal.FACE_HI, k))
		cv.draw_rect(Rect2(r.position.x, r.position.y + 4, 3, r.size.y - 8), Color(Charcoal.ACCENT, k))
	_text("%02d" % (i + 1), r.position + Vector2(16, 29), 17, Color(Charcoal.ACCENT, k) if on else Pal.ink(0.35 * k), font_l)
	if row == "keys_row":
		_text(Txt.t("s_keys_row"), r.position + Vector2(58, 28), 17, Pal.ink((0.97 if on else 0.75) * k), font)
		var kr := Rect2(r.end.x - 232, r.position.y + 5, 220, r.size.y - 10)
		Charcoal.display(cv, kr, k, 6)
		_text("→", Vector2(kr.get_center().x, kr.position.y + 23), 17, Pal.ink(0.85 * k), font_b, 0)
		return
	_text(Txt.t("s_" + row), r.position + Vector2(58, 28), 17, Pal.ink((0.97 if on else 0.75) * k), font)
	# the value in a black window, its arrows at its ends; a switch has its lamp
	var v := value(row)
	var vr := Rect2(r.end.x - 232, r.position.y + 5, 220, r.size.y - 10)
	Charcoal.display(cv, vr, k, 6)
	_text("◂", Vector2(vr.position.x + 16, vr.position.y + 23), 15, Pal.ink((0.7 if on else 0.35) * k), font, 0)
	_text("▸", Vector2(vr.end.x - 16, vr.position.y + 23), 15, Pal.ink((0.7 if on else 0.35) * k), font, 0)
	var is_sw := v == Txt.t("s_on") or v == Txt.t("s_off")
	if is_sw:
		Charcoal.led(cv, Vector2(vr.position.x + 44, vr.get_center().y), v == Txt.t("s_on"), k, 4.0)
	_text(v, Vector2(vr.get_center().x + (8.0 if is_sw else 0.0), vr.position.y + 23), 17, Pal.ink(0.97 * k), font_b, 0)
	if row.begins_with("vol_"):
		var f: float = {"vol_master": Txt.vol_master, "vol_music": Txt.vol_music, "vol_sfx": Txt.vol_sfx}[row]
		Charcoal.segments(cv, Rect2(vr.position.x - 236, r.position.y + 17, 216, 8), f * 12.0, 12, k)


# one key of the list: its action and its key; Enter (or a click) waits for the new one. The last
# one (reset) stands under the strip
func _draw_key(i: int) -> void:
	var r := _key_rect(i)
	var on := i == ksel
	var fr := Charcoal.key(cv, r, k, 0.0, Charcoal.FACE_HI if on else Charcoal.FACE, 9)
	if on:
		Charcoal.lip(cv, Rect2(fr.position.x + 3, fr.position.y + 6, 3, fr.size.y - 12), k)
	if i == Keys.ORDER.size():
		_text(Txt.t("s_reset"), r.position + Vector2(20, 28), 16, Pal.ink((0.95 if on else 0.6) * k), font)
		return
	var a: String = Keys.ORDER[i]
	_text(Txt.t("key_" + a), r.position + Vector2(20, 28), 16, Pal.ink((0.95 if on else 0.7) * k), font)
	var v := Txt.t("s_press") if on and waiting else Keys.label(a)
	var vw := maxf(64.0, font_b.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 28.0)
	var vr := Rect2(r.end.x - 10 - vw, r.position.y + 6, vw, r.size.y - 12)
	Charcoal.display(cv, vr, k, 6)
	_text(v, Vector2(vr.get_center().x, r.position.y + 27), 16, Color(Charcoal.ACCENT, k) if on and waiting else Pal.ink(0.95 * k), font_b, 0)
