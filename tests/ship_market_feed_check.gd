extends "res://tests/guide_check.gd"
# 133 号 (user 2026-11-10 "二手船市你可以做成无限的，和淘宝一样"): the hulk market scrolls on and on.
# Scrolled through 500 listings at a brisk pace (vsync off, so the time is the frame's own cost)
# the frames stay under 16.7 ms, a hard fling never stalls, no listing shows twice, only the cards near
# the screen exist and the save does not grow; a slot is the same ship every time; opening a deep
# one keeps it (and only a few opened ones are kept); a bought one leaves the feed; the size
# filters and the four orders work. Every card leads with the seller's headline. Shots: the top,
# deep down, a deep listing's window. Own test saves only.
#   tools/run_test.sh tests/ship_market_feed_check.gd --fixed-fps 60

const Face := preload("res://scripts/listing_face.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_ship_market_feed_career.json"
	SaveGame.path = "user://zp_test_ship_market_feed_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _save_size() -> int:
	Career.save()
	var f := FileAccess.open(Career.path, FileAccess.READ)
	return f.get_length() if f != null else -1


func _ids(ui) -> Array:
	return ui.feed_area.get_children().filter(func(c): return c.visible and str(c.get_meta("id", "")) != "").map(func(c): return str(c.get_meta("id")))


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 5000000.0
	Career.data.port = {"salvage": 1, "trade": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"starmap_tour": true}
	Career.data.offers = []
	Career.save()
	await _spawn()
	await _frames(60)
	# the same slot is the same ship, whenever it is drawn
	var f: Array = ShipMarket.feed(Shipping.day())
	var a := JSON.stringify(ShipMarket.feed_draft(f[7]))
	ShipMarket._drafts.clear()
	check(a == JSON.stringify(ShipMarket.feed_draft(f[7])) and str(ShipMarket.feed_draft(f[7]).offer.ship) == str(f[7].ship), "a feed slot is the same listing every time it is drawn")
	g.open_ship_market()
	await _frames(40)
	var ui = g.console_ui
	var before := _save_size()
	var kept_before: int = ShipMarket.data().listings.size()
	check(ui._items.size() > 1000, "far more than fifteen for sale (%d)" % ui._items.size())
	var cards: Array = ui.feed_area.get_children().filter(func(c): return c.visible)
	check(not cards.is_empty() and cards.all(func(c): return c.find_children("*", "Label", true, false).size() > 3), "the first screen is built")
	var heads := 0
	for c in cards:
		var l := ShipMarket.listing(str(c.get_meta("id")))
		if l.is_empty():
			l = ShipMarket._drafts.get(str(c.get_meta("id")), {})
		var h := str(Face.headline(l).text)
		if h != "" and c.find_children("*", "Label", true, false).any(func(x): return str(x.text) == h):
			heads += 1
	check(heads == cards.size(), "every card leads with the seller's headline (%d/%d)" % [heads, cards.size()])
	Cap.save(root, "res://tests/out/ship_market_feed_top_zh.png")
	# frame cost, not the display's pace: vsync off while timing (back on after)
	var vs := DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _frames(10)
	# the page standing still, for comparison
	var idle_t: Array = []
	var t0 := Time.get_ticks_usec()
	for i in 60:
		await process_frame
		var n0 := Time.get_ticks_usec()
		idle_t.append((n0 - t0) / 1000.0)
		t0 = n0
	idle_t.sort()
	print("standing still: p50 %.1f ms, p95 %.1f ms" % [idle_t[30], idle_t[57]])
	# scroll down through 500 listings, a flick's pace, timing every frame
	var seen := {}
	var dup := false
	var times: Array = []
	var most := 0
	var t := Time.get_ticks_usec()
	var guard := 0
	var last_built: int = ui.built
	var by_built := {}
	while seen.size() < 500 and guard < 3000:
		guard += 1
		ui._scroll.scroll_vertical += 40
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - t) / 1000.0)
		var nb: int = ui.built - last_built
		last_built = ui.built
		var key := mini(nb, 2)
		by_built[key] = by_built.get(key, []) + [[(now - t) / 1000.0, ui.step_us / 1000.0]]
		t = now
		most = maxi(most, ui.feed_area.get_child_count())
		for id in _ids(ui):
			seen[id] = true
	for i in ui._items.size():
		for k in range(i + 1, mini(i + 4, ui._items.size())):
			dup = dup or str(ui._items[i].id) == str(ui._items[k].id)
	var ids := {}
	for e in ui._items:
		dup = dup or ids.has(str(e.id))
		ids[str(e.id)] = true
	for k in by_built:
		var fr: Array = by_built[k]
		var sum_f := 0.0
		var sum_w := 0.0
		for e in fr:
			sum_f += e[0]
			sum_w += e[1]
		print("  frames building %d card(s): %d frames, mean %.1f ms, feed work %.1f ms" % [k, fr.size(), sum_f / fr.size(), sum_w / fr.size()])
	times.sort()
	var p95: float = times[int(times.size() * 0.95)]
	var p99: float = times[int(times.size() * 0.99)]
	var worst: float = times[-1]
	print("scrolled %d listings in %d frames: p95 %.1f ms, p99 %.1f ms, worst %.1f ms, at most %d cards alive" % [seen.size(), times.size(), p95, p99, worst, most])
	check(seen.size() >= 500, "scrolled through 500 listings (%d)" % seen.size())
	# on a quiet machine the frame itself must fit 60 FPS; when other programs load it (the page
	# standing still already over 10 ms) what scrolling adds over standing still is what is judged
	var still95: float = idle_t[57]
	if still95 <= 10.0:
		check(p95 <= 16.7 and p99 <= 22.0, "frames stay under 60 FPS's 16.7 ms while scrolling (p95 %.1f ms, p99 %.1f ms, worst %.1f ms)" % [p95, p99, worst])
	else:
		check(p95 - still95 <= 6.0, "machine busy (standing still p95 %.1f ms): scrolling adds %.1f ms at p95 (p95 %.1f ms, worst %.1f ms)" % [still95, p95 - still95, p95, worst])
	check(most <= 30, "only the cards near the screen exist (at most %d)" % most)
	check(not dup, "no listing twice on the page")
	# and a hard fling (3× that pace) for 150 frames: cards may come a moment late, frames must not stall
	var fl: Array = []
	t = Time.get_ticks_usec()
	for i in 150:
		ui._scroll.scroll_vertical += 120
		await process_frame
		var now2 := Time.get_ticks_usec()
		fl.append((now2 - t) / 1000.0)
		t = now2
	fl.sort()
	print("fling: p95 %.1f ms, worst %.1f ms" % [fl[int(fl.size() * 0.95)], fl[-1]])
	var fl95: float = fl[int(fl.size() * 0.95)]
	var busy: float = maxf(0.0, float(idle_t[57]) - 10.0)   # a loaded machine's own extra
	check(fl95 <= 25.0 + busy and fl[-1] <= 50.0 + busy, "a hard fling never stalls (p95 %.1f ms, worst %.1f ms%s)" % [fl95, fl[-1], (", machine busy +%.1f ms" % busy) if busy > 0.0 else ""])
	DisplayServer.window_set_vsync_mode(vs)
	var after := _save_size()
	check(after <= before + 64 and ShipMarket.data().listings.size() == kept_before, "scrolling does not grow the save (%d -> %d bytes)" % [before, after])
	await _frames(20)
	Cap.save(root, "res://tests/out/ship_market_feed_deep_zh.png")
	# a deep listing opened: checked, kept in the save, its window open
	var deep := ""
	for c in ui.feed_area.get_children():
		if c.visible and str(c.get_meta("id", "")).begins_with("SM-F") and not c.disabled:
			deep = str(c.get_meta("id"))
			break
	ui._open(deep)
	await _frames(8)
	var kept := ShipMarket.listing(deep)
	check(not kept.is_empty() and kept.has("feed") and ui.detail_win.visible, "a deep listing opened is kept and its window opens (%s)" % deep)
	var wt: Array = ui.detail_win.find_children("*", "Label", true, false).map(func(x): return str(x.text))
	check(wt.has("“%s”" % str(Face.headline(kept).text)) and wt.has("卖家描述"), "the window carries the seller's ad and sets the word against the checks")
	ShipMarket.inspect(deep, "structure")
	ShipMarket.inspect(deep, "systems")
	ui._detail()
	await _frames(6)
	Cap.save(root, "res://tests/out/ship_market_feed_detail_zh.png")
	var vd := Face.verdict(ShipMarket.listing(deep))
	check(not vd.is_empty(), "inspected, the window weighs the ad against what was found (%s)" % str(vd.get("text", "")))
	ui.detail_win.visible = false
	await _frames(3)
	# opening many only keeps the newest few
	var opened := 0
	for e in ui._items.slice(600, 640):
		if str(e.id).begins_with("SM-F") and ShipMarket.take(str(e.id)):
			opened += 1
	var idle: int = ShipMarket.data().listings.filter(func(l): return l.has("feed") and (l.inspected as Dictionary).is_empty()).size()
	check(idle <= ShipMarket.FEED_KEEP_VIEWED and ShipMarket.data().listings.filter(func(l): return not l.has("feed")).size() == 15, "of %d opened, at most %d idle ones are kept (%d); the fifteen stay" % [opened, ShipMarket.FEED_KEEP_VIEWED, idle])
	# bought: out of the feed
	var r := ShipMarket.buy(deep)
	await _frames(70)
	check(r.ok and not ui._items.any(func(e): return str(e.id) == deep) and not ShipMarket.feed(Shipping.day()).any(func(m): return str(m.id) == deep), "a bought listing leaves the feed")
	# the size filters scroll on too, and the orders
	ui._cat("mid")
	await _frames(10)
	check(ui._items.size() > 300 and ui._items.all(func(e): return ui._in_cat(str(e.ship))), "the mid filter is endless too (%d)" % ui._items.size())
	ui._cat("all")
	ui._sort("new")
	await _frames(10)
	var newest := true
	for i in range(1, 60):
		newest = newest and float(ui._items[i - 1].listed) >= float(ui._items[i].listed)
	check(newest, "newest first")
	ui._sort("near")
	await _frames(10)
	var near := true
	for i in range(1, 200):
		near = near and float(ui._items[i - 1].tow) <= float(ui._items[i].tow)
	check(near, "nearest first")
	ui._sort("price")
	var guard2 := 0
	while not ui._pool.is_empty() and guard2 < 600:
		guard2 += 1
		await process_frame
	await _frames(5)
	var cheap: bool = ui._items.size() > 100
	for i in range(1, ui._items.size()):
		cheap = cheap and float(ui._items[i - 1].price) <= float(ui._items[i].price)
	check(cheap, "cheapest first over the newest %d (%d frames to sort)" % [ui._items.size(), guard2])
	Cap.save(root, "res://tests/out/ship_market_feed_price_zh.png")
	ui.close()
	g.queue_free()
	await _frames(4)
	print("SHIP MARKET FEED %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
