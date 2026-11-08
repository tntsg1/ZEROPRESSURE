extends Node
# The port, district by district (design/…/83_港区强制导览; user 2026-10-26: "必须要有详细的介绍，就像
# TS-1 的那个强制介绍一样"). Once the first ship is stripped the camera flies over Zero Pressure Port
# and stops at each district in turn; a card says what it is, what it does for you, how it stands,
# what mending it brings, and how to mend it and get there. The first time it cannot be skipped and
# each card holds at least MIN_S; replayed from the pause menu, Esc ends it. The game is in state
# "porttour" meanwhile (no flying, the camera ours).

const MIN_S := 2.0
const ORDER := ["all", "salvage", "power", "tug", "cargo", "trade", "process", "ring"]

var game
var forced := true
var i := 0
var t := 0.0
var layer: CanvasLayer
var card: Control
var font: Font
var font_b: Font


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func due() -> bool:
	if not Career.usable() or Career.data.is_empty():
		return false
	if Career.data.get("seen", {}).get("port_tour", false):
		return false
	return not Career.data.get("history", []).is_empty()


func start(g, is_forced: bool) -> void:
	game = g
	forced = is_forced
	font = Fonts.get_font("Medium")
	font_b = Fonts.get_font("SemiBold")
	layer = CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	card = Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.draw.connect(_draw_card)
	layer.add_child(card)
	game.tools.release_grab(false)
	game.state = "porttour"
	game.state_t = 0.0
	i = 0
	t = 0.0


func step(dt: float) -> void:
	t += dt
	var vs: Vector2 = game.get_viewport().get_visible_rect().size
	var pz: float = Backdrop.port_zoom(vs)
	var z: String = ORDER[i]
	if z == "all":
		game.cam_override = Backdrop.pano_centre_px()
		game.zoom_override = pz
	else:
		game.cam_override = Backdrop.port_centre_px() + PortArt.district_at("salvage" if z == "salvage" else z) * PortArt.PM * Geom.M if z != "ring" else Backdrop.port_centre_px()
		game.zoom_override = pz * (2.0 if z == "ring" else 2.6)
	card.queue_redraw()


func next() -> void:
	if t < MIN_S and forced:
		return
	i += 1
	t = 0.0
	if i >= ORDER.size():
		finish()


func key(k: int) -> void:
	if k in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_RIGHT, KEY_D]:
		next()
	elif k == KEY_ESCAPE and not forced:
		finish()


func finish() -> void:
	var seen: Dictionary = Career.data.get("seen", {})
	seen["port_tour"] = true
	Career.data.seen = seen
	Career.save()
	game.cam_override = null
	game.zoom_override = -1.0
	if game.state == "porttour":
		game.state = "play"
		game.state_t = 0.0
	game.port_tour = null
	queue_free()


# ---------------------------------------------------------------- what each card says

func _stage_line(z: String) -> String:
	var n := Port.stage(z)
	return w("第 %d 期 / 共 2 期", "PART %d OF 2") % n if n > 0 else w("还没修（0 / 2 期）", "NOT MENDED YET (0 OF 2)")


func _next_line(z: String) -> String:
	var n := Port.stage(z)
	if n >= 2:
		return w("两期都修好了。", "BOTH PARTS MENDED.")
	return Port.desc_of(z, n + 1)


func _how_line(z: String) -> String:
	var n := Port.stage(z)
	if n >= 2:
		return w("已经修完。", "DONE.")
	var why := Port.reason(z, true)
	var place := w("在终端“成长与建设”里下单，施工队修完才算数。", "Order it in the terminal under Growth & Build; the crew builds it, it works once built.")
	return place + (w(" 现在还缺：%s", " Still missing: %s") % why if why != "" else w(" 材料和钱都够，可以下单。", " You have what it takes."))


# [title, what it is, what it does for you, now, mended, how]
func rows(z: String) -> Array:
	match z:
		"all":
			return [w("零压港 · 全貌", "ZERO PRESSURE PORT"),
				w("废港，六个区围着中央转运环。你只有七号船坞，别的区都停着。", "An abandoned port: six districts round the central ring. You have Berth 07 in the salvage district; most of the rest stands idle."),
				w("拆船挣钱，挣了修港。港修得越好，拆得越快，卖得越贵，船接得越大。最后让转运环转起来。", "The whole game is one loop: strip ships for money → mend the port with money and materials → mended districts strip faster, sell dearer, take bigger ships → at last the central ring turns again."),
				w("第一艘拆完了。挨个看看各区干什么。", "You have stripped your first ship. Now each district, one by one."),
				"", ""]
		"salvage":
			return [Port.name_of(z) + w(" · 你的船坞", " · YOUR BERTH"),
				w("拆船的地方。拖回来的船推进七号船坞，你在这里断电、泄压、切割、抓取。", "Where ships are taken apart. A hulk is pushed into Berth 07; here you isolate, vent, cut and grab."),
				w("钱基本从这儿来。整件设备送设备口，太宽的送重载架，碎料进熔炉炼钢锭。", "Nearly all your money starts here: whole machines through the equipment mouth sell as machines, wide ones go to the heavy rack, scrap goes to the furnace as ingots (the port and the works need them)."),
				_stage_line(z) + w("。船坞里的照明、熔炉主火、碎屑网等设施坏着，要一项项修。", ". The berth's lights, the furnace's main fire, the debris net and more are broken: mend them one by one."),
				_next_line(z), _how_line(z)]
		"power":
			return [Port.name_of(z),
				w("全港的电从这儿出。按顺序分给各区；电力不足时，排后面的功率先降。", "The whole port's power. The grid shares it out district by district; when it runs short the last in line get less."),
				w("激光、传送带、熔炉都吃电。屏幕上出“电力不足—功率 xx%”，就是这儿的事。", "Cutting, the conveyors and the furnace all draw power. The \"short of power\" line is this district talking: more power, faster cutting and melting."),
				_stage_line(z), _next_line(z), _how_line(z)]
		"tug":
			return [Port.name_of(z),
				w("拖船从这里出发去小行星带，把你在星图上找到的废船拖回来；拖回来的船先停在这里的泊位上。", "The tugs leave from here for the belt and bring home the hulks you find on the star map; they wait at its berths."),
				w("几个泊位就能停几艘。站越好拖得越长：44 米、88 米、不限。自家拖船，运费减半。", "Its berths say how many hulks can wait; the better it is, the longer the ships it can tow (44 m → 88 m → any). Your own tugs halve the tow."),
				_stage_line(z) + w(" · ", " · ") + TugYard.status(), _next_line(z), _how_line(z)]
		"cargo":
			return [Port.name_of(z),
				w("港里的仓库：一排排货架，叉车搬货。钢锭、零件、你卖出的货都从这里进出。", "The port's warehouse: racks and forklifts. Ingots, parts and what you sell all pass through here."),
				w("卖掉的货从这儿发走，熔炉也从这儿取料。", "Sold goods leave from here by forklift; the furnace draws its feed from here. The smoother it runs, the sooner you are paid."),
				_stage_line(z), _next_line(z), _how_line(z)]
		"trade":
			return [Port.name_of(z),
				w("港里做买卖的地方：交易行、上门的客人、公司的长期合同。", "Where the port does business: the exchange (F8 in the terminal), visiting buyers, company contracts."),
				w("在这儿卖钢坯、材料、零件，买修港缺的零件。修好了，设备卖得更贵，还能买二手船。", "Billets, materials and parts are sold here; parts you lack for repairs are bought here. Mended, it pays more for whole machines and opens the hulk market."),
				_stage_line(z), _next_line(z), _how_line(z)]
		"process":
			return [Port.name_of(z),
				w("再加工的地方。钢锭炼钢坯，钢坯轧钢板。混料在这儿分开，抽回的气在这儿做液氧。", "Where what you strip is worked again: the furnace desk makes billets, the mill rolls plate and sections, sorting and assay desks part mixed metal; the gas line separates recovered gas into liquid oxygen."),
				w("加工过的值钱。钢坯卖给公司，钢板型材能修港。", "Worked goods pay far better than raw: billets sell to the firms, plate and sections also mend the port."),
				_stage_line(z), _next_line(z), _how_line(z)]
		"ring":
			return [w("中央转运环", "THE CENTRAL RING"),
				w("港的中心：一圈连着所有区的环，走廊和接驳车从这里通到各区。", "The heart of the port: a ring joining every district; the corridors and the shuttle run from here."),
				w("最后要让它转起来，那时才接得了远航者那样的大船。先修动力区和拖船站。", "Getting it turning again is the game's last goal — only then can giants like the Ark come in. The power district and the tug station come first."),
				_stage_line(z), _next_line(z), _how_line(z)]
	return [z, "", "", "", "", ""]


func _draw_card() -> void:
	var s := card.size
	var z: String = ORDER[i]
	var r := rows(z)
	var cw := 760.0
	var box := Rect2(s.x - cw - 32.0, 96.0, cw, 560.0)
	card.draw_rect(box, Color(0.03, 0.034, 0.042, 0.985))
	card.draw_rect(box, Pal.ink(0.18), false, 1.0)
	card.draw_rect(Rect2(box.position + Vector2(0, 14), Vector2(5, box.size.y - 28)), UiSkin.ACCENT)
	var x := box.position.x + 30.0
	var y := box.position.y + 40.0
	card.draw_string(font, Vector2(x, y), w("港区导览 · %d / %d", "PORT TOUR · %d OF %d") % [i + 1, ORDER.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiSkin.ACCENT)
	y += 44.0
	card.draw_string(font_b, Vector2(x, y), str(r[0]), HORIZONTAL_ALIGNMENT_LEFT, cw - 60.0, 30, Pal.ink(0.98))
	y += 22.0
	var heads := [w("是什么", "WHAT IT IS"), w("对你有什么用", "WHAT IT DOES FOR YOU"), w("现在", "NOW"), w("修好以后", "MENDED"), w("怎么修 · 怎么去", "HOW TO MEND IT")]
	for k in 5:
		var text := str(r[k + 1])
		if text == "":
			continue
		y += 30.0
		card.draw_string(font_b, Vector2(x, y), heads[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.55))
		y += 8.0
		var lines := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, cw - 60.0, 18).y
		card.draw_multiline_string(font, Vector2(x, y + 20.0), text, HORIZONTAL_ALIGNMENT_LEFT, cw - 60.0, 18, -1, Pal.ink(0.9))
		y += lines + 4.0
	# the way on: held for MIN_S the first time
	var ready := not forced or t >= MIN_S
	var nav := w("空格 / 点一下：下一个", "SPACE / CLICK: NEXT") if i < ORDER.size() - 1 else w("看完了。下一步看左上角。", "SPACE / CLICK: DONE — THE MAIN-LINE CARD TAKES IT FROM HERE")
	if not ready:
		nav = w("请先看一下……", "READ IT FIRST…")
	if not forced:
		nav += w(" · Esc 结束导览", " · ESC ENDS IT")
	card.draw_string(font, Vector2(x, box.end.y - 24.0), nav, HORIZONTAL_ALIGNMENT_LEFT, cw - 60.0, 17, UiSkin.ACCENT if ready else Pal.ink(0.45))
	if not ready:
		card.draw_rect(Rect2(x, box.end.y - 14.0, (cw - 60.0) * clampf(t / MIN_S, 0.0, 1.0), 2.0), UiSkin.ACCENT)
