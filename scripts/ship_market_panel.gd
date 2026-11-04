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
	top.add_child(_btn(w("回交易行", "TO THE EXCHANGE"), _to_exchange))
	top.add_child(_btn(w("关闭 [Esc]", "CLOSE [Esc]"), close))
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
	ShipMarket.refresh()
	_fill()


func _signature() -> String:
	return "%d/%d/%s" % [ShipMarket.data().listings.size(), ShipMarket.data().assets.size(), str(ShipMarket.data().assets.map(func(a): return str(a.state) + str(a.has("resale"))))]


func _process(dt: float) -> void:
	dimmer.visible = detail_win.visible
	_t += dt
	if _t > 1.0:
		_t = 0.0
		if _signature() != _stamp:
			_fill()


func _cat(c: String) -> void:
	cat = c
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
	for c in cat_keys:
		cat_keys[c].add_theme_stylebox_override("normal", _box(Color(0.07, 0.09, 0.1), Pal.tint(Pal.AIR, 0.8, 1.1) if c == cat else Pal.ink(0.2), 8.0))
	for ch in main.get_children():
		main.remove_child(ch)
		ch.queue_free()
	if cat == "mine":
		_mine()
		return
	main.add_child(_label(w("点一艘船看详情。卖家照例往好里说，评级各有盲区；结构、系统检验各看一类，产权核查查扣押和危废责任。", "PICK A SHIP. SELLERS TALK THEM UP; RATINGS HAVE BLIND SPOTS; EACH INSPECTION READS ONE SIDE; THE TITLE SEARCH FINDS LIENS AND WASTE LIABILITY."), 14, 0.6))
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	main.add_child(g)
	var list := shown_listings()
	for l in list:
		g.add_child(_listing_card(l))
	UiSkin.enter(g.get_children())
	if list.is_empty():
		main.add_child(_label(w("这一类现在没有挂牌。", "NO LISTINGS HERE NOW."), 18, 0.7))


func _listing_card(l: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(380, 250)
	var id := str(l.id)
	b.pressed.connect(func(): chosen = id; _detail())
	UiSkin.hover_lift(b, 14.0)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 8
	v.offset_bottom = -8
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var t := _label(ship_name(l), 17, 0.9)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var tag := ""
	if not ShipMarket.fits(l):
		tag = w("坞长不够", "TOO LONG")
	elif TugYard.full():
		tag = w("拖船站满了", "YARD FULL")
	elif l.has("hold"):
		tag = w("已保留", "HELD")
	if tag != "":
		var tg := _label(tag, 13)
		tg.autowrap_mode = TextServer.AUTOWRAP_OFF
		tg.add_theme_color_override("font_color", Color("ffb35c"))
		head.add_child(tg)
	# 108 号: a showcase says which method it is laid out for, on a line of its own
	if l.has("showcase"):
		var sc := _label(w("试试新拆法 · %s", "TRY THE NEW METHOD · %s") % Methods.name_of(str(l.showcase)), 14)
		sc.add_theme_color_override("font_color", UiSkin.ACCENT)
		v.add_child(sc)
	var pic := ShipThumb.new(l.offer)
	pic.custom_minimum_size = Vector2(0, 120)
	pic.dim = not ShipMarket.fits(l)
	v.add_child(pic)
	var run: Dictionary = ShipMarket.tow_quote(l).run
	v.add_child(_label(w("%s · 拖回约 %d 秒 · 评级 %d/10", "%s · TOW ~%d s · RATED %d/10") % [Orbits.name_of(Orbits.station(int(l.station))), int(ShipMarket.fast_days(float(run.tof)) / Orbits.DAYS_PER_S), int(l.rating.score)], 13, 0.6))
	var p := _label(Pal.money(float(l.price)), 22, 0.95)
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(p)
	return b


# ---------------------------------------------------------------- the detail window

func _detail() -> void:
	for c in detail.get_children():
		detail.remove_child(c)
		c.queue_free()
	var l := ShipMarket.listing(chosen)
	if l.is_empty():
		detail_win.visible = false
		return
	detail_win.visible = true
	var head := HBoxContainer.new()
	detail.add_child(head)
	var t := _label("%s  ·  %s" % [ship_name(l), str(l.offer.reg)], 22, 0.95)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_btn(w("关闭", "CLOSE"), func(): detail_win.visible = false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(row)
	# left: the ship large, what the inspections found on it, the two inspections
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var pic := ShipThumb.new(l.offer)
	pic.custom_minimum_size = Vector2(640, 300)
	pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for cat2 in ["structure", "systems"]:
		if l.inspected.has(cat2):
			for trap in l.inspected[cat2]:
				pic.tags.append(ShipMarket.trap_name(trap))
	left.add_child(pic)
	var ins := HBoxContainer.new()
	ins.add_theme_constant_override("separation", 8)
	left.add_child(ins)
	for cat3 in ["structure", "systems", "title"]:
		var nm: String = {"structure": w("结构检验", "STRUCTURE CHECK"), "systems": w("系统检验", "SYSTEMS CHECK"), "title": w("产权核查", "TITLE SEARCH")}[cat3]
		var b: Button
		if l.inspected.has(cat3):
			var found: Array = l.inspected[cat3]
			var res := (w("查出 %d 项", "%d FOUND") % found.size() if not found.is_empty() else w("这一类没问题", "CLEAN"))
			if cat3 == "title":
				res = ("%s %s" % [ShipMarket.title_name(str(found[0])), Pal.money(float(ShipMarket.title_of(l).amount))]) if not found.is_empty() else w("产权清楚", "CLEAR")
			b = _btn(nm + "：" + res, func(): pass)
			b.disabled = true
		else:
			var id := str(l.id)
			var c4: String = cat3
			b = _btn("%s  %s" % [nm, Pal.money(ShipMarket.inspect_cost(l, cat3))], func():
				var r := ShipMarket.inspect(id, c4)
				_detail()
				if not r.ok:
					msg.text = str(r.reason))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ins.add_child(b)
	# right: price against value, the seller's word, the rating, the big buy
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 440
	right.add_theme_constant_override("separation", 8)
	row.add_child(right)
	right.add_child(_row(w("要价", "ASKING"), Pal.money(float(l.price))))
	right.add_child(_row(w("经纪估值", "BROKER'S VALUE"), Pal.money(float(l.offer.value))))
	var said: Array = []
	for s in l.statements:
		said.append(ShipMarket.statement_text(s))
	said.append(ShipMarket.title_text(l))
	right.add_child(_label(w("卖家说：", "SELLER: ") + "  ".join(said), 15, 0.85))
	var ag: Dictionary = ShipMarket.AGENCIES[str(l.rating.agency)]
	right.add_child(_label(w("评级 %d/10 · %s", "RATED %d/10 · %s") % [int(l.rating.score), ag.name[0] if Txt.zh else ag.name[1]], 15, 0.85))
	var q := ShipMarket.tow_quote(l)
	var deposit := float(l.hold.deposit) if l.has("hold") else 0.0
	var total := float(l.price) + float(q.fee) - deposit
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
	close()
	if g != null:
		g.open_exchange.call_deferred()


func close() -> void:
	if on_close.is_valid():
		on_close.call()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if detail_win.visible:
			detail_win.visible = false
		else:
			close()
