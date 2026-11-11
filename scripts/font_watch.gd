extends Node
# 2026-11-11 (user: "我死了一次之后，右上角的文字怎么都变成方块了"): a panel that redraws only when its
# state changes keeps pointing at the glyph textures it drew with; when a font's glyph cache is
# rebuilt under it (the Chinese subset reimported while the game ran), its text turns to white
# blocks while everything drawn each frame stays right. This watcher lives under the root (it
# outlives scene reloads), started by the first Fonts.get_font. It listens to every font's
# `changed`, and once a second asks the text server for the texture of a probe glyph in each font
# (a Chinese one and a Latin one, at the sizes the panels use): a new texture means the cache was
# rebuilt. Either way every canvas item in the tree is drawn once afresh — once, not every frame.

const PROBE := ["的", "设", "A", "0"]
const SIZES := [12, 14]
var fonts: Array = []              # Font resources being watched
var _was := {}                     # probe key → texture RID
var _t := 0.0
var _dirty := false
var refreshed := 0                 # times the whole tree was drawn afresh (tests)
var on := true                     # tests can switch it off to see the blocks come back


func watch(f: Font) -> void:
	if f == null or fonts.has(f):
		return
	fonts.append(f)
	if not f.changed.is_connected(_on_changed):
		f.changed.connect(_on_changed)
	if f is FontFile or f is SystemFont:
		for fb in f.fallbacks:
			watch(fb)


func _on_changed() -> void:
	_dirty = true


func _probe() -> bool:
	var ts := TextServerManager.get_primary_interface()
	var moved := false
	for f in fonts:
		for ch in PROBE:
			for px in SIZES:
				(f as Font).get_char_size((ch as String).unicode_at(0), px)     # cached again first
		for rid in (f as Font).get_rids():
			for ch in PROBE:
				var cp: int = (ch as String).unicode_at(0)
				for px in SIZES:
					var gi := ts.font_get_glyph_index(rid, px, cp, 0)
					if gi == 0:
						continue
					var sz := Vector2i(px, 0)
					ts.font_render_glyph(rid, sz, gi)
					var tex := ts.font_get_glyph_texture_rid(rid, sz, gi)
					var key := "%s|%d|%d" % [rid, cp, px]
					if _was.has(key) and _was[key] != tex:
						moved = true
					_was[key] = tex
	return moved


func _process(dt: float) -> void:
	_t += dt
	if _t >= 1.0:
		_t = 0.0
		if _probe():
			_dirty = true
	if _dirty and on:
		_dirty = false
		refresh()


# every canvas item drawn once afresh (and the panels' own caches told to redraw)
func refresh() -> void:
	refreshed += 1
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CanvasItem:
			(n as CanvasItem).queue_redraw()
		stack.append_array(n.get_children())
