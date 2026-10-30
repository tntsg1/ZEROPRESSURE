extends "res://tests/g5_heat_ui_visual.gd"
# Real training scene/dev actions and native UI mouse input. Measurement is a
# declared direct tool-command check; full controls are covered by tutorial_bot.
func frames(n: int) -> void:
	for i in n: await process_frame

func run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Career.path = "user://zp_test_training_probe_card_career.json"
	SaveGame.train_path = "user://zp_test_training_probe_card_field.json"
	SaveGame.allow_test = true
	Txt.cfg_path = "user://zp_test_training_probe_card_settings.cfg"
	Career.data = Career.fresh()
	Career.data.money = 0.0
	Career.data.fitted = {}
	Game.contract = {}
	Game.start_ship = "ts1"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO,"consum":true,"codex":true}
	root.add_child(g)
	await frames(8)
	var dev: DevPanel
	for child in g.get_children():
		if child is DevPanel: dev = child
	Txt.dev = true
	check(g.training and not g.career() and Consum.ready(g,"probe"),"fresh zero-money training supplies a working probe without a fitted career part")
	dev.tune_skills(3,false)
	dev.run(7)
	check(not g.job.is_empty() and not g.career(),"actual developer skill/item changes do not turn TS1 into a paid career contract")
	var career_before := JSON.stringify(Career.data)
	for tool in Consum.TOOLS:
		check(Consum.ready(g,tool) and Consum.use(g,tool,100000.0) and not Consum.fails(g,tool),"training supplies and does not consume or randomly fail "+tool)
	var cover = g.world.tag("P-001")
	g.do_measure({"kind":"inspect","piece":cover,"pos":Geom.centroid(g.world.world_poly(cover))})
	check(not g.sys.readings.is_empty() and JSON.stringify(Career.data) == career_before,"real cover inspection produces readings without purchasing or consuming career material")
	for size in [Vector2i(1280,720),Vector2i(1600,900)]:
		root.content_scale_size = size
		root.size = size
		var tutorial_hud: TutorialHud
		for child in g.get_children():
			if child is TutorialHud: tutorial_hud = child
		var original_step: Array = [g.tutorial.lesson_i,g.tutorial.step_i]
		await mouse_click(tutorial_hud.overview_button)
		check(paused and g.console_ui != null and g.console_ui.picker.item_count == 10,"native tutorial overview opens all basic/specialist/market/assessment sections at "+str(size))
		var overview = g.console_ui
		for index in 10:
			overview.picker.select(index)
			overview.refresh()
			check(overview.content.get_child_count() > 0,"actual tutorial overview section contains sourced instructions: "+str(index))
		await capture("tutorial_overview_%dx%d" % [size.x,size.y])
		await mouse_click(find_button("返回训练 [Esc]"))
		check(not paused and g.console_ui == null and [g.tutorial.lesson_i,g.tutorial.step_i] == original_step,"closing overview resumes the same lesson without granting completion")
		g.codex.queue.clear()
		g.codex.card = "cable"
		g.codex.card_t = 0.0
		await frames(35)
		check(g.codex_hud.close_button.visible and g.codex_hud.close_button.size.x >= 36,"first-meeting card has a native generous dismiss target at "+str(size))
		await capture("training_card_%dx%d" % [size.x,size.y])
		await mouse_click(g.codex_hud.close_button)
		check(g.codex.card == "" and g.codex_hud.page == null,"native mouse X dismisses the card without opening the book")
		await frames(25)
		check(not g.codex_hud.close_button.visible,"dismissed hint cannot remain as an invisible input blocker")
	# Latest user decision: normal contracts also no longer require parts.
	g.training = false
	g.ship = {"id":"fixture_contract"}
	g.job = {"id":"EXHAUSTED-PROBE-FIXTURE","consum":{"probe":{"tier":1,"left":0.0}}}
	check(g.career() and Consum.ready(g,"probe"),"normal contract ignores legacy exhausted probe after tool-part retirement")
	g.ship = {"id":"fixture_exam","exam":{}}
	check(not g.career() and Consum.ready(g,"probe"),"assessment rig also remains supplied despite residual job data")
	g.training = true
	await release()
	print("TRAINING PROBE / CARD UI %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
