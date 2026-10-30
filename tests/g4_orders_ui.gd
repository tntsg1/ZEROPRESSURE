extends SceneTree
const Orders = preload("res://scripts/work_orders.gd")
var checks := 0
var fails := 0
var terminal: Node
func _initialize() -> void: _run.call_deferred()
func frames(n: int) -> void:
	for k in n: await process_frame
func check(ok: bool,what: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",what])
func _run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Career.path = "user://zp_test_g4_order_ui_career.json"
	SaveGame.path = "user://zp_test_g4_order_ui_field.json"
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.market = true
	Career.data.done = 10
	Career.data.money = 100000.0
	Career.data.upgrades = {"lights":1}
	Career.data.work_orders = {"done":{"access":{"job":"ui-fixture"},"rigging":{"job":"ui-fixture"}}}
	Career.save()
	for language in [true,false]:
		Txt.zh = language
		for size in [Vector2i(1280,720),Vector2i(1920,1080)]:
			DisplayServer.window_set_size(size)
			terminal = load("res://scenes/terminal.tscn").instantiate()
			root.add_child(terminal)
			await frames(5)
			terminal.set_tab(5)
			terminal.route_panel.select_key("order:heavy")
			await frames(40)
			var page = terminal.route_panel
			check(page.category == 4 and page.entries.size() == 3,"all three engineering orders appear in the actual growth terminal")
			check(page.chosen().id == "heavy" and page.action_button != null and not page.action_button.disabled,"the heavy delivery has a usable live acceptance control")
			check(page.get_global_rect().encloses(page.categories.get_global_rect()),"the category rail fits the %s layout" % size)
			page.action_button.grab_focus()
			await frames(4)
			check(page.detail_scroll.get_global_rect().encloses(page.action_button.get_global_rect()),"keyboard focus scrolls the acceptance action fully into view")
			if "--capture" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				preload("res://tests/cap.gd").save(root,"res://proofs/g4_orders_%s_%d.png" % ["zh" if language else "en",size.x])
			terminal.queue_free()
			await frames(4)
	# Exercise the actual acceptance button, not only the static take API.
	Career.data.work_orders.done = {}
	Career.data.active = {}
	Career.save()
	terminal = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(terminal)
	await frames(5)
	terminal.set_tab(5)
	terminal.route_panel.select_key("order:access")
	terminal.route_panel.action_button.pressed.emit()
	check(Career.active().get("work_order","") == "access","the real terminal button signs a directed engineering source")
	check(Game.contract.get("work_order","") == "access" and Game.start_ship == "gr7","the accepted order enters the existing departure/loadout flow")
	terminal.queue_free()
	await frames(4)
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G4 ORDERS UI %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
