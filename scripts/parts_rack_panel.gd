extends Control
# The parts rack (86 号 Q11, was the berth page's right column): opened with E at the rack under the
# berth's terminal, or at the cargo district's left racks once the district is mended. Play goes on
# while it is open; Esc closes. Repair is the authority.
# 107 号 (user 2026-10-29: "这个零件架打开之后还是那个 UI 啊，和零件架有什么关系？" — Q1 A, Q2 A): the
# rack itself, full screen. Four shelves, one class each (sail, power, thermal, drive), every part a
# crate on its shelf with its tag, its condition and its price; a shelf with more than fits scrolls
# sideways (no limit on the rack: Q2 A). Under them two bins, hull plate and sections, heaped as
# high as the tonnes. Click a crate (or ← → ↑ ↓) and its card on the right sells or lists it;
# "sell all" asks twice.

const ROWS := ["sail", "power", "thermal", "drive"]
const DETAIL_W := 400.0
const PAD := 44.0
const POST := 30.0          # px: the rack's uprights
const LABEL_W := 150.0      # px: the shelf's plate on the left upright
const BEAM := 12.0          # px: a shelf's beam
const GAP := 14.0           # px between crates
const CONFIRM_S := 3.0      # s: "sell all" waits this long for its second press

var game
var on_close: Callable
var font: Font
var font_b: Font
var font_s: Font
var t := 0.0
var open_t := 0.0
var sel_row := -1
var sel_col := 0
var hover := Vector2i(-1, -1)
var scroll := [0.0, 0.0, 0.0, 0.0]
var scroll_to := [0.0, 0.0, 0.0, 0.0]
var frame := Rect2()         # the selection frame, gliding (in the rack's own coordinates)
var message := ""
var msg_ok := true
var msg_t := 0.0
var confirm_all := 0.0
var flyers: Array = []       # crates just sold or listed: {rect, t, text, col}
var _by := {}
var _sig := ""
var _ship_names := {}
var rows_ui: Array = []      # one clipped Control per shelf
var overlay: Control
var sell_b: Button
var list_b: Button
var all_b: Button
var close_b: Button


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = OpsSkin.theme()
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
	font_s = Fonts.get_font("SemiBold")
	for i in ROWS.size():
		var r := Control.new()
		r.name = "Shelf_" + ROWS[i]
		r.clip_contents = true
		r.mouse_filter = Control.MOUSE_FILTER_STOP
		r.draw.connect(_draw_row.bind(r, i))
		r.gui_input.connect(_row_input.bind(i))
		r.mouse_exited.connect(func(): hover = Vector2i(-1, -1))
		add_child(r)
		rows_ui.append(r)
	sell_b = _button("Sell", func(): _sell_sel())
	list_b = _button("List", func(): _list_sel())
	all_b = _button("SellAll", func(): _sell_all())
	close_b = _button("Close", close)
	close_b.text = w("关闭 [Esc]", "CLOSE [Esc]")
	UiSkin.accent_button(sell_b)
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	resized.connect(_layout)
	_refresh(true)
	_layout()


func _button(id: String, f: Callable) -> Button:
	var b := Button.new()
	b.name = id
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 44
	b.pressed.connect(f)
	add_child(b)
	return b


# ---------------------------------------------------------------- the state

func _sig_now() -> String:
	var s := ""
	for part in Career.data.get("parts", []):
		s += str(part.uid) + ("L%d" % int(float(part.listed.t)) if part.has("listed") else "") + ";"
	return "%s|%.2f|%.2f|%.2f" % [s, float(Career.data.get("structure_t", 0.0)), Repair._stock_t(Repair.PLATE), Repair._stock_t(Repair.SECTION)]


func _refresh(force := false) -> void:
	var sig := _sig_now()
	if sig == _sig and not force:
		return
	_sig = sig
	_by = Repair.shelf_by_class()
	for cls in ROWS:
		if not _by.has(cls):
			_by[cls] = []
	# the selection keeps to a crate that is still there, else the nearest one
	if sel_row < 0 or _row(sel_row).is_empty():
		sel_row = -1
		for i in ROWS.size():
			if not _row(i).is_empty():
				sel_row = i
				break
	if sel_row >= 0:
		sel_col = clampi(sel_col, 0, _row(sel_row).size() - 1)
	_update_buttons()
	queue_redraw()
	for r in rows_ui:
		r.queue_redraw()


func _row(i: int) -> Array:
	return _by.get(ROWS[i], []) if i >= 0 and i < ROWS.size() else []


func selected() -> Dictionary:
	var r := _row(sel_row)
	return r[sel_col] if sel_col >= 0 and sel_col < r.size() else {}


func _count() -> int:
	var n := 0
	for i in ROWS.size():
		n += _row(i).size()
	return n


func _total() -> float:
	var v := 0.0
	for i in ROWS.size():
		for part in _row(i):
			if not part.has("listed"):
				v += Repair.part_worth(part)
	return v


func _plate_t() -> float:
	return float(Career.data.get("structure_t", 0.0)) + Repair._stock_t(Repair.PLATE)


func _section_t() -> float:
	return Repair._stock_t(Repair.SECTION)


static func short_class(cls: String) -> String:
	return str(Repair.class_name_of(cls)).split("（")[0].split(" (")[0]


func _part_name(part: Dictionary) -> String:
	var nk := str(part.get("nk", ""))
	return Txt.t(nk) if nk != "" and Txt.has(nk) else str(part.get("tag", ""))


func _ship_name(id: String) -> String:
	if id == "":
		return ""
	if not _ship_names.has(id):
		var d := Ship.load_data(id)
		_ship_names[id] = str(d.get("name", id)) if not d.is_empty() else id
	return _ship_names[id]


# ---------------------------------------------------------------- layout

func _rack_rect() -> Rect2:
	return Rect2(PAD, 112.0, size.x - PAD * 2.0 - DETAIL_W - 28.0, size.y - 112.0 - 64.0)


func _detail_rect() -> Rect2:
	var r := _rack_rect()
	return Rect2(r.end.x + 28.0, r.position.y, DETAIL_W, r.size.y)


func _bins_h() -> float:
	return clampf(_rack_rect().size.y * 0.17, 92.0, 140.0)


func _row_h() -> float:
	return (_rack_rect().size.y - 22.0 - _bins_h() - BEAM) / ROWS.size()


# the inside of a shelf, where its crates stand (screen coordinates)
func _shelf_rect(i: int) -> Rect2:
	var r := _rack_rect()
	var x0 := r.position.x + POST + LABEL_W
	return Rect2(x0, r.position.y + 22.0 + i * _row_h(), r.end.x - POST - x0, _row_h() - BEAM)


func _crate_w() -> float:
	return clampf(_row_h() * 1.22, 118.0, 176.0)


# a crate in its shelf's own coordinates (before the scroll)
func _crate_rect(i: int, k: int) -> Rect2:
	var sh := _shelf_rect(i)
	var h := sh.size.y - 16.0
	return Rect2(14.0 + k * (_crate_w() + GAP), sh.size.y - h, _crate_w(), h)


func _content_w(i: int) -> float:
	return 28.0 + _row(i).size() * (_crate_w() + GAP) - GAP


func _max_scroll(i: int) -> float:
	return maxf(0.0, _content_w(i) - _shelf_rect(i).size.x)


func _layout() -> void:
	for i in rows_ui.size():
		var sh := _shelf_rect(i)
		rows_ui[i].position = sh.position
		rows_ui[i].size = sh.size
	var d := _detail_rect()
	var bw := (d.size.x - 40.0 - 12.0) / 2.0
	var y := d.end.y - 20.0 - 44.0
	close_b.position = Vector2(d.position.x + 20.0, y)
	close_b.size = Vector2(d.size.x - 40.0, 44.0)
	y -= 56.0
	all_b.position = Vector2(d.position.x + 20.0, y)
	all_b.size = Vector2(d.size.x - 40.0, 44.0)
	y -= 74.0
	sell_b.position = Vector2(d.position.x + 20.0, y)
	sell_b.size = Vector2(bw, 44.0)
	list_b.position = Vector2(d.position.x + 20.0 + bw + 12.0, y)
	list_b.size = Vector2(bw, 44.0)
	_update_buttons()


# the card's buttons say what they do with the crate in hand
func _update_buttons() -> void:
	var part := selected()
	sell_b.visible = not part.is_empty()
	# only a sail roll can be listed: other crates get the whole row for selling
	list_b.visible = not part.is_empty() and (Repair.can_list(part) or part.has("listed"))
	var d := _detail_rect()
	sell_b.size.x = (d.size.x - 40.0 - 12.0) / 2.0 if list_b.visible else d.size.x - 40.0
	if not part.is_empty():
		if part.has("listed"):
			sell_b.text = w("挂牌中", "LISTED")
			sell_b.disabled = true
			list_b.text = w("撤牌", "WITHDRAW")
			list_b.disabled = false
			list_b.tooltip_text = ""
		else:
			sell_b.text = w("出售 %s  [Enter]", "SELL %s  [Enter]") % Pal.money(Repair.part_worth(part))
			sell_b.disabled = false
			list_b.disabled = false
			list_b.text = w("挂牌 %s  [L]", "LIST %s  [L]") % Pal.money(Repair.list_price(part))
			list_b.tooltip_text = w("卖给光帆厂：比直接出售高 8%，约 2 分钟成交，扣 2% 手续费", "To the sail-makers: 8 % over a direct sale, sells in about 2 min, 2 % fee")
	var total := _total()
	all_b.visible = total > 0.0
	all_b.text = (w("再按一次确认：全部出售 %s", "PRESS AGAIN TO SELL ALL %s") if confirm_all > 0.0 else Txt.t("rp_sell_all")) % Pal.money(total)


# ---------------------------------------------------------------- acts

func _say(s: String, ok: bool) -> void:
	message = s
	msg_ok = ok
	msg_t = 4.0


func _fly(text: String, col: Color) -> void:
	if sel_row < 0:
		return
	var cr := _crate_rect(sel_row, sel_col)
	cr.position += _shelf_rect(sel_row).position - Vector2(scroll[sel_row], 0.0)
	flyers.append({"rect": cr, "t": 0.0, "text": text, "col": col})


func _sell_sel() -> void:
	var part := selected()
	if part.is_empty():
		return
	var worth := Repair.part_worth(part)
	var why := Repair.sell(str(part.uid))
	if why != "":
		_say(why, false)
		if game != null:
			game.sfx.play("deny")
		return
	_fly("+" + Pal.money(worth), UiSkin.ACCENT)
	_say(w("%s 已出售：+%s", "%s SOLD: +%s") % [_part_name(part), Pal.money(worth)], true)
	if game != null:
		game.sfx.play("receipt")
	_refresh(true)


func _list_sel() -> void:
	var part := selected()
	if part.is_empty():
		return
	var on := not part.has("listed")
	var why := Repair.list_part(str(part.uid), on)
	if why != "":
		_say(why, false)
		if game != null:
			game.sfx.play("deny")
		return
	_fly(w("挂牌", "LISTED") if on else w("撤牌", "WITHDRAWN"), UiSkin.DATA)
	_say(w("%s 已挂牌，约 2 分钟卖出", "%s LISTED; SELLS IN ABOUT 2 MIN") % _part_name(part) if on else w("%s 已撤牌，放回架上", "%s WITHDRAWN") % _part_name(part), true)
	if game != null:
		game.sfx.play("ok" if on else "switch")
	_refresh(true)


# the whole rack at once: the first press asks, the second sells
func _sell_all() -> void:
	if confirm_all <= 0.0:
		confirm_all = CONFIRM_S
		_say(w("再按一次“全部出售”确认；挂牌中的光帆不卖。", "PRESS AGAIN TO CONFIRM; LISTED ROLLS STAY LISTED."), true)
		if game != null:
			game.sfx.play("switch")
		_update_buttons()
		return
	confirm_all = 0.0
	var n := 0
	for i in ROWS.size():
		for part in _row(i):
			if not part.has("listed"):
				n += 1
				var cr := _crate_rect(i, _row(i).find(part))
				cr.position += _shelf_rect(i).position - Vector2(scroll[i], 0.0)
				if _shelf_rect(i).intersects(cr):
					flyers.append({"rect": cr, "t": -0.03 * n, "text": "", "col": UiSkin.ACCENT})
	var got := Repair.sell_all()
	_say(Txt.t("rp_sold_all") % Pal.money(got), true)
	if game != null:
		game.sfx.play("receipt")
	_refresh(true)


func _select(i: int, k: int) -> void:
	if _row(i).is_empty():
		return
	var moved := i != sel_row or k != sel_col
	sel_row = i
	sel_col = clampi(k, 0, _row(i).size() - 1)
	# keep the chosen crate in view
	var cr := _crate_rect(sel_row, sel_col)
	var sw := _shelf_rect(sel_row).size.x
	if cr.position.x - 14.0 < scroll_to[sel_row]:
		scroll_to[sel_row] = maxf(0.0, cr.position.x - 14.0)
	elif cr.end.x + 14.0 > scroll_to[sel_row] + sw:
		scroll_to[sel_row] = minf(_max_scroll(sel_row), cr.end.x + 14.0 - sw)
	if moved and game != null:
		game.sfx.play("term")
	_update_buttons()


# ↑ ↓ to the shelf above or below that has crates, at about the same place along it
func _step_row(d: int) -> void:
	var i := sel_row
	var x: float = _crate_rect(maxi(sel_row, 0), sel_col).get_center().x - (float(scroll[sel_row]) if sel_row >= 0 else 0.0)
	for _n in ROWS.size():
		i += d
		if i < 0 or i >= ROWS.size():
			return
		if not _row(i).is_empty():
			var k := clampi(int(round((x + scroll[i] - 14.0 - _crate_w() * 0.5) / (_crate_w() + GAP))), 0, _row(i).size() - 1)
			_select(i, k)
			return


func _crate_at(i: int, p: Vector2) -> int:
	for k in _row(i).size():
		if _crate_rect(i, k).has_point(p + Vector2(scroll[i], 0.0)):
			return k
	return -1


func _row_input(ev: InputEvent, i: int) -> void:
	if ev is InputEventMouseMotion:
		var k := _crate_at(i, ev.position)
		hover = Vector2i(i, k) if k >= 0 else Vector2i(-1, -1)
	elif ev is InputEventMouseButton and ev.pressed:
		match ev.button_index:
			MOUSE_BUTTON_LEFT:
				var k := _crate_at(i, ev.position)
				if k >= 0:
					_select(i, k)
					if ev.double_click:
						_sell_sel()
			MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
				scroll_to[i] = minf(_max_scroll(i), scroll_to[i] + _crate_w())
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
				scroll_to[i] = maxf(0.0, scroll_to[i] - _crate_w())


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var used := true
	match event.physical_keycode:
		KEY_ESCAPE:
			close()
		KEY_LEFT, KEY_A:
			_select(sel_row, sel_col - 1)
		KEY_RIGHT, KEY_D:
			_select(sel_row, sel_col + 1)
		KEY_UP, KEY_W:
			_step_row(-1)
		KEY_DOWN, KEY_S:
			_step_row(1)
		KEY_ENTER, KEY_KP_ENTER:
			if not event.echo:
				_sell_sel()
		KEY_L:
			if not event.echo:
				_list_sel()
		_:
			used = false
	if used:
		get_viewport().set_input_as_handled()


func close() -> void:
	if on_close.is_valid():
		on_close.call()


func _process(dt: float) -> void:
	t += dt
	open_t += dt
	msg_t = maxf(0.0, msg_t - dt)
	if confirm_all > 0.0:
		confirm_all = maxf(0.0, confirm_all - dt)
		if confirm_all <= 0.0:
			_update_buttons()
	if fmod(t, 0.5) < dt:
		_refresh()
		_update_buttons()
	for i in ROWS.size():
		scroll_to[i] = clampf(scroll_to[i], 0.0, _max_scroll(i))
		scroll[i] = Pal.damp(scroll[i], scroll_to[i], 14.0, dt)
	if sel_row >= 0:
		var cr := _crate_rect(sel_row, sel_col)
		cr.position += _shelf_rect(sel_row).position
		frame = cr if frame.size == Vector2.ZERO else Rect2(Pal.damp2(frame.position, cr.position, 18.0, dt), Pal.damp2(frame.size, cr.size, 18.0, dt))
	for f in flyers:
		f.t = float(f.t) + dt
	flyers = flyers.filter(func(f): return float(f.t) < 1.1)
	queue_redraw()
	for r in rows_ui:
		r.queue_redraw()
	overlay.queue_redraw()


# ---------------------------------------------------------------- drawing

func _k(delay: float, span := 0.35) -> float:
	return Pal.ease_out(clampf((open_t - delay) / span, 0.0, 1.0))


func _text(s: String, p: Vector2, px: int, col: Color, f: Font = null, w_max := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(f if f != null else font, p, s, align, w_max, px, col)


func _draw() -> void:
	var a := _k(0.0, 0.25)
	# the berth behind, dimmed: the rack is what matters now
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.025, 0.03, a))
	draw_rect(Rect2(0, 0, size.x, 96), Color(0.0, 0.0, 0.0, 0.25 * a))
	# the header: the rack's name and where it stands, then what is on it
	var where := w("船坞 · 终端下面", "BERTH · UNDER THE TERMINAL") if Port.stage("cargo") < 1 else w("货运区 · 左边货架", "CARGO · LEFT RACKS")
	draw_rect(Rect2(PAD, 34, 4, 30), UiSkin.ACCENT * Color(1, 1, 1, a))
	_text(w("零件架", "PARTS RACK"), Vector2(PAD + 16, 60), 30, Pal.ink(0.97 * a), font_s)
	_text(where, Vector2(PAD + 16, 84), 14, Pal.ink(0.5 * a), font_b)
	var n := _count()
	var stats := [[w("零件", "PARTS"), "%d" % n], [w("估值", "WORTH"), Pal.money(_total())],
		[short_class("structure"), "%.1f t" % _plate_t()], [short_class("section"), "%.1f t" % _section_t()]]
	var x := size.x - PAD
	for s in range(stats.size() - 1, -1, -1):
		var vw := font_s.get_string_size(str(stats[s][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		var lw := font_b.get_string_size(str(stats[s][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var cw := maxf(vw, lw)
		_text(str(stats[s][0]), Vector2(x - cw, 46), 13, Pal.ink(0.5 * a), font_b)
		_text(str(stats[s][1]), Vector2(x - cw, 76), 24, (UiSkin.ACCENT if s == 1 else Pal.ink(0.95)) * Color(1, 1, 1, a), font_s)
		x -= cw + 36.0
		if s > 0:
			draw_line(Vector2(x + 18.0, 40), Vector2(x + 18.0, 80), Pal.ink(0.12 * a), 1.0)
	_draw_rack(_k(0.05, 0.4))
	_draw_bins(_k(0.12, 0.4))
	_draw_detail(_k(0.1, 0.4))
	# the keys along the foot
	var keys := w("← → ↑ ↓ 选货箱 · Enter 出售 · L 挂牌/撤牌 · 滚轮 左右翻这一层 · 双击 出售 · Esc 关闭", "← → ↑ ↓ PICK · ENTER SELL · L LIST · WHEEL SCROLLS THE SHELF · DOUBLE-CLICK SELLS · ESC CLOSE")
	_text(keys, Vector2(PAD, size.y - 26), 13, Pal.ink(0.45 * a), font_b)


# the steel: two punched uprights, the shelves' orange beams, a plate on the left for each shelf
func _draw_rack(a: float) -> void:
	if a <= 0.0:
		return
	var r := _rack_rect()
	r.position.y += (1.0 - a) * 16.0
	# the bay's back wall, a faint mesh
	var back := Rect2(r.position.x + POST, r.position.y + 10.0, r.size.x - POST * 2.0, r.size.y - 10.0)
	draw_rect(back, Color(0.035, 0.04, 0.046, 0.96 * a))
	var gx := back.position.x + 24.0
	while gx < back.end.x:
		draw_line(Vector2(gx, back.position.y), Vector2(gx, back.end.y), Color(1, 1, 1, 0.025 * a), 1.0)
		gx += 24.0
	var gy := back.position.y + 24.0
	while gy < back.end.y:
		draw_line(Vector2(back.position.x, gy), Vector2(back.end.x, gy), Color(1, 1, 1, 0.025 * a), 1.0)
		gy += 24.0
	# the uprights: a channel with its row of slots, a foot plate, a top cap
	for px in [r.position.x, r.end.x - POST]:
		var post := Rect2(px, r.position.y, POST, r.size.y)
		_steel(post, a)
		var sy := post.position.y + 14.0
		while sy < post.end.y - 14.0:
			draw_rect(Rect2(post.position.x + POST * 0.5 - 3.0, sy, 6.0, 9.0), Color(0.015, 0.018, 0.02, a))
			sy += 18.0
		draw_rect(Rect2(px - 6.0, r.end.y - 8.0, POST + 12.0, 8.0), Color(0.16, 0.17, 0.18, a))
		draw_rect(Rect2(px - 6.0, r.end.y - 8.0, POST + 12.0, 8.0), Pal.ink(0.4 * a), false, 1.0)
		draw_rect(Rect2(px - 2.0, r.position.y - 6.0, POST + 4.0, 8.0), Color(0.16, 0.17, 0.18, a))
	# each shelf: its beam, its plate, its count, the arrows when it runs on out of sight
	for i in ROWS.size():
		var sh := _shelf_rect(i)
		var k := _k(0.08 + i * 0.05, 0.35) * a
		var beam := Rect2(r.position.x + POST, sh.end.y, r.size.x - POST * 2.0, BEAM)
		_beam(beam, k)
		var cls: String = ROWS[i]
		var pl := Rect2(r.position.x + POST + 8.0, sh.position.y + 10.0, LABEL_W - 20.0, sh.size.y - 20.0)
		draw_rect(pl, Color(0.06, 0.065, 0.072, 0.95 * k))
		draw_rect(pl, Pal.ink(0.16 * k), false, 1.0)
		draw_rect(Rect2(pl.position, Vector2(3.0, pl.size.y)), _class_col(cls) * Color(1, 1, 1, k))
		_text("%02d" % (i + 1), pl.position + Vector2(14, 22), 12, Pal.ink(0.4 * k), font_b)
		draw_multiline_string(font_s, pl.position + Vector2(14, 44), short_class(cls), HORIZONTAL_ALIGNMENT_LEFT, pl.size.x - 22.0, 17, 2, Pal.ink(0.92 * k))
		var cnt := _row(i).size()
		_text(w("%d 件", "%d") % cnt if cnt > 0 else w("空", "EMPTY"), Vector2(pl.position.x + 14, pl.end.y - 12), 14, (Pal.ink(0.7 * k) if cnt > 0 else Pal.ink(0.35 * k)), font_b)
		if _max_scroll(i) > 1.0:
			if scroll[i] > 1.0:
				_chevron(Vector2(sh.position.x + 10.0, sh.get_center().y), -1, k)
			if scroll[i] < _max_scroll(i) - 1.0:
				_chevron(Vector2(sh.end.x - 10.0, sh.get_center().y), 1, k)
			# where along the shelf the view is
			var tr := Rect2(sh.position.x + 14.0, beam.end.y + 3.0, sh.size.x - 28.0, 2.0)
			draw_rect(tr, Pal.ink(0.08 * k))
			var fw := tr.size.x * sh.size.x / _content_w(i)
			draw_rect(Rect2(tr.position.x + (tr.size.x - fw) * scroll[i] / _max_scroll(i), tr.position.y, fw, 2.0), Pal.ink(0.4 * k))
	# the top beam
	_beam(Rect2(r.position.x + POST, r.position.y + 10.0, r.size.x - POST * 2.0, 8.0), a)


func _chevron(c: Vector2, d: int, a: float) -> void:
	var pts := PackedVector2Array([c + Vector2(-5.0 * d, -10), c + Vector2(5.0 * d, 0), c + Vector2(-5.0 * d, 10)])
	draw_polyline(pts, Color(UiSkin.ACCENT, (0.55 + 0.3 * sin(t * 4.0)) * a), 2.5, true)


func _steel(r: Rect2, a: float) -> void:
	draw_rect(r, Color(0.12, 0.128, 0.138, a))
	draw_rect(Rect2(r.position, Vector2(r.size.x * 0.3, r.size.y)), Color(1, 1, 1, 0.05 * a))
	draw_rect(Rect2(r.end.x - 3.0, r.position.y, 3.0, r.size.y), Color(0, 0, 0, 0.35 * a))
	draw_rect(r, Pal.ink(0.32 * a), false, 1.0)


# a box beam in the racking's orange: lit face, shadowed lip
func _beam(r: Rect2, a: float) -> void:
	draw_rect(r, Pal.heat(0.72 * a, 0.95))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0)), Color(1.0, 0.75, 0.55, 0.55 * a))
	draw_rect(Rect2(r.position.x, r.end.y - 3.0, r.size.x, 3.0), Color(0, 0, 0, 0.35 * a))
	draw_rect(Rect2(r.position.x, r.end.y, r.size.x, 6.0), Color(0, 0, 0, 0.22 * a))


func _class_col(cls: String) -> Color:
	match cls:
		"sail": return Color(UiSkin.DATA)
		"power": return Pal.heat(1.0, 1.15)
		"thermal": return Color(1.0, 0.78, 0.35)
		"drive": return Pal.tint(Pal.FLUID, 1.0, 1.1)
	return Pal.ink(0.8)


# a shelf's crates, clipped to the shelf
func _draw_row(ci: Control, i: int) -> void:
	var a := _k(0.12 + i * 0.05, 0.4)
	var parts := _row(i)
	if parts.is_empty():
		ci.draw_string(font_b, Vector2(18, ci.size.y * 0.5 + 6), w("空着。拆船时把完好的%s整件送进设备口，就会放到这一层。", "Empty. Deliver a whole %s to the equipment mouth and it lands here.") % short_class(ROWS[i]),
			HORIZONTAL_ALIGNMENT_LEFT, ci.size.x - 36.0, 14, Pal.ink(0.32 * a))
		return
	for k in parts.size():
		var cr := _crate_rect(i, k)
		cr.position.x -= scroll[i]
		if cr.end.x < -4.0 or cr.position.x > ci.size.x + 4.0:
			continue
		# they drop onto the shelf one after another when the rack opens
		var dk := _k(0.16 + i * 0.05 + mini(k, 8) * 0.035, 0.3)
		if dk <= 0.0:
			continue
		cr.position.y -= (1.0 - dk) * 24.0
		_crate(ci, cr, parts[k], dk, i == sel_row and k == sel_col, hover == Vector2i(i, k))
	# the selection frame, gliding from crate to crate
	if i == sel_row and frame.size != Vector2.ZERO:
		var fr := Rect2(frame.position - ci.position - Vector2(scroll[i], 0.0), frame.size).grow(5.0)
		var c := Color(UiSkin.ACCENT, 0.85 + 0.15 * sin(t * 5.0))
		var L := 14.0
		for corner in [[fr.position, Vector2(1, 1)], [Vector2(fr.end.x, fr.position.y), Vector2(-1, 1)], [Vector2(fr.position.x, fr.end.y), Vector2(1, -1)], [fr.end, Vector2(-1, -1)]]:
			var p: Vector2 = corner[0]
			var d: Vector2 = corner[1]
			ci.draw_line(p, p + Vector2(L * d.x, 0), c, 2.5)
			ci.draw_line(p, p + Vector2(0, L * d.y), c, 2.5)


# one crate: a lidded box with corner irons, its class band, the tag stencilled on, the
# part's name, condition bar (the repair threshold marked) and its price on a label
func _crate(ci: Control, r: Rect2, part: Dictionary, a: float, on: bool, hov: bool) -> void:
	var cls := str(part.get("cls", ""))
	var cond := clampf(float(part.get("cond", 0.0)), 0.0, 1.0)
	var usable := cond >= Repair.COND_MIN
	var listed := part.has("listed")
	if hov and not on:
		r.position.y -= 3.0
	var body := Color(0.2, 0.208, 0.22, a) if usable else Color(0.15, 0.155, 0.165, a)
	if on:
		body = body.lerp(Color(0.26, 0.27, 0.29, a), 0.7)
	# shadow on the shelf, the box, its top lit and its right side in shade
	ci.draw_rect(Rect2(r.position + Vector2(4, r.size.y - 3.0), Vector2(r.size.x - 4.0, 5.0)), Color(0, 0, 0, 0.4 * a))
	ci.draw_rect(r, body)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 9.0)), Color(1, 1, 1, 0.09 * a))
	ci.draw_rect(Rect2(r.end.x - 7.0, r.position.y, 7.0, r.size.y), Color(0, 0, 0, 0.22 * a))
	# the planks
	var py := r.position.y + 9.0 + (r.size.y - 9.0) / 3.0
	for _p in 2:
		ci.draw_line(Vector2(r.position.x + 2, py), Vector2(r.end.x - 2, py), Color(0, 0, 0, 0.28 * a), 1.0)
		py += (r.size.y - 9.0) / 3.0
	ci.draw_rect(r, Pal.ink((0.75 if on else 0.42) * a), false, 1.2)
	# corner irons
	for c in [r.position, Vector2(r.end.x - 10, r.position.y), Vector2(r.position.x, r.end.y - 10), r.end - Vector2(10, 10)]:
		ci.draw_rect(Rect2(c, Vector2(10, 10)), Color(0.42, 0.44, 0.46, a))
		ci.draw_rect(Rect2(c + Vector2(4, 4), Vector2(2, 2)), Color(0.1, 0.1, 0.1, a))
	# the class band down the left
	ci.draw_rect(Rect2(r.position.x + 10.0, r.position.y + 10.0, 3.0, r.size.y - 20.0), _class_col(cls) * Color(1, 1, 1, a * (1.0 if usable else 0.45)))
	# the stencil: its tag, big; the part's name small
	var inner := r.size.x - 34.0
	ci.draw_string(font_s, r.position + Vector2(20, 30), str(part.get("tag", "")), HORIZONTAL_ALIGNMENT_LEFT, inner, 20, Pal.ink((0.95 if usable else 0.55) * a))
	if r.size.y > 92.0:
		ci.draw_string(font_b, r.position + Vector2(20, 50), _part_name(part), HORIZONTAL_ALIGNMENT_LEFT, inner, 12, Pal.ink(0.62 * a))
	# what is inside, as a pictogram between the name and the bar
	var room := Rect2(r.position.x + 20.0, r.position.y + 58.0, inner, r.end.y - 44.0 - r.position.y - 58.0)
	if room.size.y >= 22.0:
		_glyph(ci, cls, room.get_center(), minf(room.size.y * 0.42, 26.0), _class_col(cls) * Color(1, 1, 1, (0.55 if usable else 0.25) * a))
	# the condition bar along the foot, the line a repair needs marked on it
	var bar := Rect2(r.position.x + 20.0, r.end.y - 34.0, inner, 4.0)
	ci.draw_rect(bar, Color(0, 0, 0, 0.5 * a))
	var bc := Color(UiSkin.DATA) if usable else Pal.heat(0.9, 1.1)
	ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * cond, bar.size.y)), bc * Color(1, 1, 1, a))
	var tx := bar.position.x + bar.size.x * Repair.COND_MIN
	ci.draw_line(Vector2(tx, bar.position.y - 3.0), Vector2(tx, bar.end.y + 3.0), Pal.ink(0.7 * a), 1.0)
	ci.draw_string(font_b, Vector2(bar.position.x, r.end.y - 13.0), "%d%%" % int(round(cond * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, (Pal.ink(0.8) if usable else Pal.heat(0.95, 1.2)) * Color(1, 1, 1, a))
	# the price, or what it is listed at and how long it has left
	var price := Pal.money(Repair.part_worth(part))
	var pc := Pal.ink(0.92 * a)
	if listed:
		price = "%d s" % int(ceil(Repair.LIST_T - float(part.listed.t)))
		pc = Color(UiSkin.DATA, a)
	ci.draw_string(font_s, Vector2(bar.position.x, r.end.y - 13.0), price, HORIZONTAL_ALIGNMENT_RIGHT, bar.size.x, 14, pc)
	if not usable:
		# a stamp across the lid: refurbish first
		var st := Rect2(r.end.x - 74.0, r.position.y + 14.0, 60.0, 18.0)
		ci.draw_rect(st, Pal.heat(0.2 * a, 1.0))
		ci.draw_rect(st, Pal.heat(0.8 * a, 1.1), false, 1.0)
		ci.draw_string(font_s, st.position + Vector2(0, 13), w("待翻新", "REFURB"), HORIZONTAL_ALIGNMENT_CENTER, st.size.x, 11, Pal.heat(0.95 * a, 1.3))
	if listed:
		# a sale tag hung on the crate, swinging a little
		var hook := Vector2(r.end.x - 26.0, r.position.y + 4.0)
		var sw := sin(t * 2.2) * 0.12
		var tag_c := hook + Vector2(sin(sw), cos(sw)) * 26.0
		ci.draw_line(hook, tag_c, Pal.ink(0.6 * a), 1.0)
		ci.draw_set_transform(tag_c, sw, Vector2.ONE)
		ci.draw_rect(Rect2(-22, 0, 44, 18), Color(UiSkin.DATA, 0.9 * a))
		ci.draw_string(font_s, Vector2(-22, 13), w("挂牌", "LISTED"), HORIZONTAL_ALIGNMENT_CENTER, 44, 11, Color(0.02, 0.05, 0.06, a))
		ci.draw_set_transform(Vector2.ZERO)


# a class's pictogram in thin line: a furled sail roll, a cell, cooling fins, a gear
func _glyph(ci: CanvasItem, cls: String, c: Vector2, s: float, col: Color) -> void:
	match cls:
		"sail":
			ci.draw_line(c + Vector2(-s * 1.4, -s * 0.45), c + Vector2(s * 1.2, -s * 0.45), col, 1.5, true)
			ci.draw_line(c + Vector2(-s * 1.4, s * 0.45), c + Vector2(s * 1.2, s * 0.45), col, 1.5, true)
			ci.draw_arc(c + Vector2(-s * 1.4, 0), s * 0.45, PI * 0.5, PI * 1.5, 16, col, 1.5, true)
			ci.draw_arc(c + Vector2(s * 1.2, 0), s * 0.45, 0, TAU, 20, col, 1.5, true)
			ci.draw_arc(c + Vector2(s * 1.2, 0), s * 0.18, 0, TAU, 12, col, 1.2, true)
			ci.draw_line(c + Vector2(s * 1.2, s * 0.45), c + Vector2(s * 1.9, s * 0.7), col, 1.2, true)
		"power":
			var b := Rect2(c - Vector2(s * 1.1, s * 0.55), Vector2(s * 2.0, s * 1.1))
			ci.draw_rect(b, col, false, 1.5)
			ci.draw_rect(Rect2(b.end.x, c.y - s * 0.22, s * 0.2, s * 0.44), col)
			ci.draw_line(c + Vector2(-s * 0.55, -s * 0.2), c + Vector2(-s * 0.55, s * 0.2), col, 1.5)
			ci.draw_line(c + Vector2(-s * 0.75, 0), c + Vector2(-s * 0.35, 0), col, 1.5)
			ci.draw_line(c + Vector2(s * 0.15, 0), c + Vector2(s * 0.55, 0), col, 1.5)
		"thermal":
			for k in 7:
				var fx := c.x - s * 1.2 + k * s * 0.4
				ci.draw_line(Vector2(fx, c.y - s * 0.6), Vector2(fx, c.y + s * 0.6), col, 1.3)
			ci.draw_line(Vector2(c.x - s * 1.4, c.y + s * 0.2), Vector2(c.x + s * 1.4, c.y + s * 0.2), col, 1.8)
			ci.draw_line(Vector2(c.x - s * 1.4, c.y - s * 0.2), Vector2(c.x + s * 1.4, c.y - s * 0.2), col, 1.8)
		"drive":
			var pts := PackedVector2Array()
			for k in 25:
				var ang := TAU * k / 24.0
				var rr := s * (0.62 if k % 3 == 0 else 0.48) if k % 3 != 2 else s * 0.62
				pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
			ci.draw_polyline(pts, col, 1.4, true)
			ci.draw_arc(c, s * 0.2, 0, TAU, 14, col, 1.4, true)


# the bottom bay: the hull-plate bin and the sections' cradle, heaped by the tonnes
func _draw_bins(a: float) -> void:
	if a <= 0.0:
		return
	var r := _rack_rect()
	var y0 := r.end.y - _bins_h()
	var x0 := r.position.x + POST + 10.0
	var wtot := r.size.x - POST * 2.0 - 20.0
	var bw := (wtot - 16.0) / 2.0
	var tons := [_plate_t(), _section_t()]
	for b in 2:
		var br := Rect2(x0 + b * (bw + 16.0), y0 + 12.0, bw, _bins_h() - 20.0)
		br.position.y += (1.0 - a) * 14.0
		# the bin: a steel tub, sloped ends
		var tub := PackedVector2Array([br.position + Vector2(0, 22), br.position + Vector2(12, br.size.y), Vector2(br.end.x - 12, br.end.y), Vector2(br.end.x, br.position.y + 22)])
		draw_colored_polygon(tub, Color(0.07, 0.075, 0.082, 0.96 * a))
		draw_polyline(tub, Pal.ink(0.45 * a), 1.5, true)
		var fill := clampf(log(1.0 + float(tons[b])) / log(1.0 + 60.0), 0.0, 1.0)
		var inside := Rect2(br.position.x + 16.0, br.position.y + 26.0, br.size.x - 32.0, br.size.y - 32.0)
		var h := inside.size.y * fill
		if b == 0:
			# plates, stacked flat, each a shade off the next
			var n := int(h / 5.0)
			for q in n:
				var py := inside.end.y - 5.0 * (q + 1)
				var inset := float((q * 7) % 13)
				draw_rect(Rect2(inside.position.x + inset, py, inside.size.x - 13.0, 4.0), Color(0.36 + 0.04 * (q % 3), 0.37 + 0.04 * (q % 3), 0.39 + 0.04 * (q % 3), a))
		else:
			# sections, I-beams end on, in a bundle
			var cols := int(inside.size.x / 26.0)
			var layers := int(h / 22.0)
			for l in layers:
				for c in cols:
					var ip := Vector2(inside.position.x + 4.0 + c * 26.0 + (l % 2) * 6.0, inside.end.y - 22.0 * (l + 1))
					if ip.x + 20.0 > inside.end.x:
						continue
					var ic := Color(0.42, 0.43, 0.45, a)
					draw_rect(Rect2(ip, Vector2(20, 3)), ic)
					draw_rect(Rect2(ip + Vector2(8.5, 3), Vector2(3, 14)), ic)
					draw_rect(Rect2(ip + Vector2(0, 17), Vector2(20, 3)), ic)
		var name := short_class("structure") if b == 0 else short_class("section")
		_text(name, br.position + Vector2(18, 16), 15, Pal.ink(0.85 * a), font_s)
		var tt := "%.1f t" % float(tons[b])
		_text(tt, Vector2(br.position.x, br.position.y + 16), 16, (Pal.ink(0.95) if float(tons[b]) > 0.05 else Pal.ink(0.35)) * Color(1, 1, 1, a), font_s, br.size.x - 18.0, HORIZONTAL_ALIGNMENT_RIGHT)
		if float(tons[b]) <= 0.05:
			_text(w("空的 · 修船坞设施用得上", "EMPTY · USED BY BERTH REPAIRS"), br.get_center() + Vector2(-br.size.x * 0.5, 16), 13, Pal.ink(0.32 * a), font_b, br.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	# the floor line under the rack
	draw_line(Vector2(r.position.x - 10.0, r.end.y), Vector2(r.end.x + 10.0, r.end.y), Pal.ink(0.35 * a), 2.0)


# the card on the right: the crate in hand, large, and what it is
func _draw_detail(a: float) -> void:
	if a <= 0.0:
		return
	var d := _detail_rect()
	d.position.x += (1.0 - a) * 24.0
	Hmi.raised(self, d, a)
	var part := selected()
	var x := d.position.x + 24.0
	var y := d.position.y + 40.0
	var wmax := d.size.x - 48.0
	if part.is_empty():
		_text(w("架子空着", "THE RACK IS EMPTY"), Vector2(x, y), 22, Pal.ink(0.9 * a), font_s)
		draw_multiline_string(font_b, Vector2(x, y + 34), w("拆船时把完好的设备整件送进设备口，它就会装箱放到这里：修船坞设施用得上，也可以卖。", "Deliver a whole piece of equipment to the equipment mouth and it is crated here: for the berth's repairs, or to sell."), HORIZONTAL_ALIGNMENT_LEFT, wmax, 15, 4, Pal.ink(0.6 * a))
	else:
		var cls := str(part.get("cls", ""))
		var cond := clampf(float(part.get("cond", 0.0)), 0.0, 1.0)
		var usable := cond >= Repair.COND_MIN
		draw_rect(Rect2(x, y - 14, 3, 16), _class_col(cls) * Color(1, 1, 1, a))
		_text(short_class(cls), Vector2(x + 12, y), 13, Pal.ink(0.55 * a), font_b)
		_text(str(part.get("tag", "")), Vector2(x, y + 40), 32, Pal.ink(0.97 * a), font_s, wmax)
		draw_multiline_string(font_b, Vector2(x, y + 68), _part_name(part), HORIZONTAL_ALIGNMENT_LEFT, wmax, 16, 2, Pal.ink(0.75 * a))
		y += 112.0
		var ship := _ship_name(str(part.get("ship", "")))
		var rows := [[w("来源", "FROM"), ("%s · %s" % [ship, str(part.get("job", ""))]) if ship != "" else str(part.get("job", ""))],
			[w("价值", "WORTH"), Pal.money(Repair.part_worth(part))]]
		if part.has("listed"):
			rows.append([w("挂牌", "LISTED"), w("%s · 还剩 %d 秒", "%s · %d s LEFT") % [Pal.money(float(part.listed.ask)), int(ceil(Repair.LIST_T - float(part.listed.t)))]])
		for rw in rows:
			draw_line(Vector2(x, y - 20), Vector2(x + wmax, y - 20), Pal.ink(0.08 * a), 1.0)
			_text(str(rw[0]), Vector2(x, y), 13, Pal.ink(0.5 * a), font_b)
			_text(str(rw[1]), Vector2(x + 64, y), 15, Pal.ink(0.9 * a), font_s, wmax - 64.0)
			y += 34.0
		# the condition, a gauge with the repair line on it
		draw_line(Vector2(x, y - 20), Vector2(x + wmax, y - 20), Pal.ink(0.08 * a), 1.0)
		_text(w("成色", "CONDITION"), Vector2(x, y), 13, Pal.ink(0.5 * a), font_b)
		_text("%d%%" % int(round(cond * 100.0)), Vector2(x, y), 22, (Pal.ink(0.95) if usable else Pal.heat(0.95, 1.2)) * Color(1, 1, 1, a), font_s, wmax, HORIZONTAL_ALIGNMENT_RIGHT)
		var g := Rect2(x, y + 14.0, wmax, 8.0)
		draw_rect(g, Color(0, 0, 0, 0.45 * a))
		draw_rect(Rect2(g.position, Vector2(g.size.x * cond, g.size.y)), (Color(UiSkin.DATA) if usable else Pal.heat(0.9, 1.1)) * Color(1, 1, 1, a))
		var tx := g.position.x + g.size.x * Repair.COND_MIN
		draw_line(Vector2(tx, g.position.y - 4.0), Vector2(tx, g.end.y + 4.0), Pal.ink(0.8 * a), 1.5)
		_text(w("修缮线 %d%%", "REPAIR LINE %d%%") % int(Repair.COND_MIN * 100.0), Vector2(tx - 40.0, g.end.y + 20.0), 12, Pal.ink(0.5 * a), font_b)
		y += 58.0
		var note := w("够修缮线：修船坞设施时会自动用上它，也可以卖。", "Over the repair line: a berth repair takes it, or sell it.") if usable else Txt.t("rp_cond_note") % int(Repair.COND_MIN * 100.0)
		draw_multiline_string(font_b, Vector2(x, y), note, HORIZONTAL_ALIGNMENT_LEFT, wmax, 14, 3, (Pal.ink(0.6) if usable else Pal.heat(0.85, 1.2)) * Color(1, 1, 1, a))
		# where a crate like this goes: the open repairs that take its class, and how many each wants
		var uses := _uses(cls) if usable else []
		y += 54.0
		if not uses.is_empty() and y + 40.0 < sell_b.position.y - 40.0:
			_text(w("能用在", "GOES INTO"), Vector2(x, y), 13, Pal.ink(0.5 * a), font_b)
			draw_line(Vector2(x + 60, y - 5), Vector2(x + wmax, y - 5), Pal.ink(0.08 * a), 1.0)
			y += 28.0
			for u in uses:
				if y > sell_b.position.y - 46.0:
					break
				var ready: bool = u.missing <= 0
				Hmi.lamp(self, Vector2(x + 6, y - 5), Hmi.ok_col() if ready else Hmi.warn_col(), true, a, 4.0)
				_text(str(u.name), Vector2(x + 20, y), 15, Pal.ink(0.9 * a), font_s, wmax - 150.0)
				var need := w("要 %d 件 · 已够", "%d · ENOUGH") % int(u.want) if ready else w("要 %d 件 · 还缺 %d", "%d · %d SHORT") % [int(u.want), int(u.missing)]
				_text(need, Vector2(x, y), 13, (Pal.ink(0.55) if ready else Color(UiSkin.ACCENT)) * Color(1, 1, 1, a), font_b, wmax, HORIZONTAL_ALIGNMENT_RIGHT)
				y += 28.0
		elif usable:
			_text(w("眼下没有要这一类零件的修缮，可以放心卖。", "No open repair takes this class now: safe to sell."), Vector2(x, y), 14, Pal.ink(0.5 * a), font_b, wmax)
			y += 28.0
		# the crate itself, larger, in what room is left
		var room := sell_b.position.y - 56.0 - y
		if room > 150.0:
			var cw := minf(wmax * 0.72, room * 1.25)
			var ch := minf(room - 20.0, cw * 0.72)
			var cr := Rect2(x + (wmax - cw) * 0.5, y + (room - ch) * 0.5, cw, ch)
			draw_rect(Rect2(cr.position.x - 16.0, cr.end.y, cw + 32.0, 6.0), Pal.heat(0.6 * a, 0.95))
			_crate(self, cr, part, a, false, false)
	# what was just done
	if msg_t > 0.0 and message != "":
		var my := sell_b.position.y - 24.0 if sell_b.visible else all_b.position.y - 24.0
		_text(message, Vector2(x, my), 14, (Color(UiSkin.ACCENT) if msg_ok else Pal.heat(1.0, 1.3)) * Color(1, 1, 1, a * clampf(msg_t, 0.0, 1.0)), font_b, wmax)


# the open repairs that take a class: {name, want, missing}, the nearest first (cached with the shelf)
var _uses_cache := {}
var _uses_sig := ""


func _uses(cls: String) -> Array:
	if _uses_sig != _sig:
		_uses_sig = _sig
		_uses_cache.clear()
	if _uses_cache.has(cls):
		return _uses_cache[cls]
	var out: Array = []
	for it in Repair.open_items():
		var item := Repair.find(str(it.id))
		var needs: Dictionary = item[2]
		if not needs.has(cls):
			continue
		var pf := Repair.parts_for(str(it.id))
		out.append({"name": Repair.name_of(str(it.id)), "want": int(needs[cls]), "missing": int(pf.missing.get(cls, 0))})
	_uses_cache[cls] = out
	return out


# the crates just sold rise and fade, their price over them
func _draw_overlay() -> void:
	for f in flyers:
		var k := clampf(float(f.t), 0.0, 1.0)
		if float(f.t) < 0.0:
			continue
		var r: Rect2 = f.rect
		var e := Pal.ease_out(k)
		var rr := Rect2(r.position + Vector2(0, -40.0 * e), r.size)
		overlay.draw_rect(rr, Color(f.col, 0.35 * (1.0 - k)))
		overlay.draw_rect(rr.grow(6.0 * e), Color(f.col, 0.8 * (1.0 - k)), false, 2.0)
		if str(f.text) != "":
			overlay.draw_string(font_s, rr.position + Vector2(0, rr.size.y * 0.5), str(f.text), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 22, Color(f.col, 1.0 - k * k))
