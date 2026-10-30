class_name LoadoutPanel
extends Control
# The loadout page (G1, design/G1_短循环设计稿_2026-10-21.md §配装): what the
# drone takes out on the contract in hand. Three module slots, two deployable
# slots (three with the rack), the warehouse beside them with what is on the
# shelf and what can be bought now. Career.set_loadout is the authority: this
# only chooses. Opened by the terminal before a contract departs, or with its
# key between contracts; Enter starts the job, Esc goes back.

var terminal: Control
var on_go: Callable
var on_back: Callable
var mods: Array = []            # chosen module types
var deploy: Dictionary = {}     # type -> count
var status_text := ""
var column: VBoxContainer
var slots_box: VBoxContainer
var shelf_box: VBoxContainer
var foot: Label
var status: Label
var go_btn: Button
var back_btn: Button
var retain := false             # G5.1: this job's structural scrap kept as company raw material
var retain_btn: CheckButton


static func open(term: Control, go: Callable, back: Callable) -> LoadoutPanel:
	var p := LoadoutPanel.new()
	p.terminal = term
	p.on_go = go
	p.on_back = back
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	term.add_child(p)
	return p


func words(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func label(text: String, px: int = 17, col: Color = Color(1, 1, 1, 0.85)) -> Label:
	var n := Label.new()
	n.text = text
	n.add_theme_font_size_override("font_size", px)
	n.add_theme_color_override("font_color", col)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


func key(text: String, cb: Callable, enabled: bool = true, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(min_w, 44)
	b.pressed.connect(cb)
	return b


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var skin := Theme.new()
	skin.default_font = Fonts.get_font("Regular")
	skin.default_font_size = 17
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := SkillBook._key_box(state)
		box.content_margin_left = 16
		skin.set_stylebox(state, "Button", box)
	skin.set_color("font_color", "Button", Pal.ink(0.85))
	skin.set_color("font_hover_color", "Button", Pal.ink(0.98))
	skin.set_color("font_pressed_color", "Button", Pal.ink(1.0))
	skin.set_color("font_disabled_color", "Button", Pal.ink(0.4))
	theme = skin
	# 51 号: the new look's ground (gradient, drifting glow, the pointer's light)
	add_child(UiSkin.Ground.new())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	margin.add_theme_constant_override("margin_top", 120)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var head := label(Txt.t("ld_title"), 30)
	head.add_theme_font_override("font", Fonts.get_font("SemiBold"))
	column.add_child(head)
	var a: Dictionary = Career.active()
	var sub := Txt.t("ld_note") if a.is_empty() else "%s  ·  %s" % [str(a.get("id", "")), Txt.t("ld_note")]
	column.add_child(label(sub, 15, Color(1, 1, 1, 0.55)))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 30)
	column.add_child(body)
	var left := PanelContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	left.add_theme_stylebox_override("panel", _plate())
	body.add_child(left)
	var ls := ScrollContainer.new()
	ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(ls)
	slots_box = VBoxContainer.new()
	slots_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_box.add_theme_constant_override("separation", 10)
	ls.add_child(slots_box)
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.25
	right.add_theme_stylebox_override("panel", _plate())
	body.add_child(right)
	var rs := ScrollContainer.new()
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(rs)
	shelf_box = VBoxContainer.new()
	shelf_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shelf_box.add_theme_constant_override("separation", 8)
	rs.add_child(shelf_box)
	foot = label("", 16)
	column.add_child(foot)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	go_btn = key(Txt.t("ld_go") + "  [Enter]", go, true, 260)
	row.add_child(go_btn)
	back_btn = key(Txt.t("ld_back") + "  [Esc]", cancel, true, 200)
	row.add_child(back_btn)
	status = label(Txt.t("ld_keys"), 14, Color(1, 1, 1, 0.5))
	row.add_child(status)
	# start from what the contract in hand took, or the saved configuration
	var g: Dictionary = a.get("gear", {}) if not a.is_empty() else Career.data.get("loadout", {})
	for m in g.get("mods", []):
		mods.append(str(m))
	for t in g.get("deploy", {}):
		deploy[str(t)] = int(g.deploy[t])
	retain = Career.retaining()
	refresh()


func _plate() -> StyleBoxFlat:
	var plate := SkillBook._plate_box()
	plate.content_margin_left = 22
	plate.content_margin_right = 22
	plate.content_margin_top = 18
	plate.content_margin_bottom = 18
	return plate


# the shelf as the page sees it: the warehouse plus what the contract in hand already took out
func _shelf() -> Dictionary:
	var w: Dictionary = Career.data.get("gear", {}).duplicate()
	var a: Dictionary = Career.active()
	var g: Dictionary = a.get("gear", {}) if not a.is_empty() else {}
	for m in g.get("mods", []):
		w[m] = int(w.get(m, 0)) + 1
	for t in g.get("deploy", {}):
		w[t] = int(w.get(t, 0)) + int(g.deploy[t])
	return w


func _free(type: String) -> int:
	var n: int = int(_shelf().get(type, 0))
	for m in mods:
		if m == type:
			n -= 1
	n -= int(deploy.get(type, 0))
	return n


func _deploy_n() -> int:
	var n := 0
	for t in deploy:
		n += int(deploy[t])
	return n


func clear(node: Node) -> void:
	for ch in node.get_children():
		node.remove_child(ch)
		ch.queue_free()


func refresh() -> void:
	clear(slots_box)
	clear(shelf_box)
	var a: Dictionary = Career.active()
	# module slots (none while the catalogue has no modules)
	if not Gear.MODS.is_empty():
		var h1 := label(Txt.t("ld_mods") + "  %d / %d" % [mods.size(), Gear.MOD_SLOTS], 18)
		h1.add_theme_font_override("font", Fonts.get_font("SemiBold"))
		slots_box.add_child(h1)
		for i in Gear.MOD_SLOTS:
			if i < mods.size():
				var m: String = mods[i]
				slots_box.add_child(key("◆  %s   —  %s" % [Gear.name_of(m), words("卸下", "TAKE OFF")], _unfit_mod.bind(i)))
			else:
				slots_box.add_child(key("◇  " + Txt.t("ld_empty"), func(): pass, false))
	# deployable slots
	var ds := Gear.deploy_slots(mods)
	var h2 := label(Txt.t("ld_deploy") + "  %d / %d" % [_deploy_n(), ds], 18)
	h2.add_theme_font_override("font", Fonts.get_font("SemiBold"))
	slots_box.add_child(h2)
	var filled := 0
	for t in deploy:
		for k in int(deploy[t]):
			slots_box.add_child(key("◆  %s   —  %s" % [Gear.name_of(t), words("卸下", "TAKE OFF")], _unfit_deploy.bind(t)))
			filled += 1
	for i in maxi(0, ds - filled):
		slots_box.add_child(key("◇  " + Txt.t("ld_empty"), func(): pass, false))
	slots_box.add_child(label(words("基础工具持续可用，无需装配耗材。", "Basic tools remain available; no consumable fitting required."), 15))
	var parts_refund := float(Career.data.get("tool_parts_retirement",{}).get("refund",0.0))
	if parts_refund > 0.0:
		slots_box.add_child(label(words("旧工具配件残值已返还：", "Legacy tool parts refunded: ")+Pal.money(parts_refund),15))
	# G5.1: keep this job's structural scrap as the company's own raw material
	if Career.can_retain(a):
		var hr := label(words("废金属去向", "SCRAP METAL"), 18)
		hr.add_theme_font_override("font", Fonts.get_font("SemiBold"))
		slots_box.add_child(hr)
		retain_btn = CheckButton.new()
		retain_btn.text = words("废金属留作原料（本单整单生效）", "KEEP THE SCRAP AS RAW MATERIAL (WHOLE JOB)")
		retain_btn.button_pressed = retain
		retain_btn.toggled.connect(func(on: bool):
			retain = on
			_click()
			refresh())
		slots_box.add_child(retain_btn)
		var first: bool = not Career.data.get("seen", {}).has("retain_switch")
		var why := words("进金属熔炉的结构钢不折现，按实收吨数记成公司未评级原料：去分选台分选、化验位定级，就能自己炼钢坯交给工业客户。代价：这部分回收价不付现金，也不计入修缮用的结构吨数。设备、危险品、污染件照常。",
			"Structural metal into the furnace mouth is not paid out: its tonnes become the company's unrated raw material, to sort, assay and melt into billets for industrial clients yourself. The cost: no cash for it, and it does not count as structure tonnes for repairs. Equipment, hazards and contaminated pieces go as usual.")
		slots_box.add_child(label(why, 14, Pal.heat(0.95, 1.2) if first and not retain else Color(1, 1, 1, 0.6)))
		if retain:
			slots_box.add_child(label(words("本单：废金属留作原料，不折现。", "THIS JOB: SCRAP KEPT, NOT PAID OUT."), 15, Pal.tint(Pal.FLUID, 1.0, 1.2)))
	# what the contract lends on top
	var lend: Dictionary = a.get("lend", {}) if not a.is_empty() else {}
	if not lend.is_empty():
		var parts: Array = []
		for t in lend:
			parts.append(Gear.name_of(t) + " ×%d" % int(lend[t]))
		slots_box.add_child(label(Txt.t("ld_lent") + "：" + ", ".join(parts), 15, Pal.heat(0.9, 1.1)))
	# the shelf
	var h3 := label(Txt.t("ld_stock"), 18)
	h3.add_theme_font_override("font", Fonts.get_font("SemiBold"))
	shelf_box.add_child(h3)
	for type in Gear.MODS + Gear.DEPLOY:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		shelf_box.add_child(row)
		var free := _free(type)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var nm := label("%s   ·   %s" % [Gear.name_of(type), Txt.t("ld_have") % free], 17)
		col.add_child(nm)
		col.add_child(label(Txt.t("gear_" + type + "_d"), 13, Color(1, 1, 1, 0.55)))
		var is_mod := Gear.is_mod(type)
		var can_fit: bool = free > 0 and ((is_mod and mods.size() < Gear.MOD_SLOTS and not type in mods) or (not is_mod and _deploy_n() < ds))
		row.add_child(key(words("装上", "FIT"), _fit.bind(type), can_fit, 110))
		var why := Gear.reason(type)
		var bb := key(Txt.t("ld_buy") % Pal.money(Gear.price(type)), _buy.bind(type), why == "", 190)
		if why != "":
			bb.tooltip_text = why
		row.add_child(bb)
		if Gear.locked_by(type) != "":
			col.add_child(label(Txt.t("ld_locked") + "：" + why, 13, Pal.heat(0.8, 1.0)))
	# 86 号 Q5: the drone's fitted upgrades, bought with money (were on the berth page)
	if terminal != null and "SHOP" in terminal:
		var h4 := label(Txt.t("rp_fitted"), 18)
		h4.add_theme_font_override("font", Fonts.get_font("SemiBold"))
		shelf_box.add_child(h4)
		for it in terminal.SHOP.slice(0, terminal.FITTED):
			# 104 号: the inspection kit, the 5 t grapple and the second pump went into the
			# dismantling methods' tiers (precision inspection, field grapple, pumping)
			if it[1] != "upgrade" or it[0] in ["scan_kit", "grapple5", "pump2"]:
				continue
			var have: bool = Career.data.get("upgrades", {}).has(it[0])
			var row2 := HBoxContainer.new()
			row2.add_theme_constant_override("separation", 10)
			shelf_box.add_child(row2)
			row2.add_child(label(Txt.t(it[3]) + ("  ·  " + Txt.t("tm_installed") if have else ""), 17))
			var bf := key(Pal.money(float(it[2])), _buy_fitted.bind(it), not have and float(Career.data.get("money", 0.0)) >= float(it[2]), 190)
			bf.name = "Fitted_" + str(it[0])
			row2.add_child(bf)
	# the foot: what goes out and what it could cost
	var val := 0.0
	for m in mods:
		val += Gear.price(m)
	for t in deploy:
		val += Gear.price(t) * int(deploy[t])
	foot.text = "%s  %s      %s  %s      %s  %s" % [Txt.t("ld_value"), Pal.money(val), Txt.t("ld_risk"), Pal.money(val), Txt.t("tm_funds") if Txt.has("tm_funds") else words("资金", "FUNDS"), Pal.money(float(Career.data.get("money", 0.0)))]
	if status_text != "":
		status.text = status_text


func _num(v: float) -> String:
	return ("%.1f" % v) if v != floorf(v) else str(int(v))


func _fit_part(tool: String, i: int) -> void:
	var why := Consum.fit(tool, i)
	if why != "":
		_say(why)
		return
	_click()
	refresh()


func _buy_part(tool: String, t: int) -> void:
	var why := Consum.buy(tool, t)
	if why != "":
		_say(why)
		if terminal != null and terminal.has_method("_refuse"):
			terminal._refuse(why)
		return
	if terminal != null and "sfx" in terminal and terminal.sfx != null:
		terminal.sfx.play("stamp", Vector2.INF, 0.9)
	refresh()


func _fit(type: String) -> void:
	if Gear.is_mod(type):
		if mods.size() >= Gear.MOD_SLOTS or type in mods or _free(type) <= 0:
			_say(Txt.t("ld_full") if _free(type) > 0 else Txt.t("ld_no_stock"))
			return
		mods.append(type)
	else:
		if _deploy_n() >= Gear.deploy_slots(mods) or _free(type) <= 0:
			_say(Txt.t("ld_full") if _free(type) > 0 else Txt.t("ld_no_stock"))
			return
		deploy[type] = int(deploy.get(type, 0)) + 1
	_click()
	refresh()


func _unfit_mod(i: int) -> void:
	if i < 0 or i >= mods.size():
		return
	mods.remove_at(i)
	# a rack taken off: the deployables past the slots left come off too
	var ds := Gear.deploy_slots(mods)
	while _deploy_n() > ds:
		for t in deploy.keys():
			if _deploy_n() <= ds:
				break
			deploy[t] = int(deploy[t]) - 1
			if int(deploy[t]) <= 0:
				deploy.erase(t)
	_click()
	refresh()


func _unfit_deploy(type: String) -> void:
	if not deploy.has(type):
		return
	deploy[type] = int(deploy[type]) - 1
	if int(deploy[type]) <= 0:
		deploy.erase(type)
	_click()
	refresh()


func _buy(type: String) -> void:
	var why := Gear.buy(type)
	if why != "":
		_say(why)
		if terminal != null and terminal.has_method("_refuse"):
			terminal._refuse(why)
		return
	if terminal != null and terminal.has_method("say"):
		terminal.say(Txt.t("ld_bought") % Gear.name_of(type))
	if terminal != null and "sfx" in terminal and terminal.sfx != null:
		terminal.sfx.play("stamp", Vector2.INF, 0.9)
	refresh()


func _buy_fitted(it: Array) -> void:
	if terminal != null:
		terminal.buy(it)
	refresh()


func _say(s: String) -> void:
	status_text = s
	status.text = s


func _click() -> void:
	if terminal != null and "sfx" in terminal and terminal.sfx != null:
		terminal.sfx.play("menu", Vector2.INF, 0.5)


# Enter: the configuration is taken out and the contract departs
func go() -> void:
	_commit_retain()
	var why := Career.set_loadout(mods, deploy)
	if why != "":
		_say(why)
		if terminal != null and terminal.has_method("_refuse"):
			terminal._refuse(why)
		return
	var cb := on_go
	close()
	if cb.is_valid():
		cb.call()


func cancel() -> void:
	# the choice is kept for next time even when nothing departs
	_commit_retain()
	Career.set_loadout(mods, deploy)
	var cb := on_back
	close()
	if cb.is_valid():
		cb.call()


# the switch onto the contract in hand (saved by set_loadout right after); the first look is remembered
func _commit_retain() -> void:
	if not Career.can_retain(Career.active()):
		return
	Career.set_retain(retain)
	var seen: Dictionary = Career.data.get("seen", {})
	seen["retain_switch"] = true
	Career.data.seen = seen


func close() -> void:
	if terminal != null and "loadout" in terminal and terminal.loadout == self:
		terminal.loadout = null
	queue_free()
