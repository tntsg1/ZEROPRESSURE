extends Node2D
# The port on foot (84 号, user 2026-10-26: "要亲自去现场，坐列车。列车是怎么坐的呀？可以有什么用
# 啊？然后去每一个现场，哪个地方它是怎么交互的"): out of the berth, up the corridor to the hub,
# the shuttle to every district, and at each its business console and its engineering desk opened
# by the player's own hand. Each step moves on only when the game sees it done; a page counts once
# it has been opened and closed again (looked at, not just touched). Forced the first time (no way
# to end it); replayed from the pause menu with one. Same card, ring and arrow as the first ship's
# guide (scripts/first_ship.gd). Started by Game.start_port_walk().

const PortStructure = preload("res://scripts/port_structure.gd")
const GuideMark = preload("res://scripts/guide_mark.gd")
# the shuttle's round: the order the districts are visited in
const ROUND := ["power", "tug", "cargo", "trade", "process"]
var game
var forced := true
# 108 号 Q2/Q13 (the outside review: 21 steps at once is too much): the first, forced walk is only
# the core — out of the berth, the ring, the shuttle, home and the berth's repairs ("core"); each
# district is walked the first time the career has a use for it (its zone name, see due_part);
# "all" is the whole round of before
var part := "core"
var steps: Array = []           # [kind, zone]
var step := 0
var resume := 0                 # the step a walk cut short had reached (Career.guide_at)
# user 2026-10-28 ("做完一半之后，重新进来还得重新再玩", Q: back at the very step): a walk picked up
# again starts at that step; if the drone is not where the step is, the legs there come first
# (out of the berth, to the ring, the stop, the ride) — not tour steps, not counted, not kept
var back: Array = []
var done := false
var opened := false             # this step's page has been seen open
var _seen_all := false          # and every callout on it shown
var step_t := 0.0
var t := 0.0
var end_t := 0.0
const STUCK_1 := 20.0
const STUCK_2 := 40.0
const END_S := 5.0
var _why := ""
var _why_t := 99.0
const WHY_S := 6.0
var layer: CanvasLayer
var card: PanelContainer
var count: Label
var title: Label
var body: Label
var close_b: Button


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func due() -> bool:
	if Career.data.is_empty() or Career.data.get("seen", {}).has("port_walk"):
		return false
	return not Career.data.get("history", []).is_empty()


# 108 号 Q13: the walk due now — "core" after the first ship, then a district the first time it is
# of use: the processing district when ingots are first kept for it, power when a line first runs
# short, trade when a sail part can first be listed, cargo when goods first wait in the warehouse,
# the tug station when a hulk found first cannot be towed (too long, or the yard full); a district
# whose moment never comes is walked when the main line first sends the player there
static func due_part(game) -> String:
	if due():
		return "core"
	if Career.data.is_empty():
		return ""
	var seen: Dictionary = Career.data.get("seen", {})
	if not seen.has("port_walk"):
		return ""
	# one district at a time: never two walks back to back, at most one a settled job
	var jobs: int = Career.data.get("history", []).size()
	if jobs <= int(Career.data.get("walk_job", -1)):
		return ""
	var ml := ""
	if Career.usable():
		ml = str(Mainline.step().get("go", ""))
	for z in ROUND:
		if seen.has("walk_" + z) or seen.has("port_walk_all"):
			continue
		if _wants(z, game) or ml == "guide:build:" + z or (z == "process" and ml in ["guide:heat", "guide:assay", "guide:sort"]):
			return z
	return ""


static func _wants(z: String, game) -> bool:
	match z:
		"process":
			return not ProcessQueue.entries().is_empty()
		"power":
			if game == null or not is_instance_valid(game):
				return false
			for l in Grid.loads(game):
				if str(l.state) == "short":
					return true
		"trade":
			for p in Career.data.get("parts", []):
				if Repair.can_list(p):
					return true
		"cargo":
			var stock: Dictionary = Ops._stock()
			for k in stock:
				if float(stock[k]) > 0.05:
					return true
		"tug":
			var offers: Array = Career.data.get("offers", [])
			for i in Scan.found():
				if TugYard.block(str(offers[i].get("ship", ""))) != "":
					return true
	return false


func _key() -> String:
	return "port_walk" if part in ["core", "all"] else "walk_" + part


# 90 号: a walk that was started before and cut short (not the first, forced one)
func again() -> bool:
	return not forced and Career.data.get("seen", {}).has("port_walk_started")


static func plan(which := "all") -> Array:
	# 108 号 Q2: the core — the ring's console (mending a district), the shuttle, home, the repairs
	if which == "core":
		# 131 号 (user 2026-11-05: "不都有列车吗？我为什么不能在拆船厂上等车？"): the shuttle first — out to the
		# berth's own stop in the gate, ride to the ring, back by shuttle; flying the corridor is optional
		return [["station", "salvage"], ["ride", "ring"], ["console", "ring"], ["ride", "salvage"], ["home", ""], ["repair", ""], ["end", ""]]
	# 128 号 第 4 段 收尾 (2026-11-07): the processing district's first walk is its first heat — up onto the
	# gallery, E at the furnace console, a heat queued, the machines watched at work below
	if which == "process" and not ProcessLine.LEGACY_DESKS:
		return [["ride", "process"], ["gallery", "process"], ["furnace", "process"], ["queue", "process"], ["watch", "process"], ["ride", "salvage"], ["home", ""], ["end", ""]]
	if which in ROUND:
		var one: Array = [["ride", which], ["console", which]]
		var extra := {"power": "screen", "trade": "exchange", "cargo": "shelf", "process": "mill"}
		if extra.has(which):
			one.append([extra[which], which])
		one.append_array([["ride", "salvage"], ["home", ""], ["end", ""]])
		return one
	var out: Array = [["station", "salvage"], ["ride", "ring"], ["console", "ring"]]
	for z in ROUND:
		out.append(["ride", z])
		out.append(["console", z])
		if z == "power":
			out.append(["screen", z])
		if z == "trade":
			out.append(["exchange", z])
		# 85 号: the machines and racks stand in the districts, each run where it stands
		if z == "cargo":
			out.append(["shelf", z])
		if z == "process":
			out.append(["mill", z])
	# 97 号: back on the shuttle to the berth's own stop, in the port gate
	out.append(["ride", "salvage"])
	out.append(["home", ""])
	out.append(["end", ""])
	return out


func _ready() -> void:
	z_index = 30
	z_as_relative = false
	# the pages pause the tree (the terminal): the card and its checks go on over them
	process_mode = Node.PROCESS_MODE_ALWAYS
	steps = plan(part)
	resume = Career.guide_at(_key())
	if not Career.data.is_empty():
		Career.data.walk_job = Career.data.get("history", []).size()
	# a walk cut short under the old 21-step round: its step number means nothing in the new one
	if part == "core" and not Career.data.is_empty() and int(Career.data.get("walk_v", 1)) == 2:
		# 131 号: the 8-step core (gate, hub, console, station, ride, home, repair, end) to the 7-step
		# one (station, ride ring, console, ride home, home, repair, end): the same place in the walk
		resume = [0, 1, 2, 3, 3, 4, 5, 6][clampi(resume, 0, 7)]
		Career.data.walk_v = 3
		Career.guide_keep("port_walk", resume)
	if part == "core" and not Career.data.is_empty() and int(Career.data.get("walk_v", 1)) < 2:
		resume = 0
		Career.data.walk_v = 3
		Career.guide_keep("port_walk", 0)
	layer = CanvasLayer.new()
	layer.layer = 65
	add_child(layer)
	card = PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 0)
	card.add_theme_stylebox_override("panel", GuideMark.card_box(UiSkin.ACCENT))
	var col := VBoxContainer.new()
	card.add_child(col)
	var top := HBoxContainer.new()
	count = _label(13, Color(UiSkin.ACCENT, 0.85))
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(count)
	close_b = Button.new()
	close_b.text = w("关掉导览", "END THE TOUR")
	close_b.focus_mode = Control.FOCUS_NONE
	close_b.pressed.connect(stop)
	close_b.visible = not forced
	top.add_child(close_b)
	col.add_child(top)
	title = _label(20, Pal.ink(0.96))
	body = _label(15, Pal.ink(0.66))
	col.add_child(title)
	col.add_child(body)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	overlay.draw.connect(_draw_overlay)
	for i in 4:
		var d := ColorRect.new()
		# hdr_2d blends in linear light: 0.55 barely showed
		d.color = Color(0, 0, 0, 0.8)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d.show_behind_parent = true
		overlay.add_child(d)
		dims.append(d)
	overlay.gui_input.connect(_overlay_input)
	layer.add_child(overlay)
	layer.add_child(card)
	if resume > 0 and resume < steps.size():
		step = resume
		back = _legs_to(step)
	elif part in ROUND:
		# a district's walk starts in the berth: out to the ring first (legs, not counted)
		back = _legs_to(0)
	_begin()


func _label(size_px: int, c: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 480
	return l


func kind() -> String:
	if not back.is_empty():
		return str(back[0][0])
	return str(steps[step][0]) if step < steps.size() else ""


func zone() -> String:
	if not back.is_empty():
		return str(back[0][1])
	return str(steps[step][1]) if step < steps.size() else ""


# the legs from where the drone is to where step s happens
func _legs_to(s: int) -> Array:
	var k := str(steps[s][0])
	var z := str(steps[s][1])
	if k in ["gate", "home", "end", "repair"]:
		return []
	# 131 号: by shuttle — out to the berth's own stop in the gate, the ride to where the step is
	var need := "ring" if k == "hub" else (z if z != "" else "ring")
	var d = game.drone
	# A resumed ride may already be complete: in particular, the berth itself
	# counts as arrival at the salvage stop. Do not send the player out to that
	# stop only to immediately send them back into the berth.
	if k == "ride" and d != null and arrived(z, d.global_position):
		return []
	var here := PortStructure.zone_at(d.global_position) if d != null else ""
	if here == need or k == "station" and z == "salvage":
		return []
	var legs: Array = [["station", "salvage"]]
	if k == "ride":
		return legs
	legs.append(["ride", need])
	return legs


# flying only: no tool is open on the tour
func tool_allowed(_n: int) -> bool:
	return done


func _begin() -> void:
	opened = false
	_seen_all = false
	_repair_t = 0.0
	co_i = 0
	step_t = 0.0
	if game.tools != null and game.tools.has_method("release_grab"):
		game.tools.release_grab(false)
	var tg := target()
	if tg != Vector2.INF and kind() in ["gate", "hub", "station", "home"]:
		game.plan_focus = tg
		game.plan_focus_t = 2.0
	_show()


# ---------------------------------------------------------------- where things are

func _gate_x() -> float:
	return game.dock.port_gate().get_center().x * Geom.M


func _rail_y() -> float:
	return Dock.RAIL_Y * Geom.M


func _berth_rect() -> Rect2:
	return Rect2(Dock.BOUNDS.position * Geom.M, Dock.BOUNDS.size * Geom.M)


# the station the drone should board at for this ride: where the last ride left it
func _board_at() -> String:
	# 131 号: legs (and a walk picked up again) board at the berth's own stop
	if not back.is_empty() or step == resume and resume > 0:
		return "salvage"
	for i in range(step - 1, -1, -1):
		if str(steps[i][0]) in ["ride", "station"]:
			return str(steps[i][1])
	return "salvage"


func target() -> Vector2:
	if done or step >= steps.size():
		return Vector2.INF
	match kind():
		"desk":
			return game.port_access.spot(zone()) if game.port_access != null else Vector2.INF
		"console", "screen", "exchange":
			return PortStructure.console_spot(zone())
		"shelf":
			return preload("res://scripts/cargo_floor.gd").mouth("A")
		"mill":
			return preload("res://scripts/mill_line.gd").pedestal()
		"gallery":
			return preload("res://scripts/process_gallery.gd").at(Vector2(50.0, preload("res://scripts/process_gallery.gd").FLY_Y))
		"furnace", "queue":
			return preload("res://scripts/process_gallery.gd").term("furnace")
		"watch":
			var pl = game.get("plant")
			return Vector2(float(pl.X) + 1.0, float(pl.F) + 5.0) * Geom.M if pl != null else preload("res://scripts/process_gallery.gd").term("furnace")
		"gate":
			return Vector2(_gate_x(), _rail_y() - 8.0 * Geom.M)
		"hub":
			return Backdrop.port_centre_px()
		"station":
			return Tram.station_at(zone() if zone() != "" else "ring")
		"ride":
			if game.tram != null and game.tram.riding:
				return Tram.station_at(zone())
			return Tram.station_at(_board_at())
		"home":
			return Vector2(_gate_x(), _rail_y() + 8.0 * Geom.M)
	return Vector2.INF


func target_name() -> String:
	match kind():
		"desk":
			return Port.name_of(zone()) + " · " + Txt.t("pt_access_terminal")
		"console", "screen", "exchange":
			return Port.name_of(zone()) + " · " + Txt.t("pt_console_business")
		"shelf":
			return w("货架口 A（左边货架）", "RACK MOUTH A (LEFT RACKS)")
		"mill":
			return w("轧机操作台", "MILL PEDESTAL")
		"gallery":
			return w("观察廊上方的走廊", "THE CORRIDOR OVER THE GALLERY")
		"furnace":
			return w("炉体控制台", "FURNACE CONSOLE")
		"queue":
			return w("加工队列 · 排一炉", "PROCESSING QUEUE · A HEAT")
		"watch":
			return w("电弧炉", "ARC FURNACE")
		"gate":
			return w("港区通道", "PORT ACCESS")
		"hub":
			return Port.name_of("ring")
		"station":
			return w("接驳站", "SHUTTLE STOP") + (" · " + Port.name_of(zone()) if zone() != "" else "")
		"ride":
			return w("接驳站 → ", "STOP → ") + Port.name_of(zone())
		"home":
			return w("七号船坞", "BERTH 07")
		"repair":
			return w("终端 · 船坞", "TERMINAL · BERTH")
	return ""


# ---------------------------------------------------------------- the pages

func _page() -> String:
	var ui = game.console_ui
	if ui == null or not is_instance_valid(ui):
		return ""
	var path := str(ui.get_script().resource_path) if ui.get_script() != null else ""
	if path.ends_with("district_panel.gd"):
		return "console:" + str(ui.zone)
	if path.ends_with("power_panel.gd"):
		return "screen:power"
	if path.ends_with("exchange_panel.gd"):
		return "exchange:trade"
	if path.ends_with("transit_panel.gd"):
		return "transit"
	if path.ends_with("mill_panel.gd"):
		return "mill:process"
	if path.ends_with("process_queue_panel.gd"):
		return ("queue" if kind() in ["queue", "watch"] else "furnace") + ":process"
	if path.ends_with("shelf_panel.gd"):
		return "shelf:cargo"
	if path.ends_with("company_store.gd") and kind() == "shelf" and zone() == "cargo":
		return "shelf:cargo"
	if ui.get("route_panel") != null:
		var rp = ui.route_panel
		if rp != null and str(rp.selected).begins_with("port:"):
			return "desk:" + str(rp.selected).substr(5)
		return "terminal:%d" % int(ui.get("tab")) if ui.get("tab") != null else "terminal"
	return "other"


func page_open() -> bool:
	if kind() == "repair":
		return _page() == "terminal:1"
	return _page() == kind() + ":" + zone()


# the drone at the end of a ride to z: at z's stop, in z itself, or (the berth's own stop) back in the berth
static var ARRIVED_ON := true   # tests: false is the walk as it was (only the ride itself counted: the before picture)
func arrived(z: String, p: Vector2) -> bool:
	if not ARRIVED_ON:
		return game.tram.at == z and game.tram.phase == "" and p.distance_to(Tram.station_at(z)) < 12.0 * Geom.M
	if p.distance_to(Tram.station_at(z)) < 12.0 * Geom.M:
		return true
	if z == "salvage":
		return _berth_rect().has_point(p)
	return PortStructure.zone_at(p) == z


func passed() -> bool:
	var d = game.drone
	match kind():
		"desk", "console", "screen", "exchange", "shelf", "mill":
			# every framed part seen, then closed (power's and trade's consoles lead on to their next page)
			if kind() == "console" and zone() in ["power", "trade"]:
				return opened and page_open() and callouts_done()
			return opened and _seen_all and game.console_ui == null
		"gallery":
			if d == null:
				return false
			var gl: Vector2 = (d.global_position - PortStructure.box("process").position) / Geom.M
			return gl.y < preload("res://scripts/process_gallery.gd").DECK and gl.x < preload("res://scripts/process_gallery.gd").X1 and gl.x > preload("res://scripts/process_gallery.gd").X0
		"furnace":
			return page_open()
		"queue":
			return not ProcessQueue.open_entries().is_empty() or str(Career.data.get("industrial_heat", {}).get("state", "")) not in ["", "complete", "cancelled", "written_off"]
		"watch":
			# the machines seen at work: the ingots in the furnace and melting (or further on)
			var ih = game.get("industrial_heat")
			# (nothing to melt — no ingots, the grid short — the walk does not wait for ever)
			return ih != null and (str(ih.info().key) in ["melting", "probe", "tapping", "cooling", "returning"] and step_t > 2.0 or step_t > 45.0)
		"gate":
			return d != null and d.global_position.y < _rail_y() - 6.0 * Geom.M
		"hub":
			return d != null and PortStructure.zone_at(d.global_position) == "ring"
		"station":
			return game.tram != null and game.tram.near_station() == (zone() if zone() != "" else "ring")
		"ride":
			# 131 号: the car parked at the stop is not the ride — the drone has to be there with it
			if game.tram == null or game.tram.riding or d == null:
				return false
			# 2026-11-09 (user: "我本来就在拆船区，我去拆船区干什么"): the ride is for getting there; a drone
			# already there — flown there by itself, or back inside the berth for the berth's own stop — has
			# done it (the step goes by at once, it is never told to go where it is)
			return arrived(zone(), d.global_position)
		"home":
			return d != null and _berth_rect().has_point(d.global_position) and d.global_position.y > _rail_y()
		"repair":
			# looked at a while, then closed
			return opened and _repair_t >= 3.0 and game.console_ui == null
		"end":
			return end_t >= END_S
	return false


# ---------------------------------------------------------------- the card

func _show() -> void:
	_fill()
	if card != null:
		card.reset_size()


# user 2026-10-26 ("左边下面放一大段文字绝对不要……空框选择按钮，然后告诉我这个是什么用"): the card
# says only where to go and what to press, one short line under it; what a page is for is said
# on the page itself, one framed control at a time (the callouts below)
func _fill() -> void:
	var e: String = Keys.label("use")
	count.text = (w("接着上次的港区导览 · %d / %d", "THE PORT ON FOOT, CONTINUED · %d / %d") if again() else w("港区现场导览 · %d / %d", "THE PORT ON FOOT · %d / %d")) % [step + 1, steps.size()]
	if part in ROUND:
		count.text = w("%s现场导览 · %d / %d", "THE %s ON FOOT · %d / %d") % [Port.name_of(part), step + 1, steps.size()]
		if not back.is_empty():
			count.text = w("%s现场导览 · 先出坞，到中央环", "THE %s ON FOOT · OUT TO THE RING FIRST") % Port.name_of(part)
	elif not back.is_empty():
		var bz := str(steps[step][1]) if step < steps.size() else ""
		count.text = w("接着上次的港区导览 · 先回到%s（第 %d / %d 步）", "THE PORT ON FOOT · BACK TO THE %s FIRST (STEP %d OF %d)") % [Port.name_of(bz if bz != "" else "ring"), step + 1, steps.size()]
	var z := zone()
	var nm := Port.name_of(z) if z != "" else ""
	var line := ""
	match kind():
		"desk":
			title.text = w("%s工程台：飞到亮圈，按 %s", "%s DESK: TO THE LIT RING, PRESS %s") % [nm, e]
		"console":
			title.text = w("%s业务终端：飞到亮圈，按 %s", "%s CONSOLE: TO THE LIT RING, PRESS %s") % [nm, e]
		"screen":
			title.text = w("点“动力区控制屏”", "CLICK 'POWER CONTROL SCREEN'")
			line = w("在动力区业务终端里（按 %s 打开）", "In the power console (%s opens it)") % e
		"exchange":
			title.text = w("点“打开交易行”", "CLICK 'OPEN THE EXCHANGE'")
			line = w("在贸易港业务终端里（按 %s 打开）", "In the trade console (%s opens it); F8 anywhere too") % e
		"shelf":
			title.text = w("飞到左边货架口，按 %s 打开仓库", "FLY TO THE LEFT RACK AND PRESS %s TO OPEN THE STORES") % e
			line = w("两个货架口都能打开同一个公司仓库，看看拆回来的东西。", "Both racks open the same company stores, where the recovered goods are kept.")
		"mill":
			title.text = w("轧机操作台：飞到亮圈，按 %s", "THE MILL'S PEDESTAL: TO THE LIT RING, PRESS %s") % e
			line = w("轧机就站在区里：钢坯从左边进，钢板 / 型材从右边出", "The mill stands here: billet in on the left, plate out on the right")
		"gallery":
			title.text = w("往上飞到观察廊上方的走廊", "UP INTO THE CORRIDOR OVER THE GALLERY")
			line = w("机器在廊道下面。栏杆上的矮台子就是它的控制台。", "The machines work under the gallery; their consoles stand on its railing, each over its machine")
		"furnace":
			title.text = w("飞到最左边的炉体控制台，按 %s", "TO THE FURNACE CONSOLE AT THE FAR LEFT, PRESS %s") % e
			line = w("这儿排炉：炼什么、先炼哪批。", "It opens the processing queue: what is melted, which batch first")
		"queue":
			title.text = w("按『排一炉』（或按 Enter）", "PRESS 'QUEUE A HEAT' (OR ENTER)")
			line = w("把仓库里的钢锭排一炉，炉子按队列自己开炉、熔化、浇铸", "A heat of the ingots in store; the furnace starts, melts and casts by itself")
			if page_open():
				title.text = w("加工队列 · 按『排一炉』（或按 Enter）", "THE QUEUE · PRESS 'QUEUE A HEAT' (OR ENTER)")
			elif not page_open():
				title.text = w("回到炉体控制台按 %s，再按『排一炉』", "BACK TO THE FURNACE CONSOLE: %s, THEN 'QUEUE A HEAT'") % e
		"watch":
			var ih = game.get("industrial_heat")
			title.text = w("往下看：%s", "LOOK DOWN: %s") % (str(ih.info().title) if ih != null else "")
			line = w("料自己送到炉口，炉子自己熔、自己浇。不用按，关掉面板看就行。", "The forklift and the trolley bring the ingots, the arcs melt them, the melt is cast; nothing to press")
		"gate":
			title.text = w("出坞：沿青色箭头往上飞", "OUT: UP ALONG THE CYAN ARROWS")
			line = w("船坞空着时，顶上这道门通向整个港区", "With the berth empty, this gate opens on the port")
		"hub":
			title.text = w("沿走廊飞进中央转运环", "UP THE CORRIDOR INTO THE RING")
			line = w("港的中心，六条走廊通六个区", "The port's heart: six corridors, six districts")
		"station":
			title.text = w("飞到中央环的接驳站", "TO THE SHUTTLE STOP")
			if zone() == "salvage":
				# 131 号 占位: the berth's own stop, first
				title.text = w("出坞：飞到闸门外的拆船区接驳站", "OUT: TO THE BERTH'S SHUTTLE STOP BY THE GATE")
				line = w("坐车最快。自己飞也行。", "The shuttle is the easy way round; flying the corridors is up to you")
			line = w("接驳车走走廊和中央环，不撞墙，约 10 秒到任何区", "The shuttle runs every corridor: no walls, ~10 s anywhere")
		"ride":
			title.text = w("坐车去%s：站台按 %s，点“%s”", "RIDE TO THE %s: %s AT THE STOP, CLICK '%s'") % [nm, e, nm]
			line = w("车不在这站会先开过来接你", "If the car is elsewhere it comes for you first")
			if game.tram != null and game.tram.riding:
				title.text = w("车上：去%s", "ABOARD: TO THE %s") % nm
				line = w("什么都不用按，到站自己下车", "Nothing to press; you step off at the stop")
		"home":
			title.text = w("下车往下，穿过闸门回七号船坞", "DOWN THROUGH THE GATE TO BERTH 07")
			# 2026-11-09 占位 (flown back by itself, the car not here: there is no getting off)
			if game.tram != null and game.tram.at != "salvage":
				title.text = w("往下飞，穿过闸门回七号船坞", "DOWN THROUGH THE GATE TO BERTH 07")
			line = w("以后进出港区：拆船区站上车，下车就是船坞", "In and out of the port: the stop in the gate is the berth's own")
		"repair":
			title.text = w("按 %s 打开终端，点“船坞”", "PRESS %s, OPEN 'BERTH'") % Keys.label("terminal")
			line = w("看看船坞哪些设施坏了、修好有什么用", "See what in the berth is broken, and what mending it does")
			if page_open():
				title.text = w("船坞 · 设施", "BERTH · FACILITIES")
				line = w("红的是坏的。修要零件和钱，零件从拆下的设备里来。Esc 关掉。", "Red is broken: lights let you see, the furnace pays more. Mending takes parts and money; parts come from the machines you strip. Esc closes")
		"end":
			title.text = w("导览完成", "TOUR DONE")
			line = w("拆船挣钱，挣了修港，港修好了挣得更多。", "Strip for money → mend the districts → faster, better paid")
	if page_open() and kind() not in ["repair", "furnace", "queue", "watch"]:
		title.text = (nm + " · " if nm != "" else "") + {"desk": Txt.t("pt_access_terminal"), "console": Txt.t("pt_console_business"), "screen": w("控制屏", "CONTROL SCREEN"), "exchange": w("交易行", "EXCHANGE"), "shelf": w("公司仓库", "COMPANY STORES"), "mill": w("轧机", "ROLLING MILL")}.get(kind(), "")
		var left := _callouts().size() - co_i
		line = w("看亮框。点一下，下一条（还剩 %d 条）", "THE FRAMED PART: CLICK OR SPACE FOR THE NEXT (%d LEFT)") % left if left > 0 else w("看完了：按 Esc 关掉", "DONE: PRESS ESC TO CLOSE")
	elif _why != "" and _why_t < WHY_S and kind() != "end" and not (kind() == "repair" and page_open()):
		line = _why
	if step_t >= STUCK_1 and kind() in ["desk", "console", "gate", "hub", "station", "ride", "home", "shelf", "mill"] and not page_open():
		line = w("找不到？跟着无人机旁的箭头飞", "CAN'T FIND IT? FOLLOW THE ARROW BY THE DRONE")
	body.text = line
	body.visible = line != ""
	# 131 号: the way in front of the title while flying there ("往上飞 → "), the words after it unchanged
	if way != null and _way_on() and not page_open():
		title.text = way.prefix() + title.text


# ---------------------------------------------------------------- the callouts

# per page: [where, what it is for] — where is "m:<member>" (a node the page keeps), "b:<button
# text it begins with>" or "l:<label or section text it contains>"; missing or off-screen ones
# are passed over
func _callouts() -> Array:
	var pg := _page()
	if pg != kind() + ":" + zone():
		return []
	var close := ["b:" + w("关闭", "CLOSE"), w("看完按 Esc 或点这里关掉", "Esc or this closes it")]
	# every district is mended from its own console (no desks: user 2026-10-26, Jev C)
	var fix := [["l:" + w("本区修复", "MEND THIS DISTRICT"), w("修下一期要的东西，打勾的是够了", "What the next stage takes; ticked when you have it")],
		["b:" + w("自己修", "MEND IT YOURSELF"), w("用仓库里的零件和钢锭修，花钱少", "Parts and ingots from stock: cheaper")],
		["b:" + w("请施工队", "HIRE A CREW"), w("不用材料，花钱多", "No materials: dearer")]]
	match pg:
		"console:ring":
			return [["m:stage_box", w("本区第几期、下一期还缺什么", "This district's stage and what the next lacks")], fix[0], fix[1], fix[2],
				["m:overview", w("七个区一眼看完：几期、能用什么", "All seven districts at a glance")],
				["b:" + w("船坞终端", "BERTH TERMINAL"), w("打开合同与建设的大终端", "The big terminal: contracts and works")], close]
		"console:power":
			return [["m:stage_box", w("本区第几期、下一期还缺什么", "This district's stage and what the next lacks")], fix[0], fix[1], fix[2],
				["m:readout", w("全港发电、用电，谁在用", "The port's power: made, used, by whom")],
				["b:" + w("动力区控制屏", "POWER CONTROL"), w("下一步点它，进控制屏", "Click it next: the control screen")]]
		"console:tug":
			return [["m:stage_box", w("本区第几期、下一期还缺什么", "This district's stage and what the next lacks")], fix[0], fix[1], fix[2],
				["m:readout", w("拖船泊位、能拖多长的船", "The tug berths, the longest ship they take")], close]
		"console:cargo":
			return [["m:stage_box", w("本区第几期、下一期还缺什么", "This district's stage and what the next lacks")], fix[0], fix[1], fix[2],
				["m:readout", w("库存、在途、叉车", "Stock, transit, forklifts")],
				["l:" + w("左边货架 A1", "Racks A1"), w("货架在区里两侧，到货架下按 E", "The racks are at the racks")], close]
		"console:trade":
			return [["m:stage_box", w("本区第几期、下一期还缺什么", "This district's stage and what the next lacks")], fix[0], fix[1], fix[2],
				["l:" + w("上门的客人", "AT THE PIER"), w("码头边想买卖东西的小船", "Little ships at the pier, buying and selling")],
				["l:" + w("三大公司", "THE COMPANIES"), w("三家公司长期收什么、给什么价", "What the three companies keep buying")],
				["b:" + w("打开交易行", "OPEN THE EXCHANGE"), w("下一步点它，进交易行", "Click it next: the exchange")]]
		"console:process":
			return [["m:stage_box", w("本区第几期、下一期还缺什么", "This district's stage and what the next lacks")], fix[0], fix[1], fix[2],
				["l:" + w("轧机在本区中部", "The mill stands"), w("轧机不在这里开：飞到轧机操作台", "The mill is run at the mill: fly to its pedestal")],
				["l:" + w("气体线", "GAS LINE"), w("抽回来的气做成液氧卖", "Recovered air made into LOX to sell")], close]
		"screen:power":
			return [["m:lines", w("单线图：电从机组到每条线路", "The lines: from the sets to every feeder")],
				["m:gauges", w("每台机组的出力、转速、冷却", "Each set: output, speed, coolant")],
				["m:trend", w("最近 5 分钟用电 vs 容量", "Five minutes of load against capacity")],
				["m:cap_slider", w("熔炉最多能用多少电", "How much the furnace may draw")],
				["m:order_box", w("电力不足时谁先用", "Who comes first when underpowered")], close]
		"mill:process":
			return [["m:recipe_box", w("配方：点一块，下一次就轧它", "Recipe: pick one, the next pass rolls it")],
				["m:in_slot", w("进料：仓库里的钢坯，每次 1 t", "In: billet in stock, a tonne a pass")],
				["m:bar", w("这一次轧到哪了、还剩几秒", "This pass: how far, how long")],
				["m:out_slot", w("出料：轧好的进仓库", "Out: rolled goods go to the warehouse")],
				["m:lamp_label", w("状态灯：在轧 / 等钢坯 / 电力不足，原因写在这", "The lamp: rolling, waiting or underpowered, and why")],
				["m:loop_b", w("连续轧：有钢坯就一直轧", "Roll on: keeps rolling while there is billet")], close]
		"shelf:cargo":
			if str(game.console_ui.get_script().resource_path).ends_with("company_store.gd"):
				return [["m:grid_view", w("这里展示公司物品，导览结束后可点击查看详情。", "Company goods are here; select one for details after the tour.")],
					["r:f:all", w("上方分类可以筛选原料、设备等物品。", "Use the categories above to filter materials and equipment.")],
					["r:close", w("看完按 Esc 或点这里关闭，继续导览。", "Press Esc or close here to continue the tour.")]]
			return [["m:rows_box", w("这一边的四排：放什么、上面有什么", "This side's four rows: their use, what is on them")],
				["l:" + w("上面：", "ON IT:"), w("这一排现在放着的货和吨数", "What is on the row now, in tonnes")], close]
		"exchange:trade":
			return [["b:" + w("购买", "BUY"), w("买原料和钢材", "Buy feed and steel")],
				["b:" + w("出售", "SELL"), w("卖钢锭、气体、拆下的设备", "Sell ingots, gases, stripped machines")],
				["b:" + w("交易记录", "RECORDS"), w("每一笔买卖和挂单", "Every trade and listing")],
				["b:" + w("航运", "SHIPPING"), w("在路上的货", "Goods on their way")],
				["b:" + w("船市", "HULK"), w("买二手船来拆", "Buy hulks to strip")]]
	if pg.begins_with("desk:"):
		return [["b:" + w("自己修", "REPAIR IT YOURSELF"), w("用仓库里的零件和钢锭修，花钱少", "Parts and ingots from stock: cheaper")],
			["b:" + w("请施工队", "HIRE"), w("不用材料，花钱多", "No materials: dearer")]]
	return []


var _repair_t := 0.0            # 108 号: time the berth page has been open on the repair step
var co_i := 0                   # the callout shown on this step's page
var _co_page := ""
var overlay: Control
var dims: Array = []


func _co_rect(spec: String) -> Rect2:
	var ui = game.console_ui
	if ui == null or not is_instance_valid(ui):
		return Rect2()
	var node: Control = null
	if spec.begins_with("r:"):
		var buttons: Dictionary = ui.get("_btns") if ui.get("_btns") is Dictionary else {}
		var local: Rect2 = buttons.get(spec.substr(2), Rect2())
		if local.size == Vector2.ZERO:
			return Rect2()
		return ui.get_global_transform_with_canvas() * local
	if spec.begins_with("m:"):
		var v = ui.get(spec.substr(2))
		if v is Control:
			node = v
	else:
		var want := spec.substr(2)
		for n in ui.find_children("*", "Control", true, false):
			if not n.is_visible_in_tree():
				continue
			if spec.begins_with("b:") and n is Button and str(n.text).begins_with(want):
				node = n
				break
			if spec.begins_with("l:") and not n is Button and str(n.get("text") if n.get("text") != null else "").contains(want):
				node = n
				break
	if node == null or not node.is_visible_in_tree():
		return Rect2()
	var r := node.get_global_rect()
	var vs := get_viewport().get_visible_rect()
	return r if vs.intersects(r) and r.size.x > 2.0 else Rect2()


# the callouts still to show, skipping those not on the page
func _co_now() -> Array:
	var list := _callouts()
	while co_i < list.size() and _co_rect(str(list[co_i][0])).size == Vector2.ZERO:
		co_i += 1
	if co_i >= list.size():
		return []
	return list[co_i]


func callouts_done() -> bool:
	return _co_now().is_empty()


func _co_next() -> void:
	co_i += 1
	game.sfx.play("menu", Vector2.INF, 0.6)
	_show()


func _draw_overlay() -> void:
	if done or not page_open():
		return
	var c := _co_now()
	if c.is_empty():
		return
	var r := _co_rect(str(c[0])).grow(6.0)
	var vs := overlay.get_viewport_rect().size
	# the rest of the screen dimmed round the frame (four rects as nodes: drawn rects did not show)
	var parts := [Rect2(0, 0, vs.x, r.position.y), Rect2(0, r.end.y, vs.x, vs.y - r.end.y), Rect2(0, r.position.y, r.position.x, r.size.y), Rect2(r.end.x, r.position.y, vs.x - r.end.x, r.size.y)]
	for i in 4:
		dims[i].position = parts[i].position
		dims[i].size = parts[i].size
	var k := 0.7 + 0.3 * sin(t * 5.0)
	overlay.draw_rect(r, Color(UiSkin.ACCENT, k), false, 3.0)
	# one short line beside the frame: below it, else above
	var font := Fonts.get_font("Medium")
	var txt := str(c[1])
	var sub := w("点一下 / 空格：下一条", "CLICK / SPACE: NEXT")
	var tw := maxf(font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x, font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x) + 28.0
	# beside the frame where there is room (the pages sit on the right), else under it, else over it
	var bp := Vector2(r.position.x - tw - 16.0, r.get_center().y - 32.0)
	if bp.x < 10.0:
		bp = Vector2(r.end.x + 16.0, r.get_center().y - 32.0)
	if bp.x + tw > vs.x - 10.0:
		bp = Vector2(clampf(r.position.x, 10.0, vs.x - tw - 10.0), r.end.y + 10.0)
		if bp.y + 64.0 > vs.y - 10.0:
			bp.y = r.position.y - 74.0
	bp.y = clampf(bp.y, 10.0, vs.y - 74.0)
	overlay.draw_line(Vector2(bp.x + tw if bp.x < r.position.x else bp.x, bp.y + 32.0), Vector2(r.position.x if bp.x < r.position.x else r.end.x, clampf(bp.y + 32.0, r.position.y, r.end.y)), UiSkin.ACCENT, 1.5)
	var box := Rect2(bp, Vector2(tw, 64.0))
	overlay.draw_rect(box, Color(0.06, 0.07, 0.08, 0.97))
	overlay.draw_rect(box, UiSkin.ACCENT, false, 1.5)
	overlay.draw_string(font, bp + Vector2(14, 28), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Pal.ink(0.97))
	overlay.draw_string(font, bp + Vector2(14, 52), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(UiSkin.ACCENT, 0.9))


func _overlay_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not _co_now().is_empty():
		_co_next()
		overlay.accept_event()


func _input(ev: InputEvent) -> void:
	if done or not page_open() or _co_now().is_empty():
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode in [KEY_SPACE, KEY_ENTER]:
		_co_next()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- each frame

func _process(dt: float) -> void:
	# 91 号 (user: the walk's card lay over the terminal's "find a ship" key): not over the terminal page
	if layer != null and game != null:
		var term_open: bool = game.console_ui != null and is_instance_valid(game.console_ui) and (game.console_ui as Node).is_in_group("terminal")
		# user 2026-11-05 (two guides talking at once): the star map has its own tour, the walk's card waits
		var map_open: bool = game.console_ui != null and is_instance_valid(game.console_ui) and (game.console_ui as Node).get_script() != null and str((game.console_ui as Node).get_script().resource_path).ends_with("star_map.gd")
		# 131 号 追加 (user: the card lay over the terminal's keys): never over a full-screen page — on
		# the terminal its step is shown on the key it means (terminal.gd _walk_mark), the stores too
		var store_open: bool = game.console_ui != null and is_instance_valid(game.console_ui) and (game.console_ui as Node).get_script() != null and str((game.console_ui as Node).get_script().resource_path).ends_with("company_store.gd")
		layer.visible = not map_open and not term_open and (not store_open or (kind() == "shelf" and zone() == "cargo"))
	if done or game == null or step >= steps.size():
		return
	_place_card()
	t += dt
	var was := step_t
	step_t += dt
	var why_was := _why_t
	_why_t += dt
	if kind() == "end":
		end_t += dt
	var shown_open := opened
	if kind() == "repair" and page_open():
		_repair_t += dt
	if page_open():
		opened = true
		if callouts_done():
			_seen_all = true
	if overlay != null:
		overlay.visible = page_open() and not _co_now().is_empty()
		overlay.queue_redraw()
	if opened != shown_open or (was < STUCK_1 and step_t >= STUCK_1) or (why_was < WHY_S and _why_t >= WHY_S) or fmod(t, 0.5) < dt:
		_show()
	if passed():
		if kind() == "end":
			stop()
			return
		game.sfx.play("menu", Vector2.INF, 0.8)
		_why = "✓ " + _done_line()
		_why_t = 0.0
		next_step()
	queue_redraw()


func next_step() -> void:
	if not back.is_empty():
		back.pop_front()
		_begin()
		return
	step += 1
	Career.guide_keep(_key(), step)
	_begin()


# what the step just done taught, one line
func _done_line() -> String:
	var nm := Port.name_of(zone()) if zone() != "" else ""
	match kind():
		"desk": return w("%s工程台用过了：修这个区就来这里", "%s desk done: this is where the district is mended") % nm
		"shelf", "mill": return Ops.w("%s用过了", "%s done") % target_name()
		"gallery": return w("上了观察廊：沿这条走廊能直飞过全场", "On the gallery: this corridor runs the whole hall")
		"furnace": return w("加工队列开了：以后在这里排产", "The queue is open: this is where the work is ordered")
		"queue": return w("排上了：炉子会自己开炉", "Queued: the furnace starts by itself")
		"watch": return w("炉子在熔化了：出钢后钢坯自己回仓库", "Melting: the billets go back to the stores by themselves")
		"console", "screen", "exchange": return w("%s看过了", "%s seen") % nm
		"gate": return w("出坞了：船坞空着时从这道门进出港区", "Out: with the berth empty, this gate is the way into the port")
		"hub": return w("到中央环了", "In the ring")
		"station": return w("这就是站台：按 %s 叫车", "This is a stop: %s calls the car") % Keys.label("use")
		"ride":
			if zone() == "ring":
				# 131 号 占位: off at the hub — the carousel in the middle, the corridors out
				return w("到中央转运环了：中间是转盘，六条走廊通六个区", "At the ring: the carousel in the middle, six corridors out")
			return w("到%s了：站就在区门里，业务终端在旁边", "At the %s: the stop is inside the door, the console beside it") % nm
		"home": return w("回到船坞了", "Back in the berth")
		"repair": return w("船坞的修缮在终端“船坞”页", "The berth's repairs are on the terminal's BERTH page")
	return ""


# top right like the first ship's card; over a page, bottom left out of its way
func _place_card() -> void:
	var vs := get_viewport().get_visible_rect().size
	# 108 号 (user 2026-10-30, a shot: the card lay on the drone's telemetry, bottom left): a page counts
	# only while it is really on screen, and over the world with the HUD still showing (a district's
	# console) the card goes top left under the main-line card, not on the telemetry
	var ui = game.console_ui
	var page_open: bool = ui != null and is_instance_valid(ui) and ui is CanvasItem and (ui as CanvasItem).is_visible_in_tree()
	var hud_on: bool = game.hud != null and game.hud.visible and game.visible
	if page_open and kind() == "repair":
		# the berth page keeps its left foot for its own key line; its right foot is free
		card.position = Vector2(vs.x - card.size.x - 40.0, vs.y - card.size.y - 80.0)
	elif page_open and not hud_on:
		card.position = Vector2(22.0, vs.y - card.size.y - 22.0)
	elif page_open:
		card.position = Vector2(22.0, 124.0)
	else:
		card.position = Vector2(vs.x - card.size.x - 22.0, 124.0)


func stop() -> void:
	if done:
		return
	done = true
	card.visible = false
	var seen: Dictionary = Career.data.get("seen", {})
	seen[_key()] = true
	if part == "all":
		seen["port_walk_all"] = true
	Career.data.seen = seen
	Career.save()
	queue_redraw()


# 131 号 (user 2026-11-05, Q: A): the way to a place shown as every "fly there" guide shows it
# (scripts/guide_way.gd): lit chevrons along the corridors, the arrow on the screen's edge with the
# metres left, the way in front of the card's title; folded away at the target
const GuideWay = preload("res://scripts/guide_way.gd")
const FLY_KINDS := ["desk", "console", "shelf", "mill", "gate", "hub", "station", "ride", "home", "gallery", "furnace"]
var way = null
var _way_t := 0.0


func _way_on() -> bool:
	return not done and game != null and game.console_ui == null and step < steps.size() and kind() in FLY_KINDS \
		and not (game.tram != null and game.tram.riding) and game.drone != null and game.drone.visible


func _draw() -> void:
	if way == null:
		way = GuideWay.new()
		way.attach(self)
	var dt := clampf(t - _way_t, 0.0, 0.1)
	_way_t = t
	var fly := _way_on()
	var d = game.drone if game != null else null
	way.update(game, d.global_position if fly else Vector2.INF, target() if fly else Vector2.INF, dt)
	if done or game == null or game.console_ui != null:
		way.hide()
		return
	var at := target()
	if at == Vector2.INF:
		return
	var z: float = maxf(game.cam_zoom(), 0.02)
	var big := 1.6 if step_t >= STUCK_2 else 1.0
	GuideMark.target(self, at, z, UiSkin.ACCENT, t, target_name(), 26.0, big)
	if d != null and d.visible:
		GuideMark.arrow(self, game.look.lamp_pos() if game.look != null else d.global_position, at, z, UiSkin.ACCENT, t)
	if fly:
		way.draw_edge(self, target_name(), UiSkin.ACCENT, card.get_global_rect() if card != null and card.visible and layer.visible else Rect2())
