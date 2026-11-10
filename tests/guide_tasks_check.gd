extends "res://tests/guide_check.gd"
# 27 号 (Q3/Q4): the guide's other tasks — berth repair, port works, the shuttle, buying on the
# exchange, the scrap switch — and the exchange's "guide me" key in place of the paged text.
#   godot --headless --path . --fixed-fps 60 -s tests/guide_tasks_check.gd


func _run() -> void:
	# 128 号 第 2 段: this tests the old exchange (order book, before the warehouse and the new trade hall):
	# the legacy switch, as the other pre-128 tests do
	StoreBook.ON = false
	HallMarket.ON = false
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.market = true
	Career.data.money = 5000000.0
	Career.data.port = {"trade": 1, "process": 1}
	Career.save()
	await _spawn()

	# berth repair: money enough, the repairs page with the right key lit
	g.guide.begin("repair")
	await _frames(12)
	var st: Dictionary = g.guide.step
	check(str(st.get("title", "")) != "" and (str(st.get("action", "")) in ["repair", "contracts"]), "repair: a step and where it leads (%s)" % st.get("title", ""))
	if str(st.get("action", "")) == "repair":
		g.guide.act()
		await _frames(12)
		check(g.console_ui != null and g.console_ui.tab == 1, "the card opens the berth repairs")
		await _frames(12)
		check(_lit(Txt.t("rp_fix_parts")) or _lit(Txt.t("rp_fix_cash")), "the repair key is lit")
		g.console_ui.close()
		await _frames(4)
	g.guide.stop()

	# port works
	g.guide.begin("build")
	await _frames(12)
	st = g.guide.step
	# 128 号 第 3 段: the districts are mended in parts (“一期/二期”, was “阶”)
	check(str(st.get("title", "")).find("期") >= 0, "port works: the next district stage (%s)" % st.get("title", ""))
	if str(st.get("action", "")).begins_with("build:"):
		g.guide.act()
		await _frames(12)
		check(g.console_ui != null and g.console_ui.tab == 5, "the card opens the port works page")
		g.console_ui.close()
		await _frames(4)
	g.guide.stop()

	# the shuttle
	g.guide.begin("transit")
	await _frames(12)
	# 123 号 (user 2026-11-04): the nearest stop, from the berth the salvage district's over its gate (was the hub's)
	var near_stop := Guide.nearest_stop(g)
	check(str(g.guide.step.get("title", "")).find("站") >= 0 and g.guide.step.target == Tram.station_at(near_stop), "shuttle: fly to the nearest stop, %s (%s)" % [near_stop, g.guide.step.get("title", "")])
	g.guide.stop()

	# buying
	g.guide.begin("trade")
	await _frames(12)
	check(str(g.guide.step.get("action", "")) == "exchange", "buying: the card opens the exchange")
	g.guide.act()
	await _frames(12)
	if g.console_ui != null and g.console_ui.has_method("close_guide"):
		g.console_ui.close_guide()
	await _frames(12)
	check(str(g.guide.step.get("title", "")).find("购买") >= 0 and _lit("购买"), "on the exchange: a seller's buy key is lit")
	var keys: Array = g.console_ui.find_children("*", "Button", true, false).map(func(b): return str(b.text))
	check(keys.has("带我做下一步") and not keys.has("生产入门"), "the exchange carries 'guide me' instead of the paged text")
	g.console_ui.close()
	await _frames(4)
	g.guide.stop()

	# the scrap switch
	g.guide.begin("retain")
	await _frames(12)
	check(str(g.guide.step.get("action", "")) == "contracts", "scrap switch: first take a job")
	g.guide.stop()
	g.queue_free()
	await _frames(4)
	print("GUIDE TASKS %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
