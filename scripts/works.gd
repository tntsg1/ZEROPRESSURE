class_name Works
# Repairs and port works are built, not bought (design/…/65_主线重整第5批, 60 号 Q4; player
# 2026-10-25: "a click and it's done — no; get the blueprint and the materials, or pay a crew whose
# robots do it, and only then can I use it"). An order takes its materials and money at once (the
# two ways stay: own parts and ingots for half the money, or a crew for the whole of it), then the
# crew works on site for a while; what it builds is the berth's only when the job is done. One job at
# a time. Time runs while the game is played (the berth or a ship), not while it is closed.
# Career.data.works = {id, kind ("repair" | "port"), zone, stage, with_parts, total, left}

# tests and the developer tools may build at once
static var BUILD_TIME := true


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


# how long a job takes, by what it costs (s of play)
static func duration(cost: float) -> float:
	if cost < 30000.0:
		return 30.0
	if cost < 100000.0:
		return 60.0
	if cost < 500000.0:
		return 120.0
	return 180.0


static func current() -> Dictionary:
	return Career.data.get("works", {}) if Career.usable() else {}


static func busy() -> bool:
	return not current().is_empty()


static func name_of(job: Dictionary) -> String:
	if str(job.get("kind", "")) == "port":
		return w("%s（%s期）", "%s (part %s)") % [Port.name_of(str(job.zone)), cn_num(int(job.stage)) if Txt.zh else str(int(job.stage))]
	return Repair.name_of(str(job.get("id", "")))


# 1 -> 一 (user 2026-11-04: "拆船区（一期）")
static func cn_num(n: int) -> String:
	var d := ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
	return d[n] if n >= 0 and n <= 10 else str(n)


static func busy_text() -> String:
	var j := current()
	var stp := WorksPlan.line(j)
	return w("施工队正在修「%s」%s，修完才能接下一项（还要约 %d 秒）。", "The crew is on %s%s; one job at a time (about %d s left).") % [name_of(j), ("（" + stp + "）" if Txt.zh else " (" + stp + ")") if stp != "" else "", int(ceil(float(j.get("left", 0.0))))]


# the berth repair: ordered (materials and money taken), its facility the berth's when built
static func order_repair(id: String, with_parts: bool) -> String:
	if busy():
		return busy_text()
	var before := Career.data.duplicate(true)
	var cost := Repair.price(id, with_parts)
	var why := Repair.fix(id, with_parts)
	if why != "" or not BUILD_TIME:
		return why
	# take back what fix() handed over at once: built when the crew is done
	var d := Career.data
	d.upgrades.erase(id)
	var pend: Array = d.get("repaired_pending", [])
	pend.erase(id)
	d.repaired_pending = pend
	# 82 号: a repair with a plan takes as long as its steps add up to, not by its price
	var t := WorksPlan.total(id) if WorksPlan.PLANS.has(id) else duration(cost)
	d.works = {"id": id, "kind": "repair", "with_parts": with_parts, "total": t, "left": t}
	if not Career.save():
		Career.data = before
		return Txt.t("gr_save_failed")
	return ""


# a port district's next stage: ordered, the stage the port's when built
static func order_port(zone: String, with_parts: bool) -> String:
	if busy():
		return busy_text()
	var before := Career.data.duplicate(true)
	var n := Port.stage(zone) + 1
	var cost := Port.cash(zone, n, with_parts)
	var why := Port.fix(zone, with_parts)
	if why != "" or not BUILD_TIME:
		return why
	var d := Career.data
	var pt: Dictionary = d.get("port", {})
	pt[zone] = n - 1
	d.port = pt
	var tag := "port:%s:%d" % [zone, n]
	var pend: Array = d.get("repaired_pending", [])
	pend.erase(tag)
	d.repaired_pending = pend
	var t := duration(cost)
	d.works = {"id": tag, "kind": "port", "zone": zone, "stage": n, "with_parts": with_parts, "total": t, "left": t}
	if not Career.save():
		Career.data = before
		return Txt.t("gr_save_failed")
	return ""


# 87-5: while a load hangs on a crane or the boat's hook, nobody flies under it: the drone inside
# the lift zone stops the crew (and the sign says why) until it is out again
const LOCKOUT_M := 8.0
static var held := ""


static func lifting(j: Dictionary) -> bool:
	var a := WorksPlan.at(j)
	return int(a[0]) >= 0 and str(a[1]) == "lift"


# the crew's time: true when a job was finished now (the caller may show it); drone: where it is
static func advance(dt: float, drone := Vector2.INF) -> bool:
	var j := current()
	held = ""
	if j.is_empty() or dt <= 0.0:
		return false
	# developer workbench "施工瞬间完成": done now, crew or clock (the crew packs up when it sees no job)
	if DevPanel.instant_build and Txt.dev:
		return finish()
	# 92 号: the crew builds it for real (scripts/crew.gd): done when its work is, not on a clock
	if j.get("crew", false):
		return false
	if lifting(j) and drone != Vector2.INF and drone.distance_to(spot()) < LOCKOUT_M * Geom.M:
		held = "lockout"
		return false
	j.left = maxf(0.0, float(j.left) - dt)
	if float(j.left) > 0.0:
		return false
	return finish()


# the job done: the facility or the stage is the berth's; the completion is shown in the berth
static func finish() -> bool:
	var j := current()
	if j.is_empty():
		return false
	var before := Career.data.duplicate(true)
	var d := Career.data
	if str(j.kind) == "port":
		var pt: Dictionary = d.get("port", {})
		pt[str(j.zone)] = maxi(int(pt.get(str(j.zone), 0)), int(j.stage))
		d.port = pt
	else:
		d.upgrades[str(j.id)] = 1
	var pend: Array = d.get("repaired_pending", [])
	pend.append(str(j.id))
	d.repaired_pending = pend
	d.erase("works")
	if not Career.save():
		Career.data = before
		return false
	return true


# where the crew works (px in the berth scene)
static func spot() -> Vector2:
	var j := current()
	if j.is_empty():
		return Vector2.INF
	return RepairShow.spot(("port:" + str(j.zone)) if str(j.kind) == "port" else str(j.id))
