#!/usr/bin/env python3
"""One-off authoring script: adds the endgame mission (The Long View) and its scene (plain_ending)
to data/missions/story.json and data/story/scenes.json. Kept so the data can be regenerated."""
import json
from pathlib import Path

R = Path(__file__).resolve().parent.parent

p = R / "data/missions/story.json"
m = json.loads(p.read_text())
if not any(x["id"] == "the_long_view" for x in m["missions"]):
    m["missions"].append({
        "id": "the_long_view", "title": "The Long View", "giver": "npc_boeta",
        "prerequisites": {"missions": ["kings_of_the_plain"], "districts": ["district_tafelsig"]},
        "intro": "Boeta: \"Five suburbs. Westridge to Tafelsig. Nobody has held this much of the Plain. Hold ten corners and come and tell me what it was all for.\"",
        "description": "Hold ten corners across Mitchells Plain, then decide what the Plain becomes.",
        "objectives": [
            {"id": "ten", "type": "stat", "stat": "corners", "value": 10, "text": "Hold ten corners across Mitchells Plain"},
            {"id": "ending", "type": "dialogue", "target": "npc_boeta", "scene": "plain_ending", "text": "Decide with Boeta what the Plain becomes"}],
        "rewards": {"cash": 2000, "reputation": 100, "crew_influence": 25}})
    p.write_text(json.dumps(m, indent=2, ensure_ascii=False) + "\n")

p = R / "data/story/scenes.json"
sc = json.loads(p.read_text())
sc["scenes"]["plain_ending"] = {
    "speaker": "Boeta",
    "lines": [
        "Westridge, Lentegeur, Rocklands, the Promenade, Tafelsig. Ten corners. Look at that map.",
        "My mother raised us here when they moved her out of District Six. She said a place is only as good as the people who stay.",
        "So. What do we do with it?"],
    "choices": [
        {"text": "We rule it. The Plain is ours.",
         "effects": {"flags": ["ending_crown", "game_finished"], "reputation": 30, "banner": "THE PLAIN IS YOURS"},
         "reply": "Boeta: \"Then we'd better be better at it than the people before us.\""},
        {"text": "We share it. One table, every crew.",
         "effects": {"flags": ["ending_council", "game_finished"], "reputation": 40,
                     "turf_allies": ["tortel_crew", "vlakte_vipers", "duin_boys", "klipspringers"], "banner": "A COUNCIL OF CREWS"},
         "reply": "Boeta: \"A table. I never thought I'd see it. Let's keep it from tipping.\""},
        {"text": "We hand the corners back and walk away.",
         "effects": {"flags": ["ending_exit", "game_finished"], "reputation": 50, "turf_release": True, "banner": "YOU WALKED AWAY"},
         "reply": "Boeta: \"Then the Plain is theirs again. Maybe that was the point.\""}]}
p.write_text(json.dumps(sc, indent=2, ensure_ascii=False) + "\n")
print("ok")
