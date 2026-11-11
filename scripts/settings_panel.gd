class_name SettingsPanel
extends CanvasLayer
# Settings, from the title and from the pause menu: three volumes, picture
# quality, language. Arrow keys or the mouse (left half of a row turns it
# down, right half up); every change is applied and saved at once.

signal closed

const ROWS := ["vol_master", "vol_music", "vol_sfx", "quality", "window", "anim", "reduce", "ui_scale", "calm", "film", "slowmo", "lang", "context", "codex_cards", "guide_cards", "playtest", "keys_row", "back"]

var testing := false
var is_open := false
var k := 0.0
var sel := 0
var hover := -1
var c: Control
var font: Font
var font_l: Font
var font_b: Font
var keys_open := false     # the key list instead of the settings
var ksel := 0
var waiting := false       # the next key press goes to Keys.ORDER[ksel]
var _t := 0.0              # the new skin's drifting glow (54 号)


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


func open() -> void:
	is_open = true
	keys_open = false
	waiting = false
	sel = 0


func close() -> void:
	if not is_open:
		return
	is_open = false
	closed.emit()


func _row_rect(i: int) -> Rect2:
	var s := c.size
	return Rect2(s.x * 0.5 - 390, s.y * 0.5 - 360 + i * 46, 780, 42)


func _key_rect(i: int) -> Rect2:
	var s := c.size
	var col := i % 2
	var row := i / 2
	return Rect2(s.x * 0.5 - 610 + col * 620, s.y * 0.5 - 330 + row * 50, 600, 42)


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
	if ev is InputEventKey and ev.pressed:
		match ev.physical_keycode:
			KEY_ESCAPE:
				keys_open = false
			KEY_UP, KEY_W:
				ksel = (ksel + n - 2) % n
			KEY_DOWN, KEY_S:
				ksel = (ksel + 2) % n
			KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D:
				ksel = ksel ^ 1 if ksel < Keys.ORDER.size() - 1 or ksel % 2 == 1 else ksel
			KEY_ENTER, KEY_SPACE:
				_key_pick(ksel)
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var m := c.get_local_mouse_position()
		for i in n:
			if _key_rect(i).has_point(m):
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
	if ev is InputEventKey and ev.pressed:
		match ev.physical_keycode:
			KEY_ESCAPE:
				close()
			KEY_UP, KEY_W:
				sel = (sel + ROWS.size() - 1) % ROWS.size()
			KEY_DOWN, KEY_S:
				sel = (sel + 1) % ROWS.size()
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
			for i in ROWS.size():
				var r := _row_rect(i)
				if r.has_point(m):
					sel = i
					if ROWS[i] == "back":
						close()
					elif ROWS[i] == "keys_row":
						keys_open = true
					else:
						change(ROWS[i], -1 if m.x < r.get_center().x else 1)
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion:
		get_viewport().set_input_as_handled()


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
			Txt.fullscreen = not Txt.fullscreen
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
			return Txt.t("s_win_full") if Txt.fullscreen else Txt.t("s_win_window")
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
	if is_open:
		var m := c.get_local_mouse_position()
		for i in ROWS.size():
			if _row_rect(i).has_point(m):
				hover = i
	if k > 0.005 or is_open:
		c.queue_redraw()


func _text(s: String, pos: Vector2, size_px: int, col: Color, f: Font = null, align: int = -1) -> void:
	var fo := f if f != null else font
	var x := pos.x
	if align == 0:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x * 0.5
	elif align == 1:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	c.draw_string(fo, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


func _draw_ui() -> void:
	if k < 0.005:
		return
	var s := c.size
	c.draw_set_transform(Vector2.ZERO)
	# 炭黑 v2: the charcoal ground, faded in with the page
	if k > 0.98:
		Charcoal.ground(c, s)
	else:
		c.draw_rect(Rect2(Vector2.ZERO, s), Color(Charcoal.BG, 0.96 * k))
	if keys_open:
		_draw_keys(s)
		return
	var r0 := _row_rect(0)
	var rl := _row_rect(ROWS.size() - 2)
	_text(Txt.t("s_title"), Vector2(r0.position.x - 4, r0.position.y - 30), 34, Pal.ink(0.95 * k), font_l)
	# one plate under the rows; a groove between the groups (sound / picture and motion / language and help)
	Charcoal.panel(c, Rect2(r0.position - Vector2(22, 12), Vector2(r0.size.x + 44, rl.end.y - r0.position.y + 38)), k, 0.0, Charcoal.FACE, 14)
	var fl: Font = font_l
	for i in ROWS.size():
		var row: String = ROWS[i]
		var r := _row_rect(i)
		r.position.y += (1.0 - Motion.stagger(k * 0.6, i, 0.04, 0.2)) * 16.0
		var on := i == sel or i == hover
		if i in [3, 11, 16]:
			Charcoal.groove(c, r.position.x + 8, r.end.x - 8, r.position.y - 3, k)
		if row == "back":
			var br := Rect2(r.position.x, r.position.y + 4, r.size.x, 46)
			var fr := Charcoal.key(c, br, k, 0.0, Charcoal.FACE_HI if on else Charcoal.FACE, 10)
			_text(Txt.t("s_back"), fr.position + Vector2(22, 31), 18, Pal.ink((0.97 if on else 0.75) * k), font_b)
			Charcoal.keycap(c, font_b, Rect2(fr.end.x - 62, fr.position.y + 11, 48, 26), "Esc", k)
			if on:
				Charcoal.lip(c, Rect2(fr.position.x + 14, fr.end.y - 6, fr.size.x - 28, 4), k)
			continue
		# the chosen row lit, the orange lip at its left
		if on:
			c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, r.size.y), Color(Charcoal.FACE_HI, k))
			c.draw_rect(Rect2(r.position.x, r.position.y + 4, 3, r.size.y - 8), Color(Charcoal.ACCENT, k))
		_text("%02d" % (i + 1), r.position + Vector2(16, 29), 17, Color(Charcoal.ACCENT, k) if on else Pal.ink(0.35 * k), fl)
		if row == "keys_row":
			_text(Txt.t("s_keys_row"), r.position + Vector2(58, 28), 17, Pal.ink((0.97 if on else 0.75) * k), font)
			var kr := Rect2(r.end.x - 232, r.position.y + 5, 220, r.size.y - 10)
			Charcoal.display(c, kr, k, 6)
			_text("→", Vector2(kr.get_center().x, kr.position.y + 23), 17, Pal.ink(0.85 * k), font_b, 0)
			continue
		_text(Txt.t("s_" + row), r.position + Vector2(58, 28), 17, Pal.ink((0.97 if on else 0.75) * k), font)
		# the value in a black window, its arrows at its ends; a switch has its lamp
		var v := value(row)
		var vr := Rect2(r.end.x - 232, r.position.y + 5, 220, r.size.y - 10)
		Charcoal.display(c, vr, k, 6)
		_text("◂", Vector2(vr.position.x + 16, vr.position.y + 23), 15, Pal.ink((0.7 if on else 0.35) * k), font, 0)
		_text("▸", Vector2(vr.end.x - 16, vr.position.y + 23), 15, Pal.ink((0.7 if on else 0.35) * k), font, 0)
		var is_sw := v == Txt.t("s_on") or v == Txt.t("s_off")
		if is_sw:
			Charcoal.led(c, Vector2(vr.position.x + 44, vr.get_center().y), v == Txt.t("s_on"), k, 4.0)
		_text(v, Vector2(vr.get_center().x + (8.0 if is_sw else 0.0), vr.position.y + 23), 17, Pal.ink(0.97 * k), font_b, 0)
		if row.begins_with("vol_"):
			var f: float = {"vol_master": Txt.vol_master, "vol_music": Txt.vol_music, "vol_sfx": Txt.vol_sfx}[row]
			Charcoal.segments(c, Rect2(vr.position.x - 236, r.position.y + 17, 216, 8), f * 12.0, 12, k)
	_text(Txt.t("s_keys"), Vector2(s.x * 0.5, _row_rect(ROWS.size()).position.y + 44), 13, Pal.ink(0.45 * k), font, 0)


# the key list: every action, its key; Enter (or a click) waits for the new one
func _draw_keys(s: Vector2) -> void:
	_text(Txt.t("s_keys_row"), Vector2(s.x * 0.5, s.y * 0.5 - 380), 30, Pal.ink(0.9 * k), font_l, 0)
	for i in Keys.ORDER.size() + 1:
		var r := _key_rect(i)
		var on := i == ksel
		var fr := Charcoal.key(c, r, k, 0.0, Charcoal.FACE_HI if on else Charcoal.FACE, 9)
		if on:
			Charcoal.lip(c, Rect2(fr.position.x + 3, fr.position.y + 6, 3, fr.size.y - 12), k)
		if i == Keys.ORDER.size():
			_text(Txt.t("s_reset"), r.position + Vector2(20, 28), 16, Pal.ink((0.95 if on else 0.6) * k), font)
			continue
		var a: String = Keys.ORDER[i]
		_text(Txt.t("key_" + a), r.position + Vector2(20, 28), 16, Pal.ink((0.95 if on else 0.7) * k), font)
		var v := Txt.t("s_press") if on and waiting else Keys.label(a)
		var vw := maxf(64.0, font_b.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 28.0)
		var vr := Rect2(r.end.x - 10 - vw, r.position.y + 6, vw, r.size.y - 12)
		Charcoal.display(c, vr, k, 6)
		_text(v, Vector2(vr.get_center().x, r.position.y + 27), 16, Color(Charcoal.ACCENT, k) if on and waiting else Pal.ink(0.95 * k), font_b, 0)
	_text(Txt.t("s_keys_help"), Vector2(s.x * 0.5, _key_rect(Keys.ORDER.size() + 2).position.y + 30), 13, Pal.ink(0.5 * k), font, 0)
