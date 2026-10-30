extends Control
# Review physical engineering receipts before the one atomic settlement.
# Switching options previews the result; it never alters cash or inventory.
var game
var on_confirm: Callable
var on_cancel: Callable
var selling := false
var card: Panel
var inventory_label: Label
var outcome_label: Label
var cash_label: Label
var fee_label: Label
var reserve_button: Button
var sale_button: Button
var confirm_button: Button
var back_button: Button

func words(zh: String,en: String) -> String:
	return zh if Txt.zh else en
func label(text: String,px: int = 20) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_font_size_override("font_size",px)
	return node
func button(text: String,action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 44
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.pressed.connect(action)
	return node
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var skin := Theme.new()
	skin.default_font = Fonts.get_font("Regular")
	skin.default_font_size = 20
	for state in ["normal","hover","pressed","focus","disabled"]:
		skin.set_stylebox(state,"Button",SkillBook._key_box(state))
	theme = skin
	var shade := ColorRect.new()
	shade.color = Color(0.009,0.011,0.013,1.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	card = Panel.new()
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.018,0.021,0.025,1.0)
	plate.border_color = Color(0.4,0.43,0.46,0.7)
	plate.set_border_width_all(1)
	card.add_theme_stylebox_override("panel",plate)
	add_child(card)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	margin.add_child(column)
	column.add_child(label(words("结算 / 工程回收物","SETTLEMENT / ENGINEERING GOODS"),28))
	column.add_child(label(game.work_order.text(game.work_order.id),20))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",12)
	scroll.add_child(body)
	inventory_label = label("")
	body.add_child(inventory_label)
	outcome_label = label("",20)
	body.add_child(outcome_label)
	cash_label = label("")
	body.add_child(cash_label)
	fee_label = label("")
	body.add_child(fee_label)
	var group := ButtonGroup.new()
	reserve_button = button(words("预留给工程","RESERVE FOR ENGINEERING"),func(): select_sale(false))
	sale_button = button(words("出售回收物","SELL RECOVERED GOODS"),func(): select_sale(true))
	for node in [reserve_button,sale_button]:
		node.toggle_mode = true
		node.button_group = group
		column.add_child(node)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",12)
	column.add_child(actions)
	confirm_button = button(words("确认结算","CONFIRM SETTLEMENT"),func(): on_confirm.call(selling))
	back_button = button(words("继续作业","RETURN TO JOB"),func(): on_cancel.call())
	actions.add_child(confirm_button)
	actions.add_child(back_button)
	var focus: Array = [reserve_button,sale_button,confirm_button,back_button]
	for i in focus.size():
		focus[i].focus_next = focus[i].get_path_to(focus[(i+1)%focus.size()])
		focus[i].focus_previous = focus[i].get_path_to(focus[(i+focus.size()-1)%focus.size()])
	select_sale(game.work_order.sell)
	resized.connect(resize_card)
	resize_card()
	confirm_button.grab_focus.call_deferred()

func resize_card() -> void:
	card.size = Vector2(minf(860.0,size.x-48.0),minf(640.0,size.y-48.0))
	card.position = (size-card.size)*0.5

func select_sale(value: bool) -> void:
	selling = value
	reserve_button.set_pressed_no_signal(not selling)
	sale_button.set_pressed_no_signal(selling)
	var order = game.work_order
	var lines: Array = []
	for r in order.previous: lines.append(words("已有预留：","PRIOR RESERVATION: ")+" / ".join(r.keys))
	for r in order.receipts: lines.append(words("本次回收：","RECOVERED THIS JOB: ")+" / ".join(r.keys))
	inventory_label.text = "\n".join(lines)
	if selling:
		outcome_label.text = words("出售入账，本次不交付工程。","Sell for cash. No engineering delivery this time.")
	elif order.ready_for_engineering():
		outcome_label.text = words("交付完成后：","AFTER DELIVERY: ")+order.text(order.id,"next")
		if order.id == "heavy":
			var reward: String = order.selected_reward(game.job)
			if reward == "field_stock":
				outcome_label.text = words("交付完成后：获得自有牵引锚与监测探头。","AFTER DELIVERY: receive an owned anchor and monitoring probe.")
			else:
				outcome_label.text = words("交付完成后恢复：","RESTORE AFTER DELIVERY: ")+Repair.name_of(reward)+"\n"+Repair.desc_of(reward)
	else:
		outcome_label.text = words("预留入库；下次带回剩余目标即可继续交付。","Keep these goods reserved. Bring the remaining targets on a later job.")
	cash_label.text = words("工程回收物计入现金：","CASH FROM ENGINEERING GOODS: ")+Pal.money(order.cash_from_goods(selling))
	fee_label.text = words("本次装配费：","ASSEMBLY COST: ")+Pal.money(order.assembly_cost(selling))

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		on_cancel.call()
