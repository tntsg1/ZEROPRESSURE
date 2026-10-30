extends SceneTree
var g: Node
var checks := 0
var fails := 0
func _initialize() -> void: _run.call_deferred()
func frames(n: int) -> void:
	for k in n: await process_frame
func check(ok: bool,text: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",text])
func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	preload("res://tests/cap.gd").save(root,path)
func _run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Career.path = "user://zp_test_g4_ui_career.json"
	Career.data = Career.fresh()
	Career.save()
	SaveGame.path = "user://zp_test_g4_ui_save.json"
	Game.start_ship = "gr7"
	Game.contract = {"id":"G4-UI","ship":"gr7","fee":0,"kit":{}}
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	await frames(8)
	g.tutorial = null
	for language in [true,false]:
		Txt.zh = language
		for size in [Vector2i(1280,720),Vector2i(1920,1080)]:
			DisplayServer.window_set_size(size)
			await frames(5)
			g.open_plan_panel()
			await frames(5)
			var panel = g.console_ui
			check(panel != null,"real GR-7 authorization UI opens at %s / %s" % [size,"ZH" if language else "EN"])
			if panel == null: continue
			panel.choose_with_dependencies("gr7:roof:access",true)
			check(panel.checks["preset:gr7:preparation"].button_pressed and not panel.authorize_button.disabled,"selecting the skin package includes its required safe preparation")
			var bounds: Rect2 = panel.get_global_rect()
			check(bounds.encloses(panel.authorize_button.get_global_rect()),"the primary action remains inside the viewport")
			check(bounds.encloses(panel.notice.get_global_rect()),"the instructions remain visible at the smaller layout")
			if "--capture" in OS.get_cmdline_user_args():
				await capture("res://proofs/g4_plan_%s_%d.png" % ["zh" if language else "en",size.x])
			panel.choose_with_dependencies("preset:gr7:preparation",false)
			check(not panel.checks["gr7:roof:access"].button_pressed,"deselecting a prerequisite also deselects its dependent work")
			panel.close()
			await frames(3)
	g.open_plan_panel()
	await frames(3)
	var at: Vector2 = g.world.frame(g.world.key_piece("p7")) * Geom.centroid(g.world.key_piece("p7").poly)
	g.console_ui.locate("p7")
	g.bot.lmb = true
	g._read_input()
	check(not g.tools.lmb and not g.tools.lmb_pressed,"the preview-closing click cannot fire the laser through the UI")
	g.bot.lmb = false
	g._read_input()
	check(not g.modal_release,"releasing the click restores normal tool input")
	await frames(60)
	check(g.plan_focus != null and g.cam_pos.distance_to(at) < 35.0,"local inspection smoothly reaches the target without whole-ship framing")
	g.bot.move = Vector2.RIGHT
	await frames(3)
	check(g.plan_focus == null,"pilot input immediately takes back camera control")
	g.queue_free()
	await frames(5)
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G4 PLAN UI %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
