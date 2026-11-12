extends Control
const PlanCodex = preload("res://scripts/plan_codex.gd")
# The growth desk owns selection and layout; Career/Growth remain the authority.
const PAGE_SIZE := 6
var terminal: Control
var category := 6               # 104 号: the dismantling methods first
var page_index := 0
var selected := ""
var entries: Array = []
var categories: VBoxContainer
var grid: GridContainer
var detail: VBoxContainer
var detail_scroll: ScrollContainer
var counter: Label
var status: Label
var previous: Button
var following: Button
var action_button: Button
var cards: Array[Button] = []
var heading: Label
var introduction: Label

func words(zh: String, en: String) -> String:
	return zh if Txt.zh else en

func label(text: String, px: int = 18) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", px)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func key(text: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 50
	node.pressed.connect(callback)
	return node

func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var skin := Theme.new()
	skin.default_font = Fonts.get_font("Regular")
	skin.default_font_size = 18
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := SkillBook._key_box(state)
		box.content_margin_left = 16
		skin.set_stylebox(state, "Button", box)
	UiSkin.scroll_into(skin)
	theme = skin
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	heading = label("", 28)
	heading.add_theme_font_override("font", Fonts.get_font("SemiBold"))
	column.add_child(heading)
	introduction = label("", 16)
	column.add_child(introduction)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	column.add_child(body)
	categories = VBoxContainer.new()
	categories.custom_minimum_size.x = 170
	categories.add_theme_constant_override("separation", 8)
	body.add_child(categories)
	var catalogue := VBoxContainer.new()
	catalogue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalogue.size_flags_stretch_ratio = 1.35
	catalogue.add_theme_constant_override("separation", 14)
	body.add_child(catalogue)
	grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	catalogue.add_child(grid)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catalogue.add_child(spacer)
	var pager := HBoxContainer.new()
	pager.add_theme_constant_override("separation", 12)
	catalogue.add_child(pager)
	previous = key(words("上一页", "PREVIOUS"), func(): turn_page(-1))
	pager.add_child(previous)
	counter = label("", 16)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pager.add_child(counter)
	following = key(words("下一页", "NEXT"), func(): turn_page(1))
	pager.add_child(following)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	var plate := SkillBook._plate_box()
	plate.content_margin_left = 24
	plate.content_margin_right = 24
	plate.content_margin_top = 22
	plate.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", plate)
	body.add_child(panel)
	detail_scroll = ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.follow_focus = true
	panel.add_child(detail_scroll)
	detail = VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 16)
	detail_scroll.add_child(detail)
	status = label(words("Tab 切换焦点 · 方向键选择 · Enter 确认 · Esc 返回", "Tab focus · Arrows select · Enter confirm · Esc return"), 16)
	column.add_child(status)
	refresh()

func refresh() -> void:
	heading.text = words("拆法与建设", "METHODS & CONSTRUCTION")
	introduction.text = Txt.t("as_mt_intro") if category == 6 else words("这里安排基础修复与工程成长。原料买卖和工业客户请进入交易行；加工在现场设备操作。", "Manage base repairs and engineering growth here. Trade materials and find industrial clients in the exchange; operate production equipment on site.")
	previous.text = words("上一页", "PREVIOUS")
	following.text = words("下一页", "NEXT")
	status.text = words("Tab 切换焦点 · 方向键选择 · Enter 确认 · Esc 返回", "Tab focus · Arrows select · Enter confirm · Esc return")
	clear(categories)
	# 61 号: techniques (3) and engineering orders (4) are kept out of sight; 66 号: so is the ship
	# catalogue (2) — the berth's length alone decides what turns up
	# 104 号: the methods first; the old drone upgrades (5) went into the methods' tiers
	for i in [6, 0, 1]:
		var title: String = words("拆法", "METHODS") if i == 6 else [words("船坞修缮", "BERTH REPAIRS"), words("零压港", "THE PORT"), words("船型目录", "SHIP CATALOGUE"), words("永久技术", "TECHNIQUES"), words("工程委托", "ENGINEERING ORDERS"), words("设备升级", "EQUIPMENT UPGRADES")][i]
		var button := key(title, select_category.bind(i))
		button.toggle_mode = true
		button.button_pressed = i == category
		# 炭黑 v2: tall keys with their number, the open one pressed in with its lip
		button.custom_minimum_size.y = 64
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override("h_separation", 0)
		var n_c := categories.get_child_count() + 1
		var kb := SkillBook._key_box("normal")
		kb.content_margin_left = 54
		for stn in ["normal", "hover", "pressed", "disabled"]:
			var bx := SkillBook._key_box(stn)
			bx.content_margin_left = 54
			button.add_theme_stylebox_override(stn, bx)
		button.draw.connect(func():
			var fl: Font = Fonts.get_font("Light")
			var dn := 1.0 if button.button_pressed else 0.0
			button.draw_string(fl, Vector2(16, button.size.y * 0.5 + 10 + dn * 2), "%d" % n_c, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Charcoal.ACCENT if button.button_pressed else Pal.ink(0.45)))
		categories.add_child(button)
	entries = []
	if category == 6:
		for id in Methods.ORDER:
			if Methods.learned(id) or id == Methods.next_id() or Methods.SPEC[id].learn == "buy":
				entries.append(_method_node(id))
		# 2026-11-11 切割宝典 (scripts/plan_codex.gd): every type cut on P without stripping one first
		entries.append(PlanCodex.node())
	elif category == 0:
		for it in Route.buys():
			if it[1] == "facility":
				entries.append(Route.buy_node(it))
	elif category == 1:
		for z in Port.ZONES:
			entries.append(Route.port_node(z))
	elif category == 2:
		for ship in Route.ships():
			entries.append(Route.ship_node(ship))
	elif category == 5:
		for it in Route.buys():
			if it[1] == "upgrade":
				entries.append(Route.buy_node(it))
	elif category == 4:
		var orders = load("res://scripts/work_orders.gd")
		for id in orders.IDS:
			entries.append({"key":"order:"+str(id),"kind":"order","id":id,"name":orders.text(id),"note":orders.text(id,"goal"),"done":orders.done(id),"ready":orders.reason(id) == ""})
	else:
		var feats: Dictionary = Career.data.get("feats", {})
		for f in Gear.FEATS:
			entries.append({"key": "feat:" + f, "kind": "feat", "row": -1, "id": f, "name": Txt.t("feat_" + f), "conds": [],
				"done": feats.has(f), "ready": false, "note": Txt.t("feat_" + f + "_d"), "opens": Gear.name_of(str(Gear.FEAT_GRANT.get(f, "")))})
	page_index = clampi(page_index, 0, maxi(0, (entries.size() - 1) / PAGE_SIZE))
	if not entries.any(func(n): return n.key == selected):
		selected = str(entries[page_index * PAGE_SIZE].key) if not entries.is_empty() else ""
	refresh_cards()
	refresh_detail()

func select_category(index: int) -> void:
	category = index
	page_index = 0
	selected = ""
	refresh()
	if not cards.is_empty():
		cards[0].grab_focus()

func select_key(value: String) -> void:
	selected = value
	category = 6 if value.begins_with("method:") else 4 if value.begins_with("order:") else (2 if value.begins_with("ship:") else (3 if value.begins_with("feat:") else (1 if value.begins_with("port:") else 0)))
	if value.begins_with("buy:"):
		for it in Route.buys():
			if it[0] == value.substr(4) and it[1] == "upgrade":
				category = 5
	refresh()
	for i in entries.size():
		if entries[i].key == value:
			page_index = i / PAGE_SIZE
	refresh_cards()
	refresh_detail()

func turn_page(delta: int) -> void:
	page_index = clampi(page_index + delta, 0, maxi(0, (entries.size() - 1) / PAGE_SIZE))
	selected = str(entries[page_index * PAGE_SIZE].key) if not entries.is_empty() else ""
	refresh_cards()
	refresh_detail()

# 104 号: a method's card: learned (its tier) or the next one to learn
func _method_node(id: String) -> Dictionary:
	var lv := Methods.level(id)
	var why := Methods.borrow_reason(id) if lv == 0 else Methods.buy_reason(id)
	return {"key": "method:" + id, "kind": "method", "id": id, "name": Methods.name_of(id), "level": lv,
		"done": lv >= Methods.tiers(id), "ready": why == "", "why": why}

func node_name(n: Dictionary) -> String:
	if n.kind == "method":
		return str(n.name)
	if n.kind == "port":
		return "%s  %d / 2" % [str(n.name), int(n.get("stage", 0))]
	if n.kind == "feat":
		return str(n.name)
	if n.kind == "skill":
		return Growth.text(Growth.find_track(str(n.id))[2])
	if n.kind == "ship":
		return "%s · %d m" % [str(n.short), int(n.length)]
	return str(n.name)

func summary(n: Dictionary) -> String:
	if n.kind == "method":
		return Methods.does(str(n.id))
	if n.kind == "codex":
		return str(n.note)
	if n.kind == "order":
		var spec: Dictionary = load("res://scripts/work_orders.gd").SPECS[str(n.id)]
		return " + ".join(spec.targets)+(str(" + "+spec.mount) if spec.mount != "" else "")
	if n.kind == "port":
		return str(n.note)
	if n.kind == "feat":
		return words("开放：", "OPENS: ") + str(n.get("opens", ""))
	if n.kind == "skill":
		var row := Growth.find_track(str(n.id))
		var level := Growth.level(Career.data.upgrades, str(n.id))
		return "%s → %s" % [Growth.display(row, level), Growth.display(row, mini(level + 1, 3))] if level < 3 else Growth.display(row, level)
	if n.kind == "ship":
		return words("长度 %d m · 已拆 %d 艘", "%d m · %d completed") % [int(n.length), int(n.stripped)]
	var points := Route.points(str(n.id))
	return str(points[0]) if not points.is_empty() else str(n.note)

func state_text(n: Dictionary) -> String:
	if n.kind == "codex":
		return Txt.t("as_mt_top") if n.done else ((Txt.t("as_mt_buy") % Pal.money(PlanCodex.PRICE)) if n.ready else str(n.why))
	if n.kind == "method":
		var id := str(n.id)
		var lv := int(n.level)
		# 2026-11-11 (user: "不要有任何学会的…实时变化就行了"): the tier it is at, and the next price
		var learn: String = Methods.SPEC[id].learn
		if lv == 0:
			if learn == "buy":
				return Txt.t("as_mt_unbought") + "  ·  " + ((Txt.t("as_mt_buy") % Pal.money(Methods.price(id))) if n.ready else str(n.why))
			if learn == "build":
				return Txt.t("as_mt_unbought") + "  ·  " + Txt.t("as_mt_facility")
			return Txt.t("as_mt_unbought") + "  ·  " + ((words("接借用合同", "TAKE THE BORROW JOB") if learn != "order" else words("接“稳住再拆”委托", "TAKE THE RIGGING ORDER")) if n.ready else str(n.why))
		var tier := words("%d / %d 档", "TIER %d / %d") % [lv, Methods.tiers(id)]
		if n.done:
			return tier + "  ·  " + Txt.t("as_mt_top")
		if id == "auto":
			return tier + "  ·  " + Txt.t("as_mt_facility")
		return tier + "  ·  " + ((words("升档", "NEXT TIER") + "  " + Pal.money(Methods.price(id))) if n.ready else str(n.why))
	if n.kind == "order": return Txt.t("tm_trial_done") if n.done else (words("定向接取", "TAKE DIRECTLY") if n.ready else load("res://scripts/work_orders.gd").reason(str(n.id)))
	if n.kind == "port":
		if n.done:
			return words("已建成", "COMPLETE")
		return (words("可施工", "CAN BUILD") + "  " + Pal.money(float(n.price))) if n.ready else Port.reason(str(n.id), true)
	if n.kind == "feat":
		return words("已达成", "ACHIEVED") if n.done else words("未达成", "NOT YET")
	if n.done:
		return words("已开放", "AVAILABLE") if n.kind == "ship" else (words("已学满", "MASTERED") if n.kind == "skill" else words("已建成", "INSTALLED"))
	if n.ready:
		if n.kind == "skill":
			return words("升级", "UPGRADE") + "  " + Pal.money(Growth.price(str(n.id)))
		return (words("升级", "UPGRADE") if n.get("purchase_kind", "") == "upgrade" else words("建设", "BUILD")) + "  " + Pal.money(float(n.get("price", 0.0)))
	return Route.missing(n)

func refresh_cards() -> void:
	clear(grid)
	cards.clear()
	var count := mini(PAGE_SIZE, entries.size() - page_index * PAGE_SIZE)
	for i in count:
		var n: Dictionary = entries[page_index * PAGE_SIZE + i]
		var button := key("", choose.bind(str(n.key)))
		button.custom_minimum_size = Vector2(0, 180 if n.kind == "order" else 150)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_pressed = n.key == selected
		button.tooltip_text = node_name(n) + "\n" + summary(n)
		grid.add_child(button)
		cards.append(button)
		# 炭黑 v2: the card's number big at its left, a lamp for its state (done white, can be had orange)
		var n_k := page_index * PAGE_SIZE + i + 1
		var lamp_on: bool = n.done or n.ready
		var lamp_c := Color(0.86, 0.88, 0.86) if n.done else Charcoal.ACCENT
		button.draw.connect(func():
			var fl: Font = Fonts.get_font("Light")
			var dn := 3.0 if button.button_pressed else 0.0
			button.draw_string(fl, Vector2(18, 54 + dn), "%02d" % n_k, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Charcoal.ACCENT if button.button_pressed else Pal.ink(0.6))
			Charcoal.led(button, Vector2(button.size.x - 22, 22 + dn), lamp_on, 1.0, 4.5, lamp_c))
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 18)
		margin.add_theme_constant_override("margin_left", 84)
		margin.add_theme_constant_override("margin_right", 40)
		button.add_child(margin)
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 10)
		margin.add_child(column)
		var title := label(node_name(n), 21)
		title.max_lines_visible = 2
		column.add_child(title)
		var info := label(summary(n), 16)
		info.max_lines_visible = 2
		info.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(info)
		var state := label(state_text(n), 16)
		state.max_lines_visible = 2
		state.modulate = Hmi.ok_col() if n.done else (Hmi.can_col() if n.ready else Hmi.warn_col())
		column.add_child(state)
	counter.text = "%d / %d  ·  %d %s" % [page_index + 1, maxi(1, ceili(float(entries.size()) / PAGE_SIZE)), entries.size(), words("项", "projects")]
	previous.disabled = page_index == 0
	following.disabled = (page_index + 1) * PAGE_SIZE >= entries.size()

func choose(value: String) -> void:
	selected = value
	for i in cards.size():
		cards[i].button_pressed = entries[page_index * PAGE_SIZE + i].key == selected
	detail_scroll.scroll_vertical = 0
	refresh_detail()

func chosen() -> Dictionary:
	for n in entries:
		if n.key == selected:
			return n
	return {}

func refresh_detail() -> void:
	clear(detail)
	action_button = null
	var n := chosen()
	if n.is_empty():
		return
	detail.add_child(label(node_name(n), 30))
	detail.add_child(label(summary(n), 23))
	if n.kind == "method":
		_method_detail(n)
		return
	if n.kind == "codex":
		_add_line(Txt.t("as_codex_types") % PlanCodex.types().size(), 17, Pal.ink(0.85))
		detail.add_child(HSeparator.new())
		if n.done:
			_add_line(Txt.t("as_mt_top"), 17, Hmi.ok_col())
			return
		detail.add_child(label(Txt.t("as_mt_buy") % Pal.money(PlanCodex.PRICE), 24))
		action_button = key(state_text(n), purchase)
		action_button.disabled = not n.ready
		detail.add_child(action_button)
		detail.add_child(label(words("永久 · 本单立即生效", "Permanent · in effect at once"), 16))
		return
	if n.kind == "order":
		_order_detail(n)
		return
	if n.kind == "port":
		_port_detail(n)
		return
	if n.kind == "feat":
		detail.add_child(label(str(n.note)))
		detail.add_child(label(state_text(n), 18))
		detail.add_child(label(words("在合同里达成即永久开放，不花钱。", "Achieved on a job, open for good, nothing to pay."), 16))
		return
	if n.kind == "skill":
		var row := Growth.find_track(str(n.id))
		detail.add_child(label(Growth.text(row[6])))
		var current := Growth.level(Career.data.upgrades, str(n.id))
		for tier in range(1, 4):
			var line := label("%s  %s  ·  %s  ·  %s" % ["✓" if current >= tier else "○", ["I", "II", "III"][tier - 1], Growth.display(row, tier), Pal.money(float(row[5][tier - 1]))])
			line.modulate = Hmi.ok_col() if current >= tier else Pal.ink(0.8)
			detail.add_child(line)
	else:
		var points := Route.points(str(n.id)) if n.kind == "buy" else [str(n.note)]
		for point in points:
			if str(point) != "":
				detail.add_child(label("· " + str(point)))
	detail.add_child(HSeparator.new())
	detail.add_child(label(words("解锁条件", "REQUIREMENTS"), 16))
	for condition in n.get("conds", []):
		var line := label(("✓  " if condition.ok else "○  ") + str(condition.label) + "   " + str(condition.now), 17)
		line.modulate = Hmi.ok_col() if condition.ok else Hmi.warn_col()
		detail.add_child(line)
	var dependencies: Array = [Dock.needs(float(n.length))] if n.kind == "ship" else n.get("prerequisites", [])
	for prerequisite in dependencies:
		if prerequisite != "" and not Career.data.upgrades.has(prerequisite):
			var caption := words("查看前置建设", "VIEW REQUIRED CONSTRUCTION")
			if dependencies.size() > 1 or n.kind != "ship":
				caption += " · " + Repair.name_of(str(prerequisite))
			detail.add_child(key(caption, select_key.bind("buy:" + str(prerequisite))))
	if n.kind == "buy" and str(n.id) in Port.POWER_ITEMS and not Port.power_ok(str(n.id)):
		detail.add_child(key(words("查看港区供电建设", "VIEW POWER DISTRICT"), select_key.bind("port:power")))
	if n.kind == "ship":
		detail.add_child(label(Txt.t("rt_ship_then"), 16))
		action_button = key(words("查看当前合同", "VIEW CURRENT CONTRACTS"), func(): terminal.set_tab(0))
		detail.add_child(action_button)
		return
	var price := Growth.price(str(n.id)) if n.kind == "skill" else float(n.get("price", 0.0))
	if not n.done:
		detail.add_child(label(words("本次费用 %s", "PRICE %s") % Pal.money(price), 24))
		var after := float(Career.data.money) - price
		detail.add_child(label((words("购后资金 %s", "FUNDS AFTER %s") % Pal.money(after)) if after >= 0.0 else (words("还差 %s", "SHORT %s") % Pal.money(-after)), 17))
	var onsite: bool = terminal.overlay and not terminal.between and n.kind == "buy"
	var text := state_text(n)
	if onsite and not n.done:
		text = Txt.t("tm_lock_equip")
	# 65 号: the crew does one job at a time; the one being built says so
	var building: bool = Works.busy() and str(Works.current().get("id", "")) == str(n.get("id", ""))
	if building:
		text = words("施工中 · 还剩 %d 秒", "BUILDING · %d s LEFT") % int(ceil(float(Works.current().get("left", 0.0))))
	action_button = key(text, purchase)
	action_button.disabled = n.done or not n.ready or onsite or (n.kind == "buy" and Works.busy())
	detail.add_child(action_button)
	if n.kind == "buy" and Works.busy() and not building:
		detail.add_child(label(Works.busy_text(), 15))
	var fitting := words("永久设施 · 下一单安装", "Permanent facility · Installed next contract")
	if n.kind == "skill":
		fitting = words("永久升级 · 本单立即装配", "Permanent upgrade · Fits this job immediately")
	elif n.get("purchase_kind", "") == "upgrade":
		fitting = words("永久升级 · 下一单装配", "Permanent upgrade · Fitted next contract")
	detail.add_child(label(fitting, 16))

# 104 号: a method: its tiers, how it is learned, the one thing to do next
func _method_detail(n: Dictionary) -> void:
	var id := str(n.id)
	var s: Dictionary = Methods.SPEC[id]
	var lv := int(n.level)
	for tier in range(1, Methods.tiers(id) + 1):
		var price := float(s.tiers[tier - 1][0])
		var cost := Pal.money(price) if s.learn == "buy" or tier > 1 else (Txt.t("as_mt_facility") if s.learn == "build" else Txt.t("as_mt_cost_job"))
		if id == "auto" and tier > 1:
			cost = Txt.t("as_mt_facility")
		_add_line("%s  %s  ·  %s  ·  %s" % ["✓" if lv >= tier else "○", ["I", "II", "III"][tier - 1], " / ".join(Methods.points(id, tier)), cost], 17, Hmi.ok_col() if lv >= tier else Pal.ink(0.8))
	detail.add_child(HSeparator.new())
	var busy: bool = terminal.overlay and not terminal.between
	if lv == 0 and s.learn == "buy":
		detail.add_child(label(Txt.t("as_mt_buy") % Pal.money(Methods.price(id)), 24))
		action_button = key(state_text(n), purchase)
		action_button.disabled = not n.ready
		detail.add_child(action_button)
		detail.add_child(label(words("永久 · 本单立即生效", "Permanent · in effect at once"), 16))
		return
	if lv == 0:
		detail.add_child(label(Txt.t("as_mt_how"), 16))
		if s.learn == "build":
			_add_line(Txt.t("as_mt_build_how") % Repair.name_of(str(s.builds[0])), 17, Pal.ink(0.85))
			action_button = key(words("去船坞修建", "GO TO THE BUILD"), select_key.bind("buy:" + str(s.builds[0])))
			detail.add_child(action_button)
			return
		var ship := Methods.ship_for(id) if s.learn == "borrow" else "gr7"
		var lend: Array = []
		for g in s.get("lend", {}):
			lend.append("%s ×%d" % [Gear.name_of(str(g)), int(s.lend[g])])
		if s.learn == "order":
			lend.append(Gear.name_of("anchor"))
		var ship_name := Methods.ship_label(ship)
		_add_line(Txt.t("as_mt_borrow_line") % [ship_name, "、".join(lend) if not lend.is_empty() else words("本单装配", "fitted for the job")], 17, Pal.ink(0.85))
		var feat := str(s.get("feat", ""))
		if feat != "":
			_add_line(words("或者在任何船上达成：%s", "Or achieve on any ship: %s") % Txt.t("feat_" + feat), 16, Pal.ink(0.7))
		action_button = key(state_text(n), func(): terminal.take_borrow(id))
		action_button.disabled = not n.ready or busy
		detail.add_child(action_button)
		if busy:
			detail.add_child(label(words("请先结束当前合同。", "FINISH THE CURRENT CONTRACT FIRST."), 16))
		return
	if n.done:
		_add_line(Txt.t("as_mt_top"), 17, Hmi.ok_col())
		return
	if id == "auto":
		_add_line(Txt.t("as_mt_facility"), 17, Pal.ink(0.85))
		var next_build := str(s.builds[lv])
		action_button = key(words("去船坞修建：", "BUILD: ") + Repair.name_of(next_build), select_key.bind("buy:" + next_build))
		detail.add_child(action_button)
		return
	detail.add_child(label(words("下一档 %s", "NEXT TIER %s") % Pal.money(Methods.price(id)), 24))
	action_button = key(state_text(n), purchase)
	action_button.disabled = not n.ready
	detail.add_child(action_button)
	detail.add_child(label(words("永久升档 · 本单立即生效", "Permanent · in effect at once"), 16))


# a district's next stage: what it takes, the two ways to pay
func _order_detail(n: Dictionary) -> void:
	var orders = load("res://scripts/work_orders.gd")
	var id := str(n.id)
	detail.add_child(label(str(n.note),18))
	detail.add_child(label(orders.text(id,"next")))
	detail.add_child(label(words("船源：原厂灰鹭；按 P 使用安全处置和局部检修包。无需等随机合同刷新。", "SOURCE: FACTORY GR-7. P offers preparation and local access packages. No random market refresh is required."),16))
	detail.add_child(label(words("借用机器仅本单生效；锚、探头要正常取回。成功带回的自有工具可重复使用。", "Rented machines last for this job. Retrieve deployed anchors and probes normally; owned gear remains reusable."),16))
	detail.add_child(label(words("船源费：", "SOURCE FEE: ")+Pal.money(float(orders.SPECS[id].fee)),20))
	var choices: OptionButton = null
	if id == "heavy":
		choices = OptionButton.new()
		choices.custom_minimum_size.y = 44
		for reward in orders.reward_options(): choices.add_item(words("出勤物资补充", "FIELD GEAR STOCK") if reward == "field_stock" else Repair.name_of(str(reward)))
		detail.add_child(label(words("选择交付后立即恢复的设施", "CHOOSE THE FACILITY RESTORED ON DELIVERY"),18))
		detail.add_child(choices)
		detail.add_child(label(words("整组交付免装配费；分件交付支付设施标价的 20%。资金不足计入现有贷款。已建满基础设施时，交付换取自有锚与探头各一件。", "Whole delivery waives assembly costs. Separate units cost 20% of the facility list price; any shortfall uses the existing loan. Fully restored careers receive one owned anchor and probe instead."),16))
	var whole: CheckBox = null
	if id == "heavy":
		whole = CheckBox.new()
		whole.text = words("保留底座，计划整件运输", "PRESERVE CRADLE FOR WHOLE-ASSEMBLY TRANSPORT")
		detail.add_child(whole)
	var busy: bool = terminal.overlay and not terminal.between
	action_button = key(words("定向接取这份委托", "TAKE THIS ENGINEERING ORDER"),func():
		var reward := str(orders.reward_options()[choices.selected]) if id == "heavy" else ""
		terminal.take_order(id,reward,whole != null and whole.button_pressed))
	action_button.disabled = not n.ready or busy
	detail.add_child(action_button)
	if not n.ready: detail.add_child(label(state_text(n),16))
	if busy: detail.add_child(label(words("请先结束当前合同。", "FINISH THE CURRENT CONTRACT FIRST."),16))
	detail.add_child(key(words("取消目标追踪（保留库存与进度）", "HIDE TRACKING (KEEP STOCK AND PROGRESS)"),func():
		var why: String = orders.track("")
		if why != "": status.text = why))


func _port_detail(n: Dictionary) -> void:
	var z := str(n.id)
	var st := Port.stage(z)
	if z == "trade":
		detail.add_child(label(words("营业业务：按卖家报价采购原料、自主挂单、承接工业客户需求、查看交付。", "BUSINESS: seller listings, material purchases, limit orders, industrial clients and deliveries."),17))
		detail.add_child(key(words("进入交易行 · 买入 / 出售", "ENTER EXCHANGE / BUY & SELL"),func(): terminal.open_exchange()))
	if z == "process":
		detail.add_child(label(words("生产业务：分选原料与手工炼钢。先在交易行采购并等待入库，再到炉体或分选操作台按 E。", "PRODUCTION: material sorting and manual steelmaking. Purchase inputs, await warehouse receipt, then use the furnace or sorting console on site."),17))
		detail.add_child(label(words("现场路线：从船坞地板右端绕到下方；炉体操作台在左侧，分选操作台在右侧。", "ACCESS: go around the right end of the berth floor and underneath. Furnace console to the left, sorting console to the right."),16))
	if st >= 2:
		_add_line(words("基础设施修复完成。", "BASE FACILITIES RESTORED."), 17, Hmi.ok_col())
		return
	if Port.RepairBill.ON:
		_port_bill(z, st)
		return
	var needs := Port.needs(z, st + 1)
	var pf := Repair.parts_for_needs(needs)
	detail.add_child(HSeparator.new())
	detail.add_child(label(Txt.t("rp_needs") + "  ·  " + Txt.t("pt_stage") + " %d" % (st + 1), 16))
	for cls in needs:
		if cls in ["structure", "section"]:
			var miss: float = pf.tons_missing if cls == "structure" else float(pf.get("section_missing", 0.0))
			var got: float = pf.tons if cls == "structure" else float(pf.get("section", 0.0))
			var ok2: bool = miss <= 0.001
			_add_line("%s  %s  %.1f / %.1f t" % ["✓" if ok2 else "○", Repair.class_name_of(cls), got, float(needs[cls])], 16, Hmi.ok_col() if ok2 else Hmi.warn_col())
			if not ok2:
				_add_line("    " + Repair.lack_text(cls, miss), 14, Pal.ink(0.6))
		else:
			var have: int = pf.picked.get(cls, []).size()
			var ok3: bool = have >= int(needs[cls])
			_add_line("%s  %s  %d / %d" % ["✓" if ok3 else "○", Repair.class_name_of(cls), have, int(needs[cls])], 16, Hmi.ok_col() if ok3 else Hmi.warn_col())
	if st == 0:
		for d in Port.DEPS.get(z, []):
			var ok4: bool = Port.stage(str(d[0])) >= int(d[1])
			_add_line(("✓  " if ok4 else "○  ") + Txt.t("rt_first") + "  " + Port.name_of(str(d[0])), 15, Hmi.ok_col() if ok4 else Hmi.warn_col())
	detail.add_child(HSeparator.new())
	var onsite: bool = terminal.overlay and not terminal.between
	var why_p := Port.reason(z, true)
	var why_c := Port.reason(z, false)
	var bp := key("%s  %s" % [Txt.t("rp_fix_parts"), Pal.money(Port.cash(z, st + 1, true))], _port_fix.bind(z, true))
	bp.disabled = not (why_p == "" and not onsite)
	detail.add_child(bp)
	if why_p != "":
		_add_line(why_p, 13, Hmi.warn_col())
	var bc := key("%s  %s" % [Txt.t("rp_fix_cash"), Pal.money(Port.cash(z, st + 1, false))], _port_fix.bind(z, false))
	bc.disabled = not (why_c == "" and not onsite)
	detail.add_child(bc)
	if why_c != "" and why_c != why_p:
		_add_line(why_c, 13, Hmi.warn_col())
	_add_line(Txt.t("pt_effect_" + z), 14, Color(1, 1, 1, 0.6))
	action_button = bp if why_p == "" else bc


# 128 号 第 3 段: the one "修" — the bill, then the confirmation (scripts/repair_order.gd)
func _port_bill(z: String, st: int) -> void:
	var b: Dictionary = Port.RepairBill.of(z)
	detail.add_child(HSeparator.new())
	detail.add_child(label(Txt.t("rp_needs") + "  ·  " + Txt.t("pt_stage") + " %d" % (st + 1), 16))
	for row in b.get("rows", []):
		var ok := int(row.buy) == 0
		_add_line("%s  %s  %d / %d%s" % ["✓" if ok else "○", str(row.name), int(row.own), int(row.need), "" if ok else words("  · 缺的按市价买", "  · the rest bought")], 16, Hmi.ok_col() if ok else Pal.ink(0.8))
	var sd: Dictionary = b.get("steel", {})
	var oks := float(sd.get("buy", 0.0)) < 0.05
	_add_line("%s  %s  %.1f / %.1f t" % ["✓" if oks else "○", words("修缮钢材", "REPAIR STEEL"), float(sd.get("own", 0.0)), float(sd.get("need", 0.0))], 16, Hmi.ok_col() if oks else Pal.ink(0.8))
	if st == 0:
		for d in Port.DEPS.get(z, []):
			var ok4: bool = Port.stage(str(d[0])) >= int(d[1])
			_add_line(("✓  " if ok4 else "○  ") + Txt.t("rt_first") + "  " + Port.name_of(str(d[0])), 15, Hmi.ok_col() if ok4 else Hmi.warn_col())
	detail.add_child(HSeparator.new())
	var onsite: bool = terminal.overlay and not terminal.between
	var why := Port.reason(z, true)
	if why == "" and st == 0 and not Port.deps_ok(z):
		why = Txt.t("tm_needs") % Port.name_of(str(Port.DEPS[z][0][0]))
	var bm := key(words("修 · 要买 %s", "MEND · BUY %s") % Pal.money(float(b.get("buy_cash", 0.0))), _port_order.bind(z))
	bm.disabled = not (why == "" and not onsite)
	detail.add_child(bm)
	if why != "":
		_add_line(why, 13, Hmi.warn_col())
	_add_line(Txt.t("pt_effect_" + z), 14, Color(1, 1, 1, 0.6))
	action_button = bm


func _port_order(z: String) -> void:
	var od = preload("res://scripts/repair_order.gd").new()
	od.zone = z
	od.on_done = func(ok: bool):
		if ok:
			_port_fix(z, true)
	terminal.add_child(od)


func _add_line(text: String, px: int, col: Color) -> void:
	var l := label(text, px)
	l.modulate = col
	detail.add_child(l)


func _port_fix(z: String, with_parts: bool) -> void:
	var why := Works.order_port(z, with_parts)
	if why != "":
		status.text = why
		terminal._refuse(why)
		return
	terminal.say(Txt.t("pt_built") % [Port.name_of(z), Works.cn_num(Port.stage(z) + 1) if Txt.zh else str(Port.stage(z) + 1)])
	terminal.sfx.play("stamp", Vector2.INF, 0.9)
	terminal._route_frame = -1
	refresh()


func purchase() -> void:
	var n := chosen()
	if n.is_empty() or n.done or not n.ready:
		return
	var notice := ""
	if n.kind == "port":
		_port_fix(str(n.id), Port.reason(str(n.id), true) == "")
		return
	if n.kind == "codex":
		var bad := PlanCodex.buy()
		if bad != "":
			status.text = bad
			return
		terminal.sfx.play("stamp", Vector2.INF, 0.9)
		notice = Txt.t("as_mt_bought") + node_name(n)
	elif n.kind == "method":
		var why := Methods.buy(str(n.id))
		if why != "":
			status.text = why
			return
		terminal.sfx.play("stamp", Vector2.INF, 0.9)
		notice = (words("已升档：", "TIER UP: ") if int(n.level) > 0 else Txt.t("as_mt_bought")) + node_name(n)
	elif n.kind == "skill":
		var result := Growth.buy(str(n.id))
		if result != "":
			status.text = result
			return
		if terminal.on_skill_changed.is_valid():
			terminal.on_skill_changed.call()
		notice = words("已升级并装配：", "UPGRADED & FITTED: ") + node_name(n)
	else:
		for it in Route.buys():
			if it[0] == n.id:
				terminal.buy(it)
		notice = terminal.msg
	terminal._route_frame = -1
	refresh()
	status.text = notice
	if action_button != null and not action_button.disabled:
		action_button.grab_focus()
