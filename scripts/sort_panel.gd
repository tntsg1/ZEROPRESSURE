extends "res://scripts/heat_panel.gd"
# The cold line is site-operated; this view observes the same live mechanics.
# 37 号 (player 2026-10-25): one button runs the whole line — sorted, read by the in-line assay,
# melted in the arc furnace; "sort only" and the drives are under "more"
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := OpsSkin.pane(self, Charcoal.ACCENT, 420.0)
	plate = OpsSkin.Plate.new("MGS-07", words("分选线 · 全线加工","SORTING LINE · THROUGH"), words("压块 → 撕碎 → 磁选 → 线上化验 → 电弧炉
有色料回仓库 · 电费按电网","PRESS / SHRED / MAGNETS / IN-LINE ASSAY / ARC FURNACE
NONFERROUS TO THE WAREHOUSE"), Charcoal.ACCENT)
	column.add_child(plate)
	readout = OpsSkin.as_screen(label("", 17))
	readout.custom_minimum_size.y = 110
	column.add_child(readout)
	next_step = label("", 16)
	column.add_child(next_step)
	feed_row = HBoxContainer.new()
	var feed_label := label(words("待分选金属 / t","MIXED METAL / t"))
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
	more_key = button(words("展开更多操作 ▾","MORE ▾"), func():
		more.visible = not more.visible
		more_key.text = words("收起更多操作 ▴","MORE ▴") if more.visible else words("展开更多操作 ▾","MORE ▾"))
	BenchFx.note(more_key, words("点击展开或收起分选台的其他操作选项", "Show or hide the sorting desk's other keys"))
	BenchFx.primary(main)
	BenchFx.note(main, words("根据分选台当前的运行状态，执行下一步操作 [Enter]", "The sorting desk's next step, as it stands now (Enter)"))
	column.add_child(more_key)
	more = VBoxContainer.new()
	more.visible = false
	column.add_child(more)
	# 人性化 规则 4: each key's plain note
	more.add_child(BenchFx.noted(button(GuideCopy.text("sort.send_feed") + words("（仅进行金属分选，两种产物都会送回仓库）"," (SORT ONLY)"),func():show_result(service.begin(quantity.value))), words("将这些原料送入分选线，不经过熔炉处理，分选出来的两种产物都会送回仓库", "Send this feed to be sorted only; both outputs go back to the store")))
	more.add_child(BenchFx.noted(button(words("启动分选设备","START DRIVES"),func():show_result(service.command("start"))), words("启动分选线的电机，开始进行原料分选", "Start the sorting line's drives now")))
	more.add_child(BenchFx.noted(button(words("停止分选设备","STOP DRIVES"),func():show_result(service.command("stop"))), words("关闭分选线的电机，暂停原料分选", "Stop the sorting line's drives now")))
	more.add_child(BenchFx.noted(button(words("退回未处理的原料","RETURN UNPROCESSED FEED"),func():show_result(service.cancel())), words("将还没有完成分选的原料全部退回仓库", "Send the feed not yet sorted back to the store")))
	more.add_child(BenchFx.noted(button(words("报废运输中的货物（不予退款）","WRITE OFF CARGO / NO REFUND"),func():show_result(service.write_off())), words("直接报废这批运输中的货物，已经支付的费用不会退还，建议只在无法继续处理时使用", "Scrap this batch for nothing; only when it cannot be saved")))
	column.add_spacer(false)
	column.add_child(button(words("关闭面板 [Esc]","CLOSE [Esc]"),close))
	_update()


func _next() -> Array:
	var b: Dictionary = service.heat()
	var st := str(b.get("state",""))
	if service.fault != "":
		return [service.fault, Callable()]
	match st:
		"", "complete", "cancelled", "written_off":
			return [words("完整加工流程（分选 → 化验 → 炼钢）","RUN THE LINE (SORT · ASSAY · MELT)"), func(): show_result(service.begin(quantity.value, true))]
		"raw_transport":
			return [words("正在从仓库运送原料…","FEED ON ITS WAY…"), Callable()]
		"raw_return":
			return [words("正在将原料退回仓库…","FEED GOING BACK…"), Callable()]
		"processing":
			if not bool(service.line().company_powered) and not b.get("through", false):
				return [words("启动分选设备","START DRIVES"), func(): show_result(service.command("start"))]
			return [words("正在分选 · 设备内剩余 %.2f t 原料" % service.line().in_process_mass(),"SORTING · %.2f t IN" % service.line().in_process_mass()), Callable()]
		"product_transport":
			if service._through_now():
				return [words("黑色金属原料正在进行化验，即将送入电弧炉…","FERROUS TO THE ASSAY AND THE FURNACE…"), Callable()]
			return [words("正在将加工产物送回仓库…","OUTPUT GOING BACK…"), Callable()]
	return [words("完整加工流程（分选 → 化验 → 炼钢）","RUN THE LINE"), func(): show_result(service.begin(quantity.value, true))]


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
	next_step.text = service.waiting if service.waiting != "" else words("一键启动完整加工流程：系统会从仓库运来原料，完成分选后，黑色金属原料会经过在线化验并直接送入电弧炉，电弧炉自动通电。你只需要前往炉台测量温度并完成出钢，有色金属原料则会送回仓库。","ONE PRESS RUNS THE LINE: FERROUS STRAIGHT TO THE ARC FURNACE, WHICH STARTS ITSELF; YOU SAMPLE AND TAP AT THE FURNACE DESK.")
