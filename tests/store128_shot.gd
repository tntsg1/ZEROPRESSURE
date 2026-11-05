extends "res://tests/guide_check.gd"
# 128 号 第 1 段 仓库与结算. Plays TUG-001 with the salvage bot in a fresh career (own test saves
# only, never the real one), then shoots: the new settlement page, the warehouse page, the first
# visit's card and its one target mark, the counter's hand-held first sale, the dock crane taking
# it away, and an overflowing haul with its inbox column. Checks the rules as it goes.
#   tools/run_test.sh tests/store128_shot.gd --fixed-fps 60 [-- quick]

const Bot = preload("res://tests/salvage_bot.gd")
const OUT := "res://tests/out/store128_%s.png"


func _initialize() -> void:
	Career.path = "user://zp_test_store128_career.json"
	SaveGame.path = "user://zp_test_store128_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _wait_ms(ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await process_frame


func _shot(name: String) -> void:
	await _frames(2)
	Cap.save(root, OUT % name)


func _key(k: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = true
	root.push_input(ev)
	await _frames(1)
	var up := ev.duplicate()
	up.pressed = false
	root.push_input(up)


func _texts(n: Node) -> String:
	var out := PackedStringArray()
	for l in n.find_children("*", "", true, false):
		if (l is Label or l is Button) and l.is_visible_in_tree():
			out.append(str(l.text))
	return "
".join(out)


func _berth() -> void:
	Game.start_ship = "berth"
	Game.contract = {}
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(20)
	g.tutorial = null


# how bright a unit's cells are on the screen, over the grid's own dark (mean of r+g+b)
func _lum(ui, id: String) -> float:
	if id == "":
		return 0.0
	var img: Image = root.get_texture().get_image()
	var r: Rect2 = ui.unit_rect(id)
	r.position += ui._grid_rect().position
	r = r.grow(-6.0)
	var sum := 0.0
	var n := 0
	for x in range(int(r.position.x), int(r.end.x), 2):
		for y in range(int(r.position.y), int(r.end.y), 2):
			var c: Color = img.get_pixel(x, y)
			sum += maxf(0.0, c.r + c.g + c.b - 0.1)
			n += 1
	return sum / maxi(n, 1)


# the stores counter on the screen: its body (the rack's lit frame) and the name plate over it
func _counter_screen_rect() -> Rect2:
	var xf: Transform2D = g.get_viewport().canvas_transform
	var m := PortStructure.M()
	var rc := Consoles.rack_centre() + Vector2(0.2, 0.0) * Geom.M
	var a: Vector2 = xf * (rc + Vector2(-1.15, -1.15) * m)
	var b: Vector2 = xf * (rc + Vector2(1.15, 1.15) * m)
	var r := Rect2(a, b - a)
	var sp: Vector2 = xf * (rc + Vector2(0.0, -1.15) * m)
	return r.merge(Rect2(sp - Vector2(110.0, 50.0), Vector2(220.0, 50.0)))


func _run() -> void:
	Txt.zh = true
	Game.coach_in_tests = true
	# ---- TUG-001, a new career, played by the bot
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true}
	Career.data.active = Career.opening(0)
	Career.save()
	Game.contract = Career.active()
	Game.start_ship = str(Game.contract.ship)
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(12)
	g.tutorial = null
	var bot = Bot.new(g)
	while not bot.step():
		await process_frame
	Engine.time_scale = 1.0
	await _frames(20)
	check(g.state == "ending", "TUG-001 stripped by the bot (%s)" % g.state)
	var r: Dictionary = g.career_result
	var h: Dictionary = r.get("haul", {})
	print("HAUL ", JSON.stringify(h))
	check(not h.is_empty() and float(h.raw_t) > 30.0 and int(h.equip) >= 10, "the haul: %.1f t raw, %d machines, %d special" % [float(h.get("raw_t", 0)), int(h.get("equip", 0)), int(h.get("special", 0))])
	check(Career.data.get("disposal", {}).is_empty(), "no piece-by-piece page any more (no disposal open)")
	var after := StoreBook.used_with(StoreBook.inbox())
	print("CELLS after TUG-001: %d / %d (%.0f %%)" % [after, StoreBook.cap(), 100.0 * after / StoreBook.cap()])
	check(after <= StoreBook.cap(), "TUG-001 fits the 8×32 grid (%d/%d cells)" % [after, StoreBook.cap()])
	check(StoreBook.blocks_next_job(), "the haul waits in the inbox till the button: the next job is held")
	g.hud.end_t = 9.0
	await _frames(30)
	check(g.hud.stores_page() and g.hud.end_go_rect.size.x > 0.0, "the settlement page is the haul page, with its one button")
	await _shot("1_settlement")
	var money0 := float(Career.data.money)
	g.hud.ending_key(KEY_SPACE)
	await _frames(5)
	check(StoreBook.inbox().is_empty(), "入库: everything put away (%d cells)" % StoreBook.used())
	check(not StoreBook.blocks_next_job(), "and the next job is free")
	check(absf(float(Career.data.money) - money0) < 0.5, "no cash moved by putting away")
	# ---- the berth, the first visit: one card, one mark on the counter
	g.queue_free()
	await _frames(5)
	await _berth()
	await _frames(30)
	check(g.store_guide != null and is_instance_valid(g.store_guide) and g.store_guide.step == "fly", "back in the berth: the first visit's guide is up")
	check(not RemoteOps.ok("store"), "F3 is not open before the counter is visited: %s" % RemoteOps.why("store"))
	check(not g.hud._main_on() and not g.walk_on(), "only one voice: the main-line card and the port walk wait")
	check(g.store_guide.target() != Vector2.INF, "the one target mark is on the counter")
	await _frames(40)
	# 返工 3: one voice — the old top hint and the next-step board wait while the guide speaks
	check(g.hud.hint_text != "" and not g.hud.hint_on(), "the old top hint waits while the stores guide is up (%s)" % g.hud.hint_text)
	check(NextStep.of(g).is_empty(), "and no next-step board")
	# 返工 5: the counter, its name plate and the mark stand clear of the toolbar
	var cr := _counter_screen_rect()
	var tb: Rect2 = g.hud._toolbar_rect()
	print("COUNTER on screen %s · toolbar %s" % [str(cr), str(tb)])
	check(cr.end.y < tb.position.y and not cr.intersects(tb) and cr.position.y > 0.0, "the counter's plate and body are above the toolbar (%.0f < %.0f)" % [cr.end.y, tb.position.y])
	await _shot("2_first_card")
	# fly to the counter and press E
	g.drone.global_position = Consoles.rack_centre() + Vector2(1.2, 0.0) * Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(20)
	check(g.consoles.near() == "rack", "at the counter")
	g.store_guide.press_use()
	await _frames(20)
	var ui = g.console_ui
	check(ui != null and ui.get_script() == preload("res://scripts/company_store.gd"), "E at the counter opens the stores")
	check(RemoteOps.ok("store"), "and F3 is open from now on")
	check(g.store_guide.step == "sell" and ui.guide_id != "" and ui.guide_btn == "sell", "the guide lights one thing and the recycling button: %s" % ui.guide_id)
	await _frames(30)
	await _shot("3_store_guided")
	# 返工 1: the grid fills the page's left part, 8 columns of big cells
	var grr: Rect2 = ui._grid_rect()
	check(ui.cell() >= 110.0 and grr.end.x >= ui._side_rect().position.x - 60.0, "the grid fills the left part (cell %.0f px, grid ends %.0f, side column at %.0f)" % [ui.cell(), grr.end.x, ui._side_rect().position.x])
	# 用户定 C: no 零件 filter while there are no spares
	check(ui.count("part") > 0 or not ("part" in ui.filters()), "the 零件 filter is hidden with no spares (%s)" % str(ui.filters()))
	# the filters: what does not belong is dimmed, not hidden
	for k in ui.filters() + ["all"]:
		ui.open_kind(k)
		await _frames(3)
		check(ui.kind == k, "filter %s (%d lit)" % [k, ui.shown().size()])
	var sizes := {}
	for it in ui.items:
		sizes["%dx%d" % [int(it.w), int(it.h)]] = true
	check(sizes.size() >= 3, "things of different sizes in the grid: %s" % str(sizes.keys()))
	var pod: Dictionary = ui._item(ui.guide_id)
	check(int(pod.w) * int(pod.h) >= 2, "the thruster pod is bigger than one cell (%d×%d)" % [int(pod.w), int(pod.h)])
	ui.select(ui.guide_id)
	await _frames(10)
	await _shot("4_store_all")
	# 返工: a filter plainly dims what it leaves out (pixels, not just a flag)
	var raw_id := ""
	var eq_id := ""
	for it in ui.items:
		var ur: Rect2 = ui.unit_rect(str(it.id))
		if ur.size == Vector2.ZERO or ur.position.y < 0.0 or ur.end.y > ui._grid_rect().size.y:
			continue
		if raw_id == "" and str(it.cat) == "raw":
			raw_id = str(it.id)
		if eq_id == "" and str(it.cat) == "equip" and str(it.id) != ui.sel:
			eq_id = str(it.id)
	var raw_lit := _lum(ui, raw_id)
	var eq_lit := _lum(ui, eq_id)
	ui.open_kind("equip")
	await _wait_ms(110)
	Cap.save(root, OUT % "anim_filter_mid")
	await _wait_ms(320)
	var raw_dim := _lum(ui, raw_id)
	var eq_on := _lum(ui, eq_id)
	print("DIM raw %.4f -> %.4f · equip %.4f -> %.4f" % [raw_lit, raw_dim, eq_lit, eq_on])
	# 2026-11-04 (user): left out means plainly darker but still there (about 28 %), not gone
	check(raw_id != "" and raw_dim < raw_lit * 0.55 and raw_dim > raw_lit * 0.08, "filter 设备: a raw bundle is plainly dimmed but still visible (%.3f -> %.3f)" % [raw_lit, raw_dim])
	# (0.85: a shown machine now lifts 2.5 px off the floor, so the sampled cells catch a little less of it)
	check(eq_id != "" and eq_on > eq_lit * 0.85, "and a machine stays lit (%.3f -> %.3f)" % [eq_lit, eq_on])
	await _shot("4b_filter_equip_dims_rest")
	ui.open_kind("all")
	var pick: Dictionary = ui._item(ui.guide_id)
	var price := float(pick.recycle)
	check(absf(price - snappedf(float(pick.market) * 0.6, 1.0)) < 1.0, "recycling price is 60 %% of market (%s of %s)" % [Pal.money(price), Pal.money(float(pick.market))])
	var m1 := float(Career.data.money)
	# 2026-11-04 (人性化 规则 2): selling takes one press, no confirm; the note says what and where
	ui.sell_sel()
	await _wait_ms(200)
	Cap.save(root, OUT % "anim_sell_fly")
	await _wait_ms(450)
	check(absf(float(Career.data.money) - m1 - price) < 1.0, "one press sells: +%s, cash at once" % Pal.money(price))
	check(ui.message.contains("卖给回收站"), "the note says where it went (%s)" % ui.message)
	check(g.store_guide.step == "done_card", "the guide says what happened and what next")
	await _frames(20)
	await _shot("5_sold_guide")
	# drag a machine to a free place, turned on the way
	var mv := ""
	for it in ui.items:
		if str(it.cat) == "equip" and int(it.w) != int(it.h):
			mv = str(it.id)
			break
	check(mv != "", "a machine to move: %s" % mv)
	var r0: Rect2 = ui.unit_rect(mv)
	var gp: Vector2 = ui._grid_rect().position
	ui._start_drag(mv, gp + r0.position + Vector2(10, 10))
	# the shots show the dragged thing under a stand-in pointer (the real one is never moved)
	BenchFx.shot_mouse = ui.get_global_transform() * (gp + r0.position + Vector2(60, 40))
	await _wait_ms(60)
	Cap.save(root, OUT % "anim_pickup")
	ui.turn()
	await _wait_ms(90)
	Cap.save(root, OUT % "anim_turn")
	BenchFx.shot_mouse = Vector2.INF
	ui.scroll = 16.0 * ui.cell()
	var target: Vector2 = gp + Vector2(0.5, 20.5) * ui.cell() - Vector2(0.0, ui.scroll)
	ui.drag_grab = Vector2(0.5, 0.5)
	check(ui.drop_ok(target), "the dragged, turned machine fits at row 20")
	ui._drop(target)
	await _wait_ms(70)
	Cap.save(root, OUT % "anim_snap")
	await _frames(4)
	check(int(ui.lay[mv][1]) == 20 and int(ui.lay[mv][2]) == 1, "moved and turned: %s" % str(ui.lay[mv]))
	# R on a placed machine: it turns a quarter about its centre (0.2 s); turned back after the shot
	ui.select(mv)
	ui._keep_in_view()
	await _frames(2)
	ui.turn()
	if int(ui.lay[mv][2]) == 0:
		await _wait_ms(100)
		Cap.save(root, OUT % "anim_turn_placed")
		await _wait_ms(250)
		ui.turn()
	await _frames(2)
	ui.select(mv)
	# 用户 bug: cards scrolled over the title. The grid draws in its own clipped control: the page
	# above its top and under its bottom looks the same whatever the scroll
	ui.sel = ""
	ui.scroll = 0.0
	await _frames(4)
	var img0: Image = root.get_texture().get_image()
	ui.scroll = ui._scroll_max() * 0.5 + 37.0
	await _frames(4)
	var img: Image = root.get_texture().get_image()
	var gr: Rect2 = ui._grid_rect()
	var bad := 0
	for x in range(int(gr.position.x) - 2, int(gr.end.x) + 2, 3):
		for y in range(int(gr.position.y) - 14, int(gr.position.y) - 2) + range(int(gr.end.y) + 3, int(gr.end.y) + 14):
			var a: Color = img0.get_pixel(x, y)
			var b: Color = img.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.02:
				bad += 1
	ui.select(mv)
	await _frames(4)
	await _shot("5b_moved_turned_scrolled")
	check(ui.grid_view.clip_contents and bad == 0, "scrolled half way: nothing drawn past the grid's top or bottom edge (%d stray pixels)" % bad)
	ui.scroll = 0.0
	ui.open_kind("all")
	await _frames(2)
	ui.tidy()
	await _wait_ms(260)
	Cap.save(root, OUT % "anim_tidy_fly")
	await _wait_ms(380)
	Cap.save(root, OUT % "anim_tidy_settle")
	await _frames(3)
	# 2026-11-04 (user's shot): filtered to machines, tidy puts the machines first and the view at the top
	ui.open_kind("equip")
	ui.scroll = ui._scroll_max() * 0.6
	await _frames(2)
	ui.tidy()
	await _wait_ms(900)
	var top_cat := ""
	for it in ui.items:
		if ui.lay.has(str(it.id)) and int(ui.lay[str(it.id)][0]) == 0 and int(ui.lay[str(it.id)][1]) == 0:
			top_cat = str(it.cat)
	check(ui.scroll < 0.5 and top_cat == "equip", "filtered tidy: back at the top, the machines first (%s, scroll %.0f)" % [top_cat, ui.scroll])
	Cap.save(root, OUT % "anim_tidy_equip_first")
	ui.open_kind("all")
	ui.tidy()
	await _wait_ms(900)
	check(ui.lay.size() == ui.items.size(), "一键整理: everything laid out again (%d)" % ui.lay.size())
	ui.scroll = 0.0
	ui._close()
	await _frames(10)
	check(g.recycle_crane != null and g.recycle_crane.busy(), "the dock crane is taking it away")
	g.cam_override = Consoles.rack_centre() + Vector2(2.5, -1.0) * Geom.M
	await _frames(150)
	await _shot("6_crane")
	await _frames(320)
	check(not g.recycle_crane.busy(), "and it is gone in a few seconds")
	g.cam_override = null
	check(Career.data.get("seen", {}).has("store_guide_done"), "the first visit's guide is over for good")
	# 返工 4: the old exchange page (F8 and every way in) is shut while exchange_open() is false
	Career.data.market = true
	await _frames(200)
	g.open_exchange()
	await _frames(20)
	check(not StoreBook.exchange_open() and g.console_ui == null, "F8: the exchange page does not open")
	check(g.hud.hint_text == "交易行还没开放" and g.hud.hint_on(), "it says so: %s" % g.hud.hint_text)
	await _shot("10_f8_closed")
	# ---- an overflowing haul: what does not fit waits; sold or kept from the inbox
	Career.data.inbox = []
	var big: Array = []
	for i in 30:
		big.append({"cat": "equip", "tag": "BIG-%d" % i, "nk": "p_pod", "value": 2500.0 + i * 100.0, "cond": 1.0, "mass": 6.0})
	StoreBook.receive("099-TEST", "gr7", 30.0, [], big)
	Career.save()
	var need := StoreBook.used_with(StoreBook.inbox())
	print("OVERFLOW: %d / %d" % [need, StoreBook.cap()])
	check(need > StoreBook.cap(), "a haul too big (%d / %d)" % [need, StoreBook.cap()])
	StoreBook.admit()
	check(StoreBook.used() <= StoreBook.cap() and not StoreBook.inbox().is_empty(), "what fits is put away, the rest waits (%d left)" % StoreBook.inbox().size())
	check(StoreBook.blocks_next_job(), "and the next job is held")
	g.open_store()
	await _frames(10)
	ui = g.console_ui
	check(ui._inbox_on(), "the stores show the inbox column")
	ui.select(str(ui.inbox[0].id))
	await _frames(20)
	# 返工 2: the inbox tiles and the details draw the machine's own line art too
	var i0: Dictionary = ui.inbox[0]
	var lk := StoreBook.look_any(str(i0.get("ship", "")), str(i0.get("tag", "")), str(i0.get("good", {}).get("nk", "")))
	check(str(lk.get("art", "")) != "", "an inbox machine has its line art (%s)" % str(lk.get("art", "")))
	check(not str(i0.qty).contains("×"), "no cell size written on the inbox row: %s" % str(i0.qty))
	await _shot("7_inbox")
	var n0: int = StoreBook.inbox().size()
	ui.sell_sel()
	await _frames(3)
	check(StoreBook.inbox().size() == n0 - 1, "an inbox thing sold to the recycling station")
	# make room: sell an old machine, then keep a waiting one
	ui.open_kind("equip")
	ui.select(str(ui.shown()[0].id))
	ui.sell_sel()
	await _frames(3)
	var w0: int = StoreBook.inbox().size()
	for it in ui.inbox:
		if str(it.cat) == "equip":
			ui.select(str(it.id))
			break
	ui.keep_sel()
	await _wait_ms(200)
	Cap.save(root, OUT % "anim_keep_fly")
	await _frames(3)
	check(StoreBook.inbox().size() == w0 - 1, "room made: a waiting machine kept (put away)")
	# 用户定 B: the repair steel in its own slot, a stack of plate and its tonnes, not for sale
	Career.data.structure_t = 40.6
	ui.select("steel")
	await _frames(10)
	check(ui._item("steel").get("steel", false) and not ui.can_sell(ui._item("steel")), "the repair steel: its own slot, not for sale")
	check(not ui.lay.has("steel") and ui._side_rect().encloses(ui.steel_rect()), "not in the grid, at the side column's top")
	await _shot("9_steel")
	ui._close()
	await _frames(5)
	# 用户定 A: the rows come from the data (第 3 段 wires them to the cargo works); what lies keeps its cells
	var lay0: Dictionary = StoreBook.layout(StoreBook.units())
	Career.data.port = {"cargo": 1}
	StoreBook.ROWS_FROM_CARGO = true
	var lay1: Dictionary = StoreBook.layout(StoreBook.units())
	var same := true
	for id in lay0:
		if str(lay1.get(id, [])) != str(lay0[id]):
			same = false
	check(StoreBook.rows() == 48 and StoreBook.cap() == 384 and same, "cargo stage 1 → 8×48 (%d cells), nothing moved" % StoreBook.cap())
	Career.data.port = {"cargo": 2}
	check(StoreBook.rows() == 64, "stage 2 → 8×64")
	StoreBook.ROWS_FROM_CARGO = false
	Career.data.port = {}
	# ---- user 2026-11-04: no third-party storage — the cargo terminal is the company's own stores only
	Career.data.port = {"cargo": 1}
	Career.save()
	check(StoreBook.cap() == 256, "the grid is 8×32 (%d cells)" % StoreBook.cap())
	g.drone.global_position = preload("res://scripts/port_structure.gd").console_spot("cargo")
	await _frames(30)
	g.open_district("cargo")
	await _frames(30)
	var tx := _texts(g.console_ui)
	check(not tx.contains("第三方仓储") and not tx.contains("接这单") and not tx.contains("停止接新单"), "the cargo terminal has no third-party storage")
	await _shot("8_cargo_terminal")
	for i in 400:
		Depot.advance(1.0)
	check(Depot.data().offers.is_empty(), "and no client offers come any more")
	g.console_ui.close()
	await _frames(5)
	# ---- 用户 bug: an old exchange's listing held 5 t of plate in a save whose trade port is not mended
	Career.data.port = {}
	Career.data.market = true
	Career.data.inbox = []
	Career.save()
	preload("res://scripts/industrial_exchange.gd").command("view")
	var ex: Dictionary = Career.data.exchange
	var co: Dictionary = ex.actors.company
	co.stock["steel_plate:1"] = 5.0
	co.lots["test_plate"] = {"id": "test_plate", "key": "steel_plate:1", "available": 5.0, "total": 5.0, "origin": "test"}
	var post: Dictionary = preload("res://scripts/industrial_exchange.gd").post(ex, "company", "sell", "steel_plate", 1, 5.0, 900.0)
	check(bool(post.get("ok", false)) and float(co.stock.get("steel_plate:1", 0.0)) < 0.01, "an old listing holds the 5 t (%s)" % str(post))
	Career.save()
	Career.data = {}
	Career.load_or_new()
	var held_open := 0
	for o in Career.data.exchange.orders:
		if str(o.owner) == "company" and str(o.state) == "open":
			held_open += 1
	check(held_open == 0 and float(Career.data.exchange.actors.company.stock.get("steel_plate:1", 0.0)) > 4.99, "loading withdraws it: the plate is free again")
	check(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("user://zp_test_backup")), "the save was copied aside first")
	var plate_id := ""
	for u in StoreBook.units():
		if str(u.get("key", "")) == "steel_plate:1":
			plate_id = str(u.id)
	var m2 := float(Career.data.money)
	var sold: Dictionary = StoreBook.sell(plate_id)
	check(bool(sold.get("ok", false)) and float(Career.data.money) > m2, "and it sells to the recycling station (%s)" % str(sold.get("reason", sold.get("cash", ""))))
	# 用户 save: the trade port mended (stage 1) but the exchange not usable yet — the same
	Career.data.port = {"trade": 1}
	Career.data.erase("migrations")
	ex = Career.data.exchange
	co = ex.actors.company
	co.stock["steel_plate:1"] = float(co.stock.get("steel_plate:1", 0.0)) + 5.0
	co.lots["test_plate2"] = {"id": "test_plate2", "key": "steel_plate:1", "available": 5.0, "total": 5.0, "origin": "test"}
	post = preload("res://scripts/industrial_exchange.gd").post(ex, "company", "sell", "steel_plate", 1, 5.0, 900.0)
	check(bool(post.get("ok", false)) and not StoreBook.exchange_open(), "trade port mended, exchange not usable, a listing holds 5 t")
	# 返工 4: no new listing through the exchange's commands while it is shut
	var cmd: Dictionary = preload("res://scripts/industrial_exchange.gd").command("post", {"side": "sell", "item": "steel_plate", "grade": 1, "quantity": 1.0, "price": 900.0})
	check(not bool(cmd.get("ok", true)) and str(cmd.get("reason", "")) == "exchange_closed", "posting a listing is refused: %s" % str(cmd.get("reason", "")))
	Career.save()
	Career.data = {}
	Career.load_or_new()
	check(StoreBook.listed_t("steel_plate:1") < 0.01, "loading withdraws it here too")
	plate_id = ""
	for u in StoreBook.units():
		if str(u.get("key", "")) == "steel_plate:1":
			plate_id = str(u.id)
	m2 = float(Career.data.money)
	sold = StoreBook.sell(plate_id)
	check(bool(sold.get("ok", false)) and float(Career.data.money) > m2, "and it sells to the recycling station")
	Career.data = {}
	Career.load_or_new()
	check(Career.data.get("migrations", []).filter(func(m): return str(m.id) == "128_orders").size() == 1, "the migration runs once")
	# a listing made later (an old exchange page): withdrawn from the stores page itself
	ex = Career.data.exchange
	co = ex.actors.company
	co.stock["steel_plate:1"] = float(co.stock.get("steel_plate:1", 0.0)) + 4.0
	co.lots["test_plate3"] = {"id": "test_plate3", "key": "steel_plate:1", "available": 4.0, "total": 4.0, "origin": "test"}
	preload("res://scripts/industrial_exchange.gd").post(ex, "company", "sell", "steel_plate", 1, 4.0, 900.0)
	var wr := StoreBook.withdraw_key("steel_plate:1")
	check(bool(wr.get("ok", false)) and float(StoreBook.raw_stock().get("steel_plate:1", 0.0)) > 3.99, "撤下挂单 on the stores page brings the 4 t back")
	print("STORE128 %d/%d" % [checks - fails, checks])
	quit(0 if fails == 0 else 1)
