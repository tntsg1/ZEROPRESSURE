class_name TugFleet
# The company's own tugs (47 号): the tug station's stage 1 is TG-1 (contracts pay no tow fee,
# scripts/port.gd), stage 2 adds TG-2 (the long ships). Each has its own berth at the station,
# garage-style; a tug is away while it tows one of the hulks bought on the market (oldest tow
# first), and back on its berth when that hulk is in. With no tug free the market's contractor
# tows (the fee is the same either way: the tow quote is what it costs to fly it).

const NAMES := ["TG-1", "TG-2"]


static func count(stage: int = -1) -> int:
	var s := stage if stage >= 0 else (Port.stage("tug") if Career.usable() and not Career.data.is_empty() else 0)
	return clampi(s, 0, NAMES.size())


static func berths(stage: int = -1) -> int:
	return count(stage) + 1


# tug index → the hulk it is towing (only the tugs that are away)
static func away() -> Dictionary:
	var out := {}
	if not Career.usable() or Career.data.is_empty() or not Career.data.has("ship_market"):
		return out
	var towing: Array = []
	var named := {}
	for a in Career.data.ship_market.get("assets", []):
		if str(a.get("state", "")) == "towing":
			# 72 号: a tow remembers its tug; older ones are given out in order as before
			var n := NAMES.find(str(a.get("tug", "")))
			if a.has("tug") and str(a.tug) == "":
				continue
			if n >= 0 and n < count():
				named[n] = str(a.id)
			else:
				towing.append(str(a.id))
	towing.sort()
	for i in count():
		if named.has(i):
			out[i] = named[i]
		elif not towing.is_empty():
			out[i] = towing.pop_front()
	return out


static func home(i: int) -> bool:
	return i < count() and not away().has(i)


static func home_count() -> int:
	var n := 0
	for i in count():
		if home(i):
			n += 1
	return n


# who flies a hulk's tow: one of the company's tugs, or "" for the contractor
static func towed_by(asset_id: String) -> String:
	var a := away()
	for i in a:
		if str(a[i]) == asset_id:
			return NAMES[i]
	return ""


# a tug free for the next tow (for the market's quote line)
static func free_tug() -> String:
	var a := away()
	for i in count():
		if not a.has(i):
			return NAMES[i]
	return ""
