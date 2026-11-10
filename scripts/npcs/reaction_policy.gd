class_name ReactionPolicy
extends RefCounted
## Chooses how an NPC reacts to a neighbourhood incident. Pure function, unit-tested.
## Severity: 1 = noise (car alarm, whistle), 2 = disturbance (argument), 3 = danger (scuffle),
## 4 = gunfire (police come from further away; everyone else who isn't crew runs).
## Returns "", "notice", "investigate", "flee" or "report".

const PERSONALITIES: PackedStringArray = ["curious", "timid", "gossip", "steady", "tough"]


static func choose(role: String, personality: String, severity: int, distance: float, radius: float) -> String:
	if role == "police":
		return "investigate" if distance <= radius * (1.75 if severity >= 3 else 1.0) else ""
	if distance > radius:
		return ""
	if role == "crew" or role == "player_crew":
		return "investigate"
	if severity >= 4:
		return "flee"   # gunshots: nobody stands around, not even the tough ones
	if personality == "tough":
		return "investigate"
	var close := distance < radius * 0.5
	match severity:
		1:
			return "investigate" if personality == "curious" and close else "notice"
		2:
			match personality:
				"curious": return "investigate"
				"timid": return "flee"
				"gossip": return "report"
				_: return "notice"
		_:
			match personality:
				"gossip": return "report"
				"curious": return "flee" if close else "investigate"
				_: return "flee"
