extends Control
# 106 号: the settlement's second page — where the recovered goods go (scripts/disposal.gd is the
# authority: the ingots as one batch sold or kept to be processed, each whole piece of equipment
# sold or kept on the rack).
# 119 号 (user 2026-11-04, with the extraction screens of a looter shooter: "这个回收屋现在应该显示的
# 是我的仓库还有我当前的设备。右边是我的仓库，左边是我当前的设备" — 问答全按推荐): a page of its own,
# full screen, reached from the settlement sheet's "next". Left, what the drone brought home: R-02
# and the gear it took out (what did not come back in red, with why), under it this contract's
# goods as cards waiting to be put away. Right, the company's warehouse, three tabs down its edge:
# the eight rows of racks, the parts rack, the gear shelf; what is put away lands on its row, marked
# new. A card clicked or dragged to the right is kept, its "sell" (or a drag to the sale strip under
# the cards) sells it; "move all", "sell all"; what is left on the left when the page is confirmed
# is kept — nothing is lost. Everything moves back until confirmed (click it, or Ctrl+Z).
# Enter confirms and leaves the berth; Esc goes back to the sheet with nothing changed.
# Keys: 1 sell the ingots · 2 keep them · T move all · X sell all · Tab the next shelf · Ctrl+Z undo.

const PartsRack = preload("res://scripts/parts_rack_panel.gd")
const Exchange = preload("res://scripts/industrial_exchange.gd")
const DroneArt = preload("res://scripts/drone_art.gd")

const M := 40.0                      # the page's margin
const HEAD_H := 104.0
const FOOT_H := 92.0
const TAB_W := 76.0
const GAP := 14.0
const CARD_H := 176.0
const TABS := ["rack", "parts", "gear"]

var game
var on_done: Callable                # called after a confirmed save
var on_back: Callable
var metal := "keep"                  # what the page will save: kept unless the ingots are on the sale strip
var sell := {}                       # uid -> true when sold
var d: Dictionary
var want: Dictionary
var items: Array = []                # {id, kind, place, part?, t?, value?, vr: Rect2 (where it is drawn now)}
var tab := "rack"
var history: Array = []              # [id, place before]
var message := ""
var _msg_t := 0.0
var hover_id := ""
var hover_btn := ""
var _press_id := ""
var _press_at := Vector2.ZERO
var dragging := ""
var _drag_off := Vector2.ZERO
var _t := 0.0
var _rects := {}                     # id -> target rect this frame
var _btns := {}                      # name -> Rect2
var _wh_hits := {}                   # id -> rect of a new thing on the warehouse side (click: back)
var font: Font
var font_b: Font
var font_s: Font
var _gear_back: Array = []           # types that came home
var _gear_lost: Array = []           # [type, why key]
var _integrity := 100.0
var _fluid := 0.0
# 2026-11-04 (user: "上下滚动"): the cards still to sort scroll when they outgrow their column
# (a GR-7 job brings twelve), instead of running into the sale strip
var scroll := 0.0
var _bar_drag := -1.0                # the scrollbar's thumb held: where on it it was grabbed
var _clip: Control                   # the cards still to sort, drawn clipped to their view
var _over: Control                   # the card being dragged, over everything
const WHEEL := 95.0


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
	font_s = Fonts.get_font("SemiBold")
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.draw.connect(_draw_clipped)
	add_child(_clip)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.draw.connect(_draw_over)
	add_child(_over)
	d = Disposal.pending()
	want = Disposal.wanted()
	metal = "keep"
	var t := float(d.get("ingot_t", 0.0))
	if t > 0.0005:
		items.append({"id": "ingot", "kind": "ingot", "place": "left", "t": t})
	for part in Disposal.parts():
		var uid := str(part.uid)
		sell[uid] = false
		items.append({"id": uid, "kind": "part", "place": "left", "part": part})
	_read_run()
	if _fluid > 0.5:
		items.append({"id": "fluid", "kind": "fluid", "place": "fixed", "value": _fluid})
	# the shelf the first thing to put away goes to
	tab = "rack" if t > 0.0005 else "parts"
	_layout()
	for it in items:
		it.vr = _rects.get(it.id, Rect2())


# what the drone and its gear came home as (the run, not the books: the books have only the types)
func _read_run() -> void:
	if game == null:
		return
	if game.get("drone") != null and is_instance_valid(game.drone):
		_integrity = clampf(float(game.drone.integrity), 0.0, 100.0)
	var g = game.get("gear")
	if g != null and is_instance_valid(g):
		var rep: Dictionary = g.settlement_report()
		for b in rep.get("back", []):
			_gear_back.append(str(b.type))
		for l in rep.get("lost", []):
			_gear_lost.append([str(l.type), str(l.get("why", ""))])
	else:
		var cr: Dictionary = game.get("career_result") if game.get("career_result") != null else {}
		for ty in cr.get("gear", {}).get("back", []):
			_gear_back.append(str(ty))
		for ty in cr.get("gear", {}).get("lost", []):
			_gear_lost.append([str(ty), ""])
	if game.get("sys") != null and game.has_method("scope") and game.scope() == "full":
		_fluid = float(game.sys.gas_value()) + float(game.sys.fluid_value())


# ---------------------------------------------------------------- the choices

func _item(id: String) -> Dictionary:
	for it in items:
		if str(it.id) == id:
			return it
	return {}


func movable(it: Dictionary) -> bool:
	return str(it.get("kind", "")) in ["ingot", "part"]


func tab_of(it: Dictionary) -> String:
	return "rack" if str(it.kind) == "ingot" else "parts"


# put a thing where it goes: "left" (not yet put away), "wh" (kept), "sold"
func move(id: String, place: String, record := true) -> void:
	var it := _item(id)
	if it.is_empty() or not movable(it) or str(it.place) == place:
		return
	if record:
		history.append([id, str(it.place)])
	it.place = place
	if place == "wh":
		tab = tab_of(it)
	_sync()
	match place:
		"wh":
			_say(_kept_line(it))
		"sold":
			_say(w("卖掉：%s  +%s", "SOLD: %s  +%s") % [_name(it), Pal.money(_price(it))])
		"left":
			_say(w("放回待整理：%s", "BACK TO SORT: %s") % _name(it))


func _sync() -> void:
	metal = "keep"
	for it in items:
		if str(it.kind) == "ingot" and str(it.place) == "sold":
			metal = "sell"
		elif str(it.kind) == "part":
			sell[str(it.id)] = str(it.place) == "sold"


func move_all(place: String) -> void:
	var n := 0
	for it in items:
		if movable(it) and str(it.place) == "left":
			history.append([str(it.id), "left"])
			it.place = place
			n += 1
	_sync()
	if n == 0:
		_say(w("左边已经没有待整理的东西。", "NOTHING LEFT TO SORT."))
	elif place == "wh":
		_say(w("%d 样全部入库。", "%d PUT AWAY.") % n)
	else:
		_say(w("%d 样全部卖出：现在到账 %s。", "%d SOLD: %s NOW.") % [n, Pal.money(cash_now())])


func undo() -> void:
	if history.is_empty():
		_say(w("没有可以撤销的操作。", "NOTHING TO UNDO."))
		return
	var h: Array = history.pop_back()
	var it := _item(str(h[0]))
	if it.is_empty():
		return
	it.place = str(h[1])
	_sync()
	_say(w("撤销：%s 回到%s", "UNDONE: %s") % ([_name(it), _place_name(str(h[1]))] if Txt.zh else [_name(it)]))


# old callers (tests, recordings): the metal sold or kept, a part sold or kept
func _metal(v: String) -> void:
	move("ingot", "sold" if v == "sell" else "wh")


func _part(uid: String, sold: bool) -> void:
	move(uid, "sold" if sold else "wh")


func sold_uids() -> Array:
	var out: Array = []
	for uid in sell:
		if sell[uid]:
			out.append(uid)
	return out


func cash_now() -> float:
	var cash := 0.0
	for it in items:
		if str(it.place) == "sold":
			cash += _price(it)
	return cash


func left_n() -> int:
	var n := 0
	for it in items:
		if movable(it) and str(it.place) == "left":
			n += 1
	return n


func confirm() -> void:
	var left := left_n()
	var r := Disposal.apply(metal, sold_uids())
	if not r.ok:
		_say(w("保存失败，什么都没卖：再按一次确认。", "Save failed, nothing sold: confirm again."))
		return
	if left > 0:
		_say(w("剩下的 %d 样已自动入库。", "THE %d LEFT WERE PUT AWAY.") % left)
	on_done.call()


func _say(s: String) -> void:
	message = s
	_msg_t = 4.0


# ---------------------------------------------------------------- what things are called and worth

func _name(it: Dictionary) -> String:
	match str(it.kind):
		"ingot":
			return w("钢锭 %.1f t", "INGOTS %.1f t") % float(it.t)
		"part":
			var p: Dictionary = it.part
			var nk := str(p.get("nk", ""))
			return "%s %s" % [str(p.get("tag", "")), Txt.t(nk) if nk != "" and Txt.has(nk) else ""]
		"fluid":
			return w("气体与流体", "GAS AND FLUIDS")
	return ""


func _price(it: Dictionary) -> float:
	match str(it.kind):
		"ingot":
			return Disposal.sell_cash(d)
		"part":
			return Repair.part_worth(it.part)
	return 0.0


func _place_name(p: String) -> String:
	return {"left": w("待整理", "TO SORT"), "wh": w("仓库", "THE WAREHOUSE"), "sold": w("卖出", "THE SALE")}.get(p, p)


func _kept_line(it: Dictionary) -> String:
	if str(it.kind) == "ingot":
		var row := Warehouse.row_for(Exchange.INGOT)
		var kv: Dictionary = Disposal.keep_value(d)
		var then := w("之后送加工区炼成约 %.1f t 钢坯", "then to processing: about %.1f t of billet") % float(kv.billet_t)
		if Port.stage("process") < 1:
			then = w("加工区修好后自动加工", "processed once the district is mended")
		return w("入库：钢锭 %.1f t → %s %s · %s", "KEPT: INGOTS %.1f t → %s %s · %s") % [float(it.t), Warehouse.ROWS[row], Warehouse.use_name(str(Warehouse.rows()[row])), then]
	return w("入库：%s → 零件架", "KEPT: %s → THE PARTS RACK") % _name(it)


# why a card is worth keeping or selling, in a line
func _hint(it: Dictionary) -> String:
	match str(it.kind):
		"ingot":
			var kv: Dictionary = Disposal.keep_value(d)
			return w("入库加工：钢坯约 %s（电费约 %s）", "KEEP: BILLET ABOUT %s (POWER %s)") % [Pal.money(float(kv.value)), Pal.money(float(kv.power))]
		"part":
			return Disposal.part_note(it.part, want, true)
		"fluid":
			return w("已按合同交付，钱已到账", "DELIVERED WITH THE CONTRACT, PAID")
	return ""


# ---------------------------------------------------------------- layout

func _left_rect() -> Rect2:
	var s := size
	return Rect2(M, HEAD_H, floorf((s.x - M * 2.0) * 0.4), s.y - HEAD_H - FOOT_H - 12.0)


func _right_rect() -> Rect2:
	var s := size
	var lr := _left_rect()
	var x := lr.end.x + 36.0
	return Rect2(x, HEAD_H, s.x - M - TAB_W - 10.0 - x, lr.size.y)


func _sale_rect() -> Rect2:
	var lr := _left_rect()
	return Rect2(lr.position.x, size.y - FOOT_H, lr.size.x, FOOT_H - 22.0)


func _cards_top() -> float:
	return _left_rect().position.y + 214.0


func _card_w() -> float:
	return floorf((_left_rect().size.x - GAP * 2.0) / 3.0)


# where the cards still to sort are seen: between their heading and the line under them
func _view_rect() -> Rect2:
	var lr := _left_rect()
	var top := _cards_top() - 6.0
	return Rect2(lr.position.x - 4.0, top, lr.size.x + 8.0, lr.end.y - 26.0 - top)


func _grid_h() -> float:
	var k := 0
	for it in items:
		if str(it.place) in ["left", "fixed"]:
			k += 1
	return maxf(0.0, ceilf(k / 3.0) * (CARD_H + GAP) - GAP)


func _scroll_max() -> float:
	return maxf(0.0, _grid_h() + 12.0 - _view_rect().size.y)


func _bar_track() -> Rect2:
	var v := _view_rect()
	return Rect2(v.end.x + 6.0, v.position.y + 6.0, 5.0, v.size.y - 12.0)


func _bar_thumb() -> Rect2:
	var tr := _bar_track()
	var mx := _scroll_max()
	var h := maxf(40.0, tr.size.y * _view_rect().size.y / (_grid_h() + 12.0))
	return Rect2(tr.position.x, tr.position.y + (tr.size.y - h) * (scroll / mx if mx > 0.0 else 0.0), tr.size.x, h)


func scroll_by(dy: float) -> void:
	scroll = clampf(scroll + dy, 0.0, _scroll_max())


func _layout() -> void:
	_rects.clear()
	_btns.clear()
	_wh_hits.clear()
	var lr := _left_rect()
	var cw := _card_w()
	scroll = clampf(scroll, 0.0, _scroll_max())
	# the cards still to sort, in a grid that scrolls
	var k := 0
	for it in items:
		if str(it.place) in ["left", "fixed"]:
			_rects[it.id] = Rect2(lr.position.x + (k % 3) * (cw + GAP), _cards_top() - scroll + floorf(k / 3.0) * (CARD_H + GAP), cw, CARD_H)
			k += 1
	# the sale strip: one chip a thing sold, narrower as more are sold so all stay on the strip
	var sr := _sale_rect()
	var n_sold := 0
	for it in items:
		if str(it.place) == "sold":
			n_sold += 1
	var chip := clampf((sr.size.x - 24.0 - (n_sold - 1) * 10.0) / maxf(1.0, n_sold), 24.0, 168.0)
	var j := 0
	for it in items:
		if str(it.place) == "sold":
			_rects[it.id] = Rect2(sr.position.x + 12.0 + j * (chip + 10.0), sr.position.y + 30.0, chip, 32.0)
			j += 1
	# the warehouse side: new things on their shelf, the others flying to their tab
	var rr := _right_rect()
	var tr := _tab_rects()
	for i in TABS.size():
		_btns["tab_" + TABS[i]] = tr[i]
	if tab == "rack":
		var ingot := _item("ingot")
		if not ingot.is_empty() and str(ingot.place) == "wh":
			var row := Warehouse.row_for(Exchange.INGOT)
			var rc := _row_rect(row)
			_rects["ingot"] = Rect2(rc.position.x + 14.0, rc.end.y - 46.0, rc.size.x - 28.0, 34.0)
	elif tab == "parts":
		var n := 0
		for it in items:
			if str(it.kind) == "part" and str(it.place) == "wh":
				_rects[it.id] = _crate_rect(n)
				n += 1
	for it in items:
		if str(it.place) == "wh" and not _rects.has(it.id):
			var ti := TABS.find(tab_of(it))
			_rects[it.id] = Rect2(tr[ti].get_center() - Vector2(18, 12), Vector2(36, 24))
		elif str(it.place) == "wh":
			_wh_hits[it.id] = _rects[it.id]
	# the buttons along the foot, on the warehouse side
	var bx := rr.end.x + TAB_W + 10.0
	var by := size.y - FOOT_H + 4.0
	for b in [["confirm", 300.0], ["back", 170.0], ["sell_all", 150.0], ["move_all", 150.0]]:
		bx -= float(b[1])
		_btns[b[0]] = Rect2(bx, by, float(b[1]) - 10.0, 52.0)
	# the ingots' own two choices on their card (1 / 2), a part's sale: only where it is seen whole
	var view := _view_rect()
	for it in items:
		if movable(it) and str(it.place) == "left":
			var r: Rect2 = _rects[it.id]
			var sb := Rect2(r.end.x - 108.0, r.end.y - 40.0, 96.0, 30.0)
			if view.encloses(sb):
				_btns["sell:" + str(it.id)] = sb


func _tab_rects() -> Array:
	var rr := _right_rect()
	var out: Array = []
	for i in TABS.size():
		out.append(Rect2(rr.end.x + 10.0, rr.position.y + 48.0 + i * 104.0, TAB_W, 96.0))
	return out


func _row_rect(i: int) -> Rect2:
	var rr := _right_rect()
	var top := rr.position.y + 48.0
	var cw := floorf((rr.size.x - GAP) / 2.0)
	var ch := floorf((rr.size.y - 48.0 - GAP * 3.0) / 4.0)
	return Rect2(rr.position.x + (i / 4) * (cw + GAP), top + (i % 4) * (ch + GAP), cw, ch)


func _crate_rect(n: int) -> Rect2:
	var rr := _right_rect()
	var cols := 4
	var cw := floorf((rr.size.x - GAP * (cols - 1)) / cols)
	return Rect2(rr.position.x + (n % cols) * (cw + GAP), rr.position.y + 48.0 + floorf(n / float(cols)) * (CARD_H + GAP), cw, CARD_H)


func _parts_cap() -> int:
	var rr := _right_rect()
	return 4 * maxi(1, int((rr.size.y - 48.0 + GAP) / (CARD_H + GAP)))


# ---------------------------------------------------------------- the frame

func _process(dt: float) -> void:
	_t += dt
	_msg_t = maxf(0.0, _msg_t - dt)
	_layout()
	var k := 1.0 - exp(-dt * 16.0)
	for it in items:
		if str(it.id) == dragging:
			continue
		var to: Rect2 = _rects.get(it.id, it.vr)
		var vr: Rect2 = it.vr
		it.vr = Rect2(vr.position.lerp(to.position, k), vr.size.lerp(to.size, k))
	if dragging != "":
		var it := _item(dragging)
		var mp := get_local_mouse_position()
		it.vr = Rect2(mp - _drag_off, Vector2(_card_w(), CARD_H))
	var view := _view_rect()
	_clip.position = view.position
	_clip.size = view.size
	_clip.queue_redraw()
	_over.queue_redraw()
	queue_redraw()


func _at(p: Vector2) -> String:
	for it in items:
		if movable(it) and str(it.place) in ["left", "sold"] and (_rects.get(it.id, Rect2()) as Rect2).has_point(p):
			if str(it.place) == "left" and not _view_rect().has_point(p):
				continue
			return str(it.id)
	for id in _wh_hits:
		if (_wh_hits[id] as Rect2).has_point(p):
			return str(id)
	return ""


func _btn_at(p: Vector2) -> String:
	for b in _btns:
		if (_btns[b] as Rect2).has_point(p):
			return str(b)
	return ""


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and _bar_drag >= 0.0:
		var tr := _bar_track()
		var th := _bar_thumb()
		var span := tr.size.y - th.size.y
		if span > 0.0:
			scroll = clampf((ev.position.y - _bar_drag - tr.position.y) / span, 0.0, 1.0) * _scroll_max()
		accept_event()
	elif ev is InputEventMouseMotion:
		var p: Vector2 = ev.position
		hover_btn = _btn_at(p)
		hover_id = "" if hover_btn.begins_with("sell:") else _at(p)
		if _press_id != "" and dragging == "" and p.distance_to(_press_at) > 6.0:
			var it := _item(_press_id)
			if str(it.place) == "left":
				dragging = _press_id
				_drag_off = Vector2(_card_w(), CARD_H) * 0.5
		accept_event()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if _left_rect().has_point(ev.position) or _bar_track().grow(10.0).has_point(ev.position):
			scroll_by(WHEEL * (1.0 if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0))
		accept_event()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed and _bar_drag >= 0.0:
		_bar_drag = -1.0
		accept_event()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = ev.position
		if ev.pressed and _scroll_max() > 0.0 and _bar_track().grow_individual(8.0, 0.0, 8.0, 0.0).has_point(p):
			# the scrollbar: held by the thumb, or the thumb jumps to the click
			var th := _bar_thumb()
			if th.grow_individual(8.0, 0.0, 8.0, 0.0).has_point(p):
				_bar_drag = p.y - th.position.y
			else:
				_bar_drag = th.size.y * 0.5
				var tr := _bar_track()
				scroll = clampf((p.y - _bar_drag - tr.position.y) / maxf(1.0, tr.size.y - th.size.y), 0.0, 1.0) * _scroll_max()
			accept_event()
			return
		if ev.pressed:
			var b := _btn_at(p)
			if b != "":
				_press_btn(b)
			else:
				_press_id = _at(p)
				_press_at = p
		else:
			if dragging != "":
				var place := "left"
				if _right_rect().grow(20.0).has_point(p) or p.x > _right_rect().position.x:
					place = "wh"
				elif _sale_rect().grow(16.0).has_point(p):
					place = "sold"
				var id := dragging
				dragging = ""
				move(id, place)
			elif _press_id != "" and _at(p) == _press_id:
				var it := _item(_press_id)
				# a card on the left: put away; anything else: back to sort
				move(_press_id, "wh" if str(it.place) == "left" else "left")
			_press_id = ""
		accept_event()


func _press_btn(b: String) -> void:
	if b.begins_with("tab_"):
		tab = b.substr(4)
	elif b.begins_with("sell:"):
		move(b.substr(5), "sold")
	else:
		match b:
			"confirm": confirm()
			"back": on_back.call()
			"move_all": move_all("wh")
			"sell_all": move_all("sold")


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	if ev.keycode == KEY_Z and ev.ctrl_pressed:
		undo()
		get_viewport().set_input_as_handled()
		return
	match ev.keycode:
		KEY_ESCAPE:
			on_back.call()
		KEY_ENTER, KEY_KP_ENTER:
			confirm()
		KEY_1:
			_metal("sell")
		KEY_2:
			_metal("keep")
		KEY_T:
			move_all("wh")
		KEY_X:
			move_all("sold")
		KEY_TAB:
			tab = TABS[(TABS.find(tab) + 1) % TABS.size()]
		KEY_PAGEDOWN:
			scroll_by(_view_rect().size.y - CARD_H * 0.5)
		KEY_PAGEUP:
			scroll_by(-(_view_rect().size.y - CARD_H * 0.5))
		_:
			return
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- drawing

func _text(s: String, p: Vector2, px: int, col: Color, f: Font = null, wmax := -1.0, al := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(f if f != null else font, p, s, al, wmax, px, col)


func _tx(cv: CanvasItem, s: String, p: Vector2, px: int, col: Color, f: Font = null, wmax := -1.0, al := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	cv.draw_string(f if f != null else font, p, s, al, wmax, px, col)


func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.018, 0.021, 0.026))
	draw_rect(Rect2(0, 0, s.x, HEAD_H - 12.0), Color(0, 0, 0, 0.3))
	_draw_head()
	_draw_drone()
	_draw_left_cards()
	_draw_warehouse()
	_draw_sale()
	_draw_buttons()


# the cards still to sort, in their view (a child that clips), with a fade where more run on
func _draw_clipped() -> void:
	_clip.draw_set_transform(-_clip.position)
	for it in items:
		if str(it.place) in ["left", "fixed"] and str(it.id) != dragging:
			_card(it, it.vr, str(it.id) == hover_id, _clip)
	_clip.draw_set_transform(Vector2.ZERO)
	var v := _clip.size
	var bg := Color(0.018, 0.021, 0.026)
	var clear := Color(bg, 0.0)
	if scroll > 0.5:
		_clip.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(v.x, 0), Vector2(v.x, 28), Vector2(0, 28)]), PackedColorArray([bg, bg, clear, clear]))
	if scroll < _scroll_max() - 0.5:
		_clip.draw_polygon(PackedVector2Array([Vector2(0, v.y - 40), Vector2(v.x, v.y - 40), Vector2(v.x, v.y), Vector2(0, v.y)]), PackedColorArray([clear, clear, bg, bg]))


# the card being dragged, over everything
func _draw_over() -> void:
	if dragging != "":
		var it := _item(dragging)
		_card(it, it.vr, true, _over)


func _draw_head() -> void:
	var s := size
	draw_rect(Rect2(M, 30, 4, 46), UiSkin.ACCENT)
	_text(w("回收整理", "SORT THE HAUL"), Vector2(M + 20, 62), 30, Pal.ink(0.97), font_s)
	var job := str(d.get("job", ""))
	_text("%s  ·  %s" % [Methods.ship_label(str(d.get("ship", ""))), job], Vector2(M + 20, 88), 14, Pal.ink(0.5), font_b)
	# what the page will bring, live
	var bits: Array = [w("现在到账 %s", "CASH NOW %s") % Pal.money(cash_now())]
	var kept := 0
	for it in items:
		if movable(it) and str(it.place) == "wh":
			kept += 1
	bits.append(w("入库 %d 样", "%d KEPT") % kept)
	if left_n() > 0:
		bits.append(w("待整理 %d 样（确认时自动入库）", "%d TO SORT (KEPT ON CONFIRM)") % left_n())
	_text("  ·  ".join(bits), Vector2(0, 62), 18, Pal.ink(0.9), font_b, s.x - M, HORIZONTAL_ALIGNMENT_RIGHT)
	var money := float(Career.data.get("money", 0.0)) if not Career.data.is_empty() else 0.0
	_text(w("资金 %s", "FUNDS %s") % Pal.money(money), Vector2(0, 88), 14, Pal.ink(0.5), font_b, s.x - M, HORIZONTAL_ALIGNMENT_RIGHT)


# R-02 and its gear: what came home, what did not
func _draw_drone() -> void:
	var lr := _left_rect()
	_text(w("当前设备", "WHAT CAME HOME"), lr.position + Vector2(0, 22), 18, Pal.ink(0.92), font_s)
	var box := Rect2(lr.position + Vector2(0, 36), Vector2(lr.size.x, 136))
	draw_rect(box, Color(1, 1, 1, 0.01))
	draw_rect(box, Pal.ink(0.14), false, 1.0)
	# the drone, as painted on its pad
	var dc := box.position + Vector2(64, 68)
	var pts := PackedVector2Array()
	for v in DroneArt.ARROW:
		pts.append(dc + (v as Vector2) * 1.6)
	draw_colored_polygon(pts, Color(0.11, 0.115, 0.13))
	pts.append(pts[0])
	draw_polyline(pts, Pal.ink(0.75), 1.6, true)
	_text("R-02", box.position + Vector2(124, 40), 24, Pal.ink(0.95), font_s)
	_text(w("完好度 %d%%", "INTEGRITY %d%%") % int(round(_integrity)), box.position + Vector2(124, 64), 13, Pal.ink(0.6), font_b)
	var bar := Rect2(box.position + Vector2(124, 74), Vector2(150, 4))
	draw_rect(bar, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _integrity / 100.0, 4)), Color(UiSkin.DATA) if _integrity >= 45.0 else Pal.heat(1.0, 1.2))
	# the gear it took out
	var gx := box.position.x + 300.0
	var tiles: Array = []
	for ty in _gear_back:
		tiles.append([ty, ""])
	for l in _gear_lost:
		tiles.append([l[0], l[1] if l[1] != "" else "lost"])
	if tiles.is_empty():
		_text(w("这一单没有带出可部署工具", "NO DEPLOYABLE GEAR TAKEN OUT"), Vector2(gx, box.position.y + 74), 14, Pal.ink(0.4), font_b)
		return
	var tw := minf(128.0, (box.end.x - gx - 12.0) / tiles.size() - 8.0)
	for i in tiles.size():
		var r := Rect2(gx + i * (tw + 8.0), box.position.y + 14.0, tw, 108.0)
		var lost: bool = str(tiles[i][1]) != ""
		var col := Pal.heat(1.0, 1.15) if lost else Pal.ink(0.8)
		draw_rect(r, Color(1, 0.3, 0.2, 0.04) if lost else Color(1, 1, 1, 0.012))
		draw_rect(r, col * Color(1, 1, 1, 0.5), false, 1.0)
		_gear_icon(str(tiles[i][0]), r.position + Vector2(r.size.x * 0.5, 36), 15.0, col)
		_text(Gear.name_of(str(tiles[i][0])), r.position + Vector2(0, 74), 13, Pal.ink(0.9), font_b, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		var why := w("已收回", "HOME")
		if lost:
			why = Txt.t(str(tiles[i][1])) if Txt.has(str(tiles[i][1])) else w("遗失", "LOST")
		_text(why, r.position + Vector2(0, 94), 11, col, font, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _gear_icon(ty: String, c: Vector2, s: float, col: Color) -> void:
	match ty:
		"anchor":
			draw_line(c + Vector2(0, -s), c + Vector2(0, s * 0.8), col, 1.6, true)
			draw_arc(c + Vector2(0, s * 0.1), s * 0.75, PI * 0.15, PI * 0.85, 14, col, 1.6, true)
			draw_line(c + Vector2(-s * 0.4, -s * 0.55), c + Vector2(s * 0.4, -s * 0.55), col, 1.6, true)
		"pump":
			draw_arc(c, s * 0.8, 0.0, TAU, 24, col, 1.6, true)
			for k in 4:
				draw_line(c, c + Vector2.from_angle(TAU * k / 4.0 + 0.4) * s * 0.7, col, 1.3, true)
		"probe":
			draw_line(c + Vector2(-s, s * 0.6), c + Vector2(s * 0.6, -s * 0.6), col, 1.6, true)
			draw_circle(c + Vector2(s * 0.6, -s * 0.6), s * 0.22, col)
			draw_arc(c + Vector2(s * 0.6, -s * 0.6), s * 0.5, 0.0, TAU, 16, col * Color(1, 1, 1, 0.5), 1.0, true)
		"prop":
			draw_line(c + Vector2(0, -s), c + Vector2(0, s * 0.7), col, 2.2, true)
			draw_line(c + Vector2(-s * 0.7, s * 0.8), c + Vector2(s * 0.7, s * 0.8), col, 1.8, true)
			draw_line(c + Vector2(-s * 0.4, -s), c + Vector2(s * 0.4, -s), col, 1.8, true)
		_:
			draw_rect(Rect2(c - Vector2(s, s) * 0.6, Vector2(s, s) * 1.2), col, false, 1.4)


func _draw_left_cards() -> void:
	var lr := _left_rect()
	var y := _cards_top() - 16.0
	_text(w("本单回收物", "THIS CONTRACT'S GOODS"), Vector2(lr.position.x, y), 18, Pal.ink(0.92), font_s)
	_text(w("点卡片或拖到右边入库 · 卡片上的“卖”或拖到下面直接卖", "CLICK OR DRAG RIGHT TO KEEP · \"SELL\" OR DRAG BELOW TO SELL"), Vector2(lr.position.x, y), 13, Pal.ink(0.45), font_b, lr.size.x, HORIZONTAL_ALIGNMENT_RIGHT)
	var any := false
	var below := 0
	var view := _view_rect()
	for it in items:
		if str(it.place) in ["left", "fixed"] and str(it.id) != dragging:
			any = true
			if (_rects.get(it.id, Rect2()) as Rect2).position.y + CARD_H * 0.5 > view.end.y:
				below += 1
	if _scroll_max() > 0.0:
		var tr := _bar_track()
		var th := _bar_thumb()
		var held := _bar_drag >= 0.0 or (th.grow(8.0).has_point(get_local_mouse_position()) and dragging == "")
		draw_rect(tr, Pal.ink(0.08))
		draw_rect(th, Pal.ink(0.6 if held else 0.35))
		if below > 0:
			_text(w("↓ 还有 %d 样 · 滚轮翻看", "↓ %d MORE · SCROLL") % below, Vector2(view.position.x, view.end.y + 2.0), 12, Pal.ink(0.5), font_b, view.size.x - 4.0, HORIZONTAL_ALIGNMENT_RIGHT)
	if not any and dragging == "":
		_text(w("都整理好了。按 Enter 确认，离开船坞。", "ALL SORTED. ENTER TO CONFIRM AND LEAVE."), Vector2(lr.position.x, _cards_top() + 40.0), 16, Pal.ink(0.5), font_b)
	# the line under the cards: what the pointer is on, or what just happened
	var line := message if _msg_t > 0.0 else ""
	if hover_id != "":
		line = _hint(_item(hover_id))
	if line != "":
		_text(line, Vector2(lr.position.x, lr.end.y - 4.0), 15, Pal.ink(0.85) if _msg_t > 0.0 and hover_id == "" else Pal.ink(0.6), font_b, lr.size.x + 600.0)


# a card: its picture, its name, how much, what it is worth; new on the warehouse side
func _card(it: Dictionary, r: Rect2, hov: bool, cv: CanvasItem = null) -> void:
	if cv == null:
		cv = self
	if r.size.x < 40.0:
		# flying into a tab: a small chip
		cv.draw_rect(r, Color(UiSkin.DATA, 0.5))
		return
	var kind := str(it.kind)
	var place := str(it.place)
	var fixed := place == "fixed"
	if hov and not fixed:
		r.position.y -= 3.0
	cv.draw_rect(Rect2(r.position + Vector2(3, r.size.y - 2), Vector2(r.size.x - 3, 5)), Color(0, 0, 0, 0.45))
	cv.draw_rect(r, Color(0.07, 0.075, 0.085) if not hov else Color(0.095, 0.1, 0.112))
	var edge := Pal.ink(0.22)
	if place == "wh":
		edge = Color(UiSkin.DATA, 0.85)
	elif hov:
		edge = Color(UiSkin.ACCENT, 0.9)
	cv.draw_rect(r, edge, false, 1.2)
	# the picture
	var pic := Rect2(r.position + Vector2(12, 10), Vector2(r.size.x - 24, 76))
	cv.draw_rect(pic, Color(0, 0, 0, 0.35))
	match kind:
		"ingot":
			GoodsArt.draw(cv, pic.grow(-4.0), "ferrous_scrap", 1)
		"part":
			var cls := str(it.part.get("cls", ""))
			PartsRack._glyph(cv, cls, pic.get_center(), 22.0, PartsRack._class_col(cls))
		"fluid":
			var c := pic.get_center()
			for k in 3:
				var bx := c.x - 30.0 + k * 30.0
				cv.draw_rect(Rect2(bx - 9, c.y - 18, 18, 40), Color(0.12, 0.13, 0.15))
				cv.draw_rect(Rect2(bx - 9, c.y - 18, 18, 40), Pal.tint(Pal.AIR, 0.8, 1.1), false, 1.2)
				cv.draw_rect(Rect2(bx - 4, c.y - 26, 8, 8), Pal.tint(Pal.AIR, 0.8, 1.1))
	# name and amount
	var nm := _name(it)
	_tx(cv, nm, r.position + Vector2(12, 106), 15, Pal.ink(0.95), font_s, r.size.x - 24.0)
	var sub := ""
	match kind:
		"ingot":
			sub = w("熔炉铸的一批 · 整批处理", "ONE BATCH FROM THE FURNACE")
		"part":
			sub = "%s · %d%%" % [PartsRack.short_class(str(it.part.get("cls", ""))), int(round(float(it.part.get("cond", 0.0)) * 100.0))]
		"fluid":
			sub = w("已交付 · +%s", "DELIVERED · +%s") % Pal.money(float(it.value))
	_tx(cv, sub, r.position + Vector2(12, 126), 12, Pal.ink(0.55), font_b, r.size.x - 24.0)
	if kind == "part":
		var cb := Rect2(r.position + Vector2(12, 134), Vector2(r.size.x - 24, 3))
		var cond := clampf(float(it.part.get("cond", 0.0)), 0.0, 1.0)
		cv.draw_rect(cb, Color(0, 0, 0, 0.6))
		cv.draw_rect(Rect2(cb.position, Vector2(cb.size.x * cond, 3)), Color(UiSkin.DATA) if cond >= Repair.COND_MIN else Pal.heat(0.9, 1.1))
	if place == "wh":
		_tx(cv, w("新增", "NEW"), r.position + Vector2(0, 26), 12, Color(UiSkin.DATA), font_s, r.size.x - 14.0, HORIZONTAL_ALIGNMENT_RIGHT)
	if fixed:
		_tx(cv, w("已结算", "SETTLED"), r.position + Vector2(12, r.size.y - 16), 12, Pal.ink(0.4), font_b)
		return
	if place == "left":
		# its worth, and the sale button
		_tx(cv, w("值 %s", "WORTH %s") % Pal.money(_price(it)), r.position + Vector2(12, r.size.y - 18), 13, Pal.ink(0.8), font_b)
		var sb := Rect2(r.end.x - 108.0, r.end.y - 40.0, 96.0, 30.0)
		if r.size.y >= CARD_H - 1.0:
			var on := hover_btn == "sell:" + str(it.id)
			cv.draw_rect(sb, Color(UiSkin.ACCENT, 0.22 if on else 0.08))
			cv.draw_rect(sb, Color(UiSkin.ACCENT, 0.9 if on else 0.5), false, 1.0)
			_tx(cv, w("卖%s", "SELL%s") % (" [1]" if kind == "ingot" else ""), sb.position + Vector2(0, 21), 14, Pal.ink(0.95), font_s, sb.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_warehouse() -> void:
	var rr := _right_rect()
	_text(w("我的仓库", "THE WAREHOUSE"), rr.position + Vector2(0, 22), 18, Pal.ink(0.92), font_s)
	var sub := {"rack": w("货运区货架 A1–B4", "CARGO DISTRICT RACKS A1–B4"), "parts": w("零件架 · 完好设备", "PARTS RACK · WHOLE EQUIPMENT"), "gear": w("装备架 · 可部署工具", "GEAR SHELF · DEPLOYABLES")}
	_text(str(sub[tab]), rr.position + Vector2(0, 22), 14, Pal.ink(0.5), font_b, rr.size.x, HORIZONTAL_ALIGNMENT_RIGHT)
	var dropping := dragging != "" and get_local_mouse_position().x > rr.position.x - 20.0
	if dropping:
		draw_rect(rr.grow(6.0), Color(UiSkin.DATA, 0.06))
		draw_rect(rr.grow(6.0), Color(UiSkin.DATA, 0.6), false, 1.5)
	match tab:
		"rack": _draw_rack()
		"parts": _draw_parts()
		"gear": _draw_gear_shelf()
	# the tabs down the edge
	var names := {"rack": w("货架", "RACKS"), "parts": w("零件架", "PARTS"), "gear": w("装备架", "GEAR")}
	for i in TABS.size():
		var tr: Rect2 = _btns["tab_" + TABS[i]]
		var on: bool = tab == TABS[i]
		var hov: bool = hover_btn == "tab_" + TABS[i]
		draw_rect(tr, Color(1, 1, 1, 0.05 if on else (0.03 if hov else 0.01)))
		if on:
			draw_rect(Rect2(tr.position, Vector2(3, tr.size.y)), UiSkin.ACCENT)
		var new_n := 0
		for it in items:
			if str(it.place) == "wh" and tab_of(it) == TABS[i]:
				new_n += 1
		var c := tr.get_center() + Vector2(0, -14)
		var col := Pal.ink(0.95 if on else 0.55)
		match TABS[i]:
			"rack":
				for k in 3:
					draw_line(c + Vector2(-16, -10 + k * 9), c + Vector2(16, -10 + k * 9), col, 1.4)
				draw_line(c + Vector2(-16, -14), c + Vector2(-16, 12), col, 1.4)
				draw_line(c + Vector2(16, -14), c + Vector2(16, 12), col, 1.4)
			"parts":
				draw_rect(Rect2(c - Vector2(14, 11), Vector2(28, 22)), col, false, 1.4)
				draw_line(c + Vector2(-14, -4), c + Vector2(14, -4), col, 1.2)
			"gear":
				_gear_icon("anchor", c, 12.0, col)
		_text(str(names[TABS[i]]), Vector2(tr.position.x, tr.end.y - 18.0), 13, col, font_b, tr.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if new_n > 0:
			_text("+%d" % new_n, tr.position + Vector2(0, 18.0), 12, Color(UiSkin.DATA), font_s, tr.size.x - 8.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_text("Tab", Vector2(_tab_rects()[2].position.x, _tab_rects()[2].end.y + 22.0), 11, Pal.ink(0.35), font_b, TAB_W, HORIZONTAL_ALIGNMENT_CENTER)


# the company's stock, without this contract's ingots unless they are kept (they are in it already)
func _stock() -> Dictionary:
	var st: Dictionary = Career.data.get("exchange", {}).get("actors", {}).get(Exchange.PLAYER, {}).get("stock", {}).duplicate()
	var ingot := _item("ingot")
	if not ingot.is_empty() and str(ingot.place) != "wh" and st.has(Exchange.INGOT):
		st[Exchange.INGOT] = maxf(0.0, float(st[Exchange.INGOT]) - float(ingot.t))
	return st


func _draw_rack() -> void:
	var st := _stock()
	var use: Array = Warehouse.rows()
	for i in Warehouse.ROWS.size():
		var rc := _row_rect(i)
		var held: Array = []
		var tot := 0.0
		for k in st:
			if float(st[k]) > 0.004 and Warehouse.row_for(str(k)) == i:
				held.append([Ops.item_name(str(k)), float(st[k]), str(k)])
				tot += float(st[k])
		draw_rect(rc, Color(1, 1, 1, 0.01))
		draw_rect(rc, Pal.ink(0.14), false, 1.0)
		_text(Warehouse.ROWS[i], rc.position + Vector2(14, 28), 20, Pal.ink(0.95), font_s)
		_text(Warehouse.use_name(str(use[i])), rc.position + Vector2(52, 27), 14, Pal.ink(0.6), font_b)
		_text("%.1f t" % tot, rc.position + Vector2(0, 28), 16, Pal.ink(0.9) if tot > 0.05 else Pal.ink(0.3), font_s, rc.size.x - 14.0, HORIZONTAL_ALIGNMENT_RIGHT)
		var y := rc.position.y + 52.0
		if held.is_empty():
			_text(w("空着", "EMPTY"), Vector2(rc.position.x + 14, y), 13, Pal.ink(0.3), font_b)
		for h in held.slice(0, 3):
			GoodsArt.draw(self, Rect2(rc.position.x + 12, y - 15, 32, 20), str(h[2]).split(":")[0], int(str(h[2]).split(":")[1]) if str(h[2]).contains(":") else 0)
			_text("%s  %.1f t" % [h[0], h[1]], Vector2(rc.position.x + 52, y), 13, Pal.ink(0.7), font_b, rc.size.x - 66.0)
			y += 20.0
	var ingot := _item("ingot")
	if not ingot.is_empty() and str(ingot.place) == "wh" and str(ingot.id) != dragging:
		var r: Rect2 = ingot.vr
		var hov: bool = hover_id == "ingot"
		draw_rect(r, Color(UiSkin.DATA, 0.16 if hov else 0.1))
		draw_rect(r, Color(UiSkin.DATA, 0.9), false, 1.2)
		if r.size.x > 120.0:
			_text(w("新增  钢锭 %.1f t · 送加工", "NEW  INGOTS %.1f t · TO PROCESS") % float(ingot.t), r.position + Vector2(10, 22), 13, Pal.ink(0.95), font_s, r.size.x - 20.0)


func _draw_parts() -> void:
	var cap := _parts_cap()
	var n := 0
	for it in items:
		if str(it.kind) == "part" and str(it.place) == "wh":
			if str(it.id) != dragging:
				_card(it, it.vr, str(it.id) == hover_id)
			n += 1
	var mine: Array = d.get("uids", [])
	var shelf: Array = []
	for p in Career.data.get("parts", []):
		if not str(p.uid) in mine:
			shelf.append(p)
	for p in shelf:
		if n >= cap:
			break
		_card({"id": "", "kind": "part", "place": "shelf", "part": p}, _crate_rect(n), false)
		n += 1
	var more := shelf.size() + _count_new_parts() - n
	if more > 0:
		var rr := _right_rect()
		_text(w("零件架上另有 %d 件", "%d MORE ON THE RACK") % more, Vector2(rr.position.x, rr.end.y - 4.0), 13, Pal.ink(0.45), font_b, rr.size.x, HORIZONTAL_ALIGNMENT_RIGHT)
	if n == 0:
		_text(w("零件架上还没有东西", "THE PARTS RACK IS EMPTY"), _right_rect().position + Vector2(0, 80), 15, Pal.ink(0.35), font_b)


func _count_new_parts() -> int:
	var n := 0
	for it in items:
		if str(it.kind) == "part" and str(it.place) == "wh":
			n += 1
	return n


func _draw_gear_shelf() -> void:
	var rr := _right_rect()
	var have: Dictionary = Career.data.get("gear", {}) if not Career.data.is_empty() else {}
	var tw := floorf((rr.size.x - GAP * 3.0) / 4.0)
	for i in Gear.DEPLOY.size():
		var ty: String = Gear.DEPLOY[i]
		var r := Rect2(rr.position.x + i * (tw + GAP), rr.position.y + 48.0, tw, 190.0)
		var n := int(have.get(ty, 0))
		var back := _gear_back.count(ty)
		var lost := 0
		for l in _gear_lost:
			if str(l[0]) == ty:
				lost += 1
		draw_rect(r, Color(1, 1, 1, 0.01))
		draw_rect(r, Color(UiSkin.DATA, 0.8) if back > 0 else Pal.ink(0.14), false, 1.0)
		_gear_icon(ty, r.position + Vector2(tw * 0.5, 56), 22.0, Pal.ink(0.85 if n > 0 else 0.3))
		_text(Gear.name_of(ty), r.position + Vector2(0, 116), 15, Pal.ink(0.92), font_s, tw, HORIZONTAL_ALIGNMENT_CENTER)
		_text(w("架上 %d 个", "%d ON THE SHELF") % n, r.position + Vector2(0, 142), 14, Pal.ink(0.7 if n > 0 else 0.35), font_b, tw, HORIZONTAL_ALIGNMENT_CENTER)
		if back > 0:
			_text(w("+%d 收回", "+%d HOME") % back, r.position + Vector2(0, 166), 13, Color(UiSkin.DATA), font_s, tw, HORIZONTAL_ALIGNMENT_CENTER)
		elif lost > 0:
			_text(w("-%d 遗失", "-%d LOST") % lost, r.position + Vector2(0, 166), 13, Pal.heat(1.0, 1.15), font_s, tw, HORIZONTAL_ALIGNMENT_CENTER)


# the sale strip under the cards: what is sold, and the money
func _draw_sale() -> void:
	var sr := _sale_rect()
	var dropping := dragging != "" and sr.grow(16.0).has_point(get_local_mouse_position())
	draw_rect(sr, Color(UiSkin.ACCENT, 0.08 if dropping else 0.012))
	var col := Color(UiSkin.ACCENT, 0.9 if dropping else 0.45)
	# dashed edge: a place to drop things
	var x := sr.position.x
	while x < sr.end.x:
		draw_line(Vector2(x, sr.position.y), Vector2(minf(x + 8.0, sr.end.x), sr.position.y), col, 1.0)
		draw_line(Vector2(x, sr.end.y), Vector2(minf(x + 8.0, sr.end.x), sr.end.y), col, 1.0)
		x += 14.0
	_text(w("直接卖出", "SELL NOW"), sr.position + Vector2(12, 20), 13, Pal.ink(0.75), font_s)
	var n_sold := 0
	for it in items:
		if str(it.place) == "sold":
			n_sold += 1
	if n_sold > 0:
		# the chips narrow as more are sold: the count and the sum stay readable here
		_text(w("已卖 %d 样 · +%s", "%d SOLD · +%s") % [n_sold, Pal.money(cash_now())], sr.position + Vector2(84, 20), 13, Color(UiSkin.ACCENT, 0.95), font_s)
	_text(w("拖到这里卖 · 点已卖的东西放回", "DROP HERE TO SELL · CLICK ONE TO TAKE IT BACK"), sr.position + Vector2(0, 20), 12, Pal.ink(0.4), font_b, sr.size.x - 12.0, HORIZONTAL_ALIGNMENT_RIGHT)
	for it in items:
		if str(it.place) == "sold" and str(it.id) != dragging:
			var r: Rect2 = it.vr
			var hov: bool = hover_id == str(it.id)
			draw_rect(r, Color(UiSkin.ACCENT, 0.25 if hov else 0.14))
			draw_rect(r, Color(UiSkin.ACCENT, 0.8), false, 1.0)
			if r.size.x > 80.0:
				_text("%s  +%s" % [_name(it), Pal.money(_price(it))], r.position + Vector2(8, 21), 12, Pal.ink(0.95), font_b, r.size.x - 16.0)


func _draw_buttons() -> void:
	var labels := {"confirm": w("确认，离开船坞 [Enter]", "CONFIRM AND LEAVE [Enter]"), "back": w("回结算单 [Esc]", "BACK [Esc]"),
		"move_all": w("转移全部 [T]", "MOVE ALL [T]"), "sell_all": w("全部卖出 [X]", "SELL ALL [X]")}
	for b in labels:
		var r: Rect2 = _btns[b]
		var hov: bool = hover_btn == b
		var main: bool = b == "confirm"
		draw_rect(r, Color(UiSkin.ACCENT, 0.95 if hov else 0.8) if main else Color(1, 1, 1, 0.05 if hov else 0.015))
		if not main:
			draw_rect(r, Pal.ink(0.5 if hov else 0.25), false, 1.0)
		_text(str(labels[b]), r.position + Vector2(0, 33), 16, Color(0.05, 0.05, 0.06) if main else Pal.ink(0.92), font_s, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
