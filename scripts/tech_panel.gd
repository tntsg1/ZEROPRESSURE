class_name TechPanel
extends Control
# Tools and permanent techniques. Recurring hand-tool parts were retired by the
# user on 2026-10-23; this page no longer sells or fits those parts.

var terminal: Control
var tech_box: VBoxContainer
var parts_box: VBoxContainer
var status: Label


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
	b.custom_minimum_size = Vector2(min_w, 40)
	b.pressed.connect(cb)
	return b


func _plate() -> StyleBoxFlat:
	var plate := SkillBook._plate_box()
	plate.content_margin_left = 20
	plate.content_margin_right = 20
	plate.content_margin_top = 16
	plate.content_margin_bottom = 16
	return plate


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var skin := Theme.new()
	skin.default_font = Fonts.get_font("Regular")
	skin.default_font_size = 17
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := SkillBook._key_box(state)
		box.content_margin_left = 14
		skin.set_stylebox(state, "Button", box)
	skin.set_color("font_color", "Button", Pal.ink(0.85))
	skin.set_color("font_hover_color", "Button", Pal.ink(0.98))
	skin.set_color("font_pressed_color", "Button", Pal.ink(1.0))
	skin.set_color("font_disabled_color", "Button", Pal.ink(0.4))
	UiSkin.scroll_into(skin)
	theme = skin
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	column.add_child(body)
	var left := PanelContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.9
	left.add_theme_stylebox_override("panel", _plate())
	body.add_child(left)
	var ls := ScrollContainer.new()
	ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(ls)
	tech_box = VBoxContainer.new()
	tech_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tech_box.add_theme_constant_override("separation", 8)
	ls.add_child(tech_box)
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.4
	right.add_theme_stylebox_override("panel", _plate())
	body.add_child(right)
	var rs := ScrollContainer.new()
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(rs)
	parts_box = VBoxContainer.new()
	parts_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parts_box.add_theme_constant_override("separation", 6)
	rs.add_child(parts_box)
	status = label(Txt.t("cs_keys"), 14, Color(1, 1, 1, 0.5))
	column.add_child(status)
	refresh()


func clear(node: Node) -> void:
	for ch in node.get_children():
		node.remove_child(ch)
		ch.queue_free()


func _onsite() -> bool:
	return terminal != null and terminal.overlay and not terminal.between


func refresh() -> void:
	clear(tech_box)
	clear(parts_box)
	var h := label(Txt.t("cs_tech_h"), 20)
	h.add_theme_font_override("font", Fonts.get_font("SemiBold"))
	tech_box.add_child(h)
	tech_box.add_child(label(Txt.t("cs_tech_d"), 14, Color(1, 1, 1, 0.55)))
	var feats: Dictionary = Career.data.get("feats", {})
	for f in Gear.FEATS:
		var have: bool = feats.has(f)
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		tech_box.add_child(row)
		row.add_child(label(("✓  " if have else "○  ") + Txt.t("feat_" + f), 17, Hmi.ok_col() if have else Color(1, 1, 1, 0.7)))
		row.add_child(label(Txt.t("feat_" + f + "_d"), 13, Color(1, 1, 1, 0.55)))
		if have:
			var info: Dictionary = feats[f]
			row.add_child(label(Txt.t("cs_feat_when") % [str(info.get("job", "")), Gear.name_of(str(Gear.FEAT_GRANT.get(f, "")))], 13, Hmi.ok_col()))
	var refunded := float(Career.data.get("skills_refunded", 0.0))
	if refunded > 0.0:
		tech_box.add_child(HSeparator.new())
		tech_box.add_child(label(Txt.t("cs_refund_note") % Pal.money(refunded), 13, Color(1, 1, 1, 0.5)))
	parts_box.add_child(label(words("基础作业工具", "BASIC WORK TOOLS"), 20))
	parts_box.add_child(label(words("测量仪、激光切割和磁力抓钩持续可用，无需购买、更换探针、透镜或电容。工具能力通过永久升级提升。", "Meter, laser and grapple remain available without buying or replacing probe tips, lenses or capacitors. Permanent upgrades improve tool capabilities."), 17))
	var refund := float(Career.data.get("tool_parts_retirement",{}).get("refund",0.0))
	if refund > 0.0:
		parts_box.add_child(label(words("旧配件残值已一次性返还：", "Legacy parts residual value refunded once: ")+Pal.money(refund),16,Hmi.ok_col()))


func _num(v: float) -> String:
	return ("%.1f" % v) if v != floorf(v) else str(int(v))


func _buy(tool: String, t: int) -> void:
	var why := Consum.buy(tool, t)
	if why != "":
		status.text = why
		if terminal != null and terminal.has_method("_refuse"):
			terminal._refuse(why)
		return
	if terminal != null and terminal.has_method("say"):
		terminal.say(Txt.t("ld_bought") % "%s · %s" % [Consum.name_of(tool), Consum.tier_name(t)])
	if terminal != null and "sfx" in terminal and terminal.sfx != null:
		terminal.sfx.play("stamp", Vector2.INF, 0.9)
	refresh()


func _fit(tool: String, i: int) -> void:
	var why := ""
	if _onsite() and terminal.game_ref != null:
		why = Consum.fit_later(tool, i, terminal.game_ref.job)
	else:
		why = Consum.fit(tool, i)
	if why != "":
		status.text = why
		if terminal != null and terminal.has_method("_refuse"):
			terminal._refuse(why)
		return
	if terminal != null and terminal.has_method("say"):
		terminal.say(Txt.t("cs_will_fit" if _onsite() else "cs_fitted") % Consum.name_of(tool))
	if terminal != null and "sfx" in terminal and terminal.sfx != null:
		terminal.sfx.play("switch", Vector2.INF, 0.8)
	refresh()
