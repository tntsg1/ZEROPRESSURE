extends CanvasLayer
# 2026-11-12 HUD 重设计 · 中央交互 (the owner's 《hud设计》, design/TODO.md "2026-11-12 HUD 重设计"):
#   悬停 — a thin orange line round the part's real outline, and a small tag by the pointer: its name
#          and its state now (fixed by how many fixings / free / too heavy / out of reach; a danger
#          kind with an icon and its reading).
#   选中 — the middle button on a part, with any tool (user 2026-11-12: middle only; the left button
#          stays the tools' own) opens a card beside it with what the game holds about it right now. Only a part
#          that carries a danger (pressure, liquid, power, heat, radiation, antimatter, explosive,
#          bio, chemical) gets the card; plate, scrap and fixings keep the tag only.
#          The card stands to one side of the part and goes to the other side (then above, below,
#          then the screen's edge) when it would cover the pointer, the beam or the drone; the
#          middle button on blank space or on the same part, Esc
#          (scripts/ui_back.gd site_back) or another part closes or moves it.
#   数值 — readings are the instruments' (sys.readings): a value is shown only once measured,
#          marked out of date when the instrument says so; never measured: "未测 · 按 1 测量"
#          (Jev 2026-11-12: so the card never stands in for measuring). What the eye sees (the
#          fixings, the cables and pipes, the antimatter trap's own readout) is live.
#   OSD — scripts/look.gd keeps the line of sight and the drone's own "RNG · MASS" under the tag
#          (tag_rect); the part's name is only in the tag (it used to be on the target box too).
# Nothing here is saved. HudCenter.on = false gives the old picture back (tests, comparison).

const Back := preload("res://scripts/ui_back.gd")
const FastDraw = preload("res://scripts/fast_draw.gd")

static var on := true
static var tag_rect := Rect2()          # where the hover tag stands this frame (look.gd puts its RNG/MASS line under it)

const CARD_W := 360.0
const GAP := 18.0
const HEAT := Color(1.0, 0.42, 0.3)

var game
var c: Control
var sel = null                # the piece the card is about
var card_rect := Rect2()      # on screen, this frame (tests)
var card_side := ""           # "right" "left" "above" "below" "edge"
var card_k := 0.0
var _mmb_was := false
var _site_cb: Callable


func _ready() -> void:
	layer = 22   # over the feed's OSD (look.gd, 21)
	name = "HudCenter"
	c = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_draw_center)
	add_child(c)
	_site_cb = close
	Back.site_add(_site_cb)


func _exit_tree() -> void:
	Back.site_remove(_site_cb)


# Esc / anything that ends the selection: true when there was a card to close
func close() -> bool:
	if sel == null:
		return false
	sel = null
	card_k = 0.0
	return true


func select(p) -> void:
	if p == null or p.gone or not danger(p):
		sel = null
		return
	if p != sel:
		card_k = 0.0
		card_side = ""
	sel = p


func _active() -> bool:
	return on and game != null and game.state == "play" and not game.menu_open and not game.contract_open and game.tools != null and game.world != null and game.drone != null and game.drone.alive


func _process(dt: float) -> void:
	tag_rect = Rect2()
	if not _active():
		if sel != null and (game == null or game.state != "play"):
			sel = null
		_mmb_was = false
		c.queue_redraw()
		return
	var tl = game.tools
	var w = game.world
	var b: Dictionary = game.bot if game.bot != null else {}
	var mmb: bool = bool(b.get("mmb", Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) if game.bot == null else false))
	var over_ui: bool = game.bot == null and game.hud != null and game.hud.pointer_over_ui()
	if mmb and not _mmb_was and not over_ui:
		var list: Array = w.pieces_at(tl.aim)
		var p = list[0] if not list.is_empty() and not w.hidden(tl.aim) else null
		if p == null or p == sel:
			close()
		else:
			select(p)
	_mmb_was = mmb
	if sel != null and sel.gone:
		close()
	if sel != null:
		card_k = minf(1.0, card_k + dt / 0.14) if Txt.anim_level() > 0 else 1.0
	# the tag's place, ahead of any drawing this frame (look.gd's OSD puts its line under it)
	var hp = _hover_piece()
	if hp != null and hp != sel and str(tl.hover.kind) in ["piece", "inspect"]:
		tag_rect = _tag_layout(hp, tl.hover)
	c.queue_redraw()


func _hover_piece():
	var tl = game.tools
	var h: Dictionary = tl.hover
	if tl.tool == 2 or not str(h.get("kind", "")) in ["piece", "inspect", "lid", "batt"]:
		return null
	var hp = h.get("piece")
	return null if hp == null or hp.gone else hp


# ---------------------------------------------------------------- what a part is

# the dangers a part carries: [[kind, …]] in the order the card lists them
func dangers(p) -> Array:
	var out: Array = []
	if p == null or p.cls != "equip":
		return out
	var s = game.sys
	var hz: String = str(p.hazard)
	if game.get("anti") != null and game.anti.active() and (game.anti.is_trap(p) or _anti_chain(p)) or hz == "antimatter":
		out.append("anti")
	if game.get("reactor") != null and game.reactor.active() and game.reactor._core() == p or hz == "rad":
		out.append("rad")
	if s != null and (s.tank_vol(p) != "" or hz == "gas_tank"):
		out.append("pressure")
	if s != null and (s.fluid_in_piece(p) != "" or hz == "fuel_tank"):
		out.append("fluid")
	if hz in ["battery", "cap", "gen"] or (s != null and s.electric_piece(p)):
		out.append("power")
	if hz in ["explosive", "bio", "chem"]:
		out.append(hz)
	if Mat.temp(p) > 80.0 and not "heat" in out:
		out.append("heat")
	return out


func danger(p) -> bool:
	return not dangers(p).is_empty()


func _anti_chain(p) -> bool:
	if p.tag == "":
		return false
	var cf: Dictionary = game.anti.cfg
	for k in ["switch", "supply", "bus", "source"]:
		if str(cf.get(k, "")) == p.tag:
			return true
	return false


# the instruments' readings that are about this part
func readings_of(p) -> Array:
	var out: Array = []
	var s = game.sys
	if s == null:
		return out
	var vols := [s.tank_vol(p), s.fluid_in_piece(p)]
	for k in s.readings:
		var r: Dictionary = s.readings[k]
		var mine := false
		if r.get("piece") == p:
			mine = true
		elif r.get("ctrl") != null and int(r.ctrl.piece) == p.id:
			mine = true
		elif str(r.get("vol", "")) != "" and str(r.get("vol", "")) in vols:
			mine = true
		if mine:
			out.append(r)
	return out


static func _row_of(r: Dictionary) -> String:
	match str(r.kind):
		"pressure": return "pressure"
		"volts": return "volts"
		"temp": return "temp"
		"fluid": return "fluid"
		"sample": return "sample"
	var u := str(r.get("unit", ""))
	if u.begins_with("mSv") or u.begins_with("µSv") or u.begins_with("Sv"):
		return "dose"
	return "read"


# a reading that says it is not safe yet (its text says so too: the colour only repeats it)
func _hot(r: Dictionary) -> bool:
	var v := float(r.get("val", 0.0))
	match str(r.kind):
		"pressure": return v > Systems.SAFE_KPA
		"volts": return v > 50.0
	return false


# the card's rows: [icon, label, value, hot]
func rows(p) -> Array:
	var out: Array = []
	var ds := dangers(p)
	var rs := readings_of(p)
	var have := {}
	for r in rs:
		var row := _row_of(r)
		have[row] = true
		var st: bool = game.sys.stale(r) and not r.get("live", false)
		var v: String = str(r.text) + ("  ·  " + Txt.t("as_hc_stale") if st else "")
		out.append([row, Txt.t("as_hc_r_" + row), v, _hot(r) and not st])
	# what the instruments could tell and have not yet
	var want := {"pressure": "pressure", "fluid": "fluid", "power": "volts", "rad": "dose"}
	for d in ds:
		if want.has(d) and not have.has(want[d]):
			out.append([want[d], Txt.t("as_hc_r_" + want[d]), Txt.t("as_hc_unmeasured"), false])
	if "anti" in ds:
		if game.anti.is_trap(p):
			var ar: Array = game.anti.reading()
			out.push_front(["anti", Txt.t("as_hc_r_anti"), str(ar[1]), float(ar[0]) < 2.0])
		else:
			out.push_front(["anti", Txt.t("as_hc_k_anti"), Txt.t("as_hc_anti_warn"), true])
	# what the eye sees: the fixings and the cables and pipes still on it
	out.append(["links", Txt.t("as_hc_r_links"), _fix_text(p), false])
	var nc := 0
	var np := 0
	for l in game.world.lines_of(p):
		if l.kind == "cable":
			nc += 1
		else:
			np += 1
	if nc + np > 0:
		out.append(["lines", Txt.t("as_hc_r_lines"), Txt.t("as_hc_lines_v") % [nc, np], false])
	out.append(["mass", Txt.t("as_hc_r_mass"), "%.2f t" % game.world.group_mass(p), false])
	return out


func _fix_text(p) -> String:
	if p.body != null:
		return Txt.t("as_hc_free")
	var n := {}
	for j in game.world.joints_of(p):
		n[j.type] = int(n.get(j.type, 0)) + 1
	if n.is_empty():
		return Txt.t("as_hc_none")
	var parts: Array = []
	for t in ["weld", "bolt", "lock", "clamp"]:
		if n.has(t):
			parts.append("%s %d" % [Txt.t("j_" + t), n[t]])
	return "  ".join(parts)


# the hover tag's second line and whether it warns: [text, warn, icon]
func status(p, h: Dictionary) -> Array:
	var tl = game.tools
	if not h.get("ok", true):
		return [game.txt(str(h.get("reason", ""))), true, "warn"]
	var m: float = game.world.group_mass(p)
	if tl.tool == 3 and m > game.grab_max():
		return [Txt.t("as_hc_heavy") % m, true, "warn"]
	var ds := dangers(p)
	if not ds.is_empty():
		var d: String = ds[0]
		var rs := rows(p)
		var val := ""
		for r in rs:
			if r[0] in ["anti", "pressure", "volts", "fluid", "dose", "temp"]:
				val = str(r[2])
				break
		return [Txt.t("as_hc_k_" + d) + ("  ·  " + val if val != "" else ""), true, d]
	var s := ""
	if p.body != null:
		s = Txt.t("as_hc_free")
	else:
		var nj: int = game.world.joints_of(p).size()
		s = Txt.t("as_hc_fixed") % nj if nj > 0 else Txt.t("as_hc_unfixed")
	if not p.scope:
		s += "  ·  " + game.txt("sc_out")
	return [s, false, ""]


# ---------------------------------------------------------------- drawing

func _xf() -> Transform2D:
	return game.get_viewport().get_canvas_transform()


func _screen_poly(p) -> PackedVector2Array:
	var wp: PackedVector2Array = game.world.world_poly(p)
	return _xf() * wp


static func _bounds(pts: PackedVector2Array) -> Rect2:
	if pts.is_empty():
		return Rect2()
	var r := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		r = r.expand(q)
	return r


func _outline(pts: PackedVector2Array, a: float, wd: float) -> void:
	if pts.size() < 2:
		return
	var loop := pts.duplicate()
	loop.append(pts[0])
	FastDraw.polyline(c, loop, Color(0, 0, 0, 0.55 * a), wd + 2.2)
	FastDraw.polyline(c, loop, Color(UiSkin.ACCENT, 0.95 * a), wd)


func _box(r: Rect2, a: float, edge: Color = Color(1, 1, 1, 0.12)) -> void:
	c.draw_rect(r, Color(Charcoal.SCREEN, a))
	c.draw_rect(r, Color(edge, edge.a * a), false, 1.0)


func _font(bold := false) -> Font:
	var hd = game.hud
	if hd != null:
		return hd.font_b if bold and hd.font_b != null else hd.font
	return ThemeDB.fallback_font


func _str(s: String, pos: Vector2, px: int, col: Color, bold := false) -> void:
	c.draw_string(_font(bold), pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _tw(s: String, px: int, bold := false) -> float:
	return _font(bold).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x


func _draw_center() -> void:
	card_rect = Rect2()
	if not _active():
		return
	var tl = game.tools
	var h: Dictionary = tl.hover
	var hp = _hover_piece()
	if sel != null:
		_outline(_screen_poly(sel), 1.0, 1.6)
	if hp != null and hp != sel:
		var pts := _screen_poly(hp)
		_outline(pts, 1.0, 1.3)
		# lid / batt keep the HUD's own tag (they name the wrench's or the lead's job)
		if str(h.kind) in ["piece", "inspect"] and tag_rect.has_area():
			_tag(hp, h)
	if sel != null:
		_card(sel)


func _tag_layout(p, h: Dictionary) -> Rect2:
	var st := status(p, h)
	var x0 := 10.0 + (18.0 if str(st[2]) != "" else 0.0)
	var wd := maxf(_tw(Txt.piece_name(p), 15, true), _tw(str(st[0]), 14)) + x0 + 12.0
	wd = maxf(wd, _tw(Txt.t("as_hc_more"), 12) + 22.0) if danger(p) else wd
	var hgt := 46.0 + (17.0 if danger(p) else 0.0)
	var aim_s: Vector2 = _xf() * (game.tools.aim as Vector2)
	var vs: Vector2 = c.size
	var sz := Vector2(wd, hgt)
	var hud_ko: Array = _ko()
	# by the pointer, below and to the right; round the other corners when that runs into the HUD
	# or off the screen (the OSD's range line goes under it: 22 px kept for it)
	var first := Rect2()
	for off in [Vector2(22, 24), Vector2(-22 - wd, 24), Vector2(22, -24 - hgt - 22), Vector2(-22 - wd, -24 - hgt - 22)]:
		var r := Rect2(aim_s + off, sz)
		var with_line := Rect2(r.position, r.size + Vector2(0, 22))
		if not first.has_area():
			first = r
		if with_line.position.x < 8.0 or with_line.position.y < 8.0 or with_line.end.x > vs.x - 8.0 or with_line.end.y > vs.y - 8.0:
			continue
		if _hits(with_line, hud_ko):
			continue
		return r
	return first


func _tag(p, h: Dictionary) -> void:
	var name: String = Txt.piece_name(p)
	var st := status(p, h)
	var ic: String = str(st[2])
	var x0 := 10.0 + (18.0 if ic != "" else 0.0)
	var r := tag_rect
	var warn: bool = st[1]
	_box(r, 1.0)
	if warn:
		c.draw_rect(Rect2(r.position, Vector2(2, r.size.y)), Color(HEAT if ic == "warn" else UiSkin.ACCENT, 0.95))
	_str(name, r.position + Vector2(10, 19), 15, Color(UiSkin.INK, 0.97), true)
	if ic != "":
		icon(c, ic, r.position + Vector2(18, 34), HEAT if ic == "warn" else UiSkin.ACCENT)
	_str(str(st[0]), r.position + Vector2(x0, 39), 14, (HEAT if ic == "warn" else UiSkin.ACCENT) if warn else Color(UiSkin.DIM, 0.95))
	if danger(p):
		_str(Txt.t("as_hc_more"), r.position + Vector2(10, 57), 12, Color(UiSkin.DIM, 0.7))


func _card(p) -> void:
	var rs := rows(p)
	var ds := dangers(p)
	var name: String = Txt.piece_name(p)
	var hgt := 64.0 + rs.size() * 26.0 + 26.0
	var wide := _tw(name, 17, true) + 28.0
	for row in rs:
		wide = maxf(wide, 70.0 + _tw(str(row[1]), 13) + _tw(str(row[2]), 15, true))
	var size := Vector2(clampf(wide, CARD_W, 520.0), hgt)
	var pts := _screen_poly(p)
	var pb := _bounds(pts)
	var r := place(pb, size)
	var a := Pal.ease_out(card_k)
	r.position.x += (1.0 - a) * (8.0 if card_side == "right" else (-8.0 if card_side == "left" else 0.0))
	card_rect = r
	# the leader back to the part
	var cpt := Vector2(clampf(r.get_center().x, pb.position.x, pb.end.x), clampf(r.get_center().y, pb.position.y, pb.end.y))
	var lp := Vector2(clampf(cpt.x, r.position.x, r.end.x), clampf(cpt.y, r.position.y, r.end.y))
	c.draw_line(lp, cpt, Color(UiSkin.ACCENT, 0.45 * a), 1.0)
	_box(r, a, Color(1, 1, 1, 0.14))
	# the head: the danger kinds (icon + word), the part's name
	var any_hot := false
	for row in rs:
		any_hot = any_hot or row[3]
	var hc: Color = HEAT if any_hot else UiSkin.ACCENT
	c.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(hc, 0.9 * a))
	var x := r.position.x + 14.0
	for d in ds.slice(0, 3):
		icon(c, d, Vector2(x + 7.0, r.position.y + 20.0), Color(hc, a))
		var word := Txt.t("as_hc_k_" + d)
		_str(word, Vector2(x + 18.0, r.position.y + 25.0), 13, Color(hc, 0.95 * a))
		x += 18.0 + _tw(word, 13) + 14.0
	_str(name, r.position + Vector2(14, 50), 17, Color(UiSkin.INK, a), true)
	var y := r.position.y + 64.0
	for row in rs:
		c.draw_line(Vector2(r.position.x + 12, y), Vector2(r.end.x - 12, y), Color(1, 1, 1, 0.06 * a), 1.0)
		icon(c, str(row[0]), Vector2(r.position.x + 21.0, y + 13.0), Color(UiSkin.DIM, 0.9 * a))
		_str(str(row[1]), Vector2(r.position.x + 36.0, y + 18.0), 13, Color(UiSkin.DIM, 0.95 * a))
		var v: String = str(row[2])
		var vc: Color = HEAT if row[3] else UiSkin.INK
		if v == Txt.t("as_hc_unmeasured"):
			vc = Color(UiSkin.DIM, 0.85)
		var vx: float = r.end.x - 14.0 - _tw(v, 15, true)
		vx = maxf(vx, r.position.x + 52.0 + _tw(str(row[1]), 13))
		_str(v, Vector2(vx, y + 18.0), 15, Color(vc, vc.a * a), true)
		y += 26.0
	_str(Txt.t("as_hc_close"), Vector2(r.position.x + 14.0, r.end.y - 9.0), 12, Color(UiSkin.DIM, 0.6 * a))


# where the card stands: beside the part, clear of what the player works with
# the HUD's own keep-out, and the right column's cards (公测反馈 2026-11-12): the coach's and the
# warehouse guide's step card, the first-meeting card, the first-use key card
func _ko() -> Array:
	var out: Array = game.hud.keep_out().duplicate() if game.hud != null and game.hud.has_method("keep_out") else []
	for o in [game.get("coach"), game.get("store_guide")]:
		if o != null and is_instance_valid(o) and "card" in o and o.card != null and is_instance_valid(o.card) and o.card.is_visible_in_tree():
			out.append((o.card.get_global_rect() as Rect2).grow(8.0))
	var cx = game.get("codex_hud")
	if cx != null and cx.k > 0.01 and cx.rect.has_area():
		out.append((cx.rect as Rect2).grow(8.0))
	if game.hud != null and game.hud.has_method("op_rect") and game.hud.op_act != "" and game.hud.op_t <= OpCards.SHOW_S:
		out.append((game.hud.op_rect(c.size) as Rect2).grow(8.0))
	return out


func place(pb: Rect2, size: Vector2) -> Rect2:
	var vs: Vector2 = c.size
	var keep: Array = _protect()
	var hud_ko: Array = _ko()
	var cy := clampf(pb.get_center().y - size.y * 0.5, 12.0, vs.y - size.y - 12.0)
	var cx := clampf(pb.get_center().x - size.x * 0.5, 12.0, vs.x - size.x - 12.0)
	# beside the part, and beside the pointer when it rests near the part's edge
	var aim_s: Vector2 = _xf() * (game.tools.aim as Vector2)
	var cand := {
		"right": Rect2(Vector2(maxf(pb.end.x, aim_s.x + 34.0) + GAP, cy), size),
		"left": Rect2(Vector2(minf(pb.position.x, aim_s.x - 34.0) - GAP - size.x, cy), size),
		"above": Rect2(Vector2(cx, minf(pb.position.y, aim_s.y - 34.0) - GAP - size.y), size),
		"below": Rect2(Vector2(cx, maxf(pb.end.y, aim_s.y + 34.0) + GAP), size),
	}
	var order: Array = ["right", "left", "above", "below"]
	# the side it stood on keeps it while it still works (no flicking back and forth)
	if card_side in order:
		order.erase(card_side)
		order.push_front(card_side)
	for k in order:
		var r: Rect2 = cand[k]
		if r.position.x < 8.0 or r.position.y < 8.0 or r.end.x > vs.x - 8.0 or r.end.y > vs.y - 8.0:
			continue
		if _hits(r, keep) or _hits(r, hud_ko):
			continue
		card_side = k
		return r
	# no side clear (a part too big, or the HUD round it): the place over the least of the HUD —
	# the sides first, then along the screen's edges — never over the pointer, the drone or the beam
	# (公测反馈 2026-11-12: the old fixed edge place could sit on the panels on the left)
	var tries: Array = []
	for k in order:
		tries.append([k, cand[k]])
	var y := 100.0
	while y <= vs.y - size.y - 130.0:
		for x in [24.0, vs.x * 0.5 - size.x * 0.5, vs.x - size.x - 24.0]:
			tries.append(["edge", Rect2(Vector2(x, y), size)])
		y += 40.0
	var best: Rect2 = Rect2()
	var best_s := INF
	var best_k := "edge"
	for t in tries:
		var r: Rect2 = t[1]
		if r.position.x < 8.0 or r.position.y < 8.0 or r.end.x > vs.x - 8.0 or r.end.y > vs.y - 8.0:
			continue
		var sc := 0.0
		for z in keep:
			if r.intersects(z):
				sc += 100.0 * r.intersection(z).get_area() + 1.0e6
		for z in hud_ko:
			if r.intersects(z):
				sc += r.intersection(z).get_area()
		sc += r.get_center().distance_to(pb.get_center()) * 2.0
		if sc < best_s:
			best_s = sc
			best = r
			best_k = t[0]
	card_side = best_k
	return best


# what the card must never cover: the pointer, the beam's spot, the drone and the line between
func _protect() -> Array:
	var xf := _xf()
	var tl = game.tools
	var aim_s: Vector2 = xf * (tl.aim as Vector2)
	var dr_s: Vector2 = xf * game.drone.global_position
	var out: Array = [Rect2(aim_s - Vector2(34, 34), Vector2(68, 68)), Rect2(dr_s - Vector2(48, 48), Vector2(96, 96))]
	if tl.cutting or tl.tool == 2:
		var fr: Vector2 = xf * (tl.front as Vector2) if tl.cutting else aim_s
		out.append(Rect2(fr - Vector2(70, 70), Vector2(140, 140)))
		var seg := Rect2(dr_s, Vector2.ZERO).expand(aim_s)
		if seg.size.x < 900.0 and seg.size.y < 900.0:
			out.append(seg.grow(24.0))
	return out


static func _hits(r: Rect2, zones: Array) -> bool:
	for z in zones:
		if (z as Rect2).intersects(r):
			return true
	return false


# ---------------------------------------------------------------- icons (12 px, line drawn)

static func icon(ci: CanvasItem, kind: String, at: Vector2, col: Color) -> void:
	var w := 1.4
	match kind:
		"warn", "explosive":
			var tri := PackedVector2Array([at + Vector2(0, -7), at + Vector2(7, 6), at + Vector2(-7, 6), at + Vector2(0, -7)])
			ci.draw_polyline(tri, col, w, true)
			ci.draw_line(at + Vector2(0, -2.5), at + Vector2(0, 1.5), col, 1.6)
			ci.draw_rect(Rect2(at + Vector2(-0.8, 3.0), Vector2(1.6, 1.6)), col)
		"pressure":
			ci.draw_arc(at, 6.5, 0.0, TAU, 20, col, w, true)
			ci.draw_line(at, at + Vector2.from_angle(-0.7) * 5.0, col, 1.6)
			ci.draw_line(at + Vector2(-4, 4), at + Vector2(4, 4), col, 1.0)
		"fluid", "fuel":
			var dp := PackedVector2Array([at + Vector2(0, -7), at + Vector2(5, 1), at + Vector2(3.5, 5), at + Vector2(0, 6.5), at + Vector2(-3.5, 5), at + Vector2(-5, 1), at + Vector2(0, -7)])
			ci.draw_polyline(dp, col, w, true)
		"power", "volts":
			var bolt := PackedVector2Array([at + Vector2(2, -7), at + Vector2(-3, 1), at + Vector2(1, 1), at + Vector2(-2, 7), at + Vector2(4, -1), at + Vector2(0, -1), at + Vector2(2, -7)])
			ci.draw_polyline(bolt, col, w, true)
		"heat", "temp":
			ci.draw_line(at + Vector2(0, -7), at + Vector2(0, 2), col, 2.4)
			ci.draw_arc(at + Vector2(0, 4), 3.2, 0.0, TAU, 14, col, w, true)
			ci.draw_line(at + Vector2(3, -5), at + Vector2(5, -5), col, 1.0)
			ci.draw_line(at + Vector2(3, -2), at + Vector2(5, -2), col, 1.0)
		"rad", "dose":
			ci.draw_circle(at, 1.6, col)
			for k in 3:
				var a0 := -PI * 0.5 + TAU * k / 3.0 - 0.45
				var poly := PackedVector2Array([at + Vector2.from_angle(a0) * 3.0, at + Vector2.from_angle(a0) * 7.0, at + Vector2.from_angle(a0 + 0.9) * 7.0, at + Vector2.from_angle(a0 + 0.9) * 3.0])
				ci.draw_colored_polygon(poly, col)
		"anti":
			ci.draw_arc(at, 6.5, 0.0, TAU, 20, col, w, true)
			ci.draw_arc(at, 3.0, 0.0, TAU, 12, col, 1.0, true)
			ci.draw_line(at + Vector2(-8, 0), at + Vector2(-6.5, 0), col, 1.0)
			ci.draw_line(at + Vector2(6.5, 0), at + Vector2(8, 0), col, 1.0)
		"bio":
			for k in 3:
				ci.draw_arc(at + Vector2.from_angle(-PI * 0.5 + TAU * k / 3.0) * 3.2, 3.4, 0.0, TAU, 12, col, 1.2, true)
		"chem":
			var fl := PackedVector2Array([at + Vector2(-2, -7), at + Vector2(-2, -2), at + Vector2(-6, 6), at + Vector2(6, 6), at + Vector2(2, -2), at + Vector2(2, -7)])
			ci.draw_polyline(fl, col, w, true)
		"links":
			ci.draw_arc(at, 5.5, 0.0, TAU, 6, col, w, true)
			ci.draw_arc(at, 2.0, 0.0, TAU, 10, col, 1.0, true)
		"lines":
			ci.draw_line(at + Vector2(-7, -3), at + Vector2(7, -3), col, 1.2)
			ci.draw_line(at + Vector2(-7, 3), at + Vector2(7, 3), col, 2.4)
		"mass":
			var kb := PackedVector2Array([at + Vector2(-3, -3), at + Vector2(3, -3), at + Vector2(6, 6), at + Vector2(-6, 6), at + Vector2(-3, -3)])
			ci.draw_polyline(kb, col, w, true)
			ci.draw_arc(at + Vector2(0, -5), 2.0, 0.0, TAU, 10, col, 1.0, true)
		"sample", "read":
			ci.draw_rect(Rect2(at - Vector2(6, 5), Vector2(12, 10)), col, false, 1.2)
			ci.draw_line(at + Vector2(-3, 1), at + Vector2(3, 1), col, 1.0)
		_:
			ci.draw_circle(at, 2.2, col)
