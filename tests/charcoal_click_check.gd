extends SceneTree
# 炭黑 (user 2026-11-10: "这下面的电网调度和仓库怎么按不了啊"): real mouse clicks pushed into the
# viewport on the terminal's foot keys — stores [F3], grid dispatch [F5], exchange [F8] — each opens its
# page and Esc comes back to the terminal; the keys F3/F5/F8 and arrows + Enter do the same; then every
# visible button on the terminal's other pages takes a click.
#   tools/run_test.sh tests/charcoal_click_check.gd --fixed-fps 60
var g
var fails := 0
var checks := 0


func _initialize() -> void:
	Career.path = "user://zp_test_charcoal_click_career.json"
	SaveGame.path = "user://zp_test_charcoal_click_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ui_path() -> String:
	var u = g.console_ui
	if u == null or not is_instance_valid(u):
		return ""
	return str(u.get_script().resource_path).get_file()


# a left click where a control is, through the window like a real one
func _click(c: Control) -> void:
	# window pixels, as a real pointer gives them (the game's window is scaled: 1600×900 by default)
	var at := root.get_final_transform() * c.get_global_rect().get_center()
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	root.push_input(mv)
	await _frames(2)
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = at
		ev.global_position = at
		root.push_input(ev)
		await _frames(2)


func _ghosts() -> Array:
	var out: Array = []
	for n in root.get_children():
		if n is CanvasLayer and n.layer > 60 and n.layer < 80 and n.get_child_count() > 0 and n.get_child(0).get_script() != null:
			out.append("%d:%s" % [n.layer, n.get_child(0).get_script().resource_path.get_file()])
	return out


# a click in the middle of a drawn key (page pixels)
func _click_rect(r: Rect2) -> void:
	await _click_at_canvas(r.get_center())


func _click_at_canvas(p: Vector2) -> void:
	var at := root.get_final_transform() * p
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	root.push_input(mv)
	await _frames(2)
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = at
		ev.global_position = at
		root.push_input(ev)
		await _frames(2)


func _key(k: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.physical_keycode = k
		ev.pressed = down
		root.push_input(ev)
		await _frames(2)


func _what_is_at(c: Control) -> String:
	var at := root.get_final_transform() * c.get_global_rect().get_center()
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	root.push_input(mv)
	await _frames(2)
	var h := root.gui_get_hovered_control()
	return str(h.get_path()) if h != null else "(nothing)"


func _terminal() -> void:
	if _ui_path() != "terminal.gd":
		if g.console_ui != null and is_instance_valid(g.console_ui) and g.console_ui.has_method("close"):
			g.console_ui.close()
			await _frames(20)
		g.open_console("terminal")
	await _frames(40)


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_tour": true, "port_walk": true, "market_ops": true}
	Career.data.money = 714573.0
	Career.data.history = [{"id": "TUG-001"}]
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1, "tug": 1}
	Career.save()
	Game.start_ship = "berth"
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(40)
	Txt.zh = true
	# the user plays with the developer mode on (the DEV · F12 tab): the same clicks must work there
	if "dev" in OS.get_cmdline_user_args():
		Txt.dev = true
		print("dev mode on")
	# the counter seen and the round walked, so all three remote jobs are open
	Career.data.seen["store_counter"] = true
	for k in ["walk_power", "walk_process"]:
		Career.data.seen.erase(k)
	Career.data.erase("walk_v")
	print("ok store=%s grid=%s" % [RemoteOps.ok("store"), RemoteOps.ok("grid")])
	await _terminal()
	var term = g.console_ui
	var box: HBoxContainer = term.remote_box
	var want := {"store": "", "grid": "power_panel.gd"}
	for b in box.get_children():
		var kind := str(b.name).trim_prefix("Remote_")
		print("  %s disabled=%s visible=%s rect=%s under=%s" % [b.name, b.disabled, b.is_visible_in_tree(), b.get_global_rect(), await _what_is_at(b)])
	# ---- mouse clicks on the foot keys
	for kind in ["store", "grid"]:
		await _terminal()
		term = g.console_ui
		var b: Button = term.remote_box.get_node_or_null("Remote_" + kind)
		if b == null:
			check(false, "%s key on the foot" % kind)
			continue
		var before := _ui_path()
		await _click(b)
		await _frames(30)
		var now := _ui_path()
		check(now != "" and now != "terminal.gd", "click %s opens its page (%s → %s)" % [kind, before, now])
		await _key(KEY_ESCAPE)
		await _frames(40)
		check(_ui_path() == "terminal.gd", "Esc from %s comes back to the terminal (%s)" % [kind, _ui_path()])
		# the page that left must not linger on a layer above the terminal (it froze there while the
		# terminal paused the tree: the terminal looked dead under it)
		check(_ghosts().is_empty(), "nothing of %s lingers over the terminal (%s)" % [kind, str(_ghosts())])
	await _terminal()
	term = g.console_ui
	check(term.exchange_button.is_visible_in_tree(), "the exchange key is on the foot")
	await _click(term.exchange_button)
	await _frames(30)
	check(_ui_path() not in ["", "terminal.gd"], "click exchange opens it (%s)" % _ui_path())
	await _key(KEY_ESCAPE)
	await _frames(40)
	check(_ui_path() == "terminal.gd", "Esc from the exchange comes back to the terminal (%s)" % _ui_path())
	# ---- the exchange's own drawn keys (tabs, a card, its close key) take real clicks too
	await _terminal()
	term = g.console_ui
	await _click(term.exchange_button)
	await _frames(40)
	var hp = g.console_ui
	if hp != null and _ui_path() == "hall_panel.gd":
		for tb in ["buy", "orders", "sell"]:
			var tr: Rect2 = hp._btns.get("tab:" + tb, Rect2())
			await _click_rect(tr)
			await _frames(20)
			check(hp.tab == tb, "exchange: clicking the %s tab opens it (%s)" % [tb, hp.tab])
		hp.set_tab("orders")
		await _frames(30)
		var ok_card := false
		for k in hp._btns.keys():
			if str(k).begins_with("o:"):
				await _click_rect(hp._btns[k])
				await _frames(10)
				ok_card = "o:" + str(hp.ord_sel) == str(k)
				break
		check(ok_card or not hp._btns.keys().any(func(k): return str(k).begins_with("o:")), "exchange: clicking an order card picks it")
		await _click_rect(hp._btns.get("close", Rect2()))
		await _frames(40)
		check(_ui_path() == "terminal.gd", "exchange: its close key goes back to the terminal (%s)" % _ui_path())
	else:
		check(false, "the exchange opened (%s)" % _ui_path())
	# ---- the keys
	for k in [[KEY_F3, "F3"], [KEY_F5, "F5"], [KEY_F8, "F8"]]:
		await _terminal()
		await _key(k[0])
		await _frames(30)
		check(_ui_path() not in ["", "terminal.gd"], "%s opens its page (%s)" % [k[1], _ui_path()])
		await _key(KEY_ESCAPE)
		await _frames(40)
	# ---- every visible button on the terminal's pages takes a click (nothing lies over it)
	# a locked key: clickable, says why, stays on the terminal
	await _terminal()
	term = g.console_ui
	Career.data.seen.erase("store_counter")
	Career.data.history = [{"id": "TUG-001"}]
	await _frames(30)
	var sb: Button = term.remote_box.get_node("Remote_store")
	check(not sb.disabled and sb.get_meta("locked", false), "a locked foot key stays clickable and marked locked")
	await _click(sb)
	await _frames(10)
	check(_ui_path() == "terminal.gd" and term.msg != "", "clicking a locked key says why on the terminal (%s)" % term.msg)
	Career.data.seen["store_counter"] = true
	await _frames(30)
	check(not sb.get_meta("locked", true), "unlocked while the terminal is open: the key comes alive")
	for page in [-1, 1, 5, 8, 0]:
		await _terminal()
		term = g.console_ui
		term.set_tab(page)
		await _frames(40)
		if _ui_path() != "terminal.gd":
			check(true, "page %d hands over to %s" % [page, _ui_path()])
			continue
		var blocked: Array = []
		var seen := 0
		for b in term.find_children("*", "BaseButton", true, false):
			if not b.is_visible_in_tree() or b.disabled or b.get_global_rect().size.x < 4.0:
				continue
			seen += 1
			var under := await _what_is_at(b)
			var hit := root.gui_get_hovered_control()
			if hit != b and not (hit != null and b.is_ancestor_of(hit)):
				blocked.append("%s ← %s" % [b.name, under])
		check(blocked.is_empty(), "page %d: all %d buttons are reachable by the pointer %s" % [page, seen, str(blocked)])
	await _side_pages()
	print("CHARCOAL CLICK %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)


# 2026-11-11 (user: "找船的这个二手船市右上角好多按钮都点不开"): the site's function keys (hud_keys.gd)
# took every left click top right, under any page. Every button of the side pages — the star map (both
# tabs), the hulk market, every district's business console, the tram and the workboat — takes a real
# press: the pointer reaches it and its button_down fires (let go off it, so nothing is set off); then
# real full clicks on the star map's tabs, its market key and its back key do what they say.
func _press_reaches(b: BaseButton) -> bool:
	var fired := [false]
	var f := func(): fired[0] = true
	b.button_down.connect(f)
	var at := root.get_final_transform() * b.get_global_rect().get_center()
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	root.push_input(mv)
	await _frames(2)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	ev.global_position = at
	root.push_input(ev)
	await _frames(2)
	# off the key before letting go: the press is cancelled, nothing runs
	var away := Vector2(4, 4)
	var mv2 := InputEventMouseMotion.new()
	mv2.position = away
	mv2.global_position = away
	mv2.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(mv2)
	await _frames(1)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = away
	up.global_position = away
	root.push_input(up)
	await _frames(2)
	if is_instance_valid(b) and b.button_down.is_connected(f):
		b.button_down.disconnect(f)
	return fired[0]


func _close_page() -> void:
	var u = g.console_ui
	if u != null and is_instance_valid(u):
		if u.has_method("close"):
			u.close()
		elif u.has_method("_close"):
			u._close()
	await _frames(30)
	g.console_ui = null if g.console_ui != null and not is_instance_valid(g.console_ui) else g.console_ui


func _all_press(label: String) -> void:
	var u = g.console_ui
	if u == null or not is_instance_valid(u):
		check(false, "%s opened" % label)
		return
	var bad: Array = []
	var seen := 0
	for b in u.find_children("*", "BaseButton", true, false):
		if not is_instance_valid(b) or not b.is_visible_in_tree() or b.disabled or b.get_global_rect().size.x < 4.0:
			continue
		var vr := root.get_visible_rect()
		if not vr.has_point(b.get_global_rect().get_center()):
			continue
		seen += 1
		if not await _press_reaches(b):
			bad.append("%s「%s」 ← %s" % [b.name, str(b.get("text")).left(10), await _what_is_at(b)])
	check(seen > 0 and bad.is_empty(), "%s: all %d buttons take a real press %s" % [label, seen, str(bad)])


func _side_pages() -> void:
	if g.console_ui != null and is_instance_valid(g.console_ui):
		await _close_page()
	Career.data.seen["starmap_tour"] = true
	Career.data.seen["market_tour"] = true
	g.state = "play"
	# the star map, both tabs
	for m in ["find", "ships"]:
		g.open_star_map(m)
		await _frames(80)
		check(_ui_path() == "star_map.gd", "the star map opens (%s)" % m)
		await _all_press("star map · " + m)
		await _close_page()
	# real full clicks on its tabs, its market key, its back key
	g.open_star_map("find")
	await _frames(80)
	var sm = g.console_ui
	if _ui_path() == "star_map.gd":
		await _click(sm.tab_ships)
		await _frames(20)
		check(sm.mode == "ships", "star map: a click on 航运 opens shipping (%s)" % sm.mode)
		await _click(sm.tab_find)
		await _frames(20)
		check(sm.mode == "find", "star map: a click on 找船 opens finding (%s)" % sm.mode)
		var mk: Button = null
		for b in sm.find_children("*", "Button", true, false):
			if str(b.text) == "二手船市":
				mk = b
		check(mk != null and not mk.disabled, "star map: the hulk market key is there and live")
		if mk != null and not mk.disabled:
			await _click(mk)
			await _frames(60)
			check(_ui_path() == "ship_market_panel.gd", "star map: a click on 二手船市 opens the market (%s)" % _ui_path())
			if _ui_path() == "ship_market_panel.gd":
				await _all_press("hulk market")
		await _close_page()
	# every district's business console
	for z in ["power", "process", "tug", "trade", "cargo", "ring"]:
		g.state = "play"
		g.open_district(z)
		await _frames(60)
		if _ui_path() == "":
			check(true, "district %s: no console here (skipped)" % z)
			continue
		# a district console may hand over to its own page (the grid's screen)
		await _all_press("district %s (%s)" % [z, _ui_path()])
		await _close_page()
	# the tram and the workboat
	for t in [["tram", "salvage"], ["boat", "berth"]]:
		g.state = "play"
		g.open_transit(t[0], t[1])
		await _frames(60)
		await _all_press("transit %s" % t[0])
		await _close_page()
