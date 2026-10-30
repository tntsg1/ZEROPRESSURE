class_name RemoteOps
# 108 号 Q8 C / Q12 (the outside review: too much flying between districts for routine business):
# three routine jobs can be done from any terminal, or from anywhere with their key — the parts
# rack (list, unlist, sell), the grid's dispatch (who gets power first) and the processing queue
# (which ingots are melted and rolled first). Each opens once it has been done in person: the
# rack opened at the rack, the power and processing districts walked (scripts/port_walk.gd). A
# career that walked the whole old round has walked them all. Working the machines (the furnace,
# the mill, carrying goods) stays on site.

const KINDS := ["rack", "grid", "queue"]
const KEYS := {"rack": KEY_F4, "grid": KEY_F5, "queue": KEY_F6}


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func name_of(kind: String) -> String:
	match kind:
		"rack": return w("零件架", "PARTS RACK")
		"grid": return w("电网调度", "GRID DISPATCH")
		"queue": return w("加工排队", "PROCESSING QUEUE")
	return kind


static func key_label(kind: String) -> String:
	return OS.get_keycode_string(KEYS.get(kind, KEY_NONE))


static func _walked(zone: String) -> bool:
	var seen: Dictionary = Career.data.get("seen", {})
	if seen.has("walk_" + zone) or seen.has("port_walk_all"):
		return true
	# the old 21-step round (before 108 号) took the player through every district
	return seen.has("port_walk") and int(Career.data.get("walk_v", 1)) < 2


static func ok(kind: String) -> bool:
	if Career.data.is_empty() or not Career.usable():
		return false
	match kind:
		"rack": return Career.data.get("seen", {}).has("rack_used")
		"grid": return _walked("power")
		"queue": return _walked("process")
	return false


# why it cannot be opened from here yet ("" = it can)
static func why(kind: String) -> String:
	if ok(kind):
		return ""
	match kind:
		"rack": return w("先到船坞的零件架前用一次（E）", "USE THE RACK IN THE BERTH ONCE FIRST (E)")
		"grid": return w("动力区导览走过以后才能远程调度", "WALK THE POWER DISTRICT FIRST")
		"queue": return w("加工区导览走过以后才能远程排队", "WALK THE PROCESSING DISTRICT FIRST")
	return ""


# open it in the running game; false (and the reason said) when it cannot be
static func open(game, kind: String) -> bool:
	if game == null or not is_instance_valid(game):
		return false
	var r := why(kind)
	if r != "":
		game.say_text(r, game.drone.global_position + Vector2(0, -44) if game.drone != null else Vector2.ZERO)
		game.sfx.play("deny")
		return false
	match kind:
		"rack": game.open_parts_rack(true)
		"grid": game.open_power_screen()
		"queue": game.open_queue_panel()
	return true


# a key pressed in the field or at a terminal: the kind it opens, or ""
static func kind_of_key(ev: InputEvent) -> String:
	if not (ev is InputEventKey and ev.pressed and not ev.echo) or Txt.dev:
		return ""
	for k in KEYS:
		if ev.physical_keycode == KEYS[k] or ev.keycode == KEYS[k]:
			return k
	return ""
