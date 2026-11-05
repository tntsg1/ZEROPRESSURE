extends Node2D
# 128 号 第 3 段: keeps the port's districts looking as mended as they are (scripts/district_revive.gd).
# A district not mended carries its broken look (made one at a time, a few frames apart, so entering
# the berth never stalls on the baking); a stage the crew has just finished (Career.data.
# revive_pending, written by Works) lights up where it stands, a stretch at a time, while a small
# live picture at the screen's edge shows it (scripts/revive_pip.gd) — unless the player is in that
# district and sees it anyway. The first mending of a district plays whole; a later one (its second
# stage) can be skipped with any key. At the end the main line's voice says what opened (HUD).
# A loaded game is simply mended: nothing replays. Made by scripts/district_interiors.gd, put under
# the game itself (the interiors are hidden while the player is not in a district).

const Revive = preload("res://scripts/district_revive.gd")
const Pip = preload("res://scripts/revive_pip.gd")
const PortStructure = preload("res://scripts/port_structure.gd")
const SHOWN := ["trade", "process", "cargo", "power", "tug"]

static var ON := true
var game
var interiors
var nodes := {}                  # zone -> its DistrictRevive
var show_zone := ""              # the district lighting up now
var pip
var _t := 0.0


func _ready() -> void:
	z_index = 6
	z_as_relative = false


func _live() -> bool:
	return ON and game != null and is_instance_valid(game) and game.career() and Career.usable() and not Career.data.is_empty() and game.in_berth()


func _process(dt: float) -> void:
	if not _live():
		return
	_t += dt
	if show_zone == "":
		var rp: Array = Career.data.get("revive_pending", [])
		if not rp.is_empty():
			var e: Dictionary = rp.pop_front()
			Career.data.revive_pending = rp
			Career.save()
			_start(str(e.zone), int(e.stage))
			return
	if _t < 0.15:
		return
	_t = 0.0
	# one broken look made a tick, and the mended ones let go
	for z in SHOWN:
		var n = nodes.get(z)
		if z == show_zone:
			continue
		if Port.stage(z) < 1:
			if n == null:
				_make(z)
				return
		elif n != null:
			n.queue_free()
			nodes.erase(z)


func _make(z: String):
	var n = Revive.new()
	n.zone = z
	n.game = game
	add_child(n)
	nodes[z] = n
	return n


func _start(z: String, stage: int) -> void:
	if not z in SHOWN:
		_ended(z, stage)
		return
	var n = nodes.get(z)
	if n == null:
		n = _make(z)
	n.second = stage >= 2
	n.start()
	show_zone = z
	var seen: Dictionary = Career.data.get("seen", {})
	var first := not seen.has("revive_" + z)
	n.on_end = func(): _ended(z, stage)
	if _inside() != z:
		pip = Pip.new()
		pip.zone = z
		pip.revive = n
		pip.skippable = not first
		game.add_child(pip)


func _inside() -> String:
	return str(interiors._zone()) if interiors != null and is_instance_valid(interiors) else ""


func _ended(z: String, stage: int) -> void:
	StoreBook.mark("revive_" + z)
	if pip != null and is_instance_valid(pip):
		pip.queue_free()
	pip = null
	show_zone = ""
	var n = nodes.get(z)
	if n != null and Port.stage(z) >= 1:
		n.queue_free()
		nodes.erase(z)
	if game != null and game.get("hud") != null and game.hud.has_method("voice_done"):
		game.hud.voice_done(z, stage)


# a second stage, or a district seen lit before: any key skips the show
func _unhandled_input(event: InputEvent) -> void:
	if show_zone == "" or pip == null or not is_instance_valid(pip) or not pip.skippable:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var n = nodes.get(show_zone)
		if n != null:
			n.skip()


# tests
func showing() -> String:
	return show_zone
