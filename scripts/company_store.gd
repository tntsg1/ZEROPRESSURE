extends Control
# 126 号 公司仓库 (user 2026-11-04: "希望参考《三角洲》仓库那种物品清楚摆出来、分类和数量一目了然…不要让我先猜
# A 货架、B 货架、零件架、交易行分别藏了什么"; picked "新做三角洲式全屏仓库"). Everything the company holds
# on one page, in five kinds — materials (t), whole equipment (each piece), processed products (t),
# tools (each), clients' goods (not the company's) — as tiles: a picture, a name, how much. A tile
# opens on the right: where it really is (which rack row, the parts rack, the gear shelf), what it
# is for, what it is worth, and how to sell it, with the button that does it. Read from the same
# books as everything else (the exchange's company stock, Career.data.parts / gear / structure_t,
# the depot's lots): nothing is kept here.
# Opened with F3 from anywhere, from the terminal's foot, from a heat's result card.

const PartsRack = preload("res://scripts/parts_rack_panel.gd")
const Exchange = preload("res://scripts/industrial_exchange.gd")

const KINDS := ["all", "material", "equip", "product", "tool", "client"]
const PAD := 40.0
const HEAD_H := 112.0
const SIDE_W := 210.0
const DETAIL_W := 470.0
const TILE := Vector2(176, 188)
const GAP := 12.0
const WHEEL := 90.0

var game
var on_close: Callable
var kind := "all"
var sel := ""                        # the selected tile's id
var hover := ""
var hover_btn := ""
var scroll := 0.0
var items: Array = []                # {id, kind, name, qty (text), sub, pic, key?, part?, gear?, lot?, t?}
var message := ""
var _msg_t := 0.0
var _confirm := ""                   # a sale pressed once, waiting for the second press
var _confirm_t := 0.0
var _rects := {}
var _btns := {}
var _t := 0.0
var font: Font
var font_b: Font
var font_s: Font
var _sig := ""


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
	font_s = Fonts.get_font("SemiBold")
	build()
	grab_focus.call_deferred()


func select(id: String) -> void:
	sel = id
	_confirm = ""


func open_kind(k: String) -> void:
	kind = k
	scroll = 0.0
	var vis := shown()
	if not vis.is_empty() and (sel == "" or not vis.any(func(it): return it.id == sel)):
		sel = str(vis[0].id)


# ---------------------------------------------------------------- the books, read

func _stock() -> Dictionary:
	return Career.data.get("exchange", {}).get("actors", {}).get(Exchange.PLAYER, {}).get("stock", {})


static func kind_of_key(key: String) -> String:
	var u := Warehouse.use_of(key)
	if u in ["billet", "stock"]:
		return "product"
	return "material"


func build() -> void:
	items = []
	var st := _stock()
	var keys := st.keys()
	keys.sort()
	for k in keys:
		var t := float(st[k])
		if t <= 0.004:
			continue
		var key := str(k)
		items.append({"id": "m:" + key, "kind": kind_of_key(key), "name": Ops.item_name(key), "qty": "%.2f t" % t, "t": t, "key": key,
			"sub": w("货架 %s", "RACK %s") % Warehouse.ROWS[Warehouse.row_for(key)]})
	# the structural steel kept for the berth's and the port's repairs (not on the exchange)
	var plate := float(Career.data.get("structure_t", 0.0))
	if plate > 0.004:
		items.append({"id": "m:structure", "kind": "material", "name": w("船体钢板（修缮用）", "HULL PLATE (FOR REPAIRS)"), "qty": "%.1f t" % plate, "t": plate, "key": "structure", "sub": w("修缮料", "REPAIR STOCK")})
	for p in Career.data.get("parts", []):
		var nk := str(p.get("nk", ""))
		items.append({"id": "p:" + str(p.uid), "kind": "equip", "name": (Txt.t(nk) if nk != "" and Txt.has(nk) else str(p.get("tag", ""))), "qty": w("1 件", "1 PC"),
			"sub": "%s · %s %d%%" % [str(p.get("tag", "")), w("成色", "COND"), int(round(float(p.get("cond", 0.0)) * 100.0))], "part": p})
	var gear: Dictionary = Career.data.get("gear", {})
	for ty in Gear.DEPLOY:
		var n := int(gear.get(ty, 0))
		if n > 0:
			items.append({"id": "g:" + ty, "kind": "tool", "name": Gear.name_of(ty), "qty": w("%d 个", "%d") % n, "gear": ty, "n": n, "sub": w("装备架", "GEAR SHELF")})
	if Career.data.has("depot"):
		for l in Depot.data().get("lots", []):
			if str(l.get("state", "")) in ["dock", "in", "stored", "due"]:
				items.append({"id": "c:" + str(l.id), "kind": "client", "name": Ops.item_name(str(l.key)), "qty": "%.1f t" % float(l.t), "t": float(l.t), "key": str(l.key), "lot": l,
					"sub": str(l.client)})
	_sig = _signature()
	if sel != "" and not items.any(func(it): return it.id == sel):
		sel = ""
	if sel == "":
		var vis := shown()
		if not vis.is_empty():
			sel = str(vis[0].id)


func _signature() -> String:
	return "%s|%d|%s|%.3f|%s" % [str(_stock()), Career.data.get("parts", []).size(), str(Career.data.get("gear", {})), float(Career.data.get("structure_t", 0.0)), str(Career.data.get("depot", {}).get("lots", []).size())]


func shown() -> Array:
	return items.filter(func(it): return kind == "all" or str(it.kind) == kind)


func count(k: String) -> int:
	return items.filter(func(it): return k == "all" or str(it.kind) == k).size()


func _item(id: String) -> Dictionary:
	for it in items:
		if str(it.id) == id:
			return it
	return {}


func kind_name(k: String) -> String:
	return {"all": w("全部", "ALL"), "material": w("材料", "MATERIALS"), "equip": w("完整设备", "EQUIPMENT"), "product": w("加工成品", "PRODUCTS"),
		"tool": w("工具", "TOOLS"), "client": w("客户寄存", "CLIENTS' GOODS")}.get(k, k)


# ---------------------------------------------------------------- what a thing is, and how to sell it

func where_of(it: Dictionary) -> String:
	match str(it.kind):
		"material", "product":
			if str(it.key) == "structure":
				return w("船坞修缮用料（拆船时直接记下的结构钢，不占货架）", "THE BERTH'S REPAIR STOCK (HULL STEEL BOOKED AT SALVAGE)")
			var row := Warehouse.row_for(str(it.key))
			return w("货运区仓库 · %s 排（%s）", "CARGO WAREHOUSE · ROW %s (%s)") % [Warehouse.ROWS[row], Warehouse.use_name(str(Warehouse.rows()[row]))]
		"equip":
			return w("零件架 · 船坞终端下面", "PARTS RACK · UNDER THE BERTH TERMINAL") if Port.stage("cargo") < 1 else w("零件架 · 货运区左边货架", "PARTS RACK · CARGO DISTRICT, LEFT")
		"tool":
			return w("装备架（出勤配装时选带哪几件）", "THE GEAR SHELF (PICKED ON THE LOADOUT PAGE)")
		"client":
			return w("货运区仓库 · %s 排（客户货排）", "CARGO WAREHOUSE · ROW %s (CLIENTS' ROW)") % Warehouse.ROWS[int(it.lot.get("row", 0))]
	return ""


func use_of(it: Dictionary) -> String:
	match str(it.kind):
		"material":
			if str(it.key) == "structure":
				return w("修船坞设施和港区工程时按吨扣。不能卖。", "Taken by the tonne when berth facilities and port works are built. Not for sale.")
			match Warehouse.use_of(str(it.key)):
				"ingot":
					return w("电弧炉的炉料：在加工区炉台熔成钢坯（引导卡上的『送料到炉口』在哪都能按）。也能直接卖给工业客户。", "The arc furnace's feed: melted into billet at the processing district's desk. It also sells as it is.")
				"scrap":
					return w("没分选的废金属：先在分选台分开、化验位定级才能进炉；也能直接卖。", "Unsorted scrap: sorted and assayed before it can go into the furnace; it also sells as it is.")
				"nonferrous":
					return w("有色混合金属：不能进电弧炉，只能卖给工业客户。", "Non-ferrous mix: not for the arc furnace; it sells to industrial clients.")
			return w("可以在交易行卖。", "It sells on the exchange.")
		"product":
			if Warehouse.use_of(str(it.key)) == "billet":
				return w("钢坯：可以卖，也能在轧机轧成钢板或型材。轧机开着“连续轧”时，钢坯一入库就会被轧掉。", "Billet: it sells, or the mill rolls it into plate or sections (with 'rolling on', billet is rolled as soon as it comes in).")
			return w("钢板 / 型材：修船坞和港区工程要用的结构料，也能卖给工业客户。", "Plate / sections: structural stock for the berth's and the port's works; it also sells.")
		"equip":
			var p: Dictionary = it.part
			var t := w("拆下来的完整设备：可以按设备价直接卖；也能留着修船坞和港区（修缮要用对应类别的零件）。", "Whole equipment off a ship: sells at the equipment price, or is kept for the berth's and the port's repairs.")
			if float(p.get("cond", 0.0)) < Repair.COND_MIN:
				t += w(" 这件成色太低，修缮用不上，只能卖。", " Too worn for repairs: sell it.")
			return t + "\n" + w("来自 %s · %s", "FROM %s · %s") % [Methods.ship_label(str(p.get("ship", ""))), str(p.get("job", ""))]
		"tool":
			return Txt.t("gear_" + str(it.gear) + "_d")
		"client":
			return w("%s 寄存在你仓库里的货，不是你的：不能卖、不能进炉。按期收租，客户提走时收装卸费。", "%s's goods stored with you, not yours: not for sale or the furnace. Rent by the period, handling when they leave.") % str(it.lot.get("client", ""))
	return ""


func worth_of(it: Dictionary) -> float:
	match str(it.kind):
		"material", "product":
			if str(it.key) == "structure":
				return -1.0
			return Exchange.ref_price(str(it.key)) * float(it.t)
		"equip":
			return Repair.part_worth(it.part)
		"tool":
			return Gear.price(str(it.gear)) * int(it.n)
	return -1.0


# the sale button's words ("" = nothing to sell here) and whether it is a straight sale
func sale_of(it: Dictionary) -> String:
	match str(it.kind):
		"material", "product":
			if str(it.key) == "structure":
				return ""
			if Port.stage("trade") < 1:
				return w("贸易区修好后才能卖", "SELLS ONCE THE TRADE DISTRICT IS MENDED")
			return w("去交易行挂牌卖  [Enter]", "LIST IT ON THE EXCHANGE  [Enter]")
		"equip":
			if it.part.has("listed"):
				return w("挂牌中", "LISTED")
			if _confirm == str(it.id):
				return w("再按一次确认：卖 %s", "PRESS AGAIN TO SELL FOR %s") % Pal.money(Repair.part_worth(it.part))
			return w("出售 %s  [Enter]", "SELL %s  [Enter]") % Pal.money(Repair.part_worth(it.part))
	return ""


func sell_sel() -> void:
	var it := _item(sel)
	if it.is_empty():
		return
	match str(it.kind):
		"material", "product":
			if str(it.key) == "structure":
				return
			if Port.stage("trade") < 1:
				_say(w("贸易区还没修好，交易行不能挂牌", "THE TRADE DISTRICT IS NOT MENDED YET"), true)
				return
			var key := str(it.key)
			_close()
			if game != null and is_instance_valid(game):
				game.open_exchange()
				var ui = game.console_ui
				if ui != null and ui.has_method("open_sell"):
					ui.open_sell.call_deferred(key.split(":")[0], int(key.split(":")[1]) if key.contains(":") else 0)
		"equip":
			if it.part.has("listed"):
				return
			if _confirm != str(it.id):
				_confirm = str(it.id)
				_confirm_t = 3.0
				return
			var price := Repair.part_worth(it.part)
			var why := Repair.sell(str(it.part.uid))
			_confirm = ""
			if why != "":
				_say(why, true)
				return
			_say(w("卖了 %s · +%s", "SOLD %s · +%s") % [str(it.name), Pal.money(price)])
			if game != null and game.get("sfx") != null:
				game.sfx.play("stamp")
			build()


func _say(s: String, bad := false) -> void:
	message = s
	_msg_t = 3.5
	if bad and game != null and is_instance_valid(game) and game.get("sfx") != null:
		game.sfx.play("deny")


func _close() -> void:
	if on_close.is_valid():
		on_close.call()


# ---------------------------------------------------------------- layout

func _side_rect() -> Rect2:
	return Rect2(PAD, HEAD_H + 16.0, SIDE_W, size.y - HEAD_H - 16.0 - 70.0)


func _grid_rect() -> Rect2:
	var x := PAD + SIDE_W + 24.0
	return Rect2(x, HEAD_H + 16.0, size.x - x - DETAIL_W - PAD - 24.0, size.y - HEAD_H - 16.0 - 70.0)


func _detail_rect() -> Rect2:
	return Rect2(size.x - PAD - DETAIL_W, HEAD_H + 16.0, DETAIL_W, size.y - HEAD_H - 16.0 - 70.0)


func _cols() -> int:
	return maxi(1, int((_grid_rect().size.x + GAP) / (TILE.x + GAP)))


func _scroll_max() -> float:
	var n := shown().size()
	var rows := int(ceil(float(n) / _cols()))
	return maxf(0.0, rows * (TILE.y + GAP) - GAP - _grid_rect().size.y)


func _layout() -> void:
	_rects = {}
	_btns = {}
	var gr := _grid_rect()
	var c := _cols()
	var vis := shown()
	for i in vis.size():
		var r := Rect2(gr.position + Vector2((i % c) * (TILE.x + GAP), (i / c) * (TILE.y + GAP) - scroll), TILE)
		_rects[vis[i].id] = r
	var sr := _side_rect()
	for i in KINDS.size():
		_btns["kind:" + KINDS[i]] = Rect2(sr.position + Vector2(0, i * 62.0), Vector2(sr.size.x, 54.0))
	var dr := _detail_rect()
	_btns["sell"] = Rect2(dr.position.x + 20.0, dr.end.y - 74.0, dr.size.x - 40.0, 54.0)
	_btns["close"] = Rect2(size.x - PAD - 150.0, 40.0, 150.0, 44.0)


# ---------------------------------------------------------------- input

func _process(dt: float) -> void:
	_t += dt
	_msg_t = maxf(0.0, _msg_t - dt)
	if _confirm != "":
		_confirm_t -= dt
		if _confirm_t <= 0.0:
			_confirm = ""
	if _signature() != _sig:
		build()
	scroll = clampf(scroll, 0.0, _scroll_max())
	_layout()
	var m := get_local_mouse_position()
	hover = ""
	hover_btn = ""
	if _grid_rect().has_point(m):
		for id in _rects:
			if (_rects[id] as Rect2).has_point(m):
				hover = str(id)
	for b in _btns:
		if (_btns[b] as Rect2).has_point(m):
			hover_btn = str(b)
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll = clampf(scroll + WHEEL, 0.0, _scroll_max())
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll = clampf(scroll - WHEEL, 0.0, _scroll_max())
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			_layout()
			for b in _btns:
				if (_btns[b] as Rect2).has_point(ev.position):
					_press(str(b))
					accept_event()
					return
			if _grid_rect().has_point(ev.position):
				for id in _rects:
					if (_rects[id] as Rect2).has_point(ev.position):
						select(str(id))
		accept_event()


func _press(b: String) -> void:
	if b.begins_with("kind:"):
		open_kind(b.substr(5))
	elif b == "sell":
		sell_sel()
	elif b == "close":
		_close()


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	var vis := shown()
	var i := -1
	for k in vis.size():
		if str(vis[k].id) == sel:
			i = k
	match ev.physical_keycode:
		KEY_ESCAPE, KEY_F3:
			_close()
		KEY_ENTER, KEY_KP_ENTER:
			sell_sel()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			open_kind(KINDS[ev.physical_keycode - KEY_1])
		KEY_TAB:
			open_kind(KINDS[(KINDS.find(kind) + 1) % KINDS.size()])
		KEY_RIGHT, KEY_D:
			if not vis.is_empty(): select(str(vis[mini(i + 1, vis.size() - 1)].id))
		KEY_LEFT, KEY_A:
			if not vis.is_empty(): select(str(vis[maxi(i - 1, 0)].id))
		KEY_DOWN, KEY_S:
			if not vis.is_empty(): select(str(vis[mini(i + _cols(), vis.size() - 1)].id))
		KEY_UP, KEY_W:
			if not vis.is_empty(): select(str(vis[maxi(i - _cols(), 0)].id))
		_:
			return
	_keep_in_view()
	get_viewport().set_input_as_handled()


func _keep_in_view() -> void:
	_layout()
	if not _rects.has(sel):
		return
	var r: Rect2 = _rects[sel]
	var gr := _grid_rect()
	if r.position.y < gr.position.y:
		scroll -= gr.position.y - r.position.y
	elif r.end.y > gr.end.y:
		scroll += r.end.y - gr.end.y
	scroll = clampf(scroll, 0.0, _scroll_max())


# ---------------------------------------------------------------- drawing

func _text(s: String, p: Vector2, px: int, col: Color, f: Font = null, wmax := -1.0, al := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(f if f != null else font, p, s, al, wmax, px, col)


func _draw() -> void:
	_layout()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.04, 0.048))
	_draw_head()
	_draw_side()
	_draw_grid()
	_draw_detail()
	_draw_foot()


func _draw_head() -> void:
	draw_rect(Rect2(PAD, 40, 4, 34), UiSkin.ACCENT)
	_text(w("公司仓库", "COMPANY STORES"), Vector2(PAD + 16, 70), 32, Pal.ink(0.97), font_s)
	_text(w("你的全部东西都在这一页：材料、完整设备、加工成品、工具，还有客户寄存的货。点一样看它在哪、干什么用、怎么卖。", "Everything the company holds, on one page. Click a thing: where it is, what it is for, how to sell it."), Vector2(PAD + 16, 98), 15, Pal.ink(0.55), font_b)
	# the totals, right
	var mat_t := 0.0
	var prod_t := 0.0
	for it in items:
		if str(it.kind) == "material" and str(it.key) != "structure":
			mat_t += float(it.t)
		elif str(it.kind) == "product":
			prod_t += float(it.t)
	var stats := [[w("资金", "CASH"), Pal.money(float(Career.data.get("money", 0.0)))], [w("材料", "MATERIALS"), "%.1f t" % mat_t],
		[w("设备", "EQUIPMENT"), w("%d 件", "%d") % count("equip")], [w("成品", "PRODUCTS"), "%.1f t" % prod_t]]
	var x := size.x - PAD - 180.0
	for i in range(stats.size() - 1, -1, -1):
		x -= 150.0
		_text(str(stats[i][0]), Vector2(x, 58), 13, Pal.ink(0.5), font_b, 140.0, HORIZONTAL_ALIGNMENT_RIGHT)
		_text(str(stats[i][1]), Vector2(x, 86), 22, Pal.ink(0.95), font_s, 140.0, HORIZONTAL_ALIGNMENT_RIGHT)
	var cr: Rect2 = _btns.get("close", Rect2())
	var hc := hover_btn == "close"
	draw_rect(cr, Color(1, 1, 1, 0.08 if hc else 0.035))
	draw_rect(cr, Pal.ink(0.5 if hc else 0.25), false, 1.0)
	_text(w("关闭  [Esc]", "CLOSE  [Esc]"), cr.position + Vector2(0, 29), 15, Pal.ink(0.9), font_b, cr.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	draw_line(Vector2(PAD, HEAD_H), Vector2(size.x - PAD, HEAD_H), Pal.ink(0.12), 1.0)


func _draw_side() -> void:
	for i in KINDS.size():
		var k: String = KINDS[i]
		var r: Rect2 = _btns["kind:" + k]
		var on := kind == k
		var hov := hover_btn == "kind:" + k
		draw_rect(r, Color(1, 1, 1, 0.06 if on else (0.03 if hov else 0.012)))
		if on:
			draw_rect(Rect2(r.position, Vector2(3, r.size.y)), UiSkin.ACCENT)
		_text("%d" % (i + 1), r.position + Vector2(14, 33), 12, Pal.ink(0.35), font_b)
		_text(kind_name(k), r.position + Vector2(34, 34), 17, Pal.ink(0.95 if on else 0.65), font_s if on else font_b)
		var n := count(k)
		_text("%d" % n, r.position + Vector2(0, 34), 16, Pal.ink(0.85 if n > 0 else 0.3), font_s, r.size.x - 14.0, HORIZONTAL_ALIGNMENT_RIGHT)
	var sr := _side_rect()
	_text(w("1–6 分类 · Tab 下一类", "1–6 KINDS · TAB NEXT"), Vector2(sr.position.x, sr.position.y + KINDS.size() * 62.0 + 20.0), 12, Pal.ink(0.35), font_b)


func _draw_grid() -> void:
	var gr := _grid_rect()
	var vis := shown()
	if vis.is_empty():
		_text(w("这一类现在什么都没有", "NOTHING OF THIS KIND NOW"), gr.position + Vector2(0, 40), 17, Pal.ink(0.4), font_b)
		if kind == "equip":
			_text(w("结算时把设备拖进“我的仓库”就会放到这里。", "Equipment kept at settlement comes here."), gr.position + Vector2(0, 70), 14, Pal.ink(0.35), font_b)
		return
	for it in vis:
		var r: Rect2 = _rects.get(it.id, Rect2())
		if r.end.y < gr.position.y - 4.0 or r.position.y > gr.end.y + 4.0:
			continue
		_tile(it, r)
	# the cut edges: tiles going out of the view under a fade, and a scroll mark
	draw_rect(Rect2(gr.position.x - 4.0, gr.position.y - 14.0, gr.size.x + 8.0, 14.0), Color(0.035, 0.04, 0.048))
	draw_rect(Rect2(gr.position.x - 4.0, gr.end.y, gr.size.x + 8.0, 70.0), Color(0.035, 0.04, 0.048))
	if _scroll_max() > 0.0:
		var tr := Rect2(gr.end.x + 8.0, gr.position.y, 4.0, gr.size.y)
		draw_rect(tr, Pal.ink(0.08))
		var k := gr.size.y / (gr.size.y + _scroll_max())
		draw_rect(Rect2(tr.position.x, tr.position.y + (tr.size.y - tr.size.y * k) * scroll / _scroll_max(), 4.0, tr.size.y * k), Pal.ink(0.4))


func _tile(it: Dictionary, r: Rect2) -> void:
	var on := str(it.id) == sel
	var hov := str(it.id) == hover
	var client := str(it.kind) == "client"
	draw_rect(Rect2(r.position + Vector2(3, r.size.y - 2), Vector2(r.size.x - 3, 5)), Color(0, 0, 0, 0.45))
	draw_rect(r, Color(0.075, 0.08, 0.09) if not hov else Color(0.095, 0.1, 0.112))
	var edge := Pal.ink(0.2)
	if on:
		edge = Color(UiSkin.ACCENT, 0.95)
	elif client:
		edge = Color(0.55, 0.6, 0.7, 0.35)
	draw_rect(r, edge, false, 1.6 if on else 1.0)
	var pic := Rect2(r.position + Vector2(10, 10), Vector2(r.size.x - 20, 82))
	draw_rect(pic, Color(0, 0, 0, 0.35))
	_pic(it, pic)
	_text(str(it.name), r.position + Vector2(10, 114), 14, Pal.ink(0.95), font_s, r.size.x - 20.0)
	_text(str(it.qty), r.position + Vector2(10, 142), 20, Pal.ink(0.95), font_s, r.size.x - 20.0)
	_text(str(it.sub), r.position + Vector2(10, 166), 12, Pal.ink(0.5), font_b, r.size.x - 20.0)
	if str(it.kind) == "equip":
		var cond := clampf(float(it.part.get("cond", 0.0)), 0.0, 1.0)
		var cb := Rect2(r.position + Vector2(10, r.size.y - 12), Vector2(r.size.x - 20, 3))
		draw_rect(cb, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(cb.position, Vector2(cb.size.x * cond, 3)), Color(UiSkin.DATA) if cond >= Repair.COND_MIN else Pal.heat(0.9, 1.1))
	if client:
		_text(w("客户的", "A CLIENT'S"), r.position + Vector2(0, 26), 11, Pal.ink(0.55), font_b, r.size.x - 14.0, HORIZONTAL_ALIGNMENT_RIGHT)


func _pic(it: Dictionary, pic: Rect2) -> void:
	match str(it.kind):
		"material", "product", "client":
			if str(it.key) == "structure":
				for k in 4:
					var y := pic.get_center().y - 18.0 + k * 10.0
					draw_rect(Rect2(pic.get_center().x - 46.0 + k * 3.0, y, 92.0, 7.0), Color(0.3, 0.32, 0.35))
					draw_rect(Rect2(pic.get_center().x - 46.0 + k * 3.0, y, 92.0, 7.0), Pal.ink(0.5), false, 1.0)
				return
			var key := str(it.key)
			GoodsArt.draw(self, pic.grow(-6.0), key.split(":")[0], int(key.split(":")[1]) if key.contains(":") else 0)
		"equip":
			var cls := str(it.part.get("cls", ""))
			PartsRack._glyph(self, cls, pic.get_center(), 24.0, PartsRack._class_col(cls))
		"tool":
			_gear(str(it.gear), pic.get_center(), 22.0, Pal.ink(0.85))


func _gear(ty: String, c: Vector2, s: float, col: Color) -> void:
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
		"prop":
			draw_line(c + Vector2(0, -s), c + Vector2(0, s * 0.7), col, 2.2, true)
			draw_line(c + Vector2(-s * 0.7, s * 0.8), c + Vector2(s * 0.7, s * 0.8), col, 1.8, true)
			draw_line(c + Vector2(-s * 0.4, -s), c + Vector2(s * 0.4, -s), col, 1.8, true)
		_:
			draw_rect(Rect2(c - Vector2(s, s) * 0.6, Vector2(s, s) * 1.2), col, false, 1.4)


func _draw_detail() -> void:
	var dr := _detail_rect()
	draw_rect(dr, Color(1, 1, 1, 0.02))
	draw_rect(dr, Pal.ink(0.14), false, 1.0)
	var it := _item(sel)
	if it.is_empty():
		_text(w("点左边一样东西看详情", "CLICK A THING FOR ITS DETAILS"), dr.position + Vector2(20, 50), 16, Pal.ink(0.4), font_b)
		return
	var pic := Rect2(dr.position + Vector2(20, 20), Vector2(dr.size.x - 40, 150))
	draw_rect(pic, Color(0, 0, 0, 0.35))
	_pic(it, pic)
	var y := pic.end.y + 40.0
	_text(str(it.name), Vector2(dr.position.x + 20, y), 22, Pal.ink(0.97), font_s, dr.size.x - 40.0)
	y += 34.0
	_text(str(it.qty), Vector2(dr.position.x + 20, y), 26, Pal.ink(0.97), font_s)
	var worth := worth_of(it)
	if worth >= 0.0:
		_text(w("约值 %s", "WORTH ABOUT %s") % Pal.money(worth), Vector2(dr.position.x + 20, y), 16, Pal.ink(0.75), font_b, dr.size.x - 40.0, HORIZONTAL_ALIGNMENT_RIGHT)
	y += 26.0
	_text(kind_name(str(it.kind)) + ("  ·  " + str(it.sub) if str(it.sub) != "" else ""), Vector2(dr.position.x + 20, y), 13, Pal.ink(0.5), font_b, dr.size.x - 40.0)
	y += 34.0
	_text(w("在哪", "WHERE"), Vector2(dr.position.x + 20, y), 13, Pal.ink(0.45), font_b)
	y += 6.0
	y = _para(where_of(it), dr.position.x + 20, y + 16.0, dr.size.x - 40.0, Pal.ink(0.85)) + 18.0
	_text(w("用途", "USE"), Vector2(dr.position.x + 20, y), 13, Pal.ink(0.45), font_b)
	y = _para(use_of(it), dr.position.x + 20, y + 22.0, dr.size.x - 40.0, Pal.ink(0.8))
	var label := sale_of(it)
	var sb: Rect2 = _btns["sell"]
	if label != "":
		var can: bool = not (str(it.kind) in ["material", "product"] and Port.stage("trade") < 1) and not (str(it.kind) == "equip" and it.part.has("listed"))
		var hov: bool = hover_btn == "sell" and can
		var arm := _confirm == str(it.id)
		draw_rect(sb, Color(UiSkin.ACCENT, (0.35 if arm else (0.24 if hov else 0.14))) if can else Color(1, 1, 1, 0.03))
		draw_rect(sb, Color(UiSkin.ACCENT, 0.95 if can else 0.25), false, 1.2)
		_text(label, sb.position + Vector2(0, 34), 17, Pal.ink(0.97 if can else 0.45), font_s, sb.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	elif str(it.kind) == "client":
		_text(w("客户的货：不能卖", "A CLIENT'S GOODS: NOT FOR SALE"), sb.position + Vector2(0, 34), 15, Pal.ink(0.45), font_b, sb.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	elif str(it.kind) == "tool":
		_text(w("开工时在出勤配装里选带上", "PICKED ON THE LOADOUT PAGE AT THE START"), sb.position + Vector2(0, 34), 15, Pal.ink(0.5), font_b, sb.size.x, HORIZONTAL_ALIGNMENT_CENTER)


# a wrapped paragraph; returns the y under it
func _para(s: String, x: float, y: float, wd: float, col: Color) -> float:
	var lines: PackedStringArray = []
	for part in s.split("\n"):
		var cur := ""
		for ch in part:
			if font_b.get_string_size(cur + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x > wd:
				lines.append(cur)
				cur = ""
			cur += ch
		lines.append(cur)
	for l in lines:
		_text(l, Vector2(x, y), 14, col, font_b)
		y += 21.0
	return y


func _draw_foot() -> void:
	var y := size.y - 34.0
	var line := message if _msg_t > 0.0 else w("Esc / F3 关闭 · 1–6 分类 · 方向键选择 · Enter 出售或去交易行 · 滚轮翻页", "Esc / F3 CLOSE · 1–6 KINDS · ARROWS PICK · ENTER SELL · WHEEL SCROLLS")
	_text(line, Vector2(PAD, y), 15, Pal.ink(0.85) if _msg_t > 0.0 else Pal.ink(0.4), font_b)
