extends "res://tests/guide_check.gd"
# 135 号: the hulk market in the A-暗1 charcoal look, every key pressed with injected clicks (never
# the real mouse): the size filters and the orders light their lamp, 刷新 reads the page again, a
# card opens its window and the window's close key shuts it, 更多 unfolds, 回交易行 goes to the
# exchange and Esc comes back to the market, the back key closes it. Shots in Chinese and English
# (list, window) and each beside the old look (tests/out/135_before/). Own test saves only.
#   tools/run_test.sh tests/ship_market_click_check.gd --fixed-fps 60

var ui


func _initialize() -> void:
	Career.path = "user://zp_test_market_click_career.json"
	SaveGame.path = "user://zp_test_market_click_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _click(c: Control) -> void:
	var p := c.get_global_rect().get_center()
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	Input.parse_input_event(m)
	await process_frame
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = p
		e.global_position = p
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		Input.parse_input_event(e)
		await process_frame
	await _frames(8)


func _esc() -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_ESCAPE
		e.physical_keycode = KEY_ESCAPE
		e.pressed = down
		Input.parse_input_event(e)
		await process_frame
	await _frames(40)


func _key_named(root_c: Node, starts: String) -> Button:
	for b in root_c.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and str(b.text).begins_with(starts):
			return b
	return null


# the old shot and the new one side by side, halved
func _pair(name: String) -> void:
	var a := Image.load_from_file(ProjectSettings.globalize_path("res://tests/out/135_before/%s.png" % name))
	var b := Image.load_from_file(ProjectSettings.globalize_path("res://tests/out/135_%s.png" % name))
	if a == null or b == null:
		return
	a.resize(960, 540, Image.INTERPOLATE_LANCZOS)
	b.resize(960, 540, Image.INTERPOLATE_LANCZOS)
	var out := Image.create(1932, 540, false, a.get_format())
	out.fill(Color(0.3, 0.3, 0.3))
	out.blit_rect(a, Rect2i(0, 0, 960, 540), Vector2i(0, 0))
	out.blit_rect(b, Rect2i(0, 0, 960, 540), Vector2i(972, 0))
	out.save_png(ProjectSettings.globalize_path("res://tests/out/135_compare_%s.png" % name))


func _run() -> void:
	var was_motion := Txt.reduce_motion
	Txt.reduce_motion = true
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 900000.0
	Career.data.port = {"salvage": 1, "trade": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"starmap_tour": true}
	Career.data.offers = []
	Career.save()
	await _spawn()
	await _frames(60)
	var was_ex: bool = StoreBook.EXCHANGE_ON
	StoreBook.EXCHANGE_ON = true
	ShipMarket.refresh()
	for l in ShipMarket.data().listings:
		var life := float(l.expires) - float(l.listed)
		l.listed = float(l.listed) - life * randf_range(0.1, 0.8)
		l.expires = float(l.listed) + life
	g.open_ship_market()
	await _frames(60)
	ui = g.console_ui
	# the size filters
	for k in ["small", "mid", "large", "mine", "all"]:
		await _click(ui.cat_keys[k])
		check(ui.cat == k, "the %s key filters (%s)" % [k, ui.cat])
	# the orders
	for k in ["new", "near", "mix"]:
		await _click(ui.sort_keys[k])
		check(ui.sort == k, "the %s order key orders (%s)" % [k, ui.sort])
	await _click(ui.new_btn)
	check(ui._snap >= 0.0 and ui._items.size() > 100, "刷新 reads the page again")
	await _frames(30)
	Cap.save(root, "res://tests/out/135_market_list_zh.png")
	# a card, its window, 更多, the close key
	var card: Button = null
	for c in ui.feed_area.get_children():
		if c.visible and not c.disabled and c.get_global_rect().end.y < 1000.0:
			card = c
			break
	await _click(card)
	check(ui.detail_win.visible, "a card opens its window (%s)" % str(card.get_meta("id", "")))
	var more := _key_named(ui.detail_win, "更多")
	await _click(more)
	check(ui.more_box.visible, "更多 unfolds")
	await _frames(10)
	Cap.save(root, "res://tests/out/135_market_detail_zh.png")
	var shut := _key_named(ui.detail_win, "关闭")
	await _click(shut)
	check(not ui.detail_win.visible, "the window's close key shuts it")
	# 回交易行 and back
	await _click(_key_named(ui, "回交易行"))
	await _frames(40)
	var ex_page: String = "" if g.console_ui == null else str(g.console_ui.get_script().resource_path).get_file()
	check(ex_page in ["hall_panel.gd", "exchange_panel.gd"], "回交易行 opens the exchange (%s)" % ex_page)
	await _esc()
	ui = g.console_ui
	check(ui != null and str(ui.get_script().resource_path).ends_with("ship_market_panel.gd"), "Esc there comes back to the market")
	await _frames(30)
	# English
	Txt.zh = false
	ui.close()
	await _frames(10)
	g.open_ship_market()
	await _frames(60)
	ui = g.console_ui
	Cap.save(root, "res://tests/out/135_market_list_en.png")
	ui.chosen = str(ShipMarket.data().listings[2].id)
	ui._detail()
	await _frames(10)
	Cap.save(root, "res://tests/out/135_market_detail_en.png")
	ui.detail_win.visible = false
	Txt.zh = true
	# the back key closes it (opened from the site)
	ui.close()
	await _frames(10)
	g.open_ship_market()
	await _frames(40)
	ui = g.console_ui
	await _click(_key_named(ui, "关闭"))
	check(g.console_ui == null, "the back key closes the market opened from the site")
	for n in ["market_list_zh", "market_detail_zh", "market_list_en", "market_detail_en"]:
		_pair(n)
	StoreBook.EXCHANGE_ON = was_ex
	Txt.reduce_motion = was_motion
	g.queue_free()
	await _frames(4)
	print("MARKET CLICK %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
