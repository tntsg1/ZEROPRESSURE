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
		# 炭黑 v2: a black window with its lamp; the tonnage large
		Charcoal.display(self, r, 1.0, 9)
		var f := Fonts.get_font("Medium")
		Charcoal.led(self, Vector2(size.x - 16, 18), lit, 1.0, 4.0, Color(0.9, 0.91, 0.88))
		draw_string(f, Vector2(12, 23), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 12, Pal.ink(0.5))
		var parts := item.split(":")
		GoodsArt.draw(self, Rect2(Vector2(size.x * 0.5 - 44, 34), Vector2(88, 54)), parts[0], int(parts[1]) if parts.size() > 1 else 0)
		draw_string(Fonts.get_font("Light"), Vector2(10, size.y - 30), big, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 28, Pal.ink(0.97))
		draw_string(f, Vector2(12, size.y - 11), small, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 11, Pal.ink(0.5))


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
		# 炭黑 v2: the pass runs in a black slot
		Charcoal.display(self, r.grow(4.0), 1.0, 5)
		draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)), col)
		for i in 5:
			var x := r.position.x + fmod(t * 40.0 * (1.0 if k > 0.0 else 0.0) + i * r.size.x / 5.0, r.size.x)
			draw_polyline(PackedVector2Array([Vector2(x - 4, y - 5), Vector2(x + 2, y), Vector2(x - 4, y + 5)]), Pal.ink(0.35), 2.0)
		var f := Fonts.get_font("Medium")
		draw_string(f, Vector2(8, y + 30), text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 14, Pal.ink(0.8))


# 炭黑 v3: the page's centrepiece — one black window: the billet in store on the left, the product on
# the right, between them the roller table and the roll stand; while a pass runs the billet rides the
# rollers into the stand, hot, and leaves it as plate; the pass's progress as segments under it
class MillView extends Control:
	var p
	func _init() -> void:
		custom_minimum_size = Vector2(0, 268)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		Charcoal.display(self, r, 1.0, 12)
		var f: Font = Fonts.get_font("Medium")
		var fl: Font = Fonts.get_font("Light")
		var t: float = p._t if p != null else 0.0
		var j: Dictionary = Mill.job()
		var rolling := not j.is_empty() and str(j.get("state", "")) == "roll"
		var waiting := not j.is_empty() and not rolling
		var k: float = Mill.progress() if rolling else 0.0
		# the two ends side by side over the table: what is in store, what has been made
		var half := size.x * 0.5
		var sides := [[p.in_slot, 0.0], [p.out_slot, half]]
		for sd in sides:
			var sl = sd[0]
			var x: float = sd[1] + 18.0
			draw_string(f, Vector2(x, 28), sl.title, HORIZONTAL_ALIGNMENT_LEFT, half - 60.0, 12, Pal.ink(0.5))
			Charcoal.led(self, Vector2(sd[1] + half - 20.0, 23), sl.lit, 1.0, 4.0, Color(0.9, 0.91, 0.88))
			var parts: PackedStringArray = str(sl.item).split(":")
			GoodsArt.draw(self, Rect2(Vector2(x, 42), Vector2(84, 52)), parts[0], int(parts[1]) if parts.size() > 1 else 0)
			draw_string(fl, Vector2(x + 96, 84), sl.big, HORIZONTAL_ALIGNMENT_LEFT, half - 130.0, 34, Pal.ink(0.97))
			draw_string(f, Vector2(x, 112), sl.small, HORIZONTAL_ALIGNMENT_LEFT, half - 36.0, 11, Pal.ink(0.5))
		draw_line(Vector2(half, 16), Vector2(half, 112), Color(1, 1, 1, 0.07), 1.0)
		draw_line(Vector2(16, 126), Vector2(size.x - 16, 126), Color(1, 1, 1, 0.07), 1.0)
		# the roller table across the whole window, the stand in its middle
		var x0 := 26.0
		var x1 := size.x - 26.0
		var ry := 178.0
		var cx := (x0 + x1) * 0.5
		var spin := t * 7.0 if rolling and BenchFx.on() else 0.0
		var n := maxi(1, int((x1 - x0) / 26.0))
		for i in n + 1:
			var rx := x0 + i * (x1 - x0) / float(n)
			if absf(rx - cx) < 28.0:
				continue
			draw_arc(Vector2(rx, ry + 15), 6.5, 0.0, TAU, 14, Pal.ink(0.45), 1.5, true)
			draw_line(Vector2(rx, ry + 15), Vector2(rx, ry + 15) + Vector2(cos(spin), sin(spin)) * 5.5, Pal.ink(0.45), 1.5)
		draw_line(Vector2(x0 - 8, ry + 24), Vector2(x1 + 8, ry + 24), Pal.ink(0.22), 2.0)
		# the stand: its housing and two work rolls
		draw_rect(Rect2(cx - 30, ry - 46, 60, 92), Pal.ink(0.55), false, 2.0)
		for dy in [-23.0, 23.0]:
			var rc := Vector2(cx, ry + dy)
			draw_arc(rc, 15.0, 0.0, TAU, 28, Pal.ink(0.85) if rolling else Pal.ink(0.55), 2.0, true)
			var a: float = spin * (1.0 if dy < 0.0 else -1.0)
			draw_line(rc - Vector2(cos(a), sin(a)) * 11.0, rc + Vector2(cos(a), sin(a)) * 11.0, Pal.ink(0.4), 1.5)
		# the billet: thick and hot going in, thin and long coming out
		var hot := Charcoal.ACCENT
		if rolling:
			var head := lerpf(x0 + 70.0, x1 - 6.0, k)
			if head < cx:
				draw_rect(Rect2(head - 70.0, ry - 6, 70.0, 14), hot)
			else:
				var tail_in := maxf(0.0, 70.0 * (1.0 - (head - cx) / maxf(1.0, x1 - 6.0 - cx)))
				if tail_in > 0.0:
					draw_rect(Rect2(cx - tail_in, ry - 6, tail_in, 14), hot)
				draw_rect(Rect2(cx, ry + 2, head - cx, 6), hot.lerp(Pal.ink(0.9), clampf((head - cx) / 260.0, 0.0, 0.6)))
		elif waiting:
			var blink := (0.35 + 0.35 * sin(t * 4.0)) if BenchFx.on() else 0.6
			draw_rect(Rect2(x0 + 4, ry - 6, 70.0, 14), Pal.ink(blink), false, 1.5)
		# the pass's progress
		Charcoal.segments(self, Rect2(16, size.y - 44, size.x - 32, 8), k * 24.0, 24)
		draw_string(f, Vector2(16, size.y - 14), str(p.bar.text), HORIZONTAL_ALIGNMENT_LEFT, size.x - 32, 14, Pal.ink(0.8))


# the lamp's state in a black window with a big lamp; the rate at its right
class StatusWin extends Control:
	var p
	func _init() -> void:
		custom_minimum_size = Vector2(0, 56)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		Charcoal.display(self, Rect2(Vector2.ZERO, size), 1.0, 9)
		var col: Color = p.bar.col
		var lit: bool = p.lamp_state != "idle" and p.lamp_state != "off"
		Charcoal.led(self, Vector2(30, size.y * 0.5), lit, 1.0, 6.0, col if lit else Charcoal.ACCENT)
		var f: Font = Fonts.get_font("SemiBold")
		var t := str(p.lamp_label.text).trim_prefix("● ")
		draw_string(f, Vector2(56, size.y * 0.5 + 8), t, HORIZONTAL_ALIGNMENT_LEFT, size.x - 200, 22, Pal.ink(0.96))
		var rt := ("%.1f t/min" % Mill.rate(p.game)) if p.game != null else ""
		var fm: Font = Fonts.get_font("Light")
		var tw := fm.get_string_size(rt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(fm, Vector2(size.x - 18 - tw, size.y * 0.5 + 9), rt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Pal.ink(0.85))


var view: MillView
var status_win: StatusWin
var lamp_state := "idle"


func _ready() -> void:
	Back.arrive()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
		b.custom_minimum_size = Vector2(0, 104)
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
		# 炭黑 v2: the recipe tiles are dark keys; the chosen one sunk, its lamp lit, the orange lip
		Charcoal.style_card(b, 10)
		b.draw.connect(func():
			Charcoal.led(b, Vector2(b.size.x - 16, 16), b.button_pressed, 1.0, 4.0)
			if b.button_pressed:
				Charcoal.lip(b, Rect2(14, b.size.y - 5, b.size.x - 28, 3)))
		recipe_box.add_child(b)
		tiles[p] = b
	view = MillView.new()
	view.p = self
	column.add_child(view)
	# the old slots and bar hold the figures the view draws (and tests read); not shown
	var flow := HBoxContainer.new()
	flow.visible = false
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
	lamp_label.visible = false
	column.add_child(lamp_label)
	status_win = StatusWin.new()
	status_win.p = self
	column.add_child(status_win)
	rate_label = OpsSkin.label("", 16, 0.65)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	once_b = Button.new()
	once_b.text = w("加工一次（1 t）", "ONE PASS (1 t)")
	BenchFx.note(once_b, w("立即开始一次轧制，消耗 1 t 钢坯，按照当前选择的配方生产对应产品", "Roll once now: 1 t of billet into the chosen recipe"))
	once_b.custom_minimum_size.y = 84
	once_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	once_b.add_theme_font_size_override("font_size", 20)
	once_b.pressed.connect(_once)
	_plain(once_b)
	loop_b = CheckButton.new()
	loop_b.text = w("连续轧制", "ROLL ON")
	loop_b.add_theme_font_size_override("font_size", 20)
	loop_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BenchFx.note(loop_b, w("开启后，只要仓库里还有钢坯，轧机就会按照当前配方持续生产；关闭后停止连续轧制", "On: it keeps rolling while there is billet; off: it stops"))
	loop_b.button_pressed = bool(Mill.cfg().loop)
	loop_b.toggled.connect(func(v):
		Mill.set_loop(v)
		message.text = w("已开启连续轧制。", "ROLLING ON while there is billet.") if v else w("已关闭连续轧制。", "ROLLING ON is off: it stops after this pass.")
		_refresh())
	# 炭黑 v3: a big key of its own, its lamp lit while it rolls on, the orange lip under it
	loop_b.custom_minimum_size.y = 84
	_plain(loop_b)
	var none := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	for ic in ["checked", "unchecked", "checked_disabled", "unchecked_disabled", "checked_mirrored", "unchecked_mirrored"]:
		loop_b.add_theme_icon_override(ic, none)
	loop_b.draw.connect(func():
		var on := loop_b.button_pressed
		Charcoal.led(loop_b, Vector2(loop_b.size.x - 24, 22), on, 1.0, 6.0)
		loop_b.draw_string(Fonts.get_font("Medium"), Vector2(loop_b.size.x - 74, loop_b.size.y - 16), w("开", "ON") if on else w("关", "OFF"), HORIZONTAL_ALIGNMENT_RIGHT, 60, 13, Charcoal.ACCENT if on else Pal.ink(0.5))
		if on:
			Charcoal.lip(loop_b, Rect2(14, loop_b.size.y - 6, loop_b.size.x - 28, 3)))
	row.add_child(loop_b)
	row.add_child(once_b)
	# 106 号: short of power — the reason and the way to the power control screen
	power_l = OpsSkin.label("", 16, 0.7)
	power_b = Button.new()
	power_b.text = w("前往动力区", "TO THE POWER DISTRICT")
	BenchFx.note(power_b, w("关闭轧机控制台，前往供电控制屏调整电力分配。", "Close the mill desk and go to the power control screen"))
	power_b.custom_minimum_size.y = 42
	_plain(power_b)
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
	Charcoal.style_button(more_key)
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
	Charcoal.style_button(close_b)
	Charcoal.key_text(close_b)
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
	# 炭黑 v2: no blue or green on the desk — running white, waiting / short orange, idle grey
	var ls := str(lamp[0])
	lamp_state = ls
	bar.col = Color(0.92, 0.93, 0.9) if ls == "run" else (Charcoal.ACCENT if ls in ["wait", "short"] else Pal.ink(0.45))
	var j := Mill.job()
	bar.text = (w("加工进度 %d%% · 预计还需 %d 秒", "%d%% · ~%d s LEFT") % [int(bar.k * 100.0), ceili(float(j.left) / maxf(0.05, Mill.k(game)))]) if not j.is_empty() and str(j.state) == "roll" else (w("正在等待钢坯送达", "WAITING") if not j.is_empty() else w("轧机已停止运行", "STOPPED"))
	lamp_label.text = "● " + str(lamp[1])
	lamp_label.add_theme_color_override("font_color", bar.col)
	rate_label.text = w("满功率时每分钟可轧制约 %.1f t · 当前每分钟轧制 %.1f t · 当前用电功率 %.0f MW", "%.1f t/min AT FULL POWER · %.1f NOW · %.0f MW") % [60.0 / Mill.ROLL_S * Mill.BATCH, Mill.rate(game), Mill.MW]
	var why := Mill.block(p)
	once_b.disabled = why != ""
	once_b.tooltip_text = why
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
		_plain(once_b)
		now_line.set_now(true, Grid.short_label(int(Mill.k(game) * 100.0)) + w("前往动力区", ": TO THE POWER DISTRICT"))
	elif why == "" and not Mill.busy():
		if not once_b.has_meta("cc_orange"):
			ConsoleKit.orange(once_b, 22)
			once_b.set_meta("cc_orange", true)
			once_b.remove_meta("cc_plain")
		once_b.text = w("加工一次（1 t）", "ONE PASS (1 t)")
		_plain(power_b)
		now_line.set_now(true, w("仓库现有 %.1f t 钢坯，轧机目前处于停止状态", "%.1f t OF BILLET IN STORE, THE MILL IDLE") % feed)
	else:
		_plain(once_b)
		once_b.text = w("加工一次（1 t）", "ONE PASS (1 t)")
		_plain(power_b)
		power_b.text = w("前往动力区", "TO THE POWER DISTRICT")
		if Mill.busy():
			now_line.set_now(false, (w("连续轧制已开启，当前正在轧制%s", "ROLLING ON: %s") if bool(c.loop) else w("当前正在轧制%s", "ROLLING %s")) % Mill.product_name(str(Mill.job().get("product", p))))
		else:
			now_line.set_now(false, why if why != "" else w("轧机已停止运行", "STOPPED"))
	view.queue_redraw()
	status_win.queue_redraw()
	loop_b.queue_redraw()
	for lb in [message, power_l, rate_label]:
		_fit_label(lb, 18 if lb == message else 16)


func _process(dt: float) -> void:
	ConsoleKit.card_fit(self)
	_t += dt
	bar.t = _t
	if Mill.busy():
		view.queue_redraw()
	if fmod(_t, 0.25) < dt:
		_refresh()


# a dark key (once): ConsoleKit's plain look gives way to the charcoal one; its words centred
func _plain(b: Button) -> void:
	if b.has_meta("cc_plain"):
		return
	ConsoleKit.plain(b, 20)
	Charcoal.style_button(b)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.set_meta("cc_plain", true)
	b.remove_meta("cc_orange")


# no lone character on a wrapped line's end (Charcoal.fit_width narrows the label a little)
func _fit_label(lb: Label, px: int) -> void:
	if lb == null or lb.text == "" or lb.get_parent() == null:
		return
	var avail: float = (lb.get_parent() as Control).size.x
	if avail <= 0.0:
		return
	var f: Font = lb.get_theme_font("font")
	lb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lb.custom_minimum_size.x = Charcoal.fit_width(f, lb.text, avail, px)


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
