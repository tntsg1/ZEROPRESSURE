extends "res://scripts/heat_panel.gd"
# The cold line is site-operated; this view observes the same live mechanics.
# 37 号 (player 2026-10-25): one button runs the whole line — sorted, read by the in-line assay,
# melted in the arc furnace; "sort only" and the drives are under "more"
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := OpsSkin.pane(self, Pal.tint(Pal.AIR, 1.0, 1.2), 420.0)
	plate = OpsSkin.Plate.new("MGS-07", words("分选线 · 整线加工","SORTING LINE · THROUGH"), words("压块 → 撕碎 → 磁选 → 线上化验 → 电弧炉
有色料回仓库 · 电费按电网","PRESS / SHRED / MAGNETS / IN-LINE ASSAY / ARC FURNACE
NONFERROUS TO THE WAREHOUSE"), Pal.tint(Pal.AIR, 1.0, 1.2))
	column.add_child(plate)
	readout = OpsSkin.as_screen(label("", 17))
	readout.custom_minimum_size.y = 110
	column.add_child(readout)
	next_step = label("", 16)
	column.add_child(next_step)
	feed_row = HBoxContainer.new()
	var feed_label := label(words("未分选金属 / t","MIXED METAL / t"))
	feed_label.custom_minimum_size.x = 130
	feed_row.add_child(feed_label)
	quantity = SpinBox.new()
	quantity.min_value = 0.3
	quantity.max_value = 2.0
	quantity.step = 0.01
	quantity.value = 1.0
	quantity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quantity.value_changed.connect(func(_v): _qty_touched = true)
	feed_row.add_child(quantity)
	column.add_child(feed_row)
	main = button("", _press_main)
	main.custom_minimum_size.y = 64
	main.add_theme_font_size_override("font_size", 22)
	column.add_child(main)
	message = label("",15)
	column.add_child(message)
	more_key = button(words("更多 ▾","MORE ▾"), func():
		more.visible = not more.visible
		more_key.text = words("更多 ▴","MORE ▴") if more.visible else words("更多 ▾","MORE ▾"))
	column.add_child(more_key)
	more = VBoxContainer.new()
	more.visible = false
	column.add_child(more)
	more.add_child(button(GuideCopy.text("sort.send_feed") + words("（只分选，两路产物回仓）"," (SORT ONLY)"),func():show_result(service.begin(quantity.value))))
	more.add_child(button(words("启动分选驱动","START DRIVES"),func():show_result(service.command("start"))))
	more.add_child(button(words("停止分选驱动","STOP DRIVES"),func():show_result(service.command("stop"))))
	more.add_child(button(words("撤回未处理原料","RETURN UNPROCESSED FEED"),func():show_result(service.cancel())))
	more.add_child(button(words("报损运输货物（无退款）","WRITE OFF CARGO / NO REFUND"),func():show_result(service.write_off())))
	column.add_spacer(false)
	column.add_child(button(words("关闭 [Esc]","CLOSE [Esc]"),close))
	_update()


func _next() -> Array:
	var b: Dictionary = service.heat()
	var st := str(b.get("state",""))
	if service.fault != "":
		return [service.fault, Callable()]
	match st:
		"", "complete", "cancelled", "written_off":
			return [words("整线加工（分选 → 化验 → 炼钢）","RUN THE LINE (SORT · ASSAY · MELT)"), func(): show_result(service.begin(quantity.value, true))]
		"raw_transport":
			return [words("原料运送中…","FEED ON ITS WAY…"), Callable()]
		"raw_return":
			return [words("原料退回仓库中…","FEED GOING BACK…"), Callable()]
		"processing":
			if not bool(service.line().company_powered) and not b.get("through", false):
				return [words("启动分选驱动","START DRIVES"), func(): show_result(service.command("start"))]
			return [words("分选中 · 设备里 %.2f t" % service.line().in_process_mass(),"SORTING · %.2f t IN" % service.line().in_process_mass()), Callable()]
		"product_transport":
			if service._through_now():
				return [words("黑色料过化验、进电弧炉…","FERROUS TO THE ASSAY AND THE FURNACE…"), Callable()]
			return [words("产物送回仓库中…","OUTPUT GOING BACK…"), Callable()]
	return [words("整线加工（分选 → 化验 → 炼钢）","RUN THE LINE"), func(): show_result(service.begin(quantity.value, true))]


func _update() -> void:
	var b: Dictionary = service.heat()
	feed_row.visible = str(b.get("state","")) in ["", "complete", "cancelled", "written_off"]
	if not _qty_touched and feed_row.visible:
		var have: float = float(Career.data.get("exchange",{}).get("actors",{}).get("company",{}).get("stock",{}).get("mixed_metal:0",0.0))
		if have >= 0.3:
			quantity.set_value_no_signal(floorf(minf(have, 2.0) * 100.0) / 100.0)
	var n := _next()
	main.text = str(n[0])
	_main_cb = n[1]
	main.disabled = not _main_cb.is_valid()


func _process(dt: float) -> void:
	_update()
	_refresh += dt
	if _refresh < 0.2: return
	_refresh = 0.0
	var batch: Dictionary = service.heat()
	if service.fault != "": readout.text = service.fault; return
	var line = service.line()
	var have: float = float(Career.data.get("exchange",{}).get("actors",{}).get("company",{}).get("stock",{}).get("mixed_metal:0",0.0))
	readout.text = "%s %.2f t · %s %.2f / %.2f t
%s $%.2f%s
%s %.2f t" % [words("设备里","IN"), line.in_process_mass(), words("黑色 / 有色","FERROUS / NONFERROUS"), line.company_fe, line.company_nf, words("电费","POWER"), float(batch.get("energy_cost",0.0)), (words(" · 待缴 $%.2f" % float(batch.energy_debt), " · DUE $%.2f" % float(batch.energy_debt)) if float(batch.get("energy_debt",0.0)) > 0.005 else ""), words("仓库未分选金属","MIXED METAL IN STOCK"), have]
	next_step.text = service.waiting if service.waiting != "" else words("一键跑完整条线：原料从仓库运来，分选后黑色料经线上化验直接进电弧炉，炉子自己通电；你到炉台测温、出钢。有色料回仓库。","ONE PRESS RUNS THE LINE: FERROUS STRAIGHT TO THE ARC FURNACE, WHICH STARTS ITSELF; YOU SAMPLE AND TAP AT THE FURNACE DESK.")
