extends CanvasLayer
# 96 号 (Q3 B, Jev B 0.95): the port's facility card. Hovering a machine inside a district shows,
# by the pointer, what it is, what it is doing now and what the player can do with it — the plate
# on the wall says only the name and one state. Any district can feed it: `items` is a Callable
# returning [{rect (world px), title, use, now, can, lamp}] for the machines in view; the first
# rect under the pointer wins. It waits a moment before showing (a pointer passing over shows
# nothing), fades in and out, stays inside the screen, and never takes input.

const DELAY := 0.25
const W := 380.0

var game
var items := Callable()
var c: Control
var font: Font
var font_b: Font
var k := 0.0
var _over := ""
var _held := 0.0
var _shown := {}
var _list: Array = []
var _age := 0.0
var probe := Vector2.INF        # tests: a world point standing in for the pointer (the mouse is never moved)


func _ready() -> void:
	layer = 25
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
	c = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_draw_card)
	add_child(c)


func _process(dt: float) -> void:
	var hit := {}
	if items.is_valid() and game != null and is_instance_valid(game) and game.console_ui == null and not game.menu_open and not game.port_view:
		var vp := get_viewport()
		var world: Vector2 = probe if probe != Vector2.INF else vp.get_canvas_transform().affine_inverse() * vp.get_mouse_position()
		# the cards' words are made at most ten times a second (they name live states)
		_age -= dt
		if _age <= 0.0 or _list.is_empty():
			_age = 0.1
			_list = items.call()
		for it in _list:
			if (it.rect as Rect2).has_point(world):
				hit = it
				break
	var id := str(hit.get("title", ""))
	if id != _over:
		_over = id
		_held = 0.0
	_held += dt
	var want := 1.0 if id != "" and _held >= DELAY else 0.0
	if want > 0.0:
		_shown = hit
	k = move_toward(k, want, dt * 7.0)
	if k > 0.0 or want > 0.0:
		c.queue_redraw()


static func lamp_col(state: String) -> Color:
	match state:
		"ok": return Pal.tint(Pal.FLUID, 0.95, 1.3)
		"work": return Pal.heat(0.9, 1.3)
		"warn": return Color(1.0, 0.3, 0.22)
	return Pal.ink(0.35)


func _draw_card() -> void:
	if k <= 0.0 or _shown.is_empty():
		return
	var a := Pal.ease_out(k)
	var mouse := c.get_local_mouse_position() if probe == Vector2.INF else get_viewport().get_canvas_transform() * probe
	var rows: Array = [
		[("用途" if Txt.zh else "WHAT"), str(_shown.get("use", ""))],
		[("现在" if Txt.zh else "NOW"), str(_shown.get("now", ""))],
		[("你能做" if Txt.zh else "YOU"), str(_shown.get("can", ""))],
	]
	var lw := W - 96.0
	var h := 50.0
	var heights: Array = []
	for r in rows:
		var hh: float = font.get_multiline_string_size(str(r[1]), HORIZONTAL_ALIGNMENT_LEFT, lw, 14).y
		heights.append(hh)
		h += hh + 8.0
	var vs := c.size
	var pos := mouse + Vector2(22, 18)
	if pos.x + W > vs.x - 12.0:
		pos.x = mouse.x - W - 22.0
	if pos.y + h > vs.y - 12.0:
		pos.y = vs.y - h - 12.0
	pos.y += (1.0 - a) * 6.0
	var r := Rect2(pos, Vector2(W, h))
	c.draw_style_box(UiSkin.box("panel", a), r)
	var lc := lamp_col(str(_shown.get("lamp", "")))
	c.draw_rect(Rect2(r.position + Vector2(10, 12), Vector2(3, h - 24)), Color(lc, a))
	c.draw_string(font_b, r.position + Vector2(24, 30), str(_shown.title), HORIZONTAL_ALIGNMENT_LEFT, W - 40.0, 17, Pal.ink(0.95 * a))
	var y := r.position.y + 50.0
	for i in rows.size():
		c.draw_string(font, Vector2(r.position.x + 24, y + 13), str(rows[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.5 * a))
		c.draw_multiline_string(font, Vector2(r.position.x + 82, y + 13), str(rows[i][1]), HORIZONTAL_ALIGNMENT_LEFT, lw, 14, -1, (Color(lc, a) if i == 1 else Pal.ink(0.85 * a)))
		y += float(heights[i]) + 8.0
