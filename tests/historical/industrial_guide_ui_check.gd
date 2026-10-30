extends "res://tests/g5_heat_ui_visual.gd"
# Native guide navigation and persistence; starting facilities/cash are fixtures.
func run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Career.path = "user://zp_test_industrial_guide_career.json"
	SaveGame.path = "user://zp_test_industrial_guide_field.json"
	SaveGame.allow_test = true
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.market = true
	Career.data.money = 100000.0
	Career.data.port = {"trade":1,"process":1}
	Txt.zh = true
	await spawn()
	g.bot.industrial_guide = true
	for size in [Vector2i(1280,720),Vector2i(1600,900)]:
		root.content_scale_size = size
		root.size = size
		Career.data.industrial_guide_seen = false
		Career.data.industrial_guide_version = 0
		g.open_exchange()
		await frames(8)
		var panel = g.console_ui
		check(panel.guide.visible and panel.guide_close.get_global_rect().end.x <= size.x,"first market visit opens a readable dismissible guide at "+str(size))
		var before: float = Career.data.money
		var stock_before := JSON.stringify(Career.data.exchange.actors.company.stock)
		check(panel.guide_progress.text.contains("库存等级 1 炉料 0.000") and panel.guide_progress.text.contains("库存合格钢坯 0.000"),"guide reads actual empty warehouse rather than preset progress")
		await capture("industrial_guide_%dx%d" % [size.x,size.y])
		var copy = preload("res://scripts/onboarding_text.gd")
		check(copy.pages().size() == 8 and panel.guide_previous.disabled,"new guide starts with eight short pages and a disabled previous button")
		for page_index in 8:
			var page: Dictionary = copy.pages()[page_index]
			check(panel.guide_index == page_index and panel.guide_page_body.text == str(page.body[0]),"native guide displays the exact editable copy for "+str(page.id))
			if page_index == 2:
				check(panel.guide_page_body.text.contains("把仓库炉料送到炉口") and panel.guide_page_body.text.contains("按 E"),"furnace page explicitly explains where to go and how to bring purchased stock")
				await capture("industrial_guide_delivery_%dx%d" % [size.x,size.y])
			if page_index < 7: await mouse_click(panel.guide_next)
		check(panel.guide_next.disabled,"last page cannot advance beyond the real copy catalog")
		await mouse_click(panel.guide_buy)
		check(not panel.guide.visible and panel.item == "ferrous_scrap" and panel.grade == 1,"actual guide button takes player to usable grade 1 furnace feed listings")
		check(Career.data.industrial_guide_seen and Career.data.money == before and JSON.stringify(Career.data.exchange.actors.company.stock) == stock_before,"dismissing guidance remembers the visit without spending money or granting material")
		await mouse_click(find_button("生产入门"))
		check(panel.guide.visible,"production guide is reopenable through the real header button")
		await mouse_click(panel.guide_clients)
		var tabs: TabContainer = panel.find_children("*","TabContainer",true,false)[0]
		check(not panel.guide.visible and tabs.current_tab == 2,"guide navigates directly to actual industrial client demands")
		panel.open_guide()
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = true
		root.push_input(event)
		await frames(3)
		check(not panel.guide.visible and g.console_ui == panel,"Escape closes only the guide and keeps the market open")
		panel.open_guide()
		Career.data.industrial_guide_seen = false
		Career.data.industrial_guide_version = 0
		var original_path := Career.path
		Career.path = "user://missing_industrial_guide_directory/career.json"
		await mouse_click(panel.guide_close)
		check(not panel.guide.visible and not Career.data.industrial_guide_seen,"failed visit save never traps the player in the guide or claims it persisted")
		Career.path = original_path
		panel.open_guide()
		await mouse_click(panel.guide_close)
		await mouse_click(find_button("返回 [Esc]"))
		g.open_exchange()
		await frames(5)
		check(not g.console_ui.guide.visible,"remembered guide does not interrupt later market visits")
		await mouse_click(find_button("返回 [Esc]"))
	await release()
	print("INDUSTRIAL GUIDE UI %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
