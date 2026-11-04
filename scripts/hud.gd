class_name Hud
extends CanvasLayer
const FastDraw = preload("res://scripts/fast_draw.gd")
const CoreAsset = preload("res://scripts/core_asset.gd")
# Screen-space layer: contract panel, income, toolbar, drone status, cursor
# labels, measurement tags, messages, hints, the contract card, the pause
# menu and the settlement. Everything moves on springs and real time.

var game: Game
var c: Control
var fadd: Control
var font: Font
var font_l: Font
var font_b: Font
var asset_rect := Rect2()      # 110 号: where the asset board stands this frame (the drone feed's tapes keep clear of it)
var t := 0.0
var rate_roll := Motion.Roller.new(0.0, 6.0)
var credit_roll := Motion.Roller.new(0.0, 7.0)
var credit_pop := 0.0
var slot_y: Array = []
var slot_glow: Array = []
var hint_text := ""
var hint_t := 99.0
var flash := 0.0
var hurt := 0.0
var gauge_k := 0.0          # 91 号: the ring round the pointer for the work in hand
var gauge_kind := ""
var gauge_spin := 0.0
var flyers: Array = []     # [from, to, t, amount]
var card_k := Motion.Spring.new(0.0, 170.0, 0.82)
var card_t := 0.0
var menu_k := Motion.Spring.new(0.0, 220.0, 0.85)
var menu_hover := -1
var menu_confirm := -1
var ending := false
var end_t := 0.0
var end_early := false
var end_rows: Array = []
var must_k := [0.0, 0.0]
var tag_birth := {}
var tool_names_k := 0.0
var closing := -1.0
var alert_text := ""        # a required piece is lost: said across the top, in heat
var alert_t := 99.0
var show_log := false       # the radio log (L)
var saved_t := 99.0
var after_close: Callable
# motion on site: the HUD slides in from the edges once the drone is out,
# the tool marker springs between slots, bars leave a trail when they move
var in_t := 0.0
var sel_x := Motion.Spring.new(0.0, 340.0, 0.7)
var tool_pulse := 9.0
var integ_ghost := 100.0
var integ_hold := 0.0
var integ_prev := 100.0
var integ_roll := Motion.Roller.new(100.0, 9.0)
var spd_roll := Motion.Roller.new(0.0, 8.0)
var rate_lo := 0.0
var rate_sweep := 9.0
var rate_last := 0.0
var mark_pop := [9.0, 9.0, 9.0]
var must_t := {}
var bursts: Array = []      # [screen pos, age]
var cur := Motion.Spring2.new(Vector2.ZERO, 900.0, 0.9)
var cur_key := ""
var cur_t := 0.0
# the label as it was last shown: it fades out when the pointer leaves, it doesn't blink off
var cur_last := []
var cur_out := 9.0
var minimap: Control        # the berth map, bottom right (P.6)
var stock_last := {}
var stock_pop := 9.0
var stock_hit := ""


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = Fonts.get_font("Regular")
	font_l = Fonts.get_font("Light")
	font_b = Fonts.get_font("Medium")
	c = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_draw_hud)
	add_child(c)
	# 117 号: the text halos, under everything c draws
	halo_rid = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(halo_rid, c.get_canvas_item())
	RenderingServer.canvas_item_set_draw_behind_parent(halo_rid, true)
	fadd = Control.new()
	fadd.set_anchors_preset(Control.PRESET_FULL_RECT)
	fadd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fadd.material = m
	fadd.draw.connect(_draw_add)
	add_child(fadd)
	minimap = preload("res://scripts/minimap.gd").new()
	minimap.visible = false
	add_child(minimap)
	# the on-site guide's two keys (27 号): end it, or take its step's action (open the exchange)
	for i in 3:
		var b := Button.new()
		b.visible = false
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", Fonts.get_font("Medium"))
		b.add_theme_font_size_override("font_size", 15)
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			var box := SkillBook._key_box(st)
			box.content_margin_left = 14
			b.add_theme_stylebox_override(st, box)
		add_child(b)
		if i == 2:
			main_go = b
			b.pressed.connect(func(): Mainline.take_me(game, str(Mainline.step().get("go", ""))))
		elif i == 0:
			guide_end = b
			b.pressed.connect(func(): if game.guide != null: game.guide.stop())
		else:
			guide_act = b
			b.pressed.connect(func(): if game.guide != null: game.guide.act())
	for i in 6:
		slot_y.append(Motion.Spring.new(0.0, 300.0, 0.6))
		slot_glow.append(0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and halo_rid.is_valid():
		RenderingServer.free_rid(halo_rid)
		halo_rid = RID()


func size() -> Vector2:
	return c.size


func to_screen(w: Vector2) -> Vector2:
	return game.get_viewport().get_canvas_transform() * w


func pointer_over_ui() -> bool:
	var m := c.get_local_mouse_position()
	return _toolbar_rect().has_point(m) or _item_at(m) != "" or (game.training and TutorialHud.OVERVIEW_RECT.has_point(m)) or (game.codex_hud != null and game.codex_hud.pointer_over_card())


# the consumables this contract carries: one tile each, above the drone panel
func _item_slots() -> Array:
	var out: Array = []
	if game == null or not game.career():
		return out
	var s := size()
	var x := 22.0
	for id in ["repair", "ring", "spare"]:
		if game.stock(id) > 0 or int(game.used.get(id, 0)) > 0:
			out.append([id, Rect2(x, s.y - 188.0, 132.0, 58.0)])
			x += 140.0
	return out


func _item_at(m: Vector2) -> String:
	for it in _item_slots():
		if it[1].has_point(m):
			return it[0]
	return ""


# five tools, and the deploy tool while the job carries any field gear (scripts/gear.gd)
func _slots() -> int:
	if game == null or game.gear == null:
		return 5
	# on a career contract the slot is always there (greyed with nothing aboard), so it can be found
	return 6 if game.gear.active() or game.tools.tool == 6 or (game.career() and not game.training and game.exam == null and not game.in_berth()) else 5


func _toolbar_rect() -> Rect2:
	var s := size()
	var n := _slots()
	var w := n * 132.0 + (n - 1) * 10.0
	return Rect2(s.x * 0.5 - w * 0.5, s.y - 112.0, w, 92.0)


# 91 号 遥控: where the on-site panels are, for the drone feed's overlay round them (scripts/look.gd)
func feed_rects() -> Dictionary:
	var g = game
	var s := size()
	var out := {}
	if g.state != "play" or ending or g.menu_open or g.contract_open:
		return out
	if not g.training and g.exam == null and not g.in_berth():
		out["task"] = _contract_rect()
		out["ledger"] = Rect2(s.x - 290.0, 22, 268, 86)
	out["unit"] = Rect2(22.0, s.y - 106.0, 420.0, 70.0)
	out["payload"] = _toolbar_rect()
	if minimap != null and minimap.visible:
		out["nav"] = Rect2(minimap.position, minimap.map_size)
	return out


# 117 号 (Q5 A): where the HUD stands this frame — the panels with their OSD names, the link bar
# and the asset board. Signs and tags out in the world step out of these.
var _ko: Array = []
var _ko_frame := -1
func keep_out() -> Array:
	var f := Engine.get_process_frames()
	if f == _ko_frame:
		return _ko
	_ko_frame = f
	_ko = []
	var fr := feed_rects()
	if fr.is_empty():
		return _ko
	for k in fr:
		_ko.append((fr[k] as Rect2).grow_individual(10.0, 34.0, 10.0, 34.0))
	if asset_rect.has_area():
		_ko.append(asset_rect.grow(10.0))
	if Look.on and game.look != null:
		_ko.append(Rect2(size().x * 0.5 - 340.0, 8.0, 680.0, 86.0))
	return _ko


# the shortest step that takes a screen rect clear of the HUD, and how much of it may still show:
# [offset, alpha]. Pushed no further than MAX_PUSH; what can't get clear fades.
const MAX_PUSH := 360.0
func clear_of(r: Rect2) -> Array:
	var zones := keep_out()
	var off := Vector2.ZERO
	if zones.is_empty():
		return [off, 1.0]
	var s := size()
	for it in 4:
		var moved := false
		for z in zones:
			var rr := Rect2(r.position + off, r.size)
			if not rr.intersects(z):
				continue
			var best := Vector2.INF
			for cand in [Vector2(z.end.x - rr.position.x, 0.0), Vector2(z.position.x - rr.end.x, 0.0),
					Vector2(0.0, z.end.y - rr.position.y), Vector2(0.0, z.position.y - rr.end.y)]:
				var to := Rect2(rr.position + cand, rr.size)
				# never pushed off the screen
				if to.position.x < 0.0 or to.position.y < 0.0 or to.end.x > s.x or to.end.y > s.y:
					continue
				if cand.length() < best.length():
					best = cand
			if best.is_finite() and (off + best).length() <= MAX_PUSH:
				off += best
				moved = true
		if not moved:
			break
	var fin := Rect2(r.position + off, r.size)
	var hit := 0.0
	for z in zones:
		if fin.intersects(z):
			hit = maxf(hit, fin.intersection(z).get_area() / maxf(fin.get_area(), 1.0))
	return [off, 1.0 - clampf(hit * 1.6, 0.0, 0.9)]


func menu_changed() -> void:
	menu_k.target = 1.0 if game.menu_open else 0.0
	menu_confirm = -1
	menu_page = ""


func contract_changed() -> void:
	card_k.target = 1.0 if game.contract_open else 0.0
	if game.contract_open:
		card_t = 0.0


func mandatory_alert(tag: String, reason: String) -> void:
	alert_text = game.txt("mg_alert") % [tag, game.txt(reason)]
	alert_t = 0.0


# 68 号 §4: the first use of a key in a career, said once on the right
var op_act := ""
var op_t := 99.0
func op_card(action: String) -> void:
	if action in ["down", "left", "right"]:
		action = "up"
	# 80 号: one voice while the guide runs — its card already says the key
	if game.guide_coach() != null:
		return
	if OpCards.first(action):
		op_act = action
		op_t = 0.0


# a hulk towed home: top centre, until the terminal is opened on it (click it, or the terminal key)
# the top-centre stack (user 2026-10-26: these sat on each other): the guide card, then the hulk's
# arrival, then the passing hint line
func arrival_rect(s: Vector2) -> Rect2:
	var y := 118.0
	if _guide_on():
		y = _guide_rect(s).end.y + 10.0
	return Rect2(s.x * 0.5 - 330, y, 660, 92)


func _arrival_card(s: Vector2) -> void:
	var ar: Dictionary = game.arrival
	if ar.is_empty() or game.state != "play":
		return
	var r := arrival_rect(s)
	var k := 0.75 + 0.25 * sin(t * 4.0)
	c.draw_style_box(UiSkin.solid(Color(0.09, 0.105, 0.12, 0.96), 14, 12.0), r)
	c.draw_rect(Rect2(r.position, Vector2(4, r.size.y)), Color(UiSkin.ACCENT, k))
	var head := (Ops.w("%s 拖到港了 · 停在拖船站泊位 %d", "%s IS HOME · TUG YARD BERTH %d") % [str(ar.name), int(ar.get("yard", 1))])
	_text(head, r.position + Vector2(20, 34), 20, Pal.ink(0.96), font_b)
	var line := Ops.w("按 %s（或点这里）打开终端，它的卡已经选好：点“开工拆”就进船坞开拆。", "Press %s (or click here): the terminal opens on its card — start stripping to bring it into the berth.") % Keys.label("terminal")
	if ar.get("held", false):
		line = Ops.w("它被扣在港口（欠费或留置）。按 %s（或点这里）打开终端看原因，处理完才能开拆。", "It is held at the port (a lien or a bill). Press %s (or click here) to see why.") % Keys.label("terminal")
	_text(line, r.position + Vector2(20, 66), 15, Color(UiSkin.ACCENT, 0.95), font)


func _op_card(s: Vector2) -> void:
	if op_act == "" or op_t > OpCards.SHOW_S:
		return
	var a := clampf(op_t / 0.25, 0.0, 1.0) * clampf((OpCards.SHOW_S - op_t) / 0.5, 0.0, 1.0)
	var r := Rect2(s.x - 22.0 - 520.0 + (1.0 - a) * 30.0, 262.0, 520.0, 104.0)
	UI.panel(c, r, 0.94 * a)
	c.draw_rect(Rect2(r.position + Vector2(8, 10), Vector2(3, r.size.y - 20)), Color(UiSkin.ACCENT, a))
	var kr := Rect2(r.position + Vector2(20, 14), Vector2(maxf(44.0, 14.0 * OpCards.key_text(op_act).length() + 16.0), 30))
	c.draw_style_box(UiSkin.box("tag", a), kr)
	_text(OpCards.key_text(op_act), kr.position + Vector2(kr.size.x * 0.5, 21), 15, Pal.ink(0.95 * a), font_b, 0)
	_text(Ops.w("移动", "MOVE") if op_act == "up" else Txt.t("key_" + op_act), Vector2(kr.end.x + 12, kr.position.y + 21), 16, Pal.ink(0.95 * a), font_b, -1)
	var body := OpCards.line(op_act)
	if "：" in body:
		body = body.substr(body.find("：") + 1)
	c.draw_multiline_string(font, r.position + Vector2(20, 68), body, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36.0, 15, 2, Pal.ink(0.82 * a))


# 71 号: the berth short of power says so, once a second worked out
var _sp_t := -1.0
var _sp_text := ""
func _salvage_power(s: Vector2) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _sp_t > 1.0:
		_sp_t = now
		_sp_text = ""
		if Grid.applies(game):
			var gn: Dictionary = Grid.groups_now(game).get("salvage", {})
			var want := float(gn.get("want", 0.0))
			var got := float(gn.get("own", 0.0)) + float(gn.get("shore", 0.0))
			if want > 0.0 and got < want * 0.9:
				_sp_text = Ops.w("电不够：船坞只分到 %.1f / %.1f MW（激光 %d%%、传送带 %d%%、熔炉 %d%%）。修动力区，或在动力区控制屏把拆船区往前调。", "SHORT OF POWER: THE BERTH GETS %.1f / %.1f MW (LASER %d%%, BELT %d%%, FURNACE %d%%).") % [got, want, int(Grid.salvage_k(game, "laser", 0.15) * 100.0), int(Grid.salvage_k(game, "mouth", 0.2) * 100.0), int(Grid.salvage_k(game, "berth_furnace", 0.0) * 100.0)]
	if _sp_text == "":
		return
	var r := Rect2(s.x * 0.5 - 460.0, 176.0, 920.0, 34.0)
	UI.panel(c, r, 0.9)
	c.draw_rect(Rect2(r.position + Vector2(8, 8), Vector2(3, r.size.y - 16)), Pal.heat(0.9, 1.2))
	_text(_sp_text, Vector2(r.position.x + 20, r.position.y + 23), 14, Pal.ink(0.9), font, -1)


func toast_saved() -> void:
	saved_t = 0.0


func close_then(f: Callable) -> void:
	# the shared transition: the heat line closes, the next screen opens as a blueprint
	Wipe.go(game.get_tree(), f)

func show_hint(text: String) -> void:
	hint_text = text
	Playtest.hint(text)
	hint_t = 0.0


func white_flash(a: float) -> void:
	if Txt.no_flash():
		return
	flash = maxf(flash, a)


func hurt_flash(amount: float) -> void:
	hurt = maxf(hurt, clampf(amount / 40.0, 0.3, 1.0))


func pop_credits(_amount: float) -> void:
	credit_pop = 1.0


func fly_credits(world_at: Vector2, amount: float) -> void:
	var from := to_screen(world_at)
	var s := size()
	flyers.append([from, Vector2(s.x - 70.0, 76.0), 0.0, amount])


func start_ending(early: bool) -> void:
	ending = true
	end_t = 0.0
	end_early = early
	var g = game
	end_rows = [
		["e_equip", g.income_equip],
		["e_metal", g.income_metal + g.income_hazard],
		["e_fluid", g.sys.gas_value() + g.sys.fluid_value() if g.scope() == "full" else 0.0],
		["e_loss", -g.losses],
		["e_fee_paid" if g.job.get("fee_paid", false) else "e_fee", -g.fee],
	]
	if g.income_rest > 0.0:
		end_rows.append(["e_rest", g.income_rest])
	for b in g.bonuses():
		end_rows.append(b)


# the career's books after this contract: [label key, amount, kind]
func career_rows() -> Array:
	var r: Dictionary = game.career_result
	if r.is_empty():
		return []
	# the installment and interest only while there is a debt
	var out: Array = []
	var order: Dictionary = r.get("work_order",{})
	if not order.is_empty():
		var orders = load("res://scripts/work_orders.gd")
		out.append(["e_work_order",orders.text(str(order.id)),"text"])
		if order.get("completed",false):
			var reward := game.txt("g4_reward_access" if order.id == "access" else "g4_reward_rigging")
			if order.id == "heavy": reward = game.txt("g4_reward_stock") if order.get("reward","") == "field_stock" else Repair.name_of(str(order.reward))
			out.append(["e_work_reward",reward,"text"])
			if float(order.get("cash_cost",0.0)) > 0.0: out.append(["e_work_assembly",-float(order.cash_cost),"money"])
			if float(order.get("surplus_cash",0.0)) > 0.0: out.append(["e_work_surplus",float(order.surplus_cash),"money"])
		elif order.get("sold",false): out.append(["e_work_status",game.txt("g4_order_sold"),"text"])
		else: out.append(["e_work_status",game.txt("g4_order_pending"),"text"])
	# 64 号: the furnace's scrap went into the warehouse as ingots
	if float(r.get("ingot_t", 0.0)) > 0.0005:
		out.append(["e_ingots", Ops.w("%.1f 吨，下一页定：直卖或留着加工", "%.1f t: sell or process, on the next page") % float(r.ingot_t), "text"])
	if float(r.installment) > 0.5 or float(r.interest) > 0.5:
		out.append_array([["e_inst", -float(r.installment), "money"], ["e_interest", -float(r.interest), "money"]])
	if float(r.short) > 0.5:
		out.append(["e_short", float(r.short), "note"])
	var used: Dictionary = r.get("used", {})
	if not used.is_empty():
		var parts: Array = []
		for k in used:
			parts.append("%s ×%d" % [game.txt("it_" + k), int(used[k])])
		out.append(["e_used", ", ".join(parts), "text"])
	# the parts for the berth and what to work for next (scripts/repair.gd)
	var pr: Dictionary = r.get("parts", {})
	if not pr.is_empty() and (not pr.get("tags", []).is_empty() or float(pr.get("tons", 0.0)) > 0.05):
		if not pr.get("tags", []).is_empty():
			out.append(["e_parts_in", game.txt("e_parts_in_v") % [pr.tags.size(), Pal.money(float(pr.value))], "text"])
		if float(pr.get("tons", 0.0)) > 0.05:
			out.append(["e_structure_in", "%.1f t" % float(pr.tons), "text"])
	# G5.1: the scrap kept as raw material, and the cash it did not bring
	var mat: Dictionary = r.get("materials", {})
	if float(mat.get("mass_t", 0.0)) > 0.0005:
		out.append(["e_retained", "%.2f t" % float(mat.mass_t), "text"])
		out.append(["e_retained_cash", Pal.money(float(r.get("retained_value", 0.0))), "text"])
		out.append(["e_retained_next", game.txt("e_retained_next_v"), "text"])
	if float(r.get("trade_bonus", 0.0)) > 0.5:
		out.append(["e_trade_bonus", float(r.trade_bonus), "money"])
	if float(r.get("tow", 0.0)) > 0.5:
		out.append(["e_tow_fee", -float(r.tow), "money"])
	if float(r.get("tow_owed", 0.0)) > 0.5:
		out.append(["e_tow_owed", -float(r.tow_owed), "money"])
	if float(r.get("spot_paid", 0.0)) > 0.5:
		out.append(["e_spot_paid", -float(r.spot_paid), "money"])
	# 108 号 Q6 A: the showcase job against the same type before, or the job's own yardstick
	var sc: Dictionary = r.get("showcase", {})
	if not sc.is_empty():
		var mins := func(s: float) -> String: return "%d:%02d" % [int(s) / 60, int(s) % 60]
		out.append(["e_showcase", "%s · %s · %s · %s" % [Methods.name_of(str(sc.id)), str(sc.use), mins.call(float(sc.time)), Pal.money(float(sc.net))], "text"])
		if sc.has("before"):
			out.append(["e_showcase_before", "%s · %s" % [mins.call(float(sc.before.time)), Pal.money(float(sc.before.net))], "text"])
		else:
			out.append(["e_showcase_std", "%s · %s" % [mins.call(float(sc.std_time)), Pal.money(float(sc.value))], "text"])
	var sg: Dictionary = r.get("suggest", {})
	if not sg.is_empty():
		if sg.get("ready", false):
			out.append(["e_next_repair", game.txt("e_next_ready") % str(sg.name), "text"])
		else:
			var lack: Array = sg.get("lack", [])
			var line: String = str(sg.name) + (("  ·  " + game.txt("e_next_lack") % ", ".join(lack)) if not lack.is_empty() else "")
			if float(sg.get("short", 0.0)) > 0.5:
				line += "  ·  " + game.txt("e_next_short") % Pal.money(float(sg.short))
			out.append(["e_next_repair", line, "text"])
			if not sg.get("ships", []).is_empty():
				out.append(["e_next_ships", ", ".join(sg.ships), "text"])
	# the field gear: back, lost, achieved, opened (scripts/gear.gd)
	var gr: Dictionary = r.get("gear", {})
	if not gr.is_empty():
		if not gr.get("back", []).is_empty():
			out.append(["e_gear_back", _gear_list(gr.back), "text"])
		if not gr.get("lost", []).is_empty():
			out.append(["e_gear_lost", "%s  −%s" % [_gear_list(gr.lost), Pal.money(float(gr.lost_cost))], "text"])
		if not gr.get("lent_lost", []).is_empty():
			out.append(["e_gear_lent_lost", _gear_list(gr.lent_lost), "text"])
		for f in gr.get("feats", []):
			out.append(["e_feats", game.txt("feat_" + str(f)), "text"])
		if not gr.get("grants", []).is_empty():
			out.append(["e_gear_grant", _gear_list(gr.grants), "text"])
	# 104 号: a dismantling method learned on this job (the borrow job, or an achievement)
	for mid in r.get("learned", []):
		out.append(["e_learned", "%s · %s" % [Methods.name_of(str(mid)), Methods.does(str(mid))], "text"])
	if not gr.is_empty():
		for f in gr.get("feats", []):
			var g: String = Gear.FEAT_GRANT.get(f, "")
			if g != "":
				out.append(["e_gear_next", game.txt("gear_next_buy") % Gear.name_of(g), "text"])
	# 第一关结算时白送的设备（career.gd GIFT_HAULER_AFTER）
	var granted: Array = r.get("granted", [])
	if not granted.is_empty():
		var gifts: Array = []
		for id in granted:
			gifts.append(game.txt("fa_" + str(id)))
		out.append(["e_gift", ", ".join(gifts), "text"])
	if float(r.loan) > 0.5:
		out.append(["e_loan_left", float(r.loan), "plain"])
	out.append(["e_funds", float(r.money), "plain"])
	return out


# gear types with their counts, in a line
func _gear_list(types: Array) -> String:
	var n := {}
	var order: Array = []
	for t in types:
		if not n.has(t):
			order.append(t)
		n[t] = int(n.get(t, 0)) + 1
	var parts: Array = []
	for t in order:
		parts.append(Gear.name_of(str(t)) + (" ×%d" % n[t] if n[t] > 1 else ""))
	return ", ".join(parts)


func ending_key(k: int) -> void:
	if end_t < 1.0:
		end_t = 9.0
		return
	if game.career():
		# settled with the career: no second go at the same contract
		if game.story == null or not game.story.wants_epilogue():
			# 106 号: the goods' second page first, while anything is left to decide
			if not Disposal.pending().is_empty() and game.open_disposal():
				return
			game.leave()
		return
	if k == KEY_R:
		game.restart()
	elif k == KEY_M or k == KEY_ESCAPE:
		if game.dev_job():
			game.leave()
		else:
			game.to_title()


func _input(ev: InputEvent) -> void:
	# the settlement's second page (disposal_panel.gd) sits over the ending screen: its clicks are its own
	if game == null or game.get("disposal_ui") != null:
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if game.contract_open and card_t > 0.35:
			var cr := _card_rect(size())
			# only the start button starts: a stray click on the card does nothing
			if _start_rect(cr).has_point(c.get_local_mouse_position()):
				game.close_contract()
			elif game.codex_hud != null and game.codex_hud.brief_rect.has_point(c.get_local_mouse_position()):
				game.codex_hud.open_brief()
			get_viewport().set_input_as_handled()
			return
		if game.menu_open:
			get_viewport().set_input_as_handled()
			_menu_click()
			return
		if not game.arrival.is_empty() and game.state == "play" and arrival_rect(size()).has_point(c.get_local_mouse_position()):
			game.open_console("terminal")
			get_viewport().set_input_as_handled()
			return
		if ending:
			if end_t < 4.0:
				end_t = 9.0
			elif game.story != null and game.story.phase == "settle":
				game.story.ending_key(KEY_SPACE)
			get_viewport().set_input_as_handled()
			return
		var item := _item_at(c.get_local_mouse_position()) if game.state == "play" else ""
		if item != "":
			match item:
				"repair": game.repair_kit()
				"ring": game.arm_ring(not game.ring_armed)
			get_viewport().set_input_as_handled()
		elif game.state == "play" and _toolbar_rect().has_point(c.get_local_mouse_position()):
			var i := int((c.get_local_mouse_position().x - _toolbar_rect().position.x) / 142.0)
			game.tools.set_tool(clampi(i + 1, 1, _slots()))
			get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	if game == null:
		return
	if closing >= 0.0:
		closing += dt
		if closing > 0.5 and after_close.is_valid():
			var f := after_close
			after_close = Callable()
			f.call()
	t += dt
	hint_t += dt
	op_t += dt
	alert_t += dt
	saved_t += dt
	flash = maxf(0.0, flash - dt * 2.5)
	hurt = maxf(0.0, hurt - dt * 1.8)
	credit_pop = maxf(0.0, credit_pop - dt * 3.0)
	card_t += dt
	card_k.step(dt)
	menu_k.step(dt)
	if ending:
		end_t += dt
	if game.state == "play":
		in_t += dt
	elif game.state == "intro":
		in_t = 0.0
	var rt: float = game.recovery_rate() * 100.0
	if rt > rate_last + 0.05:
		rate_sweep = 0.0
		for i in 3:
			if rate_last < [70.0, 80.0, 92.0][i] and rt >= [70.0, 80.0, 92.0][i]:
				mark_pop[i] = 0.0
	rate_last = rt
	rate_sweep += dt
	for i in 3:
		mark_pop[i] += dt
	rate_roll.set_to(rt)
	rate_roll.step(dt)
	# the fresh gain glows, then the trail catches up
	rate_lo = rate_roll.shown if rate_roll.shown < rate_lo else Pal.damp(rate_lo, rate_roll.shown, 1.6, dt)
	_motion_drone(dt)
	_place_minimap()
	credit_roll.set_to(game.earned() - game.losses)
	credit_roll.step(dt)
	var mp := c.get_local_mouse_position()
	var tb := _toolbar_rect()
	if absf(sel_x.target - (game.tools.tool - 1)) > 0.01:
		tool_pulse = 0.0
	sel_x.target = game.tools.tool - 1
	sel_x.step(dt)
	tool_pulse += dt
	for i in _slots():
		var on: bool = game.tools.tool == i + 1
		var over := Rect2(tb.position.x + i * 142.0, tb.position.y + 14.0, 132.0, 70.0).has_point(mp)
		slot_y[i].target = -12.0 if on else (-5.0 if over else 0.0)
		slot_y[i].step(dt)
		slot_glow[i] = Pal.damp(slot_glow[i], 1.0 if on else 0.0, 14.0, dt)
	var items: Array = game.mandatory_items()
	must_k.resize(items.size())
	for i in items.size():
		var mk = must_k[i] if must_k[i] != null else 0.0
		var ok: bool = game.mandatory_ok.get(items[i][0], false)
		if ok and not must_t.has(i):
			must_t[i] = t
		elif not ok:
			must_t.erase(i)
		must_k[i] = Pal.damp(mk, 1.0 if ok else 0.0, 8.0, dt)
	for f in flyers:
		f[2] += dt
	var landed := flyers.filter(func(f): return f[2] >= 0.6)
	if not landed.is_empty():
		credit_pop = 1.0
		for f in landed:
			bursts.append([f[1], 0.0])
	for b in bursts:
		b[1] += dt
	bursts = bursts.filter(func(b): return b[1] < 0.45)
	flyers = flyers.filter(func(f): return f[2] < 0.6)
	if game.menu_open:
		_menu_hover()
	cur_t += dt
	cur_out += dt
	cur.target = mp
	cur.step(dt)
	_guide_keys()
	c.queue_redraw()
	fadd.queue_redraw()


# the map stays on screen while working the ship; menus, cards and the
# blueprint cover it, and the lessons and the exam keep their own screens
func _place_minimap() -> void:
	var g = game
	minimap.game = g
	var bpk: float = g.blueprint.k if g.blueprint != null else 0.0
	var on: bool = g.state == "play" and not ending and not g.menu_open and not g.contract_open and card_k.x < 0.01 and menu_k.x < 0.01 and bpk < 0.05 and not g.training and g.exam == null
	minimap.visible = on
	if on:
		if minimap.mode == "berth" and (minimap.map_size.y <= 0.0 or minimap._ship_sig.is_empty()):
			minimap.layout()
		var s := size()
		minimap.position = Vector2(s.x - 40.0 - minimap.map_size.x, s.y - 40.0 - minimap.map_size.y + (1.0 - _in(2)) * 200.0)


func _motion_drone(dt: float) -> void:
	var d = game.drone
	var integ: float = d.integrity if d.alive else 0.0
	if integ < integ_prev - 0.01:
		integ_hold = 0.0
	integ_prev = integ
	integ_hold += dt
	if integ >= integ_ghost:
		integ_ghost = integ
	elif integ_hold > 0.4:
		integ_ghost = Pal.damp(integ_ghost, integ, 5.0, dt)
	integ_roll.set_to(integ)
	integ_roll.step(dt)
	spd_roll.set_to(d.linear_velocity.length() / Geom.M if d.alive else 0.0)
	spd_roll.step(dt)
	stock_pop += dt
	if game.career():
		for id in ["repair", "ring", "spare"]:
			var n: int = game.stock(id)
			if stock_last.has(id) and stock_last[id] != n:
				stock_pop = 0.0
				stock_hit = id
			stock_last[id] = n


# 0 → 1 as the HUD piece `i` comes in after the launch
func _in(i: int) -> float:
	# full animation boots the panels in place instead of sliding them (_boot)
	if Txt.anim_level() != 1:
		return 1.0
	return Pal.ease_out(Motion.stagger(in_t, i, 0.07, 0.55))


# a panel's boot (full animation): 0 dark, 1 on; one after another as the drone comes out
func _boot(i: int) -> float:
	if Txt.anim_level() < 2:
		return 1.0
	return Motion.stagger(maxf(0.0, in_t - 0.15), i, 0.16, 0.8)


func _contract_rect() -> Rect2:
	var g = game
	var y := 46.0
	var items0: Array = _title_items()
	var by0 := maxf(y + 120, y + 56 + items0.size() * 24 + 18)
	var lrow := 0.0 if g.training or g.exam != null else 24.0
	var ph := by0 - y + 80.0 + lrow + (56.0 if g.scope() != "full" else 0.0)
	return Rect2(40.0 - 18, y - 30, 340, ph)


# ---------------------------------------------------------------- drawing helpers

func _text(s: String, pos: Vector2, size_px: int, col: Color, f: Font = null, align: int = -1, width: float = -1.0) -> void:
	var fo := f if f != null else font
	var x := pos.x
	if align == 0:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x * 0.5
	elif align == 1:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	# 91 号: on site the text is burned into the camera picture, the way a drone's OSD is — a
	# black outline round every letter keeps it legible over anything
	# 117 号 (Q4 A): and a soft dark halo hugging the letters, so a hull line behind never cuts
	# through a word — no plate, the panels stay bare. The halo goes on its own canvas item under
	# all the HUD's text: drawn in line with it, a wide halo would black out the line above.
	if UiSkin.field and col.a > 0.05:
		for h in (HALO if halo_on else []):
			fo.draw_string_outline(halo_rid, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, width, size_px, h[0], Color(0, 0, 0, h[1] * minf(col.a * 2.0, 1.0)))
		c.draw_string_outline(fo, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, width, size_px, 4, Color(0, 0, 0, 0.85 * col.a))
	c.draw_string(fo, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, width, size_px, col)


# the hull's lines are HDR-bright: one faint layer barely dims them, so two, the denser nearer
const HALO := [[34, 0.6], [18, 0.95]]
var halo_rid: RID
static var halo_on := true    # tests: the old look side by side


# c's transform, and the halo's with it
func _xform(pos: Vector2, rot := 0.0, sc := Vector2.ONE) -> void:
	c.draw_set_transform(pos, rot, sc)
	RenderingServer.canvas_item_add_set_transform(halo_rid, Transform2D(rot, sc, 0.0, pos))


# the same for a wrapped paragraph
func _mtext(s: String, pos: Vector2, width: float, size_px: int, lines: int, col: Color, f: Font = null) -> void:
	var fo := f if f != null else font
	if UiSkin.field and col.a > 0.05:
		for h in (HALO if halo_on else []):
			fo.draw_multiline_string_outline(halo_rid, pos, s, HORIZONTAL_ALIGNMENT_LEFT, width, size_px, lines, h[0], Color(0, 0, 0, h[1] * minf(col.a * 2.0, 1.0)))
		c.draw_multiline_string_outline(fo, pos, s, HORIZONTAL_ALIGNMENT_LEFT, width, size_px, lines, 4, Color(0, 0, 0, 0.85 * col.a))
	c.draw_multiline_string(fo, pos, s, HORIZONTAL_ALIGNMENT_LEFT, width, size_px, lines, col)


func _tw(s: String, size_px: int, f: Font = null) -> float:
	return (f if f != null else font).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x


func _panel(r: Rect2, a: float = 0.82) -> void:
	UI.panel(c, r, a / 0.95)


# ---------------------------------------------------------------- main draw

func _draw_hud() -> void:
	RenderingServer.canvas_item_clear(halo_rid)
	if game == null:
		return
	# 91 号 遥控 Q6 C: on site the panels are the camera feed's overlay, not glass cards
	UiSkin.field = Look.on and game.look != null
	_draw_hud_body()
	UiSkin.field = false


func _draw_hud_body() -> void:
	var s := size()
	var g = game
	if g.state == "intro":
		_intro_overlay(s)
		return
	if g.state == "towout":
		_radio_box(s)
		return
	if g.state == "survey":
		_survey_overlay(s)
		_radio_box(s)
		return
	if g.state == "build":
		_build_overlay(s)
		return
	if g.state == "nuke":
		return
	if not ending and g.state != "ending":
		_world_tags()
		_messages()
		_gauge()
		_cursor_label()
		if not g.training and g.exam == null and not g.in_berth():
			var bpk: float = g.blueprint.k if g.blueprint != null else 0.0
			_xform(Vector2(-(1.0 - _in(0) * (1.0 - Pal.ease_io(bpk))) * 420.0, 0.0))
			# booting: the edge and plate first, the content only once it is uncovered
			if _boot(0) < 0.45:
				UI.panel(c, _contract_rect(), 0.82, 0.0, Pal.HEAT, _boot(0))
			else:
				_contract_panel()
				UI.boot_cover(c, _contract_rect(), _boot(0))
				_asset_board(_contract_rect())
			_xform(Vector2.ZERO)
		_overweight()
		_tearing()
		_left_markers(s)
		_boundary(s)
		_haul_guide(s)
		if not g.training and g.exam == null and not g.in_berth():
			_next_mark(s)
		if g.warp:
			_warp(s)
		_xform(Vector2((1.0 - _in(1)) * 380.0, 0.0))
		if g.in_berth():
			pass   # 61 号 (60 号 Q8): no status strip in the empty berth; the main-line card guides
		elif _boot(1) < 0.45:
			UI.panel(c, Rect2(s.x - 290.0, 22, 268, 86), 0.82, 0.0, Pal.HEAT, _boot(1))
		else:
			_credits(s)
			UI.boot_cover(c, Rect2(s.x - 290.0, 22, 268, 86), _boot(1))
		_machines(s)
		_work_order(s)
		_xform(Vector2.ZERO)
		_toolbar(s)
		_xform(Vector2(0.0, (1.0 - _in(2)) * 140.0))
		if _boot(2) < 0.45:
			UI.panel(c, Rect2(22.0, s.y - 106.0, 420, 70), 0.82, 0.0, Pal.HEAT, _boot(2))
		else:
			_drone_status(s)
			UI.boot_cover(c, Rect2(22.0, s.y - 106.0, 420, 70), _boot(2))
		_xform(Vector2.ZERO)
		_hint(s)
		_guide(s)
		_op_card(s)
		_arrival_card(s)
		_salvage_power(s)
		_radio_box(s)
		var ka := clampf((40.0 - g.playtime) / 3.0, 0.0, 1.0)
		if ka > 0.01:
			_text(g.txt("keys_berth") % [Keys.label("terminal"), Keys.label("port")] if g.in_berth() else g.txt("keys"), Vector2(s.x * 0.5, s.y - 6.0), 15, Pal.ink(0.72 * ka), font, 0)
	# hurt vignette
	if hurt > 0.0:
		var e := hurt * hurt
		for i in 6:
			var w := 6.0 + i * 10.0
			var a := 0.1 * e * (1.0 - i / 6.0)
			c.draw_rect(Rect2(0, 0, s.x, w), Pal.heat(a))
			c.draw_rect(Rect2(0, s.y - w, s.x, w), Pal.heat(a))
			c.draw_rect(Rect2(0, 0, w, s.y), Pal.heat(a))
			c.draw_rect(Rect2(s.x - w, 0, w, s.y), Pal.heat(a))
	if alert_t < 7.0 and not ending:
		_alert(s)
	if show_log and not ending:
		_radio_log(s)
	if saved_t < 1.8 and not ending:
		var sa := clampf(saved_t / 0.2, 0.0, 1.0) * clampf((1.8 - saved_t) / 0.4, 0.0, 1.0)
		_text("● " + game.txt("autosaved"), Vector2(40, s.y - 118), 13, Pal.ink(0.7 * sa), font)
	if g.contract_open or card_k.x > 0.01:
		_contract_card(s)
	if menu_k.x > 0.01:
		_menu(s)
	if ending:
		if g.story == null or g.story.phase in ["", "settle"]:
			_settlement(s)
		_radio_box(s)
	elif g.exam != null and g.state == "ending":
		_radio_box(s)
	if flash > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, flash * flash * 0.8))
	_open_wipe(s)
	if closing >= 0.0:
		var e := Pal.ease_in(clampf(closing / 0.42, 0.0, 1.0))
		var h := s.y * 0.5 * e
		c.draw_rect(Rect2(0, 0, s.x, h), Color(0, 0, 0, 1))
		c.draw_rect(Rect2(0, s.y - h, s.x, h), Color(0, 0, 0, 1))
		c.draw_rect(Rect2(0, s.y * 0.5 - 1, s.x, 2), Pal.heat(e, 2.0))


# the scene opens out of the heat line the last one closed on: no hard cut
func _open_wipe(s: Vector2) -> void:
	# the shared transition opens this screen when it covered the change
	if t > 0.6 or Wipe.busy() or Wipe.arrived() or Txt.anim_level() == 0:
		return
	var e := Pal.ease_out(clampf((t - 0.05) / 0.5, 0.0, 1.0))
	var h := s.y * 0.5 * (1.0 - e)
	c.draw_rect(Rect2(0, 0, s.x, h), Color(0, 0, 0, 1))
	c.draw_rect(Rect2(0, s.y - h, s.x, h), Color(0, 0, 0, 1))
	var la := 1.0 - clampf((t - 0.15) / 0.4, 0.0, 1.0)
	c.draw_rect(Rect2(0, h - 1, s.x, 2), Pal.heat(la, 2.0))
	c.draw_rect(Rect2(0, s.y - h - 1, s.x, 2), Pal.heat(la, 2.0))


# Liang on the radio (name, waveform, words typing in) or the berth terminal
# (cyan, block cursor), bottom centre above the toolbar
const RADIO_W := 700.0


func _radio_box(s: Vector2) -> void:
	var rd: Radio = game.radio
	var ln: Dictionary = rd.now
	if ln.is_empty():
		return
	var line: Dictionary = ln.line
	var term: bool = line.get("who", "liang") == "term"
	var full: String = rd.text(line)
	var lt: float = ln.t
	var a := clampf(lt / 0.2, 0.0, 1.0) * clampf((ln.dur - lt) / 0.3, 0.0, 1.0)
	var shown := full.substr(0, int(lt * 30.0))
	var w := 820.0
	# a long line wraps to two; the box grows upwards
	var two := _tw(full, 18) > RADIO_W
	var h := 92.0 if two else 64.0
	var r := Rect2(s.x * 0.5 - w * 0.5, s.y - 146.0 - h + (1.0 - Pal.ease_out(clampf(lt / 0.25, 0.0, 1.0))) * 14.0, w, h)
	c.draw_style_box(UiSkin.box("panel", a), r)
	c.draw_rect(Rect2(r.position + Vector2(8, 10), Vector2(3, r.size.y - 20)), (Color(UiSkin.DATA, a) if term else Color(UiSkin.ACCENT, a)))
	# 75 号: a caller at the trade port's pier, or a company's contact, speaks for themselves
	var who_s := str(line.get("who", "liang"))
	var who_label: String = game.txt("tut_term") if term else (Ops.w("贸易港 · 客人", "TRADE PORT · CALLER") if who_s == "client" else game.txt("tut_liang"))
	_text(who_label, r.position + Vector2(18, 22), 13, Pal.ink(0.5 * a), font)
	# the voice as a little waveform while the words come in
	var typing := shown.length() < full.length()
	for i in 14:
		var hgt := 2.0 + (8.0 * absf(sin(t * 17.0 + i * 1.7)) * absf(sin(t * 5.3 + i)) if typing else 1.0)
		c.draw_rect(Rect2(r.position.x + 18 + i * 4.0, r.position.y + 44 - hgt * 0.5, 2, hgt), Pal.ink(0.35 * a))
	var col := Pal.tint(Pal.AIR, 0.95 * a, 1.1) if term else Pal.ink(0.95 * a)
	if two:
		c.draw_multiline_string(font, r.position + Vector2(90, 40), shown, HORIZONTAL_ALIGNMENT_LEFT, RADIO_W, 18, 2, col)
		return
	_text(shown, r.position + Vector2(90, 44), 18, col, font)
	if term and typing:
		var cw := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		c.draw_rect(Rect2(r.position.x + 92 + cw, r.position.y + 30, 9, 16), Pal.tint(Pal.AIR, a * (0.5 + 0.5 * sin(t * 20.0))))


# time warp: chevrons stream across, the factor in the middle
func _warp(s: Vector2) -> void:
	var cx := s.x * 0.5
	for i in 6:
		var ph := fmod(t * 1.6 + i / 6.0, 1.0)
		var a := sin(ph * PI) * 0.8
		for side in [-1.0, 1.0]:
			var x: float = cx + side * (34.0 + ph * 70.0)
			var p := Vector2(x, 34.0)
			FastDraw.polyline(c, PackedVector2Array([p + Vector2(-4, -6), p + Vector2(3, 0), p + Vector2(-4, 6)]), Pal.heat(a, 1.2), 1.6, true)
	_text("×%d" % int(Game.WARP), Vector2(cx, 40), 16, Pal.heat(0.95, 1.3), font_b, 0)


# hauling: where this load should go, by what it is (hazard first, whole
# equipment to the equipment mouth, the rest to the furnace) — a ring on the
# mouth when it is on screen, an arrow at the screen edge when it is not
func _haul_guide(s: Vector2) -> void:
	var tl = game.tools
	if tl.held_body == null or not is_instance_valid(tl.held_body) or tl.overweight:
		return
	var zone := _zone_for(tl.held_body)
	# the player's grapple can't swing a load round: the mouth it goes in as it lies
	var destination := Dock.for_load(zone,tl.held_body,false)
	if destination == "":
		# 78 号 P0-1: no mouth takes it whole — say so where the guide arrow would be
		_text(Dock.no_mouth_text(tl.held_body,false), Vector2(size().x * 0.5, size().y - 190.0), 15, Pal.heat(0.95, 1.2), font, 0)
		return
	var wp: Vector2 = Dock.zpos(destination)
	var com0: Vector2 = tl.held_body.global_transform * tl.held_body.center_of_mass
	if zone == "metal":
		var tp := Dock.trough_below(com0)
		if tp.distance_to(com0) < wp.distance_to(com0):
			wp = tp
	var sp := to_screen(wp)
	var dist: float = (tl.held_body.global_transform * tl.held_body.center_of_mass).distance_to(wp) / Geom.M
	var col := Pal.tint(Pal.FLUID, 0.95, 1.2) if zone == "hazard" else (Pal.ink(0.95, 1.2) if zone == "equip" else Pal.heat(0.95, 1.3))
	var lbl := "%s  %.0f m" % [game.txt("zone_equip_bulk" if destination == "equip_bulk" else "zone_" + zone), dist]
	var inner := Rect2(Vector2(70, 70), s - Vector2(140, 140))
	if inner.has_point(sp):
		var pr := 26.0 + 4.0 * sin(t * 6.0)
		FastDraw.arc(c, sp, pr, 0.0, TAU, 40, col, 2.0, true)
		_text(lbl, sp + Vector2(pr + 10, 6), 15, col, font_b)
		return
	# off screen: an arrow on the edge, pointing at it
	var cpos := s * 0.5
	var dir := (sp - cpos).normalized()
	var tt := INF
	if absf(dir.x) > 0.001:
		tt = minf(tt, ((inner.end.x if dir.x > 0.0 else inner.position.x) - cpos.x) / dir.x)
	if absf(dir.y) > 0.001:
		tt = minf(tt, ((inner.end.y if dir.y > 0.0 else inner.position.y) - cpos.y) / dir.y)
	var at := cpos + dir * tt
	var n := dir.orthogonal()
	var bob := dir * 5.0 * sin(t * 6.0)
	FastDraw.poly(c, PackedVector2Array([at + bob + dir * 18.0, at + bob - dir * 6.0 + n * 12.0, at + bob - dir * 6.0 - n * 12.0]), col)
	var lw := _tw(lbl, 15, font_b)
	var lp := at - dir * 34.0 - Vector2(lw * 0.5, -6)
	c.draw_style_box(UiSkin.box("tag", 0.85), Rect2(lp - Vector2(8, 20), Vector2(lw + 16, 28)))
	_text(lbl, lp, 15, col, font_b)


# a section contract: the frame where the section starts, drawn across the ship
func _boundary(s: Vector2) -> void:
	var bx: float = game.boundary()
	if bx < 0.0:
		return
	var top := to_screen(Vector2(bx, -5.6) * Geom.M)
	var bot := to_screen(Vector2(bx, 5.2) * Geom.M)
	if top.x < -40.0 or top.x > s.x + 40.0:
		return
	c.draw_dashed_line(top, bot, Pal.heat(0.85, 1.3), 2.0, 12.0)
	var lbl: String = game.txt("sc_boundary")
	c.draw_style_box(UiSkin.box("tag", 0.85), Rect2(top + Vector2(8, -30), Vector2(_tw(lbl, 14, font_b) + 16, 26)))
	_text(lbl, top + Vector2(16, -11), 14, Pal.heat(0.95, 1.2), font_b)
	# the section side is lit, the other side carries the breach warning
	_text("→", top + Vector2(-6, 20), 18, Pal.heat(0.9, 1.3), font_b, 0)


func _zone_for(b) -> String:
	var equip := false
	var metal_m := 0.0
	var all_m := 0.0
	for p in b.pieces:
		all_m += p.mass
		if game.sys.dest_of(p) == "hazard":
			return "hazard"
		if p.cls == "equip" and p.intact:
			equip = true
		else:
			metal_m += p.mass
	var assembly: bool = game.work_order != null and game.work_order.accepts_assembly(b)
	return "equip" if equip and (metal_m <= all_m * 0.2 or assembly) else "metal"

# the grapple refuses a load over its rating, and says so in numbers
func _overweight() -> void:
	var tl = game.tools
	if not tl.overweight or tl.held_piece == null:
		return
	var m: float = tl.held_body.total_mass() if tl.held_body != null and is_instance_valid(tl.held_body) else game.world.group_mass(tl.held_piece)
	var p := to_screen(tl.grab_point()) + Vector2(24, -46)
	var rows := ["TARGET MASS: %.1f t" % m, "RATED CAPACITY: %.1f t" % game.grab_max(), "OPERATION REFUSED"]
	# 106 号: what the berth's crane can do about it — mended or not, within its rating or not
	var crane_line := crane_note(m)
	var wd := maxf(230.0, font.get_string_size(crane_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 20.0)
	_panel(Rect2(p - Vector2(10, 18), Vector2(wd, 70 + (20 if crane_line != "" else 0))), 0.86)
	for i in 3:
		_text(rows[i], p + Vector2(0, i * 20), 13, Pal.heat(0.95, 1.2) if i == 2 else Pal.ink(0.85), font_b if i == 2 else font)
	if crane_line != "":
		_text(crane_line, p + Vector2(0, 60), 13, Pal.tint(Pal.AIR, 0.95, 1.2), font)


# the crane's word on a load the drone cannot pull ("" where the berth has no crane to speak of)
func crane_note(m: float) -> String:
	if game.crane != null:
		if m > Methods.crane_t():
			return Ops.w("超过吊车额定 %.0f t：先切小", "OVER THE CRANE'S %.0f t: CUT IT SMALLER") % Methods.crane_t()
		if game.manual_only():
			return Ops.w("这艘只许人工：按 %s 交给吊车", "MANUAL-ONLY SHIP: %s TO GIVE IT TO THE CRANE") % Keys.label("mark")
		return Ops.w("松手：吊车会来整件吊走", "LET GO: THE CRANE WILL LIFT IT WHOLE")
	if game.crane_wreck != null:
		return Ops.w("门式吊车坏了：修好就能整件吊走（%.0f t 以内）", "THE CRANE IS DOWN: MENDED, IT LIFTS THIS WHOLE (UP TO %.0f t)") % Methods.CRANE_T[1]
	return ""


func _intro_overlay(s: Vector2) -> void:
	var k := clampf(game.state_t / 0.6, 0.0, 1.0) * clampf((6.0 - game.state_t) / 0.6, 0.0, 1.0)
	# what is coming in: the ship file's own title
	var g = game
	var head: String = g.txt("tut_course") if g.training else ("APPRENTICE ASSESSMENT" if g.exam != null else (g.txt("contract") + " " + g.ship.get("contract", "")).strip_edges())
	var ttl: Array = g.ship.get("title", [])
	_text(head, Vector2(70, s.y - 120), 16, Pal.ink(0.5 * k), font)
	_text((ttl[0] if Txt.zh else ttl[1]) if ttl.size() == 2 else g.ship.get("name", ""), Vector2(70, s.y - 86), 30, Pal.ink(0.9 * k), font_l)
	_text("ESC / SPACE", Vector2(s.x - 70, s.y - 60), 13, Pal.ink(0.5 * k), font, 1)
	# letterbox bars slide away as the drone launches
	var bar := 70.0 * clampf((5.2 - game.state_t) / 0.6, 0.0, 1.0)
	c.draw_rect(Rect2(0, 0, s.x, bar), Color(0, 0, 0, 1))
	c.draw_rect(Rect2(0, s.y - bar, s.x, bar), Color(0, 0, 0, 1))


# the survey pass after the contract is signed: letterbox, the station the
# scan line stands at while the camera flies the hull, then the ship framed and
# measured (brackets, length and height with arrowheads, the centre of mass)
func _survey_overlay(s: Vector2) -> void:
	var g = game
	var sv: Dictionary = g.survey
	if sv.is_empty():
		return
	var M := Geom.M
	var ph: Array = g.survey_phase()
	var tt: float = g.state_t
	var k_in := Pal.ease_out(clampf(tt / 0.4, 0.0, 1.0)) * clampf((float(sv.t_end) - tt) / 0.35, 0.0, 1.0)
	var xf: Transform2D = g.get_viewport().get_canvas_transform()
	var bar := 70.0 * k_in
	var hc := Pal.tint(Pal.AIR, 0.9, 1.1)
	# the scan line at the middle of the view while the hull goes by
	if ph[0] == "pass" or (ph[0] == "" and tt < float(sv.t_in)):
		var cx := s.x * 0.5
		var a := k_in * clampf(tt / 0.8, 0.0, 1.0)
		c.draw_line(Vector2(cx, bar + 10.0), Vector2(cx, s.y - bar - 10.0), Pal.tint(Pal.AIR, 0.35 * a, 1.3), 1.4)
		var wx: float = (xf.affine_inverse() * Vector2(cx, s.y * 0.5)).x
		var sta: float = (wx - float(sv.x0)) / M
		_text(g.txt("sv_sta") % maxf(0.0, sta), Vector2(cx + 10.0, bar + 34.0), 14, Pal.tint(Pal.AIR, 0.85 * a, 1.1), font_b)
		# the rooms the line is crossing
		var names: Array = []
		for r in g.world.rooms:
			var bb: Rect2 = g.world.rooms[r].bbox
			if wx >= bb.position.x + g.world.position.x and wx <= bb.end.x + g.world.position.x and names.size() < 3:
				names.append(g.room_name(r))
		if not names.is_empty():
			_text(" · ".join(names), Vector2(cx + 10.0, bar + 54.0), 13, Pal.ink(0.7 * a), font)
	# framed and measured
	if ph[0] in ["out", "hold"]:
		var a2: float = Pal.ease_out(float(ph[1])) if ph[0] == "out" else 1.0
		a2 *= k_in
		var p0: Vector2 = xf * Vector2(sv.x0, sv.y0)
		var p1: Vector2 = xf * Vector2(sv.x1, sv.y1)
		var r := Rect2(p0, p1 - p0).abs().grow(14.0)
		var arm := minf(40.0, r.size.y * 0.3)
		for cr in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)], [r.end, Vector2(-1, -1)], [Vector2(r.position.x, r.end.y), Vector2(1, -1)]]:
			var q: Vector2 = cr[0]
			var d: Vector2 = cr[1]
			c.draw_line(q, q + Vector2(arm * d.x, 0), Pal.tint(Pal.AIR, 0.8 * a2, 1.2), 2.0)
			c.draw_line(q, q + Vector2(0, arm * d.y), Pal.tint(Pal.AIR, 0.8 * a2, 1.2), 2.0)
		# length, under the hull
		var ly := r.end.y + 26.0
		_dim(Vector2(r.position.x + 14.0, ly), Vector2(r.end.x - 14.0, ly), g.txt("sv_len") % ((float(sv.x1) - float(sv.x0)) / M), a2)
		# height, beside it
		var hx := r.end.x + 26.0
		_dim(Vector2(hx, r.position.y + 14.0), Vector2(hx, r.end.y - 14.0), g.txt("sv_hgt") % ((float(sv.y1) - float(sv.y0)) / M), a2)
		# the centre of mass
		var cm: Vector2 = xf * (sv.com as Vector2)
		FastDraw.arc(c, cm, 9.0, 0.0, TAU, 20, Pal.heat(0.9 * a2, 1.3), 1.6, true)
		c.draw_line(cm - Vector2(14, 0), cm + Vector2(14, 0), Pal.heat(0.9 * a2, 1.3), 1.2)
		c.draw_line(cm - Vector2(0, 14), cm + Vector2(0, 14), Pal.heat(0.9 * a2, 1.3), 1.2)
		_text(g.txt("sv_com") % ((sv.com.x - float(sv.x0)) / M), cm + Vector2(16, -12), 13, Pal.heat(0.95 * a2, 1.2), font_b)
		# the lidar sweep across the hull, once, as it is measured
		if ph[0] == "hold":
			var u := clampf(float(ph[1]) * 1.6, 0.0, 1.0)
			if u < 1.0:
				var sx := lerpf(r.position.x, r.end.x, Pal.ease_io(u))
				c.draw_line(Vector2(sx, r.position.y), Vector2(sx, r.end.y), Pal.tint(Pal.AIR, 0.7 * a2, 1.6), 2.0)
				c.draw_rect(Rect2(Vector2(r.position.x, r.position.y), Vector2(sx - r.position.x, r.size.y)), Pal.tint(Pal.AIR, 0.035 * a2))
	# the heading and what the ship is, low on the left
	var tl := Vector2(70, s.y - bar - 96.0)
	_text(g.txt("sv_head") + "  ·  " + g.txt("contract") + " " + str(g.ship.get("contract", "")), tl, 14, Pal.tint(Pal.AIR, 0.75 * k_in, 1.1), font_b)
	_text(g.ship_title(), tl + Vector2(0, 34), 28, Pal.ink(0.92 * k_in), font_l)
	_text(g.txt("sv_stats") % [_tonnes(float(sv.mass)), int(sv.n), g.world.rooms.size(), g.mandatory_items().size()], tl + Vector2(0, 60), 14, Pal.ink(0.62 * k_in), font)
	_text(g.txt("sv_skip"), Vector2(s.x - 70, s.y - bar - 30.0), 13, Pal.ink(0.5 * k_in), font, 1)
	c.draw_rect(Rect2(0, 0, s.x, bar), Color(0, 0, 0, 1))
	c.draw_rect(Rect2(0, s.y - bar, s.x, bar), Color(0, 0, 0, 1))
	# progress along the bottom bar
	var pk := clampf(tt / float(sv.t_end), 0.0, 1.0)
	c.draw_rect(Rect2(0, s.y - bar, s.x * pk, 2.0), hc)


# the berth being extended: letterbox, the procedure as a checklist with the
# step in hand live, the certificate when it is done
func _build_overlay(s: Vector2) -> void:
	var g = game
	var b = g.build
	if b == null:
		return
	if b is RepairShow:
		_repair_overlay(s, b)
		return
	var tt: float = b.t
	var k_in := Pal.ease_out(clampf(tt / 0.4, 0.0, 1.0)) * clampf((b.total() - tt) / 0.35, 0.0, 1.0)
	var bar := 70.0 * k_in
	var cur: int = b.current()
	var r := Rect2(48, bar + 26.0, 640, 66 + b.steps.size() * 50)
	c.draw_style_box(UiSkin.box("tag", 0.88 * k_in), r)
	UI.panel(c, r, 0.9 * k_in, 0.0, Pal.HEAT, 1.0)
	_text(b.head(), r.position + Vector2(20, 32), 16, Pal.ink(0.95 * k_in), font_b)
	# the incoming ship's outline, named
	if b.envelope.size != Vector2.ZERO and b.ship_name != "" and not b.passed("haul") and not b.passed("test"):
		var xf: Transform2D = g.get_viewport().get_canvas_transform()
		var ep: Vector2 = xf * (Vector2(b.envelope.end.x, b.envelope.position.y) * Geom.M)
		var et: String = g.txt("bb_env") % [b.ship_name, b.envelope.size.x, b.envelope.size.y]
		var ew := font_b.get_string_size(et, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		_text(et, Vector2(clampf(ep.x - ew, r.end.x + 20.0, s.x - ew - 20.0), clampf(ep.y - 10.0, bar + 30.0, s.y - bar - 30.0)), 14, Pal.heat(0.9 * k_in, 1.2), font_b)
	for i in b.steps.size():
		var y: float = r.position.y + 70.0 + i * 50.0
		var done: bool = i < cur or (i == cur and b.k(i) >= 1.0)
		var on: bool = i == cur and not done
		var a: float = (1.0 if on else (0.75 if done else 0.32)) * k_in
		var dc := Vector2(r.position.x + 30, y - 5)
		if done:
			FastDraw.polyline(c, PackedVector2Array([dc + Vector2(-6, 0), dc + Vector2(-1, 5), dc + Vector2(7, -6)]), Pal.tint(Pal.FLUID, a, 1.3), 2.0, true)
		elif on:
			FastDraw.arc(c, dc, 6.0, tt * 6.0, tt * 6.0 + PI * 1.4, 12, Pal.heat(a, 1.4), 2.0, true)
		else:
			FastDraw.arc(c, dc, 5.0, 0.0, TAU, 12, Pal.ink(a), 1.2, true)
		_text("%d  %s" % [i + 1, g.txt("bb_n_" + str(b.steps[i][0]))], Vector2(r.position.x + 48, y), 15, Pal.ink(a), font_b)
		if on or done:
			_text(b.detail(i), Vector2(r.position.x + 48, y + 20), 12, Pal.ink((0.7 if on else 0.45) * k_in), font, -1, r.size.x - 60)
		if on:
			c.draw_rect(Rect2(r.position.x + 48, y + 27, (r.size.x - 70) * b.k(i), 2), Pal.heat(0.8 * k_in, 1.3))
	# the certificate
	if cur == b.steps.size() - 1 and b.k(cur) > 0.55:
		var e := Pal.back(clampf((b.k(cur) - 0.55) / 0.25, 0.0, 1.0))
		var txt: String = g.txt("bb_done") % b.x_b
		var w := font_l.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		var cr := Rect2(Vector2(s.x * 0.5 + 120.0 - w * 0.5 - 30.0, s.y * 0.5 - 40.0), Vector2(w + 60.0, 80.0))
		_xform(cr.get_center(), 0.0, Vector2.ONE * lerpf(1.4, 1.0, e))
		var lr := Rect2(-cr.size * 0.5, cr.size)
		c.draw_style_box(UiSkin.box("tag", 0.85 * k_in), lr)
		c.draw_rect(lr, Pal.tint(Pal.FLUID, 0.9 * k_in, 1.3), false, 2.0)
		c.draw_rect(lr.grow(-6.0), Pal.tint(Pal.FLUID, 0.4 * k_in, 1.1), false, 1.0)
		_text(txt, Vector2(0, 12), 34, Pal.tint(Pal.FLUID, k_in, 1.2), font_l, 0)
		_xform(Vector2.ZERO)
	_text(g.txt("sv_skip"), Vector2(s.x - 70, s.y - bar - 30.0), 13, Pal.ink(0.5 * k_in), font, 1)
	c.draw_rect(Rect2(0, 0, s.x, bar), Color(0, 0, 0, 1))
	c.draw_rect(Rect2(0, s.y - bar, s.x, bar), Color(0, 0, 0, 1))
	c.draw_rect(Rect2(0, s.y - bar, s.x * clampf(tt / b.total(), 0.0, 1.0), 2.0), Pal.heat(0.9, 1.3))


# a repair shown at the berth (scripts/repair_show.gd): letterbox, which one of how many, its progress
func _repair_overlay(s: Vector2, b) -> void:
	var g = game
	var done_f: float = (b.i + clampf(b.t / b.PER, 0.0, 1.0)) / maxf(1.0, b.ids.size())
	var k_in := Pal.ease_out(clampf((b.i * b.PER + b.t) / 0.4, 0.0, 1.0)) * clampf((b.total() - (b.i * b.PER + b.t)) / 0.35, 0.0, 1.0)
	var bar := 70.0 * k_in
	var r := Rect2(48, bar + 26.0, 520, 66)
	c.draw_style_box(UiSkin.box("tag", 0.88 * k_in), r)
	UI.panel(c, r, 0.9 * k_in, 0.0, Pal.HEAT, 1.0)
	_text(g.txt("rp_show_head") % [b.i + 1, b.ids.size()], r.position + Vector2(20, 30), 16, Pal.ink(0.95 * k_in), font_b)
	_text(RepairShow._title(b.current()) if b.current() != "" else "", r.position + Vector2(20, 54), 15, Pal.heat(0.9 * k_in, 1.2), font_b)
	_text(g.txt("sv_skip"), Vector2(s.x - 70, s.y - bar - 30.0), 13, Pal.ink(0.5 * k_in), font, 1)
	c.draw_rect(Rect2(0, 0, s.x, bar), Color(0, 0, 0, 1))
	c.draw_rect(Rect2(0, s.y - bar, s.x, bar), Color(0, 0, 0, 1))
	c.draw_rect(Rect2(0, s.y - bar, s.x * clampf(done_f, 0.0, 1.0), 2.0), Pal.heat(0.9, 1.3))


# a measured dimension: the line, arrowheads and end ticks, the value in the middle
func _dim(a: Vector2, b: Vector2, label: String, al: float) -> void:
	var col := Pal.tint(Pal.AIR, 0.85 * al, 1.2)
	c.draw_line(a, b, col, 1.4)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	for e in [[a, d], [b, -d]]:
		var p: Vector2 = e[0]
		var f: Vector2 = e[1]
		FastDraw.poly(c, PackedVector2Array([p, p + f * 10.0 + n * 4.0, p + f * 10.0 - n * 4.0]), col)
		c.draw_line(p - n * 9.0, p + n * 9.0, col, 1.2)
	var mid := (a + b) * 0.5
	var w := font_b.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	if absf(d.x) > 0.5:
		c.draw_style_box(UiSkin.box("tag", 0.9 * al), Rect2(mid - Vector2(w * 0.5 + 8.0, 11.0), Vector2(w + 16.0, 22.0)))
		_text(label, mid + Vector2(0, 6), 15, col, font_b, 0)
	else:
		c.draw_style_box(UiSkin.box("tag", 0.9 * al), Rect2(mid + Vector2(8.0, -11.0), Vector2(w + 16.0, 22.0)))
		_text(label, mid + Vector2(16.0, 6.0), 15, col, font_b)


static func _tonnes(t: float) -> String:
	if t >= 100.0:
		return Pal.money(t).replace("$", "")
	return "%.1f" % t


func _contract_panel() -> void:
	var g = game
	var x := 40.0
	var y := 46.0
	var items0: Array = _title_items()
	var by0 := maxf(y + 120, y + 56 + items0.size() * 24 + 18)
	var lrow := 0.0 if g.training or g.exam != null else 24.0     # the "pieces left" row
	var ph := by0 - y + 80.0 + lrow + (56.0 if g.scope() != "full" else 0.0)
	UI.panel(c, Rect2(x - 18, y - 30, 340, ph), 0.82, 0.0, Pal.HEAT, _boot(0))
	_text(g.txt("contract") + " " + g.ship.get("contract", ""), Vector2(x, y), 13, Pal.ink(0.5), font)
	var kinds: Array = []
	if g.scope() != "full":
		kinds.append(g.txt("sc_" + g.scope()))
	if g.goal() != "":
		kinds.append(g.txt("goal_" + g.goal()))
	if not kinds.is_empty():
		_text(" · ".join(kinds), Vector2(x + 300, y), 13, Pal.heat(0.95, 1.2), font_b, 1)
	_text(g.ship_title(), Vector2(x, y + 24), 20, Pal.ink(0.95), font_b)
	# mandatory items (117 号 Q7: one the asset board lists carries its diamond there instead)
	var items: Array = g.mandatory_items()
	var row := -1
	for i in items.size():
		if not items0.has(items[i]):
			continue
		row += 1
		var yy := y + 56 + row * 24
		var k: float = must_k[i] if i < must_k.size() else 0.0
		var dc := Vector2(x + 7, yy - 5)
		var dia := PackedVector2Array([dc + Vector2(0, -6), dc + Vector2(6, 0), dc + Vector2(0, 6), dc + Vector2(-6, 0)])
		if k > 0.02:
			var sc := 1.0 + 0.6 * (1.0 - k) * k * 4.0
			var d2 := PackedVector2Array()
			for q in dia:
				d2.append(dc + (q - dc) * sc)
			FastDraw.poly(c, d2, Pal.ink(0.95 * k))
		var cl := dia.duplicate()
		cl.append(dia[0])
		var lost: bool = g.mandatory_lost.has(items[i][0])
		FastDraw.polyline(c, cl, Pal.heat(0.95, 1.3) if lost else Pal.ink(0.7), 1.2, true)
		if lost:
			c.draw_line(dc + Vector2(-6, -6), dc + Vector2(6, 6), Pal.heat(1.0, 1.4), 2.0)
			c.draw_line(dc + Vector2(6, -6), dc + Vector2(-6, 6), Pal.heat(1.0, 1.4), 2.0)
		if must_t.has(i) and t - must_t[i] < 0.7:
			var e := Pal.ease_out((t - must_t[i]) / 0.7)
			FastDraw.arc(c, dc, 6.0 + 22.0 * e, 0.0, TAU, 24, Pal.ink(0.8 * (1.0 - e), 1.3), 1.5, true)
			Pal.band(c, Rect2(x + 18, yy - 17, 300.0 * e, 22), 0.12 * (1.0 - e))
		_text(items[i][1] + "  " + items[i][0], Vector2(x + 22, yy), 14, Pal.ink(0.55 + 0.4 * k), font)
	# recovery bar (below however many items the contract asks for)
	var by := maxf(y + 120, y + 56 + items0.size() * 24 + 18)
	_text(g.txt("rate"), Vector2(x, by), 13, Pal.ink(0.5), font)
	var pct: float = rate_roll.shown
	_text("%.1f%%" % pct, Vector2(x + 300, by + 2), 22, Pal.ink(0.95), font_l, 1)
	var bw := 300.0
	var br := Rect2(x, by + 12, bw, 4)
	c.draw_rect(br, Pal.ink(0.1))
	var fill := bw * clampf(pct / 100.0, 0.0, 1.0)
	var lo := bw * clampf(rate_lo / 100.0, 0.0, 1.0)
	c.draw_rect(Rect2(br.position, Vector2(lo, 4)), Pal.ink(0.85))
	if fill - lo > 0.5:
		# the gain still glowing hot
		c.draw_rect(Rect2(br.position + Vector2(lo, 0), Vector2(fill - lo, 4)), Pal.heat(1.0, 1.4))
	if rate_sweep < 0.6 and fill > 4.0:
		var sx := fill * Pal.ease_out(rate_sweep / 0.6)
		for j in 6:
			c.draw_rect(Rect2(br.position.x + maxf(0.0, sx - j * 5.0 - 5.0), by + 11, 5, 6), Pal.ink(0.35 * (1.0 - j / 6.0) * (1.0 - rate_sweep / 0.6), 1.5))
	if fill > 1.0:
		c.draw_rect(Rect2(br.position.x + fill - 1.5, by + 10, 3, 8), Pal.ink(0.9, 1.3))
	for mi in 3:
		var mark: float = [70.0, 80.0, 92.0][mi]
		var mx: float = x + bw * mark / 100.0
		var pe := clampf(mark_pop[mi] / 0.6, 0.0, 1.0)
		var grow := 6.0 * (1.0 - Pal.ease_out(pe))
		c.draw_line(Vector2(mx, by + 9 - grow), Vector2(mx, by + 19 + grow), Pal.ink(0.5 if pct < mark else 0.9) if pe >= 1.0 else Pal.heat(1.0, 1.4), 1.0 + grow * 0.3)
		if pe < 1.0:
			FastDraw.arc(c, Vector2(mx, by + 14), 4.0 + 18.0 * Pal.ease_out(pe), 0.0, TAU, 24, Pal.heat(0.8 * (1.0 - pe), 1.3), 1.4, true)
	_text(g.txt("target") + " 70% · 80% · 92%", Vector2(x, by + 36), 13, Pal.ink(0.5), font)
	if not g.training and g.exam == null:
		var nl: int = g.left_count()
		_text(g.txt("left_n") % nl, Vector2(x, by + 60), 13, Pal.heat(0.9, 1.2) if nl > 0 and nl <= 8 else Pal.ink(0.5), font_b if nl <= 8 else font)
		# a job of several days: which day it is, and what is left of it
		if g.workday != null and g.workday.active():
			var fresh: bool = g.workday.card_t >= 0.0
			_text(g.txt("wd_day") % [g.workday.day, g.workday.planned(), _clock(maxf(0.0, g.workday.left_today()))], Vector2(x + 300, by + 60), 13,
				Pal.heat(0.9, 1.3) if fresh else Pal.ink(0.5), font_b if fresh else font, 1)
	if g.story != null and not g.story.items.is_empty():
		_text(g.txt("st_found") % [g.story.found_count(), g.story.items.size()], Vector2(x + 300, by + 36), 13, Pal.tint(Pal.AIR, 0.55, 1.0), font, 1)
	elif g.standard_time() > 0.0:
		# the clock against the standard time: past it, the time bonus starts to shrink
		var late: bool = g.playtime > g.standard_time()
		_text(_clock(g.playtime) + " / " + _clock(g.standard_time()), Vector2(x + 300, by + 36), 13, Pal.heat(0.8, 1.0) if late else Pal.ink(0.5), font, 1)
	var ry := by + 70 + lrow
	if g.scope() != "full":
		c.draw_rect(Rect2(x - 8, by + 50 + lrow, 2, 44), Pal.heat(0.9, 1.1))
		_mtext(Market.scope_text(g.job), Vector2(x, by + 66 + lrow), 300, 13, 2, Pal.ink(0.85))
		ry += 36
	_recall(x, ry)


# training recall cards slide in, then fold into the notes under the contract
func _recall(x: float, y: float) -> void:
	var asst = game.assist
	if asst == null:
		return
	var yy := y
	for cd in asst.cards:
		var e: float = cd[2]
		var k := Pal.ease_out(clampf(e / 0.25, 0.0, 1.0)) * clampf((Assist.CARD_T - e) / 0.4, 0.0, 1.0)
		var r := Rect2(x - (1.0 - k) * 40.0, yy, 300, 46)
		c.draw_style_box(UiSkin.box("panel", k), r)
		c.draw_rect(Rect2(r.position + Vector2(8, 9), Vector2(3, r.size.y - 18)), Color(UiSkin.DATA, k))
		_text(game.txt("rc_title") + " · " + game.txt("rc_l") % cd[0], r.position + Vector2(14, 18), 13, Pal.tint(Pal.AIR, 0.9 * k, 1.1), font)
		_text(game.txt(cd[1]), r.position + Vector2(14, 37), 15, Pal.ink(0.92 * k), font_b)
		yy += 54
	if asst.notes.is_empty():
		return
	_text(game.txt("notes"), Vector2(x, yy + 10), 13, Pal.ink(0.5), font)
	for i in asst.notes.size():
		var n: Array = asst.notes[i]
		_text("%s  ·  %s" % [game.txt(n[1]), game.txt("rc_l") % n[0]], Vector2(x, yy + 30 + i * 18), 13, Pal.ink(0.5), font)


func _credits(s: Vector2) -> void:
	var g = game
	var x := s.x - 40.0
	UI.panel(c, Rect2(x - 250, 22, 268, 86), 0.82, 0.0, Pal.HEAT, _boot(1))
	_text(g.txt("income"), Vector2(x, 46), 13, Pal.ink(0.5), font, 1)
	var v: float = credit_roll.shown
	var sc := 1.0 + 0.18 * credit_pop * credit_pop
	var txt := Pal.money(v)
	var sz := int(34 * sc)
	_text(txt, Vector2(x, 88), sz, Pal.ink(0.95), font_l, 1)
	var y := 120.0
	for i in g.feed.size():
		var f: Array = g.feed[i]
		var age: float = f[2]
		var slide := 1.0 - Pal.back(clampf(age / 0.35, 0.0, 1.0), 1.4)
		var a: float = clampf((5.0 - age) / 0.8, 0.0, 1.0) * (1.0 - i * 0.14)
		var col := Pal.ink(0.75 * a) if f[1] >= 0 else Pal.heat(0.9 * a, 1.2)
		var amt: String = ("+" if f[1] >= 0 else "") + Pal.money(f[1])
		_text(amt, Vector2(x + slide * 120.0, y + i * 22), 15, col, font_b, 1)
		_text(str(f[0]), Vector2(x - 120 + slide * 120.0, y + i * 22), 13, Pal.ink(0.5 * a), font, 1)


# the berth's machines (arm, hauler) and the work plan: running, stopped, waiting for what
func _work_order(s: Vector2) -> void:
	var order = game.work_order
	if order == null or not order.active() or Career.data.get("work_orders",{}).get("tracked",order.id) != order.id: return
	var x := s.x*0.5
	UI.panel(c,Rect2(x-240,20,480,88),0.94)
	_text(order.text(order.id),Vector2(x,44),16,Pal.ink(0.9),font,0)
	_text(order.status_line(),Vector2(x,65),14,Pal.ink(0.7),font,0)
	_text(game.txt("g4_order_sold" if order.sell else "g4_order_tracking"),Vector2(x,86),13,Pal.ink(0.55),font,0)


# the empty berth's corner (design/…/22_*): the port's four lamps and how many things wait
# on the operator; the whole overview is the terminal's home screen. Never a pop-up (Q49).
var ops_strip: Dictionary = {}
var _ops_t := 9.0


# ---------------------------------------------------------------- the on-site guide (27 号)
var guide_end: Button
var guide_act: Button
var main_go: Button          # the main line's "take me" (28 号)
const GUIDE_W := 720.0


func _guide_on() -> bool:
	return game != null and game.guide != null and game.guide.active() and game.in_berth() and game.state == "play" and not game.port_view


func _guide_rect(s: Vector2) -> Rect2:
	return Rect2(s.x * 0.5 - GUIDE_W * 0.5, 118.0, GUIDE_W, 112.0)


# the main line's chapter and step, worked out twice a second (Mainline.step walks the repairs and
# the port's works: too dear for every frame)
var _main_c := {}
var _main_ct := -1.0
func _main() -> Dictionary:
	var now := Time.get_ticks_msec() / 1000.0
	if _main_c.is_empty() or now - _main_ct > 0.5:
		_main_ct = now
		var ch := Mainline.chapter()
		_main_c = {"chapter": ch, "step": Mainline.step(ch) if ch != "" else {}}
	return _main_c


func _main_on() -> bool:
	return game != null and not game.coach_on() and not game.walk_on() and game.career() and not game.training and game.exam == null and game.in_berth() and game.state == "play" and not game.port_view and _main().chapter != "" and Career.usable()


func _main_rect() -> Rect2:
	# 61 号: room for a whole plain sentence on two lines
	return Rect2(22.0, 22.0, 760.0, 88.0)


func _guide_keys() -> void:
	var mon := _main_on()
	var go := str(_main().step.get("go", "wait")) if mon else "wait"
	main_go.visible = mon and go != "wait" and not (_guide_on() and go.begins_with("guide:"))
	if main_go.visible:
		var mr := _main_rect()
		main_go.text = Ops.w("带我去", "TAKE ME")
		main_go.size = Vector2(96, 34)
		main_go.position = Vector2(mr.end.x - 106, mr.position.y + 27)
	var on := _guide_on()
	var st: Dictionary = game.guide.step if on else {}
	guide_end.visible = on
	guide_act.visible = on and str(st.get("action", "")) != ""
	if not on:
		return
	var r := _guide_rect(size())
	guide_end.text = Ops.w("退出引导", "END GUIDE")
	# in the card's head row, clear of the title and its text (user 2026-10-26: they sat on the title)
	guide_end.size = Vector2(104, 28)
	guide_end.position = Vector2(r.end.x - 114, r.position.y + 6)
	# user 2026-10-26: it said "打开交易行" whatever it opened — named by what it does
	guide_act.text = {"starmap": Ops.w("打开星图", "STAR MAP"), "clients": Ops.w("打开客户", "CLIENTS"), "feed": Ops.w("打开交易行", "EXCHANGE"),
		"exchange": Ops.w("打开交易行", "EXCHANGE"), "contracts": Ops.w("打开合同", "CONTRACTS"), "repair": Ops.w("打开船坞修缮", "REPAIRS")}.get(str(st.get("action", "")), Ops.w("前往建设", "BUILD") if str(st.get("action", "")).begins_with("build") else Ops.w("去做", "GO"))
	guide_act.reset_size()
	guide_act.position = Vector2(r.end.x - 124 - guide_act.size.x, r.position.y + 6)


# the main line in the empty berth's corner (28 号 Q17): chapter, and the next step
func _main_line(s: Vector2) -> void:
	if not _main_on():
		return
	var id := str(_main().chapter)
	var r := _main_rect()
	UI.panel(c, r, 0.9)
	c.draw_rect(Rect2(r.position + Vector2(8, 10), Vector2(3, r.size.y - 20)), UiSkin.ACCENT)
	_text(Ops.w("主线 · 第 %d 章｜%s", "MAIN LINE · CHAPTER %d | %s") % [Mainline.index(id), Mainline.name_of(id)], r.position + Vector2(16, 24), 14, Pal.heat(0.95, 1.3), font_b, -1)
	c.draw_multiline_string(font, r.position + Vector2(16, 50), str(_main().step.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 130.0, 15, 2, Pal.ink(0.9))


func _guide(s: Vector2) -> void:
	_main_line(s)
	var g = game.guide
	if g == null:
		return
	# a finished task says so for a few seconds, even after the guide has ended
	if g.note != "" and g.note_t < 6.0:
		var nr := Rect2(s.x * 0.5 - GUIDE_W * 0.5, 222.0 if _guide_on() else 118.0, GUIDE_W, 34.0)
		UI.panel(c, nr, 0.9)
		_text(g.note, Vector2(nr.position.x + 16, nr.position.y + 23), 15, Hmi.ok_col(), font_b, -1)
	if not _guide_on() or g.step.is_empty():
		return
	var st: Dictionary = g.step
	var r := _guide_rect(s)
	UI.panel(c, r, 0.94)
	c.draw_rect(Rect2(r.position + Vector2(8, 10), Vector2(3, r.size.y - 20)), UiSkin.ACCENT)
	var head := Ops.w("引导 · %s · 第 %d / %d 步", "GUIDE · %s · STEP %d / %d") % [Guide.task_name(str(st.get("task", ""))), int(st.get("n", 1)), int(st.get("of", 1))]
	_text(head, r.position + Vector2(18, 26), 13, Pal.heat(0.9, 1.3), font_b, -1)
	c.draw_string(font_b, r.position + Vector2(18, 74), str(st.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36.0, 19 if _tw(str(st.get("title", "")), 22) > r.size.x - 36.0 else 22, Pal.ink(0.98))
	c.draw_string(font, r.position + Vector2(18, 100), str(st.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36.0, 14, Pal.ink(0.65))
	# the target: a ring and its name on screen, an arrow at the edge when it is off it
	var target: Vector2 = st.get("target", Vector2.INF)
	if not target.is_finite():
		return
	var p := to_screen(target)
	var k := 0.6 + 0.4 * absf(sin(Time.get_ticks_msec() * 0.005))
	var view := Rect2(Vector2(40, 240), s - Vector2(80, 340))
	if view.has_point(p):
		var rr := 46.0 + 8.0 * k
		FastDraw.arc(c, p, rr, 0.0, TAU, 48, Pal.heat(k, 1.6), 3.0, true)
		FastDraw.arc(c, p, rr + 10.0, 0.0, TAU, 48, Pal.heat(0.35 * k, 1.2), 1.5, true)
		var name := str(st.get("name", ""))
		var purpose := str(st.get("purpose", ""))
		var lw := maxf(_tw(name, 18), _tw(purpose, 13)) + 28.0
		var lr := Rect2(p + Vector2(rr + 14.0, -30.0), Vector2(minf(lw, 520.0), 58.0))
		if lr.end.x > s.x - 20.0:
			lr.position.x = p.x - rr - 14.0 - lr.size.x
		UI.panel(c, lr, 0.92)
		_text(name, lr.position + Vector2(14, 24), 18, Pal.heat(1.0, 1.4), font_b, -1)
		_text(purpose, lr.position + Vector2(14, 46), 13, Pal.ink(0.75), font, -1, lr.size.x - 28.0)
	else:
		# from the middle of the view (below the guide card), so the arrow never lands on the card
		var cpos := view.get_center()
		var d := (p - cpos).normalized()
		# the point where the ray from the centre leaves the view, a little inside
		var tx := (view.size.x * 0.5) / maxf(absf(d.x), 0.0001)
		var ty := (view.size.y * 0.5) / maxf(absf(d.y), 0.0001)
		var e := cpos + d * minf(tx, ty)
		var tip := e
		var back := e - d * 34.0
		var side := d.orthogonal() * 16.0
		FastDraw.poly(c, PackedVector2Array([tip, back + side, back - side]), Pal.heat(k, 1.6))
		var lab := str(st.get("name", ""))
		_text(lab, back - d * 26.0 + Vector2(0, 6), 15, Pal.heat(1.0, 1.4), font_b, 0)


func _ops_strip(s: Vector2) -> void:
	var g = game
	if not g.career() or g.training or g.exam != null or not Onboarding.shown("market_ops"):
		return
	_ops_t += get_process_delta_time()
	if _ops_t > 1.0 or ops_strip.is_empty():
		_ops_t = 0.0
		ops_strip = {"cells": Ops.cells(g), "decs": Ops.decisions(g)}
	var r := Rect2(s.x - 342.0, 22.0, 320.0, 92.0)
	UI.panel(c, r, 0.82)
	var cells: Array = ops_strip.cells
	var cw := (r.size.x - 24.0) / maxf(1.0, cells.size())
	for i in cells.size():
		var cell: Dictionary = cells[i]
		var p := Vector2(r.position.x + 12.0 + i * cw, r.position.y + 14.0)
		var state := str(cell.lamp)
		Hmi.lamp(c, p + Vector2(8, 8), OpsSkin.lamp_col(state), state != "idle", 1.0, 5.0)
		_text(str(cell.title).substr(0, 2) if Txt.zh else str(cell.code), p + Vector2(20, 13), 13, Pal.ink(0.8), font_b, -1)
		_text(str(cell.value), p + Vector2(0, 34), 12, Pal.ink(0.6), font, -1)
	var decs: Array = ops_strip.decs
	var worst := int(decs[0].level) if not decs.is_empty() else Ops.CHANCE
	var col := OpsSkin.level_col(worst) if not decs.is_empty() else Pal.ink(0.5)
	var line := (Ops.w("待决策 %d 项", "%d WAITING ON YOU") % decs.size()) if not decs.is_empty() else Ops.w("没有待决策", "NOTHING WAITING")
	_text(line + "  ·  " + Ops.w("%s 打开终端", "%s TERMINAL") % Keys.label("terminal"), Vector2(r.position.x + 12.0, r.end.y - 14.0), 13, col, font_b, -1)


func _machines(s: Vector2) -> void:
	var g = game
	var ps: Array = g.plan.status() if g.plan != null and Game.G4_OPEN else []
	if g.arm == null and g.hauler == null and g.crane == null and ps.is_empty():
		return
	var x := s.x - 40.0
	var y := 290.0
	var h := 40.0 + (44.0 if not ps.is_empty() else 0.0)
	UI.panel(c, Rect2(x - 250, y - 26, 268, h), 0.82)
	var col := Pal.heat(0.9, 1.2) if g.auto_paused else Pal.ink(0.7)
	_text(g.txt("auto_off" if g.auto_paused else "auto_on_short") % Keys.label("auto"), Vector2(x, y), 13, col, font, 1)
	if not ps.is_empty():
		_text(ps[0] + "  [%s]" % Keys.label("plan"), Vector2(x, y + 22), 13, Pal.ink(0.5), font, 1)
		var wait: bool = g.plan.running and g.plan.wait != ""
		_text(ps[1], Vector2(x, y + 40), 13, Pal.tint(Pal.AIR, 0.9, 1.2) if g.plan.running and not wait else (Pal.heat(0.85, 1.1) if wait else Pal.ink(0.6)), font, 1)


func _toolbar(s: Vector2) -> void:
	var g = game
	var r := _toolbar_rect()
	for i in _slots():
		var sx := r.position.x + i * 142.0
		var oy: float = slot_y[i].x + (1.0 - Pal.ease_out(Motion.stagger(in_t, 3 + i, 0.05, 0.5))) * 150.0
		var rect := Rect2(sx, r.position.y + 14.0 + oy, 132.0, 70.0)
		var on: float = slot_glow[i]
		# 54 号: the slots are the new skin's rounded panels; the one in hand lifts and warms
		rect.position.y -= 4.0 * on
		c.draw_style_box(UiSkin.box("panel", 1.0, on), rect)
		if on > 0.5 and tool_pulse < 0.45:
			var e := Pal.ease_out(tool_pulse / 0.45)
			c.draw_style_box(UiSkin.box("ring", 1.0 - e), rect.grow(2.0 + 9.0 * e))
		_text(str(i + 1) if i < 5 else Keys.label("tool6"), rect.position + Vector2(10, 22), 14, Pal.ink(0.5 + 0.5 * on), font_b)
		var pop := 1.0
		if on > 0.5 and tool_pulse < 0.35:
			pop = 1.0 + 0.35 * sin(clampf(tool_pulse / 0.35, 0.0, 1.0) * PI)
		_xform(rect.position + Vector2(rect.size.x - 30, 26), 0.0, Vector2.ONE * pop)
		_tool_icon(i + 1, Vector2.ZERO, on)
		_xform(Vector2.ZERO)
		_text(g.txt("tool_%d" % (i + 1)), rect.position + Vector2(10, 56), 15, Pal.ink(0.5 + 0.45 * on), font)
		# the consumable part in the meter, the laser and the grapple: its grade and what it has left
		if Consum.ENABLED and i < 3 and g.career() and not g.job.is_empty():
			var tool: String = ["probe", "lens", "cap"][i]
			var tier := Consum.tier(g, tool)
			if tier >= 0:
				var left := Consum.left(g, tool)
				var cap := Consum.capacity(tool, tier)
				var frac := clampf(left / maxf(cap, 0.001), 0.0, 1.0)
				var br := Rect2(rect.position.x + 10, rect.end.y - 7, 60, 3)
				c.draw_rect(br, Pal.ink(0.12))
				c.draw_rect(Rect2(br.position, Vector2(br.size.x * frac, br.size.y)), Pal.heat(0.9, 1.3) if frac < 0.2 else Pal.ink(0.7 + 0.2 * on))
				var lab: String = g.txt("cs_out_short") if left <= 0.0 else Consum.tier_name(tier)
				_text(lab, rect.position + Vector2(rect.size.x - 10, 22), 11, Pal.heat(0.95, 1.2) if left <= 0.0 else Pal.ink(0.45 + 0.3 * on), font, 1)
		if i == 4:
			var mode: String = g.txt("mode_" + g.tools.hose_mode)
			_text(mode, rect.position + Vector2(rect.size.x - 10, 56), 13, Pal.ink(0.5 + 0.3 * on) if g.tools.hose_mode == "recover" else Pal.heat(0.8, 1.0), font, 1)
		if i == 5 and g.gear != null:
			var ih: String = g.gear.in_hand()
			var cnt: int = int(g.gear.carried_counts().get(ih, 0))
			var what: String = (Gear.name_of(ih) + "  ×%d" % cnt) if ih != "" else g.txt("e_gear_none")
			_text(what, rect.position + Vector2(rect.size.x - 10, 22), 12, Pal.ink(0.5 + 0.4 * on) if ih != "" else Pal.ink(0.35), font, 1)
	# 80 号: the guide's step opens only its tools — the others go dark with a lock and shake when asked for
	if g.tutorial == null and g.guide_coach() != null:
		for i in _slots():
			if g.tool_ok(i + 1):
				continue
			var lr := Rect2(r.position.x + i * 142.0, r.position.y + 14.0 + slot_y[i].x, 132.0, 70.0)
			if g.tools.denied_slot == i + 1 and g.tools.denied_t < 0.4:
				lr.position.x += sin(g.tools.denied_t * 70.0) * 6.0 * (1.0 - g.tools.denied_t / 0.4)
			# covered, then: the lock, which tool, and why it is shut (user 2026-10-26: a lock alone
			# reads as "not bought" or "broken")
			c.draw_rect(lr, Color(0.03, 0.032, 0.038, 0.97))
			c.draw_rect(lr, Pal.ink(0.12), false, 1.0)
			var lc := lr.position + Vector2(lr.size.x - 18, 16)
			c.draw_rect(Rect2(lc - Vector2(6, 1), Vector2(12, 9)), Pal.ink(0.45), false, 1.2)
			FastDraw.arc(c, lc + Vector2(0, -2), 4.0, PI, TAU, 10, Pal.ink(0.45), 1.2, true)
			_text("%s  %s" % [str(i + 1) if i < 5 else Keys.label("tool6"), g.txt("tool_%d" % (i + 1))], lr.position + Vector2(10, 30), 14, Pal.ink(0.5), font)
			_text(Ops.w("教程稍后解锁", "LATER IN THE GUIDE"), lr.position + Vector2(10, 56), 13, Pal.ink(0.72), font)
		var any := false
		for i in _slots():
			any = any or g.tool_ok(i + 1)
		if not any:
			_text(Ops.w("现在只需要飞，工具在用到时一件件解锁", "JUST FLY FOR NOW: EACH TOOL UNLOCKS WHEN IT IS NEEDED"), Vector2(r.position.x + r.size.x * 0.5, r.position.y - 4), 16, Pal.ink(0.9), font_b, 0)
	# the context tool: the tool in hand follows the pointer (out of the laser and the hose)
	if g.state == "play" and Txt.context and g.tutorial == null and g.guide_coach() == null and g.bot == null:
		var auto: bool = g.tools.tool in [1, 3, 4]
		_text(g.txt("tb_auto") if auto else g.txt("tb_manual"), Vector2(r.position.x, r.position.y + 6), 13, Pal.tint(Pal.AIR, 0.8, 1.0) if auto else Pal.ink(0.5), font)
	# one marker for the tool in hand: it springs from slot to slot and stretches as it goes
	var sel := clampi(int(round(sel_x.x)), 0, _slots() - 1)
	var mw := 132.0 + minf(90.0, absf(sel_x.v) * 14.0)
	var mx := r.position.x + sel_x.x * 142.0 + 66.0
	var my: float = r.position.y + 14.0 + 70.0 - 3.0 + slot_y[sel].x + (1.0 - Pal.ease_out(Motion.stagger(in_t, 3 + sel, 0.05, 0.5))) * 150.0
	c.draw_style_box(UiSkin.box("accent", 1.0), Rect2(mx - mw * 0.5 + 14.0, my - 2.0, mw - 28.0, 3))


func _tool_icon(n: int, p: Vector2, on: float) -> void:
	var col := Pal.ink(0.4 + 0.55 * on)
	match n:
		1:
			FastDraw.polyline(c, PackedVector2Array([p + Vector2(0, -9), p + Vector2(9, 0), p + Vector2(0, 9), p + Vector2(-9, 0), p + Vector2(0, -9)]), col, 1.4, true)
			FastDraw.circle(c, p, 2.0, col)
		2:
			c.draw_line(p + Vector2(-10, 8), p + Vector2(10, -8), Pal.heat(0.4 + 0.6 * on, 1.0 + on), 2.0, true)
			FastDraw.circle(c, p + Vector2(10, -8), 2.5, col)
		3:
			FastDraw.arc(c, p, 9.0, 0.5, PI - 0.5, 12, col, 2.0, true)
			FastDraw.arc(c, p, 9.0, PI + 0.5, TAU - 0.5, 12, col, 2.0, true)
		4:
			FastDraw.arc(c, p, 6.0, 0.0, TAU, 16, col, 1.6, true)
			for k in 6:
				var a := TAU * k / 6.0 + t * on * 0.6
				c.draw_line(p + Vector2.from_angle(a) * 6.0, p + Vector2.from_angle(a) * 10.0, col, 2.0)
		5:
			FastDraw.arc(c, p, 9.0, 0.0, TAU, 20, col, 1.4, true)
			FastDraw.arc(c, p, 4.0, 0.0, TAU, 12, col, 1.2, true)
		6:
			c.draw_rect(Rect2(p + Vector2(-7, -7), Vector2(14, 14)), col, false, 1.4)
			c.draw_line(p + Vector2(0, -12), p + Vector2(0, -7), col, 1.4)
			c.draw_line(p + Vector2(0, 7), p + Vector2(0, 12), col, 1.4)


func _drone_status(s: Vector2) -> void:
	var g = game
	var d = g.drone
	var x := 40.0
	var y := s.y - 70.0
	UI.panel(c, Rect2(x - 18, y - 36, 420, 70), 0.82, 0.0, Pal.HEAT, _boot(2))
	var title := "R-02"
	if g.boat != null and g.boat.aboard:
		title = g.txt("boat_hud")
	elif g.tram != null and g.tram.riding:
		title = g.txt("tram_hud") % Port.name_of(g.tram.dest)
	_text(title, Vector2(x, y), 18, Pal.ink(0.9), font_b)
	var integ: float = d.integrity if d.alive else 0.0
	var bw := 180.0
	# a hit shakes the bar; the lost part hangs on in heat, then drains
	var sh := Vector2(sin(t * 71.0), cos(t * 53.0)) * 3.0 * hurt * hurt
	var bx := x + 60 + sh.x
	var byy := y - 10 + sh.y
	c.draw_rect(Rect2(bx, byy, bw, 6), Pal.ink(0.1))
	if integ_ghost > integ + 0.1:
		c.draw_rect(Rect2(bx + bw * integ / 100.0, byy, bw * (integ_ghost - integ) / 100.0, 6), Pal.heat(0.85, 1.3))
	var low: bool = integ <= 35.0 and d.alive
	var col := Pal.ink(0.85) if not low else Pal.heat(0.75 + 0.25 * sin(t * 7.0), 1.2)
	c.draw_rect(Rect2(bx, byy, bw * integ / 100.0, 6), col)
	if low:
		c.draw_rect(Rect2(bx - 3, byy - 3, bw + 6, 12), Pal.heat(0.35 + 0.3 * sin(t * 7.0), 1.2), false, 1.0)
	_text(g.txt("integrity") + "  %d%%" % int(round(integ_roll.shown)), Vector2(x + 60, y + 16), 13, Pal.ink(0.5), font)
	d.assist_k = Pal.damp(d.assist_k, 1.0 if d.assist else 0.0, 14.0, get_process_delta_time())
	var sw := Rect2(x + 60 + bw + 26, y - 14, 34, 14)
	c.draw_rect(sw, Pal.ink(0.08 + 0.1 * d.assist_k))
	c.draw_rect(sw, Pal.ink(0.35 + 0.4 * d.assist_k), false, 1.0)
	c.draw_rect(Rect2(sw.position + Vector2(2 + 18 * d.assist_k, 2), Vector2(12, 10)), Pal.ink(0.5 + 0.45 * d.assist_k) if d.assist else Pal.ink(0.35))
	_text("F " + game.txt("assist"), Vector2(sw.end.x + 8, y - 2), 13, Pal.ink(0.5 + 0.4 * d.assist_k), font)
	# 117 号 (Q2 A): on site the speed is the HS tape's; the name, the hull and the thrust stay here
	if not UiSkin.field:
		_text("%.1f m/s" % spd_roll.shown, Vector2(x + 60 + bw, y + 16), 13, Pal.ink(0.55), font, 1)
	if not d.alive:
		_text("R-02 …", Vector2(x, y - 30), 14, Pal.heat(0.9, 1.2), font)
	_items()


# consumables in hand for this contract: key, icon, name and how many are left;
# a click uses the repair kit or readies the ring
func _items() -> void:
	var g = game
	var mp := c.get_local_mouse_position()
	for it in _item_slots():
		var id: String = it[0]
		var r: Rect2 = it[1]
		var n: int = g.stock(id)
		var armed: bool = id == "ring" and g.ring_armed
		var over: bool = r.has_point(mp) and id != "spare"
		var a := 1.0 if n > 0 else 0.4
		var sp := clampf(stock_pop / 0.6, 0.0, 1.0) if stock_hit == id else 1.0
		r.position.y -= 4.0 * sin(sp * PI) + (4.0 if over else 0.0)
		c.draw_rect(r, Color(0.035, 0.037, 0.042, 0.88))
		var edge := Pal.heat(0.9, 1.4) if armed else (Pal.heat(0.4 + 0.6 * (1.0 - sp), 1.2) if sp < 1.0 else Pal.ink(0.14 + (0.3 if over else 0.0)))
		c.draw_rect(r, edge, false, 1.5 if armed else 1.0)
		if armed:
			c.draw_rect(r.grow(3.0 + 2.0 * sin(t * 6.0)), Pal.heat(0.35, 1.2), false, 1.0)
		var key: String = {"repair": Keys.label("repair"), "ring": Keys.label("ring"), "spare": g.txt("it_auto")}[id]
		_text(key, r.position + Vector2(10, 20), 13, Pal.ink(0.55 * a) if id == "spare" else Pal.ink(0.9 * a), font_b)
		_item_icon(id, r.position + Vector2(r.size.x - 24, 18), a, armed)
		_text(g.txt("it_" + id), r.position + Vector2(10, 46), 14, Pal.ink(0.75 * a), font)
		_text("×%d" % n, r.position + Vector2(r.size.x - 10, 47), 17, Pal.heat(1.0, 1.3) if armed else Pal.ink(0.95 * a), font_b, 1)


func _item_icon(id: String, p: Vector2, a: float, hot: bool) -> void:
	var col := Pal.heat(a, 1.4) if hot else Pal.ink(0.8 * a)
	match id:
		"repair":
			c.draw_rect(Rect2(p + Vector2(-10, -3), Vector2(20, 6)), col, false, 1.4)
			c.draw_rect(Rect2(p + Vector2(-3, -10), Vector2(6, 20)), col, false, 1.4)
		"ring":
			var r := 8.0 + (1.5 * sin(t * 6.0) if hot else 0.0)
			FastDraw.arc(c, p, r, 0.0, TAU, 24, col, 1.6, true)
			for k in 8:
				var d := Vector2.from_angle(TAU * k / 8.0)
				c.draw_line(p + d * r, p + d * (r + 4.0), Pal.heat(0.9 * a, 1.2), 1.6)
		"spare":
			FastDraw.polyline(c, PackedVector2Array([p + Vector2(-10, 6), p + Vector2(0, -9), p + Vector2(10, 6), p + Vector2(-10, 6)]), col, 1.4, true)
			FastDraw.circle(c, p + Vector2(0, 1), 2.5, col)


# the readied ring: the member it found, the cut it would make and what a click does
func _ring_overlay() -> void:
	var g = game
	var tg: Dictionary = g.ring_aim
	var mp := to_screen(g.aim)
	var zoom: float = g.get_viewport().get_canvas_transform().get_scale().x
	# how far the drone can place it
	if g.drone.alive:
		FastDraw.arc(c, to_screen(g.drone.global_position), g.RING_REACH * zoom, 0.0, TAU, 96, Pal.heat(0.18, 1.0), 1.0, true)
	var line := ""
	var col := Pal.heat(1.0, 1.6)
	if tg.has("piece"):
		var ok: bool = tg.ok
		col = Pal.heat(0.95, 1.6) if ok else Pal.ink(0.45)
		var poly: PackedVector2Array = g.world.world_poly(tg.piece)
		var sp := PackedVector2Array()
		for q in poly:
			sp.append(to_screen(q))
		sp.append(sp[0])
		FastDraw.polyline(c, sp, Pal.heat(0.55, 1.2) if ok else Pal.ink(0.3), 1.5, true)
		var a := to_screen(tg.line[0])
		var b := to_screen(tg.line[1])
		var pulse := 0.6 + 0.4 * sin(t * 8.0)
		c.draw_line(a, b, Pal.heat(pulse if ok else 0.3, 2.0 if ok else 1.0), 3.0 if ok else 1.5)
		var at := to_screen(tg.at)
		FastDraw.arc(c, at, 12.0, 0.0, TAU, 24, col, 2.0, true)
		for k in 8:
			var d := Vector2.from_angle(TAU * k / 8.0 + t * 0.8)
			c.draw_line(at + d * 12.0, at + d * 17.0, col, 2.0)
		if at.distance_to(mp) > 6.0:
			c.draw_dashed_line(mp, at, Pal.ink(0.35), 1.0, 4.0)
		line = g.txt("ring_ready") if ok else g.txt("ring_far")
	else:
		FastDraw.arc(c, mp, g.RING_SNAP * zoom, 0.0, TAU, 48, Pal.ink(0.25), 1.0, true)
		line = g.txt("ring_seek")
	var name: String = g.txt("it_ring") + "  ×%d" % g.stock("ring")
	var w := maxf(_tw(name, 14, font_b), _tw(line, 13)) + 16.0
	var op := mp + Vector2(24, 20)
	c.draw_style_box(UiSkin.box("tag", 0.86), Rect2(op - Vector2(8, 16), Vector2(w, 42)))
	c.draw_rect(Rect2(op - Vector2(2, 8), Vector2(3, 26)), UiSkin.ACCENT)
	_text(name, op, 14, Pal.ink(0.95), font_b)
	_text(line, op + Vector2(0, 19), 13, Pal.heat(0.9, 1.2) if tg.get("ok", false) else Pal.ink(0.6), font)


func _hint(s: Vector2) -> void:
	if hint_text == "" or hint_t > 9.0 or game.state == "porttour":
		return
	var a := clampf(hint_t / 0.3, 0.0, 1.0) * clampf((9.0 - hint_t) / 0.6, 0.0, 1.0)
	var w := minf(980.0, _tw(hint_text, 16) + 60.0)
	var lines := 1
	if _tw(hint_text, 16) > 920.0:
		lines = 2
	# top centre: the bottom of the screen belongs to the radio and the toolbar
	# below the main-line card when it is up (61 号: the card is wider now)
	var top := 124.0 if _main_on() else 64.0
	# user 2026-10-26: the guide card and the arrival card sit there too — the line goes under them
	if _guide_on():
		top = _guide_rect(s).end.y + 12.0
	if not game.arrival.is_empty() and game.state == "play":
		top = arrival_rect(s).end.y + 12.0
	var r := Rect2(s.x * 0.5 - w * 0.5, top - (1.0 - Pal.ease_out(a)) * 10.0, w, 18.0 + lines * 22.0)
	var ow := w * (Pal.ease_out(clampf(hint_t / 0.24, 0.0, 1.0)) if hint_t < 1.0 else 1.0)
	var ta := a * clampf((hint_t - 0.1) / 0.2, 0.0, 1.0)
	var ro := Rect2(s.x * 0.5 - ow * 0.5, r.position.y, ow, r.size.y)
	# 54 号: a rounded panel with a rounded warm bar inside its left edge
	c.draw_style_box(UiSkin.box("panel", a), ro)
	c.draw_rect(Rect2(ro.position + Vector2(8, 9), Vector2(3, ro.size.y - 18)), Color(UiSkin.ACCENT, a))
	c.draw_multiline_string(font, r.position + Vector2(22, 26 + (1.0 - ta) * 4.0), hint_text, HORIZONTAL_ALIGNMENT_LEFT, w - 40.0, 16, lines, Pal.ink(0.88 * ta))


# readings: tags anchored on the ship
func _world_tags() -> void:
	var g = game
	var w = g.world
	var mouse := c.get_local_mouse_position()
	var hovered = null
	var rects: Array = []
	for key in g.sys.readings:
		var r: Dictionary = g.sys.readings[key]
		var anchor := Vector2.INF
		if r.has("ctrl"):
			if not w.ctrl_alive(r.ctrl):
				continue
			anchor = w.ctrl_world(r.ctrl)
		elif r.has("piece"):
			if r.piece.gone:
				continue
			anchor = w.frame(r.piece) * r.local
		elif r.has("anchor_pos"):
			anchor = r.anchor_pos
		if anchor == Vector2.INF:
			continue
		var sp := to_screen(anchor)
		if not Rect2(Vector2(-200, -200), size() + Vector2(400, 400)).has_point(sp):
			continue
		if not tag_birth.has(key) or tag_birth[key][0] != r.t:
			tag_birth[key] = [r.t, t]
		var age: float = t - tag_birth[key][1]
		var live: bool = r.get("live", false)
		var stale: bool = g.sys.stale(r) and not live
		var label: String = r.at
		var val: String = r.text
		if age < 0.45 and not stale:
			# digits tumble before they settle
			var sc := ""
			for ch in val:
				sc += str(randi() % 10) if ch >= "0" and ch <= "9" else ch
			val = sc
		if r.has("inspect"):
			val = r.inspect + "  ·  " + r.text
			# a story piece: the tag opens into a small card
			if g.story != null:
				var it = g.story.item_for(r.piece)
				if it != null and g.story.found.has(it.id):
					rects.append(_story_card(sp, it, val, age))
					continue
		var off := Vector2(16, -26)
		if key.ends_with("/T") or key.ends_with("/V"):
			off = Vector2(16, -6)
		var pos := sp + off
		var tw := _tw(label, 13) + _tw(val, 15, font_b) + 30.0
		# clear of every tag already placed: step up above whichever it hits, a few times over
		for tries in 8:
			var hit := false
			for prev in rects:
				if prev.grow(3.0).intersects(Rect2(pos - Vector2(0, 16), Vector2(tw, 22))):
					pos.y = prev.position.y - 9.0
					hit = true
			if not hit:
				break
		var rect := Rect2(pos - Vector2(0, 16), Vector2(tw, 22))
		# 117 号 (Q5 A): out of the HUD's way, the leader stretching back to the reading
		var cl := clear_of(rect)
		pos += cl[0]
		rect.position += cl[0]
		rects.append(rect)
		var pop := Pal.back(clampf(age / 0.25, 0.0, 1.0), 2.0)
		var a: float = (1.0 if not stale else 0.5) * cl[1]
		c.draw_line(sp, pos + Vector2(0, 6), Pal.ink(0.3 * a), 1.0, true)
		FastDraw.circle(c, sp, 2.5, Pal.ink(0.8 * a))
		if live:
			# a probe keeps this one live: it breathes in heat
			FastDraw.arc(c, sp, 5.0 + 1.5 * sin(t * 5.0), 0.0, TAU, 16, Pal.heat(0.7 + 0.3 * sin(t * 5.0), 1.4), 1.2, true)
		var rr := Rect2(rect.position, Vector2(rect.size.x * pop, rect.size.y))
		c.draw_style_box(UiSkin.box("tag", 0.88), rr)
		c.draw_rect(Rect2(rr.position, Vector2(2, rr.size.y)), _kind_col(r.kind, a))
		if pop > 0.6:
			_text(label, pos + Vector2(8, 0), 13, Pal.ink(0.5 * a), font)
			var vcol := Pal.ink(0.95 * a) if not stale else Pal.ink(0.4)
			var vx := pos.x + 16 + _tw(label, 12)
			_text(val, Vector2(vx, pos.y + 1), 15, vcol, font_b)
			if stale:
				c.draw_line(Vector2(vx - 2, pos.y - 5), Vector2(vx + _tw(val, 15, font_b) + 2, pos.y - 5), Pal.ink(0.5), 1.0)
		if rect.has_point(mouse):
			hovered = [r, rect, stale]
	if hovered != null:
		var r: Dictionary = hovered[0]
		var rect: Rect2 = hovered[1]
		var lines := [
			"%s  %s" % [game.txt("read_by"), game.txt(r.inst)],
			"%s  %s" % [game.txt("read_at"), r.at],
			"%s  T+%s" % [game.txt("read_time"), _clock(r.t)],
		]
		if hovered[2]:
			lines.append(game.txt("stale"))
		var box := Rect2(rect.position + Vector2(0, 26), Vector2(260, 22 * lines.size() + 10))
		_panel(box, 0.92)
		for i in lines.size():
			_text(lines[i], box.position + Vector2(10, 22 + i * 22), 13, Pal.ink(0.7) if i < 3 else Pal.heat(0.9, 1.0), font)


func _story_card(sp: Vector2, it: Dictionary, info: String, age: float) -> Rect2:
	var st: Story = game.story
	var body: String = st.pair(it.text)
	var w := 340.0
	var bh: float = font_b.get_multiline_string_size(body, HORIZONTAL_ALIGNMENT_LEFT, w - 28, 15).y
	var pos := sp + Vector2(18, -40 - bh)
	var r := Rect2(pos, Vector2(w, bh + 56))
	var pop := Pal.back(clampf(age / 0.25, 0.0, 1.0), 2.0)
	c.draw_line(sp, pos + Vector2(0, r.size.y), Pal.tint(Pal.AIR, 0.4, 1.0), 1.0, true)
	FastDraw.circle(c, sp, 2.5, Pal.tint(Pal.AIR, 0.9, 1.1))
	var rr := Rect2(r.position, Vector2(r.size.x * pop, r.size.y))
	c.draw_style_box(UiSkin.box("tag", 0.92), rr)
	c.draw_rect(Rect2(rr.position, Vector2(2, rr.size.y)), Pal.tint(Pal.AIR, 0.9, 1.1))
	if pop > 0.6:
		_text(st.pair(it.title), pos + Vector2(14, 18), 13, Pal.tint(Pal.AIR, 0.75, 1.0), font)
		c.draw_multiline_string(font_b, pos + Vector2(14, 40), body, HORIZONTAL_ALIGNMENT_LEFT, w - 28, 15, -1, Pal.ink(0.95))
		_text(info, pos + Vector2(14, r.size.y - 8), 13, Pal.ink(0.5), font)
	return r


func _clock(sec: float) -> String:
	return "%02d:%02d" % [int(sec) / 60, int(sec) % 60]


func _kind_col(kind: String, a: float) -> Color:
	match kind:
		"pressure": return Pal.tint(Pal.AIR, a)
		"volts": return Pal.tint(Pal.VOLT, a)
		"fluid", "temp": return Pal.tint(Pal.FLUID, a)
	return Pal.ink(0.6 * a)


func _messages() -> void:
	var placed: Array = []
	for m in game.messages:
		var age: float = m[2]
		var sp := to_screen(m[1])
		var a := clampf(age / 0.12, 0.0, 1.0) * clampf((2.6 - age) / 0.5, 0.0, 1.0)
		var y := sp.y - 30.0 - Pal.ease_out(age / 2.6) * 26.0
		var txt: String = m[3]
		var w := _tw(txt, 15)
		var box := Rect2(sp.x - w * 0.5 - 8, y - 17, w + 16, 24)
		# 117 号: two said at the same spot (the beam's front) stack instead of printing over each other
		for tries in 6:
			var hit := false
			for prev in placed:
				if prev.grow(2.0).intersects(box):
					box.position.y = prev.position.y - box.size.y - 4.0
					hit = true
			if not hit:
				break
		# 117 号 (Q5 A): clear of the HUD
		var cl := clear_of(box)
		box.position += cl[0]
		a *= cl[1]
		placed.append(box)
		c.draw_style_box(UiSkin.box("tag", 0.7 * a), box)
		_text(txt, Vector2(box.get_center().x, box.position.y + 17), 15, Pal.ink(0.95 * a), font, 0)


# 91 号 (用户 2026-10-27：“HUD 与机械动效”): the work in hand read at the pointer, where the eye
# already is — the beam in the plate (and what the plate is), the line's pull on what the grapple
# holds against what it can take, a measurement or a repair running. A thin ring round the cursor
# that fills, ticks turning while it works; it fades when the hand is idle.
func _gauge() -> void:
	var g = game
	# user 2026-10-27: "鼠标上这个蓝色的标识提醒太难看了，没有用" — on site the work in hand is read
	# out by the drone's OSD instead (scripts/look.gd _job_bar, the payload line, the target box)
	if UiSkin.field:
		gauge_k = 0.0
		return
	if g.tools == null or g.state != "play" or g.bot != null and not g.bot.get("gauge", false):
		return
	var tl = g.tools
	var kind := ""
	var fill := 0.0
	var col := Color(UiSkin.ACCENT)
	var line1 := ""
	var line2 := ""
	if tl.cutting:
		kind = "cut"
		fill = clampf(tl.material_k, 0.0, 1.0)
		line1 = Ops.w("切割中", "CUTTING") if tl.in_material else Ops.w("空切", "IN THE OPEN")
		if tl.cut_mat != null and str(tl.cut_mat.mat) != "":
			line2 = Mat.name_of(str(tl.cut_mat.mat))
	elif tl.held_body != null and is_instance_valid(tl.held_body):
		kind = "pull"
		var m: float = tl.held_body.total_mass()
		var cap: float = g.grab_max()
		fill = clampf(m / maxf(cap, 0.01), 0.0, 1.0)
		col = Color(UiSkin.DATA) if not tl.overweight else Color(1.0, 0.35, 0.25)
		line1 = "%.2f / %.1f t" % [m, cap]
		line2 = Ops.w("超重，拉不动", "TOO HEAVY") if tl.overweight else (Ops.w("拉紧", "TAUT") if tl.tether_force > 0.25 else Ops.w("松", "SLACK"))
	elif not tl.job.is_empty() and float(tl.job.get("dur", 0.0)) > 0.0:
		kind = "job"
		fill = clampf(float(tl.job.get("t", 0.0)) / float(tl.job.dur), 0.0, 1.0)
		col = Color(UiSkin.DATA)
		line1 = Ops.w("测量中", "MEASURING") if str(tl.job.get("kind", "")) == "measure" else Ops.w("作业中", "WORKING")
		line2 = "%d%%" % int(fill * 100.0)
	var dt := get_process_delta_time()
	gauge_k = Pal.damp(gauge_k, 1.0 if kind != "" else 0.0, 12.0 if kind != "" else 6.0, dt)
	if kind != "":
		gauge_kind = kind
	gauge_spin += dt * (2.4 if kind != "" else 0.6)
	if gauge_k < 0.02:
		return
	var a := gauge_k
	var p: Vector2 = c.get_local_mouse_position() if g.bot == null or not g.bot.has("gauge_at") else g.bot.gauge_at
	var r := 26.0 + 6.0 * (1.0 - Pal.ease_out(a))
	FastDraw.arc(c, p, r, 0.0, TAU, 48, Pal.ink(0.12 * a), 1.0, true)
	if fill > 0.005:
		var a0 := -PI * 0.5
		FastDraw.arc(c, p, r, a0, a0 + TAU * fill, maxi(6, int(48 * fill)), Color(col.r, col.g, col.b, 0.95 * a), 2.6, true)
	# the ticks turning while the hand works
	for k in 6:
		var an := gauge_spin + TAU * k / 6.0
		var d := Vector2.from_angle(an)
		c.draw_line(p + d * (r + 4.0), p + d * (r + 8.0), Color(col.r, col.g, col.b, 0.5 * a), 1.2, true)
	if gauge_kind == "pull" and game.tools.overweight:
		var pl := 0.5 + 0.5 * sin(t * 14.0)
		FastDraw.arc(c, p, r + 12.0, 0.0, TAU, 48, Color(1.0, 0.35, 0.25, 0.4 * pl * a), 2.0, true)
	var tp := p + Vector2(r + 16.0, -2.0)
	_text(line1, tp, 13, Color(col.r, col.g, col.b, 0.95 * a), font_b)
	if line2 != "":
		_text(line2, tp + Vector2(0, 17), 12, Pal.ink(0.6 * a), font)


func _cursor_label() -> void:
	var g = game
	var h: Dictionary = g.tools.hover
	var mp := c.get_local_mouse_position()
	if g.ring_armed:
		_ring_overlay()
		return
	# 91 号: on site a part under the pointer is boxed and read out by the drone's OSD
	# (scripts/look.gd _designator), so its name tag here would only repeat it
	if UiSkin.field and not h.is_empty() and str(h.get("kind", "")) in ["piece", "inspect"] and g.tools.tool != 2:
		cur_key = ""
		cur_last = []
		return
	if g.tools.tool == 2 or h.is_empty():
		if cur_key != "":
			cur_out = 0.0
		cur_key = ""
		if not cur_last.is_empty() and cur_out < 0.12 and Txt.anim_level() > 0:
			var oa := 1.0 - cur_out / 0.12
			var op: Vector2 = cur_last[0]
			c.draw_style_box(UiSkin.box("tag", 0.82 * oa), Rect2(op - Vector2(8, 16), Vector2(cur_last[3], 42)))
			_text(cur_last[1], op + Vector2(0, -4.0 * (1.0 - oa)), 14, Pal.ink(0.95 * oa), font_b)
			_text(cur_last[2], op + Vector2(0, 19 - 4.0 * (1.0 - oa)), 13, Pal.ink(0.55 * oa), font)
		return
	var name := ""
	var act := ""
	match h.kind:
		"ctrl":
			name = h.ctrl.id
			act = _ctrl_action(h.ctrl)
		"joint":
			name = h.label if h.label != "" else g.txt("j_" + h.joint.type)
			act = g.txt({"bolt": "act_unbolt", "lock": "act_unlock", "clamp": "act_clamp"}[h.joint.type])
		"connector":
			name = h.label
			act = g.txt("act_unplug")
		"line":
			name = h.label
			act = g.txt("act_measure")
		"piece", "inspect":
			name = Txt.piece_name(h.piece)
			var m: float = g.world.group_mass(h.piece)
			act = ("%.2f t" % m) if g.tools.tool == 3 else g.txt("act_inspect")
			if not h.piece.scope:
				act += "  ·  " + g.txt("sc_out")
	if not h.ok:
		act = g.txt(h.reason)
	if name != cur_key:
		if cur_key == "":
			cur.snap(mp)
		cur_key = name
		cur_t = 0.0
	var la := clampf(cur_t / 0.12, 0.0, 1.0)
	var pos := cur.x + Vector2(22, 30 + (1.0 - Pal.ease_out(la)) * 6.0)
	var w := maxf(_tw(name, 14), _tw(act, 13)) + 20.0
	cur_last = [pos, name, act, w]
	c.draw_style_box(UiSkin.box("tag", 0.82 * la), Rect2(pos - Vector2(8, 16), Vector2(w, 42)))
	c.draw_rect(Rect2(pos - Vector2(8, 16), Vector2(2, 42 * Pal.ease_out(la))), Pal.ink(0.4 * la))
	_text(name, pos, 14, Pal.ink(0.95 * la), font_b)
	var heavy: bool = g.tools.tool == 3 and h.kind == "piece" and g.world.group_mass(h.piece) > g.grab_max()
	_text(act, pos + Vector2(0, 19), 13, Pal.heat(0.9 * la, 1.1) if (not h.ok or heavy) else Pal.ink(0.55 * la), font)


func _ctrl_action(ctrl) -> String:
	var g = game
	match g.tools.tool:
		1: return g.txt("act_measure")
		5: return g.txt("act_hose_off") if g.sys.hoses.has(ctrl.id) else g.txt("act_hose_on")
	match ctrl.kind:
		"valve": return g.txt("act_valve_close") if ctrl.state else g.txt("act_valve_open")
		"switch": return g.txt("act_switch_off") if ctrl.state else g.txt("act_switch_on")
		"remote": return g.txt("act_remote")
		"stop": return g.txt("act_stop")
		"socket": return g.txt("act_socket")
		"discharge": return g.txt("act_discharge")
		"door": return g.txt("act_door")
		"hatch": return g.txt("act_hatch")
		"jam": return g.txt("act_jam")
		"degauss": return g.txt("act_degauss")
		"seal": return g.txt("act_seal")
	return ""


# ---------------------------------------------------------------- contract card

func _card_rect(s: Vector2) -> Rect2:
	var k: float = clampf(card_k.x, 0.0, 1.2)
	return Rect2(s.x * 0.5 - 450.0, s.y * 0.5 - 340.0 + (1.0 - k) * 60.0, 900.0, 680.0)


# the card's right column: the numbers that decide how to go about it
func _card_numbers(r: Rect2, a: float) -> void:
	var g = game
	var o: Dictionary = g.job
	var x := r.position.x + 560.0
	var y := r.position.y + 58.0
	c.draw_line(Vector2(x - 24, r.position.y + 40), Vector2(x - 24, r.end.y - 40), Pal.ink(0.1 * a), 1.0)
	var value: float = float(o.get("value", g.ship.get("value", {}).get("total", 0.0)))
	var rows := [
		[g.txt("tm_value"), Pal.money(value)],
		[g.txt("tm_fee"), Pal.money(g.fee) + ("  ✓" if o.get("fee_paid", false) else "")],
		[g.txt("tm_time"), (g.txt("tm_minutes_short") % int(g.standard_time() / 60.0)) if g.standard_time() > 0.0 else "—"],
	]
	_text(g.txt("c_numbers"), Vector2(x, y), 14, Pal.ink(0.6 * a), font)
	for i in rows.size():
		var yy := y + 40 + i * 58
		_text(rows[i][0], Vector2(x, yy), 13, Pal.ink(0.55 * a), font)
		_text(rows[i][1], Vector2(x, yy + 28), 24, Pal.ink(0.95 * a), font_l)
	if int(o.get("stars", 0)) > 0:
		_text(g.txt("tm_risk_" + str(int(o.stars))), Vector2(x + 300, y + 40), 14, Pal.heat(0.9 * a, 1.1) if int(o.stars) >= 2 else Pal.ink(0.7 * a), font_b, 1)


func _start_rect(r: Rect2) -> Rect2:
	return Rect2(r.position.x + 560.0, r.end.y - 104.0, 300.0, 64.0)


func _contract_card(s: Vector2) -> void:
	var k: float = clampf(card_k.x, 0.0, 1.2)
	var a := clampf(k, 0.0, 1.0)
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.55 * a))
	var r := _card_rect(s)
	_panel(r, 0.95 * a)
	c.draw_rect(Rect2(r.position + Vector2(8, 10), Vector2(3, r.size.y - 20)), Color(UiSkin.ACCENT, a))
	var g = game
	var x := r.position.x + 48
	var y := r.position.y + 58
	var w := 470.0
	_card_numbers(r, a)
	# one format for every contract: the hand-made GR-001 card keeps its own words,
	# every other contract (the opening tug and Swift too) reads from its own ship
	var rows: Array = _offer_rows() if g.job.has("reg") or str(g.ship.get("id", "gr7")) != "gr7" else []
	if rows.is_empty():
		rows.append(["h", g.txt("c_title"), 14])
		rows.append(["t", g.txt("ship"), 30])
		rows.append(["gap", "", 12])
		rows.append(["h", g.txt("c_req"), 13])
		for i in range(1, 5):
			rows.append(["li", g.txt("c_req%d" % i), 16])
		rows.append(["gap", "", 10])
		rows.append(["h", g.txt("c_log"), 13])
		for i in range(1, 6):
			rows.append(["kv", g.txt("c_log%d" % i), g.txt("c_log%dv" % i)])
		rows.append(["gap", "", 10])
		rows.append(["p", g.txt("c_brief"), 15])
		rows.append(["p", g.txt("c_drawing"), 15])
		rows.append(["gap", "", 6])
		rows.append(["h", g.txt("c_fee"), 13])
	var i := 0
	for row in rows:
		var rk := Motion.stagger(card_t, i, 0.03, 0.3)
		var ra := a * rk
		var dx := (1.0 - Pal.ease_out(rk)) * 24.0
		match row[0]:
			"h":
				_text(row[1], Vector2(x + dx, y), row[2], Pal.ink(0.5 * ra), font)
				y += 26
			"t":
				_text(row[1], Vector2(x + dx, y + 8), row[2], Pal.ink(0.95 * ra), font_l)
				y += 40
			"li":
				FastDraw.circle(c, Vector2(x + 6 + dx, y - 5), 2.0, Pal.ink(0.7 * ra))
				var lines: int = clampi(int(ceil(_tw(row[1], row[2]) / (w - 20.0))), 1, 2)
				c.draw_multiline_string(font, Vector2(x + 20 + dx, y), row[1], HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, row[2], 2, Pal.ink(0.88 * ra))
				y += 25 + (lines - 1) * 22
			"kv":
				_text(row[1], Vector2(x + 20 + dx, y), 15, Pal.ink(0.55 * ra), font)
				_text(row[2], Vector2(x + 300 + dx, y), 15, Pal.ink(0.9 * ra), font_b)
				y += 24
			"p":
				c.draw_multiline_string(font, Vector2(x + dx, y), row[1], HORIZONTAL_ALIGNMENT_LEFT, w, row[2], 3, Pal.ink(0.8 * ra))
				y += 48
			"gap":
				y += row[2]
		i += 1
	# 93 号: the ship's core asset, and the ways to take it, each with its money, time and risk
	var ca: Dictionary = CoreAsset.card(g)
	if not ca.is_empty():
		y = _asset_card(ca, x, y + 12.0, w, a)
	# 104 号: the dismantling methods this ship has a use for, learned (✓) or not yet (○)
	var mu := Methods.useful_text(g)
	if mu != "":
		c.draw_multiline_string(font, Vector2(x, y + 30.0), mu, HORIZONTAL_ALIGNMENT_LEFT, w, 15, 2, Pal.ink(0.78 * a))
		y += 30.0 + (22.0 if _tw(mu, 15) > w else 0.0)
	# what is new on this ship: its own mechanisms, in the book already (I opens it)
	if g.codex_hud != null:
		g.codex_hud.draw_brief(c, Vector2(x, maxf(y + 22.0, r.position.y + 470.0)), w, a)
	# the ship's papers: what the manifest declares aboard
	_manifest(r, a)
	var m := c.get_local_mouse_position()
	UI.button(c, font_b, _start_rect(r), g.txt("c_start_btn"), 1.0 if _start_rect(r).has_point(m) else 0.0, true, a, t)


# The ship's manifest on the card's right column, the same for every ship: its
# size, the pressurised compartments, the power supplies, the pressure vessels
# and fluid tanks, the equipment aboard (count, worth, the most valuable) and the
# declared hazards. Read from the ship's papers (its type's file), not from what
# this particular ship really holds: what an accident changed is not on them.
func _manifest(r: Rect2, a: float) -> void:
	var g = game
	var d: Dictionary = Ship.load_data(str(g.ship.get("id", "gr7")))
	var x := r.position.x + 560.0
	var w := 300.0
	var y := r.position.y + 300.0
	_text(g.txt("mf_title"), Vector2(x, y), 14, Pal.ink(0.6 * a), font)
	y += 8.0
	c.draw_line(Vector2(x, y), Vector2(x + w, y), Pal.ink(0.12 * a), 1.0)
	var names := func(keys: Array, limit: int) -> String:
		var out: Array = keys.slice(0, limit)
		return "、".join(out) + (g.txt("mf_more") % keys.size() if keys.size() > limit else "")
	var rooms: Array = []
	for n in d.get("gas", {}).get("rooms", {}):
		if float(d.gas.rooms[n]) > 1.0:
			rooms.append(n)
	var power: Array = []
	for sp in d.get("power", {}).get("sources", []):
		power.append(sp.piece)
	for sp in d.get("power", {}).get("isolated", []):
		power.append(sp.piece)
	var vessels: Array = d.get("gas", {}).get("vessels", {}).keys()
	var tanks: Array = []
	for k in d.get("fluids", {}).get("volumes", {}):
		if d.fluids.volumes[k].has("piece"):
			tanks.append(d.fluids.volumes[k].piece)
	var equip: Array = []
	var hazards: Array = []
	var worth := 0.0
	for pd in d.get("pieces", []):
		if pd.get("cls", "") != "equip":
			continue
		equip.append(pd)
		worth += float(pd.get("value", 0.0))
		if pd.get("hazard", "") != "" and pd.get("tag", "") != "":
			hazards.append(pd.tag)
	equip.sort_custom(func(p, q): return float(p.get("value", 0.0)) > float(q.get("value", 0.0)))
	var top: Array = []
	for pd in equip.slice(0, 3):
		top.append("%s %s" % [str(pd.get("tag", "")), Pal.money(float(pd.get("value", 0.0)))])
	var rows := [
		[g.txt("mf_length"), "%d m" % int(float(d.get("length", 0.0)))],
		[g.txt("mf_rooms"), (g.txt("mf_n") % rooms.size()) + ("  " + names.call(rooms, 6) if not rooms.is_empty() else "")],
		[g.txt("mf_power"), names.call(power, 3) if not power.is_empty() else "—"],
		[g.txt("mf_vessels"), names.call(vessels, 4) if not vessels.is_empty() else "—"],
		[g.txt("mf_tanks"), names.call(tanks, 4) if not tanks.is_empty() else "—"],
		[g.txt("mf_equip"), (g.txt("mf_n") % equip.size()) + "  " + Pal.money(worth)],
		[g.txt("mf_top"), "\n".join(top)],
		[g.txt("mf_hazard"), names.call(hazards, 5) if not hazards.is_empty() else "—"],
	]
	y += 22.0
	for i in rows.size():
		var ra := a * Motion.stagger(card_t, 6 + i, 0.03, 0.3)
		_text(rows[i][0], Vector2(x, y), 12, Pal.ink(0.5 * ra), font)
		var lines: PackedStringArray = str(rows[i][1]).split("\n")
		for li in lines.size():
			c.draw_string(font, Vector2(x + 76.0, y + li * 17.0), lines[li], HORIZONTAL_ALIGNMENT_LEFT, w - 76.0, 12, Pal.ink(0.88 * ra))
		y += 21.0 + 17.0 * maxf(0.0, lines.size() - 1)


# a contract from the market: its card is the offer the player took
func _offer_rows() -> Array:
	var g = game
	var o: Dictionary = g.job
	var ty: Dictionary = Market.type_of(o.get("ship", ""))
	var rows: Array = []
	rows.append(["h", g.txt("c_title_n") % o.get("id", ""), 14])
	if o.has("reg"):
		rows.append(["t", "%s · %s" % [o.get("reg", ""), (ty.name[0] if Txt.zh else ty.name[1]) if not ty.is_empty() else ""], 28])
	else:
		var ttl: Array = g.ship.get("title", ["", ""])
		rows.append(["t", str(ttl[0] if Txt.zh else ttl[1]), 26])
	rows.append(["gap", "", 12])
	rows.append(["h", g.txt("c_req"), 13])
	rows.append(["li", g.txt("c_req1"), 16])
	# what this contract asks for by name (a part-ship job has its own list, or none)
	var must: Array = []
	for it in g.mandatory_items():
		must.append("%s %s" % [it[1], it[0]])
	if not must.is_empty():
		rows.append(["li", g.txt("c_req2_n") % "、".join(must), 16])
	rows.append(["li", g.txt("c_req3_n") % Pal.money(float(o.get("value", g.ship.get("value", {}).get("total", 0.0)))), 16])
	if o.get("scope", "full") == "full":
		rows.append(["li", g.txt("c_req4"), 16])
	if Market.goal_text(o) != "":
		rows.append(["li", Market.goal_text(o), 16])
	rows.append(["gap", "", 10])
	# why it was scrapped and its last log: the market's draw, or the opening contract's own slots
	var reason: String = o.get("reason", "C_reason_" + str(o.get("id", "")))
	rows.append(["h", g.txt("tm_reason"), 13])
	rows.append(["p", Copy.slot(reason), 15])
	if not o.get("logs", []).is_empty():
		rows.append(["h", g.txt("c_log_n"), 13])
		for lid in o.get("logs", []):
			rows.append(["li", Copy.slot(lid), 16])
	rows.append(["gap", "", 6])
	rows.append(["p", g.txt("c_drawing"), 15])
	if o.get("scope", "full") != "full":
		rows.append(["h", g.txt("sc_" + o.scope), 13])
		rows.append(["p", Market.scope_text(o), 15])
	return rows


# ---------------------------------------------------------------- pause menu

func _menu_items() -> Array:
	# user 2026-10-26: the pause menu is three keys and nothing else — no heading, no other rows;
	# while a ship is being stripped, ending the contract early as well
	var items := [["resume", game.txt("m_resume")]]
	if game.can_end_early():
		items.append(["end", game.txt("m_end") if menu_confirm != 1 else game.txt("m_confirm")])
	return items + [
		["settings", game.txt("m_settings")],
		["title", Ops.w("返回", "BACK") if menu_confirm != 4 else game.txt("m_confirm")],
	]


func _menu_rect(i: int) -> Rect2:
	var s := size()
	var n := _menu_items().size()
	return Rect2(s.x * 0.5 - 220, s.y * 0.5 - (n * 58 - 10) * 0.5 + i * 58, 440, 48)


func _menu_hover() -> void:
	var m := c.get_local_mouse_position()
	menu_hover = -1
	for i in _menu_items().size():
		if _menu_rect(i).has_point(m):
			menu_hover = i


func _menu_click() -> void:
	if menu_page != "":
		menu_page = ""
		game.sfx.play("menu")
		return
	if menu_hover < 0:
		return
	var id: String = _menu_items()[menu_hover][0]
	game.sfx.play("ok")
	match id:
		"resume":
			game.toggle_menu()
		"end":
			if menu_confirm == 1:
				game.toggle_menu()
				game.finish_contract(true)
			else:
				menu_confirm = 1
		"settings":
			game.settings_panel.open()
		"title":
			if menu_confirm == 4:
				game.to_title()
			else:
				menu_confirm = 4


# 68 号 §4: the pause menu's controls page (every key as bound now, in four groups)
var menu_page := ""
func _keys_page(s: Vector2, k: float) -> void:
	var r := Rect2(s.x * 0.5 - 620, s.y * 0.5 - 400, 1240, 800)
	UI.panel(c, r, 0.97 * k)
	_text(Ops.w("操作说明", "CONTROLS"), Vector2(r.position.x + 32, r.position.y + 46), 26, Pal.ink(0.95 * k), font_l, -1)
	_text(Ops.w("按键可以在 设置 → 按键 里改，这里跟着变。点任意处或按 Esc 返回。", "Keys are changed under Settings; this page follows. Click anywhere or press Esc to go back."), Vector2(r.position.x + 32, r.position.y + 76), 14, Pal.ink(0.6 * k), font, -1)
	for gi in OpCards.GROUPS.size():
		var gr: Array = OpCards.GROUPS[gi]
		var x := r.position.x + 32 + (gi % 2) * 600
		var y := r.position.y + 120 + (gi / 2) * 340
		_text(str(gr[0]) if Txt.zh else str(gr[1]), Vector2(x, y), 18, Color(UiSkin.ACCENT, k), font_b, -1)
		y += 14
		for a in gr[2]:
			var kt := OpCards.key_text(a)
			var kr := Rect2(x, y, maxf(44.0, 11.0 * kt.length() + 18.0), 26)
			c.draw_style_box(UiSkin.box("tag", k), kr)
			_text(kt, Vector2(kr.get_center().x, kr.position.y + 19), 13, Pal.ink(0.95 * k), font_b, 0)
			c.draw_multiline_string(font, Vector2(x + 84, y + 18), OpCards.line(a), HORIZONTAL_ALIGNMENT_LEFT, 500.0, 13, 2, Pal.ink(0.8 * k))
			y += 37


func _menu(s: Vector2) -> void:
	var k: float = clampf(menu_k.x, 0.0, 1.0)
	if menu_page == "keys":
		c.draw_rect(Rect2(Vector2.ZERO, s), Color(UiSkin.BG1.r, UiSkin.BG1.g, UiSkin.BG1.b, 0.92 * k))
		_keys_page(s, k)
		return
	# 51 号: the new look — the world dimmed under the ground's tint, glass keys, the accent on hover
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(UiSkin.BG1.r, UiSkin.BG1.g, UiSkin.BG1.b, 0.9 * k))
	var items := _menu_items()
	for i in items.size():
		var r := _menu_rect(i)
		var rk := Motion.stagger(menu_k.x * 0.6, i, 0.04, 0.2)
		r.position.y += (1.0 - rk) * 20.0
		var hov := i == menu_hover
		if hov:
			r.position.y -= 2.0
		c.draw_style_box(UiSkin.box("raised", k * rk, 1.0 if hov else 0.0), r.grow(-2.0))
		_text(items[i][1], Vector2(r.get_center().x, r.position.y + 32), 20, Pal.ink((0.95 if i == menu_hover else 0.6) * k * rk), font, 0)
	if menu_confirm == 1:
		_text(game.txt("end_warn"), Vector2(s.x * 0.5, _menu_rect(items.size()).position.y + 24), 14, Pal.heat(0.85 * k, 1.0), font, 0)


# ---------------------------------------------------------------- settlement

func _settlement(s: Vector2) -> void:
	var g = game
	var e := end_t - (0.2 if end_early else 1.6)
	if e < 0.0:
		return
	var a := clampf(e / 0.5, 0.0, 1.0)
	UI.sheet(c, s, a)
	var cx := s.x * 0.5
	var y := s.y * 0.5 - 300.0
	# the sheet the books are written on: it rises into place
	var pk := Pal.ease_out(clampf(e / 0.45, 0.0, 1.0))
	var crn := career_rows().size()
	var sheet := Rect2(cx - 330, y - 50 + (1.0 - pk) * 40.0, 660, (850.0 + maxf(0.0, crn - 6) * 30.0 if crn > 0 else 720.0))
	c.draw_rect(sheet, Color(0.022, 0.024, 0.029, 0.98 * pk))
	c.draw_rect(sheet, Pal.ink(0.1 * pk), false, 1.0)
	c.draw_rect(Rect2(sheet.position, Vector2(sheet.size.x * pk, 2)), Pal.heat(pk, 1.2))
	_text(g.txt("e_done") if not end_early else g.txt("e_early"), Vector2(cx, y), 20, Pal.ink(0.7 * a), font, 0)
	_text(g.txt("e_contract") + " " + g.ship.get("contract", "") + " · " + (g.txt("e_must_ok") if g.all_mandatory_ok() else g.txt("e_must_no")), Vector2(cx, y + 30), 14, Pal.ink(0.5 * a), font, 0)
	# the big number rolls up
	var rk := clampf((e - 0.3) / 1.1, 0.0, 1.0)
	var pct: float = g.recovery_rate() * 100.0 * Pal.ease_out(rk)
	var slam := Pal.back(clampf((e - 0.3) / 0.3, 0.0, 1.0), 2.6)
	_text("%.1f%%" % pct, Vector2(cx, y + 130), int(96 * slam) if slam > 0.05 else 1, Pal.ink(0.98 * a), font_l, 0)
	_text(g.txt("e_rate"), Vector2(cx, y + 166), 15, Pal.ink(0.5 * a), font, 0)
	var ry := y + 220.0
	for i in end_rows.size():
		var re := e - 1.5 - i * 0.32
		if re < 0.0:
			break
		var rs := Pal.back(clampf(re / 0.22, 0.0, 1.0), 2.2)
		var row: Array = end_rows[i]
		var v: float = row[1]
		var col := Pal.ink(0.9) if v >= 0 else Pal.heat(0.95, 1.1)
		var dy := (1.0 - rs) * -18.0
		_text(g.txt(row[0]), Vector2(cx - 260, ry + i * 34 + dy), 17, Pal.ink(0.55 * clampf(re / 0.15, 0.0, 1.0)), font)
		_text(("+" if v > 0.5 else "") + Pal.money(v), Vector2(cx + 260, ry + i * 34 + dy), int(20 * (0.7 + 0.3 * rs)), col, font_b, 1)
	var ne := e - 1.5 - end_rows.size() * 0.32 - 0.3
	if ne > 0.0:
		var ns := Pal.back(clampf(ne / 0.3, 0.0, 1.0), 2.4)
		var ny := ry + end_rows.size() * 34 + 30
		c.draw_line(Vector2(cx - 260, ny - 28), Vector2(cx + 260, ny - 28), Pal.ink(0.25), 1.0)
		_text(g.txt("e_net"), Vector2(cx - 260, ny + 10), 18, Pal.ink(0.7), font)
		_text(Pal.money((g.net() + g.bonus()) * Pal.ease_out(clampf(ne / 0.8, 0.0, 1.0))), Vector2(cx + 260, ny + 14), int(44 * ns) if ns > 0.05 else 1, Pal.ink(0.98), font_l, 1)
		var tl: String = g.txt("e_time") + "  " + _clock(g.playtime)
		if g.standard_time() > 0.0:
			tl += "  /  " + g.txt("e_standard") + "  " + _clock(g.standard_time())
		_text(tl, Vector2(cx - 260, ny + 46), 14, Pal.ink(0.5), font)
		# 61 号: the plans are out of sight (P does nothing), so the settlement doesn't say one was saved
		if g.plan != null and g.plan.result_key != "" and Game.G4_OPEN:
			c.draw_multiline_string(font,Vector2(cx - 260,ny + 66),g.plan.result_text(),HORIZONTAL_ALIGNMENT_LEFT,520,12,2,Pal.ink(0.75))
		var crows := career_rows()
		for i in crows.size():
			var ce := ne - 0.6 - i * 0.18
			if ce < 0.0:
				break
			var ca := clampf(ce / 0.2, 0.0, 1.0)
			var cy := ny + 92 + i * 30
			var row: Array = crows[i]
			_text(g.txt(row[0]), Vector2(cx - 260, cy), 15, Pal.ink(0.5 * ca), font)
			if row[2] == "text":
				_text(str(row[1]), Vector2(cx + 260, cy), 15, Pal.ink(0.85 * ca), font, 1)
				continue
			var v: float = row[1]
			var vt := Pal.money(v) if row[2] != "note" else "+" + Pal.money(v)
			var col := Pal.heat(0.9 * ca, 1.1) if (row[2] == "money" and v < -0.5) or row[2] == "note" else Pal.ink(0.85 * ca)
			_text(vt, Vector2(cx + 260, cy), 17, col, font_b, 1)
	if e > 1.6:
		_review(Vector2(cx - 330 - 30 - 430, ry - 10), e - 1.6)
	var te := e - 1.8
	var traps: Array = g.job.get("traps", [])
	if te > 0.0 and not traps.is_empty():
		_trap_rows(traps, Vector2(cx + 380, ry + 10), te)
	var ge := ne - 0.9
	if ge > 0.0:
		_stamp(Vector2(cx + 330, y + 100), ge)
		var pulse := 0.5 + 0.4 * sin(t * 3.0)
		var go: String = g.txt("st_go_on") if g.story != null and g.story.wants_epilogue() else g.txt("e_to_terminal" if g.career() else ("e_again_dev" if g.dev_job() else "e_again"))
		# 119 号: the haul's own page comes next while anything is left to sort
		if g.career() and (g.story == null or not g.story.wants_epilogue()) and not Disposal.pending().is_empty():
			go = g.txt("e_to_goods")
		_text(go, Vector2(cx, s.y - 80), 16, Pal.ink(pulse), font_b, 0)
	# 93 号: the core asset's review, over the sheet, at its right (where the trap rows would be:
	# a sample ship has none)
	if traps.is_empty():
		_asset_review(s, e)


# where the money went: value knocked off by reason, money lost by cause, named pieces lost
func _review(at: Vector2, e: float) -> void:
	var g = game
	var groups := {}
	for d in g.devalued:
		if not groups.has(d[0]):
			groups[d[0]] = [0.0, []]
		groups[d[0]][0] += float(d[2])
		if d[1] != "" and not d[1] in groups[d[0]][1]:
			groups[d[0]][1].append(d[1])
	for l in g.loss_lines:
		var k: String = l[0]
		if not groups.has(k):
			groups[k] = [0.0, []]
		groups[k][0] += float(l[1])
	var rows: Array = []
	for k in groups:
		rows.append([k, groups[k][0], groups[k][1]])
	rows.sort_custom(func(a, b): return a[1] > b[1])
	var h: float = 84.0 + maxf(1, rows.size()) * 44.0 + g.mandatory_lost.size() * 30.0 + (40.0 if not rows.is_empty() else 0.0)
	var a := clampf(e / 0.4, 0.0, 1.0)
	var r := Rect2(at, Vector2(430, h))
	UI.panel(c, r, a, 1.0, Pal.HEAT if not rows.is_empty() or not g.mandatory_lost.is_empty() else Pal.FLUID)
	_text(g.txt("rv_title"), r.position + Vector2(24, 36), 18, Pal.ink(0.95 * a), font_b)
	var y := r.position.y + 66.0
	for tg in g.mandatory_lost:
		_text(g.txt("rv_mandatory") % [tg, g.txt(g.mandatory_lost[tg])], Vector2(r.position.x + 24, y + 6), 15, Pal.heat(0.95 * a, 1.2), font_b)
		y += 30.0
	if rows.is_empty():
		_text(g.txt("rv_none"), Vector2(r.position.x + 24, y + 14), 15, Pal.tint(Pal.FLUID, 0.9 * a, 1.1), font)
		return
	var total := 0.0
	for i in rows.size():
		var ra := clampf((e - 0.15 * i) / 0.3, 0.0, 1.0) * a
		var row: Array = rows[i]
		total += row[1]
		_text(g.txt(row[0]), Vector2(r.position.x + 24, y + 14), 15, Pal.ink(0.85 * ra), font)
		_text("−" + Pal.money(row[1]), Vector2(r.end.x - 24, y + 14), 16, Pal.heat(0.9 * ra, 1.1), font_b, 1)
		var tags: Array = row[2]
		if not tags.is_empty():
			_text(" · ".join(tags.slice(0, 5)), Vector2(r.position.x + 24, y + 34), 13, Pal.ink(0.5 * ra), font)
		y += 44.0
	c.draw_line(Vector2(r.position.x + 24, y), Vector2(r.end.x - 24, y), Pal.ink(0.2 * a), 1.0)
	_text(g.txt("rv_total"), Vector2(r.position.x + 24, y + 28), 15, Pal.ink(0.7 * a), font)
	_text("−" + Pal.money(total), Vector2(r.end.x - 24, y + 28), 18, Pal.heat(0.95 * a, 1.2), font_b, 1)


# a required piece just became impossible: across the top, in heat, for a few seconds
func _alert(s: Vector2) -> void:
	var a := clampf(alert_t / 0.2, 0.0, 1.0) * clampf((7.0 - alert_t) / 0.6, 0.0, 1.0)
	var w := _tw(alert_text, 18, font_b) + 60.0
	var r := Rect2(s.x * 0.5 - w * 0.5, 120.0 - (1.0 - Pal.ease_out(a)) * 20.0, w, 50)
	c.draw_rect(r, Color(0.12, 0.03, 0.02, 0.92 * a))
	c.draw_rect(r, Pal.heat((0.6 + 0.4 * sin(t * 8.0)) * a, 1.4), false, 2.0)
	_text(alert_text, Vector2(s.x * 0.5, r.position.y + 32), 18, Pal.ink(0.98 * a), font_b, 0)


# pulling on something held only by locks and lines: how close it is to tearing
func _tearing() -> void:
	var tl = game.tools
	if tl.held_piece == null or tl.held_body != null or tl.strain < 0.04:
		return
	var p := to_screen(tl.grab_point())
	var k: float = clampf(tl.strain, 0.0, 1.0)
	FastDraw.arc(c, p, 30.0, -PI / 2, -PI / 2 + TAU * k, 40, Pal.heat(0.95, 1.4), 3.0, true)
	FastDraw.arc(c, p, 30.0, 0.0, TAU, 40, Pal.ink(0.15), 1.0, true)
	_text(game.txt("tearing"), p + Vector2(40, 6), 15, Pal.heat(0.95, 1.3), font_b)


# the last few pieces: a small mark on each, so nobody hunts for them
func _left_markers(s: Vector2) -> void:
	if game.training or game.exam != null:
		return
	# 60 FPS (2026-10-27): the cached count first; the list itself only when there are few
	# (walking all of ARK-01's pieces for it took 1.3 ms a frame)
	var n: int = game.left_count()
	if n == 0 or n > 8:
		return
	var left: Array = game.pieces_left()
	var inner := Rect2(Vector2(40, 40), s - Vector2(80, 80))
	for p in left:
		var sp := to_screen(game.world.frame(p) * Geom.centroid(p.poly))
		if inner.has_point(sp):
			var k := 7.0 + 2.0 * sin(t * 5.0)
			FastDraw.polyline(c, PackedVector2Array([sp + Vector2(0, -k - 10), sp + Vector2(k, -10), sp + Vector2(0, k - 10), sp + Vector2(-k, -10), sp + Vector2(0, -k - 10)]), Pal.heat(0.9, 1.3), 1.6, true)
		else:
			var cpos := s * 0.5
			var dir := (sp - cpos).normalized()
			var tt := INF
			if absf(dir.x) > 0.001:
				tt = minf(tt, ((inner.end.x if dir.x > 0.0 else inner.position.x) - cpos.x) / dir.x)
			if absf(dir.y) > 0.001:
				tt = minf(tt, ((inner.end.y if dir.y > 0.0 else inner.position.y) - cpos.y) / dir.y)
			var at := cpos + dir * tt
			FastDraw.circle(c, at, 5.0, Pal.heat(0.8, 1.3))


# the radio log (L): what Liang and the terminal said, newest at the bottom
func _radio_log(s: Vector2) -> void:
	var hist: Array = game.radio.history
	var n := mini(hist.size(), 10)
	var r := Rect2(s.x - 40 - 560, 130, 560, 64 + n * 30)
	UI.panel(c, r, 1.0, 1.0, Pal.AIR)
	_text(game.txt("radio_log"), r.position + Vector2(20, 30), 14, Pal.ink(0.6), font)
	for i in n:
		var h: Array = hist[hist.size() - n + i]
		var who: String = game.txt("tut_term") if h[1] == "term" else game.txt("tut_liang")
		_text(who, r.position + Vector2(20, 64 + i * 30), 13, Pal.tint(Pal.AIR, 0.7, 1.0) if h[1] == "term" else Pal.heat(0.8, 1.1), font)
		c.draw_string(font, r.position + Vector2(110, 64 + i * 30), h[0], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 130, 14, Pal.ink(0.9))


# the contract's signature traps: avoided or not, and the review note where one bit
func _trap_rows(traps: Array, at: Vector2, e: float) -> void:
	var a := clampf(e / 0.3, 0.0, 1.0)
	var card := Rect2(at + Vector2(-24, -36 + (1.0 - Pal.ease_out(a)) * 20.0), Vector2(528, 60 + traps.size() * 78))
	c.draw_style_box(UiSkin.box("panel", a), card)
	c.draw_rect(Rect2(card.position + Vector2(8, 12), Vector2(3, (card.size.y - 24) * a)), Color(UiSkin.ACCENT, a))
	_text(game.txt("e_traps"), at, 15, Pal.ink(0.5 * a), font)
	var yy := at.y + 34.0
	for i in traps.size():
		var ra := clampf((e - 0.2 - i * 0.2) / 0.2, 0.0, 1.0)
		var t: String = traps[i]
		var hit := Traps.bit(t, game.incidents)
		_text(Copy.slot("N_" + t), Vector2(at.x, yy), 17, Pal.ink(0.9 * ra), font_b)
		_text(game.txt("e_trap_hit" if hit else "e_trap_ok"), Vector2(at.x + 480, yy), 15, Pal.heat(0.9 * ra, 1.1) if hit else Pal.ink(0.6 * ra), font, 1)
		yy += 26.0
		if hit:
			c.draw_multiline_string(font, Vector2(at.x, yy), Copy.slot("V_" + t), HORIZONTAL_ALIGNMENT_LEFT, 480, 13, 2, Pal.ink(0.6 * ra))
			yy += 40.0
		yy += 8.0


func grade() -> int:
	var g = game
	var r: float = g.recovery_rate()
	if not g.all_mandatory_ok() or r < 0.7:
		return 0
	if r >= 0.92:
		return 3
	if r >= 0.8:
		return 2
	return 1


func _stamp(p: Vector2, e: float) -> void:
	var gr := grade()
	var k := Pal.back(clampf(e / 0.25, 0.0, 1.0), 3.0)
	var sc := lerpf(2.2, 1.0, clampf(e / 0.2, 0.0, 1.0))
	var a := clampf(e / 0.12, 0.0, 1.0)
	var col := Pal.heat(a, 1.2) if gr == 0 else Pal.ink(a)
	var r := 74.0 * sc
	_xform(p, -0.18, Vector2.ONE)
	FastDraw.arc(c, Vector2.ZERO, r, 0.0, TAU, 48, col, 3.0, true)
	FastDraw.arc(c, Vector2.ZERO, r - 8, 0.0, TAU, 48, Color(col.r, col.g, col.b, col.a * 0.5), 1.0, true)
	var txt := game.txt("grade_%d" % gr)
	var w := _tw(txt, int(28 * sc), font_b)
	c.draw_string(font_b, Vector2(-w * 0.5, 10 * sc), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(28 * sc), col)
	_xform(Vector2.ZERO, 0.0, Vector2.ONE)
	if e < 0.3 and k > 0.0:
		game.shake(0.02)


func _draw_add() -> void:
	if game == null:
		return
	var tex: Texture2D = game.fx.glow_tex
	for f in flyers:
		for j in 5:
			var k: float = maxf(0.0, f[2] / 0.6 - j * 0.035)
			var e := Pal.ease_in(k)
			var p: Vector2 = (f[0] as Vector2).lerp(f[1], e) + Vector2(0, -sin(k * PI) * 80.0)
			var r := (10.0 + 6.0 * (1.0 - k)) * (1.0 - j * 0.17)
			fadd.draw_texture_rect(tex, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Pal.ink(0.9 * (1.0 - j * 0.2), 1.6))
	for b in bursts:
		var e := Pal.ease_out(b[1] / 0.45)
		FastDraw.arc(fadd, b[0], 6.0 + 30.0 * e, 0.0, TAU, 32, Pal.ink(0.6 * (1.0 - e), 1.5), 2.0, true)
	if credit_pop > 0.0:
		var s := size()
		fadd.draw_texture_rect(tex, Rect2(Vector2(s.x - 260, 40), Vector2(240, 70)), false, Pal.ink(0.12 * credit_pop, 1.4))


# ---------------------------------------------------------------- 93 号: the core asset, read three times

func _money_range(lo: float, hi: float) -> String:
	if absf(hi - lo) < 1.0:
		return "≈" + Pal.money(lo)
	return Pal.money(lo) + "–" + Pal.money(hi)


# on the contract card: what is worth most aboard, and what each way of taking it fetches
func _asset_card(ca: Dictionary, x: float, y: float, w: float, a: float) -> float:
	var head := Ops.w("核心资产 · %s（%s）· 满价 %s", "CORE ASSET · %s (%s) · WHOLE %s") % [ca.name, ca.units, Pal.money(ca.full)]
	# (a long name wraps inside the column, not over the numbers beside it)
	var hl := clampi(ceili(_tw(head, 13) / maxf(w, 1.0)), 1, 2)
	c.draw_multiline_string(font, Vector2(x, y), head, HORIZONTAL_ALIGNMENT_LEFT, w, 13, 2, Color(UiSkin.ACCENT, 0.9 * a))
	y += 26.0 + (hl - 1) * 17.0
	for m in ca.methods:
		var mins: Array = m.minutes
		var line := Ops.w("%s　%s %s · 约 %d–%d 分钟", "%s　%s %s · ABOUT %d–%d MIN") % [m.name, ca.name, _money_range(m.lo, m.hi), mins[0], mins[1]]
		# 113 号: a way the bot couldn't run has no measured time
		if int(mins[1]) <= 0:
			line = Ops.w("%s　%s %s · 用时待实测", "%s　%s %s · TIME NOT MEASURED") % [m.name, ca.name, _money_range(m.lo, m.hi)]
		_text(line, Vector2(x, y), 16, Pal.ink(0.94 * a), font_b)
		y += 22.0
		if str(m.get("need", "")) != "":
			_text(str(m.need), Vector2(x + 14.0, y), 13, Pal.heat(0.85 * a, 1.1) if not str(m.need).begins_with(Ops.w("船坞已有", "THE BERTH HAS")) else Pal.ink(0.6 * a), font)
			y += 20.0
		# (up to four lines: the measured numbers ride at the end of the risks)
		var risk: String = Ops.w("风险：", "RISK: ") + str(m.risks)
		var rl := clampi(ceili(_tw(risk, 13) * 1.15 / maxf(w - 14.0, 1.0)), 1, 4)
		c.draw_multiline_string(font, Vector2(x + 14.0, y), risk, HORIZONTAL_ALIGNMENT_LEFT, w - 14.0, 13, 4, Pal.ink(0.58 * a))
		y += 24.0 + (rl - 1) * 18.0
	return y


func _grade_col(g: float, a: float) -> Color:
	if g >= 0.9:
		return Pal.ink(0.95 * a)
	if g >= 0.7:
		return Pal.ink(0.78 * a)
	if g >= 0.45:
		return Pal.heat(0.75 * a, 1.0)
	return Pal.heat(0.95 * a, 1.3)


# 117 号 (Q7): the required pieces still named under the contract's title — those the asset board
# doesn't list (it marks its own with the same diamond)
var _board_names := {}
var _board_frame := -1
func _title_items() -> Array:
	var f := Engine.get_process_frames()
	if f != _board_frame:
		_board_frame = f
		_board_names.clear()
		if not game.training and game.exam == null and not game.in_berth():
			for row in CoreAsset.board(game).get("rows", []):
				_board_names[str(row.name)] = true
	var out: Array = []
	for it in game.mandatory_items():
		if not _board_names.has(str(it[0])):
			out.append(it)
	return out


# a required piece's diamond on the asset board: filled once it is safe, crossed in heat if lost
func _must_dia(dc: Vector2, i: int, r: float) -> void:
	var k: float = must_k[i] if i < must_k.size() and must_k[i] != null else 0.0
	var dia := PackedVector2Array([dc + Vector2(0, -r), dc + Vector2(r, 0), dc + Vector2(0, r), dc + Vector2(-r, 0)])
	if k > 0.02:
		FastDraw.poly(c, dia, Pal.ink(0.95 * k))
	var cl := dia.duplicate()
	cl.append(dia[0])
	var lost: bool = game.mandatory_lost.has(game.mandatory_items()[i][0])
	FastDraw.polyline(c, cl, Pal.heat(0.95, 1.3) if lost else Pal.ink(0.7), 1.2, true)
	if lost:
		c.draw_line(dc + Vector2(-r, -r), dc + Vector2(r, r), Pal.heat(1.0, 1.4), 2.0)
		c.draw_line(dc + Vector2(r, -r), dc + Vector2(-r, r), Pal.heat(1.0, 1.4), 2.0)


# on the job, under the contract panel: each corner's pull, progress and grade, and the last losses
func _asset_board(cr: Rect2) -> void:
	var b: Dictionary = CoreAsset.board(game)
	asset_rect = Rect2()
	if b.is_empty():
		return
	var rows: Array = b.rows
	var recent: Array = b.recent
	var warn: Array = b.get("warn", [])
	var head: String = Ops.w("核心资产 · %s", "CORE ASSET · %s") % b.name
	var now: String = Ops.w("预估 %s / %s", "NOW %s / %s") % [Pal.money(b.worth), Pal.money(b.full)]
	# a long name: the worth on a line of its own
	var two := font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + font_b.get_string_size(now, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 24.0 > cr.size.x - 34.0
	# 110 号 (Q2 C / Q3 A): the one thing to do next, at the top; under a row that isn't safe, how
	var nx: Dictionary = NextStep.of(game)
	var nx_how := 0
	if not nx.is_empty() and str(nx.how) != "":
		nx_how = clampi(ceili(_tw(str(nx.how), 12) / maxf(cr.size.x - 40.0, 1.0)), 1, 3)
	var fixes := 0
	if NextStep.on(game):
		for row in rows:
			if row.get("alert", false) and str(row.get("fix", "")) != "":
				fixes += 1
	var nx_h := (42.0 + nx_how * 17.0) if not nx.is_empty() else 0.0
	# 112 号: a long warning wraps inside the board instead of running past its edge
	var warn_w := cr.size.x - 34.0
	var warn_n := 0
	for wl in warn:
		warn_n += clampi(ceili(_tw(str(wl), 12) / maxf(warn_w, 1.0)), 1, 3)
	var h := 64.0 + (18.0 if two else 0.0) + nx_h + rows.size() * 24.0 + fixes * 17.0 + warn_n * 17.0 + (10.0 + recent.size() * 20.0 if not recent.is_empty() else 0.0)
	var r := Rect2(cr.position.x, cr.end.y + 12.0, cr.size.x, h)
	asset_rect = r
	UI.panel(c, r, 0.82, 0.0, UiSkin.ACCENT, 1.0)
	var x := r.position.x + 18.0
	var y := r.position.y + 24.0
	_text(head, Vector2(x, y), 13, Pal.ink(0.55), font)
	if two:
		y += 18.0
	_text(now, Vector2(r.end.x - 16.0, y), 13, Pal.ink(0.9), font_b, 1)
	y += 10.0
	var bar := Rect2(x, y, r.size.x - 34.0, 3.0)
	c.draw_rect(bar, Pal.ink(0.12))
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(b.worth) / maxf(float(b.full), 1.0), 0.0, 1.0), 3.0)), UiSkin.ACCENT)
	y += 24.0
	if not nx.is_empty():
		var wait: bool = nx.get("wait", false)
		var pulse := 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.004)) if not wait else 0.8
		c.draw_rect(Rect2(x - 10.0, y - 14.0, 3.0, 20.0 + nx_how * 17.0 + 8.0), Color(UiSkin.ACCENT, pulse))
		_text(Ops.w("进行中", "UNDER WAY") if wait else Ops.w("下一步", "NEXT"), Vector2(x, y - 2.0), 11, Color(UiSkin.ACCENT, 0.95), font)
		y += 17.0
		_text(str(nx.t), Vector2(x, y), 15, Pal.ink(0.97), font_b)
		y += 6.0
		if nx_how > 0:
			_mtext(str(nx.how), Vector2(x, y + 12.0), r.size.x - 40.0, 12, nx_how, Pal.ink(0.62))
			y += nx_how * 17.0
		y += 22.0
	for wl in warn:
		var wn := clampi(ceili(_tw(str(wl), 12) / maxf(warn_w, 1.0)), 1, 3)
		_mtext(str(wl), Vector2(x, y - 6.0), warn_w, 12, wn, Pal.heat(0.9, 1.2))
		y += 17.0 * wn
	var must: Array = game.mandatory_items()
	for row in rows:
		_text(str(row.name), Vector2(x, y), 14, Pal.ink(0.85), font_b)
		var nw := font_b.get_string_size(str(row.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		for i in must.size():
			if str(must[i][0]) == str(row.name):
				_must_dia(Vector2(x + nw + 10.0, y - 5.0), i, 4.5)
				nw += 16.0
		_text(str(row.text), Vector2(x + maxf(44.0, nw + 8.0), y), 12, Pal.heat(0.8, 1.1) if row.get("alert", false) else Pal.ink(0.6), font)
		_text(str(row.right), Vector2(r.end.x - 16.0, y), 14, _grade_col(float(row.grade), 1.0), font_b, 1)
		y += 24.0
		if NextStep.on(game) and row.get("alert", false) and str(row.get("fix", "")) != "":
			_text("→ " + str(row.fix), Vector2(x + 14.0, y - 7.0), 12, Pal.ink(0.6), font)
			y += 17.0
	if not recent.is_empty():
		y += 4.0
		for ev in recent:
			_text("−%s  %s" % [Pal.money(ev.money).trim_prefix("$"), ev.text], Vector2(x, y), 12, Pal.heat(0.9, 1.25), font)
			y += 20.0


# 117 号 (Q1 A): on site the mark carries only the short name (what comes after the colon, or the
# control's code); the whole sentence is the asset board's
static var _code_rx: RegEx
static func short_step(s: String) -> String:
	for sep in ["：", ": "]:
		var i := s.rfind(sep)
		if i >= 0:
			return s.substr(i + sep.length()).strip_edges()
	if s.length() <= 12:
		return s
	if _code_rx == null:
		_code_rx = RegEx.create_from_string("[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+")
	var all := _code_rx.search_all(s)
	return all[all.size() - 1].get_string() if not all.is_empty() else s


# 110 号 (Q2 C): the next step on site — a ring on the control or piece it means, a leader and the
# same words; out of view, an arrow at the screen's edge pointing to it. A fixed size on the screen.
func _next_mark(s: Vector2) -> void:
	var nx: Dictionary = NextStep.of(game)
	if nx.is_empty():
		return
	var at: Vector2 = nx.at
	if not at.is_finite():
		return
	var p := to_screen(at)
	var acc: Color = UiSkin.ACCENT
	var wait: bool = nx.get("wait", false)
	var ph := Time.get_ticks_msec() / 1000.0
	var label: String = (Ops.w("进行中 · ", "UNDER WAY · ") if wait else Ops.w("下一步 · ", "NEXT · ")) + short_step(str(nx.t))
	# clear of the contract column on the left, the toolbar and the map along the bottom
	var inset := Rect2(Vector2(380.0, 110.0), s - Vector2(380.0 + 90.0, 110.0 + 230.0))
	if inset.has_point(p):
		var rr := 16.0 + (0.0 if wait else 4.0 * absf(sin(ph * 3.0)))
		c.draw_arc(p, rr, 0.0, TAU, 40, Color(acc, 0.9), 2.0, true)
		c.draw_arc(p, rr + 7.0, ph * 1.6, ph * 1.6 + 1.2, 12, Color(acc, 0.55), 1.5, true)
		c.draw_arc(p, rr + 7.0, ph * 1.6 + PI, ph * 1.6 + PI + 1.2, 12, Color(acc, 0.55), 1.5, true)
		var tw := font_b.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var left := p.x + 40.0 + tw + 24.0 > s.x - 40.0
		var knee := p + Vector2(-34.0 if left else 34.0, -34.0)
		var end := knee + Vector2(-(tw + 20.0) if left else tw + 20.0, 0.0)
		c.draw_line(p + (knee - p).normalized() * (rr + 2.0), knee, Color(acc, 0.8), 1.5, true)
		c.draw_line(knee, end, Color(acc, 0.8), 1.5, true)
		var tx := minf(knee.x, end.x) + 10.0
		c.draw_rect(Rect2(tx - 6.0, knee.y - 24.0, tw + 12.0, 22.0), Color(0.02, 0.022, 0.026, 0.85))
		_text(label, Vector2(tx, knee.y - 8.0), 14, Pal.ink(0.97), font_b)
		return
	# out of view: an arrow on the edge, pointing at it
	var cen := s * 0.5
	var d := (p - cen).normalized()
	var e := p
	e.x = clampf(e.x, inset.position.x, inset.end.x)
	e.y = clampf(e.y, inset.position.y, inset.end.y)
	var side := d.orthogonal()
	var tip := e + d * 10.0
	c.draw_colored_polygon(PackedVector2Array([tip, e - d * 8.0 + side * 9.0, e - d * 8.0 - side * 9.0]), Color(acc, 0.9))
	var tw2 := font_b.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var lp := e - d * 26.0
	lp.x = clampf(lp.x - (tw2 if d.x > 0.3 else (0.0 if d.x < -0.3 else tw2 * 0.5)), 20.0, s.x - tw2 - 20.0)
	c.draw_rect(Rect2(lp.x - 6.0, lp.y - 15.0, tw2 + 12.0, 21.0), Color(0.02, 0.022, 0.026, 0.85))
	_text(label, Vector2(lp.x, lp.y), 13, Pal.ink(0.92), font_b)


# at the settlement, right of the sheet: what came of the asset, what it lost and why, one thing to do
func _asset_review(s: Vector2, e: float) -> void:
	var rv: Dictionary = CoreAsset.review(game)
	if rv.is_empty():
		return
	var a := clampf((e - 1.2) / 0.6, 0.0, 1.0)
	if a <= 0.0:
		return
	var w := 400.0
	var x := s.x * 0.5 + 330.0 + 100.0
	var y := s.y * 0.5 - 300.0
	var lines: int = 6 + (rv.units as Array).size() + (rv.lost as Array).size() + (rv.reasons as Array).size() * 2
	var r := Rect2(x, y, w, 120.0 + lines * 22.0)
	c.draw_rect(r, Color(0.022, 0.024, 0.029, 0.97 * a))
	c.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(UiSkin.ACCENT, a))
	var px := x + 22.0
	var py := y + 34.0
	_text(Ops.w("%s复盘", "%s · REVIEW") % rv.name, Vector2(px, py), 16, Pal.ink(0.7 * a), font)
	py += 34.0
	_text((Ops.w("收成 %s", "ROLLED %s") if CoreAsset.ship_key(game) == "sa200" else Ops.w("保住 %s", "KEPT %s")) % Pal.money(rv.rolled), Vector2(px, py), 26, Pal.ink(0.98 * a), font_l)
	_text(Ops.w("满价 %s", "WHOLE %s") % Pal.money(rv.full), Vector2(r.end.x - 22.0, py), 13, Pal.ink(0.5 * a), font, 1)
	py += 24.0
	if float(rv.got) + 1.0 < float(rv.rolled):
		_text(Ops.w("已送走 %s", "SENT %s") % Pal.money(rv.got), Vector2(px, py), 13, Pal.heat(0.85 * a, 1.1), font)
		py += 20.0
	py += 6.0
	for u in rv.units:
		_text("%s  %s" % [u.text, Pal.money(u.value)], Vector2(px, py), 14, Pal.ink(0.88 * a), font_b)
		py += 18.0
		_text(str(u.sub), Vector2(px + 14.0, py), 12, Pal.ink(0.5 * a), font)
		py += 22.0
	if not rv.lost.is_empty():
		py += 4.0
		_text(Ops.w("拆坏的", "LOST"), Vector2(px, py), 13, Pal.ink(0.5 * a), font)
		py += 22.0
		for ls in rv.lost:
			var lt := "−%s  %s（%d 次）" % [Pal.money(ls.money).trim_prefix("$"), ls.text, ls.n] if Txt.zh else "−%s  %s (%d)" % [Pal.money(ls.money).trim_prefix("$"), ls.text, ls.n]
			c.draw_multiline_string(font, Vector2(px, py), lt, HORIZONTAL_ALIGNMENT_LEFT, w - 44.0, 13, 2, Pal.heat(0.9 * a, 1.2))
			py += 22.0 + (18.0 if _tw(lt, 13) > w - 44.0 else 0.0)
	py += 6.0
	_text(Ops.w("为什么", "WHY"), Vector2(px, py), 13, Pal.ink(0.5 * a), font)
	py += 22.0
	for reason in rv.reasons:
		c.draw_multiline_string(font, Vector2(px, py), "· " + str(reason), HORIZONTAL_ALIGNMENT_LEFT, w - 44.0, 13, 2, Pal.ink(0.82 * a))
		py += 22.0 + (18.0 if _tw("· " + str(reason), 13) > w - 44.0 else 0.0)
	py += 8.0
	_text(Ops.w("下次", "NEXT TIME"), Vector2(px, py), 13, Color(UiSkin.ACCENT, 0.8 * a), font)
	py += 22.0
	c.draw_multiline_string(font_b, Vector2(px, py), str(rv.advice), HORIZONTAL_ALIGNMENT_LEFT, w - 44.0, 14, 3, Pal.ink(0.95 * a))
