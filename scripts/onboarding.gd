class_name Onboarding
# The terminal opens up as it is needed (design/…/28_新手教程引导与主线, Q8/Q12; player
# 2026-10-24: "the terminal is complicated, a normal new player can't read it"). A career
# started from the title screen carries `term_open`; each part of the terminal lights the first
# time the career has a use for it, with one line on what it is. Careers without the key (every
# save from before, and the tests' fixtures) see the whole terminal, as before.

const ORDER := ["repair", "rep", "market_ops", "training"]
const TEXT := {
	"repair": ["终端里多了“装备”：七号坞有 16 处坏了，用拆船拆回来的零件或者钱来修。", "The terminal now has EQUIPMENT: sixteen things in Berth 07 are broken; mend them with salvaged parts or money."],
	"ledger": ["账本开放：缺钱可以借，结算时自动扣分期", "THE LEDGER OPENS: BORROW WHEN SHORT, INSTALMENTS TAKEN AT SETTLEMENT"],
	"rep": ["终端顶上多了“声望”：船拆得越多越好，别人越信你，才肯把更大更难的船交给你。", "REPUTATION now shows at the top: the more ships you strip well, the bigger the jobs people trust you with."],
	"market_ops": ["交易行开了：仓库里的东西可以拿去卖；“成长与建设”里可以修港区的其他地方。", "The exchange is open: sell what is in the warehouse. Growth and Construction mends the rest of the port."],
	"training": ["训练舱开了：遇到不熟的船，可以先来这里练一下，不练也能接。", "The training bay is open: practise on a ship type you don't know yet, or skip it."],
	"tools": ["工具与技术开放", "TOOLS AND TECHNIQUES OPEN"],
	"supplies": ["消耗品开放", "SUPPLIES OPEN"],
	"radio": ["无线电开放：回看终端发过的消息", "THE RADIO LOG OPENS: THE TERMINAL'S MESSAGES"],
}
# the terminal's pages -> the part that shows them
const PAGE := {0: "contracts", 1: "repair", 2: "ledger", 3: "tools", 4: "supplies", 5: "market_ops", 6: "radio", 7: "training"}


static func tracked() -> bool:
	return Career.data.has("term_open")


static func shown(key: String) -> bool:
	if key == "contracts" or key == "" or not tracked():
		return true
	return Career.data.term_open.has(key)


static func page_shown(page: int) -> bool:
	return shown(str(PAGE.get(page, "")))


static func _due(key: String) -> bool:
	var d := Career.data
	match key:
		"repair": return not d.get("parts", []).is_empty() or int(d.get("done", 0)) >= 1
		"ledger": return int(d.get("done", 0)) >= 1 or float(d.get("loan", 0.0)) > 0.0
		"rep": return int(d.get("rep", 0)) > 0
		"market_ops": return d.get("market", false)
		"training":
			if not d.get("certs", {}).is_empty():
				return true
			# 32 号: the prologue taught the basics; TS-1 is there to go over them, after the first job
			if d.get("prologue_done", false) and int(d.get("done", 0)) >= 1:
				return true
			if d.get("market", false):
				for o in d.get("offers", []):
					if not Codex.missing(str(o.get("ship", ""))).is_empty():
						return true
			return false
		"tools": return not d.get("feats", {}).is_empty() or int(d.get("done", 0)) >= 3
		"supplies": return int(d.get("done", 0)) >= 3
		"radio": return int(d.get("done", 0)) >= 1
	return false


# what opens now; returns the lines to say (and saves)
static func refresh() -> Array:
	if not tracked():
		return []
	var out: Array = []
	var open: Dictionary = Career.data.term_open
	for key in ORDER:
		if not open.has(key) and _due(key):
			open[key] = true
			out.append(TEXT[key][0 if Txt.zh else 1])
	if not out.is_empty():
		Career.save()
	return out
