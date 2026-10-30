extends RefCounted
# G5 intake accounting. Raw receipts are NOT cast products: the existing plant
# must process them before any quality, product or dispatch credit is granted.
# An old commission never acquires company ownership merely by loading it.

static func retains(job: Dictionary) -> bool:
	var policy: Dictionary = job.get("material_policy", {})
	return int(policy.get("version", 0)) == 1 and policy.get("metal", "") == "retain" and policy.get("owner", "") == "company" and str(policy.get("asset_id", "")) != "" and str(job.get("id", "")) != ""


static func receipt_id(job_id: String, piece_key: String) -> String:
	return JSON.stringify([job_id, piece_key]).sha256_text()


static func has_piece(rows: Array, job_id: String, key: String) -> bool:
	var identity := receipt_id(job_id, key)
	for row in rows:
		if row.get("id", "") == identity: return true
	return false


static func eligible(game, piece, zone: String) -> bool:
	return retains(game.job) and zone == "metal" and game.scope() != "rescue" and piece.scope and piece.cls == "metal" and not piece.contam and game.sys.dest_of(piece) != "hazard" and piece.key != "" and is_finite(piece.mass) and piece.mass > 0.0


# what a structural part is made of, as the sorting line will find it: the share that is
# not magnetic steel (aluminium trim, copper runs, brass fittings, coatings). Authored per
# part type (G5.1, 19 号); keels and frames are near-plain steel, fixtures and lamps much less so.
const NONMAGNETIC_BY_KIND := {"keel": 0.03, "rib": 0.04, "beam": 0.04, "strut": 0.04, "hull": 0.06,
	"bulkhead": 0.07, "deck": 0.08, "plate": 0.08, "door": 0.11, "hatch": 0.11, "rail": 0.12,
	"fixture": 0.30, "lamp": 0.45}
const NONMAGNETIC_DEFAULT := 0.10


static func profile_of(piece) -> Dictionary:
	var by_kind := float(NONMAGNETIC_BY_KIND.get(str(piece.kind), NONMAGNETIC_DEFAULT))
	# 87-1: a part of a known material is what its material is (aluminium, titanium, ceramic and
	# composite are not magnetic at all; armour steel is); plain steel keeps the per-type share
	if str(piece.mat) != "" and str(piece.mat) != Mat.STEEL:
		return {"version":1, "nonmagnetic_share":Mat.nonmag(piece, by_kind), "basis":"material_" + str(piece.mat), "material":str(piece.mat), "sort":Mat.sort_of(piece)}
	return {"version":1, "nonmagnetic_share":by_kind, "basis":"ship_structure_" + str(piece.kind)}


static func received(job: Dictionary, piece, value: float) -> Dictionary:
	return {"id":receipt_id(str(job.id), piece.key), "job_id":str(job.id),
		"asset_id":str(job.material_policy.asset_id), "piece_key":piece.key,
		"ship":str(job.get("ship", "")), "mass_t":piece.mass,
		"recovery_value":value, "material":"ungraded_scrap", "state":"raw_received",
		"material_profile":profile_of(piece)}


static func recovery_value(rows: Array) -> float:
	var value := 0.0
	for row in rows: value += float(row.get("recovery_value", 0.0))
	return value


# Called inside Career's copy-on-write settlement, before its single disk commit.
# Validate the complete report before changing any stock. No retroactive stock
# is generated from structure_t, cash, the furnace's initial heel or its scenery.
static func apply_report(data: Dictionary, job: Dictionary, rows: Array) -> Dictionary:
	if rows.is_empty(): return {"ok":true, "batches":0, "mass_t":0.0}
	if not retains(job): return {"ok":false, "reason":"material_ownership"}
	var stock: Array = data.get("material_batches", []).duplicate(true)
	var ids := {}
	for batch in stock: ids[str(batch.get("id", ""))] = true
	var mass := 0.0
	for entry in rows:
		if not entry is Dictionary: return {"ok":false, "reason":"material_receipt"}
		var row: Dictionary = entry
		var key := str(row.get("piece_key", ""))
		var identity := receipt_id(str(job.id), key)
		var tons := float(row.get("mass_t", 0.0))
		var value := float(row.get("recovery_value", -1.0))
		if key == "" or row.get("id", "") != identity or row.get("job_id", "") != str(job.id) or row.get("asset_id", "") != str(job.material_policy.asset_id) or row.get("ship", "") != str(job.get("ship", "")):
			return {"ok":false, "reason":"material_identity"}
		if ids.has(identity) or not is_finite(tons) or tons <= 0.0 or not is_finite(value) or value < 0.0 or row.get("state", "") != "raw_received" or row.get("material", "") != "ungraded_scrap":
			return {"ok":false, "reason":"material_receipt"}
		ids[identity] = true
		mass += tons
		stock.append(row.duplicate(true))
	data.material_batches = stock
	return {"ok":true, "batches":rows.size(), "mass_t":mass}
