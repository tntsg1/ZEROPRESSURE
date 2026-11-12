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
const Back := preload("res://scripts/ui_back.gd")
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
# user 2026-11-05 (截图：“约 12 秒到港”一直不变): texts that count down are set again in place, the page
# is not rebuilt for them; a hulk docking makes its row flash and a line say where to go
var _live: Array = []            # [control, Callable → its text now]
var _tow_was := {}               # signal id → true while its hulk was under tow at the last look
var _docked_at := {}             # signal id → msec it docked
var _dock_sig := ""              # the one the "docked" line is about
var _dock_until := 0
const DOCK_MS := 8000
const DOCK_FLASH_S := 1.6
const SCALE_AU := 3.7          # AU from the Sun to the map's edge (Jupiter drawn at the rim)
const Fx := preload("res://scripts/star_map_fx.gd")
const Mo := preload("res://scripts/star_map_motion.gd")
# the chart's layers, bottom up (2026-11-04): space, belt, orbits, fx are GPU and never redrawn on
# the CPU (only their uniforms change); _top, _inset_top and _ptr are the few things drawn per frame
var cv: Control                 # the layer being drawn into right now
var _bg: ColorRect
var _belt: MeshInstance2D
var _orbit_nodes: Array = []    # [el, MeshInstance2D, kind ("planet" | "station" | "port"), index]
var _fx: ColorRect
var _top: Control
var _inset_bg: ColorRect
var _inset_top: Control
var _ptr: Control
var _rip: Array = []            # click ripples: [pos, born ticks s]
var _sel_t := 9.0               # seconds since the sector was picked (its ring lands)
var _sel_was := -2
var _open_t := 0.0              # seconds since the map opened
var _t := 0.0
var _par_m := Vector2.ZERO
# #012: when each signal turned from unknown to known (ticks s); one already known when first seen
# has no entry and is drawn in its final shape
var _sig_seen := {}
var _known_at := {}
# #012: the hover lock, circle reticle <-> bracket box
var _lock_on := false
var _lock_key := ""
var _lock_pos := Vector2.ZERO
var _lock_s := 9.0
var _lock_from := 0.0          # the morph's progress when it turned round
# #004: when each tow's route started drawing on (ticks s)
var _tow_seen := {}
var _card_clip: Control
var _card_ink: Control
var _rv_clip: Control
var _rv_ink: Control


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ready() -> void:
	Back.arrive()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font = Fonts.get_font("Medium")
	# 54 号: the new skin's ground under the map
	add_child(UiSkin.Ground.new())
	# 2026-11-04: the whole screen is space (the panel floats over it); the chart's layers are GPU
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.material = Fx.material("space")
	add_child(_bg)
	map = Control.new()
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.offset_right = -520
	map.gui_input.connect(_map_input)
	add_child(map)
	_build_layers()
	var accent := Pal.tint(Pal.AIR, 1.0, 1.2)
	var column := OpsSkin.pane(self, accent, 460.0)
	column.add_child(OpsSkin.Plate.new("NAV-3", w("星图", "STAR MAP"), w("日心轨道 · 1 秒 = %.1f 天", "HELIOCENTRIC · 1 s = %.1f DAYS") % Orbits.DAYS_PER_S, accent))
	var tabs := HBoxContainer.new()
	tab_find = Button.new()
	tab_find.text = w("找船", "FIND HULKS")
	tab_find.toggle_mode = true
	tab_find.custom_minimum_size.y = 40
	tab_find.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_find.pressed.connect(func(): set_mode("find"))
	tab_ships = Button.new()
	tab_ships.text = w("航运", "SHIPPING")
	tab_ships.toggle_mode = true
	tab_ships.custom_minimum_size.y = 40
	tab_ships.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_ships.pressed.connect(func(): set_mode("ships"))
	tabs.add_child(tab_find)
	tabs.add_child(tab_ships)
	var market_b := _btn(w("二手船市", "HULK MARKET"), ShipMarket.open() and game != null, _open_hulk_market, 40)
	market_b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if market_b.disabled:
		market_b.tooltip_text = w("修好贸易港后开放", "OPENS ONCE THE TRADE PORT IS MENDED")
	tabs.add_child(market_b)
	# the chosen tab's line slides across under it
	_tab_ink = Control.new()
	_tab_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_ink.draw.connect(_draw_tab_line)
	tab_find.add_child(_tab_ink)
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
	close_b.text = Back.close_text()
	close_b.custom_minimum_size.y = 42
	close_b.pressed.connect(_back)
	column.add_child(close_b)
	_tour_parts.close = close_b
	for b in [tab_find, tab_ships, close_b]:
		_sheen(b)
	_enter_column()
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
			return _path_at(_tow_path(a), k)
	return Vector2.INF


# user 2026-11-10 (截图：回港航线绕了大半圈，箭头停在空白处，零压港在别处): the tug flies a shortened span
# (ShipMarket.tow_span: the first tow at most FIRST_S), but a.run is the arc worked out for the true
# flight, which ends on the port's place run.tof days on. The route drawn is the arc flown: from the
# hulk's station on the departure day to the port on the day the tug docks, in exactly the span.
var _tow_paths := {}


func _tow_path(a: Dictionary) -> Dictionary:
	var run: Dictionary = a.run
	var span := ShipMarket.tow_span(a)
	var key := "%s@%s@%s" % [str(a.id), str(run.depart), str(span)]
	if _tow_paths.has(key):
		return _tow_paths[key]
	var arr := Orbits.pos(Orbits.PORT, float(run.depart) + span)
	var path := {}
	if span > 0.0:
		var v := Orbits.lambert(run.r1, [arr.x, arr.y], span)
		if is_finite(v[0]) and is_finite(v[1]):
			var end := Orbits.propagate(run.r1, [v[0], v[1]], span)
			if Vector2(end[0] - arr.x, end[1] - arr.y).length() < 1e-3:
				path = {"r1": run.r1, "v1": [v[0], v[1]], "tof": span, "depart": float(run.depart)}
	if path.is_empty():
		# no clean arc in that time: the true arc bent so that its ends are the station and the port
		var e := Orbits.on_transfer(run, 1.0)
		path = {"r1": run.r1, "v1": run.v1, "tof": float(run.tof), "depart": float(run.depart), "warp": [arr.x - e.x, arr.y - e.y]}
	_tow_paths[key] = path
	return path


# a point a share u of the way along a route (an arc, or an arc bent onto its ends)
func _path_at(run: Dictionary, u: float) -> Vector2:
	var p := Orbits.on_transfer(run, u)
	if run.has("warp"):
		p += Vector2(float(run.warp[0]), float(run.warp[1])) * clampf(u, 0.0, 1.0)
	return p


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
		_tour_tick()
		_tour_layer.queue_redraw()
	view_z = lerpf(view_z, view_zt, e)
	_inset_pos = _inset_pos.lerp(_inset_goal, 1.0 - exp(-7.0 * dt))
	pan = pan.lerp(pan_t, e)
	_hover_t += dt
	_open_t += dt
	_sel_t += dt
	if sel_sector != _sel_was:
		if _sel_was != -2 and sel_sector >= 0:
			_sfx("starmap_sector")
		_sel_was = sel_sector
		_sel_t = 0.0
	if sel_sig != _sig_was:
		if sel_sig != "":
			_sfx("starmap_signal")
		_sig_was = sel_sig
	# the job's own sounds: a sweep or an analysis starting and landing
	var jk := str(Scan.data().job.get("kind", ""))
	if jk != _job_was:
		if jk == "sweep":
			_sfx("starmap_sweep")
		elif jk == "analyze":
			_sfx("starmap_analyze")
		if _job_was == "sweep":
			_sfx("starmap_sweep_done")
		_job_was = jk
	_tab_ink.queue_redraw()
	_list_t += dt
	if _list_t > 0.5:
		_list_t = 0.0
		_fill()
	_watch_signals()
	_update_lock(dt)
	_push_fx()
	_push_sheens()
	_top.queue_redraw()
	_inset_top.queue_redraw()
	_ptr.queue_redraw()


# a box that clips what its child draws (a control's clip_contents does not clip its own drawing)
func _clip(parent: Node) -> Control:
	var c := Control.new()
	c.clip_contents = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.visible = false
	parent.add_child(c)
	return c


func _layer(parent: Node, f: Callable) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(f)
	parent.add_child(c)
	return c


func _build_layers() -> void:
	_dressing_init()
	_belt = MeshInstance2D.new()
	_belt.mesh = Fx.belt_mesh(_belt_rocks)
	_belt.material = Fx.material("belt")
	map.add_child(_belt)
	var orbits := Node2D.new()
	map.add_child(orbits)
	var add := func(el: Array, kind: String, i: int):
		var mi := MeshInstance2D.new()
		mi.mesh = Fx.orbit_mesh(el)
		mi.material = Fx.material("orbit")
		orbits.add_child(mi)
		_orbit_nodes.append([el, mi, kind, i])
	for el in Orbits.PLANETS:
		if Orbits.pos(el, 0.0).length() <= SCALE_AU * 1.1:
			add.call(el, "planet", -1)
	for i in Orbits.STATIONS.size():
		add.call(Orbits.STATIONS[i], "station", i)
	add.call(Orbits.PORT, "port", -1)
	_fx = ColorRect.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.material = Fx.material("chart")
	map.add_child(_fx)
	_top = _layer(map, _draw_map)
	_inset_bg = ColorRect.new()
	_inset_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inset_bg.material = Fx.material("radar")
	_inset_bg.visible = false
	map.add_child(_inset_bg)
	_inset_top = _layer(map, _draw_inset_top)
	_rv_clip = _clip(map)
	_rv_ink = _layer(_rv_clip, _draw_rv_ink)
	_ptr = _layer(map, _draw_ptr)
	_card_clip = _clip(map)
	_card_ink = _layer(_card_clip, _draw_card_ink)


func _uni(m: ShaderMaterial, kv: Dictionary) -> void:
	for key in kv:
		m.set_shader_parameter(key, kv[key])


# every GPU layer's uniforms for this frame: the view, the clock, the pointer, the sweep
func _push_fx() -> void:
	var t := Mo.ms() / 1000.0
	var day := Shipping.day()
	var sun := _to(Vector2.ZERO)
	var k := _k()
	var on_map := not (mouse.x < 24.0 or mouse.y < 24.0 or mouse.x > map.size.x - 24.0 or mouse.y > map.size.y - 24.0 or (mode == "find" and sel_sector >= 0 and _inset_rect().has_point(mouse)))
	var m_px := mouse if on_map else Vector2(-99999, -99999)
	# depth: the chart's pan in pixels and a little of the pointer, the near stars moving most
	# #016 parallax: the camera's pan (the chart's drag and the pointer, ±108 px across the chart),
	# each star layer moving by pan × its factor in the shader
	var aim := Vector2.ZERO
	if mouse.x > -9999.0:
		aim = ((mouse - map.size * 0.5) / (map.size * 0.5)).clampf(-1.0, 1.0) * -Mo.PAN_PX
	_par_m = _par_m.lerp(aim, 1.0 - exp(-3.0 * get_process_delta_time()))
	var par := -pan * Vector2(1, -1) * _k0() * 0.5 * view_z + _par_m
	_uni(_bg.material, {"size": _bg.size, "sun_px": sun, "chart_c": map.size * 0.5, "k": k, "par": par, "mouse": m_px, "t": t, "zoom": view_z})
	_uni(_belt.material, {"sun_px": sun, "k": k, "day": day, "mouse": m_px, "zoom": view_z})
	var hk := str(hover.get("key", ""))
	for o in _orbit_nodes:
		var el: Array = o[0]
		var mat: ShaderMaterial = o[1].material
		var u := fposmod(day / Orbits.period(el), 1.0)
		var kv := {"sun_px": sun, "k": k, "body_u": u, "t": t}
		match str(o[2]):
			"planet":
				kv.merge({"col": Pal.heat(0.55, 1.1), "base_a": 0.07, "width": 1.0, "trail": 0.2, "trail_a": 0.9, "trail_w": 2.2, "glow_px": 5.0, "glow_a": 0.18, "flow": 0.0}, true)
			"port":
				kv.merge({"col": UiSkin.DATA, "base_a": 0.22, "width": 1.4, "trail": 0.12, "trail_a": 0.85, "trail_w": 2.6, "glow_px": 7.0, "glow_a": 0.25, "flow": 0.35}, true)
			_:
				var i: int = o[3]
				if i == sel_sector:
					kv.merge({"col": UiSkin.ACCENT, "base_a": 0.45, "width": 1.4, "trail": 0.08, "trail_a": 0.95, "trail_w": 2.4, "glow_px": 6.0, "glow_a": 0.3, "flow": 0.5}, true)
				elif hk == "st%d" % i:
					kv.merge({"col": UiSkin.DATA, "base_a": 0.28, "width": 1.0, "trail": 0.0, "trail_a": 0.0, "glow_px": 4.0, "glow_a": 0.0, "flow": 0.4}, true)
				else:
					kv.merge({"base_a": 0.0, "trail": 0.0, "trail_a": 0.0, "glow_a": 0.0, "flow": 0.0}, true)
				o[1].visible = i == sel_sector or hk == "st%d" % i
		_uni(mat, kv)
	# the fx layer: sector rings, the port's beacon, the sweep, the lock, the clicks, the crosshair
	var stp := PackedVector2Array()
	var sts := PackedFloat32Array()
	if mode == "find":
		var ord := Scan.order()
		for i in Orbits.STATIONS.size():
			stp.append(_to(Orbits.pos(Orbits.STATIONS[i], day)))
			var kk := ord.find(i)
			var s := 0.0 if kk < 0 else (1.0 if kk < Scan.reach() else 0.25)
			if s >= 1.0 and hk == "st%d" % i:
				s = 2.0
			sts.append(s)
	stp.resize(16)
	sts.resize(16)
	var j: Dictionary = Scan.data().job
	var sw := mode == "find" and not j.is_empty() and str(j.kind) == "sweep"
	var an := mode == "find" and not j.is_empty() and str(j.kind) == "analyze"
	var tgt := _to(Orbits.pos(Orbits.station(int(j.sector)), day)) if not j.is_empty() and j.has("sector") else Vector2.ZERO
	var rips := PackedVector3Array()
	for r in _rip:
		rips.append(Vector3(r[0].x, r[0].y, t - float(r[1])))
	while rips.size() < 4:
		rips.append(Vector3(0, 0, -1))
	_uni(_fx.material, {"size": map.size, "t": t, "n_st": mini(Orbits.STATIONS.size(), 16) if mode == "find" else 0, "st": stp, "st_s": sts,
		"sel": sel_sector if mode == "find" else -1, "ring_r": 0.17 * k, "port": _to(Orbits.pos(Orbits.PORT, day)),
		"mouse": m_px, "hov": hover.get("pos", Vector2(-99999, -99999)), "hov_k": clampf(_hover_t / 0.3, 0.0, 1.0),
		"sw_on": 1.0 if sw else 0.0, "sw_to": tgt, "sw_k": Scan.progress(), "an_on": 1.0 if an else 0.0, "an_to": tgt, "rip": rips, "sel_t": _sel_t})
	var show_inset := mode == "find" and sel_sector >= 0
	_inset_bg.visible = show_inset
	if show_inset:
		var r := _inset_rect()
		_inset_bg.position = r.position
		_inset_bg.size = r.size
		var sweeping: bool = sw and int(j.sector) == sel_sector
		_uni(_inset_bg.material, {"size": r.size, "c": Vector2(r.size.x * 0.5, r.size.y * 0.5 + 14.0), "R": 136.0, "ang": _radar_ang(), "sweeping": 1.0 if sweeping else 0.0, "t": t, "open_k": Pal.ease_out(clampf(_sel_open() / 0.35, 0.0, 1.0))})


func _sel_open() -> float:
	return minf(minf(_open_t, _sel_t), 9.0)


func _radar_ang() -> float:
	var j: Dictionary = Scan.data().job
	var sweeping: bool = not j.is_empty() and str(j.kind) == "sweep" and int(j.sector) == sel_sector
	return (Scan.progress() * TAU * 3.0) if sweeping else fmod(Mo.ms() / 1000.0 * 0.9, TAU)


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
		_sheen(b)
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


# ---------------------------------------------------------------- the chart's dressing (user 2026-10-26:
# "这个地图太假了……一点没有沉浸感" — a radar chart that moves: stars, a living sun, the belt as a
# stream of rock on Kepler's clock, the grid and bearings of a navigation plot)

var _stars: Array = []          # [pos (0..1), size, phase]
var _belt_rocks: Array = []     # [r AU, angle, size, alpha]


func _dressing_init() -> void:
	if not _stars.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261026
	for i in 420:
		_stars.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(0.6, 1.8), rng.randf() * TAU])
	for i in 1400:
		var r := clampf(rng.randfn(2.7, 0.28), 2.05, 3.35)
		_belt_rocks.append([r, rng.randf() * TAU, rng.randf_range(0.8, 1.9), rng.randf_range(0.12, 0.45)])


# the grid itself is in the space shader; only its words are drawn here
func _draw_grid_labels(c: Vector2) -> void:
	var k := _k()
	var rim := SCALE_AU * k
	for au in range(1, int(SCALE_AU) + 1):
		cv.draw_string(font, c + Vector2(au * k + 4, 14), "%d AU" % au, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.32))
	for d in [0, 90, 180, 270]:
		var a := deg_to_rad(float(d))
		var dir := Vector2(cos(a), -sin(a))
		cv.draw_string(font, c + dir * (rim + 12.0) + Vector2(-13, 5), "%03d°" % d, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.42))
	cv.draw_string(font, c + Vector2(0, -3.38 * k) + Vector2(-34, -4), w("小行星带", "ASTEROID BELT"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.35))


func _draw_frame(t: float, day: float) -> void:
	var box := Rect2(Vector2(24, 24), map.size - Vector2(48, 48))
	var col := Color(UiSkin.DATA, 0.6)
	# the corners open out as the map comes up
	var e := Pal.ease_out(clampf(_open_t / 0.6, 0.0, 1.0))
	var arm := 26.0 * e
	for corner in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
		var d: Vector2 = (box.get_center() - corner).sign()
		var at: Vector2 = corner + d * 40.0 * (1.0 - e)
		cv.draw_line(at, at + Vector2(d.x * arm, 0), col, 2.0)
		cv.draw_line(at, at + Vector2(0, d.y * arm), col, 2.0)
	var y := box.end.y - 14.0
	cv.draw_string(font, Vector2(box.position.x + 18, y), w("日心坐标 · 第 %.1f 天 · 1 秒 = %.1f 天", "HELIOCENTRIC · DAY %.1f · 1 s = %.1f DAYS") % [day, Orbits.DAYS_PER_S], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Pal.ink(0.45), e))
	# a thin scan line passing down the glass
	var sy := box.position.y + fmod(t * 60.0, box.size.y)
	cv.draw_line(Vector2(box.position.x, sy), Vector2(box.end.x, sy), Color(UiSkin.DATA, 0.02), 1.0)
	# opening: a bright line sweeps down the chart once, the dark lifting behind it
	if _open_t < 0.7:
		var oy := box.position.y + box.size.y * Pal.ease_out(_open_t / 0.7)
		cv.draw_line(Vector2(box.position.x, oy), Vector2(box.end.x, oy), Color(UiSkin.DATA, 0.5 * (1.0 - _open_t / 0.7)), 2.0)
		cv.draw_rect(Rect2(box.position.x, oy, box.size.x, box.end.y - oy), Color(0.0, 0.0, 0.0, 0.55 * (1.0 - _open_t / 0.7)))


# a body on the chart: a soft halo, a tighter glow, the core with a hot middle
func _body(at: Vector2, col: Color, r: float, halo: float) -> void:
	var g := UiSkin.glow_tex()
	cv.draw_texture_rect(g, Rect2(at - Vector2(halo, halo), Vector2(halo, halo) * 2.0), false, Color(col, 0.28))
	cv.draw_texture_rect(g, Rect2(at - Vector2(halo, halo) * 0.4, Vector2(halo, halo) * 0.8), false, Color(col, 0.5))
	cv.draw_circle(at, r, col)
	cv.draw_circle(at, r * 0.45, Color(1.0, 0.95, 0.88, 0.9))


func _draw_map() -> void:
	cv = _top
	_labels.clear()
	var day := Shipping.day()
	var t := Mo.ms() / 1000.0
	var c := _to(Vector2.ZERO)
	_draw_grid_labels(c)
	cv.draw_string(font, c + Vector2(14, -10) * sqrt(view_z), w("太阳", "SUN"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiSkin.ACCENT)
	for el in Orbits.PLANETS:
		var p := Orbits.pos(el, day)
		if p.length() <= SCALE_AU:
			var at := _to(p)
			_body(at, Pal.heat(0.85, 1.2), 4.2, 22.0)
			_label(at, Orbits.name_of(el), "", 12, Pal.ink(0.65), Color(), 2)
		else:
			# Jupiter beyond the map: its bearing at the rim
			var rim := _to(p.normalized() * SCALE_AU * 0.99)
			var inward := (rim - c).normalized()
			# the radar over its place: not half a marker peeking out from under it
			var jl := rim - inward * 70.0
			if mode == "find" and sel_sector >= 0 and (_inset_rect().grow(18.0).has_point(rim) or _inset_rect().grow(6.0).intersects(Rect2(jl + Vector2(0, -14), Vector2(110, 18)))):
				continue
			cv.draw_line(rim, rim - inward * 16.0, Pal.heat(0.6, 1.1), 2.0)
			cv.draw_texture_rect(UiSkin.glow_tex(), Rect2(rim - Vector2(14, 14), Vector2(28, 28)), false, Color(Pal.heat(0.6, 1.1), 0.4))
			cv.draw_string(font, rim - inward * 70.0, "%s %.1f AU →" % [Orbits.name_of(el), p.length()], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.55))
	var hk := str(hover.get("key", ""))
	for i in Orbits.STATIONS.size():
		var el: Array = Orbits.STATIONS[i]
		var p := _to(Orbits.pos(el, day))
		var on := i == sel_sector and mode == "find"
		var lit := on or hk == "st%d" % i
		var s := 6.0 if on else 5.0
		if lit:
			cv.draw_texture_rect(UiSkin.glow_tex(), Rect2(p - Vector2(18, 18), Vector2(36, 36)), false, Color(UiSkin.ACCENT if on else UiSkin.DATA, 0.4))
		var dia := PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)])
		cv.draw_colored_polygon(dia, Color(UiSkin.ACCENT, 0.9) if on else Color(0.05, 0.06, 0.08))
		dia.append(dia[0])
		cv.draw_polyline(dia, UiSkin.ACCENT if on else (UiSkin.DATA if lit else Pal.ink(0.8)), 1.2, true)
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
	# the port: its beacon pulses in the fx shader; two rings turning round it here
	var pp := _to(Orbits.pos(Orbits.PORT, day))
	cv.draw_texture_rect(UiSkin.glow_tex(), Rect2(pp - Vector2(24, 24), Vector2(48, 48)), false, Color(UiSkin.DATA, 0.45))
	cv.draw_circle(pp, 5.5, UiSkin.DATA)
	cv.draw_circle(pp, 2.4, Color(0.92, 0.98, 1.0))
	for n in 2:
		var a0 := t * (0.8 if n == 0 else -0.5)
		cv.draw_arc(pp, 11.0 + n * 5.0, a0, a0 + PI * 1.4, 24, Color(UiSkin.DATA, 0.7 - n * 0.25), 1.5, true)
	_label(pp, Orbits.name_of(Orbits.PORT), "", 13, UiSkin.DATA, Color(), 5, 14.0)
	_draw_tows(day, t)
	_draw_frame(t, day)
	_pick_hover(day, pp)
	if mode == "find":
		_draw_find(day, pp)
		return
	_flush_labels()
	# the ships
	for s in Shipping.live():
		var lit: bool = str(s.id) == chosen
		var col := UiSkin.ACCENT if lit else UiSkin.DATA
		var at: Vector2
		if str(s.state) in ["inbound", "leaving"]:
			var run: Dictionary = s.run
			var k := clampf((day - float(run.depart)) / float(run.tof), 0.0, 1.0)
			_arc(run, k, col, lit, t)
			at = _to(Orbits.on_transfer(run, k))
		else:
			at = pp + (Vector2(18, 14) if str(s.state) == "queued" else Vector2(-16, 14))
		if lit:
			cv.draw_texture_rect(UiSkin.glow_tex(), Rect2(at - Vector2(16, 16), Vector2(32, 32)), false, Color(col, 0.5))
		var tri := PackedVector2Array([at + Vector2(0, -6), at + Vector2(5, 5), at + Vector2(-5, 5)])
		cv.draw_colored_polygon(tri, col)
		cv.draw_string(font, at + Vector2(8, 12), str(s.id), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


# a transfer arc: the flown part one solid line, the rest dashes flowing towards the end (two draw
# calls, not one per segment)
func _arc(run: Dictionary, k: float, col: Color, lit: bool, t: float, n := 48, drawn := 1.0) -> void:
	var done := PackedVector2Array()
	var dash := PackedVector2Array()
	var prev := Vector2.INF
	for j in n + 1:
		var u := float(j) / n
		if u > drawn:
			break
		var p := _to(_path_at(run, u))
		if u <= k:
			done.append(p)
		elif prev.is_finite() and fmod(u * 40.0 - t * 2.0, 1.0) < 0.5:
			dash.append(prev)
			dash.append(p)
		prev = p
	if k > 0.0 and k < 1.0 and k <= drawn:
		done.append(_to(_path_at(run, k)))
	if done.size() >= 2:
		cv.draw_polyline(done, Color(col, 0.8), 2.2 if lit else 1.4, true)
	if dash.size() >= 2:
		cv.draw_multiline(dash, Color(col, 0.35 if lit else 0.2), 1.3)


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


func _draw_ptr() -> void:
	cv = _ptr
	_draw_pointer(Mo.ms() / 1000.0)


# the pointer: a reticle with its range and bearing; over a station, planet or the port the reticle
# morphs into a bracket lock (#012) and a card unfolds beside it, its words rising into place (#005)
func _draw_pointer(t: float) -> void:
	_card_clip.visible = false
	_draw_lock()
	if mouse.x < 24.0 or mouse.y < 24.0 or mouse.x > map.size.x - 24.0 or mouse.y > map.size.y - 24.0 or (mode == "find" and sel_sector >= 0 and _inset_rect().has_point(mouse)):
		return
	var m := mouse
	var lp := clampf(_lock_p(), 0.0, 1.0) if _lock_pos.distance_to(m) < 24.0 else 0.0
	cv.draw_arc(m, 7.0, 0.0, TAU, 24, Color(UiSkin.DATA, 0.85 * (1.0 - lp)), 1.2, true)
	cv.draw_circle(m, 1.5, Color(UiSkin.DATA, 0.9))
	var au := _from(m)
	var brg := fposmod(rad_to_deg(atan2(au.y, au.x)), 360.0)
	cv.draw_string(font, m + Vector2(14, 22), "%.2f AU · %03d°" % [au.length(), int(brg)], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(UiSkin.DATA, 0.85))
	if hover.is_empty():
		return
	var hp: Vector2 = hover.pos
	var lines: Array = hover.lines
	var bw := 236.0
	var bh := 38.0 + 20.0 * lines.size()
	var right := hp.x + 40.0 + bw <= map.size.x - 30.0
	# above and beside the lock, so the point's own label stays readable
	var bp := Vector2(hp.x + 44.0 if right else hp.x - 44.0 - bw, hp.y - 30.0 - bh)
	if bp.y < 30.0:
		bp.y = hp.y + 30.0
	var ck := Pal.ease_out(clampf((_hover_t - 0.08) / 0.3, 0.0, 1.0))
	if ck <= 0.0:
		return
	# the leader: out from the lock at 45 degrees, then flat to the card
	var land := Vector2(bp.x if right else bp.x + bw, bp.y + bh - 14.0 if bp.y < hp.y else bp.y + 14.0)
	var elbow := Vector2(hp.x + (land.y - hp.y) * (-1.0 if right else 1.0), land.y)
	if absf(elbow.x - hp.x) > absf(land.x - hp.x):
		elbow.x = land.x
	var start := hp + (elbow - hp).normalized() * 18.0
	var leader := PackedVector2Array([start, start.lerp(elbow, minf(1.0, ck * 2.0))])
	if ck > 0.5:
		leader.append(elbow.lerp(land, (ck - 0.5) * 2.0))
	cv.draw_polyline(leader, Color(UiSkin.ACCENT, 0.6), 1.0, true)
	var x0 := bp.x if right else bp.x + bw * (1.0 - ck)
	var box := Rect2(Vector2(x0, bp.y), Vector2(bw * ck, bh))
	cv.draw_texture_rect(UiSkin.glow_tex(), box.grow(36.0), false, Color(UiSkin.ACCENT, 0.05))
	cv.draw_rect(box, Color(0.02, 0.025, 0.033, 0.9))
	cv.draw_rect(Rect2(box.position, Vector2(box.size.x, 2.0)), Color(UiSkin.ACCENT, 0.9))
	cv.draw_rect(Rect2(box.position.x, box.end.y - 1.0, box.size.x, 1.0), Color(1, 1, 1, 0.1))
	# the words: clipped to the card, each line rising from below into place (#005, 0.35–1.0 s
	# quintic ease-out after the card opens, a line after the other)
	_card_clip.visible = true
	_card_clip.position = box.position + Vector2(0, 3)
	_card_clip.size = Vector2(maxf(1.0, box.size.x), bh - 4.0)
	_card_ink.size = Vector2(bw, bh)
	_card_ink.queue_redraw()


func _draw_card_ink() -> void:
	if hover.is_empty():
		return
	var s := _hover_t - 0.1
	var lines: Array = hover.lines
	var drop := Mo.reveal_drop(s) * 26.0
	_card_ink.draw_string(font, Vector2(14, 22 + drop), str(hover.title), HORIZONTAL_ALIGNMENT_LEFT, 212.0, 15, Pal.ink(0.97))
	for n in lines.size():
		var dn := Mo.reveal_drop(s, 0.08 * (n + 1)) * 26.0
		_card_ink.draw_string(font, Vector2(14, 43 + n * 20 + dn), str(lines[n]), HORIZONTAL_ALIGNMENT_LEFT, 212.0, 12, Pal.ink(0.7))


# #012 on the hover lock: where the morph stands now (0 = the round reticle, 1 = the bracket box)
func _lock_p() -> float:
	var k: float = Mo.morph_k(_lock_s)[0]
	return lerpf(_lock_from, 1.0 if _lock_on else 0.0, k)


func _update_lock(dt: float) -> void:
	var hk := str(hover.get("key", ""))
	if hk != "":
		if not _lock_on or hk != _lock_key:
			_lock_from = clampf(_lock_p(), 0.0, 1.0) if hk == _lock_key else 0.0
			_lock_on = true
			_lock_key = hk
			_lock_s = 0.0
			_sfx("starmap_lock", 0.6)
		_lock_pos = hover.pos
	elif _lock_on:
		_lock_from = clampf(_lock_p(), 0.0, 1.0)
		_lock_on = false
		_lock_s = 0.0
	_lock_s += dt


static var _corner_mask := PackedFloat32Array()


func _draw_lock() -> void:
	if not _lock_on and _lock_s >= Mo.MORPH_S:
		return
	if _corner_mask.is_empty():
		for i in Mo.MN:
			var a := float(i) / Mo.MN * TAU - PI * 0.5
			_corner_mask.append(smoothstep(0.62, 0.8, absf(sin(2.0 * a))))
	var mk: Array = Mo.morph_k(_lock_s)
	var p := _lock_p()
	var pc: float = lerpf(_lock_from, 1.0 if _lock_on else 0.0, mk[1])
	var r := lerpf(7.0, 17.0, p) * float(mk[2])
	var pts := Mo.blend(Mo.shape("circle"), Mo.shape("square"), p, _lock_pos, r)
	var col := UiSkin.DATA.lerp(UiSkin.ACCENT, clampf(pc, 0.0, 1.0))
	var cols := PackedColorArray()
	cols.resize(Mo.MN + 1)
	var pm := clampf(p, 0.0, 1.0)
	for i in Mo.MN:
		cols[i] = Color(col, lerpf(1.0, _corner_mask[i], pm) * (0.85 + 0.15 * pm))
	cols[Mo.MN] = cols[0]
	pts.append(pts[0])
	_ptr.draw_polyline_colors(pts, cols, lerpf(1.2, 2.0, pm), true)


# the hulks under tow (33 号): the flown arc bright, dashes flowing along what is left, the tug
# with its burn behind it. When a tow first shows (sent now, or the map just opened) its route draws
# itself on in one stroke (#004: 0.4–1.95 s, a dot riding the tip, the arrowhead opening at the end)
func _draw_tows(day: float, t: float) -> void:
	if not Career.data.has("ship_market"):
		return
	for a in ShipMarket.data().assets:
		if str(a.state) != "towing":
			continue
		var id := str(a.id)
		if not _tow_seen.has(id):
			_tow_seen[id] = t
			_sfx("starmap_route")
		var age := t - float(_tow_seen[id])
		var run: Dictionary = _tow_path(a)
		var k := clampf((day - float(run.depart)) / maxf(ShipMarket.tow_span(a), 0.0001), 0.0, 1.0)
		var col := UiSkin.ACCENT
		var f1 := Mo.draw_on(age)
		_arc(run, k, col, true, t, 64, f1)
		if f1 > 0.0 and f1 < 1.0:
			var tip := _to(_path_at(run, f1))
			cv.draw_texture_rect(UiSkin.glow_tex(), Rect2(tip - Vector2(12, 12), Vector2(24, 24)), false, Color(col, 0.7))
			cv.draw_circle(tip, 4.0, col)
			cv.draw_circle(tip, 1.7, Color(1.0, 0.95, 0.9))
		var ah := Mo.arrow_open(age)
		if ah > 0.01:
			var e := _to(_path_at(run, 1.0))
			var eb := _to(_path_at(run, 0.985))
			var d := (e - eb).normalized() if e != eb else Vector2.RIGHT
			var n := d.orthogonal()
			cv.draw_polyline(PackedVector2Array([e - d * 9.0 * ah + n * 7.0 * ah, e + d * 1.5, e - d * 9.0 * ah - n * 7.0 * ah]), Color(col, 0.85), 1.6, true)
		var at := _to(_path_at(run, k))
		var back := _to(_path_at(run, maxf(0.0, k - 0.03)))
		var dir := (at - back).normalized() if at != back else Vector2.RIGHT
		cv.draw_texture_rect(UiSkin.glow_tex(), Rect2(at - Vector2(22, 22), Vector2(44, 44)), false, Color(col, 0.5))
		# the burn: a hot core and a longer soft plume flickering
		var fl := 14.0 + 4.0 * sin(t * 20.0) + 3.0 * sin(t * 33.0)
		cv.draw_line(at, at - dir * fl * 1.6, Color(col, 0.35), 4.0, true)
		cv.draw_line(at, at - dir * fl, Color(1.0, 0.85, 0.6, 0.85), 2.0, true)
		var tri := PackedVector2Array([at + dir * 7.0, at - dir * 5.0 + dir.orthogonal() * 4.5, at - dir * 5.0 - dir.orthogonal() * 4.5])
		cv.draw_colored_polygon(tri, col)
		_label(at, w("%s 拖运中", "%s UNDER TOW") % id, "", 11, col, Color(), 3)


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
	# a click rings out from where it landed
	_rip.append([event.position, Mo.ms() / 1000.0])
	_sfx("starmap_click", 0.5)
	if _rip.size() > 4:
		_rip.pop_front()
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


func _open_hulk_market() -> void:
	if game == null or not ShipMarket.open():
		return
	var g = game
	var e := _back_entry()
	close()
	Back.go(e, "ship_market", func(): g.open_ship_market())


# 134 号: how to open the map again as it is (its page), for the page it leaves for
func _back_entry() -> Dictionary:
	var g = game
	var m := mode
	return Back.entry("star_map", ["星图", "STAR MAP"], func(): g.open_star_map(m))


func close() -> void:
	if on_close.is_valid():
		on_close.call()


# Esc and the close key: back where the map was opened from, else away (scripts/ui_back.gd)
func _back() -> void:
	close()
	Back.back()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_back()


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
	_sheen(b)
	return b


# user 2026-10-28 (截图：“分析 S-003 的电磁特征”和信号行一模一样，像同一种东西): what the page
# does is drawn apart from what it lists — an action is a solid accent button (as Buy on the
# exchange and the ship market), an action that cannot run yet only an outline with its reason;
# the signal and sector rows keep the glass of a list
func _action(b: Button) -> Button:
	UiSkin.accent_button(b)
	for e in _sheens:
		if e[0] == b:
			e[2] = true
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
		_done_until = Mo.ms() + DONE_MS
	_last_an = an
	if _done_sig != "" and (an != "" or Mo.ms() >= _done_until):
		_done_sig = ""
	var way := ShipMarket.on_the_way()
	_watch_docking()
	if _dock_sig != "" and Mo.ms() >= _dock_until:
		_dock_sig = ""
	var key := TugYard.status() + "%s|%d|%s|%d|%s|%d|%d|%s|%s|%d|%s|%s" % [str(j.get("kind", "")), sel_sector, sel_sig, found.size(), str(Scan.data().sectors.keys()), int(float(Career.data.get("money", 0.0)) / 100.0), int(Scan.cooldown(sel_sector) > 0.0), _done_sig, str(_sectors_open), way.size(), str(TugYard.taken().map(func(a): return str(a.get("state", "")))), _dock_sig]
	if key == _sig_key:
		_live_text()
		return
	_sig_key = key
	_live = []
	for c in find_box.get_children():
		c.queue_free()
	_tour_parts.erase("send")
	_tour_parts.sigs = []
	# 107 号 Q5 A (user's screenshot: the tug button was below the fold): on top, what to do next and
	# the one button that does it; the sectors fold to one line once one is picked
	var nx := OpsSkin.label(next_line(), 16, 0.95)
	nx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nx.add_theme_color_override("font_color", UiSkin.ACCENT)
	find_box.add_child(nx)
	_live.append([nx, next_line])
	if _dock_sig != "":
		find_box.add_child(ScanStatus.new(w("%s 已到港 · 去船坞开工", "%s DOCKED · START STRIPPING IT IN THE BERTH") % _dock_sig))
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
			_tour_parts.sigs.append(sec)
			for s in sigs:
				var id := str(s.id)
				var stt := sig_state(s)
				if str(stt.kind) == "found":
					var sendb := _send_button(int(stt.offer), id)
					_rise(sendb, id)
					find_box.add_child(sendb)
					_tour_parts.found = sendb
					_tour_parts.sigs.append(sendb)
					if not _tour_parts.has("send"):
						_tour_parts.send = sendb
					continue
				var txt := "%s · %s" % [id, Scan.verdict(s)]
				if str(stt.get("words", "")) != "":
					txt = "%s · %s · %s" % [id, Scan.type_name(str(s.offer.ship)), str(stt.words)]
				var b := _btn(txt, true, func(): sel_sig = id; _sig_key = ""; _fill(), 32)
				b.name = "Sig_" + id
				if str(stt.kind) == "towing":
					_live.append([b, func(): return _sig_row_text(Scan.sig_of(id))])
				if _docked_flash(id) > 0.0:
					b.add_child(DockFlash.new(self, id))
				_rise(b, id)
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
				_tour_parts.sigs.append(b)
			if an != "" or _done_sig != "":
				# user 2026-10-28 (截图：“正在分析信号 S-001，等它完成”像第三条信号): the analysis under
				# way is a status line under the list — no button, an accent rule and a bar — and says
				# what it found for a few seconds when done
				var ss := ScanStatus.new(_done_line() if an == "" else "")
				find_box.add_child(ss)
				_tour_parts.sigs.append(ss)
			if an == "" and sel_sig != "" and not Scan.sig_of(sel_sig).get("known", false):
				var why2 := Scan.analyze_block(sel_sig)
				find_box.add_child(_gap(6))
				var ab := _action(_btn(w("分析 %s 的电磁特征（约 %d 秒）", "ANALYSE %s (~%d s)") % [sel_sig, int(Scan.ANALYZE_S)] if why2 == "" else why2, why2 == "", func(): Scan.analyze(sel_sig); _sig_key = ""; _fill(), 42))
				find_box.add_child(ab)
				_tour_parts.sigs.append(ab)
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
			var eb := _send_button(i, str(o.get("scan_sig", "")))
			find_box.add_child(eb)
			if not _tour_parts.has("send"):
				_tour_parts.send = eb
	if not way.is_empty():
		var wl := OpsSkin.label(w("在路上 %d 艘 · 最快约 %d 秒", "%d ON THE WAY · FIRST ~%d s") % [way.size(), int(float(way[0].left_s))], 14, 0.8)
		find_box.add_child(wl)
		_tour_parts.way = wl
		_live.append([wl, func():
			var wv := ShipMarket.on_the_way()
			return wl.text if wv.is_empty() else w("在路上 %d 艘 · 最快约 %d 秒", "%d ON THE WAY · FIRST ~%d s") % [wv.size(), int(float(wv[0].left_s))]])
	var yard := OpsSkin.label(TugYard.status(), 13, 0.65)
	find_box.add_child(yard)
	_tour_parts.yard = yard
	_stagger(find_box)


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
					return {"kind": "arrived", "words": w("已到港 · 在拖船区等着拆", "DOCKED · WAITING IN THE TUG YARD")}
				"held":
					return {"kind": "held", "words": w("已到港 · 港务扣留 · 去二手船市“我的船”付清放行", "DOCKED · HELD BY THE PORT · PAY IT UNDER HULK MARKET · MY SHIPS")}
				"stripping":
					return {"kind": "done", "words": w("正在船坞里拆", "BEING STRIPPED")}
				_:
					return {"kind": "done", "words": w("已经拆完", "STRIPPED")}
	return {"kind": ""}


# a signal row's text from its state (the same words _fill_find writes)
func _sig_row_text(s: Dictionary) -> String:
	var id := str(s.get("id", ""))
	var stt := sig_state(s)
	if str(stt.get("words", "")) != "":
		return "%s · %s · %s" % [id, Scan.type_name(str(s.offer.ship)), str(stt.words)]
	return "%s · %s" % [id, Scan.verdict(s)]


func _live_text() -> void:
	for e in _live:
		var c = e[0]
		if c == null or not is_instance_valid(c) or c.is_queued_for_deletion():
			continue
		var t := str((e[1] as Callable).call())
		if c.text != t:
			c.text = t


# a hulk that was under tow is home: its row flashes, a line says where to go
func _watch_docking() -> void:
	if not Career.data.has("ship_market"):
		return
	var now: Dictionary = {}
	for a in Career.data.ship_market.get("assets", []):
		var sig := str(a.get("listing", {}).get("offer", {}).get("scan_sig", ""))
		if sig == "":
			continue
		var st := str(a.get("state", ""))
		if st == "towing":
			now[sig] = true
		elif _tow_was.has(sig) and st in ["arrived", "held"]:
			_docked_at[sig] = Mo.ms()
			_dock_sig = sig
			_dock_until = Mo.ms() + DOCK_MS
	_tow_was = now


# 0..1, the docked row's flash: two quick pulses fading over DOCK_FLASH_S
func _docked_flash(id: String) -> float:
	if not _docked_at.has(id):
		return 0.0
	var t := (Mo.ms() - int(_docked_at[id])) / 1000.0
	if t >= DOCK_FLASH_S:
		return 0.0
	return (1.0 - t / DOCK_FLASH_S) * (0.55 + 0.45 * cos(t * TAU * 1.6))


class DockFlash extends Control:
	var sm
	var id := ""

	func _init(owner_map, sig: String) -> void:
		sm = owner_map
		id = sig
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var a: float = sm._docked_flash(id)
		if a <= 0.0:
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color(UiSkin.DATA, 0.22 * a))
		draw_rect(Rect2(Vector2.ZERO, size), Color(UiSkin.DATA, 0.9 * a), false, 1.5)


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
	const Mo := preload("res://scripts/star_map_motion.gd")
	static var started := {}
	var row: Button
	var id := ""

	func _init(b: Button, sig: String) -> void:
		row = b
		id = sig
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if not started.has(sig) or Mo.ms() / 1000.0 - float(started[sig]) > Scan.ANALYZE_S + 2.0:
			started[sig] = Mo.ms() / 1000.0

	func _process(_dt: float) -> void:
		if str(Scan.data().job.get("sig", "")) == id:
			row.text = Scan.w("%s · 分析中 %d%%", "%s · ANALYSING %d%%") % [id, int(Scan.progress() * 100.0)]
		queue_redraw()

	# #069 Skeleton screen (Motion Prompt · MIT License (c) 2026 Shohei Ohtaki ·
	# https://showheyohtaki.github.io/motion-prompt/#069): the rest of the row turns to rounded blocks
	# over 0.15 s (linear), a 160-wide shine (clear at its edges, brightest in the middle) sweeping
	# across them every 0.9 s, drawn only on the blocks; the progress along the foot
	func _draw() -> void:
		var s := Mo.ms() / 1000.0 - float(started.get(id, 0.0))
		var sk := clampf(s / Mo.SKEL_IN, 0.0, 1.0)
		var f := row.get_theme_font("font")
		var fs := row.get_theme_font_size("font_size")
		var x0 := 12.0 + f.get_string_size(row.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 18.0
		var avail := size.x - 16.0 - x0
		if avail > 40.0 and sk > 0.0:
			var cy := size.y * 0.5 - 1.0
			var blocks := [Rect2(x0, cy - 5.0, avail * 0.56, 10.0), Rect2(x0 + avail * 0.56 + 10.0, cy - 5.0, avail * 0.44 - 10.0, 10.0)]
			var sx := -200.0 + fposmod(s, Mo.SKEL_SWEEP) / Mo.SKEL_SWEEP * (size.x + 400.0)
			for r in blocks:
				draw_rect(r, Color(1, 1, 1, 0.07 * sk))
				_shine(r, sx, sk)
		var y := size.y - 5.0
		draw_rect(Rect2(10.0, y, size.x - 20.0, 2.0), Color(1, 1, 1, 0.06))
		draw_rect(Rect2(10.0, y, (size.x - 20.0) * Scan.progress(), 2.0), UiSkin.ACCENT)

	func _shine(r: Rect2, sx: float, sk: float) -> void:
		var half := Mo.SKEL_BAND * 0.5
		var xs := [sx - half, sx, sx + half]
		var al := [0.0, 0.3 * sk, 0.0]
		for n in 2:
			var a := maxf(float(xs[n]), r.position.x)
			var b := minf(float(xs[n + 1]), r.end.x)
			if b <= a:
				continue
			var ka := lerpf(al[n], al[n + 1], (a - xs[n]) / half)
			var kb := lerpf(al[n], al[n + 1], (b - xs[n]) / half)
			draw_polygon(PackedVector2Array([Vector2(a, r.position.y), Vector2(b, r.position.y), Vector2(b, r.end.y), Vector2(a, r.end.y)]),
				PackedColorArray([Color(1, 1, 1, ka), Color(1, 1, 1, kb), Color(1, 1, 1, kb), Color(1, 1, 1, ka)]))


# 80 号: the find page's next step, in plain words, from the real state of the sweep
func next_line() -> String:
	var job: Dictionary = Scan.data().get("job", {})
	if not job.is_empty():
		return w("下一步：等一下 · %s", "NEXT: WAIT · %s") % Scan.job_text()
	var way := ShipMarket.on_the_way()
	var found := Scan.found()
	var waiting := ""
	if not way.is_empty():
		# 108 号 Q4/Q11: one line; the rest (the terminal pauses the tow, where to start it) is in the tour.
		# user 2026-11-05: the tug flies with the map open too (the tow clock is the freight pier's, which
		# the map does not stop): the line no longer says it waits for the map to close
		waiting = w("拖船在路上，约 %d 秒到港。", "THE TUG IS ON ITS WAY, ~%d s.") % int(float(way[0].left_s))
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
		["sigs", w("分析电磁特征", "ANALYSE"), w("点一个信号再点“分析电磁特征”（约 %d 秒）：看清是不是船、多长、漂了多少年、拖回来要多少钱。" % int(Scan.ANALYZE_S), "Pick a signal and analyse it (~%d s): whether it is a hulk, how long, how old, what the tow costs." % int(Scan.ANALYZE_S))],
		["send", w("派拖船", "SEND THE TUG"), w("认出是船的那一行会变成“派拖船去拖”按钮。点它，星图上看得见拖船飞过去、拖着船回来。第一趟免费。", "A signal analysed as a hulk becomes a tug button. Click it and watch the tug fly out and tow it home. The first is free.")],
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
	if part == "sigs":
		var u := Rect2()
		for c in _tour_parts.get("sigs", []):
			if is_instance_valid(c) and not c.is_queued_for_deletion() and c.is_visible_in_tree():
				u = c.get_global_rect() if u.size == Vector2.ZERO else u.merge(c.get_global_rect())
		if u.size != Vector2.ZERO:
			return u
	var c = _tour_parts.get(part)
	if c != null and is_instance_valid(c) and c.is_visible_in_tree():
		return c.get_global_rect()
	return find_box.get_global_rect()


func start_tour() -> void:
	_tour_i = clampi(Career.guide_at(_tour_kind + "_tour"), 0, _tour_steps().size() - 1)
	while _tour_i > 0 and not _tour_can(_tour_i):
		_tour_i -= 1
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
	var acted := false
	if _tour_i >= 0 and _tour_rect(_tour_part()).has_point(at):
		for b in find_box.find_children("*", "Button", true, false):
			if b.is_visible_in_tree() and not b.disabled and not b.is_queued_for_deletion() and b.get_global_rect().has_point(at):
				b.pressed.emit()
				acted = true
				break
	# the analyse step takes two presses (a signal, then its button): the hulk found moves it on
	if acted and _tour_kind == "find" and _tour_i == 4:
		return
	_tour_next(acted)


func tour_on() -> bool:
	return _tour_i >= 0


# user 2026-11-05 (截图：扫描到 83%、一个信号都没出来，卡片已经在讲“分析电磁特征”): a step shows only once
# what it talks about is on screen. Until then the card says what it waits for, lights that, and
# Space / a click wait too; the analyse step moves on by itself once a hulk is found.
func _sweeping_here() -> bool:
	var j: Dictionary = Scan.data().job
	return sel_sector >= 0 and str(j.get("kind", "")) == "sweep" and int(j.get("sector", -1)) == sel_sector


func _swept_here() -> bool:
	return sel_sector >= 0 and not _sweeping_here() and not Scan.signals(sel_sector).is_empty()


func _send_on() -> bool:
	var b = _tour_parts.get("send")
	return b != null and is_instance_valid(b) and not b.is_queued_for_deletion() and b.is_visible_in_tree()


# can the tour stand on step i at all (its own card, or the card saying what it waits for)
func _tour_can(i: int) -> bool:
	if _tour_kind != "find":
		return true
	if i == 3 or i == 4:
		return _sweeping_here() or _swept_here()
	if i == 5:
		return _send_on()
	return true


# "" when step i shows as written; else what it waits for
func tour_wait(i := _tour_i) -> String:
	if _tour_kind != "find" or i < 0:
		return ""
	if i == 3 or i == 4:
		if _sweeping_here():
			return "sweeping"
		if i == 4:
			if str(Scan.data().job.get("kind", "")) == "analyze":
				return "analysing"
			var open := false
			for sg in Scan.signals(sel_sector):
				if not sg.get("known", false):
					open = true
			if not open and not _send_on():
				return "no_ship"
	if i == 5 and not _send_on():
		return "no_ship"
	return ""


func _tour_part() -> String:
	match tour_wait():
		"sweeping":
			return "sweep"
		"analysing":
			return "sigs"
		"no_ship":
			return "sectors"
	return str(_tour_steps()[_tour_i][0])


# [title, body, progress (-1: none), footer] of the card now
func tour_card() -> Array:
	if _tour_i < 0:
		return []
	var st: Array = _tour_steps()[_tour_i]
	var wt := tour_wait()
	var foot := w("点一下或按空格：下一项 · Esc 跳过", "CLICK OR SPACE: NEXT · ESC SKIPS")
	if wt != "" or (_tour_i + 1 < _tour_steps().size() and not _tour_can(_tour_i + 1)):
		foot = w("照着做，完成后自动继续 · Esc 跳过", "DO IT: THE TOUR GOES ON BY ITSELF · ESC SKIPS")
	match wt:
		"sweeping":
			return [w("正在扫描", "SWEEPING"), w("正在扫描，扫完会出现几个信号。", "Sweeping: a few signals show up when it is done."), Scan.progress(), foot]
		"analysing":
			return [w("正在分析", "ANALYSING"), w("正在分析 %s 的电磁特征，分析完就知道是不是船。", "Analysing %s: done, it says whether it is a hulk.") % str(Scan.data().job.get("sig", "")), Scan.progress(), foot]
		"no_ship":
			return [w("这片没有船", "NO HULK HERE"), w("这片的信号都看过了，都不是船。换一片扇区再扫描。", "Every signal here is rock. Pick another sector and sweep it."), -1.0, foot]
	return [str(st[1]), str(st[2]), -1.0, foot]


# each frame: off a step whose ground went away, on from the analysis once a hulk is found
func _tour_tick() -> void:
	if _tour_kind != "find" or _tour_i < 0:
		return
	while _tour_i > 0 and not _tour_can(_tour_i):
		_tour_i -= 1
	if _tour_i == 4 and _tour_can(5):
		_tour_i = 5
		Career.guide_keep(_tour_kind + "_tour", _tour_i)


func _tour_next(acted := false) -> void:
	# a step still waiting does not let Space or a click past it (a press on its lit part that did it does)
	if not acted and tour_wait() != "":
		return
	if _tour_i + 1 < _tour_steps().size() and not _tour_can(_tour_i + 1):
		return
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
	var cd := tour_card()
	var r := _tour_rect(_tour_part()).grow(8.0)
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
	_tour_layer.draw_string(f, at + Vector2(18, 30), "%d / %d  %s" % [_tour_i + 1, _tour_steps().size(), str(cd[0])], HORIZONTAL_ALIGNMENT_LEFT, cw - 36, 19, UiSkin.ACCENT)
	_tour_layer.draw_multiline_string(f, at + Vector2(18, 58), str(cd[1]), HORIZONTAL_ALIGNMENT_LEFT, cw - 36, 15, -1, Pal.ink(0.88))
	var pr := float(cd[2])
	if pr >= 0.0:
		# the job's progress on the card itself
		var bw := cw - 36.0 - 52.0
		var by := at.y + ch - 46.0
		_tour_layer.draw_rect(Rect2(at.x + 18.0, by, bw, 3.0), Color(1, 1, 1, 0.1))
		_tour_layer.draw_rect(Rect2(at.x + 18.0, by, bw * pr, 3.0), UiSkin.ACCENT)
		_tour_layer.draw_string(f, Vector2(at.x + 18.0 + bw + 10.0, by + 6.0), "%d%%" % int(pr * 100.0), HORIZONTAL_ALIGNMENT_LEFT, 44, 13, UiSkin.ACCENT)
	_tour_layer.draw_string(f, at + Vector2(18, ch - 14), str(cd[3]), HORIZONTAL_ALIGNMENT_LEFT, cw - 36, 12, Pal.ink(0.55))


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
	# the sector rings, the sweep's wavefronts and the analysis beam are in the fx shader; the
	# signals on the big map are drawn here
	var t := Mo.ms() / 1000.0
	var g := UiSkin.glow_tex()
	for key in Scan.data().sectors:
		for sg in Scan.data().sectors[key].sigs:
			var at := _sig_at(sg, day)
			var known: bool = sg.get("known", false)
			var col := UiSkin.ACCENT if known and str(sg.kind) == "ship" else (UiSkin.DATA if not known else Pal.ink(0.35))
			if not known or str(sg.kind) == "ship":
				var tw := 0.6 + 0.4 * sin(t * 3.0 + float(hash(str(sg.id)) % 100))
				cv.draw_texture_rect(g, Rect2(at - Vector2(9, 9), Vector2(18, 18)), false, Color(col, 0.45 * tw))
			cv.draw_circle(at, 2.0, col)
	_inset_goal = _inset_target(day, pp)
	_flush_labels()


func _draw_inset_top() -> void:
	cv = _inset_top
	if mode == "find" and sel_sector >= 0:
		_draw_inset(Shipping.day())


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
			cv.draw_line(L.at, to, Color(L.col, 0.35), 1.0, true)
		cv.draw_string(font, rect.position + Vector2(2, float(L.size)), str(L.text), HORIZONTAL_ALIGNMENT_LEFT, -1, int(L.size), L.col)
		if str(L.sub) != "":
			cv.draw_string(font, rect.position + Vector2(2, float(L.size) + 13.0), str(L.sub), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, L.sub_col)


# a signal drifts on its own slow path: where it is now, AU from its station
func _drift(sg: Dictionary) -> Vector2:
	var t := Mo.ms() / 1000.0
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
	var t := Mo.ms() / 1000.0
	var g := UiSkin.glow_tex()
	# the scope itself (rings, ticks, the sweep and its afterglow, clutter) is the radar shader
	var ok := Pal.ease_out(clampf(_sel_open() / 0.35, 0.0, 1.0))
	if ok < 0.6:
		return
	cv.draw_string(font, r.position + Vector2(16, 26), w("%s · 局部雷达", "%s · LOCAL RADAR") % Orbits.name_of(Orbits.station(sel_sector)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.8))
	# a live lamp in the corner
	cv.draw_circle(r.position + Vector2(r.size.x - 20, 21), 3.0, Color(UiSkin.DATA, 0.5 + 0.5 * absf(sin(t * 2.2))))
	var c := Vector2(r.get_center().x, r.get_center().y + 14.0)
	var R := 136.0
	var j: Dictionary = Scan.data().job
	var sweeping: bool = not j.is_empty() and str(j.kind) == "sweep" and int(j.sector) == sel_sector
	var ang := _radar_ang()
	# the station at the centre
	cv.draw_texture_rect(g, Rect2(c - Vector2(16, 16), Vector2(32, 32)), false, Color(1, 1, 1, 0.12))
	var dia := PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0), c + Vector2(0, -6)])
	cv.draw_polyline(dia, Pal.ink(0.85), 1.4, true)
	# the radar's words never sit on one another (2026-11-04): the title and the foot line are kept
	# clear, every blip's own spot too, then each label takes the first free place round its point
	inset_labels.clear()
	_inset_block.clear()
	_inset_block.append(Rect2(r.position, Vector2(r.size.x, 34.0)))
	_inset_block.append(Rect2(r.position.x, r.end.y - 30.0, r.size.x, 30.0))
	_inset_block.append(Rect2(c - Vector2(8, 8), Vector2(16, 16)))
	for sg in Scan.signals(sel_sector):
		_inset_block.append(Rect2(_inset_at(sg) - Vector2(9, 9), Vector2(18, 18)))
	var st_name := Orbits.name_of(Orbits.station(sel_sector))
	cv.draw_string(font, _place_inset("@station", c, st_name, r), st_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.55))
	if sweeping:
		cv.draw_string(font, r.position + Vector2(16, r.size.y - 14), w("扫描中 %d%%", "SWEEPING %d%%") % int(Scan.progress() * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiSkin.DATA)
		# the sweep's progress round the scope's rim
		cv.draw_arc(c, R + 5.0, -PI * 0.5, -PI * 0.5 + TAU * Scan.progress(), 64, Color(UiSkin.DATA, 0.85), 2.0, true)
	# new drift: a swept sector whose quiet time is over has echoes coming in from the rim
	if not Scan.sector(sel_sector).is_empty() and Scan.cooldown(sel_sector) <= 0.0 and not sweeping:
		for n in 3:
			var a3 := TAU * (n / 3.0) + 0.6
			var kk := fmod(t * 0.12 + n * 0.33, 1.0)
			var p := c + Vector2(cos(a3), sin(a3)) * R * (1.05 - 0.45 * kk)
			cv.draw_texture_rect(g, Rect2(p - Vector2(8, 8), Vector2(16, 16)), false, Color(UiSkin.DATA, 0.5 * (1.0 - kk)))
			cv.draw_circle(p, 2.5, Color(UiSkin.DATA, 0.7 * (1.0 - kk)))
			cv.draw_line(p, p + Vector2(cos(a3), sin(a3)) * 14.0, Color(UiSkin.DATA, 0.3 * (1.0 - kk)), 1.0)
		cv.draw_string(font, r.position + Vector2(16, r.size.y - 14), w("检测到新目标 · 建议重新扫描", "NEW TARGETS · SWEEP AGAIN"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiSkin.DATA)
	_rv_clip.visible = false
	var newest := ""
	var nt := -1.0
	for sg in Scan.signals(sel_sector):
		if float(_known_at.get(str(sg.id), -1.0)) > nt:
			nt = float(_known_at[str(sg.id)])
			newest = str(sg.id)
	for sg in Scan.signals(sel_sector):
		var at := _inset_at(sg)
		var id := str(sg.id)
		var on := id == sel_sig
		var known: bool = sg.get("known", false)
		var ship: bool = known and str(sg.kind) == "ship"
		# a blip brightens as the sweep line passes and fades after it
		var bearing := (at - c).angle()
		var since := fposmod(ang - bearing, TAU)
		var lit := clampf(1.0 - since / 2.5, 0.35, 1.0)
		var morph_s: float = t - float(_known_at[id]) if _known_at.has(id) else 9.0
		_marker(sg, at, t, lit, morph_s)
		if not j.is_empty() and str(j.kind) == "analyze" and str(j.sig) == id:
			# under analysis: the progress ring, a turning arc, a line scanning down across it
			cv.draw_arc(at, 16.0, -PI * 0.5, -PI * 0.5 + TAU * Scan.progress(), 32, UiSkin.ACCENT, 2.5, true)
			cv.draw_arc(at, 22.0, t * 4.0, t * 4.0 + 1.2, 12, Color(UiSkin.ACCENT, 0.6), 1.0, true)
			var sy := at.y - 14.0 + 28.0 * fmod(t * 1.6, 1.0)
			var half := sqrt(maxf(0.0, 196.0 - pow(sy - at.y, 2.0)))
			cv.draw_line(Vector2(at.x - half, sy), Vector2(at.x + half, sy), Color(UiSkin.ACCENT, 0.7), 1.0)
		if on:
			var br := 14.0 + 1.5 * sin(t * 4.0)
			for q in 4:
				var a4 := q * PI * 0.5 + PI * 0.25 + t * 0.4
				var e := at + Vector2(cos(a4), sin(a4)) * br
				cv.draw_line(e, e + Vector2(cos(a4), sin(a4)) * 6.0, UiSkin.ACCENT, 2.0)
		# 127 号: "S-002 · 磐石级维修拖船" once analysed; just analysed, its name rises from behind a
		# line (#005) instead of appearing
		var nm := Scan.short_name(sg)
		var txt := id + (" · " + nm if nm != "" else "")
		var col := UiSkin.ACCENT if ship else Pal.ink(0.75)
		var lp := _place_inset(id, at, txt, r)
		if morph_s < 2.4 and id == newest:
			_reveal_label(lp, txt, col, morph_s)
		else:
			cv.draw_string(font, lp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


var inset_labels: Array = []      # the radar labels' boxes this frame (a test checks none overlap)
var _inset_block: Array = []
var _inset_pick := {}             # each label's last place, tried first so it does not flicker


# a radar label's place: right of its point, then the other side, then above or below, stepping
# further out; returns where its text starts (the baseline), its box kept for the next labels
func _place_inset(key: String, at: Vector2, text: String, area: Rect2) -> Vector2:
	var sz := Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, 13.0)
	var cands: Array = []
	for dy in [0.0, 13.0, -13.0, 26.0, -26.0, 39.0, -39.0]:
		cands.append(Vector2(11.0, -15.0 + dy))
		cands.append(Vector2(-11.0 - sz.x, -15.0 + dy))
	cands.append(Vector2(-sz.x * 0.5, -26.0))
	cands.append(Vector2(-sz.x * 0.5, 11.0))
	var inner := area.grow(-4.0)
	var order: Array = range(cands.size())
	var last: int = _inset_pick.get(key, -1)
	if last >= 0:
		order.erase(last)
		order.push_front(last)
	var pick := -1
	for pass_n in 2:
		for ci in order:
			var rr := Rect2(at + cands[ci], sz)
			if pass_n == 0 and not inner.encloses(rr):
				continue
			var hit := false
			for q in inset_labels:
				if q.intersects(rr):
					hit = true
					break
			if not hit and pass_n == 0:
				for q in _inset_block:
					if q.intersects(rr) and not q.has_point(at):
						hit = true
						break
			if not hit:
				pick = ci
				break
		if pick >= 0:
			break
	if pick < 0:
		pick = 0
	_inset_pick[key] = pick
	var box := Rect2(at + cands[pick], sz)
	inset_labels.append(box)
	return box.position + Vector2(0, 11.0)


# #012: a signal's mark. Unknown, a diamond beating (#125); the moment its analysis lands, the diamond
# morphs (0.58 s, backOut 1.6, swelling 7%) into the hulk's mark turning orange, or into a lump of rock
# going dark
func _marker(sg: Dictionary, at: Vector2, t: float, lit: float, morph_s: float) -> void:
	var g := UiSkin.glow_tex()
	var known: bool = sg.get("known", false)
	var st := float(sg.get("strength", 0.5))
	var dia := Mo.shape("diamond")
	if not known:
		# #125: a double beat every 1.175 s (each signal on its own phase), two rings going out
		var lu := fposmod(t + float(hash(str(sg.id)) % 997) / 997.0 * Mo.BEAT, Mo.BEAT)
		var r0 := (4.5 + st * 3.0) * Mo.beat_scale(lu)
		for ring in Mo.beat_rings(lu):
			var rp := Mo.blend(dia, dia, 0.0, at, r0 * float(ring[0]))
			rp.append(rp[0])
			cv.draw_polyline(rp, Color(UiSkin.DATA, float(ring[1]) * lit), 0.8 + 1.7 * float(ring[2]), true)
		cv.draw_texture_rect(g, Rect2(at - Vector2(16, 16), Vector2(32, 32)), false, Color(UiSkin.DATA, 0.45 * lit))
		var pts := Mo.blend(dia, dia, 0.0, at, r0)
		cv.draw_colored_polygon(pts, Color(UiSkin.DATA, 0.22 * lit))
		pts.append(pts[0])
		cv.draw_polyline(pts, Color(UiSkin.DATA, lit), 1.5, true)
		return
	var ship := str(sg.kind) == "ship"
	var goal := Mo.shape("ship") if ship else Mo.shape("rock", hash(str(sg.id)))
	var end_col := UiSkin.ACCENT if ship else Pal.ink(0.32)
	var mk: Array = Mo.morph_k(morph_s)
	var p: float = mk[0]
	var pc: float = mk[1]
	var r := lerpf(4.5 + st * 3.0, 7.5 if ship else 5.5, clampf(p, 0.0, 1.0)) * float(mk[2])
	var col := UiSkin.DATA.lerp(end_col, pc)
	if ship:
		cv.draw_texture_rect(g, Rect2(at - Vector2(20, 20), Vector2(40, 40)), false, Color(UiSkin.ACCENT, 0.55 * pc))
	if morph_s < 1.2:
		# the moment it is known: a flash and two rings bursting out
		var dk := morph_s / 1.2
		cv.draw_texture_rect(g, Rect2(at - Vector2(40, 40), Vector2(80, 80)), false, Color(end_col if ship else Color.WHITE, 0.55 * (1.0 - dk)))
		for n in 2:
			var rk := clampf(dk * 1.4 - n * 0.25, 0.0, 1.0)
			if rk > 0.0:
				cv.draw_arc(at, 8.0 + rk * 46.0, 0.0, TAU, 40, Color(end_col if ship else UiSkin.DATA, 0.7 * (1.0 - rk)), 1.6, true)
	var pts := Mo.blend(dia, goal, p, at, r)
	cv.draw_colored_polygon(pts, col if ship else Color(0.1, 0.11, 0.13).lerp(Color(UiSkin.DATA, 0.22), 1.0 - pc))
	pts.append(pts[0])
	cv.draw_polyline(pts, col, 1.5 if ship else 1.2, true)


# #005: words rising from behind a line that grows from their middle, clipped above the line
func _reveal_label(pos: Vector2, text: String, col: Color, s: float) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var ly := pos.y + 4.0
	var lg := Mo.reveal_line(s)
	if lg > 0.005:
		var cx := pos.x + tw * 0.5
		cv.draw_rect(Rect2(cx - tw * 0.5 * lg - 2.0, ly, (tw + 4.0) * lg, 1.5), col)
	_rv_text = text
	_rv_col = col
	_rv_drop = Mo.reveal_drop(s) * 14.0
	_rv_clip.visible = true
	_rv_clip.position = Vector2(pos.x - 2.0, pos.y - 13.0)
	_rv_clip.size = Vector2(tw + 6.0, ly - (pos.y - 13.0))
	_rv_ink.size = Vector2(tw + 6.0, 40.0)
	_rv_ink.queue_redraw()


var _rv_text := ""
var _rv_col := Color.WHITE
var _rv_drop := 0.0


func _draw_rv_ink() -> void:
	if _rv_text != "":
		_rv_ink.draw_string(font, Vector2(2, 13.0 + _rv_drop), _rv_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, _rv_col)


# #012: note the moment each signal turns known (only one seen unknown first morphs)
func _watch_signals() -> void:
	var now := Mo.ms() / 1000.0
	for key in Scan.data().sectors:
		for sg in Scan.data().sectors[key].sigs:
			var id := str(sg.id)
			var k: bool = sg.get("known", false)
			if _sig_seen.has(id) and not _sig_seen[id] and k:
				_known_at[id] = now
				_sfx("starmap_morph_ship" if str(sg.get("kind", "")) == "ship" else "starmap_morph_rock")
			_sig_seen[id] = k


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

# ---------------------------------------------------------------- the column's light (2026-11-04)

var _sheens: Array = []          # [button, rect, primary, press ticks s, press pos]
var shot_mouse := Vector2.INF    # screenshots only: where the pointer is taken to be (the real one is never moved)


# #154 on a button: the pointer's light inside it, its edge glowing orange near the pointer; a flash
# from where it is pressed; the page's one action breathing
func _sheen(b: Button, primary := false) -> void:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.material = Fx.material("sheen")
	b.add_child(r)
	var entry := [b, r, primary, -9.0, Vector2.ZERO]
	b.button_down.connect(func():
		entry[3] = Mo.ms() / 1000.0
		entry[4] = b.get_local_mouse_position())
	b.mouse_entered.connect(func(): if not b.disabled: _sfx("starmap_hover", 0.35))
	_sheens.append(entry)


func _push_sheens() -> void:
	var t := Mo.ms() / 1000.0
	var keep: Array = []
	for e in _sheens:
		# check before the typed assignment: a freed button can't be assigned to `Button`
		# (user 2026-11-05: "Trying to assign invalid previously freed instance" here)
		if not is_instance_valid(e[0]) or not is_instance_valid(e[1]) or e[0].is_queued_for_deletion():
			continue
		var b: Button = e[0]
		keep.append(e)
		if not b.is_visible_in_tree():
			continue
		var m: ShaderMaterial = e[1].material
		var acc: bool = e[2] and not b.disabled
		m.set_shader_parameter("size", b.size)
		var lm := (shot_mouse - b.global_position) if shot_mouse.is_finite() else b.get_local_mouse_position()
		m.set_shader_parameter("mouse", lm if not b.disabled else Vector2(-9999, -9999))
		m.set_shader_parameter("amt", 0.22 if acc else 0.35)
		m.set_shader_parameter("press", t - float(e[3]))
		m.set_shader_parameter("press_at", e[4])
		m.set_shader_parameter("breathe", 1.0 if acc else 0.0)
		m.set_shader_parameter("t", t)
	_sheens = keep


# the column comes in: it slides from the right as it fades up, its rows following one by one
func _enter_column() -> void:
	_sfx("starmap_open")
	var pane: Control = find_child("Pane", true, false)
	if pane == null or not UiSkin.motion():
		return
	var l0 := pane.offset_left
	var r0 := pane.offset_right
	pane.offset_left = l0 + 70.0
	pane.offset_right = r0 + 70.0
	pane.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	tw.tween_property(pane, "offset_left", l0, 0.55)
	tw.tween_property(pane, "offset_right", r0, 0.55)
	tw.tween_property(pane, "modulate:a", 1.0, 0.35)


func _stagger(box: Control) -> void:
	if _open_t > 0.4 or not UiSkin.motion():
		return
	var i := 0
	for c in box.get_children():
		if c is CanvasItem:
			c.modulate.a = 0.0
			var tw := create_tween()
			tw.tween_interval(0.18 + i * 0.05)
			tw.tween_property(c, "modulate:a", 1.0, 0.3)
			i += 1


# #005 on a row whose signal has just been analysed: its words rise from behind a line that grows
# from the row's middle (the button keeps its text; only its own drawing of it is held back meanwhile)
class Rise extends Control:
	const Mo := preload("res://scripts/star_map_motion.gd")
	var row: Button
	var t0 := 0.0
	var ink: Control
	var saved := {}
	const KEYS := ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]

	func _init(b: Button, start: float) -> void:
		row = b
		t0 = start
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		ink = Control.new()
		ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ink.draw.connect(_ink)
		add_child(ink)

	func _ready() -> void:
		for k in KEYS:
			saved[k] = row.get_theme_color(k)
			var c: Color = saved[k]
			row.add_theme_color_override(k, Color(c, 0.0))

	func _s() -> float:
		return Mo.ms() / 1000.0 - t0

	func _line_y() -> float:
		return row.size.y - 7.0

	func _process(_dt: float) -> void:
		size = Vector2(row.size.x, _line_y())
		ink.size = row.size
		ink.queue_redraw()
		queue_redraw()
		if _s() > 2.35:
			for k in KEYS:
				row.add_theme_color_override(k, saved[k])
			queue_free()

	func _col() -> Color:
		var k := "font_disabled_color" if row.disabled else "font_color"
		return saved.get(k, Color.WHITE)

	func _ink() -> void:
		var f := row.get_theme_font("font")
		var fs := row.get_theme_font_size("font_size")
		var sb := row.get_theme_stylebox("disabled" if row.disabled else "normal")
		var ml := sb.get_margin(SIDE_LEFT) if sb != null else 12.0
		var mr := sb.get_margin(SIDE_RIGHT) if sb != null else 12.0
		var w := row.size.x - ml - mr
		var lines := f.get_multiline_string_size(row.text, HORIZONTAL_ALIGNMENT_LEFT, w, fs).y
		var y0 := (row.size.y - lines) * 0.5 + f.get_ascent(fs)
		var drop := Mo.reveal_drop(_s()) * row.size.y * 0.9
		ink.draw_multiline_string(f, Vector2(ml, y0 + drop), row.text, HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1, _col())

	func _draw() -> void:
		pass

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE and is_instance_valid(row):
			for k in saved:
				row.add_theme_color_override(k, saved[k])


# the line under a rising row is drawn on the row itself, below the clip
class RiseLine extends Control:
	const Mo := preload("res://scripts/star_map_motion.gd")
	var t0 := 0.0
	var col := Color.WHITE

	func _init(start: float, c: Color) -> void:
		t0 = start
		col = c
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _process(_dt: float) -> void:
		queue_redraw()
		if Mo.ms() / 1000.0 - t0 > 2.4:
			queue_free()

	func _draw() -> void:
		var lg := Mo.reveal_line(Mo.ms() / 1000.0 - t0)
		if lg > 0.005:
			var wd := (size.x - 24.0) * lg
			draw_rect(Rect2(size.x * 0.5 - wd * 0.5, size.y - 7.0, wd, 2.0), col)


func _rise(b: Button, id: String) -> void:
	if not _known_at.has(id):
		return
	var t0 := float(_known_at[id])
	if Mo.ms() / 1000.0 - t0 > 2.0:
		return
	b.clip_contents = true
	var lc := b.get_theme_color("font_color") if b.has_theme_color_override("font_color") else UiSkin.ACCENT
	b.add_child(RiseLine.new(t0, lc if not b.disabled else Pal.ink(0.5)))
	b.add_child(Rise.new(b, t0))


# ---------------------------------------------------------------- sounds (2026-11-04)
# every star-map sound by its name; none is synthesised: a name with no file in assets/audio is
# silent until the recorded or generated sound is put there (the list is in the hand-over note)
var _sig_was := ""
var _job_was := ""


func _sfx(name: String, vol := 1.0) -> void:
	if game != null and game.get("sfx") != null:
		game.sfx.play(name, Vector2.INF, vol)


# the tabs' line: it eases across to the chosen tab (drawn from the first tab, under both)
var _tab_ink: Control
var _tab_x := -1.0


func _draw_tab_line() -> void:
	var on: Button = tab_find if mode == "find" else tab_ships
	var goal := on.global_position.x - tab_find.global_position.x
	_tab_x = goal if _tab_x < -0.5 else lerpf(_tab_x, goal, 1.0 - exp(-14.0 * get_process_delta_time()))
	var y := tab_find.size.y + 3.0
	var wd := on.size.x
	_tab_ink.draw_texture_rect(UiSkin.glow_tex(), Rect2(_tab_x - 20.0, y - 10.0, wd + 40.0, 20.0), false, Color(UiSkin.ACCENT, 0.25))
	_tab_ink.draw_rect(Rect2(_tab_x + 10.0, y - 1.0, wd - 20.0, 2.0), UiSkin.ACCENT)
