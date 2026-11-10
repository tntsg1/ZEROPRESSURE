extends RefCounted
# 133 号 (user 2026-11-10: "显示目前的这个二手船是有人在卖，让人看得出来这是在卖东西"): what makes a
# hulk-market listing read as a ship someone is selling. Nothing here is saved and nothing here
# touches the price, the traps or the buy: it is worked out from the listing each time.
#   real: how long it has been up and how long it has left (listed / expires), the ask against
#     the broker's value, a seller's title allowance, a held quote, a refused offer, where it lies
#     and the tow fee; what the seller says against the rating (only what the buyer can see)
#   steady by the listing's id (the same every time it is opened): who sells it (kind, name, how
#     long on the market, how many sold) and how many look at it (grows with the listing's age)
# A seller's standing says nothing about this ship's hidden faults (sellers talk ships up as a
# rule, whoever they are); the one warning is from what is on the page.

const KINDS := ["private", "company", "auction", "insurer", "court"]
const KIND_WEIGHT := [0.3, 0.3, 0.15, 0.15, 0.1]

const PEOPLE := [["周启明", "Zhou Qiming"], ["白岩", "Bai Yan"], ["索菲娅·林", "Sofia Lin"], ["马克·奥杜", "Mark Odu"],
	["韩一舟", "Han Yizhou"], ["伊洛娜·科瓦奇", "Ilona Kovac"], ["陶岸", "Tao An"], ["拉吉·梅农", "Raj Menon"]]
const COMPANIES := [["环带货运", "Beltline Freight"], ["灰鹭航运", "Grey Heron Shipping"], ["北冕矿业", "Corona Mining"],
	["铁砧拖运", "Anvil Towage"], ["远星租赁", "Farstar Leasing"], ["长庚物流", "Evenstar Logistics"]]
const AUCTIONS := [["谷神拍卖行", "Ceres Auction House"], ["环带公开拍卖", "Belt Open Auctions"], ["落锤拍卖", "Hammerfall Auctions"]]
const INSURERS := [["星盾保险 · 理赔处置部", "Starshield Insurance · Claims"], ["环带船东互保会", "Belt Shipowners' Mutual"], ["穹顶再保险", "Dome Re"]]
const COURTS := [["环带海事法院 · 执行处", "Belt Admiralty Court · Enforcement"]]


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func _rng(l: Dictionary, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(str(l.get("id", "")) + "#" + str(salt))
	return r


static func _pick(rng: RandomNumberGenerator, pool: Array) -> Array:
	return pool[rng.randi_range(0, pool.size() - 1)]


# {kind, kind_name, name, line, stats}: who sells it
static func seller(l: Dictionary) -> Dictionary:
	if l.has("showcase"):
		return {"kind": "port", "kind_name": kind_name("port"), "name": w("零压港 · 新拆法推广处", "Zero Pressure Port · Methods Desk"),
			"line": w("这艘是港口提供的拆解示范船，已经按照新的拆解流程做好了准备。船体和设备的实际情况都有记录，可以查看相关资料。", "This is a demonstration hull the port provides for dismantling, already prepared for the new method. The hull and equipment are fully documented, and the records are open to view."),
			"stats": w("港口管理方挂牌出售", "PORT AUTHORITY LISTING")}
	var rng := _rng(l, 1)
	var x := rng.randf()
	var kind := "private"
	var acc := 0.0
	for i in KINDS.size():
		acc += float(KIND_WEIGHT[i])
		if x < acc:
			kind = KINDS[i]
			break
	var nm: Array
	var stats := ""
	match kind:
		"private":
			nm = _pick(rng, PEOPLE)
			stats = _record(nm, 1, 6, 1, 9)
		"company":
			nm = _pick(rng, COMPANIES)
			stats = _record(nm, 18, 240, 4, 30)
		"auction":
			nm = _pick(rng, AUCTIONS)
			stats = _record(nm, 300, 2400, 10, 60)
		"insurer":
			nm = _pick(rng, INSURERS)
			stats = _record(nm, 40, 420, 8, 45)
		_:
			nm = _pick(rng, COURTS)
			stats = w("司法处置 · 不提供担保", "JUDICIAL SALE · NO WARRANTY")
	var lines: Dictionary = {
		"private": [w("这艘船我自己开了十几年，现在不干这行了，就想着把船卖掉。手续都齐全，有意向的话可以联系。", "I flew this ship myself for over ten years. I've left the trade now and just want to sell her. The paperwork is all in order; get in touch if you're interested."),
			w("跑完最后一趟就一直停在港口，到现在也没再用过，每个月还得交泊位费。想早点处理掉，价格可以商量。", "She has sat in port since her last run and hasn't been used since, and the berth fees come every month. I'd like to sell soon; the price is open to discussion.")],
		"company": [w("公司最近在更换船队，这艘船已经列入资产出售名单。相关账目都能查到，也可以正常开具发票。", "The company is renewing its fleet, and this ship is on the asset sale list. The accounts can all be checked, and an invoice can be issued as usual."),
			w("这艘船的运营合同已经到期，公司决定不再继续使用。之前的维护记录都有保存，目前由公司统一挂牌出售。", "This ship's operating contract has ended and the company won't keep using her. Past maintenance records are kept; she is listed for sale by the company.")],
		"auction": [w("受船东委托公开拍卖，船舶按照目前的实际状况出售。买家需要自行检查船况，拍卖行不提供额外担保。", "Auctioned publicly on the owner's behalf; the ship is sold in her present condition. Buyers must check her condition themselves; the auction house gives no further warranty."),
			w("委托方希望尽快完成出售，这次拍卖按照船舶现状成交。有意向的买家请提前安排看船，拍卖结束后就不再接受报价了。", "The consignor wants a quick sale, and this auction sells the ship as is. Interested buyers should arrange a viewing early; no offers are taken once the auction ends.")],
		"insurer": [w("这艘船已经按照全损完成理赔，目前出售的是剩余船体和设备。船舶按照现状处理，具体情况请买家自行检查确认。", "This ship has been settled as a total loss; what is for sale is the remaining hull and equipment. She is sold as is; buyers should check and confirm the details themselves."),
			w("相关保险理赔已经结案，现在准备出售剩余船体和设备。船上的实际情况以现场检查结果为准。", "The insurance claim is closed, and the remaining hull and equipment are now for sale. The inspection on site decides what is actually on board.")],
		"court": [w("这艘船属于法院强制执行的拍卖资产，按照现状出售。原船东没有配合办理交接，部分船舶资料缺失，买家需要提前了解情况。", "This ship is an asset auctioned under a court enforcement order and is sold as is. The former owner did not cooperate with the handover and some of the ship's records are missing; buyers should look into this beforehand.")],
	}
	return {"kind": kind, "kind_name": kind_name(kind), "name": nm[0] if Txt.zh else nm[1], "line": _line(rng, lines[kind]), "stats": stats}


# a seller's record goes with the seller: the same name has the same record on every listing
static func _record(nm: Array, sold0: int, sold1: int, yr0: int, yr1: int) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = hash(["seller", str(nm[1])])
	return w("已成交 %d 单 · 入驻 %d 年", "%d SOLD · %d YEARS ACTIVE") % [r.randi_range(sold0, sold1), r.randi_range(yr0, yr1)]


static func _line(rng: RandomNumberGenerator, pool: Array) -> String:
	return str(pool[rng.randi_range(0, pool.size() - 1)])


static func kind_name(kind: String) -> String:
	match kind:
		"private": return w("个人船东", "PRIVATE OWNER")
		"company": return w("航运公司", "SHIPPING COMPANY")
		"auction": return w("拍卖行", "AUCTION HOUSE")
		"insurer": return w("保险公司处置", "INSURER SALE")
		"court": return w("法院拍卖", "COURT AUCTION")
	return w("港口管理方", "PORT AUTHORITY")


# play seconds since it went up and until it comes down
static func age_s(l: Dictionary) -> float:
	return maxf(0.0, Shipping.day() - float(l.get("listed", Shipping.day()))) / Orbits.DAYS_PER_S


static func left_s(l: Dictionary) -> float:
	return maxf(0.0, float(l.get("expires", Shipping.day())) - Shipping.day()) / Orbits.DAYS_PER_S


# the last quarter of its time: the seller wants it gone (real: from listed / expires)
static func rush(l: Dictionary) -> bool:
	var life := float(l.get("expires", 0.0)) - float(l.get("listed", 0.0))
	return life > 0.0 and not l.has("hold") and left_s(l) * Orbits.DAYS_PER_S < life * 0.25


static func mins(s: float) -> String:
	if s < 60.0:
		return w("不到 1 分钟", "LESS THAN 1 MIN")
	return w("%d 分钟", "%d MIN") % int(s / 60.0)


static func listed_text(l: Dictionary) -> String:
	return w("已上架 %s", "LISTED FOR %s") % mins(age_s(l))


static func rush_text(l: Dictionary) -> String:
	return w("急售 · 距离下架还有 %s", "QUICK SALE · %s LEFT") % mins(left_s(l))


static func left_text(l: Dictionary) -> String:
	if l.has("hold"):
		return w("你已付定金保留", "HELD BY YOU")
	return w("距离下架还有 %s", "%s UNTIL REMOVAL") % mins(left_s(l))


# [looking, asking]: steady per listing, growing as the listing ages
static func interest(l: Dictionary) -> Array:
	var rng := _rng(l, 2)
	var L := float(Market.type_of(str(l.offer.ship)).get("length", 30.0))
	var base := rng.randf_range(6.0, 26.0) * (1.0 + clampf(1.0 - float(l.price) / maxf(1.0, float(l.offer.value)), 0.0, 0.7)) * (1.2 if L <= 60.0 else 0.8)
	var life := maxf(1.0, float(l.get("expires", 1.0)) - float(l.get("listed", 0.0)))
	var grown := clampf((Shipping.day() - float(l.get("listed", 0.0))) / life, 0.0, 1.0)
	var look := maxi(1, int(round(base * (0.35 + 0.65 * grown))))
	var ask := int(floor(look * rng.randf_range(0.05, 0.22)))
	return [look, ask]


# the ask under the broker's value, as a share (real)
static func under_value(l: Dictionary) -> float:
	return clampf(1.0 - float(l.price) / maxf(1.0, float(l.offer.value)), 0.0, 0.99)


# what the seller says of a side, in two words: said clean, said there is a fault, glossed over,
# not said (only what the buyer reads; a lie reads as clean)
static func said(st: Dictionary) -> String:
	match str(st.how):
		"clean", "false": return "clean"
		"admitted": return "admitted"
		"downplayed": return "vague"
	return "silent"


static func said_name(k: String) -> String:
	match k:
		"clean": return w("声称没有问题", "CLAIMS NO ISSUES")
		"admitted": return w("已说明存在的问题", "DECLARED ISSUES")
		"vague": return w("没有说清楚", "VAGUE DESCRIPTION")
	return w("没有提到", "NOT MENTIONED")


static func side_name(cat: String) -> String:
	return w("结构", "STRUCTURE") if cat == "structure" else w("系统", "SYSTEMS")


# the warning from the page itself: a side said sound that the rating covers, and a low rating
static func clash(l: Dictionary) -> bool:
	var ag: Dictionary = ShipMarket.AGENCIES.get(str(l.rating.get("agency", "")), {})
	if ag.is_empty() or int(l.rating.score) > 6:
		return false
	for st in l.get("statements", []):
		if said(st) == "clean" and str(st.cat) in ag.covers:
			return true
	return false


# ---------------------------------------------------------------- the seller's headline (133 号)
# user 2026-11-10 ("卖家的声称很好我也在游戏里没看到啊"): every listing leads with the seller's own
# headline, the way a shop titles its goods. It comes from who sells (an auction house, an insurer or
# a court say "as is"; owners and companies sell), how the seller speaks of each side (a plain lie
# shouts, a side played down or left out is talked around, a declared fault is said) and the ship
# itself (a sound ship is talked up as well, so a loud headline is a reason to check, not proof).
# The louder it is, the more a check of the side it boasts of finds against it.

const H_STRUCT := [["九成新！结构完好无事故，急售", "Like new! Sound hull, never in an accident. Must go."],
	["全船无暗伤，假一赔十", "Not a hidden crack on her. Ten back if I'm wrong."]]
const H_SYS := [["原厂保养，开过就知道", "Factory-serviced. Fly her and you'll know."],
	["系统全好，通电即用，懂的来", "Every system good, power up and go."]]
const H_ANY := [["零隐患！懂行的来，错过不再有", "Zero faults! For buyers who know. Won't come again."],
	["船况一流，拆就是赚", "Top condition. Strip her and you profit."]]
const H_WARM := [["船况良好，小毛病不影响拆", "Good shape; the small stuff won't slow a strip."],
	["正常停机，手续齐全，诚心卖", "Shut down by the book, papers in order. Honest sale."],
	["老船好料，钢材足", "Old ship, good steel, plenty of it."],
	["停得规矩，拖回去就能拆", "Laid up properly. Tow her in and cut."]]
const H_PROUD := [["结构完好 · 欢迎验船", "Sound hull. Inspection welcome."],
	["船况如实，检验随便查", "As described. Check whatever you like."]]
const H_HONEST := [["如实申报 %d 项问题，价格已经让了", "%d faults declared; already priced in."],
	["有问题写在前面，欢迎检验", "Faults stated up front. Inspect freely."]]
const H_AUCTION := [["捡漏好机会！按现状成交", "A real find! Sold as is."],
	["委托急售 · 按现状 · 低价走", "Consignor needs cash · As is · Going cheap."]]
const H_INSURER := [["理赔残值 · 按现状处置", "Claim salvage · Sold as is."],
	["残值处置 · 以检验为准", "Salvage sale · Go by the inspections."]]
const H_COURT := [["法院拍卖 · 不作担保 · 资料不全", "Court sale · No warranty · Papers incomplete."]]
const H_PORT := [["示范船 · 按新拆法备好 · 船况如实", "Demo hull · Laid out for the new method · As declared."]]


# how hard the seller talks it up: a lie 3, a side played down or left out 1, a declared fault -2
static func boast(l: Dictionary) -> int:
	if l.has("showcase"):
		return 0
	var b := 0
	for st in l.get("statements", []):
		match str(st.how):
			"false": b += 3
			"downplayed", "omitted": b += 1
			"admitted": b -= 2
	return b


# {text, tier: hype | warm | proud | honest | asis | port, side: the side it boasts of or ""}
static func headline(l: Dictionary) -> Dictionary:
	var rng := _rng(l, 3)
	var kind := str(seller(l).kind)
	var pool: Array = H_WARM
	var tier := "warm"
	var side := ""
	var b := boast(l)
	var lied := ""
	for st in l.get("statements", []):
		if str(st.how) == "false":
			lied = str(st.cat)
	if kind == "port":
		pool = H_PORT
		tier = "port"
	elif kind == "court":
		pool = H_COURT
		tier = "asis"
	elif kind == "insurer":
		pool = H_INSURER
		tier = "asis"
	elif kind == "auction":
		pool = H_AUCTION
		tier = "hype" if b >= 2 else "asis"
	elif b < 0:
		pool = H_HONEST
		tier = "honest"
	elif b >= 3:
		tier = "hype"
		side = lied
		pool = H_STRUCT if lied == "structure" else (H_SYS if lied == "systems" else H_ANY)
	elif b >= 1:
		if rng.randf() < 0.3:
			pool = H_ANY
			tier = "hype"
	else:
		# nothing to hide: proud, and now and then just as loud as a liar
		var r := rng.randf()
		pool = H_PROUD if r < 0.55 else (H_ANY if r < 0.8 else H_STRUCT)
		tier = "proud" if r < 0.55 else "hype"
		side = "structure" if pool == H_STRUCT else ""
	var pick: Array = pool[rng.randi_range(0, pool.size() - 1)]
	var text := str(pick[0] if Txt.zh else pick[1])
	if text.contains("%d"):
		var n := 0
		for st in l.get("statements", []):
			if str(st.how) == "admitted":
				n += (st.traps as Array).size()
		text = text % maxi(1, n)
	return {"text": text, "tier": tier, "side": side}


# what the checks bought so far say against the headline: {text, hot} or {} when nothing checked
static func verdict(l: Dictionary) -> Dictionary:
	var looked := 0
	var found := 0
	for st in l.get("statements", []):
		var c := str(st.cat)
		if not (l.get("inspected", {}) as Dictionary).has(c):
			continue
		looked += 1
		if str(st.how) != "admitted":
			found += (l.inspected[c] as Array).size()
	if looked == 0:
		return {}
	var h := headline(l)
	if found > 0:
		return {"hot": true, "text": w("卖家广告里说“%s”，但检验发现了 %d 项卖家没有说明的问题。", "THE AD SAYS \"%s\", BUT THE INSPECTIONS FOUND %d ISSUE(S) THE SELLER DIDN'T DECLARE.") % [str(h.text), found]}
	return {"hot": false, "text": w("已检验的项目里，没有发现卖家隐瞒的问题。", "THE INSPECTIONS DONE FOUND NOTHING THE SELLER HID.")}


# one line for the card: "自述：结构 说没问题 · 系统 含糊带过"
static func claim_line(l: Dictionary) -> String:
	var parts: Array = []
	for st in l.get("statements", []):
		parts.append((w("%s%s", "%s %s")) % [side_name(str(st.cat)), said_name(said(st))])
	return w("自述：", "SELLER: ") + " · ".join(parts)
