class_name Onboard
# The new player's first half hour, as one guide (design/…/80_新手第一个小时_逐步剧本, user
# 2026-10-26: Q1–Q4 as recommended). The steps on site are the prologue (scripts/prologue.gd)
# and the first ship (scripts/first_ship.gd), each opening only its tools; back at the
# terminal, this says which stage the career is in — worked out from its real state, never
# stored as a counter — and what the stage leaves open:
#   prologue · ship1 · find (only 找船 open: sweep, analyse, send the tug) · lights (find and
#   装备 open: mend the berth's lights while the tug is out) · then the main line takes over.
# Only careers begun after this (Career.data.onboard) are walked through it; an older save gets
# the same "next step" lines from the main line, nothing locked (Q5 A).

const TERMINAL_OPEN := {"find": [0], "lights": [0, 1]}


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func active() -> bool:
	return Career.usable() and not Career.data.is_empty() and str(Career.data.get("onboard", "done")) != "done"


static func _did_job(id: String) -> bool:
	for h in Career.data.get("history", []):
		if str(h.get("id", "")) == id:
			return true
	return false


static func _lights_started() -> bool:
	var d := Career.data
	if d.get("upgrades", {}).has("lights"):
		return true
	var wk: Dictionary = d.get("works", {})
	return str(wk.get("id", "")) == "lights"


# the stage the career is in ("" once the guide is over)
static func stage() -> String:
	if not active():
		return ""
	var d := Career.data
	if not d.get("prologue_done", false):
		return "prologue"
	if not _did_job("TUG-001"):
		return "ship1"
	if not d.get("seen", {}).get("first_tow", false):
		return "find"
	# never a dead end: with the second hulk stripped the lights wait for the main line
	if not _lights_started() and d.get("history", []).size() < 2:
		return "lights"
	return ""


# the guide is over: said once, kept in the save
static func finish_if_done() -> void:
	if active() and stage() == "":
		Career.data.onboard = "done"
		Career.save()


# the terminal's app pages this stage keeps shut, and why
static func locks(page: int) -> bool:
	var st := stage()
	if not TERMINAL_OPEN.has(st):
		return false
	return not (TERMINAL_OPEN[st] as Array).has(page)


static func lock_reason() -> String:
	match stage():
		"find":
			return w("先找第二艘船：点“找船”", "FIND THE SECOND HULK FIRST: OPEN FIND SHIPS")
		"lights":
			return w("先修船坞的照明：点“装备”里的“照明与配电”", "MEND THE BERTH'S LIGHTS FIRST: EQUIPMENT › LIGHTING & POWER")
	return ""


# the next step for the main-line card and the terminal's home: {text, go}
static func step() -> Dictionary:
	match stage():
		"find":
			return {"text": w("找第二艘船：终端 → 找船 → 星图，扫最近的扇区（第一趟拖运免费）。", "Find the second hulk: terminal › Find ships › star map, sweep the nearest sector (first tow free)."), "go": "scan"}
		"lights":
			var info := Guide.repair_info("lights")
			var why := w("船坞的照明坏了：暗处看不清读数，切割也慢。", "The berth's lights are out: readings are hard to see in the dark and cutting is slow. ")
			if info.get("ready", false):
				return {"text": why + w("趁拖船在路上修好它：终端 → 船坞 → 照明与配电。", "While the tug is out, mend them: terminal › Berth › Lighting & power."), "go": "guide:repair:lights"}
			return {"text": why + w("修它还需要：%s。", "To mend them you still need: %s.") % str(info.get("lack", "")), "go": "guide:repair:lights"}
	return {}
