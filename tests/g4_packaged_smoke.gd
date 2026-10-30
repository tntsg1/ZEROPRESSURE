extends SceneTree
# External controller with --main-pack pointing at the exported EXE, from
# build/. Standalone release startup is checked separately without -s.
# Private career and declared review receipt; physical routes have separate gates.
const Orders = preload("res://scripts/work_orders.gd")
var checks := 0
var fails := 0
func _initialize() -> void: _run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE]))
	var screen := DisplayServer.screen_get_usable_rect()
	DisplayServer.window_set_position(screen.position+screen.size-Vector2i(24,24))
	DisplayServer.window_set_size(Vector2i(1280,720))
	Career.path = "user://zp_test_g4_packaged_smoke_career.json"
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.done = 3
	Career.data.money = 50000.0
	Career.data.active = {}
	Career.data.story_job = {}
	Career.save()
	SaveGame.allow_test = false
	SaveGame.load_requested = false
	check(FileAccess.file_exists("res://project.binary") and not FileAccess.file_exists("res://project.godot"),"controller uses the exported binary project rather than the loose source project")
	check(not ResourceLoader.exists("res://tests/g4_heavy_field.gd"),"test fixtures are excluded from the shipped resource pack")
	check(FileAccess.file_exists("res://data/workplans/gr7_roof.json") and FileAccess.get_sha256("res://data/workplans/gr7_roof.json") == FileAccess.get_sha256("E:/godot/zeropower/data/workplans/gr7_roof.json"),"packaged factory cutting plan matches the verified source data")
	var title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await frames(12)
	check(is_instance_valid(title) and title.is_inside_tree(),"packaged title scene starts in the native renderer")
	title.queue_free()
	await frames(5)
	var reason := Orders.take("access")
	check(reason == "","packaged engineering entry can sign its real directed source: "+reason)
	Game.contract = Career.active()
	Game.start_ship = "gr7"
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	await frames(12)
	g.tutorial = null
	check(g.work_order.id == "access" and g.world.key_piece("C-03") != null,"packaged field creates the commission and its actual ship target")
	g.open_plan_panel()
	await frames(6)
	check(g.console_ui != null and paused and g.plan.packages.catalogue.size() >= 2,"packaged P panel loads factory safety and cutting packages")
	if g.console_ui != null: g.console_ui.on_close.call()
	await frames(3)
	g.work_order.receipts = [{"keys":["C-03"],"value":1000.0,"assembled":false,"source":g.job.id}]
	g.finish_contract(true)
	await frames(6)
	check(g.order_review != null and paused and not g.ended,"packaged engineering review opens before committing its declared receipt")
	if g.order_review != null:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("E:/godot/zeropower/proofs/g4_candidate_review.png")
		g.order_review.back_button.pressed.emit()
	await frames(3)
	check(not paused and not g.ended and not Orders.done("access"),"packaged review returns to the job without awarding an uncommitted fixture")
	g.queue_free()
	await frames(5)
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G4 PACKAGED SMOKE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
