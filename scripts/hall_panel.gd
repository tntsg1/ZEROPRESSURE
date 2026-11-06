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
const TAB_H := 44.0
const LIST_W := 520.0
const ROW_H := 64.0
const BG := Color(0.035, 0.04, 0.048)
const TABS := ["sell", "buy", "orders"]

var game
var on_close: Callable
var start_tab := ""
var start_pick := ""
var back_to_store := false
var tab := "sell"
var font: Font
var font_b: Font
var font_s: Font
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
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
	font_s = Fonts.get_font("SemiBold")
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


func _cards() -> Array:
	return HallMarket.orders().filter(func(o): return str(o.state) != "gone")


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
	if back and g != null and is_instance_valid(g) and g.has_method("open_store"):
		(func(): g.open_store()).call_deferred()


# ---------------------------------------------------------------- doing it

func list_now() -> void:
	var u := _unit(sel)
	if u.is_empty():
		_say(w("仓库里没有能挂单的东西", "NOTHING IN STORE TO LIST"), true)
		return
	var price := -1.0 if not custom else HallMarket.market_now(u) * price_k
	var r := HallMarket.list(sel, price)
	if not r.ok:
		_say(str(r.reason), true)
		return
	_say(w("挂到交易行：%s · 要价 %s · %s，成交后到账 %s（扣 5%% 手续费）", "LISTED: %s · ASKING %s · %s, %s PAID ON THE SALE (LESS 5%%)") % [str(r.name), Pal.money(float(r.price)), HallMarket.eta_text(float(r.secs)), Pal.money(float(r.net))])
	custom = false
	price_k = 1.0
	sel = ""
	_refresh()


func cancel_listing(lid: String) -> void:
	var r := HallMarket.cancel(lid)
	if not r.ok:
		_say(str(r.reason), true)
		return
	_say(w("撤下挂单：%s 回到仓库", "WITHDRAWN: %s IS BACK IN STORE") % str(r.name))
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
	_say(w("买下 %s · 付了 %s · %s", "BOUGHT %s · PAID %s · %s") % [str(r.name), Pal.money(float(r.cash)), str(r.where)])
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
				_say(w("接了 %s 的订单：仓库里都有，已备好，货运火车送往贸易港", "TOOK %s'S ORDER: ALL IN STORE, ON THE FREIGHT TRAIN TO THE TRADE PORT") % str(r.client))
			else:
				_say(w("接了 %s 的订单：仓库自动备货，缺的入库后自动补上", "TOOK %s'S ORDER: THE STORES MAKE IT UP, THE REST AS IT COMES IN") % str(r.client))
		"taken":
			var r2 := HallMarket.drop(ord_sel)
			if not r2.ok:
				_say(str(r2.reason), true)
				return
			_say(w("退了这张订单：备好的货放回仓库，没有罚款", "ORDER GIVEN BACK: THE GOODS ARE BACK IN STORE, NO PENALTY"))
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
		close()
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


# ---------------------------------------------------------------- input

func _slider_rect() -> Rect2:
	return _btns.get("slider", Rect2())


func _set_from_slider(x: float) -> void:
	var r := _slider_rect()
	if r.size.x <= 0.0:
		return
	var f := clampf((x - r.position.x) / r.size.x, 0.0, 1.0)
	price_k = snappedf(lerpf(0.8, 1.3, f), 0.005)


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
				for id in _btns:
					if id != "slider" and (_btns[id] as Rect2).has_point(ev.position):
						_press(str(id))
						break
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
			else:
				close()
		KEY_ENTER, KEY_KP_ENTER:
			_primary()
		KEY_TAB:
			set_tab(TABS[(TABS.find(tab) + 1) % TABS.size()])
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
	var h := ""
	for id in _btns:
		if id != "slider" and (_btns[id] as Rect2).has_point(m):
			h = str(id)
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
	draw_string(f if f != null else font_b, p, s, al, wmax, px, col)


func _glass(r: Rect2, k := 1.0) -> void:
	draw_rect(r, Color(0.06, 0.07, 0.08, 0.72 * k))
	draw_texture_rect(CodexFx.rows_tex(), r, true, Color(1, 1, 1, 0.02 * k))
	draw_rect(r, Pal.ink(0.14 * k), false, 1.0)
	draw_line(r.position + Vector2(1, 1), Vector2(r.end.x - 1, r.position.y + 1), Color(1, 1, 1, 0.14 * k), 1.0)
	draw_line(r.position + Vector2(1, 1), Vector2(r.position.x + 1, r.end.y - 1), Color(1, 1, 1, 0.05 * k), 1.0)


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
	var acc := UiSkin.ACCENT
	if primary and not shut:
		var br := 0.5 + 0.5 * sin(_t * TAU / 2.4) if BenchFx.on() else 0.5
		draw_rect(rr, Color(acc, 0.2 + 0.12 * hv))
		draw_rect(rr, Color(acc, 0.75 + 0.25 * maxf(hv, br * 0.6)), false, 1.4 + hv)
	else:
		draw_rect(rr, Color(1, 1, 1, (0.02 if shut else 0.04) + 0.05 * hv))
		draw_rect(rr, Pal.ink((0.16 if shut else 0.32) + 0.3 * hv), false, 1.0)
	if _flash.has(id) and BenchFx.on():
		var age := BenchFx.now() - float(_flash[id])
		if age < 0.35:
			draw_rect(rr.grow(age * 14.0), Color(acc, 0.35 * (1.0 - age / 0.35)), false, 1.5)
	var px := 16 if primary else 14
	var ty := rr.position.y + (rr.size.y * 0.5 + 6.0 if sub == "" else rr.size.y * 0.5 - 2.0)
	_text(label, Vector2(rr.position.x, ty), px, Pal.ink(0.45 if shut else 0.96), font_s if primary else font_b, rr.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	if sub != "":
		_text(sub, Vector2(rr.position.x, ty + 18.0), 11, Pal.ink(0.4 if shut else 0.62), font_b, rr.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _tab_rect(i: int) -> Rect2:
	return Rect2(PAD + i * 190.0, TAB_Y, 180.0, TAB_H)


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
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)]), PackedColorArray([Color(0.5, 0.6, 0.7, 0.04), Color(0.5, 0.6, 0.7, 0.04), Color(0, 0, 0, 0.25), Color(0, 0, 0, 0.25)]))
	_draw_head()
	_draw_tabs()
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
	var line := w("挂单中 %d 件 · 订单 %d/%d 张 · %s", "%d LISTED · %d/%d ORDERS · %s") % [nl, no, HallMarket.MAX_ORDERS, HallMarket.level_text()]
	_text(line, Vector2(PAD + 16, 104), 18, Pal.ink(0.88), font_b)
	_text(w("资金", "CASH"), Vector2(size.x - PAD - 180.0 - 220.0, 58), 13, Pal.ink(0.5), font_b, 200.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(Pal.money(roundf(_cash_shown)), Vector2(size.x - PAD - 180.0 - 220.0, 88), 24, Pal.ink(0.95), font_s, 200.0, HORIZONTAL_ALIGNMENT_RIGHT)
	var back := w("回仓库  [Esc]", "BACK TO STORES  [Esc]") if back_to_store else w("关闭  [Esc]", "CLOSE  [Esc]")
	_key("close", Rect2(size.x - PAD - 170.0, 48, 170.0, 46.0), back, w("关掉交易行", "Close the exchange") if not back_to_store else w("回到仓库页", "Back to the stores page"))
	draw_line(Vector2(PAD, HEAD_H), Vector2(size.x - PAD, HEAD_H), Pal.ink(0.12), 1.0)


func _draw_tabs() -> void:
	var names := {"sell": w("卖", "SELL"), "buy": w("买", "BUY"), "orders": w("订单", "ORDERS")}
	var notes := {"sell": w("把仓库里的东西挂到交易行，按真实时间成交", "List what is in store; it sells in real time"),
		"buy": w("买别家公司的设备和钢材，比自己拆的贵", "Buy other companies' machines and steel, dearer than your own"),
		"orders": w("客户点名要的货，市价的 130% 起", "What clients ask for, from 130% of market")}
	for i in TABS.size():
		var id := str(TABS[i])
		var r := _tab_rect(i)
		_btns["tab:" + id] = r
		_notes["tab:" + id] = [str(notes[id]), ""]
		var on := id == tab
		var hv := float(_hov.get("tab:" + id, 0.0))
		draw_rect(r, Color(1, 1, 1, 0.06 if on else 0.02 + 0.04 * hv))
		var label := str(names[id])
		if id == "sell" and HallMarket.listings().size() > 0:
			label += "  ·  %d" % HallMarket.listings().size()
		if id == "orders":
			var open_n := HallMarket.orders().filter(func(o): return str(o.state) == "open").size()
			if open_n > 0:
				label += "  ·  %d" % open_n
		_text(label, r.position + Vector2(0, 29), 17, Pal.ink(0.97 if on else 0.6 + 0.3 * hv), font_s if on else font_b, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	# the underline slides, with a glow under it
	var ir := Rect2(_ink_x, TAB_Y + TAB_H - 3.0, 180.0, 3.0)
	draw_rect(ir.grow_individual(0, 4, 0, 0), Color(UiSkin.ACCENT, 0.12))
	draw_rect(ir, UiSkin.ACCENT)
	_text(w("Tab 换页", "TAB: NEXT PAGE"), Vector2(size.x - PAD - 300.0, TAB_Y + 28.0), 12, Pal.ink(0.35), font_b, 300.0, HORIZONTAL_ALIGNMENT_RIGHT)
	draw_line(Vector2(PAD, TAB_Y + TAB_H), Vector2(size.x - PAD, TAB_Y + TAB_H), Pal.ink(0.1), 1.0)


func _body_top() -> float:
	return TAB_Y + TAB_H + 20.0


func _swap_k() -> Array:
	if not BenchFx.on():
		return [0.0, 1.0]
	var k := BenchFx.e_out(clampf(_tab_t / BenchFx.SWAP_S, 0.0, 1.0))
	return [(1.0 - k) * 8.0, k]


# ---------------------------------------------------------------- 卖

func _draw_sell() -> void:
	var top := _body_top()
	var lr := Rect2(PAD, top, LIST_W, size.y - top - 70.0)
	_glass(lr)
	_text(w("仓库里能卖的", "IN STORE, FOR SALE"), lr.position + Vector2(18, 30), 15, Pal.ink(0.7), font_s)
	var y0 := lr.position.y + 48.0
	var vis_h := lr.size.y - 56.0
	var maxs := maxf(0.0, _units.size() * ROW_H - vis_h)
	scroll.sell = clampf(float(scroll.sell), 0.0, maxs)
	if _units.is_empty():
		_text(w("仓库是空的：拆船带回来的东西会进这里", "THE STORES ARE EMPTY: WHAT YOU BRING HOME COMES HERE"), lr.position + Vector2(18, 80), 14, Pal.ink(0.5), font_b, lr.size.x - 36.0)
	for i in _units.size():
		var u: Dictionary = _units[i]
		var ry := y0 + i * ROW_H - float(scroll.sell)
		if ry < y0 - 1.0 or ry + ROW_H > lr.end.y - 4.0:
			continue
		var rs := _rise(i)
		var r := Rect2(lr.position.x + 10.0, ry + float(rs[0]), lr.size.x - 20.0, ROW_H - 6.0)
		var id := "u:" + str(u.id)
		_btns[id] = r
		_notes[id] = ["", ""]
		var on := str(u.id) == sel
		var hv := float(_hov.get(id, 0.0))
		var a := float(rs[1])
		draw_rect(r, Color(UiSkin.ACCENT, 0.14 * a) if on else Color(1, 1, 1, (0.02 + 0.05 * hv) * a))
		if on:
			draw_rect(Rect2(r.position, Vector2(3, r.size.y)), Color(UiSkin.ACCENT, a))
		_u_thumb(Rect2(r.position + Vector2(10, 5), Vector2(48, 48)), u, a)
		_text(str(u.name), r.position + Vector2(72, 25), 15, Pal.ink(0.95 * a), font_s, 260.0)
		_text("%s · %s" % [str(u.get("qty", "")), StoreBook.cat_name(str(u.cat))], r.position + Vector2(72, 46), 12, Pal.ink(0.5 * a), font_b, 260.0)
		_text(w("约 %s", "~%s") % Pal.money(HallMarket.net(HallMarket.market_now(u))), r.position + Vector2(r.size.x - 160.0, 33), 15, Pal.ink(0.9 * a), font_b, 148.0, HORIZONTAL_ALIGNMENT_RIGHT)
	if maxs > 0.0:
		var bar_h := vis_h * vis_h / (vis_h + maxs)
		draw_rect(Rect2(lr.end.x - 5.0, y0 + (vis_h - bar_h) * float(scroll.sell) / maxs, 3.0, bar_h), Pal.ink(0.25))
	var dr := Rect2(lr.end.x + 20.0, top, size.x - PAD - lr.end.x - 20.0, size.y - top - 70.0)
	_glass(dr)
	var sw := _swap_k()
	var x := dr.position.x + 28.0
	var y := dr.position.y + 44.0 + float(sw[0])
	var u := _unit(sel)
	if u.is_empty():
		_text(w("在左边点一件东西", "PICK SOMETHING ON THE LEFT"), Vector2(x, y + 20), 18, Pal.ink(0.5), font_b)
	else:
		var kind := HallMarket.kind_of(u)
		var mkt := HallMarket.market_now(u)
		var avg := float(u.market)
		_u_thumb(Rect2(Vector2(x, y - 26), Vector2(72, 72)), u)
		_text(str(u.name), Vector2(x + 90, y + 2), 26, Pal.ink(0.97), font_s, dr.size.x - 140.0)
		_text("%s · %s" % [str(u.get("qty", "")), StoreBook.cat_name(str(u.cat))], Vector2(x + 90, y + 30), 14, Pal.ink(0.55), font_b)
		# the price ladder in one line (§四)
		var of := _order_for(u)
		var ladder := w("回收站 %s · 交易行约 %s · 订单 %s", "RECYCLING %s · EXCHANGE ~%s · ORDER %s") % [Pal.money(float(u.recycle)), Pal.money(HallMarket.net(mkt)), Pal.money(float(of.price)) if not of.is_empty() else w("约 %s（现在没人要）", "~%s (NONE WANT IT NOW)") % Pal.money(avg * HallMarket.ORDER_K)]
		_text(ladder, Vector2(x, y + 76), 16, Pal.ink(0.85), font_b, dr.size.x - 56.0)
		# the price curve
		var cr := Rect2(x, y + 100.0, dr.size.x - 56.0, 230.0)
		_draw_curve(cr, kind, avg)
		var by := cr.end.y + 26.0
		if not custom:
			_key("list", Rect2(x, by, 520.0, 58.0), w("按建议价挂单  %s  [Enter]", "LIST AT THE SUGGESTED PRICE  %s  [Enter]") % Pal.money(mkt),
				w("挂到交易行：要价就是现在的市价，成交后扣 5% 手续费到账", "Listed at the market now; paid less 5% on the sale"), "", true,
				w("到账 %s · %s", "%s PAID · %s") % [Pal.money(HallMarket.net(mkt)), HallMarket.eta_text(HallMarket.fill_secs(mkt, mkt))])
			_key("custom", Rect2(x + 536.0, by, 220.0, 58.0), w("自己定价…", "SET MY OWN PRICE…"), w("打开价格滑条：要价高卖得慢，低卖得快", "Open the price slider: dearer sells slower, cheaper faster"))
		else:
			_draw_slider(Rect2(x, by - 6.0, dr.size.x - 56.0, 150.0), u, mkt, avg)
	# what is listed
	_draw_listings(Rect2(dr.position.x + 28.0, dr.end.y - 190.0, dr.size.x - 56.0, 176.0))


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
	draw_rect(r, Color(0, 0, 0, 0.25))
	draw_rect(r, Pal.ink(0.1), false, 1.0)
	var lo := 1.0 - HallMarket.DRIFT * 1.25
	var hi := 1.0 + HallMarket.DRIFT * 1.25
	var yof := func(f: float) -> float: return r.end.y - 18.0 - (f - lo) / (hi - lo) * (r.size.y - 36.0)
	# the ±10 % band and the average
	var band := Rect2(r.position.x, yof.call(1.0 + HallMarket.DRIFT), r.size.x, yof.call(1.0 - HallMarket.DRIFT) - yof.call(1.0 + HallMarket.DRIFT))
	draw_rect(band, Color(1, 1, 1, 0.025))
	var ay: float = yof.call(1.0)
	var dx := r.position.x
	while dx < r.end.x:
		draw_line(Vector2(dx, ay), Vector2(minf(dx + 8.0, r.end.x), ay), Pal.ink(0.35), 1.0)
		dx += 14.0
	_text(w("平均 %s", "AVERAGE %s") % Pal.money(avg), Vector2(r.position.x + 8.0, ay - 6.0), 12, Pal.ink(0.55), font_b)
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
			cols.append(Color(UiSkin.ACCENT, 0.09 if i < pts.size() else 0.0))
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
	_text(w("现在", "NOW"), Vector2(r.end.x - 110.0, r.end.y - 4.0), 11, Pal.ink(0.35), font_b)
	var vs := HallMarket.vs_avg_text(kind)
	var col := UiSkin.ACCENT if now_f >= 1.005 else (Pal.heat(1.0, 1.1) if now_f <= 0.995 else Pal.ink(0.8))
	_text(vs, Vector2(r.end.x - 300.0, r.position.y + 24.0), 16, col, font_s, 290.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(w("价格每隔一阵在 ±10% 之间浮动", "PRICES DRIFT WITHIN ±10%"), Vector2(r.end.x - 300.0, r.position.y + 44.0), 11, Pal.ink(0.4), font_b, 290.0, HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_slider(r: Rect2, u: Dictionary, mkt: float, avg: float) -> void:
	var price := snappedf(mkt * price_k, 1.0)
	var vs_mkt := roundi((price_k - 1.0) * 100.0)
	var vs_avg := roundi((price / maxf(avg, 1.0) - 1.0) * 100.0)
	var secs := HallMarket.fill_secs(price, mkt)
	_text(w("要价  %s", "ASKING  %s") % Pal.money(price), r.position + Vector2(0, 22), 22, Pal.ink(0.97), font_s)
	var rel := (w("比现在市价高 %d%%", "%d%% OVER THE MARKET NOW") % vs_mkt) if vs_mkt > 0 else ((w("比现在市价低 %d%%", "%d%% UNDER THE MARKET NOW") % -vs_mkt) if vs_mkt < 0 else w("就是现在的市价", "THE MARKET NOW"))
	var rel2 := (w("比平均高 %d%%", "%d%% OVER THE AVERAGE") % vs_avg) if vs_avg > 0 else ((w("比平均低 %d%%", "%d%% UNDER THE AVERAGE") % -vs_avg) if vs_avg < 0 else w("和平均一样", "THE AVERAGE"))
	_text("%s · %s · %s · %s" % [rel, rel2, HallMarket.eta_text(secs), w("到账 %s", "%s PAID") % Pal.money(HallMarket.net(price))], r.position + Vector2(220, 22), 14, Pal.ink(0.75), font_b, r.size.x - 220.0)
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
	_text(w("市价", "MARKET"), Vector2(m_x - 40.0, tr.end.y + 26.0), 11, Pal.ink(0.6), font_b, 80.0, HORIZONTAL_ALIGNMENT_CENTER)
	draw_line(Vector2(a_x, tr.position.y - 6.0), Vector2(a_x, tr.end.y + 6.0), Pal.ink(0.4), 1.0)
	_text(w("平均", "AVG"), Vector2(a_x - 40.0, tr.position.y - 10.0), 11, Pal.ink(0.45), font_b, 80.0, HORIZONTAL_ALIGNMENT_CENTER)
	_text(w("卖得快", "SELLS FAST"), Vector2(tr.position.x, tr.end.y + 26.0), 11, Pal.ink(0.4), font_b)
	_text(w("卖得慢", "SELLS SLOW"), Vector2(tr.end.x - 80.0, tr.end.y + 26.0), 11, Pal.ink(0.4), font_b, 80.0, HORIZONTAL_ALIGNMENT_RIGHT)
	var hx := tr.position.x + tr.size.x * f
	draw_circle(Vector2(hx, tr.get_center().y), 11.0, Color(0.06, 0.07, 0.08))
	draw_arc(Vector2(hx, tr.get_center().y), 11.0, 0.0, TAU, 24, UiSkin.ACCENT, 2.0)
	_key("minus", Rect2(r.position.x, tr.position.y - 14.0, 40.0, 36.0), "−", w("便宜 1%", "1% cheaper"))
	_key("plus", Rect2(tr.end.x + 12.0, tr.position.y - 14.0, 40.0, 36.0), "+", w("贵 1%", "1% dearer"))
	var by := r.position.y + 100.0
	_key("list", Rect2(r.position.x, by, 460.0, 50.0), w("按这个价挂单  %s  [Enter]", "LIST AT THIS PRICE  %s  [Enter]") % Pal.money(price),
		w("挂到交易行：成交后扣 5% 手续费到账", "Listed; paid less 5% on the sale"), "", true)
	_key("avg", Rect2(r.position.x + 476.0, by, 180.0, 50.0), w("按平均价", "AT THE AVERAGE"), w("要价设成平均价", "Ask the average price"))
	_key("custom", Rect2(r.position.x + 672.0, by, 180.0, 50.0), w("收起  [Esc]", "CLOSE  [Esc]"), w("回到按建议价挂单", "Back to the suggested price"))


func _draw_listings(r: Rect2) -> void:
	draw_line(r.position, Vector2(r.end.x, r.position.y), Pal.ink(0.1), 1.0)
	var ls := HallMarket.listings()
	_text(w("挂单中 %d 件", "LISTED: %d") % ls.size(), r.position + Vector2(0, 26), 15, Pal.ink(0.7), font_s)
	var sold: Array = HallMarket.data().get("sold", [])
	if not sold.is_empty():
		var s: Dictionary = sold[sold.size() - 1]
		_text(w("最近成交：%s %s（到账 %s）", "LAST SALE: %s %s (%s PAID)") % [str(s.name), Pal.money(float(s.price)), Pal.money(float(s.cash))], Vector2(r.position.x + 200.0, r.position.y + 26), 13, Pal.ink(0.5), font_b, r.size.x - 200.0)
	if ls.is_empty():
		_text(w("还没有挂单：在上面挑一件，按 Enter 一键挂单", "NOTHING LISTED: PICK ONE ABOVE, ENTER TO LIST"), r.position + Vector2(0, 62), 13, Pal.ink(0.42), font_b)
		return
	var cw := (r.size.x - 24.0) / 3.0
	for i in mini(ls.size(), 6):
		var l: Dictionary = ls[i]
		var cx := r.position.x + (i % 3) * (cw + 12.0)
		var cy := r.position.y + 42.0 + (i / 3) * 66.0
		var cr := Rect2(cx, cy, cw, 58.0)
		draw_rect(cr, Color(1, 1, 1, 0.03))
		draw_rect(cr, Pal.ink(0.14), false, 1.0)
		_text(str(l.name), cr.position + Vector2(12, 22), 13, Pal.ink(0.92), font_s, cw - 120.0)
		_text(w("要价 %s · %s", "%s · %s") % [Pal.money(float(l.price)), HallMarket.eta_text(HallMarket.listing_left(l))], cr.position + Vector2(12, 40), 11, Pal.ink(0.55), font_b, cw - 120.0)
		var pr := Rect2(cr.position.x + 12.0, cr.end.y - 9.0, cw - 124.0, 3.0)
		draw_rect(pr, Color(1, 1, 1, 0.06))
		draw_rect(Rect2(pr.position, Vector2(pr.size.x * clampf(float(l.prog), 0.0, 1.0), pr.size.y)), UiSkin.ACCENT)
		_key("x:" + str(l.id), Rect2(cr.end.x - 100.0, cr.position.y + 11.0, 88.0, 36.0), w("撤单", "WITHDRAW"), w("撤下挂单，东西回到仓库", "Withdraw: it comes back to the stores"))


# ---------------------------------------------------------------- 买

func _draw_buy() -> void:
	var top := _body_top()
	var lr := Rect2(PAD, top, LIST_W, size.y - top - 70.0)
	_glass(lr)
	_text(w("别家公司挂着的货", "OTHER COMPANIES' GOODS"), lr.position + Vector2(18, 30), 15, Pal.ink(0.7), font_s)
	var offers := HallMarket.offers()
	var need := _repair_need()
	for i in offers.size():
		var of: Dictionary = offers[i]
		var rs := _rise(i)
		var r := Rect2(lr.position.x + 10.0, lr.position.y + 48.0 + i * ROW_H + float(rs[0]), lr.size.x - 20.0, ROW_H - 6.0)
		if r.end.y > lr.end.y - 4.0:
			break
		var id := "b:" + str(of.kind)
		_btns[id] = r
		_notes[id] = ["", ""]
		var on := str(of.kind) == buy_sel
		var hv := float(_hov.get(id, 0.0))
		var a := float(rs[1])
		draw_rect(r, Color(UiSkin.ACCENT, 0.14 * a) if on else Color(1, 1, 1, (0.02 + 0.05 * hv) * a))
		if on:
			draw_rect(Rect2(r.position, Vector2(3, r.size.y)), Color(UiSkin.ACCENT, a))
		var rp := HallMarket.rep_piece(str(of.kind)) if str(of.cat) == "equip" else ["", "", 0.0]
		_thumb(Rect2(r.position + Vector2(10, 5), Vector2(48, 48)), str(of.cat), str(rp[0]), str(rp[1]), str(of.kind), a)
		_text(str(of.name), r.position + Vector2(72, 25), 15, Pal.ink(0.95 * a), font_s, 230.0)
		var sub := str(of.seller)
		if need.has(str(of.kind)):
			sub += w(" · 修缮要用", " · FOR THE MENDING")
		_text(sub, r.position + Vector2(72, 46), 12, Color(UiSkin.ACCENT, 0.8 * a) if need.has(str(of.kind)) else Pal.ink(0.5 * a), font_b, 260.0)
		_text("%s / %s" % [Pal.money(float(of.each)), str(of.unit)], r.position + Vector2(r.size.x - 170.0, 33), 15, Pal.ink(0.9 * a), font_b, 158.0, HORIZONTAL_ALIGNMENT_RIGHT)
	var dr := Rect2(lr.end.x + 20.0, top, size.x - PAD - lr.end.x - 20.0, size.y - top - 70.0)
	_glass(dr)
	var of2 := _offer(buy_sel)
	if of2.is_empty():
		return
	var sw := _swap_k()
	var x := dr.position.x + 28.0
	var y := dr.position.y + 44.0 + float(sw[0])
	var steel := str(of2.cat) == "steel"
	var rp2 := HallMarket.rep_piece(buy_sel) if not steel else ["", "", 0.0]
	_thumb(Rect2(Vector2(x, y - 26), Vector2(96, 96)), str(of2.cat), str(rp2[0]), str(rp2[1]), buy_sel)
	_text(str(of2.name), Vector2(x + 116, y + 4), 26, Pal.ink(0.97), font_s)
	_text(w("卖家 %s", "SELLER %s") % str(of2.seller), Vector2(x + 116, y + 32), 14, Pal.ink(0.55), font_b)
	var own_v := RepairBill.STEEL_PRICE if steel else RepairBill.kind_price(buy_sel)
	var dear := roundi((float(of2.each) / maxf(own_v, 1.0) - 1.0) * 100.0)
	y += 100.0
	_text(w("%s / %s", "%s / %s") % [Pal.money(float(of2.each)), str(of2.unit)], Vector2(x, y), 30, Pal.ink(0.97), font_s)
	if steel:
		_text(w("修缮钢材按吨卖，放进仓库的修缮钢材区，修港区时从那里扣", "Repair steel by the tonne, into the stores' repair steel slot; the works take from it"), Vector2(x, y + 30), 14, Pal.ink(0.6), font_b, dr.size.x - 56.0)
	else:
		_text(w("自己拆下来的同类约 %s · 这里贵 %d%%", "YOUR OWN SALVAGE OF THIS KIND ~%s · %d%% DEARER HERE") % [Pal.money(own_v), dear], Vector2(x, y + 30), 14, Pal.ink(0.6), font_b, dr.size.x - 56.0)
	var have := float(Career.data.get("structure_t", 0.0)) if steel else float(RepairBill.own_of(buy_sel).size())
	_text((w("仓库里有 %.1f t", "IN STORE: %.1f t") % have) if steel else (w("仓库里有 %d 台", "IN STORE: %d") % int(have)), Vector2(x, y + 54), 14, Pal.ink(0.6), font_b)
	need = _repair_need()
	if need.has(buy_sel):
		_text(str(need[buy_sel]), Vector2(x, y + 78), 14, Color(UiSkin.ACCENT, 0.9), font_b, dr.size.x - 56.0)
	y += 120.0
	var step := float(of2.get("step", 1.0))
	var n := float(buy_n) * step
	_key("bminus", Rect2(x, y, 48.0, 48.0), "−", w("少买一些", "Fewer"))
	_text((("%.0f t" % n) if steel else ("× %d" % buy_n)), Vector2(x + 56.0, y + 32.0), 22, Pal.ink(0.95), font_s, 120.0, HORIZONTAL_ALIGNMENT_CENTER)
	_key("bplus", Rect2(x + 184.0, y, 48.0, 48.0), "+", w("多买一些", "More"))
	var total := snappedf(float(of2.each) * n, 1.0)
	var cash := float(Career.data.get("money", 0.0))
	var why := "" if cash + 0.5 >= total else w("现金不够：还差 %s", "NOT ENOUGH CASH: %s SHORT") % Pal.money(total - cash)
	_key("buy", Rect2(x, y + 70.0, 520.0, 58.0), w("买下  %s  [Enter]", "BUY  %s  [Enter]") % Pal.money(total),
		w("马上付钱，货放进仓库（放不下的进待入库）", "Paid at once; into the stores (what does not fit waits to be stored)"), why, true,
		w("现金 %s → %s", "CASH %s → %s") % [Pal.money(cash), Pal.money(cash - total)])


# kinds the next stage of a district needs and the stores lack: kind -> "修 贸易港 还缺 2 台"
func _repair_need() -> Dictionary:
	var out := {}
	for z in ["trade", "process", "cargo", "power", "tug"]:
		var b := RepairBill.of(z)
		for row in b.get("rows", []):
			if int(row.buy) > 0 and not out.has(str(row.nk)):
				out[str(row.nk)] = w("修%s还缺 %d 台：买下后修缮时自动用上", "%s'S MENDING IS %d SHORT: BOUGHT, THE MENDING USES IT") % [Port.name_of(z), int(row.buy)]
		if float(b.get("steel", {}).get("buy", 0.0)) > 0.05 and not out.has(HallMarket.STEEL):
			out[HallMarket.STEEL] = w("修%s还缺钢材 %.0f t", "%s'S MENDING IS %.0f t OF STEEL SHORT") % [Port.name_of(z), float(b.steel.buy)]
	return out


# ---------------------------------------------------------------- 订单

func _draw_orders() -> void:
	var top := _body_top()
	# the reputation: its level, how far to the next, what it brings
	var lv := HallMarket.level()
	var rr := Rect2(PAD, top, size.x - PAD * 2.0, 64.0)
	_glass(rr)
	_text(HallMarket.level_text(), rr.position + Vector2(20, 28), 18, Pal.ink(0.97), font_s)
	_text(HallMarket.next_level_text(), rr.position + Vector2(20, 50), 12, Pal.ink(0.55), font_b)
	var pr := Rect2(rr.position.x + 300.0, rr.position.y + 24.0, 320.0, 6.0)
	var a0 := float(HallMarket.REP_AT[lv - 1])
	var a1 := float(HallMarket.REP_AT[lv]) if lv < HallMarket.REP_AT.size() else a0 + 1.0
	var pk := clampf((HallMarket.rep() - a0) / maxf(a1 - a0, 1.0), 0.0, 1.0) if lv < HallMarket.REP_AT.size() else 1.0
	draw_rect(pr, Color(1, 1, 1, 0.07))
	draw_rect(Rect2(pr.position, Vector2(pr.size.x * pk, pr.size.y)), UiSkin.ACCENT)
	for i in 5:
		var on := i < lv
		draw_rect(Rect2(pr.position + Vector2(i * 22.0, 16.0), Vector2(16.0, 8.0)), UiSkin.ACCENT if on else Pal.ink(0.15))
	_text(w("给价按下单时的信誉等级：1 级是市价的 130%%，每升一级多 4%%（现在 %d 级 · %d%%）· 等级越高订单越大 · 最多同时 8 张 · 过期不罚", "PRICE BY THE LEVEL WHEN POSTED: LEVEL 1 IS 130%% OF MARKET, +4%% A LEVEL (NOW %d · %d%%) · BIGGER ORDERS HIGHER UP · UP TO 8 · NO PENALTY") % [lv, roundi(HallMarket.order_k(lv) * 100.0)],
		rr.position + Vector2(660, 38), 13, Pal.ink(0.6), font_b, rr.size.x - 680.0)
	var cards := _cards()
	var gy := rr.end.y + 16.0
	var cw := (size.x - PAD * 2.0 - 3 * 16.0) / 4.0
	var ch := (size.y - gy - 80.0 - 16.0) / 2.0
	for i in 8:
		var cx := PAD + (i % 4) * (cw + 16.0)
		var cy := gy + (i / 4) * (ch + 16.0)
		var rs := _rise(i)
		var r := Rect2(cx, cy + float(rs[0]), cw, ch)
		if i < cards.size():
			_order_card(r, cards[i], float(rs[1]))
		else:
			_empty_card(r, float(rs[1]), i == cards.size())


func _empty_card(r: Rect2, a: float, next: bool) -> void:
	var dash := 10.0
	var pts := [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end], [r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]
	for e in pts:
		var a_: Vector2 = e[0]
		var b_: Vector2 = e[1]
		var L := a_.distance_to(b_)
		var d := 0.0
		while d < L:
			draw_line(a_.lerp(b_, d / L), a_.lerp(b_, minf(d + dash * 0.6, L) / L), Pal.ink(0.12 * a), 1.0)
			d += dash
	if next:
		var s := maxf(0.0, float(HallMarket.data().get("next_order", 0.0)) - HallMarket.clock())
		_text(w("等新订单 · 约 %d 秒", "NEXT ORDER IN ~%d s") % int(ceil(s)), Vector2(r.position.x, r.get_center().y + 6.0), 14, Pal.ink(0.35 * a), font_b, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _order_card(r: Rect2, o: Dictionary, a: float) -> void:
	var id := "o:" + str(o.id)
	_btns[id] = r
	_notes[id] = ["", ""]
	var on := str(o.id) == ord_sel
	var hv := float(_hov.get(id, 0.0))
	var st := str(o.state)
	var lit := st in ["taken", "rail", "ship"]
	draw_rect(r, Color(0.06, 0.07, 0.08, 0.8 * a))
	draw_texture_rect(CodexFx.rows_tex(), r, true, Color(1, 1, 1, 0.02 * a))
	draw_rect(r, Color(UiSkin.ACCENT, (0.9 if on else 0.35 + 0.3 * hv) * a) if on or lit else Pal.ink((0.16 + 0.2 * hv) * a), false, 1.5 if on else 1.0)
	if lit:
		draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color(UiSkin.ACCENT, a))
	var x := r.position.x + 18.0
	var y := r.position.y + 30.0
	_text(str(o.client), Vector2(x, y), 16, Pal.ink(0.96 * a), font_s, r.size.x - 130.0)
	# the client's reputation level when it was posted: a small badge
	var badge := Rect2(r.end.x - 108.0, r.position.y + 12.0, 92.0, 24.0)
	draw_rect(badge, Color(UiSkin.ACCENT, 0.14 * a))
	draw_rect(badge, Color(UiSkin.ACCENT, 0.6 * a), false, 1.0)
	_text(w("信誉 %d 级", "REP %d") % int(o.lv), badge.position + Vector2(0, 17), 12, Pal.ink(0.92 * a), font_b, badge.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	y += 16.0
	var rp := HallMarket.rep_piece(str(o.kind)) if str(o.cat) == "equip" else ["", "", 0.0]
	_thumb(Rect2(Vector2(x, y), Vector2(64, 64)), str(o.cat), str(rp[0]), str(rp[1]), str(o.kind), a)
	_text(HallMarket.want_name(o), Vector2(x + 78, y + 24), 17, Pal.ink(0.95 * a), font_s, r.size.x - 110.0)
	var base := HallMarket.want_base(str(o.cat), str(o.kind)) * float(o.n)
	_text(w("市价约 %s", "MARKET ~%s") % Pal.money(base), Vector2(x + 78, y + 46), 12, Pal.ink(0.5 * a), font_b)
	y += 104.0
	_text(Pal.money(float(o.price)), Vector2(x, y), 28, Pal.ink(0.97 * a), font_s)
	_text(w("市价的 %d%% · 信誉 %d 级价", "%d%% OF MARKET · LEVEL %d PRICE") % [roundi(float(o.price) / maxf(base, 1.0) * 100.0), int(o.lv)], Vector2(x + 170.0, y - 4.0), 12, Color(UiSkin.ACCENT, 0.85 * a), font_b)
	y += 26.0
	if st == "open":
		var have := HallMarket.have_of(str(o.cat), str(o.kind))
		var ok := have >= float(o.n) - 0.0005
		var hs := (w("仓库有 %.1f / %.0f t", "IN STORE %.1f / %.0f t") % [have, float(o.n)]) if str(o.cat) == "raw" else (w("仓库有 %d / %d 台", "IN STORE %d / %d") % [int(have), int(o.n)])
		_text(hs + (w(" · 可以马上交", " · CAN GO AT ONCE") if ok else ""), Vector2(x, y), 13, (Color(UiSkin.ACCENT, 0.9 * a) if ok else Pal.ink(0.6 * a)), font_b, r.size.x - 36.0)
		# the time left, a line that shortens
		var left := float(o.due) - HallMarket.clock()
		var life := float(o.due) - float(o.at)
		var tl := Rect2(x, y + 14.0, r.size.x - 36.0, 3.0)
		draw_rect(tl, Color(1, 1, 1, 0.06 * a))
		draw_rect(Rect2(tl.position, Vector2(tl.size.x * clampf(left / maxf(life, 1.0), 0.0, 1.0), 3.0)), Pal.ink(0.5 * a) if left > 180.0 else Pal.heat(a, 1.1))
		_text(w("还有 %d 分钟 · 过期不罚", "%d MIN LEFT · NO PENALTY") % HallMarket.mins_left(o), Vector2(x, y + 34.0), 11, Pal.ink(0.45 * a), font_b)
		if not ok:
			# no stock: the plain ways out
			var ways := HallMarket.short_ways(o)
			for i in ways.size():
				_text(str(ways[i]), Vector2(x, y + 60.0 + i * 18.0), 12, Pal.ink((0.82 if i == 0 else 0.62) * a), font_b, r.size.x - 36.0)
	else:
		_pipeline(Rect2(x, y - 6.0, r.size.x - 36.0, 52.0), o, a)
		if st == "taken":
			var ways := HallMarket.short_ways(o)
			for i in ways.size():
				_text(str(ways[i]), Vector2(x, y + 82.0 + i * 18.0), 12, Pal.ink((0.82 if i == 0 else 0.62) * a), font_b, r.size.x - 36.0)
	if on and st in ["open", "taken"]:
		var bl := w("接单  [Enter]", "TAKE  [Enter]") if st == "open" else w("退单", "GIVE BACK")
		var note := w("接下这张订单：仓库自动备货，备齐后货运火车送到贸易港，客户来取", "Take it: the stores make it up, the train takes it to the trade port, the client collects") if st == "open" else w("退掉这张订单：备好的货放回仓库，没有罚款", "Give it back: the goods go back to the stores, no penalty")
		_key("take", Rect2(x, r.end.y - 62.0, r.size.x - 36.0, 46.0), bl, note, "", st == "open")


# a taken order's way: 备货 → 火车 → 客户飞船 → 到账, the step it is on lit
func _pipeline(r: Rect2, o: Dictionary, a: float) -> void:
	var steps := [w("备货", "MAKE UP"), w("火车", "TRAIN"), w("客户飞船", "CLIENT SHIP"), w("到账", "PAID")]
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
		draw_rect(Rect2(r.position.x, r.end.y - 2.0, r.size.x * clampf(_msg_t / 4.0, 0.0, 1.0), 2.0), Color(UiSkin.DATA, 0.6 * k))
		_text(message, r.position + Vector2(24, 26), 16, Pal.ink(0.97 * k), font_b)
	else:
		_text(w("Enter 做这一页的主操作 · Esc 退一步 · Tab 换页", "ENTER: THIS PAGE'S ACTION · ESC: BACK · TAB: NEXT PAGE"), Vector2(PAD, y), 13, Pal.ink(0.35), font_b)


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
