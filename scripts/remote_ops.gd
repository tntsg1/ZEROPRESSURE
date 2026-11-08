class_name RemoteOps
# 108 号 Q8 C / Q12 (the outside review: too much flying between districts for routine business):
# three routine jobs can be done from any terminal, or from anywhere with their key — the parts
# rack (list, unlist, sell), the grid's dispatch (who gets power first) and the processing queue
# (which ingots are melted and rolled first). Each opens once it has been done in person: the
# rack opened at the rack, the power and processing districts walked (scripts/port_walk.gd). A
# career that walked the whole old round has walked them all. Working the machines (the furnace,
# the mill, carrying goods) stays on site.

# 126 号: the company's stores (everything on one page) with F3, from the start
# 128 号 第 4 段 (2026-11-07): the processing queue is not among them — it opens at the furnace console (E)
# and from the stores' note when ingots are queued
const KINDS := ["store", "rack", "grid"]
# 128 号 第 4 段 (2026-11-07): the processing queue has no key of its own — its button on every terminal and
# the processing district's consoles open it
const KEYS := {"store": KEY_F3, "rack": KEY_F4, "grid": KEY_F5}


# 128 号: the parts rack is in the stores page now (its equipment and parts filters): F4 opens the stores
static func kinds() -> Array:
	return KINDS.filter(func(k): return k != "rack") if StoreBook.ON else KINDS


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func name_of(kind: String) -> String:
	match kind:
		"store": return w("仓库", "STORES")
		"rack": return w("零件架", "PARTS RACK")
		"grid": return w("电网调度", "GRID DISPATCH")
		"queue": return w("加工队列", "PROCESSING QUEUE")
	return kind


static func key_label(kind: String) -> String:
	return OS.get_keycode_string(KEYS[kind]) if KEYS.has(kind) else ""


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
		"store": return StoreBook.counter_seen()
		"rack": return StoreBook.counter_seen() if StoreBook.live() else Career.data.get("seen", {}).has("rack_used")
		"grid": return _walked("power")
		"queue": return _walked("process") or ProcessLine.first_done()
	return false


# why it cannot be opened from here yet ("" = it can)
static func why(kind: String) -> String:
	if ok(kind):
		return ""
	match kind:
		"store": return w("第一次先飞到船坞的仓库柜台按 E，之后在哪都能按 F3", "FLY TO THE STORES COUNTER IN THE BERTH AND PRESS E ONCE; THEN F3 WORKS ANYWHERE")
		"rack": return w("先到船坞的零件架前用一次（E）", "USE THE RACK IN THE BERTH ONCE FIRST (E)")
		"grid": return w("动力区导览走过以后才能远程调度", "WALK THE POWER DISTRICT FIRST")
		"queue": return w("加工队列在加工区炉体控制台按 E 打开，或在仓库排产后点提示上的“查看加工队列”", "THE QUEUE OPENS AT THE FURNACE CONSOLE (E) OR FROM THE STORES' NOTE")
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
		"store": game.open_store()
		"rack": game.open_store("equip") if StoreBook.live() else game.open_parts_rack(true)
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
