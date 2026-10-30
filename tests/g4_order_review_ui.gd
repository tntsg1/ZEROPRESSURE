extends SceneTree
# Declared receipts isolate UI/transaction behavior. Physical delivery is
# separately proven by g4_access_field, g4_rigging_field and g4_heavy_field.
const Orders = preload("res://scripts/work_orders.gd")
var g: Node
var checks := 0
var fails := 0
var serial := 0
func _initialize() -> void: _run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
func same_economy(before: String) -> bool:
	var previous: Dictionary = JSON.parse_string(before)
	for key in ["money","loan","gear","work_orders","upgrades","settled_jobs","repairs","parts","structure_t","plans","plan_books"]:
		if previous.get(key) != Career.data.get(key): return false
	return true
func click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		root.push_input(event,true)
		await frames(2)
func key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event,true)
		await frames(2)
func spawn() -> void:
	serial += 1
	Career.path = "user://zp_test_g4_review_career.json"
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.done = 3
	Career.data.loan = 0.0
	Career.data.money = 100000.0
	Career.data.work_orders = {"done":{"access":{},"rigging":{}},"stock":{"heavy":[{"keys":["CP-E"],"value":1500.0,"assembled":false,"source":"prior-fixture"}]}}
	var job := {"id":"REVIEW-FIXTURE-%d" % serial,"ship":"pod","work_order":"heavy","order_reward":"buffer","fee":0,"kit":{},"time":1800}
	Career.data.active = job.duplicate(true)
	Career.save()
	Game.start_ship = "pod"
	Game.contract = job
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	await frames(8)
	g.tutorial = null
	g.income_equip = 6000.0
	g.work_order.receipts = [{"keys":["CP-E","RAD","K4"],"value":6000.0,"assembled":true,"stable":false,"source":job.id}]
func dispose() -> void:
	paused = false
	g.queue_free()
	await frames(5)
func _run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	SaveGame.allow_test = false
	SaveGame.load_requested = false
	for language in [true,false]:
		for size in [Vector2i(1280,720),Vector2i(1920,1080)]:
			await spawn()
			Txt.zh = language
			DisplayServer.window_set_size(size)
			await frames(6)
			var before := JSON.stringify(Career.data)
			var clock_before: float = g.playtime
			g.finish_contract(true)
			await frames(6)
			var panel = g.order_review
			check(panel != null and paused and not g.ended,"pre-commit review opens at %s / %s and pauses the real field" % [size,"ZH" if language else "EN"])
			if panel == null:
				await dispose()
				continue
			var bounds: Rect2 = panel.get_global_rect()
			check(bounds.encloses(panel.card.get_global_rect()) and panel.card.get_global_rect().encloses(panel.confirm_button.get_global_rect()),"review card and confirmation fit the viewport")
			check(panel.reserve_button.button_pressed and panel.cash_label.text.contains(Pal.money(1500.0)) and panel.fee_label.text.contains(Pal.money(0.0)),"reservation preview shows the actual surplus return and whole-module assembly waiver")
			check(panel.outcome_label.text.contains(Repair.name_of("buffer")) and panel.outcome_label.text.contains(Repair.desc_of("buffer")),"review names the actual selected facility and its immediately usable effect")
			if "--capture" in OS.get_cmdline_user_args() and language and size.x == 1280:
				await RenderingServer.frame_post_draw
				preload("res://tests/cap.gd").save(root,"res://proofs/g4_review_reserve_1280.png")
			g.work_order.receipts = [{"keys":["RAD"],"value":6000.0,"assembled":false,"source":"separate-fixture"}]
			panel.select_sale(false)
			check(panel.fee_label.text.contains(Pal.money(6000.0)),"separate delivery previews the real 20 percent facility assembly cost")
			g.work_order.receipts = [{"keys":["CP-E","RAD","K4"],"value":6000.0,"assembled":true,"source":"whole-fixture"}]
			panel.select_sale(false)
			await click(panel.sale_button.get_global_rect().get_center())
			check(panel.selling and panel.cash_label.text.contains(Pal.money(7500.0)) and not g.work_order.sell,"actual mouse selection previews sale without changing field ownership")
			check(JSON.stringify(Career.data) == before,"preview selection changes neither career cash nor engineering stock")
			check(is_equal_approx(g.playtime,clock_before),"contract countdown stays paused while engineering choices are reviewed")
			if JSON.stringify(Career.data) != before:
				var previous: Dictionary = JSON.parse_string(before)
				for key in Career.data:
					if previous.get(key) != Career.data[key]: print("PREVIEW CHANGE ",key," before=",previous.get(key)," after=",Career.data[key])
			if "--capture" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				preload("res://tests/cap.gd").save(root,"res://proofs/g4_review_%s_%d.png" % ["zh" if language else "en",size.x])
			await click(panel.back_button.get_global_rect().get_center())
			check(g.order_review == null and not paused and not g.ended and same_economy(before),"returning to the field leaves all goods and rewards uncommitted")
			g._read_input()
			check(not g.tools.lmb and not g.tools.lmb_pressed,"review-closing mouse release cannot operate the held tool through the overlay")
			g.finish_contract(false)
			await frames(2)
			check(g.order_review == null,"a deferred automatic ending does not reopen the review every frame")
			g.finish_contract(true)
			await frames(3)
			check(g.order_review != null,"manual finish can reopen a deferred engineering review")
			if g.order_review != null: g.order_review.back_button.pressed.emit()
			await dispose()
	await spawn()
	g.finish_contract(false)
	await frames(4)
	check(g.order_review != null,"automatic ending uses the same engineering choice before committing")
	if g.order_review != null:
		g.order_review.select_sale(true)
		g.order_review.confirm_button.pressed.emit()
	await frames(5)
	check(g.ended and g.career_result.get("work_order",{}).get("sold",false) and not Orders.done("heavy"),"confirmed sale commits cash and clears stock without awarding the engineering facility")
	check(Career.data.work_orders.stock.heavy.is_empty(),"sold old and new reservations are removed exactly once")
	await dispose()
	await spawn()
	g.finish_contract(true)
	await frames(3)
	if g.order_review != null:
		check(root.gui_get_focus_owner() == g.order_review.confirm_button,"keyboard focus starts on the visible confirmation action")
		await key(KEY_TAB)
		check(root.gui_get_focus_owner() == g.order_review.back_button,"Tab follows the explicit review action order")
		g.order_review.confirm_button.grab_focus()
		await key(KEY_ENTER)
	await frames(5)
	check(g.ended and Orders.done("heavy") and Repair.done("buffer"),"confirmed reservation commits the actual facility reward")
	check(float(g.career_result.get("work_order",{}).get("surplus_cash",0)) == 1500.0,"the same confirmation atomically returns the extra earlier reservation")
	await dispose()
	await spawn()
	var valid_path: String = Career.path
	var initial_money: float = Career.data.money
	Career.path = "user://zp_g4_review_unwritable_%d/slot.json" % Time.get_ticks_usec()
	g.finish_contract(true)
	await frames(3)
	if g.order_review != null: g.order_review.confirm_button.pressed.emit()
	await frames(4)
	check(not g.ended and g.work_order.receipts.size() == 1 and float(Career.data.money) == initial_money and not Orders.done("heavy"),"failed confirmation save preserves the field goods, money and unawarded facility")
	Career.path = valid_path
	g.finish_contract(true)
	await frames(3)
	check(g.order_review != null,"save failure can reopen the same engineering choice for a normal retry")
	if g.order_review != null: g.order_review.confirm_button.pressed.emit()
	await frames(4)
	check(g.ended and Orders.done("heavy"),"retry commits engineering delivery once storage becomes writable")
	await dispose()
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G4 ORDER REVIEW %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
