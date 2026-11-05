extends Node2D
# 128 号 第 1 段 §五/§十二: the warehouse's first visit, after TUG-001 is settled. One card, one
# target mark (the stores counter in the berth), then the counter's page walks the first sale to the
# recycling station by the hand: the thing to sell lit, the button lit, one line saying what to do
# and why. After it, a last card says what happened and what to do from now on (F3 anywhere).
# While it runs it is the only voice (the main-line card and the port walk wait). Once per career;
# "关掉引导" ends it. Started by Game._store_guide().
#   step: fly (to the counter) → sell (the page open, sell one) → done_card (sold) → over

const GuideMark = preload("res://scripts/guide_mark.gd")
const END_S := 7.0
var game
var step := "fly"
var done := false
var t := 0.0
var step_t := 0.0
var _sold0 := 0
var _pick := ""
var _pick_name := ""
var layer: CanvasLayer
var card: PanelContainer
var count: Label
var title: Label
var body: Label
var close_b: Button


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ready() -> void:
	z_index = 30
	z_as_relative = false
	layer = CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	card = PanelContainer.new()
	card.custom_minimum_size = Vector2(640, 0)
	card.position = Vector2(get_viewport().get_visible_rect().size.x - 640 - 22, 124)
	card.add_theme_stylebox_override("panel", GuideMark.card_box(UiSkin.ACCENT))
	var col := VBoxContainer.new()
	card.add_child(col)
	var top := HBoxContainer.new()
	count = _label(13, Color(UiSkin.ACCENT, 0.85))
	count.custom_minimum_size.x = 0
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(count)
	close_b = Button.new()
	close_b.text = w("退出引导", "END THE GUIDE")
	close_b.focus_mode = Control.FOCUS_NONE
	close_b.pressed.connect(stop)
	top.add_child(close_b)
	col.add_child(top)
	title = _label(20, Pal.ink(0.96))
	body = _label(15, Pal.ink(0.75))
	col.add_child(title)
	col.add_child(body)
	layer.add_child(card)
	_sold0 = int(Career.data.get("recycled", {}).get("n", 0))
	_say()


func _label(size_px: int, c: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", c)
	# CJK has no spaces to break at: any character may end a line
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY if Txt.zh else TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 600
	return l


func _haul_text() -> String:
	var parts: Array = []
	var raw := 0.0
	var eq := 0
	var sp := 0
	for e in StoreBook.entries():
		match str(e.cat):
			"raw": raw += float(e.t)
			"equip": eq += 1
			"special": sp += 1
	if raw > 0.05:
		parts.append(w("原料 %.1f 吨", "%.1f t raw") % raw)
	if eq > 0:
		parts.append(w("设备 %d 件", "%d machines") % eq)
	if sp > 0:
		parts.append(w("特殊货 %d 件", "%d special") % sp)
	return w("、", ", ").join(parts)


func _say() -> void:
	match step:
		"fly":
			count.text = w("仓库 · 第 1 步 / 共 2 步", "STORES · STEP 1 OF 2")
			title.text = w("东西都进了仓库，飞去仓库柜台看看", "IT IS ALL IN THE STORES: FLY TO THE COUNTER AND LOOK")
			body.text = w("这一单拆下来的东西（%s）全部放进了公司仓库，还没换成钱。\n飞到亮着框的仓库柜台，按 %s 打开仓库。", "This job's haul (%s) is all in the company stores, not yet money.\nFly to the counter in the frame and press %s.") % [_haul_text(), Keys.label("use")]
		"sell":
			count.text = w("仓库 · 第 2 步 / 共 2 步", "STORES · STEP 2 OF 2")
			title.text = w("卖一件给回收站", "SELL ONE TO THE RECYCLING STATION")
			body.text = w("在仓库页里卖掉亮着的「%s」。", "Sell the lit %s on the stores page.") % _pick_name
		"done_card":
			count.text = w("仓库 · 完成", "STORES · DONE")
			title.text = w("卖掉了，现金已到账", "SOLD, AND PAID")
			body.text = w("码头边的吊车正把货吊走。\n以后拆完船，东西都会进仓库；在哪都能按 F3 打开仓库，卖给回收站或留着。", "The dock crane is lifting it away.\nFrom now on every haul goes into the stores; press F3 anywhere to sell or keep.")
	card.visible = step != "sell"


func _process(dt: float) -> void:
	if done or game == null:
		return
	t += dt
	step_t += dt
	var ui = game.console_ui
	var store_open: bool = ui != null and is_instance_valid(ui) and ui.get_script() == preload("res://scripts/company_store.gd")
	match step:
		"fly":
			if store_open:
				_go("sell")
		"sell":
			if not store_open:
				_go("fly")
			else:
				_light(ui)
				if int(Career.data.get("recycled", {}).get("n", 0)) > _sold0:
					ui.guide_id = ""
					ui.guide_btn = ""
					ui.guide_text = w("卖掉了，现金已到账。其余的先留着：修缮用得上，修好贸易港后还能卖到市价。以后按 F3 随时打开仓库。", "SOLD AND PAID. KEEP THE REST: REPAIRS NEED IT, AND THE TRADE PORT PAYS MARKET. F3 OPENS THE STORES ANYWHERE.")
					StoreBook.mark("store_guide_done")
					_go("done_card")
		"done_card":
			if store_open:
				step_t = 0.0
			elif step_t >= END_S:
				stop()
	queue_redraw()


func _go(s: String) -> void:
	step = s
	step_t = 0.0
	_say()


# the page: the thing to sell and the button lit, one line on top
func _light(ui) -> void:
	if _pick == "" or ui._item(_pick).is_empty():
		_pick = StoreBook.first_pick()
		var it: Dictionary = ui._item(_pick)
		_pick_name = str(it.get("name", ""))
		if not it.is_empty():
			ui.select(_pick)
			ui.open_kind(str(it.cat))
			ui.select(_pick)
		_say()
	ui.guide_id = _pick
	var on_it: bool = ui.sel == _pick or ui.sel != "" and ui.can_sell(ui._item(ui.sel))
	ui.guide_btn = "sell" if on_it else ""
	var price := Pal.money(float(ui._item(_pick).get("recycle", 0.0)))
	if ui._confirm != "":
		ui.guide_text = w("再按一次“卖给回收站”确认（防止按错）。", "PRESS 'SELL TO RECYCLING' AGAIN TO CONFIRM.")
	else:
		ui.guide_text = w("第 2 步：卖掉亮着的「%s」—— 按“卖给回收站 %s”。回收站什么都收，立刻付现金，是市价的 6 成。", "STEP 2: SELL THE LIT %s — 'SELL TO RECYCLING %s'. THE STATION TAKES ANYTHING, CASH AT ONCE, 60%% OF MARKET.") % [_pick_name, price]


func stop() -> void:
	if done:
		return
	done = true
	StoreBook.mark("store_guide_done")
	var ui = game.console_ui if game != null else null
	if ui != null and is_instance_valid(ui) and ui.get("guide_id") != null:
		ui.guide_id = ""
		ui.guide_btn = ""
		ui.guide_text = ""
	queue_free()


# the counter, for the mark
func target() -> Vector2:
	if done or step != "fly":
		return Vector2.INF
	return Consoles.rack_centre() + Vector2(0.2, 0.0) * Geom.M


# tests: E at the counter, as the use key does
func press_use() -> void:
	if game.consoles != null and game.consoles.near() == "rack":
		game.open_counter()


func _draw() -> void:
	if done or game == null:
		return
	var at := target()
	if at == Vector2.INF:
		return
	var z: float = maxf(game.cam_zoom(), 0.02)
	GuideMark.target(self, at, z, UiSkin.ACCENT, t, w("仓库柜台", "STORES COUNTER"), 30.0, 1.6 if step_t > 40.0 else 1.0)
	var d = game.drone
	if d != null:
		GuideMark.arrow(self, game.look.lamp_pos() if game.look != null else d.global_position, at, z, UiSkin.ACCENT, t)
