extends RefCounted
# 135 号 (user 2026-11-10: "这些船的缩略图也做得很难看…看着很诡异"): a ship type's picture for the
# hulk market, drawn the way the berth draws it. The real ship is built in a World inside an
# off-screen SubViewport — hull, rooms opened, every machine with its own art — framed whole and
# rendered once; pipes, lights and the like are left out (at this size they only clutter).
#   baked: tests/ship_thumb_bake.gd writes assets/ship_thumbs/<id>.res (lossless, one per type)
#     with index.json holding each ship file's md5 at the time
#   missing or out of date (the ship file changed since): drawn here while the market is open,
#     one at a time between frames, kept for the session
# One picture per type: a listing's own state (what an inspection found, too long for the berth)
# is laid over it by the card (View below), not baked in.

const DIR := "res://assets/ship_thumbs/"
const SIZE := Vector2i(720, 172)
const HIDE := ["line_layer", "light_layer", "cover_layer", "tether_layer", "heat_layer", "rope_fx", "cut_light"]
static var _tex := {}
static var _index := {}
static var _index_read := false
static var queue: Array = []
static var busy := false


static func _read_index() -> void:
	if _index_read:
		return
	_index_read = true
	var f := FileAccess.open(DIR + "index.json", FileAccess.READ)
	if f != null:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			_index = d


static func ship_md5(id: String) -> String:
	return FileAccess.get_md5(Ship.DIR + id + ".json")


# the picture of a ship type, or null while it is still to be drawn (it is queued)
static func texture(id: String) -> Texture2D:
	if _tex.has(id):
		return _tex[id]
	_read_index()
	var p := DIR + id + ".res"
	if ResourceLoader.exists(p) and (not _index.has(id) or str(_index[id]) == ship_md5(id)):
		var t = load(p)
		if t is Texture2D:
			_tex[id] = t
			return t
	if not id in queue:
		queue.append(id)
	return null


# the ship framed whole in a box of `size`, as an Image (await it; host: a node in the tree)
static func render(host: Node, id: String, size: Vector2i = SIZE) -> Image:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.msaa_2d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	host.add_child(vp)
	var w = World.new()
	vp.add_child(w)
	var data := Ship.load_data(id)
	if data.is_empty():
		vp.queue_free()
		return null
	var d := Variant.make(data, {"ship": id, "traps": [], "id": "THUMB-" + id})
	Ship.build(w, d)
	for rn in w.rooms:
		w.rooms[rn].revealed = true
	for ln in HIDE:
		var n = w.get(ln)
		if n is CanvasItem:
			n.visible = false
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for pid in w.pieces:
		for q in w.pieces[pid].poly:
			lo = lo.min(q)
			hi = hi.max(q)
	var box := Rect2(lo, hi - lo)
	box = box.grow(maxf(box.size.x, box.size.y) * 0.03)
	var sc := minf(size.x / box.size.x, size.y / box.size.y)
	vp.canvas_transform = Transform2D(0.0, Vector2(sc, sc), 0.0, Vector2(size) * 0.5 - box.get_center() * sc)
	for i in 4:
		await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img


static func to_texture(img: Image) -> Texture2D:
	if img == null:
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# while the market is open: the next missing picture drawn (one at a time)
static func pump(host: Node) -> void:
	if busy or queue.is_empty() or not host.is_inside_tree():
		return
	busy = true
	var id: String = queue.pop_front()
	var img: Image = await render(host, id)
	if img != null:
		_tex[id] = to_texture(img)
	busy = false


# ---------------------------------------------------------------- on a card

# the picture in its recessed window, the listing's own marks over it
class View extends Control:
	var ship := ""
	var dim := false
	var tags: Array = []          # short notes (what an inspection found)
	var note := ""                # one line in the corner (too long for the berth…)
	var _tex: Texture2D

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_ship(id: String) -> void:
		if id != ship:
			ship = id
			_tex = null
		queue_redraw()

	func _process(_dt: float) -> void:
		if _tex == null and ship != "":
			_tex = preload("res://scripts/ship_thumbs.gd").texture(ship)
			if _tex != null:
				queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		Charcoal.display(self, r.grow(-3.0), 1.0, 7)
		if ship == "":
			return
		if _tex == null:
			_tex = preload("res://scripts/ship_thumbs.gd").texture(ship)
		var inner := r.grow(-10.0)
		if _tex != null:
			var ts := _tex.get_size()
			var k := minf(inner.size.x / ts.x, inner.size.y / ts.y)
			var ds := ts * k
			draw_texture_rect(_tex, Rect2(inner.get_center() - ds * 0.5, ds), false, Color(1, 1, 1, 0.42 if dim else 1.0))
		else:
			# still being drawn: a quiet line where it will be
			draw_line(Vector2(inner.position.x + inner.size.x * 0.3, inner.get_center().y), Vector2(inner.end.x - inner.size.x * 0.3, inner.get_center().y), Charcoal.ink(0.25, 3), 2.0)
		var font := Fonts.get_font("Medium")
		var y := r.position.y + 22.0
		for t in tags:
			Charcoal.led(self, Vector2(r.position.x + 16.0, y - 4.0), true, 1.0, 3.5)
			draw_string(font, Vector2(r.position.x + 26.0, y), str(t), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Charcoal.ACCENT)
			y += 18.0
		if note != "":
			var nw := font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			Charcoal.led(self, Vector2(r.end.x - nw - 24.0, r.position.y + 17.0), true, 1.0, 3.5)
			draw_string(font, Vector2(r.end.x - nw - 14.0, r.position.y + 21.0), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Charcoal.ACCENT)
