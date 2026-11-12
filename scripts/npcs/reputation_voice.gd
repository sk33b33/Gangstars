class_name ReputationVoice
extends RefCounted
## What people say when you walk past, by how well they know you: your reputation, how they
## personally feel about you, and the police heat on you. A little Cape Kaaps in the mix
## ("Hoezit", "ja nee", "my bru"); worth a read-through by someone from the Plain.

const UNKNOWN := ["Howzit.", "Hoezit?", "Morning, neighbour.", "New face, hey."]
const KNOWN := ["Ja, I know you, from 13 AZ Berman.", "Hoezit, neighbour!", "Ag, you're settling in nicely."]
const RESPECTED := ["Respect, hey.", "People talk well of you.", "Ja nee, good to see you, boss.", "My bru, you've done a lot for this street."]
const LEGEND := ["Is it really you? The whole Plain knows your name.", "Respect, boss. Respect.", "My kids point you out in the street."]
const WARY := ["Mm. I've heard things about you.", "Keep walking, please.", "I don't want trouble."]
const FRIEND := ["Ag, my friend! Come, come.", "Ja nee, look who it is!", "There's always tea for you."]
const COLD := ["I've got nothing to say to you.", "Hmph.", "You've got some nerve."]
const HEAT := ["Police are looking for you! Go!", "Not near my gate, please!", "Skarrel, quick!"]


## Returns {"line": String, "wave": bool}. heat is the police star level (0-5).
static func greet(reputation: int, relationship: int, heat: int, rng: RandomNumberGenerator) -> Dictionary:
	if heat >= 3:
		return {"line": HEAT[rng.randi() % HEAT.size()], "wave": false}
	if relationship <= -10:
		return {"line": COLD[rng.randi() % COLD.size()], "wave": false}
	if relationship >= 20:
		return {"line": FRIEND[rng.randi() % FRIEND.size()], "wave": true}
	var pool: Array = UNKNOWN
	if reputation < 0:
		pool = WARY
	elif reputation >= 250:
		pool = LEGEND
	elif reputation >= 100:
		pool = RESPECTED
	elif reputation >= 30:
		pool = KNOWN
	return {"line": pool[rng.randi() % pool.size()], "wave": reputation >= 0}
