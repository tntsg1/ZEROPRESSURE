extends Control
const Back := preload("res://scripts/ui_back.gd")
# One side of the cargo district's racks (85 号, user 2026-10-26: "左边的这个柜台就显示左边柜台的东西，
# 右边柜台显示右边柜台的东西"): opened with E at that rack's mouth (scripts/cargo_floor.gd). Its four
# rows only, each a card: what the row is for (set here), what is on it now (the company's goods
# and clients' crates, in tonnes), how long a pick takes. Play goes on while it is open; Esc closes.

var game
var side := "A"
var on_close: Callable
var rows_box: VBoxContainer
var message: Label
var _sig := ""
var _t := 0.0


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func rows() -> Array:
	return [0, 1, 2, 3] if side == "A" else [4, 5, 6, 7]


func _ready() -> void:
	Back.arrive()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := OpsSkin.pane(self, Charcoal.ACCENT, 520.0)
	column.add_child(OpsSkin.Plate.new("RACK-" + side, w("%s货架 · %s", "%s RACKS · %s") % [w("左边", "LEFT") if side == "A" else w("右边", "RIGHT"), "%s1–%s4" % [side, side]], w("货运区 · 只管这一边的四排 · 全部东西按 F3 看公司仓库", "CARGO · THIS SIDE'S FOUR ROWS ONLY · F3: EVERYTHING"), Charcoal.ACCENT))
	rows_box = VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 8)
	column.add_child(rows_box)
	message = OpsSkin.label("", 15)
	column.add_child(message)
	# 86 号 Q11: the parts kept for repairs moved here from the berth's rack once this district works
	if side == "A" and Port.stage("cargo") >= 1:
		var parts_b := Button.new()
		parts_b.name = "PartsRack"
		parts_b.text = w("零件架 · %d 件", "PARTS RACK · %d") % Career.data.get("parts", []).size()
		BenchFx.note(parts_b, w("打开零件架：看架上有哪些零件、成色多少", "Open the parts rack: what is on it, in what condition"))
		parts_b.custom_minimum_size.y = 46
		Charcoal.style_button(parts_b)
		parts_b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		parts_b.pressed.connect(func():
			var g = game
			if g != null: _leave("rack", func(): g.open_parts_rack())
			else: close())
		column.add_child(parts_b)
	var close_b := Button.new()
	close_b.text = Back.close_text()
	close_b.custom_minimum_size.y = 46
	close_b.pressed.connect(_back)
	Charcoal.style_button(close_b)
	Charcoal.key_text(close_b)
	column.add_child(close_b)
	_fill()


func _stock() -> Dictionary:
	return Career.data.get("exchange", {}).get("actors", {}).get("company", {}).get("stock", {})


func _sig_now() -> String:
	var parts: Array = [str(Warehouse.rows())]
	var st := _stock()
	for k in st:
		parts.append("%s=%.2f" % [str(k), float(st[k])])
	return ",".join(parts)


func _fill() -> void:
	var sig := _sig_now()
	if sig == _sig:
		return
	_sig = sig
	for c in rows_box.get_children():
		c.queue_free()
	var use: Array = Warehouse.rows()
	var st := _stock()
	for i in rows():
		# 2026-11-11 炭黑 v2: each row a black window — its code large, what it holds, its lamp lit
		# while something is on it; the choice of goods a dark key (was a light grey glass card)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", Charcoal.well_box(14.0))
		card.name = "Row" + Warehouse.ROWS[i]
		var rowh := HBoxContainer.new()
		rowh.add_theme_constant_override("separation", 14)
		card.add_child(rowh)
		var code := OpsSkin.label(str(Warehouse.ROWS[i]), 30)
		code.add_theme_font_override("font", Fonts.get_font("Light"))
		code.custom_minimum_size.x = 48
		code.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rowh.add_child(code)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rowh.add_child(col)
		var head := HBoxContainer.new()
		col.add_child(head)
		var nm := OpsSkin.label(Warehouse.row_text(i, game), 16)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(nm)
		var pick := OptionButton.new()
		for u in Warehouse.USES:
			pick.add_item(Warehouse.use_name(u))
		pick.selected = Warehouse.USES.find(str(use[i]))
		BenchFx.note(pick, w("选这一排货架放哪类货：立刻生效", "Choose what this row of racks holds: takes effect at once"))
		var idx: int = i
		pick.item_selected.connect(func(j):
			var res := Warehouse.set_row(idx, Warehouse.USES[j])
			message.text = (w("%s 改放%s。", "%s NOW HOLDS %s.") % [Warehouse.ROWS[idx], Warehouse.use_name(Warehouse.USES[j])]) if res.ok else str(res.reason)
			_sig = ""
			_fill.call_deferred())
		Charcoal.style_button(pick)
		head.add_child(pick)
		var held: Array = []
		for k in st:
			if float(st[k]) > 0.004 and Warehouse.row_for(str(k)) == i:
				held.append("%s %.2f t" % [Ops.item_name(str(k)), float(st[k])])
		col.add_child(OpsSkin.label(w("上面：", "ON IT: ") + (("、" if Txt.zh else ", ").join(held) if not held.is_empty() else w("空着", "EMPTY")), 14, 0.9 if not held.is_empty() else 0.5))
		code.add_theme_color_override("font_color", Charcoal.ACCENT if not held.is_empty() else Pal.ink(0.55))
		rows_box.add_child(card)


func _process(dt: float) -> void:
	_t += dt
	if fmod(_t, 0.5) < dt:
		_fill()


# 134 号: how to open this page again, for the page it leaves for; Esc and the close key go back
# where it was opened from, else away (scripts/ui_back.gd)
func _back_entry() -> Dictionary:
	var g = game
	var sd := side
	return Back.entry("shelf:" + sd, ["货架", "THE RACKS"], func(): g.open_shelf(sd))

func _leave(to: String, open: Callable) -> void:
	var e := _back_entry()
	close()
	Back.go(e, to, open)


func _back() -> void:
	close()
	Back.back()


func close() -> void:
	if on_close.is_valid():
		on_close.call()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_back()
