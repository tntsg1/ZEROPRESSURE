extends PanelContainer
# Readable index of the actual courses; it never advances lesson progress.
# 2026-11-10 炭黑 v2: the courses as numbered keys down the left (the OptionButton stays, hidden, for
# the keys and the tests), the chosen course's lessons on the right as cards — each lesson's number
# large, its steps numbered in a black window; the close a key with its keycap.
const GuideCopy = preload("res://scripts/onboarding_text.gd")
const COURSES := ["ts1","sp_energy","sp_cryo","sp_fluid","sp_atmos","sp_load","sp_precise","sp_isolate"]
const TEXT_W := 1040.0
var on_close: Callable
var picker: OptionButton
var content: VBoxContainer
var course_keys: Array = []
var _scroll: ScrollContainer
func words(zh: String,en: String) -> String: return zh if Txt.zh else en
func line(value: String,size_px: int = 18) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",size_px)
	return label
func _titles() -> Array:
	return [words("基础训练：飞行、拆解和回收","BASIC TRAINING"),words("能量设备：先释放储能","ENERGY SYSTEMS"),words("低温设备：按顺序回温","CRYOGENICS"),words("流体设备：压力、阀门和回收","FLUID SYSTEMS"),words("特殊环境：富氧、烟气和余热","ATMOSPHERE & RESIDUAL HEAT"),words("重载机构：先卸力再拆","PRELOADED STRUCTURES"),words("精密设备：保护完整性","PRECISION EQUIPMENT"),words("独立舱段：查清连接与电源","ISOLATION"),words("经营入门：买料、炼钢、卖货","MARKET & PRODUCTION"),words("考核：独立完成拆解任务","ASSESSMENT")]
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var skin := Theme.new()
	skin.default_font = Fonts.get_font("Regular")
	skin.default_font_size = 18
	theme = skin
	var box := StyleBoxFlat.new()
	box.bg_color = Charcoal.BG
	box.content_margin_left = 60
	box.content_margin_right = 60
	box.content_margin_top = 40
	box.content_margin_bottom = 36
	add_theme_stylebox_override("panel",box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",18)
	add_child(column)
	# the head: the title and its line; the close key at the right
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var tcol := VBoxContainer.new()
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tcol.add_theme_constant_override("separation",6)
	heading.add_child(tcol)
	var title := line(words("整套新手教程","THE COMPLETE TUTORIAL"),36)
	title.add_theme_font_override("font",Fonts.get_font("Light"))
	tcol.add_child(title)
	var sub := line(words("先学飞行和拆船，再学处理危险，最后学用自己的材料生产、卖货。基础工具一直能用，不用买探针、透镜或电容。","Learn flight and salvage, then hazards, then production and trade with owned stock. Basic tools never need purchased tips, lenses or capacitors."),15)
	sub.add_theme_color_override("font_color",Pal.ink(0.6))
	tcol.add_child(sub)
	var close_button := Button.new()
	# the words kept whole on the key (the back trail and the tests find it by them); drawn with its keycap
	close_button.text = words("返回训练 [Esc]","BACK TO TRAINING [Esc]")
	Charcoal.style_button(close_button)
	Charcoal.key_text(close_button)
	close_button.custom_minimum_size.y = 48
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_button.add_theme_font_size_override("font_size",16)
	# as wide as its words and its keycap (it was cut to "返回训")
	var cw := Charcoal.split_words(close_button.text)
	var fk: Font = Fonts.get_font("SemiBold")
	var kw := maxf(40.0,fk.get_string_size(str(cw[1]),HORIZONTAL_ALIGNMENT_LEFT,-1,14).x + 18.0)
	close_button.custom_minimum_size.x = Fonts.get_font("Regular").get_string_size(str(cw[0]),HORIZONTAL_ALIGNMENT_LEFT,-1,16).x + kw + 18.0 + 14.0 + 12.0 + 24.0
	close_button.pressed.connect(close)
	heading.add_child(close_button)
	# the picker: kept (keys, tests), not shown
	picker = OptionButton.new()
	for title_text in _titles(): picker.add_item(title_text)
	picker.visible = false
	column.add_child(picker)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",28)
	column.add_child(body)
	# the courses: numbered keys, the chosen one sunk with its lamp lit and the orange lip
	var keys := VBoxContainer.new()
	keys.custom_minimum_size.x = 420
	keys.add_theme_constant_override("separation",8)
	body.add_child(keys)
	var titles := _titles()
	for i in titles.size():
		var b := Button.new()
		b.text = str(titles[i])
		b.custom_minimum_size.y = 62
		b.add_theme_font_size_override("font_size",17)
		var idx := i
		Charcoal.style_choice(b,func(): return picker.selected == idx)
		for st in ["normal","hover","pressed","hover_pressed","disabled"]:
			var sb: StyleBoxFlat = (b.get_theme_stylebox(st) as StyleBoxFlat).duplicate()
			sb.content_margin_left = 82.0
			b.add_theme_stylebox_override(st,sb)
		b.draw.connect(func():
			var on := picker.selected == idx
			b.draw_string(Fonts.get_font("Light"),Vector2(36,42),"%02d" % (idx + 1),HORIZONTAL_ALIGNMENT_LEFT,-1,26,Charcoal.ACCENT if on else Pal.ink(0.5)))
		b.pressed.connect(func():
			picker.select(idx)
			refresh())
		keys.add_child(b)
		course_keys.append(b)
	# the lessons: a plate, scrolled
	var plate := PanelContainer.new()
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plate.add_theme_stylebox_override("panel",Charcoal.side_box(28.0))
	body.add_child(plate)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	plate.add_child(_scroll)
	# the wheel scrolls it (ScrollContainer); a drag with the left button too; its ends fade where more
	# lies beyond them, a thin bar at its right says where it stands
	_scroll.gui_input.connect(_drag_scroll)
	_fade = Control.new()
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.draw.connect(_draw_fade)
	plate.add_child(_fade)
	_scroll.get_v_scroll_bar().value_changed.connect(func(_v): _fade.queue_redraw())
	_scroll.get_v_scroll_bar().changed.connect(_fade.queue_redraw)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",18)
	_scroll.add_child(content)
	picker.item_selected.connect(func(_index): refresh())
	UiSkin.scroll_into(skin)
	refresh()
var _fade: Control
var _dragging := false
func _drag_scroll(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_dragging = ev.pressed
	elif ev is InputEventMouseMotion and _dragging:
		_scroll.scroll_vertical -= int(ev.relative.y)
		_scroll.accept_event()
func _draw_fade() -> void:
	var bar := _scroll.get_v_scroll_bar()
	var s := _fade.size
	var face := Charcoal.FACE
	var clear := Color(face,0.0)
	var fh := 70.0
	if bar.value > 1.0:
		_fade.draw_polygon(PackedVector2Array([Vector2(0,0),Vector2(s.x,0),Vector2(s.x,fh),Vector2(0,fh)]),PackedColorArray([face,face,clear,clear]))
	var more := bar.value < bar.max_value - bar.page - 1.0
	if more:
		_fade.draw_polygon(PackedVector2Array([Vector2(0,s.y - fh),Vector2(s.x,s.y - fh),Vector2(s.x,s.y),Vector2(0,s.y)]),PackedColorArray([clear,clear,face,face]))
		var f: Font = Fonts.get_font("Medium")
		var t := words("向下滚动查看更多 ▾","SCROLL FOR MORE ▾")
		_fade.draw_string(f,Vector2(s.x * 0.5 - f.get_string_size(t,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x * 0.5,s.y - 10),t,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Pal.ink(0.6))
	# where it stands: a thin bar at the right edge
	if bar.max_value > bar.page + 1.0:
		var track := Rect2(s.x - 8,28,3,s.y - 56)
		_fade.draw_rect(track,Color(1,1,1,0.06))
		var hh := track.size.y * bar.page / bar.max_value
		var yy := track.position.y + (track.size.y - hh) * (bar.value / maxf(1.0,bar.max_value - bar.page))
		_fade.draw_rect(Rect2(track.position.x,yy,3,hh),Charcoal.ACCENT)
func localized(value) -> String:
	return str(value.get("zh" if Txt.zh else "en","")) if value is Dictionary else Txt.t(str(value))
# a lesson's head: its number large, its title
func _lesson_head(n: int, title: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	var no := line("%02d" % n,34)
	no.add_theme_font_override("font",Fonts.get_font("Light"))
	no.add_theme_color_override("font_color",Charcoal.ACCENT)
	no.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(no)
	var t := line(title,22)
	t.add_theme_font_override("font",Fonts.get_font("SemiBold"))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(t)
	return row
# the steps in one black window, each numbered; no lone character on a line's end
func _steps(texts: Array) -> Control:
	var well := PanelContainer.new()
	well.mouse_filter = Control.MOUSE_FILTER_PASS
	well.add_theme_stylebox_override("panel",Charcoal.well_box(18.0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",12)
	well.add_child(v)
	var f: Font = Fonts.get_font("Regular")
	for i in texts.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",14)
		v.add_child(row)
		var n := line("%d" % (i + 1),17)
		n.add_theme_font_override("font",Fonts.get_font("Medium"))
		n.add_theme_color_override("font_color",Pal.ink(0.45))
		n.custom_minimum_size.x = 24
		n.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(n)
		var t := line(str(texts[i]),17)
		t.add_theme_color_override("font_color",Pal.ink(0.88))
		# as wide as the plate allows (at 1280 the plate is narrower than TEXT_W), the last line no scrap
		var wmax := minf(TEXT_W,get_viewport_rect().size.x - 720.0)
		t.custom_minimum_size.x = Charcoal.fit_width(f,str(texts[i]),wmax,17)
		t.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		row.add_child(t)
	return well
func refresh() -> void:
	for node in content.get_children():
		content.remove_child(node)
		node.queue_free()
	for b in course_keys:
		b.queue_redraw()
	if _scroll != null:
		_scroll.scroll_vertical = 0
	if picker.selected == 8:
		var n := 1
		for page in GuideCopy.pages():
			content.add_child(_lesson_head(n,str(page.id)+" · "+GuideCopy.localized(page.title)))
			content.add_child(_steps([GuideCopy.localized(page.body)]))
			n += 1
		return
	if picker.selected == 9:
		content.add_child(_lesson_head(1,words("把前面学会的操作连起来用","PUT YOUR TRAINING INTO PRACTICE")))
		content.add_child(_steps([words("进入考核后，先看清本次目标。先测量、查连接，再按现场情况断电、放电、排空、拆卸和搬运。不要只凭关机或一次旧读数判断安全。","Read the assessment objective. Inspect connections and measurements before isolating, discharging, draining, dismantling and hauling. Shutdown or an old reading alone does not prove safety."),words("考核使用配备好的基础工具，不用先买工具配件。查看这里不会替你完成任务；关掉总览后继续原来的进度。","Basic tools are supplied. Reading this overview does not complete objectives; close it to resume your existing progress.")]))
		return
	var file := FileAccess.open("res://ships/%s_course.json" % COURSES[picker.selected],FileAccess.READ)
	if file == null: return
	var course: Dictionary = JSON.parse_string(file.get_as_text())
	var li := 1
	for lesson in course.get("lessons",[]):
		content.add_child(_lesson_head(li,localized(lesson.title)))
		var texts: Array = []
		for index in lesson.get("steps",[]).size():
			texts.append(localized(lesson.steps[index].text))
		content.add_child(_steps(texts))
		li += 1
func close() -> void:
	if on_close.is_valid(): on_close.call()
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
