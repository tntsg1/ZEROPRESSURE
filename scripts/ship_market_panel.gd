extends Control
# The hulk market (33 号, 41 号; 45 号 player 2026-10-25: "no pictures, far too complicated —
# do it like the example"): big cards with the ship's own side view, its name, where it lies and
# how long the tow, its rating and one big price. Click a card: a window with the ship drawn
# large (what the inspections found written on it), the two inspections under it, the price
# against the broker's value, the seller's word and the rating in one line each, and one big
# buy button; the counter-offer, the held quote, the tow's numbers and the agency's record fold
# under "more". My ships: cards with their state, resale, claims and reports.

var game
var on_close: Callable
var chosen := ""
var cat := "all"            # all | small | mid | large | mine
var main: VBoxContainer
var detail_win: PanelContainer
var detail: VBoxContainer
var more_box: VBoxContainer
var msg: Label
var cat_keys := {}
var _resale_price := {}
var _spins := {}
var _stamp := ""
var dimmer: ColorRect          # darkens the page behind a pop-up window
var _t := 0.0
var _live: Array = []          # each card's clock: the time up / left, every second
var _dlive: Array = []         # the open window's clock
const Face := preload("res://scripts/listing_face.gd")
const Back := preload("res://scripts/ui_back.gd")


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _label(s: String, px := 16, ink := 0.9) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", Pal.ink(ink))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _btn(s: String, cb: Callable, h := 42.0) -> Button:
	var b := Button.new()
	b.text = s
	b.custom_minimum_size.y = h
	b.pressed.connect(cb)
	return b


func _sfx(id: String) -> void:
	if game != null and game.get("sfx") != null:
		game.sfx.play(id)


# a line that just changed blinks up once, so a press is seen to have done something
func _flash(c: CanvasItem) -> void:
	c.modulate = Color(1.6, 1.6, 1.6)
	create_tween().tween_property(c, "modulate", Color.WHITE, 0.45)


func _box(bg: Color, edge: Color, pad := 10.0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = edge
	b.set_border_width_all(1)
	for side in ["left", "right", "top", "bottom"]:
		b.set("content_margin_" + side, pad)
	return b


func _ready() -> void:
	Back.arrive()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiSkin.theme()
	# 51 号: the new look's ground (gradient, drifting glow, the pointer's light)
	add_child(UiSkin.Ground.new())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var title := _label(w("零压港 · 船市", "ZERO PRESSURE PORT · HULK MARKET"), 22, 0.95)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var bal := _label(w("可用资金 ", "FUNDS ") + Pal.money(float(Career.data.money)), 18)
	bal.autowrap_mode = TextServer.AUTOWRAP_OFF
	bal.add_theme_color_override("font_color", Pal.tint(Pal.AIR, 0.95, 1.2))
	top.add_child(bal)
	# came from the exchange: the back key says so, no second key to it
	if not (Back.has_back() and str(Back.stack[-1].key) == "exchange"):
		top.add_child(_btn(w("回交易行", "TO THE EXCHANGE"), _to_exchange))
	top.add_child(_btn(Back.close_text(), _back))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	column.add_child(body)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 190
	side.add_theme_constant_override("separation", 6)
	body.add_child(side)
	for c in [["all", w("全部挂牌", "ALL LISTINGS")], ["small", w("小型（≤ 40 m）", "SMALL (≤ 40 m)")], ["mid", w("中型（40–70 m）", "MID (40–70 m)")], ["large", w("大型（≥ 70 m）", "LARGE (≥ 70 m)")], ["mine", w("我的船", "MY SHIPS")]]:
		var b := _btn(str(c[1]), _cat.bind(str(c[0])))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		cat_keys[c[0]] = b
		side.add_child(b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_scroll = scroll
	main = VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 10)
	scroll.add_child(main)
	msg = _label("", 16)
	column.add_child(msg)
	dimmer = ColorRect.new()
	dimmer.color = Color(0.02, 0.025, 0.03, 0.7)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.visible = false
	add_child(dimmer)
	detail_win = PanelContainer.new()
	var win := UiSkin.solid(Color("171b21"), 22, 24.0)
	win.border_color = Color(1, 1, 1, 0.1)
	win.set_border_width_all(1)
	win.shadow_color = Color(0, 0, 0, 0.6)
	win.shadow_size = 40
	detail_win.add_theme_stylebox_override("panel", win)
	detail_win.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	detail_win.grow_horizontal = Control.GROW_DIRECTION_BOTH
	detail_win.grow_vertical = Control.GROW_DIRECTION_BOTH
	detail_win.custom_minimum_size = Vector2(1180, 600)
	detail_win.visible = false
	add_child(detail_win)
	detail = VBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)
	detail_win.add_child(detail)
	if ShipMarket.refresh():
		Career.save()
	_fill()


func _signature() -> String:
	var listings: Array = ShipMarket.data().listings.filter(func(l): return not l.has("feed")).map(func(l): return str(l.id))
	listings.append(ShipMarket.data().get("gone", {}).size())
	return "%s/%d/%s" % [str(listings), ShipMarket.data().assets.size(), str(ShipMarket.data().assets.map(func(a): return str(a.state) + str(a.has("resale"))))]


func _process(dt: float) -> void:
	if _was_open and not detail_win.visible:
		_redo(chosen)
	_was_open = detail_win.visible
	dimmer.visible = detail_win.visible
	_feed_step()
	_t += dt
	if _t > 1.0:
		_t = 0.0
		for f in _live + _dlive:
			f.call()
		_new_text()
		if _signature() != _stamp:
			var sv := _scroll.scroll_vertical
			_fill()
			_want_scroll = sv
			if detail_win.visible and ShipMarket.listing(chosen).is_empty():
				detail_win.visible = false
				msg.text = w("这艘船已下架。", "THIS SHIP IS NO LONGER LISTED.")


func _cat(c: String) -> void:
	cat = c
	_snap = -1.0
	_scroll.scroll_vertical = 0
	_fill()


func _sort(k: String) -> void:
	sort = k
	_snap = -1.0
	_scroll.scroll_vertical = 0
	_fill()


static func length_of(l: Dictionary) -> float:
	return float(Market.type_of(str(l.offer.ship)).get("length", 30.0))


static func ship_name(l: Dictionary) -> String:
	var ty: Dictionary = Market.type_of(str(l.offer.ship))
	return "%s · %d m" % [(ty.name[0] if Txt.zh else ty.name[1]) if ty.has("name") else str(l.offer.ship), int(ty.get("length", 0))]


func shown_listings() -> Array:
	var out: Array = []
	for l in ShipMarket.data().listings:
		var L := length_of(l)
		if cat == "mine":
			continue
		if cat == "small" and L > 40.0:
			continue
		if cat == "mid" and (L <= 40.0 or L >= 70.0):
			continue
		if cat == "large" and L < 70.0:
			continue
		out.append(l)
	return out


func _fill() -> void:
	_stamp = _signature()
	for id in _spins:
		if is_instance_valid(_spins[id]):
			_resale_price[id] = (_spins[id] as SpinBox).value
	_spins.clear()
	_live.clear()
	_cards.clear()
	_spare.clear()
	feed_area = null
	for c in cat_keys:
		cat_keys[c].add_theme_stylebox_override("normal", _box(Color(0.07, 0.09, 0.1), Pal.tint(Pal.AIR, 0.8, 1.1) if c == cat else Pal.ink(0.2), 8.0))
	for ch in main.get_children():
		main.remove_child(ch)
		ch.queue_free()
	if cat == "mine":
		_mine()
		return
	_feed_page()


# ---------------------------------------------------------------- the endless feed (133 号)
# user 2026-11-10 ("二手船市你可以做成无限的，和淘宝一样"): the page reads every listing up (the kept
# ones and the belt's feed, scripts/ship_market.gd) at one moment and lays them out three to a row;
# only the cards on screen and a row either side exist, built as they scroll in (a few per frame)
# and let go as they scroll out, so a deep scroll costs what the first screen does. New listings
# wait behind 刷新 so the page does not move under the pointer; one that ran out while the page was
# open says so on its card and is gone at the next read.

const CARD_H := 340.0
const GAP := 12.0
const COLS := 3
const PRICE_POOL := 240
var sort := "mix"             # mix | price | near | new
var sort_keys := {}
var _scroll: ScrollContainer
var feed_area: Control
var _head: Label
var _foot: Label
var new_btn: Button
var _items: Array = []        # {id, listed, expires, station, ship, m (feed slot) | l (kept), pin}
var _total := 0
var _cards := {}              # index in _items -> its card
var _spare: Array = []        # cards off screen, kept to be filled again
var _last_sv := 0
var _snap := -1.0             # the orbit day the page was read at
var _pool: Array = []         # price order: the newest PRICE_POOL still to be drawn
var _pool_all: Array = []
var _tow_s := {}              # station -> its arc home (the cards' tow line, the nearest-first order)
var _want_scroll := -1
var _was_open := false


func _in_cat(ship: String) -> bool:
	var L := float(Market.type_of(ship).get("length", 30.0))
	match cat:
		"small": return L <= 40.0
		"mid": return L > 40.0 and L < 70.0
		"large": return L >= 70.0
	return true


func _feed_page() -> void:
	_head = _label("", 14, 0.6)
	main.add_child(_head)
	var bar := _hrow(8)
	main.add_child(bar)
	var sl := _label(w("排序", "SORT"), 13, 0.45)
	sl.autowrap_mode = TextServer.AUTOWRAP_OFF
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(sl)
	sort_keys.clear()
	for k in [["mix", w("综合", "BEST MATCH")], ["price", w("价格从低到高", "PRICE: LOW FIRST")], ["near", w("离港近", "NEAREST")], ["new", w("刚上架", "NEWEST")]]:
		var b := _btn(str(k[1]), _sort.bind(str(k[0])), 34.0)
		b.add_theme_stylebox_override("normal", _box(Color(0.07, 0.09, 0.1), Pal.tint(Pal.AIR, 0.8, 1.1) if k[0] == sort else Pal.ink(0.2), 8.0))
		sort_keys[k[0]] = b
		bar.add_child(b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(sp)
	new_btn = _btn(w("刷新", "REFRESH"), func():
		_snap = -1.0
		_scroll.scroll_vertical = 0
		_fill(), 34.0)
	bar.add_child(new_btn)
	feed_area = Control.new()
	feed_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feed_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed_area.draw.connect(_draw_slots)
	main.add_child(feed_area)
	_foot = _label("", 14, 0.5)
	_foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_child(_foot)
	_read_feed()
	_new_text()
	_place(true)


# every listing up at the page's moment, in the chosen order
func _read_feed() -> void:
	var now := Shipping.day()
	if _snap < 0.0:
		_snap = now
		_tow_s.clear()
	var have := {}
	var out: Array = []
	for l in shown_listings():
		have[str(l.id)] = true
		out.append({"id": str(l.id), "listed": float(l.get("listed", now)), "expires": float(l.get("expires", now)), "station": int(l.station),
			"ship": str(l.offer.ship), "l": l, "pin": l.has("showcase") or l.has("hold")})
	for m in ShipMarket.feed(now, _snap):
		if have.has(str(m.id)) or not _in_cat(str(m.ship)):
			continue
		out.append({"id": str(m.id), "listed": float(m.listed), "expires": float(m.expires), "station": int(m.station), "ship": str(m.ship), "m": m, "pin": false})
	_total = out.size()
	_pool.clear()
	_pool_all.clear()
	match sort:
		"new":
			out.sort_custom(func(a, b): return a.listed > b.listed)
		"near":
			for e in out:
				e.tow = _tow(int(e.station))
			out.sort_custom(func(a, b): return a.tow < b.tow or (a.tow == b.tow and a.listed > b.listed))
		"price":
			out.sort_custom(func(a, b): return a.listed > b.listed)
			_pool_all = out.slice(0, PRICE_POOL)
			_pool = _pool_all.duplicate()
			out = []
		_:
			# best match: a held quote and the port's showcases first, then fresh ones mixed in bands
			for e in out:
				e.k = (0.0 if e.pin else 1.0e9) + floor((now - float(e.listed)) / 60.0) * 1.0e4 + float(posmod(hash(e.id), 10000))
			out.sort_custom(func(a, b): return a.k < b.k)
	_items = out
	var n := _total
	_head.text = w("当前有 %d 条在售挂牌 · 往下滚一直有 · 点一艘船看详情。卖家照例往好里说，评级各有盲区；结构、系统检验各看一类，产权核查查扣押和危废责任。", "%d ACTIVE LISTINGS · MORE AS YOU SCROLL · PICK ONE. SELLERS TALK THEM UP; RATINGS HAVE BLIND SPOTS; EACH INSPECTION READS ONE SIDE; THE TITLE SEARCH FINDS LIENS AND WASTE LIABILITY.") % n
	_foot_text()


func _tow(st: int) -> float:
	return ShipMarket.fast_days(float(_run(st).tof)) / Orbits.DAYS_PER_S


# a station's arc home, worked out once per reading of the page (a Lambert solve is ~10 ms)
func _run(st: int) -> Dictionary:
	if not _tow_s.has(st):
		_tow_s[st] = Orbits.transfer(Orbits.station(st), Orbits.PORT, Shipping.day())
	return _tow_s[st]


func _foot_text() -> void:
	if _foot == null or not is_instance_valid(_foot):
		return
	if sort == "price":
		if not _pool.is_empty():
			_foot.text = w("正在按价格整理最新上架的 %d 条… %d/%d", "SORTING THE NEWEST %d BY PRICE… %d/%d") % [_pool_all.size(), _pool_all.size() - _pool.size(), _pool_all.size()]
		else:
			_foot.text = w("价格排序只排最新上架的 %d 条 · 换“综合”看全部 %d 条", "PRICE ORDER COVERS THE NEWEST %d · BEST MATCH SHOWS ALL %d") % [_items.size(), _total]
	elif _items.is_empty():
		_foot.text = w("这一类现在没有挂牌。", "NO LISTINGS HERE NOW.")
	else:
		_foot.text = w("到底了 · 共 %d 条在售", "THAT'S ALL · %d FOR SALE") % _items.size()


# 刷新 counts what the belt has listed since the page was read
func _new_text() -> void:
	if new_btn == null or not is_instance_valid(new_btn) or _snap < 0.0:
		return
	var n := int(floor(Shipping.day() / ShipMarket.FEED_GAP)) - int(floor(_snap / ShipMarket.FEED_GAP))
	new_btn.text = (w("刷新 · 新上架 %d 条", "REFRESH · %d NEW") % n) if n > 0 else w("刷新", "REFRESH")


# every frame: the price order drawn a few at a time, the cards on screen built, the rest let go
var step_us := 0              # what the last frame's feed work took (the scroll test reads it)
var built := 0                # cards filled so far


func _feed_step() -> void:
	if feed_area == null or not is_instance_valid(feed_area):
		return
	var us := Time.get_ticks_usec()
	_feed_work()
	step_us = Time.get_ticks_usec() - us


func _feed_work() -> void:
	if not _pool.is_empty():
		var t0 := Time.get_ticks_usec()
		while not _pool.is_empty() and Time.get_ticks_usec() - t0 < 6000:
			var e: Dictionary = _pool.pop_front()
			if not e.has("l"):
				e.l = ShipMarket.feed_draft(e.m)
			e.price = float(e.l.get("price", INF))
		if _pool.is_empty():
			_items = _pool_all.filter(func(e): return not (e.l as Dictionary).is_empty())
			_items.sort_custom(func(a, b): return a.price < b.price or (a.price == b.price and a.listed > b.listed))
		_foot_text()
	_place()
	if _want_scroll >= 0:
		_scroll.scroll_vertical = _want_scroll
		if absi(_scroll.scroll_vertical - _want_scroll) <= 1 or feed_area.custom_minimum_size.y > float(_want_scroll) + _scroll.size.y:
			_want_scroll = -1


func _place(all := false) -> void:
	if feed_area == null or not is_instance_valid(feed_area):
		return
	var n := _items.size()
	var rows := int(ceil(n / float(COLS)))
	var h := maxf(0.0, rows * (CARD_H + GAP) - GAP)
	if not is_equal_approx(feed_area.custom_minimum_size.y, h):
		feed_area.custom_minimum_size.y = h
	var wd := feed_area.size.x
	if wd < 100.0:
		wd = maxf(100.0, _scroll.size.x - 12.0)
	var cw := (wd - GAP * (COLS - 1)) / COLS
	var step := CARD_H + GAP
	var top := float(_scroll.scroll_vertical) - feed_area.position.y
	var view := maxf(_scroll.size.y, 600.0)
	var r0 := maxi(0, int(floor(top / step)) - 1)
	var r1 := mini(rows - 1, int(floor((top + view) / step)) + 1)
	for i in _cards.keys():
		var r := int(i) / COLS
		if r < r0 - 1 or r > r1 + 1 or int(i) >= n:
			_drop(int(i))
	var t0 := Time.get_ticks_usec()
	var missing := false
	var filled := 0
	for r in range(r0, r1 + 1):
		for c in COLS:
			var i := r * COLS + c
			if i >= n:
				break
			if not _cards.has(i):
				# one card a frame while scrolling (a refill and its re-layout come to ~5 ms)
				if not all and (filled > 0 or Time.get_ticks_usec() - t0 > 4000):
					missing = true
					continue
				filled += 1
				var e: Dictionary = _items[i]
				var l := ShipMarket.listing(str(e.id))
				if l.is_empty():
					l = e.get("l", {})
				if l.is_empty():
					l = ShipMarket.feed_draft(e.m)
					e.l = l
				if l.is_empty():
					continue
				var card: Button = _spare.pop_back() if not _spare.is_empty() else null
				if card == null:
					card = _card_shell()
					feed_area.add_child(card)
				card.visible = true
				_card_fill(card, l)
				built += 1
				_cards[i] = card
			var cd: Control = _cards[i]
			cd.position = Vector2(c * (cw + GAP), r * step)
			cd.size = Vector2(cw, CARD_H)
	if missing or feed_area.get_meta("missing", false):
		feed_area.set_meta("missing", missing)
		feed_area.queue_redraw()
	# a frame that filled nothing draws the listings a few rows ahead, so the frame that fills
	# their card has only the card to do
	if filled == 0 and not all:
		var dir := 1 if _scroll.scroll_vertical >= _last_sv else -1
		_last_sv = _scroll.scroll_vertical
		var a := (r1 + 1) * COLS if dir > 0 else maxi(0, (r0 - 4) * COLS)
		for i in range(a, mini(n, a + 4 * COLS)):
			if Time.get_ticks_usec() - t0 > 2000:
				break
			var e: Dictionary = _items[i]
			if not e.has("l") and e.has("m"):
				e.l = ShipMarket.feed_draft(e.m)
	else:
		_last_sv = _scroll.scroll_vertical


func _drop(i: int) -> void:
	var card: Control = _cards.get(i)
	_cards.erase(i)
	if card != null and is_instance_valid(card):
		_live.erase(card.get_meta("tick", Callable()))
		card.visible = false
		card.scale = Vector2.ONE
		card.set_meta("id", "")
		_spare.append(card)


# a card is built again from the save after its window closes (held, offered on, inspected)
func _redo(id: String) -> void:
	for i in _cards.keys():
		if int(i) < _items.size() and str(_items[int(i)].id) == id:
			_drop(int(i))


# where a card is still to come: its place, faintly
func _draw_slots() -> void:
	if not feed_area.get_meta("missing", false):
		return
	var wd := feed_area.size.x
	var cw := (wd - GAP * (COLS - 1)) / COLS
	var step := CARD_H + GAP
	var top := float(_scroll.scroll_vertical) - feed_area.position.y
	for r in range(maxi(0, int(floor(top / step))), int(floor((top + _scroll.size.y) / step)) + 1):
		for c in COLS:
			var i := r * COLS + c
			if i < _items.size() and not _cards.has(i):
				feed_area.draw_rect(Rect2(c * (cw + GAP), r * step, cw, CARD_H), Color(1, 1, 1, 0.03))


# a card pressed: a feed listing is checked and kept, then its window opens (or it is withdrawn)
func _open(id: String) -> void:
	var had := not ShipMarket.listing(id).is_empty()
	if not ShipMarket.take(id):
		msg.text = w("卖家刚撤下了这条挂牌。", "THE SELLER HAS JUST WITHDRAWN THIS LISTING.")
		msg.add_theme_color_override("font_color", Hmi.warn_col())
		_flash(msg)
		_sfx("deny")
		var sv := _scroll.scroll_vertical
		_fill()
		_want_scroll = sv
		return
	if not had:
		Career.save()
	chosen = id
	_redo(id)
	_detail()


func _listing_card(l: Dictionary) -> Button:
	var b := _card_shell()
	_card_fill(b, l)
	return b


# 133 号: a card's nodes, made once; the feed fills the same few again and again as the page
# scrolls (a card entering the tree costs several milliseconds, refilling it a fraction of that)
func _card_shell() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(380, CARD_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func(): _open(str(b.get_meta("id", ""))))
	UiSkin.hover_lift(b, 14.0)
	var R := {}
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -14
	v.offset_top = 10
	v.offset_bottom = -12
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	# the strip: on sale, how long up, how long left (or why it cannot be bought)
	var strip := _hrow()
	v.add_child(strip)
	R.dot = _label("●", 11)
	R.dot.autowrap_mode = TextServer.AUTOWRAP_OFF
	R.dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	strip.add_child(R.dot)
	R.on = _label("", 13, 0.7)
	R.on.autowrap_mode = TextServer.AUTOWRAP_OFF
	R.on.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_child(R.on)
	R.left = _label("", 13, 0.55)
	R.left.autowrap_mode = TextServer.AUTOWRAP_OFF
	strip.add_child(R.left)
	# 133 号: the seller's own headline leads the card, the way a shop titles its goods
	R.ad = _label("", 19, 0.97)
	R.ad.max_lines_visible = 2
	R.ad.custom_minimum_size.y = 24
	v.add_child(R.ad)
	R.t = _label("", 14, 0.55)
	R.t.autowrap_mode = TextServer.AUTOWRAP_OFF
	R.t.clip_text = true
	v.add_child(R.t)
	# 108 号: a showcase says which method it is laid out for, on a line of its own
	R.sc = _label("", 14)
	R.sc.add_theme_color_override("font_color", UiSkin.ACCENT)
	v.add_child(R.sc)
	R.pic = ShipThumb.new({})
	R.pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(R.pic)
	# who sells it
	var who := _hrow(8)
	v.add_child(who)
	R.kind = _chip("")
	who.add_child(R.kind)
	R.nm = _label("", 15, 0.9)
	R.nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	R.nm.clip_text = true
	R.nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(R.nm)
	R.st = _label("", 12, 0.45)
	R.st.autowrap_mode = TextServer.AUTOWRAP_OFF
	who.add_child(R.st)
	# what the seller says against the rating (only what is on the page)
	var said := _hrow(8)
	v.add_child(said)
	R.cl = _label("", 13, 0.65)
	R.cl.autowrap_mode = TextServer.AUTOWRAP_OFF
	R.cl.clip_text = true
	R.cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	said.add_child(R.cl)
	R.rt = _label("", 13, 0.8)
	R.rt.autowrap_mode = TextServer.AUTOWRAP_OFF
	said.add_child(R.rt)
	v.add_child(_rule())
	# where it lies, the tow, who is looking | the price
	var foot := _hrow(10)
	v.add_child(foot)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(info)
	R.where = _label("", 13, 0.6)
	R.where.autowrap_mode = TextServer.AUTOWRAP_OFF
	info.add_child(R.where)
	R.heat = _label("", 13, 0.6)
	R.heat.autowrap_mode = TextServer.AUTOWRAP_OFF
	info.add_child(R.heat)
	var pr := VBoxContainer.new()
	pr.add_theme_constant_override("separation", -4)
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(pr)
	R.p = _label("", 26, 0.97)
	R.p.autowrap_mode = TextServer.AUTOWRAP_OFF
	R.p.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pr.add_child(R.p)
	R.off = _label("", 12, 0.5)
	R.off.autowrap_mode = TextServer.AUTOWRAP_OFF
	R.off.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pr.add_child(R.off)
	b.set_meta("R", R)
	return b


# a text set only when it differs (a Label re-shapes on every set)
func _put(x: Label, s: String) -> void:
	if x.text != s:
		x.text = s


func _card_fill(b: Button, l: Dictionary) -> void:
	var R: Dictionary = b.get_meta("R")
	var id := str(l.id)
	b.set_meta("id", id)
	b.disabled = false
	b.modulate.a = 1.0
	var fits := ShipMarket.fits(l)
	R.dot.add_theme_color_override("font_color", UiSkin.ACCENT if fits else Pal.ink(0.35))
	var tag := ""
	if not fits:
		tag = w("坞长不够", "TOO LONG")
	elif TugYard.full():
		tag = w("拖船站满了", "YARD FULL")
	var on: Label = R.on
	var left: Label = R.left
	var tick := func():
		_put(on, _status(l))
		if Face.left_s(l) <= 0.0 and not l.has("hold"):
			_put(left, w("已下架", "GONE"))
			left.add_theme_color_override("font_color", Pal.ink(0.4))
			b.disabled = true
			b.modulate.a = 0.45
			return
		if tag != "":
			_put(left, tag)
		elif Face.rush(l):
			_put(left, Face.rush_text(l))
		else:
			_put(left, Face.left_text(l))
		var hot := tag != "" or Face.rush(l) or l.has("hold")
		left.add_theme_color_override("font_color", UiSkin.ACCENT if hot else Pal.ink(0.55))
	tick.call()
	_live.erase(b.get_meta("tick", Callable()))
	_live.append(tick)
	b.set_meta("tick", tick)
	_put(R.ad, str(Face.headline(l).text))
	_put(R.t, ship_name(l) + "  ·  " + str(l.offer.reg))
	R.sc.visible = l.has("showcase")
	if l.has("showcase"):
		_put(R.sc, w("试试新拆法 · %s", "TRY THE NEW METHOD · %s") % Methods.name_of(str(l.showcase)))
	R.pic.offer = l.offer
	R.pic.tags = []
	R.pic.dim = not fits
	R.pic.custom_minimum_size = Vector2(0, 70 if l.has("showcase") else 84)
	R.pic.queue_redraw()
	var s := Face.seller(l)
	_put(R.kind, str(s.kind_name))
	_put(R.nm, str(s.name))
	_put(R.st, str(s.stats))
	_put(R.cl, Face.claim_line(l))
	if Face.clash(l):
		_put(R.rt, w("评级 %d/10 · 与实际情况不符", "RATING %d/10 · DOESN'T MATCH") % int(l.rating.score))
		R.rt.add_theme_color_override("font_color", UiSkin.ACCENT)
	else:
		_put(R.rt, w("评级 %d/10", "RATING %d/10") % int(l.rating.score))
		R.rt.add_theme_color_override("font_color", Pal.ink(0.8))
	var q := ShipMarket.tow_quote(l, _run(int(l.station)))
	_put(R.where, w("位置：%s · 预计拖回需要 %d 秒 · 拖运费用 %s", "LOCATION: %s · TOW TIME ~%d SEC · TOW COST %s") % [Orbits.name_of(Orbits.station(int(l.station))), int(ShipMarket.fast_days(float(q.run.tof)) / Orbits.DAYS_PER_S), Pal.money(float(q.fee))])
	_put(R.heat, _interest(l))
	_put(R.p, Pal.money(float(l.price)))
	_put(R.off, _under(l))


# "● 在售 · 已上架 4 分钟", or the hold, or a refused offer
func _status(l: Dictionary) -> String:
	var head := w("在售", "FOR SALE")
	if l.has("hold"):
		head = w("已保留", "RESERVED")
	elif l.get("haggled", false):
		head = w("在售 · 还价被拒绝", "FOR SALE · OFFER DECLINED")
	return head + " · " + Face.listed_text(l)


# the live mark in front of the status: the theme colour while it can be had
func _dot(l: Dictionary) -> Label:
	var d := _label("●", 11)
	d.autowrap_mode = TextServer.AUTOWRAP_OFF
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	d.add_theme_color_override("font_color", UiSkin.ACCENT if ShipMarket.fits(l) else Pal.ink(0.35))
	return d


func _interest(l: Dictionary) -> String:
	var n := Face.interest(l)
	if int(n[1]) > 0:
		return w("%d 人正在关注 · %d 人询问过价格", "%d WATCHING · %d INQUIRED") % [int(n[0]), int(n[1])]
	return w("%d 人正在关注", "%d WATCHING") % int(n[0])


func _under(l: Dictionary) -> String:
	var s := w("低于估价 %d%%", "%d%% BELOW ESTIMATED VALUE") % int(round(Face.under_value(l) * 100.0))
	var t := ShipMarket.title_of(l)
	if str(t.kind) != "" and str(t.get("how", "")) == "admitted":
		s += w(" · 因产权问题已降价 %d%%", " · %d%% DISCOUNT FOR TITLE ISSUES") % int(round((1.0 - ShipMarket.TITLE_ADMIT_CUT) * 100.0))
	return s


func _hrow(sep := 6) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


# a small filled tag (no outline): the seller's kind
func _chip(s: String, hot := false) -> Label:
	var c := _label(s, 12, 0.85)
	c.autowrap_mode = TextServer.AUTOWRAP_OFF
	var bg := UiSkin.solid(Pal.tint(UiSkin.ACCENT, 0.16) if hot else Color(1, 1, 1, 0.07), 6, 3.0)
	bg.content_margin_left = 7
	bg.content_margin_right = 7
	c.add_theme_stylebox_override("normal", bg)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c


# a hairline between parts of a card (not a frame)
func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(1, 1, 1, 0.06)
	r.custom_minimum_size.y = 1
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# ---------------------------------------------------------------- the detail window

func _detail() -> void:
	for c in detail.get_children():
		detail.remove_child(c)
		c.queue_free()
	_dlive.clear()
	var l := ShipMarket.listing(chosen)
	if l.is_empty():
		detail_win.visible = false
		return
	detail_win.visible = true
	var head := _hrow(12)
	detail.add_child(head)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_theme_constant_override("separation", 0)
	head.add_child(hv)
	var top := _hrow(6)
	hv.add_child(top)
	top.add_child(_dot(l))
	var on := _label("", 14, 0.65)
	on.autowrap_mode = TextServer.AUTOWRAP_OFF
	on.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(on)
	var tick := func():
		var tail := Face.rush_text(l) if Face.rush(l) else Face.left_text(l)
		on.text = "%s · %s · %s" % [_status(l), tail, _interest(l)]
	tick.call()
	_dlive.append(tick)
	hv.add_child(_label("%s  ·  %s" % [ship_name(l), str(l.offer.reg)], 24, 0.97))
	head.add_child(_btn(w("关闭", "CLOSE"), func(): detail_win.visible = false))
	var row := _hrow(22)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(row)
	# left: the ship large, what the inspections found on it; the seller's word against the checks
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	var pic := ShipThumb.new(l.offer)
	pic.custom_minimum_size = Vector2(640, 260)
	pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for cat2 in ["structure", "systems"]:
		if l.inspected.has(cat2):
			for trap in l.inspected[cat2]:
				pic.tags.append(ShipMarket.trap_name(trap))
	left.add_child(pic)
	left.add_child(_compare(l))
	var vd := Face.verdict(l)
	if vd.is_empty():
		left.add_child(_label(w("广告是卖家自己写的，购买前可以用上面的检验项目核对一下。", "THE AD IS WRITTEN BY THE SELLER; CHECK IT AGAINST THE INSPECTIONS ABOVE BEFORE YOU BUY."), 14, 0.5))
	else:
		var vl := _label(str(vd.text), 15, 0.75)
		if vd.hot:
			vl.add_theme_color_override("font_color", UiSkin.ACCENT)
		left.add_child(vl)
	# right: who sells it, the price, how to buy, the big buy
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 460
	right.add_theme_constant_override("separation", 8)
	row.add_child(right)
	var s := Face.seller(l)
	var who := _hrow(8)
	right.add_child(who)
	who.add_child(_chip(str(s.kind_name)))
	var nm := _label(str(s.name), 18, 0.95)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(nm)
	right.add_child(_label(str(s.stats), 13, 0.5))
	right.add_child(_label(w("卖家广告", "THE SELLER'S AD"), 13, 0.45))
	right.add_child(_label("“%s”" % str(Face.headline(l).text), 22, 0.97))
	var quote := _label(str(s.line), 15, 0.72)
	right.add_child(quote)
	right.add_child(_rule())
	var ask := _row(w("要价", "ASKING"), Pal.money(float(l.price)))
	(ask.get_child(1) as Label).add_theme_font_size_override("font_size", 28)
	right.add_child(ask)
	right.add_child(_row(w("经纪估值", "BROKER'S VALUE"), Pal.money(float(l.offer.value))))
	var under := _label(_under(l), 13, 0.55)
	under.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(under)
	var ag: Dictionary = ShipMarket.AGENCIES[str(l.rating.agency)]
	var rt := _label(w("评级 %d/10 · %s", "RATED %d/10 · %s") % [int(l.rating.score), ag.name[0] if Txt.zh else ag.name[1]], 15, 0.85)
	right.add_child(rt)
	if Face.clash(l):
		var cw := _label(w("卖家说这一项没有问题，但负责检查这一项的机构只给了 %d 分，和卖家的描述对不上。", "THE SELLER SAYS THIS SIDE HAS NO ISSUES, BUT THE AGENCY THAT CHECKS IT GAVE ONLY %d: IT DOESN'T MATCH THE SELLER'S DESCRIPTION.") % int(l.rating.score), 14)
		cw.add_theme_color_override("font_color", UiSkin.ACCENT)
		right.add_child(cw)
	right.add_child(_rule())
	var q := ShipMarket.tow_quote(l)
	var deposit := float(l.hold.deposit) if l.has("hold") else 0.0
	var total := float(l.price) + float(q.fee) - deposit
	right.add_child(_label(w("怎么买", "HOW TO BUY"), 13, 0.45))
	for step in [w("① 先检查船况：如果不确定船舶的实际情况，可以先购买左边的检验项目，每项检验都需要单独付费。", "① CHECK HER CONDITION FIRST: IF YOU'RE UNSURE OF THE SHIP'S REAL STATE, BUY THE INSPECTIONS ON THE LEFT FIRST; EACH IS PAID FOR SEPARATELY."),
			w("② 还价或保留：你可以向卖家还价一次，也可以支付定金保留当前报价，相关选项都在「更多」里面。", "② COUNTER-OFFER OR RESERVE: YOU CAN MAKE THE SELLER ONE COUNTER-OFFER, OR PAY A DEPOSIT TO RESERVE THE CURRENT QUOTE; BOTH ARE UNDER \"MORE\"."),
			w("③ 确认购买：购买时需要一次付清船舶要价和 %s 的拖运费用，付款完成后，拖船就会出发。", "③ CONFIRM THE PURCHASE: THE ASKING PRICE AND THE %s TOW COST ARE PAID IN ONE GO; ONCE PAID, THE TUG SETS OFF.") % Pal.money(float(q.fee))]:
		right.add_child(_label(step, 13, 0.62))
	# 121 号: a hulk that cannot be bought says so on the button, and a press says why (never a
	# dead button, never a silent press)
	var block := ShipMarket.buy_block(l, total)
	var note := _label(str(block.get("why", "")), 15)
	note.add_theme_color_override("font_color", Hmi.warn_col())
	note.visible = not block.is_empty()
	var buy := _btn(str(block.btn) if not block.is_empty() else w("买下并拖回 · 合计 %s", "BUY AND TOW · %s") % Pal.money(total), func():
		var b2 := ShipMarket.buy_block(l, total)
		if not b2.is_empty():
			note.text = str(b2.why)
			note.visible = true
			msg.text = str(b2.btn) + "：" + str(b2.why)
			msg.add_theme_color_override("font_color", Hmi.warn_col())
			_flash(note)
			_sfx("deny")
			return
		var r := ShipMarket.buy(str(l.id))
		if not r.ok:
			note.text = str(r.reason)
			note.visible = true
			_flash(note)
			_sfx("deny")
			return
		chosen = ""
		detail_win.visible = false
		_fill()
		_sfx("stamp")
		msg.text = w("已成交，拖船出发。到港后在合同页开工，或在“我的船”里转售。", "BOUGHT; THE TUG IS ON ITS WAY. START IT ON THE CONTRACTS PAGE OR RESELL IT UNDER MY SHIPS.")
		msg.add_theme_color_override("font_color", UiSkin.ACCENT)
		_flash(msg), 64.0)
	buy.add_theme_font_size_override("font_size", 22)
	if block.is_empty():
		UiSkin.accent_button(buy)
	right.add_child(buy)
	right.add_child(note)
	var more_key := _btn(w("更多 ▾（还价 · 保留报价 · 拖运 · 机构记录）", "MORE ▾ (OFFER · HOLD · TOW · AGENCY)"), func(): more_box.visible = not more_box.visible)
	right.add_child(more_key)
	more_box = VBoxContainer.new()
	more_box.visible = false
	more_box.add_theme_constant_override("separation", 6)
	right.add_child(more_box)
	_more(l, q)


# the seller's word against the checks, side by side: a row per side; the check's own button
# where it has not been bought yet
func _compare(l: Dictionary) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 6)
	for h in ["", w("卖家描述", "SELLER'S DESCRIPTION"), w("检验结果", "INSPECTION RESULTS")]:
		g.add_child(_label(h, 13, 0.45))
	var said := {}
	for st in l.statements:
		said[str(st.cat)] = st
	for cat3 in ["structure", "systems", "title"]:
		var nm: String = {"structure": w("结构检验", "STRUCTURE CHECK"), "systems": w("系统检验", "SYSTEMS CHECK"), "title": w("产权核查", "TITLE SEARCH")}[cat3]
		var side := _label({"structure": w("结构", "STRUCTURE"), "systems": w("系统", "SYSTEMS"), "title": w("产权", "OWNERSHIP")}[cat3], 15, 0.85)
		side.autowrap_mode = TextServer.AUTOWRAP_OFF
		side.custom_minimum_size.x = 56
		g.add_child(side)
		var word := ""
		if cat3 == "title":
			word = ShipMarket.title_text(l)
		elif said.has(cat3):
			word = ShipMarket.statement_text(said[cat3])
		var cut := word.find("：") if Txt.zh else word.find(": ")
		if cut >= 0:
			word = word.substr(cut + (1 if Txt.zh else 2))
		var wl := _label(word, 14, 0.75)
		wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wl.custom_minimum_size.x = 300
		g.add_child(wl)
		var b: Button
		if l.inspected.has(cat3):
			var found: Array = l.inspected[cat3]
			var res := (w("发现%s", "%s FOUND") % w("、", ", ").join(found.map(func(x): return ShipMarket.trap_name(x))) if not found.is_empty() else w("这一类没问题", "CLEAN"))
			if cat3 == "title":
				res = ("%s %s" % [ShipMarket.title_name(str(found[0])), Pal.money(float(ShipMarket.title_of(l).amount))]) if not found.is_empty() else w("产权清楚", "CLEAR")
			b = _btn(nm + w("：", ": ") + res, func(): pass)
			b.disabled = true
			if not found.is_empty():
				b.add_theme_color_override("font_disabled_color", UiSkin.ACCENT)
		else:
			var id := str(l.id)
			var c4: String = cat3
			b = _btn("%s  %s" % [nm, Pal.money(ShipMarket.inspect_cost(l, cat3))], func():
				var r := ShipMarket.inspect(id, c4)
				_detail()
				if not r.ok:
					msg.text = str(r.reason))
		b.custom_minimum_size.x = 290
		b.clip_text = true
		b.tooltip_text = b.text
		g.add_child(b)
	return g


func _row(a: String, b: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	var la := _label(a, 16, 0.65)
	la.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(la)
	var lb := _label(b, 20, 0.95)
	lb.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.add_child(lb)
	return r


func _more(l: Dictionary, q: Dictionary) -> void:
	var run: Dictionary = q.run
	var tug := TugFleet.free_tug()
	more_box.add_child(_label((w("自有拖船 %s · ", "OWN TUG %s · ") % tug if tug != "" else w("外包拖船 · ", "CONTRACT TUG · ")) + w("%d 天（约 %d 秒）· Δv %.1f + %.1f km/s · %s", "%d DAYS (~%d s) · Δv %.1f + %.1f km/s · %s") % [int(ShipMarket.fast_days(float(run.tof))), int(ShipMarket.fast_days(float(run.tof)) / Orbits.DAYS_PER_S), float(run.dv1), float(run.dv2), Pal.money(float(q.fee))], 14, 0.75))
	more_box.add_child(_label(ShipMarket.public_text(str(l.rating.agency)), 14, 0.8))
	more_box.add_child(_label(w("你的记录：", "YOUR RECORD: ") + ShipMarket.record_text(str(l.rating.agency)), 14, 0.75))
	for line in ShipMarket.own_lines(str(l.rating.agency)).slice(-5):
		more_box.add_child(_label("  · " + str(line), 13, 0.65))
	if l.has("hold"):
		more_box.add_child(_label(w("已付定金 %s 保留，还剩约 %d 秒；买下时抵扣，过期归卖家。", "HELD FOR %s, ~%d s LEFT; COUNTS TOWARD THE PRICE.") % [Pal.money(float(l.hold.deposit)), int(maxf(0.0, float(l.hold.until) - Shipping.day()) / Orbits.DAYS_PER_S)], 14, 0.8))
	else:
		var hid := str(l.id)
		more_box.add_child(_btn(w("付 %s 定金保留报价（约 5 分钟）", "HOLD THE QUOTE FOR %s (~5 MIN)") % Pal.money(snappedf(float(l.price) * ShipMarket.HOLD_SHARE, 10.0)), func():
			var r := ShipMarket.hold(hid)
			_detail()
			more_box.visible = true
			if not r.ok:
				msg.text = str(r.reason)))
	if l.get("haggled", false):
		more_box.add_child(_label(w("卖家已拒绝过你的还价，只能按标价买。", "THE SELLER TURNED YOUR OFFER DOWN."), 14, 0.7))
	else:
		var hr := HBoxContainer.new()
		more_box.add_child(hr)
		var offer := SpinBox.new()
		offer.min_value = ceilf(float(l.price) * ShipMarket.HAGGLE_MIN / 100.0) * 100.0
		offer.max_value = float(l.price)
		offer.step = 100.0
		offer.prefix = "$"
		offer.value = snappedf(float(l.price) * 0.9, 100.0)
		offer.custom_minimum_size.x = 160
		hr.add_child(offer)
		var gid := str(l.id)
		hr.add_child(_btn(w("还价（只有一次）", "OFFER (ONCE)"), func():
			var r := ShipMarket.haggle(gid, offer.value)
			if r.ok and r.get("accepted", true) and ShipMarket.listing(gid).is_empty():
				chosen = ""
				detail_win.visible = false
				_fill()
				msg.text = w("卖家同意了，已成交，拖船出发。", "ACCEPTED: BOUGHT, THE TUG IS ON ITS WAY.")
			else:
				_detail()
				msg.text = w("卖家拒绝了，不再谈。", "THE SELLER SAYS NO.") if r.ok else str(r.reason)))


# ---------------------------------------------------------------- my ships

func _mine() -> void:
	var assets: Array = ShipMarket.data().assets
	if assets.is_empty():
		main.add_child(_label(w("还没有自己的船。", "NO SHIPS OF YOUR OWN YET."), 18, 0.7))
		return
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	main.add_child(g)
	for a in assets:
		g.add_child(_mine_card(a))


func _mine_card(a: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(380, 0)
	card.add_theme_stylebox_override("panel", UiSkin.glass(0.04, 0.08, 16, 12.0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	v.add_child(_label(ship_name(a.listing), 17, 0.9))
	var pic := ShipThumb.new(a.listing.offer)
	pic.custom_minimum_size = Vector2(0, 110)
	pic.dim = str(a.state) in ["stripped", "sold"]
	v.add_child(pic)
	var state := ""
	match str(a.state):
		"towing":
			var by := TugFleet.towed_by(str(a.id))
			state = w("拖运中 · 还有 %d 天", "UNDER TOW · %d DAYS") % int(ceil(maxf(0.0, float(a.run.depart) + ShipMarket.tow_span(a) - Shipping.day()))) + (w(" · 自有拖船 %s", " · OWN TUG %s") % by if by != "" else w(" · 外包拖船", " · CONTRACT TUG"))
		"arrived": state = w("已到港 · 合同页里开工", "IN PORT · START IT ON THE CONTRACTS PAGE")
		"held": state = ShipMarket.held_text(a)
		"stripping": state = w("正在拆", "BEING STRIPPED")
		"stripped": state = w("已拆完", "STRIPPED") + (w(" · 已索赔 %s", " · CLAIMED %s") % Pal.money(float(a.get("claim_paid", 0.0))) if a.get("claimed", false) else "")
		"sold": state = w("已转售 %s（佣金 %s）", "RESOLD %s (FEE %s)") % [Pal.money(float(a.sold.price)), Pal.money(float(a.sold.fee))]
	if a.has("resale"):
		state += w(" · 挂牌转售 %s，等买家", " · LISTED AT %s") % Pal.money(float(a.resale.price))
	v.add_child(_label(state, 14, 0.8))
	var id := str(a.id)
	# 57 号: pay what holds it; claim an unsaid title defect once it was paid
	if str(a.state) == "held":
		var pay := _btn(w("付清 %s", "PAY %s") % Pal.money(float(ShipMarket.title_of(a.listing).amount)), func():
			var r := ShipMarket.pay_title(id)
			msg.text = (w("已付清 %s，船已放行，合同页里开工", "PAID %s; RELEASED — START IT ON THE CONTRACTS PAGE") % Pal.money(float(r.paid))) if r.ok else str(r.reason)
			_fill())
		UiSkin.accent_button(pay)
		v.add_child(pay)
	var tamount := ShipMarket.title_claimable(a)
	if tamount > 0.0:
		v.add_child(_btn(w("卖家没提这项产权问题：索赔 %s", "UNSAID TITLE DEFECT: CLAIM %s") % Pal.money(tamount), func():
			var r := ShipMarket.claim_title(id)
			msg.text = (w("索赔到账 %s", "CLAIM PAID %s") % Pal.money(float(r.amount))) if r.ok else str(r.reason)
			_fill()))
	var amount := ShipMarket.claimable(a)
	if amount > 0.0:
		v.add_child(_btn(w("凭证据索赔 %s", "CLAIM %s") % Pal.money(amount), func():
			var r := ShipMarket.claim(id)
			msg.text = (w("索赔到账 %s", "CLAIM PAID %s") % Pal.money(float(r.amount))) if r.ok else str(r.reason)
			_fill()))
	if ShipMarket.misrated(a) and not a.get("reported", false):
		v.add_child(_btn(w("评级失实：向船检监管举报", "REPORT THE FALSE RATING"), func():
			var r := ShipMarket.report(id)
			msg.text = (w("已记入该机构的公开记录", "ON THE AGENCY'S RECORD") + (w("；这份评级是卖家花钱买的，利益关联已证实", "; A PAID RATING, PROVED") if r.get("paid", false) else "")) if r.ok else str(r.reason)
			_fill()))
	if ShipMarket.can_resell(a):
		if a.has("resale"):
			v.add_child(_btn(w("撤下转售挂牌", "TAKE IT OFF THE MARKET"), func():
				var r := ShipMarket.unlist(id)
				msg.text = "" if r.ok else str(r.reason)
				_fill()))
		else:
			var band := ShipMarket.interest(a)
			v.add_child(_label(w("买家意向约 %s–%s", "BUYERS: ABOUT %s–%s") % [Pal.money(float(band[0])), Pal.money(float(band[1]))], 14, 0.7))
			var hr := HBoxContainer.new()
			v.add_child(hr)
			var spin := SpinBox.new()
			spin.min_value = 1000.0
			spin.max_value = maxf(10000.0, float(band[1]) * 3.0)
			spin.step = 100.0
			spin.prefix = "$"
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin.value = float(_resale_price.get(id, snappedf((float(band[0]) + float(band[1])) * 0.5, 100.0)))
			_spins[id] = spin
			hr.add_child(spin)
			hr.add_child(_btn(w("挂牌转售", "LIST FOR RESALE"), func():
				var r := ShipMarket.resell(id, spin.value)
				msg.text = w("挂出去了。价格合适的话一两分钟内有人买，钱当场到账（扣 3% 佣金）。", "LISTED. AT A FAIR PRICE A BUYER COMES IN A MINUTE OR TWO.") if r.ok else str(r.reason)
				_fill()))
	return card


func _to_exchange() -> void:
	var g = game
	var e := _back_entry()
	close()
	if g != null:
		Back.go(e, "exchange", func(): g.open_exchange())


# 134 号: how to open the market again as it is (its filter, order and scroll), for the page it
# leaves for; and restored when it is opened that way (scripts/ui_back.gd)
func _back_entry() -> Dictionary:
	var g = game
	var st := {"cat": cat, "sort": sort, "scroll": _scroll.scroll_vertical if _scroll != null else 0, "snap": _snap}
	return Back.entry("ship_market", ["二手船市", "HULK MARKET"], func():
		g.open_ship_market()
		if g.console_ui != null and g.console_ui.has_method("restore"):
			g.console_ui.restore(st))


func restore(st: Dictionary) -> void:
	cat = str(st.get("cat", "all"))
	sort = str(st.get("sort", "mix"))
	_snap = float(st.get("snap", -1.0))   # the page as it was read, not what came in since
	_fill()
	_want_scroll = int(st.get("scroll", 0))


func close() -> void:
	if on_close.is_valid():
		on_close.call()


# Esc and the close key: back where the market was opened from, else away
func _back() -> void:
	close()
	Back.back()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if detail_win.visible:
			detail_win.visible = false
		else:
			_back()
