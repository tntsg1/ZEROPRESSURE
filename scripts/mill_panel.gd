extends Control
const Back := preload("res://scripts/ui_back.gd")
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
const ConsoleKit = preload("res://scripts/console_kit.gd")
var now_line
var more_key: Button
var more_box: VBoxContainer
var _more_fold: BenchFx.Fold


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
	Back.arrive()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var accent := Pal.tint(Pal.AIR, 1.0, 1.2)
	# 132 号: a 520 px card on the far side of the mill; the top line, the recipe, the flow, one orange key
	var column := ConsoleKit.solid(self, ConsoleKit.W_CARD)
	ConsoleKit.card_side(self, ConsoleKit.screen_x(game, preload("res://scripts/mill_line.gd").centre()))
	column.add_child(ConsoleKit.header(w("轧机控制台", "ROLLING MILL"), "ROLL-1"))
	now_line = ConsoleKit.NowLine.new()
	column.add_child(now_line)
	recipe_box = HBoxContainer.new()
	recipe_box.add_theme_constant_override("separation", 10)
	column.add_child(recipe_box)
	for p in ["plate", "section"]:
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 92)
		BenchFx.note(b, w("选择要生产的产品配方，之后轧机会按照这个配方进行加工", "Pick this recipe: what is rolled next is this"))
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
		var nm := OpsSkin.label(Mill.product_name(p), 24)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words_box.add_child(nm)
		var rc := OpsSkin.label(w("消耗 1 t 钢坯，可生产 1 t 产品", "1 t BILLET → 1 t"), 16, 0.65)
		rc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words_box.add_child(rc)
		inner.add_child(words_box)
		b.add_child(inner)
		b.pressed.connect(func(): _pick(p))
		recipe_box.add_child(b)
		tiles[p] = b
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
	out_slot.title = w("成品出料", "OUT")
	flow.add_child(out_slot)
	lamp_label = OpsSkin.label("", 20)
	column.add_child(lamp_label)
	rate_label = OpsSkin.label("", 16, 0.65)
	var row := HFlowContainer.new()
	column.add_child(row)
	once_b = Button.new()
	once_b.text = w("加工一次（1 t）", "ONE PASS (1 t)")
	BenchFx.note(once_b, w("立即开始一次轧制，消耗 1 t 钢坯，按照当前选择的配方生产对应产品", "Roll once now: 1 t of billet into the chosen recipe"))
	once_b.custom_minimum_size.y = 48
	once_b.add_theme_font_size_override("font_size", 20)
	once_b.pressed.connect(_once)
	column.add_child(once_b)
	loop_b = CheckButton.new()
	loop_b.text = w("连续轧制", "ROLL ON: EACH BILLET AS IT COMES")
	loop_b.add_theme_font_size_override("font_size", 20)
	loop_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BenchFx.note(loop_b, w("开启后，只要仓库里还有钢坯，轧机就会按照当前配方持续生产；关闭后停止连续轧制", "On: it keeps rolling while there is billet; off: it stops"))
	loop_b.button_pressed = bool(Mill.cfg().loop)
	loop_b.toggled.connect(func(v):
		Mill.set_loop(v)
		message.text = w("已开启连续轧制。", "ROLLING ON while there is billet.") if v else w("已关闭连续轧制。", "ROLLING ON is off: it stops after this pass.")
		_refresh())
	row.add_child(loop_b)
	# 106 号: short of power — the reason and the way to the power control screen
	power_l = OpsSkin.label("", 16, 0.7)
	power_b = Button.new()
	power_b.text = w("前往动力区", "TO THE POWER DISTRICT")
	BenchFx.note(power_b, w("关闭轧机控制台，前往供电控制屏调整电力分配。", "Close the mill desk and go to the power control screen"))
	power_b.custom_minimum_size.y = 42
	power_b.pressed.connect(func():
		var g = game
		if g != null and is_instance_valid(g): _leave("power", func(): g.open_power_screen())
		else: close())
	column.add_child(power_b)
	# 更多: the rate, what can be done about the power
	more_key = Button.new()
	more_key.text = w("更多设置 › 轧制速度 · 电网供电", "MORE ›   RATE · POWER")
	more_key.alignment = HORIZONTAL_ALIGNMENT_LEFT
	more_key.add_theme_font_size_override("font_size", 18)
	more_key.custom_minimum_size.y = 44
	more_key.pressed.connect(func(): _more_fold.set_open(not _more_fold.open))
	column.add_child(more_key)
	more_box = VBoxContainer.new()
	more_box.visible = false
	column.add_child(more_box)
	more_box.add_child(rate_label)
	more_box.add_child(power_l)
	_more_fold = BenchFx.fold(more_box)
	_more_fold.on_toggle = func(open: bool): more_key.text = w("收起设置 ▾", "MORE ▾") if open else w("更多设置 › 轧制速度 · 电网供电", "MORE ›   RATE · POWER")
	message = OpsSkin.label("", 18)
	column.add_child(message)
	var close_b := Button.new()
	close_b.text = Back.close_text() if Back.has_back() else w("关闭面板 [Esc]", "CLOSE [Esc]")
	close_b.custom_minimum_size.y = 42
	close_b.pressed.connect(_back)
	column.add_child(close_b)
	_refresh()


func _pick(p: String) -> void:
	Mill.set_product(p)
	message.text = w("下次将轧制%s。", "THE NEXT PASS ROLLS %s.") % Mill.product_name(p)
	if Mill.busy() and str(Mill.job().product) != p:
		message.text += w("（当前正在轧制%s）", " (THIS PASS IS STILL %s)") % Mill.product_name(str(Mill.job().product))
	_refresh()


func _once() -> void:
	var r := Mill.start(str(Mill.cfg().product))
	message.text = w("开始轧制：叉车会先从仓库运来 1 吨钢坯。", "STARTED: THE FORKLIFT BRINGS A TONNE OF BILLET FIRST.") if r.ok else str(r.reason)
	_refresh()


func _refresh() -> void:
	var c := Mill.cfg()
	var p := str(c.product)
	for k in tiles:
		tiles[k].button_pressed = k == p
	var feed := Mill.feed_t()
	in_slot.big = "%.1f t" % feed
	in_slot.small = w("仓库库存", "IN STOCK · 1 t A PASS")
	in_slot.lit = feed >= Mill.BATCH - 0.0001
	var shown := str(Mill.job().get("product", p))
	out_slot.item = Mill.PRODUCTS[shown]
	out_slot.title = w("轧制成品 · %s", "OUT · %s") % Mill.product_name(shown)
	out_slot.big = "%.1f t" % Mill.made_t(shown)
	out_slot.small = w("仓库库存 · 累计轧制 %.0f t", "IN STOCK · %.0f t ROLLED") % float(c.get("made", 0.0))
	out_slot.lit = Mill.busy()
	var lamp: Array = Mill.lamp(game)
	bar.k = Mill.progress()
	bar.col = preload("res://scripts/mill_line.gd")._lamp_col(str(lamp[0]))
	var j := Mill.job()
	bar.text = (w("加工进度 %d%% · 预计还需 %d 秒", "%d%% · ~%d s LEFT") % [int(bar.k * 100.0), ceili(float(j.left) / maxf(0.05, Mill.k(game)))]) if not j.is_empty() and str(j.state) == "roll" else (w("正在等待钢坯送达", "WAITING") if not j.is_empty() else w("轧机已停止运行", "STOPPED"))
	lamp_label.text = "● " + str(lamp[1])
	lamp_label.add_theme_color_override("font_color", bar.col)
	rate_label.text = w("满功率时每分钟可轧制约 %.1f t · 当前每分钟轧制 %.1f t · 当前用电功率 %.0f MW", "%.1f t/min AT FULL POWER · %.1f NOW · %.0f MW") % [60.0 / Mill.ROLL_S * Mill.BATCH, Mill.rate(game), Mill.MW]
	var why := Mill.block(p)
	once_b.disabled = why != ""
	once_b.tooltip_text = why
	if why != "" and not Mill.busy() and message.text == "":
		message.text = why
	loop_b.set_pressed_no_signal(bool(c.loop))
	# 2026-11-10 用户: the way to the power district only when it would help — the mill rolling,
	# set to roll or able to start, and the power district open; idle with nothing to roll it is noise
	var short := Mill.k(game) < 0.98 and Mainline.power_open() and (Mill.busy() or bool(c.loop) or why == "")
	power_l.visible = short
	power_b.visible = short
	if short:
		# the reason is on the lamp's line above; here what can be done about it
		power_l.text = Grid.short_fix()
	# 132 号: the one orange key and the line that says it
	if short and (Mill.busy() or bool(c.loop)):
		ConsoleKit.orange(power_b, 22)
		power_b.text = w("前往动力区", "TO THE POWER DISTRICT")
		ConsoleKit.plain(once_b, 20)
		now_line.set_now(true, Grid.short_label(int(Mill.k(game) * 100.0)) + w("前往动力区", ": TO THE POWER DISTRICT"))
	elif why == "" and not Mill.busy():
		ConsoleKit.orange(once_b, 22)
		once_b.text = w("加工一次（1 t）", "ONE PASS (1 t)")
		ConsoleKit.plain(power_b, 20)
		now_line.set_now(true, w("仓库现有 %.1f t 钢坯，轧机目前处于停止状态", "%.1f t OF BILLET IN STORE, THE MILL IDLE") % feed)
	else:
		ConsoleKit.plain(once_b, 20)
		once_b.text = w("加工一次（1 t）", "ONE PASS (1 t)")
		ConsoleKit.plain(power_b, 20)
		power_b.text = w("前往动力区", "TO THE POWER DISTRICT")
		if Mill.busy():
			now_line.set_now(false, (w("连续轧制已开启，当前正在轧制%s", "ROLLING ON: %s") if bool(c.loop) else w("当前正在轧制%s", "ROLLING %s")) % Mill.product_name(str(Mill.job().get("product", p))))
		else:
			now_line.set_now(false, why if why != "" else w("轧机已停止运行", "STOPPED"))
	for n in [in_slot, bar, out_slot]:
		n.queue_redraw()


func _process(dt: float) -> void:
	ConsoleKit.card_fit(self)
	_t += dt
	bar.t = _t
	bar.queue_redraw()
	if fmod(_t, 0.25) < dt:
		_refresh()


# 134 号: how to open this page again, for the page it leaves for; Esc and the close key go back
# where it was opened from, else away (scripts/ui_back.gd)
func _back_entry() -> Dictionary:
	var g = game
	return Back.entry("mill", ["轧机控制台", "THE MILL DESK"], func(): g.open_mill())

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
