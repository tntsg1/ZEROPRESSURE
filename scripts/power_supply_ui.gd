extends VBoxContainer
# 128 号 第 5 段 动力 —— 草图: on the power screen, in place of the old "接入外购电" switch —
#   买电池块: three cards like goods at a market (capacity, the most it gives, price, time to the port),
#             a key on each that orders at once (no confirm; 人性化 规则 2) and says what it did; the berth's
#             two slots and the ships on their way; "快用完时自动再订一块".
#   发电机:   each set's output against its rating, its overload switch, its heat bar; tripped, why and
#             what to do (the wrench at the set).

const PS = preload("res://scripts/power_supply.gd")

var panel                 # scripts/power_panel.gd (its msg line for the done notes)
var order_keys := {}
var berth_l: Label
var auto_key: CheckButton
var gen_rows := {}        # id → [label, over key, heat bar Control, state label]
var _quiet := false
var cryo_l: Label


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _lab(s: String, px: int, ink: float, semi := false, wrap := false) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", Pal.ink(ink))
	if semi:
		l.add_theme_font_override("font", Fonts.get_font("SemiBold"))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


class HeatBar extends Control:
	var id := ""
	func _init() -> void:
		custom_minimum_size = Vector2(220, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(_dt: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var g: Dictionary = PS.d().get("gens", {}).get(id, {})
		var h := float(g.get("heat", 0.0))
		var r := Rect2(Vector2(0, 4), Vector2(size.x, 8))
		draw_rect(r, Color(1, 1, 1, 0.07))
		var col: Color = Hmi.ok_col().lerp(UiSkin.ACCENT, clampf((h - 0.4) / 0.4, 0.0, 1.0))
		if g.get("trip", false):
			col = Color(1, 0.3, 0.25, 0.6 + 0.4 * absf(sin(PS.t * 4.0)))
		draw_rect(Rect2(r.position, Vector2(r.size.x * h, r.size.y)), col)
		draw_line(Vector2(size.x - 1, 0), Vector2(size.x - 1, 16), Color(1, 0.3, 0.25), 2.0)


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	add_child(row)
	# ---- the battery order card
	var shop := PanelContainer.new()
	shop.add_theme_stylebox_override("panel", UiSkin.glass(0.03, 0.07, 14, 18.0))
	shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop.size_flags_stretch_ratio = 1.5
	row.add_child(shop)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 10)
	shop.add_child(sv)
	var head := HBoxContainer.new()
	sv.add_child(head)
	var ht := _lab(w("买电池块", "BUY A BATTERY BLOCK"), 18, 0.97, true)
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(ht)
	head.add_child(_lab(w("外星系送货飞船送到电池泊位，吊装后接进全港总线", "A ship brings it from another system to the battery berth"), 13, 0.5))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 10)
	sv.add_child(cards)
	for s in PS.ORDER:
		var z: Dictionary = PS.SIZES[s]
		var c := PanelContainer.new()
		c.add_theme_stylebox_override("panel", UiSkin.solid(Color(0, 0, 0, 0.25), 10, 12.0))
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards.add_child(c)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		c.add_child(v)
		var top := HBoxContainer.new()
		v.add_child(top)
		var nm := _lab(w("%s电池", "%s BLOCK") % PS.size_name(s), 17, 0.95, true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(nm)
		var pr := _lab("$" + PS._money(float(z.price)), 17, 0.95, true)
		pr.add_theme_color_override("font_color", UiSkin.ACCENT)
		top.add_child(pr)
		v.add_child(_BlockPic.make(s))
		v.add_child(_lab(w("容量 %.1f 兆瓦时 · 最多 %.0f 兆瓦", "%.1f MWh · UP TO %.0f MW") % [float(z.mwh), float(z.mw)], 14, 0.75))
		v.add_child(_lab(w("满功率能撑 %d 分钟 · 约 %d 秒到港", "%d min AT FULL · IN ABOUT %d s") % [int(round(float(z.mwh) / float(z.mw) * 60.0)), int(z.eta)], 13, 0.55))
		var b := Button.new()
		b.text = w("下单", "ORDER")
		b.custom_minimum_size = Vector2(0, 40)
		var size_key: String = s
		b.pressed.connect(func(): _order(size_key))
		BenchFx.note(b, w("立刻下单（不用确认）：扣 $%s，送货飞船约 %d 秒后到电池泊位", "Orders at once: $%s, the ship is at the berth in about %d s") % [PS._money(float(z.price)), int(z.eta)])
		v.add_child(b)
		order_keys[s] = b
	berth_l = _lab("", 14, 0.75, false, true)
	sv.add_child(berth_l)
	auto_key = CheckButton.new()
	auto_key.text = w("快用完时自动再订一块（按上次订的大小）", "ORDER ANOTHER WHEN LOW (THE LAST SIZE)")
	auto_key.toggled.connect(func(on_: bool):
		if _quiet:
			return
		PS.set_auto(on_)
		_say(w("已打开：电池剩不到 %d%% 时自动再订一块%s" % [int(PS.LOW_AT * 100), PS.size_name(str(PS.d().auto_size))], "ON: ANOTHER IS ORDERED BELOW %d%%" % int(PS.LOW_AT * 100)) if on_ else w("已关闭自动再订", "AUTO ORDER OFF")))
	BenchFx.note(auto_key, w("打开后，电池总量剩不到四分之一时，自动按上次的大小再订一块", "When on, another block of the last size is ordered below a quarter left"))
	sv.add_child(auto_key)
	# ---- the sets
	var sets := PanelContainer.new()
	sets.add_theme_stylebox_override("panel", UiSkin.glass(0.03, 0.07, 14, 18.0))
	sets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sets)
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 10)
	sets.add_child(gv)
	gv.add_child(_lab(w("发电机", "GENERATORS"), 18, 0.97, true))
	gv.add_child(_lab(w("超载多发 %d%%，但会发热；热量满了强制停机，要飞过去用维护工具修一下才能重启。" % int(PS.OVER_K * 100), "Overload gives %d%% more but heats; full, it trips until the wrench mends it." % int(PS.OVER_K * 100)), 13, 0.55, false, true))
	for id in ["tg", "fc"]:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		gv.add_child(box)
		var line := HBoxContainer.new()
		box.add_child(line)
		var nl := _lab("", 15, 0.92, true)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(nl)
		var ok := CheckButton.new()
		ok.text = w("超载", "OVERLOAD")
		var gid: String = id
		ok.toggled.connect(func(on_: bool):
			if _quiet:
				return
			var r := PS.set_over(gid, on_)
			_say(str(r.get("note", r.get("reason", ""))))
			sync())
		BenchFx.note(ok, w("超载：多发 %d%% 的电，热量条会涨，满了强制停机" % int(PS.OVER_K * 100), "Overload: %d%% more, heat rises; full, it trips" % int(PS.OVER_K * 100)))
		line.add_child(ok)
		var hb := HeatBar.new()
		hb.id = id
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(hb)
		var stl := _lab("", 13, 0.6, false, true)
		box.add_child(stl)
		gen_rows[id] = [nl, ok, hb, stl, box]
	# the fuel cells' fuel: what the next tug run can bring, from the real stock
	cryo_l = _lab("", 13, 0.6, false, true)
	cryo_l.add_theme_color_override("font_color", Pal.tint(Pal.FLUID, 0.85, 1.2))
	gv.add_child(cryo_l)
	sync()


func _order(s: String) -> void:
	var r := PS.order(s)
	_say(str(r.get("note", r.get("reason", ""))))
	sync()


func _say(text: String) -> void:
	if panel != null and panel.get("msg") != null:
		BenchFx.say(panel.msg, text)


func _process(_dt: float) -> void:
	if Engine.get_process_frames() % 10 == 0:
		sync()


func sync() -> void:
	_quiet = true
	var p := PS.d()
	var parts: Array = []
	for i in PS.SLOTS:
		var sl: Dictionary = p.slots[i]
		if sl.is_empty():
			parts.append(w("泊位 %s：空", "SLOT %s: EMPTY") % "AB"[i])
		elif float(sl.left) <= 0.0001:
			parts.append(w("泊位 %s：空壳待运走", "SLOT %s: SPENT SHELL") % "AB"[i])
		else:
			parts.append(w("泊位 %s：%s %.1f / %.1f 兆瓦时", "SLOT %s: %s %.1f / %.1f MWh") % ["AB"[i], PS.size_name(str(sl.size)), float(sl.left), float(PS.SIZES[str(sl.size)].mwh)])
	for o in p.orders:
		if str(o.size) == "":
			parts.append(w("空壳回收船 %d 秒后到", "PICKUP IN %d s") % int(ceil(float(o.t))))
		elif str(o.phase) == "transit":
			parts.append(w("%s电池在路上 · %d 秒后到港", "%s BLOCK ON ITS WAY · %d s") % [PS.size_name(str(o.size)), int(ceil(float(o.t)))])
		else:
			parts.append(w("%s电池正在吊装", "%s BLOCK BEING LOWERED") % PS.size_name(str(o.size)))
	berth_l.text = "  ·  ".join(parts)
	for s in order_keys:
		var c := PS.can_order(s)
		order_keys[s].disabled = not c.ok
		order_keys[s].tooltip_text = "" if c.ok else str(c.reason)
	auto_key.set_pressed_no_signal(bool(p.get("auto", false)))
	for id in gen_rows:
		var row: Array = gen_rows[id]
		var shown: bool = id in PS.gen_list()
		row[4].visible = shown
		if not shown:
			continue
		var g: Dictionary = p.gens[id]
		var out := float(g.get("out", 0.0))
		row[0].text = w("%s  %.1f / %.1f 兆瓦", "%s  %.1f / %.1f MW") % [PS.gen_name(id), out, PS.gen_cap(id)] + (w("（含第二组电堆 +%.0f）", " (+%.0f STACK 2)") % PS.fc2_mw() if id == "fc" and PS.fc2_mw() > 0.0 else "")
		row[1].set_pressed_no_signal(bool(g.get("over", false)))
		row[1].disabled = bool(g.get("trip", false))
		if g.get("trip", false):
			row[3].text = w("过热停机 · 待修：飞到%s旁，用维护工具（4）按住修一下", "TRIPPED · FLY TO IT AND HOLD THE WRENCH (4) ON IT") % PS.gen_name(id)
			row[3].add_theme_color_override("font_color", Color(1, 0.42, 0.35))
		else:
			row[3].text = w("热量 %d%%", "HEAT %d%%") % int(float(g.get("heat", 0.0)) * 100.0) + (w(" · 超载中，热量在涨", " · OVERLOADED, HEATING") if g.get("over", false) and float(g.get("heat", 0.0)) > 0.0 else "")
			row[3].add_theme_color_override("font_color", Pal.ink(0.6))
	cryo_l.text = w("燃料电池第二组电堆：储罐 %.1f / %.0f 兆瓦时 · ", "FUEL CELLS' STACK 2: TANK %.1f / %.0f MWh · ") % [float(p.get("fc_fuel", 0.0)), PS.FC_TANK] + PS.cryo_status()
	_quiet = false


# a small drawing of the block on its card (its height by size)
class _BlockPic extends Control:
	var s := "m"
	static func make(sz: String) -> Control:
		var c := _BlockPic.new()
		c.s = sz
		c.custom_minimum_size = Vector2(0, 62)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return c
	func _draw() -> void:
		var h: float = float(PS.SIZES[s].h) / 2.9 * 54.0
		var wpx := 34.0
		var r := Rect2(Vector2(8, 58 - h), Vector2(wpx, h))
		draw_rect(r, Color(0.075, 0.08, 0.09))
		draw_rect(r, Pal.ink(0.85), false, 1.5)
		var rows := int(round(float(PS.SIZES[s].h) / 0.55))
		for j in rows:
			var y := r.position.y + (j + 0.5) * r.size.y / rows
			draw_line(Vector2(r.position.x + 3, y), Vector2(r.end.x - 3, y), Pal.ink(0.25), 1.0)
		draw_rect(Rect2(r.end.x - 6, r.position.y + 4, 2, r.size.y - 8), Pal.tint(Pal.VOLT, 0.9, 1.3))
		draw_rect(Rect2(r.position.x + 11, r.position.y - 4, 12, 4), Pal.ink(0.7))
		draw_string(Fonts.get_font("Regular"), Vector2(56, 40), "%.1f MWh" % float(PS.SIZES[s].mwh), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.7))
