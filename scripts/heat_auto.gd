class_name HeatAuto
# 39 号 (13 号 Q33/Q51): the first step the port takes over — the arc furnace's auto
# sample-and-tap. Offered once three heats have been tapped in the processing district; bought
# once, it immerses the probe and tilts the furnace by itself when the charge is liquid and hot.
const PRICE := 12000.0
const NEED := 3


static func count() -> int:
	return int(Career.data.get("heat_count", 0))


static func on() -> bool:
	return int(Career.data.get("upgrades", {}).get("eaf_auto", 0)) > 0


static func offer() -> bool:
	return Career.usable() and not on() and count() >= NEED and Port.stage("process") >= 1


static func install() -> Dictionary:
	if on(): return {"ok": false, "reason": w("已经装好了", "Already installed")}
	if count() < NEED: return {"ok": false, "reason": w("先亲手出满 %d 炉（现在 %d 炉）", "Tap %d heats by hand first (%d so far)") % [NEED, count()]}
	if float(Career.data.get("money", 0.0)) < PRICE: return {"ok": false, "reason": w("现金不够 %s", "Not enough cash for %s") % Pal.money(PRICE)}
	var before := Career.data
	Career.data = before.duplicate(true)
	Career.data.money = float(Career.data.money) - PRICE
	var up: Dictionary = Career.data.get("upgrades", {})
	up.eaf_auto = 1
	Career.data.upgrades = up
	if Career.data.get("exchange", {}).has("actors"):
		Career.data.exchange.actors.company.cash = float(Career.data.money)
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": w("保存失败，未扣款", "Save failed; nothing charged")}
	return {"ok": true}


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en
