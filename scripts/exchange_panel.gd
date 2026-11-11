extends Control
# The port's exchange (45 号, player 2026-10-25: "learn from Delta Force's market" — layout A).
# Five big tabs across the top — buy, sell, records, shipping, hulk market — the goods on the
# left, big picture cards in the middle. Buying: a card per goods, then that goods' sellers,
# one row each with where it comes from, then the quantity to confirm. Selling: a card per
# goods in stock; a listing window with the book's price distribution (bids, asks, rush, your
# price), the port authority's buyback price beside your own listing price, and what you will
# be paid. Records: every trade and listing in one table, in plain words, one action a row.
# The industrial clients and rush bids are just the high bids on the chart (37 号, 39 号).
const Exchange = preload("res://scripts/industrial_exchange.gd")
const GuideCopy = preload("res://scripts/onboarding_text.gd")
const COUNTERS := ["merchant_00", "merchant_01", "merchant_02"]
const CATS := ["", "mixed_metal", "ferrous_scrap", "nonferrous_mix", "steel_billet"]

var game: Node
var on_close: Callable
var on_repair: Callable
const Back := preload("res://scripts/ui_back.gd")
var start_page := ""     # "clients" (sell), "feed" (grade 1 feed's sellers), "company:<id>" (a counter)
var tab := "buy"          # buy | sell | records
var cat := ""             # the goods filter on the left ("" all)
var item := "mixed_metal" # the goods whose sellers are listed (buy) or which is being listed (sell)
var grade := 0
var sellers_open := false # buy: the chosen goods' seller list instead of the cards
var balance: Label
var message: Label
var pause_button: Button
var tab_keys := {}
var cat_keys := {}
var main: VBoxContainer
var sell_win: PanelContainer
var sell_qty: HSlider
var sell_qty_label: Label
var sell_price: SpinBox
var sell_price_slide: HSlider
var sell_paid: Label
var sell_note: Label
var sell_buyback: Button
var sell_bars: Control
var sell_head: Label
var purchase: ConfirmationDialog
var purchase_info: Label
var purchase_quantity: SpinBox
var purchase_total: Label
var purchase_quote := {}
var _stamp := ""
var dimmer: ColorRect          # darkens the page behind a pop-up window
var _refresh_t := 0.0
var _paused_here := false
var _anim_key := ""
var _money_seen := -1.0


func words(zh: String, en: String) -> String: return zh if Txt.zh else en


func text(value: String, size_px: int = 18, ink := 0.92) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size", size_px)
	node.add_theme_color_override("font_color", Pal.ink(ink))
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func key(value: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = value
	node.custom_minimum_size.y = 44
	node.pressed.connect(callback)
	return node


func _box(bg: Color, edge: Color, pad := 10.0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = edge
	b.set_border_width_all(1)
	for side in ["left", "right", "top", "bottom"]:
		b.set("content_margin_" + side, pad)
	return b


# ---------------------------------------------------------------- goods pictures and the chart

class GoodsIcon extends Control:
	var item := ""
	var grade := 0
	func _draw() -> void:
		var c := size * 0.5
		var u := minf(size.x / 120.0, size.y / 70.0)
		var edge := Pal.ink(0.7)
		var fill := Color(0.2, 0.22, 0.25)
		var strap := Pal.heat(0.85, 1.1) if grade >= 1 else Pal.ink(0.45)
		match item:
			"mixed_metal":
				# a skip of torn plate and sections
				var skip := PackedVector2Array([c + Vector2(-52, 28) * u, c + Vector2(52, 28) * u, c + Vector2(44, 0) * u, c + Vector2(-44, 0) * u])
				draw_colored_polygon(skip, Color(0.15, 0.17, 0.19))
				draw_polyline(skip + PackedVector2Array([skip[0]]), edge, 1.2)
				var heap := PackedVector2Array([c + Vector2(-40, 0) * u, c + Vector2(-28, -22) * u, c + Vector2(-12, -10) * u, c + Vector2(2, -30) * u, c + Vector2(18, -14) * u, c + Vector2(30, -24) * u, c + Vector2(40, 0) * u])
				draw_colored_polygon(heap, fill)
				draw_polyline(heap, edge, 1.0)
				for k in 4:
					draw_line(c + Vector2(-30 + k * 18, -6) * u, c + Vector2(-20 + k * 18, -18) * u, Pal.ink(0.4), 1.0)
			"ferrous_scrap":
				# pressed bales, two rows, strapped
				for row in 2:
					for col in 3 - row:
						var r := Rect2(c + Vector2(-44 + col * 30 + row * 15, 2 - row * 26) * u, Vector2(28, 24) * u)
						draw_rect(r, fill)
						draw_rect(r, edge, false, 1.0)
						draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), strap, 1.5)
			"nonferrous_mix":
				# a bulk bag with its lifting loops
				var bag := PackedVector2Array([c + Vector2(-34, 30) * u, c + Vector2(-38, -14) * u, c + Vector2(0, -24) * u, c + Vector2(38, -14) * u, c + Vector2(34, 30) * u])
				draw_colored_polygon(bag, Color(0.22, 0.23, 0.22))
				draw_polyline(bag + PackedVector2Array([bag[0]]), edge, 1.2)
				for sx in [-1.0, 1.0]:
					draw_arc(c + Vector2(sx * 22, -20) * u, 7 * u, PI, TAU, 10, edge, 1.2)
			"steel_billet":
				# square billets bundled three high, two straps
				for k in 3:
					var r := Rect2(c + Vector2(-50, 12 - k * 13) * u, Vector2(100, 11) * u)
					draw_rect(r, Color(0.26, 0.28, 0.3))
					draw_rect(r, Pal.ink(0.8), false, 1.0)
				for sx in [-22.0, 22.0]:
					draw_line(c + Vector2(sx, -28) * u, c + Vector2(sx, 24) * u, strap, 2.0)


class PriceBars extends Control:
	var rows: Array = []      # [{price, buy, sell, rush}], ascending
	var mine := -1.0
	# user 2026-10-26: "点这个柱状体，它能直接跳到那个价格上" — a click on a column takes its price
	var on_pick: Callable
	var hot := -1
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = ""
	func _col_at(x: float) -> int:
		var n := rows.size()
		if n == 0:
			return -1
		var w := minf((size.x - 20.0) / n, 110.0)
		var x0 := (size.x - w * n) * 0.5
		var i := int(floor((x - x0) / w))
		return i if i >= 0 and i < n else -1
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion:
			var h := _col_at(ev.position.x)
			if h != hot:
				hot = h
				queue_redraw()
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var i := _col_at(ev.position.x)
			if i >= 0 and on_pick.is_valid():
				on_pick.call(float(rows[i].price))
				accept_event()
	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT and hot != -1:
			hot = -1
			queue_redraw()
	func _bar(r: Rect2, col: Color) -> void:
		if r.size.y < 1.0:
			return
		var rad := minf(6.0, r.size.x * 0.5)
		var pts := PackedVector2Array([Vector2(r.position.x, r.end.y), Vector2(r.position.x, r.position.y + rad), Vector2(r.position.x + rad, r.position.y), Vector2(r.end.x - rad, r.position.y), Vector2(r.end.x, r.position.y + rad), Vector2(r.end.x, r.end.y)])
		var top := Color(col.r, col.g, col.b, 0.95)
		var bot := Color(col.r, col.g, col.b, 0.12)
		draw_polygon(pts, PackedColorArray([bot, top, top, top, top, bot]))
	func _draw() -> void:
		draw_style_box(UiSkin.glass(0.03, 0.06, 14, 0.0), Rect2(Vector2.ZERO, size))
		if rows.is_empty():
			return
		var font := Fonts.get_font("Regular")
		var top := 1.0
		for r in rows:
			top = maxf(top, maxf(float(r.buy), float(r.sell)))
		var n := rows.size()
		var w := minf((size.x - 20.0) / n, 110.0)
		var base := size.y - 30.0
		var x0 := (size.x - w * n) * 0.5
		for i in n:
			var r: Dictionary = rows[i]
			var x := x0 + i * w
			var hb := (base - 20.0) * float(r.buy) / top
			var hs := (base - 20.0) * float(r.sell) / top
			if i == hot:
				draw_style_box(UiSkin.glass(0.06, 0.4, 10, 0.0), Rect2(x + w * 0.04, 6, w * 0.92, base - 2))
				draw_string(font, Vector2(x + 4, 20), Pal.money(float(r.price)), HORIZONTAL_ALIGNMENT_CENTER, w - 8, 12, Pal.ink(0.95))
			# 50 号: rounded bars, bright at the top and fading to the floor
			if float(r.buy) > 0.0:
				_bar(Rect2(x + w * 0.12, base - hb, w * 0.36, hb), UiSkin.ACCENT if r.rush else UiSkin.DATA)
			if float(r.sell) > 0.0:
				_bar(Rect2(x + w * 0.52, base - hs, w * 0.36, hs), Color(1, 1, 1, 0.55))
			if mine > 0.0 and absf(float(r.price) - mine) < 0.5:
				var ring := UiSkin.glass(0.0, 0.9, 10, 0.0, Color("7be38f"))
				ring.set_border_width_all(2)
				draw_style_box(ring, Rect2(x + w * 0.04, 6, w * 0.92, base - 2))
			draw_string(font, Vector2(x + 4, size.y - 10), Pal.money(float(r.price)), HORIZONTAL_ALIGNMENT_LEFT, w - 6, 12, Pal.ink(0.7))
			var tq := "%.1f" % (float(r.buy) if float(r.buy) > 0.0 else float(r.sell))
			draw_string(font, Vector2(x + 4, base - maxf(hb, hs) - 4), tq + " t", HORIZONTAL_ALIGNMENT_LEFT, w - 6, 11, Pal.ink(0.55))


# ---------------------------------------------------------------- building

func _ready() -> void:
	Back.arrive()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 50 号: the "minimal future" look (UiSkin): the moving ground, glass cards, one warm accent
	var skin := UiSkin.theme()
	theme = skin
	add_child(UiSkin.Ground.new())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	# 2026-11-04 (BenchFx): comes in from the side, its keys lit; Esc steps back out of a seller list
	# first; the scale and last visit's place (once the page is built)
	(func():
		BenchFx.dress(self, [column], margin, 1.0, "exchange_panel")
		BenchFx.back_step(self, func(): return sellers_open and not sell_win.visible, func():
			sellers_open = false
			_stamp = ""
			refresh())).call_deferred()
	# the top bar: the title, the five tabs, the money, guide / pause / close
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	column.add_child(top)
	var title := text(words("零压港 · 交易行", "ZERO PRESSURE PORT · EXCHANGE"), 24, 0.95)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.custom_minimum_size.x = 280
	var wide := FontVariation.new()
	wide.base_font = Fonts.get_font("Regular")
	wide.spacing_glyph = 4
	title.add_theme_font_override("font", wide)
	top.add_child(title)
	for t in [["buy", words("购买", "BUY")], ["sell", words("出售", "SELL")], ["records", words("交易记录", "RECORDS")], ["ship", words("航运", "SHIPPING")], ["hulk", words("船市", "HULKS")]]:
		var b := key(str(t[1]), _tab.bind(str(t[0])))
		b.custom_minimum_size = Vector2(118, 48)
		b.add_theme_font_size_override("font_size", 19)
		b.focus_mode = Control.FOCUS_NONE
		BenchFx.note(b, {"buy": words("买别人挂出来的货：选货，再选卖家", "Buy what others list: pick the goods, then a seller"), "sell": words("把仓库里的货挂出去卖", "List goods from your store for sale"), "records": words("每一笔买卖和挂单，用白话写着", "Every trade and listing, in plain words"), "ship": words("关掉这里，打开星图的航运页：货船在哪、什么时候到", "Close this and open the star map's shipping: where freighters are, when they come"), "hulk": words("关掉这里，打开二手船市：买整艘旧船回来拆", "Close this and open the hulk market: buy whole old ships to strip")}.get(str(t[0]), ""))
		tab_keys[t[0]] = b
		top.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	balance = text("", 20)
	balance.autowrap_mode = TextServer.AUTOWRAP_OFF
	balance.add_theme_color_override("font_color", UiSkin.INK)
	top.add_child(balance)
	UiSkin.count(balance, float(Career.data.money), func(v: float): return words("可用资金 ", "FUNDS ") + Pal.money(v))
	var guide_key := key(words("带我做下一步", "GUIDE ME"), start_guide)
	BenchFx.note(guide_key, words("一步一步指给你：现在该点哪里", "Shows you, step by step, what to press now"))
	top.add_child(guide_key)
	pause_button = key(words("暂停经营", "PAUSE"), toggle_pause)
	BenchFx.note(pause_button, words("暂停整个港口和市场的时间，慢慢看；再点一次继续", "Stops the port's and the market's clock while you look; press again to go on"))
	top.add_child(pause_button)
	top.add_child(key(Back.close_text(), _back))
	# the body: categories on the left, the page in the middle
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	column.add_child(body)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 190
	side.add_theme_constant_override("separation", 6)
	body.add_child(side)
	for c in CATS:
		# 64 号: kinds of raw scrap no longer offered get no key (ingots are under the ferrous one)
		if c in ["mixed_metal", "nonferrous_mix"] and Exchange.INGOTS:
			continue
		var nm: String = words("全部", "ALL") if c == "" else str(Exchange.CATALOG[c].name) if Txt.zh else str(c).to_upper().replace("_", " ")
		var b := key(nm, _cat.bind(c))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		BenchFx.note(b, words("只看全部货", "Show every kind of goods") if c == "" else words("只看这一类货：%s", "Show only this kind: %s") % nm)
		cat_keys[c] = b
		side.add_child(b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	main = VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 10)
	scroll.add_child(main)
	message = text("", 16)
	column.add_child(message)
	_build_sell_window()
	_build_purchase(skin)
	if start_page == "clients":
		tab = "sell"
		if float(_stock().get("steel_billet:1", 0.0)) > Exchange.EPS:
			open_sell("steel_billet", 1)
	elif start_page == "feed":
		select_item("ferrous_scrap")
		grade = 1
	elif start_page.begins_with("company:"):
		_at_counter(start_page.substr(8))
	refresh()


func _build_sell_window() -> void:
	dimmer = ColorRect.new()
	dimmer.color = Color(0.02, 0.025, 0.03, 0.7)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.visible = false
	add_child(dimmer)
	sell_win = PanelContainer.new()
	var win := UiSkin.solid(Color("171b21"), 22, 24.0)
	win.border_color = Color(1, 1, 1, 0.1)
	win.set_border_width_all(1)
	win.shadow_color = Color(0, 0, 0, 0.6)
	win.shadow_size = 40
	sell_win.add_theme_stylebox_override("panel", win)
	sell_win.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	sell_win.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sell_win.grow_vertical = Control.GROW_DIRECTION_BOTH
	sell_win.custom_minimum_size = Vector2(1100, 470)
	sell_win.visible = false
	add_child(sell_win)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	sell_win.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	sell_head = text("", 22, 0.95)
	sell_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sell_head)
	head.add_child(key(words("关闭", "CLOSE"), func(): sell_win.visible = false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	left.add_child(text(words("价格分布：蓝 = 在收（买单），灰 = 在卖（卖单），橙 = 加急收购，绿框 = 你的价", "PRICES: BLUE BIDS · GREY ASKS · ORANGE RUSH · GREEN YOUR PRICE"), 14, 0.7))
	sell_bars = PriceBars.new()
	sell_bars.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sell_bars.custom_minimum_size = Vector2(600, 300)
	(sell_bars as PriceBars).on_pick = func(p: float): sell_price.value = p
	left.add_child(sell_bars)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 400
	right.add_theme_constant_override("separation", 8)
	row.add_child(right)
	sell_buyback = key("", sell_to_port)
	right.add_child(sell_buyback)
	right.add_child(HSeparator.new())
	sell_qty_label = text("", 16)
	right.add_child(sell_qty_label)
	sell_qty = HSlider.new()
	sell_qty.step = 0.01
	sell_qty.min_value = 0.01
	sell_qty.value_changed.connect(func(_v): _update_sell())
	right.add_child(sell_qty)
	var pr := HBoxContainer.new()
	right.add_child(pr)
	var pl := text(words("你的价格 / t", "YOUR PRICE / t"), 16)
	pl.autowrap_mode = TextServer.AUTOWRAP_OFF
	pr.add_child(pl)
	sell_price = SpinBox.new()
	sell_price.min_value = 1.0
	sell_price.max_value = 100000.0
	sell_price.step = 1.0
	sell_price.custom_arrow_step = 10.0
	sell_price.prefix = "$"
	sell_price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_price.value_changed.connect(func(v):
		if sell_price_slide != null and absf(sell_price_slide.value - v) > 0.5:
			sell_price_slide.max_value = maxf(sell_price_slide.max_value, v)
			sell_price_slide.value = v
		_update_sell())
	pr.add_child(sell_price)
	# the price by hand as well: a slider over a wide range, ten dollars a notch (any figure can still be typed)
	sell_price_slide = HSlider.new()
	sell_price_slide.min_value = 1.0
	sell_price_slide.step = 1.0
	sell_price_slide.value_changed.connect(func(v): if absf(sell_price.value - v) > 0.5: sell_price.value = v)
	right.add_child(sell_price_slide)
	right.add_child(text(words("拖滑条、直接输入，或点左边的柱子跳到那个价。", "Drag, type, or click a column on the left for its price."), 13, 0.55))
	sell_paid = text("", 20)
	right.add_child(sell_paid)
	sell_note = text("", 15)
	right.add_child(sell_note)
	var go := key(words("上架", "LIST IT"), list_it)
	go.custom_minimum_size.y = 60
	go.add_theme_font_size_override("font_size", 24)
	UiSkin.accent_button(go)
	right.add_child(go)
	BenchFx.primary(go)
	BenchFx.note(go, words("按上面的价钱和数量挂到交易行；有人出到这个价就成交，钱直接到账", "List it at the price and amount above; it sells when a buyer meets the price"))


func _build_purchase(skin: Theme) -> void:
	purchase = ConfirmationDialog.new()
	purchase.title = words("购买该卖家的货物", "BUY THIS SELLER'S GOODS")
	purchase.min_size = Vector2i(520, 300)
	purchase.ok_button_text = words("确认购买", "CONFIRM PURCHASE")
	purchase.cancel_button_text = words("取消", "CANCEL")
	purchase.exclusive = true
	purchase.theme = skin
	var purchase_skin := StyleBoxFlat.new()
	purchase_skin.bg_color = Hmi.PANEL
	purchase_skin.border_color = Color(0, 0, 0, 0.8)
	purchase_skin.set_border_width_all(1)
	skin.set_stylebox("panel", "AcceptDialog", purchase_skin)
	add_child(purchase)
	var pc := VBoxContainer.new()
	pc.add_theme_constant_override("separation", 16)
	purchase.add_child(pc)
	purchase_info = text("", 20)
	purchase_info.custom_minimum_size.x = 520
	pc.add_child(purchase_info)
	purchase_quantity = SpinBox.new()
	purchase_quantity.prefix = words("购买数量 / t  ", "QUANTITY / t  ")
	purchase_quantity.step = 0.001
	purchase_quantity.min_value = 0.001
	pc.add_child(purchase_quantity)
	purchase_total = text("", 18)
	purchase_total.custom_minimum_size.x = 520
	pc.add_child(purchase_total)
	purchase_quantity.value_changed.connect(func(_value): update_purchase_total())
	purchase.confirmed.connect(confirm_purchase)


# ---------------------------------------------------------------- state

func _state() -> Dictionary:
	return Career.data.get("exchange", {})


func _stock() -> Dictionary:
	return _state().get("actors", {}).get(Exchange.PLAYER, {}).get("stock", {})


func _goods() -> Array:
	var out: Array = []
	var held: Dictionary = _stock() if tab == "sell" else {}
	for it in Exchange.CATALOG:
		if cat != "" and it != cat:
			continue
		for gr in Exchange.CATALOG[it].grades:
			var key := Exchange.lot_key(str(it), int(gr))
			# 64 号: raw scrap is not offered; what the company still holds of it can be sold
			if not Exchange.buyable(key) and float(held.get(key, 0.0)) <= Exchange.EPS:
				continue
			out.append([str(it), int(gr)])
	return out


static func where(owner: String) -> String:
	if owner in COUNTERS:
		return "本港柜台 · 几十秒到" if Txt.zh else "PORT COUNTER · SECONDS"
	if owner == Exchange.PORT_AUTHORITY:
		return "港务回收 · 本港" if Txt.zh else "PORT AUTHORITY"
	return "小行星带 · 货船几分钟" if Txt.zh else "ASTEROID BELT · BY FREIGHTER"


func _tab(t: String) -> void:
	if t == "ship":
		open_star_map()
		return
	if t == "hulk":
		open_ship_market()
		return
	tab = t
	sellers_open = false
	sell_win.visible = false
	_stamp = ""
	refresh()
	# #057: the new page comes in
	BenchFx.swap(main)


func _cat(c: String) -> void:
	cat = c
	sellers_open = false
	_stamp = ""
	refresh()


func select_item(value: String) -> void:
	item = value
	grade = int(Exchange.CATALOG[item].grades[0])
	tab = "buy"
	sellers_open = true
	_stamp = ""
	if is_node_ready():
		refresh()


func _process(dt: float) -> void:
	dimmer.visible = sell_win.visible
	_refresh_t += dt
	if _refresh_t < 0.25:
		return
	_refresh_t = 0.0
	refresh()


func refresh() -> void:
	var state := _state()
	if state.is_empty() or main == null:
		return
	var stamp := "%s/%d/%d/%s/%s/%s/%d/%s/%s" % [str(Career.data.money), int(state.revision), int(state.clock) / 5, tab, cat, item, grade, sellers_open, str(get_tree().paused)]
	if stamp == _stamp:
		return
	_stamp = stamp
	if _anim_key != "" and _money_seen != float(Career.data.money):
		balance.text = words("可用资金 ", "FUNDS ") + Pal.money(float(Career.data.money))
	_money_seen = float(Career.data.money)
	pause_button.text = words("恢复经营", "RESUME") if get_tree().paused else words("暂停经营", "PAUSE")
	for t in tab_keys:
		UiSkin.tab_button(tab_keys[t], t == tab)
	for c in cat_keys:
		var on_c: bool = c == cat
		cat_keys[c].add_theme_stylebox_override("normal", UiSkin.glass(0.08 if on_c else 0.0, 0.0, 10, 10.0))
		cat_keys[c].add_theme_color_override("font_color", UiSkin.INK if on_c else UiSkin.DIM)
	for ch in main.get_children():
		main.remove_child(ch)
		ch.queue_free()
	if Port.stage("trade") < 1:
		main.add_child(text(words("贸易港尚未恢复营业 · 可浏览报价，修复后开放交易", "TRADE DISTRICT CLOSED · BROWSING ONLY"), 18, 0.8))
		if on_repair.is_valid():
			main.add_child(key(words("查看贸易港工程", "TRADE DISTRICT WORKS"), func(): if close(): on_repair.call()))
	match tab:
		"buy":
			if sellers_open: _sellers(state)
			else: _buy_cards(state)
		"sell": _sell_cards(state)
		"records": _records(state)
	if sell_win.visible:
		_update_sell()
	# a new page plays its entrance; the periodic refresh of the same page does not
	var ak := "%s/%s/%s/%s/%d" % [tab, cat, sellers_open, item, grade]
	if ak != _anim_key:
		_anim_key = ak
		var cards: Array = []
		for ch in main.get_children():
			if ch is GridContainer:
				cards.append_array(ch.get_children())
			else:
				cards.append(ch)
		UiSkin.enter(cards)


func _card(icon_item: String, icon_grade: int, title: String, sub: String, price: String, tag: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(260, 230)
	b.pressed.connect(on_press)
	UiSkin.hover_lift(b, 14.0)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_right = -16
	v.offset_top = 14
	v.offset_bottom = -12
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var t := text(title, 16, 0.85)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	if tag != "":
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", UiSkin.solid(UiSkin.ACCENT, 20, 4.0))
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tg := text(tag, 12)
		tg.add_theme_color_override("font_color", Color("1a0d05"))
		pill.add_child(tg)
		head.add_child(pill)
	var ic := UiSkin.Goods.new(icon_item, icon_grade)
	ic.custom_minimum_size = Vector2(0, 110)
	v.add_child(ic)
	v.add_child(text(sub, 13, 0.55))
	var p := text(price, 24, 0.97)
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(p)
	return b


func _grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	main.add_child(g)
	return g


func _listings(state: Dictionary, it: String, gr: int) -> Array:
	return Exchange.book(state, it, gr, "sell").filter(func(row): return row.owner != Exchange.PLAYER and not row.has("target_order"))


func _buy_cards(state: Dictionary) -> void:
	main.add_child(text(words("点一种货，看每一家卖方的报价。", "PICK THE GOODS TO SEE EVERY SELLER."), 15, 0.6))
	var g := _grid()
	var rush := Exchange.rush_order(state)
	for gd in _goods():
		var rows := _listings(state, gd[0], gd[1])
		var qty := 0.0
		var best := INF
		var near := false
		var far := false
		for r in rows:
			qty += float(r.remaining)
			best = minf(best, float(r.price))
			if str(r.owner) in COUNTERS: near = true
			else: far = true
		var src := words("本港柜台", "PORT") if near else ""
		if far: src += (" + " if near else "") + words("小行星带", "BELT")
		var sub := words("现货 %.1f t · %s", "%.1f t · %s") % [qty, src] if qty > 0.0 else words("暂无卖家", "NO SELLERS")
		var tag := words("加急 高价收", "RUSH BUYING") if not rush.is_empty() and gd[0] == "steel_billet" and gd[1] == 1 else ""
		var it: String = gd[0]
		var gr: int = gd[1]
		g.add_child(_card(it, gr, Ops.item_name(Exchange.lot_key(it, gr)), sub, (words("最低 ", "FROM ") + Pal.money(best) + " / t") if is_finite(best) else "—", tag, func():
			item = it
			grade = gr
			sellers_open = true
			_stamp = ""
			refresh()))


func _sellers(state: Dictionary) -> void:
	var head := HBoxContainer.new()
	main.add_child(head)
	head.add_child(key(words("← 全部货品", "← ALL GOODS"), func(): sellers_open = false; _stamp = ""; refresh()))
	var t := text("  " + Ops.item_name(Exchange.lot_key(item, grade)), 22, 0.95)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	main.add_child(text(words("每行是一家卖方的实际报价。点“购买”只按这一家的价格和余量成交。", "EACH ROW IS ONE SELLER. BUY TAKES ONLY THAT SELLER'S PRICE AND STOCK."), 14, 0.6))
	var rows := _listings(state, item, grade)
	if rows.is_empty():
		main.add_child(text(words("现在没有人卖这种货。", "NOBODY IS SELLING THIS NOW."), 18, 0.7))
	var opened := Port.stage("trade") >= 1
	for order in rows:
		var plate := PanelContainer.new()
		plate.add_theme_stylebox_override("panel", UiSkin.glass(0.04, 0.08, 14, 14.0))
		main.add_child(plate)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 20)
		plate.add_child(line)
		var who := text("%s\n%s" % [str(state.actors[order.owner].name), where(str(order.owner))], 17)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(who)
		line.add_child(text(words("剩余 %.2f t", "%.2f t LEFT") % float(order.remaining), 17, 0.7))
		var cost := text(Pal.money(float(order.price)) + " / t", 22)
		cost.autowrap_mode = TextServer.AUTOWRAP_OFF
		line.add_child(cost)
		var buy := key(words("购买", "BUY"), select_quote.bind(str(order.id)))
		buy.custom_minimum_size.x = 110
		buy.disabled = not opened or float(order.remaining) <= Exchange.EPS
		line.add_child(buy)


func _sell_cards(state: Dictionary) -> void:
	main.add_child(text(words("你库里的货。点一种，自己定价上架，或按港务回收价马上卖掉。", "YOUR STOCK. PICK ONE TO LIST AT YOUR PRICE, OR SELL TO THE PORT NOW."), 15, 0.6))
	var g := _grid()
	var stock := _stock()
	var rush := Exchange.rush_order(state)
	var any := false
	for gd in _goods():
		var k := Exchange.lot_key(gd[0], gd[1])
		var have := float(stock.get(k, 0.0))
		if have <= Exchange.EPS:
			continue
		any = true
		var bid := Exchange.best_bid(state, gd[0], gd[1])
		var sub := words("库存 %.2f t", "%.2f t IN STOCK") % have
		var price := (words("最高收价 ", "BEST BID ") + Pal.money(float(bid.price)) + " / t") if not bid.is_empty() else words("暂无人收 · 回收 ", "NO BIDS · PORT ") + Pal.money(Exchange.buyback_price(k))
		var tag := words("加急", "RUSH") if not rush.is_empty() and gd[0] == "steel_billet" and gd[1] == 1 else ""
		var it: String = gd[0]
		var gr: int = gd[1]
		g.add_child(_card(it, gr, Ops.item_name(k), sub, price, tag, func(): open_sell(it, gr)))
	if not any:
		main.add_child(text(words("库里没有可卖的货。", "NOTHING IN STOCK TO SELL."), 18, 0.7))


# ---------------------------------------------------------------- the listing window

func bar_rows(state: Dictionary, it: String, gr: int) -> Array:
	var by := {}
	for o in state.get("orders", []):
		if str(o.state) != "open" or str(o.item) != it or int(o.grade) != gr or o.has("target_order"):
			continue
		if str(o.side) == "buy" and (str(o.owner) == Exchange.PLAYER or o.get("exclusive_seller", Exchange.PLAYER) != Exchange.PLAYER):
			continue
		var p := float(o.price)
		if not by.has(p):
			by[p] = {"price": p, "buy": 0.0, "sell": 0.0, "rush": false}
		if str(o.side) == "buy":
			by[p].buy += float(o.remaining)
			by[p].rush = by[p].rush or o.get("rush", false)
		else:
			by[p].sell += float(o.remaining)
	var rows: Array = by.values()
	rows.sort_custom(func(a, b): return float(a.price) < float(b.price))
	if rows.size() > 9:
		# around the best bid: the levels a seller cares about
		var bi := 0
		for i in rows.size():
			if float(rows[i].buy) > 0.0:
				bi = i
		var from := clampi(bi - 4, 0, rows.size() - 9)
		rows = rows.slice(from, from + 9)
	return rows


func open_sell(it: String, gr: int) -> void:
	item = it
	grade = gr
	tab = "sell"
	var state := _state()
	var k := Exchange.lot_key(it, gr)
	var have := float(_stock().get(k, 0.0))
	sell_head.text = words("出售 · %s（库存 %.2f t）", "SELL · %s (%.2f t IN STOCK)") % [Ops.item_name(k), have]
	sell_qty.max_value = maxf(0.01, have)
	sell_qty.value = have
	var bid := Exchange.best_bid(state, it, gr)
	var start := float(bid.price) if not bid.is_empty() else Exchange.ref_price(k)
	var top_price := Exchange.ref_price(k)
	for r in bar_rows(state, it, gr):
		top_price = maxf(top_price, float(r.price))
	sell_price_slide.max_value = maxf(100.0, ceilf(top_price * 3.0))
	sell_price.value = start
	sell_price_slide.value = start
	sell_win.visible = true
	_update_sell()


func _update_sell() -> void:
	if not sell_win.visible:
		return
	var state := _state()
	var k := Exchange.lot_key(item, grade)
	var q := sell_qty.value
	sell_qty_label.text = words("上架数量：%.2f t", "QUANTITY: %.2f t") % q
	var rows := bar_rows(state, item, grade)
	(sell_bars as PriceBars).rows = rows
	(sell_bars as PriceBars).mine = -1.0
	for r in rows:
		if absf(float(r.price) - sell_price.value) < 0.5:
			(sell_bars as PriceBars).mine = float(r.price)
	sell_bars.queue_redraw()
	var gross := q * sell_price.value
	sell_paid.text = words("预期到账（扣 2%% 手续费）：%s", "PAID (LESS 2%%): %s") % Pal.money(gross * (1.0 - Exchange.FEE))
	var bid := Exchange.best_bid(state, item, grade)
	if not bid.is_empty() and float(bid.price) >= sell_price.value:
		sell_note.text = words("这个价不高于 %s 的收价 %s：上架就立即成交，钱当场到账。", "AT OR UNDER %s's BID OF %s: SOLD THE MOMENT IT IS LISTED.") % [str(state.actors[bid.owner].name), Pal.money(float(bid.price))]
		sell_note.add_theme_color_override("font_color", Pal.tint(Pal.FLUID, 0.95, 1.2))
	else:
		sell_note.text = words("比现在的最高收价高：挂着等人出到这个价，随时可在交易记录里撤回。", "OVER THE BEST BID: IT WAITS FOR A BUYER; WITHDRAW ANY TIME FROM RECORDS.")
		sell_note.add_theme_color_override("font_color", Pal.ink(0.7))
	var bb := Exchange.buyback_price(k)
	sell_buyback.text = words("港务回收价 %s / t · 按回收价卖掉 · 到账 %s", "PORT BUYBACK %s / t · SELL NOW · PAID %s") % [Pal.money(bb), Pal.money(q * bb * (1.0 - Exchange.FEE))]


func list_it() -> void:
	var cash := float(Career.data.money)
	var r := Exchange.command("post", {"side": "sell", "item": item, "grade": grade, "quantity": sell_qty.value, "price": sell_price.value})
	explain(r)
	if r.ok:
		var got := float(Career.data.money) - cash
		message.text = (words("卖出去了，钱已到账 +%s；搬运车会把货送过去。", "SOLD AND PAID +%s; THE COURIER TAKES IT.") % Pal.money(got)) if got > 0.5 else words("已上架，有人出到这个价就成交。", "LISTED; IT SELLS WHEN A BUYER MEETS THE PRICE.")
		sell_win.visible = false


func sell_to_port() -> void:
	var cash := float(Career.data.money)
	var r := Exchange.command("buyback", {"item": item, "grade": grade, "quantity": sell_qty.value})
	explain(r)
	if r.ok:
		message.text = words("港务局收下了，到账 +%s；搬运车会把货送走。", "THE PORT TOOK IT: +%s; THE COURIER TAKES IT.") % Pal.money(float(Career.data.money) - cash)
		sell_win.visible = false


# ---------------------------------------------------------------- records

func record_rows(state: Dictionary) -> Array:
	var out: Array = []
	var now := float(state.get("clock", 0.0))
	for o in state.get("orders", []):
		if str(o.owner) != Exchange.PLAYER or str(o.state) != "open":
			continue
		out.append({"t": float(o.get("created", 0.0)), "goods": Ops.item_name(Exchange.lot_key(str(o.item), int(o.grade))), "who": words("挂牌卖", "LISTED") if str(o.side) == "sell" else words("挂单求购", "BID"),
			"q": float(o.remaining), "price": float(o.price), "state": words("挂牌中", "LISTED") if str(o.side) == "sell" else words("求购中", "BIDDING"), "kind": "w", "action": "cancel", "id": str(o.id)})
	for tr in state.get("trades", []):
		var mine_sell: bool = str(tr.seller) == Exchange.PLAYER
		if not mine_sell and str(tr.buyer) != Exchange.PLAYER:
			continue
		var other := str(tr.buyer if mine_sell else tr.seller)
		var nm := str(state.actors.get(other, {}).get("name", other))
		var st := ""
		var kind := "ok"
		var action := ""
		if mine_sell:
			st = words("已卖出 · 已到账", "SOLD · PAID") + ("" if str(tr.state) == "delivered" else words(" · 送货中", " · DELIVERING"))
		elif str(tr.state) == "delivered":
			st = words("已到库", "IN STOCK")
		elif Shipping.orbital(tr):
			st = words("货船在路上", "FREIGHTER ON ITS WAY")
			kind = "go"
			action = "starmap"
		else:
			st = words("送货中", "DELIVERING")
			kind = "go"
		out.append({"t": float(tr.get("matched", 0.0)), "goods": Ops.item_name(Exchange.lot_key(str(tr.item), int(tr.grade))),
			"who": (words("卖给 ", "TO ") if mine_sell else words("从 ", "FROM ")) + nm + ("" if mine_sell else words(" 买", "")),
			"q": float(tr.quantity), "price": float(tr.unit_price), "state": st, "kind": kind, "action": action, "id": str(tr.id)})
	out.sort_custom(func(a, b): return float(a.t) > float(b.t))
	for r in out:
		r.ago = maxf(0.0, now - float(r.t))
	return out.slice(0, 60)


func _records(state: Dictionary) -> void:
	var rows := record_rows(state)
	if rows.is_empty():
		main.add_child(text(words("还没有交易。", "NO TRADES YET."), 18, 0.7))
		return
	var g := GridContainer.new()
	g.columns = 7
	g.add_theme_constant_override("h_separation", 22)
	g.add_theme_constant_override("v_separation", 8)
	main.add_child(g)
	for h in [words("时间", "WHEN"), words("货", "GOODS"), words("买 / 卖", "WITH"), words("数量", "QTY"), words("单价", "PRICE"), words("状态", "STATE"), ""]:
		g.add_child(text(h, 14, 0.5))
	for r in rows:
		var mins := int(float(r.ago) / 60.0)
		g.add_child(text(words("刚才", "JUST NOW") if mins < 1 else words("%d 分钟前", "%d MIN AGO") % mins, 15, 0.6))
		g.add_child(text(str(r.goods), 15))
		g.add_child(text(str(r.who), 15, 0.8))
		g.add_child(text("%.2f t" % float(r.q), 15))
		g.add_child(text(Pal.money(float(r.price)), 15))
		var st := text(str(r.state), 15)
		st.add_theme_color_override("font_color", Pal.tint(Pal.FLUID, 0.95, 1.2) if r.kind == "ok" else (Pal.tint(Pal.AIR, 0.95, 1.2) if r.kind == "go" else Color("ffb35c")))
		g.add_child(st)
		match str(r.action):
			"cancel":
				var id := str(r.id)
				g.add_child(key(words("撤回", "WITHDRAW"), func(): explain(Exchange.command("cancel", {"order_id": id}))))
			"starmap":
				g.add_child(key(words("看星图", "STAR MAP"), open_star_map))
			_:
				g.add_child(Control.new())


# ---------------------------------------------------------------- the counter, buying, the rest

func _at_counter(who: String) -> void:
	var name := str(_state().get("actors", {}).get(who, {}).get("name", who))
	for identity in Exchange.CUSTOMER_OFFERS:
		if str(Exchange.CUSTOMER_OFFERS[identity].buyer) == who:
			tab = "sell"
			message.text = words("%s 柜台：他们收你的钢坯，在“出售”里按他们的价上架就成交。" % name, "%s COUNTER: THEY BUY YOUR BILLETS; LIST AT THEIR PRICE UNDER SELL." % name)
			return
	var best := ""
	var most := 0.0
	for o in _state().get("orders", []):
		if str(o.owner) == who and str(o.side) == "sell" and str(o.state) == "open" and float(o.remaining) > most:
			most = float(o.remaining)
			best = str(o.item)
	if best != "":
		select_item(best)
	message.text = words("%s 柜台：本港现货，成交后几十秒送到仓库。" % name, "%s COUNTER: PORT STOCK, IN THE WAREHOUSE WITHIN SECONDS." % name)


func explain(result: Dictionary) -> void:
	var reasons := {"insufficient_funds": words("可用资金不足", "INSUFFICIENT FUNDS"), "insufficient_stock": words("可用库存不足", "INSUFFICIENT STOCK"), "trade_repair_required": words("请先恢复贸易港营业", "RESTORE THE TRADE DISTRICT FIRST"), "exchange_closed": StoreBook.exchange_closed_text(), "save_failed": words("保存失败，操作未提交，请重试", "SAVE FAILED; RETRY."), "not_open": words("该挂单已结束", "ORDER ALREADY CLOSED"), "no_rush": words("加急单已经结束了", "THE RUSH HAS ENDED")}
	reasons.merge({"quote_unavailable": words("这笔报价已售罄或撤回，请选择另一笔", "LISTING SOLD OUT OR WITHDRAWN"), "quote_changed": words("报价已变更，未扣款，请重新查看", "PRICE CHANGED; NO PAYMENT TAKEN"), "quote_quantity": words("购买量超过该卖家剩余数量，未扣款", "QUANTITY EXCEEDS THIS SELLER'S STOCK")})
	message.text = words("已提交", "COMMITTED") if result.get("ok", false) else str(reasons.get(result.get("reason", ""), words("操作未提交，请检查选择和数值", "REJECTED; CHECK THE VALUES")))
	_stamp = ""
	refresh()


func select_quote(identity: String) -> void:
	var state := _state()
	for order in state.get("orders", []):
		if order.id != identity or order.state != "open":
			continue
		purchase_quote = order.duplicate(true)
		purchase_info.text = "%s\n%s · %s / t\n%s" % [Ops.item_name(Exchange.lot_key(str(order.item), int(order.grade))), str(state.actors[order.owner].name), Pal.money(float(order.price)), words("这家剩余 %.3f t；%s。", "%.3f t LEFT; %s.") % [float(order.remaining), where(str(order.owner))]]
		purchase_quantity.max_value = float(order.remaining)
		purchase_quantity.value = minf(1.0, float(order.remaining))
		update_purchase_total()
		purchase.popup_centered(Vector2i(560, 320))
		return
	explain({"ok": false, "reason": "quote_unavailable"})


func update_purchase_total() -> void:
	if purchase_quote.is_empty():
		return
	var total := purchase_quantity.value * float(purchase_quote.price)
	purchase_total.text = words("本次合计 ", "TOTAL ") + Pal.money(total) + words("\n成交后运进仓库，到了才能用。", "\nSHIPPED IN; USABLE ON ARRIVAL.")
	purchase.get_ok_button().disabled = total > float(Career.data.money) or Port.stage("trade") < 1


func confirm_purchase() -> void:
	var result := Exchange.command("buy_quote", {"order_id": purchase_quote.get("id", ""), "price": purchase_quote.get("price", 0.0), "quantity": purchase_quantity.value})
	explain(result)
	if result.get("ok", false):
		message.text = GuideCopy.text("market.purchase_success")


# kept for callers of the old paged guide (27 号 replaced it with the on-site guide)
func close_guide() -> void:
	pass


func toggle_pause() -> void:
	_paused_here = not get_tree().paused
	get_tree().paused = _paused_here
	if game != null:
		game.paused_sim = _paused_here
	_stamp = ""
	refresh()


# the next step from what is really in stock (Ops.next_step), as an on-site guide
func start_guide() -> void:
	if game == null or game.get("guide") == null:
		return
	var go := str(Ops.next_step().get("go", ""))
	var t := Guide.task_for(go)
	if t == "" and go == "tab:0":
		t = "retain"
	if t == "":
		t = "trade"
	game.guide.begin(t)
	if t in ["clients", "buy_feed", "trade"]:
		if t == "clients":
			_tab("sell")
		elif t == "buy_feed":
			select_item("ferrous_scrap")
			grade = 1
			refresh()
		return
	close()


func open_ship_market() -> void:
	if game == null:
		return
	var g = game
	if close():
		Back.go(_back_entry(), "ship_market", func(): g.open_ship_market())


func open_star_map() -> void:
	if game == null:
		return
	var g = game
	if close():
		Back.go(_back_entry(), "star_map", func(): g.open_star_map())


# 134 号: how to open the exchange again, for the page it leaves for (scripts/ui_back.gd)
func _back_entry() -> Dictionary:
	var g = game
	return Back.entry("exchange", ["交易行", "THE EXCHANGE"], func(): g.open_exchange())


# Esc and the close key: back where the exchange was opened from, else away
func _back() -> void:
	if close():
		Back.back()


func close() -> bool:
	if not Career.save():
		explain({"ok": false, "reason": "save_failed"})
		return false
	if _paused_here:
		get_tree().paused = false
		if game != null:
			game.paused_sim = false
	if BenchFx.leaving(self):
		return true
	var handed := BenchFx.leave(self)
	if on_close.is_valid():
		on_close.call()
	elif not handed:
		queue_free()
	return true



func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		if sell_win.visible:
			sell_win.visible = false
		else:
			_back()
		get_viewport().set_input_as_handled()
