extends PanelContainer
# Readable index of the actual courses; it never advances lesson progress.
const GuideCopy = preload("res://scripts/onboarding_text.gd")
const COURSES := ["ts1","sp_energy","sp_cryo","sp_fluid","sp_atmos","sp_load","sp_precise","sp_isolate"]
var on_close: Callable
var picker: OptionButton
var content: VBoxContainer
func words(zh: String,en: String) -> String: return zh if Txt.zh else en
func line(value: String,size_px: int = 18) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",size_px)
	return label
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var skin := Theme.new()
	skin.default_font = Fonts.get_font("Regular")
	skin.default_font_size = 18
	theme = skin
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0d171e")
	box.set_content_margin_all(32)
	add_theme_stylebox_override("panel",box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := line(words("整套新手教程","THE COMPLETE TUTORIAL"),28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close_button := Button.new()
	close_button.text = words("返回训练 [Esc]","BACK TO TRAINING [Esc]")
	close_button.custom_minimum_size.y = 44
	close_button.pressed.connect(close)
	heading.add_child(close_button)
	heading.move_child(close_button,0)
	column.add_child(line(words("先学飞行和拆船，再学处理危险，最后学用自己的材料生产、卖货。基础工具一直能用，不用买探针、透镜或电容。","Learn flight and salvage, then hazards, then production and trade with owned stock. Basic tools never need purchased tips, lenses or capacitors.")))
	picker = OptionButton.new()
	for title_text in [words("基础训练：飞行、拆解和回收","BASIC TRAINING"),words("能量设备：先释放储能","ENERGY SYSTEMS"),words("低温设备：按顺序回温","CRYOGENICS"),words("流体设备：压力、阀门和回收","FLUID SYSTEMS"),words("特殊环境：富氧、烟气和余热","ATMOSPHERE & RESIDUAL HEAT"),words("重载机构：先卸力再拆","PRELOADED STRUCTURES"),words("精密设备：保护完整性","PRECISION EQUIPMENT"),words("独立舱段：查清连接与电源","ISOLATION"),words("经营入门：买料、炼钢、卖货","MARKET & PRODUCTION")]: picker.add_item(title_text)
	picker.add_item(words("考核：独立完成拆解任务","ASSESSMENT"))
	column.add_child(picker)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",16)
	scroll.add_child(content)
	picker.item_selected.connect(func(_index): refresh())
	refresh()
func localized(value) -> String:
	return str(value.get("zh" if Txt.zh else "en","")) if value is Dictionary else Txt.t(str(value))
func refresh() -> void:
	for node in content.get_children():
		content.remove_child(node)
		node.queue_free()
	if picker.selected == 8:
		for page in GuideCopy.pages():
			content.add_child(line(str(page.id)+" · "+GuideCopy.localized(page.title),22))
			content.add_child(line(GuideCopy.localized(page.body)))
		return
	if picker.selected == 9:
		content.add_child(line(words("把前面学会的操作连起来用","PUT YOUR TRAINING INTO PRACTICE"),22))
		content.add_child(line(words("进入考核后，先看清本次目标。先测量、查连接，再按现场情况断电、放电、排空、拆卸和搬运。不要只凭关机或一次旧读数判断安全。","Read the assessment objective. Inspect connections and measurements before isolating, discharging, draining, dismantling and hauling. Shutdown or an old reading alone does not prove safety.")))
		content.add_child(line(words("考核使用配备好的基础工具，不用先买工具配件。查看这里不会替你完成任务；关掉总览后继续原来的进度。","Basic tools are supplied. Reading this overview does not complete objectives; close it to resume your existing progress.")))
		return
	var file := FileAccess.open("res://ships/%s_course.json" % COURSES[picker.selected],FileAccess.READ)
	if file == null: return
	var course: Dictionary = JSON.parse_string(file.get_as_text())
	for lesson in course.get("lessons",[]):
		content.add_child(line(localized(lesson.title),22))
		for index in lesson.get("steps",[]).size():
			content.add_child(line("%d. %s" % [index+1,localized(lesson.steps[index].text)]))
func close() -> void:
	if on_close.is_valid(): on_close.call()
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
