extends Control
# The star map (design/…/31 号; 23 Q9): the Sun, Mars and Jupiter for reference, the port and
# the belt stations turning on their real orbits, every freighter on its Lambert arc — flown
# part solid, the rest dashed. Click a ship (on the map or in the list) for its Δv, its true
# days to go and its cargo. Opened from the exchange and from the ops screen.

var game
var on_close: Callable
var chosen := ""
var list: VBoxContainer
var detail: Label
var map: Control
var font: Font
var _list_t := 0.0
# 68 号: "find" sweeps the belt for hulks, "ships" follows the freighters
var mode := "ships"
var sel_sector := -1
var sel_sig := ""
var find_box: VBoxContainer
var ship_box: VBoxContainer
var tab_find: Button
var tab_ships: Button
var _sig_key := ""
var _note := ""
var _last_an := ""             # the signal being analysed at the last look
var _done_sig := ""            # one just analysed: its result on the status line till _done_until
var _done_until := 0
const DONE_MS := 4000
const SCALE_AU := 3.7          # AU from the Sun to the map's edge (Jupiter drawn at the rim)


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font = Fonts.get_font("Medium")
	# 54 号: the new skin's ground under the map
	add_child(UiSkin.Ground.new())
	map = Control.new()
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.offset_right = -520
	map.draw.connect(_draw_map)
	map.gui_input.connect(_map_input)
	add_child(map)
	var accent := Pal.tint(Pal.AIR, 1.0, 1.2)
	var column := OpsSkin.pane(self, accent, 460.0)
	column.add_child(OpsSkin.Plate.new("NAV-3", w("星图", "STAR MAP"), w("日心轨道 · 1 秒 = %.1f 天", "HELIOCENTRIC · 1 s = %.1f DAYS") % Orbits.DAYS_PER_S, accent))
	var tabs := HBoxContainer.new()
	tab_find = Button.new()
	tab_find.text = w("找船", "FIND HULKS")
	tab_find.toggle_mode = true
	tab_find.custom_minimum_size = Vector2(200, 40)
	tab_find.pressed.connect(func(): set_mode("find"))
	tab_ships = Button.new()
	tab_ships.text = w("航运", "SHIPPING")
	tab_ships.toggle_mode = true
	tab_ships.custom_minimum_size = Vector2(200, 40)
	tab_ships.pressed.connect(func(): set_mode("ships"))
	tabs.add_child(tab_find)
	tabs.add_child(tab_ships)
	column.add_child(tabs)
	detail = OpsSkin.label("", 15)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(OpsSkin.as_screen(detail))
	ship_box = VBoxContainer.new()
	ship_box.add_child(OpsSkin.Section.new(w("船", "SHIPS")))
	list = VBoxContainer.new()
	ship_box.add_child(list)
	column.add_child(ship_box)
	find_box = VBoxContainer.new()
	column.add_child(find_box)
	var close_b := Button.new()
	close_b.text = w("关闭 [Esc]", "CLOSE [Esc]")
	close_b.custom_minimum_size.y = 42
	close_b.pressed.connect(close)
	column.add_child(close_b)
	_tour_parts.close = close_b
	if mode == "find" and sel_sector < 0:
		sel_sector = int(Scan.order()[0])
	set_mode(mode)
	if mode == "find" and Career.usable() and not Career.data.is_empty() and not Career.data.get("seen", {}).get("starmap_tour", false):
		start_tour.call_deferred()



func set_mode(m: String) -> void:
	mode = m
	tab_find.button_pressed = m == "find"
	tab_ships.button_pressed = m == "ships"
	ship_box.visible = m == "ships"
	find_box.visible = m == "find"
	detail.visible = true
	if m == "find" and sel_sector < 0:
		sel_sector = int(Scan.order()[0])
	_sig_key = ""
	_fill()


# user 2026-10-26 ("刚刚派了拖船去拖，应该给我弹出来那个星图"): a tug just sent — the map opens on it
# and keeps it in the middle until the hand moves the view; the first time, its parts are shown
var follow := ""
var _follow_on := false
var _tour_kind := "find"


func watch_tow(id: String) -> void:
	follow = id
	_follow_on = true
	view_zt = 2.2
	set_mode("find")
	if Career.usable() and not Career.data.is_empty() and not Career.data.get("seen", {}).get("tow_tour", false):
		_tour_kind = "tow"
		start_tour.call_deferred()


func _tow_au(id: String) -> Vector2:
	if not Career.data.has("ship_market"):
		return Vector2.INF
	for a in ShipMarket.data().assets:
		if str(a.id) == id and str(a.state) == "towing":
			var k := clampf((Shipping.day() - float(a.run.depart)) / maxf(ShipMarket.tow_span(a), 0.0001), 0.0, 1.0)
			return Orbits.on_transfer(a.run, k)
	return Vector2.INF


func _process(dt: float) -> void:
	if _follow_on:
		var au := _tow_au(follow)
		if au.is_finite():
			pan_t = au
		else:
			_follow_on = false
	var e := 1.0 - exp(-12.0 * dt)
	# the framed part can move (the tug, the view easing onto it): the frame goes with it
	if _tour_i >= 0 and _tour_layer != null:
		_tour_layer.queue_redraw()
	view_z = lerpf(view_z, view_zt, e)
	_inset_pos = _inset_pos.lerp(_inset_goal, 1.0 - exp(-7.0 * dt))
	pan = pan.lerp(pan_t, e)
	_hover_t += dt
	_list_t += dt
	if _list_t > 0.5:
		_list_t = 0.0
		_fill()
	map.queue_redraw()


func _state_name(s: Dictionary) -> String:
	match str(s.state):
		"inbound": return w("在途 · 来港", "INBOUND")
		"queued": return w("港外排队", "WAITING OFF THE PIER")
		"docked": return w("%d 号船位" % (int(s.slot) + 1), "AT BERTH %d" % (int(s.slot) + 1))
		"leaving": return w("返航" if str(s.dir) == "in" else "载货返航", "HEADING HOME" if str(s.dir) == "in" else "CARRYING YOUR GOODS HOME")
	return w("已离开", "GONE")


func _fill() -> void:
	if mode == "find":
		_fill_find()
		return
	for c in list.get_children():
		c.queue_free()
	var ships := Shipping.live()
	if ships.is_empty():
		list.add_child(OpsSkin.label(w("没有船在路上。交易行里向独立商户买卖，货船会从他们的小行星带站点起航。", "No ships under way. Trade with an independent merchant on the exchange and a freighter leaves their belt station."), 14, 0.7))
	for s in ships:
		var b := Button.new()
		var sta: Array = Orbits.station(int(s.station))
		b.text = "%s · %s · %s" % [str(s.id), Orbits.name_of(sta), _state_name(s)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 38
		var id := str(s.id)
		b.pressed.connect(func(): chosen = id; _detail())
		list.add_child(b)
	_detail()


func _ship(id: String) -> Dictionary:
	for s in Shipping.data().ships:
		if str(s.id) == id:
			return s
	return {}


func _detail() -> void:
	var c := Shipping.counts()
	var head := w("第 %d 天 · 在途 %d · 排队 %d · 靠泊 %d · 码头船位 %d", "DAY %d · INBOUND %d · QUEUED %d · DOCKED %d · BERTHS %d") % [int(Shipping.day()), int(c.inbound), int(c.queued), int(c.docked), Shipping.slots()]
	var s := _ship(chosen)
	if s.is_empty():
		detail.text = head + "\n" + w("点一艘船看它的轨道、Δv 和货。", "Click a ship for its orbit, Δv and cargo.")
		return
	var sta: Array = Orbits.station(int(s.station))
	var run: Dictionary = s.get("run", {})
	var from := Orbits.name_of(sta) if str(s.state) == "inbound" else Orbits.name_of(Orbits.PORT)
	var to := Orbits.name_of(Orbits.PORT) if str(s.state) == "inbound" else Orbits.name_of(sta)
	var lines := [head, "", "%s「%s」 · %.0f m" % [str(s.id), str(s.name), float(s.length)], _state_name(s),
		w("货：%s %.2f t（%d 件）", "CARGO: %s %.2f t (%d PIECES)") % [Ops.item_name("%s:%d" % [str(s.item), int(s.grade)]), float(s.quantity), s.pieces.size()]]
	if str(s.state) in ["inbound", "leaving"] and not run.is_empty():
		lines.append(w("%s → %s", "%s → %s") % [from, to])
		lines.append(w("转移 %d 天 · 出发 Δv %.1f km/s · 到达 Δv %.1f km/s", "TRANSFER %d DAYS · Δv OUT %.1f km/s · IN %.1f km/s") % [int(run.tof), float(run.dv1), float(run.dv2)])
		lines.append(Shipping.eta_text(s))
	if str(s.state) == "docked":
		var left: int = s.pieces.filter(func(p): return str(p.where) in ["hold", "deck"]).size()
		lines.append(w("还有 %d 件要搬：%s", "%d PIECES TO HAUL: %s") % [left, w("用抓钩拖进仓库收货口（货运区修好后吊车自动搬 3 t 以下的件）", "grapple them into the warehouse receiver (the crane does pieces under 3 t once the cargo district is mended)") if str(s.dir) == "in" else w("从出货台拖进它的货舱", "drag them from the loading table into its hold")])
	detail.text = "\n".join(lines)


# ---------------------------------------------------------------- the map

# the view (user 2026-10-26: "丝滑流畅，还有和鼠标的互动"): the wheel zooms about the pointer, a drag
# pans, both easing to where the hand puts them; a double click puts it back
var view_z := 1.0
var view_zt := 1.0
var pan := Vector2.ZERO          # AU: the chart's middle
var pan_t := Vector2.ZERO
var mouse := Vector2(-99999, -99999)
var _drag := false
var _drag_moved := 0.0
var _drag_at := Vector2.ZERO
var hover := {}                  # {pos, title, lines}: what the pointer is on
var _hover_t := 0.0


func _k0() -> float:
	return minf(map.size.x, map.size.y) * 0.47 / SCALE_AU


func _from(sp: Vector2) -> Vector2:
	var d := (sp - map.size * 0.5) / _k()
	return pan + Vector2(d.x, -d.y)


func _k() -> float:
	return _k0() * view_z


func _to(p: Vector2) -> Vector2:
	var d := p - pan
	return map.size * 0.5 + Vector2(d.x, -d.y) * _k()


func _orbit(el: Array, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	var t := Orbits.period(el)
	for i in 97:
		pts.append(_to(Orbits.pos(el, t * i / 96.0)))
	map.draw_polyline(pts, col, width, true)


# the arc a body has just flown, bright at the body and fading behind it (a comet's tail on the chart)
func _trail(el: Array, day: float, col: Color, frac: float = 0.22, width: float = 2.0) -> void:
	var per := Orbits.period(el)
	var n := 28
	var prev := _to(Orbits.pos(el, day - per * frac))
	for i in range(1, n + 1):
		var k := float(i) / n
		var p := _to(Orbits.pos(el, day - per * frac * (1.0 - k)))
		map.draw_line(prev, p, Color(col, col.a * k * k), width * (0.4 + 0.6 * k), true)
		prev = p


# ---------------------------------------------------------------- the chart's dressing (user 2026-10-26:
# "这个地图太假了……一点没有沉浸感" — a radar chart that moves: stars, a living sun, the belt as a
# stream of rock on Kepler's clock, the grid and bearings of a navigation plot)

var _stars: Array = []          # [pos (0..1), size, phase]
var _belt: Array = []           # [r AU, angle, size, alpha]


func _dressing_init() -> void:
	if not _stars.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261026
	for i in 420:
		_stars.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(0.6, 1.8), rng.randf() * TAU])
	for i in 1400:
		var r := clampf(rng.randfn(2.7, 0.28), 2.05, 3.35)
		_belt.append([r, rng.randf() * TAU, rng.randf_range(0.8, 1.9), rng.randf_range(0.12, 0.45)])


func _draw_space(c: Vector2, t: float) -> void:
	var box := Rect2(Vector2(24, 24), map.size - Vector2(48, 48))
	map.draw_rect(box, Color(0.016, 0.019, 0.026))
	# a soft light from the middle of the chart out to the dark rim
	for i in 10:
		var k := 1.0 - i / 10.0
		map.draw_circle(c, minf(box.size.x, box.size.y) * 0.62 * k, Color(0.05, 0.06, 0.08, 0.05))
	var par := (mouse - map.size * 0.5) * -0.012 if mouse.x > -9999.0 else Vector2.ZERO
	for st in _stars:
		var p: Vector2 = box.position + Vector2(fposmod((st[0] as Vector2).x * box.size.x + par.x * float(st[1]), box.size.x), fposmod((st[0] as Vector2).y * box.size.y + par.y * float(st[1]), box.size.y))
		var tw := 0.35 + 0.35 * sin(t * 0.8 + float(st[2]))
		map.draw_rect(Rect2(p, Vector2.ONE * float(st[1])), Pal.ink(0.12 + 0.25 * tw))


func _draw_grid(c: Vector2, t: float) -> void:
	var k := _k()
	var rim := SCALE_AU * k
	# range rings every half AU, the whole ones brighter and labelled
	for h in range(1, int(SCALE_AU * 2.0) + 1):
		var au := h * 0.5
		var whole := h % 2 == 0
		map.draw_arc(c, au * k, 0.0, TAU, 160, Pal.ink(0.06 if whole else 0.03), 1.0, true)
		if whole:
			map.draw_string(font, c + Vector2(au * k + 4, 14), "%d AU" % int(au), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.32))
	# bearings: a spoke every 15 degrees, the rim ticked every 5, the four quarters named
	for d in range(0, 360, 5):
		var a := deg_to_rad(float(d))
		var dir := Vector2(cos(a), -sin(a))
		var long := d % 15 == 0
		map.draw_line(c + dir * rim, c + dir * (rim - (12.0 if long else 5.0)), Pal.ink(0.22 if long else 0.1), 1.0)
		if d % 15 == 0:
			map.draw_line(c + dir * 1.0 * k, c + dir * (rim - 14.0), Pal.ink(0.025), 1.0)
		if d % 90 == 0:
			map.draw_string(font, c + dir * (rim + 10.0) + Vector2(-12, 5), "%03d°" % d, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.4))
	map.draw_arc(c, rim, 0.0, TAU, 200, Pal.ink(0.16), 1.0, true)
	# a slow bearing scan round the rim
	var sw := fmod(t * 0.35, TAU)
	for n in 18:
		var a2 := sw - n * 0.03
		map.draw_line(c + Vector2(cos(a2), sin(a2)) * (rim - 18.0), c + Vector2(cos(a2), sin(a2)) * rim, Color(UiSkin.DATA, 0.35 * (1.0 - n / 18.0)), 2.0, true)


func _draw_sun(c: Vector2, t: float) -> void:
	var g := UiSkin.glow_tex()
	for spec in [[70.0, 0.08], [42.0, 0.2], [22.0, 0.5]]:
		var r: float = spec[0]
		map.draw_texture_rect(g, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(UiSkin.ACCENT, float(spec[1])))
	# the corona: rays turning slowly, each breathing on its own
	for i in 28:
		var a := TAU * i / 28.0 + t * 0.05
		var l := 14.0 + 10.0 * (0.5 + 0.5 * sin(t * 1.3 + i * 1.7))
		map.draw_line(c + Vector2(cos(a), sin(a)) * 9.0, c + Vector2(cos(a), sin(a)) * (9.0 + l), Color(UiSkin.ACCENT, 0.35), 1.0, true)
	map.draw_circle(c, 7.5, UiSkin.ACCENT)
	map.draw_circle(c, 4.0, Color(1.0, 0.93, 0.85))
	map.draw_string(font, c + Vector2(14, -10), w("太阳", "SUN"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiSkin.ACCENT)


func _draw_belt(c: Vector2, day: float) -> void:
	var k := _k()
	for b in _belt:
		var r: float = b[0]
		# Kepler: a rock at r AU goes round once in r^1.5 years
		var a: float = float(b[1]) + day / (365.25 * pow(r, 1.5)) * TAU
		var p := c + Vector2(cos(a), -sin(a)) * r * k
		map.draw_rect(Rect2(p, Vector2.ONE * float(b[2])), Pal.ink(float(b[3])))
	map.draw_string(font, c + Vector2(0, -3.38 * k) + Vector2(-34, -4), w("小行星带", "ASTEROID BELT"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.35))


func _draw_frame(t: float, day: float) -> void:
	var box := Rect2(Vector2(24, 24), map.size - Vector2(48, 48))
	var col := Color(UiSkin.DATA, 0.6)
	for corner in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
		var d: Vector2 = (box.get_center() - corner).sign()
		map.draw_line(corner, corner + Vector2(d.x * 26.0, 0), col, 2.0)
		map.draw_line(corner, corner + Vector2(0, d.y * 26.0), col, 2.0)
	var y := box.end.y - 14.0
	map.draw_string(font, Vector2(box.position.x + 18, y), w("日心坐标 · 第 %.1f 天 · 1 秒 = %.1f 天", "HELIOCENTRIC · DAY %.1f · 1 s = %.1f DAYS") % [day, Orbits.DAYS_PER_S], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.45))
	# a thin scan line passing down the glass
	var sy := box.position.y + fmod(t * 60.0, box.size.y)
	map.draw_line(Vector2(box.position.x, sy), Vector2(box.end.x, sy), Color(UiSkin.DATA, 0.018), 1.0)


func _draw_map() -> void:
	_dressing_init()
	_labels.clear()
	var day := Shipping.day()
	var t := Time.get_ticks_msec() / 1000.0
	var c := _to(Vector2.ZERO)
	_draw_space(map.size * 0.5, t)
	_draw_grid(c, t)
	_draw_belt(c, day)
	_draw_sun(c, t)
	for el in Orbits.PLANETS:
		var p := Orbits.pos(el, day)
		if p.length() <= SCALE_AU:
			_orbit(el, Pal.ink(0.08), 1.0)
			_trail(el, day, Pal.heat(0.55, 1.1), 0.2, 2.0)
			var at := _to(p)
			map.draw_texture_rect(UiSkin.glow_tex(), Rect2(at - Vector2(16, 16), Vector2(32, 32)), false, Pal.heat(0.35, 1.2))
			map.draw_circle(at, 4.5, Pal.heat(0.8, 1.2))
			_label(at, Orbits.name_of(el), "", 12, Pal.ink(0.65), Color(), 2)
		else:
			# Jupiter beyond the map: its bearing at the rim
			var rim := _to(p.normalized() * SCALE_AU * 0.99)
			map.draw_line(rim, rim - (rim - c).normalized() * 16.0, Pal.heat(0.6, 1.1), 2.0)
			map.draw_string(font, rim - (rim - c).normalized() * 70.0, "%s %.1f AU →" % [Orbits.name_of(el), p.length()], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.55))
	for i in Orbits.STATIONS.size():
		var el: Array = Orbits.STATIONS[i]
		# user 2026-10-26: "其他空间站，你点它的时候才会出现轨道"
		if i == sel_sector:
			_orbit(el, Color(UiSkin.ACCENT, 0.55), 1.4)
			_trail(el, day, Color(UiSkin.ACCENT, 0.9), 0.08, 2.2)
		elif str(hover.get("key", "")) == "st%d" % i:
			_orbit(el, Color(UiSkin.DATA, 0.25), 1.0)
		var p := _to(Orbits.pos(el, day))
		var dia := PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)])
		map.draw_colored_polygon(dia, Color(0.05, 0.06, 0.08))
		dia.append(dia[0])
		map.draw_polyline(dia, Pal.ink(0.8), 1.2, true)
		# 107 号 Q5 A: the station's name and, on the find page, its sector's state as one placed label
		var sub := ""
		var sub_c := Pal.ink(0.45)
		if mode == "find":
			var k2 := Scan.order().find(i)
			if k2 >= 0 and k2 < Scan.reach():
				if Scan.sector(i).is_empty():
					sub = w("未扫", "UNSWEPT")
				elif Scan.cooldown(i) <= 0.0:
					sub = w("有新东西漂入", "NEW DRIFT")
					sub_c = Color(UiSkin.DATA, 0.85)
		_label(p, Orbits.name_of(el), sub, 12 if i == sel_sector else 11, Color(UiSkin.ACCENT, 0.95) if i == sel_sector else Pal.ink(0.6), sub_c, 4 if i == sel_sector else 2)
	# the port: a double ring turning, a beacon pulse
	_orbit(Orbits.PORT, Color(UiSkin.DATA, 0.25), 1.4)
	_trail(Orbits.PORT, day, Color(UiSkin.DATA, 0.8), 0.12, 2.5)
	var pp := _to(Orbits.pos(Orbits.PORT, day))
	var pulse := fmod(t * 0.6, 1.0)
	map.draw_arc(pp, 8.0 + 26.0 * pulse, 0.0, TAU, 40, Color(UiSkin.DATA, 0.5 * (1.0 - pulse)), 1.5, true)
	map.draw_texture_rect(UiSkin.glow_tex(), Rect2(pp - Vector2(22, 22), Vector2(44, 44)), false, Color(UiSkin.DATA, 0.4))
	map.draw_circle(pp, 5.5, UiSkin.DATA)
	for n in 2:
		var a0 := t * (0.8 if n == 0 else -0.5)
		map.draw_arc(pp, 11.0 + n * 5.0, a0, a0 + PI * 1.4, 24, Color(UiSkin.DATA, 0.7 - n * 0.25), 1.5, true)
	_label(pp, Orbits.name_of(Orbits.PORT), "", 13, UiSkin.DATA, Color(), 5, 14.0)
	_draw_tows(day, t)
	_draw_frame(t, day)
	_pick_hover(day, pp)
	if mode == "find":
		_draw_find(day, pp)
		_draw_pointer(t)
		return
	_flush_labels()
	_draw_pointer(t)
	# the ships
	for s in Shipping.live():
		var lit: bool = str(s.id) == chosen
		var col := UiSkin.ACCENT if lit else UiSkin.DATA
		var at: Vector2
		if str(s.state) in ["inbound", "leaving"]:
			var run: Dictionary = s.run
			var k := clampf((day - float(run.depart)) / float(run.tof), 0.0, 1.0)
			var arc := PackedVector2Array()
			for j in 49:
				arc.append(_to(Orbits.on_transfer(run, float(j) / 48.0)))
			for j in 48:
				var solid := float(j) / 48.0 < k
				map.draw_line(arc[j], arc[j + 1], Color(col, 0.75 if solid else 0.18), 2.0 if lit else 1.2, true)
			at = _to(Orbits.on_transfer(run, k))
		else:
			at = pp + (Vector2(18, 14) if str(s.state) == "queued" else Vector2(-16, 14))
		var tri := PackedVector2Array([at + Vector2(0, -6), at + Vector2(5, 5), at + Vector2(-5, 5)])
		map.draw_colored_polygon(tri, col)
		map.draw_string(font, at + Vector2(8, 12), str(s.id), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


# what the pointer is on: the nearest planet, station or the port within a reach
func _pick_hover(day: float, pp: Vector2) -> void:
	var was := str(hover.get("key", ""))
	hover = {}
	if mouse.x < 24.0 or mouse.y < 24.0 or mouse.x > map.size.x - 24.0 or mouse.y > map.size.y - 24.0 or _inset_rect().has_point(mouse):
		return
	var best := 18.0
	var cand: Array = []
	for el in Orbits.PLANETS:
		var pos := Orbits.pos(el, day)
		if pos.length() <= SCALE_AU * 1.4:
			cand.append(["pl" + str(el[0]), _to(pos), Orbits.name_of(el), [w("距太阳 %.2f AU", "%.2f AU FROM THE SUN") % pos.length(), w("一年 = %d 天", "YEAR = %d DAYS") % int(Orbits.period(el))]])
	for i in Orbits.STATIONS.size():
		var el: Array = Orbits.STATIONS[i]
		var pos := Orbits.pos(el, day)
		var to_port := pos.distance_to(Orbits.pos(Orbits.PORT, day))
		var reach := Scan.order().find(i) < Scan.reach()
		cand.append(["st%d" % i, _to(pos), Orbits.name_of(el), [w("距零压港 %.2f AU", "%.2f AU FROM THE PORT") % to_port, w("可以扫描 · 点一下选中", "IN REACH · CLICK TO PICK") if reach else w("太远，还扫不到", "OUT OF REACH")]])
	cand.append(["port", pp, Orbits.name_of(Orbits.PORT), [w("你的港口", "YOUR PORT"), w("距太阳 %.2f AU", "%.2f AU FROM THE SUN") % Orbits.pos(Orbits.PORT, day).length()]])
	for c in cand:
		var d := (c[1] as Vector2).distance_to(mouse)
		if d < best:
			best = d
			hover = {"key": c[0], "pos": c[1], "title": c[2], "lines": c[3]}
	if str(hover.get("key", "")) != was:
		_hover_t = 0.0


# the pointer: a reticle with its range and bearing, and a lock on what it is over
func _draw_pointer(t: float) -> void:
	if mouse.x < 24.0 or mouse.y < 24.0 or mouse.x > map.size.x - 24.0 or mouse.y > map.size.y - 24.0 or _inset_rect().has_point(mouse):
		return
	var m := mouse
	var col := Color(UiSkin.DATA, 0.2)
	map.draw_line(Vector2(24, m.y), Vector2(m.x - 14, m.y), col, 1.0)
	map.draw_line(Vector2(m.x + 14, m.y), Vector2(map.size.x - 24, m.y), col, 1.0)
	map.draw_line(Vector2(m.x, 24), Vector2(m.x, m.y - 14), col, 1.0)
	map.draw_line(Vector2(m.x, m.y + 14), Vector2(m.x, map.size.y - 24), col, 1.0)
	map.draw_arc(m, 7.0, 0.0, TAU, 20, Color(UiSkin.DATA, 0.8), 1.2, true)
	var au := _from(m)
	var brg := fposmod(rad_to_deg(atan2(au.y, au.x)), 360.0)
	map.draw_string(font, m + Vector2(14, 22), "%.2f AU · %03d°" % [au.length(), int(brg)], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(UiSkin.DATA, 0.85))
	if hover.is_empty():
		return
	# the lock: four brackets closing in, a ring breathing, the card beside it
	var hp: Vector2 = hover.pos
	var k := Pal.ease_out(clampf(_hover_t / 0.25, 0.0, 1.0))
	var r := lerpf(26.0, 13.0, k)
	for q in 4:
		var a := q * PI * 0.5 + PI * 0.25
		var cpt := hp + Vector2(cos(a), sin(a)) * r
		var d1 := Vector2(-sign(cos(a)), 0) * 6.0
		var d2 := Vector2(0, -sign(sin(a)) * 6.0)
		map.draw_line(cpt, cpt + d1, UiSkin.ACCENT, 2.0)
		map.draw_line(cpt, cpt + d2, UiSkin.ACCENT, 2.0)
	map.draw_arc(hp, 18.0 + 3.0 * sin(t * 5.0), 0.0, TAU, 32, Color(UiSkin.ACCENT, 0.35), 1.0, true)
	var lines: Array = hover.lines
	var bw := 230.0
	var bh := 34.0 + 20.0 * lines.size()
	var bp := hp + Vector2(26, -bh * 0.5)
	if bp.x + bw > map.size.x - 30.0:
		bp.x = hp.x - 26.0 - bw
	var box := Rect2(bp, Vector2(bw * k, bh))
	map.draw_rect(box, Color(0.03, 0.036, 0.046, 0.92 * k))
	map.draw_rect(box, Color(UiSkin.ACCENT, 0.6 * k), false, 1.0)
	map.draw_line(hp + Vector2(sign(bp.x - hp.x) * 14.0, 0), Vector2(bp.x if bp.x > hp.x else bp.x + bw * k, hp.y), Color(UiSkin.ACCENT, 0.5 * k), 1.0)
	if k > 0.6:
		map.draw_string(font, bp + Vector2(12, 22), str(hover.title), HORIZONTAL_ALIGNMENT_LEFT, bw - 20.0, 15, Pal.ink(0.97))
		for n in lines.size():
			map.draw_string(font, bp + Vector2(12, 42 + n * 20), str(lines[n]), HORIZONTAL_ALIGNMENT_LEFT, bw - 20.0, 12, Pal.ink(0.7))


# the hulks under tow (33 号): the flown arc bright, dashes flowing along what is left, the tug
# with its burn behind it
func _draw_tows(day: float, t: float) -> void:
	if not Career.data.has("ship_market"):
		return
	for a in ShipMarket.data().assets:
		if str(a.state) != "towing":
			continue
		var run: Dictionary = a.run
		var k := clampf((day - float(run.depart)) / maxf(ShipMarket.tow_span(a), 0.0001), 0.0, 1.0)
		var col := UiSkin.ACCENT
		var pts := PackedVector2Array()
		for j in 65:
			pts.append(_to(Orbits.on_transfer(run, float(j) / 64.0)))
		for j in 64:
			var u := float(j) / 64.0
			if u < k:
				map.draw_line(pts[j], pts[j + 1], Color(col, 0.75), 2.0, true)
			elif fmod(u * 40.0 - t * 2.0, 1.0) < 0.5:
				map.draw_line(pts[j], pts[j + 1], Color(col, 0.35), 1.4, true)
		var at := _to(Orbits.on_transfer(run, k))
		var back := _to(Orbits.on_transfer(run, maxf(0.0, k - 0.03)))
		var dir := (at - back).normalized() if at != back else Vector2.RIGHT
		map.draw_texture_rect(UiSkin.glow_tex(), Rect2(at - Vector2(18, 18), Vector2(36, 36)), false, Color(col, 0.5))
		map.draw_line(at, at - dir * (14.0 + 4.0 * sin(t * 20.0)), Color(1.0, 0.85, 0.6, 0.8), 2.0, true)
		var tri := PackedVector2Array([at + dir * 7.0, at - dir * 5.0 + dir.orthogonal() * 4.5, at - dir * 5.0 - dir.orthogonal() * 4.5])
		map.draw_colored_polygon(tri, col)
		_label(at, w("%s 拖运中", "%s UNDER TOW") % str(a.id), "", 11, col, Color(), 3)


func _map_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
		if _drag:
			_drag_moved += event.relative.length()
			if _drag_moved > 6.0:
				pan_t -= Vector2(event.relative.x, -event.relative.y) / _k()
		return
	if not (event is InputEventMouseButton):
		return
	if event.pressed:
		_follow_on = false
	if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		# zoom about the pointer: the point under it stays under it
		var under: Vector2 = _from(event.position)
		var nz := clampf(view_zt * (1.18 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.18), 0.7, 7.0)
		var d: Vector2 = (event.position - map.size * 0.5) / (_k0() * nz)
		view_zt = nz
		pan_t = under - Vector2(d.x, -d.y)
		return
	if event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
		view_zt = 1.0
		pan_t = Vector2.ZERO
		return
	if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		if event.pressed:
			_drag = true
			_drag_moved = 0.0
			_drag_at = event.position
			if event.button_index != MOUSE_BUTTON_LEFT:
				_drag_moved = 99.0
			return
		_drag = false
		# a press that did not move is a click
		if event.button_index != MOUSE_BUTTON_LEFT or _drag_moved > 6.0:
			return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if mode == "find":
		_find_click(event.position)
		return
	var best := ""
	var bd := 24.0
	var day := Shipping.day()
	var pp := _to(Orbits.pos(Orbits.PORT, day))
	for s in Shipping.live():
		var at := pp
		if str(s.state) in ["inbound", "leaving"]:
			at = _to(Orbits.on_transfer(s.run, clampf((day - float(s.run.depart)) / float(s.run.tof), 0.0, 1.0)))
		var dd: float = at.distance_to(event.position)
		if dd < bd:
			bd = dd
			best = str(s.id)
	if best != "":
		chosen = best
		_detail()


func close() -> void:
	if on_close.is_valid():
		on_close.call()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


# ---------------------------------------------------------------- finding hulks (68 号)

func _btn(text: String, ok: bool, f: Callable, h := 38) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# user 2026-10-26: a long label ("…拖船站泊位满了（1/1）：先拆掉一艘…") held the whole column
	# wider than the screen — it wraps instead
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = not ok
	b.pressed.connect(f)
	return b


# user 2026-10-28 (截图：“分析 S-003 的电磁特征”和信号行一模一样，像同一种东西): what the page
# does is drawn apart from what it lists — an action is a solid accent button (as Buy on the
# exchange and the ship market), an action that cannot run yet only an outline with its reason;
# the signal and sector rows keep the glass of a list
func _action(b: Button) -> Button:
	UiSkin.accent_button(b)
	var off := StyleBoxFlat.new()
	off.bg_color = Color(0, 0, 0, 0)
	off.border_color = Color(1, 1, 1, 0.16)
	off.set_border_width_all(1)
	off.set_corner_radius_all(12)
	off.set_content_margin_all(12.0)
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_color_override("font_disabled_color", Pal.ink(0.55))
	return b


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _find_detail() -> String:
	var lines: Array = []
	if _note != "":
		lines.append(_note)
	# 107 号: the job's progress is on its own status line, and the how-to only until the first sweep
	# (the next-step line under it says the same thing for the state at hand)
	if Scan.data().sectors.is_empty() and Scan.data().job.is_empty():
		lines.append(w("选一片扇区，点“扫描”。扫完会收到几个信号，有的只是石头；选一个信号“分析电磁特征”，才知道是不是船。", "Pick a sector and sweep it. Some signals are only rock: analyse one to learn whether it is a hulk."))
	if sel_sig != "":
		var s := Scan.sig_of(sel_sig)
		if not s.is_empty():
			lines.append("")
			lines.append("%s · %s" % [str(s.id), Scan.verdict(s)])
			if s.get("known", false) and str(s.kind) == "ship":
				var o: Dictionary = s.offer
				lines.append(w("船坞放得下" if Market.fits(str(o.ship), Career.data) else "船坞放不下：先把船坞扩长", "FITS THE BERTH" if Market.fits(str(o.ship), Career.data) else "TOO LONG FOR THE BERTH"))
	return "\n".join(lines)


func _fill_find() -> void:
	detail.text = _find_detail()
	detail.visible = detail.text != ""
	var found := Scan.found()
	# an analysis just finished: its result stays on the status line a few seconds
	var j: Dictionary = Scan.data().job
	var an := str(j.sig) if str(j.get("kind", "")) == "analyze" else ""
	if _last_an != "" and an != _last_an and Scan.sig_of(_last_an).get("known", false):
		_done_sig = _last_an
		_done_until = Time.get_ticks_msec() + DONE_MS
	_last_an = an
	if _done_sig != "" and (an != "" or Time.get_ticks_msec() >= _done_until):
		_done_sig = ""
	var way := ShipMarket.on_the_way()
	var key := TugYard.status() + "%s|%d|%s|%d|%s|%d|%d|%s|%s|%d|%s" % [str(j.get("kind", "")), sel_sector, sel_sig, found.size(), str(Scan.data().sectors.keys()), int(float(Career.data.get("money", 0.0)) / 100.0), int(Scan.cooldown(sel_sector) > 0.0), _done_sig, str(_sectors_open), way.size(), str(TugYard.taken().map(func(a): return str(a.get("state", ""))))]
	if key == _sig_key:
		return
	_sig_key = key
	for c in find_box.get_children():
		c.queue_free()
	# 107 号 Q5 A (user's screenshot: the tug button was below the fold): on top, what to do next and
	# the one button that does it; the sectors fold to one line once one is picked
	var nx := OpsSkin.label(next_line(), 16, 0.95)
	nx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nx.add_theme_color_override("font_color", UiSkin.ACCENT)
	find_box.add_child(nx)
	var ord := Scan.order()
	if _sectors_open or sel_sector < 0:
		find_box.add_child(OpsSkin.Section.new(w("扇区", "SECTORS")))
		var grid := GridContainer.new()
		_tour_parts.sectors = grid
		grid.columns = 2
		for k in mini(Scan.reach(), ord.size()):
			var i: int = ord[k]
			var tag := w(" · 已扫描", " · SWEPT") if not Scan.sector(i).is_empty() else ""
			var b := _btn(Orbits.name_of(Orbits.station(i)) + tag, true, func(): sel_sector = i; sel_sig = ""; _sectors_open = false; _sig_key = ""; _fill(), 32)
			b.custom_minimum_size.x = 200
			if i == sel_sector:
				b.add_theme_color_override("font_color", UiSkin.ACCENT)
			grid.add_child(b)
		find_box.add_child(grid)
		if Scan.reach() < ord.size():
			find_box.add_child(OpsSkin.label(w("还有 %d 片扇区太远：修好拖船站、贸易区能扫得更远。", "%d MORE SECTORS OUT OF REACH.") % (ord.size() - Scan.reach()), 13, 0.6))
	else:
		# the picked sector on one line; its own button opens the list again
		var tag := w(" · 已扫描", " · SWEPT") if not Scan.sector(sel_sector).is_empty() else w(" · 未扫描", " · UNSWEPT")
		var row := _btn(w("当前扇区：%s%s　　切换扇区 ▾", "SECTOR: %s%s    CHANGE ▾") % [Orbits.name_of(Orbits.station(sel_sector)), tag], true, func(): _sectors_open = true; _sig_key = ""; _fill(), 36)
		row.name = "SectorPicked"
		_tour_parts.sectors = row
		find_box.add_child(row)
	if sel_sector >= 0:
		if str(j.get("kind", "")) == "sweep" and int(j.sector) == sel_sector:
			# the sweep under way here: its status where its button was
			var st := ScanStatus.new()
			find_box.add_child(st)
			_tour_parts.sweep = st
		else:
			var why := Scan.sweep_block(sel_sector)
			# busy with the other job: the button still names its own action, then why it waits
			if Scan.busy():
				why = w("扫描%s附近 · 等“%s”完成", "SWEEP NEAR %s · AFTER %s") % [Orbits.name_of(Orbits.station(sel_sector)), Scan.job_text()]
			var sb := _action(_btn((w("重新扫描 · %s（约 %d 秒）", "SWEEP AGAIN · %s (~%d s)") if not Scan.sector(sel_sector).is_empty() else w("扫描 · %s（约 %d 秒）", "SWEEP · %s (~%d s)")) % [Orbits.name_of(Orbits.station(sel_sector)), int(Scan.SWEEP_S)] if why == "" else why, why == "", func(): Scan.sweep(sel_sector); _sig_key = ""; _fill(), 42))
			find_box.add_child(sb)
			_tour_parts.sweep = sb
		# the signals of that sector, each saying where it stands; a hulk found is its own tug button
		var sigs := Scan.signals(sel_sector)
		if not sigs.is_empty():
			var sec := OpsSkin.Section.new(w("信号", "SIGNALS"))
			find_box.add_child(sec)
			_tour_parts.found = sec
			for s in sigs:
				var id := str(s.id)
				var stt := sig_state(s)
				if str(stt.kind) == "found":
					var sendb := _send_button(int(stt.offer), id)
					find_box.add_child(sendb)
					_tour_parts.found = sendb
					continue
				var txt := "%s · %s" % [id, Scan.verdict(s)]
				if str(stt.get("words", "")) != "":
					txt = "%s · %s · %s" % [id, Scan.type_name(str(s.offer.ship)), str(stt.words)]
				var b := _btn(txt, true, func(): sel_sig = id; _sig_key = ""; _fill(), 32)
				b.name = "Sig_" + id
				if id == sel_sig:
					b.add_theme_color_override("font_color", UiSkin.ACCENT)
				elif str(stt.kind) in ["towing", "arrived", "held"]:
					b.add_theme_color_override("font_color", Color(UiSkin.DATA))
				elif s.get("known", false) and str(s.kind) != "ship":
					b.add_theme_color_override("font_color", Pal.ink(0.5))
				# user 2026-10-28: the one being analysed says so on its own row, a bar along its foot
				if id == an:
					b.add_child(RowBar.new(b, id))
				find_box.add_child(b)
			if an != "" or _done_sig != "":
				# user 2026-10-28 (截图：“正在分析信号 S-001，等它完成”像第三条信号): the analysis under
				# way is a status line under the list — no button, an accent rule and a bar — and says
				# what it found for a few seconds when done
				find_box.add_child(ScanStatus.new(_done_line() if an == "" else ""))
			elif sel_sig != "" and not Scan.sig_of(sel_sig).get("known", false):
				var why2 := Scan.analyze_block(sel_sig)
				find_box.add_child(_gap(6))
				find_box.add_child(_action(_btn(w("分析 %s 的电磁特征（约 %d 秒）", "ANALYSE %s (~%d s)") % [sel_sig, int(Scan.ANALYZE_S)] if why2 == "" else why2, why2 == "", func(): Scan.analyze(sel_sig); _sig_key = ""; _fill(), 42)))
	# 107 号 Q6 A: hulks found in the other sectors (this sector's are on their own rows above)
	var elsewhere: Array = []
	for i in found:
		var o: Dictionary = Career.data.get("offers", [])[i]
		if int(o.get("station", -1)) != sel_sector:
			elsewhere.append(i)
	if not elsewhere.is_empty():
		find_box.add_child(OpsSkin.Section.new(w("别的扇区找到的船", "FOUND IN OTHER SECTORS")))
		for i in elsewhere:
			var o: Dictionary = Career.data.get("offers", [])[i]
			find_box.add_child(_send_button(i, str(o.get("scan_sig", ""))))
	if not way.is_empty():
		var wl := OpsSkin.label(w("在路上 %d 艘 · 最快约 %d 秒", "%d ON THE WAY · FIRST ~%d s") % [way.size(), int(float(way[0].left_s))], 14, 0.8)
		find_box.add_child(wl)
		_tour_parts.way = wl
	var yard := OpsSkin.label(TugYard.status(), 13, 0.65)
	find_box.add_child(yard)
	_tour_parts.yard = yard


var _sectors_open := false


# 107 号 Q6 A: a found hulk's tug button — its signal, its type, the tow's terms and time, or why not
func _send_button(i: int, sig: String) -> Button:
	var o: Dictionary = Career.data.get("offers", [])[i]
	var fits := Market.fits(str(o.ship), Career.data)
	var terms := ShipMarket.tow_terms(o)
	var cash: bool = terms.ok
	var yb := TugYard.block(str(o.ship))
	var who := TugYard.ready_tug()
	var head := ("%s · " % sig if sig != "" else "") + Scan.type_name(str(o.ship))
	var label := w("%s · 派%s去拖 · %s · 约 %d 秒", "%s · SEND %s · %s · ~%d s") % [head, (w("自家拖船 %s", "OUR %s") % who) if who != "" else w("拖船", "THE TUG"), str(terms.text), ShipMarket.quote_s(o)]
	if not fits:
		label = w("%s · 船坞放不下", "%s · TOO LONG FOR THE BERTH") % head
	elif yb != "":
		# the reason is said once, on the next-step line; the row only says it waits
		label = w("%s · 等拖船站空出泊位", "%s · WAITING FOR A TUG-YARD SLOT") % head if TugYard.full() else "%s · %s" % [head, yb]
		fits = false
	elif not cash:
		label = "%s · %s" % [head, str(terms.text)]
	var b := _action(_btn(label, fits and cash, func(): _send(i), 44))
	b.name = "Send_" + (sig if sig != "" else str(i))
	return b


# where an analysed signal stands now: "found" (a tug can go: offer = its index), "towing" / "arrived"
# / "held" (in the tug yard's hands), "done" (stripped or sold), or "" (unknown, rock, debris)
func sig_state(s: Dictionary) -> Dictionary:
	if not s.get("known", false) or str(s.get("kind", "")) != "ship":
		return {"kind": ""}
	var id := str(s.id)
	var offers: Array = Career.data.get("offers", [])
	for i in offers.size():
		if str(offers[i].get("scan_sig", "")) == id and offers[i].get("find", false):
			return {"kind": "found", "offer": i}
	if Career.data.has("ship_market"):
		for a in Career.data.ship_market.get("assets", []):
			if str(a.get("listing", {}).get("offer", {}).get("scan_sig", "")) != id:
				continue
			var st := str(a.get("state", ""))
			match st:
				"towing":
					var left := 0
					for wv in ShipMarket.on_the_way():
						if str(wv.id) == str(a.id):
							left = int(float(wv.left_s))
					return {"kind": "towing", "words": w("拖运途中 · 约 %d 秒到港", "UNDER TOW · ~%d s") % left}
				"arrived":
					return {"kind": "arrived", "words": w("已拖回港 · 在拖船区等着拆", "HOME · WAITING IN THE TUG YARD")}
				"held":
					return {"kind": "held", "words": w("已拖回港 · 港务扣留", "HOME · HELD BY THE PORT")}
				"stripping":
					return {"kind": "done", "words": w("正在船坞里拆", "BEING STRIPPED")}
				_:
					return {"kind": "done", "words": w("已经拆完", "STRIPPED")}
	return {"kind": ""}


func _done_line() -> String:
	var s := Scan.sig_of(_done_sig)
	var line := w("%s 分析完成：%s", "%s ANALYSED: %s") % [_done_sig, Scan.verdict(s)]
	if str(s.get("kind", "")) == "ship":
		line += w(" · 它那一行变成了“派拖船”按钮", " · ITS ROW IS NOW THE TUG BUTTON")
	return line


# user 2026-10-28: the sweep or analysis under way, as status rather than as one more row: no
# button, an accent rule down its left, the words and a thin bar; a finished analysis (done != "")
# shows its result in the data colour, the bar full
class ScanStatus extends MarginContainer:
	var done := ""
	var lbl: Label
	var bar: Control

	func _init(finished := "") -> void:
		done = finished
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_constant_override("margin_left", 14)
		add_theme_constant_override("margin_top", 6)
		add_theme_constant_override("margin_bottom", 8)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl = OpsSkin.label("", 14, 0.9)
		v.add_child(lbl)
		bar = Control.new()
		bar.custom_minimum_size.y = 3
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.draw.connect(_bar)
		v.add_child(bar)
		add_child(v)
		_update()

	func _col() -> Color:
		return UiSkin.DATA if done != "" else UiSkin.ACCENT

	func _update() -> void:
		var j: Dictionary = Scan.data().job
		if done != "":
			lbl.text = done
		elif not j.is_empty():
			lbl.text = Scan.w("%s · %d%% · 还要约 %d 秒", "%s · %d%% · ~%d s LEFT") % [Scan.job_text(), int(Scan.progress() * 100.0), ceili(maxf(0.0, float(j.left)))]
		lbl.add_theme_color_override("font_color", _col())

	func _process(_dt: float) -> void:
		_update()
		bar.queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(0.0, 4.0, 3.0, size.y - 8.0), _col())

	func _bar() -> void:
		var k := 1.0 if done != "" else Scan.progress()
		bar.draw_rect(Rect2(Vector2.ZERO, bar.size), Color(1, 1, 1, 0.08))
		bar.draw_rect(Rect2(Vector2.ZERO, Vector2(bar.size.x * k, bar.size.y)), _col())


# the signal row being analysed: it says "分析中 47%" itself, a bar along its foot
class RowBar extends Control:
	var row: Button
	var id := ""

	func _init(b: Button, sig: String) -> void:
		row = b
		id = sig
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _process(_dt: float) -> void:
		if str(Scan.data().job.get("sig", "")) == id:
			row.text = Scan.w("%s · 分析中 %d%%", "%s · ANALYSING %d%%") % [id, int(Scan.progress() * 100.0)]
		queue_redraw()

	func _draw() -> void:
		var y := size.y - 5.0
		draw_rect(Rect2(10.0, y, size.x - 20.0, 2.0), Color(1, 1, 1, 0.06))
		draw_rect(Rect2(10.0, y, (size.x - 20.0) * Scan.progress(), 2.0), UiSkin.ACCENT)


# 80 号: the find page's next step, in plain words, from the real state of the sweep
func next_line() -> String:
	var job: Dictionary = Scan.data().get("job", {})
	if not job.is_empty():
		return w("下一步：等一下 · %s", "NEXT: WAIT · %s") % Scan.job_text()
	var way := ShipMarket.on_the_way()
	var found := Scan.found()
	var waiting := ""
	if not way.is_empty():
		# 108 号 Q4/Q11: one line; the rest (the terminal pauses the tow, where to start it) is in the tour
		waiting = w("拖船在路上，约 %d 秒到港（关掉星图它才走）。", "THE TUG IS ON ITS WAY, ~%d s (IT FLIES ONCE THIS IS CLOSED).") % int(float(way[0].left_s))
	if not found.is_empty():
		var o: Dictionary = Career.data.get("offers", [])[found[0]]
		var yb := TugYard.block(str(o.ship))
		if yb == "":
			var where := Orbits.name_of(Orbits.station(int(o.get("station", -1)))) if int(o.get("station", -1)) >= 0 else ""
			if int(o.get("station", -1)) == sel_sector or where == "":
				return w("下一步：点 %s 那一行，派拖船去拖（%s）。", "NEXT: CLICK %s'S ROW TO SEND THE TUG (%s).") % [str(o.get("scan_sig", "")), str(ShipMarket.tow_terms(o).text)]
			return w("下一步：%s附近找到的 %s，在下面“别的扇区找到的船”里派拖船去拖（%s）。", "NEXT: THE HULK FOUND NEAR %s (%s): SEND THE TUG BELOW (%s).") % [where, str(o.get("scan_sig", "")), str(ShipMarket.tow_terms(o).text)]
		# the yard full with the one on its way: wait for it, don't point at the tug button
		if waiting != "":
			return waiting + w("拖船站满了，这艘先等。", " THE YARD IS FULL: THIS ONE WAITS.")
		return w("现在派不了拖船：%s", "NO TUG CAN GO NOW: %s") % yb
	if waiting != "":
		return waiting
	if sel_sector >= 0:
		for sg in Scan.signals(sel_sector):
			if not sg.get("known", false):
				return w("下一步：点一个信号（越强越像船），再点“分析”。", "NEXT: PICK A SIGNAL (STRONGER IS LIKELIER), THEN ANALYSE IT.")
		if not Scan.sector(sel_sector).is_empty():
			var cd := Scan.cooldown(sel_sector)
			if cd <= 0.0:
				return w("检测到新目标进入扇区，请重新扫描。", "NEW TARGETS IN THE SECTOR: SWEEP AGAIN.")
			return w("这片没有船。约 %d 秒后有新东西漂进来，或换一片扫。", "NO HULK HERE. NEW DRIFT IN ~%d s, OR SWEEP ANOTHER.") % ceili(cd)
	return w("下一步：选一片扇区（最近的已选好），点“扫描”。", "NEXT: PICK A SECTOR (THE NEAREST IS PICKED), SWEEP IT.")


# 80 号 Q3 A: the first time the page opens, its parts light up one by one, a line each
var _tour_parts := {}
var _tour_i := -1
var _tour_layer: Control


func _tour_steps() -> Array:
	if _tour_kind == "tow":
		var way := ShipMarket.on_the_way()
		var left := int(float(way[0].left_s)) if not way.is_empty() else 0
		return [
			["tow", w("拖船在这里", "THE TUG"), w("它沿虚线飞到那艘船，挂上缆，拖着它沿原路回港。实线是走过的路。", "It flies the dashes to the hulk, takes it in tow and brings it home the same way. The solid line is behind it.")],
			["way", w("还有多久到港", "TIME TO PORT"), w("这一行一直在倒数，现在约 %d 秒。" % left, "This line counts down: about %d s now." % left)],
			["close", w("关掉星图，拖船照样飞", "CLOSE IT: THE TUG FLIES ON"), w("到港时屏幕上方弹一张卡，按 %s 打开终端，在它的卡上点“开工拆”。（只有终端打开时游戏暂停）" % Keys.label("terminal"), "When it docks a card pops up top; %s opens the terminal on its card: start stripping. (Only the terminal pauses the game.)" % Keys.label("terminal"))],
		]
	return [
		["map", w("太阳和小行星带", "THE SUN AND THE BELT"), w("没人要的废船都漂在小行星带里。左边这张图就是太阳系：中间是太阳，那一圈是小行星带，亮点是各个站。", "Abandoned hulks drift in the asteroid belt. This is the system: the sun in the middle, the belt around it, the stations as points.")],
		["sectors", w("扇区", "SECTORS"), w("小行星带分成一片一片。开局只能扫离港最近的 3 片，修好拖船站、贸易区能扫得更远。", "The belt is cut into sectors. At first only the 3 nearest can be swept; the tug station and the trade district reach further.")],
		["sweep", w("扫描", "SWEEP"), w("向选中的扇区发一道雷达波，约 %d 秒，不花钱。" % int(Scan.SWEEP_S), "A radar sweep over the picked sector: about %d s, free." % int(Scan.SWEEP_S))],
		["inset", w("信号点", "SIGNALS"), w("扫完出现几个信号，只知道强弱：可能是船，也可能只是石头。", "A few signals show up, strength only: a hulk, or just rock.")],
		["sweep", w("分析电磁特征", "ANALYSE"), w("点一个信号再点“分析电磁特征”（约 %d 秒）：看清是不是船、多长、漂了多少年、拖回来要多少钱。" % int(Scan.ANALYZE_S), "Pick a signal and analyse it (~%d s): whether it is a hulk, how long, how old, what the tow costs." % int(Scan.ANALYZE_S))],
		["found", w("派拖船", "SEND THE TUG"), w("认出是船的那一行会变成“派拖船去拖”按钮。点它，星图上看得见拖船飞过去、拖着船回来。第一趟免费。", "A signal analysed as a hulk becomes a tug button. Click it and watch the tug fly out and tow it home. The first is free.")],
		["yard", w("拖船站泊位", "TUG YARD"), w("港里能停几艘等着拆的船。满了就要先拆完一艘，或扩建拖船站。", "How many hulks can wait at the port. Full, strip one first or extend the tug station.")],
	]


func _tour_rect(part: String) -> Rect2:
	if part == "tow":
		var au := _tow_au(follow)
		if au.is_finite():
			return Rect2(map.get_global_rect().position + _to(au) - Vector2(46, 46), Vector2(92, 92))
		return map.get_global_rect()
	if part == "map":
		return map.get_global_rect()
	if part == "inset":
		var r := _inset_rect()
		return Rect2(map.get_global_rect().position + r.position, r.size)
	var c = _tour_parts.get(part)
	if c != null and is_instance_valid(c) and c.is_visible_in_tree():
		return c.get_global_rect()
	return find_box.get_global_rect()


func start_tour() -> void:
	_tour_i = clampi(Career.guide_at(_tour_kind + "_tour"), 0, _tour_steps().size() - 1)
	if _tour_layer == null:
		_tour_layer = Control.new()
		_tour_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_tour_layer.mouse_filter = Control.MOUSE_FILTER_STOP
		_tour_layer.draw.connect(_draw_tour)
		_tour_layer.gui_input.connect(_tour_click)
		add_child(_tour_layer)
	_tour_layer.visible = true
	_tour_layer.queue_redraw()


func _tour_click(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	# user 2026-10-26: a click on the lit part does what it says (the button under it is really
	# pressed — a sector picked, the sweep started, the tug sent), then the tour goes on
	var at: Vector2 = _tour_layer.get_global_mouse_position()
	if _tour_i >= 0 and _tour_rect(str(_tour_steps()[_tour_i][0])).has_point(at):
		for b in find_box.find_children("*", "Button", true, false):
			if b.is_visible_in_tree() and not b.disabled and b.get_global_rect().has_point(at):
				b.pressed.emit()
				break
	_tour_next()


func tour_on() -> bool:
	return _tour_i >= 0


func _tour_next() -> void:
	_tour_i += 1
	if _tour_i >= _tour_steps().size():
		_tour_end()
		return
	Career.guide_keep(_tour_kind + "_tour", _tour_i)
	if _tour_layer != null:
		_tour_layer.queue_redraw()


func _tour_end() -> void:
	_tour_i = -1
	if _tour_layer != null:
		_tour_layer.visible = false
	var seen: Dictionary = Career.data.get("seen", {})
	seen["tow_tour" if _tour_kind == "tow" else "starmap_tour"] = true
	_tour_kind = "find"
	Career.data.seen = seen
	Career.save()


func _draw_tour() -> void:
	if _tour_i < 0:
		return
	var st: Array = _tour_steps()[_tour_i]
	var r := _tour_rect(str(st[0])).grow(8.0)
	var s := _tour_layer.size
	# hdr_2d blends in linear light: 0.62 barely darkened anything
	var dim := Color(0, 0, 0, 0.85)
	# everything dark but the part
	_tour_layer.draw_rect(Rect2(0, 0, s.x, r.position.y), dim)
	_tour_layer.draw_rect(Rect2(0, r.end.y, s.x, s.y - r.end.y), dim)
	_tour_layer.draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), dim)
	_tour_layer.draw_rect(Rect2(r.end.x, r.position.y, s.x - r.end.x, r.size.y), dim)
	_tour_layer.draw_rect(r, UiSkin.ACCENT, false, 2.0)
	# the caption beside it: left of a part in the right column, else below it
	var cw := 420.0
	var ch := 150.0
	var at := Vector2(r.position.x - cw - 24.0, r.position.y) if r.position.x > s.x * 0.5 else Vector2(r.position.x + 24.0, r.end.y + 16.0)
	at.y = clampf(at.y, 20.0, s.y - ch - 20.0)
	at.x = clampf(at.x, 20.0, s.x - cw - 20.0)
	var box := Rect2(at, Vector2(cw, ch))
	_tour_layer.draw_rect(box, Color(0.09, 0.105, 0.12, 0.97))
	_tour_layer.draw_rect(Rect2(box.position, Vector2(3, box.size.y)), UiSkin.ACCENT)
	var f := Fonts.get_font("Medium")
	_tour_layer.draw_string(f, at + Vector2(18, 30), "%d / %d  %s" % [_tour_i + 1, _tour_steps().size(), str(st[1])], HORIZONTAL_ALIGNMENT_LEFT, cw - 36, 19, UiSkin.ACCENT)
	_tour_layer.draw_multiline_string(f, at + Vector2(18, 58), str(st[2]), HORIZONTAL_ALIGNMENT_LEFT, cw - 36, 15, -1, Pal.ink(0.88))
	_tour_layer.draw_string(f, at + Vector2(18, ch - 14), w("点一下或按空格：下一项 · Esc 跳过", "CLICK OR SPACE: NEXT · ESC SKIPS"), HORIZONTAL_ALIGNMENT_LEFT, cw - 36, 12, Pal.ink(0.55))


func _input(event: InputEvent) -> void:
	if _tour_i < 0 or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		_tour_end()
	else:
		_tour_next()
	get_viewport().set_input_as_handled()


func _send(i: int) -> void:
	var oid := str(Career.data.get("offers", [])[i].get("id", "")) if i < Career.data.get("offers", []).size() else ""
	var r := ShipMarket.tow_find(i)
	if r.ok:
		watch_tow(oid)
		_note = w("拖船出发了。", "THE TUG IS OFF.")
		if r.get("owe", 0.0) > 0.0:
			_note += w(" 拖运费 %s 先赊着，下次结算扣。", " THE %s TOW IS ON CREDIT TILL THE NEXT SETTLEMENT.") % Pal.money(float(r.owe))
		if game != null and game.get("sfx") != null:
			game.sfx.play("menu")
	else:
		_note = str(r.reason)
	_sig_key = ""
	_fill_find.call_deferred()


func _sig_at(s: Dictionary, day: float) -> Vector2:
	var sp := Orbits.pos(Orbits.station(int(s.sector)), day)
	return _to(sp + Vector2(float(s.off[0]), float(s.off[1])))


func _draw_find(day: float, pp: Vector2) -> void:
	var ord := Scan.order()
	var rr := 0.17 * _k()
	var t := Time.get_ticks_msec() / 1000.0
	for k in ord.size():
		var i: int = ord[k]
		var at := _to(Orbits.pos(Orbits.station(i), day))
		var reach := k < Scan.reach()
		if i == sel_sector:
			# the chosen sector: a dashed ring turning, and a soft wash inside
			map.draw_circle(at, rr, Color(UiSkin.ACCENT, 0.05))
			for n in 24:
				var a0 := TAU * n / 24.0 + t * 0.3
				map.draw_arc(at, rr, a0, a0 + TAU / 48.0, 4, UiSkin.ACCENT, 2.0, true)
			map.draw_arc(at, rr + 6.0, t * -0.2, t * -0.2 + PI * 0.5, 16, Color(UiSkin.ACCENT, 0.6), 1.0, true)
		else:
			map.draw_arc(at, rr, 0.0, TAU, 40, Color(UiSkin.DATA, 0.4) if reach else Pal.ink(0.08), 1.0, true)
	# the sweep: a radar wavefront from the port across to the sector
	var j: Dictionary = Scan.data().job
	if not j.is_empty():
		var at := _to(Orbits.pos(Orbits.station(int(j.sector)), day))
		var k := Scan.progress()
		if str(j.kind) == "sweep":
			var dir := (at - pp).normalized()
			var dist := pp.distance_to(at)
			for n in 4:
				var kk := fmod(k * 3.0 + n / 4.0, 1.0)
				var cpt := pp + dir * dist * kk
				var a0 := dir.angle()
				map.draw_arc(pp, dist * kk, a0 - 0.18, a0 + 0.18, 16, Color(UiSkin.DATA, 0.8 * (1.0 - kk)), 2.0, true)
				map.draw_circle(cpt, 2.5, Color(UiSkin.DATA, 0.9 * (1.0 - kk * 0.6)))
			map.draw_line(pp, at, Color(UiSkin.DATA, 0.18), 1.0, true)
			map.draw_arc(at, rr * (0.3 + 0.7 * fmod(k * 3.0, 1.0)), 0.0, TAU, 40, Color(UiSkin.DATA, 0.8), 2.0, true)
		else:
			map.draw_line(pp, at, Color(UiSkin.ACCENT, 0.4), 1.0, true)
	# the signals on the big map
	for key in Scan.data().sectors:
		for sg in Scan.data().sectors[key].sigs:
			var at := _sig_at(sg, day)
			var col := UiSkin.ACCENT if sg.get("known", false) and str(sg.kind) == "ship" else (UiSkin.DATA if not sg.get("known", false) else Pal.ink(0.35))
			map.draw_circle(at, 2.0, col)
	_inset_goal = _inset_target(day, pp)
	_flush_labels()
	_draw_inset(day)


const INSET_PX := 1100.0       # inset pixels per AU of offset from the station
const DRIFT_AU := 0.012        # how far a signal wanders round its place (user 2026-10-26: live, not fixed)


const INSET_SIZE := Vector2(400, 320)
var _inset_pos := Vector2(48, 48)
var _inset_goal := Vector2(48, 48)


func _inset_rect() -> Rect2:
	return Rect2(_inset_pos, INSET_SIZE)


# 107 号 Q5 A (user's screenshot: the inset sat on the stations at the top left): the corner of the
# chart that covers least — the picked sector most of all, then the port, the stations, the planets;
# it keeps its corner unless another is clearly better, and glides there
func _inset_target(day: float, pp: Vector2) -> Vector2:
	var m := 28.0
	var corners := [Vector2(m, m), Vector2(map.size.x - INSET_SIZE.x - m, m), Vector2(m, map.size.y - INSET_SIZE.y - m), Vector2(map.size.x - INSET_SIZE.x - m, map.size.y - INSET_SIZE.y - m)]
	var pts: Array = [[pp, 6.0]]
	for i in Orbits.STATIONS.size():
		pts.append([_to(Orbits.pos(Orbits.STATIONS[i], day)), 30.0 if i == sel_sector else 2.0])
	for el in Orbits.PLANETS:
		var q := Orbits.pos(el, day)
		if q.length() <= SCALE_AU:
			pts.append([_to(q), 1.0])
	pts.append([_to(Vector2.ZERO), 3.0])
	var best := _inset_goal
	var best_cost := INF
	for c in corners:
		var r := Rect2(c, INSET_SIZE).grow(24.0)
		var cost := 0.0
		for q in pts:
			if r.has_point(q[0]):
				cost += float(q[1])
		if c.distance_to(_inset_goal) < 1.0:
			cost -= 1.5
		if cost < best_cost:
			best_cost = cost
			best = c
	return best


# ---------------------------------------------------------------- labels (107 号 Q5 A)
# every name on the chart goes through here: placed beside its point where it covers no other
# label, point or the inset; the least important ones give way when the chart is crowded, and a
# label pushed off its point keeps a thin leader to it
var _labels: Array = []


func _label(at: Vector2, text: String, sub: String, size: int, col: Color, sub_col: Color, prio: int, gap := 9.0) -> void:
	_labels.append({"at": at, "text": text, "sub": sub, "size": size, "col": col, "sub_col": sub_col, "prio": prio, "gap": gap})


func _flush_labels() -> void:
	var taken: Array = []
	if mode == "find" and sel_sector >= 0:
		taken.append(_inset_rect().grow(6.0))
	for L in _labels:
		taken.append(Rect2(L.at - Vector2(6, 6), Vector2(12, 12)))
	_labels.sort_custom(func(x, y): return int(x.prio) > int(y.prio))
	var bounds := Rect2(Vector2.ZERO, map.size).grow(-6.0)
	for L in _labels:
		var tw := font.get_string_size(str(L.text), HORIZONTAL_ALIGNMENT_LEFT, -1, int(L.size)).x
		var sw := font.get_string_size(str(L.sub), HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x if str(L.sub) != "" else 0.0
		var sz := Vector2(maxf(tw, sw) + 4.0, float(L.size) + 4.0 + (13.0 if str(L.sub) != "" else 0.0))
		var g: float = L.gap
		var cands := [Vector2(g, -sz.y + 2.0), Vector2(g, 2.0), Vector2(-sz.x - g, -sz.y + 2.0), Vector2(-sz.x - g, 2.0),
			Vector2(-sz.x * 0.5, g + 2.0), Vector2(-sz.x * 0.5, -sz.y - g),
			Vector2(g + 22.0, -sz.y - 16.0), Vector2(-sz.x - g - 22.0, -sz.y - 16.0), Vector2(g + 22.0, 18.0), Vector2(-sz.x - g - 22.0, 18.0)]
		var pick := -1
		var rect := Rect2()
		for ci in cands.size():
			var r := Rect2(L.at + cands[ci], sz)
			if not bounds.encloses(r):
				continue
			var hit := false
			for q in taken:
				if q.intersects(r) and not q.has_point(L.at):
					hit = true
					break
			if not hit:
				pick = ci
				rect = r
				break
		if pick < 0:
			# crowded: a minor label gives way; a major one goes on its first place regardless
			if int(L.prio) <= 2:
				continue
			pick = 0
			rect = Rect2(L.at + cands[0], sz)
		taken.append(rect.grow(2.0))
		if pick >= 6:
			var to := Vector2(clampf(L.at.x, rect.position.x, rect.end.x), clampf(L.at.y, rect.position.y, rect.end.y))
			map.draw_line(L.at, to, Color(L.col, 0.35), 1.0, true)
		map.draw_string(font, rect.position + Vector2(2, float(L.size)), str(L.text), HORIZONTAL_ALIGNMENT_LEFT, -1, int(L.size), L.col)
		if str(L.sub) != "":
			map.draw_string(font, rect.position + Vector2(2, float(L.size) + 13.0), str(L.sub), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, L.sub_col)


# a signal drifts on its own slow path: where it is now, AU from its station
func _drift(sg: Dictionary) -> Vector2:
	var t := Time.get_ticks_msec() / 1000.0
	var h := float(hash(str(sg.get("id", ""))) % 1000) / 1000.0 * TAU
	return Vector2(sin(t * 0.06 + h), cos(t * 0.045 + h * 1.7)) * DRIFT_AU


func _inset_at(sg: Dictionary) -> Vector2:
	var r := _inset_rect()
	var off := Vector2(float(sg.off[0]), float(sg.off[1])) + _drift(sg)
	return Vector2(r.get_center().x, r.get_center().y + 14.0) + Vector2(off.x, -off.y) * INSET_PX


func _draw_inset(day: float) -> void:
	if sel_sector < 0:
		return
	var r := _inset_rect()
	var t := Time.get_ticks_msec() / 1000.0
	map.draw_rect(r, Color(0.02, 0.026, 0.032, 0.98))
	map.draw_rect(r, Color(UiSkin.DATA, 0.35), false, 1.0)
	map.draw_string(font, r.position + Vector2(16, 26), w("%s · 局部雷达", "%s · LOCAL RADAR") % Orbits.name_of(Orbits.station(sel_sector)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.8))
	var c := Vector2(r.get_center().x, r.get_center().y + 14.0)
	var R := 136.0
	# the scope: range rings, a cross, ticks round the rim
	for n in 4:
		map.draw_arc(c, R * (n + 1) / 4.0, 0.0, TAU, 64, Color(UiSkin.DATA, 0.08 if n < 3 else 0.3), 1.0, true)
	map.draw_line(c + Vector2(-R, 0), c + Vector2(R, 0), Color(UiSkin.DATA, 0.07), 1.0)
	map.draw_line(c + Vector2(0, -R), c + Vector2(0, R), Color(UiSkin.DATA, 0.07), 1.0)
	for d in range(0, 360, 10):
		var a := deg_to_rad(float(d))
		map.draw_line(c + Vector2(cos(a), sin(a)) * R, c + Vector2(cos(a), sin(a)) * (R - (8.0 if d % 30 == 0 else 4.0)), Color(UiSkin.DATA, 0.4), 1.0)
	# the sweep line: always turning, fast while a sweep runs, with its afterglow
	var j: Dictionary = Scan.data().job
	var sweeping: bool = not j.is_empty() and str(j.kind) == "sweep" and int(j.sector) == sel_sector
	var ang := (Scan.progress() * TAU * 3.0) if sweeping else fmod(t * 0.9, TAU)
	var glow := 26 if sweeping else 14
	for n in glow:
		var a2 := ang - n * 0.045
		map.draw_line(c, c + Vector2(cos(a2), sin(a2)) * R, Color(UiSkin.DATA, (0.5 if sweeping else 0.22) * (1.0 - float(n) / glow)), 2.0, true)
	map.draw_line(c, c + Vector2(cos(ang), sin(ang)) * R, Color(UiSkin.DATA, 0.95 if sweeping else 0.5), 1.6, true)
	# the station at the centre
	var dia := PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0), c + Vector2(0, -6)])
	map.draw_polyline(dia, Pal.ink(0.85), 1.4, true)
	map.draw_string(font, c + Vector2(10, -8), Orbits.name_of(Orbits.station(sel_sector)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.55))
	if sweeping:
		map.draw_string(font, r.position + Vector2(16, r.size.y - 14), w("扫描中 %d%%", "SWEEPING %d%%") % int(Scan.progress() * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiSkin.DATA)
	# new drift: a swept sector whose quiet time is over has echoes coming in from the rim
	if not Scan.sector(sel_sector).is_empty() and Scan.cooldown(sel_sector) <= 0.0 and not sweeping:
		for n in 3:
			var a3 := TAU * (n / 3.0) + 0.6
			var kk := fmod(t * 0.12 + n * 0.33, 1.0)
			var p := c + Vector2(cos(a3), sin(a3)) * R * (1.05 - 0.45 * kk)
			map.draw_circle(p, 2.5, Color(UiSkin.DATA, 0.7 * (1.0 - kk)))
			map.draw_line(p, p + Vector2(cos(a3), sin(a3)) * 14.0, Color(UiSkin.DATA, 0.3 * (1.0 - kk)), 1.0)
		map.draw_string(font, r.position + Vector2(16, r.size.y - 14), w("检测到新目标 · 建议重新扫描", "NEW TARGETS · SWEEP AGAIN"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiSkin.DATA)
	for sg in Scan.signals(sel_sector):
		var at := _inset_at(sg)
		var on := str(sg.id) == sel_sig
		# a blip lights as the sweep line passes and fades after it
		var bearing := (at - c).angle()
		var since := fposmod(ang - bearing, TAU)
		var lit := clampf(1.0 - since / 2.5, 0.25, 1.0)
		if not sg.get("known", false):
			var st := float(sg.strength)
			map.draw_texture_rect(UiSkin.glow_tex(), Rect2(at - Vector2(14, 14), Vector2(28, 28)), false, Color(UiSkin.DATA, 0.45 * lit))
			map.draw_circle(at, 2.5 + st * 3.5, Color(UiSkin.DATA, lit))
			var pulse := fmod(t * 0.8 + st, 1.0)
			map.draw_arc(at, 6.0 + pulse * 12.0 * st, 0.0, TAU, 24, Color(UiSkin.DATA, 0.5 * (1.0 - pulse)), 1.0, true)
		elif str(sg.kind) == "ship":
			var tri := PackedVector2Array([at + Vector2(0, -8), at + Vector2(7, 7), at + Vector2(-7, 7)])
			map.draw_texture_rect(UiSkin.glow_tex(), Rect2(at - Vector2(16, 16), Vector2(32, 32)), false, Color(UiSkin.ACCENT, 0.5))
			map.draw_colored_polygon(tri, UiSkin.ACCENT)
		else:
			map.draw_circle(at, 3.5, Pal.ink(0.35 + 0.2 * lit))
		if not j.is_empty() and str(j.kind) == "analyze" and str(j.sig) == str(sg.id):
			map.draw_arc(at, 16.0, -PI * 0.5, -PI * 0.5 + TAU * Scan.progress(), 32, UiSkin.ACCENT, 2.5, true)
			map.draw_arc(at, 22.0, t * 4.0, t * 4.0 + 1.2, 12, Color(UiSkin.ACCENT, 0.6), 1.0, true)
		if on:
			for q in 4:
				var a4 := q * PI * 0.5 + PI * 0.25
				var e := at + Vector2(cos(a4), sin(a4)) * 14.0
				map.draw_line(e, e + Vector2(cos(a4), sin(a4)) * 6.0, UiSkin.ACCENT, 2.0)
		# 127 号: "S-002 · 磐石级维修拖船" once analysed
		var nm := Scan.short_name(sg)
		map.draw_string(font, at + Vector2(10, -6), str(sg.id) + (" · " + nm if nm != "" else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiSkin.ACCENT if str(sg.kind) == "ship" and sg.get("known", false) else Pal.ink(0.75))


func _find_click(p: Vector2) -> void:
	var day := Shipping.day()
	var best := ""
	var bd := 18.0
	if sel_sector >= 0 and _inset_rect().has_point(p):
		for s in Scan.signals(sel_sector):
			var dd := _inset_at(s).distance_to(p)
			if dd < bd:
				bd = dd
				best = str(s.id)
		if best != "":
			sel_sig = best
			_sig_key = ""
			_fill()
		return
	if best != "":
		sel_sig = best
		sel_sector = int(Scan.sig_of(best).sector)
	else:
		var ord := Scan.order()
		var bs := -1
		var bsd := 0.17 * _k()
		for k in mini(Scan.reach(), ord.size()):
			var dd := _to(Orbits.pos(Orbits.station(int(ord[k])), day)).distance_to(p)
			if dd < bsd:
				bsd = dd
				bs = int(ord[k])
		if bs < 0:
			return
		sel_sector = bs
		sel_sig = ""
	_sig_key = ""
	_fill()
