extends Control
# 106 号: the settlement's second page — where the recovered goods go (scripts/disposal.gd is the
# authority). The ingots as one batch: sold now, or kept to be processed; each piece of equipment:
# sold now, or kept on the rack. Starts on the defaults (the last metal choice; the parts the
# repairs would use kept, the rest sold); every choice shows what it brings. Enter confirms and
# leaves the berth; Esc goes back to the settlement sheet with nothing changed. 1 / 2: the metal.

var game
var on_done: Callable          # called after a confirmed save
var on_back: Callable
var metal := "keep"
var sell := {}                 # uid -> true when sold
var d: Dictionary
var want: Dictionary
var sell_b: Button
var keep_b: Button
var part_rows := {}            # uid -> [sell button, keep button]
var total: Label
var message: Label


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	d = Disposal.pending()
	want = Disposal.wanted()
	metal = Disposal.metal_default()
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var accent := Pal.tint(Pal.AIR, 1.0, 1.2)
	var column := OpsSkin.pane(self, accent, 760.0)
	column.add_child(OpsSkin.Plate.new("GOODS", w("回收物去向", "WHERE THE GOODS GO"), Methods.ship_label(str(d.get("ship", ""))), accent))
	var box := column
	var t := float(d.get("ingot_t", 0.0))
	if t > 0.0005:
		# 108 号 Q4/Q11: one line each on the page; the why is on the buttons' hover cards
		box.add_child(OpsSkin.label(w("钢锭  %.1f t", "INGOTS  %.1f t") % t, 17))
		var kv: Dictionary = Disposal.keep_value(d)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		sell_b = _choice(w("[1] 直卖  +%s 现在到账", "[1] SELL  +%s NOW") % Pal.money(Disposal.sell_cash(d)))
		sell_b.pressed.connect(_metal.bind("sell"))
		sell_b.tooltip_text = w("熔炉铸的钢锭整批直接卖掉，钱现在到账。", "The furnace's ingots sold as one batch: the money now.")
		row.add_child(sell_b)
		keep_b = _choice(w("[2] 留着加工  钢坯约 %s", "[2] PROCESS  BILLET ABOUT %s") % Pal.money(float(kv.value)))
		keep_b.pressed.connect(_metal.bind("keep"))
		row.add_child(keep_b)
		keep_b.tooltip_text = w("留着加工：运到加工区，电弧炉炼成约 %.1f t 钢坯（电费约 %s），再轧成钢板——钢板可抵修缮用的船体结构，钢坯和钢板也能在交易行卖。",
			"Processing: carried to the processing district, melted into about %.1f t of billet (power about %s), then rolled into plate — plate counts as hull structure for repairs; both sell on the exchange.") % [float(kv.billet_t), Pal.money(float(kv.power))]
		var note := w("留着加工：炼成钢坯、轧成钢板，修船坞或卖。", "Processing: billet, then plate — for repairs or to sell.")
		if Port.stage("process") < 1:
			note = w("加工区还没修好：钢锭先放仓库，修好后自动加工。", "The processing district is not mended: the ingots wait in the warehouse.")
		box.add_child(OpsSkin.label(note, 14, 0.6))
	var parts := Disposal.parts()
	if not parts.is_empty():
		box.add_child(OpsSkin.label(w("完好设备  %d 件", "WHOLE EQUIPMENT  %d") % parts.size(), 17))
		for part in parts:
			var uid := str(part.uid)
			sell[uid] = Disposal.part_default(part, want) == "sell"
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			box.add_child(row)
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(col)
			var nm: String = Txt.t(str(part.nk)) if Txt.has(str(part.nk)) else str(part.tag)
			col.add_child(OpsSkin.label("%s  %s  ·  %s  ·  %d%%" % [part.tag, nm, preload("res://scripts/parts_rack_panel.gd").short_class(str(part.cls)), int(round(float(part.cond) * 100.0))], 15))
			col.add_child(OpsSkin.label(Disposal.part_note(part, want, true), 13, 0.55))
			var sb := _choice(w("卖 %s", "SELL %s") % Pal.money(Repair.part_worth(part)))
			sb.custom_minimum_size.x = 150
			sb.pressed.connect(_part.bind(uid, true))
			sb.tooltip_text = "%s · %s\n%s" % [nm, Repair.class_name_of(str(part.cls)), Disposal.part_note(part, want)]
			row.add_child(sb)
			var kb := _choice(w("留", "KEEP"))
			kb.custom_minimum_size.x = 84
			kb.pressed.connect(_part.bind(uid, false))
			kb.tooltip_text = sb.tooltip_text
			row.add_child(kb)
			part_rows[uid] = [sb, kb]
	total = OpsSkin.label("", 17)
	column.add_child(total)
	message = OpsSkin.label("", 14)
	column.add_child(message)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	column.add_child(foot)
	var ok := Button.new()
	ok.name = "Confirm"
	ok.text = w("确认，离开船坞 [Enter]", "CONFIRM AND LEAVE [Enter]")
	ok.custom_minimum_size.y = 44
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(confirm)
	foot.add_child(ok)
	var back := Button.new()
	back.text = w("回结算单 [Esc]", "BACK [Esc]")
	back.custom_minimum_size.y = 44
	back.pressed.connect(func(): on_back.call())
	foot.add_child(back)
	_refresh()
	ok.grab_focus.call_deferred()


func _choice(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.custom_minimum_size.y = 40
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	return b


func _metal(v: String) -> void:
	metal = v
	_refresh()


func _part(uid: String, sold: bool) -> void:
	sell[uid] = sold
	_refresh()


func sold_uids() -> Array:
	var out: Array = []
	for uid in sell:
		if sell[uid]:
			out.append(uid)
	return out


func cash_now() -> float:
	var cash := 0.0
	if metal == "sell":
		cash += Disposal.sell_cash(d)
	for part in Disposal.parts():
		if sell.get(str(part.uid), false):
			cash += Repair.part_worth(part)
	return cash


func _refresh() -> void:
	if sell_b != null:
		sell_b.set_pressed_no_signal(metal == "sell")
		keep_b.set_pressed_no_signal(metal == "keep")
	var kept := 0
	for uid in part_rows:
		part_rows[uid][0].set_pressed_no_signal(sell[uid])
		part_rows[uid][1].set_pressed_no_signal(not sell[uid])
		if not sell[uid]:
			kept += 1
	var bits: Array = [w("现在到账 %s", "CASH NOW %s") % Pal.money(cash_now())]
	if part_rows.size() > 0:
		bits.append(w("留下设备 %d 件", "%d PIECES KEPT") % kept)
	if float(d.get("ingot_t", 0.0)) > 0.0005 and metal == "keep":
		bits.append(w("%.1f t 钢锭送去加工", "%.1f t OF INGOTS TO PROCESS") % float(d.ingot_t))
	total.text = "  ·  ".join(bits)


func confirm() -> void:
	var r := Disposal.apply(metal, sold_uids())
	if not r.ok:
		message.text = w("保存失败，什么都没卖：再按一次确认。", "Save failed, nothing sold: confirm again.")
		return
	on_done.call()


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	match ev.keycode:
		KEY_ESCAPE:
			on_back.call()
		KEY_ENTER, KEY_KP_ENTER:
			confirm()
		KEY_1:
			if sell_b != null: _metal("sell")
		KEY_2:
			if sell_b != null: _metal("keep")
		_:
			return
	get_viewport().set_input_as_handled()
