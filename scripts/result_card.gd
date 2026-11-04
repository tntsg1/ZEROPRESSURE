class_name ResultCard
extends PanelContainer
# 126 号 (user 2026-11-04: "加工完成后，希望有清楚的结果提示，例如：本次加工完成：获得 X 吨钢坯，已放入仓库。
# 【查看仓库】"): a card that says what a piece of work came to, with the one button that shows it.
# Stays until it is read (closed, or its button pressed), or 20 s; one at a time, the newest wins.

var on_go: Callable
var _t := 0.0
const LIFE := 20.0


static func pop(parent: Node, title: String, body: String, go_text: String, go: Callable) -> Control:
	for c in parent.get_children():
		if c.get_script() == preload("res://scripts/result_card.gd"):
			c.queue_free()
	var card = preload("res://scripts/result_card.gd").new()
	card.on_go = go
	parent.add_child(card)
	card._build(title, body, go_text)
	return card


func _build(title: String, body: String, go_text: String) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.07, 0.96)
	sb.border_color = Color(UiSkin.DATA, 0.85)
	sb.set_border_width_all(1)
	sb.border_width_left = 4
	sb.set_content_margin_all(18)
	add_theme_stylebox_override("panel", sb)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	var t := Label.new()
	t.text = title
	t.add_theme_font_override("font", Fonts.get_font("SemiBold"))
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", Pal.ink(0.97))
	v.add_child(t)
	var b := Label.new()
	b.text = body
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size.x = 520
	b.add_theme_font_override("font", Fonts.get_font("Medium"))
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Pal.ink(0.8))
	v.add_child(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	if go_text != "":
		var go := Button.new()
		go.text = go_text
		go.custom_minimum_size = Vector2(180, 40)
		UiSkin.accent_button(go)
		go.pressed.connect(func():
			if on_go.is_valid():
				on_go.call()
			queue_free())
		row.add_child(go)
	var x := Button.new()
	x.text = "知道了" if Txt.zh else "OK"
	x.custom_minimum_size = Vector2(110, 40)
	x.pressed.connect(queue_free)
	row.add_child(x)
	_place.call_deferred()


func _place() -> void:
	var s: Vector2 = (get_parent() as Control).size if get_parent() is Control else get_viewport_rect().size
	reset_size()
	position = Vector2((s.x - size.x) * 0.5, 290.0)


func _process(dt: float) -> void:
	_t += dt
	if _t > LIFE:
		queue_free()
