extends "res://tests/guide_check.gd"
# 134 号 (user 2026-11-10: "从哪里进入，就开始从哪里返回的。你检查一下还有没有这样的 bug"): every
# full-screen page goes back where it was opened from. For each way in (the find-ships page, the
# star map, the exchange, a district console, the stores, the queue, the furnace, the mill, the
# power screen, the racks), the page is left for another the way its key does it, a real Esc is
# pressed, and the page it came from must be open again as it was (its tab, its filter, its
# scroll); a second Esc goes on back or away; a page opened from the site closes to the site; the
# back key names where it goes. Shots of the market and the exchange showing their way back.
# Own test saves only; keys are injected into the game, the real mouse is never touched.
#   tools/run_test.sh tests/back_trail_check.gd --fixed-fps 60

const Back := preload("res://scripts/ui_back.gd")
var rows: Array = []     # the report table: way in -> page -> back to


func _initialize() -> void:
	Career.path = "user://zp_test_back_trail_career.json"
	SaveGame.path = "user://zp_test_back_trail_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


# the page open now, by its script's name ("" for none)
func _page() -> String:
	var ui = g.console_ui
	if ui == null or not is_instance_valid(ui):
		return ""
	return str(ui.get_script().resource_path).get_file().get_basename()


func _esc() -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_ESCAPE
		e.physical_keycode = KEY_ESCAPE
		e.pressed = down
		Input.parse_input_event(e)
		await process_frame
	await _frames(45)


func _shut() -> void:
	# away to the site, whatever is open, the trail forgotten
	for i in 6:
		if _page() == "":
			break
		await _esc()
	Back.reset()
	await _frames(10)


# one way in: open the first page fresh, leave it for the second the way its key does, then Esc
func _trip(name: String, open_from: Callable, leave: Callable, from_page: String, to_page: String, same: Callable = Callable()) -> void:
	await _shut()
	open_from.call()
	await _frames(40)
	if _page() != from_page:
		check(false, "%s: %s opens (got %s)" % [name, from_page, _page()])
		rows.append([name, to_page, "未能打开起点", "-"])
		return
	leave.call(g.console_ui)
	await _frames(60)
	var reached := _page()
	var label := Back.label()
	var key_text := ""
	if g.console_ui != null:
		for b in g.console_ui.find_children("*", "Button", true, false):
			if str(b.text).contains("[Esc]") and b.is_visible_in_tree():
				key_text = str(b.text)
	await _esc()
	var back_to := _page()
	var ok := reached == to_page and back_to == from_page and (same.is_null() or bool(same.call(g.console_ui)))
	check(ok, "%s: %s → %s, Esc → %s (back key \"%s\", trail \"%s\")" % [name, from_page, reached, back_to, key_text, label])
	rows.append([name, to_page, back_to if back_to != "" else "现场"])
	# and from where it came from, Esc goes on (away, as that page was opened from the site)
	await _esc()
	check(_page() == "" or from_page == "terminal", "%s: a second Esc leaves %s for the site (%s)" % [name, from_page, _page()])


func _run() -> void:
	var was_motion := Txt.reduce_motion
	Txt.zh = true
	Txt.reduce_motion = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.offers = []
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true, "starmap_tour": true}
	Career.data.money = 900000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1, "tug": 1}
	Career.save()
	await _spawn()
	await _frames(60)
	var was_ex: bool = StoreBook.EXCHANGE_ON
	StoreBook.EXCHANGE_ON = true
	# a hulk bought and under tow: the find-ships page has something on it (an empty one goes
	# straight to the star map's sweep, by design)
	ShipMarket.refresh()
	for l in ShipMarket.data().listings:
		if ShipMarket.fits(l) and ShipMarket.buy(str(l.id)).ok:
			break
	# …and kept on its way for the whole test (its arrival scene would hold every page shut)
	for a in ShipMarket.data().assets:
		if str(a.state) == "towing":
			a.run.depart = Shipping.day() + 1.0e6
	check(not ShipMarket.on_the_way().is_empty(), "a hulk is on its way home (the find-ships page is not empty)")

	# --- the user's case: the terminal's find-ships page -> the hulk market -> Esc
	await _shut()
	g.open_console("terminal")
	await _frames(30)
	var term = g.console_ui
	term._skip_boot()
	term.set_tab(0)
	await _frames(20)
	term = g.console_ui
	var on_find: bool = _page() == "terminal" and term.tab == 0
	check(on_find, "the terminal is on its find-ships page (%s, tab %s)" % [_page(), str(term.tab) if on_find else "-"])
	if not on_find:
		quit(1)
		return
	# the page's own way to the market (its 二手船市 key under Find ships)
	term._go_page("ship_market", func(): g.open_ship_market())
	await _frames(60)
	var mk = g.console_ui
	var keys: Array = mk.find_children("*", "Button", true, false).map(func(b): return str(b.text)) if mk != null else []
	check(_page() == "ship_market_panel" and keys.has("返回找船 [Esc]"), "the market from Find ships: its back key says 返回找船 (%s)" % str(keys.slice(0, 4)))
	Cap.save(root, "res://tests/out/back_trail_market_from_find_zh.png")
	await _esc()
	check(_page() == "terminal" and g.console_ui.tab == 0, "Esc in the market: back on the terminal's find-ships page (%s, tab %s)" % [_page(), str(g.console_ui.tab) if g.console_ui != null else "-"])
	rows.append(["船坞终端·找船页 → 二手船市", "ship_market_panel", _page() + (" (tab %d)" % g.console_ui.tab if g.console_ui != null else "")])
	Cap.save(root, "res://tests/out/back_trail_back_on_find_zh.png")

	# --- the market keeps its filter, order and scroll through a trip to the exchange
	await _shut()
	g.open_ship_market()
	await _frames(40)
	var m = g.console_ui
	m._cat("small")
	m._sort("new")
	await _frames(10)
	m._scroll.scroll_vertical = 2400
	await _frames(20)
	var sv: int = m._scroll.scroll_vertical
	var first := str(m._items[0].id) if not m._items.is_empty() else ""
	m._to_exchange()
	await _frames(60)
	var ex_page := _page()
	var ex_keys: Array = g.console_ui.find_children("*", "Button", true, false).map(func(b): return str(b.text)) if g.console_ui != null else []
	Cap.save(root, "res://tests/out/back_trail_exchange_from_market_zh.png")
	await _esc()
	await _frames(30)
	m = g.console_ui
	var kept: bool = _page() == "ship_market_panel" and m.cat == "small" and m.sort == "new" and absi(m._scroll.scroll_vertical - sv) <= 2 and not m._items.is_empty() and str(m._items[0].id) == first
	check(kept, "market → %s → Esc: the market again, on 小型 · 刚上架 at the same scroll (%s %s %s / %d)" % [ex_page, _page(), m.cat if m != null else "-", m.sort if m != null else "-", m._scroll.scroll_vertical if m != null else -1])
	rows.append(["二手船市（小型·刚上架·滚到中间）→ 回交易行", ex_page, _page() + " · 筛选/排序/滚动已恢复" if kept else _page()])
	# the market opened from the site: Esc closes it to the site
	await _esc()
	check(_page() == "", "the market opened from the site: Esc closes it (%s)" % _page())
	print("exchange keys: %s" % str(ex_keys))

	# --- every other way in
	await _trip("星图·找船 → 二手船市", func(): g.open_star_map("find"), func(ui): ui._open_hulk_market(), "star_map", "ship_market_panel",
		func(ui): return ui.mode == "find")
	await _trip("船坞终端·首页 → 星图", func():
		g.open_console("terminal")
		g.console_ui._skip_boot(), func(ui): ui.ops_go("starmap"), "terminal", "star_map")
	await _trip("船坞终端 → 交易行（F8）", func():
		g.open_console("terminal")
		g.console_ui._skip_boot(), func(ui): ui.open_exchange(), "terminal", _ex_page())
	await _trip("动力区操作台 → 供电控制屏", func(): g.open_district("power"), func(ui): ui._then(func(): g.open_power_screen(), "power"), "district_panel", "power_panel",
		func(ui): return ui.zone == "power")
	await _trip("贸易区操作台 → 交易行", func(): g.open_district("trade"), func(ui): ui._then(func(): g.open_exchange(), "exchange"), "district_panel", _ex_page(),
		func(ui): return ui.zone == "trade")
	await _trip("拆船区操作台 → 船坞终端", func(): g.open_district("salvage"), func(ui): ui._then(func(): g.open_console("terminal"), "terminal"), "district_panel", "terminal",
		func(ui): return ui.zone == "salvage")
	await _trip("供电控制屏 → 动力区操作台", func(): g.open_power_screen(), func(ui): ui._leave("district:power", func(): g.open_district("power")), "power_panel", "district_panel")
	await _trip("仓库（F3）→ 交易行", func(): g.open_store("raw"), func(ui): ui._to_hall("sell", ""), "company_store", _ex_page(),
		func(ui): return str(ui.kind) == "raw")
	await _trip("仓库 → 加工队列", func(): g.open_store(), func(ui):
		ui._queue_link_t = 5.0
		ui._press("queue_link"), "company_store", "process_queue_panel")
	await _trip("加工队列 → 仓库", func(): g.open_queue_panel(), func(ui): ui._to_store(), "process_queue_panel", "company_store")
	await _trip("轧机控制台 → 供电控制屏", func(): g.open_mill(), func(ui): ui._leave("power", func(): g.open_power_screen()), "mill_panel", "power_panel")
	await _trip("货架 → 零件架", func(): g.open_shelf("A"), func(ui): ui._leave("rack", func(): g.open_parts_rack()), "shelf_panel", "parts_rack_panel")
	if g.industrial_heat != null:
		g.drone.global_position = g.industrial_heat.site()
		g.drone.freeze = true
		await _frames(30)
		await _trip("熔炉操作台 → 供电控制屏", func(): g.open_heat(), func(ui): ui._leave("power", func(): g.open_power_screen()), "heat_panel", "power_panel")
		g.drone.freeze = false

	# --- a chain: Find ships -> market -> exchange, then Esc twice comes back the same way
	await _shut()
	g.open_console("terminal")
	await _frames(30)
	g.console_ui._skip_boot()
	g.console_ui.set_tab(0)
	await _frames(10)
	g.console_ui._go_page("ship_market", func(): g.open_ship_market())
	await _frames(60)
	g.console_ui._to_exchange()
	await _frames(60)
	var c1 := _page()
	await _esc()
	var c2 := _page()
	await _esc()
	var c3 := _page()
	check(c2 == "ship_market_panel" and c3 == "terminal" and g.console_ui.tab == 0, "Find ships → market → %s: Esc, Esc → %s → %s (tab 0)" % [c1, c2, c3])
	rows.append(["找船页 → 二手船市 → 交易行（连走两步）", c1, "%s → %s" % [c2, c3]])

	# --- a page from the site after a trail: a fresh start, Esc to the site
	await _shut()
	g.open_star_map("find")
	await _frames(40)
	g.console_ui._open_hulk_market()
	await _frames(60)
	# the market is shut from the site side (as a guide card would), then the stores opened by F3
	g.console_ui.close()
	await _frames(120)
	g.open_store()
	await _frames(40)
	check(not Back.has_back(), "a page opened from the site after a trail starts fresh (trail %d)" % Back.stack.size())
	await _esc()
	check(_page() == "", "…and Esc closes it to the site (%s)" % _page())

	StoreBook.EXCHANGE_ON = was_ex
	Txt.reduce_motion = was_motion
	print("TRAIL TABLE")
	for r in rows:
		print("  %s | %s | %s" % r)
	g.queue_free()
	await _frames(4)
	print("BACK TRAIL %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)


func _ex_page() -> String:
	return "hall_panel" if StoreBook.live() else "exchange_panel"
