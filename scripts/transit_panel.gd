extends Control
# Where to: the destination list for the rail shuttle (at a station) or the work boat's
# autopilot (docked at a pad). Same skin as the district consoles. Only places already
# discovered or visited are listed.
var game
var mode := "tram"             # "tram" | "boat"
var here := ""
var on_close: Callable
var message: Label


func words(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func label(value: String, size_px: int = 18) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size", size_px)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


func button(value: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = value
	node.custom_minimum_size.y = 42
	node.pressed.connect(callback)
	return node


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var accent := Pal.tint(Pal.FLUID, 1.0, 1.2) if mode == "tram" else Pal.tint(Pal.AIR, 1.0, 1.2)
	var column := OpsSkin.pane(self, accent, 420.0)
	if mode == "tram":
		column.add_child(OpsSkin.Plate.new("T-1", Txt.t("tram_title"), Txt.t("tram_sub"), accent))
		column.add_child(OpsSkin.as_screen(label(Txt.t("tram_here") % Port.name_of(here), 15)))
		column.add_child(OpsSkin.Section.new(words("站", "STOPS")))
		for s in Tram.stations():
			if s == here:
				continue
			var name: String = Port.name_of(s)
			var seen: bool = s in Tram.found()
			column.add_child(BenchFx.noted(button(name + ("" if seen else "  · " + Txt.t("tram_unknown")), func(): _go(s)), words("坐接驳车去这一站", "Ride the shuttle to this stop")))
	else:
		column.add_child(OpsSkin.Plate.new("WB-1", Txt.t("boat_title"), Txt.t("boat_sub"), accent))
		column.add_child(OpsSkin.Section.new(words("泊位", "PADS")))
		var seen: Array = game.boat.visited()
		for id in WorkBoat.PADS:
			if id == here:
				continue
			var known: bool = id in seen
			var b := button(WorkBoat.pad_name(id) if known else WorkBoat.pad_name(id) + "  · " + Txt.t("tram_unknown"), func(): _go(id))
			BenchFx.note(b, words("坐工作艇去这里", "Take the work boat here"))
			b.disabled = not known
			column.add_child(b)
	message = label("", 15)
	column.add_child(message)
	column.add_child(button(words("关闭 [Esc]", "CLOSE [Esc]"), close))


func _go(to: String) -> void:
	var ok := false
	if mode == "tram":
		ok = game.tram.call_to(here, to)
	else:
		ok = game.boat.plan(to)
	if ok:
		close()
	else:
		message.text = words("现在去不了那里。", "Cannot go there now.")


func close() -> void:
	if on_close.is_valid():
		on_close.call()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
