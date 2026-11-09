class_name Safehouse
extends RefCounted
## Safehouse upgrade rules (data: data/progression/safehouse_upgrades.json).
## Purchases go through ProgressionState; one-off effects are granted once per upgrade key.

var upgrades: Array = []   # Array of Dictionary
var by_id: Dictionary = {}


static func load_file(path: String) -> Safehouse:
	var s := Safehouse.new()
	var raw: Variant = DataFiles.load_json(path)
	if raw is Dictionary:
		for u in raw.get("upgrades", []):
			if u is Dictionary and u.has("id") and u.has("cost"):
				s.upgrades.append(u)
				s.by_id[str(u.id)] = u
	return s


## "" if the upgrade can be bought now, else the reason it can't.
func why_not(id: String, p: ProgressionState) -> String:
	var u: Dictionary = by_id.get(id, {})
	if u.is_empty():
		return "unknown upgrade"
	if p.safehouse_upgrades.has(id):
		return "already built"
	if p.recruited_crew_ids.size() < int(u.get("requires_crew", 0)):
		return "needs %d crew member(s)" % int(u.requires_crew)
	if not p.can_afford(int(u.cost)):
		return "costs R%d (you have R%d)" % [int(u.cost), p.cash]
	return ""


func buy(id: String, p: ProgressionState) -> bool:
	if not why_not(id, p).is_empty():
		return false
	var u: Dictionary = by_id[id]
	if not p.spend(int(u.cost)):
		return false
	p.safehouse_upgrades.append(id)
	var effect: Dictionary = u.get("effect", {})
	p.grant("upgrade:" + id, {"reputation": int(effect.get("reputation", 0)),
		"crew_influence": int(effect.get("crew_influence", 0)),
		"influence": {"starter": int(effect.get("influence", 0))}})
	return true


func daily_income(p: ProgressionState) -> int:
	var total := 0
	for id in p.safehouse_upgrades:
		total += int(by_id.get(id, {}).get("effect", {}).get("daily_cash", 0))
	return total
