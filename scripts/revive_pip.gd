extends CanvasLayer
# 128 号 第 3 段 (用户 2026-11-04): the camera never moves — the lighting of a mended district plays
# live in a small picture at the screen's edge while the player carries on. A SubViewport on the
# same world as the game, its own camera framing the district; under it the district's name and
# what is happening now. The first mending of each district plays whole; later ones (its second
# stage) can be skipped with any key. Top right, under the recording strip (Jev A 0.50, to confirm).

const PortStructure = preload("res://scripts/port_structure.gd")
const PW := 480.0
const PH := 224.0
var zone := "trade"
var revive                       # the district's scripts/district_revive.gd
var skippable := false
var vp: SubViewport
var cam: Camera2D
var frame: Control
var font: Font
var t := 0.0


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ready() -> void:
	layer = 19
	font = Fonts.get_font("Medium")
	vp = SubViewport.new()
	vp.size = Vector2i(int(PW), int(PH))
	vp.world_2d = get_viewport().world_2d
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	cam = Camera2D.new()
	var b := PortStructure.box(zone)
	cam.position = b.get_center()
	var z := minf(PW / (b.size.x * 1.06), PH / (b.size.y * 1.06))
	cam.zoom = Vector2(z, z)
	vp.add_child(cam)
	cam.make_current()
	frame = Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.draw.connect(_draw_frame)
	add_child(frame)


func rect() -> Rect2:
	var s := get_viewport().get_visible_rect().size
	return Rect2(Vector2(s.x - PW - 26, 96), Vector2(PW, PH))


func _process(dt: float) -> void:
	t += dt
	frame.queue_redraw()


func _stage_text() -> String:
	if revive == null:
		return ""
	var s: float = revive.t
	if revive.mode == "done":
		return w("完工", "DONE")
	if s < revive.T_ARRIVE:
		return w("施工小艇进场", "THE WORK BOAT COMES IN")
	if s < revive.T_WELD:
		return w("施工队焊接总配电柜", "THE CREW WELDS THE MAIN CABINET")
	if s < revive.T_CABINET:
		return w("总配电柜合闸", "MAIN CABINET CLOSED")
	if s < revive.T_CABLE:
		return w("送电中 · %d%%", "POWERING UP · %d%%") % int(100.0 * (s - revive.T_CABINET) / (revive.T_CABLE - revive.T_CABINET))
	if s < revive.T_MACHINES:
		return w("设备依次启动", "THE MACHINES START")
	return w("名牌亮起", "NAMEPLATE ON")


func _draw_frame() -> void:
	var r := rect()
	var k := BenchFx.e_out5(clampf(t / 0.45, 0.0, 1.0))
	var rr := Rect2(r.position + Vector2((1.0 - k) * 60.0, 0), r.size)
	frame.draw_rect(rr.grow(6), Color(0.02, 0.023, 0.028, 0.95 * k))
	frame.draw_texture_rect(vp.get_texture(), rr, false, Color(1, 1, 1, k))
	frame.draw_rect(rr, Color(UiSkin.ACCENT, 0.7 * k), false, 1.0)
	# head: a live dot, the district, what is happening now
	var hy := rr.position.y - 12
	var blink := 0.5 + 0.5 * sin(t * 6.0)
	frame.draw_circle(Vector2(rr.position.x + 8, hy - 4), 4.0, Color(1.0, 0.25, 0.2, (0.5 + 0.5 * blink) * k))
	frame.draw_string(font, Vector2(rr.position.x + 20, hy), w("直播 · %s 修好了", "LIVE · %s MENDED") % Port.name_of(zone), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.92 * k))
	frame.draw_string(font, Vector2(rr.end.x - 260, hy), _stage_text(), HORIZONTAL_ALIGNMENT_RIGHT, 260, 13, Color(UiSkin.ACCENT, 0.9 * k))
	# the progress along the bottom edge
	if revive != null:
		var p := clampf(float(revive.t) / float(revive.T_END), 0.0, 1.0) if revive.mode == "revive" else 1.0
		frame.draw_rect(Rect2(rr.position + Vector2(0, rr.size.y - 3), Vector2(rr.size.x * p, 3)), Color(UiSkin.ACCENT, 0.9 * k))
	if skippable:
		frame.draw_string(font, Vector2(rr.position.x, rr.end.y + 22), w("按任意键跳过", "ANY KEY TO SKIP"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.5 * k))
