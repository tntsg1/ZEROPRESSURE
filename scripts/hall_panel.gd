extends Control
# 128 号 第 2 段 交易行与订单板 (design/成长版本/…/128_港区从头设计_仓库交易加工动力_2026-11-04.md §四, 第 2 段
# 问答定案): the trade port's one page, three tabs (scripts/hall_market.gd holds the rules).
#   卖: what the warehouse holds; pick one — its price ladder, the price curve of the last half hour
#       (the average, the ±10 % band, now), and the one key: 按建议价挂单 [Enter]. 自己定价 opens a
#       slider: the price against the market now and the average, how long it will take, what lands.
#       Below, what is listed: how far along each is, 撤单.
#   买: other companies' machines and repair steel, dearer than one's own salvage; how many, 买下 [Enter].
#   订单: up to eight cards — who, the reputation level, what and how much, the price, the time left,
#       what the warehouse holds of it; 接单 [Enter]; a taken one shows its way: 备货 → 火车 → 客户飞船
#       → 到账.
# Hand-drawn like the stores page (scripts/company_store.gd): its glass, its toast; 人性化: Esc steps
# back (the price slider, then the page — to the stores when it came from there), buys and sales and
# orders are done at once with a note, the tab and the picks come back next time, a key's plain note
# after 0.4 s (and why a shut one is shut), the interface scale, Enter on the one action.

const RepairBill = preload("res://scripts/repair_bill.gd")
const PAD := 40.0
const HEAD_H := 118.0
const TAB_Y := 132.0
const TAB_H := 56.0
const LIST_W := 520.0
const ROW_H := 64.0
const BG := Color(0.035, 0.04, 0.048)
const TABS := ["sell", "buy", "orders"]

var game
var on_close: Callable
var start_tab := ""
var start_pick := ""
var back_to_store := false   # 134 号: superseded by the shared trail (scripts/ui_back.gd); kept for old callers
const Back := preload("res://scripts/ui_back.gd")
var tab := "sell"
var font: Font
var font_b: Font
var font_s: Font
var font_l: Font
var sel := ""                 # sell: the unit picked
var custom := false           # sell: the price slider open
var price_k := 1.0            # sell: the asking price, of the market now
var buy_sel := ""
var buy_n := 1
var ord_sel := ""
var scroll := {"sell": 0.0, "buy": 0.0}
var _btns := {}               # id -> Rect2 (page px)
var _notes := {}              # id -> [plain note, why it is shut ("" if it is not)]
var _shut := {}               # id -> true: drawn dim, does nothing but say why
var hover := ""
var _hover_t := 0.0
var _hov := {}                # id -> 0 … 1 (eased)
var _drag := false
var _t := 0.0
var _tab_t := 9.0             # since the tab changed
var _ink_x := 0.0             # the tab underline's place (eased)
var message := ""
var _msg_t := 0.0
var _msg_bad := false
var _units: Array = []
var _units_t := 0.0
var _cash_shown := -1.0
var _flash := {}              # id -> time it was pressed (the click's light)


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ready() -> void:
	Back.arrive()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
	font_s = Fonts.get_font("SemiBold")
	font_l = Fonts.get_font("Light")
	var st: Dictionary = BenchFx.state_of("hall_panel").get("own", {})
	if not st.is_empty():
		tab = str(st.get("tab", "sell")) if str(st.get("tab", "")) in TABS else "sell"
		buy_sel = str(st.get("buy", ""))
		ord_sel = str(st.get("ord", ""))
	if start_tab in TABS:
		tab = start_tab
	if tab == "sell" and start_pick != "":
		sel = start_pick
		custom = true
	elif tab == "orders" and start_pick == "":
		ord_sel = ""
	elif tab == "orders" and start_pick != "":
		for o in HallMarket.orders():
			if str(o.kind) == start_pick and str(o.state) == "open":
				ord_sel = str(o.id)
				break
	_refresh()
	grab_focus.call_deferred()
	BenchFx.apply_scale(self)
	if BenchFx.on():
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cash_shown = float(Career.data.get("money", 0.0))
	_ink_x = _tab_rect(TABS.find(tab)).position.x


func _refresh() -> void:
	_units = []
	for u in StoreBook.units():
		if float(u.get("market", 0.0)) > 0.0 and not (u.has("part") and u.part.has("listed")):
			_units.append(u)
	_units.sort_custom(func(a, b): return float(a.market) > float(b.market))
	if sel != "" and not _units.any(func(u): return str(u.id) == sel):
		sel = ""
	if sel == "" and not _units.is_empty():
		sel = str(_units[0].id)
	if buy_sel == "" or not HallMarket.offers().any(func(o): return str(o.kind) == buy_sel):
		buy_sel = str(HallMarket.offers()[0].kind)
	var os := _cards()
	if ord_sel == "" or not os.any(func(o): return str(o.id) == ord_sel):
		ord_sel = str(os[0].id) if not os.is_empty() else ""


func _unit(id: String) -> Dictionary:
	for u in _units:
		if str(u.id) == id:
			return u
	return {}


# 132 号: the cards by how much they want doing now — open and in store (soonest due first), open and
# short, then the ones on their way
func _cards() -> Array:
	var cs: Array = HallMarket.orders().filter(func(o): return str(o.state) != "gone")
	cs.sort_custom(func(x, y): return _rank(x) < _rank(y))
	return cs


func _rank(o: Dictionary) -> float:
	if str(o.state) == "open":
		var ok := HallMarket.have_of(str(o.cat), str(o.kind)) >= float(o.n) - 0.0005
		return (0.0 if ok else 10000.0) + float(o.due)
	return 20000.0 + float(o.get("due", 0.0))


func set_tab(t: String) -> void:
	if t == tab or not t in TABS:
		return
	tab = t
	custom = false
	_drag = false
	_tab_t = 0.0
	_refresh()
	if game != null and is_instance_valid(game) and game.get("sfx") != null:
		game.sfx.play("menu", Vector2.INF, 0.5)


func _say(s: String, bad := false) -> void:
	message = s
	_msg_t = 4.0
	_msg_bad = bad
	if game != null and is_instance_valid(game) and game.get("sfx") != null:
		game.sfx.play("deny" if bad else "receipt", Vector2.INF, 0.8)


func close() -> void:
	if BenchFx.leaving(self):
		return
	if not Career.data.is_empty():
		var all: Dictionary = Career.data.get("bench_ui", {})
		all["hall_panel"] = {"own": {"tab": tab, "buy": buy_sel, "ord": ord_sel}}
		Career.data["bench_ui"] = all
	var g = game
	var back := back_to_store
	var handed := BenchFx.leave(self)
	if on_close.is_valid():
		on_close.call()
	elif not handed:
		queue_free()
	if back and not Back.has_back() and g != null and is_instance_valid(g) and g.has_method("open_store"):
		(func(): g.open_store()).call_deferred()


# Esc and the close key: back where the exchange was opened from (the stores, a console…), else away
func _back() -> void:
	var trail := Back.has_back()
	close()
	if trail:
		Back.back()


# ---------------------------------------------------------------- doing it

func list_now() -> void:
	var u := _unit(sel)
	if u.is_empty():
		_say(w("仓库里目前没有可以上架出售的货物", "NOTHING IN STORE TO LIST"), true)
		return
	var price := -1.0 if not custom else HallMarket.market_now(u) * price_k
	var r := HallMarket.list(sel, price)
	if not r.ok:
		_say(str(r.reason), true)
		return
	_say(w("上架出售：%s · 出售价格 %s · 数量 %s，成交后预计收到 %s（已扣除 5%% 手续费）", "LISTED: %s · ASKING %s · %s, %s PAID ON THE SALE (LESS 5%%)") % [str(r.name), Pal.money(float(r.price)), HallMarket.eta_text(float(r.secs)), Pal.money(float(r.net))])
	custom = false
	price_k = 1.0
	sel = ""
	_refresh()


func cancel_listing(lid: String) -> void:
	var r := HallMarket.cancel(lid)
	if not r.ok:
		_say(str(r.reason), true)
		return
	_say(w("取消出售：%s 将退回仓库", "WITHDRAWN: %s IS BACK IN STORE") % str(r.name))
	_refresh()


func buy_now() -> void:
	var of := _offer(buy_sel)
	if of.is_empty():
		return
	var n := float(buy_n) * float(of.get("step", 1.0))
	var r := HallMarket.buy(buy_sel, n)
	if not r.ok:
		_say(str(r.reason), true)
		return
	_say(w("已购买 %s，支付 %s，购买 %s", "BOUGHT %s · PAID %s · %s") % [str(r.name), Pal.money(float(r.cash)), str(r.where)])
	_refresh()


func take_order() -> void:
	var o := HallMarket.order(ord_sel)
	if o.is_empty():
		return
	match str(o.state):
		"open":
			var r := HallMarket.take(ord_sel)
			if not r.ok:
				_say(str(r.reason), true)
				return
			if str(r.state) == "rail":
				_say(w("已接受 %s 的订单，仓库库存足够，货物已经备齐，货运火车将把货物运往贸易港", "TOOK %s'S ORDER: ALL IN STORE, ON THE FREIGHT TRAIN TO THE TRADE PORT") % str(r.client))
			else:
				_say(w("已接受 %s 的订单，仓库会自动准备货物，缺少的部分会在入库后自动补齐", "TOOK %s'S ORDER: THE STORES MAKE IT UP, THE REST AS IT COMES IN") % str(r.client))
		"taken":
			var r2 := HallMarket.drop(ord_sel)
			if not r2.ok:
				_say(str(r2.reason), true)
				return
			_say(w("已取消这份订单，已经准备好的货物会退回仓库，不会产生罚款", "ORDER GIVEN BACK: THE GOODS ARE BACK IN STORE, NO PENALTY"))
	_refresh()


func _offer(kind: String) -> Dictionary:
	for of in HallMarket.offers():
		if str(of.kind) == kind:
			return of
	return {}


func _primary() -> void:
	match tab:
		"sell": _press("list")
		"buy": _press("buy")
		"orders": _press("take")


func _press(id: String) -> void:
	_flash[id] = BenchFx.now()
	if _shut.has(id):
		var why: String = _notes.get(id, ["", ""])[1]
		if why != "":
			_say(why, true)
		return
	if id.begins_with("tab:"):
		set_tab(id.substr(4))
	elif id == "close":
		_back()
	elif id == "list":
		list_now()
	elif id == "custom":
		custom = not custom
		price_k = 1.0
	elif id == "minus":
		price_k = clampf(snappedf(price_k - 0.01, 0.01), HallMarket.PRICE_MIN, HallMarket.PRICE_MAX)
	elif id == "plus":
		price_k = clampf(snappedf(price_k + 0.01, 0.01), HallMarket.PRICE_MIN, HallMarket.PRICE_MAX)
	elif id == "avg":
		var u := _unit(sel)
		if not u.is_empty():
			price_k = clampf(1.0 / HallMarket.drift(HallMarket.kind_of(u)), HallMarket.PRICE_MIN, HallMarket.PRICE_MAX)
	elif id.begins_with("u:"):
		if sel != id.substr(2):
			sel = id.substr(2)
			price_k = 1.0
	elif id.begins_with("x:"):
		cancel_listing(id.substr(2))
	elif id.begins_with("b:"):
		if buy_sel != id.substr(2):
			buy_sel = id.substr(2)
			buy_n = 1
	elif id == "bminus":
		buy_n = maxi(1, buy_n - 1)
	elif id == "bplus":
		buy_n = mini(9, buy_n + 1)
	elif id == "buy":
		buy_now()
	elif id.begins_with("o:"):
		ord_sel = id.substr(2)
	elif id == "take":
		take_order()
	elif id == "plan":
		var r := ProcessLine.plan_for_order(ord_sel)
		if not r.ok:
			_say(str(r.reason), true)
		else:
			_say(w("已为这份订单安排加工：消耗钢锭 %.1f t，生产 %s，已排在加工队列的第一位", "PLANNED: %.1f t → %s, FIRST IN THE QUEUE") % [float(r.entry.t), ProcessLine.mould_name(str(r.entry.mould))])


# ---------------------------------------------------------------- input

func _slider_rect() -> Rect2:
	return _btns.get("slider", Rect2())


func _set_from_slider(x: float) -> void:
	var r := _slider_rect()
	if r.size.x <= 0.0:
		return
	var f := clampf((x - r.position.x) / r.size.x, 0.0, 1.0)
	price_k = snappedf(lerpf(0.8, 1.3, f), 0.005)


# The selected order's action sits inside its card: hit the action first.
func _hit_button(pos: Vector2) -> String:
	if tab == "orders" and _btns.has("take") and (_btns["take"] as Rect2).has_point(pos):
		return "take"
	if tab == "orders" and _btns.has("plan") and (_btns["plan"] as Rect2).has_point(pos):
		return "plan"
	for id in _btns:
		if id != "slider" and (_btns[id] as Rect2).has_point(pos):
			return str(id)
	return ""


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.pressed and ev.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP] and scroll.has(tab):
			scroll[tab] = maxf(0.0, float(scroll[tab]) + (ROW_H * 2.0 if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN else -ROW_H * 2.0))
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if not ev.pressed:
				_drag = false
			elif _slider_rect().grow(8.0).has_point(ev.position) and custom and tab == "sell":
				_drag = true
				_set_from_slider(ev.position.x)
			else:
				var hit := _hit_button(ev.position)
				if hit != "":
					_press(hit)
		accept_event()
	elif ev is InputEventMouseMotion and _drag:
		_set_from_slider(ev.position.x)
		accept_event()


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	match ev.physical_keycode:
		KEY_ESCAPE, KEY_F8:
			# Esc steps back: the price slider, then the page
			if custom and ev.physical_keycode == KEY_ESCAPE:
				custom = false
				price_k = 1.0
			elif ev.physical_keycode == KEY_ESCAPE:
				_back()
			else:
				close()
		KEY_ENTER, KEY_KP_ENTER:
			_primary()
		_:
			return
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- frame

func _process(dt: float) -> void:
	_t += dt
	_tab_t += dt
	_msg_t -= dt
	_units_t += dt
	if _units_t > 1.0:
		_units_t = 0.0
		_refresh()
	var m := get_local_mouse_position()
	var h := _hit_button(m)
	if h != hover:
		hover = h
		_hover_t = 0.0
	_hover_t += dt
	for id in _btns:
		var want := 1.0 if id == hover else 0.0
		_hov[id] = move_toward(float(_hov.get(id, 0.0)), want, dt / 0.15) if BenchFx.on() else want
	var ti := TABS.find(tab)
	var tx := _tab_rect(ti).position.x
	_ink_x = lerpf(_ink_x, tx, 1.0 - exp(-dt * 14.0)) if BenchFx.on() else tx
	var cash := float(Career.data.get("money", 0.0))
	_cash_shown = lerpf(_cash_shown, cash, 1.0 - exp(-dt * 6.0)) if BenchFx.on() else cash
	if absf(_cash_shown - cash) < 0.5:
		_cash_shown = cash
	queue_redraw()


# ---------------------------------------------------------------- drawing helpers

func _text(s: String, p: Vector2, px: int, col: Color, f: Font = null, wmax := -1.0, al := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var fo: Font = f if f != null else font_b
	# 2026-11-10: a line never runs past the width it was given (it ran out of its card); cut, with "…"
	if wmax > 0.0 and fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > wmax:
		var lo := 0
		var hi := s.length()
		while lo < hi:
			var mid := (lo + hi + 1) / 2
			if fo.get_string_size(s.substr(0, mid) + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= wmax:
				lo = mid
			else:
				hi = mid - 1
		s = s.substr(0, lo) + "…"
	draw_string(fo, p, s, al, wmax, px, col)


func _glass(r: Rect2, k := 1.0) -> void:
	Charcoal.panel(self, r, k)


# rows rise one after another as a tab comes in
func _rise(i: int) -> Array:
	if not BenchFx.on():
		return [0.0, 1.0]
	var k := BenchFx.e_out5(clampf((_tab_t - 0.04 * mini(i, 10)) / 0.45, 0.0, 1.0))
	return [(1.0 - k) * 14.0, k]


# a key: its frame lit by hover, the click's light, a primary one in the accent; registered for input
func _key(id: String, r: Rect2, label: String, note := "", why := "", primary := false, sub := "") -> void:
	_btns[id] = r
	_notes[id] = [note, why]
	var shut := why != ""
	if shut:
		_shut[id] = true
	var hv := float(_hov.get(id, 0.0))
	var lift := -BenchFx.LIFT * hv if BenchFx.on() and not shut else 0.0
	var rr := Rect2(r.position + Vector2(0, lift), r.size)
	var acc := Charcoal.ACCENT
	var down := 0.0
	if _flash.has(id) and BenchFx.on():
		down = clampf(1.0 - (BenchFx.now() - float(_flash[id])) / 0.18, 0.0, 1.0)
	if primary and not shut:
		# the page's one action: the orange key, a firm shadow under it, sinking as it is pressed
		var fr := rr
		fr.position.y += 3.0 * down
		draw_style_box(_orange_box(hv, down), fr)
		rr = fr
	else:
		rr = Charcoal.key(self, rr, 0.55 if shut else 1.0, down, Charcoal.FACE.lerp(Charcoal.FACE_HI, hv), 8)
	if _flash.has(id) and BenchFx.on():
		var age := BenchFx.now() - float(_flash[id])
		if age < 0.35:
			draw_rect(rr.grow(age * 14.0), Color(acc, 0.35 * (1.0 - age / 0.35)), false, 1.5)
	var px := 30 if label in ["−", "+"] and r.size.y >= 60.0 else (16 if primary else 14)
	var ty := rr.position.y + (rr.size.y * 0.5 + (11.0 if px >= 30 else 6.0) if sub == "" else rr.size.y * 0.5 - 2.0)
	# "… [Enter]" / "… [Esc]": the words centred, the key's name on a cap at the right
	var kk := Charcoal.split_key(label.strip_edges())
	var cap_w := 0.0
	if kk[1] != "" and rr.size.x > 110.0:
		label = kk[0]
		cap_w = maxf(40.0, font_s.get_string_size(kk[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16.0)
		Charcoal.keycap(self, font_s, Rect2(rr.end.x - cap_w - 10.0, rr.get_center().y - 12.0, cap_w, 24.0), kk[1], 0.5 if shut else 1.0, down)
		cap_w += 14.0
	var ink := Color(0.1, 0.05, 0.02) if primary and not shut else Pal.ink(0.45 if shut else 0.96)
	_text(label, Vector2(rr.position.x, ty), px, ink, font_s if primary else font_b, rr.size.x - cap_w, HORIZONTAL_ALIGNMENT_CENTER)
	if sub != "":
		_text(sub, Vector2(rr.position.x, ty + 18.0), 11, Color(0.15, 0.07, 0.02, 0.8) if primary and not shut else Pal.ink(0.4 if shut else 0.62), font_b, rr.size.x - cap_w, HORIZONTAL_ALIGNMENT_CENTER)


static var _ob := {}


func _orange_box(hv: float, down: float) -> StyleBoxFlat:
	var k := "%d|%d" % [int(hv * 10.0), int(down * 10.0)]
	if _ob.has(k):
		return _ob[k]
	var b := StyleBoxFlat.new()
	b.bg_color = Charcoal.ACCENT.lightened(0.08 * hv).darkened(0.12 * down)
	b.set_corner_radius_all(8)
	b.anti_aliasing = true
	b.shadow_color = Color(0, 0, 0, 0.7 - 0.35 * down)
	b.shadow_size = 8
	b.shadow_offset = Vector2(0, 4.0 - 3.0 * down)
	b.border_width_top = 1
	b.border_color = Color(1, 1, 1, 0.28 * (1.0 - down))
	_ob[k] = b
	return b


func _tab_rect(i: int) -> Rect2:
	return Rect2(PAD + i * 248.0, TAB_Y, 234.0, TAB_H)


# a warehouse unit's or an offer's picture in a square: the machine's own line art, a bundle, plates
func _thumb(r: Rect2, cat: String, ship: String, tag: String, nk: String, alpha := 1.0) -> void:
	draw_rect(r, Color(0.08, 0.09, 0.1, 0.9 * alpha))
	draw_rect(r, Pal.ink(0.18 * alpha), false, 1.0)
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y)
	if cat == "raw":
		for k in 3:
			var y := c.y - s * 0.22 + k * s * 0.15
			draw_rect(Rect2(c.x - s * 0.3, y, s * 0.6, s * 0.11), Color(0.17, 0.18, 0.195, alpha))
			draw_rect(Rect2(c.x - s * 0.3, y, s * 0.6, s * 0.11), Pal.ink(0.6 * alpha), false, 1.0)
		draw_line(Vector2(c.x - s * 0.12, c.y - s * 0.28), Vector2(c.x - s * 0.12, c.y + s * 0.24), Color(UiSkin.ACCENT, 0.7 * alpha), 2.0)
		draw_line(Vector2(c.x + s * 0.12, c.y - s * 0.28), Vector2(c.x + s * 0.12, c.y + s * 0.24), Color(UiSkin.ACCENT, 0.7 * alpha), 2.0)
		return
	if cat == "steel":
		for k in 4:
			var y := c.y + s * 0.2 - k * s * 0.11
			draw_rect(Rect2(c.x - s * 0.32 + k * 2.0, y, s * 0.64, s * 0.08), Color(0.17, 0.18, 0.195, alpha))
			draw_rect(Rect2(c.x - s * 0.32 + k * 2.0, y, s * 0.64, s * 0.08), Pal.ink(0.55 * alpha), false, 1.0)
		return
	var lk := StoreBook.look_any(ship, tag, nk)
	if lk.is_empty():
		draw_arc(c, s * 0.26, 0.0, TAU, 20, Pal.ink(0.7 * alpha), 1.4)
		draw_rect(Rect2(c - Vector2(s * 0.12, s * 0.12), Vector2(s * 0.24, s * 0.24)), Pal.ink(0.5 * alpha), false, 1.2)
		return
	var sz: Vector2 = lk.size * Geom.M
	var k2 := minf(r.size.x / maxf(sz.x, 1.0), r.size.y / maxf(sz.y, 1.0)) * 0.8
	draw_set_transform_matrix(Transform2D(0.0, Vector2(k2, k2), 0.0, c - sz * 0.5 * k2))
	var poly: PackedVector2Array = lk.poly
	if poly.size() >= 3:
		var pts := PackedVector2Array()
		for q in poly:
			pts.append(q * Geom.M)
		draw_colored_polygon(pts, Color(0.12, 0.13, 0.145, alpha))
		pts.append(pts[0])
		draw_polyline(pts, Pal.ink(0.7 * alpha), 1.4 / k2)
	if str(lk.art) != "":
		Art.draw(self, str(lk.art), sz, null, font)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _u_thumb(r: Rect2, u: Dictionary, alpha := 1.0) -> void:
	var src: Dictionary = u.get("good", u.get("part", {}))
	_thumb(r, str(u.cat) if str(u.cat) == "raw" else "equip", str(u.get("ship", "")), str(u.get("tag", "")), str(src.get("nk", "")), alpha)


# ---------------------------------------------------------------- the page

func _draw() -> void:
	_btns = {}
	_notes = {}
	_shut = {}
	# 2026-11-10 炭黑 (user: "交易行也一点没改啊"): the dark instrument — still near-black ground,
	# matte charcoal panels with a shadow, figures in black windows, keys that press in
	Charcoal.ground(self, size)
	_draw_head()
	_draw_tabs()
	_draw_now()
	match tab:
		"sell": _draw_sell()
		"buy": _draw_buy()
		"orders": _draw_orders()
	_draw_foot()
	_draw_note()


func _draw_head() -> void:
	draw_rect(Rect2(PAD, 40, 4, 34), UiSkin.ACCENT)
	_text(w("交易行 · 贸易港", "THE EXCHANGE · TRADE PORT"), Vector2(PAD + 16, 70), 32, Pal.ink(0.97), font_s)
	var nl := HallMarket.listings().size()
	var no := HallMarket.live_orders().size()
	var line := w("当前上架商品 %d 件 · 已接受订单 %d/%d 张 · %s", "%d LISTED · %d/%d ORDERS · %s") % [nl, no, HallMarket.MAX_ORDERS, HallMarket.level_text()]
	_text(line, Vector2(PAD + 16, 104), 18, Pal.ink(0.88), font_b)
	var back0 := Back.close_text(true) if Back.has_back() else (w("返回仓库 [Esc]", "BACK TO STORES  [Esc]") if back_to_store else w("关闭窗口 [Esc]", "CLOSE  [Esc]"))
	var cash_x := size.x - PAD - maxf(170.0, font_b.get_string_size(back0, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 36.0) - 230.0
	Charcoal.display(self, Rect2(cash_x - 18.0, 36.0, 236.0, 66.0))
	_text(w("当前资金", "CASH"), Vector2(cash_x, 58), 13, Pal.ink(0.5), font_b, 200.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(Pal.money(roundf(_cash_shown)), Vector2(cash_x, 88), 24, Pal.ink(0.95), font_s, 200.0, HORIZONTAL_ALIGNMENT_RIGHT)
	var back := Back.close_text(true) if Back.has_back() else (w("返回仓库 [Esc]", "BACK TO STORES  [Esc]") if back_to_store else w("关闭窗口 [Esc]", "CLOSE  [Esc]"))
	var cw := maxf(170.0, font_b.get_string_size(back, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 36.0)
	_key("close", Rect2(size.x - PAD - cw, 48, cw, 46.0), back, (w("返回%s界面", "Back to %s") % Back.label()) if Back.has_back() else (w("关闭交易行界面", "Close the exchange") if not back_to_store else w("返回仓库界面", "Back to the stores page")))
	draw_line(Vector2(PAD, HEAD_H), Vector2(size.x - PAD, HEAD_H), Pal.ink(0.12), 1.0)


func _draw_tabs() -> void:
	# 2026-11-10 炭黑 v2: three big keys like the terminal's home keys, the open one pressed in, the
	# orange lip sliding under them
	var names := {"sell": w("出售货物", "SELL"), "buy": w("购买货物", "BUY"), "orders": w("客户订单", "ORDERS")}
	var notes := {"sell": w("把仓库里的货物上架到交易行，成交需要等待一段现实时间", "List what is in store; it sells in real time"),
		"buy": w("可以购买其他公司的设备和钢材，不过价格会比自己拆船获得的更贵", "Buy other companies' machines and steel, dearer than your own"),
		"orders": w("客户会指定需要的货物，订单价格从市场价的 130% 起", "What clients ask for, from 130% of market")}
	for i in TABS.size():
		var id := str(TABS[i])
		var r := _tab_rect(i)
		_btns["tab:" + id] = r
		_notes["tab:" + id] = [str(notes[id]), ""]
		var on := id == tab
		var hv := float(_hov.get("tab:" + id, 0.0))
		var fr := Charcoal.key(self, r, 1.0, 1.0 if on else 0.0, Charcoal.FACE.lerp(Charcoal.FACE_HI, hv), 10)
		_text("%d" % (i + 1), fr.position + Vector2(18, 37), 26, Charcoal.ACCENT if on else Pal.ink(0.45), font_l)
		var count := ""
		if id == "sell" and HallMarket.listings().size() > 0:
			count = "%d" % HallMarket.listings().size()
		if id == "orders":
			var open_n := HallMarket.orders().filter(func(o): return str(o.state) == "open").size()
			if open_n > 0:
				count = "%d" % open_n
		_text(str(names[id]), fr.position + Vector2(52, 36), 19, Pal.ink(0.97 if on else 0.7 + 0.25 * hv), font_s, fr.size.x - 100.0)
		if count != "":
			var cr := Rect2(fr.end.x - 44.0, fr.position.y + 15.0, 30.0, 26.0)
			Charcoal.display(self, cr, 1.0, 5)
			_text(count, cr.position + Vector2(0, 19), 14, Pal.ink(0.95), font_s, cr.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	Charcoal.lip(self, Rect2(_ink_x + 24.0, TAB_Y + TAB_H - 4.0, 186.0, 4.0))


func _body_top() -> float:
	return TAB_Y + TAB_H + 20.0 + NOW_H + 16.0


const NOW_H := 52.0
const ConsoleKit = preload("res://scripts/console_kit.gd")


# 132 号: the line under the tabs — whether this page has anything worth doing now
func now_of() -> Array:
	match tab:
		"orders":
			var cs := _cards()
			for o in cs:
				if str(o.state) == "open" and HallMarket.have_of(str(o.cat), str(o.kind)) >= float(o.n) - 0.0005:
					var base := HallMarket.want_base(str(o.cat), str(o.kind)) * float(o.n)
					return [true, w("%s需要的%s仓库里已经有了，接受订单后就能直接交货，价格比市场价高 %s", "%s WANTS %s: IN STORE, IT CAN GO NOW, %s OVER MARKET") % [str(o.client), HallMarket.want_name(o), Pal.money(maxf(0.0, float(o.price) - base))]]
			if cs.any(func(o): return str(o.state) == "open"):
				return [false, w("仓库里暂时没有这份订单需要的货物", "THE ORDERS WANT WHAT IS NOT IN STORE")]
			if not cs.is_empty():
				return [false, w("目前所有订单都在运输途中", "THE ORDERS ARE ON THEIR WAY")]
			return [false, w("目前没有新的客户订单", "NO ORDERS NOW")]
		"sell":
			if not _units.is_empty():
				return [true, w("仓库里有 %d 种货物可以出售，其中最贵的价值约为 %s", "%d THINGS IN STORE TO LIST, THE DEAREST ~%s") % [_units.size(), Pal.money(float(_units[0].market))]]
			return [false, w("仓库里目前没有可以出售的货物", "NOTHING IN STORE TO SELL")]
		"buy":
			var need := _repair_need()
			if not need.is_empty():
				return [true, str(need.values()[0])]
			return [false, w("目前修缮工作所需的材料都已经备齐", "THE MENDING LACKS NOTHING")]
	return [false, ""]


func _draw_now() -> void:
	var n := now_of()
	var r := Rect2(PAD, TAB_Y + TAB_H + 16.0, size.x - PAD * 2.0, NOW_H)
	# 炭黑: the shared line (ConsoleKit) set into a charcoal plate of its own
	Charcoal.panel(self, r.grow(6.0), 1.0, 0.0, Charcoal.FACE, 10)
	ConsoleKit.draw_now(self, r, bool(n[0]), str(n[1]))


func _swap_k() -> Array:
	if not BenchFx.on():
		return [0.0, 1.0]
	var k := BenchFx.e_out(clampf(_tab_t / BenchFx.SWAP_S, 0.0, 1.0))
	return [(1.0 - k) * 8.0, k]


# ---------------------------------------------------------------- 卖

func _draw_sell() -> void:
	var top := _body_top()
	var lr := Rect2(PAD, top, LIST_W, size.y - top - 64.0)
	Charcoal.panel(self, lr, 1.0, 0.0, Charcoal.FACE, 14)
	_text(w("仓库里可以出售的货物", "IN STORE, FOR SALE"), lr.position + Vector2(22, 36), 17, Pal.ink(0.85), font_s)
	_text("%d" % _units.size(), Vector2(lr.end.x - 22, lr.position.y + 36), 17, Pal.ink(0.5), font_s, -1, HORIZONTAL_ALIGNMENT_RIGHT)
	Charcoal.groove(self, lr.position.x + 16, lr.end.x - 16, lr.position.y + 52)
	var y0 := lr.position.y + 62.0
	var vis_h := lr.size.y - 72.0
	var maxs := maxf(0.0, _units.size() * ROW_H - vis_h)
	scroll.sell = clampf(float(scroll.sell), 0.0, maxs)
	if _units.is_empty():
		_text(w("仓库目前还是空的，拆船回收的货物会自动存放到这里", "THE STORES ARE EMPTY: WHAT YOU BRING HOME COMES HERE"), lr.position + Vector2(22, 100), 14, Pal.ink(0.5), font_b, lr.size.x - 44.0)
	for i in _units.size():
		var u: Dictionary = _units[i]
		var ry := y0 + i * ROW_H - float(scroll.sell)
		if ry < y0 - 1.0 or ry + ROW_H > lr.end.y - 4.0:
			continue
		var rs := _rise(i)
		var id := "u:" + str(u.id)
		var r := Rect2(lr.position.x + 14.0, ry + float(rs[0]), lr.size.x - 28.0, ROW_H - 8.0)
		_btns[id] = r
		_notes[id] = ["", ""]
		_row_key(r, str(u.id) == sel, float(_hov.get(id, 0.0)), float(rs[1]))
		var rr := Rect2(r.position + Vector2(0, 4.0 if str(u.id) == sel else 0.0), r.size)
		_u_thumb(Rect2(rr.position + Vector2(30, 6), Vector2(44, 44)), u, float(rs[1]))
		_text(str(u.name), rr.position + Vector2(86, 25), 15, Pal.ink(0.95 * float(rs[1])), font_s, 200.0)
		_text("%s · %s" % [str(u.get("qty", "")), StoreBook.cat_name(str(u.cat))], rr.position + Vector2(86, 45), 12, Pal.ink(0.5 * float(rs[1])), font_b, 200.0)
		var pw := Rect2(rr.end.x - 140.0, rr.position.y + 10.0, 128.0, rr.size.y - 20.0)
		Charcoal.display(self, pw, float(rs[1]), 5)
		_text(Pal.money(HallMarket.net(HallMarket.market_now(u))), pw.position + Vector2(0, pw.size.y * 0.5 + 7.0), 17, Pal.ink(0.95 * float(rs[1])), font_s, pw.size.x - 12.0, HORIZONTAL_ALIGNMENT_RIGHT)
	if maxs > 0.0:
		var bar_h := vis_h * vis_h / (vis_h + maxs)
		draw_rect(Rect2(lr.end.x - 7.0, y0 + (vis_h - bar_h) * float(scroll.sell) / maxs, 3.0, bar_h), Pal.ink(0.25))
	var dr := Rect2(lr.end.x + 24.0, top, size.x - PAD - lr.end.x - 24.0, lr.size.y)
	Charcoal.panel(self, dr, 1.0, 0.0, Charcoal.FACE, 14)
	var sw := _swap_k()
	var x := dr.position.x + 28.0
	var wd := dr.size.x - 56.0
	var y := dr.position.y + float(sw[0])
	var u := _unit(sel)
	if u.is_empty():
		_text(w("先从左边选择一件货物", "PICK SOMETHING ON THE LEFT"), Vector2(x, y + 60), 18, Pal.ink(0.5), font_b)
		return
	var kind := HallMarket.kind_of(u)
	var mkt := HallMarket.market_now(u)
	var avg := float(u.market)
	_u_thumb(Rect2(Vector2(x, y + 20), Vector2(64, 64)), u)
	_text(str(u.name), Vector2(x + 84, y + 52), 28, Pal.ink(0.97), font_s, wd - 100.0)
	_text("%s · %s" % [str(u.get("qty", "")), StoreBook.cat_name(str(u.cat))], Vector2(x + 84, y + 78), 14, Pal.ink(0.55), font_b)
	# the three prices in one big black window, each with its scale
	var of := _order_for(u)
	var order_p := float(of.price) if not of.is_empty() else avg * HallMarket.ORDER_K
	_price_window(Rect2(x, y + 100.0, wd, 132.0), [
		[w("回收站", "RECYCLING"), float(u.recycle), w("立刻到账", "PAID AT ONCE")],
		[w("交易行预计到手", "EXCHANGE, PAID"), HallMarket.net(mkt), HallMarket.eta_text(HallMarket.fill_secs(mkt, mkt))],
		[w("订单价", "AN ORDER"), order_p, (w("%s 要", "%s WANTS IT") % str(of.client)) if not of.is_empty() else w("目前没有买家", "NONE WANT IT NOW")]], 1)
	var cr := Rect2(x, y + 250.0, wd, 200.0)
	_draw_curve(cr, kind, avg)
	var by := cr.end.y + 22.0
	if not custom:
		_key("list", Rect2(x, by, minf(540.0, wd - 240.0), 58.0), w("按照建议价格上架 %s [Enter]", "LIST AT THE SUGGESTED PRICE  %s  [Enter]") % Pal.money(mkt),
			w("按照当前市场价格上架出售，成交后会扣除 5% 的手续费，剩余金额会转入账户", "Listed at the market now; paid less 5% on the sale"), "", true,
			w("预计到账 %s · %s", "%s PAID · %s") % [Pal.money(HallMarket.net(mkt)), HallMarket.eta_text(HallMarket.fill_secs(mkt, mkt))])
		_key("custom", Rect2(x + minf(540.0, wd - 240.0) + 16.0, by, 220.0, 58.0), w("自行设置价格…", "SET MY OWN PRICE…"), w("打开价格调整滑条，价格越高，成交可能越慢；价格越低，成交通常越快", "Open the price slider: dearer sells slower, cheaper faster"))
		_draw_listings(Rect2(x, by + 80.0, wd, dr.end.y - 16.0 - by - 80.0))
	else:
		_draw_slider(Rect2(x, by - 4.0, wd, 150.0), u, mkt, avg)
		_draw_listings(Rect2(x, by + 156.0, wd, dr.end.y - 16.0 - by - 156.0))


func _row_key(r: Rect2, on: bool, hv: float, a: float) -> void:
	var fr := Charcoal.key(self, r, a, 1.0 if on else 0.0, Charcoal.FACE_HI if hv > 0.5 and not on else Charcoal.FACE, 8)
	Charcoal.led(self, Vector2(fr.position.x + 15.0, fr.get_center().y), on, a, 4.0)
	if on:
		Charcoal.lip(self, Rect2(fr.position.x + 30.0, fr.end.y - 5.0, fr.size.x - 60.0, 3.0), a)


# three prices side by side in a black window: label, the figure large, a scale against the
# dearest, a line under it; hi = the one to look at (its figure in the accent)
func _price_window(r: Rect2, cols: Array, hi: int) -> void:
	Charcoal.display(self, r)
	var top := 0.0
	for c in cols:
		if (c as Array).size() <= 3:
			top = maxf(top, float(c[1]))
	var cw := r.size.x / cols.size()
	for i in cols.size():
		var cx := r.position.x + i * cw
		if i > 0:
			draw_line(Vector2(cx, r.position.y + 14), Vector2(cx, r.end.y - 14), Color(1, 1, 1, 0.07), 1.0)
		_text(str(cols[i][0]), Vector2(cx + 18, r.position.y + 30), 13, Pal.ink(0.5), font_b, cw - 30.0)
		# a fourth entry: the figure as words (a count, not money), with no price scale under it
		var plain: bool = (cols[i] as Array).size() > 3
		_text(str(cols[i][3]) if plain else Pal.money(float(cols[i][1])), Vector2(cx + 16, r.position.y + 76), 36, Charcoal.ACCENT if i == hi else Pal.ink(0.96), font_l, cw - 26.0)
		if not plain:
			Charcoal.segments(self, Rect2(cx + 18, r.position.y + 90, cw - 40.0, 7.0), float(cols[i][1]) / maxf(top, 1.0) * 16.0, 16)
		_text(str(cols[i][2]), Vector2(cx + 18, r.end.y - 14), 12, Pal.ink(0.5), font_b, cw - 30.0)


func _order_for(u: Dictionary) -> Dictionary:
	var kind := HallMarket.kind_of(u)
	var cat := "raw" if str(u.cat) == "raw" else "equip"
	var best := {}
	for o in HallMarket.orders():
		if str(o.state) == "open" and str(o.kind) == kind and str(o.cat) == cat:
			var p := float(o.price) / maxf(float(o.n), 0.001) * (float(u.get("t", 1.0)) if cat == "raw" else 1.0)
			if best.is_empty() or p > float(best.price):
				best = {"price": snappedf(p, 1.0), "client": str(o.client)}
	return best


func _draw_curve(r: Rect2, kind: String, avg: float) -> void:
	# 炭黑: an oscilloscope window — a fine grid, ticks along its edges, the line in the accent
	Charcoal.display(self, r)
	for gi in range(1, 12):
		var gx := r.position.x + r.size.x * gi / 12.0
		draw_line(Vector2(gx, r.position.y + 4), Vector2(gx, r.end.y - 4), Color(1, 1, 1, 0.03), 1.0)
	for gj in range(1, 6):
		var gy := r.position.y + r.size.y * gj / 6.0
		draw_line(Vector2(r.position.x + 4, gy), Vector2(r.end.x - 4, gy), Color(1, 1, 1, 0.03), 1.0)
	for ti in range(0, 49):
		var tx := r.position.x + r.size.x * ti / 48.0
		draw_line(Vector2(tx, r.end.y - 4), Vector2(tx, r.end.y - (10.0 if ti % 4 == 0 else 6.0)), Color(1, 1, 1, 0.16), 1.0)
	var lo := 1.0 - HallMarket.DRIFT * 1.25
	var hi := 1.0 + HallMarket.DRIFT * 1.25
	var yof := func(f: float) -> float: return r.end.y - 18.0 - (f - lo) / (hi - lo) * (r.size.y - 36.0)
	# the ±10 % band and the average
	var band := Rect2(r.position.x, yof.call(1.0 + HallMarket.DRIFT), r.size.x, yof.call(1.0 - HallMarket.DRIFT) - yof.call(1.0 + HallMarket.DRIFT))
	draw_rect(band, Color(1, 1, 1, 0.018))
	var ay: float = yof.call(1.0)
	var dx := r.position.x
	while dx < r.end.x:
		draw_line(Vector2(dx, ay), Vector2(minf(dx + 8.0, r.end.x), ay), Pal.ink(0.35), 1.0)
		dx += 14.0
	_text(w("平均价格 %s", "AVERAGE %s") % Pal.money(avg), Vector2(r.position.x + 8.0, ay - 6.0), 12, Pal.ink(0.55), font_b)
	_text("+10%", Vector2(r.position.x + 8.0, band.position.y + 14.0), 11, Pal.ink(0.3), font_b)
	_text("−10%", Vector2(r.position.x + 8.0, band.end.y - 4.0), 11, Pal.ink(0.3), font_b)
	var pts := PackedVector2Array()
	var cv := HallMarket.curve(kind)
	var reveal := BenchFx.e_out4(clampf(_tab_t / 0.7, 0.0, 1.0)) if BenchFx.on() else 1.0
	var n := int(ceil(cv.size() * reveal))
	for i in n:
		var px := r.position.x + 70.0 + (r.size.x - 150.0) * float(i) / float(cv.size() - 1)
		pts.append(Vector2(px, yof.call(float(cv[i][1]))))
	if pts.size() >= 2:
		var fill := pts.duplicate()
		fill.append(Vector2(pts[pts.size() - 1].x, r.end.y - 1.0))
		fill.append(Vector2(pts[0].x, r.end.y - 1.0))
		var cols := PackedColorArray()
		for i in fill.size():
			cols.append(Color(1, 1, 1, 0.035 if i < pts.size() else 0.0))
		draw_polygon(fill, cols)
		draw_polyline(pts, Color(UiSkin.ACCENT, 0.9), 2.0, true)
	var now_f := HallMarket.drift(kind)
	if reveal >= 0.99:
		var np := Vector2(r.position.x + 70.0 + (r.size.x - 150.0), yof.call(now_f))
		var pulse := 0.5 + 0.5 * sin(_t * 4.0) if BenchFx.on() else 0.5
		draw_circle(np, 9.0 + 3.0 * pulse, Color(UiSkin.ACCENT, 0.15))
		draw_circle(np, 5.0, UiSkin.ACCENT)
		_text(Pal.money(avg * now_f), np + Vector2(14, 5), 15, Pal.ink(0.97), font_s)
	_text(w("30 分钟前", "30 MIN AGO"), Vector2(r.position.x + 60.0, r.end.y - 4.0), 11, Pal.ink(0.35), font_b)
	_text(w("当前时间", "NOW"), Vector2(r.end.x - 110.0, r.end.y - 4.0), 11, Pal.ink(0.35), font_b)
	var vs := HallMarket.vs_avg_text(kind)
	var col := UiSkin.ACCENT if now_f >= 1.005 else (Pal.heat(1.0, 1.1) if now_f <= 0.995 else Pal.ink(0.8))
	_text(vs, Vector2(r.end.x - 300.0, r.position.y + 24.0), 16, col, font_s, 290.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(w("市场价格会定期变化，每次浮动范围为 ±10%", "PRICES DRIFT WITHIN ±10%"), Vector2(r.end.x - 300.0, r.position.y + 44.0), 11, Pal.ink(0.4), font_b, 290.0, HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_slider(r: Rect2, u: Dictionary, mkt: float, avg: float) -> void:
	var price := snappedf(mkt * price_k, 1.0)
	var vs_mkt := roundi((price_k - 1.0) * 100.0)
	var vs_avg := roundi((price / maxf(avg, 1.0) - 1.0) * 100.0)
	var secs := HallMarket.fill_secs(price, mkt)
	_text(w("设置售价 %s", "ASKING  %s") % Pal.money(price), r.position + Vector2(0, 22), 22, Pal.ink(0.97), font_s)
	var rel := (w("比当前市场价格高 %d%%", "%d%% OVER THE MARKET NOW") % vs_mkt) if vs_mkt > 0 else ((w("比当前市场价格低 %d%%", "%d%% UNDER THE MARKET NOW") % -vs_mkt) if vs_mkt < 0 else w("与当前市场价格相同", "THE MARKET NOW"))
	var rel2 := (w("高于平均价格 %d%%", "%d%% OVER THE AVERAGE") % vs_avg) if vs_avg > 0 else ((w("低于平均价格 %d%%", "%d%% UNDER THE AVERAGE") % -vs_avg) if vs_avg < 0 else w("与平均价格相同", "THE AVERAGE"))
	_text("%s · %s · %s · %s" % [rel, rel2, HallMarket.eta_text(secs), w("到手 %s", "%s PAID") % Pal.money(HallMarket.net(price))], r.position + Vector2(220, 22), 14, Pal.ink(0.75), font_b, r.size.x - 220.0)
	var tr := Rect2(r.position.x + 52.0, r.position.y + 52.0, r.size.x - 104.0, 8.0)
	_btns["slider"] = tr
	draw_rect(tr, Color(1, 1, 1, 0.06))
	# the slow-to-fast scale under the track: the dearer, the slower
	for i in 21:
		var fx := tr.position.x + tr.size.x * i / 20.0
		draw_line(Vector2(fx, tr.end.y + 4.0), Vector2(fx, tr.end.y + (10.0 if i % 5 == 0 else 6.0)), Pal.ink(0.25), 1.0)
	var f := clampf((price_k - 0.8) / 0.5, 0.0, 1.0)
	var m_x := tr.position.x + tr.size.x * (1.0 - 0.8) / 0.5
	var a_x := tr.position.x + tr.size.x * clampf((avg / maxf(mkt, 1.0) - 0.8) / 0.5, 0.0, 1.0)
	draw_rect(Rect2(tr.position, Vector2(tr.size.x * f, tr.size.y)), Color(UiSkin.ACCENT, 0.55))
	draw_line(Vector2(m_x, tr.position.y - 8.0), Vector2(m_x, tr.end.y + 8.0), Pal.ink(0.7), 1.5)
	_text(w("当前市场价格", "MARKET"), Vector2(m_x - 40.0, tr.end.y + 26.0), 11, Pal.ink(0.6), font_b, 80.0, HORIZONTAL_ALIGNMENT_CENTER)
	draw_line(Vector2(a_x, tr.position.y - 6.0), Vector2(a_x, tr.end.y + 6.0), Pal.ink(0.4), 1.0)
	_text(w("平均成交价格", "AVG"), Vector2(a_x - 40.0, tr.position.y - 10.0), 11, Pal.ink(0.45), font_b, 80.0, HORIZONTAL_ALIGNMENT_CENTER)
	_text(w("预计出售较快", "SELLS FAST"), Vector2(tr.position.x, tr.end.y + 26.0), 11, Pal.ink(0.4), font_b)
	_text(w("预计出售较慢", "SELLS SLOW"), Vector2(tr.end.x - 80.0, tr.end.y + 26.0), 11, Pal.ink(0.4), font_b, 80.0, HORIZONTAL_ALIGNMENT_RIGHT)
	var hx := tr.position.x + tr.size.x * f
	draw_circle(Vector2(hx, tr.get_center().y), 11.0, Color(0.06, 0.07, 0.08))
	draw_arc(Vector2(hx, tr.get_center().y), 11.0, 0.0, TAU, 24, UiSkin.ACCENT, 2.0)
	_key("minus", Rect2(r.position.x, tr.position.y - 14.0, 40.0, 36.0), "−", w("降低价格 1%", "1% cheaper"))
	_key("plus", Rect2(tr.end.x + 12.0, tr.position.y - 14.0, 40.0, 36.0), "+", w("提高价格 1%", "1% dearer"))
	var by := r.position.y + 100.0
	_key("list", Rect2(r.position.x, by, 460.0, 50.0), w("按当前价格上架出售 %s [Enter]", "LIST AT THIS PRICE  %s  [Enter]") % Pal.money(price),
		w("将货物上架到交易行，成交后会扣除 5% 的手续费，剩余金额会转入账户", "Listed; paid less 5% on the sale"), "", true)
	_key("avg", Rect2(r.position.x + 476.0, by, 180.0, 50.0), w("使用平均价格", "AT THE AVERAGE"), w("将出售价格设置为市场平均价格", "Ask the average price"))
	_key("custom", Rect2(r.position.x + 672.0, by, 180.0, 50.0), w("关闭交易窗口 [Esc]", "CLOSE  [Esc]"), w("恢复为建议价格", "Back to the suggested price"))


func _draw_listings(r: Rect2) -> void:
	Charcoal.groove(self, r.position.x, r.end.x, r.position.y)
	var ls := HallMarket.listings()
	_text(w("当前有 %d 件商品正在出售", "LISTED: %d") % ls.size(), r.position + Vector2(0, 26), 15, Pal.ink(0.7), font_s)
	var sold: Array = HallMarket.data().get("sold", [])
	if not sold.is_empty():
		var s: Dictionary = sold[sold.size() - 1]
		_text(w("最近成交记录：%s %s（到账 %s）", "LAST SALE: %s %s (%s PAID)") % [str(s.name), Pal.money(float(s.price)), Pal.money(float(s.cash))], Vector2(r.position.x + 200.0, r.position.y + 26), 13, Pal.ink(0.5), font_b, r.size.x - 200.0)
	if ls.is_empty():
		_text(w("目前还没有上架的商品，选择一件商品后按 Enter 即可上架。", "NOTHING LISTED: PICK ONE ABOVE, ENTER TO LIST"), r.position + Vector2(0, 62), 13, Pal.ink(0.42), font_b)
		return
	var cw := (r.size.x - 24.0) / 3.0
	var fit_rows := maxi(1, int((r.size.y - 42.0) / 66.0))
	for i in mini(ls.size(), 3 * fit_rows):
		var l: Dictionary = ls[i]
		var cx := r.position.x + (i % 3) * (cw + 12.0)
		var cy := r.position.y + 42.0 + (i / 3) * 66.0
		var cr := Rect2(cx, cy, cw, 58.0)
		Charcoal.panel(self, cr, 1.0, 0.0, Charcoal.FACE_HI, 8)
		_text(str(l.name), cr.position + Vector2(12, 22), 13, Pal.ink(0.92), font_s, cw - 120.0)
		_text(w("当前出售价格 %s · %s", "%s · %s") % [Pal.money(float(l.price)), HallMarket.eta_text(HallMarket.listing_left(l))], cr.position + Vector2(12, 40), 11, Pal.ink(0.55), font_b, cw - 120.0)
		var pr := Rect2(cr.position.x + 12.0, cr.end.y - 9.0, cw - 124.0, 3.0)
		draw_rect(pr, Color(1, 1, 1, 0.06))
		draw_rect(Rect2(pr.position, Vector2(pr.size.x * clampf(float(l.prog), 0.0, 1.0), pr.size.y)), UiSkin.ACCENT)
		_key("x:" + str(l.id), Rect2(cr.end.x - 100.0, cr.position.y + 11.0, 88.0, 36.0), w("取消挂单", "WITHDRAW"), w("将这件商品从交易行撤下，商品会退回仓库。", "Withdraw: it comes back to the stores"))


# ---------------------------------------------------------------- 买

func _draw_buy() -> void:
	var top := _body_top()
	var lr := Rect2(PAD, top, LIST_W, size.y - top - 64.0)
	Charcoal.panel(self, lr, 1.0, 0.0, Charcoal.FACE, 14)
	_text(w("其他公司正在出售的商品", "OTHER COMPANIES' GOODS"), lr.position + Vector2(22, 36), 17, Pal.ink(0.85), font_s)
	Charcoal.groove(self, lr.position.x + 16, lr.end.x - 16, lr.position.y + 52)
	var offers := HallMarket.offers()
	var need := _repair_need()
	for i in offers.size():
		var of: Dictionary = offers[i]
		var rs := _rise(i)
		var r := Rect2(lr.position.x + 14.0, lr.position.y + 62.0 + i * ROW_H + float(rs[0]), lr.size.x - 28.0, ROW_H - 8.0)
		if r.end.y > lr.end.y - 4.0:
			break
		var id := "b:" + str(of.kind)
		_btns[id] = r
		_notes[id] = ["", ""]
		var on := str(of.kind) == buy_sel
		var a := float(rs[1])
		_row_key(r, on, float(_hov.get(id, 0.0)), a)
		var rr := Rect2(r.position + Vector2(0, 4.0 if on else 0.0), r.size)
		var rp := HallMarket.rep_piece(str(of.kind)) if str(of.cat) == "equip" else ["", "", 0.0]
		_thumb(Rect2(rr.position + Vector2(30, 6), Vector2(44, 44)), str(of.cat), str(rp[0]), str(rp[1]), str(of.kind), a)
		_text(str(of.name), rr.position + Vector2(86, 25), 15, Pal.ink(0.95 * a), font_s, 190.0)
		var sub := str(of.seller)
		if need.has(str(of.kind)):
			sub += w(" · 修缮时需要使用", " · FOR THE MENDING")
		_text(sub, rr.position + Vector2(86, 45), 12, Color(Charcoal.ACCENT, 0.85 * a) if need.has(str(of.kind)) else Pal.ink(0.5 * a), font_b, 190.0)
		var pw := Rect2(rr.end.x - 140.0, rr.position.y + 10.0, 128.0, rr.size.y - 20.0)
		Charcoal.display(self, pw, a, 5)
		_text("%s/%s" % [Pal.money(float(of.each)), str(of.unit)], pw.position + Vector2(0, pw.size.y * 0.5 + 6.0), 14, Pal.ink(0.95 * a), font_s, pw.size.x - 12.0, HORIZONTAL_ALIGNMENT_RIGHT)
	var dr := Rect2(lr.end.x + 24.0, top, size.x - PAD - lr.end.x - 24.0, lr.size.y)
	Charcoal.panel(self, dr, 1.0, 0.0, Charcoal.FACE, 14)
	var of2 := _offer(buy_sel)
	if of2.is_empty():
		return
	var sw := _swap_k()
	var x := dr.position.x + 28.0
	var wd := dr.size.x - 56.0
	var y := dr.position.y + float(sw[0])
	var steel := str(of2.cat) == "steel"
	var rp2 := HallMarket.rep_piece(buy_sel) if not steel else ["", "", 0.0]
	_thumb(Rect2(Vector2(x, y + 20), Vector2(64, 64)), str(of2.cat), str(rp2[0]), str(rp2[1]), buy_sel)
	_text(str(of2.name), Vector2(x + 84, y + 52), 28, Pal.ink(0.97), font_s, wd - 100.0)
	_text(w("出售方：%s", "SELLER %s") % str(of2.seller), Vector2(x + 84, y + 78), 14, Pal.ink(0.55), font_b)
	var own_v := RepairBill.STEEL_PRICE if steel else RepairBill.kind_price(buy_sel)
	var have := float(Career.data.get("structure_t", 0.0)) if steel else float(RepairBill.own_of(buy_sel).size())
	_price_window(Rect2(x, y + 100.0, wd, 132.0), [
		[w("售价", "PRICE"), float(of2.each), "/ %s" % str(of2.unit)],
		[w("自己拆船获得约", "YOUR OWN SALVAGE"), own_v, w("这里贵 %d%%", "%d%% DEARER HERE") % roundi((float(of2.each) / maxf(own_v, 1.0) - 1.0) * 100.0)],
		[w("仓库库存", "IN STORE"), have, w("修缮时会先用库存", "THE MENDING USES THESE FIRST"), (w("%.1f t", "%.1f t") % have) if steel else (w("%d 台", "%d") % int(have))]], 0)
	var ny := y + 262.0
	if steel:
		_text(w("修缮钢材按吨出售，购买后会存入仓库的修缮钢材区，修缮港区时会自动从库存中扣除", "Repair steel by the tonne, into the stores' repair steel slot; the works take from it"), Vector2(x, ny), 14, Pal.ink(0.6), font_b, wd)
		ny += 24.0
	need = _repair_need()
	if need.has(buy_sel):
		Charcoal.led(self, Vector2(x + 6, ny - 5), true, 1.0, 4.0)
		_text(str(need[buy_sel]), Vector2(x + 20, ny), 14, Pal.ink(0.9), font_b, wd - 20.0)
		ny += 24.0
	# how many: two big keycaps either side of a black window
	var qy := ny + 20.0
	var step := float(of2.get("step", 1.0))
	var n := float(buy_n) * step
	_key("bminus", Rect2(x, qy, 72.0, 72.0), "−", w("减少购买数量", "Fewer"))
	var qw := Rect2(x + 88.0, qy, 180.0, 72.0)
	Charcoal.display(self, qw)
	_text(w("数量", "QUANTITY"), qw.position + Vector2(14, 22), 12, Pal.ink(0.5), font_b)
	_text((("%.0f t" % n) if steel else ("× %d" % buy_n)), qw.position + Vector2(0, 58), 30, Pal.ink(0.97), font_l, qw.size.x - 16.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_key("bplus", Rect2(qw.end.x + 16.0, qy, 72.0, 72.0), "+", w("增加购买数量", "More"))
	var total := snappedf(float(of2.each) * n, 1.0)
	var cash := float(Career.data.get("money", 0.0))
	var tw := Rect2(qw.end.x + 108.0, qy, minf(300.0, wd - (qw.end.x + 108.0 - x)), 72.0)
	if tw.size.x > 160.0:
		Charcoal.display(self, tw)
		_text(w("合计", "TOTAL"), tw.position + Vector2(14, 22), 12, Pal.ink(0.5), font_b)
		_text(Pal.money(total), tw.position + Vector2(0, 58), 30, Pal.ink(0.97) if cash + 0.5 >= total else Pal.heat(1.0, 1.2), font_l, tw.size.x - 16.0, HORIZONTAL_ALIGNMENT_RIGHT)
	var why := "" if cash + 0.5 >= total else w("现金不足：- %s", "NOT ENOUGH CASH: %s SHORT") % Pal.money(total - cash)
	_key("buy", Rect2(x, qy + 96.0, minf(560.0, wd), 58.0), w("买下  %s  [Enter]", "BUY  %s  [Enter]") % Pal.money(total),
		w("确认付款后，购买的货物会存入仓库，仓库空间不足时，多余的货物会进入待入库区", "Paid at once; into the stores (what does not fit waits to be stored)"), why, true,
		w("付款前现金 %s，付款后剩余 %s", "CASH %s → %s") % [Pal.money(cash), Pal.money(cash - total)])


# kinds the next stage of a district needs and the stores lack: kind -> "修 贸易港 还缺 2 台"
func _repair_need() -> Dictionary:
	var out := {}
	for z in ["trade", "process", "cargo", "power", "tug"]:
		var b := RepairBill.of(z)
		for row in b.get("rows", []):
			if int(row.buy) > 0 and not out.has(str(row.nk)):
				out[str(row.nk)] = w("修缮%s还缺少 %d 台设备，购买后会在修缮时自动使用", "%s'S MENDING IS %d SHORT: BOUGHT, THE MENDING USES IT") % [Port.name_of(z), int(row.buy)]
		if float(b.get("steel", {}).get("buy", 0.0)) > 0.05 and not out.has(HallMarket.STEEL):
			out[HallMarket.STEEL] = w("修缮%s还需要 %.0f t 钢材", "%s'S MENDING IS %.0f t OF STEEL SHORT") % [Port.name_of(z), float(b.steel.buy)]
	return out


# ---------------------------------------------------------------- 订单

func _draw_orders() -> void:
	# 炭黑 v2: the orders as big numbered keys (01, 02 …), the offer in a black window, a lamp for the
	# state, the time left as a segment count-down, the key at the foot of the card
	var top := _body_top()
	var cards := _cards()
	var n := cards.size()
	var per := 4
	var gap := 22.0
	var cw := (size.x - PAD * 2.0 - (per - 1) * gap) / per
	var rows := maxi(1, ceili(n / float(per)))
	var ch := minf(470.0, (size.y - top - 110.0 - (rows - 1) * gap) / rows)
	for i in n:
		var cx := PAD + (i % per) * (cw + gap)
		var cy := top + (i / per) * (ch + gap)
		var rs := _rise(i)
		_order_card(Rect2(cx, cy + float(rs[0]), cw, ch), cards[i], float(rs[1]), i)
	var ny := top + rows * (ch + gap) + 22.0 if n > 0 else top + 40.0
	var s0 := maxf(0.0, float(HallMarket.data().get("next_order", 0.0)) - HallMarket.clock())
	var nl := (w("下一批订单预计 %d 秒后到达", "NEXT ORDER IN ~%d s") % int(ceil(s0))) if n < HallMarket.MAX_ORDERS else w("当前订单已达到上限，最多可以同时保留 %d 张订单", "FULL: UP TO %d ORDERS") % HallMarket.MAX_ORDERS
	Charcoal.led(self, Vector2(PAD + 6, ny - 6), n < HallMarket.MAX_ORDERS, 1.0, 4.0, Color(0.86, 0.88, 0.86))
	_text(nl, Vector2(PAD + 22, ny), 18, Pal.ink(0.55), font_b)


func _order_card(r: Rect2, o: Dictionary, a: float, idx := 0) -> void:
	var id := "o:" + str(o.id)
	_btns[id] = r
	_notes[id] = ["", ""]
	var on := str(o.id) == ord_sel
	var hv := float(_hov.get(id, 0.0))
	var st := str(o.state)
	var lit := st in ["taken", "rail", "ship"]
	var have := HallMarket.have_of(str(o.cat), str(o.kind))
	var ok := have >= float(o.n) - 0.0005
	r = Charcoal.key(self, r, a, 0.0, Charcoal.FACE_HI if on or hv > 0.5 else Charcoal.FACE, 14)
	if on:
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.set_corner_radius_all(14)
		ring.set_border_width_all(1)
		ring.anti_aliasing = true
		ring.border_color = Color(Charcoal.ACCENT, 0.8 * a)
		draw_style_box(ring, r)
	var x := r.position.x + 22.0
	var wd := r.size.x - 44.0
	# the big number, the lamp, who wants what
	_text("%02d" % (idx + 1), Vector2(x - 2, r.position.y + 62), 54, Color(Charcoal.ACCENT, a) if on else Pal.ink(0.9 * a), font_l)
	Charcoal.led(self, Vector2(r.end.x - 24.0, r.position.y + 26.0), lit or (st == "open" and ok), a, 5.0, Charcoal.ACCENT if lit else Color(0.86, 0.88, 0.86))
	var state_t: String = {"open": w("可接", "OPEN") if ok else w("缺货", "SHORT"), "taken": w("备货中", "MAKING UP"), "rail": w("运输中", "ON THE TRAIN"), "ship": w("待提货", "AT THE QUAY"), "done": w("已到账", "PAID")}.get(st, "")
	_text(str(state_t), Vector2(r.end.x - 120.0, r.position.y + 56), 12, Pal.ink(0.6 * a), font_b, 104.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(str(o.client), Vector2(x + 92, r.position.y + 34), 14, Pal.ink(0.55 * a), font_b, wd - 160.0)
	_text(HallMarket.want_name(o), Vector2(x + 92, r.position.y + 60), 20, Pal.ink(0.97 * a), font_s, wd - 100.0)
	var rp := HallMarket.rep_piece(str(o.kind)) if str(o.cat) == "equip" else ["", "", 0.0]
	# the offer in a black window, the market under it
	var pw := Rect2(x, r.position.y + 84.0, wd, 96.0)
	Charcoal.display(self, pw, a)
	_thumb(Rect2(pw.end.x - 74.0, pw.position.y + 14.0, 60, 60), str(o.cat), str(rp[0]), str(rp[1]), str(o.kind), a)
	_text(w("报价", "OFFER"), pw.position + Vector2(14, 24), 12, Pal.ink(0.5 * a), font_b)
	_text(Pal.money(float(o.price)), pw.position + Vector2(12, 64), 38, Pal.ink(0.97 * a), font_l, pw.size.x - 100.0)
	var base := HallMarket.want_base(str(o.cat), str(o.kind)) * float(o.n)
	_text(w("市价 %s · 高 %d%%", "MARKET %s · +%d%%") % [Pal.money(base), roundi((float(o.price) / maxf(base, 1.0) - 1.0) * 100.0)], pw.position + Vector2(14, 86), 12, Pal.ink(0.55 * a), font_b, pw.size.x - 100.0)
	var y := pw.end.y + 30.0
	if st == "open":
		var hs := (w("仓库当前库存：%.1f / %.0f t", "IN STORE %.1f / %.0f t") % [have, float(o.n)]) if str(o.cat) == "raw" else (w("仓库当前库存：%d / %d 台", "IN STORE %d / %d") % [int(have), int(o.n)])
		_text(hs, Vector2(x, y), 16, Pal.ink(0.95 * a) if ok else Pal.ink(0.6 * a), font_b, wd)
		# the time left: a segment count-down, orange in the last three minutes
		var left := float(o.due) - HallMarket.clock()
		var life := float(o.due) - float(o.at)
		var mins := HallMarket.mins_left(o)
		_text(w("剩余 %d 分钟，到时自动取消", "%d MIN LEFT · THEN IT LAPSES") % mins, Vector2(x, y + 30.0), 13, Color(Charcoal.ACCENT, a) if mins <= 3 else Pal.ink(0.55 * a), font_b, wd)
		var segs := clampi(int(ceil(life / 60.0)), 4, 20)
		Charcoal.segments(self, Rect2(x, y + 42.0, wd, 8.0), clampf(left / maxf(life, 1.0), 0.0, 1.0) * segs, segs, a if mins <= 3 else 0.55 * a)
		if not ok and not on:
			var ways := HallMarket.short_ways(o)
			if not ways.is_empty():
				_text(str(ways[0]), Vector2(x, y + 76.0), 13, Pal.ink(0.6 * a), font_b, wd)
	else:
		_pipeline(Rect2(x, y - 10.0, wd, 52.0), o, a)
		if not on:
			_text(w("不用额外操作，货款到账后会收到通知", "NOTHING TO DO: YOU WILL BE TOLD"), Vector2(x, y + 76.0), 13, Pal.ink(0.5 * a), font_b, wd)
	# the key at the foot: live on the picked card (orange), a dark cap on the others (a click picks)
	var kr := Rect2(x, r.end.y - 70.0, wd, 52.0)
	if on and st in ["open", "taken"]:
		var bl := w("接受订单 [Enter]", "TAKE  [Enter]") if st == "open" else w("取消订单", "GIVE BACK")
		var note := w("接受订单后，仓库会自动准备货物，备货完成后由货运火车送到贸易港，等待客户提货", "Take it: the stores make it up, the train takes it to the trade port, the client collects") if st == "open" else w("取消这张订单后，已经准备好的货物会退回仓库，不会收取罚款", "Give it back: the goods go back to the stores, no penalty")
		_key("take", kr, bl, note, "", st == "open")
		if str(o.cat) == "raw" and ProcessLine.mould_of_key(str(o.kind)) != "" and HallMarket.have_of("raw", str(o.kind)) + ProcessLine.for_order_t(str(o.id)) < float(o.n) - float(o.get("got", 0.0)) - 0.05:
			var why := "" if ProcessLine.first_done() or not ProcessLine.LEGACY_DESKS else w("第一次冶炼需要先到熔炉操作台亲自完成", "MAKE THE FIRST HEAT BY HAND FIRST")
			_key("plan", Rect2(x, kr.position.y - 54.0, wd, 44.0), w("为这张订单安排生产 · %s模具", "PLAN FOR THIS ORDER · %s") % ProcessLine.mould_name(ProcessLine.mould_of_key(str(o.kind))), w("将仓库里的钢锭安排到加工队列最前面，使用%s模具加工成订单需要的货物", "Puts ingots first in the processing queue, cast as the order wants") % StoreBook.raw_name(str(o.kind)), why)
	elif st == "open":
		var fk := Charcoal.panel(self, kr, 0.7 * a, 0.0, Charcoal.FACE, 8)
		_text(w("选中后接受订单", "PICK TO TAKE"), fk.position + Vector2(0, 33), 15, Pal.ink(0.5 * a), font_b, fk.size.x, HORIZONTAL_ALIGNMENT_CENTER)


# a taken order's way: 备货 → 火车 → 客户飞船 → 到账, the step it is on lit
func _pipeline(r: Rect2, o: Dictionary, a: float) -> void:
	var steps := [w("正在准备货物", "MAKE UP"), w("货运火车运输中", "TRAIN"), w("等待客户飞船提货", "CLIENT SHIP"), w("等待货款到账", "PAID")]
	var at: int = {"taken": 0, "rail": 1, "ship": 2, "done": 3}.get(str(o.state), 0)
	var sx := (r.size.x - 20.0) / 3.0
	for i in 4:
		var p := Vector2(r.position.x + 10.0 + i * sx, r.position.y + 10.0)
		if i < 3:
			draw_line(p, p + Vector2(sx, 0), Color(UiSkin.ACCENT, 0.8 * a) if i < at else Pal.ink(0.15 * a), 2.0)
			if i == at and BenchFx.on():
				var u := fmod(_t * 0.6, 1.0)
				draw_circle(p + Vector2(sx * u, 0), 3.0, Color(UiSkin.ACCENT, a))
		var done := i < at or str(o.state) == "done"
		var cur := i == at and str(o.state) != "done"
		draw_circle(p, 6.0, Color(UiSkin.ACCENT, a) if done else Color(0.06, 0.07, 0.08, a))
		draw_arc(p, 6.0 + (2.0 * sin(_t * 5.0) if cur and BenchFx.on() else 0.0), 0.0, TAU, 18, Color(UiSkin.ACCENT, a) if done or cur else Pal.ink(0.3 * a), 1.5)
		_text(str(steps[i]), p + Vector2(-40, 26), 11, Pal.ink((0.9 if done or cur else 0.4) * a), font_b, 80.0, HORIZONTAL_ALIGNMENT_CENTER)
	_text(HallMarket.order_state_text(o), Vector2(r.position.x, r.end.y + 12.0), 12, Pal.ink(0.7 * a), font_b, r.size.x)


# ---------------------------------------------------------------- the foot: the toast

func _draw_foot() -> void:
	var y := size.y - 34.0
	if _msg_t > 0.0 and message != "":
		var k := clampf(_msg_t / 0.35, 0.0, 1.0) * clampf((4.0 - _msg_t) / 0.3, 0.0, 1.0) if BenchFx.on() else 1.0
		var tw := font_b.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 48.0
		var r := Rect2(Vector2((size.x - tw) * 0.5 + (1.0 - k) * 60.0, y - 30.0), Vector2(tw, 40.0))
		draw_rect(r, Color(0.06, 0.07, 0.08, 0.96 * k))
		draw_rect(Rect2(r.position, Vector2(4, r.size.y)), (Pal.heat(k, 1.1) if _msg_bad else Color(UiSkin.ACCENT, k)))
		draw_rect(r, Pal.ink(0.2 * k), false, 1.0)
		draw_rect(Rect2(r.position.x, r.end.y - 2.0, r.size.x * clampf(_msg_t / 4.0, 0.0, 1.0), 2.0), Color(UiSkin.FIGURE, 0.6 * k))
		_text(message, r.position + Vector2(24, 26), 16, Pal.ink(0.97 * k), font_b)
	else:
		var esc := (w("Esc 返回%s", "ESC: BACK TO %s") % Back.label()) if Back.has_back() else w("Esc 关闭界面", "ESC: CLOSE")
		_text({"sell": w("Enter 确认挂单 · ", "ENTER: LIST · "), "buy": w("Enter 确认购买 · ", "ENTER: BUY · "), "orders": w("Enter 接受订单 · ", "ENTER: TAKE · ")}.get(tab, "") + esc, Vector2(PAD, y), 16, Pal.ink(0.4), font_b)


# 人性化 规则 4: a key's plain note after 0.4 s by the pointer; a shut one says why
func _draw_note() -> void:
	if hover == "" or _hover_t < BenchFx.NOTE_S or not _notes.has(hover):
		return
	var n: Array = _notes[hover]
	var s := str(n[0])
	if str(n[1]) != "":
		s = (s + "\n" if s != "" else "") + str(n[1])
	if s == "":
		return
	BenchFx.draw_note(self, s, get_local_mouse_position(), size)
