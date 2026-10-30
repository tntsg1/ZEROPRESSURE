extends SceneTree
# Real scene/clock/native-control integration, with declared career fixtures.
# No claim of human playtesting or completed physical trade logistics.
var g: Node
var checks := 0
var fails := 0
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
func run() -> void:
	Career.path = "user://zp_test_g5_exchange_ui_career.json"
	SaveGame.path = "user://zp_test_g5_exchange_ui_field.json"
	SaveGame.allow_test = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.port = {"trade":1}
	Career.data.money = 1000.0
	var job := {"id":"G5-UI-001","ship":"pod","fee":0,"kit":{},"items":{}}
	Career.data.active = job.duplicate(true)
	Game.contract = job
	Game.start_ship = "pod"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	await frames(8)
	g.tutorial = null
	g.open_console("terminal")
	await frames(3)
	var terminal = g.console_ui
	check(terminal != null and terminal.exchange_button.visible and paused, "existing berth terminal exposes the new exchange entry after the original market unlock")
	terminal.exchange_button.pressed.emit()
	await frames(5)
	var panel = g.console_ui
	check(panel != null and panel is Control and not paused and not g.paused_sim, "new native exchange opens over actual scene without pausing gameplay")
	if panel == null: quit(1);return
	# 45 号: the exchange was rebuilt (goods cards, seller rows; tests/exchange_ui_check.gd covers
	# buying and selling through it); this check keeps the live-clock, no-pause and input rules
	var merchant_offers: int = Career.data.exchange.orders.filter(func(o): return o.state == "open" and o.owner != "company").size()
	check(merchant_offers > 2 and panel.main.get_child_count() > 0, "production market opens on actual merchant orders (%d), not an empty book" % merchant_offers)
	g.bot.move = Vector2.RIGHT
	g.bot.dash = true
	await frames(2)
	check(g.drone.input.move == Vector2.ZERO and not g.drone.input.dash, "live market controls cannot leak pilot thrust or boost into the unpaused world")
	g.bot.move = Vector2.ZERO
	g.bot.dash = false
	var clock: float = Career.data.exchange.clock
	var play: float = g.playtime
	await frames(60)
	check(float(Career.data.exchange.clock) > clock and is_equal_approx(float(Career.data.exchange.clock)-clock,float(g.playtime)-play), "exchange and live game advance once from the same scene delta while panel is open")
	panel.toggle_pause()
	clock = float(Career.data.exchange.clock)
	play = float(g.playtime)
	await frames(20)
	check(paused and g.paused_sim and Career.data.exchange.clock == clock and g.playtime == play, "explicit pause freezes both world and market without freezing the resume control")
	panel.toggle_pause()
	await frames(5)
	check(not paused and not g.paused_sim and Career.data.exchange.clock > clock, "resume restarts the same world and exchange clock")
	panel.toggle_pause()
	check(panel.close(), "exchange closes only after its career state is persisted")
	await frames(3)
	check(g.console_ui == null and not paused and not g.paused_sim, "closing a manually paused panel restores gameplay and clears its modal owner")
	g.queue_free()
	await frames(5)
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G5 EXCHANGE UI CLOCK %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
