extends Control
# The rolling mill's own panel (85 号; as a Dyson Sphere Program building's window): the recipe
# (plate or sections, picked by a tile, used from the next pass), the flow — the input slot (billet
# in the warehouse, a tonne a pass), the pass's progress, the output slot (that product in stock,
# and what this session rolled) — the lamp with its reason, the rate at the power it has, and the
# hand on it: one pass, rolling on while billet lasts, stop after this pass. Opened with E at the
# mill's pedestal (scripts/mill_line.gd); play goes on while it is open; Esc closes it.

var game
var on_close: Callable
var power_l: Label
var power_b: Button
var recipe_box: HBoxContainer
var tiles := {}
var in_slot: Slot
var bar: Flow
var out_slot: Slot
var lamp_label: Label
var rate_label: Label
var once_b: Button
var loop_b: CheckButton
var stop_b: Button
var message: Label
var _t := 0.0


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


# a slot: the goods' picture, its name, a big figure and a small one under it
class Slot extends Control:
	var item := ""
	var title := ""
	var big := ""
	var small := ""
	var lit := false
	func _init() -> void:
		custom_minimum_size = Vector2(150, 150)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(UiSkin.glass(0.04, 0.5 if lit else 0.15, 12, 0.0), r)
		var f := Fonts.get_font("Medium")
		draw_string(f, Vector2(12, 22), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 13, Pal.ink(0.6))
		var parts := item.split(":")
		GoodsArt.draw(self, Rect2(Vector2(size.x * 0.5 - 48, 30), Vector2(96, 60)), parts[0], int(parts[1]) if parts.size() > 1 else 0)
		draw_string(f, Vector2(12, size.y - 34), big, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 22, Pal.ink(0.95))
		draw_string(f, Vector2(12, size.y - 12), small, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 12, Pal.ink(0.55))


# between the slots: the pass's progress as a bar with chevrons running through it
class Flow extends Control:
	var k := 0.0
	var text := ""
	var col := Color.WHITE
	var t := 0.0
	func _init() -> void:
		custom_minimum_size = Vector2(150, 150)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var y := size.y * 0.5
		var r := Rect2(Vector2(8, y - 7), Vector2(size.x - 16, 14))
		draw_rect(r, Pal.ink(0.1))
		draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)), col)
		for i in 5:
			var x := r.position.x + fmod(t * 40.0 * (1.0 if k > 0.0 else 0.0) + i * r.size.x / 5.0, r.size.x)
			draw_polyline(PackedVector2Array([Vector2(x - 4, y - 5), Vector2(x + 2, y), Vector2(x - 4, y + 5)]), Pal.ink(0.35), 2.0)
		var f := Fonts.get_font("Medium")
		draw_string(f, Vector2(8, y + 30), text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 14, Pal.ink(0.8))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var accent := Pal.tint(Pal.AIR, 1.0, 1.2)
	var column := OpsSkin.pane(self, accent, 600.0)
	column.add_child(OpsSkin.Plate.new("ROLL-1", w("轧机", "ROLLING MILL"), w("加工区 · 钢坯 → 钢板 / 型材 · %.0f MW", "PROCESSING · BILLET → PLATE / SECTIONS · %.0f MW") % Mill.MW, accent))
	column.add_child(OpsSkin.Section.new(w("配方（点一块，下一次就轧它）", "RECIPE (PICK ONE: THE NEXT PASS ROLLS IT)")))
	recipe_box = HBoxContainer.new()
	recipe_box.add_theme_constant_override("separation", 10)
	column.add_child(recipe_box)
	for p in ["plate", "section"]:
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 92)
		BenchFx.note(b, w("选这个配方：之后轧出来的就是它", "Pick this recipe: what is rolled next is this"))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# the picture on the left, the name and the recipe beside it (the button's own text stays empty)
		var inner := HBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 10
		inner.offset_right = -10
		inner.add_theme_constant_override("separation", 12)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pic := Control.new()
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.custom_minimum_size = Vector2(88, 55)
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var key: String = Mill.PRODUCTS[p]
		pic.draw.connect(func(): GoodsArt.draw(pic, Rect2(Vector2.ZERO, pic.size), key.split(":")[0], 1))
		inner.add_child(pic)
		var words_box := VBoxContainer.new()
		words_box.alignment = BoxContainer.ALIGNMENT_CENTER
		words_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := OpsSkin.label(Mill.product_name(p), 20)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words_box.add_child(nm)
		var rc := OpsSkin.label(w("1 t 钢坯 → 1 t · 满电 %d 秒", "1 t BILLET → 1 t · %d s AT FULL POWER") % int(Mill.ROLL_S), 13, 0.65)
		rc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words_box.add_child(rc)
		inner.add_child(words_box)
		b.add_child(inner)
		b.pressed.connect(func(): _pick(p))
		recipe_box.add_child(b)
		tiles[p] = b
	column.add_child(OpsSkin.Section.new(w("生产", "PRODUCTION")))
	var flow := HBoxContainer.new()
	flow.add_theme_constant_override("separation", 8)
	column.add_child(flow)
	in_slot = Slot.new()
	in_slot.item = Mill.FEED
	in_slot.title = w("进料 · 钢坯", "IN · BILLET")
	flow.add_child(in_slot)
	bar = Flow.new()
	flow.add_child(bar)
	out_slot = Slot.new()
	out_slot.title = w("出料", "OUT")
	flow.add_child(out_slot)
	lamp_label = OpsSkin.label("", 17)
	column.add_child(lamp_label)
	rate_label = OpsSkin.label("", 14, 0.65)
	column.add_child(rate_label)
	var row := HFlowContainer.new()
	column.add_child(row)
	once_b = Button.new()
	once_b.text = w("轧一次（1 t）", "ONE PASS (1 t)")
	BenchFx.note(once_b, w("立刻轧一次：用掉 1 t 钢坯，按选好的配方轧出产品", "Roll once now: 1 t of billet into the chosen recipe"))
	once_b.custom_minimum_size.y = 42
	once_b.pressed.connect(_once)
	row.add_child(once_b)
	loop_b = CheckButton.new()
	loop_b.text = w("连续轧（有钢坯就一直轧）", "ROLL ON (WHILE THERE IS BILLET)")
	BenchFx.note(loop_b, w("打开后，仓库里有钢坯就一直轧下去；关掉就停", "On: it keeps rolling while there is billet; off: it stops"))
	loop_b.button_pressed = bool(Mill.cfg().loop)
	loop_b.toggled.connect(func(v):
		Mill.set_loop(v)
		message.text = w("连续轧开了：仓库有钢坯就一直轧。", "ROLLING ON while there is billet.") if v else w("连续轧关了：这一次轧完就停。", "ROLLING ON is off: it stops after this pass.")
		_refresh())
	row.add_child(loop_b)
	# 106 号: short of power — the reason and the way to the power control screen
	power_l = OpsSkin.label("", 14, 0.7)
	column.add_child(power_l)
	power_b = Button.new()
	power_b.text = w("去电网调度", "TO THE POWER CONTROL SCREEN")
	BenchFx.note(power_b, w("关掉轧机台，去供电控制屏调电", "Close the mill desk and go to the power control screen"))
	power_b.custom_minimum_size.y = 42
	power_b.pressed.connect(func():
		close()
		if game != null and is_instance_valid(game):
			game.open_power_screen.call_deferred())
	column.add_child(power_b)
	message = OpsSkin.label("", 15)
	column.add_child(message)
	var close_b := Button.new()
	close_b.text = w("关闭 [Esc]", "CLOSE [Esc]")
	close_b.custom_minimum_size.y = 42
	close_b.pressed.connect(close)
	column.add_child(close_b)
	_refresh()


func _pick(p: String) -> void:
	Mill.set_product(p)
	message.text = w("下一次轧%s。", "THE NEXT PASS ROLLS %s.") % Mill.product_name(p)
	if Mill.busy() and str(Mill.job().product) != p:
		message.text += w("（这一次还在轧%s）", " (THIS PASS IS STILL %s)") % Mill.product_name(str(Mill.job().product))
	_refresh()


func _once() -> void:
	var r := Mill.start(str(Mill.cfg().product))
	message.text = w("开轧：叉车先从仓库送一吨钢坯来。", "STARTED: THE FORKLIFT BRINGS A TONNE OF BILLET FIRST.") if r.ok else str(r.reason)
	_refresh()


func _refresh() -> void:
	var c := Mill.cfg()
	var p := str(c.product)
	for k in tiles:
		tiles[k].button_pressed = k == p
	var feed := Mill.feed_t()
	in_slot.big = "%.1f t" % feed
	in_slot.small = w("仓库存量 · 每次 1 t", "IN STOCK · 1 t A PASS")
	in_slot.lit = feed >= Mill.BATCH - 0.0001
	var shown := str(Mill.job().get("product", p))
	out_slot.item = Mill.PRODUCTS[shown]
	out_slot.title = w("出料 · %s", "OUT · %s") % Mill.product_name(shown)
	out_slot.big = "%.1f t" % Mill.made_t(shown)
	out_slot.small = w("仓库里 · 这次共轧 %.0f t", "IN STOCK · %.0f t ROLLED") % float(c.get("made", 0.0))
	out_slot.lit = Mill.busy()
	var lamp: Array = Mill.lamp(game)
	bar.k = Mill.progress()
	bar.col = preload("res://scripts/mill_line.gd")._lamp_col(str(lamp[0]))
	var j := Mill.job()
	bar.text = (w("%d%% · 还剩约 %d 秒", "%d%% · ~%d s LEFT") % [int(bar.k * 100.0), ceili(float(j.left) / maxf(0.05, Mill.k(game)))]) if not j.is_empty() and str(j.state) == "roll" else (w("等钢坯", "WAITING") if not j.is_empty() else w("停着", "STOPPED"))
	lamp_label.text = "● " + str(lamp[1])
	lamp_label.add_theme_color_override("font_color", bar.col)
	rate_label.text = w("满电约 %.1f t/分钟 · 现在 %.1f t/分钟 · 用电 %.0f MW", "%.1f t/min AT FULL POWER · %.1f NOW · %.0f MW") % [60.0 / Mill.ROLL_S * Mill.BATCH, Mill.rate(game), Mill.MW]
	var why := Mill.block(p)
	once_b.disabled = why != ""
	once_b.tooltip_text = why
	if why != "" and not Mill.busy() and message.text == "":
		message.text = why
	loop_b.set_pressed_no_signal(bool(c.loop))
	var short := Mill.k(game) < 0.98
	power_l.visible = short
	power_b.visible = short
	if short:
		# the reason is on the lamp's line above; here what can be done about it
		power_l.text = Grid.short_fix()
	for n in [in_slot, bar, out_slot]:
		n.queue_redraw()


func _process(dt: float) -> void:
	_t += dt
	bar.t = _t
	bar.queue_redraw()
	if fmod(_t, 0.25) < dt:
		_refresh()


func close() -> void:
	if on_close.is_valid():
		on_close.call()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
